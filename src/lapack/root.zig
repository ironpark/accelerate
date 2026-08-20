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
//! Wrapped so far:
//!
//! - `linear.zig` - the simple drivers `gesv`, `gbsv`, `gtsv`, `posv`, `ppsv`,
//!   `pbsv`, `ptsv`, `sysv`, `spsv`, `hesv`, `hpsv`, plus the mixed-precision
//!   iterative-refinement pair.
//! - `factor.zig` - the computational routines behind them: LU, Cholesky,
//!   Bunch-Kaufman and triangular solves, inverses, condition estimates and
//!   equilibration, in full, packed and band storage.
//! - `qr.zig` - the QR/LQ/QL/RQ factorizations, forming and applying `Q`,
//!   column-pivoted QR, and the four least squares drivers.
//! - `eigen.zig` - the symmetric/Hermitian eigenvalue drivers, dense, packed,
//!   band, tridiagonal and generalized.
//! - `eigen_gen.zig` - the nonsymmetric and generalized eigenproblems:
//!   `geev`, `gees`, `ggev`, and the Sylvester solver `trsyl`.
//! - `svd.zig` - `gesvd` and `gesdd`.
//! - `norms.zig` - the `lan*` matrix norms, `lacpy` and `laset`.
//! - `util.zig` - machine parameters, random matrices, plane rotations,
//!   overflow-safe scaling, and the complex-symmetric routines CBLAS lacks.
//! - `refine.zig` - iterative refinement and the forward/backward error bounds
//!   that say how much of a computed solution to believe, for every storage
//!   form.
//! - `expert.zig` - the expert drivers, which equilibrate, factor, solve,
//!   estimate the condition number and bound the error in one call, again for
//!   every storage form.
//! - `reduce.zig` - the reductions to condensed form (`sytrd`, `gehrd`,
//!   `gebrd`, `gbbrd`), the routines that build or apply their orthogonal
//!   factors, and balancing.
//! - `tridiag.zig` - the symmetric tridiagonal eigensolvers that run on what
//!   `reduce.zig` produces: `sterf`, `steqr`, `pteqr`, `stedc`, `stemr` and the
//!   `stebz`/`stein` bisection pair.
//!
//! Not yet wrapped: the `_aa`/`_rk`/`_rook`/`_2stage` factorization variants,
//! RFP storage, the expert eigenvalue drivers (`geevx`, `geesx`, `ggevx`, `ggesx`), the
//! generalized Schur family (`gges`, `hgeqz`, `tgsen`, ...), the CS
//! decomposition, the tall-skinny QR family, and the remaining SVD drivers
//! (`gesvdx`, `gejsv`, `gesvdq`).
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
pub const norms = @import("norms.zig");
pub const factor = @import("factor.zig");
pub const qr = @import("qr.zig");
pub const eigen = @import("eigen.zig");
pub const svd = @import("svd.zig");
pub const eigen_gen = @import("eigen_gen.zig");
pub const util = @import("util.zig");
pub const refine = @import("refine.zig");
pub const expert = @import("expert.zig");
pub const reduce = @import("reduce.zig");
pub const tridiag = @import("tridiag.zig");

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

pub const getrf = factor.getrf;
pub const getrs = factor.getrs;
pub const getri = factor.getri;
pub const gecon = factor.gecon;
pub const potrf = factor.potrf;
pub const potrs = factor.potrs;
pub const potri = factor.potri;
pub const pocon = factor.pocon;
pub const sytrf = factor.sytrf;
pub const sytrs = factor.sytrs;
pub const hetrf = factor.hetrf;
pub const hetrs = factor.hetrs;
pub const trtrs = factor.trtrs;
pub const trtri = factor.trtri;
pub const trcon = factor.trcon;
pub const gbcon = factor.gbcon;
pub const gtcon = factor.gtcon;
pub const pbcon = factor.pbcon;
pub const ppcon = factor.ppcon;
pub const ptcon = factor.ptcon;
pub const spcon = factor.spcon;
pub const hpcon = factor.hpcon;
pub const tbcon = factor.tbcon;
pub const tpcon = factor.tpcon;
pub const geequ = factor.geequ;
pub const geequb = factor.geequb;
pub const gbequ = factor.gbequ;
pub const gbequb = factor.gbequb;
pub const poequ = factor.poequ;
pub const poequb = factor.poequb;
pub const pbequ = factor.pbequ;
pub const ppequ = factor.ppequ;
pub const syequb = factor.syequb;
pub const heequb = factor.heequb;
pub const Equilibration = factor.Equilibration;
pub const SymmetricEquilibration = factor.SymmetricEquilibration;

pub const geqrf = qr.geqrf;
pub const gelqf = qr.gelqf;
pub const geqp3 = qr.geqp3;
pub const orgqr = qr.orgqr;
pub const ungqr = qr.ungqr;
pub const ormqr = qr.ormqr;
pub const unmqr = qr.unmqr;
pub const orglq = qr.orglq;
pub const ormlq = qr.ormlq;
pub const gels = qr.gels;
pub const gelsd = qr.gelsd;
pub const gelss = qr.gelss;
pub const gelsy = qr.gelsy;
pub const QTrans = qr.QTrans;

