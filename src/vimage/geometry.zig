const std = @import("std");
const types = @import("types.zig");
const vImage_Buffer = types.vImage_Buffer;
const vImagePixelCount = types.vImagePixelCount;
const vImage_Flags = types.vImage_Flags;
const vImage_Error = types.vImage_Error;
const VImageError = types.VImageError;
const check = types.check;
const vImage_AffineTransform = types.vImage_AffineTransform;
const vImage_AffineTransform_Double = types.vImage_AffineTransform_Double;
const vImage_CGAffineTransform = types.vImage_CGAffineTransform;
const vImage_PerspectiveTransform = types.vImage_PerspectiveTransform;
const WarpInterpolation = types.WarpInterpolation;
const KernelFunc = types.KernelFunc;
const Pixel_8 = types.Pixel_8;
const Pixel_F = types.Pixel_F;
const Pixel_8888 = types.Pixel_8888;
const Pixel_FFFF = types.Pixel_FFFF;
const Pixel_ARGB_16U = types.Pixel_ARGB_16U;
const Pixel_ARGB_16S = types.Pixel_ARGB_16S;
const Pixel_16U = types.Pixel_16U;
const Pixel_16S = types.Pixel_16S;
const Pixel_16F = types.Pixel_16F;
const Pixel_ARGB_16F = types.Pixel_ARGB_16F;
const Pixel_88 = types.Pixel_88;
const Pixel_16U16U = types.Pixel_16U16U;
const Pixel_16S16S = types.Pixel_16S16S;
const Pixel_16F16F = types.Pixel_16F16F;
const Pixel_32U = types.Pixel_32U;
const ResamplingFilter = types.ResamplingFilter;
const Flags = types.Flags;
const c = @import("c.zig");

// ============================================================================
// Pixel type keys
// ============================================================================
//
// Every function here is dispatched on a *pixel* type. That works because each
// of vImage's geometry formats has a distinct Zig type - with two exceptions
// that would otherwise collide:
//
//   * `Pixel_16F` and `Pixel_16U` are both `u16`, and `Pixel_ARGB_16F` and
//     `Pixel_ARGB_16U` are both `[4]u16`, because vImage stores half-precision
//     as its raw bit pattern.
//   * `Pixel_16F16F` and `Pixel_16U16U` are both `[2]u16` for the same reason.
//
// So the half-precision formats are keyed by `f16`, `[4]f16` and `[2]f16`
// instead, which are distinct types *and* are what a caller actually wants to
// write a background colour as. The conversion to bits happens at the call
// boundary in `halfBits`.

/// Background colour type for a given pixel type. Planar formats take a
/// scalar; multi-channel formats take a pointer, because the C parameter is an
/// array and decays to one.
fn BackColor(comptime T: type) type {
    return switch (T) {
        Pixel_8, Pixel_F, Pixel_16U, Pixel_16S, Pixel_32U, f16 => T,
        Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, Pixel_ARGB_16S => *const T,
        Pixel_88, Pixel_16U16U, Pixel_16S16S => *const T,
        [4]f16, [2]f16 => *const T,
        else => @compileError("Unsupported pixel type for geometry"),
    };
}

/// vImage's 16F formats are IEEE 754 binary16 held in a `uint16_t`, so a
/// background colour crosses as its bit pattern. Callers write `0.5`.
fn halfBits(value: f16) Pixel_16F {
    return @bitCast(value);
}

fn halfBits4(value: [4]f16) Pixel_ARGB_16F {
    return .{ halfBits(value[0]), halfBits(value[1]), halfBits(value[2]), halfBits(value[3]) };
}

fn halfBits2(value: [2]f16) Pixel_16F16F {
    return .{ halfBits(value[0]), halfBits(value[1]) };
}

// ============================================================================
// Rotate
// ============================================================================

/// Rotate an image by an arbitrary angle (in radians) around its center.
///
/// Areas revealed by the rotation are filled with `backColor` when
/// `kvImageBackgroundColorFill` is set.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `[2]f16`.
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageRotate_Planar8(src, dest, tempBuffer, angleInRadians, backColor, flags),
        Pixel_F => c.vImageRotate_PlanarF(src, dest, tempBuffer, angleInRadians, backColor, flags),
        f16 => c.vImageRotate_Planar16F(src, dest, tempBuffer, angleInRadians, halfBits(backColor), flags),
        Pixel_8888 => c.vImageRotate_ARGB8888(src, dest, tempBuffer, angleInRadians, backColor, flags),
        Pixel_FFFF => c.vImageRotate_ARGBFFFF(src, dest, tempBuffer, angleInRadians, backColor, flags),
        Pixel_ARGB_16U => c.vImageRotate_ARGB16U(src, dest, tempBuffer, angleInRadians, backColor, flags),
        Pixel_ARGB_16S => c.vImageRotate_ARGB16S(src, dest, tempBuffer, angleInRadians, backColor, flags),
        [4]f16 => blk: {
            const bg = halfBits4(backColor.*);
            break :blk c.vImageRotate_ARGB16F(src, dest, tempBuffer, angleInRadians, &bg, flags);
        },
        [2]f16 => blk: {
            const bg = halfBits2(backColor.*);
            break :blk c.vImageRotate_CbCr16F(src, dest, tempBuffer, angleInRadians, &bg, flags);
        },
        else => @compileError("rotate supports only: " ++ "`Pixel_8`, `Pixel_F`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `[2]f16`"),
    });
}

// ============================================================================
// Scale
// ============================================================================

/// Resize an image to the dimensions of the destination buffer.
///
/// The source is scaled to fit `dest` with a high-quality resampling filter.
/// Edge pixels are extended, so no background colour is involved.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_16U`, `Pixel_16S`, `f16`, `Pixel_32U`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `Pixel_88`, `Pixel_16U16U`, `[2]f16`.
///
/// Does not work in place.
pub fn scale(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    flags: vImage_Flags,
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageScale_Planar8(src, dest, tempBuffer, flags),
        Pixel_F => c.vImageScale_PlanarF(src, dest, tempBuffer, flags),
        Pixel_16U => c.vImageScale_Planar16U(src, dest, tempBuffer, flags),
        Pixel_16S => c.vImageScale_Planar16S(src, dest, tempBuffer, flags),
        f16 => c.vImageScale_Planar16F(src, dest, tempBuffer, flags),
        Pixel_32U => c.vImageScale_XRGB2101010W(src, dest, tempBuffer, flags),
        Pixel_8888 => c.vImageScale_ARGB8888(src, dest, tempBuffer, flags),
        Pixel_FFFF => c.vImageScale_ARGBFFFF(src, dest, tempBuffer, flags),
        Pixel_ARGB_16U => c.vImageScale_ARGB16U(src, dest, tempBuffer, flags),
        Pixel_ARGB_16S => c.vImageScale_ARGB16S(src, dest, tempBuffer, flags),
        [4]f16 => c.vImageScale_ARGB16F(src, dest, tempBuffer, flags),
        Pixel_88 => c.vImageScale_CbCr8(src, dest, tempBuffer, flags),
        Pixel_16U16U => c.vImageScale_CbCr16U(src, dest, tempBuffer, flags),
        [2]f16 => c.vImageScale_CbCr16F(src, dest, tempBuffer, flags),
        else => @compileError("scale supports only: " ++ "`Pixel_8`, `Pixel_F`, `Pixel_16U`, `Pixel_16S`, `f16`, `Pixel_32U`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `Pixel_88`, `Pixel_16U16U`, `[2]f16`"),
    });
}

// ============================================================================
// Reflect
// ============================================================================

