//! Remaining N-to-M pixel-format pairs from `Conversion.h`: the depth changes
//! (12U <-> 16U, 16U <-> 16F, 8-bit <-> 16U), the 16U channel-shuffling family
//! (ARGB16U / RGB16U / RGBA16U / BGRA16U and their planar splits), the
//! "X-channel" interleave/de-interleave pairs where one channel is a
//! caller-supplied constant rather than image data, and the `_dithered`
//! narrowing variants.
//!
//! Layout facts a caller needs:
//!
//!   * **12U is packed, not padded.** Two 12-bit samples share three bytes,
//!     big-endian within the pair: `byte0 = s0 >> 4`,
//!     `byte1 = ((s0 & 0xF) << 4) | (s1 >> 8)`, `byte2 = s1 & 0xFF`. A 12U
//!     `vImage_Buffer.width` counts *samples*, so a row of `w` samples
//!     occupies `w * 3 / 2` bytes and `w` must be even. There is no
//!     `Pixel_12U` type; the buffer is bytes.
//!
//!   * **8 <-> 16 unsigned scaling is the exact full-range map**, not a shift:
//!     widening is `(v * 65535 + 127) / 255` and narrowing is
//!     `round(v * 255 / 65535)`, so `255 <-> 65535` and, generally,
//!     `k <-> 257*k`. Note that `Conversion.h`'s pseudo-code writes the
//!     narrowing step as the truncating `(v * 255 + 32767) / 65535`; the
//!     shipping implementation rounds to nearest instead and the two differ by
//!     one at midpoints (65535/2 = 32768 converts to 128, not 127). 12U uses
//!     the analogous 4095-denominator map: `12U -> 16U` is
//!     `(t * 65535 + (t << 4) + 2055) >> 12`, and that one *is* exact as
//!     written.
//!
//!   * **16F is IEEE 754 binary16 stored as its raw bit pattern.** Because
//!     `Pixel_16F == Pixel_16U == u16` in this binding, the 16U <-> 16F pair
//!     below cannot be distinguished by type - `convert16Uto16F` reads
//!     integers and writes half-float bits, and `convert16Fto16U` does the
//!     reverse. The pair is *full-range normalising*, not a plain integer ->
//!     float cast: 16U 0..65535 maps to 16F 0.0..1.0 (`h = v / 65535`), so
//!     65535 becomes 1.0h and 32768 becomes 0.5h. `Conversion.h` documents it
//!     as a bare `ConvertToPlanar16F(srcPixel[x])`, which is misleading -
//!     measured behaviour is the normalising map. To run either on
//!     interleaved data, multiply `vImage_Buffer.width` by the channel count.
//!
//!   * **Channel order is memory order, always.** `ARGB16UtoRGB16U` drops the
//!     first channel, `RGBA16UtoRGB16U` drops the last, and
//!     `BGRA16UtoRGB16U` drops the last *and* reverses the remaining three.
//!     The X in XRGB/BGRX is ignored on read and written from a scalar
//!     argument on write; it is never read from a source plane.
//!
//!   * **`permuteMap` indexes the source, `copyMask` selects the background.**
//!     For the 4-channel converters `permuteMap[i]` is the source channel that
//!     lands in destination channel `i`, and `copyMask` bit `0x8 >> i`
//!     replaces destination channel `i` with `backgroundColor[i]` after the
//!     conversion. `RGB16UToARGB8888` permutes a synthesised 4-channel
//!     `{255, R, G, B}`, so `permuteMap[0] = 0` yields an opaque alpha.
//!
//! The `_dithered` entry points take a dither method (see `Dither`). Pass
//! `Dither.none` for deterministic round-to-nearest output; the ordered modes
//! add blue noise and, except for `ordered_reproducible`, vary per call.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const Error = types.Error;
const check = types.check;
const vImage_Flags = types.vImage_Flags;
const Pixel_8 = types.Pixel_8;
const Pixel_F = types.Pixel_F;
const Pixel_8888 = types.Pixel_8888;
const Pixel_FFFF = types.Pixel_FFFF;
const Pixel_16U = types.Pixel_16U;
const Pixel_ARGB_16U = types.Pixel_ARGB_16U;
const Flags = types.Flags;
const Options = types.Options;

// ============================================================================
// Dither methods
// ============================================================================

/// The `int dither` argument taken by every `_dithered` entry point.
///
/// These are the `kvImageConvert_Dither*` constants from `Conversion.h`. They
/// are plain `c_int`s rather than an enum because the two noise-shape values
/// are OR-ed into an ordered method:
///
///     Dither.ordered_reproducible | Dither.ordered_uniform_blue
///
/// Only the ordered methods honour the shape bits. Anything vImage does not
/// recognise comes back as `Error.InvalidParameter`.
pub const Dither = struct {
    /// Round to nearest. Deterministic, and identical to the undithered
    /// conversion of the same pair.
    pub const none: c_int = 0;
    /// Blue noise, with a per-call randomised offset into the noise table.
    pub const ordered: c_int = 1;
    /// Blue noise at a fixed offset, so repeated calls agree. Still images.
    pub const ordered_reproducible: c_int = 2;
    pub const floyd_steinberg: c_int = 3;
    pub const atkinson: c_int = 4;

    /// Gaussian noise distribution - the default for the ordered methods.
    pub const ordered_gaussian_blue: c_int = 0;
    /// Uniform noise distribution: better colour fidelity, noisier image.
    pub const ordered_uniform_blue: c_int = 1 << 28;
    /// Mask covering the noise-shape field of a dither value.
    pub const ordered_noise_shape_mask: c_int = @bitCast(@as(u32, 0xF) << 28);
};

// ============================================================================
// Depth conversions: 12U <-> 16U, 16U <-> 16F
// ============================================================================

/// Unpack a 12-bit planar image to Planar16U, expanding to full range.
///
/// `src` holds two 12-bit samples per three bytes (see the module comment for
/// the packing); `src.width` counts samples, so `src.rowBytes` must be at
/// least `width * 3 / 2` and the width must be even. `dest` is `Pixel_16U`.
///
///     dest[i] = (t * 65535 + (t << 4) + 2055) >> 12   // t = 12-bit sample
///
/// Does not work in place.
pub fn convert12UTo16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_12UTo16U(src, dest, flags.bits()));
}

/// Pack a Planar16U image down to 12 bits per sample.
///
///     t = (v * 4095 + 32767 + (v >> 4)) >> 16
///
/// then two consecutive `t` values are packed into three bytes. `dest.width`
/// counts samples and must be even; `dest.rowBytes >= width * 3 / 2`.
/// Does not work in place.
pub fn convert16UTo12U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_16UTo12U(src, dest, flags.bits()));
}

/// Convert Planar16U to Planar16F (IEEE 754 binary16 bit patterns).
///
/// Full-range normalising: `h = v / 65535`, so 0 -> 0.0h, 32768 -> 0.5h and
/// 65535 -> 1.0h. Small `v` lands in binary16's subnormal range (1 -> 0x0100)
/// but still round-trips, because 16 bits of integer fit in the 24 bits of
/// subnormal resolution below 2^-14. For interleaved data, multiply `width`
/// by the channel count. Works in place when
/// `src.data == dest.data and src.rowBytes >= dest.rowBytes` (add
/// `kvImageDoNotTile` if the rowBytes differ).
pub fn convert16Uto16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_16Uto16F(src, dest, flags.bits()));
}

/// Convert Planar16F (binary16 bit patterns) to Planar16U.
///
/// The inverse of `convert16Uto16F`: `v = round(h * 65535)`, clamped into
/// `[0, 65535]`, so 1.0h becomes 65535. Half-floats carry 11 significant bits
/// against 16U's 16, so a 16U -> 16F -> 16U round trip is lossy for values
/// that are not exactly representable (25700 comes back as 25696). For
/// interleaved data, multiply `width` by the channel count.
pub fn convert16Fto16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_16Fto16U(src, dest, flags.bits()));
}

// ============================================================================
// ARGB16U / RGB16U <-> 8-bit interleaved
// ============================================================================

/// Narrow ARGB16U to ARGB8888, permuting channels and optionally substituting
/// a background colour.
///
///     result[i] = round(src[permuteMap[i]] * 255 / 65535)
///     if (copyMask & (0x8 >> i)) result[i] = backgroundColor[i]
///
/// (The header writes the first line as the truncating
/// `(v * 255 + 32767) / 65535`; the implementation rounds to nearest.)
/// Every `permuteMap` entry must be 0..3 or vImage returns
/// `Error.InvalidParameter`. `backgroundColor` may not be null even when
/// `copyMask` is 0. Works in place.
pub fn argb16UToARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    permute_map: *const [4]u8,
    copy_mask: u8,
    background_color: *const Pixel_8888,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB16UToARGB8888(src, dest, permute_map, copy_mask, background_color, flags.bits()));
}

