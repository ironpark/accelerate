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
    return finishGeneralized(info, n);
}

/// LAPACK's name for `sygv` on complex elements.
pub const hegv = sygv;

// ============================================================================
// Expert and divide-and-conquer variants
// ============================================================================

/// The four loosely-coupled arguments a `Selection` stands in for, unpacked.
const Window = struct {
    range: Range,
    vl: f64,
    vu: f64,
    il: Int,
    iu: Int,

    fn from(selection: Selection, n: usize) Window {
        var w: Window = .{ .range = .all, .vl = 0, .vu = 0, .il = 1, .iu = @max(dim(n), 1) };
        switch (selection) {
            .all => {},
            .interval => |iv| {
                std.debug.assert(iv.low < iv.high);
                w.range = .interval;
                w.vl = iv.low;
                w.vu = iv.high;
            },
            .indices => |ix| {
                std.debug.assert(ix.first >= 1 and ix.first <= ix.last and ix.last <= n);
                w.range = .indices;
                w.il = dim(ix.first);
                w.iu = dim(ix.last);
            },
        }
        return w;
    }
};

/// A subset of the eigenvalues of a dense symmetric matrix, by bisection and
/// inverse iteration.
///
/// The older expert driver; `syevr` computes the same thing by MRRR and is
/// usually both faster and more accurate. The reason to reach for this one is
/// `ifail`: when a vector does not converge, this reports *which*, where
/// `syevr` reports only that something went wrong.
///
/// `ifail` needs `n` entries and receives the 1-based indices of the vectors
/// that failed. `error.NoConvergence` means at least one did; `lastInfo()` is
/// the count.
///
/// `abstol` is the absolute tolerance on each eigenvalue; pass `0` for the
/// default, or `2 * util.lamch(T, .safe_min)` for the most accurate answer
/// bisection can give.
pub fn syevx(
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
    ifail: []Int,
) Fail!EigResult {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(w.len >= n);
    std.debug.assert(ifail.len >= n);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const name = comptime herm(T, "sy", "he", "evx");
    const win = Window.from(selection, n);
    const n_ = dim(n);
    const lda_ = dim(lda);
    const ldz_ = dim(@max(ldz, 1));
    const vl: Real(T) = @floatCast(win.vl);
    const vu: Real(T) = @floatCast(win.vu);
    var found: Int = 0;
    var info: Int = 0;

    const iwork = try allocator.alloc(Int, @max(5 * n, 1));
    defer allocator.free(iwork);

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, name)(opt(job), opt(win.range), opt(uplo), ref(&n_), &probe, ref(&lda_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), &rprobe, &probe, ref(&ldz_), &wq, ref(&neg), &rprobe, iwork.ptr, ifail.ptr, out(&info));
    } else {
        sym(T, name)(opt(job), opt(win.range), opt(uplo), ref(&n_), &probe, ref(&lda_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), &rprobe, &probe, ref(&ldz_), &wq, ref(&neg), iwork.ptr, ifail.ptr, out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexScratch(T)) {
        const rwork = try allocator.alloc(Real(T), @max(7 * n, 1));
        defer allocator.free(rwork);
        sym(T, name)(opt(job), opt(win.range), opt(uplo), ref(&n_), a.ptr, ref(&lda_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), rwork.ptr, iwork.ptr, ifail.ptr, out(&info));
    } else {
        sym(T, name)(opt(job), opt(win.range), opt(uplo), ref(&n_), a.ptr, ref(&lda_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), iwork.ptr, ifail.ptr, out(&info));
    }
    try info_mod.checkConvergence(info);
    return .{ .found = @intCast(found) };
}

/// `syevx` under its complex name.
pub const heevx = syevx;

/// `spev` by divide and conquer.
pub fn spevd(
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

    const name = comptime herm(T, "sp", "hp", "evd");
    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    var rq: [1]Real(T) = undefined;
    var iq: [1]Int = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ap.ptr, w.ptr, z.ptr, ref(&ldz_), &wq, ref(&neg), &rq, ref(&neg), &iq, ref(&neg), out(&info));
    } else {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ap.ptr, w.ptr, z.ptr, ref(&ldz_), &wq, ref(&neg), &iq, ref(&neg), out(&info));
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
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ap.ptr, w.ptr, z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), rwork.ptr, ref(&lrwork), iwork.ptr, ref(&liwork), out(&info));
    } else {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ap.ptr, w.ptr, z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
    }
    return info_mod.checkConvergence(info);
}

/// `spevd` under its complex name.
pub const hpevd = spevd;

/// `spev` restricted to a subset of the spectrum. See `syevx` for `abstol` and
/// `ifail`.
pub fn spevx(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    selection: Selection,
    uplo: Uplo,
    n: usize,
    ap: []T,
    w: []Real(T),
    z: []T,
    ldz: usize,
    abstol: Real(T),
    ifail: []Int,
) Fail!EigResult {
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(w.len >= n);
    std.debug.assert(ifail.len >= n);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const name = comptime herm(T, "sp", "hp", "evx");
    const win = Window.from(selection, n);
    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    const vl: Real(T) = @floatCast(win.vl);
    const vu: Real(T) = @floatCast(win.vu);
    var found: Int = 0;
    var info: Int = 0;

    const iwork = try allocator.alloc(Int, @max(5 * n, 1));
    defer allocator.free(iwork);

    // Fixed sizes, no query: 8n reals, or 2n complex plus 7n reals.
    const buf = try allocator.alloc(T, @max(if (comptime complexScratch(T)) 2 * n else 8 * n, 1));
    defer allocator.free(buf);

    if (comptime complexScratch(T)) {
        const rwork = try allocator.alloc(Real(T), @max(7 * n, 1));
        defer allocator.free(rwork);
        sym(T, name)(opt(job), opt(win.range), opt(uplo), ref(&n_), ap.ptr, ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), buf.ptr, rwork.ptr, iwork.ptr, ifail.ptr, out(&info));
    } else {
        sym(T, name)(opt(job), opt(win.range), opt(uplo), ref(&n_), ap.ptr, ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), buf.ptr, iwork.ptr, ifail.ptr, out(&info));
    }
    try info_mod.checkConvergence(info);
    return .{ .found = @intCast(found) };
}

/// `spevx` under its complex name.
pub const hpevx = spevx;

