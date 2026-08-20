const std = @import("std");
const types = @import("types.zig");
const fft = @import("fft.zig");
const Direction = fft.Direction;
const c = @import("c.zig");
const SC = types.SplitComplex;

/// vDSP_FFT16_copv performs a 16-element FFT on interleaved complex
/// unit-stride vector-block-aligned data.
///
/// Parameters:
///
///     float *Output
///
///         Pointer to space for output data (interleaved complex).  This
///         address must be vector-block aligned.
///
///     const float *Input
///
///         Pointer to input data (interleaved complex).  This address must be
///         vector-block aligned.
///
///     FFT_Direction Direction
///
///         Transform direction, FFT_FORWARD or FFT_INVERSE.
///
/// This routine calculates:
///
///     For 0 <= k < 16,
///
///         H[k] = sum(1**(S * j*k/16) * h[j], 0 <= j < 16),
///
/// where:
///
///     N is 16,
///
///     h[j] is Input[2*j+0] + i * Input[2*j+1] at routine entry,
///
///     H[j] is Output[2*j+0] + i * Output[2*j+1] at routine exit,
///
///     S is -1 if Direction is FFT_FORWARD and +1 if Direction is FFT_INVERSE,
///     and
///
///     1**x is e**(2*pi*i*x).
///
/// Input and Output may be equal but may not otherwise overlap.
pub fn fft16_copv(output: *[32]f32, input: *const [32]f32, direction: Direction) void {
    c.vDSP_FFT16_copv(output, input, @intFromEnum(direction));
}

/// vDSP_FFT32_copv performs a 32-element FFT on interleaved complex
/// unit-stride vector-block-aligned data.
///
/// Parameters:
///
///     float *Output
///
///         Pointer to space for output data (interleaved complex).  This
///         address must be vector-block aligned.
///
///     const float *Input
///
///         Pointer to input data (interleaved complex).  This address must be
///         vector-block aligned.
///
///     FFT_Direction Direction
///
///         Transform direction, FFT_FORWARD or FFT_INVERSE.
///
/// This routine calculates:
///
///     For 0 <= k < 32,
///
///         H[k] = sum(1**(S * j*k/32) * h[j], 0 <= j < 32),
///
/// where:
///
///     N is 32,
///
///     h[j] is Input[2*j+0] + i * Input[2*j+1] at routine entry,
///
///     H[j] is Output[2*j+0] + i * Output[2*j+1] at routine exit,
///
///     S is -1 if Direction is FFT_FORWARD and +1 if Direction is FFT_INVERSE,
///     and
///
///     1**x is e**(2*pi*i*x).
///
/// Input and Output may be equal but may not otherwise overlap.
pub fn fft32_copv(output: *[64]f32, input: *const [64]f32, direction: Direction) void {
    c.vDSP_FFT32_copv(output, input, @intFromEnum(direction));
}

/// vDSP_FFT16_zopv performs a 16-element FFT on separated complex
/// unit-stride vector-block-aligned data.
///
/// Parameters:
///
///     float *Or, float *Oi
///
///         Pointers to space for real and imaginary output data.  These
///         addresses must be vector-block aligned.
///
///     const float *Ir, *Ii
///
///         Pointers to real and imaginary input data.  These addresses must be
///         vector-block aligned.
///
///     FFT_Direction Direction
///
///         Transform direction, FFT_FORWARD or FFT_INVERSE.
///
/// This routine calculates:
///
///     For 0 <= k < 16,
///
///         H[k] = sum(1**(S * j*k/16) * h[j], 0 <= j < 16),
///
/// where:
///
///     N is 16,
///
///     h[j] is Ir[j] + i * Ii[j] at routine entry,
///
///     H[j] is Or[j] + i * Oi[j] at routine exit,
///
///     S is -1 if Direction is FFT_FORWARD and +1 if Direction is FFT_INVERSE,
///     and
///
///     1**x is e**(2*pi*i*x).
///
/// Or may equal Ir or Ii, and Oi may equal Ii or Ir, but the arrays may not
/// otherwise overlap.
pub fn fft16_zopv(out_real: *[16]f32, out_imag: *[16]f32, in_real: *const [16]f32, in_imag: *const [16]f32, direction: Direction) void {
    c.vDSP_FFT16_zopv(out_real, out_imag, in_real, in_imag, @intFromEnum(direction));
}

