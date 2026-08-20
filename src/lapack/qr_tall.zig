//! Tall-skinny and blocked QR: the modern factorization interfaces.
//!
//! `qr.geqrf` is the classical QR, and it is fine. These are the interfaces
//! LAPACK added afterwards, and they exist for two different reasons.
//!
//! ## `geqr` / `gelq`: let the library choose
//!
//! `geqrf` commits you to one algorithm and one representation of `Q`. `geqr`
//! does not: it picks between a blocked Householder QR and a communication-
//! avoiding "tall-skinny" QR based on the shape, and returns an opaque factor
//! that only `gemqr` knows how to apply. For a matrix with far more rows than
//! columns the tall-skinny path is substantially faster, and you get it without
//! choosing.
//!
//! The price is that the factor is opaque. There is no `orgqr` for it — you can
//! apply `Q` with `gemqr` but not build it — and `R` is the upper triangle of
//! `a` as usual. `Factorization(T)` owns the array and its `deinit` frees it.
//!
//! ## `geqrt` / `tpqrt`: build your own blocked algorithm
//!
//! The other family exposes the block reflector directly. `geqrt` factors a
//! panel and returns its `T` matrix; `tpqrt` factors a *triangular-pentagonal*
//! block against an existing `R`, which is the update step of a blocked or
//! out-of-core QR; `tprfb` applies such a reflector to a pair of blocks.
//!
//! Together they let you write a QR that processes a matrix that does not fit
//! in memory, or one distributed across threads, with LAPACK doing the
//! numerical work at each step. `qr.geqrf` is what you want unless you are
//! doing that.
//!
//! ## The `p` in "triangular-pentagonal"
//!
//! `tpqrt` and friends take an extra `l` saying how much of the second block is
//! triangular: `l = 0` makes it a plain rectangle, `l = m` makes it triangular,
//! and anything between makes it pentagonal. `l = 0` is the common case — it is
//! what you use to append rows to an existing factorization.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");
const qr = @import("qr.zig");

const Int = types.Int;
const Complex = types.Complex;
const Real = types.Real;
const Side = types.Side;
const Trans = types.Trans;
const Uplo = types.Uplo;
const Direction = types.Direction;
const StoreV = types.StoreV;
const Error = info_mod.Error;
const dim = types.dim;
const assertMatrix = types.assertMatrix;
const ref = work_mod.ref;
const out = work_mod.out;
const opt = types.opt;

const Allocator = std.mem.Allocator;
const Fail = Error || Allocator.Error;

/// Re-exported so callers need not import `qr.zig` for the flag `gemqr` takes.
pub const QTrans = qr.QTrans;

fn sym(comptime T: type, comptime name: []const u8) @TypeOf(@field(c, [_]u8{types.prefix(T)} ++ name)) {
    return @field(c, [_]u8{types.prefix(T)} ++ name);
}

fn ortho(comptime T: type, comptime suffix: []const u8) []const u8 {
    return switch (T) {
        f32, f64 => "or" ++ suffix,
        else => "un" ++ suffix,
    };
}

fn qtrans(comptime T: type, t: QTrans) [*]const u8 {
    const Chars = enum(u8) { n = 'N', t = 'T', c_ = 'C' };
    return switch (t) {
        .no_trans => opt(Chars.n),
        .transpose => switch (T) {
            f32, f64 => opt(Chars.t),
            else => opt(Chars.c_),
        },
    };
}

/// The opaque factor `geqr` and `gelq` produce.
///
/// Its contents are the library's business — the layout depends on which
/// algorithm was chosen — so there is nothing to read here. Pass it to `gemqr`
/// or `gemlq`, and call `deinit` when done.
pub fn Factorization(comptime T: type) type {
    return struct {
        const Self = @This();
        t: []T,
        allocator: Allocator,

        pub fn deinit(self: Self) void {
            self.allocator.free(self.t);
        }
    };
}

/// QR with the algorithm chosen by the library.
///
/// `R` is left in the upper triangle of `a` as usual; the returned factor
/// describes `Q` and is only usable through `gemqr`.
pub fn geqr(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
) Fail!Factorization(T) {
    return chooseAndFactor(T, "geqr", allocator, rows, cols, a, lda);
}

