//! Flattening against an opaque background, and arbitrary chunky/planar
//! de-interleaving (`vImage/Conversion.h`).
//!
//! ## Flatten
//!
//! A flatten is an alpha composite of one image over a solid, opaque
//! background colour. There is no second image and no alpha-out: the result is
//! the source laid over `backgroundColor`, in the same pixel format as the
//! source.
//!
//! The background colour is always passed *premultiplied* and always in the
//! same channel order as the image, so `flattenRGBA8888` wants
//! `.{ R, G, B, A }` while `flattenARGB8888` wants `.{ A, R, G, B }`. Because
//! the C parameter is an array type it decays to a pointer, so every wrapper
//! here takes `*const [4]T`, not a by-value array.
//!
//! `isImagePremultiplied` selects between two formulas. Writing `S` for the
//! full-scale value of the format:
//!
//!     resultAlpha = (a*S + (S - a)*bgA + S/2) / S
//!     premultiplied:      resultColor = (color*S + (S - a)*bgColor + S/2) / S
//!     not premultiplied:  resultColor = (color*a + (S - a)*bgColor + S/2) / S
//!
//! The scale `S` per format:
//!
//!   * `8888`  - `S = 255`, unsigned 8-bit, integer divide.
//!   * `16U`   - `S = 65535`, unsigned 16-bit, integer divide.
//!   * `16Q12` - `S = 4096`, signed 4.12 fixed point where 4096 means 1.0 and
//!     the representable range is roughly [-8.0, 8.0). Alpha is clamped to
//!     [0, 4096] first; the division is an arithmetic `>> 12`. Whether colour
//!     results with `|value| >= 8.0` are clamped is explicitly undefined.
//!   * `FFFF`  - `S = 1.0`, `float`, so the rounding term drops out and the
//!     premultiplied form is exactly `color + (1 - a)*bgColor`.
//!
//! All flatten entry points can work in place.
//!
//! ## ChunkyToPlanar / PlanarToChunky
//!
//! These are the escape hatch for interleaved layouts vImage has no dedicated
//! converter for: any channel count, any pixel stride. The element type is
//! either `uint8_t` (the `8` variants) or `float` (the `F` variants).
//!
//! The interleaved side is *not* described by a `vImage_Buffer`. It is
//! described by four separate values:
//!
//!   * an array of one pointer per channel, each pointing at that channel
//!     inside the **first pixel of the first row** - so for tightly packed
//!     RGB8 you pass `.{ base, base + 1, base + 2 }`, and you can reorder or
//!     skip channels just by reordering those pointers;
//!   * `srcStrideBytes` / `destStrideBytes`, the distance in bytes from one
//!     pixel to the next (4 for RGBX8888 even though only 3 channels are
//!     converted; 16 for an XYZ-in-float4 layout);
//!   * `srcWidth` / `srcHeight` in pixels;
//!   * `srcRowBytes` / `destRowBytes`, the distance in bytes between rows,
//!     which may exceed `width * strideBytes`.
//!
//! The planar side is an array of `channelCount` `vImage_Buffer`s, one per
//! channel, each `width` x `height` of the element type. The wrappers take
//! both arrays as slices and derive `channelCount` from the length; the two
//! slices must be the same length.
//!
//! Neither direction works in place. The header carries a performance
//! advisory: these are too general to vectorise well, so prefer a dedicated
//! converter when one exists for your format.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const Error = types.Error;
const check = types.check;
const vImage_Flags = types.vImage_Flags;
const vImagePixelCount = types.vImagePixelCount;
const Pixel_8888 = types.Pixel_8888;
const Pixel_FFFF = types.Pixel_FFFF;
const Pixel_ARGB_16U = types.Pixel_ARGB_16U;
const Pixel_ARGB_16S = types.Pixel_ARGB_16S;
const Flags = types.Flags;
const Options = types.Options;

// ============================================================================
// Flatten
// ============================================================================

