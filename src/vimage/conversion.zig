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
const Flags = types.Flags;

// ============================================================================
// Sub-modules
//
// The Conversion.h surface is large enough that it is split by format family
// rather than kept in one file. Each sub-module below covers one family and
// carries its own tests.
// ============================================================================

/// 16-bit packed pixels: ARGB1555, RGBA5551, RGB565.
pub const packed16 = @import("conversion_packed16.zig");
/// 32-bit 10-bit-per-channel packed pixels: ARGB2101010, XRGB2101010, RGBA1010102.
pub const packed10 = @import("conversion_packed10.zig");
/// Chroma-subsampled video formats: 420, 422 and 444 YpCbCr.
pub const ycbcr = @import("conversion_ycbcr.zig");
/// The signed 4.12 fixed-point format, Pixel_16Q12.
pub const q12 = @import("conversion_q12.zig");
/// Remaining N-to-M format pairs across the 8/12/16U/16F/F types.
pub const formats = @import("conversion_formats.zig");
/// Sub-byte planar (1/2/4 bits per pixel) and indexed colour.
pub const indexed = @import("conversion_indexed.zig");
/// Flatten against an opaque background, and chunky/planar de-interleaving.
pub const flatten = @import("conversion_flatten_chunky.zig");
/// Buffer fill, channel overwrite, channel permute, and byte-swap variants.
pub const fill = @import("conversion_fill_misc.zig");

// ============================================================================
// Clip
// ============================================================================

/// Clip pixel values of a PlanarF image to [min_val, max_val].
///
/// Can also be used for multichannel float formats (e.g. ARGBFFFF) by
/// scaling `vImage_Buffer.width` by the channel count.
pub fn clipPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, max_val: Pixel_F, min_val: Pixel_F, flags: Options) Error!usize {
    return check(c.vImageClip_PlanarF(src, dest, max_val, min_val, flags.bits()));
}

// ============================================================================
// Planar format conversions
// ============================================================================

/// Convert Planar8 to PlanarF.
///
///     result = (maxFloat - minFloat) * pixel / 255.0 + minFloat
pub fn planar8ToPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, max_float: Pixel_F, min_float: Pixel_F, flags: Options) Error!usize {
    return check(c.vImageConvert_Planar8toPlanarF(src, dest, max_float, min_float, flags.bits()));
}

/// Convert PlanarF to Planar8.
///
///     result = CLIP(0, 255, 255.0 * (pixel - minFloat) / (maxFloat - minFloat) + 0.5)
pub fn planarFToPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, max_float: Pixel_F, min_float: Pixel_F, flags: Options) Error!usize {
    return check(c.vImageConvert_PlanarFtoPlanar8(src, dest, max_float, min_float, flags.bits()));
}

/// Convert half-precision float (Planar16F) to single-precision float (PlanarF).
pub fn planar16FToPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_Planar16FtoPlanarF(src, dest, flags.bits()));
}

/// Convert single-precision float (PlanarF) to half-precision float (Planar16F).
pub fn planarFToPlanar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_PlanarFtoPlanar16F(src, dest, flags.bits()));
}

/// Convert Planar8 directly to half-precision float (Planar16F).
pub fn planar8ToPlanar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_Planar8toPlanar16F(src, dest, flags.bits()));
}

/// Convert half-precision float (Planar16F) to Planar8.
pub fn planar16FToPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_Planar16FtoPlanar8(src, dest, flags.bits()));
}

/// Convert 16-bit signed integer to PlanarF.
///
///     result = scale * pixel + offset
pub fn convert16SToF(src: *const vImage_Buffer, dest: *const vImage_Buffer, offset: f32, scale: f32, flags: Options) Error!usize {
    return check(c.vImageConvert_16SToF(src, dest, offset, scale, flags.bits()));
}

/// Convert 16-bit unsigned integer to PlanarF.
///
///     result = scale * pixel + offset
pub fn convert16UToF(src: *const vImage_Buffer, dest: *const vImage_Buffer, offset: f32, scale: f32, flags: Options) Error!usize {
    return check(c.vImageConvert_16UToF(src, dest, offset, scale, flags.bits()));
}

/// Convert PlanarF to 16-bit signed integer.
///
///     result = (pixel - offset) / scale
pub fn convertFTo16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, offset: f32, scale: f32, flags: Options) Error!usize {
    return check(c.vImageConvert_FTo16S(src, dest, offset, scale, flags.bits()));
}

/// Convert PlanarF to 16-bit unsigned integer.
///
///     result = (pixel - offset) / scale
pub fn convertFTo16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, offset: f32, scale: f32, flags: Options) Error!usize {
    return check(c.vImageConvert_FTo16U(src, dest, offset, scale, flags.bits()));
}

/// Convert 16-bit unsigned integer to Planar8.
///
///     result = (pixel * 255 + 32767) / 65535
pub fn convert16UToPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_16UToPlanar8(src, dest, flags.bits()));
}

/// Convert Planar8 to 16-bit unsigned integer.
pub fn planar8To16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_Planar8To16U(src, dest, flags.bits()));
}

// ============================================================================
// 4-channel combine (planar -> interleaved)
// ============================================================================

/// Combine four Planar8 buffers into a single ARGB8888 interleaved buffer.
pub fn planar8ToARGB8888(
    srcA: *const vImage_Buffer,
    srcR: *const vImage_Buffer,
    srcG: *const vImage_Buffer,
    srcB: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_Planar8toARGB8888(srcA, srcR, srcG, srcB, dest, flags.bits()));
}

/// Combine four PlanarF buffers into a single ARGBFFFF interleaved buffer.
pub fn planarFToARGBFFFF(
    srcA: *const vImage_Buffer,
    srcR: *const vImage_Buffer,
    srcG: *const vImage_Buffer,
    srcB: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_PlanarFtoARGBFFFF(srcA, srcR, srcG, srcB, dest, flags.bits()));
}

// ============================================================================
// 4-channel split (interleaved -> planar)
// ============================================================================

/// Split an ARGB8888 interleaved buffer into four Planar8 buffers.
pub fn argb8888ToPlanar8(
    srcARGB: *const vImage_Buffer,
    destA: *const vImage_Buffer,
    destR: *const vImage_Buffer,
    destG: *const vImage_Buffer,
    destB: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB8888toPlanar8(srcARGB, destA, destR, destG, destB, flags.bits()));
}

/// Split an ARGBFFFF interleaved buffer into four PlanarF buffers.
pub fn argbFFFFToPlanarF(
    srcARGB: *const vImage_Buffer,
    destA: *const vImage_Buffer,
    destR: *const vImage_Buffer,
    destG: *const vImage_Buffer,
    destB: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGBFFFFtoPlanarF(srcARGB, destA, destR, destG, destB, flags.bits()));
}

// ============================================================================
// Cross-format combine/extract (Planar8 <-> ARGBFFFF, PlanarF <-> ARGB8888)
// ============================================================================

/// Combine four Planar8 channel buffers into an ARGBFFFF buffer, with per-channel min/max scaling.
pub fn planar8ToARGBFFFF(
    alpha: *const vImage_Buffer,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    max_float: Pixel_FFFF,
    min_float: Pixel_FFFF,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_Planar8ToARGBFFFF(alpha, red, green, blue, dest, &max_float, &min_float, flags.bits()));
}

/// Split an ARGB8888 buffer into four PlanarF buffers, with per-channel min/max scaling.
pub fn argb8888ToPlanarF(
    src: *const vImage_Buffer,
    alpha: *const vImage_Buffer,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    max_float: Pixel_FFFF,
    min_float: Pixel_FFFF,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB8888toPlanarF(src, alpha, red, green, blue, &max_float, &min_float, flags.bits()));
}

/// Split an ARGBFFFF buffer into four Planar8 buffers, with per-channel min/max scaling.
pub fn argbFFFFToPlanar8(
    src: *const vImage_Buffer,
    alpha: *const vImage_Buffer,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    max_float: Pixel_FFFF,
    min_float: Pixel_FFFF,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGBFFFFtoPlanar8(src, alpha, red, green, blue, &max_float, &min_float, flags.bits()));
}

/// Combine four PlanarF channel buffers into an ARGB8888 buffer, with per-channel min/max scaling.
pub fn planarFToARGB8888(
    alpha: *const vImage_Buffer,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    max_float: Pixel_FFFF,
    min_float: Pixel_FFFF,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_PlanarFToARGB8888(alpha, red, green, blue, dest, &max_float, &min_float, flags.bits()));
}

// ============================================================================
// 3-channel interleave / deinterleave
// ============================================================================

/// Combine three Planar8 buffers into an RGB888 interleaved buffer.
pub fn planar8ToRGB888(
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_Planar8toRGB888(red, green, blue, dest, flags.bits()));
}

/// Combine three PlanarF buffers into an RGBFFF interleaved buffer.
pub fn planarFToRGBFFF(
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_PlanarFtoRGBFFF(red, green, blue, dest, flags.bits()));
}

/// Split an RGB888 interleaved buffer into three Planar8 buffers.
pub fn rgb888ToPlanar8(
    src: *const vImage_Buffer,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGB888toPlanar8(src, red, green, blue, flags.bits()));
}