/// Reflect an image horizontally (left-right mirror).
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_16U`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `[2]f16`.
///
/// Does not work in place.
pub fn horizontalReflect(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: vImage_Flags,
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageHorizontalReflect_Planar8(src, dest, flags),
        Pixel_F => c.vImageHorizontalReflect_PlanarF(src, dest, flags),
        Pixel_16U => c.vImageHorizontalReflect_Planar16U(src, dest, flags),
        f16 => c.vImageHorizontalReflect_Planar16F(src, dest, flags),
        Pixel_8888 => c.vImageHorizontalReflect_ARGB8888(src, dest, flags),
        Pixel_FFFF => c.vImageHorizontalReflect_ARGBFFFF(src, dest, flags),
        Pixel_ARGB_16U => c.vImageHorizontalReflect_ARGB16U(src, dest, flags),
        Pixel_ARGB_16S => c.vImageHorizontalReflect_ARGB16S(src, dest, flags),
        [4]f16 => c.vImageHorizontalReflect_ARGB16F(src, dest, flags),
        [2]f16 => c.vImageHorizontalReflect_CbCr16F(src, dest, flags),
        else => @compileError("horizontalReflect supports only: " ++ "`Pixel_8`, `Pixel_F`, `Pixel_16U`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `[2]f16`"),
    });
}

/// Reflect an image vertically (top-bottom mirror).
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_16U`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `[2]f16`.
///
/// Does not work in place.
pub fn verticalReflect(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: vImage_Flags,
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageVerticalReflect_Planar8(src, dest, flags),
        Pixel_F => c.vImageVerticalReflect_PlanarF(src, dest, flags),
        Pixel_16U => c.vImageVerticalReflect_Planar16U(src, dest, flags),
        f16 => c.vImageVerticalReflect_Planar16F(src, dest, flags),
        Pixel_8888 => c.vImageVerticalReflect_ARGB8888(src, dest, flags),
        Pixel_FFFF => c.vImageVerticalReflect_ARGBFFFF(src, dest, flags),
        Pixel_ARGB_16U => c.vImageVerticalReflect_ARGB16U(src, dest, flags),
        Pixel_ARGB_16S => c.vImageVerticalReflect_ARGB16S(src, dest, flags),
        [4]f16 => c.vImageVerticalReflect_ARGB16F(src, dest, flags),
        [2]f16 => c.vImageVerticalReflect_CbCr16F(src, dest, flags),
        else => @compileError("verticalReflect supports only: " ++ "`Pixel_8`, `Pixel_F`, `Pixel_16U`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `[2]f16`"),
    });
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
/// Images are rotated about their center. If source and destination sizes do
/// not match, parts of the image may be clipped and revealed areas are filled
/// with `backColor`.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_16U`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `[2]f16`.
///
/// Does not work in place.
pub fn rotate90(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    rotationConstant: RotationConstant,
    backColor: BackColor(T),
    flags: vImage_Flags,
) VImageError!usize {
    const rc = @intFromEnum(rotationConstant);
    return check(switch (T) {
        Pixel_8 => c.vImageRotate90_Planar8(src, dest, rc, backColor, flags),
        Pixel_F => c.vImageRotate90_PlanarF(src, dest, rc, backColor, flags),
        Pixel_16U => c.vImageRotate90_Planar16U(src, dest, rc, backColor, flags),
        f16 => c.vImageRotate90_Planar16F(src, dest, rc, halfBits(backColor), flags),
        Pixel_8888 => c.vImageRotate90_ARGB8888(src, dest, rc, backColor, flags),
        Pixel_FFFF => c.vImageRotate90_ARGBFFFF(src, dest, rc, backColor, flags),
        Pixel_ARGB_16U => c.vImageRotate90_ARGB16U(src, dest, rc, backColor, flags),
        Pixel_ARGB_16S => c.vImageRotate90_ARGB16S(src, dest, rc, backColor, flags),
        [4]f16 => blk: {
            const bg = halfBits4(backColor.*);
            break :blk c.vImageRotate90_ARGB16F(src, dest, rc, &bg, flags);
        },
        [2]f16 => blk: {
            const bg = halfBits2(backColor.*);
            break :blk c.vImageRotate90_CbCr16F(src, dest, rc, &bg, flags);
        },
        else => @compileError("rotate90 supports only: " ++ "`Pixel_8`, `Pixel_F`, `Pixel_16U`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `[2]f16`"),
    });
}

// ============================================================================
// Affine Warp
// ============================================================================

/// Apply a single-precision affine transform to an image.
///
/// The transform matrix maps source to destination coordinates:
///
///                       |  a   b  |
///     (x', y') = (x, y) |         | + (tx, ty)
///                       |  c   d  |
///
/// Coordinate space origin is at the bottom-left corner.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `[2]f16`.
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageAffineWarp_Planar8(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_F => c.vImageAffineWarp_PlanarF(src, dest, tempBuffer, transform, backColor, flags),
        f16 => c.vImageAffineWarp_Planar16F(src, dest, tempBuffer, transform, halfBits(backColor), flags),
        Pixel_8888 => c.vImageAffineWarp_ARGB8888(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_FFFF => c.vImageAffineWarp_ARGBFFFF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16U => c.vImageAffineWarp_ARGB16U(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16S => c.vImageAffineWarp_ARGB16S(src, dest, tempBuffer, transform, backColor, flags),
        [4]f16 => blk: {
            const bg = halfBits4(backColor.*);
            break :blk c.vImageAffineWarp_ARGB16F(src, dest, tempBuffer, transform, &bg, flags);
        },
        [2]f16 => blk: {
            const bg = halfBits2(backColor.*);
            break :blk c.vImageAffineWarp_CbCr16F(src, dest, tempBuffer, transform, &bg, flags);
        },
        else => @compileError("affineWarp supports only: " ++ "`Pixel_8`, `Pixel_F`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `[2]f16`"),
    });
}

/// Apply a double-precision affine transform to an image.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `[2]f16`.
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageAffineWarpD_Planar8(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_F => c.vImageAffineWarpD_PlanarF(src, dest, tempBuffer, transform, backColor, flags),
        f16 => c.vImageAffineWarpD_Planar16F(src, dest, tempBuffer, transform, halfBits(backColor), flags),
        Pixel_8888 => c.vImageAffineWarpD_ARGB8888(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_FFFF => c.vImageAffineWarpD_ARGBFFFF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16U => c.vImageAffineWarpD_ARGB16U(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16S => c.vImageAffineWarpD_ARGB16S(src, dest, tempBuffer, transform, backColor, flags),
        [4]f16 => blk: {
            const bg = halfBits4(backColor.*);
            break :blk c.vImageAffineWarpD_ARGB16F(src, dest, tempBuffer, transform, &bg, flags);
        },
        [2]f16 => blk: {
            const bg = halfBits2(backColor.*);
            break :blk c.vImageAffineWarpD_CbCr16F(src, dest, tempBuffer, transform, &bg, flags);
        },
        else => @compileError("affineWarpD supports only: " ++ "`Pixel_8`, `Pixel_F`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `[2]f16`"),
    });
}

/// Apply a `CGAffineTransform`-shaped affine warp to an image.
///
/// The narrowest of the three: vImage never added the 16F or CbCr formats to
/// this spelling.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`.
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageAffineWarpCG_Planar8(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_F => c.vImageAffineWarpCG_PlanarF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_8888 => c.vImageAffineWarpCG_ARGB8888(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_FFFF => c.vImageAffineWarpCG_ARGBFFFF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16U => c.vImageAffineWarpCG_ARGB16U(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16S => c.vImageAffineWarpCG_ARGB16S(src, dest, tempBuffer, transform, backColor, flags),
        else => @compileError("affineWarpCG supports only: " ++ "`Pixel_8`, `Pixel_F`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`"),
    });
}

// ============================================================================
// Perspective Warp
// ============================================================================

/// Compute the perspective transform that maps one quadrilateral onto another.
///
/// `srcPoints` and `destPoints` are four corresponding `(x, y)` pairs. Four
/// pairs is exactly what determines a projective transform - three would give
/// an affine one, and the extra pair is what lets the result have vanishing
/// points.
pub fn getPerspectiveWarp(
    srcPoints: *const [4][2]f32,
    destPoints: *const [4][2]f32,
    transform: *vImage_PerspectiveTransform,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageGetPerspectiveWarp(srcPoints, destPoints, transform, flags));
}

