const std = @import("std");
const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;
const SplitComplex = types.SplitComplex;
const DoubleSplitComplex = types.DoubleSplitComplex;
const c = @import("c.zig");

const SC = types.SC;

// ============================================================================
// Fill
// ============================================================================

/// Vector fill.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[0];
pub fn vfill(comptime T: type, val: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vfill(&val, out.ptr, 1, out.len),
        f64 => c.vDSP_vfillD(&val, out.ptr, 1, out.len),
        i32 => c.vDSP_vfilli(&val, out.ptr, 1, out.len),
        else => @compileError("vfill requires f32, f64, or i32"),
    }
}

// ============================================================================
// Binary vector ops
// ============================================================================

/// Vector add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] + B[n];
pub fn vadd(comptime T: type, a: []const T, b: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vadd(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vaddD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        i32 => c.vDSP_vaddi(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vadd requires f32, f64, or i32"),
    }
}

/// Vector subtract.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] - B[n];
pub fn vsub(comptime T: type, a: []const T, b: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vsub(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vsubD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vsub requires f32 or f64"),
    }
}

/// Vector multiply.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] * B[n];
pub fn vmul(comptime T: type, a: []const T, b: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vmul(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vmulD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vmul requires f32 or f64"),
    }
}

/// Vector divide.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] / B[n];
pub fn vdiv(comptime T: type, a: []const T, b: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vdiv(b.ptr, 1, a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vdivD(b.ptr, 1, a.ptr, 1, out.ptr, 1, a.len),
        i32 => c.vDSP_vdivi(b.ptr, 1, a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vdiv requires f32, f64, or i32"),
    }
}

/// Vector bit-wise equivalence, NOT (A XOR B).
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = ~(A[n] ^ B[n]);
pub fn veqvi(a: []const i32, b: []const i32, out: []i32) void {
    c.vDSP_veqvi(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

// ============================================================================
// Scalar-vector ops
// ============================================================================

/// Vector-scalar multiply.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] * B[0];
pub fn vsmul(comptime T: type, a: []const T, scalar: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vsmul(a.ptr, 1, &scalar, out.ptr, 1, a.len),
        f64 => c.vDSP_vsmulD(a.ptr, 1, &scalar, out.ptr, 1, a.len),
        else => @compileError("vsmul requires f32 or f64"),
    }
}

/// Vector-scalar add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] + B[0];
pub fn vsadd(comptime T: type, a: []const T, scalar: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vsadd(a.ptr, 1, &scalar, out.ptr, 1, a.len),
        f64 => c.vDSP_vsaddD(a.ptr, 1, &scalar, out.ptr, 1, a.len),
        i32 => c.vDSP_vsaddi(a.ptr, 1, &scalar, out.ptr, 1, a.len),
        else => @compileError("vsadd requires f32, f64, or i32"),
    }
}

/// Vector-scalar divide.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] / B[0];
pub fn vsdiv(comptime T: type, a: []const T, scalar: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vsdiv(a.ptr, 1, &scalar, out.ptr, 1, a.len),
        f64 => c.vDSP_vsdivD(a.ptr, 1, &scalar, out.ptr, 1, a.len),
        i32 => c.vDSP_vsdivi(a.ptr, 1, &scalar, out.ptr, 1, a.len),
        else => @compileError("vsdiv requires f32, f64, or i32"),
    }
}

/// Scalar / vector: C[n] = scalar / B[n]
pub fn svdiv(comptime T: type, scalar: T, b: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_svdiv(&scalar, b.ptr, 1, out.ptr, 1, b.len),
        f64 => c.vDSP_svdivD(&scalar, b.ptr, 1, out.ptr, 1, b.len),
        else => @compileError("svdiv requires f32 or f64"),
    }
}

// ============================================================================
// Multiply-add variants
// ============================================================================

/// Vector multiply and add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         D[n] = A[n] * B[n] + C[n];
pub fn vma(comptime T: type, a: []const T, b: []const T, addend: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vma(a.ptr, 1, b.ptr, 1, addend.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vmaD(a.ptr, 1, b.ptr, 1, addend.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vma requires f32 or f64"),
    }
}

/// D[n] = A[n] * B[n] + scalar
pub fn vmsa(comptime T: type, a: []const T, b: []const T, scalar: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vmsa(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len),
        f64 => c.vDSP_vmsaD(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len),
        else => @compileError("vmsa requires f32 or f64"),
    }
}

