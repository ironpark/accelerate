# Changelog

## Unreleased

### Added

- **`lapack` module.** The complete 2032-symbol extern surface in
  `src/lapack/c.zig`, generated from `lapack.h` by `tools/gen_lapack.py`, plus
  shared types, `info` translation and workspace sizing. Typed wrappers are
  being added tier by tier; `docs/LAPACK-PLAN.md` is the checklist. Same symbol
  story as `blas`: this binds `$NEWLAPACK[$ILP64]`, since the unsuffixed names
  belong to the deprecated `clapack.h`.

  Wrapped so far, in `linear.zig`: the simple linear-system drivers `gesv`,
  `gbsv`, `gtsv`, `posv`, `ppsv`, `pbsv`, `ptsv`, `sysv`, `spsv`, `hesv`,
  `hpsv`, and the mixed-precision `dsgesv`/`dsposv`. The expert drivers
  (`gesvx` and friends) are not wrapped yet. What the wrappers add:

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

- 244 tests covering the four modules above, including struct-layout
  assertions against the C headers for every ABI type. Those are not decoration: each one is passed to
  or returned from Accelerate by value, so layout drift on a future SDK would
  corrupt memory rather than fail to compile. The block literal's offsets are
  asserted for the same reason - a wrong one is a wild jump, not a type error.

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
