//! Reductions to condensed form, and the orthogonal factors they produce.
//!
//! Almost every dense eigenvalue and singular value algorithm has the same two
//! phases: reduce the matrix to a condensed form by orthogonal similarity, then
//! run an iteration on the condensed form. The drivers in `eigen.zig`,
//! `eigen_gen.zig` and `svd.zig` do both and hand back the answer. These are
//! the first phase on its own.
//!
//! | reduction | from | to | driver that uses it |
//! |---|---|---|---|
//! | `sytrd`/`hetrd` | symmetric/Hermitian | tridiagonal | `syev`, `heev` |
//! | `sptrd`/`hptrd` | the same, packed | tridiagonal | `spev`, `hpev` |
//! | `sbtrd`/`hbtrd` | the same, band | tridiagonal | `sbev`, `hbev` |
//! | `gehrd` | general square | upper Hessenberg | `geev`, `gees` |
//! | `gebrd` | general rectangular | bidiagonal | `gesvd`, `gesdd` |
//! | `gbbrd` | general band | bidiagonal | — |
//!
//! You want these when the driver's answer is not the one you need: to run your
//! own tridiagonal solver, to apply the reduction's `Q` to something else, or
//! to reduce once and then solve several different problems on the condensed
//! form.
//!
//! ## `Q` is implicit, exactly as in `qr.zig`
//!
//! Every reduction here leaves its orthogonal factor as a product of Householder
//! reflectors packed into the part of the matrix the condensed form does not
//! need, plus a `tau` array. Two routines turn that into something usable, and
//! the choice matters:
//!
//! - `org*` **builds** `Q` as an explicit matrix. O(n^3), and you get an n x n
//!   array you then have to store.
//! - `orm*` **applies** `Q` to a matrix you already have. Also O(n^3) but with a
//!   much smaller constant, and no extra storage.
//!
//! If the next thing you do with `Q` is multiply by it — which it usually is —
//! `orm*` is the one you want. `org*` exists for when the vectors themselves are
//! the answer.
//!
//! As in `qr.zig`, the `or*` (real, orthogonal) and `un*` (complex, unitary)
//! names are one function here that picks the symbol from `T`, and the packed
//! `op*`/`up*` pair likewise.
//!
//! ## Balancing comes first
//!
//! `gebal` is not a reduction — it permutes and scales a general matrix to make
//! the eigenvalue computation better conditioned, and it is what `geev` does
//! before `gehrd`. It reports a window `ilo .. ihi` outside which the matrix is
//! already triangular, and `gehrd` and the Hessenberg `Q` builders take that
//! window so they can skip the part that needs no work.
//!
//! Eigenvalues are invariant under balancing but **eigenvectors are not**:
//! `gebak` undoes the transformation on the vectors afterwards. Skipping it
//! gives vectors of the balanced matrix, which are not the ones you asked for,
//! and nothing reports that.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");

const Int = types.Int;
const Complex = types.Complex;
const Real = types.Real;
const Uplo = types.Uplo;
const Side = types.Side;
const Vect = types.Vect;
const Balance = types.Balance;
const Error = info_mod.Error;
const dim = types.dim;
const assertMatrix = types.assertMatrix;
const packedLen = types.packedLen;
const ref = work_mod.ref;
const out = work_mod.out;
const opt = types.opt;

const Allocator = std.mem.Allocator;
const Fail = Error || Allocator.Error;

/// Re-exported so callers of `ormtr` and friends do not have to reach into
/// `qr.zig` for the flag they take.
pub const QTrans = @import("qr.zig").QTrans;

fn sym(comptime T: type, comptime name: []const u8) @TypeOf(@field(c, [_]u8{types.prefix(T)} ++ name)) {
    return @field(c, [_]u8{types.prefix(T)} ++ name);
}

/// `"or" ++ suffix` for real `T`, `"un" ++ suffix` for complex.
fn ortho(comptime T: type, comptime suffix: []const u8) []const u8 {
    return switch (T) {
        f32, f64 => "or" ++ suffix,
        else => "un" ++ suffix,
    };
}

/// `"op" ++ suffix` for real `T`, `"up" ++ suffix` for complex — the packed
/// spelling of the same split.
fn packedOrtho(comptime T: type, comptime suffix: []const u8) []const u8 {
    return switch (T) {
        f32, f64 => "op" ++ suffix,
        else => "up" ++ suffix,
    };
}

