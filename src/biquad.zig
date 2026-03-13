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
        /// Coefficients are specified in double precision.
        /// Note: only available for f32 (single-precision setup).
        pub const setCoefficientsDouble = switch (T) {
            f32 => struct {
                fn func(self: Self, coeffs: []const f64, start_section: Length) void {
                    c.vDSP_biquad_SetCoefficientsDouble(self.setup, coeffs.ptr, start_section, coeffs.len / 5);
                }
            }.func,
            else => @compileError("setCoefficientsDouble is only available for Biquad(f32)"),
        };

        /// Update the filter coefficients within a valid setup object.
        ///
        /// Coefficients are specified in single precision.
        /// Note: only available for f32 (single-precision setup).
        pub const setCoefficientsSingle = switch (T) {
            f32 => struct {
                fn func(self: Self, coeffs: []const f32, start_section: Length) void {
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
        /// coefficients: 5 doubles per section per channel, row-major [ch0_sec0, ch0_sec1, ..., ch1_sec0, ...]
        pub fn init(coefficients: []const f64, sections: Length, channels: Length) ?Self {
            const setup = switch (T) {
                f32 => c.vDSP_biquadm_CreateSetup(coefficients.ptr, sections, channels),
                f64 => c.vDSP_biquadm_CreateSetupD(coefficients.ptr, sections, channels),
                else => @compileError("Biquadm requires f32 or f64"),
            };
            return .{
                .setup = setup orelse return null,
                .sections = sections,
                .channels = channels,
            };
        }

        /// Frees the memory allocated by init.
        pub fn deinit(self: Self) void {
            switch (T) {
                f32 => c.vDSP_biquadm_DestroySetup(self.setup),
                f64 => c.vDSP_biquadm_DestroySetupD(self.setup),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }

        /// Applies the multi-channel biquad IIR filter.
        pub fn apply(self: Self, input: [*]const [*]const T, output: [*]const [*]T, n: Length) void {
            switch (T) {
                f32 => c.vDSP_biquadm(self.setup, input, 1, output, 1, n),
                f64 => c.vDSP_biquadmD(self.setup, input, 1, output, 1, n),
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

        /// Copies the current state between two biquadm setup objects.
        /// The two objects must have been created with the same number of channels and sections.
        pub fn copyState(self: Self, src: Self) void {
            switch (T) {
                f32 => c.vDSP_biquadm_CopyState(src.setup, self.setup),
                f64 => c.vDSP_biquadm_CopyStateD(src.setup, self.setup),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }

        /// Update the filter coefficients within a valid setup object.
        ///
        /// Coefficients are specified in double precision.
        pub fn setCoefficientsDouble(self: Self, coeffs: []const f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
            switch (T) {
                f32 => c.vDSP_biquadm_SetCoefficientsDouble(self.setup, coeffs.ptr, start_sec, start_chn, nsec, nchn),
                f64 => c.vDSP_biquadm_SetCoefficientsDoubleD(self.setup, coeffs.ptr, start_sec, start_chn, nsec, nchn),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }

        /// Update the filter coefficients within a valid setup object.
        ///
        /// Coefficients are specified in single precision.
        pub fn setCoefficientsSingle(self: Self, coeffs: []const f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
            switch (T) {
                f32 => c.vDSP_biquadm_SetCoefficientsSingle(self.setup, coeffs.ptr, start_sec, start_chn, nsec, nchn),
                f64 => c.vDSP_biquadm_SetCoefficientsSingleD(self.setup, coeffs.ptr, start_sec, start_chn, nsec, nchn),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }

        /// Set the target coefficients within a valid setup object.
        ///
        /// Targets are specified in double precision.
        pub fn setTargetsDouble(self: Self, targets: []const f64, interp_rate: T, interp_threshold: T, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
            switch (T) {
                f32 => c.vDSP_biquadm_SetTargetsDouble(self.setup, targets.ptr, interp_rate, interp_threshold, start_sec, start_chn, nsec, nchn),
                f64 => c.vDSP_biquadm_SetTargetsDoubleD(self.setup, targets.ptr, interp_rate, interp_threshold, start_sec, start_chn, nsec, nchn),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }

        /// Set the target coefficients within a valid setup object.
        ///
        /// Targets are specified in single precision.
        pub fn setTargetsSingle(self: Self, targets: []const f32, interp_rate: T, interp_threshold: T, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void {
            switch (T) {
                f32 => c.vDSP_biquadm_SetTargetsSingle(self.setup, targets.ptr, interp_rate, interp_threshold, start_sec, start_chn, nsec, nchn),
                f64 => c.vDSP_biquadm_SetTargetsSingleD(self.setup, targets.ptr, interp_rate, interp_threshold, start_sec, start_chn, nsec, nchn),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }

        /// Set the overall active/inactive filter state of the setup object.
        pub fn setActiveFilters(self: Self, filter_states: []const bool) void {
            switch (T) {
                f32 => c.vDSP_biquadm_SetActiveFilters(self.setup, filter_states.ptr),
                f64 => c.vDSP_biquadm_SetActiveFiltersD(self.setup, filter_states.ptr),
                else => @compileError("Biquadm requires f32 or f64"),
            }
        }
    };
}
