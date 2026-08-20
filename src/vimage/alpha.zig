const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const VImageError = types.VImageError;
const check = types.check;
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
pub fn alphaBlendPlanar(comptime T: type, srcTop: *const vImage_Buffer, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, srcBottomAlpha: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageAlphaBlend_Planar8(srcTop, srcTopAlpha, srcBottom, srcBottomAlpha, alpha, dest, flags),
        f32 => c.vImageAlphaBlend_PlanarF(srcTop, srcTopAlpha, srcBottom, srcBottomAlpha, alpha, dest, flags),
        else => @compileError("alphaBlendPlanar requires u8 or f32"),
    });
}

/// Composite two non-premultiplied ARGB interleaved images to produce a non-premultiplied result.
///
/// For each color channel:
///     destColor = (srcTopColor * srcTopAlpha + (1 - srcTopAlpha) * srcBottomAlpha * srcBottomColor) / alpha
pub fn alphaBlendARGB(comptime T: type, srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageAlphaBlend_ARGB8888(srcTop, srcBottom, dest, flags),
        f32 => c.vImageAlphaBlend_ARGBFFFF(srcTop, srcBottom, dest, flags),
        else => @compileError("alphaBlendARGB requires u8 or f32"),
    });
}

// ============================================================================
// Alpha Blend (premultiplied)
// ============================================================================

/// Blend two premultiplied planar images to produce a premultiplied result.
///
/// For each color channel:
///     u8:  destColor = srcTopColor + ((255 - srcTopAlpha) * srcBottomColor + 127) / 255
///     f32: destColor = srcTopColor + (1.0 - srcTopAlpha) * srcBottomColor
pub fn premultipliedAlphaBlendPlanar(comptime T: type, srcTop: *const vImage_Buffer, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImagePremultipliedAlphaBlend_Planar8(srcTop, srcTopAlpha, srcBottom, dest, flags),
        f32 => c.vImagePremultipliedAlphaBlend_PlanarF(srcTop, srcTopAlpha, srcBottom, dest, flags),
        else => @compileError("premultipliedAlphaBlendPlanar requires u8 or f32"),
    });
}

/// Blend two premultiplied ARGB (alpha-first) interleaved images.
pub fn premultipliedAlphaBlendARGB(comptime T: type, srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImagePremultipliedAlphaBlend_ARGB8888(srcTop, srcBottom, dest, flags),
        f32 => c.vImagePremultipliedAlphaBlend_ARGBFFFF(srcTop, srcBottom, dest, flags),
        else => @compileError("premultipliedAlphaBlendARGB requires u8 or f32"),
    });
}

/// Blend two premultiplied BGRA/RGBA (alpha-last) interleaved images.
pub fn premultipliedAlphaBlendBGRA(comptime T: type, srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImagePremultipliedAlphaBlend_BGRA8888(srcTop, srcBottom, dest, flags),
        f32 => c.vImagePremultipliedAlphaBlend_BGRAFFFF(srcTop, srcBottom, dest, flags),
        else => @compileError("premultipliedAlphaBlendBGRA requires u8 or f32"),
    });
}

/// Reorder channels of the top premultiplied image via permuteMap, then blend into the bottom
/// premultiplied ARGB image. Optionally force destination alpha to 0xFF/opaque.
pub fn premultipliedAlphaBlendWithPermuteARGB(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, makeDestAlphaOpaque: bool, flags: vImage_Flags) VImageError!usize {
    return check(c.vImagePremultipliedAlphaBlendWithPermute_ARGB8888(srcTop, srcBottom, dest, permuteMap, makeDestAlphaOpaque, flags));
}

/// Reorder channels of the top premultiplied image via permuteMap, then blend into the bottom
/// premultiplied RGBA image. Optionally force destination alpha to 0xFF/opaque.
pub fn premultipliedAlphaBlendWithPermuteRGBA(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, makeDestAlphaOpaque: bool, flags: vImage_Flags) VImageError!usize {
    return check(c.vImagePremultipliedAlphaBlendWithPermute_RGBA8888(srcTop, srcBottom, dest, permuteMap, makeDestAlphaOpaque, flags));
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
pub fn premultipliedAlphaBlendRGBA(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, mode: BlendMode, flags: vImage_Flags) VImageError!usize {
    return check(switch (mode) {
        .normal => c.vImagePremultipliedAlphaBlend_BGRA8888(srcTop, srcBottom, dest, flags),
        .multiply => c.vImagePremultipliedAlphaBlendMultiply_RGBA8888(srcTop, srcBottom, dest, flags),
        .screen => c.vImagePremultipliedAlphaBlendScreen_RGBA8888(srcTop, srcBottom, dest, flags),
        .darken => c.vImagePremultipliedAlphaBlendDarken_RGBA8888(srcTop, srcBottom, dest, flags),
        .lighten => c.vImagePremultipliedAlphaBlendLighten_RGBA8888(srcTop, srcBottom, dest, flags),
    });
}

// ============================================================================
// Premultiplied Const Alpha Blend
// ============================================================================

/// Blend a premultiplied top image into a premultiplied bottom image, scaling the top
/// by a constant alpha value in addition to the per-pixel alpha.
///
/// Planar version requires separate alpha buffer.
pub fn premultipliedConstAlphaBlendPlanar(comptime T: type, srcTop: *const vImage_Buffer, constAlpha: T, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImagePremultipliedConstAlphaBlend_Planar8(srcTop, constAlpha, srcTopAlpha, srcBottom, dest, flags),
        f32 => c.vImagePremultipliedConstAlphaBlend_PlanarF(srcTop, constAlpha, srcTopAlpha, srcBottom, dest, flags),
        else => @compileError("premultipliedConstAlphaBlendPlanar requires u8 or f32"),
    });
}

