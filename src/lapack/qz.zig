//! The generalized eigenproblem, taken apart: the QZ algorithm and its Schur
//! toolkit.
//!
//! `eigen_gen.ggev` solves `A x = lambda B x` in one call. This module is the
//! same computation in stages, plus the tools that operate on the result:
//!
//! | stage | routine | analogue in the standard problem |
//! |---|---|---|
//! | balance | `ggbal` / `ggbak` | `reduce.gebal` / `gebak` |
//! | reduce | `gghd3` | `reduce.gehrd` |
//! | iterate | `hgeqz` | `eigen_gen.hseqr` |
//! | eigenvectors | `tgevc` | `eigen_gen.trevc3` |
//! | reorder | `tgexc`, `tgsen` | `trexc`, `trsen` |
//! | condition | `tgsna` | `trsna` |
//! | Sylvester | `tgsyl` | `trsyl` |
//!
//! Plus the drivers that package them: `gges`/`gges3` for the generalized Schur
//! form, `ggesx` and `ggevx` for the expert versions, `ggev3` for the blocked
//! eigenvalue driver, and `ggsvd3`/`tgsja` for the generalized SVD.
//!
//! ## Two matrices, two of everything
//!
//! Where the standard problem reduces `A` to Hessenberg form with one
//! orthogonal `Q`, the generalized one reduces the *pair* `(A, B)` to
//! Hessenberg-triangular form with two, `Q` and `Z`, applied on opposite sides:
//! `Q^H A Z` is Hessenberg and `Q^H B Z` is upper triangular. Everything here
//! therefore comes in pairs — two balancing vectors, two vector matrices, two
//! `compq`/`compz` flags — and mixing up which side a factor belongs on is the
//! standing hazard.
//!
//! ## Eigenvalues are ratios, and may be infinite
//!
//! `alpha / beta` rather than a single number, so that `beta = 0` can represent
//! an infinite eigenvalue rather than dividing by zero. That is not a corner
//! case: a singular `B` produces them routinely. `GeneralizedEigenvalue` from
//! `eigen_gen.zig` carries the pair and has `value()` returning null for the
//! infinite ones.
//!
//! ## `wantq`/`wantz` are Fortran logicals, not characters
//!
//! `tgexc` and `tgsen` are the only routines in this binding that take a
//! boolean *scalar* rather than an option character. They are `bool` here and
//! converted at the boundary.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");
const eigen_gen = @import("eigen_gen.zig");

const Int = types.Int;
const Bool = types.Bool;
const Complex = types.Complex;
const Real = types.Real;
const Job = types.Job;
const Trans = types.Trans;
const Sort = types.Sort;
const Side = types.Side;
const Balance = types.Balance;
const Error = info_mod.Error;
const dim = types.dim;
const assertMatrix = types.assertMatrix;
const ref = work_mod.ref;
const out = work_mod.out;
const opt = types.opt;

const Allocator = std.mem.Allocator;
const Fail = Error || Allocator.Error;

/// Re-exported so callers need not reach across modules for the shared
/// vocabulary.
pub const Eigenvalue = eigen_gen.Eigenvalue;
pub const GeneralizedEigenvalue = eigen_gen.GeneralizedEigenvalue;
pub const Sense = eigen_gen.Sense;
pub const SchurJob = eigen_gen.SchurJob;
pub const SchurVectors = eigen_gen.SchurVectors;
pub const HowMany = eigen_gen.HowMany;
pub const ReorderResult = eigen_gen.ReorderResult;
pub const Window = @import("reduce.zig").Window;

fn sym(comptime T: type, comptime name: []const u8) @TypeOf(@field(c, [_]u8{types.prefix(T)} ++ name)) {
    return @field(c, [_]u8{types.prefix(T)} ++ name);
}

fn complexElement(comptime T: type) bool {
    return switch (T) {
        f32, f64 => false,
        else => true,
    };
}

/// The two or three arrays LAPACK splits a generalized eigenvalue across, and
/// the gather back into `GeneralizedEigenvalue`.
///
/// The real routines use `alphar`, `alphai` and `beta`; the complex ones use
/// `alpha` and `beta`. `beta` is real in both cases, which the complex
/// signature hides by declaring it complex.
fn Alphas(comptime T: type) type {
    return struct {
        const Self = @This();
        ar: []T,
        ai: []T,
        b: []T,
        allocator: Allocator,

        fn init(allocator: Allocator, n: usize) !Self {
            const len = @max(n, 1);
            return .{
                .ar = try allocator.alloc(T, len),
                .ai = try allocator.alloc(T, len),
                .b = try allocator.alloc(T, len),
                .allocator = allocator,
            };
        }

        fn deinit(self: Self) void {
            self.allocator.free(self.ar);
            self.allocator.free(self.ai);
            self.allocator.free(self.b);
        }

        fn gather(self: Self, n: usize, w: []GeneralizedEigenvalue(T)) void {
            if (comptime complexElement(T)) {
                for (0..n) |i| w[i] = .{ .alpha = @bitCast(self.ar[i]), .beta = @bitCast(self.b[i]) };
            } else {
                for (0..n) |i| w[i] = .{
                    .alpha = .{ .re = self.ar[i], .im = self.ai[i] },
                    .beta = .{ .re = self.b[i], .im = 0 },
                };
            }
        }
    };
}

/// A predicate deciding which generalized eigenvalues get sorted to the leading
/// block.
///
/// Takes the `(alpha, beta)` pair rather than a ratio, so an infinite
/// eigenvalue is representable. Use `value()` on it if you want the ratio and
/// are prepared for null.
pub fn SelectFn(comptime T: type) type {
    return *const fn (GeneralizedEigenvalue(T)) bool;
}

// Same threadlocal trick as `eigen_gen.gees`, for the same reason: the LAPACK
// callback carries no context pointer, and it is invoked synchronously on the
// calling thread inside the call that installed the hook.
threadlocal var select_hook: ?*const anyopaque = null;

fn Trampoline(comptime T: type) type {
    return struct {
        fn real(ar: [*]T, ai: [*]T, b: [*]T) callconv(.c) Bool {
            const f: SelectFn(T) = @ptrCast(@alignCast(select_hook.?));
            return if (f(.{
                .alpha = .{ .re = ar[0], .im = ai[0] },
                .beta = .{ .re = b[0], .im = 0 },
            })) 1 else 0;
        }
        fn complex(a: [*]T, b: [*]T) callconv(.c) Bool {
            const f: SelectFn(T) = @ptrCast(@alignCast(select_hook.?));
            return if (f(.{ .alpha = @bitCast(a[0]), .beta = @bitCast(b[0]) })) 1 else 0;
        }
    };
}

/// LAPACK's selection mask as an array of Fortran logicals. Same shape as the
/// one in `eigen_gen.zig`; the generalized routines only ever read it.
const SelectMask = struct {
    buf: []Bool,
    allocator: Allocator,

    fn init(allocator: Allocator, mask: []const bool) !SelectMask {
        const buf = try allocator.alloc(Bool, @max(mask.len, 1));
        for (mask, 0..) |v, i| buf[i] = if (v) 1 else 0;
        return .{ .buf = buf, .allocator = allocator };
    }

    fn deinit(self: SelectMask) void {
        self.allocator.free(self.buf);
    }
};

fn logical(value: bool) Bool {
    return if (value) 1 else 0;
}

// ============================================================================
// Balancing
// ============================================================================

/// `reduce.gebal` for a matrix pair.
///
/// Permutes and scales `(A, B)` together, so the pencil's eigenvalues are
/// unchanged. Two scale vectors come back rather than one — `lscale` for the
/// rows and `lscale`-side transform, `rscale` for the columns — because the two
/// sides are transformed independently here, unlike the similarity `gebal`
/// applies.
///
/// Both arrays need `n` entries, and both go to `ggbak` afterwards. As with
/// `gebal`, the eigenvalues survive balancing and the eigenvectors do not.
pub fn ggbal(
    comptime T: type,
    allocator: Allocator,
    job: Balance,
    n: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    lscale: []Real(T),
    rscale: []Real(T),
) Fail!Window {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, n, ldb);
    std.debug.assert(lscale.len >= n and rscale.len >= n);

    const work = try allocator.alloc(Real(T), @max(6 * n, 1));
    defer allocator.free(work);

    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    var ilo: Int = 0;
    var ihi: Int = 0;
    var info: Int = 0;

    sym(T, "ggbal")(opt(job), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), out(&ilo), out(&ihi), lscale.ptr, rscale.ptr, work.ptr, out(&info));
    try info_mod.checkArgs(info);
    return .{ .ilo = @intCast(ilo), .ihi = @intCast(ihi) };
}

/// Undoes `ggbal` on a set of eigenvectors.
///
/// `side` says whether `v` holds left or right eigenvectors; they use different
/// scale vectors, so passing the wrong one silently returns the wrong answer.
pub fn ggbak(
    comptime T: type,
    job: Balance,
    side: Side,
    n: usize,
    ilo: usize,
    ihi: usize,
    lscale: []const Real(T),
    rscale: []const Real(T),
    m: usize,
    v: []T,
    ldv: usize,
) Error!void {
    std.debug.assert(lscale.len >= n and rscale.len >= n);
    assertMatrix(v.len, n, m, ldv);

    const n_ = dim(n);
    const ilo_ = dim(ilo);
    const ihi_ = dim(ihi);
    const m_ = dim(m);
    const ldv_ = dim(@max(ldv, 1));
    var info: Int = 0;

    sym(T, "ggbak")(opt(job), opt(side), ref(&n_), ref(&ilo_), ref(&ihi_), lscale.ptr, rscale.ptr, ref(&m_), v.ptr, ref(&ldv_), out(&info));
    return info_mod.checkArgs(info);
}

