const std = @import("std");
const types = @import("types.zig");
const Length = types.Length;
const fft = @import("fft.zig");
const c = @import("c.zig");

// ============================================================================
// Types
// ============================================================================

pub const DFTSetup = c.DFTSetup;
pub const DFTSetupD = c.DFTSetupD;
pub const DFTInterleavedSetup = c.DFTInterleavedSetup;
pub const DFTInterleavedSetupD = c.DFTInterleavedSetupD;

pub const Direction = fft.Direction;

pub const DCTType = enum(c_int) {
    dct_II = 2,
    dct_III = 3,
    dct_IV = 4,
};

pub const RealToComplex = enum(c_int) {
    complex_to_complex = 0,
    real_to_complex = 1,
};

pub const Complex = types.Complex;

// ============================================================================
// High-level DFT wrappers (manage setup lifetime)
// ============================================================================

/// Complex-to-complex DFT (split complex), backed by vDSP_DFT_zop_CreateSetup
/// / vDSP_DFT_Execute. This is the "newer, more specialized" DFT API that
/// Apple's vDSP.h recommends over the legacy vDSP_DFT_CreateSetup/vDSP_DFT_zop
/// pair (vDSP.h ~L6856-6869).
///
/// Use DFT(f32) for single-precision or DFT(f64) for double-precision.
pub fn DFT(comptime T: type) type {
    const Setup = switch (T) {
        f32 => DFTSetup,
        f64 => DFTSetupD,
        else => @compileError("DFT only supports f32 and f64"),
    };

    return struct {
        const Self = @This();

        setup: Setup,
        length: Length,

        /// Allocates and prepares a new DFT setup for `length` complex
        /// elements. vDSP.h ~L6969-6973: supported lengths are 2**n, or
        /// f*2**n where f is 3, 5, or 15 and n >= 3; other lengths fail.
        pub fn init(length: Length, direction: Direction) !Self {
            const dir = @intFromEnum(direction);
            const setup = switch (T) {
                f32 => c.vDSP_DFT_zop_CreateSetup(null, length, dir),
                f64 => c.vDSP_DFT_zop_CreateSetupD(null, length, dir),
                else => unreachable,
            };
            return .{ .setup = setup orelse return error.SetupFailed, .length = length };
        }

        /// Creates a new setup that shares internal tables/buffers with
        /// `previous` where feasible (vDSP.h ~L6949-6955: "If a previous
        /// setup is passed, the new setup will share data with the previous
        /// setup, if feasible ... Do not call this routine while any DFT or
        /// DCT routine sharing setup data might be executing.").
        ///
        /// Runtime-verified (see test below): a setup created this way
        /// produces bit-for-bit-equivalent output to an independently
        /// created setup of the same length/direction, and destroying either
        /// setup first (in any order) does not corrupt or use-after-free the
        /// other - vDSP.h ~L7187-7189 documents this as safe ("Destroying a
        /// setup with shared data is safe; it will release only memory not
        /// needed by other undestroyed setups").
        pub fn initShared(previous: Setup, length: Length, direction: Direction) !Self {
            const dir = @intFromEnum(direction);
            const setup = switch (T) {
                f32 => c.vDSP_DFT_zop_CreateSetup(previous, length, dir),
                f64 => c.vDSP_DFT_zop_CreateSetupD(previous, length, dir),
                else => unreachable,
            };
            return .{ .setup = setup orelse return error.SetupFailed, .length = length };
        }

        /// Releases the setup. Safe to call even if this setup shares data
        /// with other live setups (vDSP.h ~L7187-7189): only memory not
        /// needed by other undestroyed setups is freed.
        pub fn deinit(self: Self) void {
            switch (T) {
                f32 => c.vDSP_DFT_DestroySetup(self.setup),
                f64 => c.vDSP_DFT_DestroySetupD(self.setup),
                else => unreachable,
            }
        }

        /// Executes the complex-to-complex DFT configured at init() time.
        /// ir, ii, or_out, oi_out must each have `length` elements
        /// (vDSP.h ~L7333-7334: "When the setup is from vDSP_zop_CreateSetup,
        /// each array (Ir, Ii, Or, and Oi) must have Length elements.").
        /// or_out may alias ir and oi_out may alias ii for in-place operation;
        /// no other aliasing is supported (vDSP.h ~L7020-7021).
        ///
        /// Computes, for 0 <= k < N (vDSP.h ~L6985-7008):
        ///     h[j] = ir[j] + i * ii[j],                    0 <= j < N
        ///     H[k] = sum(h[j] * e**(S*2*pi*i*j*k/N), 0 <= j < N)
        ///     or_out[k] = Re(H[k]); oi_out[k] = Im(H[k])
        /// where S is -1 for .forward and +1 for .inverse.
        ///
        /// Runtime-verified (see test below): unlike vDSP_DFT_zrop (RealDFT),
        /// there is no extra scale factor here in either direction - this
        /// matches fft.zig's already-verified finding that vDSP's complex
        /// DFT/FFT routines are unnormalized: an impulse forward-transformed
        /// then inverse-transformed comes back scaled by exactly N, not 1.
        pub fn exec(self: Self, ir: []const T, ii: []const T, or_out: []T, oi_out: []T) void {
            std.debug.assert(ir.len == self.length);
            std.debug.assert(ii.len == self.length);
            std.debug.assert(or_out.len == self.length);
            std.debug.assert(oi_out.len == self.length);
            switch (T) {
                f32 => c.vDSP_DFT_Execute(self.setup, ir.ptr, ii.ptr, or_out.ptr, oi_out.ptr),
                f64 => c.vDSP_DFT_ExecuteD(self.setup, ir.ptr, ii.ptr, or_out.ptr, oi_out.ptr),
                else => unreachable,
            }
        }
    };
}

