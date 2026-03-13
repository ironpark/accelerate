const types = @import("types.zig");
const Length = types.Length;
const Stride = types.Stride;
const SplitComplex = types.SplitComplex;
const DoubleSplitComplex = types.DoubleSplitComplex;

// ============================================================================
// Types
// ============================================================================

pub const DFTSetup = *opaque {};
pub const DFTSetupD = *opaque {};
pub const DFTInterleavedSetup = *opaque {};
pub const DFTInterleavedSetupD = *opaque {};

pub const Direction = enum(c_int) {
    forward = 1,
    inverse = -1,
};

pub const DCTType = enum(c_int) {
    dct_II = 2,
    dct_III = 3,
    dct_IV = 4,
};

pub const RealToComplex = enum(c_int) {
    complex_to_complex = 0,
    real_to_complex = 1,
};

pub const Complex = extern struct { real: f32, imag: f32 };
pub const DoubleComplex = extern struct { real: f64, imag: f64 };

// ============================================================================
// Raw C extern declarations
// ============================================================================

const c = struct {
    // -- Setup --
    extern fn vDSP_DFT_CreateSetup(Previous: ?DFTSetup, Length: Length) ?DFTSetup;
    extern fn vDSP_DFT_zop_CreateSetup(Previous: ?DFTSetup, Length: Length, Direction: c_int) ?DFTSetup;
    extern fn vDSP_DFT_zop_CreateSetupD(Previous: ?DFTSetupD, Length: Length, Direction: c_int) ?DFTSetupD;
    extern fn vDSP_DFT_zrop_CreateSetup(Previous: ?DFTSetup, Length: Length, Direction: c_int) ?DFTSetup;
    extern fn vDSP_DFT_zrop_CreateSetupD(Previous: ?DFTSetupD, Length: Length, Direction: c_int) ?DFTSetupD;
    extern fn vDSP_DCT_CreateSetup(Previous: ?DFTSetup, Length: Length, Type: c_int) ?DFTSetup;

    // -- Destroy --
    extern fn vDSP_DFT_DestroySetup(Setup: ?DFTSetup) void;
    extern fn vDSP_DFT_DestroySetupD(Setup: ?DFTSetupD) void;

    // -- Execute (split complex) --
    extern fn vDSP_DFT_Execute(Setup: DFTSetup, Ir: [*]const f32, Ii: [*]const f32, Or: [*]f32, Oi: [*]f32) void;
    extern fn vDSP_DFT_ExecuteD(Setup: DFTSetupD, Ir: [*]const f64, Ii: [*]const f64, Or: [*]f64, Oi: [*]f64) void;

    // -- Legacy execute with stride --
    extern fn vDSP_DFT_zop(Setup: DFTSetup, Ir: [*]const f32, Ii: [*]const f32, Is: Stride, Or: [*]f32, Oi: [*]f32, Os: Stride, Direction: c_int) void;

    // -- DCT execute --
    extern fn vDSP_DCT_Execute(Setup: DFTSetup, Input: [*]const f32, Output: [*]f32) void;

    // -- Interleaved setup --
    extern fn vDSP_DFT_Interleaved_CreateSetup(Previous: ?DFTInterleavedSetup, Length: Length, Direction: c_int, RealToComplex: c_int) ?DFTInterleavedSetup;
    extern fn vDSP_DFT_Interleaved_CreateSetupD(Previous: ?DFTInterleavedSetupD, Length: Length, Direction: c_int, RealToComplex: c_int) ?DFTInterleavedSetupD;

    // -- Interleaved execute --
    extern fn vDSP_DFT_Interleaved_Execute(Setup: DFTInterleavedSetup, Iri: [*]const Complex, Ori: [*]Complex) void;
    extern fn vDSP_DFT_Interleaved_ExecuteD(Setup: DFTInterleavedSetupD, Iri: [*]const DoubleComplex, Ori: [*]DoubleComplex) void;

    // -- Interleaved destroy --
    extern fn vDSP_DFT_Interleaved_DestroySetup(Setup: ?DFTInterleavedSetup) void;
    extern fn vDSP_DFT_Interleaved_DestroySetupD(Setup: ?DFTInterleavedSetupD) void;
};

// ============================================================================
// High-level DFT wrappers (manage setup lifetime)
// ============================================================================

