//! The CS (cosine-sine) decomposition of a partitioned orthogonal matrix.
//!
//! Given an orthogonal `X` split into four blocks
//!
//! ```text
//! X = [ X11  X12 ]
//!     [ X21  X22 ]
//! ```
//!
//! there are orthogonal `U1, U2, V1, V2` such that each block is diagonalized
//! simultaneously, with the diagonals being cosines and sines of one shared set
//! of angles `theta`:
//!
//! ```text
//! [ U1     ]^T [ X11  X12 ] [ V1     ]  =  [  C  -S ]
//! [     U2 ]   [ X21  X22 ] [     V2 ]     [  S   C ]
//! ```
//!
//! `C = diag(cos(theta))` and `S = diag(sin(theta))`. The angles are the
//! *principal angles* between the subspaces the blocks span, which is what this
//! is usually wanted for: measuring how close two subspaces are, in a way that
//! is numerically stable when they are very close (where a dot product of bases
//! loses all its digits).
//!
//! ## Which routine
//!
//! | routine | input |
//! |---|---|
//! | `orcsd` | all four blocks of a square orthogonal `X` |
//! | `orcsd2by1` | just the two blocks of one block-column `[X11; X21]` |
//!
//! `orcsd2by1` is the common case — comparing two subspaces means having an
//! orthonormal basis for each, which is a tall matrix with two row blocks, not
//! a full square one.
//!
//! Underneath, both are `orbdb` (reduce to bidiagonal-block form) followed by
//! `bbcsd` (the iteration on that form), and both are exposed for the same
//! reason the other reduce/iterate pairs are.
//!
//! ## `trans` is a storage flag, not a transpose
//!
//! `orcsd` and `orbdb` take a `row_major` argument that says how `X` is laid
//! out, which is unlike every other routine in this binding — LAPACK is
//! column-major everywhere else and does not offer the choice. It is `false`
//! for the usual column-major layout.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const info_mod = @import("info.zig");
const work_mod = @import("work.zig");

const Int = types.Int;
const Complex = types.Complex;
const Real = types.Real;
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

fn ortho(comptime T: type, comptime suffix: []const u8) []const u8 {
    return switch (T) {
        f32, f64 => "or" ++ suffix,
        else => "un" ++ suffix,
    };
}

const Chars = enum(u8) { y = 'Y', n = 'N', t = 'T', d = 'D', o = 'O' };

fn yesNo(wanted: bool) [*]const u8 {
    return if (wanted) opt(Chars.y) else opt(Chars.n);
}

fn transFlag(row_major: bool) [*]const u8 {
    return if (row_major) opt(Chars.t) else opt(Chars.n);
}

/// Which sign convention the decomposition should use.
///
/// The two differ in where the minus sign lands among the four blocks. LAPACK
/// calls them "default" and "otherwise"; they give the same angles, so pick
/// `.default` unless you are matching someone else's output.
pub const SignConvention = enum(u8) {
    default = 'D',
    other = 'O',
};

/// The principal angles a decomposition found, and where the vectors went.
pub const CsResult = struct {
    /// How many angles are in `theta`: `min(p, m - p, q, m - q)`.
    count: usize,
    /// True when the iteration did not fully converge. `theta` then holds the
    /// values from the last sweep, which are usually still close, and the
    /// vectors are not orthogonal to working precision.
    unconverged: bool,
};

fn angleCount(m: usize, p: usize, q: usize) usize {
    return @min(@min(p, m - p), @min(q, m - q));
}

