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

- [ ] `dotpr` — L8
- [ ] `dotpr2` — L35
- [ ] `zdotpr` — L46
- [ ] `zidotpr` — L56
- [ ] `zrdotpr` — L66
- [ ] `dotpr_s1_15` — L92
- [ ] `dotpr2_s1_15` — L119
- [ ] `dotpr_s8_24` — L142
- [ ] `dotpr2_s8_24` — L169

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

- [ ] `vrampmul` — L48
- [ ] `vrampmuladd` — L103
- [ ] `vrampmul2` — L167
- [ ] `vrampmuladd2` — L231
- [ ] `vrampmul_s1_15` — L288
- [ ] `vrampmuladd_s1_15` — L339
- [ ] `vrampmul2_s1_15` — L398
- [ ] `vrampmuladd2_s1_15` — L458
- [ ] `vrampmul_s8_24` — L511
- [ ] `vrampmuladd_s8_24` — L562
- [ ] `vrampmul2_s8_24` — L621
- [ ] `vrampmuladd2_s8_24` — L681

### `src/vdsp/reduction.zig`

- [x] `ValueIndex` — L6
- [x] `NormResult` — L10
- [ ] `sve` — L19
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
- [ ] `Complex` — L13
- [ ] `Complex(T).init` — L20
- [ ] `Complex(T).fromStd` — L24
- [ ] `Complex(T).toStd` — L28
- [ ] `Int24.from` — L37
- [ ] `Int24.to` — L41
- [ ] `Int24.toI32` — L45
- [ ] `UInt24.from` — L53
- [ ] `UInt24.to` — L57
- [ ] `UInt24.toU32` — L61

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

- [ ] `vaddsub` — L39

### `src/vdsp/vecop.zig`

- [x] `vfill` — L14
- [ ] `vadd` — L31
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

- [ ] `rec` — L20
- [ ] `div` — L31
- [ ] `sqrt` — L43
- [ ] `cbrt` — L54
- [ ] `rsqrt` — L65
- [ ] `exp` — L80
- [ ] `exp2` — L91
- [ ] `expm1` — L102
- [ ] `log` — L117
- [ ] `log10` — L128
- [ ] `log2` — L139
- [ ] `log1p` — L150
- [ ] `logb` — L161
- [ ] `pow` — L176
- [ ] `pows` — L189
- [ ] `fabs` — L205
- [ ] `sin` — L220
- [ ] `cos` — L231
- [ ] `tan` — L242
- [ ] `sinpi` — L253
- [ ] `cospi` — L264
- [ ] `tanpi` — L275
- [ ] `sincos` — L286
- [ ] `asin` — L302
- [ ] `acos` — L313
- [ ] `atan` — L324
- [ ] `atan2` — L335
- [ ] `sinh` — L351
- [ ] `cosh` — L362
- [ ] `tanh` — L373
- [ ] `asinh` — L388
- [ ] `acosh` — L399
- [ ] `atanh` — L410
- [ ] `trunc` — L425
- [ ] `nint` — L436
- [ ] `ceil` — L447
- [ ] `floor` — L458
- [ ] `fmod` — L473
- [ ] `remainder` — L485
- [ ] `copysign` — L501
- [ ] `nextafter` — L513
- [ ] `cosisin` — L529

## vImage

### `src/vimage/alpha.zig`

- [ ] `alphaBlendPlanar` — L19
- [ ] `alphaBlendARGB` — L31
- [ ] `premultipliedAlphaBlendPlanar` — L48
- [ ] `premultipliedAlphaBlendARGB` — L57
- [ ] `premultipliedAlphaBlendBGRA` — L66
- [ ] `premultipliedAlphaBlendWithPermuteARGB` — L76
- [ ] `premultipliedAlphaBlendWithPermuteRGBA` — L82
- [ ] `premultipliedAlphaBlendRGBA` — L100
- [ ] `premultipliedConstAlphaBlendPlanar` — L118
- [ ] `premultipliedConstAlphaBlendARGB` — L128
- [ ] `alphaBlendNonpremultipliedToPremultipliedPlanar` — L142
- [ ] `alphaBlendNonpremultipliedToPremultipliedARGB` — L152
- [ ] `premultiplyDataPlanar` — L168
- [ ] `premultiplyDataARGB` — L177
- [ ] `premultiplyDataRGBA` — L186
- [ ] `premultiplyDataARGB16U` — L195
- [ ] `premultiplyDataRGBA16U` — L200
- [ ] `premultiplyDataARGB16Q12` — L205
- [ ] `premultiplyDataRGBA16Q12` — L210
- [ ] `premultiplyDataRGBA16F` — L215
- [ ] `unpremultiplyDataPlanar` — L228
- [ ] `unpremultiplyDataARGB` — L237
- [ ] `unpremultiplyDataRGBA` — L246
- [ ] `unpremultiplyDataARGB16U` — L255
- [ ] `unpremultiplyDataRGBA16U` — L260
- [ ] `unpremultiplyDataARGB16Q12` — L265
- [ ] `unpremultiplyDataRGBA16Q12` — L270
- [ ] `unpremultiplyDataRGBA16F` — L275
- [ ] `clipToAlphaPlanar` — L287
- [ ] `clipToAlphaARGB` — L297
- [ ] `clipToAlphaRGBA` — L307

