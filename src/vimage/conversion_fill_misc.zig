//! Buffer fill, channel overwrite, channel permute, byte swap and the PNG
//! per-scanline unfilter step.
//!
//! Everything in this file is a *channel-level* operation: it moves, replaces
//! or reorders whole channels without ever rescaling a value. No conversion
//! here is lossy, and none of them look at premultiplication - an alpha
//! channel is just channel 0 of an ARGB pixel like any other.
//!
//! Layout facts a caller needs:
//!
//!   * The 4-channel formats (`Pixel_ARGB_16U`, `Pixel_ARGB_16S`,
//!     `Pixel_ARGB_16F`, `Pixel_8888`, `Pixel_FFFF`) are interleaved, so one
//!     row is `width * 4 * @sizeOf(channel)` bytes. `vImage_Buffer.width` is
//!     always in *pixels*, never in channels or bytes.
//!   * The `CbCr` formats are 2-channel interleaved chroma planes: 2 bytes per
//!     pixel for `CbCr8`, 4 bytes per pixel for `CbCr16U`/`CbCr16S`. For a
//!     4:2:0 image that plane is half the width and half the height of the
//!     luma plane; vImage does not know or check that relationship, it just
//!     fills whatever rectangle you hand it.
//!   * 16F pixels are IEEE 754 binary16 stored in a `uint16_t`, which makes
//!     `Pixel_16F` and `Pixel_16U` the same Zig type. The wrappers here take
//!     `f16` / `[4]f16` and `@bitCast` at the call boundary, matching
//!     `geometry.zig`'s `halfBits` pattern, so a caller writes `0.5` and not
//!     `0x3800`.
//!   * `copyMask` is a 4-bit channel selector, MSB-first over the pixel:
//!     `0x8` is channel 0 (alpha in ARGB), `0x4` channel 1 (red), `0x2`
//!     channel 2 (green), `0x1` channel 3 (blue). A value above `0x0F` is
//!     documented as `kvImageInvalidParameter` - but measured behaviour is
//!     that vImage silently ignores the bits above 0x0F (see the test), so do
//!     not rely on the error. For a non-ARGB channel order (RGBA, BGRA, AYUV)
//!     the mask bits still count from channel 0, so shift them yourself.
//!   * A `permuteMap` is read as `dest[i] = src[permuteMap[i]]`, so
//!     `.{ 0, 1, 2, 3 }` is a copy and `.{ 3, 2, 1, 0 }` turns ARGB into BGRA.
//!     Any entry above 3 is `kvImageInvalidParameter`.
//!   * `vImagePNGDecompressionFilter` works *in place* on the buffer you pass
//!     and treats bytes above/left of the buffer as zero, per the PNG spec -
//!     but see `pngDecompressionFilter` for a hang in the `up`/`paeth` filters
//!     at `startScanline == 0` that makes that zero prior row unusable.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const VImageError = types.VImageError;
const check = types.check;
const vImage_Flags = types.vImage_Flags;
const vImagePixelCount = types.vImagePixelCount;
const Pixel_8 = types.Pixel_8;
const Pixel_8888 = types.Pixel_8888;
const Pixel_FFFF = types.Pixel_FFFF;
const Pixel_16U = types.Pixel_16U;
const Pixel_16S = types.Pixel_16S;
const Pixel_16F = types.Pixel_16F;
const Pixel_88 = types.Pixel_88;
const Pixel_16U16U = types.Pixel_16U16U;
const Pixel_16S16S = types.Pixel_16S16S;
const Pixel_ARGB_16U = types.Pixel_ARGB_16U;
const Pixel_ARGB_16S = types.Pixel_ARGB_16S;
const Pixel_ARGB_16F = types.Pixel_ARGB_16F;
const Flags = types.Flags;

// ============================================================================
// Local types
//
// PNG filter type numbers. BasicImageTypes.h declares these as an anonymous
// enum (kvImage_PNG_FILTER_VALUE_*), so there is nothing in types.zig to
// re-export; they live here until someone hoists them.
// ============================================================================

/// PNG filter type for filter method 0 (the only method the PNG standard
/// defines, and the only one `pngDecompressionFilter` accepts). Section 9.2 of
/// the PNG spec; `bpp` below is `max(1, bitsPerPixel / 8)`.
pub const PNGFilterValue = enum(u32) {
    /// `Raw(x) = Filt(x)`.
    none = 0,
    /// `Raw(x) = Filt(x) + Raw(x - bpp)`.
    sub = 1,
    /// `Raw(x) = Filt(x) + Prior(x)`.
    up = 2,
    /// `Raw(x) = Filt(x) + floor((Raw(x - bpp) + Prior(x)) / 2)`.
    avg = 3,
    /// `Raw(x) = Filt(x) + PaethPredictor(Raw(x - bpp), Prior(x), Prior(x - bpp))`.
    paeth = 4,
};

