//! BLAS Level 3: matrix-matrix operations.
//!
//! This is where BLAS earns its reputation - `gemm` and `trsm` are the routines
//! that reach a large fraction of peak throughput, and every higher-level dense
//! linear algebra algorithm is written to spend its time here.
//!
//! Parameter order follows CBLAS. Matrices arrive as slices whose lengths are
//! checked against the dimensions and leading dimensions.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");

const Complex = types.Complex;
const Scalar = types.Scalar;
const Order = types.Order;
const Transpose = types.Transpose;
const Uplo = types.Uplo;
const Diag = types.Diag;
const Side = types.Side;
const dim = types.dim;
const matrixLen = types.matrixLen;

fn unsupported(comptime T: type, comptime op: []const u8) noreturn {
    @compileError(op ++ " is not defined for " ++ @typeName(T));
}

/// Shape of `op(A)` given the untransposed dimensions.
fn opShape(trans: Transpose, rows: usize, cols: usize) struct { usize, usize } {
    return if (trans == .no_trans) .{ rows, cols } else .{ cols, rows };
}

// ============================================================================
// gemm
// ============================================================================

/// `C := alpha * op(A) * op(B) + beta * C`.
///
/// `op(A)` is `m x k`, `op(B)` is `k x n`, `C` is `m x n`. The dimensions given
/// are those of the *operated* matrices, so `lda` refers to `A` as stored -
/// which is the usual source of confusion, and why the length checks below
/// undo the transpose before measuring.
pub fn gemm(
    comptime T: type,
    order: Order,
    transa: Transpose,
    transb: Transpose,
    m: usize,
    n: usize,
    k: usize,
    alpha: T,
    a: []const T,
    lda: usize,
    b: []const T,
    ldb: usize,
    beta: T,
    cm: []T,
    ldc: usize,
) void {
    const ar, const ac = opShape(transa, m, k);
    const br, const bc = opShape(transb, k, n);
    std.debug.assert(a.len >= matrixLen(order, ar, ac, lda));
    std.debug.assert(b.len >= matrixLen(order, br, bc, ldb));
    std.debug.assert(cm.len >= matrixLen(order, m, n, ldc));
    switch (T) {
        f32 => c.cblas_sgemm(order, transa, transb, dim(m), dim(n), dim(k), alpha, a.ptr, dim(lda), b.ptr, dim(ldb), beta, cm.ptr, dim(ldc)),
        f64 => c.cblas_dgemm(order, transa, transb, dim(m), dim(n), dim(k), alpha, a.ptr, dim(lda), b.ptr, dim(ldb), beta, cm.ptr, dim(ldc)),
        Complex(f32) => c.cblas_cgemm(order, transa, transb, dim(m), dim(n), dim(k), &alpha, a.ptr, dim(lda), b.ptr, dim(ldb), &beta, cm.ptr, dim(ldc)),
        Complex(f64) => c.cblas_zgemm(order, transa, transb, dim(m), dim(n), dim(k), &alpha, a.ptr, dim(lda), b.ptr, dim(ldb), &beta, cm.ptr, dim(ldc)),
        else => unsupported(T, "gemm"),
    }
}

// ============================================================================
// symm / hemm
// ============================================================================

