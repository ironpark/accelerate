//! Chroma-subsampled Y'CbCr (YUV) video formats: 4:2:0, 4:2:2 and 4:4:4, in 8,
//! 10 and 16 bits per component, converted to and from interleaved ARGB8888,
//! ARGB16U and ARGB16Q12.
//!
//! Every entry point here takes a *precomputed conversion*: an opaque
//! `YpCbCrToARGB` or `ARGBToYpCbCr` built once by `ypCbCrToARGBGenerateConversion`
//! / `argbToYpCbCrGenerateConversion` from a 3x3 matrix (`ypCbCrToARGBMatrix601()`
//! and friends) plus a `YpCbCrPixelRange`. The generated info is immutable and
//! may be shared across threads; generating one per frame is the classic misuse.
//!
//! ## Pixel range
//!
//! Y'CbCr almost never uses the full code range. An 8-bit "video range" signal
//! encodes Y' = 0.0 as 16 and Y' = 1.0 as 235, and CbCr = 0.0 as 128 with
//! CbCr = +/-0.5 at 128 +/- 112. `YpCbCrPixelRange` carries those four encoding
//! points plus four clamping limits. The bias is a *pre*-bias going YUV -> RGB
//! and a *post*-bias going RGB -> YUV. Scale the numbers with the bit depth:
//! 8-bit {16,128,235,240,...}, 10-bit {64,512,940,960,...}, 16-bit
//! {4096,32768,60160,61440,...} (the 16-bit formats are left-justified, i.e.
//! the 8-bit value shifted up by 8).
//!
//! ## Plane sizing
//!
//! `width` and `height` on *every* buffer passed here - including the packed
//! ones - are counted in **luma pixels**, i.e. in output ARGB pixels. What
//! changes is `rowBytes`:
//!
//!   * 4:4:4 8-bit  (`v308`, `y408`/`r408`, `v408`): 3 or 4 bytes per pixel.
//!   * 4:4:4 10-bit (`v410`): one 32-bit little-endian word per pixel, packed
//!     `Cr:10 | Yp:10 | Cb:10 | xx:2`, i.e. `Cr << 22 | Yp << 12 | Cb << 2`.
//!   * 4:4:4 16-bit (`y416`): four little-endian `uint16_t` per pixel, A Yp Cb Cr.
//!   * 4:2:2 8-bit  (`2vuy`, `yuvs`): 4 bytes per *two* pixels, so 2 bytes per
//!     pixel; width must be even.
//!   * 4:2:2 16-bit (`v216`): 8 bytes per two pixels - Cb Y0 Cr Y1 as LE 16-bit.
//!   * 4:2:2 10-bit (`v210`): 16 bytes per **six** pixels (four 32-bit words
//!     holding twelve 10-bit components), so width must be a multiple of 6.
//!   * 4:2:0 (`420v`/`420f`, `y420`/`f420`): the luma plane is full size; the
//!     chroma plane(s) are **half width and half height**. Getting that wrong
//!     is the classic bug - a `Cb8` plane for a 4x4 image is 2x2, not 4x4.
//!     The tri-planar form takes separate Cb and Cr planes; the bi-planar form
//!     takes one interleaved CbCr plane of half width and 2 bytes per element.
//!
//! ## permuteMap
//!
//! Every conversion takes a 4-byte `permuteMap` that reorders the ARGB side
//! only. `{0,1,2,3}` is ARGB, `{3,2,1,0}` is BGRA, `{1,2,3,0}` is RGBA. It
//! never reorders the Y'CbCr side - the channel order there is fixed by the
//! format name.
//!
//! ## ARGB16Q12
//!
//! The 16Q12 destinations are signed 16-bit fixed point with 12 fractional
//! bits: 1.0 is 4096, and the format deliberately has headroom on both sides so
//! out-of-gamut Y'CbCr survives the trip.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const vImage_Flags = types.vImage_Flags;
const VImageError = types.VImageError;
const check = types.check;
const Flags = types.Flags;
const Pixel_8 = types.Pixel_8;
const Pixel_16U = types.Pixel_16U;
const Pixel_16Q12 = types.Pixel_16Q12;
const vImageARGBType = types.vImageARGBType;
const vImageYpCbCrType = types.vImageYpCbCrType;
const vImage_YpCbCrToARGBMatrix = types.vImage_YpCbCrToARGBMatrix;
const vImage_ARGBToYpCbCrMatrix = types.vImage_ARGBToYpCbCrMatrix;

// ============================================================================
// Conversion-info types
// ============================================================================
//
// These live in types.zig and are re-exported here for convenience. Their sizes
// were measured against Accelerate.h: the pixel range is eight `int32_t` (32
// bytes) and each conversion info is `uint8_t opaque[128]` aligned to 16. All
// three were declared at half that size here until this module was written, so
// the layout test in types.zig pins them.

/// Encoding and clamping limits for a Y'CbCr format.
///
/// `Yp_bias` / `CbCr_bias` are the codes for Y' = 0.0 and CbCr = 0.0;
/// `YpRangeMax` / `CbCrRangeMax` are the codes for Y' = 1.0 and CbCr = 0.5.
/// The four `Max`/`Min` fields are hard clamps applied to the Y'CbCr side;
/// setting them to the full representable range is fastest, setting them to the
/// signal range refuses to emit out-of-range codes.
pub const YpCbCrPixelRange = types.vImage_YpCbCrPixelRange;

/// Opaque, precomputed Y'CbCr -> ARGB conversion. Build with
/// `ypCbCrToARGBGenerateConversion`; treat the contents as write-once.
pub const YpCbCrToARGB = types.vImage_YpCbCrToARGB;

/// Opaque, precomputed ARGB -> Y'CbCr conversion. Build with
/// `argbToYpCbCrGenerateConversion`; treat the contents as write-once.
pub const ARGBToYpCbCr = types.vImage_ARGBToYpCbCr;

// ============================================================================
// Standard matrices
// ============================================================================
//
// The framework exports these as *pointers to* matrices, and the exported
// symbol is the pointer, not the matrix. The `extern var` declarations live in
// c.zig so the link test covers them; these accessors just read them. They are
// functions rather than constants because the value is only known at load time.

/// ITU-R BT.601-4 Y'CbCr -> R'G'B' matrix (standard-definition video).
pub inline fn ypCbCrToARGBMatrix601() *const vImage_YpCbCrToARGBMatrix {
    return c.kvImage_YpCbCrToARGBMatrix_ITU_R_601_4;
}
/// ITU-R BT.709-2 Y'CbCr -> R'G'B' matrix (high-definition video).
pub inline fn ypCbCrToARGBMatrix709() *const vImage_YpCbCrToARGBMatrix {
    return c.kvImage_YpCbCrToARGBMatrix_ITU_R_709_2;
}
/// ITU-R BT.601-4 R'G'B' -> Y'CbCr matrix (standard-definition video).
pub inline fn argbToYpCbCrMatrix601() *const vImage_ARGBToYpCbCrMatrix {
    return c.kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4;
}
/// ITU-R BT.709-2 R'G'B' -> Y'CbCr matrix (high-definition video).
pub inline fn argbToYpCbCrMatrix709() *const vImage_ARGBToYpCbCrMatrix {
    return c.kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2;
}

// Bridges to the c.zig parameter spellings. Now that types.zig carries the
// measured layouts these are identity casts, kept so the call sites below read
// the same either way.

