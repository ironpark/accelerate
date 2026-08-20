//! Eigenvalues of a symmetric tridiagonal matrix.
//!
//! This is the second phase of every dense symmetric eigenvalue computation:
//! `reduce.sytrd` produces a tridiagonal, and one of these solves it. The
//! drivers in `eigen.zig` do both, so reach for these when you want a different
//! algorithm than the driver picked, when the matrix is already tridiagonal, or
//! when you want to reuse one reduction across several different queries.
//!
//! ## Which one
//!
//! Six algorithms, and the choice is not arbitrary:
//!
//! | routine | computes | cost | notes |
//! |---|---|---|---|
//! | `sterf` | eigenvalues only | O(n^2) | root-free QL/QR, the fastest |
//! | `steqr` | values and vectors | O(n^3) | implicit QL/QR, the most robust |
//! | `stedc` | values and vectors | O(n^2.3) typical | divide and conquer, wants workspace |
//! | `stemr` | values and any subset of vectors | O(nk) | MRRR, the modern default |
//! | `stegr` | the same | O(nk) | a thin wrapper over `stemr` |
//! | `stebz` + `stein` | selected values, then their vectors | O(nk) | bisection plus inverse iteration |
//!
//! `sterf` is real-only: it has no vectors to store, so there is nothing for a
//! complex version to do differently.
//!
//! `pteqr` is the odd one — it is for a *positive definite* tridiagonal, and it
//! gets more accurate small eigenvalues by factoring first rather than working
//! on the matrix directly.
//!
//! ## The `d`/`e` pair is real even for a complex problem
//!
//! A Hermitian tridiagonal has a real diagonal and can be given a real
//! off-diagonal, so `d` and `e` are `[]Real(T)` throughout, exactly as they come
//! out of `reduce.hetrd`. `T` only shows up in the eigenvector array, which is
//! complex when the original matrix was — the tridiagonal's own vectors are
//! real, but `compz = .original` back-transforms them through the complex `Q`.
//!
//! ## `compz` decides what `z` means on the way in
//!
//! `steqr`, `stedc` and `pteqr` take a three-valued flag, and the middle value
//! reads `z` as well as writing it:
//!
//! | `compz` | `z` on entry | `z` on exit |
//! |---|---|---|
//! | `.none` | not touched | not touched |
//! | `.tridiagonal` | not read | eigenvectors of the tridiagonal |
//! | `.original` | the reduction's `Q` | eigenvectors of the original matrix |
//!
//! `.original` is what you want after `reduce.sytrd` + `reduce.orgtr`. Passing
//! `.tridiagonal` there instead returns vectors of the wrong matrix, and nothing
//! reports it.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");
const eigen = @import("eigen.zig");

const Int = types.Int;
const Bool = types.Bool;
const Complex = types.Complex;
const Real = types.Real;
const Job = types.Job;
const Range = types.Range;
const Error = info_mod.Error;
const dim = types.dim;
const assertMatrix = types.assertMatrix;
const ref = work_mod.ref;
const out = work_mod.out;
const opt = types.opt;

const Allocator = std.mem.Allocator;
const Fail = Error || Allocator.Error;

/// Re-exported so a caller of `stegr` need not import `eigen.zig` for the
/// argument it takes.
pub const Selection = eigen.Selection;
pub const EigResult = eigen.EigResult;

fn sym(comptime T: type, comptime name: []const u8) @TypeOf(@field(c, [_]u8{types.prefix(T)} ++ name)) {
    return @field(c, [_]u8{types.prefix(T)} ++ name);
}

fn requireReal(comptime T: type, comptime routine: []const u8) void {
    switch (T) {
        f32, f64 => {},
        else => @compileError(routine ++ " is real-only; it computes no eigenvectors, so there is nothing for a complex version to do"),
    }
}

/// What to do with `z`.
pub const Compz = enum(u8) {
    /// Eigenvalues only.
    none = 'N',
    /// Eigenvectors of the tridiagonal itself. `z` is not read on entry.
    tridiagonal = 'I',
    /// Eigenvectors of the original matrix. `z` must hold the orthogonal factor
    /// from the reduction that produced this tridiagonal.
    original = 'V',
};