/// Composite an 8-bit ARGB image over the opaque colour `backgroundColor`
/// (given as premultiplied `.{ A, R, G, B }`).
///
/// `is_premultiplied` describes the *source*: when true the colour channels
/// are already scaled by alpha and are used as-is, when false they are
/// multiplied by alpha first. Rounding is `+127` then integer divide by 255.
/// Works in place.
pub fn flattenARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, backgroundColor: *const Pixel_8888, is_premultiplied: bool, flags: Options) Error!usize {
    return check(c.vImageFlatten_ARGB8888(src, dest, backgroundColor, is_premultiplied, flags.bits()));
}

/// Composite an 8-bit RGBA image over the opaque colour `backgroundColor`
/// (given as premultiplied `.{ R, G, B, A }` - alpha last, matching the image).
///
/// Same arithmetic as `flattenARGB8888`; only the channel position of alpha
/// differs. Works in place.
pub fn flattenRGBA8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, backgroundColor: *const Pixel_8888, is_premultiplied: bool, flags: Options) Error!usize {
    return check(c.vImageFlatten_RGBA8888(src, dest, backgroundColor, is_premultiplied, flags.bits()));
}

/// Composite a 16-bit unsigned ARGB image over the opaque colour
/// `backgroundColor` (premultiplied `.{ A, R, G, B }`).
///
/// Full scale is 65535; rounding is `+32767` then integer divide by 65535.
/// Pixels are native-endian. Works in place.
pub fn flattenARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, backgroundColor: *const Pixel_ARGB_16U, is_premultiplied: bool, flags: Options) Error!usize {
    return check(c.vImageFlatten_ARGB16U(src, dest, backgroundColor, is_premultiplied, flags.bits()));
}

/// Composite a 16-bit unsigned RGBA image over the opaque colour
/// `backgroundColor` (premultiplied `.{ R, G, B, A }`).
///
/// As `flattenARGB16U`, with alpha in the last channel. Works in place.
pub fn flattenRGBA16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, backgroundColor: *const Pixel_ARGB_16U, is_premultiplied: bool, flags: Options) Error!usize {
    return check(c.vImageFlatten_RGBA16U(src, dest, backgroundColor, is_premultiplied, flags.bits()));
}

/// Composite a signed 4.12 fixed-point ARGB image over the opaque colour
/// `backgroundColor` (premultiplied `.{ A, R, G, B }`, same 4.12 encoding).
///
/// 4096 encodes 1.0. Alpha is clamped to [0, 4096] before compositing; colour
/// channels are not clamped, and whether a result of magnitude >= 8.0 is
/// clamped is undefined. Rounding is `+2048` then arithmetic `>> 12`.
/// Native-endian, works in place.
pub fn flattenARGB16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, backgroundColor: *const Pixel_ARGB_16S, is_premultiplied: bool, flags: Options) Error!usize {
    return check(c.vImageFlatten_ARGB16Q12(src, dest, backgroundColor, is_premultiplied, flags.bits()));
}

/// Composite a signed 4.12 fixed-point RGBA image over the opaque colour
/// `backgroundColor` (premultiplied `.{ R, G, B, A }`, same 4.12 encoding).
///
/// As `flattenARGB16Q12`, with alpha in the last channel. The header declares
/// this one with the ARGB parameter names verbatim; it is nonetheless a
/// distinct symbol that reads alpha from channel 3.
pub fn flattenRGBA16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, backgroundColor: *const Pixel_ARGB_16S, is_premultiplied: bool, flags: Options) Error!usize {
    return check(c.vImageFlatten_RGBA16Q12(src, dest, backgroundColor, is_premultiplied, flags.bits()));
}

/// Composite a float ARGB image over the opaque colour `backgroundColor`
/// (premultiplied `.{ A, R, G, B }`).
///
/// Exactly `result = color + (1 - a)*bgColor` when premultiplied, or
/// `color*a + (1 - a)*bgColor` when not. No clamping, so values outside
/// [0, 1] pass through the formula unchanged. Works in place.
pub fn flattenARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, backgroundColor: *const Pixel_FFFF, is_premultiplied: bool, flags: Options) Error!usize {
    return check(c.vImageFlatten_ARGBFFFF(src, dest, backgroundColor, is_premultiplied, flags.bits()));
}

