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
// Low-level functions
// ============================================================================

// -- Single-channel --

pub fn biquad_create_setup(coefficients: []const f64, sections: Length) ?BiquadSetup {
    return c.vDSP_biquad_CreateSetup(coefficients.ptr, sections);
}

pub fn biquad_create_setupD(coefficients: []const f64, sections: Length) ?BiquadSetupD {
    return c.vDSP_biquad_CreateSetupD(coefficients.ptr, sections);
}

pub fn biquad_destroy_setup(setup: ?BiquadSetup) void {
    c.vDSP_biquad_DestroySetup(setup);
}

pub fn biquad_destroy_setupD(setup: ?BiquadSetupD) void {
    c.vDSP_biquad_DestroySetupD(setup);
}

pub fn biquad(setup: BiquadSetup, delay: [*]f32, x: []const f32, y: []f32) void {
    c.vDSP_biquad(setup, delay, x.ptr, 1, y.ptr, 1, x.len);
}

pub fn biquadD(setup: BiquadSetupD, delay: [*]f64, x: []const f64, y: []f64) void {
    c.vDSP_biquadD(setup, delay, x.ptr, 1, y.ptr, 1, x.len);
}

// -- Multi-channel --

pub fn biquadm_create_setup(coefficients: []const f64, sections: Length, channels: Length) ?BiquadmSetup {
    return c.vDSP_biquadm_CreateSetup(coefficients.ptr, sections, channels);
}

pub fn biquadm_create_setupD(coefficients: []const f64, sections: Length, channels: Length) ?BiquadmSetupD {
    return c.vDSP_biquadm_CreateSetupD(coefficients.ptr, sections, channels);
}

pub fn biquadm_destroy_setup(setup: BiquadmSetup) void {
    c.vDSP_biquadm_DestroySetup(setup);
}

pub fn biquadm_destroy_setupD(setup: BiquadmSetupD) void {
    c.vDSP_biquadm_DestroySetupD(setup);
}

pub fn biquadm(setup: BiquadmSetup, x: [*]const [*]const f32, y: [*]const [*]f32, n: Length) void {
    c.vDSP_biquadm(setup, x, 1, y, 1, n);
}

pub fn biquadmD(setup: BiquadmSetupD, x: [*]const [*]const f64, y: [*]const [*]f64, n: Length) void {
    c.vDSP_biquadmD(setup, x, 1, y, 1, n);
}

// ============================================================================
// High-level wrappers
// ============================================================================

/// Single-channel cascaded biquad IIR filter (single-precision processing, double-precision coefficients)
pub const Biquad = struct {
    setup: BiquadSetup,
    delay: []f32,
    sections: Length,

    /// coefficients: 5 doubles per section [b0, b1, b2, a1, a2] x sections
    pub fn init(allocator: @import("std").mem.Allocator, coefficients: []const f64, sections: Length) !Biquad {
        const setup = biquad_create_setup(coefficients, sections) orelse return error.SetupFailed;
        const delay = try allocator.alloc(f32, (sections + 1) * 2);
        @memset(delay, 0);
        return .{ .setup = setup, .delay = delay, .sections = sections };
    }

    pub fn deinit(self: *Biquad, allocator: @import("std").mem.Allocator) void {
        biquad_destroy_setup(self.setup);
        allocator.free(self.delay);
        self.* = undefined;
    }

    pub fn apply(self: *Biquad, input: []const f32, output: []f32) void {
        biquad(self.setup, self.delay.ptr, input, output);
    }

    pub fn setCoefficientsDouble(self: Biquad, coeffs: []const f64, start_section: Length) void {
        c.vDSP_biquad_SetCoefficientsDouble(self.setup, coeffs.ptr, start_section, coeffs.len / 5);
    }

    pub fn setCoefficientsSingle(self: Biquad, coeffs: []const f32, start_section: Length) void {
        c.vDSP_biquad_SetCoefficientsSingle(self.setup, coeffs.ptr, start_section, coeffs.len / 5);
    }
};

/// Single-channel cascaded biquad IIR filter (double-precision)
pub const BiquadD = struct {
    setup: BiquadSetupD,
    delay: []f64,
    sections: Length,

    pub fn init(allocator: @import("std").mem.Allocator, coefficients: []const f64, sections: Length) !BiquadD {
        const setup = biquad_create_setupD(coefficients, sections) orelse return error.SetupFailed;
        const delay = try allocator.alloc(f64, (sections + 1) * 2);
        @memset(delay, 0);
        return .{ .setup = setup, .delay = delay, .sections = sections };
    }

    pub fn deinit(self: *BiquadD, allocator: @import("std").mem.Allocator) void {
        biquad_destroy_setupD(self.setup);
        allocator.free(self.delay);
        self.* = undefined;
    }

    pub fn apply(self: *BiquadD, input: []const f64, output: []f64) void {
        biquadD(self.setup, self.delay.ptr, input, output);
    }
};