/// `sbev` by divide and conquer.
pub fn sbevd(
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
    std.debug.assert(w.len >= n);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const name = comptime herm(T, "sb", "hb", "evd");
    const n_ = dim(n);
    const kd_ = dim(kd);
    const ldab_ = dim(ldab);
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    var rq: [1]Real(T) = undefined;
    var iq: [1]Int = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), w.ptr, z.ptr, ref(&ldz_), &wq, ref(&neg), &rq, ref(&neg), &iq, ref(&neg), out(&info));
    } else {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), w.ptr, z.ptr, ref(&ldz_), &wq, ref(&neg), &iq, ref(&neg), out(&info));
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
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), w.ptr, z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), rwork.ptr, ref(&lrwork), iwork.ptr, ref(&liwork), out(&info));
    } else {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), w.ptr, z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
    }
    return info_mod.checkConvergence(info);
}

/// `sbevd` under its complex name.
pub const hbevd = sbevd;

/// `sbev` restricted to a subset of the spectrum.
///
/// The extra `q`/`ldq` array is where the band-to-tridiagonal reduction's
/// orthogonal factor goes. It is only referenced when `job = .vectors`, and it
/// is an output — this routine has no way to reuse one you already have, unlike
/// `sbgv`.
pub fn sbevx(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    selection: Selection,
    uplo: Uplo,
    n: usize,
    kd: usize,
    ab: []T,
    ldab: usize,
    q: []T,
    ldq: usize,
    w: []Real(T),
    z: []T,
    ldz: usize,
    abstol: Real(T),
    ifail: []Int,
) Fail!EigResult {
    std.debug.assert(ldab >= kd + 1);
    std.debug.assert(w.len >= n);
    std.debug.assert(ifail.len >= n);
    std.debug.assert(ldq >= 1);
    if (job == .vectors) {
        assertMatrix(q.len, n, n, ldq);
        assertMatrix(z.len, n, n, ldz);
    }

    const name = comptime herm(T, "sb", "hb", "evx");
    const win = Window.from(selection, n);
    const n_ = dim(n);
    const kd_ = dim(kd);
    const ldab_ = dim(ldab);
    const ldq_ = dim(ldq);
    const ldz_ = dim(@max(ldz, 1));
    const vl: Real(T) = @floatCast(win.vl);
    const vu: Real(T) = @floatCast(win.vu);
    var found: Int = 0;
    var info: Int = 0;

    const iwork = try allocator.alloc(Int, @max(5 * n, 1));
    defer allocator.free(iwork);
    const buf = try allocator.alloc(T, @max(if (comptime complexScratch(T)) n else 7 * n, 1));
    defer allocator.free(buf);

    if (comptime complexScratch(T)) {
        const rwork = try allocator.alloc(Real(T), @max(7 * n, 1));
        defer allocator.free(rwork);
        sym(T, name)(opt(job), opt(win.range), opt(uplo), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), q.ptr, ref(&ldq_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), buf.ptr, rwork.ptr, iwork.ptr, ifail.ptr, out(&info));
    } else {
        sym(T, name)(opt(job), opt(win.range), opt(uplo), ref(&n_), ref(&kd_), ab.ptr, ref(&ldab_), q.ptr, ref(&ldq_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), buf.ptr, iwork.ptr, ifail.ptr, out(&info));
    }
    try info_mod.checkConvergence(info);
    return .{ .found = @intCast(found) };
}

/// `sbevx` under its complex name.
pub const hbevx = sbevx;

/// `stev` by divide and conquer. Real only, like `stev`.
pub fn stevd(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    n: usize,
    d: []T,
    e: []T,
    z: []T,
    ldz: usize,
) Fail!void {
    requireRealTridiagonal(T, "stevd");
    std.debug.assert(d.len >= n);
    if (n > 1) std.debug.assert(e.len >= n - 1);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    var iq: [1]Int = undefined;
    const neg = work_mod.query;
    sym(T, "stevd")(opt(job), ref(&n_), d.ptr, e.ptr, z.ptr, ref(&ldz_), &wq, ref(&neg), &iq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const iwork = try allocator.alloc(Int, @intCast(@max(iq[0], 1)));
    defer allocator.free(iwork);
    const lwork = dim(size);
    const liwork = dim(iwork.len);

    sym(T, "stevd")(opt(job), ref(&n_), d.ptr, e.ptr, z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
    return info_mod.checkConvergence(info);
}

/// `stev` restricted to a subset of the spectrum, by bisection and inverse
/// iteration. Real only.
pub fn stevx(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    selection: Selection,
    n: usize,
    d: []T,
    e: []T,
    w: []T,
    z: []T,
    ldz: usize,
    abstol: T,
    ifail: []Int,
) Fail!EigResult {
    requireRealTridiagonal(T, "stevx");
    std.debug.assert(d.len >= n);
    if (n > 1) std.debug.assert(e.len >= n - 1);
    std.debug.assert(w.len >= n and ifail.len >= n);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const win = Window.from(selection, n);
    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    const vl: T = @floatCast(win.vl);
    const vu: T = @floatCast(win.vu);
    var found: Int = 0;
    var info: Int = 0;

    const buf = try allocator.alloc(T, @max(5 * n, 1));
    defer allocator.free(buf);
    const iwork = try allocator.alloc(Int, @max(5 * n, 1));
    defer allocator.free(iwork);

    sym(T, "stevx")(opt(job), opt(win.range), ref(&n_), d.ptr, e.ptr, ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), buf.ptr, iwork.ptr, ifail.ptr, out(&info));
    try info_mod.checkConvergence(info);
    return .{ .found = @intCast(found) };
}

/// `stev` restricted to a subset of the spectrum, by MRRR. Real only.
///
/// The tridiagonal counterpart of `syevr`, and the best default when a subset
/// is wanted: it needs no reorthogonalization, where `stevx` degrades on a
/// tight cluster. `isuppz` receives two indices per vector bounding its nonzero
/// rows and needs `2 * max(1, n)` entries.
pub fn stevr(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    selection: Selection,
    n: usize,
    d: []T,
    e: []T,
    w: []T,
    z: []T,
    ldz: usize,
    isuppz: []Int,
    abstol: T,
) Fail!EigResult {
    requireRealTridiagonal(T, "stevr");
    std.debug.assert(d.len >= n);
    if (n > 1) std.debug.assert(e.len >= n - 1);
    std.debug.assert(w.len >= n);
    if (job == .vectors) std.debug.assert(isuppz.len >= 2 * @max(n, 1));

    const win = Window.from(selection, n);
    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    const vl: T = @floatCast(win.vl);
    const vu: T = @floatCast(win.vu);
    var found: Int = 0;
    var info: Int = 0;

    var wq: [1]T = undefined;
    var iq: [1]Int = undefined;
    const neg = work_mod.query;
    sym(T, "stevr")(opt(job), opt(win.range), ref(&n_), d.ptr, e.ptr, ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), isuppz.ptr, &wq, ref(&neg), &iq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const iwork = try allocator.alloc(Int, @intCast(@max(iq[0], 1)));
    defer allocator.free(iwork);
    const lwork = dim(size);
    const liwork = dim(iwork.len);

    sym(T, "stevr")(opt(job), opt(win.range), ref(&n_), d.ptr, e.ptr, ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), isuppz.ptr, buf.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
    try info_mod.checkConvergence(info);
    return .{ .found = @intCast(found) };
}

fn requireRealTridiagonal(comptime T: type, comptime routine: []const u8) void {
    switch (T) {
        f32, f64 => {},
        else => @compileError(routine ++ " is real-only; for " ++ @typeName(T) ++
            " reduce to a real tridiagonal first, or use the hb* band routines with kd = 1"),
    }
}

// ============================================================================
// Generalized problems: reduction, and the remaining drivers
// ============================================================================

/// `info` for the generalized drivers is bimodal, and the split is at `n`.
///
/// At or below `n` the QR/DC iteration failed to converge. Above it, the
/// Cholesky of `B` failed — `B` is not positive definite, so the problem was
/// never well posed — and `lastInfo() - n` is the leading minor that failed.
/// The raw value is what `lastInfo()` carries, so both readings stay available.
fn finishGeneralized(info: Int, n: usize) Error!void {
    if (info > @as(Int, @intCast(n))) return info_mod.checkCholesky(info);
    return info_mod.checkConvergence(info);
}

/// Reduces `A x = lambda B x` (or the `abx`/`bax` forms) to a standard
/// symmetric eigenproblem, given a Cholesky factor of `B`.
///
/// `b` must be `factor.potrf`'s output, not `B` itself. `a` is overwritten with
/// the reduced matrix, whose eigenvalues are the generalized ones; the
/// eigenvectors are *not* the generalized ones and have to be back-transformed
/// with a triangular solve against the same factor.
///
/// This is what `sygv` does internally. Call it directly to reduce once and
/// then run several different queries — `syevr` for a subset, then `syevd` for
/// everything — against the same reduced matrix.
pub fn sygst(
    comptime T: type,
    kind: GeneralizedKind,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    b: []const T,
    ldb: usize,
) Error!void {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, n, ldb);

    const itype: Int = @intFromEnum(kind);
    const n_ = dim(n);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    sym(T, comptime herm(T, "sy", "he", "gst"))(ref(&itype), opt(uplo), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), out(&info));
    return info_mod.checkArgs(info);
}

