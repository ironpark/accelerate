const std = @import("std");
const types = @import("types.zig");
const Length = types.Length;
const c = @import("c.zig");

const SC = types.SplitComplex;

pub fn dotpr(comptime T: type, a: []const T, b: []const T) T {
    var result: T = undefined;
    switch (T) {
        f32 => c.vDSP_dotpr(a.ptr, 1, b.ptr, 1, &result, a.len),
        f64 => c.vDSP_dotprD(a.ptr, 1, b.ptr, 1, &result, a.len),
        else => @compileError("dotpr requires f32 or f64"),
    }
    return result;
}

/// vDSP_dotpr2/vDSP_dotpr2D, vector stereo dot product.
///
/// This routine calculates the dot product of A0 with B and the dot
/// product of A1 with B.  This is functionally equivalent to calculating
/// two dot products but might execute faster.
///
/// In pseudocode, the operation is:
///
///     sum0 = 0;
///     sum1 = 0;
///     for (i = 0; i < Length; ++i)
///     {
///         sum0 += A0[i*A0Stride] * B[i*BStride];
///         sum1 += A1[i*A1Stride] * B[i*BStride];
///     }
///     *C0 = sum0;
///     *C1 = sum1;
pub fn dotpr2(comptime T: type, a0: []const T, a1: []const T, b: []const T) [2]T {
    var c0: T = undefined;
    var c1: T = undefined;
    switch (T) {
        f32 => c.vDSP_dotpr2(a0.ptr, 1, a1.ptr, 1, b.ptr, 1, &c0, &c1, a0.len),
        f64 => c.vDSP_dotpr2D(a0.ptr, 1, a1.ptr, 1, b.ptr, 1, &c0, &c1, a0.len),
        else => @compileError("dotpr2 requires f32 or f64"),
    }
    return .{ c0, c1 };
}

pub fn zdotpr(comptime T: type, a: *const SC(T), b: *const SC(T), n: Length) SC(T) {
    var result: SC(T) = undefined;
    switch (T) {
        f32 => c.vDSP_zdotpr(a, 1, b, 1, &result, n),
        f64 => c.vDSP_zdotprD(a, 1, b, 1, &result, n),
        else => @compileError("zdotpr requires f32 or f64"),
    }
    return result;
}

pub fn zidotpr(comptime T: type, a: *const SC(T), b: *const SC(T), n: Length) SC(T) {
    var result: SC(T) = undefined;
    switch (T) {
        f32 => c.vDSP_zidotpr(a, 1, b, 1, &result, n),
        f64 => c.vDSP_zidotprD(a, 1, b, 1, &result, n),
        else => @compileError("zidotpr requires f32 or f64"),
    }
    return result;
}

pub fn zrdotpr(comptime T: type, a: *const SC(T), b: []const T, n: Length) SC(T) {
    var result: SC(T) = undefined;
    switch (T) {
        f32 => c.vDSP_zrdotpr(a, 1, b.ptr, 1, &result, n),
        f64 => c.vDSP_zrdotprD(a, 1, b.ptr, 1, &result, n),
        else => @compileError("zrdotpr requires f32 or f64"),
    }
    return result;
}

/// vDSP_dotpr_s1_15, vector integer 1.15 format dot product.
///
/// This routine calculates the dot product of A with B.
///
/// In pseudocode, the operation is:
///
///     sum = 0;
///     for (i = 0; i < N; ++i)
///     {
///         sum0 += A[i*AStride] * B[i*BStride];
///     }
///     *C = sum;
///
/// The elements are fixed-point numbers, each with one sign bit and 15
/// fraction bits.  Where the value of the short int is normally x, it is
/// x/32768 for the purposes of this routine.
pub fn dotpr_s1_15(a: []const i16, b: []const i16) i16 {
    var result: i16 = undefined;
    c.vDSP_dotpr_s1_15(a.ptr, 1, b.ptr, 1, &result, a.len);
    return result;
}

/// vDSP_dotpr2_s1_15, vector integer 1.15 format stereo dot product.
///
/// This routine calculates the dot product of A0 with B and the dot
/// product of A1 with B.  This is functionally equivalent to calculating
/// two dot products but might execute faster.
///
/// In pseudocode, the operation is:
///
///     sum0 = 0;
///     sum1 = 0;
///     for (i = 0; i < N; ++i)
///     {
///         sum0 += A0[i*A0Stride] * B[i*BStride];
///         sum1 += A1[i*A1Stride] * B[i*BStride];
///     }
///     *C0 = sum0;
///     *C1 = sum1;
///
/// The elements are fixed-point numbers, each with one sign bit and 15
/// fraction bits.  Where the value of the short int is normally x, it is
/// x/32768 for the purposes of this routine.
pub fn dotpr2_s1_15(a0: []const i16, a1: []const i16, b: []const i16) [2]i16 {
    var c0: i16 = undefined;
    var c1: i16 = undefined;
    c.vDSP_dotpr2_s1_15(a0.ptr, 1, a1.ptr, 1, b.ptr, 1, &c0, &c1, a0.len);
    return .{ c0, c1 };
}

/// vDSP_dotpr_s8_24, vector integer 8.24 format dot product.
///
/// This routine calculates the dot product of A with B.
///
/// In pseudocode, the operation is:
///
///     sum = 0;
///     for (i = 0; i < N; ++i)
///     {
///         sum0 += A[i*AStride] * B[i*BStride];
///     }
///     *C = sum;
///
/// The elements are fixed-point numbers, each with eight integer bits
/// (including sign) and 24 fraction bits.  Where the value of the int is
/// normally x, it is x/16777216 for the purposes of this routine.
pub fn dotpr_s8_24(a: []const i32, b: []const i32) i32 {
    var result: i32 = undefined;
    c.vDSP_dotpr_s8_24(a.ptr, 1, b.ptr, 1, &result, a.len);
    return result;
}

/// vDSP_dotpr2_s8_24, vector integer 8.24 format stereo dot product.
///
/// This routine calculates the dot product of A0 with B and the dot
/// product of A1 with B.  This is functionally equivalent to calculating
/// two dot products but might execute faster.
///
/// In pseudocode, the operation is:
///
///     sum0 = 0;
///     sum1 = 0;
///     for (i = 0; i < N; ++i)
///     {
///         sum0 += A0[i*A0Stride] * B[i*BStride];
///         sum1 += A1[i*A1Stride] * B[i*BStride];
///     }
///     *C0 = sum0;
///     *C1 = sum1;
///
/// The elements are fixed-point numbers, each with eight integer bits
/// (including sign) and 24 fraction bits.  Where the value of the int is
/// normally x, it is x/16777216 for the purposes of this routine.
pub fn dotpr2_s8_24(a0: []const i32, a1: []const i32, b: []const i32) [2]i32 {
    var c0: i32 = undefined;
    var c1: i32 = undefined;
    c.vDSP_dotpr2_s8_24(a0.ptr, 1, a1.ptr, 1, b.ptr, 1, &c0, &c1, a0.len);
    return .{ c0, c1 };
}

test "dotpr" {
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    const b = [_]f32{ 4.0, 5.0, 6.0 };
    const result = dotpr(f32, &a, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 32.0), result, 0.001);
}

test "dotpr2" {
    const a0 = [_]f32{ 1.0, 2.0, 3.0 };
    const a1 = [_]f32{ 4.0, 5.0, 6.0 };
    const b = [_]f32{ 1.0, 1.0, 1.0 };
    const result = dotpr2(f32, &a0, &a1, &b);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), result[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), result[1], 0.001);
}