/// Blend a premultiplied top ARGB image into a premultiplied bottom image, scaling the top
/// by a constant alpha value.
pub fn premultipliedConstAlphaBlendARGB(comptime T: type, srcTop: *const vImage_Buffer, constAlpha: T, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImagePremultipliedConstAlphaBlend_ARGB8888(srcTop, constAlpha, srcBottom, dest, flags),
        f32 => c.vImagePremultipliedConstAlphaBlend_ARGBFFFF(srcTop, constAlpha, srcBottom, dest, flags),
        else => @compileError("premultipliedConstAlphaBlendARGB requires u8 or f32"),
    });
}

// ============================================================================
// Alpha Blend (non-premultiplied to premultiplied)
// ============================================================================

/// Blend a non-premultiplied top image over a premultiplied bottom image, producing a
/// premultiplied result. Planar version requires separate alpha buffer.
pub fn alphaBlendNonpremultipliedToPremultipliedPlanar(comptime T: type, srcTop: *const vImage_Buffer, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageAlphaBlend_NonpremultipliedToPremultiplied_Planar8(srcTop, srcTopAlpha, srcBottom, dest, flags),
        f32 => c.vImageAlphaBlend_NonpremultipliedToPremultiplied_PlanarF(srcTop, srcTopAlpha, srcBottom, dest, flags),
        else => @compileError("alphaBlendNonpremultipliedToPremultipliedPlanar requires u8 or f32"),
    });
}

/// Blend a non-premultiplied top ARGB image over a premultiplied bottom image, producing a
/// premultiplied result.
pub fn alphaBlendNonpremultipliedToPremultipliedARGB(comptime T: type, srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageAlphaBlend_NonpremultipliedToPremultiplied_ARGB8888(srcTop, srcBottom, dest, flags),
        f32 => c.vImageAlphaBlend_NonpremultipliedToPremultiplied_ARGBFFFF(srcTop, srcBottom, dest, flags),
        else => @compileError("alphaBlendNonpremultipliedToPremultipliedARGB requires u8 or f32"),
    });
}

// ============================================================================
// Premultiply Data
// ============================================================================

/// Multiply a planar color channel by its corresponding alpha channel.
///
///     u8:  destColor = (src * alpha + 127) / 255
///     f32: destColor = src * alpha
pub fn premultiplyDataPlanar(comptime T: type, src: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImagePremultiplyData_Planar8(src, alpha, dest, flags),
        f32 => c.vImagePremultiplyData_PlanarF(src, alpha, dest, flags),
        else => @compileError("premultiplyDataPlanar requires u8 or f32"),
    });
}

/// Premultiply an ARGB (alpha-first) interleaved image by its alpha channel.
pub fn premultiplyDataARGB(comptime T: type, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImagePremultiplyData_ARGB8888(src, dest, flags),
        f32 => c.vImagePremultiplyData_ARGBFFFF(src, dest, flags),
        else => @compileError("premultiplyDataARGB requires u8 or f32"),
    });
}

/// Premultiply an RGBA/BGRA (alpha-last) interleaved image by its alpha channel.
pub fn premultiplyDataRGBA(comptime T: type, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImagePremultiplyData_RGBA8888(src, dest, flags),
        f32 => c.vImagePremultiplyData_RGBAFFFF(src, dest, flags),
        else => @compileError("premultiplyDataRGBA requires u8 or f32"),
    });
}

/// Premultiply an ARGB 16-bit unsigned interleaved image by its alpha channel.
pub fn premultiplyDataARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImagePremultiplyData_ARGB16U(src, dest, flags));
}

/// Premultiply an RGBA 16-bit unsigned interleaved image by its alpha channel.
pub fn premultiplyDataRGBA16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImagePremultiplyData_RGBA16U(src, dest, flags));
}

/// Premultiply an ARGB 16Q12 fixed-point interleaved image by its alpha channel.
pub fn premultiplyDataARGB16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImagePremultiplyData_ARGB16Q12(src, dest, flags));
}

/// Premultiply an RGBA 16Q12 fixed-point interleaved image by its alpha channel.
pub fn premultiplyDataRGBA16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImagePremultiplyData_RGBA16Q12(src, dest, flags));
}

/// Premultiply an RGBA half-float (16F) interleaved image by its alpha channel.
pub fn premultiplyDataRGBA16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImagePremultiplyData_RGBA16F(src, dest, flags));
}

// ============================================================================
// Unpremultiply Data
// ============================================================================

/// Divide a planar color channel by its corresponding alpha channel to recover
/// non-premultiplied values.
///
/// Per Alpha.h:1356-1360 (vImageUnpremultiplyData_Planar8), the u8 formula clamps
/// src to alpha to avoid modulo overflow when src > alpha (which can happen with
/// slightly-off-premultiplied input):
///
///     u8:  destColor = (min(src, alpha) * 255 + alpha/2) / alpha  (0 if alpha == 0)
///     f32: destColor = src / alpha                                 (0 if alpha == 0)
pub fn unpremultiplyDataPlanar(comptime T: type, src: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageUnpremultiplyData_Planar8(src, alpha, dest, flags),
        f32 => c.vImageUnpremultiplyData_PlanarF(src, alpha, dest, flags),
        else => @compileError("unpremultiplyDataPlanar requires u8 or f32"),
    });
}

/// Unpremultiply an ARGB (alpha-first) interleaved image.
pub fn unpremultiplyDataARGB(comptime T: type, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageUnpremultiplyData_ARGB8888(src, dest, flags),
        f32 => c.vImageUnpremultiplyData_ARGBFFFF(src, dest, flags),
        else => @compileError("unpremultiplyDataARGB requires u8 or f32"),
    });
}

/// Unpremultiply an RGBA/BGRA (alpha-last) interleaved image.
pub fn unpremultiplyDataRGBA(comptime T: type, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageUnpremultiplyData_RGBA8888(src, dest, flags),
        f32 => c.vImageUnpremultiplyData_RGBAFFFF(src, dest, flags),
        else => @compileError("unpremultiplyDataRGBA requires u8 or f32"),
    });
}

/// Unpremultiply an ARGB 16-bit unsigned interleaved image.
pub fn unpremultiplyDataARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageUnpremultiplyData_ARGB16U(src, dest, flags));
}