/// Composite a float RGBA image over the opaque colour `backgroundColor`
/// (premultiplied `.{ R, G, B, A }`).
///
/// As `flattenARGBFFFF`, with alpha in the last channel. Works in place.
pub fn flattenRGBAFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, backgroundColor: *const Pixel_FFFF, is_premultiplied: bool, flags: Options) Error!usize {
    return check(c.vImageFlatten_RGBAFFFF(src, dest, backgroundColor, is_premultiplied, flags.bits()));
}

// ============================================================================
// Chunky <-> planar, arbitrary channel count and stride
// ============================================================================

/// De-interleave an 8-bit interleaved image into one planar buffer per channel.
///
/// `srcChannels[i]` points at channel `i` within the first pixel of the first
/// row of the interleaved image; `srcStrideBytes` is the byte distance between
/// consecutive pixels (which may be larger than `srcChannels.len`, e.g. 4 for
/// RGBX8888) and `srcRowBytes` the byte distance between rows.
///
/// `destPlanarBuffers` must have the same length as `srcChannels`, and each
/// buffer must be at least `srcWidth` x `srcHeight` bytes. Does not work in
/// place.
pub fn chunkyToPlanar8(
    srcChannels: []const *const anyopaque,
    destPlanarBuffers: []const *const vImage_Buffer,
    srcStrideBytes: usize,
    srcWidth: vImagePixelCount,
    srcHeight: vImagePixelCount,
    srcRowBytes: usize,
    flags: Options,
) Error!usize {
    std.debug.assert(srcChannels.len == destPlanarBuffers.len);
    return check(c.vImageConvert_ChunkyToPlanar8(
        @ptrCast(srcChannels.ptr),
        destPlanarBuffers.ptr,
        @intCast(srcChannels.len),
        srcStrideBytes,
        srcWidth,
        srcHeight,
        srcRowBytes,
        flags.bits(),
    ));
}

/// De-interleave a float interleaved image into one PlanarF buffer per channel.
///
/// Identical addressing rules to `chunkyToPlanar8`, but the element is a
/// 4-byte `float`, so `srcStrideBytes` is a multiple of 4 for any sane layout
/// (12 for tight XYZ, 16 for XYZ padded to float4). Each destination buffer
/// needs `srcWidth * 4` bytes per row. Does not work in place.
pub fn chunkyToPlanarF(
    srcChannels: []const *const anyopaque,
    destPlanarBuffers: []const *const vImage_Buffer,
    srcStrideBytes: usize,
    srcWidth: vImagePixelCount,
    srcHeight: vImagePixelCount,
    srcRowBytes: usize,
    flags: Options,
) Error!usize {
    std.debug.assert(srcChannels.len == destPlanarBuffers.len);
    return check(c.vImageConvert_ChunkyToPlanarF(
        @ptrCast(srcChannels.ptr),
        destPlanarBuffers.ptr,
        @intCast(srcChannels.len),
        srcStrideBytes,
        srcWidth,
        srcHeight,
        srcRowBytes,
        flags.bits(),
    ));
}

/// Interleave one 8-bit planar buffer per channel into a single chunky image.
///
/// The inverse of `chunkyToPlanar8`: `destChannels[i]` points at where channel
/// `i` of the first pixel of the first row should land, `destStrideBytes` is
/// the byte distance between pixels and `destRowBytes` between rows. Bytes of
/// the destination that no channel pointer covers (padding in an RGBX layout,
/// or row padding) are left untouched. Does not work in place.
pub fn planarToChunky8(
    srcPlanarBuffers: []const *const vImage_Buffer,
    destChannels: []const *anyopaque,
    destStrideBytes: usize,
    destWidth: vImagePixelCount,
    destHeight: vImagePixelCount,
    destRowBytes: usize,
    flags: Options,
) Error!usize {
    std.debug.assert(srcPlanarBuffers.len == destChannels.len);
    return check(c.vImageConvert_PlanarToChunky8(
        srcPlanarBuffers.ptr,
        @ptrCast(destChannels.ptr),
        @intCast(destChannels.len),
        destStrideBytes,
        destWidth,
        destHeight,
        destRowBytes,
        flags.bits(),
    ));
}