/// vDSP_FFT32_zopv performs a 32-element FFT on separated complex
/// unit-stride vector-block-aligned data.
///
/// Parameters:
///
///     float *Or, float *Oi
///
///         Pointers to space for real and imaginary output data.  These
///         addresses must be vector-block aligned.
///
///     const float *Ir, *Ii
///
///         Pointers to real and imaginary input data.  These addresses must be
///         vector-block aligned.
///
///     FFT_Direction Direction
///
///         Transform direction, FFT_FORWARD or FFT_INVERSE.
///
/// This routine calculates:
///
///     For 0 <= k < 32,
///
///         H[k] = sum(1**(S * j*k/32) * h[j], 0 <= j < 32),
///
/// where:
///
///     N is 32,
///
///     h[j] is Ir[j] + i * Ii[j] at routine entry,
///
///     H[j] is Or[j] + i * Oi[j] at routine exit,
///
///     S is -1 if Direction is FFT_FORWARD and +1 if Direction is FFT_INVERSE,
///     and
///
///     1**x is e**(2*pi*i*x).
///
/// Or may equal Ir or Ii, and Oi may equal Ii or Ir, but the arrays may not
/// otherwise overlap.
pub fn fft32_zopv(out_real: *[32]f32, out_imag: *[32]f32, in_real: *const [32]f32, in_imag: *const [32]f32, direction: Direction) void {
    c.vDSP_FFT32_zopv(out_real, out_imag, in_real, in_imag, @intFromEnum(direction));
}

// ============================================================================
// Tests
// ============================================================================
//
// vDSP.h's pseudocode for these four routines (unlike vDSP_fft_zip/zop, whose
// doc comment incorrectly claims a 1/N inverse scale - see fft.zig) does not
// claim any normalization at all: "H[k] = sum(1**(S*j*k/N)*h[j])" with no
// leading `scale` term. The tests below both hand-verify the impulse
// closed-form and cross-check against the already-verified general
// FFT(f32).zip at the same N, and confirm empirically that these routines
// are likewise unnormalized in both directions (consistent with
// fix/REQUEST.md's note that vDSP FFTs generally are not normalized).

test "fft16_zopv forward: impulse closed form" {
    // For an impulse h[0] = a + i*b (rest zero), the DFT sum collapses to
    // its single j=0 term for every k, since 1**(S*0*k/N) = 1 regardless of
    // k. So H[k] = a + i*b for all 0 <= k < 16. Using a != b (asymmetric)
    // means a real/imaginary argument-order bug (e.g. Or/Oi or Ir/Ii
    // swapped) would show up as the real and imaginary output arrays being
    // swapped, which this test would catch.
    const a: f32 = 3.0;
    const b: f32 = -7.0;
    var in_re = [_]f32{0.0} ** 16;
    var in_im = [_]f32{0.0} ** 16;
    in_re[0] = a;
    in_im[0] = b;

    var out_re: [16]f32 = undefined;
    var out_im: [16]f32 = undefined;
    fft16_zopv(&out_re, &out_im, &in_re, &in_im, .forward);

    for (out_re) |v| try std.testing.expectApproxEqAbs(a, v, 0.001);
    for (out_im) |v| try std.testing.expectApproxEqAbs(b, v, 0.001);
}

test "fft32_zopv forward: impulse closed form" {
    const a: f32 = -5.0;
    const b: f32 = 2.0;
    var in_re = [_]f32{0.0} ** 32;
    var in_im = [_]f32{0.0} ** 32;
    in_re[0] = a;
    in_im[0] = b;

    var out_re: [32]f32 = undefined;
    var out_im: [32]f32 = undefined;
    fft32_zopv(&out_re, &out_im, &in_re, &in_im, .forward);

    for (out_re) |v| try std.testing.expectApproxEqAbs(a, v, 0.001);
    for (out_im) |v| try std.testing.expectApproxEqAbs(b, v, 0.001);
}

