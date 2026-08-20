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
const EigSide = types.EigSide;
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
// The Schur toolkit
// ============================================================================

/// What `hseqr` should compute.
pub const SchurJob = enum(u8) {
    /// Eigenvalues only. `h` is destroyed and holds nothing useful.
    eigenvalues = 'E',
    /// The full Schur form, left in `h`.
    schur_form = 'S',
};

/// What to do with the Schur vector matrix.
pub const SchurVectors = enum(u8) {
    /// Do not compute them.
    none = 'N',
    /// Start from the identity, so `z` receives the Schur vectors of the
    /// Hessenberg matrix.
    identity = 'I',
    /// Start from what `z` already holds — normally `reduce.orghr`'s output —
    /// so `z` receives the Schur vectors of the *original* matrix.
    accumulate = 'V',
};

/// Which eigenvectors a `trevc`/`trsna`/`hsein` call is about.
pub const HowMany = enum(u8) {
    /// All of them.
    all = 'A',
    /// All of them, back-transformed by the matrix already in `vl`/`vr`. Turns
    /// eigenvectors of the Schur form into eigenvectors of the original.
    backtransform = 'B',
    /// Only those marked in `select`.
    selected = 'S',
};

/// Where `hsein` should take its eigenvalues from.
pub const EigenSource = enum(u8) {
    /// The `w` array holds exact eigenvalues of `h`, from `hseqr`. Lets the
    /// routine group nearby eigenvalues and orthogonalize their vectors.
    hseqr = 'Q',
    /// The `w` array is approximate and unrelated to any grouping.
    other = 'N',
};

/// Whether `hsein` should start inverse iteration from a supplied vector.
pub const InitialVectors = enum(u8) {
    /// Start from a routine-chosen vector.
    none = 'N',
    /// `vl`/`vr` already hold starting vectors.
    user = 'U',
};

/// LAPACK's selection mask, which is an array of Fortran logicals.
///
/// `Bool` is `Int`-wide under ILP64, so a Zig `[]bool` cannot be handed over
/// directly. This copies in, and copies back afterwards because the *real*
/// routines write to it: selecting one half of a conjugate pair makes them
/// select the other half too, and silently dropping that would leave the caller
/// thinking it asked for fewer vectors than it got.
const SelectMask = struct {
    buf: []Bool,
    allocator: Allocator,

    fn init(allocator: Allocator, mask: []const bool) !SelectMask {
        const buf = try allocator.alloc(Bool, @max(mask.len, 1));
        for (mask, 0..) |v, i| buf[i] = if (v) 1 else 0;
        return .{ .buf = buf, .allocator = allocator };
    }

    fn writeBack(self: SelectMask, mask: []bool) void {
        for (mask, 0..) |*v, i| v.* = self.buf[i] != 0;
    }

    fn deinit(self: SelectMask) void {
        self.allocator.free(self.buf);
    }
};

/// Eigenvalues, and optionally the Schur form, of an upper Hessenberg matrix.
///
/// The QR iteration `geev` and `gees` run internally, exposed for when you have
/// already reduced with `reduce.gehrd` and want to drive the rest yourself.
///
/// `ilo` and `ihi` are 1-based inclusive and come from `reduce.gebal`; pass
/// `1, n` if the matrix was not balanced. With `compz = .accumulate`, `z` must
/// hold `reduce.orghr`'s output so the Schur vectors come back in the original
/// basis.
///
/// `error.NoConvergence` means the iteration failed; `lastInfo()` is the index
/// past which eigenvalues *did* converge, so `w[lastInfo()..]` is usable.
pub fn hseqr(
    comptime T: type,
    allocator: Allocator,
    job: SchurJob,
    compz: SchurVectors,
    n: usize,
    ilo: usize,
    ihi: usize,
    h: []T,
    ldh: usize,
    w: []Eigenvalue(T),
    z: []T,
    ldz: usize,
) Fail!void {
    assertMatrix(h.len, n, n, ldh);
    std.debug.assert(w.len >= n);
    if (compz != .none) assertMatrix(z.len, n, n, ldz);

    const n_ = dim(n);
    const ilo_ = dim(ilo);
    const ihi_ = dim(ihi);
    const ldh_ = dim(@max(ldh, 1));
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    var probe: [1]T = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        sym(T, "hseqr")(opt(job), opt(compz), ref(&n_), ref(&ilo_), ref(&ihi_), &probe, ref(&ldh_), &probe, &probe, ref(&ldz_), &wq, ref(&neg), out(&info));
    } else {
        sym(T, "hseqr")(opt(job), opt(compz), ref(&n_), ref(&ilo_), ref(&ihi_), &probe, ref(&ldh_), &probe, &probe, &probe, ref(&ldz_), &wq, ref(&neg), out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), @as(Int, @intCast(@max(n, 1)))));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexElement(T)) {
        sym(T, "hseqr")(opt(job), opt(compz), ref(&n_), ref(&ilo_), ref(&ihi_), h.ptr, ref(&ldh_), @ptrCast(w.ptr), z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), out(&info));
    } else {
        const wr = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(wr);
        const wi = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(wi);
        sym(T, "hseqr")(opt(job), opt(compz), ref(&n_), ref(&ilo_), ref(&ihi_), h.ptr, ref(&ldh_), wr.ptr, wi.ptr, z.ptr, ref(&ldz_), buf.ptr, ref(&lwork), out(&info));
        for (0..n) |i| w[i] = .{ .re = wr[i], .im = wi[i] };
    }
    return info_mod.checkConvergence(info);
}

