const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;

// ============================================================================
// Types
// ============================================================================

pub const BiquadSetup = *opaque {};
pub const BiquadSetupD = *opaque {};
pub const BiquadmSetup = *opaque {};
pub const BiquadmSetupD = *opaque {};

// ============================================================================
// Raw C extern declarations
// ============================================================================

const c = struct {
    // -- Single-channel setup/destroy --
    extern fn vDSP_biquad_CreateSetup(Coefficients: [*]const f64, M: Length) ?BiquadSetup;
    extern fn vDSP_biquad_CreateSetupD(Coefficients: [*]const f64, M: Length) ?BiquadSetupD;
    extern fn vDSP_biquad_DestroySetup(setup: ?BiquadSetup) void;
    extern fn vDSP_biquad_DestroySetupD(setup: ?BiquadSetupD) void;

    // -- Single-channel coefficient update --
    extern fn vDSP_biquad_SetCoefficientsDouble(setup: BiquadSetup, coeffs: [*]const f64, start_sec: Length, nsec: Length) void;
    extern fn vDSP_biquad_SetCoefficientsSingle(setup: BiquadSetup, coeffs: [*]const f32, start_sec: Length, nsec: Length) void;

    // -- Single-channel execute --
    extern fn vDSP_biquad(Setup: BiquadSetup, Delay: [*]f32, X: [*]const f32, IX: Stride, Y: [*]f32, IY: Stride, N: Length) void;
    extern fn vDSP_biquadD(Setup: BiquadSetupD, Delay: [*]f64, X: [*]const f64, IX: Stride, Y: [*]f64, IY: Stride, N: Length) void;

    // -- Multi-channel setup/destroy --
    extern fn vDSP_biquadm_CreateSetup(coeffs: [*]const f64, M: Length, N: Length) ?BiquadmSetup;
    extern fn vDSP_biquadm_CreateSetupD(coeffs: [*]const f64, M: Length, N: Length) ?BiquadmSetupD;
    extern fn vDSP_biquadm_DestroySetup(setup: BiquadmSetup) void;
    extern fn vDSP_biquadm_DestroySetupD(setup: BiquadmSetupD) void;

    // -- Multi-channel state --
    extern fn vDSP_biquadm_CopyState(dest: BiquadmSetup, src: BiquadmSetup) void;
    extern fn vDSP_biquadm_CopyStateD(dest: BiquadmSetupD, src: BiquadmSetupD) void;
    extern fn vDSP_biquadm_ResetState(setup: BiquadmSetup) void;
    extern fn vDSP_biquadm_ResetStateD(setup: BiquadmSetupD) void;

    // -- Multi-channel coefficient update --
    extern fn vDSP_biquadm_SetCoefficientsDouble(setup: BiquadmSetup, coeffs: [*]const f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;
    extern fn vDSP_biquadm_SetCoefficientsDoubleD(setup: BiquadmSetupD, coeffs: [*]const f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;
    extern fn vDSP_biquadm_SetCoefficientsSingle(setup: BiquadmSetup, coeffs: [*]const f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;
    extern fn vDSP_biquadm_SetCoefficientsSingleD(setup: BiquadmSetupD, coeffs: [*]const f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;

    // -- Multi-channel target (interpolated coefficient update) --
    extern fn vDSP_biquadm_SetTargetsDouble(setup: BiquadmSetup, targets: [*]const f64, interp_rate: f32, interp_threshold: f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;
    extern fn vDSP_biquadm_SetTargetsDoubleD(setup: BiquadmSetupD, targets: [*]const f64, interp_rate: f64, interp_threshold: f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;
    extern fn vDSP_biquadm_SetTargetsSingle(setup: BiquadmSetup, targets: [*]const f32, interp_rate: f32, interp_threshold: f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;
    extern fn vDSP_biquadm_SetTargetsSingleD(setup: BiquadmSetupD, targets: [*]const f32, interp_rate: f64, interp_threshold: f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;

    // -- Multi-channel active filter control --
    extern fn vDSP_biquadm_SetActiveFilters(setup: BiquadmSetup, filter_states: [*]const bool) void;
    extern fn vDSP_biquadm_SetActiveFiltersD(setup: BiquadmSetupD, filter_states: [*]const bool) void;

    // -- Multi-channel execute --
    extern fn vDSP_biquadm(Setup: BiquadmSetup, X: [*]const [*]const f32, IX: Stride, Y: [*]const [*]f32, IY: Stride, N: Length) void;
    extern fn vDSP_biquadmD(Setup: BiquadmSetupD, X: [*]const [*]const f64, IX: Stride, Y: [*]const [*]f64, IY: Stride, N: Length) void;
};

// ============================================================================
// High-level wrappers
// ============================================================================

/// Single-channel cascaded biquad IIR filter (single-precision processing, double-precision coefficients)
pub const Biquad = struct {
    setup: BiquadSetup,
    delay: []f32,
    sections: Length,

    /// vDSP_biquad_CreateSetup allocates memory and prepares the coefficients for
    /// processing a cascaded biquad IIR filter.
    ///
    /// coefficients: 5 doubles per section [b0, b1, b2, a1, a2] x sections
    pub fn init(allocator: @import("std").mem.Allocator, coefficients: []const f64, sections: Length) !Biquad {
        const setup = c.vDSP_biquad_CreateSetup(coefficients.ptr, sections) orelse return error.SetupFailed;
        const delay = try allocator.alloc(f32, (sections + 1) * 2);
        @memset(delay, 0);
        return .{ .setup = setup, .delay = delay, .sections = sections };
    }

    /// vDSP_biquad_DestroySetup frees the memory allocated by
    /// vDSP_biquad_CreateSetup.
    pub fn deinit(self: *Biquad, allocator: @import("std").mem.Allocator) void {
        c.vDSP_biquad_DestroySetup(self.setup);
        allocator.free(self.delay);
        self.* = undefined;
    }

    /// Cascade biquadratic IIR filters.
    ///
    /// X provides the bulk of the input signal. Delay provides prior state
    /// data for S biquadratic filters. The filters are applied to the data in
    /// turn. The output of the final filter is stored in Y, and the final
    /// state data of the filters are stored in Delay.
    pub fn apply(self: *Biquad, input: []const f32, output: []f32) void {
        c.vDSP_biquad(self.setup, self.delay.ptr, input.ptr, 1, output.ptr, 1, input.len);
    }

    /// vDSP_biquad_SetCoefficientsDouble will
    /// update the filter coefficients within a valid vDSP_biquad_Setup object.
    ///
    /// Coefficients are specified in double precision.
    pub fn setCoefficientsDouble(self: Biquad, coeffs: []const f64, start_section: Length) void {
        c.vDSP_biquad_SetCoefficientsDouble(self.setup, coeffs.ptr, start_section, coeffs.len / 5);
    }

    /// vDSP_biquad_SetCoefficientsSingle will
    /// update the filter coefficients within a valid vDSP_biquad_Setup object.
    ///
    /// Coefficients are specified in single precision.
    pub fn setCoefficientsSingle(self: Biquad, coeffs: []const f32, start_section: Length) void {
        c.vDSP_biquad_SetCoefficientsSingle(self.setup, coeffs.ptr, start_section, coeffs.len / 5);
    }
};

/// Single-channel cascaded biquad IIR filter (double-precision)
pub const BiquadD = struct {
    setup: BiquadSetupD,
    delay: []f64,
    sections: Length,

    /// vDSP_biquad_CreateSetupD allocates memory and prepares the coefficients for
    /// processing a cascaded biquad IIR filter (double-precision).
    pub fn init(allocator: @import("std").mem.Allocator, coefficients: []const f64, sections: Length) !BiquadD {
        const setup = c.vDSP_biquad_CreateSetupD(coefficients.ptr, sections) orelse return error.SetupFailed;
        const delay = try allocator.alloc(f64, (sections + 1) * 2);
        @memset(delay, 0);
        return .{ .setup = setup, .delay = delay, .sections = sections };
    }

    /// vDSP_biquad_DestroySetupD frees the memory allocated by
    /// vDSP_biquad_CreateSetupD.
    pub fn deinit(self: *BiquadD, allocator: @import("std").mem.Allocator) void {
        c.vDSP_biquad_DestroySetupD(self.setup);
        allocator.free(self.delay);
        self.* = undefined;
    }

    /// Cascade biquadratic IIR filters (double-precision).
    ///
    /// X provides the bulk of the input signal. Delay provides prior state
    /// data for S biquadratic filters. The filters are applied to the data in
    /// turn. The output of the final filter is stored in Y, and the final
    /// state data of the filters are stored in Delay.
    pub fn apply(self: *BiquadD, input: []const f64, output: []f64) void {
        c.vDSP_biquadD(self.setup, self.delay.ptr, input.ptr, 1, output.ptr, 1, input.len);
    }
};

/// Multi-channel cascaded biquad IIR filter (single-precision)
pub const Biquadm = struct {
    setup: BiquadmSetup,
    sections: Length,
    channels: Length,

    /// vDSP_biquadm_CreateSetup allocates memory and prepares the coefficients for processing a
    /// multi-channel cascaded biquad IIR filter. Delay values are set to zero.
    ///
    /// Unlike some other setup objects in vDSP, a vDSP_biquadm_Setup
    /// contains data that is modified during a vDSP_biquadm call, and it therefore may not be
    /// used more than once simultaneously, as in multiple threads.
    ///
    /// coefficients: 5 doubles per section per channel, row-major [ch0_sec0, ch0_sec1, ..., ch1_sec0, ...]
    pub fn init(coefficients: []const f64, sections: Length, channels: Length) ?Biquadm {
        return .{
            .setup = c.vDSP_biquadm_CreateSetup(coefficients.ptr, sections, channels) orelse return null,
            .sections = sections,
            .channels = channels,
        };
    }

    /// vDSP_biquadm_DestroySetup frees the memory allocated by
    /// vDSP_biquadm_CreateSetup.
    pub fn deinit(self: Biquadm) void {
        c.vDSP_biquadm_DestroySetup(self.setup);
    }

    /// vDSP_biquadm applies a multi-channel biquad IIR filter created with
    /// vDSP_biquadm_CreateSetup.
    pub fn apply(self: Biquadm, input: [*]const [*]const f32, output: [*]const [*]f32, n: Length) void {
        c.vDSP_biquadm(self.setup, input, 1, output, 1, n);
    }

    /// vDSP_biquadm_ResetState sets the delay values of a biquadm setup object to zero.
    pub fn resetState(self: Biquadm) void {
        c.vDSP_biquadm_ResetState(self.setup);
    }

    /// vDSP_biquadm_CopyState copies the current state between two biquadm setup objects.
    /// The two objects must have been created with the same number of channels and sections.
    pub fn copyState(self: Biquadm, src: Biquadm) void {
        c.vDSP_biquadm_CopyState(self.setup, src.setup);
    }

    /// vDSP_biquadm_SetCoefficientsDouble will
    /// update the filter coefficients within a valid vDSP_biquadm_Setup object.
    pub fn setCoefficientsDouble(self: Biquadm, coeffs: []const f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
        c.vDSP_biquadm_SetCoefficientsDouble(self.setup, coeffs.ptr, start_sec, start_chn, nsec, nchn);
    }

    /// vDSP_biquadm_SetCoefficientsSingle will
    /// update the filter coefficients within a valid vDSP_biquadm_Setup object.
    ///
    /// Coefficients are specified in single precision.
    pub fn setCoefficientsSingle(self: Biquadm, coeffs: []const f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
        c.vDSP_biquadm_SetCoefficientsSingle(self.setup, coeffs.ptr, start_sec, start_chn, nsec, nchn);
    }

    /// vDSP_biquadm_SetTargetsDouble will
    /// set the target coefficients within a valid vDSP_biquadm_Setup object.
    pub fn setTargetsDouble(self: Biquadm, targets: []const f64, interp_rate: f32, interp_threshold: f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
        c.vDSP_biquadm_SetTargetsDouble(self.setup, targets.ptr, interp_rate, interp_threshold, start_sec, start_chn, nsec, nchn);
    }

    /// vDSP_biquadm_SetTargetsSingle will
    /// set the target coefficients within a valid vDSP_biquadm_Setup object.
    /// The target values are specified in single precision.
    pub fn setTargetsSingle(self: Biquadm, targets: []const f32, interp_rate: f32, interp_threshold: f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
        c.vDSP_biquadm_SetTargetsSingle(self.setup, targets.ptr, interp_rate, interp_threshold, start_sec, start_chn, nsec, nchn);
    }

    /// vDSP_biquadm_SetActiveFilters will set the overall active/inactive filter
    /// state of a valid vDSP_biquadm_Setup object.
    pub fn setActiveFilters(self: Biquadm, filter_states: []const bool) void {
        c.vDSP_biquadm_SetActiveFilters(self.setup, filter_states.ptr);
    }
};

/// Multi-channel cascaded biquad IIR filter (double-precision)
pub const BiquadmD = struct {
    setup: BiquadmSetupD,
    sections: Length,
    channels: Length,

    /// vDSP_biquadm_CreateSetupD allocates memory and prepares the coefficients for processing a
    /// multi-channel cascaded biquad IIR filter (double-precision). Delay values are set to zero.
    ///
    /// Unlike some other setup objects in vDSP, a vDSP_biquadm_SetupD
    /// contains data that is modified during a vDSP_biquadmD call, and it therefore may not be
    /// used more than once simultaneously, as in multiple threads.
    pub fn init(coefficients: []const f64, sections: Length, channels: Length) ?BiquadmD {
        return .{
            .setup = c.vDSP_biquadm_CreateSetupD(coefficients.ptr, sections, channels) orelse return null,
            .sections = sections,
            .channels = channels,
        };
    }

    /// vDSP_biquadm_DestroySetupD frees the memory allocated by
    /// vDSP_biquadm_CreateSetupD.
    pub fn deinit(self: BiquadmD) void {
        c.vDSP_biquadm_DestroySetupD(self.setup);
    }

    /// vDSP_biquadmD applies a multi-channel biquad IIR filter created with
    /// vDSP_biquadm_CreateSetupD.
    pub fn apply(self: BiquadmD, input: [*]const [*]const f64, output: [*]const [*]f64, n: Length) void {
        c.vDSP_biquadmD(self.setup, input, 1, output, 1, n);
    }

    /// vDSP_biquadm_ResetStateD sets the delay values of a biquadm setup object to zero.
    pub fn resetState(self: BiquadmD) void {
        c.vDSP_biquadm_ResetStateD(self.setup);
    }

    /// vDSP_biquadm_CopyStateD copies the current state between two biquadm setup objects.
    /// The two objects must have been created with the same number of channels and sections.
    pub fn copyState(self: BiquadmD, src: BiquadmD) void {
        c.vDSP_biquadm_CopyStateD(self.setup, src.setup);
    }

    /// vDSP_biquadm_SetCoefficientsDoubleD will
    /// update the filter coefficients within a valid vDSP_biquadm_SetupD object.
    pub fn setCoefficientsDouble(self: BiquadmD, coeffs: []const f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
        c.vDSP_biquadm_SetCoefficientsDoubleD(self.setup, coeffs.ptr, start_sec, start_chn, nsec, nchn);
    }

    /// vDSP_biquadm_SetTargetsDoubleD will
    /// set the target coefficients within a valid vDSP_biquadm_SetupD object.
    pub fn setTargetsDouble(self: BiquadmD, targets: []const f64, interp_rate: f64, interp_threshold: f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
        c.vDSP_biquadm_SetTargetsDoubleD(self.setup, targets.ptr, interp_rate, interp_threshold, start_sec, start_chn, nsec, nchn);
    }

    /// vDSP_biquadm_SetActiveFiltersD will set the overall active/inactive filter
    /// state of a valid vDSP_biquadm_SetupD object.
    pub fn setActiveFilters(self: BiquadmD, filter_states: []const bool) void {
        c.vDSP_biquadm_SetActiveFiltersD(self.setup, filter_states.ptr);
    }
};
