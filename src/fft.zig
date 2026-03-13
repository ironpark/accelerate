const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;
const SplitComplex = types.SplitComplex;
const DoubleSplitComplex = types.DoubleSplitComplex;

// ============================================================================
// Types
// ============================================================================

pub const FFTSetup = *opaque {};
pub const FFTSetupD = *opaque {};

pub const Direction = enum(c_int) {
    forward = 1,
    inverse = -1,
};

pub const Radix = enum(c_int) {
    radix2 = 0,
    radix3 = 1,
    radix5 = 2,
};

// ============================================================================
// Raw C extern declarations
// ============================================================================

const c = struct {
    // -- Setup / destroy --
    extern fn vDSP_create_fftsetup(Log2n: Length, Radix: c_int) ?FFTSetup;
    extern fn vDSP_create_fftsetupD(Log2n: Length, Radix: c_int) ?FFTSetupD;
    extern fn vDSP_destroy_fftsetup(setup: ?FFTSetup) void;
    extern fn vDSP_destroy_fftsetupD(setup: ?FFTSetupD) void;

    // -- Complex-to-complex, in-place (zip) --
    extern fn vDSP_fft_zip(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
    extern fn vDSP_fft_zipD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
    extern fn vDSP_fft_zipt(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, Buffer: *const SplitComplex, Log2N: Length, Direction: c_int) void;
    extern fn vDSP_fft_ziptD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, Direction: c_int) void;

    // -- Complex-to-complex, out-of-place (zop) --
    extern fn vDSP_fft_zop(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
    extern fn vDSP_fft_zopD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
    extern fn vDSP_fft_zopt(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, Buffer: *const SplitComplex, Log2N: Length, Direction: c_int) void;
    extern fn vDSP_fft_zoptD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, Direction: c_int) void;

    // -- Real-to-complex, in-place (zrip) --
    extern fn vDSP_fft_zrip(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
    extern fn vDSP_fft_zripD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
    extern fn vDSP_fft_zript(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, Buffer: *const SplitComplex, Log2N: Length, Direction: c_int) void;
    extern fn vDSP_fft_zriptD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, Direction: c_int) void;

    // -- Real-to-complex, out-of-place (zrop) --
    extern fn vDSP_fft_zrop(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
    extern fn vDSP_fft_zropD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
    extern fn vDSP_fft_zropt(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, Buffer: *const SplitComplex, Log2N: Length, Direction: c_int) void;
    extern fn vDSP_fft_zroptD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, Direction: c_int) void;

    // -- 2D complex-to-complex, in-place --
    extern fn vDSP_fft2d_zip(Setup: FFTSetup, C: *const SplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
    extern fn vDSP_fft2d_zipD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
    extern fn vDSP_fft2d_zipt(Setup: FFTSetup, C: *const SplitComplex, IC0: Stride, IC1: Stride, Buffer: *const SplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
    extern fn vDSP_fft2d_ziptD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Buffer: *const DoubleSplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;

    // -- 2D complex-to-complex, out-of-place --
    extern fn vDSP_fft2d_zop(Setup: FFTSetup, A: *const SplitComplex, IA0: Stride, IA1: Stride, C: *const SplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
    extern fn vDSP_fft2d_zopD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA0: Stride, IA1: Stride, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
    extern fn vDSP_fft2d_zopt(Setup: FFTSetup, A: *const SplitComplex, IA0: Stride, IA1: Stride, C: *const SplitComplex, IC0: Stride, IC1: Stride, Buffer: *const SplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
    extern fn vDSP_fft2d_zoptD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA0: Stride, IA1: Stride, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Buffer: *const DoubleSplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;

    // -- 2D real-to-complex, in-place --
    extern fn vDSP_fft2d_zrip(Setup: FFTSetup, C: *const SplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
    extern fn vDSP_fft2d_zripD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
    extern fn vDSP_fft2d_zript(Setup: FFTSetup, C: *const SplitComplex, IC0: Stride, IC1: Stride, Buffer: *const SplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
    extern fn vDSP_fft2d_zriptD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Buffer: *const DoubleSplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;

    // -- 2D real-to-complex, out-of-place --
    extern fn vDSP_fft2d_zrop(Setup: FFTSetup, A: *const SplitComplex, IA0: Stride, IA1: Stride, C: *const SplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
    extern fn vDSP_fft2d_zropD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA0: Stride, IA1: Stride, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
    extern fn vDSP_fft2d_zropt(Setup: FFTSetup, A: *const SplitComplex, IA0: Stride, IA1: Stride, C: *const SplitComplex, IC0: Stride, IC1: Stride, Buffer: *const SplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
    extern fn vDSP_fft2d_zroptD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA0: Stride, IA1: Stride, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Buffer: *const DoubleSplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;

    // -- Multiple FFT, complex in-place --
    extern fn vDSP_fftm_zip(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, IM: Stride, Log2N: Length, M: Length, Direction: c_int) void;
    extern fn vDSP_fftm_zipD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, IM: Stride, Log2N: Length, M: Length, Direction: c_int) void;
    extern fn vDSP_fftm_zipt(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, IM: Stride, Buffer: *const SplitComplex, Log2N: Length, M: Length, Direction: c_int) void;
    extern fn vDSP_fftm_ziptD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, IM: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, M: Length, Direction: c_int) void;

    // -- Multiple FFT, complex out-of-place --
    extern fn vDSP_fftm_zop(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, IMA: Stride, C: *const SplitComplex, IC: Stride, IMC: Stride, Log2N: Length, M: Length, Direction: c_int) void;
    extern fn vDSP_fftm_zopD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, IMA: Stride, C: *const DoubleSplitComplex, IC: Stride, IMC: Stride, Log2N: Length, M: Length, Direction: c_int) void;
    extern fn vDSP_fftm_zopt(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, IMA: Stride, C: *const SplitComplex, IC: Stride, IMC: Stride, Buffer: *const SplitComplex, Log2N: Length, M: Length, Direction: c_int) void;
    extern fn vDSP_fftm_zoptD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, IMA: Stride, C: *const DoubleSplitComplex, IC: Stride, IMC: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, M: Length, Direction: c_int) void;

    // -- Multiple FFT, real in-place --
    extern fn vDSP_fftm_zrip(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, IM: Stride, Log2N: Length, M: Length, Direction: c_int) void;
    extern fn vDSP_fftm_zripD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, IM: Stride, Log2N: Length, M: Length, Direction: c_int) void;
    extern fn vDSP_fftm_zript(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, IM: Stride, Buffer: *const SplitComplex, Log2N: Length, M: Length, Direction: c_int) void;
    extern fn vDSP_fftm_zriptD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, IM: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, M: Length, Direction: c_int) void;

    // -- Multiple FFT, real out-of-place --
    extern fn vDSP_fftm_zrop(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, IMA: Stride, C: *const SplitComplex, IC: Stride, IMC: Stride, Log2N: Length, M: Length, Direction: c_int) void;
    extern fn vDSP_fftm_zropD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, IMA: Stride, C: *const DoubleSplitComplex, IC: Stride, IMC: Stride, Log2N: Length, M: Length, Direction: c_int) void;
    extern fn vDSP_fftm_zropt(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, IMA: Stride, C: *const SplitComplex, IC: Stride, IMC: Stride, Buffer: *const SplitComplex, Log2N: Length, M: Length, Direction: c_int) void;
    extern fn vDSP_fftm_zroptD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, IMA: Stride, C: *const DoubleSplitComplex, IC: Stride, IMC: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, M: Length, Direction: c_int) void;

    // -- Interleaved conversion --
    extern fn vDSP_ctoz(C: [*]const extern struct { real: f32, imag: f32 }, IC: Stride, Z: *const SplitComplex, IZ: Stride, N: Length) void;
    extern fn vDSP_ctozD(C: [*]const extern struct { real: f64, imag: f64 }, IC: Stride, Z: *const DoubleSplitComplex, IZ: Stride, N: Length) void;
    extern fn vDSP_ztoc(Z: *const SplitComplex, IZ: Stride, C: [*]extern struct { real: f32, imag: f32 }, IC: Stride, N: Length) void;
    extern fn vDSP_ztocD(Z: *const DoubleSplitComplex, IZ: Stride, C: [*]extern struct { real: f64, imag: f64 }, IC: Stride, N: Length) void;
};

