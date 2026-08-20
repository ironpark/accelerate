//! Iterative refinement and error bounds.
//!
//! Every solver in this library returns an `x` without saying how much of it is
//! signal. These routines answer that: given the original matrix, its
//! factorization, the right-hand side and a computed solution, they improve `x`
//! and report two bounds per right-hand side.
//!
//! | bound | meaning |
//! |---|---|
//! | `ferr` | estimated `\|\|x_computed - x_true\|\| / \|\|x_true\|\|` |
//! | `berr` | smallest relative perturbation of `A` and `b` for which `x` is *exact* |
//!
//! `berr` is the honest one — it is a computed quantity, near machine epsilon
//! for any sane solve, and a large value means the solver misbehaved. `ferr` is
//! an *estimate* built from a condition-number bound; it is usually pessimistic
//! and can be optimistic for a very ill-conditioned problem. Treat `ferr` as an
//! order of magnitude, not a guarantee.
//!
//! ## These need both matrices
//!
//! Every routine here takes the original `A` **and** its factorization, because
//! it computes a residual against the original and then solves with the factor.
//! Since the factor routines overwrite their input, you have to copy the matrix
//! before factoring — `norms.lacpy` — or there is nothing left to refine
//! against. That is the whole reason these are separate calls rather than part
//! of the solvers.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");

const Int = types.Int;
const Complex = types.Complex;
const Real = types.Real;
const Uplo = types.Uplo;
const Trans = types.Trans;
const Diag = types.Diag;
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

fn requireComplex(comptime T: type, comptime routine: []const u8, comptime alternative: []const u8) void {
    switch (T) {
        Complex(f32), Complex(f64) => {},
        else => @compileError(routine ++ " is complex-only; for " ++ @typeName(T) ++ " use " ++ alternative),
    }
}

/// Allocates the two scratch buffers the `*rfs` routines want, whose shapes
/// differ between real and complex exactly as the `*con` routines' do.
fn Scratch(comptime T: type) type {
    return struct {
        const Self = @This();
        work: []T,
        iwork: []Int,
        rwork: []Real(T),
        allocator: Allocator,

        fn init(allocator: Allocator, n: usize) !Self {
            return switch (T) {
                Complex(f32), Complex(f64) => .{
                    .work = try allocator.alloc(T, @max(2 * n, 1)),
                    .iwork = &.{},
                    .rwork = try allocator.alloc(Real(T), @max(n, 1)),
                    .allocator = allocator,
                },
                else => .{
                    .work = try allocator.alloc(T, @max(3 * n, 1)),
                    .iwork = try allocator.alloc(Int, @max(n, 1)),
                    .rwork = &.{},
                    .allocator = allocator,
                },
            };
        }

        fn deinit(self: Self) void {
            if (self.work.len != 0) self.allocator.free(self.work);
            if (self.iwork.len != 0) self.allocator.free(self.iwork);
            if (self.rwork.len != 0) self.allocator.free(self.rwork);
        }
    };
}

/// Refines a solution of a general system and bounds its error.
///
/// `a` is the original matrix, `af`/`ipiv` the `getrf` factorization of it, `b`
/// the right-hand side and `x` the solution `getrs` produced. `x` is improved
/// in place.
///
/// `ferr` and `berr` each receive one value per right-hand side.
pub fn gerfs(
    comptime T: type,
    allocator: Allocator,
    trans: Trans,
    n: usize,
    nrhs: usize,
    a: []const T,
    lda: usize,
    af: []const T,
    ldaf: usize,
    ipiv: []const Int,
    b: []const T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(af.len, n, n, ldaf);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ipiv.len >= n);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const scratch = try Scratch(T).init(allocator, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldaf_ = dim(ldaf);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "gerfs")(opt(trans), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), af.ptr, ref(&ldaf_), ipiv.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "gerfs")(opt(trans), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), af.ptr, ref(&ldaf_), ipiv.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }
    return info_mod.checkArgs(info);
}