// ============================================================================
// Reduction to Hessenberg-triangular form
// ============================================================================

/// Reduces a pair to Hessenberg-triangular form: `Q^H A Z` upper Hessenberg,
/// `Q^H B Z` upper triangular.
///
/// **`B` must already be upper triangular on entry.** Getting it there is a QR
/// factorization of `B` with `Q` applied to `A`, which this routine does not do
/// — `gges` does it internally, and calling `gghd3` on a general `B` produces
/// nonsense with no diagnostic.
///
/// `compq` and `compz` behave like `hseqr`'s: `.identity` starts from the
/// identity, `.accumulate` from whatever is already in `q`/`z`, which is how
/// you fold in the QR factorization that made `B` triangular.
///
/// This is the blocked implementation; `gghrd` is the unblocked one.
pub fn gghd3(
    comptime T: type,
    allocator: Allocator,
    compq: SchurVectors,
    compz: SchurVectors,
    n: usize,
    ilo: usize,
    ihi: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    q: []T,
    ldq: usize,
    z: []T,
    ldz: usize,
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, n, ldb);
    if (compq != .none) assertMatrix(q.len, n, n, ldq);
    if (compz != .none) assertMatrix(z.len, n, n, ldz);

    const n_ = dim(n);
    const ilo_ = dim(ilo);
    const ihi_ = dim(ihi);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldq_ = dim(@max(ldq, 1));
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, "gghd3")(opt(compq), opt(compz), ref(&n_), ref(&ilo_), ref(&ihi_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), q.ptr, ref(&ldq_), z.ptr, ref(&ldz_), &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, "gghd3")(opt(compq), opt(compz), ref(&n_), ref(&ilo_), ref(&ihi_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), q.ptr, ref(&ldq_), z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// The unblocked `gghd3`. Same result and same preconditions, no workspace.
pub fn gghrd(
    comptime T: type,
    compq: SchurVectors,
    compz: SchurVectors,
    n: usize,
    ilo: usize,
    ihi: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    q: []T,
    ldq: usize,
    z: []T,
    ldz: usize,
) Error!void {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, n, ldb);
    if (compq != .none) assertMatrix(q.len, n, n, ldq);
    if (compz != .none) assertMatrix(z.len, n, n, ldz);

    const n_ = dim(n);
    const ilo_ = dim(ilo);
    const ihi_ = dim(ihi);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldq_ = dim(@max(ldq, 1));
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    sym(T, "gghrd")(opt(compq), opt(compz), ref(&n_), ref(&ilo_), ref(&ihi_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), q.ptr, ref(&ldq_), z.ptr, ref(&ldz_), out(&info));
    return info_mod.checkArgs(info);
}

/// The QZ iteration: generalized eigenvalues, and optionally the generalized
/// Schur form, of a Hessenberg-triangular pair.
///
/// The generalized `hseqr`. `h` must be upper Hessenberg and `t` upper
/// triangular, as `gghd3` leaves them.
///
/// `error.NoConvergence` with `lastInfo()` in `1 .. n` means the iteration
/// failed; in `n+1 .. 2n` it means the *balancing* stage failed, at index
/// `lastInfo() - n`.
pub fn hgeqz(
    comptime T: type,
    allocator: Allocator,
    job: SchurJob,
    compq: SchurVectors,
    compz: SchurVectors,
    n: usize,
    ilo: usize,
    ihi: usize,
    h: []T,
    ldh: usize,
    t: []T,
    ldt: usize,
    w: []GeneralizedEigenvalue(T),
    q: []T,
    ldq: usize,
    z: []T,
    ldz: usize,
) Fail!void {
    assertMatrix(h.len, n, n, ldh);
    assertMatrix(t.len, n, n, ldt);
    std.debug.assert(w.len >= n);
    if (compq != .none) assertMatrix(q.len, n, n, ldq);
    if (compz != .none) assertMatrix(z.len, n, n, ldz);

    const alphas = try Alphas(T).init(allocator, n);
    defer alphas.deinit();

    const n_ = dim(n);
    const ilo_ = dim(ilo);
    const ihi_ = dim(ihi);
    const ldh_ = dim(@max(ldh, 1));
    const ldt_ = dim(@max(ldt, 1));
    const ldq_ = dim(@max(ldq, 1));
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        sym(T, "hgeqz")(opt(job), opt(compq), opt(compz), ref(&n_), ref(&ilo_), ref(&ihi_), &probe, ref(&ldh_), &probe, ref(&ldt_), &probe, &probe, &probe, ref(&ldq_), &probe, ref(&ldz_), &wq, ref(&neg), &rprobe, out(&info));
    } else {
        sym(T, "hgeqz")(opt(job), opt(compq), opt(compz), ref(&n_), ref(&ilo_), ref(&ihi_), &probe, ref(&ldh_), &probe, ref(&ldt_), &probe, &probe, &probe, &probe, ref(&ldq_), &probe, ref(&ldz_), &wq, ref(&neg), out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexElement(T)) {
        const rwork = try allocator.alloc(Real(T), @max(n, 1));
        defer allocator.free(rwork);
        sym(T, "hgeqz")(opt(job), opt(compq), opt(compz), ref(&n_), ref(&ilo_), ref(&ihi_), h.ptr, ref(&ldh_), t.ptr, ref(&ldt_), alphas.ar.ptr, alphas.b.ptr, q.ptr, ref(&ldq_), z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), rwork.ptr, out(&info));
    } else {
        sym(T, "hgeqz")(opt(job), opt(compq), opt(compz), ref(&n_), ref(&ilo_), ref(&ihi_), h.ptr, ref(&ldh_), t.ptr, ref(&ldt_), alphas.ar.ptr, alphas.ai.ptr, alphas.b.ptr, q.ptr, ref(&ldq_), z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), out(&info));
    }
    try info_mod.checkConvergence(info);
    alphas.gather(n, w);
}

// ============================================================================
// Drivers
// ============================================================================

/// Generalized Schur factorization `A = Q S Z^H`, `B = Q T Z^H`.
///
/// The pencil analogue of `gees`: `a` and `b` are overwritten with the
/// generalized Schur form, `vsl` and `vsr` with the two vector matrices.
///
/// Pass `select` to sort the accepted eigenvalues to the leading block, which
/// is how you extract a deflating subspace. `selected` reports how many there
/// were.
///
/// This is the blocked implementation; `gges` is the unblocked one and is
/// otherwise identical.
pub fn gges3(
    comptime T: type,
    allocator: Allocator,
    jobvsl: Job,
    jobvsr: Job,
    select: ?SelectFn(T),
    n: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    w: []GeneralizedEigenvalue(T),
    vsl: []T,
    ldvsl: usize,
    vsr: []T,
    ldvsr: usize,
) Fail!eigen_gen.SchurResult {
    return generalizedSchur(T, "gges3", allocator, jobvsl, jobvsr, select, n, a, lda, b, ldb, w, vsl, ldvsl, vsr, ldvsr);
}

/// The unblocked `gges3`.
pub fn gges(
    comptime T: type,
    allocator: Allocator,
    jobvsl: Job,
    jobvsr: Job,
    select: ?SelectFn(T),
    n: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    w: []GeneralizedEigenvalue(T),
    vsl: []T,
    ldvsl: usize,
    vsr: []T,
    ldvsr: usize,
) Fail!eigen_gen.SchurResult {
    return generalizedSchur(T, "gges", allocator, jobvsl, jobvsr, select, n, a, lda, b, ldb, w, vsl, ldvsl, vsr, ldvsr);
}

fn generalizedSchur(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    jobvsl: Job,
    jobvsr: Job,
    select: ?SelectFn(T),
    n: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    w: []GeneralizedEigenvalue(T),
    vsl: []T,
    ldvsl: usize,
    vsr: []T,
    ldvsr: usize,
) Fail!eigen_gen.SchurResult {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, n, ldb);
    std.debug.assert(w.len >= n);
    if (jobvsl == .vectors) assertMatrix(vsl.len, n, n, ldvsl);
    if (jobvsr == .vectors) assertMatrix(vsr.len, n, n, ldvsr);

    const alphas = try Alphas(T).init(allocator, n);
    defer alphas.deinit();
    const bwork = try allocator.alloc(Bool, @max(n, 1));
    defer allocator.free(bwork);

    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldvsl_ = dim(@max(ldvsl, 1));
    const ldvsr_ = dim(@max(ldvsr, 1));
    const sort: Sort = if (select == null) .unsorted else .sorted;
    var sdim: Int = 0;
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        sym(T, name)(opt(jobvsl), opt(jobvsr), opt(sort), null, ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), out(&sdim), &probe, &probe, &probe, ref(&ldvsl_), &probe, ref(&ldvsr_), &wq, ref(&neg), &rprobe, null, out(&info));
    } else {
        sym(T, name)(opt(jobvsl), opt(jobvsr), opt(sort), null, ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), out(&sdim), &probe, &probe, &probe, &probe, ref(&ldvsl_), &probe, ref(&ldvsr_), &wq, ref(&neg), null, out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    const previous = select_hook;
    defer select_hook = previous;
    select_hook = if (select) |f| @ptrCast(f) else null;

    if (comptime complexElement(T)) {
        const callback = if (select == null) null else &Trampoline(T).complex;
        const rwork = try allocator.alloc(Real(T), @max(8 * n, 1));
        defer allocator.free(rwork);
        sym(T, name)(opt(jobvsl), opt(jobvsr), opt(sort), callback, ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), out(&sdim), alphas.ar.ptr, alphas.b.ptr, vsl.ptr, ref(&ldvsl_), vsr.ptr, ref(&ldvsr_), buf.ptr, ref(&lwork), rwork.ptr, bwork.ptr, out(&info));
    } else {
        const callback = if (select == null) null else &Trampoline(T).real;
        sym(T, name)(opt(jobvsl), opt(jobvsr), opt(sort), callback, ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), out(&sdim), alphas.ar.ptr, alphas.ai.ptr, alphas.b.ptr, vsl.ptr, ref(&ldvsl_), vsr.ptr, ref(&ldvsr_), buf.ptr, ref(&lwork), bwork.ptr, out(&info));
    }
    try info_mod.checkConvergence(info);
    alphas.gather(n, w);
    return .{ .selected = @intCast(sdim) };
}