/// vImage stores half-precision as a raw bit pattern in a `uint16_t`, so a
/// fill colour crosses the boundary as bits. Callers write `0.5`.
fn halfBits(value: f16) Pixel_16F {
    return @bitCast(value);
}

fn halfBits4(value: [4]f16) Pixel_ARGB_16F {
    return .{ halfBits(value[0]), halfBits(value[1]), halfBits(value[2]), halfBits(value[3]) };
}

// ============================================================================
// Buffer fill
// ============================================================================

/// Fill every pixel of a 4-channel 16-bit unsigned buffer with `color`.
///
/// Works for any 4-channel 16U ordering (ARGB16U, RGBA16U, ...); the channels
/// are written in the order given, no interpretation is applied.
pub fn bufferFillARGB16U(dest: *const vImage_Buffer, color: *const Pixel_ARGB_16U, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageBufferFill_ARGB16U(dest, color, flags));
}

/// Fill every pixel of a 4-channel 16-bit signed buffer with `color`.
///
/// The full `[-32768, 32767]` range is written verbatim; nothing is clamped
/// to a video or unsigned range.
pub fn bufferFillARGB16S(dest: *const vImage_Buffer, color: *const Pixel_ARGB_16S, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageBufferFill_ARGB16S(dest, color, flags));
}

/// Fill every pixel of a 4-channel half-float buffer with `color`.
///
/// `color` is given as real `f16` values and bit-cast to the `uint16_t` pair
/// vImage expects. Values outside the binary16 range (magnitude above 65504)
/// become infinities, since no conversion happens - only a bit cast.
pub fn bufferFillARGB16F(dest: *const vImage_Buffer, color: [4]f16, flags: vImage_Flags) VImageError!usize {
    const bits = halfBits4(color);
    return check(c.vImageBufferFill_ARGB16F(dest, &bits, flags));
}

/// Fill every pixel of a 2-channel 8-bit chroma plane with `color` (Cb, Cr).
///
/// `dest.width` counts CbCr *pairs*, so a row is `width * 2` bytes. For
/// neutral (grey) chroma in a full-range 8-bit format use `.{ 128, 128 }`.
pub fn bufferFillCbCr8(dest: *const vImage_Buffer, color: *const Pixel_88, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageBufferFill_CbCr8(dest, color, flags));
}

/// Fill every pixel of a 2-channel 16-bit unsigned chroma plane with `color`.
///
/// A row is `width * 4` bytes. Note that 16U video formats are usually only
/// 10 or 12 bits of real precision left-justified or right-justified in the
/// 16-bit container; this function does not know which, it stores the value
/// you give it.
pub fn bufferFillCbCr16U(dest: *const vImage_Buffer, color: *const Pixel_16U16U, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageBufferFill_CbCr16U(dest, color, flags));
}

/// Fill every pixel of a 2-channel 16-bit signed chroma plane with `color`.
///
/// A row is `width * 4` bytes. Signed chroma is normally zero-centred, so the
/// neutral fill is `.{ 0, 0 }` rather than a mid-range constant.
pub fn bufferFillCbCr16S(dest: *const vImage_Buffer, color: *const Pixel_16S16S, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageBufferFill_CbCr16S(dest, color, flags));
}

// ============================================================================
// Channel overwrite
// ============================================================================

/// Copy `src` to `dest`, replacing the channels selected by `copyMask` with
/// the matching channel of `the_pixel`.
///
/// `copyMask` is `0x8` = channel 0 (alpha), `0x4` = red, `0x2` = green,
/// `0x1` = blue; anything above `0x0F` is `error.InvalidParameter`. This is
/// how you force an ARGB16U image opaque without touching colour:
/// `copyMask = 0x8` with `the_pixel[0] = 0xFFFF`.
///
/// May run in place when `src.data == dest.data` and
/// `src.rowBytes >= dest.rowBytes` (add `kvImageDoNotTile` if the rowBytes
/// differ).
pub fn overwriteChannelsWithPixelARGB16U(the_pixel: *const Pixel_ARGB_16U, src: *const vImage_Buffer, dest: *const vImage_Buffer, copyMask: u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageOverwriteChannelsWithPixel_ARGB16U(the_pixel, src, dest, copyMask, flags));
}

/// Fill a Planar16U buffer with `scalar`.
///
/// Despite the name there is no mask and no source: for a planar buffer the
/// only channel is the whole image, so this is a buffer fill.
pub fn overwriteChannelsWithScalarPlanar16U(scalar: Pixel_16U, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageOverwriteChannelsWithScalar_Planar16U(scalar, dest, flags));
}

/// Fill a Planar16S buffer with `scalar`. Negative values are stored as-is.
pub fn overwriteChannelsWithScalarPlanar16S(scalar: Pixel_16S, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageOverwriteChannelsWithScalar_Planar16S(scalar, dest, flags));
}

/// Fill a Planar16F (half-float) buffer with `scalar`.
///
/// Takes a real `f16` and bit-casts it; the buffer holds the binary16 bit
/// pattern, one `u16` per pixel.
pub fn overwriteChannelsWithScalarPlanar16F(scalar: f16, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageOverwriteChannelsWithScalar_Planar16F(halfBits(scalar), dest, flags));
}

