//! Singular value decomposition: `A = U S V^H`.
//!
//! `gesdd` is divide and conquer and is the one to use — substantially faster
//! than `gesvd` whenever singular vectors are wanted. `gesvd` is here because
//! it offers finer control over which vectors get computed, and because its
//! interface is the one most documentation describes.
//!
//! Singular values come back in **descending** order and are always real, even
//! for a complex `A`, which is why `s` is `[]Real(T)`.
//!
//! ## `U` and `V^H`, not `U` and `V`
//!
//! LAPACK returns the second factor already conjugate-transposed. For an
//! `m x n` matrix, `u` is `m x m` (or `m x min(m,n)` for the thin form) and
//! `vt` is `n x n` (or `min(m,n) x n`), and the reconstruction is
//! `A = U * S * VT` with no further transposing. Taking `vt` for `V` gives the
//! transpose of what you wanted, which for a symmetric test matrix looks
//! correct and for anything else does not.
//!
//! ## The thin decomposition
//!
//! For a tall `m x n` matrix with `m >> n`, the full `U` is `m x m` and almost
//! all of it is irrelevant — only the first `n` columns pair with a nonzero
//! singular value. `JobSvd.some` computes just those, and is usually what you
//! want; `.all` exists for when you specifically need an orthonormal basis of
//! the whole space.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");

const Int = types.Int;
const Complex = types.Complex;
const Real = types.Real;
const JobSvd = types.JobSvd;
const Job = types.Job;
const Uplo = types.Uplo;
const Range = types.Range;
const Selection = @import("eigen.zig").Selection;
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

fn complexScratch(comptime T: type) bool {
    return switch (T) {
        f32, f64 => false,
        else => true,
    };
}

/// `A = U S V^H`, by QR iteration.
///
/// `jobu` and `jobvt` are chosen independently, which is the reason to prefer
/// this over `gesdd` — you can compute `U` and skip `V^H` entirely. At most one
/// of them may be `.overwrite`, since both would want to write into `a`.
///
/// `a` is destroyed unless one of the jobs is `.overwrite`, in which case it
/// holds that factor.
///
/// `error.NoConvergence` means some superdiagonals of the intermediate
/// bidiagonal form did not converge; `lastInfo()` is how many.
pub fn gesvd(
    comptime T: type,
    allocator: Allocator,
    jobu: JobSvd,
    jobvt: JobSvd,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    s: []Real(T),
    u: []T,
    ldu: usize,
    vt: []T,
    ldvt: usize,
) Fail!void {
    std.debug.assert(!(jobu == .overwrite and jobvt == .overwrite));
    assertMatrix(a.len, rows, cols, lda);
    const mn = @min(rows, cols);
    std.debug.assert(s.len >= mn);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(lda);
    const ldu_ = dim(@max(ldu, 1));
    const ldvt_ = dim(@max(ldvt, 1));
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, "gesvd")(opt(jobu), opt(jobvt), ref(&m_), ref(&n_), &probe, ref(&lda_), &rprobe, &probe, ref(&ldu_), &probe, ref(&ldvt_), &wq, ref(&neg), &rprobe, out(&info));
    } else {
        sym(T, "gesvd")(opt(jobu), opt(jobvt), ref(&m_), ref(&n_), &probe, ref(&lda_), &rprobe, &probe, ref(&ldu_), &probe, ref(&ldvt_), &wq, ref(&neg), out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexScratch(T)) {
        // gesvd's rwork is a fixed 5*min(m, n) and is not part of the query.
        const rwork = try allocator.alloc(Real(T), @max(5 * mn, 1));
        defer allocator.free(rwork);
        sym(T, "gesvd")(opt(jobu), opt(jobvt), ref(&m_), ref(&n_), a.ptr, ref(&lda_), s.ptr, u.ptr, ref(&ldu_), vt.ptr, ref(&ldvt_), buf.ptr, ref(&lwork), rwork.ptr, out(&info));
    } else {
        sym(T, "gesvd")(opt(jobu), opt(jobvt), ref(&m_), ref(&n_), a.ptr, ref(&lda_), s.ptr, u.ptr, ref(&ldu_), vt.ptr, ref(&ldvt_), buf.ptr, ref(&lwork), out(&info));
    }
    return info_mod.checkConvergence(info);
}

/// `A = U S V^H`, by divide and conquer. Faster than `gesvd`, less flexible.
///
/// One `job` controls both factors, because the algorithm computes them
/// together:
///
/// - `.none` — singular values only.
/// - `.all` — full `m x m` `U` and `n x n` `V^H`.
/// - `.some` — the thin form: `min(m,n)` columns of `U`, `min(m,n)` rows of
///   `V^H`. Usually what you want.
/// - `.overwrite` — thin form, with the larger factor written back into `a` to
///   save the allocation.
pub fn gesdd(
    comptime T: type,
    allocator: Allocator,
    job: JobSvd,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    s: []Real(T),
    u: []T,
    ldu: usize,
    vt: []T,
    ldvt: usize,
) Fail!void {
    assertMatrix(a.len, rows, cols, lda);
    const mn = @min(rows, cols);
    const mx = @max(rows, cols);
    std.debug.assert(s.len >= mn);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(lda);
    const ldu_ = dim(@max(ldu, 1));
    const ldvt_ = dim(@max(ldvt, 1));
    var info: Int = 0;

    const iwork = try allocator.alloc(Int, @max(8 * mn, 1));
    defer allocator.free(iwork);

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, "gesdd")(opt(job), ref(&m_), ref(&n_), &probe, ref(&lda_), &rprobe, &probe, ref(&ldu_), &probe, ref(&ldvt_), &wq, ref(&neg), &rprobe, iwork.ptr, out(&info));
    } else {
        sym(T, "gesdd")(opt(job), ref(&m_), ref(&n_), &probe, ref(&lda_), &rprobe, &probe, ref(&ldu_), &probe, ref(&ldvt_), &wq, ref(&neg), iwork.ptr, out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexScratch(T)) {
        // The complex gesdd takes an rwork with no length argument, so its size
        // comes from a formula rather than from the query - and the formula
        // depends on `job`. Rather than encode that branching, this allocates
        // the largest of the documented cases; the excess is bounded by
        // O(min(m,n)^2) and an undersized buffer here is a heap overflow.
        const quad = 5 * mn * mn + 7 * mn;
        const linear = 2 * mx * mn + 2 * mn * mn + mn;
        const rwork = try allocator.alloc(Real(T), @max(@max(quad, linear), 1));
        defer allocator.free(rwork);
        sym(T, "gesdd")(opt(job), ref(&m_), ref(&n_), a.ptr, ref(&lda_), s.ptr, u.ptr, ref(&ldu_), vt.ptr, ref(&ldvt_), buf.ptr, ref(&lwork), rwork.ptr, iwork.ptr, out(&info));
    } else {
        sym(T, "gesdd")(opt(job), ref(&m_), ref(&n_), a.ptr, ref(&lda_), s.ptr, u.ptr, ref(&ldu_), vt.ptr, ref(&ldvt_), buf.ptr, ref(&lwork), iwork.ptr, out(&info));
    }
    return info_mod.checkConvergence(info);
}

