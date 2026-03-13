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
// Split-complex DFT
// ============================================================================

/// Create DFT setup for complex-to-complex (zop)
pub fn zop_create_setup(previous: ?DFTSetup, length: Length, direction: Direction) ?DFTSetup {
    return c.vDSP_DFT_zop_CreateSetup(previous, length, @intFromEnum(direction));
}
pub fn zop_create_setupD(previous: ?DFTSetupD, length: Length, direction: Direction) ?DFTSetupD {
    return c.vDSP_DFT_zop_CreateSetupD(previous, length, @intFromEnum(direction));
}

/// Create DFT setup for real-to-complex (zrop)
pub fn zrop_create_setup(previous: ?DFTSetup, length: Length, direction: Direction) ?DFTSetup {
    return c.vDSP_DFT_zrop_CreateSetup(previous, length, @intFromEnum(direction));
}
pub fn zrop_create_setupD(previous: ?DFTSetupD, length: Length, direction: Direction) ?DFTSetupD {
    return c.vDSP_DFT_zrop_CreateSetupD(previous, length, @intFromEnum(direction));
}

/// Create legacy DFT setup (use with dft_zop)
pub fn create_setup(previous: ?DFTSetup, length: Length) ?DFTSetup {
    return c.vDSP_DFT_CreateSetup(previous, length);
}

/// Destroy DFT setup
pub fn destroy_setup(setup: ?DFTSetup) void {
    c.vDSP_DFT_DestroySetup(setup);
}
pub fn destroy_setupD(setup: ?DFTSetupD) void {
    c.vDSP_DFT_DestroySetupD(setup);
}

/// Execute DFT (split complex, stride 1)
pub fn execute(setup: DFTSetup, ir: []const f32, ii: []const f32, or_out: []f32, oi_out: []f32) void {
    c.vDSP_DFT_Execute(setup, ir.ptr, ii.ptr, or_out.ptr, oi_out.ptr);
}
pub fn executeD(setup: DFTSetupD, ir: []const f64, ii: []const f64, or_out: []f64, oi_out: []f64) void {
    c.vDSP_DFT_ExecuteD(setup, ir.ptr, ii.ptr, or_out.ptr, oi_out.ptr);
}

// ============================================================================
// DCT
// ============================================================================

/// Create DCT setup (types II, III, IV)
pub fn dct_create_setup(previous: ?DFTSetup, length: Length, dct_type: DCTType) ?DFTSetup {
    return c.vDSP_DCT_CreateSetup(previous, length, @intFromEnum(dct_type));
}

/// Execute DCT
pub fn dct_execute(setup: DFTSetup, input: []const f32, output: []f32) void {
    c.vDSP_DCT_Execute(setup, input.ptr, output.ptr);
}

// ============================================================================
// Interleaved DFT
// ============================================================================

/// Create interleaved DFT setup (single-precision)
pub fn interleaved_create_setup(previous: ?DFTInterleavedSetup, length: Length, direction: Direction, rtc: RealToComplex) ?DFTInterleavedSetup {
    return c.vDSP_DFT_Interleaved_CreateSetup(previous, length, @intFromEnum(direction), @intFromEnum(rtc));
}
pub fn interleaved_create_setupD(previous: ?DFTInterleavedSetupD, length: Length, direction: Direction, rtc: RealToComplex) ?DFTInterleavedSetupD {
    return c.vDSP_DFT_Interleaved_CreateSetupD(previous, length, @intFromEnum(direction), @intFromEnum(rtc));
}

/// Execute interleaved DFT
pub fn interleaved_execute(setup: DFTInterleavedSetup, input: []const Complex, output: []Complex) void {
    c.vDSP_DFT_Interleaved_Execute(setup, input.ptr, output.ptr);
}
pub fn interleaved_executeD(setup: DFTInterleavedSetupD, input: []const DoubleComplex, output: []DoubleComplex) void {
    c.vDSP_DFT_Interleaved_ExecuteD(setup, input.ptr, output.ptr);
}

/// Destroy interleaved DFT setup
pub fn interleaved_destroy_setup(setup: ?DFTInterleavedSetup) void {
    c.vDSP_DFT_Interleaved_DestroySetup(setup);
}
pub fn interleaved_destroy_setupD(setup: ?DFTInterleavedSetupD) void {
    c.vDSP_DFT_Interleaved_DestroySetupD(setup);
}