inline fn cRange(r: *const YpCbCrPixelRange) *const c.vImage_YpCbCrPixelRange {
    return @ptrCast(r);
}
inline fn cToARGB(i: *const YpCbCrToARGB) *const c.vImage_YpCbCrToARGB {
    return @ptrCast(i);
}
inline fn cToARGBMut(i: *YpCbCrToARGB) *c.vImage_YpCbCrToARGB {
    return @ptrCast(i);
}
inline fn cToYUV(i: *const ARGBToYpCbCr) *const c.vImage_ARGBToYpCbCr {
    return @ptrCast(i);
}
inline fn cToYUVMut(i: *ARGBToYpCbCr) *c.vImage_ARGBToYpCbCr {
    return @ptrCast(i);
}

// ============================================================================
// Conversion info generation
// ============================================================================

/// Precompute a Y'CbCr -> ARGB conversion.
///
/// `matrix` is a 3x3 decode matrix (`ypCbCrToARGBMatrix601()`
/// for SD video, `..._709_2` for HD); `pixelRange` describes how the source
/// codes map onto Y' in [0,1] and CbCr in [-0.5,0.5]. `outInfo` is fully
/// overwritten and can then be shared by any number of concurrent conversions.
///
/// Not every (Y'CbCr depth, ARGB depth) pair exists. Per Conversion.h: 8-bit
/// YUV only reaches ARGB8888; 10- and 12-bit reach ARGB8888 and ARGB16Q12;
/// 14- and 16-bit reach ARGB8888 and ARGB16U. Anything else returns
/// `UnsupportedConversion`.
pub fn ypCbCrToARGBGenerateConversion(
    matrix: *const vImage_YpCbCrToARGBMatrix,
    pixelRange: *const YpCbCrPixelRange,
    outInfo: *YpCbCrToARGB,
    inYpCbCrType: vImageYpCbCrType,
    outARGBType: vImageARGBType,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_YpCbCrToARGB_GenerateConversion(matrix, cRange(pixelRange), cToARGBMut(outInfo), inYpCbCrType, outARGBType, flags));
}

/// Precompute an ARGB -> Y'CbCr conversion.
///
/// The mirror of `ypCbCrToARGBGenerateConversion`; note the argument order is
/// `(inARGBType, outYpCbCrType)`, i.e. source type first in both functions even
/// though that flips which side is Y'CbCr. `pixelRange` here controls the
/// *output* encoding, and its `Max`/`Min` fields decide whether out-of-range
/// chroma is clamped into the signal range or merely into the code range.
pub fn argbToYpCbCrGenerateConversion(
    matrix: *const vImage_ARGBToYpCbCrMatrix,
    pixelRange: *const YpCbCrPixelRange,
    outInfo: *ARGBToYpCbCr,
    inARGBType: vImageARGBType,
    outYpCbCrType: vImageYpCbCrType,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_ARGBToYpCbCr_GenerateConversion(matrix, cRange(pixelRange), cToYUVMut(outInfo), inARGBType, outYpCbCrType, flags));
}

// ============================================================================
// 4:2:2, 8 bit  ('yuvs' / 'yuvf', '2vuy' / '2vuf', 'a2vy')
// ============================================================================

/// `Yp0 Cb0 Yp1 Cr0` -> two ARGB8888 pixels ('yuvs'/'yuvf').
///
/// `src` is 2 bytes per pixel; `src.width` counts luma pixels and must be even.
/// One chroma pair serves both pixels of each horizontal couple. `alpha` is a
/// constant written into every destination alpha, since the format carries none.
pub fn convert422YpCbYpCr8ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_422YpCbYpCr8ToARGB8888(src, dest, cToARGB(info), permuteMap, alpha, flags));
}

/// Two ARGB8888 pixels -> `Yp0 Cb0 Yp1 Cr0` ('yuvs'/'yuvf').
///
/// Chroma is subsampled by averaging the horizontal pair, so this is lossy;
/// source alpha is discarded. `dest` is 2 bytes per pixel and `dest.width` must
/// be even.
pub fn convertARGB8888To422YpCbYpCr8(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB8888To422YpCbYpCr8(src, dest, cToYUV(info), permuteMap, flags));
}

/// `Cb0 Yp0 Cr0 Yp1` -> two ARGB8888 pixels ('2vuy'/'2vuf').
///
/// Same geometry as `convert422YpCbYpCr8ToARGB8888`; only the byte order within
/// the 4-byte group differs (chroma first). `alpha` fills the destination alpha.
pub fn convert422CbYpCrYp8ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_422CbYpCrYp8ToARGB8888(src, dest, cToARGB(info), permuteMap, alpha, flags));
}

/// Two ARGB8888 pixels -> `Cb0 Yp0 Cr0 Yp1` ('2vuy'/'2vuf'). Lossy in chroma;
/// alpha is dropped. `dest.width` must be even.
pub fn convertARGB8888To422CbYpCrYp8(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB8888To422CbYpCrYp8(src, dest, cToYUV(info), permuteMap, flags));
}

/// `Cb0 Yp0 Cr0 Yp1` plus a separate 8-bit alpha plane -> ARGB8888 ('a2vy').
///
/// `srcA` is a full-resolution Planar8 buffer (one byte per output pixel, *not*
/// subsampled) and supplies the destination alpha, so there is no `alpha`
/// argument. Alpha is straight, not premultiplied.
pub fn convert422CbYpCrYp8_AA8ToARGB8888(src: *const vImage_Buffer, srcA: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_422CbYpCrYp8_AA8ToARGB8888(src, srcA, dest, cToARGB(info), permuteMap, flags));
}

/// ARGB8888 -> `Cb0 Yp0 Cr0 Yp1` plus a full-resolution 8-bit alpha plane ('a2vy').
///
/// `dest` gets the 4:2:2 chroma/luma at 2 bytes per pixel; `destA` gets one
/// alpha byte per pixel at full resolution. Alpha is copied through unchanged.
pub fn convertARGB8888To422CbYpCrYp8_AA8(src: *const vImage_Buffer, dest: *const vImage_Buffer, destA: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB8888To422CbYpCrYp8_AA8(src, dest, destA, cToYUV(info), permuteMap, flags));
}

// ============================================================================
// 4:2:0, 8 bit  ('y420' / 'f420' tri-planar, '420v' / '420f' bi-planar)
// ============================================================================

/// Tri-planar 4:2:0 -> ARGB8888 ('y420'/'f420').
///
/// `srcYp` is full resolution; `srcCb` and `srcCr` are each **half width and
/// half height**, one byte per element. A single chroma sample serves a 2x2
/// luma quad, so both `srcYp.width` and `srcYp.height` must be even. `alpha`
/// fills the destination alpha.
pub fn convert420Yp8_Cb8_Cr8ToARGB8888(srcYp: *const vImage_Buffer, srcCb: *const vImage_Buffer, srcCr: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(srcYp, srcCb, srcCr, dest, cToARGB(info), permuteMap, alpha, flags));
}

/// ARGB8888 -> tri-planar 4:2:0 ('y420'/'f420').
///
/// `destYp` is full resolution; `destCb` and `destCr` are half width and half
/// height. Chroma is averaged over each 2x2 quad, so this is lossy; alpha is
/// discarded.
pub fn convertARGB8888To420Yp8_Cb8_Cr8(src: *const vImage_Buffer, destYp: *const vImage_Buffer, destCb: *const vImage_Buffer, destCr: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(src, destYp, destCb, destCr, cToYUV(info), permuteMap, flags));
}