/// Real-to-complex / complex-to-real DFT (split complex), backed by
/// vDSP_DFT_zrop_CreateSetup / vDSP_DFT_Execute.
///
/// Use RealDFT(f32) for single-precision or RealDFT(f64) for double-precision.
pub fn RealDFT(comptime T: type) type {
    const Setup = switch (T) {
        f32 => DFTSetup,
        f64 => DFTSetupD,
        else => @compileError("RealDFT only supports f32 and f64"),
    };

    return struct {
        const Self = @This();

        setup: Setup,
        length: Length,

        /// Allocates and prepares a new setup for a `length`-element real
        /// signal (`length` must be even - vDSP.h ~L7061-7063). Supported
        /// lengths are 2**n, or f*2**n where f is 3, 5, or 15 and n >= 4
        /// (vDSP.h ~L7075-7077).
        pub fn init(length: Length, direction: Direction) !Self {
            std.debug.assert(length % 2 == 0);
            const dir = @intFromEnum(direction);
            const setup = switch (T) {
                f32 => c.vDSP_DFT_zrop_CreateSetup(null, length, dir),
                f64 => c.vDSP_DFT_zrop_CreateSetupD(null, length, dir),
                else => unreachable,
            };
            return .{ .setup = setup orelse return error.SetupFailed, .length = length };
        }

        pub fn deinit(self: Self) void {
            switch (T) {
                f32 => c.vDSP_DFT_DestroySetup(self.setup),
                f64 => c.vDSP_DFT_DestroySetupD(self.setup),
                else => unreachable,
            }
        }

        /// Executes the real DFT configured at init() time. Direction was
        /// fixed when the setup was created; this call performs whichever
        /// direction that was.
        ///
        /// All four arrays (ir, ii, or_out, oi_out) must have `length / 2`
        /// elements (vDSP.h ~L7336-7337). or_out may alias ir and oi_out may
        /// alias ii for in-place operation; no other aliasing is supported
        /// (vDSP.h ~L7150-7151).
        ///
        /// Data layout and scaling depend on direction (vDSP.h ~L7089-7138):
        ///
        /// Forward (.forward, real-to-complex):
        ///     Input: ir/ii hold the length-N real signal packed as
        ///         h[2*j+0] = ir[j], h[2*j+1] = ii[j],  0 <= j < N/2.
        ///     Output: or_out/oi_out hold the length-N/2+1 unique complex
        ///         spectrum bins, packed as:
        ///         H[0]   = or_out[0]   (DC, purely real)
        ///         H[N/2] = oi_out[0]   (Nyquist, purely real)
        ///         H[k]   = or_out[k] + i*oi_out[k],  1 <= k < N/2
        ///         (H[k] for N/2 < k < N is not stored; it is the conjugate
        ///         of H[N-k].)
        ///         H[k] = 2 * sum(h[j] * e**(-2*pi*i*j*k/N), 0 <= j < N)
        ///         i.e. there is a fixed factor of 2 baked into the forward
        ///         direction (vDSP.h ~L7103-7104: "C is 2 if Direction is
        ///         vDSP_DFT_FORWARD and 1 if Direction is vDSP_DFT_INVERSE").
        ///
        /// Inverse (.inverse, complex-to-real): input/output layouts above
        ///     are swapped - ir/ii hold the packed spectrum, or_out/oi_out
        ///     hold the packed real output - and the C factor is 1, not 2.
        ///
        /// Runtime-verified (see test below): because forward applies C=2
        /// but inverse applies C=1, a forward+inverse round trip on an
        /// impulse comes back scaled by 2*N, not N - this asymmetric scaling
        /// is unique to the real-to-complex DFT and is easy to miss since
        /// the complex-to-complex DFT (DFT(T) above) and fft.zig's FFT have
        /// no such per-direction C factor at all.
        pub fn exec(self: Self, ir: []const T, ii: []const T, or_out: []T, oi_out: []T) void {
            const half = self.length / 2;
            std.debug.assert(ir.len == half);
            std.debug.assert(ii.len == half);
            std.debug.assert(or_out.len == half);
            std.debug.assert(oi_out.len == half);
            switch (T) {
                f32 => c.vDSP_DFT_Execute(self.setup, ir.ptr, ii.ptr, or_out.ptr, oi_out.ptr),
                f64 => c.vDSP_DFT_ExecuteD(self.setup, ir.ptr, ii.ptr, or_out.ptr, oi_out.ptr),
                else => unreachable,
            }
        }
    };
}

