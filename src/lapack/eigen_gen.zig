//! Nonsymmetric and generalized eigenvalue problems.
//!
//! A nonsymmetric matrix has no symmetry to lean on, so nothing here is as
//! well behaved as `eigen.zig`: eigenvalues are complex even when the matrix is
//! real, they come back unordered, and the eigenvectors are not orthogonal and
//! may not form a basis at all.
//!
//! ## Eigenvalues are complex, and this module says so
//!
//! LAPACK's real routines return eigenvalues split across two arrays, `wr` and
//! `wi`, with a complex conjugate pair occupying consecutive entries. The
//! complex routines return a single `w`. These wrappers always deliver
//! `[]Complex(Real(T))`, gathering the two real arrays internally, so the same
//! code reads the result whichever precision it ran at — and so the fact that a
//! real matrix has complex eigenvalues is in the type rather than in a comment.
//!
//! ## Eigenvectors of a real matrix are packed, and that is a trap
//!
//! The uniform eigenvalue array does *not* extend to the eigenvectors, because
//! they are large and copying them would be wasteful. `vr` comes back in
//! LAPACK's native layout, which for real `T` is:
//!
//! - if eigenvalue `j` is real, column `j` is its eigenvector;
//! - if eigenvalues `j` and `j+1` are a conjugate pair, column `j` holds the
//!   **real part** and column `j+1` the **imaginary part**, so the eigenvectors
//!   are `v_j = col(j) + i*col(j+1)` and `v_{j+1} = col(j) - i*col(j+1)`.
//!
//! Reading column `j+1` as an eigenvector in its own right is the classic
//! mistake and produces a plausible-looking wrong answer. `unpackVectors` below
//! expands the packed form into explicit complex columns when that is what you
//! want.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");
const reduce = @import("reduce.zig");

const Int = types.Int;
const Bool = types.Bool;
const Complex = types.Complex;
const Real = types.Real;
const Job = types.Job;
const Trans = types.Trans;
const Sort = types.Sort;
const Balance = types.Balance;
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

fn complexElement(comptime T: type) bool {
    return switch (T) {
        f32, f64 => false,
        else => true,
    };
}

/// The complex type eigenvalues of a `T`-valued matrix are reported in.
///
/// `Eigenvalue(f64)` is `Complex(f64)`; `Eigenvalue(Complex(f64))` is
/// `Complex(f64)` as well.
pub fn Eigenvalue(comptime T: type) type {
    return Complex(Real(T));
}

// ============================================================================
// geev
// ============================================================================

/// Eigenvalues and optionally eigenvectors of a general matrix.
///
/// `w` receives the eigenvalues, in no particular order — unlike the symmetric
/// drivers, there is no meaningful ordering to sort into.
///
/// `vl` and `vr` receive the left and right eigenvectors in LAPACK's packed
/// layout (see the module docs); pass `job = .values_only` and an empty slice
/// for either one you do not want. Right eigenvectors satisfy `A v = lambda v`;
/// left ones satisfy `u^H A = lambda u^H`.
///
/// `error.NoConvergence` means the QR iteration failed; `lastInfo()` is the
/// index past which eigenvalues did converge, so a partial result is available
/// in `w[lastInfo()..]`.
pub fn geev(
    comptime T: type,
    allocator: Allocator,
    jobvl: Job,
    jobvr: Job,
    n: usize,
    a: []T,
    lda: usize,
    w: []Eigenvalue(T),
    vl: []T,
    ldvl: usize,
    vr: []T,
    ldvr: usize,
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(w.len >= n);
    if (jobvl == .vectors) assertMatrix(vl.len, n, n, ldvl);
    if (jobvr == .vectors) assertMatrix(vr.len, n, n, ldvr);

    const n_ = dim(n);
    const lda_ = dim(lda);
    const ldvl_ = dim(@max(ldvl, 1));
    const ldvr_ = dim(@max(ldvr, 1));
    var info: Int = 0;

    var probe: [1]T = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        var rprobe: [1]Real(T) = undefined;
        sym(T, "geev")(opt(jobvl), opt(jobvr), ref(&n_), &probe, ref(&lda_), &probe, &probe, ref(&ldvl_), &probe, ref(&ldvr_), &wq, ref(&neg), &rprobe, out(&info));
    } else {
        sym(T, "geev")(opt(jobvl), opt(jobvr), ref(&n_), &probe, ref(&lda_), &probe, &probe, &probe, ref(&ldvl_), &probe, ref(&ldvr_), &wq, ref(&neg), out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexElement(T)) {
        // The complex form already reports a single complex array, so `w` can
        // be written directly.
        const rwork = try allocator.alloc(Real(T), @max(2 * n, 1));
        defer allocator.free(rwork);
        sym(T, "geev")(opt(jobvl), opt(jobvr), ref(&n_), a.ptr, ref(&lda_), @ptrCast(w.ptr), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), buf.ptr, ref(&lwork), rwork.ptr, out(&info));
    } else {
        // The real form splits eigenvalues into separate real and imaginary
        // arrays, so they are gathered into `w` afterwards.
        const wr = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(wr);
        const wi = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(wi);
        sym(T, "geev")(opt(jobvl), opt(jobvr), ref(&n_), a.ptr, ref(&lda_), wr.ptr, wi.ptr, vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), buf.ptr, ref(&lwork), out(&info));
        for (0..n) |i| w[i] = .{ .re = wr[i], .im = wi[i] };
    }
    return info_mod.checkConvergence(info);
}