/// Bi-planar 4:2:0 -> ARGB8888 ('420v'/'420f', the CoreVideo camera format).
///
/// `srcYp` is full resolution Planar8; `srcCbCr` is half width, half height,
/// with two interleaved bytes (`Cb Cr`) per element - so its `rowBytes` is
/// `srcYp.width` bytes, the same as the luma plane, but it has half the rows.
/// `alpha` fills the destination alpha.
pub fn convert420Yp8_CbCr8ToARGB8888(srcYp: *const vImage_Buffer, srcCbCr: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_420Yp8_CbCr8ToARGB8888(srcYp, srcCbCr, dest, cToARGB(info), permuteMap, alpha, flags));
}

/// ARGB8888 -> bi-planar 4:2:0 ('420v'/'420f').
///
/// `destYp` is full resolution; `destCbCr` is half width, half height, two
/// bytes per element. Lossy in chroma; alpha is discarded.
pub fn convertARGB8888To420Yp8_CbCr8(src: *const vImage_Buffer, destYp: *const vImage_Buffer, destCbCr: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB8888To420Yp8_CbCr8(src, destYp, destCbCr, cToYUV(info), permuteMap, flags));
}

// ============================================================================
// 4:4:4, 8 bit  ('y408' / 'r408', 'v408', 'v308')
// ============================================================================

/// `A0 Yp0 Cb0 Cr0` -> ARGB8888 ('y408'/'r408').
///
/// 4 bytes per pixel, no subsampling. The format carries its own alpha, which
/// is copied straight through (hence no `alpha` argument).
pub fn convert444AYpCbCr8ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_444AYpCbCr8ToARGB8888(src, dest, cToARGB(info), permuteMap, flags));
}

/// ARGB8888 -> `A0 Yp0 Cb0 Cr0` ('y408'/'r408'). Alpha is preserved; only the
/// colour conversion and range compression are lossy.
pub fn convertARGB8888To444AYpCbCr8(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB8888To444AYpCbCr8(src, dest, cToYUV(info), permuteMap, flags));
}

/// `Cb0 Yp0 Cr0 A0` -> ARGB8888 ('v408'). 4 bytes per pixel, alpha last,
/// copied through unchanged.
pub fn convert444CbYpCrA8ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_444CbYpCrA8ToARGB8888(src, dest, cToARGB(info), permuteMap, flags));
}

/// ARGB8888 -> `Cb0 Yp0 Cr0 A0` ('v408'). Alpha is preserved.
pub fn convertARGB8888To444CbYpCrA8(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB8888To444CbYpCrA8(src, dest, cToYUV(info), permuteMap, flags));
}

/// `Cr0 Yp0 Cb0` -> ARGB8888 ('v308').
///
/// **Three** bytes per pixel, not four, so `rowBytes` is `3 * width` at
/// minimum. The format has no alpha channel; `alpha` supplies a constant one.
pub fn convert444CrYpCb8ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_444CrYpCb8ToARGB8888(src, dest, cToARGB(info), permuteMap, alpha, flags));
}

/// ARGB8888 -> `Cr0 Yp0 Cb0` ('v308'). Three bytes per destination pixel;
/// source alpha is discarded.
pub fn convertARGB8888To444CrYpCb8(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB8888To444CrYpCb8(src, dest, cToYUV(info), permuteMap, flags));
}

// ============================================================================
// 4:4:4, 16 bit  ('y416')
// ============================================================================

/// `A0 Yp0 Cb0 Cr0` as four LE `uint16_t` -> ARGB8888 ('y416').
///
/// 8 bytes per source pixel, 4 per destination pixel; the 16-bit alpha is
/// narrowed to 8 bits. Build `info` with a 16-bit `YpCbCrPixelRange`
/// (video range is {4096, 32768, 60160, 61440, ...}).
pub fn convert444AYpCbCr16ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_444AYpCbCr16ToARGB8888(src, dest, cToARGB(info), permuteMap, flags));
}

/// ARGB8888 -> `A0 Yp0 Cb0 Cr0` as four LE `uint16_t` ('y416').
/// 8 bytes per destination pixel; the 8-bit alpha is widened to 16 bits.
pub fn convertARGB8888To444AYpCbCr16(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB8888To444AYpCbCr16(src, dest, cToYUV(info), permuteMap, flags));
}

/// `A0 Yp0 Cb0 Cr0` as four LE `uint16_t` -> ARGB16U ('y416').
/// 8 bytes per pixel on both sides; results are clamped to [0, 65535].
pub fn convert444AYpCbCr16ToARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_444AYpCbCr16ToARGB16U(src, dest, cToARGB(info), permuteMap, flags));
}

/// ARGB16U -> `A0 Yp0 Cb0 Cr0` as four LE `uint16_t` ('y416').
/// 8 bytes per pixel on both sides; alpha is preserved at full precision.
pub fn convertARGB16UTo444AYpCbCr16(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB16UTo444AYpCbCr16(src, dest, cToYUV(info), permuteMap, flags));
}

// ============================================================================
// 4:4:4, 10 bit  ('v410')
// ============================================================================

/// `v410` -> ARGB8888.
///
/// One 32-bit LE word per pixel packed `Cr << 22 | Yp << 12 | Cb << 2`; the low
/// two bits are unused. Build `info` with a 10-bit `YpCbCrPixelRange`
/// (video range is {64, 512, 940, 960, ...}). `alpha` supplies the missing
/// alpha channel.
pub fn convert444CrYpCb10ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_444CrYpCb10ToARGB8888(src, dest, cToARGB(info), permuteMap, alpha, flags));
}

/// ARGB8888 -> `v410`. 4 bytes per destination pixel; alpha is discarded.
pub fn convertARGB8888To444CrYpCb10(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB8888To444CrYpCb10(src, dest, cToYUV(info), permuteMap, flags));
}

/// `v410` -> ARGB16Q12.
///
/// The destination is signed 16.12 fixed point, so 1.0 is 4096 and values
/// outside [0,1] survive. `alpha` is likewise a 16Q12 value - pass 4096 for
/// fully opaque, not 255.
pub fn convert444CrYpCb10ToARGB16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_16Q12, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_444CrYpCb10ToARGB16Q12(src, dest, cToARGB(info), permuteMap, alpha, flags));
}

/// ARGB16Q12 -> `v410`. Source is signed 16.12 fixed point (1.0 == 4096);
/// alpha is discarded.
pub fn convertARGB16Q12To444CrYpCb10(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB16Q12To444CrYpCb10(src, dest, cToYUV(info), permuteMap, flags));
}

// ============================================================================
// 4:2:2, 10 bit  ('v210')
// ============================================================================

/// `v210` -> ARGB8888.
///
/// Twelve 10-bit components live in four 32-bit LE words and expand to **six**
/// pixels, so `rowBytes` is `16 * (width / 6)` and `width` must be a multiple
/// of 6. Word 0 holds `Cb0 | Y0 | Cr0`, word 1 `Y1 | Cb1 | Y2`, word 2
/// `Cr1 | Y3 | Cb2`, word 3 `Y4 | Cr2 | Y5`, each component in its own 10 bits
/// starting at bit 0 with the top 2 bits of each word unused. `alpha` supplies
/// the missing alpha channel.
pub fn convert422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB8888(src, dest, cToARGB(info), permuteMap, alpha, flags));
}