/// Apply a perspective (projective) transform to an image.
///
/// Unlike `affineWarp`, this can produce foreshortening: parallel lines in the
/// source need not stay parallel. Build the transform with
/// `getPerspectiveWarp` or fill `vImage_PerspectiveTransform` directly.
///
/// `interpolation` is explicit here because a projective map's sampling
/// density varies across the image, so the choice between nearest and linear
/// matters more than it does for a rigid transform.
///
/// Supported pixel types: `Pixel_8`, `Pixel_16U`, `f16`, `Pixel_8888`, `Pixel_ARGB_16U`, `[4]f16`.
///
/// Does not work in place.
pub fn perspectiveWarp(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    transform: *const vImage_PerspectiveTransform,
    interpolation: WarpInterpolation,
    backColor: BackColor(T),
    flags: vImage_Flags,
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImagePerspectiveWarp_Planar8(src, dest, tempBuffer, transform, interpolation, backColor, flags),
        Pixel_16U => c.vImagePerspectiveWarp_Planar16U(src, dest, tempBuffer, transform, interpolation, backColor, flags),
        f16 => c.vImagePerspectiveWarp_Planar16F(src, dest, tempBuffer, transform, interpolation, halfBits(backColor), flags),
        Pixel_8888 => c.vImagePerspectiveWarp_ARGB8888(src, dest, tempBuffer, transform, interpolation, backColor, flags),
        Pixel_ARGB_16U => c.vImagePerspectiveWarp_ARGB16U(src, dest, tempBuffer, transform, interpolation, backColor, flags),
        [4]f16 => blk: {
            const bg = halfBits4(backColor.*);
            break :blk c.vImagePerspectiveWarp_ARGB16F(src, dest, tempBuffer, transform, interpolation, &bg, flags);
        },
        else => @compileError("perspectiveWarp supports only: " ++ "`Pixel_8`, `Pixel_16U`, `f16`, `Pixel_8888`, `Pixel_ARGB_16U`, `[4]f16`"),
    });
}

// ============================================================================
// Shear
// ============================================================================