/// Expands the packed real eigenvector layout into explicit complex columns.
///
/// A no-op copy for complex `T`, where the columns are already the
/// eigenvectors. For real `T` it undoes the conjugate-pair packing described in
/// the module docs.
///
/// `dest` needs `n` columns with leading dimension `lddest`.
pub fn unpackVectors(
    comptime T: type,
    n: usize,
    w: []const Eigenvalue(T),
    v: []const T,
    ldv: usize,
    dest: []Eigenvalue(T),
    lddest: usize,
) void {
    assertMatrix(v.len, n, n, ldv);
    assertMatrix(dest.len, n, n, lddest);
    std.debug.assert(w.len >= n);

    if (comptime complexElement(T)) {
        for (0..n) |j| {
            for (0..n) |i| dest[i + j * lddest] = @bitCast(v[i + j * ldv]);
        }
        return;
    }

    var j: usize = 0;
    while (j < n) {
        if (w[j].im == 0) {
            for (0..n) |i| dest[i + j * lddest] = .{ .re = v[i + j * ldv], .im = 0 };
            j += 1;
            continue;
        }
        // A conjugate pair. Column j is the real part and column j+1 the
        // imaginary part of *both* vectors, with opposite signs.
        std.debug.assert(j + 1 < n);
        for (0..n) |i| {
            const re = v[i + j * ldv];
            const im = v[i + (j + 1) * ldv];
            dest[i + j * lddest] = .{ .re = re, .im = im };
            dest[i + (j + 1) * lddest] = .{ .re = re, .im = -im };
        }
        j += 2;
    }
}

// ============================================================================
// gees - Schur factorization
// ============================================================================

/// A predicate deciding which eigenvalues `gees` sorts to the top of the Schur
/// form.
///
/// Takes the eigenvalue as one complex number regardless of precision, which
/// the raw LAPACK callback does not: its real form receives the real and
/// imaginary parts as two separate pointers and its complex form receives one.
pub fn SelectFn(comptime T: type) type {
    return *const fn (Eigenvalue(T)) bool;
}

// The LAPACK callback carries no context pointer, so the user's predicate has
// to reach the trampoline some other way. A threadlocal is safe here because
// LAPACK invokes the callback synchronously, on the calling thread, entirely
// within the `gees` call that installed it.
threadlocal var select_hook: ?*const anyopaque = null;

fn Trampoline(comptime T: type) type {
    return struct {
        fn real(re: [*]T, im: [*]T) callconv(.c) Bool {
            const f: SelectFn(T) = @ptrCast(@alignCast(select_hook.?));
            return if (f(.{ .re = re[0], .im = im[0] })) 1 else 0;
        }
        fn complex(z: [*]T) callconv(.c) Bool {
            const f: SelectFn(T) = @ptrCast(@alignCast(select_hook.?));
            return if (f(@bitCast(z[0]))) 1 else 0;
        }
    };
}

/// Result of a Schur factorization.
pub const SchurResult = struct {
    /// How many eigenvalues the predicate selected. Zero when unsorted.
    selected: usize,
};