/// Selected eigenvectors of an upper Hessenberg matrix, by inverse iteration.
///
/// Cheaper than `trevc` when only a few vectors are wanted, because it works on
/// the Hessenberg matrix directly instead of needing a Schur form first.
///
/// `select` marks which eigenvalues to compute vectors for and is written back:
/// the real routine sets the partner of any selected member of a conjugate pair.
/// `w` is also in/out for real `T` — the routine may perturb an eigenvalue to
/// separate it from its neighbours.
///
/// `mm` is the number of columns available in `vl`/`vr`; a conjugate pair takes
/// two. The return is how many were actually filled. `ifaill`/`ifailr` receive
/// a nonzero entry for each vector that did not converge and need `mm` entries.
pub fn hsein(
    comptime T: type,
    allocator: Allocator,
    side: EigSide,
    source: EigenSource,
    initial: InitialVectors,
    select: []bool,
    n: usize,
    h: []const T,
    ldh: usize,
    w: []Eigenvalue(T),
    vl: []T,
    ldvl: usize,
    vr: []T,
    ldvr: usize,
    mm: usize,
    ifaill: []Int,
    ifailr: []Int,
) Fail!usize {
    assertMatrix(h.len, n, n, ldh);
    std.debug.assert(select.len >= n and w.len >= n);
    std.debug.assert(ifaill.len >= mm and ifailr.len >= mm);

    const mask = try SelectMask.init(allocator, select);
    defer mask.deinit();

    const n_ = dim(n);
    const ldh_ = dim(@max(ldh, 1));
    const ldvl_ = dim(@max(ldvl, 1));
    const ldvr_ = dim(@max(ldvr, 1));
    const mm_ = dim(mm);
    var m: Int = 0;
    var info: Int = 0;

    if (comptime complexElement(T)) {
        const buf = try allocator.alloc(T, @max(n * n, 1));
        defer allocator.free(buf);
        const rwork = try allocator.alloc(Real(T), @max(n, 1));
        defer allocator.free(rwork);
        sym(T, "hsein")(opt(side), opt(source), opt(initial), mask.buf.ptr, ref(&n_), h.ptr, ref(&ldh_), @ptrCast(w.ptr), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), ref(&mm_), out(&m), buf.ptr, rwork.ptr, ifaill.ptr, ifailr.ptr, out(&info));
    } else {
        const buf = try allocator.alloc(T, @max((n + 2) * n, 1));
        defer allocator.free(buf);
        const wr = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(wr);
        const wi = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(wi);
        for (0..n) |i| {
            wr[i] = w[i].re;
            wi[i] = w[i].im;
        }
        sym(T, "hsein")(opt(side), opt(source), opt(initial), mask.buf.ptr, ref(&n_), h.ptr, ref(&ldh_), wr.ptr, wi.ptr, vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), ref(&mm_), out(&m), buf.ptr, ifaill.ptr, ifailr.ptr, out(&info));
        for (0..n) |i| w[i] = .{ .re = wr[i], .im = wi[i] };
    }
    mask.writeBack(select);

    try info_mod.checkConvergence(info);
    return @intCast(m);
}

