// Zig type definitions for Apple's vImage framework (vImage_Types.h).

// ============================================================================
// Core scalar types
// ============================================================================

/// Signed return type for vImage functions (ssize_t on C side).
pub const vImage_Error = isize;

/// Pixel-count / dimension type (unsigned long on C side, 64-bit on LP64).
pub const vImagePixelCount = usize;

/// Bitfield type for option flags passed to vImage functions.
pub const vImage_Flags = u32;

// ============================================================================
// Buffer
// ============================================================================

/// Describes a rectangular image buffer in memory.
pub const vImage_Buffer = extern struct {
    data: ?*anyopaque,
    height: vImagePixelCount,
    width: vImagePixelCount,
    rowBytes: usize,
};

// ============================================================================
// Affine / perspective transforms
// ============================================================================

pub const vImage_AffineTransform = extern struct {
    a: f32,
    b: f32,
    c: f32,
    d: f32,
    tx: f32,
    ty: f32,
};

pub const vImage_AffineTransform_Double = extern struct {
    a: f64,
    b: f64,
    c: f64,
    d: f64,
    tx: f64,
    ty: f64,
};

/// On 64-bit platforms CGAffineTransform uses doubles; mirror that here.
pub const vImage_CGAffineTransform = vImage_AffineTransform_Double;

pub const vImage_PerpsectiveTransform = extern struct {
    v0: [3]f64,
    v1: [3]f64,
    v2: [3]f64,
};

// ============================================================================
// Warp interpolation
// ============================================================================

pub const vImage_WarpInterpolation = enum(i32) {
    nearest = 0,
    linear = 1,
};

// ============================================================================
// Pixel types
// ============================================================================

pub const Pixel_8 = u8;
pub const Pixel_F = f32;
pub const Pixel_88 = [2]u8;
pub const Pixel_8888 = [4]u8;
pub const Pixel_FFFF = [4]f32;
pub const Pixel_FF = [2]f32;
pub const Pixel_16U = u16;
pub const Pixel_16S = i16;
pub const Pixel_16Q12 = i16;
pub const Pixel_16U16U = [2]u16;
pub const Pixel_16S16S = [2]i16;
pub const Pixel_32U = u32;
pub const Pixel_ARGB_16U = [4]u16;
pub const Pixel_ARGB_16S = [4]i16;
pub const Pixel_16F = u16;
pub const Pixel_16F16F = [2]u16;
pub const Pixel_ARGB_16F = [4]u16;

// ============================================================================
// Opaque pointer types
// ============================================================================

/// `vImage_PerpsectiveTransform` - the 3x3 projective transform matrix.
///
/// Apple's spelling of the type is `vImage_PerpsectiveTransform`, with the
/// letters of "Perspective" transposed. The name here is the corrected one;
/// the typo lives only in the header and is not part of any symbol.
pub const vImage_PerspectiveTransform = extern struct {
    a: f32,
    b: f32,
    c: f32,
    d: f32,
    tx: f32,
    ty: f32,
    /// The projective vector's x component. Zero for an affine transform.
    vx: f32,
    /// The projective vector's y component. Zero for an affine transform.
    vy: f32,
    /// The homogeneous scale factor. One for an affine transform.
    v: f32,
};

/// `vImage_WarpInterpolation` - how `perspectiveWarp` samples the source.
pub const WarpInterpolation = enum(i32) {
    nearest = 0,
    linear = 1,
};

/// The kernel-shape callback `vImageNewResamplingFilterForFunctionUsingBuffer`
/// takes.
///
/// vImage calls it with a batch of `count` x-coordinates and expects the
/// corresponding filter weights written to `yArray`. It is a plain C function
/// pointer with a `userData` context, so no block shim is needed.
pub const KernelFunc = ?*const fn (xArray: [*]const f32, yArray: [*]f32, count: c_ulong, userData: ?*anyopaque) callconv(.c) void;

/// Resampling filter handle used by Geometry functions.
pub const ResamplingFilter = ?*opaque {};

/// Gamma transfer-function handle used by vImageGamma.
pub const GammaFunction = ?*opaque {};

/// Handle to a multidimensional interpolated lookup table.
pub const vImage_MultidimensionalTable = ?*opaque {};

