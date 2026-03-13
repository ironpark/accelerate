const fft = @import("fft.zig");
const Direction = fft.Direction;

const c = struct {
    extern fn vDSP_FFT16_copv(Output: [*]f32, Input: [*]const f32, Direction: c_int) void;
    extern fn vDSP_FFT32_copv(Output: [*]f32, Input: [*]const f32, Direction: c_int) void;
    extern fn vDSP_FFT16_zopv(Or: [*]f32, Oi: [*]f32, Ir: [*]const f32, Ii: [*]const f32, Direction: c_int) void;
    extern fn vDSP_FFT32_zopv(Or: [*]f32, Oi: [*]f32, Ir: [*]const f32, Ii: [*]const f32, Direction: c_int) void;
};

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