/// `sygst` under its complex name.
pub const hegst = sygst;

/// `sygst` in packed storage. `bp` is `factor.pptrf`'s output.
pub fn spgst(
    comptime T: type,
    kind: GeneralizedKind,
    uplo: Uplo,
    n: usize,
    ap: []T,
    bp: []const T,
) Error!void {
    std.debug.assert(ap.len >= packedLen(n) and bp.len >= packedLen(n));

    const itype: Int = @intFromEnum(kind);
    const n_ = dim(n);
    var info: Int = 0;

    sym(T, comptime herm(T, "sp", "hp", "gst"))(ref(&itype), opt(uplo), ref(&n_), ap.ptr, bp.ptr, out(&info));
    return info_mod.checkArgs(info);
}

/// `spgst` under its complex name.
pub const hpgst = spgst;

/// Reduces a banded `A x = lambda B x` to a standard banded eigenproblem.
///
/// The band analogue of `sygst`, but it does not use a Cholesky factor: `bb`
/// must be `factor.pbstf`'s split factor instead, and the transformation is a
/// sequence of rotations rather than a triangular solve. `x` receives the
/// transformation when `vect = .vectors`, and it is `n x n` — the only dense
/// array in a routine that is otherwise all band storage.
///
/// Unlike `sygst` there is no `kind`: the band routines solve only
/// `A x = lambda B x`.
pub fn sbgst(
    comptime T: type,
    allocator: Allocator,
    vect: Job,
    uplo: Uplo,
    n: usize,
    ka: usize,
    kb: usize,
    ab: []T,
    ldab: usize,
    bb: []const T,
    ldbb: usize,
    x: []T,
    ldx: usize,
) Fail!void {
    std.debug.assert(ldab >= ka + 1 and ldbb >= kb + 1);
    std.debug.assert(ldx >= 1);
    if (vect == .vectors) assertMatrix(x.len, n, n, ldx);

    const name = comptime herm(T, "sb", "hb", "gst");
    const n_ = dim(n);
    const ka_ = dim(ka);
    const kb_ = dim(kb);
    const ldab_ = dim(ldab);
    const ldbb_ = dim(ldbb);
    const ldx_ = dim(ldx);
    var info: Int = 0;

    if (comptime complexScratch(T)) {
        const buf = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(buf);
        const rwork = try allocator.alloc(Real(T), @max(n, 1));
        defer allocator.free(rwork);
        sym(T, name)(opt(vect), opt(uplo), ref(&n_), ref(&ka_), ref(&kb_), ab.ptr, ref(&ldab_), bb.ptr, ref(&ldbb_), x.ptr, ref(&ldx_), buf.ptr, rwork.ptr, out(&info));
    } else {
        const buf = try allocator.alloc(T, @max(2 * n, 1));
        defer allocator.free(buf);
        sym(T, name)(opt(vect), opt(uplo), ref(&n_), ref(&ka_), ref(&kb_), ab.ptr, ref(&ldab_), bb.ptr, ref(&ldbb_), x.ptr, ref(&ldx_), buf.ptr, out(&info));
    }
    return info_mod.checkArgs(info);
}

/// `sbgst` under its complex name.
pub const hbgst = sbgst;

/// `sygv` by divide and conquer.
pub fn sygvd(
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

    const name = comptime herm(T, "sy", "he", "gvd");
    const itype: Int = @intFromEnum(kind);
    const n_ = dim(n);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    var rq: [1]Real(T) = undefined;
    var iq: [1]Int = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, name)(ref(&itype), opt(job), opt(uplo), ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), &rprobe, &wq, ref(&neg), &rq, ref(&neg), &iq, ref(&neg), out(&info));
    } else {
        sym(T, name)(ref(&itype), opt(job), opt(uplo), ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), &rprobe, &wq, ref(&neg), &iq, ref(&neg), out(&info));
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
        sym(T, name)(ref(&itype), opt(job), opt(uplo), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), w.ptr, buf.ptr, ref(&lwork), rwork.ptr, ref(&lrwork), iwork.ptr, ref(&liwork), out(&info));
    } else {
        sym(T, name)(ref(&itype), opt(job), opt(uplo), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), w.ptr, buf.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
    }
    return finishGeneralized(info, n);
}

/// `sygvd` under its complex name.
pub const hegvd = sygvd;

