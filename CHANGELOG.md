# Changelog

## 0.1.0

First release after a full audit of the binding surface against the macOS SDK
headers (`vDSP.h`, `vForce.h`, `vImage/*.h`), documented in `fix/AUDIT.md`,
reviewed in `fix/REVIEW.md`, with the API changes motivated in
`fix/API-PROPOSAL.md`. 409 tests, all passing.

Everything below is a breaking change from `0.0.0`. Most break loudly — the
compiler rejects the old call. **Read the "silent" section first**: two fixes
change results without changing types, so existing code keeps compiling and
starts behaving differently.

### Silent behavior changes — read these

These two do **not** produce a compile error. If you are upgrading, audit your
call sites by hand.

- **`vdsp.vsub` now computes `a - b`.** It previously computed `b - a`.
  `vDSP.h:2811-2818` declares `vDSP_vsub`'s parameters as `__B` then `__A`
  with the comment `// Caution: A and B are swapped!`; the old wrapper passed
  its arguments through positionally and so returned the negation of what its
  own name and doc comment promised. The result is now sign-correct.

  If you compensated for the old behavior — by swapping your arguments, or by
  negating the result — **remove that compensation**, or your results will now
  be sign-flipped. This was wrong for the library's entire history, so
  compensating was a reasonable thing to have done.

- **`Biquadm(T).copyState` now copies in the direction its name implies.**
  `a.copyState(b)` makes `a` adopt `b`'s delay state. It previously did the
  reverse, overwriting the *argument* with the *receiver*'s state
  (`vDSP.h:472-479` declares `__dest` first; the binding passed `src` into the
  `__dest` slot).

### Fixed

- `vdsp.vswmax` wrote past the end of a correctly-sized output buffer on every
  call. `vDSP.h:5698-5706` requires both `A` and `C` to hold
  `N + WindowLength - 1` elements even though only `N` are meaningful output;
  the old wrapper derived `N` from `out.len`, so no buffer size could satisfy
  both requirements. `N` is now an explicit parameter. **Signature change.**
- `vdsp.deq22` wrote 2 elements past the end of `out` on every call, and never
  filled `out[0]`/`out[1]`. `vDSP.h:3956-3966` writes outputs at indices
  `[2, N+2)` and reads `out[0..2)` as filter history. `n_out` is now an
  explicit parameter, with a doc comment explaining the offset convention.
  **Signature change.**
- `vdsp.zdotpr`, `zidotpr`, `zrdotpr` passed an uninitialized `SplitComplex`
  into the C function, which then wrote through its garbage pointers. This
  hung indefinitely rather than crashing. They now return `Complex(T)` (a
  plain value struct) with real backing storage. **Return type change.**
- `vforce.pows` took its exponent as `[]const T`, mirroring `pow`'s
  per-element exponent slice — but `vvpows` reads only element 0
  (`vForce.h:467-475`: "Input **scalar**"). All data past index 0 was silently
  discarded. It is now a scalar `T`. **Signature change.**
- `src/vimage/c.zig` had six self-referencing type aliases
  (`pub const vImage_Buffer = vImage_Buffer;`) and two externs taking a C
  array type by value. The whole vImage module was uncompilable the moment
  anything forced those decls to resolve; Zig's lazy declaration resolution
  had hidden it since the module was first added.
- `src/vdsp/c.zig` declared `vDSP_DFT_Interleaved_CreateSetup`'s
  `RealToComplex` parameter as `c_int`, where `vDSP.h:6904` defines it as a
  `bool`-backed enum. Correct in practice on AAPCS64/SysV only by accident.

### Added

