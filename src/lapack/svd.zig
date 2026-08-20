//! Singular value decomposition: `A = U S V^H`.
//!
//! `gesdd` is divide and conquer and is the one to use — substantially faster
//! than `gesvd` whenever singular vectors are wanted. `gesvd` is here because
//! it offers finer control over which vectors get computed, and because its
//! interface is the one most documentation describes.
//!
//! Singular values come back in **descending** order and are always real, even
//! for a complex `A`, which is why `s` is `[]Real(T)`.
//!
//! ## `U` and `V^H`, not `U` and `V`
//!
//! LAPACK returns the second factor already conjugate-transposed. For an
//! `m x n` matrix, `u` is `m x m` (or `m x min(m,n)` for the thin form) and
//! `vt` is `n x n` (or `min(m,n) x n`), and the reconstruction is
//! `A = U * S * VT` with no further transposing. Taking `vt` for `V` gives the
//! transpose of what you wanted, which for a symmetric test matrix looks
//! correct and for anything else does not.
//!
//! ## The thin decomposition
//!
//! For a tall `m x n` matrix with `m >> n`, the full `U` is `m x m` and almost
//! all of it is irrelevant — only the first `n` columns pair with a nonzero
//! singular value. `JobSvd.some` computes just those, and is usually what you
//! want; `.all` exists for when you specifically need an orthonormal basis of
//! the whole space.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");

const Int = types.Int;
const Complex = types.Complex;
const Real = types.Real;
const JobSvd = types.JobSvd;
const Error = info_mod.Error;
const dim = types.dim;
const assertMatrix = types.assertMatrix;
const ref = work_mod.ref;
const out = work_mod.out;
const opt = types.opt;

const Allocator = std.mem.Allocator;
const Fail = Error || Allocator.Error;

fn sym(comptime T: type, comptime name: []const u8) @TypeOf(@field(c, [_]u8{types.prefix(T)} ++ name)) {
    return @field(c, [_]u8{types.prefix(T)} ++ name);
}

fn complexScratch(comptime T: type) bool {
    return switch (T) {
        f32, f64 => false,
        else => true,
    };
}

/// `A = U S V^H`, by QR iteration.
///
/// `jobu` and `jobvt` are chosen independently, which is the reason to prefer
/// this over `gesdd` — you can compute `U` and skip `V^H` entirely. At most one
/// of them may be `.overwrite`, since both would want to write into `a`.
///
/// `a` is destroyed unless one of the jobs is `.overwrite`, in which case it
/// holds that factor.
///
/// `error.NoConvergence` means some superdiagonals of the intermediate
/// bidiagonal form did not converge; `lastInfo()` is how many.
pub fn gesvd(
    comptime T: type,
    allocator: Allocator,
    jobu: JobSvd,
    jobvt: JobSvd,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    s: []Real(T),
    u: []T,
    ldu: usize,
    vt: []T,
    ldvt: usize,
) Fail!void {
    std.debug.assert(!(jobu == .overwrite and jobvt == .overwrite));
    assertMatrix(a.len, rows, cols, lda);
    const mn = @min(rows, cols);
    std.debug.assert(s.len >= mn);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(lda);
    const ldu_ = dim(@max(ldu, 1));
    const ldvt_ = dim(@max(ldvt, 1));
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, "gesvd")(opt(jobu), opt(jobvt), ref(&m_), ref(&n_), &probe, ref(&lda_), &rprobe, &probe, ref(&ldu_), &probe, ref(&ldvt_), &wq, ref(&neg), &rprobe, out(&info));
    } else {
        sym(T, "gesvd")(opt(jobu), opt(jobvt), ref(&m_), ref(&n_), &probe, ref(&lda_), &rprobe, &probe, ref(&ldu_), &probe, ref(&ldvt_), &wq, ref(&neg), out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexScratch(T)) {
        // gesvd's rwork is a fixed 5*min(m, n) and is not part of the query.
        const rwork = try allocator.alloc(Real(T), @max(5 * mn, 1));
        defer allocator.free(rwork);
        sym(T, "gesvd")(opt(jobu), opt(jobvt), ref(&m_), ref(&n_), a.ptr, ref(&lda_), s.ptr, u.ptr, ref(&ldu_), vt.ptr, ref(&ldvt_), buf.ptr, ref(&lwork), rwork.ptr, out(&info));
    } else {
        sym(T, "gesvd")(opt(jobu), opt(jobvt), ref(&m_), ref(&n_), a.ptr, ref(&lda_), s.ptr, u.ptr, ref(&ldu_), vt.ptr, ref(&ldvt_), buf.ptr, ref(&lwork), out(&info));
    }
    return info_mod.checkConvergence(info);
}

