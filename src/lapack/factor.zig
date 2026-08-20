//! Computational routines: factor once, then solve, invert or estimate a
//! condition number as many times as you like.
//!
//! This is the layer under `linear.zig`. `gesv` is exactly `getrf` followed by
//! `getrs`, and the reason to come here instead is that the factorization is
//! the expensive part — O(n^3) against O(n^2) for each solve. Factoring once
//! and solving repeatedly is the whole point.
//!
//! ## Condition numbers
//!
//! The `*con` routines estimate `rcond = 1 / (||A|| * ||A^-1||)`, and they take
//! `||A||` as an *input* — computed from the original matrix, before the
//! factorization overwrote it. Compute it first with `norms.lange` (or
//! `lansy`/`lantr`), or copy the matrix with `norms.lacpy` and compute it
//! after. Passing the norm of the factor produces a confident, meaningless
//! number, and nothing anywhere will complain.
//!
//! An `rcond` near 1 means well conditioned; near zero means the solution has
//! lost most of its significant digits. It is an estimate, and it can be off by
//! a factor of ten, which is fine for its purpose — you are deciding whether to
//! trust an answer, not measuring anything.
//!
//! The estimators here allocate their own scratch. The sizes vary by routine
//! *and* by whether `T` is real or complex (a real `gecon` wants `4n` reals and
//! `n` integers; a complex one wants `2n` complex and `2n` reals), and getting
//! one wrong is a heap overflow rather than an error, so it is not a number
//! worth exposing to callers.
//!
//! ## Pivot arrays are not interchangeable
//!
//! `getrf` produces row-interchange indices. `sytrf` produces Bunch-Kaufman
//! block pivots, where a negative entry marks a 2x2 block. `pstrf` produces a
//! permutation. All three are `[]Int` of length `n`, all three are 1-based, and
//! feeding one to the wrong solver is silent nonsense.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");

const Int = types.Int;
const Complex = types.Complex;
const Real = types.Real;
const Uplo = types.Uplo;
const Trans = types.Trans;
const Diag = types.Diag;
const Norm = types.Norm;
const Error = info_mod.Error;
const dim = types.dim;
const assertMatrix = types.assertMatrix;
const packedLen = types.packedLen;
const ref = work_mod.ref;
const out = work_mod.out;
const opt = types.opt;

const Allocator = std.mem.Allocator;
const Fail = Error || Allocator.Error;

fn sym(comptime T: type, comptime name: []const u8) @TypeOf(@field(c, [_]u8{types.prefix(T)} ++ name)) {
    return @field(c, [_]u8{types.prefix(T)} ++ name);
}

/// Rejects a real `T` at compile time.
///
/// Every real/complex split in this file is a `switch (T)` rather than an `if`
/// on a type predicate, because Zig analyses *both* arms of a plain `if` even
/// when the condition is comptime-known. For a `@compileError` guard that means
/// firing on every instantiation, including the valid ones; for the workspace
/// branches below it means type-checking the complex call shape against the
/// real symbol, which does not compile. Only the selected prong of a `switch`
/// is analysed.
fn requireComplex(comptime T: type, comptime routine: []const u8, comptime alternative: []const u8) void {
    switch (T) {
        Complex(f32), Complex(f64) => {},
        else => @compileError(routine ++ " is complex-only; for " ++ @typeName(T) ++ " use " ++ alternative),
    }
}

// ============================================================================
// LU of a general matrix
// ============================================================================

/// `A = P L U` by LU with partial pivoting, for an `rows x cols` matrix.
///
/// `a` is overwritten: `U` in the upper triangle, `L` below it with an implicit
/// unit diagonal. `ipiv` receives 1-based row interchanges — row `i` was
/// swapped with row `ipiv[i]`.
///
/// `error.SingularMatrix` means a pivot was exactly zero, so `getrs` cannot use
/// the result; `lastInfo()` gives its position. The factorization itself
/// completed either way, which is why `getri` and `gecon` are still meaningful
/// on a matrix that is merely *close* to singular — that case is not reported
/// here at all.
pub fn getrf(
    comptime T: type,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    ipiv: []Int,
) Error!void {
    assertMatrix(a.len, rows, cols, lda);
    std.debug.assert(ipiv.len >= @min(rows, cols));

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(lda);
    var info: Int = 0;

    sym(T, "getrf")(ref(&m_), ref(&n_), a.ptr, ref(&lda_), ipiv.ptr, out(&info));
    return info_mod.checkLu(info);
}

/// Solves `A X = B`, `A^T X = B` or `A^H X = B` using a `getrf` factorization.
///
/// `trans` selects which, and `.conj_trans` differs from `.trans` only for
/// complex `T` — for real elements LAPACK treats them the same.
pub fn getrs(
    comptime T: type,
    trans: Trans,
    n: usize,
    nrhs: usize,
    a: []const T,
    lda: usize,
    ipiv: []const Int,
    b: []T,
    ldb: usize,
) Error!void {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, nrhs, ldb);
    std.debug.assert(ipiv.len >= n);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, "getrs")(opt(trans), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), ipiv.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkArgs(info);
}

/// `A := A^-1`, in place, from a `getrf` factorization.
///
/// Explicitly inverting a matrix to solve a system is slower and less accurate
/// than `getrs`, and is almost never what you want. It is right when you need
/// the inverse's *entries* — a covariance matrix, say.
pub fn getri(
    comptime T: type,
    allocator: Allocator,
    n: usize,
    a: []T,
    lda: usize,
    ipiv: []const Int,
) Fail!void {
    const size = try getriWorkspaceSize(T, n, lda);
    const buf = try allocator.alloc(T, @max(size, 1));
    defer allocator.free(buf);
    return getriWithWorkspace(T, n, a, lda, ipiv, buf);
}

/// Optimal `work` length for `getri`. The documented minimum is `n`.
pub fn getriWorkspaceSize(comptime T: type, n: usize, lda: usize) Error!usize {
    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    const lwork = work_mod.query;
    var probe: [1]T = undefined;
    var ipiv: [1]Int = undefined;
    var wq: [1]T = undefined;
    var info: Int = 0;

    sym(T, "getri")(ref(&n_), &probe, ref(&lda_), &ipiv, &wq, ref(&lwork), out(&info));
    try info_mod.checkArgs(info);
    return @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
}

/// `getri` with a caller-supplied workspace.
pub fn getriWithWorkspace(
    comptime T: type,
    n: usize,
    a: []T,
    lda: usize,
    ipiv: []const Int,
    work: []T,
) Error!void {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(ipiv.len >= n);
    std.debug.assert(work.len >= 1);

    const n_ = dim(n);
    const lda_ = dim(lda);
    const lwork = dim(work.len);
    var info: Int = 0;

    sym(T, "getri")(ref(&n_), a.ptr, ref(&lda_), ipiv.ptr, work.ptr, ref(&lwork), out(&info));
    return info_mod.checkLu(info);
}

/// Estimates the reciprocal condition number of a general matrix, given a
/// `getrf` factorization and the norm of the **original** matrix.
///
/// `norm` must be `.one` or `.infinity`, and must match the norm `anorm` was
/// computed with — mixing them gives a wrong answer with no diagnostic.
pub fn gecon(
    comptime T: type,
    allocator: Allocator,
    norm: Norm,
    n: usize,
    a: []const T,
    lda: usize,
    anorm: Real(T),
) Fail!Real(T) {
    std.debug.assert(norm == .one or norm == .infinity);
    assertMatrix(a.len, n, n, lda);

    const n_ = dim(n);
    const lda_ = dim(lda);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => {
            // Complex gecon: work is 2n complex, rwork is 2n real.
            const work = try allocator.alloc(T, @max(2 * n, 1));
            defer allocator.free(work);
            const rwork = try allocator.alloc(Real(T), @max(2 * n, 1));
            defer allocator.free(rwork);
            sym(T, "gecon")(opt(norm), ref(&n_), a.ptr, ref(&lda_), ref(&anorm), out(&rcond), work.ptr, rwork.ptr, out(&info));
        },
        else => {
            // Real gecon: work is 4n real, iwork is n integers.
            const work = try allocator.alloc(T, @max(4 * n, 1));
            defer allocator.free(work);
            const iwork = try allocator.alloc(Int, @max(n, 1));
            defer allocator.free(iwork);
            sym(T, "gecon")(opt(norm), ref(&n_), a.ptr, ref(&lda_), ref(&anorm), out(&rcond), work.ptr, iwork.ptr, out(&info));
        },
    }

    try info_mod.checkArgs(info);
    return rcond;
}

/// Row and column scale factors that equilibrate a general matrix.
pub const Equilibration = struct {
    /// Ratio of smallest to largest row scale factor. If this is close to 1,
    /// scaling the rows is not worth doing.
    row_cond: f64,
    /// The same for columns.
    col_cond: f64,
    /// Largest absolute element of the matrix, for detecting overflow risk.
    max_abs: f64,
};

/// Computes row and column scalings `R` and `C` such that `R A C` has entries
/// of roughly equal magnitude.
///
/// Returns `error.SingularMatrix` if a row or column is exactly zero;
/// `lastInfo()` is then the index — `<= n` for a row, `> n` for a column.
pub fn geequ(
    comptime T: type,
    rows: usize,
    cols: usize,
    a: []const T,
    lda: usize,
    r: []Real(T),
    col_scale: []Real(T),
) Error!Equilibration {
    assertMatrix(a.len, rows, cols, lda);
    std.debug.assert(r.len >= rows);
    std.debug.assert(col_scale.len >= cols);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(lda);
    var rowcnd: Real(T) = 0;
    var colcnd: Real(T) = 0;
    var amax: Real(T) = 0;
    var info: Int = 0;

    sym(T, "geequ")(ref(&m_), ref(&n_), a.ptr, ref(&lda_), r.ptr, col_scale.ptr, out(&rowcnd), out(&colcnd), out(&amax), out(&info));
    try info_mod.checkLu(info);
    return .{ .row_cond = rowcnd, .col_cond = colcnd, .max_abs = amax };
}

// ============================================================================
// LU of band and tridiagonal matrices
// ============================================================================

/// `A = P L U` for a band matrix.
///
/// The band array needs `kl` extra rows above the band for fill-in, so
/// `ldab >= 2*kl + ku + 1` — the same layout `gbsv` wants and *not* the one
/// `gbmv`/`langb` want.
pub fn gbtrf(
    comptime T: type,
    rows: usize,
    cols: usize,
    kl: usize,
    ku: usize,
    ab: []T,
    ldab: usize,
    ipiv: []Int,
) Error!void {
    std.debug.assert(ldab >= 2 * kl + ku + 1);
    assertMatrix(ab.len, 2 * kl + ku + 1, cols, ldab);
    std.debug.assert(ipiv.len >= @min(rows, cols));

    const m_ = dim(rows);
    const n_ = dim(cols);
    const kl_ = dim(kl);
    const ku_ = dim(ku);
    const ldab_ = dim(ldab);
    var info: Int = 0;

    sym(T, "gbtrf")(ref(&m_), ref(&n_), ref(&kl_), ref(&ku_), ab.ptr, ref(&ldab_), ipiv.ptr, out(&info));
    return info_mod.checkLu(info);
}

/// Solves using a `gbtrf` factorization.
pub fn gbtrs(
    comptime T: type,
    trans: Trans,
    n: usize,
    kl: usize,
    ku: usize,
    nrhs: usize,
    ab: []const T,
    ldab: usize,
    ipiv: []const Int,
    b: []T,
    ldb: usize,
) Error!void {
    std.debug.assert(ldab >= 2 * kl + ku + 1);
    assertMatrix(b.len, n, nrhs, ldb);
    std.debug.assert(ipiv.len >= n);

    const n_ = dim(n);
    const kl_ = dim(kl);
    const ku_ = dim(ku);
    const nrhs_ = dim(nrhs);
    const ldab_ = dim(ldab);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, "gbtrs")(opt(trans), ref(&n_), ref(&kl_), ref(&ku_), ref(&nrhs_), ab.ptr, ref(&ldab_), ipiv.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkArgs(info);
}

/// `A = L U` for a tridiagonal matrix.
///
/// Unlike `gtsv`, this keeps the factorization: `du2` receives a second
/// superdiagonal that pivoting can create, and `gttrs` needs all four arrays
/// plus `ipiv`.
pub fn gttrf(
    comptime T: type,
    n: usize,
    dl: []T,
    d: []T,
    du: []T,
    du2: []T,
    ipiv: []Int,
) Error!void {
    std.debug.assert(d.len >= n);
    if (n > 1) {
        std.debug.assert(dl.len >= n - 1);
        std.debug.assert(du.len >= n - 1);
    }
    if (n > 2) std.debug.assert(du2.len >= n - 2);
    std.debug.assert(ipiv.len >= n);

    const n_ = dim(n);
    var info: Int = 0;

    sym(T, "gttrf")(ref(&n_), dl.ptr, d.ptr, du.ptr, du2.ptr, ipiv.ptr, out(&info));
    return info_mod.checkLu(info);
}

