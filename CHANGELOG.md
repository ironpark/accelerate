# Changelog

## 0.4.0

An API consistency pass. Nothing new is bound; a lot is renamed or retyped, so
this release is breaking across every module.

The through-line is that the package had grown two ways to say most things —
a designed one and an accidental one — and the accidental one had won by
default. Flags are the clearest case: `vimage.Options` existed, with a test
pinning every bit position, and 380 wrappers took a raw `u32` anyway. The only
vImage example in the README was written against `Options` and had not
compiled for some time.

2540 tests pass with the CoreGraphics option off and 1292 with it on, in all
four optimize modes.

### Breaking

- **vImage wrappers take `Options`, not `vImage_Flags`.** All 380 of them.

  ```zig
  // before
  _ = try vimage.geometry.scale(u8, &src, &dst, null, 32 | 8);
  // after
  _ = try vimage.geometry.scale(u8, &src, &dst, null, .{
      .high_quality_resampling = true,
      .edge_extend = true,
  });
  ```

  `Options` is a `packed struct(u32)` whose bit positions are pinned against
  the `kvImage*` constants by a test. It cannot express a bit vImage does not
  define, which matters because `kvImageUnknownFlagsBit` is a failure vImage
  really does return. `vimage.Flags` still holds the raw integers for code
  crossing an FFI boundary; `Options.from(raw)` and `.bits()` convert.

- **Every module's error set is named `Error`.** `VImageError`, `SparseError`,
  `QuadratureError`, `CGError` and `CVError` are gone; `bnns.Error` and
  `lapack.Error` already had the name. A one-line `sed` per module migrates
  code.

- **`vimage.Error` no longer means what it used to.** It was the namespace of
  raw `kvImage*` integers, while `vimage.VImageError` was the error set — so
  the name meant the opposite of `bnns.Error` and `lapack.Error`. The integers
  are now `vimage.ErrorCode`. Code that said `vimage.Error.kvImageNoError`
  fails to compile rather than changing meaning silently.

- **`deinit` always takes `*Self`.** Roughly half the package took `self` by
  value and half by pointer. Call sites become
  `var x = try T.init(...); defer x.deinit();`. Where the handle is optional
  it is nulled, so a double free is a no-op rather than a double release.

- **Owned-handle constructors are `init` / `init<Qualifier>`.**
  `Converter.createWithCGImageFormat` -> `initWithCGImageFormat`,
  `CVImageFormat.create` -> `init`,
  `CVImageFormat.createWithCVPixelBuffer` -> `initWithCVPixelBuffer`,
  `ColorSpace.deviceRGB` -> `initDeviceRGB`, `ColorSpace.named` ->
  `initNamed`, and so on. Free functions that build an object keep a verb
  name (`createCGImageFromBuffer`, `converterForCGToCVImageFormat`), which is
  now the rule rather than an accident.

### Fixed

Two declarations in the tree did not compile. Neither was reachable from any
test, and `std.testing.refAllDecls` only forces declarations one level deep,
so nothing ever analysed them:

- **`vimage.utilities.Converter.tempBufferSize`** passed a raw `u32` where an
  `Options` was wanted. It now builds the query by setting the field, which is
  what the type is for.
- **`vimage.conversion_indexed.Dither.ordered_noise_shape_mask`** was written
  `0xf << 28` as a `c_int`, which is not representable. The C constant is
  `(0xfU<<28)` — the `U` suffix widens the whole anonymous enum to
  `unsigned int` — while the `dither` parameter is a plain `int`, so the mask
  is now a `c_int` carrying the same bit pattern via `@bitCast`. A new test
  pins all seven dither constants.

The root test block now walks declarations recursively, bounded by depth, so
this class of dead-but-broken code fails the build.

### Added

- **`examples/readme.zig`** — every code sample in `README.md`, compiled by
  `zig build test` against both build configurations. Four samples were wrong
  when the file was added: a `vimage.alpha` function name that never existed,
  a missing `comptime T`, a `morphology.dilate` call with the wrong arity, and
  a `vdsp.FFT` method (`forward`) that does not exist at all. The README's
  blocks are now copied from that file.

- **A "Conventions" section in `README.md`** stating the five rules above in
  one table, so the next addition has something to be consistent with.

## 0.3.0

Accelerate, bound in full — the CoreGraphics half included.

0.2.0 left `vImage_Utilities.h` and `vImage_CVUtilities.h` out on a scope
question about depending on CoreGraphics and CoreVideo. This release answers
it and binds all 45, so every non-excluded symbol in `Accelerate.framework` is
now bound. The dependency is opt-in.

The test suite went from 1246 to 2536 tests across both build configurations,
passing in all four optimize modes.

### Added

- **`vImage_Utilities.h` and `vImage_CVUtilities.h` — the last 45 entry
  points.** With these, every non-excluded symbol in `Accelerate.framework` is
  bound. The headline is `vImageConvert_AnyToAny`, wrapped as
  `vimage.utilities.Converter`: one compiled object converts between any two
  formats vImage can describe, colour-space changes and CG-to-CV format pairs
  included.

  - `vimage.utilities` — `CGImageFormat`, `Converter`,
    `createCGImageFromBuffer`, `bufferInitWithCGImage`, `bufferInit`,
    `bufferLayout`, `bufferSize`, `componentCount`, `formatsEqual`.
  - `vimage.cv` — `CVImageFormat`, the `CVPixelBuffer` bridges,
    `converterForCGToCVImageFormat` / `converterForCVToCGImageFormat`,
    `createRGBColorSpace` / `createMonochromeColorSpace`.
  - `accelerate.cg` — the slice of CoreFoundation and CoreGraphics these need:
    `ColorSpace`, `Image`, `ColorConversionInfo`, and `CGBitmapInfo` as a
    `packed struct(u32)` rather than an integer to hand-OR.
  - `accelerate.cv` — `PixelBuffer` (creation, locking, plane access) and the
    `kCVPixelFormatType_*` codes.

- **`-Dcoregraphics` build option**, default `false`. The four namespaces above
  exist only when it is on, because binding them means linking CoreGraphics,
  CoreVideo and CoreFoundation into every consumer. Dependents set it in the
  `b.dependency` call: `.coregraphics = true`. With it off, each namespace
  resolves to a placeholder whose only declaration is `enabled = false`, so a
  program can branch on the feature and one that uses it anyway gets a compile
  error naming what it wanted. `zig build test` builds the package both ways.

- **CoreFoundation ownership is encoded in the types.** `*CGImage`,
  `*CGColorSpace` and `*CVPixelBuffer` are borrowed pointers with no `deinit`;
  `cg.Image`, `cg.ColorSpace`, `cv.PixelBuffer`, `utilities.Converter` and
  `cv.CVImageFormat` are owned +1 references that must be released.
  Constructors return the owned form, getters the borrowed one, and
  `.borrow(ptr)` / `.adopt(ptr)` convert. The Create Rule is invisible in C,
  where both are the same `CGImageRef`.

- **Ten more rows in `docs/COVERAGE.md`'s "Behaviour that contradicts the
  headers" table**, each pinned by a test. Among them:
  `vImageCreateCGImageFromBuffer` rewrites an alpha-first format to alpha-last
  and converts the pixels to match; `vImageBuffer_InitForCopyToCVPixelBuffer`
  describes a subsampled chroma plane in the *luma* geometry, four times what
  `CVPixelBufferGetWidthOfPlane` reports; `vImageCGImageFormat_IsEqual` says
  two NULLs are unequal.

