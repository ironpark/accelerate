//! The vImage types declared in `vImage_Utilities.h` and
//! `vImage_CVUtilities.h` — the ones that mention a CoreGraphics or
//! CoreVideo type and so cannot live in `types.zig`.
//!
//! Available only when the package is built with `-Dcoregraphics=true`.

const std = @import("std");
const cg = @import("../cg/root.zig");
const types = @import("types.zig");

const CGFloat = cg.CGFloat;

// ============================================================================
// vImage_CGImageFormat
// ============================================================================

/// `vImage_CGImageFormat` — the complete description of a CoreGraphics image
/// format: channel depth, channel order, colour space and decode range.
///
/// The struct does **not** own `color_space` or `decode`. Both are borrowed
/// pointers that must outlive every call the format is passed to; the header
/// says so explicitly for `decode`, which is easy to get wrong with a stack
/// array.
pub const CGImageFormat = extern struct {
    /// Bits per colour component: one of 5, 8, 16 or 32.
    bitsPerComponent: u32,
    /// Bits per whole pixel. For a planar format this equals
    /// `bitsPerComponent`.
    bitsPerPixel: u32,
    /// Borrowed. Null is legal only for a mask.
    colorSpace: ?*cg.CGColorSpace = null,
    bitmapInfo: cg.BitmapInfo = .{},
    /// Reserved; must be 0.
    version: u32 = 0,
    /// Borrowed decode array — 2 `CGFloat`s per component giving the range
    /// each maps onto. Null means the default [0, 1].
    decode: ?[*]const CGFloat = null,
    renderingIntent: cg.RenderingIntent = .default,

    /// 8-bit-per-channel ARGB, alpha first and premultiplied — the format
    /// most vImage `ARGB8888` entry points expect.
    pub fn argb8888(color_space: *cg.CGColorSpace) CGImageFormat {
        return .{
            .bitsPerComponent = 8,
            .bitsPerPixel = 32,
            .colorSpace = color_space,
            .bitmapInfo = .{ .alpha = .premultiplied_first },
        };
    }

    /// 8-bit-per-channel RGBA, alpha last and premultiplied.
    pub fn rgba8888(color_space: *cg.CGColorSpace) CGImageFormat {
        return .{
            .bitsPerComponent = 8,
            .bitsPerPixel = 32,
            .colorSpace = color_space,
            .bitmapInfo = .{ .alpha = .premultiplied_last },
        };
    }

    /// 8-bit-per-channel BGRA, premultiplied — ARGB with a 32-bit
    /// little-endian byte swap, which is how CoreGraphics spells BGRA.
    pub fn bgra8888(color_space: *cg.CGColorSpace) CGImageFormat {
        return .{
            .bitsPerComponent = 8,
            .bitsPerPixel = 32,
            .colorSpace = color_space,
            .bitmapInfo = .{ .alpha = .premultiplied_first, .byte_order = .little32 },
        };
    }

    /// Single-channel 8-bit grayscale, no alpha.
    pub fn gray8(color_space: *cg.CGColorSpace) CGImageFormat {
        return .{
            .bitsPerComponent = 8,
            .bitsPerPixel = 8,
            .colorSpace = color_space,
            .bitmapInfo = .{ .alpha = .none },
        };
    }

    /// Four-channel 32-bit float ARGB, premultiplied.
    pub fn argbFFFF(color_space: *cg.CGColorSpace) CGImageFormat {
        return .{
            .bitsPerComponent = 32,
            .bitsPerPixel = 128,
            .colorSpace = color_space,
            .bitmapInfo = .{ .alpha = .premultiplied_first, .float_components = true },
        };
    }
};

// ============================================================================
// vImageBufferTypeCode
// ============================================================================

