//! BLAS Level 1: vector-vector operations.
//!
//! Each operation comes in two forms:
//!
//! * A **unit-stride** form taking slices, where the element count is the
//!   slice length. This is what most callers want.
//! * A **strided** form (`...Strided`) taking an explicit `n` and increments,
//!   which is the full BLAS interface. A negative increment traverses the
//!   vector backwards - BLAS allows it, and `types.vectorLen` accounts for it
//!   when checking the slice is long enough.
//!
//! `T` is `f32`, `f64`, `Complex(f32)` or `Complex(f64)` unless a specific
//! operation says otherwise.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");

const Complex = types.Complex;
const Scalar = types.Scalar;
const dim = types.dim;
const inc = types.inc;
const vectorLen = types.vectorLen;

fn unsupported(comptime T: type, comptime op: []const u8) noreturn {
    @compileError(op ++ " is not defined for " ++ @typeName(T));
}

// ============================================================================
// asum, nrm2, amax
// ============================================================================

/// Sum of absolute values. For complex input this is `sum(|re| + |im|)` -
/// note that this is BLAS's definition, not the sum of moduli.
pub fn asumStrided(comptime T: type, n: usize, x: []const T, incx: isize) Scalar(T) {
    std.debug.assert(x.len >= vectorLen(n, incx));
    const p = x.ptr;
    return switch (T) {
        f32 => c.cblas_sasum(dim(n), p, inc(incx)),
        f64 => c.cblas_dasum(dim(n), p, inc(incx)),
        Complex(f32) => c.cblas_scasum(dim(n), p, inc(incx)),
        Complex(f64) => c.cblas_dzasum(dim(n), p, inc(incx)),
        else => unsupported(T, "asum"),
    };
}

pub fn asum(comptime T: type, x: []const T) Scalar(T) {
    return asumStrided(T, x.len, x, 1);
}

/// Euclidean norm. Unlike `asum`, this is the true 2-norm for complex input.
pub fn nrm2Strided(comptime T: type, n: usize, x: []const T, incx: isize) Scalar(T) {
    std.debug.assert(x.len >= vectorLen(n, incx));
    const p = x.ptr;
    return switch (T) {
        f32 => c.cblas_snrm2(dim(n), p, inc(incx)),
        f64 => c.cblas_dnrm2(dim(n), p, inc(incx)),
        Complex(f32) => c.cblas_scnrm2(dim(n), p, inc(incx)),
        Complex(f64) => c.cblas_dznrm2(dim(n), p, inc(incx)),
        else => unsupported(T, "nrm2"),
    };
}

pub fn nrm2(comptime T: type, x: []const T) Scalar(T) {
    return nrm2Strided(T, x.len, x, 1);
}

/// Index of the first element with the largest absolute value.
///
/// Returned as a **0-based** index, unlike the Fortran-derived C routine which
/// is also 0-based in CBLAS but 1-based in the reference BLAS - a classic
/// source of off-by-one. `null` for an empty vector, where BLAS returns 0 and
/// gives no way to distinguish "empty" from "first element".
pub fn iamaxStrided(comptime T: type, n: usize, x: []const T, incx: isize) ?usize {
    if (n == 0) return null;
    std.debug.assert(x.len >= vectorLen(n, incx));
    const p = x.ptr;
    const i = switch (T) {
        f32 => c.cblas_isamax(dim(n), p, inc(incx)),
        f64 => c.cblas_idamax(dim(n), p, inc(incx)),
        Complex(f32) => c.cblas_icamax(dim(n), p, inc(incx)),
        Complex(f64) => c.cblas_izamax(dim(n), p, inc(incx)),
        else => unsupported(T, "iamax"),
    };
    return @intCast(i);
}

pub fn iamax(comptime T: type, x: []const T) ?usize {
    return iamaxStrided(T, x.len, x, 1);
}

// ============================================================================
// dot products
// ============================================================================

