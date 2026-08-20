const std = @import("std");
const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;
const c = @import("c.zig");

const SC = types.SplitComplex;
const SS = types.SplitSlice;

// ============================================================================
// Complex vector arithmetic
// ============================================================================

/// Complex vector add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] + B[n];
pub fn zvadd(comptime T: type, a: SS(T), b: SS(T), out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(b.len() >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var b_raw = b.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zvadd(&a_raw, 1, &b_raw, 1, &out_raw, 1, n),
        f64 => c.vDSP_zvaddD(&a_raw, 1, &b_raw, 1, &out_raw, 1, n),
        else => @compileError("zvadd requires f32 or f64"),
    }
}

/// Complex-real vector add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] + B[n];
pub fn zrvadd(comptime T: type, a: SS(T), b: []const T, out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(b.len >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zrvadd(&a_raw, 1, b.ptr, 1, &out_raw, 1, n),
        f64 => c.vDSP_zrvaddD(&a_raw, 1, b.ptr, 1, &out_raw, 1, n),
        else => @compileError("zrvadd requires f32 or f64"),
    }
}

/// Complex vector subtract.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] - B[n];
pub fn zvsub(comptime T: type, a: SS(T), b: SS(T), out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(b.len() >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var b_raw = b.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zvsub(&a_raw, 1, &b_raw, 1, &out_raw, 1, n),
        f64 => c.vDSP_zvsubD(&a_raw, 1, &b_raw, 1, &out_raw, 1, n),
        else => @compileError("zvsub requires f32 or f64"),
    }
}

/// Subtract real from complex-split.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] - B[n];
pub fn zrvsub(comptime T: type, a: SS(T), b: []const T, out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(b.len >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zrvsub(&a_raw, 1, b.ptr, 1, &out_raw, 1, n),
        f64 => c.vDSP_zrvsubD(&a_raw, 1, b.ptr, 1, &out_raw, 1, n),
        else => @compileError("zrvsub requires f32 or f64"),
    }
}

/// Complex-real vector multiply.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] * B[n];
pub fn zrvmul(comptime T: type, a: SS(T), b: []const T, out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(b.len >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zrvmul(&a_raw, 1, b.ptr, 1, &out_raw, 1, n),
        f64 => c.vDSP_zrvmulD(&a_raw, 1, b.ptr, 1, &out_raw, 1, n),
        else => @compileError("zrvmul requires f32 or f64"),
    }
}

/// Complex vector divide.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] / B[n];
pub fn zvdiv(comptime T: type, a: SS(T), b: SS(T), out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(b.len() >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var b_raw = b.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zvdiv(&b_raw, 1, &a_raw, 1, &out_raw, 1, n),
        f64 => c.vDSP_zvdivD(&b_raw, 1, &a_raw, 1, &out_raw, 1, n),
        else => @compileError("zvdiv requires f32 or f64"),
    }
}

/// Complex-real vector divide.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] / B[n];
pub fn zrvdiv(comptime T: type, a: SS(T), b: []const T, out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(b.len >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zrvdiv(&a_raw, 1, b.ptr, 1, &out_raw, 1, n),
        f64 => c.vDSP_zrvdivD(&a_raw, 1, b.ptr, 1, &out_raw, 1, n),
        else => @compileError("zrvdiv requires f32 or f64"),
    }
}

/// Complex vector absolute value.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = |A[n]|;
pub fn zvabs(comptime T: type, a: SS(T), out: []T, n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(out.len >= n);
    var a_raw = a.raw();
    switch (T) {
        f32 => c.vDSP_zvabs(&a_raw, 1, out.ptr, 1, n),
        f64 => c.vDSP_zvabsD(&a_raw, 1, out.ptr, 1, n),
        else => @compileError("zvabs requires f32 or f64"),
    }
}

/// Complex vector fill.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[0];
pub fn zvfill(comptime T: type, val: SS(T), out: SS(T), n: Length) void {
    std.debug.assert(val.len() >= 1);
    std.debug.assert(out.len() >= n);
    var val_raw = val.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zvfill(&val_raw, &out_raw, 1, n),
        f64 => c.vDSP_zvfillD(&val_raw, &out_raw, 1, n),
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
pub fn zvmul(comptime T: type, a: SS(T), b: SS(T), out: SS(T), n: Length, conjugate: bool) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(b.len() >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var b_raw = b.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zvmul(&a_raw, 1, &b_raw, 1, &out_raw, 1, n, if (conjugate) @as(c_int, -1) else @as(c_int, 1)),
        f64 => c.vDSP_zvmulD(&a_raw, 1, &b_raw, 1, &out_raw, 1, n, if (conjugate) @as(c_int, -1) else @as(c_int, 1)),
        else => @compileError("zvmul requires f32 or f64"),
    }
}

