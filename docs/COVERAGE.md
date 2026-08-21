# Accelerate coverage

What this package binds, what it does not, and why. Measured on
**macOS 15.7.7 / arm64, Xcode SDK MacOSX.sdk**, by diffing every public
header in `Accelerate.framework` against the `extern` declarations in
`src/*/c.zig`, and checking each unbound name against the `.tbd` export
lists to separate real symbols from `#define` aliases.

Re-measure with the recipe at the bottom; the numbers below will drift as
Apple adds entry points.

`Accelerate.framework` is an umbrella over exactly two sub-frameworks,
`vecLib` and `vImage`, so the tables below cover the whole thing.

## Complete

| Component | Entry points | Notes |
|---|---:|---|
| **BLAS** (`cblas_new.h`) | all | ILP64 `$NEWLAPACK$ILP64` symbols, plus `thread_api.h` |
| **LAPACK** (`lapack.h`) | 2032 | every symbol bound; typed wrappers for the whole user-facing surface — see `LAPACK-PLAN.md` |
| **vDSP** (`vDSP.h`) | 470 | complete |
| **vForce** (`vForce.h`) | 84 | complete |
| **Sparse** (`Sparse/Solve.h`) | — | direct (Cholesky, LDL^T, QR, LU), iterative (CG, GMRES, LSMR), subfactors, real and complex |
| **Quadrature** | — | complete |
| **vImage** — every header | 587 | Alpha, BasicImageTypes, Conversion, Convolution, Geometry, Histogram, Morphology, Transform, Utilities, CVUtilities |
| **BNNS** (`BNNS/*.h`) | 140 | the Graph API, the standalone utilities, and the deprecated layer-filter API |

`vImage` Alpha and Geometry each still report a handful of unbound names
against the header. All of them are `#define` aliases rather than symbols:
Alpha's twelve are channel-order spellings (`..._BGRA8888` onto
`..._RGBA8888`, since the operation does not distinguish them), and
Geometry's three are the `ResamplingKernel` spellings of the
`ResamplingFilter` functions. There is nothing behind them to bind.

Two BNNS notes for anyone re-running the measurement below and finding
apparent gaps:

* Eleven graph entry points are `__asm__`-renamed. The C name
  `BNNSGraphContextExecute` resolves to the symbol
  `_BNNSGraphContextExecute_v2`, and `src/bnns/c.zig` binds the `_v2`
  spelling with `@extern`. A name-based diff will report the un-suffixed
  spelling as unbound; it is not.
* `BNNSGraphExecute` is exported by `vecLib.tbd` but declared in no header —
  it appears only inside doc comments. It is deliberately not bound, because
  there is no prototype to bind it against and a guessed signature would link
  cleanly and misbehave.

The deprecated BNNS layer-filter API (`BNNSFilterCreateLayer*`,
`BNNSFilterApply*`, and the 75 symbols around them) is bound rather than
excluded, unlike `LinearAlgebra`. Apple deprecated it in macOS 15.0 in favour
of the Graph API, but 15.0 is a recent floor to require and a caller on an
older deployment target has no Graph API to fall back on. Every one of those
declarations carries a doc comment naming the deprecating version and, where
the header gives one, the replacement — five of them were deprecated in
macOS 11.0 or 13.0 rather than 15.0.

## Not bound

### Deliberately excluded

| Component | Symbols | Why |
|---|---:|---|
| `LinearAlgebra` (`la_*`) | 47 | `API_DEPRECATED` since macOS 11; Apple's own guidance is "use BLAS and LAPACK", which this package binds in full |
| `vBasicOps.h` | 71 | AltiVec-era 128-bit integer SIMD |
| `vBigNum.h` | 69 | 256/512/1024-bit integer arithmetic |
| `vfp.h` | 47 | superseded vector floating point |
| `vectorOps.h` | 29 | superseded vector utilities |

The last four predate Zig's `@Vector`, which covers the same ground
natively, portably, and without a call across the C boundary.

`LinearAlgebra` and the deprecated BNNS filter API are both deprecated, and
they are treated differently on purpose. `la_*` has a complete, supported
replacement that this package already binds, so binding it would add a second
way to do the same thing. The BNNS filter API's replacement requires macOS
15.0, so excluding it would leave older deployment targets with nothing.

### Nothing on the roadmap

Every non-excluded entry point in both sub-frameworks is bound.

## vImage Utilities and CVUtilities — the CoreGraphics half