/// Solves using a `gttrf` factorization.
pub fn gttrs(
    comptime T: type,
    trans: Trans,
    n: usize,
    nrhs: usize,
    dl: []const T,
    d: []const T,
    du: []const T,
    du2: []const T,
    ipiv: []const Int,
    b: []T,
    ldb: usize,
) Error!void {
    std.debug.assert(d.len >= n);
    std.debug.assert(ipiv.len >= n);
    assertMatrix(b.len, n, nrhs, ldb);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, "gttrs")(opt(trans), ref(&n_), ref(&nrhs_), dl.ptr, d.ptr, du.ptr, du2.ptr, ipiv.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkArgs(info);
}

// ============================================================================
// Cholesky
// ============================================================================

/// `A = U^H U` or `A = L L^H`, reading and writing only the `uplo` triangle.
///
/// `error.NotPositiveDefinite` with `lastInfo()` giving the order of the
/// leading minor that failed. This is the standard cheap test for positive
/// definiteness, so that error is often the answer you wanted rather than a
/// failure.
pub fn potrf(comptime T: type, uplo: Uplo, n: usize, a: []T, lda: usize) Error!void {
    assertMatrix(a.len, n, n, lda);

    const n_ = dim(n);
    const lda_ = dim(lda);
    var info: Int = 0;

    sym(T, "potrf")(opt(uplo), ref(&n_), a.ptr, ref(&lda_), out(&info));
    return info_mod.checkCholesky(info);
}

/// Solves using a `potrf` factorization.
pub fn potrs(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []const T,
    lda: usize,
    b: []T,
    ldb: usize,
) Error!void {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, nrhs, ldb);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, "potrs")(opt(uplo), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkArgs(info);
}

/// `A := A^-1` from a `potrf` factorization.
///
/// Only the `uplo` triangle of the result is written — the inverse of a
/// symmetric matrix is symmetric, so the other half is redundant and LAPACK
/// does not fill it in. Code that then treats `a` as a full matrix reads
/// whatever was there before.
pub fn potri(comptime T: type, uplo: Uplo, n: usize, a: []T, lda: usize) Error!void {
    assertMatrix(a.len, n, n, lda);

    const n_ = dim(n);
    const lda_ = dim(lda);
    var info: Int = 0;

    sym(T, "potri")(opt(uplo), ref(&n_), a.ptr, ref(&lda_), out(&info));
    return info_mod.checkLu(info);
}

/// Reciprocal condition number from a `potrf` factorization. `anorm` is the
/// 1-norm of the original matrix (`norms.lansy` or `lanhe`).
pub fn pocon(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []const T,
    lda: usize,
    anorm: Real(T),
) Fail!Real(T) {
    assertMatrix(a.len, n, n, lda);

    const n_ = dim(n);
    const lda_ = dim(lda);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => {
            const work = try allocator.alloc(T, @max(2 * n, 1));
            defer allocator.free(work);
            const rwork = try allocator.alloc(Real(T), @max(n, 1));
            defer allocator.free(rwork);
            sym(T, "pocon")(opt(uplo), ref(&n_), a.ptr, ref(&lda_), ref(&anorm), out(&rcond), work.ptr, rwork.ptr, out(&info));
        },
        else => {
            const work = try allocator.alloc(T, @max(3 * n, 1));
            defer allocator.free(work);
            const iwork = try allocator.alloc(Int, @max(n, 1));
            defer allocator.free(iwork);
            sym(T, "pocon")(opt(uplo), ref(&n_), a.ptr, ref(&lda_), ref(&anorm), out(&rcond), work.ptr, iwork.ptr, out(&info));
        },
    }

    try info_mod.checkArgs(info);
    return rcond;
}

/// A *split* Cholesky factorization of a positive definite band matrix.
///
/// Not the same as `pbtrf`. This produces `S^H S` where `S` is upper triangular
/// in its first `(n + kd) / 2` rows and lower triangular below that — a hybrid
/// that keeps the bandwidth of the *generalized* band eigenproblem from growing
/// during the reduction. `eigen.sbgst` is the only consumer, and it will not
/// accept a `pbtrf` factor.
///
/// `error.NotPositiveDefinite` with `lastInfo()` giving the position where the
/// factorization broke down.
pub fn pbstf(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    kd: usize,
    ab: []T,
    ldab: usize,
) Error!void {
    std.debug.assert(ldab >= kd + 1);

    const n_ = dim(n);
    const kd_ = dim(kd);
    const ldab_ = dim(ldab);
    var info: Int = 0;

    sym(T, "pbstf")(opt(uplo), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), out(&info));
    return info_mod.checkCholesky(info);
}

/// Cholesky of a packed matrix.
pub fn pptrf(comptime T: type, uplo: Uplo, n: usize, ap: []T) Error!void {
    std.debug.assert(ap.len >= packedLen(n));

    const n_ = dim(n);
    var info: Int = 0;

    sym(T, "pptrf")(opt(uplo), ref(&n_), ap.ptr, out(&info));
    return info_mod.checkCholesky(info);
}

/// Solves using a `pptrf` factorization.
pub fn pptrs(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    ap: []const T,
    b: []T,
    ldb: usize,
) Error!void {
    std.debug.assert(ap.len >= packedLen(n));
    assertMatrix(b.len, n, nrhs, ldb);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, "pptrs")(opt(uplo), ref(&n_), ref(&nrhs_), ap.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkArgs(info);
}

/// `A := A^-1` in packed storage, from `pptrf`.
pub fn pptri(comptime T: type, uplo: Uplo, n: usize, ap: []T) Error!void {
    std.debug.assert(ap.len >= packedLen(n));

    const n_ = dim(n);
    var info: Int = 0;

    sym(T, "pptri")(opt(uplo), ref(&n_), ap.ptr, out(&info));
    return info_mod.checkLu(info);
}

/// Cholesky of a positive definite band matrix. `ldab >= kd + 1` — no fill-in
/// rows, unlike the general band case.
pub fn pbtrf(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    kd: usize,
    ab: []T,
    ldab: usize,
) Error!void {
    std.debug.assert(ldab >= kd + 1);
    assertMatrix(ab.len, kd + 1, n, ldab);

    const n_ = dim(n);
    const kd_ = dim(kd);
    const ldab_ = dim(ldab);
    var info: Int = 0;

    sym(T, "pbtrf")(opt(uplo), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), out(&info));
    return info_mod.checkCholesky(info);
}

/// Solves using a `pbtrf` factorization.
pub fn pbtrs(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    kd: usize,
    nrhs: usize,
    ab: []const T,
    ldab: usize,
    b: []T,
    ldb: usize,
) Error!void {
    std.debug.assert(ldab >= kd + 1);
    assertMatrix(b.len, n, nrhs, ldb);

    const n_ = dim(n);
    const kd_ = dim(kd);
    const nrhs_ = dim(nrhs);
    const ldab_ = dim(ldab);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, "pbtrs")(opt(uplo), ref(&n_), ref(&kd_), ref(&nrhs_), ab.ptr, ref(&ldab_), b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkArgs(info);
}

/// `A = L D L^H` for a positive definite tridiagonal matrix.
///
/// `d` is real even when `A` is complex — see `linear.ptsv`.
pub fn pttrf(comptime T: type, n: usize, d: []Real(T), e: []T) Error!void {
    std.debug.assert(d.len >= n);
    if (n > 1) std.debug.assert(e.len >= n - 1);

    const n_ = dim(n);
    var info: Int = 0;

    sym(T, "pttrf")(ref(&n_), d.ptr, e.ptr, out(&info));
    return info_mod.checkCholesky(info);
}

/// Solves using a `pttrf` factorization.
///
/// The real and complex forms differ in shape: the complex one takes a `uplo`
/// telling it whether `e` holds the sub- or superdiagonal of the factor, and
/// the real one does not. That is why this wrapper takes `uplo` and quietly
/// drops it for real `T` rather than offering two functions.
pub fn pttrs(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    d: []const Real(T),
    e: []const T,
    b: []T,
    ldb: usize,
) Error!void {
    std.debug.assert(d.len >= n);
    assertMatrix(b.len, n, nrhs, ldb);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => {
            sym(T, "pttrs")(opt(uplo), ref(&n_), ref(&nrhs_), d.ptr, e.ptr, b.ptr, ref(&ldb_), out(&info));
        },
        else => {
            sym(T, "pttrs")(ref(&n_), ref(&nrhs_), d.ptr, e.ptr, b.ptr, ref(&ldb_), out(&info));
        },
    }
    return info_mod.checkArgs(info);
}

/// Cholesky with complete pivoting, for a matrix that may be only positive
/// *semi*definite.
///
/// Returns the computed rank. Unlike `potrf`, a rank-deficient matrix is not an
/// error here — detecting the rank is the point. `piv` receives the 1-based
/// permutation, and `tol` selects the stopping tolerance (pass a negative value
/// for the LAPACK default, `n * eps * max(diag)`).
pub fn pstrf(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    piv: []Int,
    tol: Real(T),
) Fail!usize {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(piv.len >= n);

    const work = try allocator.alloc(Real(T), @max(2 * n, 1));
    defer allocator.free(work);

    const n_ = dim(n);
    const lda_ = dim(lda);
    var rank: Int = 0;
    var info: Int = 0;

    sym(T, "pstrf")(opt(uplo), ref(&n_), a.ptr, ref(&lda_), piv.ptr, out(&rank), ref(&tol), work.ptr, out(&info));

    // info > 0 reports rank deficiency, which is a result rather than a
    // failure, so only the negative case is an error here.
    if (info < 0) try info_mod.checkArgs(info);
    return @intCast(rank);
}

// ============================================================================
// Symmetric and Hermitian indefinite
// ============================================================================

/// `A = U D U^T` or `A = L D L^T` by Bunch-Kaufman, for a symmetric matrix.
///
/// `ipiv` encodes block pivots: a positive entry is a 1x1 block, and a
/// *negative* pair marks a 2x2 one. This is not the same encoding as `getrf`'s
/// row interchanges.
pub fn sytrf(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    ipiv: []Int,
) Fail!void {
    const size = try indefiniteWorkspaceSize(T, "sytrf", uplo, n, lda);
    const buf = try allocator.alloc(T, @max(size, 1));
    defer allocator.free(buf);
    return sytrfWithWorkspace(T, uplo, n, a, lda, ipiv, buf);
}

/// `sytrf` with a caller-supplied workspace.
pub fn sytrfWithWorkspace(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    ipiv: []Int,
    work: []T,
) Error!void {
    return indefiniteFactor(T, "sytrf", uplo, n, a, lda, ipiv, work);
}

/// `A = U D U^H` or `A = L D L^H` for a Hermitian matrix. Complex only.
pub fn hetrf(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    ipiv: []Int,
) Fail!void {
    requireComplex(T, "hetrf", "sytrf");
    const size = try indefiniteWorkspaceSize(T, "hetrf", uplo, n, lda);
    const buf = try allocator.alloc(T, @max(size, 1));
    defer allocator.free(buf);
    return hetrfWithWorkspace(T, uplo, n, a, lda, ipiv, buf);
}

/// `hetrf` with a caller-supplied workspace.
pub fn hetrfWithWorkspace(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    ipiv: []Int,
    work: []T,
) Error!void {
    requireComplex(T, "hetrf", "sytrf");
    return indefiniteFactor(T, "hetrf", uplo, n, a, lda, ipiv, work);
}

fn indefiniteFactor(
    comptime T: type,
    comptime name: []const u8,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    ipiv: []Int,
    work: []T,
) Error!void {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(ipiv.len >= n);
    std.debug.assert(work.len >= 1);

    const n_ = dim(n);
    const lda_ = dim(lda);
    const lwork = dim(work.len);
    var info: Int = 0;

    sym(T, name)(opt(uplo), ref(&n_), a.ptr, ref(&lda_), ipiv.ptr, work.ptr, ref(&lwork), out(&info));
    return info_mod.checkIndefinite(info);
}

fn indefiniteWorkspaceSize(
    comptime T: type,
    comptime name: []const u8,
    uplo: Uplo,
    n: usize,
    lda: usize,
) Error!usize {
    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    const lwork = work_mod.query;
    var probe: [1]T = undefined;
    var ipiv: [1]Int = undefined;
    var wq: [1]T = undefined;
    var info: Int = 0;

    sym(T, name)(opt(uplo), ref(&n_), &probe, ref(&lda_), &ipiv, &wq, ref(&lwork), out(&info));
    try info_mod.checkArgs(info);
    return @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
}

/// Optimal `work` length for `sytrf`.
pub fn sytrfWorkspaceSize(comptime T: type, uplo: Uplo, n: usize, lda: usize) Error!usize {
    return indefiniteWorkspaceSize(T, "sytrf", uplo, n, lda);
}