/// What `ggesx` computed besides the Schur form.
pub const ExpertGeneralizedSchur = struct {
    /// How many eigenvalues the predicate selected.
    selected: usize,
    /// Reciprocal condition numbers of the average of the selected cluster:
    /// `[0]` for the left deflating subspace, `[1]` for the right.
    cluster_condition: [2]f64,
    /// Estimated reciprocal condition numbers of the two deflating subspaces,
    /// left and right.
    subspace_condition: [2]f64,
    /// True when `info` came back as `n + 3`: reordering succeeded but roundoff
    /// made the cluster inseparable, so the condition numbers may be wrong.
    condition_unreliable: bool,
};

/// `gges` with condition numbers for the selected cluster and its deflating
/// subspaces.
///
/// Two of each, because the generalized problem has a left and a right
/// deflating subspace where the standard one has a single invariant subspace.
///
/// As with `geesx`, `sense` other than `.none` requires a `select` predicate.
pub fn ggesx(
    comptime T: type,
    allocator: Allocator,
    jobvsl: Job,
    jobvsr: Job,
    select: ?SelectFn(T),
    sense: Sense,
    n: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    w: []GeneralizedEigenvalue(T),
    vsl: []T,
    ldvsl: usize,
    vsr: []T,
    ldvsr: usize,
) Fail!ExpertGeneralizedSchur {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, n, ldb);
    std.debug.assert(w.len >= n);
    if (jobvsl == .vectors) assertMatrix(vsl.len, n, n, ldvsl);
    if (jobvsr == .vectors) assertMatrix(vsr.len, n, n, ldvsr);
    if (sense != .none) std.debug.assert(select != null);

    const alphas = try Alphas(T).init(allocator, n);
    defer alphas.deinit();
    const bwork = try allocator.alloc(Bool, @max(n, 1));
    defer allocator.free(bwork);

    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldvsl_ = dim(@max(ldvsl, 1));
    const ldvsr_ = dim(@max(ldvsr, 1));
    const sort: Sort = if (select == null) .unsorted else .sorted;
    var sdim: Int = 0;
    var rconde: [2]Real(T) = .{ 0, 0 };
    var rcondv: [2]Real(T) = .{ 0, 0 };
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    var iq: [1]Int = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        sym(T, "ggesx")(opt(jobvsl), opt(jobvsr), opt(sort), null, opt(sense), ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), out(&sdim), &probe, &probe, &probe, ref(&ldvsl_), &probe, ref(&ldvsr_), &rconde, &rcondv, &wq, ref(&neg), &rprobe, &iq, ref(&neg), null, out(&info));
    } else {
        sym(T, "ggesx")(opt(jobvsl), opt(jobvsr), opt(sort), null, opt(sense), ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), out(&sdim), &probe, &probe, &probe, &probe, ref(&ldvsl_), &probe, ref(&ldvsr_), &rconde, &rcondv, &wq, ref(&neg), &iq, ref(&neg), null, out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);
    const iwork = try allocator.alloc(Int, @intCast(@max(iq[0], 1)));
    defer allocator.free(iwork);
    const liwork = dim(iwork.len);

    const previous = select_hook;
    defer select_hook = previous;
    select_hook = if (select) |f| @ptrCast(f) else null;

    if (comptime complexElement(T)) {
        const callback = if (select == null) null else &Trampoline(T).complex;
        const rwork = try allocator.alloc(Real(T), @max(8 * n, 1));
        defer allocator.free(rwork);
        sym(T, "ggesx")(opt(jobvsl), opt(jobvsr), opt(sort), callback, opt(sense), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), out(&sdim), alphas.ar.ptr, alphas.b.ptr, vsl.ptr, ref(&ldvsl_), vsr.ptr, ref(&ldvsr_), &rconde, &rcondv, buf.ptr, ref(&lwork), rwork.ptr, iwork.ptr, ref(&liwork), bwork.ptr, out(&info));
    } else {
        const callback = if (select == null) null else &Trampoline(T).real;
        sym(T, "ggesx")(opt(jobvsl), opt(jobvsr), opt(sort), callback, opt(sense), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), out(&sdim), alphas.ar.ptr, alphas.ai.ptr, alphas.b.ptr, vsl.ptr, ref(&ldvsl_), vsr.ptr, ref(&ldvsr_), &rconde, &rcondv, buf.ptr, ref(&lwork), iwork.ptr, ref(&liwork), bwork.ptr, out(&info));
    }

    const unreliable = info == @as(Int, @intCast(n)) + 3;
    if (!unreliable) try info_mod.checkConvergence(info);
    alphas.gather(n, w);
    return .{
        .selected = @intCast(sdim),
        .cluster_condition = .{ rconde[0], rconde[1] },
        .subspace_condition = .{ rcondv[0], rcondv[1] },
        .condition_unreliable = unreliable,
    };
}

/// `eigen_gen.ggev`, blocked. Same result; prefer it for large `n`.
pub fn ggev3(
    comptime T: type,
    allocator: Allocator,
    jobvl: Job,
    jobvr: Job,
    n: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    w: []GeneralizedEigenvalue(T),
    vl: []T,
    ldvl: usize,
    vr: []T,
    ldvr: usize,
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, n, ldb);
    std.debug.assert(w.len >= n);
    if (jobvl == .vectors) assertMatrix(vl.len, n, n, ldvl);
    if (jobvr == .vectors) assertMatrix(vr.len, n, n, ldvr);

    const alphas = try Alphas(T).init(allocator, n);
    defer alphas.deinit();

    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldvl_ = dim(@max(ldvl, 1));
    const ldvr_ = dim(@max(ldvr, 1));
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        sym(T, "ggev3")(opt(jobvl), opt(jobvr), ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), &probe, &probe, &probe, ref(&ldvl_), &probe, ref(&ldvr_), &wq, ref(&neg), &rprobe, out(&info));
    } else {
        sym(T, "ggev3")(opt(jobvl), opt(jobvr), ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), &probe, &probe, &probe, &probe, ref(&ldvl_), &probe, ref(&ldvr_), &wq, ref(&neg), out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexElement(T)) {
        const rwork = try allocator.alloc(Real(T), @max(8 * n, 1));
        defer allocator.free(rwork);
        sym(T, "ggev3")(opt(jobvl), opt(jobvr), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), alphas.ar.ptr, alphas.b.ptr, vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), buf.ptr, ref(&lwork), rwork.ptr, out(&info));
    } else {
        sym(T, "ggev3")(opt(jobvl), opt(jobvr), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), alphas.ar.ptr, alphas.ai.ptr, alphas.b.ptr, vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), buf.ptr, ref(&lwork), out(&info));
    }
    try info_mod.checkConvergence(info);
    alphas.gather(n, w);
}

/// What `ggevx` computed besides the eigenvalues.
pub const ExpertGeneralizedEigen = struct {
    /// The window `ggbal` left, 1-based inclusive.
    window: Window,
    /// 1-norm of the balanced `A`.
    a_norm: f64,
    /// 1-norm of the balanced `B`.
    b_norm: f64,
};

