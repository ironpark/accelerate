//! Simple drivers for linear systems: factor `A` and solve `A X = B` in one
//! call.
//!
//! Each routine here is specialised to a matrix structure, and picking the
//! right one matters more than usual — `ptsv` on a positive-definite
//! tridiagonal system is O(n), `gesv` on the same matrix stored densely is
//! O(n^3).
//!
//! | routine | matrix | storage |
//! |---|---|---|
//! | `gesv` | general | full |
//! | `gbsv` | general banded | band |
//! | `gtsv` | general tridiagonal | three diagonals |
//! | `posv` | symmetric/Hermitian positive definite | full |
//! | `ppsv` | " | packed |
//! | `pbsv` | " banded | band |
//! | `ptsv` | " tridiagonal | two diagonals |
//! | `sysv` | symmetric indefinite | full |
//! | `spsv` | " | packed |
//! | `hesv` | Hermitian indefinite | full |
//! | `hpsv` | " | packed |
//!
//! `B` is overwritten with the solution and `A` with its factorization, so
//! neither survives the call. Everything is column-major; see `root.zig`.
//!
//! ## Symmetric versus Hermitian for complex elements
//!
//! `sysv`/`spsv` treat a complex matrix as **symmetric** (`A = A^T`), not
//! Hermitian, which is a genuinely different problem from `hesv`/`hpsv`
//! (`A = A^H`). LAPACK provides both for the complex precisions and they are
//! not interchangeable. The real precisions have no `he` form, because for real
//! elements the two coincide — asking for one is a compile error rather than a
//! silent redirect.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");

const Int = types.Int;
const Complex = types.Complex;
const Uplo = types.Uplo;
const Error = info_mod.Error;
const dim = types.dim;
const assertMatrix = types.assertMatrix;
const packedLen = types.packedLen;
const ref = work_mod.ref;
const out = work_mod.out;
const opt = types.opt;

/// The `c.zig` declaration for `<prefix><name>`, chosen by element type.
///
/// LAPACK's four precisions differ only in a one-letter prefix, so a comptime
/// `@field` lookup replaces four hand-written dispatch arms per routine. With
/// 459 user-facing routines to get through, that is the difference between a
/// binding and a transcription project.
fn sym(comptime T: type, comptime name: []const u8) @TypeOf(@field(c, [_]u8{types.prefix(T)} ++ name)) {
    return @field(c, [_]u8{types.prefix(T)} ++ name);
}

fn assertReal(comptime T: type, comptime routine: []const u8) void {
    switch (T) {
        f32, f64 => {},
        else => @compileError(routine ++ " is real-only; use the Hermitian form for " ++ @typeName(T)),
    }
}

fn assertComplex(comptime T: type, comptime routine: []const u8) void {
    switch (T) {
        Complex(f32), Complex(f64) => {},
        else => @compileError(routine ++ " is complex-only; for " ++ @typeName(T) ++
            " symmetric and Hermitian coincide, so use the symmetric form"),
    }
}

// ============================================================================
// General
// ============================================================================

/// `A X = B` for a general `n x n` matrix, by LU with partial pivoting.
///
/// `a` is overwritten with `L` and `U` (the unit diagonal of `L` is not
/// stored), `ipiv` receives the pivot indices (**1-based**, as Fortran counts),
/// and `b` is overwritten with `X`.
///
/// Returns `error.SingularMatrix` if a pivot came out exactly zero; `lastInfo()`
/// is then its 1-based position. Note that a *nearly* singular matrix is not
/// reported here at all — the factorization succeeds and the solution is
/// garbage. Use `gecon` on the factor when that matters.
pub fn gesv(
    comptime T: type,
    n: usize,
    nrhs: usize,
    a: []T,
    lda: usize,
    ipiv: []Int,
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

    sym(T, "gesv")(ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), ipiv.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkLu(info);
}

/// `A X = B` for a general band matrix with `kl` subdiagonals and `ku`
/// superdiagonals.
///
/// The band storage `gbsv` wants is **not** the same as the one `gbmv` wants:
/// the factorization needs `kl` extra rows above the band for fill-in, so
/// `A(i, j)` lives at `ab[kl + ku + i - j + j * ldab]` and `ldab >= 2*kl + ku + 1`.
/// Passing a BLAS-shaped band array here silently factors the wrong matrix, so
/// the leading dimension is asserted rather than trusted.
pub fn gbsv(
    comptime T: type,
    n: usize,
    kl: usize,
    ku: usize,
    nrhs: usize,
    ab: []T,
    ldab: usize,
    ipiv: []Int,
    b: []T,
    ldb: usize,
) Error!void {
    std.debug.assert(ldab >= 2 * kl + ku + 1);
    assertMatrix(ab.len, 2 * kl + ku + 1, n, ldab);
    assertMatrix(b.len, n, nrhs, ldb);
    std.debug.assert(ipiv.len >= n);

    const n_ = dim(n);
    const kl_ = dim(kl);
    const ku_ = dim(ku);
    const nrhs_ = dim(nrhs);
    const ldab_ = dim(ldab);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, "gbsv")(ref(&n_), ref(&kl_), ref(&ku_), ref(&nrhs_), ab.ptr, ref(&ldab_), ipiv.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkLu(info);
}