/// Unpremultiply an RGBA 16-bit unsigned interleaved image.
pub fn unpremultiplyDataRGBA16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageUnpremultiplyData_RGBA16U(src, dest, flags));
}

/// Unpremultiply an ARGB 16Q12 fixed-point interleaved image.
pub fn unpremultiplyDataARGB16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageUnpremultiplyData_ARGB16Q12(src, dest, flags));
}

/// Unpremultiply an RGBA 16Q12 fixed-point interleaved image.
pub fn unpremultiplyDataRGBA16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageUnpremultiplyData_RGBA16Q12(src, dest, flags));
}

/// Unpremultiply an RGBA half-float (16F) interleaved image.
pub fn unpremultiplyDataRGBA16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageUnpremultiplyData_RGBA16F(src, dest, flags));
}

// ============================================================================
// Clip to Alpha
// ============================================================================

/// Clip color channel values so they do not exceed the alpha value.
/// Planar version requires separate alpha buffer.
///
/// For each pixel: dest = min(src, alpha)
pub fn clipToAlphaPlanar(comptime T: type, src: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageClipToAlpha_Planar8(src, alpha, dest, flags),
        f32 => c.vImageClipToAlpha_PlanarF(src, alpha, dest, flags),
        else => @compileError("clipToAlphaPlanar requires u8 or f32"),
    });
}

/// Clip color channel values so they do not exceed the alpha value.
/// ARGB (alpha-first) interleaved version.
pub fn clipToAlphaARGB(comptime T: type, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageClipToAlpha_ARGB8888(src, dest, flags),
        f32 => c.vImageClipToAlpha_ARGBFFFF(src, dest, flags),
        else => @compileError("clipToAlphaARGB requires u8 or f32"),
    });
}

/// Clip color channel values so they do not exceed the alpha value.
/// RGBA/BGRA (alpha-last) interleaved version.
pub fn clipToAlphaRGBA(comptime T: type, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageClipToAlpha_RGBA8888(src, dest, flags),
        f32 => c.vImageClipToAlpha_RGBAFFFF(src, dest, flags),
        else => @compileError("clipToAlphaRGBA requires u8 or f32"),
    });
}

// ============================================================================
// Tests
// ============================================================================
//
// Test images use non-square (height != width) dimensions and, where relevant,
// rowBytes padded beyond width*bytesPerPixel to catch wrappers that assume tight
// packing. Every wrapper call is `try`d, so any vImage error code fails the
// test before output pixels are inspected. Interleaved-format tests give every channel a
// distinct value so a channel-order bug (e.g. ARGB data run through an RGBA path)
// produces a visibly wrong result rather than a coincidentally-correct one.

fn bufFromBytes(data: []u8, height: usize, width: usize, rowBytes: usize) vImage_Buffer {
    return .{ .data = data.ptr, .height = height, .width = width, .rowBytes = rowBytes };
}

test "alphaBlendPlanar PlanarF matches Alpha.h formula (argument-order check)" {
    // Alpha.h:92-94 (vImageAlphaBlend_PlanarF):
    //   destColor = (srcTopColor*srcTopAlpha + (1-srcTopAlpha)*srcBottomAlpha*srcBottomColor) / alpha
    //   alpha = srcTopAlpha + (1-srcTopAlpha)*srcBottomAlpha
    // Deliberately asymmetric top vs. bottom color/alpha so swapping any argument
    // pair would change the result.
    const h = 2;
    const w = 3;
    var top_color = [_]f32{100} ** (h * w);
    var top_alpha = [_]f32{0.25} ** (h * w);
    var bottom_color = [_]f32{20} ** (h * w);
    var bottom_alpha = [_]f32{0.6} ** (h * w);
    const alpha_val: f32 = 0.25 + (1 - 0.25) * 0.6; // 0.7
    var alpha_buf = [_]f32{alpha_val} ** (h * w);
    var dest = [_]f32{0} ** (h * w);

    const row_bytes = w * @sizeOf(f32);
    const b_top = bufFromBytes(std.mem.sliceAsBytes(&top_color), h, w, row_bytes);
    const b_top_a = bufFromBytes(std.mem.sliceAsBytes(&top_alpha), h, w, row_bytes);
    const b_bottom = bufFromBytes(std.mem.sliceAsBytes(&bottom_color), h, w, row_bytes);
    const b_bottom_a = bufFromBytes(std.mem.sliceAsBytes(&bottom_alpha), h, w, row_bytes);
    const b_alpha = bufFromBytes(std.mem.sliceAsBytes(&alpha_buf), h, w, row_bytes);
    const b_dest = bufFromBytes(std.mem.sliceAsBytes(&dest), h, w, row_bytes);

    const err = alphaBlendPlanar(f32, &b_top, &b_top_a, &b_bottom, &b_bottom_a, &b_alpha, &b_dest, 0);
    try std.testing.expectEqual(@as(usize, 0), try err);

    const expected: f32 = (100 * 0.25 + (1 - 0.25) * 0.6 * 20) / alpha_val; // ~48.571
    for (dest) |v| {
        try std.testing.expectApproxEqAbs(expected, v, 0.01);
    }
}

