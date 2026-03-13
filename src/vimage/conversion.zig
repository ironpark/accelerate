const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const vImage_Flags = types.vImage_Flags;
const Pixel_8 = types.Pixel_8;
const Pixel_F = types.Pixel_F;
const Pixel_8888 = types.Pixel_8888;
const Pixel_FFFF = types.Pixel_FFFF;
const Flags = types.Flags;

// ============================================================================
// Clip
// ============================================================================

/// Clip pixel values of a PlanarF image to [min_val, max_val].
///
/// Can also be used for multichannel float formats (e.g. ARGBFFFF) by
/// scaling `vImage_Buffer.width` by the channel count.
pub fn clipPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, max_val: Pixel_F, min_val: Pixel_F, flags: vImage_Flags) vImage_Error {
    return c.vImageClip_PlanarF(src, dest, max_val, min_val, flags);
}

// ============================================================================
// Planar format conversions
// ============================================================================

/// Convert Planar8 to PlanarF.
///
///     result = (maxFloat - minFloat) * pixel / 255.0 + minFloat
pub fn planar8ToPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, max_float: Pixel_F, min_float: Pixel_F, flags: vImage_Flags) vImage_Error {
    return c.vImageConvert_Planar8toPlanarF(src, dest, max_float, min_float, flags);
}

/// Convert PlanarF to Planar8.
///
///     result = CLIP(0, 255, 255.0 * (pixel - minFloat) / (maxFloat - minFloat) + 0.5)
pub fn planarFToPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, max_float: Pixel_F, min_float: Pixel_F, flags: vImage_Flags) vImage_Error {
    return c.vImageConvert_PlanarFtoPlanar8(src, dest, max_float, min_float, flags);
}

/// Convert half-precision float (Planar16F) to single-precision float (PlanarF).
pub fn planar16FToPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImageConvert_Planar16FtoPlanarF(src, dest, flags);
}

/// Convert single-precision float (PlanarF) to half-precision float (Planar16F).
pub fn planarFToPlanar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImageConvert_PlanarFtoPlanar16F(src, dest, flags);
}

/// Convert Planar8 directly to half-precision float (Planar16F).
pub fn planar8ToPlanar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImageConvert_Planar8toPlanar16F(src, dest, flags);
}

/// Convert half-precision float (Planar16F) to Planar8.
pub fn planar16FToPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImageConvert_Planar16FtoPlanar8(src, dest, flags);
}

/// Convert 16-bit signed integer to PlanarF.
///
///     result = scale * pixel + offset
pub fn convert16SToF(src: *const vImage_Buffer, dest: *const vImage_Buffer, offset: f32, scale: f32, flags: vImage_Flags) vImage_Error {
    return c.vImageConvert_16SToF(src, dest, offset, scale, flags);
}

/// Convert 16-bit unsigned integer to PlanarF.
///
///     result = scale * pixel + offset
pub fn convert16UToF(src: *const vImage_Buffer, dest: *const vImage_Buffer, offset: f32, scale: f32, flags: vImage_Flags) vImage_Error {
    return c.vImageConvert_16UToF(src, dest, offset, scale, flags);
}

/// Convert PlanarF to 16-bit signed integer.
///
///     result = (pixel - offset) / scale
pub fn convertFTo16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, offset: f32, scale: f32, flags: vImage_Flags) vImage_Error {
    return c.vImageConvert_FTo16S(src, dest, offset, scale, flags);
}

/// Convert PlanarF to 16-bit unsigned integer.
///
///     result = (pixel - offset) / scale
pub fn convertFTo16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, offset: f32, scale: f32, flags: vImage_Flags) vImage_Error {
    return c.vImageConvert_FTo16U(src, dest, offset, scale, flags);
}

/// Convert 16-bit unsigned integer to Planar8.
///
///     result = (pixel * 255 + 32767) / 65535
pub fn convert16UToPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImageConvert_16UToPlanar8(src, dest, flags);
}

/// Convert Planar8 to 16-bit unsigned integer.
pub fn planar8To16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImageConvert_Planar8To16U(src, dest, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageConvert_Planar8toARGB8888(srcA, srcR, srcG, srcB, dest, flags);
}