/// A vImage pixel-format converter (CFType-bridged). Named rather than an
/// anonymous `opaque {}` so that wrappers can spell the non-optional
/// `*vImageConverter` for an object that is known to exist.
pub const vImageConverter = opaque {};
/// Handle to a vImage pixel-format converter (CFType-bridged).
pub const vImageConverterRef = ?*vImageConverter;

/// A CoreVideo image format description.
pub const vImageCVImageFormat = opaque {};
/// Handle to a CoreVideo image format description.
pub const vImageCVImageFormatRef = ?*vImageCVImageFormat;
pub const vImageConstCVImageFormatRef = ?*const vImageCVImageFormat;

// ============================================================================
// YpCbCr types
// ============================================================================

pub const vImageARGBType = enum(c_int) {
    kvImageARGB8888 = 0,
    kvImageARGB16U = 1,
    kvImageARGB16Q12 = 2,
};

pub const vImageYpCbCrType = enum(c_int) {
    kvImage422CbYpCrYp8 = 0,
    kvImage422YpCbYpCr8 = 1,
    kvImage422CbYpCrYp8_AA8 = 2,
    kvImage420Yp8_Cb8_Cr8 = 3,
    kvImage420Yp8_CbCr8 = 4,
    kvImage444AYpCbCr8 = 5,
    kvImage444CrYpCb8 = 6,
    kvImage444CbYpCrA8 = 7,
    kvImage444CrYpCb10 = 8,
    kvImage422CrYpCbYpCbYpCbYpCrYpCrYp10 = 9,
    kvImage422CbYpCrYp16 = 13,
    kvImage444AYpCbCr16 = 14,
};

pub const vImage_YpCbCrToARGBMatrix = extern struct {
    Yp: f32,
    Cr_R: f32,
    Cr_G: f32,
    Cb_G: f32,
    Cb_B: f32,
};

/// `vImage_YpCbCrToARGB` — the conversion info built by
/// `vImageConvert_YpCbCrToARGB_GenerateConversion` and consumed by every
/// YpCbCr-to-ARGB entry point. Opaque; only BNNS-side code reads the fields.
///
/// The size and alignment here were MEASURED against Accelerate.h on
/// macOS 15.7.7 / arm64: 128 bytes, 16-byte aligned. An earlier version of this
/// declaration was `[16]i32` — 64 bytes, 4-byte aligned — which meant
/// `GenerateConversion` wrote 64 bytes past the end of a caller's object.
pub const vImage_YpCbCrToARGB = extern struct {
    _opaque: [128]u8 align(16) = @splat(0),
};

pub const vImage_ARGBToYpCbCrMatrix = extern struct {
    R_Yp: f32,
    G_Yp: f32,
    B_Yp: f32,
    R_Cb: f32,
    G_Cb: f32,
    B_Cb_R_Cr: f32,
    G_Cr: f32,
    B_Cr: f32,
};

/// `vImage_ARGBToYpCbCr` — the conversion info built by
/// `vImageConvert_ARGBToYpCbCr_GenerateConversion`. Opaque.
///
/// 128 bytes, 16-byte aligned, measured against Accelerate.h. See the note on
/// `vImage_YpCbCrToARGB` for the bug this replaced.
pub const vImage_ARGBToYpCbCr = extern struct {
    _opaque: [128]u8 align(16) = @splat(0),
};

/// `vImage_YpCbCrPixelRange` — the black point, white point and clamping limits
/// that pin down a YpCbCr encoding.
///
/// Every field is `int32_t` in the header, not `int16_t`: the struct is 32
/// bytes, measured against Accelerate.h. It was declared with `i16` fields
/// here until this was checked, which made it half the size the framework
/// writes and put every field after the first at the wrong offset.
pub const vImage_YpCbCrPixelRange = extern struct {
    Yp_bias: i32,
    CbCr_bias: i32,
    YpRangeMax: i32,
    CbCrRangeMax: i32,
    YpMax: i32,
    YpMin: i32,
    CbCrMax: i32,
    CbCrMin: i32,
};

