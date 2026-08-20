//! Symmetric and Hermitian eigenvalue problems.
//!
//! Every routine here returns **real** eigenvalues in ascending order, because
//! a symmetric (Hermitian) matrix has no others. That is why `w` is
//! `[]Real(T)` rather than `[]T`, and why there is no separate "imaginary
//! parts" array of the kind the nonsymmetric solvers need.
//!
//! ## `sy*` and `he*` are exposed as one name
//!
//! LAPACK names the real routines `ssyev`/`dsyev` and the complex ones
//! `cheev`/`zheev`. Here `syev` works for all four element types and resolves
//! to `zheev` for `Complex(f64)`, with `heev` as an alias.
//!
//! This is safe in a way the same trick would **not** be for the linear
//! solvers. `sysv` and `hesv` both exist for complex elements and solve
//! genuinely different problems (`A = A^T` against `A = A^H`), so `linear.zig`
//! keeps them apart and rejects `hesv(f64, ...)` at compile time. For
//! eigenvalues there is no complex-symmetric routine at all — a complex
//! symmetric matrix does not generally have real eigenvalues or an orthogonal
//! eigenbasis, so the problem is a different one that LAPACK does not solve
//! here. With only one interpretation available, unifying the names loses
//! nothing.
//!
//! ## Which driver
//!
//! | routine | method | when |
//! |---|---|---|
//! | `syev` | QR iteration | small, or you want the simplest thing |
//! | `syevd` | divide and conquer | all eigenvectors of a large matrix |
//! | `syevr` | MRRR | a *subset*, or the best general choice |
//!
//! `syevr` is the modern default: it is usually fastest, and it is the only one
//! that can compute a range of eigenvalues without computing all of them.
//!
//! Eigenvectors are determined only up to sign (up to phase, for complex), so
//! comparing them elementwise against a reference is not a valid test and none
//! of the tests below do it.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");

const Int = types.Int;
const Complex = types.Complex;
const Real = types.Real;
const Uplo = types.Uplo;
const Job = types.Job;
const Range = types.Range;
const Error = info_mod.Error;
const dim = types.dim;
const assertMatrix = types.assertMatrix;
const packedLen = types.packedLen;
const ref = work_mod.ref;
const out = work_mod.out;
const opt = types.opt;

const Allocator = std.mem.Allocator;
const Fail = Error || Allocator.Error;

fn sym(comptime T: type, comptime name: []const u8) @TypeOf(@field(c, [_]u8{types.prefix(T)} ++ name)) {
    return @field(c, [_]u8{types.prefix(T)} ++ name);
}

/// The symmetric spelling for real `T`, the Hermitian one for complex.
///
/// `herm(f64, "ev")` is `"syev"`; `herm(Complex(f64), "ev")` is `"heev"`.
fn herm(comptime T: type, comptime prefix_real: []const u8, comptime prefix_complex: []const u8, comptime suffix: []const u8) []const u8 {
    return switch (T) {
        f32, f64 => prefix_real ++ suffix,
        else => prefix_complex ++ suffix,
    };
}

fn complexScratch(comptime T: type) bool {
    return switch (T) {
        f32, f64 => false,
        else => true,
    };
}

/// Which eigenvalues to compute.
///
/// Replaces LAPACK's four loosely-coupled arguments (`range`, `vl`, `vu`, `il`,
/// `iu`), where the two that matter depend on the first and the other two are
/// ignored. Only `syevr` and the other expert drivers accept anything but
/// `.all`.
pub const Selection = union(enum) {
    /// Every eigenvalue.
    all,
    /// Those in the half-open interval `(low, high]`.
    interval: struct { low: f64, high: f64 },
    /// Those with 1-based indices `first` through `last`, counting from the
    /// smallest.
    indices: struct { first: usize, last: usize },

    fn tag(self: Selection) Range {
        return switch (self) {
            .all => .all,
            .interval => .interval,
            .indices => .indices,
        };
    }
};

/// How many eigenvalues a call produced, and where they went.
pub const EigResult = struct {
    /// Number of eigenvalues found. Equals `n` unless a `Selection` narrowed it.
    found: usize,
};

