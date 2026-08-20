//! BLAS Level 2: matrix-vector operations.
//!
//! Parameter order follows CBLAS so the reference documentation reads across
//! directly; what changes is that matrices and vectors arrive as slices whose
//! lengths are checked against the dimensions, and that the scalar types
//! encode the Hermitian routines' real-alpha requirement.
//!
//! Storage conventions, all as in BLAS:
//!
//! * **General / triangular** matrices are dense with leading dimension `lda`.
//! * **Banded** matrices store `kl` sub- and `ku` super-diagonals in
//!   `kl + ku + 1` rows.
//! * **Packed** triangular matrices store `n(n+1)/2` elements contiguously.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");

const Complex = types.Complex;
const Scalar = types.Scalar;
const Order = types.Order;
const Transpose = types.Transpose;
const Uplo = types.Uplo;
const Diag = types.Diag;
const dim = types.dim;
const inc = types.inc;
const vectorLen = types.vectorLen;
const matrixLen = types.matrixLen;
const packedLen = types.packedLen;

fn unsupported(comptime T: type, comptime op: []const u8) noreturn {
    @compileError(op ++ " is not defined for " ++ @typeName(T));
}

/// For `y := alpha * op(A) * x + beta * y` with `A` being `m x n`, the lengths
/// `x` and `y` must have.
fn gemvLengths(trans: Transpose, m: usize, n: usize) struct { usize, usize } {
    return if (trans == .no_trans) .{ n, m } else .{ m, n };
}

// ============================================================================
// General matrix-vector
// ============================================================================

/// `y := alpha * op(A) * x + beta * y`, `A` general `m x n`.
pub fn gemv(
    comptime T: type,
    order: Order,
    trans: Transpose,
    m: usize,
    n: usize,
    alpha: T,
    a: []const T,
    lda: usize,
    x: []const T,
    incx: isize,
    beta: T,
    y: []T,
    incy: isize,
) void {
    const xn, const yn = gemvLengths(trans, m, n);
    std.debug.assert(a.len >= matrixLen(order, m, n, lda));
    std.debug.assert(x.len >= vectorLen(xn, incx));
    std.debug.assert(y.len >= vectorLen(yn, incy));
    switch (T) {
        f32 => c.cblas_sgemv(order, trans, dim(m), dim(n), alpha, a.ptr, dim(lda), x.ptr, inc(incx), beta, y.ptr, inc(incy)),
        f64 => c.cblas_dgemv(order, trans, dim(m), dim(n), alpha, a.ptr, dim(lda), x.ptr, inc(incx), beta, y.ptr, inc(incy)),
        Complex(f32) => c.cblas_cgemv(order, trans, dim(m), dim(n), &alpha, a.ptr, dim(lda), x.ptr, inc(incx), &beta, y.ptr, inc(incy)),
        Complex(f64) => c.cblas_zgemv(order, trans, dim(m), dim(n), &alpha, a.ptr, dim(lda), x.ptr, inc(incx), &beta, y.ptr, inc(incy)),
        else => unsupported(T, "gemv"),
    }
}

/// `y := alpha * op(A) * x + beta * y`, `A` banded `m x n` with `kl`
/// sub-diagonals and `ku` super-diagonals.
pub fn gbmv(
    comptime T: type,
    order: Order,
    trans: Transpose,
    m: usize,
    n: usize,
    kl: usize,
    ku: usize,
    alpha: T,
    a: []const T,
    lda: usize,
    x: []const T,
    incx: isize,
    beta: T,
    y: []T,
    incy: isize,
) void {
    const xn, const yn = gemvLengths(trans, m, n);
    std.debug.assert(lda >= kl + ku + 1);
    std.debug.assert(a.len >= matrixLen(order, if (order == .col_major) kl + ku + 1 else n, if (order == .col_major) n else kl + ku + 1, lda));
    std.debug.assert(x.len >= vectorLen(xn, incx));
    std.debug.assert(y.len >= vectorLen(yn, incy));
    switch (T) {
        f32 => c.cblas_sgbmv(order, trans, dim(m), dim(n), dim(kl), dim(ku), alpha, a.ptr, dim(lda), x.ptr, inc(incx), beta, y.ptr, inc(incy)),
        f64 => c.cblas_dgbmv(order, trans, dim(m), dim(n), dim(kl), dim(ku), alpha, a.ptr, dim(lda), x.ptr, inc(incx), beta, y.ptr, inc(incy)),
        Complex(f32) => c.cblas_cgbmv(order, trans, dim(m), dim(n), dim(kl), dim(ku), &alpha, a.ptr, dim(lda), x.ptr, inc(incx), &beta, y.ptr, inc(incy)),
        Complex(f64) => c.cblas_zgbmv(order, trans, dim(m), dim(n), dim(kl), dim(ku), &alpha, a.ptr, dim(lda), x.ptr, inc(incx), &beta, y.ptr, inc(incy)),
        else => unsupported(T, "gbmv"),
    }
}