`vImage_Utilities.h` (17 symbols) and `vImage_CVUtilities.h` (28) are the only
part of the package that touches an object graph: `CGImageRef`,
`CVPixelBufferRef` and `CGColorSpaceRef` are CoreFoundation objects with
`CFRetain`/`CFRelease` lifetimes, where everything else here is pure C over
buffers and integers. Three decisions shape how they are bound.

**They are behind a build option, off by default.** `-Dcoregraphics=true`, or
`.coregraphics = true` in the `b.dependency` call. Linking CoreGraphics,
CoreVideo and CoreFoundation into every consumer that only wanted `vDSP` is
not a cost to impose by default. With the option off, `vimage.utilities`,
`vimage.cv`, `accelerate.cg` and `accelerate.cv` each resolve to a placeholder
namespace whose only declaration is `enabled = false` — so a program can test
for the feature, and a program that uses it anyway gets a compile error naming
the declaration it wanted rather than a link failure.

`zig build test` builds the package *twice*, once each way, so the gated code
is covered regardless of how the option is set.

**Ownership is encoded in the type, not in a naming convention.**
CoreFoundation's Create Rule — a `Create` or `Copy` function returns a +1
reference you must release, anything else returns a borrowed one you must not
— is invisible in C, where both cases are the same `CGImageRef`. Here they are
different Zig types:

* `*CGImage`, `*CGColorSpace`, `*CVPixelBuffer` — **borrowed**. Every getter
  returns this, every function that only reads takes this. No `deinit`.
* `cg.Image`, `cg.ColorSpace`, `cv.PixelBuffer`, `utilities.Converter`,
  `cv.CVImageFormat` — **owned**, +1, with `deinit()`. Every constructor
  returns this.

`Type.borrow(ptr)` retains and returns the owned form; `Type.adopt(ptr)` takes
ownership of an existing +1 without retaining, which is what the wrappers use
internally for the `Create` entry points. Reading `.ref` gives the borrowed
pointer back.

**CGImage interop is fully in scope.** `accelerate.cg` and `accelerate.cv`
bind the slice of CoreFoundation, CoreGraphics and CoreVideo needed to
actually build and inspect the objects vImage wants — colour spaces including
the parametric constructors, `CGImage` accessors, `CGBitmapInfo` as a packed
struct rather than a hand-ORed integer, `CGColorConversionInfo`, and
`CVPixelBuffer` creation, locking and plane access. They are deliberately not
a CoreGraphics binding; nothing beyond what these 45 entry points need is
there.

The payoff is `Converter.convert` (`vImageConvert_AnyToAny`), which converts
between any two formats vImage can describe — including colour-space changes
and CG-to-CV format pairs — and so subsumes a large part of the 173
hand-written entry points in the `conversion` module with one object.

## Re-measuring

```sh
SDK=$(xcrun --show-sdk-path)
FW=$SDK/System/Library/Frameworks/Accelerate.framework/Frameworks

# Every symbol this package declares.
grep -ohE 'pub extern fn [A-Za-z0-9_]+' src/*/c.zig \
  | awk '{print $NF}' | sort -u > /tmp/ours.txt

# Every function a header declares, for one header.
grep -ohE '\bvImage[A-Za-z0-9_]+\s*\(' \
  $FW/vImage.framework/Headers/Conversion.h \
  | tr -d ' (' | sort -u > /tmp/theirs.txt

comm -23 /tmp/theirs.txt /tmp/ours.txt
```

One caveat that cost real time: a name in a header is not necessarily a
symbol. Check each result against the `.tbd` before treating it as
unbound —

```sh
grep -c '_vImagePremultiplyData_BGRA8888\b' \
  $FW/vImage.framework/vImage.tbd   # 0: it is a #define
```

— and the reverse trap also exists. An `extern fn` whose *signature* is
wrong still links. `src/vimage/c.zig` and `src/bnns/c.zig` each end with a
test that forces every declaration to resolve at link time, which catches a
misspelled name but not a mistyped one.

Three classes of bug got past the link test during this work, all found only
by comparing declarations against the header by hand:

* **A struct declared at the wrong size.** `vImage_YpCbCrPixelRange` is eight
  `int32_t` (32 bytes); it was declared with `i16` fields (16 bytes), so every
  field after the first sat at the wrong offset. `vImage_YpCbCrToARGB` and
  `vImage_ARGBToYpCbCr` are each 128 bytes aligned to 16; they were declared
  as 64 bytes aligned to 4, so `GenerateConversion` wrote past the end of the
  caller's object.
* **A nullable parameter declared non-null, or the reverse.** vImage marks
  optional parameters by *omission* from `VIMAGE_NON_NULL(...)`; `bnns.h` sits
  inside `_Pragma("clang assume_nonnull begin")` and marks them with an
  explicit `_Nullable`. The two conventions are opposites, and reading one
  header with the other's habit produces silently wrong signatures in both
  directions.