// ============================================================================
// Dense drivers
// ============================================================================

/// All eigenvalues (and optionally eigenvectors) of a symmetric/Hermitian
/// matrix, by QR iteration.
///
/// Reads only the `uplo` triangle. With `job = .vectors`, `a` is overwritten
/// with the orthonormal eigenvectors as columns, in the same order as `w`; with
/// `job = .values_only`, `a` is destroyed but holds nothing useful.
pub fn syev(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    w: []Real(T),
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(w.len >= n);

    const name = comptime herm(T, "sy", "he", "ev");
    const n_ = dim(n);
    const lda_ = dim(lda);
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), &probe, ref(&lda_), &rprobe, &wq, ref(&neg), &rprobe, out(&info));
    } else {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), &probe, ref(&lda_), &rprobe, &wq, ref(&neg), out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexScratch(T)) {
        // heev's rwork is fixed at max(1, 3n - 2) and is not part of the query.
        const rwork = try allocator.alloc(Real(T), @max(3 * n, 1));
        defer allocator.free(rwork);
        sym(T, name)(opt(job), opt(uplo), ref(&n_), a.ptr, ref(&lda_), w.ptr, buf.ptr, ref(&lwork), rwork.ptr, out(&info));
    } else {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), a.ptr, ref(&lda_), w.ptr, buf.ptr, ref(&lwork), out(&info));
    }
    return info_mod.checkConvergence(info);
}

/// LAPACK's name for `syev` on complex elements. Identical.
pub const heev = syev;

/// `syev` by divide and conquer.
///
/// Faster than `syev` when eigenvectors are wanted and `n` is large, at the
/// cost of a much bigger workspace. With `job = .values_only` it offers no
/// advantage.
pub fn syevd(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    w: []Real(T),
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(w.len >= n);

    const name = comptime herm(T, "sy", "he", "evd");
    const n_ = dim(n);
    const lda_ = dim(lda);
    var info: Int = 0;

    // Unlike syev, every workspace here is queryable - including the integer
    // one, whose size depends on whether eigenvectors were asked for.
    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    var rq: [1]Real(T) = undefined;
    var iq: [1]Int = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), &probe, ref(&lda_), &rprobe, &wq, ref(&neg), &rq, ref(&neg), &iq, ref(&neg), out(&info));
    } else {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), &probe, ref(&lda_), &rprobe, &wq, ref(&neg), &iq, ref(&neg), out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const iwork = try allocator.alloc(Int, @intCast(@max(iq[0], 1)));
    defer allocator.free(iwork);
    const lwork = dim(size);
    const liwork = dim(iwork.len);

    if (comptime complexScratch(T)) {
        const rsize: usize = @intCast(@max(work_mod.sizeFrom(Real(T), rq[0]), 1));
        const rwork = try allocator.alloc(Real(T), rsize);
        defer allocator.free(rwork);
        const lrwork = dim(rsize);
        sym(T, name)(opt(job), opt(uplo), ref(&n_), a.ptr, ref(&lda_), w.ptr, buf.ptr, ref(&lwork), rwork.ptr, ref(&lrwork), iwork.ptr, ref(&liwork), out(&info));
    } else {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), a.ptr, ref(&lda_), w.ptr, buf.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
    }
    return info_mod.checkConvergence(info);
}

/// LAPACK's name for `syevd` on complex elements.
pub const heevd = syevd;