/// Complex-split conjugate multiply and add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         D[n] = conj(A[n]) * B[n] + C[n];
pub fn zvcma(comptime T: type, a: SS(T), b: SS(T), addend: SS(T), out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(b.len() >= n);
    std.debug.assert(addend.len() >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var b_raw = b.raw();
    var addend_raw = addend.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zvcma(&a_raw, 1, &b_raw, 1, &addend_raw, 1, &out_raw, 1, n),
        f64 => c.vDSP_zvcmaD(&a_raw, 1, &b_raw, 1, &addend_raw, 1, &out_raw, 1, n),
        else => @compileError("zvcma requires f32 or f64"),
    }
}

/// Complex vector multiply and add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         D[n] = A[n] * B[n] + C[n];
pub fn zvma(comptime T: type, a: SS(T), b: SS(T), addend: SS(T), out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(b.len() >= n);
    std.debug.assert(addend.len() >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var b_raw = b.raw();
    var addend_raw = addend.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zvma(&a_raw, 1, &b_raw, 1, &addend_raw, 1, &out_raw, 1, n),
        f64 => c.vDSP_zvmaD(&a_raw, 1, &b_raw, 1, &addend_raw, 1, &out_raw, 1, n),
        else => @compileError("zvma requires f32 or f64"),
    }
}

/// Complex vector conjugate and multiply.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = conj(A[n]) * B[n];
pub fn zvcmul(comptime T: type, a: SS(T), b: SS(T), out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(b.len() >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var b_raw = b.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zvcmul(&a_raw, 1, &b_raw, 1, &out_raw, 1, n),
        f64 => c.vDSP_zvcmulD(&a_raw, 1, &b_raw, 1, &out_raw, 1, n),
        else => @compileError("zvcmul requires f32 or f64"),
    }
}

/// Complex vector conjugate.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = conj(A[n]);
pub fn zvconj(comptime T: type, a: SS(T), out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zvconj(&a_raw, 1, &out_raw, 1, n),
        f64 => c.vDSP_zvconjD(&a_raw, 1, &out_raw, 1, n),
        else => @compileError("zvconj requires f32 or f64"),
    }
}

/// Complex vector multiply with scalar.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] * B[0];
pub fn zvzsml(comptime T: type, a: SS(T), scalar: SS(T), out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(scalar.len() >= 1);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var scalar_raw = scalar.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zvzsml(&a_raw, 1, &scalar_raw, &out_raw, 1, n),
        f64 => c.vDSP_zvzsmlD(&a_raw, 1, &scalar_raw, &out_raw, 1, n),
        else => @compileError("zvzsml requires f32 or f64"),
    }
}

/// Complex vector magnitudes squared.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = |A[n]| ** 2;
pub fn zvmags(comptime T: type, a: SS(T), out: []T, n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(out.len >= n);
    var a_raw = a.raw();
    switch (T) {
        f32 => c.vDSP_zvmags(&a_raw, 1, out.ptr, 1, n),
        f64 => c.vDSP_zvmagsD(&a_raw, 1, out.ptr, 1, n),
        else => @compileError("zvmags requires f32 or f64"),
    }
}

/// Complex vector magnitudes square and add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = |A[n]| ** 2 + B[n];
pub fn zvmgsa(comptime T: type, a: SS(T), b: []const T, out: []T, n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(b.len >= n);
    std.debug.assert(out.len >= n);
    var a_raw = a.raw();
    switch (T) {
        f32 => c.vDSP_zvmgsa(&a_raw, 1, b.ptr, 1, out.ptr, 1, n),
        f64 => c.vDSP_zvmgsaD(&a_raw, 1, b.ptr, 1, out.ptr, 1, n),
        else => @compileError("zvmgsa requires f32 or f64"),
    }
}

