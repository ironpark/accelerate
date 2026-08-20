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

/// Power: out[i] = base[i] ^ exp[i]
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

/// Power with a scalar exponent (positive bases only): out[i] = base[i] ^ exp.
/// `exp` is a single scalar applied to every element of `base`, not a
/// per-element vector - faster than `pow` for this case.
pub fn pows(comptime T: type, exponent: T, base: []const T, out: []T) void {
    std.debug.assert(out.len >= base.len);
    var n = toLen(base.len);
    var exp_var = exponent;
    switch (T) {
        f32 => c.vvpowsf(out.ptr, @as([*]const f32, @ptrCast(&exp_var)), base.ptr, &n),
        f64 => c.vvpows(out.ptr, @as([*]const f64, @ptrCast(&exp_var)), base.ptr, &n),
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

// ============================================================================
// Additional tests: rec/div/sqrt/cbrt/rsqrt/exp*/log*/pow* (priority 6 audit)
// ============================================================================

test "div (asymmetric, confirms out[i] = a[i] / b[i], not swapped)" {
    // vForce.h:111-119: vvdivf(z, y, x, n) documents z[i] = y[i]/x[i], with
    // y (numerator) in the 2nd arg slot and x (denominator) in the 3rd -
    // opposite naming from vDSP_vdiv's "Caution: A and B are swapped!" case.
    // The wrapper passes (out, a, b) into (z, y, x), so div(a, b, out) must
    // compute a/b, not b/a. Asymmetric inputs make a mixup visibly wrong:
    // a/b would give [5, 7, 8.25]; b/a would give [0.2, ~0.142, ~0.121].
    const a_f32 = [_]f32{ 10.0, 21.0, 33.0 };
    const b_f32 = [_]f32{ 2.0, 3.0, 4.0 };
    var out_f32: [3]f32 = undefined;
    div(f32, &a_f32, &b_f32, &out_f32);
    try std.testing.expectApproxEqRel(@as(f32, 5.0), out_f32[0], 1e-5);
    try std.testing.expectApproxEqRel(@as(f32, 7.0), out_f32[1], 1e-5);
    try std.testing.expectApproxEqRel(@as(f32, 8.25), out_f32[2], 1e-5);

    const a_f64 = [_]f64{ 10.0, 21.0, 33.0 };
    const b_f64 = [_]f64{ 2.0, 3.0, 4.0 };
    var out_f64: [3]f64 = undefined;
    div(f64, &a_f64, &b_f64, &out_f64);
    try std.testing.expectApproxEqRel(@as(f64, 5.0), out_f64[0], 1e-9);
    try std.testing.expectApproxEqRel(@as(f64, 7.0), out_f64[1], 1e-9);
    try std.testing.expectApproxEqRel(@as(f64, 8.25), out_f64[2], 1e-9);
}

test "cbrt" {
    const x = [_]f32{ 8.0, -27.0, 1.0, 0.125 };
    var out: [4]f32 = undefined;
    cbrt(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), out[0], 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, -3.0), out[1], 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out[2], 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), out[3], 1e-4);
}

test "rsqrt (out[i] = 1/sqrt(x[i]))" {
    const x = [_]f64{ 4.0, 16.0, 25.0 };
    var out: [3]f64 = undefined;
    rsqrt(f64, &x, &out);
    try std.testing.expectApproxEqRel(@as(f64, 0.5), out[0], 1e-6);
    try std.testing.expectApproxEqRel(@as(f64, 0.25), out[1], 1e-6);
    try std.testing.expectApproxEqRel(@as(f64, 0.2), out[2], 1e-6);
}

test "exp direct values" {
    const x = [_]f64{ 0.0, 1.0, 2.0 };
    var out: [3]f64 = undefined;
    exp(f64, &x, &out);
    try std.testing.expectApproxEqRel(@as(f64, 1.0), out[0], 1e-9);
    try std.testing.expectApproxEqRel(@as(f64, std.math.e), out[1], 1e-9);
    try std.testing.expectApproxEqRel(std.math.e * std.math.e, out[2], 1e-9);
}

