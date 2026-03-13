const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;
const DbFlag = types.DbFlag;

const c = struct {
    extern fn vDSP_vfixr8(A: [*]const f32, IA: Stride, C: [*]i8, IC: Stride, N: Length) void;
    extern fn vDSP_vfixr16(A: [*]const f32, IA: Stride, C: [*]i16, IC: Stride, N: Length) void;
    extern fn vDSP_vfixr32(A: [*]const f32, IA: Stride, C: [*]i32, IC: Stride, N: Length) void;
    extern fn vDSP_vflt8(A: [*]const i8, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vflt16(A: [*]const i16, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vflt32(A: [*]const i32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vfltu8(A: [*]const u8, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vfltu16(A: [*]const u16, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vfltu32(A: [*]const u32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vdpsp(A: [*]const f64, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vspdp(A: [*]const f32, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vdbcon(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length, F: c_uint) void;
    extern fn vDSP_vdbconD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length, F: c_uint) void;
    extern fn vDSP_polar(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_polarD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_rect(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_rectD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
};

// -- Float precision conversion --

pub fn vdpsp(a: []const f64, out: []f32) void {
    c.vDSP_vdpsp(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vspdp(a: []const f32, out: []f64) void {
    c.vDSP_vspdp(a.ptr, 1, out.ptr, 1, a.len);
}

// -- Int to float --

pub fn vflt8(a: []const i8, out: []f32) void {
    c.vDSP_vflt8(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vflt16(a: []const i16, out: []f32) void {
    c.vDSP_vflt16(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vflt32(a: []const i32, out: []f32) void {
    c.vDSP_vflt32(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vfltu8(a: []const u8, out: []f32) void {
    c.vDSP_vfltu8(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vfltu16(a: []const u16, out: []f32) void {
    c.vDSP_vfltu16(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vfltu32(a: []const u32, out: []f32) void {
    c.vDSP_vfltu32(a.ptr, 1, out.ptr, 1, a.len);
}

// -- Float to int --

pub fn vfixr8(a: []const f32, out: []i8) void {
    c.vDSP_vfixr8(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vfixr16(a: []const f32, out: []i16) void {
    c.vDSP_vfixr16(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vfixr32(a: []const f32, out: []i32) void {
    c.vDSP_vfixr32(a.ptr, 1, out.ptr, 1, a.len);
}

// -- Decibel conversion --

pub fn vdbcon(a: []const f32, zero_ref: f32, flag: DbFlag, out: []f32) void {
    c.vDSP_vdbcon(a.ptr, 1, &zero_ref, out.ptr, 1, a.len, @intFromEnum(flag));
}
pub fn vdbconD(a: []const f64, zero_ref: f64, flag: DbFlag, out: []f64) void {
    c.vDSP_vdbconD(a.ptr, 1, &zero_ref, out.ptr, 1, a.len, @intFromEnum(flag));
}

// -- Polar / Rect (interleaved pairs) --

pub fn polar(rect_pairs: []const f32, out: []f32) void {
    c.vDSP_polar(rect_pairs.ptr, 2, out.ptr, 2, rect_pairs.len / 2);
}
pub fn polarD(rect_pairs: []const f64, out: []f64) void {
    c.vDSP_polarD(rect_pairs.ptr, 2, out.ptr, 2, rect_pairs.len / 2);
}

pub fn rect(polar_pairs: []const f32, out: []f32) void {
    c.vDSP_rect(polar_pairs.ptr, 2, out.ptr, 2, polar_pairs.len / 2);
}
pub fn rectD(polar_pairs: []const f64, out: []f64) void {
    c.vDSP_rectD(polar_pairs.ptr, 2, out.ptr, 2, polar_pairs.len / 2);
}