// ============================================================================
// Channel permute
// ============================================================================

/// Reorder the four channels of a half-float image: `dest[i] = src[map[i]]`.
///
/// `src` must be at least as large as `dest` in both dimensions. Entries above
/// 3 give `error.InvalidParameter`. Because only bits move, this is exact and
/// works for any 4-channel 16-bit-per-channel format (RGBA16F, BGRA16F,
/// AYUV16F) - and, since it never inspects the values, equally well for
/// 16U/16S data that happens to be typed as 16F.
pub fn permuteChannelsARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImagePermuteChannels_ARGB16F(src, dest, permuteMap, flags));
}

/// Permute channels, then overwrite the channels selected by `copyMask` with
/// `backgroundColor`:
///
///     dest[i] = src[permuteMap[i]];
///     if (copyMask & (0x8 >> i)) dest[i] = backgroundColor[i];
///
/// The mask selects *background*, not source - a `copyMask` of 0 is a plain
/// permute, and `0x0F` fills the whole image with `backgroundColor` (vImage
/// detects that case and reroutes to the buffer fill). `backgroundColor` is in
/// destination channel order, i.e. it is indexed after the permute, not
/// before.
pub fn permuteChannelsWithMaskedInsertARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, copyMask: u8, backgroundColor: *const Pixel_8888, flags: vImage_Flags) VImageError!usize {
    return check(c.vImagePermuteChannelsWithMaskedInsert_ARGB8888(src, dest, permuteMap, copyMask, backgroundColor, flags));
}

/// `permuteChannelsWithMaskedInsertARGB8888` for 32-bit float channels.
///
/// No clamping is applied, so the background may be outside [0, 1] if that is
/// what your pipeline wants.
pub fn permuteChannelsWithMaskedInsertARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, copyMask: u8, backgroundColor: *const Pixel_FFFF, flags: vImage_Flags) VImageError!usize {
    return check(c.vImagePermuteChannelsWithMaskedInsert_ARGBFFFF(src, dest, permuteMap, copyMask, backgroundColor, flags));
}

/// `permuteChannelsWithMaskedInsertARGB8888` for 16-bit unsigned channels.
pub fn permuteChannelsWithMaskedInsertARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, copyMask: u8, backgroundColor: *const Pixel_ARGB_16U, flags: vImage_Flags) VImageError!usize {
    return check(c.vImagePermuteChannelsWithMaskedInsert_ARGB16U(src, dest, permuteMap, copyMask, backgroundColor, flags));
}

// ============================================================================
// Byte swap
// ============================================================================

/// Swap the two bytes of every 16-bit pixel of a planar buffer.
///
/// This is the big-endian/little-endian fixup for 16-bit image data (PNG and
/// TIFF store 16-bit samples big-endian). It is its own inverse. `width`
/// counts 16-bit pixels, so a row is `width * 2` bytes; for an interleaved
/// 4-channel 16-bit image multiply `width` by 4 and swap the whole thing at
/// once. May be used in place.
pub fn byteSwapPlanar16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageByteSwap_Planar16U(src, dest, flags));
}

// ============================================================================
// PNG unfilter
// ============================================================================

/// Undo the PNG per-scanline difference filter, in place, for scanlines
/// `[startScanline, startScanline + scanlineCount)` of `buffer`.
///
/// Implements filter method 0 of the PNG standard, section 9.2; every scanline
/// in the range is unfiltered with the same `filterType`, so a real decoder
/// calls this once per run of like-filtered rows (the per-row filter byte is
/// *not* part of the buffer - strip it and pass it as `filterType`).
///
/// `bitsPerPixel` sets the filter's "bpp" stride as `max(1, bitsPerPixel / 8)`
/// bytes, so sub-byte depths behave as a 1-byte stride. Bytes left of the row
/// are taken as 0, per the spec. Since the filters are recursive, this is
/// always an in-place operation and `filterMethodNumber` must be 0.
///
/// WARNING: `.up` and `.paeth` at `startScanline == 0` hang. vImage
/// (macOS 15.7.7) spins forever inside `vImagePNGDecompressionFilter` itself -
/// a `sample` of a 4-byte, 1-row buffer shows 100% of stacks in that frame
/// after 100 seconds, with no error returned and no progress. It reproduces
/// with and without row padding and for any `scanlineCount`. So the "prior row
/// above the buffer is zero" rule in BasicImageTypes.h is not usable for those
/// two filters: pass a buffer whose row 0 is the already-unfiltered previous
/// scanline and start at `startScanline >= 1`. `.none`, `.sub` and `.avg` are
/// fine at scanline 0 (`.avg` correctly sees a zero prior row there).
pub fn pngDecompressionFilter(
    buffer: *const vImage_Buffer,
    startScanline: vImagePixelCount,
    scanlineCount: vImagePixelCount,
    bitsPerPixel: u32,
    filterMethodNumber: u32,
    filterType: PNGFilterValue,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImagePNGDecompressionFilter(buffer, startScanline, scanlineCount, bitsPerPixel, filterMethodNumber, @intFromEnum(filterType), flags));
}

