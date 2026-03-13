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
    extern fn vDSP_mmov(A: [*]const f32, C: [*]f32, M: Length, N: Length, TA: Length, TC: Length) void;
    extern fn vDSP_mmovD(A: [*]const f64, C: [*]f64, M: Length, N: Length, TA: Length, TC: Length) void;
    extern fn vDSP_mvessq(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
    extern fn vDSP_mvessqD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
    extern fn vDSP_nzcros(A: [*]const f32, IA: Stride, B: Length, C: *Length, D: *Length, N: Length) void;
    extern fn vDSP_nzcrosD(A: [*]const f64, IA: Stride, B: Length, C: *Length, D: *Length, N: Length) void;
    extern fn vDSP_svdiv(A: *const f32, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_svdivD(A: *const f64, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_svs(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
    extern fn vDSP_svsD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
};

const ValueIndex = struct { value: f32, index: Length };
const ValueIndexD = struct { value: f64, index: Length };
const NormResult = struct { mean: f32, std_dev: f32 };
const NormResultD = struct { mean: f64, std_dev: f64 };

// -- Sum --

/// Sum of vector elements.
///
/// C[0] = sum(A[n], 0 <= n < N);
pub fn sve(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_sve(a.ptr, 1, &r, a.len);
    return r;
}
/// Sum of vector elements (double-precision).
///
/// C[0] = sum(A[n], 0 <= n < N);
pub fn sveD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_sveD(a.ptr, 1, &r, a.len);
    return r;
}

/// Sum of vector elements' squares.
///
/// C[0] = sum(A[n] ** 2, 0 <= n < N);
pub fn svesq(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_svesq(a.ptr, 1, &r, a.len);
    return r;
}
/// Sum of vector elements' squares (double-precision).
///
/// C[0] = sum(A[n] ** 2, 0 <= n < N);
pub fn svesqD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_svesqD(a.ptr, 1, &r, a.len);
    return r;
}

/// Sum of vector elements and sum of vector elements' squares.
///
/// Sum[0]          = sum(A[n],      0 <= n < N);
/// SumOfSquares[0] = sum(A[n] ** 2, 0 <= n < N);
pub fn sve_svesq(a: []const f32) struct { sum: f32, sum_sq: f32 } {
    var s: f32 = undefined;
    var sq: f32 = undefined;
    c.vDSP_sve_svesq(a.ptr, 1, &s, &sq, a.len);
    return .{ .sum = s, .sum_sq = sq };
}
/// Sum of vector elements and sum of vector elements' squares (double-precision).
///
/// Sum[0]          = sum(A[n],      0 <= n < N);
/// SumOfSquares[0] = sum(A[n] ** 2, 0 <= n < N);
pub fn sve_svesqD(a: []const f64) struct { sum: f64, sum_sq: f64 } {
    var s: f64 = undefined;
    var sq: f64 = undefined;
    c.vDSP_sve_svesqD(a.ptr, 1, &s, &sq, a.len);
    return .{ .sum = s, .sum_sq = sq };
}

/// Sum of vector elements magnitudes.
///
/// C[0] = sum(|A[n]|, 0 <= n < N);
pub fn svemg(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_svemg(a.ptr, 1, &r, a.len);
    return r;
}
/// Sum of vector elements magnitudes (double-precision).
///
/// C[0] = sum(|A[n]|, 0 <= n < N);
pub fn svemgD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_svemgD(a.ptr, 1, &r, a.len);
    return r;
}

// -- Mean --

/// Mean of vector.
///
/// C[0] = sum(A[n], 0 <= n < N) / N;
pub fn meanv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_meanv(a.ptr, 1, &r, a.len);
    return r;
}
/// Mean of vector (double-precision).
///
/// C[0] = sum(A[n], 0 <= n < N) / N;
pub fn meanvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_meanvD(a.ptr, 1, &r, a.len);
    return r;
}