// ============================================================================
// High-level DFT wrappers (manage setup lifetime)
// ============================================================================

/// Complex-to-complex DFT (split complex, single-precision)
pub const DFT = struct {
    setup: DFTSetup,

    pub fn init(length: Length, direction: Direction) ?DFT {
        return .{ .setup = zop_create_setup(null, length, direction) orelse return null };
    }

    pub fn initShared(previous: DFTSetup, length: Length, direction: Direction) ?DFT {
        return .{ .setup = zop_create_setup(previous, length, direction) orelse return null };
    }

    pub fn deinit(self: DFT) void {
        destroy_setup(self.setup);
    }

    pub fn exec(self: DFT, ir: []const f32, ii: []const f32, or_out: []f32, oi_out: []f32) void {
        execute(self.setup, ir, ii, or_out, oi_out);
    }
};

/// Complex-to-complex DFT (split complex, double-precision)
pub const DFTD = struct {
    setup: DFTSetupD,

    pub fn init(length: Length, direction: Direction) ?DFTD {
        return .{ .setup = zop_create_setupD(null, length, direction) orelse return null };
    }

    pub fn deinit(self: DFTD) void {
        destroy_setupD(self.setup);
    }

    pub fn exec(self: DFTD, ir: []const f64, ii: []const f64, or_out: []f64, oi_out: []f64) void {
        executeD(self.setup, ir, ii, or_out, oi_out);
    }
};

/// Real-to-complex DFT (split complex, single-precision)
pub const RealDFT = struct {
    setup: DFTSetup,

    pub fn init(length: Length, direction: Direction) ?RealDFT {
        return .{ .setup = zrop_create_setup(null, length, direction) orelse return null };
    }

    pub fn deinit(self: RealDFT) void {
        destroy_setup(self.setup);
    }

    pub fn exec(self: RealDFT, ir: []const f32, ii: []const f32, or_out: []f32, oi_out: []f32) void {
        execute(self.setup, ir, ii, or_out, oi_out);
    }
};

/// Real-to-complex DFT (split complex, double-precision)
pub const RealDFTD = struct {
    setup: DFTSetupD,

    pub fn init(length: Length, direction: Direction) ?RealDFTD {
        return .{ .setup = zrop_create_setupD(null, length, direction) orelse return null };
    }

    pub fn deinit(self: RealDFTD) void {
        destroy_setupD(self.setup);
    }

    pub fn exec(self: RealDFTD, ir: []const f64, ii: []const f64, or_out: []f64, oi_out: []f64) void {
        executeD(self.setup, ir, ii, or_out, oi_out);
    }
};

/// DCT (single-precision, type II/III/IV)
pub const DCT = struct {
    setup: DFTSetup,

    pub fn init(length: Length, dct_type: DCTType) ?DCT {
        return .{ .setup = dct_create_setup(null, length, dct_type) orelse return null };
    }

    pub fn deinit(self: DCT) void {
        destroy_setup(self.setup);
    }

    pub fn exec(self: DCT, input: []const f32, output: []f32) void {
        dct_execute(self.setup, input, output);
    }
};

/// Interleaved complex DFT (single-precision)
pub const InterleavedDFT = struct {
    setup: DFTInterleavedSetup,

    pub fn init(length: Length, direction: Direction, rtc: RealToComplex) ?InterleavedDFT {
        return .{ .setup = interleaved_create_setup(null, length, direction, rtc) orelse return null };
    }

    pub fn deinit(self: InterleavedDFT) void {
        interleaved_destroy_setup(self.setup);
    }

    pub fn exec(self: InterleavedDFT, input: []const Complex, output: []Complex) void {
        interleaved_execute(self.setup, input, output);
    }
};

/// Interleaved complex DFT (double-precision)
pub const InterleavedDFTD = struct {
    setup: DFTInterleavedSetupD,

    pub fn init(length: Length, direction: Direction, rtc: RealToComplex) ?InterleavedDFTD {
        return .{ .setup = interleaved_create_setupD(null, length, direction, rtc) orelse return null };
    }

    pub fn deinit(self: InterleavedDFTD) void {
        interleaved_destroy_setupD(self.setup);
    }

    pub fn exec(self: InterleavedDFTD, input: []const DoubleComplex, output: []DoubleComplex) void {
        interleaved_executeD(self.setup, input, output);
    }
};
