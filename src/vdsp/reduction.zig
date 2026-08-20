const std = @import("std");
const types = @import("types.zig");
const Length = types.Length;
const c = @import("c.zig");

pub fn ValueIndex(comptime T: type) type {
    return struct { value: T, index: Length };
}

pub fn NormResult(comptime T: type) type {
    return struct { mean: T, std_dev: T };
}

// -- Sum --

/// Sum of vector elements.
///
/// C[0] = sum(A[n], 0 <= n < N);
pub fn sve(comptime T: type, a: []const T) T {
    var r: T = undefined;
    switch (T) {
        f32 => c.vDSP_sve(a.ptr, 1, &r, a.len),
        f64 => c.vDSP_sveD(a.ptr, 1, &r, a.len),
        else => @compileError("sve requires f32 or f64"),
    }
    return r;
}

/// Sum of vector elements' squares.
///
/// C[0] = sum(A[n] ** 2, 0 <= n < N);
pub fn svesq(comptime T: type, a: []const T) T {
    var r: T = undefined;
    switch (T) {
        f32 => c.vDSP_svesq(a.ptr, 1, &r, a.len),
        f64 => c.vDSP_svesqD(a.ptr, 1, &r, a.len),
        else => @compileError("svesq requires f32 or f64"),
    }
    return r;
}

/// Sum of vector elements and sum of vector elements' squares.
///
/// Sum[0]          = sum(A[n],      0 <= n < N);
/// SumOfSquares[0] = sum(A[n] ** 2, 0 <= n < N);
pub fn sve_svesq(comptime T: type, a: []const T) struct { sum: T, sum_sq: T } {
    var s: T = undefined;
    var sq: T = undefined;
    switch (T) {
        f32 => c.vDSP_sve_svesq(a.ptr, 1, &s, &sq, a.len),
        f64 => c.vDSP_sve_svesqD(a.ptr, 1, &s, &sq, a.len),
        else => @compileError("sve_svesq requires f32 or f64"),
    }
    return .{ .sum = s, .sum_sq = sq };
}

/// Sum of vector elements magnitudes.
///
/// C[0] = sum(|A[n]|, 0 <= n < N);
pub fn svemg(comptime T: type, a: []const T) T {
    var r: T = undefined;
    switch (T) {
        f32 => c.vDSP_svemg(a.ptr, 1, &r, a.len),
        f64 => c.vDSP_svemgD(a.ptr, 1, &r, a.len),
        else => @compileError("svemg requires f32 or f64"),
    }
    return r;
}

// -- Mean --

/// Mean of vector.
///
/// C[0] = sum(A[n], 0 <= n < N) / N;
pub fn meanv(comptime T: type, a: []const T) T {
    var r: T = undefined;
    switch (T) {
        f32 => c.vDSP_meanv(a.ptr, 1, &r, a.len),
        f64 => c.vDSP_meanvD(a.ptr, 1, &r, a.len),
        else => @compileError("meanv requires f32 or f64"),
    }
    return r;
}

/// Mean magnitude of vector.
///
/// C[0] = sum(|A[n]|, 0 <= n < N) / N;
pub fn meamgv(comptime T: type, a: []const T) T {
    var r: T = undefined;
    switch (T) {
        f32 => c.vDSP_meamgv(a.ptr, 1, &r, a.len),
        f64 => c.vDSP_meamgvD(a.ptr, 1, &r, a.len),
        else => @compileError("meamgv requires f32 or f64"),
    }
    return r;
}

/// Mean square of vector.
///
/// C[0] = sum(A[n]**2, 0 <= n < N) / N;
pub fn measqv(comptime T: type, a: []const T) T {
    var r: T = undefined;
    switch (T) {
        f32 => c.vDSP_measqv(a.ptr, 1, &r, a.len),
        f64 => c.vDSP_measqvD(a.ptr, 1, &r, a.len),
        else => @compileError("measqv requires f32 or f64"),
    }
    return r;
}