// ============================================================================
// Tests
// ============================================================================

/// Allocate a `height` x `width` image of `T` with `channels` interleaved
/// channels per pixel, plus a row of trailing pad bytes so that a wrapper that
/// walks the buffer with the wrong rowBytes shows up as a mismatch.
fn Image(comptime T: type) type {
    return struct {
        buf: vImage_Buffer,
        mem: []T,
        channels: usize,

        const Self = @This();

        fn init(allocator: std.mem.Allocator, height: usize, width: usize, channels: usize) !Self {
            const row = width * channels + channels; // one pixel of pad
            const mem = try allocator.alloc(T, row * height);
            @memset(mem, 0);
            return .{
                .buf = .{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row * @sizeOf(T) },
                .mem = mem,
                .channels = channels,
            };
        }

        fn deinit(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.mem);
        }

        fn stride(self: Self) usize {
            return self.buf.rowBytes / @sizeOf(T);
        }

        fn at(self: Self, y: usize, x: usize) []T {
            const start = y * self.stride() + x * self.channels;
            return self.mem[start .. start + self.channels];
        }

        fn set(self: Self, y: usize, x: usize, values: []const T) void {
            @memcpy(self.at(y, x), values);
        }
    };
}

test "bufferFillARGB16U/16S: every pixel gets the colour, pad bytes untouched" {
    const allocator = std.testing.allocator;

    var u = try Image(u16).init(allocator, 3, 5, 4);
    defer u.deinit(allocator);
    const color_u: Pixel_ARGB_16U = .{ 0xFFFF, 0x1234, 0x0000, 0xABCD };
    try std.testing.expectEqual(@as(usize, 0), try bufferFillARGB16U(&u.buf, &color_u, Flags.kvImageNoFlags));
    for (0..3) |y| {
        for (0..5) |x| try std.testing.expectEqualSlices(u16, &color_u, u.at(y, x));
        // The 4 pad channels at the end of each row must still be zero.
        const row_end = y * u.stride() + 5 * 4;
        try std.testing.expectEqualSlices(u16, &.{ 0, 0, 0, 0 }, u.mem[row_end .. row_end + 4]);
    }

    var s = try Image(i16).init(allocator, 2, 3, 4);
    defer s.deinit(allocator);
    const color_s: Pixel_ARGB_16S = .{ -32768, -1, 0, 32767 };
    try std.testing.expectEqual(@as(usize, 0), try bufferFillARGB16S(&s.buf, &color_s, Flags.kvImageNoFlags));
    for (0..2) |y| for (0..3) |x| try std.testing.expectEqualSlices(i16, &color_s, s.at(y, x));
}

test "bufferFillARGB16F: f16 colour survives the bit cast exactly" {
    const allocator = std.testing.allocator;
    var img = try Image(u16).init(allocator, 2, 4, 4);
    defer img.deinit(allocator);

    // All four are exactly representable in binary16, so this is not lossy.
    const color: [4]f16 = .{ 1.0, 0.5, -2.25, 0.0 };
    try std.testing.expectEqual(@as(usize, 0), try bufferFillARGB16F(&img.buf, color, Flags.kvImageNoFlags));

    for (0..2) |y| {
        for (0..4) |x| {
            const px = img.at(y, x);
            for (color, 0..) |want, i| {
                try std.testing.expectEqual(want, @as(f16, @bitCast(px[i])));
            }
        }
    }
    // 0.5 is 0x3800 in binary16 - pin the actual bit pattern once, so that a
    // wrapper that forgot to bit-cast (and truncated 0.5 to 0) is caught.
    try std.testing.expectEqual(@as(u16, 0x3800), img.at(0, 0)[1]);
}

test "bufferFillCbCr8/16U/16S: two-channel chroma planes" {
    const allocator = std.testing.allocator;

    var b8 = try Image(u8).init(allocator, 4, 3, 2);
    defer b8.deinit(allocator);
    const neutral: Pixel_88 = .{ 128, 130 };
    try std.testing.expectEqual(@as(usize, 0), try bufferFillCbCr8(&b8.buf, &neutral, Flags.kvImageNoFlags));
    for (0..4) |y| for (0..3) |x| try std.testing.expectEqualSlices(u8, &neutral, b8.at(y, x));
    // rowBytes for CbCr8 is width*2 (+pad here): the byte after the last
    // pixel of row 0 must be pad, not a third channel.
    try std.testing.expectEqual(@as(u8, 0), b8.mem[3 * 2]);

    var b16u = try Image(u16).init(allocator, 2, 2, 2);
    defer b16u.deinit(allocator);
    const cbcr_u: Pixel_16U16U = .{ 0x8000, 0x4000 };
    try std.testing.expectEqual(@as(usize, 0), try bufferFillCbCr16U(&b16u.buf, &cbcr_u, Flags.kvImageNoFlags));
    for (0..2) |y| for (0..2) |x| try std.testing.expectEqualSlices(u16, &cbcr_u, b16u.at(y, x));

    var b16s = try Image(i16).init(allocator, 2, 2, 2);
    defer b16s.deinit(allocator);
    const cbcr_s: Pixel_16S16S = .{ -1000, 2000 };
    try std.testing.expectEqual(@as(usize, 0), try bufferFillCbCr16S(&b16s.buf, &cbcr_s, Flags.kvImageNoFlags));
    for (0..2) |y| for (0..2) |x| try std.testing.expectEqualSlices(i16, &cbcr_s, b16s.at(y, x));
}