/// `C := alpha * A * B + beta * C` (or `B * A` when `side` is `.right`), with
/// `A` symmetric.
///
/// For complex `T` this is `csymm`/`zsymm`, which treat `A` as *symmetric*,
/// not Hermitian. Use `hemm` for the Hermitian case - the two are different
/// routines and BLAS does not conflate them.
pub fn symm(
    comptime T: type,
    order: Order,
    side: Side,
    uplo: Uplo,
    m: usize,
    n: usize,
    alpha: T,
    a: []const T,
    lda: usize,
    b: []const T,
    ldb: usize,
    beta: T,
    cm: []T,
    ldc: usize,
) void {
    const an = if (side == .left) m else n;
    std.debug.assert(a.len >= matrixLen(order, an, an, lda));
    std.debug.assert(b.len >= matrixLen(order, m, n, ldb));
    std.debug.assert(cm.len >= matrixLen(order, m, n, ldc));
    switch (T) {
        f32 => c.cblas_ssymm(order, side, uplo, dim(m), dim(n), alpha, a.ptr, dim(lda), b.ptr, dim(ldb), beta, cm.ptr, dim(ldc)),
        f64 => c.cblas_dsymm(order, side, uplo, dim(m), dim(n), alpha, a.ptr, dim(lda), b.ptr, dim(ldb), beta, cm.ptr, dim(ldc)),
        Complex(f32) => c.cblas_csymm(order, side, uplo, dim(m), dim(n), &alpha, a.ptr, dim(lda), b.ptr, dim(ldb), &beta, cm.ptr, dim(ldc)),
        Complex(f64) => c.cblas_zsymm(order, side, uplo, dim(m), dim(n), &alpha, a.ptr, dim(lda), b.ptr, dim(ldb), &beta, cm.ptr, dim(ldc)),
        else => unsupported(T, "symm"),
    }
}

/// `C := alpha * A * B + beta * C` (or `B * A`), with `A` Hermitian. Complex
/// only; the real analogue is `symm`.
pub fn hemm(
    comptime T: type,
    order: Order,
    side: Side,
    uplo: Uplo,
    m: usize,
    n: usize,
    alpha: T,
    a: []const T,
    lda: usize,
    b: []const T,
    ldb: usize,
    beta: T,
    cm: []T,
    ldc: usize,
) void {
    const an = if (side == .left) m else n;
    std.debug.assert(a.len >= matrixLen(order, an, an, lda));
    std.debug.assert(b.len >= matrixLen(order, m, n, ldb));
    std.debug.assert(cm.len >= matrixLen(order, m, n, ldc));
    switch (T) {
        Complex(f32) => c.cblas_chemm(order, side, uplo, dim(m), dim(n), &alpha, a.ptr, dim(lda), b.ptr, dim(ldb), &beta, cm.ptr, dim(ldc)),
        Complex(f64) => c.cblas_zhemm(order, side, uplo, dim(m), dim(n), &alpha, a.ptr, dim(lda), b.ptr, dim(ldb), &beta, cm.ptr, dim(ldc)),
        else => unsupported(T, "hemm"),
    }
}

// ============================================================================
// Rank-k and rank-2k updates
// ============================================================================

/// `C := alpha * op(A) * op(A)^T + beta * C`, `C` symmetric `n x n`.
pub fn syrk(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    trans: Transpose,
    n: usize,
    k: usize,
    alpha: T,
    a: []const T,
    lda: usize,
    beta: T,
    cm: []T,
    ldc: usize,
) void {
    const ar, const ac = opShape(trans, n, k);
    std.debug.assert(a.len >= matrixLen(order, ar, ac, lda));
    std.debug.assert(cm.len >= matrixLen(order, n, n, ldc));
    switch (T) {
        f32 => c.cblas_ssyrk(order, uplo, trans, dim(n), dim(k), alpha, a.ptr, dim(lda), beta, cm.ptr, dim(ldc)),
        f64 => c.cblas_dsyrk(order, uplo, trans, dim(n), dim(k), alpha, a.ptr, dim(lda), beta, cm.ptr, dim(ldc)),
        Complex(f32) => c.cblas_csyrk(order, uplo, trans, dim(n), dim(k), &alpha, a.ptr, dim(lda), &beta, cm.ptr, dim(ldc)),
        Complex(f64) => c.cblas_zsyrk(order, uplo, trans, dim(n), dim(k), &alpha, a.ptr, dim(lda), &beta, cm.ptr, dim(ldc)),
        else => unsupported(T, "syrk"),
    }
}