/// Split an RGBFFF interleaved buffer into three PlanarF buffers.
pub fn rgbFFFToPlanarF(
    src: *const vImage_Buffer,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGBFFFtoPlanarF(src, red, green, blue, flags.bits()));
}

// ============================================================================
// Channel ordering
// ============================================================================

/// Channel ordering for 4-channel interleaved formats.
pub const ChannelOrder = enum {
    argb,
    rgba,
    bgra,
};

// ============================================================================
// RGB888 -> 4-channel (add alpha)
// ============================================================================

/// Convert RGB888 to a 4-channel 8-bit format (ARGB, RGBA, or BGRA), optionally
/// adding an alpha channel from a planar buffer or a constant value.
///
/// Pass `alpha_src` to use per-pixel alpha; pass `null` to fill with `alpha`.
/// Set `premultiply` to true to premultiply RGB by the alpha value.
pub fn rgb888ToInterleaved8888(
    rgb_src: *const vImage_Buffer,
    alpha_src: ?*const vImage_Buffer,
    alpha: Pixel_8,
    dest: *const vImage_Buffer,
    order: ChannelOrder,
    premultiply: bool,
    flags: Options,
) Error!usize {
    return check(switch (order) {
        .argb => c.vImageConvert_RGB888toARGB8888(rgb_src, alpha_src, alpha, dest, premultiply, flags.bits()),
        .rgba => c.vImageConvert_RGB888toRGBA8888(rgb_src, alpha_src, alpha, dest, premultiply, flags.bits()),
        .bgra => c.vImageConvert_RGB888toBGRA8888(rgb_src, alpha_src, alpha, dest, premultiply, flags.bits()),
    });
}

/// Strip the alpha channel from a 4-channel 8-bit buffer to produce RGB888.
pub fn interleaved8888ToRGB888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    order: ChannelOrder,
    flags: Options,
) Error!usize {
    return check(switch (order) {
        .argb => c.vImageConvert_ARGB8888toRGB888(src, dest, flags.bits()),
        .rgba => c.vImageConvert_RGBA8888toRGB888(src, dest, flags.bits()),
        .bgra => c.vImageConvert_BGRA8888toRGB888(src, dest, flags.bits()),
    });
}

// ============================================================================
// Float 4-channel <-> 3-channel
// ============================================================================

/// Strip the alpha channel from a 4-channel float buffer to produce RGBFFF.
pub fn interleavedFFFFToRGBFFF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    order: ChannelOrder,
    flags: Options,
) Error!usize {
    return check(switch (order) {
        .argb => c.vImageConvert_ARGBFFFFtoRGBFFF(src, dest, flags.bits()),
        .rgba => c.vImageConvert_RGBAFFFFtoRGBFFF(src, dest, flags.bits()),
        .bgra => c.vImageConvert_BGRAFFFFtoRGBFFF(src, dest, flags.bits()),
    });
}

/// Convert RGBFFF to a 4-channel float format (ARGB, RGBA, or BGRA), optionally
/// adding an alpha channel from a planar buffer or a constant value.
///
/// Pass `alpha_src` to use per-pixel alpha; pass `null` to fill with `alpha`.
/// Set `premultiply` to true to premultiply RGB by the alpha value.
pub fn rgbFFFToInterleavedFFFF(
    rgb_src: *const vImage_Buffer,
    alpha_src: ?*const vImage_Buffer,
    alpha: Pixel_F,
    dest: *const vImage_Buffer,
    order: ChannelOrder,
    premultiply: bool,
    flags: Options,
) Error!usize {
    return check(switch (order) {
        .argb => c.vImageConvert_RGBFFFtoARGBFFFF(rgb_src, alpha_src, alpha, dest, premultiply, flags.bits()),
        .rgba => c.vImageConvert_RGBFFFtoRGBAFFFF(rgb_src, alpha_src, alpha, dest, premultiply, flags.bits()),
        .bgra => c.vImageConvert_RGBFFFtoBGRAFFFF(rgb_src, alpha_src, alpha, dest, premultiply, flags.bits()),
    });
}

/// Flatten an 8-bit 4-channel image against an opaque background color,
/// producing an RGB888 result.
pub fn flatten8888ToRGB888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    background_color: Pixel_8888,
    order: ChannelOrder,
    is_premultiplied: bool,
    flags: Options,
) Error!usize {
    return check(switch (order) {
        .argb => c.vImageFlatten_ARGB8888ToRGB888(src, dest, &background_color, is_premultiplied, flags.bits()),
        .rgba => c.vImageFlatten_RGBA8888ToRGB888(src, dest, &background_color, is_premultiplied, flags.bits()),
        .bgra => c.vImageFlatten_BGRA8888ToRGB888(src, dest, &background_color, is_premultiplied, flags.bits()),
    });
}

/// Flatten a float 4-channel image against an opaque background color,
/// producing an RGBFFF result.
pub fn flattenFFFFToRGBFFF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    background_color: Pixel_FFFF,
    order: ChannelOrder,
    is_premultiplied: bool,
    flags: Options,
) Error!usize {
    return check(switch (order) {
        .argb => c.vImageFlatten_ARGBFFFFToRGBFFF(src, dest, &background_color, is_premultiplied, flags.bits()),
        .rgba => c.vImageFlatten_RGBAFFFFToRGBFFF(src, dest, &background_color, is_premultiplied, flags.bits()),
        .bgra => c.vImageFlatten_BGRAFFFFToRGBFFF(src, dest, &background_color, is_premultiplied, flags.bits()),
    });
}

// ============================================================================
// Permute channels
// ============================================================================

/// Reorder the 4 color channels of an ARGB8888 image according to permuteMap.
///
/// Each value in permuteMap must be 0..3. For example, {3,2,1,0} converts
/// ARGB -> BGRA.
pub fn permuteChannelsARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, permute_map: [4]u8, flags: Options) Error!usize {
    return check(c.vImagePermuteChannels_ARGB8888(src, dest, &permute_map, flags.bits()));
}

/// Reorder the 4 color channels of an ARGB16U image according to permuteMap.
pub fn permuteChannelsARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, permute_map: [4]u8, flags: Options) Error!usize {
    return check(c.vImagePermuteChannels_ARGB16U(src, dest, &permute_map, flags.bits()));
}

/// Reorder the 4 color channels of an ARGBFFFF image according to permuteMap.
pub fn permuteChannelsARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, permute_map: [4]u8, flags: Options) Error!usize {
    return check(c.vImagePermuteChannels_ARGBFFFF(src, dest, &permute_map, flags.bits()));
}

/// Reorder the 3 color channels of an RGB888 image according to permuteMap.
///
/// Each value in permuteMap must be 0..2. For example, {2,1,0} converts
/// RGB -> BGR.
pub fn permuteChannelsRGB888(src: *const vImage_Buffer, dest: *const vImage_Buffer, permute_map: [3]u8, flags: Options) Error!usize {
    return check(c.vImagePermuteChannels_RGB888(src, dest, &permute_map, flags.bits()));
}

// ============================================================================
// Extract single channel
// ============================================================================

/// Extract a single channel from a 4-channel 8-bit buffer to a Planar8 buffer.
///
/// channelIndex: 0 = first channel (e.g. A in ARGB), 3 = last channel.
pub fn extractChannelARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, channel_index: usize, flags: Options) Error!usize {
    return check(c.vImageExtractChannel_ARGB8888(src, dest, @intCast(channel_index), flags.bits()));
}

/// Extract a single channel from a 4-channel 16U buffer to a Planar16U buffer.
pub fn extractChannelARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, channel_index: usize, flags: Options) Error!usize {
    return check(c.vImageExtractChannel_ARGB16U(src, dest, @intCast(channel_index), flags.bits()));
}

/// Extract a single channel from a 4-channel float buffer to a PlanarF buffer.
pub fn extractChannelARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, channel_index: usize, flags: Options) Error!usize {
    return check(c.vImageExtractChannel_ARGBFFFF(src, dest, @intCast(channel_index), flags.bits()));
}

// ============================================================================
// Overwrite channels
// ============================================================================

/// Channel mask bits for overwrite/select operations.
/// Bit 3 = alpha (0x8), bit 2 = red (0x4), bit 1 = green (0x2), bit 0 = blue (0x1).
pub const ChannelMask = struct {
    pub const alpha: u8 = 0x8;
    pub const red: u8 = 0x4;
    pub const green: u8 = 0x2;
    pub const blue: u8 = 0x1;
    pub const all: u8 = 0xF;
};

/// Overwrite selected channels of an ARGB8888 image with data from a planar buffer.
pub fn overwriteChannelsARGB8888(new_src: *const vImage_Buffer, orig_src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: Options) Error!usize {
    return check(c.vImageOverwriteChannels_ARGB8888(new_src, orig_src, dest, copy_mask, flags.bits()));
}

/// Overwrite selected channels of an ARGBFFFF image with data from a planar buffer.
pub fn overwriteChannelsARGBFFFF(new_src: *const vImage_Buffer, orig_src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: Options) Error!usize {
    return check(c.vImageOverwriteChannels_ARGBFFFF(new_src, orig_src, dest, copy_mask, flags.bits()));
}

/// Fill a Planar8 buffer with a scalar value.
pub fn overwriteScalarPlanar8(scalar: Pixel_8, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageOverwriteChannelsWithScalar_Planar8(scalar, dest, flags.bits()));
}