/// Widen ARGB8888 to ARGB16U, permuting channels and optionally substituting
/// a background colour.
///
///     result[i] = (src[permuteMap[i]] * 65535 + 127) / 255
///     if (copyMask & (0x8 >> i)) result[i] = backgroundColor[i]
///
/// Does not work in place.
pub fn argb8888ToARGB16U(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    permute_map: *const [4]u8,
    copy_mask: u8,
    background_color: *const Pixel_ARGB_16U,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB8888ToARGB16U(src, dest, permute_map, copy_mask, background_color, flags.bits()));
}

/// Widen a 4-channel 8-bit image to a 3-channel 16U image, dropping whichever
/// channel `permuteMap` does not name.
///
/// `permuteMap` has three entries indexing the four source channels, so
/// `.{ 1, 2, 3 }` takes RGB out of ARGB8888. `copyMask` is only three bits
/// wide here: 0x4 -> first destination channel, 0x2 -> second, 0x1 -> third,
/// and `backgroundColor` is three `Pixel_16U`. Does not work in place.
pub fn argb8888ToRGB16U(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    permute_map: *const [3]u8,
    copy_mask: u8,
    background_color: *const [3]Pixel_16U,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB8888ToRGB16U(src, dest, permute_map, copy_mask, background_color, flags.bits()));
}

/// Narrow a 3-channel 16U image to a 4-channel 8-bit image, synthesising the
/// missing channel as an opaque 255.
///
/// vImage builds `{255, R', G', B'}` (with `X' = (X * 255 + 32767) / 65535`)
/// and *then* permutes it, so `permuteMap` entries index 0..3 with 0 meaning
/// the synthesised 255. `.{ 0, 1, 2, 3 }` gives XRGB-style opaque ARGB8888.
/// `copyMask` and `backgroundColor` behave as in `argb16UToARGB8888`.
pub fn rgb16UToARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    permute_map: *const [4]u8,
    copy_mask: u8,
    background_color: *const Pixel_8888,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGB16UToARGB8888(src, dest, permute_map, copy_mask, background_color, flags.bits()));
}

// ============================================================================
// 16U interleaved <-> 16U planar
// ============================================================================

/// De-interleave ARGB16U into four Planar16U buffers, in memory order.
/// All four destinations must have the same dimensions. Not in place.
pub fn argb16UtoPlanar16U(
    argb_src: *const vImage_Buffer,
    a_dest: *const vImage_Buffer,
    r_dest: *const vImage_Buffer,
    g_dest: *const vImage_Buffer,
    b_dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB16UtoPlanar16U(argb_src, a_dest, r_dest, g_dest, b_dest, flags.bits()));
}

/// Interleave four Planar16U buffers into ARGB16U, in memory order.
/// Not in place.
pub fn planar16UtoARGB16U(
    a_src: *const vImage_Buffer,
    r_src: *const vImage_Buffer,
    g_src: *const vImage_Buffer,
    b_src: *const vImage_Buffer,
    argb_dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_Planar16UtoARGB16U(a_src, r_src, g_src, b_src, argb_dest, flags.bits()));
}

/// De-interleave RGB16U (3 channels, 6 bytes per pixel) into three Planar16U
/// buffers. Not in place.
pub fn rgb16UtoPlanar16U(
    rgb_src: *const vImage_Buffer,
    r_dest: *const vImage_Buffer,
    g_dest: *const vImage_Buffer,
    b_dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGB16UtoPlanar16U(rgb_src, r_dest, g_dest, b_dest, flags.bits()));
}

/// Interleave three Planar16U buffers into RGB16U. Not in place.
pub fn planar16UtoRGB16U(
    r_src: *const vImage_Buffer,
    g_src: *const vImage_Buffer,
    b_src: *const vImage_Buffer,
    rgb_dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_Planar16UtoRGB16U(r_src, g_src, b_src, rgb_dest, flags.bits()));
}

// ============================================================================
// 16U interleaved: 4 channels -> 3 channels
// ============================================================================

/// Drop the leading channel of an ARGB16U image: `dest[i] = src[i + 1]`.
/// Not in place.
pub fn argb16UtoRGB16U(argb_src: *const vImage_Buffer, rgb_dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_ARGB16UtoRGB16U(argb_src, rgb_dest, flags.bits()));
}

/// Drop the trailing channel of an RGBA16U image: `dest[i] = src[i]` for
/// i in 0..2. This is the one member of the family that can work in place,
/// provided `src.data == dest.data` and the rowBytes match.
pub fn rgba16UtoRGB16U(rgba_src: *const vImage_Buffer, rgb_dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_RGBA16UtoRGB16U(rgba_src, rgb_dest, flags.bits()));
}

/// Drop the trailing channel of a BGRA16U image *and* reverse the remaining
/// three, so `dest = {src[2], src[1], src[0]}`. Not in place.
pub fn bgra16UtoRGB16U(bgra_src: *const vImage_Buffer, rgb_dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_BGRA16UtoRGB16U(bgra_src, rgb_dest, flags.bits()));
}

// ============================================================================
// 16U interleaved: 3 channels + alpha -> 4 channels
// ============================================================================

/// Add an alpha channel ahead of an RGB16U image, producing ARGB16U.
///
/// The alpha comes from the Planar16U buffer `a_src`. When `premultiply` is
/// true each colour channel becomes `(a * v + 32767) / 65535` and the alpha
/// itself is stored unscaled. Not in place.
///
/// Pass null for `a_src` to use the scalar `alpha` for every pixel instead;
/// the header marks the parameter optional with `VIMAGE_NON_NULL(1,4)`.
pub fn rgb16UtoARGB16U(
    rgb_src: *const vImage_Buffer,
    a_src: ?*const vImage_Buffer,
    alpha: Pixel_16U,
    argb_dest: *const vImage_Buffer,
    premultiply: bool,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGB16UtoARGB16U(rgb_src, a_src, alpha, argb_dest, premultiply, flags.bits()));
}

/// Append an alpha channel to an RGB16U image, producing RGBA16U.
/// Premultiplication and the null-`a_src` behaviour are as in `rgb16UtoARGB16U`.
pub fn rgb16UtoRGBA16U(
    rgb_src: *const vImage_Buffer,
    a_src: ?*const vImage_Buffer,
    alpha: Pixel_16U,
    rgba_dest: *const vImage_Buffer,
    premultiply: bool,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGB16UtoRGBA16U(rgb_src, a_src, alpha, rgba_dest, premultiply, flags.bits()));
}

/// Reverse an RGB16U image's channels and append alpha, producing BGRA16U.
/// Premultiplication and the null-`a_src` behaviour are as in `rgb16UtoARGB16U`.
pub fn rgb16UtoBGRA16U(
    rgb_src: *const vImage_Buffer,
    a_src: ?*const vImage_Buffer,
    alpha: Pixel_16U,
    bgra_dest: *const vImage_Buffer,
    premultiply: bool,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGB16UtoBGRA16U(rgb_src, a_src, alpha, bgra_dest, premultiply, flags.bits()));
}

// ============================================================================
// Dithered narrowing conversions
// ============================================================================

/// Narrow Planar16U to Planar8 with a chosen dither method.
///
/// With `Dither.none` this is `round(v * 255 / 65535)`. Works in
/// place when `src.data == dest.data` and `src.rowBytes >= dest.rowBytes`.
pub fn planar16UtoPlanar8Dithered(src: *const vImage_Buffer, dest: *const vImage_Buffer, dither: c_int, flags: Options) Error!usize {
    return check(c.vImageConvert_Planar16UtoPlanar8_dithered(src, dest, dither, flags.bits()));
}

/// Narrow RGB16U to RGB888 (3 channels, no alpha) with a chosen dither
/// method. Per-channel behaviour matches `planar16UtoPlanar8Dithered`.
pub fn rgb16UtoRGB888Dithered(src: *const vImage_Buffer, dest: *const vImage_Buffer, dither: c_int, flags: Options) Error!usize {
    return check(c.vImageConvert_RGB16UtoRGB888_dithered(src, dest, dither, flags.bits()));
}

/// Narrow ARGB16U to ARGB8888 with a chosen dither method, permuting channels
/// on the way. `permuteMap[i]` is the source channel for destination channel
/// `i` and every entry must be 0..3.
pub fn argb16UtoARGB8888Dithered(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    dither: c_int,
    permute_map: *const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB16UtoARGB8888_dithered(src, dest, dither, permute_map, flags.bits()));
}