/// `A X = B` for a general tridiagonal matrix given as its three diagonals.
///
/// `dl` is the subdiagonal (`n - 1` elements), `d` the diagonal (`n`), `du` the
/// superdiagonal (`n - 1`). All three are overwritten, and the factorization is
/// not recoverable afterwards — `gtsv` discards it. Use `gttrf`/`gttrs` to
/// factor once and solve repeatedly.
pub fn gtsv(
    comptime T: type,
    n: usize,
    nrhs: usize,
    dl: []T,
    d: []T,
    du: []T,
    b: []T,
    ldb: usize,
) Error!void {
    std.debug.assert(d.len >= n);
    if (n > 1) {
        std.debug.assert(dl.len >= n - 1);
        std.debug.assert(du.len >= n - 1);
    }
    assertMatrix(b.len, n, nrhs, ldb);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, "gtsv")(ref(&n_), ref(&nrhs_), dl.ptr, d.ptr, du.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkLu(info);
}

// ============================================================================
// Positive definite
// ============================================================================

/// `A X = B` for a symmetric (Hermitian, if complex) positive definite matrix,
/// by Cholesky factorization.
///
/// Only the `uplo` triangle of `a` is read; the other is untouched. On success
/// `a` holds the Cholesky factor in that same triangle.
///
/// Returns `error.NotPositiveDefinite` if the matrix is not — `lastInfo()` is
/// the order of the leading minor that failed. This is the cheapest reliable
/// positive-definiteness test there is, so the error is a useful answer rather
/// than only a failure.
pub fn posv(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []T,
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

    sym(T, "posv")(opt(uplo), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkCholesky(info);
}

/// `posv` for a matrix in packed storage: the `uplo` triangle only, stored
/// column by column with no leading dimension. `ap.len >= n * (n + 1) / 2`.
pub fn ppsv(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    ap: []T,
    b: []T,
    ldb: usize,
) Error!void {
    std.debug.assert(ap.len >= packedLen(n));
    assertMatrix(b.len, n, nrhs, ldb);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, "ppsv")(opt(uplo), ref(&n_), ref(&nrhs_), ap.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkCholesky(info);
}

/// `posv` for a positive definite band matrix with `kd` off-diagonals.
///
/// Unlike `gbsv`, no extra rows are needed — Cholesky on a positive definite
/// matrix pivots on the diagonal, so there is no fill-in above the band and
/// `ldab >= kd + 1` suffices.
pub fn pbsv(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    kd: usize,
    nrhs: usize,
    ab: []T,
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

    sym(T, "pbsv")(opt(uplo), ref(&n_), ref(&kd_), ref(&nrhs_), ab.ptr, ref(&ldab_), b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkCholesky(info);
}

/// `posv` for a positive definite tridiagonal matrix.
///
/// `d` is the diagonal and is **always real**, even for complex `A` — a
/// Hermitian matrix has a real diagonal by definition. That is why `d` is
/// `[]Real(T)` rather than `[]T`, which the type system enforces here and the C
/// signature only implies.
pub fn ptsv(
    comptime T: type,
    n: usize,
    nrhs: usize,
    d: []types.Real(T),
    e: []T,
    b: []T,
    ldb: usize,
) Error!void {
    std.debug.assert(d.len >= n);
    if (n > 1) std.debug.assert(e.len >= n - 1);
    assertMatrix(b.len, n, nrhs, ldb);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, "ptsv")(ref(&n_), ref(&nrhs_), d.ptr, e.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkCholesky(info);
}

// ============================================================================
// Symmetric / Hermitian indefinite
// ============================================================================

/// Optimal `work` length for `sysv`. See `sysvWithWorkspace`.
pub fn sysvWorkspaceSize(comptime T: type, uplo: Uplo, n: usize, nrhs: usize, lda: usize, ldb: usize) Error!usize {
    return indefiniteQuery(T, "sysv", uplo, n, nrhs, lda, ldb);
}

/// `A X = B` for a symmetric indefinite matrix, by Bunch-Kaufman.
///
/// Allocates the workspace itself, sized by a query. `ipiv` encodes 1x1 and 2x2
/// pivot blocks and is interpreted differently from `gesv`'s: a negative entry
/// marks a 2x2 block. Do not feed it to a routine expecting LU pivots.
///
/// For complex `T` this is the **symmetric** (`A = A^T`) problem. See `hesv`.
pub fn sysv(
    comptime T: type,
    allocator: std.mem.Allocator,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []T,
    lda: usize,
    ipiv: []Int,
    b: []T,
    ldb: usize,
) (Error || std.mem.Allocator.Error)!void {
    const size = try sysvWorkspaceSize(T, uplo, n, nrhs, lda, ldb);
    const buf = try allocator.alloc(T, @max(size, 1));
    defer allocator.free(buf);
    return sysvWithWorkspace(T, uplo, n, nrhs, a, lda, ipiv, b, ldb, buf);
}

/// `sysv` with a caller-supplied workspace.
///
/// The documented minimum is 1 (`n` for a blocked path to be taken at all), but
/// performance depends on the length, so prefer the size `sysvWorkspaceSize`
/// reports. Too short is a clean `error.InvalidArgument`, not corruption.
pub fn sysvWithWorkspace(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []T,
    lda: usize,
    ipiv: []Int,
    b: []T,
    ldb: usize,
    work: []T,
) Error!void {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, nrhs, ldb);
    std.debug.assert(ipiv.len >= n);
    std.debug.assert(work.len >= 1);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    const lwork = dim(work.len);
    var info: Int = 0;

    sym(T, "sysv")(opt(uplo), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), ipiv.ptr, b.ptr, ref(&ldb_), work.ptr, ref(&lwork), out(&info));
    return info_mod.checkIndefinite(info);
}