/// Eigenvectors of an upper quasi-triangular (Schur) matrix.
///
/// With `howmny = .backtransform`, `vl`/`vr` must hold the Schur vectors on
/// entry and come back holding eigenvectors of the original matrix — that is
/// the step `geev` performs after `hseqr`.
///
/// `select` is only read for `howmny = .selected`, and is written back for real
/// `T` for the conjugate-pair reason described on `hsein`. The eigenvectors
/// come back in the packed real layout described in the module docs;
/// `unpackVectors` expands it.
///
/// This is the blocked implementation. `trevc` is the unblocked one, kept
/// because LAPACK still ships it, but there is no reason to prefer it.
pub fn trevc3(
    comptime T: type,
    allocator: Allocator,
    side: EigSide,
    howmny: HowMany,
    select: []bool,
    n: usize,
    t: []T,
    ldt: usize,
    vl: []T,
    ldvl: usize,
    vr: []T,
    ldvr: usize,
    mm: usize,
) Fail!usize {
    assertMatrix(t.len, n, n, ldt);
    if (howmny == .selected) std.debug.assert(select.len >= n);

    const mask = try SelectMask.init(allocator, if (howmny == .selected) select else &.{});
    defer mask.deinit();

    const n_ = dim(n);
    const ldt_ = dim(@max(ldt, 1));
    const ldvl_ = dim(@max(ldvl, 1));
    const ldvr_ = dim(@max(ldvr, 1));
    const mm_ = dim(mm);
    var m: Int = 0;
    var info: Int = 0;

    var wq: [1]T = undefined;
    var rq: [1]Real(T) = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        sym(T, "trevc3")(opt(side), opt(howmny), mask.buf.ptr, ref(&n_), t.ptr, ref(&ldt_), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), ref(&mm_), out(&m), &wq, ref(&neg), &rq, ref(&neg), out(&info));
    } else {
        sym(T, "trevc3")(opt(side), opt(howmny), mask.buf.ptr, ref(&n_), t.ptr, ref(&ldt_), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), ref(&mm_), out(&m), &wq, ref(&neg), out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), @as(Int, @intCast(@max(3 * n, 1)))));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexElement(T)) {
        const rsize: usize = @intCast(@max(work_mod.sizeFrom(Real(T), rq[0]), @as(Int, @intCast(@max(n, 1)))));
        const rwork = try allocator.alloc(Real(T), rsize);
        defer allocator.free(rwork);
        const lrwork = dim(rsize);
        sym(T, "trevc3")(opt(side), opt(howmny), mask.buf.ptr, ref(&n_), t.ptr, ref(&ldt_), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), ref(&mm_), out(&m), buf.ptr, ref(&lwork), rwork.ptr, ref(&lrwork), out(&info));
    } else {
        sym(T, "trevc3")(opt(side), opt(howmny), mask.buf.ptr, ref(&n_), t.ptr, ref(&ldt_), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), ref(&mm_), out(&m), buf.ptr, ref(&lwork), out(&info));
    }
    if (howmny == .selected) mask.writeBack(select);

    try info_mod.checkArgs(info);
    return @intCast(m);
}

/// The unblocked `trevc3`. Same result, no workspace query, slower for large
/// `n`.
pub fn trevc(
    comptime T: type,
    allocator: Allocator,
    side: EigSide,
    howmny: HowMany,
    select: []bool,
    n: usize,
    t: []T,
    ldt: usize,
    vl: []T,
    ldvl: usize,
    vr: []T,
    ldvr: usize,
    mm: usize,
) Fail!usize {
    assertMatrix(t.len, n, n, ldt);
    if (howmny == .selected) std.debug.assert(select.len >= n);

    const mask = try SelectMask.init(allocator, if (howmny == .selected) select else &.{});
    defer mask.deinit();

    const n_ = dim(n);
    const ldt_ = dim(@max(ldt, 1));
    const ldvl_ = dim(@max(ldvl, 1));
    const ldvr_ = dim(@max(ldvr, 1));
    const mm_ = dim(mm);
    var m: Int = 0;
    var info: Int = 0;

    if (comptime complexElement(T)) {
        const buf = try allocator.alloc(T, @max(2 * n, 1));
        defer allocator.free(buf);
        const rwork = try allocator.alloc(Real(T), @max(n, 1));
        defer allocator.free(rwork);
        sym(T, "trevc")(opt(side), opt(howmny), mask.buf.ptr, ref(&n_), t.ptr, ref(&ldt_), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), ref(&mm_), out(&m), buf.ptr, rwork.ptr, out(&info));
    } else {
        const buf = try allocator.alloc(T, @max(3 * n, 1));
        defer allocator.free(buf);
        sym(T, "trevc")(opt(side), opt(howmny), mask.buf.ptr, ref(&n_), t.ptr, ref(&ldt_), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), ref(&mm_), out(&m), buf.ptr, out(&info));
    }
    if (howmny == .selected) mask.writeBack(select);

    try info_mod.checkArgs(info);
    return @intCast(m);
}

/// Where a `trexc` reorder ended up.
pub const ReorderResult = struct {
    /// The 1-based row the block actually started at. For real `T` this can
    /// differ from what you asked for, because a 2x2 block cannot be split.
    from: usize,
    /// The 1-based row it ended at, likewise adjusted.
    to: usize,
};

/// Moves one diagonal block of a Schur form to another position.
///
/// `ifst` and `ilst` are 1-based. For a real Schur form the diagonal blocks may
/// be 2x2, and a requested index pointing into the middle of one is snapped to
/// its start — which is why this returns where the block *actually* went rather
/// than nothing.
///
/// `compq` says whether to update the Schur vectors alongside; passing `.none`
/// leaves `q` untouched and makes the factorization inconsistent with it, which
/// is only what you want if you are not keeping `q`.
pub fn trexc(
    comptime T: type,
    allocator: Allocator,
    compq: SchurVectors,
    n: usize,
    t: []T,
    ldt: usize,
    q: []T,
    ldq: usize,
    ifst: usize,
    ilst: usize,
) Fail!ReorderResult {
    assertMatrix(t.len, n, n, ldt);
    std.debug.assert(ifst >= 1 and ifst <= @max(n, 1));
    std.debug.assert(ilst >= 1 and ilst <= @max(n, 1));
    if (compq != .none) assertMatrix(q.len, n, n, ldq);

    const n_ = dim(n);
    const ldt_ = dim(@max(ldt, 1));
    const ldq_ = dim(@max(ldq, 1));
    var ifst_ = dim(ifst);
    var ilst_ = dim(ilst);
    var info: Int = 0;

    if (comptime complexElement(T)) {
        // The complex form has no 2x2 blocks to snap to, so ifst and ilst are
        // inputs only and there is no workspace.
        sym(T, "trexc")(opt(compq), ref(&n_), t.ptr, ref(&ldt_), q.ptr, ref(&ldq_), ref(&ifst_), ref(&ilst_), out(&info));
    } else {
        const buf = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(buf);
        sym(T, "trexc")(opt(compq), ref(&n_), t.ptr, ref(&ldt_), q.ptr, ref(&ldq_), out(&ifst_), out(&ilst_), buf.ptr, out(&info));
    }
    try info_mod.checkArgs(info);
    return .{ .from = @intCast(ifst_), .to = @intCast(ilst_) };
}

