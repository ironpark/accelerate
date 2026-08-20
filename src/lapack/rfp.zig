//! Rectangular full packed storage.
//!
//! A third way to store a triangular or symmetric matrix, and the only one that
//! is both compact *and* usable by the blocked kernels.
//!
//! | storage | space | blocked kernels |
//! |---|---|---|
//! | full (`a`, `lda`) | `n^2` | yes |
//! | packed (`ap`) | `n(n+1)/2` | no |
//! | RFP (`arf`) | `n(n+1)/2` | yes |
//!
//! Packed storage halves the memory and gives up all the performance, because
//! its triangular rows have no leading dimension to stride by. RFP keeps the
//! `n(n+1)/2` element count but folds the triangle into a *rectangle* —
//! roughly `n x (n+1)/2` — whose columns do have a stride, so `trmm` and
//! friends work on it directly. In practice it is as fast as full storage in
//! half the space.
//!
//! ## Two shape flags, not one
//!
//! Every routine here takes a `transr` alongside the usual `uplo`. `uplo` says
//! which triangle of the original matrix is stored, as always; `transr` says
//! whether the *rectangle* is laid out normally or transposed. They are
//! independent, and the four combinations are four different layouts.
//!
//! There is no reason to prefer one `transr` over the other for a fresh matrix.
//! It matters when converting: `trttf` writes whichever you ask for, and
//! `tfttr` must be told the same one back.
//!
//! ## Getting data in and out
//!
//! Nothing constructs an RFP matrix directly. The four conversions do:
//!
//! - `trttf` / `tfttr` — full triangular to RFP and back
//! - `tpttf` / `tfttp` — packed to RFP and back
//!
//! They are exact, elementwise copies, so a round trip is bit-identical.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");

const Int = types.Int;
const Complex = types.Complex;
const Real = types.Real;
const Uplo = types.Uplo;
const Side = types.Side;
const Trans = types.Trans;
const Diag = types.Diag;
const Error = info_mod.Error;
const dim = types.dim;
const assertMatrix = types.assertMatrix;
const packedLen = types.packedLen;
const ref = work_mod.ref;
const out = work_mod.out;
const opt = types.opt;

fn sym(comptime T: type, comptime name: []const u8) @TypeOf(@field(c, [_]u8{types.prefix(T)} ++ name)) {
    return @field(c, [_]u8{types.prefix(T)} ++ name);
}

fn requireComplex(comptime T: type, comptime routine: []const u8, comptime alternative: []const u8) void {
    switch (T) {
        Complex(f32), Complex(f64) => {},
        else => @compileError(routine ++ " is complex-only; for " ++ @typeName(T) ++ " use " ++ alternative),
    }
}

/// How the RFP rectangle itself is laid out.
///
/// Independent of `uplo`, which still says which triangle of the original the
/// data came from. For a complex matrix the transposed form is conjugated, so
/// the two are `'N'` and `'C'` rather than `'N'` and `'T'`; this enum emits the
/// right character for `T`.
pub const RfpLayout = enum {
    /// The rectangle as stored.
    normal,
    /// The rectangle transposed (conjugate-transposed for complex `T`).
    transposed,
};

fn layout(comptime T: type, l: RfpLayout) [*]const u8 {
    const Chars = enum(u8) { n = 'N', t = 'T', c_ = 'C' };
    return switch (l) {
        .normal => opt(Chars.n),
        .transposed => switch (T) {
            f32, f64 => opt(Chars.t),
            else => opt(Chars.c_),
        },
    };
}

/// Elements an RFP array needs for an order-`n` matrix. The same count as
/// packed storage.
pub fn rfpLen(n: usize) usize {
    return packedLen(n);
}

// ============================================================================
// Conversions
// ============================================================================