/// Narrow PlanarF to Planar8 with a chosen dither method.
///
///     dest = clip_0_255(255 * (v - minFloat) / (maxFloat - minFloat) + noise)
///
/// `maxFloat` and `minFloat` are the encodings of full and zero intensity;
/// `maxFloat < minFloat` is legal and inverts the image. NaN yields 0.
pub fn planarFtoPlanar8Dithered(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    max_float: Pixel_F,
    min_float: Pixel_F,
    dither: c_int,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_PlanarFtoPlanar8_dithered(src, dest, max_float, min_float, dither, flags.bits()));
}

/// Narrow RGBFFF (3-channel float) to RGB888 with a chosen dither method.
/// `max_float` and `min_float` carry one value per channel, in destination
/// channel order.
pub fn rgbFFFtoRGB888Dithered(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    max_float: *const [3]Pixel_F,
    min_float: *const [3]Pixel_F,
    dither: c_int,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGBFFFtoRGB888_dithered(src, dest, max_float, min_float, dither, flags.bits()));
}

/// Narrow ARGBFFFF to ARGB8888 with a chosen dither method and a channel
/// permutation. `max_float` / `min_float` are per-channel and are indexed in
/// *destination* order, i.e. after the permute.
pub fn argbFFFFtoARGB8888Dithered(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    max_float: *const Pixel_FFFF,
    min_float: *const Pixel_FFFF,
    dither: c_int,
    permute_map: *const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGBFFFFtoARGB8888_dithered(src, dest, max_float, min_float, dither, permute_map, flags.bits()));
}

// ============================================================================
// X-channel de-interleave: XRGB / BGRX -> planar
// ============================================================================
//
// The X channel is read and discarded; there is no destination plane for it.
// All three destination planes must have identical dimensions or vImage
// returns kvImageBufferSizeMismatch. None of these work in place.

/// Split XRGB8888 into three Planar8 buffers, discarding the leading X byte:
/// `red = src[1]`, `green = src[2]`, `blue = src[3]`.
pub fn xrgb8888ToPlanar8(
    src: *const vImage_Buffer,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_XRGB8888ToPlanar8(src, red, green, blue, flags.bits()));
}

/// Split BGRX8888 into three Planar8 buffers, discarding the trailing X byte:
/// `blue = src[0]`, `green = src[1]`, `red = src[2]`. Note the argument order
/// - blue first - which mirrors memory order and is what makes this the same
/// entry point as `vImageConvert_RGBX8888ToPlanar8`.
pub fn bgrx8888ToPlanar8(
    src: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    green: *const vImage_Buffer,
    red: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_BGRX8888ToPlanar8(src, blue, green, red, flags.bits()));
}

/// Split XRGBFFFF into three PlanarF buffers, discarding the leading X float.
pub fn xrgbFFFFToPlanarF(
    src: *const vImage_Buffer,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_XRGBFFFFToPlanarF(src, red, green, blue, flags.bits()));
}

/// Split BGRXFFFF into three PlanarF buffers, discarding the trailing X float.
pub fn bgrxFFFFToPlanarF(
    src: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    green: *const vImage_Buffer,
    red: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_BGRXFFFFToPlanarF(src, blue, green, red, flags.bits()));
}

// ============================================================================
// X-channel interleave: planar -> XRGB / BGRX
// ============================================================================
//
// The X channel comes from a scalar, not a buffer, so it is constant over the
// whole image. None of these work in place.

/// Interleave three Planar8 buffers into XRGB8888, writing `alpha` into the
/// leading byte of every pixel: `dest = {alpha, r, g, b}`.
pub fn planar8ToXRGB8888(
    alpha: Pixel_8,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_Planar8ToXRGB8888(alpha, red, green, blue, dest, flags.bits()));
}

/// Interleave three Planar8 buffers into BGRX8888, writing `alpha` into the
/// trailing byte: `dest = {b, g, r, alpha}`. Passing the planes as
/// (red, green, blue) instead produces RGBX8888 - the header's
/// `vImageConvert_Planar8ToRGBX8888` is a macro for exactly that.
pub fn planar8ToBGRX8888(
    blue: *const vImage_Buffer,
    green: *const vImage_Buffer,
    red: *const vImage_Buffer,
    alpha: Pixel_8,
    dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_Planar8ToBGRX8888(blue, green, red, alpha, dest, flags.bits()));
}

/// Interleave three Planar8 buffers into XRGBFFFF, scaling each 8-bit channel
/// into the float range:
///
///     dest[ch] = (maxFloat[ch] - minFloat[ch]) * v / 255 + minFloat[ch]
///
/// The leading X channel is written as the raw `alpha` float and is *not*
/// scaled, so `max_float[0]` / `min_float[0]` do not affect it.
pub fn planar8ToXRGBFFFF(
    alpha: Pixel_F,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    max_float: *const Pixel_FFFF,
    min_float: *const Pixel_FFFF,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_Planar8ToXRGBFFFF(alpha, red, green, blue, dest, max_float, min_float, flags.bits()));
}

/// Interleave three Planar8 buffers into BGRXFFFF with the same per-channel
/// scaling as `planar8ToXRGBFFFF`, but with the constant `alpha` float in the
/// trailing channel.
pub fn planar8ToBGRXFFFF(
    blue: *const vImage_Buffer,
    green: *const vImage_Buffer,
    red: *const vImage_Buffer,
    alpha: Pixel_F,
    dest: *const vImage_Buffer,
    max_float: *const Pixel_FFFF,
    min_float: *const Pixel_FFFF,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_Planar8ToBGRXFFFF(blue, green, red, alpha, dest, max_float, min_float, flags.bits()));
}

/// Interleave three PlanarF buffers into XRGB8888, quantising each channel:
///
///     dest[ch] = round(clamp(v, min, max) * 255 / (max - min) - min * ...)
///
/// i.e. `minFloat[ch]` maps to 0 and `maxFloat[ch]` to 255, with saturation
/// outside that range and NaN producing 0. The leading X byte is the raw
/// `alpha` byte - note that it is a `Pixel_8` here even though the sources are
/// float. When `max_float[ch] == min_float[ch]` the channel is instead set to
/// `round(clip(255 * maxFloat[ch]))`, which is how you pin a channel to a
/// constant.
pub fn planarFToXRGB8888(
    alpha: Pixel_8,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    max_float: *const Pixel_FFFF,
    min_float: *const Pixel_FFFF,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_PlanarFToXRGB8888(alpha, red, green, blue, dest, max_float, min_float, flags.bits()));
}

/// Interleave three PlanarF buffers into BGRX8888 with the same quantisation
/// as `planarFToXRGB8888`, with the constant `alpha` byte trailing.
pub fn planarFToBGRX8888(
    blue: *const vImage_Buffer,
    green: *const vImage_Buffer,
    red: *const vImage_Buffer,
    alpha: Pixel_8,
    dest: *const vImage_Buffer,
    max_float: *const Pixel_FFFF,
    min_float: *const Pixel_FFFF,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_PlanarFToBGRX8888(blue, green, red, alpha, dest, max_float, min_float, flags.bits()));
}

/// Interleave three PlanarF buffers into XRGBFFFF: a straight copy with the
/// constant `alpha` float leading. No scaling, hence no max/min arguments.
pub fn planarFToXRGBFFFF(
    alpha: Pixel_F,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_PlanarFToXRGBFFFF(alpha, red, green, blue, dest, flags.bits()));
}

/// Interleave three PlanarF buffers into BGRXFFFF: a straight copy with the
/// constant `alpha` float trailing. Passing (red, green, blue) instead gives
/// RGBXFFFF, matching the header's `vImageConvert_PlanarFToRGBXFFFF` macro.
pub fn planarFToBGRXFFFF(
    blue: *const vImage_Buffer,
    green: *const vImage_Buffer,
    red: *const vImage_Buffer,
    alpha: Pixel_F,
    dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_PlanarFToBGRXFFFF(blue, green, red, alpha, dest, flags.bits()));
}

// ============================================================================
// Tests
// ============================================================================
//
// Every buffer here is allocated with std.testing.allocator and given a
// rowBytes padded one pixel past width * bytesPerPixel, so a wrapper that
// assumed rowBytes == width * bytesPerPixel would read into the padding and
// fail. Expected values are the header's own integer formulas evaluated by
// hand; see the comment at each call site.

