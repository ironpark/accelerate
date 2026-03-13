const std = @import("std");
const c = @import("c.zig");

pub const FloatComplex = c.FloatComplex;
pub const DoubleComplex = c.DoubleComplex;

// ============================================================================
// Helper
// ============================================================================

inline fn toLen(len: usize) c_int {
    return @intCast(len);
}

// ============================================================================
// Basic arithmetic
// ============================================================================

/// Reciprocal: y[i] = 1/x[i]
pub fn rec(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvrecf(out.ptr, x.ptr, &n),
        f64 => c.vvrec(out.ptr, x.ptr, &n),
        else => @compileError("rec requires f32 or f64"),
    }
}

/// Division: out[i] = a[i] / b[i]
pub fn div(comptime T: type, a: []const T, b: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
    var n = toLen(a.len);
    switch (T) {
        f32 => c.vvdivf(out.ptr, a.ptr, b.ptr, &n),
        f64 => c.vvdiv(out.ptr, a.ptr, b.ptr, &n),
        else => @compileError("div requires f32 or f64"),
    }
}

/// Square root: out[i] = sqrt(x[i])
pub fn sqrt(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvsqrtf(out.ptr, x.ptr, &n),
        f64 => c.vvsqrt(out.ptr, x.ptr, &n),
        else => @compileError("sqrt requires f32 or f64"),
    }
}

/// Cube root: out[i] = cbrt(x[i])
pub fn cbrt(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvcbrtf(out.ptr, x.ptr, &n),
        f64 => c.vvcbrt(out.ptr, x.ptr, &n),
        else => @compileError("cbrt requires f32 or f64"),
    }
}

/// Reciprocal square root: out[i] = 1/sqrt(x[i])
pub fn rsqrt(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvrsqrtf(out.ptr, x.ptr, &n),
        f64 => c.vvrsqrt(out.ptr, x.ptr, &n),
        else => @compileError("rsqrt requires f32 or f64"),
    }
}

// ============================================================================
// Exponential
// ============================================================================

/// Exponential: out[i] = exp(x[i])
pub fn exp(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvexpf(out.ptr, x.ptr, &n),
        f64 => c.vvexp(out.ptr, x.ptr, &n),
        else => @compileError("exp requires f32 or f64"),
    }
}

/// Base-2 exponential: out[i] = 2^x[i]
pub fn exp2(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvexp2f(out.ptr, x.ptr, &n),
        f64 => c.vvexp2(out.ptr, x.ptr, &n),
        else => @compileError("exp2 requires f32 or f64"),
    }
}

/// Exponential minus one: out[i] = exp(x[i]) - 1
pub fn expm1(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvexpm1f(out.ptr, x.ptr, &n),
        f64 => c.vvexpm1(out.ptr, x.ptr, &n),
        else => @compileError("expm1 requires f32 or f64"),
    }
}

// ============================================================================
// Logarithmic
// ============================================================================

/// Natural logarithm: out[i] = ln(x[i])
pub fn log(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvlogf(out.ptr, x.ptr, &n),
        f64 => c.vvlog(out.ptr, x.ptr, &n),
        else => @compileError("log requires f32 or f64"),
    }
}

/// Base-10 logarithm: out[i] = log10(x[i])
pub fn log10(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvlog10f(out.ptr, x.ptr, &n),
        f64 => c.vvlog10(out.ptr, x.ptr, &n),
        else => @compileError("log10 requires f32 or f64"),
    }
}

/// Base-2 logarithm: out[i] = log2(x[i])
pub fn log2(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvlog2f(out.ptr, x.ptr, &n),
        f64 => c.vvlog2(out.ptr, x.ptr, &n),
        else => @compileError("log2 requires f32 or f64"),
    }
}

/// Logarithm of (1 + x): out[i] = log(1 + x[i])
pub fn log1p(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvlog1pf(out.ptr, x.ptr, &n),
        f64 => c.vvlog1p(out.ptr, x.ptr, &n),
        else => @compileError("log1p requires f32 or f64"),
    }
}

/// Extract exponent: out[i] = logb(x[i])
pub fn logb(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvlogbf(out.ptr, x.ptr, &n),
        f64 => c.vvlogb(out.ptr, x.ptr, &n),
        else => @compileError("logb requires f32 or f64"),
    }
}

// ============================================================================
// Power
// ============================================================================