/// `gerfs` for a positive definite system factored by `potrf`.
pub fn porfs(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []const T,
    lda: usize,
    af: []const T,
    ldaf: usize,
    b: []const T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(af.len, n, n, ldaf);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const scratch = try Scratch(T).init(allocator, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldaf_ = dim(ldaf);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "porfs")(opt(uplo), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), af.ptr, ref(&ldaf_), b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "porfs")(opt(uplo), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), af.ptr, ref(&ldaf_), b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }
    return info_mod.checkArgs(info);
}

/// `gerfs` for a symmetric indefinite system factored by `sytrf`.
pub fn syrfs(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []const T,
    lda: usize,
    af: []const T,
    ldaf: usize,
    ipiv: []const Int,
    b: []const T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    return indefiniteRefine(T, "syrfs", allocator, uplo, n, nrhs, a, lda, af, ldaf, ipiv, b, ldb, x, ldx, ferr, berr);
}

/// `gerfs` for a Hermitian indefinite system factored by `hetrf`. Complex only.
pub fn herfs(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []const T,
    lda: usize,
    af: []const T,
    ldaf: usize,
    ipiv: []const Int,
    b: []const T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    requireComplex(T, "herfs", "syrfs");
    return indefiniteRefine(T, "herfs", allocator, uplo, n, nrhs, a, lda, af, ldaf, ipiv, b, ldb, x, ldx, ferr, berr);
}

fn indefiniteRefine(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []const T,
    lda: usize,
    af: []const T,
    ldaf: usize,
    ipiv: []const Int,
    b: []const T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(af.len, n, n, ldaf);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ipiv.len >= n);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const scratch = try Scratch(T).init(allocator, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldaf_ = dim(ldaf);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, name)(opt(uplo), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), af.ptr, ref(&ldaf_), ipiv.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, name)(opt(uplo), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), af.ptr, ref(&ldaf_), ipiv.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }
    return info_mod.checkArgs(info);
}

/// Error bounds for a triangular solve.
///
/// Unlike the others this takes no factorization, because a triangular matrix
/// already is one — and unlike the others it does **not** refine `x`, only
/// bound its error. `trtrs` is already about as accurate as a triangular solve
/// gets; there is nothing to improve.
pub fn trrfs(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    trans: Trans,
    diag: Diag,
    n: usize,
    nrhs: usize,
    a: []const T,
    lda: usize,
    b: []const T,
    ldb: usize,
    x: []const T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const scratch = try Scratch(T).init(allocator, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "trrfs")(opt(uplo), opt(trans), opt(diag), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "trrfs")(opt(uplo), opt(trans), opt(diag), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }
    return info_mod.checkArgs(info);
}

/// `gerfs` for a band system factored by `gbtrf`.
///
/// `ab` is the original band in the narrow `kl + ku + 1` layout; `afb` is the
/// factor in the wide `2*kl + ku + 1` one. They are different shapes and the
/// routine cannot tell them apart, so mixing them up is silent nonsense.
pub fn gbrfs(
    comptime T: type,
    allocator: Allocator,
    trans: Trans,
    n: usize,
    kl: usize,
    ku: usize,
    nrhs: usize,
    ab: []const T,
    ldab: usize,
    afb: []const T,
    ldafb: usize,
    ipiv: []const Int,
    b: []const T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    std.debug.assert(ldab >= kl + ku + 1);
    std.debug.assert(ldafb >= 2 * kl + ku + 1);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ipiv.len >= n);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const scratch = try Scratch(T).init(allocator, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const kl_ = dim(kl);
    const ku_ = dim(ku);
    const nrhs_ = dim(nrhs);
    const ldab_ = dim(ldab);
    const ldafb_ = dim(ldafb);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "gbrfs")(opt(trans), ref(&n_), ref(&kl_), ref(&ku_), ref(&nrhs_), ab.ptr, ref(&ldab_), afb.ptr, ref(&ldafb_), ipiv.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "gbrfs")(opt(trans), ref(&n_), ref(&kl_), ref(&ku_), ref(&nrhs_), ab.ptr, ref(&ldab_), afb.ptr, ref(&ldafb_), ipiv.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }
    return info_mod.checkArgs(info);
}

