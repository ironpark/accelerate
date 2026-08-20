# 공개 함수 체크리스트

이 문서는 `src` 아래 Zig 소스에서 확인한 공개 함수 목록입니다. 각 항목의 숫자는 선언 위치의 줄 번호입니다. `src/vdsp/root.zig`와 `src/root.zig`의 재-export는 원본 선언과 중복해서 세지 않았습니다.

- 직접 선언된 `pub fn`: 474개
- 공개 callable `pub const` 멤버: 2개
- 체크리스트 항목 합계: 476개

## vDSP

### `src/vdsp/biquad.zig`

- [x] `Biquad` — L23
- [x] `Biquad(T).init` — L38
- [x] `Biquad(T).deinit` — L56
- [x] `Biquad(T).apply` — L72
- [x] `Biquad(T).setCoefficientsDouble` — L84 (callable `pub const`)
- [x] `Biquad(T).setCoefficientsSingle` — L97 (callable `pub const`)
- [x] `Biquadm` — L112
- [x] `Biquadm(T).init` — L134
- [x] `Biquadm(T).deinit` — L148
- [x] `Biquadm(T).apply` — L157
- [x] `Biquadm(T).resetState` — L166
- [x] `Biquadm(T).copyState` — L176
- [x] `Biquadm(T).setCoefficientsDouble` — L187
- [x] `Biquadm(T).setCoefficientsSingle` — L198
- [x] `Biquadm(T).setTargetsDouble` — L209
- [x] `Biquadm(T).setTargetsSingle` — L220
- [x] `Biquadm(T).setActiveFilters` — L229

### `src/vdsp/clip.zig`

- [x] `vclr` — L11
- [x] `vcmprs` — L27
- [x] `vclip` — L45
- [x] `vclipc` — L63
- [x] `viclip` — L74
- [x] `vthr` — L82
- [x] `vthres` — L90
- [x] `vlim` — L98
- [x] `vmax` — L108
- [x] `vmin` — L116
- [x] `vmaxmg` — L124
- [x] `vminmg` — L132

### `src/vdsp/conv.zig`

- [x] `conv` — L15
- [x] `imgfir` — L40
- [x] `f3x3` — L62
- [x] `f5x5` — L84
- [x] `deq22` — L92
- [x] `zconv` — L111

### `src/vdsp/convert.zig`

- [x] `vdpsp` — L13
- [x] `vspdp` — L17
- [x] `vflt8` — L27
- [x] `vflt16` — L38
- [x] `vflt32` — L49
- [x] `vfltu8` — L60
- [x] `vfltu16` — L71
- [x] `vfltu32` — L82
- [x] `vflt24` — L96
- [x] `vfltu24` — L104
- [x] `vfltsm24` — L115
- [x] `vfltsmu24` — L123
- [x] `vsmfix24` — L138
- [x] `vsmfixu24` — L150
- [x] `vfix8` — L161
- [x] `vfix16` — L172
- [x] `vfix32` — L183
- [x] `vfixu8` — L197
- [x] `vfixu16` — L208
- [x] `vfixu32` — L219
- [x] `vfixr8` — L236
- [x] `vfixr16` — L250
- [x] `vfixr32` — L264
- [x] `vfixru8` — L281
- [x] `vfixru16` — L295
- [x] `vfixru32` — L309
- [x] `venvlp` — L326
- [x] `vdbcon` — L345
- [x] `polar` — L355
- [x] `rect` — L363

### `src/vdsp/dft.zig`

- [x] `DFT` — L36
- [x] `DFT(T).init` — L48
- [x] `DFT(T).initShared` — L58
- [x] `DFT(T).deinit` — L68
- [x] `DFT(T).exec` — L76
- [x] `RealDFT` — L88
- [x] `RealDFT(T).init` — L100
- [x] `RealDFT(T).deinit` — L110
- [x] `RealDFT(T).exec` — L118
- [x] `DCT.init` — L132
- [x] `DCT.deinit` — L136
- [x] `DCT.exec` — L140
- [x] `InterleavedDFT` — L147
- [x] `InterleavedDFT(T).init` — L160
- [x] `InterleavedDFT(T).deinit` — L171
- [x] `InterleavedDFT(T).exec` — L179

### `src/vdsp/dotp.zig`

- [x] `dotpr` — L8
- [x] `dotpr2` — L35
- [x] `zdotpr` — L46
- [x] `zidotpr` — L56
- [x] `zrdotpr` — L66
- [x] `dotpr_s1_15` — L92
- [x] `dotpr2_s1_15` — L119
- [x] `dotpr_s8_24` — L142
- [x] `dotpr2_s8_24` — L169

