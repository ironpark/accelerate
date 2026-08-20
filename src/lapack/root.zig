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
//!   column-pivoted QR, the four least squares drivers, and the constrained
//!   and generalized ones (`gglse`, `ggglm`, `ggqrf`, `ggrqf`).
//! - `qr_tall.zig` - the tall-skinny and blocked QR interfaces: `geqr`/`gemqr`,
//!   `geqrt`/`gemqrt`, the triangular-pentagonal family, `getsls`, `geqrfp`
//!   and the RZ factorization.
//! - `eigen.zig` - the symmetric/Hermitian eigenvalue drivers, dense, packed,
//!   band, tridiagonal and generalized, including the expert (`*evx`) and
//!   divide-and-conquer (`*evd`) variants.
//! - `eigen_gen.zig` - the nonsymmetric and generalized eigenproblems:
//!   `geev`, `gees`, `ggev`, their expert forms `geevx` and `geesx`, the Schur
//!   toolkit (`hseqr`, `hsein`, `trevc3`, `trexc`, `trsen`, `trsna`) and the
//!   Sylvester solvers `trsyl` and `trsyl3`.
//! - `svd.zig` - `gesvd`, `gesdd`, the bidiagonal solvers `bdsqr`, `bdsdc` and
//!   `bdsvdx`, the range-restricted `gesvdx`, and the high-accuracy Jacobi
//!   drivers `gesvj`, `gejsv` and `gesvdq`.
//! - `rfp.zig` - rectangular full packed storage: the four conversions, plus
//!   Cholesky, inversion, `trsm` and `syrk` operating on it directly.
//! - `cs.zig` - the CS decomposition (`orcsd`, `orcsd2by1`) and its two halves
//!   `orbdb` and `bbcsd`.
//! - `norms.zig` - the `lan*` matrix norms for every storage form, plus
//!   `lacpy` and `laset`.
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
//! - `qz.zig` - the generalized eigenproblem taken apart: `ggbal`, `gghd3`,
//!   `hgeqz`, `tgevc`, `tgexc`, `tgsen`, `tgsna`, `tgsyl`, the `gges`/`ggesx`
//!   drivers and the generalized SVD (`ggsvd3`, `tgsja`).
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
pub const qz = @import("qz.zig");
pub const qr_tall = @import("qr_tall.zig");
pub const rfp = @import("rfp.zig");
pub const cs = @import("cs.zig");

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
pub const sgesvIterative = linear.sgesvIterative;
pub const sposvIterative = linear.sposvIterative;
pub const cgesvIterative = linear.cgesvIterative;
pub const cposvIterative = linear.cposvIterative;

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
pub const pbstf = factor.pbstf;
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
pub const gglse = qr.gglse;
pub const ggglm = qr.ggglm;
pub const ggqrf = qr.ggqrf;
pub const ggrqf = qr.ggrqf;

pub const geqr = qr_tall.geqr;
pub const gemqr = qr_tall.gemqr;
pub const gelq = qr_tall.gelq;
pub const gemlq = qr_tall.gemlq;
pub const geqrt = qr_tall.geqrt;
pub const gemqrt = qr_tall.gemqrt;
pub const tpqrt = qr_tall.tpqrt;
pub const tpmqrt = qr_tall.tpmqrt;
pub const tplqt = qr_tall.tplqt;
pub const tpmlqt = qr_tall.tpmlqt;
pub const tprfb = qr_tall.tprfb;
pub const getsls = qr_tall.getsls;
pub const gelst = qr_tall.gelst;
pub const geqrfp = qr_tall.geqrfp;
pub const geqr2p = qr_tall.geqr2p;
pub const tzrzf = qr_tall.tzrzf;
pub const ormrz = qr_tall.ormrz;
pub const unmrz = qr_tall.unmrz;
pub const Direction = types.Direction;
pub const StoreV = types.StoreV;

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
pub const syevx = eigen.syevx;
pub const heevx = eigen.heevx;
pub const spevd = eigen.spevd;
pub const hpevd = eigen.hpevd;
pub const spevx = eigen.spevx;
pub const hpevx = eigen.hpevx;
pub const sbevd = eigen.sbevd;
pub const hbevd = eigen.hbevd;
pub const sbevx = eigen.sbevx;
pub const hbevx = eigen.hbevx;
pub const stevd = eigen.stevd;
pub const stevx = eigen.stevx;
pub const stevr = eigen.stevr;
pub const Selection = eigen.Selection;
pub const EigResult = eigen.EigResult;
pub const GeneralizedKind = eigen.GeneralizedKind;
pub const sygst = eigen.sygst;
pub const hegst = eigen.hegst;
pub const spgst = eigen.spgst;
pub const hpgst = eigen.hpgst;
pub const sbgst = eigen.sbgst;
pub const hbgst = eigen.hbgst;
pub const sygvd = eigen.sygvd;
pub const hegvd = eigen.hegvd;
pub const sygvx = eigen.sygvx;
pub const hegvx = eigen.hegvx;
pub const spgv = eigen.spgv;
pub const hpgv = eigen.hpgv;
pub const spgvd = eigen.spgvd;
pub const hpgvd = eigen.hpgvd;
pub const spgvx = eigen.spgvx;
pub const hpgvx = eigen.hpgvx;
pub const sbgv = eigen.sbgv;
pub const hbgv = eigen.hbgv;
pub const sbgvd = eigen.sbgvd;
pub const hbgvd = eigen.hbgvd;
pub const sbgvx = eigen.sbgvx;
pub const hbgvx = eigen.hbgvx;

