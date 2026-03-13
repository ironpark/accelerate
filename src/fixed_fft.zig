const fft = @import("fft.zig");
const Direction = fft.Direction;

const c = struct {
    extern fn vDSP_FFT16_copv(Output: [*]f32, Input: [*]const f32, Direction: c_int) void;
    extern fn vDSP_FFT32_copv(Output: [*]f32, Input: [*]const f32, Direction: c_int) void;
    extern fn vDSP_FFT16_zopv(Or: [*]f32, Oi: [*]f32, Ir: [*]const f32, Ii: [*]const f32, Direction: c_int) void;
    extern fn vDSP_FFT32_zopv(Or: [*]f32, Oi: [*]f32, Ir: [*]const f32, Ii: [*]const f32, Direction: c_int) void;
};

// -- 16-element interleaved complex FFT --

pub fn fft16_copv(output: *[32]f32, input: *const [32]f32, direction: Direction) void {
    c.vDSP_FFT16_copv(output, input, @intFromEnum(direction));
}

// -- 32-element interleaved complex FFT --

pub fn fft32_copv(output: *[64]f32, input: *const [64]f32, direction: Direction) void {
    c.vDSP_FFT32_copv(output, input, @intFromEnum(direction));
}

// -- 16-element split complex FFT --

pub fn fft16_zopv(out_real: *[16]f32, out_imag: *[16]f32, in_real: *const [16]f32, in_imag: *const [16]f32, direction: Direction) void {
    c.vDSP_FFT16_zopv(out_real, out_imag, in_real, in_imag, @intFromEnum(direction));
}

// -- 32-element split complex FFT --

pub fn fft32_zopv(out_real: *[32]f32, out_imag: *[32]f32, in_real: *const [32]f32, in_imag: *const [32]f32, direction: Direction) void {
    c.vDSP_FFT32_zopv(out_real, out_imag, in_real, in_imag, @intFromEnum(direction));
}
