//! `vImage_CVUtilities.h` — CoreVideo interoperation.
//!
//! Two things live here. `CVImageFormat` is vImage's description of a
//! `CVPixelBuffer`'s format: its four-character format code, the colour space
//! and YCbCr matrix to interpret it with, where the chroma samples sit, and
//! the per-channel encoding ranges that make "video range" video range. The
//! rest are bridges that move pixels between a `vImage_Buffer` and a
//! `CVPixelBuffer`, either in one shot or through a reusable
//! `utilities.Converter`.
//!
//! A `CVPixelBuffer` carries its format code but not, in general, its colour
//! space or matrix — those normally arrive as attachments from whatever
//! produced the buffer. A format created from a bare `CVPixelBuffer` therefore
//! often has holes in it, and a converter cannot be built until they are
//! filled with `setColorSpace` and friends. The setters refuse a value that
//! contradicts one already present, reporting it through the
//! `CVImageFormat*` errors rather than by silently winning.
//!
//! Available only when the package is built with `-Dcoregraphics=true`.

const std = @import("std");
const types = @import("types.zig");
const cgt = @import("cg_types.zig");
const c = @import("c_cg.zig");
const cg = @import("../cg/root.zig");
const cv = @import("../cv/root.zig");
const utilities = @import("utilities.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Flags = types.vImage_Flags;
const vImage_Error = types.vImage_Error;
const Error = types.Error;
const check = types.check;
const vImageCVImageFormat = types.vImageCVImageFormat;
const vImageConverter = types.vImageConverter;
const ARGBToYpCbCrMatrix = types.vImage_ARGBToYpCbCrMatrix;
const Options = types.Options;

const CGFloat = cg.CGFloat;
const CVPixelBuffer = cv.CVPixelBuffer;
const Converter = utilities.Converter;

/// This namespace is present; the mirror-image placeholder installed when
/// `-Dcoregraphics` is off sets this to `false`.
pub const enabled = true;

// -- Re-exported types --
pub const CGImageFormat = cgt.CGImageFormat;
pub const BufferTypeCode = cgt.BufferTypeCode;
pub const ChannelDescription = cgt.ChannelDescription;
pub const MatrixType = cgt.MatrixType;
pub const TransferFunction = cgt.TransferFunction;
pub const RGBPrimaries = cgt.RGBPrimaries;
pub const WhitePoint = cgt.WhitePoint;

/// The conversion matrix a `CVImageFormat` carries, as a tagged value rather
/// than the C API's `(const void *, vImageMatrixType *)` pair.
pub const ConversionMatrix = union(enum) {
    /// The format needs no matrix — an RGB format, for instance.
    none,
    /// Borrowed from the format; do not free, and do not let it outlive the
    /// format or the next mutation of it.
    argb_to_ypcbcr: *const ARGBToYpCbCrMatrix,
};

// ============================================================================
// vImageCVImageFormatRef
// ============================================================================

/// An owned `vImageCVImageFormatRef`.
pub const CVImageFormat = struct {
    /// Borrowed for as long as this wrapper lives.
    ref: *vImageCVImageFormat,

    /// Take ownership of an existing +1 reference without retaining.
    pub fn adopt(ref: *vImageCVImageFormat) CVImageFormat {
        return .{ .ref = ref };
    }

    /// Retain a borrowed pointer and return it as an owned reference.
    pub fn borrow(ref: *vImageCVImageFormat) CVImageFormat {
        c.vImageCVImageFormat_Retain(ref);
        return .{ .ref = ref };
    }

    /// Describe an existing pixel buffer.
    ///
    /// `vImageCVImageFormat_CreateWithCVPixelBuffer`. The result reflects
    /// only what the buffer actually knows about itself — for a buffer with
    /// no colour attachments, expect `colorSpace()` to be null and to have to
    /// set it before building a converter.
    pub fn initWithCVPixelBuffer(buffer: *CVPixelBuffer) Error!CVImageFormat {
        const ref = c.vImageCVImageFormat_CreateWithCVPixelBuffer(buffer) orelse
            return Error.InvalidCVImageFormat;
        return adopt(ref);
    }

    /// Describe a format from scratch.
    ///
    /// `vImageCVImageFormat_Create`. `format_type` is a
    /// `kCVPixelFormatType_*` code — `cv.PixelFormat` has the common ones.
    /// `matrix` and `chroma_location` are only meaningful for YCbCr formats
    /// and may be null otherwise; `Conversion.h`'s standard 601 and 709
    /// matrices are the usual arguments.
    ///
    /// `alpha_is_one` asserts that the format has an alpha channel whose
    /// every value is opaque, which lets vImage skip the alpha work entirely.
    pub fn init(
        format_type: u32,
        matrix: ?*const ARGBToYpCbCrMatrix,
        chroma_location: cg.CFStringRef,
        base_colorspace: ?*cg.CGColorSpace,
        alpha_is_one: bool,
    ) Error!CVImageFormat {
        const ref = c.vImageCVImageFormat_Create(
            format_type,
            matrix,
            chroma_location,
            base_colorspace,
            @intFromBool(alpha_is_one),
        ) orelse return Error.InvalidCVImageFormat;
        return adopt(ref);
    }

    /// An independent copy that can be mutated without disturbing the
    /// original. `vImageCVImageFormat_Copy`.
    pub fn copy(self: CVImageFormat) Error!CVImageFormat {
        const ref = c.vImageCVImageFormat_Copy(self.ref) orelse return Error.MemoryAllocationError;
        return adopt(ref);
    }

    /// A second owned reference. `vImageCVImageFormat_Retain`.
    pub fn retain(self: CVImageFormat) CVImageFormat {
        return borrow(self.ref);
    }

    /// `vImageCVImageFormat_Release`.
    pub fn deinit(self: *CVImageFormat) void {
        c.vImageCVImageFormat_Release(self.ref);
    }

    /// The `kCVPixelFormatType_*` code. `vImageCVImageFormat_GetFormatCode`.
    pub fn formatCode(self: CVImageFormat) u32 {
        return c.vImageCVImageFormat_GetFormatCode(self.ref);
    }

    /// Same value as `formatCode`, typed. `cv.PixelFormat` is an open enum,
    /// so an unrecognised code round-trips rather than being rejected.
    pub fn pixelFormat(self: CVImageFormat) cv.PixelFormat {
        return @enumFromInt(self.formatCode());
    }

    /// How many channels this format has across all its planes.
    /// `vImageCVImageFormat_GetChannelCount`.
    pub fn channelCount(self: CVImageFormat) u32 {
        return c.vImageCVImageFormat_GetChannelCount(self.ref);
    }

    /// What each channel is, in order. `vImageCVImageFormat_GetChannelNames`.
    ///
    /// The C array is `end_of_list`-terminated; the slice here excludes the
    /// terminator and is borrowed from the format.
    pub fn channelNames(self: CVImageFormat) []const BufferTypeCode {
        const p = c.vImageCVImageFormat_GetChannelNames(self.ref) orelse return &.{};
        var n: usize = 0;
        while (p[n] != .end_of_list) n += 1;
        return p[0..n];
    }

    /// The base colour space, **borrowed**, or null if the format does not
    /// have one yet. `vImageCVImageFormat_GetColorSpace`.
    pub fn colorSpace(self: CVImageFormat) ?*cg.CGColorSpace {
        return c.vImageCVImageFormat_GetColorSpace(self.ref);
    }

    /// `vImageCVImageFormat_SetColorSpace`. The format retains its own
    /// reference, so the caller keeps ownership of `space`.
    ///
    /// Fails with `CVImageFormatColorSpace` if the format already has a
    /// colour space that this one contradicts.
    pub fn setColorSpace(self: CVImageFormat, space: ?*cg.CGColorSpace) Error!void {
        _ = try check(c.vImageCVImageFormat_SetColorSpace(self.ref, space));
    }

    /// Where the chroma samples sit relative to the luma grid, as a
    /// `kCVImageBufferChromaLocation_*` string. Borrowed, or null if unset.
    /// `vImageCVImageFormat_GetChromaSiting`.
    pub fn chromaSiting(self: CVImageFormat) cg.CFStringRef {
        return c.vImageCVImageFormat_GetChromaSiting(self.ref);
    }

    /// `vImageCVImageFormat_SetChromaSiting`. See `cv.ChromaLocation`.
    pub fn setChromaSiting(self: CVImageFormat, siting: cg.CFStringRef) Error!void {
        _ = try check(c.vImageCVImageFormat_SetChromaSiting(self.ref, siting));
    }

    /// The RGB-to-YCbCr matrix this format is interpreted with.
    ///
    /// `vImageCVImageFormat_GetConversionMatrix`. The C signature returns an
    /// untyped `const void *` alongside a type tag written through an
    /// out-parameter; this returns the two as one tagged union so the pointer
    /// cannot be read at the wrong type.
    pub fn conversionMatrix(self: CVImageFormat) ConversionMatrix {
        var kind: MatrixType = .none;
        const p = c.vImageCVImageFormat_GetConversionMatrix(self.ref, &kind);
        return switch (kind) {
            .argb_to_ypcbcr => if (p) |ptr|
                .{ .argb_to_ypcbcr = @ptrCast(@alignCast(ptr)) }
            else
                .none,
            else => .none,
        };
    }

    /// `vImageCVImageFormat_CopyConversionMatrix`. The matrix is copied into
    /// the format, so the argument need not outlive the call.
    pub fn setConversionMatrix(self: CVImageFormat, matrix: ConversionMatrix) Error!void {
        switch (matrix) {
            .none => {},
            .argb_to_ypcbcr => |m| _ = try check(c.vImageCVImageFormat_CopyConversionMatrix(self.ref, m, .argb_to_ypcbcr)),
        }
    }

    /// Whether every pixel's alpha is known to be opaque.
    ///
    /// `vImageCVImageFormat_GetAlphaHint`. The C return is an `int`, and the
    /// contract is "zero or non-zero" rather than a specific value: 0 means
    /// the hint is unset or alpha is not known to be opaque, and any non-zero
    /// value means it is. A format with no alpha channel at all also reports
    /// non-zero — measured as 2 for `420v` on macOS 15.7, which is why this
    /// returns the raw `c_int` and `alphaIsOne` does the comparison.
    pub fn alphaHint(self: CVImageFormat) c_int {
        return c.vImageCVImageFormat_GetAlphaHint(self.ref);
    }

    /// `alphaHint() != 0` — the test the header actually specifies.
    pub fn alphaIsOne(self: CVImageFormat) bool {
        return self.alphaHint() != 0;
    }

    /// `vImageCVImageFormat_SetAlphaHint`.
    pub fn setAlphaHint(self: CVImageFormat, alpha_is_one: bool) Error!void {
        _ = try check(c.vImageCVImageFormat_SetAlphaHint(self.ref, @intFromBool(alpha_is_one)));
    }

    /// The encoding range and clamp limits of one channel, borrowed, or null
    /// if the format does not describe that channel.
    /// `vImageCVImageFormat_GetChannelDescription`.
    pub fn channelDescription(self: CVImageFormat, channel: BufferTypeCode) ?*const ChannelDescription {
        return c.vImageCVImageFormat_GetChannelDescription(self.ref, channel);
    }

    /// `vImageCVImageFormat_CopyChannelDescription`. Copied into the format.
    pub fn setChannelDescription(self: CVImageFormat, channel: BufferTypeCode, desc: *const ChannelDescription) Error!void {
        _ = try check(c.vImageCVImageFormat_CopyChannelDescription(self.ref, desc, channel));
    }

    /// `vImageCVImageFormat_GetUserData`.
    pub fn userData(self: CVImageFormat) ?*anyopaque {
        return c.vImageCVImageFormat_GetUserData(self.ref);
    }

    /// Attach an arbitrary pointer to the format.
    ///
    /// `vImageCVImageFormat_SetUserData`. `release_callback` runs when the
    /// format is destroyed or the user data is replaced, and is the only hook
    /// for freeing whatever `data` points at.
    pub fn setUserData(
        self: CVImageFormat,
        data: ?*anyopaque,
        release_callback: ?*const fn (fmt: ?*vImageCVImageFormat, data: ?*anyopaque) callconv(.c) void,
    ) Error!void {
        _ = try check(c.vImageCVImageFormat_SetUserData(self.ref, data, release_callback));
    }
};

// ============================================================================
// One-shot pixel-buffer bridges
// ============================================================================

/// Decode a `CVPixelBuffer` into a freshly allocated `vImage_Buffer`.
///
/// `vImageBuffer_InitWithCVPixelBuffer`. Release `buf.data` with
/// `utilities.bufferFree`.
///
/// The pixel buffer must be locked for the duration of the call. `cv_format`
/// may be null to let vImage derive the format from the buffer's own
/// attachments; supply one when those attachments are absent or wrong.
/// `desired_format` is mutable for the same reason as in
/// `utilities.bufferInitWithCGImage` — a null `colorSpace` is filled in.
pub fn bufferInitWithCVPixelBuffer(
    buf: *vImage_Buffer,
    desired_format: *CGImageFormat,
    pixel_buffer: *CVPixelBuffer,
    cv_format: ?CVImageFormat,
    background_color: ?[]const CGFloat,
    flags: Options,
) Error!void {
    const bg: ?[*]const CGFloat = if (background_color) |b| b.ptr else null;
    const fmt: ?*vImageCVImageFormat = if (cv_format) |f| f.ref else null;
    _ = try check(c.vImageBuffer_InitWithCVPixelBuffer(buf, desired_format, pixel_buffer, fmt, bg, flags.bits()));
}

/// Encode a `vImage_Buffer` into an existing `CVPixelBuffer`.
///
/// `vImageBuffer_CopyToCVPixelBuffer`. The pixel buffer must be locked, and
/// already have the dimensions and format the copy should produce.
pub fn bufferCopyToCVPixelBuffer(
    buf: *const vImage_Buffer,
    buffer_format: *const CGImageFormat,
    pixel_buffer: *CVPixelBuffer,
    cv_format: ?CVImageFormat,
    background_color: ?[]const CGFloat,
    flags: Options,
) Error!void {
    const bg: ?[*]const CGFloat = if (background_color) |b| b.ptr else null;
    const fmt: ?*vImageCVImageFormat = if (cv_format) |f| f.ref else null;
    _ = try check(c.vImageBuffer_CopyToCVPixelBuffer(buf, buffer_format, pixel_buffer, fmt, bg, flags.bits()));
}

// ============================================================================
// Converter-based bridges
// ============================================================================

/// Compile a conversion from a CoreGraphics format into a CoreVideo one.
///
/// `vImageConverter_CreateForCGToCVImageFormat`. `dest_format` must be
/// complete — a colour space and, for YCbCr, a matrix and chroma siting —
/// or creation fails with the corresponding `CVImageFormat*` error.
pub fn converterForCGToCVImageFormat(
    src_format: *const CGImageFormat,
    dest_format: CVImageFormat,
    background_color: ?[]const CGFloat,
    flags: Options,
) Error!Converter {
    var err: vImage_Error = 0;
    const bg: ?[*]const CGFloat = if (background_color) |b| b.ptr else null;
    const ref = c.vImageConverter_CreateForCGToCVImageFormat(src_format, dest_format.ref, bg, flags.bits(), &err);
    return finishConverter(ref, err);
}

/// `vImageConverter_CreateForCVToCGImageFormat`.
pub fn converterForCVToCGImageFormat(
    src_format: CVImageFormat,
    dest_format: *const CGImageFormat,
    background_color: ?[]const CGFloat,
    flags: Options,
) Error!Converter {
    var err: vImage_Error = 0;
    const bg: ?[*]const CGFloat = if (background_color) |b| b.ptr else null;
    const ref = c.vImageConverter_CreateForCVToCGImageFormat(src_format.ref, dest_format, bg, flags.bits(), &err);
    return finishConverter(ref, err);
}

fn finishConverter(ref: ?*vImageConverter, err: vImage_Error) Error!Converter {
    if (ref) |r| return Converter.adopt(r);
    _ = try check(err);
    return Error.Unknown;
}

/// Point an array of `vImage_Buffer`s at a locked pixel buffer's planes, ready
/// to be the *destination* of `Converter.convert`.
///
/// `vImageBuffer_InitForCopyToCVPixelBuffer`. `buffers.len` must equal
/// `converter.destinationBufferCount()`, which for a planar format is more
/// than one — this is the point of the function, since a YCbCr pixel buffer
/// becomes two or three vImage buffers.
///
/// Set `.do_not_allocate` (`kvImageNoAllocate`) to alias the pixel buffer's
/// own memory rather
/// than allocate; the conversion then writes straight into it, and nothing
/// needs freeing.
pub fn bufferInitForCopyToCVPixelBuffer(
    buffers: []vImage_Buffer,
    converter: Converter,
    pixel_buffer: *CVPixelBuffer,
    flags: Options,
) Error!void {
    std.debug.assert(buffers.len == converter.destinationBufferCount());
    _ = try check(c.vImageBuffer_InitForCopyToCVPixelBuffer(buffers.ptr, converter.ref, pixel_buffer, flags.bits()));
}

/// The mirror image: prepare buffers to be the *source* of a conversion out
/// of a pixel buffer. `vImageBuffer_InitForCopyFromCVPixelBuffer`.
pub fn bufferInitForCopyFromCVPixelBuffer(
    buffers: []vImage_Buffer,
    converter: Converter,
    pixel_buffer: *CVPixelBuffer,
    flags: Options,
) Error!void {
    std.debug.assert(buffers.len == converter.sourceBufferCount());
    _ = try check(c.vImageBuffer_InitForCopyFromCVPixelBuffer(buffers.ptr, converter.ref, pixel_buffer, flags.bits()));
}

// ============================================================================
// Colour space construction
// ============================================================================

/// Build an RGB colour space from primaries and a transfer function.
///
/// `vImageCreateRGBColorSpaceWithPrimariesAndTransferFunction`. This is how
/// you get a `CGColorSpace` for a video colour space that CoreGraphics has no
/// name for — the parameters are exactly what a video standard specifies.
pub fn createRGBColorSpace(
    primaries: *const RGBPrimaries,
    tf: *const TransferFunction,
    intent: cg.RenderingIntent,
    flags: Options,
) Error!cg.ColorSpace {
    var err: vImage_Error = 0;
    const ref = c.vImageCreateRGBColorSpaceWithPrimariesAndTransferFunction(primaries, tf, intent, flags.bits(), &err);
    if (ref) |r| return cg.ColorSpace.adopt(r);
    _ = try check(err);
    return Error.Unknown;
}

/// `vImageCreateMonochromeColorSpaceWithWhitePointAndTransferFunction`.
pub fn createMonochromeColorSpace(
    white_point: *const WhitePoint,
    tf: *const TransferFunction,
    intent: cg.RenderingIntent,
    flags: Options,
) Error!cg.ColorSpace {
    var err: vImage_Error = 0;
    const ref = c.vImageCreateMonochromeColorSpaceWithWhitePointAndTransferFunction(white_point, tf, intent, flags.bits(), &err);
    if (ref) |r| return cg.ColorSpace.adopt(r);
    _ = try check(err);
    return Error.Unknown;
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const conversion = @import("conversion.zig");

test "a format created from a 32BGRA pixel buffer reports that format back" {
    var pb = try cv.PixelBuffer.init(8, 8, .bgra32);
    defer pb.deinit();

    var fmt = try CVImageFormat.initWithCVPixelBuffer(pb.ref);
    defer fmt.deinit();

    try testing.expectEqual(cv.fourCC("BGRA"), fmt.formatCode());
    try testing.expectEqual(cv.PixelFormat.bgra32, fmt.pixelFormat());
    try testing.expectEqual(@as(u32, 4), fmt.channelCount());

    // The channel-name list is end_of_list-terminated in C, so its length
    // must come out equal to the channel count once the terminator is
    // dropped.
    const names = fmt.channelNames();
    try testing.expectEqual(@as(usize, 4), names.len);

    // An RGB format needs no YCbCr matrix.
    try testing.expectEqual(ConversionMatrix.none, fmt.conversionMatrix());
}

test "a 420v format is YCbCr, needs a matrix, and starts without a colour space" {
    var pb = try cv.PixelBuffer.init(16, 16, .ycbcr420_biplanar_video);
    defer pb.deinit();

    var fmt = try CVImageFormat.initWithCVPixelBuffer(pb.ref);
    defer fmt.deinit();

    try testing.expectEqual(cv.fourCC("420v"), fmt.formatCode());
    // Y', Cb and Cr.
    try testing.expectEqual(@as(u32, 3), fmt.channelCount());

    // A bare CVPixelBuffer carries no colour attachments, so vImage has
    // nothing to derive a colour space from and the format arrives
    // incomplete. This is the hole that has to be filled before a converter
    // can be built.
    try testing.expect(fmt.colorSpace() == null);

    var srgb = try cg.ColorSpace.initNamed(cg.ColorSpaceName.srgb());
    defer srgb.deinit();
    try fmt.setColorSpace(srgb.ref);
    try testing.expect(fmt.colorSpace() != null);
}

test "a YCbCr format built from scratch keeps the matrix it was given" {
    var srgb = try cg.ColorSpace.initNamed(cg.ColorSpaceName.srgb());
    defer srgb.deinit();

    const argb_matrix = conversion.ycbcr.argbToYpCbCrMatrix601();

    var fmt = try CVImageFormat.init(
        cv.fourCC("420v"),
        argb_matrix,
        cv.ChromaLocation.center(),
        srgb.ref,
        false,
    );
    defer fmt.deinit();

    try testing.expectEqual(cv.fourCC("420v"), fmt.formatCode());
    try testing.expect(fmt.colorSpace() != null);

    // The tagged union is what keeps the `const void *` from being read at
    // the wrong type: the tag and the pointer come out of C separately.
    switch (fmt.conversionMatrix()) {
        .none => return error.ExpectedAMatrix,
        .argb_to_ypcbcr => |m| {
            try testing.expectApproxEqAbs(argb_matrix.R_Yp, m.R_Yp, 1e-6);
            try testing.expectApproxEqAbs(argb_matrix.B_Yp, m.B_Yp, 1e-6);
        },
    }

    const siting = fmt.chromaSiting() orelse return error.ExpectedASiting;
    try testing.expect(cg.equal(siting, cv.ChromaLocation.center().?));
}

test "the alpha hint is zero-or-non-zero, and 'no alpha at all' counts as set" {
    var pb = try cv.PixelBuffer.init(8, 8, .bgra32);
    defer pb.deinit();
    var fmt = try CVImageFormat.initWithCVPixelBuffer(pb.ref);
    defer fmt.deinit();

    // A format with an alpha channel and no promise about it reports 0.
    try testing.expectEqual(@as(c_int, 0), fmt.alphaHint());
    try testing.expect(!fmt.alphaIsOne());
    try fmt.setAlphaHint(true);
    try testing.expect(fmt.alphaIsOne());

    // A format with no alpha channel at all also reports non-zero — and the
    // specific value is 2, not 1. Treating the hint as a boolean-valued int
    // rather than as `!= 0` would get this wrong.
    var pb2 = try cv.PixelBuffer.init(16, 16, .ycbcr420_biplanar_video);
    defer pb2.deinit();
    var fmt2 = try CVImageFormat.initWithCVPixelBuffer(pb2.ref);
    defer fmt2.deinit();
    try testing.expectEqual(@as(c_int, 2), fmt2.alphaHint());
    try testing.expect(fmt2.alphaIsOne());
}

test "a 420v format describes its luma channel with a video range" {
    var pb = try cv.PixelBuffer.init(16, 16, .ycbcr420_biplanar_video);
    defer pb.deinit();
    var fmt = try CVImageFormat.initWithCVPixelBuffer(pb.ref);
    defer fmt.deinit();

    // "Video range" 8-bit luma is the classic 16..235 encoding; this is the
    // whole reason ChannelDescription exists.
    const luma = fmt.channelDescription(.luminance) orelse return error.ExpectedADescription;
    try testing.expectApproxEqAbs(@as(CGFloat, 16), luma.zero, 1e-9);
    try testing.expectApproxEqAbs(@as(CGFloat, 235), luma.full, 1e-9);

    // Chroma is biased to 128 and encodes 0.5 rather than 1.0 at `full`.
    const cb = fmt.channelDescription(.cb) orelse return error.ExpectedADescription;
    try testing.expectApproxEqAbs(@as(CGFloat, 128), cb.zero, 1e-9);
    try testing.expectApproxEqAbs(@as(CGFloat, 240), cb.full, 1e-9);
}

test "copy produces a format that can be mutated independently" {
    var pb = try cv.PixelBuffer.init(8, 8, .bgra32);
    defer pb.deinit();
    var original = try CVImageFormat.initWithCVPixelBuffer(pb.ref);
    defer original.deinit();

    var duplicate = try original.copy();
    defer duplicate.deinit();

    try testing.expect(duplicate.ref != original.ref);
    try testing.expectEqual(original.formatCode(), duplicate.formatCode());

    try duplicate.setAlphaHint(true);
    try testing.expectEqual(@as(c_int, 1), duplicate.alphaHint());
    try testing.expectEqual(@as(c_int, 0), original.alphaHint());
}

var user_data_released: usize = 0;

fn releaseUserData(_: ?*vImageCVImageFormat, data: ?*anyopaque) callconv(.c) void {
    _ = data;
    user_data_released += 1;
}

test "the user-data release callback runs when the format is destroyed" {
    user_data_released = 0;
    var payload: u32 = 0xDEADBEEF;

    {
        var pb = try cv.PixelBuffer.init(8, 8, .bgra32);
        defer pb.deinit();
        var fmt = try CVImageFormat.initWithCVPixelBuffer(pb.ref);
        try fmt.setUserData(&payload, releaseUserData);

        const back: *u32 = @ptrCast(@alignCast(fmt.userData().?));
        try testing.expectEqual(@as(u32, 0xDEADBEEF), back.*);
        try testing.expectEqual(@as(usize, 0), user_data_released);

        fmt.deinit();
    }

    try testing.expectEqual(@as(usize, 1), user_data_released);
}

test "retain and release balance out on a CV image format" {
    var pb = try cv.PixelBuffer.init(8, 8, .bgra32);
    defer pb.deinit();
    var fmt = try CVImageFormat.initWithCVPixelBuffer(pb.ref);
    defer fmt.deinit();

    const before = cg.CFGetRetainCount(fmt.ref);
    var second = fmt.retain();
    try testing.expectEqual(before + 1, cg.CFGetRetainCount(fmt.ref));
    second.deinit();
    try testing.expectEqual(before, cg.CFGetRetainCount(fmt.ref));
}

test "pixels round-trip from a vImage_Buffer through a BGRA pixel buffer and back" {
    var rgb = try cg.ColorSpace.initDeviceRGB();
    defer rgb.deinit();

    // A 4x4 image with a distinct byte in every channel of every pixel.
    var src_storage: [4 * 4 * 4]u8 = undefined;
    for (0..16) |p| {
        src_storage[p * 4 + 0] = 0xFF;
        src_storage[p * 4 + 1] = @intCast(0x10 + p);
        src_storage[p * 4 + 2] = @intCast(0x30 + p);
        src_storage[p * 4 + 3] = @intCast(0x50 + p);
    }
    const src = vImage_Buffer{ .data = &src_storage, .height = 4, .width = 4, .rowBytes = 16 };
    const fmt = CGImageFormat.argb8888(rgb.ref);

    var pb = try cv.PixelBuffer.init(4, 4, .bgra32);
    defer pb.deinit();

    // A CVPixelBuffer created without attributes carries no colour
    // attachments, so passing null here fails with
    // `InvalidCVImageFormat` (-21782) — vImage has nothing to interpret the
    // pixels with. Supplying a format with a colour space is what makes the
    // bridge work on a bare buffer.
    var cv_fmt = try CVImageFormat.initWithCVPixelBuffer(pb.ref);
    defer cv_fmt.deinit();
    try cv_fmt.setColorSpace(rgb.ref);

    try testing.expectError(
        Error.InvalidCVImageFormat,
        bufferCopyToCVPixelBuffer(&src, &fmt, pb.ref, null, null, .{}),
    );

    try pb.lock(0);
    try bufferCopyToCVPixelBuffer(&src, &fmt, pb.ref, cv_fmt, null, .{});
    try pb.unlock(0);

    var dst_fmt = fmt;
    var dst: vImage_Buffer = undefined;
    try pb.lock(cv.lock_read_only);
    try bufferInitWithCVPixelBuffer(&dst, &dst_fmt, pb.ref, cv_fmt, null, .{});
    try pb.unlock(cv.lock_read_only);
    defer utilities.bufferFree(&dst);

    try testing.expectEqual(@as(usize, 4), dst.width);
    try testing.expectEqual(@as(usize, 4), dst.height);

    // BGRA is a lossless permutation of ARGB, so the round trip is exact.
    const out: [*]const u8 = @ptrCast(dst.data.?);
    for (0..4) |y| {
        try testing.expectEqualSlices(u8, src_storage[y * 16 ..][0..16], out[y * dst.rowBytes ..][0..16]);
    }
}

test "a CG-to-CV converter for 420v splits the destination into two planes" {
    var srgb = try cg.ColorSpace.initNamed(cg.ColorSpaceName.srgb());
    defer srgb.deinit();
    var rgb = try cg.ColorSpace.initDeviceRGB();
    defer rgb.deinit();

    var cv_fmt = try CVImageFormat.init(
        cv.fourCC("420v"),
        conversion.ycbcr.argbToYpCbCrMatrix601(),
        cv.ChromaLocation.center(),
        srgb.ref,
        false,
    );
    defer cv_fmt.deinit();

    const cg_fmt = CGImageFormat.argb8888(rgb.ref);
    var conv = try converterForCGToCVImageFormat(&cg_fmt, cv_fmt, &[_]CGFloat{ 0, 0, 0 }, .{});
    defer conv.deinit();

    // One interleaved ARGB buffer in, two planes out: Y' and interleaved
    // CbCr. This is what the buffer-order query is for.
    try testing.expectEqual(@as(usize, 1), conv.sourceBufferCount());
    try testing.expectEqual(@as(usize, 2), conv.destinationBufferCount());
    try testing.expectEqualSlices(BufferTypeCode, &.{.cg_format}, conv.sourceBufferOrder());
    try testing.expectEqualSlices(BufferTypeCode, &.{ .luminance, .chroma }, conv.destinationBufferOrder());
}

test "InitForCopyToCVPixelBuffer aliases the pixel buffer's own planes" {
    var srgb = try cg.ColorSpace.initNamed(cg.ColorSpaceName.srgb());
    defer srgb.deinit();
    var rgb = try cg.ColorSpace.initDeviceRGB();
    defer rgb.deinit();

    var pb = try cv.PixelBuffer.init(16, 16, .ycbcr420_biplanar_video);
    defer pb.deinit();

    var cv_fmt = try CVImageFormat.initWithCVPixelBuffer(pb.ref);
    defer cv_fmt.deinit();
    try cv_fmt.setColorSpace(srgb.ref);
    try cv_fmt.setConversionMatrix(.{ .argb_to_ypcbcr = conversion.ycbcr.argbToYpCbCrMatrix601() });
    try cv_fmt.setChromaSiting(cv.ChromaLocation.center());

    const cg_fmt = CGImageFormat.argb8888(rgb.ref);
    var conv = try converterForCGToCVImageFormat(&cg_fmt, cv_fmt, &[_]CGFloat{ 0, 0, 0 }, .{});
    defer conv.deinit();

    var planes: [2]vImage_Buffer = undefined;
    try pb.lock(0);
    defer pb.unlock(0) catch {};
    try bufferInitForCopyToCVPixelBuffer(&planes, conv, pb.ref, .{ .do_not_allocate = true });

    // kvImageNoAllocate means the vImage buffers point straight at the pixel
    // buffer's planes rather than at new memory — so the addresses must
    // match, and nothing needs freeing.
    try testing.expectEqual(pb.baseAddressOfPlane(0), planes[0].data);
    try testing.expectEqual(pb.baseAddressOfPlane(1), planes[1].data);
    try testing.expectEqual(@as(usize, 16), planes[0].width);
    try testing.expectEqual(@as(usize, 16), planes[0].height);

    // The chroma plane is described in the *luma* geometry, 16x16, even
    // though CoreVideo reports the same plane as 8x8 and it holds a quarter
    // as many samples. vImage knows the subsampling from the format code and
    // expects the buffer described at full resolution; sizing a chroma buffer
    // from `CVPixelBufferGetWidthOfPlane` instead would be a four-fold
    // undercount. Measured, and matched by an equivalent C program.
    try testing.expectEqual(@as(usize, 16), planes[1].width);
    try testing.expectEqual(@as(usize, 16), planes[1].height);
    try testing.expectEqual(@as(usize, 8), pb.widthOfPlane(1));
    try testing.expectEqual(@as(usize, 8), pb.heightOfPlane(1));

    // And the conversion actually runs into them.
    var src_storage: [16 * 16 * 4]u8 = @splat(0xFF);
    const src = vImage_Buffer{ .data = &src_storage, .height = 16, .width = 16, .rowBytes = 16 * 4 };
    _ = try conv.convert(&.{src}, &planes, null, .{});

    // Opaque white in video-range luma is 235.
    const luma: [*]const u8 = @ptrCast(planes[0].data.?);
    try testing.expectEqual(@as(u8, 235), luma[0]);
}

test "a colour space can be built from primaries and a transfer function" {
    var space = try createRGBColorSpace(&RGBPrimaries.itur_709, &TransferFunction.itur_709, .default, .{});
    defer space.deinit();

    try testing.expectEqual(@as(usize, 3), space.componentCount());
    try testing.expectEqual(cg.ColorSpaceModel.rgb, space.model());
}

test "a monochrome colour space can be built from a white point" {
    var space = try createMonochromeColorSpace(&WhitePoint.d65, &TransferFunction.gammaOnly(2.2), .default, .{});
    defer space.deinit();

    try testing.expectEqual(@as(usize, 1), space.componentCount());
    try testing.expectEqual(cg.ColorSpaceModel.monochrome, space.model());
}

test "a CV-to-CG converter runs the YCbCr decode back to ARGB" {
    var srgb = try cg.ColorSpace.initNamed(cg.ColorSpaceName.srgb());
    defer srgb.deinit();
    var rgb = try cg.ColorSpace.initDeviceRGB();
    defer rgb.deinit();

    var pb = try cv.PixelBuffer.init(16, 16, .ycbcr420_biplanar_video);
    defer pb.deinit();
    var cv_fmt = try CVImageFormat.initWithCVPixelBuffer(pb.ref);
    defer cv_fmt.deinit();
    try cv_fmt.setColorSpace(srgb.ref);
    try cv_fmt.setConversionMatrix(.{ .argb_to_ypcbcr = conversion.ycbcr.argbToYpCbCrMatrix601() });
    try cv_fmt.setChromaSiting(cv.ChromaLocation.center());

    const cg_fmt = CGImageFormat.argb8888(rgb.ref);
    var conv = try converterForCVToCGImageFormat(cv_fmt, &cg_fmt, &[_]CGFloat{ 0, 0, 0 }, .{});
    defer conv.deinit();

    try testing.expectEqual(@as(usize, 2), conv.sourceBufferCount());
    try testing.expectEqual(@as(usize, 1), conv.destinationBufferCount());

    // Fill the pixel buffer with video-range white: luma 235, chroma 128.
    try pb.lock(0);
    defer pb.unlock(0) catch {};
    var planes: [2]vImage_Buffer = undefined;
    try bufferInitForCopyFromCVPixelBuffer(&planes, conv, pb.ref, .{ .do_not_allocate = true });
    {
        const luma: [*]u8 = @ptrCast(planes[0].data.?);
        @memset(luma[0 .. planes[0].rowBytes * planes[0].height], 235);
        const chroma: [*]u8 = @ptrCast(planes[1].data.?);
        @memset(chroma[0 .. planes[1].rowBytes * planes[1].height], 128);
    }

    var dst_storage: [16 * 16 * 4]u8 = @splat(0);
    const dst = vImage_Buffer{ .data = &dst_storage, .height = 16, .width = 16, .rowBytes = 16 * 4 };
    _ = try conv.convert(&planes, &.{dst}, null, .{});

    // Video-range white decodes back to full-range white, within rounding.
    try testing.expectEqual(@as(u8, 0xFF), dst_storage[0]);
    try testing.expect(dst_storage[1] >= 250);
    try testing.expect(dst_storage[2] >= 250);
    try testing.expect(dst_storage[3] >= 250);
}
