# Accelerate binding audit

Progress: 165/476 checklist items verified (see `fix/checklist.sh` for live status).
Completed: priority 1 (8 "swapped" functions), priority 2 (16 ultrasync
dependencies), and priority 3 (vecop.zig, zvecop.zig, reduction.zig, clip.zig,
util.zig, convert.zig - 168 functions) from `fix/REQUEST.md`. Priorities 4-7
not yet started; paused here for review before priority 4 (fft.zig, dft.zig,
fixed_fft.zig), which REQUEST.md itself flags as the hardest remaining section.

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

## Not yet verified

311 of 476 checklist items remain (see `fix/checklist.sh` for the live, up-to-date
breakdown by module/file/function). Not yet started:
- Priority 4: `fft.zig` remainder (batch/multi-dimensional FFT methods beyond
  `zip`/`zop`/`zipt2d`/`zopt2d`), `dft.zig`, `fixed_fft.zig` - REQUEST.md flags
  this as the hardest section (scaling conventions, split-complex DC/Nyquist
  packing, setup lifecycle).
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