// ============================================================================
// Alternative drivers
// ============================================================================

/// The four numbers a `Selection`-style range collapses to.
const Window = struct {
    range: Range,
    vl: f64,
    vu: f64,
    il: Int,
    iu: Int,

    fn from(selection: Selection, n: usize) Window {
        var w: Window = .{ .range = .all, .vl = 0, .vu = 0, .il = 1, .iu = @max(dim(n), 1) };
        switch (selection) {
            .all => {},
            .interval => |iv| {
                std.debug.assert(iv.low < iv.high);
                w.range = .interval;
                w.vl = iv.low;
                w.vu = iv.high;
            },
            .indices => |ix| {
                std.debug.assert(ix.first >= 1 and ix.first <= ix.last and ix.last <= n);
                w.range = .indices;
                w.il = dim(ix.first);
                w.iu = dim(ix.last);
            },
        }
        return w;
    }
};

/// Singular values of a **bidiagonal** matrix, and optionally the product of
/// its vectors with matrices you supply.
///
/// The iteration `gesvd` runs after `reduce.gebrd`. Unusually it does not
/// compute `U` and `V^T` from scratch: it *multiplies* whatever is in `u` and
/// `vt` by the rotations it applies, so passing the reduction's factors gives
/// the original matrix's vectors, and passing identities gives the bidiagonal's
/// own. `c` is a third matrix that gets `U^H` applied to it, for carrying a
/// right-hand side along; pass `ncc = 0` to skip it.
///
/// `d` comes back holding the singular values in descending order; `e` is
/// destroyed.
pub fn bdsqr(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    ncvt: usize,
    nru: usize,
    ncc: usize,
    d: []Real(T),
    e: []Real(T),
    vt: []T,
    ldvt: usize,
    u: []T,
    ldu: usize,
    cm: []T,
    ldc: usize,
) Fail!void {
    std.debug.assert(d.len >= n);
    if (n > 0) std.debug.assert(e.len >= n - 1);
    if (ncvt > 0) assertMatrix(vt.len, n, ncvt, ldvt);
    if (nru > 0) assertMatrix(u.len, nru, n, ldu);
    if (ncc > 0) assertMatrix(cm.len, n, ncc, ldc);

    // 4n reals covers every documented case for both precisions.
    const work = try allocator.alloc(Real(T), @max(4 * n, 1));
    defer allocator.free(work);

    const n_ = dim(n);
    const ncvt_ = dim(ncvt);
    const nru_ = dim(nru);
    const ncc_ = dim(ncc);
    const ldvt_ = dim(@max(ldvt, 1));
    const ldu_ = dim(@max(ldu, 1));
    const ldc_ = dim(@max(ldc, 1));
    var info: Int = 0;

    sym(T, "bdsqr")(opt(uplo), ref(&n_), ref(&ncvt_), ref(&nru_), ref(&ncc_), d.ptr, e.ptr, vt.ptr, ref(&ldvt_), u.ptr, ref(&ldu_), cm.ptr, ref(&ldc_), work.ptr, out(&info));
    return info_mod.checkConvergence(info);
}

/// What `bdsdc` should produce.
pub const BidiagVectors = enum(u8) {
    /// Singular values only.
    none = 'N',
    /// Explicit `U` and `V^T`.
    explicit = 'I',
};

/// Singular values and vectors of a bidiagonal matrix, by divide and conquer.
///
/// Much faster than `bdsqr` for a large `n` with vectors wanted. Unlike
/// `bdsqr` it computes `U` and `V^T` outright rather than multiplying into
/// what you supply, so a reduction's factors have to be applied afterwards with
/// `reduce.ormbr`.
///
/// Real only: there is no complex bidiagonal to solve, because
/// `reduce.gebrd` produces a real one from a complex matrix.
///
/// LAPACK also offers a third `compq` value, `'P'`, returning a compact
/// representation in two extra arrays. It is not exposed here: nothing public
/// consumes that form.
pub fn bdsdc(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    compq: BidiagVectors,
    n: usize,
    d: []T,
    e: []T,
    u: []T,
    ldu: usize,
    vt: []T,
    ldvt: usize,
) Fail!void {
    requireReal(T, "bdsdc");
    std.debug.assert(d.len >= n);
    if (n > 0) std.debug.assert(e.len >= n - 1);
    if (compq == .explicit) {
        assertMatrix(u.len, n, n, ldu);
        assertMatrix(vt.len, n, n, ldvt);
    }

    const work = try allocator.alloc(T, @max(switch (compq) {
        .none => 4 * n,
        .explicit => 3 * n * n + 4 * n,
    }, 1));
    defer allocator.free(work);
    const iwork = try allocator.alloc(Int, @max(8 * n, 1));
    defer allocator.free(iwork);

    const n_ = dim(n);
    const ldu_ = dim(@max(ldu, 1));
    const ldvt_ = dim(@max(ldvt, 1));
    var iq: [1]Int = undefined;
    var q: [1]T = undefined;
    var info: Int = 0;

    sym(T, "bdsdc")(opt(uplo), opt(compq), ref(&n_), d.ptr, e.ptr, u.ptr, ref(&ldu_), vt.ptr, ref(&ldvt_), &q, &iq, work.ptr, iwork.ptr, out(&info));
    return info_mod.checkConvergence(info);
}

/// How many singular triplets a range-restricted driver produced.
pub const SvdResult = struct {
    /// Number of singular values found. Equals `min(rows, cols)` unless a
    /// `Selection` narrowed it.
    found: usize,
};

/// A subset of the singular values of a bidiagonal matrix, by bisection.
///
/// The singular-value counterpart of `tridiag.stebz` + `stein`, done in one
/// call. Real only, for the same reason as `bdsdc`.
///
/// `z` is `(2n) x (k + 1)` when vectors are wanted, not `n x k`: each column
/// holds a left and a right singular vector stacked, because the bisection runs
/// on the `2n x 2n` symmetric matrix `[[0, B], [B^T, 0]]` whose eigenvalues are
/// the singular values and their negatives. The left vector is the first `n`
/// entries and the right vector the last `n`.
pub fn bdsvdx(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    job: Job,
    selection: Selection,
    n: usize,
    d: []T,
    e: []T,
    s: []T,
    z: []T,
    ldz: usize,
) Fail!SvdResult {
    requireReal(T, "bdsvdx");
    std.debug.assert(d.len >= n);
    if (n > 0) std.debug.assert(e.len >= n - 1);
    std.debug.assert(s.len >= n);
    if (job == .vectors) std.debug.assert(ldz >= 2 * n);

    const work = try allocator.alloc(T, @max(14 * n + 4 * n * n, 1));
    defer allocator.free(work);
    const iwork = try allocator.alloc(Int, @max(12 * n, 1));
    defer allocator.free(iwork);

    const win = Window.from(selection, n);
    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    const vl: T = @floatCast(win.vl);
    const vu: T = @floatCast(win.vu);
    var ns: Int = 0;
    var info: Int = 0;

    sym(T, "bdsvdx")(opt(uplo), opt(job), opt(win.range), ref(&n_), d.ptr, e.ptr, ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), out(&ns), s.ptr, z.ptr, ref(&ldz_), work.ptr, iwork.ptr, out(&info));
    try info_mod.checkConvergence(info);
    return .{ .found = @intCast(ns) };
}

