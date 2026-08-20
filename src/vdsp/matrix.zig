const std = @import("std");
const types = @import("types.zig");
const Length = types.Length;
const SC = types.SplitComplex;
const c = @import("c.zig");

/// Matrix multiply.
///
/// Maps:
///
///     A is regarded as a two-dimensional matrix with dimemnsions [M][P]
///     and stride IA.  B is regarded as a two-dimensional matrix with
///     dimemnsions [P][N] and stride IB.  C is regarded as a
///     two-dimensional matrix with dimemnsions [M][N] and stride IC.
///
///     Pseudocode:     Memory:
///     A[m][p]         A[(m*P+p)*IA]
///     B[p][n]         B[(p*N+n)*IB]
///     C[m][n]         C[(m*N+n)*IC]
///
/// These compute:
///
///     for (m = 0; m < M; ++m)
///     for (n = 0; n < N; ++n)
///         C[m][n] = sum(A[m][p] * B[p][n], 0 <= p < P);
pub fn mmul(comptime T: type, a: []const T, b: []const T, out: []T, m: Length, n: Length, p: Length) void {
    std.debug.assert(a.len >= m * p);
    std.debug.assert(b.len >= p * n);
    std.debug.assert(out.len >= m * n);
    switch (T) {
        f32 => c.vDSP_mmul(a.ptr, 1, b.ptr, 1, out.ptr, 1, m, n, p),
        f64 => c.vDSP_mmulD(a.ptr, 1, b.ptr, 1, out.ptr, 1, m, n, p),
        else => @compileError("mmul requires f32 or f64"),
    }
}

/// Matrix transpose.
///
/// Maps:
///
///     A is regarded as a two-dimensional matrix with dimemnsions
///     [N][M] and stride IA.  C is regarded as a two-dimensional matrix
///     with dimemnsions [M][N] and stride IC:
///
///     Pseudocode:     Memory:
///     A[n][m]         A[(n*M + m)*IA]
///     C[m][n]         C[(m*N + n)*IC]
///
/// These compute:
///
///     for (m = 0; m < M; ++m)
///     for (n = 0; n < N; ++n)
///         C[m][n] = A[n][m];
pub fn mtrans(comptime T: type, a: []const T, out: []T, m: Length, n: Length) void {
    std.debug.assert(a.len >= m * n);
    std.debug.assert(out.len >= m * n);
    switch (T) {
        f32 => c.vDSP_mtrans(a.ptr, 1, out.ptr, 1, m, n),
        f64 => c.vDSP_mtransD(a.ptr, 1, out.ptr, 1, m, n),
        else => @compileError("mtrans requires f32 or f64"),
    }
}

/// Split-complex matrix multiply and add.
///
/// Maps:
///
///     Pseudocode:     Memory:
///     A[m][p]         A->realp[(m*P+p)*IA] + i * A->imagp[(m*P+p)*IA].
///     B[p][n]         B->realp[(p*N+n)*IB] + i * B->imagp[(p*N+n)*IB].
///     C[m][n]         C->realp[(m*N+n)*IC] + i * C->imagp[(m*N+n)*IC].
///     D[m][n]         D->realp[(m*N+n)*ID] + i * D->imagp[(m*N+n)*ID].
///
/// These compute:
///
///     for (m = 0; m < M; ++m)
///     for (n = 0; n < N; ++n)
///         D[m][n] = sum(A[m][p] * B[p][n], 0 <= p < P) + C[m][n];
pub fn zmma(comptime T: type, a: *const SC(T), b: *const SC(T), cc: *const SC(T), d: *SC(T), m: Length, n: Length, p: Length) void {
    switch (T) {
        f32 => c.vDSP_zmma(a, 1, b, 1, cc, 1, d, 1, m, n, p),
        f64 => c.vDSP_zmmaD(a, 1, b, 1, cc, 1, d, 1, m, n, p),
        else => @compileError("zmma requires f32 or f64"),
    }
}