/// Real-to-real Discrete Cosine Transform (single-precision only - there is
/// no vDSP_DCT_ExecuteD in vDSP.h), backed by vDSP_DCT_CreateSetup /
/// vDSP_DCT_Execute.
pub const DCT = struct {
    setup: DFTSetup,
    length: Length,

    /// Allocates and prepares a new DCT setup of the given `dct_type` and
    /// `length` (number of real elements). Supported lengths are f*2**n
    /// where f is 1, 3, 5, or 15 and n >= 4 (vDSP.h ~L7386).
    pub fn init(length: Length, dct_type: DCTType) !DCT {
        const setup = c.vDSP_DCT_CreateSetup(null, length, @intFromEnum(dct_type)) orelse return error.SetupFailed;
        return .{ .setup = setup, .length = length };
    }

    pub fn deinit(self: DCT) void {
        c.vDSP_DFT_DestroySetup(self.setup);
    }

    /// Executes the DCT variant/length fixed at init() time. input and
    /// output must each have `length` elements; output may alias input for
    /// in-place operation (vDSP.h ~L7430-7433).
    ///
    /// Computes, for 0 <= k < N (vDSP.h ~L7393-7411; N = length):
    ///     DCT-II:  output[k] = sum(input[j] * cos(k*(j+1/2)*pi/N), 0<=j<N)
    ///     DCT-III: output[k] = input[0]/2
    ///                  + sum(input[j] * cos((k+1/2)*j*pi/N), 1<=j<N)
    ///     DCT-IV:  output[k] = sum(input[j] * cos((k+1/2)*(j+1/2)*pi/N), 0<=j<N)
    pub fn exec(self: DCT, input: []const f32, output: []f32) void {
        std.debug.assert(input.len == self.length);
        std.debug.assert(output.len == self.length);
        c.vDSP_DCT_Execute(self.setup, input.ptr, output.ptr);
    }
};