/// Power: out[i] = exp[i] ^ base[i]
pub fn pow(comptime T: type, exp_vec: []const T, base: []const T, out: []T) void {
    std.debug.assert(base.len >= exp_vec.len);
    std.debug.assert(out.len >= exp_vec.len);
    var n = toLen(exp_vec.len);
    switch (T) {
        f32 => c.vvpowf(out.ptr, exp_vec.ptr, base.ptr, &n),
        f64 => c.vvpow(out.ptr, exp_vec.ptr, base.ptr, &n),
        else => @compileError("pow requires f32 or f64"),
    }
}

/// Power (positive bases only): out[i] = base[i] ^ exp[i]
/// base values must be positive; faster than pow for this case.
pub fn pows(comptime T: type, exp_vec: []const T, base: []const T, out: []T) void {
    std.debug.assert(base.len >= exp_vec.len);
    std.debug.assert(out.len >= exp_vec.len);
    var n = toLen(exp_vec.len);
    switch (T) {
        f32 => c.vvpowsf(out.ptr, exp_vec.ptr, base.ptr, &n),
        f64 => c.vvpows(out.ptr, exp_vec.ptr, base.ptr, &n),
        else => @compileError("pows requires f32 or f64"),
    }
}

// ============================================================================
// Absolute value
// ============================================================================

/// Absolute value: out[i] = |x[i]|
pub fn fabs(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvfabsf(out.ptr, x.ptr, &n),
        f64 => c.vvfabs(out.ptr, x.ptr, &n),
        else => @compileError("fabs requires f32 or f64"),
    }
}

// ============================================================================
// Trigonometric
// ============================================================================

/// Sine: out[i] = sin(x[i])
pub fn sin(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvsinf(out.ptr, x.ptr, &n),
        f64 => c.vvsin(out.ptr, x.ptr, &n),
        else => @compileError("sin requires f32 or f64"),
    }
}

/// Cosine: out[i] = cos(x[i])
pub fn cos(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvcosf(out.ptr, x.ptr, &n),
        f64 => c.vvcos(out.ptr, x.ptr, &n),
        else => @compileError("cos requires f32 or f64"),
    }
}

/// Tangent: out[i] = tan(x[i])
pub fn tan(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvtanf(out.ptr, x.ptr, &n),
        f64 => c.vvtan(out.ptr, x.ptr, &n),
        else => @compileError("tan requires f32 or f64"),
    }
}

/// Sine of pi*x: out[i] = sin(pi * x[i])
pub fn sinpi(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvsinpif(out.ptr, x.ptr, &n),
        f64 => c.vvsinpi(out.ptr, x.ptr, &n),
        else => @compileError("sinpi requires f32 or f64"),
    }
}

/// Cosine of pi*x: out[i] = cos(pi * x[i])
pub fn cospi(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvcospif(out.ptr, x.ptr, &n),
        f64 => c.vvcospi(out.ptr, x.ptr, &n),
        else => @compileError("cospi requires f32 or f64"),
    }
}

/// Tangent of pi*x: out[i] = tan(pi * x[i])
pub fn tanpi(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvtanpif(out.ptr, x.ptr, &n),
        f64 => c.vvtanpi(out.ptr, x.ptr, &n),
        else => @compileError("tanpi requires f32 or f64"),
    }
}

/// Simultaneous sine and cosine: sin_out[i] = sin(x[i]), cos_out[i] = cos(x[i])
pub fn sincos(comptime T: type, x: []const T, sin_out: []T, cos_out: []T) void {
    std.debug.assert(sin_out.len >= x.len);
    std.debug.assert(cos_out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvsincosf(sin_out.ptr, cos_out.ptr, x.ptr, &n),
        f64 => c.vvsincos(sin_out.ptr, cos_out.ptr, x.ptr, &n),
        else => @compileError("sincos requires f32 or f64"),
    }
}

// ============================================================================
// Inverse trigonometric
// ============================================================================

/// Arc sine: out[i] = asin(x[i])
pub fn asin(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvasinf(out.ptr, x.ptr, &n),
        f64 => c.vvasin(out.ptr, x.ptr, &n),
        else => @compileError("asin requires f32 or f64"),
    }
}

/// Arc cosine: out[i] = acos(x[i])
pub fn acos(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvacosf(out.ptr, x.ptr, &n),
        f64 => c.vvacos(out.ptr, x.ptr, &n),
        else => @compileError("acos requires f32 or f64"),
    }
}

/// Arc tangent: out[i] = atan(x[i])
pub fn atan(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvatanf(out.ptr, x.ptr, &n),
        f64 => c.vvatan(out.ptr, x.ptr, &n),
        else => @compileError("atan requires f32 or f64"),
    }
}