/// Fill a PlanarF buffer with a scalar value.
pub fn overwriteScalarPlanarF(scalar: Pixel_F, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageOverwriteChannelsWithScalar_PlanarF(scalar, dest, flags.bits()));
}

/// Overwrite selected channels of an ARGB8888 image with a scalar value.
pub fn overwriteScalarARGB8888(scalar: Pixel_8, src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: Options) Error!usize {
    return check(c.vImageOverwriteChannelsWithScalar_ARGB8888(scalar, src, dest, copy_mask, flags.bits()));
}

/// Overwrite selected channels of an ARGBFFFF image with a scalar value.
pub fn overwriteScalarARGBFFFF(scalar: Pixel_F, src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: Options) Error!usize {
    return check(c.vImageOverwriteChannelsWithScalar_ARGBFFFF(scalar, src, dest, copy_mask, flags.bits()));
}

/// Overwrite selected channels of an ARGB8888 image with a pixel value.
pub fn overwritePixelARGB8888(pixel: Pixel_8888, src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: Options) Error!usize {
    return check(c.vImageOverwriteChannelsWithPixel_ARGB8888(&pixel, src, dest, copy_mask, flags.bits()));
}

/// Overwrite selected channels of an ARGBFFFF image with a pixel value.
pub fn overwritePixelARGBFFFF(pixel: Pixel_FFFF, src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: Options) Error!usize {
    return check(c.vImageOverwriteChannelsWithPixel_ARGBFFFF(&pixel, src, dest, copy_mask, flags.bits()));
}

// ============================================================================
// Select channels (interleaved source)
// ============================================================================

/// Select channels from newSrc (ARGB8888 interleaved) to overwrite channels in origSrc.
pub fn selectChannelsARGB8888(new_src: *const vImage_Buffer, orig_src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: Options) Error!usize {
    return check(c.vImageSelectChannels_ARGB8888(new_src, orig_src, dest, copy_mask, flags.bits()));
}

/// Select channels from newSrc (ARGBFFFF interleaved) to overwrite channels in origSrc.
pub fn selectChannelsARGBFFFF(new_src: *const vImage_Buffer, orig_src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: Options) Error!usize {
    return check(c.vImageSelectChannels_ARGBFFFF(new_src, orig_src, dest, copy_mask, flags.bits()));
}

// ============================================================================
// Buffer fill
// ============================================================================

/// Fill an ARGB8888 buffer with a constant color.
pub fn fillARGB8888(dest: *const vImage_Buffer, color: Pixel_8888, flags: Options) Error!usize {
    return check(c.vImageBufferFill_ARGB8888(dest, &color, flags.bits()));
}

/// Fill an ARGBFFFF buffer with a constant color.
pub fn fillARGBFFFF(dest: *const vImage_Buffer, color: Pixel_FFFF, flags: Options) Error!usize {
    return check(c.vImageBufferFill_ARGBFFFF(dest, &color, flags.bits()));
}

// ============================================================================
// Table lookup
// ============================================================================

/// Apply per-channel lookup tables to an ARGB8888 image.
///
/// Pass null for any channel's table to leave that channel unchanged.
pub fn tableLookUpARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    alpha_table: ?*const [256]Pixel_8,
    red_table: ?*const [256]Pixel_8,
    green_table: ?*const [256]Pixel_8,
    blue_table: ?*const [256]Pixel_8,
    flags: Options,
) Error!usize {
    return check(c.vImageTableLookUp_ARGB8888(
        src,
        dest,
        if (alpha_table) |t| @as([*]const Pixel_8, t) else null,
        if (red_table) |t| @as([*]const Pixel_8, t) else null,
        if (green_table) |t| @as([*]const Pixel_8, t) else null,
        if (blue_table) |t| @as([*]const Pixel_8, t) else null,
        flags.bits(),
    ));
}

/// Apply a lookup table to a Planar8 image.
pub fn tableLookUpPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]Pixel_8, flags: Options) Error!usize {
    return check(c.vImageTableLookUp_Planar8(src, dest, @as([*]const Pixel_8, table), flags.bits()));
}

// ============================================================================
// Copy buffer
// ============================================================================

/// Copy a vImage buffer from src to dest.
///
/// pixel_size is the number of bytes per pixel (e.g., 1 for Planar8, 4 for ARGB8888 or PlanarF, 16 for ARGBFFFF).
pub fn copyBuffer(src: *const vImage_Buffer, dest: *const vImage_Buffer, pixel_size: usize, flags: Options) Error!usize {
    return check(c.vImageCopyBuffer(src, dest, pixel_size, flags.bits()));
}

// ============================================================================
// Tests
// ============================================================================
//
// All buffers below are deliberately non-square (2 rows x 3 cols) with
// `rowBytes` padded past `width * bytesPerPixel` (pad_pixels=1) to catch any
// wrapper code that assumes rowBytes == width * bytesPerPixel instead of
// respecting the struct field. Every wrapper call is `try`d, so a nonzero
// vImage error code fails the test instead of being silently ignored.

fn PixelBuf(comptime T: type, comptime height: usize, comptime width: usize, comptime channels: usize, comptime pad_pixels: usize) type {
    const stride = (width + pad_pixels) * channels;
    return struct {
        data: [height * stride]T = [_]T{0} ** (height * stride),

        const Self = @This();

        pub fn buffer(self: *Self) vImage_Buffer {
            return .{
                .data = @ptrCast(&self.data),
                .height = height,
                .width = width,
                .rowBytes = stride * @sizeOf(T),
            };
        }

        pub fn set(self: *Self, row: usize, col: usize, ch: usize, v: T) void {
            self.data[row * stride + col * channels + ch] = v;
        }

        pub fn get(self: *Self, row: usize, col: usize, ch: usize) T {
            return self.data[row * stride + col * channels + ch];
        }
    };
}

// ---- half-precision (Pixel_16F) bit patterns for exactly-representable values ----
const half_0_0: Pixel_F16 = 0x0000;
const half_1_0: Pixel_F16 = 0x3C00;
const half_neg1_0: Pixel_F16 = 0xBC00;
const half_0_5: Pixel_F16 = 0x3800;
const Pixel_F16 = types.Pixel_16F;
const Options = types.Options;

test "clipPlanarF" {
    var src = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var dst = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    const vals = [_][3]Pixel_F{ .{ -5.0, 3.0, 15.0 }, .{ 0.0, 10.0, -1.0 } };
    for (vals, 0..) |row, r| for (row, 0..) |v, col| src.set(r, col, 0, v);

    var s = src.buffer();
    var d = dst.buffer();
    const err = clipPlanarF(&s, &d, 10.0, 0.0, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);

    const expected = [_][3]Pixel_F{ .{ 0.0, 3.0, 10.0 }, .{ 0.0, 10.0, 0.0 } };
    for (expected, 0..) |row, r| for (row, 0..) |v, col| {
        try std.testing.expectEqual(v, dst.get(r, col, 0));
    };
}

test "planar8ToPlanarF and planarFToPlanar8 round-trip formulas" {
    // result = (maxFloat - minFloat) * pixel / 255.0 + minFloat, maxFloat=10, minFloat=-10.
    var src8 = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var dstF = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    src8.set(0, 0, 0, 0);
    src8.set(0, 1, 0, 255);
    src8.set(1, 2, 0, 128);

    var s8 = src8.buffer();
    var dF = dstF.buffer();
    _ = try planar8ToPlanarF(&s8, &dF, 10.0, -10.0, .{});
    try std.testing.expectApproxEqAbs(@as(Pixel_F, -10.0), dstF.get(0, 0, 0), 1e-4);
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 10.0), dstF.get(0, 1, 0), 1e-4);
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 20.0 * 128.0 / 255.0 - 10.0), dstF.get(1, 2, 0), 1e-4);

    // result = SATURATED_CLIP_0_to_255(255*(pixel-minFloat)/(maxFloat-minFloat) + 0.5), maxFloat=10, minFloat=-10.
    var srcF = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var dst8 = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    srcF.set(0, 0, 0, -20.0); // below range -> clip 0
    srcF.set(0, 1, 0, 0.0); // mid -> 128
    srcF.set(1, 2, 0, 20.0); // above range -> clip 255

    var sF = srcF.buffer();
    var d8 = dst8.buffer();
    _ = try planarFToPlanar8(&sF, &d8, 10.0, -10.0, .{});
    try std.testing.expectEqual(@as(Pixel_8, 0), dst8.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 128), dst8.get(0, 1, 0));
    try std.testing.expectEqual(@as(Pixel_8, 255), dst8.get(1, 2, 0));
}

