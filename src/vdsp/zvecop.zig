const std = @import("std");
const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;
const c = @import("c.zig");

const SC = types.SplitComplex;

// ============================================================================
// Complex vector arithmetic
// ============================================================================

/// Complex vector add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] + B[n];
pub fn zvadd(comptime T: type, a: *const SC(T), b: *const SC(T), out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvadd(a, 1, b, 1, out, 1, n),
        f64 => c.vDSP_zvaddD(a, 1, b, 1, out, 1, n),
        else => @compileError("zvadd requires f32 or f64"),
    }
}

/// Complex-real vector add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] + B[n];
pub fn zrvadd(comptime T: type, a: *const SC(T), b: []const T, out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zrvadd(a, 1, b.ptr, 1, out, 1, n),
        f64 => c.vDSP_zrvaddD(a, 1, b.ptr, 1, out, 1, n),
        else => @compileError("zrvadd requires f32 or f64"),
    }
}

/// Complex vector subtract.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] - B[n];
pub fn zvsub(comptime T: type, a: *const SC(T), b: *const SC(T), out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvsub(a, 1, b, 1, out, 1, n),
        f64 => c.vDSP_zvsubD(a, 1, b, 1, out, 1, n),
        else => @compileError("zvsub requires f32 or f64"),
    }
}

/// Subtract real from complex-split.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] - B[n];
pub fn zrvsub(comptime T: type, a: *const SC(T), b: []const T, out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zrvsub(a, 1, b.ptr, 1, out, 1, n),
        f64 => c.vDSP_zrvsubD(a, 1, b.ptr, 1, out, 1, n),
        else => @compileError("zrvsub requires f32 or f64"),
    }
}

/// Complex-real vector multiply.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] * B[n];
pub fn zrvmul(comptime T: type, a: *const SC(T), b: []const T, out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zrvmul(a, 1, b.ptr, 1, out, 1, n),
        f64 => c.vDSP_zrvmulD(a, 1, b.ptr, 1, out, 1, n),
        else => @compileError("zrvmul requires f32 or f64"),
    }
}

/// Complex vector divide.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] / B[n];
pub fn zvdiv(comptime T: type, a: *const SC(T), b: *const SC(T), out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvdiv(b, 1, a, 1, out, 1, n),
        f64 => c.vDSP_zvdivD(b, 1, a, 1, out, 1, n),
        else => @compileError("zvdiv requires f32 or f64"),
    }
}

/// Complex-real vector divide.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] / B[n];
pub fn zrvdiv(comptime T: type, a: *const SC(T), b: []const T, out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zrvdiv(a, 1, b.ptr, 1, out, 1, n),
        f64 => c.vDSP_zrvdivD(a, 1, b.ptr, 1, out, 1, n),
        else => @compileError("zrvdiv requires f32 or f64"),
    }
}

/// Complex vector absolute value.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = |A[n]|;
pub fn zvabs(comptime T: type, a: *const SC(T), out: []T, n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvabs(a, 1, out.ptr, 1, n),
        f64 => c.vDSP_zvabsD(a, 1, out.ptr, 1, n),
        else => @compileError("zvabs requires f32 or f64"),
    }
}

/// Complex vector fill.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[0];
pub fn zvfill(comptime T: type, val: *const SC(T), out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvfill(val, out, 1, n),
        f64 => c.vDSP_zvfillD(val, out, 1, n),
        else => @compileError("zvfill requires f32 or f64"),
    }
}

/// Complex multiplication with optional conjugation.
/// Computes:
///     If Conjugate is +1:
///         for (n = 0; n < N; ++n)
///             C[n] = A[n] * B[n];
///     If Conjugate is -1:
///         for (n = 0; n < N; ++n)
///             C[n] = conj(A[n]) * B[n];
pub fn zvmul(comptime T: type, a: *const SC(T), b: *const SC(T), out: *SC(T), n: Length, conjugate: bool) void {
    switch (T) {
        f32 => c.vDSP_zvmul(a, 1, b, 1, out, 1, n, if (conjugate) @as(c_int, -1) else @as(c_int, 1)),
        f64 => c.vDSP_zvmulD(a, 1, b, 1, out, 1, n, if (conjugate) @as(c_int, -1) else @as(c_int, 1)),
        else => @compileError("zvmul requires f32 or f64"),
    }
}

