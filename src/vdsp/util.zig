const std = @import("std");
const types = @import("types.zig");
const Length = types.Length;
const SortOrder = types.SortOrder;
const WindowFlag = types.WindowFlag;
const c = @import("c.zig");

// ============================================================================
// Reverse / swap / sort
// ============================================================================

/// Vector reverse order, in-place.
///
/// These compute:
///
///     Let A contain a copy of C.
///     for (n = 0; n < N; ++n)
///         C[n] = A[N-1-n];
pub fn vrvrs(comptime T: type, buf: []T) void {
    switch (T) {
        f32 => c.vDSP_vrvrs(buf.ptr, 1, buf.len),
        f64 => c.vDSP_vrvrsD(buf.ptr, 1, buf.len),
        else => @compileError("vrvrs requires f32 or f64"),
    }
}

/// Vector swap.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         A[n] is swapped with B[n].
pub fn vswap(comptime T: type, a: []T, b: []T) void {
    std.debug.assert(b.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vswap(a.ptr, 1, b.ptr, 1, a.len),
        f64 => c.vDSP_vswapD(a.ptr, 1, b.ptr, 1, a.len),
        else => @compileError("vswap requires f32 or f64"),
    }
}

/// Vector sort, in-place.
///
/// If Order is +1, C is sorted in ascending order.
/// If Order is -1, C is sorted in descending order.
pub fn vsort(comptime T: type, buf: []T, order: SortOrder) void {
    switch (T) {
        f32 => c.vDSP_vsort(buf.ptr, buf.len, @intFromEnum(order)),
        f64 => c.vDSP_vsortD(buf.ptr, buf.len, @intFromEnum(order)),
        else => @compileError("vsort requires f32 or f64"),
    }
}

/// Vector sort indices, in-place.
///
/// I contains indices into C.
///
/// If Order is +1, I is sorted so that C[I[n]] increases, for 0 <= n < N.
/// If Order is -1, I is sorted so that C[I[n]] decreases, for 0 <= n < N.
///
/// Temporary is not used. NULL should be passed for it.
pub fn vsorti(comptime T: type, data: []const T, indices: []Length, order: SortOrder) void {
    switch (T) {
        f32 => c.vDSP_vsorti(data.ptr, indices.ptr, null, data.len, @intFromEnum(order)),
        f64 => c.vDSP_vsortiD(data.ptr, indices.ptr, null, data.len, @intFromEnum(order)),
        else => @compileError("vsorti requires f32 or f64"),
    }
}

// ============================================================================
// Ramp / generate
// ============================================================================

/// Vector build ramp.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[0] + n*B[0];
pub fn vramp(comptime T: type, start: T, step: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vramp(&start, &step, out.ptr, 1, out.len),
        f64 => c.vDSP_vrampD(&start, &step, out.ptr, 1, out.len),
        else => @compileError("vramp requires f32 or f64"),
    }
}

/// Vector generate tapered ramp.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[0] + (B[0] - A[0]) * n/(N-1);
pub fn vgen(comptime T: type, start: T, end: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vgen(&start, &end, out.ptr, 1, out.len),
        f64 => c.vDSP_vgenD(&start, &end, out.ptr, 1, out.len),
        else => @compileError("vgen requires f32 or f64"),
    }
}

// ============================================================================
// Gather / index
// ============================================================================

/// Vector gather.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[B[n] - 1];
pub fn vgathr(comptime T: type, table: []const T, indices: []const Length, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vgathr(table.ptr, indices.ptr, 1, out.ptr, 1, indices.len),
        f64 => c.vDSP_vgathrD(table.ptr, indices.ptr, 1, out.ptr, 1, indices.len),
        else => @compileError("vgathr requires f32 or f64"),
    }
}

/// Vector index, C[i] = A[truncate[B[i]].
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[trunc(B[n])];
pub fn vindex(comptime T: type, table: []const T, indices: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vindex(table.ptr, indices.ptr, 1, out.ptr, 1, indices.len),
        f64 => c.vDSP_vindexD(table.ptr, indices.ptr, 1, out.ptr, 1, indices.len),
        else => @compileError("vindex requires f32 or f64"),
    }
}