test "planar16FToPlanarF and planarFToPlanar16F round-trip exactly-representable values" {
    var src16 = PixelBuf(Pixel_F16, 2, 3, 1, 1){};
    var dstF = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    src16.set(0, 0, 0, half_0_0);
    src16.set(0, 1, 0, half_1_0);
    src16.set(1, 2, 0, half_neg1_0);

    var s16 = src16.buffer();
    var dF = dstF.buffer();
    _ = try planar16FToPlanarF(&s16, &dF, .{});
    try std.testing.expectEqual(@as(Pixel_F, 0.0), dstF.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_F, 1.0), dstF.get(0, 1, 0));
    try std.testing.expectEqual(@as(Pixel_F, -1.0), dstF.get(1, 2, 0));

    var srcF = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var dst16 = PixelBuf(Pixel_F16, 2, 3, 1, 1){};
    srcF.set(0, 0, 0, 0.0);
    srcF.set(0, 1, 0, 1.0);
    srcF.set(1, 2, 0, 0.5);

    var sF = srcF.buffer();
    var d16 = dst16.buffer();
    _ = try planarFToPlanar16F(&sF, &d16, .{});
    try std.testing.expectEqual(half_0_0, dst16.get(0, 0, 0));
    try std.testing.expectEqual(half_1_0, dst16.get(0, 1, 0));
    try std.testing.expectEqual(half_0_5, dst16.get(1, 2, 0));
}

test "planar8ToPlanar16F and planar16FToPlanar8 endpoint formulas" {
    var src8 = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var dst16 = PixelBuf(Pixel_F16, 2, 3, 1, 1){};
    src8.set(0, 0, 0, 0);
    src8.set(0, 1, 0, 255);

    var s8 = src8.buffer();
    var d16 = dst16.buffer();
    _ = try planar8ToPlanar16F(&s8, &d16, .{});
    try std.testing.expectEqual(half_0_0, dst16.get(0, 0, 0));
    try std.testing.expectEqual(half_1_0, dst16.get(0, 1, 0));

    // destPixel = ROUND_TO_INTEGER(SATURATED_CLAMP_0_to_255(255 * srcPixel)), ties-to-even.
    var src16 = PixelBuf(Pixel_F16, 2, 3, 1, 1){};
    var dst8 = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    src16.set(0, 0, 0, half_0_0);
    src16.set(0, 1, 0, half_1_0);
    src16.set(1, 2, 0, half_0_5); // 255*0.5 = 127.5 -> ties-to-even -> 128

    var s16 = src16.buffer();
    var d8 = dst8.buffer();
    _ = try planar16FToPlanar8(&s16, &d8, .{});
    try std.testing.expectEqual(@as(Pixel_8, 0), dst8.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 255), dst8.get(0, 1, 0));
    try std.testing.expectEqual(@as(Pixel_8, 128), dst8.get(1, 2, 0));
}

test "convert16SToF and convertFTo16S: result = scale * pixel + offset" {
    var src = PixelBuf(i16, 2, 3, 1, 1){};
    var dst = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    src.set(0, 0, 0, 100);
    src.set(0, 1, 0, -200);

    var s = src.buffer();
    var d = dst.buffer();
    // offset=1.0, scale=0.1 (asymmetric, non-trivial constants)
    _ = try convert16SToF(&s, &d, 1.0, 0.1, .{});
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 11.0), dst.get(0, 0, 0), 1e-4);
    try std.testing.expectApproxEqAbs(@as(Pixel_F, -19.0), dst.get(0, 1, 0), 1e-4);

    // Round trip with same offset/scale (per header's documented lossless round trip).
    var srcF = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var dstS = PixelBuf(i16, 2, 3, 1, 1){};
    srcF.set(0, 0, 0, 11.0);
    srcF.set(0, 1, 0, -19.0);
    var sF = srcF.buffer();
    var dS = dstS.buffer();
    _ = try convertFTo16S(&sF, &dS, 1.0, 0.1, .{});
    try std.testing.expectEqual(@as(i16, 100), dstS.get(0, 0, 0));
    try std.testing.expectEqual(@as(i16, -200), dstS.get(0, 1, 0));
}

test "convert16UToF and convertFTo16U: result = scale * pixel + offset" {
    var src = PixelBuf(u16, 2, 3, 1, 1){};
    var dst = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    src.set(0, 0, 0, 100);
    src.set(0, 1, 0, 6000);

    var s = src.buffer();
    var d = dst.buffer();
    _ = try convert16UToF(&s, &d, 2.0, 0.01, .{});
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 3.0), dst.get(0, 0, 0), 1e-4);
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 62.0), dst.get(0, 1, 0), 1e-4);

    var srcF = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var dstU = PixelBuf(u16, 2, 3, 1, 1){};
    srcF.set(0, 0, 0, 3.0);
    srcF.set(0, 1, 0, 62.0);
    var sF = srcF.buffer();
    var dU = dstU.buffer();
    _ = try convertFTo16U(&sF, &dU, 2.0, 0.01, .{});
    try std.testing.expectEqual(@as(u16, 100), dstU.get(0, 0, 0));
    try std.testing.expectEqual(@as(u16, 6000), dstU.get(0, 1, 0));
}

test "convert16UToPlanar8: result = (pixel * 255 + 32767) / 65535" {
    var src = PixelBuf(u16, 2, 3, 1, 1){};
    var dst = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    src.set(0, 0, 0, 0);
    src.set(0, 1, 0, 65535);
    src.set(1, 2, 0, 32768);

    var s = src.buffer();
    var d = dst.buffer();
    _ = try convert16UToPlanar8(&s, &d, .{});
    try std.testing.expectEqual(@as(Pixel_8, 0), dst.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 255), dst.get(0, 1, 0));
    try std.testing.expectEqual(@as(Pixel_8, 128), dst.get(1, 2, 0));
}

test "planar8To16U: result = (pixel * 65535 + 127) / 255" {
    var src = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var dst = PixelBuf(u16, 2, 3, 1, 1){};
    src.set(0, 0, 0, 0);
    src.set(0, 1, 0, 255);
    src.set(1, 2, 0, 128);

    var s = src.buffer();
    var d = dst.buffer();
    _ = try planar8To16U(&s, &d, .{});
    try std.testing.expectEqual(@as(u16, 0), dst.get(0, 0, 0));
    try std.testing.expectEqual(@as(u16, 65535), dst.get(0, 1, 0));
    try std.testing.expectEqual(@as(u16, 32896), dst.get(1, 2, 0));
}

test "planar8ToARGB8888 and argb8888ToPlanar8: A,R,G,B planar order round-trip" {
    var a = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var r = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var g = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var b = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    // Every channel gets a distinct, asymmetric value per pixel so any channel
    // swap is detectable.
    a.set(0, 0, 0, 10);
    r.set(0, 0, 0, 20);
    g.set(0, 0, 0, 30);
    b.set(0, 0, 0, 40);
    a.set(1, 2, 0, 11);
    r.set(1, 2, 0, 22);
    g.set(1, 2, 0, 33);
    b.set(1, 2, 0, 44);

    var dest = PixelBuf(Pixel_8, 2, 3, 4, 1){};
    var ba = a.buffer();
    var br = r.buffer();
    var bg = g.buffer();
    var bb = b.buffer();
    var bd = dest.buffer();
    _ = try planar8ToARGB8888(&ba, &br, &bg, &bb, &bd, .{});
    try std.testing.expectEqual(@as(Pixel_8, 10), dest.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 20), dest.get(0, 0, 1));
    try std.testing.expectEqual(@as(Pixel_8, 30), dest.get(0, 0, 2));
    try std.testing.expectEqual(@as(Pixel_8, 40), dest.get(0, 0, 3));
    try std.testing.expectEqual(@as(Pixel_8, 11), dest.get(1, 2, 0));
    try std.testing.expectEqual(@as(Pixel_8, 22), dest.get(1, 2, 1));
    try std.testing.expectEqual(@as(Pixel_8, 33), dest.get(1, 2, 2));
    try std.testing.expectEqual(@as(Pixel_8, 44), dest.get(1, 2, 3));

    var da = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var dr = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var dg = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var db = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var bda = da.buffer();
    var bdr = dr.buffer();
    var bdg = dg.buffer();
    var bdb = db.buffer();
    _ = try argb8888ToPlanar8(&bd, &bda, &bdr, &bdg, &bdb, .{});
    try std.testing.expectEqual(@as(Pixel_8, 10), da.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 20), dr.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 30), dg.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 40), db.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 11), da.get(1, 2, 0));
    try std.testing.expectEqual(@as(Pixel_8, 22), dr.get(1, 2, 0));
    try std.testing.expectEqual(@as(Pixel_8, 33), dg.get(1, 2, 0));
    try std.testing.expectEqual(@as(Pixel_8, 44), db.get(1, 2, 0));
}

test "planarFToARGBFFFF and argbFFFFToPlanarF: A,R,G,B planar order round-trip" {
    var a = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var r = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var g = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var b = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    a.set(0, 0, 0, 1.0);
    r.set(0, 0, 0, 2.0);
    g.set(0, 0, 0, 3.0);
    b.set(0, 0, 0, 4.0);

    var dest = PixelBuf(Pixel_F, 2, 3, 4, 1){};
    var ba = a.buffer();
    var br = r.buffer();
    var bg = g.buffer();
    var bb = b.buffer();
    var bd = dest.buffer();
    _ = try planarFToARGBFFFF(&ba, &br, &bg, &bb, &bd, .{});
    try std.testing.expectEqual(@as(Pixel_F, 1.0), dest.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_F, 2.0), dest.get(0, 0, 1));
    try std.testing.expectEqual(@as(Pixel_F, 3.0), dest.get(0, 0, 2));
    try std.testing.expectEqual(@as(Pixel_F, 4.0), dest.get(0, 0, 3));

    var da = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var dr = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var dg = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var db = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var bda = da.buffer();
    var bdr = dr.buffer();
    var bdg = dg.buffer();
    var bdb = db.buffer();
    _ = try argbFFFFToPlanarF(&bd, &bda, &bdr, &bdg, &bdb, .{});
    try std.testing.expectEqual(@as(Pixel_F, 1.0), da.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_F, 2.0), dr.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_F, 3.0), dg.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_F, 4.0), db.get(0, 0, 0));
}