/// What `trsen` computed.
pub const ReorderedSchur = struct {
    /// How many eigenvalues were selected, and therefore the order of the
    /// leading block of the reordered Schur form.
    selected: usize,
    /// Reciprocal condition number of the average of the selected cluster.
    /// Written only when `job` asks for it.
    cluster_condition: f64,
    /// Reciprocal condition number of the selected invariant subspace.
    subspace_condition: f64,
    /// True when `info` came back as `1`: reordering failed and the selected
    /// eigenvalues could not be separated, so `t` and `q` are back to a valid
    /// Schur factorization but of a differently ordered matrix.
    reorder_failed: bool,
};

/// Reorders a Schur form so the selected eigenvalues come first, and estimates
/// how well conditioned that split is.
///
/// The general-purpose invariant-subspace tool: `geesx` does the same thing but
/// only from scratch, where this works on a factorization you already have and
/// takes an explicit mask rather than a predicate.
///
/// `job = .none` reorders without estimating; `.eigenvalues` and `.eigenvectors`
/// add the cluster and subspace condition numbers respectively.
pub fn trsen(
    comptime T: type,
    allocator: Allocator,
    job: Sense,
    compq: SchurVectors,
    select: []const bool,
    n: usize,
    t: []T,
    ldt: usize,
    q: []T,
    ldq: usize,
    w: []Eigenvalue(T),
) Fail!ReorderedSchur {
    assertMatrix(t.len, n, n, ldt);
    std.debug.assert(select.len >= n and w.len >= n);
    if (compq != .none) assertMatrix(q.len, n, n, ldq);

    const mask = try SelectMask.init(allocator, select);
    defer mask.deinit();

    const n_ = dim(n);
    const ldt_ = dim(@max(ldt, 1));
    const ldq_ = dim(@max(ldq, 1));
    var m: Int = 0;
    var s: Real(T) = 0;
    var sep: Real(T) = 0;
    var info: Int = 0;

    var probe: [1]T = undefined;
    var wq: [1]T = undefined;
    var iq: [1]Int = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        sym(T, "trsen")(opt(job), opt(compq), mask.buf.ptr, ref(&n_), &probe, ref(&ldt_), &probe, ref(&ldq_), &probe, out(&m), out(&s), out(&sep), &wq, ref(&neg), out(&info));
    } else {
        sym(T, "trsen")(opt(job), opt(compq), mask.buf.ptr, ref(&n_), &probe, ref(&ldt_), &probe, ref(&ldq_), &probe, &probe, out(&m), out(&s), out(&sep), &wq, ref(&neg), &iq, ref(&neg), out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexElement(T)) {
        sym(T, "trsen")(opt(job), opt(compq), mask.buf.ptr, ref(&n_), t.ptr, ref(&ldt_), q.ptr, ref(&ldq_), @ptrCast(w.ptr), out(&m), out(&s), out(&sep), buf.ptr, ref(&lwork), out(&info));
    } else {
        const iwork = try allocator.alloc(Int, @intCast(@max(iq[0], 1)));
        defer allocator.free(iwork);
        const liwork = dim(iwork.len);
        const wr = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(wr);
        const wi = try allocator.alloc(T, @max(n, 1));
        defer allocator.free(wi);
        sym(T, "trsen")(opt(job), opt(compq), mask.buf.ptr, ref(&n_), t.ptr, ref(&ldt_), q.ptr, ref(&ldq_), wr.ptr, wi.ptr, out(&m), out(&s), out(&sep), buf.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
        for (0..n) |i| w[i] = .{ .re = wr[i], .im = wi[i] };
    }

    const failed = info == 1;
    if (!failed) try info_mod.checkArgs(info);
    return .{
        .selected = @intCast(m),
        .cluster_condition = s,
        .subspace_condition = sep,
        .reorder_failed = failed,
    };
}

/// Condition numbers for individual eigenvalues and eigenvectors of a Schur
/// form.
///
/// Where `trsen` conditions a *cluster* as a whole, this conditions each
/// eigenvalue and eigenvector separately. `s[i]` is the reciprocal condition
/// number of eigenvalue `i` and `sep[i]` the separation governing eigenvector
/// `i`; both arrays need `mm` entries.
///
/// `vl` and `vr` must hold the left and right eigenvectors — from `trevc3` —
/// and are read, not written. Passing Schur vectors instead gives a confident
/// wrong answer.
pub fn trsna(
    comptime T: type,
    allocator: Allocator,
    job: Sense,
    howmny: HowMany,
    select: []const bool,
    n: usize,
    t: []const T,
    ldt: usize,
    vl: []const T,
    ldvl: usize,
    vr: []const T,
    ldvr: usize,
    s: []Real(T),
    sep: []Real(T),
    mm: usize,
) Fail!usize {
    assertMatrix(t.len, n, n, ldt);
    if (howmny == .selected) std.debug.assert(select.len >= n);
    if (job != .eigenvectors) std.debug.assert(s.len >= mm);
    if (job != .eigenvalues) std.debug.assert(sep.len >= mm);

    const mask = try SelectMask.init(allocator, if (howmny == .selected) select else &.{});
    defer mask.deinit();

    const n_ = dim(n);
    const ldt_ = dim(@max(ldt, 1));
    const ldvl_ = dim(@max(ldvl, 1));
    const ldvr_ = dim(@max(ldvr, 1));
    const mm_ = dim(mm);
    // Both variants want an (n + 6) x (n + 6) scratch when eigenvectors are
    // being conditioned, and none at all otherwise. The larger size is always
    // allocated; the difference is not worth an extra branch.
    const ldwork = @max(n + 6, 1);
    var m: Int = 0;
    var info: Int = 0;

    const buf = try allocator.alloc(T, ldwork * ldwork);
    defer allocator.free(buf);
    const ldwork_ = dim(ldwork);

    if (comptime complexElement(T)) {
        const rwork = try allocator.alloc(Real(T), @max(n, 1));
        defer allocator.free(rwork);
        sym(T, "trsna")(opt(job), opt(howmny), mask.buf.ptr, ref(&n_), t.ptr, ref(&ldt_), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), s.ptr, sep.ptr, ref(&mm_), out(&m), buf.ptr, ref(&ldwork_), rwork.ptr, out(&info));
    } else {
        const iwork = try allocator.alloc(Int, @max(2 * (n - @min(n, 1)), 1));
        defer allocator.free(iwork);
        sym(T, "trsna")(opt(job), opt(howmny), mask.buf.ptr, ref(&n_), t.ptr, ref(&ldt_), vl.ptr, ref(&ldvl_), vr.ptr, ref(&ldvr_), s.ptr, sep.ptr, ref(&mm_), out(&m), buf.ptr, ref(&ldwork_), iwork.ptr, out(&info));
    }
    try info_mod.checkArgs(info);
    return @intCast(m);
}