test "YCbCr conversion-info layouts match Accelerate.h" {
    // Measured with a clang program that printf's sizeof/_Alignof against
    // <Accelerate/Accelerate.h> on macOS 15.7.7 / arm64. These are not derived
    // from the field list; they are what the framework actually writes.
    const std = @import("std");
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(vImage_YpCbCrPixelRange));
    try std.testing.expectEqual(@as(usize, 4), @alignOf(vImage_YpCbCrPixelRange));
    try std.testing.expectEqual(@as(usize, 28), @offsetOf(vImage_YpCbCrPixelRange, "CbCrMin"));

    try std.testing.expectEqual(@as(usize, 128), @sizeOf(vImage_YpCbCrToARGB));
    try std.testing.expectEqual(@as(usize, 16), @alignOf(vImage_YpCbCrToARGB));
    try std.testing.expectEqual(@as(usize, 128), @sizeOf(vImage_ARGBToYpCbCr));
    try std.testing.expectEqual(@as(usize, 16), @alignOf(vImage_ARGBToYpCbCr));

    // The matrix structs were already right; pin them so they stay that way.
    try std.testing.expectEqual(@as(usize, 20), @sizeOf(vImage_YpCbCrToARGBMatrix));
    try std.testing.expectEqual(@as(usize, 32), @sizeOf(vImage_ARGBToYpCbCrMatrix));
}

// ============================================================================
// MultidimensionalTable hints
// ============================================================================

pub const vImage_MDTableUsageHint = enum(u32) {
    kvImageMDTableHint_Float = 0,
    kvImageMDTableHint_16Q12 = 1,
};

// ============================================================================
// Flags
// ============================================================================

/// vImage option flags as a bitfield you can compose by field name.
///
/// The C type is a bare `uint32_t`, so any integer at all type-checks - a
/// typo'd or out-of-range value reaches vImage as an unrecognised bit rather
/// than a compile error. `Options` makes each documented flag a named `bool`
/// so the compiler rejects anything vImage does not define:
///
///     const flags = Options.of(.{ .edge_extend = true, .do_not_tile = true });
///
/// The bit positions match `vImage_Types.h`'s `kvImage*` constants exactly.
pub const Options = packed struct(u32) {
    leave_alpha_unchanged: bool = false, // kvImageLeaveAlphaUnchanged, 1 << 0
    copy_in_place: bool = false, // kvImageCopyInPlace,          1 << 1
    background_color_fill: bool = false, // kvImageBackgroundColorFill,  1 << 2
    edge_extend: bool = false, // kvImageEdgeExtend,           1 << 3
    do_not_tile: bool = false, // kvImageDoNotTile,            1 << 4
    high_quality_resampling: bool = false, // kvImageHighQualityResampling,1 << 5
    truncate_kernel: bool = false, // kvImageTruncateKernel,       1 << 6
    get_temp_buffer_size: bool = false, // kvImageGetTempBufferSize,    1 << 7
    print_diagnostics_to_console: bool = false, // kvImagePrintDiagnostics..., 1 << 8
    do_not_allocate: bool = false, // kvImageNoAllocate,           1 << 9
    hdr_content: bool = false, // kvImageHDRContent,           1 << 10
    do_not_clamp: bool = false, // kvImageDoNotClamp,           1 << 11
    use_fp16_accumulator: bool = false, // kvImageUseFP16Accumulator,   1 << 12
    _padding: u19 = 0,

    /// The raw `vImage_Flags` value to hand to a wrapper.
    pub fn bits(self: Options) vImage_Flags {
        return @bitCast(self);
    }

    /// Shorthand: `Options.of(.{ .edge_extend = true })` -> `vImage_Flags`.
    pub fn of(opts: Options) vImage_Flags {
        return opts.bits();
    }

    pub fn from(raw: vImage_Flags) Options {
        return @bitCast(raw);
    }
};

