//! Machine parameters, small utilities, and the complex-symmetric routines
//! that CBLAS does not provide.
//!
//! ## Complex symmetric is not Hermitian
//!
//! `symv`, `syr`, `spmv` and `spr` here operate on a **complex symmetric**
//! matrix (`A = A^T`), which is a different object from the Hermitian one
//! (`A = A^H`) that `blas.hemv` and friends handle. CBLAS has no equivalent —
//! it offers `hemv`/`her` for complex and `symv`/`syr` only for real — so these
//! are a genuine addition rather than a duplicate of the BLAS module.
//!
//! They exist because complex symmetric matrices turn up in the middle of
//! LAPACK's own algorithms, which is also why they live in LAPACK rather than
//! BLAS. If you have one, nothing else in either library will handle it
//! correctly: passing it to `hemv` silently conjugates the wrong half.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");

const Int = types.Int;
const Bool = types.Bool;
const Complex = types.Complex;
const Real = types.Real;
const Uplo = types.Uplo;
const Error = info_mod.Error;
const dim = types.dim;
const assertMatrix = types.assertMatrix;
const packedLen = types.packedLen;
const ref = work_mod.ref;
const out = work_mod.out;
const opt = types.opt;

fn sym(comptime T: type, comptime name: []const u8) @TypeOf(@field(c, [_]u8{types.prefix(T)} ++ name)) {
    return @field(c, [_]u8{types.prefix(T)} ++ name);
}

fn requireComplex(comptime T: type, comptime routine: []const u8) void {
    switch (T) {
        Complex(f32), Complex(f64) => {},
        else => @compileError(routine ++ " is complex-only; " ++ @typeName(T) ++
            " has a BLAS equivalent"),
    }
}

// ============================================================================
// Machine parameters
// ============================================================================

/// Which machine parameter `lamch` should report.
pub const MachineParam = enum(u8) {
    /// Relative machine epsilon: `base^(1-t)` times the rounding factor. This
    /// is LAPACK's `eps`, and it is **half** of Zig's `std.math.floatEps` -
    /// LAPACK defines it as the rounding unit, not as the gap to the next
    /// representable number.
    epsilon = 'E',
    /// Smallest number whose reciprocal does not overflow.
    safe_min = 'S',
    /// The radix, 2 on anything current.
    base = 'B',
    /// `epsilon * base`.
    precision = 'P',
    /// Mantissa digits.
    digits = 'N',
    /// 1 if rounding occurs in addition, 0 otherwise.
    rounding = 'R',
    /// Minimum exponent before gradual underflow.
    min_exponent = 'M',
    /// Underflow threshold.
    underflow = 'U',
    /// Largest exponent before overflow.
    max_exponent = 'L',
    /// Overflow threshold.
    overflow = 'O',
};

/// Machine parameters as the running LAPACK sees them.
///
/// Worth preferring over Zig's `std.math` constants when the value is about to
/// be handed back to LAPACK — a tolerance derived from a different definition
/// of epsilon is a tolerance the routine will not behave as documented under.
pub fn lamch(comptime T: type, param: MachineParam) T {
    switch (T) {
        f32, f64 => {},
        else => @compileError("lamch is real-only; use lamch(Real(T), ...)"),
    }
    return sym(T, "lamch")(opt(param));
}

/// The blocking factor and other tuning parameters LAPACK would use.
///
/// `name` is the routine name **without** its precision prefix and in
/// uppercase, as LAPACK expects (`"GEQRF"`, not `"dgeqrf"`); the prefix for `T`
/// is prepended here. `ispec = 1` is the block size, which is the one anyone
/// asks for.
///
/// Mostly useful for sizing a workspace by hand instead of by query, or for
/// understanding why a routine chose a particular path.
pub fn ilaenv(
    comptime T: type,
    ispec: Int,
    comptime name: []const u8,
    comptime opts: []const u8,
    n1: Int,
    n2: Int,
    n3: Int,
    n4: Int,
) Int {
    const full = comptime blk: {
        var buf: [name.len + 2]u8 = undefined;
        buf[0] = std.ascii.toUpper(types.prefix(T));
        for (name, 0..) |ch, i| buf[i + 1] = ch;
        buf[name.len + 1] = 0;
        break :blk buf;
    };
    const opts_z = comptime opts ++ "\x00";
    return c.ilaenv(ref(&ispec), &full, opts_z, ref(&n1), ref(&n2), ref(&n3), ref(&n4));
}

// ============================================================================
// Random numbers
// ============================================================================