test "fft16_zopv forward+inverse round-trip is unnormalized (N times original)" {
    // Empirically confirm the same unnormalized-both-directions behavior
    // found for the general FFT(T).zip in fft.zig transfers to this fixed-
    // size routine, rather than assuming it - vDSP.h's pseudocode for THIS
    // routine doesn't even claim a 1/N scale (unlike vDSP_fft_zip/zop's
    // doc, which incorrectly does), so there's no doc bug to fix here, but
    // the actual runtime scaling behavior is still worth pinning down.
    const a: f32 = 1.0;
    const b: f32 = 0.0;
    var re = [_]f32{0.0} ** 16;
    var im = [_]f32{0.0} ** 16;
    re[0] = a;
    im[0] = b;

    var fwd_re: [16]f32 = undefined;
    var fwd_im: [16]f32 = undefined;
    fft16_zopv(&fwd_re, &fwd_im, &re, &im, .forward);

    var inv_re: [16]f32 = undefined;
    var inv_im: [16]f32 = undefined;
    fft16_zopv(&inv_re, &inv_im, &fwd_re, &fwd_im, .inverse);

    const n: f32 = 16.0;
    try std.testing.expectApproxEqAbs(n * a, inv_re[0], 0.01);
    try std.testing.expectApproxEqAbs(n * b, inv_im[0], 0.01);
    for (inv_re[1..]) |v| try std.testing.expectApproxEqAbs(@as(f32, 0.0), v, 0.01);
    for (inv_im[1..]) |v| try std.testing.expectApproxEqAbs(@as(f32, 0.0), v, 0.01);
}

test "fft16_zopv forward cross-checked against FFT(f32).zip at N=16" {
    // Asymmetric, non-repeating input so any argument-order bug (real vs.
    // imaginary, input vs. output) would produce a detectably different
    // result than the already-verified general FFT.zip path.
    var in_re = [_]f32{ 1.0, -2.5, 3.25, 0.0, 4.75, -1.0, 2.0, -3.5, 5.0, -0.25, 1.5, -4.0, 0.5, 2.75, -1.75, 3.0 };
    var in_im = [_]f32{ 0.5, 1.5, -2.0, 3.0, -0.5, 2.5, -1.5, 0.25, -3.0, 1.0, -0.75, 4.0, -2.25, 0.0, 1.25, -3.25 };

    var out_re: [16]f32 = undefined;
    var out_im: [16]f32 = undefined;
    fft16_zopv(&out_re, &out_im, &in_re, &in_im, .forward);

    var re2 = in_re;
    var im2 = in_im;
    const setup = try fft.FFT(f32).init(4, .radix2); // N = 1 << 4 = 16
    defer setup.deinit();
    const io = SC(f32){ .realp = &re2, .imagp = &im2 };
    setup.zip(&io, .forward);

    for (out_re, 0..) |v, i| try std.testing.expectApproxEqAbs(re2[i], v, 0.05);
    for (out_im, 0..) |v, i| try std.testing.expectApproxEqAbs(im2[i], v, 0.05);
}

test "fft32_zopv forward cross-checked against FFT(f32).zip at N=32" {
    var in_re: [32]f32 = undefined;
    var in_im: [32]f32 = undefined;
    for (&in_re, 0..) |*v, i| v.* = @as(f32, @floatFromInt(i)) * 0.37 - 5.0;
    for (&in_im, 0..) |*v, i| v.* = @as(f32, @floatFromInt(i)) * -0.19 + 2.5;

    var out_re: [32]f32 = undefined;
    var out_im: [32]f32 = undefined;
    fft32_zopv(&out_re, &out_im, &in_re, &in_im, .forward);

    var re2 = in_re;
    var im2 = in_im;
    const setup = try fft.FFT(f32).init(5, .radix2); // N = 1 << 5 = 32
    defer setup.deinit();
    const io = SC(f32){ .realp = &re2, .imagp = &im2 };
    setup.zip(&io, .forward);

    for (out_re, 0..) |v, i| try std.testing.expectApproxEqAbs(re2[i], v, 0.05);
    for (out_im, 0..) |v, i| try std.testing.expectApproxEqAbs(im2[i], v, 0.05);
}

