const std = @import("std");
const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;

const c = struct {
    extern fn vDSP_sve(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
    extern fn vDSP_sveD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
    extern fn vDSP_svesq(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
    extern fn vDSP_svesqD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
    extern fn vDSP_sve_svesq(A: [*]const f32, IA: Stride, Sum: *f32, SumSq: *f32, N: Length) void;
    extern fn vDSP_sve_svesqD(A: [*]const f64, IA: Stride, Sum: *f64, SumSq: *f64, N: Length) void;
    extern fn vDSP_svemg(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
    extern fn vDSP_svemgD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
    extern fn vDSP_meanv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
    extern fn vDSP_meanvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
    extern fn vDSP_meamgv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
    extern fn vDSP_meamgvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
    extern fn vDSP_measqv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
    extern fn vDSP_measqvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
    extern fn vDSP_rmsqv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
    extern fn vDSP_rmsqvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
    extern fn vDSP_maxv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
    extern fn vDSP_maxvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
    extern fn vDSP_maxvi(A: [*]const f32, IA: Stride, C: *f32, I: *Length, N: Length) void;
    extern fn vDSP_maxviD(A: [*]const f64, IA: Stride, C: *f64, I: *Length, N: Length) void;
    extern fn vDSP_maxmgv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
    extern fn vDSP_maxmgvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
    extern fn vDSP_maxmgvi(A: [*]const f32, IA: Stride, C: *f32, I: *Length, N: Length) void;
    extern fn vDSP_maxmgviD(A: [*]const f64, IA: Stride, C: *f64, I: *Length, N: Length) void;
    extern fn vDSP_minv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
    extern fn vDSP_minvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
    extern fn vDSP_minvi(A: [*]const f32, IA: Stride, C: *f32, I: *Length, N: Length) void;
    extern fn vDSP_minviD(A: [*]const f64, IA: Stride, C: *f64, I: *Length, N: Length) void;
    extern fn vDSP_minmgv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
    extern fn vDSP_minmgvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
    extern fn vDSP_minmgvi(A: [*]const f32, IA: Stride, C: *f32, I: *Length, N: Length) void;
    extern fn vDSP_minmgviD(A: [*]const f64, IA: Stride, C: *f64, I: *Length, N: Length) void;
    extern fn vDSP_normalize(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, Mean: *f32, StdDev: *f32, N: Length) void;
    extern fn vDSP_normalizeD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, Mean: *f64, StdDev: *f64, N: Length) void;
};

const ValueIndex = struct { value: f32, index: Length };
const ValueIndexD = struct { value: f64, index: Length };
const NormResult = struct { mean: f32, std_dev: f32 };
const NormResultD = struct { mean: f64, std_dev: f64 };

// -- Sum --

pub fn sve(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_sve(a.ptr, 1, &r, a.len);
    return r;
}
pub fn sveD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_sveD(a.ptr, 1, &r, a.len);
    return r;
}

pub fn svesq(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_svesq(a.ptr, 1, &r, a.len);
    return r;
}
pub fn svesqD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_svesqD(a.ptr, 1, &r, a.len);
    return r;
}

pub fn sve_svesq(a: []const f32) struct { sum: f32, sum_sq: f32 } {
    var s: f32 = undefined;
    var sq: f32 = undefined;
    c.vDSP_sve_svesq(a.ptr, 1, &s, &sq, a.len);
    return .{ .sum = s, .sum_sq = sq };
}
pub fn sve_svesqD(a: []const f64) struct { sum: f64, sum_sq: f64 } {
    var s: f64 = undefined;
    var sq: f64 = undefined;
    c.vDSP_sve_svesqD(a.ptr, 1, &s, &sq, a.len);
    return .{ .sum = s, .sum_sq = sq };
}

pub fn svemg(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_svemg(a.ptr, 1, &r, a.len);
    return r;
}
pub fn svemgD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_svemgD(a.ptr, 1, &r, a.len);
    return r;
}