/// The raw `kvImage*` constants, kept for direct correspondence with
/// `vImage_Types.h` and for callers holding flags as plain integers. Prefer
/// `Options` in new code - it cannot express a bit vImage does not define.
pub const Flags = struct {
    pub const kvImageNoFlags: vImage_Flags = 0;
    pub const kvImageLeaveAlphaUnchanged: vImage_Flags = 1;
    pub const kvImageCopyInPlace: vImage_Flags = 2;
    pub const kvImageBackgroundColorFill: vImage_Flags = 4;
    pub const kvImageEdgeExtend: vImage_Flags = 8;
    pub const kvImageDoNotTile: vImage_Flags = 16;
    pub const kvImageHighQualityResampling: vImage_Flags = 32;
    pub const kvImageTruncateKernel: vImage_Flags = 64;
    pub const kvImageGetTempBufferSize: vImage_Flags = 128;
    pub const kvImagePrintDiagnosticsToConsole: vImage_Flags = 256;
    pub const kvImageNoAllocate: vImage_Flags = 512;
    pub const kvImageHDRContent: vImage_Flags = 1024;
    pub const kvImageDoNotClamp: vImage_Flags = 2048;
    pub const kvImageUseFP16Accumulator: vImage_Flags = 4096;
};

test "Options bit positions match the kvImage* constants exactly" {
    const std = @import("std");
    try std.testing.expectEqual(Flags.kvImageNoFlags, Options.of(.{}));
    try std.testing.expectEqual(Flags.kvImageLeaveAlphaUnchanged, Options.of(.{ .leave_alpha_unchanged = true }));
    try std.testing.expectEqual(Flags.kvImageCopyInPlace, Options.of(.{ .copy_in_place = true }));
    try std.testing.expectEqual(Flags.kvImageBackgroundColorFill, Options.of(.{ .background_color_fill = true }));
    try std.testing.expectEqual(Flags.kvImageEdgeExtend, Options.of(.{ .edge_extend = true }));
    try std.testing.expectEqual(Flags.kvImageDoNotTile, Options.of(.{ .do_not_tile = true }));
    try std.testing.expectEqual(Flags.kvImageHighQualityResampling, Options.of(.{ .high_quality_resampling = true }));
    try std.testing.expectEqual(Flags.kvImageTruncateKernel, Options.of(.{ .truncate_kernel = true }));
    try std.testing.expectEqual(Flags.kvImageGetTempBufferSize, Options.of(.{ .get_temp_buffer_size = true }));
    try std.testing.expectEqual(Flags.kvImagePrintDiagnosticsToConsole, Options.of(.{ .print_diagnostics_to_console = true }));
    try std.testing.expectEqual(Flags.kvImageNoAllocate, Options.of(.{ .do_not_allocate = true }));
    try std.testing.expectEqual(Flags.kvImageHDRContent, Options.of(.{ .hdr_content = true }));
    try std.testing.expectEqual(Flags.kvImageDoNotClamp, Options.of(.{ .do_not_clamp = true }));
    try std.testing.expectEqual(Flags.kvImageUseFP16Accumulator, Options.of(.{ .use_fp16_accumulator = true }));

    // Composition is a plain OR, and the round trip is lossless.
    const combo = Options{ .edge_extend = true, .do_not_tile = true };
    try std.testing.expectEqual(Flags.kvImageEdgeExtend | Flags.kvImageDoNotTile, combo.bits());
    try std.testing.expectEqual(combo, Options.from(combo.bits()));
}

/// Neighbourhood connectivity for flood fill: only 4 and 8 are valid
/// (Transform.h:1671-1690). The C parameter is a bare `int`.
pub const Connectivity = enum(c_int) {
    /// Orthogonal neighbours only (N/S/E/W).
    four = 4,
    /// Orthogonal plus diagonal neighbours.
    eight = 8,
};

// ============================================================================
// Error codes
// ============================================================================

