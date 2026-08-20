//! Matrix norms, plus the two copy/initialise helpers that go with them.
//!
//! These exist here mostly because the condition estimators need them: `gecon`
//! and friends do not compute `||A||` themselves, they take it as an argument,
//! and it must be the norm of the *original* matrix rather than of the factor
//! that replaced it. Getting the norm from the wrong matrix is the single
//! easiest way to produce a confident, wrong condition number.
//!
//! ## The workspace rule is not uniform
//!
//! Every `lan*` routine takes a real workspace that it references only for
//! certain norms, and *which* norms differ by routine:
//!
//! | routine | needs workspace for |
//! |---|---|
//! | `lange`, `langb` | `.infinity` only |
//! | `lansy`, `lanhe`, `lantr`, `lansp`, `lanhp` | `.infinity` **and** `.one` |
//! | `lanst`, `lanht` | never |
//!
//! The reason is symmetry: for a symmetric matrix the 1-norm and the
//! infinity-norm are the same quantity, and LAPACK computes both by
//! accumulating row sums, which needs somewhere to accumulate. For a general
//! matrix the 1-norm is a straight column-wise scan and needs nothing.
//!
//! Rather than have callers remember that, each wrapper exposes a
//! `...WorkspaceLen` companion and asserts the slice it is given is long
//! enough. An empty slice is fine whenever the norm does not need one.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");

const Int = types.Int;
const Complex = types.Complex;
const Real = types.Real;
const Uplo = types.Uplo;
const Norm = types.Norm;
const Diag = types.Diag;
const dim = types.dim;
const assertMatrix = types.assertMatrix;
const packedLen = types.packedLen;
const ref = @import("work.zig").ref;
const opt = types.opt;

fn sym(comptime T: type, comptime name: []const u8) @TypeOf(@field(c, [_]u8{types.prefix(T)} ++ name)) {
    return @field(c, [_]u8{types.prefix(T)} ++ name);
}

/// Rejects a real `T` at compile time.
///
/// This is a `switch` rather than `if (!isComplex(T)) @compileError(...)`
/// because Zig analyses the body of a plain `if` even when the condition is
/// comptime-known false, so the guard would fire on every instantiation. A
/// `switch` prong is only analysed when it is the one selected.
fn requireComplex(comptime T: type, comptime routine: []const u8, comptime alternative: []const u8) void {
    switch (T) {
        Complex(f32), Complex(f64) => {},
        else => @compileError(routine ++ " is complex-only; for " ++ @typeName(T) ++ " use " ++ alternative),
    }
}

/// Rejects a complex `T` at compile time. See `requireComplex`.
fn requireReal(comptime T: type, comptime routine: []const u8, comptime alternative: []const u8) void {
    switch (T) {
        f32, f64 => {},
        else => @compileError(routine ++ " is real-only; for " ++ @typeName(T) ++ " use " ++ alternative),
    }
}

/// Workspace length `lange`/`langb` need for `norm`.
pub fn langeWorkspaceLen(norm: Norm, rows: usize) usize {
    return if (norm == .infinity) rows else 0;
}

/// Workspace length the symmetric, Hermitian and triangular norms need.
pub fn symmetricWorkspaceLen(norm: Norm, n: usize) usize {
    return switch (norm) {
        .infinity, .one => n,
        else => 0,
    };
}

/// `||A||` for a general `rows x cols` matrix.
///
/// Note that `.max_abs` is `max |a_ij|`, which is *not* submultiplicative and
/// so is not a matrix norm in the usual sense - it is offered because LAPACK
/// offers it, and because it is what you want for a quick magnitude check.
pub fn lange(
    comptime T: type,
    norm: Norm,
    rows: usize,
    cols: usize,
    a: []const T,
    lda: usize,
    work: []Real(T),
) Real(T) {
    assertMatrix(a.len, rows, cols, lda);
    std.debug.assert(work.len >= langeWorkspaceLen(norm, rows));

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(lda);
    return sym(T, "lange")(opt(norm), ref(&m_), ref(&n_), a.ptr, ref(&lda_), work.ptr);
}