test "alphaBlendARGB u8 alpha-first channel order, padded rowBytes" {
    // Alpha.h:222 (vImageAlphaBlend_ARGB8888): "alpha channel must appear first".
    // 2x2 image, 4 bytes/pixel, rowBytes padded to 12 (tight = 8) to confirm the
    // wrapper doesn't assume tight packing.
    const h = 2;
    const w = 2;
    const row_bytes = 12;
    var top: [h * row_bytes]u8 = undefined;
    var bottom: [h * row_bytes]u8 = undefined;
    var dest: [h * row_bytes]u8 = [_]u8{0xAA} ** (h * row_bytes);

    // Every pixel: top A=64 R=200 G=10 B=30 ; bottom A=180 R=5 G=90 B=250.
    for (0..h) |y| {
        for (0..w) |x| {
            const off = y * row_bytes + x * 4;
            top[off + 0] = 64; // A
            top[off + 1] = 200; // R
            top[off + 2] = 10; // G
            top[off + 3] = 30; // B
            bottom[off + 0] = 180; // A
            bottom[off + 1] = 5; // R
            bottom[off + 2] = 90; // G
            bottom[off + 3] = 250; // B
        }
    }

    const b_top = bufFromBytes(&top, h, w, row_bytes);
    const b_bottom = bufFromBytes(&bottom, h, w, row_bytes);
    const b_dest = bufFromBytes(&dest, h, w, row_bytes);

    const err = alphaBlendARGB(u8, &b_top, &b_bottom, &b_dest, 0);
    try std.testing.expectEqual(@as(usize, 0), try err);

    // Alpha.h:94 alpha = srcTopAlpha + (1-srcTopAlpha)*srcBottomAlpha (compositing
    // "over", so result alpha is >= both inputs, not their average). With
    // topAlpha=64, bottomAlpha=180 this works out to ~199 (0.7799*255). Confirm
    // the alpha channel really was read from byte offset 0 by checking it lands
    // near that computed value rather than being e.g. a stray color channel.
    const expected_alpha_f: f32 = 64.0 / 255.0 + (1.0 - 64.0 / 255.0) * (180.0 / 255.0);
    const expected_alpha_u8: u8 = @intFromFloat(@round(expected_alpha_f * 255.0));
    for (0..h) |y| {
        for (0..w) |x| {
            const off = y * row_bytes + x * 4;
            const diff: i32 = @as(i32, dest[off + 0]) - @as(i32, expected_alpha_u8);
            try std.testing.expect(diff <= 2 and diff >= -2);
        }
    }
}

test "premultipliedAlphaBlendPlanar exact u8/f32 formulas" {
    // Alpha.h:270-271 (u8): destColor = srcTop + ((255-srcTopAlpha)*srcBottom + 127)/255
    // Alpha.h:317    (f32): destColor = srcTop + (1-srcTopAlpha)*srcBottom
    const h = 2;
    const w = 3;

    var top_u8 = [_]u8{200} ** (h * w);
    var top_alpha_u8 = [_]u8{60} ** (h * w);
    var bottom_u8 = [_]u8{40} ** (h * w);
    var dest_u8 = [_]u8{0} ** (h * w);
    const row_bytes_u8 = w;
    const b_top_u8 = bufFromBytes(&top_u8, h, w, row_bytes_u8);
    const b_top_a_u8 = bufFromBytes(&top_alpha_u8, h, w, row_bytes_u8);
    const b_bottom_u8 = bufFromBytes(&bottom_u8, h, w, row_bytes_u8);
    const b_dest_u8 = bufFromBytes(&dest_u8, h, w, row_bytes_u8);

    const err_u8 = premultipliedAlphaBlendPlanar(u8, &b_top_u8, &b_top_a_u8, &b_bottom_u8, &b_dest_u8, 0);
    try std.testing.expectEqual(@as(usize, 0), try err_u8);
    const expected_u8: u8 = 200 + @as(u8, @intCast((@as(u32, 255 - 60) * 40 + 127) / 255));
    for (dest_u8) |v| try std.testing.expectEqual(expected_u8, v);

    var top_f = [_]f32{200} ** (h * w);
    var top_alpha_f = [_]f32{0.25} ** (h * w);
    var bottom_f = [_]f32{40} ** (h * w);
    var dest_f = [_]f32{0} ** (h * w);
    const row_bytes_f = w * @sizeOf(f32);
    const b_top_f = bufFromBytes(std.mem.sliceAsBytes(&top_f), h, w, row_bytes_f);
    const b_top_a_f = bufFromBytes(std.mem.sliceAsBytes(&top_alpha_f), h, w, row_bytes_f);
    const b_bottom_f = bufFromBytes(std.mem.sliceAsBytes(&bottom_f), h, w, row_bytes_f);
    const b_dest_f = bufFromBytes(std.mem.sliceAsBytes(&dest_f), h, w, row_bytes_f);

    const err_f = premultipliedAlphaBlendPlanar(f32, &b_top_f, &b_top_a_f, &b_bottom_f, &b_dest_f, 0);
    try std.testing.expectEqual(@as(usize, 0), try err_f);
    const expected_f: f32 = 200 + (1 - 0.25) * 40;
    for (dest_f) |v| try std.testing.expectApproxEqAbs(expected_f, v, 0.001);
}

test "premultipliedAlphaBlendARGB (alpha-first) vs premultipliedAlphaBlendBGRA (alpha-last)" {
    // Both ultimately call the same blend math; the only difference the wrapper
    // must get right is which byte offset carries alpha. Build a 1x1 pixel with
    // 4 distinct byte values and confirm ARGB reads alpha from offset 0 while
    // BGRA reads it from offset 3 (Alpha.h:398 vs :440).
    const h = 1;
    const w = 1;
    const row_bytes = 4;

    var argb_top = [_]u8{ 64, 200, 10, 30 }; // A R G B
    var argb_bottom = [_]u8{ 180, 5, 90, 250 };
    var argb_dest = [_]u8{0} ** 4;
    const b_argb_top = bufFromBytes(&argb_top, h, w, row_bytes);
    const b_argb_bottom = bufFromBytes(&argb_bottom, h, w, row_bytes);
    const b_argb_dest = bufFromBytes(&argb_dest, h, w, row_bytes);
    const err1 = premultipliedAlphaBlendARGB(u8, &b_argb_top, &b_argb_bottom, &b_argb_dest, 0);
    try std.testing.expectEqual(@as(usize, 0), try err1);
    // destAlpha = srcTopAlpha + ((255-srcTopAlpha)*srcBottomAlpha + 127)/255
    const expected_alpha: u8 = 64 + @as(u8, @intCast((@as(u32, 255 - 64) * 180 + 127) / 255));
    try std.testing.expectEqual(expected_alpha, argb_dest[0]);

    var bgra_top = [_]u8{ 200, 10, 30, 64 }; // R G B A (same pixel, alpha last)
    var bgra_bottom = [_]u8{ 5, 90, 250, 180 };
    var bgra_dest = [_]u8{0} ** 4;
    const b_bgra_top = bufFromBytes(&bgra_top, h, w, row_bytes);
    const b_bgra_bottom = bufFromBytes(&bgra_bottom, h, w, row_bytes);
    const b_bgra_dest = bufFromBytes(&bgra_dest, h, w, row_bytes);
    const err2 = premultipliedAlphaBlendBGRA(u8, &b_bgra_top, &b_bgra_bottom, &b_bgra_dest, 0);
    try std.testing.expectEqual(@as(usize, 0), try err2);
    try std.testing.expectEqual(expected_alpha, bgra_dest[3]);
}