test "exp2" {
    const x = [_]f32{ 0.0, 3.0, 10.0 };
    var out: [3]f32 = undefined;
    exp2(f32, &x, &out);
    try std.testing.expectApproxEqRel(@as(f32, 1.0), out[0], 1e-5);
    try std.testing.expectApproxEqRel(@as(f32, 8.0), out[1], 1e-5);
    try std.testing.expectApproxEqRel(@as(f32, 1024.0), out[2], 1e-5);
}

test "expm1 retains precision near x=0 (unlike naive exp(x)-1 in f32)" {
    // vForce.h:223-238: vvexpm1f is documented to avoid catastrophic
    // cancellation for small x, where the naive exp(x)-1 loses all
    // precision. Runtime-confirmed: with x=1e-8 (well below f32 epsilon
    // ~1.19e-7), the naive route computes exp(1e-8) which rounds to exactly
    // 1.0f in f32, so exp(x)-1 == 0.0 - completely wrong. expm1 must return
    // a value close to x itself (expm1(x) ~= x for small x), not 0.
    const x = [_]f32{1e-8};
    var expm1_out: [1]f32 = undefined;
    expm1(f32, &x, &expm1_out);
    try std.testing.expectApproxEqRel(@as(f32, 1e-8), expm1_out[0], 1e-3);

    var naive_exp_out: [1]f32 = undefined;
    exp(f32, &x, &naive_exp_out);
    const naive = naive_exp_out[0] - 1.0;
    try std.testing.expectEqual(@as(f32, 0.0), naive); // naive route loses all precision
}

test "log direct values" {
    const x = [_]f64{ 1.0, std.math.e, 10.0 };
    var out: [3]f64 = undefined;
    log(f64, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), out[0], 1e-9);
    try std.testing.expectApproxEqRel(@as(f64, 1.0), out[1], 1e-9);
    try std.testing.expectApproxEqRel(@as(f64, 2.302585092994046), out[2], 1e-9);
}

test "log10" {
    const x = [_]f32{ 1.0, 10.0, 1000.0 };
    var out: [3]f32 = undefined;
    log10(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), out[0], 1e-4);
    try std.testing.expectApproxEqRel(@as(f32, 1.0), out[1], 1e-5);
    try std.testing.expectApproxEqRel(@as(f32, 3.0), out[2], 1e-5);
}

test "log2" {
    const x = [_]f32{ 1.0, 8.0, 1024.0 };
    var out: [3]f32 = undefined;
    log2(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), out[0], 1e-4);
    try std.testing.expectApproxEqRel(@as(f32, 3.0), out[1], 1e-5);
    try std.testing.expectApproxEqRel(@as(f32, 10.0), out[2], 1e-5);
}

test "log1p retains precision near x=0 (unlike naive log(1+x) in f32)" {
    // vForce.h:292-307: vvlog1pf is documented to avoid the precision loss
    // of forming (1+x) directly for small x. Runtime-confirmed: x=1e-8 is
    // below f32 epsilon, so 1.0f + 1e-8f rounds to exactly 1.0f, and
    // log(1.0f) == 0.0f via the naive route - completely wrong. log1p must
    // return a value close to x itself (log1p(x) ~= x for small x).
    const x = [_]f32{1e-8};
    var log1p_out: [1]f32 = undefined;
    log1p(f32, &x, &log1p_out);
    try std.testing.expectApproxEqRel(@as(f32, 1e-8), log1p_out[0], 1e-3);

    const one_plus_x: f32 = 1.0 + x[0];
    try std.testing.expectEqual(@as(f32, 1.0), one_plus_x); // precondition: 1+x truncates to 1 in f32
    var naive_arr = [_]f32{one_plus_x};
    var naive_log_out: [1]f32 = undefined;
    log(f32, &naive_arr, &naive_log_out);
    try std.testing.expectEqual(@as(f32, 0.0), naive_log_out[0]); // naive route loses all precision
}

test "logb extracts unbiased binary exponent" {
    // vForce.h:344-360: logb(f) is the integer satisfying
    // abs(f) = significand * 2**logb(f), significand in [1,2).
    const x = [_]f32{ 8.0, 0.5, 1.0, 3.0 };
    var out: [4]f32 = undefined;
    logb(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), out[0], 1e-6); // 8 = 1.0 * 2^3
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), out[1], 1e-6); // 0.5 = 1.0 * 2^-1
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), out[2], 1e-6); // 1 = 1.0 * 2^0
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out[3], 1e-6); // 3 = 1.5 * 2^1
}

