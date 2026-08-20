//! Expert drivers: equilibrate, factor, solve, estimate the condition number
//! and bound the error, in one call.
//!
//! These do everything `linear.zig` + `factor.zig` + `refine.zig` do, and add
//! equilibration on top. The reason to use one is not convenience — it is that
//! equilibration genuinely changes the answer for a badly scaled matrix, and
//! doing it by hand means getting the scale factors, the solve and the
//! unscaling all right.
//!
//! ## `info = n + 1` is a warning, not a failure
//!
//! Every routine here overloads the positive `info` in a way the simple drivers
//! do not:
//!
//! | `info` | meaning |
//! |---|---|
//! | `0` | success |
//! | `1 .. n` | the factorization found an exactly zero pivot; nothing was solved |
//! | `n + 1` | the factorization succeeded, `rcond` is below machine precision, **and the system was solved anyway** |
//!
//! That last case is a result, not an error. `x` and the error bounds are all
//! valid; LAPACK is telling you the matrix is singular to working precision so
//! the answer may be meaningless — which is exactly what `ferr` will also say.
//! Treating it as a failure throws away a computed answer *and* the diagnostic
//! that came with it, so these wrappers return it as a flag on the result.
//!
//! ## `equed` is an in/out parameter
//!
//! Unlike every other option character in this binding, `equed` is written as
//! well as read: an input when `fact = .factored` (telling the routine how the
//! supplied factorization was scaled) and an output when `fact = .equilibrate`
//! (telling you what it chose). It is therefore a `*Equed` rather than a value.

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
const Fact = types.Fact;
const Equed = types.Equed;
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

/// `equed` is read *and written*, so it cannot come from the shared immutable
/// byte table `types.opt` uses. The enum's values are exactly the four
/// characters LAPACK writes back ('N', 'R', 'C', 'B'), so reinterpreting the
/// pointer is safe in both directions.
fn equedPtr(e: *Equed) [*]u8 {
    return @ptrCast(e);
}

/// What an expert driver computed alongside the solution.
pub const ExpertResult = struct {
    /// Estimated reciprocal condition number of the (equilibrated) matrix.
    rcond: f64,

    /// True when `info` came back as `n + 1`: the factorization succeeded and
    /// the system was solved, but `rcond` is below machine precision, so the
    /// matrix is singular to working precision and the solution may be
    /// meaningless. `x`, `ferr` and `berr` are all still valid — `ferr` will
    /// generally be large, saying the same thing quantitatively.
    singular_to_working_precision: bool,

    /// How the matrix was equilibrated. Meaningful after
    /// `fact = .equilibrate`.
    equed: Equed,
};

fn finish(info: Int, n: usize, rcond: f64, equed: Equed) Error!ExpertResult {
    if (info < 0) try info_mod.checkArgs(info);
    const warned = info == @as(Int, @intCast(n)) + 1;
    if (info > 0 and !warned) return blk: {
        _ = info_mod.checkLu(info) catch |e| break :blk e;
        unreachable;
    };
    return .{
        .rcond = rcond,
        .singular_to_working_precision = warned,
        .equed = equed,
    };
}

/// Solves `A X = B` for a general matrix, with equilibration, condition
/// estimation and error bounds.
///
/// With `fact = .not_factored` the routine factors `a` into `af`/`ipiv`; with
/// `.equilibrate` it scales first and reports the choice through `equed`; with
/// `.factored` it reuses an `af`/`ipiv` you already have, and `equed`, `r` and
/// `c` are then **inputs** describing how that factorization was scaled.
///
/// `a` is not overwritten unless equilibration scales it. `x` receives the
/// solution; `b` is left alone.
pub fn gesvx(
    comptime T: type,
    allocator: Allocator,
    fact: Fact,
    trans: Trans,
    n: usize,
    nrhs: usize,
    a: []T,
    lda: usize,
    af: []T,
    ldaf: usize,
    ipiv: []Int,
    equed: *Equed,
    r: []Real(T),
    col_scale: []Real(T),
    b: []T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!ExpertResult {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(af.len, n, n, ldaf);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ipiv.len >= n);
    std.debug.assert(r.len >= n and col_scale.len >= n);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldaf_ = dim(ldaf);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => {
            const work = try allocator.alloc(T, @max(2 * n, 1));
            defer allocator.free(work);
            const rwork = try allocator.alloc(Real(T), @max(2 * n, 1));
            defer allocator.free(rwork);
            sym(T, "gesvx")(opt(fact), opt(trans), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), af.ptr, ref(&ldaf_), ipiv.ptr, equedPtr(equed), r.ptr, col_scale.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), out(&rcond), ferr.ptr, berr.ptr, work.ptr, rwork.ptr, out(&info));
        },
        else => {
            const work = try allocator.alloc(T, @max(4 * n, 1));
            defer allocator.free(work);
            const iwork = try allocator.alloc(Int, @max(n, 1));
            defer allocator.free(iwork);
            sym(T, "gesvx")(opt(fact), opt(trans), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), af.ptr, ref(&ldaf_), ipiv.ptr, equedPtr(equed), r.ptr, col_scale.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), out(&rcond), ferr.ptr, berr.ptr, work.ptr, iwork.ptr, out(&info));
        },
    }
    return finish(info, n, rcond, equed.*);
}