/// Schur factorization `A = Z T Z^H`, optionally with selected eigenvalues
/// sorted to the leading block.
///
/// `a` is overwritten with the Schur form `T` — quasi-triangular for real
/// input, where a 2x2 diagonal block holds a conjugate pair, and genuinely
/// triangular for complex input. `vs` receives the Schur vectors `Z`.
///
/// Pass `select` to sort: the eigenvalues it accepts are moved to the top left,
/// and `selected` reports how many there were. This is the usual way to get an
/// invariant subspace — for example the stable one, by selecting eigenvalues
/// with negative real part.
///
/// Sorting can fail even when the factorization succeeds: `lastInfo()` of
/// `n + 1` means roundoff made the selected eigenvalues no longer separable, in
/// which case the factorization is still valid but the sort is not to be
/// trusted.
pub fn gees(
    comptime T: type,
    allocator: Allocator,
    jobvs: Job,
    select: ?SelectFn(T),
    n: usize,
    a: []T,
    lda: usize,
    w: []Eigenvalue(T),
    vs: []T,
    ldvs: usize,
) Fail!SchurResult {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(w.len >= n);
    if (jobvs == .vectors) assertMatrix(vs.len, n, n, ldvs);

    const n_ = dim(n);
    const lda_ = dim(lda);
    const ldvs_ = dim(@max(ldvs, 1));
    const sort: Sort = if (select == null) .unsorted else .sorted;
    var sdim: Int = 0;
    var info: Int = 0;

    const bwork = try allocator.alloc(Bool, @max(n, 1));
    defer allocator.free(bwork);

    var probe: [1]T = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        var rprobe: [1]Real(T) = undefined;
        sym(T, "gees")(opt(jobvs), opt(sort), null, ref(&n_), &probe, ref(&lda_), out(&sdim), &probe, &probe, ref(&ldvs_), &wq, ref(&neg), &rprobe, bwork.ptr, out(&info));
    } else {
        sym(T, "gees")(opt(jobvs), opt(sort), null, ref(&n_), &probe, ref(&lda_), out(&sdim), &probe, &probe, &probe, ref(&ldvs_), &wq, ref(&neg), bwork.ptr, out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    const previous = select_hook;
    select_hook = if (select) |f| @ptrCast(f) else null;
    defer select_hook = previous;

    if (comptime complexElement(T)) {
        const callback = if (select == null) null else &Trampoline(T).complex;
        const rwork = try allocator.alloc(Real(T), @max(n, 1));
        defer allocator.free(rwork);
        sym(T, "gees")(opt(jobvs), opt(sort), callback, ref(&n_), a.ptr, ref(&lda_), out(&sdim), @ptrCast(w.ptr), vs.ptr, ref(&ldvs_), buf.ptr, ref(&lwork), rwork.ptr, bwork.ptr, out(&info));
    } else {
        const callback = if (select == null) null else &Trampoline(T).real;
        const wr = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(wr);
        const wi = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(wi);
        sym(T, "gees")(opt(jobvs), opt(sort), callback, ref(&n_), a.ptr, ref(&lda_), out(&sdim), wr.ptr, wi.ptr, vs.ptr, ref(&ldvs_), buf.ptr, ref(&lwork), bwork.ptr, out(&info));
        for (0..n) |i| w[i] = .{ .re = wr[i], .im = wi[i] };
    }
    try info_mod.checkConvergence(info);
    return .{ .selected = @intCast(sdim) };
}

// ============================================================================
// ggev - generalized eigenvalues
// ============================================================================

/// Generalized eigenvalues, reported as the pair they actually are.
///
/// The eigenvalue is `alpha / beta`, and LAPACK reports the two separately
/// rather than dividing, because `beta` can be **zero**: a singular `B` gives
/// the pencil genuinely infinite eigenvalues, and there is no complex number to
/// return for those. Dividing without checking turns a meaningful infinite
/// eigenvalue into a NaN or an overflow.
pub fn GeneralizedEigenvalue(comptime T: type) type {
    return struct {
        const Self = @This();

        alpha: Eigenvalue(T),
        beta: Eigenvalue(T),

        /// `alpha / beta`, or null when `beta` is zero (an infinite eigenvalue).
        pub fn value(self: Self) ?Eigenvalue(T) {
            if (self.beta.re == 0 and self.beta.im == 0) return null;
            const d = self.beta.re * self.beta.re + self.beta.im * self.beta.im;
            return .{
                .re = (self.alpha.re * self.beta.re + self.alpha.im * self.beta.im) / d,
                .im = (self.alpha.im * self.beta.re - self.alpha.re * self.beta.im) / d,
            };
        }

        /// Whether this is an infinite eigenvalue.
        pub fn isInfinite(self: Self) bool {
            return self.beta.re == 0 and self.beta.im == 0;
        }
    };
}

/// Eigenvalues of the pencil `A - lambda B`, and optionally its eigenvectors.
///
/// See `GeneralizedEigenvalue` for why the result is a pair rather than a
/// number.
pub fn ggev(
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

    const n_ = dim(n);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    const ldvl_ = dim(@max(ldvl, 1));
    const ldvr_ = dim(@max(ldvr, 1));
    var info: Int = 0;

    var probe: [1]T = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        var rprobe: [1]Real(T) = undefined;
        sym(T, "ggev")(opt(jobvl), opt(jobvr), ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), &probe, &probe, &probe, ref(&ldvl_), &probe, ref(&ldvr_), &wq, ref(&neg), &rprobe, out(&info));
    } else {
        sym(T, "ggev")(opt(jobvl), opt(jobvr), ref(&n_), &probe, ref(&lda_), &probe, ref(&ldb_), &probe, &probe, &probe, &probe, ref(&ldvl_), &probe, ref(&ldvr_), &wq, ref(&neg), out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexElement(T)) {
        const alpha = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(alpha);
        const beta = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(beta);
        const rwork = try allocator.alloc(Real(T), @max(8 * n, 1));
        defer allocator.free(rwork);
        sym(T, "ggev")(opt(jobvl), opt(jobvr), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), alpha.ptr, beta.ptr, vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), buf.ptr, ref(&lwork), rwork.ptr, out(&info));
        for (0..n) |i| w[i] = .{ .alpha = @bitCast(alpha[i]), .beta = @bitCast(beta[i]) };
    } else {
        // The real form splits alpha but keeps beta real, since a real pencil's
        // beta is always real even when alpha is not.
        const alphar = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(alphar);
        const alphai = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(alphai);
        const beta = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(beta);
        sym(T, "ggev")(opt(jobvl), opt(jobvr), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), alphar.ptr, alphai.ptr, beta.ptr, vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), buf.ptr, ref(&lwork), out(&info));
        for (0..n) |i| w[i] = .{
            .alpha = .{ .re = alphar[i], .im = alphai[i] },
            .beta = .{ .re = beta[i], .im = 0 },
        };
    }
    return info_mod.checkConvergence(info);
}

// ============================================================================
// Sylvester equation
// ============================================================================

/// Solution of a Sylvester equation, and the scaling that made it representable.
pub const SylvesterResult = struct {
    /// The right-hand side was multiplied by this to avoid overflow, so the
    /// true solution is `X / scale`. Usually 1.
    scale: f64,
    /// Whether the equation was perturbed to make it solvable, which happens
    /// when `A` and `B` have eigenvalues that are close to each other. The
    /// answer is then the solution of a nearby problem.
    perturbed: bool,
};

/// Solves the Sylvester equation `op(A) X + isgn * X op(B) = scale * C`.
///
/// `A` and `B` must already be in Schur form — this is the back end of an
/// invariant-subspace computation, not a standalone solver, so run `gees` on
/// each first. `c` is overwritten with `X`.
///
/// `isgn` must be `1` or `-1`.
pub fn trsyl(
    comptime T: type,
    trana: Trans,
    tranb: Trans,
    isgn: i2,
    m: usize,
    n: usize,
    a: []const T,
    lda: usize,
    b: []const T,
    ldb: usize,
    cm: []T,
    ldc: usize,
) Error!SylvesterResult {
    std.debug.assert(isgn == 1 or isgn == -1);
    assertMatrix(a.len, m, m, lda);
    assertMatrix(b.len, n, n, ldb);
    assertMatrix(cm.len, m, n, ldc);

    const isgn_: Int = isgn;
    const m_ = dim(m);
    const n_ = dim(n);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    const ldc_ = dim(ldc);
    var scale: Real(T) = 0;
    var info: Int = 0;

    sym(T, "trsyl")(opt(trana), opt(tranb), ref(&isgn_), ref(&m_), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), cm.ptr, ref(&ldc_), out(&scale), out(&info));

    // info == 1 reports a perturbed but computed solution, which is a result
    // rather than a failure - hence not routed through checkDegenerate.
    if (info < 0) try info_mod.checkArgs(info);
    return .{ .scale = scale, .perturbed = info == 1 };
}

// ============================================================================
// Expert drivers
// ============================================================================