/// Multi-channel cascaded biquad IIR filter (single-precision)
pub const Biquadm = struct {
    setup: BiquadmSetup,
    sections: Length,
    channels: Length,

    /// coefficients: 5 doubles per section per channel, row-major [ch0_sec0, ch0_sec1, ..., ch1_sec0, ...]
    pub fn init(coefficients: []const f64, sections: Length, channels: Length) ?Biquadm {
        return .{
            .setup = biquadm_create_setup(coefficients, sections, channels) orelse return null,
            .sections = sections,
            .channels = channels,
        };
    }

    pub fn deinit(self: Biquadm) void {
        biquadm_destroy_setup(self.setup);
    }

    pub fn apply(self: Biquadm, input: [*]const [*]const f32, output: [*]const [*]f32, n: Length) void {
        biquadm(self.setup, input, output, n);
    }

    pub fn resetState(self: Biquadm) void {
        c.vDSP_biquadm_ResetState(self.setup);
    }

    pub fn copyState(self: Biquadm, src: Biquadm) void {
        c.vDSP_biquadm_CopyState(self.setup, src.setup);
    }

    pub fn setCoefficientsDouble(self: Biquadm, coeffs: []const f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
        c.vDSP_biquadm_SetCoefficientsDouble(self.setup, coeffs.ptr, start_sec, start_chn, nsec, nchn);
    }

    pub fn setCoefficientsSingle(self: Biquadm, coeffs: []const f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
        c.vDSP_biquadm_SetCoefficientsSingle(self.setup, coeffs.ptr, start_sec, start_chn, nsec, nchn);
    }

    pub fn setTargetsDouble(self: Biquadm, targets: []const f64, interp_rate: f32, interp_threshold: f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
        c.vDSP_biquadm_SetTargetsDouble(self.setup, targets.ptr, interp_rate, interp_threshold, start_sec, start_chn, nsec, nchn);
    }

    pub fn setTargetsSingle(self: Biquadm, targets: []const f32, interp_rate: f32, interp_threshold: f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
        c.vDSP_biquadm_SetTargetsSingle(self.setup, targets.ptr, interp_rate, interp_threshold, start_sec, start_chn, nsec, nchn);
    }

    pub fn setActiveFilters(self: Biquadm, filter_states: []const bool) void {
        c.vDSP_biquadm_SetActiveFilters(self.setup, filter_states.ptr);
    }
};

/// Multi-channel cascaded biquad IIR filter (double-precision)
pub const BiquadmD = struct {
    setup: BiquadmSetupD,
    sections: Length,
    channels: Length,

    pub fn init(coefficients: []const f64, sections: Length, channels: Length) ?BiquadmD {
        return .{
            .setup = biquadm_create_setupD(coefficients, sections, channels) orelse return null,
            .sections = sections,
            .channels = channels,
        };
    }

    pub fn deinit(self: BiquadmD) void {
        biquadm_destroy_setupD(self.setup);
    }

    pub fn apply(self: BiquadmD, input: [*]const [*]const f64, output: [*]const [*]f64, n: Length) void {
        biquadmD(self.setup, input, output, n);
    }

    pub fn resetState(self: BiquadmD) void {
        c.vDSP_biquadm_ResetStateD(self.setup);
    }

    pub fn copyState(self: BiquadmD, src: BiquadmD) void {
        c.vDSP_biquadm_CopyStateD(self.setup, src.setup);
    }

    pub fn setCoefficientsDouble(self: BiquadmD, coeffs: []const f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
        c.vDSP_biquadm_SetCoefficientsDoubleD(self.setup, coeffs.ptr, start_sec, start_chn, nsec, nchn);
    }

    pub fn setTargetsDouble(self: BiquadmD, targets: []const f64, interp_rate: f64, interp_threshold: f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
        c.vDSP_biquadm_SetTargetsDoubleD(self.setup, targets.ptr, interp_rate, interp_threshold, start_sec, start_chn, nsec, nchn);
    }

    pub fn setActiveFilters(self: BiquadmD, filter_states: []const bool) void {
        c.vDSP_biquadm_SetActiveFiltersD(self.setup, filter_states.ptr);
    }
};