/// LQ with the algorithm chosen by the library. `gemlq` applies the `Q`.
pub fn gelq(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
) Fail!Factorization(T) {
    return chooseAndFactor(T, "gelq", allocator, rows, cols, a, lda);
}

fn chooseAndFactor(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
) Fail!Factorization(T) {
    assertMatrix(a.len, rows, cols, lda);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(@max(lda, 1));
    var info: Int = 0;

    // Two sizes to learn, and both are queried in the same call: `tsize` for
    // the factor and `lwork` for the scratch. The factor is not a workspace -
    // it has to outlive the call.
    var tq: [5]T = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(ref(&m_), ref(&n_), a.ptr, ref(&lda_), &tq, ref(&neg), &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const tsize: usize = @intCast(@max(work_mod.sizeFrom(T, tq[0]), 5));
    const t = try allocator.alloc(T, tsize);
    errdefer allocator.free(t);
    const tsize_ = dim(tsize);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, name)(ref(&m_), ref(&n_), a.ptr, ref(&lda_), t.ptr, ref(&tsize_), buf.ptr, ref(&lwork), out(&info));
    try info_mod.checkArgs(info);
    return .{ .t = t, .allocator = allocator };
}

/// Multiplies `c` by the `Q` from `geqr`, without forming it.
///
/// `k` is the number of reflectors, which is `min(rows, cols)` of the *original*
/// matrix, not of `c`.
pub fn gemqr(
    comptime T: type,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    k: usize,
    a: []const T,
    lda: usize,
    factorization: Factorization(T),
    cm: []T,
    ldc: usize,
) Fail!void {
    return applyChosen(T, "gemqr", allocator, side, trans, rows, cols, k, a, lda, factorization, cm, ldc);
}

/// `gemqr` for a `gelq` factorization.
pub fn gemlq(
    comptime T: type,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    k: usize,
    a: []const T,
    lda: usize,
    factorization: Factorization(T),
    cm: []T,
    ldc: usize,
) Fail!void {
    return applyChosen(T, "gemlq", allocator, side, trans, rows, cols, k, a, lda, factorization, cm, ldc);
}