- `vImage_Error` now maps the `vImageCVImageFormatError` block
  (-21600..-21604) onto its own Zig errors. Those codes sit well away from the
  main run, so they previously fell through to `Unknown`.

- `README.md` gains a "What this package does not bind" section: the five
  deliberately excluded headers, why Zig's `@Vector` and arbitrary-width
  integers make four of them unnecessary, and why `LinearAlgebra` is excluded
  while the equally deprecated BNNS filter API is not.

### Fixed

- **`LICENSE` was not shipped with the package.** `build.zig.zon`'s `.paths`
  listed only `build.zig`, `build.zig.zon` and `src`, so a consumer running
  `zig fetch` got the code without its licence. `README.md`, `CHANGELOG.md` and
  `docs/` were missing for the same reason and are now included too. Affects
  every release up to and including 0.2.0.

## 0.2.0

Accelerate, bound in full.

0.1.0 covered `vdsp`, `vforce` and `vimage`. This release adds `sparse`,
`quadrature`, `blas`, `lapack` and `bnns`, and closes the gaps in what was
already there. Every public entry point in `vecLib` and `vImage` is now bound
except `vImage_Utilities.h` and `vImage_CVUtilities.h` (47), which are held
back on a scope decision about depending on CoreGraphics and CoreVideo —
`docs/COVERAGE.md` states the question and the numbers behind all of this.

The test suite went from 476 checked items to 1246 tests, passing in all four
optimize modes.

### Breaking

- **`vImage_YpCbCrPixelRange`'s fields are `i32`, not `i16`.** The C struct is
  eight `int32_t` — 32 bytes, not 16. Code that builds one has to change; code
  that passed one to Accelerate was already handing it a half-size object with
  every field after the first at the wrong offset.

- **`vImage_YpCbCrToARGB` and `vImage_ARGBToYpCbCr` are 128 bytes, not 64.**
  They are opaque, so this only affects storage. Anyone who allocated one and
  called `vImageConvert_YpCbCrToARGB_GenerateConversion` was getting 64 bytes
  written past the end of it.

- **`bnns.tensor.topK` takes a non-optional `best_indices`.** The header marks
  it `_Nullable` on macOS 13+, but passing NULL never returns. Requiring the
  descriptor makes the hang unreachable; discard the indices if you do not
  want them.


### Added

- **vImage Conversion, in full.** The remaining 173 entry points of
  `Conversion.h`, split by format family into eight sub-modules under
  `vimage.conversion`: `packed16` (ARGB1555 / RGBA5551 / RGB565), `packed10`
  (ARGB2101010 / XRGB2101010 / RGBA1010102), `ycbcr` (420, 422 and 444
  chroma-subsampled video, plus the two `GenerateConversion` matrix builders),
  `q12` (the signed 4.12 fixed-point format), `formats` (the remaining N-to-M
  pairs and the dithered narrowing variants), `indexed` (1/2/4-bit planar and
  indexed colour), `flatten` (compositing onto an opaque background, and
  chunky/planar de-interleaving) and `fill` (buffer fill, channel overwrite,
  channel permute, byte swap). `vImagePNGDecompressionFilter` from
  `BasicImageTypes.h` came along with it. `Conversion.h` is now bound in full.

- **BNNS.** Both generations of the API, 140 entry points.

  The current one is the Graph API: compile a Core ML `.mlmodelc` into a
  `bnns.Graph`, wrap it in a `bnns.Context`, execute. Alongside it are the
  standalone utilities from `bnns.h` that Apple did not deprecate — tensor
  copy and transpose, reductions, top-k, a seedable AES-CTR random generator
  and a k-nearest-neighbours store.

  The older layer-filter API (`BNNSFilterCreateLayer*`, `BNNSFilterApply*`)
  is bound too, in `bnns.filter`, `bnns.layers`, `bnns.ops`,
  `bnns.specialized` and `bnns.train`. Apple deprecated it in macOS 15.0 in
  favour of the Graph API, but 15.0 is a recent floor to require and an older
  deployment target has no Graph API to fall back on. Every declaration
  carries the version it was deprecated in and, where the header names one,
  its replacement.

  Eleven graph entry points are `__asm__`-renamed in the header —
  `BNNSGraphContextExecute` resolves to `_BNNSGraphContextExecute_v2` — and
  are bound under the real symbol with `@extern`.

- **Accelerate coverage sweep.** A symbol-level diff of every public header in
  `Accelerate.framework` against this package's `extern` declarations, and the
  work to close what it found. `docs/COVERAGE.md` records the result, the
  re-measuring recipe, and what is deliberately left out.

  Closed: `vDSP_fft3_zop`/`vDSP_fft5_zop` (+`D`), the last unbound vDSP entry
  points, as `zop3`/`zop5` - vDSP.h never states how `Log2N` maps to `N`, so
  the tests fix it at `3 << log2n` and `5 << log2n` against a closed-form DFT.
  `BLASSetThreading`/`BLASGetThreading` from `thread_api.h`, vecLib's
  per-thread switch governing BLAS *and* LAPACK, as `blas.Threading` +
  `setThreading`/`getThreading`. All six `vImageSepConvolve_*`, which left
  separable filtering - the standard path for a Gaussian blur - unreachable,
  plus the 16F convolution variants and `vImageConvolveFloatKernel_ARGB8888`.
  The whole remaining vImage Geometry surface: 75 entry points covering
  perspective warp, the double-precision `*ShearD` family, caller-supplied
  resampling kernels, and the 16F/CbCr/XRGB2101010W formats.

  Sparse gained `Complex(f32)`/`Complex(f64)` element types, Hermitian
  factorization, and LU in all four pivoting modes with `updateLu`.

  Also documented: vImage Alpha's twelve "missing" entry points are `#define`
  aliases onto the opposite channel order, not symbols, so there is nothing to
  bind.

