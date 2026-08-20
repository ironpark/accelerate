const std = @import("std");
const types = @import("types.zig");
const Length = types.Length;
const c = @import("c.zig");

// -- Clear --

/// Vector clear.
///
///     for (n = 0; n < N; ++n)
///         C[n] = 0;
pub fn vclr(comptime T: type, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vclr(out.ptr, 1, out.len),
        f64 => c.vDSP_vclrD(out.ptr, 1, out.len),
        else => @compileError("vclr requires f32 or f64"),
    }
}

// -- Compress --

/// Vector compress: copies the elements of `a` whose corresponding `gate`
/// entry is nonzero into `out`, packed contiguously from `out[0]`.
///
///     p = 0;
///     for (n = 0; n < N; ++n)
///         if (B[n] != 0)
///             C[p++] = A[n];
///
/// CAUTION: `out` is the only output buffer in this file whose required size
/// is *data-dependent* - it must hold one element per nonzero entry of
/// `gate`, a count this function cannot know without scanning `gate` itself.
/// It is therefore the one buffer here with no `assert`. The safe upper bound
/// is `out.len >= a.len` (every gate entry nonzero); size `out` that way
/// unless you have already counted the nonzero gate entries yourself.
pub fn vcmprs(comptime T: type, a: []const T, gate: []const T, out: []T) void {
    std.debug.assert(gate.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vcmprs(a.ptr, 1, gate.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vcmprsD(a.ptr, 1, gate.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vcmprs requires f32 or f64"),
    }
}

// -- Clip --

/// Vector clip.
///
///     for (n = 0; n < N; ++n)
///     {
///         D[n] = A[n];
///         if (D[n] < B[0]) D[n] = B[0];
///         if (C[0] < D[n]) D[n] = C[0];
///     }
pub fn vclip(comptime T: type, a: []const T, lo: T, hi: T, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vclip(a.ptr, 1, &lo, &hi, out.ptr, 1, a.len),
        f64 => c.vDSP_vclipD(a.ptr, 1, &lo, &hi, out.ptr, 1, a.len),
        else => @compileError("vclip requires f32 or f64"),
    }
}

/// Vector clip and count.
///
///     NLow[0]  = 0;
///     NHigh[0] = 0;
///     for (n = 0; n < N; ++n)
///     {
///         D[n] = A[n];
///         if (D[n] < B[0]) { D[n] = B[0]; ++NLow[0];  }
///         if (C[0] < D[n]) { D[n] = C[0]; ++NHigh[0]; }
///     }
pub fn vclipc(comptime T: type, a: []const T, lo: T, hi: T, out: []T) struct { n_low: Length, n_high: Length } {
    std.debug.assert(out.len >= a.len);
    var nl: Length = undefined;
    var nh: Length = undefined;
    switch (T) {
        f32 => c.vDSP_vclipc(a.ptr, 1, &lo, &hi, out.ptr, 1, a.len, &nl, &nh),
        f64 => c.vDSP_vclipcD(a.ptr, 1, &lo, &hi, out.ptr, 1, a.len, &nl, &nh),
        else => @compileError("vclipc requires f32 or f64"),
    }
    return .{ .n_low = nl, .n_high = nh };
}

pub fn viclip(comptime T: type, a: []const T, lo: T, hi: T, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_viclip(a.ptr, 1, &lo, &hi, out.ptr, 1, a.len),
        f64 => c.vDSP_viclipD(a.ptr, 1, &lo, &hi, out.ptr, 1, a.len),
        else => @compileError("viclip requires f32 or f64"),
    }
}

pub fn vthr(comptime T: type, a: []const T, threshold: T, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vthr(a.ptr, 1, &threshold, out.ptr, 1, a.len),
        f64 => c.vDSP_vthrD(a.ptr, 1, &threshold, out.ptr, 1, a.len),
        else => @compileError("vthr requires f32 or f64"),
    }
}

pub fn vthres(comptime T: type, a: []const T, threshold: T, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vthres(a.ptr, 1, &threshold, out.ptr, 1, a.len),
        f64 => c.vDSP_vthresD(a.ptr, 1, &threshold, out.ptr, 1, a.len),
        else => @compileError("vthres requires f32 or f64"),
    }
}

pub fn vlim(comptime T: type, a: []const T, threshold: T, val: T, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vlim(a.ptr, 1, &threshold, &val, out.ptr, 1, a.len),
        f64 => c.vDSP_vlimD(a.ptr, 1, &threshold, &val, out.ptr, 1, a.len),
        else => @compileError("vlim requires f32 or f64"),
    }
}

// -- Element-wise max / min --

pub fn vmax(comptime T: type, a: []const T, b: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vmax(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vmaxD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vmax requires f32 or f64"),
    }
}

pub fn vmin(comptime T: type, a: []const T, b: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vmin(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vminD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vmin requires f32 or f64"),
    }
}

pub fn vmaxmg(comptime T: type, a: []const T, b: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vmaxmg(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vmaxmgD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vmaxmg requires f32 or f64"),
    }
}

pub fn vminmg(comptime T: type, a: []const T, b: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vminmg(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vminmgD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vminmg requires f32 or f64"),
    }
}

// ============================================================================
// Tests
// ============================================================================

test "vclr" {
    var out = [_]f32{ 1.0, 2.0, 3.0 };
    vclr(f32, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 0.0, 0.0, 0.0 }, &out);
}