test "fft16_copv forward matches fft16_zopv forward (interleaved vs split layout)" {
    // Both routines share the exact same header pseudocode and Direction
    // convention; the only difference is data layout (interleaved
    // Output[2*j+0]/Output[2*j+1] vs. separate Or/Oi arrays). Interleaving
    // the same asymmetric input both ways and comparing outputs verifies
    // fft16_copv's interleave indexing (Output[2*j+0] = real, [2*j+1] =
    // imag) matches the documented convention, not swapped.
    var in_re = [_]f32{ 1.0, -2.5, 3.25, 0.0, 4.75, -1.0, 2.0, -3.5, 5.0, -0.25, 1.5, -4.0, 0.5, 2.75, -1.75, 3.0 };
    var in_im = [_]f32{ 0.5, 1.5, -2.0, 3.0, -0.5, 2.5, -1.5, 0.25, -3.0, 1.0, -0.75, 4.0, -2.25, 0.0, 1.25, -3.25 };

    var zopv_out_re: [16]f32 = undefined;
    var zopv_out_im: [16]f32 = undefined;
    fft16_zopv(&zopv_out_re, &zopv_out_im, &in_re, &in_im, .forward);

    var interleaved_in: [32]f32 = undefined;
    for (0..16) |j| {
        interleaved_in[2 * j + 0] = in_re[j];
        interleaved_in[2 * j + 1] = in_im[j];
    }
    var interleaved_out: [32]f32 = undefined;
    fft16_copv(&interleaved_out, &interleaved_in, .forward);

    for (0..16) |j| {
        try std.testing.expectApproxEqAbs(zopv_out_re[j], interleaved_out[2 * j + 0], 0.01);
        try std.testing.expectApproxEqAbs(zopv_out_im[j], interleaved_out[2 * j + 1], 0.01);
    }
}

test "fft32_copv forward matches fft32_zopv forward (interleaved vs split layout)" {
    var in_re: [32]f32 = undefined;
    var in_im: [32]f32 = undefined;
    for (&in_re, 0..) |*v, i| v.* = @as(f32, @floatFromInt(i)) * 0.37 - 5.0;
    for (&in_im, 0..) |*v, i| v.* = @as(f32, @floatFromInt(i)) * -0.19 + 2.5;

    var zopv_out_re: [32]f32 = undefined;
    var zopv_out_im: [32]f32 = undefined;
    fft32_zopv(&zopv_out_re, &zopv_out_im, &in_re, &in_im, .forward);

    var interleaved_in: [64]f32 = undefined;
    for (0..32) |j| {
        interleaved_in[2 * j + 0] = in_re[j];
        interleaved_in[2 * j + 1] = in_im[j];
    }
    var interleaved_out: [64]f32 = undefined;
    fft32_copv(&interleaved_out, &interleaved_in, .forward);

    for (0..32) |j| {
        try std.testing.expectApproxEqAbs(zopv_out_re[j], interleaved_out[2 * j + 0], 0.05);
        try std.testing.expectApproxEqAbs(zopv_out_im[j], interleaved_out[2 * j + 1], 0.05);
    }
}

test "fft16_copv in-place (Input == Output) matches out-of-place result" {
    // Header explicitly documents "Input and Output may be equal but may
    // not otherwise overlap" - verify the in-place call path actually works
    // and produces the same result as the out-of-place call.
    const original = [_]f32{ 1.0, -2.5, 3.25, 0.0, 4.75, -1.0, 2.0, -3.5, 5.0, -0.25, 1.5, -4.0, 0.5, 2.75, -1.75, 3.0, 0.5, 1.5, -2.0, 3.0, -0.5, 2.5, -1.5, 0.25, -3.0, 1.0, -0.75, 4.0, -2.25, 0.0, 1.25, -3.25 };

    var out_of_place_in = original;
    var out_of_place_out: [32]f32 = undefined;
    fft16_copv(&out_of_place_out, &out_of_place_in, .forward);

    var in_place_buf = original;
    fft16_copv(&in_place_buf, &in_place_buf, .forward);

    for (out_of_place_out, 0..) |v, i| try std.testing.expectApproxEqAbs(v, in_place_buf[i], 0.01);
}
