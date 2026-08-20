const std = @import("std");
const types = @import("types.zig");
const Length = types.Length;
const DbFlag = types.DbFlag;
const c = @import("c.zig");

const Int24 = types.Int24;
const UInt24 = types.UInt24;

// -- Float precision conversion --

/// Vector double-precision to single-precision conversion.
pub fn vdpsp(a: []const f64, out: []f32) void {
    std.debug.assert(out.len >= a.len);
    c.vDSP_vdpsp(a.ptr, 1, out.ptr, 1, a.len);
}
/// Vector single-precision to double-precision conversion.
pub fn vspdp(a: []const f32, out: []f64) void {
    std.debug.assert(out.len >= a.len);
    c.vDSP_vspdp(a.ptr, 1, out.ptr, 1, a.len);
}

// -- Int to float --

/// Vector convert to floating-point from integer.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vflt8(comptime T: type, a: []const i8, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vflt8(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vflt8D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vflt8 requires f32 or f64"),
    }
}
/// Vector convert to floating-point from integer.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vflt16(comptime T: type, a: []const i16, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vflt16(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vflt16D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vflt16 requires f32 or f64"),
    }
}
/// Vector convert to floating-point from integer.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vflt32(comptime T: type, a: []const i32, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vflt32(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vflt32D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vflt32 requires f32 or f64"),
    }
}
/// Vector convert to floating-point from unsigned integer.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vfltu8(comptime T: type, a: []const u8, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfltu8(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfltu8D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfltu8 requires f32 or f64"),
    }
}
/// Vector convert to floating-point from unsigned integer.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vfltu16(comptime T: type, a: []const u16, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfltu16(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfltu16D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfltu16 requires f32 or f64"),
    }
}
/// Vector convert to floating-point from unsigned integer.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vfltu32(comptime T: type, a: []const u32, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfltu32(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfltu32D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfltu32 requires f32 or f64"),
    }
}

// -- 24-bit int to float --

/// Vector convert 24-bit integer to single-precision float.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vflt24(a: []const Int24, out: []f32) void {
    std.debug.assert(out.len >= a.len);
    c.vDSP_vflt24(a.ptr, 1, out.ptr, 1, a.len);
}
/// Vector convert 24-bit unsigned integer to single-precision float.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vfltu24(a: []const UInt24, out: []f32) void {
    std.debug.assert(out.len >= a.len);
    c.vDSP_vfltu24(a.ptr, 1, out.ptr, 1, a.len);
}

// -- 24-bit int to float with scale --

/// Vector convert 24-bit integer to single-precision float and scale.
///
///     for (n = 0; n < N; ++n)
///         C[n] = B[0] * (float)A[n];
pub fn vfltsm24(a: []const Int24, scale: f32, out: []f32) void {
    std.debug.assert(out.len >= a.len);
    c.vDSP_vfltsm24(a.ptr, 1, &scale, out.ptr, 1, a.len);
}
/// Vector convert 24-bit unsigned integer to single-precision float and scale.
///
///     for (n = 0; n < N; ++n)
///         C[n] = B[0] * (float)A[n];
pub fn vfltsmu24(a: []const UInt24, scale: f32, out: []f32) void {
    std.debug.assert(out.len >= a.len);
    c.vDSP_vfltsmu24(a.ptr, 1, &scale, out.ptr, 1, a.len);
}

// -- Float to 24-bit int with scale --

/// Vector convert single precision to 24-bit signed integer with pre-scaling.
/// The scaled value is rounded toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n] * B[0]);
///
/// Note: Values outside the representable range are clamped to the largest
/// or smallest representable values of the destination type.
pub fn vsmfix24(a: []const f32, scale: f32, out: []Int24) void {
    std.debug.assert(out.len >= a.len);
    c.vDSP_vsmfix24(a.ptr, 1, &scale, out.ptr, 1, a.len);
}
/// Vector convert single precision to 24-bit unsigned integer with pre-scaling.
/// The scaled value is rounded toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n] * B[0]);
///
/// Note: Values outside the representable range are clamped to the largest
/// or smallest representable values of the destination type.
pub fn vsmfixu24(a: []const f32, scale: f32, out: []UInt24) void {
    std.debug.assert(out.len >= a.len);
    c.vDSP_vsmfixu24(a.ptr, 1, &scale, out.ptr, 1, a.len);
}