/// `||A||` for a symmetric matrix, reading only the `uplo` triangle.
///
/// For complex `T` this is the **symmetric** norm (`A = A^T`), not the
/// Hermitian one. `lanhe` is the Hermitian form, and the two give different
/// answers for the same stored triangle.
pub fn lansy(
    comptime T: type,
    norm: Norm,
    uplo: Uplo,
    n: usize,
    a: []const T,
    lda: usize,
    work: []Real(T),
) Real(T) {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(work.len >= symmetricWorkspaceLen(norm, n));

    const n_ = dim(n);
    const lda_ = dim(lda);
    return sym(T, "lansy")(opt(norm), opt(uplo), ref(&n_), a.ptr, ref(&lda_), work.ptr);
}

/// `||A||` for a Hermitian matrix. Complex only - for real elements this is
/// `lansy`, and LAPACK ships no `slanhe`.
pub fn lanhe(
    comptime T: type,
    norm: Norm,
    uplo: Uplo,
    n: usize,
    a: []const T,
    lda: usize,
    work: []Real(T),
) Real(T) {
    requireComplex(T, "lanhe", "lansy");
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(work.len >= symmetricWorkspaceLen(norm, n));

    const n_ = dim(n);
    const lda_ = dim(lda);
    return sym(T, "lanhe")(opt(norm), opt(uplo), ref(&n_), a.ptr, ref(&lda_), work.ptr);
}

/// `||A||` for a triangular (or trapezoidal) matrix.
///
/// With `diag = .unit` the stored diagonal is ignored and taken to be 1, which
/// changes the answer - a norm computed with the wrong `diag` is silently off.
pub fn lantr(
    comptime T: type,
    norm: Norm,
    uplo: Uplo,
    diag: Diag,
    rows: usize,
    cols: usize,
    a: []const T,
    lda: usize,
    work: []Real(T),
) Real(T) {
    assertMatrix(a.len, rows, cols, lda);
    std.debug.assert(work.len >= symmetricWorkspaceLen(norm, rows));

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(lda);
    return sym(T, "lantr")(opt(norm), opt(uplo), opt(diag), ref(&m_), ref(&n_), a.ptr, ref(&lda_), work.ptr);
}

/// `||A||` for a symmetric matrix in packed storage.
pub fn lansp(
    comptime T: type,
    norm: Norm,
    uplo: Uplo,
    n: usize,
    ap: []const T,
    work: []Real(T),
) Real(T) {
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(work.len >= symmetricWorkspaceLen(norm, n));

    const n_ = dim(n);
    return sym(T, "lansp")(opt(norm), opt(uplo), ref(&n_), ap.ptr, work.ptr);
}

/// `||A||` for a Hermitian matrix in packed storage. Complex only.
pub fn lanhp(
    comptime T: type,
    norm: Norm,
    uplo: Uplo,
    n: usize,
    ap: []const T,
    work: []Real(T),
) Real(T) {
    requireComplex(T, "lanhp", "lansp");
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(work.len >= symmetricWorkspaceLen(norm, n));

    const n_ = dim(n);
    return sym(T, "lanhp")(opt(norm), opt(uplo), ref(&n_), ap.ptr, work.ptr);
}

/// `||A||` for a general band matrix in `gbmv`-style band storage
/// (`ldab >= kl + ku + 1`, no fill-in rows).
///
/// This is the band layout *without* the extra `kl` rows `gbtrf` needs, so a
/// factored band array is the wrong input here.
pub fn langb(
    comptime T: type,
    norm: Norm,
    n: usize,
    kl: usize,
    ku: usize,
    ab: []const T,
    ldab: usize,
    work: []Real(T),
) Real(T) {
    std.debug.assert(ldab >= kl + ku + 1);
    assertMatrix(ab.len, kl + ku + 1, n, ldab);
    std.debug.assert(work.len >= langeWorkspaceLen(norm, n));

    const n_ = dim(n);
    const kl_ = dim(kl);
    const ku_ = dim(ku);
    const ldab_ = dim(ldab);
    return sym(T, "langb")(opt(norm), ref(&n_), ref(&kl_), ref(&ku_), ab.ptr, ref(&ldab_), work.ptr);
}