### `src/vdsp/fft.zig`

- [x] `ctoz` — L38
- [x] `ztoc` — L54
- [x] `FFT` — L70
- [x] `FFT(T).init` — L84
- [x] `FFT(T).deinit` — L98
- [x] `FFT(T).zip` — L132
- [x] `FFT(T).zipt` — L148
- [x] `FFT(T).zop` — L180
- [x] `FFT(T).zopt` — L196
- [x] `FFT(T).zrip` — L217
- [x] `FFT(T).zript` — L232
- [x] `FFT(T).zrop` — L251
- [x] `FFT(T).zropt` — L266
- [x] `FFT(T).zip2d` — L279
- [x] `FFT(T).zipt2d` — L294
- [x] `FFT(T).zop2d` — L305
- [x] `FFT(T).zopt2d` — L320
- [x] `FFT(T).zrip2d` — L339
- [x] `FFT(T).zript2d` — L354
- [x] `FFT(T).zrop2d` — L371
- [x] `FFT(T).zropt2d` — L386
- [x] `FFT(T).mzip` — L401
- [x] `FFT(T).mzipt` — L415
- [x] `FFT(T).mzop` — L428
- [x] `FFT(T).mzopt` — L442
- [x] `FFT(T).mzrip` — L457
- [x] `FFT(T).mzript` — L472
- [x] `FFT(T).mzrop` — L487
- [x] `FFT(T).mzropt` — L502

### `src/vdsp/fixed_fft.zig`

- [x] `fft16_copv` — L44
- [x] `fft32_copv` — L87
- [x] `fft16_zopv` — L131
- [x] `fft32_zopv` — L175

### `src/vdsp/matrix.zig`

- [x] `mmul` — L25
- [x] `mtrans` — L50
- [x] `zmma` — L73
- [x] `zmms` — L96
- [x] `zmsm` — L119
- [x] `zmmul` — L141
- [x] `zvmmaa` — L157

### `src/vdsp/ramp.zig`

- [x] `vrampmul` — L48
- [x] `vrampmuladd` — L103
- [x] `vrampmul2` — L167
- [x] `vrampmuladd2` — L231
- [x] `vrampmul_s1_15` — L288
- [x] `vrampmuladd_s1_15` — L339
- [x] `vrampmul2_s1_15` — L398
- [x] `vrampmuladd2_s1_15` — L458
- [x] `vrampmul_s8_24` — L511
- [x] `vrampmuladd_s8_24` — L562
- [x] `vrampmul2_s8_24` — L621
- [x] `vrampmuladd2_s8_24` — L681

### `src/vdsp/reduction.zig`

- [x] `ValueIndex` — L6
- [x] `NormResult` — L10
- [x] `sve` — L19
- [x] `svesq` — L32
- [x] `sve_svesq` — L46
- [x] `svemg` — L60
- [x] `meanv` — L75
- [x] `meamgv` — L88
- [x] `measqv` — L101
- [x] `rmsqv` — L114
- [x] `maxv` — L129
- [x] `maxvi` — L143
- [x] `maxmgv` — L157
- [x] `maxmgvi` — L171
- [x] `minv` — L187
- [x] `minvi` — L201
- [x] `minmgv` — L215
- [x] `minmgvi` — L229
- [x] `normalize` — L251
- [x] `mmov` — L272
- [x] `mvessq` — L285
- [x] `nzcros` — L309
- [x] `svs` — L325

### `src/vdsp/types.zig`

- [x] `SplitComplex` — L6
- [x] `Complex` — L13
- [x] `Complex(T).init` — L20
- [x] `Complex(T).fromStd` — L24
- [x] `Complex(T).toStd` — L28
- [x] `Int24.from` — L37
- [x] `Int24.to` — L41
- [x] `Int24.toI32` — L45
- [x] `UInt24.from` — L53
- [x] `UInt24.to` — L57
- [x] `UInt24.toU32` — L61

### `src/vdsp/util.zig`

- [x] `vrvrs` — L18
- [x] `vswap` — L32
- [x] `vsort` — L44
- [x] `vsorti` — L60
- [x] `vramp` — L78
- [x] `vgen` — L92
- [x] `vgathr` — L110
- [x] `vindex` — L124
- [x] `vgathra` — L138
- [x] `vthrsc` — L159
- [x] `vtabi` — L189
- [x] `vtmerg` — L207
- [x] `wiener` — L220
- [x] `vlint` — L244
- [x] `vqint` — L263
- [x] `vintb` — L277
- [x] `vgenp` — L297
- [x] `vpoly` — L313
- [x] `vrsum` — L333
- [x] `vsimps` — L349
- [x] `vtrapz` — L364
- [x] `vswsum` — L380
- [x] `vswmax` — L403
- [x] `blkman_window` — L415
- [x] `hamm_window` — L423
- [x] `hann_window` — L431