/// `gerfs` for a tridiagonal system factored by `gttrf`.
///
/// The first three diagonals are the original matrix; `dlf`/`df`/`duf`/`du2`
/// and `ipiv` are what `gttrf` produced from a *copy* of them.
pub fn gtrfs(
    comptime T: type,
    allocator: Allocator,
    trans: Trans,
    n: usize,
    nrhs: usize,
    dl: []const T,
    d: []const T,
    du: []const T,
    dlf: []const T,
    df: []const T,
    duf: []const T,
    du2: []const T,
    ipiv: []const Int,
    b: []const T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    std.debug.assert(d.len >= n and df.len >= n);
    std.debug.assert(ipiv.len >= n);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const scratch = try Scratch(T).init(allocator, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "gtrfs")(opt(trans), ref(&n_), ref(&nrhs_), dl.ptr, d.ptr, du.ptr, dlf.ptr, df.ptr, duf.ptr, du2.ptr, ipiv.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "gtrfs")(opt(trans), ref(&n_), ref(&nrhs_), dl.ptr, d.ptr, du.ptr, dlf.ptr, df.ptr, duf.ptr, du2.ptr, ipiv.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }
    return info_mod.checkArgs(info);
}

/// `porfs` for a positive definite band system factored by `pbtrf`.
///
/// Both band arrays use the same `kd + 1` layout here — unlike `gbrfs`, a
/// Cholesky of a band matrix creates no fill-in outside the band.
pub fn pbrfs(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    kd: usize,
    nrhs: usize,
    ab: []const T,
    ldab: usize,
    afb: []const T,
    ldafb: usize,
    b: []const T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    std.debug.assert(ldab >= kd + 1 and ldafb >= kd + 1);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const scratch = try Scratch(T).init(allocator, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const kd_ = dim(kd);
    const nrhs_ = dim(nrhs);
    const ldab_ = dim(ldab);
    const ldafb_ = dim(ldafb);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "pbrfs")(opt(uplo), ref(&n_), ref(&kd_), ref(&nrhs_), ab.ptr, ref(&ldab_), afb.ptr, ref(&ldafb_), b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "pbrfs")(opt(uplo), ref(&n_), ref(&kd_), ref(&nrhs_), ab.ptr, ref(&ldab_), afb.ptr, ref(&ldafb_), b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }
    return info_mod.checkArgs(info);
}

/// `porfs` in packed storage, from a `pptrf` factorization.
pub fn pprfs(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    ap: []const T,
    afp: []const T,
    b: []const T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    std.debug.assert(ap.len >= packedLen(n) and afp.len >= packedLen(n));
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const scratch = try Scratch(T).init(allocator, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "pprfs")(opt(uplo), ref(&n_), ref(&nrhs_), ap.ptr, afp.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "pprfs")(opt(uplo), ref(&n_), ref(&nrhs_), ap.ptr, afp.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }
    return info_mod.checkArgs(info);
}

/// `porfs` for a positive definite tridiagonal system factored by `pttrf`.
///
/// `uplo` says whether `e` holds the sub- or superdiagonal. **It is ignored for
/// a real `T`**: the real routine has no such argument, because a real
/// symmetric tridiagonal has the same off-diagonal either way. Only the complex
/// routine needs to know, since there the two differ by a conjugation.
pub fn ptrfs(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    d: []const Real(T),
    e: []const T,
    df: []const Real(T),
    ef: []const T,
    b: []const T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    std.debug.assert(d.len >= n and df.len >= n);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const scratch = try Scratch(T).init(allocator, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "ptrfs")(opt(uplo), ref(&n_), ref(&nrhs_), d.ptr, e.ptr, df.ptr, ef.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "ptrfs")(ref(&n_), ref(&nrhs_), d.ptr, e.ptr, df.ptr, ef.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, out(&info)),
    }
    return info_mod.checkArgs(info);
}

/// `syrfs` in packed storage, from an `sptrf` factorization.
pub fn sprfs(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    ap: []const T,
    afp: []const T,
    ipiv: []const Int,
    b: []const T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    return packedIndefiniteRefine(T, "sprfs", allocator, uplo, n, nrhs, ap, afp, ipiv, b, ldb, x, ldx, ferr, berr);
}