/// Mean magnitude of vector.
///
/// C[0] = sum(|A[n]|, 0 <= n < N) / N;
pub fn meamgv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_meamgv(a.ptr, 1, &r, a.len);
    return r;
}
/// Mean magnitude of vector (double-precision).
///
/// C[0] = sum(|A[n]|, 0 <= n < N) / N;
pub fn meamgvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_meamgvD(a.ptr, 1, &r, a.len);
    return r;
}

/// Mean square of vector.
///
/// C[0] = sum(A[n]**2, 0 <= n < N) / N;
pub fn measqv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_measqv(a.ptr, 1, &r, a.len);
    return r;
}
/// Mean square of vector (double-precision).
///
/// C[0] = sum(A[n]**2, 0 <= n < N) / N;
pub fn measqvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_measqvD(a.ptr, 1, &r, a.len);
    return r;
}

/// Root-mean-square of vector.
///
/// C[0] = sqrt(sum(A[n] ** 2, 0 <= n < N) / N);
pub fn rmsqv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_rmsqv(a.ptr, 1, &r, a.len);
    return r;
}
/// Root-mean-square of vector (double-precision).
///
/// C[0] = sqrt(sum(A[n] ** 2, 0 <= n < N) / N);
pub fn rmsqvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_rmsqvD(a.ptr, 1, &r, a.len);
    return r;
}

// -- Max --

/// Maximum value of vector.
///
/// C[0] is set to the greatest value of A[n] for 0 <= n < N.
pub fn maxv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_maxv(a.ptr, 1, &r, a.len);
    return r;
}
/// Maximum value of vector (double-precision).
///
/// C[0] is set to the greatest value of A[n] for 0 <= n < N.
pub fn maxvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_maxvD(a.ptr, 1, &r, a.len);
    return r;
}

/// Maximum value of vector, with index.
///
/// C[0] is set to the greatest value of A[n] for 0 <= n < N.
/// I[0] is set to the least i*IA such that A[i] has the value in C[0].
pub fn maxvi(a: []const f32) ValueIndex {
    var v: f32 = undefined;
    var i: Length = undefined;
    c.vDSP_maxvi(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}
/// Maximum value of vector, with index (double-precision).
///
/// C[0] is set to the greatest value of A[n] for 0 <= n < N.
/// I[0] is set to the least i*IA such that A[i] has the value in C[0].
pub fn maxviD(a: []const f64) ValueIndexD {
    var v: f64 = undefined;
    var i: Length = undefined;
    c.vDSP_maxviD(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}

/// Maximum magnitude of vector.
///
/// C[0] is set to the greatest value of |A[n]| for 0 <= n < N.
pub fn maxmgv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_maxmgv(a.ptr, 1, &r, a.len);
    return r;
}
/// Maximum magnitude of vector (double-precision).
///
/// C[0] is set to the greatest value of |A[n]| for 0 <= n < N.
pub fn maxmgvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_maxmgvD(a.ptr, 1, &r, a.len);
    return r;
}

/// Maximum magnitude of vector, with index.
///
/// C[0] is set to the greatest value of |A[n]| for 0 <= n < N.
/// I[0] is set to the least i*IA such that |A[i]| has the value in C[0].
pub fn maxmgvi(a: []const f32) ValueIndex {
    var v: f32 = undefined;
    var i: Length = undefined;
    c.vDSP_maxmgvi(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}
/// Maximum magnitude of vector, with index (double-precision).
///
/// C[0] is set to the greatest value of |A[n]| for 0 <= n < N.
/// I[0] is set to the least i*IA such that |A[i]| has the value in C[0].
pub fn maxmgviD(a: []const f64) ValueIndexD {
    var v: f64 = undefined;
    var i: Length = undefined;
    c.vDSP_maxmgviD(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}

// -- Min --

/// Minimum value of vector.
///
/// C[0] is set to the least value of A[n] for 0 <= n < N.
pub fn minv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_minv(a.ptr, 1, &r, a.len);
    return r;
}
/// Minimum value of vector (double-precision).
///
/// C[0] is set to the least value of A[n] for 0 <= n < N.
pub fn minvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_minvD(a.ptr, 1, &r, a.len);
    return r;
}

