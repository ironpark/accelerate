# accelerate

Zig bindings for Apple's [Accelerate framework](https://developer.apple.com/documentation/accelerate) — high-performance vector math, signal processing, and image manipulation on macOS and iOS.

## Modules

| Module | Description |
|--------|-------------|
| `vdsp` | Digital signal processing — vector arithmetic, FFT/DFT/DCT, convolution, biquad filters, reductions, complex operations, type conversions |
| `vimage` | Image processing — alpha compositing, the complete format-conversion surface (packed pixels, YCbCr video, 16Q12 fixed point, indexed and sub-byte planar), convolution (including separable), geometric transforms up to perspective warp, histograms, morphology |
| `vforce` | Vectorized math functions — exp, log, trig, hyperbolic, power, rounding, and more on large arrays |
| `sparse` | Sparse solvers — direct (Cholesky, LDL^T, QR, LU) and iterative (CG, GMRES, LSMR), subfactors, preconditioners, real and complex |
| `quadrature` | Numerical integration — QNG, QAG and QAGS, including infinite intervals |
| `blas` | Dense linear algebra — the full CBLAS Levels 1, 2 and 3, real and complex, plus threading control |
| `bnns` | Neural network inference — the Graph API (compile a Core ML `.mlmodelc`, execute it), tensor ops, reductions, top-k, a seedable RNG, k-nearest-neighbours, and the deprecated layer-filter API for pre-macOS-15 deployment targets |
| `lapack` | Linear systems, factorizations, least squares, eigenvalues, SVD and the CS decomposition, in full, band, tridiagonal, packed and RFP storage — all 2032 symbols bound, typed wrappers for the whole user-facing surface |