/// `gesvd` restricted to a subset of the singular values.
///
/// The only driver here that can compute *some* singular triplets without
/// computing them all. `u` needs `found` columns and `vt` needs `found` rows,
/// so size them by the range you asked for.
///
/// Note that a `.interval` selection is on the singular values themselves, and
/// `vl` must be non-negative.
pub fn gesvdx(
    comptime T: type,
    allocator: Allocator,
    jobu: Job,
    jobvt: Job,
    selection: Selection,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    s: []Real(T),
    u: []T,
    ldu: usize,
    vt: []T,
    ldvt: usize,
) Fail!SvdResult {
    assertMatrix(a.len, rows, cols, lda);
    const mn = @min(rows, cols);
    std.debug.assert(s.len >= mn);

    const iwork = try allocator.alloc(Int, @max(12 * mn, 1));
    defer allocator.free(iwork);

    const win = Window.from(selection, mn);
    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(@max(lda, 1));
    const ldu_ = dim(@max(ldu, 1));
    const ldvt_ = dim(@max(ldvt, 1));
    const vl: Real(T) = @floatCast(win.vl);
    const vu: Real(T) = @floatCast(win.vu);
    var ns: Int = 0;
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, "gesvdx")(opt(jobu), opt(jobvt), opt(win.range), ref(&m_), ref(&n_), &probe, ref(&lda_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), out(&ns), &rprobe, &probe, ref(&ldu_), &probe, ref(&ldvt_), &wq, ref(&neg), &rprobe, iwork.ptr, out(&info));
    } else {
        sym(T, "gesvdx")(opt(jobu), opt(jobvt), opt(win.range), ref(&m_), ref(&n_), &probe, ref(&lda_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), out(&ns), &rprobe, &probe, ref(&ldu_), &probe, ref(&ldvt_), &wq, ref(&neg), iwork.ptr, out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexScratch(T)) {
        const rwork = try allocator.alloc(Real(T), @max(mn * (mn * 2 + 15 * mn), 1));
        defer allocator.free(rwork);
        sym(T, "gesvdx")(opt(jobu), opt(jobvt), opt(win.range), ref(&m_), ref(&n_), a.ptr, ref(&lda_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), out(&ns), s.ptr, u.ptr, ref(&ldu_), vt.ptr, ref(&ldvt_), buf.ptr, ref(&lwork), rwork.ptr, iwork.ptr, out(&info));
    } else {
        sym(T, "gesvdx")(opt(jobu), opt(jobvt), opt(win.range), ref(&m_), ref(&n_), a.ptr, ref(&lda_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), out(&ns), s.ptr, u.ptr, ref(&ldu_), vt.ptr, ref(&ldvt_), buf.ptr, ref(&lwork), iwork.ptr, out(&info));
    }
    try info_mod.checkConvergence(info);
    return .{ .found = @intCast(ns) };
}

/// What triangle `gesvj` should assume the input has.
pub const JacobiStructure = enum(u8) {
    /// `a` is lower triangular.
    lower = 'L',
    /// `a` is upper triangular.
    upper = 'U',
    /// No structure.
    general = 'G',
};

/// What `gesvj` should do about the left vectors.
pub const JacobiLeft = enum(u8) {
    /// Compute them.
    vectors = 'U',
    /// Compute them, with the control option that also reins in the scaling.
    controlled = 'C',
    /// Do not.
    none = 'N',
};

/// What `gesvj` should do about the right vectors.
pub const JacobiRight = enum(u8) {
    /// Compute them.
    vectors = 'V',
    /// Apply the rotations to a matrix already in `v` instead.
    apply = 'A',
    /// Do not.
    none = 'N',
};

/// SVD by one-sided Jacobi rotations.
///
/// Slower than `gesdd` and more accurate, in a specific and useful way: it
/// computes every singular value to high *relative* accuracy, so the small ones
/// come out right even when they are many orders of magnitude below the large
/// ones. `gesdd` and `gesvd` give high *absolute* accuracy, which means the
/// small ones can be pure noise.
///
/// Reach for it when the singular values span a wide dynamic range and the
/// small ones matter — a graded or badly scaled matrix. Otherwise `gesdd`.
///
/// `sva` receives the singular values. `a` is overwritten with `U` when left
/// vectors are wanted.
pub fn gesvj(
    comptime T: type,
    allocator: Allocator,
    joba: JacobiStructure,
    jobu: JacobiLeft,
    jobv: JacobiRight,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    sva: []Real(T),
    mv: usize,
    v: []T,
    ldv: usize,
) Fail!void {
    assertMatrix(a.len, rows, cols, lda);
    std.debug.assert(sva.len >= cols);
    if (jobv != .none) std.debug.assert(ldv >= 1);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(@max(lda, 1));
    const mv_ = dim(mv);
    const ldv_ = dim(@max(ldv, 1));
    var info: Int = 0;

    if (comptime complexScratch(T)) {
        // The complex form splits its scratch: complex cwork of m + n, and a
        // real rwork of max(6, n) whose first entry is also an *input* scaling
        // control. Zeroing it asks for the default.
        const cwork = try allocator.alloc(T, @max(rows + cols, 1));
        defer allocator.free(cwork);
        const lwork = dim(cwork.len);
        const rwork = try allocator.alloc(Real(T), @max(@max(6, cols), 1));
        defer allocator.free(rwork);
        @memset(rwork, 0);
        const lrwork = dim(rwork.len);
        sym(T, "gesvj")(opt(joba), opt(jobu), opt(jobv), ref(&m_), ref(&n_), a.ptr, ref(&lda_), sva.ptr, ref(&mv_), v.ptr, ref(&ldv_), cwork.ptr, ref(&lwork), rwork.ptr, ref(&lrwork), out(&info));
    } else {
        const work = try allocator.alloc(T, @max(@max(6, rows + cols), 1));
        defer allocator.free(work);
        @memset(work, 0);
        const lwork = dim(work.len);
        sym(T, "gesvj")(opt(joba), opt(jobu), opt(jobv), ref(&m_), ref(&n_), a.ptr, ref(&lda_), sva.ptr, ref(&mv_), v.ptr, ref(&ldv_), work.ptr, ref(&lwork), out(&info));
    }
    return info_mod.checkConvergence(info);
}