test "planar8ToARGBFFFF: A,R,G,B order with per-channel min/max scaling" {
    var a = PixelBuf(Pixel_8, 1, 1, 1, 0){};
    var r = PixelBuf(Pixel_8, 1, 1, 1, 0){};
    var g = PixelBuf(Pixel_8, 1, 1, 1, 0){};
    var b = PixelBuf(Pixel_8, 1, 1, 1, 0){};
    a.set(0, 0, 0, 255);
    r.set(0, 0, 0, 0);
    g.set(0, 0, 0, 255);
    b.set(0, 0, 0, 0);

    var dest = PixelBuf(Pixel_F, 1, 1, 4, 0){};
    var ba = a.buffer();
    var br = r.buffer();
    var bg = g.buffer();
    var bb = b.buffer();
    var bd = dest.buffer();
    // Distinct per-channel [min,max] so a channel-index mixup in the range
    // arrays would be caught.
    const max_f: Pixel_FFFF = .{ 1.0, 2.0, 3.0, 4.0 };
    const min_f: Pixel_FFFF = .{ 0.0, 0.0, 0.0, 0.0 };
    _ = try planar8ToARGBFFFF(&ba, &br, &bg, &bb, &bd, max_f, min_f, .{});
    // alpha = maxFloat[0]*255/255 = 1.0; green = maxFloat[2]*255/255 = 3.0
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 1.0), dest.get(0, 0, 0), 1e-4);
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 0.0), dest.get(0, 0, 1), 1e-4);
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 3.0), dest.get(0, 0, 2), 1e-4);
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 0.0), dest.get(0, 0, 3), 1e-4);
}

test "argb8888ToPlanarF and argbFFFFToPlanar8: per-channel min/max scaling" {
    var src = PixelBuf(Pixel_8, 1, 1, 4, 0){};
    src.set(0, 0, 0, 255); // A
    src.set(0, 0, 1, 0); // R
    src.set(0, 0, 2, 255); // G
    src.set(0, 0, 3, 0); // B
    var a = PixelBuf(Pixel_F, 1, 1, 1, 0){};
    var r = PixelBuf(Pixel_F, 1, 1, 1, 0){};
    var g = PixelBuf(Pixel_F, 1, 1, 1, 0){};
    var b = PixelBuf(Pixel_F, 1, 1, 1, 0){};
    var bs = src.buffer();
    var ba = a.buffer();
    var br = r.buffer();
    var bg = g.buffer();
    var bb = b.buffer();
    const max_f: Pixel_FFFF = .{ 1.0, 2.0, 3.0, 4.0 };
    const min_f: Pixel_FFFF = .{ 0.0, 0.0, 0.0, 0.0 };
    _ = try argb8888ToPlanarF(&bs, &ba, &br, &bg, &bb, max_f, min_f, .{});
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 1.0), a.get(0, 0, 0), 1e-4);
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 0.0), r.get(0, 0, 0), 1e-4);
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 3.0), g.get(0, 0, 0), 1e-4);
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 0.0), b.get(0, 0, 0), 1e-4);

    var srcF = PixelBuf(Pixel_F, 1, 1, 4, 0){};
    srcF.set(0, 0, 0, 1.0);
    srcF.set(0, 0, 1, 0.0);
    srcF.set(0, 0, 2, 3.0);
    srcF.set(0, 0, 3, 0.0);
    var da = PixelBuf(Pixel_8, 1, 1, 1, 0){};
    var dr = PixelBuf(Pixel_8, 1, 1, 1, 0){};
    var dg = PixelBuf(Pixel_8, 1, 1, 1, 0){};
    var db = PixelBuf(Pixel_8, 1, 1, 1, 0){};
    var bsF = srcF.buffer();
    var bda = da.buffer();
    var bdr = dr.buffer();
    var bdg = dg.buffer();
    var bdb = db.buffer();
    _ = try argbFFFFToPlanar8(&bsF, &bda, &bdr, &bdg, &bdb, max_f, min_f, .{});
    try std.testing.expectEqual(@as(Pixel_8, 255), da.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 0), dr.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 255), dg.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 0), db.get(0, 0, 0));
}

test "planarFToARGB8888: A,R,G,B order with per-channel min/max scaling" {
    var a = PixelBuf(Pixel_F, 1, 1, 1, 0){};
    var r = PixelBuf(Pixel_F, 1, 1, 1, 0){};
    var g = PixelBuf(Pixel_F, 1, 1, 1, 0){};
    var b = PixelBuf(Pixel_F, 1, 1, 1, 0){};
    a.set(0, 0, 0, 1.0);
    r.set(0, 0, 0, 0.0);
    g.set(0, 0, 0, 3.0);
    b.set(0, 0, 0, 0.0);

    var dest = PixelBuf(Pixel_8, 1, 1, 4, 0){};
    var ba = a.buffer();
    var br = r.buffer();
    var bg = g.buffer();
    var bb = b.buffer();
    var bd = dest.buffer();
    const max_f: Pixel_FFFF = .{ 1.0, 2.0, 3.0, 4.0 };
    const min_f: Pixel_FFFF = .{ 0.0, 0.0, 0.0, 0.0 };
    _ = try planarFToARGB8888(&ba, &br, &bg, &bb, &bd, max_f, min_f, .{});
    try std.testing.expectEqual(@as(Pixel_8, 255), dest.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 0), dest.get(0, 0, 1));
    try std.testing.expectEqual(@as(Pixel_8, 255), dest.get(0, 0, 2));
    try std.testing.expectEqual(@as(Pixel_8, 0), dest.get(0, 0, 3));
}

test "planar8ToRGB888 and rgb888ToPlanar8: R,G,B planar order round-trip" {
    var r = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var g = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var b = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    r.set(0, 0, 0, 20);
    g.set(0, 0, 0, 30);
    b.set(0, 0, 0, 40);

    var dest = PixelBuf(Pixel_8, 2, 3, 3, 1){};
    var br = r.buffer();
    var bg = g.buffer();
    var bb = b.buffer();
    var bd = dest.buffer();
    _ = try planar8ToRGB888(&br, &bg, &bb, &bd, .{});
    try std.testing.expectEqual(@as(Pixel_8, 20), dest.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 30), dest.get(0, 0, 1));
    try std.testing.expectEqual(@as(Pixel_8, 40), dest.get(0, 0, 2));

    var dr = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var dg = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var db = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var bdr = dr.buffer();
    var bdg = dg.buffer();
    var bdb = db.buffer();
    _ = try rgb888ToPlanar8(&bd, &bdr, &bdg, &bdb, .{});
    try std.testing.expectEqual(@as(Pixel_8, 20), dr.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 30), dg.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 40), db.get(0, 0, 0));
}

test "planarFToRGBFFF and rgbFFFToPlanarF: R,G,B planar order round-trip" {
    var r = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var g = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var b = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    r.set(0, 0, 0, 2.0);
    g.set(0, 0, 0, 3.0);
    b.set(0, 0, 0, 4.0);

    var dest = PixelBuf(Pixel_F, 2, 3, 3, 1){};
    var br = r.buffer();
    var bg = g.buffer();
    var bb = b.buffer();
    var bd = dest.buffer();
    _ = try planarFToRGBFFF(&br, &bg, &bb, &bd, .{});
    try std.testing.expectEqual(@as(Pixel_F, 2.0), dest.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_F, 3.0), dest.get(0, 0, 1));
    try std.testing.expectEqual(@as(Pixel_F, 4.0), dest.get(0, 0, 2));

    var dr = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var dg = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var db = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var bdr = dr.buffer();
    var bdg = dg.buffer();
    var bdb = db.buffer();
    _ = try rgbFFFToPlanarF(&bd, &bdr, &bdg, &bdb, .{});
    try std.testing.expectEqual(@as(Pixel_F, 2.0), dr.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_F, 3.0), dg.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_F, 4.0), db.get(0, 0, 0));
}

