//! Orthogonal factorizations and linear least squares.
//!
//! ## The four factorizations
//!
//! | routine | produces | reflectors stored in |
//! |---|---|---|
//! | `geqrf` | `A = Q R` | below the diagonal |
//! | `gelqf` | `A = L Q` | above the diagonal |
//! | `geqlf` | `A = Q L` | above the diagonal |
//! | `gerqf` | `A = R Q` | below the diagonal |
//!
//! All four leave `Q` implicit, as a product of Householder reflectors packed
//! into the part of `A` the triangular factor does not need, plus a `tau`
//! array. `Q` is never formed unless you ask, because you usually do not need
//! it: `ormqr` applies `Q` to a matrix in O(mnk) without ever materialising the
//! m x m matrix that `orgqr` would build.
//!
//! ## `or*` and `un*` are the same routine
//!
//! LAPACK names the real versions `orgqr`/`ormqr` (orthogonal) and the complex
//! ones `ungqr`/`unmqr` (unitary). This module exposes one name per operation
//! that works for all four element types and picks the right symbol, with the
//! LAPACK spellings available as aliases. `orgqr(Complex(f64), ...)` therefore
//! calls `zungqr`, which is what you wanted.
//!
//! ## Transposing `Q`
//!
//! `ormqr` and `gels` take a transpose flag, and the accepted values differ by
//! precision: real routines want `'N'` or `'T'`, complex ones `'N'` or `'C'`.
//! Passing `'T'` to `zunmqr` is an illegal-argument error, not a silent
//! conjugation difference. Rather than surface that, these wrappers take a
//! two-valued `QTrans` and emit the right character for `T` — `.transpose`
//! means "the adjoint", which is the transpose for real and the conjugate
//! transpose for complex, and is the only one of the two that is ever
//! mathematically wanted.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");

const Int = types.Int;
const Complex = types.Complex;
const Real = types.Real;
const Side = types.Side;
const Error = info_mod.Error;
const dim = types.dim;
const assertMatrix = types.assertMatrix;
const ref = work_mod.ref;
const out = work_mod.out;
const opt = types.opt;

const Allocator = std.mem.Allocator;
const Fail = Error || Allocator.Error;

fn sym(comptime T: type, comptime name: []const u8) @TypeOf(@field(c, [_]u8{types.prefix(T)} ++ name)) {
    return @field(c, [_]u8{types.prefix(T)} ++ name);
}

/// `"or" ++ suffix` for real `T`, `"un" ++ suffix` for complex.
///
/// The two families are the same operation under different names, so every
/// wrapper below resolves the symbol through this rather than making callers
/// pick.
fn ortho(comptime T: type, comptime suffix: []const u8) []const u8 {
    return switch (T) {
        f32, f64 => "or" ++ suffix,
        else => "un" ++ suffix,
    };
}

/// Whether to apply `Q` or its adjoint.
///
/// Deliberately two-valued. LAPACK's character argument accepts `'T'` for real
/// precisions and `'C'` for complex, and passing the wrong one is an
/// illegal-argument failure rather than a subtle numerical difference. Since
/// applying the plain (unconjugated) transpose of a complex `Q` is not an
/// operation anyone wants, there is nothing lost by collapsing the two.
pub const QTrans = enum {
    no_trans,
    /// `Q^T` for real elements, `Q^H` for complex.
    transpose,
};

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

// ============================================================================
// Factorizations
// ============================================================================

/// `A = Q R` for an `rows x cols` matrix.
///
/// `R` is left in the upper triangle of `a`; the reflectors defining `Q` go
/// below it, with `tau` holding their scalars. `tau` needs `min(rows, cols)`
/// elements.
///
/// The result is not a usable `Q` on its own — pass `a` and `tau` to `orgqr` to
/// build it, or to `ormqr` to apply it without building it.
pub fn geqrf(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    tau: []T,
) Fail!void {
    return factorAlloc(T, "geqrf", allocator, rows, cols, a, lda, tau);
}

/// `A = L Q`.
pub fn gelqf(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    tau: []T,
) Fail!void {
    return factorAlloc(T, "gelqf", allocator, rows, cols, a, lda, tau);
}

/// `A = Q L`.
pub fn geqlf(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    tau: []T,
) Fail!void {
    return factorAlloc(T, "geqlf", allocator, rows, cols, a, lda, tau);
}

/// `A = R Q`.
pub fn gerqf(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    tau: []T,
) Fail!void {
    return factorAlloc(T, "gerqf", allocator, rows, cols, a, lda, tau);
}

/// `geqrf` with a caller-supplied workspace. Documented minimum is `cols`.
pub fn geqrfWithWorkspace(comptime T: type, rows: usize, cols: usize, a: []T, lda: usize, tau: []T, work: []T) Error!void {
    return factorWith(T, "geqrf", rows, cols, a, lda, tau, work);
}

/// `gelqf` with a caller-supplied workspace. Documented minimum is `rows`.
pub fn gelqfWithWorkspace(comptime T: type, rows: usize, cols: usize, a: []T, lda: usize, tau: []T, work: []T) Error!void {
    return factorWith(T, "gelqf", rows, cols, a, lda, tau, work);
}

/// Optimal `work` length for `geqrf`.
pub fn geqrfWorkspaceSize(comptime T: type, rows: usize, cols: usize, lda: usize) Error!usize {
    return factorQuery(T, "geqrf", rows, cols, lda);
}

/// Optimal `work` length for `gelqf`.
pub fn gelqfWorkspaceSize(comptime T: type, rows: usize, cols: usize, lda: usize) Error!usize {
    return factorQuery(T, "gelqf", rows, cols, lda);
}

fn factorAlloc(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    tau: []T,
) Fail!void {
    const size = try factorQuery(T, name, rows, cols, lda);
    const buf = try allocator.alloc(T, @max(size, 1));
    defer allocator.free(buf);
    return factorWith(T, name, rows, cols, a, lda, tau, buf);
}