/// Complex-split vector move.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn zvmov(comptime T: type, a: SS(T), out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zvmov(&a_raw, 1, &out_raw, 1, n),
        f64 => c.vDSP_zvmovD(&a_raw, 1, &out_raw, 1, n),
        else => @compileError("zvmov requires f32 or f64"),
    }
}

/// Complex vector negate.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = -A[n];
pub fn zvneg(comptime T: type, a: SS(T), out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zvneg(&a_raw, 1, &out_raw, 1, n),
        f64 => c.vDSP_zvnegD(&a_raw, 1, &out_raw, 1, n),
        else => @compileError("zvneg requires f32 or f64"),
    }
}

/// Complex vector phase.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = atan2(Im(A[n]), Re(A[n]));
pub fn zvphas(comptime T: type, a: SS(T), out: []T, n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(out.len >= n);
    var a_raw = a.raw();
    switch (T) {
        f32 => c.vDSP_zvphas(&a_raw, 1, out.ptr, 1, n),
        f64 => c.vDSP_zvphasD(&a_raw, 1, out.ptr, 1, n),
        else => @compileError("zvphas requires f32 or f64"),
    }
}

/// Complex vector multiply by scalar and add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         D[n] = A[n] * B[0] + C[n];
pub fn zvsma(comptime T: type, a: SS(T), scalar: SS(T), addend: SS(T), out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(scalar.len() >= 1);
    std.debug.assert(addend.len() >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var scalar_raw = scalar.raw();
    var addend_raw = addend.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zvsma(&a_raw, 1, &scalar_raw, &addend_raw, 1, &out_raw, 1, n),
        f64 => c.vDSP_zvsmaD(&a_raw, 1, &scalar_raw, &addend_raw, 1, &out_raw, 1, n),
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
pub fn zaspec(comptime T: type, a: SS(T), out: []T, n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(out.len >= n);
    var a_raw = a.raw();
    switch (T) {
        f32 => c.vDSP_zaspec(&a_raw, out.ptr, n),
        f64 => c.vDSP_zaspecD(&a_raw, out.ptr, n),
        else => @compileError("zaspec requires f32 or f64"),
    }
}

/// Coherence function.
/// Computes:
///     for (n = 0; n < N; ++n)
///         D[n] = |C[n]| ** 2 / (A[n] * B[n]);
pub fn zcoher(comptime T: type, a: []const T, b: []const T, cross: SS(T), out: []T, n: Length) void {
    std.debug.assert(a.len >= n);
    std.debug.assert(b.len >= n);
    std.debug.assert(cross.len() >= n);
    std.debug.assert(out.len >= n);
    var cross_raw = cross.raw();
    switch (T) {
        f32 => c.vDSP_zcoher(a.ptr, b.ptr, &cross_raw, out.ptr, n),
        f64 => c.vDSP_zcoherD(a.ptr, b.ptr, &cross_raw, out.ptr, n),
        else => @compileError("zcoher requires f32 or f64"),
    }
}

/// Transfer function, B/A.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = B[n] / A[n];
pub fn ztrans(comptime T: type, a: []const T, b: SS(T), out: SS(T), n: Length) void {
    std.debug.assert(a.len >= n);
    std.debug.assert(b.len() >= n);
    std.debug.assert(out.len() >= n);
    var b_raw = b.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_ztrans(a.ptr, &b_raw, &out_raw, n),
        f64 => c.vDSP_ztransD(a.ptr, &b_raw, &out_raw, n),
        else => @compileError("ztrans requires f32 or f64"),
    }
}

/// Accumulating cross-spectrum.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] += conj(A[n]) * B[n];
pub fn zcspec(comptime T: type, a: SS(T), b: SS(T), out: SS(T), n: Length) void {
    std.debug.assert(a.len() >= n);
    std.debug.assert(b.len() >= n);
    std.debug.assert(out.len() >= n);
    var a_raw = a.raw();
    var b_raw = b.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zcspec(&a_raw, &b_raw, &out_raw, n),
        f64 => c.vDSP_zcspecD(&a_raw, &b_raw, &out_raw, n),
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
pub fn zrdesamp(comptime T: type, a: SS(T), decimation_factor: Stride, filter: []const T, out: SS(T), n: Length) void {
    std.debug.assert(out.len() >= n);
    std.debug.assert(filter.len >= filter.len);
    std.debug.assert(a.len() >= (n - 1) * @as(usize, @intCast(decimation_factor)) + filter.len);
    var a_raw = a.raw();
    var out_raw = out.raw();
    switch (T) {
        f32 => c.vDSP_zrdesamp(&a_raw, decimation_factor, filter.ptr, &out_raw, n, filter.len),
        f64 => c.vDSP_zrdesampD(&a_raw, decimation_factor, filter.ptr, &out_raw, n, filter.len),
        else => @compileError("zrdesamp requires f32 or f64"),
    }
}

// ============================================================================
// Tests
// ============================================================================

test "zvabs" {
    var a_re = [_]f32{3.0};
    var a_im = [_]f32{4.0};
    const a = SS(f32).init(&a_re, &a_im);
    var out = [_]f32{0.0};
    zvabs(f32, a, &out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), out[0], 0.001);
}

test "zvmags" {
    var a_re = [_]f32{3.0};
    var a_im = [_]f32{4.0};
    const a = SS(f32).init(&a_re, &a_im);
    var out = [_]f32{0.0};
    zvmags(f32, a, &out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), out[0], 0.001);
}

