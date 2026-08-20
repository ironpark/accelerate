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
| **vImage** Alpha, Convolution, Geometry, Histogram, Morphology, Transform, BasicImageTypes | — | see the one exception below |

`vImage` Alpha and Geometry each still report a handful of unbound names
against the header. All of them are `#define` aliases rather than symbols:
Alpha's twelve are channel-order spellings (`..._BGRA8888` onto
`..._RGBA8888`, since the operation does not distinguish them), and
Geometry's three are the `ResamplingKernel` spellings of the
`ResamplingFilter` functions. There is nothing behind them to bind.

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

### Roadmap

Three areas remain, in the order they are worth doing.

#### 1. vImage Conversion — 172 entry points

`Conversion.h` is 263 entry points and 91 are bound: the RGB/greyscale
format pairs, the lookup tables, `vImageBufferFill`, `vImageCopyBuffer`
and the 8-bit/float/16-bit conversions most callers reach for. What is
left, grouped:

| Group | Count | What it is |
|---|---:|---|
| Packed pixel (1555 / 5551 / 565 / 2101010) | 39 | conversions to and from bit-packed 16- and 32-bit pixels |
| YCbCr / video | 37 | 420, 422 and 444 chroma-subsampled planar and interleaved formats, plus the `GenerateConversion` matrix builders |
| Other format pairs | 35 | remaining N-to-M combinations across the 8/16U/16S/F types |
| 16Q12 fixed-point | 22 | the signed 4.12 fixed-point format |
| Indexed / sub-byte planar | 12 | 1-, 2- and 4-bit-per-pixel planar, and indexed colour |
| Fill / overwrite variants | 7 | `vImageBufferFill_*`, `vImageOverwriteChannelsWithScalar_*` |
| Dithered narrowing | 6 | `..._dithered` variants that trade banding for noise |
| Flatten | 6 | composite a premultiplied image onto an opaque background |
| Chunky ↔ planar | 4 | de-interleave and re-interleave arbitrary channel counts |
| Channel permute variants | 4 | `vImagePermuteChannelsWithMaskedInsert_*` |

This is mechanical but large, and much of it is only useful inside a video
pipeline. The sensible increment is by group rather than all at once —
Flatten, chunky/planar and the fill/overwrite variants are small and
generally useful; the YCbCr set is the one to leave for a caller who
actually needs it.

There is also one straggler in `BasicImageTypes.h`:
`vImagePNGDecompressionFilter`, which applies the PNG un-filter step to a
scanline.

#### 2. vImage Utilities and CVUtilities — 47 entry points

`vImage_Utilities.h` (17) is the `vImageConverter` machinery:
`vImageConvert_AnyToAny`, `vImageConverter_CreateWithCGImageFormat`,
`vImageBuffer_InitWithCGImage`, `vImageCreateCGImageFromBuffer`.
`vImage_CVUtilities.h` (30) is the CoreVideo half: `vImageCVImageFormat_*`
and the `CVPixelBuffer` ↔ `vImage_Buffer` bridges.

These are not more of the same. `AnyToAny` is arguably the most useful
single function in vImage — it converts between *any* two formats it can
describe, which subsumes a large part of the Conversion table above — but
reaching it means depending on CoreGraphics and CoreVideo, which are
Objective-C frameworks with `CFRetain`/`CFRelease` lifetimes and
`CGColorSpace` objects. That is a different kind of binding from the rest
of this package, which is pure C with no object graph, and it needs a
decision about scope before any of it is written:

* Does the package link CoreGraphics and CoreVideo unconditionally, or
  behind a build option?
* Do the `Ref` types get Zig wrappers with `deinit`, or stay opaque?
* Is `CGImage` interop in scope at all, or only the format descriptors?

Worth answering before starting, not during.

#### 3. BNNS — ~148 entry points

`vecLib/BNNS/` is neural-network inference: layer construction, graph
compilation and execution, plus the `bnns_graph.h` runtime. It is a
self-contained subsystem the size of a project rather than a module, with
its own object lifetimes and its own tensor descriptors, and it shares
nothing with the numerical code here. Apple has also been steering new
work toward Core ML and MPSGraph.

Not planned. If it happens it should probably be a separate package that
depends on this one.

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

— and note that the reverse trap exists too. An `extern fn` whose
signature is wrong still links; only its arity and types checked against
the header will catch that. `src/vimage/c.zig` has a test that forces
every declaration to resolve at link time, which catches misspelled names
but not mistyped ones.