/// Root-mean-square of vector.
///
/// C[0] = sqrt(sum(A[n] ** 2, 0 <= n < N) / N);
pub fn rmsqv(comptime T: type, a: []const T) T {
    var r: T = undefined;
    switch (T) {
        f32 => c.vDSP_rmsqv(a.ptr, 1, &r, a.len),
        f64 => c.vDSP_rmsqvD(a.ptr, 1, &r, a.len),
        else => @compileError("rmsqv requires f32 or f64"),
    }
    return r;
}

// -- Max --

/// Maximum value of vector.
///
/// C[0] is set to the greatest value of A[n] for 0 <= n < N.
pub fn maxv(comptime T: type, a: []const T) T {
    var r: T = undefined;
    switch (T) {
        f32 => c.vDSP_maxv(a.ptr, 1, &r, a.len),
        f64 => c.vDSP_maxvD(a.ptr, 1, &r, a.len),
        else => @compileError("maxv requires f32 or f64"),
    }
    return r;
}

/// Maximum value of vector, with index.
///
/// C[0] is set to the greatest value of A[n] for 0 <= n < N.
/// I[0] is set to the least i*IA such that A[i] has the value in C[0].
pub fn maxvi(comptime T: type, a: []const T) ValueIndex(T) {
    var v: T = undefined;
    var i: Length = undefined;
    switch (T) {
        f32 => c.vDSP_maxvi(a.ptr, 1, &v, &i, a.len),
        f64 => c.vDSP_maxviD(a.ptr, 1, &v, &i, a.len),
        else => @compileError("maxvi requires f32 or f64"),
    }
    return .{ .value = v, .index = i };
}

/// Maximum magnitude of vector.
///
/// C[0] is set to the greatest value of |A[n]| for 0 <= n < N.
pub fn maxmgv(comptime T: type, a: []const T) T {
    var r: T = undefined;
    switch (T) {
        f32 => c.vDSP_maxmgv(a.ptr, 1, &r, a.len),
        f64 => c.vDSP_maxmgvD(a.ptr, 1, &r, a.len),
        else => @compileError("maxmgv requires f32 or f64"),
    }
    return r;
}

/// Maximum magnitude of vector, with index.
///
/// C[0] is set to the greatest value of |A[n]| for 0 <= n < N.
/// I[0] is set to the least i*IA such that |A[i]| has the value in C[0].
pub fn maxmgvi(comptime T: type, a: []const T) ValueIndex(T) {
    var v: T = undefined;
    var i: Length = undefined;
    switch (T) {
        f32 => c.vDSP_maxmgvi(a.ptr, 1, &v, &i, a.len),
        f64 => c.vDSP_maxmgviD(a.ptr, 1, &v, &i, a.len),
        else => @compileError("maxmgvi requires f32 or f64"),
    }
    return .{ .value = v, .index = i };
}

// -- Min --

/// Minimum value of vector.
///
/// C[0] is set to the least value of A[n] for 0 <= n < N.
pub fn minv(comptime T: type, a: []const T) T {
    var r: T = undefined;
    switch (T) {
        f32 => c.vDSP_minv(a.ptr, 1, &r, a.len),
        f64 => c.vDSP_minvD(a.ptr, 1, &r, a.len),
        else => @compileError("minv requires f32 or f64"),
    }
    return r;
}

/// Minimum value of vector, with index.
///
/// C[0] is set to the least value of A[n] for 0 <= n < N.
/// I[0] is set to the least i*IA such that A[i] has the value in C[0].
pub fn minvi(comptime T: type, a: []const T) ValueIndex(T) {
    var v: T = undefined;
    var i: Length = undefined;
    switch (T) {
        f32 => c.vDSP_minvi(a.ptr, 1, &v, &i, a.len),
        f64 => c.vDSP_minviD(a.ptr, 1, &v, &i, a.len),
        else => @compileError("minvi requires f32 or f64"),
    }
    return .{ .value = v, .index = i };
}

/// Minimum magnitude of vector.
///
/// C[0] is set to the least value of |A[n]| for 0 <= n < N.
pub fn minmgv(comptime T: type, a: []const T) T {
    var r: T = undefined;
    switch (T) {
        f32 => c.vDSP_minmgv(a.ptr, 1, &r, a.len),
        f64 => c.vDSP_minmgvD(a.ptr, 1, &r, a.len),
        else => @compileError("minmgv requires f32 or f64"),
    }
    return r;
}