/// `C := alpha * A * A^H + beta * C`, `C` Hermitian. Complex only.
///
/// Both `alpha` and `beta` are **real**: `C` is Hermitian and a complex scalar
/// would destroy that, which is why `cherk`/`zherk` declare them as `float` /
/// `double`.
pub fn herk(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    trans: Transpose,
    n: usize,
    k: usize,
    alpha: Scalar(T),
    a: []const T,
    lda: usize,
    beta: Scalar(T),
    cm: []T,
    ldc: usize,
) void {
    const ar, const ac = opShape(trans, n, k);
    std.debug.assert(a.len >= matrixLen(order, ar, ac, lda));
    std.debug.assert(cm.len >= matrixLen(order, n, n, ldc));
    switch (T) {
        Complex(f32) => c.cblas_cherk(order, uplo, trans, dim(n), dim(k), alpha, a.ptr, dim(lda), beta, cm.ptr, dim(ldc)),
        Complex(f64) => c.cblas_zherk(order, uplo, trans, dim(n), dim(k), alpha, a.ptr, dim(lda), beta, cm.ptr, dim(ldc)),
        else => unsupported(T, "herk"),
    }
}

/// `C := alpha * A * B^T + alpha * B * A^T + beta * C`, `C` symmetric.
pub fn syr2k(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    trans: Transpose,
    n: usize,
    k: usize,
    alpha: T,
    a: []const T,
    lda: usize,
    b: []const T,
    ldb: usize,
    beta: T,
    cm: []T,
    ldc: usize,
) void {
    const ar, const ac = opShape(trans, n, k);
    std.debug.assert(a.len >= matrixLen(order, ar, ac, lda));
    std.debug.assert(b.len >= matrixLen(order, ar, ac, ldb));
    std.debug.assert(cm.len >= matrixLen(order, n, n, ldc));
    switch (T) {
        f32 => c.cblas_ssyr2k(order, uplo, trans, dim(n), dim(k), alpha, a.ptr, dim(lda), b.ptr, dim(ldb), beta, cm.ptr, dim(ldc)),
        f64 => c.cblas_dsyr2k(order, uplo, trans, dim(n), dim(k), alpha, a.ptr, dim(lda), b.ptr, dim(ldb), beta, cm.ptr, dim(ldc)),
        Complex(f32) => c.cblas_csyr2k(order, uplo, trans, dim(n), dim(k), &alpha, a.ptr, dim(lda), b.ptr, dim(ldb), &beta, cm.ptr, dim(ldc)),
        Complex(f64) => c.cblas_zsyr2k(order, uplo, trans, dim(n), dim(k), &alpha, a.ptr, dim(lda), b.ptr, dim(ldb), &beta, cm.ptr, dim(ldc)),
        else => unsupported(T, "syr2k"),
    }
}

/// `C := alpha * A * B^H + conj(alpha) * B * A^H + beta * C`, `C` Hermitian.
///
/// `alpha` is complex but `beta` is **real** - the cross terms are already
/// conjugate-symmetric, but scaling `C` by a complex number would not be.
pub fn her2k(
    comptime T: type,
    order: Order,
    uplo: Uplo,
    trans: Transpose,
    n: usize,
    k: usize,
    alpha: T,
    a: []const T,
    lda: usize,
    b: []const T,
    ldb: usize,
    beta: Scalar(T),
    cm: []T,
    ldc: usize,
) void {
    const ar, const ac = opShape(trans, n, k);
    std.debug.assert(a.len >= matrixLen(order, ar, ac, lda));
    std.debug.assert(b.len >= matrixLen(order, ar, ac, ldb));
    std.debug.assert(cm.len >= matrixLen(order, n, n, ldc));
    switch (T) {
        Complex(f32) => c.cblas_cher2k(order, uplo, trans, dim(n), dim(k), &alpha, a.ptr, dim(lda), b.ptr, dim(ldb), beta, cm.ptr, dim(ldc)),
        Complex(f64) => c.cblas_zher2k(order, uplo, trans, dim(n), dim(k), &alpha, a.ptr, dim(lda), b.ptr, dim(ldb), beta, cm.ptr, dim(ldc)),
        else => unsupported(T, "her2k"),
    }
}

// ============================================================================
// Triangular multiply and solve
// ============================================================================