/// Interleave one PlanarF buffer per channel into a single chunky float image.
///
/// The inverse of `chunkyToPlanarF`; see `planarToChunky8` for the addressing
/// rules. Destination bytes not covered by a channel pointer are left
/// untouched. Does not work in place.
pub fn planarToChunkyF(
    srcPlanarBuffers: []const *const vImage_Buffer,
    destChannels: []const *anyopaque,
    destStrideBytes: usize,
    destWidth: vImagePixelCount,
    destHeight: vImagePixelCount,
    destRowBytes: usize,
    flags: Options,
) Error!usize {
    std.debug.assert(srcPlanarBuffers.len == destChannels.len);
    return check(c.vImageConvert_PlanarToChunkyF(
        srcPlanarBuffers.ptr,
        @ptrCast(destChannels.ptr),
        @intCast(destChannels.len),
        destStrideBytes,
        destWidth,
        destHeight,
        destRowBytes,
        flags.bits(),
    ));
}

// ============================================================================
// Tests
// ============================================================================

fn bufFromBytes(data: []u8, height: usize, width: usize, rowBytes: usize) vImage_Buffer {
    return .{ .data = data.ptr, .height = height, .width = width, .rowBytes = rowBytes };
}

test "flattenARGB8888 premultiplied matches the Conversion.h formula byte for byte" {
    // Conversion.h vImageFlatten_ARGB8888:
    //   resultAlpha = (a*255 + (255-a)*bgA + 127) / 255
    //   resultColor = (color*255 + (255-a)*bgColor + 127) / 255   (premultiplied)
    // src pixel A=128 R=64 G=32 B=16 (premultiplied), bg = A=255 R=100 G=200 B=50.
    //   A: (128*255 + 127*255 + 127)/255 = 65152/255 = 255 (saturating at 255)
    //   R: (64*255  + 127*100 + 127)/255 = 29147/255 = 114
    //   G: (32*255  + 127*200 + 127)/255 = 33687/255 = 132
    //   B: (16*255  + 127*50  + 127)/255 = 10557/255 = 41
    const h = 2;
    const w = 2;
    const row_bytes = 12; // deliberately padded; tight would be 8
    const bytes = h * row_bytes;
    const src = try std.testing.allocator.alloc(u8, bytes);
    defer std.testing.allocator.free(src);
    const dst = try std.testing.allocator.alloc(u8, bytes);
    defer std.testing.allocator.free(dst);
    @memset(src, 0);
    @memset(dst, 0xAA);

    for (0..h) |y| {
        for (0..w) |x| {
            const off = y * row_bytes + x * 4;
            src[off + 0] = 128; // A
            src[off + 1] = 64; // R
            src[off + 2] = 32; // G
            src[off + 3] = 16; // B
        }
    }

    const b_src = bufFromBytes(src, h, w, row_bytes);
    const b_dst = bufFromBytes(dst, h, w, row_bytes);
    const bg: Pixel_8888 = .{ 255, 100, 200, 50 };

    try std.testing.expectEqual(@as(usize, 0), try flattenARGB8888(&b_src, &b_dst, &bg, true, .{}));

    for (0..h) |y| {
        for (0..w) |x| {
            const off = y * row_bytes + x * 4;
            try std.testing.expectEqual(@as(u8, 255), dst[off + 0]);
            try std.testing.expectEqual(@as(u8, 114), dst[off + 1]);
            try std.testing.expectEqual(@as(u8, 132), dst[off + 2]);
            try std.testing.expectEqual(@as(u8, 41), dst[off + 3]);
        }
    }
    // Row padding must be untouched.
    try std.testing.expectEqual(@as(u8, 0xAA), dst[row_bytes - 1]);
}