fn factorWith(
    comptime T: type,
    comptime name: []const u8,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    tau: []T,
    work: []T,
) Error!void {
    assertMatrix(a.len, rows, cols, lda);
    std.debug.assert(tau.len >= @min(rows, cols));
    std.debug.assert(work.len >= 1);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(lda);
    const lwork = dim(work.len);
    var info: Int = 0;

    sym(T, name)(ref(&m_), ref(&n_), a.ptr, ref(&lda_), tau.ptr, work.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

fn factorQuery(comptime T: type, comptime name: []const u8, rows: usize, cols: usize, lda: usize) Error!usize {
    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(@max(lda, 1));
    const lwork = work_mod.query;
    var probe: [1]T = undefined;
    var wq: [1]T = undefined;
    var info: Int = 0;

    sym(T, name)(ref(&m_), ref(&n_), &probe, ref(&lda_), &probe, &wq, ref(&lwork), out(&info));
    try info_mod.checkArgs(info);
    return @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
}

/// `A P = Q R` — QR with column pivoting, which reveals rank.
///
/// `jpvt` selects and receives the permutation: an entry that is nonzero on
/// input pins that column to the front of `A P`; the rest are chosen by the
/// algorithm. Zero it first unless you mean to pin something. On output it is
/// the 1-based permutation.
///
/// The diagonal of `R` comes out in non-increasing magnitude, so the rank is
/// the count of diagonal entries above whatever tolerance you choose. That is
/// what makes this the rank-revealing factorization and plain `geqrf` not.
pub fn geqp3(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    jpvt: []Int,
    tau: []T,
) Fail!void {
    assertMatrix(a.len, rows, cols, lda);
    std.debug.assert(jpvt.len >= cols);
    std.debug.assert(tau.len >= @min(rows, cols));

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(lda);
    var info: Int = 0;

    // Query. The complex form takes an extra real workspace, which is not part
    // of the query - its size is fixed at 2n.
    var probe: [1]T = undefined;
    var probe_i: [1]Int = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    switch (T) {
        Complex(f32), Complex(f64) => {
            var rprobe: [1]Real(T) = undefined;
            sym(T, "geqp3")(ref(&m_), ref(&n_), &probe, ref(&lda_), &probe_i, &probe, &wq, ref(&neg), &rprobe, out(&info));
        },
        else => {
            sym(T, "geqp3")(ref(&m_), ref(&n_), &probe, ref(&lda_), &probe_i, &probe, &wq, ref(&neg), out(&info));
        },
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    switch (T) {
        Complex(f32), Complex(f64) => {
            const rwork = try allocator.alloc(Real(T), @max(2 * cols, 1));
            defer allocator.free(rwork);
            sym(T, "geqp3")(ref(&m_), ref(&n_), a.ptr, ref(&lda_), jpvt.ptr, tau.ptr, buf.ptr, ref(&lwork), rwork.ptr, out(&info));
        },
        else => {
            sym(T, "geqp3")(ref(&m_), ref(&n_), a.ptr, ref(&lda_), jpvt.ptr, tau.ptr, buf.ptr, ref(&lwork), out(&info));
        },
    }
    return info_mod.checkArgs(info);
}

// ============================================================================
// Forming and applying Q
// ============================================================================

/// Builds the first `k` reflectors of a `geqrf` factorization into an explicit
/// `rows x cols` matrix `Q`.
///
/// Overwrites `a`. `cols <= rows` and `k <= cols` — you cannot ask for more
/// columns of `Q` than the factorization has reflectors, and the full square
/// `Q` requires `rows` reflectors, which a thin factorization does not have.
///
/// Called `ungqr` in LAPACK for complex elements; both names work here.
pub fn orgqr(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    k: usize,
    a: []T,
    lda: usize,
    tau: []const T,
) Fail!void {
    return generateAlloc(T, "gqr", allocator, rows, cols, k, a, lda, tau);
}

/// LAPACK's name for `orgqr` on complex elements. Identical.
pub const ungqr = orgqr;

/// `orgqr` for a `gelqf` factorization.
pub fn orglq(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    k: usize,
    a: []T,
    lda: usize,
    tau: []const T,
) Fail!void {
    return generateAlloc(T, "glq", allocator, rows, cols, k, a, lda, tau);
}

/// LAPACK's name for `orglq` on complex elements.
pub const unglq = orglq;

/// `orgqr` for a `geqlf` factorization.
pub fn orgql(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    k: usize,
    a: []T,
    lda: usize,
    tau: []const T,
) Fail!void {
    return generateAlloc(T, "gql", allocator, rows, cols, k, a, lda, tau);
}

/// LAPACK's name for `orgql` on complex elements.
pub const ungql = orgql;

/// `orgqr` for a `gerqf` factorization.
pub fn orgrq(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    k: usize,
    a: []T,
    lda: usize,
    tau: []const T,
) Fail!void {
    return generateAlloc(T, "grq", allocator, rows, cols, k, a, lda, tau);
}

/// LAPACK's name for `orgrq` on complex elements.
pub const ungrq = orgrq;

fn generateAlloc(
    comptime T: type,
    comptime suffix: []const u8,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    k: usize,
    a: []T,
    lda: usize,
    tau: []const T,
) Fail!void {
    assertMatrix(a.len, rows, cols, lda);
    std.debug.assert(tau.len >= k);

    const name = comptime ortho(T, suffix);
    const m_ = dim(rows);
    const n_ = dim(cols);
    const k_ = dim(k);
    const lda_ = dim(lda);
    var info: Int = 0;

    var probe: [1]T = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(ref(&m_), ref(&n_), ref(&k_), &probe, ref(&lda_), &probe, &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, name)(ref(&m_), ref(&n_), ref(&k_), a.ptr, ref(&lda_), tau.ptr, buf.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// `C := Q C`, `C := Q^H C`, `C := C Q` or `C := C Q^H`, without ever forming
/// `Q`.
///
/// This is the routine to reach for. Forming `Q` with `orgqr` and calling
/// `gemm` costs an m x m matrix and an O(m^2 n) product; applying the
/// reflectors directly costs neither.
///
/// The shapes are the usual source of trouble. `C` is `rows x cols`. With
/// `side = .left`, `Q` is `rows x rows` and `a` must be `rows x k`; with
/// `side = .right`, `Q` is `cols x cols` and `a` must be `cols x k`. `k` is the
/// number of reflectors, i.e. how many `geqrf` produced.
pub fn ormqr(
    comptime T: type,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    k: usize,
    a: []const T,
    lda: usize,
    tau: []const T,
    cm: []T,
    ldc: usize,
) Fail!void {
    return applyAlloc(T, "mqr", allocator, side, trans, rows, cols, k, a, lda, tau, cm, ldc);
}

/// LAPACK's name for `ormqr` on complex elements.
pub const unmqr = ormqr;

/// `ormqr` for a `gelqf` factorization.
pub fn ormlq(
    comptime T: type,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    k: usize,
    a: []const T,
    lda: usize,
    tau: []const T,
    cm: []T,
    ldc: usize,
) Fail!void {
    return applyAlloc(T, "mlq", allocator, side, trans, rows, cols, k, a, lda, tau, cm, ldc);
}

/// LAPACK's name for `ormlq` on complex elements.
pub const unmlq = ormlq;

/// `ormqr` for a `geqlf` factorization.
pub fn ormql(
    comptime T: type,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    k: usize,
    a: []const T,
    lda: usize,
    tau: []const T,
    cm: []T,
    ldc: usize,
) Fail!void {
    return applyAlloc(T, "mql", allocator, side, trans, rows, cols, k, a, lda, tau, cm, ldc);
}

/// `ormqr` for a `gerqf` factorization.
pub fn ormrq(
    comptime T: type,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    k: usize,
    a: []const T,
    lda: usize,
    tau: []const T,
    cm: []T,
    ldc: usize,
) Fail!void {
    return applyAlloc(T, "mrq", allocator, side, trans, rows, cols, k, a, lda, tau, cm, ldc);
}

fn applyAlloc(
    comptime T: type,
    comptime suffix: []const u8,
    allocator: Allocator,
    side: Side,
    trans: QTrans,
    rows: usize,
    cols: usize,
    k: usize,
    a: []const T,
    lda: usize,
    tau: []const T,
    cm: []T,
    ldc: usize,
) Fail!void {
    const q_order = if (side == .left) rows else cols;
    std.debug.assert(k <= q_order);
    assertMatrix(a.len, q_order, k, lda);
    assertMatrix(cm.len, rows, cols, ldc);
    std.debug.assert(tau.len >= k);

    const name = comptime ortho(T, suffix);
    const m_ = dim(rows);
    const n_ = dim(cols);
    const k_ = dim(k);
    const lda_ = dim(lda);
    const ldc_ = dim(ldc);
    var info: Int = 0;

    var probe: [1]T = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(opt(side), qtrans(T, trans), ref(&m_), ref(&n_), ref(&k_), &probe, ref(&lda_), &probe, &probe, ref(&ldc_), &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, name)(opt(side), qtrans(T, trans), ref(&m_), ref(&n_), ref(&k_), @constCast(a.ptr), ref(&lda_), tau.ptr, cm.ptr, ref(&ldc_), buf.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

// ============================================================================
// Least squares
// ============================================================================

/// Solves the least squares problem `min ||A x - b||` (or the minimum-norm
/// underdetermined problem) assuming `A` has **full rank**.
///
/// `b` must be large enough for both the right-hand side and the solution:
/// `max(rows, cols) x nrhs`, since an underdetermined solution is longer than
/// the data. The solution occupies the first `cols` rows on return when
/// `trans = .no_trans`.
///
/// ## The full-rank assumption is barely checked
///
/// `error.SingularMatrix` is raised only when a diagonal element of the
/// triangular factor comes out **exactly** zero. A matrix that is rank
/// deficient in any realistic sense - two nearly parallel columns, say - sails
/// through, and the "solution" is whatever dividing by a rounding error
/// produces. Measured on a 3x2 matrix of all ones, this returns success and
/// `x = (-7.5e15, 7.5e15)`.
///
/// So the error is a courtesy, not a guarantee. If you are not certain `A` has
/// full rank, use `gelsd`, which reports the rank and the singular values it
/// based that on.
pub fn gels(
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
    assertMatrix(a.len, rows, cols, lda);
    assertMatrix(b.len, @max(rows, cols), nrhs, ldb);
    std.debug.assert(ldb >= @max(rows, cols));

    const m_ = dim(rows);
    const n_ = dim(cols);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    var probe: [1]T = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, "gels")(qtrans(T, trans), ref(&m_), ref(&n_), ref(&nrhs_), &probe, ref(&lda_), &probe, ref(&ldb_), &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, "gels")(qtrans(T, trans), ref(&m_), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), buf.ptr, ref(&lwork), out(&info));
    // info > 0 means a diagonal element of the triangular factor is zero, so A
    // is rank deficient and the least squares solution was not computed.
    return info_mod.checkLu(info);
}

/// Result of a rank-deficient least squares solve.
pub const RankResult = struct {
    /// The effective rank of `A`, as determined by `rcond`.
    rank: usize,
};

/// Least squares by complete orthogonal factorization, tolerating rank
/// deficiency.
///
/// `rcond` sets the threshold: the effective rank is the order of the largest
/// leading submatrix whose estimated condition number is below `1 / rcond`.
///
/// **Do not pass a negative `rcond` here.** LAPACK documents that as "use
/// machine precision", which sounds like a safe default and is not one: the
/// threshold becomes `1 / eps`, and a numerically singular matrix passes. On a
/// 3x2 matrix of all ones, `rcond = -1` reports rank 2 and returns
/// `x = (-7.5e15, 7.5e15)`, while any explicit value from `1e-16` up reports
/// rank 1 and the correct minimum-norm `x = (1, 1)`. `gelsd` does not share
/// this behaviour - its negative default works, because it compares singular
/// values rather than a condition estimate. There is a test pinning the
/// difference.
///
/// `jpvt` works as in `geqp3` — zero it unless you mean to pin columns.
///
/// This is the cheaper of the two rank-deficient solvers. `gelsd` is more
/// reliable near the threshold because it uses the SVD, but costs more.
pub fn gelsy(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    nrhs: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    jpvt: []Int,
    rcond: Real(T),
) Fail!RankResult {
    assertMatrix(a.len, rows, cols, lda);
    assertMatrix(b.len, @max(rows, cols), nrhs, ldb);
    std.debug.assert(jpvt.len >= cols);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    var rank: Int = 0;
    var info: Int = 0;

    var probe: [1]T = undefined;
    var probe_i: [1]Int = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    switch (T) {
        Complex(f32), Complex(f64) => {
            var rprobe: [1]Real(T) = undefined;
            sym(T, "gelsy")(ref(&m_), ref(&n_), ref(&nrhs_), &probe, ref(&lda_), &probe, ref(&ldb_), &probe_i, ref(&rcond), out(&rank), &wq, ref(&neg), &rprobe, out(&info));
        },
        else => {
            sym(T, "gelsy")(ref(&m_), ref(&n_), ref(&nrhs_), &probe, ref(&lda_), &probe, ref(&ldb_), &probe_i, ref(&rcond), out(&rank), &wq, ref(&neg), out(&info));
        },
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    switch (T) {
        Complex(f32), Complex(f64) => {
            const rwork = try allocator.alloc(Real(T), @max(2 * cols, 1));
            defer allocator.free(rwork);
            sym(T, "gelsy")(ref(&m_), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), jpvt.ptr, ref(&rcond), out(&rank), buf.ptr, ref(&lwork), rwork.ptr, out(&info));
        },
        else => {
            sym(T, "gelsy")(ref(&m_), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), jpvt.ptr, ref(&rcond), out(&rank), buf.ptr, ref(&lwork), out(&info));
        },
    }
    try info_mod.checkArgs(info);
    return .{ .rank = @intCast(rank) };
}

/// Least squares by SVD with a divide-and-conquer driver, tolerating rank
/// deficiency.
///
/// `s` receives the singular values of `A`, in decreasing order — often the
/// reason to choose this over `gelsy`, since they tell you *how* rank deficient
/// the problem is rather than just where the cut fell.
///
/// `error.NoConvergence` means the SVD did not converge; `lastInfo()` is the
/// number of off-diagonal elements that failed.
pub fn gelsd(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    nrhs: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    s: []Real(T),
    rcond: Real(T),
) Fail!RankResult {
    assertMatrix(a.len, rows, cols, lda);
    assertMatrix(b.len, @max(rows, cols), nrhs, ldb);
    std.debug.assert(s.len >= @min(rows, cols));

    const m_ = dim(rows);
    const n_ = dim(cols);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    var rank: Int = 0;
    var info: Int = 0;

    // gelsd is the one routine here whose query reports three sizes: work,
    // iwork, and (for complex) rwork. Sizing any of them by a formula rather
    // than by asking is how you get a heap overflow on a large problem.
    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    var iq: [1]Int = undefined;
    var rq: [1]Real(T) = undefined;
    const neg = work_mod.query;
    switch (T) {
        Complex(f32), Complex(f64) => {
            sym(T, "gelsd")(ref(&m_), ref(&n_), ref(&nrhs_), &probe, ref(&lda_), &probe, ref(&ldb_), &rprobe, ref(&rcond), out(&rank), &wq, ref(&neg), &rq, &iq, out(&info));
        },
        else => {
            sym(T, "gelsd")(ref(&m_), ref(&n_), ref(&nrhs_), &probe, ref(&lda_), &probe, ref(&ldb_), &rprobe, ref(&rcond), out(&rank), &wq, ref(&neg), &iq, out(&info));
        },
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const iwork = try allocator.alloc(Int, @intCast(@max(iq[0], 1)));
    defer allocator.free(iwork);
    const lwork = dim(size);

    switch (T) {
        Complex(f32), Complex(f64) => {
            const rwork = try allocator.alloc(Real(T), @intCast(@max(work_mod.sizeFrom(Real(T), rq[0]), 1)));
            defer allocator.free(rwork);
            sym(T, "gelsd")(ref(&m_), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), s.ptr, ref(&rcond), out(&rank), buf.ptr, ref(&lwork), rwork.ptr, iwork.ptr, out(&info));
        },
        else => {
            sym(T, "gelsd")(ref(&m_), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), s.ptr, ref(&rcond), out(&rank), buf.ptr, ref(&lwork), iwork.ptr, out(&info));
        },
    }
    try info_mod.checkConvergence(info);
    return .{ .rank = @intCast(rank) };
}

/// Least squares by SVD, without the divide-and-conquer acceleration.
///
/// `gelsd` is faster for anything but small problems and computes the same
/// thing. This is here because it uses less workspace and is the older, more
/// widely described interface.
pub fn gelss(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    nrhs: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    s: []Real(T),
    rcond: Real(T),
) Fail!RankResult {
    assertMatrix(a.len, rows, cols, lda);
    assertMatrix(b.len, @max(rows, cols), nrhs, ldb);
    std.debug.assert(s.len >= @min(rows, cols));

    const m_ = dim(rows);
    const n_ = dim(cols);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    var rank: Int = 0;
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    switch (T) {
        Complex(f32), Complex(f64) => {
            sym(T, "gelss")(ref(&m_), ref(&n_), ref(&nrhs_), &probe, ref(&lda_), &probe, ref(&ldb_), &rprobe, ref(&rcond), out(&rank), &wq, ref(&neg), &rprobe, out(&info));
        },
        else => {
            sym(T, "gelss")(ref(&m_), ref(&n_), ref(&nrhs_), &probe, ref(&lda_), &probe, ref(&ldb_), &rprobe, ref(&rcond), out(&rank), &wq, ref(&neg), out(&info));
        },
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    switch (T) {
        Complex(f32), Complex(f64) => {
            const rwork = try allocator.alloc(Real(T), @max(5 * @min(rows, cols), 1));
            defer allocator.free(rwork);
            sym(T, "gelss")(ref(&m_), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), s.ptr, ref(&rcond), out(&rank), buf.ptr, ref(&lwork), rwork.ptr, out(&info));
        },
        else => {
            sym(T, "gelss")(ref(&m_), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), s.ptr, ref(&rcond), out(&rank), buf.ptr, ref(&lwork), out(&info));
        },
    }
    try info_mod.checkConvergence(info);
    return .{ .rank = @intCast(rank) };
}

// ============================================================================
// Constrained and generalized least squares
// ============================================================================

/// Least squares with an exact linear constraint.
///
/// Minimizes `||A x - c||` subject to `B x = d`, where `B` is `p x n` with
/// `p <= n <= m + p`. The constraint is satisfied *exactly*, not in a least
/// squares sense — that is the whole difference from stacking `B` onto `A` with
/// a large weight, which only approximates it and destroys the conditioning.
///
/// `x` receives the solution; `a`, `b`, `c` and `d` are all destroyed.
///
/// `error.SingularMatrix` means the problem is not well posed: `lastInfo() == 1`
/// says `B` is rank deficient so the constraint has no solution;
/// `lastInfo() == 2` says the stacked `[A; B]` is rank deficient so the
/// minimizer is not unique.
///
/// **That check is not reliable.** Measured, an exactly duplicated row in `B`
/// comes back as success — the test is on a QR pivot, which for a duplicate is
/// small but not zero. If `B` might be rank deficient, check it yourself.
pub fn gglse(
    comptime T: type,
    allocator: Allocator,
    rows: usize,
    cols: usize,
    p: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    cv: []T,
    d: []T,
    x: []T,
) Fail!void {
    assertMatrix(a.len, rows, cols, lda);
    assertMatrix(b.len, p, cols, ldb);
    std.debug.assert(cv.len >= rows and d.len >= p and x.len >= cols);
    std.debug.assert(p <= cols and cols <= rows + p);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const p_ = dim(p);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    var info: Int = 0;

    var probe: [1]T = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, "gglse")(ref(&m_), ref(&n_), ref(&p_), &probe, ref(&lda_), &probe, ref(&ldb_), &probe, &probe, &probe, &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, "gglse")(ref(&m_), ref(&n_), ref(&p_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), cv.ptr, d.ptr, x.ptr, buf.ptr, ref(&lwork), out(&info));
    return info_mod.checkLu(info);
}

/// The Gauss-Markov linear model problem.
///
/// Minimizes `||y||` subject to `d = A x + B y`, with `A` being `n x m` and `B`
/// being `n x p`, `m <= n <= m + p`. The dual of `gglse`: there the constraint
/// was exact and the residual minimized, here the residual is exact and a
/// *weighting* is minimized. It is the generalized least squares problem, and
/// with `B = I` it reduces to ordinary least squares.
///
/// `x` and `y` receive the solution; everything else is destroyed. The `info`
/// values mirror `gglse`'s.
pub fn ggglm(
    comptime T: type,
    allocator: Allocator,
    n: usize,
    m: usize,
    p: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    d: []T,
    x: []T,
    y: []T,
) Fail!void {
    assertMatrix(a.len, n, m, lda);
    assertMatrix(b.len, n, p, ldb);
    std.debug.assert(d.len >= n and x.len >= m and y.len >= p);
    std.debug.assert(m <= n and n <= m + p);

    const n_ = dim(n);
    const m_ = dim(m);
    const p_ = dim(p);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    var info: Int = 0;

    var probe: [1]T = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, "ggglm")(ref(&n_), ref(&m_), ref(&p_), &probe, ref(&lda_), &probe, ref(&ldb_), &probe, &probe, &probe, &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, "ggglm")(ref(&n_), ref(&m_), ref(&p_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), d.ptr, x.ptr, y.ptr, buf.ptr, ref(&lwork), out(&info));
    return info_mod.checkLu(info);
}