/// `trsyl`, blocked.
///
/// Same problem, same result, a recursive blocked algorithm underneath. Worth
/// preferring for large `m` and `n`; identical otherwise.
pub fn trsyl3(
    comptime T: type,
    allocator: Allocator,
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
) Fail!SylvesterResult {
    std.debug.assert(isgn == 1 or isgn == -1);
    assertMatrix(a.len, m, m, lda);
    assertMatrix(b.len, n, n, ldb);
    assertMatrix(cm.len, m, n, ldc);

    const isgn_: Int = isgn;
    const m_ = dim(m);
    const n_ = dim(n);
    const lda_ = dim(@max(lda, 1));
    const ldb_ = dim(@max(ldb, 1));
    const ldc_ = dim(@max(ldc, 1));
    var scale: Real(T) = 0;
    var info: Int = 0;

    if (comptime complexElement(T)) {
        const swork = try allocator.alloc(Real(T), @max(m + n, 2));
        defer allocator.free(swork);
        sym(T, "trsyl3")(opt(trana), opt(tranb), ref(&isgn_), ref(&m_), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), cm.ptr, ref(&ldc_), out(&scale), swork.ptr, out(&info));
    } else {
        // The real routine takes an integer workspace and a 2D real one whose
        // shape it will report if asked; the documented minimum is what the
        // unblocked path needs, and the routine falls back to it.
        const iwork = try allocator.alloc(Int, @max(m + n + 2, 2));
        defer allocator.free(iwork);
        const liwork = dim(iwork.len);
        const ldswork = @max(m + n, 2);
        const swork = try allocator.alloc(T, ldswork * ldswork);
        defer allocator.free(swork);
        // ldswork is declared non-const in the header, so it goes through a
        // mutable local even though it is an input here.
        var ldswork_ = dim(ldswork);
        sym(T, "trsyl3")(opt(trana), opt(tranb), ref(&isgn_), ref(&m_), ref(&n_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), cm.ptr, ref(&ldc_), out(&scale), iwork.ptr, ref(&liwork), swork.ptr, out(&ldswork_), out(&info));
    }

    const perturbed = info == 1;
    if (!perturbed) try info_mod.checkArgs(info);
    return .{ .scale = scale, .perturbed = perturbed };
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

// ============================================================================
// Tests: the Schur toolkit
// ============================================================================