/// `ggev` with balancing and per-eigenvalue condition numbers.
///
/// The generalized `geevx`. `rconde[i]` conditions eigenvalue `i` and
/// `rcondv[i]` its eigenvector; both need `n` entries. As with `geevx`,
/// `sense = .eigenvalues` or `.both` requires both sets of eigenvectors.
///
/// These are the same numbers `tgsna` computes, with the same caveat: they are
/// **not** bounded by 1 the way `geevx`'s are.
pub fn ggevx(
    comptime T: type,
    allocator: Allocator,
    balance: Balance,
    jobvl: Job,
    jobvr: Job,
    sense: Sense,
    n: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    w: []GeneralizedEigenvalue(T),
    vl: []T,
    ldvl: usize,
    vr: []T,
    ldvr: usize,
    lscale: []Real(T),
    rscale: []Real(T),
    rconde: []Real(T),
    rcondv: []Real(T),
) Fail!ExpertGeneralizedEigen {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, n, ldb);
    std.debug.assert(w.len >= n);
    std.debug.assert(lscale.len >= n and rscale.len >= n);
    if (jobvl == .vectors) assertMatrix(vl.len, n, n, ldvl);
    if (jobvr == .vectors) assertMatrix(vr.len, n, n, ldvr);
    if (sense == .eigenvalues or sense == .both) {
        std.debug.assert(jobvl == .vectors and jobvr == .vectors);
        std.debug.assert(rconde.len >= n);
    }
    if (sense == .eigenvectors or sense == .both) std.debug.assert(rcondv.len >= n);

    const alphas = try Alphas(T).init(allocator, n);
    defer alphas.deinit();
    const bwork = try allocator.alloc(Bool, @max(n, 1));
    defer allocator.free(bwork);
    const iwork = try allocator.alloc(Int, @max(n + 6, 1));
    defer allocator.free(iwork);

    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldvl_ = dim(@max(ldvl, 1));
    const ldvr_ = dim(@max(ldvr, 1));
    var ilo: Int = 0;
    var ihi: Int = 0;
    var abnrm: Real(T) = 0;
    var bbnrm: Real(T) = 0;
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var iprobe: [1]Int = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        sym(T, "ggevx")(opt(balance), opt(jobvl), opt(jobvr), opt(sense), ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), &probe, &probe, &probe, ref(&ldvl_), &probe, ref(&ldvr_), out(&ilo), out(&ihi), &rprobe, &rprobe, out(&abnrm), out(&bbnrm), &rprobe, &rprobe, &wq, ref(&neg), &rprobe, &iprobe, null, out(&info));
    } else {
        sym(T, "ggevx")(opt(balance), opt(jobvl), opt(jobvr), opt(sense), ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), &probe, &probe, &probe, &probe, ref(&ldvl_), &probe, ref(&ldvr_), out(&ilo), out(&ihi), &rprobe, &rprobe, out(&abnrm), out(&bbnrm), &rprobe, &rprobe, &wq, ref(&neg), &iprobe, null, out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexElement(T)) {
        const rwork = try allocator.alloc(Real(T), @max(6 * n, 1));
        defer allocator.free(rwork);
        sym(T, "ggevx")(opt(balance), opt(jobvl), opt(jobvr), opt(sense), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), alphas.ar.ptr, alphas.b.ptr, vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), out(&ilo), out(&ihi), lscale.ptr, rscale.ptr, out(&abnrm), out(&bbnrm), rconde.ptr, rcondv.ptr, buf.ptr, ref(&lwork), rwork.ptr, iwork.ptr, bwork.ptr, out(&info));
    } else {
        sym(T, "ggevx")(opt(balance), opt(jobvl), opt(jobvr), opt(sense), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), alphas.ar.ptr, alphas.ai.ptr, alphas.b.ptr, vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), out(&ilo), out(&ihi), lscale.ptr, rscale.ptr, out(&abnrm), out(&bbnrm), rconde.ptr, rcondv.ptr, buf.ptr, ref(&lwork), iwork.ptr, bwork.ptr, out(&info));
    }
    try info_mod.checkConvergence(info);
    alphas.gather(n, w);
    return .{
        .window = .{ .ilo = @intCast(ilo), .ihi = @intCast(ihi) },
        .a_norm = abnrm,
        .b_norm = bbnrm,
    };
}

// ============================================================================
// Working on a generalized Schur form
// ============================================================================

/// Eigenvectors of a pair in generalized Schur form.
///
/// The generalized `trevc3`. `s` and `p` are the two Schur factors, and with
/// `howmny = .backtransform` the vector arrays must hold `Q` and `Z` on entry
/// and come back holding eigenvectors of the original pencil.
pub fn tgevc(
    comptime T: type,
    allocator: Allocator,
    side: types.EigSide,
    howmny: HowMany,
    select: []const bool,
    n: usize,
    s: []const T,
    lds: usize,
    p: []const T,
    ldp: usize,
    vl: []T,
    ldvl: usize,
    vr: []T,
    ldvr: usize,
    mm: usize,
) Fail!usize {
    assertMatrix(s.len, n, n, lds);
    assertMatrix(p.len, n, n, ldp);
    if (howmny == .selected) std.debug.assert(select.len >= n);

    const mask = try SelectMask.init(allocator, if (howmny == .selected) select else &.{});
    defer mask.deinit();

    const n_ = dim(n);
    const lds_ = dim(@max(lds, 1));
    const ldp_ = dim(@max(ldp, 1));
    const ldvl_ = dim(@max(ldvl, 1));
    const ldvr_ = dim(@max(ldvr, 1));
    const mm_ = dim(mm);
    var m: Int = 0;
    var info: Int = 0;

    if (comptime complexElement(T)) {
        const buf = try allocator.alloc(T, @max(2 * n, 1));
        defer allocator.free(buf);
        const rwork = try allocator.alloc(Real(T), @max(2 * n, 1));
        defer allocator.free(rwork);
        sym(T, "tgevc")(opt(side), opt(howmny), mask.buf.ptr, ref(&n_), s.ptr, ref(&lds_), p.ptr, ref(&ldp_), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), ref(&mm_), out(&m), buf.ptr, rwork.ptr, out(&info));
    } else {
        const buf = try allocator.alloc(T, @max(6 * n, 1));
        defer allocator.free(buf);
        sym(T, "tgevc")(opt(side), opt(howmny), mask.buf.ptr, ref(&n_), s.ptr, ref(&lds_), p.ptr, ref(&ldp_), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), ref(&mm_), out(&m), buf.ptr, out(&info));
    }
    try info_mod.checkArgs(info);
    return @intCast(m);
}

/// Moves one diagonal block of a generalized Schur form.
///
/// The generalized `trexc`, and the one place in this binding where the "do you
/// want the vectors" flags are Fortran logicals rather than option characters.
///
/// As with `trexc`, a real 2x2 block cannot be split, so the returned positions
/// may differ from the requested ones.
///
/// `error.Degenerate` means the blocks are too close to swap; nothing was moved
/// and both matrices are unchanged.
pub fn tgexc(
    comptime T: type,
    allocator: Allocator,
    want_q: bool,
    want_z: bool,
    n: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    q: []T,
    ldq: usize,
    z: []T,
    ldz: usize,
    ifst: usize,
    ilst: usize,
) Fail!ReorderResult {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, n, ldb);
    if (want_q) assertMatrix(q.len, n, n, ldq);
    if (want_z) assertMatrix(z.len, n, n, ldz);

    const wantq = logical(want_q);
    const wantz = logical(want_z);
    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldq_ = dim(@max(ldq, 1));
    const ldz_ = dim(@max(ldz, 1));
    var ifst_ = dim(ifst);
    var ilst_ = dim(ilst);
    var info: Int = 0;

    if (comptime complexElement(T)) {
        sym(T, "tgexc")(ref(&wantq), ref(&wantz), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), q.ptr, ref(&ldq_), z.ptr, ref(&ldz_), ref(&ifst_), ref(&ilst_), out(&info));
    } else {
        var wq: [1]T = undefined;
        const neg = work_mod.query;
        sym(T, "tgexc")(ref(&wantq), ref(&wantz), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), q.ptr, ref(&ldq_), z.ptr, ref(&ldz_), out(&ifst_), out(&ilst_), &wq, ref(&neg), out(&info));
        try info_mod.checkArgs(info);

        const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
        const buf = try allocator.alloc(T, size);
        defer allocator.free(buf);
        const lwork = dim(size);
        ifst_ = dim(ifst);
        ilst_ = dim(ilst);
        sym(T, "tgexc")(ref(&wantq), ref(&wantz), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), q.ptr, ref(&ldq_), z.ptr, ref(&ldz_), out(&ifst_), out(&ilst_), buf.ptr, ref(&lwork), out(&info));
    }
    try info_mod.checkDegenerate(info);
    return .{ .from = @intCast(ifst_), .to = @intCast(ilst_) };
}

/// What `tgsen` computed.
pub const GeneralizedReorder = struct {
    /// Order of the leading block after reordering.
    selected: usize,
    /// Reciprocal condition number of the selected cluster of eigenvalues.
    cluster_condition: f64,
    /// Estimated reciprocal condition numbers of the left and right deflating
    /// subspaces, written only for `ijob` 2, 4 or 5.
    subspace_condition: [2]f64,
    /// True when `info` came back as `1`: the reordering failed because the
    /// blocks were too close, so the pair is back to a valid generalized Schur
    /// form of a differently ordered problem.
    reorder_failed: bool,
};

/// How much work `tgsen` should do.
///
/// The condition estimates are the expensive part, and LAPACK exposes five
/// levels rather than a yes/no.
pub const TgsenJob = enum(Int) {
    /// Reorder only.
    reorder = 0,
    /// Reorder and compute the cluster condition number and a *Frobenius-norm*
    /// estimate of the subspace conditions.
    reorder_and_estimate = 1,
    /// The same, but with a 1-norm estimate, which is more accurate and costs
    /// a Sylvester solve.
    reorder_and_estimate_one_norm = 2,
    /// The 1-norm estimate only, on a pair that is already ordered.
    estimate_only = 3,
    /// The Frobenius-norm estimate only.
    estimate_only_frobenius = 4,
    /// A cheaper 1-norm estimate without reordering.
    estimate_only_cheap = 5,
};