/// Optimal `work` length for `hesv`.
pub fn hesvWorkspaceSize(comptime T: type, uplo: Uplo, n: usize, nrhs: usize, lda: usize, ldb: usize) Error!usize {
    assertComplex(T, "hesv");
    return indefiniteQuery(T, "hesv", uplo, n, nrhs, lda, ldb);
}

/// `A X = B` for a Hermitian indefinite matrix (`A = A^H`), by Bunch-Kaufman.
///
/// Complex precisions only: for real elements Hermitian and symmetric are the
/// same problem, and LAPACK ships no `ssysv`-equivalent `hesv`. Asking for
/// `hesv(f64, ...)` is a compile error pointing at `sysv`, rather than a
/// missing-symbol link failure.
pub fn hesv(
    comptime T: type,
    allocator: std.mem.Allocator,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []T,
    lda: usize,
    ipiv: []Int,
    b: []T,
    ldb: usize,
) (Error || std.mem.Allocator.Error)!void {
    const size = try hesvWorkspaceSize(T, uplo, n, nrhs, lda, ldb);
    const buf = try allocator.alloc(T, @max(size, 1));
    defer allocator.free(buf);
    return hesvWithWorkspace(T, uplo, n, nrhs, a, lda, ipiv, b, ldb, buf);
}

/// `hesv` with a caller-supplied workspace.
pub fn hesvWithWorkspace(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []T,
    lda: usize,
    ipiv: []Int,
    b: []T,
    ldb: usize,
    work: []T,
) Error!void {
    assertComplex(T, "hesv");
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, nrhs, ldb);
    std.debug.assert(ipiv.len >= n);
    std.debug.assert(work.len >= 1);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    const lwork = dim(work.len);
    var info: Int = 0;

    sym(T, "hesv")(opt(uplo), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), ipiv.ptr, b.ptr, ref(&ldb_), work.ptr, ref(&lwork), out(&info));
    return info_mod.checkIndefinite(info);
}

/// Shared `lwork = -1` query for `sysv`/`hesv`.
///
/// The query reads none of the arrays, so this passes a one-element dummy
/// rather than requiring the caller to have the matrix in hand — which is what
/// makes `sysvWorkspaceSize` callable before allocating anything.
fn indefiniteQuery(
    comptime T: type,
    comptime name: []const u8,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    lda: usize,
    ldb: usize,
) Error!usize {
    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const lwork = work_mod.query;
    var probe: [1]T = undefined;
    var ipiv: [1]Int = undefined;
    var wq: [1]T = undefined;
    var info: Int = 0;

    sym(T, name)(opt(uplo), ref(&n_), ref(&nrhs_), &probe, ref(&lda_), &ipiv, &probe, ref(&ldb_), &wq, ref(&lwork), out(&info));
    try info_mod.checkArgs(info);
    return @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
}