/// `gesvx` for a symmetric/Hermitian positive definite matrix.
///
/// Equilibration here is symmetric — one scale vector `s` rather than separate
/// row and column ones — because scaling the two independently would destroy
/// the symmetry the routine relies on.
pub fn posvx(
    comptime T: type,
    allocator: Allocator,
    fact: Fact,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []T,
    lda: usize,
    af: []T,
    ldaf: usize,
    equed: *Equed,
    s: []Real(T),
    b: []T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!ExpertResult {
    assertMatrix(a.len, n, n, lda);
    assertMatrix(af.len, n, n, ldaf);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(s.len >= n);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldaf_ = dim(ldaf);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    switch (T) {
        Complex(f32), Complex(f64) => {
            const work = try allocator.alloc(T, @max(2 * n, 1));
            defer allocator.free(work);
            const rwork = try allocator.alloc(Real(T), @max(n, 1));
            defer allocator.free(rwork);
            sym(T, "posvx")(opt(fact), opt(uplo), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), af.ptr, ref(&ldaf_), equedPtr(equed), s.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), out(&rcond), ferr.ptr, berr.ptr, work.ptr, rwork.ptr, out(&info));
        },
        else => {
            const work = try allocator.alloc(T, @max(3 * n, 1));
            defer allocator.free(work);
            const iwork = try allocator.alloc(Int, @max(n, 1));
            defer allocator.free(iwork);
            sym(T, "posvx")(opt(fact), opt(uplo), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), af.ptr, ref(&ldaf_), equedPtr(equed), s.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), out(&rcond), ferr.ptr, berr.ptr, work.ptr, iwork.ptr, out(&info));
        },
    }
    return finish(info, n, rcond, equed.*);
}