test "vcmprs" {
    const a = [_]f32{ 10.0, 20.0, 30.0, 40.0 };
    const gate = [_]f32{ 1.0, 0.0, 1.0, 0.0 };
    var out: [2]f32 = undefined;
    vcmprs(f32, &a, &gate, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 10.0, 30.0 }, &out);
}

test "vclip" {
    const a = [_]f32{ -5.0, 3.0, 15.0 };
    var out: [3]f32 = undefined;
    vclip(f32, &a, 0.0, 10.0, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 0.0, 3.0, 10.0 }, &out);
}

test "vclipc" {
    const a = [_]f32{ -5.0, 3.0, 15.0 };
    var out: [3]f32 = undefined;
    const result = vclipc(f32, &a, 0.0, 10.0, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 0.0, 3.0, 10.0 }, &out);
    try std.testing.expectEqual(@as(Length, 1), result.n_low);
    try std.testing.expectEqual(@as(Length, 1), result.n_high);
}

test "viclip" {
    // Inverse clip (vDSP.h:5487-5499): values OUTSIDE [lo, hi] pass through
    // unchanged; values INSIDE get pushed to the nearer boundary based on
    // sign. lo=2, hi=8.
    const a = [_]f32{ -5.0, 5.0, 15.0, 1.0 };
    var out: [4]f32 = undefined;
    viclip(f32, &a, 2.0, 8.0, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ -5.0, 8.0, 15.0, 1.0 }, &out);
}

test "vthr" {
    const a = [_]f32{ 3.0, 10.0, 5.0, -2.0 };
    var out: [4]f32 = undefined;
    vthr(f32, &a, 5.0, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 5.0, 10.0, 5.0, 5.0 }, &out);
}

test "vthres" {
    const a = [_]f32{ 3.0, 10.0, 5.0, -2.0 };
    var out: [4]f32 = undefined;
    vthres(f32, &a, 5.0, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 0.0, 10.0, 5.0, 0.0 }, &out);
}

test "vlim" {
    const a = [_]f32{ 3.0, 10.0, 5.0, -2.0 };
    var out: [4]f32 = undefined;
    vlim(f32, &a, 5.0, 100.0, &out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ -100.0, 100.0, 100.0, -100.0 }, &out);
}

test "vmax and vmin" {
    const a = [_]f32{ 1.0, 10.0, 5.0 };
    const b = [_]f32{ 9.0, 2.0, 5.0 };
    var max_out: [3]f32 = undefined;
    var min_out: [3]f32 = undefined;
    vmax(f32, &a, &b, &max_out);
    vmin(f32, &a, &b, &min_out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 9.0, 10.0, 5.0 }, &max_out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 1.0, 2.0, 5.0 }, &min_out);
}

test "vmaxmg and vminmg" {
    // Both return the *magnitude* (always non-negative), not the original
    // signed value - vDSP.h:5674-5678/5765-5769 explicitly wrap in |...|.
    const a = [_]f32{ -9.0, 3.0, -5.0 };
    const b = [_]f32{ 2.0, -8.0, 5.0 };
    var maxmg_out: [3]f32 = undefined;
    var minmg_out: [3]f32 = undefined;
    vmaxmg(f32, &a, &b, &maxmg_out);
    vminmg(f32, &a, &b, &minmg_out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 9.0, 8.0, 5.0 }, &maxmg_out);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 2.0, 3.0, 5.0 }, &minmg_out);
}

// ============================================================================
// Intention-revealing aliases
// ============================================================================
//
// Three functions in this file have vDSP names that read as the opposite of,
// or vaguer than, what they do. The doc comments say so, but a doc comment is
// only seen by someone who goes looking; the alias is visible at the call
// site, which is where the misreading actually happens. The vDSP names stay
// as the primary spelling so header cross-references keep working.

/// `viclip` under a name that matches its behavior: values *inside* `[lo, hi]`
/// are pushed out to the nearer boundary and values *outside* pass through
/// unchanged - the inverse of what "clip" normally means.
pub const inverseClip = viclip;

/// `vmaxmg` under a name that says it returns a *magnitude*:
/// `out[i] = max(|a[i]|, |b[i]|)`, always non-negative, never the original
/// signed value.
pub const maxMagnitude = vmaxmg;

/// `vminmg` under a name that says it returns a *magnitude*:
/// `out[i] = min(|a[i]|, |b[i]|)`, always non-negative.
pub const minMagnitude = vminmg;

test "intention-revealing aliases are the same functions, and the names are the accurate ones" {
    const a = [_]f32{ -10.0, 3.0, -2.0, 8.0 };
    const b = [_]f32{ 4.0, -5.0, 6.0, -1.0 };

    // maxMagnitude / minMagnitude: signed inputs whose magnitude ordering
    // differs from their signed ordering, so a "returns the signed value"
    // misreading fails here.
    var mx = [_]f32{0} ** 4;
    var mn = [_]f32{0} ** 4;
    maxMagnitude(f32, &a, &b, &mx);
    minMagnitude(f32, &a, &b, &mn);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 10.0, 5.0, 6.0, 8.0 }, &mx);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 4.0, 3.0, 2.0, 1.0 }, &mn);

    // inverseClip: 3.0 and -2.0 are inside [-5, 5] and get pushed OUT to the
    // nearer bound; -10.0 and 8.0 are outside and pass through untouched.
    // A normal clip would have done exactly the opposite to every element.
    var ic = [_]f32{0} ** 4;
    inverseClip(f32, &a, -5.0, 5.0, &ic);
    try std.testing.expectEqualSlices(f32, &[_]f32{ -10.0, 5.0, -5.0, 8.0 }, &ic);
}