/// Distribution for `larnv`.
pub const Distribution = enum(Int) {
    /// Uniform on (0, 1). For complex `T`, uniform on the unit square.
    uniform_01 = 1,
    /// Uniform on (-1, 1). For complex `T`, uniform on the square with corners
    /// (-1, -1) and (1, 1).
    uniform_pm1 = 2,
    /// Normal(0, 1). For complex `T`, both parts normal.
    normal = 3,
    /// Complex only: uniform on the unit disc.
    unit_disc = 4,
    /// Complex only: uniform on the unit circle.
    unit_circle = 5,
};

/// LAPACK's random seed: four integers with a parity constraint.
///
/// Each entry must be in `[0, 4095]` and the **last must be odd**. That
/// constraint is not decorative - the generator is a multiplicative congruential
/// one whose period collapses if the seed is even, and LAPACK does not check.
pub const Seed = struct {
    state: [4]Int,

    /// Builds a valid seed from an arbitrary value, forcing the last entry odd.
    pub fn init(value: u64) Seed {
        var v = value;
        var state: [4]Int = undefined;
        for (&state) |*slot| {
            slot.* = @intCast(v % 4096);
            v /= 4096;
        }
        state[3] |= 1;
        return .{ .state = state };
    }

    pub fn assertValid(self: Seed) void {
        for (self.state) |v| std.debug.assert(v >= 0 and v <= 4095);
        std.debug.assert(@rem(self.state[3], 2) == 1);
    }
};

/// Fills `x` with random numbers, advancing `seed` in place.
///
/// Useful for building test matrices whose entries are not all small integers -
/// the kind of matrix that catches scaling bugs a hand-written `[1, 2, 3]`
/// never will.
pub fn larnv(comptime T: type, dist: Distribution, seed: *Seed, x: []T) void {
    switch (T) {
        f32, f64 => std.debug.assert(@intFromEnum(dist) <= 3),
        else => {},
    }
    seed.assertValid();

    const idist: Int = @intFromEnum(dist);
    const n = dim(x.len);
    sym(T, "larnv")(ref(&idist), &seed.state, ref(&n), x.ptr);
}

// ============================================================================
// Plane rotations and scaling
// ============================================================================

/// A Givens rotation.
pub fn Rotation(comptime T: type) type {
    return struct {
        /// Cosine. Always real, even for a complex rotation.
        cos: Real(T),
        /// Sine.
        sin: T,
        /// The resulting nonzero entry: `[c s; -conj(s) c] [f; g] = [r; 0]`.
        r: T,
    };
}

/// Generates the plane rotation that zeroes `g` against `f`.
///
/// `blas.rotg` does the same for real elements but overwrites its inputs; this
/// returns a value and handles complex `T`, where the cosine stays real while
/// the sine does not.
pub fn lartg(comptime T: type, f: T, g: T) Rotation(T) {
    var cos: Real(T) = 0;
    var sin: T = undefined;
    var r: T = undefined;
    sym(T, "lartg")(ref(&f), ref(&g), out(&cos), out(&sin), out(&r));
    return .{ .cos = cos, .sin = sin, .r = r };
}

/// Which part of a matrix `lascl` scales, and how it is stored.
pub const ScaleKind = enum(u8) {
    full = 'G',
    lower_triangular = 'L',
    upper_triangular = 'U',
    upper_hessenberg = 'H',
    symmetric_band_lower = 'B',
    symmetric_band_upper = 'Q',
    band = 'Z',
};

/// `A := (to / from) * A`, without the intermediate overflow that computing the
/// ratio first would risk.
///
/// That is the entire reason this exists rather than a `scal` call: when `from`
/// is tiny and `to` is large, `to / from` overflows even though the scaled
/// matrix is perfectly representable. `lascl` splits the multiplication into
/// steps that cannot.
pub fn lascl(
    comptime T: type,
    kind: ScaleKind,
    kl: usize,
    ku: usize,
    from: Real(T),
    to: Real(T),
    rows: usize,
    cols: usize,
    a: []T,
    lda: usize,
) Error!void {
    std.debug.assert(from != 0);
    assertMatrix(a.len, rows, cols, lda);

    const kl_ = dim(kl);
    const ku_ = dim(ku);
    const m_ = dim(rows);
    const n_ = dim(cols);
    const lda_ = dim(lda);
    var info: Int = 0;

    sym(T, "lascl")(opt(kind), ref(&kl_), ref(&ku_), ref(&from), ref(&to), ref(&m_), ref(&n_), a.ptr, ref(&lda_), out(&info));
    return info_mod.checkArgs(info);
}