/// `gesvx` for a symmetric indefinite matrix.
///
/// No equilibration — LAPACK does not offer it for the indefinite case, so
/// there is no `equed` or scale vector here. The `.equilibrate` value of `fact`
/// is therefore not accepted.
pub fn sysvx(
    comptime T: type,
    allocator: Allocator,
    fact: Fact,
    uplo: Uplo,
    n: usize,
    nrhs: usize,
    a: []const T,
    lda: usize,
    af: []T,
    ldaf: usize,
    ipiv: []Int,
    b: []const T,
    ldb: usize,
    x: []T,
    ldx: usize,
    ferr: []Real(T),
    berr: []Real(T),
) Fail!ExpertResult {
    std.debug.assert(fact != .equilibrate);
    assertMatrix(a.len, n, n, lda);
    assertMatrix(af.len, n, n, ldaf);
    assertMatrix(b.len, n, nrhs, ldb);
    assertMatrix(x.len, n, nrhs, ldx);
    std.debug.assert(ipiv.len >= n);
    std.debug.assert(ferr.len >= nrhs and berr.len >= nrhs);

    const n_ = dim(n);
    const nrhs_ = dim(nrhs);
    const lda_ = dim(lda);
    const ldaf_ = dim(ldaf);
    const ldb_ = dim(ldb);
    const ldx_ = dim(ldx);
    var rcond: Real(T) = 0;
    var info: Int = 0;

    // Unlike gesvx and posvx, this one takes an lwork and is worth querying:
    // the documented minimum is 3n but the blocked path wants considerably
    // more.
    var probe: [1]T = undefined;
    var probe_i: [1]Int = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    switch (T) {
        Complex(f32), Complex(f64) => sym(T, "sysvx")(opt(fact), opt(uplo), ref(&n_), ref(&nrhs_), &probe, ref(&lda_), &probe, ref(&ldaf_), &probe_i, &probe, ref(&ldb_), &probe, ref(&ldx_), out(&rcond), &rprobe, &rprobe, &wq, ref(&neg), &rprobe, out(&info)),
        else => sym(T, "sysvx")(opt(fact), opt(uplo), ref(&n_), ref(&nrhs_), &probe, ref(&lda_), &probe, ref(&ldaf_), &probe_i, &probe, ref(&ldb_), &probe, ref(&ldx_), out(&rcond), &rprobe, &rprobe, &wq, ref(&neg), &probe_i, out(&info)),
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), @as(Int, @intCast(3 * n))));
    const work = try allocator.alloc(T, @max(size, 1));
    defer allocator.free(work);
    const lwork = dim(size);

    switch (T) {
        Complex(f32), Complex(f64) => {
            const rwork = try allocator.alloc(Real(T), @max(n, 1));
            defer allocator.free(rwork);
            sym(T, "sysvx")(opt(fact), opt(uplo), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), af.ptr, ref(&ldaf_), ipiv.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), out(&rcond), ferr.ptr, berr.ptr, work.ptr, ref(&lwork), rwork.ptr, out(&info));
        },
        else => {
            const iwork = try allocator.alloc(Int, @max(n, 1));
            defer allocator.free(iwork);
            sym(T, "sysvx")(opt(fact), opt(uplo), ref(&n_), ref(&nrhs_), a.ptr, ref(&lda_), af.ptr, ref(&ldaf_), ipiv.ptr, b.ptr, ref(&ldb_), x.ptr, ref(&ldx_), out(&rcond), ferr.ptr, berr.ptr, work.ptr, ref(&lwork), iwork.ptr, out(&info));
        },
    }
    return finish(info, n, rcond, .none);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "gesvx solves and reports a condition number" {
    const n = 3;
    var a = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };
    var b = [_]f64{ 1, 2, 3 };
    var af: [n * n]f64 = undefined;
    var ipiv: [n]Int = undefined;
    var r: [n]f64 = undefined;
    var col: [n]f64 = undefined;
    var x: [n]f64 = undefined;
    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    var equed: Equed = .none;

    const res = try gesvx(f64, testing.allocator, .not_factored, .no_trans, n, 1, &a, n, &af, n, &ipiv, &equed, &r, &col, &b, n, &x, n, &ferr, &berr);

    try testing.expect(!res.singular_to_working_precision);
    try testing.expect(res.rcond > 0.1);
    try testing.expect(berr[0] < 1e-14);

    // b is not overwritten - the solution goes to x. That differs from gesv,
    // where b is the solution.
    try testing.expectEqual(@as(f64, 1), b[0]);
    for (0..n) |i| {
        var acc: f64 = 0;
        for (0..n) |j| acc += ([_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 })[i + j * n] * x[j];
        try testing.expectApproxEqAbs(b[i], acc, 1e-12);
    }
}

test "gesvx equilibrates a badly scaled matrix and says so" {
    const n = 2;
    // Rows differing by ten orders of magnitude.
    var a = [_]f64{ 1, 1e10, 1, 2e10 };
    var b = [_]f64{ 1, 1e10 };
    var af: [n * n]f64 = undefined;
    var ipiv: [n]Int = undefined;
    var r: [n]f64 = undefined;
    var col: [n]f64 = undefined;
    var x: [n]f64 = undefined;
    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    var equed: Equed = .none;

    const res = try gesvx(f64, testing.allocator, .equilibrate, .no_trans, n, 1, &a, n, &af, n, &ipiv, &equed, &r, &col, &b, n, &x, n, &ferr, &berr);

    // equed is an output here, and reports what the routine chose. It is the
    // one option character in this binding that LAPACK writes to.
    try testing.expect(res.equed != .none);
    try testing.expectEqual(res.equed, equed);
    try testing.expect(berr[0] < 1e-14);
}