// ============================================================================
// Setup / Destroy
// ============================================================================

pub fn create_fftsetup(log2n: Length, radix: Radix) ?FFTSetup {
    return c.vDSP_create_fftsetup(log2n, @intFromEnum(radix));
}

pub fn create_fftsetupD(log2n: Length, radix: Radix) ?FFTSetupD {
    return c.vDSP_create_fftsetupD(log2n, @intFromEnum(radix));
}

pub fn destroy_fftsetup(setup: ?FFTSetup) void {
    c.vDSP_destroy_fftsetup(setup);
}

pub fn destroy_fftsetupD(setup: ?FFTSetupD) void {
    c.vDSP_destroy_fftsetupD(setup);
}

// ============================================================================
// 1D Complex-to-Complex FFT
// ============================================================================

/// In-place complex FFT (split complex)
pub fn fft_zip(setup: FFTSetup, io: *const SplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zip(setup, io, 1, log2n, @intFromEnum(direction));
}
pub fn fft_zipD(setup: FFTSetupD, io: *const DoubleSplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zipD(setup, io, 1, log2n, @intFromEnum(direction));
}

/// In-place complex FFT with temp buffer
pub fn fft_zipt(setup: FFTSetup, io: *const SplitComplex, buffer: *const SplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zipt(setup, io, 1, buffer, log2n, @intFromEnum(direction));
}
pub fn fft_ziptD(setup: FFTSetupD, io: *const DoubleSplitComplex, buffer: *const DoubleSplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_ziptD(setup, io, 1, buffer, log2n, @intFromEnum(direction));
}