/// Full triangular storage to RFP.
pub fn trttf(
    comptime T: type,
    transr: RfpLayout,
    uplo: Uplo,
    n: usize,
    a: []const T,
    lda: usize,
    arf: []T,
) Error!void {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(arf.len >= rfpLen(n));

    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    var info: Int = 0;

    sym(T, "trttf")(layout(T, transr), opt(uplo), ref(&n_), a.ptr, ref(&lda_), arf.ptr, out(&info));
    return info_mod.checkArgs(info);
}

/// RFP back to full triangular storage. Only the `uplo` triangle is written.
pub fn tfttr(
    comptime T: type,
    transr: RfpLayout,
    uplo: Uplo,
    n: usize,
    arf: []const T,
    a: []T,
    lda: usize,
) Error!void {
    std.debug.assert(arf.len >= rfpLen(n));
    assertMatrix(a.len, n, n, lda);

    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    var info: Int = 0;

    sym(T, "tfttr")(layout(T, transr), opt(uplo), ref(&n_), arf.ptr, a.ptr, ref(&lda_), out(&info));
    return info_mod.checkArgs(info);
}

/// Packed storage to RFP. Same element count, different arrangement.
pub fn tpttf(
    comptime T: type,
    transr: RfpLayout,
    uplo: Uplo,
    n: usize,
    ap: []const T,
    arf: []T,
) Error!void {
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(arf.len >= rfpLen(n));

    const n_ = dim(n);
    var info: Int = 0;

    sym(T, "tpttf")(layout(T, transr), opt(uplo), ref(&n_), ap.ptr, arf.ptr, out(&info));
    return info_mod.checkArgs(info);
}

/// RFP back to packed storage.
pub fn tfttp(
    comptime T: type,
    transr: RfpLayout,
    uplo: Uplo,
    n: usize,
    arf: []const T,
    ap: []T,
) Error!void {
    std.debug.assert(arf.len >= rfpLen(n));
    std.debug.assert(ap.len >= packedLen(n));

    const n_ = dim(n);
    var info: Int = 0;

    sym(T, "tfttp")(layout(T, transr), opt(uplo), ref(&n_), arf.ptr, ap.ptr, out(&info));
    return info_mod.checkArgs(info);
}

// ============================================================================
// Computation in RFP
// ============================================================================

/// Cholesky in RFP storage.
///
/// The reason RFP exists: this is a blocked factorization at packed-storage
/// memory cost, where `factor.pptrf` is unblocked.
pub fn pftrf(
    comptime T: type,
    transr: RfpLayout,
    uplo: Uplo,
    n: usize,
    arf: []T,
) Error!void {
    std.debug.assert(arf.len >= rfpLen(n));

    const n_ = dim(n);
    var info: Int = 0;

    sym(T, "pftrf")(layout(T, transr), opt(uplo), ref(&n_), arf.ptr, out(&info));
    return info_mod.checkCholesky(info);
}