test "rgb888ToInterleaved8888 and interleaved8888ToRGB888: channel order per variant" {
    var rgb = PixelBuf(Pixel_8, 1, 1, 3, 0){};
    rgb.set(0, 0, 0, 20); // R
    rgb.set(0, 0, 1, 30); // G
    rgb.set(0, 0, 2, 40); // B
    var brgb = rgb.buffer();

    // ARGB: dest = {alpha, R, G, B}
    {
        var dest = PixelBuf(Pixel_8, 1, 1, 4, 0){};
        var bd = dest.buffer();
        _ = try rgb888ToInterleaved8888(&brgb, null, 99, &bd, .argb, false, .{});
        try std.testing.expectEqual(@as(Pixel_8, 99), dest.get(0, 0, 0));
        try std.testing.expectEqual(@as(Pixel_8, 20), dest.get(0, 0, 1));
        try std.testing.expectEqual(@as(Pixel_8, 30), dest.get(0, 0, 2));
        try std.testing.expectEqual(@as(Pixel_8, 40), dest.get(0, 0, 3));

        var rgbBack = PixelBuf(Pixel_8, 1, 1, 3, 0){};
        var bb = rgbBack.buffer();
        _ = try interleaved8888ToRGB888(&bd, &bb, .argb, .{});
        try std.testing.expectEqual(@as(Pixel_8, 20), rgbBack.get(0, 0, 0));
        try std.testing.expectEqual(@as(Pixel_8, 30), rgbBack.get(0, 0, 1));
        try std.testing.expectEqual(@as(Pixel_8, 40), rgbBack.get(0, 0, 2));
    }

    // RGBA: dest = {R, G, B, alpha}
    {
        var dest = PixelBuf(Pixel_8, 1, 1, 4, 0){};
        var bd = dest.buffer();
        _ = try rgb888ToInterleaved8888(&brgb, null, 99, &bd, .rgba, false, .{});
        try std.testing.expectEqual(@as(Pixel_8, 20), dest.get(0, 0, 0));
        try std.testing.expectEqual(@as(Pixel_8, 30), dest.get(0, 0, 1));
        try std.testing.expectEqual(@as(Pixel_8, 40), dest.get(0, 0, 2));
        try std.testing.expectEqual(@as(Pixel_8, 99), dest.get(0, 0, 3));

        var rgbBack = PixelBuf(Pixel_8, 1, 1, 3, 0){};
        var bb = rgbBack.buffer();
        _ = try interleaved8888ToRGB888(&bd, &bb, .rgba, .{});
        try std.testing.expectEqual(@as(Pixel_8, 20), rgbBack.get(0, 0, 0));
        try std.testing.expectEqual(@as(Pixel_8, 30), rgbBack.get(0, 0, 1));
        try std.testing.expectEqual(@as(Pixel_8, 40), rgbBack.get(0, 0, 2));
    }

    // BGRA: dest = {B, G, R, alpha}
    {
        var dest = PixelBuf(Pixel_8, 1, 1, 4, 0){};
        var bd = dest.buffer();
        _ = try rgb888ToInterleaved8888(&brgb, null, 99, &bd, .bgra, false, .{});
        try std.testing.expectEqual(@as(Pixel_8, 40), dest.get(0, 0, 0));
        try std.testing.expectEqual(@as(Pixel_8, 30), dest.get(0, 0, 1));
        try std.testing.expectEqual(@as(Pixel_8, 20), dest.get(0, 0, 2));
        try std.testing.expectEqual(@as(Pixel_8, 99), dest.get(0, 0, 3));

        var rgbBack = PixelBuf(Pixel_8, 1, 1, 3, 0){};
        var bb = rgbBack.buffer();
        _ = try interleaved8888ToRGB888(&bd, &bb, .bgra, .{});
        try std.testing.expectEqual(@as(Pixel_8, 20), rgbBack.get(0, 0, 0));
        try std.testing.expectEqual(@as(Pixel_8, 30), rgbBack.get(0, 0, 1));
        try std.testing.expectEqual(@as(Pixel_8, 40), rgbBack.get(0, 0, 2));
    }
}

test "rgb888ToInterleaved8888 with premultiply: r' = (a*r + 127) / 255" {
    var rgb = PixelBuf(Pixel_8, 1, 1, 3, 0){};
    rgb.set(0, 0, 0, 200); // R
    rgb.set(0, 0, 1, 100); // G
    rgb.set(0, 0, 2, 50); // B
    var brgb = rgb.buffer();

    var dest = PixelBuf(Pixel_8, 1, 1, 4, 0){};
    var bd = dest.buffer();
    _ = try rgb888ToInterleaved8888(&brgb, null, 128, &bd, .argb, true, .{});
    try std.testing.expectEqual(@as(Pixel_8, 128), dest.get(0, 0, 0)); // alpha unchanged
    try std.testing.expectEqual(@as(Pixel_8, (128 * 200 + 127) / 255), dest.get(0, 0, 1));
    try std.testing.expectEqual(@as(Pixel_8, (128 * 100 + 127) / 255), dest.get(0, 0, 2));
    try std.testing.expectEqual(@as(Pixel_8, (128 * 50 + 127) / 255), dest.get(0, 0, 3));
}

test "interleavedFFFFToRGBFFF and rgbFFFToInterleavedFFFF: channel order per variant" {
    var rgb = PixelBuf(Pixel_F, 1, 1, 3, 0){};
    rgb.set(0, 0, 0, 2.0);
    rgb.set(0, 0, 1, 3.0);
    rgb.set(0, 0, 2, 4.0);
    var brgb = rgb.buffer();

    var dest = PixelBuf(Pixel_F, 1, 1, 4, 0){};
    var bd = dest.buffer();
    _ = try rgbFFFToInterleavedFFFF(&brgb, null, 9.0, &bd, .bgra, false, .{});
    try std.testing.expectEqual(@as(Pixel_F, 4.0), dest.get(0, 0, 0)); // B
    try std.testing.expectEqual(@as(Pixel_F, 3.0), dest.get(0, 0, 1)); // G
    try std.testing.expectEqual(@as(Pixel_F, 2.0), dest.get(0, 0, 2)); // R
    try std.testing.expectEqual(@as(Pixel_F, 9.0), dest.get(0, 0, 3)); // alpha

    var rgbBack = PixelBuf(Pixel_F, 1, 1, 3, 0){};
    var bb = rgbBack.buffer();
    _ = try interleavedFFFFToRGBFFF(&bd, &bb, .bgra, .{});
    try std.testing.expectEqual(@as(Pixel_F, 2.0), rgbBack.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_F, 3.0), rgbBack.get(0, 0, 1));
    try std.testing.expectEqual(@as(Pixel_F, 4.0), rgbBack.get(0, 0, 2));
}

test "flatten8888ToRGB888: non-premultiplied color = (color*alpha + (255-alpha)*bg + 127) / 255" {
    var src = PixelBuf(Pixel_8, 1, 1, 4, 0){};
    src.set(0, 0, 0, 128); // alpha
    src.set(0, 0, 1, 200); // R
    src.set(0, 0, 2, 100); // G
    src.set(0, 0, 3, 50); // B
    var bs = src.buffer();

    var dest = PixelBuf(Pixel_8, 1, 1, 3, 0){};
    var bd = dest.buffer();
    const bg: Pixel_8888 = .{ 255, 10, 20, 30 };
    _ = try flatten8888ToRGB888(&bs, &bd, bg, .argb, false, .{});
    const alpha: u32 = 128;
    const inv: u32 = 255 - alpha;
    try std.testing.expectEqual(@as(Pixel_8, @intCast((alpha * 200 + inv * 10 + 127) / 255)), dest.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, @intCast((alpha * 100 + inv * 20 + 127) / 255)), dest.get(0, 0, 1));
    try std.testing.expectEqual(@as(Pixel_8, @intCast((alpha * 50 + inv * 30 + 127) / 255)), dest.get(0, 0, 2));
}

test "flattenFFFFToRGBFFF: non-premultiplied color = color*alpha + (1-alpha)*bg" {
    var src = PixelBuf(Pixel_F, 1, 1, 4, 0){};
    src.set(0, 0, 0, 0.5); // alpha
    src.set(0, 0, 1, 1.0); // R
    src.set(0, 0, 2, 0.4); // G
    src.set(0, 0, 3, 0.2); // B
    var bs = src.buffer();

    var dest = PixelBuf(Pixel_F, 1, 1, 3, 0){};
    var bd = dest.buffer();
    const bg: Pixel_FFFF = .{ 1.0, 0.0, 0.8, 0.6 };
    _ = try flattenFFFFToRGBFFF(&bs, &bd, bg, .argb, false, .{});
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 0.5 * 1.0 + 0.5 * 0.0), dest.get(0, 0, 0), 1e-4);
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 0.5 * 0.4 + 0.5 * 0.8), dest.get(0, 0, 1), 1e-4);
    try std.testing.expectApproxEqAbs(@as(Pixel_F, 0.5 * 0.2 + 0.5 * 0.6), dest.get(0, 0, 2), 1e-4);
}

test "permuteChannelsARGB8888: dest[i] = src[permuteMap[i]]" {
    var src = PixelBuf(Pixel_8, 1, 1, 4, 0){};
    src.set(0, 0, 0, 10); // A
    src.set(0, 0, 1, 20); // R
    src.set(0, 0, 2, 30); // G
    src.set(0, 0, 3, 40); // B
    var bs = src.buffer();

    var dest = PixelBuf(Pixel_8, 1, 1, 4, 0){};
    var bd = dest.buffer();
    // {3,2,1,0}: ARGB -> BGRA per header's own example.
    _ = try permuteChannelsARGB8888(&bs, &bd, .{ 3, 2, 1, 0 }, .{});
    try std.testing.expectEqual(@as(Pixel_8, 40), dest.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 30), dest.get(0, 0, 1));
    try std.testing.expectEqual(@as(Pixel_8, 20), dest.get(0, 0, 2));
    try std.testing.expectEqual(@as(Pixel_8, 10), dest.get(0, 0, 3));
}

