const std = @import("std");
const types = @import("types.zig");
const Length = types.Length;
const c = @import("c.zig");

// ============================================================================
// Types
// ============================================================================

pub const BiquadSetup = c.BiquadSetup;
pub const BiquadSetupD = c.BiquadSetupD;
pub const BiquadmSetup = c.BiquadmSetup;
pub const BiquadmSetupD = c.BiquadmSetupD;

// ============================================================================
// High-level wrappers
// ============================================================================

/// Single-channel cascaded biquad IIR filter, generic over f32 or f64.
///
/// - `Biquad(f32)` performs single-precision processing with double-precision coefficients.
/// - `Biquad(f64)` performs double-precision processing with double-precision coefficients.
pub fn Biquad(comptime T: type) type {
    return struct {
        const Self = @This();

        setup: switch (T) {
            f32 => BiquadSetup,
            f64 => BiquadSetupD,
            else => @compileError("Biquad requires f32 or f64"),
        },
        delay: []T,
        sections: Length,

        /// Allocates memory and prepares the coefficients for processing a cascaded biquad IIR filter.
        ///
        /// coefficients: 5 doubles per section [b0, b1, b2, a1, a2] x sections
        pub fn init(allocator: std.mem.Allocator, coefficients: []const f64, sections: Length) !Self {
            const setup = switch (T) {
                f32 => c.vDSP_biquad_CreateSetup(coefficients.ptr, sections),
                f64 => c.vDSP_biquad_CreateSetupD(coefficients.ptr, sections),
                else => @compileError("Biquad requires f32 or f64"),
            };
            const s = setup orelse return error.SetupFailed;
            errdefer switch (T) {
                f32 => c.vDSP_biquad_DestroySetup(s),
                f64 => c.vDSP_biquad_DestroySetupD(s),
                else => unreachable,
            };
            const delay = try allocator.alloc(T, (sections + 1) * 2);
            @memset(delay, 0);
            return .{ .setup = s, .delay = delay, .sections = sections };
        }

        /// Frees the memory allocated by init.
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            switch (T) {
                f32 => c.vDSP_biquad_DestroySetup(self.setup),
                f64 => c.vDSP_biquad_DestroySetupD(self.setup),
                else => @compileError("Biquad requires f32 or f64"),
            }
            allocator.free(self.delay);
            self.* = undefined;
        }

        /// Cascade biquadratic IIR filters.
        ///
        /// X provides the bulk of the input signal. Delay provides prior state
        /// data for S biquadratic filters. The filters are applied to the data in
        /// turn. The output of the final filter is stored in Y, and the final
        /// state data of the filters are stored in Delay.
        pub fn apply(self: *Self, input: []const T, output: []T) void {
            switch (T) {
                f32 => c.vDSP_biquad(self.setup, self.delay.ptr, input.ptr, 1, output.ptr, 1, input.len),
                f64 => c.vDSP_biquadD(self.setup, self.delay.ptr, input.ptr, 1, output.ptr, 1, input.len),
                else => @compileError("Biquad requires f32 or f64"),
            }
        }

        /// Update the filter coefficients within a valid setup object.
        ///
        /// coeffs: 5 doubles per section [b0, b1, b2, a1, a2] x nsec, starting
        /// at section `start_section` (same 5-per-section layout as `init`).
        /// Note: only available for f32 (single-precision setup); vDSP.h
        /// declares no `*D` variant of vDSP_biquad_SetCoefficientsDouble.
        pub const setCoefficientsDouble = switch (T) {
            f32 => struct {
                fn func(self: Self, coeffs: []const f64, start_section: Length) void {
                    std.debug.assert(coeffs.len % 5 == 0);
                    c.vDSP_biquad_SetCoefficientsDouble(self.setup, coeffs.ptr, start_section, coeffs.len / 5);
                }
            }.func,
            else => @compileError("setCoefficientsDouble is only available for Biquad(f32)"),
        };

        /// Update the filter coefficients within a valid setup object.
        ///
        /// coeffs: 5 floats per section [b0, b1, b2, a1, a2] x nsec, starting
        /// at section `start_section` (same 5-per-section layout as `init`).
        /// Note: only available for f32 (single-precision setup); vDSP.h
        /// declares no `*D` variant of vDSP_biquad_SetCoefficientsSingle.
        pub const setCoefficientsSingle = switch (T) {
            f32 => struct {
                fn func(self: Self, coeffs: []const f32, start_section: Length) void {
                    std.debug.assert(coeffs.len % 5 == 0);
                    c.vDSP_biquad_SetCoefficientsSingle(self.setup, coeffs.ptr, start_section, coeffs.len / 5);
                }
            }.func,
            else => @compileError("setCoefficientsSingle is only available for Biquad(f32)"),
        };
    };
}