test "flattenARGB8888 non-premultiplied multiplies colour by alpha first" {
    // resultColor = (color*a + (255-a)*bgColor + 127) / 255
    // src A=128 R=200 G=0 B=255, bg A=255 R=10 G=20 B=30.
    //   A: (128*255 + 127*255 + 127)/255 = 255
    //   R: (200*128 + 127*10 + 127)/255 = (25600+1270+127)/255 = 26997/255 = 105
    //   G: (0*128   + 127*20 + 127)/255 = 2667/255 = 10
    //   B: (255*128 + 127*30 + 127)/255 = (32640+3810+127)/255 = 36577/255 = 143
    var px = [_]u8{ 128, 200, 0, 255 };
    const b = bufFromBytes(&px, 1, 1, 4);
    const bg: Pixel_8888 = .{ 255, 10, 20, 30 };

    // In place, which the header documents as supported.
    try std.testing.expectEqual(@as(usize, 0), try flattenARGB8888(&b, &b, &bg, false, .{}));
    try std.testing.expectEqual([_]u8{ 255, 105, 10, 143 }, px);
}

test "flattenRGBA8888 reads alpha from the last channel, not the first" {
    // Same numbers as the ARGB premultiplied test but rotated so alpha is last:
    // src R=64 G=32 B=16 A=128, bg R=100 G=200 B=50 A=255 -> {114,132,41,255}.
    // If this dispatched to the ARGB entry point the result would be different,
    // so this doubles as an argument-order check.
    var px = [_]u8{ 64, 32, 16, 128 };
    var out = [_]u8{0} ** 4;
    const b_src = bufFromBytes(&px, 1, 1, 4);
    const b_dst = bufFromBytes(&out, 1, 1, 4);
    const bg: Pixel_8888 = .{ 100, 200, 50, 255 };

    try std.testing.expectEqual(@as(usize, 0), try flattenRGBA8888(&b_src, &b_dst, &bg, true, .{}));
    try std.testing.expectEqual([_]u8{ 114, 132, 41, 255 }, out);
}

test "flattenARGBFFFF and flattenRGBAFFFF are exact: color + (1-a)*bg" {
    // a = 0.25, so (1-a) = 0.75.
    //   A: 0.25 + 0.75*1.0   = 1.0
    //   R: 0.1  + 0.75*0.5   = 0.475
    //   G: 0.2  + 0.75*0.25  = 0.3875
    //   B: 0.05 + 0.75*0.125 = 0.14375
    var argb = [_]f32{ 0.25, 0.1, 0.2, 0.05 };
    var rgba = [_]f32{ 0.1, 0.2, 0.05, 0.25 };
    const b_argb = bufFromBytes(std.mem.sliceAsBytes(&argb), 1, 1, 16);
    const b_rgba = bufFromBytes(std.mem.sliceAsBytes(&rgba), 1, 1, 16);
    const bg_argb: Pixel_FFFF = .{ 1.0, 0.5, 0.25, 0.125 };
    const bg_rgba: Pixel_FFFF = .{ 0.5, 0.25, 0.125, 1.0 };

    try std.testing.expectEqual(@as(usize, 0), try flattenARGBFFFF(&b_argb, &b_argb, &bg_argb, true, .{}));
    try std.testing.expectEqual(@as(usize, 0), try flattenRGBAFFFF(&b_rgba, &b_rgba, &bg_rgba, true, .{}));

    try std.testing.expectApproxEqAbs(@as(f32, 1.0), argb[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.475), argb[1], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3875), argb[2], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.14375), argb[3], 1e-6);

    // Same result, rotated: alpha last.
    try std.testing.expectApproxEqAbs(@as(f32, 0.475), rgba[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.3875), rgba[1], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 0.14375), rgba[2], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), rgba[3], 1e-6);
}

