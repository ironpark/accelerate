const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;

const c = struct {
    extern fn vDSP_vrsum(A: [*]const f32, IA: Stride, S: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vrsumD(A: [*]const f64, IA: Stride, S: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vsimps(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vsimpsD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vtrapz(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vtrapzD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vswsum(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length, P: Length) void;
    extern fn vDSP_vswsumD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length, P: Length) void;
    extern fn vDSP_vswmax(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length, P: Length) void;
    extern fn vDSP_vswmaxD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length, P: Length) void;
};

pub fn vrsum(a: []const f32, scale: f32, out: []f32) void {
    c.vDSP_vrsum(a.ptr, 1, &scale, out.ptr, 1, a.len);
}
pub fn vrsumD(a: []const f64, scale: f64, out: []f64) void {
    c.vDSP_vrsumD(a.ptr, 1, &scale, out.ptr, 1, a.len);
}

pub fn vsimps(a: []const f32, step: f32, out: []f32) void {
    c.vDSP_vsimps(a.ptr, 1, &step, out.ptr, 1, a.len);
}
pub fn vsimpsD(a: []const f64, step: f64, out: []f64) void {
    c.vDSP_vsimpsD(a.ptr, 1, &step, out.ptr, 1, a.len);
}

pub fn vtrapz(a: []const f32, step: f32, out: []f32) void {
    c.vDSP_vtrapz(a.ptr, 1, &step, out.ptr, 1, a.len);
}
pub fn vtrapzD(a: []const f64, step: f64, out: []f64) void {
    c.vDSP_vtrapzD(a.ptr, 1, &step, out.ptr, 1, a.len);
}

pub fn vswsum(a: []const f32, out: []f32, window_len: Length) void {
    c.vDSP_vswsum(a.ptr, 1, out.ptr, 1, out.len, window_len);
}
pub fn vswsumD(a: []const f64, out: []f64, window_len: Length) void {
    c.vDSP_vswsumD(a.ptr, 1, out.ptr, 1, out.len, window_len);
}

pub fn vswmax(a: []const f32, out: []f32, window_len: Length) void {
    c.vDSP_vswmax(a.ptr, 1, out.ptr, 1, out.len, window_len);
}
pub fn vswmaxD(a: []const f64, out: []f64, window_len: Length) void {
    c.vDSP_vswmaxD(a.ptr, 1, out.ptr, 1, out.len, window_len);
}