/// Which condition numbers an expert driver should compute.
///
/// These are not free — `.eigenvectors` and `.both` cost roughly an extra
/// `geev` — and they constrain the other arguments: `geevx` needs *both* sets
/// of eigenvectors to condition-estimate eigenvalues, and `geesx` needs a sort
/// predicate to have something to condition-estimate about.
pub const Sense = enum(u8) {
    none = 'N',
    /// Condition numbers for the eigenvalues (`geevx`) or for the average of
    /// the selected cluster (`geesx`).
    eigenvalues = 'E',
    /// Condition numbers for the eigenvectors (`geevx`) or for the selected
    /// invariant subspace (`geesx`).
    eigenvectors = 'V',
    both = 'B',
};

/// What `geevx` computed besides the eigenvalues.
pub const ExpertEigenResult = struct {
    /// The window `gebal` left, 1-based inclusive. Outside it the balanced
    /// matrix is already triangular.
    window: reduce.Window,
    /// The 1-norm of the balanced matrix. The condition numbers are relative to
    /// this, so `rconde[i]` is meaningful as `matrix_norm / rconde[i]` being the
    /// error amplification for eigenvalue `i`.
    matrix_norm: f64,
};

/// `geev` with balancing, and condition numbers for what it computed.
///
/// Three things `geev` does not give you:
///
/// - `balance` runs `gebal` first, which can dramatically improve accuracy on a
///   badly scaled matrix. The eigenvectors are back-transformed automatically,
///   so unlike calling `gebal` by hand there is no `gebak` step to remember.
/// - `rconde[i]` is the reciprocal condition number of eigenvalue `i`: small
///   means that eigenvalue is sensitive to perturbations of the matrix.
/// - `rcondv[i]` is the same for eigenvector `i`, which is governed by how
///   close eigenvalue `i` is to the rest of the spectrum rather than by the
///   matrix norm.
///
/// Both arrays need `n` entries and are only written when `sense` asks for
/// them. `sense = .eigenvalues` or `.both` **requires** `jobvl` and `jobvr` to
/// both be `.vectors` — the estimate is built from both sets — and that is
/// asserted here rather than left to come back as an illegal argument.
pub fn geevx(
    comptime T: type,
    allocator: Allocator,
    balance: Balance,
    jobvl: Job,
    jobvr: Job,
    sense: Sense,
    n: usize,
    a: []T,
    lda: usize,
    w: []Eigenvalue(T),
    vl: []T,
    ldvl: usize,
    vr: []T,
    ldvr: usize,
    scale: []Real(T),
    rconde: []Real(T),
    rcondv: []Real(T),
) Fail!ExpertEigenResult {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(w.len >= n);
    std.debug.assert(scale.len >= n);
    if (jobvl == .vectors) assertMatrix(vl.len, n, n, ldvl);
    if (jobvr == .vectors) assertMatrix(vr.len, n, n, ldvr);
    if (sense == .eigenvalues or sense == .both) {
        std.debug.assert(jobvl == .vectors and jobvr == .vectors);
        std.debug.assert(rconde.len >= n);
    }
    if (sense == .eigenvectors or sense == .both) std.debug.assert(rcondv.len >= n);

    const n_ = dim(n);
    const lda_ = dim(lda);
    const ldvl_ = dim(@max(ldvl, 1));
    const ldvr_ = dim(@max(ldvr, 1));
    var ilo: Int = 0;
    var ihi: Int = 0;
    var abnrm: Real(T) = 0;
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var iprobe: [1]Int = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        sym(T, "geevx")(opt(balance), opt(jobvl), opt(jobvr), opt(sense), ref(&n_), &probe, ref(&lda_), &probe, &probe, ref(&ldvl_), &probe, ref(&ldvr_), out(&ilo), out(&ihi), &rprobe, out(&abnrm), &rprobe, &rprobe, &wq, ref(&neg), &rprobe, out(&info));
    } else {
        sym(T, "geevx")(opt(balance), opt(jobvl), opt(jobvr), opt(sense), ref(&n_), &probe, ref(&lda_), &probe, &probe, &probe, ref(&ldvl_), &probe, ref(&ldvr_), out(&ilo), out(&ihi), &rprobe, out(&abnrm), &rprobe, &rprobe, &wq, ref(&neg), &iprobe, out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexElement(T)) {
        const rwork = try allocator.alloc(Real(T), @max(2 * n, 1));
        defer allocator.free(rwork);
        sym(T, "geevx")(opt(balance), opt(jobvl), opt(jobvr), opt(sense), ref(&n_), a.ptr, ref(&lda_), @ptrCast(w.ptr), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), out(&ilo), out(&ihi), scale.ptr, out(&abnrm), rconde.ptr, rcondv.ptr, buf.ptr, ref(&lwork), rwork.ptr, out(&info));
    } else {
        // Only referenced for sense V or B, where the documented size is 2n-2.
        const iwork = try allocator.alloc(Int, @max(2 * n, 1));
        defer allocator.free(iwork);
        const wr = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(wr);
        const wi = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(wi);
        sym(T, "geevx")(opt(balance), opt(jobvl), opt(jobvr), opt(sense), ref(&n_), a.ptr, ref(&lda_), wr.ptr, wi.ptr, vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), out(&ilo), out(&ihi), scale.ptr, out(&abnrm), rconde.ptr, rcondv.ptr, buf.ptr, ref(&lwork), iwork.ptr, out(&info));
        for (0..n) |i| w[i] = .{ .re = wr[i], .im = wi[i] };
    }
    try info_mod.checkConvergence(info);
    return .{
        .window = .{ .ilo = @intCast(ilo), .ihi = @intCast(ihi) },
        .matrix_norm = abnrm,
    };
}