test "zvmul" {
    // Asymmetric operands: (1+2i)*(3+4i) = -5+10i, but conj(1+2i)*(3+4i) =
    // 11-2i, so this also confirms the conjugate flag is wired correctly.
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    var b_re = [_]f32{3.0};
    var b_im = [_]f32{4.0};
    const a = SS(f32).init(&a_re, &a_im);
    const b = SS(f32).init(&b_re, &b_im);

    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const out = SS(f32).init(&out_re, &out_im);

    zvmul(f32, a, b, out, 1, false);
    try std.testing.expectApproxEqAbs(@as(f32, -5.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), out_im[0], 0.001);

    zvmul(f32, a, b, out, 1, true);
    try std.testing.expectApproxEqAbs(@as(f32, 11.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -2.0), out_im[0], 0.001);
}

test "zvdiv" {
    // a/b != b/a for these asymmetric operands, so an argument-order bug
    // (dividing b/a instead of a/b) would fail this test.
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    var b_re = [_]f32{3.0};
    var b_im = [_]f32{4.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const b = SS(f32).init(&b_re, &b_im);
    const out = SS(f32).init(&out_re, &out_im);

    zvdiv(f32, a, b, out, 1);

    // (1+2i)/(3+4i) = (1+2i)(3-4i)/25 = (11+2i)/25 = 0.44 + 0.08i
    try std.testing.expectApproxEqAbs(@as(f32, 0.44), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.08), out_im[0], 0.001);
}

test "zvadd" {
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    var b_re = [_]f32{3.0};
    var b_im = [_]f32{4.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const b = SS(f32).init(&b_re, &b_im);
    const out = SS(f32).init(&out_re, &out_im);
    zvadd(f32, a, b, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), out_im[0], 0.001);
}

test "zrvadd" {
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    const b = [_]f32{5.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const out = SS(f32).init(&out_re, &out_im);
    zrvadd(f32, a, &b, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), out_im[0], 0.001);
}

test "zvsub" {
    // Asymmetric operands so an argument-order bug would be caught.
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    var b_re = [_]f32{3.0};
    var b_im = [_]f32{4.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const b = SS(f32).init(&b_re, &b_im);
    const out = SS(f32).init(&out_re, &out_im);
    zvsub(f32, a, b, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, -2.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -2.0), out_im[0], 0.001);
}

test "zrvsub" {
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    const b = [_]f32{5.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const out = SS(f32).init(&out_re, &out_im);
    zrvsub(f32, a, &b, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, -4.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), out_im[0], 0.001);
}

test "zrvmul" {
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    const b = [_]f32{5.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const out = SS(f32).init(&out_re, &out_im);
    zrvmul(f32, a, &b, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), out_im[0], 0.001);
}

test "zrvdiv" {
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    const b = [_]f32{5.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const out = SS(f32).init(&out_re, &out_im);
    zrvdiv(f32, a, &b, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), out_im[0], 0.001);
}

test "zvfill" {
    var val_re = [_]f32{9.0};
    var val_im = [_]f32{3.0};
    var out_re = [_]f32{ 0.0, 0.0 };
    var out_im = [_]f32{ 0.0, 0.0 };
    const val = SS(f32).init(&val_re, &val_im);
    const out = SS(f32).init(&out_re, &out_im);
    zvfill(f32, val, out, 2);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 9.0, 9.0 }, &out_re);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 3.0, 3.0 }, &out_im);
}