- **`lapack` module.** The complete 2032-symbol extern surface in
  `src/lapack/c.zig`, generated from `lapack.h` by `tools/gen_lapack.py`, plus
  shared types, `info` translation and workspace sizing. Typed wrappers are
  being added tier by tier; `docs/LAPACK-PLAN.md` is the checklist. Same symbol
  story as `blas`: this binds `$NEWLAPACK[$ILP64]`, since the unsuffixed names
  belong to the deprecated `clapack.h`.

  Wrapped so far: the simple linear-system drivers in `linear.zig` (`gesv`,
  `gbsv`, `gtsv`, `posv`, `ppsv`, `pbsv`, `ptsv`, `sysv`, `spsv`, `hesv`,
  `hpsv`, `dsgesv`, `dsposv`); the computational routines behind them in
  `factor.zig` (LU, Cholesky, Bunch-Kaufman and triangular factor/solve/invert,
  condition estimation and equilibration, in full, packed and band storage);
  the `lan*` norms plus `lacpy`/`laset` in `norms.zig`; and the orthogonal
  factorizations and least squares drivers in `qr.zig` (`geqrf`, `gelqf`,
  `geqlf`, `gerqf`, `geqp3`, `orgqr`/`ungqr`, `ormqr`/`unmqr` and the LQ/QL/RQ
  equivalents, `gels`, `gelsd`, `gelss`, `gelsy`); the symmetric/Hermitian
  eigenvalue drivers in `eigen.zig` (`syev`, `syevd`, `syevr`, `spev`, `sbev`,
  `stev`, `sygv`, each with its `he*`/`hp*`/`hb*` complex counterpart); and
  `gesvd`/`gesdd` in `svd.zig`; and the nonsymmetric and generalized
  eigenproblems in `eigen_gen.zig` (`geev`, `gees`, `ggev`, `trsyl`); and the
  utilities and complex-symmetric routines in `util.zig` (`lamch`, `ilaenv`,
  `larnv`, `lartg`, `lascl`, `lasrt`, `lacgv`, `ladiv`, `rscl`, `symv`, `syr`,
  `spmv`, `spr`); and iterative refinement with error bounds in `refine.zig`
  (`gerfs`, `porfs`, `syrfs`, `herfs`, `trrfs`); and the expert drivers in
  `expert.zig` (`gesvx`, `posvx`, `sysvx`).

  Every storage form now carries the same four services as the dense one:
  condition estimation (`gbcon`, `gtcon`, `pbcon`, `ppcon`, `ptcon`, `spcon`,
  `hpcon`, `tbcon`, `tpcon`), equilibration (`gbequ`, `gbequb`, `geequb`,
  `pbequ`, `poequ`, `poequb`, `ppequ`, `syequb`, `heequb`), iterative
  refinement (`gbrfs`, `gtrfs`, `pbrfs`, `pprfs`, `ptrfs`, `sprfs`, `hprfs`,
  `tbrfs`, `tprfs`) and an expert driver (`gbsvx`, `gtsvx`, `pbsvx`, `ppsvx`,
  `ptsvx`, `spsvx`, `hpsvx`, `hesvx`).

  `reduce.zig` has the reductions to condensed form that every dense eigenvalue
  and SVD algorithm starts with — `sytrd`/`hetrd`, `sptrd`, `sbtrd`, `gehrd`,
  `gebrd` and `gbbrd` — along with the routines that build (`orgtr`, `opgtr`,
  `orghr`, `orgbr`) or apply (`ormtr`, `opmtr`, `ormhr`, `ormbr`) their
  orthogonal factors, and balancing (`gebal`, `gebak`).

  `tridiag.zig` has the six symmetric tridiagonal eigensolvers that run on what
  `reduce.zig` produces, with the module documentation laying out which to pick:
  `sterf` (values only, cheapest), `steqr` (QL/QR, most robust), `stedc`
  (divide and conquer), `stemr`/`stegr` (MRRR), `pteqr` (positive definite,
  accurate small eigenvalues) and the `stebz`/`stein` bisection pair.

  The expert and divide-and-conquer eigenvalue variants: `syevx`, `spevd`,
  `spevx`, `sbevd`, `sbevx`, `stevd`, `stevx`, `stevr` in `eigen.zig`, and
  `geevx` and `geesx` in `eigen_gen.zig`. The last two return their condition
  numbers as a typed result rather than as out-parameters, and `geesx`'s
  `info = n + 2` — reordering succeeded but the cluster is no longer separable,
  so the condition numbers may be wrong — comes back as a
  `condition_unreliable` flag rather than as an error, since the factorization
  itself is valid.

  The generalized symmetric eigenproblem in every storage form: the reductions
  `sygst`, `spgst` and `sbgst`, and the drivers `sygvd`, `sygvx`, `spgv`,
  `spgvd`, `spgvx`, `sbgv`, `sbgvd`, `sbgvx`, each with its Hermitian
  counterpart. `factor.pbstf` comes with them, since `sbgst` needs its split
  factorization and will not accept a `pbtrf` one.

  **Behaviour change:** `sygv`/`hegv` previously reported a non-positive-definite
  `B` as `error.NoConvergence`. LAPACK signals it with `info > n`, and every
  generalized driver now reads that split — above `n` is
  `error.NotPositiveDefinite`, at or below it is a genuine convergence failure.
  `lastInfo()` still carries the raw value, so `lastInfo() - n` is the leading
  minor of `B` that failed.

  `eigen_gen.zig` also gains the Schur toolkit — `hseqr`, `hsein`, `trevc`,
  `trevc3`, `trexc`, `trsen`, `trsna`, `trsyl3` — and `qz.zig` is the
  generalized problem taken apart the same way: `ggbal`/`ggbak`,
  `gghrd`/`gghd3`, `hgeqz`, `tgevc`, `tgexc`, `tgsen`, `tgsna`, `tgsyl`, the
  `gges`/`gges3`/`ggesx`/`ggev3`/`ggevx` drivers, and the generalized SVD pair
  `ggsvd3`/`tgsja`.

  `svd.zig` gains the rest of the SVD family: the bidiagonal solvers `bdsqr`,
  `bdsdc` and `bdsvdx`, the range-restricted `gesvdx`, and the high-accuracy
  Jacobi drivers `gesvj`, `gejsv` and `gesvdq`. `util.zig` gains `disna` and
  `csum1`, and `linear.zig` gains the complex mixed-precision pair
  `cgesvIterative`/`cposvIterative` that had been missing next to the real one.

  `qr_tall.zig` is the modern factorization interfaces: `geqr`/`gemqr` and
  `gelq`/`gemlq`, which let the library choose between blocked and
  communication-avoiding QR and return an opaque `Factorization(T)` that owns
  its array; the explicit block reflectors `geqrt`/`gemqrt`; the
  triangular-pentagonal family `tpqrt`/`tpmqrt`/`tplqt`/`tpmlqt`/`tprfb` for
  building your own blocked or out-of-core QR; `getsls` and `gelst`; the
  sign-fixed `geqrfp`/`geqr2p`; and the RZ factorization `tzrzf`/`ormrz`.
  `qr.zig` gains the constrained and generalized least squares routines
  `gglse`, `ggglm`, `ggqrf` and `ggrqf`.

  `rfp.zig` is rectangular full packed storage — the layout that is both
  `n(n+1)/2` elements *and* usable by the blocked kernels, where plain packed
  storage gives up the performance. The four conversions (`trttf`, `tfttr`,
  `tpttf`, `tfttp`) plus `pftrf`/`pftrs`/`pftri`, `tftri`, `tfsm` and
  `sfrk`/`hfrk`.

  `norms.zig` is finished off with the `lan*` norms that were missing:
  `langt`, `lanhs`, `lansb`/`lanhb`, `lantb`, `lantp` and `lansf`/`lanhf`.
  `lanhs` is worth knowing about — it reads only the upper triangle and first
  subdiagonal, so on a `gehrd` output it and `lange` give different answers and
  `lanhs` is the one you want.

  `cs.zig` is the CS decomposition: `orcsd` for a full square orthogonal
  matrix, `orcsd2by1` for the common single-block-column case, and the two
  halves `orbdb` and `bbcsd` they are built from, plus the `orbdb1`-`orbdb6`
  helpers.

  That completes the user-facing surface. What remains unwrapped is
  deliberately so: the `_aa`/`_rk`/`_rook`/`_2stage` variants (alternative
  algorithms for problems already covered), the unblocked kernels the blocked
  routines call internally, eight deprecated routines, and the `la*`/`ila*`
  helpers — all reachable through `c`. What the wrappers add:

  - `info` becomes a typed error. It is tri-modal in LAPACK - negative is an
    illegal argument, positive is a routine-specific numerical condition - and
    positive means something different for each family, so there is no single
    `check`. `checkLu` reports a zero pivot, `checkCholesky` a failed leading
    minor, `checkConvergence` a stalled iteration. The offending value is
    readable via `lastInfo()`.
  - `hesv`/`hpsv` are complex-only and `sysv`/`spsv` mean *symmetric* even for
    complex elements. These are different problems, LAPACK ships both, and
    neither routine can tell you that you picked the wrong one. Asking for
    `hesv(f64, ...)` is a compile error pointing at `sysv`, rather than a
    missing symbol at link time.
  - `ptsv` takes its diagonal as `[]Real(T)`: a Hermitian tridiagonal has a real
    diagonal by definition, so for `Complex(f64)` that is `[]f64` sitting next
    to `[]Complex(f64)`, which the C signature only implies.
  - `gbsv`'s band storage needs `kl` extra rows above the band for fill-in and
    is *not* the layout `gbmv` wants; `ldab >= 2*kl + ku + 1` is asserted rather
    than trusted, since passing a BLAS-shaped array otherwise factors a
    different matrix without complaint.
  - Solves are tested by residual against the original matrix rather than
    against a solution vector written down by hand, so a wrong answer and a
    wrong expectation cannot cancel.
  - `ptrfs` takes a `uplo` that the *real* routine does not have. A real
    symmetric tridiagonal has the same off-diagonal read either way, so LAPACK
    omits the argument; the complex one needs it, since the two readings differ
    by a conjugation. The wrapper takes it uniformly and drops it for a real
    `T`, with a test that pins the drop. `ptsvx`, confusingly, has no `uplo` in
    either precision.
  - **Fixed before release: `ormlq` and `ormrq` asserted the wrong shape.**
    `geqrf` and `geqlf` store their reflectors down columns, so the array is
    `q_order x k`; `gelqf` and `gerqf` store theirs along rows, so it is
    `k x q_order`. The shared helper asserted the first shape for all four,
    which rejected *every* valid `ormlq`/`ormrq` call. It went unnoticed because
    no test instantiated those two, and a generic Zig function that nothing
    calls is never type-checked — an audit for exactly that turned up 14 such
    functions, all now covered.
  - The `*equb` routines report `max_abs` **after** the same power-of-two
    rounding the scale factors get, where the `*equ` routines report the true
    largest element. Measured on a matrix whose largest entry is 100: `gbequ`
    returns 100 and `gbequb` returns 64. Comparing one against the other, or
    against `norms.lange(.max_abs)`, compares different quantities.
  - RFP takes *two* shape flags, not one: `uplo` says which triangle the data
    came from and `RfpLayout` says whether the rectangle itself is stored
    transposed. They are independent, the four combinations are four different
    arrangements of the same values, and telling `tfttr` the wrong one gives a
    wrong matrix rather than an error. A test sorts both layouts and shows they
    hold the same multiset in a different order.
  - `orcsd`'s `trans` is a **storage** flag saying whether `X` is row-major, not
    a transpose — the only place in this binding where LAPACK offers a choice of
    layout at all.
  - `sfrk` and `hfrk` take real `alpha` and `beta` even for a complex `T`,
    because a Hermitian result has a real diagonal and a complex scale factor
    would break that.
  - **`gglse` does not reliably detect a rank-deficient constraint.** Its
    documented `info = 1` is a test on a QR pivot, and an exactly duplicated row
    in `B` leaves a pivot that is small but not zero, so the call returns
    success on a problem that is not well posed. The docstring says so and a
    characterization test pins it.
  - `tprfb` has no `info` parameter at all, so its wrapper returns
    `Allocator.Error!void` rather than the usual error set — it is the only
    routine here that cannot fail.
  - **`gejsv` has no workspace query.** Every other queryable routine here is
    sized by calling it with `lwork = -1` first; `gejsv` returns `info = -17`,
    an illegal value for `lwork` itself. Its workspace is therefore sized from
    the documented formulas, taken at their maximum over every option
    combination the wrapper can produce. A test pins the `-17`, because that
    choice is only justified while it holds, and another runs every accuracy
    level through the single size.
  - `csum1` is the **true** 1-norm of a complex vector, summing `|z|`.
    `blas.asum` is not: it sums `|re| + |im|`, which is up to `sqrt(2)` larger.
    The two names read as synonyms; on two unit-modulus entries they return 2
    and 2.83.
  - `disna`'s `.left_singular` and `.right_singular` differ on a non-square
    matrix: the side with the null space has its last entry capped by
    `sigma_min` rather than by a gap. Measured on `d = {5, 3, 1}`,
    `left_singular` at 5x3 gives `{2, 2, 1}` and at 3x5 gives `{2, 2, 2}`.
  - `bdsvdx`'s `z` has `2n` rows, not `n`: each column stacks a left and a right
    singular vector, each separately normalized, because the bisection runs on
    the `2n x 2n` matrix `[[0, B], [B^T, 0]]`.
  - `tgsna`'s and `ggevx`'s condition numbers are **not** bounded by 1, where
    `trsna`'s and `geevx`'s are. They are chordal distances against an
    unnormalized pencil; measured, a diagonal pair with entries 2,3,4 and 1,2,3
    gives 1.49, 0.72, 0.91. Both docstrings say so and the tests assert
    finiteness rather than a bound.
  - `tgexc` and `tgsen` take their "do you want the vectors" flags as Fortran
    *logicals* rather than option characters — the only two routines in this
    binding that do. They are `bool` here and converted at the boundary.
  - `ggsvd3` takes its extents as `m, n, p` and `tgsja`, its own computational
    half, takes them as `m, p, n`. The wrappers keep each routine's order rather
    than imposing one, so the LAPACK documentation still reads across, and both
    docstrings flag it.
  - `sytrd`, `gebrd` and `gbbrd` write their diagonals as `[]Real(T)`, not
    `[]T`. A Hermitian tridiagonal has a real diagonal and can be made to have
    a real off-diagonal, and a bidiagonal reduction is real by construction; the
    C signature says `double *` in both the real and complex routine and leaves
    you to notice.
  - `gebal`'s window comes back as a `Window { ilo, ihi }` documented as
    1-based inclusive, because it is handed straight back to `gehrd`, `orghr`
    and `gebak`. Converting it to 0-based at the boundary would mean converting
    it back at four call sites.
  - The band routines disagree with each other about band layout, and nothing
    checks. `gbrfs` and `gbsvx` want the *original* matrix in the narrow
    `kl + ku + 1` form and its *factor* in the wide `2*kl + ku + 1` one, in
    adjacent arguments. `pbrfs` and `pbsvx` use the same `kd + 1` layout for
    both, because a band Cholesky creates no fill-in. Both leading dimensions
    are asserted.

  Verifying the ABI before writing any of it turned up two things the header
  does not tell you:

  - **`__LAPACK_bool` is 8 bytes under ILP64, not 4.** `lapack_types.h`
    comments the LP64 branch with "Because the fortran logical is 4 bytes" and
    then the ILP64 branch silently widens it to `long`. 163 declarations take a
    `bwork` array; a 4-byte definition reads every other element. There is a
    test that fails under the wrong width - which took a second attempt, because
    the obvious version (poison the array, check the tail) passes at either
    stride. What discriminates is the *value* of the elements that were written.

  - **`cladiv` and `zladiv` are declared wrongly.** The header types them as
    writing through a leading `ret` out-parameter, and calling them that way
    leaves `ret` untouched - reproduced from C as well as Zig. Disassembly shows
    the shipping symbol is a thunk that drops its first argument and tail-calls
    an implementation returning the quotient by value:

    ```asm
    cladiv$NEWLAPACK$ILP64:
        mov  x0, x1
        mov  x1, x2
        b    <impl>
    ```

    All three pointers must still be passed - a two-argument call reads whatever
    `x2` holds and crashes - but the result comes back in registers. The
    generator carries these two as hand-written overrides, and *aborts* if it
    ever meets a new routine with the same leading-`ret` shape rather than
    trusting the header. `chla_transtype`, the only other routine with a leading
    `ret`, is unaffected.

  - The condition estimators allocate their own scratch and return `rcond`
    directly. The sizes vary by routine *and* by whether `T` is real or complex
    - a real `gecon` wants `4n` reals and `n` integers, a complex one `2n`
    complex and `2n` reals - and `sycon`/`hecon` are an outright exception,
    taking no `rwork` at all where `gecon`, `pocon` and `trcon` all do. None of
    that is in the header, and getting one wrong is a heap overflow rather than
    an error, so it is not a number worth exposing. Two tests over-allocate and
    poison past the documented ends to check the sizes empirically.
  - `*con` takes `||A||` of the *original* matrix, not of the factorization
    that overwrote it. Passing the wrong one produces a confident, meaningless
    number with no diagnostic anywhere, so there is a characterization test
    pinning that the two differ.
  - Every real/complex split is a `switch (T)`, not an `if` on a type
    predicate. Zig analyses both arms of a plain `if` even when the condition is
    comptime-known, which type-checks the complex call shape against the real
    symbol and fails to compile; only the selected `switch` prong is analysed.
    The same applies to the `@compileError` guards, which otherwise fire on
    every instantiation including the valid ones.

  - `or*` and `un*` are exposed as one name. LAPACK calls the real routines
    `orgqr`/`ormqr` and the complex ones `ungqr`/`unmqr`; here `orgqr` works for
    all four element types and resolves to `zungqr` for `Complex(f64)`, with
    the LAPACK spellings kept as aliases.
  - `ormqr`'s transpose flag is a two-valued `QTrans` rather than a character.
    LAPACK accepts `'T'` for real precisions and `'C'` for complex, and passing
    `'T'` to `zunmqr` is an illegal-argument failure. `.transpose` means "the
    adjoint" and emits the right one; applying the unconjugated transpose of a
    complex `Q` is not an operation anyone wants, so nothing is lost.
  - **`gels` barely checks its full-rank assumption, and `gelsy`'s documented
    default makes it worse.** `gels` raises an error only on an *exactly* zero
    pivot; on a 3x2 matrix of all ones it returns success and
    `x = (-7.5e15, 7.5e15)`. `gelsy` with `rcond = -1` -- which LAPACK
    documents as "use machine precision", and which reads like a safe default
    -- reports that same matrix as full rank and returns the same nonsense,
    because the threshold becomes a condition number of `1/eps`. Any explicit
    `rcond` from `1e-16` up gives rank 1 and the correct minimum-norm
    `x = (1, 1)`. `gelsd` is unaffected, since it compares singular values
    rather than a condition estimate. All three behaviours are pinned by tests
    and called out in the doc comments; the tests were written expecting the
    opposite and were corrected to match what the routines actually do.

  - `sy*` and `he*` are exposed as one name for the *eigenvalue* routines, the
    same way `or*`/`un*` are - `syev(Complex(f64), ...)` calls `zheev`. This is
    deliberately **not** done for the linear solvers, where `sysv` and `hesv`
    both exist for complex elements and solve different problems. There is no
    complex-symmetric eigensolver in LAPACK at all, so with one interpretation
    available the unification loses nothing; with two it would hide a real
    choice.
  - Eigenvalues and singular values come back as `[]Real(T)`, so a
    `Complex(f64)` problem yields `[]f64`. Both are real by construction and
    the signature now says so.
  - `syevr`'s five loosely-coupled range arguments (`range`, `vl`, `vu`, `il`,
    `iu`, where the two that matter depend on the first) collapse into a
    `Selection` union: `.all`, `.interval`, or `.indices`.
  - `sygv` overloads `info > 0`: up to `n` it means the iteration did not
    converge, above `n` it means the Cholesky factorization of `B` failed at
    minor `info - n`, i.e. `B` was not positive definite. Both surface as
    `error.NoConvergence`, so the doc comment says to read `lastInfo()` and a
    test pins the `> n` case.
  - Eigendecompositions are tested by `A v = lambda v` and SVDs by
    `U S V^H = A`, never by comparing vectors against written-down values -
    signs and phases are arbitrary. One test specifically checks that `vt` is
    used as `V^H` rather than `V`, on an asymmetric matrix where the two
    differ.

  - **Nonsymmetric eigenvalues are always `[]Complex(Real(T))`.** LAPACK's real
    routines split them across `wr` and `wi`, with a conjugate pair in
    consecutive entries; the complex ones return one array. These wrappers
    gather the real pair internally, so a real matrix's complex eigenvalues are
    in the type rather than in a comment.
  - `unpackVectors` expands the packed real eigenvector layout. When
    eigenvalues `j` and `j+1` are a conjugate pair, `geev` puts the *real part*
    in column `j` and the *imaginary part* in column `j+1` - so reading column
    `j+1` as an eigenvector in its own right gives a plausible wrong answer.
    The eigenvector arrays are left in LAPACK's layout (copying them would be
    wasteful) and this converts on request; the test verifies `A v = lambda v`
    in genuine complex arithmetic afterwards.
  - `gees`'s sorting predicate takes one complex number at any precision. The
    raw LAPACK callback takes *two* pointers for real input and one for
    complex; a threadlocal trampoline bridges them, which is safe because
    LAPACK invokes the callback synchronously on the calling thread within the
    call that installed it.
  - `ggev` returns `alpha` and `beta` as a pair rather than their quotient,
    with `value()` returning null when `beta` is zero. A singular `B` gives the
    pencil genuinely infinite eigenvalues, and dividing without checking turns
    a meaningful result into a NaN.
  - `trsyl` reports `perturbed` rather than erroring when `A` and `-B` share an
    eigenvalue: LAPACK solves a nearby problem and says so, which is a result
    the caller needs but not a failure.

  - **`symv`, `syr`, `spmv`, `spr` are complex *symmetric*, and CBLAS has no
    equivalent.** CBLAS offers `hemv`/`her` for complex and `symv`/`syr` only
    for real, so a complex symmetric matrix (`A = A^T`, not `A = A^H`) has
    nowhere else to go: `hemv` conjugates when it reflects the stored triangle
    and silently returns a different answer. A test runs the same stored
    triangle through both and pins that they differ. `syr` also takes a complex
    `alpha`, where `blas.her` requires a real one - the Hermitian constraint
    does not apply to the symmetric update.
  - `lamch` exists because LAPACK's epsilon is **half** of Zig's
    `std.math.floatEps`: LAPACK defines it as the rounding unit, Zig as the gap
    to the next representable number. A tolerance built from the wrong one is
    off by a factor of two, which is enough for a routine not to behave as
    documented. Pinned by a test.
  - `larnv`'s seed carries a constraint LAPACK does not check: four values in
    `[0, 4095]` with the **last odd**, or the generator's period collapses.
    `Seed.init` enforces it for any input.
  - `lascl` and `rscl` scale without the intermediate overflow a direct ratio
    would cause - `1e300 / 1e-300` is not representable even though the scaled
    matrix is. Both have tests that overflow the naive computation first to
    show the difference is real.
  - `rscl`'s complex symbols are `csrscl` and `zdrscl`, with *two* precision
    letters (complex vector, real scalar), so the one-letter prefix lookup used
    everywhere else does not reach them.

  - `refine.zig` answers the question every solver leaves open: how much of the
    computed `x` is signal. `berr` is a computed quantity - the smallest
    relative perturbation of `A` and `b` for which `x` is exact - and sits near
    machine epsilon for any sane solve. `ferr` is an *estimate* of the relative
    forward error, built from a condition bound, and is usually pessimistic. A
    test on a nearly singular system pins the distinction: `berr` stays below
    1e-14 because the solver did its job, while `ferr` exceeds 1e-8 because the
    problem itself does not determine `x`.

    These take the original matrix *and* its factorization, so the matrix has to
    be copied (`norms.lacpy`) before factoring - the factor routines overwrite
    their input, and there would otherwise be nothing to refine against.

  - **The expert drivers treat `info = n + 1` as a result, not a failure.** They
    overload the positive `info`: `1..n` means the factorization hit an exactly
    zero pivot and nothing was solved, but `n + 1` means the factorization
    succeeded, `rcond` came out below machine precision, *and the system was
    solved anyway*. `x`, `ferr` and `berr` are all valid; LAPACK is reporting
    that the matrix is singular to working precision. Returning an error there
    would discard both a computed answer and the diagnostic attached to it, so
    it surfaces as `singular_to_working_precision` on the result instead.

    Provoking that case for a test took measurement rather than guesswork - the
    window is about one ULP wide. Perturbing the identity-like matrix by less
    than an ULP rounds away and yields an exactly zero pivot; by a few ULPs
    lifts `rcond` back above eps and the warning stops firing.
  - `equed` is the only option character in this binding that LAPACK *writes*:
    an input when reusing a supplied factorization, an output when asking the
    routine to equilibrate. It is therefore a `*Equed` and cannot come from the
    shared immutable byte table the other options use.