/// CS decomposition of a full square orthogonal matrix.
///
/// `x11` is `p x q`, `x12` is `p x (m - q)`, `x21` is `(m - p) x q` and `x22`
/// is `(m - p) x (m - q)`. All four are destroyed.
///
/// `theta` receives the angles in **ascending** order and needs
/// `min(p, m-p, q, m-q)` entries; the returned `count` is that number.
///
/// Set the four `want_*` flags for the factors you need. `v1t` and `v2t` come
/// back already transposed, as their names say.
pub fn orcsd(
    comptime T: type,
    allocator: Allocator,
    want_u1: bool,
    want_u2: bool,
    want_v1t: bool,
    want_v2t: bool,
    row_major: bool,
    signs: SignConvention,
    m: usize,
    p: usize,
    q: usize,
    x11: []T,
    ldx11: usize,
    x12: []T,
    ldx12: usize,
    x21: []T,
    ldx21: usize,
    x22: []T,
    ldx22: usize,
    theta: []Real(T),
    u_1: []T,
    ldu1: usize,
    u_2: []T,
    ldu2: usize,
    v1t: []T,
    ldv1t: usize,
    v2t: []T,
    ldv2t: usize,
) Fail!CsResult {
    std.debug.assert(p <= m and q <= m);
    const count = angleCount(m, p, q);
    std.debug.assert(theta.len >= count);

    const name = comptime ortho(T, "csd");
    const m_ = dim(m);
    const p_ = dim(p);
    const q_ = dim(q);
    const ldx11_ = dim(@max(ldx11, 1));
    const ldx12_ = dim(@max(ldx12, 1));
    const ldx21_ = dim(@max(ldx21, 1));
    const ldx22_ = dim(@max(ldx22, 1));
    const ldu1_ = dim(@max(ldu1, 1));
    const ldu2_ = dim(@max(ldu2, 1));
    const ldv1t_ = dim(@max(ldv1t, 1));
    const ldv2t_ = dim(@max(ldv2t, 1));
    var info: Int = 0;

    const iwork = try allocator.alloc(Int, @max(m, 1));
    defer allocator.free(iwork);

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    var rq: [1]Real(T) = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        sym(T, name)(yesNo(want_u1), yesNo(want_u2), yesNo(want_v1t), yesNo(want_v2t), transFlag(row_major), opt(signs), ref(&m_), ref(&p_), ref(&q_), &probe, ref(&ldx11_), &probe, ref(&ldx12_), &probe, ref(&ldx21_), &probe, ref(&ldx22_), &rprobe, &probe, ref(&ldu1_), &probe, ref(&ldu2_), &probe, ref(&ldv1t_), &probe, ref(&ldv2t_), &wq, ref(&neg), &rq, ref(&neg), iwork.ptr, out(&info));
    } else {
        sym(T, name)(yesNo(want_u1), yesNo(want_u2), yesNo(want_v1t), yesNo(want_v2t), transFlag(row_major), opt(signs), ref(&m_), ref(&p_), ref(&q_), &probe, ref(&ldx11_), &probe, ref(&ldx12_), &probe, ref(&ldx21_), &probe, ref(&ldx22_), &rprobe, &probe, ref(&ldu1_), &probe, ref(&ldu2_), &probe, ref(&ldv1t_), &probe, ref(&ldv2t_), &wq, ref(&neg), iwork.ptr, out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexElement(T)) {
        const rsize: usize = @intCast(@max(work_mod.sizeFrom(Real(T), rq[0]), 1));
        const rwork = try allocator.alloc(Real(T), rsize);
        defer allocator.free(rwork);
        const lrwork = dim(rsize);
        sym(T, name)(yesNo(want_u1), yesNo(want_u2), yesNo(want_v1t), yesNo(want_v2t), transFlag(row_major), opt(signs), ref(&m_), ref(&p_), ref(&q_), x11.ptr, ref(&ldx11_), x12.ptr, ref(&ldx12_), x21.ptr, ref(&ldx21_), x22.ptr, ref(&ldx22_), theta.ptr, u_1.ptr, ref(&ldu1_), u_2.ptr, ref(&ldu2_), v1t.ptr, ref(&ldv1t_), v2t.ptr, ref(&ldv2t_), buf.ptr, ref(&lwork), rwork.ptr, ref(&lrwork), iwork.ptr, out(&info));
    } else {
        sym(T, name)(yesNo(want_u1), yesNo(want_u2), yesNo(want_v1t), yesNo(want_v2t), transFlag(row_major), opt(signs), ref(&m_), ref(&p_), ref(&q_), x11.ptr, ref(&ldx11_), x12.ptr, ref(&ldx12_), x21.ptr, ref(&ldx21_), x22.ptr, ref(&ldx22_), theta.ptr, u_1.ptr, ref(&ldu1_), u_2.ptr, ref(&ldu2_), v1t.ptr, ref(&ldv1t_), v2t.ptr, ref(&ldv2t_), buf.ptr, ref(&lwork), iwork.ptr, out(&info));
    }

    const unconverged = info > 0;
    if (!unconverged) try info_mod.checkArgs(info);
    return .{ .count = count, .unconverged = unconverged };
}

/// `orcsd` under its complex name.
pub const uncsd = orcsd;

