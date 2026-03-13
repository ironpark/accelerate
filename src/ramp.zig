const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;

const c = struct {
    extern fn vDSP_vrampmul(I: [*]const f32, IS: Stride, Start: *f32, Step: *const f32, O: [*]f32, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmulD(I: [*]const f64, IS: Stride, Start: *f64, Step: *const f64, O: [*]f64, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladd(I: [*]const f32, IS: Stride, Start: *f32, Step: *const f32, O: [*]f32, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladdD(I: [*]const f64, IS: Stride, Start: *f64, Step: *const f64, O: [*]f64, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmul2(I0: [*]const f32, I1: [*]const f32, IS: Stride, Start: *f32, Step: *const f32, O0: [*]f32, O1: [*]f32, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmul2D(I0: [*]const f64, I1: [*]const f64, IS: Stride, Start: *f64, Step: *const f64, O0: [*]f64, O1: [*]f64, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladd2(I0: [*]const f32, I1: [*]const f32, IS: Stride, Start: *f32, Step: *const f32, O0: [*]f32, O1: [*]f32, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladd2D(I0: [*]const f64, I1: [*]const f64, IS: Stride, Start: *f64, Step: *const f64, O0: [*]f64, O1: [*]f64, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmul_s1_15(I: [*]const i16, IS: Stride, Start: *i16, Step: *const i16, O: [*]i16, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladd_s1_15(I: [*]const i16, IS: Stride, Start: *i16, Step: *const i16, O: [*]i16, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmul2_s1_15(I0: [*]const i16, I1: [*]const i16, IS: Stride, Start: *i16, Step: *const i16, O0: [*]i16, O1: [*]i16, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladd2_s1_15(I0: [*]const i16, I1: [*]const i16, IS: Stride, Start: *i16, Step: *const i16, O0: [*]i16, O1: [*]i16, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmul_s8_24(I: [*]const i32, IS: Stride, Start: *i32, Step: *const i32, O: [*]i32, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladd_s8_24(I: [*]const i32, IS: Stride, Start: *i32, Step: *const i32, O: [*]i32, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmul2_s8_24(I0: [*]const i32, I1: [*]const i32, IS: Stride, Start: *i32, Step: *const i32, O0: [*]i32, O1: [*]i32, OS: Stride, N: Length) void;
    extern fn vDSP_vrampmuladd2_s8_24(I0: [*]const i32, I1: [*]const i32, IS: Stride, Start: *i32, Step: *const i32, O0: [*]i32, O1: [*]i32, OS: Stride, N: Length) void;
};

// -- Float ramp multiply --

pub fn vrampmul(input: []const f32, start: *f32, step: f32, out: []f32) void {
    c.vDSP_vrampmul(input.ptr, 1, start, &step, out.ptr, 1, input.len);
}
pub fn vrampmulD(input: []const f64, start: *f64, step: f64, out: []f64) void {
    c.vDSP_vrampmulD(input.ptr, 1, start, &step, out.ptr, 1, input.len);
}

// -- Float ramp multiply and add --

pub fn vrampmuladd(input: []const f32, start: *f32, step: f32, out: []f32) void {
    c.vDSP_vrampmuladd(input.ptr, 1, start, &step, out.ptr, 1, input.len);
}
pub fn vrampmuladdD(input: []const f64, start: *f64, step: f64, out: []f64) void {
    c.vDSP_vrampmuladdD(input.ptr, 1, start, &step, out.ptr, 1, input.len);
}

// -- Stereo float ramp multiply --

pub fn vrampmul2(input_a: []const f32, input_b: []const f32, start: *f32, step: f32, out_a: []f32, out_b: []f32) void {
    c.vDSP_vrampmul2(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
}
pub fn vrampmul2D(input_a: []const f64, input_b: []const f64, start: *f64, step: f64, out_a: []f64, out_b: []f64) void {
    c.vDSP_vrampmul2D(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
}

// -- Stereo float ramp multiply and add --

pub fn vrampmuladd2(input_a: []const f32, input_b: []const f32, start: *f32, step: f32, out_a: []f32, out_b: []f32) void {
    c.vDSP_vrampmuladd2(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
}
pub fn vrampmuladd2D(input_a: []const f64, input_b: []const f64, start: *f64, step: f64, out_a: []f64, out_b: []f64) void {
    c.vDSP_vrampmuladd2D(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
}

// -- Fixed-point s1_15 ramp multiply --

pub fn vrampmul_s1_15(input: []const i16, start: *i16, step: i16, out: []i16) void {
    c.vDSP_vrampmul_s1_15(input.ptr, 1, start, &step, out.ptr, 1, input.len);
}
pub fn vrampmuladd_s1_15(input: []const i16, start: *i16, step: i16, out: []i16) void {
    c.vDSP_vrampmuladd_s1_15(input.ptr, 1, start, &step, out.ptr, 1, input.len);
}
pub fn vrampmul2_s1_15(input_a: []const i16, input_b: []const i16, start: *i16, step: i16, out_a: []i16, out_b: []i16) void {
    c.vDSP_vrampmul2_s1_15(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
}
pub fn vrampmuladd2_s1_15(input_a: []const i16, input_b: []const i16, start: *i16, step: i16, out_a: []i16, out_b: []i16) void {
    c.vDSP_vrampmuladd2_s1_15(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
}

// -- Fixed-point s8_24 ramp multiply --

pub fn vrampmul_s8_24(input: []const i32, start: *i32, step: i32, out: []i32) void {
    c.vDSP_vrampmul_s8_24(input.ptr, 1, start, &step, out.ptr, 1, input.len);
}
pub fn vrampmuladd_s8_24(input: []const i32, start: *i32, step: i32, out: []i32) void {
    c.vDSP_vrampmuladd_s8_24(input.ptr, 1, start, &step, out.ptr, 1, input.len);
}
pub fn vrampmul2_s8_24(input_a: []const i32, input_b: []const i32, start: *i32, step: i32, out_a: []i32, out_b: []i32) void {
    c.vDSP_vrampmul2_s8_24(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
}
pub fn vrampmuladd2_s8_24(input_a: []const i32, input_b: []const i32, start: *i32, step: i32, out_a: []i32, out_b: []i32) void {
    c.vDSP_vrampmuladd2_s8_24(input_a.ptr, input_b.ptr, 1, start, &step, out_a.ptr, out_b.ptr, 1, input_a.len);
}
