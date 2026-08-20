const std = @import("std");
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
///
/// N is out.len, P is filter.len. The highest index of `signal` read is
/// `out.len - 1 + filter.len - 1`, so `signal` must have at least
/// `out.len + filter.len - 1` elements.
pub fn conv(comptime T: type, signal: []const T, filter: []const T, out: []T) void {
    std.debug.assert(signal.len >= out.len + filter.len - 1);
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
///
/// `image`/`out` must have at least `rows * cols` elements and `kernel` at
/// least `kr * kc` elements; these are raw pointers (matching vDSP.h, which
/// takes no stride for this routine), so the caller is responsible for
/// sizing them - there is no slice length to assert against here.
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

/// Difference equation, 2 poles, 2 zeros (a specific IIR "deemphasis"
/// filter). This is NOT the same filter structure as `Biquad`/`Biquadm`.
///
/// `coeffs` is `[B0, B1, B2, B3, B4]` and computes, for n in [2, n_out+2):
///
///     C[n] = A[n]*B0 + A[n-1]*B1 + A[n-2]*B2 - C[n-1]*B3 - C[n-2]*B4;
///
/// CAUTION (confirmed by runtime probe, not documented in vDSP.h beyond the
/// pseudocode's terse "Note outputs start with C[2]"): the C function writes
/// its `n_out` output samples at *relative* indices `[2, n_out+2)` of the
/// buffer pointed to by `out`, not `[0, n_out)`. Equivalently, `out[0]` and
/// `out[1]` are read as history (the previous two output samples - the
/// `C[n-1]`/`C[n-2]` terms for the first two computed outputs) and are never
/// written; the freshly computed samples land in `out[2..n_out+2)`. The
/// same offset applies to `a`: `a[0]` and `a[1]` are history input samples,
/// and the `n_out` new input samples to filter are `a[2..n_out+2)`.
///
/// The previous version of this wrapper passed `out.len` directly as the
/// vDSP `N` parameter while giving the C function only `out.len` elements of
/// buffer - since the C function always writes up to relative index
/// `N+1 = out.len+1`, this was an out-of-bounds write of (at least) 2
/// elements for every call, and the first two elements of `out` were never
/// filled despite the old (nonexistent) doc comment implying `out` held the
/// N results directly. Confirmed empirically: calling the C function with a
/// sentinel-filled buffer showed writes only at relative offsets [2, N+2).
/// See vDSP.h:3940-3967 for the pseudocode this is derived from.
pub fn deq22(comptime T: type, a: []const T, coeffs: *const [5]T, out: []T, n_out: Length) void {
    std.debug.assert(a.len >= n_out + 2);
    std.debug.assert(out.len >= n_out + 2);
    switch (T) {
        f32 => c.vDSP_deq22(a.ptr, 1, coeffs, out.ptr, 1, n_out),
        f64 => c.vDSP_deq22D(a.ptr, 1, coeffs, out.ptr, 1, n_out),
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

// ============================================================================
// Tests
// ============================================================================

test "conv" {
    // Asymmetric, non-arithmetic signal so a signal/filter argument-order
    // bug (or a wrong output-length convention) produces visibly wrong,
    // distinguishable numbers rather than a coincidental match.
    const signal = [_]f32{ 1, 2, 4, 8, 16 };
    const filter = [_]f32{ 1, 0, -1 }; // C[n] = A[n] - A[n+2]
    var out: [3]f32 = undefined;
    conv(f32, &signal, &filter, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ -3, -6, -12 }, &out);
}

test "conv f64" {
    const signal = [_]f64{ 1, 2, 4, 8, 16 };
    const filter = [_]f64{ 1, 0, -1 };
    var out: [3]f64 = undefined;
    conv(f64, &signal, &filter, &out);
    try std.testing.expectEqualSlices(f64, &[_]f64{ -3, -6, -12 }, &out);
}

test "imgfir picks the documented [P/2][Q/2]-relative neighbor" {
    // Non-square image (3 rows x 5 cols) so a rows/cols argument swap would
    // misbehave rather than silently "work". Kernel picks out A[r][c-1]
    // (only F[1][0] = 1) so only interior row r=1, cols c=1..3 are nonzero,
    // and the value should equal the *left* neighbor, pinning down which
    // kernel axis is rows vs columns.
    const rows: Length = 3;
    const cols: Length = 5;
    const image = [_]f32{
        1,   2,   3,   4,   5,
        10,  20,  30,  40,  50,
        100, 200, 300, 400, 500,
    };
    const kernel = [_]f32{
        0, 0, 0,
        1, 0, 0,
        0, 0, 0,
    };
    var out: [15]f32 = undefined;
    imgfir(f32, &image, rows, cols, &kernel, &out, 3, 3);
    const expected = [_]f32{
        0, 0,  0,  0,  0,
        0, 10, 20, 30, 0,
        0, 0,  0,  0,  0,
    };
    try std.testing.expectEqualSlices(f32, &expected, &out);
}

test "imgfir identity kernel reproduces input in the interior" {
    const rows: Length = 4;
    const cols: Length = 4;
    const image = [_]f32{
        1,  2,  3,  4,
        5,  6,  7,  8,
        9,  10, 11, 12,
        13, 14, 15, 16,
    };
    const kernel = [_]f32{
        0, 0, 0,
        0, 1, 0,
        0, 0, 0,
    };
    var out: [16]f32 = undefined;
    imgfir(f32, &image, rows, cols, &kernel, &out, 3, 3);
    const expected = [_]f32{
        0, 0,  0,  0,
        0, 6,  7,  0,
        0, 10, 11, 0,
        0, 0,  0,  0,
    };
    try std.testing.expectEqualSlices(f32, &expected, &out);
}

test "f3x3 matches imgfir at the same 3x3 kernel size" {
    const rows: Length = 3;
    const cols: Length = 5;
    const image = [_]f32{
        1,   2,   3,   4,   5,
        10,  20,  30,  40,  50,
        100, 200, 300, 400, 500,
    };
    const kernel = [_]f32{
        1, 0, -2,
        0, 3, 0,
        -1, 0, 1,
    };
    var out_f3x3: [15]f32 = undefined;
    var out_imgfir: [15]f32 = undefined;
    f3x3(f32, &image, rows, cols, &kernel, &out_f3x3);
    imgfir(f32, &image, rows, cols, &kernel, &out_imgfir, 3, 3);
    try std.testing.expectEqualSlices(f32, &out_imgfir, &out_f3x3);
}

test "f3x3 identity kernel reproduces input in the interior" {
    const rows: Length = 3;
    const cols: Length = 4;
    const image = [_]f32{
        1, 2,  3,  4,
        5, 6,  7,  8,
        9, 10, 11, 12,
    };
    const kernel = [_]f32{
        0, 0, 0,
        0, 1, 0,
        0, 0, 0,
    };
    var out: [12]f32 = undefined;
    f3x3(f32, &image, rows, cols, &kernel, &out);
    const expected = [_]f32{
        0, 0, 0, 0,
        0, 6, 7, 0,
        0, 0, 0, 0,
    };
    try std.testing.expectEqualSlices(f32, &expected, &out);
}

test "f5x5 matches imgfir at the same 5x5 kernel size" {
    const rows: Length = 5;
    const cols: Length = 7;
    var image: [35]f32 = undefined;
    for (0..rows) |r| {
        for (0..cols) |col| {
            image[r * cols + col] = @floatFromInt(100 * r + col);
        }
    }
    var kernel: [25]f32 = undefined;
    for (&kernel, 0..) |*v, i| v.* = @floatFromInt(i);

    var out_f5x5: [35]f32 = undefined;
    var out_imgfir: [35]f32 = undefined;
    f5x5(f32, &image, rows, cols, &kernel, &out_f5x5);
    imgfir(f32, &image, rows, cols, &kernel, &out_imgfir, 5, 5);
    try std.testing.expectEqualSlices(f32, &out_imgfir, &out_f5x5);
}

test "f5x5 picks the documented [P/2][Q/2]-relative neighbor" {
    // Non-square image (5 rows x 7 cols). Kernel has a single 1 at
    // F[j+2][k+2] = F[0][3] (j=-2, k=1), so C[r][c] = A[r-2][c+1]. Only
    // interior row r=2, cols c=2..4 are nonzero.
    const rows: Length = 5;
    const cols: Length = 7;
    var image: [35]f32 = undefined;
    for (0..rows) |r| {
        for (0..cols) |col| {
            image[r * cols + col] = @floatFromInt(100 * r + col);
        }
    }
    var kernel = [_]f32{0} ** 25;
    kernel[0 * 5 + 3] = 1; // F[0][3]

    var out: [35]f32 = undefined;
    f5x5(f32, &image, rows, cols, &kernel, &out);

    var expected = [_]f32{0} ** 35;
    expected[2 * cols + 2] = 3; // A[0][3]
    expected[2 * cols + 3] = 4; // A[0][4]
    expected[2 * cols + 4] = 5; // A[0][5]
    try std.testing.expectEqualSlices(f32, &expected, &out);
}

test "deq22 identity coefficients pass signal through with the [2, n+2) offset" {
    // B = [1, 0, 0, 0, 0] means C[n] = A[n] with no dependence on history,
    // so this isolates the buffer-offset convention without needing to
    // hand-verify the recursive filter math.
    const a = [_]f32{ -999, -999, 1, 2, 4, 8, 16 }; // a[0..2) history unused by B
    const coeffs = [_]f32{ 1, 0, 0, 0, 0 };
    var out = [_]f32{ -999, -999, -999, -999, -999, -999, -999 };
    deq22(f32, &a, &coeffs, &out, 5);
    try std.testing.expectEqualSlices(f32, &[_]f32{ -999, -999, 1, 2, 4, 8, 16 }, &out);
}

test "deq22 full 2-pole-2-zero recursion matches the header formula" {
    // B0=1, B1=0.5, B2=0.25, B3=0.5 (feedback from C[n-1]), B4=0.25
    // (feedback from C[n-2]). History a[0]=a[1]=0, out history
    // out[0]=out[1]=0 (cold start). New input a[2..]=[1,1,1,1].
    const coeffs = [_]f32{ 1.0, 0.5, 0.25, 0.5, 0.25 };
    const a = [_]f32{ 0, 0, 1, 1, 1, 1 };
    var out = [_]f32{ 0, 0, 0, 0, 0, 0 };
    deq22(f32, &a, &coeffs, &out, 4);

    // Hand-compute via the header's formula:
    //   C[n] = A[n]*B0 + A[n-1]*B1 + A[n-2]*B2 - C[n-1]*B3 - C[n-2]*B4
    var expect = [_]f32{ 0, 0, 0, 0, 0, 0 };
    const A = a;
    var n: usize = 2;
    while (n < 6) : (n += 1) {
        expect[n] = A[n] * coeffs[0] + A[n - 1] * coeffs[1] + A[n - 2] * coeffs[2] -
            expect[n - 1] * coeffs[3] - expect[n - 2] * coeffs[4];
    }
    try std.testing.expectApproxEqAbs(expect[2], out[2], 0.0001);
    try std.testing.expectApproxEqAbs(expect[3], out[3], 0.0001);
    try std.testing.expectApproxEqAbs(expect[4], out[4], 0.0001);
    try std.testing.expectApproxEqAbs(expect[5], out[5], 0.0001);
}

test "zconv matches conv componentwise for a real filter" {
    var signal_re = [_]f32{ 1, 2, 4, 8, 16 };
    var signal_im = [_]f32{ 0, 1, 0, -1, 0 };
    var filter_re = [_]f32{ 1, 0, -1 };
    var filter_im = [_]f32{ 0, 0, 0 };
    const signal = SC(f32){ .realp = &signal_re, .imagp = &signal_im };
    const filter = SC(f32){ .realp = &filter_re, .imagp = &filter_im };

    var out_re = [_]f32{ 0, 0, 0 };
    var out_im = [_]f32{ 0, 0, 0 };
    var out = SC(f32){ .realp = &out_re, .imagp = &out_im };

    zconv(f32, &signal, &filter, &out, 3, 3);

    try std.testing.expectEqualSlices(f32, &[_]f32{ -3, -6, -12 }, &out_re);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 0, 2, 0 }, &out_im);
}
