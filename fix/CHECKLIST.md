# 공개 함수 체크리스트

이 문서는 `src` 아래 Zig 소스에서 확인한 공개 함수 목록입니다. 각 항목의 숫자는 선언 위치의 줄 번호입니다. `src/vdsp/root.zig`와 `src/root.zig`의 재-export는 원본 선언과 중복해서 세지 않았습니다.

- 직접 선언된 `pub fn`: 474개
- 공개 callable `pub const` 멤버: 2개
- 체크리스트 항목 합계: 476개

## vDSP

### `src/vdsp/biquad.zig`

- [ ] `Biquad` — L23
- [ ] `Biquad(T).init` — L38
- [ ] `Biquad(T).deinit` — L56
- [ ] `Biquad(T).apply` — L72
- [ ] `Biquad(T).setCoefficientsDouble` — L84 (callable `pub const`)
- [ ] `Biquad(T).setCoefficientsSingle` — L97 (callable `pub const`)
- [ ] `Biquadm` — L112
- [ ] `Biquadm(T).init` — L134
- [ ] `Biquadm(T).deinit` — L148
- [ ] `Biquadm(T).apply` — L157
- [ ] `Biquadm(T).resetState` — L166
- [ ] `Biquadm(T).copyState` — L176
- [ ] `Biquadm(T).setCoefficientsDouble` — L187
- [ ] `Biquadm(T).setCoefficientsSingle` — L198
- [ ] `Biquadm(T).setTargetsDouble` — L209
- [ ] `Biquadm(T).setTargetsSingle` — L220
- [ ] `Biquadm(T).setActiveFilters` — L229

### `src/vdsp/clip.zig`

- [ ] `vclr` — L11
- [ ] `vcmprs` — L27
- [ ] `vclip` — L45
- [ ] `vclipc` — L63
- [ ] `viclip` — L74
- [ ] `vthr` — L82
- [ ] `vthres` — L90
- [ ] `vlim` — L98
- [ ] `vmax` — L108
- [ ] `vmin` — L116
- [ ] `vmaxmg` — L124
- [ ] `vminmg` — L132

### `src/vdsp/conv.zig`

- [ ] `conv` — L15
- [ ] `imgfir` — L40
- [ ] `f3x3` — L62
- [ ] `f5x5` — L84
- [ ] `deq22` — L92
- [ ] `zconv` — L111

### `src/vdsp/convert.zig`

- [ ] `vdpsp` — L13
- [ ] `vspdp` — L17
- [ ] `vflt8` — L27
- [ ] `vflt16` — L38
- [ ] `vflt32` — L49
- [ ] `vfltu8` — L60
- [ ] `vfltu16` — L71
- [ ] `vfltu32` — L82
- [ ] `vflt24` — L96
- [ ] `vfltu24` — L104
- [ ] `vfltsm24` — L115
- [ ] `vfltsmu24` — L123
- [ ] `vsmfix24` — L138
- [ ] `vsmfixu24` — L150
- [ ] `vfix8` — L161
- [ ] `vfix16` — L172
- [ ] `vfix32` — L183
- [ ] `vfixu8` — L197
- [ ] `vfixu16` — L208
- [ ] `vfixu32` — L219
- [ ] `vfixr8` — L236
- [ ] `vfixr16` — L250
- [ ] `vfixr32` — L264
- [ ] `vfixru8` — L281
- [ ] `vfixru16` — L295
- [ ] `vfixru32` — L309
- [ ] `venvlp` — L326
- [ ] `vdbcon` — L345
- [ ] `polar` — L355
- [ ] `rect` — L363

### `src/vdsp/dft.zig`

- [ ] `DFT` — L36
- [ ] `DFT(T).init` — L48
- [ ] `DFT(T).initShared` — L58
- [ ] `DFT(T).deinit` — L68
- [ ] `DFT(T).exec` — L76
- [ ] `RealDFT` — L88
- [ ] `RealDFT(T).init` — L100
- [ ] `RealDFT(T).deinit` — L110
- [ ] `RealDFT(T).exec` — L118
- [ ] `DCT.init` — L132
- [ ] `DCT.deinit` — L136
- [ ] `DCT.exec` — L140
- [ ] `InterleavedDFT` — L147
- [ ] `InterleavedDFT(T).init` — L160
- [ ] `InterleavedDFT(T).deinit` — L171
- [ ] `InterleavedDFT(T).exec` — L179

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

- [ ] `ctoz` — L38
- [ ] `ztoc` — L54
- [ ] `FFT` — L70
- [ ] `FFT(T).init` — L84
- [ ] `FFT(T).deinit` — L98
- [ ] `FFT(T).zip` — L132
- [ ] `FFT(T).zipt` — L148
- [ ] `FFT(T).zop` — L180
- [ ] `FFT(T).zopt` — L196
- [ ] `FFT(T).zrip` — L217
- [ ] `FFT(T).zript` — L232
- [ ] `FFT(T).zrop` — L251
- [ ] `FFT(T).zropt` — L266
- [ ] `FFT(T).zip2d` — L279
- [ ] `FFT(T).zipt2d` — L294
- [ ] `FFT(T).zop2d` — L305
- [ ] `FFT(T).zopt2d` — L320
- [ ] `FFT(T).zrip2d` — L339
- [ ] `FFT(T).zript2d` — L354
- [ ] `FFT(T).zrop2d` — L371
- [ ] `FFT(T).zropt2d` — L386
- [ ] `FFT(T).mzip` — L401
- [ ] `FFT(T).mzipt` — L415
- [ ] `FFT(T).mzop` — L428
- [ ] `FFT(T).mzopt` — L442
- [ ] `FFT(T).mzrip` — L457
- [ ] `FFT(T).mzript` — L472
- [ ] `FFT(T).mzrop` — L487
- [ ] `FFT(T).mzropt` — L502