/// `B := alpha * op(A) * B` (or `B * op(A)` when `side` is `.right`), `A`
/// triangular.
pub fn trmm(
    comptime T: type,
    order: Order,
    side: Side,
    uplo: Uplo,
    transa: Transpose,
    diag: Diag,
    m: usize,
    n: usize,
    alpha: T,
    a: []const T,
    lda: usize,
    b: []T,
    ldb: usize,
) void {
    const an = if (side == .left) m else n;
    std.debug.assert(a.len >= matrixLen(order, an, an, lda));
    std.debug.assert(b.len >= matrixLen(order, m, n, ldb));
    switch (T) {
        f32 => c.cblas_strmm(order, side, uplo, transa, diag, dim(m), dim(n), alpha, a.ptr, dim(lda), b.ptr, dim(ldb)),
        f64 => c.cblas_dtrmm(order, side, uplo, transa, diag, dim(m), dim(n), alpha, a.ptr, dim(lda), b.ptr, dim(ldb)),
        Complex(f32) => c.cblas_ctrmm(order, side, uplo, transa, diag, dim(m), dim(n), &alpha, a.ptr, dim(lda), b.ptr, dim(ldb)),
        Complex(f64) => c.cblas_ztrmm(order, side, uplo, transa, diag, dim(m), dim(n), &alpha, a.ptr, dim(lda), b.ptr, dim(ldb)),
        else => unsupported(T, "trmm"),
    }
}

/// Solves `op(A) * X = alpha * B` (or `X * op(A) = alpha * B`) in place; `b`
/// holds `B` on entry and `X` on exit. `A` is triangular.
///
/// As with `trsv`, BLAS assumes `A` is non-singular and reports nothing if it
/// is not.
pub fn trsm(
    comptime T: type,
    order: Order,
    side: Side,
    uplo: Uplo,
    transa: Transpose,
    diag: Diag,
    m: usize,
    n: usize,
    alpha: T,
    a: []const T,
    lda: usize,
    b: []T,
    ldb: usize,
) void {
    const an = if (side == .left) m else n;
    std.debug.assert(a.len >= matrixLen(order, an, an, lda));
    std.debug.assert(b.len >= matrixLen(order, m, n, ldb));
    switch (T) {
        f32 => c.cblas_strsm(order, side, uplo, transa, diag, dim(m), dim(n), alpha, a.ptr, dim(lda), b.ptr, dim(ldb)),
        f64 => c.cblas_dtrsm(order, side, uplo, transa, diag, dim(m), dim(n), alpha, a.ptr, dim(lda), b.ptr, dim(ldb)),
        Complex(f32) => c.cblas_ctrsm(order, side, uplo, transa, diag, dim(m), dim(n), &alpha, a.ptr, dim(lda), b.ptr, dim(ldb)),
        Complex(f64) => c.cblas_ztrsm(order, side, uplo, transa, diag, dim(m), dim(n), &alpha, a.ptr, dim(lda), b.ptr, dim(ldb)),
        else => unsupported(T, "trsm"),
    }
}

// ============================================================================
// Apple extension
// ============================================================================