// -- Float to int (truncate toward zero) --

/// Vector convert to integer, round toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n]);
pub fn vfix8(comptime T: type, a: []const T, out: []i8) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfix8(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfix8D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfix8 requires f32 or f64"),
    }
}
/// Vector convert to integer, round toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n]);
pub fn vfix16(comptime T: type, a: []const T, out: []i16) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfix16(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfix16D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfix16 requires f32 or f64"),
    }
}
/// Vector convert to integer, round toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n]);
pub fn vfix32(comptime T: type, a: []const T, out: []i32) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfix32(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfix32D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfix32 requires f32 or f64"),
    }
}

// -- Float to unsigned int (truncate toward zero) --

/// Vector convert to unsigned integer, round toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n]);
pub fn vfixu8(comptime T: type, a: []const T, out: []u8) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfixu8(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixu8D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixu8 requires f32 or f64"),
    }
}
/// Vector convert to unsigned integer, round toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n]);
pub fn vfixu16(comptime T: type, a: []const T, out: []u16) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfixu16(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixu16D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixu16 requires f32 or f64"),
    }
}
/// Vector convert to unsigned integer, round toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n]);
pub fn vfixu32(comptime T: type, a: []const T, out: []u32) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfixu32(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixu32D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixu32 requires f32 or f64"),
    }
}

// -- Float to int (round to nearest) --

/// Vector convert to integer, round to nearest.
///
///     for (n = 0; n < N; ++n)
///         C[n] = rint(A[n]);
///
/// Note: It is expected that the global rounding mode be the default,
/// round-to-nearest. It is unspecified whether ties round up or down.
pub fn vfixr8(comptime T: type, a: []const T, out: []i8) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfixr8(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixr8D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixr8 requires f32 or f64"),
    }
}
/// Vector convert to integer, round to nearest.
///
///     for (n = 0; n < N; ++n)
///         C[n] = rint(A[n]);
///
/// Note: It is expected that the global rounding mode be the default,
/// round-to-nearest. It is unspecified whether ties round up or down.
pub fn vfixr16(comptime T: type, a: []const T, out: []i16) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfixr16(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixr16D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixr16 requires f32 or f64"),
    }
}
/// Vector convert to integer, round to nearest.
///
///     for (n = 0; n < N; ++n)
///         C[n] = rint(A[n]);
///
/// Note: It is expected that the global rounding mode be the default,
/// round-to-nearest. It is unspecified whether ties round up or down.
pub fn vfixr32(comptime T: type, a: []const T, out: []i32) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfixr32(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixr32D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixr32 requires f32 or f64"),
    }
}

// -- Float to unsigned int (round to nearest) --

/// Vector convert to unsigned integer, round to nearest.
///
///     for (n = 0; n < N; ++n)
///         C[n] = rint(A[n]);
///
/// Note: It is expected that the global rounding mode be the default,
/// round-to-nearest. It is unspecified whether ties round up or down.
pub fn vfixru8(comptime T: type, a: []const T, out: []u8) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfixru8(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixru8D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixru8 requires f32 or f64"),
    }
}
/// Vector convert to unsigned integer, round to nearest.
///
///     for (n = 0; n < N; ++n)
///         C[n] = rint(A[n]);
///
/// Note: It is expected that the global rounding mode be the default,
/// round-to-nearest. It is unspecified whether ties round up or down.
pub fn vfixru16(comptime T: type, a: []const T, out: []u16) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfixru16(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixru16D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixru16 requires f32 or f64"),
    }
}
/// Vector convert to unsigned integer, round to nearest.
///
///     for (n = 0; n < N; ++n)
///         C[n] = rint(A[n]);
///
/// Note: It is expected that the global rounding mode be the default,
/// round-to-nearest. It is unspecified whether ties round up or down.
pub fn vfixru32(comptime T: type, a: []const T, out: []u32) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfixru32(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixru32D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixru32 requires f32 or f64"),
    }
}