/// `x := x / a`, computed so that it cannot overflow.
///
/// Dividing by a very small `a` directly can overflow where this does not,
/// which matters when `a` came out of a factorization rather than from the
/// caller.
pub fn rscl(comptime T: type, a: Real(T), x: []T, incx: usize) void {
    std.debug.assert(incx >= 1);
    // The complex forms are named csrscl and zdrscl - two precision letters,
    // for the complex vector and the real scalar - so the usual one-letter
    // prefix lookup does not reach them.
    const name = switch (T) {
        f32 => "srscl",
        f64 => "drscl",
        Complex(f32) => "csrscl",
        Complex(f64) => "zdrscl",
        else => @compileError("not a LAPACK element type: " ++ @typeName(T)),
    };
    const n = dim((x.len + incx - 1) / incx);
    const incx_ = dim(incx);
    @field(c, name)(ref(&n), ref(&a), x.ptr, ref(&incx_));
}

/// Sorts a vector in place.
pub fn lasrt(comptime T: type, order: enum(u8) { increasing = 'I', decreasing = 'D' }, x: []T) Error!void {
    switch (T) {
        f32, f64 => {},
        else => @compileError("lasrt is real-only; complex numbers have no natural order"),
    }
    const n = dim(x.len);
    var info: Int = 0;
    sym(T, "lasrt")(opt(order), ref(&n), x.ptr, out(&info));
    return info_mod.checkArgs(info);
}

/// Conjugates a vector in place. Complex only.
///
/// LAPACK needs this because Fortran has no in-place conjugate and because the
/// packed factorizations occasionally store a conjugated row.
pub fn lacgv(comptime T: type, x: []T, incx: usize) void {
    requireComplex(T, "lacgv");
    std.debug.assert(incx >= 1);
    const n = dim((x.len + incx - 1) / incx);
    const incx_ = dim(incx);
    sym(T, "lacgv")(ref(&n), x.ptr, ref(&incx_));
}

/// Complex division `x / y`, computed to avoid the overflow that the naive
/// formula suffers when the operands are large.
///
/// This wraps `cladiv`/`zladiv`, which are **declared wrongly in the SDK
/// header** — see `c.zig` and `tools/gen_lapack.py`. The header types them as
/// writing through a leading out-parameter and they do not; the shipping symbol
/// is a thunk that discards that argument and returns the quotient in
/// registers. This wrapper hides the resulting oddity (three pointers must
/// still be passed, one of them ignored).
pub fn ladiv(comptime T: type, x: T, y: T) T {
    requireComplex(T, "ladiv");
    var ignored: T = undefined;
    return sym(T, "ladiv")(out(&ignored), ref(&x), ref(&y));
}

// ============================================================================
// Complex symmetric BLAS
// ============================================================================

/// `y := alpha * A * x + beta * y` for a **complex symmetric** `A`.
///
/// Not Hermitian. `blas.hemv` conjugates when it reflects the stored triangle
/// across the diagonal; this does not. For a matrix that really is symmetric
/// rather than Hermitian, `hemv` gives a different and wrong answer, and
/// nothing reports it.
pub fn symv(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    alpha: T,
    a: []const T,
    lda: usize,
    x: []const T,
    incx: usize,
    beta: T,
    y: []T,
    incy: usize,
) void {
    requireComplex(T, "symv");
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(incx >= 1 and incy >= 1);
    std.debug.assert(x.len >= (n - 1) * incx + 1);
    std.debug.assert(y.len >= (n - 1) * incy + 1);

    const n_ = dim(n);
    const lda_ = dim(lda);
    const incx_ = dim(incx);
    const incy_ = dim(incy);
    sym(T, "symv")(opt(uplo), ref(&n_), ref(&alpha), a.ptr, ref(&lda_), x.ptr, ref(&incx_), ref(&beta), y.ptr, ref(&incy_));
}

/// `A := alpha * x * x^T + A` for a complex symmetric `A`.
///
/// Note `x^T`, not `x^H` — this is the symmetric rank-1 update, so `alpha` may
/// be complex. `blas.her` requires a real alpha precisely because the Hermitian
/// version would otherwise stop being Hermitian; here there is no such
/// constraint.
pub fn syr(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    alpha: T,
    x: []const T,
    incx: usize,
    a: []T,
    lda: usize,
) void {
    requireComplex(T, "syr");
    assertMatrix(a.len, n, n, lda);
    std.debug.assert(incx >= 1);
    std.debug.assert(x.len >= (n - 1) * incx + 1);

    const n_ = dim(n);
    const lda_ = dim(lda);
    const incx_ = dim(incx);
    sym(T, "syr")(opt(uplo), ref(&n_), ref(&alpha), x.ptr, ref(&incx_), a.ptr, ref(&lda_));
}