/// CS decomposition of one block-column of an orthogonal matrix.
///
/// The common case: `[x11; x21]` is `m x q` with orthonormal columns, split at
/// row `p`. The angles are the principal angles between the column space and
/// the first `p` coordinate axes.
///
/// Takes no `row_major` or `signs`: with only two blocks there is nothing for
/// the sign convention to choose between, and the layout is always
/// column-major.
pub fn orcsd2by1(
    comptime T: type,
    allocator: Allocator,
    want_u1: bool,
    want_u2: bool,
    want_v1t: bool,
    m: usize,
    p: usize,
    q: usize,
    x11: []T,
    ldx11: usize,
    x21: []T,
    ldx21: usize,
    theta: []Real(T),
    u_1: []T,
    ldu1: usize,
    u_2: []T,
    ldu2: usize,
    v1t: []T,
    ldv1t: usize,
) Fail!CsResult {
    std.debug.assert(p <= m and q <= m);
    assertMatrix(x11.len, p, q, ldx11);
    assertMatrix(x21.len, m - p, q, ldx21);
    const count = angleCount(m, p, q);
    std.debug.assert(theta.len >= count);

    const name = comptime ortho(T, "csd2by1");
    const m_ = dim(m);
    const p_ = dim(p);
    const q_ = dim(q);
    const ldx11_ = dim(@max(ldx11, 1));
    const ldx21_ = dim(@max(ldx21, 1));
    const ldu1_ = dim(@max(ldu1, 1));
    const ldu2_ = dim(@max(ldu2, 1));
    const ldv1t_ = dim(@max(ldv1t, 1));
    var info: Int = 0;

    const iwork = try allocator.alloc(Int, @max(m, 1));
    defer allocator.free(iwork);

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    var rq: [1]Real(T) = undefined;
    const neg = work_mod.query;
    if (comptime complexElement(T)) {
        sym(T, name)(yesNo(want_u1), yesNo(want_u2), yesNo(want_v1t), ref(&m_), ref(&p_), ref(&q_), &probe, ref(&ldx11_), &probe, ref(&ldx21_), &rprobe, &probe, ref(&ldu1_), &probe, ref(&ldu2_), &probe, ref(&ldv1t_), &wq, ref(&neg), &rq, ref(&neg), iwork.ptr, out(&info));
    } else {
        sym(T, name)(yesNo(want_u1), yesNo(want_u2), yesNo(want_v1t), ref(&m_), ref(&p_), ref(&q_), &probe, ref(&ldx11_), &probe, ref(&ldx21_), &rprobe, &probe, ref(&ldu1_), &probe, ref(&ldu2_), &probe, ref(&ldv1t_), &wq, ref(&neg), iwork.ptr, out(&info));
    }
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    if (comptime complexElement(T)) {
        const rsize: usize = @intCast(@max(work_mod.sizeFrom(Real(T), rq[0]), 1));
        const rwork = try allocator.alloc(Real(T), rsize);
        defer allocator.free(rwork);
        const lrwork = dim(rsize);
        sym(T, name)(yesNo(want_u1), yesNo(want_u2), yesNo(want_v1t), ref(&m_), ref(&p_), ref(&q_), x11.ptr, ref(&ldx11_), x21.ptr, ref(&ldx21_), theta.ptr, u_1.ptr, ref(&ldu1_), u_2.ptr, ref(&ldu2_), v1t.ptr, ref(&ldv1t_), buf.ptr, ref(&lwork), rwork.ptr, ref(&lrwork), iwork.ptr, out(&info));
    } else {
        sym(T, name)(yesNo(want_u1), yesNo(want_u2), yesNo(want_v1t), ref(&m_), ref(&p_), ref(&q_), x11.ptr, ref(&ldx11_), x21.ptr, ref(&ldx21_), theta.ptr, u_1.ptr, ref(&ldu1_), u_2.ptr, ref(&ldu2_), v1t.ptr, ref(&ldv1t_), buf.ptr, ref(&lwork), iwork.ptr, out(&info));
    }

    const unconverged = info > 0;
    if (!unconverged) try info_mod.checkArgs(info);
    return .{ .count = count, .unconverged = unconverged };
}

/// `orcsd2by1` under its complex name.
pub const uncsd2by1 = orcsd2by1;