/// Complex-split conjugate multiply and add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         D[n] = conj(A[n]) * B[n] + C[n];
pub fn zvcma(comptime T: type, a: *const SC(T), b: *const SC(T), addend: *const SC(T), out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvcma(a, 1, b, 1, addend, 1, out, 1, n),
        f64 => c.vDSP_zvcmaD(a, 1, b, 1, addend, 1, out, 1, n),
        else => @compileError("zvcma requires f32 or f64"),
    }
}

/// Complex vector multiply and add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         D[n] = A[n] * B[n] + C[n];
pub fn zvma(comptime T: type, a: *const SC(T), b: *const SC(T), addend: *const SC(T), out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvma(a, 1, b, 1, addend, 1, out, 1, n),
        f64 => c.vDSP_zvmaD(a, 1, b, 1, addend, 1, out, 1, n),
        else => @compileError("zvma requires f32 or f64"),
    }
}

/// Complex vector conjugate and multiply.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = conj(A[n]) * B[n];
pub fn zvcmul(comptime T: type, a: *const SC(T), b: *const SC(T), out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvcmul(a, 1, b, 1, out, 1, n),
        f64 => c.vDSP_zvcmulD(a, 1, b, 1, out, 1, n),
        else => @compileError("zvcmul requires f32 or f64"),
    }
}

/// Complex vector conjugate.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = conj(A[n]);
pub fn zvconj(comptime T: type, a: *const SC(T), out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvconj(a, 1, out, 1, n),
        f64 => c.vDSP_zvconjD(a, 1, out, 1, n),
        else => @compileError("zvconj requires f32 or f64"),
    }
}

/// Complex vector multiply with scalar.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] * B[0];
pub fn zvzsml(comptime T: type, a: *const SC(T), scalar: *const SC(T), out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvzsml(a, 1, scalar, out, 1, n),
        f64 => c.vDSP_zvzsmlD(a, 1, scalar, out, 1, n),
        else => @compileError("zvzsml requires f32 or f64"),
    }
}

/// Complex vector magnitudes squared.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = |A[n]| ** 2;
pub fn zvmags(comptime T: type, a: *const SC(T), out: []T, n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvmags(a, 1, out.ptr, 1, n),
        f64 => c.vDSP_zvmagsD(a, 1, out.ptr, 1, n),
        else => @compileError("zvmags requires f32 or f64"),
    }
}

/// Complex vector magnitudes square and add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = |A[n]| ** 2 + B[n];
pub fn zvmgsa(comptime T: type, a: *const SC(T), b: []const T, out: []T, n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvmgsa(a, 1, b.ptr, 1, out.ptr, 1, n),
        f64 => c.vDSP_zvmgsaD(a, 1, b.ptr, 1, out.ptr, 1, n),
        else => @compileError("zvmgsa requires f32 or f64"),
    }
}

/// Complex-split vector move.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn zvmov(comptime T: type, a: *const SC(T), out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvmov(a, 1, out, 1, n),
        f64 => c.vDSP_zvmovD(a, 1, out, 1, n),
        else => @compileError("zvmov requires f32 or f64"),
    }
}

/// Complex vector negate.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = -A[n];
pub fn zvneg(comptime T: type, a: *const SC(T), out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvneg(a, 1, out, 1, n),
        f64 => c.vDSP_zvnegD(a, 1, out, 1, n),
        else => @compileError("zvneg requires f32 or f64"),
    }
}

/// Complex vector phase.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = atan2(Im(A[n]), Re(A[n]));
pub fn zvphas(comptime T: type, a: *const SC(T), out: []T, n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvphas(a, 1, out.ptr, 1, n),
        f64 => c.vDSP_zvphasD(a, 1, out.ptr, 1, n),
        else => @compileError("zvphas requires f32 or f64"),
    }
}