- **`blas` module - the full CBLAS surface.** Levels 1, 2 and 3 over `f32`,
  `f64`, `Complex(f32)` and `Complex(f64)`, selected by a comptime element
  type. 156 extern declarations, generated from `cblas_new.h` rather than
  transcribed, behind checked wrappers.

  **This binds the current interface, not the obvious one.** Accelerate exports
  every routine three times: `_cblas_sgemm` (legacy), `_cblas_sgemm$NEWLAPACK`
  (current, LP64) and `_cblas_sgemm$NEWLAPACK$ILP64` (current, 64-bit indices).
  The unsuffixed name is what plain `cblas.h` declares, and that whole header
  has been `API_DEPRECATED` since macOS 13.3 in favour of the ILP64-capable
  one. The suffixes come from `__LAPACK_ALIAS`, which is an `__asm` label
  rename, so a C caller never sees them - and a Zig caller binding the obvious
  name would silently get the deprecated routine. `types.zig` reproduces
  `lapack_version.h`'s arch test so `Int` and the symbol suffix are chosen
  together; getting that pairing wrong links cleanly and then reads the wrong
  half of every dimension.

  What the Zig layer adds over a transliteration:

  - Matrices and vectors are slices, checked against the dimensions, leading
    dimensions and increments - including negative increments, which BLAS
    allows and which span the same elements as positive ones.
  - `Order`, `Transpose`, `Uplo`, `Diag` and `Side` are enums.
  - The Hermitian routines that require a **real** scalar - `her`, `hpr`,
    `herk`, and `her2k`'s `beta` - take `Scalar(T)`, so a complex one does not
    compile. A complex alpha there would silently produce a non-Hermitian
    result.
  - `iamax` returns `?usize`, rather than overloading 0 to mean both "first
    element" and "empty input".
  - Every extern is referenced by a test, because Zig resolves declarations
    lazily and an unreferenced `@extern` with a wrong symbol name would link
    fine until its first caller.