* **A name that is not the symbol.** Eleven BNNS graph entry points carry an
  `__asm__("_..._v2")` clause. That one the link test does catch.

For struct layout specifically, the cheapest reliable check is to make C
answer. Compile a program that prints `sizeof` and `offsetof` for each type
against `<Accelerate/Accelerate.h>`, then assert the same numbers with
`@sizeOf` and `@offsetOf` in a Zig test:

```sh
clang -o /tmp/layout /tmp/layout.c -framework Accelerate && /tmp/layout
```

`src/bnns/types.zig` and `src/vimage/types.zig` both carry tests written that
way. The numbers in them were measured, not inferred — and a `sizeof` match
alone is not enough, since two transposed fields of the same width give the
right total size and the wrong data.

## Verifying that bound code is actually compiled

Zig only semantically analyses a declaration something references.
`std.testing.refAllDecls` forces the declarations of one namespace, one level
deep — so a `pub fn` on a struct *inside* a module is never analysed, and can
sit in the tree not compiling through a completely green test run. Two
declarations were in exactly that state when this was checked:
`vimage.utilities.Converter.tempBufferSize` and
`vimage.conversion_indexed.Dither.ordered_noise_shape_mask`.

`src/root.zig` therefore walks recursively:

```zig
fn refAllDeclsDeep(comptime T: type, comptime depth: usize) void { ... }

test {
    @setEvalBranchQuota(200_000);
    refAllDeclsDeep(@This(), 6);
}
```

The same trap catches documentation. `examples/readme.zig` holds every code
sample in `README.md` and is compiled by `zig build test` against both build
configurations — but only because it ends in a `refAllDecls` block. Without
that, `addTest` on a file of unreferenced `pub fn`s compiles nothing at all
and reports success.

## Behaviour that contradicts the headers

Measured on macOS 15.7.7 / arm64. Each is pinned by a test in the module that
binds it.

| Entry point | Header says | Actually |
|---|---|---|
| `BNNSDirectApplyTopK` | `best_indices` is `_Nullable` on macOS 13+ | passing NULL never returns; `tensor.topK` requires the descriptor |
| `BNNSNDArrayGetDataSize` | returns the data size | returns 0 for every sub-byte type (`int1/2/4`, `uint1/2/3/4/6`, `indexed*`) |
| `BNNSNearestNeighborsGetInfo` | returns the `n_neighbors` nearest | includes the query sample itself, first, at distance 0 |
| `BNNSNearestNeighborsLoad` | — | returns 0 (success) when the load overflows `max_n_samples`, and writes anyway |
| `vImageCreateCGImageFromBuffer` | produces an image in the format given | rewrites alpha-first to alpha-last and converts the pixels, so the image reports `.premultiplied_last` for a `.premultiplied_first` format. The pixels are correct; an equality check against the input format is not |
| `vImageBuffer_InitWithCGImage` | takes `vImage_CGImageFormat *` non-const | never writes to it — a null `colorSpace` decodes fine and stays null on return |
| `vImageCGImageFormat_IsEqual` | — | two NULLs compare **unequal** |
| `vImageConverter_CreateWithCGImageFormat` | `bitsPerComponent` must be 5, 8, 16 or 32 | 7 is accepted and a converter is returned |
| `vImageConverter_CreateWithColorSyncCodeFragment` | `VIMAGE_NON_NULL(1,2)`, leaving `destFormat` optional | the same function's own docs list `kvImageNullPointerArgument` for a null `destFormat`; treated as required |
| `vImageBuffer_InitForCopyToCVPixelBuffer` | — | describes a subsampled chroma plane in the **luma** geometry (16x16 for a 16x16 `420v` buffer), where `CVPixelBufferGetWidthOfPlane` reports 8x8 |
| `vImageCVImageFormat_GetAlphaHint` | non-zero means alpha is opaque | a format with no alpha channel returns 2, not 1 — so the test must be `!= 0` |
| `vImageBuffer_CopyToCVPixelBuffer` | `cvImageFormat` may be NULL | fails with `kvImageInvalidCVImageFormat` on a `CVPixelBuffer` created without colour attachments |
| `CGColorConversionInfoCreate` | — | returns NULL for a *device* colour space; both ends need defined colorimetry |
| `CGColorSpaceCreateDeviceRGB` / `...WithName` | — | return cached immortal singletons whose retain count reads `0xFFFFFFFF` and never moves |