/// `sygv` restricted to a subset of the spectrum. See `syevx` for `abstol` and
/// `ifail`.
pub fn sygvx(
    comptime T: type,
    allocator: Allocator,
    kind: GeneralizedKind,
    job: Job,
    selection: Selection,
    uplo: Uplo,
    n: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    w: []Real(T),
    z: []T,
    ldz: usize,
    abstol: Real(T),
    ifail: []Int,
) Fail!EigResult {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, n, ldb);
    std.debug.assert(w.len >= n and ifail.len >= n);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const name = comptime herm(T, "sy", "he", "gvx");
    const itype: Int = @intFromEnum(kind);
    const win = Window.from(selection, n);
    const n_ = dim(n);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    const ldz_ = dim(@max(ldz, 1));
    const vl: Real(T) = @floatCast(win.vl);
    const vu: Real(T) = @floatCast(win.vu);
    var found: Int = 0;
    var info: Int = 0;

    const iwork = try allocator.alloc(Int, @max(5 * n, 1));
    defer allocator.free(iwork);

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, name)(ref(&itype), opt(job), opt(win.range), opt(uplo), ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), &rprobe, &probe, ref(&ldz_), &wq, ref(&neg), &rprobe, iwork.ptr, ifail.ptr, out(&info));
    } else {
        sym(T, name)(ref(&itype), opt(job), opt(win.range), opt(uplo), ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), &rprobe, &probe, ref(&ldz_), &wq, ref(&neg), iwork.ptr, ifail.ptr, out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexScratch(T)) {
        const rwork = try allocator.alloc(Real(T), @max(7 * n, 1));
        defer allocator.free(rwork);
        sym(T, name)(ref(&itype), opt(job), opt(win.range), opt(uplo), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), rwork.ptr, iwork.ptr, ifail.ptr, out(&info));
    } else {
        sym(T, name)(ref(&itype), opt(job), opt(win.range), opt(uplo), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), iwork.ptr, ifail.ptr, out(&info));
    }
    try finishGeneralized(info, n);
    return .{ .found = @intCast(found) };
}

/// `sygvx` under its complex name.
pub const hegvx = sygvx;

/// `sygv` in packed storage. `ap` and `bp` are both destroyed.
pub fn spgv(
    comptime T: type,
    allocator: Allocator,
    kind: GeneralizedKind,
    job: Job,
    uplo: Uplo,
    n: usize,
    ap: []T,
    bp: []T,
    w: []Real(T),
    z: []T,
    ldz: usize,
) Fail!void {
    std.debug.assert(ap.len >= packedLen(n) and bp.len >= packedLen(n));
    std.debug.assert(w.len >= n);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const name = comptime herm(T, "sp", "hp", "gv");
    const itype: Int = @intFromEnum(kind);
    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    const buf = try allocator.alloc(T, @max(if (comptime complexScratch(T)) 2 * n else 3 * n, 1));
    defer allocator.free(buf);

    if (comptime complexScratch(T)) {
        const rwork = try allocator.alloc(Real(T), @max(3 * n, 1));
        defer allocator.free(rwork);
        sym(T, name)(ref(&itype), opt(job), opt(uplo), ref(&n_), ap.ptr, bp.ptr, w.ptr, z.ptr, ref(&ldz_), buf.ptr, rwork.ptr, out(&info));
    } else {
        sym(T, name)(ref(&itype), opt(job), opt(uplo), ref(&n_), ap.ptr, bp.ptr, w.ptr, z.ptr, ref(&ldz_), buf.ptr, out(&info));
    }
    return finishGeneralized(info, n);
}

/// `spgv` under its complex name.
pub const hpgv = spgv;

/// `spgv` by divide and conquer.
pub fn spgvd(
    comptime T: type,
    allocator: Allocator,
    kind: GeneralizedKind,
    job: Job,
    uplo: Uplo,
    n: usize,
    ap: []T,
    bp: []T,
    w: []Real(T),
    z: []T,
    ldz: usize,
) Fail!void {
    std.debug.assert(ap.len >= packedLen(n) and bp.len >= packedLen(n));
    std.debug.assert(w.len >= n);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const name = comptime herm(T, "sp", "hp", "gvd");
    const itype: Int = @intFromEnum(kind);
    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    var rq: [1]Real(T) = undefined;
    var iq: [1]Int = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, name)(ref(&itype), opt(job), opt(uplo), ref(&n_), ap.ptr, bp.ptr, w.ptr, z.ptr, ref(&ldz_), &wq, ref(&neg), &rq, ref(&neg), &iq, ref(&neg), out(&info));
    } else {
        sym(T, name)(ref(&itype), opt(job), opt(uplo), ref(&n_), ap.ptr, bp.ptr, w.ptr, z.ptr, ref(&ldz_), &wq, ref(&neg), &iq, ref(&neg), out(&info));
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
        sym(T, name)(ref(&itype), opt(job), opt(uplo), ref(&n_), ap.ptr, bp.ptr, w.ptr, z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), rwork.ptr, ref(&lrwork), iwork.ptr, ref(&liwork), out(&info));
    } else {
        sym(T, name)(ref(&itype), opt(job), opt(uplo), ref(&n_), ap.ptr, bp.ptr, w.ptr, z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
    }
    return finishGeneralized(info, n);
}

/// `spgvd` under its complex name.
pub const hpgvd = spgvd;

/// `spgv` restricted to a subset of the spectrum.
pub fn spgvx(
    comptime T: type,
    allocator: Allocator,
    kind: GeneralizedKind,
    job: Job,
    selection: Selection,
    uplo: Uplo,
    n: usize,
    ap: []T,
    bp: []T,
    w: []Real(T),
    z: []T,
    ldz: usize,
    abstol: Real(T),
    ifail: []Int,
) Fail!EigResult {
    std.debug.assert(ap.len >= packedLen(n) and bp.len >= packedLen(n));
    std.debug.assert(w.len >= n and ifail.len >= n);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const name = comptime herm(T, "sp", "hp", "gvx");
    const itype: Int = @intFromEnum(kind);
    const win = Window.from(selection, n);
    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    const vl: Real(T) = @floatCast(win.vl);
    const vu: Real(T) = @floatCast(win.vu);
    var found: Int = 0;
    var info: Int = 0;

    const iwork = try allocator.alloc(Int, @max(5 * n, 1));
    defer allocator.free(iwork);
    const buf = try allocator.alloc(T, @max(if (comptime complexScratch(T)) 2 * n else 8 * n, 1));
    defer allocator.free(buf);

    if (comptime complexScratch(T)) {
        const rwork = try allocator.alloc(Real(T), @max(7 * n, 1));
        defer allocator.free(rwork);
        sym(T, name)(ref(&itype), opt(job), opt(win.range), opt(uplo), ref(&n_), ap.ptr, bp.ptr, ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), buf.ptr, rwork.ptr, iwork.ptr, ifail.ptr, out(&info));
    } else {
        sym(T, name)(ref(&itype), opt(job), opt(win.range), opt(uplo), ref(&n_), ap.ptr, bp.ptr, ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), buf.ptr, iwork.ptr, ifail.ptr, out(&info));
    }
    try finishGeneralized(info, n);
    return .{ .found = @intCast(found) };
}