/// `symv` for a matrix in packed storage.
pub fn spmv(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    alpha: T,
    ap: []const T,
    x: []const T,
    incx: usize,
    beta: T,
    y: []T,
    incy: usize,
) void {
    requireComplex(T, "spmv");
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(incx >= 1 and incy >= 1);

    const n_ = dim(n);
    const incx_ = dim(incx);
    const incy_ = dim(incy);
    sym(T, "spmv")(opt(uplo), ref(&n_), ref(&alpha), ap.ptr, x.ptr, ref(&incx_), ref(&beta), y.ptr, ref(&incy_));
}

/// `syr` for a matrix in packed storage.
pub fn spr(
    comptime T: type,
    uplo: Uplo,
    n: usize,
    alpha: T,
    x: []const T,
    incx: usize,
    ap: []T,
) void {
    requireComplex(T, "spr");
    std.debug.assert(ap.len >= packedLen(n));
    std.debug.assert(incx >= 1);

    const n_ = dim(n);
    const incx_ = dim(incx);
    sym(T, "spr")(opt(uplo), ref(&n_), ref(&alpha), x.ptr, ref(&incx_), ap.ptr);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

test "lamch reports the parameters of the running machine" {
    const eps = lamch(f64, .epsilon);
    const sfmin = lamch(f64, .safe_min);

    try testing.expect(eps > 0);
    try testing.expect(eps < 1e-10);
    // LAPACK's eps is the rounding unit, which is half of Zig's floatEps - the
    // gap to the next representable number. Mixing the two definitions gives a
    // tolerance off by a factor of two, which is exactly the sort of thing that
    // makes a routine "not behave as documented".
    try testing.expectApproxEqAbs(std.math.floatEps(f64) / 2, eps, 1e-20);

    try testing.expect(sfmin > 0);
    try testing.expectEqual(@as(f64, 2), lamch(f64, .base));
    try testing.expectEqual(@as(f64, 53), lamch(f64, .digits));

    // And single precision differs, as it must.
    try testing.expect(lamch(f32, .epsilon) > @as(f32, @floatCast(eps)));
    try testing.expectEqual(@as(f32, 24), lamch(f32, .digits));
}

test "ilaenv prepends the precision prefix" {
    // The routine name goes in without its prefix; the wrapper adds the one for
    // T, so the same call site reports the f32 and f64 block sizes.
    const nb_d = ilaenv(f64, 1, "GEQRF", " ", 100, 100, -1, -1);
    const nb_s = ilaenv(f32, 1, "GEQRF", " ", 100, 100, -1, -1);
    try testing.expect(nb_d > 0);
    try testing.expect(nb_s > 0);
}

test "larnv fills a vector and advances the seed" {
    var seed = Seed.init(1);
    var x: [16]f64 = undefined;
    larnv(f64, .uniform_01, &seed, &x);

    for (x) |v| {
        try testing.expect(v > 0 and v < 1);
    }

    // A second draw with the advanced seed differs from the first.
    var y: [16]f64 = undefined;
    larnv(f64, .uniform_01, &seed, &y);
    try testing.expect(!std.mem.eql(u8, std.mem.asBytes(&x), std.mem.asBytes(&y)));

    // And reseeding reproduces the first draw exactly.
    var again = Seed.init(1);
    var z: [16]f64 = undefined;
    larnv(f64, .uniform_01, &again, &z);
    try testing.expectEqualSlices(f64, &x, &z);
}

test "Seed.init always produces a valid seed" {
    // The last entry must be odd or the generator's period collapses, and
    // LAPACK does not check. Every value must come out valid, including the
    // ones whose fourth digit is naturally even.
    for ([_]u64{ 0, 1, 2, 4096, 4095, 12345678, std.math.maxInt(u64) }) |v| {
        const s = Seed.init(v);
        s.assertValid();
        try testing.expectEqual(@as(Int, 1), @rem(s.state[3], 2));
    }
}

test "larnv draws complex numbers on the unit circle" {
    const Z = Complex(f64);
    var seed = Seed.init(7);
    var x: [8]Z = undefined;
    larnv(Z, .unit_circle, &seed, &x);

    for (x) |v| {
        try testing.expectApproxEqAbs(@as(f64, 1), @sqrt(v.re * v.re + v.im * v.im), 1e-12);
    }
}

test "lartg builds a rotation that zeroes the second component" {
    const r = lartg(f64, 3, 4);

    // [c s; -s c] [3; 4] = [5; 0]
    try testing.expectApproxEqAbs(@as(f64, 5), r.r, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.6), r.cos, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.8), r.sin, 1e-12);

    // Verify the zeroing directly.
    const second = -r.sin * 3 + r.cos * 4;
    try testing.expectApproxEqAbs(@as(f64, 0), second, 1e-12);
}