/// Real dot product `x . y`. Real types only; complex has `dotu`/`dotc`.
pub fn dotStrided(comptime T: type, n: usize, x: []const T, incx: isize, y: []const T, incy: isize) T {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    return switch (T) {
        f32 => c.cblas_sdot(dim(n), x.ptr, inc(incx), y.ptr, inc(incy)),
        f64 => c.cblas_ddot(dim(n), x.ptr, inc(incx), y.ptr, inc(incy)),
        else => unsupported(T, "dot"),
    };
}

pub fn dot(comptime T: type, x: []const T, y: []const T) T {
    std.debug.assert(x.len == y.len);
    return dotStrided(T, x.len, x, 1, y, 1);
}

/// `f32` dot product accumulated in `f64`, plus `alpha`. More accurate than
/// `dot(f32, ...)` for long vectors.
pub fn sdsdotStrided(n: usize, alpha: f32, x: []const f32, incx: isize, y: []const f32, incy: isize) f32 {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    return c.cblas_sdsdot(dim(n), alpha, x.ptr, inc(incx), y.ptr, inc(incy));
}

pub fn sdsdot(alpha: f32, x: []const f32, y: []const f32) f32 {
    std.debug.assert(x.len == y.len);
    return sdsdotStrided(x.len, alpha, x, 1, y, 1);
}

/// `f32` dot product accumulated and returned in `f64`.
pub fn dsdotStrided(n: usize, x: []const f32, incx: isize, y: []const f32, incy: isize) f64 {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    return c.cblas_dsdot(dim(n), x.ptr, inc(incx), y.ptr, inc(incy));
}

pub fn dsdot(x: []const f32, y: []const f32) f64 {
    std.debug.assert(x.len == y.len);
    return dsdotStrided(x.len, x, 1, y, 1);
}

/// Unconjugated complex dot product `sum(x_i * y_i)`.
///
/// CBLAS returns this through an out-parameter (`cblas_cdotu_sub`); the value
/// is returned directly here.
pub fn dotuStrided(comptime T: type, n: usize, x: []const T, incx: isize, y: []const T, incy: isize) T {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    var result: T = T.zero;
    switch (T) {
        Complex(f32) => c.cblas_cdotu_sub(dim(n), x.ptr, inc(incx), y.ptr, inc(incy), &result),
        Complex(f64) => c.cblas_zdotu_sub(dim(n), x.ptr, inc(incx), y.ptr, inc(incy), &result),
        else => unsupported(T, "dotu"),
    }
    return result;
}

pub fn dotu(comptime T: type, x: []const T, y: []const T) T {
    std.debug.assert(x.len == y.len);
    return dotuStrided(T, x.len, x, 1, y, 1);
}

/// Conjugated complex dot product `sum(conj(x_i) * y_i)`.
pub fn dotcStrided(comptime T: type, n: usize, x: []const T, incx: isize, y: []const T, incy: isize) T {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    var result: T = T.zero;
    switch (T) {
        Complex(f32) => c.cblas_cdotc_sub(dim(n), x.ptr, inc(incx), y.ptr, inc(incy), &result),
        Complex(f64) => c.cblas_zdotc_sub(dim(n), x.ptr, inc(incx), y.ptr, inc(incy), &result),
        else => unsupported(T, "dotc"),
    }
    return result;
}

pub fn dotc(comptime T: type, x: []const T, y: []const T) T {
    std.debug.assert(x.len == y.len);
    return dotcStrided(T, x.len, x, 1, y, 1);
}

// ============================================================================
// axpy, axpby, copy, swap, scal, set
// ============================================================================

/// `y := alpha * x + y`.
pub fn axpyStrided(comptime T: type, n: usize, alpha: T, x: []const T, incx: isize, y: []T, incy: isize) void {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    switch (T) {
        f32 => c.cblas_saxpy(dim(n), alpha, x.ptr, inc(incx), y.ptr, inc(incy)),
        f64 => c.cblas_daxpy(dim(n), alpha, x.ptr, inc(incx), y.ptr, inc(incy)),
        Complex(f32) => c.cblas_caxpy(dim(n), &alpha, x.ptr, inc(incx), y.ptr, inc(incy)),
        Complex(f64) => c.cblas_zaxpy(dim(n), &alpha, x.ptr, inc(incx), y.ptr, inc(incy)),
        else => unsupported(T, "axpy"),
    }
}