/// Split-complex matrix multiply and subtract.
///
/// Maps:
///
///     Pseudocode:     Memory:
///     A[m][p]         A->realp[(m*P+p)*IA] + i * A->imagp[(m*P+p)*IA].
///     B[p][n]         B->realp[(p*N+n)*IB] + i * B->imagp[(p*N+n)*IB].
///     C[m][n]         C->realp[(m*N+n)*IC] + i * C->imagp[(m*N+n)*IC].
///     D[m][n]         D->realp[(m*N+n)*ID] + i * D->imagp[(m*N+n)*ID].
///
/// These compute:
///
///     for (m = 0; m < M; ++m)
///     for (n = 0; n < N; ++n)
///         D[m][n] = sum(A[m][p] * B[p][n], 0 <= p < P) - C[m][n];
pub fn zmms(comptime T: type, a: *const SC(T), b: *const SC(T), cc: *const SC(T), d: *SC(T), m: Length, n: Length, p: Length) void {
    switch (T) {
        f32 => c.vDSP_zmms(a, 1, b, 1, cc, 1, d, 1, m, n, p),
        f64 => c.vDSP_zmmsD(a, 1, b, 1, cc, 1, d, 1, m, n, p),
        else => @compileError("zmms requires f32 or f64"),
    }
}

/// Split-complex matrix multiply and reverse subtract.
///
/// Maps:
///
///     Pseudocode:     Memory:
///     A[m][p]         A->realp[(m*P+p)*IA] + i * A->imagp[(m*P+p)*IA].
///     B[p][n]         B->realp[(p*N+n)*IB] + i * B->imagp[(p*N+n)*IB].
///     C[m][n]         C->realp[(m*N+n)*IC] + i * C->imagp[(m*N+n)*IC].
///     D[m][n]         D->realp[(m*N+n)*ID] + i * D->imagp[(m*N+n)*ID].
///
/// These compute:
///
///     for (m = 0; m < M; ++m)
///     for (n = 0; n < N; ++n)
///         D[m][n] = C[m][n] - sum(A[m][p] * B[p][n], 0 <= p < P);
pub fn zmsm(comptime T: type, a: *const SC(T), b: *const SC(T), cc: *const SC(T), d: *SC(T), m: Length, n: Length, p: Length) void {
    switch (T) {
        f32 => c.vDSP_zmsm(a, 1, b, 1, cc, 1, d, 1, m, n, p),
        f64 => c.vDSP_zmsmD(a, 1, b, 1, cc, 1, d, 1, m, n, p),
        else => @compileError("zmsm requires f32 or f64"),
    }
}

/// Split-complex matrix multiply.
///
/// Maps:
///
///     Pseudocode:     Memory:
///     A[m][p]         A->realp[(m*P+p)*IA] + i * A->imagp[(m*P+p)*IA].
///     B[p][n]         B->realp[(p*N+n)*IB] + i * B->imagp[(p*N+n)*IB].
///     C[m][n]         C->realp[(m*N+n)*IC] + i * C->imagp[(m*N+n)*IC].
///
/// These compute:
///
///     for (m = 0; m < M; ++m)
///     for (n = 0; n < N; ++n)
///         C[m][n] = sum(A[m][p] * B[p][n], 0 <= p < P);
pub fn zmmul(comptime T: type, a: *const SC(T), b: *const SC(T), cc: *SC(T), m: Length, n: Length, p: Length) void {
    switch (T) {
        f32 => c.vDSP_zmmul(a, 1, b, 1, cc, 1, m, n, p),
        f64 => c.vDSP_zmmulD(a, 1, b, 1, cc, 1, m, n, p),
        else => @compileError("zmmul requires f32 or f64"),
    }
}

/// Vector multiply, multiply, add, and add.
///
/// Maps:  The default maps are used.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         F[n] = A[n] * B[n] + C[n] * D[n] + E[n];
pub fn zvmmaa(comptime T: type, a: *const SC(T), b: *const SC(T), cc: *const SC(T), d: *const SC(T), e: *const SC(T), f: *SC(T), n: Length) void {
    switch (T) {
        f32 => c.vDSP_zvmmaa(a, 1, b, 1, cc, 1, d, 1, e, 1, f, 1, n),
        f64 => c.vDSP_zvmmaaD(a, 1, b, 1, cc, 1, d, 1, e, 1, f, 1, n),
        else => @compileError("zvmmaa requires f32 or f64"),
    }
}

