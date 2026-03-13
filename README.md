# accelerate

Zig bindings for Apple's [Accelerate framework](https://developer.apple.com/documentation/accelerate) — high-performance vector math, signal processing, and image manipulation on macOS and iOS.

## Modules

| Module | Description |
|--------|-------------|
| `vdsp` | Digital signal processing — vector arithmetic, FFT/DFT/DCT, convolution, biquad filters, reductions, complex operations, type conversions |
| `vimage` | Image processing — alpha compositing, format conversion, convolution, geometric transforms, histograms, morphology |
| `vforce` | Vectorized math functions — exp, log, trig, hyperbolic, power, rounding, and more on large arrays |

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

## Requirements

- macOS or iOS (Accelerate framework)
- Zig 0.16.0+

## License

MIT