/// Vector gather, absolute pointers.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         C[n] = *A[n];
pub fn vgathra(comptime T: type, ptrs: [*]const [*]const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vgathra(ptrs, 1, out.ptr, 1, out.len),
        f64 => c.vDSP_vgathraD(ptrs, 1, out.ptr, 1, out.len),
        else => @compileError("vgathra requires f32 or f64"),
    }
}

// ============================================================================
// Threshold with signed constant
// ============================================================================

/// Vector threshold with signed constant.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         if (B[0] <= A[n])
///             D[n] = +C[0];
///         else
///             D[n] = -C[0];
pub fn vthrsc(comptime T: type, a: []const T, threshold: T, val: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vthrsc(a.ptr, 1, &threshold, &val, out.ptr, 1, a.len),
        f64 => c.vDSP_vthrscD(a.ptr, 1, &threshold, &val, out.ptr, 1, a.len),
        else => @compileError("vthrsc requires f32 or f64"),
    }
}

// ============================================================================
// Table lookup and interpolation
// ============================================================================

/// Vector table lookup and interpolation.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///     {
///         p = S1[0] * A[n] + S2[0];
///         if (p < 0)
///             D[n] = C[0];
///         else if (p < M-1)
///         {
///             q = trunc(p);
///             r = p-q;
///             D[n] = (1-r)*C[q] + r*C[q+1];
///         }
///         else
///             D[n] = C[M-1];
///     }
pub fn vtabi(comptime T: type, a: []const T, s1: T, s2: T, table: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vtabi(a.ptr, 1, &s1, &s2, table.ptr, table.len, out.ptr, 1, a.len),
        f64 => c.vDSP_vtabiD(a.ptr, 1, &s1, &s2, table.ptr, table.len, out.ptr, 1, a.len),
        else => @compileError("vtabi requires f32 or f64"),
    }
}

// ============================================================================
// Tapered merge
// ============================================================================

/// Vector tapered merge.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] + (B[n] - A[n]) * n/(N-1);
pub fn vtmerg(comptime T: type, a: []const T, b: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vtmerg(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vtmergD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vtmerg requires f32 or f64"),
    }
}

// ============================================================================
// Wiener Levinson
// ============================================================================

/// Wiener Levinson.
pub fn wiener(comptime T: type, l: Length, a: [*]const T, corr: [*]const T, filter: [*]T, power: [*]T, flag: c_int) c_int {
    var err: c_int = undefined;
    switch (T) {
        f32 => c.vDSP_wiener(l, a, corr, filter, power, flag, &err),
        f64 => c.vDSP_wienerD(l, a, corr, filter, power, flag, &err),
        else => @compileError("wiener requires f32 or f64"),
    }
    return err;
}

test "wiener" {
    // Order-1 normal equations: autocorrelation A = [r0, r1] = [1.0, 0.5],
    // cross-correlation C = [0.5]. The order-1 Wiener/Levinson solution is
    // filter[0] = C[0] / A[0] = 0.5, matching the classic normal-equation
    // solution and confirming (L, A, C, F, P, Flag, Error) line up with the
    // header's parameter order.
    const a = [_]f32{ 1.0, 0.5 };
    const corr = [_]f32{0.5};
    var filter = [_]f32{0.0};
    var power = [_]f32{0.0};
    const err = wiener(f32, 1, &a, &corr, &filter, &power, 0);
    try std.testing.expectEqual(@as(c_int, 0), err);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), filter[0], 0.001);
}

// ============================================================================
// Interpolation
// ============================================================================

/// Vector linear interpolation.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///     {
///         b = trunc(B[n]);
///         a = B[n] - b;
///         C[n] = A[b] + a * (A[b+1] - A[b]);
///     }
pub fn vlint(comptime T: type, table: []const T, indices: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vlint(table.ptr, indices.ptr, 1, out.ptr, 1, out.len, table.len),
        f64 => c.vDSP_vlintD(table.ptr, indices.ptr, 1, out.ptr, 1, out.len, table.len),
        else => @compileError("vlint requires f32 or f64"),
    }
}