pub fn axpy(comptime T: type, alpha: T, x: []const T, y: []T) void {
    std.debug.assert(x.len == y.len);
    axpyStrided(T, x.len, alpha, x, 1, y, 1);
}

/// `y := alpha * x + beta * y`. An Apple/ATLAS extension, not standard BLAS.
pub fn axpbyStrided(comptime T: type, n: usize, alpha: T, x: []const T, incx: isize, beta: T, y: []T, incy: isize) void {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    switch (T) {
        f32 => c.catlas_saxpby(dim(n), alpha, x.ptr, inc(incx), beta, y.ptr, inc(incy)),
        f64 => c.catlas_daxpby(dim(n), alpha, x.ptr, inc(incx), beta, y.ptr, inc(incy)),
        Complex(f32) => c.catlas_caxpby(dim(n), &alpha, x.ptr, inc(incx), &beta, y.ptr, inc(incy)),
        Complex(f64) => c.catlas_zaxpby(dim(n), &alpha, x.ptr, inc(incx), &beta, y.ptr, inc(incy)),
        else => unsupported(T, "axpby"),
    }
}

pub fn axpby(comptime T: type, alpha: T, x: []const T, beta: T, y: []T) void {
    std.debug.assert(x.len == y.len);
    axpbyStrided(T, x.len, alpha, x, 1, beta, y, 1);
}

/// `y := x`.
pub fn copyStrided(comptime T: type, n: usize, x: []const T, incx: isize, y: []T, incy: isize) void {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    switch (T) {
        f32 => c.cblas_scopy(dim(n), x.ptr, inc(incx), y.ptr, inc(incy)),
        f64 => c.cblas_dcopy(dim(n), x.ptr, inc(incx), y.ptr, inc(incy)),
        Complex(f32) => c.cblas_ccopy(dim(n), x.ptr, inc(incx), y.ptr, inc(incy)),
        Complex(f64) => c.cblas_zcopy(dim(n), x.ptr, inc(incx), y.ptr, inc(incy)),
        else => unsupported(T, "copy"),
    }
}

pub fn copy(comptime T: type, x: []const T, y: []T) void {
    std.debug.assert(x.len == y.len);
    copyStrided(T, x.len, x, 1, y, 1);
}

/// Exchanges `x` and `y`.
pub fn swapStrided(comptime T: type, n: usize, x: []T, incx: isize, y: []T, incy: isize) void {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    switch (T) {
        f32 => c.cblas_sswap(dim(n), x.ptr, inc(incx), y.ptr, inc(incy)),
        f64 => c.cblas_dswap(dim(n), x.ptr, inc(incx), y.ptr, inc(incy)),
        Complex(f32) => c.cblas_cswap(dim(n), x.ptr, inc(incx), y.ptr, inc(incy)),
        Complex(f64) => c.cblas_zswap(dim(n), x.ptr, inc(incx), y.ptr, inc(incy)),
        else => unsupported(T, "swap"),
    }
}

pub fn swap(comptime T: type, x: []T, y: []T) void {
    std.debug.assert(x.len == y.len);
    swapStrided(T, x.len, x, 1, y, 1);
}

/// `x := alpha * x`.
pub fn scalStrided(comptime T: type, n: usize, alpha: T, x: []T, incx: isize) void {
    std.debug.assert(x.len >= vectorLen(n, incx));
    switch (T) {
        f32 => c.cblas_sscal(dim(n), alpha, x.ptr, inc(incx)),
        f64 => c.cblas_dscal(dim(n), alpha, x.ptr, inc(incx)),
        Complex(f32) => c.cblas_cscal(dim(n), &alpha, x.ptr, inc(incx)),
        Complex(f64) => c.cblas_zscal(dim(n), &alpha, x.ptr, inc(incx)),
        else => unsupported(T, "scal"),
    }
}