// -- Vector envelope --

/// Vector envelope.
///
///     for (n = 0; n < N; ++n)
///     {
///         if (C[n] < B[n] || A[n] < C[n]) D[n] = C[n];
///         else D[n] = 0;
///     }
pub fn venvlp(comptime T: type, a: []const T, b: []const T, cv: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(cv.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_venvlp(a.ptr, 1, b.ptr, 1, cv.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_venvlpD(a.ptr, 1, b.ptr, 1, cv.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("venvlp requires f32 or f64"),
    }
}

// -- Decibel conversion --

/// Vector convert to decibels, power, or amplitude.
///
///     If Flag is 1:
///         alpha = 20;
///     If Flag is 0:
///         alpha = 10;
///
///     for (n = 0; n < N; ++n)
///         C[n] = alpha * log10(A[n] / B[0]);
pub fn vdbcon(comptime T: type, a: []const T, zero_ref: T, flag: DbFlag, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vdbcon(a.ptr, 1, &zero_ref, out.ptr, 1, a.len, @intFromEnum(flag)),
        f64 => c.vDSP_vdbconD(a.ptr, 1, &zero_ref, out.ptr, 1, a.len, @intFromEnum(flag)),
        else => @compileError("vdbcon requires f32 or f64"),
    }
}

// -- Polar / Rect (interleaved pairs) --

pub fn polar(comptime T: type, rect_pairs: []const T, out: []T) void {
    std.debug.assert(out.len >= rect_pairs.len);
    switch (T) {
        f32 => c.vDSP_polar(rect_pairs.ptr, 2, out.ptr, 2, rect_pairs.len / 2),
        f64 => c.vDSP_polarD(rect_pairs.ptr, 2, out.ptr, 2, rect_pairs.len / 2),
        else => @compileError("polar requires f32 or f64"),
    }
}

pub fn rect(comptime T: type, polar_pairs: []const T, out: []T) void {
    std.debug.assert(out.len >= polar_pairs.len);
    switch (T) {
        f32 => c.vDSP_rect(polar_pairs.ptr, 2, out.ptr, 2, polar_pairs.len / 2),
        f64 => c.vDSP_rectD(polar_pairs.ptr, 2, out.ptr, 2, polar_pairs.len / 2),
        else => @compileError("rect requires f32 or f64"),
    }
}

// ============================================================================
// Tests
// ============================================================================

test "vdpsp" {
    const a = [_]f64{ 1.5, -2.25, 3.0 };
    var out: [3]f32 = undefined;
    vdpsp(&a, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 1.5), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -2.25), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), out[2], 0.001);
}

test "vspdp" {
    const a = [_]f32{ 1.5, -2.25, 3.0 };
    var out: [3]f64 = undefined;
    vspdp(&a, &out);
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), out[0], 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, -2.25), out[1], 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, 3.0), out[2], 1e-9);
}

test "vflt16" {
    const a = [_]i16{ -32768, 0, 12345 };
    var out: [3]f32 = undefined;
    vflt16(f32, &a, &out);
    try std.testing.expectApproxEqAbs(@as(f32, -32768.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 12345.0), out[2], 0.001);
}

test "vflt8" {
    const a = [_]i8{ -128, 0, 100 };
    var out: [3]f32 = undefined;
    vflt8(f32, &a, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ -128.0, 0.0, 100.0 }, &out);
}