const Buf = struct {
    buf: vImage_Buffer,
    mem: []align(8) u8,

    fn free(self: Buf, allocator: std.mem.Allocator) void {
        allocator.free(self.mem);
    }

    /// `i` is the flat index within the row: `col * channels + channel`.
    fn get(self: Buf, comptime T: type, row: usize, i: usize) T {
        const base: [*]u8 = @ptrCast(self.mem.ptr);
        const p: [*]const T = @ptrCast(@alignCast(base + row * self.buf.rowBytes));
        return p[i];
    }

    fn set(self: Buf, comptime T: type, row: usize, i: usize, v: T) void {
        const base: [*]u8 = @ptrCast(self.mem.ptr);
        const p: [*]T = @ptrCast(@alignCast(base + row * self.buf.rowBytes));
        p[i] = v;
    }
};

/// Allocate a `height` x `width` buffer of `channels` `T`s per pixel, with one
/// extra pixel of row padding, zero filled.
fn alloc(
    allocator: std.mem.Allocator,
    comptime T: type,
    height: usize,
    width: usize,
    channels: usize,
) !Buf {
    const row_bytes = (width + 1) * channels * @sizeOf(T);
    const mem = try allocator.alignedAlloc(u8, .@"8", row_bytes * height);
    @memset(mem, 0);
    return .{
        .buf = .{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes },
        .mem = mem,
    };
}

/// Allocate a 12U buffer: `width` samples per row at 1.5 bytes each, plus two
/// samples' worth of padding.
fn alloc12U(allocator: std.mem.Allocator, height: usize, width: usize) !Buf {
    std.debug.assert(width % 2 == 0);
    const row_bytes = (width + 2) * 3 / 2;
    const mem = try allocator.alignedAlloc(u8, .@"8", row_bytes * height);
    @memset(mem, 0);
    return .{
        .buf = .{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes },
        .mem = mem,
    };
}

/// Pack sample `s` into the 12U byte stream at sample index `i`.
fn put12(b: Buf, row: usize, i: usize, s: u12) void {
    const base = row * b.buf.rowBytes + (i / 2) * 3;
    if (i % 2 == 0) {
        b.mem[base] = @intCast(s >> 4);
        b.mem[base + 1] = (b.mem[base + 1] & 0x0F) | (@as(u8, @truncate(s)) << 4);
    } else {
        b.mem[base + 1] = (b.mem[base + 1] & 0xF0) | @as(u8, @intCast(s >> 8));
        b.mem[base + 2] = @truncate(s);
    }
}

fn get12(b: Buf, row: usize, i: usize) u12 {
    const base = row * b.buf.rowBytes + (i / 2) * 3;
    if (i % 2 == 0) {
        return (@as(u12, b.mem[base]) << 4) | (b.mem[base + 1] >> 4);
    }
    return (@as(u12, b.mem[base + 1] & 0x0F) << 8) | b.mem[base + 2];
}

test "convert12UTo16U: dest = (t * 65535 + (t << 4) + 2055) >> 12, two samples per three bytes" {
    const allocator = std.testing.allocator;
    const src = try alloc12U(allocator, 1, 4);
    defer src.free(allocator);
    const dest = try alloc(allocator, u16, 1, 4, 1);
    defer dest.free(allocator);

    // 0xFFF, 0x000, 0x800, 0x001 -> bytes FF F0 00 80 00 01.
    const samples = [_]u12{ 0xFFF, 0x000, 0x800, 0x001 };
    for (samples, 0..) |s, i| put12(src, 0, i, s);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xFF, 0xF0, 0x00, 0x80, 0x00, 0x01 }, src.mem[0..6]);

    _ = try convert12UTo16U(&src.buf, &dest.buf, .{});

    // (4095*65535 + 65520 + 2055) >> 12 = 268433400 >> 12 = 65535
    // (0    *65535 + 0     + 2055) >> 12 = 0
    // (2048*65535 + 32768 + 2055) >> 12 = 134250503 >> 12 = 32776
    // (1   *65535 + 16    + 2055) >> 12 = 67606     >> 12 = 16
    const expected = [_]u16{ 65535, 0, 32776, 16 };
    for (expected, 0..) |e, i| try std.testing.expectEqual(e, dest.get(u16, 0, i));
}

test "convert16UTo12U: t = (v * 4095 + 32767 + (v >> 4)) >> 16, and the 12U round trip is exact" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, u16, 1, 4, 1);
    defer src.free(allocator);
    const dest = try alloc12U(allocator, 1, 4);
    defer dest.free(allocator);

    const vals = [_]u16{ 65535, 0, 32776, 16 };
    for (vals, 0..) |v, i| src.set(u16, 0, i, v);

    _ = try convert16UTo12U(&src.buf, &dest.buf, .{});

    // (65535*4095 + 32767 + 4095) >> 16 = 268402687 >> 16 = 4095
    // (0                        ) >> 16 = 0
    // (32776*4095 + 32767 + 2048) >> 16 = 134251335 >> 16 = 2048
    // (16   *4095 + 32767 + 1   ) >> 16 = 98288     >> 16 = 1
    const expected = [_]u12{ 0xFFF, 0x000, 0x800, 0x001 };
    for (expected, 0..) |e, i| try std.testing.expectEqual(e, get12(dest, 0, i));
    try std.testing.expectEqualSlices(u8, &[_]u8{ 0xFF, 0xF0, 0x00, 0x80, 0x00, 0x01 }, dest.mem[0..6]);
}

test "convert16Uto16F and convert16Fto16U: 16U 0..65535 maps to 16F 0.0..1.0, not to 0.0..65535.0" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, u16, 1, 4, 1);
    defer src.free(allocator);
    const half = try alloc(allocator, u16, 1, 4, 1);
    defer half.free(allocator);
    const back = try alloc(allocator, u16, 1, 4, 1);
    defer back.free(allocator);

    const vals = [_]u16{ 0, 32768, 65535, 257 };
    for (vals, 0..) |v, i| src.set(u16, 0, i, v);

    _ = try convert16Uto16F(&src.buf, &half.buf, .{});

    // The stored bits are the binary16 encodings of v / 65535. If this were
    // the plain integer -> float cast the header's pseudo-code implies, 65535
    // would overflow binary16's 65504 maximum and become infinity (0x7C00)
    // instead of 1.0 (0x3C00).
    const expected_bits = [_]u16{ 0x0000, 0x3800, 0x3C00, 0x1C04 };
    const expected_floats = [_]f16{ 0.0, 0.5, 1.0, 257.0 / 65535.0 };
    for (expected_bits, 0..) |e, i| {
        try std.testing.expectEqual(e, half.get(u16, 0, i));
        try std.testing.expectEqual(expected_floats[i], @as(f16, @bitCast(half.get(u16, 0, i))));
    }

    // These four are exactly representable, so the round trip is exact.
    _ = try convert16Fto16U(&half.buf, &back.buf, .{});
    for (vals, 0..) |v, i| try std.testing.expectEqual(v, back.get(u16, 0, i));
}

test "convert16Uto16F is lossy for values needing more than 11 significant bits" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, u16, 1, 2, 1);
    defer src.free(allocator);
    const half = try alloc(allocator, u16, 1, 2, 1);
    defer half.free(allocator);
    const back = try alloc(allocator, u16, 1, 2, 1);
    defer back.free(allocator);

    // 25700/65535 = 0.39216 sits in the binade [0.25, 0.5), where binary16
    // steps by 2^-13; one step is 65535 * 2^-13 = 8 counts of 16U, so the
    // round trip can lose up to 4. Measured: 25700 -> 25696.
    src.set(u16, 0, 0, 25700);
    src.set(u16, 0, 1, 65534);
    _ = try convert16Uto16F(&src.buf, &half.buf, .{});
    _ = try convert16Fto16U(&half.buf, &back.buf, .{});

    try std.testing.expectEqual(@as(u16, 25696), back.get(u16, 0, 0));
    try std.testing.expectApproxEqAbs(
        @as(f64, 25700),
        @as(f64, @floatFromInt(back.get(u16, 0, 0))),
        4,
    );
    // Just below full scale, the step is 65535 * 2^-11 = 32 counts, so 65534
    // snaps to 65535.
    try std.testing.expectApproxEqAbs(
        @as(f64, 65534),
        @as(f64, @floatFromInt(back.get(u16, 0, 1))),
        16,
    );
}

