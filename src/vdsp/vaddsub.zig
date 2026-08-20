const std = @import("std");
const c = @import("c.zig");

/// Vector add and subtract.
///
/// Adds vector I0 to vector I1 and leaves the result in vector O0.
/// Subtracts vector I0 from vector I1 and leaves the result in vector O1.
///
/// This routine calculates:
///
///     for (i = 0; i < N; ++i)
///     {
///         T i1 = I1[i*I1S], i0 = I0[i*I0S];
///         O0[i*O0S] = i1 + i0;
///         O1[i*O1S] = i1 - i0;
///     }
///
/// Input:
///
///     const T *I0, const T *I1, vDSP_Stride I0S, vDSP_Stride I1S.
///
///         Starting addresses of both inputs and strides for the input vectors.
///
///     T *O0, T *O1, vDSP_Stride O0S, vDSP_Stride O1S.
///
///         Starting addresses of both outputs and strides for the output vectors.
///
///     vDSP_Length Length.
///
///         Number of elements in each vector.
///
/// Output:
///
///     The results are written to O0 and O1.
///
/// In-Place Operation:
///
///     Either of O0 and/or O1 may equal I0 and/or I1, but O0 may not equal
///     O1.  Otherwise, no overlap is permitted between any of the buffers.
pub fn vaddsub(comptime T: type, in0: []const T, in1: []const T, o0: []T, o1: []T) void {
    std.debug.assert(in1.len >= in0.len);
    std.debug.assert(o0.len >= in0.len);
    std.debug.assert(o1.len >= in0.len);
    switch (T) {
        f32 => c.vDSP_vaddsub(in0.ptr, 1, in1.ptr, 1, o0.ptr, 1, o1.ptr, 1, in0.len),
        f64 => c.vDSP_vaddsubD(in0.ptr, 1, in1.ptr, 1, o0.ptr, 1, o1.ptr, 1, in0.len),
        else => @compileError("vaddsub requires f32 or f64"),
    }
}

// ============================================================================
// Tests
// ============================================================================

test "vaddsub: O0 = I1 + I0, O1 = I1 - I0 (asymmetric, order-sensitive)" {
    // vDSP.h:8083-8117: O0[i] = I1[i] + I0[i], O1[i] = I1[i] - I0[i]. Using
    // asymmetric in0/in1 makes an I0/I1-swap in the subtraction visible:
    // I1-I0 = [9, 18, 27]; the swapped I0-I1 would give [-9, -18, -27].
    const in0_f32 = [_]f32{ 1.0, 2.0, 3.0 };
    const in1_f32 = [_]f32{ 10.0, 20.0, 30.0 };
    var o0_f32: [3]f32 = undefined;
    var o1_f32: [3]f32 = undefined;
    vaddsub(f32, &in0_f32, &in1_f32, &o0_f32, &o1_f32);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 11.0, 22.0, 33.0 }, &o0_f32);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 9.0, 18.0, 27.0 }, &o1_f32);

    const in0_f64 = [_]f64{ 1.0, 2.0, 3.0 };
    const in1_f64 = [_]f64{ 10.0, 20.0, 30.0 };
    var o0_f64: [3]f64 = undefined;
    var o1_f64: [3]f64 = undefined;
    vaddsub(f64, &in0_f64, &in1_f64, &o0_f64, &o1_f64);
    try std.testing.expectEqualSlices(f64, &[_]f64{ 11.0, 22.0, 33.0 }, &o0_f64);
    try std.testing.expectEqualSlices(f64, &[_]f64{ 9.0, 18.0, 27.0 }, &o1_f64);
}