/// `vImageBufferTypeCode` — the identity of one buffer in the array
/// `vImageConvert_AnyToAny` consumes or produces.
///
/// A buffer-order list is terminated by `end_of_list`, which is why the value
/// is 0 rather than a channel.
pub const BufferTypeCode = enum(u32) {
    end_of_list = 0,
    color_space_channel_1 = 1,
    color_space_channel_2 = 2,
    color_space_channel_3 = 3,
    color_space_channel_4 = 4,
    color_space_channel_5 = 5,
    color_space_channel_6 = 6,
    color_space_channel_7 = 7,
    color_space_channel_8 = 8,
    color_space_channel_9 = 9,
    color_space_channel_10 = 10,
    color_space_channel_11 = 11,
    color_space_channel_12 = 12,
    color_space_channel_13 = 13,
    color_space_channel_14 = 14,
    color_space_channel_15 = 15,
    color_space_channel_16 = 16,
    /// The coverage (alpha) channel.
    alpha = 17,
    indexed = 18,
    /// A packed YCbCr buffer laid out per `CVPixelBuffer.h`.
    cv_pixel_buffer_ycbcr = 19,
    /// A luminance (Y') plane.
    luminance = 20,
    /// A two-channel interleaved chroma (CbCr) plane.
    chroma = 21,
    /// A blue-difference chroma (Cb) plane.
    cb = 22,
    /// A red-difference chroma (Cr) plane.
    cr = 23,
    /// A single interleaved buffer describable as a `CGImageFormat`. Always a
    /// singleton; before macOS 10.10 every `AnyToAny` buffer had this code.
    cg_format = 24,
    /// A single interleaved buffer *not* describable as a `CGImageFormat` and
    /// not YCbCr. Always a singleton.
    chunky = 25,
    _,

    // The convenience aliases from the header. These are not distinct values
    // — every one of them is `color_space_channel_N` under another name — so
    // they are declarations rather than enum members, which would be
    // duplicate tags.
    pub const monochrome: BufferTypeCode = .color_space_channel_1;
    pub const rgb_red: BufferTypeCode = .color_space_channel_1;
    pub const rgb_green: BufferTypeCode = .color_space_channel_2;
    pub const rgb_blue: BufferTypeCode = .color_space_channel_3;
    pub const cmyk_cyan: BufferTypeCode = .color_space_channel_1;
    pub const cmyk_magenta: BufferTypeCode = .color_space_channel_2;
    pub const cmyk_yellow: BufferTypeCode = .color_space_channel_3;
    pub const cmyk_black: BufferTypeCode = .color_space_channel_4;
    pub const xyz_x: BufferTypeCode = .color_space_channel_1;
    pub const xyz_y: BufferTypeCode = .color_space_channel_2;
    pub const xyz_z: BufferTypeCode = .color_space_channel_3;
    pub const lab_l: BufferTypeCode = .color_space_channel_1;
    pub const lab_a: BufferTypeCode = .color_space_channel_2;
    pub const lab_b: BufferTypeCode = .color_space_channel_3;

    /// `kvImageBufferTypeCode_UniqueFormatCount` — one past the last distinct
    /// code, for sizing a lookup table.
    pub const unique_format_count: u32 = 26;
};

// ============================================================================
// vImageChannelDescription / vImageMatrixType
// ============================================================================

/// `vImageChannelDescription` — the encoding range and clamp limits of one
/// channel, which is how "video range" formats are described.
///
/// For 8-bit video-range luminance this is `{ .min = 16, .zero = 16,
/// .full = 235, .max = 235 }`; for 8-bit chroma, `.zero` is 128 and `.full`
/// encodes 0.5 rather than 1.0.
pub const ChannelDescription = extern struct {
    /// Values below this are clamped up to it.
    min: CGFloat,
    /// The encoding of 0.0 (0.0 for chroma too — the *neutral* point).
    zero: CGFloat,
    /// The encoding of 1.0, or of 0.5 for chroma.
    full: CGFloat,
    /// Values above this are clamped down to it.
    max: CGFloat,
};

/// `vImageMatrixType` — which struct
/// `CVImageFormat.conversionMatrix` returned a pointer to.
pub const MatrixType = enum(u32) {
    /// The format needs no matrix; the pointer is null.
    none = 0,
    /// The pointer is a `vImage_ARGBToYpCbCrMatrix`.
    argb_to_ypcbcr = 1,
    _,
};

// ============================================================================
// Colour-space construction
// ============================================================================