test "overwriteChannelsWithPixelARGB16U: copyMask 0x8|0x2 replaces channels 0 and 2 only" {
    const allocator = std.testing.allocator;
    var src = try Image(u16).init(allocator, 2, 3, 4);
    defer src.deinit(allocator);
    var dest = try Image(u16).init(allocator, 2, 3, 4);
    defer dest.deinit(allocator);

    for (0..2) |y| {
        for (0..3) |x| {
            const base: u16 = @intCast((y * 3 + x) * 4);
            src.set(y, x, &.{ base, base + 1, base + 2, base + 3 });
        }
    }

    const pixel: Pixel_ARGB_16U = .{ 0xFFFF, 0xEEEE, 0xDDDD, 0xCCCC };
    // 0x8 -> channel 0, 0x2 -> channel 2.
    try std.testing.expectEqual(@as(usize, 0), try overwriteChannelsWithPixelARGB16U(&pixel, &src.buf, &dest.buf, 0x8 | 0x2, Flags.kvImageNoFlags));

    for (0..2) |y| {
        for (0..3) |x| {
            const base: u16 = @intCast((y * 3 + x) * 4);
            const want = [4]u16{ 0xFFFF, base + 1, 0xDDDD, base + 3 };
            try std.testing.expectEqualSlices(u16, &want, dest.at(y, x));
        }
    }
}

test "overwriteChannelsWithPixelARGB16U: copyMask bits above 0x0F are ignored, not rejected" {
    const allocator = std.testing.allocator;
    var src = try Image(u16).init(allocator, 1, 2, 4);
    defer src.deinit(allocator);
    var dest = try Image(u16).init(allocator, 1, 2, 4);
    defer dest.deinit(allocator);
    for (0..2) |x| src.set(0, x, &.{ 1, 2, 3, 4 });
    const pixel: Pixel_ARGB_16U = .{ 100, 200, 300, 400 };

    // Conversion.h documents "kvImageInvalidParameter when copyMask > 0x0F".
    // That is not what the shipping implementation does: the high bits are
    // masked off and the call succeeds. Pinning the real behaviour here so a
    // caller does not use an out-of-range mask as an error probe.
    try std.testing.expectEqual(@as(usize, 0), try overwriteChannelsWithPixelARGB16U(&pixel, &src.buf, &dest.buf, 0x10, Flags.kvImageNoFlags));
    // 0x10 behaves as 0x00: a plain copy, no channel replaced.
    try std.testing.expectEqualSlices(u16, &.{ 1, 2, 3, 4 }, dest.at(0, 0));

    // 0x18 behaves as 0x08: only channel 0 replaced.
    try std.testing.expectEqual(@as(usize, 0), try overwriteChannelsWithPixelARGB16U(&pixel, &src.buf, &dest.buf, 0x18, Flags.kvImageNoFlags));
    try std.testing.expectEqualSlices(u16, &.{ 100, 2, 3, 4 }, dest.at(0, 0));
}

test "overwriteChannelsWithScalarPlanar16U/16S/16F: planar fills" {
    const allocator = std.testing.allocator;

    var u = try Image(u16).init(allocator, 3, 4, 1);
    defer u.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try overwriteChannelsWithScalarPlanar16U(0xBEEF, &u.buf, Flags.kvImageNoFlags));
    for (0..3) |y| for (0..4) |x| try std.testing.expectEqual(@as(u16, 0xBEEF), u.at(y, x)[0]);

    var s = try Image(i16).init(allocator, 3, 4, 1);
    defer s.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try overwriteChannelsWithScalarPlanar16S(-12345, &s.buf, Flags.kvImageNoFlags));
    for (0..3) |y| for (0..4) |x| try std.testing.expectEqual(@as(i16, -12345), s.at(y, x)[0]);

    var h = try Image(u16).init(allocator, 3, 4, 1);
    defer h.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try overwriteChannelsWithScalarPlanar16F(0.25, &h.buf, Flags.kvImageNoFlags));
    // 0.25 == 0x3400 in binary16.
    for (0..3) |y| for (0..4) |x| {
        try std.testing.expectEqual(@as(u16, 0x3400), h.at(y, x)[0]);
        try std.testing.expectEqual(@as(f16, 0.25), @as(f16, @bitCast(h.at(y, x)[0])));
    };
}

