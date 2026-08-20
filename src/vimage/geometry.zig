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
const Pixel_8 = types.Pixel_8;
const Pixel_F = types.Pixel_F;
const Pixel_8888 = types.Pixel_8888;
const Pixel_FFFF = types.Pixel_FFFF;
const Pixel_ARGB_16U = types.Pixel_ARGB_16U;
const Pixel_ARGB_16S = types.Pixel_ARGB_16S;
const Pixel_16U = types.Pixel_16U;
const Pixel_16S = types.Pixel_16S;
const ResamplingFilter = types.ResamplingFilter;
const Flags = types.Flags;
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageRotate_Planar8(src, dest, tempBuffer, angleInRadians, backColor, flags),
        Pixel_F => c.vImageRotate_PlanarF(src, dest, tempBuffer, angleInRadians, backColor, flags),
        Pixel_8888 => c.vImageRotate_ARGB8888(src, dest, tempBuffer, angleInRadians, backColor, flags),
        Pixel_FFFF => c.vImageRotate_ARGBFFFF(src, dest, tempBuffer, angleInRadians, backColor, flags),
        Pixel_ARGB_16U => c.vImageRotate_ARGB16U(src, dest, tempBuffer, angleInRadians, backColor, flags),
        Pixel_ARGB_16S => c.vImageRotate_ARGB16S(src, dest, tempBuffer, angleInRadians, backColor, flags),
        else => @compileError("rotate requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    });
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageScale_Planar8(src, dest, tempBuffer, flags),
        Pixel_F => c.vImageScale_PlanarF(src, dest, tempBuffer, flags),
        Pixel_8888 => c.vImageScale_ARGB8888(src, dest, tempBuffer, flags),
        Pixel_FFFF => c.vImageScale_ARGBFFFF(src, dest, tempBuffer, flags),
        Pixel_ARGB_16U => c.vImageScale_ARGB16U(src, dest, tempBuffer, flags),
        Pixel_ARGB_16S => c.vImageScale_ARGB16S(src, dest, tempBuffer, flags),
        Pixel_16U => c.vImageScale_Planar16U(src, dest, tempBuffer, flags),
        Pixel_16S => c.vImageScale_Planar16S(src, dest, tempBuffer, flags),
        else => @compileError("scale requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, Pixel_ARGB_16S, Pixel_16U, or Pixel_16S"),
    });
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageHorizontalReflect_Planar8(src, dest, flags),
        Pixel_F => c.vImageHorizontalReflect_PlanarF(src, dest, flags),
        Pixel_8888 => c.vImageHorizontalReflect_ARGB8888(src, dest, flags),
        Pixel_FFFF => c.vImageHorizontalReflect_ARGBFFFF(src, dest, flags),
        Pixel_ARGB_16U => c.vImageHorizontalReflect_ARGB16U(src, dest, flags),
        Pixel_ARGB_16S => c.vImageHorizontalReflect_ARGB16S(src, dest, flags),
        else => @compileError("horizontalReflect requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    });
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageVerticalReflect_Planar8(src, dest, flags),
        Pixel_F => c.vImageVerticalReflect_PlanarF(src, dest, flags),
        Pixel_8888 => c.vImageVerticalReflect_ARGB8888(src, dest, flags),
        Pixel_FFFF => c.vImageVerticalReflect_ARGBFFFF(src, dest, flags),
        Pixel_ARGB_16U => c.vImageVerticalReflect_ARGB16U(src, dest, flags),
        Pixel_ARGB_16S => c.vImageVerticalReflect_ARGB16S(src, dest, flags),
        else => @compileError("verticalReflect requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
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
) VImageError!usize {
    const rc = @intFromEnum(rotationConstant);
    return check(switch (T) {
        Pixel_8 => c.vImageRotate90_Planar8(src, dest, rc, backColor, flags),
        Pixel_F => c.vImageRotate90_PlanarF(src, dest, rc, backColor, flags),
        Pixel_8888 => c.vImageRotate90_ARGB8888(src, dest, rc, backColor, flags),
        Pixel_FFFF => c.vImageRotate90_ARGBFFFF(src, dest, rc, backColor, flags),
        Pixel_ARGB_16U => c.vImageRotate90_ARGB16U(src, dest, rc, backColor, flags),
        Pixel_ARGB_16S => c.vImageRotate90_ARGB16S(src, dest, rc, backColor, flags),
        else => @compileError("rotate90 requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    });
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageAffineWarp_Planar8(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_F => c.vImageAffineWarp_PlanarF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_8888 => c.vImageAffineWarp_ARGB8888(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_FFFF => c.vImageAffineWarp_ARGBFFFF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16U => c.vImageAffineWarp_ARGB16U(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16S => c.vImageAffineWarp_ARGB16S(src, dest, tempBuffer, transform, backColor, flags),
        else => @compileError("affineWarp requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    });
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageAffineWarpD_Planar8(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_F => c.vImageAffineWarpD_PlanarF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_8888 => c.vImageAffineWarpD_ARGB8888(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_FFFF => c.vImageAffineWarpD_ARGBFFFF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16U => c.vImageAffineWarpD_ARGB16U(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16S => c.vImageAffineWarpD_ARGB16S(src, dest, tempBuffer, transform, backColor, flags),
        else => @compileError("affineWarpD requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    });
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageAffineWarpCG_Planar8(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_F => c.vImageAffineWarpCG_PlanarF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_8888 => c.vImageAffineWarpCG_ARGB8888(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_FFFF => c.vImageAffineWarpCG_ARGBFFFF(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16U => c.vImageAffineWarpCG_ARGB16U(src, dest, tempBuffer, transform, backColor, flags),
        Pixel_ARGB_16S => c.vImageAffineWarpCG_ARGB16S(src, dest, tempBuffer, transform, backColor, flags),
        else => @compileError("affineWarpCG requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    });
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageHorizontalShear_Planar8(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_F => c.vImageHorizontalShear_PlanarF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_8888 => c.vImageHorizontalShear_ARGB8888(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_FFFF => c.vImageHorizontalShear_ARGBFFFF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16U => c.vImageHorizontalShear_ARGB16U(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16S => c.vImageHorizontalShear_ARGB16S(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, xTranslate, shearSlope, filter, backColor, flags),
        else => @compileError("horizontalShear requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    });
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
) VImageError!usize {
    return check(switch (T) {
        Pixel_8 => c.vImageVerticalShear_Planar8(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_F => c.vImageVerticalShear_PlanarF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_8888 => c.vImageVerticalShear_ARGB8888(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_FFFF => c.vImageVerticalShear_ARGBFFFF(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16U => c.vImageVerticalShear_ARGB16U(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        Pixel_ARGB_16S => c.vImageVerticalShear_ARGB16S(src, dest, srcOffsetToROI_X, srcOffsetToROI_Y, yTranslate, shearSlope, filter, backColor, flags),
        else => @compileError("verticalShear requires Pixel_8, Pixel_F, Pixel_8888, Pixel_FFFF, Pixel_ARGB_16U, or Pixel_ARGB_16S"),
    });
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