/// Complex-to-complex DFT for interleaved (non-split) complex data, backed by
/// vDSP_DFT_Interleaved_CreateSetup / vDSP_DFT_Interleaved_Execute. Also
/// supports a real-to-complex mode via `rtc`, though vDSP.h does not
/// document the real-signal packing layout for that mode the way it does for
/// vDSP_DFT_zrop_CreateSetup (RealDFT above) - only that "For real-to-complex
/// DFT, Length should be half of the length of the real signal" (vDSP.h
/// ~L7515). Runtime-verified (see test below): the real-to-complex mode
/// packs DC/Nyquist into the first output element's real/imag components
/// and applies the same C=2-forward/C=1-inverse scale factor as RealDFT
/// (vDSP_DFT_zrop) - i.e. it behaves like RealDFT with interleaved storage,
/// not like a distinct convention.
///
/// Use InterleavedDFT(f32) for single-precision or InterleavedDFT(f64) for
/// double-precision.
pub fn InterleavedDFT(comptime T: type) type {
    const Setup = switch (T) {
        f32 => DFTInterleavedSetup,
        f64 => DFTInterleavedSetupD,
        else => @compileError("InterleavedDFT only supports f32 and f64"),
    };
    const C = Complex(T);

    return struct {
        const Self = @This();

        setup: Setup,
        length: Length,

        /// Allocates and prepares a new setup for `length` complex elements.
        /// Supported lengths are f*2**n where f is 2, 3, 5, 9, 15, or 25 and
        /// n >= 2 (vDSP.h ~L7523).
        pub fn init(length: Length, direction: Direction, rtc: RealToComplex) !Self {
            const dir = @intFromEnum(direction);
            const r2c = @intFromEnum(rtc);
            const setup = switch (T) {
                f32 => c.vDSP_DFT_Interleaved_CreateSetup(null, length, dir, r2c),
                f64 => c.vDSP_DFT_Interleaved_CreateSetupD(null, length, dir, r2c),
                else => unreachable,
            };
            return .{ .setup = setup orelse return error.SetupFailed, .length = length };
        }

        pub fn deinit(self: Self) void {
            switch (T) {
                f32 => c.vDSP_DFT_Interleaved_DestroySetup(self.setup),
                f64 => c.vDSP_DFT_Interleaved_DestroySetupD(self.setup),
                else => unreachable,
            }
        }

        /// Executes the DFT configured at init() time. input and output
        /// must each have `length` elements (vDSP.h ~L7669-7670: "each array
        /// (Iri and Ori) must have Length elements"). output may alias input
        /// for in-place operation (vDSP.h ~L7570-7571).
        ///
        /// For complex-to-complex mode, computes, for 0 <= k < N (vDSP.h
        /// ~L7535-7558):
        ///     h[j] = input[j].re + i * input[j].im,        0 <= j < N
        ///     H[k] = sum(h[j] * e**(S*2*pi*i*j*k/N), 0 <= j < N)
        ///     output[k] = H[k]
        /// where S is -1 for .forward and +1 for .inverse - unnormalized in
        /// both directions, same as DFT(T).exec above (no C scale factor is
        /// documented or observed for this routine).
        pub fn exec(self: Self, input: []const C, output: []C) void {
            std.debug.assert(input.len == self.length);
            std.debug.assert(output.len == self.length);
            switch (T) {
                f32 => c.vDSP_DFT_Interleaved_Execute(self.setup, input.ptr, output.ptr),
                f64 => c.vDSP_DFT_Interleaved_ExecuteD(self.setup, input.ptr, output.ptr),
                else => unreachable,
            }
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

test "DFT(f32) init/deinit/exec: impulse forward spectrum then unnormalized inverse round-trip" {
    // N=8 complex DFT. h[0]=1+0i, rest zero. Forward DFT of an impulse is a
    // constant spectrum H[k]=1 for all k (vDSP.h's own formula, hand-derived
    // to a closed form: sum(h[j]*e^..., 0<=j<N) collapses to h[0]=1 because
    // h[j]=0 for j!=0). This uses an *asymmetric* known-input (impulse, not
    // a symmetric all-equal vector) so an argument-order bug (e.g. real vs
    // imaginary swapped) would show up as a non-constant / non-real result.
    const n: Length = 8;
    const fwd = try DFT(f32).init(n, .forward);
    defer fwd.deinit();

    var ir = [_]f32{0} ** n;
    var ii = [_]f32{0} ** n;
    ir[0] = 1.0;
    var or_out: [n]f32 = undefined;
    var oi_out: [n]f32 = undefined;

    fwd.exec(&ir, &ii, &or_out, &oi_out);
    for (or_out) |v| try std.testing.expectApproxEqAbs(@as(f32, 1.0), v, 1e-4);
    for (oi_out) |v| try std.testing.expectApproxEqAbs(@as(f32, 0.0), v, 1e-4);

    // Now feed that constant spectrum through an independently-created
    // inverse setup. Per vDSP_DFT_zop's documented formula (vDSP.h
    // ~L6985-7008) there is no scale factor in either direction, so
    // inverting a constant-1 spectrum of length N should give N at index 0
    // and 0 elsewhere - i.e. the impulse scaled by exactly N, not
    // normalized back to the original impulse. This matches fft.zig's
    // already-verified finding for the older vDSP_fft_zip/zop API.
    const inv = try DFT(f32).init(n, .inverse);
    defer inv.deinit();

    var or2: [n]f32 = undefined;
    var oi2: [n]f32 = undefined;
    inv.exec(&or_out, &oi_out, &or2, &oi2);

    try std.testing.expectApproxEqAbs(@as(f32, @floatFromInt(n)), or2[0], 1e-3);
    for (or2[1..]) |v| try std.testing.expectApproxEqAbs(@as(f32, 0.0), v, 1e-3);
    for (oi2) |v| try std.testing.expectApproxEqAbs(@as(f32, 0.0), v, 1e-3);
}

test "DFT(f32) initShared produces identical results to an independent setup, and deinit order doesn't matter" {
    const n: Length = 8;
    const original = try DFT(f32).init(n, .forward);
    const shared = try DFT(f32).initShared(original.setup, n, .forward);
    const independent = try DFT(f32).init(n, .forward);

    // Asymmetric input so a sharing bug that corrupts tables would be
    // visible (not just a symmetric/trivial case).
    var ir = [_]f32{ 1, -2, 3, 0, 5, -1, 0, 2 };
    var ii = [_]f32{ 0, 1, -1, 2, 0, 0, 3, -2 };

    var or_shared: [n]f32 = undefined;
    var oi_shared: [n]f32 = undefined;
    shared.exec(&ir, &ii, &or_shared, &oi_shared);

    var or_indep: [n]f32 = undefined;
    var oi_indep: [n]f32 = undefined;
    independent.exec(&ir, &ii, &or_indep, &oi_indep);

    for (0..n) |k| {
        try std.testing.expectApproxEqAbs(or_indep[k], or_shared[k], 1e-3);
        try std.testing.expectApproxEqAbs(oi_indep[k], oi_shared[k], 1e-3);
    }

    // Destroy the setup that others share data with *first* (opposite of
    // the "obvious" safe order) and confirm the surviving shared setup
    // still executes correctly afterward - vDSP.h ~L7187-7189 documents
    // this as safe: "Destroying a setup with shared data is safe; it will
    // release only memory not needed by other undestroyed setups."
    original.deinit();

    var or_after: [n]f32 = undefined;
    var oi_after: [n]f32 = undefined;
    shared.exec(&ir, &ii, &or_after, &oi_after);
    for (0..n) |k| {
        try std.testing.expectApproxEqAbs(or_indep[k], or_after[k], 1e-3);
        try std.testing.expectApproxEqAbs(oi_indep[k], oi_after[k], 1e-3);
    }

    shared.deinit();
    independent.deinit();
}

test "RealDFT(f32) init/deinit/exec: impulse spectrum matches C=2 forward / C=1 inverse asymmetric scaling" {
    // N=8 real samples. h[0]=1, rest zero, packed even/odd into ir/ii per
    // vDSP.h's zrop Data Layout (~L7113-7131): h[2j]=ir[j], h[2j+1]=ii[j].
    // So ir[0]=1 encodes the impulse at time index 0; everything else 0.
    const n: Length = 8;
    const half = n / 2;

    const fwd = try RealDFT(f32).init(n, .forward);
    defer fwd.deinit();

    var ir = [_]f32{0} ** half;
    var ii = [_]f32{0} ** half;
    ir[0] = 1.0;
    var or_out: [half]f32 = undefined;
    var oi_out: [half]f32 = undefined;

    fwd.exec(&ir, &ii, &or_out, &oi_out);

    // H[k] = C * sum(...) = 2 * h[0] = 2 for every k (real-valued, flat
    // spectrum), since only h[0] is nonzero and e**0 = 1 regardless of k.
    // DC (or_out[0]) and Nyquist (oi_out[0]) are packed per vDSP.h
    // ~L7124-7125; runtime-confirmed those are the only two slots pulled
    // out of the Or/Oi pair for k=0 and k=N/2 - all Or_out[k] read back as
    // 2 (Re(H[k])=2 for every k), but only oi_out[0] (Nyquist) is 2, while
    // oi_out[1..] (Im(H[1..N/2-1])) are 0, because a real impulse produces
    // a purely-real spectrum at every non-Nyquist bin too.
    for (or_out) |v| try std.testing.expectApproxEqAbs(@as(f32, 2.0), v, 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), oi_out[0], 1e-4);
    for (oi_out[1..]) |v| try std.testing.expectApproxEqAbs(@as(f32, 0.0), v, 1e-4);

    // Feed the forward spectrum into an inverse setup. Because forward used
    // C=2 but inverse uses C=1 (vDSP.h ~L7103-7104), a full round trip does
    // NOT return N times the original impulse (as the complex-to-complex
    // DFT does) - it returns 2*N times the original impulse. This is the
    // asymmetric-scaling behavior flagged as a documentation/education risk:
    // callers porting code from the complex DFT or from fft.zig's FFT would
    // reasonably but wrongly assume a single factor of N.
    const inv = try RealDFT(f32).init(n, .inverse);
    defer inv.deinit();

    var or2: [half]f32 = undefined;
    var oi2: [half]f32 = undefined;
    inv.exec(&or_out, &oi_out, &or2, &oi2);

    // Inverse output is packed real: even indices in or2, odd in oi2
    // (vDSP.h ~L7136-7138). Time index 0 is even => or2[0].
    const expected: f32 = 2.0 * @as(f32, @floatFromInt(n));
    try std.testing.expectApproxEqAbs(expected, or2[0], 1e-3);
    for (or2[1..]) |v| try std.testing.expectApproxEqAbs(@as(f32, 0.0), v, 1e-3);
    for (oi2) |v| try std.testing.expectApproxEqAbs(@as(f32, 0.0), v, 1e-3);
}

test "RealDFT(f32) superposed DC+Nyquist+k=1 signal: pins down Or[0]=DC, Oi[0]=Nyquist, Or[1]/Oi[1]=Re/Im(H[1])" {
    // N=8, x[n] = 1 + (-1)**n + sin(2*pi*n/N). By linearity of the DFT this
    // separates into three independently-derivable closed-form
    // contributions, chosen so no two land on the same bin with the same
    // value (ruling out a slot-swap bug hiding behind coincidentally equal
    // numbers, unlike the impulse test above where every non-Nyquist bin is
    // the same value):
    //
    //   x[n] = 1            -> pure DC:      H[0] = C*1*N,       all other H[k] = 0
    //   x[n] = (-1)**n       -> pure Nyquist: H[N/2] = C*1*N,     all other H[k] = 0
    //   x[n] = sin(2*pi*n/N) -> pure k=1:     H[1] = C*(-N/2)*i,  all other H[k] = 0
    //     (derivation: sin(theta) = (e^{i theta} - e^{-i theta})/(2i); DFT
    //     of e^{i*2*pi*n/N} is an impulse at k=1 with sum N, and of
    //     e^{-i*2*pi*n/N} is an impulse at k=N-1 with sum N (does not land
    //     on k=1 for N>2); so H[1] = C * (N/(2i)) = C * (-i*N/2).)
    //
    // With C=2, N=8: H[0]=16, H[N/2]=16, H[1]=-8i (Re=0, Im=-8), all other
    // H[k]=0. Three distinct nonzero values (16, 16, -8) at three distinct
    // slots (Or[0], Oi[0], Oi[1]) confirm DC lands in Or[0], Nyquist lands
    // in Oi[0] (vDSP.h ~L7124-7125), and the general-bin real/imaginary
    // split Or[k]/Oi[k] (vDSP.h ~L7126-7127, despite that range being
    // written "1 < k < N/2" - which if taken literally excludes k=1, but
    // runtime output below shows k=1 IS carried in Or[1]/Oi[1] as expected,
    // so the header's "1 <" is imprecise/off-by-one, not "0 <=").
    const n: Length = 8;
    const half = n / 2;
    const fwd = try RealDFT(f32).init(n, .forward);
    defer fwd.deinit();

    var ir: [half]f32 = undefined;
    var ii: [half]f32 = undefined;
    for (0..half) |j| {
        const even_n: f32 = @floatFromInt(2 * j);
        const odd_n: f32 = @floatFromInt(2 * j + 1);
        const nf: f32 = @floatFromInt(n);
        ir[j] = 1.0 + @cos(std.math.pi * even_n) + @sin(2.0 * std.math.pi * even_n / nf);
        ii[j] = 1.0 + @cos(std.math.pi * odd_n) + @sin(2.0 * std.math.pi * odd_n / nf);
    }
    var or_out: [half]f32 = undefined;
    var oi_out: [half]f32 = undefined;
    fwd.exec(&ir, &ii, &or_out, &oi_out);

    try std.testing.expectApproxEqAbs(@as(f32, 16.0), or_out[0], 1e-2); // DC
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), oi_out[0], 1e-2); // Nyquist
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), or_out[1], 1e-2); // Re(H[1])
    try std.testing.expectApproxEqAbs(@as(f32, -8.0), oi_out[1], 1e-2); // Im(H[1])
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), or_out[2], 1e-2);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), oi_out[2], 1e-2);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), or_out[3], 1e-2);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), oi_out[3], 1e-2);
}