/// Minimum magnitude of vector, with index.
///
/// C[0] is set to the least value of |A[n]| for 0 <= n < N.
/// I[0] is set to the least i*IA such that |A[i]| has the value in C[0].
pub fn minmgvi(comptime T: type, a: []const T) ValueIndex(T) {
    var v: T = undefined;
    var i: Length = undefined;
    switch (T) {
        f32 => c.vDSP_minmgvi(a.ptr, 1, &v, &i, a.len),
        f64 => c.vDSP_minmgviD(a.ptr, 1, &v, &i, a.len),
        else => @compileError("minmgvi requires f32 or f64"),
    }
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
pub fn normalize(comptime T: type, a: []const T, out: []T) NormResult(T) {
    var mean: T = undefined;
    var std_dev: T = undefined;
    switch (T) {
        f32 => c.vDSP_normalize(a.ptr, 1, out.ptr, 1, &mean, &std_dev, a.len),
        f64 => c.vDSP_normalizeD(a.ptr, 1, out.ptr, 1, &mean, &std_dev, a.len),
        else => @compileError("normalize requires f32 or f64"),
    }
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
pub fn mmov(comptime T: type, a: [*]const T, out: [*]T, cols: Length, rows: Length, ta: Length, tc: Length) void {
    switch (T) {
        f32 => c.vDSP_mmov(a, out, cols, rows, ta, tc),
        f64 => c.vDSP_mmovD(a, out, cols, rows, ta, tc),
        else => @compileError("mmov requires f32 or f64"),
    }
}

// -- Mean of signed squares --

/// Mean of signed squares of vector.
///
/// C[0] = sum(A[n] * |A[n]|, 0 <= n < N) / N;
pub fn mvessq(comptime T: type, a: []const T) T {
    var r: T = undefined;
    switch (T) {
        f32 => c.vDSP_mvessq(a.ptr, 1, &r, a.len),
        f64 => c.vDSP_mvessqD(a.ptr, 1, &r, a.len),
        else => @compileError("mvessq requires f32 or f64"),
    }
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
pub fn nzcros(comptime T: type, a: []const T, b: Length) struct { crossing: Length, count: Length } {
    var crossing: Length = undefined;
    var count: Length = undefined;
    switch (T) {
        f32 => c.vDSP_nzcros(a.ptr, 1, b, &crossing, &count, a.len),
        f64 => c.vDSP_nzcrosD(a.ptr, 1, b, &crossing, &count, a.len),
        else => @compileError("nzcros requires f32 or f64"),
    }
    return .{ .crossing = crossing, .count = count };
}

// -- Sum of signed squares --

/// Sum of vector elements' signed squares.
///
/// C[0] = sum(A[n] * |A[n]|, 0 <= n < N);
pub fn svs(comptime T: type, a: []const T) T {
    var r: T = undefined;
    switch (T) {
        f32 => c.vDSP_svs(a.ptr, 1, &r, a.len),
        f64 => c.vDSP_svsD(a.ptr, 1, &r, a.len),
        else => @compileError("svs requires f32 or f64"),
    }
    return r;
}

test "sve" {
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), sve(f32, &a), 0.001);
}

test "svesq" {
    const a = [_]f32{ -10.0, 3.0, -2.0, 4.0 };
    // 100 + 9 + 4 + 16 = 129
    try std.testing.expectApproxEqAbs(@as(f32, 129.0), svesq(f32, &a), 0.001);
}

test "sve_svesq" {
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const result = sve_svesq(f32, &a);
    // sum = 1+2+3+4 = 10, sum_sq = 1+4+9+16 = 30 - distinct values, so an
    // output-order bug (sum/sum_sq swapped) would be caught.
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), result.sum, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 30.0), result.sum_sq, 0.001);
}

test "maxv and minv" {
    const a = [_]f32{ 3.0, 1.0, 4.0, 1.0, 5.0 };
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), maxv(f32, &a), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), minv(f32, &a), 0.001);
}