/// Eigenvalues and eigenvectors by MRRR, optionally only a selected range.
///
/// The best general choice, and the only driver here that can compute a subset
/// without computing everything.
///
/// `z` receives the eigenvectors when `job = .vectors`; it needs `n` columns
/// even when a `Selection` will produce fewer, because LAPACK does not know how
/// many it will find until it has looked. `w` likewise needs `n` elements. The
/// returned `found` says how many of each were actually written.
///
/// `abstol` sets the convergence tolerance; pass 0 for the default, which is
/// what you want unless you have a specific reason.
pub fn syevr(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    selection: Selection,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    w: []Real(T),
    z: []T,
    ldz: usize,
    abstol: Real(T),
) Fail!EigResult {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(w.len >= n);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const name = comptime herm(T, "sy", "he", "evr");
    const n_ = dim(n);
    const lda_ = dim(lda);
    const ldz_ = dim(@max(ldz, 1));

    // Only two of these four are read, chosen by the range character - which is
    // exactly the coupling `Selection` exists to hide.
    var vl: Real(T) = 0;
    var vu: Real(T) = 0;
    var il: Int = 1;
    var iu: Int = @max(dim(n), 1);
    switch (selection) {
        .all => {},
        .interval => |iv| {
            std.debug.assert(iv.low < iv.high);
            vl = @floatCast(iv.low);
            vu = @floatCast(iv.high);
        },
        .indices => |ix| {
            std.debug.assert(ix.first >= 1 and ix.first <= ix.last and ix.last <= n);
            il = dim(ix.first);
            iu = dim(ix.last);
        },
    }
    const range = selection.tag();

    var found: Int = 0;
    var info: Int = 0;
    const isuppz = try allocator.alloc(Int, @max(2 * n, 1));
    defer allocator.free(isuppz);

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    var rq: [1]Real(T) = undefined;
    var iq: [1]Int = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, name)(opt(job), opt(range), opt(uplo), ref(&n_), &probe, ref(&lda_), ref(&vl), ref(&vu), ref(&il), ref(&iu), ref(&abstol), out(&found), &rprobe, &probe, ref(&ldz_), &iq, &wq, ref(&neg), &rq, ref(&neg), &iq, ref(&neg), out(&info));
    } else {
        sym(T, name)(opt(job), opt(range), opt(uplo), ref(&n_), &probe, ref(&lda_), ref(&vl), ref(&vu), ref(&il), ref(&iu), ref(&abstol), out(&found), &rprobe, &probe, ref(&ldz_), &iq, &wq, ref(&neg), &iq, ref(&neg), out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const iwork = try allocator.alloc(Int, @intCast(@max(iq[0], 1)));
    defer allocator.free(iwork);
    const lwork = dim(size);
    const liwork = dim(iwork.len);

    if (comptime complexScratch(T)) {
        const rsize: usize = @intCast(@max(work_mod.sizeFrom(Real(T), rq[0]), 1));
        const rwork = try allocator.alloc(Real(T), rsize);
        defer allocator.free(rwork);
        const lrwork = dim(rsize);
        sym(T, name)(opt(job), opt(range), opt(uplo), ref(&n_), a.ptr, ref(&lda_), ref(&vl), ref(&vu), ref(&il), ref(&iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), isuppz.ptr, buf.ptr, ref(&lwork), rwork.ptr, ref(&lrwork), iwork.ptr, ref(&liwork), out(&info));
    } else {
        sym(T, name)(opt(job), opt(range), opt(uplo), ref(&n_), a.ptr, ref(&lda_), ref(&vl), ref(&vu), ref(&il), ref(&iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), isuppz.ptr, buf.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
    }
    try info_mod.checkConvergence(info);
    return .{ .found = @intCast(found) };
}

/// LAPACK's name for `syevr` on complex elements.
pub const heevr = syevr;

// ============================================================================
// Packed and band storage
// ============================================================================

/// `syev` for a matrix in packed storage.
///
/// `ap` is destroyed. Eigenvectors, if asked for, go to `z` rather than back
/// into `ap` — there is no room for them in packed storage.
pub fn spev(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    uplo: Uplo,
    n: usize,
    ap: []T,
    w: []Real(T),
    z: []T,
    ldz: usize,
) Fail!void {
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(w.len >= n);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const name = comptime herm(T, "sp", "hp", "ev");
    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    // No query available: the workspace is a documented fixed size.
    const buf = try allocator.alloc(T, @max(3 * n, 1));
    defer allocator.free(buf);

    if (comptime complexScratch(T)) {
        const rwork = try allocator.alloc(Real(T), @max(3 * n, 1));
        defer allocator.free(rwork);
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ap.ptr, w.ptr, z.ptr, ref(&ldz_), buf.ptr, rwork.ptr, out(&info));
    } else {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ap.ptr, w.ptr, z.ptr, ref(&ldz_), buf.ptr, out(&info));
    }
    return info_mod.checkConvergence(info);
}

