# API improvement proposals

> **Status: all implemented** on `fix/audit-accelerate-bindings-2`. See
> `CHANGELOG.md` for the migration-facing version. Each item carries an
> *Implemented* line recording what shipped and where it diverged from the
> proposal. 409 tests pass in Debug, ReleaseSafe and ReleaseFast.

Follow-up to `fix/AUDIT.md` and `fix/REVIEW.md`. The audit fixed nine *bugs*;
this document proposes changes to the *API shape* that would have made several
of those bugs unrepresentable rather than merely fixed.

The audit's own "emerging patterns" section already names the root cause
repeatedly: *an API surface that looks safe by its type but isn't, because the
actual C contract needs verifying rather than inferring.* Each proposal below
targets one instance of that.

Ordered by value-per-unit-of-churn. P1 items are non-breaking or nearly so.

---

## P1-A. Give `SplitComplex` a length-carrying sibling

**Problem.** `SplitComplex(T)` is `{ realp: [*]T, imagp: [*]T }` — two raw
pointers, no length. So every complex function takes `n: Length` as a separate
argument that nothing can validate:

```zig
pub fn zvmul(comptime T: type, a: *const SC(T), b: *const SC(T), out: *const SC(T), n: Length, conj: i32) void
```

`AUDIT.md` explicitly declined to add length asserts to all `SC(T)`-taking
functions "since there's no embedded length to check against" (matrix.zig row).
That is a correct read of the current type — and it means ~60 public functions
across `zvecop.zig`, `matrix.zig`, `dotp.zig`, `fft.zig`, and `conv.zig` have
**zero** buffer-size checking, in the module where the audit's two confirmed
hangs both occurred.

**Proposal.** Keep `SplitComplex` exactly as-is for the C boundary, and add a
safe slice-based type callers actually hold:

```zig
pub fn SplitSlice(comptime T: type) type {
    return struct {
        realp: []T,
        imagp: []T,

        pub fn len(self: @This()) usize {
            std.debug.assert(self.realp.len == self.imagp.len);
            return self.realp.len;
        }

        /// Raw C-ABI view. Lifetime is the caller's slices.
        pub fn raw(self: @This()) SplitComplex(T) {
            return .{ .realp = self.realp.ptr, .imagp = self.imagp.ptr };
        }
    };
}
```

Public wrappers take `SplitSlice(T)`, assert against `.len()`, and drop the
separate `n` parameter where it is redundant. This retro-fits the entire
complex surface with the same length checking the real-valued surface already
got, and removes the `n`-doesn't-match-the-buffers class of bug outright.

**Cost.** Breaking for `SC(T)`-taking functions, but mechanical, and every
break is a compile error. Can be staged: add `SplitSlice`, add `z*` overloads,
deprecate the raw ones.

## P1-B. `Biquadm.apply` should take slices, not bare multi-pointers

**Problem.**

```zig
pub fn apply(self: Self, input: [*]const [*]const T, output: [*]const [*]T, n: Length) void
```

Nothing ties the pointer-array length to `self.channels`. Passing too few
channel pointers does not crash — it **hangs** (confirmed while reviewing;
see `fix/REVIEW.md` §3), which is the worst of the three failure modes and the
one this audit kept rediscovering.

**Proposal.**

```zig
pub fn apply(self: Self, input: []const [*]const T, output: []const [*]T, n: Length) void {
    std.debug.assert(input.len == self.channels);
    std.debug.assert(output.len == self.channels);
    ...
}
```

`self.channels` is already stored. Call sites change from `&ins` to `&ins`
(slice coercion from `*const [N]T` is automatic) — in practice most existing
call sites compile unchanged. Highest value-per-line in this document.

## P1-C. Make `vsorti` safe by construction

**Problem.** `vsorti` hangs forever if `indices` is not pre-seeded with the
identity permutation `0..N-1`. This precondition appears nowhere in `vDSP.h`.
The audit's fix was a `CAUTION` doc comment — correct as far as it goes, but it
leaves a documented-only landmine in a library whose entire premise is
absorbing vDSP's quirks on the caller's behalf.

**Proposal.** Seed it in the wrapper:

```zig
pub fn vsorti(comptime T: type, data: []const T, indices: []Length, order: SortOrder) void {
    std.debug.assert(indices.len >= data.len);
    for (indices[0..data.len], 0..) |*ix, i| ix.* = i;   // required by vDSP_vsorti; see doc comment
    ...
}
```

This is precisely what the binding already does for `vsub` — absorb an ABI
quirk so the Zig-level name means what it says. Callers who want to reuse a
pre-seeded array can be offered `vsortiAssumeSeeded`. The `O(n)` seed is
negligible next to the sort.

## P1-D. Unify the windowed/scratch-buffer convention

`vswmax` now takes an explicit `n`; its near-identical sibling `vswsum` still
derives `N` from `out.len`. The audit correctly identified that the two have
genuinely different C contracts — but the resulting Zig API gives two
same-shaped operations two different signatures, which is exactly the
"same-shaped-signature sibling" trap the audit flagged for `pow`/`pows`.

**Proposal.** Give both an explicit `n`, and have `vswsum` assert
`out.len >= n` while `vswmax` asserts `out.len >= n + window_len - 1`. The
signatures then match and the *asserts* carry the difference, where it belongs.
`AUDIT.md`'s own emerging-patterns note asks for a sweep of "any other
windowed/scratch-space functions" — this is that sweep's landing place.

---

## P2-A. Real error handling for vImage

**Problem.** All ~170 vImage wrappers return `vImage_Error` (an `isize`) that
the caller must remember to compare against `Error.kvImageNoError`. Ignoring
the return value is silent and legal. Every test on this branch has to write
`try std.testing.expectEqual(@as(vImage_Error, 0), err)` by hand.

**Proposal.** A Zig error set plus a `check` helper:

```zig
pub const VImageError = error{
    RoiLargerThanInputBuffer, InvalidKernelSize, /* ... */ CoreVideoIsAbsent, Unknown,
};

pub fn check(e: vImage_Error) VImageError!usize {
    if (e >= 0) return @intCast(e);   // >= 0, not == 0: kvImageGetTempBufferSize
    return switch (e) { ... };        //                 returns a size in the same slot
}
```

Note the `>= 0` detail: with `Flags.kvImageGetTempBufferSize` set, vImage
returns the required buffer size as a **positive** value through the same
return slot. An `== 0`-based error check silently misreports that as failure —
worth encoding once in a helper instead of at 170 call sites.

Wrappers become `!void` (or `!usize`), so a dropped error is a compile error.

## P2-B. Enums instead of `c_int` / raw bitfields

- `floodFill_*(..., connectivity: c_int, ...)` — only 4 and 8 are valid.
  → `Connectivity = enum(c_int) { four = 4, eight = 8 }`
- `vImage_Flags = u32` with a `Flags` namespace of constants → a `packed
  struct(u32)` so flags compose with `.{ .high_quality_resampling = true }`
  and an invalid bit cannot be set.
- `vDSP_DFT_Interleaved_CreateSetup`'s `RealToComplex` → the `bool`-backed enum
  the header actually declares (also a correctness fix; see `fix/REVIEW.md` §1).

## P2-C. `pow`'s argument order

`vforce.pow(exp_vec, base, out)` mirrors the C parameter order (`z, y, x`)
rather than the mathematical one. The audit corrected the doc comment to match
the code — but the branch's flagship decision was the opposite move for `vsub`:
*reorder the wrapper so the Zig-level name means what it says, and absorb the C
quirk internally.* Applying that principle to `vsub` but not `pow` is worse
than applying it consistently in either direction.

**Proposal.** `pow(base, exponent, out)`, matching the now-fixed
`pows(exponent, base, out)`'s… actually, matching `pows` argues for
`pows(base, exponent, out)` too. Pick one order and make all four
(`pow`, `pows`, and the `f64` paths) obey it. Breaking, but a compile error
only where the two slices have different lengths — so it warrants a loud
CHANGELOG entry rather than a silent rename.

## P2-D. Accept `usize`, convert to `Length` internally

Public signatures take `n: Length` (`c_ulong`) while every adjacent slice uses
`usize`. Callers write `@intCast` at the boundary. Since the values are always
buffer-derived, taking `usize` and converting inside the wrapper removes that
noise with no loss of expressiveness.