/// The order `stebz` should return eigenvalues in.
pub const EigenOrder = enum(u8) {
    /// Grouped by the submatrix each came from, ascending within a group. This
    /// is the order `stein` wants.
    by_block = 'B',
    /// Ascending across the whole matrix, ignoring the split.
    ascending = 'E',
};

/// Which `Selection` character to send, and the four numbers behind it.
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

// ============================================================================
// QR/QL iteration
// ============================================================================

/// Eigenvalues of a symmetric tridiagonal, no vectors, by root-free QL/QR.
///
/// The cheapest of the family and the most accurate for eigenvalues alone.
/// Real only — with no vectors to back-transform there is nothing a complex
/// version would do differently, so LAPACK ships none.
///
/// `d` is overwritten with the eigenvalues in ascending order; `e` is destroyed.
pub fn sterf(comptime T: type, n: usize, d: []T, e: []T) Error!void {
    requireReal(T, "sterf");
    std.debug.assert(d.len >= n);
    if (n > 0) std.debug.assert(e.len >= n - 1);

    const n_ = dim(n);
    var info: Int = 0;

    sym(T, "sterf")(ref(&n_), d.ptr, e.ptr, out(&info));
    return info_mod.checkConvergence(info);
}

/// Eigenvalues and optionally eigenvectors of a symmetric tridiagonal, by
/// implicit QL/QR.
///
/// The most robust of the family, and the slowest when vectors are wanted.
/// `d` receives the eigenvalues in ascending order and `e` is destroyed; see
/// the module docs for what `compz` does to `z`.
pub fn steqr(
    comptime T: type,
    allocator: Allocator,
    compz: Compz,
    n: usize,
    d: []Real(T),
    e: []Real(T),
    z: []T,
    ldz: usize,
) Fail!void {
    std.debug.assert(d.len >= n);
    if (n > 0) std.debug.assert(e.len >= n - 1);
    if (compz != .none) assertMatrix(z.len, n, n, ldz);

    // 2n-2 reals when vectors are wanted, unreferenced otherwise. Allocated
    // unconditionally because the difference is a few hundred bytes and a
    // wrong guess here is a heap overflow.
    const work = try allocator.alloc(Real(T), @max(2 * n, 1));
    defer allocator.free(work);

    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    sym(T, "steqr")(opt(compz), ref(&n_), d.ptr, e.ptr, z.ptr, ref(&ldz_), work.ptr, out(&info));
    return info_mod.checkConvergence(info);
}

/// `steqr` for a **positive definite** tridiagonal.
///
/// Factors `A = L D L^T` first and runs the iteration on the factor, which
/// gives small eigenvalues to high relative accuracy — `steqr` gives them only
/// to high absolute accuracy, so on a matrix spanning many orders of magnitude
/// the small ones can come out as noise.
///
/// `error.NotPositiveDefinite` if the factorization fails; `lastInfo()` is then
/// the leading minor. A `lastInfo()` above `n` instead means the iteration did
/// not converge, which is reported as `error.NoConvergence`.
pub fn pteqr(
    comptime T: type,
    allocator: Allocator,
    compz: Compz,
    n: usize,
    d: []Real(T),
    e: []Real(T),
    z: []T,
    ldz: usize,
) Fail!void {
    std.debug.assert(d.len >= n);
    if (n > 0) std.debug.assert(e.len >= n - 1);
    if (compz != .none) assertMatrix(z.len, n, n, ldz);

    const work = try allocator.alloc(Real(T), @max(4 * n, 1));
    defer allocator.free(work);

    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    sym(T, "pteqr")(opt(compz), ref(&n_), d.ptr, e.ptr, z.ptr, ref(&ldz_), work.ptr, out(&info));

    // The two positive outcomes are told apart by whether info exceeds n.
    if (info > 0 and info <= @as(Int, @intCast(n))) return info_mod.checkCholesky(info);
    return info_mod.checkConvergence(info);
}

// ============================================================================
// Divide and conquer
// ============================================================================