test "pows applies a single scalar exponent to every base element" {
    // vForce.h:467-486: vvpowsf/vvpows document `y` as "Input scalar,
    // exponent in calculation" (singular), unlike vvpowf/vvpow's `y` which
    // is documented as a full per-element input vector. Runtime-confirmed
    // by calling with junk values past index 0 in what would be an
    // element-wise exponent array: the output only reflects exp_vec[0],
    // proving the C function reads a single scalar through the pointer,
    // not an N-element vector. The wrapper's signature was changed from
    // `exp_vec: []const T` to a plain scalar `exp: T` to make this honest -
    // the old slice-typed signature silently ignored all but the first
    // element, a footgun a caller could not detect from the type alone.
    const base = [_]f32{ 2.0, 3.0, 4.0 };
    var out: [3]f32 = undefined;
    pows(f32, 3.0, &base, &out);
    try std.testing.expectApproxEqRel(@as(f32, 8.0), out[0], 1e-4); // 2^3
    try std.testing.expectApproxEqRel(@as(f32, 27.0), out[1], 1e-4); // 3^3
    try std.testing.expectApproxEqRel(@as(f32, 64.0), out[2], 1e-4); // 4^3

    // Different scalar exponent, still asymmetric bases, cross-checks pow's
    // dedicated (per-element) test doesn't accidentally alias this one.
    var out2: [3]f64 = undefined;
    const base64 = [_]f64{ 5.0, 6.0, 7.0 };
    pows(f64, 2.0, &base64, &out2);
    try std.testing.expectApproxEqRel(@as(f64, 25.0), out2[0], 1e-9);
    try std.testing.expectApproxEqRel(@as(f64, 36.0), out2[1], 1e-9);
    try std.testing.expectApproxEqRel(@as(f64, 49.0), out2[2], 1e-9);
}

// ----------------------------------------------------------------------
// Additional regression tests: trig / inverse-trig / hyperbolic family
// (sin, cos, tan, sinpi, cospi, tanpi, sincos, asin, acos, atan, atan2,
// sinh, cosh, tanh, asinh, acosh, atanh)
//
// vForce.h positional signature for these is `(y, x, n)` for the
// single-argument functions ("output, input, count") - i.e. output comes
// BEFORE input, opposite of the mathematical reading order but consistent
// across the whole family. Confirmed against vForce.h for every symbol in
// this group before writing these tests; all wrapper call sites already
// match that order (no swap bug found in this group).
// ----------------------------------------------------------------------

test "tan asymmetric" {
    // tan(0) = 0, tan(pi/4) = 1, tan(-pi/4) = -1
    const x = [_]f32{ 0.0, std.math.pi / 4.0, -std.math.pi / 4.0 };
    var out: [3]f32 = undefined;
    tan(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), out[2], 0.001);
}

test "sinpi computes sin(pi*x), not pi*sin(x)" {
    // At x=0.5 the two interpretations diverge obviously:
    //   sin(pi*0.5)  = 1.0
    //   pi*sin(0.5) ~= 1.5069
    // vForce.h L1192/1200: "y[i] is set to sin(pi*x[i])".
    const x = [_]f32{ 0.5, 0.25, -0.5 };
    var out: [3]f32 = undefined;
    sinpi(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, std.math.sqrt2 / 2.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), out[2], 0.001);

    // Cross-check against the wrong ("pi*sin(x)") interpretation to make
    // sure the test would actually fail if the binding computed that instead.
    try std.testing.expect(@abs(out[0] - std.math.pi * @sin(@as(f32, 0.5))) > 0.4);
}

test "cospi computes cos(pi*x), not pi*cos(x)" {
    // cos(pi*0.5) = 0, cos(pi*0.25) = sqrt(2)/2, cos(pi*0) = 1
    const x = [_]f32{ 0.5, 0.25, 0.0 };
    var out: [3]f32 = undefined;
    cospi(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, std.math.sqrt2 / 2.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out[2], 0.001);
}

