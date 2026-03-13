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

pub const Complex = fft.Complex;

// ============================================================================
// High-level DFT wrappers (manage setup lifetime)
// ============================================================================

/// Complex-to-complex DFT (split complex).
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

        pub fn init(length: Length, direction: Direction) ?Self {
            const dir = @intFromEnum(direction);
            const setup = switch (T) {
                f32 => c.vDSP_DFT_zop_CreateSetup(null, length, dir),
                f64 => c.vDSP_DFT_zop_CreateSetupD(null, length, dir),
                else => unreachable,
            };
            return .{ .setup = setup orelse return null };
        }

        pub fn initShared(previous: Setup, length: Length, direction: Direction) ?Self {
            const dir = @intFromEnum(direction);
            const setup = switch (T) {
                f32 => c.vDSP_DFT_zop_CreateSetup(previous, length, dir),
                f64 => c.vDSP_DFT_zop_CreateSetupD(previous, length, dir),
                else => unreachable,
            };
            return .{ .setup = setup orelse return null };
        }

        pub fn deinit(self: Self) void {
            switch (T) {
                f32 => c.vDSP_DFT_DestroySetup(self.setup),
                f64 => c.vDSP_DFT_DestroySetupD(self.setup),
                else => unreachable,
            }
        }

        pub fn exec(self: Self, ir: []const T, ii: []const T, or_out: []T, oi_out: []T) void {
            switch (T) {
                f32 => c.vDSP_DFT_Execute(self.setup, ir.ptr, ii.ptr, or_out.ptr, oi_out.ptr),
                f64 => c.vDSP_DFT_ExecuteD(self.setup, ir.ptr, ii.ptr, or_out.ptr, oi_out.ptr),
                else => unreachable,
            }
        }
    };
}

/// Real-to-complex DFT (split complex).
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

        pub fn init(length: Length, direction: Direction) ?Self {
            const dir = @intFromEnum(direction);
            const setup = switch (T) {
                f32 => c.vDSP_DFT_zrop_CreateSetup(null, length, dir),
                f64 => c.vDSP_DFT_zrop_CreateSetupD(null, length, dir),
                else => unreachable,
            };
            return .{ .setup = setup orelse return null };
        }

        pub fn deinit(self: Self) void {
            switch (T) {
                f32 => c.vDSP_DFT_DestroySetup(self.setup),
                f64 => c.vDSP_DFT_DestroySetupD(self.setup),
                else => unreachable,
            }
        }

        pub fn exec(self: Self, ir: []const T, ii: []const T, or_out: []T, oi_out: []T) void {
            switch (T) {
                f32 => c.vDSP_DFT_Execute(self.setup, ir.ptr, ii.ptr, or_out.ptr, oi_out.ptr),
                f64 => c.vDSP_DFT_ExecuteD(self.setup, ir.ptr, ii.ptr, or_out.ptr, oi_out.ptr),
                else => unreachable,
            }
        }
    };
}

/// DCT (single-precision, type II/III/IV)
pub const DCT = struct {
    setup: DFTSetup,

    pub fn init(length: Length, dct_type: DCTType) ?DCT {
        return .{ .setup = c.vDSP_DCT_CreateSetup(null, length, @intFromEnum(dct_type)) orelse return null };
    }

    pub fn deinit(self: DCT) void {
        c.vDSP_DFT_DestroySetup(self.setup);
    }

    pub fn exec(self: DCT, input: []const f32, output: []f32) void {
        c.vDSP_DCT_Execute(self.setup, input.ptr, output.ptr);
    }
};

/// Interleaved complex DFT.
/// Use InterleavedDFT(f32) for single-precision or InterleavedDFT(f64) for double-precision.
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

        pub fn init(length: Length, direction: Direction, rtc: RealToComplex) ?Self {
            const dir = @intFromEnum(direction);
            const r2c = @intFromEnum(rtc);
            const setup = switch (T) {
                f32 => c.vDSP_DFT_Interleaved_CreateSetup(null, length, dir, r2c),
                f64 => c.vDSP_DFT_Interleaved_CreateSetupD(null, length, dir, r2c),
                else => unreachable,
            };
            return .{ .setup = setup orelse return null };
        }

        pub fn deinit(self: Self) void {
            switch (T) {
                f32 => c.vDSP_DFT_Interleaved_DestroySetup(self.setup),
                f64 => c.vDSP_DFT_Interleaved_DestroySetupD(self.setup),
                else => unreachable,
            }
        }

        pub fn exec(self: Self, input: []const C, output: []C) void {
            switch (T) {
                f32 => c.vDSP_DFT_Interleaved_Execute(self.setup, input.ptr, output.ptr),
                f64 => c.vDSP_DFT_Interleaved_ExecuteD(self.setup, input.ptr, output.ptr),
                else => unreachable,
            }
        }
    };
}