/// `herfs` in packed storage, from an `hptrf` factorization. Complex only.
pub fn hprfs(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    ap: []const T,
    afp: []const T,
    ipiv: []const Int,
    b: []const T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    requireComplex(T, "hprfs", "sprfs");
    return packedIndefiniteRefine(T, "hprfs", allocator, uplo, n, nrhs, ap, afp, ipiv, b, ldb, x, ldx, ferr, berr);
}

fn packedIndefiniteRefine(
    comptime T: type,
    comptime name: []const u8,
    allocator: Allocator,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    ap: []const T,
    afp: []const T,
    ipiv: []const Int,
    b: []const T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    std.debug.assert(ap.len >= packedLen(n) and afp.len >= packedLen(n));
    std.debug.assert(ipiv.len >= n);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const scratch = try Scratch(T).init(allocator, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, name)(opt(uplo), ref(&n_), ref(&nrhs_), ap.ptr, afp.ptr, ipiv.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, name)(opt(uplo), ref(&n_), ref(&nrhs_), ap.ptr, afp.ptr, ipiv.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }
    return info_mod.checkArgs(info);
}

/// `trrfs` for a triangular band matrix. Bounds only; `x` is not refined.
pub fn tbrfs(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    trans: Trans,
    diag: Diag,
    n: usize,
    kd: usize,
    nrhs: usize,
    ab: []const T,
    ldab: usize,
    b: []const T,
    ldb: usize,
    x: []const T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    std.debug.assert(ldab >= kd + 1);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const scratch = try Scratch(T).init(allocator, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const kd_ = dim(kd);
    const nrhs_ = dim(nrhs);
    const ldab_ = dim(ldab);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "tbrfs")(opt(uplo), opt(trans), opt(diag), ref(&n_), ref(&kd_), ref(&nrhs_), ab.ptr, ref(&ldab_), b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "tbrfs")(opt(uplo), opt(trans), opt(diag), ref(&n_), ref(&kd_), ref(&nrhs_), ab.ptr, ref(&ldab_), b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }
    return info_mod.checkArgs(info);
}

/// `trrfs` in packed triangular storage. Bounds only; `x` is not refined.
pub fn tprfs(
    comptime T: type,
    allocator: Allocator,
    uplo: Uplo,
    trans: Trans,
    diag: Diag,
    n: usize,
    nrhs: usize,
    ap: []const T,
    b: []const T,
    ldb: usize,
    x: []const T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!void {
    std.debug.assert(ap.len >= packedLen(n));
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const scratch = try Scratch(T).init(allocator, n);
    defer scratch.deinit();

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "tprfs")(opt(uplo), opt(trans), opt(diag), ref(&n_), ref(&nrhs_), ap.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.rwork.ptr, out(&info)),
        else => sym(T, "tprfs")(opt(uplo), opt(trans), opt(diag), ref(&n_), ref(&nrhs_), ap.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), ferr.ptr, berr.ptr, scratch.work.ptr, scratch.iwork.ptr, out(&info)),
    }
    return info_mod.checkArgs(info);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const factor = @import("factor.zig");
const norms = @import("norms.zig");

test "gerfs bounds the error of a well-conditioned solve" {
    const n = 3;
    // The original must be kept: getrf overwrites, and gerfs needs both.
    const original = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };
    const b = [_]f64{ 1, 2, 3 };

    var af = original;
    var ipiv: [n]Int = undefined;
    try factor.getrf(f64, n, n, &af, n, &ipiv);

    var x = b;
    try factor.getrs(f64, .no_trans, n, 1, &af, n, &ipiv, &x, n);

    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    try gerfs(f64, testing.allocator, .no_trans, n, 1, &original, n, &af, n, &ipiv, &b, n, &x, n, &ferr, &berr);

    // berr is a computed quantity and must be around machine epsilon for a
    // solve this benign. ferr is an estimate and only needs to be small.
    try testing.expect(berr[0] < 1e-14);
    try testing.expect(ferr[0] < 1e-10);
    try testing.expect(ferr[0] >= 0);

    // The refined x still solves the system.
    for (0..n) |i| {
        var acc: f64 = 0;
        for (0..n) |j| acc += original[i + j * n] * x[j];
        try testing.expectApproxEqAbs(b[i], acc, 1e-12);
    }
}