/// Optimal `work` length for `hetrf`.
pub fn hetrfWorkspaceSize(comptime T: type, uplo: Uplo, n: usize, lda: usize) Error!usize {
    requireComplex(T, "hetrf", "sytrf");
    return indefiniteWorkspaceSize(T, "hetrf", uplo, n, lda);
}

/// Solves using a `sytrf` factorization.
pub fn sytrs(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []const T,
    lda: usize,
    ipiv: []const Int,
    b: []T,
    ldb: usize,
) Error!void {
    return indefiniteSolve(T, "sytrs", uplo, n, nrhs, a, lda, ipiv, b, ldb);
}

/// Solves using a `hetrf` factorization. Complex only.
pub fn hetrs(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []const T,
    lda: usize,
    ipiv: []const Int,
    b: []T,
    ldb: usize,
) Error!void {
    requireComplex(T, "hetrs", "sytrs");
    return indefiniteSolve(T, "hetrs", uplo, n, nrhs, a, lda, ipiv, b, ldb);
}

fn indefiniteSolve(
    comptime T: type,
    comptime name: []const u8,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []const T,
    lda: usize,
    ipiv: []const Int,
    b: []T,
    ldb: usize,
) Error!void {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, nrhs, ldb);
    std.debug.assert(ipiv.len >= n);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, name)(opt(uplo), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), ipiv.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkArgs(info);
}

/// `A := A^-1` from a `sytrf` factorization, writing only the `uplo` triangle.
pub fn sytri(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    ipiv: []const Int,
) Fail!void {
    return indefiniteInvert(T, "sytri", allocator, uplo, n, a, lda, ipiv);
}

/// `A := A^-1` from a `hetrf` factorization. Complex only.
pub fn hetri(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    ipiv: []const Int,
) Fail!void {
    requireComplex(T, "hetri", "sytri");
    return indefiniteInvert(T, "hetri", allocator, uplo, n, a, lda, ipiv);
}

fn indefiniteInvert(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    ipiv: []const Int,
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(ipiv.len >= n);

    // sytri/hetri take a fixed n-element workspace with no query available.
    const work = try allocator.alloc(T, @max(n, 1));
    defer allocator.free(work);

    const n_ = dim(n);
    const lda_ = dim(lda);
    var info: Int = 0;

    sym(T, name)(opt(uplo), ref(&n_), a.ptr, ref(&lda_), ipiv.ptr, work.ptr, out(&info));
    return info_mod.checkLu(info);
}

/// Reciprocal condition number from a `sytrf` factorization.
pub fn sycon(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []const T,
    lda: usize,
    ipiv: []const Int,
    anorm: Real(T),
) Fail!Real(T) {
    return indefiniteCondition(T, "sycon", allocator, uplo, n, a, lda, ipiv, anorm);
}

/// Reciprocal condition number from a `hetrf` factorization. Complex only.
pub fn hecon(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []const T,
    lda: usize,
    ipiv: []const Int,
    anorm: Real(T),
) Fail!Real(T) {
    requireComplex(T, "hecon", "sycon");
    return indefiniteCondition(T, "hecon", allocator, uplo, n, a, lda, ipiv, anorm);
}

fn indefiniteCondition(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []const T,
    lda: usize,
    ipiv: []const Int,
    anorm: Real(T),
) Fail!Real(T) {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(ipiv.len >= n);

    const work = try allocator.alloc(T, @max(2 * n, 1));
    defer allocator.free(work);

    const n_ = dim(n);
    const lda_ = dim(lda);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => {
            // The complex sycon/hecon take no rwork at all - unlike gecon,
            // pocon and trcon, which all do. A binding that assumed the pattern
            // held would pass an extra argument, landing the real `info` one
            // slot further along.
            sym(T, name)(opt(uplo), ref(&n_), a.ptr, ref(&lda_), ipiv.ptr, ref(&anorm), out(&rcond), work.ptr, out(&info));
        },
        else => {
            const iwork = try allocator.alloc(Int, @max(n, 1));
            defer allocator.free(iwork);
            sym(T, name)(opt(uplo), ref(&n_), a.ptr, ref(&lda_), ipiv.ptr, ref(&anorm), out(&rcond), work.ptr, iwork.ptr, out(&info));
        },
    }

    try info_mod.checkArgs(info);
    return rcond;
}

/// Bunch-Kaufman factorization of a symmetric matrix in packed storage.
pub fn sptrf(comptime T: type, uplo: Uplo, n: usize, ap: []T, ipiv: []Int) Error!void {
    return packedFactor(T, "sptrf", uplo, n, ap, ipiv);
}

/// Bunch-Kaufman factorization of a packed Hermitian matrix. Complex only.
pub fn hptrf(comptime T: type, uplo: Uplo, n: usize, ap: []T, ipiv: []Int) Error!void {
    requireComplex(T, "hptrf", "sptrf");
    return packedFactor(T, "hptrf", uplo, n, ap, ipiv);
}

fn packedFactor(
    comptime T: type,
    comptime name: []const u8,
    uplo: Uplo,
    n: usize,
    ap: []T,
    ipiv: []Int,
) Error!void {
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(ipiv.len >= n);

    const n_ = dim(n);
    var info: Int = 0;

    sym(T, name)(opt(uplo), ref(&n_), ap.ptr, ipiv.ptr, out(&info));
    return info_mod.checkIndefinite(info);
}

/// Solves using an `sptrf` factorization.
pub fn sptrs(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    ap: []const T,
    ipiv: []const Int,
    b: []T,
    ldb: usize,
) Error!void {
    return packedSolve(T, "sptrs", uplo, n, nrhs, ap, ipiv, b, ldb);
}

/// Solves using an `hptrf` factorization. Complex only.
pub fn hptrs(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    ap: []const T,
    ipiv: []const Int,
    b: []T,
    ldb: usize,
) Error!void {
    requireComplex(T, "hptrs", "sptrs");
    return packedSolve(T, "hptrs", uplo, n, nrhs, ap, ipiv, b, ldb);
}

fn packedSolve(
    comptime T: type,
    comptime name: []const u8,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    ap: []const T,
    ipiv: []const Int,
    b: []T,
    ldb: usize,
) Error!void {
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(ipiv.len >= n);
    assertMatrix(b.len, n, nrhs, ldb);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, name)(opt(uplo), ref(&n_), ref(&nrhs_), ap.ptr, ipiv.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkArgs(info);
}

/// `A := A^-1` in packed storage, from `sptrf`.
pub fn sptri(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    ap: []T,
    ipiv: []const Int,
) Fail!void {
    return packedInvert(T, "sptri", allocator, uplo, n, ap, ipiv);
}

/// `A := A^-1` in packed storage, from `hptrf`. Complex only.
pub fn hptri(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    ap: []T,
    ipiv: []const Int,
) Fail!void {
    requireComplex(T, "hptri", "sptri");
    return packedInvert(T, "hptri", allocator, uplo, n, ap, ipiv);
}

fn packedInvert(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    ap: []T,
    ipiv: []const Int,
) Fail!void {
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(ipiv.len >= n);

    const work = try allocator.alloc(T, @max(n, 1));
    defer allocator.free(work);

    const n_ = dim(n);
    var info: Int = 0;

    sym(T, name)(opt(uplo), ref(&n_), ap.ptr, ipiv.ptr, work.ptr, out(&info));
    return info_mod.checkLu(info);
}

// ============================================================================
// Triangular
// ============================================================================

/// Solves a triangular system directly — no factorization needed, since a
/// triangular matrix already is one.
pub fn trtrs(
    comptime T: type,
    uplo: Uplo,
    trans: Trans,
    diag: Diag,
    n: usize,
    nrhs: usize,
    a: []const T,
    lda: usize,
    b: []T,
    ldb: usize,
) Error!void {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, nrhs, ldb);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, "trtrs")(opt(uplo), opt(trans), opt(diag), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), out(&info));
    // Unlike blas.trsm, this one checks for a zero diagonal element first.
    return info_mod.checkLu(info);
}

/// `A := A^-1` for a triangular matrix, in place.
pub fn trtri(comptime T: type, uplo: Uplo, diag: Diag, n: usize, a: []T, lda: usize) Error!void {
    assertMatrix(a.len, n, n, lda);

    const n_ = dim(n);
    const lda_ = dim(lda);
    var info: Int = 0;

    sym(T, "trtri")(opt(uplo), opt(diag), ref(&n_), a.ptr, ref(&lda_), out(&info));
    return info_mod.checkLu(info);
}

/// Reciprocal condition number of a triangular matrix.
///
/// Unlike the other estimators, this one needs no `anorm` — it has the matrix
/// itself, not a factorization of it, so it computes the norm internally.
pub fn trcon(
    comptime T: type,
    allocator: Allocator,
    norm: Norm,
    uplo: Uplo,
    diag: Diag,
    n: usize,
    a: []const T,
    lda: usize,
) Fail!Real(T) {
    std.debug.assert(norm == .one or norm == .infinity);
    assertMatrix(a.len, n, n, lda);

    const n_ = dim(n);
    const lda_ = dim(lda);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => {
            const work = try allocator.alloc(T, @max(2 * n, 1));
            defer allocator.free(work);
            const rwork = try allocator.alloc(Real(T), @max(n, 1));
            defer allocator.free(rwork);
            sym(T, "trcon")(opt(norm), opt(uplo), opt(diag), ref(&n_), a.ptr, ref(&lda_), out(&rcond), work.ptr, rwork.ptr, out(&info));
        },
        else => {
            const work = try allocator.alloc(T, @max(3 * n, 1));
            defer allocator.free(work);
            const iwork = try allocator.alloc(Int, @max(n, 1));
            defer allocator.free(iwork);
            sym(T, "trcon")(opt(norm), opt(uplo), opt(diag), ref(&n_), a.ptr, ref(&lda_), out(&rcond), work.ptr, iwork.ptr, out(&info));
        },
    }

    try info_mod.checkArgs(info);
    return rcond;
}

/// `trtrs` in packed storage.
pub fn tptrs(
    comptime T: type,
    uplo: Uplo,
    trans: Trans,
    diag: Diag,
    n: usize,
    nrhs: usize,
    ap: []const T,
    b: []T,
    ldb: usize,
) Error!void {
    std.debug.assert(ap.len >= packedLen(n));
    assertMatrix(b.len, n, nrhs, ldb);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, "tptrs")(opt(uplo), opt(trans), opt(diag), ref(&n_), ref(&nrhs_), ap.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkLu(info);
}

/// `trtri` in packed storage.
pub fn tptri(comptime T: type, uplo: Uplo, diag: Diag, n: usize, ap: []T) Error!void {
    std.debug.assert(ap.len >= packedLen(n));

    const n_ = dim(n);
    var info: Int = 0;

    sym(T, "tptri")(opt(uplo), opt(diag), ref(&n_), ap.ptr, out(&info));
    return info_mod.checkLu(info);
}

/// `trtrs` for a triangular band matrix. `ldab >= kd + 1`.
pub fn tbtrs(
    comptime T: type,
    uplo: Uplo,
    trans: Trans,
    diag: Diag,
    n: usize,
    kd: usize,
    nrhs: usize,
    ab: []const T,
    ldab: usize,
    b: []T,
    ldb: usize,
) Error!void {
    std.debug.assert(ldab >= kd + 1);
    assertMatrix(ab.len, kd + 1, n, ldab);
    assertMatrix(b.len, n, nrhs, ldb);

    const n_ = dim(n);
    const kd_ = dim(kd);
    const nrhs_ = dim(nrhs);
    const ldab_ = dim(ldab);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, "tbtrs")(opt(uplo), opt(trans), opt(diag), ref(&n_), ref(&kd_), ref(&nrhs_), ab.ptr, ref(&ldab_), b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkLu(info);
}

// ============================================================================
// Storage conversion
// ============================================================================

/// Full triangular storage to packed.
pub fn trttp(comptime T: type, uplo: Uplo, n: usize, a: []const T, lda: usize, ap: []T) Error!void {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(ap.len >= packedLen(n));

    const n_ = dim(n);
    const lda_ = dim(lda);
    var info: Int = 0;

    sym(T, "trttp")(opt(uplo), ref(&n_), a.ptr, ref(&lda_), ap.ptr, out(&info));
    return info_mod.checkArgs(info);
}

/// Packed triangular storage to full.
///
/// Only the `uplo` triangle of the destination is written; the other half keeps
/// whatever was in it.
pub fn tpttr(comptime T: type, uplo: Uplo, n: usize, ap: []const T, a: []T, lda: usize) Error!void {
    std.debug.assert(ap.len >= packedLen(n));
    assertMatrix(a.len, n, n, lda);

    const n_ = dim(n);
    const lda_ = dim(lda);
    var info: Int = 0;

    sym(T, "tpttr")(opt(uplo), ref(&n_), ap.ptr, a.ptr, ref(&lda_), out(&info));
    return info_mod.checkArgs(info);
}