test "permuteChannelsARGB16F: map {3,2,1,0} reverses channels, {0,1,2,3} copies" {
    const allocator = std.testing.allocator;
    var src = try Image(u16).init(allocator, 2, 3, 4);
    defer src.deinit(allocator);
    var dest = try Image(u16).init(allocator, 2, 3, 4);
    defer dest.deinit(allocator);

    const vals = [4]f16{ 1.0, 2.0, 4.0, 8.0 };
    for (0..2) |y| for (0..3) |x| src.set(y, x, &halfBits4(vals));

    const reverse = [4]u8{ 3, 2, 1, 0 };
    try std.testing.expectEqual(@as(usize, 0), try permuteChannelsARGB16F(&src.buf, &dest.buf, &reverse, Flags.kvImageNoFlags));
    for (0..2) |y| for (0..3) |x| {
        const px = dest.at(y, x);
        try std.testing.expectEqual(@as(f16, 8.0), @as(f16, @bitCast(px[0])));
        try std.testing.expectEqual(@as(f16, 4.0), @as(f16, @bitCast(px[1])));
        try std.testing.expectEqual(@as(f16, 2.0), @as(f16, @bitCast(px[2])));
        try std.testing.expectEqual(@as(f16, 1.0), @as(f16, @bitCast(px[3])));
    };

    // Permuting twice by the same reversal is the identity.
    var back = try Image(u16).init(allocator, 2, 3, 4);
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try permuteChannelsARGB16F(&dest.buf, &back.buf, &reverse, Flags.kvImageNoFlags));
    for (0..2) |y| for (0..3) |x| try std.testing.expectEqualSlices(u16, &halfBits4(vals), back.at(y, x));

    const bad = [4]u8{ 0, 1, 2, 4 };
    try std.testing.expectError(VImageError.InvalidParameter, permuteChannelsARGB16F(&src.buf, &dest.buf, &bad, Flags.kvImageNoFlags));
}

test "permuteChannelsWithMaskedInsertARGB8888: mask selects background, not source" {
    const allocator = std.testing.allocator;
    var src = try Image(u8).init(allocator, 2, 3, 4);
    defer src.deinit(allocator);
    var dest = try Image(u8).init(allocator, 2, 3, 4);
    defer dest.deinit(allocator);

    for (0..2) |y| for (0..3) |x| src.set(y, x, &.{ 1, 2, 3, 4 });

    const map = [4]u8{ 3, 2, 1, 0 };
    const bg: Pixel_8888 = .{ 200, 201, 202, 203 };

    // copyMask 0x4 == the i == 1 bit (0x8 >> 1), so only dest channel 1 comes
    // from the background. The rest is the permute: {4, ., 2, 1}.
    try std.testing.expectEqual(@as(usize, 0), try permuteChannelsWithMaskedInsertARGB8888(&src.buf, &dest.buf, &map, 0x4, &bg, Flags.kvImageNoFlags));
    for (0..2) |y| for (0..3) |x| try std.testing.expectEqualSlices(u8, &.{ 4, 201, 2, 1 }, dest.at(y, x));

    // copyMask 0 is a plain permute.
    try std.testing.expectEqual(@as(usize, 0), try permuteChannelsWithMaskedInsertARGB8888(&src.buf, &dest.buf, &map, 0x0, &bg, Flags.kvImageNoFlags));
    for (0..2) |y| for (0..3) |x| try std.testing.expectEqualSlices(u8, &.{ 4, 3, 2, 1 }, dest.at(y, x));

    // copyMask 0x0F is a whole-buffer fill with the background.
    try std.testing.expectEqual(@as(usize, 0), try permuteChannelsWithMaskedInsertARGB8888(&src.buf, &dest.buf, &map, 0x0F, &bg, Flags.kvImageNoFlags));
    for (0..2) |y| for (0..3) |x| try std.testing.expectEqualSlices(u8, &bg, dest.at(y, x));
}