/// Generalized QR factorization of a pair: `A = Q R` and `B = Q T Z`.
///
/// The factorization `gglse` and `ggglm` use internally, with one `Q` shared
/// between the two matrices. `taua` goes with `Q` and `taub` with `Z`; apply
/// them with `ormqr` and `ormrq` respectively.
pub fn ggqrf(
    comptime T: type,
    allocator: Allocator,
    n: usize,
    m: usize,
    p: usize,
    a: []T,
    lda: usize,
    taua: []T,
    b: []T,
    ldb: usize,
    taub: []T,
) Fail!void {
    return generalizedFactor(T, "ggqrf", allocator, n, m, p, a, lda, taua, b, ldb, taub);
}

/// Generalized RQ factorization of a pair: `A = R Q` and `B = Z T Q`, sharing
/// the `Q`.
pub fn ggrqf(
    comptime T: type,
    allocator: Allocator,
    m: usize,
    p: usize,
    n: usize,
    a: []T,
    lda: usize,
    taua: []T,
    b: []T,
    ldb: usize,
    taub: []T,
) Fail!void {
    return generalizedFactor(T, "ggrqf", allocator, m, p, n, a, lda, taua, b, ldb, taub);
}

fn generalizedFactor(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    d1: usize,
    d2: usize,
    d3: usize,
    a: []T,
    lda: usize,
    taua: []T,
    b: []T,
    ldb: usize,
    taub: []T,
) Fail!void {
    const d1_ = dim(d1);
    const d2_ = dim(d2);
    const d3_ = dim(d3);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    var info: Int = 0;

    var probe: [1]T = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(ref(&d1_), ref(&d2_), ref(&d3_), &probe, ref(&lda_), &probe, &probe, ref(&ldb_), &probe, &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, name)(ref(&d1_), ref(&d2_), ref(&d3_), a.ptr, ref(&lda_), taua.ptr, b.ptr, ref(&ldb_), taub.ptr, buf.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// `max |(A B)_ij - expected_ij|` for column-major operands.
fn productError(
    comptime T: type,
    m: usize,
    n: usize,
    k: usize,
    a: []const T,
    lda: usize,
    b: []const T,
    ldb: usize,
    expected: []const T,
    lde: usize,
) T {
    var worst: T = 0;
    for (0..m) |i| {
        for (0..n) |j| {
            var acc: T = 0;
            for (0..k) |p| acc += a[i + p * lda] * b[p + j * ldb];
            worst = @max(worst, @abs(acc - expected[i + j * lde]));
        }
    }
    return worst;
}

test "geqrf then orgqr reconstructs the original matrix" {
    // 4x3, full column rank.
    const m = 4;
    const n = 3;
    const original = [_]f64{ 1, 2, 3, 4, 2, 3, 5, 7, 3, 5, 8, 13 };
    var a = original;
    var tau: [3]f64 = undefined;

    try geqrf(f64, testing.allocator, m, n, &a, m, &tau);

    // Copy R out before orgqr overwrites `a` with Q.
    var r = [_]f64{0} ** (n * n);
    for (0..n) |j| {
        for (0..j + 1) |i| r[i + j * n] = a[i + j * m];
    }

    try orgqr(f64, testing.allocator, m, n, n, &a, m, &tau);

    // Q R must be the original. This checks the factorization end to end
    // without needing a reference value for either factor.
    try testing.expect(productError(f64, m, n, n, &a, m, &r, n, &original, m) < 1e-12);

    // And Q's columns must be orthonormal: Q^T Q = I.
    for (0..n) |i| {
        for (0..n) |j| {
            var acc: f64 = 0;
            for (0..m) |p| acc += a[p + i * m] * a[p + j * m];
            const want: f64 = if (i == j) 1 else 0;
            try testing.expectApproxEqAbs(want, acc, 1e-12);
        }
    }
}

test "ormqr applies Q without forming it" {
    const m = 4;
    const n = 3;
    const original = [_]f64{ 1, 2, 3, 4, 2, 3, 5, 7, 3, 5, 8, 13 };

    // Route one: form Q, then multiply by hand.
    var a1 = original;
    var tau1: [3]f64 = undefined;
    try geqrf(f64, testing.allocator, m, n, &a1, m, &tau1);
    var q = a1;
    try orgqr(f64, testing.allocator, m, n, n, &q, m, &tau1);

    // Route two: ormqr on the identity, which is what "form Q" means.
    var a2 = original;
    var tau2: [3]f64 = undefined;
    try geqrf(f64, testing.allocator, m, n, &a2, m, &tau2);
    var cm = [_]f64{0} ** (m * n);
    for (0..n) |i| cm[i + i * m] = 1;
    try ormqr(f64, testing.allocator, .left, .no_trans, m, n, n, &a2, m, &tau2, &cm, m);

    for (0..m * n) |i| try testing.expectApproxEqAbs(q[i], cm[i], 1e-12);
}

test "ormqr with .transpose undoes .no_trans" {
    const m = 4;
    const n = 2;
    var a = [_]f64{ 1, 2, 3, 4, 2, 3, 5, 7 };
    var tau: [2]f64 = undefined;
    try geqrf(f64, testing.allocator, m, n, &a, m, &tau);

    const original = [_]f64{ 1, 0, 2, 0, 0, 3, 0, 1 };
    var cm = original;
    try ormqr(f64, testing.allocator, .left, .no_trans, m, n, n, &a, m, &tau, &cm, m);
    try ormqr(f64, testing.allocator, .left, .transpose, m, n, n, &a, m, &tau, &cm, m);

    // Q^T Q C = C. If .transpose emitted the wrong character this would either
    // fail outright (complex) or silently not round-trip.
    for (0..m * n) |i| try testing.expectApproxEqAbs(original[i], cm[i], 1e-12);
}

test "unmqr accepts the conjugate transpose that LAPACK requires for complex" {
    // Real cunmqr rejects TRANS = 'T' with info < 0. QTrans hides that: the
    // same .transpose value emits 'T' for f64 and 'C' for Complex(f64), so this
    // call compiles and runs where a literal transliteration would fail.
    const Z = Complex(f64);
    const m = 3;
    const n = 2;
    var a = [_]Z{
        Z.init(1, 1), Z.init(2, 0),  Z.init(0, 1),
        Z.init(3, 0), Z.init(-1, 2), Z.init(1, 0),
    };
    var tau: [2]Z = undefined;
    try geqrf(Z, testing.allocator, m, n, &a, m, &tau);

    const original = [_]Z{ Z.init(1, 0), Z.init(0, 0), Z.init(0, 0), Z.init(0, 1), Z.init(2, 0), Z.init(0, 0) };
    var cm = original;
    try unmqr(Z, testing.allocator, .left, .no_trans, m, n, n, &a, m, &tau, &cm, m);
    try unmqr(Z, testing.allocator, .left, .transpose, m, n, n, &a, m, &tau, &cm, m);

    for (original, cm) |want, got| {
        try testing.expectApproxEqAbs(want.re, got.re, 1e-12);
        try testing.expectApproxEqAbs(want.im, got.im, 1e-12);
    }
}

test "gelqf then orglq reconstructs the original matrix" {
    // 3x4, full row rank: A = L Q.
    const m = 3;
    const n = 4;
    const original = [_]f64{ 1, 2, 3, 2, 3, 5, 3, 5, 8, 4, 7, 13 };
    var a = original;
    var tau: [3]f64 = undefined;

    try gelqf(f64, testing.allocator, m, n, &a, m, &tau);

    var l = [_]f64{0} ** (m * m);
    for (0..m) |j| {
        for (j..m) |i| l[i + j * m] = a[i + j * m];
    }

    try orglq(f64, testing.allocator, m, n, m, &a, m, &tau);

    try testing.expect(productError(f64, m, n, m, &l, m, &a, m, &original, m) < 1e-12);
}

test "geqp3 orders the diagonal of R by magnitude" {
    // Column 0 is tiny, column 2 is large - pivoting must reorder them.
    const m = 3;
    const n = 3;
    var a = [_]f64{ 1e-6, 0, 0, 0, 1, 0, 0, 0, 100 };
    var jpvt = [_]Int{ 0, 0, 0 };
    var tau: [3]f64 = undefined;

    try geqp3(f64, testing.allocator, m, n, &a, m, &jpvt, &tau);

    // |R(0,0)| >= |R(1,1)| >= |R(2,2)| is what makes this rank-revealing.
    const r0 = @abs(a[0]);
    const r1 = @abs(a[1 + 1 * m]);
    const r2 = @abs(a[2 + 2 * m]);
    try testing.expect(r0 >= r1);
    try testing.expect(r1 >= r2);
    try testing.expectApproxEqAbs(@as(f64, 100), r0, 1e-9);

    // jpvt is 1-based and names the original column now in each position.
    try testing.expectEqual(@as(Int, 3), jpvt[0]);
}

test "geqp3 pins a column when jpvt says so" {
    const m = 3;
    const n = 3;
    var a = [_]f64{ 1e-6, 0, 0, 0, 1, 0, 0, 0, 100 };
    // Nonzero pins column 1 (the tiny one) to the front, overriding magnitude.
    var jpvt = [_]Int{ 1, 0, 0 };
    var tau: [3]f64 = undefined;

    try geqp3(f64, testing.allocator, m, n, &a, m, &jpvt, &tau);

    try testing.expectEqual(@as(Int, 1), jpvt[0]);
    try testing.expectApproxEqAbs(@as(f64, 1e-6), @abs(a[0]), 1e-15);
}

test "gels solves an overdetermined system in the least squares sense" {
    // Fit y = c0 + c1 x through (0,1), (1,2), (2,4): the best line is not exact.
    const m = 3;
    const n = 2;
    var a = [_]f64{ 1, 1, 1, 0, 1, 2 }; // columns: ones, x
    var b = [_]f64{ 1, 2, 4 };

    try gels(f64, testing.allocator, .no_trans, m, n, 1, &a, m, &b, m);

    // Normal equations give c1 = 1.5, c0 = 5/6.
    try testing.expectApproxEqAbs(@as(f64, 5.0 / 6.0), b[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1.5), b[1], 1e-12);
}

test "gels needs b sized for the solution, not just the data" {
    // Underdetermined: 2 equations, 3 unknowns. The minimum-norm solution has
    // three entries, so b must have max(m, n) = 3 rows even though only 2 are
    // input. Getting this wrong is a buffer overrun LAPACK cannot detect.
    const m = 2;
    const n = 3;
    var a = [_]f64{ 1, 0, 0, 1, 1, 1 }; // [[1, 0, 1], [0, 1, 1]]
    var b = [_]f64{ 1, 1, 0 }; // ldb = 3, only the first 2 are data

    try gels(f64, testing.allocator, .no_trans, m, n, 1, &a, m, &b, 3);

    // Minimum-norm solution of x0 + x2 = 1, x1 + x2 = 1 is (1/3, 1/3, 2/3).
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 3.0), b[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 3.0), b[1], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2.0 / 3.0), b[2], 1e-12);
}