/// Complex vector multiply by scalar and add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         D[n] = A[n] * B[0] + C[n];
pub fn zvsma(comptime T: type, a: *const SC(T), scalar: *const SC(T), addend: *const SC(T), out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvsma(a, 1, scalar, addend, 1, out, 1, n),
        f64 => c.vDSP_zvsmaD(a, 1, scalar, addend, 1, out, 1, n),
        else => @compileError("zvsma requires f32 or f64"),
    }
}

// ============================================================================
// Spectral / signal ops
// ============================================================================

/// Complex-split accumulating autospectrum.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] += |A[n]| ** 2;
pub fn zaspec(comptime T: type, a: *const SC(T), out: []T, n: Length) void {
    switch (T) {
        f32 => c.vDSP_zaspec(a, out.ptr, n),
        f64 => c.vDSP_zaspecD(a, out.ptr, n),
        else => @compileError("zaspec requires f32 or f64"),
    }
}

/// Coherence function.
/// Computes:
///     for (n = 0; n < N; ++n)
///         D[n] = |C[n]| ** 2 / (A[n] * B[n]);
pub fn zcoher(comptime T: type, a: []const T, b: []const T, cross: *const SC(T), out: []T, n: Length) void {
    switch (T) {
        f32 => c.vDSP_zcoher(a.ptr, b.ptr, cross, out.ptr, n),
        f64 => c.vDSP_zcoherD(a.ptr, b.ptr, cross, out.ptr, n),
        else => @compileError("zcoher requires f32 or f64"),
    }
}

/// Transfer function, B/A.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = B[n] / A[n];
pub fn ztrans(comptime T: type, a: []const T, b: *const SC(T), out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_ztrans(a.ptr, b, out, n),
        f64 => c.vDSP_ztransD(a.ptr, b, out, n),
        else => @compileError("ztrans requires f32 or f64"),
    }
}

/// Accumulating cross-spectrum.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] += conj(A[n]) * B[n];
pub fn zcspec(comptime T: type, a: *const SC(T), b: *const SC(T), out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zcspec(a, b, out, n),
        f64 => c.vDSP_zcspecD(a, b, out, n),
        else => @compileError("zcspec requires f32 or f64"),
    }
}

/// Anti-aliasing down-sample with real filter.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = sum(A[n*DF+p] * F[p], 0 <= p < P);
pub fn desamp(comptime T: type, a: [*]const T, decimation_factor: Stride, filter: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_desamp(a, decimation_factor, filter.ptr, out.ptr, out.len, filter.len),
        f64 => c.vDSP_desampD(a, decimation_factor, filter.ptr, out.ptr, out.len, filter.len),
        else => @compileError("desamp requires f32 or f64"),
    }
}

/// Anti-aliasing down-sample with real filter (complex-split).
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = sum(A[n*DF+p] * F[p], 0 <= p < P);
pub fn zrdesamp(comptime T: type, a: *const SC(T), decimation_factor: Stride, filter: []const T, out: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zrdesamp(a, decimation_factor, filter.ptr, out, n, filter.len),
        f64 => c.vDSP_zrdesampD(a, decimation_factor, filter.ptr, out, n, filter.len),
        else => @compileError("zrdesamp requires f32 or f64"),
    }
}

// ============================================================================
// Tests
// ============================================================================

test "zvdiv" {
    // a/b != b/a for these asymmetric operands, so an argument-order bug
    // (dividing b/a instead of a/b) would fail this test.
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    var b_re = [_]f32{3.0};
    var b_im = [_]f32{4.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SC(f32){ .realp = &a_re, .imagp = &a_im };
    const b = SC(f32){ .realp = &b_re, .imagp = &b_im };
    var out = SC(f32){ .realp = &out_re, .imagp = &out_im };

    zvdiv(f32, &a, &b, &out, 1);

    // (1+2i)/(3+4i) = (1+2i)(3-4i)/25 = (11+2i)/25 = 0.44 + 0.08i
    try std.testing.expectApproxEqAbs(@as(f32, 0.44), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.08), out_im[0], 0.001);
}