pub fn scal(comptime T: type, alpha: T, x: []T) void {
    scalStrided(T, x.len, alpha, x, 1);
}

/// Scales a complex vector by a **real** scalar (`csscal` / `zdscal`).
///
/// Cheaper than `scal` with a complex `alpha` whose imaginary part is zero.
pub fn scalRealStrided(comptime T: type, n: usize, alpha: Scalar(T), x: []T, incx: isize) void {
    std.debug.assert(x.len >= vectorLen(n, incx));
    switch (T) {
        Complex(f32) => c.cblas_csscal(dim(n), alpha, x.ptr, inc(incx)),
        Complex(f64) => c.cblas_zdscal(dim(n), alpha, x.ptr, inc(incx)),
        else => unsupported(T, "scalReal"),
    }
}

pub fn scalReal(comptime T: type, alpha: Scalar(T), x: []T) void {
    scalRealStrided(T, x.len, alpha, x, 1);
}

/// Fills `x` with `alpha`. An Apple/ATLAS extension, not standard BLAS.
pub fn setStrided(comptime T: type, n: usize, alpha: T, x: []T, incx: isize) void {
    std.debug.assert(x.len >= vectorLen(n, incx));
    switch (T) {
        f32 => c.catlas_sset(dim(n), alpha, x.ptr, inc(incx)),
        f64 => c.catlas_dset(dim(n), alpha, x.ptr, inc(incx)),
        Complex(f32) => c.catlas_cset(dim(n), &alpha, x.ptr, inc(incx)),
        Complex(f64) => c.catlas_zset(dim(n), &alpha, x.ptr, inc(incx)),
        else => unsupported(T, "set"),
    }
}

pub fn set(comptime T: type, alpha: T, x: []T) void {
    setStrided(T, x.len, alpha, x, 1);
}

// ============================================================================
// Givens rotations
// ============================================================================

/// Generates a Givens rotation that zeroes `b`.
///
/// All four arguments are in/out: on return `a` holds `r`, `b` holds `z`, and
/// `cosine`/`sine` hold the rotation. Real types only - see `rotgComplex`.
pub fn rotg(comptime T: type, a: *T, b: *T, cosine: *T, sine: *T) void {
    switch (T) {
        f32 => c.cblas_srotg(a, b, cosine, sine),
        f64 => c.cblas_drotg(a, b, cosine, sine),
        else => unsupported(T, "rotg"),
    }
}

/// Complex Givens generator. `cosine` is real, `sine` is complex.
pub fn rotgComplex(comptime T: type, a: *T, b: *T, cosine: *Scalar(T), sine: *T) void {
    switch (T) {
        Complex(f32) => c.cblas_crotg(a, b, cosine, sine),
        Complex(f64) => c.cblas_zrotg(a, b, cosine, sine),
        else => unsupported(T, "rotgComplex"),
    }
}

/// Applies a Givens rotation to a pair of vectors.
pub fn rotStrided(comptime T: type, n: usize, x: []T, incx: isize, y: []T, incy: isize, cosine: T, sine: T) void {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    switch (T) {
        f32 => c.cblas_srot(dim(n), x.ptr, inc(incx), y.ptr, inc(incy), cosine, sine),
        f64 => c.cblas_drot(dim(n), x.ptr, inc(incx), y.ptr, inc(incy), cosine, sine),
        else => unsupported(T, "rot"),
    }
}

pub fn rot(comptime T: type, x: []T, y: []T, cosine: T, sine: T) void {
    std.debug.assert(x.len == y.len);
    rotStrided(T, x.len, x, 1, y, 1, cosine, sine);
}

/// Applies a **real** Givens rotation to a pair of complex vectors
/// (`csrot` / `zdrot`).
pub fn rotComplexStrided(comptime T: type, n: usize, x: []T, incx: isize, y: []T, incy: isize, cosine: Scalar(T), sine: Scalar(T)) void {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    switch (T) {
        Complex(f32) => c.cblas_csrot(dim(n), x.ptr, inc(incx), y.ptr, inc(incy), cosine, sine),
        Complex(f64) => c.cblas_zdrot(dim(n), x.ptr, inc(incx), y.ptr, inc(incy), cosine, sine),
        else => unsupported(T, "rotComplex"),
    }
}

