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
pub fn vclr(comptime T: type, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vclr(out.ptr, 1, out.len),
        f64 => c.vDSP_vclrD(out.ptr, 1, out.len),
        else => @compileError("vclr requires f32 or f64"),
    }
}

// -- Compress --

/// Vector compress.
///
///     p = 0;
///     for (n = 0; n < N; ++n)
///         if (B[n] != 0)
///             C[p++] = A[n];
pub fn vcmprs(comptime T: type, a: []const T, gate: []const T, out: []T) void {
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
    switch (T) {
        f32 => c.vDSP_viclip(a.ptr, 1, &lo, &hi, out.ptr, 1, a.len),
        f64 => c.vDSP_viclipD(a.ptr, 1, &lo, &hi, out.ptr, 1, a.len),
        else => @compileError("viclip requires f32 or f64"),
    }
}

pub fn vthr(comptime T: type, a: []const T, threshold: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vthr(a.ptr, 1, &threshold, out.ptr, 1, a.len),
        f64 => c.vDSP_vthrD(a.ptr, 1, &threshold, out.ptr, 1, a.len),
        else => @compileError("vthr requires f32 or f64"),
    }
}

pub fn vthres(comptime T: type, a: []const T, threshold: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vthres(a.ptr, 1, &threshold, out.ptr, 1, a.len),
        f64 => c.vDSP_vthresD(a.ptr, 1, &threshold, out.ptr, 1, a.len),
        else => @compileError("vthres requires f32 or f64"),
    }
}

pub fn vlim(comptime T: type, a: []const T, threshold: T, val: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vlim(a.ptr, 1, &threshold, &val, out.ptr, 1, a.len),
        f64 => c.vDSP_vlimD(a.ptr, 1, &threshold, &val, out.ptr, 1, a.len),
        else => @compileError("vlim requires f32 or f64"),
    }
}

// -- Element-wise max / min --

pub fn vmax(comptime T: type, a: []const T, b: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vmax(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vmaxD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vmax requires f32 or f64"),
    }
}

pub fn vmin(comptime T: type, a: []const T, b: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vmin(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vminD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vmin requires f32 or f64"),
    }
}

pub fn vmaxmg(comptime T: type, a: []const T, b: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vmaxmg(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vmaxmgD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vmaxmg requires f32 or f64"),
    }
}

pub fn vminmg(comptime T: type, a: []const T, b: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vminmg(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vminmgD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vminmg requires f32 or f64"),
    }
}