test "permuteChannelsWithMaskedInsertARGBFFFF/ARGB16U: same semantics at other depths" {
    const allocator = std.testing.allocator;
    const map = [4]u8{ 1, 0, 3, 2 };
    // 0x8 -> dest channel 0, 0x1 -> dest channel 3.
    const mask: u8 = 0x8 | 0x1;

    var f_src = try Image(f32).init(allocator, 2, 2, 4);
    defer f_src.deinit(allocator);
    var f_dest = try Image(f32).init(allocator, 2, 2, 4);
    defer f_dest.deinit(allocator);
    for (0..2) |y| for (0..2) |x| f_src.set(y, x, &.{ 0.0, 0.25, 0.5, 0.75 });
    const f_bg: Pixel_FFFF = .{ -1.0, -2.0, -3.0, -4.0 };
    try std.testing.expectEqual(@as(usize, 0), try permuteChannelsWithMaskedInsertARGBFFFF(&f_src.buf, &f_dest.buf, &map, mask, &f_bg, Flags.kvImageNoFlags));
    // permute gives {0.25, 0.0, 0.75, 0.5}; channels 0 and 3 become bg[0], bg[3].
    for (0..2) |y| for (0..2) |x| try std.testing.expectEqualSlices(f32, &.{ -1.0, 0.0, 0.75, -4.0 }, f_dest.at(y, x));

    var u_src = try Image(u16).init(allocator, 2, 2, 4);
    defer u_src.deinit(allocator);
    var u_dest = try Image(u16).init(allocator, 2, 2, 4);
    defer u_dest.deinit(allocator);
    for (0..2) |y| for (0..2) |x| u_src.set(y, x, &.{ 10, 20, 30, 40 });
    const u_bg: Pixel_ARGB_16U = .{ 0xFFFF, 0xFFFE, 0xFFFD, 0xFFFC };
    try std.testing.expectEqual(@as(usize, 0), try permuteChannelsWithMaskedInsertARGB16U(&u_src.buf, &u_dest.buf, &map, mask, &u_bg, Flags.kvImageNoFlags));
    for (0..2) |y| for (0..2) |x| try std.testing.expectEqualSlices(u16, &.{ 0xFFFF, 10, 40, 0xFFFC }, u_dest.at(y, x));
}

test "byteSwapPlanar16U: swaps the bytes of each 16-bit pixel and is its own inverse" {
    const allocator = std.testing.allocator;
    var src = try Image(u16).init(allocator, 2, 4, 1);
    defer src.deinit(allocator);
    var dest = try Image(u16).init(allocator, 2, 4, 1);
    defer dest.deinit(allocator);

    const vals = [4]u16{ 0x0102, 0xFF00, 0x1234, 0xABCD };
    for (0..2) |y| for (vals, 0..) |v, x| src.set(y, x, &.{v});

    try std.testing.expectEqual(@as(usize, 0), try byteSwapPlanar16U(&src.buf, &dest.buf, Flags.kvImageNoFlags));
    const swapped = [4]u16{ 0x0201, 0x00FF, 0x3412, 0xCDAB };
    for (0..2) |y| for (swapped, 0..) |want, x| try std.testing.expectEqual(want, dest.at(y, x)[0]);

    // Round trip in place restores the original.
    try std.testing.expectEqual(@as(usize, 0), try byteSwapPlanar16U(&dest.buf, &dest.buf, Flags.kvImageNoFlags));
    for (0..2) |y| for (vals, 0..) |want, x| try std.testing.expectEqual(want, dest.at(y, x)[0]);
}

test "pngDecompressionFilter: sub filter accumulates left neighbour" {
    const allocator = std.testing.allocator;
    // 8 bits per pixel -> bpp == 1 byte, so Raw(x) = Filt(x) + Raw(x-1)
    // with Raw(-1) == 0.  Filt = {10, 20, 30, 40} -> {10, 30, 60, 100}.
    var img = try Image(u8).init(allocator, 1, 4, 1);
    defer img.deinit(allocator);
    for ([_]u8{ 10, 20, 30, 40 }, 0..) |v, x| img.set(0, x, &.{v});

    try std.testing.expectEqual(@as(usize, 0), try pngDecompressionFilter(&img.buf, 0, 1, 8, 0, .sub, Flags.kvImageNoFlags));
    for ([_]u8{ 10, 30, 60, 100 }, 0..) |want, x| try std.testing.expectEqual(want, img.at(0, x)[0]);
}

test "pngDecompressionFilter: sub filter at 32bpp strides 4 bytes and wraps mod 256" {
    const allocator = std.testing.allocator;
    // bitsPerPixel = 32 -> bpp == 4, so each channel accumulates down its own
    // column of the scanline, independently.  Row of 3 RGBA pixels:
    //   {1,2,3,4} {10,20,30,40} {100,200,250,255}
    // -> {1,2,3,4} {11,22,33,44} {111,222,283%256=27,299%256=43}
    var img = try Image(u8).init(allocator, 1, 3, 4);
    defer img.deinit(allocator);
    img.set(0, 0, &.{ 1, 2, 3, 4 });
    img.set(0, 1, &.{ 10, 20, 30, 40 });
    img.set(0, 2, &.{ 100, 200, 250, 255 });

    try std.testing.expectEqual(@as(usize, 0), try pngDecompressionFilter(&img.buf, 0, 1, 32, 0, .sub, Flags.kvImageNoFlags));
    try std.testing.expectEqualSlices(u8, &.{ 1, 2, 3, 4 }, img.at(0, 0));
    try std.testing.expectEqualSlices(u8, &.{ 11, 22, 33, 44 }, img.at(0, 1));
    try std.testing.expectEqualSlices(u8, &.{ 111, 222, 27, 43 }, img.at(0, 2));
}