test "permuteChannelsARGB16U: dest[i] = src[permuteMap[i]]" {
    var src = PixelBuf(u16, 1, 1, 4, 0){};
    src.set(0, 0, 0, 100);
    src.set(0, 0, 1, 200);
    src.set(0, 0, 2, 300);
    src.set(0, 0, 3, 400);
    var bs = src.buffer();

    var dest = PixelBuf(u16, 1, 1, 4, 0){};
    var bd = dest.buffer();
    _ = try permuteChannelsARGB16U(&bs, &bd, .{ 1, 0, 3, 2 }, .{});
    try std.testing.expectEqual(@as(u16, 200), dest.get(0, 0, 0));
    try std.testing.expectEqual(@as(u16, 100), dest.get(0, 0, 1));
    try std.testing.expectEqual(@as(u16, 400), dest.get(0, 0, 2));
    try std.testing.expectEqual(@as(u16, 300), dest.get(0, 0, 3));
}

test "permuteChannelsARGBFFFF: dest[i] = src[permuteMap[i]]" {
    var src = PixelBuf(Pixel_F, 1, 1, 4, 0){};
    src.set(0, 0, 0, 1.0);
    src.set(0, 0, 1, 2.0);
    src.set(0, 0, 2, 3.0);
    src.set(0, 0, 3, 4.0);
    var bs = src.buffer();

    var dest = PixelBuf(Pixel_F, 1, 1, 4, 0){};
    var bd = dest.buffer();
    _ = try permuteChannelsARGBFFFF(&bs, &bd, .{ 3, 2, 1, 0 }, .{});
    try std.testing.expectEqual(@as(Pixel_F, 4.0), dest.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_F, 3.0), dest.get(0, 0, 1));
    try std.testing.expectEqual(@as(Pixel_F, 2.0), dest.get(0, 0, 2));
    try std.testing.expectEqual(@as(Pixel_F, 1.0), dest.get(0, 0, 3));
}

test "permuteChannelsRGB888: dest[i] = src[permuteMap[i]]" {
    var src = PixelBuf(Pixel_8, 1, 1, 3, 0){};
    src.set(0, 0, 0, 20);
    src.set(0, 0, 1, 30);
    src.set(0, 0, 2, 40);
    var bs = src.buffer();

    var dest = PixelBuf(Pixel_8, 1, 1, 3, 0){};
    var bd = dest.buffer();
    // {2,1,0}: RGB -> BGR per header's own example.
    _ = try permuteChannelsRGB888(&bs, &bd, .{ 2, 1, 0 }, .{});
    try std.testing.expectEqual(@as(Pixel_8, 40), dest.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 30), dest.get(0, 0, 1));
    try std.testing.expectEqual(@as(Pixel_8, 20), dest.get(0, 0, 2));
}

test "extractChannelARGB8888/ARGB16U/ARGBFFFF: 0-based index, 0 = first (A) channel" {
    var src8 = PixelBuf(Pixel_8, 1, 1, 4, 0){};
    src8.set(0, 0, 0, 10);
    src8.set(0, 0, 1, 20);
    src8.set(0, 0, 2, 30);
    src8.set(0, 0, 3, 40);
    var bs8 = src8.buffer();
    var d8 = PixelBuf(Pixel_8, 1, 1, 1, 0){};
    var bd8 = d8.buffer();
    _ = try extractChannelARGB8888(&bs8, &bd8, 0, .{});
    try std.testing.expectEqual(@as(Pixel_8, 10), d8.get(0, 0, 0));
    _ = try extractChannelARGB8888(&bs8, &bd8, 3, .{});
    try std.testing.expectEqual(@as(Pixel_8, 40), d8.get(0, 0, 0));

    var src16 = PixelBuf(u16, 1, 1, 4, 0){};
    src16.set(0, 0, 0, 100);
    src16.set(0, 0, 2, 300);
    var bs16 = src16.buffer();
    var d16 = PixelBuf(u16, 1, 1, 1, 0){};
    var bd16 = d16.buffer();
    _ = try extractChannelARGB16U(&bs16, &bd16, 2, .{});
    try std.testing.expectEqual(@as(u16, 300), d16.get(0, 0, 0));

    var srcF = PixelBuf(Pixel_F, 1, 1, 4, 0){};
    srcF.set(0, 0, 1, 2.5);
    var bsF = srcF.buffer();
    var dF = PixelBuf(Pixel_F, 1, 1, 1, 0){};
    var bdF = dF.buffer();
    _ = try extractChannelARGBFFFF(&bsF, &bdF, 1, .{});
    try std.testing.expectEqual(@as(Pixel_F, 2.5), dF.get(0, 0, 0));
}

test "overwriteChannelsARGB8888 vs overwriteScalarARGB8888 vs overwritePixelARGB8888: distinct semantics" {
    // orig = {A=1, R=2, G=3, B=4}; mask selects alpha(0x8) | red(0x4) = 0xC.
    const mask: u8 = ChannelMask.alpha | ChannelMask.red;

    // overwriteChannelsARGB8888: a single PLANAR value is broadcast into every
    // masked channel (Conversion.h: srcPixel splatted into all lanes, then
    // masked-combined with origSrc).
    {
        var orig = PixelBuf(Pixel_8, 1, 1, 4, 0){};
        orig.set(0, 0, 0, 1);
        orig.set(0, 0, 1, 2);
        orig.set(0, 0, 2, 3);
        orig.set(0, 0, 3, 4);
        var newSrc = PixelBuf(Pixel_8, 1, 1, 1, 0){};
        newSrc.set(0, 0, 0, 77);
        var dest = PixelBuf(Pixel_8, 1, 1, 4, 0){};
        var bo = orig.buffer();
        var bn = newSrc.buffer();
        var bd = dest.buffer();
        _ = try overwriteChannelsARGB8888(&bn, &bo, &bd, mask, .{});
        try std.testing.expectEqual(@as(Pixel_8, 77), dest.get(0, 0, 0)); // alpha <- newSrc (broadcast)
        try std.testing.expectEqual(@as(Pixel_8, 77), dest.get(0, 0, 1)); // red <- newSrc (broadcast, same value)
        try std.testing.expectEqual(@as(Pixel_8, 3), dest.get(0, 0, 2)); // green unchanged
        try std.testing.expectEqual(@as(Pixel_8, 4), dest.get(0, 0, 3)); // blue unchanged
    }

    // overwriteScalarARGB8888: a single compile-time constant scalar is
    // broadcast into every masked channel.
    {
        var src = PixelBuf(Pixel_8, 1, 1, 4, 0){};
        src.set(0, 0, 0, 1);
        src.set(0, 0, 1, 2);
        src.set(0, 0, 2, 3);
        src.set(0, 0, 3, 4);
        var dest = PixelBuf(Pixel_8, 1, 1, 4, 0){};
        var bs = src.buffer();
        var bd = dest.buffer();
        _ = try overwriteScalarARGB8888(99, &bs, &bd, mask, .{});
        try std.testing.expectEqual(@as(Pixel_8, 99), dest.get(0, 0, 0));
        try std.testing.expectEqual(@as(Pixel_8, 99), dest.get(0, 0, 1));
        try std.testing.expectEqual(@as(Pixel_8, 3), dest.get(0, 0, 2));
        try std.testing.expectEqual(@as(Pixel_8, 4), dest.get(0, 0, 3));
    }

    // overwritePixelARGB8888: each masked channel gets ITS OWN component from
    // the_pixel -- distinct values per channel, not a broadcast.
    {
        var src = PixelBuf(Pixel_8, 1, 1, 4, 0){};
        src.set(0, 0, 0, 1);
        src.set(0, 0, 1, 2);
        src.set(0, 0, 2, 3);
        src.set(0, 0, 3, 4);
        var dest = PixelBuf(Pixel_8, 1, 1, 4, 0){};
        var bs = src.buffer();
        var bd = dest.buffer();
        const pixel: Pixel_8888 = .{ 9, 8, 7, 6 };
        _ = try overwritePixelARGB8888(pixel, &bs, &bd, mask, .{});
        try std.testing.expectEqual(@as(Pixel_8, 9), dest.get(0, 0, 0)); // alpha <- pixel[0]
        try std.testing.expectEqual(@as(Pixel_8, 8), dest.get(0, 0, 1)); // red <- pixel[1] (distinct from alpha!)
        try std.testing.expectEqual(@as(Pixel_8, 3), dest.get(0, 0, 2)); // green unchanged
        try std.testing.expectEqual(@as(Pixel_8, 4), dest.get(0, 0, 3)); // blue unchanged
    }
}

