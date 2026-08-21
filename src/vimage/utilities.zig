//! `vImage_Utilities.h` — CoreGraphics interoperation.
//!
//! This is the bridge between `vImage_Buffer` and `CGImageRef`, plus
//! `vImageConverterRef`: a compiled conversion between any two image formats
//! vImage can describe. The single most useful entry point here is
//! `Converter.convert` (`vImageConvert_AnyToAny`), which subsumes a large
//! part of the hand-written `conversion` module — one converter object handles
//! any describable source/destination pair, including colour-space conversion,
//! rather than one entry point per format combination.
//!
//! Available only when the package is built with `-Dcoregraphics=true`.
//! See `accelerate.cg` for the ownership convention `Converter` and
//! `cg.Image` follow.

const std = @import("std");
const types = @import("types.zig");
const cgt = @import("cg_types.zig");
const c = @import("c_cg.zig");
const cg = @import("../cg/root.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImagePixelCount = types.vImagePixelCount;
const vImage_Flags = types.vImage_Flags;
const vImage_Error = types.vImage_Error;
const VImageError = types.VImageError;
const check = types.check;
const vImageConverter = types.vImageConverter;

const CGFloat = cg.CGFloat;

/// This namespace is present; the mirror-image placeholder installed when
/// `-Dcoregraphics` is off sets this to `false`.
pub const enabled = true;

// -- Re-exported types --
pub const CGImageFormat = cgt.CGImageFormat;
pub const BufferTypeCode = cgt.BufferTypeCode;

/// libc `free`. `vImageBuffer_Init` and `vImageBuffer_InitWithCGImage`
/// allocate `buf.data` with the system allocator, so it must go back the same
/// way — not through a Zig allocator.
extern fn free(ptr: ?*anyopaque) void;

// ============================================================================
// vImage_Buffer utilities
// ============================================================================

/// The alignment and row stride vImage would pick for an image of this shape.
pub const BufferLayout = struct {
    /// Suitable for `posix_memalign`, in bytes.
    alignment: usize,
    /// Bytes per scanline, including any padding.
    row_bytes: usize,
};

/// Allocate a buffer sized and aligned for best performance.
///
/// `vImageBuffer_Init`. On success `buf` has its `height`, `width`,
/// `rowBytes` and `data` filled in; release `buf.data` with `bufferFree`.
///
/// `pixel_bits` is bits per *pixel* for an interleaved format and bits per
/// *component* for a planar one. A value not divisible by 8 is padded out, so
/// two scanlines never share a byte.
pub fn bufferInit(buf: *vImage_Buffer, height: vImagePixelCount, width: vImagePixelCount, pixel_bits: u32, flags: vImage_Flags) VImageError!void {
    _ = try check(c.vImageBuffer_Init(buf, height, width, pixel_bits, flags));
}

/// Ask vImage for the preferred layout without allocating anything.
///
/// `vImageBuffer_Init` with `kvImageNoAllocate`. In that mode the return slot
/// carries the preferred *alignment* as a positive value rather than an error
/// code — which is exactly why `check` treats every non-negative value as
/// success. `buf.data` is left null.
pub fn bufferLayout(height: vImagePixelCount, width: vImagePixelCount, pixel_bits: u32) VImageError!BufferLayout {
    var buf: vImage_Buffer = undefined;
    const alignment = try check(c.vImageBuffer_Init(&buf, height, width, pixel_bits, types.Flags.kvImageNoAllocate));
    return .{ .alignment = alignment, .row_bytes = buf.rowBytes };
}

/// Release the `data` pointer `bufferInit` or `bufferInitWithCGImage`
/// allocated, and null it out.
pub fn bufferFree(buf: *vImage_Buffer) void {
    free(buf.data);
    buf.data = null;
}

/// The buffer's dimensions as a `CGSize`.
///
/// `vImageBuffer_GetSize`. Rounded *down* to the nearest representable
/// `CGFloat`, so for an implausibly large image the bottom or right edge can
/// be truncated rather than rounded up past the end of the data.
pub fn bufferSize(buf: *const vImage_Buffer) cg.CGSize {
    return c.vImageBuffer_GetSize(buf);
}

// ============================================================================
// vImage_CGImageFormat utilities
// ============================================================================

/// How many channels a pixel in this format has, counting alpha and any
/// skipped padding channel.
///
/// `vImageCGImageFormat_GetComponentCount`.
pub fn componentCount(format: *const CGImageFormat) u32 {
    return c.vImageCGImageFormat_GetComponentCount(format);
}

/// Whether two formats describe the same pixel layout.
///
/// `vImageCGImageFormat_IsEqual`. Either argument may be null, but note the
/// measured behaviour: **two nulls compare unequal**, not equal. Null is
/// treated as "no format" rather than as a value that matches itself.
pub fn formatsEqual(f1: ?*const CGImageFormat, f2: ?*const CGImageFormat) bool {
    return c.vImageCGImageFormat_IsEqual(f1, f2) != 0;
}

// ============================================================================
// CGImage bridges
// ============================================================================

/// Decode a `CGImage` into a freshly allocated buffer in `format`.
///
/// `vImageBuffer_InitWithCGImage`. Release `buf.data` with `bufferFree`.
///
/// `format` is taken by mutable pointer because the C parameter is non-const,
/// but do not count on it being filled in: passing a format whose
/// `colorSpace` is null decodes successfully against the image's own colour
/// space and leaves the caller's field **still null** on return. Measured on
/// macOS 15.7. Populate the format fully if you need to know what you got.
///
/// `background_color` supplies the colour to flatten against when the source
/// has alpha and the destination does not; it needs
/// `componentCount(format)` entries, and may be null when no flattening is
/// required.
pub fn bufferInitWithCGImage(
    buf: *vImage_Buffer,
    format: *CGImageFormat,
    background_color: ?[]const CGFloat,
    image: *cg.CGImage,
    flags: vImage_Flags,
) VImageError!void {
    const bg: ?[*]const CGFloat = if (background_color) |b| b.ptr else null;
    _ = try check(c.vImageBuffer_InitWithCGImage(buf, format, bg, image, flags));
}

/// Wrap a buffer in a new `CGImage`.
///
/// `vImageCreateCGImageFromBuffer`. By default the pixel data is **copied**,
/// so `buf` may be freed immediately afterwards.
///
/// The `CGImage` that comes back is canonicalised, not a literal echo of
/// `format`: vImage rewrites an alpha-first layout into the equivalent
/// alpha-last one, converting the pixels to match, so a format built with
/// `.premultiplied_first` produces an image reporting `.premultiplied_last`.
/// The image is correct — rendering it gives the original colours — but an
/// equality check against the format you passed in will fail. Measured on
/// macOS 15.7; the header does not mention it.
///
/// Pass `kvImageNoAllocate` in `flags` for no-copy mode, in which the
/// `CGImage` takes ownership of `buf.data` and calls `callback(user_data,
/// buf.data)` — or `free`, if `callback` is null — when it is done. The
/// callback may fire on any thread, and possibly before this function has
/// even returned. It is not called if the result is an error.
///
/// The returned `cg.Image` owns a reference; call `deinit` on it.
pub fn createCGImageFromBuffer(
    buf: *const vImage_Buffer,
    format: *const CGImageFormat,
    callback: ?*const fn (user_data: ?*anyopaque, buf_data: ?*anyopaque) callconv(.c) void,
    user_data: ?*anyopaque,
    flags: vImage_Flags,
) VImageError!cg.Image {
    var err: vImage_Error = 0;
    const image = c.vImageCreateCGImageFromBuffer(buf, format, callback, user_data, flags, &err);
    if (image) |ref| return cg.Image.adopt(ref);
    // A null return always comes with an error code written through `err`.
    _ = try check(err);
    return VImageError.Unknown;
}

// ============================================================================
// vImageConverterRef
// ============================================================================

/// An owned `vImageConverterRef` — a compiled conversion between two image
/// formats.
///
/// Building one is the expensive part; applying it with `convert` is cheap
/// and thread-safe, so hoist creation out of a per-frame loop.
pub const Converter = struct {
    /// Borrowed for as long as this wrapper lives.
    ref: *vImageConverter,

    /// Take ownership of an existing +1 reference without retaining.
    pub fn adopt(ref: *vImageConverter) Converter {
        return .{ .ref = ref };
    }

    /// Retain a borrowed pointer and return it as an owned reference.
    pub fn borrow(ref: *vImageConverter) Converter {
        c.vImageConverter_Retain(ref);
        return .{ .ref = ref };
    }

    /// A second owned reference. `vImageConverter_Retain`.
    pub fn retain(self: Converter) Converter {
        return borrow(self.ref);
    }

    /// `vImageConverter_Release`.
    pub fn deinit(self: Converter) void {
        c.vImageConverter_Release(self.ref);
    }

    /// Compile a conversion between two CoreGraphics image formats.
    ///
    /// `vImageConverter_CreateWithCGImageFormat`. A null `colorSpace` in
    /// either format means sRGB.
    ///
    /// `background_color` is used when alpha has to be flattened away; it
    /// needs one entry per destination colour channel and may be null when
    /// the conversion does not need one.
    pub fn createWithCGImageFormat(
        src_format: *const CGImageFormat,
        dest_format: *const CGImageFormat,
        background_color: ?[]const CGFloat,
        flags: vImage_Flags,
    ) VImageError!Converter {
        var err: vImage_Error = 0;
        const bg: ?[*]const CGFloat = if (background_color) |b| b.ptr else null;
        const ref = c.vImageConverter_CreateWithCGImageFormat(src_format, dest_format, bg, flags, &err);
        return finish(ref, err);
    }

    /// Compile a conversion driven by a CoreGraphics colour conversion info
    /// object rather than by the two formats' colour spaces.
    ///
    /// `vImageConverter_CreateWithCGColorConversionInfo`. Use this when the
    /// colour transform has to match one CoreGraphics would apply exactly,
    /// including any black-point compensation or rendering intent baked into
    /// the `CGColorConversionInfo`.
    pub fn createWithCGColorConversionInfo(
        info: *cg.CGColorConversionInfo,
        src_format: *const CGImageFormat,
        dest_format: *const CGImageFormat,
        background_color: ?[]const CGFloat,
        flags: vImage_Flags,
    ) VImageError!Converter {
        var err: vImage_Error = 0;
        const bg: ?[*]const CGFloat = if (background_color) |b| b.ptr else null;
        const ref = c.vImageConverter_CreateWithCGColorConversionInfo(info, src_format, dest_format, bg, flags, &err);
        return finish(ref, err);
    }

    /// Compile a conversion substituting a custom ColorSync transform for the
    /// colour-conversion step vImage would otherwise generate.
    ///
    /// `vImageConverter_CreateWithColorSyncCodeFragment`. `code_fragment` is
    /// a ColorSync code fragment, produced by ColorSync APIs this package
    /// does not bind; it is typed as an opaque `CFTypeRef` to pass through.
    pub fn createWithColorSyncCodeFragment(
        code_fragment: cg.CFTypeRef,
        src_format: *const CGImageFormat,
        dest_format: *const CGImageFormat,
        background_color: ?[]const CGFloat,
        flags: vImage_Flags,
    ) VImageError!Converter {
        var err: vImage_Error = 0;
        const bg: ?[*]const CGFloat = if (background_color) |b| b.ptr else null;
        const ref = c.vImageConverter_CreateWithColorSyncCodeFragment(code_fragment, src_format, dest_format, bg, flags, &err);
        return finish(ref, err);
    }

    /// Shared tail for the `Create*` entry points: a null return always comes
    /// with a code written through the `error` out-parameter.
    fn finish(ref: ?*vImageConverter, err: vImage_Error) VImageError!Converter {
        if (ref) |r| return adopt(r);
        _ = try check(err);
        return VImageError.Unknown;
    }

    /// How many source buffers `convert` expects.
    ///
    /// `vImageConverter_GetNumberOfSourceBuffers`. One for any interleaved
    /// CoreGraphics format; more for planar and YCbCr formats.
    pub fn sourceBufferCount(self: Converter) usize {
        return c.vImageConverter_GetNumberOfSourceBuffers(self.ref);
    }

    /// `vImageConverter_GetNumberOfDestinationBuffers`.
    pub fn destinationBufferCount(self: Converter) usize {
        return c.vImageConverter_GetNumberOfDestinationBuffers(self.ref);
    }

    /// What each source buffer must contain, in order.
    ///
    /// `vImageConverter_GetSourceBufferOrder`. The C array is terminated by
    /// `end_of_list`; the slice returned here excludes that terminator and is
    /// borrowed from the converter, so it must not outlive it.
    pub fn sourceBufferOrder(self: Converter) []const BufferTypeCode {
        return sliceOrder(c.vImageConverter_GetSourceBufferOrder(self.ref));
    }

    /// `vImageConverter_GetDestinationBufferOrder`.
    pub fn destinationBufferOrder(self: Converter) []const BufferTypeCode {
        return sliceOrder(c.vImageConverter_GetDestinationBufferOrder(self.ref));
    }

    fn sliceOrder(ptr: ?[*]const BufferTypeCode) []const BufferTypeCode {
        const p = ptr orelse return &.{};
        var n: usize = 0;
        while (p[n] != .end_of_list) n += 1;
        return p[0..n];
    }

    /// Whether this conversion needs separate source and destination buffers.
    ///
    /// `vImageConverter_MustOperateOutOfPlace`. Returns `true` when in-place
    /// operation is impossible. `srcs` and `dests` may both be omitted for a
    /// general answer, or both supplied to ask about specific buffers — some
    /// conversions are in-place-capable only for particular row strides.
    ///
    /// Note the C convention: `kvImageOutOfPlaceOperationRequired` is not a
    /// failure here, it is the affirmative answer, so it is folded into the
    /// boolean instead of being propagated as an error.
    pub fn mustOperateOutOfPlace(
        self: Converter,
        srcs: ?[]const vImage_Buffer,
        dests: ?[]const vImage_Buffer,
        flags: vImage_Flags,
    ) VImageError!bool {
        const s: ?[*]const vImage_Buffer = if (srcs) |x| x.ptr else null;
        const d: ?[*]const vImage_Buffer = if (dests) |x| x.ptr else null;
        const e = c.vImageConverter_MustOperateOutOfPlace(self.ref, s, d, flags);
        if (e == types.Error.kvImageOutOfPlaceOperationRequired) return true;
        _ = try check(e);
        return false;
    }

    /// Apply the conversion.
    ///
    /// `vImageConvert_AnyToAny`. `srcs.len` must equal `sourceBufferCount()`
    /// and `dests.len` must equal `destinationBufferCount()`; both are
    /// asserted, because passing a short array is a buffer overrun vImage
    /// cannot detect.
    ///
    /// `temp_buffer` may be null, in which case vImage allocates any scratch
    /// space it needs itself. To supply your own, call once with
    /// `kvImageGetTempBufferSize` in `flags` — the size comes back through
    /// the return value rather than an out-parameter.
    pub fn convert(
        self: Converter,
        srcs: []const vImage_Buffer,
        dests: []const vImage_Buffer,
        temp_buffer: ?*anyopaque,
        flags: vImage_Flags,
    ) VImageError!usize {
        std.debug.assert(srcs.len == self.sourceBufferCount());
        std.debug.assert(dests.len == self.destinationBufferCount());
        return check(c.vImageConvert_AnyToAny(self.ref, srcs.ptr, dests.ptr, temp_buffer, flags));
    }

    /// The scratch size `convert` would want for these buffers, in bytes.
    ///
    /// `vImageConvert_AnyToAny` with `kvImageGetTempBufferSize`.
    pub fn tempBufferSize(self: Converter, srcs: []const vImage_Buffer, dests: []const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
        return self.convert(srcs, dests, null, flags | types.Flags.kvImageGetTempBufferSize);
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// A 4x4 ARGB8888 test image with a distinct value in every channel of every
/// pixel, so a channel swap or a row-stride error cannot go unnoticed.
fn makeTestBuffer(storage: []u8, width: usize, height: usize) vImage_Buffer {
    for (0..height) |y| {
        for (0..width) |x| {
            const i = (y * width + x) * 4;
            storage[i + 0] = 0xFF; // A (premultiplied, opaque)
            storage[i + 1] = @intCast(0x10 + x);
            storage[i + 2] = @intCast(0x40 + y);
            storage[i + 3] = @intCast(0x80 + x * 4 + y);
        }
    }
    return .{ .data = storage.ptr, .height = height, .width = width, .rowBytes = width * 4 };
}

test "bufferLayout reports an alignment through the return slot, not an error" {
    const layout = try bufferLayout(64, 64, 32);
    // The value comes back positive through the same slot a failure would use
    // a negative code in. Anything > 0 and a power of two is plausible.
    try testing.expect(layout.alignment > 0);
    try testing.expect(std.math.isPowerOfTwo(layout.alignment));
    try testing.expect(layout.row_bytes >= 64 * 4);
}

test "bufferInit allocates a usable buffer with the requested geometry" {
    var buf: vImage_Buffer = undefined;
    try bufferInit(&buf, 17, 33, 32, 0);
    defer bufferFree(&buf);

    try testing.expectEqual(@as(usize, 17), buf.height);
    try testing.expectEqual(@as(usize, 33), buf.width);
    try testing.expect(buf.rowBytes >= 33 * 4);
    try testing.expect(buf.data != null);

    // Writing every byte of every scanline must stay inside the allocation.
    const bytes: [*]u8 = @ptrCast(buf.data.?);
    @memset(bytes[0 .. buf.rowBytes * buf.height], 0xA5);
    try testing.expectEqual(@as(u8, 0xA5), bytes[buf.rowBytes * buf.height - 1]);
}

test "bufferSize returns the width and height as a CGSize" {
    var storage: [4 * 4 * 4]u8 = undefined;
    const buf = makeTestBuffer(&storage, 4, 4);
    const size = bufferSize(&buf);
    try testing.expectEqual(@as(cg.CGFloat, 4), size.width);
    try testing.expectEqual(@as(cg.CGFloat, 4), size.height);
}

test "componentCount counts alpha and padding channels, not just colours" {
    const rgb = try cg.ColorSpace.deviceRGB();
    defer rgb.deinit();
    const gray = try cg.ColorSpace.deviceGray();
    defer gray.deinit();
    const cmyk = try cg.ColorSpace.deviceCMYK();
    defer cmyk.deinit();

    try testing.expectEqual(@as(u32, 4), componentCount(&CGImageFormat.argb8888(rgb.ref)));
    try testing.expectEqual(@as(u32, 1), componentCount(&CGImageFormat.gray8(gray.ref)));

    // A skipped padding channel still occupies a component slot, which is
    // what makes the count usable for sizing a background-colour array.
    const xrgb = CGImageFormat{
        .bitsPerComponent = 8,
        .bitsPerPixel = 32,
        .colorSpace = rgb.ref,
        .bitmapInfo = .{ .alpha = .none_skip_first },
    };
    try testing.expectEqual(@as(u32, 4), componentCount(&xrgb));

    const cmyka = CGImageFormat{
        .bitsPerComponent = 8,
        .bitsPerPixel = 40,
        .colorSpace = cmyk.ref,
        .bitmapInfo = .{ .alpha = .premultiplied_last },
    };
    try testing.expectEqual(@as(u32, 5), componentCount(&cmyka));
}

test "formatsEqual distinguishes formats that differ only in channel order" {
    const rgb = try cg.ColorSpace.deviceRGB();
    defer rgb.deinit();

    const argb = CGImageFormat.argb8888(rgb.ref);
    const argb2 = CGImageFormat.argb8888(rgb.ref);
    const bgra = CGImageFormat.bgra8888(rgb.ref);

    try testing.expect(formatsEqual(&argb, &argb2));
    // ARGB and BGRA have the same depth, pixel size and colour space, and
    // differ only in the byte-order field of bitmapInfo.
    try testing.expect(!formatsEqual(&argb, &bgra));
    // Two nulls are *not* equal. Measured on macOS 15.7 and matched by an
    // equivalent C program; the header does not say either way, and the
    // reflexive answer would be the natural guess.
    try testing.expect(!formatsEqual(null, null));
    try testing.expect(!formatsEqual(&argb, null));
}

test "a buffer survives a round trip through a CGImage unchanged" {
    const rgb = try cg.ColorSpace.deviceRGB();
    defer rgb.deinit();

    var storage: [4 * 4 * 4]u8 = undefined;
    const src = makeTestBuffer(&storage, 4, 4);
    const fmt = CGImageFormat.argb8888(rgb.ref);

    const image = try createCGImageFromBuffer(&src, &fmt, null, null, 0);
    defer image.deinit();

    try testing.expectEqual(@as(usize, 4), image.width());
    try testing.expectEqual(@as(usize, 4), image.height());
    try testing.expectEqual(@as(usize, 8), image.bitsPerComponent());
    try testing.expectEqual(@as(usize, 32), image.bitsPerPixel());
    // Not `.premultiplied_first`, which is what went in: vImage rewrites the
    // layout to alpha-last and converts the pixels to match. Confirmed by
    // rendering such an image through a CGBitmapContext, where the colours
    // come out right.
    try testing.expectEqual(cg.AlphaInfo.premultiplied_last, image.alphaInfo());

    var dst_fmt = fmt;
    var dst: vImage_Buffer = undefined;
    try bufferInitWithCGImage(&dst, &dst_fmt, null, image.ref, 0);
    defer bufferFree(&dst);

    try testing.expectEqual(@as(usize, 4), dst.width);
    try testing.expectEqual(@as(usize, 4), dst.height);

    const out: [*]const u8 = @ptrCast(dst.data.?);
    for (0..4) |y| {
        const row = out[y * dst.rowBytes ..][0 .. 4 * 4];
        const expect = storage[y * 16 ..][0..16];
        try testing.expectEqualSlices(u8, expect, row);
    }
}

test "bufferInitWithCGImage decodes against a null colour space without filling it in" {
    const rgb = try cg.ColorSpace.deviceRGB();
    defer rgb.deinit();

    var storage: [4 * 4 * 4]u8 = undefined;
    const src = makeTestBuffer(&storage, 4, 4);
    const fmt = CGImageFormat.argb8888(rgb.ref);
    const image = try createCGImageFromBuffer(&src, &fmt, null, null, 0);
    defer image.deinit();

    // The C parameter is non-const, so it looks like an out-parameter — but
    // vImage leaves it alone. The decode succeeds against the image's own
    // colour space and the caller's field stays null.
    var dst_fmt = CGImageFormat{
        .bitsPerComponent = 8,
        .bitsPerPixel = 32,
        .colorSpace = null,
        .bitmapInfo = .{ .alpha = .premultiplied_first },
    };
    var dst: vImage_Buffer = undefined;
    try bufferInitWithCGImage(&dst, &dst_fmt, null, image.ref, 0);
    defer bufferFree(&dst);

    try testing.expectEqual(@as(usize, 4), dst.width);
    try testing.expect(dst.data != null);
    try testing.expect(dst_fmt.colorSpace == null);
}

test "a CG-format converter uses exactly one buffer on each side" {
    const rgb = try cg.ColorSpace.deviceRGB();
    defer rgb.deinit();

    const src_fmt = CGImageFormat.argb8888(rgb.ref);
    const dst_fmt = CGImageFormat.bgra8888(rgb.ref);

    const conv = try Converter.createWithCGImageFormat(&src_fmt, &dst_fmt, null, 0);
    defer conv.deinit();

    try testing.expectEqual(@as(usize, 1), conv.sourceBufferCount());
    try testing.expectEqual(@as(usize, 1), conv.destinationBufferCount());
    // An interleaved CoreGraphics format is a singleton `cg_format` buffer.
    try testing.expectEqualSlices(BufferTypeCode, &.{.cg_format}, conv.sourceBufferOrder());
    try testing.expectEqualSlices(BufferTypeCode, &.{.cg_format}, conv.destinationBufferOrder());
}

test "AnyToAny performs the ARGB-to-BGRA channel swap it was compiled for" {
    const rgb = try cg.ColorSpace.deviceRGB();
    defer rgb.deinit();

    const src_fmt = CGImageFormat.argb8888(rgb.ref);
    const dst_fmt = CGImageFormat.bgra8888(rgb.ref);
    const conv = try Converter.createWithCGImageFormat(&src_fmt, &dst_fmt, null, 0);
    defer conv.deinit();

    var src_storage: [4 * 4 * 4]u8 = undefined;
    const src = makeTestBuffer(&src_storage, 4, 4);
    var dst_storage: [4 * 4 * 4]u8 = @splat(0);
    const dst = vImage_Buffer{ .data = &dst_storage, .height = 4, .width = 4, .rowBytes = 4 * 4 };

    _ = try conv.convert(&.{src}, &.{dst}, null, 0);

    // ARGB stored big-endian, read back as a 32-bit little-endian swap, is
    // the byte sequence reversed: {A,R,G,B} -> {B,G,R,A}.
    for (0..16) |p| {
        const s = src_storage[p * 4 ..][0..4];
        const d = dst_storage[p * 4 ..][0..4];
        try testing.expectEqual(s[3], d[0]);
        try testing.expectEqual(s[2], d[1]);
        try testing.expectEqual(s[1], d[2]);
        try testing.expectEqual(s[0], d[3]);
    }
}

test "AnyToAny converts between colour spaces, not just channel orders" {
    const device = try cg.ColorSpace.deviceRGB();
    defer device.deinit();
    const srgb = try cg.ColorSpace.named(cg.ColorSpaceName.srgb());
    defer srgb.deinit();
    const gray = try cg.ColorSpace.deviceGray();
    defer gray.deinit();

    // RGB -> grayscale collapses three channels into one, so the converter
    // has to do real colour work rather than shuffle bytes.
    const src_fmt = CGImageFormat.argb8888(srgb.ref);
    const dst_fmt = CGImageFormat.gray8(gray.ref);
    const conv = try Converter.createWithCGImageFormat(&src_fmt, &dst_fmt, &[_]CGFloat{1.0}, 0);
    defer conv.deinit();

    // Two solid pixels: opaque white and opaque black.
    var src_storage = [_]u8{ 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x00, 0x00, 0x00 };
    const src = vImage_Buffer{ .data = &src_storage, .height = 1, .width = 2, .rowBytes = 8 };
    var dst_storage = [_]u8{ 0, 0 };
    const dst = vImage_Buffer{ .data = &dst_storage, .height = 1, .width = 2, .rowBytes = 2 };

    _ = try conv.convert(&.{src}, &.{dst}, null, 0);

    try testing.expectEqual(@as(u8, 0xFF), dst_storage[0]);
    // Black, to within the rounding of a linear-light round trip.
    try testing.expect(dst_storage[1] <= 1);
}

test "mustOperateOutOfPlace answers false for a same-size in-place-capable conversion" {
    const rgb = try cg.ColorSpace.deviceRGB();
    defer rgb.deinit();

    const src_fmt = CGImageFormat.argb8888(rgb.ref);
    const dst_fmt = CGImageFormat.bgra8888(rgb.ref);
    const conv = try Converter.createWithCGImageFormat(&src_fmt, &dst_fmt, null, 0);
    defer conv.deinit();

    // kvImageOutOfPlaceOperationRequired is the affirmative answer here, not
    // a failure, so a `try` on the raw code would turn "yes" into an error.
    const general = try conv.mustOperateOutOfPlace(null, null, 0);
    try testing.expect(!general);
}

test "a converter built from a CGColorConversionInfo converts the same pixels" {
    const p3 = try cg.ColorSpace.named(cg.ColorSpaceName.displayP3());
    defer p3.deinit();
    const srgb = try cg.ColorSpace.named(cg.ColorSpaceName.srgb());
    defer srgb.deinit();

    // Both spaces must be colorimetrically defined; a device colour space
    // makes CGColorConversionInfoCreate return null.
    const info = try cg.ColorConversionInfo.init(srgb.ref, p3.ref);
    defer info.deinit();

    const src_fmt = CGImageFormat.argb8888(srgb.ref);
    const dst_fmt = CGImageFormat.argb8888(p3.ref);
    const conv = try Converter.createWithCGColorConversionInfo(info.ref, &src_fmt, &dst_fmt, null, 0);
    defer conv.deinit();

    var src_storage: [4 * 4 * 4]u8 = undefined;
    const src = makeTestBuffer(&src_storage, 4, 4);
    var dst_storage: [4 * 4 * 4]u8 = @splat(0);
    const dst = vImage_Buffer{ .data = &dst_storage, .height = 4, .width = 4, .rowBytes = 16 };

    _ = try conv.convert(&.{src}, &.{dst}, null, 0);

    // Alpha is untouched by a colour-space change, and something was written.
    try testing.expectEqual(@as(u8, 0xFF), dst_storage[0]);
    try testing.expect(!std.mem.allEqual(u8, &dst_storage, 0));
}

test "retain and release balance out on a converter" {
    const rgb = try cg.ColorSpace.deviceRGB();
    defer rgb.deinit();
    const fmt = CGImageFormat.argb8888(rgb.ref);
    const conv = try Converter.createWithCGImageFormat(&fmt, &fmt, null, 0);
    defer conv.deinit();

    // vImageConverterRef is CFType-bridged, so CFGetRetainCount applies.
    const before = cg.CFGetRetainCount(conv.ref);
    const second = conv.retain();
    try testing.expectEqual(before + 1, cg.CFGetRetainCount(conv.ref));
    second.deinit();
    try testing.expectEqual(before, cg.CFGetRetainCount(conv.ref));
}

test "a failed converter creation surfaces the code from the error out-parameter" {
    const rgb = try cg.ColorSpace.deviceRGB();
    defer rgb.deinit();

    // 24 bits per pixel cannot hold three 8-bit colour channels *and* an
    // alpha channel, so this format is internally inconsistent.
    const bad = CGImageFormat{
        .bitsPerComponent = 8,
        .bitsPerPixel = 24,
        .colorSpace = rgb.ref,
        .bitmapInfo = .{ .alpha = .premultiplied_first },
    };
    const good = CGImageFormat.argb8888(rgb.ref);
    try testing.expectError(VImageError.InvalidImageFormat, Converter.createWithCGImageFormat(&bad, &good, null, 0));

    // Not every documented constraint is actually enforced, though: the
    // header says bitsPerComponent must be one of 5, 8, 16 or 32, and a
    // converter with 7 is created anyway. Pinned so the difference between
    // "documented" and "checked" stays visible.
    const undocumented = CGImageFormat{
        .bitsPerComponent = 7,
        .bitsPerPixel = 28,
        .colorSpace = rgb.ref,
        .bitmapInfo = .{ .alpha = .premultiplied_first },
    };
    const accepted = try Converter.createWithCGImageFormat(&undocumented, &good, null, 0);
    accepted.deinit();
}
