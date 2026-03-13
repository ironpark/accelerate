const types = @import("types.zig");
const vImage_Buffer = types.vImage_Buffer;
const vImagePixelCount = types.vImagePixelCount;
const vImage_Flags = types.vImage_Flags;
const vImage_Error = types.vImage_Error;
const vImage_AffineTransform = types.vImage_AffineTransform;
const vImage_AffineTransform_Double = types.vImage_AffineTransform_Double;
const vImage_CGAffineTransform = types.vImage_CGAffineTransform;
const Pixel_8 = types.Pixel_8;
const Pixel_F = types.Pixel_F;
const Pixel_8888 = types.Pixel_8888;
const Pixel_FFFF = types.Pixel_FFFF;
const Pixel_ARGB_16U = types.Pixel_ARGB_16U;
const Pixel_ARGB_16S = types.Pixel_ARGB_16S;
const Pixel_16U = types.Pixel_16U;
const Pixel_16S = types.Pixel_16S;
const ResamplingFilter = types.ResamplingFilter;
const c = @import("c.zig");

/// Background color type for a given pixel type.
/// Planar formats use a scalar; multi-channel formats use a pointer to an array.
fn BackColor(comptime T: type) type {
    return switch (T) {
        Pixel_8 => Pixel_8,
        Pixel_F => Pixel_F,
        Pixel_8888 => *const Pixel_8888,
        Pixel_FFFF => *const Pixel_FFFF,
        Pixel_ARGB_16U => *const Pixel_ARGB_16U,
        Pixel_ARGB_16S => *const Pixel_ARGB_16S,
        else => @compileError("Unsupported pixel type for geometry. Use Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S."),
    };
}

// ============================================================================
// Rotate
// ============================================================================

/// Rotate an image by an arbitrary angle (in radians) around its center.
///
/// The destination buffer receives the rotated image. Areas revealed by the
/// rotation are filled with `backColor` (when using kvImageBackgroundColorFill).
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_8888`, `Pixel_FFFF`,
/// `Pixel_ARGB_16U`, `Pixel_ARGB_16S`.
///
/// Does not work in place.
pub fn rotate(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    angleInRadians: f32,
    backColor: BackColor(T),
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        Pixel_8 => c.vImageRotate_Planar8(src, dest, tempBuffer, angleInRadians, backColor, flags),
        Pixel_F => c.vImageRotate_PlanarF(src, dest, tempBuffer, angleInRadians, backColor, flags),
        Pixel_8888 => c.vImageRotate_ARGB8888(src, dest, tempBuffer, angleInRadians, backColor, flags),
        Pixel_FFFF => c.vImageRotate_ARGBFFFF(src, dest, tempBuffer, angleInRadians, backColor, flags),
        Pixel_ARGB_16U => c.vImageRotate_ARGB16U(src, dest, tempBuffer, angleInRadians, backColor, flags),
        Pixel_ARGB_16S => c.vImageRotate_ARGB16S(src, dest, tempBuffer, angleInRadians, backColor, flags),
        else => @compileError("rotate requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    };
}

// ============================================================================
// Scale
// ============================================================================

/// Resize an image to the dimensions of the destination buffer.
///
/// The source image is scaled to fit the destination buffer using a
/// high-quality resampling filter. Edge pixels are extended to prevent
/// background color bleeding.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_8888`, `Pixel_FFFF`,
/// `Pixel_ARGB_16U`, `Pixel_ARGB_16S`.
///
/// Does not work in place.
pub fn scale(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        Pixel_8 => c.vImageScale_Planar8(src, dest, tempBuffer, flags),
        Pixel_F => c.vImageScale_PlanarF(src, dest, tempBuffer, flags),
        Pixel_8888 => c.vImageScale_ARGB8888(src, dest, tempBuffer, flags),
        Pixel_FFFF => c.vImageScale_ARGBFFFF(src, dest, tempBuffer, flags),
        Pixel_ARGB_16U => c.vImageScale_ARGB16U(src, dest, tempBuffer, flags),
        Pixel_ARGB_16S => c.vImageScale_ARGB16S(src, dest, tempBuffer, flags),
        Pixel_16U => c.vImageScale_Planar16U(src, dest, tempBuffer, flags),
        Pixel_16S => c.vImageScale_Planar16S(src, dest, tempBuffer, flags),
        else => @compileError("scale requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, Pixel_ARGB_16S, Pixel_16U, or Pixel_16S"),
    };
}

// ============================================================================
// Reflect
// ============================================================================

