const std = @import("std");
const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;

const c = struct {
    extern fn vDSP_vadd(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vaddD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vaddi(A: [*]const i32, IA: Stride, B: [*]const i32, IB: Stride, C: [*]i32, IC: Stride, N: Length) void;
    extern fn vDSP_vsub(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vsubD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vmul(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vmulD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vdiv(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vdivD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vsmul(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vsmulD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vsadd(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vsaddD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vsaddi(A: [*]const i32, IA: Stride, B: *const i32, C: [*]i32, IC: Stride, N: Length) void;
    extern fn vDSP_vma(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vmaD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
    extern fn vDSP_vmsa(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: *const f32, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vmsaD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: *const f64, D: [*]f64, ID: Stride, N: Length) void;
    extern fn vDSP_vsma(A: [*]const f32, IA: Stride, B: *const f32, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vsmaD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
    extern fn vDSP_vam(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vamD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
    extern fn vDSP_vsq(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vsqD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vssq(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vssqD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vdist(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vdistD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vabs(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vabsD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vabsi(A: [*]const i32, IA: Stride, C: [*]i32, IC: Stride, N: Length) void;
    extern fn vDSP_vneg(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vnegD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vfrac(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vfracD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
};

// -- Binary vector ops --

pub fn vadd(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vadd(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vaddD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vaddD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

pub fn vsub(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vsub(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vsubD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vsubD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

pub fn vmul(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vmul(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vmulD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vmulD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

pub fn vdiv(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vdiv(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vdivD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vdivD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

// -- Scalar-vector ops --

pub fn vsmul(a: []const f32, scalar: f32, out: []f32) void {
    c.vDSP_vsmul(a.ptr, 1, &scalar, out.ptr, 1, a.len);
}
pub fn vsmulD(a: []const f64, scalar: f64, out: []f64) void {
    c.vDSP_vsmulD(a.ptr, 1, &scalar, out.ptr, 1, a.len);
}

pub fn vsadd(a: []const f32, scalar: f32, out: []f32) void {
    c.vDSP_vsadd(a.ptr, 1, &scalar, out.ptr, 1, a.len);
}
pub fn vsaddD(a: []const f64, scalar: f64, out: []f64) void {
    c.vDSP_vsaddD(a.ptr, 1, &scalar, out.ptr, 1, a.len);
}

// -- Multiply-add variants --

pub fn vma(a: []const f32, b: []const f32, addend: []const f32, out: []f32) void {
    c.vDSP_vma(a.ptr, 1, b.ptr, 1, addend.ptr, 1, out.ptr, 1, a.len);
}
pub fn vmaD(a: []const f64, b: []const f64, addend: []const f64, out: []f64) void {
    c.vDSP_vmaD(a.ptr, 1, b.ptr, 1, addend.ptr, 1, out.ptr, 1, a.len);
}

pub fn vmsa(a: []const f32, b: []const f32, scalar: f32, out: []f32) void {
    c.vDSP_vmsa(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len);
}
pub fn vmsaD(a: []const f64, b: []const f64, scalar: f64, out: []f64) void {
    c.vDSP_vmsaD(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len);
}

pub fn vsma(a: []const f32, scalar: f32, addend: []const f32, out: []f32) void {
    c.vDSP_vsma(a.ptr, 1, &scalar, addend.ptr, 1, out.ptr, 1, a.len);
}
pub fn vsmaD(a: []const f64, scalar: f64, addend: []const f64, out: []f64) void {
    c.vDSP_vsmaD(a.ptr, 1, &scalar, addend.ptr, 1, out.ptr, 1, a.len);
}

pub fn vam(a: []const f32, b: []const f32, multiplier: []const f32, out: []f32) void {
    c.vDSP_vam(a.ptr, 1, b.ptr, 1, multiplier.ptr, 1, out.ptr, 1, a.len);
}
pub fn vamD(a: []const f64, b: []const f64, multiplier: []const f64, out: []f64) void {
    c.vDSP_vamD(a.ptr, 1, b.ptr, 1, multiplier.ptr, 1, out.ptr, 1, a.len);
}

// -- Unary ops --

pub fn vsq(a: []const f32, out: []f32) void {
    c.vDSP_vsq(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vsqD(a: []const f64, out: []f64) void {
    c.vDSP_vsqD(a.ptr, 1, out.ptr, 1, a.len);
}

pub fn vssq(a: []const f32, out: []f32) void {
    c.vDSP_vssq(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vssqD(a: []const f64, out: []f64) void {
    c.vDSP_vssqD(a.ptr, 1, out.ptr, 1, a.len);
}

pub fn vabs(a: []const f32, out: []f32) void {
    c.vDSP_vabs(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vabsD(a: []const f64, out: []f64) void {
    c.vDSP_vabsD(a.ptr, 1, out.ptr, 1, a.len);
}

pub fn vneg(a: []const f32, out: []f32) void {
    c.vDSP_vneg(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vnegD(a: []const f64, out: []f64) void {
    c.vDSP_vnegD(a.ptr, 1, out.ptr, 1, a.len);
}

pub fn vfrac(a: []const f32, out: []f32) void {
    c.vDSP_vfrac(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vfracD(a: []const f64, out: []f64) void {
    c.vDSP_vfracD(a.ptr, 1, out.ptr, 1, a.len);
}

pub fn vdist(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vdist(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vdistD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vdistD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

test "vadd" {
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    const b = [_]f32{ 4.0, 5.0, 6.0 };
    var out: [3]f32 = undefined;
    vadd(&a, &b, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), out[2], 0.001);
}

test "vsmul" {
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    var out: [3]f32 = undefined;
    vsmul(&a, 2.5, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.5), out[2], 0.001);
}