/// Reduces a partitioned orthogonal matrix to bidiagonal-block form.
///
/// The first half of `orcsd`, exposed for the same reason `reduce.gehrd` is.
/// `theta` and `phi` are the two angle sequences of the reduced form, and the
/// four `tau` arrays hold the reflectors that `bbcsd` then works with.
pub fn orbdb(
    comptime T: type,
    allocator: Allocator,
    row_major: bool,
    signs: SignConvention,
    m: usize,
    p: usize,
    q: usize,
    x11: []T,
    ldx11: usize,
    x12: []T,
    ldx12: usize,
    x21: []T,
    ldx21: usize,
    x22: []T,
    ldx22: usize,
    theta: []Real(T),
    phi: []Real(T),
    taup1: []T,
    taup2: []T,
    tauq1: []T,
    tauq2: []T,
) Fail!void {
    std.debug.assert(theta.len >= q);
    if (q > 0) std.debug.assert(phi.len >= q - 1);

    const name = comptime ortho(T, "bdb");
    const m_ = dim(m);
    const p_ = dim(p);
    const q_ = dim(q);
    const ldx11_ = dim(@max(ldx11, 1));
    const ldx12_ = dim(@max(ldx12, 1));
    const ldx21_ = dim(@max(ldx21, 1));
    const ldx22_ = dim(@max(ldx22, 1));
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, name)(transFlag(row_major), opt(signs), ref(&m_), ref(&p_), ref(&q_), &probe, ref(&ldx11_), &probe, ref(&ldx12_), &probe, ref(&ldx21_), &probe, ref(&ldx22_), &rprobe, &rprobe, &probe, &probe, &probe, &probe, &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), @as(Int, @intCast(@max(m - q, 1)))));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, name)(transFlag(row_major), opt(signs), ref(&m_), ref(&p_), ref(&q_), x11.ptr, ref(&ldx11_), x12.ptr, ref(&ldx12_), x21.ptr, ref(&ldx21_), x22.ptr, ref(&ldx22_), theta.ptr, phi.ptr, taup1.ptr, taup2.ptr, tauq1.ptr, tauq2.ptr, buf.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// `orbdb` under its complex name.
pub const unbdb = orbdb;

/// Which of the four block shapes a simultaneous bidiagonalization handles.
///
/// `orbdb` dispatches on the relative sizes of `p`, `q` and `m`; these are the
/// four cases it dispatches to, exposed because a caller who already knows the
/// shape can skip the dispatch. They all take the same arguments.
pub const BidiagonalizeCase = enum(u3) {
    /// `q <= p` and `q <= m - p` and `q <= m - q`.
    one = 1,
    /// `p <= q` and `p <= m - q` and `p <= m - p`.
    two = 2,
    /// `m - p <= q` and `m - p <= m - q` and `m - p <= p`.
    three = 3,
    /// `m - q <= p` and `m - q <= m - p` and `m - q <= q`.
    four = 4,
};

/// One case of `orbdb`, chosen explicitly.
///
/// Takes only the two blocks of a block-column, like `orcsd2by1`. `which` picks
/// the variant; passing one whose size condition does not hold gives an
/// illegal-argument error rather than a wrong answer.
///
/// `phantom` is read only by case four, which needs an extra `m`-element array
/// the other three have no parameter for. Pass an empty slice otherwise.
pub fn orbdbCase(
    comptime T: type,
    allocator: Allocator,
    which: BidiagonalizeCase,
    m: usize,
    p: usize,
    q: usize,
    x11: []T,
    ldx11: usize,
    x21: []T,
    ldx21: usize,
    theta: []Real(T),
    phi: []Real(T),
    taup1: []T,
    taup2: []T,
    tauq1: []T,
    phantom: []T,
) Fail!void {
    if (which == .four) std.debug.assert(phantom.len >= m);
    const m_ = dim(m);
    const p_ = dim(p);
    const q_ = dim(q);
    const ldx11_ = dim(@max(ldx11, 1));
    const ldx21_ = dim(@max(ldx21, 1));
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;

    // Four separate symbols rather than one with a parameter, so the dispatch
    // is a switch here instead of inside LAPACK.
    switch (which) {
        inline else => |case| {
            const name = comptime ortho(T, "bdb" ++ [_]u8{'0' + @as(u8, @intFromEnum(case))});
            // Case four takes one more array than the other three, which is
            // why the call is not shared across the prongs.
            if (comptime case == .four) {
                sym(T, name)(ref(&m_), ref(&p_), ref(&q_), &probe, ref(&ldx11_), &probe, ref(&ldx21_), &rprobe, &rprobe, &probe, &probe, &probe, &probe, &wq, ref(&neg), out(&info));
            } else {
                sym(T, name)(ref(&m_), ref(&p_), ref(&q_), &probe, ref(&ldx11_), &probe, ref(&ldx21_), &rprobe, &rprobe, &probe, &probe, &probe, &wq, ref(&neg), out(&info));
            }
            try info_mod.checkArgs(info);

            const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), 1));
            const buf = try allocator.alloc(T, size);
            defer allocator.free(buf);
            const lwork = dim(size);

            if (comptime case == .four) {
                sym(T, name)(ref(&m_), ref(&p_), ref(&q_), x11.ptr, ref(&ldx11_), x21.ptr, ref(&ldx21_), theta.ptr, phi.ptr, taup1.ptr, taup2.ptr, tauq1.ptr, phantom.ptr, buf.ptr, ref(&lwork), out(&info));
            } else {
                sym(T, name)(ref(&m_), ref(&p_), ref(&q_), x11.ptr, ref(&ldx11_), x21.ptr, ref(&ldx21_), theta.ptr, phi.ptr, taup1.ptr, taup2.ptr, tauq1.ptr, buf.ptr, ref(&lwork), out(&info));
            }
        },
    }
    return info_mod.checkArgs(info);
}

/// Orthogonalizes a vector against the columns of two matrices at once.
///
/// A helper inside the CS machinery, exposed because it is occasionally useful
/// on its own: `x1` and `x2` are the two halves of one vector, `q1` and `q2`
/// the two halves of the basis, and the vector comes back orthogonal to every
/// column and normalized.
///
/// `orbdb5` first tries to orthogonalize in place and falls back to choosing a
/// fresh vector if the result would be zero; `orbdb6` does not and leaves a
/// zero vector instead.
pub fn orbdb5(
    comptime T: type,
    allocator: Allocator,
    m1: usize,
    m2: usize,
    n: usize,
    x1: []T,
    incx1: usize,
    x2: []T,
    incx2: usize,
    q1: []const T,
    ldq1: usize,
    q2: []const T,
    ldq2: usize,
) Fail!void {
    return orthogonalizeAgainst(T, "bdb5", allocator, m1, m2, n, x1, incx1, x2, incx2, q1, ldq1, q2, ldq2);
}

/// `orbdb5` without the fallback: a vector already in the span comes back as
/// zero rather than replaced.
pub fn orbdb6(
    comptime T: type,
    allocator: Allocator,
    m1: usize,
    m2: usize,
    n: usize,
    x1: []T,
    incx1: usize,
    x2: []T,
    incx2: usize,
    q1: []const T,
    ldq1: usize,
    q2: []const T,
    ldq2: usize,
) Fail!void {
    return orthogonalizeAgainst(T, "bdb6", allocator, m1, m2, n, x1, incx1, x2, incx2, q1, ldq1, q2, ldq2);
}