test "gesvx reports singularity to working precision without discarding the answer" {
    const n = 2;
    // Reaching info = n + 1 needs a matrix that is *almost* singular but not
    // exactly so: rcond must land below machine epsilon while the factorization
    // still finds a nonzero pivot. The window is narrow. Perturbing by less than
    // one ULP rounds away entirely and gives an exactly zero pivot (measured:
    // 1e-16 -> error.SingularMatrix, info = 2); perturbing by a few ULPs lifts
    // rcond back above eps and the warning stops firing (7e-16 -> rcond
    // 1.67e-16, no warning). One ULP is the value that sits inside it, giving
    // rcond = eps/4.
    const eps = std.math.floatEps(f64);
    var a = [_]f64{ 1, 1, 1, 1 + eps };
    var b = [_]f64{ 1, 1 };
    var af: [n * n]f64 = undefined;
    var ipiv: [n]Int = undefined;
    var r: [n]f64 = undefined;
    var col: [n]f64 = undefined;
    var x: [n]f64 = undefined;
    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    var equed: Equed = .none;

    const res = try gesvx(f64, testing.allocator, .not_factored, .no_trans, n, 1, &a, n, &af, n, &ipiv, &equed, &r, &col, &b, n, &x, n, &ferr, &berr);

    // info = n + 1 is a warning, not a failure. Returning an error here would
    // throw away both the computed x and the diagnostic that came with it.
    try testing.expect(res.singular_to_working_precision);
    try testing.expect(res.rcond < eps);
    // ferr says the same thing quantitatively: the answer is worthless.
    try testing.expect(ferr[0] > 1);
}

test "gesvx does raise an error on an exactly zero pivot" {
    const n = 2;
    // A genuinely zero column: info lands in 1..n, which is a failure.
    var a = [_]f64{ 1, 1, 0, 0 };
    var b = [_]f64{ 1, 1 };
    var af: [n * n]f64 = undefined;
    var ipiv: [n]Int = undefined;
    var r: [n]f64 = undefined;
    var col: [n]f64 = undefined;
    var x: [n]f64 = undefined;
    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    var equed: Equed = .none;

    try testing.expectError(error.SingularMatrix, gesvx(f64, testing.allocator, .not_factored, .no_trans, n, 1, &a, n, &af, n, &ipiv, &equed, &r, &col, &b, n, &x, n, &ferr, &berr));
    try testing.expect(info_mod.lastInfo() >= 1 and info_mod.lastInfo() <= n);
}

test "gesvx reuses a factorization it was given" {
    const n = 3;
    const original = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };
    var a = original;
    var b = [_]f64{ 1, 2, 3 };
    var af: [n * n]f64 = undefined;
    var ipiv: [n]Int = undefined;
    var r: [n]f64 = undefined;
    var col: [n]f64 = undefined;
    var x: [n]f64 = undefined;
    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    var equed: Equed = .none;

    _ = try gesvx(f64, testing.allocator, .not_factored, .no_trans, n, 1, &a, n, &af, n, &ipiv, &equed, &r, &col, &b, n, &x, n, &ferr, &berr);

    // Second solve, different right-hand side, reusing af/ipiv. equed is an
    // *input* now, describing how the supplied factorization was scaled.
    var b2 = [_]f64{ 1, 0, 0 };
    var x2: [n]f64 = undefined;
    const res = try gesvx(f64, testing.allocator, .factored, .no_trans, n, 1, &a, n, &af, n, &ipiv, &equed, &r, &col, &b2, n, &x2, n, &ferr, &berr);

    try testing.expect(res.rcond > 0.1);
    for (0..n) |i| {
        var acc: f64 = 0;
        for (0..n) |j| acc += original[i + j * n] * x2[j];
        try testing.expectApproxEqAbs(b2[i], acc, 1e-12);
    }
}

