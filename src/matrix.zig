const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;
const SplitComplex = types.SplitComplex;
const DoubleSplitComplex = types.DoubleSplitComplex;

const c = struct {
    extern fn vDSP_mmul(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, M: Length, N: Length, P: Length) void;
    extern fn vDSP_mmulD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, M: Length, N: Length, P: Length) void;
    extern fn vDSP_mtrans(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, M: Length, N: Length) void;
    extern fn vDSP_mtransD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, M: Length, N: Length) void;
    extern fn vDSP_zmma(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, D: *const SplitComplex, ID: Stride, M: Length, N: Length, P: Length) void;
    extern fn vDSP_zmmaD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, D: *const DoubleSplitComplex, ID: Stride, M: Length, N: Length, P: Length) void;
    extern fn vDSP_zmms(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, D: *const SplitComplex, ID: Stride, M: Length, N: Length, P: Length) void;
    extern fn vDSP_zmmsD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, D: *const DoubleSplitComplex, ID: Stride, M: Length, N: Length, P: Length) void;
    extern fn vDSP_zmsm(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, D: *const SplitComplex, ID: Stride, M: Length, N: Length, P: Length) void;
    extern fn vDSP_zmsmD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, D: *const DoubleSplitComplex, ID: Stride, M: Length, N: Length, P: Length) void;
    extern fn vDSP_zmmul(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, M: Length, N: Length, P: Length) void;
    extern fn vDSP_zmmulD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, M: Length, N: Length, P: Length) void;
    extern fn vDSP_zvmmaa(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, D: *const SplitComplex, ID: Stride, E: *const SplitComplex, IE: Stride, F: *const SplitComplex, IF: Stride, N: Length) void;
    extern fn vDSP_zvmmaaD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, D: *const DoubleSplitComplex, ID: Stride, E: *const DoubleSplitComplex, IE: Stride, F: *const DoubleSplitComplex, IF: Stride, N: Length) void;
};

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
pub fn mmul(a: []const f32, b: []const f32, out: []f32, m: Length, n: Length, p: Length) void {
    c.vDSP_mmul(a.ptr, 1, b.ptr, 1, out.ptr, 1, m, n, p);
}
/// Matrix multiply (double-precision).
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
pub fn mmulD(a: []const f64, b: []const f64, out: []f64, m: Length, n: Length, p: Length) void {
    c.vDSP_mmulD(a.ptr, 1, b.ptr, 1, out.ptr, 1, m, n, p);
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
pub fn mtrans(a: []const f32, out: []f32, m: Length, n: Length) void {
    c.vDSP_mtrans(a.ptr, 1, out.ptr, 1, m, n);
}
/// Matrix transpose (double-precision).
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
pub fn mtransD(a: []const f64, out: []f64, m: Length, n: Length) void {
    c.vDSP_mtransD(a.ptr, 1, out.ptr, 1, m, n);
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
pub fn zmma(a: *const SplitComplex, b: *const SplitComplex, cc: *const SplitComplex, d: *const SplitComplex, m: Length, n: Length, p: Length) void {
    c.vDSP_zmma(a, 1, b, 1, cc, 1, d, 1, m, n, p);
}
/// Split-complex matrix multiply and add (double-precision).
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
pub fn zmmaD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, cc: *const DoubleSplitComplex, d: *const DoubleSplitComplex, m: Length, n: Length, p: Length) void {
    c.vDSP_zmmaD(a, 1, b, 1, cc, 1, d, 1, m, n, p);
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
pub fn zmms(a: *const SplitComplex, b: *const SplitComplex, cc: *const SplitComplex, d: *const SplitComplex, m: Length, n: Length, p: Length) void {
    c.vDSP_zmms(a, 1, b, 1, cc, 1, d, 1, m, n, p);
}
/// Split-complex matrix multiply and subtract (double-precision).
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
pub fn zmmsD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, cc: *const DoubleSplitComplex, d: *const DoubleSplitComplex, m: Length, n: Length, p: Length) void {
    c.vDSP_zmmsD(a, 1, b, 1, cc, 1, d, 1, m, n, p);
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
pub fn zmsm(a: *const SplitComplex, b: *const SplitComplex, cc: *const SplitComplex, d: *const SplitComplex, m: Length, n: Length, p: Length) void {
    c.vDSP_zmsm(a, 1, b, 1, cc, 1, d, 1, m, n, p);
}
/// Split-complex matrix multiply and reverse subtract (double-precision).
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
pub fn zmsmD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, cc: *const DoubleSplitComplex, d: *const DoubleSplitComplex, m: Length, n: Length, p: Length) void {
    c.vDSP_zmsmD(a, 1, b, 1, cc, 1, d, 1, m, n, p);
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
pub fn zmmul(a: *const SplitComplex, b: *const SplitComplex, cc: *const SplitComplex, m: Length, n: Length, p: Length) void {
    c.vDSP_zmmul(a, 1, b, 1, cc, 1, m, n, p);
}
/// Split-complex matrix multiply (double-precision).
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
pub fn zmmulD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, cc: *const DoubleSplitComplex, m: Length, n: Length, p: Length) void {
    c.vDSP_zmmulD(a, 1, b, 1, cc, 1, m, n, p);
}

/// Vector multiply, multiply, add, and add.
///
/// Maps:  The default maps are used.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         F[n] = A[n] * B[n] + C[n] * D[n] + E[n];
pub fn zvmmaa(a: *const SplitComplex, b: *const SplitComplex, cc: *const SplitComplex, d: *const SplitComplex, e: *const SplitComplex, f: *const SplitComplex, n: Length) void {
    c.vDSP_zvmmaa(a, 1, b, 1, cc, 1, d, 1, e, 1, f, 1, n);
}
/// Vector multiply, multiply, add, and add (double-precision).
///
/// Maps:  The default maps are used.
///
/// These compute:
///
///     for (n = 0; n < N; ++n)
///         F[n] = A[n] * B[n] + C[n] * D[n] + E[n];
pub fn zvmmaaD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, cc: *const DoubleSplitComplex, d: *const DoubleSplitComplex, e: *const DoubleSplitComplex, f: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zvmmaaD(a, 1, b, 1, cc, 1, d, 1, e, 1, f, 1, n);
}