### `src/vdsp/vaddsub.zig`

- [x] `vaddsub` — L39

### `src/vdsp/vecop.zig`

- [x] `vfill` — L14
- [x] `vadd` — L31
- [x] `vsub` — L46
- [x] `vmul` — L60
- [x] `vdiv` — L74
- [x] `veqvi` — L89
- [x] `vsmul` — L103
- [x] `vsadd` — L116
- [x] `vsdiv` — L130
- [x] `svdiv` — L141
- [x] `vma` — L158
- [x] `vmsa` — L170
- [x] `vsma` — L181
- [x] `vam` — L195
- [x] `vmsb` — L207
- [x] `vmma` — L219
- [x] `vmmsb` — L232
- [x] `vsmsa` — L245
- [x] `vsmsb` — L255
- [x] `vsmsma` — L266
- [x] `vaam` — L281
- [x] `vasbm` — L294
- [x] `vasm` — L307
- [x] `vsbm` — L322
- [x] `vsbsbm` — L334
- [x] `vsbsm` — L347
- [x] `vavlin` — L362
- [x] `vpythg` — L376
- [x] `vsq` — L396
- [x] `vssq` — L409
- [x] `vabs` — L422
- [x] `vneg` — L432
- [x] `vnabs` — L442
- [x] `vfrac` — L451
- [x] `vdist` — L460
- [x] `distancesq` — L473

### `src/vdsp/zvecop.zig`

- [x] `zvadd` — L16
- [x] `zrvadd` — L28
- [x] `zvsub` — L40
- [x] `zrvsub` — L52
- [x] `zrvmul` — L64
- [x] `zvdiv` — L76
- [x] `zrvdiv` — L88
- [x] `zvabs` — L100
- [x] `zvfill` — L112
- [x] `zvmul` — L128
- [x] `zvcma` — L140
- [x] `zvma` — L152
- [x] `zvcmul` — L164
- [x] `zvconj` — L176
- [x] `zvzsml` — L188
- [x] `zvmags` — L200
- [x] `zvmgsa` — L212
- [x] `zvmov` — L224
- [x] `zvneg` — L236
- [x] `zvphas` — L248
- [x] `zvsma` — L260
- [x] `zaspec` — L276
- [x] `zcoher` — L288
- [x] `ztrans` — L300
- [x] `zcspec` — L312
- [x] `desamp` — L324
- [x] `zrdesamp` — L336

## vForce

### `src/vforce/root.zig`

- [x] `rec` — L20
- [x] `div` — L31
- [x] `sqrt` — L43
- [x] `cbrt` — L54
- [x] `rsqrt` — L65
- [x] `exp` — L80
- [x] `exp2` — L91
- [x] `expm1` — L102
- [x] `log` — L117
- [x] `log10` — L128
- [x] `log2` — L139
- [x] `log1p` — L150
- [x] `logb` — L161
- [x] `pow` — L176
- [x] `pows` — L189
- [x] `fabs` — L205
- [x] `sin` — L220
- [x] `cos` — L231
- [x] `tan` — L242
- [x] `sinpi` — L253
- [x] `cospi` — L264
- [x] `tanpi` — L275
- [x] `sincos` — L286
- [x] `asin` — L302
- [x] `acos` — L313
- [x] `atan` — L324
- [x] `atan2` — L335
- [x] `sinh` — L351
- [x] `cosh` — L362
- [x] `tanh` — L373
- [x] `asinh` — L388
- [x] `acosh` — L399
- [x] `atanh` — L410
- [x] `trunc` — L425
- [x] `nint` — L436
- [x] `ceil` — L447
- [x] `floor` — L458
- [x] `fmod` — L473
- [x] `remainder` — L485
- [x] `copysign` — L501
- [x] `nextafter` — L513
- [x] `cosisin` — L529

## vImage

### `src/vimage/alpha.zig`