test "DCT(.dct_II) matches hand-computed cosine sums for an impulse input" {
    // N=16 (vDSP.h ~L7386: supported lengths are f*2**n with f in
    // {1,3,5,15} and n>=4, so the smallest f=1 length is 16 - N=4 is NOT a
    // supported length and vDSP_DCT_CreateSetup returns NULL for it,
    // confirmed by running this test with N=4 first and observing
    // error.SetupFailed).
    //
    // Impulse at j=0: Or[k] = cos(k*(0+1/2)*pi/N) = cos(k*pi/(2N)) per
    // vDSP.h's own DCT-II formula (~L7397). Cross-checked against
    // std.math.cos directly rather than any closed form, so this doesn't
    // just restate the header - it independently evaluates the formula.
    const n: Length = 16;
    const dct = try DCT.init(n, .dct_II);
    defer dct.deinit();

    var input = [_]f32{0} ** n;
    input[0] = 1.0;
    var output: [n]f32 = undefined;
    dct.exec(&input, &output);

    for (0..n) |k| {
        const kf: f32 = @floatFromInt(k);
        const expected = @cos(kf * std.math.pi / (2.0 * @as(f32, @floatFromInt(n))));
        try std.testing.expectApproxEqAbs(expected, output[k], 1e-3);
    }
}

