const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;
const SortOrder = types.SortOrder;

const c = struct {
    extern fn vDSP_vfill(A: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vfillD(A: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vfilli(A: *const c_int, C: [*]c_int, IC: Stride, N: Length) void;
    extern fn vDSP_vclr(C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vclrD(C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vrvrs(C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vrvrsD(C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vswap(A: [*]f32, IA: Stride, B: [*]f32, IB: Stride, N: Length) void;
    extern fn vDSP_vswapD(A: [*]f64, IA: Stride, B: [*]f64, IB: Stride, N: Length) void;
    extern fn vDSP_vsort(C: [*]f32, N: Length, Order: c_int) void;
    extern fn vDSP_vsortD(C: [*]f64, N: Length, Order: c_int) void;
    extern fn vDSP_vramp(A: *const f32, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vrampD(A: *const f64, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vgen(A: *const f32, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vgenD(A: *const f64, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vcmprs(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vcmprsD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vgathr(A: [*]const f32, B: [*]const Length, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vgathrD(A: [*]const f64, B: [*]const Length, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vindex(A: [*]const f32, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vindexD(A: [*]const f64, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
};

// -- Fill / clear --

pub fn vfill(val: f32, out: []f32) void {
    c.vDSP_vfill(&val, out.ptr, 1, out.len);
}
pub fn vfillD(val: f64, out: []f64) void {
    c.vDSP_vfillD(&val, out.ptr, 1, out.len);
}

pub fn vclr(out: []f32) void {
    c.vDSP_vclr(out.ptr, 1, out.len);
}
pub fn vclrD(out: []f64) void {
    c.vDSP_vclrD(out.ptr, 1, out.len);
}

// -- Reverse --

pub fn vrvrs(buf: []f32) void {
    c.vDSP_vrvrs(buf.ptr, 1, buf.len);
}
pub fn vrvrsD(buf: []f64) void {
    c.vDSP_vrvrsD(buf.ptr, 1, buf.len);
}

// -- Swap --

pub fn vswap(a: []f32, b: []f32) void {
    c.vDSP_vswap(a.ptr, 1, b.ptr, 1, a.len);
}
pub fn vswapD(a: []f64, b: []f64) void {
    c.vDSP_vswapD(a.ptr, 1, b.ptr, 1, a.len);
}

// -- Sort --

pub fn vsort(buf: []f32, order: SortOrder) void {
    c.vDSP_vsort(buf.ptr, buf.len, @intFromEnum(order));
}
pub fn vsortD(buf: []f64, order: SortOrder) void {
    c.vDSP_vsortD(buf.ptr, buf.len, @intFromEnum(order));
}

// -- Ramp --

pub fn vramp(start: f32, step: f32, out: []f32) void {
    c.vDSP_vramp(&start, &step, out.ptr, 1, out.len);
}
pub fn vrampD(start: f64, step: f64, out: []f64) void {
    c.vDSP_vrampD(&start, &step, out.ptr, 1, out.len);
}

pub fn vgen(start: f32, end: f32, out: []f32) void {
    c.vDSP_vgen(&start, &end, out.ptr, 1, out.len);
}
pub fn vgenD(start: f64, end: f64, out: []f64) void {
    c.vDSP_vgenD(&start, &end, out.ptr, 1, out.len);
}

// -- Compress / Gather / Index --

pub fn vcmprs(a: []const f32, gate: []const f32, out: []f32) void {
    c.vDSP_vcmprs(a.ptr, 1, gate.ptr, 1, out.ptr, 1, a.len);
}
pub fn vcmprsD(a: []const f64, gate: []const f64, out: []f64) void {
    c.vDSP_vcmprsD(a.ptr, 1, gate.ptr, 1, out.ptr, 1, a.len);
}

pub fn vgathr(table: []const f32, indices: []const Length, out: []f32) void {
    c.vDSP_vgathr(table.ptr, indices.ptr, 1, out.ptr, 1, indices.len);
}
pub fn vgathrD(table: []const f64, indices: []const Length, out: []f64) void {
    c.vDSP_vgathrD(table.ptr, indices.ptr, 1, out.ptr, 1, indices.len);
}

pub fn vindex(table: []const f32, indices: []const f32, out: []f32) void {
    c.vDSP_vindex(table.ptr, indices.ptr, 1, out.ptr, 1, indices.len);
}
pub fn vindexD(table: []const f64, indices: []const f64, out: []f64) void {
    c.vDSP_vindexD(table.ptr, indices.ptr, 1, out.ptr, 1, indices.len);
}