// ============================================================================
// Condition estimators for the remaining storage forms
// ============================================================================

/// The scratch the `*con` estimators want.
///
/// Every one of them takes two workspaces whose element types flip with `T`:
/// real routines want `T` plus `Int`, complex ones want `T` plus `Real(T)`. The
/// *sizes* differ per routine, which is why they are parameters here rather
/// than constants — `gecon` wants `4n` reals where `pocon` wants `3n` and
/// `spcon` wants `2n`, and each is a heap overflow if you guess low.
///
/// A few complex routines (`gtcon`, `spcon`, `hpcon`) take no second workspace
/// at all; pass `0` for `reals` and they allocate nothing.
fn ConScratch(comptime T: type) type {
    return struct {
        const Self = @This();
        work: []T,
        iwork: []Int,
        rwork: []Real(T),
        allocator: Allocator,

        fn init(allocator: Allocator, reals: usize, complexes: usize, ints: usize) !Self {
            return switch (T) {
                Complex(f32), Complex(f64) => .{
                    .work = try allocator.alloc(T, @max(complexes, 1)),
                    .iwork = &.{},
                    .rwork = try allocator.alloc(Real(T), @max(ints, 1)),
                    .allocator = allocator,
                },
                else => .{
                    .work = try allocator.alloc(T, @max(reals, 1)),
                    .iwork = try allocator.alloc(Int, @max(ints, 1)),
                    .rwork = &.{},
                    .allocator = allocator,
                },
            };
        }

        fn deinit(self: Self) void {
            self.allocator.free(self.work);
            if (self.iwork.len > 0) self.allocator.free(self.iwork);
            if (self.rwork.len > 0) self.allocator.free(self.rwork);
        }
    };
}

/// `gecon` for a band matrix factored by `gbtrf`.
///
/// `ab` is the *factored* band array, so `ldab >= 2*kl + ku + 1`, but `anorm`
/// must come from the original — `norms.langb`, which uses the narrower
/// `kl + ku + 1` layout. The two arrays are not the same shape.
pub fn gbcon(
    comptime T: type,
    allocator: Allocator,
    norm: Norm,
    n: usize,
    kl: usize,
    ku: usize,
    ab: []const T,
    ldab: usize,
    ipiv: []const Int,
    anorm: Real(T),
) Fail!Real(T) {
    std.debug.assert(norm == .one or norm == .infinity);
    std.debug.assert(ldab >= 2 * kl + ku + 1);
    std.debug.assert(ipiv.len >= n);

    const scratch = try ConScratch(T).init(allocator, 3 * n, 2 * n, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const kl_ = dim(kl);
    const ku_ = dim(ku);
    const ldab_ = dim(ldab);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "gbcon")(opt(norm), ref(&n_), ref(&kl_), ref(&ku_), ab.ptr, ref(&ldab_), ipiv.ptr, ref(&anorm), out(&rcond), scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "gbcon")(opt(norm), ref(&n_), ref(&kl_), ref(&ku_), ab.ptr, ref(&ldab_), ipiv.ptr, ref(&anorm), out(&rcond), scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }

    try info_mod.checkArgs(info);
    return rcond;
}

/// `gecon` for a tridiagonal matrix factored by `gttrf`.
pub fn gtcon(
    comptime T: type,
    allocator: Allocator,
    norm: Norm,
    n: usize,
    dl: []const T,
    d: []const T,
    du: []const T,
    du2: []const T,
    ipiv: []const Int,
    anorm: Real(T),
) Fail!Real(T) {
    std.debug.assert(norm == .one or norm == .infinity);
    std.debug.assert(d.len >= n);
    std.debug.assert(ipiv.len >= n);

    // The complex routine takes no real workspace at all, hence the 0.
    const scratch = try ConScratch(T).init(allocator, 2 * n, 2 * n, switch (T) {
        Complex(f32), Complex(f64) => 0,
        else => n,
    });
    defer scratch.deinit();

    const n_ = dim(n);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "gtcon")(opt(norm), ref(&n_), dl.ptr, d.ptr, du.ptr, du2.ptr, ipiv.ptr, ref(&anorm), out(&rcond), scratch.work.ptr, out(&info)),
        else => sym(T, "gtcon")(opt(norm), ref(&n_), dl.ptr, d.ptr, du.ptr, du2.ptr, ipiv.ptr, ref(&anorm), out(&rcond), scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }

    try info_mod.checkArgs(info);
    return rcond;
}

/// `pocon` for a positive definite band matrix factored by `pbtrf`.
pub fn pbcon(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    kd: usize,
    ab: []const T,
    ldab: usize,
    anorm: Real(T),
) Fail!Real(T) {
    std.debug.assert(ldab >= kd + 1);

    const scratch = try ConScratch(T).init(allocator, 3 * n, 2 * n, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const kd_ = dim(kd);
    const ldab_ = dim(ldab);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "pbcon")(opt(uplo), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), ref(&anorm), out(&rcond), scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "pbcon")(opt(uplo), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), ref(&anorm), out(&rcond), scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }

    try info_mod.checkArgs(info);
    return rcond;
}

/// `pocon` in packed storage, from a `pptrf` factorization.
pub fn ppcon(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    ap: []const T,
    anorm: Real(T),
) Fail!Real(T) {
    std.debug.assert(ap.len >= packedLen(n));

    const scratch = try ConScratch(T).init(allocator, 3 * n, 2 * n, n);
    defer scratch.deinit();

    const n_ = dim(n);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "ppcon")(opt(uplo), ref(&n_), ap.ptr, ref(&anorm), out(&rcond), scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "ppcon")(opt(uplo), ref(&n_), ap.ptr, ref(&anorm), out(&rcond), scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }

    try info_mod.checkArgs(info);
    return rcond;
}

/// `pocon` for a positive definite tridiagonal matrix factored by `pttrf`.
///
/// This one takes no `norm` argument: the 1-norm and the infinity norm of a
/// symmetric matrix are the same, and it is the only estimator here that says
/// so in its signature.
pub fn ptcon(
    comptime T: type,
    allocator: Allocator,
    n: usize,
    d: []const Real(T),
    e: []const T,
    anorm: Real(T),
) Fail!Real(T) {
    std.debug.assert(d.len >= n);
    if (n > 1) std.debug.assert(e.len >= n - 1);

    // Both variants want exactly one n-element real workspace; the complex one
    // just spells it `rwork` and takes no complex scratch at all.
    const work = try allocator.alloc(Real(T), @max(n, 1));
    defer allocator.free(work);

    const n_ = dim(n);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    sym(T, "ptcon")(ref(&n_), d.ptr, e.ptr, ref(&anorm), out(&rcond), work.ptr, out(&info));

    try info_mod.checkArgs(info);
    return rcond;
}

/// `sycon` in packed storage, from an `sptrf` factorization.
pub fn spcon(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    ap: []const T,
    ipiv: []const Int,
    anorm: Real(T),
) Fail!Real(T) {
    return packedIndefiniteCondition(T, "spcon", allocator, uplo, n, ap, ipiv, anorm);
}

/// `hecon` in packed storage, from an `hptrf` factorization. Complex only.
pub fn hpcon(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    ap: []const T,
    ipiv: []const Int,
    anorm: Real(T),
) Fail!Real(T) {
    requireComplex(T, "hpcon", "spcon");
    return packedIndefiniteCondition(T, "hpcon", allocator, uplo, n, ap, ipiv, anorm);
}

fn packedIndefiniteCondition(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    ap: []const T,
    ipiv: []const Int,
    anorm: Real(T),
) Fail!Real(T) {
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(ipiv.len >= n);

    const scratch = try ConScratch(T).init(allocator, 2 * n, 2 * n, switch (T) {
        Complex(f32), Complex(f64) => 0,
        else => n,
    });
    defer scratch.deinit();

    const n_ = dim(n);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, name)(opt(uplo), ref(&n_), ap.ptr, ipiv.ptr, ref(&anorm), out(&rcond), scratch.work.ptr, out(&info)),
        else => sym(T, name)(opt(uplo), ref(&n_), ap.ptr, ipiv.ptr, ref(&anorm), out(&rcond), scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }

    try info_mod.checkArgs(info);
    return rcond;
}

/// `trcon` for a triangular band matrix.
///
/// Like `trcon`, this needs no `anorm` — a triangular matrix is its own factor,
/// so the routine has the original in hand.
pub fn tbcon(
    comptime T: type,
    allocator: Allocator,
    norm: Norm,
    uplo: Uplo,
    diag: Diag,
    n: usize,
    kd: usize,
    ab: []const T,
    ldab: usize,
) Fail!Real(T) {
    std.debug.assert(norm == .one or norm == .infinity);
    std.debug.assert(ldab >= kd + 1);

    const scratch = try ConScratch(T).init(allocator, 3 * n, 2 * n, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const kd_ = dim(kd);
    const ldab_ = dim(ldab);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "tbcon")(opt(norm), opt(uplo), opt(diag), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), out(&rcond), scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "tbcon")(opt(norm), opt(uplo), opt(diag), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), out(&rcond), scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }

    try info_mod.checkArgs(info);
    return rcond;
}

/// `trcon` in packed triangular storage.
pub fn tpcon(
    comptime T: type,
    allocator: Allocator,
    norm: Norm,
    uplo: Uplo,
    diag: Diag,
    n: usize,
    ap: []const T,
) Fail!Real(T) {
    std.debug.assert(norm == .one or norm == .infinity);
    std.debug.assert(ap.len >= packedLen(n));

    const scratch = try ConScratch(T).init(allocator, 3 * n, 2 * n, n);
    defer scratch.deinit();

    const n_ = dim(n);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "tpcon")(opt(norm), opt(uplo), opt(diag), ref(&n_), ap.ptr, out(&rcond), scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "tpcon")(opt(norm), opt(uplo), opt(diag), ref(&n_), ap.ptr, out(&rcond), scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }

    try info_mod.checkArgs(info);
    return rcond;
}

// ============================================================================
// Equilibration for the remaining storage forms
// ============================================================================

/// One set of scale factors, for a matrix that has only one — anything
/// symmetric, Hermitian or positive definite, where the same `S` is applied on
/// both sides as `S A S`.
pub const SymmetricEquilibration = struct {
    /// Ratio of smallest to largest scale factor. Close to 1 means scaling is
    /// not worth doing.
    cond: f64,
    /// Largest absolute element of the matrix, for detecting overflow risk.
    max_abs: f64,
};

/// `geequ` for a band matrix.
///
/// `ab` here is the *unfactored* band layout, `ldab >= kl + ku + 1` — narrower
/// than what `gbtrf` wants, since there is no fill-in to leave room for.
pub fn gbequ(
    comptime T: type,
    rows: usize,
    cols: usize,
    kl: usize,
    ku: usize,
    ab: []const T,
    ldab: usize,
    r: []Real(T),
    col_scale: []Real(T),
) Error!Equilibration {
    return bandEquilibrate(T, "gbequ", rows, cols, kl, ku, ab, ldab, r, col_scale);
}

/// `gbequ` with the scale factors rounded to a power of the radix.
///
/// Powers of two scale exactly, so `R A C` introduces no rounding error of its
/// own. The scaling is coarser and the resulting condition number slightly
/// worse; use this when you care that equilibration be reversible.
///
/// **`max_abs` means something different here.** The `*equ` routines report the
/// true largest element; the `*equb` ones report it after the same rounding the
/// scale factors get. Measured on a matrix whose largest entry is 100, `gbequ`
/// returns 100 and `gbequb` returns 64. Comparing the two against each other,
/// or against `norms.lange(.max_abs)`, is comparing different quantities.
pub fn gbequb(
    comptime T: type,
    rows: usize,
    cols: usize,
    kl: usize,
    ku: usize,
    ab: []const T,
    ldab: usize,
    r: []Real(T),
    col_scale: []Real(T),
) Error!Equilibration {
    return bandEquilibrate(T, "gbequb", rows, cols, kl, ku, ab, ldab, r, col_scale);
}

fn bandEquilibrate(
    comptime T: type,
    comptime name: []const u8,
    rows: usize,
    cols: usize,
    kl: usize,
    ku: usize,
    ab: []const T,
    ldab: usize,
    r: []Real(T),
    col_scale: []Real(T),
) Error!Equilibration {
    std.debug.assert(ldab >= kl + ku + 1);
    std.debug.assert(r.len >= rows);
    std.debug.assert(col_scale.len >= cols);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const kl_ = dim(kl);
    const ku_ = dim(ku);
    const ldab_ = dim(ldab);
    var rowcnd: Real(T) = 0;
    var colcnd: Real(T) = 0;
    var amax: Real(T) = 0;
    var info: Int = 0;

    sym(T, name)(ref(&m_), ref(&n_), ref(&kl_), ref(&ku_), ab.ptr, ref(&ldab_), r.ptr, col_scale.ptr, out(&rowcnd), out(&colcnd), out(&amax), out(&info));
    try info_mod.checkLu(info);
    return .{ .row_cond = rowcnd, .col_cond = colcnd, .max_abs = amax };
}

