# Accelerate binding audit

Progress: 206/476 checklist items verified (see `fix/checklist.sh` for live status).
Completed: priority 1 (8 "swapped" functions), priority 2 (16 ultrasync
dependencies), priority 3 (vecop.zig, zvecop.zig, reduction.zig, clip.zig,
util.zig, convert.zig - 168 functions), and priority 4 (fft.zig remainder,
dft.zig, fixed_fft.zig - 41 functions) from `fix/REQUEST.md`. Priority 4 was
run as three parallel worktree agents (fft.zig remainder / dft.zig /
fixed_fft.zig) and merged back cleanly. Priorities 5-7 not yet started.

## Behavior changes

| Function | Downstream impact | Evidence | Change |
| --- | --- | --- | --- |
| `vdsp.vsub` | Not used by the current ultrasync call list, so no downstream compensation is at risk | macOS SDK `vDSP.h:2811-2828`: `vDSP_vsub`/`vDSP_vsubD` declare `__B` before `__A` and explicitly warn "Caution: A and B are swapped!" | The wrapper now passes `b` then `a` into the C call, so `vsub(a, b, out)` computes `a - b` as its name and doc comment promise. Regression test uses asymmetric inputs (`a=[1,2,3]`, `b=[10,20,30]`) for both f32 and f64. |
| `vdsp.vswmax` | Not called anywhere else in this codebase, so safe to change without a downstream migration | `vDSP.h:5705-5707`: `C` (the output buffer) must contain `N+WindowLength-1` elements even though only the first `N` are meaningful output - `vDSP_vswmax` uses the tail of the buffer as scratch space. The prior wrapper derived `N` directly from `out.len`, so a caller who sized `out` to exactly the `N` outputs they wanted (the natural reading of the old signature) triggered an out-of-bounds write by the C function. There was no way to call the old signature safely per its own documented buffer requirement. | Added an explicit `n: Length` parameter instead of deriving it from `out.len`, plus asserts that both `a` and `out` are large enough (`>= n + window_len - 1`). |

## Comment-only corrections

| Function | Evidence | Change |
| --- | --- | --- |
| `FFT(T).zip`, `FFT(T).zop` | `vDSP.h`'s pseudocode claims inverse transforms apply a `1/N` scale ("scale = 0 < Direction ? 1 : 1./N"). Running an impulse through `FFT(f32).zip` forward then inverse (N=4) produced `4x` the original signal, not the original signal - the real (hardware-accelerated) implementation is unnormalized in **both** directions. Matches `fix/REQUEST.md`'s own note that vDSP FFTs are unnormalized. | Removed the incorrect scale line from both doc comments and documented the actual unnormalized behavior, backed by a new round-trip test in `fft.zig`. Any caller who trusted the old comment's claim of automatic 1/N scaling on inverse was already getting numerically wrong results before this fix - the *code* was correct, the *docs* were not. |
| `vdsp.vsorti` | Runtime testing found that calling `vsorti` with an uninitialized `indices` output array hangs `vDSP_vsorti` indefinitely - not a crash, not wrong output, an infinite hang. This precondition (that `indices` must start as the identity permutation `0..N-1`) is not documented anywhere in `vDSP.h`. | Added a prominent CAUTION note on the function documenting the required pre-seeding and the hang failure mode, since a silent deadlock is far more dangerous to discover in production than a wrong answer. |
| `FFT(T).zrip`, `FFT(T).zrip2d` | Not called elsewhere in the codebase. | `vDSP.h`'s pseudocode claims the real-to-complex inverse transform applies a `1/N` (1D) / `1/(N1*N0)` (2D) scale, matching the same pattern already found wrong for `zip`/`zop`. Runtime round trip (forward+inverse) returns `2*N` (1D) / `2*N0*N1` (2D) times the original signal - the header's forward "scale = 2" claim is accurate, but the inverse claim is not; the real implementation is unnormalized on the inverse leg too. | Documented the runtime-confirmed scaling convention (forward 2x real-to-complex convention is correct per header; inverse is NOT 1/N as claimed) and the DC/Nyquist packing into `realp[0]`/`imagp[0]` for the 1D case. `zrop`/`zrop2d` doc comments point to `zrip`/`zrip2d`'s rather than repeating it. |
| `RealDFT(T)`, `InterleavedDFT(T)` (real-to-complex mode) | Not called elsewhere in the codebase. | Runtime round trip shows an asymmetric scale: forward applies `C=2`, inverse applies `C=1` (so round trip returns `2N`x, not `N`x or `4N`x) - `vDSP.h` documents this for `RealDFT` (~L7103-7104) but `InterleavedDFT`'s real-to-complex mode has **no packing/scaling documentation at all** in the header. | Documented both functions' runtime-confirmed `C=2` forward / `C=1` inverse scaling and DC/Nyquist-in-slot-0 packing (DC to `Or[0]`/real-part-0, Nyquist to `Oi[0]`/imag-part-0), pinned down with a DC+Nyquist+k=1-sine superposed test signal whose three distinct closed-form values (16, 16, -8) can't hide a slot-swap bug. |
| `DFT(T)` (complex-to-complex zop) | Not called elsewhere in the codebase. | Confirmed via impulse forward+inverse round trip returning exactly `N`x the original - unnormalized in both directions, same family of finding as `zip`/`zop`/`zrip`. | Documented as unnormalized in both directions (previously had no doc comment at all - `dft.zig` had almost no doc comments before this pass). |
| `DCT` | Not called elsewhere in the codebase. | `vDSP.h` documents the length constraint (`f*2**n`, `f`∈{1,3,5,15}, `n`≥4) and per-type (`II`/`III`/`IV`) cosine-sum formulas, but the wrapper had no doc comment restating them. Empirically confirmed `CreateSetup` fails for `N=4` (violates the constraint). | Documented the exact per-type formulas and length constraint. |