/// `sysv` for a symmetric indefinite matrix in packed storage. Needs no
/// workspace — the packed path is unblocked.
pub fn spsv(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    ap: []T,
    ipiv: []Int,
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

    sym(T, "spsv")(opt(uplo), ref(&n_), ref(&nrhs_), ap.ptr, ipiv.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkIndefinite(info);
}

/// `hesv` for a Hermitian indefinite matrix in packed storage. Complex only.
pub fn hpsv(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    ap: []T,
    ipiv: []Int,
    b: []T,
    ldb: usize,
) Error!void {
    assertComplex(T, "hpsv");
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(ipiv.len >= n);
    assertMatrix(b.len, n, nrhs, ldb);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, "hpsv")(opt(uplo), ref(&n_), ref(&nrhs_), ap.ptr, ipiv.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkIndefinite(info);
}

// ============================================================================
// Mixed precision
// ============================================================================

/// `A X = B` in double precision, factored in single and refined back up.
///
/// The single-precision factorization costs half the memory traffic of a double
/// one, and iterative refinement recovers double accuracy when the matrix is
/// well enough conditioned. When it is not, the routine gives up and factors in
/// double instead, so the answer is never worse — only the time spent is.
///
/// `iter` reports which happened: positive is the number of refinement steps,
/// negative means it fell back. `a` and `b` are **not** overwritten here; `x`
/// receives the solution.
pub fn sgesvIterative(
    n: usize,
    nrhs: usize,
    a: []f64,
    lda: usize,
    ipiv: []Int,
    b: []const f64,
    ldb: usize,
    x: []f64,
    ldx: usize,
    workd: []f64,
    works: []f32,
) Error!Int {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ipiv.len >= n);
    std.debug.assert(workd.len >= n * nrhs);
    std.debug.assert(works.len >= n * (n + nrhs));

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var iter: Int = 0;
    var info: Int = 0;

    c.dsgesv(
        ref(&n_),
        ref(&nrhs_),
        a.ptr,
        ref(&lda_),
        ipiv.ptr,
        @constCast(b.ptr),
        ref(&ldb_),
        x.ptr,
        ref(&ldx_),
        workd.ptr,
        works.ptr,
        out(&iter),
        out(&info),
    );
    try info_mod.checkLu(info);
    return iter;
}

/// `sgesvIterative` for a positive definite matrix.
pub fn sposvIterative(
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []f64,
    lda: usize,
    b: []const f64,
    ldb: usize,
    x: []f64,
    ldx: usize,
    workd: []f64,
    works: []f32,
) Error!Int {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(workd.len >= n * nrhs);
    std.debug.assert(works.len >= n * (n + nrhs));

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var iter: Int = 0;
    var info: Int = 0;

    c.dsposv(
        opt(uplo),
        ref(&n_),
        ref(&nrhs_),
        a.ptr,
        ref(&lda_),
        @constCast(b.ptr),
        ref(&ldb_),
        x.ptr,
        ref(&ldx_),
        workd.ptr,
        works.ptr,
        out(&iter),
        out(&info),
    );
    try info_mod.checkCholesky(info);
    return iter;
}

/// `sgesvIterative` for complex elements: factored in single, refined to double.
///
/// The complex counterpart takes an extra `rwork` of `n` reals that the real
/// pair has no use for.
pub fn cgesvIterative(
    n: usize,
    nrhs: usize,
    a: []Complex(f64),
    lda: usize,
    ipiv: []Int,
    b: []const Complex(f64),
    ldb: usize,
    x: []Complex(f64),
    ldx: usize,
    workd: []Complex(f64),
    works: []Complex(f32),
    rwork: []f64,
) Error!Int {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ipiv.len >= n);
    std.debug.assert(workd.len >= n * nrhs);
    std.debug.assert(works.len >= n * (n + nrhs));
    std.debug.assert(rwork.len >= n);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var iter: Int = 0;
    var info: Int = 0;

    c.zcgesv(
        ref(&n_),
        ref(&nrhs_),
        a.ptr,
        ref(&lda_),
        ipiv.ptr,
        b.ptr,
        ref(&ldb_),
        x.ptr,
        ref(&ldx_),
        workd.ptr,
        works.ptr,
        rwork.ptr,
        out(&iter),
        out(&info),
    );
    try info_mod.checkLu(info);
    return iter;
}