/// Complex-to-complex DFT (split complex, single-precision)
pub const DFT = struct {
    setup: DFTSetup,

    pub fn init(length: Length, direction: Direction) ?DFT {
        return .{ .setup = c.vDSP_DFT_zop_CreateSetup(null, length, @intFromEnum(direction)) orelse return null };
    }

    pub fn initShared(previous: DFTSetup, length: Length, direction: Direction) ?DFT {
        return .{ .setup = c.vDSP_DFT_zop_CreateSetup(previous, length, @intFromEnum(direction)) orelse return null };
    }

    pub fn deinit(self: DFT) void {
        c.vDSP_DFT_DestroySetup(self.setup);
    }

    pub fn exec(self: DFT, ir: []const f32, ii: []const f32, or_out: []f32, oi_out: []f32) void {
        c.vDSP_DFT_Execute(self.setup, ir.ptr, ii.ptr, or_out.ptr, oi_out.ptr);
    }
};

/// Complex-to-complex DFT (split complex, double-precision)
pub const DFTD = struct {
    setup: DFTSetupD,

    pub fn init(length: Length, direction: Direction) ?DFTD {
        return .{ .setup = c.vDSP_DFT_zop_CreateSetupD(null, length, @intFromEnum(direction)) orelse return null };
    }

    pub fn deinit(self: DFTD) void {
        c.vDSP_DFT_DestroySetupD(self.setup);
    }

    pub fn exec(self: DFTD, ir: []const f64, ii: []const f64, or_out: []f64, oi_out: []f64) void {
        c.vDSP_DFT_ExecuteD(self.setup, ir.ptr, ii.ptr, or_out.ptr, oi_out.ptr);
    }
};

/// Real-to-complex DFT (split complex, single-precision)
pub const RealDFT = struct {
    setup: DFTSetup,

    pub fn init(length: Length, direction: Direction) ?RealDFT {
        return .{ .setup = c.vDSP_DFT_zrop_CreateSetup(null, length, @intFromEnum(direction)) orelse return null };
    }

    pub fn deinit(self: RealDFT) void {
        c.vDSP_DFT_DestroySetup(self.setup);
    }

    pub fn exec(self: RealDFT, ir: []const f32, ii: []const f32, or_out: []f32, oi_out: []f32) void {
        c.vDSP_DFT_Execute(self.setup, ir.ptr, ii.ptr, or_out.ptr, oi_out.ptr);
    }
};

/// Real-to-complex DFT (split complex, double-precision)
pub const RealDFTD = struct {
    setup: DFTSetupD,

    pub fn init(length: Length, direction: Direction) ?RealDFTD {
        return .{ .setup = c.vDSP_DFT_zrop_CreateSetupD(null, length, @intFromEnum(direction)) orelse return null };
    }

    pub fn deinit(self: RealDFTD) void {
        c.vDSP_DFT_DestroySetupD(self.setup);
    }

    pub fn exec(self: RealDFTD, ir: []const f64, ii: []const f64, or_out: []f64, oi_out: []f64) void {
        c.vDSP_DFT_ExecuteD(self.setup, ir.ptr, ii.ptr, or_out.ptr, oi_out.ptr);
    }
};

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

/// Interleaved complex DFT (single-precision)
pub const InterleavedDFT = struct {
    setup: DFTInterleavedSetup,

    pub fn init(length: Length, direction: Direction, rtc: RealToComplex) ?InterleavedDFT {
        return .{ .setup = c.vDSP_DFT_Interleaved_CreateSetup(null, length, @intFromEnum(direction), @intFromEnum(rtc)) orelse return null };
    }

    pub fn deinit(self: InterleavedDFT) void {
        c.vDSP_DFT_Interleaved_DestroySetup(self.setup);
    }

    pub fn exec(self: InterleavedDFT, input: []const Complex, output: []Complex) void {
        c.vDSP_DFT_Interleaved_Execute(self.setup, input.ptr, output.ptr);
    }
};

/// Interleaved complex DFT (double-precision)
pub const InterleavedDFTD = struct {
    setup: DFTInterleavedSetupD,

    pub fn init(length: Length, direction: Direction, rtc: RealToComplex) ?InterleavedDFTD {
        return .{ .setup = c.vDSP_DFT_Interleaved_CreateSetupD(null, length, @intFromEnum(direction), @intFromEnum(rtc)) orelse return null };
    }

    pub fn deinit(self: InterleavedDFTD) void {
        c.vDSP_DFT_Interleaved_DestroySetupD(self.setup);
    }

    pub fn exec(self: InterleavedDFTD, input: []const DoubleComplex, output: []DoubleComplex) void {
        c.vDSP_DFT_Interleaved_ExecuteD(self.setup, input.ptr, output.ptr);
    }
};