### `src/vimage/conversion.zig`

- [ ] `clipPlanarF` — L21
- [ ] `planar8ToPlanarF` — L32
- [ ] `planarFToPlanar8` — L39
- [ ] `planar16FToPlanarF` — L44
- [ ] `planarFToPlanar16F` — L49
- [ ] `planar8ToPlanar16F` — L54
- [ ] `planar16FToPlanar8` — L59
- [ ] `convert16SToF` — L66
- [ ] `convert16UToF` — L73
- [ ] `convertFTo16S` — L80
- [ ] `convertFTo16U` — L87
- [ ] `convert16UToPlanar8` — L94
- [ ] `planar8To16U` — L99
- [ ] `planar8ToARGB8888` — L108
- [ ] `planarFToARGBFFFF` — L120
- [ ] `argb8888ToPlanar8` — L136
- [ ] `argbFFFFToPlanarF` — L148
- [ ] `planar8ToARGBFFFF` — L164
- [ ] `argb8888ToPlanarF` — L178
- [ ] `argbFFFFToPlanar8` — L192
- [ ] `planarFToARGB8888` — L206
- [ ] `planar8ToRGB888` — L224
- [ ] `planarFToRGBFFF` — L235
- [ ] `rgb888ToPlanar8` — L246
- [ ] `rgbFFFToPlanarF` — L257
- [ ] `rgb888ToInterleaved8888` — L287
- [ ] `interleaved8888ToRGB888` — L304
- [ ] `interleavedFFFFToRGBFFF` — L322
- [ ] `rgbFFFToInterleavedFFFF` — L340
- [ ] `flatten8888ToRGB888` — L358
- [ ] `flattenFFFFToRGBFFF` — L375
- [ ] `permuteChannelsARGB8888` — L398
- [ ] `permuteChannelsARGB16U` — L403
- [ ] `permuteChannelsARGBFFFF` — L408
- [ ] `permuteChannelsRGB888` — L416
- [ ] `extractChannelARGB8888` — L427
- [ ] `extractChannelARGB16U` — L432
- [ ] `extractChannelARGBFFFF` — L437
- [ ] `overwriteChannelsARGB8888` — L456
- [ ] `overwriteChannelsARGBFFFF` — L461
- [ ] `overwriteScalarPlanar8` — L466
- [ ] `overwriteScalarPlanarF` — L471
- [ ] `overwriteScalarARGB8888` — L476
- [ ] `overwriteScalarARGBFFFF` — L481
- [ ] `overwritePixelARGB8888` — L486
- [ ] `overwritePixelARGBFFFF` — L491
- [ ] `selectChannelsARGB8888` — L500
- [ ] `selectChannelsARGBFFFF` — L505
- [ ] `fillARGB8888` — L514
- [ ] `fillARGBFFFF` — L519
- [ ] `tableLookUpARGB8888` — L530
- [ ] `tableLookUpPlanar8` — L551
- [ ] `copyBuffer` — L562

### `src/vimage/convolution.zig`

- [ ] `convolvePlanar` — L25
- [ ] `convolveInterleaved` — L53
- [ ] `convolveWithBiasPlanar` — L85
- [ ] `convolveWithBiasInterleaved` — L110
- [ ] `convolveMultiKernelInterleaved` — L142
- [ ] `richardsonLucyDeConvolvePlanar` — L177
- [ ] `richardsonLucyDeConvolveInterleaved` — L205
- [ ] `boxConvolvePlanar8` — L241
- [ ] `boxConvolveARGB8888` — L256
- [ ] `tentConvolvePlanar8` — L281
- [ ] `tentConvolveARGB8888` — L296