/// What `geesx` computed besides the Schur form.
pub const ExpertSchurResult = struct {
    /// How many eigenvalues the predicate selected.
    selected: usize,
    /// Reciprocal condition number of the *average* of the selected
    /// eigenvalues. Written only when `sense` asks for it. Note this is one
    /// number for the whole cluster, not one per eigenvalue — for a tight
    /// cluster the individual eigenvalues can be arbitrarily ill-conditioned
    /// while their average is not.
    cluster_condition: f64,
    /// Reciprocal condition number of the selected invariant subspace. Also one
    /// number, and it measures how far the selected eigenvalues are from the
    /// unselected ones.
    subspace_condition: f64,
    /// True when `info` came back as `n + 2`: the Schur form and the sort are
    /// both valid, but roundoff made the selected eigenvalues no longer
    /// separable, so the condition numbers may be wrong.
    condition_unreliable: bool,
};

/// `gees` with condition numbers for the selected cluster and its subspace.
///
/// `sense` other than `.none` **requires** a `select` predicate — there is no
/// cluster to condition-estimate otherwise — which is asserted here.
///
/// The positive `info` values are more crowded than `gees`'s:
///
/// | `info` | meaning |
/// |---|---|
/// | `1 .. n` | the QR iteration failed |
/// | `n + 1` | the eigenvalues could not be reordered; nothing was sorted |
/// | `n + 2` | reordering succeeded but roundoff made the cluster inseparable |
///
/// The last is a warning, not a failure, so it comes back as
/// `condition_unreliable` rather than as an error.
pub fn geesx(
    comptime T: type,
    allocator: Allocator,
    jobvs: Job,
    select: ?SelectFn(T),
    sense: Sense,
    n: usize,
    a: []T,
    lda: usize,
    w: []Eigenvalue(T),
    vs: []T,
    ldvs: usize,
) Fail!ExpertSchurResult {
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(w.len >= n);
    if (jobvs == .vectors) assertMatrix(vs.len, n, n, ldvs);
    if (sense != .none) std.debug.assert(select != null);

    const n_ = dim(n);
    const lda_ = dim(lda);
    const ldvs_ = dim(@max(ldvs, 1));
    const sort: Sort = if (select == null) .unsorted else .sorted;
    var sdim: Int = 0;
    var rconde: Real(T) = 0;
    var rcondv: Real(T) = 0;
    var info: Int = 0;

    const bwork = try allocator.alloc(Bool, @max(n, 1));
    defer allocator.free(bwork);

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    var iq: [1]Int = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        sym(T, "geesx")(opt(jobvs), opt(sort), null, opt(sense), ref(&n_), &probe, ref(&lda_), out(&sdim), &probe, &probe, ref(&ldvs_), out(&rconde), out(&rcondv), &wq, ref(&neg), &rprobe, null, out(&info));
    } else {
        sym(T, "geesx")(opt(jobvs), opt(sort), null, opt(sense), ref(&n_), &probe, ref(&lda_), out(&sdim), &probe, &probe, &probe, ref(&ldvs_), out(&rconde), out(&rcondv), &wq, ref(&neg), &iq, ref(&neg), null, out(&info));
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
        const rwork = try allocator.alloc(Real(T), @max(2 * n, 1));
        defer allocator.free(rwork);
        sym(T, "geesx")(opt(jobvs), opt(sort), callback, opt(sense), ref(&n_), a.ptr, ref(&lda_), out(&sdim), @ptrCast(w.ptr), vs.ptr, ref(&ldvs_), out(&rconde), out(&rcondv), buf.ptr, ref(&lwork), rwork.ptr, bwork.ptr, out(&info));
    } else {
        const callback = if (select == null) null else &Trampoline(T).real;
        const iwork = try allocator.alloc(Int, @intCast(@max(iq[0], 1)));
        defer allocator.free(iwork);
        const liwork = dim(iwork.len);
        const wr = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(wr);
        const wi = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(wi);
        sym(T, "geesx")(opt(jobvs), opt(sort), callback, opt(sense), ref(&n_), a.ptr, ref(&lda_), out(&sdim), wr.ptr, wi.ptr, vs.ptr, ref(&ldvs_), out(&rconde), out(&rcondv), buf.ptr, ref(&lwork), iwork.ptr, ref(&liwork), bwork.ptr, out(&info));
        for (0..n) |i| w[i] = .{ .re = wr[i], .im = wi[i] };
    }

    const unreliable = info == @as(Int, @intCast(n)) + 2;
    if (!unreliable) try info_mod.checkConvergence(info);
    return .{
        .selected = @intCast(sdim),
        .cluster_condition = rconde,
        .subspace_condition = rcondv,
        .condition_unreliable = unreliable,
    };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "geev finds real eigenvalues of a real matrix" {
    // Column-major [[1, 2], [3, 4]]: eigenvalues (5 +/- sqrt(33)) / 2.
    var a = [_]f64{ 1, 3, 2, 4 };
    var w: [2]Complex(f64) = undefined;
    var vr: [4]f64 = undefined;
    var empty: [1]f64 = undefined;

    try geev(f64, testing.allocator, .values_only, .vectors, 2, &a, 2, &w, &empty, 1, &vr, 2);

    const s = @sqrt(@as(f64, 33));
    // Order is not guaranteed, so check the set rather than the sequence.
    const lo = @min(w[0].re, w[1].re);
    const hi = @max(w[0].re, w[1].re);
    try testing.expectApproxEqAbs((5 - s) / 2, lo, 1e-12);
    try testing.expectApproxEqAbs((5 + s) / 2, hi, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), w[0].im, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), w[1].im, 1e-12);
}

test "a real matrix can have complex eigenvalues, and w carries them" {
    // A 90-degree rotation, [[0, -1], [1, 0]], has eigenvalues +i and -i. This
    // is the whole reason the eigenvalue array is complex even for f64 input.
    var a = [_]f64{ 0, 1, -1, 0 };
    var w: [2]Complex(f64) = undefined;
    var vr: [4]f64 = undefined;
    var empty: [1]f64 = undefined;

    try geev(f64, testing.allocator, .values_only, .vectors, 2, &a, 2, &w, &empty, 1, &vr, 2);

    try testing.expectApproxEqAbs(@as(f64, 0), w[0].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), w[1].re, 1e-12);
    // A conjugate pair: one +1, one -1, in some order.
    try testing.expectApproxEqAbs(@as(f64, 1), @abs(w[0].im), 1e-12);
    try testing.expectApproxEqAbs(@as(f64, -w[0].im), w[1].im, 1e-12);
}