/// Two-argument arc tangent: out[i] = atan2(y[i], x[i])
pub fn atan2(comptime T: type, y: []const T, x: []const T, out: []T) void {
    std.debug.assert(x.len >= y.len);
    std.debug.assert(out.len >= y.len);
    var n = toLen(y.len);
    switch (T) {
        f32 => c.vvatan2f(out.ptr, y.ptr, x.ptr, &n),
        f64 => c.vvatan2(out.ptr, y.ptr, x.ptr, &n),
        else => @compileError("atan2 requires f32 or f64"),
    }
}

// ============================================================================
// Hyperbolic
// ============================================================================

/// Hyperbolic sine: out[i] = sinh(x[i])
pub fn sinh(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvsinhf(out.ptr, x.ptr, &n),
        f64 => c.vvsinh(out.ptr, x.ptr, &n),
        else => @compileError("sinh requires f32 or f64"),
    }
}

/// Hyperbolic cosine: out[i] = cosh(x[i])
pub fn cosh(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvcoshf(out.ptr, x.ptr, &n),
        f64 => c.vvcosh(out.ptr, x.ptr, &n),
        else => @compileError("cosh requires f32 or f64"),
    }
}

/// Hyperbolic tangent: out[i] = tanh(x[i])
pub fn tanh(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvtanhf(out.ptr, x.ptr, &n),
        f64 => c.vvtanh(out.ptr, x.ptr, &n),
        else => @compileError("tanh requires f32 or f64"),
    }
}

// ============================================================================
// Inverse hyperbolic
// ============================================================================

/// Inverse hyperbolic sine: out[i] = asinh(x[i])
pub fn asinh(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvasinhf(out.ptr, x.ptr, &n),
        f64 => c.vvasinh(out.ptr, x.ptr, &n),
        else => @compileError("asinh requires f32 or f64"),
    }
}

/// Inverse hyperbolic cosine: out[i] = acosh(x[i])
pub fn acosh(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvacoshf(out.ptr, x.ptr, &n),
        f64 => c.vvacosh(out.ptr, x.ptr, &n),
        else => @compileError("acosh requires f32 or f64"),
    }
}

/// Inverse hyperbolic tangent: out[i] = atanh(x[i])
pub fn atanh(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvatanhf(out.ptr, x.ptr, &n),
        f64 => c.vvatanh(out.ptr, x.ptr, &n),
        else => @compileError("atanh requires f32 or f64"),
    }
}

// ============================================================================
// Rounding
// ============================================================================

/// Truncate to integer: out[i] = trunc(x[i])
pub fn trunc(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvintf(out.ptr, x.ptr, &n),
        f64 => c.vvint(out.ptr, x.ptr, &n),
        else => @compileError("trunc requires f32 or f64"),
    }
}

/// Round to nearest integer: out[i] = round(x[i])
pub fn nint(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvnintf(out.ptr, x.ptr, &n),
        f64 => c.vvnint(out.ptr, x.ptr, &n),
        else => @compileError("nint requires f32 or f64"),
    }
}

/// Ceiling: out[i] = ceil(x[i])
pub fn ceil(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvceilf(out.ptr, x.ptr, &n),
        f64 => c.vvceil(out.ptr, x.ptr, &n),
        else => @compileError("ceil requires f32 or f64"),
    }
}

/// Floor: out[i] = floor(x[i])
pub fn floor(comptime T: type, x: []const T, out: []T) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvfloorf(out.ptr, x.ptr, &n),
        f64 => c.vvfloor(out.ptr, x.ptr, &n),
        else => @compileError("floor requires f32 or f64"),
    }
}

// ============================================================================
// Modular arithmetic
// ============================================================================

/// Floating-point modulus: out[i] = fmod(a[i], b[i])
pub fn fmod(comptime T: type, a: []const T, b: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
    var n = toLen(a.len);
    switch (T) {
        f32 => c.vvfmodf(out.ptr, a.ptr, b.ptr, &n),
        f64 => c.vvfmod(out.ptr, a.ptr, b.ptr, &n),
        else => @compileError("fmod requires f32 or f64"),
    }
}

/// IEEE remainder: out[i] = remainder(a[i], b[i])
pub fn remainder(comptime T: type, a: []const T, b: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
    var n = toLen(a.len);
    switch (T) {
        f32 => c.vvremainderf(out.ptr, a.ptr, b.ptr, &n),
        f64 => c.vvremainder(out.ptr, a.ptr, b.ptr, &n),
        else => @compileError("remainder requires f32 or f64"),
    }
}