/// `vImageTransferFunction` — a parametric transfer function, in the shape
/// every ITU/IEC gamma curve takes:
///
/// ```
/// R' = c0 * pow(c1 * R + c2, gamma) + c3     (R >= cutoff)
/// R' = c4 * R + c5                           (R <  cutoff)
/// ```
///
/// Pass `-inf` for `cutoff` to disable the linear segment entirely.
pub const TransferFunction = extern struct {
    c0: CGFloat,
    c1: CGFloat,
    c2: CGFloat,
    c3: CGFloat,
    gamma: CGFloat,
    /// The breakpoint between the power segment and the linear one.
    cutoff: CGFloat,
    c4: CGFloat,
    c5: CGFloat,

    /// A pure power law with no linear toe: `R' = pow(R, gamma)`.
    pub fn gammaOnly(g: CGFloat) TransferFunction {
        return .{
            .c0 = 1,
            .c1 = 1,
            .c2 = 0,
            .c3 = 0,
            .gamma = g,
            .cutoff = -std.math.inf(CGFloat),
            .c4 = 0,
            .c5 = 0,
        };
    }

    /// The sRGB transfer function.
    pub const srgb: TransferFunction = .{
        .c0 = 1.055,
        .c1 = 1.0,
        .c2 = 0.0,
        .c3 = -0.055,
        .gamma = 1.0 / 2.4,
        .cutoff = 0.0031308,
        .c4 = 12.92,
        .c5 = 0.0,
    };

    /// The ITU-R BT.709 transfer function.
    pub const itur_709: TransferFunction = .{
        .c0 = 1.099,
        .c1 = 1.0,
        .c2 = 0.0,
        .c3 = -0.099,
        .gamma = 0.45,
        .cutoff = 0.018,
        .c4 = 4.5,
        .c5 = 0.0,
    };
};

/// `vImageRGBPrimaries` — CIE xy chromaticities of the three primaries and
/// the white point.
///
/// Note the field order in the C struct: all four x coordinates come first,
/// then all four y coordinates. It is not four `{x, y}` pairs.
pub const RGBPrimaries = extern struct {
    red_x: f32,
    green_x: f32,
    blue_x: f32,
    white_x: f32,
    red_y: f32,
    green_y: f32,
    blue_y: f32,
    white_y: f32,

    /// The ITU-R BT.709 / sRGB primaries with a D65 white point.
    pub const itur_709: RGBPrimaries = .{
        .red_x = 0.640,
        .green_x = 0.300,
        .blue_x = 0.150,
        .white_x = 0.3127,
        .red_y = 0.330,
        .green_y = 0.600,
        .blue_y = 0.060,
        .white_y = 0.3290,
    };

    /// The ITU-R BT.2020 primaries with a D65 white point.
    pub const itur_2020: RGBPrimaries = .{
        .red_x = 0.708,
        .green_x = 0.170,
        .blue_x = 0.131,
        .white_x = 0.3127,
        .red_y = 0.292,
        .green_y = 0.797,
        .blue_y = 0.046,
        .white_y = 0.3290,
    };
};

/// `vImageWhitePoint` — a CIE xy white point, for a monochrome colour space.
pub const WhitePoint = extern struct {
    white_x: f32,
    white_y: f32,

    /// D65.
    pub const d65: WhitePoint = .{ .white_x = 0.3127, .white_y = 0.3290 };
    /// D50, the ICC profile connection space white point.
    pub const d50: WhitePoint = .{ .white_x = 0.3457, .white_y = 0.3585 };
};

// ============================================================================
// Tests
// ============================================================================

test "layouts match vImage_Utilities.h and vImage_CVUtilities.h" {
    const testing = std.testing;
    // Measured with clang against <Accelerate/Accelerate.h> on
    // macOS 15.7 / arm64. A matching size alone would not be enough: the
    // offsets are what pin the field order, and `decode` sitting where
    // `bitmapInfo`/`version` do would still add up to 40.
    try testing.expectEqual(@as(usize, 40), @sizeOf(CGImageFormat));
    try testing.expectEqual(@as(usize, 8), @alignOf(CGImageFormat));
    try testing.expectEqual(@as(usize, 0), @offsetOf(CGImageFormat, "bitsPerComponent"));
    try testing.expectEqual(@as(usize, 4), @offsetOf(CGImageFormat, "bitsPerPixel"));
    try testing.expectEqual(@as(usize, 8), @offsetOf(CGImageFormat, "colorSpace"));
    try testing.expectEqual(@as(usize, 16), @offsetOf(CGImageFormat, "bitmapInfo"));
    try testing.expectEqual(@as(usize, 20), @offsetOf(CGImageFormat, "version"));
    try testing.expectEqual(@as(usize, 24), @offsetOf(CGImageFormat, "decode"));
    try testing.expectEqual(@as(usize, 32), @offsetOf(CGImageFormat, "renderingIntent"));

    try testing.expectEqual(@as(usize, 32), @sizeOf(ChannelDescription));
    try testing.expectEqual(@as(usize, 8), @alignOf(ChannelDescription));

    try testing.expectEqual(@as(usize, 64), @sizeOf(TransferFunction));
    try testing.expectEqual(@as(usize, 32), @offsetOf(TransferFunction, "gamma"));
    try testing.expectEqual(@as(usize, 40), @offsetOf(TransferFunction, "cutoff"));
    try testing.expectEqual(@as(usize, 48), @offsetOf(TransferFunction, "c4"));
    try testing.expectEqual(@as(usize, 56), @offsetOf(TransferFunction, "c5"));

    // All four x coordinates precede all four y coordinates, so red_y is at
    // offset 16 and not 4.
    try testing.expectEqual(@as(usize, 32), @sizeOf(RGBPrimaries));
    try testing.expectEqual(@as(usize, 4), @alignOf(RGBPrimaries));
    try testing.expectEqual(@as(usize, 16), @offsetOf(RGBPrimaries, "red_y"));

    try testing.expectEqual(@as(usize, 8), @sizeOf(WhitePoint));
    try testing.expectEqual(@as(usize, 4), @sizeOf(BufferTypeCode));
    try testing.expectEqual(@as(usize, 4), @sizeOf(MatrixType));
}