// ============================================================================
// The high-accuracy drivers
// ============================================================================

/// How much accuracy `gejsv` should buy, and at what price.
///
/// The levels differ in how aggressively they pivot and scale before the Jacobi
/// sweeps. Higher accuracy costs more time and, for the estimating variants, an
/// extra condition number in the workspace.
pub const JsvAccuracy = enum(u8) {
    /// Default. Columns whose norm is below the underflow threshold are treated
    /// as zero.
    default = 'C',
    /// `default` plus an error estimate for the computed values.
    default_with_estimate = 'E',
    /// Higher accuracy: full column pivoting, no columns discarded.
    high = 'F',
    /// `high` plus an error estimate.
    high_with_estimate = 'G',
    /// Highest accuracy, at the highest cost.
    highest = 'A',
    /// Rank-revealing: the values are computed to high relative accuracy and
    /// the numerical rank is determined.
    rank_revealing = 'R',
};

/// What `gejsv` should do about the left singular vectors.
pub const JsvLeft = enum(u8) {
    /// The `m x n` block of `U` that pairs with the singular values.
    thin = 'U',
    /// The full `m x m` orthogonal matrix.
    full = 'F',
    /// Compute them into the workspace only, for the routine's own use.
    workspace = 'W',
    none = 'N',
};

/// What `gejsv` should do about the right singular vectors.
pub const JsvRight = enum(u8) {
    /// The `n x n` matrix `V`.
    vectors = 'V',
    /// `V` computed without an explicit accumulation of the Jacobi rotations,
    /// which is cheaper and slightly less accurate.
    jacobi = 'J',
    workspace = 'W',
    none = 'N',
};

/// SVD by preconditioned Jacobi, the most accurate driver LAPACK ships.
///
/// `gesvj` on its own already gives high relative accuracy; this preconditions
/// with a rank-revealing QR first, which makes it both faster and more accurate
/// on a matrix whose columns are badly scaled relative to one another.
///
/// Six option characters, which is why they are six enums here. The three
/// boolean-ish ones are:
///
/// - `restrict_range`: skip the columns the preconditioner found negligible.
/// - `may_transpose`: allow working on `A^T` when that is better conditioned.
///   Only meaningful for a square `A`.
/// - `perturb`: replace denormal entries with a small normal value, which
///   avoids a slow path on hardware that traps them.
///
/// `sva` receives the singular values. `work[0..]` also carries scaling
/// information LAPACK documents; this wrapper does not expose it, so a value in
/// `sva` is the singular value directly only when `work[0] == work[1]`, which
/// holds unless the matrix needed rescaling to avoid overflow.
///
/// ## No workspace query
///
/// Every other queryable routine in this binding is sized by calling it with
/// `lwork = -1` first. `gejsv` **rejects that** — measured on this machine, the
/// query returns `info = -17`, an illegal value for `lwork` itself. So the
/// sizes below come from the documented formulas, taken at their maximum over
/// every option combination this wrapper can produce rather than branching on
/// `jobu`/`jobv`. That over-allocates for the cheap combinations by a few `n^2`
/// and is the only safe way to do it without a query to check against.
pub fn gejsv(
    comptime T: type,
    allocator: Allocator,
    joba: JsvAccuracy,
    jobu: JsvLeft,
    jobv: JsvRight,
    restrict_range: bool,
    may_transpose: bool,
    perturb: bool,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    sva: []Real(T),
    u: []T,
    ldu: usize,
    v: []T,
    ldv: usize,
) Fail!void {
    assertMatrix(a.len, rows, cols, lda);
    std.debug.assert(sva.len >= cols);
    std.debug.assert(rows >= cols);

    const Flags = enum(u8) { n = 'N', r = 'R', t = 'T', p = 'P' };
    const jobr = if (restrict_range) opt(Flags.r) else opt(Flags.n);
    const jobt = if (may_transpose) opt(Flags.t) else opt(Flags.n);
    const jobp = if (perturb) opt(Flags.p) else opt(Flags.n);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(@max(lda, 1));
    const ldu_ = dim(@max(ldu, 1));
    const ldv_ = dim(@max(ldv, 1));
    var info: Int = 0;

    // max over the documented minima: 2m+n, 6n+2n^2, n^2+4n, 7.
    const size = @max(@max(2 * rows + cols, 6 * cols + 2 * cols * cols), @max(cols * cols + 4 * cols, 7));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    const iwork = try allocator.alloc(Int, @max(rows + 3 * cols, 3));
    defer allocator.free(iwork);

    if (comptime complexScratch(T)) {
        const rsize = @max(@max(7, cols + 2 * rows), 2 * cols + cols * cols);
        const rwork = try allocator.alloc(Real(T), rsize);
        defer allocator.free(rwork);
        const lrwork = dim(rsize);
        sym(T, "gejsv")(opt(joba), opt(jobu), opt(jobv), jobr, jobt, jobp, ref(&m_), ref(&n_), a.ptr, ref(&lda_), sva.ptr, u.ptr, ref(&ldu_), v.ptr, ref(&ldv_), buf.ptr, ref(&lwork), rwork.ptr, ref(&lrwork), iwork.ptr, out(&info));
    } else {
        sym(T, "gejsv")(opt(joba), opt(jobu), opt(jobv), jobr, jobt, jobp, ref(&m_), ref(&n_), a.ptr, ref(&lda_), sva.ptr, u.ptr, ref(&ldu_), v.ptr, ref(&ldv_), buf.ptr, ref(&lwork), iwork.ptr, out(&info));
    }
    return info_mod.checkConvergence(info);
}

/// How `gesvdq` should trade accuracy for speed.
pub const SvdqAccuracy = enum(u8) {
    /// Aggressive: the fastest, and the least accurate of the four.
    aggressive = 'A',
    /// High accuracy, using a rank-revealing preconditioner.
    high = 'H',
    /// Medium.
    medium = 'M',
    /// `medium` plus an error bound on the values.
    medium_with_estimate = 'E',
};

/// What `gesvdq` should do about the left singular vectors.
pub const SvdqLeft = enum(u8) {
    /// All `m` columns of `U`.
    all = 'A',
    /// The thin form: `min(m, n)` columns.
    thin = 'S',
    /// Only the columns spanning the numerical range, which is `numrank` of
    /// them and may be fewer than the thin form.
    rank = 'R',
    none = 'N',
};

/// What `gesvdq` should do about the right singular vectors.
pub const SvdqRight = enum(u8) {
    /// All of `V`.
    all = 'A',
    /// Only the rank-many columns.
    rank = 'R',
    none = 'N',
};