/// `spgvx` under its complex name.
pub const hpgvx = spgvx;

/// `A x = lambda B x` for a pair of banded matrices, `B` positive definite.
///
/// No `kind`: the band drivers solve only this form. `ka` and `kb` are the two
/// bandwidths and need not match.
pub fn sbgv(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    uplo: Uplo,
    n: usize,
    ka: usize,
    kb: usize,
    ab: []T,
    ldab: usize,
    bb: []T,
    ldbb: usize,
    w: []Real(T),
    z: []T,
    ldz: usize,
) Fail!void {
    std.debug.assert(ldab >= ka + 1 and ldbb >= kb + 1);
    std.debug.assert(w.len >= n);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const name = comptime herm(T, "sb", "hb", "gv");
    const n_ = dim(n);
    const ka_ = dim(ka);
    const kb_ = dim(kb);
    const ldab_ = dim(ldab);
    const ldbb_ = dim(ldbb);
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    const buf = try allocator.alloc(T, @max(if (comptime complexScratch(T)) n else 3 * n, 1));
    defer allocator.free(buf);

    if (comptime complexScratch(T)) {
        const rwork = try allocator.alloc(Real(T), @max(3 * n, 1));
        defer allocator.free(rwork);
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ref(&ka_), ref(&kb_), ab.ptr, ref(&ldab_), bb.ptr, ref(&ldbb_), w.ptr, z.ptr, ref(&ldz_), buf.ptr, rwork.ptr, out(&info));
    } else {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ref(&ka_), ref(&kb_), ab.ptr, ref(&ldab_), bb.ptr, ref(&ldbb_), w.ptr, z.ptr, ref(&ldz_), buf.ptr, out(&info));
    }
    return finishGeneralized(info, n);
}

/// `sbgv` under its complex name.
pub const hbgv = sbgv;

/// `sbgv` by divide and conquer.
pub fn sbgvd(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    uplo: Uplo,
    n: usize,
    ka: usize,
    kb: usize,
    ab: []T,
    ldab: usize,
    bb: []T,
    ldbb: usize,
    w: []Real(T),
    z: []T,
    ldz: usize,
) Fail!void {
    std.debug.assert(ldab >= ka + 1 and ldbb >= kb + 1);
    std.debug.assert(w.len >= n);
    if (job == .vectors) assertMatrix(z.len, n, n, ldz);

    const name = comptime herm(T, "sb", "hb", "gvd");
    const n_ = dim(n);
    const ka_ = dim(ka);
    const kb_ = dim(kb);
    const ldab_ = dim(ldab);
    const ldbb_ = dim(ldbb);
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    var rq: [1]Real(T) = undefined;
    var iq: [1]Int = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ref(&ka_), ref(&kb_), ab.ptr, ref(&ldab_), bb.ptr, ref(&ldbb_), w.ptr, z.ptr, ref(&ldz_), &wq, ref(&neg), &rq, ref(&neg), &iq, ref(&neg), out(&info));
    } else {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ref(&ka_), ref(&kb_), ab.ptr, ref(&ldab_), bb.ptr, ref(&ldbb_), w.ptr, z.ptr, ref(&ldz_), &wq, ref(&neg), &iq, ref(&neg), out(&info));
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
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ref(&ka_), ref(&kb_), ab.ptr, ref(&ldab_), bb.ptr, ref(&ldbb_), w.ptr, z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), rwork.ptr, ref(&lrwork), iwork.ptr, ref(&liwork), out(&info));
    } else {
        sym(T, name)(opt(job), opt(uplo), ref(&n_), ref(&ka_), ref(&kb_), ab.ptr, ref(&ldab_), bb.ptr, ref(&ldbb_), w.ptr, z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
    }
    return finishGeneralized(info, n);
}

/// `sbgvd` under its complex name.
pub const hbgvd = sbgvd;

/// `sbgv` restricted to a subset of the spectrum.
///
/// `q` receives the `sbgst` transformation, as in `sbevx`; it is `n x n` and
/// only referenced when `job = .vectors`.
pub fn sbgvx(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    selection: Selection,
    uplo: Uplo,
    n: usize,
    ka: usize,
    kb: usize,
    ab: []T,
    ldab: usize,
    bb: []T,
    ldbb: usize,
    q: []T,
    ldq: usize,
    w: []Real(T),
    z: []T,
    ldz: usize,
    abstol: Real(T),
    ifail: []Int,
) Fail!EigResult {
    std.debug.assert(ldab >= ka + 1 and ldbb >= kb + 1);
    std.debug.assert(w.len >= n and ifail.len >= n);
    std.debug.assert(ldq >= 1);
    if (job == .vectors) {
        assertMatrix(q.len, n, n, ldq);
        assertMatrix(z.len, n, n, ldz);
    }

    const name = comptime herm(T, "sb", "hb", "gvx");
    const win = Window.from(selection, n);
    const n_ = dim(n);
    const ka_ = dim(ka);
    const kb_ = dim(kb);
    const ldab_ = dim(ldab);
    const ldbb_ = dim(ldbb);
    const ldq_ = dim(ldq);
    const ldz_ = dim(@max(ldz, 1));
    const vl: Real(T) = @floatCast(win.vl);
    const vu: Real(T) = @floatCast(win.vu);
    var found: Int = 0;
    var info: Int = 0;

    const iwork = try allocator.alloc(Int, @max(5 * n, 1));
    defer allocator.free(iwork);
    const buf = try allocator.alloc(T, @max(if (comptime complexScratch(T)) n else 7 * n, 1));
    defer allocator.free(buf);

    if (comptime complexScratch(T)) {
        const rwork = try allocator.alloc(Real(T), @max(7 * n, 1));
        defer allocator.free(rwork);
        sym(T, name)(opt(job), opt(win.range), opt(uplo), ref(&n_), ref(&ka_), ref(&kb_), ab.ptr, ref(&ldab_), bb.ptr, ref(&ldbb_), q.ptr, ref(&ldq_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), buf.ptr, rwork.ptr, iwork.ptr, ifail.ptr, out(&info));
    } else {
        sym(T, name)(opt(job), opt(win.range), opt(uplo), ref(&n_), ref(&ka_), ref(&kb_), ab.ptr, ref(&ldab_), bb.ptr, ref(&ldbb_), q.ptr, ref(&ldq_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&found), w.ptr, z.ptr, ref(&ldz_), buf.ptr, iwork.ptr, ifail.ptr, out(&info));
    }
    try finishGeneralized(info, n);
    return .{ .found = @intCast(found) };
}