/// LAPACK's name for `spev` on complex elements.
pub const hpev = spev;

/// `syev` for a symmetric/Hermitian band matrix with `kd` off-diagonals.
pub fn sbev(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    uplo: Uplo,
    n: usize,
    kd: usize,
    ab: []T,
    ldab: usize,
    w: []Real(T),
    z: []T,
    ldz: usize,
) Fail!void {
    std.debug.assert(ldab >= kd + 1);
    assertMatrix(ab.len, kd + 1, n, ldab);
    std.debug.assert(w.len >= n);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const name = comptime herm(T, "sb", "hb", "ev");
    const n_ = dim(n);
    const kd_ = dim(kd);
    const ldab_ = dim(ldab);
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    const buf = try allocator.alloc(T, @max(3 * n, 1));
    defer allocator.free(buf);

    if (comptime complexScratch(T)) {
        const rwork = try allocator.alloc(Real(T), @max(3 * n, 1));
        defer allocator.free(rwork);
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), w.ptr, z.ptr, ref(&ldz_), buf.ptr, rwork.ptr, out(&info));
    } else {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), w.ptr, z.ptr, ref(&ldz_), buf.ptr, out(&info));
    }
    return info_mod.checkConvergence(info);
}

/// LAPACK's name for `sbev` on complex elements.
pub const hbev = sbev;

/// Eigenvalues of a real symmetric **tridiagonal** matrix.
///
/// Real precisions only. A Hermitian tridiagonal matrix has a real diagonal but
/// complex off-diagonals, and LAPACK handles that by reducing it to a real one
/// first (`hbev` on a `kd = 1` band), so there is no `ctev`.
pub fn stev(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    n: usize,
    d: []T,
    e: []T,
    z: []T,
    ldz: usize,
) Fail!void {
    switch (T) {
        f32, f64 => {},
        else => @compileError("stev is real-only; for " ++ @typeName(T) ++
            " reduce to a real tridiagonal first, or use hbev with kd = 1"),
    }
    std.debug.assert(d.len >= n);
    if (n > 1) std.debug.assert(e.len >= n - 1);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    const buf = try allocator.alloc(T, @max(2 * n, 1));
    defer allocator.free(buf);

    sym(T, "stev")(opt(job), ref(&n_), d.ptr, e.ptr, z.ptr, ref(&ldz_), buf.ptr, out(&info));
    return info_mod.checkConvergence(info);
}

// ============================================================================
// Generalized
// ============================================================================

/// Which generalized problem to solve.
pub const GeneralizedKind = enum(Int) {
    /// `A x = lambda B x`
    a_bx = 1,
    /// `A B x = lambda x`
    abx = 2,
    /// `B A x = lambda x`
    bax = 3,
};

/// Generalized symmetric-definite eigenproblem.
///
/// `B` must be positive definite — that is what makes the problem have real
/// eigenvalues and what the routine relies on. `b` is overwritten with its
/// Cholesky factor.
///
/// `info > 0` is overloaded here in a way worth knowing: values up to `n` mean
/// the eigenvalue iteration failed to converge, and values above `n` mean the
/// *Cholesky* factorization of `B` failed at minor `info - n` — i.e. `B` was
/// not positive definite. Both arrive as `error.NoConvergence`, so read
/// `lastInfo()` to tell them apart.
pub fn sygv(
    comptime T: type,
    allocator: Allocator,
    kind: GeneralizedKind,
    job: Job,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    w: []Real(T),
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, n, ldb);
    std.debug.assert(w.len >= n);

    const name = comptime herm(T, "sy", "he", "gv");
    const itype: Int = @intFromEnum(kind);
    const n_ = dim(n);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, name)(ref(&itype), opt(job), opt(uplo), ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), &rprobe, &wq, ref(&neg), &rprobe, out(&info));
    } else {
        sym(T, name)(ref(&itype), opt(job), opt(uplo), ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), &rprobe, &wq, ref(&neg), out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexScratch(T)) {
        const rwork = try allocator.alloc(Real(T), @max(3 * n, 1));
        defer allocator.free(rwork);
        sym(T, name)(ref(&itype), opt(job), opt(uplo), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), w.ptr, buf.ptr, ref(&lwork), rwork.ptr, out(&info));
    } else {
        sym(T, name)(ref(&itype), opt(job), opt(uplo), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), w.ptr, buf.ptr, ref(&lwork), out(&info));
    }
    return info_mod.checkConvergence(info);
}