/// Vector quadratic interpolation.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///     {
///         b = max(trunc(B[n]), 1);
///         a = B[n] - b;
///         C[n] = (A[b-1]*(a**2-a) + A[b]*(2-2*a**2) + A[b+1]*(a**2+a))
///             / 2;
///     }
pub fn vqint(comptime T: type, table: []const T, indices: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vqint(table.ptr, indices.ptr, 1, out.ptr, 1, out.len, table.len),
        f64 => c.vDSP_vqintD(table.ptr, indices.ptr, 1, out.ptr, 1, out.len, table.len),
        else => @compileError("vqint requires f32 or f64"),
    }
}

/// Vector interpolation between vectors.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         D[n] = A[n] + C[0] * (B[n] - A[n]);
pub fn vintb(comptime T: type, a: []const T, b: []const T, t: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vintb(a.ptr, 1, b.ptr, 1, &t, out.ptr, 1, a.len),
        f64 => c.vDSP_vintbD(a.ptr, 1, b.ptr, 1, &t, out.ptr, 1, a.len),
        else => @compileError("vintb requires f32 or f64"),
    }
}

/// Vector generate by extrapolation and interpolation.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         If n <= B[0],  then C[n] = A[0].
///         If B[M-1] < n, then C[n] = A[M-1].
///         Otherwise:
///             Let m be such that B[m] < n <= B[m+1].
///             C[n] = A[m] + (A[m+1]-A[m]) * (n-B[m]) / (B[m+1]-B[m]).
///
/// The elements of B are expected to be in increasing order.
pub fn vgenp(comptime T: type, values: []const T, positions: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vgenp(values.ptr, 1, positions.ptr, 1, out.ptr, 1, out.len, values.len),
        f64 => c.vDSP_vgenpD(values.ptr, 1, positions.ptr, 1, out.ptr, 1, out.len, values.len),
        else => @compileError("vgenp requires f32 or f64"),
    }
}

/// Vector polynomial.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         C[n] = sum(A[P-p] * B[n]**p, 0 <= p <= P);
///
/// P is the polynomial degree.
pub fn vpoly(comptime T: type, coeffs: []const T, points: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vpoly(coeffs.ptr, 1, points.ptr, 1, out.ptr, 1, points.len, coeffs.len - 1),
        f64 => c.vDSP_vpolyD(coeffs.ptr, 1, points.ptr, 1, out.ptr, 1, points.len, coeffs.len - 1),
        else => @compileError("vpoly requires f32 or f64"),
    }
}

// ============================================================================
// Integration
// ============================================================================

/// Vector running sum integration.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         C[n] = S[0] * sum(A[j], 0 < j <= n);
///
/// Observe that C[0] is set to 0, and A[0] is not used.
pub fn vrsum(comptime T: type, a: []const T, scale: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vrsum(a.ptr, 1, &scale, out.ptr, 1, a.len),
        f64 => c.vDSP_vrsumD(a.ptr, 1, &scale, out.ptr, 1, a.len),
        else => @compileError("vrsum requires f32 or f64"),
    }
}

/// Vector Simpson integration.
///
/// These compute:
///
///     C[0] = 0;
///     C[1] = B[0] * (A[0] + A[1])/2;
///     for (n = 2; n < N; ++n)
///         C[n] = C[n-2] + B[0] * (A[n-2] + 4*A[n-1] + A[n])/3;
pub fn vsimps(comptime T: type, a: []const T, step: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vsimps(a.ptr, 1, &step, out.ptr, 1, a.len),
        f64 => c.vDSP_vsimpsD(a.ptr, 1, &step, out.ptr, 1, a.len),
        else => @compileError("vsimps requires f32 or f64"),
    }
}