/// Solves using a `pftrf` factorization.
pub fn pftrs(
    comptime T: type,
    transr: RfpLayout,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    arf: []const T,
    b: []T,
    ldb: usize,
) Error!void {
    std.debug.assert(arf.len >= rfpLen(n));
    assertMatrix(b.len, n, nrhs, ldb);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(@max(ldb, 1));
    var info: Int = 0;

    sym(T, "pftrs")(layout(T, transr), opt(uplo), ref(&n_), ref(&nrhs_), arf.ptr, b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkArgs(info);
}

/// Inverse of a positive definite matrix in RFP, from its `pftrf` factor.
pub fn pftri(
    comptime T: type,
    transr: RfpLayout,
    uplo: Uplo,
    n: usize,
    arf: []T,
) Error!void {
    std.debug.assert(arf.len >= rfpLen(n));

    const n_ = dim(n);
    var info: Int = 0;

    sym(T, "pftri")(layout(T, transr), opt(uplo), ref(&n_), arf.ptr, out(&info));
    return info_mod.checkLu(info);
}

/// Inverse of a triangular matrix in RFP.
pub fn tftri(
    comptime T: type,
    transr: RfpLayout,
    uplo: Uplo,
    diag: Diag,
    n: usize,
    arf: []T,
) Error!void {
    std.debug.assert(arf.len >= rfpLen(n));

    const n_ = dim(n);
    var info: Int = 0;

    sym(T, "tftri")(layout(T, transr), opt(uplo), opt(diag), ref(&n_), arf.ptr, out(&info));
    return info_mod.checkLu(info);
}

/// `trsm` with the triangular matrix in RFP storage.
///
/// Solves `op(A) X = alpha B` or `X op(A) = alpha B` in place. The BLAS
/// operation, taking its triangle from a packed-size array — which `trsm`
/// itself cannot do and `tpsv` can only do one column at a time.
///
/// Reports nothing: like `tprfb`, the C signature has no `info`.
pub fn tfsm(
    comptime T: type,
    transr: RfpLayout,
    side: Side,
    uplo: Uplo,
    trans: Trans,
    diag: Diag,
    rows: usize,
    cols: usize,
    alpha: T,
    arf: []const T,
    b: []T,
    ldb: usize,
) void {
    const order = if (side == .left) rows else cols;
    std.debug.assert(arf.len >= rfpLen(order));
    assertMatrix(b.len, rows, cols, ldb);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const ldb_ = dim(@max(ldb, 1));

    sym(T, "tfsm")(layout(T, transr), opt(side), opt(uplo), opt(trans), opt(diag), ref(&m_), ref(&n_), ref(&alpha), arf.ptr, b.ptr, ref(&ldb_));
}

/// `syrk` with the result in RFP storage: `C = alpha A A^T + beta C`.
///
/// `trans = .no_trans` forms `A A^T` for an `n x k` `A`; `.transpose` forms
/// `A^T A` for a `k x n` one.
///
/// Reports nothing, like `tfsm`. Note `alpha` and `beta` are **real** even for
/// a complex `T` — `hfrk` computes a Hermitian result, whose diagonal is real,
/// and a complex scale factor would break that. `sfrk` inherits the same
/// signature.
pub fn sfrk(
    comptime T: type,
    transr: RfpLayout,
    uplo: Uplo,
    trans: Trans,
    n: usize,
    k: usize,
    alpha: Real(T),
    a: []const T,
    lda: usize,
    beta: Real(T),
    cf: []T,
) void {
    std.debug.assert(cf.len >= rfpLen(n));

    const n_ = dim(n);
    const k_ = dim(k);
    const lda_ = dim(@max(lda, 1));

    sym(T, "sfrk")(layout(T, transr), opt(uplo), opt(trans), ref(&n_), ref(&k_), ref(&alpha), a.ptr, ref(&lda_), ref(&beta), cf.ptr);
}

/// `sfrk` for a Hermitian result. Complex only.
pub fn hfrk(
    comptime T: type,
    transr: RfpLayout,
    uplo: Uplo,
    trans: Trans,
    n: usize,
    k: usize,
    alpha: Real(T),
    a: []const T,
    lda: usize,
    beta: Real(T),
    cf: []T,
) void {
    requireComplex(T, "hfrk", "sfrk");
    std.debug.assert(cf.len >= rfpLen(n));

    const n_ = dim(n);
    const k_ = dim(k);
    const lda_ = dim(@max(lda, 1));

    sym(T, "hfrk")(layout(T, transr), opt(uplo), opt(trans), ref(&n_), ref(&k_), ref(&alpha), a.ptr, ref(&lda_), ref(&beta), cf.ptr);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const factor = @import("factor.zig");

/// A 4x4 symmetric positive definite matrix, column-major.
const spd4 = [_]f64{
    9, 1, 2, 3,
    1, 8, 1, 2,
    2, 1, 7, 1,
    3, 2, 1, 6,
};

fn upperPacked(n: usize, a: []const f64, ap: []f64) void {
    var at: usize = 0;
    for (0..n) |j| for (0..j + 1) |i| {
        ap[at] = a[i + j * n];
        at += 1;
    };
}

test "trttf and tfttr round-trip exactly, in both layouts" {
    const n = 4;
    for ([_]RfpLayout{ .normal, .transposed }) |transr| {
        var arf: [10]f64 = undefined;
        try trttf(f64, transr, .upper, n, &spd4, n, &arf);

        var back = [_]f64{-1} ** (n * n);
        try tfttr(f64, transr, .upper, n, &arf, &back, n);

        // Exact, not approximate: this is an elementwise copy.
        for (0..n) |j| for (0..j + 1) |i| {
            try testing.expectEqual(spd4[i + j * n], back[i + j * n]);
        };
        // And only the requested triangle was written.
        try testing.expectEqual(@as(f64, -1), back[1]);
    }
}

test "the two layouts are genuinely different arrangements" {
    const n = 4;
    var normal: [10]f64 = undefined;
    var transposed: [10]f64 = undefined;
    try trttf(f64, .normal, .upper, n, &spd4, n, &normal);
    try trttf(f64, .transposed, .upper, n, &spd4, n, &transposed);

    // Same multiset of values, different order - so telling tfttr the wrong
    // transr gives a wrong matrix rather than an error.
    try testing.expect(!std.mem.eql(f64, &normal, &transposed));
    var a = normal;
    var b = transposed;
    std.mem.sort(f64, &a, {}, std.sort.asc(f64));
    std.mem.sort(f64, &b, {}, std.sort.asc(f64));
    try testing.expectEqualSlices(f64, &a, &b);
}

test "tpttf and tfttp round-trip through packed storage" {
    const n = 4;
    var ap: [10]f64 = undefined;
    upperPacked(n, &spd4, &ap);

    var arf: [10]f64 = undefined;
    try tpttf(f64, .normal, .upper, n, &ap, &arf);

    var back: [10]f64 = undefined;
    try tfttp(f64, .normal, .upper, n, &arf, &back);
    try testing.expectEqualSlices(f64, &ap, &back);

    // And the same RFP array the full-storage conversion produces.
    var from_full: [10]f64 = undefined;
    try trttf(f64, .normal, .upper, n, &spd4, n, &from_full);
    try testing.expectEqualSlices(f64, &from_full, &arf);
}

test "pftrf factors in half the space pptrf needs the same arithmetic for" {
    const n = 4;
    var arf: [10]f64 = undefined;
    try trttf(f64, .normal, .upper, n, &spd4, n, &arf);
    try pftrf(f64, .normal, .upper, n, &arf);

    // The same factorization pptrf produces, up to the storage arrangement.
    var ap: [10]f64 = undefined;
    upperPacked(n, &spd4, &ap);
    try factor.pptrf(f64, .upper, n, &ap);

    var converted: [10]f64 = undefined;
    try tfttp(f64, .normal, .upper, n, &arf, &converted);
    for (ap, converted) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "pftrf then pftrs solves, and pftri inverts" {
    const n = 4;
    const b0 = [_]f64{ 1, 2, 3, 4 };
    var arf: [10]f64 = undefined;
    try trttf(f64, .normal, .upper, n, &spd4, n, &arf);
    try pftrf(f64, .normal, .upper, n, &arf);

    var b = b0;
    try pftrs(f64, .normal, .upper, n, 1, &arf, &b, n);
    for (0..n) |i| {
        var acc: f64 = 0;
        for (0..n) |j| acc += spd4[i + j * n] * b[j];
        try testing.expectApproxEqAbs(b0[i], acc, 1e-11);
    }

    try pftri(f64, .normal, .upper, n, &arf);
    var inv = [_]f64{0} ** (n * n);
    try tfttr(f64, .normal, .upper, n, &arf, &inv, n);
    // A A^-1 = I, reading the inverse's lower half by symmetry.
    for (0..n) |j| for (0..n) |i| {
        var acc: f64 = 0;
        for (0..n) |k| {
            const ik = if (k <= i) inv[k + i * n] else inv[i + k * n];
            acc += spd4[j + k * n] * ik;
        }
        try testing.expectApproxEqAbs(if (i == j) @as(f64, 1) else 0, acc, 1e-11);
    };
}

test "pftrf reports a matrix that is not positive definite" {
    const n = 2;
    const indefinite = [_]f64{ 1, 2, 2, 1 };
    var arf: [3]f64 = undefined;
    try trttf(f64, .normal, .upper, n, &indefinite, n, &arf);
    try testing.expectError(error.NotPositiveDefinite, pftrf(f64, .normal, .upper, n, &arf));
}

test "tftri matches trtri" {
    const n = 4;
    const t = [_]f64{
        2, 0, 0, 0,
        1, 3, 0, 0,
        4, 1, 5, 0,
        2, 3, 1, 7,
    };
    var arf: [10]f64 = undefined;
    try trttf(f64, .normal, .upper, n, &t, n, &arf);
    try tftri(f64, .normal, .upper, .non_unit, n, &arf);
    var from_rfp = [_]f64{0} ** (n * n);
    try tfttr(f64, .normal, .upper, n, &arf, &from_rfp, n);

    var direct = t;
    try factor.trtri(f64, .upper, .non_unit, n, &direct, n);

    for (0..n) |j| for (0..j + 1) |i| {
        try testing.expectApproxEqAbs(direct[i + j * n], from_rfp[i + j * n], 1e-12);
    };
}

test "tfsm solves the same system trsm would, and reports nothing" {
    const n = 3;
    const t = [_]f64{ 2, 0, 0, 1, 3, 0, 4, 1, 5 };
    const b0 = [_]f64{ 1, 2, 3 };

    var arf: [6]f64 = undefined;
    try trttf(f64, .normal, .upper, n, &t, n, &arf);

    var b = b0;
    // No error union: the C signature has no info at all.
    tfsm(f64, .normal, .left, .upper, .no_trans, .non_unit, n, 1, 1, &arf, &b, n);

    // T x = b, checked against the original.
    for (0..n) |i| {
        var acc: f64 = 0;
        for (i..n) |j| acc += t[i + j * n] * b[j];
        try testing.expectApproxEqAbs(b0[i], acc, 1e-12);
    }
}

test "sfrk takes real alpha and beta even for a complex T" {
    const n = 3;
    const k = 2;
    const a = [_]f64{ 1, 2, 3, 4, 5, 6 };
    var cf = [_]f64{0} ** 6;

    sfrk(f64, .normal, .upper, .no_trans, n, k, 1, &a, n, 0, &cf);

    var full = [_]f64{0} ** (n * n);
    try tfttr(f64, .normal, .upper, n, &cf, &full, n);

    // A A^T for the 3x2 A.
    for (0..n) |j| for (0..j + 1) |i| {
        var acc: f64 = 0;
        for (0..k) |t| acc += a[i + t * n] * a[j + t * n];
        try testing.expectApproxEqAbs(acc, full[i + j * n], 1e-12);
    };
}

test "hfrk keeps a real diagonal, which a complex alpha would not" {
    const Z = Complex(f64);
    const n = 2;
    const k = 2;
    const a = [_]Z{
        Z.init(1, 1), Z.init(2, -1),
        Z.init(0, 2), Z.init(3, 0),
    };
    var cf = [_]Z{Z.init(0, 0)} ** 3;

    hfrk(Z, .normal, .upper, .no_trans, n, k, 2, &a, n, 0, &cf);

    var full = [_]Z{Z.init(0, 0)} ** (n * n);
    try tfttr(Z, .normal, .upper, n, &cf, &full, n);

    // A Hermitian matrix has a real diagonal; that is why the scale factors are
    // Real(T) here rather than T.
    for (0..n) |i| try testing.expectApproxEqAbs(@as(f64, 0), full[i + i * n].im, 1e-14);
    // And the diagonal is alpha * (sum of squared moduli of row i): row 0 is
    // (1+i, 2i), so 2 * (2 + 4).
    try testing.expectApproxEqAbs(@as(f64, 2 * (2 + 4)), full[0].re, 1e-12);
}