test "argb16UToARGB8888: result[i] = round(src[permuteMap[i]] * 255 / 65535), then copyMask" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, u16, 1, 1, 4);
    defer src.free(allocator);
    const dest = try alloc(allocator, u8, 1, 1, 4);
    defer dest.free(allocator);

    // round(65535*255/65535) = 255, round(32768*255/65535) = round(127.502) = 128,
    // round(0*255/65535)     = 0,   round(257*255/65535)   = 1 exactly.
    // The header's truncating pseudo-code would give 127 for 32768; vImage
    // actually rounds, so 128 is the value that pins down real behaviour.
    const vals = [_]u16{ 65535, 32768, 0, 257 };
    for (vals, 0..) |v, i| src.set(u16, 0, i, v);

    const identity = [_]u8{ 0, 1, 2, 3 };
    const bg = Pixel_8888{ 9, 9, 9, 9 };
    _ = try argb16UToARGB8888(&src.buf, &dest.buf, &identity, 0, &bg, .{});
    try std.testing.expectEqual(@as(u8, 255), dest.get(u8, 0, 0));
    try std.testing.expectEqual(@as(u8, 128), dest.get(u8, 0, 1));
    try std.testing.expectEqual(@as(u8, 0), dest.get(u8, 0, 2));
    try std.testing.expectEqual(@as(u8, 1), dest.get(u8, 0, 3));

    // Reversed permute, and copyMask 0x8 replaces destination channel 0 with
    // backgroundColor[0]. If permuteMap were treated as a [4]u8 by value
    // rather than a pointer this would read garbage.
    const reversed = [_]u8{ 3, 2, 1, 0 };
    const bg2 = Pixel_8888{ 42, 0, 0, 0 };
    _ = try argb16UToARGB8888(&src.buf, &dest.buf, &reversed, 0x8, &bg2, .{});
    try std.testing.expectEqual(@as(u8, 42), dest.get(u8, 0, 0)); // from background
    try std.testing.expectEqual(@as(u8, 0), dest.get(u8, 0, 1)); // src[2] = 0
    try std.testing.expectEqual(@as(u8, 128), dest.get(u8, 0, 2)); // src[1] = 32768
    try std.testing.expectEqual(@as(u8, 255), dest.get(u8, 0, 3)); // src[0] = 65535
}

test "argb8888ToARGB16U: result[i] = (src[permuteMap[i]] * 65535 + 127) / 255, then copyMask" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, u8, 1, 1, 4);
    defer src.free(allocator);
    const dest = try alloc(allocator, u16, 1, 1, 4);
    defer dest.free(allocator);

    // 255 -> 65535, 128 -> (8388480+127)/255 = 32896, 0 -> 0, 1 -> 257.
    const vals = [_]u8{ 255, 128, 0, 1 };
    for (vals, 0..) |v, i| src.set(u8, 0, i, v);

    const identity = [_]u8{ 0, 1, 2, 3 };
    const bg = Pixel_ARGB_16U{ 7, 7, 7, 7 };
    _ = try argb8888ToARGB16U(&src.buf, &dest.buf, &identity, 0, &bg, .{});
    try std.testing.expectEqual(@as(u16, 65535), dest.get(u16, 0, 0));
    try std.testing.expectEqual(@as(u16, 32896), dest.get(u16, 0, 1));
    try std.testing.expectEqual(@as(u16, 0), dest.get(u16, 0, 2));
    try std.testing.expectEqual(@as(u16, 257), dest.get(u16, 0, 3));

    // copyMask bit 0x8 >> i selects channel i, so 0x3 = channels 2 and 3.
    // Background entries for the untouched channels are deliberately distinct
    // from the converted values, so a wrong bit order would show up.
    const bg2 = Pixel_ARGB_16U{ 1111, 2222, 3333, 4444 };
    _ = try argb8888ToARGB16U(&src.buf, &dest.buf, &identity, 0x3, &bg2, .{});
    try std.testing.expectEqual(@as(u16, 65535), dest.get(u16, 0, 0));
    try std.testing.expectEqual(@as(u16, 32896), dest.get(u16, 0, 1));
    try std.testing.expectEqual(@as(u16, 3333), dest.get(u16, 0, 2));
    try std.testing.expectEqual(@as(u16, 4444), dest.get(u16, 0, 3));
}

test "argb8888ToRGB16U: 3-entry permuteMap picks which source channels survive" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, u8, 1, 1, 4);
    defer src.free(allocator);
    const dest = try alloc(allocator, u16, 1, 1, 3);
    defer dest.free(allocator);

    const vals = [_]u8{ 10, 20, 30, 40 };
    for (vals, 0..) |v, i| src.set(u8, 0, i, v);

    // Drop the leading alpha: {1,2,3}. (v*65535+127)/255 = 257*v exactly for
    // these, since 20*65535+127 = 255*5140 + 127.
    const skip_alpha = [_]u8{ 1, 2, 3 };
    const bg = [3]Pixel_16U{ 0, 0, 0 };
    _ = try argb8888ToRGB16U(&src.buf, &dest.buf, &skip_alpha, 0, &bg, .{});
    try std.testing.expectEqual(@as(u16, 5140), dest.get(u16, 0, 0));
    try std.testing.expectEqual(@as(u16, 7710), dest.get(u16, 0, 1));
    try std.testing.expectEqual(@as(u16, 10280), dest.get(u16, 0, 2));

    // copyMask is only 3 bits wide here: 0x4 -> first channel.
    const bg2 = [3]Pixel_16U{ 60000, 0, 0 };
    _ = try argb8888ToRGB16U(&src.buf, &dest.buf, &skip_alpha, 0x4, &bg2, .{});
    try std.testing.expectEqual(@as(u16, 60000), dest.get(u16, 0, 0));
    try std.testing.expectEqual(@as(u16, 7710), dest.get(u16, 0, 1));
}

test "rgb16UToARGB8888: permuteMap indexes the synthesised {255, R, G, B}" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, u16, 1, 1, 3);
    defer src.free(allocator);
    const dest = try alloc(allocator, u8, 1, 1, 4);
    defer dest.free(allocator);

    const vals = [_]u16{ 65535, 32768, 257 };
    for (vals, 0..) |v, i| src.set(u16, 0, i, v);

    // Identity: alpha is the synthesised 255, then round(v*255/65535) gives
    // 255, 128 and 1.
    const identity = [_]u8{ 0, 1, 2, 3 };
    const bg = Pixel_8888{ 0, 0, 0, 0 };
    _ = try rgb16UToARGB8888(&src.buf, &dest.buf, &identity, 0, &bg, .{});
    try std.testing.expectEqual(@as(u8, 255), dest.get(u8, 0, 0));
    try std.testing.expectEqual(@as(u8, 255), dest.get(u8, 0, 1));
    try std.testing.expectEqual(@as(u8, 128), dest.get(u8, 0, 2));
    try std.testing.expectEqual(@as(u8, 1), dest.get(u8, 0, 3));

    // BGRA order: {3,2,1,0} puts blue first and the synthesised alpha last.
    const bgra = [_]u8{ 3, 2, 1, 0 };
    _ = try rgb16UToARGB8888(&src.buf, &dest.buf, &bgra, 0, &bg, .{});
    try std.testing.expectEqual(@as(u8, 1), dest.get(u8, 0, 0));
    try std.testing.expectEqual(@as(u8, 128), dest.get(u8, 0, 1));
    try std.testing.expectEqual(@as(u8, 255), dest.get(u8, 0, 2));
    try std.testing.expectEqual(@as(u8, 255), dest.get(u8, 0, 3));
}

test "argb16UtoPlanar16U and planar16UtoARGB16U: A,R,G,B memory order round-trip" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, u16, 2, 2, 4);
    defer src.free(allocator);
    const a = try alloc(allocator, u16, 2, 2, 1);
    defer a.free(allocator);
    const r = try alloc(allocator, u16, 2, 2, 1);
    defer r.free(allocator);
    const g = try alloc(allocator, u16, 2, 2, 1);
    defer g.free(allocator);
    const b = try alloc(allocator, u16, 2, 2, 1);
    defer b.free(allocator);

    for (0..2) |y| for (0..2) |x| for (0..4) |ch| {
        src.set(u16, y, x * 4 + ch, @intCast(1000 * (ch + 1) + 10 * y + x));
    };

    _ = try argb16UtoPlanar16U(&src.buf, &a.buf, &r.buf, &g.buf, &b.buf, .{});
    const planes = [_]Buf{ a, r, g, b };
    for (planes, 0..) |p, ch| {
        for (0..2) |y| for (0..2) |x| {
            try std.testing.expectEqual(@as(u16, @intCast(1000 * (ch + 1) + 10 * y + x)), p.get(u16, y, x));
        };
    }

    const dest = try alloc(allocator, u16, 2, 2, 4);
    defer dest.free(allocator);
    _ = try planar16UtoARGB16U(&a.buf, &r.buf, &g.buf, &b.buf, &dest.buf, .{});
    for (0..2) |y| for (0..2) |x| for (0..4) |ch| {
        try std.testing.expectEqual(src.get(u16, y, x * 4 + ch), dest.get(u16, y, x * 4 + ch));
    };
}