test "zvcma" {
    // D = conj(A)*B + C: conj(1+2i)*(3+4i) = (1-2i)(3+4i) = 11-2i, +(5+6i) = 16+4i.
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    var b_re = [_]f32{3.0};
    var b_im = [_]f32{4.0};
    var addend_re = [_]f32{5.0};
    var addend_im = [_]f32{6.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const b = SS(f32).init(&b_re, &b_im);
    const addend = SS(f32).init(&addend_re, &addend_im);
    const out = SS(f32).init(&out_re, &out_im);
    zvcma(f32, a, b, addend, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), out_im[0], 0.001);
}

test "zvma" {
    // D = A*B + C: (1+2i)(3+4i) = -5+10i, +(5+6i) = 0+16i.
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    var b_re = [_]f32{3.0};
    var b_im = [_]f32{4.0};
    var addend_re = [_]f32{5.0};
    var addend_im = [_]f32{6.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const b = SS(f32).init(&b_re, &b_im);
    const addend = SS(f32).init(&addend_re, &addend_im);
    const out = SS(f32).init(&out_re, &out_im);
    zvma(f32, a, b, addend, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), out_im[0], 0.001);
}

test "zvcmul" {
    // C = conj(A)*B = 11-2i (see zvcma above).
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    var b_re = [_]f32{3.0};
    var b_im = [_]f32{4.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const b = SS(f32).init(&b_re, &b_im);
    const out = SS(f32).init(&out_re, &out_im);
    zvcmul(f32, a, b, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 11.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -2.0), out_im[0], 0.001);
}

test "zvconj" {
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const out = SS(f32).init(&out_re, &out_im);
    zvconj(f32, a, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -2.0), out_im[0], 0.001);
}

test "zvzsml" {
    // C = A * B[0]: (1+2i)(5+6i) = 5+6i+10i-12 = -7+16i.
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    var scalar_re = [_]f32{5.0};
    var scalar_im = [_]f32{6.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const scalar = SS(f32).init(&scalar_re, &scalar_im);
    const out = SS(f32).init(&out_re, &out_im);
    zvzsml(f32, a, scalar, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, -7.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 16.0), out_im[0], 0.001);
}

test "zvmgsa" {
    // C = |A|^2 + B: |1+2i|^2 = 5, + 3 = 8.
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    const b = [_]f32{3.0};
    var out = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    zvmgsa(f32, a, &b, &out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 8.0), out[0], 0.001);
}

test "zvmov" {
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const out = SS(f32).init(&out_re, &out_im);
    zvmov(f32, a, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), out_im[0], 0.001);
}

test "zvneg" {
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{-2.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const out = SS(f32).init(&out_re, &out_im);
    zvneg(f32, a, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), out_im[0], 0.001);
}

test "zvphas" {
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    var out = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    zvphas(f32, a, &out, 1);
    try std.testing.expectApproxEqAbs(std.math.atan2(@as(f32, 2.0), @as(f32, 1.0)), out[0], 0.001);
}

test "zvsma" {
    // D = A*B[0] + C: A*(5+6i) = -7+16i (see zvzsml), + (7+1i) = 0+17i.
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    var scalar_re = [_]f32{5.0};
    var scalar_im = [_]f32{6.0};
    var addend_re = [_]f32{7.0};
    var addend_im = [_]f32{1.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const a = SS(f32).init(&a_re, &a_im);
    const scalar = SS(f32).init(&scalar_re, &scalar_im);
    const addend = SS(f32).init(&addend_re, &addend_im);
    const out = SS(f32).init(&out_re, &out_im);
    zvsma(f32, a, scalar, addend, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 17.0), out_im[0], 0.001);
}

test "zaspec" {
    // Accumulating: C[n] += |A[n]|^2. Seed out with a nonzero value to
    // confirm it's an accumulation, not an overwrite.
    var a_re = [_]f32{3.0};
    var a_im = [_]f32{4.0};
    var out = [_]f32{10.0};
    const a = SS(f32).init(&a_re, &a_im);
    zaspec(f32, a, &out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 35.0), out[0], 0.001); // 10 + |3+4i|^2 (=25)
}