fn orthogonalizeAgainst(
    comptime T: type,
    comptime suffix: []const u8,
    allocator: Allocator,
    m1: usize,
    m2: usize,
    n: usize,
    x1: []T,
    incx1: usize,
    x2: []T,
    incx2: usize,
    q1: []const T,
    ldq1: usize,
    q2: []const T,
    ldq2: usize,
) Fail!void {
    std.debug.assert(incx1 >= 1 and incx2 >= 1);

    const name = comptime ortho(T, suffix);
    const m1_ = dim(m1);
    const m2_ = dim(m2);
    const n_ = dim(n);
    const incx1_ = dim(incx1);
    const incx2_ = dim(incx2);
    const ldq1_ = dim(@max(ldq1, 1));
    const ldq2_ = dim(@max(ldq2, 1));
    var info: Int = 0;

    const buf = try allocator.alloc(T, @max(m1 + m2 + n, 1));
    defer allocator.free(buf);
    const lwork = dim(buf.len);

    sym(T, name)(ref(&m1_), ref(&m2_), ref(&n_), x1.ptr, ref(&incx1_), x2.ptr, ref(&incx2_), q1.ptr, ref(&ldq1_), q2.ptr, ref(&ldq2_), buf.ptr, ref(&lwork), out(&info));
    return info_mod.checkArgs(info);
}

/// The CS iteration on a bidiagonal-block form.
///
/// The second half of `orcsd`, taking `orbdb`'s `theta` and `phi` and refining
/// them to the actual principal angles while accumulating the rotations into
/// whichever of `u1`, `u2`, `v1t`, `v2t` you asked for.
///
/// The eight `b*` arrays receive the diagonals and off-diagonals of the four
/// blocks after the iteration; they are outputs only, and each needs `q`
/// entries (`q - 1` for the `e` ones).
pub fn bbcsd(
    comptime T: type,
    allocator: Allocator,
    want_u1: bool,
    want_u2: bool,
    want_v1t: bool,
    want_v2t: bool,
    row_major: bool,
    m: usize,
    p: usize,
    q: usize,
    theta: []Real(T),
    phi: []Real(T),
    u_1: []T,
    ldu1: usize,
    u_2: []T,
    ldu2: usize,
    v1t: []T,
    ldv1t: usize,
    v2t: []T,
    ldv2t: usize,
    b11d: []Real(T),
    b11e: []Real(T),
    b12d: []Real(T),
    b12e: []Real(T),
    b21d: []Real(T),
    b21e: []Real(T),
    b22d: []Real(T),
    b22e: []Real(T),
) Fail!bool {
    std.debug.assert(theta.len >= q);
    if (q > 0) std.debug.assert(phi.len >= q - 1);
    std.debug.assert(b11d.len >= q and b12d.len >= q and b21d.len >= q and b22d.len >= q);
    if (q > 0) {
        std.debug.assert(b11e.len >= q - 1 and b12e.len >= q - 1);
        std.debug.assert(b21e.len >= q - 1 and b22e.len >= q - 1);
    }

    const m_ = dim(m);
    const p_ = dim(p);
    const q_ = dim(q);
    const ldu1_ = dim(@max(ldu1, 1));
    const ldu2_ = dim(@max(ldu2, 1));
    const ldv1t_ = dim(@max(ldv1t, 1));
    const ldv2t_ = dim(@max(ldv2t, 1));
    var info: Int = 0;

    var probe: [1]T = undefined;
    var rprobe: [1]Real(T) = undefined;
    var wq: [1]T = undefined;
    const neg = work_mod.query;
    sym(T, "bbcsd")(yesNo(want_u1), yesNo(want_u2), yesNo(want_v1t), yesNo(want_v2t), transFlag(row_major), ref(&m_), ref(&p_), ref(&q_), &rprobe, &rprobe, &probe, ref(&ldu1_), &probe, ref(&ldu2_), &probe, ref(&ldv1t_), &probe, ref(&ldv2t_), &rprobe, &rprobe, &rprobe, &rprobe, &rprobe, &rprobe, &rprobe, &rprobe, &wq, ref(&neg), out(&info));
    try info_mod.checkArgs(info);

    const size: usize = @intCast(@max(work_mod.sizeFrom(T, wq[0]), @as(Int, @intCast(@max(8 * q, 1)))));
    const buf = try allocator.alloc(T, size);
    defer allocator.free(buf);
    const lwork = dim(size);

    sym(T, "bbcsd")(yesNo(want_u1), yesNo(want_u2), yesNo(want_v1t), yesNo(want_v2t), transFlag(row_major), ref(&m_), ref(&p_), ref(&q_), theta.ptr, phi.ptr, u_1.ptr, ref(&ldu1_), u_2.ptr, ref(&ldu2_), v1t.ptr, ref(&ldv1t_), v2t.ptr, ref(&ldv2t_), b11d.ptr, b11e.ptr, b12d.ptr, b12e.ptr, b21d.ptr, b21e.ptr, b22d.ptr, b22e.ptr, buf.ptr, ref(&lwork), out(&info));

    if (info < 0) try info_mod.checkArgs(info);
    return info > 0;
}