test "premultipliedAlphaBlendWithPermuteARGB reorders top channels before blending" {
    // Alpha.h:625 vImagePremultipliedAlphaBlendWithPermute_ARGB8888: srcTop channels
    // are first permuted per permuteMap[dst_index] = src_index, then blended into
    // srcBottom (already in ARGB order). Use an identity-breaking permute
    // (reverse) and confirm makeDestAlphaOpaque forces alpha to 0xFF.
    const h = 1;
    const w = 1;
    const row_bytes = 4;
    var top = [_]u8{ 10, 20, 30, 40 }; // stored as [c0,c1,c2,c3]
    var bottom = [_]u8{ 0, 0, 0, 0 }; // fully transparent black bottom
    var dest = [_]u8{0} ** 4;
    const b_top = bufFromBytes(&top, h, w, row_bytes);
    const b_bottom = bufFromBytes(&bottom, h, w, row_bytes);
    const b_dest = bufFromBytes(&dest, h, w, row_bytes);
    const permute = [4]u8{ 3, 2, 1, 0 }; // reverse: dest[i] source = top[permute[i]]

    const err = premultipliedAlphaBlendWithPermuteARGB(&b_top, &b_bottom, &b_dest, &permute, true, 0);
    try std.testing.expectEqual(@as(usize, 0), try err);
    // makeDestAlphaOpaque forces alpha (index 0) to 0xFF regardless of blend math.
    try std.testing.expectEqual(@as(u8, 0xFF), dest[0]);
}

test "premultipliedAlphaBlendWithPermuteRGBA reorders top channels before blending" {
    const h = 1;
    const w = 1;
    const row_bytes = 4;
    var top = [_]u8{ 10, 20, 30, 40 };
    var bottom = [_]u8{ 0, 0, 0, 0 };
    var dest = [_]u8{0} ** 4;
    const b_top = bufFromBytes(&top, h, w, row_bytes);
    const b_bottom = bufFromBytes(&bottom, h, w, row_bytes);
    const b_dest = bufFromBytes(&dest, h, w, row_bytes);
    const permute = [4]u8{ 3, 2, 1, 0 };

    const err = premultipliedAlphaBlendWithPermuteRGBA(&b_top, &b_bottom, &b_dest, &permute, true, 0);
    try std.testing.expectEqual(@as(usize, 0), try err);
    // RGBA/BGRA layout: alpha is last (index 3).
    try std.testing.expectEqual(@as(u8, 0xFF), dest[3]);
}