/// Reflect an image horizontally (left-right mirror).
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_8888`, `Pixel_FFFF`,
/// `Pixel_ARGB_16U`, `Pixel_ARGB_16S`.
///
/// Does not work in place.
pub fn horizontalReflect(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        Pixel_8 => c.vImageHorizontalReflect_Planar8(src, dest, flags),
        Pixel_F => c.vImageHorizontalReflect_PlanarF(src, dest, flags),
        Pixel_8888 => c.vImageHorizontalReflect_ARGB8888(src, dest, flags),
        Pixel_FFFF => c.vImageHorizontalReflect_ARGBFFFF(src, dest, flags),
        Pixel_ARGB_16U => c.vImageHorizontalReflect_ARGB16U(src, dest, flags),
        Pixel_ARGB_16S => c.vImageHorizontalReflect_ARGB16S(src, dest, flags),
        else => @compileError("horizontalReflect requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    };
}

/// Reflect an image vertically (top-bottom mirror).
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_8888`, `Pixel_FFFF`,
/// `Pixel_ARGB_16U`, `Pixel_ARGB_16S`.
///
/// Does not work in place.
pub fn verticalReflect(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        Pixel_8 => c.vImageVerticalReflect_Planar8(src, dest, flags),
        Pixel_F => c.vImageVerticalReflect_PlanarF(src, dest, flags),
        Pixel_8888 => c.vImageVerticalReflect_ARGB8888(src, dest, flags),
        Pixel_FFFF => c.vImageVerticalReflect_ARGBFFFF(src, dest, flags),
        Pixel_ARGB_16U => c.vImageVerticalReflect_ARGB16U(src, dest, flags),
        Pixel_ARGB_16S => c.vImageVerticalReflect_ARGB16S(src, dest, flags),
        else => @compileError("verticalReflect requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    };
}

// ============================================================================
// Rotate90
// ============================================================================

/// Rotation constants for 90-degree rotation functions.
pub const RotationConstant = enum(u8) {
    rotate_0 = 0,
    rotate_90_ccw = 1,
    rotate_180 = 2,
    rotate_270_ccw = 3,

    // Clockwise aliases
    pub const rotate_90_cw: RotationConstant = .rotate_270_ccw;
    pub const rotate_270_cw: RotationConstant = .rotate_90_ccw;
};

/// Rotate an image by a multiple of 90 degrees.
///
/// Images are rotated about their center. If source and destination sizes
/// do not match, parts of the image may be clipped and revealed areas are
/// filled with `backColor`.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_8888`, `Pixel_FFFF`,
/// `Pixel_ARGB_16U`, `Pixel_ARGB_16S`.
///
/// Does not work in place.
pub fn rotate90(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    rotationConstant: RotationConstant,
    backColor: BackColor(T),
    flags: vImage_Flags,
) vImage_Error {
    const rc = @intFromEnum(rotationConstant);
    return switch (T) {
        Pixel_8 => c.vImageRotate90_Planar8(src, dest, rc, backColor, flags),
        Pixel_F => c.vImageRotate90_PlanarF(src, dest, rc, backColor, flags),
        Pixel_8888 => c.vImageRotate90_ARGB8888(src, dest, rc, backColor, flags),
        Pixel_FFFF => c.vImageRotate90_ARGBFFFF(src, dest, rc, backColor, flags),
        Pixel_ARGB_16U => c.vImageRotate90_ARGB16U(src, dest, rc, backColor, flags),
        Pixel_ARGB_16S => c.vImageRotate90_ARGB16S(src, dest, rc, backColor, flags),
        else => @compileError("rotate90 requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    };
}

// ============================================================================
// Affine Warp
// ============================================================================

/// Apply a single-precision affine transform to an image.
///
/// The transform matrix maps source to destination coordinates:
///
///                   |  a   b  |
///     (x', y') = (x, y) |         | + (tx, ty)
///                   |  c   d  |
///
/// Coordinate space origin is at the bottom-left corner.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_8888`, `Pixel_FFFF`,
/// `Pixel_ARGB_16U`, `Pixel_ARGB_16S`.
///
/// Does not work in place.
pub fn affineWarp(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    transform: *const vImage_AffineTransform,
    backColor: BackColor(T),
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        Pixel_8 => c.vImageAffineWarp_Planar8(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_F => c.vImageAffineWarp_PlanarF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_8888 => c.vImageAffineWarp_ARGB8888(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_FFFF => c.vImageAffineWarp_ARGBFFFF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16U => c.vImageAffineWarp_ARGB16U(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16S => c.vImageAffineWarp_ARGB16S(src, dest, tempBuffer, transform, backColor, flags),
        else => @compileError("affineWarp requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    };
}

/// Apply a double-precision affine transform to an image.
///
/// Same as `affineWarp` but uses `vImage_AffineTransform_Double` for
/// higher-precision transform matrices.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_8888`, `Pixel_FFFF`,
/// `Pixel_ARGB_16U`, `Pixel_ARGB_16S`.
///
/// Does not work in place.
pub fn affineWarpD(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    transform: *const vImage_AffineTransform_Double,
    backColor: BackColor(T),
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        Pixel_8 => c.vImageAffineWarpD_Planar8(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_F => c.vImageAffineWarpD_PlanarF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_8888 => c.vImageAffineWarpD_ARGB8888(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_FFFF => c.vImageAffineWarpD_ARGBFFFF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16U => c.vImageAffineWarpD_ARGB16U(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16S => c.vImageAffineWarpD_ARGB16S(src, dest, tempBuffer, transform, backColor, flags),
        else => @compileError("affineWarpD requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    };
}

/// Apply a CGAffineTransform-based affine warp to an image.
///
/// Convenience wrapper that accepts `vImage_CGAffineTransform` (double-precision
/// on 64-bit platforms), matching CoreGraphics conventions directly.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_8888`, `Pixel_FFFF`,
/// `Pixel_ARGB_16U`, `Pixel_ARGB_16S`.
///
/// Does not work in place.
pub fn affineWarpCG(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    transform: *const vImage_CGAffineTransform,
    backColor: BackColor(T),
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        Pixel_8 => c.vImageAffineWarpCG_Planar8(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_F => c.vImageAffineWarpCG_PlanarF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_8888 => c.vImageAffineWarpCG_ARGB8888(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_FFFF => c.vImageAffineWarpCG_ARGBFFFF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16U => c.vImageAffineWarpCG_ARGB16U(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16S => c.vImageAffineWarpCG_ARGB16S(src, dest, tempBuffer, transform, backColor, flags),
        else => @compileError("affineWarpCG requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    };
}

// ============================================================================
// Shear
// ============================================================================

/// Apply a horizontal shear, rescale, and translate to an image.
///
/// The shear slope corresponds to the off-diagonal element (0,1) of an
/// equivalent affine transform matrix. A `ResamplingFilter` must be created
/// with `newResamplingFilter` before calling this function.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_8888`, `Pixel_FFFF`,
/// `Pixel_ARGB_16U`, `Pixel_ARGB_16S`.
///
/// Does not work in place.
pub fn horizontalShear(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    xTranslate: f32,
    shearSlope: f32,
    filter: ResamplingFilter,
    backColor: BackColor(T),
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        Pixel_8 => c.vImageHorizontalShear_Planar8(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_F => c.vImageHorizontalShear_PlanarF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_8888 => c.vImageHorizontalShear_ARGB8888(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_FFFF => c.vImageHorizontalShear_ARGBFFFF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16U => c.vImageHorizontalShear_ARGB16U(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16S => c.vImageHorizontalShear_ARGB16S(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        else => @compileError("horizontalShear requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    };
}

/// Apply a vertical shear, rescale, and translate to an image.
///
/// The shear slope corresponds to the off-diagonal element (1,0) of an
/// equivalent affine transform matrix. A `ResamplingFilter` must be created
/// with `newResamplingFilter` before calling this function.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_8888`, `Pixel_FFFF`,
/// `Pixel_ARGB_16U`, `Pixel_ARGB_16S`.
///
/// Does not work in place.
pub fn verticalShear(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    yTranslate: f32,
    shearSlope: f32,
    filter: ResamplingFilter,
    backColor: BackColor(T),
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        Pixel_8 => c.vImageVerticalShear_Planar8(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_F => c.vImageVerticalShear_PlanarF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_8888 => c.vImageVerticalShear_ARGB8888(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_FFFF => c.vImageVerticalShear_ARGBFFFF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16U => c.vImageVerticalShear_ARGB16U(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16S => c.vImageVerticalShear_ARGB16S(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        else => @compileError("verticalShear requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    };
}

// ============================================================================
// Resampling Filter
// ============================================================================

/// Create a new resampling filter for use with shear functions.
///
/// The `scale` parameter sets the magnification/minification factor:
/// - 1.0 = original size
/// - 2.0 = double size (magnify)
/// - 0.5 = half size (minify)
/// - Negative values flip the axis.
///
/// Set `kvImageHighQualityResampling` in flags for a Lanczos5 kernel;
/// otherwise Lanczos3 is used.
///
/// The returned filter must be destroyed with `destroyResamplingFilter`
/// when no longer needed.
pub fn newResamplingFilter(scale_factor: f32, flags: vImage_Flags) ResamplingFilter {
    return c.vImageNewResamplingFilter(scale_factor, flags);
}

/// Destroy a resampling filter previously created with `newResamplingFilter`.
pub fn destroyResamplingFilter(filter: ResamplingFilter) void {
    c.vImageDestroyResamplingFilter(filter);
}