test "rgb16UtoPlanar16U and planar16UtoRGB16U: R,G,B memory order round-trip" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, u16, 1, 2, 3);
    defer src.free(allocator);
    const r = try alloc(allocator, u16, 1, 2, 1);
    defer r.free(allocator);
    const g = try alloc(allocator, u16, 1, 2, 1);
    defer g.free(allocator);
    const b = try alloc(allocator, u16, 1, 2, 1);
    defer b.free(allocator);

    const vals = [_]u16{ 100, 200, 300, 400, 500, 600 };
    for (vals, 0..) |v, i| src.set(u16, 0, i, v);

    _ = try rgb16UtoPlanar16U(&src.buf, &r.buf, &g.buf, &b.buf, .{});
    try std.testing.expectEqual(@as(u16, 100), r.get(u16, 0, 0));
    try std.testing.expectEqual(@as(u16, 400), r.get(u16, 0, 1));
    try std.testing.expectEqual(@as(u16, 200), g.get(u16, 0, 0));
    try std.testing.expectEqual(@as(u16, 500), g.get(u16, 0, 1));
    try std.testing.expectEqual(@as(u16, 300), b.get(u16, 0, 0));
    try std.testing.expectEqual(@as(u16, 600), b.get(u16, 0, 1));

    const dest = try alloc(allocator, u16, 1, 2, 3);
    defer dest.free(allocator);
    _ = try planar16UtoRGB16U(&r.buf, &g.buf, &b.buf, &dest.buf, .{});
    for (vals, 0..) |v, i| try std.testing.expectEqual(v, dest.get(u16, 0, i));
}

test "argb16UtoRGB16U drops channel 0, rgba16U drops channel 3, bgra16U drops 3 and reverses" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, u16, 1, 1, 4);
    defer src.free(allocator);
    const dest = try alloc(allocator, u16, 1, 1, 3);
    defer dest.free(allocator);

    const vals = [_]u16{ 1000, 2000, 3000, 4000 };
    for (vals, 0..) |v, i| src.set(u16, 0, i, v);

    _ = try argb16UtoRGB16U(&src.buf, &dest.buf, .{});
    try std.testing.expectEqual(@as(u16, 2000), dest.get(u16, 0, 0));
    try std.testing.expectEqual(@as(u16, 3000), dest.get(u16, 0, 1));
    try std.testing.expectEqual(@as(u16, 4000), dest.get(u16, 0, 2));

    _ = try rgba16UtoRGB16U(&src.buf, &dest.buf, .{});
    try std.testing.expectEqual(@as(u16, 1000), dest.get(u16, 0, 0));
    try std.testing.expectEqual(@as(u16, 2000), dest.get(u16, 0, 1));
    try std.testing.expectEqual(@as(u16, 3000), dest.get(u16, 0, 2));

    // The header's prose claims all three "skip the first channel", but
    // BGRA16UtoRGB16U actually emits {src[2], src[1], src[0]} - it has to, to
    // turn BGR into RGB.
    _ = try bgra16UtoRGB16U(&src.buf, &dest.buf, .{});
    try std.testing.expectEqual(@as(u16, 3000), dest.get(u16, 0, 0));
    try std.testing.expectEqual(@as(u16, 2000), dest.get(u16, 0, 1));
    try std.testing.expectEqual(@as(u16, 1000), dest.get(u16, 0, 2));
}

test "rgb16Uto{ARGB,RGBA,BGRA}16U: alpha placement, channel order, and premultiply = (a*v + 32767) / 65535" {
    const allocator = std.testing.allocator;
    const rgb = try alloc(allocator, u16, 1, 1, 3);
    defer rgb.free(allocator);
    const a = try alloc(allocator, u16, 1, 1, 1);
    defer a.free(allocator);
    const dest = try alloc(allocator, u16, 1, 1, 4);
    defer dest.free(allocator);

    rgb.set(u16, 0, 0, 65535);
    rgb.set(u16, 0, 1, 32768);
    rgb.set(u16, 0, 2, 0);
    a.set(u16, 0, 0, 40000);

    // Not premultiplied: straight interleave, alpha leading.
    _ = try rgb16UtoARGB16U(&rgb.buf, &a.buf, 0, &dest.buf, false, .{});
    try std.testing.expectEqual(@as(u16, 40000), dest.get(u16, 0, 0));
    try std.testing.expectEqual(@as(u16, 65535), dest.get(u16, 0, 1));
    try std.testing.expectEqual(@as(u16, 32768), dest.get(u16, 0, 2));
    try std.testing.expectEqual(@as(u16, 0), dest.get(u16, 0, 3));

    // Alpha trailing, colours in source order.
    _ = try rgb16UtoRGBA16U(&rgb.buf, &a.buf, 0, &dest.buf, false, .{});
    try std.testing.expectEqual(@as(u16, 65535), dest.get(u16, 0, 0));
    try std.testing.expectEqual(@as(u16, 32768), dest.get(u16, 0, 1));
    try std.testing.expectEqual(@as(u16, 0), dest.get(u16, 0, 2));
    try std.testing.expectEqual(@as(u16, 40000), dest.get(u16, 0, 3));

    // Alpha trailing, colours reversed.
    _ = try rgb16UtoBGRA16U(&rgb.buf, &a.buf, 0, &dest.buf, false, .{});
    try std.testing.expectEqual(@as(u16, 0), dest.get(u16, 0, 0));
    try std.testing.expectEqual(@as(u16, 32768), dest.get(u16, 0, 1));
    try std.testing.expectEqual(@as(u16, 65535), dest.get(u16, 0, 2));
    try std.testing.expectEqual(@as(u16, 40000), dest.get(u16, 0, 3));

    // Premultiplied, with alpha = 32768:
    //   (32768*65535 + 32767) / 65535 = 2147483647 / 65535 = 32768
    //   (32768*32768 + 32767) / 65535 = 1073774592 / 65535 = 16384
    //   0 -> 0.  Alpha itself is stored unscaled.
    a.set(u16, 0, 0, 32768);
    _ = try rgb16UtoARGB16U(&rgb.buf, &a.buf, 0, &dest.buf, true, .{});
    try std.testing.expectEqual(@as(u16, 32768), dest.get(u16, 0, 0));
    try std.testing.expectEqual(@as(u16, 32768), dest.get(u16, 0, 1));
    try std.testing.expectEqual(@as(u16, 16384), dest.get(u16, 0, 2));
    try std.testing.expectEqual(@as(u16, 0), dest.get(u16, 0, 3));
}

test "planar16UtoPlanar8Dithered with Dither.none: (v * 255 + 32767) / 65535" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, u16, 1, 4, 1);
    defer src.free(allocator);
    const dest = try alloc(allocator, u8, 1, 4, 1);
    defer dest.free(allocator);

    // Multiples of 257 land exactly on an 8-bit value, so no dither method
    // could disagree about them: 257*k -> k.
    const vals = [_]u16{ 0, 257, 25700, 65535 };
    for (vals, 0..) |v, i| src.set(u16, 0, i, v);

    _ = try planar16UtoPlanar8Dithered(&src.buf, &dest.buf, Dither.none, .{});
    const expected = [_]u8{ 0, 1, 100, 255 };
    for (expected, 0..) |e, i| try std.testing.expectEqual(e, dest.get(u8, 0, i));
}

test "rgb16UtoRGB888Dithered and argb16UtoARGB8888Dithered with Dither.none" {
    const allocator = std.testing.allocator;
    const src3 = try alloc(allocator, u16, 1, 1, 3);
    defer src3.free(allocator);
    const dest3 = try alloc(allocator, u8, 1, 1, 3);
    defer dest3.free(allocator);

    const vals3 = [_]u16{ 0, 25700, 65535 };
    for (vals3, 0..) |v, i| src3.set(u16, 0, i, v);
    _ = try rgb16UtoRGB888Dithered(&src3.buf, &dest3.buf, Dither.none, .{});
    try std.testing.expectEqual(@as(u8, 0), dest3.get(u8, 0, 0));
    try std.testing.expectEqual(@as(u8, 100), dest3.get(u8, 0, 1));
    try std.testing.expectEqual(@as(u8, 255), dest3.get(u8, 0, 2));

    const src4 = try alloc(allocator, u16, 1, 1, 4);
    defer src4.free(allocator);
    const dest4 = try alloc(allocator, u8, 1, 1, 4);
    defer dest4.free(allocator);

    const vals4 = [_]u16{ 257, 25700, 65535, 0 };
    for (vals4, 0..) |v, i| src4.set(u16, 0, i, v);
    const reversed = [_]u8{ 3, 2, 1, 0 };
    _ = try argb16UtoARGB8888Dithered(&src4.buf, &dest4.buf, Dither.none, &reversed, .{});
    try std.testing.expectEqual(@as(u8, 0), dest4.get(u8, 0, 0)); // src[3]
    try std.testing.expectEqual(@as(u8, 255), dest4.get(u8, 0, 1)); // src[2]
    try std.testing.expectEqual(@as(u8, 100), dest4.get(u8, 0, 2)); // src[1]
    try std.testing.expectEqual(@as(u8, 1), dest4.get(u8, 0, 3)); // src[0]
}