test "pngDecompressionFilter: up and avg filters read the prior scanline" {
    const allocator = std.testing.allocator;

    // Two scanlines, filter applied to the second only (startScanline = 1),
    // so Prior() is the first row, which is already unfiltered.
    var img = try Image(u8).init(allocator, 2, 4, 1);
    defer img.deinit(allocator);
    for ([_]u8{ 5, 10, 15, 20 }, 0..) |v, x| img.set(0, x, &.{v});
    for ([_]u8{ 1, 2, 3, 250 }, 0..) |v, x| img.set(1, x, &.{v});

    // up: Raw(x) = Filt(x) + Prior(x) -> {6, 12, 18, 270 % 256 = 14}
    try std.testing.expectEqual(@as(usize, 0), try pngDecompressionFilter(&img.buf, 1, 1, 8, 0, .up, Flags.kvImageNoFlags));
    for ([_]u8{ 5, 10, 15, 20 }, 0..) |want, x| try std.testing.expectEqual(want, img.at(0, x)[0]);
    for ([_]u8{ 6, 12, 18, 14 }, 0..) |want, x| try std.testing.expectEqual(want, img.at(1, x)[0]);

    // avg: Raw(x) = Filt(x) + floor((Raw(x-1) + Prior(x)) / 2), Raw(-1) = 0.
    //   Prior = {5, 10, 15, 20}, Filt = {1, 2, 3, 4}
    //   x=0: 1 + (0+5)/2   = 1 + 2  = 3
    //   x=1: 2 + (3+10)/2  = 2 + 6  = 8
    //   x=2: 3 + (8+15)/2  = 3 + 11 = 14
    //   x=3: 4 + (14+20)/2 = 4 + 17 = 21
    var avg = try Image(u8).init(allocator, 2, 4, 1);
    defer avg.deinit(allocator);
    for ([_]u8{ 5, 10, 15, 20 }, 0..) |v, x| avg.set(0, x, &.{v});
    for ([_]u8{ 1, 2, 3, 4 }, 0..) |v, x| avg.set(1, x, &.{v});
    try std.testing.expectEqual(@as(usize, 0), try pngDecompressionFilter(&avg.buf, 1, 1, 8, 0, .avg, Flags.kvImageNoFlags));
    for ([_]u8{ 3, 8, 14, 21 }, 0..) |want, x| try std.testing.expectEqual(want, avg.at(1, x)[0]);
}

// `.up` and `.paeth` at startScanline 0 are deliberately NOT exercised: they
// hang inside vImage (see the WARNING on `pngDecompressionFilter`). The
// configurations below all start at scanline 1, where a real prior row exists.
// `.avg`, which also reads the prior row, does work at scanline 0 and is
// covered by the avg half of the "up and avg" test plus the sub tests.
test "pngDecompressionFilter: up/paeth at startScanline 0 hang - documented, not run" {
    // No call is made. vImagePNGDecompressionFilter(buffer, 0, n, 8, 0,
    // kvImage_PNG_FILTER_VALUE_UP or _PAETH, kvImageNoFlags) never returns:
    // sampled at 100s on a 1x4 Planar8 buffer, every stack frame sits in
    // vImagePNGDecompressionFilter (macOS 15.7.7, arm64). There is no error
    // code to assert - the call simply does not come back, with or without row
    // padding, so this test records the constraint instead of triggering it.
    try std.testing.expect(@intFromEnum(PNGFilterValue.up) == 2);
    try std.testing.expect(@intFromEnum(PNGFilterValue.paeth) == 4);
}

test "pngDecompressionFilter: paeth filter with a real prior row" {
    const allocator = std.testing.allocator;
    // Prior = {10, 10, 10, 10}, Filt = {0, 0, 0, 0}:
    //   x=0: a=0, b=10, c=0  -> p=10; pa=10, pb=0, pc=10 -> b=10; Raw=10
    //   x=1: a=10,b=10, c=10 -> p=10; pa=0               -> a=10; Raw=10
    //   x=2, x=3: same -> 10
    var p2 = try Image(u8).init(allocator, 2, 4, 1);
    defer p2.deinit(allocator);
    for (0..4) |x| p2.set(0, x, &.{10});
    for (0..4) |x| p2.set(1, x, &.{0});
    try std.testing.expectEqual(@as(usize, 0), try pngDecompressionFilter(&p2.buf, 1, 1, 8, 0, .paeth, Flags.kvImageNoFlags));
    for (0..4) |x| try std.testing.expectEqual(@as(u8, 10), p2.at(1, x)[0]);
}

test "pngDecompressionFilter: none leaves the bytes alone" {
    const allocator = std.testing.allocator;
    var n = try Image(u8).init(allocator, 1, 3, 1);
    defer n.deinit(allocator);
    for ([_]u8{ 9, 8, 7 }, 0..) |v, x| n.set(0, x, &.{v});
    try std.testing.expectEqual(@as(usize, 0), try pngDecompressionFilter(&n.buf, 0, 1, 8, 0, .none, Flags.kvImageNoFlags));
    for ([_]u8{ 9, 8, 7 }, 0..) |want, x| try std.testing.expectEqual(want, n.at(0, x)[0]);
}