test "unpackVectors expands the packed conjugate-pair layout" {
    // Same rotation matrix. The two columns of vr are the real and imaginary
    // parts of one eigenvector, not two eigenvectors - reading them as two is
    // the mistake this function exists to prevent.
    const original = [_]f64{ 0, 1, -1, 0 };
    var a = original;
    var w: [2]Complex(f64) = undefined;
    var vr: [4]f64 = undefined;
    var empty: [1]f64 = undefined;

    try geev(f64, testing.allocator, .values_only, .vectors, 2, &a, 2, &w, &empty, 1, &vr, 2);

    var v: [4]Complex(f64) = undefined;
    unpackVectors(f64, 2, &w, &vr, 2, &v, 2);

    // Now check A v = lambda v with genuine complex arithmetic, for both
    // eigenpairs. This fails if the packing was misread.
    for (0..2) |k| {
        for (0..2) |i| {
            var acc = Complex(f64).zero;
            for (0..2) |j| {
                const aij = Complex(f64){ .re = original[i + j * 2], .im = 0 };
                acc = acc.add(aij.mul(v[j + k * 2]));
            }
            const want = w[k].mul(v[i + k * 2]);
            try testing.expectApproxEqAbs(want.re, acc.re, 1e-12);
            try testing.expectApproxEqAbs(want.im, acc.im, 1e-12);
        }
    }

    // And the two unpacked vectors really are conjugates of one another.
    try testing.expectApproxEqAbs(v[0].re, v[2].re, 1e-12);
    try testing.expectApproxEqAbs(v[0].im, -v[2].im, 1e-12);
}

test "unpackVectors leaves real eigenvectors alone" {
    const original = [_]f64{ 2, 0, 0, 3 }; // diagonal, real eigenvalues
    var a = original;
    var w: [2]Complex(f64) = undefined;
    var vr: [4]f64 = undefined;
    var empty: [1]f64 = undefined;

    try geev(f64, testing.allocator, .values_only, .vectors, 2, &a, 2, &w, &empty, 1, &vr, 2);

    var v: [4]Complex(f64) = undefined;
    unpackVectors(f64, 2, &w, &vr, 2, &v, 2);

    for (0..4) |i| {
        try testing.expectApproxEqAbs(vr[i], v[i].re, 1e-12);
        try testing.expectApproxEqAbs(@as(f64, 0), v[i].im, 1e-12);
    }
}

test "geev on a complex matrix writes w directly" {
    const Z = Complex(f64);
    // Upper triangular, so the eigenvalues are the diagonal.
    var a = [_]Z{ Z.init(1, 1), Z.init(0, 0), Z.init(5, 0), Z.init(2, -3) };
    var w: [2]Z = undefined;
    var empty: [1]Z = undefined;

    try geev(Z, testing.allocator, .values_only, .values_only, 2, &a, 2, &w, &empty, 1, &empty, 1);

    const first_is_one = @abs(w[0].re - 1) < 1e-12;
    const one = if (first_is_one) w[0] else w[1];
    const two = if (first_is_one) w[1] else w[0];
    try testing.expectApproxEqAbs(@as(f64, 1), one.re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1), one.im, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2), two.re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, -3), two.im, 1e-12);
}

test "gees without sorting produces the Schur form" {
    const original = [_]f64{ 1, 3, 2, 4 };
    var a = original;
    var w: [2]Complex(f64) = undefined;
    var vs: [4]f64 = undefined;

    const r = try gees(f64, testing.allocator, .vectors, null, 2, &a, 2, &w, &vs, 2);
    try testing.expectEqual(@as(usize, 0), r.selected);

    // Z T Z^T must reconstruct the original.
    for (0..2) |i| {
        for (0..2) |j| {
            var acc: f64 = 0;
            for (0..2) |p| {
                for (0..2) |q| acc += vs[i + p * 2] * a[p + q * 2] * vs[j + q * 2];
            }
            try testing.expectApproxEqAbs(original[i + j * 2], acc, 1e-12);
        }
    }
}

test "gees sorts the eigenvalues a predicate selects" {
    // diag(-2, 1, -5, 3): two have negative real part.
    const n = 4;
    var a = [_]f64{0} ** (n * n);
    const diag = [_]f64{ -2, 1, -5, 3 };
    for (0..n) |i| a[i + i * n] = diag[i];
    var w: [n]Complex(f64) = undefined;
    var vs: [n * n]f64 = undefined;

    const S = struct {
        fn stable(lambda: Complex(f64)) bool {
            return lambda.re < 0;
        }
    };

    const r = try gees(f64, testing.allocator, .vectors, &S.stable, n, &a, n, &w, &vs, n);

    try testing.expectEqual(@as(usize, 2), r.selected);
    // The selected ones are moved to the leading block, so the first two
    // eigenvalues must be the negative ones.
    try testing.expect(w[0].re < 0);
    try testing.expect(w[1].re < 0);
    try testing.expect(w[2].re > 0);
    try testing.expect(w[3].re > 0);
}

test "the gees predicate receives one complex number for either precision" {
    // The raw LAPACK callback takes two pointers for real input and one for
    // complex. The Zig predicate is the same shape in both cases, which is what
    // the trampoline is for.
    const Z = Complex(f64);
    const n = 3;
    var a = [_]Z{Z.zero} ** (n * n);
    const diag = [_]Z{ Z.init(-1, 0), Z.init(2, 0), Z.init(-3, 0) };
    for (0..n) |i| a[i + i * n] = diag[i];
    var w: [n]Z = undefined;
    var vs: [n * n]Z = undefined;

    const S = struct {
        fn stable(lambda: Z) bool {
            return lambda.re < 0;
        }
    };

    const r = try gees(Z, testing.allocator, .vectors, &S.stable, n, &a, n, &w, &vs, n);
    try testing.expectEqual(@as(usize, 2), r.selected);
    try testing.expect(w[0].re < 0);
    try testing.expect(w[1].re < 0);
}