/// ARGB8888 -> `v210`. Width must be a multiple of 6; chroma is horizontally
/// averaged and alpha is discarded.
pub fn convertARGB8888To422CrYpCbYpCbYpCbYpCrYpCrYp10(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB8888To422CrYpCbYpCbYpCbYpCrYpCrYp10(src, dest, cToYUV(info), permuteMap, flags));
}

/// `v210` -> ARGB16Q12. Same 6-pixel-per-16-byte packing as the ARGB8888 form;
/// `alpha` is a 16Q12 value (4096 == 1.0).
pub fn convert422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_16Q12, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB16Q12(src, dest, cToARGB(info), permuteMap, alpha, flags));
}

/// ARGB16Q12 -> `v210`. Width must be a multiple of 6; alpha is discarded.
pub fn convertARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10(src, dest, cToYUV(info), permuteMap, flags));
}

// ============================================================================
// 4:2:2, 16 bit  ('v216')
// ============================================================================

/// `v216` -> ARGB8888.
///
/// Four LE `uint16_t` - `Cb Y0 Cr Y1` - cover two pixels, so 4 bytes per pixel
/// and `width` must be even. Components are left-justified 16-bit, so use a
/// 16-bit `YpCbCrPixelRange`. `alpha` supplies the missing alpha channel.
pub fn convert422CbYpCrYp16ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_422CbYpCrYp16ToARGB8888(src, dest, cToARGB(info), permuteMap, alpha, flags));
}

/// ARGB8888 -> `v216`. 4 bytes per destination pixel, width even; chroma is
/// horizontally averaged and alpha is discarded.
pub fn convertARGB8888To422CbYpCrYp16(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB8888To422CbYpCrYp16(src, dest, cToYUV(info), permuteMap, flags));
}

/// `v216` -> ARGB16U. Same packing as the ARGB8888 form; `alpha` is a 16-bit
/// constant (65535 for opaque).
pub fn convert422CbYpCrYp16ToARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_16U, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_422CbYpCrYp16ToARGB16U(src, dest, cToARGB(info), permuteMap, alpha, flags));
}

/// ARGB16U -> `v216`. 8 bytes per source pixel, 4 per destination pixel;
/// width must be even and alpha is discarded.
pub fn convertARGB16UTo422CbYpCrYp16(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_ARGB16UTo422CbYpCrYp16(src, dest, cToYUV(info), permuteMap, flags));
}

// ============================================================================
// Tests
// ============================================================================
//
// Every value-checking test below is anchored on one arithmetic fact. For an
// 8-bit ITU-R 601-4 video-range encoding, a neutral grey R = G = B = 85 gives
//
//   Y'  = 0.299*85 + 0.587*85 + 0.114*85 = 85     (the coefficients sum to 1)
//   Yp  = 16 + (235 - 16) * 85/255 = 16 + 219/3 = 16 + 73 = 89
//   Cb  = Cr = 128                                 (chroma of a grey is zero)
//
// and 85/255 = 1/3 exactly, so the encode lands on an integer and the decode
// (73 * 255/219 = 85) returns the original byte. Grey therefore also makes
// chroma subsampling a no-op, which is what lets a 4:2:0 round trip be checked
// at all. The same grey at 10 bits is Yp = 64 + 876/3 = 356, Cb = Cr = 512;
// at 16 bits Yp = 4096 + 56064/3 = 22784, Cb = Cr = 32768.

const identity_permute = [4]u8{ 0, 1, 2, 3 };

/// 8-bit video range, clamped only to the code range ("unclamped" in the header).
const range8 = YpCbCrPixelRange{
    .Yp_bias = 16,
    .CbCr_bias = 128,
    .YpRangeMax = 235,
    .CbCrRangeMax = 240,
    .YpMax = 255,
    .YpMin = 0,
    .CbCrMax = 255,
    .CbCrMin = 1,
};

/// 10-bit video range: every 8-bit code scaled by 4.
const range10 = YpCbCrPixelRange{
    .Yp_bias = 64,
    .CbCr_bias = 512,
    .YpRangeMax = 940,
    .CbCrRangeMax = 960,
    .YpMax = 1023,
    .YpMin = 0,
    .CbCrMax = 1023,
    .CbCrMin = 4,
};

/// 16-bit video range: every 8-bit code left-justified (scaled by 256).
const range16 = YpCbCrPixelRange{
    .Yp_bias = 4096,
    .CbCr_bias = 32768,
    .YpRangeMax = 60160,
    .CbCrRangeMax = 61440,
    .YpMax = 65535,
    .YpMin = 0,
    .CbCrMax = 65535,
    .CbCrMin = 256,
};

const Owned = struct {
    mem: []align(16) u8,
    buf: vImage_Buffer,

    fn init(allocator: std.mem.Allocator, width: usize, height: usize, row_bytes: usize) !Owned {
        const mem = try allocator.alignedAlloc(u8, .@"16", row_bytes * height);
        @memset(mem, 0);
        return .{
            .mem = mem,
            .buf = .{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes },
        };
    }

    fn deinit(self: Owned, allocator: std.mem.Allocator) void {
        allocator.free(self.mem);
    }

    fn row(self: Owned, y: usize) []u8 {
        return self.mem[y * self.buf.rowBytes ..][0..self.buf.rowBytes];
    }

    fn u16At(self: Owned, y: usize, index: usize) u16 {
        return std.mem.readInt(u16, self.row(y)[index * 2 ..][0..2], .little);
    }

    fn setU16(self: Owned, y: usize, index: usize, value: u16) void {
        std.mem.writeInt(u16, self.row(y)[index * 2 ..][0..2], value, .little);
    }

    fn u32At(self: Owned, y: usize, index: usize) u32 {
        return std.mem.readInt(u32, self.row(y)[index * 4 ..][0..4], .little);
    }

    fn setU32(self: Owned, y: usize, index: usize, value: u32) void {
        std.mem.writeInt(u32, self.row(y)[index * 4 ..][0..4], value, .little);
    }

    fn i16At(self: Owned, y: usize, index: usize) i16 {
        return @bitCast(self.u16At(y, index));
    }
};

/// A `width` x `height` ARGB8888 buffer filled with one colour.
fn makeARGB8888(allocator: std.mem.Allocator, width: usize, height: usize, argb: [4]u8) !Owned {
    const owned = try Owned.init(allocator, width, height, width * 4);
    var y: usize = 0;
    while (y < height) : (y += 1) {
        var x: usize = 0;
        while (x < width) : (x += 1) @memcpy(owned.row(y)[x * 4 ..][0..4], &argb);
    }
    return owned;
}

fn expectARGB8888Near(owned: Owned, x: usize, y: usize, expected: [4]u8, tol: u8) !void {
    const px = owned.row(y)[x * 4 ..][0..4];
    for (expected, 0..) |want, ch| {
        const got = px[ch];
        const diff = if (got > want) got - want else want - got;
        if (diff > tol) {
            std.debug.print("channel {d} at ({d},{d}): expected {d} +/- {d}, got {d}\n", .{ ch, x, y, want, tol, got });
            return error.TestExpectedApproxEq;
        }
    }
}

