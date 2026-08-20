# accelerate

Zig bindings for Apple's [Accelerate framework](https://developer.apple.com/documentation/accelerate) — high-performance vector math, signal processing, and image manipulation on macOS and iOS.

## Modules

| Module | Description |
|--------|-------------|
| `vdsp` | Digital signal processing — vector arithmetic, FFT/DFT/DCT, convolution, biquad filters, reductions, complex operations, type conversions |
| `vimage` | Image processing — alpha compositing, format conversion, convolution, geometric transforms, histograms, morphology |
| `vforce` | Vectorized math functions — exp, log, trig, hyperbolic, power, rounding, and more on large arrays |
| `sparse` | Sparse solvers — direct (Cholesky, LDL^T, QR) and iterative (CG, GMRES, LSMR), subfactors, preconditioners |

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

## Usage

```zig
const accelerate = @import("accelerate");
const vdsp = accelerate.vdsp;
const vforce = accelerate.vforce;
const vimage = accelerate.vimage;
const sparse = accelerate.sparse;
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

## Requirements

- macOS or iOS (Accelerate framework)
- Zig 0.16.0+

## License

MIT