- [x] `alphaBlendPlanar` — L19
- [x] `alphaBlendARGB` — L31
- [x] `premultipliedAlphaBlendPlanar` — L48
- [x] `premultipliedAlphaBlendARGB` — L57
- [x] `premultipliedAlphaBlendBGRA` — L66
- [x] `premultipliedAlphaBlendWithPermuteARGB` — L76
- [x] `premultipliedAlphaBlendWithPermuteRGBA` — L82
- [x] `premultipliedAlphaBlendRGBA` — L100
- [x] `premultipliedConstAlphaBlendPlanar` — L118
- [x] `premultipliedConstAlphaBlendARGB` — L128
- [x] `alphaBlendNonpremultipliedToPremultipliedPlanar` — L142
- [x] `alphaBlendNonpremultipliedToPremultipliedARGB` — L152
- [x] `premultiplyDataPlanar` — L168
- [x] `premultiplyDataARGB` — L177
- [x] `premultiplyDataRGBA` — L186
- [x] `premultiplyDataARGB16U` — L195
- [x] `premultiplyDataRGBA16U` — L200
- [x] `premultiplyDataARGB16Q12` — L205
- [x] `premultiplyDataRGBA16Q12` — L210
- [x] `premultiplyDataRGBA16F` — L215
- [x] `unpremultiplyDataPlanar` — L228
- [x] `unpremultiplyDataARGB` — L237
- [x] `unpremultiplyDataRGBA` — L246
- [x] `unpremultiplyDataARGB16U` — L255
- [x] `unpremultiplyDataRGBA16U` — L260
- [x] `unpremultiplyDataARGB16Q12` — L265
- [x] `unpremultiplyDataRGBA16Q12` — L270
- [x] `unpremultiplyDataRGBA16F` — L275
- [x] `clipToAlphaPlanar` — L287
- [x] `clipToAlphaARGB` — L297
- [x] `clipToAlphaRGBA` — L307

### `src/vimage/conversion.zig`

- [x] `clipPlanarF` — L21
- [x] `planar8ToPlanarF` — L32
- [x] `planarFToPlanar8` — L39
- [x] `planar16FToPlanarF` — L44
- [x] `planarFToPlanar16F` — L49
- [x] `planar8ToPlanar16F` — L54
- [x] `planar16FToPlanar8` — L59
- [x] `convert16SToF` — L66
- [x] `convert16UToF` — L73
- [x] `convertFTo16S` — L80
- [x] `convertFTo16U` — L87
- [x] `convert16UToPlanar8` — L94
- [x] `planar8To16U` — L99
- [x] `planar8ToARGB8888` — L108
- [x] `planarFToARGBFFFF` — L120
- [x] `argb8888ToPlanar8` — L136
- [x] `argbFFFFToPlanarF` — L148
- [x] `planar8ToARGBFFFF` — L164
- [x] `argb8888ToPlanarF` — L178
- [x] `argbFFFFToPlanar8` — L192
- [x] `planarFToARGB8888` — L206
- [x] `planar8ToRGB888` — L224
- [x] `planarFToRGBFFF` — L235
- [x] `rgb888ToPlanar8` — L246
- [x] `rgbFFFToPlanarF` — L257
- [x] `rgb888ToInterleaved8888` — L287
- [x] `interleaved8888ToRGB888` — L304
- [x] `interleavedFFFFToRGBFFF` — L322
- [x] `rgbFFFToInterleavedFFFF` — L340
- [x] `flatten8888ToRGB888` — L358
- [x] `flattenFFFFToRGBFFF` — L375
- [x] `permuteChannelsARGB8888` — L398
- [x] `permuteChannelsARGB16U` — L403
- [x] `permuteChannelsARGBFFFF` — L408
- [x] `permuteChannelsRGB888` — L416
- [x] `extractChannelARGB8888` — L427
- [x] `extractChannelARGB16U` — L432
- [x] `extractChannelARGBFFFF` — L437
- [x] `overwriteChannelsARGB8888` — L456
- [x] `overwriteChannelsARGBFFFF` — L461
- [x] `overwriteScalarPlanar8` — L466
- [x] `overwriteScalarPlanarF` — L471
- [x] `overwriteScalarARGB8888` — L476
- [x] `overwriteScalarARGBFFFF` — L481
- [x] `overwritePixelARGB8888` — L486
- [x] `overwritePixelARGBFFFF` — L491
- [x] `selectChannelsARGB8888` — L500
- [x] `selectChannelsARGBFFFF` — L505
- [x] `fillARGB8888` — L514
- [x] `fillARGBFFFF` — L519
- [x] `tableLookUpARGB8888` — L530
- [x] `tableLookUpPlanar8` — L551
- [x] `copyBuffer` — L562

### `src/vimage/convolution.zig`