test "tanpi computes tan(pi*x), not pi*tan(x)" {
    // tan(pi*0.25) = 1, tan(pi*-0.25) = -1, tan(pi*0.1) ~= 0.3249 (18 deg)
    const x = [_]f32{ 0.25, -0.25, 0.1 };
    var out: [3]f32 = undefined;
    tanpi(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3249), out[2], 0.001);
}

test "sincos matches independent sin/cos, f64" {
    // Asymmetric input, f64 path (vvsincos, not vvsincosf), cross-checked
    // against the independently-verified sin()/cos() wrappers rather than
    // hand-computed constants, to also confirm f64 dispatch is wired up.
    const x = [_]f64{ 0.3, -1.2, 2.5 };
    var sin_out: [3]f64 = undefined;
    var cos_out: [3]f64 = undefined;
    sincos(f64, &x, &sin_out, &cos_out);

    var sin_ref: [3]f64 = undefined;
    var cos_ref: [3]f64 = undefined;
    sin(f64, &x, &sin_ref);
    cos(f64, &x, &cos_ref);

    for (0..3) |i| {
        try std.testing.expectApproxEqAbs(sin_ref[i], sin_out[i], 1e-9);
        try std.testing.expectApproxEqAbs(cos_ref[i], cos_out[i], 1e-9);
    }
}

test "asin, acos, atan asymmetric" {
    const x = [_]f32{ 0.5, -0.8, 0.2 };
    var asin_out: [3]f32 = undefined;
    var acos_out: [3]f32 = undefined;
    var atan_out: [3]f32 = undefined;
    asin(f32, &x, &asin_out);
    acos(f32, &x, &acos_out);
    atan(f32, &x, &atan_out);

    try std.testing.expectApproxEqAbs(@as(f32, 0.5236), asin_out[0], 0.001); // asin(0.5)
    try std.testing.expectApproxEqAbs(@as(f32, -0.9273), asin_out[1], 0.001); // asin(-0.8)
    try std.testing.expectApproxEqAbs(@as(f32, 1.0472), acos_out[0], 0.001); // acos(0.5)
    try std.testing.expectApproxEqAbs(@as(f32, 2.4981), acos_out[1], 0.001); // acos(-0.8)
    try std.testing.expectApproxEqAbs(@as(f32, 0.1974), atan_out[2], 0.001); // atan(0.2)
}

test "atan2(y, x) argument order, not atan2(x, y)" {
    // vForce.h L671/700 ("@param z ... z[i] is set to atan2(y,x)") and the
    // extern declaration order `(z, y, x, n)` both put y before x. This
    // wrapper's `atan2(comptime T, y, x, out)` passes y then x straight
    // through, matching that order.
    //
    // atan2(1, 2) ~= 0.4636 rad, atan2(2, 1) ~= 1.1071 rad - clearly
    // distinguishable, so a swapped y/x would fail this test.
    const y = [_]f32{ 1.0, -3.0 };
    const x = [_]f32{ 2.0, 4.0 };
    var out: [2]f32 = undefined;
    atan2(f32, &y, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4636), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -0.6435), out[1], 0.001); // atan2(-3,4)

    // f64 path cross-check (vvatan2, not vvatan2f).
    const yd = [_]f64{ 1.0, -3.0 };
    const xd = [_]f64{ 2.0, 4.0 };
    var outd: [2]f64 = undefined;
    atan2(f64, &yd, &xd, &outd);
    try std.testing.expectApproxEqAbs(@as(f64, 0.4636476090008061), outd[0], 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, -0.6435011087932844), outd[1], 1e-9);
}

test "sinh, cosh, tanh asymmetric" {
    const x = [_]f32{ 0.5, 1.5, -1.0 };
    var sinh_out: [3]f32 = undefined;
    var cosh_out: [3]f32 = undefined;
    var tanh_out: [3]f32 = undefined;
    sinh(f32, &x, &sinh_out);
    cosh(f32, &x, &cosh_out);
    tanh(f32, &x, &tanh_out);

    try std.testing.expectApproxEqAbs(@as(f32, 0.5211), sinh_out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.1293), sinh_out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.1276), cosh_out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.3524), cosh_out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -0.7616), tanh_out[2], 0.001); // tanh(-1)
}