## Verified, no behavior change

Grouped by file; ~150 functions total. Full per-function detail is in git log
(one commit per file/group); this is a representative summary of the
argument-order verification method used, not an exhaustive re-listing.

| File | Summary |
| --- | --- |
| `vecop.zig` (36/36) | `vdiv`, `zvdiv` confirmed swap-compensated; all 34 remaining functions (multiply-add/subtract-multiply combinators, unary ops, `vdist`/`distancesq`) confirmed normal argument order via header, each with a hand-computed asymmetric-input regression test. |
| `zvecop.zig` (27/27) | Complex-real mixed ops (`zrvadd`/`zrvsub`/`zrvmul`/`zrvdiv`) and accumulating spectrum functions (`zaspec`, `zcspec` - verified as `+=` not overwrite) all confirmed against header; `zvmul`'s conjugate flag polarity (`+1`=`A*B`, `-1`=`conj(A)*B`) verified with both flag values. |
| `reduction.zig` (23/23) | `sve_svesq` output order confirmed. Signed-value vs magnitude functions (`maxv` vs `maxmgv`, etc.) tested with an input where they diverge (`a=[-10,3,-2,4]`: `maxv`=4, `maxmgv`=10) so a value/magnitude mixup would be caught. `nzcros` sign-change counting verified by hand against `vDSP.h:4320-4334`. |
| `clip.zig` (12/12) | Previously had **zero** length asserts anywhere in the file; added them to match sibling files. Two notable non-obvious semantics found and pinned down with tests: `viclip` is an *inverse* clip (values outside `[lo,hi]` pass through unchanged, values inside get pushed to the boundary - opposite of what the name suggests), and `vmaxmg`/`vminmg` return the *magnitude* (always non-negative), not the original signed value. |
| `util.zig` (26/26) | See behavior-change and comment-only-correction sections above for `vswmax` and `vsorti`. `vgathr`/`vindex`'s 1-indexed/truncated table lookups, `vqint`'s edge-clamped quadratic interpolation, `vgenp`'s piecewise extrapolation, and `vpoly`'s `A[P-p]` (highest-degree-first) coefficient order all verified with hand-computed expected values. Window functions (`blkman_window`/`hamm_window`/`hann_window`) verified against their textbook *periodic* (not symmetric) formulas - an initial symmetry-based test (`w[n]==w[N-1-n]`) was wrong and caught by its own assertion before being corrected. |
| `convert.zig` (30/30) | All int/float, 24-bit, envelope, decibel, and polar/rect conversions confirmed against header. Round-toward-zero vs round-to-nearest distinguished with fractional test inputs; round-to-nearest tests deliberately avoid asserting a specific tie-breaking direction (vDSP.h says it's unspecified). |
| Priority 1/2 items (vDSP core) | `vdiv`, `zvdiv`, `vswap`, `wiener`, `FFT(T).zipt2d`/`zopt2d` (the "swapped" group); `vmul`, `vsdiv`, `vsmul`, `vdpsp`, `vspdp`, `vflt16`, `vrvrs`, `zvabs`, `zvmags`, `zvmul`, `sve_svesq`, `SplitComplex`/`ctoz`/`ztoc`, `Biquad`, `FFT` init/deinit/zip (ultrasync's 16 dependencies). See prior audit detail in git log for full evidence per function. |
| `fft.zig` remainder (21/21) | `zipt`/`zop`/`zopt`/`zrip`/`zript`/`zrop`/`zropt` (1D), `zip2d`/`zop2d`/`zrip2d`/`zript2d`/`zrop2d`/`zropt2d` (2D), `mzip`/`mzipt`/`mzop`/`mzopt`/`mzrip`/`mzript`/`mzrop`/`mzropt` (batched/multi-signal). Every C argument order checked positionally against `vDSP.h` - all correct, no swap bugs. `zrip`/`zrop` scaling documented (see comment-only-corrections table). The 2D real-transform's exact DC/Nyquist packing layout was **not** hand-derived: `vDSP.h` itself calls that layout "awkward format... due to a legacy implementation" with pseudocode that looks internally inconsistent (identical formulas for two different array positions). Per REQUEST.md's no-guessing rule, these four (`zrip2d`/`zrop2d`/`zript2d`/`zropt2d`) are verified via round-trip scaling + cross-check against `zrip2d` (whose own arg order is independently confirmed) rather than a full hand-derived closed-form - weaker evidence than the rest of this file, flagged explicitly. |
| `dft.zig` (16/16) | `DFT`/`RealDFT`/`DCT`/`InterleavedDFT` families - see comment-only-corrections table for the scaling/packing findings. `DFT(T).initShared` verified (not just documented) to produce bit-identical output to an independent setup, and that destroying a setup others share data with does not corrupt the survivor, matching `vDSP.h`'s documented guarantee. Added `std.debug.assert` length checks (debug-only, no release-mode behavior change). Found but explicitly out of scope: `src/vdsp/c.zig` declares `vDSP_DFT_Interleaved_CreateSetup`'s `RealToComplex` parameter as `c_int`, but `vDSP.h` defines `vDSP_DFT_RealtoComplex` as a `bool`-backed enum; both modes select correctly on this ABI regardless, so it's a latent type mismatch, not an observed bug - worth fixing when `c.zig` itself is in scope. |
| `fixed_fft.zig` (4/4) | `fft16_copv`/`fft32_copv`/`fft16_zopv`/`fft32_zopv` - fixed-N=16/32 legacy FFTs. Argument order (`Output, Input, Direction` / `Or, Oi, Ir, Ii, Direction`) and the `FFT_FORWARD`/`FFT_INVERSE`→`S=-1`/`S=+1` convention matched the header exactly; confirmed via cross-check against the already-verified general `FFT(f32).zip` at N=16/32 plus a hand-computed impulse test. No length asserts needed - buffer sizes are enforced by the Zig type system itself (`*[32]f32` etc.), a compile-time guarantee stronger than a runtime assert. Unlike `zip`/`zop`, this header's pseudocode makes no `1/N` scaling claim at all, so there was no doc bug to fix - round-trip is still empirically unnormalized (N x original), consistent with the rest of the FFT family, noted in a test comment rather than a doc edit since nothing in the existing doc was wrong. |

## Not yet verified

270 of 476 checklist items remain (see `fix/checklist.sh` for the live, up-to-date
breakdown by module/file/function). Not yet started:
- Priority 5: `biquad.zig` remainder (`Biquadm` family), `conv.zig`,
  `matrix.zig`, `ramp.zig`, `dotp.zig`.
- Priority 6: `vforce/root.zig` (42 functions).
- Priority 7: `vimage/` (168 functions, not used by ultrasync - REQUEST.md
  asks to check in before starting this one; it uses a different error-code
  convention and buffer alignment model than vDSP).

## Emerging patterns

- vDSP C declarations do not always retain the mathematical argument order
  (`vsub`, `vdiv`, `zvdiv`). Wrappers must absorb those ABI quirks, and tests
  for non-commutative operations must use **asymmetric** inputs - a symmetric
  test (`a == b`) cannot distinguish `a op b` from `b op a`.
- Header parameter *names* are occasionally misleading even when the actual
  ABI/behavior is correct (`vDSP_fft2d_zipt`'s reversed `__IC1`/`__IC0`
  naming). Runtime execution, not header naming, is the deciding evidence -
  per `fix/REQUEST.md`'s own ground-truth ordering.
- Header *pseudocode* can also be wrong about actual runtime behavior, not
  just parameter names: `vDSP_fft_zip`/`zop`'s documented `1/N` inverse-scale
  formula does not match the real implementation, which is unnormalized in
  both directions. Anywhere a doc comment restates vDSP.h's mathematical
  formula verbatim, treat it as a hypothesis to verify at runtime, not fact.
- Undocumented preconditions can cause **hangs**, not just wrong answers or
  crashes (`vsorti` with uninitialized `indices`). A hang is the worst of the
  three to discover in production - worth explicitly testing "what happens
  with garbage/uninitialized input" for functions that take an in/out array
  the algorithm might treat as a hint (sort indices, iterative refinement,
  etc.), not just functions that look obviously order-sensitive.
- A function's derived-length API can be unsafe even when every individual
  argument looks reasonable: `vswmax` took its output buffer's `.len` as the
  effective `N`, but the C API needs the *buffer* to be larger than `N` (for
  scratch space) - so no buffer size satisfies both "have N meaningful
  outputs" and "give the C function the scratch room it needs" under that
  API shape. Fixed by making `N` an explicit parameter, independent of
  `out.len`. Worth checking whether any other windowed/scratch-space
  functions in the unverified remainder share this pattern (vDSP.h explicitly
  distinguishes `vswsum`, which only needs `out.len == N`, from `vswmax`,
  which needs `out.len >= N+WindowLength-1` - the two look identical at a
  glance).
- Several functions were missing `std.debug.assert` length preconditions that
  sibling functions in the same file already had, in every file touched so
  far. `clip.zig` had **none** before this pass. Worth checking for on every
  function touched, not just the ones under direct investigation.
- Real-to-complex transforms use an **asymmetric forward/inverse scale**
  distinct from the complex-to-complex unnormalized-both-ways pattern:
  `zrip`/`zrip2d` and `RealDFT`/`InterleavedDFT` all apply `C=2` forward but
  `C=1` inverse (round trip = `2N`x, not `N`x or `4N`x). This is
  header-documented for `zrip` and `RealDFT`, but **not documented at all**
  for `InterleavedDFT`'s real-to-complex mode - runtime cross-check against
  the already-verified `RealDFT` was the only way to confirm it shares the
  same convention.
- Apple's own header pseudocode can be internally inconsistent, not just
  wrong relative to runtime: the 2D real FFT's DC/Nyquist packing pseudocode
  in `vDSP.h` uses identical formulas for two different array positions, and
  the header itself calls the format "awkward... due to a legacy
  implementation." Per REQUEST.md's no-guessing rule, functions in this
  situation (`zrip2d`/`zrop2d`/`zript2d`/`zropt2d`) were verified via
  round-trip scaling and cross-checks against an independently-confirmed
  sibling function rather than a full hand-derived closed-form test, and
  flagged as weaker evidence than the rest of the file rather than silently
  presented as equally solid.
- Type mismatches between a Zig extern declaration and the actual C header
  can be latent (not observably broken) rather than causing a wrong answer:
  `c.zig` declares a `vDSP_DFT_RealtoComplex`-typed parameter as `c_int`
  where `vDSP.h` defines it as a `bool`-backed enum; both selected correctly
  at runtime on this ABI, but it's still worth fixing when `c.zig` itself
  comes into scope, since ABI compatibility here is incidental, not
  guaranteed.
- Parallelizing independent files (fft.zig / dft.zig / fixed_fft.zig) across
  three worktree-isolated agents worked cleanly for priority 4: each touched
  disjoint code files plus `fix/CHECKLIST.md`, and the only merge conflicts
  were in `CHECKLIST.md` itself, which `git merge` auto-resolved correctly
  since each agent's checked-off items were non-overlapping line ranges.
