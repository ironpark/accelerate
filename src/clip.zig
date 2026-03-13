const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;

const c = struct {
    extern fn vDSP_vclr(C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vclrD(C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vcmprs(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vcmprsD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vclip(A: [*]const f32, IA: Stride, lo: *const f32, hi: *const f32, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vclipD(A: [*]const f64, IA: Stride, lo: *const f64, hi: *const f64, D: [*]f64, ID: Stride, N: Length) void;
    extern fn vDSP_vclipc(A: [*]const f32, IA: Stride, lo: *const f32, hi: *const f32, D: [*]f32, ID: Stride, N: Length, NLow: *Length, NHigh: *Length) void;
    extern fn vDSP_vclipcD(A: [*]const f64, IA: Stride, lo: *const f64, hi: *const f64, D: [*]f64, ID: Stride, N: Length, NLow: *Length, NHigh: *Length) void;
    extern fn vDSP_viclip(A: [*]const f32, IA: Stride, lo: *const f32, hi: *const f32, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_viclipD(A: [*]const f64, IA: Stride, lo: *const f64, hi: *const f64, D: [*]f64, ID: Stride, N: Length) void;
    extern fn vDSP_vthr(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vthrD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vthres(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vthresD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vlim(A: [*]const f32, IA: Stride, B: *const f32, C_val: *const f32, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vlimD(A: [*]const f64, IA: Stride, B: *const f64, C_val: *const f64, D: [*]f64, ID: Stride, N: Length) void;
    extern fn vDSP_vmax(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vmaxD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vmin(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vminD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vmaxmg(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vmaxmgD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vminmg(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vminmgD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
};

// -- Clear --

/// Vector clear.
///
///     for (n = 0; n < N; ++n)
///         C[n] = 0;
pub fn vclr(out: []f32) void {
    c.vDSP_vclr(out.ptr, 1, out.len);
}
/// Vector clear.
///
///     for (n = 0; n < N; ++n)
///         C[n] = 0;
pub fn vclrD(out: []f64) void {
    c.vDSP_vclrD(out.ptr, 1, out.len);
}

// -- Compress --

/// Vector compress.
///
///     p = 0;
///     for (n = 0; n < N; ++n)
///         if (B[n] != 0)
///             C[p++] = A[n];
pub fn vcmprs(a: []const f32, gate: []const f32, out: []f32) void {
    c.vDSP_vcmprs(a.ptr, 1, gate.ptr, 1, out.ptr, 1, a.len);
}
/// Vector compress.
///
///     p = 0;
///     for (n = 0; n < N; ++n)
///         if (B[n] != 0)
///             C[p++] = A[n];
pub fn vcmprsD(a: []const f64, gate: []const f64, out: []f64) void {
    c.vDSP_vcmprsD(a.ptr, 1, gate.ptr, 1, out.ptr, 1, a.len);
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
pub fn vclip(a: []const f32, lo: f32, hi: f32, out: []f32) void {
    c.vDSP_vclip(a.ptr, 1, &lo, &hi, out.ptr, 1, a.len);
}
/// Vector clip.
///
///     for (n = 0; n < N; ++n)
///     {
///         D[n] = A[n];
///         if (D[n] < B[0]) D[n] = B[0];
///         if (C[0] < D[n]) D[n] = C[0];
///     }
pub fn vclipD(a: []const f64, lo: f64, hi: f64, out: []f64) void {
    c.vDSP_vclipD(a.ptr, 1, &lo, &hi, out.ptr, 1, a.len);
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
pub fn vclipc(a: []const f32, lo: f32, hi: f32, out: []f32) struct { n_low: Length, n_high: Length } {
    var nl: Length = undefined;
    var nh: Length = undefined;
    c.vDSP_vclipc(a.ptr, 1, &lo, &hi, out.ptr, 1, a.len, &nl, &nh);
    return .{ .n_low = nl, .n_high = nh };
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
pub fn vclipcD(a: []const f64, lo: f64, hi: f64, out: []f64) struct { n_low: Length, n_high: Length } {
    var nl: Length = undefined;
    var nh: Length = undefined;
    c.vDSP_vclipcD(a.ptr, 1, &lo, &hi, out.ptr, 1, a.len, &nl, &nh);
    return .{ .n_low = nl, .n_high = nh };
}

pub fn viclip(a: []const f32, lo: f32, hi: f32, out: []f32) void {
    c.vDSP_viclip(a.ptr, 1, &lo, &hi, out.ptr, 1, a.len);
}
pub fn viclipD(a: []const f64, lo: f64, hi: f64, out: []f64) void {
    c.vDSP_viclipD(a.ptr, 1, &lo, &hi, out.ptr, 1, a.len);
}

pub fn vthr(a: []const f32, threshold: f32, out: []f32) void {
    c.vDSP_vthr(a.ptr, 1, &threshold, out.ptr, 1, a.len);
}
pub fn vthrD(a: []const f64, threshold: f64, out: []f64) void {
    c.vDSP_vthrD(a.ptr, 1, &threshold, out.ptr, 1, a.len);
}

pub fn vthres(a: []const f32, threshold: f32, out: []f32) void {
    c.vDSP_vthres(a.ptr, 1, &threshold, out.ptr, 1, a.len);
}
pub fn vthresD(a: []const f64, threshold: f64, out: []f64) void {
    c.vDSP_vthresD(a.ptr, 1, &threshold, out.ptr, 1, a.len);
}

pub fn vlim(a: []const f32, threshold: f32, val: f32, out: []f32) void {
    c.vDSP_vlim(a.ptr, 1, &threshold, &val, out.ptr, 1, a.len);
}
pub fn vlimD(a: []const f64, threshold: f64, val: f64, out: []f64) void {
    c.vDSP_vlimD(a.ptr, 1, &threshold, &val, out.ptr, 1, a.len);
}

// -- Element-wise max / min --

pub fn vmax(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vmax(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vmaxD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vmaxD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

pub fn vmin(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vmin(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vminD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vminD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

pub fn vmaxmg(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vmaxmg(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vmaxmgD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vmaxmgD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

pub fn vminmg(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vminmg(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vminmgD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vminmgD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