/// LAPACK's name for `sygv` on complex elements.
pub const hegv = sygv;

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// `max_i || A v_i - lambda_i v_i ||_inf` over the columns of `z`.
///
/// The only correct way to check an eigendecomposition: eigenvectors are
/// determined up to sign for real matrices and up to phase for complex ones, so
/// comparing them elementwise against a reference proves nothing.
fn eigResidual(n: usize, a: []const f64, lda: usize, w: []const f64, z: []const f64, ldz: usize, count: usize) f64 {
    var worst: f64 = 0;
    for (0..count) |k| {
        for (0..n) |i| {
            var acc: f64 = 0;
            for (0..n) |j| acc += a[i + j * lda] * z[j + k * ldz];
            worst = @max(worst, @abs(acc - w[k] * z[i + k * ldz]));
        }
    }
    return worst;
}

test "syev returns ascending eigenvalues and orthonormal vectors" {
    // Column-major [[2, 1], [1, 2]], eigenvalues 1 and 3.
    const original = [_]f64{ 2, 1, 1, 2 };
    var a = original;
    var w: [2]f64 = undefined;

    try syev(f64, testing.allocator, .vectors, .upper, 2, &a, 2, &w);

    try testing.expectApproxEqAbs(@as(f64, 1), w[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 3), w[1], 1e-12);
    // Ascending order is guaranteed, which is worth relying on.
    try testing.expect(w[0] < w[1]);

    // A v = lambda v, rather than comparing v against a written-down vector.
    try testing.expect(eigResidual(2, &original, 2, &w, &a, 2, 2) < 1e-12);

    // Columns orthonormal.
    for (0..2) |i| {
        for (0..2) |j| {
            var acc: f64 = 0;
            for (0..2) |p| acc += a[p + i * 2] * a[p + j * 2];
            try testing.expectApproxEqAbs(@as(f64, if (i == j) 1 else 0), acc, 1e-12);
        }
    }
}

test "syev reads only the requested triangle" {
    // Poison the strict lower half; .upper must not touch it as input. (It is
    // overwritten as output, since the eigenvectors go into `a`.)
    var a = [_]f64{ 2, -999, 1, 2 };
    var w: [2]f64 = undefined;
    try syev(f64, testing.allocator, .values_only, .upper, 2, &a, 2, &w);

    // If the poison had been read, the eigenvalues would not be 1 and 3.
    try testing.expectApproxEqAbs(@as(f64, 1), w[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 3), w[1], 1e-12);
}

test "heev solves the Hermitian problem through the same name" {
    // A = [[2, i], [-i, 2]] is Hermitian with eigenvalues 1 and 3.
    const Z = Complex(f64);
    var a = [_]Z{ Z.init(2, 0), Z.init(0, -1), Z.init(0, 0), Z.init(2, 0) };
    var w: [2]f64 = undefined;

    // Note `w` is []f64, not []Complex(f64) - a Hermitian matrix has real
    // eigenvalues, and the signature says so.
    try heev(Z, testing.allocator, .vectors, .lower, 2, &a, 2, &w);

    try testing.expectApproxEqAbs(@as(f64, 1), w[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 3), w[1], 1e-12);
    // A Hermitian matrix has real eigenvalues, so `w` is f64 even though the
    // matrix is Complex(f64). A binding using []T for both would not compile.
    try testing.expectEqual(f64, @TypeOf(w[0]));
}