/// `sbgvx` under its complex name.
pub const hbgvx = sbgvx;

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const factor = @import("factor.zig");

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
    // info > n rather than with a separate code, and the wrapper reads the
    // split: above n is NotPositiveDefinite, at or below it is a convergence
    // failure. lastInfo() keeps the raw value, so lastInfo() - n is the
    // leading minor of B that failed.
    const n = 2;
    var a = [_]f64{ 2, 1, 1, 2 };
    var b = [_]f64{ 1, 2, 2, 1 };
    var w: [2]f64 = undefined;

    try testing.expectError(
        error.NotPositiveDefinite,
        sygv(f64, testing.allocator, .a_bx, .values_only, .upper, n, &a, n, &b, n, &w),
    );
    try testing.expect(info_mod.lastInfo() > n);
    try testing.expectEqual(@as(Int, 2), info_mod.lastInfo() - n);
}

test "single precision works through the same wrappers" {
    var a = [_]f32{ 2, 1, 1, 2 };
    var w: [2]f32 = undefined;
    try syev(f32, testing.allocator, .values_only, .upper, 2, &a, 2, &w);
    try testing.expectApproxEqAbs(@as(f32, 1), w[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 3), w[1], 1e-5);
}

// ============================================================================
// Tests: expert and divide-and-conquer variants
// ============================================================================

/// A symmetric 4x4 with well-separated eigenvalues, used by every test below so
/// the variants can be checked against each other.
const expert4 = [_]f64{
    6, 1, 0, 0,
    1, 5, 1, 0,
    0, 1, 4, 1,
    0, 0, 1, 3,
};

/// The eigenvalues of `expert4`, from `syev` — the driver already covered by
/// the tests above, so the variants are compared against something known good
/// rather than against numbers written down here.
fn expert4Eigenvalues() ![4]f64 {
    var a = expert4;
    var w: [4]f64 = undefined;
    try syev(f64, testing.allocator, .values_only, .upper, 4, &a, 4, &w);
    return w;
}

test "syevx computes a selected index range and reports no failures" {
    const reference = try expert4Eigenvalues();

    var a = expert4;
    var w: [4]f64 = undefined;
    var z: [4 * 4]f64 = undefined;
    var ifail: [4]Int = undefined;
    const res = try syevx(f64, testing.allocator, .vectors, .{ .indices = .{ .first = 2, .last = 3 } }, .upper, 4, &a, 4, &w, &z, 4, 0, &ifail);

    try testing.expectEqual(@as(usize, 2), res.found);
    for (0..2) |i| try testing.expectApproxEqAbs(reference[i + 1], w[i], 1e-12);

    // With every vector converged, ifail is not written past found, so only
    // the return value says the call succeeded.
    for (0..res.found) |j| {
        var norm: f64 = 0;
        for (0..4) |i| norm += z[i + j * 4] * z[i + j * 4];
        try testing.expectApproxEqAbs(@as(f64, 1), norm, 1e-12);
    }
}

test "syevx and syevr agree on an interval selection" {
    const reference = try expert4Eigenvalues();
    // An interval that contains exactly the two middle eigenvalues.
    const low = (reference[0] + reference[1]) / 2;
    const high = (reference[2] + reference[3]) / 2;

    var ax = expert4;
    var wx: [4]f64 = undefined;
    var zx: [4 * 4]f64 = undefined;
    var ifail: [4]Int = undefined;
    const rx = try syevx(f64, testing.allocator, .values_only, .{ .interval = .{ .low = low, .high = high } }, .upper, 4, &ax, 4, &wx, &zx, 4, 0, &ifail);

    var ar = expert4;
    var wr: [4]f64 = undefined;
    var zr: [4 * 4]f64 = undefined;
    const rr = try syevr(f64, testing.allocator, .values_only, .{ .interval = .{ .low = low, .high = high } }, .upper, 4, &ar, 4, &wr, &zr, 4, 0);

    try testing.expectEqual(@as(usize, 2), rx.found);
    try testing.expectEqual(rx.found, rr.found);
    for (0..rx.found) |i| try testing.expectApproxEqAbs(wx[i], wr[i], 1e-12);
}

test "heevx takes 7n rwork where syevx takes none" {
    const Z = Complex(f64);
    const a0 = [_]Z{
        Z.init(4, 0), Z.init(1, -1), Z.init(0, 0),
        Z.init(1, 1), Z.init(5, 0),  Z.init(0, -2),
        Z.init(0, 0), Z.init(0, 2),  Z.init(6, 0),
    };
    var a = a0;
    var w: [3]f64 = undefined;
    var z: [3 * 3]Z = undefined;
    var ifail: [3]Int = undefined;
    const res = try heevx(Z, testing.allocator, .vectors, .all, .upper, 3, &a, 3, &w, &z, 3, 0, &ifail);

    try testing.expectEqual(@as(usize, 3), res.found);
    // Hermitian: the trace is the sum of the eigenvalues.
    var sum: f64 = 0;
    for (w) |v| sum += v;
    try testing.expectApproxEqAbs(@as(f64, 15), sum, 1e-12);
    try testing.expect(w[0] < w[1] and w[1] < w[2]);
}