- **`vdsp.SplitSlice(T)`** — a split-complex buffer pair that carries its own
  length. `SplitComplex(T)` is two raw pointers, so the `n` parameter beside
  it could never be validated; the complex surface (~37 functions across
  `zvecop`, `matrix`, `dotp`, `conv`, `fft`) had no bounds checking at all.
  Every one of those wrappers now takes `SplitSlice(T)` and asserts `n`
  against the real buffer lengths. `n` is still an explicit parameter, because
  operating on a prefix of a larger scratch buffer is normal DSP practice.
  **Breaking:** pass `SplitSlice(T).init(re, im)` instead of
  `&SplitComplex(T){ ... }`; use `.raw()` if you need the C-ABI struct.
- **`vimage.VImageError` and `vimage.check`** — vImage wrappers now return
  `VImageError!usize` instead of a raw `vImage_Error` that was silent to
  ignore. The success test is `>= 0`, not `== 0`: with
  `Flags.kvImageGetTempBufferSize` set, vImage returns the required buffer
  size through the same return slot, and an `== 0` check would misreport that
  as failure. The `usize` payload is 0 for an ordinary call, or that size for
  a size query. **Breaking:** `try` the call; `_ = try f(...)` to discard.
- **`vimage.Options`** — a `packed struct(u32)` for vImage flags, so
  `Options.of(.{ .edge_extend = true })` replaces raw integer arithmetic and
  an undefined bit is a compile error. The `Flags.kvImage*` constants remain
  for direct header correspondence.
- **`vimage.Connectivity`** — `.four` / `.eight` instead of a bare `c_int` on
  the `floodFill_*` functions.
- **`vdsp.vsortiAssumeSeeded`** — see the `vsorti` change below.
- **`FFT(T).roundTripScale()`, `.realForwardScale()`, `.realRoundTripScale()`**
  — the audit's scaling findings as callable, test-checked code rather than
  prose. vDSP FFTs are unnormalized in both directions (vDSP.h's pseudocode
  claims a 1/N inverse scale that the implementation does not apply), and the
  real-to-complex family scales by 2 on the forward leg only, so a real round
  trip returns `2N`x.
- **`vdsp.inverseClip`, `.maxMagnitude`, `.minMagnitude`** — aliases for
  `viclip`, `vmaxmg`, `vminmg`, whose vDSP names read as the opposite of (or
  vaguer than) what they do. `viclip` passes values *outside* the range
  through unchanged and pushes values *inside* it out to the boundary.

### Changed

- **`vdsp.vsorti` now seeds `indices` with the identity permutation itself.**
  vDSP_vsorti requires that on entry, a precondition documented nowhere in
  `vDSP.h`; violating it hangs indefinitely. Use `vsortiAssumeSeeded` to skip
  the O(N) seed if you have already done it.
- **`vdsp.vswsum` gained an explicit `n` parameter** so it and `vswmax` share
  one signature. Their buffer requirements genuinely differ and the asserts
  now carry that difference instead of the signatures doing it implicitly.
  **Signature change.**
- **`Biquadm(T).apply` takes slices** (`[]const [*]const T`) instead of bare
  multi-pointers, and asserts the channel count against the setup. Passing
  too few channel pointers previously hung. Most call sites compile unchanged.
- **`vforce.pow` and `vforce.pows` take `(base, exponent)`.** `pow` previously
  took `(exponent, base)`, mirroring vForce's C parameter order. The binding
  already reorders arguments to match its own names elsewhere (`vsub`,
  `vdiv`); doing it in one place and not another was the worst of both.
  **Signature change; `pow`'s two slice arguments have the same type, so this
  will not always produce a compile error — check your `pow` call sites.**
- Length preconditions in `biquad.zig` and `dft.zig` relaxed from `==` to
  `>=`, matching the other 219 asserts in the codebase. Passing an oversized
  backing buffer is legal again.

### Notes

- `vdsp.Length` is already `usize` and `vimage.vImagePixelCount` is already
  `usize`, so no `@intCast` is needed at API boundaries.
- Tests that pin undocumented, runtime-determined framework behavior are
  marked `[characterization]` in a comment. If one fails on a future macOS,
  that is the intended signal to re-verify Apple's behavior — not evidence
  that this binding regressed.