/// Minimum value of vector, with index.
///
/// C[0] is set to the least value of A[n] for 0 <= n < N.
/// I[0] is set to the least i*IA such that A[i] has the value in C[0].
pub fn minvi(a: []const f32) ValueIndex {
    var v: f32 = undefined;
    var i: Length = undefined;
    c.vDSP_minvi(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}
/// Minimum value of vector, with index (double-precision).
///
/// C[0] is set to the least value of A[n] for 0 <= n < N.
/// I[0] is set to the least i*IA such that A[i] has the value in C[0].
pub fn minviD(a: []const f64) ValueIndexD {
    var v: f64 = undefined;
    var i: Length = undefined;
    c.vDSP_minviD(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}

/// Minimum magnitude of vector.
///
/// C[0] is set to the least value of |A[n]| for 0 <= n < N.
pub fn minmgv(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_minmgv(a.ptr, 1, &r, a.len);
    return r;
}
/// Minimum magnitude of vector (double-precision).
///
/// C[0] is set to the least value of |A[n]| for 0 <= n < N.
pub fn minmgvD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_minmgvD(a.ptr, 1, &r, a.len);
    return r;
}

/// Minimum magnitude of vector, with index.
///
/// C[0] is set to the least value of |A[n]| for 0 <= n < N.
/// I[0] is set to the least i*IA such that |A[i]| has the value in C[0].
pub fn minmgvi(a: []const f32) ValueIndex {
    var v: f32 = undefined;
    var i: Length = undefined;
    c.vDSP_minmgvi(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}
/// Minimum magnitude of vector, with index (double-precision).
///
/// C[0] is set to the least value of |A[n]| for 0 <= n < N.
/// I[0] is set to the least i*IA such that |A[i]| has the value in C[0].
pub fn minmgviD(a: []const f64) ValueIndexD {
    var v: f64 = undefined;
    var i: Length = undefined;
    c.vDSP_minmgviD(a.ptr, 1, &v, &i, a.len);
    return .{ .value = v, .index = i };
}

// -- Normalize --

/// Compute mean and standard deviation and then calculate new elements to have
/// a zero mean and a unit standard deviation.
///
///     m = sum(A[n], 0 <= n < N) / N;
///     d = sqrt(sum(A[n]**2, 0 <= n < N) / N - m**2);
///
///     // Normalize.
///     for (n = 0; n < N; ++n)
///         C[n] = (A[n] - m) / d;
pub fn normalize(a: []const f32, out: []f32) NormResult {
    var mean: f32 = undefined;
    var std_dev: f32 = undefined;
    c.vDSP_normalize(a.ptr, 1, out.ptr, 1, &mean, &std_dev, a.len);
    return .{ .mean = mean, .std_dev = std_dev };
}
/// Compute mean and standard deviation and then calculate new elements to have
/// a zero mean and a unit standard deviation (double-precision).
///
///     m = sum(A[n], 0 <= n < N) / N;
///     d = sqrt(sum(A[n]**2, 0 <= n < N) / N - m**2);
///
///     // Normalize.
///     for (n = 0; n < N; ++n)
///         C[n] = (A[n] - m) / d;
pub fn normalizeD(a: []const f64, out: []f64) NormResultD {
    var mean: f64 = undefined;
    var std_dev: f64 = undefined;
    c.vDSP_normalizeD(a.ptr, 1, out.ptr, 1, &mean, &std_dev, a.len);
    return .{ .mean = mean, .std_dev = std_dev };
}

// -- Matrix move --

/// Matrix move.
///
/// A is regarded as a two-dimensional matrix with dimensions [N][TA].
/// C is regarded as a two-dimensional matrix with dimensions [N][TC].
///
///     for (n = 0; n < N; ++n)
///     for (m = 0; m < M; ++m)
///         C[n][m] = A[n][m];
pub fn mmov(a: [*]const f32, out: [*]f32, cols: Length, rows: Length, ta: Length, tc: Length) void {
    c.vDSP_mmov(a, out, cols, rows, ta, tc);
}
/// Matrix move (double-precision).
///
/// A is regarded as a two-dimensional matrix with dimensions [N][TA].
/// C is regarded as a two-dimensional matrix with dimensions [N][TC].
///
///     for (n = 0; n < N; ++n)
///     for (m = 0; m < M; ++m)
///         C[n][m] = A[n][m];
pub fn mmovD(a: [*]const f64, out: [*]f64, cols: Length, rows: Length, ta: Length, tc: Length) void {
    c.vDSP_mmovD(a, out, cols, rows, ta, tc);
}

// -- Mean of signed squares --

/// Mean of signed squares of vector.
///
/// C[0] = sum(A[n] * |A[n]|, 0 <= n < N) / N;
pub fn mvessq(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_mvessq(a.ptr, 1, &r, a.len);
    return r;
}
/// Mean of signed squares of vector (double-precision).
///
/// C[0] = sum(A[n] * |A[n]|, 0 <= n < N) / N;
pub fn mvessqD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_mvessqD(a.ptr, 1, &r, a.len);
    return r;
}

// -- Zero crossings --

/// Find zero crossing.
///
/// Let S be the number of times the sign bit changes in the sequence A[0],
/// A[1],... A[N-1].
///
/// If B <= S:
///     D[0] is set to B.
///     C[0] is set to n*IA, where the B-th sign bit change occurs between
///     elements A[n-1] and A[n].
/// Else:
///     D[0] is set to S.
///     C[0] is set to 0.
pub fn nzcros(a: []const f32, b: Length) struct { crossing: Length, count: Length } {
    var crossing: Length = undefined;
    var count: Length = undefined;
    c.vDSP_nzcros(a.ptr, 1, b, &crossing, &count, a.len);
    return .{ .crossing = crossing, .count = count };
}
/// Find zero crossing (double-precision).
///
/// Let S be the number of times the sign bit changes in the sequence A[0],
/// A[1],... A[N-1].
///
/// If B <= S:
///     D[0] is set to B.
///     C[0] is set to n*IA, where the B-th sign bit change occurs between
///     elements A[n-1] and A[n].
/// Else:
///     D[0] is set to S.
///     C[0] is set to 0.
pub fn nzcrosD(a: []const f64, b: Length) struct { crossing: Length, count: Length } {
    var crossing: Length = undefined;
    var count: Length = undefined;
    c.vDSP_nzcrosD(a.ptr, 1, b, &crossing, &count, a.len);
    return .{ .crossing = crossing, .count = count };
}

// -- Scalar / vector divide --

/// Scalar-vector divide.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[0] / B[n];
///
/// When A[0] is not zero or NaN and B[n] is zero, C[n] is set to an infinity.
pub fn svdiv(scalar: f32, b: []const f32, out: []f32) void {
    c.vDSP_svdiv(&scalar, b.ptr, 1, out.ptr, 1, b.len);
}
/// Scalar-vector divide (double-precision).
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[0] / B[n];
///
/// When A[0] is not zero or NaN and B[n] is zero, C[n] is set to an infinity.
pub fn svdivD(scalar: f64, b: []const f64, out: []f64) void {
    c.vDSP_svdivD(&scalar, b.ptr, 1, out.ptr, 1, b.len);
}

// -- Sum of signed squares --

/// Sum of vector elements' signed squares.
///
/// C[0] = sum(A[n] * |A[n]|, 0 <= n < N);
pub fn svs(a: []const f32) f32 {
    var r: f32 = undefined;
    c.vDSP_svs(a.ptr, 1, &r, a.len);
    return r;
}
/// Sum of vector elements' signed squares (double-precision).
///
/// C[0] = sum(A[n] * |A[n]|, 0 <= n < N);
pub fn svsD(a: []const f64) f64 {
    var r: f64 = undefined;
    c.vDSP_svsD(a.ptr, 1, &r, a.len);
    return r;
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
