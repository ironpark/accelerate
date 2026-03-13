const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const vImage_Flags = types.vImage_Flags;

// ============================================================================
// Alpha Blend (non-premultiplied)
// ============================================================================

/// Composite two non-premultiplied planar images to produce a non-premultiplied result.
///
/// For each color channel:
///     destColor = (srcTopColor * srcTopAlpha + (1 - srcTopAlpha) * srcBottomAlpha * srcBottomColor) / alpha
///
/// The `alpha` buffer must be pre-calculated. For planar data, compute it via:
///     premultipliedAlphaBlend(srcTopAlpha, srcTopAlpha, srcBottomAlpha, alpha, flags)
pub fn alphaBlendPlanar(comptime T: type, srcTop: *const vImage_Buffer, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, srcBottomAlpha: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImageAlphaBlend_Planar8(srcTop, srcTopAlpha, srcBottom, srcBottomAlpha, alpha, dest, flags),
        f32 => c.vImageAlphaBlend_PlanarF(srcTop, srcTopAlpha, srcBottom, srcBottomAlpha, alpha, dest, flags),
        else => @compileError("alphaBlendPlanar requires u8 or f32"),
    };
}

/// Composite two non-premultiplied ARGB interleaved images to produce a non-premultiplied result.
///
/// For each color channel:
///     destColor = (srcTopColor * srcTopAlpha + (1 - srcTopAlpha) * srcBottomAlpha * srcBottomColor) / alpha
pub fn alphaBlendARGB(comptime T: type, srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImageAlphaBlend_ARGB8888(srcTop, srcBottom, dest, flags),
        f32 => c.vImageAlphaBlend_ARGBFFFF(srcTop, srcBottom, dest, flags),
        else => @compileError("alphaBlendARGB requires u8 or f32"),
    };
}

// ============================================================================
// Alpha Blend (premultiplied)
// ============================================================================

/// Blend two premultiplied planar images to produce a premultiplied result.
///
/// For each color channel:
///     u8:  destColor = srcTopColor + ((255 - srcTopAlpha) * srcBottomColor + 127) / 255
///     f32: destColor = srcTopColor + (1.0 - srcTopAlpha) * srcBottomColor
pub fn premultipliedAlphaBlendPlanar(comptime T: type, srcTop: *const vImage_Buffer, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImagePremultipliedAlphaBlend_Planar8(srcTop, srcTopAlpha, srcBottom, dest, flags),
        f32 => c.vImagePremultipliedAlphaBlend_PlanarF(srcTop, srcTopAlpha, srcBottom, dest, flags),
        else => @compileError("premultipliedAlphaBlendPlanar requires u8 or f32"),
    };
}

/// Blend two premultiplied ARGB (alpha-first) interleaved images.
pub fn premultipliedAlphaBlendARGB(comptime T: type, srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImagePremultipliedAlphaBlend_ARGB8888(srcTop, srcBottom, dest, flags),
        f32 => c.vImagePremultipliedAlphaBlend_ARGBFFFF(srcTop, srcBottom, dest, flags),
        else => @compileError("premultipliedAlphaBlendARGB requires u8 or f32"),
    };
}

/// Blend two premultiplied BGRA/RGBA (alpha-last) interleaved images.
pub fn premultipliedAlphaBlendBGRA(comptime T: type, srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImagePremultipliedAlphaBlend_BGRA8888(srcTop, srcBottom, dest, flags),
        f32 => c.vImagePremultipliedAlphaBlend_BGRAFFFF(srcTop, srcBottom, dest, flags),
        else => @compileError("premultipliedAlphaBlendBGRA requires u8 or f32"),
    };
}

/// Reorder channels of the top premultiplied image via permuteMap, then blend into the bottom
/// premultiplied ARGB image. Optionally force destination alpha to 0xFF/opaque.
pub fn premultipliedAlphaBlendWithPermuteARGB(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, makeDestAlphaOpaque: bool, flags: vImage_Flags) vImage_Error {
    return c.vImagePremultipliedAlphaBlendWithPermute_ARGB8888(srcTop, srcBottom, dest, permuteMap, makeDestAlphaOpaque, flags);
}

/// Reorder channels of the top premultiplied image via permuteMap, then blend into the bottom
/// premultiplied RGBA image. Optionally force destination alpha to 0xFF/opaque.
pub fn premultipliedAlphaBlendWithPermuteRGBA(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, makeDestAlphaOpaque: bool, flags: vImage_Flags) vImage_Error {
    return c.vImagePremultipliedAlphaBlendWithPermute_RGBA8888(srcTop, srcBottom, dest, permuteMap, makeDestAlphaOpaque, flags);
}

// ============================================================================
// Alpha Blend (premultiplied, SVG blend modes) - RGBA only
// ============================================================================

pub const BlendMode = enum {
    normal,
    multiply,
    screen,
    darken,
    lighten,
};