/// Vector trapezoidal integration.
///
/// These compute:
///
///     C[0] = 0;
///     for (n = 1; n < N; ++n)
///         C[n] = C[n-1] + B[0] * (A[n-1] + A[n])/2;
pub fn vtrapz(comptime T: type, a: []const T, step: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vtrapz(a.ptr, 1, &step, out.ptr, 1, a.len),
        f64 => c.vDSP_vtrapzD(a.ptr, 1, &step, out.ptr, 1, a.len),
        else => @compileError("vtrapz requires f32 or f64"),
    }
}

/// Vector sliding window sum.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         C[n] = sum(A[n+p], 0 <= p < P);
///
/// Note that A must contain N+P-1 elements.
pub fn vswsum(comptime T: type, a: []const T, out: []T, window_len: Length) void {
    switch (T) {
        f32 => c.vDSP_vswsum(a.ptr, 1, out.ptr, 1, out.len, window_len),
        f64 => c.vDSP_vswsumD(a.ptr, 1, out.ptr, 1, out.len, window_len),
        else => @compileError("vswsum requires f32 or f64"),
    }
}

/// Vector sliding window maxima.
///
/// These compute the maximum value within a window to the input vector.
/// A maximum is calculated for each window position:
///
///     for (n = 0; n < N; ++n)
///         C[n] = the greatest value of A[w] for n <= w < n+WindowLength.
///
/// A must contain N+WindowLength-1 elements, and C must contain space for
/// N+WindowLength-1 elements. Although only N outputs are provided in C,
/// the additional elements may be used for intermediate computation.
///
/// A and C may not overlap.
///
/// WindowLength must be positive (zero is not supported).
pub fn vswmax(comptime T: type, a: []const T, out: []T, window_len: Length) void {
    switch (T) {
        f32 => c.vDSP_vswmax(a.ptr, 1, out.ptr, 1, out.len, window_len),
        f64 => c.vDSP_vswmaxD(a.ptr, 1, out.ptr, 1, out.len, window_len),
        else => @compileError("vswmax requires f32 or f64"),
    }
}

// ============================================================================
// Window functions
// ============================================================================

pub fn blkman_window(comptime T: type, out: []T, flag: WindowFlag) void {
    switch (T) {
        f32 => c.vDSP_blkman_window(out.ptr, out.len, @intFromEnum(flag)),
        f64 => c.vDSP_blkman_windowD(out.ptr, out.len, @intFromEnum(flag)),
        else => @compileError("blkman_window requires f32 or f64"),
    }
}

pub fn hamm_window(comptime T: type, out: []T, flag: WindowFlag) void {
    switch (T) {
        f32 => c.vDSP_hamm_window(out.ptr, out.len, @intFromEnum(flag)),
        f64 => c.vDSP_hamm_windowD(out.ptr, out.len, @intFromEnum(flag)),
        else => @compileError("hamm_window requires f32 or f64"),
    }
}

pub fn hann_window(comptime T: type, out: []T, flag: WindowFlag) void {
    switch (T) {
        f32 => c.vDSP_hann_window(out.ptr, out.len, @intFromEnum(flag)),
        f64 => c.vDSP_hann_windowD(out.ptr, out.len, @intFromEnum(flag)),
        else => @compileError("hann_window requires f32 or f64"),
    }
}

// ============================================================================
// Tests
// ============================================================================

test "vrvrs" {
    var buf = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0 };
    vrvrs(f32, &buf);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 5.0, 4.0, 3.0, 2.0, 1.0 }, &buf);
}

test "vrvrs odd single element" {
    var buf = [_]f32{42.0};
    vrvrs(f32, &buf);
    try std.testing.expectEqualSlices(f32, &[_]f32{42.0}, &buf);
}

test "vswap" {
    // A[n] swapped with B[n] is order-independent by definition, so this
    // just verifies the contents actually get exchanged.
    var a = [_]f32{ 1.0, 2.0, 3.0 };
    var b = [_]f32{ 10.0, 20.0, 30.0 };
    vswap(f32, &a, &b);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 10.0, 20.0, 30.0 }, &a);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 1.0, 2.0, 3.0 }, &b);
}