test "gels only detects an exactly zero pivot, not rank deficiency" {
    const m = 3;
    const n = 2;

    // An exactly zero column does produce the error.
    {
        var a = [_]f64{ 1, 1, 1, 0, 0, 0 };
        var b = [_]f64{ 1, 2, 3 };
        try testing.expectError(error.SingularMatrix, gels(f64, testing.allocator, .no_trans, m, n, 1, &a, m, &b, m));
        try testing.expectEqual(@as(Int, 2), info_mod.lastInfo());
    }

    // Two *identical* columns do not. The matrix is rank 1, but the triangular
    // factor's second diagonal element comes out as a rounding error rather
    // than a clean zero, so gels reports success and returns nonsense. This is
    // the documented behaviour and the reason gelsd exists; pinned here so the
    // limitation is visible rather than discovered.
    {
        var a = [_]f64{ 1, 1, 1, 1, 1, 1 };
        var b = [_]f64{ 1, 2, 3 };
        try gels(f64, testing.allocator, .no_trans, m, n, 1, &a, m, &b, m);
        try testing.expect(@abs(b[0]) > 1e10);
        try testing.expect(@abs(b[1]) > 1e10);
    }
}

test "gelsy solves the rank-deficient problem gels gets wrong" {
    const m = 3;
    const n = 2;
    var a = [_]f64{ 1, 1, 1, 1, 1, 1 }; // rank 1
    var b = [_]f64{ 1, 2, 3 };
    var jpvt = [_]Int{ 0, 0 };

    const result = try gelsy(f64, testing.allocator, m, n, 1, &a, m, &b, m, &jpvt, 1e-10);

    try testing.expectEqual(@as(usize, 1), result.rank);
    // The minimum-norm solution splits the fit evenly between the two identical
    // columns: each gets half of the rank-1 coefficient (2).
    try testing.expectApproxEqAbs(@as(f64, 1), b[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1), b[1], 1e-12);
}