/// Multi-channel cascaded biquad IIR filter, generic over f32 or f64.
///
/// - `Biquadm(f32)` performs single-precision processing.
/// - `Biquadm(f64)` performs double-precision processing.
pub fn Biquadm(comptime T: type) type {
    const Setup = switch (T) {
        f32 => BiquadmSetup,
        f64 => BiquadmSetupD,
        else => @compileError("Biquadm requires f32 or f64"),
    };

    return struct {
        const Self = @This();

        setup: Setup,
        sections: Length,
        channels: Length,

        /// Allocates memory and prepares the coefficients for processing a
        /// multi-channel cascaded biquad IIR filter. Delay values are set to zero.
        ///
        /// Unlike some other setup objects in vDSP, a biquadm setup
        /// contains data that is modified during an apply call, and it therefore may not be
        /// used more than once simultaneously, as in multiple threads.
        ///
        /// coefficients: 5 doubles per (section, channel) pair, laid out
        /// section-major: [sec0_ch0, sec0_ch1, ..., sec0_ch(N-1), sec1_ch0, ...].
        /// Runtime-confirmed (not documented in vDSP.h): a 2-section/2-channel
        /// setup with a distinguishing one-pole block placed at flat coefficient
        /// index 10 produced a decaying response on channel 0 (not channel 1),
        /// which only matches the section-major ordering, not a channel-major
        /// ordering like [ch0_sec0, ch0_sec1, ch1_sec0, ...].
        pub fn init(coefficients: []const f64, sections: Length, channels: Length) !Self {
            std.debug.assert(coefficients.len >= 5 * sections * channels);
            const setup = switch (T) {
                f32 => c.vDSP_biquadm_CreateSetup(coefficients.ptr, sections, channels),
                f64 => c.vDSP_biquadm_CreateSetupD(coefficients.ptr, sections, channels),
                else => @compileError("Biquadm requires f32 or f64"),
            };
            return .{
                .setup = setup orelse return error.SetupFailed,
                .sections = sections,
                .channels = channels,
            };
        }

        /// Frees the memory allocated by init.
        pub fn deinit(self: *Self) void {
            switch (T) {
                f32 => c.vDSP_biquadm_DestroySetup(self.setup),
                f64 => c.vDSP_biquadm_DestroySetupD(self.setup),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }

        /// Applies the multi-channel biquad IIR filter. `input` and `output`
        /// are arrays of per-channel buffer pointers, one entry per channel,
        /// each pointing at `n` samples.
        ///
        /// These are slices rather than bare `[*]`multi-pointers specifically
        /// so the channel count can be checked: vDSP_biquadm reads exactly
        /// `channels` pointers out of each array, and handing it fewer does
        /// not fault - it reads whatever follows in memory and, in testing,
        /// **hangs indefinitely**. Nothing in the C signature communicates
        /// that, so the length lives in the Zig type and the assert below
        /// converts a silent deadlock into an immediate, located panic.
        pub fn apply(self: Self, input: []const [*]const T, output: []const [*]T, n: Length) void {
            std.debug.assert(input.len >= self.channels);
            std.debug.assert(output.len >= self.channels);
            switch (T) {
                f32 => c.vDSP_biquadm(self.setup, input.ptr, 1, output.ptr, 1, n),
                f64 => c.vDSP_biquadmD(self.setup, input.ptr, 1, output.ptr, 1, n),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }

        /// Sets the delay values of the setup object to zero.
        pub fn resetState(self: Self) void {
            switch (T) {
                f32 => c.vDSP_biquadm_ResetState(self.setup),
                f64 => c.vDSP_biquadm_ResetStateD(self.setup),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }

        /// Copies `src`'s delay state into `self` (`self`'s prior state is
        /// discarded). The two objects must have been created with the same
        /// number of channels and sections.
        ///
        /// vDSP.h:472-474 declares `vDSP_biquadm_CopyState(__dest, __src)`
        /// with `__dest` first: it writes into `__dest` and reads from
        /// `__src`. Runtime-confirmed with a one-pole filter: give `a` and
        /// `b` distinct nonzero delay states (impulses of 1.0 and 2.0
        /// respectively), call `a.copyState(b)`, then apply zero input to
        /// both. With this argument order, `a`'s next output equals `b`'s
        /// (both follow `b`'s state: 0.5*2.0=1.0) while `b` is unaffected
        /// (also 1.0, continuing its own state) -- i.e. `self` ("a") must
        /// map to `__dest` and `src` ("b") must map to `__src` for
        /// `self.copyState(src)` to mean "self absorbs src's state" as its
        /// name and parameter promise. See the "Biquadm copyState" test.
        pub fn copyState(self: Self, src: Self) void {
            switch (T) {
                f32 => c.vDSP_biquadm_CopyState(self.setup, src.setup),
                f64 => c.vDSP_biquadm_CopyStateD(self.setup, src.setup),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }

        /// Update the filter coefficients within a valid setup object.
        ///
        /// Coefficients are specified in double precision. `coeffs` holds
        /// `nsec * nchn` blocks of 5 doubles `[b0, b1, b2, a1, a2]`, in the
        /// same section-major order as `init` (section-outer, channel-inner),
        /// covering sections `[start_sec, start_sec+nsec)` and channels
        /// `[start_chn, start_chn+nchn)`. Runtime-confirmed: on a 2x2 setup
        /// initialized to identity, updating (start_sec=1, start_chn=0,
        /// nsec=1, nchn=2) with a 2-block array assigning channel 0 a
        /// different pole than channel 1 produced exactly the two distinct,
        /// per-channel impulse responses expected under section-major
        /// ordering (see the "Biquadm partial coefficient update" test).
        pub fn setCoefficientsDouble(self: Self, coeffs: []const f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
            std.debug.assert(coeffs.len >= 5 * nsec * nchn);
            switch (T) {
                f32 => c.vDSP_biquadm_SetCoefficientsDouble(self.setup, coeffs.ptr, start_sec, start_chn, nsec, nchn),
                f64 => c.vDSP_biquadm_SetCoefficientsDoubleD(self.setup, coeffs.ptr, start_sec, start_chn, nsec, nchn),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }

        /// Update the filter coefficients within a valid setup object.
        ///
        /// Coefficients are specified in single precision. Same section-major
        /// `[b0, b1, b2, a1, a2]` block layout as `setCoefficientsDouble`.
        pub fn setCoefficientsSingle(self: Self, coeffs: []const f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
            std.debug.assert(coeffs.len >= 5 * nsec * nchn);
            switch (T) {
                f32 => c.vDSP_biquadm_SetCoefficientsSingle(self.setup, coeffs.ptr, start_sec, start_chn, nsec, nchn),
                f64 => c.vDSP_biquadm_SetCoefficientsSingleD(self.setup, coeffs.ptr, start_sec, start_chn, nsec, nchn),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }

        /// Sets new target coefficients for the given (section, channel)
        /// range, specified in double precision, with the same section-major
        /// block layout as `setCoefficientsDouble`. `interp_rate` and
        /// `interp_threshold` are documented by Apple only as controlling a
        /// smoothed transition toward the target coefficients; vDSP.h gives
        /// no formula. Runtime-tested here (impulse and constant-DC inputs,
        /// `interp_rate` from 1e-6 to 1000, `interp_threshold` from 0 to 100,
        /// both single big `apply` calls and many size-1 `apply` calls): in
        /// every case the output exactly matched an *instantaneous* switch to
        /// the target coefficients on the very next `apply` call -- no
        /// gradual, sample-by-sample transition was observed on this
        /// platform. Treat this as taking effect immediately unless you
        /// re-verify on your target OS/architecture.
        pub fn setTargetsDouble(self: Self, targets: []const f64, interp_rate: T, interp_threshold: T, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
            std.debug.assert(targets.len >= 5 * nsec * nchn);
            switch (T) {
                f32 => c.vDSP_biquadm_SetTargetsDouble(self.setup, targets.ptr, interp_rate, interp_threshold, start_sec, start_chn, nsec, nchn),
                f64 => c.vDSP_biquadm_SetTargetsDoubleD(self.setup, targets.ptr, interp_rate, interp_threshold, start_sec, start_chn, nsec, nchn),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }

        /// Sets new target coefficients, specified in single precision. See
        /// `setTargetsDouble` for the layout and the runtime findings on
        /// `interp_rate`/`interp_threshold` (no observed gradual ramp).
        pub fn setTargetsSingle(self: Self, targets: []const f32, interp_rate: T, interp_threshold: T, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
            std.debug.assert(targets.len >= 5 * nsec * nchn);
            switch (T) {
                f32 => c.vDSP_biquadm_SetTargetsSingle(self.setup, targets.ptr, interp_rate, interp_threshold, start_sec, start_chn, nsec, nchn),
                f64 => c.vDSP_biquadm_SetTargetsSingleD(self.setup, targets.ptr, interp_rate, interp_threshold, start_sec, start_chn, nsec, nchn),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }

        /// Sets the overall active/inactive filter state of the setup
        /// object. `filter_states` has one entry per channel (`self.channels`
        /// entries total); vDSP.h gives no separate length parameter.
        ///
        /// Runtime-tested here (matching and differing per-channel
        /// coefficients, with and without a pending `setTargets` call, and
        /// with sentinel-filled output buffers): marking a channel inactive
        /// produced NO observable difference in that channel's `apply()`
        /// output in any configuration tried -- the channel was still fully
        /// filtered and its output buffer was still overwritten. What
        /// "active/inactive" actually gates was not observable from this
        /// binding's surface on this platform; do not assume it mutes,
        /// bypasses, or freezes a channel without re-verifying.
        pub fn setActiveFilters(self: Self, filter_states: []const bool) void {
            std.debug.assert(filter_states.len >= self.channels);
            switch (T) {
                f32 => c.vDSP_biquadm_SetActiveFilters(self.setup, filter_states.ptr),
                f64 => c.vDSP_biquadm_SetActiveFiltersD(self.setup, filter_states.ptr),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }
    };
}

test "Biquad identity filter" {
    // b0=1, b1=0, b2=0, a1=0, a2=0: y[n] = x[n], independent of delay state.
    const coeffs = [_]f64{ 1.0, 0.0, 0.0, 0.0, 0.0 };
    var filter = try Biquad(f32).init(std.testing.allocator, &coeffs, 1);
    defer filter.deinit(std.testing.allocator);

    const input = [_]f32{ 1.0, -2.0, 3.5, 0.0 };
    var output: [4]f32 = undefined;
    filter.apply(&input, &output);
    try std.testing.expectEqualSlices(f32, &input, &output);
}

test "Biquad one-pole IIR" {
    // b0=1, b1=0, b2=0, a1=-0.5, a2=0: y[n] = x[n] + 0.5*y[n-1].
    // Impulse input with zero initial delay gives a known geometric decay:
    // y = [1, 0.5, 0.25, 0.125].
    const coeffs = [_]f64{ 1.0, 0.0, 0.0, -0.5, 0.0 };
    var filter = try Biquad(f32).init(std.testing.allocator, &coeffs, 1);
    defer filter.deinit(std.testing.allocator);

    const input = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    var output: [4]f32 = undefined;
    filter.apply(&input, &output);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), output[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), output[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), output[2], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.125), output[3], 0.0001);
}

test "Biquad setCoefficientsDouble/Single swap in a new response" {
    // Start as identity, then switch to a one-pole filter via each setter and
    // confirm the geometric-decay impulse response (same ground truth as the
    // "Biquad one-pole IIR" test above) takes effect on subsequent applies.
    const identity = [_]f64{ 1.0, 0.0, 0.0, 0.0, 0.0 };
    const one_pole_d = [_]f64{ 1.0, 0.0, 0.0, -0.5, 0.0 };
    const one_pole_s = [_]f32{ 1.0, 0.0, 0.0, -0.5, 0.0 };

    var f1 = try Biquad(f32).init(std.testing.allocator, &identity, 1);
    defer f1.deinit(std.testing.allocator);
    f1.setCoefficientsDouble(&one_pole_d, 0);
    const input = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    var out1: [4]f32 = undefined;
    f1.apply(&input, &out1);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out1[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), out1[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), out1[2], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.125), out1[3], 0.0001);

    var f2 = try Biquad(f32).init(std.testing.allocator, &identity, 1);
    defer f2.deinit(std.testing.allocator);
    f2.setCoefficientsSingle(&one_pole_s, 0);
    var out2: [4]f32 = undefined;
    f2.apply(&input, &out2);
    try std.testing.expectEqualSlices(f32, &out1, &out2);
}

test "Biquadm init/apply: distinct per-channel coefficients don't cross-contaminate" {
    // 2 channels, 1 section, section-major layout [ch0_coeffs, ch1_coeffs].
    // Channel 0: identity. Channel 1: one-pole decay (a1=-0.5). If channels
    // were mixed up, either channel would show the wrong response.
    const coeffs = [_]f64{
        1.0, 0.0, 0.0, 0.0, 0.0, // ch0: identity
        1.0, 0.0, 0.0, -0.5, 0.0, // ch1: one-pole
    };
    var filter = try Biquadm(f32).init(&coeffs, 1, 2);
    defer filter.deinit();

    const in0 = [_]f32{ 1.0, -2.0, 3.5, 0.0 };
    const in1 = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    var out0: [4]f32 = undefined;
    var out1: [4]f32 = undefined;
    const xs = [_][*]const f32{ &in0, &in1 };
    const ys = [_][*]f32{ &out0, &out1 };
    filter.apply(&xs, &ys, 4);

    // Channel 0 is identity: passes input through unchanged.
    try std.testing.expectEqualSlices(f32, &in0, &out0);
    // Channel 1 shows the known one-pole geometric decay, not channel 0's
    // asymmetric input pattern.
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out1[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), out1[1], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), out1[2], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.125), out1[3], 0.0001);
}

test "Biquadm setCoefficientsDouble: section-major partial update layout" {
    // 2 sections x 2 channels, all identity. Partially update
    // (start_sec=1, start_chn=0, nsec=1, nchn=2) with a 2-block array giving
    // channel 0 and channel 1 DIFFERENT poles, confirming the partial-update
    // array is section-major: [sec1_ch0, sec1_ch1], matching `init`'s layout.
    const identity = [_]f64{ 1.0, 0.0, 0.0, 0.0, 0.0 } ** 4;
    var filter = try Biquadm(f64).init(&identity, 2, 2);
    defer filter.deinit();

    const update = [_]f64{
        1.0, 0.0, 0.0, -0.5, 0.0, // sec1_ch0
        1.0, 0.0, 0.0, -0.25, 0.0, // sec1_ch1
    };
    filter.setCoefficientsDouble(&update, 1, 0, 1, 2);

    var in0 = [_]f64{ 1.0, 0.0, 0.0, 0.0 };
    var in1 = [_]f64{ 1.0, 0.0, 0.0, 0.0 };
    var out0: [4]f64 = undefined;
    var out1: [4]f64 = undefined;
    const xs = [_][*]const f64{ &in0, &in1 };
    const ys = [_][*]f64{ &out0, &out1 };
    filter.apply(&xs, &ys, 4);

    // Channel 0: sec0 identity cascaded with sec1 one-pole a1=-0.5.
    const expect0 = [_]f64{ 1.0, 0.5, 0.25, 0.125 };
    // Channel 1: sec0 identity cascaded with sec1 one-pole a1=-0.25.
    const expect1 = [_]f64{ 1.0, 0.25, 0.0625, 0.015625 };
    for (out0, expect0) |got, want| try std.testing.expectApproxEqAbs(want, got, 1e-9);
    for (out1, expect1) |got, want| try std.testing.expectApproxEqAbs(want, got, 1e-9);
}

test "Biquadm setCoefficientsSingle matches setCoefficientsDouble" {
    const identity = [_]f64{ 1.0, 0.0, 0.0, 0.0, 0.0 };
    const target_d = [_]f64{ 1.0, 0.0, 0.0, -0.5, 0.0 };
    const target_s = [_]f32{ 1.0, 0.0, 0.0, -0.5, 0.0 };

    var fd = try Biquadm(f32).init(&identity, 1, 1);
    defer fd.deinit();
    fd.setCoefficientsDouble(&target_d, 0, 0, 1, 1);

    var fs = try Biquadm(f32).init(&identity, 1, 1);
    defer fs.deinit();
    fs.setCoefficientsSingle(&target_s, 0, 0, 1, 1);

    const input = [_]f32{ 1.0, 0.0, 0.0, 0.0 };
    var out_d: [4]f32 = undefined;
    var out_s: [4]f32 = undefined;
    {
        const xs = [_][*]const f32{&input};
        const ys = [_][*]f32{&out_d};
        fd.apply(&xs, &ys, 4);
    }
    {
        const xs = [_][*]const f32{&input};
        const ys = [_][*]f32{&out_s};
        fs.apply(&xs, &ys, 4);
    }
    try std.testing.expectEqualSlices(f32, &out_d, &out_s);
}

test "Biquadm resetState zeroes the delay line" {
    const coeffs = [_]f64{ 1.0, 0.0, 0.0, -0.5, 0.0 };
    var filter = try Biquadm(f32).init(&coeffs, 1, 1);
    defer filter.deinit();

    // Advance state with an impulse.
    var in_imp = [_]f32{1.0};
    var out_imp: [1]f32 = undefined;
    {
        const xs = [_][*]const f32{&in_imp};
        const ys = [_][*]f32{&out_imp};
        filter.apply(&xs, &ys, 1);
    }

    filter.resetState();

    // With state reset to zero, a fresh impulse must reproduce exactly the
    // same first-sample response as a brand-new filter (1.0), not a
    // continuation of the pre-reset decay.
    var in_imp2 = [_]f32{1.0};
    var out_imp2: [1]f32 = undefined;
    {
        const xs = [_][*]const f32{&in_imp2};
        const ys = [_][*]f32{&out_imp2};
        filter.apply(&xs, &ys, 1);
    }
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out_imp2[0], 0.0001);
}