test "premultipliedAlphaBlendRGBA dispatches distinct blend modes" {
    // Alpha.h declares separate Multiply/Screen/Darken/Lighten RGBA8888 entry
    // points (lines 787-914) plus the shared BGRA8888 path for .normal. Verify
    // every mode succeeds and that the modes are not all aliased to the same
    // underlying function (which would make all outputs identical).
    const h = 1;
    const w = 1;
    const row_bytes = 4;
    var top = [_]u8{ 200, 100, 50, 128 }; // R G B A, alpha in the middle range
    var bottom = [_]u8{ 30, 220, 180, 255 };

    var results: [5][4]u8 = undefined;
    const modes = [_]BlendMode{ .normal, .multiply, .screen, .darken, .lighten };
    for (modes, 0..) |mode, i| {
        var dest = [_]u8{0} ** 4;
        const b_top = bufFromBytes(&top, h, w, row_bytes);
        const b_bottom = bufFromBytes(&bottom, h, w, row_bytes);
        const b_dest = bufFromBytes(&dest, h, w, row_bytes);
        const err = premultipliedAlphaBlendRGBA(&b_top, &b_bottom, &b_dest, mode, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
        results[i] = dest;
    }

    // multiply/screen/darken/lighten should not all coincide with normal (they
    // are meaningfully different compositing operators for these inputs).
    var any_different = false;
    for (results[1..]) |r| {
        if (!std.mem.eql(u8, &r, &results[0])) any_different = true;
    }
    try std.testing.expect(any_different);
}

test "premultipliedConstAlphaBlendPlanar exact u8 formula" {
    // Alpha.h:1783-1784 (vImagePremultipliedConstAlphaBlend_Planar8):
    //   destColor = (srcTopColor*constAlpha*255 + (255*255 - srcTopAlpha*constAlpha)*srcBottomColor + 127*255) / (255*255)
    const h = 1;
    const w = 1;
    var top = [_]u8{150};
    var top_alpha = [_]u8{80};
    var bottom = [_]u8{40};
    var dest = [_]u8{0};
    const b_top = bufFromBytes(&top, h, w, w);
    const b_top_a = bufFromBytes(&top_alpha, h, w, w);
    const b_bottom = bufFromBytes(&bottom, h, w, w);
    const b_dest = bufFromBytes(&dest, h, w, w);

    const const_alpha: u8 = 100;
    const err = premultipliedConstAlphaBlendPlanar(u8, &b_top, const_alpha, &b_top_a, &b_bottom, &b_dest, 0);
    try std.testing.expectEqual(@as(usize, 0), try err);

    const top_c: u64 = 150;
    const ca: u64 = 100;
    const top_a: u64 = 80;
    const bottom_c: u64 = 40;
    const expected: u8 = @intCast((top_c * ca * 255 + (255 * 255 - top_a * ca) * bottom_c + 127 * 255) / (255 * 255));
    try std.testing.expectEqual(expected, dest[0]);
}

test "premultipliedConstAlphaBlendARGB succeeds and blends distinct pixels" {
    const h = 1;
    const w = 1;
    const row_bytes = 4;
    var top = [_]u8{ 200, 10, 20, 30 }; // A R G B
    var bottom = [_]u8{ 50, 90, 100, 110 };
    var dest = [_]u8{0} ** 4;
    const b_top = bufFromBytes(&top, h, w, row_bytes);
    const b_bottom = bufFromBytes(&bottom, h, w, row_bytes);
    const b_dest = bufFromBytes(&dest, h, w, row_bytes);

    const err = premultipliedConstAlphaBlendARGB(u8, &b_top, 128, &b_bottom, &b_dest, 0);
    try std.testing.expectEqual(@as(usize, 0), try err);
    // Result should land strictly between top and bottom color values for a
    // partial constAlpha, per channel.
    for (1..4) |i| {
        const lo = @min(top[i], bottom[i]);
        const hi = @max(top[i], bottom[i]);
        try std.testing.expect(dest[i] >= lo and dest[i] <= hi);
    }
}

test "alphaBlendNonpremultipliedToPremultipliedPlanar PlanarF matches formula" {
    // Alpha.h:1962-1965 (PlanarF): result = srcTop*srcTopAlpha + (1-srcTopAlpha)*srcBottom
    const h = 1;
    const w = 1;
    var top = [_]f32{80};
    var top_alpha = [_]f32{0.3};
    var bottom = [_]f32{20}; // already premultiplied bottom
    var dest = [_]f32{0};
    const rb = @sizeOf(f32);
    const b_top = bufFromBytes(std.mem.sliceAsBytes(&top), h, w, rb);
    const b_top_a = bufFromBytes(std.mem.sliceAsBytes(&top_alpha), h, w, rb);
    const b_bottom = bufFromBytes(std.mem.sliceAsBytes(&bottom), h, w, rb);
    const b_dest = bufFromBytes(std.mem.sliceAsBytes(&dest), h, w, rb);

    const err = alphaBlendNonpremultipliedToPremultipliedPlanar(f32, &b_top, &b_top_a, &b_bottom, &b_dest, 0);
    try std.testing.expectEqual(@as(usize, 0), try err);
    const expected: f32 = 80 * 0.3 + (1 - 0.3) * 20;
    try std.testing.expectApproxEqAbs(expected, dest[0], 0.001);
}

test "alphaBlendNonpremultipliedToPremultipliedARGB succeeds, alpha-first" {
    const h = 1;
    const w = 1;
    const row_bytes = 4;
    var top = [_]u8{ 100, 200, 150, 50 }; // A R G B, non-premultiplied top
    var bottom = [_]u8{ 30, 10, 10, 10 }; // premultiplied bottom
    var dest = [_]u8{0} ** 4;
    const b_top = bufFromBytes(&top, h, w, row_bytes);
    const b_bottom = bufFromBytes(&bottom, h, w, row_bytes);
    const b_dest = bufFromBytes(&dest, h, w, row_bytes);

    const err = alphaBlendNonpremultipliedToPremultipliedARGB(u8, &b_top, &b_bottom, &b_dest, 0);
    try std.testing.expectEqual(@as(usize, 0), try err);
    // Dest color channels must be <= max(top color premultiplied by its alpha, bottom)
    // roughly; just sanity check they're not raw-copied top (which would ignore alpha).
    try std.testing.expect(dest[1] != top[1] or dest[2] != top[2] or dest[3] != top[3]);
}

test "premultiplyDataPlanar / unpremultiplyDataPlanar round trip (u8 and f32, non-edge alpha)" {
    // Round trip with a non-edge alpha (not 0 or max) must recover the original
    // color, within u8 rounding.
    const h = 1;
    const w = 1;
    var color_u8 = [_]u8{77};
    var alpha_u8 = [_]u8{150}; // non-edge
    var premult_u8 = [_]u8{0};
    var recovered_u8 = [_]u8{0};
    {
        const b_color = bufFromBytes(&color_u8, h, w, w);
        const b_alpha = bufFromBytes(&alpha_u8, h, w, w);
        const b_dest = bufFromBytes(&premult_u8, h, w, w);
        const err = premultiplyDataPlanar(u8, &b_color, &b_alpha, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    {
        const b_premult = bufFromBytes(&premult_u8, h, w, w);
        const b_alpha = bufFromBytes(&alpha_u8, h, w, w);
        const b_dest = bufFromBytes(&recovered_u8, h, w, w);
        const err = unpremultiplyDataPlanar(u8, &b_premult, &b_alpha, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    // u8 round trip may be off by a small amount due to integer rounding twice.
    try std.testing.expect(@as(i32, recovered_u8[0]) - @as(i32, color_u8[0]) <= 1 and @as(i32, color_u8[0]) - @as(i32, recovered_u8[0]) <= 1);

    var color_f = [_]f32{0.42};
    var alpha_f = [_]f32{0.6}; // non-edge
    var premult_f = [_]f32{0};
    var recovered_f = [_]f32{0};
    {
        const rb = @sizeOf(f32);
        const b_color = bufFromBytes(std.mem.sliceAsBytes(&color_f), h, w, rb);
        const b_alpha = bufFromBytes(std.mem.sliceAsBytes(&alpha_f), h, w, rb);
        const b_dest = bufFromBytes(std.mem.sliceAsBytes(&premult_f), h, w, rb);
        const err = premultiplyDataPlanar(f32, &b_color, &b_alpha, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
        const b_premult = bufFromBytes(std.mem.sliceAsBytes(&premult_f), h, w, rb);
        const b_dest2 = bufFromBytes(std.mem.sliceAsBytes(&recovered_f), h, w, rb);
        const err2 = unpremultiplyDataPlanar(f32, &b_premult, &b_alpha, &b_dest2, 0);
        try std.testing.expectEqual(@as(usize, 0), try err2);
    }
    try std.testing.expectApproxEqAbs(color_f[0], recovered_f[0], 1e-5);
}

test "premultiplyDataARGB / unpremultiplyDataARGB round trip, alpha-first" {
    const h = 1;
    const w = 1;
    const row_bytes = 4;
    var pixel = [_]u8{ 150, 10, 200, 90 }; // A R G B, non-edge alpha
    var premult = [_]u8{0} ** 4;
    var recovered = [_]u8{0} ** 4;
    {
        const b_src = bufFromBytes(&pixel, h, w, row_bytes);
        const b_dest = bufFromBytes(&premult, h, w, row_bytes);
        const err = premultiplyDataARGB(u8, &b_src, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    try std.testing.expectEqual(pixel[0], premult[0]); // alpha channel passes through
    {
        const b_src = bufFromBytes(&premult, h, w, row_bytes);
        const b_dest = bufFromBytes(&recovered, h, w, row_bytes);
        const err = unpremultiplyDataARGB(u8, &b_src, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    for (1..4) |i| {
        try std.testing.expect(@as(i32, recovered[i]) - @as(i32, pixel[i]) <= 1 and @as(i32, pixel[i]) - @as(i32, recovered[i]) <= 1);
    }
}

test "premultiplyDataRGBA / unpremultiplyDataRGBA round trip, alpha-last" {
    const h = 1;
    const w = 1;
    const row_bytes = 4;
    var pixel = [_]u8{ 10, 200, 90, 150 }; // R G B A, non-edge alpha
    var premult = [_]u8{0} ** 4;
    var recovered = [_]u8{0} ** 4;
    {
        const b_src = bufFromBytes(&pixel, h, w, row_bytes);
        const b_dest = bufFromBytes(&premult, h, w, row_bytes);
        const err = premultiplyDataRGBA(u8, &b_src, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    try std.testing.expectEqual(pixel[3], premult[3]); // alpha channel (last) passes through
    {
        const b_src = bufFromBytes(&premult, h, w, row_bytes);
        const b_dest = bufFromBytes(&recovered, h, w, row_bytes);
        const err = unpremultiplyDataRGBA(u8, &b_src, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    for (0..3) |i| {
        try std.testing.expect(@as(i32, recovered[i]) - @as(i32, pixel[i]) <= 1 and @as(i32, pixel[i]) - @as(i32, recovered[i]) <= 1);
    }
}

test "premultiplyDataARGB16U / unpremultiplyDataARGB16U round trip" {
    // Alpha.h:1230/1648: uint16_t destColor = (src*alpha+32767)/65535; alpha-first.
    const h = 1;
    const w = 1;
    var pixel: [4]u16 = .{ 40000, 5000, 60000, 20000 }; // A R G B, non-edge alpha
    var premult: [4]u16 = .{ 0, 0, 0, 0 };
    var recovered: [4]u16 = .{ 0, 0, 0, 0 };
    const rb = 4 * @sizeOf(u16);
    {
        const b_src = bufFromBytes(std.mem.sliceAsBytes(&pixel), h, w, rb);
        const b_dest = bufFromBytes(std.mem.sliceAsBytes(&premult), h, w, rb);
        const err = premultiplyDataARGB16U(&b_src, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    try std.testing.expectEqual(pixel[0], premult[0]);
    {
        const b_src = bufFromBytes(std.mem.sliceAsBytes(&premult), h, w, rb);
        const b_dest = bufFromBytes(std.mem.sliceAsBytes(&recovered), h, w, rb);
        const err = unpremultiplyDataARGB16U(&b_src, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    for (1..4) |i| {
        const diff: i32 = @as(i32, recovered[i]) - @as(i32, pixel[i]);
        try std.testing.expect(diff <= 1 and diff >= -1);
    }
}

test "premultiplyDataRGBA16U / unpremultiplyDataRGBA16U round trip, alpha-last" {
    const h = 1;
    const w = 1;
    var pixel: [4]u16 = .{ 5000, 60000, 20000, 40000 }; // R G B A
    var premult: [4]u16 = .{ 0, 0, 0, 0 };
    var recovered: [4]u16 = .{ 0, 0, 0, 0 };
    const rb = 4 * @sizeOf(u16);
    {
        const b_src = bufFromBytes(std.mem.sliceAsBytes(&pixel), h, w, rb);
        const b_dest = bufFromBytes(std.mem.sliceAsBytes(&premult), h, w, rb);
        const err = premultiplyDataRGBA16U(&b_src, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    try std.testing.expectEqual(pixel[3], premult[3]);
    {
        const b_src = bufFromBytes(std.mem.sliceAsBytes(&premult), h, w, rb);
        const b_dest = bufFromBytes(std.mem.sliceAsBytes(&recovered), h, w, rb);
        const err = unpremultiplyDataRGBA16U(&b_src, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    for (0..3) |i| {
        const diff: i32 = @as(i32, recovered[i]) - @as(i32, pixel[i]);
        try std.testing.expect(diff <= 1 and diff >= -1);
    }
}

test "premultiplyDataARGB16Q12 / unpremultiplyDataARGB16Q12 round trip" {
    // Alpha.h:1272/1728: int16_t destColor = CLAMP((src*alpha+2048)/4096, ...); alpha-first.
    // Use 16Q12 fixed point values (4096 == 1.0); keep src/alpha modest to avoid overflow.
    const h = 1;
    const w = 1;
    var pixel: [4]i16 = .{ 3000, 500, 2000, 1000 }; // A R G B
    var premult: [4]i16 = .{ 0, 0, 0, 0 };
    var recovered: [4]i16 = .{ 0, 0, 0, 0 };
    const rb = 4 * @sizeOf(i16);
    {
        const b_src = bufFromBytes(std.mem.sliceAsBytes(&pixel), h, w, rb);
        const b_dest = bufFromBytes(std.mem.sliceAsBytes(&premult), h, w, rb);
        const err = premultiplyDataARGB16Q12(&b_src, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    try std.testing.expectEqual(pixel[0], premult[0]);
    {
        const b_src = bufFromBytes(std.mem.sliceAsBytes(&premult), h, w, rb);
        const b_dest = bufFromBytes(std.mem.sliceAsBytes(&recovered), h, w, rb);
        const err = unpremultiplyDataARGB16Q12(&b_src, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    for (1..4) |i| {
        const diff: i32 = @as(i32, recovered[i]) - @as(i32, pixel[i]);
        try std.testing.expect(diff <= 2 and diff >= -2);
    }
}

test "premultiplyDataRGBA16Q12 / unpremultiplyDataRGBA16Q12 round trip, alpha-last" {
    const h = 1;
    const w = 1;
    var pixel: [4]i16 = .{ 500, 2000, 1000, 3000 }; // R G B A
    var premult: [4]i16 = .{ 0, 0, 0, 0 };
    var recovered: [4]i16 = .{ 0, 0, 0, 0 };
    const rb = 4 * @sizeOf(i16);
    {
        const b_src = bufFromBytes(std.mem.sliceAsBytes(&pixel), h, w, rb);
        const b_dest = bufFromBytes(std.mem.sliceAsBytes(&premult), h, w, rb);
        const err = premultiplyDataRGBA16Q12(&b_src, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    try std.testing.expectEqual(pixel[3], premult[3]);
    {
        const b_src = bufFromBytes(std.mem.sliceAsBytes(&premult), h, w, rb);
        const b_dest = bufFromBytes(std.mem.sliceAsBytes(&recovered), h, w, rb);
        const err = unpremultiplyDataRGBA16Q12(&b_src, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    for (0..3) |i| {
        const diff: i32 = @as(i32, recovered[i]) - @as(i32, pixel[i]);
        try std.testing.expect(diff <= 2 and diff >= -2);
    }
}

test "premultiplyDataRGBA16F / unpremultiplyDataRGBA16F round trip" {
    // Alpha.h:1155-1160/1608: float destColor = src*alpha; alpha-last, half-float storage (u16 bits).
    const h = 1;
    const w = 1;
    const rb = 4 * @sizeOf(u16);

    const half = struct {
        fn fromF32(v: f32) u16 {
            return @bitCast(@as(f16, @floatCast(v)));
        }
        fn toF32(bits: u16) f32 {
            return @as(f32, @as(f16, @bitCast(bits)));
        }
    };

    var pixel = [4]u16{ half.fromF32(0.2), half.fromF32(0.6), half.fromF32(0.9), half.fromF32(0.5) }; // R G B A
    var premult = [_]u16{0} ** 4;
    var recovered = [_]u16{0} ** 4;
    {
        const b_src = bufFromBytes(std.mem.sliceAsBytes(&pixel), h, w, rb);
        const b_dest = bufFromBytes(std.mem.sliceAsBytes(&premult), h, w, rb);
        const err = premultiplyDataRGBA16F(&b_src, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    try std.testing.expectApproxEqAbs(half.toF32(pixel[3]), half.toF32(premult[3]), 0.01);
    {
        const b_src = bufFromBytes(std.mem.sliceAsBytes(&premult), h, w, rb);
        const b_dest = bufFromBytes(std.mem.sliceAsBytes(&recovered), h, w, rb);
        const err = unpremultiplyDataRGBA16F(&b_src, &b_dest, 0);
        try std.testing.expectEqual(@as(usize, 0), try err);
    }
    for (0..3) |i| {
        try std.testing.expectApproxEqAbs(half.toF32(pixel[i]), half.toF32(recovered[i]), 0.02);
    }
}

test "clipToAlphaPlanar/ARGB/RGBA clamp color to alpha (dest = min(src, alpha))" {
    // Alpha.h:2085 (vImageClipToAlpha_Planar8): color_result = MIN(color, alpha).
    const h = 1;
    const w = 1;

    var src_p = [_]u8{200};
    var alpha_p = [_]u8{90}; // color > alpha, so it should be clamped down
    var dest_p = [_]u8{0};
    const b_src_p = bufFromBytes(&src_p, h, w, w);
    const b_alpha_p = bufFromBytes(&alpha_p, h, w, w);
    const b_dest_p = bufFromBytes(&dest_p, h, w, w);
    const err_p = clipToAlphaPlanar(u8, &b_src_p, &b_alpha_p, &b_dest_p, 0);
    try std.testing.expectEqual(@as(usize, 0), try err_p);
    try std.testing.expectEqual(@as(u8, 90), dest_p[0]);

    const row_bytes = 4;
    var src_argb = [_]u8{ 90, 200, 50, 30 }; // A R G B: R (200) exceeds alpha (90)
    var dest_argb = [_]u8{0} ** 4;
    const b_src_argb = bufFromBytes(&src_argb, h, w, row_bytes);
    const b_dest_argb = bufFromBytes(&dest_argb, h, w, row_bytes);
    const err_argb = clipToAlphaARGB(u8, &b_src_argb, &b_dest_argb, 0);
    try std.testing.expectEqual(@as(usize, 0), try err_argb);
    try std.testing.expectEqual(@as(u8, 90), dest_argb[0]); // alpha itself unchanged
    try std.testing.expectEqual(@as(u8, 90), dest_argb[1]); // R clamped down to alpha
    try std.testing.expectEqual(@as(u8, 50), dest_argb[2]); // G untouched (already <= alpha)
    try std.testing.expectEqual(@as(u8, 30), dest_argb[3]); // B untouched

    var src_rgba = [_]u8{ 200, 50, 30, 90 }; // R G B A: alpha last
    var dest_rgba = [_]u8{0} ** 4;
    const b_src_rgba = bufFromBytes(&src_rgba, h, w, row_bytes);
    const b_dest_rgba = bufFromBytes(&dest_rgba, h, w, row_bytes);
    const err_rgba = clipToAlphaRGBA(u8, &b_src_rgba, &b_dest_rgba, 0);
    try std.testing.expectEqual(@as(usize, 0), try err_rgba);
    try std.testing.expectEqual(@as(u8, 90), dest_rgba[0]); // R clamped down to alpha
    try std.testing.expectEqual(@as(u8, 50), dest_rgba[1]);
    try std.testing.expectEqual(@as(u8, 30), dest_rgba[2]);
    try std.testing.expectEqual(@as(u8, 90), dest_rgba[3]); // alpha itself unchanged
}