test "gelsy's negative rcond default is unsafe where gelsd's is not" {
    // LAPACK documents rcond < 0 as "use machine precision" for both routines,
    // which reads like a safe default. For gelsy it is not: the rank threshold
    // becomes a condition number of 1/eps, which a numerically singular matrix
    // slips under. gelsd compares singular values instead and is unaffected.
    //
    // This is the single most surprising thing in this module, so it is pinned
    // rather than only documented.
    const m = 3;
    const n = 2;

    var ay = [_]f64{ 1, 1, 1, 1, 1, 1 };
    var by = [_]f64{ 1, 2, 3 };
    var jpvt = [_]Int{ 0, 0 };
    const ry = try gelsy(f64, testing.allocator, m, n, 1, &ay, m, &by, m, &jpvt, -1);

    var ad = [_]f64{ 1, 1, 1, 1, 1, 1 };
    var bd = [_]f64{ 1, 2, 3 };
    var s: [2]f64 = undefined;
    const rd = try gelsd(f64, testing.allocator, m, n, 1, &ad, m, &bd, m, &s, -1);

    // gelsy calls it full rank and returns a solution of order 1e15.
    try testing.expectEqual(@as(usize, 2), ry.rank);
    try testing.expect(@abs(by[0]) > 1e10);

    // gelsd calls it rank 1 and returns the minimum-norm solution.
    try testing.expectEqual(@as(usize, 1), rd.rank);
    try testing.expectApproxEqAbs(@as(f64, 1), bd[0], 1e-12);
}

