const std = @import("std");
const c = @import("c.zig");

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
pub fn vrampmul(comptime T: type, input: []const T, start: T, step: T, out: []T) T {
    std.debug.assert(out.len >= input.len);
    var s = start;
    switch (T) {
        f32 => c.vDSP_vrampmul(input.ptr, 1, &s, &step, out.ptr, 1, input.len),
        f64 => c.vDSP_vrampmulD(input.ptr, 1, &s, &step, out.ptr, 1, input.len),
        else => @compileError("vrampmul requires f32 or f64"),
    }
    return s;
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
pub fn vrampmuladd(comptime T: type, input: []const T, start: T, step: T, out: []T) T {
    std.debug.assert(out.len >= input.len);
    var s = start;
    switch (T) {
        f32 => c.vDSP_vrampmuladd(input.ptr, 1, &s, &step, out.ptr, 1, input.len),
        f64 => c.vDSP_vrampmuladdD(input.ptr, 1, &s, &step, out.ptr, 1, input.len),
        else => @compileError("vrampmuladd requires f32 or f64"),
    }
    return s;
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
pub fn vrampmul2(comptime T: type, input_a: []const T, input_b: []const T, start: T, step: T, out_a: []T, out_b: []T) T {
    std.debug.assert(input_b.len >= input_a.len);
    std.debug.assert(out_a.len >= input_a.len);
    std.debug.assert(out_b.len >= input_a.len);
    var s = start;
    switch (T) {
        f32 => c.vDSP_vrampmul2(input_a.ptr, input_b.ptr, 1, &s, &step, out_a.ptr, out_b.ptr, 1, input_a.len),
        f64 => c.vDSP_vrampmul2D(input_a.ptr, input_b.ptr, 1, &s, &step, out_a.ptr, out_b.ptr, 1, input_a.len),
        else => @compileError("vrampmul2 requires f32 or f64"),
    }
    return s;
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
pub fn vrampmuladd2(comptime T: type, input_a: []const T, input_b: []const T, start: T, step: T, out_a: []T, out_b: []T) T {
    std.debug.assert(input_b.len >= input_a.len);
    std.debug.assert(out_a.len >= input_a.len);
    std.debug.assert(out_b.len >= input_a.len);
    var s = start;
    switch (T) {
        f32 => c.vDSP_vrampmuladd2(input_a.ptr, input_b.ptr, 1, &s, &step, out_a.ptr, out_b.ptr, 1, input_a.len),
        f64 => c.vDSP_vrampmuladd2D(input_a.ptr, input_b.ptr, 1, &s, &step, out_a.ptr, out_b.ptr, 1, input_a.len),
        else => @compileError("vrampmuladd2 requires f32 or f64"),
    }
    return s;
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
pub fn vrampmul_s1_15(input: []const i16, start: i16, step: i16, out: []i16) i16 {
    std.debug.assert(out.len >= input.len);
    var s = start;
    c.vDSP_vrampmul_s1_15(input.ptr, 1, &s, &step, out.ptr, 1, input.len);
    return s;
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
pub fn vrampmuladd_s1_15(input: []const i16, start: i16, step: i16, out: []i16) i16 {
    std.debug.assert(out.len >= input.len);
    var s = start;
    c.vDSP_vrampmuladd_s1_15(input.ptr, 1, &s, &step, out.ptr, 1, input.len);
    return s;
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
pub fn vrampmul2_s1_15(input_a: []const i16, input_b: []const i16, start: i16, step: i16, out_a: []i16, out_b: []i16) i16 {
    std.debug.assert(input_b.len >= input_a.len);
    std.debug.assert(out_a.len >= input_a.len);
    std.debug.assert(out_b.len >= input_a.len);
    var s = start;
    c.vDSP_vrampmul2_s1_15(input_a.ptr, input_b.ptr, 1, &s, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
    return s;
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
pub fn vrampmuladd2_s1_15(input_a: []const i16, input_b: []const i16, start: i16, step: i16, out_a: []i16, out_b: []i16) i16 {
    std.debug.assert(input_b.len >= input_a.len);
    std.debug.assert(out_a.len >= input_a.len);
    std.debug.assert(out_b.len >= input_a.len);
    var s = start;
    c.vDSP_vrampmuladd2_s1_15(input_a.ptr, input_b.ptr, 1, &s, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
    return s;
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
pub fn vrampmul_s8_24(input: []const i32, start: i32, step: i32, out: []i32) i32 {
    std.debug.assert(out.len >= input.len);
    var s = start;
    c.vDSP_vrampmul_s8_24(input.ptr, 1, &s, &step, out.ptr, 1, input.len);
    return s;
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
pub fn vrampmuladd_s8_24(input: []const i32, start: i32, step: i32, out: []i32) i32 {
    std.debug.assert(out.len >= input.len);
    var s = start;
    c.vDSP_vrampmuladd_s8_24(input.ptr, 1, &s, &step, out.ptr, 1, input.len);
    return s;
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
pub fn vrampmul2_s8_24(input_a: []const i32, input_b: []const i32, start: i32, step: i32, out_a: []i32, out_b: []i32) i32 {
    std.debug.assert(input_b.len >= input_a.len);
    std.debug.assert(out_a.len >= input_a.len);
    std.debug.assert(out_b.len >= input_a.len);
    var s = start;
    c.vDSP_vrampmul2_s8_24(input_a.ptr, input_b.ptr, 1, &s, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
    return s;
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
pub fn vrampmuladd2_s8_24(input_a: []const i32, input_b: []const i32, start: i32, step: i32, out_a: []i32, out_b: []i32) i32 {
    std.debug.assert(input_b.len >= input_a.len);
    std.debug.assert(out_a.len >= input_a.len);
    std.debug.assert(out_b.len >= input_a.len);
    var s = start;
    c.vDSP_vrampmuladd2_s8_24(input_a.ptr, input_b.ptr, 1, &s, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
    return s;
}

test "vrampmul" {
    // Hand-computed per vDSP.h: O[i] = Start*I[i]; Start += Step (post-increment).
    const input = [_]f32{ 1, 2, 3 };
    var out: [3]f32 = undefined;
    const final_start = vrampmul(f32, &input, 10, 2, &out);
    try std.testing.expectEqual(@as(f32, 10), out[0]); // Start=10 * 1
    try std.testing.expectEqual(@as(f32, 24), out[1]); // Start=12 * 2
    try std.testing.expectEqual(@as(f32, 42), out[2]); // Start=14 * 3
    try std.testing.expectEqual(@as(f32, 16), final_start); // 10 + 3*2
}

test "vrampmuladd accumulates rather than overwrites" {
    const input = [_]f32{ 1, 2, 3 };
    var out = [_]f32{ 100, 200, 300 }; // pre-seeded, nonzero
    const final_start = vrampmuladd(f32, &input, 10, 2, &out);
    try std.testing.expectEqual(@as(f32, 110), out[0]); // 100 + 10*1
    try std.testing.expectEqual(@as(f32, 224), out[1]); // 200 + 12*2
    try std.testing.expectEqual(@as(f32, 342), out[2]); // 300 + 14*3
    try std.testing.expectEqual(@as(f32, 16), final_start);
}

test "vrampmul2 uses independent per-channel inputs and outputs, shared ramp" {
    // Different values in each channel so a channel-swap bug would be caught.
    const input_a = [_]f32{ 1, 2 };
    const input_b = [_]f32{ 10, 20 };
    var out_a: [2]f32 = undefined;
    var out_b: [2]f32 = undefined;
    const final_start = vrampmul2(f32, &input_a, &input_b, 1, 1, &out_a, &out_b);
    try std.testing.expectEqual(@as(f32, 1), out_a[0]); // Start=1 * 1
    try std.testing.expectEqual(@as(f32, 10), out_b[0]); // Start=1 * 10
    try std.testing.expectEqual(@as(f32, 4), out_a[1]); // Start=2 * 2
    try std.testing.expectEqual(@as(f32, 40), out_b[1]); // Start=2 * 20
    try std.testing.expectEqual(@as(f32, 3), final_start);
}

test "vrampmuladd2 accumulates independently per channel" {
    const input_a = [_]f32{ 1, 2 };
    const input_b = [_]f32{ 10, 20 };
    var out_a = [_]f32{ 1000, 2000 };
    var out_b = [_]f32{ -1000, -2000 };
    const final_start = vrampmuladd2(f32, &input_a, &input_b, 1, 1, &out_a, &out_b);
    try std.testing.expectEqual(@as(f32, 1001), out_a[0]); // 1000 + 1*1
    try std.testing.expectEqual(@as(f32, -990), out_b[0]); // -1000 + 1*10
    try std.testing.expectEqual(@as(f32, 2004), out_a[1]); // 2000 + 2*2
    try std.testing.expectEqual(@as(f32, -1960), out_b[1]); // -2000 + 2*20
    try std.testing.expectEqual(@as(f32, 3), final_start);
}

test "vrampmul f64" {
    const input = [_]f64{ 1, 2, 3 };
    var out: [3]f64 = undefined;
    const final_start = vrampmul(f64, &input, 10, 2, &out);
    try std.testing.expectEqual(@as(f64, 10), out[0]);
    try std.testing.expectEqual(@as(f64, 24), out[1]);
    try std.testing.expectEqual(@as(f64, 42), out[2]);
    try std.testing.expectEqual(@as(f64, 16), final_start);
}

// -- Fixed-point (Q1.15) regression tests --
//
// Q1.15 encodes real value x as round(x * 32768); e.g. 0.5 -> 16384,
// 0.25 -> 8192, 0.75 -> 24576. Confirmed against the real (hardware
// accelerated) vDSP_vrampmul_s1_15/vDSP_vrampmul2_s1_15/vDSP_dotpr_s1_15 at
// runtime, not just derived from the header text, since a wrong assumed
// fractional-bit-count would otherwise silently produce values off by a
// power of 2.

test "vrampmul_s1_15 fixed-point Q1.15 scaling" {
    // input = 0.5 (16384), start = 0.0 (0), step = 0.25 (8192).
    const input = [_]i16{ 16384, 16384, 16384 };
    var out: [3]i16 = undefined;
    const final_start = vrampmul_s1_15(&input, 0, 8192, &out);
    try std.testing.expectEqual(@as(i16, 0), out[0]); // Start=0.0 * 0.5 = 0
    try std.testing.expectEqual(@as(i16, 4096), out[1]); // Start=0.25 * 0.5 = 0.125 -> 4096
    try std.testing.expectEqual(@as(i16, 8192), out[2]); // Start=0.5 * 0.5 = 0.25 -> 8192
    try std.testing.expectEqual(@as(i16, 24576), final_start); // Start=0.75 -> 24576
}

test "vrampmuladd_s1_15 accumulates rather than overwrites" {
    const input = [_]i16{ 16384, 16384, 16384 };
    var out = [_]i16{ 100, 100, 100 }; // pre-seeded, nonzero
    const final_start = vrampmuladd_s1_15(&input, 0, 8192, &out);
    try std.testing.expectEqual(@as(i16, 100), out[0]); // 100 + 0
    try std.testing.expectEqual(@as(i16, 4196), out[1]); // 100 + 4096
    try std.testing.expectEqual(@as(i16, 8292), out[2]); // 100 + 8192
    try std.testing.expectEqual(@as(i16, 24576), final_start);
}

test "vrampmul2_s1_15 per-channel with distinct values" {
    // I0 = 0.5 (16384), I1 = 0.25 (8192); Start = 0.0, Step = 0.25 (8192).
    const input_a = [_]i16{ 16384, 16384 };
    const input_b = [_]i16{ 8192, 8192 };
    var out_a: [2]i16 = undefined;
    var out_b: [2]i16 = undefined;
    const final_start = vrampmul2_s1_15(&input_a, &input_b, 0, 8192, &out_a, &out_b);
    try std.testing.expectEqual(@as(i16, 0), out_a[0]); // 0.0*0.5
    try std.testing.expectEqual(@as(i16, 0), out_b[0]); // 0.0*0.25
    try std.testing.expectEqual(@as(i16, 4096), out_a[1]); // 0.25*0.5 = 0.125
    try std.testing.expectEqual(@as(i16, 2048), out_b[1]); // 0.25*0.25 = 0.0625
    try std.testing.expectEqual(@as(i16, 16384), final_start); // 0.5
}

test "vrampmuladd2_s1_15 accumulates independently per channel" {
    const input_a = [_]i16{ 16384, 16384 };
    const input_b = [_]i16{ 8192, 8192 };
    var out_a = [_]i16{ 500, 500 };
    var out_b = [_]i16{ -500, -500 };
    const final_start = vrampmuladd2_s1_15(&input_a, &input_b, 0, 8192, &out_a, &out_b);
    try std.testing.expectEqual(@as(i16, 500), out_a[0]); // 500 + 0
    try std.testing.expectEqual(@as(i16, -500), out_b[0]); // -500 + 0
    try std.testing.expectEqual(@as(i16, 4596), out_a[1]); // 500 + 4096
    try std.testing.expectEqual(@as(i16, 1548), out_b[1]); // -500 + 2048
    try std.testing.expectEqual(@as(i16, 16384), final_start);
}

// -- Fixed-point (Q8.24) regression tests --
//
// Q8.24 encodes real value x as round(x * 16777216); e.g. 0.5 -> 8388608,
// 0.25 -> 4194304. Runtime-confirmed the same way as the Q1.15 tests above.

test "vrampmul_s8_24 fixed-point Q8.24 scaling" {
    const input = [_]i32{ 8388608, 8388608, 8388608 }; // 0.5
    var out: [3]i32 = undefined;
    const final_start = vrampmul_s8_24(&input, 0, 4194304, &out); // step 0.25
    try std.testing.expectEqual(@as(i32, 0), out[0]);
    try std.testing.expectEqual(@as(i32, 2097152), out[1]); // 0.25*0.5=0.125
    try std.testing.expectEqual(@as(i32, 4194304), out[2]); // 0.5*0.5=0.25
    try std.testing.expectEqual(@as(i32, 12582912), final_start); // 0.75
}

test "vrampmuladd_s8_24 accumulates rather than overwrites" {
    const input = [_]i32{ 8388608, 8388608, 8388608 };
    var out = [_]i32{ 1000, 1000, 1000 };
    const final_start = vrampmuladd_s8_24(&input, 0, 4194304, &out);
    try std.testing.expectEqual(@as(i32, 1000), out[0]);
    try std.testing.expectEqual(@as(i32, 2098152), out[1]);
    try std.testing.expectEqual(@as(i32, 4195304), out[2]);
    try std.testing.expectEqual(@as(i32, 12582912), final_start);
}

test "vrampmul2_s8_24 per-channel with distinct values" {
    const input_a = [_]i32{ 8388608, 8388608 }; // 0.5
    const input_b = [_]i32{ 4194304, 4194304 }; // 0.25
    var out_a: [2]i32 = undefined;
    var out_b: [2]i32 = undefined;
    const final_start = vrampmul2_s8_24(&input_a, &input_b, 0, 4194304, &out_a, &out_b);
    try std.testing.expectEqual(@as(i32, 0), out_a[0]);
    try std.testing.expectEqual(@as(i32, 0), out_b[0]);
    try std.testing.expectEqual(@as(i32, 2097152), out_a[1]); // 0.25*0.5
    try std.testing.expectEqual(@as(i32, 1048576), out_b[1]); // 0.25*0.25
    try std.testing.expectEqual(@as(i32, 8388608), final_start); // 0.5
}

test "vrampmuladd2_s8_24 accumulates independently per channel" {
    const input_a = [_]i32{ 8388608, 8388608 };
    const input_b = [_]i32{ 4194304, 4194304 };
    var out_a = [_]i32{ 500, 500 };
    var out_b = [_]i32{ -500, -500 };
    const final_start = vrampmuladd2_s8_24(&input_a, &input_b, 0, 4194304, &out_a, &out_b);
    try std.testing.expectEqual(@as(i32, 500), out_a[0]);
    try std.testing.expectEqual(@as(i32, -500), out_b[0]);
    try std.testing.expectEqual(@as(i32, 2097652), out_a[1]);
    try std.testing.expectEqual(@as(i32, 1048076), out_b[1]);
    try std.testing.expectEqual(@as(i32, 8388608), final_start);
}