test "a complex rotation keeps a real cosine" {
    const Z = Complex(f64);
    const r = lartg(Z, Z.init(3, 4), Z.init(0, 5));

    // The type says the cosine is real; this confirms the routine agrees.
    try testing.expectEqual(f64, @TypeOf(r.cos));
    try testing.expect(r.cos > 0 and r.cos < 1);
    // |r| = sqrt(|f|^2 + |g|^2) = sqrt(25 + 25).
    try testing.expectApproxEqAbs(@sqrt(@as(f64, 50)), @sqrt(r.r.re * r.r.re + r.r.im * r.r.im), 1e-12);
}

test "lascl scales without the overflow a direct ratio would cause" {
    // to / from overflows on its own: 1e300 / 1e-300 is not representable.
    // lascl splits the multiplication so the result, which is representable,
    // comes out correctly.
    var a = [_]f64{ 1e-300, 2e-300, 3e-300, 4e-300 };
    try lascl(f64, .full, 0, 0, 1e-300, 1e300, 2, 2, &a, 2);

    try testing.expect(std.math.isInf(@as(f64, 1e300) / @as(f64, 1e-300)));
    try testing.expectApproxEqRel(@as(f64, 1e300), a[0], 1e-12);
    try testing.expectApproxEqRel(@as(f64, 4e300), a[3], 1e-12);
}

test "rscl divides without overflowing" {
    // x / a where a is subnormal-small: the naive division overflows, this
    // does not.
    var x = [_]f64{ 1, 2, 3 };
    rscl(f64, 1e-300, &x, 1);
    try testing.expectApproxEqRel(@as(f64, 1e300), x[0], 1e-12);
    try testing.expectApproxEqRel(@as(f64, 3e300), x[2], 1e-12);
}

test "rscl reaches the two-letter complex symbol names" {
    // csrscl and zdrscl have two precision letters - one for the complex
    // vector, one for the real scalar - so the usual single-letter prefix
    // lookup does not find them.
    const Z = Complex(f64);
    var x = [_]Z{ Z.init(2, 4), Z.init(6, 8) };
    rscl(Z, 2, &x, 1);
    try testing.expectApproxEqAbs(@as(f64, 1), x[0].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2), x[0].im, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 4), x[1].im, 1e-12);
}

test "lasrt sorts both ways" {
    var x = [_]f64{ 3, 1, 4, 1, 5 };
    try lasrt(f64, .increasing, &x);
    try testing.expectEqualSlices(f64, &.{ 1, 1, 3, 4, 5 }, &x);

    try lasrt(f64, .decreasing, &x);
    try testing.expectEqualSlices(f64, &.{ 5, 4, 3, 1, 1 }, &x);
}

test "lacgv conjugates in place" {
    const Z = Complex(f64);
    var x = [_]Z{ Z.init(1, 2), Z.init(3, -4) };
    lacgv(Z, &x, 1);
    try testing.expectEqual(@as(f64, -2), x[0].im);
    try testing.expectEqual(@as(f64, 4), x[1].im);
}

test "ladiv wraps the SDK's mis-declared complex division" {
    // (1 + 2i) / (3 + 4i) = 0.44 + 0.08i. The underlying symbol ignores the
    // out-parameter the header says it writes; this wrapper hides that.
    const Z = Complex(f64);
    const q = ladiv(Z, Z.init(1, 2), Z.init(3, 4));
    try testing.expectApproxEqAbs(@as(f64, 0.44), q.re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0.08), q.im, 1e-12);

    // The point of using it over naive division: operands near the overflow
    // threshold still divide correctly.
    const big = Z.init(1e300, 1e300);
    const r = ladiv(Z, big, big);
    try testing.expectApproxEqAbs(@as(f64, 1), r.re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), r.im, 1e-12);
}