/// Blend two premultiplied RGBA images using the specified SVG blend mode.
/// The `normal` mode calls the standard premultiplied alpha blend for BGRA/RGBA layout.
pub fn premultipliedAlphaBlendRGBA(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, mode: BlendMode, flags: vImage_Flags) vImage_Error {
    return switch (mode) {
        .normal => c.vImagePremultipliedAlphaBlend_BGRA8888(srcTop, srcBottom, dest, flags),
        .multiply => c.vImagePremultipliedAlphaBlendMultiply_RGBA8888(srcTop, srcBottom, dest, flags),
        .screen => c.vImagePremultipliedAlphaBlendScreen_RGBA8888(srcTop, srcBottom, dest, flags),
        .darken => c.vImagePremultipliedAlphaBlendDarken_RGBA8888(srcTop, srcBottom, dest, flags),
        .lighten => c.vImagePremultipliedAlphaBlendLighten_RGBA8888(srcTop, srcBottom, dest, flags),
    };
}

// ============================================================================
// Premultiplied Const Alpha Blend
// ============================================================================

/// Blend a premultiplied top image into a premultiplied bottom image, scaling the top
/// by a constant alpha value in addition to the per-pixel alpha.
///
/// Planar version requires separate alpha buffer.
pub fn premultipliedConstAlphaBlendPlanar(comptime T: type, srcTop: *const vImage_Buffer, constAlpha: T, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImagePremultipliedConstAlphaBlend_Planar8(srcTop, constAlpha, srcTopAlpha, srcBottom, dest, flags),
        f32 => c.vImagePremultipliedConstAlphaBlend_PlanarF(srcTop, constAlpha, srcTopAlpha, srcBottom, dest, flags),
        else => @compileError("premultipliedConstAlphaBlendPlanar requires u8 or f32"),
    };
}

/// Blend a premultiplied top ARGB image into a premultiplied bottom image, scaling the top
/// by a constant alpha value.
pub fn premultipliedConstAlphaBlendARGB(comptime T: type, srcTop: *const vImage_Buffer, constAlpha: T, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImagePremultipliedConstAlphaBlend_ARGB8888(srcTop, constAlpha, srcBottom, dest, flags),
        f32 => c.vImagePremultipliedConstAlphaBlend_ARGBFFFF(srcTop, constAlpha, srcBottom, dest, flags),
        else => @compileError("premultipliedConstAlphaBlendARGB requires u8 or f32"),
    };
}

// ============================================================================
// Alpha Blend (non-premultiplied to premultiplied)
// ============================================================================

/// Blend a non-premultiplied top image over a premultiplied bottom image, producing a
/// premultiplied result. Planar version requires separate alpha buffer.
pub fn alphaBlendNonpremultipliedToPremultipliedPlanar(comptime T: type, srcTop: *const vImage_Buffer, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImageAlphaBlend_NonpremultipliedToPremultiplied_Planar8(srcTop, srcTopAlpha, srcBottom, dest, flags),
        f32 => c.vImageAlphaBlend_NonpremultipliedToPremultiplied_PlanarF(srcTop, srcTopAlpha, srcBottom, dest, flags),
        else => @compileError("alphaBlendNonpremultipliedToPremultipliedPlanar requires u8 or f32"),
    };
}

/// Blend a non-premultiplied top ARGB image over a premultiplied bottom image, producing a
/// premultiplied result.
pub fn alphaBlendNonpremultipliedToPremultipliedARGB(comptime T: type, srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImageAlphaBlend_NonpremultipliedToPremultiplied_ARGB8888(srcTop, srcBottom, dest, flags),
        f32 => c.vImageAlphaBlend_NonpremultipliedToPremultiplied_ARGBFFFF(srcTop, srcBottom, dest, flags),
        else => @compileError("alphaBlendNonpremultipliedToPremultipliedARGB requires u8 or f32"),
    };
}

// ============================================================================
// Premultiply Data
// ============================================================================

/// Multiply a planar color channel by its corresponding alpha channel.
///
///     u8:  destColor = (src * alpha + 127) / 255
///     f32: destColor = src * alpha
pub fn premultiplyDataPlanar(comptime T: type, src: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImagePremultiplyData_Planar8(src, alpha, dest, flags),
        f32 => c.vImagePremultiplyData_PlanarF(src, alpha, dest, flags),
        else => @compileError("premultiplyDataPlanar requires u8 or f32"),
    };
}

/// Premultiply an ARGB (alpha-first) interleaved image by its alpha channel.
pub fn premultiplyDataARGB(comptime T: type, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImagePremultiplyData_ARGB8888(src, dest, flags),
        f32 => c.vImagePremultiplyData_ARGBFFFF(src, dest, flags),
        else => @compileError("premultiplyDataARGB requires u8 or f32"),
    };
}

/// Premultiply an RGBA/BGRA (alpha-last) interleaved image by its alpha channel.
pub fn premultiplyDataRGBA(comptime T: type, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImagePremultiplyData_RGBA8888(src, dest, flags),
        f32 => c.vImagePremultiplyData_RGBAFFFF(src, dest, flags),
        else => @compileError("premultiplyDataRGBA requires u8 or f32"),
    };
}