test "asinh domain: all reals" {
    const x = [_]f32{ 1.0, -2.0, 0.0 };
    var out: [3]f32 = undefined;
    asinh(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8814), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.4436), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), out[2], 0.001);
}

test "acosh domain boundary x=1 and interior x=2" {
    // acosh is only defined for x >= 1; acosh(1) = 0 is the domain boundary.
    const x = [_]f32{ 1.0, 2.0 };
    var out: [2]f32 = undefined;
    acosh(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.3170), out[1], 0.001);
}

test "atanh domain interior, asymmetric" {
    // atanh is only defined for -1 < x < 1.
    const x = [_]f32{ 0.5, -0.9 };
    var out: [2]f32 = undefined;
    atanh(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5493), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.4722), out[1], 0.001);
}

test "trunc" {
    // vForce.h vvintf/vvint: "rounds x[i] to the nearest integer in the
    // direction of zero" - truncation must NOT match floor/ceil for
    // negative fractional values.
    const x = [_]f64{ 2.7, -2.7, -0.3, 3.0 };
    var out: [4]f64 = undefined;
    trunc(f64, &x, &out);
    try std.testing.expectEqual(@as(f64, 2.0), out[0]);
    try std.testing.expectEqual(@as(f64, -2.0), out[1]);
    try std.testing.expectEqual(@as(f64, -0.0), out[2]);
    try std.testing.expectEqual(@as(f64, 3.0), out[3]);
}

test "nint rounds ties to even" {
    // vForce.h vvnintf/vvnint: "Rounds x[i] to the nearest integer, with
    // ties rounded to even" - this is banker's rounding, NOT round-half-up.
    // 2.5 and -2.5 are equidistant from two integers; the even one wins.
    const x = [_]f64{ 2.5, 3.5, -2.5, -0.5, 1.3, -1.7 };
    var out: [6]f64 = undefined;
    nint(f64, &x, &out);
    try std.testing.expectEqual(@as(f64, 2.0), out[0]); // tie -> even (2)
    try std.testing.expectEqual(@as(f64, 4.0), out[1]); // tie -> even (4)
    try std.testing.expectEqual(@as(f64, -2.0), out[2]); // tie -> even (-2)
    try std.testing.expectEqual(@as(f64, -0.0), out[3]); // tie -> even (0)
    try std.testing.expectEqual(@as(f64, 1.0), out[4]); // non-tie: nearest
    try std.testing.expectEqual(@as(f64, -2.0), out[5]); // non-tie: nearest
}

test "ceil and floor asymmetric" {
    const x = [_]f64{ -2.5, 4.1, 0.0 };
    var ceil_out: [3]f64 = undefined;
    var floor_out: [3]f64 = undefined;
    ceil(f64, &x, &ceil_out);
    floor(f64, &x, &floor_out);
    try std.testing.expectEqual(@as(f64, -2.0), ceil_out[0]);
    try std.testing.expectEqual(@as(f64, 5.0), ceil_out[1]);
    try std.testing.expectEqual(@as(f64, 0.0), ceil_out[2]);
    try std.testing.expectEqual(@as(f64, -3.0), floor_out[0]);
    try std.testing.expectEqual(@as(f64, 4.0), floor_out[1]);
    try std.testing.expectEqual(@as(f64, 0.0), floor_out[2]);
}

test "fmod matches libm fmod sign convention (sign of dividend/numerator)" {
    // vForce.h vvfmodf/vvfmod: z = y - k*x, "if x is non-zero, the result
    // has the same sign as y" where y is the numerator (2nd C arg) and x is
    // the denominator (3rd C arg). Root.zig's fmod(a, b, out) maps a->y
    // (numerator), b->x (denominator), matching the standard C fmod(a, b)
    // convention despite the header's warning that "argument labels are
    // switched with respect to the libm function fmod()" (that warning is
    // about the *C parameter names* y/x vs libm's x/y, not about which
    // vector is the dividend).
    const a = [_]f64{ 5.5, -5.5, 7.0 };
    const b = [_]f64{ 2.0, 2.0, -3.0 };
    var out: [3]f64 = undefined;
    fmod(f64, &a, &b, &out);
    // fmod(5.5, 2) = 1.5 (5.5 = 2*2 + 1.5)
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), out[0], 1e-12);
    // fmod(-5.5, 2) = -1.5 (sign follows dividend, unlike remainder)
    try std.testing.expectApproxEqAbs(@as(f64, -1.5), out[1], 1e-12);
    // fmod(7, -3) = 1.0 (sign follows dividend)
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), out[2], 1e-12);
}