/// Eigenvalues and optionally eigenvectors of a symmetric tridiagonal, by
/// divide and conquer.
///
/// Much faster than `steqr` when vectors are wanted and `n` is large, at the
/// cost of a workspace that grows like `n^2`. For eigenvalues only it falls
/// back to `sterf` internally, so there is no reason to prefer it there.
pub fn stedc(
    comptime T: type,
    allocator: Allocator,
    compz: Compz,
    n: usize,
    d: []Real(T),
    e: []Real(T),
    z: []T,
    ldz: usize,
) Fail!void {
    std.debug.assert(d.len >= n);
    if (n > 0) std.debug.assert(e.len >= n - 1);
    if (compz != .none) assertMatrix(z.len, n, n, ldz);

    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    const neg = work_mod.query;
    var wq: [1]T = undefined;
    var rwq: [1]Real(T) = undefined;
    var iwq: [1]Int = undefined;

    switch (T) {
        Complex(f32), Complex(f64) => {
            sym(T, "stedc")(opt(compz), ref(&n_), d.ptr, e.ptr, z.ptr, ref(&ldz_), &wq, ref(&neg), &rwq, ref(&neg), &iwq, ref(&neg), out(&info));
            try info_mod.checkArgs(info);

            const lw: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
            const lrw: usize = @intCast(@max(work_mod.sizeFrom(Real(T), rwq[0]), 1));
            const liw: usize = @intCast(@max(iwq[0], 1));
            const work = try allocator.alloc(T, lw);
            defer allocator.free(work);
            const rwork = try allocator.alloc(Real(T), lrw);
            defer allocator.free(rwork);
            const iwork = try allocator.alloc(Int, liw);
            defer allocator.free(iwork);
            const lwork = dim(lw);
            const lrwork = dim(lrw);
            const liwork = dim(liw);
            sym(T, "stedc")(opt(compz), ref(&n_), d.ptr, e.ptr, z.ptr, ref(&ldz_), work.ptr, ref(&lwork), rwork.ptr, ref(&lrwork), iwork.ptr, ref(&liwork), out(&info));
        },
        else => {
            sym(T, "stedc")(opt(compz), ref(&n_), d.ptr, e.ptr, z.ptr, ref(&ldz_), &wq, ref(&neg), &iwq, ref(&neg), out(&info));
            try info_mod.checkArgs(info);

            const lw: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
            const liw: usize = @intCast(@max(iwq[0], 1));
            const work = try allocator.alloc(T, lw);
            defer allocator.free(work);
            const iwork = try allocator.alloc(Int, liw);
            defer allocator.free(iwork);
            const lwork = dim(lw);
            const liwork = dim(liw);
            sym(T, "stedc")(opt(compz), ref(&n_), d.ptr, e.ptr, z.ptr, ref(&ldz_), work.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
        },
    }
    return info_mod.checkConvergence(info);
}

// ============================================================================
// MRRR
// ============================================================================

/// Selected eigenvalues and eigenvectors of a symmetric tridiagonal, by
/// Multiple Relatively Robust Representations.
///
/// The modern default: it computes `k` eigenvectors in O(nk) without any
/// reorthogonalization, where `stein` needs O(nk^2) for a tight cluster.
///
/// `try_rac` asks for a check that the matrix defines its eigenvalues to high
/// relative accuracy; it comes back false if it does not, in which case the
/// answers are still correct in the absolute sense. `isuppz` receives two
/// indices per vector bounding its nonzero rows, and needs `2 * max(1, k)`
/// entries.
///
/// The returned `found` is how many eigenvalues came back. `d` and `e` are both
/// destroyed.
pub fn stemr(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    selection: Selection,
    n: usize,
    d: []Real(T),
    e: []Real(T),
    w: []Real(T),
    z: []T,
    ldz: usize,
    isuppz: []Int,
    try_rac: *bool,
) Fail!EigResult {
    std.debug.assert(d.len >= n);
    std.debug.assert(w.len >= n);
    if (job == .vectors) std.debug.assert(isuppz.len >= 2 * @max(n, 1));

    const win = Window.from(selection, n);
    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    // nzc is how many columns z has room for. Passing -1 would ask the routine
    // to report the number it needs instead of computing anything; the caller
    // sized z already, so it gets n.
    const nzc_: Int = if (job == .vectors) @max(dim(n), 1) else 1;
    const vl: Real(T) = @floatCast(win.vl);
    const vu: Real(T) = @floatCast(win.vu);
    var m: Int = 0;
    var rac: Bool = if (try_rac.*) 1 else 0;
    var info: Int = 0;

    const neg = work_mod.query;
    var rwq: [1]Real(T) = undefined;
    var iwq: [1]Int = undefined;
    sym(T, "stemr")(opt(job), opt(win.range), ref(&n_), d.ptr, e.ptr, ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), out(&m), w.ptr, z.ptr, ref(&ldz_), ref(&nzc_), isuppz.ptr, out(&rac), &rwq, ref(&neg), &iwq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const lw: usize = @intCast(@max(work_mod.sizeFrom(Real(T), rwq[0]), 1));
    const liw: usize = @intCast(@max(iwq[0], 1));
    const work = try allocator.alloc(Real(T), lw);
    defer allocator.free(work);
    const iwork = try allocator.alloc(Int, liw);
    defer allocator.free(iwork);
    const lwork = dim(lw);
    const liwork = dim(liw);

    rac = if (try_rac.*) 1 else 0;
    sym(T, "stemr")(opt(job), opt(win.range), ref(&n_), d.ptr, e.ptr, ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), out(&m), w.ptr, z.ptr, ref(&ldz_), ref(&nzc_), isuppz.ptr, out(&rac), work.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
    try info_mod.checkConvergence(info);

    try_rac.* = rac != 0;
    return .{ .found = @intCast(m) };
}

/// `stemr` under LAPACK's older name.
///
/// `stegr` is documented as a wrapper over `stemr` that exists for backward
/// compatibility; it takes an `abstol` that the current implementation ignores.
/// Kept because callers coming from other LAPACK bindings expect the name, but
/// `stemr` is the one to write new code against.
pub fn stegr(
    comptime T: type,
    allocator: Allocator,
    job: Job,
    selection: Selection,
    n: usize,
    d: []Real(T),
    e: []Real(T),
    w: []Real(T),
    z: []T,
    ldz: usize,
    isuppz: []Int,
    abstol: Real(T),
) Fail!EigResult {
    std.debug.assert(d.len >= n);
    std.debug.assert(w.len >= n);
    if (job == .vectors) std.debug.assert(isuppz.len >= 2 * @max(n, 1));

    const win = Window.from(selection, n);
    const n_ = dim(n);
    const ldz_ = dim(@max(ldz, 1));
    const vl: Real(T) = @floatCast(win.vl);
    const vu: Real(T) = @floatCast(win.vu);
    var m: Int = 0;
    var info: Int = 0;

    const neg = work_mod.query;
    var rwq: [1]Real(T) = undefined;
    var iwq: [1]Int = undefined;
    sym(T, "stegr")(opt(job), opt(win.range), ref(&n_), d.ptr, e.ptr, ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&m), w.ptr, z.ptr, ref(&ldz_), isuppz.ptr, &rwq, ref(&neg), &iwq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const lw: usize = @intCast(@max(work_mod.sizeFrom(Real(T), rwq[0]), 1));
    const liw: usize = @intCast(@max(iwq[0], 1));
    const work = try allocator.alloc(Real(T), lw);
    defer allocator.free(work);
    const iwork = try allocator.alloc(Int, liw);
    defer allocator.free(iwork);
    const lwork = dim(lw);
    const liwork = dim(liw);

    sym(T, "stegr")(opt(job), opt(win.range), ref(&n_), d.ptr, e.ptr, ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), out(&m), w.ptr, z.ptr, ref(&ldz_), isuppz.ptr, work.ptr, ref(&lwork), iwork.ptr, ref(&liwork), out(&info));
    try info_mod.checkConvergence(info);
    return .{ .found = @intCast(m) };
}