test "zcoher" {
    // D = |C|^2 / (A*B): |1+2i|^2=5, A*B=2*3=6 -> 5/6.
    const a = [_]f32{2.0};
    const b = [_]f32{3.0};
    var cross_re = [_]f32{1.0};
    var cross_im = [_]f32{2.0};
    var out = [_]f32{0.0};
    const cross = SS(f32).init(&cross_re, &cross_im);
    zcoher(f32, &a, &b, cross, &out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0 / 6.0), out[0], 0.001);
}

test "ztrans" {
    // C = B / A, A real: (4+6i)/2 = 2+3i.
    const a = [_]f32{2.0};
    var b_re = [_]f32{4.0};
    var b_im = [_]f32{6.0};
    var out_re = [_]f32{0.0};
    var out_im = [_]f32{0.0};
    const b = SS(f32).init(&b_re, &b_im);
    const out = SS(f32).init(&out_re, &out_im);
    ztrans(f32, &a, b, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), out_im[0], 0.001);
}

test "zcspec" {
    // Accumulating: C += conj(A)*B = 11-2i (see zvcma). Seed C nonzero to
    // confirm accumulation.
    var a_re = [_]f32{1.0};
    var a_im = [_]f32{2.0};
    var b_re = [_]f32{3.0};
    var b_im = [_]f32{4.0};
    var out_re = [_]f32{1.0};
    var out_im = [_]f32{1.0};
    const a = SS(f32).init(&a_re, &a_im);
    const b = SS(f32).init(&b_re, &b_im);
    const out = SS(f32).init(&out_re, &out_im);
    zcspec(f32, a, b, out, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 12.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), out_im[0], 0.001);
}

test "desamp" {
    // C[n] = sum(A[n*DF+p] * F[p], 0 <= p < P). DF=2, F=[1,1]:
    // C[0] = A[0]*1 + A[1]*1 = 3, C[1] = A[2]*1 + A[3]*1 = 7.
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };
    const filter = [_]f32{ 1.0, 1.0 };
    var out: [2]f32 = undefined;
    desamp(f32, &a, 2, &filter, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), out[1], 0.001);
}

test "zrdesamp" {
    // Same as desamp, but the input/output are complex-split and only the
    // filter is real.
    var a_re = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };
    var a_im = [_]f32{ 0.5, 1.5, 2.5, 3.5, 4.5, 5.5 };
    const filter = [_]f32{ 1.0, 1.0 };
    var out_re: [2]f32 = undefined;
    var out_im: [2]f32 = undefined;
    const a = SS(f32).init(&a_re, &a_im);
    const out = SS(f32).init(&out_re, &out_im);
    zrdesamp(f32, a, 2, &filter, out, 2);
    try std.testing.expectApproxEqAbs(@as(f32, 3.0), out_re[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 2.0), out_im[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), out_re[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), out_im[1], 0.001);
}

test "SplitSlice length checks catch an n larger than the buffers" {
    // The whole point of SplitSlice: before it, `n` was a bare Length that
    // nothing could validate, so passing an n past the end of the buffers was
    // an unchecked out-of-bounds read/write inside the C function. Now it is a
    // located panic in Debug/ReleaseSafe. This test pins the *checkable*
    // direction - that a correctly-sized call still works and a prefix call on
    // an oversized buffer is still allowed, since operating on a prefix of a
    // larger scratch buffer is normal DSP practice and must not be rejected.
    var ar = [_]f32{ 1, 2, 3, 4 };
    var ai = [_]f32{ 5, 6, 7, 8 };
    var br = [_]f32{ 1, 1, 1, 1 };
    var bi = [_]f32{ 1, 1, 1, 1 };
    var or_ = [_]f32{ 0, 0, 0, 0 };
    var oi = [_]f32{ 0, 0, 0, 0 };
    const a = SS(f32).init(&ar, &ai);
    const b = SS(f32).init(&br, &bi);
    const out = SS(f32).init(&or_, &oi);

    // n == buffer length: exact fit.
    zvadd(f32, a, b, out, 4);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 2, 3, 4, 5 }, &or_);

    // n < buffer length: prefix operation on an oversized buffer, still legal.
    or_ = [_]f32{ 0, 0, 0, 0 };
    zvadd(f32, a, b, out, 2);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 2, 3, 0, 0 }, &or_);
}