- **`quadrature` module - numerical integration.** One-dimensional integration
  of a real function via QNG, QAG or QAGS, including infinite intervals.

  Small and ordinary C - one exported symbol, no overloading, a plain function
  pointer rather than a block - so unlike `sparse` it binds directly. What the
  Zig API adds is that three ways to get a runtime failure become
  unrepresentable or checked, all three found by probing rather than from the
  header:

  - `max_intervals = 0` is rejected by both adaptive integrators (status -2),
    so a zero-initialized options struct is a trap. `Integrator` is a tagged
    union carrying each algorithm's own parameters, with a documented non-zero
    default that is this binding's choice - Apple gives none.
  - Infinite bounds work **only** with QAGS. QNG reports an invalid argument,
    but QAG returns `NaN` with a max-eval status, which is a poor way to learn
    the integrator was wrong. Both are rejected up front.
  - `qag_points_per_interval` accepts only 0/15/21/31/41/51/61; 17 returns -2.
    It is an enum here.

  Failing to reach the requested tolerance is **not** an error - it arrives as
  `Result.status` next to the partial estimate and Accelerate's error bound.
  That matters for integrands like `sin(1/x)`, which never converges at any
  budget (measured at 8 through 4096 intervals) yet yields a value good to
  ~1e-6.

- **`sparse` module - Apple's Sparse Solvers.** Direct sparse linear solvers:
  Cholesky, `LDL^T` (four pivoting modes) and QR, over `f32` and `f64`, plus
  sparse-times-dense multiplication and coordinate-to-block-CSC conversion.

  The public C API could not be bound the way `vdsp`/`vforce`/`vimage` were.
  Every entry point in `Sparse/Solve.h` is
  `static inline __attribute__((overloadable))`, so there is no symbol to link
  against, and `@cImport` cannot read the header at all - translate-c rejects
  the second declaration of an overloaded name, and `SparseSolve` alone has 78.
  The bindings target the underscore-prefixed implementation symbols that the
  inline wrappers dispatch to (declared `extern` in the SDK's
  `SolveImplementation*.h` under `API_AVAILABLE(macos(10.13), ...)`) and
  re-implement the wrappers' validation in Zig. `docs/SPARSE-RESEARCH.md` has
  the full reasoning, including the risk this carries.

  Two places where the Zig API is deliberately not a transliteration:

  - **A bad argument is an error, not process death.** With
    `options.reportError == NULL` - the default - Sparse's parameter checks
    call `_SparseTrap()`, i.e. `__builtin_trap()`. Arguments are validated in
    Zig first, and a `reportError` callback is installed so anything Sparse
    rejects internally surfaces as `SparseError` with its message available
    from `lastErrorMessage()`.
  - **The solve workspace comes from your allocator.** Apple's `SparseSolve`
    mallocs and frees scratch on every call. The size is computable from
    public fields, so `solve` takes a `std.mem.Allocator` and
    `solveWithWorkspace` takes a buffer you can hoist out of a loop.
    `refactor` works the same way.