// ============================================================================
// Rank-1 updates
// ============================================================================

/// `A := alpha * x * y^T + A`, real types only. Complex has `geru`/`gerc`.
pub fn ger(
    comptime T: type,
    order: Order,
    m: usize,
    n: usize,
    alpha: T,
    x: []const T,
    incx: isize,
    y: []const T,
    incy: isize,
    a: []T,
    lda: usize,
) void {
    std.debug.assert(x.len >= vectorLen(m, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    std.debug.assert(a.len >= matrixLen(order, m, n, lda));
    switch (T) {
        f32 => c.cblas_sger(order, dim(m), dim(n), alpha, x.ptr, inc(incx), y.ptr, inc(incy), a.ptr, dim(lda)),
        f64 => c.cblas_dger(order, dim(m), dim(n), alpha, x.ptr, inc(incx), y.ptr, inc(incy), a.ptr, dim(lda)),
        else => unsupported(T, "ger"),
    }
}

/// `A := alpha * x * y^T + A` (unconjugated), complex only.
pub fn geru(
    comptime T: type,
    order: Order,
    m: usize,
    n: usize,
    alpha: T,
    x: []const T,
    incx: isize,
    y: []const T,
    incy: isize,
    a: []T,
    lda: usize,
) void {
    std.debug.assert(x.len >= vectorLen(m, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    std.debug.assert(a.len >= matrixLen(order, m, n, lda));
    switch (T) {
        Complex(f32) => c.cblas_cgeru(order, dim(m), dim(n), &alpha, x.ptr, inc(incx), y.ptr, inc(incy), a.ptr, dim(lda)),
        Complex(f64) => c.cblas_zgeru(order, dim(m), dim(n), &alpha, x.ptr, inc(incx), y.ptr, inc(incy), a.ptr, dim(lda)),
        else => unsupported(T, "geru"),
    }
}

/// `A := alpha * x * y^H + A` (conjugated), complex only.
pub fn gerc(
    comptime T: type,
    order: Order,
    m: usize,
    n: usize,
    alpha: T,
    x: []const T,
    incx: isize,
    y: []const T,
    incy: isize,
    a: []T,
    lda: usize,
) void {
    std.debug.assert(x.len >= vectorLen(m, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    std.debug.assert(a.len >= matrixLen(order, m, n, lda));
    switch (T) {
        Complex(f32) => c.cblas_cgerc(order, dim(m), dim(n), &alpha, x.ptr, inc(incx), y.ptr, inc(incy), a.ptr, dim(lda)),
        Complex(f64) => c.cblas_zgerc(order, dim(m), dim(n), &alpha, x.ptr, inc(incx), y.ptr, inc(incy), a.ptr, dim(lda)),
        else => unsupported(T, "gerc"),
    }
}

// ============================================================================
// Symmetric and Hermitian matrix-vector
// ============================================================================

/// `y := alpha * A * x + beta * y` for symmetric (real) or Hermitian
/// (complex) `A`, dense with leading dimension `lda`.
///
/// Dispatches to `ssymv`/`dsymv` for real types and `chemv`/`zhemv` for
/// complex ones, which is what "symmetric" means for each.
pub fn hemv(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    n: usize,
    alpha: T,
    a: []const T,
    lda: usize,
    x: []const T,
    incx: isize,
    beta: T,
    y: []T,
    incy: isize,
) void {
    std.debug.assert(a.len >= matrixLen(order, n, n, lda));
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    switch (T) {
        f32 => c.cblas_ssymv(order, uplo, dim(n), alpha, a.ptr, dim(lda), x.ptr, inc(incx), beta, y.ptr, inc(incy)),
        f64 => c.cblas_dsymv(order, uplo, dim(n), alpha, a.ptr, dim(lda), x.ptr, inc(incx), beta, y.ptr, inc(incy)),
        Complex(f32) => c.cblas_chemv(order, uplo, dim(n), &alpha, a.ptr, dim(lda), x.ptr, inc(incx), &beta, y.ptr, inc(incy)),
        Complex(f64) => c.cblas_zhemv(order, uplo, dim(n), &alpha, a.ptr, dim(lda), x.ptr, inc(incx), &beta, y.ptr, inc(incy)),
        else => unsupported(T, "hemv"),
    }
}

/// Alias for `hemv`, for callers working in real arithmetic where "symmetric"
/// is the natural word.
pub const symv = hemv;

/// Banded symmetric/Hermitian matrix-vector product with `k` off-diagonals.
pub fn hbmv(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    n: usize,
    k: usize,
    alpha: T,
    a: []const T,
    lda: usize,
    x: []const T,
    incx: isize,
    beta: T,
    y: []T,
    incy: isize,
) void {
    std.debug.assert(lda >= k + 1);
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    std.debug.assert(a.len >= (n - 1) * lda + k + 1 or n == 0);
    switch (T) {
        f32 => c.cblas_ssbmv(order, uplo, dim(n), dim(k), alpha, a.ptr, dim(lda), x.ptr, inc(incx), beta, y.ptr, inc(incy)),
        f64 => c.cblas_dsbmv(order, uplo, dim(n), dim(k), alpha, a.ptr, dim(lda), x.ptr, inc(incx), beta, y.ptr, inc(incy)),
        Complex(f32) => c.cblas_chbmv(order, uplo, dim(n), dim(k), &alpha, a.ptr, dim(lda), x.ptr, inc(incx), &beta, y.ptr, inc(incy)),
        Complex(f64) => c.cblas_zhbmv(order, uplo, dim(n), dim(k), &alpha, a.ptr, dim(lda), x.ptr, inc(incx), &beta, y.ptr, inc(incy)),
        else => unsupported(T, "hbmv"),
    }
}

pub const sbmv = hbmv;

/// Packed symmetric/Hermitian matrix-vector product. `ap` holds `n(n+1)/2`
/// elements.
pub fn hpmv(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    n: usize,
    alpha: T,
    ap: []const T,
    x: []const T,
    incx: isize,
    beta: T,
    y: []T,
    incy: isize,
) void {
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    switch (T) {
        f32 => c.cblas_sspmv(order, uplo, dim(n), alpha, ap.ptr, x.ptr, inc(incx), beta, y.ptr, inc(incy)),
        f64 => c.cblas_dspmv(order, uplo, dim(n), alpha, ap.ptr, x.ptr, inc(incx), beta, y.ptr, inc(incy)),
        Complex(f32) => c.cblas_chpmv(order, uplo, dim(n), &alpha, ap.ptr, x.ptr, inc(incx), &beta, y.ptr, inc(incy)),
        Complex(f64) => c.cblas_zhpmv(order, uplo, dim(n), &alpha, ap.ptr, x.ptr, inc(incx), &beta, y.ptr, inc(incy)),
        else => unsupported(T, "hpmv"),
    }
}

pub const spmv = hpmv;

// ============================================================================
// Symmetric / Hermitian rank updates
// ============================================================================

/// `A := alpha * x * x^H + A`, symmetric (real) or Hermitian (complex).
///
/// `alpha` is `Scalar(T)`, i.e. **real even for complex `A`** - a Hermitian
/// rank-1 update with a complex alpha would not stay Hermitian, which is why
/// `cher`/`zher` declare `const float ALPHA`.
pub fn her(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    n: usize,
    alpha: Scalar(T),
    x: []const T,
    incx: isize,
    a: []T,
    lda: usize,
) void {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(a.len >= matrixLen(order, n, n, lda));
    switch (T) {
        f32 => c.cblas_ssyr(order, uplo, dim(n), alpha, x.ptr, inc(incx), a.ptr, dim(lda)),
        f64 => c.cblas_dsyr(order, uplo, dim(n), alpha, x.ptr, inc(incx), a.ptr, dim(lda)),
        Complex(f32) => c.cblas_cher(order, uplo, dim(n), alpha, x.ptr, inc(incx), a.ptr, dim(lda)),
        Complex(f64) => c.cblas_zher(order, uplo, dim(n), alpha, x.ptr, inc(incx), a.ptr, dim(lda)),
        else => unsupported(T, "her"),
    }
}

pub const syr = her;

/// `A := alpha * x * y^H + conj(alpha) * y * x^H + A`.
pub fn her2(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    n: usize,
    alpha: T,
    x: []const T,
    incx: isize,
    y: []const T,
    incy: isize,
    a: []T,
    lda: usize,
) void {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    std.debug.assert(a.len >= matrixLen(order, n, n, lda));
    switch (T) {
        f32 => c.cblas_ssyr2(order, uplo, dim(n), alpha, x.ptr, inc(incx), y.ptr, inc(incy), a.ptr, dim(lda)),
        f64 => c.cblas_dsyr2(order, uplo, dim(n), alpha, x.ptr, inc(incx), y.ptr, inc(incy), a.ptr, dim(lda)),
        Complex(f32) => c.cblas_cher2(order, uplo, dim(n), &alpha, x.ptr, inc(incx), y.ptr, inc(incy), a.ptr, dim(lda)),
        Complex(f64) => c.cblas_zher2(order, uplo, dim(n), &alpha, x.ptr, inc(incx), y.ptr, inc(incy), a.ptr, dim(lda)),
        else => unsupported(T, "her2"),
    }
}

pub const syr2 = her2;

/// Packed rank-1 update. `alpha` is real for the same reason as in `her`.
pub fn hpr(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    n: usize,
    alpha: Scalar(T),
    x: []const T,
    incx: isize,
    ap: []T,
) void {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(ap.len >= packedLen(n));
    switch (T) {
        f32 => c.cblas_sspr(order, uplo, dim(n), alpha, x.ptr, inc(incx), ap.ptr),
        f64 => c.cblas_dspr(order, uplo, dim(n), alpha, x.ptr, inc(incx), ap.ptr),
        Complex(f32) => c.cblas_chpr(order, uplo, dim(n), alpha, x.ptr, inc(incx), ap.ptr),
        Complex(f64) => c.cblas_zhpr(order, uplo, dim(n), alpha, x.ptr, inc(incx), ap.ptr),
        else => unsupported(T, "hpr"),
    }
}

pub const spr = hpr;

/// Packed rank-2 update.
pub fn hpr2(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    n: usize,
    alpha: T,
    x: []const T,
    incx: isize,
    y: []const T,
    incy: isize,
    ap: []T,
) void {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    std.debug.assert(ap.len >= packedLen(n));
    switch (T) {
        f32 => c.cblas_sspr2(order, uplo, dim(n), alpha, x.ptr, inc(incx), y.ptr, inc(incy), ap.ptr),
        f64 => c.cblas_dspr2(order, uplo, dim(n), alpha, x.ptr, inc(incx), y.ptr, inc(incy), ap.ptr),
        Complex(f32) => c.cblas_chpr2(order, uplo, dim(n), &alpha, x.ptr, inc(incx), y.ptr, inc(incy), ap.ptr),
        Complex(f64) => c.cblas_zhpr2(order, uplo, dim(n), &alpha, x.ptr, inc(incx), y.ptr, inc(incy), ap.ptr),
        else => unsupported(T, "hpr2"),
    }
}

pub const spr2 = hpr2;

// ============================================================================
// Triangular matrix-vector: multiply and solve
// ============================================================================

/// `x := op(A) * x`, `A` triangular `n x n`.
pub fn trmv(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    trans: Transpose,
    diag: Diag,
    n: usize,
    a: []const T,
    lda: usize,
    x: []T,
    incx: isize,
) void {
    std.debug.assert(a.len >= matrixLen(order, n, n, lda));
    std.debug.assert(x.len >= vectorLen(n, incx));
    switch (T) {
        f32 => c.cblas_strmv(order, uplo, trans, diag, dim(n), a.ptr, dim(lda), x.ptr, inc(incx)),
        f64 => c.cblas_dtrmv(order, uplo, trans, diag, dim(n), a.ptr, dim(lda), x.ptr, inc(incx)),
        Complex(f32) => c.cblas_ctrmv(order, uplo, trans, diag, dim(n), a.ptr, dim(lda), x.ptr, inc(incx)),
        Complex(f64) => c.cblas_ztrmv(order, uplo, trans, diag, dim(n), a.ptr, dim(lda), x.ptr, inc(incx)),
        else => unsupported(T, "trmv"),
    }
}

/// Solves `op(A) * x = b` in place, `A` triangular `n x n`. `x` holds `b` on
/// entry.
///
/// No singularity check: BLAS assumes `A` is non-singular, and a zero on the
/// diagonal produces infinities rather than an error.
pub fn trsv(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    trans: Transpose,
    diag: Diag,
    n: usize,
    a: []const T,
    lda: usize,
    x: []T,
    incx: isize,
) void {
    std.debug.assert(a.len >= matrixLen(order, n, n, lda));
    std.debug.assert(x.len >= vectorLen(n, incx));
    switch (T) {
        f32 => c.cblas_strsv(order, uplo, trans, diag, dim(n), a.ptr, dim(lda), x.ptr, inc(incx)),
        f64 => c.cblas_dtrsv(order, uplo, trans, diag, dim(n), a.ptr, dim(lda), x.ptr, inc(incx)),
        Complex(f32) => c.cblas_ctrsv(order, uplo, trans, diag, dim(n), a.ptr, dim(lda), x.ptr, inc(incx)),
        Complex(f64) => c.cblas_ztrsv(order, uplo, trans, diag, dim(n), a.ptr, dim(lda), x.ptr, inc(incx)),
        else => unsupported(T, "trsv"),
    }
}

/// Banded triangular multiply with `k` off-diagonals.
pub fn tbmv(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    trans: Transpose,
    diag: Diag,
    n: usize,
    k: usize,
    a: []const T,
    lda: usize,
    x: []T,
    incx: isize,
) void {
    std.debug.assert(lda >= k + 1);
    std.debug.assert(x.len >= vectorLen(n, incx));
    switch (T) {
        f32 => c.cblas_stbmv(order, uplo, trans, diag, dim(n), dim(k), a.ptr, dim(lda), x.ptr, inc(incx)),
        f64 => c.cblas_dtbmv(order, uplo, trans, diag, dim(n), dim(k), a.ptr, dim(lda), x.ptr, inc(incx)),
        Complex(f32) => c.cblas_ctbmv(order, uplo, trans, diag, dim(n), dim(k), a.ptr, dim(lda), x.ptr, inc(incx)),
        Complex(f64) => c.cblas_ztbmv(order, uplo, trans, diag, dim(n), dim(k), a.ptr, dim(lda), x.ptr, inc(incx)),
        else => unsupported(T, "tbmv"),
    }
}

/// Banded triangular solve with `k` off-diagonals.
pub fn tbsv(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    trans: Transpose,
    diag: Diag,
    n: usize,
    k: usize,
    a: []const T,
    lda: usize,
    x: []T,
    incx: isize,
) void {
    std.debug.assert(lda >= k + 1);
    std.debug.assert(x.len >= vectorLen(n, incx));
    switch (T) {
        f32 => c.cblas_stbsv(order, uplo, trans, diag, dim(n), dim(k), a.ptr, dim(lda), x.ptr, inc(incx)),
        f64 => c.cblas_dtbsv(order, uplo, trans, diag, dim(n), dim(k), a.ptr, dim(lda), x.ptr, inc(incx)),
        Complex(f32) => c.cblas_ctbsv(order, uplo, trans, diag, dim(n), dim(k), a.ptr, dim(lda), x.ptr, inc(incx)),
        Complex(f64) => c.cblas_ztbsv(order, uplo, trans, diag, dim(n), dim(k), a.ptr, dim(lda), x.ptr, inc(incx)),
        else => unsupported(T, "tbsv"),
    }
}

/// Packed triangular multiply. `ap` holds `n(n+1)/2` elements.
pub fn tpmv(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    trans: Transpose,
    diag: Diag,
    n: usize,
    ap: []const T,
    x: []T,
    incx: isize,
) void {
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(x.len >= vectorLen(n, incx));
    switch (T) {
        f32 => c.cblas_stpmv(order, uplo, trans, diag, dim(n), ap.ptr, x.ptr, inc(incx)),
        f64 => c.cblas_dtpmv(order, uplo, trans, diag, dim(n), ap.ptr, x.ptr, inc(incx)),
        Complex(f32) => c.cblas_ctpmv(order, uplo, trans, diag, dim(n), ap.ptr, x.ptr, inc(incx)),
        Complex(f64) => c.cblas_ztpmv(order, uplo, trans, diag, dim(n), ap.ptr, x.ptr, inc(incx)),
        else => unsupported(T, "tpmv"),
    }
}

/// Packed triangular solve.
pub fn tpsv(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    trans: Transpose,
    diag: Diag,
    n: usize,
    ap: []const T,
    x: []T,
    incx: isize,
) void {
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(x.len >= vectorLen(n, incx));
    switch (T) {
        f32 => c.cblas_stpsv(order, uplo, trans, diag, dim(n), ap.ptr, x.ptr, inc(incx)),
        f64 => c.cblas_dtpsv(order, uplo, trans, diag, dim(n), ap.ptr, x.ptr, inc(incx)),
        Complex(f32) => c.cblas_ctpsv(order, uplo, trans, diag, dim(n), ap.ptr, x.ptr, inc(incx)),
        Complex(f64) => c.cblas_ztpsv(order, uplo, trans, diag, dim(n), ap.ptr, x.ptr, inc(incx)),
        else => unsupported(T, "tpsv"),
    }
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const C64 = Complex(f64);

test "gemv computes A*x and A^T*x for a non-square matrix" {
    // A = [[1,2,3],[4,5,6]] row-major, 2x3.
    const a = [_]f64{ 1, 2, 3, 4, 5, 6 };

    // A * [1,1,1] = [6, 15]
    var y = [_]f64{ 0, 0 };
    gemv(f64, .row_major, .no_trans, 2, 3, 1, &a, 3, &.{ 1, 1, 1 }, 1, 0, &y, 1);
    try testing.expectEqualSlices(f64, &.{ 6, 15 }, &y);

    // A^T * [1,1] = [5, 7, 9]
    var yt = [_]f64{ 0, 0, 0 };
    gemv(f64, .row_major, .trans, 2, 3, 1, &a, 3, &.{ 1, 1 }, 1, 0, &yt, 1);
    try testing.expectEqualSlices(f64, &.{ 5, 7, 9 }, &yt);
}

test "row-major and column-major describe the same matrix" {
    // Same 2x3 matrix in both layouts.
    const row = [_]f64{ 1, 2, 3, 4, 5, 6 };
    const col = [_]f64{ 1, 4, 2, 5, 3, 6 };
    const x = [_]f64{ 1, 2, 3 };

    var yr = [_]f64{ 0, 0 };
    var yc = [_]f64{ 0, 0 };
    gemv(f64, .row_major, .no_trans, 2, 3, 1, &row, 3, &x, 1, 0, &yr, 1);
    gemv(f64, .col_major, .no_trans, 2, 3, 1, &col, 2, &x, 1, 0, &yc, 1);
    try testing.expectEqualSlices(f64, &yr, &yc);
}

test "gemv accumulates into y with beta" {
    const a = [_]f64{ 1, 0, 0, 1 };
    var y = [_]f64{ 10, 20 };
    gemv(f64, .row_major, .no_trans, 2, 2, 2, &a, 2, &.{ 1, 1 }, 1, 3, &y, 1);
    // 2*I*[1,1] + 3*[10,20] = [32, 62]
    try testing.expectEqualSlices(f64, &.{ 32, 62 }, &y);
}

test "gemv with a leading dimension larger than the row length" {
    // 2x2 matrix embedded in a 2x4 buffer; the padding must be ignored.
    const a = [_]f64{ 1, 2, 99, 99, 3, 4, 99, 99 };
    var y = [_]f64{ 0, 0 };
    gemv(f64, .row_major, .no_trans, 2, 2, 1, &a, 4, &.{ 1, 1 }, 1, 0, &y, 1);
    try testing.expectEqualSlices(f64, &.{ 3, 7 }, &y);
}

test "complex gemv passes alpha and beta by pointer correctly" {
    // A = [[i]], x = [1], alpha = 2, beta = 0 -> y = 2i
    const a = [_]C64{.init(0, 1)};
    const x = [_]C64{.init(1, 0)};
    var y = [_]C64{.init(9, 9)};
    gemv(C64, .row_major, .no_trans, 1, 1, .init(2, 0), &a, 1, &x, 1, C64.zero, &y, 1);
    try testing.expect(y[0].eqlApprox(.init(0, 2), 1e-12));
}

test "ger performs a rank-1 update" {
    var a = [_]f64{ 0, 0, 0, 0, 0, 0 };
    // [1,2] outer [10,20,30] = [[10,20,30],[20,40,60]]
    ger(f64, .row_major, 2, 3, 1, &.{ 1, 2 }, 1, &.{ 10, 20, 30 }, 1, &a, 3);
    try testing.expectEqualSlices(f64, &.{ 10, 20, 30, 20, 40, 60 }, &a);
}

test "geru and gerc differ by conjugation of y" {
    const x = [_]C64{.init(1, 0)};
    const y = [_]C64{.init(0, 1)};

    var au = [_]C64{C64.zero};
    geru(C64, .row_major, 1, 1, .init(1, 0), &x, 1, &y, 1, &au, 1);
    try testing.expect(au[0].eqlApprox(.init(0, 1), 1e-12));

    var ac = [_]C64{C64.zero};
    gerc(C64, .row_major, 1, 1, .init(1, 0), &x, 1, &y, 1, &ac, 1);
    try testing.expect(ac[0].eqlApprox(.init(0, -1), 1e-12));
}

test "symv reads only the referenced triangle" {
    // Upper triangle says [[2,1],[.,3]]; the lower entry is poisoned to prove
    // it is never read.
    const a = [_]f64{ 2, 1, -999, 3 };
    var y = [_]f64{ 0, 0 };
    symv(f64, .row_major, .upper, 2, 1, &a, 2, &.{ 1, 1 }, 1, 0, &y, 1);
    // Full symmetric matrix is [[2,1],[1,3]], so y = [3, 4].
    try testing.expectEqualSlices(f64, &.{ 3, 4 }, &y);
}

test "hemv treats the complex matrix as Hermitian" {
    // A = [[2, 1+i], [1-i, 3]] is Hermitian; store the upper triangle.
    const a = [_]C64{ .init(2, 0), .init(1, 1), .init(-999, -999), .init(3, 0) };
    const x = [_]C64{ .init(1, 0), .init(1, 0) };
    var y = [_]C64{ C64.zero, C64.zero };
    hemv(C64, .row_major, .upper, 2, .init(1, 0), &a, 2, &x, 1, C64.zero, &y, 1);

    // y = [2 + (1+i), (1-i) + 3] = [3+i, 4-i]
    try testing.expect(y[0].eqlApprox(.init(3, 1), 1e-12));
    try testing.expect(y[1].eqlApprox(.init(4, -1), 1e-12));
}

test "her takes a real alpha and keeps the matrix Hermitian" {
    // A Hermitian rank-1 update with a complex alpha would break the
    // Hermitian property, which is why cher/zher declare a real ALPHA.
    var a = [_]C64{ C64.zero, C64.zero, C64.zero, C64.zero };
    const x = [_]C64{ .init(1, 1), .init(2, 0) };
    her(C64, .row_major, .upper, 2, 1.0, &x, 1, &a, 2);

    // Diagonal of x x^H is |x_i|^2, which must come out real.
    try testing.expectApproxEqAbs(@as(f64, 2), a[0].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), a[0].im, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 4), a[3].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), a[3].im, 1e-12);
    // Off-diagonal x_0 * conj(x_1) = (1+i)*2 = 2+2i
    try testing.expect(a[1].eqlApprox(.init(2, 2), 1e-12));
}

test "syr and syr2 update a real symmetric matrix" {
    var a = [_]f64{ 0, 0, 0, 0 };
    syr(f64, .row_major, .upper, 2, 2, &.{ 1, 3 }, 1, &a, 2);
    // 2 * [1,3] outer [1,3], upper triangle only.
    try testing.expectApproxEqAbs(@as(f64, 2), a[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 6), a[1], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 18), a[3], 1e-12);

    var b = [_]f64{ 0, 0, 0, 0 };
    syr2(f64, .row_major, .upper, 2, 1, &.{ 1, 0 }, 1, &.{ 0, 1 }, 1, &b, 2);
    // x y^T + y x^T has 1 in both off-diagonal slots; only upper is written.
    try testing.expectApproxEqAbs(@as(f64, 1), b[1], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), b[0], 1e-12);
}

test "packed and dense symmetric products agree" {
    // A = [[1,2,3],[2,4,5],[3,5,6]], upper triangle.
    const dense = [_]f64{ 1, 2, 3, -999, 4, 5, -999, -999, 6 };
    // Column-major packed upper walks the columns: (a00), (a01,a11),
    // (a02,a12,a22) - not the row-major order the dense array above uses.
    const packed_upper = [_]f64{ 1, 2, 4, 3, 5, 6 };
    const x = [_]f64{ 1, 1, 1 };

    var yd = [_]f64{ 0, 0, 0 };
    var yp = [_]f64{ 0, 0, 0 };
    symv(f64, .row_major, .upper, 3, 1, &dense, 3, &x, 1, 0, &yd, 1);
    spmv(f64, .col_major, .upper, 3, 1, &packed_upper, &x, 1, 0, &yp, 1);

    for (yd, yp) |a, b| try testing.expectApproxEqAbs(a, b, 1e-12);
    // A * [1,1,1] sums each row of the full symmetric matrix.
    try testing.expectEqualSlices(f64, &.{ 6, 11, 14 }, &yd);
}

test "trmv then trsv is the identity" {
    // Upper triangular [[2,1],[0,3]].
    const a = [_]f64{ 2, 1, 0, 3 };
    const original = [_]f64{ 5, 7 };
    var x = original;

    trmv(f64, .row_major, .upper, .no_trans, .non_unit, 2, &a, 2, &x, 1);
    try testing.expectEqualSlices(f64, &.{ 2 * 5 + 7, 3 * 7 }, &x);

    trsv(f64, .row_major, .upper, .no_trans, .non_unit, 2, &a, 2, &x, 1);
    for (original, x) |want, got| try testing.expectApproxEqAbs(want, got, 1e-12);
}

test "a unit diagonal ignores the stored diagonal entries" {
    // The diagonal is poisoned; .unit must mean it is never read.
    const a = [_]f64{ -999, 1, 0, -999 };
    var x = [_]f64{ 1, 1 };
    trmv(f64, .row_major, .upper, .no_trans, .unit, 2, &a, 2, &x, 1);
    // Implicit [[1,1],[0,1]] * [1,1] = [2, 1]
    try testing.expectEqualSlices(f64, &.{ 2, 1 }, &x);
}

test "packed triangular solve matches the dense one" {
    // Upper triangular [[2,1],[0,4]] dense and packed (column-major upper).
    const dense = [_]f64{ 2, 1, 0, 4 };
    const ap = [_]f64{ 2, 1, 4 };

    var xd = [_]f64{ 4, 8 };
    var xp = [_]f64{ 4, 8 };
    trsv(f64, .row_major, .upper, .no_trans, .non_unit, 2, &dense, 2, &xd, 1);
    tpsv(f64, .col_major, .upper, .no_trans, .non_unit, 2, &ap, &xp, 1);

    for (xd, xp) |a, b| try testing.expectApproxEqAbs(a, b, 1e-12);
    // A x = [4, 8] with x = [1, 2].
    try testing.expectApproxEqAbs(@as(f64, 1), xd[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2), xd[1], 1e-12);
}

test "banded and dense products agree for a tridiagonal matrix" {
    // Symmetric tridiagonal [[2,1,0],[1,2,1],[0,1,2]], k = 1.
    // Column-major banded upper storage: lda = k+1 = 2.
    const banded = [_]f64{ -999, 2, 1, 2, 1, 2 };
    const dense = [_]f64{ 2, 1, 0, 1, 2, 1, 0, 1, 2 };
    const x = [_]f64{ 1, 2, 3 };

    var yb = [_]f64{ 0, 0, 0 };
    var yd = [_]f64{ 0, 0, 0 };
    sbmv(f64, .col_major, .upper, 3, 1, 1, &banded, 2, &x, 1, 0, &yb, 1);
    gemv(f64, .col_major, .no_trans, 3, 3, 1, &dense, 3, &x, 1, 0, &yd, 1);

    for (yd, yb) |a, b| try testing.expectApproxEqAbs(a, b, 1e-12);
}

test "gbmv matches gemv for a banded matrix stored both ways" {
    // 3x3 with kl = 1, ku = 1: [[1,2,0],[3,4,5],[0,6,7]]
    const dense = [_]f64{ 1, 3, 0, 2, 4, 6, 0, 5, 7 }; // column-major
    // Banded column-major: lda = kl+ku+1 = 3, each column holds ku..kl.
    const banded = [_]f64{ -999, 1, 3, 2, 4, 6, 5, 7, -999 };
    const x = [_]f64{ 1, 1, 1 };

    var yd = [_]f64{ 0, 0, 0 };
    var yb = [_]f64{ 0, 0, 0 };
    gemv(f64, .col_major, .no_trans, 3, 3, 1, &dense, 3, &x, 1, 0, &yd, 1);
    gbmv(f64, .col_major, .no_trans, 3, 3, 1, 1, 1, &banded, 3, &x, 1, 0, &yb, 1);

    for (yd, yb) |a, b| try testing.expectApproxEqAbs(a, b, 1e-12);
}