fn makeInfos(
    yuv_type: vImageYpCbCrType,
    argb_type: vImageARGBType,
    range: *const YpCbCrPixelRange,
    to_argb: *YpCbCrToARGB,
    to_yuv: *ARGBToYpCbCr,
) !void {
    try std.testing.expectEqual(@as(usize, 0), try ypCbCrToARGBGenerateConversion(ypCbCrToARGBMatrix601(), range, to_argb, yuv_type, argb_type, Flags.kvImageNoFlags));
    try std.testing.expectEqual(@as(usize, 0), try argbToYpCbCrGenerateConversion(argbToYpCbCrMatrix601(), range, to_yuv, argb_type, yuv_type, Flags.kvImageNoFlags));
}

test "GenerateConversion: ITU-R 601-4 matrices are the documented BT.601 coefficients and the generated info is non-empty" {
    // vImage_Types.h documents the decode matrix as Y' + 1.402*Cr etc. If the
    // extern global were declared as the struct rather than a pointer to it,
    // these reads would be garbage.
    const dec = ypCbCrToARGBMatrix601();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), dec.Yp, 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, 1.402), dec.Cr_R, 1e-3);
    try std.testing.expectApproxEqAbs(@as(f32, -0.714136), dec.Cr_G, 1e-3);
    try std.testing.expectApproxEqAbs(@as(f32, -0.344136), dec.Cb_G, 1e-3);
    try std.testing.expectApproxEqAbs(@as(f32, 1.772), dec.Cb_B, 1e-3);

    const enc = argbToYpCbCrMatrix601();
    try std.testing.expectApproxEqAbs(@as(f32, 0.299), enc.R_Yp, 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, 0.587), enc.G_Yp, 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, 0.114), enc.B_Yp, 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), enc.B_Cb_R_Cr, 1e-4);

    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage422CbYpCrYp8, .kvImageARGB8888, &range8, &to_argb, &to_yuv);
    // The framework must have written into the 128-byte payload.
    try std.testing.expect(!std.mem.allEqual(u8, &to_argb._opaque, 0));
    try std.testing.expect(!std.mem.allEqual(u8, &to_yuv._opaque, 0));
}

test "GenerateConversion: 8-bit Y'CbCr has no ARGB16U form, so the unsupported pair is rejected" {
    // Conversion.h's availability table: YUV8 -> RGB8 only.
    var to_argb: YpCbCrToARGB = .{};
    const result = ypCbCrToARGBGenerateConversion(ypCbCrToARGBMatrix601(), &range8, &to_argb, .kvImage422CbYpCrYp8, .kvImageARGB16U, Flags.kvImageNoFlags);
    try std.testing.expectError(VImageError.UnsupportedConversion, result);
}

test "422CbYpCrYp8 ('2vuy'): grey 85 encodes to Cb=128 Yp=89 Cr=128 Yp=89 and round trips within 1" {
    const allocator = std.testing.allocator;
    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage422CbYpCrYp8, .kvImageARGB8888, &range8, &to_argb, &to_yuv);

    const src = try makeARGB8888(allocator, 4, 2, .{ 255, 85, 85, 85 });
    defer src.deinit(allocator);
    // 4:2:2 8-bit is 2 bytes per luma pixel.
    const yuv = try Owned.init(allocator, 4, 2, 4 * 2);
    defer yuv.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), try convertARGB8888To422CbYpCrYp8(&src.buf, &yuv.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 128, 89, 128, 89, 128, 89, 128, 89 }, yuv.row(0));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 128, 89, 128, 89, 128, 89, 128, 89 }, yuv.row(1));

    const back = try makeARGB8888(allocator, 4, 2, .{ 0, 0, 0, 0 });
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convert422CbYpCrYp8ToARGB8888(&yuv.buf, &back.buf, &to_argb, &identity_permute, 200, Flags.kvImageNoFlags));
    // alpha comes from the constant, not from the source image
    try expectARGB8888Near(back, 0, 0, .{ 200, 85, 85, 85 }, 1);
    try expectARGB8888Near(back, 3, 1, .{ 200, 85, 85, 85 }, 1);
}

test "422YpCbYpCr8 ('yuvs'): luma-first byte order distinguishes it from '2vuy'" {
    const allocator = std.testing.allocator;
    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage422YpCbYpCr8, .kvImageARGB8888, &range8, &to_argb, &to_yuv);

    const src = try makeARGB8888(allocator, 2, 1, .{ 255, 85, 85, 85 });
    defer src.deinit(allocator);
    const yuv = try Owned.init(allocator, 2, 1, 4);
    defer yuv.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), try convertARGB8888To422YpCbYpCr8(&src.buf, &yuv.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
    // Yp0 Cb0 Yp1 Cr0 - the mirror of '2vuy'
    try std.testing.expectEqualSlices(u8, &[_]u8{ 89, 128, 89, 128 }, yuv.row(0));

    const back = try makeARGB8888(allocator, 2, 1, .{ 0, 0, 0, 0 });
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convert422YpCbYpCr8ToARGB8888(&yuv.buf, &back.buf, &to_argb, &identity_permute, 255, Flags.kvImageNoFlags));
    try expectARGB8888Near(back, 0, 0, .{ 255, 85, 85, 85 }, 1);
    try expectARGB8888Near(back, 1, 0, .{ 255, 85, 85, 85 }, 1);
}

test "422CbYpCrYp8 permuteMap {3,2,1,0} produces BGRA, proving the map reorders only the ARGB side" {
    const allocator = std.testing.allocator;
    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage422CbYpCrYp8, .kvImageARGB8888, &range8, &to_argb, &to_yuv);

    // Encode a saturated red so R, G and B are all different.
    const src = try makeARGB8888(allocator, 2, 1, .{ 255, 255, 0, 0 });
    defer src.deinit(allocator);
    const yuv = try Owned.init(allocator, 2, 1, 4);
    defer yuv.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convertARGB8888To422CbYpCrYp8(&src.buf, &yuv.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));

    const argb = try makeARGB8888(allocator, 2, 1, .{ 0, 0, 0, 0 });
    defer argb.deinit(allocator);
    const bgra = try makeARGB8888(allocator, 2, 1, .{ 0, 0, 0, 0 });
    defer bgra.deinit(allocator);
    _ = try convert422CbYpCrYp8ToARGB8888(&yuv.buf, &argb.buf, &to_argb, &identity_permute, 17, Flags.kvImageNoFlags);
    _ = try convert422CbYpCrYp8ToARGB8888(&yuv.buf, &bgra.buf, &to_argb, &[4]u8{ 3, 2, 1, 0 }, 17, Flags.kvImageNoFlags);

    const a = argb.row(0)[0..4];
    const b = bgra.row(0)[0..4];
    try std.testing.expectEqualSlices(u8, &[_]u8{ a[3], a[2], a[1], a[0] }, b);
    // and the ARGB order really is A R G B: red survives the trip
    try expectARGB8888Near(argb, 0, 0, .{ 17, 255, 0, 0 }, 3);
}