// ============================================================================
// Tests
// ============================================================================

test "mmul on a non-square 2x3 * 3x2 matrix" {
    // Non-square (M != N != P) so a dimension-order bug (e.g. swapping M
    // and P) causes a visible shape mismatch or wrong values, not a silent
    // pass, which a square test could hide.
    const m: Length = 2;
    const n: Length = 2;
    const p: Length = 3;
    const a = [_]f32{ 1, 2, 3, 4, 5, 6 }; // [2][3]
    const b = [_]f32{ 7, 8, 9, 10, 11, 12 }; // [3][2]
    var out: [4]f32 = undefined;
    mmul(f32, &a, &b, &out, m, n, p);
    // C[0][0]=1*7+2*9+3*11=58  C[0][1]=1*8+2*10+3*12=64
    // C[1][0]=4*7+5*9+6*11=139 C[1][1]=4*8+5*10+6*12=154
    try std.testing.expectEqualSlices(f32, &[_]f32{ 58, 64, 139, 154 }, &out);
}

test "mtrans on a non-square 2x3 matrix" {
    // A is [N][M] = [2][3] per vDSP.h's convention; C is [M][N] = [3][2].
    const m: Length = 3;
    const n: Length = 2;
    const a = [_]f32{ 1, 2, 3, 4, 5, 6 }; // A[0]=[1,2,3], A[1]=[4,5,6]
    var out: [6]f32 = undefined;
    mtrans(f32, &a, &out, m, n);
    // C[m][n] = A[n][m]: C[0]=[1,4] C[1]=[2,5] C[2]=[3,6]
    try std.testing.expectEqualSlices(f32, &[_]f32{ 1, 4, 2, 5, 3, 6 }, &out);
}

test "zmmul on a non-square 2x3 * 3x2 complex matrix" {
    const m: Length = 2;
    const n: Length = 2;
    const p: Length = 3;
    var a_re = [_]f32{ 1, 2, 0, 4, 0, 1 };
    var a_im = [_]f32{ 1, 0, 3, 2, 0, -1 };
    var b_re = [_]f32{ 1, 2, 0, 1, 3, 0 };
    var b_im = [_]f32{ 0, 1, 1, 0, 0, 2 };
    const a = SC(f32){ .realp = &a_re, .imagp = &a_im };
    const b = SC(f32){ .realp = &b_re, .imagp = &b_im };

    var c_re = [_]f32{ 0, 0, 0, 0 };
    var c_im = [_]f32{ 0, 0, 0, 0 };
    var cc = SC(f32){ .realp = &c_re, .imagp = &c_im };

    zmmul(f32, &a, &b, &cc, m, n, p);

    // Hand-computed: C = A*B where
    //   A = [[1+1i, 2+0i, 0+3i], [4+2i, 0+0i, 1-1i]]
    //   B = [[1+0i, 2+1i], [0+1i, 1+0i], [3+0i, 0+2i]]
    //   C = [[1+12i, -3+3i], [7-1i, 8+10i]]
    try std.testing.expectEqualSlices(f32, &[_]f32{ 1, -3, 7, 8 }, &c_re);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 12, 3, -1, 10 }, &c_im);
}