test "gerfs reports a larger forward error for an ill-conditioned system" {
    const n = 2;
    // Nearly singular: rcond is about 1e-10.
    const original = [_]f64{ 1, 1, 1, 1 + 1e-10 };
    const b = [_]f64{ 1, 1 };

    var af = original;
    var ipiv: [n]Int = undefined;
    try factor.getrf(f64, n, n, &af, n, &ipiv);
    var x = b;
    try factor.getrs(f64, .no_trans, n, 1, &af, n, &ipiv, &x, n);

    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    try gerfs(f64, testing.allocator, .no_trans, n, 1, &original, n, &af, n, &ipiv, &b, n, &x, n, &ferr, &berr);

    // The backward error stays tiny - the solver did its job. The forward error
    // does not, because the problem itself does not determine x well. That
    // distinction is the reason both numbers exist.
    try testing.expect(berr[0] < 1e-14);
    try testing.expect(ferr[0] > 1e-8);
}

test "gerfs handles multiple right-hand sides independently" {
    const n = 3;
    const original = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };
    const b = [_]f64{ 1, 2, 3, 1, 0, 0 };

    var af = original;
    var ipiv: [n]Int = undefined;
    try factor.getrf(f64, n, n, &af, n, &ipiv);
    var x = b;
    try factor.getrs(f64, .no_trans, n, 2, &af, n, &ipiv, &x, n);

    var ferr: [2]f64 = undefined;
    var berr: [2]f64 = undefined;
    try gerfs(f64, testing.allocator, .no_trans, n, 2, &original, n, &af, n, &ipiv, &b, n, &x, n, &ferr, &berr);

    for (berr) |v| try testing.expect(v < 1e-14);
    for (ferr) |v| try testing.expect(v >= 0 and v < 1e-10);
}

test "porfs refines a Cholesky solve" {
    const n = 3;
    const original = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };
    const b = [_]f64{ 1, 2, 3 };

    // lacpy is the reason this works: potrf would otherwise destroy the matrix
    // porfs needs.
    var af = [_]f64{0} ** (n * n);
    norms.lacpy(f64, .all, n, n, &original, n, &af, n);
    try factor.potrf(f64, .upper, n, &af, n);

    var x = b;
    try factor.potrs(f64, .upper, n, 1, &af, n, &x, n);

    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    try porfs(f64, testing.allocator, .upper, n, 1, &original, n, &af, n, &b, n, &x, n, &ferr, &berr);

    try testing.expect(berr[0] < 1e-14);
    for (0..n) |i| {
        var acc: f64 = 0;
        for (0..n) |j| acc += original[i + j * n] * x[j];
        try testing.expectApproxEqAbs(b[i], acc, 1e-12);
    }
}

test "syrfs refines an indefinite solve" {
    const n = 2;
    const original = [_]f64{ 1, 2, 2, 1 };
    const b = [_]f64{ 1, 1 };

    var af = original;
    var ipiv: [n]Int = undefined;
    try factor.sytrf(f64, testing.allocator, .upper, n, &af, n, &ipiv);
    var x = b;
    try factor.sytrs(f64, .upper, n, 1, &af, n, &ipiv, &x, n);

    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    try syrfs(f64, testing.allocator, .upper, n, 1, &original, n, &af, n, &ipiv, &b, n, &x, n, &ferr, &berr);

    try testing.expect(berr[0] < 1e-14);
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 3.0), x[0], 1e-12);
}

test "herfs refines a Hermitian solve" {
    const Z = Complex(f64);
    const n = 2;
    const original = [_]Z{ Z.init(2, 0), Z.init(0, -1), Z.init(0, 1), Z.init(2, 0) };
    const b = [_]Z{ Z.init(1, 0), Z.init(0, 0) };

    var af = original;
    var ipiv: [n]Int = undefined;
    try factor.hetrf(Z, testing.allocator, .lower, n, &af, n, &ipiv);
    var x = b;
    try factor.hetrs(Z, .lower, n, 1, &af, n, &ipiv, &x, n);

    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    try herfs(Z, testing.allocator, .lower, n, 1, &original, n, &af, n, &ipiv, &b, n, &x, n, &ferr, &berr);

    // The complex branch allocates a different scratch shape from the real one
    // (2n complex plus n real, against 3n real plus n integers); a wrong choice
    // here would corrupt the heap rather than fail.
    try testing.expect(berr[0] < 1e-14);
    try testing.expectApproxEqAbs(@as(f64, 2.0 / 3.0), x[0].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 3.0), x[1].im, 1e-12);
}