### `src/vimage/geometry.zig`

- [ ] `rotate` — L47
- [ ] `scale` — L81
- [ ] `horizontalReflect` — L111
- [ ] `verticalReflect` — L134
- [ ] `rotate90` — L177
- [ ] `affineWarp` — L215
- [ ] `affineWarpD` — L244
- [ ] `affineWarpCG` — L273
- [ ] `horizontalShear` — L307
- [ ] `verticalShear` — L340
- [ ] `newResamplingFilter` — L380
- [ ] `destroyResamplingFilter` — L385

### `src/vimage/histogram.zig`

- [ ] `histogramCalculation_Planar8` — L25
- [ ] `histogramCalculation_PlanarF` — L37
- [ ] `histogramCalculation_ARGB8888` — L51
- [ ] `histogramCalculation_ARGBFFFF` — L63
- [ ] `histogramCalculation` — L78
- [ ] `equalization_Planar8` — L119
- [ ] `equalization_PlanarF` — L131
- [ ] `equalization_ARGB8888` — L144
- [ ] `equalization_ARGBFFFF` — L153
- [ ] `equalization` — L166
- [ ] `histogramSpecification_Planar8` — L212
- [ ] `histogramSpecification_PlanarF` — L222
- [ ] `histogramSpecification_ARGB8888` — L239
- [ ] `histogramSpecification_ARGBFFFF` — L249
- [ ] `histogramSpecification` — L263
- [ ] `contrastStretch_Planar8` — L310
- [ ] `contrastStretch_PlanarF` — L319
- [ ] `contrastStretch_ARGB8888` — L332
- [ ] `contrastStretch_ARGBFFFF` — L341
- [ ] `contrastStretch` — L354
- [ ] `endsInContrastStretch_Planar8` — L400
- [ ] `endsInContrastStretch_PlanarF` — L411
- [ ] `endsInContrastStretch_ARGB8888` — L428
- [ ] `endsInContrastStretch_ARGBFFFF` — L439
- [ ] `endsInContrastStretch` — L454

### `src/vimage/morphology.zig`

- [ ] `dilate` — L32
- [ ] `erode` — L63
- [ ] `max` — L95
- [ ] `min` — L127

### `src/vimage/transform.zig`

- [ ] `matrixMultiplyPlanar` — L27
- [ ] `matrixMultiplyPlanar16S` — L66
- [ ] `matrixMultiplyARGB` — L96
- [ ] `matrixMultiplyARGBToPlanar` — L117
- [ ] `createGammaFunction` — L155
- [ ] `destroyGammaFunction` — L160
- [ ] `gammaPlanarF` — L165
- [ ] `gammaPlanar8toPlanarF` — L170
- [ ] `gammaPlanarFtoPlanar8` — L175
- [ ] `piecewiseGamma` — L187
- [ ] `symmetricPiecewiseGamma` — L218
- [ ] `piecewisePolynomial` — L243
- [ ] `symmetricPiecewisePolynomial` — L267
- [ ] `piecewiseRational` — L282
- [ ] `lookupTable_Planar8toPlanar16` — L301
- [ ] `lookupTable_Planar8toPlanar24` — L306
- [ ] `lookupTable_Planar8toPlanar48` — L311
- [ ] `lookupTable_Planar8toPlanar96` — L316
- [ ] `lookupTable_Planar8toPlanar128` — L321
- [ ] `lookupTable_Planar8toPlanarF` — L326
- [ ] `lookupTable_PlanarFtoPlanar8` — L331
- [ ] `lookupTable_8to64U` — L336
- [ ] `lookupTable_Planar16` — L341
- [ ] `interpolatedLookupTable_PlanarF` — L347
- [ ] `multidimensionalTableCreate` — L380
- [ ] `multidimensionalTableRetain` — L393
- [ ] `multidimensionalTableRelease` — L398
- [ ] `multiDimensionalInterpolatedLookupTable` — L403
- [ ] `floodFill_Planar8` — L424
- [ ] `floodFill_Planar16U` — L429
- [ ] `floodFill_ARGB8888` — L434
- [ ] `floodFill_ARGB16U` — L439
