const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;
const SplitComplex = types.SplitComplex;
const DoubleSplitComplex = types.DoubleSplitComplex;

const c = struct {
    extern fn vDSP_conv(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_convD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_zconv(A: *const SplitComplex, IA: Stride, F: *const SplitComplex, IF: Stride, C: *const SplitComplex, IC: Stride, N: Length, P: Length) void;
    extern fn vDSP_zconvD(A: *const DoubleSplitComplex, IA: Stride, F: *const DoubleSplitComplex, IF: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length, P: Length) void;
    extern fn vDSP_imgfir(A: [*]const f32, NR: Length, NC: Length, B: [*]const f32, C: [*]f32, M: Length, N: Length) void;
    extern fn vDSP_imgfirD(A: [*]const f64, NR: Length, NC: Length, B: [*]const f64, C: [*]f64, M: Length, N: Length) void;
    extern fn vDSP_f3x3(A: [*]const f32, NR: Length, NC: Length, B: [*]const f32, C: [*]f32) void;
    extern fn vDSP_f3x3D(A: [*]const f64, NR: Length, NC: Length, B: [*]const f64, C: [*]f64) void;
    extern fn vDSP_f5x5(A: [*]const f32, NR: Length, NC: Length, B: [*]const f32, C: [*]f32) void;
    extern fn vDSP_f5x5D(A: [*]const f64, NR: Length, NC: Length, B: [*]const f64, C: [*]f64) void;
    extern fn vDSP_deq22(A: [*]const f32, IA: Stride, B: [*]const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_deq22D(A: [*]const f64, IA: Stride, B: [*]const f64, C: [*]f64, IC: Stride, N: Length) void;
};

/// Convolution and correlation (single-precision).
///
/// Computes:
///
///     for (n = 0; n < N; ++n)
///         C[n] = sum(A[n+p] * F[p], 0 <= p < P);
///
/// Commonly, this is called correlation if IF is positive and convolution
/// if IF is negative.
pub fn conv(signal: []const f32, filter: []const f32, out: []f32) void {
    c.vDSP_conv(signal.ptr, 1, filter.ptr, 1, out.ptr, 1, out.len, filter.len);
}
/// Convolution and correlation (double-precision).
///
/// Computes:
///
///     for (n = 0; n < N; ++n)
///         C[n] = sum(A[n+p] * F[p], 0 <= p < P);
///
/// Commonly, this is called correlation if IF is positive and convolution
/// if IF is negative.
pub fn convD(signal: []const f64, filter: []const f64, out: []f64) void {
    c.vDSP_convD(signal.ptr, 1, filter.ptr, 1, out.ptr, 1, out.len, filter.len);
}

/// Two-dimensional (image) convolution (single-precision).
///
/// A and C are regarded as two-dimensional matrices with dimensions [NR][NC].
/// F is regarded as a two-dimensional matrix with dimensions [P][Q].
///
/// Computes:
///
///     P and Q must be odd.  "P/2" and "Q/2" are evaluated with integer
///     arithmetic, so, if P is 3, P/2 is 1, not 1.5.
///
///     for (r = P/2; r < NR-P/2; ++r)
///     for (c = Q/2; c < NC-Q/2; ++c)
///         C[r][c] = sum(A[r+j][c+k] * F[j+P/2][k+Q/2],
///             -P/2 <= j <= P/2, -Q/2 <= k <= Q/2);
///
///     All other elements of C (borders of P/2 elements at the top and
///     bottom and Q/2 elements at the left and right) are set to zero.
pub fn imgfir(image: [*]const f32, rows: Length, cols: Length, kernel: [*]const f32, out: [*]f32, kr: Length, kc: Length) void {
    c.vDSP_imgfir(image, rows, cols, kernel, out, kr, kc);
}
/// Two-dimensional (image) convolution (double-precision).
///
/// A and C are regarded as two-dimensional matrices with dimensions [NR][NC].
/// F is regarded as a two-dimensional matrix with dimensions [P][Q].
///
/// Computes:
///
///     P and Q must be odd.  "P/2" and "Q/2" are evaluated with integer
///     arithmetic, so, if P is 3, P/2 is 1, not 1.5.
///
///     for (r = P/2; r < NR-P/2; ++r)
///     for (c = Q/2; c < NC-Q/2; ++c)
///         C[r][c] = sum(A[r+j][c+k] * F[j+P/2][k+Q/2],
///             -P/2 <= j <= P/2, -Q/2 <= k <= Q/2);
///
///     All other elements of C (borders of P/2 elements at the top and
///     bottom and Q/2 elements at the left and right) are set to zero.
pub fn imgfirD(image: [*]const f64, rows: Length, cols: Length, kernel: [*]const f64, out: [*]f64, kr: Length, kc: Length) void {
    c.vDSP_imgfirD(image, rows, cols, kernel, out, kr, kc);
}

/// 3x3 convolution (single-precision).
///
/// A and C are regarded as two-dimensional matrices with dimensions [NR][NC].
/// F is regarded as a two-dimensional matrix with dimensions [3][3].
///
/// Computes:
///
///     for (r = 1; r < NR-1; ++r)
///     for (c = 1; c < NC-1; ++c)
///         C[r][c] = sum(A[r+j][c+k] * F[j+1][k+1],
///             -1 <= j <= 1, -1 <= k <= 1);
///
///     All other elements of C (a border of 1 element around all four
///     sides) are set to zero.
pub fn f3x3(image: [*]const f32, rows: Length, cols: Length, kernel: *const [9]f32, out: [*]f32) void {
    c.vDSP_f3x3(image, rows, cols, kernel, out);
}
/// 3x3 convolution (double-precision).
///
/// A and C are regarded as two-dimensional matrices with dimensions [NR][NC].
/// F is regarded as a two-dimensional matrix with dimensions [3][3].
///
/// Computes:
///
///     for (r = 1; r < NR-1; ++r)
///     for (c = 1; c < NC-1; ++c)
///         C[r][c] = sum(A[r+j][c+k] * F[j+1][k+1],
///             -1 <= j <= 1, -1 <= k <= 1);
///
///     All other elements of C (a border of 1 element around all four
///     sides) are set to zero.
pub fn f3x3D(image: [*]const f64, rows: Length, cols: Length, kernel: *const [9]f64, out: [*]f64) void {
    c.vDSP_f3x3D(image, rows, cols, kernel, out);
}

/// 5x5 convolution (single-precision).
///
/// A and C are regarded as two-dimensional matrices with dimensions [NR][NC].
/// F is regarded as a two-dimensional matrix with dimensions [5][5].
///
/// Computes:
///
///     for (r = 2; r < NR-2; ++r)
///     for (c = 2; c < NC-2; ++c)
///         C[r][c] = sum(A[r+j][c+k] * F[j+2][k+2],
///             -2 <= j <= 2, -2 <= k <= 2);
///
///     All other elements of C (a border of 2 elements around all four
///     sides) are set to zero.
pub fn f5x5(image: [*]const f32, rows: Length, cols: Length, kernel: *const [25]f32, out: [*]f32) void {
    c.vDSP_f5x5(image, rows, cols, kernel, out);
}
/// 5x5 convolution (double-precision).
///
/// A and C are regarded as two-dimensional matrices with dimensions [NR][NC].
/// F is regarded as a two-dimensional matrix with dimensions [5][5].
///
/// Computes:
///
///     for (r = 2; r < NR-2; ++r)
///     for (c = 2; c < NC-2; ++c)
///         C[r][c] = sum(A[r+j][c+k] * F[j+2][k+2],
///             -2 <= j <= 2, -2 <= k <= 2);
///
///     All other elements of C (a border of 2 elements around all four
///     sides) are set to zero.
pub fn f5x5D(image: [*]const f64, rows: Length, cols: Length, kernel: *const [25]f64, out: [*]f64) void {
    c.vDSP_f5x5D(image, rows, cols, kernel, out);
}

pub fn deq22(a: []const f32, coeffs: *const [5]f32, out: []f32) void {
    c.vDSP_deq22(a.ptr, 1, coeffs, out.ptr, 1, out.len);
}
pub fn deq22D(a: []const f64, coeffs: *const [5]f64, out: []f64) void {
    c.vDSP_deq22D(a.ptr, 1, coeffs, out.ptr, 1, out.len);
}

// -- Complex convolution --

/// Complex convolution and correlation (single-precision).
///
/// Computes:
///
///     for (n = 0; n < N; ++n)
///         C[n] = sum(A[n+p] * F[p], 0 <= p < P);
///
/// Commonly, this is called correlation if IF is positive and convolution
/// if IF is negative.
pub fn zconv(signal: *const SplitComplex, filter: *const SplitComplex, out: *const SplitComplex, n: Length, p: Length) void {
    c.vDSP_zconv(signal, 1, filter, 1, out, 1, n, p);
}
/// Complex convolution and correlation (double-precision).
///
/// Computes:
///
///     for (n = 0; n < N; ++n)
///         C[n] = sum(A[n+p] * F[p], 0 <= p < P);
///
/// Commonly, this is called correlation if IF is positive and convolution
/// if IF is negative.
pub fn zconvD(signal: *const DoubleSplitComplex, filter: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length, p: Length) void {
    c.vDSP_zconvD(signal, 1, filter, 1, out, 1, n, p);
}