/// `A = U S V^H`, by divide and conquer. Faster than `gesvd`, less flexible.
///
/// One `job` controls both factors, because the algorithm computes them
/// together:
///
/// - `.none` — singular values only.
/// - `.all` — full `m x m` `U` and `n x n` `V^H`.
/// - `.some` — the thin form: `min(m,n)` columns of `U`, `min(m,n)` rows of
///   `V^H`. Usually what you want.
/// - `.overwrite` — thin form, with the larger factor written back into `a` to
///   save the allocation.
pub fn gesdd(
    comptime T: type,
    allocator: Allocator,
    job: JobSvd,
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
    s: []Real(T),
    u: []T,
    ldu: usize,
    vt: []T,
    ldvt: usize,
) Fail!void {
    assertMatrix(a.len, rows, cols, lda);
    const mn = @min(rows, cols);
    const mx = @max(rows, cols);
    std.debug.assert(s.len >= mn);

    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(lda);
    const ldu_ = dim(@max(ldu, 1));
    const ldvt_ = dim(@max(ldvt, 1));
    var info: Int = 0;

    const iwork = try allocator.alloc(Int, @max(8 * mn, 1));
    defer allocator.free(iwork);

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexScratch(T)) {
        sym(T, "gesdd")(opt(job), ref(&m_), ref(&n_), &probe, ref(&lda_), &rprobe, &probe, ref(&ldu_), &probe, ref(&ldvt_), &wq, ref(&neg), &rprobe, iwork.ptr, out(&info));
    } else {
        sym(T, "gesdd")(opt(job), ref(&m_), ref(&n_), &probe, ref(&lda_), &rprobe, &probe, ref(&ldu_), &probe, ref(&ldvt_), &wq, ref(&neg), iwork.ptr, out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexScratch(T)) {
        // The complex gesdd takes an rwork with no length argument, so its size
        // comes from a formula rather than from the query - and the formula
        // depends on `job`. Rather than encode that branching, this allocates
        // the largest of the documented cases; the excess is bounded by
        // O(min(m,n)^2) and an undersized buffer here is a heap overflow.
        const quad = 5 * mn * mn + 7 * mn;
        const linear = 2 * mx * mn + 2 * mn * mn + mn;
        const rwork = try allocator.alloc(Real(T), @max(@max(quad, linear), 1));
        defer allocator.free(rwork);
        sym(T, "gesdd")(opt(job), ref(&m_), ref(&n_), a.ptr, ref(&lda_), s.ptr, u.ptr, ref(&ldu_), vt.ptr, ref(&ldvt_), buf.ptr, ref(&lwork), rwork.ptr, iwork.ptr, out(&info));
    } else {
        sym(T, "gesdd")(opt(job), ref(&m_), ref(&n_), a.ptr, ref(&lda_), s.ptr, u.ptr, ref(&ldu_), vt.ptr, ref(&ldvt_), buf.ptr, ref(&lwork), iwork.ptr, out(&info));
    }
    return info_mod.checkConvergence(info);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// `max |(U S VT)_ij - A_ij|` — the only reconstruction that proves an SVD is
/// right, since `U` and `V` are each determined only up to sign.
fn reconstructionError(
    m: usize,
    n: usize,
    k: usize,
    u: []const f64,
    ldu: usize,
    s: []const f64,
    vt: []const f64,
    ldvt: usize,
    a: []const f64,
    lda: usize,
) f64 {
    var worst: f64 = 0;
    for (0..m) |i| {
        for (0..n) |j| {
            var acc: f64 = 0;
            for (0..k) |p| acc += u[i + p * ldu] * s[p] * vt[p + j * ldvt];
            worst = @max(worst, @abs(acc - a[i + j * lda]));
        }
    }
    return worst;
}

test "gesvd reconstructs the original matrix" {
    // 3x2, column-major [[1, 2], [3, 4], [5, 6]].
    const m = 3;
    const n = 2;
    const original = [_]f64{ 1, 3, 5, 2, 4, 6 };
    var a = original;
    var s: [2]f64 = undefined;
    var u: [m * m]f64 = undefined;
    var vt: [n * n]f64 = undefined;

    try gesvd(f64, testing.allocator, .all, .all, m, n, &a, m, &s, &u, m, &vt, n);

    // U is 3x3, VT is 2x2, and only the first min(m,n) singular values pair up.
    try testing.expect(reconstructionError(m, n, n, &u, m, &s, &vt, n, &original, m) < 1e-12);

    // Descending order.
    try testing.expect(s[0] > s[1]);
    try testing.expect(s[1] > 0);
}

test "gesvd computes the thin decomposition" {
    const m = 3;
    const n = 2;
    const original = [_]f64{ 1, 3, 5, 2, 4, 6 };
    var a = original;
    var s: [2]f64 = undefined;
    var u: [m * n]f64 = undefined; // only min(m,n) columns
    var vt: [n * n]f64 = undefined;

    try gesvd(f64, testing.allocator, .some, .all, m, n, &a, m, &s, &u, m, &vt, n);

    try testing.expect(reconstructionError(m, n, n, &u, m, &s, &vt, n, &original, m) < 1e-12);
}

test "gesvd can compute one factor and skip the other" {
    // The reason to reach for gesvd over gesdd: independent job flags.
    const m = 3;
    const n = 2;
    var a = [_]f64{ 1, 3, 5, 2, 4, 6 };
    var s: [2]f64 = undefined;
    var u: [m * n]f64 = undefined;
    var vt: [1]f64 = .{-999};

    try gesvd(f64, testing.allocator, .some, .none, m, n, &a, m, &s, &u, m, &vt, 1);

    // vt was not computed and not touched.
    try testing.expectEqual(@as(f64, -999), vt[0]);
    try testing.expect(s[0] > s[1]);
}

test "vt is V transposed, not V" {
    // On an asymmetric matrix the difference is visible; on a symmetric one it
    // is not, which is how this gets missed.
    const m = 2;
    const n = 2;
    const original = [_]f64{ 1, 0, 2, 3 }; // column-major [[1, 2], [0, 3]]
    var a = original;
    var s: [2]f64 = undefined;
    var u: [4]f64 = undefined;
    var vt: [4]f64 = undefined;

    try gesvd(f64, testing.allocator, .all, .all, m, n, &a, m, &s, &u, m, &vt, n);

    // U S VT = A reconstructs.
    try testing.expect(reconstructionError(m, n, n, &u, m, &s, &vt, n, &original, m) < 1e-12);

    // Using vt as if it were V - i.e. transposing it before multiplying - does
    // not, unless vt happens to be symmetric.
    var worst: f64 = 0;
    for (0..m) |i| {
        for (0..n) |j| {
            var acc: f64 = 0;
            for (0..n) |p| acc += u[i + p * m] * s[p] * vt[j + p * n];
            worst = @max(worst, @abs(acc - original[i + j * m]));
        }
    }
    try testing.expect(worst > 1e-6);
}

test "gesdd agrees with gesvd" {
    const m = 4;
    const n = 3;
    const original = [_]f64{ 1, 2, 3, 4, 2, 4, 5, 7, 3, 5, 8, 11 };

    var a1 = original;
    var s1: [3]f64 = undefined;
    var u_qr: [m * m]f64 = undefined;
    var vt_qr: [n * n]f64 = undefined;
    try gesvd(f64, testing.allocator, .all, .all, m, n, &a1, m, &s1, &u_qr, m, &vt_qr, n);

    var a2 = original;
    var s2: [3]f64 = undefined;
    var u_dc: [m * m]f64 = undefined;
    var vt_dc: [n * n]f64 = undefined;
    try gesdd(f64, testing.allocator, .all, m, n, &a2, m, &s2, &u_dc, m, &vt_dc, n);

    // Singular values are unique, so these must match exactly (to tolerance);
    // the vectors need not, since signs are arbitrary.
    for (s1, s2) |x, y| try testing.expectApproxEqAbs(x, y, 1e-10);
    try testing.expect(reconstructionError(m, n, n, &u_dc, m, &s2, &vt_dc, n, &original, m) < 1e-10);
}

test "gesdd computes singular values alone" {
    const m = 3;
    const n = 2;
    var a = [_]f64{ 1, 3, 5, 2, 4, 6 };
    var s: [2]f64 = undefined;
    var dummy: [1]f64 = .{-999};

    try gesdd(f64, testing.allocator, .none, m, n, &a, m, &s, &dummy, 1, &dummy, 1);

    try testing.expect(s[0] > s[1]);
    try testing.expectEqual(@as(f64, -999), dummy[0]);
}

test "gesdd reports rank through a zero singular value" {
    // Rank 1: every column a multiple of the first.
    const m = 3;
    const n = 2;
    var a = [_]f64{ 1, 1, 1, 2, 2, 2 };
    var s: [2]f64 = undefined;
    var dummy: [1]f64 = .{0};

    try gesdd(f64, testing.allocator, .none, m, n, &a, m, &s, &dummy, 1, &dummy, 1);

    // sqrt(3 * 5) = sqrt(15) for the nonzero one, and zero for the other.
    try testing.expectApproxEqAbs(@sqrt(@as(f64, 15)), s[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), s[1], 1e-12);
}

test "the complex SVD reconstructs through the conjugate transpose" {
    const Z = Complex(f64);
    const m = 2;
    const n = 2;
    const original = [_]Z{ Z.init(1, 0), Z.init(0, 1), Z.init(0, -1), Z.init(1, 0) };
    var a = original;
    var s: [2]f64 = undefined;
    var u: [4]Z = undefined;
    var vt: [4]Z = undefined;

    try gesdd(Z, testing.allocator, .all, m, n, &a, m, &s, &u, m, &vt, n);

    // Singular values are real even though A is not - the signature says so.
    try testing.expectEqual(f64, @TypeOf(s[0]));

    // U S VT = A, with vt already conjugate-transposed by LAPACK.
    for (0..m) |i| {
        for (0..n) |j| {
            var acc = Z.zero;
            for (0..n) |p| {
                const us = Z.init(u[i + p * m].re * s[p], u[i + p * m].im * s[p]);
                acc = acc.add(us.mul(vt[p + j * n]));
            }
            try testing.expectApproxEqAbs(original[i + j * m].re, acc.re, 1e-12);
            try testing.expectApproxEqAbs(original[i + j * m].im, acc.im, 1e-12);
        }
    }
}

test "a wide matrix works as well as a tall one" {
    // 2x4: min(m, n) = 2, so there are two singular values and the thin U is
    // 2x2 while the thin VT is 2x4.
    const m = 2;
    const n = 4;
    const original = [_]f64{ 1, 5, 2, 6, 3, 7, 4, 8 };
    var a = original;
    var s: [2]f64 = undefined;
    var u: [m * m]f64 = undefined;
    var vt: [2 * n]f64 = undefined;

    try gesdd(f64, testing.allocator, .some, m, n, &a, m, &s, &u, m, &vt, 2);

    try testing.expect(reconstructionError(m, n, 2, &u, m, &s, &vt, 2, &original, m) < 1e-12);
}

test "single precision works through the same wrappers" {
    var a = [_]f32{ 1, 3, 5, 2, 4, 6 };
    var s: [2]f32 = undefined;
    var dummy: [1]f32 = .{0};
    try gesdd(f32, testing.allocator, .none, 3, 2, &a, 3, &s, &dummy, 1, &dummy, 1);
    try testing.expect(s[0] > s[1]);
}