pub const syev = eigen.syev;
pub const heev = eigen.heev;
pub const syevd = eigen.syevd;
pub const heevd = eigen.heevd;
pub const syevr = eigen.syevr;
pub const heevr = eigen.heevr;
pub const spev = eigen.spev;
pub const hpev = eigen.hpev;
pub const sbev = eigen.sbev;
pub const hbev = eigen.hbev;
pub const stev = eigen.stev;
pub const sygv = eigen.sygv;
pub const hegv = eigen.hegv;
pub const Selection = eigen.Selection;
pub const GeneralizedKind = eigen.GeneralizedKind;

pub const gesvd = svd.gesvd;
pub const gesdd = svd.gesdd;

pub const geev = eigen_gen.geev;
pub const gees = eigen_gen.gees;
pub const ggev = eigen_gen.ggev;
pub const trsyl = eigen_gen.trsyl;
pub const unpackVectors = eigen_gen.unpackVectors;
pub const Eigenvalue = eigen_gen.Eigenvalue;
pub const GeneralizedEigenvalue = eigen_gen.GeneralizedEigenvalue;
pub const SelectFn = eigen_gen.SelectFn;

pub const sytrd = reduce.sytrd;
pub const hetrd = reduce.hetrd;
pub const sptrd = reduce.sptrd;
pub const hptrd = reduce.hptrd;
pub const sbtrd = reduce.sbtrd;
pub const hbtrd = reduce.hbtrd;
pub const orgtr = reduce.orgtr;
pub const ungtr = reduce.ungtr;
pub const opgtr = reduce.opgtr;
pub const upgtr = reduce.upgtr;
pub const ormtr = reduce.ormtr;
pub const unmtr = reduce.unmtr;
pub const opmtr = reduce.opmtr;
pub const upmtr = reduce.upmtr;
pub const gehrd = reduce.gehrd;
pub const orghr = reduce.orghr;
pub const unghr = reduce.unghr;
pub const ormhr = reduce.ormhr;
pub const unmhr = reduce.unmhr;
pub const gebrd = reduce.gebrd;
pub const orgbr = reduce.orgbr;
pub const ungbr = reduce.ungbr;
pub const ormbr = reduce.ormbr;
pub const unmbr = reduce.unmbr;
pub const gbbrd = reduce.gbbrd;
pub const gebal = reduce.gebal;
pub const gebak = reduce.gebak;
pub const Window = reduce.Window;
pub const QUpdate = reduce.QUpdate;
pub const BidiagVect = reduce.BidiagVect;

pub const sterf = tridiag.sterf;
pub const steqr = tridiag.steqr;
pub const pteqr = tridiag.pteqr;
pub const stedc = tridiag.stedc;
pub const stemr = tridiag.stemr;
pub const stegr = tridiag.stegr;
pub const stebz = tridiag.stebz;
pub const stein = tridiag.stein;
pub const Compz = tridiag.Compz;
pub const EigenOrder = tridiag.EigenOrder;
pub const BisectionResult = tridiag.BisectionResult;

pub const lamch = util.lamch;
pub const ilaenv = util.ilaenv;
pub const larnv = util.larnv;
pub const lartg = util.lartg;
pub const lascl = util.lascl;
pub const lasrt = util.lasrt;
pub const lacgv = util.lacgv;
pub const ladiv = util.ladiv;
pub const rscl = util.rscl;

pub const gerfs = refine.gerfs;
pub const porfs = refine.porfs;
pub const syrfs = refine.syrfs;
pub const herfs = refine.herfs;
pub const trrfs = refine.trrfs;
pub const gbrfs = refine.gbrfs;
pub const gtrfs = refine.gtrfs;
pub const pbrfs = refine.pbrfs;
pub const pprfs = refine.pprfs;
pub const ptrfs = refine.ptrfs;
pub const sprfs = refine.sprfs;
pub const hprfs = refine.hprfs;
pub const tbrfs = refine.tbrfs;
pub const tprfs = refine.tprfs;

pub const gesvx = expert.gesvx;
pub const posvx = expert.posvx;
pub const sysvx = expert.sysvx;
pub const gbsvx = expert.gbsvx;
pub const gtsvx = expert.gtsvx;
pub const pbsvx = expert.pbsvx;
pub const ppsvx = expert.ppsvx;
pub const ptsvx = expert.ptsvx;
pub const spsvx = expert.spsvx;
pub const hpsvx = expert.hpsvx;
pub const hesvx = expert.hesvx;
pub const ExpertResult = expert.ExpertResult;
pub const MachineParam = util.MachineParam;
pub const Distribution = util.Distribution;
pub const Seed = util.Seed;

pub const lange = norms.lange;
pub const lansy = norms.lansy;
pub const lanhe = norms.lanhe;
pub const lantr = norms.lantr;
pub const lacpy = norms.lacpy;
pub const laset = norms.laset;

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