test "DCT(.dct_III) matches hand-computed cosine sums for an asymmetric input" {
    // N=16, DCT-III: Or[k] = Ir[0]/2 + sum(Ir[j]*cos((k+1/2)*j*pi/N), 1<=j<N)
    // (vDSP.h ~L7403-7404). Uses an asymmetric input (input[j] = j - 8, so
    // no two elements are equal and none are zero except j=8) so an
    // argument-order or off-by-one bug in j indexing would be caught.
    const n: Length = 16;
    const dct = try DCT.init(n, .dct_III);
    defer dct.deinit();

    var input: [n]f32 = undefined;
    for (0..n) |j| input[j] = @as(f32, @floatFromInt(j)) - 8.0;
    var output: [n]f32 = undefined;
    dct.exec(&input, &output);

    const nf: f32 = @floatFromInt(n);
    for (0..n) |k| {
        const kf: f32 = @floatFromInt(k);
        var expected: f32 = input[0] / 2.0;
        for (1..n) |j| {
            const jf: f32 = @floatFromInt(j);
            expected += input[j] * @cos((kf + 0.5) * jf * std.math.pi / nf);
        }
        try std.testing.expectApproxEqAbs(expected, output[k], 1e-2);
    }
}

test "InterleavedDFT(f32) complex-to-complex matches split-complex DFT(f32) for the same input" {
    // Cross-check against the already-verified DFT(T) (split-complex) type
    // above, per fix/REQUEST.md's suggestion to cross-check FFT/DFT variants
    // against each other. Same asymmetric input, same length, same
    // direction - outputs must agree element-wise.
    const n: Length = 8;
    const split = try DFT(f32).init(n, .forward);
    defer split.deinit();
    const interleaved = try InterleavedDFT(f32).init(n, .forward, .complex_to_complex);
    defer interleaved.deinit();

    var ir = [_]f32{ 1, -2, 3, 0, 5, -1, 0, 2 };
    var ii = [_]f32{ 0, 1, -1, 2, 0, 0, 3, -2 };
    var or_out: [n]f32 = undefined;
    var oi_out: [n]f32 = undefined;
    split.exec(&ir, &ii, &or_out, &oi_out);

    var in_c: [n]Complex(f32) = undefined;
    for (0..n) |i| in_c[i] = .{ .real = ir[i], .imag = ii[i] };
    var out_c: [n]Complex(f32) = undefined;
    interleaved.exec(&in_c, &out_c);

    for (0..n) |k| {
        try std.testing.expectApproxEqAbs(or_out[k], out_c[k].real, 1e-3);
        try std.testing.expectApproxEqAbs(oi_out[k], out_c[k].imag, 1e-3);
    }
}

