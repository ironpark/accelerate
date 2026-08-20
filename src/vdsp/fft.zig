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
pub fn ctoz(comptime T: type, input: []const Complex(T), output: SS(T), n: Length) void {
    std.debug.assert(input.len >= n);
    std.debug.assert(output.len() >= n);
    var output_raw = output.raw();
    switch (T) {
        f32 => c.vDSP_ctoz(input.ptr, 2, &output_raw, 1, n),
        f64 => c.vDSP_ctozD(input.ptr, 2, &output_raw, 1, n),
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
pub fn ztoc(comptime T: type, input: SS(T), output: []Complex(T), n: Length) void {
    std.debug.assert(input.len() >= n);
    std.debug.assert(output.len >= n);
    var input_raw = input.raw();
    switch (T) {
        f32 => c.vDSP_ztoc(&input_raw, 1, output.ptr, 2, n),
        f64 => c.vDSP_ztocD(&input_raw, 1, output.ptr, 2, n),
        else => @compileError("ztoc requires f32 or f64"),
    }
}

const SC = types.SplitComplex;
const SS = types.SplitSlice;

// ============================================================================
// High-level FFT wrapper (manages setup lifetime)
// ============================================================================

/// A generic FFT wrapper parameterized on scalar type T (f32 or f64).
/// Manages the lifetime of the underlying vDSP FFT setup object.
pub fn FFT(comptime T: type) type {
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

        // -- Scaling conventions --
        //
        // vDSP FFTs are not normalized, and vDSP.h's pseudocode is *wrong*
        // about it: it claims a 1/N scale on the inverse leg that the real
        // implementation does not apply (confirmed by round-tripping an
        // impulse - see the tests at the bottom of this file). The
        // real-to-complex family adds a second wrinkle: it applies a 2x scale
        // on the forward leg only.
        //
        // Those two facts are the most easily-lost results of auditing this
        // module, so they live here as code you can call and that the test
        // suite checks, rather than only as prose in a doc comment that will
        // drift.

        /// Factor a complex round trip (`zip`/`zop` forward then inverse)
        /// multiplies the signal by. Divide by this to recover the original.
        ///
        ///     const s = fft.roundTripScale();
        ///     fft.zip(io, .forward);
        ///     fft.zip(io, .inverse);
        ///     vdsp.vsdiv(T, re, s, re);  // now back to the original
        pub fn roundTripScale(self: Self) T {
            return @floatFromInt(@as(usize, 1) << @intCast(self.log2n));
        }

        /// Factor the real-to-complex family (`zrip`/`zrop`) applies on the
        /// **forward** transform. vDSP.h documents this one accurately.
        pub fn realForwardScale(_: Self) T {
            return 2.0;
        }

        /// Factor a real round trip (`zrip` forward then inverse) multiplies
        /// the signal by: `2 * N`, not `N` and not 1. The asymmetry is
        /// because the forward leg scales by 2 and the inverse leg, contrary
        /// to vDSP.h's pseudocode, scales by 1.
        pub fn realRoundTripScale(self: Self) T {
            return 2.0 * self.roundTripScale();
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
        ///
        ///     // Define a complex vector, h:
        ///     for (j = 0; j < N; ++j)
        ///         h[j] = C->realp[j*IC] + i * C->imagp[j*IC];
        ///
        ///     // Perform Discrete Fourier Transform.
        ///     for (k = 0; k < N; ++k)
        ///         H[k] = sum(h[j] * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);
        ///
        ///     // Store result.
        ///     for (k = 0; k < N; ++k)
        ///     {
        ///         C->realp[k*IC] = Re(H[k]);
        ///         C->imagp[k*IC] = Im(H[k]);
        ///     }
        ///
        /// Direction must be +1 or -1.
        ///
        /// Note: unlike vDSP.h's documented pseudocode (which shows a 1/N
        /// scale applied when Direction is inverse), the actual vDSP FFT
        /// implementation is unnormalized in BOTH directions - confirmed by
        /// running an impulse through forward+inverse and observing N times
        /// the original signal, not the original signal. Divide by N
        /// yourself after an inverse transform if you need a true inverse.
        pub fn zip(self: Self, io: SS(T), direction: Direction) void {
            const n_elems = @as(usize, 1) << @intCast(self.log2n);
            std.debug.assert(io.len() >= n_elems);
            var io_raw = io.raw();
            switch (T) {
                f32 => c.vDSP_fft_zip(self.setup, &io_raw, 1, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_zipD(self.setup, &io_raw, 1, self.log2n, @intFromEnum(direction)),
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
        pub fn zipt(self: Self, io: SS(T), buffer: SS(T), direction: Direction) void {
            const n_elems = @as(usize, 1) << @intCast(self.log2n);
            std.debug.assert(io.len() >= n_elems);
            std.debug.assert(buffer.len() >= @min(n_elems, 16384 / @sizeOf(T)));
            var io_raw = io.raw();
            var buffer_raw = buffer.raw();
            switch (T) {
                f32 => c.vDSP_fft_zipt(self.setup, &io_raw, 1, &buffer_raw, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_ziptD(self.setup, &io_raw, 1, &buffer_raw, self.log2n, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place complex Discrete Fourier Transform routine.
        /// We suggest you use the DFT routines instead of these.
        ///
        /// These compute:
        ///
        ///     N = 1 << Log2N;
        ///
        ///     // Define a complex vector, h:
        ///     for (j = 0; j < N; ++j)
        ///         h[j] = A->realp[j*IA] + i * A->imagp[j*IA];
        ///
        ///     // Perform Discrete Fourier Transform.
        ///     for (k = 0; k < N; ++k)
        ///         H[k] = sum(h[j] * e**(-Direction*2*pi*i*j*k/N), 0 <= j < N);
        ///
        ///     // Store result.
        ///     for (k = 0; k < N; ++k)
        ///     {
        ///         C->realp[k*IC] = Re(H[k]);
        ///         C->imagp[k*IC] = Im(H[k]);
        ///     }
        ///
        /// Direction must be +1 or -1.
        ///
        /// Note: unlike vDSP.h's documented pseudocode (which shows a 1/N
        /// scale applied when Direction is inverse), the actual vDSP FFT
        /// implementation is unnormalized in BOTH directions - see zip()'s
        /// note above for the runtime-verified detail.
        pub fn zop(self: Self, input: SS(T), output: SS(T), direction: Direction) void {
            const n_elems = @as(usize, 1) << @intCast(self.log2n);
            std.debug.assert(input.len() >= n_elems);
            std.debug.assert(output.len() >= n_elems);
            var input_raw = input.raw();
            var output_raw = output.raw();
            switch (T) {
                f32 => c.vDSP_fft_zop(self.setup, &input_raw, 1, &output_raw, 1, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_zopD(self.setup, &input_raw, 1, &output_raw, 1, self.log2n, @intFromEnum(direction)),
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
        pub fn zopt(self: Self, input: SS(T), output: SS(T), buffer: SS(T), direction: Direction) void {
            const n_elems = @as(usize, 1) << @intCast(self.log2n);
            std.debug.assert(input.len() >= n_elems);
            std.debug.assert(output.len() >= n_elems);
            std.debug.assert(buffer.len() >= @min(n_elems, 16384 / @sizeOf(T)));
            var input_raw = input.raw();
            var output_raw = output.raw();
            var buffer_raw = buffer.raw();
            switch (T) {
                f32 => c.vDSP_fft_zopt(self.setup, &input_raw, 1, &output_raw, 1, &buffer_raw, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_zoptD(self.setup, &input_raw, 1, &output_raw, 1, &buffer_raw, self.log2n, @intFromEnum(direction)),
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
        ///
        /// Scaling, runtime-confirmed (see fft.zig tests): the forward
        /// transform's result is 2x the equivalent complex FFT (vDSP.h
        /// documents this "scale = 2" explicitly, and it matches reality).
        /// The inverse transform, despite vDSP.h's pseudocode claiming a
        /// "scale = 1./N" normalization, is NOT normalized at runtime - a
        /// forward+inverse round trip returns 2*N times the original signal,
        /// not the original signal. Divide by 2*N yourself for a true
        /// inverse.
        ///
        /// DC and Nyquist packing: both are purely real for a real input, so
        /// they are packed specially into io.realp[0] (DC, Re(H[0])) and
        /// io.imagp[0] (Nyquist, Re(H[N/2])); regular bins 1..N/2-1 use
        /// realp[k]/imagp[k] for their Re/Im parts as usual.
        pub fn zrip(self: Self, io: SS(T), direction: Direction) void {
            const n_elems = (@as(usize, 1) << @intCast(self.log2n)) / 2;
            std.debug.assert(io.len() >= n_elems);
            var io_raw = io.raw();
            switch (T) {
                f32 => c.vDSP_fft_zrip(self.setup, &io_raw, 1, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_zripD(self.setup, &io_raw, 1, self.log2n, @intFromEnum(direction)),
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
        pub fn zript(self: Self, io: SS(T), buffer: SS(T), direction: Direction) void {
            const n_elems = (@as(usize, 1) << @intCast(self.log2n)) / 2;
            std.debug.assert(io.len() >= n_elems);
            // vDSP.h:952/1081: the real-transform temp buffer must hold exactly
            // N/2 elements (no 16,384-byte cap, unlike the complex variants).
            std.debug.assert(buffer.len() >= n_elems);
            var io_raw = io.raw();
            var buffer_raw = buffer.raw();
            switch (T) {
                f32 => c.vDSP_fft_zript(self.setup, &io_raw, 1, &buffer_raw, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_zriptD(self.setup, &io_raw, 1, &buffer_raw, self.log2n, @intFromEnum(direction)),
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
        ///
        /// Same scaling and DC/Nyquist packing convention as zrip() - see its
        /// doc comment for the runtime-confirmed detail.
        pub fn zrop(self: Self, input: SS(T), output: SS(T), direction: Direction) void {
            const n_elems = (@as(usize, 1) << @intCast(self.log2n)) / 2;
            std.debug.assert(input.len() >= n_elems);
            std.debug.assert(output.len() >= n_elems);
            var input_raw = input.raw();
            var output_raw = output.raw();
            switch (T) {
                f32 => c.vDSP_fft_zrop(self.setup, &input_raw, 1, &output_raw, 1, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_zropD(self.setup, &input_raw, 1, &output_raw, 1, self.log2n, @intFromEnum(direction)),
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
        pub fn zropt(self: Self, input: SS(T), output: SS(T), buffer: SS(T), direction: Direction) void {
            const n_elems = (@as(usize, 1) << @intCast(self.log2n)) / 2;
            std.debug.assert(input.len() >= n_elems);
            std.debug.assert(output.len() >= n_elems);
            // vDSP.h:952/1081: the real-transform temp buffer must hold exactly
            // N/2 elements (no 16,384-byte cap, unlike the complex variants).
            std.debug.assert(buffer.len() >= n_elems);
            var input_raw = input.raw();
            var output_raw = output.raw();
            var buffer_raw = buffer.raw();
            switch (T) {
                f32 => c.vDSP_fft_zropt(self.setup, &input_raw, 1, &output_raw, 1, &buffer_raw, self.log2n, @intFromEnum(direction)),
                f64 => c.vDSP_fft_zroptD(self.setup, &input_raw, 1, &output_raw, 1, &buffer_raw, self.log2n, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        // -- 2D complex --

        /// In-place two-dimensional complex Discrete Fourier Transform routine.
        ///
        /// Direction must be +1 or -1.
        pub fn zip2d(self: Self, io: SS(T), ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
            const n0 = @as(usize, 1) << @intCast(log2n0);
            const n1 = @as(usize, 1) << @intCast(log2n1);
            if (ic0 > 0) std.debug.assert(io.len() >= (n0 - 1) * @as(usize, @intCast(ic0)) + n1);
            var io_raw = io.raw();
            switch (T) {
                f32 => c.vDSP_fft2d_zip(self.setup, &io_raw, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_zipD(self.setup, &io_raw, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
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
        pub fn zipt2d(self: Self, io: SS(T), ic0: Stride, buffer: SS(T), log2n0: Length, log2n1: Length, direction: Direction) void {
            const n0 = @as(usize, 1) << @intCast(log2n0);
            const n1 = @as(usize, 1) << @intCast(log2n1);
            if (ic0 > 0) std.debug.assert(io.len() >= (n0 - 1) * @as(usize, @intCast(ic0)) + n1);
            std.debug.assert(buffer.len() >= @min(n0 * n1, 16384 / @sizeOf(T)));
            var io_raw = io.raw();
            var buffer_raw = buffer.raw();
            switch (T) {
                f32 => c.vDSP_fft2d_zipt(self.setup, &io_raw, ic0, 1, &buffer_raw, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_ziptD(self.setup, &io_raw, ic0, 1, &buffer_raw, log2n0, log2n1, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place two-dimensional complex Discrete Fourier Transform routine.
        ///
        /// Direction must be +1 or -1.
        pub fn zop2d(self: Self, input: SS(T), ia0: Stride, output: SS(T), ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
            const n0 = @as(usize, 1) << @intCast(log2n0);
            const n1 = @as(usize, 1) << @intCast(log2n1);
            if (ia0 > 0) std.debug.assert(input.len() >= (n0 - 1) * @as(usize, @intCast(ia0)) + n1);
            if (ic0 > 0) std.debug.assert(output.len() >= (n0 - 1) * @as(usize, @intCast(ic0)) + n1);
            var input_raw = input.raw();
            var output_raw = output.raw();
            switch (T) {
                f32 => c.vDSP_fft2d_zop(self.setup, &input_raw, ia0, 1, &output_raw, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_zopD(self.setup, &input_raw, ia0, 1, &output_raw, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
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
        pub fn zopt2d(self: Self, input: SS(T), ia0: Stride, output: SS(T), ic0: Stride, buffer: SS(T), log2n0: Length, log2n1: Length, direction: Direction) void {
            const n0 = @as(usize, 1) << @intCast(log2n0);
            const n1 = @as(usize, 1) << @intCast(log2n1);
            if (ia0 > 0) std.debug.assert(input.len() >= (n0 - 1) * @as(usize, @intCast(ia0)) + n1);
            if (ic0 > 0) std.debug.assert(output.len() >= (n0 - 1) * @as(usize, @intCast(ic0)) + n1);
            std.debug.assert(buffer.len() >= @min(n0 * n1, 16384 / @sizeOf(T)));
            var input_raw = input.raw();
            var output_raw = output.raw();
            var buffer_raw = buffer.raw();
            switch (T) {
                f32 => c.vDSP_fft2d_zopt(self.setup, &input_raw, ia0, 1, &output_raw, ic0, 1, &buffer_raw, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_zoptD(self.setup, &input_raw, ia0, 1, &output_raw, ic0, 1, &buffer_raw, log2n0, log2n1, @intFromEnum(direction)),
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
        ///
        /// Scaling, runtime-confirmed the same way as the 1D zrip(): the
        /// forward transform applies vDSP.h's documented "scale = 2", but
        /// the inverse transform does NOT apply the "scale = 1/(N0*N1)"
        /// vDSP.h's pseudocode claims - a forward+inverse round trip returns
        /// 2*N0*N1 times the original signal. Divide by 2*N0*N1 yourself for
        /// a true inverse.
        ///
        /// DC/Nyquist packing here is more involved than the 1D case (an
        /// "awkward format... due to a legacy implementation" per vDSP.h -
        /// see vDSP.h's vDSP_fft2d_zrip Maps comment for the exact element
        /// layout); this binding passes strides straight through to vDSP so
        /// that layout is unchanged from what vDSP.h documents.
        pub fn zrip2d(self: Self, io: SS(T), ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
            var io_raw = io.raw();
            switch (T) {
                f32 => c.vDSP_fft2d_zrip(self.setup, &io_raw, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_zripD(self.setup, &io_raw, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
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
        pub fn zript2d(self: Self, io: SS(T), ic0: Stride, buffer: SS(T), log2n0: Length, log2n1: Length, direction: Direction) void {
            var io_raw = io.raw();
            var buffer_raw = buffer.raw();
            switch (T) {
                f32 => c.vDSP_fft2d_zript(self.setup, &io_raw, ic0, 1, &buffer_raw, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_zriptD(self.setup, &io_raw, ic0, 1, &buffer_raw, log2n0, log2n1, @intFromEnum(direction)),
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
        ///
        /// Same scaling and DC/Nyquist packing convention as zrip2d() - see
        /// its doc comment for the runtime-confirmed detail.
        pub fn zrop2d(self: Self, input: SS(T), ia0: Stride, output: SS(T), ic0: Stride, log2n0: Length, log2n1: Length, direction: Direction) void {
            var input_raw = input.raw();
            var output_raw = output.raw();
            switch (T) {
                f32 => c.vDSP_fft2d_zrop(self.setup, &input_raw, ia0, 1, &output_raw, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_zropD(self.setup, &input_raw, ia0, 1, &output_raw, ic0, 1, log2n0, log2n1, @intFromEnum(direction)),
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
        pub fn zropt2d(self: Self, input: SS(T), ia0: Stride, output: SS(T), ic0: Stride, buffer: SS(T), log2n0: Length, log2n1: Length, direction: Direction) void {
            var input_raw = input.raw();
            var output_raw = output.raw();
            var buffer_raw = buffer.raw();
            switch (T) {
                f32 => c.vDSP_fft2d_zropt(self.setup, &input_raw, ia0, 1, &output_raw, ic0, 1, &buffer_raw, log2n0, log2n1, @intFromEnum(direction)),
                f64 => c.vDSP_fft2d_zroptD(self.setup, &input_raw, ia0, 1, &output_raw, ic0, 1, &buffer_raw, log2n0, log2n1, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        // -- Batch --

        /// In-place multiple complex Discrete Fourier Transform routine.
        ///
        /// Performs M individual complex DFTs, each of length N = 1 << Log2N.
        ///
        /// Direction must be +1 or -1.
        pub fn mzip(self: Self, io: SS(T), im: Stride, m: Length, direction: Direction) void {
            const n_elems = @as(usize, 1) << @intCast(self.log2n);
            if (im > 0) std.debug.assert(io.len() >= (m - 1) * @as(usize, @intCast(im)) + n_elems);
            var io_raw = io.raw();
            switch (T) {
                f32 => c.vDSP_fftm_zip(self.setup, &io_raw, 1, im, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_zipD(self.setup, &io_raw, 1, im, self.log2n, m, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// In-place multiple complex Discrete Fourier Transform routine, with temporary memory.
        ///
        /// The temporary buffer version performs the same operation but is
        /// permitted to use the temporary buffer for improved performance.  Each
        /// of Buffer->realp and Buffer->imagp must contain space for N
        /// floating-point elements and is preferably 16-byte aligned or better.
        pub fn mzipt(self: Self, io: SS(T), im: Stride, buffer: SS(T), m: Length, direction: Direction) void {
            const n_elems = @as(usize, 1) << @intCast(self.log2n);
            if (im > 0) std.debug.assert(io.len() >= (m - 1) * @as(usize, @intCast(im)) + n_elems);
            // vDSP.h:1721/1956: the batched temp buffer holds N (complex) or
            // N/2 (real) elements - NOT m*N. n_elems already carries that split.
            std.debug.assert(buffer.len() >= n_elems);
            var io_raw = io.raw();
            var buffer_raw = buffer.raw();
            switch (T) {
                f32 => c.vDSP_fftm_zipt(self.setup, &io_raw, 1, im, &buffer_raw, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_ziptD(self.setup, &io_raw, 1, im, &buffer_raw, self.log2n, m, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place multiple complex Discrete Fourier Transform routine.
        ///
        /// Performs M individual complex DFTs, each of length N = 1 << Log2N.
        ///
        /// Direction must be +1 or -1.
        pub fn mzop(self: Self, input: SS(T), ima: Stride, output: SS(T), imc: Stride, m: Length, direction: Direction) void {
            const n_elems = @as(usize, 1) << @intCast(self.log2n);
            if (ima > 0) std.debug.assert(input.len() >= (m - 1) * @as(usize, @intCast(ima)) + n_elems);
            if (imc > 0) std.debug.assert(output.len() >= (m - 1) * @as(usize, @intCast(imc)) + n_elems);
            var input_raw = input.raw();
            var output_raw = output.raw();
            switch (T) {
                f32 => c.vDSP_fftm_zop(self.setup, &input_raw, 1, ima, &output_raw, 1, imc, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_zopD(self.setup, &input_raw, 1, ima, &output_raw, 1, imc, self.log2n, m, @intFromEnum(direction)),
                else => unreachable,
            }
        }

        /// Out-of-place multiple complex Discrete Fourier Transform routine, with temporary memory.
        ///
        /// The temporary buffer version performs the same operation but is
        /// permitted to use the temporary buffer for improved performance.  Each
        /// of Buffer->realp and Buffer->imagp must contain space for N
        /// floating-point elements and is preferably 16-byte aligned or better.
        pub fn mzopt(self: Self, input: SS(T), ima: Stride, output: SS(T), imc: Stride, buffer: SS(T), m: Length, direction: Direction) void {
            const n_elems = @as(usize, 1) << @intCast(self.log2n);
            if (ima > 0) std.debug.assert(input.len() >= (m - 1) * @as(usize, @intCast(ima)) + n_elems);
            if (imc > 0) std.debug.assert(output.len() >= (m - 1) * @as(usize, @intCast(imc)) + n_elems);
            // vDSP.h:1721/1956: the batched temp buffer holds N (complex) or
            // N/2 (real) elements - NOT m*N. n_elems already carries that split.
            std.debug.assert(buffer.len() >= n_elems);
            var input_raw = input.raw();
            var output_raw = output.raw();
            var buffer_raw = buffer.raw();
            switch (T) {
                f32 => c.vDSP_fftm_zopt(self.setup, &input_raw, 1, ima, &output_raw, 1, imc, &buffer_raw, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_zoptD(self.setup, &input_raw, 1, ima, &output_raw, 1, imc, &buffer_raw, self.log2n, m, @intFromEnum(direction)),
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
        pub fn mzrip(self: Self, io: SS(T), im: Stride, m: Length, direction: Direction) void {
            const n_elems = (@as(usize, 1) << @intCast(self.log2n)) / 2;
            if (im > 0) std.debug.assert(io.len() >= (m - 1) * @as(usize, @intCast(im)) + n_elems);
            var io_raw = io.raw();
            switch (T) {
                f32 => c.vDSP_fftm_zrip(self.setup, &io_raw, 1, im, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_zripD(self.setup, &io_raw, 1, im, self.log2n, m, @intFromEnum(direction)),
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
        pub fn mzript(self: Self, io: SS(T), im: Stride, buffer: SS(T), m: Length, direction: Direction) void {
            const n_elems = (@as(usize, 1) << @intCast(self.log2n)) / 2;
            if (im > 0) std.debug.assert(io.len() >= (m - 1) * @as(usize, @intCast(im)) + n_elems);
            // vDSP.h:1721/1956: the batched temp buffer holds N (complex) or
            // N/2 (real) elements - NOT m*N. n_elems already carries that split.
            std.debug.assert(buffer.len() >= n_elems);
            var io_raw = io.raw();
            var buffer_raw = buffer.raw();
            switch (T) {
                f32 => c.vDSP_fftm_zript(self.setup, &io_raw, 1, im, &buffer_raw, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_zriptD(self.setup, &io_raw, 1, im, &buffer_raw, self.log2n, m, @intFromEnum(direction)),
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
        pub fn mzrop(self: Self, input: SS(T), ima: Stride, output: SS(T), imc: Stride, m: Length, direction: Direction) void {
            const n_elems = (@as(usize, 1) << @intCast(self.log2n)) / 2;
            if (ima > 0) std.debug.assert(input.len() >= (m - 1) * @as(usize, @intCast(ima)) + n_elems);
            if (imc > 0) std.debug.assert(output.len() >= (m - 1) * @as(usize, @intCast(imc)) + n_elems);
            var input_raw = input.raw();
            var output_raw = output.raw();
            switch (T) {
                f32 => c.vDSP_fftm_zrop(self.setup, &input_raw, 1, ima, &output_raw, 1, imc, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_zropD(self.setup, &input_raw, 1, ima, &output_raw, 1, imc, self.log2n, m, @intFromEnum(direction)),
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
        pub fn mzropt(self: Self, input: SS(T), ima: Stride, output: SS(T), imc: Stride, buffer: SS(T), m: Length, direction: Direction) void {
            const n_elems = (@as(usize, 1) << @intCast(self.log2n)) / 2;
            if (ima > 0) std.debug.assert(input.len() >= (m - 1) * @as(usize, @intCast(ima)) + n_elems);
            if (imc > 0) std.debug.assert(output.len() >= (m - 1) * @as(usize, @intCast(imc)) + n_elems);
            // vDSP.h:1721/1956: the batched temp buffer holds N (complex) or
            // N/2 (real) elements - NOT m*N. n_elems already carries that split.
            std.debug.assert(buffer.len() >= n_elems);
            var input_raw = input.raw();
            var output_raw = output.raw();
            var buffer_raw = buffer.raw();
            switch (T) {
                f32 => c.vDSP_fftm_zropt(self.setup, &input_raw, 1, ima, &output_raw, 1, imc, &buffer_raw, self.log2n, m, @intFromEnum(direction)),
                f64 => c.vDSP_fftm_zroptD(self.setup, &input_raw, 1, ima, &output_raw, 1, imc, &buffer_raw, self.log2n, m, @intFromEnum(direction)),
                else => unreachable,
            }
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

test "FFT init/deinit and zip forward+inverse round-trip" {
    const log2n: Length = 2; // N = 4
    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    // Impulse at n=0: forward DFT is a constant spectrum, [1,1,1,1] for
    // N=4. vDSP.h's pseudocode says the inverse direction applies a 1/N
    // scale ("scale = 0 < Direction ? 1 : 1./N"), but the actual (hardware-
    // accelerated) implementation does NOT normalize either direction - per
    // fix/REQUEST.md's own note that vDSP FFTs are unnormalized. Measured:
    // inverting [1,1,1,1] yields [4,0,0,0], i.e. N times the original
    // impulse, not the impulse itself. This confirms the binding passes
    // Direction through correctly; the header's scale comment just doesn't
    // reflect the real implementation, so callers must divide by N
    // themselves for a true inverse.
    var re = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    var im = [_]f32{ 0.0, 0.0, 0.0, 0.0 };
    const io = SS(f32).init(&re, &im);

    fft.zip(io, .forward);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), re[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), re[2], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), re[3], 0.001);
    for (im) |v| try std.testing.expectApproxEqAbs(@as(f32, 0.0), v, 0.001);

    fft.zip(io, .inverse);
    const n: f32 = 4.0;
    try std.testing.expectApproxEqAbs(n, re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), re[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), re[2], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), re[3], 0.001);
    for (im) |v| try std.testing.expectApproxEqAbs(@as(f32, 0.0), v, 0.001);
}

test "ctoz and ztoc round-trip" {
    const input = [_]Complex(f32){
        Complex(f32).init(1.0, 2.0),
        Complex(f32).init(-3.0, 4.5),
        Complex(f32).init(0.0, -1.0),
    };
    var re: [3]f32 = undefined;
    var im: [3]f32 = undefined;
    const z = SS(f32).init(&re, &im);

    ctoz(f32, &input, z, 3);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), im[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -3.0), re[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.5), im[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), re[2], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), im[2], 0.001);

    var output: [3]Complex(f32) = undefined;
    ztoc(f32, z, &output, 3);
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
    const zip_sc = SS(f32).init(&zip_re, &zip_im);
    const zipt_sc = SS(f32).init(&zipt_re, &zipt_im);

    var buf_re: [total]f32 = undefined;
    var buf_im: [total]f32 = undefined;
    const buffer = SS(f32).init(&buf_re, &buf_im);

    fft.zip2d(zip_sc, ic0, log2n0, log2n1, .forward);
    fft.zipt2d(zipt_sc, ic0, buffer, log2n0, log2n1, .forward);

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
    const input = SS(f32).init(&in_re, &in_im);

    var zop_re: [total]f32 = undefined;
    var zop_im: [total]f32 = undefined;
    var zopt_re: [total]f32 = undefined;
    var zopt_im: [total]f32 = undefined;
    const zop_out = SS(f32).init(&zop_re, &zop_im);
    const zopt_out = SS(f32).init(&zopt_re, &zopt_im);

    var buf_re: [total]f32 = undefined;
    var buf_im: [total]f32 = undefined;
    const buffer = SS(f32).init(&buf_re, &buf_im);

    fft.zop2d(input, ia0, zop_out, ic0, log2n0, log2n1, .forward);
    fft.zopt2d(input, ia0, zopt_out, ic0, buffer, log2n0, log2n1, .forward);

    for (0..total) |i| {
        try std.testing.expectApproxEqAbs(zop_re[i], zopt_re[i], 0.01);
        try std.testing.expectApproxEqAbs(zop_im[i], zopt_im[i], 0.01);
    }
}

// -- 1D complex: zipt/zop/zopt cross-checked against zip --

test "zop matches zip (out-of-place forward equals in-place forward, asymmetric input)" {
    // vDSP_fft_zop's header order (Setup, A, IA, C, IC, Log2N, Direction)
    // matches the wrapper's call positionally. Cross-check its result
    // against the already-verified zip on the same starting data.
    const log2n: Length = 3; // N = 8
    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    const in_re = [_]f32{ 1.0, -2.5, 3.0, 0.5, -4.0, 2.0, -1.5, 6.0 };
    const in_im = [_]f32{ 0.5, 1.0, -2.0, 0.0, 3.0, -1.0, 0.0, 2.5 };

    var zip_re = in_re;
    var zip_im = in_im;
    const zip_io = SS(f32).init(&zip_re, &zip_im);
    fft.zip(zip_io, .forward);

    var a_re = in_re;
    var a_im = in_im;
    var out_re: [8]f32 = undefined;
    var out_im: [8]f32 = undefined;
    const input = SS(f32).init(&a_re, &a_im);
    const output = SS(f32).init(&out_re, &out_im);
    fft.zop(input, output, .forward);

    for (0..8) |i| {
        try std.testing.expectApproxEqAbs(zip_re[i], out_re[i], 0.01);
        try std.testing.expectApproxEqAbs(zip_im[i], out_im[i], 0.01);
    }
}

test "zipt matches zip (temp-buffer in-place agrees with buffer-less in-place)" {
    const log2n: Length = 3; // N = 8
    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    const in_re = [_]f32{ 2.0, -1.0, 0.5, 4.5, -3.0, 1.5, 0.0, -6.0 };
    const in_im = [_]f32{ -1.0, 0.0, 2.0, -0.5, 1.0, 3.0, -2.0, 0.5 };

    var zip_re = in_re;
    var zip_im = in_im;
    const zip_io = SS(f32).init(&zip_re, &zip_im);
    fft.zip(zip_io, .inverse);

    var zipt_re = in_re;
    var zipt_im = in_im;
    const zipt_io = SS(f32).init(&zipt_re, &zipt_im);
    var buf_re: [8]f32 = undefined;
    var buf_im: [8]f32 = undefined;
    const buffer = SS(f32).init(&buf_re, &buf_im);
    fft.zipt(zipt_io, buffer, .inverse);

    for (0..8) |i| {
        try std.testing.expectApproxEqAbs(zip_re[i], zipt_re[i], 0.01);
        try std.testing.expectApproxEqAbs(zip_im[i], zipt_im[i], 0.01);
    }
}

test "zopt matches zop (temp-buffer out-of-place agrees with buffer-less out-of-place)" {
    const log2n: Length = 3; // N = 8
    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    var a_re = [_]f32{ 1.0, -2.5, 3.0, 0.5, -4.0, 2.0, -1.5, 6.0 };
    var a_im = [_]f32{ 0.5, 1.0, -2.0, 0.0, 3.0, -1.0, 0.0, 2.5 };
    const input = SS(f32).init(&a_re, &a_im);

    var zop_re: [8]f32 = undefined;
    var zop_im: [8]f32 = undefined;
    const zop_out = SS(f32).init(&zop_re, &zop_im);
    fft.zop(input, zop_out, .forward);

    var zopt_re: [8]f32 = undefined;
    var zopt_im: [8]f32 = undefined;
    const zopt_out = SS(f32).init(&zopt_re, &zopt_im);
    var buf_re: [8]f32 = undefined;
    var buf_im: [8]f32 = undefined;
    const buffer = SS(f32).init(&buf_re, &buf_im);
    fft.zopt(input, zopt_out, buffer, .forward);

    for (0..8) |i| {
        try std.testing.expectApproxEqAbs(zop_re[i], zopt_re[i], 0.01);
        try std.testing.expectApproxEqAbs(zop_im[i], zopt_im[i], 0.01);
    }
}

// -- 1D real: zrip/zript/zrop/zropt --

test "zrip forward matches vDSP.h's documented 2x-of-equivalent-complex-FFT scale" {
    // Cross-check zrip (real FFT) against the already-verified zip (complex
    // FFT) using the same underlying real signal, per REQUEST.md's guidance
    // to verify vDSP.h's documented real-FFT 2x scaling convention
    // (vDSP.h:~880 "scale = 2") at runtime rather than trust it blindly.
    //
    // zrip's packed input format interleaves the real signal as
    // realp[j] = x[2j], imagp[j] = x[2j+1]; DC/Nyquist (both real, since the
    // input is real) are packed specially into realp[0]/imagp[0].
    const log2n: Length = 3; // N = 8
    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    const x = [_]f32{ 1.0, 2.0, -3.0, 0.5, 4.0, -1.0, 2.0, 7.0 }; // asymmetric real signal

    // Reference: zero-padded complex FFT of the same real signal. zip's
    // forward is confirmed unnormalized (scale=1), so this gives X[k] with
    // no extra factor.
    var zre = x;
    var zim = [_]f32{0} ** 8;
    const zio = SS(f32).init(&zre, &zim);
    fft.zip(zio, .forward);

    var rre = [_]f32{ x[0], x[2], x[4], x[6] };
    var rim = [_]f32{ x[1], x[3], x[5], x[7] };
    const rio = SS(f32).init(&rre, &rim);
    fft.zrip(rio, .forward);

    // Special DC/Nyquist packing: realp[0] = 2*Re(X[0]), imagp[0] = 2*Re(X[N/2]).
    try std.testing.expectApproxEqAbs(2.0 * zre[0], rre[0], 0.02);
    try std.testing.expectApproxEqAbs(2.0 * zre[4], rim[0], 0.02);
    // Regular bins k=1..N/2-1: realp[k] = 2*Re(X[k]), imagp[k] = 2*Im(X[k]).
    for (1..4) |k| {
        try std.testing.expectApproxEqAbs(2.0 * zre[k], rre[k], 0.02);
        try std.testing.expectApproxEqAbs(2.0 * zim[k], rim[k], 0.02);
    }
}

test "zrip inverse is unnormalized (not the 1/N vDSP.h documents)" {
    // As with zip/zop (see the note on zip() above), vDSP.h's pseudocode for
    // zrip's inverse direction (vDSP.h:~915) claims `scale = 1./N`, but a
    // measured forward+inverse round trip shows the real implementation
    // applies NO extra 1/N normalization on top of the forward pass's own
    // scale=2 - an impulse round-tripped through forward+inverse came back
    // as 2*N times the original value (2*8=16 for N=8), not the original
    // value nor 2x the original value the header's literal formulas would
    // predict. Divide by 2*N yourself for a true round trip.
    const log2n: Length = 3; // N = 8
    const n: f32 = 8.0;
    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    const x = [_]f32{ 1.0, 2.0, -3.0, 0.5, 4.0, -1.0, 2.0, 7.0 };
    var rre = [_]f32{ x[0], x[2], x[4], x[6] };
    var rim = [_]f32{ x[1], x[3], x[5], x[7] };
    const rio = SS(f32).init(&rre, &rim);

    fft.zrip(rio, .forward);
    fft.zrip(rio, .inverse);

    for (0..4) |j| {
        try std.testing.expectApproxEqAbs(2.0 * n * x[2 * j], rre[j], 0.1);
        try std.testing.expectApproxEqAbs(2.0 * n * x[2 * j + 1], rim[j], 0.1);
    }
}

test "zript matches zrip (temp-buffer real FFT agrees with buffer-less version)" {
    const log2n: Length = 3; // N = 8
    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    const packed_re = [_]f32{ 1.0, -3.0, 4.0, 2.0 };
    const packed_im = [_]f32{ 2.0, 0.5, -1.0, 7.0 };

    var a_re = packed_re;
    var a_im = packed_im;
    const a_io = SS(f32).init(&a_re, &a_im);
    fft.zrip(a_io, .forward);

    var b_re = packed_re;
    var b_im = packed_im;
    const b_io = SS(f32).init(&b_re, &b_im);
    var buf_re: [4]f32 = undefined;
    var buf_im: [4]f32 = undefined;
    const buffer = SS(f32).init(&buf_re, &buf_im);
    fft.zript(b_io, buffer, .forward);

    for (0..4) |i| {
        try std.testing.expectApproxEqAbs(a_re[i], b_re[i], 0.02);
        try std.testing.expectApproxEqAbs(a_im[i], b_im[i], 0.02);
    }
}

test "zrop matches zrip (out-of-place equals in-place, same input)" {
    const log2n: Length = 3; // N = 8
    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    const packed_re = [_]f32{ 1.0, -3.0, 4.0, 2.0 };
    const packed_im = [_]f32{ 2.0, 0.5, -1.0, 7.0 };

    var ip_re = packed_re;
    var ip_im = packed_im;
    const ip_io = SS(f32).init(&ip_re, &ip_im);
    fft.zrip(ip_io, .forward);

    var oa_re = packed_re;
    var oa_im = packed_im;
    const oa_in = SS(f32).init(&oa_re, &oa_im);
    var oc_re: [4]f32 = undefined;
    var oc_im: [4]f32 = undefined;
    const oa_out = SS(f32).init(&oc_re, &oc_im);
    fft.zrop(oa_in, oa_out, .forward);

    for (0..4) |i| {
        try std.testing.expectApproxEqAbs(ip_re[i], oc_re[i], 0.02);
        try std.testing.expectApproxEqAbs(ip_im[i], oc_im[i], 0.02);
    }
}

test "zropt matches zrop (temp-buffer out-of-place agrees with buffer-less)" {
    const log2n: Length = 3; // N = 8
    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    var a_re = [_]f32{ 1.0, -3.0, 4.0, 2.0 };
    var a_im = [_]f32{ 2.0, 0.5, -1.0, 7.0 };
    const input = SS(f32).init(&a_re, &a_im);

    var zrop_re: [4]f32 = undefined;
    var zrop_im: [4]f32 = undefined;
    const zrop_out = SS(f32).init(&zrop_re, &zrop_im);
    fft.zrop(input, zrop_out, .forward);

    var zropt_re: [4]f32 = undefined;
    var zropt_im: [4]f32 = undefined;
    const zropt_out = SS(f32).init(&zropt_re, &zropt_im);
    var buf_re: [4]f32 = undefined;
    var buf_im: [4]f32 = undefined;
    const buffer = SS(f32).init(&buf_re, &buf_im);
    fft.zropt(input, zropt_out, buffer, .forward);

    for (0..4) |i| {
        try std.testing.expectApproxEqAbs(zrop_re[i], zropt_re[i], 0.02);
        try std.testing.expectApproxEqAbs(zrop_im[i], zropt_im[i], 0.02);
    }
}

// -- 2D complex: zip2d/zop2d --

/// Test-only reference: compute a 2D complex DFT as two separable 1D
/// passes using the already-verified zip(), per vDSP.h's own note
/// (vDSP.h:~1160) that the 2D transform is separable across dimensions.
/// Matches the wrapper's layout convention (dim1, size n1, is contiguous;
/// dim0, size n0, has caller-supplied stride ic0).
/// fft_n1 must have been created with log2n = log2(n1); fft_n0 with
/// log2n = log2(n0) (each zip() call only knows its own instance's fixed
/// log2n, so the two passes need separately-sized FFT instances).
fn refFft2dViaZip(fft_n0: FFT(f32), fft_n1: FFT(f32), re: []f32, im: []f32, ic0: usize, n0: usize, n1: usize, direction: Direction) void {
    // Pass 1: transform along dim1 (contiguous) for each of the n0 rows.
    for (0..n0) |row| {
        const off = row * ic0;
        const sc = SS(f32).init(re[off..], im[off..]);
        fft_n1.zip(sc, direction);
    }
    // Pass 2: transform along dim0 (stride ic0) for each of the n1 columns;
    // gather into a contiguous temp buffer since zip requires stride-1 data.
    var tmp_re: [64]f32 = undefined;
    var tmp_im: [64]f32 = undefined;
    for (0..n1) |col| {
        for (0..n0) |row| {
            tmp_re[row] = re[row * ic0 + col];
            tmp_im[row] = im[row * ic0 + col];
        }
        const sc = SS(f32).init(tmp_re[0..n0], tmp_im[0..n0]);
        fft_n0.zip(sc, direction);
        for (0..n0) |row| {
            re[row * ic0 + col] = tmp_re[row];
            im[row * ic0 + col] = tmp_im[row];
        }
    }
}

test "zip2d matches zip-based separable reference (argument order check)" {
    const log2n0: Length = 2; // N0 = 4
    const log2n1: Length = 3; // N1 = 8
    const n0: usize = 4;
    const n1: usize = 8;
    const total = n0 * n1;
    const ic0: Stride = @intCast(n1);

    const fft = try FFT(f32).init(@max(log2n0, log2n1), .radix2);
    defer fft.deinit();
    const fft_n0 = try FFT(f32).init(log2n0, .radix2);
    defer fft_n0.deinit();
    const fft_n1 = try FFT(f32).init(log2n1, .radix2);
    defer fft_n1.deinit();

    var re: [total]f32 = undefined;
    var im: [total]f32 = undefined;
    for (0..total) |i| {
        const v: f32 = @floatFromInt(i);
        re[i] = v * 0.37 - 5.0; // asymmetric, non-trivial values
        im[i] = -v * 0.13 + 1.0;
    }
    var ref_re = re;
    var ref_im = im;

    const io = SS(f32).init(&re, &im);
    fft.zip2d(io, ic0, log2n0, log2n1, .forward);

    refFft2dViaZip(fft_n0, fft_n1, &ref_re, &ref_im, @intCast(ic0), n0, n1, .forward);

    for (0..total) |i| {
        try std.testing.expectApproxEqAbs(ref_re[i], re[i], 0.05);
        try std.testing.expectApproxEqAbs(ref_im[i], im[i], 0.05);
    }
}

test "zop2d matches zip2d (out-of-place equals in-place)" {
    const log2n0: Length = 2; // N0 = 4
    const log2n1: Length = 3; // N1 = 8
    const n0: usize = 4;
    const n1: usize = 8;
    const total = n0 * n1;
    const ia0: Stride = @intCast(n1);
    const ic0: Stride = @intCast(n1);

    const fft = try FFT(f32).init(@max(log2n0, log2n1), .radix2);
    defer fft.deinit();

    var re: [total]f32 = undefined;
    var im: [total]f32 = undefined;
    for (0..total) |i| {
        const v: f32 = @floatFromInt(i);
        re[i] = v * 0.37 - 5.0;
        im[i] = -v * 0.13 + 1.0;
    }

    var ip_re = re;
    var ip_im = im;
    const ip_io = SS(f32).init(&ip_re, &ip_im);
    fft.zip2d(ip_io, ic0, log2n0, log2n1, .forward);

    var oa_re = re;
    var oa_im = im;
    const input = SS(f32).init(&oa_re, &oa_im);
    var oc_re: [total]f32 = undefined;
    var oc_im: [total]f32 = undefined;
    const output = SS(f32).init(&oc_re, &oc_im);
    fft.zop2d(input, ia0, output, ic0, log2n0, log2n1, .forward);

    for (0..total) |i| {
        try std.testing.expectApproxEqAbs(ip_re[i], oc_re[i], 0.05);
        try std.testing.expectApproxEqAbs(ip_im[i], oc_im[i], 0.05);
    }
}

// -- 2D real: zrip2d/zript2d/zrop2d/zropt2d --
//
// The 2D real transform's packing (vDSP.h:~1370-1380) uses an "awkward
// format... due to a legacy implementation" that interleaves Re/Im pairs
// across doubled row indices for interior rows, unlike the clean 1D
// realp[k]/imagp[k] = Re/Im split. Rather than hand-derive that packing
// (risking an unverified guess, which fix/REQUEST.md forbids), these tests
// cross-check the buffered/out-of-place variants against zrip2d itself
// (whose argument order is confirmed against vDSP.h above) and verify the
// scale convention empirically via a round trip, the same way the 1D real
// family was verified above.

test "zrip2d forward+inverse round trip confirms unnormalized-inverse pattern" {
    // Same pattern as the 1D "zrip inverse is unnormalized" test: an
    // impulse's round trip through forward (scale=2 per vDSP.h) then
    // inverse (documented as 1/(N0*N1), vDSP.h:~1399) comes back scaled by
    // 2*N0*N1, confirming the inverse does NOT apply the documented
    // 1/(N0*N1) normalization - consistent with every other FFT direction
    // in this file.
    const log2n0: Length = 2; // N0 = 4
    const log2n1: Length = 3; // N1 = 8
    const n1: usize = 8;
    const half_n0: usize = 2; // N0/2
    const ic0: Stride = @intCast(n1);
    const total: usize = half_n0 * n1;

    const fft = try FFT(f32).init(@max(log2n0, log2n1), .radix2);
    defer fft.deinit();

    var re = [_]f32{0} ** total;
    var im = [_]f32{0} ** total;
    re[0] = 1.0; // impulse
    const io = SS(f32).init(&re, &im);

    fft.zrip2d(io, ic0, log2n0, log2n1, .forward);
    fft.zrip2d(io, ic0, log2n0, log2n1, .inverse);

    const expected: f32 = 2.0 * 4.0 * 8.0; // 2 * N0 * N1
    try std.testing.expectApproxEqAbs(expected, re[0], 0.5);
    for (1..total) |i| {
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), re[i], 0.5);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), im[i], 0.5);
    }
}

test "zript2d matches zrip2d (temp-buffer agrees with buffer-less)" {
    const log2n0: Length = 2; // N0 = 4
    const log2n1: Length = 3; // N1 = 8
    const n1: usize = 8;
    const half_n0: usize = 2; // N0/2
    const ic0: Stride = @intCast(n1);
    const total: usize = half_n0 * n1;

    const fft = try FFT(f32).init(@max(log2n0, log2n1), .radix2);
    defer fft.deinit();

    var seed = [_]f32{0} ** total;
    for (0..total) |i| seed[i] = @as(f32, @floatFromInt(i)) * 0.5 - 3.0;

    var a_re = seed;
    var a_im = seed;
    const a_io = SS(f32).init(&a_re, &a_im);
    fft.zrip2d(a_io, ic0, log2n0, log2n1, .forward);

    var b_re = seed;
    var b_im = seed;
    const b_io = SS(f32).init(&b_re, &b_im);
    var buf_re: [8]f32 = undefined; // max(N1, N0/2) = max(8, 2) = 8
    var buf_im: [8]f32 = undefined;
    const buffer = SS(f32).init(&buf_re, &buf_im);
    fft.zript2d(b_io, ic0, buffer, log2n0, log2n1, .forward);

    for (0..total) |i| {
        try std.testing.expectApproxEqAbs(a_re[i], b_re[i], 0.05);
        try std.testing.expectApproxEqAbs(a_im[i], b_im[i], 0.05);
    }
}

test "zrop2d matches zrip2d (out-of-place equals in-place)" {
    const log2n0: Length = 2; // N0 = 4
    const log2n1: Length = 3; // N1 = 8
    const n1: usize = 8;
    const half_n0: usize = 2; // N0/2
    const ic0: Stride = @intCast(n1);
    const ia0: Stride = @intCast(n1);
    const total: usize = half_n0 * n1;

    const fft = try FFT(f32).init(@max(log2n0, log2n1), .radix2);
    defer fft.deinit();

    var seed = [_]f32{0} ** total;
    for (0..total) |i| seed[i] = @as(f32, @floatFromInt(i)) * 0.5 - 3.0;

    var ip_re = seed;
    var ip_im = seed;
    const ip_io = SS(f32).init(&ip_re, &ip_im);
    fft.zrip2d(ip_io, ic0, log2n0, log2n1, .forward);

    var oa_re = seed;
    var oa_im = seed;
    const input = SS(f32).init(&oa_re, &oa_im);
    var oc_re: [total]f32 = undefined;
    var oc_im: [total]f32 = undefined;
    const output = SS(f32).init(&oc_re, &oc_im);
    fft.zrop2d(input, ia0, output, ic0, log2n0, log2n1, .forward);

    for (0..total) |i| {
        try std.testing.expectApproxEqAbs(ip_re[i], oc_re[i], 0.05);
        try std.testing.expectApproxEqAbs(ip_im[i], oc_im[i], 0.05);
    }
}

test "zropt2d matches zrop2d (temp-buffer agrees with buffer-less)" {
    const log2n0: Length = 2; // N0 = 4
    const log2n1: Length = 3; // N1 = 8
    const n1: usize = 8;
    const half_n0: usize = 2; // N0/2
    const ic0: Stride = @intCast(n1);
    const ia0: Stride = @intCast(n1);
    const total: usize = half_n0 * n1;

    const fft = try FFT(f32).init(@max(log2n0, log2n1), .radix2);
    defer fft.deinit();

    var seed = [_]f32{0} ** total;
    for (0..total) |i| seed[i] = @as(f32, @floatFromInt(i)) * 0.5 - 3.0;
    const input = SS(f32).init(&seed, &seed);

    var zrop_re: [total]f32 = undefined;
    var zrop_im: [total]f32 = undefined;
    const zrop_out = SS(f32).init(&zrop_re, &zrop_im);
    fft.zrop2d(input, ia0, zrop_out, ic0, log2n0, log2n1, .forward);

    var zropt_re: [total]f32 = undefined;
    var zropt_im: [total]f32 = undefined;
    const zropt_out = SS(f32).init(&zropt_re, &zropt_im);
    var buf_re: [8]f32 = undefined;
    var buf_im: [8]f32 = undefined;
    const buffer = SS(f32).init(&buf_re, &buf_im);
    fft.zropt2d(input, ia0, zropt_out, ic0, buffer, log2n0, log2n1, .forward);

    for (0..total) |i| {
        try std.testing.expectApproxEqAbs(zrop_re[i], zropt_re[i], 0.05);
        try std.testing.expectApproxEqAbs(zrop_im[i], zropt_im[i], 0.05);
    }
}

// -- Batch (m-prefixed): mzip/mzipt/mzop/mzopt --

test "mzip matches per-signal zip (M independent batched transforms)" {
    // vDSP.h maps element (m, j) to index m*IM + j*IC (IC hardcoded to 1),
    // so signal m occupies [m*IM, m*IM+N). Use a non-contiguous IM (N=4,
    // IM=7) so a stride/argument-order bug would misalign signals.
    const log2n: Length = 2; // N = 4
    const n: usize = 4;
    const m: Length = 3;
    const im: Stride = 7; // > n, leaves a gap between signals
    const total: usize = 2 * 7 + n; // (m-1)*im + n

    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    var re = [_]f32{0} ** total;
    var im_arr = [_]f32{0} ** total;
    // Fill three distinct asymmetric signals.
    const signals_re = [_][4]f32{
        .{ 1.0, -2.0, 3.0, 0.5 },
        .{ -1.5, 4.0, 0.0, 2.5 },
        .{ 2.0, 2.0, -3.5, 1.0 },
    };
    const signals_im = [_][4]f32{
        .{ 0.5, 0.0, -1.0, 2.0 },
        .{ 1.0, -2.0, 0.5, 0.0 },
        .{ -0.5, 1.0, 0.0, 3.0 },
    };
    for (0..3) |s| {
        for (0..n) |j| {
            re[s * @as(usize, @intCast(im)) + j] = signals_re[s][j];
            im_arr[s * @as(usize, @intCast(im)) + j] = signals_im[s][j];
        }
    }

    const io = SS(f32).init(&re, &im_arr);
    fft.mzip(io, im, m, .forward);

    for (0..3) |s| {
        var sig_re = signals_re[s];
        var sig_im = signals_im[s];
        const sig_io = SS(f32).init(&sig_re, &sig_im);
        fft.zip(sig_io, .forward);
        for (0..n) |j| {
            const idx = s * @as(usize, @intCast(im)) + j;
            try std.testing.expectApproxEqAbs(sig_re[j], re[idx], 0.02);
            try std.testing.expectApproxEqAbs(sig_im[j], im_arr[idx], 0.02);
        }
    }
}

test "mzipt matches mzip (temp-buffer agrees with buffer-less batched transform)" {
    const log2n: Length = 2; // N = 4
    const n: usize = 4;
    const m: Length = 2;
    const im: Stride = 5;
    const total: usize = n + 5;

    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    var seed = [_]f32{0} ** total;
    for (0..total) |i| seed[i] = @as(f32, @floatFromInt(i)) * 0.7 - 2.0;

    var a_re = seed;
    var a_im = seed;
    const a_io = SS(f32).init(&a_re, &a_im);
    fft.mzip(a_io, im, m, .forward);

    var b_re = seed;
    var b_im = seed;
    const b_io = SS(f32).init(&b_re, &b_im);
    var buf_re: [4]f32 = undefined;
    var buf_im: [4]f32 = undefined;
    const buffer = SS(f32).init(&buf_re, &buf_im);
    fft.mzipt(b_io, im, buffer, m, .forward);

    for (0..total) |i| {
        try std.testing.expectApproxEqAbs(a_re[i], b_re[i], 0.05);
        try std.testing.expectApproxEqAbs(a_im[i], b_im[i], 0.05);
    }
}

test "mzop matches mzip (out-of-place equals in-place, batched)" {
    const log2n: Length = 2; // N = 4
    const n: usize = 4;
    const m: Length = 2;
    const im: Stride = 5;
    const total: usize = n + 5;

    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    var seed = [_]f32{0} ** total;
    for (0..total) |i| seed[i] = @as(f32, @floatFromInt(i)) * 0.7 - 2.0;

    var ip_re = seed;
    var ip_im = seed;
    const ip_io = SS(f32).init(&ip_re, &ip_im);
    fft.mzip(ip_io, im, m, .forward);

    var oa_re = seed;
    var oa_im = seed;
    const input = SS(f32).init(&oa_re, &oa_im);
    var oc_re: [total]f32 = undefined;
    var oc_im: [total]f32 = undefined;
    const output = SS(f32).init(&oc_re, &oc_im);
    fft.mzop(input, im, output, im, m, .forward);

    // Only the M*N signal-occupied slots are written by mzop; the gap
    // between signals (index n..im, since im > n here) is untouched scratch
    // space in the output buffer and is not meaningful to compare.
    for (0..m) |s| {
        for (0..n) |j| {
            const idx = s * @as(usize, @intCast(im)) + j;
            try std.testing.expectApproxEqAbs(ip_re[idx], oc_re[idx], 0.05);
            try std.testing.expectApproxEqAbs(ip_im[idx], oc_im[idx], 0.05);
        }
    }
}

test "mzopt matches mzop (temp-buffer agrees with buffer-less, batched out-of-place)" {
    const log2n: Length = 2; // N = 4
    const n: usize = 4;
    const m: Length = 2;
    const im: Stride = 5;
    const total: usize = n + 5;

    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    var seed = [_]f32{0} ** total;
    for (0..total) |i| seed[i] = @as(f32, @floatFromInt(i)) * 0.7 - 2.0;
    const input = SS(f32).init(&seed, &seed);

    var mzop_re: [total]f32 = undefined;
    var mzop_im: [total]f32 = undefined;
    const mzop_out = SS(f32).init(&mzop_re, &mzop_im);
    fft.mzop(input, im, mzop_out, im, m, .forward);

    var mzopt_re: [total]f32 = undefined;
    var mzopt_im: [total]f32 = undefined;
    const mzopt_out = SS(f32).init(&mzopt_re, &mzopt_im);
    var buf_re: [4]f32 = undefined;
    var buf_im: [4]f32 = undefined;
    const buffer = SS(f32).init(&buf_re, &buf_im);
    fft.mzopt(input, im, mzopt_out, im, buffer, m, .forward);

    for (0..total) |i| {
        try std.testing.expectApproxEqAbs(mzop_re[i], mzopt_re[i], 0.05);
        try std.testing.expectApproxEqAbs(mzop_im[i], mzopt_im[i], 0.05);
    }
}

// -- Batch real (m-prefixed): mzrip/mzript/mzrop/mzropt --

test "mzrip matches per-signal zrip (M independent batched real transforms)" {
    // Same layout convention as mzip: element (m, j) maps to m*IM + j*IC
    // (IC hardcoded to 1). Each real-packed signal occupies N/2 slots.
    const log2n: Length = 3; // N = 8
    const half_n: usize = 4; // N/2
    const m: Length = 2;
    const im: Stride = 6; // > N/2, leaves a gap between signals
    const total: usize = half_n + 6;

    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    var re = [_]f32{0} ** total;
    var im_arr = [_]f32{0} ** total;
    const signals_re = [_][4]f32{
        .{ 1.0, -3.0, 4.0, 2.0 },
        .{ -2.0, 0.5, 3.0, -1.0 },
    };
    const signals_im = [_][4]f32{
        .{ 2.0, 0.5, -1.0, 7.0 },
        .{ 0.0, -3.0, 1.5, 4.0 },
    };
    for (0..2) |s| {
        for (0..half_n) |j| {
            re[s * @as(usize, @intCast(im)) + j] = signals_re[s][j];
            im_arr[s * @as(usize, @intCast(im)) + j] = signals_im[s][j];
        }
    }

    const io = SS(f32).init(&re, &im_arr);
    fft.mzrip(io, im, m, .forward);

    for (0..2) |s| {
        var sig_re = signals_re[s];
        var sig_im = signals_im[s];
        const sig_io = SS(f32).init(&sig_re, &sig_im);
        fft.zrip(sig_io, .forward);
        for (0..half_n) |j| {
            const idx = s * @as(usize, @intCast(im)) + j;
            try std.testing.expectApproxEqAbs(sig_re[j], re[idx], 0.02);
            try std.testing.expectApproxEqAbs(sig_im[j], im_arr[idx], 0.02);
        }
    }
}

test "mzript matches mzrip (temp-buffer agrees with buffer-less batched real transform)" {
    const log2n: Length = 3; // N = 8
    const half_n: usize = 4;
    const m: Length = 2;
    const im: Stride = 6;
    const total: usize = half_n + 6;

    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    var seed = [_]f32{0} ** total;
    for (0..total) |i| seed[i] = @as(f32, @floatFromInt(i)) * 0.6 - 2.5;

    var a_re = seed;
    var a_im = seed;
    const a_io = SS(f32).init(&a_re, &a_im);
    fft.mzrip(a_io, im, m, .forward);

    var b_re = seed;
    var b_im = seed;
    const b_io = SS(f32).init(&b_re, &b_im);
    var buf_re: [4]f32 = undefined; // N/2
    var buf_im: [4]f32 = undefined;
    const buffer = SS(f32).init(&buf_re, &buf_im);
    fft.mzript(b_io, im, buffer, m, .forward);

    for (0..total) |i| {
        try std.testing.expectApproxEqAbs(a_re[i], b_re[i], 0.05);
        try std.testing.expectApproxEqAbs(a_im[i], b_im[i], 0.05);
    }
}

test "mzrop matches mzrip (out-of-place equals in-place, batched real)" {
    const log2n: Length = 3; // N = 8
    const half_n: usize = 4;
    const m: Length = 2;
    const im: Stride = 6;
    const total: usize = half_n + 6;

    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    var seed = [_]f32{0} ** total;
    for (0..total) |i| seed[i] = @as(f32, @floatFromInt(i)) * 0.6 - 2.5;

    var ip_re = seed;
    var ip_im = seed;
    const ip_io = SS(f32).init(&ip_re, &ip_im);
    fft.mzrip(ip_io, im, m, .forward);

    var oa_re = seed;
    var oa_im = seed;
    const input = SS(f32).init(&oa_re, &oa_im);
    var oc_re: [total]f32 = undefined;
    var oc_im: [total]f32 = undefined;
    const output = SS(f32).init(&oc_re, &oc_im);
    fft.mzrop(input, im, output, im, m, .forward);

    // As with mzop above: only the M*(N/2) signal-occupied slots are
    // written; the gap between signals is untouched scratch space.
    for (0..m) |s| {
        for (0..half_n) |j| {
            const idx = s * @as(usize, @intCast(im)) + j;
            try std.testing.expectApproxEqAbs(ip_re[idx], oc_re[idx], 0.05);
            try std.testing.expectApproxEqAbs(ip_im[idx], oc_im[idx], 0.05);
        }
    }
}

test "mzropt matches mzrop (temp-buffer agrees with buffer-less, batched real out-of-place)" {
    const log2n: Length = 3; // N = 8
    const half_n: usize = 4;
    const m: Length = 2;
    const im: Stride = 6;
    const total: usize = half_n + 6;

    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    var seed = [_]f32{0} ** total;
    for (0..total) |i| seed[i] = @as(f32, @floatFromInt(i)) * 0.6 - 2.5;
    const input = SS(f32).init(&seed, &seed);

    var mzrop_re: [total]f32 = undefined;
    var mzrop_im: [total]f32 = undefined;
    const mzrop_out = SS(f32).init(&mzrop_re, &mzrop_im);
    fft.mzrop(input, im, mzrop_out, im, m, .forward);

    var mzropt_re: [total]f32 = undefined;
    var mzropt_im: [total]f32 = undefined;
    const mzropt_out = SS(f32).init(&mzropt_re, &mzropt_im);
    var buf_re: [4]f32 = undefined;
    var buf_im: [4]f32 = undefined;
    const buffer = SS(f32).init(&buf_re, &buf_im);
    fft.mzropt(input, im, mzropt_out, im, buffer, m, .forward);

    for (0..total) |i| {
        try std.testing.expectApproxEqAbs(mzrop_re[i], mzropt_re[i], 0.05);
        try std.testing.expectApproxEqAbs(mzrop_im[i], mzropt_im[i], 0.05);
    }
}

/// Naive O(N^2) 2D DFT over a row-major complex matrix, written straight from
/// the mathematical definition with no vDSP involvement. Used below as an
/// independent oracle: every other 2D test in this file checks one vDSP
/// routine against another vDSP routine, which cannot catch an error the
/// whole family shares.
fn refDft2d(
    in_re: []const f32,
    in_im: []const f32,
    out_re: []f32,
    out_im: []f32,
    n0: usize,
    n1: usize,
    direction: Direction,
) void {
    // vDSP's Direction: .forward => e^(-2*pi*i*...), .inverse => e^(+2*pi*i*...).
    const sign: f32 = if (direction == .forward) -1.0 else 1.0;
    for (0..n0) |k0| {
        for (0..n1) |k1| {
            var acc_re: f32 = 0;
            var acc_im: f32 = 0;
            for (0..n0) |j0| {
                for (0..n1) |j1| {
                    const phase = sign * 2.0 * std.math.pi *
                        (@as(f32, @floatFromInt(j0 * k0)) / @as(f32, @floatFromInt(n0)) +
                            @as(f32, @floatFromInt(j1 * k1)) / @as(f32, @floatFromInt(n1)));
                    const cr = @cos(phase);
                    const ci = @sin(phase);
                    const vr = in_re[j0 * n1 + j1];
                    const vi = in_im[j0 * n1 + j1];
                    acc_re += vr * cr - vi * ci;
                    acc_im += vr * ci + vi * cr;
                }
            }
            out_re[k0 * n1 + k1] = acc_re;
            out_im[k0 * n1 + k1] = acc_im;
        }
    }
}

test "zop2d matches an independent naive 2D DFT (not just another vDSP routine)" {
    // The existing 2D coverage cross-checks vDSP against vDSP (zop2d vs
    // zip2d, zipt2d vs zip2d, and a separable zip()-based reference). All of
    // those share vDSP's own conventions, so a systematic error in the family
    // would pass every one. This compares against a closed-form DFT computed
    // from the definition, in plain Zig, at a deliberately non-square size.
    const log2n0: Length = 2; // N0 = 4 (the strided dimension)
    const log2n1: Length = 3; // N1 = 8 (the contiguous dimension)
    const n0: usize = 4;
    const n1: usize = 8;
    const total = n0 * n1;
    const ic0: Stride = @intCast(n1);

    var in_re: [total]f32 = undefined;
    var in_im: [total]f32 = undefined;
    // Asymmetric, non-separable input so a transposed or single-axis bug
    // cannot produce a coincidentally-correct spectrum.
    for (0..n0) |y| {
        for (0..n1) |x| {
            const fy: f32 = @floatFromInt(y);
            const fx: f32 = @floatFromInt(x);
            in_re[y * n1 + x] = fx * 1.5 - fy * 0.25 + fx * fy * 0.125;
            in_im[y * n1 + x] = fy * 0.75 - fx * 0.5;
        }
    }

    var got_re = in_re;
    var got_im = in_im;
    var out_re: [total]f32 = undefined;
    var out_im: [total]f32 = undefined;

    const fft = try FFT(f32).init(@max(log2n0, log2n1), .radix2);
    defer fft.deinit();
    const input = SS(f32).init(&got_re, &got_im);
    const output = SS(f32).init(&out_re, &out_im);
    fft.zop2d(input, ic0, output, ic0, log2n0, log2n1, .forward);

    var want_re: [total]f32 = undefined;
    var want_im: [total]f32 = undefined;
    refDft2d(&in_re, &in_im, &want_re, &want_im, n0, n1, .forward);

    for (0..total) |i| {
        try std.testing.expectApproxEqAbs(want_re[i], out_re[i], 0.02);
        try std.testing.expectApproxEqAbs(want_im[i], out_im[i], 0.02);
    }
}

test "zrip2d DC/Nyquist packing: which output slot each basis image lands in" {
    // vDSP.h's own pseudocode for the 2D real transform's packing is
    // internally inconsistent (it gives identical formulas for two different
    // array positions) and the header itself calls the format "awkward ...
    // due to a legacy implementation". Rather than hand-derive a closed form
    // from documentation that contradicts itself, this pins the layout the
    // way the rest of this audit resolved undocumented behavior: drive the
    // real function with basis images whose spectra have exactly one nonzero
    // coefficient, and record which slot receives it.
    //
    // Observed on this platform (N0 = 4 rows, N1 = 8 cols, forward):
    //
    //   input image                    -> slot holding the energy
    //   -------------------------------   -----------------------
    //   DC (all ones)                     realp[row 0][col 0]
    //   Nyquist along x (cols)            realp[row 0][col 1]
    //   Nyquist along y (rows)            imagp[row 0][col 0]
    //   Nyquist along both                imagp[row 0][col 1]
    //   cos(2*pi*x/N1)  (kx = 1)          realp[row 0][col 2]
    //   cos(2*pi*y/N0)  (ky = 1)          realp[row 1][col 0]
    //
    // So the y (row) dimension folds DC and Nyquist into row 0's real and
    // imaginary parts respectively - exactly the 1D zrip convention - while
    // the x (column) dimension puts DC at col 0 and Nyquist at col 1, with
    // the remaining bins starting at col 2. That col-0/col-1 adjacency is
    // the "awkward" part, and it is NOT what a naive reading of the header
    // would predict (col N1/2 for Nyquist).
    //
    // These are characterization expectations: if a future macOS changes the
    // layout, this test failing is the intended signal, not a regression in
    // this binding.
    const log2n0: Length = 2;
    const log2n1: Length = 3;
    const n0: usize = 4;
    const n1: usize = 8;
    const half_n0 = n0 / 2;
    const total = half_n0 * n1;
    const ic0: Stride = @intCast(n1);

    const fft = try FFT(f32).init(@max(log2n0, log2n1), .radix2);
    defer fft.deinit();

    const Case = struct {
        name: []const u8,
        // Which of realp/imagp, which row, which col, and the expected value.
        in_imag: bool,
        row: usize,
        col: usize,
        value: f32,
        gen: *const fn (y: usize, x: usize) f32,
    };
    const gens = struct {
        fn dc(_: usize, _: usize) f32 {
            return 1.0;
        }
        fn nyqX(_: usize, x: usize) f32 {
            return if (x % 2 == 0) 1.0 else -1.0;
        }
        fn nyqY(y: usize, _: usize) f32 {
            return if (y % 2 == 0) 1.0 else -1.0;
        }
        fn nyqBoth(y: usize, x: usize) f32 {
            return if ((x + y) % 2 == 0) 1.0 else -1.0;
        }
        fn cosX(_: usize, x: usize) f32 {
            return @cos(2.0 * std.math.pi * @as(f32, @floatFromInt(x)) / 8.0);
        }
        fn cosY(y: usize, _: usize) f32 {
            return @cos(2.0 * std.math.pi * @as(f32, @floatFromInt(y)) / 4.0);
        }
    };
    // Forward scale is 2 (vDSP.h's documented real-to-complex convention), so
    // a self-conjugate bin (DC, Nyquist) gets 2*N0*N1 = 64 and an ordinary
    // cosine splits between +k and -k for 2*(N0*N1/2) = 32.
    const cases = [_]Case{
        .{ .name = "DC", .in_imag = false, .row = 0, .col = 0, .value = 64.0, .gen = gens.dc },
        .{ .name = "Nyquist x", .in_imag = false, .row = 0, .col = 1, .value = 64.0, .gen = gens.nyqX },
        .{ .name = "Nyquist y", .in_imag = true, .row = 0, .col = 0, .value = 64.0, .gen = gens.nyqY },
        .{ .name = "Nyquist xy", .in_imag = true, .row = 0, .col = 1, .value = 64.0, .gen = gens.nyqBoth },
        .{ .name = "cos kx=1", .in_imag = false, .row = 0, .col = 2, .value = 32.0, .gen = gens.cosX },
        .{ .name = "cos ky=1", .in_imag = false, .row = 1, .col = 0, .value = 32.0, .gen = gens.cosY },
    };

    for (cases) |case| {
        var re = [_]f32{0} ** total;
        var im = [_]f32{0} ** total;
        // Real 2D input packing (same as 1D zrip): even rows -> realp,
        // odd rows -> imagp.
        for (0..half_n0) |r| {
            for (0..n1) |cc| {
                re[r * n1 + cc] = case.gen(2 * r, cc);
                im[r * n1 + cc] = case.gen(2 * r + 1, cc);
            }
        }
        const io = SS(f32).init(&re, &im);
        fft.zrip2d(io, ic0, log2n0, log2n1, .forward);

        const target = case.row * n1 + case.col;
        const buf: []const f32 = if (case.in_imag) &im else &re;
        std.testing.expectApproxEqAbs(case.value, buf[target], 0.05) catch |e| {
            std.debug.print("case '{s}': wrong value in the expected slot\n", .{case.name});
            return e;
        };
        // Every other slot must be (numerically) zero - this is what makes
        // the test a packing check and not just a magnitude check.
        for (0..total) |i| {
            const in_re_slot = !case.in_imag and i == target;
            const in_im_slot = case.in_imag and i == target;
            if (!in_re_slot) try std.testing.expectApproxEqAbs(@as(f32, 0.0), re[i], 0.05);
            if (!in_im_slot) try std.testing.expectApproxEqAbs(@as(f32, 0.0), im[i], 0.05);
        }
    }
}

test "roundTripScale / realRoundTripScale match what the transforms actually do" {
    // Guards the scaling helpers against the doc-comment drift that made the
    // original 1/N claim survive in this file for so long: if a future macOS
    // ever starts normalizing, these fail rather than silently misinforming.
    const log2n: Length = 4; // N = 16
    const n: usize = 16;
    const fft = try FFT(f32).init(log2n, .radix2);
    defer fft.deinit();

    try std.testing.expectEqual(@as(f32, 16.0), fft.roundTripScale());
    try std.testing.expectEqual(@as(f32, 2.0), fft.realForwardScale());
    try std.testing.expectEqual(@as(f32, 32.0), fft.realRoundTripScale());

    // Complex round trip: an impulse comes back scaled by roundTripScale().
    {
        var re = [_]f32{0} ** n;
        var im = [_]f32{0} ** n;
        re[3] = 1.0;
        const io = SS(f32).init(&re, &im);
        fft.zip(io, .forward);
        fft.zip(io, .inverse);
        try std.testing.expectApproxEqAbs(fft.roundTripScale(), re[3], 1e-3);
        // Dividing by the helper's factor is what recovers the original.
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), re[3] / fft.roundTripScale(), 1e-4);
    }

    // Real round trip: scaled by realRoundTripScale() = 2*N, not N.
    {
        var re = [_]f32{0} ** (n / 2);
        var im = [_]f32{0} ** (n / 2);
        re[1] = 1.0;
        const io = SS(f32).init(&re, &im);
        fft.zrip(io, .forward);
        fft.zrip(io, .inverse);
        try std.testing.expectApproxEqAbs(fft.realRoundTripScale(), re[1], 1e-2);
    }
}