test "422CbYpCrYp8_AA8 ('a2vy'): the alpha plane is full resolution and passes through unchanged" {
    const allocator = std.testing.allocator;
    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage422CbYpCrYp8_AA8, .kvImageARGB8888, &range8, &to_argb, &to_yuv);

    const src = try makeARGB8888(allocator, 4, 2, .{ 73, 85, 85, 85 });
    defer src.deinit(allocator);
    const yuv = try Owned.init(allocator, 4, 2, 4 * 2);
    defer yuv.deinit(allocator);
    // one alpha byte per pixel, NOT subsampled
    const alpha = try Owned.init(allocator, 4, 2, 4);
    defer alpha.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), try convertARGB8888To422CbYpCrYp8_AA8(&src.buf, &yuv.buf, &alpha.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 128, 89, 128, 89, 128, 89, 128, 89 }, yuv.row(0));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 73, 73, 73, 73 }, alpha.row(0));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 73, 73, 73, 73 }, alpha.row(1));

    const back = try makeARGB8888(allocator, 4, 2, .{ 0, 0, 0, 0 });
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convert422CbYpCrYp8_AA8ToARGB8888(&yuv.buf, &alpha.buf, &back.buf, &to_argb, &identity_permute, Flags.kvImageNoFlags));
    try expectARGB8888Near(back, 2, 1, .{ 73, 85, 85, 85 }, 1);
}

test "420Yp8_Cb8_Cr8 ('y420'): chroma planes are half width AND half height, and grey round trips within 1" {
    const allocator = std.testing.allocator;
    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage420Yp8_Cb8_Cr8, .kvImageARGB8888, &range8, &to_argb, &to_yuv);

    const src = try makeARGB8888(allocator, 4, 4, .{ 255, 85, 85, 85 });
    defer src.deinit(allocator);
    const yp = try Owned.init(allocator, 4, 4, 4);
    defer yp.deinit(allocator);
    const cb = try Owned.init(allocator, 2, 2, 2);
    defer cb.deinit(allocator);
    const cr = try Owned.init(allocator, 2, 2, 2);
    defer cr.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), try convertARGB8888To420Yp8_Cb8_Cr8(&src.buf, &yp.buf, &cb.buf, &cr.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
    var y: usize = 0;
    while (y < 4) : (y += 1) try std.testing.expectEqualSlices(u8, &[_]u8{ 89, 89, 89, 89 }, yp.row(y));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 128, 128 }, cb.row(0));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 128, 128 }, cb.row(1));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 128, 128 }, cr.row(1));

    const back = try makeARGB8888(allocator, 4, 4, .{ 0, 0, 0, 0 });
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convert420Yp8_Cb8_Cr8ToARGB8888(&yp.buf, &cb.buf, &cr.buf, &back.buf, &to_argb, &identity_permute, 255, Flags.kvImageNoFlags));
    try expectARGB8888Near(back, 0, 0, .{ 255, 85, 85, 85 }, 1);
    try expectARGB8888Near(back, 3, 3, .{ 255, 85, 85, 85 }, 1);
}

test "420Yp8_CbCr8 ('420v'): the CbCr plane is half width, half height and 2 interleaved bytes per element" {
    const allocator = std.testing.allocator;
    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage420Yp8_CbCr8, .kvImageARGB8888, &range8, &to_argb, &to_yuv);

    const src = try makeARGB8888(allocator, 4, 4, .{ 255, 85, 85, 85 });
    defer src.deinit(allocator);
    const yp = try Owned.init(allocator, 4, 4, 4);
    defer yp.deinit(allocator);
    // 2 elements per row x 2 bytes, 2 rows
    const cbcr = try Owned.init(allocator, 2, 2, 4);
    defer cbcr.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), try convertARGB8888To420Yp8_CbCr8(&src.buf, &yp.buf, &cbcr.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 89, 89, 89, 89 }, yp.row(2));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 128, 128, 128, 128 }, cbcr.row(0));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 128, 128, 128, 128 }, cbcr.row(1));

    const back = try makeARGB8888(allocator, 4, 4, .{ 0, 0, 0, 0 });
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convert420Yp8_CbCr8ToARGB8888(&yp.buf, &cbcr.buf, &back.buf, &to_argb, &identity_permute, 255, Flags.kvImageNoFlags));
    try expectARGB8888Near(back, 1, 2, .{ 255, 85, 85, 85 }, 1);
}