pub const Error = struct {
    pub const kvImageNoError: vImage_Error = 0;
    pub const kvImageRoiLargerThanInputBuffer: vImage_Error = -21766;
    pub const kvImageInvalidKernelSize: vImage_Error = -21767;
    pub const kvImageInvalidEdgeStyle: vImage_Error = -21768;
    pub const kvImageInvalidOffset_X: vImage_Error = -21769;
    pub const kvImageInvalidOffset_Y: vImage_Error = -21770;
    pub const kvImageMemoryAllocationError: vImage_Error = -21771;
    pub const kvImageNullPointerArgument: vImage_Error = -21772;
    pub const kvImageInvalidParameter: vImage_Error = -21773;
    pub const kvImageBufferSizeMismatch: vImage_Error = -21774;
    pub const kvImageUnknownFlagsBit: vImage_Error = -21775;
    pub const kvImageInternalError: vImage_Error = -21776;
    pub const kvImageInvalidRowBytes: vImage_Error = -21777;
    pub const kvImageInvalidImageFormat: vImage_Error = -21778;
    pub const kvImageColorSyncIsAbsent: vImage_Error = -21779;
    pub const kvImageOutOfPlaceOperationRequired: vImage_Error = -21780;
    pub const kvImageInvalidImageObject: vImage_Error = -21781;
    pub const kvImageInvalidCVImageFormat: vImage_Error = -21782;
    pub const kvImageUnsupportedConversion: vImage_Error = -21783;
    pub const kvImageCoreVideoIsAbsent: vImage_Error = -21784;

    // -- vImageCVImageFormatError (vImage_CVUtilities.h) --
    //
    // A separate, non-contiguous block of codes, returned only by the
    // `vImageCVImageFormat_*` setters when the format already has a value for
    // that property that the new one contradicts.
    pub const kvImageCVImageFormat_ConversionMatrix: vImage_Error = -21600;
    pub const kvImageCVImageFormat_ChromaSiting: vImage_Error = -21601;
    pub const kvImageCVImageFormat_ColorSpace: vImage_Error = -21602;
    pub const kvImageCVImageFormat_VideoChannelDescription: vImage_Error = -21603;
    pub const kvImageCVImageFormat_AlphaIsOneHint: vImage_Error = -21604;
};

// ============================================================================
// Zig-native error handling
// ============================================================================

/// vImage's error codes as a Zig error set.
///
/// The C API reports failure through the `vImage_Error` (`ssize_t`) return
/// value, which is easy to drop on the floor: ignoring it is silent and legal.
/// Wrappers in this binding return `VImageError!usize` instead, so an
/// unhandled failure is a compile error.
pub const VImageError = error{
    RoiLargerThanInputBuffer,
    InvalidKernelSize,
    InvalidEdgeStyle,
    InvalidOffset_X,
    InvalidOffset_Y,
    MemoryAllocationError,
    NullPointerArgument,
    InvalidParameter,
    BufferSizeMismatch,
    UnknownFlagsBit,
    InternalError,
    InvalidRowBytes,
    InvalidImageFormat,
    ColorSyncIsAbsent,
    OutOfPlaceOperationRequired,
    InvalidImageObject,
    InvalidCVImageFormat,
    UnsupportedConversion,
    CoreVideoIsAbsent,
    /// The format's conversion matrix conflicts with the requested change.
    CVImageFormatConversionMatrix,
    /// The format's chroma siting conflicts with the requested change.
    CVImageFormatChromaSiting,
    /// The format's colour space conflicts with the requested change.
    CVImageFormatColorSpace,
    /// The format's channel description conflicts with the requested change.
    CVImageFormatVideoChannelDescription,
    /// The format's alpha-is-one hint conflicts with the requested change.
    CVImageFormatAlphaIsOneHint,
    /// A negative code vImage returned that is not in the documented set.
    Unknown,
};