- **Iterative solvers** - conjugate gradient, GMRES (DQGMRES / GMRES / FGMRES)
  and LSMR, over either a stored matrix or a **matrix-free operator**, with
  built-in (diagonal, diagonal-scaling) or user-supplied preconditioners.

  Every iterative entry point takes its operator as a `_Nonnull` Objective-C
  block, and there is no block-free variant. Zig has no block syntax, so
  `block.zig` reproduces libclosure's `Block_layout` directly - a block is a
  struct with a documented layout, not magic - and the operator callback is
  what it captures. This is also why the matrix-free form is the *natural* one
  here: it is the shape the C API actually has, and the matrix-taking overloads
  are wrappers around it.

  Two behaviours worth knowing, both found by measurement rather than from the
  header:

  - Non-convergence is an outcome, not an error. `.max_iterations` comes back
    as a status. Sparse *also* pushes "Exceeded maximum iteration limit."
    through the `reportError` callback, so the binding decides on the returned
    status rather than on whether a message arrived.
  - `.fgmres` requires a preconditioner and is rejected without one.

- **Subfactors** - `L`, `D`, `P`, `S`, `Q`, `R` extracted from a factorization
  and applied individually, each holding its own reference so it may outlive
  the factorization it came from.

  `Solve.h` documents the `PLPS` round trip as "transpose solve followed by
  non-transpose solve". **That is backwards.** For the symmetric 4x4 in the
  test suite the header's order returns `{0.690, 2.035, 2.772, 4.198}` where
  the answer is `{1, 2, 3, 4}`. The algebra agrees with the measurement: for
  Cholesky `A = PLL'P'`, so `M = PLP'` gives `M M' = A`, and a full solve is
  `M y = b` then `M' x = y`. Both orders are pinned by tests, so if a future
  SDK ever makes the prose true, it fails loudly.