test "remainder diverges from fmod on sign (round-to-nearest, ties to even)" {
    // vForce.h vvremainderf/vvremainder: z = y - k*x for the integer k
    // nearest y/x (ties to even), abs(z) <= abs(x)/2. This can have a
    // different sign than fmod for the same inputs - a concrete divergence
    // check per REQUEST.md's test design rules.
    const a = [_]f64{5.5};
    const b = [_]f64{2.0};
    var fmod_out: [1]f64 = undefined;
    var rem_out: [1]f64 = undefined;
    fmod(f64, &a, &b, &fmod_out);
    remainder(f64, &a, &b, &rem_out);
    // fmod(5.5, 2) = 1.5, remainder(5.5, 2) = -0.5 (5.5/2 = 2.75 -> k=3,
    // 5.5 - 3*2 = -0.5)
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), fmod_out[0], 1e-12);
    try std.testing.expectApproxEqAbs(@as(f64, -0.5), rem_out[0], 1e-12);
}

test "copysign takes magnitude from first arg, sign from second" {
    // vForce.h vvcopysignf/vvcopysign: z = copysign(y, x) where y (2nd C
    // arg) supplies the magnitude and x (3rd C arg) supplies the sign.
    // Root.zig's copysign(magnitude, sign, out) maps magnitude->y, sign->x
    // positionally, matching the header. Use DIFFERENT magnitudes (not just
    // opposite signs of the same value) so an accidental arg swap would be
    // caught even if it happened to preserve sign by coincidence.
    const magnitude = [_]f64{ 3.0, -7.5, 2.0 };
    const sign = [_]f64{ -1.0, 1.0, -0.0 };
    var out: [3]f64 = undefined;
    copysign(f64, &magnitude, &sign, &out);
    try std.testing.expectEqual(@as(f64, -3.0), out[0]); // mag 3, sign of -1 -> -3
    try std.testing.expectEqual(@as(f64, 7.5), out[1]); // mag -7.5, sign of 1 -> 7.5
    try std.testing.expectEqual(@as(f64, -2.0), out[2]); // mag 2, sign of -0.0 -> -2
}

test "nextafter moves toward the second argument, not the first" {
    // vForce.h vvnextafterf/vvnextafter: z = nextafter(y, x), "next machine
    // representable number from y in the direction of x". Root.zig's
    // nextafter(x, y, out) maps x->y (starting value), y->x (direction
    // target) positionally, matching the header despite its param doc
    // erroneously reusing copysign's "magnitude"/"sign" wording for y/x.
    const from = [_]f64{ 1.0, 1.0, -1.0 };
    const towards = [_]f64{ 2.0, 0.0, -2.0 };
    var out: [3]f64 = undefined;
    nextafter(f64, &from, &towards, &out);
    try std.testing.expect(out[0] > 1.0); // moving toward +2 increases
    try std.testing.expect(out[0] < 1.0 + 1e-10);
    try std.testing.expect(out[1] < 1.0); // moving toward 0 decreases
    try std.testing.expect(out[1] > 1.0 - 1e-10);
    try std.testing.expect(out[2] < -1.0); // moving toward -2 decreases (more negative)
    try std.testing.expect(out[2] > -1.0 - 1e-10);
}

test "cosisin computes cos(x) + i*sin(x)" {
    // vForce.h vvcosisinf/vvcosisin: "C[i] is set to cos(x[i]) + I*sin(x[i])",
    // the same C function as the complex exponential e^(i*x) restricted to
    // the unit circle. Verified against known angles.
    const x = [_]f32{ 0.0, std.math.pi / 2.0 };
    var out: [2]FloatComplex = undefined;
    cosisin(f32, &x, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out[0].real, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), out[0].imag, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), out[1].real, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out[1].imag, 0.001);
}