/// `cgesvIterative` for a Hermitian positive definite matrix.
pub fn cposvIterative(
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []Complex(f64),
    lda: usize,
    b: []const Complex(f64),
    ldb: usize,
    x: []Complex(f64),
    ldx: usize,
    workd: []Complex(f64),
    works: []Complex(f32),
    rwork: []f64,
) Error!Int {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(workd.len >= n * nrhs);
    std.debug.assert(works.len >= n * (n + nrhs));
    std.debug.assert(rwork.len >= n);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var iter: Int = 0;
    var info: Int = 0;

    c.zcposv(
        opt(uplo),
        ref(&n_),
        ref(&nrhs_),
        a.ptr,
        ref(&lda_),
        b.ptr,
        ref(&ldb_),
        x.ptr,
        ref(&ldx_),
        workd.ptr,
        works.ptr,
        rwork.ptr,
        out(&iter),
        out(&info),
    );
    try info_mod.checkCholesky(info);
    return iter;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// `max |A x - b|`, for checking a solve without comparing against a constant
/// I worked out by hand. Column-major `A`.
fn residual(comptime T: type, n: usize, a: []const T, lda: usize, x: []const T, b: []const T) T {
    var worst: T = 0;
    for (0..n) |i| {
        var acc: T = 0;
        for (0..n) |j| acc += a[i + j * lda] * x[j];
        worst = @max(worst, @abs(acc - b[i]));
    }
    return worst;
}

test "gesv solves a general system" {
    // Column-major [[2, 1, 1], [1, 3, 2], [1, 0, 0]]
    const original = [_]f64{ 2, 1, 1, 1, 3, 0, 1, 2, 0 };
    var a = original;
    var b = [_]f64{ 4, 5, 6 };
    const rhs = b;
    var ipiv: [3]Int = undefined;

    try gesv(f64, 3, 1, &a, 3, &ipiv, &b, 3);

    // Check the residual against the *original* matrix rather than an expected
    // vector: a wrong solution and a wrong expectation cannot cancel out.
    try testing.expect(residual(f64, 3, &original, 3, &b, &rhs) < 1e-12);
}

test "gesv reports an exactly singular pivot" {
    var a = [_]f64{ 1, 2, 2, 4 }; // second column is twice the first
    var b = [_]f64{ 1, 2 };
    var ipiv: [2]Int = undefined;

    try testing.expectError(error.SingularMatrix, gesv(f64, 2, 1, &a, 2, &ipiv, &b, 2));
    try testing.expectEqual(@as(Int, 2), info_mod.lastInfo());
}

test "gesv pivots are 1-based" {
    // [[0, 1], [1, 0]] forces a row swap, so ipiv[0] must name row 2.
    var a = [_]f64{ 0, 1, 1, 0 };
    var b = [_]f64{ 1, 2 };
    var ipiv: [2]Int = undefined;

    try gesv(f64, 2, 1, &a, 2, &ipiv, &b, 2);

    // Fortran counts from 1. A 0-based reading would make this a no-op swap and
    // any code interpreting ipiv itself would silently permute wrongly.
    try testing.expectEqual(@as(Int, 2), ipiv[0]);
    try testing.expectApproxEqAbs(@as(f64, 2), b[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1), b[1], 1e-12);
}

test "gesv handles multiple right-hand sides" {
    const original = [_]f64{ 2, 1, 1, 3 };
    var a = original;
    // Two columns: [1, 2] and [3, 4].
    var b = [_]f64{ 1, 2, 3, 4 };
    const rhs = b;
    var ipiv: [2]Int = undefined;

    try gesv(f64, 2, 2, &a, 2, &ipiv, &b, 2);

    try testing.expect(residual(f64, 2, &original, 2, b[0..2], rhs[0..2]) < 1e-12);
    try testing.expect(residual(f64, 2, &original, 2, b[2..4], rhs[2..4]) < 1e-12);
}

test "posv solves and leaves the other triangle alone" {
    // Column-major SPD [[4, 1], [1, 3]], with the strict lower triangle
    // poisoned. `.upper` must not read it, and must not write it either.
    var a = [_]f64{ 4, -999, 1, 3 };
    var b = [_]f64{ 1, 2 };

    try posv(f64, .upper, 2, 1, &a, 2, &b, 2);

    try testing.expectEqual(@as(f64, -999), a[1]);
    // A x = b with A = [[4, 1], [1, 3]] -> x = [1/11, 7/11]
    const spd = [_]f64{ 4, 1, 1, 3 };
    try testing.expect(residual(f64, 2, &spd, 2, &b, &.{ 1, 2 }) < 1e-12);
}

test "posv reports a non-positive-definite matrix" {
    // [[1, 2], [2, 1]] is symmetric with eigenvalues 3 and -1.
    var a = [_]f64{ 1, 2, 2, 1 };
    var b = [_]f64{ 1, 1 };

    try testing.expectError(error.NotPositiveDefinite, posv(f64, .upper, 2, 1, &a, 2, &b, 2));
    // The leading 2x2 minor is where it failed.
    try testing.expectEqual(@as(Int, 2), info_mod.lastInfo());
}

test "ppsv agrees with posv on the same matrix" {
    // Upper packed storage of [[4, 1], [1, 3]] is a11, a12, a22.
    var ap = [_]f64{ 4, 1, 3 };
    var bp = [_]f64{ 1, 2 };
    try ppsv(f64, .upper, 2, 1, &ap, &bp, 2);

    var a = [_]f64{ 4, 0, 1, 3 };
    var b = [_]f64{ 1, 2 };
    try posv(f64, .upper, 2, 1, &a, 2, &b, 2);

    try testing.expectApproxEqAbs(b[0], bp[0], 1e-12);
    try testing.expectApproxEqAbs(b[1], bp[1], 1e-12);
}

test "pbsv solves a positive definite band system" {
    // Tridiagonal SPD [[4, 1, 0], [1, 4, 1], [0, 1, 4]], kd = 1, upper band.
    // Upper band storage puts the superdiagonal in row 0 and the diagonal in
    // row 1; ab[0] is unreferenced because column 0 has no superdiagonal.
    var ab = [_]f64{ -999, 4, 1, 4, 1, 4 };
    var b = [_]f64{ 1, 2, 3 };

    try pbsv(f64, .upper, 3, 1, 1, &ab, 2, &b, 3);

    const full = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };
    try testing.expect(residual(f64, 3, &full, 3, &b, &.{ 1, 2, 3 }) < 1e-12);
}