test "trrfs bounds a triangular solve without refining it" {
    const n = 2;
    const a = [_]f64{ 2, 0, 1, 3 }; // upper [[2, 1], [0, 3]]
    const b = [_]f64{ 5, 3 };

    var x = b;
    try factor.trtrs(f64, .upper, .no_trans, .non_unit, n, 1, &a, n, &x, n);
    const before = x;

    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    try trrfs(f64, testing.allocator, .upper, .no_trans, .non_unit, n, 1, &a, n, &b, n, &x, n, &ferr, &berr);

    // x is const to the routine - it bounds the error and leaves the solution
    // alone, unlike every other routine in this module.
    try testing.expectEqualSlices(f64, &before, &x);
    try testing.expect(berr[0] < 1e-14);
}

test "single precision works through the same wrappers" {
    const n = 2;
    const original = [_]f32{ 2, 1, 1, 3 };
    const b = [_]f32{ 3, 5 };

    var af = original;
    var ipiv: [n]Int = undefined;
    try factor.getrf(f32, n, n, &af, n, &ipiv);
    var x = b;
    try factor.getrs(f32, .no_trans, n, 1, &af, n, &ipiv, &x, n);

    var ferr: [1]f32 = undefined;
    var berr: [1]f32 = undefined;
    try gerfs(f32, testing.allocator, .no_trans, n, 1, &original, n, &af, n, &ipiv, &b, n, &x, n, &ferr, &berr);

    try testing.expect(berr[0] < 1e-6);
}

// ============================================================================
// Tests: refinement for the other storage forms
// ============================================================================

/// The 3x3 tridiagonal `tridiag(1, 4, 1)`, dense column-major. Every test below
/// solves against this same matrix in a different storage form, so their `x`
/// vectors can be compared against each other.
const tri3 = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };
const rhs3 = [_]f64{ 1, 2, 3 };

fn solves(x: []const f64) !void {
    for (0..3) |i| {
        var acc: f64 = 0;
        for (0..3) |j| acc += tri3[i + j * 3] * x[j];
        try testing.expectApproxEqAbs(rhs3[i], acc, 1e-12);
    }
}

test "gbrfs takes the original in the narrow band layout and the factor in the wide one" {
    const kl = 1;
    const ku = 1;
    const narrow_ld = kl + ku + 1;
    const wide_ld = 2 * kl + ku + 1;

    var narrow = [_]f64{0} ** (narrow_ld * 3);
    var wide = [_]f64{0} ** (wide_ld * 3);
    for (0..3) |j| for (0..3) |i| {
        if (i + kl < j or j + ku < i) continue;
        narrow[ku + i - j + j * narrow_ld] = tri3[i + j * 3];
        wide[kl + ku + i - j + j * wide_ld] = tri3[i + j * 3];
    };

    var ipiv: [3]Int = undefined;
    try factor.gbtrf(f64, 3, 3, kl, ku, &wide, wide_ld, &ipiv);

    var x = rhs3;
    try factor.gbtrs(f64, .no_trans, 3, kl, ku, 1, &wide, wide_ld, &ipiv, &x, 3);

    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    try gbrfs(f64, testing.allocator, .no_trans, 3, kl, ku, 1, &narrow, narrow_ld, &wide, wide_ld, &ipiv, &rhs3, 3, &x, 3, &ferr, &berr);

    try testing.expect(berr[0] < 1e-14);
    try testing.expect(ferr[0] >= 0 and ferr[0] < 1e-12);
    try solves(&x);
}

