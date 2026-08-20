# accelerate

Zig bindings for Apple's [Accelerate framework](https://developer.apple.com/documentation/accelerate) — high-performance vector math, signal processing, and image manipulation on macOS and iOS.

## Modules

| Module | Description |
|--------|-------------|
| `vdsp` | Digital signal processing — vector arithmetic, FFT/DFT/DCT, convolution, biquad filters, reductions, complex operations, type conversions |
| `vimage` | Image processing — alpha compositing, format conversion, convolution, geometric transforms, histograms, morphology |
| `vforce` | Vectorized math functions — exp, log, trig, hyperbolic, power, rounding, and more on large arrays |
| `sparse` | Sparse solvers — direct (Cholesky, LDL^T, QR) and iterative (CG, GMRES, LSMR), subfactors, preconditioners |
| `quadrature` | Numerical integration — QNG, QAG and QAGS, including infinite intervals |
| `blas` | Dense linear algebra — the full CBLAS Levels 1, 2 and 3, real and complex |
| `lapack` | Linear systems, factorizations, least squares, eigenvalues and SVD, in full, band, tridiagonal and packed storage — all 2032 symbols bound, wrappers in progress |

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

## Requirements

- macOS or iOS (Accelerate framework)
- Zig 0.16.0+

## License

MIT