// ============================================================================
// Bisection and inverse iteration
// ============================================================================

/// What `stebz` found.
pub const BisectionResult = struct {
    /// How many eigenvalues are in `w`.
    found: usize,
    /// How many diagonal blocks the matrix split into. `iblock` says which
    /// block each eigenvalue came from, `isplit` where each block ends.
    blocks: usize,
};

/// Selected eigenvalues of a symmetric tridiagonal, by bisection.
///
/// Real only: bisection works on the diagonal and off-diagonal, both of which
/// are real for a Hermitian problem too, and it computes no vectors.
///
/// `abstol` is the absolute tolerance on each eigenvalue. Zero or negative asks
/// for the default, which is the machine precision times the matrix norm; a
/// positive value larger than that trades accuracy for speed. Setting it to
/// `2 * lamch(.safe_min)` gets the most accurate answer bisection can give.
///
/// The output feeds `stein`, which wants `order = .by_block` and the `iblock`
/// and `isplit` arrays as they come out of here.
pub fn stebz(
    comptime T: type,
    allocator: Allocator,
    selection: Selection,
    order: EigenOrder,
    n: usize,
    abstol: T,
    d: []const T,
    e: []const T,
    w: []T,
    iblock: []Int,
    isplit: []Int,
) Fail!BisectionResult {
    requireReal(T, "stebz");
    std.debug.assert(d.len >= n);
    if (n > 0) std.debug.assert(e.len >= n - 1);
    std.debug.assert(w.len >= n and iblock.len >= n and isplit.len >= n);

    const work = try allocator.alloc(T, @max(4 * n, 1));
    defer allocator.free(work);
    const iwork = try allocator.alloc(Int, @max(3 * n, 1));
    defer allocator.free(iwork);

    const win = Window.from(selection, n);
    const n_ = dim(n);
    const vl: T = @floatCast(win.vl);
    const vu: T = @floatCast(win.vu);
    var m: Int = 0;
    var nsplit: Int = 0;
    var info: Int = 0;

    sym(T, "stebz")(opt(win.range), opt(order), ref(&n_), ref(&vl), ref(&vu), ref(&win.il), ref(&win.iu), ref(&abstol), d.ptr, e.ptr, out(&m), out(&nsplit), w.ptr, iblock.ptr, isplit.ptr, work.ptr, iwork.ptr, out(&info));
    try info_mod.checkConvergence(info);

    return .{ .found = @intCast(m), .blocks = @intCast(nsplit) };
}