/// `||A||` for a real symmetric tridiagonal matrix. Needs no workspace.
pub fn lanst(
    comptime T: type,
    norm: Norm,
    n: usize,
    d: []const T,
    e: []const T,
) T {
    requireReal(T, "lanst", "lanht");
    std.debug.assert(d.len >= n);
    if (n > 1) std.debug.assert(e.len >= n - 1);

    const n_ = dim(n);
    return sym(T, "lanst")(opt(norm), ref(&n_), d.ptr, e.ptr);
}

/// `||A||` for a complex Hermitian tridiagonal matrix.
///
/// `d` is real, as it must be for a Hermitian matrix - the same asymmetry
/// `ptsv` has.
pub fn lanht(
    comptime T: type,
    norm: Norm,
    n: usize,
    d: []const Real(T),
    e: []const T,
) Real(T) {
    requireComplex(T, "lanht", "lanst");
    std.debug.assert(d.len >= n);
    if (n > 1) std.debug.assert(e.len >= n - 1);

    const n_ = dim(n);
    return sym(T, "lanht")(opt(norm), ref(&n_), d.ptr, e.ptr);
}

// ============================================================================
// Copy and initialise
// ============================================================================

/// Which part of a matrix `lacpy`/`laset` touches.
///
/// This is `Uplo` plus a "whole matrix" option, which is why it is a separate
/// enum rather than an optional `Uplo` - LAPACK spells it as the same character
/// argument with a third accepted letter.
pub const Part = enum(u8) {
    upper = 'U',
    lower = 'L',
    all = 'A',

    pub fn from(uplo: Uplo) Part {
        return switch (uplo) {
            .upper => .upper,
            .lower => .lower,
        };
    }
};

/// `B := A` for the selected part.
///
/// The usual reason to want this: the factorization routines overwrite their
/// input, and the condition estimators need the norm of the original. Copy
/// first, or compute the norm first - but do one of them.
pub fn lacpy(
    comptime T: type,
    part: Part,
    rows: usize,
    cols: usize,
    a: []const T,
    lda: usize,
    b: []T,
    ldb: usize,
) void {
    assertMatrix(a.len, rows, cols, lda);
    assertMatrix(b.len, rows, cols, ldb);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    sym(T, "lacpy")(opt(part), ref(&m_), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_));
}