/// `C := alpha * op(A) + beta * op(B)`, an Apple extension (`appleblas_sgeadd`
/// / `appleblas_dgeadd`), not standard BLAS. `f32` and `f64` only.
///
/// `m` and `n` are the dimensions of `C`; a transposed `A` or `B` is
/// interpreted as `n x m`. Per the header, a zero `alpha` or `beta` means the
/// corresponding matrix is not read at all, so it may be an empty slice.
pub fn geadd(
    comptime T: type,
    order: Order,
    transa: Transpose,
    transb: Transpose,
    m: usize,
    n: usize,
    alpha: T,
    a: []const T,
    lda: usize,
    beta: T,
    b: []const T,
    ldb: usize,
    cm: []T,
    ldc: usize,
) void {
    const ar, const ac = opShape(transa, m, n);
    const br, const bc = opShape(transb, m, n);
    if (alpha != 0) std.debug.assert(a.len >= matrixLen(order, ar, ac, lda));
    if (beta != 0) std.debug.assert(b.len >= matrixLen(order, br, bc, ldb));
    std.debug.assert(cm.len >= matrixLen(order, m, n, ldc));
    switch (T) {
        f32 => c.appleblas_sgeadd(order, transa, transb, dim(m), dim(n), alpha, if (alpha != 0) a.ptr else null, dim(lda), beta, if (beta != 0) b.ptr else null, dim(ldb), cm.ptr, dim(ldc)),
        f64 => c.appleblas_dgeadd(order, transa, transb, dim(m), dim(n), alpha, if (alpha != 0) a.ptr else null, dim(lda), beta, if (beta != 0) b.ptr else null, dim(ldb), cm.ptr, dim(ldc)),
        else => unsupported(T, "geadd"),
    }
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const C64 = Complex(f64);

/// Naive reference product, deliberately independent of BLAS: row-major,
/// no transposes, no strides. Several tests below check BLAS against this
/// rather than against hand-computed numbers.
fn refGemm(comptime T: type, m: usize, n: usize, k: usize, a: []const T, b: []const T, out: []T) void {
    for (0..m) |i| {
        for (0..n) |j| {
            var acc: T = 0;
            for (0..k) |p| acc += a[i * k + p] * b[p * n + j];
            out[i * n + j] = acc;
        }
    }
}

test "gemm computes a 2x2 product" {
    const a = [_]f64{ 1, 2, 3, 4 };
    const b = [_]f64{ 5, 6, 7, 8 };
    var cm = [_]f64{ 0, 0, 0, 0 };
    gemm(f64, .row_major, .no_trans, .no_trans, 2, 2, 2, 1, &a, 2, &b, 2, 0, &cm, 2);
    try testing.expectEqualSlices(f64, &.{ 19, 22, 43, 50 }, &cm);
}

test "gemm matches an independent naive product for a non-square case" {
    // 3x2 times 2x4.
    const a = [_]f64{ 1, 2, 3, 4, 5, 6 };
    const b = [_]f64{ 1, 0, 2, 1, 0, 1, 3, 2 };
    var want = [_]f64{0} ** 12;
    refGemm(f64, 3, 4, 2, &a, &b, &want);

    var got = [_]f64{0} ** 12;
    gemm(f64, .row_major, .no_trans, .no_trans, 3, 4, 2, 1, &a, 2, &b, 4, 0, &got, 4);
    for (want, got) |w, g| try testing.expectApproxEqAbs(w, g, 1e-12);
}

test "transposing A gives the same result as pre-transposing the data" {
    // A is 2x3; A^T is stored 3x2.
    const a = [_]f64{ 1, 2, 3, 4, 5, 6 };
    const at = [_]f64{ 1, 4, 2, 5, 3, 6 };
    const b = [_]f64{ 1, 1, 1, 1, 1, 1 }; // 3x2

    var direct = [_]f64{0} ** 4;
    gemm(f64, .row_major, .no_trans, .no_trans, 2, 2, 3, 1, &a, 3, &b, 2, 0, &direct, 2);

    var transposed = [_]f64{0} ** 4;
    gemm(f64, .row_major, .trans, .no_trans, 2, 2, 3, 1, &at, 2, &b, 2, 0, &transposed, 2);

    for (direct, transposed) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "gemm accumulates with beta" {
    const a = [_]f64{ 1, 0, 0, 1 };
    var cm = [_]f64{ 1, 2, 3, 4 };
    gemm(f64, .row_major, .no_trans, .no_trans, 2, 2, 2, 2, &a, 2, &a, 2, 10, &cm, 2);
    // 2*I*I + 10*C = 2I + 10C
    try testing.expectEqualSlices(f64, &.{ 12, 20, 30, 42 }, &cm);
}

test "gemm respects a leading dimension larger than the row" {
    // 2x2 operands living inside 2x3 buffers.
    const a = [_]f64{ 1, 2, 99, 3, 4, 99 };
    const b = [_]f64{ 5, 6, 99, 7, 8, 99 };
    var cm = [_]f64{ 0, 0, 77, 0, 0, 77 };
    gemm(f64, .row_major, .no_trans, .no_trans, 2, 2, 2, 1, &a, 3, &b, 3, 0, &cm, 3);
    try testing.expectEqualSlices(f64, &.{ 19, 22, 77, 43, 50, 77 }, &cm);
}

test "gemm over f32 and both complex types" {
    {
        const a = [_]f32{ 1, 2, 3, 4 };
        var cm = [_]f32{ 0, 0, 0, 0 };
        gemm(f32, .row_major, .no_trans, .no_trans, 2, 2, 2, 1, &a, 2, &a, 2, 0, &cm, 2);
        try testing.expectEqualSlices(f32, &.{ 7, 10, 15, 22 }, &cm);
    }
    {
        // [[i]] * [[i]] = [[-1]]
        const a = [_]C64{.init(0, 1)};
        var cm = [_]C64{C64.zero};
        gemm(C64, .row_major, .no_trans, .no_trans, 1, 1, 1, C64.one, &a, 1, &a, 1, C64.zero, &cm, 1);
        try testing.expect(cm[0].eqlApprox(.init(-1, 0), 1e-12));
    }
    {
        const A32 = Complex(f32);
        const a = [_]A32{.init(1, 1)};
        var cm = [_]A32{A32.zero};
        gemm(A32, .row_major, .no_trans, .no_trans, 1, 1, 1, A32.one, &a, 1, &a, 1, A32.zero, &cm, 1);
        // (1+i)^2 = 2i
        try testing.expect(cm[0].eqlApprox(.init(0, 2), 1e-6));
    }
}

test "conj_trans conjugates as well as transposes" {
    // A = [[i]], so A^H = [[-i]] and A^H * A = [[1]].
    const a = [_]C64{.init(0, 1)};
    var cm = [_]C64{C64.zero};
    gemm(C64, .row_major, .conj_trans, .no_trans, 1, 1, 1, C64.one, &a, 1, &a, 1, C64.zero, &cm, 1);
    try testing.expect(cm[0].eqlApprox(.init(1, 0), 1e-12));

    // Plain .trans would give (i)*(i) = -1 instead.
    var ct = [_]C64{C64.zero};
    gemm(C64, .row_major, .trans, .no_trans, 1, 1, 1, C64.one, &a, 1, &a, 1, C64.zero, &ct, 1);
    try testing.expect(ct[0].eqlApprox(.init(-1, 0), 1e-12));
}

test "symm agrees with gemm on the expanded symmetric matrix" {
    // S = [[1,2],[2,3]]; store the upper triangle with a poisoned lower entry.
    const packed_s = [_]f64{ 1, 2, -999, 3 };
    const full_s = [_]f64{ 1, 2, 2, 3 };
    const b = [_]f64{ 1, 0, 0, 1 };

    var from_symm = [_]f64{0} ** 4;
    var from_gemm = [_]f64{0} ** 4;
    symm(f64, .row_major, .left, .upper, 2, 2, 1, &packed_s, 2, &b, 2, 0, &from_symm, 2);
    gemm(f64, .row_major, .no_trans, .no_trans, 2, 2, 2, 1, &full_s, 2, &b, 2, 0, &from_gemm, 2);

    for (from_gemm, from_symm) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "hemm agrees with gemm on the expanded Hermitian matrix" {
    // H = [[2, 1+i], [1-i, 3]], upper triangle stored.
    const packed_h = [_]C64{ .init(2, 0), .init(1, 1), .init(-999, -999), .init(3, 0) };
    const full_h = [_]C64{ .init(2, 0), .init(1, 1), .init(1, -1), .init(3, 0) };
    const b = [_]C64{ C64.one, C64.zero, C64.zero, C64.one };

    var from_hemm = [_]C64{C64.zero} ** 4;
    var from_gemm = [_]C64{C64.zero} ** 4;
    hemm(C64, .row_major, .left, .upper, 2, 2, C64.one, &packed_h, 2, &b, 2, C64.zero, &from_hemm, 2);
    gemm(C64, .row_major, .no_trans, .no_trans, 2, 2, 2, C64.one, &full_h, 2, &b, 2, C64.zero, &from_gemm, 2);

    for (from_gemm, from_hemm) |x, y| try testing.expect(x.eqlApprox(y, 1e-12));
}

test "side .right multiplies from the other side" {
    // S = [[1,2],[2,3]], B = [[1,1],[0,1]]. S*B != B*S, so the flag matters.
    const s = [_]f64{ 1, 2, -999, 3 };
    const b = [_]f64{ 1, 1, 0, 1 };

    var left = [_]f64{0} ** 4;
    var right = [_]f64{0} ** 4;
    symm(f64, .row_major, .left, .upper, 2, 2, 1, &s, 2, &b, 2, 0, &left, 2);
    symm(f64, .row_major, .right, .upper, 2, 2, 1, &s, 2, &b, 2, 0, &right, 2);

    // S*B = [[1,3],[2,5]] but B*S = [[3,5],[2,3]] - genuinely different, which
    // is the point of the flag.
    try testing.expectEqualSlices(f64, &.{ 1, 3, 2, 5 }, &left);
    try testing.expectEqualSlices(f64, &.{ 3, 5, 2, 3 }, &right);
}

test "syrk produces A*A^T in the requested triangle only" {
    // A = [[1,2],[3,4]]; A*A^T = [[5,11],[11,25]].
    const a = [_]f64{ 1, 2, 3, 4 };
    var cm = [_]f64{ 0, 0, -1, 0 };
    syrk(f64, .row_major, .upper, .no_trans, 2, 2, 1, &a, 2, 0, &cm, 2);

    try testing.expectApproxEqAbs(@as(f64, 5), cm[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 11), cm[1], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 25), cm[3], 1e-12);
    // The lower triangle must be untouched.
    try testing.expectEqual(@as(f64, -1), cm[2]);
}

test "herk takes real alpha and beta and yields a real diagonal" {
    // A = [[1+i, 2]], so A*A^H = [|1+i|^2 + |2|^2] = [6].
    const a = [_]C64{ .init(1, 1), .init(2, 0) };
    var cm = [_]C64{C64.zero};
    herk(C64, .row_major, .upper, .no_trans, 1, 2, 1.0, &a, 2, 0.0, &cm, 1);

    try testing.expectApproxEqAbs(@as(f64, 6), cm[0].re, 1e-12);
    // A Hermitian matrix has a real diagonal; a complex beta could not
    // preserve that, which is why the signature takes Scalar(T).
    try testing.expectApproxEqAbs(@as(f64, 0), cm[0].im, 1e-12);
}

test "syr2k matches the equivalent gemm combination" {
    // C = A*B^T + B*A^T for 2x2 A, B.
    const a = [_]f64{ 1, 2, 3, 4 };
    const b = [_]f64{ 0, 1, 1, 0 };

    var from_syr2k = [_]f64{0} ** 4;
    syr2k(f64, .row_major, .upper, .no_trans, 2, 2, 1, &a, 2, &b, 2, 0, &from_syr2k, 2);

    // Build the same thing out of two gemms.
    var want = [_]f64{0} ** 4;
    gemm(f64, .row_major, .no_trans, .trans, 2, 2, 2, 1, &a, 2, &b, 2, 0, &want, 2);
    gemm(f64, .row_major, .no_trans, .trans, 2, 2, 2, 1, &b, 2, &a, 2, 1, &want, 2);

    try testing.expectApproxEqAbs(want[0], from_syr2k[0], 1e-12);
    try testing.expectApproxEqAbs(want[1], from_syr2k[1], 1e-12);
    try testing.expectApproxEqAbs(want[3], from_syr2k[3], 1e-12);
}

test "her2k takes a complex alpha but a real beta" {
    const a = [_]C64{.init(1, 0)};
    const b = [_]C64{.init(0, 1)};
    var cm = [_]C64{C64.zero};
    // alpha*A*B^H + conj(alpha)*B*A^H with alpha = 1:
    //   1*(1)*(-i) + 1*(i)*(1) = -i + i = 0
    her2k(C64, .row_major, .upper, .no_trans, 1, 1, C64.one, &a, 1, &b, 1, 0.0, &cm, 1);
    try testing.expect(cm[0].eqlApprox(C64.zero, 1e-12));
}

test "trmm then trsm is the identity" {
    // A = [[2,1],[0,4]] upper triangular; B is 2x3.
    const a = [_]f64{ 2, 1, 0, 4 };
    const original = [_]f64{ 1, 2, 3, 4, 5, 6 };
    var b = original;

    trmm(f64, .row_major, .left, .upper, .no_trans, .non_unit, 2, 3, 1, &a, 2, &b, 3);
    // B must actually have changed, or the round trip proves nothing.
    try testing.expect(!std.mem.eql(f64, &original, &b));

    trsm(f64, .row_major, .left, .upper, .no_trans, .non_unit, 2, 3, 1, &a, 2, &b, 3);
    for (original, b) |want, got| try testing.expectApproxEqAbs(want, got, 1e-12);
}

test "trsm solves a triangular system with alpha scaling" {
    // A = [[2,0],[1,3]] lower triangular, solve A X = 2*B.
    const a = [_]f64{ 2, 0, 1, 3 };
    var b = [_]f64{ 1, 5 }; // 2x1
    trsm(f64, .row_major, .left, .lower, .no_trans, .non_unit, 2, 1, 2, &a, 2, &b, 1);

    // A x = [2, 10]  =>  x = [1, 3]
    try testing.expectApproxEqAbs(@as(f64, 1), b[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 3), b[1], 1e-12);
}

test "geadd adds two matrices, with transposes" {
    const a = [_]f64{ 1, 2, 3, 4 };
    const b = [_]f64{ 10, 20, 30, 40 };
    var cm = [_]f64{0} ** 4;

    geadd(f64, .row_major, .no_trans, .no_trans, 2, 2, 1, &a, 2, 1, &b, 2, &cm, 2);
    try testing.expectEqualSlices(f64, &.{ 11, 22, 33, 44 }, &cm);

    // Transposing B: A + B^T
    geadd(f64, .row_major, .no_trans, .trans, 2, 2, 1, &a, 2, 1, &b, 2, &cm, 2);
    try testing.expectEqualSlices(f64, &.{ 11, 32, 23, 44 }, &cm);
}

test "geadd with a zero coefficient does not read that matrix" {
    // The header says a zero alpha or beta means the matrix is not accessed at
    // all, so an empty slice must be accepted.
    const b = [_]f64{ 1, 2, 3, 4 };
    var cm = [_]f64{0} ** 4;
    geadd(f64, .row_major, .no_trans, .no_trans, 2, 2, 0, &.{}, 2, 3, &b, 2, &cm, 2);
    try testing.expectEqualSlices(f64, &.{ 3, 6, 9, 12 }, &cm);
}

test "a larger gemm still matches the naive reference" {
    // Big enough to exercise a blocked path rather than a special case.
    const n = 24;
    var a: [n * n]f64 = undefined;
    var b: [n * n]f64 = undefined;
    for (&a, 0..) |*v, i| v.* = @as(f64, @floatFromInt(i % 7)) - 3;
    for (&b, 0..) |*v, i| v.* = @as(f64, @floatFromInt((i * 3) % 5)) - 2;

    var want: [n * n]f64 = undefined;
    refGemm(f64, n, n, n, &a, &b, &want);

    var got: [n * n]f64 = undefined;
    gemm(f64, .row_major, .no_trans, .no_trans, n, n, n, 1, &a, n, &b, n, 0, &got, n);

    for (want, got) |w, g| try testing.expectApproxEqAbs(w, g, 1e-9);
}