/// `geequ` with the scale factors rounded to a power of the radix. See `gbequb`
/// for why you would want that, and for the fact that `max_abs` is rounded too.
pub fn geequb(
    comptime T: type,
    rows: usize,
    cols: usize,
    a: []const T,
    lda: usize,
    r: []Real(T),
    col_scale: []Real(T),
) Error!Equilibration {
    assertMatrix(a.len, rows, cols, lda);
    std.debug.assert(r.len >= rows);
    std.debug.assert(col_scale.len >= cols);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(lda);
    var rowcnd: Real(T) = 0;
    var colcnd: Real(T) = 0;
    var amax: Real(T) = 0;
    var info: Int = 0;

    sym(T, "geequb")(ref(&m_), ref(&n_), a.ptr, ref(&lda_), r.ptr, col_scale.ptr, out(&rowcnd), out(&colcnd), out(&amax), out(&info));
    try info_mod.checkLu(info);
    return .{ .row_cond = rowcnd, .col_cond = colcnd, .max_abs = amax };
}

/// Scale factors `S` for a positive definite matrix, so that `S A S` has a unit
/// diagonal. `s[i]` is `1 / sqrt(a[i,i])`.
///
/// Returns `error.NotPositiveDefinite` if a diagonal entry is not positive;
/// `lastInfo()` gives its 1-based index. That is a genuine test — this is the
/// cheapest way to reject a matrix before attempting a Cholesky.
pub fn poequ(
    comptime T: type,
    n: usize,
    a: []const T,
    lda: usize,
    s: []Real(T),
) Error!SymmetricEquilibration {
    return fullPosEquilibrate(T, "poequ", n, a, lda, s);
}

/// `poequ` with the scale factors rounded to a power of the radix.
pub fn poequb(
    comptime T: type,
    n: usize,
    a: []const T,
    lda: usize,
    s: []Real(T),
) Error!SymmetricEquilibration {
    return fullPosEquilibrate(T, "poequb", n, a, lda, s);
}

fn fullPosEquilibrate(
    comptime T: type,
    comptime name: []const u8,
    n: usize,
    a: []const T,
    lda: usize,
    s: []Real(T),
) Error!SymmetricEquilibration {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(s.len >= n);

    const n_ = dim(n);
    const lda_ = dim(lda);
    var scond: Real(T) = 0;
    var amax: Real(T) = 0;
    var info: Int = 0;

    sym(T, name)(ref(&n_), a.ptr, ref(&lda_), s.ptr, out(&scond), out(&amax), out(&info));
    try info_mod.checkCholesky(info);
    return .{ .cond = scond, .max_abs = amax };
}

/// `poequ` for a positive definite band matrix.
pub fn pbequ(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    kd: usize,
    ab: []const T,
    ldab: usize,
    s: []Real(T),
) Error!SymmetricEquilibration {
    std.debug.assert(ldab >= kd + 1);
    std.debug.assert(s.len >= n);

    const n_ = dim(n);
    const kd_ = dim(kd);
    const ldab_ = dim(ldab);
    var scond: Real(T) = 0;
    var amax: Real(T) = 0;
    var info: Int = 0;

    sym(T, "pbequ")(opt(uplo), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), s.ptr, out(&scond), out(&amax), out(&info));
    try info_mod.checkCholesky(info);
    return .{ .cond = scond, .max_abs = amax };
}

/// `poequ` in packed storage.
pub fn ppequ(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    ap: []const T,
    s: []Real(T),
) Error!SymmetricEquilibration {
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(s.len >= n);

    const n_ = dim(n);
    var scond: Real(T) = 0;
    var amax: Real(T) = 0;
    var info: Int = 0;

    sym(T, "ppequ")(opt(uplo), ref(&n_), ap.ptr, s.ptr, out(&scond), out(&amax), out(&info));
    try info_mod.checkCholesky(info);
    return .{ .cond = scond, .max_abs = amax };
}

/// Scale factors for a symmetric *indefinite* matrix.
///
/// Unlike `poequ` this cannot just take the reciprocal square root of the
/// diagonal — the diagonal of an indefinite matrix can be zero or negative — so
/// it runs an iteration that minimises the condition number, which is why it
/// needs a workspace and the others do not.
pub fn syequb(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []const T,
    lda: usize,
    s: []Real(T),
) Fail!SymmetricEquilibration {
    return indefiniteEquilibrate(T, "syequb", allocator, uplo, n, a, lda, s);
}

/// `syequb` for a Hermitian matrix. Complex only.
pub fn heequb(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []const T,
    lda: usize,
    s: []Real(T),
) Fail!SymmetricEquilibration {
    requireComplex(T, "heequb", "syequb");
    return indefiniteEquilibrate(T, "heequb", allocator, uplo, n, a, lda, s);
}

fn indefiniteEquilibrate(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    a: []const T,
    lda: usize,
    s: []Real(T),
) Fail!SymmetricEquilibration {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(s.len >= n);

    // 3n reals or 2n complex; the workspace is `T`-typed either way here, which
    // is why this one does not go through ConScratch.
    const work = try allocator.alloc(T, @max(switch (T) {
        Complex(f32), Complex(f64) => 2 * n,
        else => 3 * n,
    }, 1));
    defer allocator.free(work);

    const n_ = dim(n);
    const lda_ = dim(lda);
    var scond: Real(T) = 0;
    var amax: Real(T) = 0;
    var info: Int = 0;

    sym(T, name)(opt(uplo), ref(&n_), a.ptr, ref(&lda_), s.ptr, out(&scond), out(&amax), work.ptr, out(&info));
    try info_mod.checkArgs(info);
    return .{ .cond = scond, .max_abs = amax };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const norms = @import("norms.zig");

fn residual(comptime T: type, n: usize, a: []const T, lda: usize, x: []const T, b: []const T) T {
    var worst: T = 0;
    for (0..n) |i| {
        var acc: T = 0;
        for (0..n) |j| acc += a[i + j * lda] * x[j];
        worst = @max(worst, @abs(acc - b[i]));
    }
    return worst;
}

test "getrf then getrs matches gesv" {
    const original = [_]f64{ 2, 1, 1, 1, 3, 0, 1, 2, 0 };
    var a = original;
    var ipiv: [3]Int = undefined;
    try getrf(f64, 3, 3, &a, 3, &ipiv);

    // The point of splitting: two right-hand sides solved against one
    // factorization, at O(n^2) each.
    var b1 = [_]f64{ 4, 5, 6 };
    try getrs(f64, .no_trans, 3, 1, &a, 3, &ipiv, &b1, 3);
    try testing.expect(residual(f64, 3, &original, 3, &b1, &.{ 4, 5, 6 }) < 1e-12);

    var b2 = [_]f64{ 1, 0, 0 };
    try getrs(f64, .no_trans, 3, 1, &a, 3, &ipiv, &b2, 3);
    try testing.expect(residual(f64, 3, &original, 3, &b2, &.{ 1, 0, 0 }) < 1e-12);
}

test "getrs solves the transposed system" {
    // The matrix has to be asymmetric for this to test anything: on a symmetric
    // one, .trans and .no_trans agree and the test would pass either way.
    var a = [_]f64{ 1, 3, 2, 4 }; // column-major [[1, 2], [3, 4]]
    var ipiv: [2]Int = undefined;
    try getrf(f64, 2, 2, &a, 2, &ipiv);

    var b = [_]f64{ 1, 2 };
    try getrs(f64, .trans, 2, 1, &a, 2, &ipiv, &b, 2);

    // A^T = [[1, 3], [2, 4]], which column-major is {1, 2, 3, 4}.
    const at = [_]f64{ 1, 2, 3, 4 };
    try testing.expect(residual(f64, 2, &at, 2, &b, &.{ 1, 2 }) < 1e-12);

    // And the untransposed solve of the same factorization gives a different
    // answer, confirming `trans` reached the routine at all.
    var b2 = [_]f64{ 1, 2 };
    try getrs(f64, .no_trans, 2, 1, &a, 2, &ipiv, &b2, 2);
    try testing.expect(@abs(b2[0] - b[0]) > 1e-6);
}

test "getrf reports rectangular factorizations too" {
    // 3x2: LU of a tall matrix is legal and useful.
    var a = [_]f64{ 1, 2, 3, 4, 5, 7 };
    var ipiv: [2]Int = undefined;
    try getrf(f64, 3, 2, &a, 3, &ipiv);
}

test "getri inverts, and the inverse multiplies back to the identity" {
    const original = [_]f64{ 4, 2, 7, 6 }; // [[4, 7], [2, 6]], det = 10
    var a = original;
    var ipiv: [2]Int = undefined;
    try getrf(f64, 2, 2, &a, 2, &ipiv);
    try getri(f64, testing.allocator, 2, &a, 2, &ipiv);

    // A^-1 = (1/10) [[6, -7], [-2, 4]]
    try testing.expectApproxEqAbs(@as(f64, 0.6), a[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, -0.2), a[1], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, -0.7), a[2], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.4), a[3], 1e-12);

    // And A * A^-1 = I, computed independently.
    for (0..2) |i| {
        for (0..2) |j| {
            var acc: f64 = 0;
            for (0..2) |k| acc += original[i + k * 2] * a[k + j * 2];
            const want: f64 = if (i == j) 1 else 0;
            try testing.expectApproxEqAbs(want, acc, 1e-12);
        }
    }
}

test "gecon separates a well-conditioned matrix from a nearly singular one" {
    var work: [2]f64 = undefined;

    // Identity: perfectly conditioned, rcond = 1.
    var good = [_]f64{ 1, 0, 0, 1 };
    const good_norm = norms.lange(f64, .one, 2, 2, &good, 2, &work);
    var ipiv: [2]Int = undefined;
    try getrf(f64, 2, 2, &good, 2, &ipiv);
    const good_rcond = try gecon(f64, testing.allocator, .one, 2, &good, 2, good_norm);
    try testing.expectApproxEqAbs(@as(f64, 1), good_rcond, 1e-12);

    // Nearly singular: [[1, 1], [1, 1 + 1e-10]].
    var bad = [_]f64{ 1, 1, 1, 1 + 1e-10 };
    const bad_norm = norms.lange(f64, .one, 2, 2, &bad, 2, &work);
    try getrf(f64, 2, 2, &bad, 2, &ipiv);
    const bad_rcond = try gecon(f64, testing.allocator, .one, 2, &bad, 2, bad_norm);
    try testing.expect(bad_rcond < 1e-9);
}

test "gecon uses the norm of the original matrix, not of the factor" {
    // The most common way to misuse this, and it produces no diagnostic at all.
    // Pinned as a characterization test: the two calls differ, and only the
    // first is right.
    var a = [_]f64{ 100, 1, 1, 100 };
    const original = a;
    var work: [2]f64 = undefined;
    const correct_norm = norms.lange(f64, .one, 2, 2, &original, 2, &work);

    var ipiv: [2]Int = undefined;
    try getrf(f64, 2, 2, &a, 2, &ipiv);
    const factor_norm = norms.lange(f64, .one, 2, 2, &a, 2, &work);

    const right = try gecon(f64, testing.allocator, .one, 2, &a, 2, correct_norm);
    const wrong = try gecon(f64, testing.allocator, .one, 2, &a, 2, factor_norm);

    try testing.expect(right != wrong);
    // The true rcond of [[100, 1], [1, 100]] is about 0.98.
    try testing.expect(right > 0.9);
}

test "geequ finds the scaling of a badly scaled matrix" {
    // Rows differing by six orders of magnitude.
    const a = [_]f64{ 1, 1e6, 1, 1e6 };
    var r: [2]f64 = undefined;
    var col: [2]f64 = undefined;

    const eq = try geequ(f64, 2, 2, &a, 2, &r, &col);

    try testing.expectApproxEqAbs(@as(f64, 1e6), eq.max_abs, 1);
    // Row 0 needs scaling up, row 1 down.
    try testing.expect(r[0] > r[1]);
}

test "geequ reports an exactly zero row" {
    const a = [_]f64{ 1, 0, 1, 0 }; // second row is zero
    var r: [2]f64 = undefined;
    var col: [2]f64 = undefined;

    try testing.expectError(error.SingularMatrix, geequ(f64, 2, 2, &a, 2, &r, &col));
    // info <= n means a row; > n would mean a column.
    try testing.expectEqual(@as(Int, 2), info_mod.lastInfo());
}