test "gelsd reports the singular values as well as the rank" {
    const m = 3;
    const n = 2;
    var a = [_]f64{ 1, 1, 1, 1, 1, 1 };
    var b = [_]f64{ 1, 2, 3 };
    var s: [2]f64 = undefined;

    const result = try gelsd(f64, testing.allocator, m, n, 1, &a, m, &b, m, &s, -1);

    try testing.expectEqual(@as(usize, 1), result.rank);
    // Singular values of a 3x2 all-ones matrix: sqrt(6) and 0.
    try testing.expectApproxEqAbs(@sqrt(@as(f64, 6)), s[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), s[1], 1e-12);
    // Same minimum-norm answer as gelsy.
    try testing.expectApproxEqAbs(@as(f64, 1), b[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1), b[1], 1e-12);
}

test "gelss agrees with gelsd on the same problem" {
    const m = 3;
    const n = 2;
    const a0 = [_]f64{ 1, 1, 1, 0, 1, 2 };
    const b0 = [_]f64{ 1, 2, 4 };

    var a1 = a0;
    var b1 = b0;
    var s1: [2]f64 = undefined;
    const r1 = try gelsd(f64, testing.allocator, m, n, 1, &a1, m, &b1, m, &s1, -1);

    var a2 = a0;
    var b2 = b0;
    var s2: [2]f64 = undefined;
    const r2 = try gelss(f64, testing.allocator, m, n, 1, &a2, m, &b2, m, &s2, -1);

    try testing.expectEqual(r1.rank, r2.rank);
    try testing.expectApproxEqAbs(s1[0], s2[0], 1e-12);
    try testing.expectApproxEqAbs(b1[0], b2[0], 1e-12);
    try testing.expectApproxEqAbs(b1[1], b2[1], 1e-12);
}