test "planarFtoPlanar8Dithered with Dither.none: 255 * (v - min) / (max - min), clamped" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, f32, 1, 4, 1);
    defer src.free(allocator);
    const dest = try alloc(allocator, u8, 1, 4, 1);
    defer dest.free(allocator);

    src.set(f32, 0, 0, 0.0);
    src.set(f32, 0, 1, 100.0 / 255.0);
    src.set(f32, 0, 2, 1.0);
    src.set(f32, 0, 3, 5.0); // above max -> saturates

    _ = try planarFtoPlanar8Dithered(&src.buf, &dest.buf, 1.0, 0.0, Dither.none, .{});
    const expected = [_]u8{ 0, 100, 255, 255 };
    for (expected, 0..) |e, i| try std.testing.expectEqual(e, dest.get(u8, 0, i));
}

test "rgbFFFtoRGB888Dithered: per-channel max/min, and a negative range inverts that channel" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, f32, 1, 1, 3);
    defer src.free(allocator);
    const dest = try alloc(allocator, u8, 1, 1, 3);
    defer dest.free(allocator);

    src.set(f32, 0, 0, 0.0);
    src.set(f32, 0, 1, 100.0 / 255.0);
    src.set(f32, 0, 2, 0.0);

    const max = [3]Pixel_F{ 1.0, 1.0, 1.0 };
    const min = [3]Pixel_F{ 0.0, 0.0, 0.0 };
    _ = try rgbFFFtoRGB888Dithered(&src.buf, &dest.buf, &max, &min, Dither.none, .{});
    try std.testing.expectEqual(@as(u8, 0), dest.get(u8, 0, 0));
    try std.testing.expectEqual(@as(u8, 100), dest.get(u8, 0, 1));
    try std.testing.expectEqual(@as(u8, 0), dest.get(u8, 0, 2));

    // Channel 2 with max < min: 0.0 is now full intensity.
    const max2 = [3]Pixel_F{ 1.0, 1.0, 0.0 };
    const min2 = [3]Pixel_F{ 0.0, 0.0, 1.0 };
    _ = try rgbFFFtoRGB888Dithered(&src.buf, &dest.buf, &max2, &min2, Dither.none, .{});
    try std.testing.expectEqual(@as(u8, 255), dest.get(u8, 0, 2));
}

test "argbFFFFtoARGB8888Dithered: max/min are indexed in destination order, after the permute" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, f32, 1, 1, 4);
    defer src.free(allocator);
    const dest = try alloc(allocator, u8, 1, 1, 4);
    defer dest.free(allocator);

    src.set(f32, 0, 0, 1.0);
    src.set(f32, 0, 1, 100.0 / 255.0);
    src.set(f32, 0, 2, 0.0);
    src.set(f32, 0, 3, 0.5);

    const max = Pixel_FFFF{ 1.0, 1.0, 1.0, 1.0 };
    const min = Pixel_FFFF{ 0.0, 0.0, 0.0, 0.0 };
    const identity = [_]u8{ 0, 1, 2, 3 };
    _ = try argbFFFFtoARGB8888Dithered(&src.buf, &dest.buf, &max, &min, Dither.none, &identity, .{});
    try std.testing.expectEqual(@as(u8, 255), dest.get(u8, 0, 0));
    try std.testing.expectEqual(@as(u8, 100), dest.get(u8, 0, 1));
    try std.testing.expectEqual(@as(u8, 0), dest.get(u8, 0, 2));

    const reversed = [_]u8{ 3, 2, 1, 0 };
    _ = try argbFFFFtoARGB8888Dithered(&src.buf, &dest.buf, &max, &min, Dither.none, &reversed, .{});
    try std.testing.expectEqual(@as(u8, 0), dest.get(u8, 0, 1)); // src[2] = 0.0
    try std.testing.expectEqual(@as(u8, 100), dest.get(u8, 0, 2)); // src[1]
    try std.testing.expectEqual(@as(u8, 255), dest.get(u8, 0, 3)); // src[0] = 1.0
}

test "xrgb8888ToPlanar8 / bgrx8888ToPlanar8: X is dropped from opposite ends" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, u8, 1, 1, 4);
    defer src.free(allocator);
    const p0 = try alloc(allocator, u8, 1, 1, 1);
    defer p0.free(allocator);
    const p1 = try alloc(allocator, u8, 1, 1, 1);
    defer p1.free(allocator);
    const p2 = try alloc(allocator, u8, 1, 1, 1);
    defer p2.free(allocator);

    const vals = [_]u8{ 10, 20, 30, 40 };
    for (vals, 0..) |v, i| src.set(u8, 0, i, v);

    // XRGB: the leading 10 is discarded.
    _ = try xrgb8888ToPlanar8(&src.buf, &p0.buf, &p1.buf, &p2.buf, .{});
    try std.testing.expectEqual(@as(u8, 20), p0.get(u8, 0, 0));
    try std.testing.expectEqual(@as(u8, 30), p1.get(u8, 0, 0));
    try std.testing.expectEqual(@as(u8, 40), p2.get(u8, 0, 0));

    // BGRX: the trailing 40 is discarded. Arguments are (blue, green, red), so
    // p0 receives src[0] = 10 as blue.
    _ = try bgrx8888ToPlanar8(&src.buf, &p0.buf, &p1.buf, &p2.buf, .{});
    try std.testing.expectEqual(@as(u8, 10), p0.get(u8, 0, 0));
    try std.testing.expectEqual(@as(u8, 20), p1.get(u8, 0, 0));
    try std.testing.expectEqual(@as(u8, 30), p2.get(u8, 0, 0));
}

test "xrgbFFFFToPlanarF / bgrxFFFFToPlanarF: X is dropped from opposite ends" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, f32, 1, 1, 4);
    defer src.free(allocator);
    const p0 = try alloc(allocator, f32, 1, 1, 1);
    defer p0.free(allocator);
    const p1 = try alloc(allocator, f32, 1, 1, 1);
    defer p1.free(allocator);
    const p2 = try alloc(allocator, f32, 1, 1, 1);
    defer p2.free(allocator);

    const vals = [_]f32{ 0.125, 0.25, 0.5, 0.75 };
    for (vals, 0..) |v, i| src.set(f32, 0, i, v);

    _ = try xrgbFFFFToPlanarF(&src.buf, &p0.buf, &p1.buf, &p2.buf, .{});
    try std.testing.expectEqual(@as(f32, 0.25), p0.get(f32, 0, 0));
    try std.testing.expectEqual(@as(f32, 0.5), p1.get(f32, 0, 0));
    try std.testing.expectEqual(@as(f32, 0.75), p2.get(f32, 0, 0));

    _ = try bgrxFFFFToPlanarF(&src.buf, &p0.buf, &p1.buf, &p2.buf, .{});
    try std.testing.expectEqual(@as(f32, 0.125), p0.get(f32, 0, 0));
    try std.testing.expectEqual(@as(f32, 0.25), p1.get(f32, 0, 0));
    try std.testing.expectEqual(@as(f32, 0.5), p2.get(f32, 0, 0));
}

test "planar8ToXRGB8888 / planar8ToBGRX8888: the scalar X lands first or last" {
    const allocator = std.testing.allocator;
    const r = try alloc(allocator, u8, 1, 1, 1);
    defer r.free(allocator);
    const g = try alloc(allocator, u8, 1, 1, 1);
    defer g.free(allocator);
    const b = try alloc(allocator, u8, 1, 1, 1);
    defer b.free(allocator);
    const dest = try alloc(allocator, u8, 1, 1, 4);
    defer dest.free(allocator);

    r.set(u8, 0, 0, 1);
    g.set(u8, 0, 0, 2);
    b.set(u8, 0, 0, 3);

    _ = try planar8ToXRGB8888(99, &r.buf, &g.buf, &b.buf, &dest.buf, .{});
    try std.testing.expectEqual(@as(u8, 99), dest.get(u8, 0, 0));
    try std.testing.expectEqual(@as(u8, 1), dest.get(u8, 0, 1));
    try std.testing.expectEqual(@as(u8, 2), dest.get(u8, 0, 2));
    try std.testing.expectEqual(@as(u8, 3), dest.get(u8, 0, 3));

    _ = try planar8ToBGRX8888(&b.buf, &g.buf, &r.buf, 99, &dest.buf, .{});
    try std.testing.expectEqual(@as(u8, 3), dest.get(u8, 0, 0));
    try std.testing.expectEqual(@as(u8, 2), dest.get(u8, 0, 1));
    try std.testing.expectEqual(@as(u8, 1), dest.get(u8, 0, 2));
    try std.testing.expectEqual(@as(u8, 99), dest.get(u8, 0, 3));
}

