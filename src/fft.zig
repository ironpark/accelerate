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
// Interleaved <-> Split conversion
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
            .setup = c.vDSP_create_fftsetup(log2n, @intFromEnum(radix)) orelse return null,
            .log2n = log2n,
        };
    }

    pub fn deinit(self: FFT) void {
        c.vDSP_destroy_fftsetup(self.setup);
    }

    // -- 1D complex --

    pub fn zip(self: FFT, io: *const SplitComplex, direction: Direction) void {
        c.vDSP_fft_zip(self.setup, io, 1, self.log2n, @intFromEnum(direction));
    }

    pub fn zipt(self: FFT, io: *const SplitComplex, buffer: *const SplitComplex, direction: Direction) void {
        c.vDSP_fft_zipt(self.setup, io, 1, buffer, self.log2n, @intFromEnum(direction));
    }

    pub fn zop(self: FFT, input: *const SplitComplex, output: *const SplitComplex, direction: Direction) void {
        c.vDSP_fft_zop(self.setup, input, 1, output, 1, self.log2n, @intFromEnum(direction));
    }

    pub fn zopt(self: FFT, input: *const SplitComplex, output: *const SplitComplex, buffer: *const SplitComplex, direction: Direction) void {
        c.vDSP_fft_zopt(self.setup, input, 1, output, 1, buffer, self.log2n, @intFromEnum(direction));
    }

    // -- 1D real --

    pub fn zrip(self: FFT, io: *const SplitComplex, direction: Direction) void {
        c.vDSP_fft_zrip(self.setup, io, 1, self.log2n, @intFromEnum(direction));
    }

    pub fn zript(self: FFT, io: *const SplitComplex, buffer: *const SplitComplex, direction: Direction) void {
        c.vDSP_fft_zript(self.setup, io, 1, buffer, self.log2n, @intFromEnum(direction));
    }

    pub fn zrop(self: FFT, input: *const SplitComplex, output: *const SplitComplex, direction: Direction) void {
        c.vDSP_fft_zrop(self.setup, input, 1, output, 1, self.log2n, @intFromEnum(direction));
    }

    pub fn zropt(self: FFT, input: *const SplitComplex, output: *const SplitComplex, buffer: *const SplitComplex, direction: Direction) void {
        c.vDSP_fft_zropt(self.setup, input, 1, output, 1, buffer, self.log2n, @intFromEnum(direction));
    }

    // -- 2D complex --

    pub fn zip2d(self: FFT, io: *const SplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zip(self.setup, io, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
    }

    pub fn zipt2d(self: FFT, io: *const SplitComplex, ic0: Stride, buffer: *const SplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zipt(self.setup, io, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
    }

    pub fn zop2d(self: FFT, input: *const SplitComplex, ia0: Stride, output: *const SplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zop(self.setup, input, ia0, 1, output, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
    }

    pub fn zopt2d(self: FFT, input: *const SplitComplex, ia0: Stride, output: *const SplitComplex, ic0: Stride, buffer: *const SplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zopt(self.setup, input, ia0, 1, output, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
    }

    // -- 2D real --

    pub fn zrip2d(self: FFT, io: *const SplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zrip(self.setup, io, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
    }

    pub fn zript2d(self: FFT, io: *const SplitComplex, ic0: Stride, buffer: *const SplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zript(self.setup, io, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
    }

    pub fn zrop2d(self: FFT, input: *const SplitComplex, ia0: Stride, output: *const SplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zrop(self.setup, input, ia0, 1, output, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
    }

    pub fn zropt2d(self: FFT, input: *const SplitComplex, ia0: Stride, output: *const SplitComplex, ic0: Stride, buffer: *const SplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zropt(self.setup, input, ia0, 1, output, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
    }

    // -- Batch --

    pub fn mzip(self: FFT, io: *const SplitComplex, im: Stride, m: Length, direction: Direction) void {
        c.vDSP_fftm_zip(self.setup, io, 1, im, self.log2n, m, @intFromEnum(direction));
    }

    pub fn mzipt(self: FFT, io: *const SplitComplex, im: Stride, buffer: *const SplitComplex, m: Length, direction: Direction) void {
        c.vDSP_fftm_zipt(self.setup, io, 1, im, buffer, self.log2n, m, @intFromEnum(direction));
    }

    pub fn mzop(self: FFT, input: *const SplitComplex, ima: Stride, output: *const SplitComplex, imc: Stride, m: Length, direction: Direction) void {
        c.vDSP_fftm_zop(self.setup, input, 1, ima, output, 1, imc, self.log2n, m, @intFromEnum(direction));
    }

    pub fn mzopt(self: FFT, input: *const SplitComplex, ima: Stride, output: *const SplitComplex, imc: Stride, buffer: *const SplitComplex, m: Length, direction: Direction) void {
        c.vDSP_fftm_zopt(self.setup, input, 1, ima, output, 1, imc, buffer, self.log2n, m, @intFromEnum(direction));
    }

    pub fn mzrip(self: FFT, io: *const SplitComplex, im: Stride, m: Length, direction: Direction) void {
        c.vDSP_fftm_zrip(self.setup, io, 1, im, self.log2n, m, @intFromEnum(direction));
    }

    pub fn mzript(self: FFT, io: *const SplitComplex, im: Stride, buffer: *const SplitComplex, m: Length, direction: Direction) void {
        c.vDSP_fftm_zript(self.setup, io, 1, im, buffer, self.log2n, m, @intFromEnum(direction));
    }

    pub fn mzrop(self: FFT, input: *const SplitComplex, ima: Stride, output: *const SplitComplex, imc: Stride, m: Length, direction: Direction) void {
        c.vDSP_fftm_zrop(self.setup, input, 1, ima, output, 1, imc, self.log2n, m, @intFromEnum(direction));
    }

    pub fn mzropt(self: FFT, input: *const SplitComplex, ima: Stride, output: *const SplitComplex, imc: Stride, buffer: *const SplitComplex, m: Length, direction: Direction) void {
        c.vDSP_fftm_zropt(self.setup, input, 1, ima, output, 1, imc, buffer, self.log2n, m, @intFromEnum(direction));
    }
};

pub const FFTD = struct {
    setup: FFTSetupD,
    log2n: Length,

    pub fn init(log2n: Length, radix: Radix) ?FFTD {
        return .{
            .setup = c.vDSP_create_fftsetupD(log2n, @intFromEnum(radix)) orelse return null,
            .log2n = log2n,
        };
    }

    pub fn deinit(self: FFTD) void {
        c.vDSP_destroy_fftsetupD(self.setup);
    }

    // -- 1D complex --

    pub fn zip(self: FFTD, io: *const DoubleSplitComplex, direction: Direction) void {
        c.vDSP_fft_zipD(self.setup, io, 1, self.log2n, @intFromEnum(direction));
    }

    pub fn zipt(self: FFTD, io: *const DoubleSplitComplex, buffer: *const DoubleSplitComplex, direction: Direction) void {
        c.vDSP_fft_ziptD(self.setup, io, 1, buffer, self.log2n, @intFromEnum(direction));
    }

    pub fn zop(self: FFTD, input: *const DoubleSplitComplex, output: *const DoubleSplitComplex, direction: Direction) void {
        c.vDSP_fft_zopD(self.setup, input, 1, output, 1, self.log2n, @intFromEnum(direction));
    }

    pub fn zopt(self: FFTD, input: *const DoubleSplitComplex, output: *const DoubleSplitComplex, buffer: *const DoubleSplitComplex, direction: Direction) void {
        c.vDSP_fft_zoptD(self.setup, input, 1, output, 1, buffer, self.log2n, @intFromEnum(direction));
    }

    // -- 1D real --

    pub fn zrip(self: FFTD, io: *const DoubleSplitComplex, direction: Direction) void {
        c.vDSP_fft_zripD(self.setup, io, 1, self.log2n, @intFromEnum(direction));
    }

    pub fn zript(self: FFTD, io: *const DoubleSplitComplex, buffer: *const DoubleSplitComplex, direction: Direction) void {
        c.vDSP_fft_zriptD(self.setup, io, 1, buffer, self.log2n, @intFromEnum(direction));
    }

    pub fn zrop(self: FFTD, input: *const DoubleSplitComplex, output: *const DoubleSplitComplex, direction: Direction) void {
        c.vDSP_fft_zropD(self.setup, input, 1, output, 1, self.log2n, @intFromEnum(direction));
    }

    pub fn zropt(self: FFTD, input: *const DoubleSplitComplex, output: *const DoubleSplitComplex, buffer: *const DoubleSplitComplex, direction: Direction) void {
        c.vDSP_fft_zroptD(self.setup, input, 1, output, 1, buffer, self.log2n, @intFromEnum(direction));
    }

    // -- 2D complex --

    pub fn zip2d(self: FFTD, io: *const DoubleSplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zipD(self.setup, io, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
    }

    pub fn zipt2d(self: FFTD, io: *const DoubleSplitComplex, ic0: Stride, buffer: *const DoubleSplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_ziptD(self.setup, io, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
    }

    pub fn zop2d(self: FFTD, input: *const DoubleSplitComplex, ia0: Stride, output: *const DoubleSplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zopD(self.setup, input, ia0, 1, output, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
    }

    pub fn zopt2d(self: FFTD, input: *const DoubleSplitComplex, ia0: Stride, output: *const DoubleSplitComplex, ic0: Stride, buffer: *const DoubleSplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zoptD(self.setup, input, ia0, 1, output, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
    }

    // -- 2D real --

    pub fn zrip2d(self: FFTD, io: *const DoubleSplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zripD(self.setup, io, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
    }

    pub fn zript2d(self: FFTD, io: *const DoubleSplitComplex, ic0: Stride, buffer: *const DoubleSplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zriptD(self.setup, io, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
    }

    pub fn zrop2d(self: FFTD, input: *const DoubleSplitComplex, ia0: Stride, output: *const DoubleSplitComplex, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zropD(self.setup, input, ia0, 1, output, ic0, 1, log2n0, log2n1, @intFromEnum(direction));
    }

    pub fn zropt2d(self: FFTD, input: *const DoubleSplitComplex, ia0: Stride, output: *const DoubleSplitComplex, ic0: Stride, buffer: *const DoubleSplitComplex, log2n0: Length, log2n1: Length, direction: Direction) void {
        c.vDSP_fft2d_zroptD(self.setup, input, ia0, 1, output, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction));
    }

    // -- Batch --

    pub fn mzip(self: FFTD, io: *const DoubleSplitComplex, im: Stride, m: Length, direction: Direction) void {
        c.vDSP_fftm_zipD(self.setup, io, 1, im, self.log2n, m, @intFromEnum(direction));
    }

    pub fn mzipt(self: FFTD, io: *const DoubleSplitComplex, im: Stride, buffer: *const DoubleSplitComplex, m: Length, direction: Direction) void {
        c.vDSP_fftm_ziptD(self.setup, io, 1, im, buffer, self.log2n, m, @intFromEnum(direction));
    }

    pub fn mzop(self: FFTD, input: *const DoubleSplitComplex, ima: Stride, output: *const DoubleSplitComplex, imc: Stride, m: Length, direction: Direction) void {
        c.vDSP_fftm_zopD(self.setup, input, 1, ima, output, 1, imc, self.log2n, m, @intFromEnum(direction));
    }

    pub fn mzopt(self: FFTD, input: *const DoubleSplitComplex, ima: Stride, output: *const DoubleSplitComplex, imc: Stride, buffer: *const DoubleSplitComplex, m: Length, direction: Direction) void {
        c.vDSP_fftm_zoptD(self.setup, input, 1, ima, output, 1, imc, buffer, self.log2n, m, @intFromEnum(direction));
    }

    pub fn mzrip(self: FFTD, io: *const DoubleSplitComplex, im: Stride, m: Length, direction: Direction) void {
        c.vDSP_fftm_zripD(self.setup, io, 1, im, self.log2n, m, @intFromEnum(direction));
    }

    pub fn mzript(self: FFTD, io: *const DoubleSplitComplex, im: Stride, buffer: *const DoubleSplitComplex, m: Length, direction: Direction) void {
        c.vDSP_fftm_zriptD(self.setup, io, 1, im, buffer, self.log2n, m, @intFromEnum(direction));
    }

    pub fn mzrop(self: FFTD, input: *const DoubleSplitComplex, ima: Stride, output: *const DoubleSplitComplex, imc: Stride, m: Length, direction: Direction) void {
        c.vDSP_fftm_zropD(self.setup, input, 1, ima, output, 1, imc, self.log2n, m, @intFromEnum(direction));
    }

    pub fn mzropt(self: FFTD, input: *const DoubleSplitComplex, ima: Stride, output: *const DoubleSplitComplex, imc: Stride, buffer: *const DoubleSplitComplex, m: Length, direction: Direction) void {
        c.vDSP_fftm_zroptD(self.setup, input, 1, ima, output, 1, imc, buffer, self.log2n, m, @intFromEnum(direction));
    }
};
