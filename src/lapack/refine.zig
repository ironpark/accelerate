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