test "symv treats the matrix as symmetric, not Hermitian" {
    // A = [[1, 2i], [2i, 1]] is complex symmetric (A = A^T) but not Hermitian.
    // Stored upper, so the strict lower is never read.
    const Z = Complex(f64);
    const a = [_]Z{ Z.init(1, 0), Z.init(-999, -999), Z.init(0, 2), Z.init(1, 0) };
    const x = [_]Z{ Z.init(1, 0), Z.init(0, 0) };
    var y = [_]Z{ Z.zero, Z.zero };

    symv(Z, .upper, 2, Z.one, &a, 2, &x, 1, Z.zero, &y, 1);

    // A * [1, 0]^T is the first column: [1, 2i]. Reflecting the stored 2i
    // across the diagonal *without* conjugating is what makes this symmetric;
    // hemv would have produced -2i in the second entry.
    try testing.expectApproxEqAbs(@as(f64, 1), y[0].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), y[1].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 2), y[1].im, 1e-12);
}

test "symv and hemv disagree, which is the whole point" {
    const Z = Complex(f64);
    const blas = @import("../blas/root.zig");
    const BZ = blas.Complex(f64);

    const a = [_]Z{ Z.init(1, 0), Z.init(0, 0), Z.init(0, 2), Z.init(1, 0) };
    const x = [_]Z{ Z.init(1, 0), Z.init(0, 0) };
    var y_sym = [_]Z{ Z.zero, Z.zero };
    symv(Z, .upper, 2, Z.one, &a, 2, &x, 1, Z.zero, &y_sym, 1);

    // The same stored triangle read as Hermitian.
    const ba = [_]BZ{ BZ.init(1, 0), BZ.init(0, 0), BZ.init(0, 2), BZ.init(1, 0) };
    const bx = [_]BZ{ BZ.init(1, 0), BZ.init(0, 0) };
    var y_herm = [_]BZ{ BZ.zero, BZ.zero };
    blas.hemv(BZ, .col_major, .upper, 2, BZ.one, &ba, 2, &bx, 1, BZ.zero, &y_herm, 1);

    // Symmetric reflects A(1,2) = 2i to A(2,1) = 2i; Hermitian conjugates it to
    // -2i. Nothing in either library would tell you which one you wanted.
    try testing.expectApproxEqAbs(@as(f64, 2), y_sym[1].im, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, -2), y_herm[1].im, 1e-12);
}

test "syr allows a complex alpha where her does not" {
    // blas.her requires a real alpha, because a complex one would make the
    // result non-Hermitian. The symmetric update has no such constraint, and
    // the signature reflects that: alpha is T, not Scalar(T).
    const Z = Complex(f64);
    var a = [_]Z{ Z.zero, Z.zero, Z.zero, Z.zero };
    const x = [_]Z{ Z.init(1, 0), Z.init(0, 1) };

    syr(Z, .upper, 2, Z.init(0, 1), &x, 1, &a, 2);

    // alpha * x x^T with alpha = i, x = [1, i]:
    //   x x^T = [[1, i], [i, -1]], times i = [[i, -1], [-1, -i]].
    try testing.expectApproxEqAbs(@as(f64, 1), a[0].im, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, -1), a[2].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, -1), a[3].im, 1e-12);
}

test "spmv and spr work in packed storage" {
    const Z = Complex(f64);
    // Upper packed [[1, 2i], [2i, 1]] is a11, a12, a22.
    const ap = [_]Z{ Z.init(1, 0), Z.init(0, 2), Z.init(1, 0) };
    const x = [_]Z{ Z.init(1, 0), Z.init(0, 0) };
    var y = [_]Z{ Z.zero, Z.zero };

    spmv(Z, .upper, 2, Z.one, &ap, &x, 1, Z.zero, &y, 1);
    try testing.expectApproxEqAbs(@as(f64, 2), y[1].im, 1e-12);

    var packed_a = [_]Z{ Z.zero, Z.zero, Z.zero };
    spr(Z, .upper, 2, Z.one, &x, 1, &packed_a);
    // x x^T with x = [1, 0] puts 1 in the (1,1) entry only.
    try testing.expectApproxEqAbs(@as(f64, 1), packed_a[0].re, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), packed_a[2].re, 1e-12);
}

test "single precision complex works through the same wrappers" {
    const Z = Complex(f32);
    const q = ladiv(Z, Z.init(1, 2), Z.init(3, 4));
    try testing.expectApproxEqAbs(@as(f32, 0.44), q.re, 1e-6);
}
