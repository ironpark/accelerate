const types = @import("types.zig");
const Length = types.Length;
const Stride = types.Stride;
const fft = @import("fft.zig");

// ============================================================================
// Types
// ============================================================================

pub const DFTSetup = *opaque {};
pub const DFTSetupD = *opaque {};
pub const DFTInterleavedSetup = *opaque {};
pub const DFTInterleavedSetupD = *opaque {};

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
// Raw C extern declarations
// ============================================================================

const c = struct {
    // -- Setup --

    /// vDSP_DFT_CreateSetup is a DFT setup routine. It creates a setup object
    /// for use with the vDSP_DFT_zop execution routine. We recommend you use
    /// vDSP_DFT_zop_CreateSetup instead of this routine.
    ///
    /// Parameters:
    ///   - Previous: Either zero or a previous DFT or DCT setup. If a previous setup is passed,
    ///     the new setup will share data with the previous setup, if feasible (and with any other
    ///     setups the previous setup shares with). If zero is passed, the routine will allocate
    ///     and initialize new memory.
    ///   - Length: The number of complex elements to be transformed.
    ///
    /// Return value: Zero is returned if memory is unavailable.
    ///
    /// The returned setup object may be used only with vDSP_DFT_zop for the length
    /// given during setup. Unlike previous vDSP FFT routines, the setup may not
    /// be used to execute transforms with shorter lengths.
    ///
    /// Do not call this routine while any DFT routine sharing setup data might be executing.
    extern fn vDSP_DFT_CreateSetup(Previous: ?DFTSetup, Length: Length) ?DFTSetup;
    /// vDSP_DFT_zop_CreateSetup is a DFT setup routine. It creates a setup object
    /// for use with the vDSP_DFT_Execute execution routine, to perform a
    /// complex-to-complex DFT.
    ///
    /// Parameters:
    ///   - Previous: Either zero or a previous DFT or DCT setup. If a previous setup is passed,
    ///     the new setup will share data with the previous setup, if feasible. If zero is passed,
    ///     the routine will allocate and initialize new memory.
    ///   - Length: The number of complex elements to be transformed.
    ///   - Direction: Transform direction, vDSP_DFT_FORWARD or vDSP_DFT_INVERSE.
    ///
    /// Return value: Zero is returned if memory is unavailable or if there is no
    /// implementation for the requested case. Currently, the implemented cases are:
    ///   - Length = 2**n.
    ///   - Length = f * 2**n, where f is 3, 5, or 15 and 3 <= n.
    ///
    /// It is recommended that array addresses (passed to vDSP_DFT_Execute) be 16-byte aligned.
    ///
    /// The returned setup object may be used only with vDSP_DFT_Execute for the length
    /// given during setup.
    ///
    /// Do not call this routine while any DFT or DCT routine sharing setup data might be executing.
    extern fn vDSP_DFT_zop_CreateSetup(Previous: ?DFTSetup, Length: Length, Direction: c_int) ?DFTSetup;
    /// vDSP_DFT_zop_CreateSetupD is a DFT setup routine (double-precision). It creates a setup
    /// object for use with the vDSP_DFT_ExecuteD execution routine, to perform a
    /// complex-to-complex DFT.
    ///
    /// Parameters:
    ///   - Previous: Either zero or a previous DFT or DCT setup. If a previous setup is passed,
    ///     the new setup will share data with the previous setup, if feasible. If zero is passed,
    ///     the routine will allocate and initialize new memory.
    ///   - Length: The number of complex elements to be transformed.
    ///   - Direction: Transform direction, vDSP_DFT_FORWARD or vDSP_DFT_INVERSE.
    ///
    /// Return value: Zero is returned if memory is unavailable or if there is no
    /// implementation for the requested case. Currently, the implemented cases are:
    ///   - Length = 2**n.
    ///   - Length = f * 2**n, where f is 3, 5, or 15 and 3 <= n.
    ///
    /// Do not call this routine while any DFT or DCT routine sharing setup data might be executing.
    extern fn vDSP_DFT_zop_CreateSetupD(Previous: ?DFTSetupD, Length: Length, Direction: c_int) ?DFTSetupD;
    /// vDSP_DFT_zrop_CreateSetup is a DFT setup routine. It creates a setup object for use with
    /// vDSP_DFT_Execute, to perform a real-to-complex DFT or a complex-to-real DFT.
    ///
    /// Parameters:
    ///   - Previous: Either zero or a previous DFT or DCT setup. If a previous setup is passed,
    ///     the new setup will share data with the previous setup, if feasible. If zero is passed,
    ///     the routine will allocate and initialize new memory.
    ///   - Length: The number of real elements to be transformed (forward) or produced (inverse).
    ///     Length must be even.
    ///   - Direction: Transform direction, vDSP_DFT_FORWARD or vDSP_DFT_INVERSE.
    ///
    /// Return value: Zero is returned if memory is unavailable or if there is no
    /// implementation for the requested case. Currently, the implemented cases are:
    ///   - Length = 2**n.
    ///   - Length = f * 2**n, where f is 3, 5, or 15 and 4 <= n.
    ///
    /// Data Layout:
    ///   If Direction is forward, input is real (even-index in Ir, odd-index in Ii),
    ///   output is complex. If Direction is inverse, layouts are swapped.
    ///
    /// In-Place Operation: Or may equal Ir and Oi may equal Ii. Otherwise, no overlap is supported.
    ///
    /// Do not call this routine while any DFT routine sharing setup data might be executing.
    extern fn vDSP_DFT_zrop_CreateSetup(Previous: ?DFTSetup, Length: Length, Direction: c_int) ?DFTSetup;
    /// vDSP_DFT_zrop_CreateSetupD is a DFT setup routine (double-precision). It creates a setup
    /// object for use with vDSP_DFT_ExecuteD, to perform a real-to-complex DFT or a
    /// complex-to-real DFT.
    ///
    /// Parameters:
    ///   - Previous: Either zero or a previous DFT or DCT setup. If a previous setup is passed,
    ///     the new setup will share data with the previous setup, if feasible. If zero is passed,
    ///     the routine will allocate and initialize new memory.
    ///   - Length: The number of real elements to be transformed (forward) or produced (inverse).
    ///     Length must be even.
    ///   - Direction: Transform direction, vDSP_DFT_FORWARD or vDSP_DFT_INVERSE.
    ///
    /// Return value: Zero is returned if memory is unavailable or if there is no
    /// implementation for the requested case. Currently, the implemented cases are:
    ///   - Length = 2**n.
    ///   - Length = f * 2**n, where f is 3, 5, or 15 and 4 <= n.
    ///
    /// Do not call this routine while any DFT routine sharing setup data might be executing.
    extern fn vDSP_DFT_zrop_CreateSetupD(Previous: ?DFTSetupD, Length: Length, Direction: c_int) ?DFTSetupD;
    /// vDSP_DCT_CreateSetup is a DCT setup routine. It creates a setup object
    /// for use with the vDSP_DCT_Execute routine.
    ///
    /// Parameters:
    ///   - Previous: Either zero or a previous DFT or DCT setup. If a previous setup is passed,
    ///     the new setup will share data with the previous setup, if feasible. If zero is passed,
    ///     the routine will allocate and initialize new memory.
    ///   - Length: The number of real elements to be transformed.
    ///   - Type: Specifies which DCT variant to perform. Supported types are II, III (mutual
    ///     inverses up to scaling), and IV (its own inverse).
    ///
    /// Return value: Zero is returned if memory is unavailable or if there is no
    /// implementation for the requested case. Currently, the implemented cases are:
    ///   - Length = f * 2**n, where f is 1, 3, 5, or 15 and 4 <= n.
    ///
    /// In-Place Operation: Output may equal Input. Otherwise, no overlap is permitted.
    ///
    /// Do not call this routine while any DFT or DCT routine sharing setup data might be executing.
    extern fn vDSP_DCT_CreateSetup(Previous: ?DFTSetup, Length: Length, Type: c_int) ?DFTSetup;

    // -- Destroy --

    /// vDSP_DFT_DestroySetup is a DFT destroy routine. It releases the memory used by a setup
    /// object.
    ///
    /// Parameters:
    ///   - Setup: The setup object to be released. The object may have been previously allocated
    ///     with any DFT or DCT setup routine, such as vDSP_DFT_zop_CreateSetup,
    ///     vDSP_DFT_zrop_CreateSetup, or vDSP_DCT_CreateSetup. Setup may be a null pointer,
    ///     in which case the call has no effect.
    ///
    /// Destroying a setup with shared data is safe; it will release only memory not needed by
    /// other undestroyed setups. Memory is freed only when all setup objects using it have been
    /// destroyed.
    ///
    /// Do not call this routine while any DFT or DCT routine sharing setup data might be executing.
    extern fn vDSP_DFT_DestroySetup(Setup: ?DFTSetup) void;
    /// vDSP_DFT_DestroySetupD is a DFT destroy routine (double-precision). It releases the memory
    /// used by a setup object.
    ///
    /// Parameters:
    ///   - Setup: The setup object to be released. The object may have been previously allocated
    ///     with any double-precision DFT or DCT setup routine. Setup may be a null pointer,
    ///     in which case the call has no effect.
    ///
    /// Destroying a setup with shared data is safe; it will release only memory not needed by
    /// other undestroyed setups.
    ///
    /// Do not call this routine while any DFT or DCT routine sharing setup data might be executing.
    extern fn vDSP_DFT_DestroySetupD(Setup: ?DFTSetupD) void;

    // -- Execute (split complex) --

    /// vDSP_DFT_Execute is a DFT execution routine. It performs a DFT, with the aid of
    /// previously created setup data.
    ///
    /// Parameters:
    ///   - Setup: A setup object returned by a previous call to vDSP_DFT_zop_CreateSetup
    ///     or vDSP_DFT_zrop_CreateSetup.
    ///   - Ir, Ii: Pointers to input data (real and imaginary components).
    ///   - Or, Oi: Pointers to output data (real and imaginary components).
    ///     The input and output arrays may not overlap except for in-place operation
    ///     (Or may equal Ir and Oi may equal Ii).
    ///
    /// The function performed is determined by the setup passed to it.
    /// When setup is from vDSP_zop_CreateSetup, each array must have Length elements.
    /// When setup is from vDSP_zrop_CreateSetup, each array must have Length/2 elements.
    ///
    /// Do not call this routine while any DFT setup or destroy routine sharing setup data
    /// might be executing.
    extern fn vDSP_DFT_Execute(Setup: DFTSetup, Ir: [*]const f32, Ii: [*]const f32, Or: [*]f32, Oi: [*]f32) void;
    /// vDSP_DFT_ExecuteD is a DFT execution routine (double-precision). It performs a DFT,
    /// with the aid of previously created setup data. Behaves the same as vDSP_DFT_Execute,
    /// with corresponding changes of types to double-precision versions.
    ///
    /// Parameters:
    ///   - Setup: A setup object returned by a previous call to vDSP_DFT_zop_CreateSetupD
    ///     or vDSP_DFT_zrop_CreateSetupD.
    ///   - Ir, Ii: Pointers to input data (real and imaginary components).
    ///   - Or, Oi: Pointers to output data (real and imaginary components).
    ///
    /// Do not call this routine while any DFT setup or destroy routine sharing setup data
    /// might be executing.
    extern fn vDSP_DFT_ExecuteD(Setup: DFTSetupD, Ir: [*]const f64, Ii: [*]const f64, Or: [*]f64, Oi: [*]f64) void;

    // -- Legacy execute with stride --

    /// vDSP_DFT_zop is a DFT execution routine. It performs a DFT, with the aid of
    /// previously created setup data.
    ///
    /// Parameters:
    ///   - Setup: A setup object returned by a previous call to vDSP_DFT_zop_CreateSetup.
    ///   - Ir, Ii: Pointers to real and imaginary components of input data.
    ///   - Is: The number of physical elements from one logical input element to the next.
    ///   - Or, Oi: Pointers to space for real and imaginary components of output data.
    ///   - Os: The number of physical elements from one logical output element to the next.
    ///   - Direction: Transform direction, vDSP_DFT_FORWARD or vDSP_DFT_INVERSE.
    ///
    /// There is no separate length parameter; the length is passed via the setup object.
    ///
    /// Performance is good when all addresses are 16-byte aligned, all strides are one,
    /// and the length is f * 2**n, where f is 3, 5, or 15 and 3 <= n.
    /// Performance is extremely slow for all other cases.
    ///
    /// In-Place Operation: For supported lengths, Or may equal Ir and Oi may equal Ii.
    /// Otherwise, no overlap is supported.
    ///
    /// Do not call this routine while any DFT setup or destroy routine sharing setup data
    /// might be executing.
    extern fn vDSP_DFT_zop(Setup: DFTSetup, Ir: [*]const f32, Ii: [*]const f32, Is: Stride, Or: [*]f32, Oi: [*]f32, Os: Stride, Direction: c_int) void;

    // -- DCT execute --

    /// vDSP_DCT_Execute is a DCT execution routine. It performs a DCT, with the
    /// aid of previously created setup data.
    ///
    /// Parameters:
    ///   - Setup: A setup object returned by a previous call to vDSP_DCT_CreateSetup.
    ///   - Input: Pointer to the input buffer.
    ///   - Output: Pointer to the output buffer.
    ///
    /// There are no separate length or type parameters; they are specified at the time
    /// the Setup is created. Because the DCT is real-to-real, the parameters differ from
    /// those used for a DFT.
    extern fn vDSP_DCT_Execute(Setup: DFTSetup, Input: [*]const f32, Output: [*]f32) void;

    // -- Interleaved setup --

    /// vDSP_DFT_Interleaved_CreateSetup is a DFT setup routine for interleaved complex data
    /// (single-precision). It creates the required butterfly weight factors needed in the
    /// computation of the interleaved complex number DFT of a specified length.
    ///
    /// Parameters:
    ///   - Previous: Either zero or a previous DFT_Interleaved setup. If a previous setup is
    ///     passed, the new setup will share data with the previous setup, if feasible. If zero
    ///     is passed, the routine will allocate and initialize new memory.
    ///   - Length: The number of complex elements to be transformed.
    ///   - Direction: Transform direction, vDSP_DFT_FORWARD or vDSP_DFT_INVERSE.
    ///   - RealToComplex: Flag for real to complex transform (ComplextoComplex or RealtoComplex).
    ///     For real-to-complex DFT, Length should be half of the length of the real signal.
    ///
    /// Return value: A pointer to the requested DFT setup on success, or 0 if the Length
    /// is not supported or having other issues such as memory allocation. Currently, the
    /// implemented cases are:
    ///   - Length = f * 2**n, where f is 2, 3, 5, 3*3, 3*5, or 5*5 and n >= 2.
    ///
    /// It is recommended that array addresses be 16-byte aligned.
    ///
    /// In-Place Operation: Ori may equal Iri. Otherwise, no overlap is supported.
    ///
    /// Do not call this routine while any DFT or DCT routine sharing setup data might be executing.
    extern fn vDSP_DFT_Interleaved_CreateSetup(Previous: ?DFTInterleavedSetup, Length: Length, Direction: c_int, RealToComplex: c_int) ?DFTInterleavedSetup;
    /// vDSP_DFT_Interleaved_CreateSetupD is a DFT setup routine for interleaved complex data
    /// (double-precision). It creates the required butterfly weight factors needed in the
    /// computation of the interleaved complex number DFT of a specified length.
    ///
    /// Parameters:
    ///   - Previous: Either zero or a previous DFT_Interleaved setup.
    ///   - Length: The number of complex elements to be transformed.
    ///   - Direction: Transform direction, vDSP_DFT_FORWARD or vDSP_DFT_INVERSE.
    ///   - RealToComplex: Flag for real to complex transform, true or false.
    ///
    /// Return value: A pointer to the requested DFT setup on success, or 0 if the Length
    /// is not supported or having other issues such as memory allocation.
    extern fn vDSP_DFT_Interleaved_CreateSetupD(Previous: ?DFTInterleavedSetupD, Length: Length, Direction: c_int, RealToComplex: c_int) ?DFTInterleavedSetupD;

    // -- Interleaved execute --

    /// vDSP_DFT_Interleaved_Execute is a DFT execution routine for interleaved complex data
    /// (single-precision). It performs a DFT, with the aid of previously created setup data.
    ///
    /// Parameters:
    ///   - Setup: A setup object returned by a previous call to vDSP_DFT_Interleaved_CreateSetup.
    ///   - Iri: Pointer to input data.
    ///   - Ori: Pointer to output data. The input and output arrays may not overlap except for
    ///     in-place operation (Ori may equal Iri).
    ///
    /// When the setup is from vDSP_DFT_Interleaved_CreateSetup, each array (Iri and Ori)
    /// must have Length elements.
    ///
    /// Do not call this routine while any DFT setup or destroy routine sharing setup data
    /// might be executing.
    extern fn vDSP_DFT_Interleaved_Execute(Setup: DFTInterleavedSetup, Iri: [*]const Complex(f32), Ori: [*]Complex(f32)) void;
    /// vDSP_DFT_Interleaved_ExecuteD is a DFT execution routine for interleaved complex data
    /// (double-precision). It performs a DFT, with the aid of previously created setup data.
    ///
    /// Parameters:
    ///   - Setup: A setup object returned by a previous call to vDSP_DFT_Interleaved_CreateSetupD.
    ///   - Iri: Pointer to input data.
    ///   - Ori: Pointer to output data.
    ///
    /// Do not call this routine while any DFT setup or destroy routine sharing setup data
    /// might be executing.
    extern fn vDSP_DFT_Interleaved_ExecuteD(Setup: DFTInterleavedSetupD, Iri: [*]const Complex(f64), Ori: [*]Complex(f64)) void;

    // -- Interleaved destroy --

    /// vDSP_DFT_Interleaved_DestroySetup is a DFT destroy routine (single-precision).
    /// It releases the memory used by a setup object.
    ///
    /// Parameters:
    ///   - Setup: A setup object vDSP_DFT_Interleaved_Setup, created by
    ///     vDSP_DFT_Interleaved_CreateSetup.
    extern fn vDSP_DFT_Interleaved_DestroySetup(Setup: ?DFTInterleavedSetup) void;
    /// vDSP_DFT_Interleaved_DestroySetupD is a DFT destroy routine (double-precision).
    /// It releases the memory used by a setup object.
    ///
    /// Parameters:
    ///   - Setup: A setup object vDSP_DFT_Interleaved_SetupD, created by
    ///     vDSP_DFT_Interleaved_CreateSetupD.
    extern fn vDSP_DFT_Interleaved_DestroySetupD(Setup: ?DFTInterleavedSetupD) void;
};

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