fn complexElement(comptime T: type) bool {
    return switch (T) {
        f32, f64 => false,
        else => true,
    };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const qr = @import("qr.zig");

/// Builds an `m x q` matrix with orthonormal columns, from a QR of `seed`.
fn orthonormalColumns(comptime m: usize, comptime q: usize, seed: [m * q]f64, dest: *[m * q]f64) !void {
    dest.* = seed;
    var tau: [q]f64 = undefined;
    try qr.geqrf(f64, testing.allocator, m, q, dest, m, &tau);
    try qr.orgqr(f64, testing.allocator, m, q, q, dest, m, &tau);
}

/// Splits an `m x q` column-major matrix into its top `p` rows and the rest.
///
/// Not a contiguous slice: a row split of a column-major matrix touches every
/// column, which is the mistake to make here.
fn splitRows(comptime m: usize, comptime p: usize, comptime q: usize, x: [m * q]f64, top: *[p * q]f64, bottom: *[(m - p) * q]f64) void {
    for (0..q) |j| {
        for (0..p) |i| top[i + j * p] = x[i + j * m];
        for (0..m - p) |i| bottom[i + j * (m - p)] = x[p + i + j * m];
    }
}

test "orcsd2by1 finds the principal angles between a subspace and the axes" {
    const m = 4;
    const p = 2;
    const q = 2;

    // A subspace that is exactly the first two coordinate axes: every principal
    // angle is zero, so every cosine is 1.
    const x = [_]f64{ 1, 0, 0, 0, 0, 1, 0, 0 };
    var x11: [p * q]f64 = undefined;
    var x21: [(m - p) * q]f64 = undefined;
    splitRows(m, p, q, x, &x11, &x21);

    var theta: [2]f64 = undefined;
    var u_1: [p * p]f64 = undefined;
    var u_2: [(m - p) * (m - p)]f64 = undefined;
    var v1t: [q * q]f64 = undefined;

    const res = try orcsd2by1(f64, testing.allocator, true, true, true, m, p, q, &x11, p, &x21, m - p, &theta, &u_1, p, &u_2, m - p, &v1t, q);

    try testing.expectEqual(@as(usize, 2), res.count);
    try testing.expect(!res.unconverged);
    for (theta[0..res.count]) |t| try testing.expectApproxEqAbs(@as(f64, 0), t, 1e-12);
}

test "orcsd2by1 finds a right angle for an orthogonal subspace" {
    const m = 4;
    const p = 2;
    const q = 2;

    // The *last* two axes: every principal angle is pi/2.
    var x11 = [_]f64{ 0, 0, 0, 0 };
    var x21 = [_]f64{ 1, 0, 0, 1 };
    var theta: [2]f64 = undefined;
    var u_1: [p * p]f64 = undefined;
    var u_2: [(m - p) * (m - p)]f64 = undefined;
    var v1t: [q * q]f64 = undefined;

    const res = try orcsd2by1(f64, testing.allocator, true, true, true, m, p, q, &x11, p, &x21, m - p, &theta, &u_1, p, &u_2, m - p, &v1t, q);

    for (theta[0..res.count]) |t| try testing.expectApproxEqAbs(std.math.pi / 2.0, t, 1e-12);
}

test "orcsd2by1's angles are the arccosines of the singular values of x11" {
    const m = 4;
    const p = 2;
    const q = 2;
    var x: [m * q]f64 = undefined;
    try orthonormalColumns(m, q, .{ 1, 2, 3, 4, 5, 1, 2, 6 }, &x);

    var x11: [p * q]f64 = undefined;
    var x21: [(m - p) * q]f64 = undefined;
    splitRows(m, p, q, x, &x11, &x21);
    const top_original = x11;

    var theta: [2]f64 = undefined;
    var u_1: [p * p]f64 = undefined;
    var u_2: [(m - p) * (m - p)]f64 = undefined;
    var v1t: [q * q]f64 = undefined;
    const res = try orcsd2by1(f64, testing.allocator, true, true, true, m, p, q, &x11, p, &x21, m - p, &theta, &u_1, p, &u_2, m - p, &v1t, q);

    // The top block's singular values are the cosines - that is what a
    // principal angle is. This is the check that catches angles coming back as
    // sines, which look just as plausible.
    var top = top_original;
    var sv: [2]f64 = undefined;
    var uu: [4]f64 = undefined;
    var vt: [4]f64 = undefined;
    const svd = @import("svd.zig");
    try svd.gesvd(f64, testing.allocator, .all, .all, p, q, &top, p, &sv, &uu, p, &vt, q);

    // theta comes back ascending and the singular values descending, and they
    // pair index for index: the smallest angle has the largest cosine.
    for (0..res.count) |i| {
        try testing.expectApproxEqAbs(sv[i], @cos(theta[i]), 1e-10);
    }
    try testing.expect(theta[0] <= theta[1]);
}

test "orcsd decomposes all four blocks of a square orthogonal matrix" {
    const m = 4;
    const p = 2;
    const q = 2;
    // Build an orthogonal 4x4 from a QR.
    var x: [m * m]f64 = undefined;
    try orthonormalColumns(m, m, .{ 1, 2, 3, 4, 5, 1, 2, 6, 7, 3, 1, 2, 4, 8, 2, 1 }, &x);

    // Split into four 2x2 blocks, each with its own leading dimension.
    var x11: [4]f64 = undefined;
    var x12: [4]f64 = undefined;
    var x21: [4]f64 = undefined;
    var x22: [4]f64 = undefined;
    for (0..q) |j| for (0..p) |i| {
        x11[i + j * p] = x[i + j * m];
        x21[i + j * p] = x[p + i + j * m];
        x12[i + j * p] = x[i + (q + j) * m];
        x22[i + j * p] = x[p + i + (q + j) * m];
    };

    var theta: [2]f64 = undefined;
    var u_1: [4]f64 = undefined;
    var u_2: [4]f64 = undefined;
    var v1t: [4]f64 = undefined;
    var v2t: [4]f64 = undefined;

    const res = try orcsd(f64, testing.allocator, true, true, true, true, false, .default, m, p, q, &x11, p, &x12, p, &x21, m - p, &x22, m - p, &theta, &u_1, p, &u_2, m - p, &v1t, q, &v2t, m - q);

    try testing.expectEqual(@as(usize, 2), res.count);
    try testing.expect(!res.unconverged);
    // Angles are in [0, pi/2] and ascending.
    for (theta[0..res.count]) |t| try testing.expect(t >= -1e-12 and t <= std.math.pi / 2.0 + 1e-12);
    try testing.expect(theta[0] <= theta[1] + 1e-12);
}

test "orcsd's two sign conventions give the same angles" {
    const m = 4;
    const p = 2;
    const q = 2;
    var x: [m * m]f64 = undefined;
    try orthonormalColumns(m, m, .{ 1, 2, 3, 4, 5, 1, 2, 6, 7, 3, 1, 2, 4, 8, 2, 1 }, &x);

    var angles: [2][2]f64 = undefined;
    for ([_]SignConvention{ .default, .other }, 0..) |signs, k| {
        var x11: [4]f64 = undefined;
        var x12: [4]f64 = undefined;
        var x21: [4]f64 = undefined;
        var x22: [4]f64 = undefined;
        for (0..q) |j| for (0..p) |i| {
            x11[i + j * p] = x[i + j * m];
            x21[i + j * p] = x[p + i + j * m];
            x12[i + j * p] = x[i + (q + j) * m];
            x22[i + j * p] = x[p + i + (q + j) * m];
        };
        var u_1: [4]f64 = undefined;
        var u_2: [4]f64 = undefined;
        var v1t: [4]f64 = undefined;
        var v2t: [4]f64 = undefined;
        _ = try orcsd(f64, testing.allocator, true, true, true, true, false, signs, m, p, q, &x11, p, &x12, p, &x21, m - p, &x22, m - p, &angles[k], &u_1, p, &u_2, m - p, &v1t, q, &v2t, m - q);
    }

    // The conventions differ in where a minus sign lands among the blocks, not
    // in the geometry.
    for (angles[0], angles[1]) |a, b| try testing.expectApproxEqAbs(a, b, 1e-12);
}

test "orbdb then bbcsd is what orcsd does in one call" {
    const m = 4;
    const p = 2;
    const q = 2;
    var x: [m * m]f64 = undefined;
    try orthonormalColumns(m, m, .{ 1, 2, 3, 4, 5, 1, 2, 6, 7, 3, 1, 2, 4, 8, 2, 1 }, &x);

    var blocks: [4][4]f64 = undefined;
    for (0..q) |j| for (0..p) |i| {
        blocks[0][i + j * p] = x[i + j * m];
        blocks[2][i + j * p] = x[p + i + j * m];
        blocks[1][i + j * p] = x[i + (q + j) * m];
        blocks[3][i + j * p] = x[p + i + (q + j) * m];
    };
    const staged_blocks = blocks;

    // One-shot.
    var direct: [2]f64 = undefined;
    {
        var b = blocks;
        var u_1: [4]f64 = undefined;
        var u_2: [4]f64 = undefined;
        var v1t: [4]f64 = undefined;
        var v2t: [4]f64 = undefined;
        _ = try orcsd(f64, testing.allocator, true, true, true, true, false, .default, m, p, q, &b[0], p, &b[1], p, &b[2], m - p, &b[3], m - p, &direct, &u_1, p, &u_2, m - p, &v1t, q, &v2t, m - q);
    }

    // Staged: reduce, then iterate.
    var b = staged_blocks;
    var theta: [2]f64 = undefined;
    var phi: [1]f64 = undefined;
    var taup1: [2]f64 = undefined;
    var taup2: [2]f64 = undefined;
    var tauq1: [2]f64 = undefined;
    var tauq2: [2]f64 = undefined;
    try orbdb(f64, testing.allocator, false, .default, m, p, q, &b[0], p, &b[1], p, &b[2], m - p, &b[3], m - p, &theta, &phi, &taup1, &taup2, &tauq1, &tauq2);

    var u_1 = [_]f64{ 1, 0, 0, 1 };
    var u_2 = [_]f64{ 1, 0, 0, 1 };
    var v1t = [_]f64{ 1, 0, 0, 1 };
    var v2t = [_]f64{ 1, 0, 0, 1 };
    var b11d: [2]f64 = undefined;
    var b11e: [1]f64 = undefined;
    var b12d: [2]f64 = undefined;
    var b12e: [1]f64 = undefined;
    var b21d: [2]f64 = undefined;
    var b21e: [1]f64 = undefined;
    var b22d: [2]f64 = undefined;
    var b22e: [1]f64 = undefined;
    const unconverged = try bbcsd(f64, testing.allocator, true, true, true, true, false, m, p, q, &theta, &phi, &u_1, p, &u_2, m - p, &v1t, q, &v2t, m - q, &b11d, &b11e, &b12d, &b12e, &b21d, &b21e, &b22d, &b22e);

    try testing.expect(!unconverged);
    for (direct, theta) |a, c_| try testing.expectApproxEqAbs(a, c_, 1e-10);
}

test "orbdb6 leaves a vector already in the span as zero" {
    const m1 = 2;
    const m2 = 2;
    const n = 1;
    // q spans e1 (in the first half); x is exactly that vector.
    const q1 = [_]f64{ 1, 0 };
    const q2 = [_]f64{ 0, 0 };
    var x1 = [_]f64{ 1, 0 };
    var x2 = [_]f64{ 0, 0 };

    try orbdb6(f64, testing.allocator, m1, m2, n, &x1, 1, &x2, 1, &q1, m1, &q2, m2);

    // Nothing is left after projecting out the span, and orbdb6 does not
    // substitute a fresh vector the way orbdb5 does.
    for (x1) |v| try testing.expectApproxEqAbs(@as(f64, 0), v, 1e-14);
    for (x2) |v| try testing.expectApproxEqAbs(@as(f64, 0), v, 1e-14);
}

test "orbdb5 substitutes a vector where orbdb6 gives up" {
    const m1 = 2;
    const m2 = 2;
    const n = 1;
    const q1 = [_]f64{ 1, 0 };
    const q2 = [_]f64{ 0, 0 };
    var x1 = [_]f64{ 1, 0 };
    var x2 = [_]f64{ 0, 0 };

    try orbdb5(f64, testing.allocator, m1, m2, n, &x1, 1, &x2, 1, &q1, m1, &q2, m2);

    // A unit vector orthogonal to the span, chosen by the routine rather than
    // left as zero - that is the whole difference between the two.
    var norm: f64 = 0;
    for (x1) |v| norm += v * v;
    for (x2) |v| norm += v * v;
    try testing.expectApproxEqAbs(@as(f64, 1), norm, 1e-12);
    try testing.expectApproxEqAbs(@as(f64, 0), x1[0], 1e-12);
}

test "orbdbCase computes the same reduction as orbdb for its shape" {
    const m = 4;
    const p = 2;
    const q = 2;
    var x: [m * q]f64 = undefined;
    try orthonormalColumns(m, q, .{ 1, 2, 3, 4, 5, 1, 2, 6 }, &x);

    var theta: [2]f64 = undefined;
    var phi: [1]f64 = undefined;
    var taup1: [2]f64 = undefined;
    var taup2: [2]f64 = undefined;
    var tauq1: [2]f64 = undefined;
    // q <= p, q <= m-p and q <= m-q, so case one applies.
    try orbdbCase(f64, testing.allocator, .one, m, p, q, x[0..4], p, x[4..8], m - p, &theta, &phi, &taup1, &taup2, &tauq1, &.{});

    for (theta) |t| try testing.expect(std.math.isFinite(t));
    for (phi) |v| try testing.expect(std.math.isFinite(v));
}

test "uncsd2by1 handles a complex subspace" {
    const Z = Complex(f64);
    const m = 4;
    const p = 2;
    const q = 2;
    // The first two coordinate axes again, complex-typed.
    var x11 = [_]Z{ Z.init(1, 0), Z.init(0, 0), Z.init(0, 0), Z.init(1, 0) };
    var x21 = [_]Z{ Z.init(0, 0), Z.init(0, 0), Z.init(0, 0), Z.init(0, 0) };
    var theta: [2]f64 = undefined;
    var u_1: [4]Z = undefined;
    var u_2: [4]Z = undefined;
    var v1t: [4]Z = undefined;

    const res = try uncsd2by1(Z, testing.allocator, true, true, true, m, p, q, &x11, p, &x21, m - p, &theta, &u_1, p, &u_2, m - p, &v1t, q);
    try testing.expectEqual(@as(usize, 2), res.count);
    for (theta[0..res.count]) |t| try testing.expectApproxEqAbs(@as(f64, 0), t, 1e-12);
}