test "Biquadm copyState: self absorbs src's delay state" {
    // vDSP.h:472-478 declares vDSP_biquadm_CopyState(__dest, __src): writes
    // __dest, reads __src. `self.copyState(src)` must therefore make `self`
    // end up matching `src`'s state (self <- src), consistent with the
    // parameter being named `src`.
    const coeffs = [_]f64{ 1.0, 0.0, 0.0, -0.5, 0.0 };
    var a = try Biquadm(f32).init(&coeffs, 1, 1);
    defer a.deinit();
    var b = try Biquadm(f32).init(&coeffs, 1, 1);
    defer b.deinit();

    // Give `a` and `b` distinct, nonzero delay states via different impulse
    // magnitudes.
    {
        var in_a = [_]f32{1.0};
        var out_a: [1]f32 = undefined;
        const xs = [_][*]const f32{&in_a};
        const ys = [_][*]f32{&out_a};
        a.apply(&xs, &ys, 1);
    }
    {
        var in_b = [_]f32{2.0};
        var out_b: [1]f32 = undefined;
        const xs = [_][*]const f32{&in_b};
        const ys = [_][*]f32{&out_b};
        b.apply(&xs, &ys, 1);
    }

    a.copyState(b);

    // Continuing both with zero input: `a` must now follow `b`'s state
    // (0.5 * 2.0 = 1.0), and `b` must be untouched by the call (also 1.0,
    // continuing its own state).
    var out_a2: [1]f32 = undefined;
    var out_b2: [1]f32 = undefined;
    {
        var in_z = [_]f32{0.0};
        const xs = [_][*]const f32{&in_z};
        const ys = [_][*]f32{&out_a2};
        a.apply(&xs, &ys, 1);
    }
    {
        var in_z = [_]f32{0.0};
        const xs = [_][*]const f32{&in_z};
        const ys = [_][*]f32{&out_b2};
        b.apply(&xs, &ys, 1);
    }
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out_a2[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out_b2[0], 0.0001);
}