/// Apply a horizontal shear, rescale, and translate to an image.
///
/// The shear slope corresponds to the off-diagonal element (0,1) of an
/// equivalent affine transform matrix. A `ResamplingFilter` must be created
/// with `newResamplingFilter` first.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_16U`, `Pixel_16S`, `f16`, `Pixel_32U`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `Pixel_88`, `Pixel_16U16U`, `Pixel_16S16S`, `[2]f16`.
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageHorizontalShear_Planar8(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_F => c.vImageHorizontalShear_PlanarF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_16U => c.vImageHorizontalShear_Planar16U(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_16S => c.vImageHorizontalShear_Planar16S(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        f16 => c.vImageHorizontalShear_Planar16F(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, halfBits(backColor), flags),
        Pixel_32U => c.vImageHorizontalShear_XRGB2101010W(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_8888 => c.vImageHorizontalShear_ARGB8888(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_FFFF => c.vImageHorizontalShear_ARGBFFFF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16U => c.vImageHorizontalShear_ARGB16U(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16S => c.vImageHorizontalShear_ARGB16S(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        [4]f16 => blk: {
            const bg = halfBits4(backColor.*);
            break :blk c.vImageHorizontalShear_ARGB16F(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, &bg, flags);
        },
        Pixel_88 => c.vImageHorizontalShear_CbCr8(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_16U16U => c.vImageHorizontalShear_CbCr16U(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_16S16S => c.vImageHorizontalShear_CbCr16S(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        [2]f16 => blk: {
            const bg = halfBits2(backColor.*);
            break :blk c.vImageHorizontalShear_CbCr16F(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, &bg, flags);
        },
        else => @compileError("horizontalShear supports only: " ++ "`Pixel_8`, `Pixel_F`, `Pixel_16U`, `Pixel_16S`, `f16`, `Pixel_32U`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `Pixel_88`, `Pixel_16U16U`, `Pixel_16S16S`, `[2]f16`"),
    });
}

/// Apply a vertical shear, rescale, and translate to an image.
///
/// The shear slope corresponds to the off-diagonal element (1,0) of an
/// equivalent affine transform matrix.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `Pixel_16U`, `Pixel_16S`, `f16`, `Pixel_32U`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `Pixel_88`, `Pixel_16U16U`, `Pixel_16S16S`, `[2]f16`.
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageVerticalShear_Planar8(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_F => c.vImageVerticalShear_PlanarF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_16U => c.vImageVerticalShear_Planar16U(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_16S => c.vImageVerticalShear_Planar16S(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        f16 => c.vImageVerticalShear_Planar16F(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, halfBits(backColor), flags),
        Pixel_32U => c.vImageVerticalShear_XRGB2101010W(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_8888 => c.vImageVerticalShear_ARGB8888(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_FFFF => c.vImageVerticalShear_ARGBFFFF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16U => c.vImageVerticalShear_ARGB16U(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16S => c.vImageVerticalShear_ARGB16S(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        [4]f16 => blk: {
            const bg = halfBits4(backColor.*);
            break :blk c.vImageVerticalShear_ARGB16F(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, &bg, flags);
        },
        Pixel_88 => c.vImageVerticalShear_CbCr8(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_16U16U => c.vImageVerticalShear_CbCr16U(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_16S16S => c.vImageVerticalShear_CbCr16S(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        [2]f16 => blk: {
            const bg = halfBits2(backColor.*);
            break :blk c.vImageVerticalShear_CbCr16F(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, &bg, flags);
        },
        else => @compileError("verticalShear supports only: " ++ "`Pixel_8`, `Pixel_F`, `Pixel_16U`, `Pixel_16S`, `f16`, `Pixel_32U`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `Pixel_88`, `Pixel_16U16U`, `Pixel_16S16S`, `[2]f16`"),
    });
}

/// `horizontalShear` with a double-precision translate and slope.
///
/// Only the two scalars widen; the pixels, the filter and the background
/// colour are unchanged. Worth reaching for when the shear is one step of a
/// composed transform and the parameters were computed in double.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `Pixel_16U16U`, `Pixel_16S16S`, `[2]f16`.
///
/// Does not work in place.
pub fn horizontalShearD(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    xTranslate: f64,
    shearSlope: f64,
    filter: ResamplingFilter,
    backColor: BackColor(T),
    flags: vImage_Flags,
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageHorizontalShearD_Planar8(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_F => c.vImageHorizontalShearD_PlanarF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        f16 => c.vImageHorizontalShearD_Planar16F(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, halfBits(backColor), flags),
        Pixel_8888 => c.vImageHorizontalShearD_ARGB8888(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_FFFF => c.vImageHorizontalShearD_ARGBFFFF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16U => c.vImageHorizontalShearD_ARGB16U(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16S => c.vImageHorizontalShearD_ARGB16S(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        [4]f16 => blk: {
            const bg = halfBits4(backColor.*);
            break :blk c.vImageHorizontalShearD_ARGB16F(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, &bg, flags);
        },
        Pixel_16U16U => c.vImageHorizontalShearD_CbCr16U(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_16S16S => c.vImageHorizontalShearD_CbCr16S(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        [2]f16 => blk: {
            const bg = halfBits2(backColor.*);
            break :blk c.vImageHorizontalShearD_CbCr16F(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, &bg, flags);
        },
        else => @compileError("horizontalShearD supports only: " ++ "`Pixel_8`, `Pixel_F`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `Pixel_16U16U`, `Pixel_16S16S`, `[2]f16`"),
    });
}

/// `verticalShear` with a double-precision translate and slope.
///
/// Supported pixel types: `Pixel_8`, `Pixel_F`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `Pixel_16U16U`, `Pixel_16S16S`, `[2]f16`.
///
/// Does not work in place.
pub fn verticalShearD(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    yTranslate: f64,
    shearSlope: f64,
    filter: ResamplingFilter,
    backColor: BackColor(T),
    flags: vImage_Flags,
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageVerticalShearD_Planar8(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_F => c.vImageVerticalShearD_PlanarF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        f16 => c.vImageVerticalShearD_Planar16F(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, halfBits(backColor), flags),
        Pixel_8888 => c.vImageVerticalShearD_ARGB8888(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_FFFF => c.vImageVerticalShearD_ARGBFFFF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16U => c.vImageVerticalShearD_ARGB16U(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16S => c.vImageVerticalShearD_ARGB16S(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        [4]f16 => blk: {
            const bg = halfBits4(backColor.*);
            break :blk c.vImageVerticalShearD_ARGB16F(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, &bg, flags);
        },
        Pixel_16U16U => c.vImageVerticalShearD_CbCr16U(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_16S16S => c.vImageVerticalShearD_CbCr16S(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        [2]f16 => blk: {
            const bg = halfBits2(backColor.*);
            break :blk c.vImageVerticalShearD_CbCr16F(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, &bg, flags);
        },
        else => @compileError("verticalShearD supports only: " ++ "`Pixel_8`, `Pixel_F`, `f16`, `Pixel_8888`, `Pixel_FFFF`, `Pixel_ARGB_16U`, `Pixel_ARGB_16S`, `[4]f16`, `Pixel_16U16U`, `Pixel_16S16S`, `[2]f16`"),
    });
}

// ============================================================================
// Resampling Filter
// ============================================================================

/// Create a resampling filter for the shear functions.
///
/// `scale_factor` is the magnification: 1.0 keeps the size, 2.0 doubles it,
/// 0.5 halves it, and a negative value flips the axis.
///
/// Set `kvImageHighQualityResampling` in flags for a Lanczos5 kernel;
/// otherwise Lanczos3 is used. Which kernel Apple picks is documented as
/// subject to change - use `newResamplingFilterForFunction` if the exact
/// shape matters.
///
/// Destroy the result with `destroyResamplingFilter`.
pub fn newResamplingFilter(scale_factor: f32, flags: vImage_Flags) ResamplingFilter {
    return c.vImageNewResamplingFilter(scale_factor, flags);
}

/// Destroy a resampling filter previously created with `newResamplingFilter`.
///
/// Not for a filter built by `newResamplingFilterForFunction`: that one lives
/// in caller-owned memory and needs no destruction, just a buffer that
/// outlives its use.
pub fn destroyResamplingFilter(filter: ResamplingFilter) void {
    c.vImageDestroyResamplingFilter(filter);
}

/// Bytes `newResamplingFilterForFunction` needs for a filter with this scale
/// and kernel width.
///
/// Note that `kernelFunc` is a parameter: the size depends on the kernel, not
/// only on the numbers, so passing a different function here than to the
/// build call is a way to under-allocate.
pub fn resamplingFilterSize(scale_factor: f32, kernelFunc: KernelFunc, kernelWidth: f32, flags: vImage_Flags) usize {
    return c.vImageGetResamplingFilterSize(scale_factor, kernelFunc, kernelWidth, flags);
}

/// The maximum sampling radius of an existing filter: how far, in source
/// pixels, it reaches from the point being sampled.
///
/// This is the halo a tiled caller has to add to each tile's source region.
/// `flags` should be the flags you intend to pass to the shear call, since
/// they can change the sampling.
///
/// Note this takes the *filter*, not the parameters it was built from -
/// unlike `resamplingFilterSize`, which takes the parameters because it is
/// what you call before you have a filter. Getting these two the same way
/// round is the natural mistake: the wrong signature still links, and returns
/// zero rather than failing.
pub fn resamplingFilterExtent(filter: ResamplingFilter, flags: vImage_Flags) vImagePixelCount {
    return c.vImageGetResamplingFilterExtent(filter, flags);
}

/// Build a resampling filter with a caller-supplied kernel shape, in
/// caller-supplied memory.
///
/// `buffer` must be at least `resamplingFilterSize(...)` bytes for the same
/// `scale_factor`, `kernelFunc` and `kernelWidth`, and must outlive every use
/// of the returned filter. `userData` is passed through to `kernelFunc`
/// untouched.
///
/// The two reasons to use this over `newResamplingFilter`: the kernel is yours
/// rather than "Lanczos3 or Lanczos5, subject to change", and the allocation
/// is yours rather than vImage's.
pub fn newResamplingFilterForFunction(
    buffer: []align(@alignOf(usize)) u8,
    scale_factor: f32,
    kernelFunc: KernelFunc,
    kernelWidth: f32,
    userData: ?*anyopaque,
    flags: vImage_Flags,
) VImageError!ResamplingFilter {
    std.debug.assert(buffer.len >= resamplingFilterSize(scale_factor, kernelFunc, kernelWidth, flags));
    const filter: ResamplingFilter = @ptrCast(buffer.ptr);
    _ = try check(c.vImageNewResamplingFilterForFunctionUsingBuffer(filter, scale_factor, kernelFunc, kernelWidth, userData, flags));
    return filter;
}

// ============================================================================
// Tests
// ============================================================================
//
// Buffers use padded rowBytes (rowBytes > width*bytesPerPixel) throughout so
// a wrapper that assumed tight packing would fail. A single bright "marker"
// pixel against a zero background is used to track exactly where geometry
// operations move a known point, which is a more direct runtime check than
// eyeballing a whole transformed image.

fn makePlanar8Buffer(allocator: std.mem.Allocator, height: usize, width: usize, row_pad: usize) !struct { buf: vImage_Buffer, mem: []u8 } {
    const row_bytes = width + row_pad;
    const mem = try allocator.alloc(u8, row_bytes * height);
    @memset(mem, 0);
    return .{ .buf = .{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes }, .mem = mem };
}

fn setPlanar8(buf: vImage_Buffer, y: usize, x: usize, v: u8) void {
    const base: [*]u8 = @ptrCast(buf.data.?);
    base[y * buf.rowBytes + x] = v;
}

fn getPlanar8(buf: vImage_Buffer, y: usize, x: usize) u8 {
    const base: [*]u8 = @ptrCast(buf.data.?);
    return base[y * buf.rowBytes + x];
}

/// Find the (y, x) of the single brightest (nonzero) pixel in a Planar8
/// buffer. Panics if none found -- tests using this expect exactly one
/// marker pixel to have survived the transform.
fn findMarker(buf: vImage_Buffer) struct { y: usize, x: usize, v: u8 } {
    var best_y: usize = 0;
    var best_x: usize = 0;
    var best_v: u8 = 0;
    for (0..buf.height) |y| {
        for (0..buf.width) |x| {
            const v = getPlanar8(buf, y, x);
            if (v > best_v) {
                best_v = v;
                best_y = y;
                best_x = x;
            }
        }
    }
    return .{ .y = best_y, .x = best_x, .v = best_v };
}

test "horizontalReflect_Planar8: mirrors columns (x), not rows" {
    // 3x5 image (non-square so a row/col mixup can't hide), marker at
    // (row=0, col=1). Horizontal (left-right) reflect should move it to
    // (row=0, col=width-1-1=3), i.e. the row is untouched and only the
    // column mirrors.
    const allocator = std.testing.allocator;
    var src = try makePlanar8Buffer(allocator, 3, 5, 2);
    defer allocator.free(src.mem);
    setPlanar8(src.buf, 0, 1, 200);
    var dest = try makePlanar8Buffer(allocator, 3, 5, 3);
    defer allocator.free(dest.mem);

    const err = horizontalReflect(Pixel_8, &src.buf, &dest.buf, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    const marker = findMarker(dest.buf);
    try std.testing.expectEqual(@as(usize, 0), marker.y);
    try std.testing.expectEqual(@as(usize, 3), marker.x);
}

test "verticalReflect_Planar8: mirrors rows (y), not columns" {
    // Complementary check to horizontalReflect: marker at (row=1, col=0) in
    // a 5x3 image. Vertical (top-bottom) reflect should move it to
    // (row=height-1-1=3, col=0) -- column untouched, only the row mirrors.
    const allocator = std.testing.allocator;
    var src = try makePlanar8Buffer(allocator, 5, 3, 2);
    defer allocator.free(src.mem);
    setPlanar8(src.buf, 1, 0, 200);
    var dest = try makePlanar8Buffer(allocator, 5, 3, 3);
    defer allocator.free(dest.mem);

    const err = verticalReflect(Pixel_8, &src.buf, &dest.buf, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    const marker = findMarker(dest.buf);
    try std.testing.expectEqual(@as(usize, 3), marker.y);
    try std.testing.expectEqual(@as(usize, 0), marker.x);
}

test "rotate90: RotationConstant values match Geometry.h's kRotate*DegreesClockwise/CounterClockwise enum" {
    // Geometry.h:
    //   kRotate0DegreesClockwise = 0,   kRotate90DegreesClockwise = 3,
    //   kRotate180DegreesClockwise = 2, kRotate270DegreesClockwise = 1,
    //   kRotate0DegreesCounterClockwise = 0, kRotate90DegreesCounterClockwise = 1,
    //   kRotate180DegreesCounterClockwise = 2, kRotate270DegreesCounterClockwise = 3.
    // RotationConstant's declared values (rotate_0=0, rotate_90_ccw=1,
    // rotate_180=2, rotate_270_ccw=3) already match this numbering, and its
    // rotate_90_cw/rotate_270_cw aliases point at rotate_270_ccw(3)/
    // rotate_90_ccw(1) respectively -- also matching. Confirm at runtime
    // with a non-square (3 rows x 5 cols) image and a marker near one
    // corner, which pins down both axes simultaneously (a 180 rotation
    // would look identical to a correct 90 if we used a symmetric image).
    const allocator = std.testing.allocator;
    // marker at (row=0, col=0) -- the actual "corner" is unambiguous for all 4 rotations.
    var src = try makePlanar8Buffer(allocator, 3, 5, 1);
    defer allocator.free(src.mem);
    setPlanar8(src.buf, 0, 0, 200);

    const Case = struct { rc: RotationConstant, dest_h: usize, dest_w: usize, exp_y: usize, exp_x: usize };
    // 90-degree rotations swap height/width; a corner marker at (0,0) maps
    // to a different corner of the *new* dimensions depending on direction.
    const cases = [_]Case{
        .{ .rc = .rotate_0, .dest_h = 3, .dest_w = 5, .exp_y = 0, .exp_x = 0 },
        .{ .rc = .rotate_180, .dest_h = 3, .dest_w = 5, .exp_y = 2, .exp_x = 4 },
        // 90 CCW: top-left corner of src maps to bottom-left corner of dest.
        .{ .rc = .rotate_90_ccw, .dest_h = 5, .dest_w = 3, .exp_y = 4, .exp_x = 0 },
        // 270 CCW (== 90 CW): top-left corner of src maps to top-right corner of dest.
        .{ .rc = .rotate_270_ccw, .dest_h = 5, .dest_w = 3, .exp_y = 0, .exp_x = 2 },
    };
    for (cases) |case| {
        var dest = try makePlanar8Buffer(allocator, case.dest_h, case.dest_w, 2);
        defer allocator.free(dest.mem);
        const err = rotate90(Pixel_8, &src.buf, &dest.buf, case.rc, 0, Flags.kvImageNoFlags);
        try std.testing.expectEqual(@as(usize, 0), try err);
        const marker = findMarker(dest.buf);
        try std.testing.expectEqual(case.exp_y, marker.y);
        try std.testing.expectEqual(case.exp_x, marker.x);
    }
    // Cross-check the documented CW aliases point at the same numeric
    // enum values as the CCW constants Geometry.h declares them equal to.
    try std.testing.expectEqual(RotationConstant.rotate_270_ccw, RotationConstant.rotate_90_cw);
    try std.testing.expectEqual(RotationConstant.rotate_90_ccw, RotationConstant.rotate_270_cw);
}

test "affineWarp: pure translation (a=1,b=0,c=0,d=1) shifts by exactly (tx,ty) pixels, runtime-confirmed axis mapping" {
    // Geometry.h: (x',y') = (x,y)*[[a,b],[c,d]] + (tx,ty), origin bottom-left,
    // +x right, +y up. With a=d=1, b=c=0 this reduces to a pure translation
    // (x'=x+tx, y'=y+ty). This test lets runtime execution determine how
    // "+x"/"+y" in that coordinate space map onto the buffer's (row, col)
    // indexing (row-major, row 0 first in memory) rather than assuming it:
    // where the header is silent, this suite measures rather than guesses.
    const allocator = std.testing.allocator;
    var src = try makePlanar8Buffer(allocator, 5, 5, 2);
    defer allocator.free(src.mem);
    setPlanar8(src.buf, 2, 2, 200); // center marker
    var dest = try makePlanar8Buffer(allocator, 5, 5, 3);
    defer allocator.free(dest.mem);

    const transform = vImage_AffineTransform{ .a = 1, .b = 0, .c = 0, .d = 1, .tx = 1, .ty = 0 };
    const err = affineWarp(Pixel_8, &src.buf, &dest.buf, null, &transform, 0, Flags.kvImageBackgroundColorFill);
    try std.testing.expectEqual(@as(usize, 0), try err);
    const marker = findMarker(dest.buf);
    try std.testing.expectEqual(@as(u8, 200), marker.v);
    // Runtime-confirmed: tx=1 moved the marker from col=2 to col=3 (row
    // unchanged) -- +x is +1 column, the unsurprising direction.
    try std.testing.expectEqual(@as(usize, 2), marker.y);
    try std.testing.expectEqual(@as(usize, 3), marker.x);

    // Now ty=1 with tx=0: must move along the *other* axis only.
    var dest2 = try makePlanar8Buffer(allocator, 5, 5, 1);
    defer allocator.free(dest2.mem);
    const transform2 = vImage_AffineTransform{ .a = 1, .b = 0, .c = 0, .d = 1, .tx = 0, .ty = 1 };
    const err2 = affineWarp(Pixel_8, &src.buf, &dest2.buf, null, &transform2, 0, Flags.kvImageBackgroundColorFill);
    try std.testing.expectEqual(@as(usize, 0), try err2);
    const marker2 = findMarker(dest2.buf);
    try std.testing.expectEqual(@as(u8, 200), marker2.v);
    // Runtime-confirmed: ty=1 moved the marker from row=2 to row=1 (col
    // unchanged), i.e. +y (math-space "up", per Geometry.h's documented
    // bottom-left-origin coordinate space) corresponds to a *decreasing*
    // buffer row index -- row 0 is the visual top of the image, consistent
    // with standard raster (row-major, top row first) storage combined
    // with the header's bottom-left/+y-up transform coordinate space.
    try std.testing.expectEqual(@as(usize, 1), marker2.y);
    try std.testing.expectEqual(@as(usize, 2), marker2.x);
}

test "affineWarpD: matches affineWarp for an equivalent single/double-precision transform" {
    const allocator = std.testing.allocator;
    var src = try makePlanar8Buffer(allocator, 5, 5, 2);
    defer allocator.free(src.mem);
    setPlanar8(src.buf, 2, 2, 200);

    var dest_f = try makePlanar8Buffer(allocator, 5, 5, 1);
    defer allocator.free(dest_f.mem);
    const tf = vImage_AffineTransform{ .a = 1, .b = 0, .c = 0, .d = 1, .tx = 1, .ty = 0 };
    const err_f = affineWarp(Pixel_8, &src.buf, &dest_f.buf, null, &tf, 0, Flags.kvImageBackgroundColorFill);
    try std.testing.expectEqual(@as(usize, 0), try err_f);

    var dest_d = try makePlanar8Buffer(allocator, 5, 5, 3);
    defer allocator.free(dest_d.mem);
    const td = vImage_AffineTransform_Double{ .a = 1, .b = 0, .c = 0, .d = 1, .tx = 1, .ty = 0 };
    const err_d = affineWarpD(Pixel_8, &src.buf, &dest_d.buf, null, &td, 0, Flags.kvImageBackgroundColorFill);
    try std.testing.expectEqual(@as(usize, 0), try err_d);

    const marker_f = findMarker(dest_f.buf);
    const marker_d = findMarker(dest_d.buf);
    try std.testing.expectEqual(marker_f.y, marker_d.y);
    try std.testing.expectEqual(marker_f.x, marker_d.x);
    try std.testing.expectEqual(marker_f.v, marker_d.v);
}

test "affineWarpCG: matches affineWarp for an equivalent transform (vImage_CGAffineTransform is the Double layout)" {
    const allocator = std.testing.allocator;
    var src = try makePlanar8Buffer(allocator, 5, 5, 1);
    defer allocator.free(src.mem);
    setPlanar8(src.buf, 2, 2, 200);

    var dest_f = try makePlanar8Buffer(allocator, 5, 5, 2);
    defer allocator.free(dest_f.mem);
    const tf = vImage_AffineTransform{ .a = 1, .b = 0, .c = 0, .d = 1, .tx = 1, .ty = 0 };
    const err_f = affineWarp(Pixel_8, &src.buf, &dest_f.buf, null, &tf, 0, Flags.kvImageBackgroundColorFill);
    try std.testing.expectEqual(@as(usize, 0), try err_f);

    var dest_cg = try makePlanar8Buffer(allocator, 5, 5, 3);
    defer allocator.free(dest_cg.mem);
    const tcg = vImage_CGAffineTransform{ .a = 1, .b = 0, .c = 0, .d = 1, .tx = 1, .ty = 0 };
    const err_cg = affineWarpCG(Pixel_8, &src.buf, &dest_cg.buf, null, &tcg, 0, Flags.kvImageBackgroundColorFill);
    try std.testing.expectEqual(@as(usize, 0), try err_cg);

    const marker_f = findMarker(dest_f.buf);
    const marker_cg = findMarker(dest_cg.buf);
    try std.testing.expectEqual(marker_f.y, marker_cg.y);
    try std.testing.expectEqual(marker_f.x, marker_cg.x);
}

test "rotate: positive angleInRadians is a standard mathematical CCW rotation (runtime-confirmed sign convention)" {
    // Geometry.h documents the parameter name as `angleInRadians` (no
    // separate degrees variant exists for vImageRotate_<fmt>), so degrees
    // vs radians is settled by the parameter's own name. The *sign*
    // convention (CW vs CCW) is not documented in prose anywhere in
    // Geometry.h, so runtime execution is the only evidence available.
    //
    // 9x9 image, center at (row=4,col=4). Marker at (row=4,col=7): offset
    // from center is (drow=0, dcol=+3). affineWarp's already-confirmed
    // coordinate convention (this file) is world x=+col, world y=-row
    // (Geometry.h's "+y is up" combined with row-major, row-0-first
    // buffer storage). Under that convention this marker sits at world
    // (x=+3, y=0). A standard CCW rotation by +30 degrees maps
    // (x,y) -> (x*cos30 - y*sin30, x*sin30 + y*cos30) = (2.598, 1.5),
    // i.e. world y increases (+1.5) which is buffer row *decreasing* by
    // 1.5 (row ~2.5), and world x increases to ~6.6 (col ~6.6). Runtime
    // output's energy peak (v=125, the brightest destination pixel) lands
    // at exactly (row=3, col=6) with (row=2,col=6)/(row=2,col=7)/
    // (row=3,col=7) also lit up around it -- centered almost exactly on
    // the (row=2.5, col=6.6) prediction, confirming +angleInRadians is a
    // standard CCW rotation in this coordinate convention, not CW.
    const allocator = std.testing.allocator;
    var src = try makePlanar8Buffer(allocator, 9, 9, 2);
    defer allocator.free(src.mem);
    setPlanar8(src.buf, 4, 7, 200);
    var dest = try makePlanar8Buffer(allocator, 9, 9, 1);
    defer allocator.free(dest.mem);

    const err = rotate(Pixel_8, &src.buf, &dest.buf, null, std.math.pi / 6.0, 0, Flags.kvImageBackgroundColorFill);
    try std.testing.expectEqual(@as(usize, 0), try err);
    const marker = findMarker(dest.buf);
    try std.testing.expectEqual(@as(usize, 3), marker.y);
    try std.testing.expectEqual(@as(usize, 6), marker.x);
    try std.testing.expectEqual(@as(u8, 125), marker.v);
}

test "scale: resizes to the destination buffer's dimensions" {
    const allocator = std.testing.allocator;
    var src = try makePlanar8Buffer(allocator, 4, 4, 1);
    defer allocator.free(src.mem);
    for (0..4) |y| for (0..4) |x| {
        setPlanar8(src.buf, y, x, 100);
    };
    var dest = try makePlanar8Buffer(allocator, 2, 2, 2);
    defer allocator.free(dest.mem);

    const err = scale(Pixel_8, &src.buf, &dest.buf, null, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    // Uniform input -> uniform (approximately, resampled) output; the key
    // check is that the call succeeds and writes into the *dest*-sized
    // buffer (2x2) using dest's own rowBytes, not src's.
    for (0..2) |y| for (0..2) |x| {
        try std.testing.expect(getPlanar8(dest.buf, y, x) > 0);
    };
}

test "newResamplingFilter/destroyResamplingFilter: create-use-destroy lifecycle, and horizontalShear/verticalShear axis mapping" {
    const allocator = std.testing.allocator;
    const filter = newResamplingFilter(1.0, Flags.kvImageNoFlags);
    try std.testing.expect(filter != null);
    defer destroyResamplingFilter(filter);

    var src = try makePlanar8Buffer(allocator, 5, 5, 2);
    defer allocator.free(src.mem);
    setPlanar8(src.buf, 2, 2, 200);

    // horizontalShear with shearSlope=0 (no shear) and xTranslate=1 behaves
    // like a pure x-translation -- confirms the filter round-trips through
    // a real shear call and that "horizontal" moves columns not rows.
    var dest_h = try makePlanar8Buffer(allocator, 5, 5, 1);
    defer allocator.free(dest_h.mem);
    const err_h = horizontalShear(Pixel_8, &src.buf, &dest_h.buf, 0, 0, 1, 0, filter, 0, Flags.kvImageBackgroundColorFill);
    try std.testing.expectEqual(@as(usize, 0), try err_h);
    const marker_h = findMarker(dest_h.buf);
    // Runtime-confirmed: col 2 -> 3 (row unchanged), matching affineWarp's
    // tx=+1 result above -- xTranslate moves the same direction as +tx.
    try std.testing.expectEqual(@as(usize, 2), marker_h.y);
    try std.testing.expectEqual(@as(usize, 3), marker_h.x);

    // verticalShear with shearSlope=0 and yTranslate=1: "vertical" moves rows not columns.
    var dest_v = try makePlanar8Buffer(allocator, 5, 5, 3);
    defer allocator.free(dest_v.mem);
    const err_v = verticalShear(Pixel_8, &src.buf, &dest_v.buf, 0, 0, 1, 0, filter, 0, Flags.kvImageBackgroundColorFill);
    try std.testing.expectEqual(@as(usize, 0), try err_v);
    const marker_v = findMarker(dest_v.buf);
    // Runtime-confirmed: row 2 -> 1 (col unchanged), matching affineWarp's
    // ty=+1 result (+y-up == decreasing row index) -- yTranslate moves the
    // same direction as +ty, not the opposite.
    try std.testing.expectEqual(@as(usize, 1), marker_v.y);
    try std.testing.expectEqual(@as(usize, 2), marker_v.x);
}

// ---------------------------------------------------------------------------
// Perspective warp, the D-suffixed shears, and the wider format set
// ---------------------------------------------------------------------------

fn makePlanar16FBuffer(allocator: std.mem.Allocator, height: usize, width: usize, row_pad: usize) !struct { buf: vImage_Buffer, mem: []f16 } {
    const row_elems = width + row_pad;
    const mem = try allocator.alloc(f16, row_elems * height);
    @memset(mem, 0);
    return .{ .buf = .{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_elems * @sizeOf(f16) }, .mem = mem };
}

fn getPlanar16F(buf: vImage_Buffer, y: usize, x: usize) f16 {
    const base: [*]u8 = @ptrCast(buf.data.?);
    const row: [*]f16 = @ptrCast(@alignCast(base + y * buf.rowBytes));
    return row[x];
}

fn setPlanar16F(buf: vImage_Buffer, y: usize, x: usize, v: f16) void {
    const base: [*]u8 = @ptrCast(buf.data.?);
    const row: [*]f16 = @ptrCast(@alignCast(base + y * buf.rowBytes));
    row[x] = v;
}

test "getPerspectiveWarp: the identity quadrilateral gives the identity transform" {
    // Four corners mapped to themselves. `v` is the homogeneous scale and
    // must come back as 1, with the projective vector zero - a perspective
    // transform with vx = vy = 0 and v = 1 is exactly an affine one.
    const pts = [4][2]f32{ .{ 0, 0 }, .{ 4, 0 }, .{ 4, 4 }, .{ 0, 4 } };
    var t: vImage_PerspectiveTransform = undefined;
    _ = try getPerspectiveWarp(&pts, &pts, &t, Flags.kvImageNoFlags);

    try std.testing.expectApproxEqAbs(@as(f32, 1), t.a, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0), t.b, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0), t.c, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 1), t.d, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0), t.tx, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0), t.ty, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0), t.vx, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 0), t.vy, 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 1), t.v, 1e-5);
}

test "perspectiveWarp: a translation-only transform moves the marker like affineWarp" {
    // The point of running a *degenerate* perspective transform - vx = vy = 0,
    // v = 1, so it reduces to an affine one - is that the answer is already
    // known from the affineWarp tests above. That pins the field order of
    // vImage_PerspectiveTransform, which is the thing most likely to be wrong
    // and least likely to show up as an error code.
    const allocator = std.testing.allocator;
    var src = try makePlanar8Buffer(allocator, 5, 5, 2);
    defer allocator.free(src.mem);
    setPlanar8(src.buf, 2, 2, 200);

    var dest = try makePlanar8Buffer(allocator, 5, 5, 1);
    defer allocator.free(dest.mem);

    const t = vImage_PerspectiveTransform{
        .a = 1,
        .b = 0,
        .c = 0,
        .d = 1,
        .tx = 1,
        .ty = 0,
        .vx = 0,
        .vy = 0,
        .v = 1,
    };
    _ = try perspectiveWarp(Pixel_8, &src.buf, &dest.buf, null, &t, .nearest, 0, Flags.kvImageBackgroundColorFill);

    const marker = findMarker(dest.buf);
    try std.testing.expectEqual(@as(usize, 2), marker.y);
    try std.testing.expectEqual(@as(usize, 3), marker.x);
}

test "perspectiveWarp: linear interpolation spreads a marker that nearest keeps sharp" {
    // Distinguishes the two interpolation modes by their effect rather than by
    // the enum value, so a swapped mapping would fail. A half-pixel shift is
    // exactly the case where nearest snaps and linear splits.
    const allocator = std.testing.allocator;
    var src = try makePlanar8Buffer(allocator, 5, 5, 2);
    defer allocator.free(src.mem);
    setPlanar8(src.buf, 2, 2, 200);

    const t = vImage_PerspectiveTransform{
        .a = 1,
        .b = 0,
        .c = 0,
        .d = 1,
        .tx = 0.5,
        .ty = 0,
        .vx = 0,
        .vy = 0,
        .v = 1,
    };

    var sharp = try makePlanar8Buffer(allocator, 5, 5, 1);
    defer allocator.free(sharp.mem);
    _ = try perspectiveWarp(Pixel_8, &src.buf, &sharp.buf, null, &t, .nearest, 0, Flags.kvImageBackgroundColorFill);

    var soft = try makePlanar8Buffer(allocator, 5, 5, 1);
    defer allocator.free(soft.mem);
    _ = try perspectiveWarp(Pixel_8, &src.buf, &soft.buf, null, &t, .linear, 0, Flags.kvImageBackgroundColorFill);

    // Nearest keeps the full 200 somewhere; linear cannot, because half of it
    // has gone to the neighbouring column.
    try std.testing.expectEqual(@as(u8, 200), findMarker(sharp.buf).v);
    try std.testing.expect(findMarker(soft.buf).v < 200);
}

test "horizontalShearD and verticalShearD agree with the f32 versions" {
    // The D variants differ only in the precision of `xTranslate`/`shearSlope`.
    // Given integer parameters both must produce identical images - if the
    // wrapper passed a float where a double is expected the arguments would
    // land in the wrong registers and this would not merely be imprecise.
    const allocator = std.testing.allocator;
    const filter = newResamplingFilter(1.0, Flags.kvImageNoFlags);
    try std.testing.expect(filter != null);
    defer destroyResamplingFilter(filter);

    var src = try makePlanar8Buffer(allocator, 5, 5, 2);
    defer allocator.free(src.mem);
    setPlanar8(src.buf, 2, 2, 200);

    var single = try makePlanar8Buffer(allocator, 5, 5, 1);
    defer allocator.free(single.mem);
    var double = try makePlanar8Buffer(allocator, 5, 5, 3);
    defer allocator.free(double.mem);

    _ = try horizontalShear(Pixel_8, &src.buf, &single.buf, 0, 0, 1, 0, filter, 0, Flags.kvImageBackgroundColorFill);
    _ = try horizontalShearD(Pixel_8, &src.buf, &double.buf, 0, 0, 1, 0, filter, 0, Flags.kvImageBackgroundColorFill);
    for (0..5) |y| {
        for (0..5) |x| {
            try std.testing.expectEqual(getPlanar8(single.buf, y, x), getPlanar8(double.buf, y, x));
        }
    }

    @memset(single.mem, 0);
    @memset(double.mem, 0);
    _ = try verticalShear(Pixel_8, &src.buf, &single.buf, 0, 0, 1, 0, filter, 0, Flags.kvImageBackgroundColorFill);
    _ = try verticalShearD(Pixel_8, &src.buf, &double.buf, 0, 0, 1, 0, filter, 0, Flags.kvImageBackgroundColorFill);
    for (0..5) |y| {
        for (0..5) |x| {
            try std.testing.expectEqual(getPlanar8(single.buf, y, x), getPlanar8(double.buf, y, x));
        }
    }

    // A slope only a double can hold exactly, to show the parameter is really
    // being read as one. 1/3 in f32 and in f64 differ, so this is a
    // characterization of the D path running, not a claim they agree.
    var fine = try makePlanar8Buffer(allocator, 5, 5, 2);
    defer allocator.free(fine.mem);
    _ = try horizontalShearD(Pixel_8, &src.buf, &fine.buf, 0, 0, 0, 1.0 / 3.0, filter, 0, Flags.kvImageBackgroundColorFill);
    try std.testing.expect(findMarker(fine.buf).v > 0);
}

test "the 16F formats: half-precision pixels through reflect, rotate90 and shear" {
    // These three exercise the f16 pixel key, the scalar half background
    // colour, and a format vImage only added to Geometry in macOS 13.
    const allocator = std.testing.allocator;

    var src = try makePlanar16FBuffer(allocator, 3, 5, 2);
    defer allocator.free(src.mem);
    setPlanar16F(src.buf, 0, 1, 8.0);

    {
        var dest = try makePlanar16FBuffer(allocator, 3, 5, 1);
        defer allocator.free(dest.mem);
        _ = try horizontalReflect(f16, &src.buf, &dest.buf, Flags.kvImageNoFlags);
        // Column 1 of 5 mirrors to column 3; the row is untouched.
        try std.testing.expectApproxEqAbs(@as(f16, 8.0), getPlanar16F(dest.buf, 0, 3), 0.01);
    }
    {
        var dest = try makePlanar16FBuffer(allocator, 3, 5, 1);
        defer allocator.free(dest.mem);
        _ = try verticalReflect(f16, &src.buf, &dest.buf, Flags.kvImageNoFlags);
        // Row 0 of 3 mirrors to row 2; the column is untouched.
        try std.testing.expectApproxEqAbs(@as(f16, 8.0), getPlanar16F(dest.buf, 2, 1), 0.01);
    }
    {
        // 180 degrees is the one rotation that keeps a 3x5 image 3x5.
        var dest = try makePlanar16FBuffer(allocator, 3, 5, 1);
        defer allocator.free(dest.mem);
        _ = try rotate90(f16, &src.buf, &dest.buf, .rotate_180, 0.0, Flags.kvImageBackgroundColorFill);
        try std.testing.expectApproxEqAbs(@as(f16, 8.0), getPlanar16F(dest.buf, 2, 3), 0.01);
    }
    {
        const filter = newResamplingFilter(1.0, Flags.kvImageNoFlags);
        defer destroyResamplingFilter(filter);
        var dest = try makePlanar16FBuffer(allocator, 3, 5, 1);
        defer allocator.free(dest.mem);
        _ = try horizontalShear(f16, &src.buf, &dest.buf, 0, 0, 1, 0, filter, 0.0, Flags.kvImageBackgroundColorFill);
        try std.testing.expectApproxEqAbs(@as(f16, 8.0), getPlanar16F(dest.buf, 0, 2), 0.01);
    }
}

test "the ARGB16F and CbCr16F formats: pointer background colours converted at the boundary" {
    // `[4]f16` and `[2]f16` are the keys for the interleaved half formats, and
    // their background colours have to be converted element-wise into a local
    // before the pointer is taken. This runs both prongs.
    const allocator = std.testing.allocator;

    {
        const w = 4;
        const h = 3;
        const row_elems = w * 4 + 4;
        const mem = try allocator.alloc(f16, row_elems * h);
        defer allocator.free(mem);
        @memset(mem, 0);
        mem[0 * row_elems + 1 * 4] = 8.0; // (row 0, col 1), channel 0
        const src = vImage_Buffer{ .data = mem.ptr, .height = h, .width = w, .rowBytes = row_elems * @sizeOf(f16) };

        const dmem = try allocator.alloc(f16, row_elems * h);
        defer allocator.free(dmem);
        @memset(dmem, 0);
        const dest = vImage_Buffer{ .data = dmem.ptr, .height = h, .width = w, .rowBytes = row_elems * @sizeOf(f16) };

        _ = try horizontalReflect([4]f16, &src, &dest, Flags.kvImageNoFlags);
        // Column 1 of 4 mirrors to column 2.
        try std.testing.expectApproxEqAbs(@as(f16, 8.0), dmem[0 * row_elems + 2 * 4], 0.01);

        @memset(dmem, 0);
        const bg = [4]f16{ 1.0, 0.5, 0.25, 0.0 };
        _ = try rotate90([4]f16, &src, &dest, .rotate_180, &bg, Flags.kvImageBackgroundColorFill);
        try std.testing.expectApproxEqAbs(@as(f16, 8.0), dmem[2 * row_elems + 2 * 4], 0.01);
    }
    {
        const w = 4;
        const h = 3;
        const row_elems = w * 2 + 2;
        const mem = try allocator.alloc(f16, row_elems * h);
        defer allocator.free(mem);
        @memset(mem, 0);
        mem[0 * row_elems + 1 * 2] = 8.0;
        const src = vImage_Buffer{ .data = mem.ptr, .height = h, .width = w, .rowBytes = row_elems * @sizeOf(f16) };

        const dmem = try allocator.alloc(f16, row_elems * h);
        defer allocator.free(dmem);
        @memset(dmem, 0);
        const dest = vImage_Buffer{ .data = dmem.ptr, .height = h, .width = w, .rowBytes = row_elems * @sizeOf(f16) };

        const bg = [2]f16{ 0.0, 0.0 };
        _ = try rotate90([2]f16, &src, &dest, .rotate_180, &bg, Flags.kvImageBackgroundColorFill);
        try std.testing.expectApproxEqAbs(@as(f16, 8.0), dmem[2 * row_elems + 2 * 2], 0.01);
    }
}

test "halfBits reinterprets rather than converts" {
    try std.testing.expectEqual(@as(Pixel_16F, 0x3C00), halfBits(1.0));
    try std.testing.expectEqual(@as(Pixel_16F, 0x3800), halfBits(0.5));
    try std.testing.expectEqual(Pixel_ARGB_16F{ 0x3C00, 0x3800, 0, 0 }, halfBits4(.{ 1.0, 0.5, 0.0, 0.0 }));
    try std.testing.expectEqual(Pixel_16F16F{ 0x3C00, 0x3800 }, halfBits2(.{ 1.0, 0.5 }));
}

test "CbCr8 and Planar16U scale through the widened format set" {
    const allocator = std.testing.allocator;

    // Planar16U, which vImageScale has had for a while but which the wrapper
    // now also offers for shear.
    {
        const src_mem = try allocator.alloc(u16, 6 * 4);
        defer allocator.free(src_mem);
        @memset(src_mem, 1000);
        const src = vImage_Buffer{ .data = src_mem.ptr, .height = 4, .width = 4, .rowBytes = 6 * @sizeOf(u16) };

        const dst_mem = try allocator.alloc(u16, 4 * 2);
        defer allocator.free(dst_mem);
        @memset(dst_mem, 0);
        const dest = vImage_Buffer{ .data = dst_mem.ptr, .height = 2, .width = 2, .rowBytes = 4 * @sizeOf(u16) };

        _ = try scale(Pixel_16U, &src, &dest, null, Flags.kvImageHighQualityResampling);
        // A constant image stays constant under any resampling filter.
        try std.testing.expectEqual(@as(u16, 1000), dst_mem[0]);
    }
    // CbCr8: two interleaved 8-bit channels, a chroma plane.
    {
        const src_mem = try allocator.alloc(u8, 10 * 4);
        defer allocator.free(src_mem);
        for (0..4) |y| {
            for (0..4) |x| {
                src_mem[y * 10 + x * 2] = 100;
                src_mem[y * 10 + x * 2 + 1] = 200;
            }
        }
        const src = vImage_Buffer{ .data = src_mem.ptr, .height = 4, .width = 4, .rowBytes = 10 };

        const dst_mem = try allocator.alloc(u8, 6 * 2);
        defer allocator.free(dst_mem);
        @memset(dst_mem, 0);
        const dest = vImage_Buffer{ .data = dst_mem.ptr, .height = 2, .width = 2, .rowBytes = 6 };

        _ = try scale(Pixel_88, &src, &dest, null, Flags.kvImageHighQualityResampling);
        try std.testing.expectEqual(@as(u8, 100), dst_mem[0]);
        try std.testing.expectEqual(@as(u8, 200), dst_mem[1]);
    }
}

/// A triangular-tent kernel, for `newResamplingFilterForFunction`. vImage
/// hands over a batch of positions and wants the filter weight at each.
fn tentKernel(xArray: [*]const f32, yArray: [*]f32, count: c_ulong, userData: ?*anyopaque) callconv(.c) void {
    _ = userData;
    for (0..count) |i| {
        const x = @abs(xArray[i]);
        yArray[i] = if (x < 1.0) 1.0 - x else 0.0;
    }
}

test "newResamplingFilterForFunction builds a usable filter in caller memory" {
    const allocator = std.testing.allocator;
    const flags = Flags.kvImageNoFlags;

    const size = resamplingFilterSize(1.0, tentKernel, 2.0, flags);
    try std.testing.expect(size > 0);

    const buffer = try allocator.alignedAlloc(u8, .of(usize), size);
    defer allocator.free(buffer);

    const filter = try newResamplingFilterForFunction(buffer, 1.0, tentKernel, 2.0, null, flags);
    // No destroyResamplingFilter here: the memory is ours, and freeing it
    // through vImage would free a slice the allocator still owns.

    // The extent is the filter's sampling radius, and the header warns it may
    // exceed the requested kernel width "to allow for extra slop when dealing
    // with sub-pixel coordinates". Measured for this tent at width 2, scale 1:
    // exactly 2, no slop added.
    try std.testing.expectEqual(@as(vImagePixelCount, 2), resamplingFilterExtent(filter, flags));

    var src = try makePlanar8Buffer(allocator, 5, 5, 2);
    defer allocator.free(src.mem);
    setPlanar8(src.buf, 2, 2, 200);

    var dest = try makePlanar8Buffer(allocator, 5, 5, 1);
    defer allocator.free(dest.mem);
    _ = try horizontalShear(Pixel_8, &src.buf, &dest.buf, 0, 0, 1, 0, filter, 0, Flags.kvImageBackgroundColorFill);

    const marker = findMarker(dest.buf);
    try std.testing.expectEqual(@as(usize, 2), marker.y);
    try std.testing.expectEqual(@as(usize, 3), marker.x);
}
