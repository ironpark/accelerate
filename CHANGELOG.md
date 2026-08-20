# Changelog

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