/// Reorders a generalized Schur form so the selected eigenvalues come first.
///
/// The generalized `trsen`. `want_q` and `want_z` say whether to update the two
/// vector matrices alongside.
pub fn tgsen(
    comptime T: type,
    allocator: Allocator,
    job: TgsenJob,
    want_q: bool,
    want_z: bool,
    select: []const bool,
    n: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    w: []GeneralizedEigenvalue(T),
    q: []T,
    ldq: usize,
    z: []T,
    ldz: usize,
) Fail!GeneralizedReorder {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, n, ldb);
    std.debug.assert(select.len >= n and w.len >= n);
    if (want_q) assertMatrix(q.len, n, n, ldq);
    if (want_z) assertMatrix(z.len, n, n, ldz);

    const mask = try SelectMask.init(allocator, select);
    defer mask.deinit();
    const alphas = try Alphas(T).init(allocator, n);
    defer alphas.deinit();

    const ijob: Int = @intFromEnum(job);
    const wantq = logical(want_q);
    const wantz = logical(want_z);
    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldq_ = dim(@max(ldq, 1));
    const ldz_ = dim(@max(ldz, 1));
    var m: Int = 0;
    var pl: Real(T) = 0;
    var pr: Real(T) = 0;
    var dif: [2]Real(T) = .{ 0, 0 };
    var info: Int = 0;

    var probe: [1]T = undefined;
    var wq: [1]T = undefined;
    var iq: [1]Int = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        sym(T, "tgsen")(ref(&ijob), ref(&wantq), ref(&wantz), mask.buf.ptr, ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), &probe, &probe, &probe, ref(&ldq_), &probe, ref(&ldz_), out(&m), out(&pl), out(&pr), &dif, &wq, ref(&neg), &iq, ref(&neg), out(&info));
    } else {
        sym(T, "tgsen")(ref(&ijob), ref(&wantq), ref(&wantz), mask.buf.ptr, ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), &probe, &probe, &probe, &probe, ref(&ldq_), &probe, ref(&ldz_), out(&m), out(&pl), out(&pr), &dif, &wq, ref(&neg), &iq, ref(&neg), out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);
    const iwork = try allocator.alloc(Int, @intCast(@max(iq[0], 1)));
    defer allocator.free(iwork);
    const liwork = dim(iwork.len);

    if (comptime complexElement(T)) {
        sym(T, "tgsen")(ref(&ijob), ref(&wantq), ref(&wantz), mask.buf.ptr, ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), alphas.ar.ptr, alphas.b.ptr, q.ptr, ref(&ldq_), z.ptr, ref(&ldz_), out(&m), out(&pl), out(&pr), &dif, buf.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
    } else {
        sym(T, "tgsen")(ref(&ijob), ref(&wantq), ref(&wantz), mask.buf.ptr, ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), alphas.ar.ptr, alphas.ai.ptr, alphas.b.ptr, q.ptr, ref(&ldq_), z.ptr, ref(&ldz_), out(&m), out(&pl), out(&pr), &dif, buf.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
    }

    const failed = info == 1;
    if (!failed) try info_mod.checkArgs(info);
    alphas.gather(n, w);
    return .{
        .selected = @intCast(m),
        .cluster_condition = pl,
        .subspace_condition = .{ dif[0], dif[1] },
        .reorder_failed = failed,
    };
}

/// Condition numbers for individual generalized eigenvalues and eigenvectors.
///
/// The generalized `trsna`. `s[i]` conditions eigenvalue `i`, `dif[i]` its
/// eigenvector. `vl` and `vr` must hold the left and right eigenvectors from
/// `tgevc`.
///
/// **`s[i]` is not bounded by 1**, unlike `trsna`'s. It is a chordal-distance
/// condition number against an unnormalized pencil, so a value above 1 is
/// ordinary — measured, a diagonal `(A, B)` with entries 2,3,4 and 1,2,3 gives
/// 1.49. Only the relative sizes are meaningful.
pub fn tgsna(
    comptime T: type,
    allocator: Allocator,
    job: Sense,
    howmny: HowMany,
    select: []const bool,
    n: usize,
    a: []const T,
    lda: usize,
    b: []const T,
    ldb: usize,
    vl: []const T,
    ldvl: usize,
    vr: []const T,
    ldvr: usize,
    s: []Real(T),
    dif: []Real(T),
    mm: usize,
) Fail!usize {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, n, ldb);
    if (howmny == .selected) std.debug.assert(select.len >= n);
    if (job != .eigenvectors) std.debug.assert(s.len >= mm);
    if (job != .eigenvalues) std.debug.assert(dif.len >= mm);

    const mask = try SelectMask.init(allocator, if (howmny == .selected) select else &.{});
    defer mask.deinit();

    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldvl_ = dim(@max(ldvl, 1));
    const ldvr_ = dim(@max(ldvr, 1));
    const mm_ = dim(mm);
    var m: Int = 0;
    var info: Int = 0;

    // The documented minimum is 2n(n+2)+16 for the real routine and 2n*n for
    // the complex one when eigenvector conditions are wanted; the larger is
    // always allocated rather than branching on `job`.
    const buf = try allocator.alloc(T, @max(2 * n * (n + 2) + 16, 1));
    defer allocator.free(buf);
    const lwork = dim(buf.len);
    const iwork = try allocator.alloc(Int, @max(n + 6, 1));
    defer allocator.free(iwork);

    if (comptime complexElement(T)) {
        sym(T, "tgsna")(opt(job), opt(howmny), mask.buf.ptr, ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), s.ptr, dif.ptr, ref(&mm_), out(&m), buf.ptr, ref(&lwork), iwork.ptr, out(&info));
    } else {
        sym(T, "tgsna")(opt(job), opt(howmny), mask.buf.ptr, ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), s.ptr, dif.ptr, ref(&mm_), out(&m), buf.ptr, ref(&lwork), iwork.ptr, out(&info));
    }
    try info_mod.checkArgs(info);
    return @intCast(m);
}

/// What `tgsyl` computed.
pub const GeneralizedSylvesterResult = struct {
    /// The scale factor applied to avoid overflow. A value below 1 means the
    /// returned `c` and `f` solve the *scaled* problem.
    scale: f64,
    /// Estimated reciprocal of the separation between the two pencils, written
    /// only for the estimating `ijob` values. Small means the solution is
    /// ill-conditioned.
    dif: f64,
};

/// The generalized Sylvester equations.
///
/// Solves the coupled pair
///
/// ```text
/// A R - L B = scale * C
/// D R - L E = scale * F
/// ```
///
/// for `R` and `L`, which overwrite `c` and `f`. `(A, D)` and `(B, E)` must
/// both be in generalized Schur form.
///
/// `ijob` selects between solving (0) and estimating the separation (1 through
/// 4); the estimating modes overwrite `c` and `f` with intermediates rather
/// than the solution, so 0 is what you want unless you specifically want `dif`.
///
/// `error.Degenerate` means the two pencils have a common eigenvalue, so the
/// equations have no unique solution.
pub fn tgsyl(
    comptime T: type,
    allocator: Allocator,
    trans: Trans,
    ijob: u3,
    m: usize,
    n: usize,
    a: []const T,
    lda: usize,
    b: []const T,
    ldb: usize,
    cm: []T,
    ldc: usize,
    d: []const T,
    ldd: usize,
    e: []const T,
    lde: usize,
    f: []T,
    ldf: usize,
) Fail!GeneralizedSylvesterResult {
    std.debug.assert(ijob <= 4);
    assertMatrix(a.len, m, m, lda);
    assertMatrix(b.len, n, n, ldb);
    assertMatrix(cm.len, m, n, ldc);
    assertMatrix(d.len, m, m, ldd);
    assertMatrix(e.len, n, n, lde);
    assertMatrix(f.len, m, n, ldf);

    const ijob_: Int = ijob;
    const m_ = dim(m);
    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldc_ = dim(@max(ldc, 1));
    const ldd_ = dim(@max(ldd, 1));
    const lde_ = dim(@max(lde, 1));
    const ldf_ = dim(@max(ldf, 1));
    var scale: Real(T) = 0;
    var dif: Real(T) = 0;
    var info: Int = 0;

    const iwork = try allocator.alloc(Int, @max(m + n + 6, 1));
    defer allocator.free(iwork);

    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, "tgsyl")(opt(trans), ref(&ijob_), ref(&m_), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), cm.ptr, ref(&ldc_), d.ptr, ref(&ldd_), e.ptr, ref(&lde_), f.ptr, ref(&ldf_), out(&scale), out(&dif), &wq, ref(&neg), iwork.ptr, out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, "tgsyl")(opt(trans), ref(&ijob_), ref(&m_), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), cm.ptr, ref(&ldc_), d.ptr, ref(&ldd_), e.ptr, ref(&lde_), f.ptr, ref(&ldf_), out(&scale), out(&dif), buf.ptr, ref(&lwork), iwork.ptr, out(&info));
    try info_mod.checkDegenerate(info);
    return .{ .scale = scale, .dif = dif };
}

// ============================================================================
// Generalized singular value decomposition
// ============================================================================

/// The block structure `ggsvd3` found.
///
/// The generalized singular values are `alpha[i] / beta[i]`, and `k + l` is the
/// effective rank of the stacked matrix `[A; B]`. The first `k` of them are
/// infinite (`beta = 0`), and the next `l` are the finite ones — which is why
/// both numbers come back rather than just the rank.
pub const GsvdResult = struct {
    /// Number of infinite generalized singular values.
    k: usize,
    /// Number of finite ones.
    l: usize,
};

/// Which vectors `tgsja` should form, and what `u`/`v`/`q` hold on entry.
///
/// The three arguments take *different* characters for the same meaning in
/// LAPACK — `'U'`, `'V'` and `'Q'` respectively — which is why this enum has no
/// backing character and the right one is chosen per argument.
pub const GsvdVectors = enum {
    /// Do not compute them.
    none,
    /// Start from the identity.
    identity,
    /// Start from what the array already holds, accumulating onto an earlier
    /// transformation.
    accumulate,
};

const Chars = enum(u8) { n = 'N', i = 'I', u = 'U', v = 'V', q = 'Q' };

fn gsvdChar(kind: GsvdVectors, comptime accumulate: Chars) [*]const u8 {
    return switch (kind) {
        .none => opt(Chars.n),
        .identity => opt(Chars.i),
        .accumulate => opt(accumulate),
    };
}

fn flagChar(wanted: bool, comptime yes: Chars) [*]const u8 {
    return if (wanted) opt(yes) else opt(Chars.n);
}

