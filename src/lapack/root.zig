//! LAPACK — dense linear algebra from Apple's Accelerate framework.
//!
//! Binds the `$NEWLAPACK[$ILP64]` symbol variants, not the `clapack.h` names
//! that have been `API_DEPRECATED` since macOS 13.3. See `types.zig`.
//!
//! ## Storage
//!
//! LAPACK is column-major, always. Unlike CBLAS there is no `Order` parameter
//! to choose with, so a row-major matrix has to be transposed before it gets
//! here. `A(i, j)` lives at `a[i + j * lda]`, and `lda >= max(1, rows)`.
//!
//! ## Status
//!
//! The full 2032-symbol extern surface is in `c.zig`, along with the shared
//! types, `info` translation and workspace sizing. Typed wrappers are being
//! added tier by tier - `docs/LAPACK-PLAN.md` is the checklist.
//!
//! Wrapped so far: the simple linear-system drivers in `linear.zig` (`gesv`,
//! `gbsv`, `gtsv`, `posv`, `ppsv`, `pbsv`, `ptsv`, `sysv`, `spsv`, `hesv`,
//! `hpsv`) and the mixed-precision iterative-refinement pair. The *expert*
//! drivers (`gesvx` and friends, which also equilibrate and estimate condition
//! numbers) are not wrapped yet.
//!
//! Until a routine has a wrapper it is reachable through `c`, with the caveats
//! documented there: every argument by pointer, no bounds checking, `info`
//! unread.

const std = @import("std");

pub const c = @import("c.zig");
pub const types = @import("types.zig");
pub const info = @import("info.zig");
pub const work = @import("work.zig");
pub const linear = @import("linear.zig");

pub const Int = types.Int;
pub const Bool = types.Bool;
pub const Complex = types.Complex;
pub const Real = types.Real;
pub const Error = info.Error;
pub const lastInfo = info.lastInfo;

pub const Uplo = types.Uplo;
pub const Trans = types.Trans;
pub const Diag = types.Diag;
pub const Side = types.Side;
pub const Norm = types.Norm;
pub const Job = types.Job;
pub const Range = types.Range;
pub const JobSvd = types.JobSvd;
pub const Equed = types.Equed;
pub const Fact = types.Fact;
pub const Sort = types.Sort;
pub const Balance = types.Balance;
pub const EigSide = types.EigSide;
pub const Vect = types.Vect;

pub const gesv = linear.gesv;
pub const gbsv = linear.gbsv;
pub const gtsv = linear.gtsv;
pub const posv = linear.posv;
pub const ppsv = linear.ppsv;
pub const pbsv = linear.pbsv;
pub const ptsv = linear.ptsv;
pub const sysv = linear.sysv;
pub const spsv = linear.spsv;
pub const hesv = linear.hesv;
pub const hpsv = linear.hpsv;

test {
    std.testing.refAllDecls(@This());
}

const ref = work.ref;
const out = work.out;

test "sgesv solves a 2x2 system" {
    // Column-major A = [[2, 1], [1, 3]], b = [3, 5]. Exact solution [0.8, 1.4].
    var a = [_]f32{ 2, 1, 1, 3 };
    var b = [_]f32{ 3, 5 };
    var ipiv: [2]Int = undefined;
    var inf: Int = 0;
    const n: Int = 2;
    const nrhs: Int = 1;

    c.sgesv(ref(&n), ref(&nrhs), &a, ref(&n), &ipiv, &b, ref(&n), out(&inf));

    try info.checkLu(inf);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), b[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 1.4), b[1], 1e-6);
}

test "a singular system reports the zero pivot rather than succeeding" {
    // Column-major [[1, 2], [2, 4]] - the second row is twice the first.
    var a = [_]f64{ 1, 2, 2, 4 };
    var b = [_]f64{ 1, 2 };
    var ipiv: [2]Int = undefined;
    var inf: Int = 0;
    const n: Int = 2;
    const nrhs: Int = 1;

    c.dgesv(ref(&n), ref(&nrhs), &a, ref(&n), &ipiv, &b, ref(&n), out(&inf));

    try std.testing.expectError(error.SingularMatrix, info.checkLu(inf));
    try std.testing.expectEqual(@as(Int, 2), info.lastInfo());
}

test "cladiv and zladiv return by value, contradicting the SDK header" {
    // `lapack.h` declares these as writing through a leading out-parameter.
    // They do not: the shipping symbol is a thunk that drops its first argument
    // and tail-calls an implementation returning the quotient in registers.
    //
    //     cladiv$NEWLAPACK$ILP64:
    //         mov  x0, x1
    //         mov  x1, x2
    //         b    <impl>
    //
    // All three pointers must still be passed - a two-argument call reads
    // whatever x2 happens to hold and crashes - but the result comes back as
    // the return value. If a future SDK ever fixes the header, this test fails
    // and `OVERRIDES` in tools/gen_lapack.py is what to revisit.
    //
    // (1 + 2i) / (3 + 4i) = (11 + 2i) / 25 = 0.44 + 0.08i
    var ignored = Complex(f32).zero;
    const x = Complex(f32).init(1, 2);
    const y = Complex(f32).init(3, 4);
    const q = c.cladiv(out(&ignored), ref(&x), ref(&y));

    try std.testing.expectApproxEqAbs(@as(f32, 0.44), q.re, 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.08), q.im, 1e-6);
    // The parameter the header calls `ret` is never written.
    try std.testing.expectEqual(@as(f32, 0), ignored.re);

    var ignored_d = Complex(f64).zero;
    const xd = Complex(f64).init(1, 2);
    const yd = Complex(f64).init(3, 4);
    const qd = c.zladiv(out(&ignored_d), ref(&xd), ref(&yd));
    try std.testing.expectApproxEqAbs(@as(f64, 0.44), qd.re, 1e-12);
    try std.testing.expectApproxEqAbs(@as(f64, 0.08), qd.im, 1e-12);
}