test "ggev reports finite eigenvalues as a ratio" {
    // A = diag(2, 6), B = diag(1, 2) gives eigenvalues 2 and 3.
    var a = [_]f64{ 2, 0, 0, 6 };
    var b = [_]f64{ 1, 0, 0, 2 };
    var w: [2]GeneralizedEigenvalue(f64) = undefined;
    var empty: [1]f64 = undefined;

    try ggev(f64, testing.allocator, .values_only, .values_only, 2, &a, 2, &b, 2, &w, &empty, 1, &empty, 1);

    var values: [2]f64 = undefined;
    for (w, 0..) |pair, i| {
        try testing.expect(!pair.isInfinite());
        values[i] = pair.value().?.re;
    }
    const lo = @min(values[0], values[1]);
    const hi = @max(values[0], values[1]);
    try testing.expectApproxEqAbs(@as(f64, 2), lo, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 3), hi, 1e-12);
}

test "ggev reports an infinite eigenvalue rather than dividing by zero" {
    // B singular: the pencil has an infinite eigenvalue, and `value()` returns
    // null instead of a NaN. This is why the result is a pair rather than a
    // number.
    var a = [_]f64{ 1, 0, 0, 1 };
    var b = [_]f64{ 1, 0, 0, 0 }; // second diagonal entry is zero
    var w: [2]GeneralizedEigenvalue(f64) = undefined;
    var empty: [1]f64 = undefined;

    try ggev(f64, testing.allocator, .values_only, .values_only, 2, &a, 2, &b, 2, &w, &empty, 1, &empty, 1);

    var infinite: usize = 0;
    var finite: usize = 0;
    for (w) |pair| {
        if (pair.isInfinite()) {
            infinite += 1;
            try testing.expectEqual(@as(?Complex(f64), null), pair.value());
        } else {
            finite += 1;
            try testing.expectApproxEqAbs(@as(f64, 1), pair.value().?.re, 1e-12);
        }
    }
    try testing.expectEqual(@as(usize, 1), infinite);
    try testing.expectEqual(@as(usize, 1), finite);
}

test "trsyl solves a Sylvester equation in Schur form" {
    // A = [[1, 0], [0, 2]], B = [[3, 0], [0, 4]], both already triangular.
    // A X + X B = C with C all ones gives X_ij = 1 / (a_i + b_j).
    const a = [_]f64{ 1, 0, 0, 2 };
    const b = [_]f64{ 3, 0, 0, 4 };
    var cm = [_]f64{ 1, 1, 1, 1 };

    const r = try trsyl(f64, .no_trans, .no_trans, 1, 2, 2, &a, 2, &b, 2, &cm, 2);

    try testing.expect(!r.perturbed);
    try testing.expectApproxEqAbs(@as(f64, 1), r.scale, 1e-12);
    // X(0,0) = 1/(1+3), X(1,0) = 1/(2+3), X(0,1) = 1/(1+4), X(1,1) = 1/(2+4).
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 4.0), cm[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 5.0), cm[1], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 5.0), cm[2], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 6.0), cm[3], 1e-12);
}

test "trsyl reports perturbation instead of failing" {
    // A and -B share an eigenvalue, so the equation is singular. LAPACK
    // perturbs and reports it rather than returning an error, which is a
    // result the caller needs to know about.
    const a = [_]f64{ 1, 0, 0, 1 };
    const b = [_]f64{ -1, 0, 0, -1 };
    var cm = [_]f64{ 1, 1, 1, 1 };

    const r = try trsyl(f64, .no_trans, .no_trans, 1, 2, 2, &a, 2, &b, 2, &cm, 2);
    try testing.expect(r.perturbed);
}

test "single precision works through the same wrappers" {
    var a = [_]f32{ 0, 1, -1, 0 };
    var w: [2]Complex(f32) = undefined;
    var empty: [1]f32 = undefined;

    try geev(f32, testing.allocator, .values_only, .values_only, 2, &a, 2, &w, &empty, 1, &empty, 1);

    try testing.expectApproxEqAbs(@as(f32, 1), @abs(w[0].im), 1e-6);
}

// ============================================================================
// Tests: expert drivers
// ============================================================================

test "geevx balances a badly scaled matrix and reports the window" {
    const n = 3;
    // The same matrix as a well-scaled one, with row 1 multiplied by 1e6 and
    // column 1 divided by it - a diagonal similarity, so the eigenvalues are
    // unchanged and balancing should undo it.
    var a = [_]f64{
        1,   1e-6, 0,
        1e6, 2,    1e6,
        0,   1e-6, 3,
    };
    var w: [n]Eigenvalue(f64) = undefined;
    var vl: [n * n]f64 = undefined;
    var vr: [n * n]f64 = undefined;
    var scale: [n]f64 = undefined;
    var rconde: [n]f64 = undefined;
    var rcondv: [n]f64 = undefined;

    const res = try geevx(f64, testing.allocator, .both, .vectors, .vectors, .both, n, &a, n, &w, &vl, n, &vr, n, &scale, &rconde, &rcondv);

    try testing.expect(res.window.ilo >= 1 and res.window.ihi <= n);
    try testing.expect(res.matrix_norm > 0);

    // Trace is invariant: the sum of the eigenvalues is 1 + 2 + 3.
    var sum: f64 = 0;
    for (w) |v| sum += v.re;
    try testing.expectApproxEqAbs(@as(f64, 6), sum, 1e-9);

    // Every condition number is in (0, 1].
    for (rconde) |v| try testing.expect(v > 0 and v <= 1 + 1e-12);
    for (rcondv) |v| try testing.expect(v > 0);
}