test "svemg, meanv, meamgv, measqv, rmsqv" {
    const a = [_]f32{ -10.0, 3.0, -2.0, 4.0 };
    // sum|A| = 10+3+2+4 = 19
    try std.testing.expectApproxEqAbs(@as(f32, 19.0), svemg(f32, &a), 0.001);
    // sum(A)/N = -5/4 = -1.25
    try std.testing.expectApproxEqAbs(@as(f32, -1.25), meanv(f32, &a), 0.001);
    // sum|A|/N = 19/4 = 4.75
    try std.testing.expectApproxEqAbs(@as(f32, 4.75), meamgv(f32, &a), 0.001);
    // sum(A^2)/N = 129/4 = 32.25
    try std.testing.expectApproxEqAbs(@as(f32, 32.25), measqv(f32, &a), 0.001);
    // sqrt(32.25)
    try std.testing.expectApproxEqAbs(@as(f32, 5.67891), rmsqv(f32, &a), 0.001);
}

test "maxvi and maxmgvi distinguish signed value from magnitude" {
    // -10 has the largest magnitude but 4 has the largest signed value -
    // this distinguishes an argument-order/formula bug from a magnitude bug.
    const a = [_]f32{ -10.0, 3.0, -2.0, 4.0 };
    const max_result = maxvi(f32, &a);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), max_result.value, 0.001);
    try std.testing.expectEqual(@as(Length, 3), max_result.index);

    try std.testing.expectApproxEqAbs(@as(f32, 10.0), maxmgv(f32, &a), 0.001);
    const maxmg_result = maxmgvi(f32, &a);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), maxmg_result.value, 0.001);
    try std.testing.expectEqual(@as(Length, 0), maxmg_result.index);
}

test "minvi, minmgv, minmgvi" {
    const a = [_]f32{ -10.0, 3.0, -2.0, 4.0 };
    const min_result = minvi(f32, &a);
    try std.testing.expectApproxEqAbs(@as(f32, -10.0), min_result.value, 0.001);
    try std.testing.expectEqual(@as(Length, 0), min_result.index);

    // Smallest magnitude is |-2| = 2, at index 2.
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), minmgv(f32, &a), 0.001);
    const minmg_result = minmgvi(f32, &a);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), minmg_result.value, 0.001);
    try std.testing.expectEqual(@as(Length, 2), minmg_result.index);
}

test "normalize" {
    const a = [_]f32{ -10.0, 3.0, -2.0, 4.0 };
    var out: [4]f32 = undefined;
    const result = normalize(f32, &a, &out);
    try std.testing.expectApproxEqAbs(@as(f32, -1.25), result.mean, 0.001);
    // std_dev = sqrt(measqv - mean^2) = sqrt(32.25 - 1.5625) = sqrt(30.6875)
    try std.testing.expectApproxEqAbs(@as(f32, 5.5397), result.std_dev, 0.001);
    for (0..4) |i| {
        try std.testing.expectApproxEqAbs((a[i] - result.mean) / result.std_dev, out[i], 0.001);
    }
}

test "mmov" {
    // A is 2 rows x 2 "used" cols with row stride TA=2 (tightly packed).
    // C has row stride TC=3 (padded), pre-zeroed so the padding is visible.
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var out = [_]f32{ 0.0, 0.0, 0.0, 0.0, 0.0, 0.0 };
    mmov(f32, &a, &out, 2, 2, 2, 3);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 1.0, 2.0, 0.0, 3.0, 4.0, 0.0 }, &out);
}

test "mvessq and svs" {
    // A[n]*|A[n]|: -10*10=-100, 3*3=9, -2*2=-4, 4*4=16; sum = -79.
    const a = [_]f32{ -10.0, 3.0, -2.0, 4.0 };
    try std.testing.expectApproxEqAbs(@as(f32, -79.0), svs(f32, &a), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -19.75), mvessq(f32, &a), 0.001);
}

test "nzcros" {
    // Sign sequence: -,+,-,+ -> 3 changes total (S=3). With B=2, the 2nd
    // change occurs between A[1] and A[2], so crossing index n=2.
    const a = [_]f32{ -10.0, 3.0, -2.0, 4.0 };
    const result = nzcros(f32, &a, 2);
    try std.testing.expectEqual(@as(Length, 2), result.crossing);
    try std.testing.expectEqual(@as(Length, 2), result.count);
}