test "chla_transtype does write through its ret parameter" {
    // The only other routine in the header with a leading `ret`, and the reason
    // the cladiv finding is a two-routine bug rather than a general rule about
    // Apple's LAPACK. Pinned so the two cases stay distinguishable.
    var ch: [1]u8 = .{'?'};
    const trans: Int = 111; // BLAS_NO_TRANS
    c.chla_transtype(&ch, 1, ref(&trans));
    try std.testing.expectEqual(@as(u8, 'N'), ch[0]);
}

test "bwork is written with Int stride, not c_int stride" {
    // `sgees` writes one Fortran LOGICAL per eigenvalue into bwork. Under ILP64
    // that element is 8 bytes wide (see types.Bool), and getting it wrong is
    // invisible to every other test in the suite.
    //
    // Poisoning with -1 and checking only the tail would *not* prove anything:
    // three 4-byte writes and three 8-byte writes both leave bwork[3..] alone.
    // What discriminates is the value of the elements that were written. At
    // 8-byte stride each is cleanly 0 or 1; at 4-byte stride the second element
    // would be 0xffffffff_00000001 - poison in the high half - which the
    // "0 or 1" assertion below rejects.
    const n: Int = 3;
    var a = [_]f32{ 3, 0, 0, 0, 2, 0, 0, 0, 1 }; // diagonal, eigenvalues 3, 2, 1
    var wr: [3]f32 = undefined;
    var wi: [3]f32 = undefined;
    var vs: [9]f32 = undefined;
    var bwork = [_]Bool{ -1, -1, -1, -1, -1, -1 };
    var sdim: Int = 0;
    var inf: Int = 0;
    var work_buf: [64]f32 = undefined;
    const lwork: Int = 64;

    const S = struct {
        fn selectGreaterThanOne(re: [*]f32, im: [*]f32) callconv(.c) Bool {
            _ = im;
            return if (re[0] > 1.5) 1 else 0;
        }
    };

    c.sgees(
        types.opt(Job.vectors),
        types.opt(Sort.sorted),
        &S.selectGreaterThanOne,
        ref(&n),
        &a,
        ref(&n),
        out(&sdim),
        &wr,
        &wi,
        &vs,
        ref(&n),
        &work_buf,
        ref(&lwork),
        &bwork,
        out(&inf),
    );

    try info.checkConvergence(inf);
    // Two eigenvalues (3 and 2) exceed 1.5.
    try std.testing.expectEqual(@as(Int, 2), sdim);

    // Eigenvalues come back in the input order, so the predicate's answers are
    // true, true, false. Each must be a clean Fortran logical - no poison
    // surviving in any part of the element.
    try std.testing.expectEqual(@as(Bool, 1), bwork[0]);
    try std.testing.expectEqual(@as(Bool, 1), bwork[1]);
    try std.testing.expectEqual(@as(Bool, 0), bwork[2]);

    // And nothing past n was touched.
    try std.testing.expectEqual(@as(Bool, -1), bwork[3]);
    try std.testing.expectEqual(@as(Bool, -1), bwork[4]);
    try std.testing.expectEqual(@as(Bool, -1), bwork[5]);
}

test "sisnan returns a Fortran logical" {
    const nan: f32 = std.math.nan(f32);
    const one: f32 = 1;
    try std.testing.expect(types.isTrue(c.sisnan(ref(&nan))));
    try std.testing.expect(!types.isTrue(c.sisnan(ref(&one))));
}

test "ilaenv reports a blocking factor" {
    // Not a correctness check on the value - Apple is free to tune it - but it
    // confirms the precision-independent symbols link and that the character
    // arguments cross the boundary without a hidden length.
    const ispec: Int = 1;
    const n: Int = 100;
    const neg: Int = -1;
    const nb = c.ilaenv(ref(&ispec), "DGEQRF", " ", ref(&n), ref(&n), ref(&neg), ref(&neg));
    try std.testing.expect(nb > 0);
}

test "slange computes the Frobenius norm" {
    // Column-major [[1, 3], [2, 4]]; sqrt(1 + 4 + 9 + 16) = sqrt(30).
    var a = [_]f32{ 1, 2, 3, 4 };
    const n: Int = 2;
    var scratch: [2]f32 = undefined;
    const norm = c.slange(types.opt(Norm.frobenius), ref(&n), ref(&n), &a, ref(&n), &scratch);
    try std.testing.expectApproxEqAbs(@sqrt(@as(f32, 30)), norm, 1e-5);
}