pub fn rotComplex(comptime T: type, x: []T, y: []T, cosine: Scalar(T), sine: Scalar(T)) void {
    std.debug.assert(x.len == y.len);
    rotComplexStrided(T, x.len, x, 1, y, 1, cosine, sine);
}

/// Generates a modified (Givens) rotation. `param` is the 5-element `P` array
/// the reference BLAS uses; `param[0]` is the flag.
pub fn rotmg(comptime T: type, d1: *T, d2: *T, b1: *T, b2: T, param: *[5]T) void {
    switch (T) {
        f32 => c.cblas_srotmg(d1, d2, b1, b2, param),
        f64 => c.cblas_drotmg(d1, d2, b1, b2, param),
        else => unsupported(T, "rotmg"),
    }
}

/// Applies a modified Givens rotation.
pub fn rotmStrided(comptime T: type, n: usize, x: []T, incx: isize, y: []T, incy: isize, param: *const [5]T) void {
    std.debug.assert(x.len >= vectorLen(n, incx));
    std.debug.assert(y.len >= vectorLen(n, incy));
    switch (T) {
        f32 => c.cblas_srotm(dim(n), x.ptr, inc(incx), y.ptr, inc(incy), param),
        f64 => c.cblas_drotm(dim(n), x.ptr, inc(incx), y.ptr, inc(incy), param),
        else => unsupported(T, "rotm"),
    }
}