test "spevd and spevx agree with spev in packed storage" {
    const reference = try expert4Eigenvalues();
    var ap0: [10]f64 = undefined;
    var at: usize = 0;
    for (0..4) |j| for (0..j + 1) |i| {
        ap0[at] = expert4[i + j * 4];
        at += 1;
    };

    var ap_d = ap0;
    var w_d: [4]f64 = undefined;
    var z_d: [16]f64 = undefined;
    try spevd(f64, testing.allocator, .vectors, .upper, 4, &ap_d, &w_d, &z_d, 4);
    for (reference, w_d) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);

    var ap_x = ap0;
    var w_x: [4]f64 = undefined;
    var z_x: [16]f64 = undefined;
    var ifail: [4]Int = undefined;
    const res = try spevx(f64, testing.allocator, .vectors, .all, .upper, 4, &ap_x, &w_x, &z_x, 4, 0, &ifail);
    try testing.expectEqual(@as(usize, 4), res.found);
    for (reference, w_x) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "sbevd and sbevx agree with sbev in band storage" {
    const reference = try expert4Eigenvalues();
    // kd = 1, upper band: row kd + i - j.
    const ab0 = [_]f64{ 0, 6, 1, 5, 1, 4, 1, 3 };

    var ab_d = ab0;
    var w_d: [4]f64 = undefined;
    var z_d: [16]f64 = undefined;
    try sbevd(f64, testing.allocator, .vectors, .upper, 4, 1, &ab_d, 2, &w_d, &z_d, 4);
    for (reference, w_d) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);

    var ab_x = ab0;
    var q: [16]f64 = undefined;
    var w_x: [4]f64 = undefined;
    var z_x: [16]f64 = undefined;
    var ifail: [4]Int = undefined;
    const res = try sbevx(f64, testing.allocator, .vectors, .{ .indices = .{ .first = 1, .last = 4 } }, .upper, 4, 1, &ab_x, 2, &q, 4, &w_x, &z_x, 4, 0, &ifail);
    try testing.expectEqual(@as(usize, 4), res.found);
    for (reference, w_x) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "sbevx writes its reduction factor into q" {
    const ab0 = [_]f64{ 0, 6, 1, 5, 1, 4, 1, 3 };
    var ab = ab0;
    var q = [_]f64{-1} ** 16;
    var w: [4]f64 = undefined;
    var z: [16]f64 = undefined;
    var ifail: [4]Int = undefined;
    _ = try sbevx(f64, testing.allocator, .vectors, .all, .upper, 4, 1, &ab, 2, &q, 4, &w, &z, 4, 0, &ifail);

    // q is an output, not a workspace: it comes back orthogonal, and the poison
    // is gone.
    for (0..4) |j| {
        var norm: f64 = 0;
        for (0..4) |i| norm += q[i + j * 4] * q[i + j * 4];
        try testing.expectApproxEqAbs(@as(f64, 1), norm, 1e-12);
    }
}

test "stevd, stevx and stevr agree with stev" {
    const d0 = [_]f64{ 6, 5, 4, 3 };
    const e0 = [_]f64{ 1, 1, 1 };

    var d_ref = d0;
    var e_ref = e0;
    var z_ref: [16]f64 = undefined;
    try stev(f64, testing.allocator, .values_only, 4, &d_ref, &e_ref, &z_ref, 1);

    var d_d = d0;
    var e_d = e0;
    var z_d: [16]f64 = undefined;
    try stevd(f64, testing.allocator, .vectors, 4, &d_d, &e_d, &z_d, 4);
    for (d_ref, d_d) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);

    var d_x = d0;
    var e_x = e0;
    var w_x: [4]f64 = undefined;
    var z_x: [16]f64 = undefined;
    var ifail: [4]Int = undefined;
    const rx = try stevx(f64, testing.allocator, .vectors, .all, 4, &d_x, &e_x, &w_x, &z_x, 4, 0, &ifail);
    try testing.expectEqual(@as(usize, 4), rx.found);
    for (d_ref, w_x) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);

    var d_r = d0;
    var e_r = e0;
    var w_r: [4]f64 = undefined;
    var z_r: [16]f64 = undefined;
    var isuppz: [8]Int = undefined;
    const rr = try stevr(f64, testing.allocator, .vectors, .all, 4, &d_r, &e_r, &w_r, &z_r, 4, &isuppz, 0);
    try testing.expectEqual(@as(usize, 4), rr.found);
    for (d_ref, w_r) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "stevr's isuppz bounds the nonzero rows of each vector" {
    // A matrix with a zero off-diagonal splits, so each eigenvector is nonzero
    // in only one half - which is what isuppz reports.
    var d = [_]f64{ 1, 2, 10, 20 };
    var e = [_]f64{ 1, 0, 1 };
    var w: [4]f64 = undefined;
    var z: [16]f64 = undefined;
    var isuppz: [8]Int = undefined;
    const res = try stevr(f64, testing.allocator, .vectors, .all, 4, &d, &e, &w, &z, 4, &isuppz, 0);

    try testing.expectEqual(@as(usize, 4), res.found);
    for (0..4) |j| {
        const lo: usize = @intCast(isuppz[2 * j]);
        const hi: usize = @intCast(isuppz[2 * j + 1]);
        try testing.expect(lo >= 1 and hi <= 4 and lo <= hi);
        // Everything outside the support is zero.
        for (0..4) |i| {
            if (i + 1 < lo or i + 1 > hi) try testing.expectApproxEqAbs(@as(f64, 0), z[i + j * 4], 1e-14);
        }
    }
}

// ============================================================================
// Tests: generalized symmetric eigenproblems
// ============================================================================

/// `A` and a positive definite `B`, used by every generalized test below.
const gen_a = [_]f64{
    6, 1, 0,
    1, 5, 1,
    0, 1, 4,
};
const gen_b = [_]f64{
    2, 0, 0,
    0, 3, 0,
    0, 0, 4,
};

/// The eigenvalues of `A x = lambda B x`, from `sygv` — already covered above,
/// so the variants are checked against a known-good driver.
fn generalizedEigenvalues() ![3]f64 {
    var a = gen_a;
    var b = gen_b;
    var w: [3]f64 = undefined;
    try sygv(f64, testing.allocator, .a_bx, .values_only, .upper, 3, &a, 3, &b, 3, &w);
    return w;
}

