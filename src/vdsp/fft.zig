const std = @import("std");
const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;
const c = @import("c.zig");

// ============================================================================
// Types
// ============================================================================

pub const FFTSetup = c.FFTSetup;
pub const FFTSetupD = c.FFTSetupD;

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
// Interleaved <-> Split conversion
// ============================================================================

pub const Complex = types.Complex;

/// Convert a complex array to a complex-split array.
///
/// This computes:
///     for (n = 0; n < N; ++n)
///         Z[n] = C[n];
///
/// where C[n] is C[n*IC/2].real + i * C[n*IC/2].imag
/// and Z[n] is Z->realp[n*IZ] + i * Z->imagp[n*IZ].
pub fn ctoz(comptime T: type, input: [*]const Complex(T), output: *const SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_ctoz(input, 2, output, 1, n),
        f64 => c.vDSP_ctozD(input, 2, output, 1, n),
        else => @compileError("ctoz requires f32 or f64"),
    }
}

/// Convert a complex-split array to a complex array.
///
/// This computes:
///     for (n = 0; n < N; ++n)
///         C[n] = Z[n];
///
/// where Z[n] is Z->realp[n*IZ] + i * Z->imagp[n*IZ]
/// and C[n] is C[n*IC/2].real + i * C[n*IC/2].imag.
pub fn ztoc(comptime T: type, input: *const SC(T), output: [*]Complex(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_ztoc(input, 1, output, 2, n),
        f64 => c.vDSP_ztocD(input, 1, output, 2, n),
        else => @compileError("ztoc requires f32 or f64"),
    }
}

const SC = types.SplitComplex;

// ============================================================================
// High-level FFT wrapper (manages setup lifetime)
// ============================================================================