test "Biquadm setTargetsDouble/Single: runtime-confirmed to take effect immediately" {
    // [characterization] This test pins behavior that Apple does not document
    // and that was determined by running the real framework, not derived from
    // a header. It asserts what macOS does today. If a future OS version
    // changes it, this failing is the intended signal to re-verify and update
    // the doc comment - it is NOT evidence that this binding regressed.
    // No gradual ramp was observed on this platform (see doc comment on
    // setTargetsDouble); the output after calling setTargets must exactly
    // match the *target* filter's own step response from sample 0, i.e. the
    // same closed-form one-pole DC-step transient as an instantaneous
    // coefficient swap: y[n] = b0 + (-a1)*y[n-1], starting from zero delay.
    const identity = [_]f64{ 1.0, 0.0, 0.0, 0.0, 0.0 };
    const targets_d = [_]f64{ 0.1, 0.0, 0.0, -0.9, 0.0 };
    const targets_s = [_]f32{ 0.1, 0.0, 0.0, -0.9, 0.0 };

    var fd = try Biquadm(f64).init(&identity, 1, 1);
    defer fd.deinit();
    fd.setTargetsDouble(&targets_d, 0.05, 0.0, 0, 0, 1, 1);

    var fs = try Biquadm(f32).init(&[_]f64{ 1.0, 0.0, 0.0, 0.0, 0.0 }, 1, 1);
    defer fs.deinit();
    fs.setTargetsSingle(&targets_s, 0.05, 0.0, 0, 0, 1, 1);

    var input_d = [_]f64{ 1.0, 1.0, 1.0, 1.0 };
    var input_s = [_]f32{ 1.0, 1.0, 1.0, 1.0 };
    var out_d: [4]f64 = undefined;
    var out_s: [4]f32 = undefined;
    {
        const xs = [_][*]const f64{&input_d};
        const ys = [_][*]f64{&out_d};
        fd.apply(&xs, &ys, 4);
    }
    {
        const xs = [_][*]const f32{&input_s};
        const ys = [_][*]f32{&out_s};
        fs.apply(&xs, &ys, 4);
    }

    // Closed-form: y[0]=b0=0.1, y[n]=b0-a1*y[n-1]=0.1+0.9*y[n-1].
    var expect: [4]f64 = undefined;
    expect[0] = 0.1;
    for (1..4) |n| expect[n] = 0.1 + 0.9 * expect[n - 1];
    for (out_d, expect) |got, want| try std.testing.expectApproxEqAbs(want, got, 1e-9);
    for (out_s, expect) |got, want| try std.testing.expectApproxEqAbs(@as(f32, @floatCast(want)), got, 1e-4);
}