test "posvx equilibrates symmetrically" {
    const n = 3;
    const original = [_]f64{ 4, 1, 0, 1, 4, 1, 0, 1, 4 };
    var a = original;
    var b = [_]f64{ 1, 2, 3 };
    var af: [n * n]f64 = undefined;
    var s: [n]f64 = undefined;
    var x: [n]f64 = undefined;
    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    var equed: Equed = .none;

    const res = try posvx(f64, testing.allocator, .equilibrate, .upper, n, 1, &a, n, &af, n, &equed, &s, &b, n, &x, n, &ferr, &berr);

    // One scale vector, not two: scaling rows and columns independently would
    // break the symmetry the Cholesky path depends on.
    try testing.expect(res.rcond > 0);
    try testing.expect(berr[0] < 1e-14);
    for (0..n) |i| {
        var acc: f64 = 0;
        for (0..n) |j| acc += original[i + j * n] * x[j];
        try testing.expectApproxEqAbs(b[i], acc, 1e-12);
    }
}

test "posvx rejects a matrix that is not positive definite" {
    const n = 2;
    var a = [_]f64{ 1, 2, 2, 1 };
    var b = [_]f64{ 1, 1 };
    var af: [n * n]f64 = undefined;
    var s: [n]f64 = undefined;
    var x: [n]f64 = undefined;
    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    var equed: Equed = .none;

    try testing.expectError(error.SingularMatrix, posvx(f64, testing.allocator, .not_factored, .upper, n, 1, &a, n, &af, n, &equed, &s, &b, n, &x, n, &ferr, &berr));
}

test "sysvx solves the indefinite system with bounds" {
    const n = 2;
    const original = [_]f64{ 1, 2, 2, 1 };
    const b = [_]f64{ 1, 1 };
    var af: [n * n]f64 = undefined;
    var ipiv: [n]Int = undefined;
    var x: [n]f64 = undefined;
    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;

    const res = try sysvx(f64, testing.allocator, .not_factored, .upper, n, 1, &original, n, &af, n, &ipiv, &b, n, &x, n, &ferr, &berr);

    try testing.expect(res.rcond > 0.1);
    try testing.expect(berr[0] < 1e-14);
    try testing.expectApproxEqAbs(@as(f64, 1.0 / 3.0), x[0], 1e-12);
    // No equilibration exists for the indefinite case.
    try testing.expectEqual(Equed.none, res.equed);
}

test "the complex expert driver uses its own scratch shape" {
    const Z = Complex(f64);
    const n = 2;
    var a = [_]Z{ Z.init(2, 0), Z.init(0, 1), Z.init(0, -1), Z.init(2, 0) };
    var b = [_]Z{ Z.init(1, 0), Z.init(0, 0) };
    var af: [n * n]Z = undefined;
    var ipiv: [n]Int = undefined;
    var r: [n]f64 = undefined;
    var col: [n]f64 = undefined;
    var x: [n]Z = undefined;
    var ferr: [1]f64 = undefined;
    var berr: [1]f64 = undefined;
    var equed: Equed = .none;

    const res = try gesvx(Z, testing.allocator, .not_factored, .no_trans, n, 1, &a, n, &af, n, &ipiv, &equed, &r, &col, &b, n, &x, n, &ferr, &berr);

    try testing.expect(res.rcond > 0.1);
    try testing.expect(berr[0] < 1e-14);
    // A = [[2, -i], [i, 2]], det = 3, so x = A^-1 [1, 0] = [2/3, -i/3].
    try testing.expectApproxEqAbs(@as(f64, 2.0 / 3.0), x[0].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, -1.0 / 3.0), x[1].im, 1e-12);
}

test "single precision works through the same wrappers" {
    const n = 2;
    var a = [_]f32{ 2, 1, 1, 3 };
    var b = [_]f32{ 3, 5 };
    var af: [n * n]f32 = undefined;
    var ipiv: [n]Int = undefined;
    var r: [n]f32 = undefined;
    var col: [n]f32 = undefined;
    var x: [n]f32 = undefined;
    var ferr: [1]f32 = undefined;
    var berr: [1]f32 = undefined;
    var equed: Equed = .none;

    const res = try gesvx(f32, testing.allocator, .not_factored, .no_trans, n, 1, &a, n, &af, n, &ipiv, &equed, &r, &col, &b, n, &x, n, &ferr, &berr);

    try testing.expect(res.rcond > 0.1);
    try testing.expectApproxEqAbs(@as(f32, 0.8), x[0], 1e-5);
}