// ============================================================================
// Sign and next-after
// ============================================================================

/// Copy sign: out[i] = copysign(magnitude[i], sign[i])
pub fn copysign(comptime T: type, magnitude: []const T, sign: []const T, out: []T) void {
    std.debug.assert(sign.len >= magnitude.len);
    std.debug.assert(out.len >= magnitude.len);
    var n = toLen(magnitude.len);
    switch (T) {
        f32 => c.vvcopysignf(out.ptr, magnitude.ptr, sign.ptr, &n),
        f64 => c.vvcopysign(out.ptr, magnitude.ptr, sign.ptr, &n),
        else => @compileError("copysign requires f32 or f64"),
    }
}

/// Next representable value: out[i] = nextafter(x[i], y[i])
pub fn nextafter(comptime T: type, x: []const T, y: []const T, out: []T) void {
    std.debug.assert(y.len >= x.len);
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvnextafterf(out.ptr, x.ptr, y.ptr, &n),
        f64 => c.vvnextafter(out.ptr, x.ptr, y.ptr, &n),
        else => @compileError("nextafter requires f32 or f64"),
    }
}

// ============================================================================
// Complex exponential
// ============================================================================

/// Complex exponential: out[i] = cos(x[i]) + i*sin(x[i])
pub fn cosisin(comptime T: type, x: []const T, out: anytype) void {
    std.debug.assert(out.len >= x.len);
    var n = toLen(x.len);
    switch (T) {
        f32 => c.vvcosisinf(out.ptr, x.ptr, &n),
        f64 => c.vvcosisin(out.ptr, x.ptr, &n),
        else => @compileError("cosisin requires f32 or f64"),
    }
}

// ============================================================================
// Tests
// ============================================================================

test "rec" {
    const x = [_]f32{ 2.0, 4.0, 5.0 };
    var out: [3]f32 = undefined;
    rec(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), out[2], 0.001);
}

test "sqrt" {
    const x = [_]f32{ 1.0, 4.0, 9.0 };
    var out: [3]f32 = undefined;
    sqrt(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), out[2], 0.001);
}

test "exp and log roundtrip" {
    const x = [_]f64{ 1.0, 2.0, 3.0 };
    var exp_out: [3]f64 = undefined;
    var log_out: [3]f64 = undefined;
    exp(f64, &x, &exp_out);
    log(f64, &exp_out, &log_out);
    for (0..3) |i| {
        try std.testing.expectApproxEqAbs(x[i], log_out[i], 1e-10);
    }
}

test "sin and cos" {
    const x = [_]f32{ 0.0, std.math.pi / 2.0, std.math.pi };
    var sin_out: [3]f32 = undefined;
    var cos_out: [3]f32 = undefined;
    sin(f32, &x, &sin_out);
    cos(f32, &x, &cos_out);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), sin_out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sin_out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), cos_out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), cos_out[1], 0.001);
}

test "sincos" {
    const x = [_]f32{ 0.0, std.math.pi / 2.0 };
    var sin_out: [2]f32 = undefined;
    var cos_out: [2]f32 = undefined;
    sincos(f32, &x, &sin_out, &cos_out);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), sin_out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), sin_out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), cos_out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), cos_out[1], 0.001);
}

test "ceil and floor" {
    const x = [_]f32{ 1.3, 2.7, -0.5 };
    var ceil_out: [3]f32 = undefined;
    var floor_out: [3]f32 = undefined;
    ceil(f32, &x, &ceil_out);
    floor(f32, &x, &floor_out);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), ceil_out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), ceil_out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), ceil_out[2], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), floor_out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), floor_out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), floor_out[2], 0.001);
}

test "fabs" {
    const x = [_]f32{ -1.0, 2.0, -3.0 };
    var out: [3]f32 = undefined;
    fabs(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), out[2], 0.001);
}

test "pow" {
    const bases = [_]f32{ 2.0, 3.0, 4.0 };
    const exps = [_]f32{ 3.0, 2.0, 0.5 };
    var out: [3]f32 = undefined;
    pow(f32, &exps, &bases, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), out[2], 0.001);
}

test "tanh" {
    const x = [_]f32{ 0.0, 1.0 };
    var out: [2]f32 = undefined;
    tanh(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.7616), out[1], 0.001);
}