test "Biquadm setActiveFilters: passthrough, no observed effect on apply output" {
    // [characterization] This test pins behavior that Apple does not document
    // and that was determined by running the real framework, not derived from
    // a header. It asserts what macOS does today. If a future OS version
    // changes it, this failing is the intended signal to re-verify and update
    // the doc comment - it is NOT evidence that this binding regressed.
    // vDSP.h gives no pseudocode for what "active/inactive" gates. Runtime
    // testing (matching/differing per-channel coefficients, with/without a
    // pending setTargets call, and sentinel-filled output buffers) found NO
    // observable difference in an "inactive" channel's apply() output in any
    // configuration tried: the channel was still fully filtered. This test
    // only pins down that the call itself is a correct passthrough (does not
    // crash, does not alter unrelated channels) -- it intentionally does not
    // assert any muting/bypass semantics, since none were observed.
    const coeffs = [_]f64{ 1.0, 0.0, 0.0, -0.5, 0.0 } ** 2;
    var filter = try Biquadm(f64).init(&coeffs, 1, 2);
    defer filter.deinit();

    const states = [_]bool{ true, false };
    filter.setActiveFilters(&states);

    var in0 = [_]f64{ 1.0, 0.0, 0.0, 0.0 };
    var in1 = [_]f64{ 1.0, 0.0, 0.0, 0.0 };
    var out0: [4]f64 = undefined;
    var out1: [4]f64 = undefined;
    const xs = [_][*]const f64{ &in0, &in1 };
    const ys = [_][*]f64{ &out0, &out1 };
    filter.apply(&xs, &ys, 4);

    // Both channels have identical coefficients, so both must show the same
    // one-pole decay regardless of the active/inactive flag.
    const expect = [_]f64{ 1.0, 0.5, 0.25, 0.125 };
    for (out0, expect) |got, want| try std.testing.expectApproxEqAbs(want, got, 1e-9);
    for (out1, expect) |got, want| try std.testing.expectApproxEqAbs(want, got, 1e-9);
}