test "flattenARGB16U and flattenRGBA16U scale by 65535" {
    const S: u64 = 65535;
    const a: u64 = 20000;
    const src_argb = [_]u16{ @intCast(a), 1000, 30000, 65535 };
    const bg_argb: Pixel_ARGB_16U = .{ 65535, 40000, 100, 12345 };

    var argb = src_argb;
    var rgba = [_]u16{ src_argb[1], src_argb[2], src_argb[3], src_argb[0] };
    const bg_rgba: Pixel_ARGB_16U = .{ bg_argb[1], bg_argb[2], bg_argb[3], bg_argb[0] };

    const b_argb = bufFromBytes(std.mem.sliceAsBytes(&argb), 1, 1, 8);
    const b_rgba = bufFromBytes(std.mem.sliceAsBytes(&rgba), 1, 1, 8);

    try std.testing.expectEqual(@as(usize, 0), try flattenARGB16U(&b_argb, &b_argb, &bg_argb, true, .{}));
    try std.testing.expectEqual(@as(usize, 0), try flattenRGBA16U(&b_rgba, &b_rgba, &bg_rgba, true, .{}));

    var expected: [4]u16 = undefined;
    for (0..4) |i| {
        const v = src_argb[i];
        const bgv = bg_argb[i];
        const num = if (i == 0)
            a * S + (S - a) * bgv + S / 2
        else
            @as(u64, v) * S + (S - a) * bgv + S / 2;
        expected[i] = @intCast(@min(num / S, S));
    }

    for (0..4) |i| {
        try std.testing.expectEqual(expected[i], argb[i]);
        // RGBA: alpha moved to the end, colours shifted down one slot.
        const rgba_i = if (i == 0) 3 else i - 1;
        try std.testing.expectEqual(argb[i], rgba[rgba_i]);
    }
}

test "flattenARGB16Q12 and flattenRGBA16Q12 use the 4096 = 1.0 fixed-point scale" {
    // resultX = (x*4096 + (4096-a)*bgX + 2048) >> 12, alpha clamped to [0,4096].
    // a = 1024 (0.25), so (4096-a) = 3072 (0.75).
    //   A: (1024*4096 + 3072*4096 + 2048) >> 12 = (4194304+12582912+2048)>>12 = 4096
    //   R: (2048*4096 + 3072*2048 + 2048) >> 12 = (8388608+6291456+2048)>>12  = 3584
    //   G: (0*4096    + 3072*4096 + 2048) >> 12 = 3072
    //   B: (-512*4096 + 3072*1024 + 2048) >> 12 = (-2097152+3145728+2048)>>12 = 256
    var argb = [_]i16{ 1024, 2048, 0, -512 };
    var rgba = [_]i16{ 2048, 0, -512, 1024 };
    const bg_argb: Pixel_ARGB_16S = .{ 4096, 2048, 4096, 1024 };
    const bg_rgba: Pixel_ARGB_16S = .{ 2048, 4096, 1024, 4096 };

    const b_argb = bufFromBytes(std.mem.sliceAsBytes(&argb), 1, 1, 8);
    const b_rgba = bufFromBytes(std.mem.sliceAsBytes(&rgba), 1, 1, 8);

    try std.testing.expectEqual(@as(usize, 0), try flattenARGB16Q12(&b_argb, &b_argb, &bg_argb, true, .{}));
    try std.testing.expectEqual(@as(usize, 0), try flattenRGBA16Q12(&b_rgba, &b_rgba, &bg_rgba, true, .{}));

    try std.testing.expectEqual([_]i16{ 4096, 3584, 3072, 256 }, argb);
    try std.testing.expectEqual([_]i16{ 3584, 3072, 256, 4096 }, rgba);
}