/// Combine four PlanarF buffers into a single ARGBFFFF interleaved buffer.
pub fn planarFToARGBFFFF(
    srcA: *const vImage_Buffer,
    srcR: *const vImage_Buffer,
    srcG: *const vImage_Buffer,
    srcB: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageConvert_PlanarFtoARGBFFFF(srcA, srcR, srcG, srcB, dest, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageConvert_ARGB8888toPlanar8(srcARGB, destA, destR, destG, destB, flags);
}

/// Split an ARGBFFFF interleaved buffer into four PlanarF buffers.
pub fn argbFFFFToPlanarF(
    srcARGB: *const vImage_Buffer,
    destA: *const vImage_Buffer,
    destR: *const vImage_Buffer,
    destG: *const vImage_Buffer,
    destB: *const vImage_Buffer,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageConvert_ARGBFFFFtoPlanarF(srcARGB, destA, destR, destG, destB, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageConvert_Planar8ToARGBFFFF(alpha, red, green, blue, dest, &max_float, &min_float, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageConvert_ARGB8888toPlanarF(src, alpha, red, green, blue, &max_float, &min_float, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageConvert_ARGBFFFFtoPlanar8(src, alpha, red, green, blue, &max_float, &min_float, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageConvert_PlanarFToARGB8888(alpha, red, green, blue, dest, &max_float, &min_float, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageConvert_Planar8toRGB888(red, green, blue, dest, flags);
}

/// Combine three PlanarF buffers into an RGBFFF interleaved buffer.
pub fn planarFToRGBFFF(
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageConvert_PlanarFtoRGBFFF(red, green, blue, dest, flags);
}

/// Split an RGB888 interleaved buffer into three Planar8 buffers.
pub fn rgb888ToPlanar8(
    src: *const vImage_Buffer,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageConvert_RGB888toPlanar8(src, red, green, blue, flags);
}

/// Split an RGBFFF interleaved buffer into three PlanarF buffers.
pub fn rgbFFFToPlanarF(
    src: *const vImage_Buffer,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageConvert_RGBFFFtoPlanarF(src, red, green, blue, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return switch (order) {
        .argb => c.vImageConvert_RGB888toARGB8888(rgb_src, alpha_src, alpha, dest, premultiply, flags),
        .rgba => c.vImageConvert_RGB888toRGBA8888(rgb_src, alpha_src, alpha, dest, premultiply, flags),
        .bgra => c.vImageConvert_RGB888toBGRA8888(rgb_src, alpha_src, alpha, dest, premultiply, flags),
    };
}

/// Strip the alpha channel from a 4-channel 8-bit buffer to produce RGB888.
pub fn interleaved8888ToRGB888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    order: ChannelOrder,
    flags: vImage_Flags,
) vImage_Error {
    return switch (order) {
        .argb => c.vImageConvert_ARGB8888toRGB888(src, dest, flags),
        .rgba => c.vImageConvert_RGBA8888toRGB888(src, dest, flags),
        .bgra => c.vImageConvert_BGRA8888toRGB888(src, dest, flags),
    };
}

// ============================================================================
// Float 4-channel <-> 3-channel
// ============================================================================

/// Strip the alpha channel from a 4-channel float buffer to produce RGBFFF.
pub fn interleavedFFFFToRGBFFF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    order: ChannelOrder,
    flags: vImage_Flags,
) vImage_Error {
    return switch (order) {
        .argb => c.vImageConvert_ARGBFFFFtoRGBFFF(src, dest, flags),
        .rgba => c.vImageConvert_RGBAFFFFtoRGBFFF(src, dest, flags),
        .bgra => c.vImageConvert_BGRAFFFFtoRGBFFF(src, dest, flags),
    };
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
    flags: vImage_Flags,
) vImage_Error {
    return switch (order) {
        .argb => c.vImageConvert_RGBFFFtoARGBFFFF(rgb_src, alpha_src, alpha, dest, premultiply, flags),
        .rgba => c.vImageConvert_RGBFFFtoRGBAFFFF(rgb_src, alpha_src, alpha, dest, premultiply, flags),
        .bgra => c.vImageConvert_RGBFFFtoBGRAFFFF(rgb_src, alpha_src, alpha, dest, premultiply, flags),
    };
}

/// Flatten an 8-bit 4-channel image against an opaque background color,
/// producing an RGB888 result.
pub fn flatten8888ToRGB888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    background_color: Pixel_8888,
    order: ChannelOrder,
    is_premultiplied: bool,
    flags: vImage_Flags,
) vImage_Error {
    return switch (order) {
        .argb => c.vImageFlatten_ARGB8888ToRGB888(src, dest, &background_color, is_premultiplied, flags),
        .rgba => c.vImageFlatten_RGBA8888ToRGB888(src, dest, &background_color, is_premultiplied, flags),
        .bgra => c.vImageFlatten_BGRA8888ToRGB888(src, dest, &background_color, is_premultiplied, flags),
    };
}

/// Flatten a float 4-channel image against an opaque background color,
/// producing an RGBFFF result.
pub fn flattenFFFFToRGBFFF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    background_color: Pixel_FFFF,
    order: ChannelOrder,
    is_premultiplied: bool,
    flags: vImage_Flags,
) vImage_Error {
    return switch (order) {
        .argb => c.vImageFlatten_ARGBFFFFToRGBFFF(src, dest, &background_color, is_premultiplied, flags),
        .rgba => c.vImageFlatten_RGBAFFFFToRGBFFF(src, dest, &background_color, is_premultiplied, flags),
        .bgra => c.vImageFlatten_BGRAFFFFToRGBFFF(src, dest, &background_color, is_premultiplied, flags),
    };
}

// ============================================================================
// Permute channels
// ============================================================================

/// Reorder the 4 color channels of an ARGB8888 image according to permuteMap.
///
/// Each value in permuteMap must be 0..3. For example, {3,2,1,0} converts
/// ARGB -> BGRA.
pub fn permuteChannelsARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, permute_map: [4]u8, flags: vImage_Flags) vImage_Error {
    return c.vImagePermuteChannels_ARGB8888(src, dest, &permute_map, flags);
}

/// Reorder the 4 color channels of an ARGB16U image according to permuteMap.
pub fn permuteChannelsARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, permute_map: [4]u8, flags: vImage_Flags) vImage_Error {
    return c.vImagePermuteChannels_ARGB16U(src, dest, &permute_map, flags);
}

/// Reorder the 4 color channels of an ARGBFFFF image according to permuteMap.
pub fn permuteChannelsARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, permute_map: [4]u8, flags: vImage_Flags) vImage_Error {
    return c.vImagePermuteChannels_ARGBFFFF(src, dest, &permute_map, flags);
}