test "Biquadm init: (sections, channels) argument order, pinned with an asymmetric 3x2 setup" {
    // vDSP.h:447-451 names vDSP_biquadm_CreateSetup's two size parameters
    // only `__M` and `__N` and gives no prose for either, so which one is
    // sections and which is channels cannot be read off the header. Every
    // other Biquadm test here uses a 2x2 or single-section configuration,
    // which cannot tell the two apart - this one uses 3 sections x 2 channels
    // so swapping them changes both the response and the required buffer
    // shape.
    //
    // Channel 0: three cascaded one-poles (y[n] = x[n] + 0.5*y[n-1]).
    //   Impulse response of one section:   0.5^n
    //   Cascaded three times:              C(n+2, 2) * 0.5^n
    //     = 1, 1.5, 1.5, 1.25, ...
    // Channel 1: pure identity in all three sections, so the impulse passes
    // through unchanged. If (sections, channels) were reversed, the setup
    // would describe 2 sections x 3 channels and the two-pointer apply()
    // below would be reading a third channel pointer that does not exist.
    const one_pole = [_]f64{ 1.0, 0.0, 0.0, -0.5, 0.0 };
    const identity = [_]f64{ 1.0, 0.0, 0.0, 0.0, 0.0 };
    // Section-major layout: [sec0_ch0, sec0_ch1, sec1_ch0, sec1_ch1, ...]
    const coeffs = one_pole ++ identity ++ one_pole ++ identity ++ one_pole ++ identity;
    try std.testing.expectEqual(@as(usize, 5 * 3 * 2), coeffs.len);

    var filter = try Biquadm(f64).init(&coeffs, 3, 2);
    defer filter.deinit();
    try std.testing.expectEqual(@as(Length, 3), filter.sections);
    try std.testing.expectEqual(@as(Length, 2), filter.channels);

    const impulse = [_]f64{ 1, 0, 0, 0 };
    var out0 = [_]f64{ 0, 0, 0, 0 };
    var out1 = [_]f64{ 0, 0, 0, 0 };
    const xs = [_][*]const f64{ &impulse, &impulse };
    const ys = [_][*]f64{ &out0, &out1 };
    filter.apply(&xs, &ys, 4);

    // C(n+2,2) * 0.5^n for n = 0..3: 1*1, 3*0.5, 6*0.25, 10*0.125
    const expect0 = [_]f64{ 1.0, 1.5, 1.5, 1.25 };
    for (out0, expect0) |got, want| try std.testing.expectApproxEqAbs(want, got, 1e-9);
    // Identity sections leave the impulse alone; a section/channel mix-up
    // would have given this channel filtered output instead.
    try std.testing.expectEqualSlices(f64, &[_]f64{ 1, 0, 0, 0 }, &out1);
}