test "potrf produces a factor that multiplies back to the original" {
    // SPD [[4, 2], [2, 3]].
    const original = [_]f64{ 4, 2, 2, 3 };
    var a = original;
    try potrf(f64, .lower, 2, &a, 2);

    // Lower factor L, with the strict upper left as it was. L L^T = A.
    const l = [_]f64{ a[0], a[1], 0, a[3] };
    for (0..2) |i| {
        for (0..2) |j| {
            var acc: f64 = 0;
            for (0..2) |k| acc += l[i + k * 2] * l[j + k * 2];
            try testing.expectApproxEqAbs(original[i + j * 2], acc, 1e-12);
        }
    }
}

test "potri writes only the requested triangle" {
    var a = [_]f64{ 4, 2, -999, 3 };
    try potrf(f64, .lower, 2, &a, 2);
    try potri(f64, .lower, 2, &a, 2);

    // The inverse of a symmetric matrix is symmetric, so LAPACK fills in only
    // half and leaves the rest. Code treating `a` as a full matrix afterwards
    // reads the poison.
    try testing.expectEqual(@as(f64, -999), a[2]);
    // A^-1 for [[4, 2], [2, 3]] (det 8) is (1/8)[[3, -2], [-2, 4]].
    try testing.expectApproxEqAbs(@as(f64, 3.0 / 8.0), a[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, -2.0 / 8.0), a[1], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 4.0 / 8.0), a[3], 1e-12);
}

test "pocon on a well-conditioned SPD matrix" {
    var a = [_]f64{ 4, 0, 0, 4 };
    var work: [2]f64 = undefined;
    const anorm = norms.lansy(f64, .one, .upper, 2, &a, 2, &work);
    try potrf(f64, .upper, 2, &a, 2);

    const rcond = try pocon(f64, testing.allocator, .upper, 2, &a, 2, anorm);
    try testing.expectApproxEqAbs(@as(f64, 1), rcond, 1e-12);
}

test "packed Cholesky round-trips through the full form" {
    // Upper packed [[4, 2], [2, 3]] is a11, a12, a22.
    var ap = [_]f64{ 4, 2, 3 };
    try pptrf(f64, .upper, 2, &ap);

    var b = [_]f64{ 1, 1 };
    try pptrs(f64, .upper, 2, 1, &ap, &b, 2);

    const full = [_]f64{ 4, 2, 2, 3 };
    try testing.expect(residual(f64, 2, &full, 2, &b, &.{ 1, 1 }) < 1e-12);
}

test "pptri inverts in packed storage" {
    var ap = [_]f64{ 4, 2, 3 };
    try pptrf(f64, .upper, 2, &ap);
    try pptri(f64, .upper, 2, &ap);

    // (1/8)[[3, -2], [-2, 4]] packed upper: 3/8, -2/8, 4/8.
    try testing.expectApproxEqAbs(@as(f64, 3.0 / 8.0), ap[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, -0.25), ap[1], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.5), ap[2], 1e-12);
}

test "pbtrf and pbtrs on a band matrix" {
    // Tridiagonal SPD, kd = 1, upper band storage.
    var ab = [_]f64{ 0, 4, 1, 4, 1, 4 };
    try pbtrf(f64, .upper, 3, 1, &ab, 2);

    var b = [_]f64{ 1, 2, 3 };
    try pbtrs(f64, .upper, 3, 1, 1, &ab, 2, &b, 3);

    const full = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };
    try testing.expect(residual(f64, 3, &full, 3, &b, &.{ 1, 2, 3 }) < 1e-12);
}

test "pttrf and pttrs keep the factorization for reuse" {
    var d = [_]f64{ 4, 4, 4 };
    var e = [_]f64{ 1, 1 };
    try pttrf(f64, 3, &d, &e);

    const full = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };
    var b1 = [_]f64{ 1, 2, 3 };
    try pttrs(f64, .lower, 3, 1, &d, &e, &b1, 3);
    try testing.expect(residual(f64, 3, &full, 3, &b1, &.{ 1, 2, 3 }) < 1e-12);

    // Second solve against the same factors.
    var b2 = [_]f64{ 1, 0, 0 };
    try pttrs(f64, .lower, 3, 1, &d, &e, &b2, 3);
    try testing.expect(residual(f64, 3, &full, 3, &b2, &.{ 1, 0, 0 }) < 1e-12);
}

test "pstrf detects rank deficiency instead of failing" {
    // Rank 1: [[1, 1], [1, 1]] is positive semidefinite, not definite. potrf
    // rejects it; pstrf reports rank 1 and succeeds.
    var reject = [_]f64{ 1, 1, 1, 1 };
    try testing.expectError(error.NotPositiveDefinite, potrf(f64, .upper, 2, &reject, 2));

    var a = [_]f64{ 1, 1, 1, 1 };
    var piv: [2]Int = undefined;
    const rank = try pstrf(f64, testing.allocator, .upper, 2, &a, 2, &piv, -1);
    try testing.expectEqual(@as(usize, 1), rank);
}

test "sytrf pivots differ from getrf pivots" {
    // Both are []Int of length n and both are 1-based, which is exactly why
    // this is worth pinning: sytrf can emit a negative entry marking a 2x2
    // block, and getrf never does.
    var a = [_]f64{ 0, 1, 1, 0 }; // symmetric, indefinite, needs a 2x2 pivot
    var ipiv: [2]Int = undefined;
    try sytrf(f64, testing.allocator, .upper, 2, &a, 2, &ipiv);

    try testing.expect(ipiv[0] < 0);
}

test "sytrf then sytrs solves an indefinite system" {
    const full = [_]f64{ 1, 2, 2, 1 };
    var a = full;
    var ipiv: [2]Int = undefined;
    try sytrf(f64, testing.allocator, .upper, 2, &a, 2, &ipiv);

    var b = [_]f64{ 1, 1 };
    try sytrs(f64, .upper, 2, 1, &a, 2, &ipiv, &b, 2);
    try testing.expect(residual(f64, 2, &full, 2, &b, &.{ 1, 1 }) < 1e-12);
}

test "sytri inverts an indefinite matrix" {
    var a = [_]f64{ 1, 2, 2, 1 };
    var ipiv: [2]Int = undefined;
    try sytrf(f64, testing.allocator, .upper, 2, &a, 2, &ipiv);
    try sytri(f64, testing.allocator, .upper, 2, &a, 2, &ipiv);

    // [[1, 2], [2, 1]] has det -3, inverse (1/-3)[[1, -2], [-2, 1]].
    try testing.expectApproxEqAbs(@as(f64, -1.0 / 3.0), a[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2.0 / 3.0), a[2], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, -1.0 / 3.0), a[3], 1e-12);
}

test "sycon estimates the condition of an indefinite matrix" {
    var a = [_]f64{ 1, 2, 2, 1 };
    var work: [2]f64 = undefined;
    const anorm = norms.lansy(f64, .one, .upper, 2, &a, 2, &work);
    var ipiv: [2]Int = undefined;
    try sytrf(f64, testing.allocator, .upper, 2, &a, 2, &ipiv);

    const rcond = try sycon(f64, testing.allocator, .upper, 2, &a, 2, &ipiv, anorm);
    // ||A||_1 = 3, ||A^-1||_1 = 1, so rcond = 1/3.
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 3.0), rcond, 1e-9);
}

test "hecon takes no rwork where gecon does" {
    // The complex hecon/sycon are the exception to the real-vs-complex
    // workspace pattern: they have no rwork parameter at all. If this wrapper
    // passed one, the argument after it would land in `info`.
    const Z = Complex(f64);
    var a = [_]Z{ Z.init(2, 0), Z.init(0, -1), Z.init(0, 0), Z.init(2, 0) };
    var work: [2]f64 = undefined;
    const anorm = norms.lanhe(Z, .one, .lower, 2, &a, 2, &work);
    var ipiv: [2]Int = undefined;
    try hetrf(Z, testing.allocator, .lower, 2, &a, 2, &ipiv);

    const rcond = try hecon(Z, testing.allocator, .lower, 2, &a, 2, &ipiv, anorm);
    // A = [[2, i], [-i, 2]] has eigenvalues 1 and 3, ||A||_1 = 3,
    // ||A^-1||_1 = 1, so rcond = 1/3.
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 3.0), rcond, 1e-9);
}

test "hetrf then hetrs solves the Hermitian system" {
    const Z = Complex(f64);
    var a = [_]Z{ Z.init(2, 0), Z.init(0, -1), Z.init(0, 0), Z.init(2, 0) };
    var ipiv: [2]Int = undefined;
    try hetrf(Z, testing.allocator, .lower, 2, &a, 2, &ipiv);

    var b = [_]Z{ Z.init(1, 0), Z.init(0, 0) };
    try hetrs(Z, .lower, 2, 1, &a, 2, &ipiv, &b, 2);

    // x = [2/3, i/3], as in the linear.zig hesv test.
    try testing.expectApproxEqAbs(@as(f64, 2.0 / 3.0), b[0].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 3.0), b[1].im, 1e-12);
}

test "packed indefinite factor, solve and invert" {
    var ap = [_]f64{ 1, 2, 1 }; // upper packed [[1, 2], [2, 1]]
    var ipiv: [2]Int = undefined;
    try sptrf(f64, .upper, 2, &ap, &ipiv);

    var b = [_]f64{ 1, 1 };
    try sptrs(f64, .upper, 2, 1, &ap, &ipiv, &b, 2);
    const full = [_]f64{ 1, 2, 2, 1 };
    try testing.expect(residual(f64, 2, &full, 2, &b, &.{ 1, 1 }) < 1e-12);

    try sptri(f64, testing.allocator, .upper, 2, &ap, &ipiv);
    try testing.expectApproxEqAbs(@as(f64, -1.0 / 3.0), ap[0], 1e-12);
}

test "hptrf and hptri in packed Hermitian storage" {
    const Z = Complex(f64);
    var ap = [_]Z{ Z.init(2, 0), Z.init(0, -1), Z.init(2, 0) };
    var ipiv: [2]Int = undefined;
    try hptrf(Z, .lower, 2, &ap, &ipiv);
    try hptri(Z, testing.allocator, .lower, 2, &ap, &ipiv);

    // A^-1 = (1/3)[[2, -i], [i, 2]]; lower packed keeps a11, a21, a22.
    try testing.expectApproxEqAbs(@as(f64, 2.0 / 3.0), ap[0].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2.0 / 3.0), ap[2].re, 1e-12);
}

test "gbtrf then gbtrs on a band matrix" {
    const kl = 1;
    const ku = 1;
    const ldab = 2 * kl + ku + 1;
    var ab = [_]f64{0} ** (ldab * 3);
    const full = [_]f64{ 2, 1, 0, 1, 2, 1, 0, 1, 2 };
    for (0..3) |j| {
        for (0..3) |i| {
            if (i + kl < j or j + ku < i) continue;
            ab[kl + ku + i - j + j * ldab] = full[i + j * 3];
        }
    }
    var ipiv: [3]Int = undefined;
    try gbtrf(f64, 3, 3, kl, ku, &ab, ldab, &ipiv);

    var b = [_]f64{ 1, 2, 3 };
    try gbtrs(f64, .no_trans, 3, kl, ku, 1, &ab, ldab, &ipiv, &b, 3);
    try testing.expect(residual(f64, 3, &full, 3, &b, &.{ 1, 2, 3 }) < 1e-12);
}

test "gttrf keeps the second superdiagonal that gtsv discards" {
    var dl = [_]f64{ 1, 1 };
    var d = [_]f64{ 4, 4, 4 };
    var du = [_]f64{ 1, 1 };
    var du2 = [_]f64{0};
    var ipiv: [3]Int = undefined;
    try gttrf(f64, 3, &dl, &d, &du, &du2, &ipiv);

    const full = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };
    var b1 = [_]f64{ 1, 2, 3 };
    try gttrs(f64, .no_trans, 3, 1, &dl, &d, &du, &du2, &ipiv, &b1, 3);
    try testing.expect(residual(f64, 3, &full, 3, &b1, &.{ 1, 2, 3 }) < 1e-12);

    // Reuse - the thing gtsv cannot do.
    var b2 = [_]f64{ 0, 1, 0 };
    try gttrs(f64, .no_trans, 3, 1, &dl, &d, &du, &du2, &ipiv, &b2, 3);
    try testing.expect(residual(f64, 3, &full, 3, &b2, &.{ 0, 1, 0 }) < 1e-12);
}

test "trtrs solves without any factorization step" {
    // Upper triangular [[2, 1], [0, 3]].
    const a = [_]f64{ 2, 0, 1, 3 };
    var b = [_]f64{ 5, 3 };
    try trtrs(f64, .upper, .no_trans, .non_unit, 2, 1, &a, 2, &b, 2);

    // x2 = 1, then 2*x1 + 1 = 5 -> x1 = 2.
    try testing.expectApproxEqAbs(@as(f64, 2), b[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1), b[1], 1e-12);
}

test "trtrs reports a zero diagonal where trsm would not" {
    const a = [_]f64{ 2, 0, 1, 0 }; // second diagonal element is zero
    var b = [_]f64{ 1, 1 };
    try testing.expectError(error.SingularMatrix, trtrs(f64, .upper, .no_trans, .non_unit, 2, 1, &a, 2, &b, 2));
    try testing.expectEqual(@as(Int, 2), info_mod.lastInfo());
}

