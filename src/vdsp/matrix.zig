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