### `src/vdsp/fixed_fft.zig`

- [ ] `fft16_copv` — L44
- [ ] `fft32_copv` — L87
- [ ] `fft16_zopv` — L131
- [ ] `fft32_zopv` — L175

### `src/vdsp/matrix.zig`

- [ ] `mmul` — L25
- [ ] `mtrans` — L50
- [ ] `zmma` — L73
- [ ] `zmms` — L96
- [ ] `zmsm` — L119
- [ ] `zmmul` — L141
- [ ] `zvmmaa` — L157

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

- [ ] `ValueIndex` — L6
- [ ] `NormResult` — L10
- [ ] `sve` — L19
- [ ] `svesq` — L32
- [ ] `sve_svesq` — L46
- [ ] `svemg` — L60
- [ ] `meanv` — L75
- [ ] `meamgv` — L88
- [ ] `measqv` — L101
- [ ] `rmsqv` — L114
- [ ] `maxv` — L129
- [ ] `maxvi` — L143
- [ ] `maxmgv` — L157
- [ ] `maxmgvi` — L171
- [ ] `minv` — L187
- [ ] `minvi` — L201
- [ ] `minmgv` — L215
- [ ] `minmgvi` — L229
- [ ] `normalize` — L251
- [ ] `mmov` — L272
- [ ] `mvessq` — L285
- [ ] `nzcros` — L309
- [ ] `svs` — L325

### `src/vdsp/types.zig`

- [ ] `SplitComplex` — L6
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

- [ ] `vrvrs` — L18
- [ ] `vswap` — L32
- [ ] `vsort` — L44
- [ ] `vsorti` — L60
- [ ] `vramp` — L78
- [ ] `vgen` — L92
- [ ] `vgathr` — L110
- [ ] `vindex` — L124
- [ ] `vgathra` — L138
- [ ] `vthrsc` — L159
- [ ] `vtabi` — L189
- [ ] `vtmerg` — L207
- [ ] `wiener` — L220
- [ ] `vlint` — L244
- [ ] `vqint` — L263
- [ ] `vintb` — L277
- [ ] `vgenp` — L297
- [ ] `vpoly` — L313
- [ ] `vrsum` — L333
- [ ] `vsimps` — L349
- [ ] `vtrapz` — L364
- [ ] `vswsum` — L380
- [ ] `vswmax` — L403
- [ ] `blkman_window` — L415
- [ ] `hamm_window` — L423
- [ ] `hann_window` — L431

### `src/vdsp/vaddsub.zig`

- [ ] `vaddsub` — L39

### `src/vdsp/vecop.zig`

- [ ] `vfill` — L14
- [ ] `vadd` — L31
- [x] `vsub` — L46
- [ ] `vmul` — L60
- [x] `vdiv` — L74
- [ ] `veqvi` — L89
- [ ] `vsmul` — L103
- [ ] `vsadd` — L116
- [ ] `vsdiv` — L130
- [ ] `svdiv` — L141
- [ ] `vma` — L158
- [ ] `vmsa` — L170
- [ ] `vsma` — L181
- [ ] `vam` — L195
- [ ] `vmsb` — L207
- [ ] `vmma` — L219
- [ ] `vmmsb` — L232
- [ ] `vsmsa` — L245
- [ ] `vsmsb` — L255
- [ ] `vsmsma` — L266
- [ ] `vaam` — L281
- [ ] `vasbm` — L294
- [ ] `vasm` — L307
- [ ] `vsbm` — L322
- [ ] `vsbsbm` — L334
- [ ] `vsbsm` — L347
- [ ] `vavlin` — L362
- [ ] `vpythg` — L376
- [ ] `vsq` — L396
- [ ] `vssq` — L409
- [ ] `vabs` — L422
- [ ] `vneg` — L432
- [ ] `vnabs` — L442
- [ ] `vfrac` — L451
- [ ] `vdist` — L460
- [ ] `distancesq` — L473

### `src/vdsp/zvecop.zig`

- [ ] `zvadd` — L16
- [ ] `zrvadd` — L28
- [ ] `zvsub` — L40
- [ ] `zrvsub` — L52
- [ ] `zrvmul` — L64
- [x] `zvdiv` — L76
- [ ] `zrvdiv` — L88
- [ ] `zvabs` — L100
- [ ] `zvfill` — L112
- [ ] `zvmul` — L128
- [ ] `zvcma` — L140
- [ ] `zvma` — L152
- [ ] `zvcmul` — L164
- [ ] `zvconj` — L176
- [ ] `zvzsml` — L188
- [ ] `zvmags` — L200
- [ ] `zvmgsa` — L212
- [ ] `zvmov` — L224
- [ ] `zvneg` — L236
- [ ] `zvphas` — L248
- [ ] `zvsma` — L260
- [ ] `zaspec` — L276
- [ ] `zcoher` — L288
- [ ] `ztrans` — L300
- [ ] `zcspec` — L312
- [ ] `desamp` — L324
- [ ] `zrdesamp` — L336

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