test "planar8ToXRGBFFFF / planar8ToBGRXFFFF: colours scale by max/min, the X float does not" {
    const allocator = std.testing.allocator;
    const r = try alloc(allocator, u8, 1, 1, 1);
    defer r.free(allocator);
    const g = try alloc(allocator, u8, 1, 1, 1);
    defer g.free(allocator);
    const b = try alloc(allocator, u8, 1, 1, 1);
    defer b.free(allocator);
    const dest = try alloc(allocator, f32, 1, 1, 4);
    defer dest.free(allocator);

    // result = (max - min) * v / 255 + min, with max = 1, min = 0.
    r.set(u8, 0, 0, 255);
    g.set(u8, 0, 0, 0);
    b.set(u8, 0, 0, 51); // 51/255 = 0.2
    const max = Pixel_FFFF{ 1.0, 1.0, 1.0, 1.0 };
    const min = Pixel_FFFF{ 0.0, 0.0, 0.0, 0.0 };

    _ = try planar8ToXRGBFFFF(0.25, &r.buf, &g.buf, &b.buf, &dest.buf, &max, &min, .{});
    try std.testing.expectEqual(@as(f32, 0.25), dest.get(f32, 0, 0));
    try std.testing.expectEqual(@as(f32, 1.0), dest.get(f32, 0, 1));
    try std.testing.expectEqual(@as(f32, 0.0), dest.get(f32, 0, 2));
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), dest.get(f32, 0, 3), 1e-6);

    _ = try planar8ToBGRXFFFF(&b.buf, &g.buf, &r.buf, 0.25, &dest.buf, &max, &min, .{});
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), dest.get(f32, 0, 0), 1e-6);
    try std.testing.expectEqual(@as(f32, 0.0), dest.get(f32, 0, 1));
    try std.testing.expectEqual(@as(f32, 1.0), dest.get(f32, 0, 2));
    try std.testing.expectEqual(@as(f32, 0.25), dest.get(f32, 0, 3));

    // A doubled range halves the result: max = 2 -> 255 maps to 2.0.
    const max2 = Pixel_FFFF{ 2.0, 2.0, 2.0, 2.0 };
    _ = try planar8ToXRGBFFFF(0.25, &r.buf, &g.buf, &b.buf, &dest.buf, &max2, &min, .{});
    try std.testing.expectEqual(@as(f32, 0.25), dest.get(f32, 0, 0)); // X unchanged
    try std.testing.expectEqual(@as(f32, 2.0), dest.get(f32, 0, 1));
}

test "planarFToXRGB8888 / planarFToBGRX8888: quantise to 0..255 with a Pixel_8 X" {
    const allocator = std.testing.allocator;
    const r = try alloc(allocator, f32, 1, 1, 1);
    defer r.free(allocator);
    const g = try alloc(allocator, f32, 1, 1, 1);
    defer g.free(allocator);
    const b = try alloc(allocator, f32, 1, 1, 1);
    defer b.free(allocator);
    const dest = try alloc(allocator, u8, 1, 1, 4);
    defer dest.free(allocator);

    r.set(f32, 0, 0, 1.0);
    g.set(f32, 0, 0, 100.0 / 255.0);
    b.set(f32, 0, 0, -1.0); // below min -> saturates to 0
    const max = Pixel_FFFF{ 1.0, 1.0, 1.0, 1.0 };
    const min = Pixel_FFFF{ 0.0, 0.0, 0.0, 0.0 };

    _ = try planarFToXRGB8888(7, &r.buf, &g.buf, &b.buf, &dest.buf, &max, &min, .{});
    try std.testing.expectEqual(@as(u8, 7), dest.get(u8, 0, 0));
    try std.testing.expectEqual(@as(u8, 255), dest.get(u8, 0, 1));
    try std.testing.expectEqual(@as(u8, 100), dest.get(u8, 0, 2));
    try std.testing.expectEqual(@as(u8, 0), dest.get(u8, 0, 3));

    _ = try planarFToBGRX8888(&b.buf, &g.buf, &r.buf, 7, &dest.buf, &max, &min, .{});
    try std.testing.expectEqual(@as(u8, 0), dest.get(u8, 0, 0));
    try std.testing.expectEqual(@as(u8, 100), dest.get(u8, 0, 1));
    try std.testing.expectEqual(@as(u8, 255), dest.get(u8, 0, 2));
    try std.testing.expectEqual(@as(u8, 7), dest.get(u8, 0, 3));
}

test "planarFToXRGBFFFF / planarFToBGRXFFFF: straight interleave, no scaling arguments" {
    const allocator = std.testing.allocator;
    const r = try alloc(allocator, f32, 1, 2, 1);
    defer r.free(allocator);
    const g = try alloc(allocator, f32, 1, 2, 1);
    defer g.free(allocator);
    const b = try alloc(allocator, f32, 1, 2, 1);
    defer b.free(allocator);
    const dest = try alloc(allocator, f32, 1, 2, 4);
    defer dest.free(allocator);

    // Deliberately out of [0,1] to prove nothing is clamped or rescaled.
    r.set(f32, 0, 0, -3.5);
    g.set(f32, 0, 0, 17.25);
    b.set(f32, 0, 0, 0.0);
    r.set(f32, 0, 1, 1.0);
    g.set(f32, 0, 1, 2.0);
    b.set(f32, 0, 1, 3.0);

    _ = try planarFToXRGBFFFF(-1.0, &r.buf, &g.buf, &b.buf, &dest.buf, .{});
    try std.testing.expectEqual(@as(f32, -1.0), dest.get(f32, 0, 0));
    try std.testing.expectEqual(@as(f32, -3.5), dest.get(f32, 0, 1));
    try std.testing.expectEqual(@as(f32, 17.25), dest.get(f32, 0, 2));
    try std.testing.expectEqual(@as(f32, 0.0), dest.get(f32, 0, 3));
    try std.testing.expectEqual(@as(f32, -1.0), dest.get(f32, 0, 4));
    try std.testing.expectEqual(@as(f32, 1.0), dest.get(f32, 0, 5));

    _ = try planarFToBGRXFFFF(&b.buf, &g.buf, &r.buf, -1.0, &dest.buf, .{});
    try std.testing.expectEqual(@as(f32, 0.0), dest.get(f32, 0, 0));
    try std.testing.expectEqual(@as(f32, 17.25), dest.get(f32, 0, 1));
    try std.testing.expectEqual(@as(f32, -3.5), dest.get(f32, 0, 2));
    try std.testing.expectEqual(@as(f32, -1.0), dest.get(f32, 0, 3));
}

test "an out-of-range permuteMap entry is rejected with kvImageInvalidParameter (-21773)" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, u16, 1, 1, 4);
    defer src.free(allocator);
    const dest = try alloc(allocator, u8, 1, 1, 4);
    defer dest.free(allocator);

    const bad = [_]u8{ 0, 1, 2, 4 }; // 4 is not a channel index
    const bg = Pixel_8888{ 0, 0, 0, 0 };
    try std.testing.expectError(
        Error.InvalidParameter,
        argb16UToARGB8888(&src.buf, &dest.buf, &bad, 0, &bg, .{}),
    );
    try std.testing.expectEqual(@as(vImage_Error, -21773), types.ErrorCode.kvImageInvalidParameter);
}

test "an unsupported dither method is rejected with kvImageInvalidParameter" {
    const allocator = std.testing.allocator;
    const src = try alloc(allocator, u16, 1, 1, 1);
    defer src.free(allocator);
    const dest = try alloc(allocator, u8, 1, 1, 1);
    defer dest.free(allocator);

    // 99 is not one of the kvImageConvert_Dither* constants.
    try std.testing.expectError(
        Error.InvalidParameter,
        planar16UtoPlanar8Dithered(&src.buf, &dest.buf, 99, .{}),
    );
    // Dither.none, by contrast, is accepted.
    _ = try planar16UtoPlanar8Dithered(&src.buf, &dest.buf, Dither.none, .{});
}