/// A 4x4 with two real and one complex conjugate pair of eigenvalues, so the
/// real packed layouts below are actually exercised.
const schur4 = [_]f64{
    4, 1,  0, 0,
    1, 3,  1, 0,
    0, -2, 1, 1,
    0, 0,  1, 2,
};

test "reduce.gehrd then hseqr reproduces what geev computes in one call" {
    const n = 4;
    var direct = schur4;
    var w_direct: [n]Eigenvalue(f64) = undefined;
    var dummy: [1]f64 = undefined;
    try geev(f64, testing.allocator, .values_only, .values_only, n, &direct, n, &w_direct, &dummy, 1, &dummy, 1);

    var h = schur4;
    var tau: [n - 1]f64 = undefined;
    try reduce.gehrd(f64, testing.allocator, n, 1, n, &h, n, &tau);
    var z = h;
    try reduce.orghr(f64, testing.allocator, n, 1, n, &z, n, &tau);

    var w: [n]Eigenvalue(f64) = undefined;
    try hseqr(f64, testing.allocator, .schur_form, .accumulate, n, 1, n, &h, n, &w, &z, n);

    // Same spectrum, possibly in a different order.
    for (w_direct) |a| {
        var matched = false;
        for (w) |b| {
            if (@abs(a.re - b.re) < 1e-10 and @abs(a.im - b.im) < 1e-10) matched = true;
        }
        try testing.expect(matched);
    }

    // h is the Schur form: nothing below the first subdiagonal.
    for (0..n) |j| for (0..n) |i| {
        if (i > j + 1) try testing.expectApproxEqAbs(@as(f64, 0), h[i + j * n], 1e-11);
    };
}

test "trevc3 back-transforms Schur vectors into eigenvectors" {
    const n = 4;
    var h = schur4;
    var tau: [n - 1]f64 = undefined;
    try reduce.gehrd(f64, testing.allocator, n, 1, n, &h, n, &tau);
    var z = h;
    try reduce.orghr(f64, testing.allocator, n, 1, n, &z, n, &tau);
    var w: [n]Eigenvalue(f64) = undefined;
    try hseqr(f64, testing.allocator, .schur_form, .accumulate, n, 1, n, &h, n, &w, &z, n);

    // vr starts as the Schur vectors and comes back as eigenvectors of the
    // original matrix - that is what .backtransform means.
    var vr = z;
    var select = [_]bool{false} ** n;
    var dummy: [1]f64 = undefined;
    const m = try trevc3(f64, testing.allocator, .right, .backtransform, &select, n, &h, n, &dummy, 1, &vr, n, n);
    try testing.expectEqual(@as(usize, n), m);

    // Expand the packed layout and check A v = lambda v.
    var v: [n * n]Eigenvalue(f64) = undefined;
    unpackVectors(f64, n, &w, &vr, n, &v, n);
    for (0..n) |j| {
        for (0..n) |i| {
            var acc = Eigenvalue(f64){ .re = 0, .im = 0 };
            for (0..n) |k| {
                acc.re += schur4[i + k * n] * v[k + j * n].re;
                acc.im += schur4[i + k * n] * v[k + j * n].im;
            }
            const expected = Eigenvalue(f64){
                .re = w[j].re * v[i + j * n].re - w[j].im * v[i + j * n].im,
                .im = w[j].re * v[i + j * n].im + w[j].im * v[i + j * n].re,
            };
            try testing.expectApproxEqAbs(expected.re, acc.re, 1e-10);
            try testing.expectApproxEqAbs(expected.im, acc.im, 1e-10);
        }
    }
}

test "trevc agrees with trevc3" {
    const n = 4;
    var h = schur4;
    var tau: [n - 1]f64 = undefined;
    try reduce.gehrd(f64, testing.allocator, n, 1, n, &h, n, &tau);
    var w: [n]Eigenvalue(f64) = undefined;
    var z: [1]f64 = undefined;
    try hseqr(f64, testing.allocator, .schur_form, .none, n, 1, n, &h, n, &w, &z, 1);

    var select = [_]bool{false} ** n;
    var dummy: [1]f64 = undefined;

    var v3: [n * n]f64 = undefined;
    const m3 = try trevc3(f64, testing.allocator, .right, .all, &select, n, &h, n, &dummy, 1, &v3, n, n);
    var v1: [n * n]f64 = undefined;
    const m1 = try trevc(f64, testing.allocator, .right, .all, &select, n, &h, n, &dummy, 1, &v1, n, n);

    try testing.expectEqual(m3, m1);
    for (v3, v1) |a, b| try testing.expectApproxEqAbs(a, b, 1e-12);
}

