const types = @import("types.zig");
const Length = types.Length;
const SC = types.SplitComplex;
const c = @import("c.zig");

/// Convolution and correlation.
///
/// Computes:
///
///     for (n = 0; n < N; ++n)
///         C[n] = sum(A[n+p] * F[p], 0 <= p < P);
///
/// Commonly, this is called correlation if IF is positive and convolution
/// if IF is negative.
pub fn conv(comptime T: type, signal: []const T, filter: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_conv(signal.ptr, 1, filter.ptr, 1, out.ptr, 1, out.len, filter.len),
        f64 => c.vDSP_convD(signal.ptr, 1, filter.ptr, 1, out.ptr, 1, out.len, filter.len),
        else => @compileError("conv requires f32 or f64"),
    }
}

/// Two-dimensional (image) convolution.
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
pub fn imgfir(comptime T: type, image: [*]const T, rows: Length, cols: Length, kernel: [*]const T, out: [*]T, kr: Length, kc: Length) void {
    switch (T) {
        f32 => c.vDSP_imgfir(image, rows, cols, kernel, out, kr, kc),
        f64 => c.vDSP_imgfirD(image, rows, cols, kernel, out, kr, kc),
        else => @compileError("imgfir requires f32 or f64"),
    }
}

/// 3x3 convolution.
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
pub fn f3x3(comptime T: type, image: [*]const T, rows: Length, cols: Length, kernel: *const [9]T, out: [*]T) void {
    switch (T) {
        f32 => c.vDSP_f3x3(image, rows, cols, kernel, out),
        f64 => c.vDSP_f3x3D(image, rows, cols, kernel, out),
        else => @compileError("f3x3 requires f32 or f64"),
    }
}

/// 5x5 convolution.
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
pub fn f5x5(comptime T: type, image: [*]const T, rows: Length, cols: Length, kernel: *const [25]T, out: [*]T) void {
    switch (T) {
        f32 => c.vDSP_f5x5(image, rows, cols, kernel, out),
        f64 => c.vDSP_f5x5D(image, rows, cols, kernel, out),
        else => @compileError("f5x5 requires f32 or f64"),
    }
}

pub fn deq22(comptime T: type, a: []const T, coeffs: *const [5]T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_deq22(a.ptr, 1, coeffs, out.ptr, 1, out.len),
        f64 => c.vDSP_deq22D(a.ptr, 1, coeffs, out.ptr, 1, out.len),
        else => @compileError("deq22 requires f32 or f64"),
    }
}

// -- Complex convolution --

/// Complex convolution and correlation.
///
/// Computes:
///
///     for (n = 0; n < N; ++n)
///         C[n] = sum(A[n+p] * F[p], 0 <= p < P);
///
/// Commonly, this is called correlation if IF is positive and convolution
/// if IF is negative.
pub fn zconv(comptime T: type, signal: *const SC(T), filter: *const SC(T), out: *SC(T), n: Length, p: Length) void {
    switch (T) {
        f32 => c.vDSP_zconv(signal, 1, filter, 1, out, 1, n, p),
        f64 => c.vDSP_zconvD(signal, 1, filter, 1, out, 1, n, p),
        else => @compileError("zconv requires f32 or f64"),
    }
}
