# Accelerate binding audit

## Behavior changes

| Function | Downstream impact | Evidence | Change |
| --- | --- | --- | --- |
| `vdsp.vsub` | Not used by the supplied ultrasync call list | macOS SDK `vDSP.h`, `vDSP_vsub` / `vDSP_vsubD`: both declare `B` before `A` and explicitly warn that the names are swapped | The wrapper now passes `b` then `a`, so `vsub(a, b, out)` computes `a - b` as documented. The `vsub preserves Zig argument order` regression test uses asymmetric negative/zero inputs and an in-place call. |

## Verified, no behavior change

| Function | Evidence |
| --- | --- |
| `vdsp.vswap` | macOS SDK `vDSP.h` declares `vDSP_vswap` and `vDSP_vswapD` in the same A/stride/B/stride order; `vswap swaps both precisions` checks asymmetric values for f32 and f64. Added the missing `b.len >= a.len` precondition assertion. |
| `vdsp.vdiv` | macOS SDK `vDSP.h` explicitly declares B before A for `vDSP_vdiv`, `vDSP_vdivD`, and `vDSP_vdivi`; the existing wrapper compensates. `vdiv preserves Zig argument order` verifies f32/f64 asymmetric signed values with division-appropriate relative tolerances. |

## Comment-only corrections

_None yet._

## Not yet verified

All public APIs other than `vdsp.vsub` remain unverified at this point. This is deliberate: a checklist check means header/runtime evidence and test coverage, not a cursory source review.

## Emerging patterns

- vDSP C declarations do not always retain the mathematical argument order. Wrappers must absorb those ABI quirks, and tests for non-commutative operations must use asymmetric inputs.