/// Premultiply an ARGB 16-bit unsigned interleaved image by its alpha channel.
pub fn premultiplyDataARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImagePremultiplyData_ARGB16U(src, dest, flags);
}

/// Premultiply an RGBA 16-bit unsigned interleaved image by its alpha channel.
pub fn premultiplyDataRGBA16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImagePremultiplyData_RGBA16U(src, dest, flags);
}

/// Premultiply an ARGB 16Q12 fixed-point interleaved image by its alpha channel.
pub fn premultiplyDataARGB16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImagePremultiplyData_ARGB16Q12(src, dest, flags);
}

/// Premultiply an RGBA 16Q12 fixed-point interleaved image by its alpha channel.
pub fn premultiplyDataRGBA16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImagePremultiplyData_RGBA16Q12(src, dest, flags);
}

/// Premultiply an RGBA half-float (16F) interleaved image by its alpha channel.
pub fn premultiplyDataRGBA16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImagePremultiplyData_RGBA16F(src, dest, flags);
}

// ============================================================================
// Unpremultiply Data
// ============================================================================

/// Divide a planar color channel by its corresponding alpha channel to recover
/// non-premultiplied values.
///
///     u8:  destColor = (src * 255 + alpha/2) / alpha  (0 if alpha == 0)
///     f32: destColor = src / alpha                     (0 if alpha == 0)
pub fn unpremultiplyDataPlanar(comptime T: type, src: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImageUnpremultiplyData_Planar8(src, alpha, dest, flags),
        f32 => c.vImageUnpremultiplyData_PlanarF(src, alpha, dest, flags),
        else => @compileError("unpremultiplyDataPlanar requires u8 or f32"),
    };
}

/// Unpremultiply an ARGB (alpha-first) interleaved image.
pub fn unpremultiplyDataARGB(comptime T: type, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImageUnpremultiplyData_ARGB8888(src, dest, flags),
        f32 => c.vImageUnpremultiplyData_ARGBFFFF(src, dest, flags),
        else => @compileError("unpremultiplyDataARGB requires u8 or f32"),
    };
}

/// Unpremultiply an RGBA/BGRA (alpha-last) interleaved image.
pub fn unpremultiplyDataRGBA(comptime T: type, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImageUnpremultiplyData_RGBA8888(src, dest, flags),
        f32 => c.vImageUnpremultiplyData_RGBAFFFF(src, dest, flags),
        else => @compileError("unpremultiplyDataRGBA requires u8 or f32"),
    };
}

/// Unpremultiply an ARGB 16-bit unsigned interleaved image.
pub fn unpremultiplyDataARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImageUnpremultiplyData_ARGB16U(src, dest, flags);
}

/// Unpremultiply an RGBA 16-bit unsigned interleaved image.
pub fn unpremultiplyDataRGBA16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImageUnpremultiplyData_RGBA16U(src, dest, flags);
}

/// Unpremultiply an ARGB 16Q12 fixed-point interleaved image.
pub fn unpremultiplyDataARGB16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImageUnpremultiplyData_ARGB16Q12(src, dest, flags);
}

/// Unpremultiply an RGBA 16Q12 fixed-point interleaved image.
pub fn unpremultiplyDataRGBA16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImageUnpremultiplyData_RGBA16Q12(src, dest, flags);
}

/// Unpremultiply an RGBA half-float (16F) interleaved image.
pub fn unpremultiplyDataRGBA16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return c.vImageUnpremultiplyData_RGBA16F(src, dest, flags);
}

// ============================================================================
// Clip to Alpha
// ============================================================================

/// Clip color channel values so they do not exceed the alpha value.
/// Planar version requires separate alpha buffer.
///
/// For each pixel: dest = min(src, alpha)
pub fn clipToAlphaPlanar(comptime T: type, src: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImageClipToAlpha_Planar8(src, alpha, dest, flags),
        f32 => c.vImageClipToAlpha_PlanarF(src, alpha, dest, flags),
        else => @compileError("clipToAlphaPlanar requires u8 or f32"),
    };
}

/// Clip color channel values so they do not exceed the alpha value.
/// ARGB (alpha-first) interleaved version.
pub fn clipToAlphaARGB(comptime T: type, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImageClipToAlpha_ARGB8888(src, dest, flags),
        f32 => c.vImageClipToAlpha_ARGBFFFF(src, dest, flags),
        else => @compileError("clipToAlphaARGB requires u8 or f32"),
    };
}

/// Clip color channel values so they do not exceed the alpha value.
/// RGBA/BGRA (alpha-last) interleaved version.
pub fn clipToAlphaRGBA(comptime T: type, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error {
    return switch (T) {
        u8 => c.vImageClipToAlpha_RGBA8888(src, dest, flags),
        f32 => c.vImageClipToAlpha_RGBAFFFF(src, dest, flags),
        else => @compileError("clipToAlphaRGBA requires u8 or f32"),
    };
}