test "ptsv takes a real diagonal even for a complex matrix" {
    // A Hermitian tridiagonal has a real diagonal by construction, and the type
    // signature says so. This is `[]f64` next to `[]Complex(f64)`, which would
    // be a silent size mismatch if the binding used []T for both.
    const Z = Complex(f64);
    var d = [_]f64{ 4, 4 };
    var e = [_]Z{Z.init(1, 1)};
    var b = [_]Z{ Z.init(1, 0), Z.init(0, 1) };

    try ptsv(Z, 2, 1, &d, &e, &b, 2);

    // A = [[4, 1-i], [1+i, 4]] (e holds the subdiagonal, so A(2,1) = 1+i).
    // Verify by multiplying back.
    const a00 = Z.init(4, 0);
    const a01 = Z.init(1, -1);
    const a10 = Z.init(1, 1);
    const a11 = Z.init(4, 0);
    const r0 = a00.mul(b[0]).add(a01.mul(b[1]));
    const r1 = a10.mul(b[0]).add(a11.mul(b[1]));
    try testing.expectApproxEqAbs(@as(f64, 1), r0.re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), r0.im, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), r1.re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1), r1.im, 1e-12);
}

test "sysv solves an indefinite symmetric system" {
    // [[1, 2], [2, 1]] is symmetric and indefinite - posv rejects it, sysv does
    // not. Solution of A x = [1, 1] is [1/3, 1/3].
    var a = [_]f64{ 1, 2, 2, 1 };
    var b = [_]f64{ 1, 1 };
    var ipiv: [2]Int = undefined;

    try sysv(f64, testing.allocator, .upper, 2, 1, &a, 2, &ipiv, &b, 2);

    const full = [_]f64{ 1, 2, 2, 1 };
    try testing.expect(residual(f64, 2, &full, 2, &b, &.{ 1, 1 }) < 1e-12);
}

test "sysv workspace query reports a usable size" {
    const size = try sysvWorkspaceSize(f64, .upper, 8, 1, 8, 8);
    try testing.expect(size >= 1);

    var a = [_]f64{0} ** 64;
    for (0..8) |i| a[i + i * 8] = 4;
    a[0 + 1 * 8] = 1;
    a[1 + 0 * 8] = 1;
    var b = [_]f64{1} ** 8;
    var ipiv: [8]Int = undefined;
    const buf = try testing.allocator.alloc(f64, size);
    defer testing.allocator.free(buf);

    try sysvWithWorkspace(f64, .upper, 8, 1, &a, 8, &ipiv, &b, 8, buf);
}

test "spsv solves the packed indefinite system" {
    // Upper packed [[1, 2], [2, 1]].
    var ap = [_]f64{ 1, 2, 1 };
    var b = [_]f64{ 1, 1 };
    var ipiv: [2]Int = undefined;

    try spsv(f64, .upper, 2, 1, &ap, &ipiv, &b, 2);

    const full = [_]f64{ 1, 2, 2, 1 };
    try testing.expect(residual(f64, 2, &full, 2, &b, &.{ 1, 1 }) < 1e-12);
}

