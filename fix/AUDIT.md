# Accelerate binding audit

Progress: 29/476 checklist items verified (see `fix/checklist.sh` for live status).
Completed: priority 1 (8 "swapped" functions) and priority 2 (16 ultrasync
dependencies) from `fix/REQUEST.md`. Priorities 3-7 not yet started.

## Behavior changes

| Function | Downstream impact | Evidence | Change |
| --- | --- | --- | --- |
| `vdsp.vsub` | Not used by the current ultrasync call list, so no downstream compensation is at risk | macOS SDK `vDSP.h:2811-2828`: `vDSP_vsub`/`vDSP_vsubD` declare `__B` before `__A` and explicitly warn "Caution: A and B are swapped!" | The wrapper now passes `b` then `a` into the C call, so `vsub(a, b, out)` computes `a - b` as its name and doc comment promise. Regression test uses asymmetric inputs (`a=[1,2,3]`, `b=[10,20,30]`) for both f32 and f64. |

## Comment-only corrections

| Function | Evidence | Change |
| --- | --- | --- |
| `FFT(T).zip`, `FFT(T).zop` | `vDSP.h`'s pseudocode claims inverse transforms apply a `1/N` scale ("scale = 0 < Direction ? 1 : 1./N"). Running an impulse through `FFT(f32).zip` forward then inverse (N=4) produced `4x` the original signal, not the original signal - the real (hardware-accelerated) implementation is unnormalized in **both** directions. Matches `fix/REQUEST.md`'s own note that vDSP FFTs are unnormalized. | Removed the incorrect scale line from both doc comments and documented the actual unnormalized behavior, backed by a new round-trip test in `fft.zig`. Any caller who trusted the old comment's claim of automatic 1/N scaling on inverse was already getting numerically wrong results before this fix - the *code* was correct, the *docs* were not. |

## Verified, no behavior change

| Function(s) | Evidence |
| --- | --- |
| `vdiv` (f32/f64/i32) | `vDSP.h:2903-2919` declares `__B` before `__A`; wrapper already compensates. Asymmetric runtime tests added for all three types. |
| `zvdiv` | `vDSP.h:2929-2937` same swap pattern for complex-split; wrapper already compensates. Asymmetric complex test added. |
| `vswap`/`vswapD` | Swap is order-independent by definition (`A[n]` and `B[n]` exchange regardless of call order) - no bug possible. Added a missing `b.len >= a.len` assert and a round-trip test. |
| `wiener`/`wienerD` | `vDSP.h:6655-6671` (`L, A, C, F, P, Flag, Error`) is not flagged "swapped" and matches the wrapper's parameter order. Order-1 normal-equations test (`filter[0] = C[0]/A[0]`) confirms `A` and `C` are wired to the correct slots. |
| `FFT(T).zipt2d` (float `vDSP_fft2d_zipt`) | `vDSP.h:1107-1116` names the 3rd/4th parameters `__IC1, __IC0` - reversed from `vDSP_fft2d_zip`/`vDSP_fft2d_ziptD`'s `__IC0, __IC1`. A runtime test with asymmetric N0=4/N1=8 and non-trivial stride shows `zip2d` and `zipt2d` produce identical results, so this is a header documentation quirk, not a real ABI reversal. `vDSP_fft2d_zoptD` (the other function REQUEST.md flagged as unverified) turned out to have normal, non-reversed parameter order all along; a `zop2d`/`zopt2d` cross-check test confirms no sibling issue. |
| `vmul`, `vsdiv`, `vsmul` | `vDSP.h` confirms normal (A, B) order for all three - not in the swapped set. Asymmetric tests added. |
| `vdpsp`, `vspdp`, `vflt16` | Single-input conversions, no argument-order risk. Added missing `out.len >= a.len` asserts (previously absent) and tests. |
| `vrvrs` | Single-buffer in-place reverse, no argument order possible. Tests for normal and length-1 cases. |
| `zvabs`, `zvmags` | Single-input complex magnitude ops, no order risk. Tests added. |
| `zvmul` | `vDSP.h:3219-3251` confirms `Conjugate=+1` means `A*B`, `Conjugate=-1` means `conj(A)*B`; wrapper's `if (conjugate) -1 else 1` matches. Test exercises both flag values with asymmetric complex operands. |
| `sve_svesq` | `vDSP.h:4513-4533` confirms `(Sum, SumOfSquares)` output order matches the wrapper's `(sum, sum_sq)`. Test uses inputs with distinct sum/sum_sq. |
| `SplitComplex`, `ctoz`, `ztoc` | `vDSP.h:626-679` order confirmed. A round-trip test (interleaved → split → interleaved) with distinct per-element values also validates `SplitComplex`'s `extern struct { realp, imagp }` layout is ABI-compatible with `DSPSplitComplex`. |
| `Biquad` (`init`/`deinit`/`apply`) | `vDSP.h:2189-2246`: argument order `(Setup, Delay, X, IX, Y, IY, N)` matches; delay buffer size `(sections+1)*2` matches the header's requirement of 2 slots per section for `s` in `0..=S`. Identity-filter test and a one-pole IIR test (hand-computable geometric-decay ground truth) both pass. |
| `FFT` (`init`/`deinit`/`zip`) | `vDSP.h:367-373, 685-691` order confirmed. Round-trip test (see comment-only correction above for the normalization finding). |

## Not yet verified

447 of 476 checklist items remain (see `fix/checklist.sh` for the live, up-to-date
breakdown by module/file/function). Not yet started: `vdsp/vecop.zig` remainder,
`zvecop.zig` remainder, `reduction.zig` remainder, `clip.zig`, `util.zig` remainder,
`convert.zig` remainder (priority 3); `fft.zig` remainder, `dft.zig`,
`fixed_fft.zig` (priority 4); `biquad.zig` remainder, `conv.zig`, `matrix.zig`,
`ramp.zig`, `dotp.zig` (priority 5); `vforce/root.zig` (priority 6); `vimage/`
(priority 7, 168 functions - REQUEST.md asks to check in before starting this one).

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
- Several functions were missing `std.debug.assert` length preconditions that
  sibling functions in the same file already had (`vswap`, `vdpsp`, `vspdp`,
  `vflt16`). Worth checking for on every function touched, not just the ones
  under direct investigation.