test "geevx reports a small rconde for a nearly defective matrix" {
    const n = 2;
    // A Jordan block perturbed slightly: the two eigenvalues are extremely
    // sensitive, which is exactly what rconde measures.
    var a = [_]f64{ 1, 1e-14, 1, 1 };
    var w: [n]Eigenvalue(f64) = undefined;
    var vl: [n * n]f64 = undefined;
    var vr: [n * n]f64 = undefined;
    var scale: [n]f64 = undefined;
    var rconde: [n]f64 = undefined;
    var rcondv: [n]f64 = undefined;
    _ = try geevx(f64, testing.allocator, .none, .vectors, .vectors, .both, n, &a, n, &w, &vl, n, &vr, n, &scale, &rconde, &rcondv);

    // Well-conditioned would be near 1; this is nowhere near.
    for (rconde) |v| try testing.expect(v < 1e-5);

    // And a well-conditioned matrix, for contrast.
    var b = [_]f64{ 1, 0, 0, 5 };
    var rconde2: [n]f64 = undefined;
    _ = try geevx(f64, testing.allocator, .none, .vectors, .vectors, .both, n, &b, n, &w, &vl, n, &vr, n, &scale, &rconde2, &rcondv);
    for (rconde2) |v| try testing.expectApproxEqAbs(@as(f64, 1), v, 1e-12);
}

test "geevx with sense = .none skips the condition estimates" {
    const n = 3;
    var a = [_]f64{ 1, 0, 0, 2, 3, 0, 4, 5, 6 };
    var w: [n]Eigenvalue(f64) = undefined;
    var vl: [1]f64 = undefined;
    var vr: [1]f64 = undefined;
    var scale: [n]f64 = undefined;
    var none: [0]f64 = undefined;

    // No eigenvectors are needed when nothing is being estimated - the
    // constraint that ties sense to jobvl/jobvr only bites for .eigenvalues.
    _ = try geevx(f64, testing.allocator, .none, .values_only, .values_only, .none, n, &a, n, &w, &vl, 1, &vr, 1, &scale, &none, &none);

    // Upper triangular: the eigenvalues are the diagonal.
    var found = [_]bool{false} ** 3;
    for (w) |v| {
        for ([_]f64{ 1, 3, 6 }, 0..) |expected, i| {
            if (@abs(v.re - expected) < 1e-12 and @abs(v.im) < 1e-12) found[i] = true;
        }
    }
    for (found) |f| try testing.expect(f);
}

fn selectNegativeReal(value: Eigenvalue(f64)) bool {
    return value.re < 0;
}

test "geesx reports the condition of the selected cluster" {
    const n = 4;
    // Block diagonal with a well-separated stable pair and unstable pair.
    var a = [_]f64{
        -1, 0,  0, 0,
        0,  -2, 0, 0,
        0,  0,  3, 0,
        0,  0,  0, 4,
    };
    var w: [n]Eigenvalue(f64) = undefined;
    var vs: [n * n]f64 = undefined;

    const res = try geesx(f64, testing.allocator, .vectors, selectNegativeReal, .both, n, &a, n, &w, &vs, n);

    try testing.expectEqual(@as(usize, 2), res.selected);
    try testing.expect(!res.condition_unreliable);
    // Diagonal and well separated, so both conditions are excellent.
    try testing.expect(res.cluster_condition > 0.5);
    try testing.expect(res.subspace_condition > 0.5);
}

test "geesx's subspace condition falls when the selected eigenvalues approach the rest" {
    const n = 2;
    var far = [_]f64{ -1, 0, 0, 1 };
    var w: [n]Eigenvalue(f64) = undefined;
    var vs: [n * n]f64 = undefined;
    const separated = try geesx(f64, testing.allocator, .vectors, selectNegativeReal, .eigenvectors, n, &far, n, &w, &vs, n);

    // The same problem with an off-diagonal coupling the two.
    var coupled = [_]f64{ -1e-8, 0, 1, 1e-8 };
    const close = try geesx(f64, testing.allocator, .vectors, selectNegativeReal, .eigenvectors, n, &coupled, n, &w, &vs, n);

    try testing.expectEqual(@as(usize, 1), separated.selected);
    try testing.expectEqual(@as(usize, 1), close.selected);
    try testing.expect(close.subspace_condition < separated.subspace_condition);
}

test "geesx without a predicate still factors, and selects nothing" {
    const n = 3;
    var a = [_]f64{ 1, 2, 0, 3, 4, 1, 0, 2, 5 };
    var w: [n]Eigenvalue(f64) = undefined;
    var vs: [n * n]f64 = undefined;

    const res = try geesx(f64, testing.allocator, .vectors, null, .none, n, &a, n, &w, &vs, n);
    try testing.expectEqual(@as(usize, 0), res.selected);

    // a now holds the quasi-triangular Schur form: nothing below the first
    // subdiagonal.
    for (0..n) |j| for (0..n) |i| {
        if (i > j + 1) try testing.expectApproxEqAbs(@as(f64, 0), a[i + j * n], 1e-12);
    };
}

test "geesx on a complex matrix takes rwork where the real one takes iwork" {
    const Z = Complex(f64);
    const n = 3;
    var a = [_]Z{
        Z.init(-1, 0), Z.init(0, 0), Z.init(0, 0),
        Z.init(0, 0),  Z.init(2, 1), Z.init(0, 0),
        Z.init(0, 0),  Z.init(0, 0), Z.init(3, 0),
    };
    var w: [n]Eigenvalue(Z) = undefined;
    var vs: [n * n]Z = undefined;

    const S = struct {
        fn negative(value: Eigenvalue(Z)) bool {
            return value.re < 0;
        }
    };
    const res = try geesx(Z, testing.allocator, .vectors, S.negative, .both, n, &a, n, &w, &vs, n);
    try testing.expectEqual(@as(usize, 1), res.selected);
    try testing.expectApproxEqAbs(@as(f64, -1), w[0].re, 1e-12);
}