test "hesv and sysv disagree on a complex matrix" {
    // The whole reason both exist. A = [[2, i], [-i, 2]] is Hermitian (A = A^H)
    // but not symmetric (A != A^T). Solving it as symmetric gives a different
    // answer, and neither routine can tell you that you picked wrong.
    const Z = Complex(f64);
    const rhs = [_]Z{ Z.init(1, 0), Z.init(0, 0) };

    // Hermitian reading: lower triangle holds A(2,1) = -i.
    var ah = [_]Z{ Z.init(2, 0), Z.init(0, -1), Z.init(0, 0), Z.init(2, 0) };
    var bh = rhs;
    var ipiv: [2]Int = undefined;
    try hesv(Z, testing.allocator, .lower, 2, 1, &ah, 2, &ipiv, &bh, 2);

    // Symmetric reading of the same stored triangle: A(1,2) = A(2,1) = -i.
    var as = [_]Z{ Z.init(2, 0), Z.init(0, -1), Z.init(0, 0), Z.init(2, 0) };
    var bs = rhs;
    try sysv(Z, testing.allocator, .lower, 2, 1, &as, 2, &ipiv, &bs, 2);

    // Hermitian: A = [[2, i], [-i, 2]], det = 3, x = [2/3, i/3].
    try testing.expectApproxEqAbs(@as(f64, 2.0 / 3.0), bh[0].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), bh[0].im, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), bh[1].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 3.0), bh[1].im, 1e-12);

    // Symmetric: A = [[2, -i], [-i, 2]], det = 4 + i^2*... -> a different x.
    try testing.expect(@abs(bs[1].im - bh[1].im) > 1e-6);
}

test "hpsv matches hesv in packed storage" {
    const Z = Complex(f64);
    // Lower packed storage of [[2, i], [-i, 2]]: a11, a21, a22.
    var ap = [_]Z{ Z.init(2, 0), Z.init(0, -1), Z.init(2, 0) };
    var b = [_]Z{ Z.init(1, 0), Z.init(0, 0) };
    var ipiv: [2]Int = undefined;

    try hpsv(Z, .lower, 2, 1, &ap, &ipiv, &b, 2);

    try testing.expectApproxEqAbs(@as(f64, 2.0 / 3.0), b[0].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 3.0), b[1].im, 1e-12);
}

test "gbsv wants the extra kl rows that gbmv does not" {
    // A = [[2, 1, 0], [1, 2, 1], [0, 1, 2]], kl = ku = 1.
    // ldab must be 2*kl + ku + 1 = 4, with the first kl rows left for fill-in.
    // Row kl+ku+i-j of column j holds A(i, j).
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
    var b = [_]f64{ 1, 2, 3 };
    var ipiv: [3]Int = undefined;

    try gbsv(f64, 3, kl, ku, 1, &ab, ldab, &ipiv, &b, 3);

    try testing.expect(residual(f64, 3, &full, 3, &b, &.{ 1, 2, 3 }) < 1e-12);
}

test "gtsv solves a tridiagonal system" {
    var dl = [_]f64{ 1, 1 };
    var d = [_]f64{ 4, 4, 4 };
    var du = [_]f64{ 1, 1 };
    var b = [_]f64{ 1, 2, 3 };

    try gtsv(f64, 3, 1, &dl, &d, &du, &b, 3);

    const full = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };
    try testing.expect(residual(f64, 3, &full, 3, &b, &.{ 1, 2, 3 }) < 1e-12);
}

test "dsgesv refines a single-precision factorization back to double" {
    const n = 4;
    // Well-conditioned, so the refinement path should succeed rather than fall
    // back to a double factorization.
    const full = [_]f64{ 4, 1, 0, 0, 1, 4, 1, 0, 0, 1, 4, 1, 0, 0, 1, 4 };
    var a = full;
    const b = [_]f64{ 1, 2, 3, 4 };
    var x = [_]f64{0} ** n;
    var ipiv: [n]Int = undefined;
    var workd = [_]f64{0} ** (n * 1);
    var works = [_]f32{0} ** (n * (n + 1));

    const iter = try sgesvIterative(n, 1, &a, n, &ipiv, &b, n, &x, n, &workd, &works);

    // Positive iter means refinement converged in that many steps; negative
    // means it gave up and factored in double instead. Both produce a correct
    // answer, so the residual is what gets asserted - but iter is still pinned
    // as nonzero, because a zero would mean neither path ran and the routine
    // returned whatever was already in x.
    try testing.expect(residual(f64, n, &full, n, &x, &b) < 1e-10);
    try testing.expect(iter != 0);

    // b must be intact - unlike every other driver here, dsgesv does not
    // overwrite the right-hand side.
    try testing.expectEqual(@as(f64, 1), b[0]);
    try testing.expectEqual(@as(f64, 4), b[3]);
}

test "dsposv refines a positive definite system" {
    const n = 3;
    const full = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };
    var a = full;
    const b = [_]f64{ 1, 2, 3 };
    var x = [_]f64{0} ** n;
    var workd = [_]f64{0} ** n;
    var works = [_]f32{0} ** (n * (n + 1));

    _ = try sposvIterative(.upper, n, 1, &a, n, &b, n, &x, n, &workd, &works);

    try testing.expect(residual(f64, n, &full, n, &x, &b) < 1e-10);
}