test "zmma/zmms/zmsm add/subtract/reverse-subtract the same product consistently" {
    const m: Length = 2;
    const n: Length = 2;
    const p: Length = 3;
    var a_re = [_]f32{ 1, 2, 0, 4, 0, 1 };
    var a_im = [_]f32{ 1, 0, 3, 2, 0, -1 };
    var b_re = [_]f32{ 1, 2, 0, 1, 3, 0 };
    var b_im = [_]f32{ 0, 1, 1, 0, 0, 2 };
    const a = SC(f32){ .realp = &a_re, .imagp = &a_im };
    const b = SC(f32){ .realp = &b_re, .imagp = &b_im };

    // Bias matrix C, distinct from the A*B product so add/subtract/reverse
    // are all distinguishable.
    var bias_re = [_]f32{ 10, 20, 30, 40 };
    var bias_im = [_]f32{ 1, 2, 3, 4 };
    const bias = SC(f32){ .realp = &bias_re, .imagp = &bias_im };

    var ma_re = [_]f32{ 0, 0, 0, 0 };
    var ma_im = [_]f32{ 0, 0, 0, 0 };
    var d_ma = SC(f32){ .realp = &ma_re, .imagp = &ma_im };
    zmma(f32, &a, &b, &bias, &d_ma, m, n, p);
    // D = A*B + bias = [1+10, -3+20, 7+30, 8+40] + i*[12+1, 3+2, -1+3, 10+4]
    try std.testing.expectEqualSlices(f32, &[_]f32{ 11, 17, 37, 48 }, &ma_re);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 13, 5, 2, 14 }, &ma_im);

    var ms_re = [_]f32{ 0, 0, 0, 0 };
    var ms_im = [_]f32{ 0, 0, 0, 0 };
    var d_ms = SC(f32){ .realp = &ms_re, .imagp = &ms_im };
    zmms(f32, &a, &b, &bias, &d_ms, m, n, p);
    // D = A*B - bias
    try std.testing.expectEqualSlices(f32, &[_]f32{ -9, -23, -23, -32 }, &ms_re);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 11, 1, -4, 6 }, &ms_im);

    var sm_re = [_]f32{ 0, 0, 0, 0 };
    var sm_im = [_]f32{ 0, 0, 0, 0 };
    var d_sm = SC(f32){ .realp = &sm_re, .imagp = &sm_im };
    zmsm(f32, &a, &b, &bias, &d_sm, m, n, p);
    // D = bias - A*B, i.e. exactly the negation of zmms's result - a strong
    // cross-check that "reverse subtract" really reverses the operand order
    // rather than duplicating zmms.
    for (ms_re, sm_re) |ms, sm| try std.testing.expectApproxEqAbs(-ms, sm, 0.0001);
    for (ms_im, sm_im) |ms, sm| try std.testing.expectApproxEqAbs(-ms, sm, 0.0001);
}

test "zvmmaa computes A*B + C*D + E elementwise" {
    var a_re = [_]f32{ 1, 2, 0 };
    var a_im = [_]f32{ 1, 0, 3 };
    var b_re = [_]f32{ 1, 0, 3 };
    var b_im = [_]f32{ 0, 1, 0 };
    var c_re = [_]f32{ 2, 1, 0 };
    var c_im = [_]f32{ 0, 1, 1 };
    var d_re = [_]f32{ 3, 0, 1 };
    var d_im = [_]f32{ 1, 2, 0 };
    var e_re = [_]f32{ 1, 0, 2 };
    var e_im = [_]f32{ 0, 0, 1 };

    const a = SC(f32){ .realp = &a_re, .imagp = &a_im };
    const b = SC(f32){ .realp = &b_re, .imagp = &b_im };
    const cc = SC(f32){ .realp = &c_re, .imagp = &c_im };
    const d = SC(f32){ .realp = &d_re, .imagp = &d_im };
    const e = SC(f32){ .realp = &e_re, .imagp = &e_im };

    var f_re = [_]f32{ 0, 0, 0 };
    var f_im = [_]f32{ 0, 0, 0 };
    var f = SC(f32){ .realp = &f_re, .imagp = &f_im };

    zvmmaa(f32, &a, &b, &cc, &d, &e, &f, 3);

    // Hand-computed F[n] = A[n]*B[n] + C[n]*D[n] + E[n]:
    //   n=0: (1+1i)*(1+0i) + (2+0i)*(3+1i) + (1+0i) = 8+3i
    //   n=1: (2+0i)*(0+1i) + (1+1i)*(0+2i) + (0+0i) = -2+4i
    //   n=2: (0+3i)*(3+0i) + (0+1i)*(1+0i) + (2+1i) = 2+11i
    try std.testing.expectEqualSlices(f32, &[_]f32{ 8, -2, 2 }, &f_re);
    try std.testing.expectEqualSlices(f32, &[_]f32{ 3, 4, 11 }, &f_im);
}