test "chunkyToPlanar8 de-interleaves 3 channels at stride 4 with padded rows" {
    const h = 2;
    const w = 3;
    const channels = 3;
    const stride = 4; // RGBX-style: a 4th byte per pixel that we do not convert
    const src_row_bytes = w * stride + 4; // padded rows
    const plane_row_bytes = 8; // padded planes (tight would be 3)

    const src = try std.testing.allocator.alloc(u8, h * src_row_bytes);
    defer std.testing.allocator.free(src);
    @memset(src, 0xEE);
    for (0..h) |y| {
        for (0..w) |x| {
            const off = y * src_row_bytes + x * stride;
            src[off + 0] = @intCast(10 * y + x);
            src[off + 1] = @intCast(100 + 10 * y + x);
            src[off + 2] = @intCast(200 + 10 * y + x);
            src[off + 3] = 0x77; // ignored channel
        }
    }

    var planes: [channels][]u8 = undefined;
    for (&planes) |*p| {
        p.* = try std.testing.allocator.alloc(u8, h * plane_row_bytes);
        @memset(p.*, 0);
    }
    defer for (planes) |p| std.testing.allocator.free(p);

    var bufs: [channels]vImage_Buffer = undefined;
    for (&bufs, planes) |*b, p| b.* = bufFromBytes(p, h, w, plane_row_bytes);
    const buf_ptrs = [channels]*const vImage_Buffer{ &bufs[0], &bufs[1], &bufs[2] };

    const base: [*]u8 = src.ptr;
    const chans = [channels]*const anyopaque{ base, base + 1, base + 2 };

    try std.testing.expectEqual(@as(usize, 0), try chunkyToPlanar8(&chans, &buf_ptrs, stride, w, h, src_row_bytes, .{}));

    for (0..h) |y| {
        for (0..w) |x| {
            try std.testing.expectEqual(@as(u8, @intCast(10 * y + x)), planes[0][y * plane_row_bytes + x]);
            try std.testing.expectEqual(@as(u8, @intCast(100 + 10 * y + x)), planes[1][y * plane_row_bytes + x]);
            try std.testing.expectEqual(@as(u8, @intCast(200 + 10 * y + x)), planes[2][y * plane_row_bytes + x]);
        }
    }
}

test "planarToChunky8 round-trips 3 channels through a different stride and channel order" {
    const h = 2;
    const w = 3;
    const channels = 3;
    const src_stride = 4;
    const src_row_bytes = w * src_stride + 4;

    const src = try std.testing.allocator.alloc(u8, h * src_row_bytes);
    defer std.testing.allocator.free(src);
    @memset(src, 0xEE);
    for (0..h) |y| {
        for (0..w) |x| {
            const off = y * src_row_bytes + x * src_stride;
            src[off + 0] = @intCast(10 * y + x);
            src[off + 1] = @intCast(100 + 10 * y + x);
            src[off + 2] = @intCast(200 + 10 * y + x);
        }
    }

    const plane_row_bytes = 8;
    var planes: [channels][]u8 = undefined;
    for (&planes) |*p| {
        p.* = try std.testing.allocator.alloc(u8, h * plane_row_bytes);
        @memset(p.*, 0);
    }
    defer for (planes) |p| std.testing.allocator.free(p);

    var bufs: [channels]vImage_Buffer = undefined;
    for (&bufs, planes) |*b, p| b.* = bufFromBytes(p, h, w, plane_row_bytes);
    const buf_ptrs = [channels]*const vImage_Buffer{ &bufs[0], &bufs[1], &bufs[2] };

    const src_base: [*]u8 = src.ptr;
    const src_chans = [channels]*const anyopaque{ src_base, src_base + 1, src_base + 2 };
    _ = try chunkyToPlanar8(&src_chans, &buf_ptrs, src_stride, w, h, src_row_bytes, .{});

    // Re-interleave tightly (stride 3), reversed channel order, padded rows.
    const dst_stride = 3;
    const dst_row_bytes = w * dst_stride + 3;
    const dst = try std.testing.allocator.alloc(u8, h * dst_row_bytes);
    defer std.testing.allocator.free(dst);
    @memset(dst, 0x5A);

    const dst_base: [*]u8 = dst.ptr;
    // channel 0 -> byte 2, channel 1 -> byte 1, channel 2 -> byte 0.
    const dst_chans = [channels]*anyopaque{ dst_base + 2, dst_base + 1, dst_base };

    try std.testing.expectEqual(@as(usize, 0), try planarToChunky8(&buf_ptrs, &dst_chans, dst_stride, w, h, dst_row_bytes, .{}));

    for (0..h) |y| {
        for (0..w) |x| {
            const off = y * dst_row_bytes + x * dst_stride;
            try std.testing.expectEqual(@as(u8, @intCast(200 + 10 * y + x)), dst[off + 0]);
            try std.testing.expectEqual(@as(u8, @intCast(100 + 10 * y + x)), dst[off + 1]);
            try std.testing.expectEqual(@as(u8, @intCast(10 * y + x)), dst[off + 2]);
        }
    }
    // Row padding is not written.
    for (0..h) |y| {
        for (w * dst_stride..dst_row_bytes) |i| {
            try std.testing.expectEqual(@as(u8, 0x5A), dst[y * dst_row_bytes + i]);
        }
    }
}