test "syevd agrees with syev" {
    const original = [_]f64{ 4, 1, 2, 1, 5, 3, 2, 3, 6 };

    var a1 = original;
    var w1: [3]f64 = undefined;
    try syev(f64, testing.allocator, .vectors, .upper, 3, &a1, 3, &w1);

    var a2 = original;
    var w2: [3]f64 = undefined;
    try syevd(f64, testing.allocator, .vectors, .upper, 3, &a2, 3, &w2);

    for (w1, w2) |x, y| try testing.expectApproxEqAbs(x, y, 1e-10);
    try testing.expect(eigResidual(3, &original, 3, &w2, &a2, 3, 3) < 1e-10);
}

test "syevr computes every eigenvalue when asked for all" {
    const original = [_]f64{ 4, 1, 2, 1, 5, 3, 2, 3, 6 };
    var a = original;
    var w: [3]f64 = undefined;
    var z: [9]f64 = undefined;

    const r = try syevr(f64, testing.allocator, .vectors, .all, .upper, 3, &a, 3, &w, &z, 3, 0);

    try testing.expectEqual(@as(usize, 3), r.found);
    try testing.expect(eigResidual(3, &original, 3, &w, &z, 3, 3) < 1e-10);
}

test "syevr computes only the requested index range" {
    // diag(1, 2, 3, 4, 5): asking for indices 2..3 must give exactly 2 and 3.
    const n = 5;
    var a = [_]f64{0} ** (n * n);
    for (0..n) |i| a[i + i * n] = @floatFromInt(i + 1);
    var w: [n]f64 = undefined;
    var z: [n * n]f64 = undefined;

    const r = try syevr(
        f64,
        testing.allocator,
        .vectors,
        .{ .indices = .{ .first = 2, .last = 3 } },
        .upper,
        n,
        &a,
        n,
        &w,
        &z,
        n,
        0,
    );

    try testing.expectEqual(@as(usize, 2), r.found);
    try testing.expectApproxEqAbs(@as(f64, 2), w[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 3), w[1], 1e-12);
}

test "syevr computes only the requested value interval" {
    const n = 5;
    var a = [_]f64{0} ** (n * n);
    for (0..n) |i| a[i + i * n] = @floatFromInt(i + 1);
    var w: [n]f64 = undefined;
    var z: [n * n]f64 = undefined;

    // (2.5, 4.5] contains 3 and 4. The interval is half-open at the low end,
    // which is why 2.5 rather than 3 is the right lower bound to ask with.
    const r = try syevr(
        f64,
        testing.allocator,
        .vectors,
        .{ .interval = .{ .low = 2.5, .high = 4.5 } },
        .upper,
        n,
        &a,
        n,
        &w,
        &z,
        n,
        0,
    );

    try testing.expectEqual(@as(usize, 2), r.found);
    try testing.expectApproxEqAbs(@as(f64, 3), w[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 4), w[1], 1e-12);
}

test "heevr handles a complex subset request" {
    const Z = Complex(f64);
    var a = [_]Z{ Z.init(2, 0), Z.init(0, -1), Z.init(0, 0), Z.init(2, 0) };
    var w: [2]f64 = undefined;
    var z: [4]Z = undefined;

    const r = try heevr(
        Z,
        testing.allocator,
        .vectors,
        .{ .indices = .{ .first = 1, .last = 1 } },
        .lower,
        2,
        &a,
        2,
        &w,
        &z,
        2,
        0,
    );

    try testing.expectEqual(@as(usize, 1), r.found);
    try testing.expectApproxEqAbs(@as(f64, 1), w[0], 1e-12);
}

test "spev matches syev on the same matrix" {
    // Upper packed [[2, 1], [1, 2]] is a11, a12, a22.
    var ap = [_]f64{ 2, 1, 2 };
    var w: [2]f64 = undefined;
    var z: [4]f64 = undefined;
    try spev(f64, testing.allocator, .vectors, .upper, 2, &ap, &w, &z, 2);

    try testing.expectApproxEqAbs(@as(f64, 1), w[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 3), w[1], 1e-12);

    const full = [_]f64{ 2, 1, 1, 2 };
    try testing.expect(eigResidual(2, &full, 2, &w, &z, 2, 2) < 1e-12);
}