test "single precision works through the same wrappers" {
    const original = [_]f32{ 2, 1, 1, 3 };
    var a = original;
    var b = [_]f32{ 3, 5 };
    var ipiv: [2]Int = undefined;

    try gesv(f32, 2, 1, &a, 2, &ipiv, &b, 2);

    try testing.expect(residual(f32, 2, &original, 2, &b, &.{ 3, 5 }) < 1e-5);
}

test "cgesvIterative solves a complex system in mixed precision" {
    const Z = Complex(f64);
    const n = 3;
    var a = [_]Z{
        Z.init(4, 0), Z.init(1, -1), Z.init(0, 0),
        Z.init(1, 1), Z.init(5, 0),  Z.init(1, -1),
        Z.init(0, 0), Z.init(1, 1),  Z.init(6, 0),
    };
    const original = a;
    const b = [_]Z{ Z.init(1, 0), Z.init(2, 1), Z.init(3, -1) };
    var ipiv: [n]Int = undefined;
    var x: [n]Z = undefined;
    var workd: [n]Z = undefined;
    var works: [n * (n + 1)]Complex(f32) = undefined;
    var rwork: [n]f64 = undefined;

    // iter is positive when refinement converged and negative when the routine
    // fell back to a double factorization. Both are correct outcomes and which
    // one happens is not this binding's business, so the residual is what is
    // pinned.
    _ = try cgesvIterative(n, 1, &a, n, &ipiv, &b, n, &x, n, &workd, &works, &rwork);

    for (0..n) |i| {
        var acc = Z.init(0, 0);
        for (0..n) |j| {
            const m = original[i + j * n];
            acc.re += m.re * x[j].re - m.im * x[j].im;
            acc.im += m.re * x[j].im + m.im * x[j].re;
        }
        try testing.expectApproxEqAbs(b[i].re, acc.re, 1e-12);
        try testing.expectApproxEqAbs(b[i].im, acc.im, 1e-12);
    }
}

test "cposvIterative solves a Hermitian positive definite system" {
    const Z = Complex(f64);
    const n = 2;
    var a = [_]Z{ Z.init(4, 0), Z.init(0, -1), Z.init(0, 1), Z.init(5, 0) };
    const original = a;
    const b = [_]Z{ Z.init(1, 0), Z.init(0, 1) };
    var x: [n]Z = undefined;
    var workd: [n]Z = undefined;
    var works: [n * (n + 1)]Complex(f32) = undefined;
    var rwork: [n]f64 = undefined;

    _ = try cposvIterative(.upper, n, 1, &a, n, &b, n, &x, n, &workd, &works, &rwork);

    for (0..n) |i| {
        var acc = Z.init(0, 0);
        for (0..n) |j| {
            const m = original[i + j * n];
            acc.re += m.re * x[j].re - m.im * x[j].im;
            acc.im += m.re * x[j].im + m.im * x[j].re;
        }
        try testing.expectApproxEqAbs(b[i].re, acc.re, 1e-12);
        try testing.expectApproxEqAbs(b[i].im, acc.im, 1e-12);
    }
}

test "hesvWorkspaceSize and hesvWithWorkspace match hesv" {
    const Z = Complex(f64);
    const n = 2;
    const a0 = [_]Z{ Z.init(2, 0), Z.init(0, -1), Z.init(0, 1), Z.init(2, 0) };
    const b0 = [_]Z{ Z.init(1, 0), Z.init(0, 1) };

    var a_alloc = a0;
    var b_alloc = b0;
    var ipiv_alloc: [n]Int = undefined;
    try hesv(Z, testing.allocator, .upper, n, 1, &a_alloc, n, &ipiv_alloc, &b_alloc, n);

    const size = try hesvWorkspaceSize(Z, .upper, n, 1, n, n);
    const work = try testing.allocator.alloc(Z, size);
    defer testing.allocator.free(work);

    var a_manual = a0;
    var b_manual = b0;
    var ipiv_manual: [n]Int = undefined;
    try hesvWithWorkspace(Z, .upper, n, 1, &a_manual, n, &ipiv_manual, &b_manual, n, work);

    for (b_alloc, b_manual) |x, y| {
        try testing.expectApproxEqAbs(x.re, y.re, 1e-14);
        try testing.expectApproxEqAbs(x.im, y.im, 1e-14);
    }
    // And the solution really solves the original system.
    for (0..n) |i| {
        var acc = Z.init(0, 0);
        for (0..n) |j| {
            const m = a0[i + j * n];
            acc.re += m.re * b_manual[j].re - m.im * b_manual[j].im;
            acc.im += m.re * b_manual[j].im + m.im * b_manual[j].re;
        }
        try testing.expectApproxEqAbs(b0[i].re, acc.re, 1e-13);
        try testing.expectApproxEqAbs(b0[i].im, acc.im, 1e-13);
    }
}