test "gtrfs needs the original diagonals alongside the factored ones" {
    const dl = [_]f64{ 1, 1 };
    const d = [_]f64{ 4, 4, 4 };
    const du = [_]f64{ 1, 1 };

    var dlf = dl;
    var df = d;
    var duf = du;
    var du2 = [_]f64{0};
    var ipiv: [3]Int = undefined;
    try factor.gttrf(f64, 3, &dlf, &df, &duf, &du2, &ipiv);

    var x = rhs3;
    try factor.gttrs(f64, .no_trans, 3, 1, &dlf, &df, &duf, &du2, &ipiv, &x, 3);

    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    try gtrfs(f64, testing.allocator, .no_trans, 3, 1, &dl, &d, &du, &dlf, &df, &duf, &du2, &ipiv, &rhs3, 3, &x, 3, &ferr, &berr);

    try testing.expect(berr[0] < 1e-14);
    try solves(&x);
}

test "pbrfs uses the same band layout for the matrix and its Cholesky factor" {
    const ab = [_]f64{ 0, 4, 1, 4, 1, 4 }; // upper, kd = 1
    var afb = ab;
    try factor.pbtrf(f64, .upper, 3, 1, &afb, 2);

    var x = rhs3;
    try factor.pbtrs(f64, .upper, 3, 1, 1, &afb, 2, &x, 3);

    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    try pbrfs(f64, testing.allocator, .upper, 3, 1, 1, &ab, 2, &afb, 2, &rhs3, 3, &x, 3, &ferr, &berr);

    try testing.expect(berr[0] < 1e-14);
    try solves(&x);
}

test "pprfs refines a packed Cholesky solve" {
    const ap = [_]f64{ 4, 1, 4, 0, 1, 4 };
    var afp = ap;
    try factor.pptrf(f64, .upper, 3, &afp);

    var x = rhs3;
    try factor.pptrs(f64, .upper, 3, 1, &afp, &x, 3);

    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    try pprfs(f64, testing.allocator, .upper, 3, 1, &ap, &afp, &rhs3, 3, &x, 3, &ferr, &berr);

    try testing.expect(berr[0] < 1e-14);
    try solves(&x);
}

test "ptrfs ignores uplo for a real matrix" {
    const d = [_]f64{ 4, 4, 4 };
    const e = [_]f64{ 1, 1 };
    var df = d;
    var ef = e;
    try factor.pttrf(f64, 3, &df, &ef);

    var x_upper = rhs3;
    try factor.pttrs(f64, .upper, 3, 1, &df, &ef, &x_upper, 3);
    var x_lower = rhs3;
    try factor.pttrs(f64, .lower, 3, 1, &df, &ef, &x_lower, 3);

    var ferr: [2]f64 = undefined;
    var berr: [2]f64 = undefined;
    try ptrfs(f64, testing.allocator, .upper, 3, 1, &d, &e, &df, &ef, &rhs3, 3, &x_upper, 3, ferr[0..1], berr[0..1]);
    try ptrfs(f64, testing.allocator, .lower, 3, 1, &d, &e, &df, &ef, &rhs3, 3, &x_lower, 3, ferr[1..2], berr[1..2]);

    // The real routine has no uplo parameter, so passing a different one cannot
    // change anything. This pins that the wrapper really does drop it.
    try testing.expectEqual(ferr[0], ferr[1]);
    try testing.expectEqual(berr[0], berr[1]);
    try testing.expectEqualSlices(f64, &x_upper, &x_lower);
    try solves(&x_upper);
}

test "ptrfs does look at uplo for a complex matrix" {
    const Z = Complex(f64);
    // Hermitian positive definite tridiagonal: diagonal 4, off-diagonal i.
    const d = [_]f64{ 4, 4 };
    const e_lower = [_]Z{Z.init(0, 1)};
    // The same matrix described by its superdiagonal is the conjugate.
    const e_upper = [_]Z{Z.init(0, -1)};

    var df_l = d;
    var ef_l = e_lower;
    try factor.pttrf(Z, 2, &df_l, &ef_l);
    var df_u = d;
    var ef_u = e_upper;
    try factor.pttrf(Z, 2, &df_u, &ef_u);

    const b = [_]Z{ Z.init(1, 0), Z.init(0, 0) };
    var x_l = b;
    try factor.pttrs(Z, .lower, 2, 1, &df_l, &ef_l, &x_l, 2);
    var x_u = b;
    try factor.pttrs(Z, .upper, 2, 1, &df_u, &ef_u, &x_u, 2);

    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    try ptrfs(Z, testing.allocator, .lower, 2, 1, &d, &e_lower, &df_l, &ef_l, &b, 2, &x_l, 2, &ferr, &berr);
    try testing.expect(berr[0] < 1e-14);
    try ptrfs(Z, testing.allocator, .upper, 2, 1, &d, &e_upper, &df_u, &ef_u, &b, 2, &x_u, 2, &ferr, &berr);
    try testing.expect(berr[0] < 1e-14);

    // Both descriptions are of the same matrix, so both solves agree.
    try testing.expectApproxEqAbs(x_l[0].re, x_u[0].re, 1e-14);
    try testing.expectApproxEqAbs(x_l[1].im, x_u[1].im, 1e-14);
}