/// Reorder the 3 color channels of an RGB888 image according to permuteMap.
///
/// Each value in permuteMap must be 0..2. For example, {2,1,0} converts
/// RGB -> BGR.
pub fn permuteChannelsRGB888(src: *const vImage_Buffer, dest: *const vImage_Buffer, permute_map: [3]u8, flags: vImage_Flags) vImage_Error {
    return c.vImagePermuteChannels_RGB888(src, dest, &permute_map, flags);
}

// ============================================================================
// Extract single channel
// ============================================================================

/// Extract a single channel from a 4-channel 8-bit buffer to a Planar8 buffer.
///
/// channelIndex: 0 = first channel (e.g. A in ARGB), 3 = last channel.
pub fn extractChannelARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, channel_index: usize, flags: vImage_Flags) vImage_Error {
    return c.vImageExtractChannel_ARGB8888(src, dest, @intCast(channel_index), flags);
}

/// Extract a single channel from a 4-channel 16U buffer to a Planar16U buffer.
pub fn extractChannelARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, channel_index: usize, flags: vImage_Flags) vImage_Error {
    return c.vImageExtractChannel_ARGB16U(src, dest, @intCast(channel_index), flags);
}

/// Extract a single channel from a 4-channel float buffer to a PlanarF buffer.
pub fn extractChannelARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, channel_index: usize, flags: vImage_Flags) vImage_Error {
    return c.vImageExtractChannel_ARGBFFFF(src, dest, @intCast(channel_index), flags);
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
pub fn overwriteChannelsARGB8888(new_src: *const vImage_Buffer, orig_src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: vImage_Flags) vImage_Error {
    return c.vImageOverwriteChannels_ARGB8888(new_src, orig_src, dest, copy_mask, flags);
}

/// Overwrite selected channels of an ARGBFFFF image with data from a planar buffer.
pub fn overwriteChannelsARGBFFFF(new_src: *const vImage_Buffer, orig_src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: vImage_Flags) vImage_Error {
    return c.vImageOverwriteChannels_ARGBFFFF(new_src, orig_src, dest, copy_mask, flags);
}

/// Fill a Planar8 buffer with a scalar value.
pub fn overwriteScalarPlanar8(scalar: Pixel_8, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImageOverwriteChannelsWithScalar_Planar8(scalar, dest, flags);
}

/// Fill a PlanarF buffer with a scalar value.
pub fn overwriteScalarPlanarF(scalar: Pixel_F, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImageOverwriteChannelsWithScalar_PlanarF(scalar, dest, flags);
}

/// Overwrite selected channels of an ARGB8888 image with a scalar value.
pub fn overwriteScalarARGB8888(scalar: Pixel_8, src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: vImage_Flags) vImage_Error {
    return c.vImageOverwriteChannelsWithScalar_ARGB8888(scalar, src, dest, copy_mask, flags);
}

/// Overwrite selected channels of an ARGBFFFF image with a scalar value.
pub fn overwriteScalarARGBFFFF(scalar: Pixel_F, src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: vImage_Flags) vImage_Error {
    return c.vImageOverwriteChannelsWithScalar_ARGBFFFF(scalar, src, dest, copy_mask, flags);
}

/// Overwrite selected channels of an ARGB8888 image with a pixel value.
pub fn overwritePixelARGB8888(pixel: Pixel_8888, src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: vImage_Flags) vImage_Error {
    return c.vImageOverwriteChannelsWithPixel_ARGB8888(&pixel, src, dest, copy_mask, flags);
}

/// Overwrite selected channels of an ARGBFFFF image with a pixel value.
pub fn overwritePixelARGBFFFF(pixel: Pixel_FFFF, src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: vImage_Flags) vImage_Error {
    return c.vImageOverwriteChannelsWithPixel_ARGBFFFF(&pixel, src, dest, copy_mask, flags);
}

// ============================================================================
// Select channels (interleaved source)
// ============================================================================

/// Select channels from newSrc (ARGB8888 interleaved) to overwrite channels in origSrc.
pub fn selectChannelsARGB8888(new_src: *const vImage_Buffer, orig_src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: vImage_Flags) vImage_Error {
    return c.vImageSelectChannels_ARGB8888(new_src, orig_src, dest, copy_mask, flags);
}

/// Select channels from newSrc (ARGBFFFF interleaved) to overwrite channels in origSrc.
pub fn selectChannelsARGBFFFF(new_src: *const vImage_Buffer, orig_src: *const vImage_Buffer, dest: *const vImage_Buffer, copy_mask: u8, flags: vImage_Flags) vImage_Error {
    return c.vImageSelectChannels_ARGBFFFF(new_src, orig_src, dest, copy_mask, flags);
}

// ============================================================================
// Buffer fill
// ============================================================================

/// Fill an ARGB8888 buffer with a constant color.
pub fn fillARGB8888(dest: *const vImage_Buffer, color: Pixel_8888, flags: vImage_Flags) vImage_Error {
    return c.vImageBufferFill_ARGB8888(dest, &color, flags);
}

/// Fill an ARGBFFFF buffer with a constant color.
pub fn fillARGBFFFF(dest: *const vImage_Buffer, color: Pixel_FFFF, flags: vImage_Flags) vImage_Error {
    return c.vImageBufferFill_ARGBFFFF(dest, &color, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageTableLookUp_ARGB8888(
        src,
        dest,
        if (alpha_table) |t| @as([*]const Pixel_8, t) else null,
        if (red_table) |t| @as([*]const Pixel_8, t) else null,
        if (green_table) |t| @as([*]const Pixel_8, t) else null,
        if (blue_table) |t| @as([*]const Pixel_8, t) else null,
        flags,
    );
}

/// Apply a lookup table to a Planar8 image.
pub fn tableLookUpPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]Pixel_8, flags: vImage_Flags) vImage_Error {
    return c.vImageTableLookUp_Planar8(src, dest, @as([*]const Pixel_8, table), flags);
}

// ============================================================================
// Copy buffer
// ============================================================================

/// Copy a vImage buffer from src to dest.
///
/// pixel_size is the number of bytes per pixel (e.g., 1 for Planar8, 4 for ARGB8888 or PlanarF, 16 for ARGBFFFF).
pub fn copyBuffer(src: *const vImage_Buffer, dest: *const vImage_Buffer, pixel_size: usize, flags: vImage_Flags) vImage_Error {
    return c.vImageCopyBuffer(src, dest, pixel_size, flags);
}
