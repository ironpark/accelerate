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
    switch (T) {
        f32 => c.vDSP_vaddsub(in0.ptr, 1, in1.ptr, 1, o0.ptr, 1, o1.ptr, 1, in0.len),
        f64 => c.vDSP_vaddsubD(in0.ptr, 1, in1.ptr, 1, o0.ptr, 1, o1.ptr, 1, in0.len),
        else => @compileError("vaddsub requires f32 or f64"),
    }
}