test "trevc3 selecting one half of a conjugate pair writes back the other" {
    const n = 4;
    var h = schur4;
    var tau: [n - 1]f64 = undefined;
    try reduce.gehrd(f64, testing.allocator, n, 1, n, &h, n, &tau);
    var w: [n]Eigenvalue(f64) = undefined;
    var z: [1]f64 = undefined;
    try hseqr(f64, testing.allocator, .schur_form, .none, n, 1, n, &h, n, &w, &z, 1);

    // Find one member of the complex pair.
    var pair: ?usize = null;
    for (w, 0..) |v, i| {
        if (v.im > 0) pair = i;
    }
    try testing.expect(pair != null);

    // Select the *second* member of the pair. LAPACK's convention is that a
    // pair is requested through its first entry, so the routine moves the flag.
    var select = [_]bool{false} ** n;
    select[pair.? + 1] = true;
    var v: [n * n]f64 = undefined;
    var dummy: [1]f64 = undefined;
    const m = try trevc3(f64, testing.allocator, .right, .selected, &select, n, &h, n, &dummy, 1, &v, n, n);

    // A conjugate pair costs two columns and cannot be split, so asking for one
    // gets two. The mask comes back normalized: the flag has moved to the first
    // entry of the pair and the second is cleared. Dropping that write-back
    // would leave a caller indexing the output columns by its own mask, which
    // now disagrees with LAPACK's.
    try testing.expectEqual(@as(usize, 2), m);
    try testing.expect(select[pair.?]);
    try testing.expect(!select[pair.? + 1]);
}

test "trexc moves a block and reports where it landed" {
    const n = 4;
    // Upper triangular with distinct diagonal, so every block is 1x1 and the
    // requested indices are used unchanged.
    var t = [_]f64{
        1, 0, 0, 0,
        5, 2, 0, 0,
        6, 7, 3, 0,
        8, 9, 1, 4,
    };
    var q = [_]f64{0} ** (n * n);
    for (0..n) |i| q[i + i * n] = 1;

    const res = try trexc(f64, testing.allocator, .accumulate, n, &t, n, &q, n, 4, 1);
    try testing.expectEqual(@as(usize, 4), res.from);
    try testing.expectEqual(@as(usize, 1), res.to);
    // The eigenvalue that was last is now first.
    try testing.expectApproxEqAbs(@as(f64, 4), t[0], 1e-12);
}

test "trexc snaps an index that points into the middle of a 2x2 block" {
    const n = 4;
    var h = schur4;
    var tau: [n - 1]f64 = undefined;
    try reduce.gehrd(f64, testing.allocator, n, 1, n, &h, n, &tau);
    var q = h;
    try reduce.orghr(f64, testing.allocator, n, 1, n, &q, n, &tau);
    var w: [n]Eigenvalue(f64) = undefined;
    try hseqr(f64, testing.allocator, .schur_form, .accumulate, n, 1, n, &h, n, &w, &q, n);

    // Find the 2x2 block: its second row has a nonzero subdiagonal entry.
    var block: ?usize = null;
    for (0..n - 1) |i| {
        if (@abs(h[i + 1 + i * n]) > 1e-10) block = i;
    }
    try testing.expect(block != null);

    // Ask to move starting from the *second* row of the block. The routine
    // cannot split it, so it reports the row it actually used.
    const res = try trexc(f64, testing.allocator, .accumulate, n, &h, n, &q, n, block.? + 2, 1);
    try testing.expectEqual(@as(usize, 1), res.to);
    try testing.expectEqual(block.? + 1, res.from);
}

test "trsen reorders a cluster and conditions it" {
    const n = 4;
    var t = [_]f64{
        -1, 0,  0, 0,
        0,  -2, 0, 0,
        0,  0,  3, 0,
        0,  0,  0, 4,
    };
    var q = [_]f64{0} ** (n * n);
    for (0..n) |i| q[i + i * n] = 1;
    var w: [n]Eigenvalue(f64) = undefined;

    // Already leading, but the condition numbers are the point.
    const select = [_]bool{ true, true, false, false };
    const res = try trsen(f64, testing.allocator, .both, .accumulate, &select, n, &t, n, &q, n, &w);

    try testing.expectEqual(@as(usize, 2), res.selected);
    try testing.expect(!res.reorder_failed);
    try testing.expect(res.cluster_condition > 0.5);
    try testing.expect(res.subspace_condition > 0);
}

test "trsen moves a scattered selection to the front" {
    const n = 4;
    var t = [_]f64{
        1, 0, 0, 0,
        0, 2, 0, 0,
        0, 0, 3, 0,
        0, 0, 0, 4,
    };
    var q = [_]f64{0} ** (n * n);
    for (0..n) |i| q[i + i * n] = 1;
    var w: [n]Eigenvalue(f64) = undefined;

    const select = [_]bool{ false, true, false, true };
    const res = try trsen(f64, testing.allocator, .none, .accumulate, &select, n, &t, n, &q, n, &w);

    try testing.expectEqual(@as(usize, 2), res.selected);
    // The selected eigenvalues 2 and 4 are now the leading block.
    try testing.expectApproxEqAbs(@as(f64, 2), t[0], 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 4), t[1 + n], 1e-12);
}