/// Out-of-place complex FFT
pub fn fft_zop(setup: FFTSetup, input: *const SplitComplex, output: *const SplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zop(setup, input, 1, output, 1, log2n, @intFromEnum(direction));
}
pub fn fft_zopD(setup: FFTSetupD, input: *const DoubleSplitComplex, output: *const DoubleSplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zopD(setup, input, 1, output, 1, log2n, @intFromEnum(direction));
}

/// Out-of-place complex FFT with temp buffer
pub fn fft_zopt(setup: FFTSetup, input: *const SplitComplex, output: *const SplitComplex, buffer: *const SplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zopt(setup, input, 1, output, 1, buffer, log2n, @intFromEnum(direction));
}
pub fn fft_zoptD(setup: FFTSetupD, input: *const DoubleSplitComplex, output: *const DoubleSplitComplex, buffer: *const DoubleSplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zoptD(setup, input, 1, output, 1, buffer, log2n, @intFromEnum(direction));
}

// ============================================================================
// 1D Real-to-Complex FFT
// ============================================================================

/// In-place real FFT (packed split complex)
pub fn fft_zrip(setup: FFTSetup, io: *const SplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zrip(setup, io, 1, log2n, @intFromEnum(direction));
}
pub fn fft_zripD(setup: FFTSetupD, io: *const DoubleSplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zripD(setup, io, 1, log2n, @intFromEnum(direction));
}

/// In-place real FFT with temp buffer
pub fn fft_zript(setup: FFTSetup, io: *const SplitComplex, buffer: *const SplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zript(setup, io, 1, buffer, log2n, @intFromEnum(direction));
}
pub fn fft_zriptD(setup: FFTSetupD, io: *const DoubleSplitComplex, buffer: *const DoubleSplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zriptD(setup, io, 1, buffer, log2n, @intFromEnum(direction));
}

/// Out-of-place real FFT
pub fn fft_zrop(setup: FFTSetup, input: *const SplitComplex, output: *const SplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zrop(setup, input, 1, output, 1, log2n, @intFromEnum(direction));
}
pub fn fft_zropD(setup: FFTSetupD, input: *const DoubleSplitComplex, output: *const DoubleSplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zropD(setup, input, 1, output, 1, log2n, @intFromEnum(direction));
}

/// Out-of-place real FFT with temp buffer
pub fn fft_zropt(setup: FFTSetup, input: *const SplitComplex, output: *const SplitComplex, buffer: *const SplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zropt(setup, input, 1, output, 1, buffer, log2n, @intFromEnum(direction));
}
pub fn fft_zroptD(setup: FFTSetupD, input: *const DoubleSplitComplex, output: *const DoubleSplitComplex, buffer: *const DoubleSplitComplex, log2n: Length, direction: Direction) void {
    c.vDSP_fft_zroptD(setup, input, 1, output, 1, buffer, log2n, @intFromEnum(direction));
}