/// Sets the off-diagonal of the selected part to `alpha` and the diagonal to
/// `beta`.
///
/// Two scalars rather than one because the common uses want them different:
/// `laset(.all, 0, 1, ...)` builds an identity, `laset(.all, 0, 0, ...)` zeroes.
pub fn laset(
    comptime T: type,
    part: Part,
    rows: usize,
    cols: usize,
    alpha: T,
    beta: T,
    a: []T,
    lda: usize,
) void {
    assertMatrix(a.len, rows, cols, lda);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(lda);
    sym(T, "laset")(opt(part), ref(&m_), ref(&n_), ref(&alpha), ref(&beta), a.ptr, ref(&lda_));
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "lange computes each norm of a known matrix" {
    // Column-major [[1, 3], [2, 4]].
    const a = [_]f64{ 1, 2, 3, 4 };
    var work: [2]f64 = undefined;

    // max |a_ij|
    try testing.expectEqual(@as(f64, 4), lange(f64, .max_abs, 2, 2, &a, 2, &work));
    // 1-norm: max column sum -> max(1+2, 3+4) = 7
    try testing.expectEqual(@as(f64, 7), lange(f64, .one, 2, 2, &a, 2, &work));
    // infinity-norm: max row sum -> max(1+3, 2+4) = 6
    try testing.expectEqual(@as(f64, 6), lange(f64, .infinity, 2, 2, &a, 2, &work));
    // Frobenius: sqrt(1 + 4 + 9 + 16)
    try testing.expectApproxEqAbs(@sqrt(@as(f64, 30)), lange(f64, .frobenius, 2, 2, &a, 2, &work), 1e-12);
}

test "lange needs no workspace except for the infinity norm" {
    const a = [_]f64{ 1, 2, 3, 4 };
    const none: []f64 = &.{};

    // An empty slice is accepted for the three norms that never dereference it,
    // which is what langeWorkspaceLen promises.
    try testing.expectEqual(@as(usize, 0), langeWorkspaceLen(.one, 2));
    try testing.expectEqual(@as(usize, 2), langeWorkspaceLen(.infinity, 2));
    try testing.expectEqual(@as(f64, 7), lange(f64, .one, 2, 2, &a, 2, none));
    try testing.expectEqual(@as(f64, 4), lange(f64, .max_abs, 2, 2, &a, 2, none));
}

test "lange writes nothing past the workspace it was promised" {
    // Pins the size langeWorkspaceLen reports. If the real requirement were
    // larger, the poison below would be overwritten - which is the only way to
    // check a documented workspace size without reading LAPACK's source.
    const a = [_]f64{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    var work = [_]f64{-999} ** 8;
    const needed = langeWorkspaceLen(.infinity, 3);
    try testing.expectEqual(@as(usize, 3), needed);

    _ = lange(f64, .infinity, 3, 3, &a, 3, work[0..needed]);

    for (work[needed..]) |slot| try testing.expectEqual(@as(f64, -999), slot);
}

test "lansy reads only the requested triangle" {
    // [[1, 2], [2, 5]] stored upper, with the strict lower poisoned.
    const a = [_]f64{ 1, -999, 2, 5 };
    var work: [2]f64 = undefined;

    // 1-norm of the full symmetric matrix: max(1+2, 2+5) = 7.
    try testing.expectEqual(@as(f64, 7), lansy(f64, .one, .upper, 2, &a, 2, &work));
    // For a symmetric matrix the 1- and infinity-norms coincide, which is why
    // both need the accumulation workspace and lange's 1-norm does not.
    try testing.expectEqual(@as(f64, 7), lansy(f64, .infinity, .upper, 2, &a, 2, &work));
}

test "lanhe and lansy disagree on the same complex triangle" {
    const Z = Complex(f64);
    // Lower triangle holds A(1,1) = 2, A(2,1) = 3+4i, A(2,2) = 2.
    const a = [_]Z{ Z.init(2, 0), Z.init(3, 4), Z.init(0, 0), Z.init(2, 0) };
    var work: [2]f64 = undefined;

    // Hermitian: A(1,2) = conj(A(2,1)) = 3-4i, so column 1 sums to 2 + 5 = 7.
    const herm = lanhe(Z, .one, .lower, 2, &a, 2, &work);
    // Symmetric: A(1,2) = A(2,1) = 3+4i, same magnitude, same 1-norm here.
    const symm = lansy(Z, .one, .lower, 2, &a, 2, &work);
    try testing.expectApproxEqAbs(@as(f64, 7), herm, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 7), symm, 1e-12);

    // The 1-norms coincide because |conj(z)| = |z|. Where they genuinely part
    // company is the Frobenius norm of a matrix whose diagonal is complex:
    // lanhe ignores the stored imaginary part of the diagonal (a Hermitian
    // matrix cannot have one), lansy does not.
    const b = [_]Z{ Z.init(0, 5), Z.init(0, 0), Z.init(0, 0), Z.init(0, 0) };
    const fh = lanhe(Z, .frobenius, .lower, 2, &b, 2, &work);
    const fs = lansy(Z, .frobenius, .lower, 2, &b, 2, &work);
    try testing.expectApproxEqAbs(@as(f64, 0), fh, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 5), fs, 1e-12);
}