// -- Mean --

pub fn meanv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_meanv(a.ptr, 1, &r, a.len);
    return r;
}
pub fn meanvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_meanvD(a.ptr, 1, &r, a.len);
    return r;
}

pub fn meamgv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_meamgv(a.ptr, 1, &r, a.len);
    return r;
}
pub fn meamgvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_meamgvD(a.ptr, 1, &r, a.len);
    return r;
}

pub fn measqv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_measqv(a.ptr, 1, &r, a.len);
    return r;
}
pub fn measqvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_measqvD(a.ptr, 1, &r, a.len);
    return r;
}

pub fn rmsqv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_rmsqv(a.ptr, 1, &r, a.len);
    return r;
}
pub fn rmsqvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_rmsqvD(a.ptr, 1, &r, a.len);
    return r;
}

// -- Max --

pub fn maxv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_maxv(a.ptr, 1, &r, a.len);
    return r;
}
pub fn maxvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_maxvD(a.ptr, 1, &r, a.len);
    return r;
}

pub fn maxvi(a: []const f32) ValueIndex {
    var v: f32 = undefined;
    var i: Length = undefined;
    c.vDSP_maxvi(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}
pub fn maxviD(a: []const f64) ValueIndexD {
    var v: f64 = undefined;
    var i: Length = undefined;
    c.vDSP_maxviD(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}

pub fn maxmgv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_maxmgv(a.ptr, 1, &r, a.len);
    return r;
}
pub fn maxmgvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_maxmgvD(a.ptr, 1, &r, a.len);
    return r;
}

pub fn maxmgvi(a: []const f32) ValueIndex {
    var v: f32 = undefined;
    var i: Length = undefined;
    c.vDSP_maxmgvi(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}
pub fn maxmgviD(a: []const f64) ValueIndexD {
    var v: f64 = undefined;
    var i: Length = undefined;
    c.vDSP_maxmgviD(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}

// -- Min --

pub fn minv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_minv(a.ptr, 1, &r, a.len);
    return r;
}
pub fn minvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_minvD(a.ptr, 1, &r, a.len);
    return r;
}

pub fn minvi(a: []const f32) ValueIndex {
    var v: f32 = undefined;
    var i: Length = undefined;
    c.vDSP_minvi(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}
pub fn minviD(a: []const f64) ValueIndexD {
    var v: f64 = undefined;
    var i: Length = undefined;
    c.vDSP_minviD(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}

pub fn minmgv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_minmgv(a.ptr, 1, &r, a.len);
    return r;
}
pub fn minmgvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_minmgvD(a.ptr, 1, &r, a.len);
    return r;
}

pub fn minmgvi(a: []const f32) ValueIndex {
    var v: f32 = undefined;
    var i: Length = undefined;
    c.vDSP_minmgvi(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}
pub fn minmgviD(a: []const f64) ValueIndexD {
    var v: f64 = undefined;
    var i: Length = undefined;
    c.vDSP_minmgviD(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}

// -- Normalize --

pub fn normalize(a: []const f32, out: []f32) NormResult {
    var mean: f32 = undefined;
    var std_dev: f32 = undefined;
    c.vDSP_normalize(a.ptr, 1, out.ptr, 1, &mean, &std_dev, a.len);
    return .{ .mean = mean, .std_dev = std_dev };
}
pub fn normalizeD(a: []const f64, out: []f64) NormResultD {
    var mean: f64 = undefined;
    var std_dev: f64 = undefined;
    c.vDSP_normalizeD(a.ptr, 1, out.ptr, 1, &mean, &std_dev, a.len);
    return .{ .mean = mean, .std_dev = std_dev };
}

test "sve" {
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), sve(&a), 0.001);
}

test "maxv and minv" {
    const a = [_]f32{ 3.0, 1.0, 4.0, 1.0, 5.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), maxv(&a), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), minv(&a), 0.001);
}