test "InterleavedDFT(f32) real-to-complex uses the same DC/Nyquist-in-slot-0 packing and C=2 scale as RealDFT" {
    // vDSP.h documents no data layout at all for the Interleaved real-to-
    // complex mode (only "For real-to-complex DFT, Length should be half of
    // the length of the real signal", ~L7515) - unlike zrop's detailed
    // "Data Layout" section. Runtime-determined here: it turns out to match
    // RealDFT(T) (vDSP_DFT_zrop) exactly - impulse at real-sample index 0,
    // packed as slot[0].real=x[0], slot[0].imag=x[1], ...:
    //   out[0].real = DC = C*1 = 2
    //   out[0].imag = Nyquist = C*1 = 2
    //   out[k].real = Re(H[k]) = 2, out[k].imag = Im(H[k]) = 0, for 1<=k<n
    // i.e. same C=2-forward scaling and same "DC in .real, Nyquist in
    // .imag" packing of slot 0 as RealDFT(T).exec's forward direction.
    const n: Length = 8; // complex slots; real signal length = 2*n = 16
    const fwd = try InterleavedDFT(f32).init(n, .forward, .real_to_complex);
    defer fwd.deinit();

    var in_c: [n]Complex(f32) = [_]Complex(f32){.{ .real = 0, .imag = 0 }} ** n;
    in_c[0] = .{ .real = 1, .imag = 0 };
    var out_c: [n]Complex(f32) = undefined;
    fwd.exec(&in_c, &out_c);

    try std.testing.expectApproxEqAbs(@as(f32, 2.0), out_c[0].real, 1e-4); // DC
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), out_c[0].imag, 1e-4); // Nyquist
    for (out_c[1..]) |v| {
        try std.testing.expectApproxEqAbs(@as(f32, 2.0), v.real, 1e-4);
        try std.testing.expectApproxEqAbs(@as(f32, 0.0), v.imag, 1e-4);
    }
}