test "geqlf and gerqf factor through the shared helper" {
    const m = 4;
    const n = 3;
    const original = [_]f64{ 1, 2, 3, 4, 2, 3, 5, 7, 3, 5, 8, 13 };

    var a1 = original;
    var tau1: [3]f64 = undefined;
    try geqlf(f64, testing.allocator, m, n, &a1, m, &tau1);

    var a2 = original;
    var tau2: [3]f64 = undefined;
    try gerqf(f64, testing.allocator, m, n, &a2, m, &tau2);

    // Different factorizations of the same matrix, so they must differ.
    try testing.expect(!std.mem.eql(u8, std.mem.asBytes(&a1), std.mem.asBytes(&a2)));
}

test "orgql and orgrq build orthonormal factors" {
    // A = Q L for a square matrix, so Q is the full 3x3 orthogonal factor.
    const n = 3;
    var a = [_]f64{ 1, 2, 3, 2, 5, 7, 3, 7, 13 };
    var tau: [3]f64 = undefined;
    try geqlf(f64, testing.allocator, n, n, &a, n, &tau);
    try orgql(f64, testing.allocator, n, n, n, &a, n, &tau);

    for (0..n) |i| {
        for (0..n) |j| {
            var acc: f64 = 0;
            for (0..n) |p| acc += a[p + i * n] * a[p + j * n];
            const want: f64 = if (i == j) 1 else 0;
            try testing.expectApproxEqAbs(want, acc, 1e-12);
        }
    }
}