test "444 8-bit: AYpCbCr8, CbYpCrA8 and CrYpCb8 differ only in component order (grey 85 -> Yp 89, chroma 128)" {
    const allocator = std.testing.allocator;
    const src = try makeARGB8888(allocator, 2, 1, .{ 60, 85, 85, 85 });
    defer src.deinit(allocator);

    {
        var to_argb: YpCbCrToARGB = .{};
        var to_yuv: ARGBToYpCbCr = .{};
        try makeInfos(.kvImage444AYpCbCr8, .kvImageARGB8888, &range8, &to_argb, &to_yuv);
        const yuv = try Owned.init(allocator, 2, 1, 2 * 4);
        defer yuv.deinit(allocator);
        try std.testing.expectEqual(@as(usize, 0), try convertARGB8888To444AYpCbCr8(&src.buf, &yuv.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
        // A Yp Cb Cr, alpha carried by the format itself
        try std.testing.expectEqualSlices(u8, &[_]u8{ 60, 89, 128, 128, 60, 89, 128, 128 }, yuv.row(0));

        const back = try makeARGB8888(allocator, 2, 1, .{ 0, 0, 0, 0 });
        defer back.deinit(allocator);
        try std.testing.expectEqual(@as(usize, 0), try convert444AYpCbCr8ToARGB8888(&yuv.buf, &back.buf, &to_argb, &identity_permute, Flags.kvImageNoFlags));
        try expectARGB8888Near(back, 1, 0, .{ 60, 85, 85, 85 }, 1);
    }
    {
        var to_argb: YpCbCrToARGB = .{};
        var to_yuv: ARGBToYpCbCr = .{};
        try makeInfos(.kvImage444CbYpCrA8, .kvImageARGB8888, &range8, &to_argb, &to_yuv);
        const yuv = try Owned.init(allocator, 2, 1, 2 * 4);
        defer yuv.deinit(allocator);
        try std.testing.expectEqual(@as(usize, 0), try convertARGB8888To444CbYpCrA8(&src.buf, &yuv.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
        // Cb Yp Cr A
        try std.testing.expectEqualSlices(u8, &[_]u8{ 128, 89, 128, 60, 128, 89, 128, 60 }, yuv.row(0));

        const back = try makeARGB8888(allocator, 2, 1, .{ 0, 0, 0, 0 });
        defer back.deinit(allocator);
        try std.testing.expectEqual(@as(usize, 0), try convert444CbYpCrA8ToARGB8888(&yuv.buf, &back.buf, &to_argb, &identity_permute, Flags.kvImageNoFlags));
        try expectARGB8888Near(back, 0, 0, .{ 60, 85, 85, 85 }, 1);
    }
    {
        var to_argb: YpCbCrToARGB = .{};
        var to_yuv: ARGBToYpCbCr = .{};
        try makeInfos(.kvImage444CrYpCb8, .kvImageARGB8888, &range8, &to_argb, &to_yuv);
        // 'v308' is THREE bytes per pixel
        const yuv = try Owned.init(allocator, 2, 1, 2 * 3);
        defer yuv.deinit(allocator);
        try std.testing.expectEqual(@as(usize, 0), try convertARGB8888To444CrYpCb8(&src.buf, &yuv.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
        // Cr Yp Cb, no alpha at all
        try std.testing.expectEqualSlices(u8, &[_]u8{ 128, 89, 128, 128, 89, 128 }, yuv.row(0));

        const back = try makeARGB8888(allocator, 2, 1, .{ 0, 0, 0, 0 });
        defer back.deinit(allocator);
        try std.testing.expectEqual(@as(usize, 0), try convert444CrYpCb8ToARGB8888(&yuv.buf, &back.buf, &to_argb, &identity_permute, 210, Flags.kvImageNoFlags));
        try expectARGB8888Near(back, 1, 0, .{ 210, 85, 85, 85 }, 1);
    }
}

test "444AYpCbCr16 ('y416'): 16-bit components use the left-justified video range (Yp 22784, chroma 32768)" {
    const allocator = std.testing.allocator;
    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage444AYpCbCr16, .kvImageARGB8888, &range16, &to_argb, &to_yuv);

    const src = try makeARGB8888(allocator, 2, 1, .{ 255, 85, 85, 85 });
    defer src.deinit(allocator);
    const yuv = try Owned.init(allocator, 2, 1, 2 * 8);
    defer yuv.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), try convertARGB8888To444AYpCbCr16(&src.buf, &yuv.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
    try std.testing.expectEqual(@as(u16, 65535), yuv.u16At(0, 0)); // A, widened 8 -> 16
    try std.testing.expectApproxEqAbs(@as(f64, 22784), @as(f64, @floatFromInt(yuv.u16At(0, 1))), 8); // Yp
    try std.testing.expectApproxEqAbs(@as(f64, 32768), @as(f64, @floatFromInt(yuv.u16At(0, 2))), 8); // Cb
    try std.testing.expectApproxEqAbs(@as(f64, 32768), @as(f64, @floatFromInt(yuv.u16At(0, 3))), 8); // Cr

    const back = try makeARGB8888(allocator, 2, 1, .{ 0, 0, 0, 0 });
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convert444AYpCbCr16ToARGB8888(&yuv.buf, &back.buf, &to_argb, &identity_permute, Flags.kvImageNoFlags));
    try expectARGB8888Near(back, 0, 0, .{ 255, 85, 85, 85 }, 1);
}

test "444AYpCbCr16 <-> ARGB16U: full 16-bit round trip of grey 21845 stays within 64 codes" {
    const allocator = std.testing.allocator;
    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage444AYpCbCr16, .kvImageARGB16U, &range16, &to_argb, &to_yuv);

    // 21845 = 65535/3, the 16-bit twin of the 8-bit grey 85.
    const src = try Owned.init(allocator, 2, 1, 2 * 8);
    defer src.deinit(allocator);
    for (0..2) |x| {
        src.setU16(0, x * 4 + 0, 65535);
        src.setU16(0, x * 4 + 1, 21845);
        src.setU16(0, x * 4 + 2, 21845);
        src.setU16(0, x * 4 + 3, 21845);
    }
    const yuv = try Owned.init(allocator, 2, 1, 2 * 8);
    defer yuv.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convertARGB16UTo444AYpCbCr16(&src.buf, &yuv.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
    try std.testing.expectEqual(@as(u16, 65535), yuv.u16At(0, 0));
    try std.testing.expectApproxEqAbs(@as(f64, 32768), @as(f64, @floatFromInt(yuv.u16At(0, 2))), 8);

    const back = try Owned.init(allocator, 2, 1, 2 * 8);
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convert444AYpCbCr16ToARGB16U(&yuv.buf, &back.buf, &to_argb, &identity_permute, Flags.kvImageNoFlags));
    try std.testing.expectEqual(@as(u16, 65535), back.u16At(0, 0));
    for (1..4) |ch| {
        try std.testing.expectApproxEqAbs(@as(f64, 21845), @as(f64, @floatFromInt(back.u16At(0, ch))), 64);
    }
}

/// `v410` packs one pixel per 32-bit word as `Cr << 22 | Yp << 12 | Cb << 2`.
fn v410Cb(word: u32) u16 {
    return @intCast((word >> 2) & 0x3ff);
}
fn v410Yp(word: u32) u16 {
    return @intCast((word >> 12) & 0x3ff);
}
fn v410Cr(word: u32) u16 {
    return @intCast((word >> 22) & 0x3ff);
}

test "444CrYpCb10 ('v410'): components sit at Cr<<22 | Yp<<12 | Cb<<2, grey 85 -> Yp 356 chroma 512" {
    const allocator = std.testing.allocator;
    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage444CrYpCb10, .kvImageARGB8888, &range10, &to_argb, &to_yuv);

    const src = try makeARGB8888(allocator, 2, 1, .{ 255, 85, 85, 85 });
    defer src.deinit(allocator);
    const yuv = try Owned.init(allocator, 2, 1, 2 * 4);
    defer yuv.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), try convertARGB8888To444CrYpCb10(&src.buf, &yuv.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
    const word = yuv.u32At(0, 0);
    try std.testing.expectEqual(@as(u16, 356), v410Yp(word));
    try std.testing.expectEqual(@as(u16, 512), v410Cb(word));
    try std.testing.expectEqual(@as(u16, 512), v410Cr(word));

    // Hand-build the same word and decode it: the packing claim is checked in
    // both directions.
    const built = try Owned.init(allocator, 2, 1, 2 * 4);
    defer built.deinit(allocator);
    const packed_word: u32 = (@as(u32, 512) << 22) | (@as(u32, 356) << 12) | (@as(u32, 512) << 2);
    built.setU32(0, 0, packed_word);
    built.setU32(0, 1, packed_word);

    const back = try makeARGB8888(allocator, 2, 1, .{ 0, 0, 0, 0 });
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convert444CrYpCb10ToARGB8888(&built.buf, &back.buf, &to_argb, &identity_permute, 99, Flags.kvImageNoFlags));
    try expectARGB8888Near(back, 0, 0, .{ 99, 85, 85, 85 }, 1);
    try expectARGB8888Near(back, 1, 0, .{ 99, 85, 85, 85 }, 1);
}

test "444CrYpCb10 <-> ARGB16Q12: 1.0 is 4096, so grey 1/3 lands near 1365 and round trips within 16" {
    const allocator = std.testing.allocator;
    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage444CrYpCb10, .kvImageARGB16Q12, &range10, &to_argb, &to_yuv);

    const yuv = try Owned.init(allocator, 2, 1, 2 * 4);
    defer yuv.deinit(allocator);
    const packed_word: u32 = (@as(u32, 512) << 22) | (@as(u32, 356) << 12) | (@as(u32, 512) << 2);
    yuv.setU32(0, 0, packed_word);
    yuv.setU32(0, 1, packed_word);

    const argb = try Owned.init(allocator, 2, 1, 2 * 8);
    defer argb.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convert444CrYpCb10ToARGB16Q12(&yuv.buf, &argb.buf, &to_argb, &identity_permute, 4096, Flags.kvImageNoFlags));
    try std.testing.expectEqual(@as(i16, 4096), argb.i16At(0, 0)); // alpha, 1.0 in 16Q12
    for (1..4) |ch| {
        try std.testing.expectApproxEqAbs(@as(f64, 1365), @as(f64, @floatFromInt(argb.i16At(0, ch))), 16);
    }

    const back = try Owned.init(allocator, 2, 1, 2 * 4);
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convertARGB16Q12To444CrYpCb10(&argb.buf, &back.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
    const w = back.u32At(0, 1);
    try std.testing.expectApproxEqAbs(@as(f64, 356), @as(f64, @floatFromInt(v410Yp(w))), 2);
    try std.testing.expectApproxEqAbs(@as(f64, 512), @as(f64, @floatFromInt(v410Cb(w))), 2);
    try std.testing.expectApproxEqAbs(@as(f64, 512), @as(f64, @floatFromInt(v410Cr(w))), 2);
}

