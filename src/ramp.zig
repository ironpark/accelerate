const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;

const c = struct {
    extern fn vDSP_vrampmul(I: [*]const f32, IS: Stride, Start: *f32, Step: *const f32, O: [*]f32, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmulD(I: [*]const f64, IS: Stride, Start: *f64, Step: *const f64, O: [*]f64, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladd(I: [*]const f32, IS: Stride, Start: *f32, Step: *const f32, O: [*]f32, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladdD(I: [*]const f64, IS: Stride, Start: *f64, Step: *const f64, O: [*]f64, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmul2(I0: [*]const f32, I1: [*]const f32, IS: Stride, Start: *f32, Step: *const f32, O0: [*]f32, O1: [*]f32, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmul2D(I0: [*]const f64, I1: [*]const f64, IS: Stride, Start: *f64, Step: *const f64, O0: [*]f64, O1: [*]f64, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladd2(I0: [*]const f32, I1: [*]const f32, IS: Stride, Start: *f32, Step: *const f32, O0: [*]f32, O1: [*]f32, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladd2D(I0: [*]const f64, I1: [*]const f64, IS: Stride, Start: *f64, Step: *const f64, O0: [*]f64, O1: [*]f64, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmul_s1_15(I: [*]const i16, IS: Stride, Start: *i16, Step: *const i16, O: [*]i16, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladd_s1_15(I: [*]const i16, IS: Stride, Start: *i16, Step: *const i16, O: [*]i16, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmul2_s1_15(I0: [*]const i16, I1: [*]const i16, IS: Stride, Start: *i16, Step: *const i16, O0: [*]i16, O1: [*]i16, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladd2_s1_15(I0: [*]const i16, I1: [*]const i16, IS: Stride, Start: *i16, Step: *const i16, O0: [*]i16, O1: [*]i16, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmul_s8_24(I: [*]const i32, IS: Stride, Start: *i32, Step: *const i32, O: [*]i32, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladd_s8_24(I: [*]const i32, IS: Stride, Start: *i32, Step: *const i32, O: [*]i32, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmul2_s8_24(I0: [*]const i32, I1: [*]const i32, IS: Stride, Start: *i32, Step: *const i32, O0: [*]i32, O1: [*]i32, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladd2_s8_24(I0: [*]const i32, I1: [*]const i32, IS: Stride, Start: *i32, Step: *const i32, O0: [*]i32, O1: [*]i32, OS: Stride, N: Length) void;
};

// -- Float ramp multiply --

/// Vector vramp and multiply.
///
/// This routine puts into O the product of I and a ramp function with initial
/// value *Start and slope *Step.  *Start is updated to continue the ramp
/// in a consecutive call.  To continue the ramp smoothly, the new value of
/// *Step includes rounding errors accumulated during the routine rather than
/// being calculated directly as *Start + N * *Step.
///
/// This routine calculates:
///
///     for (i = 0; i < N; ++i)
///     {
///         O[i*OS] = *Start * I[i*IS];
///         *Start += *Step;
///     }
///
/// Input:
///
///     const T *I, vDSP_Stride IS.
///
///         Starting address and stride for the input vector.
///
///     T *Start.
///
///         Starting value for the ramp.
///
///     const T *Step.
///
///         Value of the step for the ramp.
///
///     T *O, vDSP_Stride OS.
///
///         Starting address and stride for the output vector.
///
///     vDSP_Length Length.
///
///         Number of elements in each vector.
///
/// Output:
///
///     The results are written to O.
///
///     On return, *Start contains initial *Start + N * *Step.
pub fn vrampmul(comptime T: type, input: []const T, start: *T, step: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vrampmul(input.ptr, 1, start, &step, out.ptr, 1, input.len),
        f64 => c.vDSP_vrampmulD(input.ptr, 1, start, &step, out.ptr, 1, input.len),
        else => @compileError("vrampmul requires f32 or f64"),
    }
}

// -- Float ramp multiply and add --

/// Vector vramp, multiply and add.
///
/// This routine adds to O the product of I and a ramp function with initial
/// value *Start and slope *Step.  *Start is updated to continue the ramp in a
/// consecutive call.  To continue the ramp smoothly, the new value of *Step
/// includes rounding errors accumulated during the routine rather than being
/// calculated directly as *Start + N * *Step.
///
/// This routine calculates:
///
///     for (i = 0; i < N; ++i)
///     {
///         O[i*OS] += *Start * I[i*IS];
///         *Start += *Step;
///     }
///
/// Input:
///
///     const T *I, vDSP_Stride IS.
///
///         Starting address and stride for the input vector.
///
///     T *Start.
///
///         Starting value for the ramp.
///
///     const T *Step.
///
///         Value of the step for the ramp.
///
///     T *O, vDSP_Stride OS.
///
///         Starting address and stride for the output vector.
///
///     vDSP_Length Length.
///
///         Number of elements in each vector.
///
/// Output:
///
///     The results are added to O.
///
///     On return, *Start contains initial *Start + N * *Step.
pub fn vrampmuladd(comptime T: type, input: []const T, start: *T, step: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vrampmuladd(input.ptr, 1, start, &step, out.ptr, 1, input.len),
        f64 => c.vDSP_vrampmuladdD(input.ptr, 1, start, &step, out.ptr, 1, input.len),
        else => @compileError("vrampmuladd requires f32 or f64"),
    }
}

// -- Stereo float ramp multiply --

/// Stereo vector vramp and multiply.
///
/// This routine:
///
///     Puts into O0 the product of I0 and a ramp function with initial value
///     *Start and slope *Step.
///
///     Puts into O1 the product of I1 and a ramp function with initial value
///     *Start and slope *Step.
///
/// *Start is updated to continue the ramp in a consecutive call.  To continue
/// the ramp smoothly, the new value of *Step includes rounding errors
/// accumulated during the routine rather than being calculated directly as
/// *Start + N * *Step.
///
/// This routine calculates:
///
///     for (i = 0; i < N; ++i)
///     {
///         O0[i*OS] = *Start * I0[i*IS];
///         O1[i*OS] = *Start * I1[i*IS];
///         *Start += *Step;
///     }
///
/// Input:
///
///     const T *I0, const T *I1, vDSP_Stride IS.
///
///         Starting addresses of both inputs and stride for the input vectors.
///
///     T *Start.
///
///         Starting value for the ramp.
///
///     const T *Step.
///
///         Value of the step for the ramp.
///
///     T *O0, T *O1, vDSP_Stride OS.
///
///         Starting addresses of both outputs and stride for the output
///         vectors.
///
///     vDSP_Length Length.
///
///         Number of elements in each vector.
///
/// Output:
///
///     The results are written to O0 and O1.
///
///     On return, *Start contains initial *Start + N * *Step.
pub fn vrampmul2(comptime T: type, input_a: []const T, input_b: []const T, start: *T, step: T, out_a: []T, out_b: []T) void {
    switch (T) {
        f32 => c.vDSP_vrampmul2(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len),
        f64 => c.vDSP_vrampmul2D(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len),
        else => @compileError("vrampmul2 requires f32 or f64"),
    }
}

// -- Stereo float ramp multiply and add --

/// Stereo vector vramp, multiply and add.
///
/// This routine:
///
///     Adds to O0 the product of I0 and a ramp function with initial value
///     *Start and slope *Step.
///
///     Adds to O1 the product of I1 and a ramp function with initial value
///     *Start and slope *Step.
///
/// *Start is updated to continue the ramp in a consecutive call.  To continue
/// the ramp smoothly, the new value of *Step includes rounding errors
/// accumulated during the routine rather than being calculated directly as
/// *Start + N * *Step.
///
/// This routine calculates:
///
///     for (i = 0; i < N; ++i)
///     {
///         O0[i*OS] += *Start * I0[i*IS];
///         O1[i*OS] += *Start * I1[i*IS];
///         *Start += *Step;
///     }
///
/// Input:
///
///     const T *I0, const T *I1, vDSP_Stride IS.
///
///         Starting addresses of both inputs and stride for the input vectors.
///
///     T *Start.
///
///         Starting value for the ramp.
///
///     const T *Step.
///
///         Value of the step for the ramp.
///
///     T *O0, T *O1, vDSP_Stride OS.
///
///         Starting addresses of both outputs and stride for the output
///         vectors.
///
///     vDSP_Length Length.
///
///         Number of elements in each vector.
///
/// Output:
///
///     The results are written to O0 and O1.
///
///     On return, *Start contains initial *Start + N * *Step.
pub fn vrampmuladd2(comptime T: type, input_a: []const T, input_b: []const T, start: *T, step: T, out_a: []T, out_b: []T) void {
    switch (T) {
        f32 => c.vDSP_vrampmuladd2(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len),
        f64 => c.vDSP_vrampmuladd2D(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len),
        else => @compileError("vrampmuladd2 requires f32 or f64"),
    }
}

// -- Fixed-point s1_15 ramp multiply --

/// vDSP_vrampmul_s1_15, vector integer 1.15 format vramp and multiply.
///
/// This routine puts into O the product of I and a ramp function with initial
/// value *Start and slope *Step.  *Start is updated to continue the ramp
/// in a consecutive call.
///
/// This routine calculates:
///
///     for (i = 0; i < N; ++i)
///     {
///         O[i*OS] = *Start * I[i*IS];
///         *Start += *Step;
///     }
///
/// The elements are fixed-point numbers, each with one sign bit and 15
/// fraction bits.  Where the value of the short int is normally x, it is
/// x/32768 for the purposes of this routine.
///
/// Input:
///
///     const short int *I, vDSP_Stride IS.
///
///         Starting address and stride for the input vector.
///
///     short int *Start.
///
///         Starting value for the ramp.
///
///     const short int *Step.
///
///         Value of the step for the ramp.
///
///     short int *O, vDSP_Stride OS.
///
///         Starting address and stride for the output vector.
///
///     vDSP_Length Length.
///
///         Number of elements in each vector.
///
/// Output:
///
///     The results are written to O.
///
///     On return, *Start contains initial *Start + N * *Step.
pub fn vrampmul_s1_15(input: []const i16, start: *i16, step: i16, out: []i16) void {
    c.vDSP_vrampmul_s1_15(input.ptr, 1, start, &step, out.ptr, 1, input.len);
}

/// vDSP_vrampmuladd_s1_15, vector integer 1.15 format vramp, multiply and add.
///
/// This routine adds to O the product of I and a ramp function with initial
/// value *Start and slope *Step.  *Start is updated to continue the ramp in a
/// consecutive call.
///
/// This routine calculates:
///
///     for (i = 0; i < N; ++i)
///     {
///         O[i*OS] += *Start * I[i*IS];
///         *Start += *Step;
///     }
///
/// The elements are fixed-point numbers, each with one sign bit and 15
/// fraction bits.  Where the value of the short int is normally x, it is
/// x/32768 for the purposes of this routine.
///
/// Input:
///
///     const short int *I, vDSP_Stride IS.
///
///         Starting address and stride for the input vector.
///
///     short int *Start.
///
///         Starting value for the ramp.
///
///     const short int *Step.
///
///         Value of the step for the ramp.
///
///     short int *O, vDSP_Stride OS.
///
///         Starting address and stride for the output vector.
///
///     vDSP_Length Length.
///
///         Number of elements in each vector.
///
/// Output:
///
///     The results are added to O.
///
///     On return, *Start contains initial *Start + N * *Step.
pub fn vrampmuladd_s1_15(input: []const i16, start: *i16, step: i16, out: []i16) void {
    c.vDSP_vrampmuladd_s1_15(input.ptr, 1, start, &step, out.ptr, 1, input.len);
}

/// vDSP_vrampmul2_s1_15, stereo vector integer 1.15 format vramp and multiply.
///
/// This routine:
///
///     Puts into O0 the product of I0 and a ramp function with initial value
///     *Start and slope *Step.
///
///     Puts into O1 the product of I1 and a ramp function with initial value
///     *Start and slope *Step.
///
/// *Start is updated to continue the ramp in a consecutive call.
///
/// This routine calculates:
///
///     for (i = 0; i < N; ++i)
///     {
///         O0[i*OS] = *Start * I0[i*IS];
///         O1[i*OS] = *Start * I1[i*IS];
///         *Start += *Step;
///     }
///
/// The elements are fixed-point numbers, each with one sign bit and 15
/// fraction bits.  Where the value of the short int is normally x, it is
/// x/32768 for the purposes of this routine.
///
/// Input:
///
///     const short int *I0, const short int *I1, vDSP_Stride IS.
///
///         Starting addresses of both inputs and stride for the input vectors.
///
///     short int *Start.
///
///         Starting value for the ramp.
///
///     const short int *Step.
///
///         Value of the step for the ramp.
///
///     short int *O0, short int *O1, vDSP_Stride OS.
///
///         Starting addresses of both outputs and stride for the output
///         vectors.
///
///     vDSP_Length Length.
///
///         Number of elements in each vector.
///
/// Output:
///
///     The results are written to O0 and O1.
///
///     On return, *Start contains initial *Start + N * *Step.
pub fn vrampmul2_s1_15(input_a: []const i16, input_b: []const i16, start: *i16, step: i16, out_a: []i16, out_b: []i16) void {
    c.vDSP_vrampmul2_s1_15(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
}

/// vDSP_vrampmuladd2_s1_15, stereo vector integer 1.15 format vramp, multiply
/// and add.
///
/// This routine:
///
///     Adds to O0 the product of I0 and a ramp function with initial value
///     *Start and slope *Step.
///
///     Adds to O1 the product of I1 and a ramp function with initial value
///     *Start and slope *Step.
///
/// *Start is updated to continue the ramp in a consecutive call.
///
/// This routine calculates:
///
///     for (i = 0; i < N; ++i)
///     {
///         O0[i*OS] += *Start * I0[i*IS];
///         O1[i*OS] += *Start * I1[i*IS];
///         *Start += *Step;
///     }
///
/// The elements are fixed-point numbers, each with one sign bit and 15
/// fraction bits.  Where the value of the short int is normally x, it is
/// x/32768 for the purposes of this routine.
///
/// Input:
///
///     const short int *I0, const short int *I1, vDSP_Stride IS.
///
///         Starting addresses of both inputs and stride for the input vectors.
///
///     short int *Start.
///
///         Starting value for the ramp.
///
///     const short int *Step.
///
///         Value of the step for the ramp.
///
///     short int *O0, short int *O1, vDSP_Stride OS.
///
///         Starting addresses of both outputs and stride for the output
///         vectors.
///
///     vDSP_Length Length.
///
///         Number of elements in each vector.
///
/// Output:
///
///     The results are added to O0 and O1.
///
///     On return, *Start contains initial *Start + N * *Step.
pub fn vrampmuladd2_s1_15(input_a: []const i16, input_b: []const i16, start: *i16, step: i16, out_a: []i16, out_b: []i16) void {
    c.vDSP_vrampmuladd2_s1_15(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
}

// -- Fixed-point s8_24 ramp multiply --

/// vDSP_vrampmul_s8_24, vector integer 8.24 format vramp and multiply.
///
/// This routine puts into O the product of I and a ramp function with initial
/// value *Start and slope *Step.  *Start is updated to continue the ramp
/// in a consecutive call.
///
/// This routine calculates:
///
///     for (i = 0; i < N; ++i)
///     {
///         O[i*OS] = *Start * I[i*IS];
///         *Start += *Step;
///     }
///
/// The elements are fixed-point numbers, each with eight integer bits
/// (including sign) and 24 fraction bits.  Where the value of the int is
/// normally x, it is x/16777216 for the purposes of this routine.
///
/// Input:
///
///     const int *I, vDSP_Stride IS.
///
///         Starting address and stride for the input vector.
///
///     int *Start.
///
///         Starting value for the ramp.
///
///     const int *Step.
///
///         Value of the step for the ramp.
///
///     int *O, vDSP_Stride OS.
///
///         Starting address and stride for the output vector.
///
///     vDSP_Length Length.
///
///         Number of elements in each vector.
///
/// Output:
///
///     The results are written to O.
///
///     On return, *Start contains initial *Start + N * *Step.
pub fn vrampmul_s8_24(input: []const i32, start: *i32, step: i32, out: []i32) void {
    c.vDSP_vrampmul_s8_24(input.ptr, 1, start, &step, out.ptr, 1, input.len);
}

/// vDSP_vrampmuladd_s8_24, vector integer 8.24 format vramp, multiply and add.
///
/// This routine adds to O the product of I and a ramp function with initial
/// value *Start and slope *Step.  *Start is updated to continue the ramp in a
/// consecutive call.
///
/// This routine calculates:
///
///     for (i = 0; i < N; ++i)
///     {
///         O[i*OS] += *Start * I[i*IS];
///         *Start += *Step;
///     }
///
/// The elements are fixed-point numbers, each with eight integer bits
/// (including sign) and 24 fraction bits.  Where the value of the int is
/// normally x, it is x/16777216 for the purposes of this routine.
///
/// Input:
///
///     const int *I, vDSP_Stride IS.
///
///         Starting address and stride for the input vector.
///
///     int *Start.
///
///         Starting value for the ramp.
///
///     const int *Step.
///
///         Value of the step for the ramp.
///
///     int *O, vDSP_Stride OS.
///
///         Starting address and stride for the output vector.
///
///     vDSP_Length Length.
///
///         Number of elements in each vector.
///
/// Output:
///
///     The results are added to O.
///
///     On return, *Start contains initial *Start + N * *Step.
pub fn vrampmuladd_s8_24(input: []const i32, start: *i32, step: i32, out: []i32) void {
    c.vDSP_vrampmuladd_s8_24(input.ptr, 1, start, &step, out.ptr, 1, input.len);
}

/// vDSP_vrampmul2_s8_24, stereo vector integer 8.24 format vramp and multiply.
///
/// This routine:
///
///     Puts into O0 the product of I0 and a ramp function with initial value
///     *Start and slope *Step.
///
///     Puts into O1 the product of I1 and a ramp function with initial value
///     *Start and slope *Step.
///
/// *Start is updated to continue the ramp in a consecutive call.
///
/// This routine calculates:
///
///     for (i = 0; i < N; ++i)
///     {
///         O0[i*OS] = *Start * I0[i*IS];
///         O1[i*OS] = *Start * I1[i*IS];
///         *Start += *Step;
///     }
///
/// The elements are fixed-point numbers, each with eight integer bits
/// (including sign) and 24 fraction bits.  Where the value of the int is
/// normally x, it is x/16777216 for the purposes of this routine.
///
/// Input:
///
///     const int *I0, const int *I1, vDSP_Stride IS.
///
///         Starting addresses of both inputs and stride for the input vectors.
///
///     int *Start.
///
///         Starting value for the ramp.
///
///     const int *Step.
///
///         Value of the step for the ramp.
///
///     int *O0, int *O1, vDSP_Stride OS.
///
///         Starting addresses of both outputs and stride for the output
///         vectors.
///
///     vDSP_Length Length.
///
///         Number of elements in each vector.
///
/// Output:
///
///     The results are written to O0 and O1.
///
///     On return, *Start contains initial *Start + N * *Step.
pub fn vrampmul2_s8_24(input_a: []const i32, input_b: []const i32, start: *i32, step: i32, out_a: []i32, out_b: []i32) void {
    c.vDSP_vrampmul2_s8_24(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
}

/// vDSP_vrampmuladd2_s8_24, stereo vector integer 8.24 format vramp, multiply
/// and add.
///
/// This routine:
///
///     Adds to O0 the product of I0 and a ramp function with initial value
///     *Start and slope *Step.
///
///     Adds to O1 the product of I1 and a ramp function with initial value
///     *Start and slope *Step.
///
/// *Start is updated to continue the ramp in a consecutive call.
///
/// This routine calculates:
///
///     for (i = 0; i < N; ++i)
///     {
///         O0[i*OS] += *Start * I0[i*IS];
///         O1[i*OS] += *Start * I1[i*IS];
///         *Start += *Step;
///     }
///
/// The elements are fixed-point numbers, each with eight integer bits
/// (including sign) and 24 fraction bits.  Where the value of the int is
/// normally x, it is x/16777216 for the purposes of this routine.
///
/// Input:
///
///     const int *I0, const int *I1, vDSP_Stride IS.
///
///         Starting addresses of both inputs and stride for the input vectors.
///
///     int *Start.
///
///         Starting value for the ramp.
///
///     const int *Step.
///
///         Value of the step for the ramp.
///
///     int *O0, int *O1, vDSP_Stride OS.
///
///         Starting addresses of both outputs and stride for the output
///         vectors.
///
///     vDSP_Length Length.
///
///         Number of elements in each vector.
///
/// Output:
///
///     The results are written to O0 and O1.
///
///     On return, *Start contains initial *Start + N * *Step.
pub fn vrampmuladd2_s8_24(input_a: []const i32, input_b: []const i32, start: *i32, step: i32, out_a: []i32, out_b: []i32) void {
    c.vDSP_vrampmuladd2_s8_24(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
}