test "chunkyToPlanarF / planarToChunkyF round-trip 3 float channels at a float4 stride" {
    const h = 2;
    const w = 2;
    const channels = 3;
    const stride = 16; // three valid floats padded out to a float4
    const src_row_bytes = w * stride;

    const src = try std.testing.allocator.alloc(u8, h * src_row_bytes);
    defer std.testing.allocator.free(src);
    @memset(src, 0);

    const value = struct {
        fn at(ch: usize, y: usize, x: usize) f32 {
            return @as(f32, @floatFromInt(ch)) * 100.0 + @as(f32, @floatFromInt(y)) * 10.0 + @as(f32, @floatFromInt(x)) + 0.5;
        }
    };

    for (0..h) |y| {
        for (0..w) |x| {
            for (0..channels) |ch| {
                const off = y * src_row_bytes + x * stride + ch * 4;
                std.mem.bytesAsValue(f32, src[off..][0..4]).* = value.at(ch, y, x);
            }
        }
    }

    const plane_row_bytes = 16; // padded; tight would be w*4 = 8
    var planes: [channels][]u8 = undefined;
    for (&planes) |*p| {
        p.* = try std.testing.allocator.alloc(u8, h * plane_row_bytes);
        @memset(p.*, 0);
    }
    defer for (planes) |p| std.testing.allocator.free(p);

    var bufs: [channels]vImage_Buffer = undefined;
    for (&bufs, planes) |*b, p| b.* = bufFromBytes(p, h, w, plane_row_bytes);
    const buf_ptrs = [channels]*const vImage_Buffer{ &bufs[0], &bufs[1], &bufs[2] };

    const base: [*]u8 = src.ptr;
    const chans = [channels]*const anyopaque{ base, base + 4, base + 8 };
    try std.testing.expectEqual(@as(usize, 0), try chunkyToPlanarF(&chans, &buf_ptrs, stride, w, h, src_row_bytes, .{}));

    for (0..channels) |ch| {
        for (0..h) |y| {
            for (0..w) |x| {
                const off = y * plane_row_bytes + x * 4;
                const got = std.mem.bytesAsValue(f32, planes[ch][off..][0..4]).*;
                try std.testing.expectEqual(value.at(ch, y, x), got);
            }
        }
    }

    // Interleave back, this time tightly packed at stride 12.
    const dst_stride = 12;
    const dst_row_bytes = w * dst_stride + 8;
    const dst = try std.testing.allocator.alloc(u8, h * dst_row_bytes);
    defer std.testing.allocator.free(dst);
    @memset(dst, 0);

    const dst_base: [*]u8 = dst.ptr;
    const dst_chans = [channels]*anyopaque{ dst_base, dst_base + 4, dst_base + 8 };
    try std.testing.expectEqual(@as(usize, 0), try planarToChunkyF(&buf_ptrs, &dst_chans, dst_stride, w, h, dst_row_bytes, .{}));

    for (0..h) |y| {
        for (0..w) |x| {
            for (0..channels) |ch| {
                const off = y * dst_row_bytes + x * dst_stride + ch * 4;
                const got = std.mem.bytesAsValue(f32, dst[off..][0..4]).*;
                try std.testing.expectEqual(value.at(ch, y, x), got);
            }
        }
    }
}

test "flatten rejects a destination larger than the source" {
    var src = [_]u8{0} ** 4;
    var dst = [_]u8{0} ** (4 * 4);
    const b_src = bufFromBytes(&src, 1, 1, 4);
    const b_dst = bufFromBytes(&dst, 2, 2, 8);
    const bg: Pixel_8888 = .{ 255, 0, 0, 0 };
    try std.testing.expectError(
        Error.RoiLargerThanInputBuffer,
        flattenARGB8888(&b_src, &b_dst, &bg, true, .{}),
    );
}