pub const gesvd = svd.gesvd;
pub const gesdd = svd.gesdd;
pub const bdsqr = svd.bdsqr;
pub const bdsdc = svd.bdsdc;
pub const bdsvdx = svd.bdsvdx;
pub const gesvdx = svd.gesvdx;
pub const gesvj = svd.gesvj;
pub const gejsv = svd.gejsv;
pub const gesvdq = svd.gesvdq;
pub const SvdResult = svd.SvdResult;
pub const BidiagVectors = svd.BidiagVectors;
pub const JacobiStructure = svd.JacobiStructure;
pub const JacobiLeft = svd.JacobiLeft;
pub const JacobiRight = svd.JacobiRight;
pub const JsvAccuracy = svd.JsvAccuracy;
pub const JsvLeft = svd.JsvLeft;
pub const JsvRight = svd.JsvRight;
pub const SvdqAccuracy = svd.SvdqAccuracy;
pub const SvdqLeft = svd.SvdqLeft;
pub const SvdqRight = svd.SvdqRight;

pub const geev = eigen_gen.geev;
pub const gees = eigen_gen.gees;
pub const ggev = eigen_gen.ggev;
pub const trsyl = eigen_gen.trsyl;
pub const geevx = eigen_gen.geevx;
pub const geesx = eigen_gen.geesx;
pub const Sense = eigen_gen.Sense;
pub const ExpertEigenResult = eigen_gen.ExpertEigenResult;
pub const ExpertSchurResult = eigen_gen.ExpertSchurResult;
pub const hseqr = eigen_gen.hseqr;
pub const hsein = eigen_gen.hsein;
pub const trevc = eigen_gen.trevc;
pub const trevc3 = eigen_gen.trevc3;
pub const trexc = eigen_gen.trexc;
pub const trsen = eigen_gen.trsen;
pub const trsna = eigen_gen.trsna;
pub const trsyl3 = eigen_gen.trsyl3;
pub const SchurJob = eigen_gen.SchurJob;
pub const SchurVectors = eigen_gen.SchurVectors;
pub const HowMany = eigen_gen.HowMany;
pub const EigenSource = eigen_gen.EigenSource;
pub const InitialVectors = eigen_gen.InitialVectors;
pub const ReorderResult = eigen_gen.ReorderResult;
pub const ReorderedSchur = eigen_gen.ReorderedSchur;
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

pub const ggbal = qz.ggbal;
pub const ggbak = qz.ggbak;
pub const gghrd = qz.gghrd;
pub const gghd3 = qz.gghd3;
pub const hgeqz = qz.hgeqz;
pub const gges = qz.gges;
pub const gges3 = qz.gges3;
pub const ggesx = qz.ggesx;
pub const ggev3 = qz.ggev3;
pub const ggevx = qz.ggevx;
pub const tgevc = qz.tgevc;
pub const tgexc = qz.tgexc;
pub const tgsen = qz.tgsen;
pub const tgsna = qz.tgsna;
pub const tgsyl = qz.tgsyl;
pub const ggsvd3 = qz.ggsvd3;
pub const tgsja = qz.tgsja;
pub const TgsenJob = qz.TgsenJob;
pub const GsvdResult = qz.GsvdResult;
pub const GsvdVectors = qz.GsvdVectors;
pub const ExpertGeneralizedSchur = qz.ExpertGeneralizedSchur;
pub const ExpertGeneralizedEigen = qz.ExpertGeneralizedEigen;
pub const GeneralizedReorder = qz.GeneralizedReorder;
pub const GeneralizedSylvesterResult = qz.GeneralizedSylvesterResult;

pub const trttf = rfp.trttf;
pub const tfttr = rfp.tfttr;
pub const tpttf = rfp.tpttf;
pub const tfttp = rfp.tfttp;
pub const pftrf = rfp.pftrf;
pub const pftrs = rfp.pftrs;
pub const pftri = rfp.pftri;
pub const tftri = rfp.tftri;
pub const tfsm = rfp.tfsm;
pub const sfrk = rfp.sfrk;
pub const hfrk = rfp.hfrk;
pub const RfpLayout = rfp.RfpLayout;
pub const rfpLen = rfp.rfpLen;

pub const orcsd = cs.orcsd;
pub const uncsd = cs.uncsd;
pub const orcsd2by1 = cs.orcsd2by1;
pub const uncsd2by1 = cs.uncsd2by1;
pub const orbdb = cs.orbdb;
pub const unbdb = cs.unbdb;
pub const orbdbCase = cs.orbdbCase;
pub const orbdb5 = cs.orbdb5;
pub const orbdb6 = cs.orbdb6;
pub const bbcsd = cs.bbcsd;
pub const CsResult = cs.CsResult;
pub const SignConvention = cs.SignConvention;
pub const BidiagonalizeCase = cs.BidiagonalizeCase;

pub const lamch = util.lamch;
pub const ilaenv = util.ilaenv;
pub const larnv = util.larnv;
pub const lartg = util.lartg;
pub const lascl = util.lascl;
pub const lasrt = util.lasrt;
pub const lacgv = util.lacgv;
pub const ladiv = util.ladiv;
pub const rscl = util.rscl;
pub const disna = util.disna;
pub const csum1 = util.csum1;
pub const SeparationKind = util.SeparationKind;

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
pub const langb = norms.langb;
pub const langt = norms.langt;
pub const lanst = norms.lanst;
pub const lanht = norms.lanht;
pub const lanhs = norms.lanhs;
pub const lansb = norms.lansb;
pub const lanhb = norms.lanhb;
pub const lantb = norms.lantb;
pub const lansp = norms.lansp;
pub const lanhp = norms.lanhp;
pub const lantp = norms.lantp;
pub const lansf = norms.lansf;
pub const lanhf = norms.lanhf;

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