test "422CrYpCbYpCbYpCbYpCrYpCrYp10 ('v210'): six pixels per 16 bytes, all twelve components at their grey codes" {
    const allocator = std.testing.allocator;
    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10, .kvImageARGB8888, &range10, &to_argb, &to_yuv);

    // width must be a multiple of 6; rowBytes = 16 * (width / 6)
    const src = try makeARGB8888(allocator, 12, 2, .{ 255, 85, 85, 85 });
    defer src.deinit(allocator);
    const yuv = try Owned.init(allocator, 12, 2, 16 * (12 / 6));
    defer yuv.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), try convertARGB8888To422CrYpCbYpCbYpCbYpCrYpCrYp10(&src.buf, &yuv.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
    // Word layout, low 10 bits first: w0 = Cb0|Y0|Cr0, w1 = Y1|Cb1|Y2,
    // w2 = Cr1|Y3|Cb2, w3 = Y4|Cr2|Y5. For a grey image every luma slot is 356
    // and every chroma slot is 512, so a mis-decode of the packing shows up as
    // 356 where 512 was expected.
    const expected = [4][3]u16{
        .{ 512, 356, 512 },
        .{ 356, 512, 356 },
        .{ 512, 356, 512 },
        .{ 356, 512, 356 },
    };
    for (expected, 0..) |word_slots, w| {
        const word = yuv.u32At(0, w);
        for (word_slots, 0..) |want, slot| {
            const got: u16 = @intCast((word >> @intCast(10 * slot)) & 0x3ff);
            try std.testing.expectEqual(want, got);
        }
        // top two bits of every v210 word are unused
        try std.testing.expectEqual(@as(u32, 0), word >> 30);
    }

    const back = try makeARGB8888(allocator, 12, 2, .{ 0, 0, 0, 0 });
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convert422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB8888(&yuv.buf, &back.buf, &to_argb, &identity_permute, 255, Flags.kvImageNoFlags));
    try expectARGB8888Near(back, 0, 0, .{ 255, 85, 85, 85 }, 1);
    try expectARGB8888Near(back, 11, 1, .{ 255, 85, 85, 85 }, 1);
}

test "422CrYpCbYpCbYpCbYpCrYpCrYp10 <-> ARGB16Q12: grey survives the 10-bit 4:2:2 round trip within 16 of 1365" {
    const allocator = std.testing.allocator;
    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10, .kvImageARGB16Q12, &range10, &to_argb, &to_yuv);

    const src = try Owned.init(allocator, 6, 1, 6 * 8);
    defer src.deinit(allocator);
    for (0..6) |x| {
        src.setU16(0, x * 4 + 0, @bitCast(@as(i16, 4096)));
        for (1..4) |ch| src.setU16(0, x * 4 + ch, @bitCast(@as(i16, 1365)));
    }
    const yuv = try Owned.init(allocator, 6, 1, 16);
    defer yuv.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convertARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10(&src.buf, &yuv.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
    // word0 = Cb0 | Y0 | Cr0, low 10 bits first
    const w0 = yuv.u32At(0, 0);
    try std.testing.expectApproxEqAbs(@as(f64, 512), @as(f64, @floatFromInt(w0 & 0x3ff)), 2);
    try std.testing.expectApproxEqAbs(@as(f64, 356), @as(f64, @floatFromInt((w0 >> 10) & 0x3ff)), 2);

    const back = try Owned.init(allocator, 6, 1, 6 * 8);
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convert422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB16Q12(&yuv.buf, &back.buf, &to_argb, &identity_permute, 4096, Flags.kvImageNoFlags));
    try std.testing.expectEqual(@as(i16, 4096), back.i16At(0, 0));
    for (1..4) |ch| {
        try std.testing.expectApproxEqAbs(@as(f64, 1365), @as(f64, @floatFromInt(back.i16At(0, ch))), 16);
    }
}

test "422CbYpCrYp16 ('v216'): Cb Y0 Cr Y1 as four LE uint16 covering two pixels, ARGB8888 round trip within 1" {
    const allocator = std.testing.allocator;
    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage422CbYpCrYp16, .kvImageARGB8888, &range16, &to_argb, &to_yuv);

    const src = try makeARGB8888(allocator, 4, 2, .{ 255, 85, 85, 85 });
    defer src.deinit(allocator);
    // 4 bytes per luma pixel: two pixels share one 8-byte Cb Y0 Cr Y1 group
    const yuv = try Owned.init(allocator, 4, 2, 4 * 4);
    defer yuv.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), try convertARGB8888To422CbYpCrYp16(&src.buf, &yuv.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
    try std.testing.expectApproxEqAbs(@as(f64, 32768), @as(f64, @floatFromInt(yuv.u16At(0, 0))), 8); // Cb
    try std.testing.expectApproxEqAbs(@as(f64, 22784), @as(f64, @floatFromInt(yuv.u16At(0, 1))), 8); // Y0
    try std.testing.expectApproxEqAbs(@as(f64, 32768), @as(f64, @floatFromInt(yuv.u16At(0, 2))), 8); // Cr
    try std.testing.expectApproxEqAbs(@as(f64, 22784), @as(f64, @floatFromInt(yuv.u16At(0, 3))), 8); // Y1

    const back = try makeARGB8888(allocator, 4, 2, .{ 0, 0, 0, 0 });
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convert422CbYpCrYp16ToARGB8888(&yuv.buf, &back.buf, &to_argb, &identity_permute, 128, Flags.kvImageNoFlags));
    try expectARGB8888Near(back, 3, 1, .{ 128, 85, 85, 85 }, 1);
}

test "422CbYpCrYp16 <-> ARGB16U: 16-bit grey 21845 round trips within 64 codes" {
    const allocator = std.testing.allocator;
    var to_argb: YpCbCrToARGB = .{};
    var to_yuv: ARGBToYpCbCr = .{};
    try makeInfos(.kvImage422CbYpCrYp16, .kvImageARGB16U, &range16, &to_argb, &to_yuv);

    const src = try Owned.init(allocator, 4, 1, 4 * 8);
    defer src.deinit(allocator);
    for (0..4) |x| {
        src.setU16(0, x * 4 + 0, 65535);
        for (1..4) |ch| src.setU16(0, x * 4 + ch, 21845);
    }
    const yuv = try Owned.init(allocator, 4, 1, 4 * 4);
    defer yuv.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convertARGB16UTo422CbYpCrYp16(&src.buf, &yuv.buf, &to_yuv, &identity_permute, Flags.kvImageNoFlags));
    try std.testing.expectApproxEqAbs(@as(f64, 32768), @as(f64, @floatFromInt(yuv.u16At(0, 0))), 8);
    try std.testing.expectApproxEqAbs(@as(f64, 22784), @as(f64, @floatFromInt(yuv.u16At(0, 1))), 8);

    const back = try Owned.init(allocator, 4, 1, 4 * 8);
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convert422CbYpCrYp16ToARGB16U(&yuv.buf, &back.buf, &to_argb, &identity_permute, 65535, Flags.kvImageNoFlags));
    try std.testing.expectEqual(@as(u16, 65535), back.u16At(0, 0));
    for (1..4) |ch| {
        try std.testing.expectApproxEqAbs(@as(f64, 21845), @as(f64, @floatFromInt(back.u16At(0, ch))), 64);
    }
}