test "lantr respects the unit-diagonal flag" {
    // Upper triangular [[7, 2], [0, 9]].
    const a = [_]f64{ 7, 0, 2, 9 };
    var work: [2]f64 = undefined;

    // Non-unit: max column sum is max(7, 2 + 9) = 11.
    try testing.expectEqual(@as(f64, 11), lantr(f64, .one, .upper, .non_unit, 2, 2, &a, 2, &work));
    // Unit: the stored diagonal is ignored and taken as 1, so max(1, 2 + 1) = 3.
    try testing.expectEqual(@as(f64, 3), lantr(f64, .one, .upper, .unit, 2, 2, &a, 2, &work));
}

test "lansp matches lansy on the same matrix" {
    // Upper packed [[1, 2], [2, 5]] is a11, a12, a22.
    const ap = [_]f64{ 1, 2, 5 };
    const a = [_]f64{ 1, 0, 2, 5 };
    var work: [2]f64 = undefined;

    try testing.expectEqual(
        lansy(f64, .one, .upper, 2, &a, 2, &work),
        lansp(f64, .one, .upper, 2, &ap, &work),
    );
}

test "lanst needs no workspace at all" {
    const d = [_]f64{ 4, 4, 4 };
    const e = [_]f64{ 1, 1 };
    // 1-norm of tridiag(1, 4, 1) is 4 + 1 + 1 = 6 for the interior columns.
    try testing.expectEqual(@as(f64, 6), lanst(f64, .one, 3, &d, &e));
    try testing.expectEqual(@as(f64, 4), lanst(f64, .max_abs, 3, &d, &e));
}

test "lanht takes a real diagonal" {
    const Z = Complex(f64);
    const d = [_]f64{ 4, 4 };
    const e = [_]Z{Z.init(3, 4)}; // magnitude 5
    try testing.expectEqual(@as(f64, 9), lanht(Z, .one, 2, &d, &e));
}

test "lacpy copies only the selected part" {
    const a = [_]f64{ 1, 2, 3, 4 }; // column-major [[1, 3], [2, 4]]
    var b = [_]f64{ -1, -1, -1, -1 };

    lacpy(f64, .upper, 2, 2, &a, 2, &b, 2);

    // Upper means a11, a12, a22 - the strict lower stays as it was.
    try testing.expectEqual(@as(f64, 1), b[0]);
    try testing.expectEqual(@as(f64, -1), b[1]);
    try testing.expectEqual(@as(f64, 3), b[2]);
    try testing.expectEqual(@as(f64, 4), b[3]);
}

test "laset builds an identity from its two scalars" {
    var a = [_]f64{-1} ** 9;
    laset(f64, .all, 3, 3, 0, 1, &a, 3);

    for (0..3) |i| {
        for (0..3) |j| {
            const want: f64 = if (i == j) 1 else 0;
            try testing.expectEqual(want, a[i + j * 3]);
        }
    }
}

test "norms work in single precision and through complex" {
    const a = [_]f32{ 3, 4 };
    var work: [2]f32 = undefined;
    try testing.expectApproxEqAbs(@as(f32, 5), lange(f32, .frobenius, 2, 1, &a, 2, &work), 1e-6);

    const Z = Complex(f32);
    const z = [_]Z{Z.init(3, 4)};
    var zwork: [1]f32 = undefined;
    // Real(Complex(f32)) is f32, so the norm comes back real.
    const n = lange(Z, .frobenius, 1, 1, &z, 1, &zwork);
    try testing.expectEqual(f32, @TypeOf(n));
    try testing.expectApproxEqAbs(@as(f32, 5), n, 1e-6);
}
