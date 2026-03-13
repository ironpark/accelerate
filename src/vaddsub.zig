const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;

const c = struct {
    extern fn vDSP_vaddsub(I0: [*]const f32, I0S: Stride, I1: [*]const f32, I1S: Stride, O0: [*]f32, O0S: Stride, O1: [*]f32, O1S: Stride, N: Length) void;
    extern fn vDSP_vaddsubD(I0: [*]const f64, I0S: Stride, I1: [*]const f64, I1S: Stride, O0: [*]f64, O0S: Stride, O1: [*]f64, O1S: Stride, N: Length) void;
};

/// O0[n] = I1[n] + I0[n], O1[n] = I1[n] - I0[n]
pub fn vaddsub(in0: []const f32, in1: []const f32, o0: []f32, o1: []f32) void {
    c.vDSP_vaddsub(in0.ptr, 1, in1.ptr, 1, o0.ptr, 1, o1.ptr, 1, in0.len);
}
pub fn vaddsubD(in0: []const f64, in1: []const f64, o0: []f64, o1: []f64) void {
    c.vDSP_vaddsubD(in0.ptr, 1, in1.ptr, 1, o0.ptr, 1, o1.ptr, 1, in0.len);
}