/// D[n] = A[n] * scalar + C[n]
pub fn vsma(comptime T: type, a: []const T, scalar: T, addend: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vsma(a.ptr, 1, &scalar, addend.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vsmaD(a.ptr, 1, &scalar, addend.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vsma requires f32 or f64"),
    }
}

/// Vector add and multiply.
/// Computes:
///     for (n = 0; n < N; ++n)
///         D[n] = (A[n] + B[n]) * C[n];
pub fn vam(comptime T: type, a: []const T, b: []const T, multiplier: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vam(a.ptr, 1, b.ptr, 1, multiplier.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vamD(a.ptr, 1, b.ptr, 1, multiplier.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vam requires f32 or f64"),
    }
}

/// D[n] = A[n] * B[n] - C[n]
pub fn vmsb(comptime T: type, a: []const T, b: []const T, subtrahend: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vmsb(a.ptr, 1, b.ptr, 1, subtrahend.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vmsbD(a.ptr, 1, b.ptr, 1, subtrahend.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vmsb requires f32 or f64"),
    }
}

/// E[n] = A[n]*B[n] + C[n]*D[n]
pub fn vmma(comptime T: type, a: []const T, b: []const T, c_vec: []const T, d: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vmma(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vmmaD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vmma requires f32 or f64"),
    }
}

/// E[n] = A[n]*B[n] - C[n]*D[n]
pub fn vmmsb(comptime T: type, a: []const T, b: []const T, c_vec: []const T, d: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vmmsb(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vmmsbD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vmmsb requires f32 or f64"),
    }
}

/// D[n] = A[n] * scalar + scalar2
pub fn vsmsa(comptime T: type, a: []const T, scalar: T, scalar2: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vsmsa(a.ptr, 1, &scalar, &scalar2, out.ptr, 1, a.len),
        f64 => c.vDSP_vsmsaD(a.ptr, 1, &scalar, &scalar2, out.ptr, 1, a.len),
        else => @compileError("vsmsa requires f32 or f64"),
    }
}

/// D[n] = A[n] * scalar - C[n]
pub fn vsmsb(comptime T: type, a: []const T, scalar: T, subtrahend: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vsmsb(a.ptr, 1, &scalar, subtrahend.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vsmsbD(a.ptr, 1, &scalar, subtrahend.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vsmsb requires f32 or f64"),
    }
}

/// E[n] = A[n]*scalarA + C[n]*scalarB
pub fn vsmsma(comptime T: type, a: []const T, scalar_a: T, b: []const T, scalar_b: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vsmsma(a.ptr, 1, &scalar_a, b.ptr, 1, &scalar_b, out.ptr, 1, a.len),
        f64 => c.vDSP_vsmsmaD(a.ptr, 1, &scalar_a, b.ptr, 1, &scalar_b, out.ptr, 1, a.len),
        else => @compileError("vsmsma requires f32 or f64"),
    }
}

// ============================================================================
// Add-add-multiply, add-sub-multiply, add-scalar-multiply
// ============================================================================

/// E[n] = (A[n] + B[n]) * (C[n] + D[n])
pub fn vaam(comptime T: type, a: []const T, b: []const T, c_vec: []const T, d: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vaam(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vaamD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vaam requires f32 or f64"),
    }
}

/// E[n] = (A[n] + B[n]) * (C[n] - D[n])
pub fn vasbm(comptime T: type, a: []const T, b: []const T, c_vec: []const T, d: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vasbm(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vasbmD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vasbm requires f32 or f64"),
    }
}

/// D[n] = (A[n] + B[n]) * scalar
pub fn vasm(comptime T: type, a: []const T, b: []const T, scalar: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vasm(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len),
        f64 => c.vDSP_vasmD(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len),
        else => @compileError("vasm requires f32 or f64"),
    }
}

// ============================================================================
// Subtract-multiply combos
// ============================================================================

/// D[n] = (A[n] - B[n]) * C[n]
pub fn vsbm(comptime T: type, a: []const T, b: []const T, multiplier: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vsbm(a.ptr, 1, b.ptr, 1, multiplier.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vsbmD(a.ptr, 1, b.ptr, 1, multiplier.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vsbm requires f32 or f64"),
    }
}

/// E[n] = (A[n] - B[n]) * (C[n] - D[n])
pub fn vsbsbm(comptime T: type, a: []const T, b: []const T, c_vec: []const T, d: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vsbsbm(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vsbsbmD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vsbsbm requires f32 or f64"),
    }
}

/// D[n] = (A[n] - B[n]) * scalar
pub fn vsbsm(comptime T: type, a: []const T, b: []const T, scalar: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vsbsm(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len),
        f64 => c.vDSP_vsbsmD(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len),
        else => @compileError("vsbsm requires f32 or f64"),
    }
}

// ============================================================================
// Linear average
// ============================================================================

/// C[n] = (C[n]*scalar + A[n]) / (scalar + 1)
pub fn vavlin(comptime T: type, a: []const T, scalar: T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vavlin(a.ptr, 1, &scalar, out.ptr, 1, a.len),
        f64 => c.vDSP_vavlinD(a.ptr, 1, &scalar, out.ptr, 1, a.len),
        else => @compileError("vavlin requires f32 or f64"),
    }
}

// ============================================================================
// Pythagoras
// ============================================================================

/// E[n] = sqrt((A[n]-C[n])^2 + (B[n]-D[n])^2)
pub fn vpythg(comptime T: type, a: []const T, b: []const T, c_vec: []const T, d: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vpythg(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vpythgD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vpythg requires f32 or f64"),
    }
}

// ============================================================================
// Unary ops
// ============================================================================