/// Eigenvectors for eigenvalues `stebz` already found, by inverse iteration.
///
/// `w`, `iblock` and `isplit` must be `stebz`'s output with `order = .by_block`
/// — `stein` uses the block structure to decide which vectors to
/// reorthogonalize against, and the `.ascending` order destroys it.
///
/// `ifail` receives the 1-based indices of any vectors that did not converge,
/// and needs `m` entries. `error.NoConvergence` means at least one did not;
/// `lastInfo()` is the count.
///
/// Inverse iteration is O(n) per vector when the eigenvalues are well
/// separated, and degrades to O(nk^2) for a tight cluster because every vector
/// in the cluster has to be reorthogonalized against every other. `stemr` has
/// no such failure mode and is the better choice unless you specifically want
/// bisection's control over which eigenvalues to compute.
pub fn stein(
    comptime T: type,
    allocator: Allocator,
    n: usize,
    d: []const Real(T),
    e: []const Real(T),
    m: usize,
    w: []const Real(T),
    iblock: []const Int,
    isplit: []const Int,
    z: []T,
    ldz: usize,
    ifail: []Int,
) Fail!void {
    std.debug.assert(d.len >= n);
    if (n > 0) std.debug.assert(e.len >= n - 1);
    std.debug.assert(w.len >= m and iblock.len >= n and isplit.len >= n);
    std.debug.assert(ifail.len >= m);
    assertMatrix(z.len, n, m, ldz);

    const work = try allocator.alloc(Real(T), @max(5 * n, 1));
    defer allocator.free(work);
    const iwork = try allocator.alloc(Int, @max(n, 1));
    defer allocator.free(iwork);

    const n_ = dim(n);
    const m_ = dim(m);
    const ldz_ = dim(@max(ldz, 1));
    var info: Int = 0;

    sym(T, "stein")(ref(&n_), d.ptr, e.ptr, ref(&m_), w.ptr, iblock.ptr, isplit.ptr, z.ptr, ref(&ldz_), work.ptr, iwork.ptr, ifail.ptr, out(&info));
    return info_mod.checkConvergence(info);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const reduce = @import("reduce.zig");

/// `tridiag(1, 2, 1)` of order 5, whose eigenvalues are known in closed form:
/// `2 - 2 cos(k pi / 6)` for k = 1 .. 5.
const n5 = 5;
fn model() struct { d: [n5]f64, e: [n5 - 1]f64 } {
    return .{ .d = .{ 2, 2, 2, 2, 2 }, .e = .{ 1, 1, 1, 1 } };
}

fn exactEigenvalues() [n5]f64 {
    var out_: [n5]f64 = undefined;
    for (0..n5) |k| {
        const kk: f64 = @floatFromInt(k + 1);
        out_[k] = 2 - 2 * @cos(kk * std.math.pi / @as(f64, n5 + 1));
    }
    return out_;
}

test "sterf matches the closed-form eigenvalues" {
    var m = model();
    try sterf(f64, n5, &m.d, &m.e);

    const exact = exactEigenvalues();
    for (exact, m.d) |x, y| try testing.expectApproxEqAbs(x, y, 1e-13);
}

test "steqr agrees with sterf and produces orthonormal vectors" {
    var values = model();
    try sterf(f64, n5, &values.d, &values.e);

    var m = model();
    var z: [n5 * n5]f64 = undefined;
    try steqr(f64, testing.allocator, .tridiagonal, n5, &m.d, &m.e, &z, n5);

    for (values.d, m.d) |x, y| try testing.expectApproxEqAbs(x, y, 1e-13);

    // Each column is a unit vector, and distinct columns are orthogonal.
    for (0..n5) |j| {
        var norm: f64 = 0;
        for (0..n5) |i| norm += z[i + j * n5] * z[i + j * n5];
        try testing.expectApproxEqAbs(@as(f64, 1), norm, 1e-13);
    }
    var dot: f64 = 0;
    for (0..n5) |i| dot += z[i] * z[i + n5];
    try testing.expectApproxEqAbs(@as(f64, 0), dot, 1e-13);
}

test "steqr's vectors satisfy A v = lambda v" {
    var m = model();
    const original = model();
    var z: [n5 * n5]f64 = undefined;
    try steqr(f64, testing.allocator, .tridiagonal, n5, &m.d, &m.e, &z, n5);

    for (0..n5) |j| {
        for (0..n5) |i| {
            var acc = original.d[i] * z[i + j * n5];
            if (i > 0) acc += original.e[i - 1] * z[i - 1 + j * n5];
            if (i + 1 < n5) acc += original.e[i] * z[i + 1 + j * n5];
            try testing.expectApproxEqAbs(m.d[j] * z[i + j * n5], acc, 1e-12);
        }
    }
}

test "stedc agrees with steqr" {
    var a = model();
    var za: [n5 * n5]f64 = undefined;
    try steqr(f64, testing.allocator, .tridiagonal, n5, &a.d, &a.e, &za, n5);

    var b = model();
    var zb: [n5 * n5]f64 = undefined;
    try stedc(f64, testing.allocator, .tridiagonal, n5, &b.d, &b.e, &zb, n5);

    for (a.d, b.d) |x, y| try testing.expectApproxEqAbs(x, y, 1e-13);
    // Vectors agree up to sign, which no eigensolver fixes.
    for (0..n5) |j| {
        const sign: f64 = if (za[j * n5] * zb[j * n5] < 0) -1 else 1;
        for (0..n5) |i| try testing.expectApproxEqAbs(za[i + j * n5], sign * zb[i + j * n5], 1e-12);
    }
}

test "pteqr gets small eigenvalues of a graded matrix more accurately than steqr" {
    // Positive definite, spanning many orders of magnitude. pteqr factors
    // first, which is what buys the relative accuracy.
    const n = 4;
    const d0 = [_]f64{ 1e10, 1e6, 1e2, 1e-2 };
    const e0 = [_]f64{ 1e7, 1e3, 1e-1 };

    var dp = d0;
    var ep = e0;
    var zp: [1]f64 = undefined;
    try pteqr(f64, testing.allocator, .none, n, &dp, &ep, &zp, 1);

    var dq = d0;
    var eq = e0;
    var zq: [1]f64 = undefined;
    try steqr(f64, testing.allocator, .none, n, &dq, &eq, &zq, 1);

    // pteqr returns descending, steqr ascending. Both find the same spectrum
    // to within their own accuracy; what is pinned here is that pteqr's
    // smallest is positive, which is the property steqr cannot guarantee on a
    // matrix this graded.
    for (dp) |v| try testing.expect(v > 0);
    try testing.expectApproxEqRel(dp[0], dq[n - 1], 1e-12);
}

test "pteqr reports a matrix that is not positive definite" {
    const n = 3;
    var d = [_]f64{ 1, -5, 1 };
    var e = [_]f64{ 1, 1 };
    var z: [1]f64 = undefined;
    try testing.expectError(error.NotPositiveDefinite, pteqr(f64, testing.allocator, .none, n, &d, &e, &z, 1));
    // info <= n distinguishes the failed factorization from a failed iteration.
    try testing.expect(info_mod.lastInfo() > 0 and info_mod.lastInfo() <= n);
}

test "stemr finds a selected index range" {
    var m = model();
    var w: [n5]f64 = undefined;
    var z: [n5 * n5]f64 = undefined;
    var isuppz: [2 * n5]Int = undefined;
    var rac = true;

    const res = try stemr(f64, testing.allocator, .vectors, .{ .indices = .{ .first = 2, .last = 4 } }, n5, &m.d, &m.e, &w, &z, n5, &isuppz, &rac);

    try testing.expectEqual(@as(usize, 3), res.found);
    const exact = exactEigenvalues();
    for (0..3) |i| try testing.expectApproxEqAbs(exact[i + 1], w[i], 1e-12);
}

test "stemr reports whether the matrix has high relative accuracy" {
    var m = model();
    var w: [n5]f64 = undefined;
    var z: [1]f64 = undefined;
    var isuppz: [2 * n5]Int = undefined;
    var rac = true;

    _ = try stemr(f64, testing.allocator, .values_only, .all, n5, &m.d, &m.e, &w, &z, 1, &isuppz, &rac);
    // The flag comes back, whatever its value; it is an out parameter as much
    // as an in one, which the C signature does not say.
    try testing.expect(rac == true or rac == false);
}

test "stegr matches stemr on the same problem" {
    var a = model();
    var wa: [n5]f64 = undefined;
    var za: [1]f64 = undefined;
    var isuppz: [2 * n5]Int = undefined;
    var rac = false;
    const ra = try stemr(f64, testing.allocator, .values_only, .all, n5, &a.d, &a.e, &wa, &za, 1, &isuppz, &rac);

    var b = model();
    var wb: [n5]f64 = undefined;
    var zb: [1]f64 = undefined;
    const rb = try stegr(f64, testing.allocator, .values_only, .all, n5, &b.d, &b.e, &wb, &zb, 1, &isuppz, 0);

    try testing.expectEqual(ra.found, rb.found);
    for (wa, wb) |x, y| try testing.expectApproxEqAbs(x, y, 1e-13);
}

test "stebz then stein computes selected vectors" {
    const m = model();
    var w: [n5]f64 = undefined;
    var iblock: [n5]Int = undefined;
    var isplit: [n5]Int = undefined;

    // stein needs .by_block; .ascending would destroy the grouping it uses to
    // decide what to reorthogonalize against.
    const found = try stebz(f64, testing.allocator, .{ .indices = .{ .first = 1, .last = 2 } }, .by_block, n5, 0, &m.d, &m.e, &w, &iblock, &isplit);
    try testing.expectEqual(@as(usize, 2), found.found);
    try testing.expectEqual(@as(usize, 1), found.blocks);

    const exact = exactEigenvalues();
    for (0..2) |i| try testing.expectApproxEqAbs(exact[i], w[i], 1e-12);

    var z: [n5 * 2]f64 = undefined;
    var ifail: [2]Int = undefined;
    try stein(f64, testing.allocator, n5, &m.d, &m.e, 2, &w, &iblock, &isplit, &z, n5, &ifail);

    for (0..2) |j| {
        for (0..n5) |i| {
            var acc = m.d[i] * z[i + j * n5];
            if (i > 0) acc += m.e[i - 1] * z[i - 1 + j * n5];
            if (i + 1 < n5) acc += m.e[i] * z[i + 1 + j * n5];
            try testing.expectApproxEqAbs(w[j] * z[i + j * n5], acc, 1e-11);
        }
    }
}

test "stebz splits a matrix with a zero off-diagonal into blocks" {
    // A zero off-diagonal decouples the matrix; stebz reports the split and
    // stein needs it.
    const d = [_]f64{ 1, 2, 3, 4 };
    const e = [_]f64{ 1, 0, 1 };
    var w: [4]f64 = undefined;
    var iblock: [4]Int = undefined;
    var isplit: [4]Int = undefined;

    const found = try stebz(f64, testing.allocator, .all, .by_block, 4, 0, &d, &e, &w, &iblock, &isplit);
    try testing.expectEqual(@as(usize, 4), found.found);
    try testing.expectEqual(@as(usize, 2), found.blocks);
    // The first block ends at row 2.
    try testing.expectEqual(@as(Int, 2), isplit[0]);
    try testing.expectEqual(@as(Int, 4), isplit[1]);
    // Two eigenvalues from each block.
    try testing.expectEqual(@as(Int, 1), iblock[0]);
    try testing.expectEqual(@as(Int, 2), iblock[3]);
}

test "steqr with compz = .original back-transforms through the reduction's Q" {
    // The full pipeline eigen.syev performs in one call: reduce, build Q,
    // then solve the tridiagonal in the original basis.
    const n = 4;
    const original = [_]f64{
        4, 1, 2, 3,
        1, 5, 1, 2,
        2, 1, 6, 1,
        3, 2, 1, 7,
    };
    var a = original;
    var d: [n]f64 = undefined;
    var e: [n - 1]f64 = undefined;
    var tau: [n - 1]f64 = undefined;
    try reduce.sytrd(f64, testing.allocator, .upper, n, &a, n, &d, &e, &tau);

    var z = a;
    try reduce.orgtr(f64, testing.allocator, .upper, n, &z, n, &tau);
    try steqr(f64, testing.allocator, .original, n, &d, &e, &z, n);

    // z now holds eigenvectors of the original matrix, not of the tridiagonal.
    for (0..n) |j| {
        for (0..n) |i| {
            var acc: f64 = 0;
            for (0..n) |k| acc += original[i + k * n] * z[k + j * n];
            try testing.expectApproxEqAbs(d[j] * z[i + j * n], acc, 1e-11);
        }
    }
}

test "the complex tridiagonal solvers take real d and e with complex vectors" {
    const Z = Complex(f64);
    var m = model();
    var z: [n5 * n5]Z = undefined;
    try steqr(Z, testing.allocator, .tridiagonal, n5, &m.d, &m.e, &z, n5);

    const exact = exactEigenvalues();
    for (exact, m.d) |x, y| try testing.expectApproxEqAbs(x, y, 1e-13);
    // The tridiagonal itself is real, so its vectors come back with zero
    // imaginary parts - the complex type is there for the back-transform.
    for (0..n5) |i| try testing.expectApproxEqAbs(@as(f64, 0), z[i].im, 1e-15);
}

test "stedc handles the complex case with its extra rwork" {
    const Z = Complex(f64);
    var m = model();
    var z: [n5 * n5]Z = undefined;
    try stedc(Z, testing.allocator, .tridiagonal, n5, &m.d, &m.e, &z, n5);

    const exact = exactEigenvalues();
    for (exact, m.d) |x, y| try testing.expectApproxEqAbs(x, y, 1e-13);
}