test "overwriteChannelsARGBFFFF and overwritePixelARGBFFFF" {
    const mask: u8 = ChannelMask.green | ChannelMask.blue;
    var orig = PixelBuf(Pixel_F, 1, 1, 4, 0){};
    orig.set(0, 0, 0, 1.0);
    orig.set(0, 0, 1, 2.0);
    orig.set(0, 0, 2, 3.0);
    orig.set(0, 0, 3, 4.0);
    var newSrc = PixelBuf(Pixel_F, 1, 1, 1, 0){};
    newSrc.set(0, 0, 0, 77.0);
    var dest = PixelBuf(Pixel_F, 1, 1, 4, 0){};
    var bo = orig.buffer();
    var bn = newSrc.buffer();
    var bd = dest.buffer();
    _ = try overwriteChannelsARGBFFFF(&bn, &bo, &bd, mask, .{});
    try std.testing.expectEqual(@as(Pixel_F, 1.0), dest.get(0, 0, 0)); // alpha unchanged
    try std.testing.expectEqual(@as(Pixel_F, 2.0), dest.get(0, 0, 1)); // red unchanged
    try std.testing.expectEqual(@as(Pixel_F, 77.0), dest.get(0, 0, 2)); // green <- broadcast
    try std.testing.expectEqual(@as(Pixel_F, 77.0), dest.get(0, 0, 3)); // blue <- broadcast

    var dest2 = PixelBuf(Pixel_F, 1, 1, 4, 0){};
    var bd2 = dest2.buffer();
    const pixel: Pixel_FFFF = .{ 9.0, 8.0, 7.0, 6.0 };
    _ = try overwritePixelARGBFFFF(pixel, &bo, &bd2, mask, .{});
    try std.testing.expectEqual(@as(Pixel_F, 1.0), dest2.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_F, 2.0), dest2.get(0, 0, 1));
    try std.testing.expectEqual(@as(Pixel_F, 7.0), dest2.get(0, 0, 2)); // green <- pixel[2]
    try std.testing.expectEqual(@as(Pixel_F, 6.0), dest2.get(0, 0, 3)); // blue <- pixel[3] (distinct!)
}

test "overwriteScalarPlanar8 and overwriteScalarPlanarF: fill entire buffer" {
    var dst8 = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var bd8 = dst8.buffer();
    _ = try overwriteScalarPlanar8(42, &bd8, .{});
    for (0..2) |r| for (0..3) |cidx| {
        try std.testing.expectEqual(@as(Pixel_8, 42), dst8.get(r, cidx, 0));
    };

    var dstF = PixelBuf(Pixel_F, 2, 3, 1, 1){};
    var bdF = dstF.buffer();
    _ = try overwriteScalarPlanarF(3.5, &bdF, .{});
    for (0..2) |r| for (0..3) |cidx| {
        try std.testing.expectEqual(@as(Pixel_F, 3.5), dstF.get(r, cidx, 0));
    };
}

test "selectChannelsARGB8888: masked channels come from newSrc's OWN channel position (not broadcast)" {
    var newSrc = PixelBuf(Pixel_8, 1, 1, 4, 0){};
    newSrc.set(0, 0, 0, 50);
    newSrc.set(0, 0, 1, 51);
    newSrc.set(0, 0, 2, 52);
    newSrc.set(0, 0, 3, 53);
    var orig = PixelBuf(Pixel_8, 1, 1, 4, 0){};
    orig.set(0, 0, 0, 1);
    orig.set(0, 0, 1, 2);
    orig.set(0, 0, 2, 3);
    orig.set(0, 0, 3, 4);
    var dest = PixelBuf(Pixel_8, 1, 1, 4, 0){};
    var bn = newSrc.buffer();
    var bo = orig.buffer();
    var bd = dest.buffer();
    const mask: u8 = ChannelMask.alpha | ChannelMask.blue;
    _ = try selectChannelsARGB8888(&bn, &bo, &bd, mask, .{});
    try std.testing.expectEqual(@as(Pixel_8, 50), dest.get(0, 0, 0)); // alpha <- newSrc[0]
    try std.testing.expectEqual(@as(Pixel_8, 2), dest.get(0, 0, 1)); // red <- orig[1]
    try std.testing.expectEqual(@as(Pixel_8, 3), dest.get(0, 0, 2)); // green <- orig[2]
    try std.testing.expectEqual(@as(Pixel_8, 53), dest.get(0, 0, 3)); // blue <- newSrc[3] (distinct from alpha!)
}

test "selectChannelsARGBFFFF: masked channels come from newSrc's OWN channel position" {
    var newSrc = PixelBuf(Pixel_F, 1, 1, 4, 0){};
    newSrc.set(0, 0, 0, 50.0);
    newSrc.set(0, 0, 3, 53.0);
    var orig = PixelBuf(Pixel_F, 1, 1, 4, 0){};
    orig.set(0, 0, 0, 1.0);
    orig.set(0, 0, 1, 2.0);
    orig.set(0, 0, 2, 3.0);
    orig.set(0, 0, 3, 4.0);
    var dest = PixelBuf(Pixel_F, 1, 1, 4, 0){};
    var bn = newSrc.buffer();
    var bo = orig.buffer();
    var bd = dest.buffer();
    const mask: u8 = ChannelMask.alpha | ChannelMask.blue;
    _ = try selectChannelsARGBFFFF(&bn, &bo, &bd, mask, .{});
    try std.testing.expectEqual(@as(Pixel_F, 50.0), dest.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_F, 2.0), dest.get(0, 0, 1));
    try std.testing.expectEqual(@as(Pixel_F, 3.0), dest.get(0, 0, 2));
    try std.testing.expectEqual(@as(Pixel_F, 53.0), dest.get(0, 0, 3));
}

test "fillARGB8888 and fillARGBFFFF: every pixel gets the constant color" {
    var dst8 = PixelBuf(Pixel_8, 2, 3, 4, 1){};
    var bd8 = dst8.buffer();
    const color8: Pixel_8888 = .{ 10, 20, 30, 40 };
    _ = try fillARGB8888(&bd8, color8, .{});
    for (0..2) |r| for (0..3) |cidx| {
        try std.testing.expectEqual(@as(Pixel_8, 10), dst8.get(r, cidx, 0));
        try std.testing.expectEqual(@as(Pixel_8, 20), dst8.get(r, cidx, 1));
        try std.testing.expectEqual(@as(Pixel_8, 30), dst8.get(r, cidx, 2));
        try std.testing.expectEqual(@as(Pixel_8, 40), dst8.get(r, cidx, 3));
    };

    var dstF = PixelBuf(Pixel_F, 2, 3, 4, 1){};
    var bdF = dstF.buffer();
    const colorF: Pixel_FFFF = .{ 1.0, 2.0, 3.0, 4.0 };
    _ = try fillARGBFFFF(&bdF, colorF, .{});
    try std.testing.expectEqual(@as(Pixel_F, 1.0), dstF.get(1, 2, 0));
    try std.testing.expectEqual(@as(Pixel_F, 4.0), dstF.get(1, 2, 3));
}

test "tableLookUpARGB8888: table[pixel] is used per channel; null leaves channel unchanged" {
    var alpha_table: [256]Pixel_8 = undefined;
    var blue_table: [256]Pixel_8 = undefined;
    for (0..256) |i| {
        alpha_table[i] = @intCast(255 - i); // invert
        blue_table[i] = @intCast(i); // identity
    }

    var src = PixelBuf(Pixel_8, 1, 1, 4, 0){};
    src.set(0, 0, 0, 10); // A
    src.set(0, 0, 1, 20); // R (no table -> unchanged)
    src.set(0, 0, 2, 30); // G (no table -> unchanged)
    src.set(0, 0, 3, 40); // B
    var bs = src.buffer();
    var dest = PixelBuf(Pixel_8, 1, 1, 4, 0){};
    var bd = dest.buffer();
    _ = try tableLookUpARGB8888(&bs, &bd, &alpha_table, null, null, &blue_table, .{});
    try std.testing.expectEqual(@as(Pixel_8, 255 - 10), dest.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 20), dest.get(0, 0, 1)); // unchanged (null table)
    try std.testing.expectEqual(@as(Pixel_8, 30), dest.get(0, 0, 2)); // unchanged (null table)
    try std.testing.expectEqual(@as(Pixel_8, 40), dest.get(0, 0, 3));
}

test "tableLookUpPlanar8: dest[x] = table[src[x]]" {
    var table: [256]Pixel_8 = undefined;
    for (0..256) |i| table[i] = @intCast(255 - i);

    var src = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    src.set(0, 0, 0, 0);
    src.set(1, 2, 0, 200);
    var bs = src.buffer();
    var dest = PixelBuf(Pixel_8, 2, 3, 1, 1){};
    var bd = dest.buffer();
    _ = try tableLookUpPlanar8(&bs, &bd, &table, .{});
    try std.testing.expectEqual(@as(Pixel_8, 255), dest.get(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 55), dest.get(1, 2, 0));
}

test "copyBuffer: byte-exact copy respecting pixel_size and rowBytes padding" {
    var src = PixelBuf(Pixel_8, 2, 3, 4, 1){};
    for (0..2) |r| for (0..3) |cidx| for (0..4) |ch| {
        src.set(r, cidx, ch, @intCast(r * 10 + cidx * 4 + ch));
    };
    var dest = PixelBuf(Pixel_8, 2, 3, 4, 1){};
    var bs = src.buffer();
    var bd = dest.buffer();
    _ = try copyBuffer(&bs, &bd, 4, .{});
    for (0..2) |r| for (0..3) |cidx| for (0..4) |ch| {
        try std.testing.expectEqual(src.get(r, cidx, ch), dest.get(r, cidx, ch));
    };
}

test {
    // The sub-modules above are `@import`ed decls of this file, and
    // `refAllDecls` in vimage/root.zig only forces decls one level deep — it
    // reaches `conversion` but not `conversion.packed16`. Without this the
    // sub-modules compile but none of their tests run.
    std.testing.refAllDecls(@This());
}
