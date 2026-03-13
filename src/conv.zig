const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;

const c = struct {
    extern fn vDSP_conv(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_convD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_imgfir(A: [*]const f32, NR: Length, NC: Length, B: [*]const f32, C: [*]f32, M: Length, N: Length) void;
    extern fn vDSP_imgfirD(A: [*]const f64, NR: Length, NC: Length, B: [*]const f64, C: [*]f64, M: Length, N: Length) void;
    extern fn vDSP_f3x3(A: [*]const f32, NR: Length, NC: Length, B: [*]const f32, C: [*]f32) void;
    extern fn vDSP_f3x3D(A: [*]const f64, NR: Length, NC: Length, B: [*]const f64, C: [*]f64) void;
    extern fn vDSP_f5x5(A: [*]const f32, NR: Length, NC: Length, B: [*]const f32, C: [*]f32) void;
    extern fn vDSP_f5x5D(A: [*]const f64, NR: Length, NC: Length, B: [*]const f64, C: [*]f64) void;
    extern fn vDSP_deq22(A: [*]const f32, IA: Stride, B: [*]const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_deq22D(A: [*]const f64, IA: Stride, B: [*]const f64, C: [*]f64, IC: Stride, N: Length) void;
};

pub fn conv(signal: []const f32, filter: []const f32, out: []f32) void {
    c.vDSP_conv(signal.ptr, 1, filter.ptr, 1, out.ptr, 1, out.len, filter.len);
}
pub fn convD(signal: []const f64, filter: []const f64, out: []f64) void {
    c.vDSP_convD(signal.ptr, 1, filter.ptr, 1, out.ptr, 1, out.len, filter.len);
}

pub fn imgfir(image: [*]const f32, rows: Length, cols: Length, kernel: [*]const f32, out: [*]f32, kr: Length, kc: Length) void {
    c.vDSP_imgfir(image, rows, cols, kernel, out, kr, kc);
}
pub fn imgfirD(image: [*]const f64, rows: Length, cols: Length, kernel: [*]const f64, out: [*]f64, kr: Length, kc: Length) void {
    c.vDSP_imgfirD(image, rows, cols, kernel, out, kr, kc);
}

pub fn f3x3(image: [*]const f32, rows: Length, cols: Length, kernel: *const [9]f32, out: [*]f32) void {
    c.vDSP_f3x3(image, rows, cols, kernel, out);
}
pub fn f3x3D(image: [*]const f64, rows: Length, cols: Length, kernel: *const [9]f64, out: [*]f64) void {
    c.vDSP_f3x3D(image, rows, cols, kernel, out);
}

pub fn f5x5(image: [*]const f32, rows: Length, cols: Length, kernel: *const [25]f32, out: [*]f32) void {
    c.vDSP_f5x5(image, rows, cols, kernel, out);
}
pub fn f5x5D(image: [*]const f64, rows: Length, cols: Length, kernel: *const [25]f64, out: [*]f64) void {
    c.vDSP_f5x5D(image, rows, cols, kernel, out);
}

pub fn deq22(a: []const f32, coeffs: *const [5]f32, out: []f32) void {
    c.vDSP_deq22(a.ptr, 1, coeffs, out.ptr, 1, out.len);
}
pub fn deq22D(a: []const f64, coeffs: *const [5]f64, out: []f64) void {
    c.vDSP_deq22D(a.ptr, 1, coeffs, out.ptr, 1, out.len);
}