test "sprfs refines a packed indefinite solve" {
    const ap = [_]f64{ 1, 2, 1, 0, 2, 1 }; // upper packed [[1,2,0],[2,1,2],[0,2,1]]
    const dense = [_]f64{ 1, 2, 0, 2, 1, 2, 0, 2, 1 };

    var afp = ap;
    var ipiv: [3]Int = undefined;
    try factor.sptrf(f64, .upper, 3, &afp, &ipiv);

    var x = rhs3;
    try factor.sptrs(f64, .upper, 3, 1, &afp, &ipiv, &x, 3);

    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    try sprfs(f64, testing.allocator, .upper, 3, 1, &ap, &afp, &ipiv, &rhs3, 3, &x, 3, &ferr, &berr);

    try testing.expect(berr[0] < 1e-14);
    for (0..3) |i| {
        var acc: f64 = 0;
        for (0..3) |j| acc += dense[i + j * 3] * x[j];
        try testing.expectApproxEqAbs(rhs3[i], acc, 1e-12);
    }
}

test "hprfs is the Hermitian packed refinement" {
    const Z = Complex(f64);
    // [[2, i], [-i, 2]] in upper packed storage.
    const ap = [_]Z{ Z.init(2, 0), Z.init(0, 1), Z.init(2, 0) };
    var afp = ap;
    var ipiv: [2]Int = undefined;
    try factor.hptrf(Z, .upper, 2, &afp, &ipiv);

    const b = [_]Z{ Z.init(1, 0), Z.init(0, 1) };
    var x = b;
    try factor.hptrs(Z, .upper, 2, 1, &afp, &ipiv, &x, 2);

    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    try hprfs(Z, testing.allocator, .upper, 2, 1, &ap, &afp, &ipiv, &b, 2, &x, 2, &ferr, &berr);
    try testing.expect(berr[0] < 1e-14);
}

test "tbrfs and tprfs bound a triangular solve without refining it" {
    // Upper triangular [[1, 2, 0], [0, 3, 4], [0, 0, 5]].
    const dense_t = [_]f64{ 1, 0, 0, 2, 3, 0, 0, 4, 5 };
    const ab = [_]f64{ 0, 1, 2, 3, 4, 5 }; // kd = 1
    const ap = [_]f64{ 1, 2, 3, 0, 4, 5 };

    var x = rhs3;
    try factor.trtrs(f64, .upper, .no_trans, .non_unit, 3, 1, &dense_t, 3, &x, 3);
    const before = x;

    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    try tbrfs(f64, testing.allocator, .upper, .no_trans, .non_unit, 3, 1, 1, &ab, 2, &rhs3, 3, &x, 3, &ferr, &berr);
    const band_ferr = ferr[0];
    try tprfs(f64, testing.allocator, .upper, .no_trans, .non_unit, 3, 1, &ap, &rhs3, 3, &x, 3, &ferr, &berr);

    try testing.expect(berr[0] < 1e-14);
    // Both bound the same solve, but ferr is an estimate built from a
    // componentwise bound that the band and packed traversals accumulate in
    // different orders — measured, they land within about 30% of each other,
    // not bit-for-bit. Pinning them equal would be pinning an accident.
    try testing.expect(band_ferr < 1e-13 and ferr[0] < 1e-13);
    try testing.expect(@max(band_ferr, ferr[0]) < 2 * @min(band_ferr, ferr[0]));
    // x is untouched: these two only measure.
    try testing.expectEqualSlices(f64, &before, &x);
}