/// Generalized SVD of a pair: `A = U S1 [0 R] Q^H`, `B = V S2 [0 R] Q^H`.
///
/// Simultaneously diagonalizes `A` (`m x n`) and `B` (`p x n`) with a shared
/// right factor, giving the pairs `(alpha[i], beta[i])` whose ratios are the
/// generalized singular values. `alpha` and `beta` each need `n` entries.
///
/// **The extents are `m`, `n`, `p` here and `m`, `p`, `n` in `tgsja`.** The two
/// routines are the driver and its computational half; LAPACK orders their
/// arguments differently and nothing catches a swap. This binding keeps each
/// routine's own order rather than imposing one, because renaming would make
/// the LAPACK documentation harder to follow, but it is the mistake to look for
/// first when the answer is wrong.
///
/// `u`, `v` and `q` are only referenced when the corresponding flag is set.
pub fn ggsvd3(
    comptime T: type,
    allocator: Allocator,
    want_u: bool,
    want_v: bool,
    want_q: bool,
    m: usize,
    n: usize,
    p: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    alpha: []Real(T),
    beta: []Real(T),
    u: []T,
    ldu: usize,
    v: []T,
    ldv: usize,
    q: []T,
    ldq: usize,
) Fail!GsvdResult {
    assertMatrix(a.len, m, n, lda);
    assertMatrix(b.len, p, n, ldb);
    std.debug.assert(alpha.len >= n and beta.len >= n);
    if (want_u) assertMatrix(u.len, m, m, ldu);
    if (want_v) assertMatrix(v.len, p, p, ldv);
    if (want_q) assertMatrix(q.len, n, n, ldq);

    const iwork = try allocator.alloc(Int, @max(n, 1));
    defer allocator.free(iwork);

    const m_ = dim(m);
    const n_ = dim(n);
    const p_ = dim(p);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldu_ = dim(@max(ldu, 1));
    const ldv_ = dim(@max(ldv, 1));
    const ldq_ = dim(@max(ldq, 1));
    var k: Int = 0;
    var l: Int = 0;
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        sym(T, "ggsvd3")(flagChar(want_u, .u), flagChar(want_v, .v), flagChar(want_q, .q), ref(&m_), ref(&n_), ref(&p_), out(&k), out(&l), &probe, ref(&lda_), &probe, ref(&ldb_), &rprobe, &rprobe, &probe, ref(&ldu_), &probe, ref(&ldv_), &probe, ref(&ldq_), &wq, ref(&neg), &rprobe, iwork.ptr, out(&info));
    } else {
        sym(T, "ggsvd3")(flagChar(want_u, .u), flagChar(want_v, .v), flagChar(want_q, .q), ref(&m_), ref(&n_), ref(&p_), out(&k), out(&l), &probe, ref(&lda_), &probe, ref(&ldb_), &rprobe, &rprobe, &probe, ref(&ldu_), &probe, ref(&ldv_), &probe, ref(&ldq_), &wq, ref(&neg), iwork.ptr, out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexElement(T)) {
        const rwork = try allocator.alloc(Real(T), @max(2 * n, 1));
        defer allocator.free(rwork);
        sym(T, "ggsvd3")(flagChar(want_u, .u), flagChar(want_v, .v), flagChar(want_q, .q), ref(&m_), ref(&n_), ref(&p_), out(&k), out(&l), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), alpha.ptr, beta.ptr, u.ptr, ref(&ldu_), v.ptr, ref(&ldv_), q.ptr, ref(&ldq_), buf.ptr, ref(&lwork), rwork.ptr, iwork.ptr, out(&info));
    } else {
        sym(T, "ggsvd3")(flagChar(want_u, .u), flagChar(want_v, .v), flagChar(want_q, .q), ref(&m_), ref(&n_), ref(&p_), out(&k), out(&l), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), alpha.ptr, beta.ptr, u.ptr, ref(&ldu_), v.ptr, ref(&ldv_), q.ptr, ref(&ldq_), buf.ptr, ref(&lwork), iwork.ptr, out(&info));
    }
    try info_mod.checkConvergence(info);
    return .{ .k = @intCast(k), .l = @intCast(l) };
}