test "BufferTypeCode values match the kvImageBufferTypeCode_ constants" {
    const testing = std.testing;
    // Printed by a C program including <Accelerate/Accelerate.h>: the codes
    // are sequential with no gaps, so an off-by-one anywhere in the channel
    // run would shift everything after it.
    try testing.expectEqual(@as(u32, 0), @intFromEnum(BufferTypeCode.end_of_list));
    try testing.expectEqual(@as(u32, 1), @intFromEnum(BufferTypeCode.color_space_channel_1));
    try testing.expectEqual(@as(u32, 16), @intFromEnum(BufferTypeCode.color_space_channel_16));
    try testing.expectEqual(@as(u32, 17), @intFromEnum(BufferTypeCode.alpha));
    try testing.expectEqual(@as(u32, 18), @intFromEnum(BufferTypeCode.indexed));
    try testing.expectEqual(@as(u32, 19), @intFromEnum(BufferTypeCode.cv_pixel_buffer_ycbcr));
    try testing.expectEqual(@as(u32, 20), @intFromEnum(BufferTypeCode.luminance));
    try testing.expectEqual(@as(u32, 21), @intFromEnum(BufferTypeCode.chroma));
    try testing.expectEqual(@as(u32, 22), @intFromEnum(BufferTypeCode.cb));
    try testing.expectEqual(@as(u32, 23), @intFromEnum(BufferTypeCode.cr));
    try testing.expectEqual(@as(u32, 24), @intFromEnum(BufferTypeCode.cg_format));
    try testing.expectEqual(@as(u32, 25), @intFromEnum(BufferTypeCode.chunky));
    try testing.expectEqual(@as(u32, 26), BufferTypeCode.unique_format_count);
    try testing.expectEqual(BufferTypeCode.color_space_channel_2, BufferTypeCode.rgb_green);
}

test "the format constructors produce the bitmapInfo CoreGraphics expects" {
    const testing = std.testing;
    const cs = try cg.ColorSpace.deviceRGB();
    defer cs.deinit();

    // BGRA is ARGB plus a 32-bit little-endian swap; getting this wrong is
    // the classic channel-order bug, so pin the raw value.
    try testing.expectEqual(@as(u32, 2), CGImageFormat.argb8888(cs.ref).bitmapInfo.bits());
    try testing.expectEqual(@as(u32, 1), CGImageFormat.rgba8888(cs.ref).bitmapInfo.bits());
    try testing.expectEqual(@as(u32, 2 | 8192), CGImageFormat.bgra8888(cs.ref).bitmapInfo.bits());
    try testing.expectEqual(@as(u32, 2 | 256), CGImageFormat.argbFFFF(cs.ref).bitmapInfo.bits());
    try testing.expectEqual(@as(u32, 8), CGImageFormat.gray8(cs.ref).bitsPerPixel);
}

comptime {
    // `vImage_Buffer` is shared with the non-CoreGraphics half of the
    // binding; referencing it here keeps the two files' view of it honest.
    std.debug.assert(@sizeOf(types.vImage_Buffer) == 32);
}
