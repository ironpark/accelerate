// Consolidated C extern declarations for vForce.
//
// vForce provides fast mathematical operations on large arrays via Apple's
// Accelerate framework. All functions take an element count as `*const c_int`.

// ============================================================================
// Basic arithmetic
// ============================================================================

// Reciprocal: y[i] = 1/x[i]
pub extern fn vvrecf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvrec(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// Division: z[i] = y[i]/x[i]
pub extern fn vvdivf(z: [*]f32, y: [*]const f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvdiv(z: [*]f64, y: [*]const f64, x: [*]const f64, n: *const c_int) void;

// Square root: y[i] = sqrt(x[i])
pub extern fn vvsqrtf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvsqrt(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// Cube root: y[i] = cbrt(x[i])
pub extern fn vvcbrtf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvcbrt(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// Reciprocal square root: y[i] = 1/sqrt(x[i])
pub extern fn vvrsqrtf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvrsqrt(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// ============================================================================
// Exponential
// ============================================================================

// y[i] = exp(x[i])
pub extern fn vvexpf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvexp(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = 2^x[i]
pub extern fn vvexp2f(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvexp2(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = exp(x[i]) - 1
pub extern fn vvexpm1f(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvexpm1(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// ============================================================================
// Logarithmic
// ============================================================================

// y[i] = ln(x[i])
pub extern fn vvlogf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvlog(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = log10(x[i])
pub extern fn vvlog10f(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvlog10(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = log2(x[i])
pub extern fn vvlog2f(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvlog2(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = log(1 + x[i])
pub extern fn vvlog1pf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvlog1p(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = logb(x[i]) (extract exponent)
pub extern fn vvlogbf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvlogb(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// ============================================================================
// Power
// ============================================================================

// z[i] = y[i]^x[i]
pub extern fn vvpowf(z: [*]f32, y: [*]const f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvpow(z: [*]f64, y: [*]const f64, x: [*]const f64, n: *const c_int) void;

// z[i] = x[i]^y[i] (x must be positive)
pub extern fn vvpowsf(z: [*]f32, y: [*]const f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvpows(z: [*]f64, y: [*]const f64, x: [*]const f64, n: *const c_int) void;

// ============================================================================
// Absolute value
// ============================================================================

// y[i] = |x[i]|
pub extern fn vvfabsf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvfabs(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// ============================================================================
// Trigonometric
// ============================================================================

// y[i] = sin(x[i])
pub extern fn vvsinf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvsin(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = cos(x[i])
pub extern fn vvcosf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvcos(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = tan(x[i])
pub extern fn vvtanf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvtan(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = sin(pi * x[i])
pub extern fn vvsinpif(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvsinpi(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = cos(pi * x[i])
pub extern fn vvcospif(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvcospi(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = tan(pi * x[i])
pub extern fn vvtanpif(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvtanpi(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// sincos: sin_out[i] = sin(x[i]), cos_out[i] = cos(x[i])
pub extern fn vvsincosf(sin_out: [*]f32, cos_out: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvsincos(sin_out: [*]f64, cos_out: [*]f64, x: [*]const f64, n: *const c_int) void;

// ============================================================================
// Inverse trigonometric
// ============================================================================

// y[i] = asin(x[i])
pub extern fn vvasinf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvasin(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = acos(x[i])
pub extern fn vvacosf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvacos(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = atan(x[i])
pub extern fn vvatanf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvatan(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// z[i] = atan2(y[i], x[i])
pub extern fn vvatan2f(z: [*]f32, y: [*]const f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvatan2(z: [*]f64, y: [*]const f64, x: [*]const f64, n: *const c_int) void;

// ============================================================================
// Hyperbolic
// ============================================================================

// y[i] = sinh(x[i])
pub extern fn vvsinhf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvsinh(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = cosh(x[i])
pub extern fn vvcoshf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvcosh(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = tanh(x[i])
pub extern fn vvtanhf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvtanh(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// ============================================================================
// Inverse hyperbolic
// ============================================================================

// y[i] = asinh(x[i])
pub extern fn vvasinhf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvasinh(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = acosh(x[i])
pub extern fn vvacoshf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvacosh(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = atanh(x[i])
pub extern fn vvatanhf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvatanh(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// ============================================================================
// Rounding
// ============================================================================

// y[i] = trunc(x[i]) (round towards zero)
pub extern fn vvintf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvint(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = round(x[i]) (round to nearest, ties to even)
pub extern fn vvnintf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvnint(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = ceil(x[i])
pub extern fn vvceilf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvceil(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// y[i] = floor(x[i])
pub extern fn vvfloorf(y: [*]f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvfloor(y: [*]f64, x: [*]const f64, n: *const c_int) void;

// ============================================================================
// Modular arithmetic
// ============================================================================

// z[i] = fmod(y[i], x[i])
pub extern fn vvfmodf(z: [*]f32, y: [*]const f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvfmod(z: [*]f64, y: [*]const f64, x: [*]const f64, n: *const c_int) void;

// z[i] = remainder(y[i], x[i])
pub extern fn vvremainderf(z: [*]f32, y: [*]const f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvremainder(z: [*]f64, y: [*]const f64, x: [*]const f64, n: *const c_int) void;

// ============================================================================
// Sign and next-after
// ============================================================================

// z[i] = copysign(y[i], x[i])
pub extern fn vvcopysignf(z: [*]f32, y: [*]const f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvcopysign(z: [*]f64, y: [*]const f64, x: [*]const f64, n: *const c_int) void;

// z[i] = nextafter(y[i], x[i])
pub extern fn vvnextafterf(z: [*]f32, y: [*]const f32, x: [*]const f32, n: *const c_int) void;
pub extern fn vvnextafter(z: [*]f64, y: [*]const f64, x: [*]const f64, n: *const c_int) void;

// ============================================================================
// Complex exponential
// ============================================================================

pub const FloatComplex = extern struct { real: f32, imag: f32 };
pub const DoubleComplex = extern struct { real: f64, imag: f64 };

// C[i] = cos(x[i]) + i*sin(x[i])
pub extern fn vvcosisinf(c_out: [*]FloatComplex, x: [*]const f32, n: *const c_int) void;
pub extern fn vvcosisin(c_out: [*]DoubleComplex, x: [*]const f64, n: *const c_int) void;