test "vflt32" {
    const a = [_]i32{ -2147483648, 0, 100000 };
    var out: [3]f64 = undefined;
    vflt32(f64, &a, &out);
    try std.testing.expectEqualSlices(f64, &[_]f64{ -2147483648.0, 0.0, 100000.0 }, &out);
}

test "vfltu8" {
    const a = [_]u8{ 0, 128, 255 };
    var out: [3]f32 = undefined;
    vfltu8(f32, &a, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 0.0, 128.0, 255.0 }, &out);
}

test "vfltu16" {
    const a = [_]u16{ 0, 32768, 65535 };
    var out: [3]f32 = undefined;
    vfltu16(f32, &a, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 0.0, 32768.0, 65535.0 }, &out);
}

test "vfltu32" {
    const a = [_]u32{ 0, 2147483648, 4294967295 };
    var out: [3]f64 = undefined;
    vfltu32(f64, &a, &out);
    try std.testing.expectEqualSlices(f64, &[_]f64{ 0.0, 2147483648.0, 4294967295.0 }, &out);
}

test "vflt24 and vfltu24" {
    const a = [_]Int24{ Int24.from(-100), Int24.from(0), Int24.from(8388607) };
    var out: [3]f32 = undefined;
    vflt24(&a, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ -100.0, 0.0, 8388607.0 }, &out);

    const ua = [_]UInt24{ UInt24.from(0), UInt24.from(100), UInt24.from(16777215) };
    var uout: [3]f32 = undefined;
    vfltu24(&ua, &uout);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 0.0, 100.0, 16777215.0 }, &uout);
}

test "vfltsm24 and vfltsmu24" {
    const a = [_]Int24{ Int24.from(-100), Int24.from(50) };
    var out: [2]f32 = undefined;
    vfltsm24(&a, 2.0, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ -200.0, 100.0 }, &out);

    const ua = [_]UInt24{ UInt24.from(10), UInt24.from(50) };
    var uout: [2]f32 = undefined;
    vfltsmu24(&ua, 3.0, &uout);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 30.0, 150.0 }, &uout);
}

test "vsmfix24 and vsmfixu24" {
    const a = [_]f32{ -100.7, 50.2 };
    var out: [2]Int24 = undefined;
    vsmfix24(&a, 2.0, &out);
    // trunc(-100.7*2)=trunc(-201.4)=-201; trunc(50.2*2)=trunc(100.4)=100
    try std.testing.expectEqual(@as(i24, -201), out[0].to());
    try std.testing.expectEqual(@as(i24, 100), out[1].to());

    const ua = [_]f32{ 10.9, 50.2 };
    var uout: [2]UInt24 = undefined;
    vsmfixu24(&ua, 3.0, &uout);
    // trunc(10.9*3)=trunc(32.7)=32; trunc(50.2*3)=trunc(150.6)=150
    try std.testing.expectEqual(@as(u24, 32), uout[0].to());
    try std.testing.expectEqual(@as(u24, 150), uout[1].to());
}

test "vfix8, vfix16, vfix32 truncate toward zero" {
    const a = [_]f32{ 3.9, -3.9, 0.5, -0.5 };
    var out8: [4]i8 = undefined;
    vfix8(f32, &a, &out8);
    try std.testing.expectEqualSlices(i8, &[_]i8{ 3, -3, 0, 0 }, &out8);

    var out16: [4]i16 = undefined;
    vfix16(f32, &a, &out16);
    try std.testing.expectEqualSlices(i16, &[_]i16{ 3, -3, 0, 0 }, &out16);

    var out32: [4]i32 = undefined;
    vfix32(f32, &a, &out32);
    try std.testing.expectEqualSlices(i32, &[_]i32{ 3, -3, 0, 0 }, &out32);
}

