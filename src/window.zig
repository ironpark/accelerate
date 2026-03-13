const types = @import("types.zig");
const Length = types.Length;
const WindowFlag = types.WindowFlag;

const c = struct {
    extern fn vDSP_blkman_window(C: [*]f32, N: Length, Flag: c_int) void;
    extern fn vDSP_blkman_windowD(C: [*]f64, N: Length, Flag: c_int) void;
    extern fn vDSP_hamm_window(C: [*]f32, N: Length, Flag: c_int) void;
    extern fn vDSP_hamm_windowD(C: [*]f64, N: Length, Flag: c_int) void;
    extern fn vDSP_hann_window(C: [*]f32, N: Length, Flag: c_int) void;
    extern fn vDSP_hann_windowD(C: [*]f64, N: Length, Flag: c_int) void;
};

pub fn blkman_window(out: []f32, flag: WindowFlag) void {
    c.vDSP_blkman_window(out.ptr, out.len, @intFromEnum(flag));
}
pub fn blkman_windowD(out: []f64, flag: WindowFlag) void {
    c.vDSP_blkman_windowD(out.ptr, out.len, @intFromEnum(flag));
}

pub fn hamm_window(out: []f32, flag: WindowFlag) void {
    c.vDSP_hamm_window(out.ptr, out.len, @intFromEnum(flag));
}
pub fn hamm_windowD(out: []f64, flag: WindowFlag) void {
    c.vDSP_hamm_windowD(out.ptr, out.len, @intFromEnum(flag));
}

pub fn hann_window(out: []f32, flag: WindowFlag) void {
    c.vDSP_hann_window(out.ptr, out.len, @intFromEnum(flag));
}
pub fn hann_windowD(out: []f64, flag: WindowFlag) void {
    c.vDSP_hann_windowD(out.ptr, out.len, @intFromEnum(flag));
}