test "trtri inverts a triangular matrix in place" {
    var a = [_]f64{ 2, 0, 1, 4 }; // [[2, 1], [0, 4]]
    try trtri(f64, .upper, .non_unit, 2, &a, 2);

    // Inverse is [[1/2, -1/8], [0, 1/4]].
    try testing.expectApproxEqAbs(@as(f64, 0.5), a[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, -0.125), a[2], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.25), a[3], 1e-12);
}

test "trtri with a unit diagonal ignores what is stored there" {
    var a = [_]f64{ 7, 0, 2, 9 };
    try trtri(f64, .upper, .unit, 2, &a, 2);

    // The diagonal is left exactly as it was - LAPACK neither reads nor writes
    // it when diag is .unit.
    try testing.expectEqual(@as(f64, 7), a[0]);
    try testing.expectEqual(@as(f64, 9), a[3]);
    // The off-diagonal is inverted as if the diagonal were 1: -2.
    try testing.expectApproxEqAbs(@as(f64, -2), a[2], 1e-12);
}

test "trcon needs no anorm because it has the matrix itself" {
    const a = [_]f64{ 1, 0, 0, 1 };
    const rcond = try trcon(f64, testing.allocator, .one, .upper, .non_unit, 2, &a, 2);
    try testing.expectApproxEqAbs(@as(f64, 1), rcond, 1e-12);

    // [[1, 0], [0, 1e-8]] is badly conditioned.
    const bad = [_]f64{ 1, 0, 0, 1e-8 };
    const bad_rcond = try trcon(f64, testing.allocator, .one, .upper, .non_unit, 2, &bad, 2);
    try testing.expect(bad_rcond < 1e-7);
}

test "tptrs and tptri in packed triangular storage" {
    // Upper packed [[2, 1], [0, 3]] is a11, a12, a22.
    const ap = [_]f64{ 2, 1, 3 };
    var b = [_]f64{ 5, 3 };
    try tptrs(f64, .upper, .no_trans, .non_unit, 2, 1, &ap, &b, 2);
    try testing.expectApproxEqAbs(@as(f64, 2), b[0], 1e-12);

    var inv = ap;
    try tptri(f64, .upper, .non_unit, 2, &inv);
    try testing.expectApproxEqAbs(@as(f64, 0.5), inv[0], 1e-12);
}

test "tbtrs solves a triangular band system" {
    // Upper bidiagonal [[2, 1, 0], [0, 2, 1], [0, 0, 2]], kd = 1.
    var ab = [_]f64{ 0, 2, 1, 2, 1, 2 };
    var b = [_]f64{ 1, 1, 2 };
    try tbtrs(f64, .upper, .no_trans, .non_unit, 3, 1, 1, &ab, 2, &b, 3);

    const full = [_]f64{ 2, 0, 0, 1, 2, 0, 0, 1, 2 };
    try testing.expect(residual(f64, 3, &full, 3, &b, &.{ 1, 1, 2 }) < 1e-12);
}

test "trttp and tpttr are inverses" {
    const a = [_]f64{ 1, -999, 2, 3 }; // upper [[1, 2], [0(unused), 3]]
    var ap: [3]f64 = undefined;
    try trttp(f64, .upper, 2, &a, 2, &ap);
    try testing.expectEqualSlices(f64, &.{ 1, 2, 3 }, &ap);

    var back = [_]f64{ -1, -1, -1, -1 };
    try tpttr(f64, .upper, 2, &ap, &back, 2);
    try testing.expectEqual(@as(f64, 1), back[0]);
    try testing.expectEqual(@as(f64, 2), back[2]);
    try testing.expectEqual(@as(f64, 3), back[3]);
    // The unreferenced triangle is not written.
    try testing.expectEqual(@as(f64, -1), back[1]);
}

test "the condition estimators write nothing past their workspaces" {
    // Pins the workspace sizes this module allocates. They differ per routine
    // and per real/complex, they are not queryable, and getting one too small
    // is a heap overflow rather than an error - so this checks the real gecon
    // path against a deliberately over-allocated buffer.
    const n = 4;
    var a = [_]f64{0} ** (n * n);
    for (0..n) |i| a[i + i * n] = @floatFromInt(i + 1);
    var nwork: [n]f64 = undefined;
    const anorm = norms.lange(f64, .one, n, n, &a, n, &nwork);
    var ipiv: [n]Int = undefined;
    try getrf(f64, n, n, &a, n, &ipiv);

    // Mirror gecon's real branch by hand, with poison past the documented ends.
    var work = [_]f64{-999} ** (4 * n + 4);
    var iwork = [_]Int{-999} ** (n + 4);
    var rcond: f64 = 0;
    var info: Int = 0;
    const n_ = dim(n);
    c.dgecon(opt(Norm.one), ref(&n_), &a, ref(&n_), ref(&anorm), out(&rcond), &work, &iwork, out(&info));
    try info_mod.checkArgs(info);

    for (work[4 * n ..]) |slot| try testing.expectEqual(@as(f64, -999), slot);
    for (iwork[n..]) |slot| try testing.expectEqual(@as(Int, -999), slot);
    // rcond of diag(1, 2, 3, 4) in the 1-norm is (1/4) / 1 = 0.25.
    try testing.expectApproxEqAbs(@as(f64, 0.25), rcond, 1e-9);
}

test "the complex condition estimators also stay inside their workspaces" {
    // The complex branches use different sizes from the real ones (2n complex
    // work plus 2n real rwork for gecon, against 4n and n), and those numbers
    // come from the reference documentation rather than from anything the
    // header states. Poisoning past the documented ends is the only way to
    // check them without reading LAPACK's source.
    const Z = Complex(f64);
    const n = 4;
    var a = [_]Z{Z.zero} ** (n * n);
    for (0..n) |i| a[i + i * n] = Z.init(@floatFromInt(i + 1), 0);
    var nwork: [n]f64 = undefined;
    const anorm = norms.lange(Z, .one, n, n, &a, n, &nwork);
    var ipiv: [n]Int = undefined;
    try getrf(Z, n, n, &a, n, &ipiv);

    var work = [_]Z{Z.init(-999, -999)} ** (2 * n + 4);
    var rwork = [_]f64{-999} ** (2 * n + 4);
    var rcond: f64 = 0;
    var info: Int = 0;
    const n_ = dim(n);
    c.zgecon(opt(Norm.one), ref(&n_), &a, ref(&n_), ref(&anorm), out(&rcond), &work, &rwork, out(&info));
    try info_mod.checkArgs(info);

    for (work[2 * n ..]) |slot| try testing.expectEqual(@as(f64, -999), slot.re);
    for (rwork[2 * n ..]) |slot| try testing.expectEqual(@as(f64, -999), slot);
    try testing.expectApproxEqAbs(@as(f64, 0.25), rcond, 1e-9);
}

// ============================================================================
// Tests: condition estimators for the other storage forms
// ============================================================================

/// The 3x3 tridiagonal `tridiag(1, 4, 1)` in dense column-major form. Every
/// band and packed test below uses this same matrix, so their `rcond` estimates
/// can be checked against a dense `gecon` on it.
const tri3 = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };

/// `gecon` on a dense copy of `tri3`, the reference every band estimator below
/// is compared against.
fn denseRcond(norm: Norm) !f64 {
    var a = tri3;
    var nwork = [_]f64{ 0, 0, 0 };
    const anorm = norms.lange(f64, norm, 3, 3, &a, 3, &nwork);
    var ipiv: [3]Int = undefined;
    try getrf(f64, 3, 3, &a, 3, &ipiv);
    return gecon(f64, testing.allocator, norm, 3, &a, 3, anorm);
}

/// Packs `tri3` into the `gbtrf` band layout, which leaves `kl` rows of
/// headroom above the band for fill-in.
fn packBandForFactor(ab: []f64, ldab: usize, kl: usize, ku: usize) void {
    @memset(ab, 0);
    for (0..3) |j| {
        for (0..3) |i| {
            if (i + kl < j or j + ku < i) continue;
            ab[kl + ku + i - j + j * ldab] = tri3[i + j * 3];
        }
    }
}

test "gbcon agrees with a dense gecon on the same matrix" {
    const kl = 1;
    const ku = 1;
    const ldab = 2 * kl + ku + 1;
    var ab = [_]f64{0} ** (ldab * 3);
    packBandForFactor(&ab, ldab, kl, ku);

    // anorm comes from the *unfactored* band, in the narrower langb layout.
    var narrow = [_]f64{0} ** ((kl + ku + 1) * 3);
    for (0..3) |j| for (0..3) |i| {
        if (i + kl < j or j + ku < i) continue;
        narrow[ku + i - j + j * (kl + ku + 1)] = tri3[i + j * 3];
    };
    var nwork = [_]f64{};
    const anorm = norms.langb(f64, .one, 3, kl, ku, &narrow, kl + ku + 1, &nwork);

    var ipiv: [3]Int = undefined;
    try gbtrf(f64, 3, 3, kl, ku, &ab, ldab, &ipiv);
    const rcond = try gbcon(f64, testing.allocator, .one, 3, kl, ku, &ab, ldab, &ipiv, anorm);

    try testing.expectApproxEqRel(try denseRcond(.one), rcond, 1e-10);
}

test "gtcon agrees with a dense gecon on the same matrix" {
    var dl = [_]f64{ 1, 1 };
    var d = [_]f64{ 4, 4, 4 };
    var du = [_]f64{ 1, 1 };
    var du2 = [_]f64{0};
    const anorm = norms.lanst(f64, .one, 3, &d, &dl);

    var ipiv: [3]Int = undefined;
    try gttrf(f64, 3, &dl, &d, &du, &du2, &ipiv);
    const rcond = try gtcon(f64, testing.allocator, .one, 3, &dl, &d, &du, &du2, &ipiv, anorm);

    try testing.expectApproxEqRel(try denseRcond(.one), rcond, 1e-10);
}

test "pbcon and ppcon agree with a dense pocon on the same matrix" {
    var nwork = [_]f64{ 0, 0, 0 };
    const anorm = norms.lansy(f64, .one, .upper, 3, &tri3, 3, &nwork);

    var ab = [_]f64{ 0, 4, 1, 4, 1, 4 }; // upper band, kd = 1
    try pbtrf(f64, .upper, 3, 1, &ab, 2);
    const band = try pbcon(f64, testing.allocator, .upper, 3, 1, &ab, 2, anorm);

    var ap = [_]f64{ 4, 1, 4, 0, 1, 4 }; // upper packed
    try pptrf(f64, .upper, 3, &ap);
    const packed_ = try ppcon(f64, testing.allocator, .upper, 3, &ap, anorm);

    var dense = tri3;
    try potrf(f64, .upper, 3, &dense, 3);
    const full = try pocon(f64, testing.allocator, .upper, 3, &dense, 3, anorm);

    try testing.expectApproxEqRel(full, band, 1e-10);
    try testing.expectApproxEqRel(full, packed_, 1e-10);
}

test "ptcon takes no norm argument because the two norms coincide" {
    var d = [_]f64{ 4, 4, 4 };
    var e = [_]f64{ 1, 1 };
    const anorm = norms.lanst(f64, .one, 3, &d, &e);
    // Symmetric, so the infinity norm is the same number.
    try testing.expectEqual(anorm, norms.lanst(f64, .infinity, 3, &d, &e));

    try pttrf(f64, 3, &d, &e);
    const rcond = try ptcon(f64, testing.allocator, 3, &d, &e, anorm);
    try testing.expectApproxEqRel(try denseRcond(.one), rcond, 1e-10);
}

test "spcon agrees with sycon on the same indefinite matrix" {
    const dense_a = [_]f64{ 1, 2, 0, 2, 1, 2, 0, 2, 1 };
    var nwork = [_]f64{ 0, 0, 0 };
    const anorm = norms.lansy(f64, .one, .upper, 3, &dense_a, 3, &nwork);

    var ap = [_]f64{ 1, 2, 1, 0, 2, 1 };
    var ipiv_p: [3]Int = undefined;
    try sptrf(f64, .upper, 3, &ap, &ipiv_p);
    const packed_ = try spcon(f64, testing.allocator, .upper, 3, &ap, &ipiv_p, anorm);

    var full = dense_a;
    var ipiv_f: [3]Int = undefined;
    try sytrf(f64, testing.allocator, .upper, 3, &full, 3, &ipiv_f);
    const dense = try sycon(f64, testing.allocator, .upper, 3, &full, 3, &ipiv_f, anorm);

    try testing.expectApproxEqRel(dense, packed_, 1e-10);
}