- 384 tests covering the four modules above, including struct-layout
  assertions against the C headers for every ABI type. Those are not decoration: each one is passed to
  or returned from Accelerate by value, so layout drift on a future SDK would
  corrupt memory rather than fail to compile. The block literal's offsets are
  asserted for the same reason - a wrong one is a wild jump, not a type error.

### Fixed

- **`vImage_YpCbCrPixelRange` was declared at half its size.** Every field is
  `int32_t` in `vImage_Types.h`, not `int16_t`: 32 bytes, not 16. Every field
  after the first sat at the wrong offset.

- **`vImage_YpCbCrToARGB` and `vImage_ARGBToYpCbCr` were declared at half
  their size.** Each is 128 bytes aligned to 16, not 64 aligned to 4, so
  `vImageConvert_YpCbCrToARGB_GenerateConversion` wrote 64 bytes past the end
  of the caller's object. Both structs and the pixel range are now pinned by a
  layout test whose numbers were measured against `<Accelerate/Accelerate.h>`.

- **`aSrc` was not optional in three 16U conversions.**
  `vImageConvert_RGB16Uto{ARGB,RGBA,BGRA}16U` mark it optional via
  `VIMAGE_NON_NULL(1,4)`; it was declared `*const vImage_Buffer`, which made
  the scalar-alpha mode unreachable.

- **The new Conversion sub-modules' tests were not running.**
  `std.testing.refAllDecls` only forces declarations one level deep, so
  `vimage.conversion` was reached but `vimage.conversion.packed16` was not.
  The eight modules compiled and their 131 tests never executed.


### Documented

- **`FFTSetup`/`FFTSetupD` are immutable after creation and safe to share
  across threads.** `vDSP.h` never says so - and its silence is meaningful,
  since it *does* warn explicitly where a setup is mutated by its execute call
  (`vDSP_biquadm_Setup`). Established by measurement rather than inference: the
  heap graph reachable from a setup (~75 blocks, ~394 KB) does not change by a
  single byte across 110 million transforms over 9 entry points on 32 threads,
  and a read-only object cannot be raced on. Corroborated by 86 million
  bit-compared transforms and a ThreadSanitizer run. Measured on macOS/arm64
  and assumed to hold on every platform Accelerate ships for.

  So share one `FFT(T)` across threads rather than creating one each: a
  `log2n = 12` setup costs ~194 us and ~369 KB, and 8 threads each building
  their own burns ~1.7 ms and ~2.9 MB for nothing.

- Two further measurements recorded in the same place so they are not
  rediscovered: a setup created at `log2n = K` drives any smaller transform
  bit-identically and at the same speed (so one oversized setup could serve
  every size - though the current API binds `log2n` at `init`, so this is not
  reachable yet), and the `zipt`/`zopt` temp-buffer variants that `vDSP.h`
  says are "permitted to use the temporary buffer for improved performance"
  are **not** measurably faster (0.98x-1.01x across `log2n` 4..18) and return
  bit-identical results.

### Added

- Two tests that keep the above honest on whatever platform the suite runs on:
  `"FFT setup is read-only during execution"` walks the setup's heap graph via
  `malloc_size` and asserts nothing changed, and `"one setup drives every
  smaller size, bit-identically"` pins the size-reuse invariant.

## 0.1.0

The first release with a verified binding surface.

Every wrapper in `vdsp`, `vforce` and `vimage` — 476 items — was checked
argument-by-argument against the macOS SDK headers (`vDSP.h`, `vForce.h`,
`vImage/*.h`) and, where the header was ambiguous, silent, or contradicted
itself, against the running framework. That pass found **9 genuine bugs**, 8
wrong doc comments, and an entire module that did not compile. The test suite
went from 15 tests to 406.

A second pass then reshaped the API so that several of those bug classes are
no longer expressible.

Everything below is a breaking change from `0.0.0`. Most break loudly — the
compiler rejects the old call. **Read the "silent" section first**: three
changes alter results without changing types.

---

### Silent behavior changes — read these

These do **not** produce a compile error. If you are upgrading, audit these
call sites by hand.

- **`vdsp.vsub` now computes `a - b`.** It previously computed `b - a`.
  `vDSP.h:2811-2818` declares `vDSP_vsub`'s parameters as `__B` then `__A`
  with the comment `// Caution: A and B are swapped!`; the old wrapper passed
  its arguments through positionally and returned the negation of what its own
  name and doc comment promised.

  If you compensated for the old behavior — by swapping your arguments, or by
  negating the result — **remove that compensation**, or your results will now
  be sign-flipped. This was wrong for the library's entire history, so
  compensating was a reasonable thing to have done.

- **`Biquadm(T).copyState` now copies in the direction its name implies.**
  `a.copyState(b)` makes `a` adopt `b`'s delay state. It previously did the
  reverse, overwriting the *argument* with the *receiver*'s state
  (`vDSP.h:472-479` declares `__dest` first; the binding passed `src` into the
  `__dest` slot).

- **`vforce.pow` now takes `(base, exponent)`.** Both parameters are
  `[]const T`, so swapping them still compiles. See *Changed* below for why
  the order moved.

### Fixed — memory safety

- **`vdsp.vswmax` wrote past the end of a correctly-sized output buffer on
  every call.** `vDSP.h:5698-5706` requires both `A` and `C` to hold
  `N + WindowLength - 1` elements even though only `N` are meaningful output;
  the old wrapper derived `N` from `out.len`, so *no* buffer size satisfied
  both "have N outputs" and "give the C function its scratch room". `N` is now
  an explicit parameter. **Signature change.**
- **`vdsp.deq22` wrote 2 elements past the end of `out` on every call**, and
  never filled `out[0]`/`out[1]`. `vDSP.h:3956-3966` writes outputs at indices
  `[2, N+2)` and reads `out[0..2)` as filter history. `n_out` is now explicit,
  with a doc comment explaining the offset convention. **Signature change.**
- **`vdsp.zdotpr`, `zidotpr`, `zrdotpr` hung indefinitely.** They passed an
  uninitialized `SplitComplex` into the C function, which then wrote through
  its garbage pointers — not a crash, not a wrong answer, a deadlock. They now
  return `Complex(T)` (a plain value struct) backed by real storage.
  **Return type change.**

### Fixed — wrong results

- **`vforce.pows` silently discarded all but the first exponent.** It took
  `[]const T`, mirroring `pow`'s per-element exponent slice, but `vvpows`
  reads only element 0 (`vForce.h:467-475`: "Input **scalar**"). Now a scalar
  `T`. **Signature change.**

### Fixed — did not compile

- **The entire `vimage` module was uncompilable.** `src/vimage/c.zig` had six
  self-referencing type aliases (`pub const vImage_Buffer = vImage_Buffer;`)
  and two externs taking a C array type by value. Zig's lazy declaration
  resolution hid this from the day the module was added, because nothing had
  ever forced those particular declarations to resolve.

### Fixed — ABI

- `src/vdsp/c.zig` declared `vDSP_DFT_Interleaved_CreateSetup`'s
  `RealToComplex` parameter as `c_int`, where `vDSP.h:6904` defines it as a
  `bool`-backed enum. Correct in practice on AAPCS64/SysV only by accident —
  the callee reads the low byte of a register that happened to hold the right
  value.

### Fixed — documentation that was actively misleading

