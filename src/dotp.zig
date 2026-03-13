const std = @import("std");
const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;
const SplitComplex = types.SplitComplex;
const DoubleSplitComplex = types.DoubleSplitComplex;

const c = struct {
    extern fn vDSP_dotpr(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: *f32, N: Length) void;
    extern fn vDSP_dotprD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: *f64, N: Length) void;
    extern fn vDSP_dotpr2(A0: [*]const f32, IA0: Stride, A1: [*]const f32, IA1: Stride, B: [*]const f32, IB: Stride, C0: *f32, C1: *f32, N: Length) void;
    extern fn vDSP_dotpr2D(A0: [*]const f64, IA0: Stride, A1: [*]const f64, IA1: Stride, B: [*]const f64, IB: Stride, C0: *f64, C1: *f64, N: Length) void;
    extern fn vDSP_zdotpr(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *SplitComplex, N: Length) void;
    extern fn vDSP_zdotprD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *DoubleSplitComplex, N: Length) void;
    extern fn vDSP_zidotpr(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *SplitComplex, N: Length) void;
    extern fn vDSP_zidotprD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *DoubleSplitComplex, N: Length) void;
    extern fn vDSP_zrdotpr(A: *const SplitComplex, IA: Stride, B: [*]const f32, IB: Stride, C: *SplitComplex, N: Length) void;
    extern fn vDSP_zrdotprD(A: *const DoubleSplitComplex, IA: Stride, B: [*]const f64, IB: Stride, C: *DoubleSplitComplex, N: Length) void;
    extern fn vDSP_dotpr_s1_15(A: [*]const i16, IA: Stride, B: [*]const i16, IB: Stride, C: *i16, N: Length) void;
    extern fn vDSP_dotpr2_s1_15(A0: [*]const i16, IA0: Stride, A1: [*]const i16, IA1: Stride, B: [*]const i16, IB: Stride, C0: *i16, C1: *i16, N: Length) void;
    extern fn vDSP_dotpr_s8_24(A: [*]const i32, IA: Stride, B: [*]const i32, IB: Stride, C: *i32, N: Length) void;
    extern fn vDSP_dotpr2_s8_24(A0: [*]const i32, IA0: Stride, A1: [*]const i32, IA1: Stride, B: [*]const i32, IB: Stride, C0: *i32, C1: *i32, N: Length) void;
};

pub fn dotpr(a: []const f32, b: []const f32) f32 {
    var result: f32 = undefined;
    c.vDSP_dotpr(a.ptr, 1, b.ptr, 1, &result, a.len);
    return result;
}

pub fn dotprD(a: []const f64, b: []const f64) f64 {
    var result: f64 = undefined;
    c.vDSP_dotprD(a.ptr, 1, b.ptr, 1, &result, a.len);
    return result;
}

pub fn dotpr2(a0: []const f32, a1: []const f32, b: []const f32) [2]f32 {
    var c0: f32 = undefined;
    var c1: f32 = undefined;
    c.vDSP_dotpr2(a0.ptr, 1, a1.ptr, 1, b.ptr, 1, &c0, &c1, a0.len);
    return .{ c0, c1 };
}

pub fn dotpr2D(a0: []const f64, a1: []const f64, b: []const f64) [2]f64 {
    var c0: f64 = undefined;
    var c1: f64 = undefined;
    c.vDSP_dotpr2D(a0.ptr, 1, a1.ptr, 1, b.ptr, 1, &c0, &c1, a0.len);
    return .{ c0, c1 };
}

pub fn zdotpr(a: *const SplitComplex, b: *const SplitComplex, n: Length) SplitComplex {
    var result: SplitComplex = undefined;
    c.vDSP_zdotpr(a, 1, b, 1, &result, n);
    return result;
}

pub fn zdotprD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, n: Length) DoubleSplitComplex {
    var result: DoubleSplitComplex = undefined;
    c.vDSP_zdotprD(a, 1, b, 1, &result, n);
    return result;
}

pub fn zidotpr(a: *const SplitComplex, b: *const SplitComplex, n: Length) SplitComplex {
    var result: SplitComplex = undefined;
    c.vDSP_zidotpr(a, 1, b, 1, &result, n);
    return result;
}

pub fn zidotprD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, n: Length) DoubleSplitComplex {
    var result: DoubleSplitComplex = undefined;
    c.vDSP_zidotprD(a, 1, b, 1, &result, n);
    return result;
}

pub fn zrdotpr(a: *const SplitComplex, b: []const f32, n: Length) SplitComplex {
    var result: SplitComplex = undefined;
    c.vDSP_zrdotpr(a, 1, b.ptr, 1, &result, n);
    return result;
}

pub fn zrdotprD(a: *const DoubleSplitComplex, b: []const f64, n: Length) DoubleSplitComplex {
    var result: DoubleSplitComplex = undefined;
    c.vDSP_zrdotprD(a, 1, b.ptr, 1, &result, n);
    return result;
}

pub fn dotpr_s1_15(a: []const i16, b: []const i16) i16 {
    var result: i16 = undefined;
    c.vDSP_dotpr_s1_15(a.ptr, 1, b.ptr, 1, &result, a.len);
    return result;
}

pub fn dotpr2_s1_15(a0: []const i16, a1: []const i16, b: []const i16) [2]i16 {
    var c0: i16 = undefined;
    var c1: i16 = undefined;
    c.vDSP_dotpr2_s1_15(a0.ptr, 1, a1.ptr, 1, b.ptr, 1, &c0, &c1, a0.len);
    return .{ c0, c1 };
}

pub fn dotpr_s8_24(a: []const i32, b: []const i32) i32 {
    var result: i32 = undefined;
    c.vDSP_dotpr_s8_24(a.ptr, 1, b.ptr, 1, &result, a.len);
    return result;
}

pub fn dotpr2_s8_24(a0: []const i32, a1: []const i32, b: []const i32) [2]i32 {
    var c0: i32 = undefined;
    var c1: i32 = undefined;
    c.vDSP_dotpr2_s8_24(a0.ptr, 1, a1.ptr, 1, b.ptr, 1, &c0, &c1, a0.len);
    return .{ c0, c1 };
}

test "dotpr" {
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    const b = [_]f32{ 4.0, 5.0, 6.0 };
    const result = dotpr(&a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 32.0), result, 0.001);
}

test "dotpr2" {
    const a0 = [_]f32{ 1.0, 2.0, 3.0 };
    const a1 = [_]f32{ 4.0, 5.0, 6.0 };
    const b = [_]f32{ 1.0, 1.0, 1.0 };
    const result = dotpr2(&a0, &a1, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), result[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), result[1], 0.001);
}