- [x] `convolvePlanar` — L25
- [x] `convolveInterleaved` — L53
- [x] `convolveWithBiasPlanar` — L85
- [x] `convolveWithBiasInterleaved` — L110
- [x] `convolveMultiKernelInterleaved` — L142
- [x] `richardsonLucyDeConvolvePlanar` — L177
- [x] `richardsonLucyDeConvolveInterleaved` — L205
- [x] `boxConvolvePlanar8` — L241
- [x] `boxConvolveARGB8888` — L256
- [x] `tentConvolvePlanar8` — L281
- [x] `tentConvolveARGB8888` — L296

### `src/vimage/geometry.zig`

- [x] `rotate` — L47
- [x] `scale` — L81
- [x] `horizontalReflect` — L111
- [x] `verticalReflect` — L134
- [x] `rotate90` — L177
- [x] `affineWarp` — L215
- [x] `affineWarpD` — L244
- [x] `affineWarpCG` — L273
- [x] `horizontalShear` — L307
- [x] `verticalShear` — L340
- [x] `newResamplingFilter` — L380
- [x] `destroyResamplingFilter` — L385

### `src/vimage/histogram.zig`

- [x] `histogramCalculation_Planar8` — L25
- [x] `histogramCalculation_PlanarF` — L37
- [x] `histogramCalculation_ARGB8888` — L51
- [x] `histogramCalculation_ARGBFFFF` — L63
- [x] `histogramCalculation` — L78
- [x] `equalization_Planar8` — L119
- [x] `equalization_PlanarF` — L131
- [x] `equalization_ARGB8888` — L144
- [x] `equalization_ARGBFFFF` — L153
- [x] `equalization` — L166
- [x] `histogramSpecification_Planar8` — L212
- [x] `histogramSpecification_PlanarF` — L222
- [x] `histogramSpecification_ARGB8888` — L239
- [x] `histogramSpecification_ARGBFFFF` — L249
- [x] `histogramSpecification` — L263
- [x] `contrastStretch_Planar8` — L310
- [x] `contrastStretch_PlanarF` — L319
- [x] `contrastStretch_ARGB8888` — L332
- [x] `contrastStretch_ARGBFFFF` — L341
- [x] `contrastStretch` — L354
- [x] `endsInContrastStretch_Planar8` — L400
- [x] `endsInContrastStretch_PlanarF` — L411
- [x] `endsInContrastStretch_ARGB8888` — L428
- [x] `endsInContrastStretch_ARGBFFFF` — L439
- [x] `endsInContrastStretch` — L454

### `src/vimage/morphology.zig`

- [x] `dilate` — L32
- [x] `erode` — L63
- [x] `max` — L95
- [x] `min` — L127

### `src/vimage/transform.zig`

- [x] `matrixMultiplyPlanar` — L27
- [x] `matrixMultiplyPlanar16S` — L66
- [x] `matrixMultiplyARGB` — L96
- [x] `matrixMultiplyARGBToPlanar` — L117
- [x] `createGammaFunction` — L155
- [x] `destroyGammaFunction` — L160
- [x] `gammaPlanarF` — L165
- [x] `gammaPlanar8toPlanarF` — L170
- [x] `gammaPlanarFtoPlanar8` — L175
- [x] `piecewiseGamma` — L187
- [x] `symmetricPiecewiseGamma` — L218
- [x] `piecewisePolynomial` — L243
- [x] `symmetricPiecewisePolynomial` — L267
- [x] `piecewiseRational` — L282
- [x] `lookupTable_Planar8toPlanar16` — L301
- [x] `lookupTable_Planar8toPlanar24` — L306
- [x] `lookupTable_Planar8toPlanar48` — L311
- [x] `lookupTable_Planar8toPlanar96` — L316
- [x] `lookupTable_Planar8toPlanar128` — L321
- [x] `lookupTable_Planar8toPlanarF` — L326
- [x] `lookupTable_PlanarFtoPlanar8` — L331
- [x] `lookupTable_8to64U` — L336
- [x] `lookupTable_Planar16` — L341
- [x] `interpolatedLookupTable_PlanarF` — L347
- [x] `multidimensionalTableCreate` — L380
- [x] `multidimensionalTableRetain` — L393
- [x] `multidimensionalTableRelease` — L398
- [x] `multiDimensionalInterpolatedLookupTable` — L403
- [x] `floodFill_Planar8` — L424
- [x] `floodFill_Planar16U` — L429
- [x] `floodFill_ARGB8888` — L434
- [x] `floodFill_ARGB16U` — L439