These changed no code, but a caller who believed them got wrong numbers.

- **vDSP FFTs are unnormalized in *both* directions.** `vDSP.h`'s own
  pseudocode for `fft_zip`/`zop` claims a `1/N` scale on the inverse leg that
  the real implementation does not apply. Running an impulse forward then
  inverse returns `N`× the original, not the original. Anyone who trusted the
  old doc comment was already off by a factor of `N`. The same wrong `1/N`
  claim appeared for `zrip`/`zrip2d`; those are additionally asymmetric —
  forward scales by 2, inverse by 1, so a real round trip returns `2N`×.
- **`Biquadm` coefficient layout is section-major**, not channel-major as the
  old doc comment claimed: `[sec0_ch0, sec0_ch1, sec1_ch0, ...]`. Following
  the old comment put your coefficients in the wrong sections.
- **`vdsp.viclip` is an *inverse* clip.** Values *outside* `[lo, hi]` pass
  through unchanged; values *inside* are pushed out to the nearer boundary —
  the opposite of what the name suggests.
- **`vdsp.vmaxmg`/`vminmg` return a magnitude**, always non-negative, never
  the original signed value.
- **`vdsp.vsorti` hangs** unless `indices` arrives pre-seeded with the
  identity permutation — a precondition documented nowhere in `vDSP.h`. Now
  handled by the wrapper (see *Changed*).
- `vforce.pow`'s doc comment had its operands backwards.
- `vimage.unpremultiplyDataPlanar`'s formula was missing its `MIN` clamp.
- `RealDFT`/`InterleavedDFT` scaling and DC/Nyquist packing, `DFT`'s
  normalization, and `DCT`'s length constraint and per-type formulas were
  undocumented; `InterleavedDFT`'s real-to-complex mode has no packing
  documentation in the header at all and was resolved against the running
  framework.

### Added

- **`vdsp.SplitSlice(T)`** — a split-complex buffer pair that carries its own
  length. `SplitComplex(T)` is two raw pointers, so the `n` parameter beside
  it could never be validated; ~37 functions across `zvecop`, `matrix`,
  `dotp`, `conv` and the 20 `FFT` methods had **zero** bounds checking — in
  the module where both confirmed hangs occurred. All of them now take
  `SplitSlice(T)` and assert `n` against the real buffer lengths.

  `n` is still an explicit parameter: operating on a prefix of a larger
  scratch buffer is routine in DSP code, and deriving `n` from the slice would
  make that inexpressible. The goal was a *checkable* `n`, not no `n`.

  **Breaking:** pass `SplitSlice(T).init(re, im)` instead of
  `&SplitComplex(T){ ... }`; call `.raw()` if you need the C-ABI struct.

- **`vimage.VImageError` and `vimage.check`** — vImage wrappers now return
  `VImageError!usize` instead of a raw `vImage_Error` that was silent to
  ignore. The success test is `>= 0`, not `== 0`: with
  `Flags.kvImageGetTempBufferSize` set, vImage returns the required buffer
  size *through the same return slot*, and an `== 0` check would misreport
  that as failure. The `usize` payload is 0 for an ordinary call, or that size
  for a size query. **Breaking:** `try` the call; `_ = try f(...)` to discard.

- **`vimage.Options`** — a `packed struct(u32)` for vImage flags, so
  `Options.of(.{ .edge_extend = true })` replaces raw integer arithmetic and
  a bit vImage does not define is a compile error. The `Flags.kvImage*`
  constants remain for direct header correspondence.

- **`vimage.Connectivity`** — `.four` / `.eight` instead of a bare `c_int` on
  the `floodFill_*` functions.

- **`vdsp.vsortiAssumeSeeded`** — see the `vsorti` change below.

- **`FFT(T).roundTripScale()`, `.realForwardScale()`, `.realRoundTripScale()`**
  — the scaling facts above as callable, test-checked code rather than prose.
  Prose is how the original wrong `1/N` claim survived so long.

- **`vdsp.inverseClip`, `.maxMagnitude`, `.minMagnitude`** — aliases for
  `viclip`, `vmaxmg`, `vminmg`, whose vDSP names read as the opposite of, or
  vaguer than, what they do. Visible at the call site, which is where the
  misreading happens. The vDSP names remain primary.

- **267 new `std.debug.assert` length/dimension preconditions**, bringing
  every file up to the checking its best-covered siblings already had
  (`clip.zig` previously had none at all). These are active in Debug and
  ReleaseSafe: code that was already passing under-sized buffers now panics at
  the call instead of corrupting memory inside the C function. No effect in
  ReleaseFast or ReleaseSmall.

- **`DFT(T)`, `RealDFT(T)`, `DCT`, `InterleavedDFT(T)` gained a `length`
  field**, so `exec` can check its buffers against the size the setup was
  created with.

- **391 tests** (15 → 406). Tests that pin undocumented, runtime-determined
  framework behavior are marked `[characterization]`: if one fails on a future
  macOS, that is the intended signal to re-verify Apple's behavior, not
  evidence that this binding regressed.

### Changed

- **`vdsp.vsorti` now seeds `indices` with the identity permutation itself.**
  vDSP_vsorti requires that on entry and hangs indefinitely otherwise. A
  documented-only landmine is not a fix in a library whose premise is
  absorbing vDSP's quirks. Use `vsortiAssumeSeeded` to skip the `O(N)` seed.
- **`vdsp.vswsum` gained an explicit `n` parameter** so it and `vswmax` share
  one signature. Their buffer contracts genuinely differ (`vswsum` needs
  `out.len >= n`; `vswmax` needs `n + window_len - 1`) and the asserts now
  carry that difference instead of the signatures doing it implicitly. The two
  look interchangeable at a glance and are not. **Signature change.**
- **`Biquadm(T).apply` takes slices** (`[]const [*]const T`) instead of bare
  multi-pointers, and asserts the channel count against the setup. Passing too
  few channel pointers previously hung. Most call sites compile unchanged.
- **`vdsp.ctoz` and `ztoc` take slices** instead of `[*]`-multi-pointers for
  their interleaved-complex side, so that side is bounds-checked too.
  **Signature change.**
- **`vforce.pow` and `vforce.pows` take `(base, exponent)`.** `pow`
  previously took `(exponent, base)`, mirroring vForce's C parameter order.
  The binding already reorders arguments to match its own names elsewhere
  (`vsub`, `vdiv`); doing it in one place and not another was the worst of
  both. See the silent-changes section — `pow`'s reordering does not always
  produce a compile error.
- Length preconditions in `biquad.zig` and `dft.zig` use `>=` rather than
  `==`, matching the rest of the codebase, so passing an oversized backing
  buffer is legal.

### Notes

- `vdsp.Length` is already `usize` and `vimage.vImagePixelCount` is already
  `usize`, so no `@intCast` is needed at API boundaries.
- The four 2D **real** FFT methods (`zrip2d`, `zrop2d`, `zript2d`, `zropt2d`)
  deliberately carry no length assert. Their DC/Nyquist packing is the one
  layout that could not be derived from the header — `vDSP.h`'s pseudocode for
  it is internally inconsistent and the header itself calls the format
  "awkward … due to a legacy implementation" — and a guessed assert that is
  too strict would panic on correct caller code. The layout is instead pinned
  empirically by a characterization test: the row dimension folds DC/Nyquist
  into row 0's real/imaginary parts (the 1D `zrip` convention), while the
  column dimension puts DC at column 0 and Nyquist at **column 1**, not column
  `N1/2` as a naive reading of the header would predict.
- Verified on macOS (arm64) against the macOS 15.4 SDK headers.