test "sygst reduces to a standard problem with the same eigenvalues" {
    const reference = try generalizedEigenvalues();

    var a = gen_a;
    var b = gen_b;
    // sygst wants the Cholesky factor, not B itself.
    try factor.potrf(f64, .upper, 3, &b, 3);
    try sygst(f64, .a_bx, .upper, 3, &a, 3, &b, 3);

    // What is left is an ordinary symmetric eigenproblem.
    var w: [3]f64 = undefined;
    try syev(f64, testing.allocator, .values_only, .upper, 3, &a, 3, &w);
    for (reference, w) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "spgst matches sygst in packed storage" {
    const reference = try generalizedEigenvalues();

    var ap: [6]f64 = undefined;
    var bp: [6]f64 = undefined;
    var at: usize = 0;
    for (0..3) |j| for (0..j + 1) |i| {
        ap[at] = gen_a[i + j * 3];
        bp[at] = gen_b[i + j * 3];
        at += 1;
    };
    try factor.pptrf(f64, .upper, 3, &bp);
    try spgst(f64, .a_bx, .upper, 3, &ap, &bp);

    var w: [3]f64 = undefined;
    var z: [1]f64 = undefined;
    try spev(f64, testing.allocator, .values_only, .upper, 3, &ap, &w, &z, 1);
    for (reference, w) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "sygvd and sygvx agree with sygv" {
    const reference = try generalizedEigenvalues();

    var ad = gen_a;
    var bd = gen_b;
    var wd: [3]f64 = undefined;
    try sygvd(f64, testing.allocator, .a_bx, .vectors, .upper, 3, &ad, 3, &bd, 3, &wd);
    for (reference, wd) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);

    var ax = gen_a;
    var bx = gen_b;
    var wx: [3]f64 = undefined;
    var zx: [9]f64 = undefined;
    var ifail: [3]Int = undefined;
    const res = try sygvx(f64, testing.allocator, .a_bx, .vectors, .all, .upper, 3, &ax, 3, &bx, 3, &wx, &zx, 3, 0, &ifail);
    try testing.expectEqual(@as(usize, 3), res.found);
    for (reference, wx) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "sygvx's vectors satisfy A x = lambda B x" {
    var a = gen_a;
    var b = gen_b;
    var w: [3]f64 = undefined;
    var z: [9]f64 = undefined;
    var ifail: [3]Int = undefined;
    _ = try sygvx(f64, testing.allocator, .a_bx, .vectors, .all, .upper, 3, &a, 3, &b, 3, &w, &z, 3, 0, &ifail);

    for (0..3) |j| {
        for (0..3) |i| {
            var ax: f64 = 0;
            var bx: f64 = 0;
            for (0..3) |k| {
                ax += gen_a[i + k * 3] * z[k + j * 3];
                bx += gen_b[i + k * 3] * z[k + j * 3];
            }
            try testing.expectApproxEqAbs(w[j] * bx, ax, 1e-11);
        }
    }
}

test "spgv, spgvd and spgvx agree in packed storage" {
    const reference = try generalizedEigenvalues();
    var ap0: [6]f64 = undefined;
    var bp0: [6]f64 = undefined;
    var at: usize = 0;
    for (0..3) |j| for (0..j + 1) |i| {
        ap0[at] = gen_a[i + j * 3];
        bp0[at] = gen_b[i + j * 3];
        at += 1;
    };

    var ap = ap0;
    var bp = bp0;
    var w: [3]f64 = undefined;
    var z: [9]f64 = undefined;
    try spgv(f64, testing.allocator, .a_bx, .vectors, .upper, 3, &ap, &bp, &w, &z, 3);
    for (reference, w) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);

    ap = ap0;
    bp = bp0;
    try spgvd(f64, testing.allocator, .a_bx, .vectors, .upper, 3, &ap, &bp, &w, &z, 3);
    for (reference, w) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);

    ap = ap0;
    bp = bp0;
    var ifail: [3]Int = undefined;
    const res = try spgvx(f64, testing.allocator, .a_bx, .vectors, .{ .indices = .{ .first = 1, .last = 2 } }, .upper, 3, &ap, &bp, &w, &z, 3, 0, &ifail);
    try testing.expectEqual(@as(usize, 2), res.found);
    for (0..2) |i| try testing.expectApproxEqAbs(reference[i], w[i], 1e-12);
}

test "sbgv, sbgvd and sbgvx agree in band storage" {
    const reference = try generalizedEigenvalues();
    // A: ka = 1, B: kb = 0 (diagonal). Upper band, row kd + i - j.
    const ab0 = [_]f64{ 0, 6, 1, 5, 1, 4 };
    const bb0 = [_]f64{ 2, 3, 4 };

    var ab = ab0;
    var bb = bb0;
    var w: [3]f64 = undefined;
    var z: [9]f64 = undefined;
    try sbgv(f64, testing.allocator, .vectors, .upper, 3, 1, 0, &ab, 2, &bb, 1, &w, &z, 3);
    for (reference, w) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);

    ab = ab0;
    bb = bb0;
    try sbgvd(f64, testing.allocator, .vectors, .upper, 3, 1, 0, &ab, 2, &bb, 1, &w, &z, 3);
    for (reference, w) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);

    ab = ab0;
    bb = bb0;
    var q: [9]f64 = undefined;
    var ifail: [3]Int = undefined;
    const res = try sbgvx(f64, testing.allocator, .vectors, .all, .upper, 3, 1, 0, &ab, 2, &bb, 1, &q, 3, &w, &z, 3, 0, &ifail);
    try testing.expectEqual(@as(usize, 3), res.found);
    for (reference, w) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "sbgst reduces the banded pair, matching sbgv" {
    const reference = try generalizedEigenvalues();
    var ab = [_]f64{ 0, 6, 1, 5, 1, 4 };
    var bb = [_]f64{ 2, 3, 4 };

    // pbstf, not pbtrf: sbgst wants the split factor.
    try factor.pbstf(f64, .upper, 3, 0, &bb, 1);

    var x: [9]f64 = undefined;
    try sbgst(f64, testing.allocator, .vectors, .upper, 3, 1, 0, &ab, 2, &bb, 1, &x, 3);

    // What is left is a standard banded symmetric eigenproblem.
    var w: [3]f64 = undefined;
    var z: [1]f64 = undefined;
    try sbev(f64, testing.allocator, .values_only, .upper, 3, 1, &ab, 2, &w, &z, 1);
    for (reference, w) |a, b| try testing.expectApproxEqAbs(a, b, 1e-12);
}

test "the complex generalized drivers agree with each other" {
    const Z = Complex(f64);
    const a0 = [_]Z{
        Z.init(6, 0), Z.init(1, -1),
        Z.init(1, 1), Z.init(5, 0),
    };
    const b0 = [_]Z{
        Z.init(2, 0), Z.init(0, 0),
        Z.init(0, 0), Z.init(3, 0),
    };

    var a = a0;
    var b = b0;
    var w_ref: [2]f64 = undefined;
    try hegv(Z, testing.allocator, .a_bx, .values_only, .upper, 2, &a, 2, &b, 2, &w_ref);

    a = a0;
    b = b0;
    var w: [2]f64 = undefined;
    try hegvd(Z, testing.allocator, .a_bx, .values_only, .upper, 2, &a, 2, &b, 2, &w);
    for (w_ref, w) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);

    a = a0;
    b = b0;
    var z: [4]Z = undefined;
    var ifail: [2]Int = undefined;
    const res = try hegvx(Z, testing.allocator, .a_bx, .vectors, .all, .upper, 2, &a, 2, &b, 2, &w, &z, 2, 0, &ifail);
    try testing.expectEqual(@as(usize, 2), res.found);
    for (w_ref, w) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "the abx and bax forms give different eigenvalues from a_bx" {
    var w: [3][3]f64 = undefined;
    for ([_]GeneralizedKind{ .a_bx, .abx, .bax }, 0..) |kind, i| {
        var a = gen_a;
        var b = gen_b;
        try sygvd(f64, testing.allocator, kind, .values_only, .upper, 3, &a, 3, &b, 3, &w[i]);
    }

    // A B and B A are similar, so kinds 2 and 3 share a spectrum; kind 1 does
    // not. The itype is not a formatting detail.
    for (w[1], w[2]) |x, y| try testing.expectApproxEqAbs(x, y, 1e-11);
    try testing.expect(@abs(w[0][0] - w[1][0]) > 1);
}