/// A generic FFT wrapper parameterized on scalar type T (f32 or f64).
/// Manages the lifetime of the underlying vDSP FFT setup object.
pub fn FFT(comptime T: type) type {
    const SCT = SC(T);
    const Setup = switch (T) {
        f32 => FFTSetup,
        f64 => FFTSetupD,
        else => @compileError("FFT requires f32 or f64"),
    };

    return struct {
        const Self = @This();
        setup: Setup,
        log2n: Length,

        /// Allocates memory and prepares constants used by FFT routines.
        pub fn init(log2n: Length, radix: Radix) !Self {
            const setup = switch (T) {
                f32 => c.vDSP_create_fftsetup(log2n, @intFromEnum(radix)),
                f64 => c.vDSP_create_fftsetupD(log2n, @intFromEnum(radix)),
                else => unreachable,
            };
            return .{
                .setup = setup orelse return error.SetupFailed,
                .log2n = log2n,
            };
        }

        /// Frees the memory allocated by init. May be called on a destroyed setup
        /// with no effect.
        pub fn deinit(self: Self) void {
            switch (T) {
                f32 => c.vDSP_destroy_fftsetup(self.setup),
                f64 => c.vDSP_destroy_fftsetupD(self.setup),
                else => unreachable,
            }
        }

        // -- 1D complex --

        /// In-place complex Discrete Fourier Transform routine.
        /// We suggest you use the DFT routines instead of these.
        ///
        /// These compute:
        ///
        ///     N = 1 << Log2N;
        ///     scale = 0 < Direction ? 1 : 1./N;
        ///
        ///     // Define a complex vector, h:
        ///     for (j = 0; j < N; ++j)
        ///         h[j] = C->realp[j*IC] + i * C->imagp[j*IC];
        ///
        ///     // Perform Discrete Fourier Transform.
        ///     for (k = 0; k < N; ++k)
        ///         H[k] = scale * sum(h[j] * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);
        ///
        ///     // Store result.
        ///     for (k = 0; k < N; ++k)
        ///     {
        ///         C->realp[k*IC] = Re(H[k]);
        ///         C->imagp[k*IC] = Im(H[k]);
        ///     }
        ///
        /// Direction must be +1 or -1.
        pub fn zip(self: Self, io: *const SCT, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft_zip(self.setup, io, 1, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_zipD(self.setup, io, 1, self.log2n, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// In-place complex Discrete Fourier Transform routine, with temporary memory.
        /// We suggest you use the DFT routines instead of these.
        ///
        /// The temporary buffer version performs the same operation as zip but is
        /// permitted to use the temporary buffer for improved performance.  Each
        /// of Buffer->realp and Buffer->imagp must contain the lesser of 16,384
        /// bytes or N * sizeof *C->realp bytes and is preferably 16-byte aligned
        /// or better.
        pub fn zipt(self: Self, io: *const SCT, buffer: *const SCT, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft_zipt(self.setup, io, 1, buffer, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_ziptD(self.setup, io, 1, buffer, self.log2n, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place complex Discrete Fourier Transform routine.
        /// We suggest you use the DFT routines instead of these.
        ///
        /// These compute:
        ///
        ///     N = 1 << Log2N;
        ///     scale = 0 < Direction ? 1 : 1./N;
        ///
        ///     // Define a complex vector, h:
        ///     for (j = 0; j < N; ++j)
        ///         h[j] = A->realp[j*IA] + i * A->imagp[j*IA];
        ///
        ///     // Perform Discrete Fourier Transform.
        ///     for (k = 0; k < N; ++k)
        ///         H[k] = scale * sum(h[j] * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);
        ///
        ///     // Store result.
        ///     for (k = 0; k < N; ++k)
        ///     {
        ///         C->realp[k*IC] = Re(H[k]);
        ///         C->imagp[k*IC] = Im(H[k]);
        ///     }
        ///
        /// Direction must be +1 or -1.
        pub fn zop(self: Self, input: *const SCT, output: *const SCT, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft_zop(self.setup, input, 1, output, 1, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_zopD(self.setup, input, 1, output, 1, self.log2n, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place complex Discrete Fourier Transform routine, with temporary memory.
        /// We suggest you use the DFT routines instead of these.
        ///
        /// The temporary buffer version performs the same operation as zop but is
        /// permitted to use the temporary buffer for improved performance.  Each
        /// of Buffer->realp and Buffer->imagp must contain the lesser of 16,384
        /// bytes or N * sizeof *C->realp bytes and is preferably 16-byte aligned
        /// or better.
        pub fn zopt(self: Self, input: *const SCT, output: *const SCT, buffer: *const SCT, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft_zopt(self.setup, input, 1, output, 1, buffer, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_zoptD(self.setup, input, 1, output, 1, buffer, self.log2n, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        // -- 1D real --

        /// In-place real-to-complex Discrete Fourier Transform routine.
        /// We suggest you use the DFT routines instead of these.
        ///
        /// If Direction is +1, a real-to-complex transform is performed, taking
        /// input from a real vector that has been coerced into the complex
        /// structure.
        ///
        /// If Direction is -1, a complex-to-real inverse transform is performed,
        /// producing a real output vector coerced into the complex structure.
        ///
        /// Direction must be +1 or -1.
        pub fn zrip(self: Self, io: *const SCT, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft_zrip(self.setup, io, 1, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_zripD(self.setup, io, 1, self.log2n, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// In-place real-to-complex Discrete Fourier Transform routine, with temporary memory.
        /// We suggest you use the DFT routines instead of these.
        ///
        /// The temporary buffer version performs the same operation as zrip but is
        /// permitted to use the temporary buffer for improved performance.  Each
        /// of Buffer->realp and Buffer->imagp must contain N/2 * sizeof *C->realp
        /// bytes and is preferably 16-byte aligned or better.
        pub fn zript(self: Self, io: *const SCT, buffer: *const SCT, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft_zript(self.setup, io, 1, buffer, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_zriptD(self.setup, io, 1, buffer, self.log2n, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place real-to-complex Discrete Fourier Transform routine.
        /// We suggest you use the DFT routines instead of these.
        ///
        /// If Direction is +1, a real-to-complex transform is performed, taking
        /// input from a real vector that has been coerced into the complex
        /// structure.
        ///
        /// If Direction is -1, a complex-to-real inverse transform is performed,
        /// producing a real output vector coerced into the complex structure.
        ///
        /// Direction must be +1 or -1.
        pub fn zrop(self: Self, input: *const SCT, output: *const SCT, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft_zrop(self.setup, input, 1, output, 1, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_zropD(self.setup, input, 1, output, 1, self.log2n, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place real-to-complex Discrete Fourier Transform routine, with temporary memory.
        /// We suggest you use the DFT routines instead of these.
        ///
        /// The temporary buffer version performs the same operation as zrop but is
        /// permitted to use the temporary buffer for improved performance.  Each
        /// of Buffer->realp and Buffer->imagp must contain N/2 * sizeof *C->realp
        /// bytes and is preferably 16-byte aligned or better.
        pub fn zropt(self: Self, input: *const SCT, output: *const SCT, buffer: *const SCT, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft_zropt(self.setup, input, 1, output, 1, buffer, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_zroptD(self.setup, input, 1, output, 1, buffer, self.log2n, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        // -- 2D complex --

        /// In-place two-dimensional complex Discrete Fourier Transform routine.
        ///
        /// Direction must be +1 or -1.
        pub fn zip2d(self: Self, io: *const SCT, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft2d_zip(self.setup, io, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_zipD(self.setup, io, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// In-place two-dimensional complex Discrete Fourier Transform routine, with temporary memory.
        ///
        /// The temporary buffer version performs the same operation but is
        /// permitted to use the temporary buffer for improved performance.  Each
        /// of Buffer->realp and Buffer->imagp must contain the lesser of 16,384
        /// bytes or N1*N0 * sizeof *C->realp bytes and is preferably 16-byte
        /// aligned or better.
        pub fn zipt2d(self: Self, io: *const SCT, ic0: Stride, buffer: *const SCT, log2n0: Length, log2n1: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft2d_zipt(self.setup, io, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_ziptD(self.setup, io, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place two-dimensional complex Discrete Fourier Transform routine.
        ///
        /// Direction must be +1 or -1.
        pub fn zop2d(self: Self, input: *const SCT, ia0: Stride, output: *const SCT, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft2d_zop(self.setup, input, ia0, 1, output, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_zopD(self.setup, input, ia0, 1, output, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place two-dimensional complex Discrete Fourier Transform routine, with temporary memory.
        ///
        /// The temporary buffer version performs the same operation but is
        /// permitted to use the temporary buffer for improved performance.  Each
        /// of Buffer->realp and Buffer->imagp must contain the lesser of 16,384
        /// bytes or N1*N0 * sizeof *C->realp bytes and is preferably 16-byte
        /// aligned or better.
        pub fn zopt2d(self: Self, input: *const SCT, ia0: Stride, output: *const SCT, ic0: Stride, buffer: *const SCT, log2n0: Length, log2n1: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft2d_zopt(self.setup, input, ia0, 1, output, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_zoptD(self.setup, input, ia0, 1, output, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        // -- 2D real --

        /// In-place two-dimensional real-to-complex Discrete Fourier Transform routine.
        ///
        /// If Direction is +1, a real-to-complex transform is performed.
        /// If Direction is -1, a complex-to-real inverse transform is performed.
        ///
        /// Unlike the two-dimensional complex transform, the dimensions are not
        /// symmetric in this real-to-complex transform.
        ///
        /// Direction must be +1 or -1.
        pub fn zrip2d(self: Self, io: *const SCT, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft2d_zrip(self.setup, io, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_zripD(self.setup, io, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// In-place two-dimensional real-to-complex Discrete Fourier Transform routine, with temporary memory.
        ///
        /// The temporary buffer version performs the same operation but is
        /// permitted to use the temporary buffer for improved performance.  Each
        /// of Buffer->realp and Buffer->imagp must contain space for the greater
        /// of N1 or N0/2 floating-point elements.  The addresses are preferably
        /// 16-byte aligned or better.
        pub fn zript2d(self: Self, io: *const SCT, ic0: Stride, buffer: *const SCT, log2n0: Length, log2n1: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft2d_zript(self.setup, io, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_zriptD(self.setup, io, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place two-dimensional real-to-complex Discrete Fourier Transform routine.
        ///
        /// If Direction is +1, a real-to-complex transform is performed.
        /// If Direction is -1, a complex-to-real inverse transform is performed.
        ///
        /// Unlike the two-dimensional complex transform, the dimensions are not
        /// symmetric in this real-to-complex transform.
        ///
        /// Direction must be +1 or -1.
        pub fn zrop2d(self: Self, input: *const SCT, ia0: Stride, output: *const SCT, ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft2d_zrop(self.setup, input, ia0, 1, output, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_zropD(self.setup, input, ia0, 1, output, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place two-dimensional real-to-complex Discrete Fourier Transform routine, with temporary memory.
        ///
        /// The temporary buffer version performs the same operation but is
        /// permitted to use the temporary buffer for improved performance.  Each
        /// of Buffer->realp and Buffer->imagp must contain space for the greater
        /// of N1 or N0/2 floating-point elements.  The addresses are preferably
        /// 16-byte aligned or better.
        pub fn zropt2d(self: Self, input: *const SCT, ia0: Stride, output: *const SCT, ic0: Stride, buffer: *const SCT, log2n0: Length, log2n1: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fft2d_zropt(self.setup, input, ia0, 1, output, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_zroptD(self.setup, input, ia0, 1, output, ic0, 1, buffer, log2n0, log2n1, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        // -- Batch --

        /// In-place multiple complex Discrete Fourier Transform routine.
        ///
        /// Performs M individual complex DFTs, each of length N = 1 << Log2N.
        ///
        /// Direction must be +1 or -1.
        pub fn mzip(self: Self, io: *const SCT, im: Stride, m: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fftm_zip(self.setup, io, 1, im, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_zipD(self.setup, io, 1, im, self.log2n, m, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// In-place multiple complex Discrete Fourier Transform routine, with temporary memory.
        ///
        /// The temporary buffer version performs the same operation but is
        /// permitted to use the temporary buffer for improved performance.  Each
        /// of Buffer->realp and Buffer->imagp must contain space for N
        /// floating-point elements and is preferably 16-byte aligned or better.
        pub fn mzipt(self: Self, io: *const SCT, im: Stride, buffer: *const SCT, m: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fftm_zipt(self.setup, io, 1, im, buffer, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_ziptD(self.setup, io, 1, im, buffer, self.log2n, m, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place multiple complex Discrete Fourier Transform routine.
        ///
        /// Performs M individual complex DFTs, each of length N = 1 << Log2N.
        ///
        /// Direction must be +1 or -1.
        pub fn mzop(self: Self, input: *const SCT, ima: Stride, output: *const SCT, imc: Stride, m: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fftm_zop(self.setup, input, 1, ima, output, 1, imc, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_zopD(self.setup, input, 1, ima, output, 1, imc, self.log2n, m, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place multiple complex Discrete Fourier Transform routine, with temporary memory.
        ///
        /// The temporary buffer version performs the same operation but is
        /// permitted to use the temporary buffer for improved performance.  Each
        /// of Buffer->realp and Buffer->imagp must contain space for N
        /// floating-point elements and is preferably 16-byte aligned or better.
        pub fn mzopt(self: Self, input: *const SCT, ima: Stride, output: *const SCT, imc: Stride, buffer: *const SCT, m: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fftm_zopt(self.setup, input, 1, ima, output, 1, imc, buffer, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_zoptD(self.setup, input, 1, ima, output, 1, imc, buffer, self.log2n, m, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// In-place multiple real-to-complex Discrete Fourier Transform routine.
        /// We suggest you use the DFT routines instead of these.
        ///
        /// Performs M individual real-to-complex (Direction +1) or complex-to-real
        /// (Direction -1) DFTs, each of length N = 1 << Log2N.
        ///
        /// Direction must be +1 or -1.
        pub fn mzrip(self: Self, io: *const SCT, im: Stride, m: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fftm_zrip(self.setup, io, 1, im, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_zripD(self.setup, io, 1, im, self.log2n, m, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// In-place multiple real-to-complex Discrete Fourier Transform routine, with temporary memory.
        /// We suggest you use the DFT routines instead of these.
        ///
        /// The temporary buffer version performs the same operation but is
        /// permitted to use the temporary buffer for improved performance.  Each
        /// of Buffer->realp and Buffer->imagp must contain space for N/2
        /// floating-point elements and is preferably 16-byte aligned or better.
        pub fn mzript(self: Self, io: *const SCT, im: Stride, buffer: *const SCT, m: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fftm_zript(self.setup, io, 1, im, buffer, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_zriptD(self.setup, io, 1, im, buffer, self.log2n, m, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place multiple real-to-complex Discrete Fourier Transform routine.
        /// We suggest you use the DFT routines instead of these.
        ///
        /// Performs M individual real-to-complex (Direction +1) or complex-to-real
        /// (Direction -1) DFTs, each of length N = 1 << Log2N.
        ///
        /// Direction must be +1 or -1.
        pub fn mzrop(self: Self, input: *const SCT, ima: Stride, output: *const SCT, imc: Stride, m: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fftm_zrop(self.setup, input, 1, ima, output, 1, imc, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_zropD(self.setup, input, 1, ima, output, 1, imc, self.log2n, m, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place multiple real-to-complex Discrete Fourier Transform routine, with temporary memory.
        /// We suggest you use the DFT routines instead of these.
        ///
        /// The temporary buffer version performs the same operation but is
        /// permitted to use the temporary buffer for improved performance.  Each
        /// of Buffer->realp and Buffer->imagp must contain space for N/2
        /// floating-point elements and is preferably 16-byte aligned or better.
        pub fn mzropt(self: Self, input: *const SCT, ima: Stride, output: *const SCT, imc: Stride, buffer: *const SCT, m: Length, direction: Direction) void {
            switch (T) {
                f32 => c.vDSP_fftm_zropt(self.setup, input, 1, ima, output, 1, imc, buffer, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_zroptD(self.setup, input, 1, ima, output, 1, imc, buffer, self.log2n, m, @intFromEnum(direction)),
                else => unreachable,
            }
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

test "ctoz and ztoc round-trip" {
    const input = [_]Complex(f32){
        Complex(f32).init(1.0, 2.0),
        Complex(f32).init(-3.0, 4.5),
        Complex(f32).init(0.0, -1.0),
    };
    var re: [3]f32 = undefined;
    var im: [3]f32 = undefined;
    const z = SC(f32){ .realp = &re, .imagp = &im };

    ctoz(f32, &input, &z, 3);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), im[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -3.0), re[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.5), im[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), re[2], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), im[2], 0.001);

    var output: [3]Complex(f32) = undefined;
    ztoc(f32, &z, &output, 3);
    for (0..3) |i| {
        try std.testing.expectApproxEqAbs(input[i].real, output[i].real, 0.001);
        try std.testing.expectApproxEqAbs(input[i].imag, output[i].imag, 0.001);
    }
}

test "zipt2d matches zip2d (fft2d_zipt header param-name anomaly check)" {
    // vDSP.h declares vDSP_fft2d_zipt's 3rd/4th params as (__IC1, __IC0),
    // reversed from vDSP_fft2d_zip/vDSP_fft2d_ziptD's (__IC0, __IC1). If that
    // reversal were real (not a header documentation typo), zipt2d would
    // silently compute a different (wrong) result than zip2d for the same
    // input whenever log2n0 != log2n1 and ic0 != 1. We use asymmetric
    // dimensions (N0=4, N1=8) and a non-trivial ic0 (=N1=8, i.e. dimension 0
    // has row-stride-8, dimension 1 is contiguous) specifically so a real
    // swap would be detectable.
    const log2n0: Length = 2; // N0 = 4
    const log2n1: Length = 3; // N1 = 8
    const n0: usize = 4;
    const n1: usize = 8;
    const total = n0 * n1;
    const ic0: Stride = @intCast(n1);

    const fft = try FFT(f32).init(@max(log2n0, log2n1), .radix2);
    defer fft.deinit();

    var zip_re: [total]f32 = undefined;
    var zip_im: [total]f32 = undefined;
    var zipt_re: [total]f32 = undefined;
    var zipt_im: [total]f32 = undefined;
    for (0..total) |i| {
        const v: f32 = @floatFromInt(i);
        zip_re[i] = v;
        zip_im[i] = -v * 0.5;
        zipt_re[i] = v;
        zipt_im[i] = -v * 0.5;
    }
    const zip_sc = SC(f32){ .realp = &zip_re, .imagp = &zip_im };
    const zipt_sc = SC(f32){ .realp = &zipt_re, .imagp = &zipt_im };

    var buf_re: [total]f32 = undefined;
    var buf_im: [total]f32 = undefined;
    const buffer = SC(f32){ .realp = &buf_re, .imagp = &buf_im };

    fft.zip2d(&zip_sc, ic0, log2n0, log2n1, .forward);
    fft.zipt2d(&zipt_sc, ic0, &buffer, log2n0, log2n1, .forward);

    for (0..total) |i| {
        try std.testing.expectApproxEqAbs(zip_re[i], zipt_re[i], 0.01);
        try std.testing.expectApproxEqAbs(zip_im[i], zipt_im[i], 0.01);
    }
}

test "zopt2d matches zop2d" {
    // Sibling sanity check to the zipt2d test above: vDSP_fft2d_zopt/zoptD's
    // parameter order matches vDSP_fft2d_zop/zopD in the header (no reversal
    // like zipt's), so this should already agree - confirms there's no
    // similar latent issue in the out-of-place temp-buffer path.
    const log2n0: Length = 2; // N0 = 4
    const log2n1: Length = 3; // N1 = 8
    const n0: usize = 4;
    const n1: usize = 8;
    const total = n0 * n1;
    const ia0: Stride = @intCast(n1);
    const ic0: Stride = @intCast(n1);

    const fft = try FFT(f32).init(@max(log2n0, log2n1), .radix2);
    defer fft.deinit();

    var in_re: [total]f32 = undefined;
    var in_im: [total]f32 = undefined;
    for (0..total) |i| {
        const v: f32 = @floatFromInt(i);
        in_re[i] = v;
        in_im[i] = -v * 0.5;
    }
    const input = SC(f32){ .realp = &in_re, .imagp = &in_im };

    var zop_re: [total]f32 = undefined;
    var zop_im: [total]f32 = undefined;
    var zopt_re: [total]f32 = undefined;
    var zopt_im: [total]f32 = undefined;
    const zop_out = SC(f32){ .realp = &zop_re, .imagp = &zop_im };
    const zopt_out = SC(f32){ .realp = &zopt_re, .imagp = &zopt_im };

    var buf_re: [total]f32 = undefined;
    var buf_im: [total]f32 = undefined;
    const buffer = SC(f32){ .realp = &buf_re, .imagp = &buf_im };

    fft.zop2d(&input, ia0, &zop_out, ic0, log2n0, log2n1, .forward);
    fft.zopt2d(&input, ia0, &zopt_out, ic0, &buffer, log2n0, log2n1, .forward);

    for (0..total) |i| {
        try std.testing.expectApproxEqAbs(zop_re[i], zopt_re[i], 0.01);
        try std.testing.expectApproxEqAbs(zop_im[i], zopt_im[i], 0.01);
    }
}