/// The Kogbetliantz iteration behind `ggsvd3`.
///
/// Takes a pair already preprocessed into the triangular form `ggsvd3` produces
/// internally, along with the `k` and `l` from that preprocessing, and runs the
/// iteration that produces the generalized singular values. Reach for it only
/// if you are doing the preprocessing yourself.
///
/// `tola` and `tolb` are the convergence thresholds; the documented choices are
/// `max(m, n) * ||A|| * eps` and `max(p, n) * ||B|| * eps`.
///
/// **Note the extent order: `m`, `p`, `n`, not `ggsvd3`'s `m`, `n`, `p`.**
///
/// Returns the number of cycles the iteration used. `error.NoConvergence` means
/// it hit its limit.
pub fn tgsja(
    comptime T: type,
    allocator: Allocator,
    jobu: GsvdVectors,
    jobv: GsvdVectors,
    jobq: GsvdVectors,
    m: usize,
    p: usize,
    n: usize,
    k: usize,
    l: usize,
    a: []T,
    lda: usize,
    b: []T,
    ldb: usize,
    tola: Real(T),
    tolb: Real(T),
    alpha: []Real(T),
    beta: []Real(T),
    u: []T,
    ldu: usize,
    v: []T,
    ldv: usize,
    q: []T,
    ldq: usize,
) Fail!usize {
    assertMatrix(a.len, m, n, lda);
    assertMatrix(b.len, p, n, ldb);
    std.debug.assert(alpha.len >= n and beta.len >= n);
    if (jobu != .none) assertMatrix(u.len, m, m, ldu);
    if (jobv != .none) assertMatrix(v.len, p, p, ldv);
    if (jobq != .none) assertMatrix(q.len, n, n, ldq);

    const work = try allocator.alloc(T, @max(2 * n, 1));
    defer allocator.free(work);

    const m_ = dim(m);
    const p_ = dim(p);
    const n_ = dim(n);
    const k_ = dim(k);
    const l_ = dim(l);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldu_ = dim(@max(ldu, 1));
    const ldv_ = dim(@max(ldv, 1));
    const ldq_ = dim(@max(ldq, 1));
    var ncycle: Int = 0;
    var info: Int = 0;

    sym(T, "tgsja")(gsvdChar(jobu, .u), gsvdChar(jobv, .v), gsvdChar(jobq, .q), ref(&m_), ref(&p_), ref(&n_), ref(&k_), ref(&l_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), ref(&tola), ref(&tolb), alpha.ptr, beta.ptr, u.ptr, ref(&ldu_), v.ptr, ref(&ldv_), q.ptr, ref(&ldq_), work.ptr, out(&ncycle), out(&info));
    try info_mod.checkConvergence(info);
    return @intCast(ncycle);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const qr = @import("qr.zig");
const norms = @import("norms.zig");

/// A 3x3 pencil with a singular `B`, so one eigenvalue is infinite. Every test
/// below uses it, which is the point: `beta = 0` is routine, not a corner case.
const pa = [_]f64{
    2, 0, 0,
    1, 3, 0,
    0, 1, 4,
};
const pb = [_]f64{
    1, 0, 0,
    0, 1, 0,
    0, 0, 0,
};

/// The finite eigenvalues of the pencil, from `eigen_gen.ggev` — a driver the
/// existing tests already cover, so the staged path below is checked against
/// something known good.
fn referenceFinite() ![2]f64 {
    var a = pa;
    var b = pb;
    var w: [3]GeneralizedEigenvalue(f64) = undefined;
    var dummy: [1]f64 = undefined;
    try eigen_gen.ggev(f64, testing.allocator, .values_only, .values_only, 3, &a, 3, &b, 3, &w, &dummy, 1, &dummy, 1);

    var finite: [2]f64 = undefined;
    var at: usize = 0;
    for (w) |v| {
        if (v.value()) |ratio| {
            if (at < 2) finite[at] = ratio.re;
            at += 1;
        }
    }
    try testing.expectEqual(@as(usize, 2), at);
    std.mem.sort(f64, &finite, {}, std.sort.asc(f64));
    return finite;
}

fn sortedFinite(w: []const GeneralizedEigenvalue(f64)) ![2]f64 {
    var finite: [2]f64 = undefined;
    var at: usize = 0;
    for (w) |v| {
        if (v.value()) |ratio| {
            if (at < 2) finite[at] = ratio.re;
            at += 1;
        }
    }
    try testing.expectEqual(@as(usize, 2), at);
    std.mem.sort(f64, &finite, {}, std.sort.asc(f64));
    return finite;
}

test "gghd3 then hgeqz reproduces what ggev computes in one call" {
    const reference = try referenceFinite();
    const n = 3;

    // B must be upper triangular before gghd3, which it already is here. In
    // general that costs a QR of B with Q applied to A.
    var a = pa;
    var b = pb;
    var q = [_]f64{0} ** (n * n);
    var z = [_]f64{0} ** (n * n);
    try gghd3(f64, testing.allocator, .identity, .identity, n, 1, n, &a, n, &b, n, &q, n, &z, n);

    var w: [n]GeneralizedEigenvalue(f64) = undefined;
    try hgeqz(f64, testing.allocator, .schur_form, .accumulate, .accumulate, n, 1, n, &a, n, &b, n, &w, &q, n, &z, n);

    const finite = try sortedFinite(&w);
    for (reference, finite) |x, y| try testing.expectApproxEqRel(x, y, 1e-10);

    // One eigenvalue is infinite, because B is singular.
    var infinite: usize = 0;
    for (w) |v| {
        if (v.isInfinite()) infinite += 1;
    }
    try testing.expectEqual(@as(usize, 1), infinite);
}

test "gghrd agrees with gghd3" {
    const n = 3;
    var a3 = pa;
    var b3 = pb;
    var q3 = [_]f64{0} ** (n * n);
    var z3 = [_]f64{0} ** (n * n);
    try gghd3(f64, testing.allocator, .identity, .identity, n, 1, n, &a3, n, &b3, n, &q3, n, &z3, n);

    var a1 = pa;
    var b1 = pb;
    var q1 = [_]f64{0} ** (n * n);
    var z1 = [_]f64{0} ** (n * n);
    try gghrd(f64, .identity, .identity, n, 1, n, &a1, n, &b1, n, &q1, n, &z1, n);

    for (a3, a1) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
    for (b3, b1) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "gges and gges3 produce the same generalized Schur form" {
    const n = 3;
    var a3 = pa;
    var b3 = pb;
    var w3: [n]GeneralizedEigenvalue(f64) = undefined;
    var l3: [n * n]f64 = undefined;
    var r3: [n * n]f64 = undefined;
    const res3 = try gges3(f64, testing.allocator, .vectors, .vectors, null, n, &a3, n, &b3, n, &w3, &l3, n, &r3, n);

    var a1 = pa;
    var b1 = pb;
    var w1: [n]GeneralizedEigenvalue(f64) = undefined;
    var l1: [n * n]f64 = undefined;
    var r1: [n * n]f64 = undefined;
    const res1 = try gges(f64, testing.allocator, .vectors, .vectors, null, n, &a1, n, &b1, n, &w1, &l1, n, &r1, n);

    try testing.expectEqual(res3.selected, res1.selected);
    try testing.expectEqual(@as(usize, 0), res1.selected);
    const f3 = try sortedFinite(&w3);
    const f1 = try sortedFinite(&w1);
    for (f3, f1) |x, y| try testing.expectApproxEqRel(x, y, 1e-12);

    // B comes back upper triangular, which is what "generalized Schur form"
    // means for the second matrix.
    for (0..n) |j| for (0..n) |i| {
        if (i > j) try testing.expectApproxEqAbs(@as(f64, 0), b1[i + j * n], 1e-12);
    };
}

fn selectFinite(value: GeneralizedEigenvalue(f64)) bool {
    return !value.isInfinite();
}

test "gges sorts the finite eigenvalues to the leading block" {
    const n = 3;
    var a = pa;
    var b = pb;
    var w: [n]GeneralizedEigenvalue(f64) = undefined;
    var vsl: [n * n]f64 = undefined;
    var vsr: [n * n]f64 = undefined;

    const res = try gges(f64, testing.allocator, .vectors, .vectors, selectFinite, n, &a, n, &b, n, &w, &vsl, n, &vsr, n);

    // Two finite, so the deflating subspace has dimension 2.
    try testing.expectEqual(@as(usize, 2), res.selected);
    try testing.expect(!w[0].isInfinite());
    try testing.expect(!w[1].isInfinite());
    try testing.expect(w[2].isInfinite());
}

test "the select predicate sees the alpha/beta pair, not a ratio" {
    const n = 3;
    var a = pa;
    var b = pb;
    var w: [n]GeneralizedEigenvalue(f64) = undefined;
    var vsl: [1]f64 = undefined;
    var vsr: [1]f64 = undefined;

    // Selecting on the ratio alone cannot express "infinite"; the pair can.
    const S = struct {
        fn infiniteOnly(value: GeneralizedEigenvalue(f64)) bool {
            return value.isInfinite();
        }
    };
    const res = try gges(f64, testing.allocator, .values_only, .values_only, S.infiniteOnly, n, &a, n, &b, n, &w, &vsl, 1, &vsr, 1);
    try testing.expectEqual(@as(usize, 1), res.selected);
    try testing.expect(w[0].isInfinite());
}

test "ggesx conditions both deflating subspaces" {
    const n = 3;
    var a = pa;
    var b = pb;
    var w: [n]GeneralizedEigenvalue(f64) = undefined;
    var vsl: [n * n]f64 = undefined;
    var vsr: [n * n]f64 = undefined;

    const res = try ggesx(f64, testing.allocator, .vectors, .vectors, selectFinite, .both, n, &a, n, &b, n, &w, &vsl, n, &vsr, n);

    try testing.expectEqual(@as(usize, 2), res.selected);
    try testing.expect(!res.condition_unreliable);
    // Two of each - a left and a right deflating subspace where the standard
    // problem has one invariant subspace.
    for (res.cluster_condition) |v| try testing.expect(v >= 0);
    for (res.subspace_condition) |v| try testing.expect(v >= 0);
}

test "ggev3 agrees with ggev" {
    const reference = try referenceFinite();
    const n = 3;
    var a = pa;
    var b = pb;
    var w: [n]GeneralizedEigenvalue(f64) = undefined;
    var vl: [1]f64 = undefined;
    var vr: [1]f64 = undefined;
    try ggev3(f64, testing.allocator, .values_only, .values_only, n, &a, n, &b, n, &w, &vl, 1, &vr, 1);

    const finite = try sortedFinite(&w);
    for (reference, finite) |x, y| try testing.expectApproxEqRel(x, y, 1e-12);
}

test "ggevx balances and conditions the pencil" {
    const n = 3;
    var a = pa;
    var b = [_]f64{
        1, 0, 0,
        0, 2, 0,
        0, 0, 3,
    };
    var w: [n]GeneralizedEigenvalue(f64) = undefined;
    var vl: [n * n]f64 = undefined;
    var vr: [n * n]f64 = undefined;
    var lscale: [n]f64 = undefined;
    var rscale: [n]f64 = undefined;
    var rconde: [n]f64 = undefined;
    var rcondv: [n]f64 = undefined;

    const res = try ggevx(f64, testing.allocator, .both, .vectors, .vectors, .both, n, &a, n, &b, n, &w, &vl, n, &vr, n, &lscale, &rscale, &rconde, &rcondv);

    try testing.expect(res.window.ilo >= 1 and res.window.ihi <= n);
    try testing.expect(res.a_norm > 0 and res.b_norm > 0);
    // B is nonsingular here, so every eigenvalue is finite: 2/1, 3/2, 4/3.
    for (w) |v| try testing.expect(!v.isInfinite());
    // Unlike geevx's, these are *not* bounded by 1 - measured, this pencil
    // gives 1.49, 0.72, 0.91. The generalized condition number is a chordal
    // distance against an unnormalized pencil, so treating it like the standard
    // one and asserting <= 1 is wrong.
    for (rconde) |v| try testing.expect(v > 0 and std.math.isFinite(v));
    try testing.expect(rconde[0] > 1);
}

test "ggbal and ggbak round-trip a badly scaled pencil" {
    const n = 3;
    var a = [_]f64{
        1,   1e-6, 0,
        1e6, 2,    1e6,
        0,   1e-6, 3,
    };
    var b = [_]f64{
        1, 0, 0,
        0, 1, 0,
        0, 0, 1,
    };
    var lscale: [n]f64 = undefined;
    var rscale: [n]f64 = undefined;
    const w = try ggbal(f64, testing.allocator, .both, n, &a, n, &b, n, &lscale, &rscale);

    try testing.expect(w.ilo >= 1 and w.ihi <= n);

    // Right and left eigenvectors use different scale vectors; passing the
    // wrong side silently returns the wrong answer, so both are exercised.
    var right = [_]f64{ 1, 1, 1 };
    var left = [_]f64{ 1, 1, 1 };
    try ggbak(f64, .both, .right, n, w.ilo, w.ihi, &lscale, &rscale, 1, &right, n);
    try ggbak(f64, .both, .left, n, w.ilo, w.ihi, &lscale, &rscale, 1, &left, n);
    for (right, left) |r, l| {
        try testing.expect(std.math.isFinite(r) and r != 0);
        try testing.expect(std.math.isFinite(l) and l != 0);
    }
}

test "tgevc back-transforms the generalized Schur vectors" {
    const n = 3;
    var a = pa;
    var b = pb;
    var w: [n]GeneralizedEigenvalue(f64) = undefined;
    var vsl: [n * n]f64 = undefined;
    var vsr: [n * n]f64 = undefined;
    _ = try gges(f64, testing.allocator, .vectors, .vectors, null, n, &a, n, &b, n, &w, &vsl, n, &vsr, n);

    const select = [_]bool{ false, false, false };
    var vr = vsr;
    var dummy: [1]f64 = undefined;
    const m = try tgevc(f64, testing.allocator, .right, .backtransform, &select, n, &a, n, &b, n, &dummy, 1, &vr, n, n);
    try testing.expectEqual(@as(usize, n), m);

    // Check the first finite eigenvalue: A v = lambda B v, which for a real
    // eigenvalue is a straightforward residual.
    for (w, 0..) |v, j| {
        const ratio = v.value() orelse continue;
        if (ratio.im != 0) continue;
        for (0..n) |i| {
            var av: f64 = 0;
            var bv: f64 = 0;
            for (0..n) |k| {
                av += pa[i + k * n] * vr[k + j * n];
                bv += pb[i + k * n] * vr[k + j * n];
            }
            try testing.expectApproxEqAbs(ratio.re * bv, av, 1e-9);
        }
    }
}

test "tgexc takes Fortran logicals where trexc takes characters" {
    const n = 3;
    var a = pa;
    var b = pb;
    var w: [n]GeneralizedEigenvalue(f64) = undefined;
    var q: [n * n]f64 = undefined;
    var z: [n * n]f64 = undefined;
    _ = try gges(f64, testing.allocator, .vectors, .vectors, null, n, &a, n, &b, n, &w, &q, n, &z, n);

    const before = w[0];
    const res = try tgexc(f64, testing.allocator, true, true, n, &a, n, &b, n, &q, n, &z, n, 3, 1);
    try testing.expectEqual(@as(usize, 1), res.to);

    // The eigenvalue that was third is now first, so the leading one changed.
    var after: [n]GeneralizedEigenvalue(f64) = undefined;
    for (0..n) |i| after[i] = .{
        .alpha = .{ .re = a[i + i * n], .im = 0 },
        .beta = .{ .re = b[i + i * n], .im = 0 },
    };
    try testing.expect(before.isInfinite() != after[0].isInfinite() or
        @abs(before.alpha.re - after[0].alpha.re) > 1e-9);
}

test "tgsen reorders and reports the cluster condition" {
    const n = 3;
    var a = pa;
    var b = pb;
    var w: [n]GeneralizedEigenvalue(f64) = undefined;
    var q: [n * n]f64 = undefined;
    var z: [n * n]f64 = undefined;
    _ = try gges(f64, testing.allocator, .vectors, .vectors, null, n, &a, n, &b, n, &w, &q, n, &z, n);

    // Select whichever eigenvalue is currently last.
    const select = [_]bool{ false, false, true };
    const res = try tgsen(f64, testing.allocator, .reorder_and_estimate_one_norm, true, true, &select, n, &a, n, &b, n, &w, &q, n, &z, n);

    try testing.expectEqual(@as(usize, 1), res.selected);
    try testing.expect(!res.reorder_failed);
    try testing.expect(res.cluster_condition >= 0);
}

test "tgsna conditions each generalized eigenvalue" {
    const n = 3;
    // A nonsingular B, so all three eigenvalues are finite and conditionable.
    var a = pa;
    var b = [_]f64{
        1, 0, 0,
        0, 2, 0,
        0, 0, 3,
    };
    var w: [n]GeneralizedEigenvalue(f64) = undefined;
    var q: [n * n]f64 = undefined;
    var z: [n * n]f64 = undefined;
    _ = try gges(f64, testing.allocator, .vectors, .vectors, null, n, &a, n, &b, n, &w, &q, n, &z, n);

    const select = [_]bool{ true, true, true };
    var vl = q;
    var vr = z;
    _ = try tgevc(f64, testing.allocator, .both, .backtransform, &select, n, &a, n, &b, n, &vl, n, &vr, n, n);

    var s: [n]f64 = undefined;
    var dif: [n]f64 = undefined;
    const m = try tgsna(f64, testing.allocator, .both, .all, &select, n, &a, n, &b, n, &vl, n, &vr, n, &s, &dif, n);

    try testing.expectEqual(@as(usize, n), m);
    for (s) |v| try testing.expect(v > 0 and std.math.isFinite(v));
    for (dif) |v| try testing.expect(v > 0);

    // ggevx computes the same numbers in one call; they agree exactly, which
    // pins that the staged path fed tgsna the right eigenvectors.
    var a2 = pa;
    var b2 = [_]f64{ 1, 0, 0, 0, 2, 0, 0, 0, 3 };
    var w2: [n]GeneralizedEigenvalue(f64) = undefined;
    var evl: [n * n]f64 = undefined;
    var evr: [n * n]f64 = undefined;
    var lscale: [n]f64 = undefined;
    var rscale: [n]f64 = undefined;
    var rconde: [n]f64 = undefined;
    var rcondv: [n]f64 = undefined;
    _ = try ggevx(f64, testing.allocator, .none, .vectors, .vectors, .both, n, &a2, n, &b2, n, &w2, &evl, n, &evr, n, &lscale, &rscale, &rconde, &rcondv);
    for (s, rconde) |x, y| try testing.expectApproxEqRel(x, y, 1e-12);
    for (dif, rcondv) |x, y| try testing.expectApproxEqRel(x, y, 1e-12);
}

test "tgsyl solves the coupled Sylvester pair" {
    const m = 2;
    const n = 2;
    // (A, D) and (B, E) both in generalized Schur form: upper triangular.
    const a = [_]f64{ 1, 0, 2, 3 };
    const d = [_]f64{ 1, 0, 0, 1 };
    const b = [_]f64{ 5, 0, 1, 7 };
    const e = [_]f64{ 1, 0, 0, 1 };
    // Pick R and L, then form the right-hand sides they produce.
    const r = [_]f64{ 1, 2, 3, 4 };
    const l = [_]f64{ 2, 1, 0, 3 };

    var cm: [m * n]f64 = undefined;
    var f: [m * n]f64 = undefined;
    for (0..n) |j| for (0..m) |i| {
        var ar: f64 = 0;
        var lb: f64 = 0;
        var dr: f64 = 0;
        var le: f64 = 0;
        for (0..m) |k| {
            ar += a[i + k * m] * r[k + j * m];
            dr += d[i + k * m] * r[k + j * m];
        }
        for (0..n) |k| {
            lb += l[i + k * m] * b[k + j * n];
            le += l[i + k * m] * e[k + j * n];
        }
        cm[i + j * m] = ar - lb;
        f[i + j * m] = dr - le;
    };

    const res = try tgsyl(f64, testing.allocator, .no_trans, 0, m, n, &a, m, &b, n, &cm, m, &d, m, &e, n, &f, m);
    try testing.expectApproxEqAbs(@as(f64, 1), res.scale, 1e-15);
    for (r, cm) |x, y| try testing.expectApproxEqAbs(x, y, 1e-11);
    for (l, f) |x, y| try testing.expectApproxEqAbs(x, y, 1e-11);
}

test "ggsvd3 simultaneously diagonalizes a pair" {
    const m = 3;
    const n = 2;
    const p = 2;
    var a = [_]f64{ 1, 0, 0, 0, 1, 0 };
    var b = [_]f64{ 1, 0, 0, 2 };
    var alpha: [n]f64 = undefined;
    var beta: [n]f64 = undefined;
    var u: [m * m]f64 = undefined;
    var v: [p * p]f64 = undefined;
    var q: [n * n]f64 = undefined;

    const res = try ggsvd3(f64, testing.allocator, true, true, true, m, n, p, &a, m, &b, p, &alpha, &beta, &u, m, &v, p, &q, n);

    // Both matrices have full column rank and B is nonsingular, so all the
    // generalized singular values are finite: k = 0, l = n.
    try testing.expectEqual(@as(usize, 0), res.k);
    try testing.expectEqual(@as(usize, n), res.l);

    // alpha^2 + beta^2 = 1 for every finite pair, which is the normalization
    // that makes the ratio meaningful.
    for (0..n) |i| {
        try testing.expectApproxEqAbs(@as(f64, 1), alpha[i] * alpha[i] + beta[i] * beta[i], 1e-12);
    }
    // The ratios are the generalized singular values of (A, B): 1/1 and 1/2.
    var ratios: [n]f64 = undefined;
    for (0..n) |i| ratios[i] = alpha[i] / beta[i];
    std.mem.sort(f64, &ratios, {}, std.sort.asc(f64));
    try testing.expectApproxEqRel(@as(f64, 0.5), ratios[0], 1e-10);
    try testing.expectApproxEqRel(@as(f64, 1), ratios[1], 1e-10);
}

test "tgsja runs the iteration behind ggsvd3, with the extents in the other order" {
    // A pair already in the triangular form ggsvd3's preprocessing produces:
    // both upper triangular and square, k = 0, l = n.
    const m = 2;
    const p = 2;
    const n = 2;
    var a = [_]f64{ 1, 0, 0, 1 };
    var b = [_]f64{ 1, 0, 0, 2 };
    var alpha: [n]f64 = undefined;
    var beta: [n]f64 = undefined;
    var u: [m * m]f64 = undefined;
    var v: [p * p]f64 = undefined;
    var q: [n * n]f64 = undefined;

    const eps = std.math.floatEps(f64);
    var nwork = [_]f64{ 0, 0 };
    const tola = @as(f64, @max(m, n)) * norms.lange(f64, .one, m, n, &a, m, &nwork) * eps;
    const tolb = @as(f64, @max(p, n)) * norms.lange(f64, .one, p, n, &b, p, &nwork) * eps;

    // m, p, n here - ggsvd3 takes m, n, p. Same two routines, different order.
    const cycles = try tgsja(f64, testing.allocator, .identity, .identity, .identity, m, p, n, 0, n, &a, m, &b, p, tola, tolb, &alpha, &beta, &u, m, &v, p, &q, n);
    try testing.expect(cycles >= 1);

    var ratios: [n]f64 = undefined;
    for (0..n) |i| ratios[i] = alpha[i] / beta[i];
    std.mem.sort(f64, &ratios, {}, std.sort.asc(f64));
    try testing.expectApproxEqRel(@as(f64, 0.5), ratios[0], 1e-10);
    try testing.expectApproxEqRel(@as(f64, 1), ratios[1], 1e-10);
}

test "the complex QZ path takes rwork where the real one takes none" {
    const Z = Complex(f64);
    const n = 2;
    var a = [_]Z{ Z.init(2, 0), Z.init(0, 0), Z.init(1, 1), Z.init(3, 0) };
    var b = [_]Z{ Z.init(1, 0), Z.init(0, 0), Z.init(0, 0), Z.init(1, 0) };
    var w: [n]GeneralizedEigenvalue(Z) = undefined;
    var vsl: [n * n]Z = undefined;
    var vsr: [n * n]Z = undefined;

    const res = try gges3(Z, testing.allocator, .vectors, .vectors, null, n, &a, n, &b, n, &w, &vsl, n, &vsr, n);
    try testing.expectEqual(@as(usize, 0), res.selected);

    // B is the identity, so the eigenvalues are A's: 2 and 3.
    var seen = [_]bool{ false, false };
    for (w) |v| {
        const ratio = v.value().?;
        if (@abs(ratio.re - 2) < 1e-10) seen[0] = true;
        if (@abs(ratio.re - 3) < 1e-10) seen[1] = true;
    }
    try testing.expect(seen[0] and seen[1]);
}