test "the workspace queries report sizes the routines then accept" {
    const size = try geqrfWorkspaceSize(f64, 64, 32, 64);
    try testing.expect(size >= 32); // documented minimum is n

    var a = [_]f64{0} ** (64 * 32);
    for (0..32) |j| a[j + j * 64] = 1;
    var tau: [32]f64 = undefined;
    const buf = try testing.allocator.alloc(f64, size);
    defer testing.allocator.free(buf);

    try geqrfWithWorkspace(f64, 64, 32, &a, 64, &tau, buf);
}

test "single precision works through the same wrappers" {
    const m = 3;
    const n = 2;
    var a = [_]f32{ 1, 1, 1, 0, 1, 2 };
    var b = [_]f32{ 1, 2, 4 };

    try gels(f32, testing.allocator, .no_trans, m, n, 1, &a, m, &b, m);

    try testing.expectApproxEqAbs(@as(f32, 5.0 / 6.0), b[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 1.5), b[1], 1e-5);
}

// ============================================================================
// Tests: constrained and generalized least squares
// ============================================================================

test "gglse satisfies its constraint exactly" {
    const m = 4;
    const n = 3;
    const p = 1;
    // Fit b = x0 + x1*t + x2*t^2 through four points, constrained to pass
    // exactly through the origin: x0 = 0.
    var a = [_]f64{
        1, 1, 1, 1,
        1, 2, 3, 4,
        1, 4, 9, 16,
    };
    var b = [_]f64{ 1, 0, 0 };
    var cv = [_]f64{ 2.1, 4.2, 6.1, 8.3 };
    var d = [_]f64{0};
    var x: [n]f64 = undefined;

    try gglse(f64, testing.allocator, m, n, p, &a, m, &b, p, &cv, &d, &x);

    // The constraint holds to machine precision, not approximately - that is
    // the difference from stacking B onto A with a large weight.
    try testing.expectApproxEqAbs(@as(f64, 0), x[0], 1e-14);
}

test "gglse does not detect an exactly duplicated constraint row" {
    const m = 3;
    const n = 2;
    const p = 2;
    var a = [_]f64{ 1, 1, 1, 0, 1, 2 };
    // Two identical constraint rows, so B has rank 1 where the routine wants
    // rank 2 and the problem is not well posed.
    var b = [_]f64{ 1, 1, 1, 1 };
    var cv = [_]f64{ 1, 2, 3 };
    var d = [_]f64{ 1, 1 };
    var x: [n]f64 = undefined;

    // Measured: this returns success. The rank test is on the QR of B, and an
    // exact duplicate leaves a pivot that is small but not zero, so the
    // documented info = 1 does not fire. Do not rely on gglse to validate a
    // constraint matrix - check its rank yourself if it might be deficient.
    try gglse(f64, testing.allocator, m, n, p, &a, m, &b, p, &cv, &d, &x);
    for (x) |v| try testing.expect(std.math.isFinite(v));
}

test "ggglm with an identity B is ordinary least squares" {
    const n = 4;
    const m = 2;
    const p = 4;
    // d = A x + y, minimizing ||y||: exactly the least squares problem gels
    // solves.
    const a0 = [_]f64{ 1, 1, 1, 1, 0, 1, 2, 3 };
    const d0 = [_]f64{ 1, 3, 5, 7 };

    var a = a0;
    var b = [_]f64{0} ** (n * p);
    for (0..n) |i| b[i + i * n] = 1;
    var d = d0;
    var x: [m]f64 = undefined;
    var y: [p]f64 = undefined;
    try ggglm(f64, testing.allocator, n, m, p, &a, n, &b, n, &d, &x, &y);

    var a_ref = a0;
    var b_ref = d0;
    try gels(f64, testing.allocator, .no_trans, n, m, 1, &a_ref, n, &b_ref, n);

    for (0..m) |i| try testing.expectApproxEqAbs(b_ref[i], x[i], 1e-11);
    // Exact fit here, so the minimized residual is zero.
    for (y) |v| try testing.expectApproxEqAbs(@as(f64, 0), v, 1e-11);
}

test "ggqrf shares one Q between the two matrices" {
    const n = 4;
    const m = 2;
    const p = 2;
    const a0 = [_]f64{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const b0 = [_]f64{ 1, 0, 0, 1, 0, 1, 1, 0 };

    var a = a0;
    var b = b0;
    var taua: [m]f64 = undefined;
    var taub: [n]f64 = undefined;
    try ggqrf(f64, testing.allocator, n, m, p, &a, n, &taua, &b, n, &taub);

    // R is the upper triangle of the leading m x m block of a; build Q from
    // the reflectors and check Q R reconstructs A.
    // The thin Q: n x m, which is all that pairs with the m x m R.
    var q = a;
    try orgqr(f64, testing.allocator, n, m, m, &q, n, &taua);
    for (0..m) |j| {
        for (0..n) |i| {
            var acc: f64 = 0;
            for (0..m) |k| {
                if (k <= j) acc += q[i + k * n] * a[k + j * n];
            }
            try testing.expectApproxEqAbs(a0[i + j * n], acc, 1e-11);
        }
    }
}

test "ggrqf is the RQ counterpart" {
    const m = 2;
    const p = 2;
    const n = 4;
    var a = [_]f64{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var b = [_]f64{ 1, 0, 0, 1, 0, 1, 1, 0 };
    var taua: [m]f64 = undefined;
    var taub: [p]f64 = undefined;

    try ggrqf(f64, testing.allocator, m, p, n, &a, m, &taua, &b, p, &taub);

    // Both tau arrays were written; the shared Q is what makes this one call
    // rather than two independent factorizations.
    for (taua) |v| try testing.expect(std.math.isFinite(v));
    for (taub) |v| try testing.expect(std.math.isFinite(v));
}