/// SVD with a QR preconditioner and a reported numerical rank.
///
/// The newest of the SVD drivers, and the one to reach for when the rank
/// matters: it returns `numrank`, the number of singular values it judged
/// significant, computed from the preconditioning rather than by thresholding
/// the values afterwards.
///
/// Returns that rank. `v` holds `V`, not `V^H`.
pub fn gesvdq(
    comptime T: type,
    allocator: Allocator,
    joba: SvdqAccuracy,
    jobu: SvdqLeft,
    jobv: SvdqRight,
    pivot: bool,
    transposed_rows: bool,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    s: []Real(T),
    u: []T,
    ldu: usize,
    v: []T,
    ldv: usize,
) Fail!usize {
    assertMatrix(a.len, rows, cols, lda);
    std.debug.assert(s.len >= @min(rows, cols));

    const Flags = enum(u8) { n = 'N', p = 'P', t = 'T' };
    const jobp = if (pivot) opt(Flags.p) else opt(Flags.n);
    const jobr = if (transposed_rows) opt(Flags.t) else opt(Flags.n);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(@max(lda, 1));
    const ldu_ = dim(@max(ldu, 1));
    const ldv_ = dim(@max(ldv, 1));
    var numrank: Int = 0;
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    var rq: [1]Real(T) = undefined;
    var iq: [1]Int = undefined;
    const neg = work_mod.query;
    sym(T, "gesvdq")(opt(joba), jobp, jobr, opt(jobu), opt(jobv), ref(&m_), ref(&n_), &probe, ref(&lda_), &rprobe, &probe, ref(&ldu_), &probe, ref(&ldv_), out(&numrank), &iq, ref(&neg), &wq, ref(&neg), &rq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const liw: usize = @intCast(@max(iq[0], @as(Int, @intCast(cols + rows + 1))));
    const iwork = try allocator.alloc(Int, liw);
    defer allocator.free(iwork);
    const liwork = dim(liw);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 2));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    const rsize: usize = @intCast(@max(work_mod.sizeFrom(Real(T), rq[0]), @as(Int, @intCast(@max(cols, 2)))));
    const rwork = try allocator.alloc(Real(T), rsize);
    defer allocator.free(rwork);
    const lrwork = dim(rsize);

    sym(T, "gesvdq")(opt(joba), jobp, jobr, opt(jobu), opt(jobv), ref(&m_), ref(&n_), a.ptr, ref(&lda_), s.ptr, u.ptr, ref(&ldu_), v.ptr, ref(&ldv_), out(&numrank), iwork.ptr, ref(&liwork), buf.ptr, ref(&lwork), rwork.ptr, ref(&lrwork), out(&info));
    try info_mod.checkConvergence(info);
    return @intCast(numrank);
}

