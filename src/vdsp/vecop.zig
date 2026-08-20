const std = @import("std");
const types = @import("types.zig");
const Length = types.Length;
const c = @import("c.zig");

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
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        // vDSP_vsub's first two arguments are the *subtrahend* (labeled __B in
        // the Apple header) then the *minuend* (__A); the header explicitly
        // warns "Caution: A and B are swapped!". Pass b then a so vsub(a, b,
        // out) computes a - b as its name promises.
        f32 => c.vDSP_vsub(b.ptr, 1, a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vsubD(b.ptr, 1, a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vsub requires f32 or f64"),
    }
}

/// Vector multiply.
/// Computes:
///     for (n = 0; n < N; ++n)
///         C[n] = A[n] * B[n];
pub fn vmul(comptime T: type, a: []const T, b: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vsdiv(a.ptr, 1, &scalar, out.ptr, 1, a.len),
        f64 => c.vDSP_vsdivD(a.ptr, 1, &scalar, out.ptr, 1, a.len),
        i32 => c.vDSP_vsdivi(a.ptr, 1, &scalar, out.ptr, 1, a.len),
        else => @compileError("vsdiv requires f32, f64, or i32"),
    }
}

/// Scalar / vector: C[n] = scalar / B[n]
pub fn svdiv(comptime T: type, scalar: T, b: []const T, out: []T) void {
    std.debug.assert(out.len >= b.len);
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
    std.debug.assert(b.len >= a.len);
    std.debug.assert(addend.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vma(a.ptr, 1, b.ptr, 1, addend.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vmaD(a.ptr, 1, b.ptr, 1, addend.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vma requires f32 or f64"),
    }
}

/// D[n] = A[n] * B[n] + scalar
pub fn vmsa(comptime T: type, a: []const T, b: []const T, scalar: T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vmsa(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len),
        f64 => c.vDSP_vmsaD(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len),
        else => @compileError("vmsa requires f32 or f64"),
    }
}

/// D[n] = A[n] * scalar + C[n]
pub fn vsma(comptime T: type, a: []const T, scalar: T, addend: []const T, out: []T) void {
    std.debug.assert(addend.len >= a.len);
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(b.len >= a.len);
    std.debug.assert(multiplier.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vam(a.ptr, 1, b.ptr, 1, multiplier.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vamD(a.ptr, 1, b.ptr, 1, multiplier.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vam requires f32 or f64"),
    }
}

/// D[n] = A[n] * B[n] - C[n]
pub fn vmsb(comptime T: type, a: []const T, b: []const T, subtrahend: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(subtrahend.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vmsb(a.ptr, 1, b.ptr, 1, subtrahend.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vmsbD(a.ptr, 1, b.ptr, 1, subtrahend.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vmsb requires f32 or f64"),
    }
}

/// E[n] = A[n]*B[n] + C[n]*D[n]
pub fn vmma(comptime T: type, a: []const T, b: []const T, c_vec: []const T, d: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(c_vec.len >= a.len);
    std.debug.assert(d.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vmma(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vmmaD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vmma requires f32 or f64"),
    }
}

/// E[n] = A[n]*B[n] - C[n]*D[n]
pub fn vmmsb(comptime T: type, a: []const T, b: []const T, c_vec: []const T, d: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(c_vec.len >= a.len);
    std.debug.assert(d.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vmmsb(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vmmsbD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vmmsb requires f32 or f64"),
    }
}

/// D[n] = A[n] * scalar + scalar2
pub fn vsmsa(comptime T: type, a: []const T, scalar: T, scalar2: T, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vsmsa(a.ptr, 1, &scalar, &scalar2, out.ptr, 1, a.len),
        f64 => c.vDSP_vsmsaD(a.ptr, 1, &scalar, &scalar2, out.ptr, 1, a.len),
        else => @compileError("vsmsa requires f32 or f64"),
    }
}

/// D[n] = A[n] * scalar - C[n]
pub fn vsmsb(comptime T: type, a: []const T, scalar: T, subtrahend: []const T, out: []T) void {
    std.debug.assert(subtrahend.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vsmsb(a.ptr, 1, &scalar, subtrahend.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vsmsbD(a.ptr, 1, &scalar, subtrahend.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vsmsb requires f32 or f64"),
    }
}

/// E[n] = A[n]*scalarA + C[n]*scalarB
pub fn vsmsma(comptime T: type, a: []const T, scalar_a: T, b: []const T, scalar_b: T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(b.len >= a.len);
    std.debug.assert(c_vec.len >= a.len);
    std.debug.assert(d.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vaam(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vaamD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vaam requires f32 or f64"),
    }
}

/// E[n] = (A[n] + B[n]) * (C[n] - D[n])
pub fn vasbm(comptime T: type, a: []const T, b: []const T, c_vec: []const T, d: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(c_vec.len >= a.len);
    std.debug.assert(d.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vasbm(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vasbmD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vasbm requires f32 or f64"),
    }
}

/// D[n] = (A[n] + B[n]) * scalar
pub fn vasm(comptime T: type, a: []const T, b: []const T, scalar: T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(b.len >= a.len);
    std.debug.assert(multiplier.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vsbm(a.ptr, 1, b.ptr, 1, multiplier.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vsbmD(a.ptr, 1, b.ptr, 1, multiplier.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vsbm requires f32 or f64"),
    }
}

/// E[n] = (A[n] - B[n]) * (C[n] - D[n])
pub fn vsbsbm(comptime T: type, a: []const T, b: []const T, c_vec: []const T, d: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(c_vec.len >= a.len);
    std.debug.assert(d.len >= a.len);
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vsbsbm(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vsbsbmD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vsbsbm requires f32 or f64"),
    }
}

/// D[n] = (A[n] - B[n]) * scalar
pub fn vsbsm(comptime T: type, a: []const T, b: []const T, scalar: T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(b.len >= a.len);
    std.debug.assert(c_vec.len >= a.len);
    std.debug.assert(d.len >= a.len);
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vabs(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vabsD(a.ptr, 1, out.ptr, 1, a.len),
        i32 => c.vDSP_vabsi(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vabs requires f32, f64, or i32"),
    }
}

pub fn vneg(comptime T: type, a: []const T, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vneg(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vnegD(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vneg requires f32 or f64"),
    }
}

/// C[n] = -|A[n]|
pub fn vnabs(comptime T: type, a: []const T, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vnabs(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vnabsD(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vnabs requires f32 or f64"),
    }
}

pub fn vfrac(comptime T: type, a: []const T, out: []T) void {
    std.debug.assert(out.len >= a.len);
    switch (T) {
        f32 => c.vDSP_vfrac(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfracD(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfrac requires f32 or f64"),
    }
}

pub fn vdist(comptime T: type, a: []const T, b: []const T, out: []T) void {
    std.debug.assert(b.len >= a.len);
    std.debug.assert(out.len >= a.len);
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
    std.debug.assert(b.len >= a.len);
    var result: T = undefined;
    switch (T) {
        f32 => c.vDSP_distancesq(a.ptr, 1, b.ptr, 1, &result, a.len),
        f64 => c.vDSP_distancesqD(a.ptr, 1, b.ptr, 1, &result, a.len),
        else => @compileError("distancesq requires f32 or f64"),
    }
    return result;
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

test "vsub" {
    // Asymmetric inputs: a symmetric test (e.g. a=[1,2,3], b=[1,2,3]) can't
    // catch an argument-order bug because a-b == b-a when a==b.
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    const b = [_]f32{ 10.0, 20.0, 30.0 };
    var out: [3]f32 = undefined;
    vsub(f32, &a, &b, &out);
    try std.testing.expectApproxEqAbs(@as(f32, -9.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -18.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -27.0), out[2], 0.001);
}

test "vsub f64" {
    const a = [_]f64{ 1.0, 2.0, 3.0 };
    const b = [_]f64{ 10.0, 20.0, 30.0 };
    var out: [3]f64 = undefined;
    vsub(f64, &a, &b, &out);
    try std.testing.expectApproxEqAbs(@as(f64, -9.0), out[0], 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, -18.0), out[1], 1e-9);
    try std.testing.expectApproxEqAbs(@as(f64, -27.0), out[2], 1e-9);
}

test "vdiv" {
    // Asymmetric inputs so an argument-order bug (a/b vs b/a) would show up.
    const a = [_]f32{ 10.0, 20.0, 30.0 };
    const b = [_]f32{ 2.0, 4.0, 5.0 };
    var out: [3]f32 = undefined;
    vdiv(f32, &a, &b, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 6.0), out[2], 0.001);
}

test "vdiv f64" {
    const a = [_]f64{ 10.0, 21.0, 30.0 };
    const b = [_]f64{ 2.0, 4.0, 5.0 };
    var out: [3]f64 = undefined;
    vdiv(f64, &a, &b, &out);
    // vDSP_vdivD is a fast reciprocal-refine implementation, not IEEE exact.
    try std.testing.expectApproxEqRel(@as(f64, 5.0), out[0], 1e-12);
    try std.testing.expectApproxEqRel(@as(f64, 5.25), out[1], 1e-12);
    try std.testing.expectApproxEqRel(@as(f64, 6.0), out[2], 1e-12);
}

test "vdiv i32" {
    const a = [_]i32{ 10, 21, -30 };
    const b = [_]i32{ 2, 4, 5 };
    var out: [3]i32 = undefined;
    vdiv(i32, &a, &b, &out);
    try std.testing.expectEqual(@as(i32, 5), out[0]);
    try std.testing.expectEqual(@as(i32, 5), out[1]);
    try std.testing.expectEqual(@as(i32, -6), out[2]);
}

test "vmul" {
    const a = [_]f32{ 2.0, 3.0, 4.0 };
    const b = [_]f32{ 5.0, 6.0, 7.0 };
    var out: [3]f32 = undefined;
    vmul(f32, &a, &b, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 18.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 28.0), out[2], 0.001);
}

test "vsdiv" {
    const a = [_]f32{ 10.0, 20.0, 33.0 };
    var out: [3]f32 = undefined;
    vsdiv(f32, &a, 2.0, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 10.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 16.5), out[2], 0.001);
}

test "vsmul" {
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    var out: [3]f32 = undefined;
    vsmul(f32, &a, 2.5, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.5), out[2], 0.001);
}