// ============================================================================
// 2D FFT
// ============================================================================

/// 2D in-place complex FFT
pub fn fft2d_zip(setup: FFTSetup, io: *const SplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zip(setup, io, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
}
pub fn fft2d_zipD(setup: FFTSetupD, io: *const DoubleSplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zipD(setup, io, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
}

/// 2D in-place complex FFT with temp buffer
pub fn fft2d_zipt(setup: FFTSetup, io: *const SplitComplex, ic0: Stride, buffer: *const SplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zipt(setup, io, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
}
pub fn fft2d_ziptD(setup: FFTSetupD, io: *const DoubleSplitComplex, ic0: Stride, buffer: *const DoubleSplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_ziptD(setup, io, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
}

/// 2D out-of-place complex FFT
pub fn fft2d_zop(setup: FFTSetup, input: *const SplitComplex, ia0: Stride, output: *const SplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zop(setup, input, ia0, 1, output, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
}
pub fn fft2d_zopD(setup: FFTSetupD, input: *const DoubleSplitComplex, ia0: Stride, output: *const DoubleSplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zopD(setup, input, ia0, 1, output, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
}

/// 2D out-of-place complex FFT with temp buffer
pub fn fft2d_zopt(setup: FFTSetup, input: *const SplitComplex, ia0: Stride, output: *const SplitComplex, ic0: Stride, buffer: *const SplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zopt(setup, input, ia0, 1, output, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
}
pub fn fft2d_zoptD(setup: FFTSetupD, input: *const DoubleSplitComplex, ia0: Stride, output: *const DoubleSplitComplex, ic0: Stride, buffer: *const DoubleSplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zoptD(setup, input, ia0, 1, output, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
}

/// 2D in-place real FFT
pub fn fft2d_zrip(setup: FFTSetup, io: *const SplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zrip(setup, io, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
}
pub fn fft2d_zripD(setup: FFTSetupD, io: *const DoubleSplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zripD(setup, io, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
}

/// 2D in-place real FFT with temp buffer
pub fn fft2d_zript(setup: FFTSetup, io: *const SplitComplex, ic0: Stride, buffer: *const SplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zript(setup, io, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
}
pub fn fft2d_zriptD(setup: FFTSetupD, io: *const DoubleSplitComplex, ic0: Stride, buffer: *const DoubleSplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zriptD(setup, io, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
}

/// 2D out-of-place real FFT
pub fn fft2d_zrop(setup: FFTSetup, input: *const SplitComplex, ia0: Stride, output: *const SplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zrop(setup, input, ia0, 1, output, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
}
pub fn fft2d_zropD(setup: FFTSetupD, input: *const DoubleSplitComplex, ia0: Stride, output: *const DoubleSplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zropD(setup, input, ia0, 1, output, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
}

/// 2D out-of-place real FFT with temp buffer
pub fn fft2d_zropt(setup: FFTSetup, input: *const SplitComplex, ia0: Stride, output: *const SplitComplex, ic0: Stride, buffer: *const SplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zropt(setup, input, ia0, 1, output, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
}
pub fn fft2d_zroptD(setup: FFTSetupD, input: *const DoubleSplitComplex, ia0: Stride, output: *const DoubleSplitComplex, ic0: Stride, buffer: *const DoubleSplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
    c.vDSP_fft2d_zroptD(setup, input, ia0, 1, output, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
}

// ============================================================================
// Multiple (batch) FFT
// ============================================================================

/// Multiple in-place complex FFT
pub fn fftm_zip(setup: FFTSetup, io: *const SplitComplex, im: Stride, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zip(setup, io, 1, im, log2n, m, @intFromEnum(direction));
}
pub fn fftm_zipD(setup: FFTSetupD, io: *const DoubleSplitComplex, im: Stride, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zipD(setup, io, 1, im, log2n, m, @intFromEnum(direction));
}

/// Multiple in-place complex FFT with temp buffer
pub fn fftm_zipt(setup: FFTSetup, io: *const SplitComplex, im: Stride, buffer: *const SplitComplex, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zipt(setup, io, 1, im, buffer, log2n, m, @intFromEnum(direction));
}
pub fn fftm_ziptD(setup: FFTSetupD, io: *const DoubleSplitComplex, im: Stride, buffer: *const DoubleSplitComplex, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_ziptD(setup, io, 1, im, buffer, log2n, m, @intFromEnum(direction));
}

/// Multiple out-of-place complex FFT
pub fn fftm_zop(setup: FFTSetup, input: *const SplitComplex, ima: Stride, output: *const SplitComplex, imc: Stride, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zop(setup, input, 1, ima, output, 1, imc, log2n, m, @intFromEnum(direction));
}
pub fn fftm_zopD(setup: FFTSetupD, input: *const DoubleSplitComplex, ima: Stride, output: *const DoubleSplitComplex, imc: Stride, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zopD(setup, input, 1, ima, output, 1, imc, log2n, m, @intFromEnum(direction));
}

/// Multiple out-of-place complex FFT with temp buffer
pub fn fftm_zopt(setup: FFTSetup, input: *const SplitComplex, ima: Stride, output: *const SplitComplex, imc: Stride, buffer: *const SplitComplex, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zopt(setup, input, 1, ima, output, 1, imc, buffer, log2n, m, @intFromEnum(direction));
}
pub fn fftm_zoptD(setup: FFTSetupD, input: *const DoubleSplitComplex, ima: Stride, output: *const DoubleSplitComplex, imc: Stride, buffer: *const DoubleSplitComplex, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zoptD(setup, input, 1, ima, output, 1, imc, buffer, log2n, m, @intFromEnum(direction));
}

/// Multiple in-place real FFT
pub fn fftm_zrip(setup: FFTSetup, io: *const SplitComplex, im: Stride, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zrip(setup, io, 1, im, log2n, m, @intFromEnum(direction));
}
pub fn fftm_zripD(setup: FFTSetupD, io: *const DoubleSplitComplex, im: Stride, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zripD(setup, io, 1, im, log2n, m, @intFromEnum(direction));
}

/// Multiple in-place real FFT with temp buffer
pub fn fftm_zript(setup: FFTSetup, io: *const SplitComplex, im: Stride, buffer: *const SplitComplex, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zript(setup, io, 1, im, buffer, log2n, m, @intFromEnum(direction));
}
pub fn fftm_zriptD(setup: FFTSetupD, io: *const DoubleSplitComplex, im: Stride, buffer: *const DoubleSplitComplex, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zriptD(setup, io, 1, im, buffer, log2n, m, @intFromEnum(direction));
}

/// Multiple out-of-place real FFT
pub fn fftm_zrop(setup: FFTSetup, input: *const SplitComplex, ima: Stride, output: *const SplitComplex, imc: Stride, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zrop(setup, input, 1, ima, output, 1, imc, log2n, m, @intFromEnum(direction));
}
pub fn fftm_zropD(setup: FFTSetupD, input: *const DoubleSplitComplex, ima: Stride, output: *const DoubleSplitComplex, imc: Stride, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zropD(setup, input, 1, ima, output, 1, imc, log2n, m, @intFromEnum(direction));
}

/// Multiple out-of-place real FFT with temp buffer
pub fn fftm_zropt(setup: FFTSetup, input: *const SplitComplex, ima: Stride, output: *const SplitComplex, imc: Stride, buffer: *const SplitComplex, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zropt(setup, input, 1, ima, output, 1, imc, buffer, log2n, m, @intFromEnum(direction));
}
pub fn fftm_zroptD(setup: FFTSetupD, input: *const DoubleSplitComplex, ima: Stride, output: *const DoubleSplitComplex, imc: Stride, buffer: *const DoubleSplitComplex, log2n: Length, m: Length, direction: Direction) void {
    c.vDSP_fftm_zroptD(setup, input, 1, ima, output, 1, imc, buffer, log2n, m, @intFromEnum(direction));
}

// ============================================================================
// Interleaved ↔ Split conversion
// ============================================================================

pub const Complex = extern struct { real: f32, imag: f32 };
pub const DoubleComplex = extern struct { real: f64, imag: f64 };

/// Convert interleaved complex to split complex
pub fn ctoz(input: [*]const Complex, output: *const SplitComplex, n: Length) void {
    c.vDSP_ctoz(input, 2, output, 1, n);
}
pub fn ctozD(input: [*]const DoubleComplex, output: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_ctozD(input, 2, output, 1, n);
}

/// Convert split complex to interleaved complex
pub fn ztoc(input: *const SplitComplex, output: [*]Complex, n: Length) void {
    c.vDSP_ztoc(input, 1, output, 2, n);
}
pub fn ztocD(input: *const DoubleSplitComplex, output: [*]DoubleComplex, n: Length) void {
    c.vDSP_ztocD(input, 1, output, 2, n);
}

// ============================================================================
// High-level FFT wrapper (manages setup lifetime)
// ============================================================================

pub const FFT = struct {
    setup: FFTSetup,
    log2n: Length,

    pub fn init(log2n: Length, radix: Radix) ?FFT {
        return .{
            .setup = create_fftsetup(log2n, radix) orelse return null,
            .log2n = log2n,
        };
    }

    pub fn deinit(self: FFT) void {
        destroy_fftsetup(self.setup);
    }

    // -- 1D complex --

    pub fn zip(self: FFT, io: *const SplitComplex, direction: Direction) void {
        fft_zip(self.setup, io, self.log2n, direction);
    }

    pub fn zipt(self: FFT, io: *const SplitComplex, buffer: *const SplitComplex, direction: Direction) void {
        fft_zipt(self.setup, io, buffer, self.log2n, direction);
    }

    pub fn zop(self: FFT, input: *const SplitComplex, output: *const SplitComplex, direction: Direction) void {
        fft_zop(self.setup, input, output, self.log2n, direction);
    }

    pub fn zopt(self: FFT, input: *const SplitComplex, output: *const SplitComplex, buffer: *const SplitComplex, direction: Direction) void {
        fft_zopt(self.setup, input, output, buffer, self.log2n, direction);
    }

    // -- 1D real --

    pub fn zrip(self: FFT, io: *const SplitComplex, direction: Direction) void {
        fft_zrip(self.setup, io, self.log2n, direction);
    }

    pub fn zript(self: FFT, io: *const SplitComplex, buffer: *const SplitComplex, direction: Direction) void {
        fft_zript(self.setup, io, buffer, self.log2n, direction);
    }

    pub fn zrop(self: FFT, input: *const SplitComplex, output: *const SplitComplex, direction: Direction) void {
        fft_zrop(self.setup, input, output, self.log2n, direction);
    }

    pub fn zropt(self: FFT, input: *const SplitComplex, output: *const SplitComplex, buffer: *const SplitComplex, direction: Direction) void {
        fft_zropt(self.setup, input, output, buffer, self.log2n, direction);
    }

    // -- 2D complex --

    pub fn zip2d(self: FFT, io: *const SplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zip(self.setup, io, ic0, log2n0, log2n1, direction);
    }

    pub fn zipt2d(self: FFT, io: *const SplitComplex, ic0: Stride, buffer: *const SplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zipt(self.setup, io, ic0, buffer, log2n0, log2n1, direction);
    }

    pub fn zop2d(self: FFT, input: *const SplitComplex, ia0: Stride, output: *const SplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zop(self.setup, input, ia0, output, ic0, log2n0, log2n1, direction);
    }

    pub fn zopt2d(self: FFT, input: *const SplitComplex, ia0: Stride, output: *const SplitComplex, ic0: Stride, buffer: *const SplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zopt(self.setup, input, ia0, output, ic0, buffer, log2n0, log2n1, direction);
    }

    // -- 2D real --

    pub fn zrip2d(self: FFT, io: *const SplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zrip(self.setup, io, ic0, log2n0, log2n1, direction);
    }

    pub fn zript2d(self: FFT, io: *const SplitComplex, ic0: Stride, buffer: *const SplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zript(self.setup, io, ic0, buffer, log2n0, log2n1, direction);
    }

    pub fn zrop2d(self: FFT, input: *const SplitComplex, ia0: Stride, output: *const SplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zrop(self.setup, input, ia0, output, ic0, log2n0, log2n1, direction);
    }

    pub fn zropt2d(self: FFT, input: *const SplitComplex, ia0: Stride, output: *const SplitComplex, ic0: Stride, buffer: *const SplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zropt(self.setup, input, ia0, output, ic0, buffer, log2n0, log2n1, direction);
    }

    // -- Batch --

    pub fn mzip(self: FFT, io: *const SplitComplex, im: Stride, m: Length, direction: Direction) void {
        fftm_zip(self.setup, io, im, self.log2n, m, direction);
    }

    pub fn mzipt(self: FFT, io: *const SplitComplex, im: Stride, buffer: *const SplitComplex, m: Length, direction: Direction) void {
        fftm_zipt(self.setup, io, im, buffer, self.log2n, m, direction);
    }

    pub fn mzop(self: FFT, input: *const SplitComplex, ima: Stride, output: *const SplitComplex, imc: Stride, m: Length, direction: Direction) void {
        fftm_zop(self.setup, input, ima, output, imc, self.log2n, m, direction);
    }

    pub fn mzopt(self: FFT, input: *const SplitComplex, ima: Stride, output: *const SplitComplex, imc: Stride, buffer: *const SplitComplex, m: Length, direction: Direction) void {
        fftm_zopt(self.setup, input, ima, output, imc, buffer, self.log2n, m, direction);
    }

    pub fn mzrip(self: FFT, io: *const SplitComplex, im: Stride, m: Length, direction: Direction) void {
        fftm_zrip(self.setup, io, im, self.log2n, m, direction);
    }

    pub fn mzript(self: FFT, io: *const SplitComplex, im: Stride, buffer: *const SplitComplex, m: Length, direction: Direction) void {
        fftm_zript(self.setup, io, im, buffer, self.log2n, m, direction);
    }

    pub fn mzrop(self: FFT, input: *const SplitComplex, ima: Stride, output: *const SplitComplex, imc: Stride, m: Length, direction: Direction) void {
        fftm_zrop(self.setup, input, ima, output, imc, self.log2n, m, direction);
    }

    pub fn mzropt(self: FFT, input: *const SplitComplex, ima: Stride, output: *const SplitComplex, imc: Stride, buffer: *const SplitComplex, m: Length, direction: Direction) void {
        fftm_zropt(self.setup, input, ima, output, imc, buffer, self.log2n, m, direction);
    }
};

pub const FFTD = struct {
    setup: FFTSetupD,
    log2n: Length,

    pub fn init(log2n: Length, radix: Radix) ?FFTD {
        return .{
            .setup = create_fftsetupD(log2n, radix) orelse return null,
            .log2n = log2n,
        };
    }

    pub fn deinit(self: FFTD) void {
        destroy_fftsetupD(self.setup);
    }

    // -- 1D complex --

    pub fn zip(self: FFTD, io: *const DoubleSplitComplex, direction: Direction) void {
        fft_zipD(self.setup, io, self.log2n, direction);
    }

    pub fn zipt(self: FFTD, io: *const DoubleSplitComplex, buffer: *const DoubleSplitComplex, direction: Direction) void {
        fft_ziptD(self.setup, io, buffer, self.log2n, direction);
    }

    pub fn zop(self: FFTD, input: *const DoubleSplitComplex, output: *const DoubleSplitComplex, direction: Direction) void {
        fft_zopD(self.setup, input, output, self.log2n, direction);
    }

    pub fn zopt(self: FFTD, input: *const DoubleSplitComplex, output: *const DoubleSplitComplex, buffer: *const DoubleSplitComplex, direction: Direction) void {
        fft_zoptD(self.setup, input, output, buffer, self.log2n, direction);
    }

    // -- 1D real --

    pub fn zrip(self: FFTD, io: *const DoubleSplitComplex, direction: Direction) void {
        fft_zripD(self.setup, io, self.log2n, direction);
    }

    pub fn zript(self: FFTD, io: *const DoubleSplitComplex, buffer: *const DoubleSplitComplex, direction: Direction) void {
        fft_zriptD(self.setup, io, buffer, self.log2n, direction);
    }

    pub fn zrop(self: FFTD, input: *const DoubleSplitComplex, output: *const DoubleSplitComplex, direction: Direction) void {
        fft_zropD(self.setup, input, output, self.log2n, direction);
    }

    pub fn zropt(self: FFTD, input: *const DoubleSplitComplex, output: *const DoubleSplitComplex, buffer: *const DoubleSplitComplex, direction: Direction) void {
        fft_zroptD(self.setup, input, output, buffer, self.log2n, direction);
    }

    // -- 2D complex --

    pub fn zip2d(self: FFTD, io: *const DoubleSplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zipD(self.setup, io, ic0, log2n0, log2n1, direction);
    }

    pub fn zipt2d(self: FFTD, io: *const DoubleSplitComplex, ic0: Stride, buffer: *const DoubleSplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_ziptD(self.setup, io, ic0, buffer, log2n0, log2n1, direction);
    }

    pub fn zop2d(self: FFTD, input: *const DoubleSplitComplex, ia0: Stride, output: *const DoubleSplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zopD(self.setup, input, ia0, output, ic0, log2n0, log2n1, direction);
    }

    pub fn zopt2d(self: FFTD, input: *const DoubleSplitComplex, ia0: Stride, output: *const DoubleSplitComplex, ic0: Stride, buffer: *const DoubleSplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zoptD(self.setup, input, ia0, output, ic0, buffer, log2n0, log2n1, direction);
    }

    // -- 2D real --

    pub fn zrip2d(self: FFTD, io: *const DoubleSplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zripD(self.setup, io, ic0, log2n0, log2n1, direction);
    }

    pub fn zript2d(self: FFTD, io: *const DoubleSplitComplex, ic0: Stride, buffer: *const DoubleSplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zriptD(self.setup, io, ic0, buffer, log2n0, log2n1, direction);
    }

    pub fn zrop2d(self: FFTD, input: *const DoubleSplitComplex, ia0: Stride, output: *const DoubleSplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zropD(self.setup, input, ia0, output, ic0, log2n0, log2n1, direction);
    }

    pub fn zropt2d(self: FFTD, input: *const DoubleSplitComplex, ia0: Stride, output: *const DoubleSplitComplex, ic0: Stride, buffer: *const DoubleSplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        fft2d_zroptD(self.setup, input, ia0, output, ic0, buffer, log2n0, log2n1, direction);
    }

    // -- Batch --

    pub fn mzip(self: FFTD, io: *const DoubleSplitComplex, im: Stride, m: Length, direction: Direction) void {
        fftm_zipD(self.setup, io, im, self.log2n, m, direction);
    }

    pub fn mzipt(self: FFTD, io: *const DoubleSplitComplex, im: Stride, buffer: *const DoubleSplitComplex, m: Length, direction: Direction) void {
        fftm_ziptD(self.setup, io, im, buffer, self.log2n, m, direction);
    }

    pub fn mzop(self: FFTD, input: *const DoubleSplitComplex, ima: Stride, output: *const DoubleSplitComplex, imc: Stride, m: Length, direction: Direction) void {
        fftm_zopD(self.setup, input, ima, output, imc, self.log2n, m, direction);
    }

    pub fn mzopt(self: FFTD, input: *const DoubleSplitComplex, ima: Stride, output: *const DoubleSplitComplex, imc: Stride, buffer: *const DoubleSplitComplex, m: Length, direction: Direction) void {
        fftm_zoptD(self.setup, input, ima, output, imc, buffer, self.log2n, m, direction);
    }

    pub fn mzrip(self: FFTD, io: *const DoubleSplitComplex, im: Stride, m: Length, direction: Direction) void {
        fftm_zripD(self.setup, io, im, self.log2n, m, direction);
    }

    pub fn mzript(self: FFTD, io: *const DoubleSplitComplex, im: Stride, buffer: *const DoubleSplitComplex, m: Length, direction: Direction) void {
        fftm_zriptD(self.setup, io, im, buffer, self.log2n, m, direction);
    }

    pub fn mzrop(self: FFTD, input: *const DoubleSplitComplex, ima: Stride, output: *const DoubleSplitComplex, imc: Stride, m: Length, direction: Direction) void {
        fftm_zropD(self.setup, input, ima, output, imc, self.log2n, m, direction);
    }

    pub fn mzropt(self: FFTD, input: *const DoubleSplitComplex, ima: Stride, output: *const DoubleSplitComplex, imc: Stride, buffer: *const DoubleSplitComplex, m: Length, direction: Direction) void {
        fftm_zroptD(self.setup, input, ima, output, imc, buffer, self.log2n, m, direction);
    }
};