pub fn rotm(comptime T: type, x: []T, y: []T, param: *const [5]T) void {
    std.debug.assert(x.len == y.len);
    rotmStrided(T, x.len, x, 1, y, 1, param);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const C32 = Complex(f32);
const C64 = Complex(f64);

fn tol(comptime T: type) Scalar(T) {
    return if (Scalar(T) == f64) 1e-12 else 1e-5;
}

test "asum sums absolute values, and for complex sums |re| + |im|" {
    try testing.expectApproxEqAbs(@as(f32, 10), asum(f32, &.{ 1, -2, 3, -4 }), 1e-6);
    try testing.expectApproxEqAbs(@as(f64, 10), asum(f64, &.{ 1, -2, 3, -4 }), 1e-12);

    // BLAS's complex asum is sum(|re| + |im|), NOT sum(|z|): here that is
    // (3 + 4) + (1 + 1) = 9, where the sum of moduli would be 5 + sqrt(2).
    const z = [_]C64{ .init(3, -4), .init(-1, 1) };
    try testing.expectApproxEqAbs(@as(f64, 9), asum(C64, &z), 1e-12);
}

test "nrm2 is the true Euclidean norm for both real and complex" {
    try testing.expectApproxEqAbs(@as(f64, 5), nrm2(f64, &.{ 3, 4 }), 1e-12);
    const z = [_]C64{.init(3, 4)};
    try testing.expectApproxEqAbs(@as(f64, 5), nrm2(C64, &z), 1e-12);
    const z2 = [_]C32{ .init(1, 1), .init(1, 1) };
    try testing.expectApproxEqAbs(@as(f32, 2), nrm2(C32, &z2), 1e-6);
}

test "iamax returns a 0-based index, and null for an empty vector" {
    try testing.expectEqual(@as(?usize, 2), iamax(f64, &.{ 1, -2, 5, 3 }));
    // Ties go to the first occurrence.
    try testing.expectEqual(@as(?usize, 0), iamax(f64, &.{ -5, 5, 5 }));
    try testing.expectEqual(@as(?usize, null), iamax(f64, &.{}));

    const z = [_]C64{ .init(1, 0), .init(0, 3), .init(2, 0) };
    try testing.expectEqual(@as(?usize, 1), iamax(C64, &z));
}

test "dot and the extended-precision variants" {
    const x = [_]f32{ 1, 2, 3 };
    const y = [_]f32{ 4, 5, 6 };
    try testing.expectApproxEqAbs(@as(f32, 32), dot(f32, &x, &y), 1e-5);
    try testing.expectApproxEqAbs(@as(f64, 32), dsdot(&x, &y), 1e-12);
    // sdsdot adds alpha to the f64-accumulated product.
    try testing.expectApproxEqAbs(@as(f32, 42), sdsdot(10, &x, &y), 1e-5);
}

test "dotu and dotc differ by conjugation of x" {
    const x = [_]C64{ .init(1, 2), .init(3, -1) };
    const y = [_]C64{ .init(0, 1), .init(2, 2) };

    // dotu = sum(x_i * y_i) = (1+2i)(0+1i) + (3-i)(2+2i) = (-2+i) + (8+4i)
    const u = dotu(C64, &x, &y);
    try testing.expect(u.eqlApprox(.init(6, 5), 1e-12));

    // dotc = sum(conj(x_i) * y_i) = (1-2i)(0+1i) + (3+i)(2+2i) = (2+i) + (4+8i)
    const cc = dotc(C64, &x, &y);
    try testing.expect(cc.eqlApprox(.init(6, 9), 1e-12));

    // dotc(x, x) is the squared 2-norm, so it must be real and positive.
    const self_inner = dotc(C64, &x, &x);
    try testing.expectApproxEqAbs(@as(f64, 0), self_inner.im, 1e-12);
    const n = nrm2(C64, &x);
    try testing.expectApproxEqAbs(n * n, self_inner.re, 1e-12);
}

test "axpy and axpby over every element type" {
    {
        var y = [_]f64{ 10, 20, 30 };
        axpy(f64, 2, &.{ 1, 2, 3 }, &y);
        try testing.expectEqualSlices(f64, &.{ 12, 24, 36 }, &y);
    }
    {
        var y = [_]f32{ 10, 20 };
        axpby(f32, 2, &.{ 1, 1 }, 0.5, &y);
        try testing.expectEqualSlices(f32, &.{ 7, 12 }, &y);
    }
    {
        const x = [_]C64{.init(1, 1)};
        var y = [_]C64{.init(2, 0)};
        // (0+1i)*(1+1i) + (2+0i) = (-1+1i) + (2) = 1 + 1i
        axpy(C64, .init(0, 1), &x, &y);
        try testing.expect(y[0].eqlApprox(.init(1, 1), 1e-12));
    }
    {
        const x = [_]C32{.init(1, 0)};
        var y = [_]C32{.init(4, 4)};
        axpby(C32, .init(2, 0), &x, .init(0.5, 0), &y);
        try testing.expect(y[0].eqlApprox(.init(4, 2), 1e-6));
    }
}

test "copy, swap, scal, scalReal and set" {
    {
        var y = [_]f64{ 0, 0, 0 };
        copy(f64, &.{ 1, 2, 3 }, &y);
        try testing.expectEqualSlices(f64, &.{ 1, 2, 3 }, &y);
    }
    {
        var a = [_]f64{ 1, 2 };
        var b = [_]f64{ 3, 4 };
        swap(f64, &a, &b);
        try testing.expectEqualSlices(f64, &.{ 3, 4 }, &a);
        try testing.expectEqualSlices(f64, &.{ 1, 2 }, &b);
    }
    {
        var x = [_]f64{ 1, 2, 3 };
        scal(f64, 3, &x);
        try testing.expectEqualSlices(f64, &.{ 3, 6, 9 }, &x);
    }
    {
        // scalReal multiplies a complex vector by a real scalar.
        var z = [_]C64{ .init(1, 2), .init(3, 4) };
        scalReal(C64, 2, &z);
        try testing.expect(z[0].eqlApprox(.init(2, 4), 1e-12));
        try testing.expect(z[1].eqlApprox(.init(6, 8), 1e-12));
    }
    {
        var x = [_]f32{ 9, 9, 9 };
        set(f32, 1.5, &x);
        try testing.expectEqualSlices(f32, &.{ 1.5, 1.5, 1.5 }, &x);
    }
}

test "a stride of 2 touches every other element and leaves the rest alone" {
    var y = [_]f64{ 0, 99, 0, 99, 0, 99 };
    const x = [_]f64{ 1, 2, 3 };
    axpyStrided(f64, 3, 1, &x, 1, &y, 2);
    try testing.expectEqualSlices(f64, &.{ 1, 99, 2, 99, 3, 99 }, &y);

    // The strided sum sees only the touched entries.
    try testing.expectApproxEqAbs(@as(f64, 6), asumStrided(f64, 3, &y, 2), 1e-12);
}

test "a negative increment traverses the vector backwards" {
    // BLAS allows incx < 0; vectorLen must still size the slice correctly.
    var y = [_]f64{ 0, 0, 0 };
    const x = [_]f64{ 1, 2, 3 };
    copyStrided(f64, 3, &x, 1, &y, -1);
    try testing.expectEqualSlices(f64, &.{ 3, 2, 1 }, &y);

    // Reversing both is the identity.
    var z = [_]f64{ 0, 0, 0 };
    copyStrided(f64, 3, &x, -1, &z, -1);
    try testing.expectEqualSlices(f64, &.{ 1, 2, 3 }, &z);
}

test "rotg generates a rotation that zeroes the second component" {
    var a: f64 = 3;
    var b: f64 = 4;
    var cs: f64 = 0;
    var sn: f64 = 0;
    rotg(f64, &a, &b, &cs, &sn);

    // r = hypot(3, 4) = 5.
    try testing.expectApproxEqAbs(@as(f64, 5), a, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.6), cs, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.8), sn, 1e-12);

    // Applying it to (3, 4) must annihilate the second entry.
    var x = [_]f64{3};
    var y = [_]f64{4};
    rot(f64, &x, &y, cs, sn);
    try testing.expectApproxEqAbs(@as(f64, 5), x[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), y[0], 1e-12);
}