/// Converts a raw `vImage_Error` into a Zig error union.
///
/// The success test is `>= 0`, NOT `== 0`. When a function is called with
/// `Flags.kvImageGetTempBufferSize`, vImage returns the required temp-buffer
/// size **through the same return slot** as a positive value - so an
/// `== 0`-based check would misreport a successful size query as a failure.
/// Only negative values are errors.
///
/// The returned `usize` is therefore 0 for an ordinary successful call, and
/// the required temp-buffer size in bytes for a `kvImageGetTempBufferSize`
/// query.
pub fn check(e: vImage_Error) VImageError!usize {
    if (e >= 0) return @intCast(e);
    return switch (e) {
        Error.kvImageRoiLargerThanInputBuffer => VImageError.RoiLargerThanInputBuffer,
        Error.kvImageInvalidKernelSize => VImageError.InvalidKernelSize,
        Error.kvImageInvalidEdgeStyle => VImageError.InvalidEdgeStyle,
        Error.kvImageInvalidOffset_X => VImageError.InvalidOffset_X,
        Error.kvImageInvalidOffset_Y => VImageError.InvalidOffset_Y,
        Error.kvImageMemoryAllocationError => VImageError.MemoryAllocationError,
        Error.kvImageNullPointerArgument => VImageError.NullPointerArgument,
        Error.kvImageInvalidParameter => VImageError.InvalidParameter,
        Error.kvImageBufferSizeMismatch => VImageError.BufferSizeMismatch,
        Error.kvImageUnknownFlagsBit => VImageError.UnknownFlagsBit,
        Error.kvImageInternalError => VImageError.InternalError,
        Error.kvImageInvalidRowBytes => VImageError.InvalidRowBytes,
        Error.kvImageInvalidImageFormat => VImageError.InvalidImageFormat,
        Error.kvImageColorSyncIsAbsent => VImageError.ColorSyncIsAbsent,
        Error.kvImageOutOfPlaceOperationRequired => VImageError.OutOfPlaceOperationRequired,
        Error.kvImageInvalidImageObject => VImageError.InvalidImageObject,
        Error.kvImageInvalidCVImageFormat => VImageError.InvalidCVImageFormat,
        Error.kvImageUnsupportedConversion => VImageError.UnsupportedConversion,
        Error.kvImageCoreVideoIsAbsent => VImageError.CoreVideoIsAbsent,
        Error.kvImageCVImageFormat_ConversionMatrix => VImageError.CVImageFormatConversionMatrix,
        Error.kvImageCVImageFormat_ChromaSiting => VImageError.CVImageFormatChromaSiting,
        Error.kvImageCVImageFormat_ColorSpace => VImageError.CVImageFormatColorSpace,
        Error.kvImageCVImageFormat_VideoChannelDescription => VImageError.CVImageFormatVideoChannelDescription,
        Error.kvImageCVImageFormat_AlphaIsOneHint => VImageError.CVImageFormatAlphaIsOneHint,
        else => VImageError.Unknown,
    };
}

test "check maps negative codes to errors and treats >= 0 as success" {
    const std = @import("std");
    try std.testing.expectEqual(@as(usize, 0), try check(0));
    // kvImageGetTempBufferSize makes vImage return a SIZE through the error
    // slot. An `== 0` success test would report this as a failure.
    try std.testing.expectEqual(@as(usize, 4096), try check(4096));
    try std.testing.expectError(VImageError.BufferSizeMismatch, check(-21774));
    try std.testing.expectError(VImageError.NullPointerArgument, check(-21772));
    try std.testing.expectError(VImageError.Unknown, check(-1));
    // The vImageCVImageFormatError block lives well away from the main run of
    // codes, so a range-based mapping would have missed it entirely.
    try std.testing.expectError(VImageError.CVImageFormatColorSpace, check(-21602));
    try std.testing.expectError(VImageError.CVImageFormatAlphaIsOneHint, check(-21604));
}

test "a real vImage failure surfaces as a Zig error, not a dropped return value" {
    const std = @import("std");
    const alpha = @import("alpha.zig");

    // A source buffer smaller than the destination ROI: vImage rejects this
    // with kvImageRoiLargerThanInputBuffer (-21766). Before wrappers returned
    // an error union, this code was silently legal - the caller could ignore
    // the return value entirely and go on to read a dest buffer vImage never
    // touched.
    var top = [_]u8{0} ** 4;
    var bottom = [_]u8{0} ** 16;
    var dest = [_]u8{0} ** 16;
    const b_top = vImage_Buffer{ .data = &top, .height = 1, .width = 1, .rowBytes = 4 };
    const b_bottom = vImage_Buffer{ .data = &bottom, .height = 2, .width = 2, .rowBytes = 8 };
    const b_dest = vImage_Buffer{ .data = &dest, .height = 2, .width = 2, .rowBytes = 8 };

    const result = alpha.alphaBlendARGB(u8, &b_top, &b_bottom, &b_dest, Flags.kvImageNoFlags);
    try std.testing.expectError(VImageError.RoiLargerThanInputBuffer, result);
}