/// Vector square.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n]**2;
pub fn vsq(comptime T: type, a: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vsq(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vsqD(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vsq requires f32 or f64"),
    }
}

/// Vector signed square.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] * |A[n]|;
pub fn vssq(comptime T: type, a: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vssq(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vssqD(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vssq requires f32 or f64"),
    }
}

/// Vector absolute value.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = |A[n]|;
pub fn vabs(comptime T: type, a: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vabs(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vabsD(a.ptr, 1, out.ptr, 1, a.len),
        i32 => c.vDSP_vabsi(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vabs requires f32, f64, or i32"),
    }
}

pub fn vneg(comptime T: type, a: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vneg(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vnegD(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vneg requires f32 or f64"),
    }
}

/// C[n] = -|A[n]|
pub fn vnabs(comptime T: type, a: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vnabs(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vnabsD(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vnabs requires f32 or f64"),
    }
}

pub fn vfrac(comptime T: type, a: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vfrac(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfracD(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfrac requires f32 or f64"),
    }
}

pub fn vdist(comptime T: type, a: []const T, b: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vdist(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vdistD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vdist requires f32 or f64"),
    }
}

/// Euclidean distance, squared.
/// Computes:
///     C[0] = sum((A[n] - B[n]) ** 2, 0 <= n < N);
pub fn distancesq(comptime T: type, a: []const T, b: []const T) T {
    var result: T = undefined;
    switch (T) {
        f32 => c.vDSP_distancesq(a.ptr, 1, b.ptr, 1, &result, a.len),
        f64 => c.vDSP_distancesqD(a.ptr, 1, b.ptr, 1, &result, a.len),
        else => @compileError("distancesq requires f32 or f64"),
    }
    return result;
}

// ============================================================================
// Complex vector arithmetic
// ============================================================================

/// Complex vector add.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] + B[n];
pub fn zvadd(comptime T: type, a: *const SC(T), b: *const SC(T), out: *const SC(T), n: Length) void {
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
pub fn zrvadd(comptime T: type, a: *const SC(T), b: []const T, out: *const SC(T), n: Length) void {
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
pub fn zvsub(comptime T: type, a: *const SC(T), b: *const SC(T), out: *const SC(T), n: Length) void {
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
pub fn zrvsub(comptime T: type, a: *const SC(T), b: []const T, out: *const SC(T), n: Length) void {
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
pub fn zrvmul(comptime T: type, a: *const SC(T), b: []const T, out: *const SC(T), n: Length) void {
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
pub fn zvdiv(comptime T: type, a: *const SC(T), b: *const SC(T), out: *const SC(T), n: Length) void {
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
pub fn zrvdiv(comptime T: type, a: *const SC(T), b: []const T, out: *const SC(T), n: Length) void {
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
pub fn zvfill(comptime T: type, val: *const SC(T), out: *const SC(T), n: Length) void {
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
pub fn zvmul(comptime T: type, a: *const SC(T), b: *const SC(T), out: *const SC(T), n: Length, conjugate: bool) void {
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
pub fn zvcma(comptime T: type, a: *const SC(T), b: *const SC(T), addend: *const SC(T), out: *const SC(T), n: Length) void {
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
pub fn zvma(comptime T: type, a: *const SC(T), b: *const SC(T), addend: *const SC(T), out: *const SC(T), n: Length) void {
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
pub fn zvcmul(comptime T: type, a: *const SC(T), b: *const SC(T), out: *const SC(T), n: Length) void {
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
pub fn zvconj(comptime T: type, a: *const SC(T), out: *const SC(T), n: Length) void {
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
pub fn zvzsml(comptime T: type, a: *const SC(T), scalar: *const SC(T), out: *const SC(T), n: Length) void {
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
pub fn zvmov(comptime T: type, a: *const SC(T), out: *const SC(T), n: Length) void {
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
pub fn zvneg(comptime T: type, a: *const SC(T), out: *const SC(T), n: Length) void {
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
pub fn zvsma(comptime T: type, a: *const SC(T), scalar: *const SC(T), addend: *const SC(T), out: *const SC(T), n: Length) void {
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
pub fn ztrans(comptime T: type, a: []const T, b: *const SC(T), out: *const SC(T), n: Length) void {
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
pub fn zcspec(comptime T: type, a: *const SC(T), b: *const SC(T), out: *const SC(T), n: Length) void {
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
pub fn zrdesamp(comptime T: type, a: *const SC(T), decimation_factor: Stride, filter: []const T, out: *const SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zrdesamp(a, decimation_factor, filter.ptr, out, n, filter.len),
        f64 => c.vDSP_zrdesampD(a, decimation_factor, filter.ptr, out, n, filter.len),
        else => @compileError("zrdesamp requires f32 or f64"),
    }
}

// ============================================================================
// Tests
// ============================================================================

test "vadd" {
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    const b = [_]f32{ 4.0, 5.0, 6.0 };
    var out: [3]f32 = undefined;
    vadd(f32, &a, &b, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), out[2], 0.001);
}

test "vsmul" {
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    var out: [3]f32 = undefined;
    vsmul(f32, &a, 2.5, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.5), out[2], 0.001);
}