fn requireReal(comptime T: type, comptime routine: []const u8) void {
    switch (T) {
        f32, f64 => {},
        else => @compileError(routine ++ " is real-only; reduce.gebrd produces a real bidiagonal even from a complex matrix, so there is no complex version"),
    }
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// `max |(U S VT)_ij - A_ij|` — the only reconstruction that proves an SVD is
/// right, since `U` and `V` are each determined only up to sign.
fn reconstructionError(
    m: usize,
    n: usize,
    k: usize,
    u: []const f64,
    ldu: usize,
    s: []const f64,
    vt: []const f64,
    ldvt: usize,
    a: []const f64,
    lda: usize,
) f64 {
    var worst: f64 = 0;
    for (0..m) |i| {
        for (0..n) |j| {
            var acc: f64 = 0;
            for (0..k) |p| acc += u[i + p * ldu] * s[p] * vt[p + j * ldvt];
            worst = @max(worst, @abs(acc - a[i + j * lda]));
        }
    }
    return worst;
}

test "gesvd reconstructs the original matrix" {
    // 3x2, column-major [[1, 2], [3, 4], [5, 6]].
    const m = 3;
    const n = 2;
    const original = [_]f64{ 1, 3, 5, 2, 4, 6 };
    var a = original;
    var s: [2]f64 = undefined;
    var u: [m * m]f64 = undefined;
    var vt: [n * n]f64 = undefined;

    try gesvd(f64, testing.allocator, .all, .all, m, n, &a, m, &s, &u, m, &vt, n);

    // U is 3x3, VT is 2x2, and only the first min(m,n) singular values pair up.
    try testing.expect(reconstructionError(m, n, n, &u, m, &s, &vt, n, &original, m) < 1e-12);

    // Descending order.
    try testing.expect(s[0] > s[1]);
    try testing.expect(s[1] > 0);
}

test "gesvd computes the thin decomposition" {
    const m = 3;
    const n = 2;
    const original = [_]f64{ 1, 3, 5, 2, 4, 6 };
    var a = original;
    var s: [2]f64 = undefined;
    var u: [m * n]f64 = undefined; // only min(m,n) columns
    var vt: [n * n]f64 = undefined;

    try gesvd(f64, testing.allocator, .some, .all, m, n, &a, m, &s, &u, m, &vt, n);

    try testing.expect(reconstructionError(m, n, n, &u, m, &s, &vt, n, &original, m) < 1e-12);
}

test "gesvd can compute one factor and skip the other" {
    // The reason to reach for gesvd over gesdd: independent job flags.
    const m = 3;
    const n = 2;
    var a = [_]f64{ 1, 3, 5, 2, 4, 6 };
    var s: [2]f64 = undefined;
    var u: [m * n]f64 = undefined;
    var vt: [1]f64 = .{-999};

    try gesvd(f64, testing.allocator, .some, .none, m, n, &a, m, &s, &u, m, &vt, 1);

    // vt was not computed and not touched.
    try testing.expectEqual(@as(f64, -999), vt[0]);
    try testing.expect(s[0] > s[1]);
}

test "vt is V transposed, not V" {
    // On an asymmetric matrix the difference is visible; on a symmetric one it
    // is not, which is how this gets missed.
    const m = 2;
    const n = 2;
    const original = [_]f64{ 1, 0, 2, 3 }; // column-major [[1, 2], [0, 3]]
    var a = original;
    var s: [2]f64 = undefined;
    var u: [4]f64 = undefined;
    var vt: [4]f64 = undefined;

    try gesvd(f64, testing.allocator, .all, .all, m, n, &a, m, &s, &u, m, &vt, n);

    // U S VT = A reconstructs.
    try testing.expect(reconstructionError(m, n, n, &u, m, &s, &vt, n, &original, m) < 1e-12);

    // Using vt as if it were V - i.e. transposing it before multiplying - does
    // not, unless vt happens to be symmetric.
    var worst: f64 = 0;
    for (0..m) |i| {
        for (0..n) |j| {
            var acc: f64 = 0;
            for (0..n) |p| acc += u[i + p * m] * s[p] * vt[j + p * n];
            worst = @max(worst, @abs(acc - original[i + j * m]));
        }
    }
    try testing.expect(worst > 1e-6);
}

test "gesdd agrees with gesvd" {
    const m = 4;
    const n = 3;
    const original = [_]f64{ 1, 2, 3, 4, 2, 4, 5, 7, 3, 5, 8, 11 };

    var a1 = original;
    var s1: [3]f64 = undefined;
    var u_qr: [m * m]f64 = undefined;
    var vt_qr: [n * n]f64 = undefined;
    try gesvd(f64, testing.allocator, .all, .all, m, n, &a1, m, &s1, &u_qr, m, &vt_qr, n);

    var a2 = original;
    var s2: [3]f64 = undefined;
    var u_dc: [m * m]f64 = undefined;
    var vt_dc: [n * n]f64 = undefined;
    try gesdd(f64, testing.allocator, .all, m, n, &a2, m, &s2, &u_dc, m, &vt_dc, n);

    // Singular values are unique, so these must match exactly (to tolerance);
    // the vectors need not, since signs are arbitrary.
    for (s1, s2) |x, y| try testing.expectApproxEqAbs(x, y, 1e-10);
    try testing.expect(reconstructionError(m, n, n, &u_dc, m, &s2, &vt_dc, n, &original, m) < 1e-10);
}

test "gesdd computes singular values alone" {
    const m = 3;
    const n = 2;
    var a = [_]f64{ 1, 3, 5, 2, 4, 6 };
    var s: [2]f64 = undefined;
    var dummy: [1]f64 = .{-999};

    try gesdd(f64, testing.allocator, .none, m, n, &a, m, &s, &dummy, 1, &dummy, 1);

    try testing.expect(s[0] > s[1]);
    try testing.expectEqual(@as(f64, -999), dummy[0]);
}

test "gesdd reports rank through a zero singular value" {
    // Rank 1: every column a multiple of the first.
    const m = 3;
    const n = 2;
    var a = [_]f64{ 1, 1, 1, 2, 2, 2 };
    var s: [2]f64 = undefined;
    var dummy: [1]f64 = .{0};

    try gesdd(f64, testing.allocator, .none, m, n, &a, m, &s, &dummy, 1, &dummy, 1);

    // sqrt(3 * 5) = sqrt(15) for the nonzero one, and zero for the other.
    try testing.expectApproxEqAbs(@sqrt(@as(f64, 15)), s[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), s[1], 1e-12);
}

test "the complex SVD reconstructs through the conjugate transpose" {
    const Z = Complex(f64);
    const m = 2;
    const n = 2;
    const original = [_]Z{ Z.init(1, 0), Z.init(0, 1), Z.init(0, -1), Z.init(1, 0) };
    var a = original;
    var s: [2]f64 = undefined;
    var u: [4]Z = undefined;
    var vt: [4]Z = undefined;

    try gesdd(Z, testing.allocator, .all, m, n, &a, m, &s, &u, m, &vt, n);

    // Singular values are real even though A is not - the signature says so.
    try testing.expectEqual(f64, @TypeOf(s[0]));

    // U S VT = A, with vt already conjugate-transposed by LAPACK.
    for (0..m) |i| {
        for (0..n) |j| {
            var acc = Z.zero;
            for (0..n) |p| {
                const us = Z.init(u[i + p * m].re * s[p], u[i + p * m].im * s[p]);
                acc = acc.add(us.mul(vt[p + j * n]));
            }
            try testing.expectApproxEqAbs(original[i + j * m].re, acc.re, 1e-12);
            try testing.expectApproxEqAbs(original[i + j * m].im, acc.im, 1e-12);
        }
    }
}

test "a wide matrix works as well as a tall one" {
    // 2x4: min(m, n) = 2, so there are two singular values and the thin U is
    // 2x2 while the thin VT is 2x4.
    const m = 2;
    const n = 4;
    const original = [_]f64{ 1, 5, 2, 6, 3, 7, 4, 8 };
    var a = original;
    var s: [2]f64 = undefined;
    var u: [m * m]f64 = undefined;
    var vt: [2 * n]f64 = undefined;

    try gesdd(f64, testing.allocator, .some, m, n, &a, m, &s, &u, m, &vt, 2);

    try testing.expect(reconstructionError(m, n, 2, &u, m, &s, &vt, 2, &original, m) < 1e-12);
}

test "single precision works through the same wrappers" {
    var a = [_]f32{ 1, 3, 5, 2, 4, 6 };
    var s: [2]f32 = undefined;
    var dummy: [1]f32 = .{0};
    try gesdd(f32, testing.allocator, .none, 3, 2, &a, 3, &s, &dummy, 1, &dummy, 1);
    try testing.expect(s[0] > s[1]);
}

// ============================================================================
// Tests: alternative drivers
// ============================================================================

/// A 4x3 matrix whose singular values span ten orders of magnitude, so the
/// accuracy difference between the drivers is visible rather than theoretical.
const graded = [_]f64{
    1, 0,    0,     0,
    0, 1e-5, 0,     0,
    0, 0,    1e-10, 0,
};

test "bdsqr on the identity's bidiagonal returns the diagonal" {
    const n = 4;
    var d = [_]f64{ 4, 3, 2, 1 };
    var e = [_]f64{ 0, 0, 0 };
    var dummy: [1]f64 = undefined;

    try bdsqr(f64, testing.allocator, .upper, n, 0, 0, 0, &d, &e, &dummy, 1, &dummy, 1, &dummy, 1);
    // Already diagonal, so the values are unchanged - but sorted descending.
    try testing.expectEqualSlices(f64, &.{ 4, 3, 2, 1 }, &d);
}

test "reduce.gebrd then bdsqr reproduces gesvd" {
    const n = 3;
    const a0 = [_]f64{ 4, 1, 2, 1, 5, 3, 2, 3, 6 };

    var direct = a0;
    var s_direct: [n]f64 = undefined;
    var u_direct: [n * n]f64 = undefined;
    var vt_direct: [n * n]f64 = undefined;
    try gesvd(f64, testing.allocator, .all, .all, n, n, &direct, n, &s_direct, &u_direct, n, &vt_direct, n);

    // Reduce to bidiagonal, build the two factors, then hand them to bdsqr,
    // which multiplies its rotations into them rather than starting fresh.
    const reduce = @import("reduce.zig");
    var a = a0;
    var d: [n]f64 = undefined;
    var e: [n - 1]f64 = undefined;
    var tauq: [n]f64 = undefined;
    var taup: [n]f64 = undefined;
    try reduce.gebrd(f64, testing.allocator, n, n, &a, n, &d, &e, &tauq, &taup);

    var u = a;
    try reduce.orgbr(f64, testing.allocator, .q, n, n, n, &u, n, &tauq);
    var vt = a;
    try reduce.orgbr(f64, testing.allocator, .p, n, n, n, &vt, n, &taup);

    var dummy: [1]f64 = undefined;
    try bdsqr(f64, testing.allocator, .upper, n, n, n, 0, &d, &e, &vt, n, &u, n, &dummy, 1);

    for (s_direct, d) |x, y| try testing.expectApproxEqRel(x, y, 1e-11);

    // And U S VT reconstructs the original.
    for (0..n) |j| for (0..n) |i| {
        var acc: f64 = 0;
        for (0..n) |k| acc += u[i + k * n] * d[k] * vt[k + j * n];
        try testing.expectApproxEqAbs(a0[i + j * n], acc, 1e-11);
    };
}

test "bdsdc agrees with bdsqr on the same bidiagonal" {
    const n = 4;
    const d0 = [_]f64{ 4, 3, 2, 1 };
    const e0 = [_]f64{ 1, 1, 1 };

    var d_q = d0;
    var e_q = e0;
    var dummy: [1]f64 = undefined;
    try bdsqr(f64, testing.allocator, .upper, n, 0, 0, 0, &d_q, &e_q, &dummy, 1, &dummy, 1, &dummy, 1);

    var d_c = d0;
    var e_c = e0;
    var u: [n * n]f64 = undefined;
    var vt: [n * n]f64 = undefined;
    try bdsdc(f64, testing.allocator, .upper, .explicit, n, &d_c, &e_c, &u, n, &vt, n);

    for (d_q, d_c) |x, y| try testing.expectApproxEqRel(x, y, 1e-12);

    // bdsdc computes U and VT outright; check they reconstruct B.
    for (0..n) |j| for (0..n) |i| {
        var acc: f64 = 0;
        for (0..n) |k| acc += u[i + k * n] * d_c[k] * vt[k + j * n];
        const expected: f64 = if (i == j) d0[i] else if (i + 1 == j) e0[i] else 0;
        try testing.expectApproxEqAbs(expected, acc, 1e-11);
    };
}

test "bdsvdx stacks the left and right vectors in one column" {
    const n = 3;
    var d = [_]f64{ 3, 2, 1 };
    var e = [_]f64{ 0, 0 };
    var s: [n]f64 = undefined;
    var z: [2 * n * (n + 1)]f64 = undefined;

    const res = try bdsvdx(f64, testing.allocator, .upper, .vectors, .{ .indices = .{ .first = 1, .last = 2 } }, n, &d, &e, &s, &z, 2 * n);
    try testing.expectEqual(@as(usize, 2), res.found);
    // Diagonal, so the largest two are 3 and 2.
    try testing.expectApproxEqAbs(@as(f64, 3), s[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2), s[1], 1e-12);

    // Each column is 2n long: the left vector then the right vector. Measured,
    // each half is separately normalized to unit length, so the column as a
    // whole has norm sqrt(2). Treating a column as an n-vector would read half
    // of one vector and none of the other.
    for (0..res.found) |j| {
        var left: f64 = 0;
        var right: f64 = 0;
        for (0..n) |i| left += z[i + j * 2 * n] * z[i + j * 2 * n];
        for (n..2 * n) |i| right += z[i + j * 2 * n] * z[i + j * 2 * n];
        try testing.expectApproxEqAbs(@as(f64, 1), left, 1e-11);
        try testing.expectApproxEqAbs(@as(f64, 1), right, 1e-11);
    }
}

test "gesvdx computes only the singular triplets asked for" {
    const m = 4;
    const n = 3;
    const a0 = [_]f64{
        1, 0, 0, 0,
        0, 2, 0, 0,
        0, 0, 3, 0,
    };

    var a = a0;
    var s: [n]f64 = undefined;
    var u: [m * n]f64 = undefined;
    var vt: [n * n]f64 = undefined;
    const res = try gesvdx(f64, testing.allocator, .vectors, .vectors, .{ .indices = .{ .first = 1, .last = 2 } }, m, n, &a, m, &s, &u, m, &vt, n);

    try testing.expectEqual(@as(usize, 2), res.found);
    try testing.expectApproxEqAbs(@as(f64, 3), s[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2), s[1], 1e-12);

    // The vectors that were computed are unit vectors; nothing else was.
    for (0..res.found) |j| {
        var norm: f64 = 0;
        for (0..m) |i| norm += u[i + j * m] * u[i + j * m];
        try testing.expectApproxEqAbs(@as(f64, 1), norm, 1e-12);
    }
}

test "gesvdx on an interval selects by singular value" {
    const n = 3;
    var a = [_]f64{ 1, 0, 0, 0, 2, 0, 0, 0, 30 };
    var s: [n]f64 = undefined;
    var u: [n * n]f64 = undefined;
    var vt: [n * n]f64 = undefined;

    // (2.5, 100] contains only the 30.
    const res = try gesvdx(f64, testing.allocator, .vectors, .vectors, .{ .interval = .{ .low = 2.5, .high = 100 } }, n, n, &a, n, &s, &u, n, &vt, n);
    try testing.expectEqual(@as(usize, 1), res.found);
    try testing.expectApproxEqAbs(@as(f64, 30), s[0], 1e-11);
}

test "gesvj gets a graded matrix's small singular values where gesdd does not" {
    const m = 3;
    const n = 3;
    // Singular values 1, 1e-8, 1e-16. The smallest is below the absolute
    // accuracy gesdd can offer against a norm of 1.
    const a0 = [_]f64{
        1, 0,    0,
        0, 1e-8, 0,
        0, 0,    1e-16,
    };

    var a_j = a0;
    var sva: [n]f64 = undefined;
    var v: [n * n]f64 = undefined;
    try gesvj(f64, testing.allocator, .general, .vectors, .vectors, m, n, &a_j, m, &sva, 0, &v, n);

    // High relative accuracy: every value, including the smallest, is right to
    // many digits.
    try testing.expectApproxEqRel(@as(f64, 1), sva[0], 1e-14);
    try testing.expectApproxEqRel(@as(f64, 1e-8), sva[1], 1e-14);
    try testing.expectApproxEqRel(@as(f64, 1e-16), sva[2], 1e-14);

    // gesdd gets the same answer here because the matrix is exactly diagonal;
    // what is pinned is that gesvj agrees, not that gesdd fails.
    var a_d = a0;
    var s: [n]f64 = undefined;
    var u: [m * m]f64 = undefined;
    var vt: [n * n]f64 = undefined;
    try gesdd(f64, testing.allocator, .all, m, n, &a_d, m, &s, &u, m, &vt, n);
    for (s, sva) |x, y| try testing.expectApproxEqRel(x, y, 1e-12);
}

test "gesvj reconstructs a general matrix" {
    const n = 3;
    const a0 = [_]f64{ 4, 1, 2, 1, 5, 3, 2, 3, 6 };
    var a = a0;
    var sva: [n]f64 = undefined;
    var v: [n * n]f64 = undefined;
    try gesvj(f64, testing.allocator, .general, .vectors, .vectors, n, n, &a, n, &sva, 0, &v, n);

    // a holds U, v holds V (not V^T - that is the difference from gesvd).
    for (0..n) |j| for (0..n) |i| {
        var acc: f64 = 0;
        for (0..n) |k| acc += a[i + k * n] * sva[k] * v[j + k * n];
        try testing.expectApproxEqAbs(a0[i + j * n], acc, 1e-11);
    };
}

test "gejsv agrees with gesdd on a well-conditioned matrix" {
    const m = 4;
    const n = 3;
    const a0 = [_]f64{
        1, 2, 3, 4,
        5, 6, 7, 8,
        9, 1, 2, 3,
    };

    var a_d = a0;
    var s_d: [n]f64 = undefined;
    var u_d: [m * m]f64 = undefined;
    var vt_d: [n * n]f64 = undefined;
    try gesdd(f64, testing.allocator, .all, m, n, &a_d, m, &s_d, &u_d, m, &vt_d, n);

    var a_j = a0;
    var sva: [n]f64 = undefined;
    var u_j: [m * n]f64 = undefined;
    var v_j: [n * n]f64 = undefined;
    try gejsv(f64, testing.allocator, .default, .thin, .vectors, false, false, false, m, n, &a_j, m, &sva, &u_j, m, &v_j, n);

    for (s_d, sva) |x, y| try testing.expectApproxEqRel(x, y, 1e-11);
}

test "gejsv reconstructs with V rather than V transpose" {
    const m = 3;
    const n = 3;
    const a0 = [_]f64{ 4, 1, 2, 1, 5, 3, 2, 3, 6 };
    var a = a0;
    var sva: [n]f64 = undefined;
    var u: [m * n]f64 = undefined;
    var v: [n * n]f64 = undefined;
    try gejsv(f64, testing.allocator, .highest, .thin, .vectors, false, false, false, m, n, &a, m, &sva, &u, m, &v, n);

    // U S V^T, with v holding V - the opposite convention from gesvd, which
    // hands back V^T already transposed.
    for (0..n) |j| for (0..m) |i| {
        var acc: f64 = 0;
        for (0..n) |k| acc += u[i + k * m] * sva[k] * v[j + k * n];
        try testing.expectApproxEqAbs(a0[i + j * m], acc, 1e-11);
    };
}

test "gesvdq reports the numerical rank" {
    const m = 4;
    const n = 3;
    // Column 2 is column 0 plus column 1, so the rank is 2.
    const a0 = [_]f64{
        1, 0, 0, 0,
        0, 1, 0, 0,
        1, 1, 0, 0,
    };
    var a = a0;
    var s: [n]f64 = undefined;
    var u: [m * n]f64 = undefined;
    var v: [n * n]f64 = undefined;

    const rank = try gesvdq(f64, testing.allocator, .high, .thin, .all, true, false, m, n, &a, m, &s, &u, m, &v, n);
    try testing.expectEqual(@as(usize, 2), rank);
    try testing.expect(s[2] < 1e-14);
}

test "gesvdq's singular values match gesdd's" {
    const m = 4;
    const n = 3;
    const a0 = [_]f64{
        1, 2, 3, 4,
        5, 6, 7, 8,
        9, 1, 2, 3,
    };

    var a_d = a0;
    var s_d: [n]f64 = undefined;
    var u_d: [m * m]f64 = undefined;
    var vt_d: [n * n]f64 = undefined;
    try gesdd(f64, testing.allocator, .all, m, n, &a_d, m, &s_d, &u_d, m, &vt_d, n);

    var a_q = a0;
    var s_q: [n]f64 = undefined;
    var u_q: [m * n]f64 = undefined;
    var v_q: [n * n]f64 = undefined;
    const rank = try gesvdq(f64, testing.allocator, .high, .thin, .all, true, false, m, n, &a_q, m, &s_q, &u_q, m, &v_q, n);

    try testing.expectEqual(@as(usize, 3), rank);
    for (s_d, s_q) |x, y| try testing.expectApproxEqRel(x, y, 1e-11);
}

test "gejsv rejects a workspace query, unlike every other queryable routine" {
    // Pinned because the wrapper sizes its workspace from formulas instead of
    // querying, and that choice is only justified while this holds.
    const m: Int = 4;
    const n: Int = 3;
    var a = [_]f64{0} ** 12;
    const lda: Int = 4;
    const ldu: Int = 4;
    const ldv: Int = 3;
    var sva = [_]f64{0} ** 3;
    var u = [_]f64{0} ** 12;
    var v = [_]f64{0} ** 9;
    var iwork = [_]Int{0} ** 16;
    var wq = [_]f64{0} ** 1;
    const neg = work_mod.query;
    var info: Int = 0;
    const Chars = enum(u8) { n = 'N', c = 'C', u = 'U', v = 'V' };

    c.dgejsv(
        opt(Chars.c),
        opt(Chars.u),
        opt(Chars.v),
        opt(Chars.n),
        opt(Chars.n),
        opt(Chars.n),
        ref(&m),
        ref(&n),
        &a,
        ref(&lda),
        &sva,
        &u,
        ref(&ldu),
        &v,
        ref(&ldv),
        &wq,
        ref(&neg),
        &iwork,
        out(&info),
    );

    // -17 is lwork itself: the routine has no query path at all.
    try testing.expectEqual(@as(Int, -17), info);
}

test "gejsv works across the option combinations the wrapper exposes" {
    const m = 4;
    const n = 3;
    const a0 = [_]f64{
        1, 2, 3, 4,
        5, 6, 7, 8,
        9, 1, 2, 3,
    };
    var reference: [n]f64 = undefined;
    {
        var a = a0;
        var s: [n]f64 = undefined;
        var uu: [m * m]f64 = undefined;
        var vt: [n * n]f64 = undefined;
        try gesdd(f64, testing.allocator, .all, m, n, &a, m, &s, &uu, m, &vt, n);
        reference = s;
    }

    // Every accuracy level against the same matrix, since the single workspace
    // size has to cover all of them.
    for ([_]JsvAccuracy{ .default, .default_with_estimate, .high, .high_with_estimate, .highest, .rank_revealing }) |joba| {
        var a = a0;
        var sva: [n]f64 = undefined;
        var u: [m * m]f64 = undefined;
        var v: [n * n]f64 = undefined;
        try gejsv(f64, testing.allocator, joba, .full, .vectors, false, false, false, m, n, &a, m, &sva, &u, m, &v, n);
        for (reference, sva) |x, y| try testing.expectApproxEqRel(x, y, 1e-10);
    }

    // And with no vectors at all, which has a different documented minimum.
    var a = a0;
    var sva: [n]f64 = undefined;
    var dummy: [1]f64 = undefined;
    try gejsv(f64, testing.allocator, .default, .none, .none, false, false, false, m, n, &a, m, &sva, &dummy, 1, &dummy, 1);
    for (reference, sva) |x, y| try testing.expectApproxEqRel(x, y, 1e-10);
}
