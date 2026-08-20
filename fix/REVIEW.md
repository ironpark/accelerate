# Review of `fix/audit-accelerate-bindings-2`

> **Status: all findings resolved.** Every item below has been fixed on this
> branch; see `CHANGELOG.md` for the user-facing summary and
> `fix/API-PROPOSAL.md` for the API work. 409 tests pass in Debug, ReleaseSafe
> and ReleaseFast. Each finding carries a *Resolution* line.

Independent review of the audit described in `fix/AUDIT.md` (63 commits,
30 files, +9575/-78). Every claim below was re-checked against the macOS SDK
headers (`MacOSX15.4.sdk/.../vecLib.framework/Headers/vDSP.h`, the vendored
`reference/vforce/vForce.h`, `reference/vimage/*.h`) and, where noted, against
runtime probes written for this review rather than reusing the audit's tests.

**Overall: the audit holds up.** All 9 claimed behavior-change fixes are
correct, the evidence cited in `AUDIT.md` matches the actual header text at the
cited line numbers, and `zig build test` passes 397/397 with a clean working
tree. The findings below are gaps and follow-ups, not refutations.

---

## Independently confirmed

| Claim | How it was re-checked |
| --- | --- |
| `vsub` operand swap | `vDSP.h:2811-2818` declares `__B` then `__A` with `// Caution: A and B are swapped!`. Wrapper now passes `(b, a)` → `a - b`. Correct. |
| No swap-cautioned function was missed | Extracted **every** function in `vDSP.h` carrying a `swapped` comment: `vsub`/`vsubD`, `vdiv`/`vdivD`/`vdivi`, `zvdiv`/`zvdivD`, `vswap`/`vswapD`, `wiener`/`wienerD`, `fft2d_zipt`/`fft2d_zopt`. That is exactly priority 1's set — nothing outside it. (The two extra hits at `vDSP.h:9505`/`10125` are the deprecated, unprefixed `vsub`/`vsubD` legacy symbols, which this binding does not declare.) |
| `vdiv`/`zvdiv` already swap-compensated | `vecop.zig:82-84` and `zvecop.zig:79-80` pass `(b, a)`. Correct. |
| `vswmax` buffer contract | `vDSP.h:5698-5706`: "A must contain N+WindowLength-1 elements, and C must contain space for N+WindowLength-1 elements." New explicit `n` param + both asserts are right, and the `vswsum` contrast (`vDSP.h:6462`: only `A` needs `N+P-1`) is real, not a misreading. |
| `deq22` `[2, N+2)` offset | `vDSP.h:3956-3966`: `for (n = 2; n < N+2; ++n)  // Note outputs start with C[2].` Asserts `a.len >= n_out+2` / `out.len >= n_out+2` are correct, and the doc comment correctly identifies `out[0..2)` as *history input*, not just unwritten padding. |
| `Biquadm.copyState` `dest`/`src` | `vDSP.h:472-479`: `vDSP_biquadm_CopyState(__dest, __src)`. Fix is correct. |
| `vforce.pows` scalar exponent | `vForce.h:467-475`: "`@param y (input) Input **scalar**, exponent in calculation`", vs `vvpow`'s "`Input vector of size *n`" at `vForce.h:459`. Fix is correct. |
| `vimage/c.zig` floodFill ABI | `vImage_Types.h:286`: `typedef uint8_t Pixel_8888[4]` — a C array parameter that decays to a pointer. `*const Pixel_8888` is the ABI-correct Zig spelling. |
| `Biquadm` `interp_rate` precision | Easy place to get an ABI mismatch, and it is right: `vDSP.h:517-541` gives `SetTargetsDouble` a `float` rate but `SetTargetsDoubleD` a `double` rate; `c.zig:628-631` and the `interp_rate: T` wrapper both match. |
| No latent uncompilable decls remain | Wrote a throwaway test that forces `std.testing.refAllDecls` over `vdsp/c.zig`, `vimage/c.zig`, `vforce/c.zig`, both `types.zig` files, plus a recursive decl walk of `src/root.zig`. All compile. The `vimage/c.zig` class of bug (Zig's lazy decl resolution hiding a broken alias) is cleared repo-wide, not just where tests happened to reach. |

---

## Findings

### 1. Known ABI mismatch was documented but left unfixed — should be fixed

`src/vdsp/c.zig:588-589` declares `vDSP_DFT_Interleaved_CreateSetup`'s
`RealToComplex` parameter as `c_int`, but `vDSP.h:6904` defines it as
`vDSP_ENUM(bool, vDSP_DFT_RealtoComplex)` — a 1-byte `_Bool`, not a 4-byte
`int`. `AUDIT.md` (dft.zig row) found this and explicitly deferred it as
"out of scope … worth fixing when `c.zig` itself is in scope."

It works today only because AAPCS64 and SysV both pass the argument in a
register whose low byte the callee reads. That is incidental, not guaranteed.
Given that the branch's own headline claim is a 100%-verified binding, shipping
a knowingly-wrong extern declaration is the one place the audit's standard is
applied inconsistently. It is a one-line change.

**Resolution:** `c.zig` now declares the parameter as `bool`, and `dft.zig`'s
`RealToComplex` became a `u1`-backed enum with a `toBool()` accessor, matching
`vDSP_ENUM(bool, ...)`.

### 2. 18 strict-equality length asserts contradict the codebase's `>=` convention

219 of the 237 new asserts use `>=`; 18 use `==`, all in `biquad.zig` and
`dft.zig`:

- `biquad.zig:147, 223, 236, 258, 270, 292`
- `dft.zig:120-123, 211-214, 253-254, 323-324`

`>=` lets a caller pass an oversized backing buffer — a normal DSP pattern
(one scratch allocation reused across several transform sizes). The `==`
asserts turn that into a panic in Debug and ReleaseSafe. Since these asserts
are *new* on this branch, this is a behavior change for existing callers in
ReleaseSafe that `AUDIT.md`'s "debug-only, no release-mode behavior change"
note (dft.zig row) understates. Recommend relaxing all 18 to `>=`.

**Resolution:** all 18 relaxed to `>=`.

### 3. `Biquadm.init`'s `(sections, channels)` order was never actually distinguished by the test suite

`vDSP.h:447-451` names the two parameters only `__M` and `__N` and gives no
prose for either. Every `Biquadm` test on this branch uses 2 sections × 2
channels (symmetric — cannot tell M from N) or a single-section config. So the
argument order was carried over from the pre-audit code without evidence,
inside the very file where the audit *did* find a real argument-order bug
(`copyState`).

I probed it directly: `vDSP_biquadm_CreateSetup(coeffs, 2, 1)` with two
identical one-pole sections and one channel produced
`[1, 1, 0.75, 0.5, 0.3125]` — the two-section cascade `(n+1)·0.5ⁿ`, not the
single-pole `0.5ⁿ`. **The binding is correct** (arg 2 = sections, arg 3 =
channels), but the evidence for it did not exist until now. Add an asymmetric
(e.g. 3 sections × 2 channels) test so it stays pinned.

While probing this I also hit a new instance of the audit's own
"undocumented preconditions cause hangs" pattern: creating a 2-channel setup
and calling `vDSP_biquadm` with a 1-element pointer array spins forever at
~56% CPU rather than crashing. `apply()` takes bare `[*]const [*]const T` with
no length, so nothing in the binding prevents this. See the API proposal.

**Resolution:** added `"Biquadm init: (sections, channels) argument order,
pinned with an asymmetric 3x2 setup"` — 3 sections × 2 channels, with a
three-deep one-pole cascade on channel 0 and identity on channel 1, so a swap
changes both the response and the required buffer shape. Separately, `apply()`
now takes slices and asserts the channel count (P1-B), turning that hang into
a located panic.

### 4. Two tests encode "no observed effect" as a passing expectation

- `biquad.zig` — "Biquadm setTargetsDouble/Single: runtime-confirmed to take
  effect immediately"
- `biquad.zig` — "Biquadm setActiveFilters: passthrough, no observed effect on
  apply output"

The *doc comments* handle this well: they state plainly that no ramp and no
muting were observable and tell the reader to re-verify. The *tests* do not —
they assert the instantaneous-switch output exactly. If Apple ever implements
the interpolation these describe, or the behavior differs on another OS
version or on x86-64, these fail as false regressions on an unrelated change.
The same shape applies to `histogram.zig`'s runtime-determined expectations
(`equalization_Planar8`'s minimum not mapping to bin 0;
`endsInContrastStretch_*8` being a no-op at `percent=0`).

Suggest either asserting only the stable part (e.g. "output is finite and the
buffer was written") or marking these as platform-pinned characterization
tests so a future failure is read as "Apple changed something," not "we broke
something."

**Resolution:** these two, plus the three `histogram.zig` equivalents, now
carry a `[characterization]` comment block stating that they pin undocumented
runtime behavior and that a failure on a future macOS means "re-verify Apple,"
not "this binding regressed."

### 5. The self-flagged weak spot is correctly flagged — but worth closing

`AUDIT.md` is candid that `zrip2d`/`zrop2d`/`zript2d`/`zropt2d` are verified
only by round-trip scaling plus a cross-check against `zrip2d`, because
`vDSP.h`'s own 2D DC/Nyquist packing pseudocode is internally inconsistent and
the header calls the format "awkward … due to a legacy implementation." That
judgment is right, and flagging it beats a fabricated closed-form.

It does mean a packing-layout bug in the 2D real path would survive the audit.
Closing it is cheap: a naive O(N²) reference DFT in plain Zig at 8×8 costs
nothing at test time and pins the layout exactly.

**Resolution:** two tests added, and the second turned out more informative
than expected. `"zop2d matches an independent naive 2D DFT"` checks the
complex 2D path against a closed-form O(N²) DFT written in plain Zig at a
non-square 4×8 size — the first 2D check in the file that does not compare
vDSP against vDSP. For the real 2D path, rather than hand-derive a layout from
self-contradicting pseudocode, `"zrip2d DC/Nyquist packing"` drives the
function with six basis images whose spectra have exactly one nonzero
coefficient and asserts *which slot* receives it, requiring every other slot
to be zero. The layout is now pinned: the row dimension folds DC/Nyquist into
row 0's real/imaginary parts (the 1D `zrip` convention), while the column
dimension puts DC at col 0 and Nyquist at **col 1** — not col N1/2, which is
what a naive reading of the header would predict. That surprise is exactly the
"awkward legacy format" the header warns about, and it is now a test rather
than an unknown.

### 6. Breaking changes are unversioned and unannounced

`build.zig.zon` is still `.version = "0.0.0"` and there is no CHANGELOG.
Six public APIs changed:

| API | Failure mode for an existing caller |
| --- | --- |
| `vdsp.vsub` | **Silent.** Sign flips. |
| `Biquadm.copyState` | **Silent.** Copy direction reverses. |
| `vdsp.vswmax` | Compile error (new `n` param) |
| `vdsp.deq22` | Compile error (new `n_out` param) |
| `vforce.pows` | Compile error (`[]const T` → `T`) |
| `zdotpr`/`zidotpr`/`zrdotpr` | Compile error (`SC(T)` → `Complex(T)`) |

The four compile errors are fine — they are exactly the loud failure you want.
The two silent ones are not. `vsub` in particular was wrong for the library's
entire history, so any downstream user who noticed and compensated at the call
site now gets sign-flipped results with no diagnostic. Recommend a CHANGELOG
that names those two specifically, and a version bump.

**Resolution:** `CHANGELOG.md` added, opening with a "Silent behavior changes
- read these" section covering exactly `vsub` and `Biquadm.copyState`, and
explicitly telling anyone who compensated for the old `vsub` to remove that
compensation. `build.zig.zon` bumped to `0.1.0`. A third silent-risk case
surfaced while implementing the API changes and is flagged there too:
`vforce.pow`'s two slice arguments have the same type, so its reordering will
not always produce a compile error either.

### 7. Minor

- `clip.zig:31` — `vcmprs` is the one function in the file that can genuinely
  overflow its output (the write count is data-dependent on `gate`), and it is
  the one with no `out.len` assert. The inline comment explains why correctly,
  but the reasoning lives in a `//` comment rather than the `///` doc comment,
  so callers reading generated docs never see it. Move it up, and state the
  safe upper bound (`out.len >= a.len`).
  **Resolution:** moved into the `///` doc comment as a CAUTION, stating the
  `out.len >= a.len` upper bound and why this is the one buffer in the file
  with no assert.
- `vforce/root.zig` — `pows` builds a mutable `var exp_var` only to take its
  address; `@ptrCast(&exponent)` on the parameter directly is equivalent and
  removes the copy.
  **Resolution:** done.