test "rot is orthogonal, so it preserves the norm" {
    var x = [_]f64{ 1, 2, 3 };
    var y = [_]f64{ 4, 5, 6 };
    const before = @sqrt(nrm2(f64, &x) * nrm2(f64, &x) + nrm2(f64, &y) * nrm2(f64, &y));

    const angle: f64 = 0.7;
    rot(f64, &x, &y, @cos(angle), @sin(angle));

    const after = @sqrt(nrm2(f64, &x) * nrm2(f64, &x) + nrm2(f64, &y) * nrm2(f64, &y));
    try testing.expectApproxEqAbs(before, after, 1e-12);
}

test "rotgComplex takes a real cosine and a complex sine" {
    var a = C64.init(3, 0);
    var b = C64.init(4, 0);
    var cs: f64 = 0;
    var sn = C64.zero;
    rotgComplex(C64, &a, &b, &cs, &sn);

    try testing.expectApproxEqAbs(@as(f64, 5), a.abs(), 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.6), cs, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.8), sn.abs(), 1e-12);
}

test "rotComplex applies a real rotation to complex vectors" {
    var x = [_]C64{.init(1, 1)};
    var y = [_]C64{.init(0, 0)};
    rotComplex(C64, &x, &y, 0, 1); // cos=0, sin=1 swaps with a sign
    try testing.expect(x[0].eqlApprox(.init(0, 0), 1e-12));
    try testing.expect(y[0].eqlApprox(.init(-1, -1), 1e-12));
}

test "rotmg and rotm round-trip through the modified rotation" {
    var d1: f64 = 1;
    var d2: f64 = 1;
    var b1: f64 = 3;
    var param: [5]f64 = undefined;
    rotmg(f64, &d1, &d2, &b1, 4, &param);

    var x = [_]f64{3};
    var y = [_]f64{4};
    rotm(f64, &x, &y, &param);
    // The modified rotation, like the plain one, annihilates y.
    try testing.expectApproxEqAbs(@as(f64, 0), y[0], 1e-12);
}