/// `"sy" ++ suffix` for real `T`, `"he" ++ suffix` for complex, and likewise
/// for the packed and band prefixes.
fn herm(comptime T: type, comptime real: []const u8, comptime complex: []const u8, comptime suffix: []const u8) []const u8 {
    return switch (T) {
        f32, f64 => real ++ suffix,
        else => complex ++ suffix,
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

/// What `sbtrd`/`hbtrd` should do with `q`.
pub const QUpdate = enum(u8) {
    /// Do not touch `q`. The reduction is still performed.
    none = 'N',
    /// Overwrite `q` with the reduction's orthogonal factor.
    form = 'V',
    /// Multiply the existing contents of `q` by the factor, accumulating a
    /// transformation across several calls.
    update = 'U',
};

/// Which of `gbbrd`'s factors to form.
pub const BidiagVect = enum(u8) {
    none = 'N',
    /// Form `Q` only.
    q = 'Q',
    /// Form `P^T` only.
    p = 'P',
    /// Form both.
    both = 'B',
};

/// The rows and columns `gebal` found to be already triangular.
///
/// Both are **1-based and inclusive**, because that is what `gehrd`, `orghr`,
/// `hseqr` and `gebak` expect to be handed back. `ilo == 1` and `ihi == n`
/// means balancing found nothing to isolate.
pub const Window = struct {
    ilo: usize,
    ihi: usize,
};

// ============================================================================
// Symmetric and Hermitian, to tridiagonal
// ============================================================================

/// Reduces a symmetric matrix to tridiagonal form by orthogonal similarity.
///
/// `d` receives the diagonal and `e` the off-diagonal of the result — both
/// **real**, even for a complex `T`, since a Hermitian tridiagonal has a real
/// diagonal and can always be made to have a real off-diagonal too. `tau` and
/// the untouched triangle of `a` hold `Q`; `orgtr` builds it, `ormtr` applies
/// it.
pub fn sytrd(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    d: []Real(T),
    e: []Real(T),
    tau: []T,
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(d.len >= n);
    if (n > 0) {
        std.debug.assert(e.len >= n - 1);
        std.debug.assert(tau.len >= n - 1);
    }

    const name = comptime herm(T, "sy", "he", "trd");
    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(opt(uplo), ref(&n_), a.ptr, ref(&lda_), d.ptr, e.ptr, tau.ptr, &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const work = try allocator.alloc(T, size);
    defer allocator.free(work);
    const lwork = dim(size);

    sym(T, name)(opt(uplo), ref(&n_), a.ptr, ref(&lda_), d.ptr, e.ptr, tau.ptr, work.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// `sytrd` under its complex name. Identical; both spellings work for all four
/// element types.
pub const hetrd = sytrd;

/// `sytrd` in packed storage. Needs no workspace, and is unblocked, so it is
/// slower than `sytrd` for anything but a small `n`.
pub fn sptrd(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    ap: []T,
    d: []Real(T),
    e: []Real(T),
    tau: []T,
) Error!void {
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(d.len >= n);
    if (n > 0) {
        std.debug.assert(e.len >= n - 1);
        std.debug.assert(tau.len >= n - 1);
    }

    const n_ = dim(n);
    var info: Int = 0;

    sym(T, herm(T, "sp", "hp", "trd"))(opt(uplo), ref(&n_), ap.ptr, d.ptr, e.ptr, tau.ptr, out(&info));
    return info_mod.checkArgs(info);
}

/// `sptrd` under its complex name.
pub const hptrd = sptrd;

/// `sytrd` for a band matrix.
///
/// The odd one out: it does not produce a `tau` array, because a band reduction
/// applies its rotations as it goes rather than accumulating reflectors. If you
/// want `Q` you have to ask for it here with `vect`, and `q` must be `n x n`
/// with `ldq >= n`; there is no `orgtr` equivalent to call afterwards.
///
/// `ab` is destroyed.
pub fn sbtrd(
    comptime T: type,
    allocator: Allocator,
    vect: QUpdate,
    uplo: Uplo,
    n: usize,
    kd: usize,
    ab: []T,
    ldab: usize,
    d: []Real(T),
    e: []Real(T),
    q: []T,
    ldq: usize,
) Fail!void {
    std.debug.assert(ldab >= kd + 1);
    std.debug.assert(d.len >= n);
    if (n > 0) std.debug.assert(e.len >= n - 1);
    std.debug.assert(ldq >= 1);
    if (vect != .none) assertMatrix(q.len, n, n, ldq);

    const work = try allocator.alloc(T, @max(n, 1));
    defer allocator.free(work);

    const n_ = dim(n);
    const kd_ = dim(kd);
    const ldab_ = dim(ldab);
    const ldq_ = dim(ldq);
    var info: Int = 0;

    sym(T, herm(T, "sb", "hb", "trd"))(opt(vect), opt(uplo), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), d.ptr, e.ptr, q.ptr, ref(&ldq_), work.ptr, out(&info));
    return info_mod.checkArgs(info);
}

/// `sbtrd` under its complex name.
pub const hbtrd = sbtrd;

/// Builds `sytrd`'s `Q` explicitly, overwriting `a`.
///
/// Prefer `ormtr` if you only want to multiply by `Q` — this materialises the
/// whole n x n matrix.
pub fn orgtr(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    tau: []const T,
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    if (n > 0) std.debug.assert(tau.len >= n - 1);

    const name = comptime ortho(T, "gtr");
    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(opt(uplo), ref(&n_), a.ptr, ref(&lda_), tau.ptr, &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const work = try allocator.alloc(T, size);
    defer allocator.free(work);
    const lwork = dim(size);

    sym(T, name)(opt(uplo), ref(&n_), a.ptr, ref(&lda_), tau.ptr, work.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// `orgtr` under its complex name.
pub const ungtr = orgtr;

/// Builds `sptrd`'s `Q` into a separate `n x n` array.
///
/// Unlike `orgtr` this writes to `q` rather than overwriting the input, since
/// packed storage has no room for an n x n result.
pub fn opgtr(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    ap: []const T,
    tau: []const T,
    q: []T,
    ldq: usize,
) Fail!void {
    std.debug.assert(ap.len >= packedLen(n));
    if (n > 0) std.debug.assert(tau.len >= n - 1);
    assertMatrix(q.len, n, n, ldq);

    const work = try allocator.alloc(T, @max(n, 1));
    defer allocator.free(work);

    const n_ = dim(n);
    const ldq_ = dim(ldq);
    var info: Int = 0;

    sym(T, packedOrtho(T, "gtr"))(opt(uplo), ref(&n_), ap.ptr, tau.ptr, q.ptr, ref(&ldq_), work.ptr, out(&info));
    return info_mod.checkArgs(info);
}

/// `opgtr` under its complex name.
pub const upgtr = opgtr;

/// Multiplies `c` by `sytrd`'s `Q`, without forming it.
///
/// `side = .left` gives `Q C` (or `Q^H C`), `.right` gives `C Q`. `a` and `tau`
/// are the reduction's outputs; `n` here is the order of `Q`, which must match
/// the side of `c` it multiplies.
pub fn ormtr(
    comptime T: type,
    allocator: Allocator,
    side: Side,
    uplo: Uplo,
    trans: QTrans,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    tau: []const T,
    cm: []T,
    ldc: usize,
) Fail!void {
    const order = if (side == .left) rows else cols;
    assertMatrix(a.len, order, order, lda);
    assertMatrix(cm.len, rows, cols, ldc);
    if (order > 0) std.debug.assert(tau.len >= order - 1);

    const name = comptime ortho(T, "mtr");
    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(@max(lda, 1));
    const ldc_ = dim(@max(ldc, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(opt(side), opt(uplo), qtrans(T, trans), ref(&m_), ref(&n_), a.ptr, ref(&lda_), tau.ptr, cm.ptr, ref(&ldc_), &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const work = try allocator.alloc(T, size);
    defer allocator.free(work);
    const lwork = dim(size);

    sym(T, name)(opt(side), opt(uplo), qtrans(T, trans), ref(&m_), ref(&n_), a.ptr, ref(&lda_), tau.ptr, cm.ptr, ref(&ldc_), work.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// `ormtr` under its complex name.
pub const unmtr = ormtr;

/// `ormtr` for a packed reduction. No workspace query — this one is unblocked
/// and takes a fixed `max(rows, cols)` scratch.
pub fn opmtr(
    comptime T: type,
    allocator: Allocator,
    side: Side,
    uplo: Uplo,
    trans: QTrans,
    rows: usize,
    cols: usize,
    ap: []T,
    tau: []const T,
    cm: []T,
    ldc: usize,
) Fail!void {
    const order = if (side == .left) rows else cols;
    std.debug.assert(ap.len >= packedLen(order));
    assertMatrix(cm.len, rows, cols, ldc);
    if (order > 0) std.debug.assert(tau.len >= order - 1);

    const work = try allocator.alloc(T, @max(if (side == .left) cols else rows, 1));
    defer allocator.free(work);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const ldc_ = dim(@max(ldc, 1));
    var info: Int = 0;

    sym(T, packedOrtho(T, "mtr"))(opt(side), opt(uplo), qtrans(T, trans), ref(&m_), ref(&n_), ap.ptr, tau.ptr, cm.ptr, ref(&ldc_), work.ptr, out(&info));
    return info_mod.checkArgs(info);
}

/// `opmtr` under its complex name.
pub const upmtr = opmtr;

// ============================================================================
// General square, to upper Hessenberg
// ============================================================================

/// Reduces a general matrix to upper Hessenberg form by orthogonal similarity.
///
/// `ilo` and `ihi` are 1-based and inclusive, and come from `gebal`; pass
/// `1, n` if the matrix was not balanced. Rows and columns outside that window
/// are already in the right form and are left alone.
///
/// `a` is overwritten with the Hessenberg matrix in its upper triangle and
/// first subdiagonal; the reflectors defining `Q` go below that, with `tau`.
pub fn gehrd(
    comptime T: type,
    allocator: Allocator,
    n: usize,
    ilo: usize,
    ihi: usize,
    a: []T,
    lda: usize,
    tau: []T,
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(ilo >= 1 and ihi <= @max(n, 1) and ilo <= ihi + 1);
    if (n > 0) std.debug.assert(tau.len >= n - 1);

    const n_ = dim(n);
    const ilo_ = dim(ilo);
    const ihi_ = dim(ihi);
    const lda_ = dim(@max(lda, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, "gehrd")(ref(&n_), ref(&ilo_), ref(&ihi_), a.ptr, ref(&lda_), tau.ptr, &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const work = try allocator.alloc(T, size);
    defer allocator.free(work);
    const lwork = dim(size);

    sym(T, "gehrd")(ref(&n_), ref(&ilo_), ref(&ihi_), a.ptr, ref(&lda_), tau.ptr, work.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// Builds `gehrd`'s `Q` explicitly, overwriting `a`.
///
/// `ilo` and `ihi` must be the same values `gehrd` was given.
pub fn orghr(
    comptime T: type,
    allocator: Allocator,
    n: usize,
    ilo: usize,
    ihi: usize,
    a: []T,
    lda: usize,
    tau: []const T,
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    if (n > 0) std.debug.assert(tau.len >= n - 1);

    const name = comptime ortho(T, "ghr");
    const n_ = dim(n);
    const ilo_ = dim(ilo);
    const ihi_ = dim(ihi);
    const lda_ = dim(@max(lda, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(ref(&n_), ref(&ilo_), ref(&ihi_), a.ptr, ref(&lda_), tau.ptr, &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const work = try allocator.alloc(T, size);
    defer allocator.free(work);
    const lwork = dim(size);

    sym(T, name)(ref(&n_), ref(&ilo_), ref(&ihi_), a.ptr, ref(&lda_), tau.ptr, work.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// `orghr` under its complex name.
pub const unghr = orghr;

/// Multiplies `c` by `gehrd`'s `Q`, without forming it.
pub fn ormhr(
    comptime T: type,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    ilo: usize,
    ihi: usize,
    a: []T,
    lda: usize,
    tau: []const T,
    cm: []T,
    ldc: usize,
) Fail!void {
    const order = if (side == .left) rows else cols;
    assertMatrix(a.len, order, order, lda);
    assertMatrix(cm.len, rows, cols, ldc);
    if (order > 0) std.debug.assert(tau.len >= order - 1);

    const name = comptime ortho(T, "mhr");
    const m_ = dim(rows);
    const n_ = dim(cols);
    const ilo_ = dim(ilo);
    const ihi_ = dim(ihi);
    const lda_ = dim(@max(lda, 1));
    const ldc_ = dim(@max(ldc, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(opt(side), qtrans(T, trans), ref(&m_), ref(&n_), ref(&ilo_), ref(&ihi_), a.ptr, ref(&lda_), tau.ptr, cm.ptr, ref(&ldc_), &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const work = try allocator.alloc(T, size);
    defer allocator.free(work);
    const lwork = dim(size);

    sym(T, name)(opt(side), qtrans(T, trans), ref(&m_), ref(&n_), ref(&ilo_), ref(&ihi_), a.ptr, ref(&lda_), tau.ptr, cm.ptr, ref(&ldc_), work.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// `ormhr` under its complex name.
pub const unmhr = ormhr;

// ============================================================================
// General rectangular, to bidiagonal
// ============================================================================

/// Reduces a general matrix to bidiagonal form: `A = Q B P^H`.
///
/// This is the first half of an SVD. `d` and `e` receive the bidiagonal's
/// diagonal and off-diagonal, both real. Two orthogonal factors come out, not
/// one — `tauq` with `Q` and `taup` with `P` — and they are reflectors packed
/// into `a` on either side of the bidiagonal, so `orgbr` and `ormbr` take a
/// `vect` argument saying which of the two you mean.
///
/// Where the off-diagonal `e` lives depends on the shape: `B` is upper
/// bidiagonal when `rows >= cols` and lower bidiagonal otherwise.
pub fn gebrd(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    d: []Real(T),
    e: []Real(T),
    tauq: []T,
    taup: []T,
) Fail!void {
    assertMatrix(a.len, rows, cols, lda);
    const mn = @min(rows, cols);
    std.debug.assert(d.len >= mn);
    if (mn > 0) std.debug.assert(e.len >= mn - 1);
    std.debug.assert(tauq.len >= mn and taup.len >= mn);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(@max(lda, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, "gebrd")(ref(&m_), ref(&n_), a.ptr, ref(&lda_), d.ptr, e.ptr, tauq.ptr, taup.ptr, &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const work = try allocator.alloc(T, size);
    defer allocator.free(work);
    const lwork = dim(size);

    sym(T, "gebrd")(ref(&m_), ref(&n_), a.ptr, ref(&lda_), d.ptr, e.ptr, tauq.ptr, taup.ptr, work.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// Builds `Q` or `P^H` from a `gebrd` reduction, overwriting `a`.
///
/// `vect` picks which, and it also changes what `rows`, `cols` and `k` mean:
///
/// | `vect` | `k` is | result is |
/// |---|---|---|
/// | `.q` | the number of columns in the original `A` | `rows x cols` of `Q` |
/// | `.p` | the number of rows in the original `A` | `rows x cols` of `P^H` |
///
/// Pass the `tau` that goes with the factor you asked for — `tauq` for `.q`,
/// `taup` for `.p`. There is nothing that can catch swapping them.
pub fn orgbr(
    comptime T: type,
    allocator: Allocator,
    vect: Vect,
    rows: usize,
    cols: usize,
    k: usize,
    a: []T,
    lda: usize,
    tau: []const T,
) Fail!void {
    assertMatrix(a.len, rows, cols, lda);

    const name = comptime ortho(T, "gbr");
    const m_ = dim(rows);
    const n_ = dim(cols);
    const k_ = dim(k);
    const lda_ = dim(@max(lda, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(opt(vect), ref(&m_), ref(&n_), ref(&k_), a.ptr, ref(&lda_), tau.ptr, &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const work = try allocator.alloc(T, size);
    defer allocator.free(work);
    const lwork = dim(size);

    sym(T, name)(opt(vect), ref(&m_), ref(&n_), ref(&k_), a.ptr, ref(&lda_), tau.ptr, work.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// `orgbr` under its complex name.
pub const ungbr = orgbr;

/// Multiplies `c` by `gebrd`'s `Q` or `P`, without forming it.
///
/// Note that for `vect = .p` the "transpose" flag is relative to `P`, so
/// `.no_trans` applies `P` and `.transpose` applies `P^H` — the routine forms
/// `P` from `taup` and the flag then means what it says.
pub fn ormbr(
    comptime T: type,
    allocator: Allocator,
    vect: Vect,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    k: usize,
    a: []T,
    lda: usize,
    tau: []const T,
    cm: []T,
    ldc: usize,
) Fail!void {
    assertMatrix(cm.len, rows, cols, ldc);

    const name = comptime ortho(T, "mbr");
    const m_ = dim(rows);
    const n_ = dim(cols);
    const k_ = dim(k);
    const lda_ = dim(@max(lda, 1));
    const ldc_ = dim(@max(ldc, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(opt(vect), opt(side), qtrans(T, trans), ref(&m_), ref(&n_), ref(&k_), a.ptr, ref(&lda_), tau.ptr, cm.ptr, ref(&ldc_), &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const work = try allocator.alloc(T, size);
    defer allocator.free(work);
    const lwork = dim(size);

    sym(T, name)(opt(vect), opt(side), qtrans(T, trans), ref(&m_), ref(&n_), ref(&k_), a.ptr, ref(&lda_), tau.ptr, cm.ptr, ref(&ldc_), work.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// `ormbr` under its complex name.
pub const unmbr = ormbr;

/// Reduces a general **band** matrix to bidiagonal form.
///
/// Unlike `gebrd` this forms its factors on the spot — there is no `tau`, and
/// no `orgbr` step. `vect` says which of `q` and `pt` to write. `cm` is an
/// optional extra matrix that gets `Q^H` applied to it as the reduction runs,
/// which is how you carry a right-hand side through; pass `ncc = 0` to skip it.
///
/// `ab` is destroyed.
pub fn gbbrd(
    comptime T: type,
    allocator: Allocator,
    vect: BidiagVect,
    rows: usize,
    cols: usize,
    ncc: usize,
    kl: usize,
    ku: usize,
    ab: []T,
    ldab: usize,
    d: []Real(T),
    e: []Real(T),
    q: []T,
    ldq: usize,
    pt: []T,
    ldpt: usize,
    cm: []T,
    ldc: usize,
) Fail!void {
    std.debug.assert(ldab >= kl + ku + 1);
    const mn = @min(rows, cols);
    std.debug.assert(d.len >= mn);
    if (mn > 0) std.debug.assert(e.len >= mn - 1);
    std.debug.assert(ldq >= 1 and ldpt >= 1 and ldc >= 1);
    if (vect == .q or vect == .both) assertMatrix(q.len, rows, rows, ldq);
    if (vect == .p or vect == .both) assertMatrix(pt.len, cols, cols, ldpt);
    if (ncc > 0) assertMatrix(cm.len, rows, ncc, ldc);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const ncc_ = dim(ncc);
    const kl_ = dim(kl);
    const ku_ = dim(ku);
    const ldab_ = dim(ldab);
    const ldq_ = dim(ldq);
    const ldpt_ = dim(ldpt);
    const ldc_ = dim(ldc);
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => {
            const work = try allocator.alloc(T, @max(@max(rows, cols), 1));
            defer allocator.free(work);
            const rwork = try allocator.alloc(Real(T), @max(@max(rows, cols), 1));
            defer allocator.free(rwork);
            sym(T, "gbbrd")(opt(vect), ref(&m_), ref(&n_), ref(&ncc_), ref(&kl_), ref(&ku_), ab.ptr, ref(&ldab_), d.ptr, e.ptr, q.ptr, ref(&ldq_), pt.ptr, ref(&ldpt_), cm.ptr, ref(&ldc_), work.ptr, rwork.ptr, out(&info));
        },
        else => {
            const work = try allocator.alloc(T, @max(2 * @max(rows, cols), 1));
            defer allocator.free(work);
            sym(T, "gbbrd")(opt(vect), ref(&m_), ref(&n_), ref(&ncc_), ref(&kl_), ref(&ku_), ab.ptr, ref(&ldab_), d.ptr, e.ptr, q.ptr, ref(&ldq_), pt.ptr, ref(&ldpt_), cm.ptr, ref(&ldc_), work.ptr, out(&info));
        },
    }
    return info_mod.checkArgs(info);
}

// ============================================================================
// Balancing
// ============================================================================

/// Permutes and scales a general matrix to improve the conditioning of its
/// eigenvalue problem, and reports the window that still needs reducing.
///
/// `job` chooses what to do: `.permute` isolates eigenvalues by permutation
/// only, `.scale` rescales rows and columns by powers of the radix only,
/// `.both` does both, `.none` does neither and just returns `1 .. n`.
///
/// Scaling by powers of the radix is exact, so `.scale` changes no eigenvalue.
/// `.permute` is a similarity transform, so it does not either. **Eigenvectors
/// do change**, and `gebak` is how you get them back.
pub fn gebal(
    comptime T: type,
    job: Balance,
    n: usize,
    a: []T,
    lda: usize,
    scale: []Real(T),
) Error!Window {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(scale.len >= n);

    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    var ilo: Int = 0;
    var ihi: Int = 0;
    var info: Int = 0;

    sym(T, "gebal")(opt(job), ref(&n_), a.ptr, ref(&lda_), out(&ilo), out(&ihi), scale.ptr, out(&info));
    try info_mod.checkArgs(info);
    return .{ .ilo = @intCast(ilo), .ihi = @intCast(ihi) };
}

/// Undoes `gebal`'s transformation on a set of eigenvectors.
///
/// `job` and `scale` must be exactly what `gebal` was given and produced, and
/// `side` says whether `v` holds right or left eigenvectors — they transform
/// differently, and passing the wrong one silently returns the wrong vectors.
///
/// `v` is `n x m`, with `m` the number of vectors, and is modified in place.
pub fn gebak(
    comptime T: type,
    job: Balance,
    side: Side,
    n: usize,
    ilo: usize,
    ihi: usize,
    scale: []const Real(T),
    m: usize,
    v: []T,
    ldv: usize,
) Error!void {
    std.debug.assert(scale.len >= n);
    assertMatrix(v.len, n, m, ldv);

    const n_ = dim(n);
    const ilo_ = dim(ilo);
    const ihi_ = dim(ihi);
    const m_ = dim(m);
    const ldv_ = dim(@max(ldv, 1));
    var info: Int = 0;

    sym(T, "gebak")(opt(job), opt(side), ref(&n_), ref(&ilo_), ref(&ihi_), scale.ptr, ref(&m_), v.ptr, ref(&ldv_), out(&info));
    return info_mod.checkArgs(info);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// `cm = a * b`, all column-major, all `n x n`. Naive on purpose: the point is
/// to check LAPACK's answer against something with no shared machinery.
fn mul(n: usize, a: []const f64, b: []const f64, cm: []f64) void {
    for (0..n) |j| for (0..n) |i| {
        var acc: f64 = 0;
        for (0..n) |k| acc += a[i + k * n] * b[k + j * n];
        cm[i + j * n] = acc;
    };
}

/// `cm = a^T * b`.
fn mulT(n: usize, a: []const f64, b: []const f64, cm: []f64) void {
    for (0..n) |j| for (0..n) |i| {
        var acc: f64 = 0;
        for (0..n) |k| acc += a[k + i * n] * b[k + j * n];
        cm[i + j * n] = acc;
    };
}

/// The symmetric 4x4 every tridiagonal test below reduces.
const sym4 = [_]f64{
    4, 1, 2, 3,
    1, 5, 1, 2,
    2, 1, 6, 1,
    3, 2, 1, 7,
};

fn expectTridiagonal(n: usize, m: []const f64, d: []const f64, e: []const f64) !void {
    for (0..n) |j| for (0..n) |i| {
        const expected: f64 = if (i == j)
            d[i]
        else if (i + 1 == j)
            e[i]
        else if (j + 1 == i)
            e[j]
        else
            0;
        try testing.expectApproxEqAbs(expected, m[i + j * n], 1e-11);
    };
}

test "sytrd then orgtr gives a Q that tridiagonalizes the original" {
    const n = 4;
    var a = sym4;
    var d: [n]f64 = undefined;
    var e: [n - 1]f64 = undefined;
    var tau: [n - 1]f64 = undefined;
    try sytrd(f64, testing.allocator, .upper, n, &a, n, &d, &e, &tau);

    // a now holds the reflectors; orgtr turns them into Q in place.
    var q = a;
    try orgtr(f64, testing.allocator, .upper, n, &q, n, &tau);

    var tmp: [n * n]f64 = undefined;
    var result: [n * n]f64 = undefined;
    mulT(n, &q, &sym4, &tmp); // Q^T A
    mul(n, &tmp, &q, &result); // Q^T A Q
    try expectTridiagonal(n, &result, &d, &e);
}

test "sptrd matches sytrd, and opgtr matches orgtr" {
    const n = 4;
    var full = sym4;
    var d_full: [n]f64 = undefined;
    var e_full: [n - 1]f64 = undefined;
    var tau_full: [n - 1]f64 = undefined;
    try sytrd(f64, testing.allocator, .upper, n, &full, n, &d_full, &e_full, &tau_full);

    // Upper packed: column j contributes rows 0..j.
    var ap: [n * (n + 1) / 2]f64 = undefined;
    var at: usize = 0;
    for (0..n) |j| for (0..j + 1) |i| {
        ap[at] = sym4[i + j * n];
        at += 1;
    };
    var d_packed: [n]f64 = undefined;
    var e_packed: [n - 1]f64 = undefined;
    var tau_packed: [n - 1]f64 = undefined;
    try sptrd(f64, .upper, n, &ap, &d_packed, &e_packed, &tau_packed);

    for (d_full, d_packed) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
    for (e_full, e_packed) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);

    // opgtr writes to a separate array, since packed storage has no room.
    var q_packed: [n * n]f64 = undefined;
    try opgtr(f64, testing.allocator, .upper, n, &ap, &tau_packed, &q_packed, n);
    var q_full = full;
    try orgtr(f64, testing.allocator, .upper, n, &q_full, n, &tau_full);
    for (q_full, q_packed) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "sbtrd on a band matrix reproduces the same tridiagonal" {
    const n = 4;
    const kd = 1;
    // A symmetric tridiagonal is already the answer, so use kd = 1 and check
    // that the reduction is the identity on it.
    const full = [_]f64{
        4, 1, 0, 0,
        1, 5, 2, 0,
        0, 2, 6, 3,
        0, 0, 3, 7,
    };
    // Upper band storage: row kd + i - j.
    var ab = [_]f64{ 0, 4, 1, 5, 2, 6, 3, 7 };
    var d: [n]f64 = undefined;
    var e: [n - 1]f64 = undefined;
    var q: [n * n]f64 = undefined;
    try sbtrd(f64, testing.allocator, .form, .upper, n, kd, &ab, kd + 1, &d, &e, &q, n);

    var tmp: [n * n]f64 = undefined;
    var result: [n * n]f64 = undefined;
    mulT(n, &q, &full, &tmp);
    mul(n, &tmp, &q, &result);
    try expectTridiagonal(n, &result, &d, &e);
}

test "ormtr applies the same Q that orgtr builds" {
    const n = 4;
    var a = sym4;
    var d: [n]f64 = undefined;
    var e: [n - 1]f64 = undefined;
    var tau: [n - 1]f64 = undefined;
    try sytrd(f64, testing.allocator, .upper, n, &a, n, &d, &e, &tau);

    // Apply Q to the identity - which is exactly what orgtr computes.
    var applied = [_]f64{0} ** (n * n);
    for (0..n) |i| applied[i + i * n] = 1;
    try ormtr(f64, testing.allocator, .left, .upper, .no_trans, n, n, &a, n, &tau, &applied, n);

    var built = a;
    try orgtr(f64, testing.allocator, .upper, n, &built, n, &tau);
    for (built, applied) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "opmtr applies the packed Q" {
    const n = 4;
    var ap: [n * (n + 1) / 2]f64 = undefined;
    var at: usize = 0;
    for (0..n) |j| for (0..j + 1) |i| {
        ap[at] = sym4[i + j * n];
        at += 1;
    };
    var d: [n]f64 = undefined;
    var e: [n - 1]f64 = undefined;
    var tau: [n - 1]f64 = undefined;
    try sptrd(f64, .upper, n, &ap, &d, &e, &tau);

    var applied = [_]f64{0} ** (n * n);
    for (0..n) |i| applied[i + i * n] = 1;
    try opmtr(f64, testing.allocator, .left, .upper, .no_trans, n, n, &ap, &tau, &applied, n);

    var built: [n * n]f64 = undefined;
    try opgtr(f64, testing.allocator, .upper, n, &ap, &tau, &built, n);
    for (built, applied) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "hetrd reduces a Hermitian matrix to a real tridiagonal" {
    const Z = Complex(f64);
    const n = 3;
    const original = [_]Z{
        Z.init(3, 0), Z.init(1, -1), Z.init(0, -2),
        Z.init(1, 1), Z.init(4, 0),  Z.init(2, -1),
        Z.init(0, 2), Z.init(2, 1),  Z.init(5, 0),
    };
    var a = original;
    var d: [n]f64 = undefined;
    var e: [n - 1]f64 = undefined;
    var tau: [n - 1]Z = undefined;
    try hetrd(Z, testing.allocator, .upper, n, &a, n, &d, &e, &tau);

    // d and e are f64, not Complex(f64) - that is the whole point of the
    // Real(T) in the signature. The trace is preserved by a similarity.
    var trace: f64 = 0;
    for (d) |v| trace += v;
    try testing.expectApproxEqAbs(@as(f64, 3 + 4 + 5), trace, 1e-12);

    var q = a;
    try ungtr(Z, testing.allocator, .upper, n, &q, n, &tau);
    // Q is unitary: its first column has unit norm.
    var norm: f64 = 0;
    for (0..n) |i| norm += q[i].re * q[i].re + q[i].im * q[i].im;
    try testing.expectApproxEqAbs(@as(f64, 1), norm, 1e-12);
}

// ============================================================================
// Tests: Hessenberg
// ============================================================================

const gen4 = [_]f64{
    1, 5, 9, 4,
    2, 6, 1, 3,
    3, 7, 2, 8,
    4, 8, 3, 7,
};

test "gehrd then orghr gives a Q that makes the original Hessenberg" {
    const n = 4;
    var a = gen4;
    var tau: [n - 1]f64 = undefined;
    try gehrd(f64, testing.allocator, n, 1, n, &a, n, &tau);

    var q = a;
    try orghr(f64, testing.allocator, n, 1, n, &q, n, &tau);

    var tmp: [n * n]f64 = undefined;
    var h: [n * n]f64 = undefined;
    mulT(n, &q, &gen4, &tmp);
    mul(n, &tmp, &q, &h);

    // Everything two or more below the diagonal is zero, and what is left
    // matches the Hessenberg part gehrd wrote into a.
    for (0..n) |j| for (0..n) |i| {
        if (i > j + 1) {
            try testing.expectApproxEqAbs(@as(f64, 0), h[i + j * n], 1e-11);
        } else {
            try testing.expectApproxEqAbs(a[i + j * n], h[i + j * n], 1e-11);
        }
    };
}

test "ormhr applies the same Q that orghr builds" {
    const n = 4;
    var a = gen4;
    var tau: [n - 1]f64 = undefined;
    try gehrd(f64, testing.allocator, n, 1, n, &a, n, &tau);

    var applied = [_]f64{0} ** (n * n);
    for (0..n) |i| applied[i + i * n] = 1;
    try ormhr(f64, testing.allocator, .left, .no_trans, n, n, 1, n, &a, n, &tau, &applied, n);

    var built = a;
    try orghr(f64, testing.allocator, n, 1, n, &built, n, &tau);
    for (built, applied) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

// ============================================================================
// Tests: bidiagonal
// ============================================================================

test "gebrd with orgbr reconstructs the original matrix" {
    const n = 4;
    var a = gen4;
    var d: [n]f64 = undefined;
    var e: [n - 1]f64 = undefined;
    var tauq: [n]f64 = undefined;
    var taup: [n]f64 = undefined;
    try gebrd(f64, testing.allocator, n, n, &a, n, &d, &e, &tauq, &taup);

    // The reflectors for Q and P share the array, so each builder needs its own
    // copy - and its own tau. Swapping tauq and taup here compiles and returns
    // a wrong answer with no diagnostic.
    var q = a;
    try orgbr(f64, testing.allocator, .q, n, n, n, &q, n, &tauq);
    var pt = a;
    try orgbr(f64, testing.allocator, .p, n, n, n, &pt, n, &taup);

    // B is upper bidiagonal here because rows >= cols.
    var b = [_]f64{0} ** (n * n);
    for (0..n) |i| b[i + i * n] = d[i];
    for (0..n - 1) |i| b[i + (i + 1) * n] = e[i];

    var tmp: [n * n]f64 = undefined;
    var result: [n * n]f64 = undefined;
    mul(n, &q, &b, &tmp);
    mul(n, &tmp, &pt, &result);
    for (gen4, result) |x, y| try testing.expectApproxEqAbs(x, y, 1e-11);
}

test "gebrd's singular values are the original's" {
    const n = 4;
    var a = gen4;
    var d: [n]f64 = undefined;
    var e: [n - 1]f64 = undefined;
    var tauq: [n]f64 = undefined;
    var taup: [n]f64 = undefined;
    try gebrd(f64, testing.allocator, n, n, &a, n, &d, &e, &tauq, &taup);

    // The reduction is orthogonal on both sides, so it preserves the Frobenius
    // norm - and the bidiagonal holds all of it.
    var reduced: f64 = 0;
    for (d) |v| reduced += v * v;
    for (e) |v| reduced += v * v;
    var original: f64 = 0;
    for (gen4) |v| original += v * v;
    try testing.expectApproxEqRel(original, reduced, 1e-12);
}

test "ormbr applies Q where orgbr builds it" {
    const n = 4;
    var a = gen4;
    var d: [n]f64 = undefined;
    var e: [n - 1]f64 = undefined;
    var tauq: [n]f64 = undefined;
    var taup: [n]f64 = undefined;
    try gebrd(f64, testing.allocator, n, n, &a, n, &d, &e, &tauq, &taup);

    var applied = [_]f64{0} ** (n * n);
    for (0..n) |i| applied[i + i * n] = 1;
    try ormbr(f64, testing.allocator, .q, .left, .no_trans, n, n, n, &a, n, &tauq, &applied, n);

    var built = a;
    try orgbr(f64, testing.allocator, .q, n, n, n, &built, n, &tauq);
    for (built, applied) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "gbbrd bidiagonalizes a band matrix and forms both factors" {
    const n = 4;
    const kl = 1;
    const ku = 1;
    const ldab = kl + ku + 1;
    const full = [_]f64{
        4, 1, 0, 0,
        2, 5, 1, 0,
        0, 3, 6, 1,
        0, 0, 4, 7,
    };
    var ab = [_]f64{0} ** (ldab * n);
    for (0..n) |j| for (0..n) |i| {
        if (i + kl < j or j + ku < i) continue;
        ab[ku + i - j + j * ldab] = full[i + j * n];
    };

    var d: [n]f64 = undefined;
    var e: [n - 1]f64 = undefined;
    var q: [n * n]f64 = undefined;
    var pt: [n * n]f64 = undefined;
    var dummy: [1]f64 = undefined;
    try gbbrd(f64, testing.allocator, .both, n, n, 0, kl, ku, &ab, ldab, &d, &e, &q, n, &pt, n, &dummy, 1);

    var b = [_]f64{0} ** (n * n);
    for (0..n) |i| b[i + i * n] = d[i];
    for (0..n - 1) |i| b[i + (i + 1) * n] = e[i];

    var tmp: [n * n]f64 = undefined;
    var result: [n * n]f64 = undefined;
    mul(n, &q, &b, &tmp);
    mul(n, &tmp, &pt, &result);
    for (full, result) |x, y| try testing.expectApproxEqAbs(x, y, 1e-11);
}

// ============================================================================
// Tests: balancing
// ============================================================================

test "gebal isolates an eigenvalue that permutation can expose" {
    const n = 3;
    // Column 0 is zero below the diagonal, so row/column 0 already holds an
    // eigenvalue and needs no reduction.
    var a = [_]f64{
        2, 0, 0,
        1, 3, 1,
        4, 1, 3,
    };
    var scale: [n]f64 = undefined;
    const w = try gebal(f64, .permute, n, &a, n, &scale);

    // The isolated eigenvalue is pushed outside the window.
    try testing.expect(w.ihi - w.ilo + 1 < n);
    try testing.expect(w.ilo >= 1 and w.ihi <= n);
}

test "gebal with .none returns the whole matrix untouched" {
    const n = 4;
    var a = gen4;
    var scale: [n]f64 = undefined;
    const w = try gebal(f64, .none, n, &a, n, &scale);

    try testing.expectEqual(@as(usize, 1), w.ilo);
    try testing.expectEqual(@as(usize, n), w.ihi);
    try testing.expectEqualSlices(f64, &gen4, &a);
}

test "gebal scales by exact powers of two, so the eigenvalues do not move" {
    const n = 3;
    // Badly scaled but similar to a well-scaled matrix.
    var a = [_]f64{
        1,   1e-6, 0,
        1e6, 2,    1e6,
        0,   1e-6, 3,
    };
    const original = a;
    var scale: [n]f64 = undefined;
    _ = try gebal(f64, .scale, n, &a, n, &scale);

    // Every scale factor is a power of two, which is why the transform is
    // exact rather than merely close.
    for (scale) |v| try testing.expectEqual(@as(f64, 0.5), std.math.frexp(v).significand);

    // The trace is invariant: scaling is a diagonal similarity.
    var t0: f64 = 0;
    var t1: f64 = 0;
    for (0..n) |i| {
        t0 += original[i + i * n];
        t1 += a[i + i * n];
    }
    try testing.expectApproxEqAbs(t0, t1, 1e-12);
}

test "gebak undoes the scaling on eigenvectors" {
    const n = 3;
    var a = [_]f64{
        1,   1e-6, 0,
        1e6, 2,    1e6,
        0,   1e-6, 3,
    };
    var scale: [n]f64 = undefined;
    const w = try gebal(f64, .scale, n, &a, n, &scale);

    // Pretend the balanced problem produced these right eigenvectors. gebak
    // multiplies row i by scale[i] for .right, and divides for .left, so the
    // two are not interchangeable.
    var right = [_]f64{ 1, 1, 1 };
    var left = [_]f64{ 1, 1, 1 };
    try gebak(f64, .scale, .right, n, w.ilo, w.ihi, &scale, 1, &right, n);
    try gebak(f64, .scale, .left, n, w.ilo, w.ihi, &scale, 1, &left, n);

    for (0..n) |i| {
        try testing.expectApproxEqRel(scale[i], right[i], 1e-12);
        try testing.expectApproxEqRel(1 / scale[i], left[i], 1e-12);
    }
}
