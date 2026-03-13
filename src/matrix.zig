const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;

const c = struct {
    extern fn vDSP_mmul(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, M: Length, N: Length, P: Length) void;
    extern fn vDSP_mmulD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, M: Length, N: Length, P: Length) void;
    extern fn vDSP_mtrans(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, M: Length, N: Length) void;
    extern fn vDSP_mtransD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, M: Length, N: Length) void;
};

/// C = A (M x N) * B (N x P), result is M x P
pub fn mmul(a: []const f32, b: []const f32, out: []f32, m: Length, n: Length, p: Length) void {
    c.vDSP_mmul(a.ptr, 1, b.ptr, 1, out.ptr, 1, m, n, p);
}
pub fn mmulD(a: []const f64, b: []const f64, out: []f64, m: Length, n: Length, p: Length) void {
    c.vDSP_mmulD(a.ptr, 1, b.ptr, 1, out.ptr, 1, m, n, p);
}

/// Transpose M x N matrix to N x M
pub fn mtrans(a: []const f32, out: []f32, m: Length, n: Length) void {
    c.vDSP_mtrans(a.ptr, 1, out.ptr, 1, m, n);
}
pub fn mtransD(a: []const f64, out: []f64, m: Length, n: Length) void {
    c.vDSP_mtransD(a.ptr, 1, out.ptr, 1, m, n);
}