test "hpcon takes no rwork, matching hecon's packed shape" {
    const Z = Complex(f64);
    const one = Z.init(1, 0);
    const two_i = Z.init(0, 2);
    // Hermitian [[1, 2i], [-2i, 1]] in upper packed storage.
    var ap = [_]Z{ one, two_i, one };
    var nwork = [_]f64{ 0, 0 };
    const anorm = norms.lanhp(Z, .one, .upper, 2, &ap, &nwork);

    var ipiv: [2]Int = undefined;
    try hptrf(Z, .upper, 2, &ap, &ipiv);
    const rcond = try hpcon(Z, testing.allocator, .upper, 2, &ap, &ipiv, anorm);

    // Eigenvalues are 1 +/- 2, so the true rcond in the 1-norm is 1/(3*1) here:
    // ||A||_1 = 3 and ||A^-1||_1 = 1/3 * ... the estimate is what we pin.
    try testing.expect(rcond > 0.1 and rcond <= 1.0);
}

test "tbcon and tpcon agree with trcon, and need no anorm" {
    // Upper triangular [[1, 2, 0], [0, 3, 4], [0, 0, 5]], column-major.
    const dense_t = [_]f64{ 1, 0, 0, 2, 3, 0, 0, 4, 5 };
    const full = try trcon(f64, testing.allocator, .one, .upper, .non_unit, 3, &dense_t, 3);

    // Band form with kd = 1: row kd + i - j.
    var ab = [_]f64{ 0, 1, 2, 3, 4, 5 };
    const band = try tbcon(f64, testing.allocator, .one, .upper, .non_unit, 3, 1, &ab, 2);

    var ap = [_]f64{ 1, 2, 3, 0, 4, 5 };
    const packed_ = try tpcon(f64, testing.allocator, .one, .upper, .non_unit, 3, &ap);

    try testing.expectApproxEqRel(full, band, 1e-10);
    try testing.expectApproxEqRel(full, packed_, 1e-10);
}

// ============================================================================
// Tests: equilibration
// ============================================================================

test "gbequ finds the same scaling as geequ on the same matrix" {
    const kl = 1;
    const ku = 1;
    const ld = kl + ku + 1;
    const badly_scaled = [_]f64{ 1e6, 1, 0, 1e6, 1, 0, 0, 1, 1 };
    var ab = [_]f64{0} ** (ld * 3);
    for (0..3) |j| for (0..3) |i| {
        if (i + kl < j or j + ku < i) continue;
        ab[ku + i - j + j * ld] = badly_scaled[i + j * 3];
    };

    var r_band: [3]f64 = undefined;
    var c_band: [3]f64 = undefined;
    const band = try gbequ(f64, 3, 3, kl, ku, &ab, ld, &r_band, &c_band);

    var r_full: [3]f64 = undefined;
    var c_full: [3]f64 = undefined;
    const full = try geequ(f64, 3, 3, &badly_scaled, 3, &r_full, &c_full);

    try testing.expectApproxEqRel(full.max_abs, band.max_abs, 1e-12);
    for (r_full, r_band) |a, b| try testing.expectApproxEqRel(a, b, 1e-12);
    for (c_full, c_band) |a, b| try testing.expectApproxEqRel(a, b, 1e-12);
}

test "the b variants round the scale factors to exact powers of two" {
    const a = [_]f64{ 3, 0, 0, 0, 7, 0, 0, 0, 100 };
    var r: [3]f64 = undefined;
    var col: [3]f64 = undefined;
    _ = try geequb(f64, 3, 3, &a, 3, &r, &col);

    // Every factor is 2^k exactly, so scaling introduces no rounding of its own.
    for (r) |v| try testing.expectEqual(@as(f64, 0.5), std.math.frexp(v).significand);
    // geequ, by contrast, uses the reciprocals themselves.
    var r_plain: [3]f64 = undefined;
    _ = try geequ(f64, 3, 3, &a, 3, &r_plain, &col);
    try testing.expectApproxEqRel(@as(f64, 1.0 / 3.0), r_plain[0], 1e-15);
    try testing.expect(r[0] != r_plain[0]);
}

test "poequ takes the reciprocal square root of the diagonal" {
    const a = [_]f64{ 4, 1, 1, 1, 9, 1, 1, 1, 16 }; // SPD, diagonal 4, 9, 16
    var s: [3]f64 = undefined;
    const e = try poequ(f64, 3, &a, 3, &s);

    try testing.expectApproxEqRel(@as(f64, 0.5), s[0], 1e-15);
    try testing.expectApproxEqRel(@as(f64, 1.0 / 3.0), s[1], 1e-15);
    try testing.expectApproxEqRel(@as(f64, 0.25), s[2], 1e-15);
    try testing.expectApproxEqRel(@as(f64, 16), e.max_abs, 1e-15);
    // cond is min(s) / max(s).
    try testing.expectApproxEqRel(@as(f64, 0.5), e.cond, 1e-15);
}

test "poequ rejects a non-positive diagonal, which poequb also does" {
    const a = [_]f64{ 4, 0, 0, -1 };
    var s: [2]f64 = undefined;
    try testing.expectError(error.NotPositiveDefinite, poequ(f64, 2, &a, 2, &s));
    try testing.expectEqual(@as(Int, 2), info_mod.lastInfo());
    try testing.expectError(error.NotPositiveDefinite, poequb(f64, 2, &a, 2, &s));
}

test "pbequ and ppequ match poequ on the same matrix" {
    var s_full: [3]f64 = undefined;
    const full = try poequ(f64, 3, &tri3, 3, &s_full);

    var ab = [_]f64{ 0, 4, 1, 4, 1, 4 };
    var s_band: [3]f64 = undefined;
    const band = try pbequ(f64, .upper, 3, 1, &ab, 2, &s_band);

    var ap = [_]f64{ 4, 1, 4, 0, 1, 4 };
    var s_packed: [3]f64 = undefined;
    const packed_ = try ppequ(f64, .upper, 3, &ap, &s_packed);

    for (s_full, s_band, s_packed) |a, b, cc| {
        try testing.expectApproxEqRel(a, b, 1e-15);
        try testing.expectApproxEqRel(a, cc, 1e-15);
    }
    try testing.expectApproxEqRel(full.cond, band.cond, 1e-15);
    try testing.expectApproxEqRel(full.cond, packed_.cond, 1e-15);
}

test "syequb scales a matrix whose diagonal poequ could not use" {
    // Indefinite: the diagonal has a zero, so poequ's 1/sqrt(a[i,i]) is undefined.
    const a = [_]f64{ 0, 2, 3, 2, 5, 1, 3, 1, 0 };
    var s: [3]f64 = undefined;
    const e = try syequb(f64, testing.allocator, .upper, 3, &a, 3, &s);

    for (s) |v| try testing.expect(v > 0 and std.math.isFinite(v));
    try testing.expect(e.cond > 0 and e.cond <= 1);
    try testing.expectApproxEqRel(@as(f64, 5), e.max_abs, 1e-15);
}

test "heequb wants 2n complex scratch where syequb wants 3n real" {
    const Z = Complex(f64);
    const a = [_]Z{
        Z.init(2, 0), Z.init(0, -1),
        Z.init(0, 1), Z.init(3, 0),
    };
    var s: [2]f64 = undefined;
    const e = try heequb(Z, testing.allocator, .upper, 2, &a, 2, &s);
    for (s) |v| try testing.expect(v > 0 and std.math.isFinite(v));
    try testing.expect(e.cond > 0 and e.cond <= 1);
}

// ============================================================================
// Tests: the caller-supplied-workspace variants
// ============================================================================

test "getriWorkspaceSize and getriWithWorkspace match getri" {
    const n = 3;
    const a0 = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };

    var a_alloc = a0;
    var ipiv_alloc: [n]Int = undefined;
    try getrf(f64, n, n, &a_alloc, n, &ipiv_alloc);
    try getri(f64, testing.allocator, n, &a_alloc, n, &ipiv_alloc);

    const size = try getriWorkspaceSize(f64, n, n);
    try testing.expect(size >= n);
    const work = try testing.allocator.alloc(f64, size);
    defer testing.allocator.free(work);

    var a_manual = a0;
    var ipiv_manual: [n]Int = undefined;
    try getrf(f64, n, n, &a_manual, n, &ipiv_manual);
    try getriWithWorkspace(f64, n, &a_manual, n, &ipiv_manual, work);

    try testing.expectEqualSlices(f64, &a_alloc, &a_manual);
}

test "sytrfWorkspaceSize and sytrfWithWorkspace match sytrf" {
    const n = 3;
    const a0 = [_]f64{ 1, 2, 0, 2, 1, 2, 0, 2, 1 };

    var a_alloc = a0;
    var ipiv_alloc: [n]Int = undefined;
    try sytrf(f64, testing.allocator, .upper, n, &a_alloc, n, &ipiv_alloc);

    const size = try sytrfWorkspaceSize(f64, .upper, n, n);
    try testing.expect(size >= n);
    const work = try testing.allocator.alloc(f64, size);
    defer testing.allocator.free(work);

    var a_manual = a0;
    var ipiv_manual: [n]Int = undefined;
    try sytrfWithWorkspace(f64, .upper, n, &a_manual, n, &ipiv_manual, work);

    try testing.expectEqualSlices(f64, &a_alloc, &a_manual);
    try testing.expectEqualSlices(Int, &ipiv_alloc, &ipiv_manual);
}

test "hetrfWorkspaceSize and hetrfWithWorkspace match hetrf" {
    const Z = Complex(f64);
    const n = 2;
    const a0 = [_]Z{ Z.init(2, 0), Z.init(0, -1), Z.init(0, 1), Z.init(2, 0) };

    var a_alloc = a0;
    var ipiv_alloc: [n]Int = undefined;
    try hetrf(Z, testing.allocator, .upper, n, &a_alloc, n, &ipiv_alloc);

    const size = try hetrfWorkspaceSize(Z, .upper, n, n);
    const work = try testing.allocator.alloc(Z, size);
    defer testing.allocator.free(work);

    var a_manual = a0;
    var ipiv_manual: [n]Int = undefined;
    try hetrfWithWorkspace(Z, .upper, n, &a_manual, n, &ipiv_manual, work);

    for (a_alloc, a_manual) |x, y| {
        try testing.expectEqual(x.re, y.re);
        try testing.expectEqual(x.im, y.im);
    }
}

test "hetri inverts a Hermitian matrix where sytri would treat it as symmetric" {
    const Z = Complex(f64);
    const n = 2;
    // [[2, i], [-i, 2]]: Hermitian, eigenvalues 1 and 3, so it is invertible.
    const original = [_]Z{ Z.init(2, 0), Z.init(0, -1), Z.init(0, 1), Z.init(2, 0) };
    var a = original;
    var ipiv: [n]Int = undefined;
    try hetrf(Z, testing.allocator, .upper, n, &a, n, &ipiv);
    try hetri(Z, testing.allocator, .upper, n, &a, n, &ipiv);

    // A A^-1 = I, reading the inverse's lower half by conjugate symmetry.
    for (0..n) |j| {
        for (0..n) |i| {
            var acc = Z.init(0, 0);
            for (0..n) |k| {
                const inv = if (k <= j) a[k + j * n] else Z.init(a[j + k * n].re, -a[j + k * n].im);
                const m = original[i + k * n];
                acc.re += m.re * inv.re - m.im * inv.im;
                acc.im += m.re * inv.im + m.im * inv.re;
            }
            try testing.expectApproxEqAbs(if (i == j) @as(f64, 1) else 0, acc.re, 1e-12);
            try testing.expectApproxEqAbs(@as(f64, 0), acc.im, 1e-12);
        }
    }
}

test "gbequb rounds the band scale factors to powers of two" {
    const kl = 1;
    const ku = 1;
    const ld = kl + ku + 1;
    const badly_scaled = [_]f64{ 3, 1, 0, 1, 7, 0, 0, 1, 100 };
    var ab = [_]f64{0} ** (ld * 3);
    for (0..3) |j| for (0..3) |i| {
        if (i + kl < j or j + ku < i) continue;
        ab[ku + i - j + j * ld] = badly_scaled[i + j * 3];
    };

    var r: [3]f64 = undefined;
    var col: [3]f64 = undefined;
    const b = try gbequb(f64, 3, 3, kl, ku, &ab, ld, &r, &col);
    for (r) |v| try testing.expectEqual(@as(f64, 0.5), std.math.frexp(v).significand);
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 64.0), r[2], 1e-15);

    // gbequ uses the reciprocals themselves, and reports the true largest
    // element. The b variant reports the *rounded* one: 64 rather than 100.
    var r_plain: [3]f64 = undefined;
    const plain = try gbequ(f64, 3, 3, kl, ku, &ab, ld, &r_plain, &col);
    try testing.expectApproxEqAbs(@as(f64, 0.01), r_plain[2], 1e-15);
    try testing.expectApproxEqAbs(@as(f64, 100), plain.max_abs, 1e-15);
    try testing.expectApproxEqAbs(@as(f64, 64), b.max_abs, 1e-15);
}