test "sbev solves the band problem" {
    // Tridiagonal [[2, 1, 0], [1, 2, 1], [0, 1, 2]], kd = 1, upper band.
    var ab = [_]f64{ 0, 2, 1, 2, 1, 2 };
    var w: [3]f64 = undefined;
    var z: [9]f64 = undefined;

    try sbev(f64, testing.allocator, .vectors, .upper, 3, 1, &ab, 2, &w, &z, 3);

    // Eigenvalues are 2 - sqrt(2), 2, 2 + sqrt(2).
    try testing.expectApproxEqAbs(2 - @sqrt(@as(f64, 2)), w[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2), w[1], 1e-12);
    try testing.expectApproxEqAbs(2 + @sqrt(@as(f64, 2)), w[2], 1e-12);
}

test "stev solves the tridiagonal problem directly" {
    var d = [_]f64{ 2, 2, 2 };
    var e = [_]f64{ 1, 1 };
    var z: [9]f64 = undefined;

    try stev(f64, testing.allocator, .vectors, 3, &d, &e, &z, 3);

    // d is overwritten with the eigenvalues.
    try testing.expectApproxEqAbs(2 - @sqrt(@as(f64, 2)), d[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2), d[1], 1e-12);
    try testing.expectApproxEqAbs(2 + @sqrt(@as(f64, 2)), d[2], 1e-12);
}

test "sygv solves the generalized problem" {
    // A x = lambda B x with A = [[2, 1], [1, 2]] and B = I gives the ordinary
    // eigenvalues 1 and 3; with B = 2I it halves them.
    var a = [_]f64{ 2, 1, 1, 2 };
    var b = [_]f64{ 2, 0, 0, 2 };
    var w: [2]f64 = undefined;

    try sygv(f64, testing.allocator, .a_bx, .vectors, .upper, 2, &a, 2, &b, 2, &w);

    try testing.expectApproxEqAbs(@as(f64, 0.5), w[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1.5), w[1], 1e-12);
}

test "sygv distinguishes its three problem types" {
    const a0 = [_]f64{ 2, 1, 1, 2 };
    const b0 = [_]f64{ 2, 0, 0, 2 };

    var results: [3][2]f64 = undefined;
    for ([_]GeneralizedKind{ .a_bx, .abx, .bax }, 0..) |kind, i| {
        var a = a0;
        var b = b0;
        try sygv(f64, testing.allocator, kind, .values_only, .upper, 2, &a, 2, &b, 2, &results[i]);
    }

    // A x = lambda B x -> lambda / 2; A B x = lambda x -> 2 lambda. The third
    // (B A x) has the same spectrum as the second here because B is a multiple
    // of the identity.
    try testing.expectApproxEqAbs(@as(f64, 0.5), results[0][0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2), results[1][0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2), results[2][0], 1e-12);
}

test "sygv reports a non-positive-definite B distinguishably" {
    // B is indefinite, so the Cholesky step fails. LAPACK signals that with
    // info > n rather than with a different error, so lastInfo() is the only
    // way to tell it from a convergence failure.
    const n = 2;
    var a = [_]f64{ 2, 1, 1, 2 };
    var b = [_]f64{ 1, 2, 2, 1 };
    var w: [2]f64 = undefined;

    try testing.expectError(
        error.NoConvergence,
        sygv(f64, testing.allocator, .a_bx, .values_only, .upper, n, &a, n, &b, n, &w),
    );
    try testing.expect(info_mod.lastInfo() > n);
}

test "single precision works through the same wrappers" {
    var a = [_]f32{ 2, 1, 1, 2 };
    var w: [2]f32 = undefined;
    try syev(f32, testing.allocator, .values_only, .upper, 2, &a, 2, &w);
    try testing.expectApproxEqAbs(@as(f32, 1), w[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 3), w[1], 1e-5);
}