test "vfixu8, vfixu16, vfixu32 truncate toward zero" {
    const a = [_]f32{ 3.9, 0.5, 200.1 };
    var out8: [3]u8 = undefined;
    vfixu8(f32, &a, &out8);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 3, 0, 200 }, &out8);

    var out16: [3]u16 = undefined;
    vfixu16(f32, &a, &out16);
    try std.testing.expectEqualSlices(u16, &[_]u16{ 3, 0, 200 }, &out16);

    var out32: [3]u32 = undefined;
    vfixu32(f32, &a, &out32);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 3, 0, 200 }, &out32);
}

test "vfixr8, vfixr16, vfixr32 round to nearest" {
    const a = [_]f32{ 3.5, -3.5, 2.4, -2.4 };
    var out8: [4]i8 = undefined;
    vfixr8(f32, &a, &out8);
    // Ties: unspecified direction per doc comment, so just check the
    // unambiguous non-tie cases and that ties round to 3 or 4 / -3 or -4.
    try std.testing.expect(out8[0] == 3 or out8[0] == 4);
    try std.testing.expect(out8[1] == -3 or out8[1] == -4);
    try std.testing.expectEqual(@as(i8, 2), out8[2]);
    try std.testing.expectEqual(@as(i8, -2), out8[3]);

    var out32: [4]i32 = undefined;
    vfixr32(f32, &a, &out32);
    try std.testing.expectEqual(@as(i32, 2), out32[2]);
    try std.testing.expectEqual(@as(i32, -2), out32[3]);
}

test "vfixru8, vfixru16, vfixru32 round to nearest" {
    const a = [_]f32{ 2.4, 2.6 };
    var out8: [2]u8 = undefined;
    vfixru8(f32, &a, &out8);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 2, 3 }, &out8);

    var out16: [2]u16 = undefined;
    vfixru16(f32, &a, &out16);
    try std.testing.expectEqualSlices(u16, &[_]u16{ 2, 3 }, &out16);

    var out32: [2]u32 = undefined;
    vfixru32(f32, &a, &out32);
    try std.testing.expectEqualSlices(u32, &[_]u32{ 2, 3 }, &out32);
}

test "venvlp" {
    // D[n] = C[n] if (C[n] < B[n] || A[n] < C[n]), else 0.
    // n0: C=5, B(lower)=10, A(upper)=20 -> C<B true -> D=5
    // n1: C=15, B=10, A=20 -> neither C<B nor A<C -> D=0
    // n2: C=25, B=10, A=20 -> A<C true -> D=25
    const a = [_]f32{ 20.0, 20.0, 20.0 };
    const b = [_]f32{ 10.0, 10.0, 10.0 };
    const cv = [_]f32{ 5.0, 15.0, 25.0 };
    var out: [3]f32 = undefined;
    venvlp(f32, &a, &b, &cv, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 5.0, 0.0, 25.0 }, &out);
}

test "vdbcon" {
    // alpha=20 (amplitude): C[n] = 20*log10(A[n]/B[0]).
    const a = [_]f32{ 10.0, 100.0 };
    var out: [2]f32 = undefined;
    vdbcon(f32, &a, 1.0, .amplitude, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), out[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 40.0), out[1], 0.01);

    // alpha=10 (power).
    var pout: [2]f32 = undefined;
    vdbcon(f32, &a, 1.0, .power, &pout);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), pout[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), pout[1], 0.01);
}

test "polar and rect round-trip" {
    // rect (x=3, y=4) -> polar (r=5, theta=atan2(4,3)).
    const rect_pairs = [_]f32{ 3.0, 4.0 };
    var polar_out: [2]f32 = undefined;
    polar(f32, &rect_pairs, &polar_out);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), polar_out[0], 0.001);
    try std.testing.expectApproxEqAbs(std.math.atan2(@as(f32, 4.0), @as(f32, 3.0)), polar_out[1], 0.001);

    var rect_out: [2]f32 = undefined;
    rect(f32, &polar_out, &rect_out);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), rect_out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), rect_out[1], 0.001);
}