Two more become available when the package is built with `-Dcoregraphics=true`
— see [CoreGraphics and CoreVideo](#coregraphics-and-corevideo):

| Module | Description |
|--------|-------------|
| `cg` | The slice of CoreFoundation and CoreGraphics vImage needs — `CGColorSpace`, `CGImage`, `CGBitmapInfo`, `CGColorConversionInfo` |
| `cv` | The slice of CoreVideo vImage needs — `CVPixelBuffer` creation, locking and plane access, and the pixel-format codes |

along with `vimage.utilities` (CGImage interop and `vImageConvert_AnyToAny`)
and `vimage.cv` (CVPixelBuffer interop).

See [`docs/COVERAGE.md`](docs/COVERAGE.md) for exactly which Accelerate entry
points are bound, which are not, and why.

## Installation

Add this package to your `build.zig.zon`:

```
zig fetch --save git+https://github.com/ironpark/accelerate
```

Then in your `build.zig`:

```zig
const accelerate = b.dependency("accelerate", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("accelerate", accelerate.module("accelerate"));
```

### CoreGraphics and CoreVideo

The vImage entry points that interoperate with `CGImage` and `CVPixelBuffer`
are off by default, because binding them means linking CoreGraphics, CoreVideo
and CoreFoundation into your program whether you touch them or not. Turn them
on through the dependency call:

```zig
const accelerate = b.dependency("accelerate", .{
    .target = target,
    .optimize = optimize,
    .coregraphics = true,
});
```

With the option off, `accelerate.cg`, `accelerate.cv`, `vimage.utilities` and
`vimage.cv` each resolve to a placeholder namespace whose only declaration is
`enabled = false`, so you can branch on it:

```zig
if (accelerate.vimage.utilities.enabled) {
    // ...
}
```

Ownership follows CoreFoundation's Create Rule, encoded in the types rather
than left to a naming convention. `*CGImage`, `*CGColorSpace` and
`*CVPixelBuffer` are **borrowed** pointers with no `deinit`; `cg.Image`,
`cg.ColorSpace`, `cv.PixelBuffer`, `vimage.utilities.Converter` and
`vimage.cv.CVImageFormat` are **owned** +1 references that must be released.
Constructors return the owned form, getters return the borrowed one, and
`.borrow(ptr)` / `.adopt(ptr)` convert between them.

## Usage

```zig
const accelerate = @import("accelerate");
const vdsp = accelerate.vdsp;
const vforce = accelerate.vforce;
const vimage = accelerate.vimage;
const sparse = accelerate.sparse;
const quadrature = accelerate.quadrature;
const blas = accelerate.blas;
```

### vDSP

```zig
// Vector add
const a = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
const b = [_]f32{ 5.0, 6.0, 7.0, 8.0 };
var out: [4]f32 = undefined;
vdsp.vadd(f32, &a, &b, &out);
// out = { 6.0, 8.0, 10.0, 12.0 }

// Dot product
const dot = vdsp.dotpr(f32, &a, &b);

// Sum
const s = vdsp.sve(f32, &a);

// FFT
var fft = vdsp.FFT(f32).init(log2n, .radix2) orelse return error.FFTInitFailed;
defer fft.deinit();
fft.forward(&split);
```

### vForce

```zig
const x = [_]f32{ 1.0, 4.0, 9.0 };
var out: [3]f32 = undefined;

// Square root
vforce.sqrt(f32, &x, &out);
// out = { 1.0, 2.0, 3.0 }

// Exponential
vforce.exp(f32, &x, &out);

// Trigonometric
vforce.sin(f32, &x, &out);
vforce.cos(f32, &x, &out);

// Simultaneous sin & cos
var sin_out: [3]f32 = undefined;
var cos_out: [3]f32 = undefined;
vforce.sincos(f32, &x, &sin_out, &cos_out);

// Hyperbolic tangent
vforce.tanh(f32, &x, &out);
```

### vImage

```zig
// Alpha compositing
var src = vimage.types.vImage_Buffer{ ... };
var dst = vimage.types.vImage_Buffer{ ... };
try vimage.alpha.premultipliedAlphaBlend_ARGB8888(&src, &dst, &dst, .{});
```

### vImage <-> CoreGraphics (`-Dcoregraphics=true`)

```zig
const cg = accelerate.cg;
const utilities = vimage.utilities;

const space = try cg.ColorSpace.named(cg.ColorSpaceName.srgb());
defer space.deinit();

// Wrap a buffer in a CGImage (the pixel data is copied).
const fmt = utilities.CGImageFormat.argb8888(space.ref);
const image = try utilities.createCGImageFromBuffer(&buf, &fmt, null, null, 0);
defer image.deinit();

// ...and decode one back out, in whatever format you ask for.
var dst_fmt = utilities.CGImageFormat.bgra8888(space.ref);
var dst: vimage.vImage_Buffer = undefined;
try utilities.bufferInitWithCGImage(&dst, &dst_fmt, null, image.ref, 0);
defer utilities.bufferFree(&dst);

// vImageConvert_AnyToAny: one object converts between any two describable
// formats, colour-space changes included.
const conv = try utilities.Converter.createWithCGImageFormat(&fmt, &dst_fmt, null, 0);
defer conv.deinit();
_ = try conv.convert(&.{src}, &.{dst}, null, 0);
```

```zig
// CVPixelBuffer, including planar YCbCr.
const pb = try accelerate.cv.PixelBuffer.init(1920, 1080, .ycbcr420_biplanar_video);
defer pb.deinit();

const cv_fmt = try vimage.cv.CVImageFormat.createWithCVPixelBuffer(pb.ref);
defer cv_fmt.deinit();
try cv_fmt.setColorSpace(space.ref);
try cv_fmt.setConversionMatrix(.{ .argb_to_ypcbcr = vimage.conversion.ycbcr.argbToYpCbCrMatrix601() });
try cv_fmt.setChromaSiting(accelerate.cv.ChromaLocation.center());

const encoder = try vimage.cv.converterForCGToCVImageFormat(&fmt, cv_fmt, &.{ 0, 0, 0 }, 0);
defer encoder.deinit();

// kvImageNoAllocate points the vImage buffers straight at the pixel
// buffer's own planes, so the conversion writes into it with no extra copy.
var planes: [2]vimage.vImage_Buffer = undefined;
try pb.lock(0);
defer pb.unlock(0) catch {};
try vimage.cv.bufferInitForCopyToCVPixelBuffer(&planes, encoder, pb.ref, vimage.Flags.kvImageNoAllocate);
_ = try encoder.convert(&.{argb_source}, &planes, null, 0);
```

### Sparse

```zig
// Lower triangle of a symmetric positive-definite matrix, in CSC.
const starts = [_]c_long{ 0, 2, 4, 6, 7 };
const rows   = [_]c_int{ 0, 1, 1, 2, 2, 3, 3 };
const vals   = [_]f64{ 2, 1, 3, 1, 4, 1, 5 };
const a = sparse.Sparse(f64).init(4, 4, &starts, &rows, &vals, .{
    .attributes = .{ .kind = .symmetric, .triangle = .lower },
});

var f = try sparse.Factorization(f64).init(.cholesky, a, .{});
defer f.deinit();

var b = [_]f64{ 4, 10, 18, 23 };
var x = [_]f64{ 0, 0, 0, 0 };
try f.solve(allocator, &b, &x);
// x = { 1, 2, 3, 4 }

// Same pattern, new values: reuses the ordering and symbolic analysis.
try f.refactor(allocator, a2, .{});

// Iterative, for when a factorization is too big to store.
const status = try sparse.Iterative(f64).conjugateGradient(
    a, sparse.Dense(f64).fromSlice(&b), sparse.Dense(f64).fromSlice(&x),
    .{ .rtol = 1e-12 }, null,
);

// ...or matrix-free, with A never stored at all.
_ = try sparse.Iterative(f64).conjugateGradientOperator(
    *Grid, &grid, applyStencil,
    sparse.Dense(f64).fromSlice(&b), sparse.Dense(f64).fromSlice(&x), .{}, null,
);
```

### BLAS

```zig
// C := A * B for 2x2 row-major matrices
const a = [_]f64{ 1, 2, 3, 4 };
const b = [_]f64{ 5, 6, 7, 8 };
var c = [_]f64{ 0, 0, 0, 0 };
blas.gemm(f64, .row_major, .no_trans, .no_trans, 2, 2, 2, 1, &a, 2, &b, 2, 0, &c, 2);
// c = { 19, 22, 43, 50 }

// Level 1 has a unit-stride form and a full strided form
const n = blas.nrm2(f64, &.{ 3, 4 });           // 5
blas.axpy(f64, 2.0, &x, &y);                    // y := 2x + y
blas.axpyStrided(f64, 3, 2.0, &x, 1, &y, 2);    // every other element of y

// Complex works the same way, via the element type
const Z = blas.Complex(f64);
const z = [_]Z{ .init(1, 2), .init(3, -1) };
const inner = blas.dotc(Z, &z, &z);             // real, = ||z||^2
```

### Quadrature

```zig
fn gaussian(_: void, x: f64) f64 {
    return @exp(-x * x);
}

// Integrates to sqrt(pi) over the whole real line.
const r = try quadrature.integrateScalar(void, {}, gaussian, -inf, inf, .{
    .integrator = .{ .qags = .{} },
    .abs_tolerance = 1e-12,
}, allocator);
// r.value, r.abs_error, r.status

// The array form is the one Accelerate actually calls; use it to vectorize.
fn batched(_: void, x: []const f64, y: []f64) void {
    vforce.exp(f64, x, y);
}
_ = try quadrature.integrate(void, {}, batched, 0, 1, .{}, allocator);
```

## API Overview

### vdsp

**Dot products:** `dotpr`, `dotpr2`, `zdotpr`, `zidotpr`, `zrdotpr`

**Vector ops:** `vadd`, `vsub`, `vmul`, `vdiv`, `vfill`, `vsmul`, `vsadd`, `vsdiv`, `vma`, `vmsa`, `vsma`, `vam`, `vmsb`, `vmma`, `vmmsb`, `vsmsa`, `vsmsb`, `vsmsma`, `vaam`, `vasbm`, `vasm`, `vsbm`, `vsbsbm`, `vsbsm`, `vavlin`, `vpythg`, `vsq`, `vssq`, `vabs`, `vneg`, `vnabs`, `vfrac`, `vdist`, `distancesq`

**Complex ops:** `zvadd`, `zvsub`, `zvmul`, `zvdiv`, `zvabs`, `zvfill`, `zvcma`, `zvma`, `zvcmul`, `zvconj`, `zvzsml`, `zvmags`, `zvmov`, `zvneg`, `zvphas`, `zvsma`, `zaspec`, `zcoher`, `ztrans`, `zcspec`, `desamp`

**Reductions:** `sve`, `svesq`, `svemg`, `meanv`, `meamgv`, `measqv`, `rmsqv`, `maxv`, `maxvi`, `minv`, `minvi`, `normalize`

**Clip/threshold:** `vclr`, `vclip`, `vclipc`, `viclip`, `vthr`, `vthres`, `vlim`, `vmax`, `vmin`

**FFT/DFT:** `FFT`, `DFT`, `RealDFT`, `DCT`, `InterleavedDFT`, `fft16_copv`, `fft32_copv`

**Convolution:** `conv`, `imgfir`, `f3x3`, `f5x5`, `deq22`, `zconv`

**Biquad filters:** `Biquad`, `Biquadm`

**Utilities:** `vrvrs`, `vswap`, `vsort`, `vramp`, `vgen`, `vpoly`, `vrsum`, `vsimps`, `vtrapz`, `blkman_window`, `hamm_window`, `hann_window`

**Type conversion:** `vdpsp`, `vspdp`, `vflt8`..`vflt32`, `vfix8`..`vfix32`, `vdbcon`, `polar`, `rect`

**Matrix:** `mmul`, `mtrans`, `zmmul`

### vforce

**Arithmetic:** `rec`, `div`, `sqrt`, `cbrt`, `rsqrt`

**Exponential:** `exp`, `exp2`, `expm1`

**Logarithmic:** `log`, `log10`, `log2`, `log1p`, `logb`

**Power:** `pow`, `pows`, `fabs`

**Trigonometric:** `sin`, `cos`, `tan`, `sinpi`, `cospi`, `tanpi`, `sincos`

**Inverse trig:** `asin`, `acos`, `atan`, `atan2`

**Hyperbolic:** `sinh`, `cosh`, `tanh`, `asinh`, `acosh`, `atanh`

**Rounding:** `trunc`, `nint`, `ceil`, `floor`

**Modular:** `fmod`, `remainder`

**Other:** `copysign`, `nextafter`, `cosisin`

### vimage

**Alpha:** premultiplied/non-premultiplied blending, flatten, unpremultiply

**Conversion:** format conversion, channel extraction, pixel resampling

**Convolution:** box, tent, general convolution kernels

**Geometry:** affine transforms, scaling, rotation, shearing

**Histogram:** computation and specification

**Morphology:** dilate, erode, min, max

**Transform:** gamma correction, lookup tables, multidimensional interpolation

**Utilities** (`-Dcoregraphics=true`): `CGImageFormat`, `Converter`
(`vImageConvert_AnyToAny`), `createCGImageFromBuffer`,
`bufferInitWithCGImage`, `bufferInit`/`bufferLayout`

**CV** (`-Dcoregraphics=true`): `CVImageFormat`, the `CVPixelBuffer` bridges,
`converterForCGToCVImageFormat` / `converterForCVToCGImageFormat`,
`createRGBColorSpace` / `createMonochromeColorSpace`

### sparse

**Matrix types:** `Sparse(T)` (block CSC, borrowed or built from coordinate
form via `fromCoordinate`), `Dense(T)` (column-major, one or many right-hand
sides)

**Factorizations:** `.cholesky`, `.ldlt`, `.ldlt_unpivoted`, `.ldlt_sbk`,
`.ldlt_tpp`, `.qr`, `.cholesky_at_a`

**Solving:** `solve`, `solveInPlace`, `solveMatrix`, `solveMatrixInPlace`,
`solveWithWorkspace`, `workspaceSize`

**Iterative:** `conjugateGradient`, `gmres` (DQGMRES/GMRES/FGMRES), `lsmr`,
each with a matrix-free `...Operator` variant; `Preconditioner` (built-in
diagonal/diagonal-scaling, or user-supplied)

**Subfactors:** `Subfactor` — extract and apply `L`, `D`, `P`, `S`, `Q`, `R`
individually

**Other:** `multiply` (sparse x dense, with optional accumulate and scale),
`refactor` / `refactorWithWorkspace`, `inertia`, `retain`

Supports `f32` and `f64`. See `docs/SPARSE-RESEARCH.md` for how these bind to a
C API that exports no symbols for its public functions.

### quadrature

**Integrators:** `.qng` (non-adaptive Gauss-Kronrod-Patterson, no workspace),
`.qag` (adaptive, selectable 15/21/31/41/51/61 points per interval), `.qags`
(adaptive with epsilon-algorithm acceleration; the only one accepting infinite
bounds)

**Entry points:** `integrate` / `integrateWithWorkspace` (array integrand),
`integrateScalar` / `integrateScalarWithWorkspace`

Failing to reach the requested tolerance is reported through `Result.status`,
not as an error, so a partial estimate and its error bound stay available.

### blas

**Level 1:** `asum`, `nrm2`, `iamax`, `dot`, `dotu`, `dotc`, `sdsdot`,
`dsdot`, `axpy`, `axpby`, `copy`, `swap`, `scal`, `scalReal`, `set`, `rot`,
`rotg`, `rotm`, `rotmg` — each with a `...Strided` form taking explicit `n`
and increments (negative increments included)

**Level 2:** `gemv`, `gbmv`, `ger`, `geru`, `gerc`, `symv`/`hemv`,
`sbmv`/`hbmv`, `spmv`/`hpmv`, `syr`/`her`, `syr2`/`her2`, `spr`/`hpr`,
`spr2`/`hpr2`, `trmv`, `trsv`, `tbmv`, `tbsv`, `tpmv`, `tpsv`

**Level 3:** `gemm`, `symm`, `hemm`, `syrk`, `herk`, `syr2k`, `her2k`, `trmm`,
`trsm`, plus Apple's `geadd` extension

Element types are `f32`, `f64`, `Complex(f32)` and `Complex(f64)`. Uses the
current (`$NEWLAPACK`) interface with ILP64 indices where Accelerate provides
them — `cblas.h`'s unsuffixed symbols have been deprecated since macOS 13.3.

## What this package does not bind

Five headers in `Accelerate.framework` are left out on purpose. Together they
are 263 symbols, and none of them is a gap you would hit in new code.

| Header | Symbols | Why |
|---|---:|---|
| `vBasicOps.h` | 71 | AltiVec-era 128-bit integer SIMD |
| `vBigNum.h` | 69 | 256/512/1024-bit integer arithmetic |
| `vfp.h` | 47 | superseded vector floating point |
| `vectorOps.h` | 29 | superseded vector utilities |
| `LinearAlgebra` (`la_*`) | 47 | `API_DEPRECATED` since macOS 11 |

The first four predate Zig's own facilities for the same work. `@Vector`
covers `vBasicOps`, `vfp` and `vectorOps` natively and portably, with no call
across the C boundary; Zig's arbitrary-width integers (`u512`, `i1024`) cover
`vBigNum` directly. Binding them would trade a language feature for a
platform dependency.

`LinearAlgebra` is a different case. Apple's own guidance for `la_*` is to use
BLAS and LAPACK instead, and this package binds both in full — so binding it
would add a second, deprecated way to do something already available.

That reasoning is worth spelling out, because the deprecated **BNNS**
layer-filter API is bound rather than excluded, and the two look like the same
decision made twice in opposite directions. The difference is whether the
replacement is reachable. `la_*`'s replacement is BLAS/LAPACK, available on
every deployment target. The BNNS filter API's replacement is the Graph API,
which requires macOS 15.0 — so excluding it would leave anyone targeting an
older OS with nothing at all. Each of those 75 declarations carries a doc
comment naming the version that deprecated it and, where the header gives one,
its replacement.

One further symbol is deliberately unbound: `BNNSGraphExecute` is exported by
`vecLib.tbd` but declared in no header, appearing only inside doc comments.
There is no prototype to bind it against, and a guessed signature would link
cleanly and then misbehave at runtime.

Everything else — every entry point in `vecLib` and `vImage` — is bound. See
[`docs/COVERAGE.md`](docs/COVERAGE.md) for the per-header counts, the
re-measurement recipe, and a table of the places where Accelerate's measured
behaviour contradicts its own headers.

## Requirements

- macOS or iOS (Accelerate framework)
- Zig 0.16.0+
- CoreGraphics, CoreVideo and CoreFoundation, only with `-Dcoregraphics=true`

## License

MIT
