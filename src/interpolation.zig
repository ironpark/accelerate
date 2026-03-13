const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;

const c = struct {
    extern fn vDSP_vgenp(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_vgenpD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_vlint(A: [*]const f32, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_vlintD(A: [*]const f64, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_vqint(A: [*]const f32, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_vqintD(A: [*]const f64, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_vintb(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: *const f32, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vintbD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: *const f64, D: [*]f64, ID: Stride, N: Length) void;
    extern fn vDSP_vpoly(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, P: Length) void;
    extern fn vDSP_vpolyD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, P: Length) void;
};

/// Linear interpolation from table using fractional indices
pub fn vlint(table: []const f32, indices: []const f32, out: []f32) void {
    c.vDSP_vlint(table.ptr, indices.ptr, 1, out.ptr, 1, out.len, table.len);
}
pub fn vlintD(table: []const f64, indices: []const f64, out: []f64) void {
    c.vDSP_vlintD(table.ptr, indices.ptr, 1, out.ptr, 1, out.len, table.len);
}

/// Quadratic interpolation from table using fractional indices
pub fn vqint(table: []const f32, indices: []const f32, out: []f32) void {
    c.vDSP_vqint(table.ptr, indices.ptr, 1, out.ptr, 1, out.len, table.len);
}
pub fn vqintD(table: []const f64, indices: []const f64, out: []f64) void {
    c.vDSP_vqintD(table.ptr, indices.ptr, 1, out.ptr, 1, out.len, table.len);
}

/// Interpolation between two vectors: D = A + t*(B-A)
pub fn vintb(a: []const f32, b: []const f32, t: f32, out: []f32) void {
    c.vDSP_vintb(a.ptr, 1, b.ptr, 1, &t, out.ptr, 1, a.len);
}
pub fn vintbD(a: []const f64, b: []const f64, t: f64, out: []f64) void {
    c.vDSP_vintbD(a.ptr, 1, b.ptr, 1, &t, out.ptr, 1, a.len);
}

/// Generate by extrapolation and interpolation
pub fn vgenp(values: []const f32, positions: []const f32, out: []f32) void {
    c.vDSP_vgenp(values.ptr, 1, positions.ptr, 1, out.ptr, 1, out.len, values.len);
}
pub fn vgenpD(values: []const f64, positions: []const f64, out: []f64) void {
    c.vDSP_vgenpD(values.ptr, 1, positions.ptr, 1, out.ptr, 1, out.len, values.len);
}

/// Evaluate polynomial: coefficients A, evaluation points B, results C
pub fn vpoly(coeffs: []const f32, points: []const f32, out: []f32) void {
    c.vDSP_vpoly(coeffs.ptr, 1, points.ptr, 1, out.ptr, 1, points.len, coeffs.len - 1);
}
pub fn vpolyD(coeffs: []const f64, points: []const f64, out: []f64) void {
    c.vDSP_vpolyD(coeffs.ptr, 1, points.ptr, 1, out.ptr, 1, points.len, coeffs.len - 1);
}