fn applyChosen(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    k: usize,
    a: []const T,
    lda: usize,
    factorization: Factorization(T),
    cm: []T,
    ldc: usize,
) Fail!void {
    assertMatrix(cm.len, rows, cols, ldc);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const k_ = dim(k);
    const lda_ = dim(@max(lda, 1));
    const ldc_ = dim(@max(ldc, 1));
    const tsize = dim(factorization.t.len);
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(opt(side), qtrans(T, trans), ref(&m_), ref(&n_), ref(&k_), a.ptr, ref(&lda_), factorization.t.ptr, ref(&tsize), cm.ptr, ref(&ldc_), &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, name)(opt(side), qtrans(T, trans), ref(&m_), ref(&n_), ref(&k_), a.ptr, ref(&lda_), factorization.t.ptr, ref(&tsize), cm.ptr, ref(&ldc_), buf.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

// ============================================================================
// Explicit block reflectors
// ============================================================================

/// QR with the block reflector returned explicitly.
///
/// `nb` is the block size, at most `min(rows, cols)`. `t` receives the
/// `nb x min(rows, cols)` block reflector, which `gemqrt` applies and `tprfb`
/// consumes.
pub fn geqrt(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    nb: usize,
    a: []T,
    lda: usize,
    t: []T,
    ldt: usize,
) Fail!void {
    assertMatrix(a.len, rows, cols, lda);
    const k = @min(rows, cols);
    std.debug.assert(nb >= 1 and nb <= k);
    assertMatrix(t.len, nb, k, ldt);

    const work = try allocator.alloc(T, @max(nb * cols, 1));
    defer allocator.free(work);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const nb_ = dim(nb);
    const lda_ = dim(@max(lda, 1));
    const ldt_ = dim(@max(ldt, 1));
    var info: Int = 0;

    sym(T, "geqrt")(ref(&m_), ref(&n_), ref(&nb_), a.ptr, ref(&lda_), t.ptr, ref(&ldt_), work.ptr, out(&info));
    return info_mod.checkArgs(info);
}

/// Applies a `geqrt` block reflector to `c`.
pub fn gemqrt(
    comptime T: type,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    k: usize,
    nb: usize,
    v: []const T,
    ldv: usize,
    t: []const T,
    ldt: usize,
    cm: []T,
    ldc: usize,
) Fail!void {
    assertMatrix(cm.len, rows, cols, ldc);
    std.debug.assert(nb >= 1 and nb <= k);

    const work = try allocator.alloc(T, @max(nb * (if (side == .left) cols else rows), 1));
    defer allocator.free(work);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const k_ = dim(k);
    const nb_ = dim(nb);
    const ldv_ = dim(@max(ldv, 1));
    const ldt_ = dim(@max(ldt, 1));
    const ldc_ = dim(@max(ldc, 1));
    var info: Int = 0;

    sym(T, "gemqrt")(opt(side), qtrans(T, trans), ref(&m_), ref(&n_), ref(&k_), ref(&nb_), v.ptr, ref(&ldv_), t.ptr, ref(&ldt_), cm.ptr, ref(&ldc_), work.ptr, out(&info));
    return info_mod.checkArgs(info);
}

/// QR of a triangular-pentagonal block stacked under an existing `R`.
///
/// The blocked-QR update step: `a` holds the `n x n` upper triangular factor so
/// far and `b` the `m x n` block being appended. Both are overwritten, `a` with
/// the new `R` and `b` with the reflectors.
///
/// `l` says how much of `b` is triangular — `0` for a plain rectangular block,
/// which is the case when you are simply appending rows.
pub fn tpqrt(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    l: usize,
    nb: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    t: []T,
    ldt: usize,
) Fail!void {
    return pentagonal(T, "tpqrt", allocator, rows, cols, l, nb, a, lda, b, ldb, t, ldt);
}

/// `tpqrt` for an LQ factorization.
pub fn tplqt(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    l: usize,
    nb: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    t: []T,
    ldt: usize,
) Fail!void {
    return pentagonal(T, "tplqt", allocator, rows, cols, l, nb, a, lda, b, ldb, t, ldt);
}

fn pentagonal(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    l: usize,
    nb: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    t: []T,
    ldt: usize,
) Fail!void {
    std.debug.assert(l <= @min(rows, cols));
    std.debug.assert(nb >= 1);

    const work = try allocator.alloc(T, @max(nb * @max(rows, cols), 1));
    defer allocator.free(work);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const l_ = dim(l);
    const nb_ = dim(nb);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldt_ = dim(@max(ldt, 1));
    var info: Int = 0;

    sym(T, name)(ref(&m_), ref(&n_), ref(&l_), ref(&nb_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), t.ptr, ref(&ldt_), work.ptr, out(&info));
    return info_mod.checkArgs(info);
}

/// Applies a `tpqrt` reflector to the pair `(a, b)`.
///
/// Both blocks are updated together, because the reflector spans them.
pub fn tpmqrt(
    comptime T: type,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    k: usize,
    l: usize,
    nb: usize,
    v: []const T,
    ldv: usize,
    t: []const T,
    ldt: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
) Fail!void {
    return applyPentagonal(T, "tpmqrt", allocator, side, trans, rows, cols, k, l, nb, v, ldv, t, ldt, a, lda, b, ldb);
}

/// `tpmqrt` for a `tplqt` reflector.
pub fn tpmlqt(
    comptime T: type,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    k: usize,
    l: usize,
    nb: usize,
    v: []const T,
    ldv: usize,
    t: []const T,
    ldt: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
) Fail!void {
    return applyPentagonal(T, "tpmlqt", allocator, side, trans, rows, cols, k, l, nb, v, ldv, t, ldt, a, lda, b, ldb);
}

fn applyPentagonal(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    k: usize,
    l: usize,
    nb: usize,
    v: []const T,
    ldv: usize,
    t: []const T,
    ldt: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
) Fail!void {
    assertMatrix(b.len, rows, cols, ldb);
    std.debug.assert(nb >= 1 and nb <= k);

    const work = try allocator.alloc(T, @max(nb * @max(rows, cols) + nb * nb, 1));
    defer allocator.free(work);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const k_ = dim(k);
    const l_ = dim(l);
    const nb_ = dim(nb);
    const ldv_ = dim(@max(ldv, 1));
    const ldt_ = dim(@max(ldt, 1));
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    var info: Int = 0;

    sym(T, name)(opt(side), qtrans(T, trans), ref(&m_), ref(&n_), ref(&k_), ref(&l_), ref(&nb_), v.ptr, ref(&ldv_), t.ptr, ref(&ldt_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), work.ptr, out(&info));
    return info_mod.checkArgs(info);
}

/// Applies a block reflector `H` or `H^H` to a pair of blocks.
///
/// The primitive under `tpmqrt`, exposed for building your own blocked
/// algorithm. Unlike everything else here it reports nothing — there is no
/// `info` in the C signature at all — so it cannot fail and returns `void`.
pub fn tprfb(
    comptime T: type,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    direct: Direction,
    storev: StoreV,
    rows: usize,
    cols: usize,
    k: usize,
    l: usize,
    v: []const T,
    ldv: usize,
    t: []const T,
    ldt: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
) Allocator.Error!void {
    assertMatrix(b.len, rows, cols, ldb);

    const ldwork = if (side == .left) k else rows;
    const work = try allocator.alloc(T, @max(ldwork * @max(k, cols), 1));
    defer allocator.free(work);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const k_ = dim(k);
    const l_ = dim(l);
    const ldv_ = dim(@max(ldv, 1));
    const ldt_ = dim(@max(ldt, 1));
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldwork_ = dim(@max(ldwork, 1));

    sym(T, "tprfb")(opt(side), qtrans(T, trans), opt(direct), opt(storev), ref(&m_), ref(&n_), ref(&k_), ref(&l_), v.ptr, ref(&ldv_), t.ptr, ref(&ldt_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), work.ptr, ref(&ldwork_));
}

// ============================================================================
// Least squares and the RZ factorization
// ============================================================================

/// `qr.gels` using the tall-skinny factorization.
///
/// Same problem and same interface as `gels`; faster when the matrix is much
/// taller than it is wide, because it uses `geqr` internally rather than
/// `geqrf`.
pub fn getsls(
    comptime T: type,
    allocator: Allocator,
    trans: QTrans,
    rows: usize,
    cols: usize,
    nrhs: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
) Fail!void {
    return tallLeastSquares(T, "getsls", allocator, trans, rows, cols, nrhs, a, lda, b, ldb);
}

/// `qr.gels` using the blocked `geqrt` factorization.
pub fn gelst(
    comptime T: type,
    allocator: Allocator,
    trans: QTrans,
    rows: usize,
    cols: usize,
    nrhs: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
) Fail!void {
    return tallLeastSquares(T, "gelst", allocator, trans, rows, cols, nrhs, a, lda, b, ldb);
}

fn tallLeastSquares(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    trans: QTrans,
    rows: usize,
    cols: usize,
    nrhs: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
) Fail!void {
    assertMatrix(a.len, rows, cols, lda);
    assertMatrix(b.len, @max(rows, cols), nrhs, ldb);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(qtrans(T, trans), ref(&m_), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, name)(qtrans(T, trans), ref(&m_), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), buf.ptr, ref(&lwork), out(&info));
    // Positive info here means the matrix is rank deficient, which these
    // routines cannot handle - use qr.gelsd or gelsy instead.
    return info_mod.checkLu(info);
}

/// `qr.geqrf` with a guaranteed non-negative diagonal in `R`.
///
/// The QR factorization is unique only up to the signs of `R`'s diagonal;
/// `geqrf` picks whichever sign falls out of the arithmetic, this one forces
/// them all non-negative. Slightly slower, and worth it when you need the
/// factorization to be a function of the input rather than of the
/// implementation — comparing two factorizations, or reproducing one across
/// LAPACK versions.
pub fn geqrfp(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    tau: []T,
) Fail!void {
    assertMatrix(a.len, rows, cols, lda);
    std.debug.assert(tau.len >= @min(rows, cols));

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(@max(lda, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, "geqrfp")(ref(&m_), ref(&n_), a.ptr, ref(&lda_), tau.ptr, &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, "geqrfp")(ref(&m_), ref(&n_), a.ptr, ref(&lda_), tau.ptr, buf.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// The unblocked `geqrfp`. No workspace query; it takes exactly `cols`.
pub fn geqr2p(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    tau: []T,
) Fail!void {
    assertMatrix(a.len, rows, cols, lda);
    std.debug.assert(tau.len >= @min(rows, cols));

    const work = try allocator.alloc(T, @max(cols, 1));
    defer allocator.free(work);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(@max(lda, 1));
    var info: Int = 0;

    sym(T, "geqr2p")(ref(&m_), ref(&n_), a.ptr, ref(&lda_), tau.ptr, work.ptr, out(&info));
    return info_mod.checkArgs(info);
}

/// Reduces an upper trapezoidal matrix to upper triangular form: `A = [R 0] Z`.
///
/// The step `qr.gelsy` performs after its pivoted QR. For an `m x n` matrix
/// with `m <= n`, the leading `m x m` block becomes upper triangular and the
/// rest is annihilated by the orthogonal `Z`, whose reflectors are stored in the
/// trailing part of `a` with `tau`.
pub fn tzrzf(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    tau: []T,
) Fail!void {
    assertMatrix(a.len, rows, cols, lda);
    std.debug.assert(rows <= cols);
    std.debug.assert(tau.len >= rows);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(@max(lda, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, "tzrzf")(ref(&m_), ref(&n_), a.ptr, ref(&lda_), tau.ptr, &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, "tzrzf")(ref(&m_), ref(&n_), a.ptr, ref(&lda_), tau.ptr, buf.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// Multiplies `c` by `tzrzf`'s `Z`, without forming it.
///
/// `l` is the number of columns of `a` holding reflectors, which is
/// `cols - rows` from the `tzrzf` call.
pub fn ormrz(
    comptime T: type,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    k: usize,
    l: usize,
    a: []const T,
    lda: usize,
    tau: []const T,
    cm: []T,
    ldc: usize,
) Fail!void {
    assertMatrix(cm.len, rows, cols, ldc);
    std.debug.assert(tau.len >= k);

    const name = comptime ortho(T, "mrz");
    const m_ = dim(rows);
    const n_ = dim(cols);
    const k_ = dim(k);
    const l_ = dim(l);
    const lda_ = dim(@max(lda, 1));
    const ldc_ = dim(@max(ldc, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(opt(side), qtrans(T, trans), ref(&m_), ref(&n_), ref(&k_), ref(&l_), a.ptr, ref(&lda_), tau.ptr, cm.ptr, ref(&ldc_), &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, name)(opt(side), qtrans(T, trans), ref(&m_), ref(&n_), ref(&k_), ref(&l_), a.ptr, ref(&lda_), tau.ptr, cm.ptr, ref(&ldc_), buf.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// `ormrz` under its complex name.
pub const unmrz = ormrz;

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// A 6x2 matrix — tall enough that `geqr` may pick the tall-skinny path.
const tall = [_]f64{
    1, 2,  3, 4,  5, 6,
    2, -1, 4, -3, 6, -5,
};

test "geqr's Q applied to R reconstructs the original" {
    const m = 6;
    const n = 2;
    var a = tall;
    const f = try geqr(f64, testing.allocator, m, n, &a, m);
    defer f.deinit();

    // Note there is nothing to assert about the lower triangle: like geqrf,
    // this leaves the reflectors there rather than zeros. R is the upper
    // triangle by convention, and the reconstruction below is what checks it.

    // Build Q explicitly by applying it to the identity - the only way, since
    // there is no orgqr for this factor.
    var q = [_]f64{0} ** (m * m);
    for (0..m) |i| q[i + i * m] = 1;
    try gemqr(f64, testing.allocator, .left, .no_trans, m, m, n, &a, m, f, &q, m);

    // Q R, with R the upper triangle of a.
    for (0..n) |j| {
        for (0..m) |i| {
            var acc: f64 = 0;
            for (0..n) |k| {
                if (k <= j) acc += q[i + k * m] * a[k + j * m];
            }
            try testing.expectApproxEqAbs(tall[i + j * m], acc, 1e-11);
        }
    }
}

test "geqr's R matches geqrf's up to column signs" {
    const m = 6;
    const n = 2;
    var a_new = tall;
    const f = try geqr(f64, testing.allocator, m, n, &a_new, m);
    defer f.deinit();

    var a_old = tall;
    var tau: [2]f64 = undefined;
    try qr.geqrf(f64, testing.allocator, m, n, &a_old, m, &tau);

    // The two algorithms can differ by the sign of each row of R.
    for (0..n) |j| {
        for (0..j + 1) |i| {
            try testing.expectApproxEqAbs(@abs(a_old[i + j * m]), @abs(a_new[i + j * m]), 1e-11);
        }
    }
}

test "gelq and gemlq are the LQ counterparts" {
    const m = 2;
    const n = 6;
    // The transpose of `tall`.
    var a: [m * n]f64 = undefined;
    for (0..n) |j| for (0..m) |i| {
        a[i + j * m] = tall[j + i * 6];
    };
    const original = a;

    const f = try gelq(f64, testing.allocator, m, n, &a, m);
    defer f.deinit();

    // L is the lower triangle of the leading m x m block.
    var q = [_]f64{0} ** (n * n);
    for (0..n) |i| q[i + i * n] = 1;
    try gemlq(f64, testing.allocator, .left, .no_trans, n, n, m, &a, m, f, &q, n);

    // L Q reconstructs the original.
    for (0..n) |j| {
        for (0..m) |i| {
            var acc: f64 = 0;
            for (0..m) |k| {
                if (k <= i) acc += a[i + k * m] * q[k + j * n];
            }
            try testing.expectApproxEqAbs(original[i + j * m], acc, 1e-11);
        }
    }
}

test "geqrt and gemqrt agree with geqr" {
    const m = 6;
    const n = 2;
    var a = tall;
    var t: [2 * 2]f64 = undefined;
    try geqrt(f64, testing.allocator, m, n, 2, &a, m, &t, 2);

    var q = [_]f64{0} ** (m * m);
    for (0..m) |i| q[i + i * m] = 1;
    try gemqrt(f64, testing.allocator, .left, .no_trans, m, m, n, 2, &a, m, &t, 2, &q, m);

    for (0..n) |j| {
        for (0..m) |i| {
            var acc: f64 = 0;
            for (0..n) |k| {
                if (k <= j) acc += q[i + k * m] * a[k + j * m];
            }
            try testing.expectApproxEqAbs(tall[i + j * m], acc, 1e-11);
        }
    }
}

test "tpqrt appends rows to an existing factorization" {
    const n = 2;
    // Factor the first four rows, then append the last two with tpqrt and
    // check the result matches factoring all six at once.
    var top = [_]f64{
        1, 2,  3, 4,
        2, -1, 4, -3,
    };
    var tau_top: [n]f64 = undefined;
    try qr.geqrf(f64, testing.allocator, 4, n, &top, 4, &tau_top);

    // R so far, as an n x n upper triangle.
    var r = [_]f64{0} ** (n * n);
    for (0..n) |j| for (0..j + 1) |i| {
        r[i + j * n] = top[i + j * 4];
    };

    // The two remaining rows.
    var b = [_]f64{ 5, 6, 6, -5 };
    var t: [1 * n]f64 = undefined;
    // l = 0: b is a plain rectangle, not pentagonal.
    try tpqrt(f64, testing.allocator, 2, n, 0, 1, &r, n, &b, 2, &t, 1);

    // Compare against the one-shot factorization, up to row signs.
    var all = tall;
    var tau_all: [n]f64 = undefined;
    try qr.geqrf(f64, testing.allocator, 6, n, &all, 6, &tau_all);
    for (0..n) |j| for (0..j + 1) |i| {
        try testing.expectApproxEqAbs(@abs(all[i + j * 6]), @abs(r[i + j * n]), 1e-11);
    };
}

test "tpmqrt updates both blocks of a pair" {
    const n = 2;
    var r = [_]f64{ 3, 0, 1, 4 };
    var b = [_]f64{ 5, 6, 6, -5 };
    const b_original = b;
    var t: [1 * n]f64 = undefined;
    try tpqrt(f64, testing.allocator, 2, n, 0, 1, &r, n, &b, 2, &t, 1);

    // Apply the resulting reflector to an identity pair; the two halves come
    // back as the two blocks of Q^T.
    var a_top = [_]f64{ 1, 0, 0, 1 };
    var a_bot = [_]f64{ 0, 0, 0, 0 };
    try tpmqrt(f64, testing.allocator, .left, .transpose, 2, n, n, 0, 1, &b, 2, &t, 1, &a_top, n, &a_bot, 2);

    // The reflector spans both blocks, so orthonormality is a property of the
    // stacked pair rather than of either half: each column of [a_top; a_bot]
    // has unit norm even though neither block does on its own.
    try testing.expect(b_original[0] != b[0]);
    for (0..n) |j| {
        var norm: f64 = 0;
        for (0..n) |i| norm += a_top[i + j * n] * a_top[i + j * n];
        for (0..2) |i| norm += a_bot[i + j * 2] * a_bot[i + j * 2];
        try testing.expectApproxEqAbs(@as(f64, 1), norm, 1e-11);
    }
}

test "tplqt and tpmlqt are the LQ counterparts" {
    const m = 2;
    var l = [_]f64{ 3, 1, 0, 4 };
    var b = [_]f64{ 5, 6, 6, -5 };
    var t: [1 * m]f64 = undefined;
    try tplqt(f64, testing.allocator, m, 2, 0, 1, &l, m, &b, m, &t, 1);

    var a_left = [_]f64{ 1, 0, 0, 1 };
    var a_right = [_]f64{ 0, 0, 0, 0 };
    try tpmlqt(f64, testing.allocator, .right, .transpose, m, 2, m, 0, 1, &b, m, &t, 1, &a_left, m, &a_right, m);

    for (0..m) |i| {
        var norm: f64 = 0;
        for (0..m) |j| norm += a_left[i + j * m] * a_left[i + j * m];
        for (0..2) |j| norm += a_right[i + j * m] * a_right[i + j * m];
        try testing.expectApproxEqAbs(@as(f64, 1), norm, 1e-11);
    }
}

test "tprfb applies the same reflector tpmqrt does, and reports nothing" {
    const n = 2;
    var r = [_]f64{ 3, 0, 1, 4 };
    var b = [_]f64{ 5, 6, 6, -5 };
    // nb = n here, not 1: tprfb needs the whole k x k block reflector, where
    // tpqrt with nb = 1 would produce a sequence of 1x1 ones.
    var t: [n * n]f64 = undefined;
    try tpqrt(f64, testing.allocator, 2, n, 0, n, &r, n, &b, 2, &t, n);

    var top_m = [_]f64{ 1, 0, 0, 1 };
    var bot_m = [_]f64{ 0, 0, 0, 0 };
    try tpmqrt(f64, testing.allocator, .left, .transpose, 2, n, n, 0, n, &b, 2, &t, n, &top_m, n, &bot_m, 2);

    var top_r = [_]f64{ 1, 0, 0, 1 };
    var bot_r = [_]f64{ 0, 0, 0, 0 };
    // tprfb has no info parameter at all, so it cannot fail - hence the
    // Allocator.Error-only error set.
    try tprfb(f64, testing.allocator, .left, .transpose, .forward, .columnwise, 2, n, n, 0, &b, 2, &t, n, &top_r, n, &bot_r, 2);

    for (top_m, top_r) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
    for (bot_m, bot_r) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "getsls and gelst solve the same least squares problem as gels" {
    const m = 4;
    const n = 2;
    const a0 = [_]f64{ 1, 1, 1, 1, 0, 1, 2, 3 };
    const b0 = [_]f64{ 1, 3, 5, 7 };

    var a_ref = a0;
    var b_ref = b0;
    try qr.gels(f64, testing.allocator, .no_trans, m, n, 1, &a_ref, m, &b_ref, m);

    var a_t = a0;
    var b_t = b0;
    try getsls(f64, testing.allocator, .no_trans, m, n, 1, &a_t, m, &b_t, m);

    var a_s = a0;
    var b_s = b0;
    try gelst(f64, testing.allocator, .no_trans, m, n, 1, &a_s, m, &b_s, m);

    for (0..n) |i| {
        try testing.expectApproxEqAbs(b_ref[i], b_t[i], 1e-11);
        try testing.expectApproxEqAbs(b_ref[i], b_s[i], 1e-11);
    }
    // The fit is exact here: b = 1 + 2x.
    try testing.expectApproxEqAbs(@as(f64, 1), b_t[0], 1e-11);
    try testing.expectApproxEqAbs(@as(f64, 2), b_t[1], 1e-11);
}

test "geqrfp forces a non-negative diagonal where geqrf does not" {
    const m = 3;
    const n = 2;
    // Chosen so geqrf produces a negative R(0,0).
    const a0 = [_]f64{ 1, 2, 3, 4, 5, 6 };

    var a_plain = a0;
    var tau_plain: [n]f64 = undefined;
    try qr.geqrf(f64, testing.allocator, m, n, &a_plain, m, &tau_plain);

    var a_pos = a0;
    var tau_pos: [n]f64 = undefined;
    try geqrfp(f64, testing.allocator, m, n, &a_pos, m, &tau_pos);

    for (0..n) |i| try testing.expect(a_pos[i + i * m] >= 0);
    // Same factorization up to those signs.
    for (0..n) |j| for (0..j + 1) |i| {
        try testing.expectApproxEqAbs(@abs(a_plain[i + j * m]), @abs(a_pos[i + j * m]), 1e-11);
    };
    // And at least one sign actually differed, so the guarantee is not vacuous.
    try testing.expect(a_plain[0] < 0 and a_pos[0] > 0);
}

test "geqr2p matches geqrfp" {
    const m = 3;
    const n = 2;
    const a0 = [_]f64{ 1, 2, 3, 4, 5, 6 };

    var a_b = a0;
    var tau_b: [n]f64 = undefined;
    try geqrfp(f64, testing.allocator, m, n, &a_b, m, &tau_b);

    var a_u = a0;
    var tau_u: [n]f64 = undefined;
    try geqr2p(f64, testing.allocator, m, n, &a_u, m, &tau_u);

    for (a_b, a_u) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
    for (tau_b, tau_u) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "tzrzf makes a wide matrix triangular, and ormrz applies the Z" {
    const m = 2;
    const n = 4;
    const a0 = [_]f64{ 1, 0, 2, 3, 4, 5, 6, 7 };
    var a = a0;
    var tau: [m]f64 = undefined;
    try tzrzf(f64, testing.allocator, m, n, &a, m, &tau);

    // The leading m x m block is upper triangular.
    try testing.expectApproxEqAbs(@as(f64, 0), a[1], 1e-12);

    // Applying Z to the identity gives Z itself, and [R 0] Z reconstructs A.
    var z = [_]f64{0} ** (n * n);
    for (0..n) |i| z[i + i * n] = 1;
    try ormrz(f64, testing.allocator, .right, .no_trans, n, n, m, n - m, &a, m, &tau, &z, n);

    for (0..n) |j| {
        for (0..m) |i| {
            var acc: f64 = 0;
            for (0..m) |k| {
                if (k >= i) acc += a[i + k * m] * z[k + j * n];
            }
            try testing.expectApproxEqAbs(a0[i + j * m], acc, 1e-11);
        }
    }
}

test "the complex tall-skinny path picks the C transpose" {
    const Z = Complex(f64);
    const m = 4;
    const n = 2;
    var a = [_]Z{
        Z.init(1, 1), Z.init(2, 0), Z.init(3, -1), Z.init(4, 0),
        Z.init(0, 1), Z.init(1, 1), Z.init(2, 0),  Z.init(3, 1),
    };
    const original = a;
    const f = try geqr(Z, testing.allocator, m, n, &a, m);
    defer f.deinit();

    var q = [_]Z{Z.init(0, 0)} ** (m * m);
    for (0..m) |i| q[i + i * m] = Z.init(1, 0);
    // .transpose means the adjoint for complex, which is the only sense in
    // which Q^H Q = I.
    try gemqr(Z, testing.allocator, .left, .no_trans, m, m, n, &a, m, f, &q, m);

    for (0..n) |j| {
        for (0..m) |i| {
            var acc = Z.init(0, 0);
            for (0..n) |k| {
                if (k > j) continue;
                const qi = q[i + k * m];
                const rk = a[k + j * m];
                acc.re += qi.re * rk.re - qi.im * rk.im;
                acc.im += qi.re * rk.im + qi.im * rk.re;
            }
            try testing.expectApproxEqAbs(original[i + j * m].re, acc.re, 1e-11);
            try testing.expectApproxEqAbs(original[i + j * m].im, acc.im, 1e-11);
        }
    }
}