---

## P3. Documentation-level

- **Name the surprising semantics.** `viclip` is an *inverse* clip (values
  *outside* the range pass through); `vmaxmg`/`vminmg` return a magnitude, not
  the signed value. Both are documented now. Consider additionally exporting
  intention-revealing aliases (`inverseClip`, `maxMagnitude`) alongside the
  vDSP names, so the surprising behavior is visible at the call site and not
  only in the docs the caller may not open.
- **Publish the FFT scaling conventions as code, not prose.** The audit
  established that complex transforms are unnormalized both ways while
  real-to-complex is `2×` forward / `1×` inverse. That is exactly the kind of
  fact that decays in a doc comment. A `FFT(T).roundTripScale(n)` /
  `RealDFT(T).forwardScale()` helper makes it checkable and reusable.
- **CHANGELOG + version bump.** See `fix/REVIEW.md` §6 — `vsub` and
  `Biquadm.copyState` change behavior *silently* for existing callers, and
  `build.zig.zon` is still at `0.0.0`.


---

## What shipped, and where it diverged from the proposal

Three items landed differently than proposed. Recording why, since the
reasoning is the part worth keeping:

**P1-A — `n` was kept, not dropped.** The proposal said to "drop redundant `n`
parameters" once `SplitSlice` carried the lengths. Implementing it made clear
that would be a downgrade: operating on a prefix of a larger scratch buffer is
routine in DSP code, and deriving `n` from the slice would have made that
impossible to express. The goal was never to remove `n` — it was to make `n`
*checkable*. So every wrapper still takes `n` and now asserts it against the
real buffer lengths. ~37 functions across `zvecop`, `matrix`, `dotp`, `conv`
and the 20 `FFT` methods went from zero bounds checking to full checking.

For the `FFT` methods the assert bound is derived from the wrapper's own
hardcoded strides plus the stored `log2n`, so it is exact rather than a guess:
`N` for 1D complex, `N/2` for 1D real, `(n0-1)*ic0 + n1` for the 2D forms, and
`(m-1)*stride + N` for the batched ones. The four 2D **real** transforms
deliberately get no length assert — their packing is the one layout this
codebase could not pin from the header, and a guessed assert that is too
strict would panic on correct caller code, which is worse than no assert.
(The new packing characterization test now pins that layout empirically, so a
future pass can tighten this.)

Getting the buffer bounds exact mattered: the first implementation asserted
`m * N` for the batched temp buffers and broke four passing tests, because
`vDSP.h:1721` specifies `N`, not `m * N`. The header distinguishes four
different temp-buffer rules across the FFT family (`min(16 KB, N)`, exactly
`N/2`, `min(16 KB, N1*N0)`, and `max(N1, N0/2)`); each is now encoded at the
method that needs it.

**P2-A — `!usize`, not `!void`.** The proposal sketched `!void`. That would
have silently broken `Flags.kvImageGetTempBufferSize`, which returns the
required buffer size *through the same return slot* as the error code. The
shipped signature is `VImageError!usize`, where the payload is 0 for an
ordinary call and the buffer size for a size query — so the `>= 0` success
test the proposal called out is not just a note in `check`, it is load-bearing
on the return type. Cost: callers write `_ = try f(...)` to discard.

**P2-D — already satisfied, no change made.** The proposal asked for `usize`
public parameters instead of `Length`. `vdsp.Length` is *already* `usize` and
`vimage.vImagePixelCount` is *already* `usize`; a grep confirmed no `@intCast`
at any public API boundary. The proposal was wrong that a problem existed, so
nothing was changed. Noted here rather than quietly dropped.

Everything else shipped as described: `SplitSlice(T)`, slice-based
`Biquadm.apply` with a channel-count assert, self-seeding `vsorti` (plus
`vsortiAssumeSeeded`), unified `vswsum`/`vswmax` signatures, `VImageError` +
`check`, `Options` as a `packed struct(u32)`, `Connectivity`, consistent
`(base, exponent)` order for `pow`/`pows`, the `inverseClip`/`maxMagnitude`/
`minMagnitude` aliases, the `FFT` scaling helpers, and `CHANGELOG.md` with a
version bump to `0.1.0`.