test "trsna conditions each eigenvalue separately" {
    const n = 3;
    // Diagonal but with two nearly equal entries: those two eigenvectors are
    // ill-conditioned while the eigenvalues themselves are not.
    var t = [_]f64{
        1, 0,        0,
        0, 1 + 1e-7, 0,
        0, 0,        10,
    };
    var select = [_]bool{ true, true, true };
    var vl: [n * n]f64 = undefined;
    var vr: [n * n]f64 = undefined;
    var t_copy = t;
    _ = try trevc3(f64, testing.allocator, .both, .all, &select, n, &t_copy, n, &vl, n, &vr, n, n);

    var s: [n]f64 = undefined;
    var sep: [n]f64 = undefined;
    const m = try trsna(f64, testing.allocator, .both, .all, &select, n, &t, n, &vl, n, &vr, n, &s, &sep, n);

    try testing.expectEqual(@as(usize, n), m);
    // Diagonal, so every eigenvalue is perfectly conditioned.
    for (s) |v| try testing.expectApproxEqAbs(@as(f64, 1), v, 1e-12);
    // The two close eigenvalues have a tiny separation; the far one does not.
    try testing.expect(sep[0] < 1e-6);
    try testing.expect(sep[1] < 1e-6);
    try testing.expect(sep[2] > 1);
}

test "hsein computes selected eigenvectors straight from the Hessenberg form" {
    const n = 4;
    var h = schur4;
    var tau: [n - 1]f64 = undefined;
    try reduce.gehrd(f64, testing.allocator, n, 1, n, &h, n, &tau);
    // Zero the reflectors so h is a clean Hessenberg matrix.
    for (0..n) |j| for (0..n) |i| {
        if (i > j + 1) h[i + j * n] = 0;
    };
    const hess = h;

    var eig = h;
    var w: [n]Eigenvalue(f64) = undefined;
    var z: [1]f64 = undefined;
    try hseqr(f64, testing.allocator, .eigenvalues, .none, n, 1, n, &eig, n, &w, &z, 1);

    // Pick the first real eigenvalue.
    var idx: ?usize = null;
    for (w, 0..) |v, i| {
        if (v.im == 0 and idx == null) idx = i;
    }
    try testing.expect(idx != null);

    var select = [_]bool{false} ** n;
    select[idx.?] = true;
    var h_in = hess;
    var vr: [n * n]f64 = undefined;
    var vl: [1]f64 = undefined;
    var ifaill: [n]Int = undefined;
    var ifailr: [n]Int = undefined;
    const m = try hsein(f64, testing.allocator, .right, .hseqr, .none, &select, n, &h_in, n, &w, &vl, 1, &vr, n, n, &ifaill, &ifailr);

    try testing.expectEqual(@as(usize, 1), m);
    // H v = lambda v against the Hessenberg matrix, which hsein worked on.
    const lambda = w[idx.?].re;
    for (0..n) |i| {
        var acc: f64 = 0;
        for (0..n) |k| acc += hess[i + k * n] * vr[k];
        try testing.expectApproxEqAbs(lambda * vr[i], acc, 1e-9);
    }
}

test "trsyl3 agrees with trsyl" {
    const m = 2;
    const n = 2;
    const a = [_]f64{ 1, 0, 2, 3 };
    const b = [_]f64{ 5, 0, 1, 7 };
    const c0 = [_]f64{ 1, 2, 3, 4 };

    var c1 = c0;
    const r1 = try trsyl(f64, .no_trans, .no_trans, 1, m, n, &a, m, &b, n, &c1, m);
    var c3 = c0;
    const r3 = try trsyl3(f64, testing.allocator, .no_trans, .no_trans, 1, m, n, &a, m, &b, n, &c3, m);

    try testing.expectApproxEqAbs(r1.scale, r3.scale, 1e-15);
    for (c1, c3) |x, y| try testing.expectApproxEqAbs(x, y, 1e-12);
}

test "the complex Schur toolkit takes no iwork where the real one does" {
    const Z = Complex(f64);
    const n = 3;
    var t = [_]Z{
        Z.init(1, 0), Z.init(0, 0), Z.init(0, 0),
        Z.init(2, 0), Z.init(5, 0), Z.init(0, 0),
        Z.init(3, 0), Z.init(4, 0), Z.init(9, 0),
    };
    var q = [_]Z{Z.init(0, 0)} ** (n * n);
    for (0..n) |i| q[i + i * n] = Z.init(1, 0);
    var w: [n]Eigenvalue(Z) = undefined;

    const select = [_]bool{ false, false, true };
    const res = try trsen(Z, testing.allocator, .both, .accumulate, &select, n, &t, n, &q, n, &w);
    try testing.expectEqual(@as(usize, 1), res.selected);
    try testing.expectApproxEqAbs(@as(f64, 9), t[0].re, 1e-12);

    // trexc for complex takes ifst/ilst as inputs only - there are no 2x2
    // blocks to snap to - so the returned window is what was asked for.
    const moved = try trexc(Z, testing.allocator, .accumulate, n, &t, n, &q, n, 1, 3);
    try testing.expectEqual(@as(usize, 1), moved.from);
    try testing.expectEqual(@as(usize, 3), moved.to);
}
