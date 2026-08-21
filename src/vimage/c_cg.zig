//! Extern declarations for the 45 vImage entry points that take or return a
//! CoreGraphics or CoreVideo object — everything in `vImage_Utilities.h` and
//! `vImage_CVUtilities.h`.
//!
//! Split out of `c.zig` because these only exist when the package is built
//! with `-Dcoregraphics=true`; `c.zig` must stay compilable without the
//! CoreGraphics and CoreVideo frameworks linked.
//!
//! ## Nullability
//!
//! vImage marks *required* parameters with `VIMAGE_NON_NULL(...)` and says
//! nothing about the rest, so a parameter absent from that list is optional.
//! That is the opposite of the `assume_nonnull` convention `bnns.h` uses, and
//! reading one with the other's habit produces wrong signatures in both
//! directions.
//!
//! One deliberate departure, at `vImageConverter_CreateWithColorSyncCodeFragment`
//! — see the note on that declaration.

const types = @import("types.zig");
const cgt = @import("cg_types.zig");
const cg = @import("../cg/root.zig");
const cv = @import("../cv/root.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImagePixelCount = types.vImagePixelCount;
const vImage_Flags = types.vImage_Flags;
const vImage_Error = types.vImage_Error;
const vImageConverter = types.vImageConverter;
const vImageCVImageFormat = types.vImageCVImageFormat;
const vImage_ARGBToYpCbCrMatrix = types.vImage_ARGBToYpCbCrMatrix;

const CGFloat = cg.CGFloat;
const CGSize = cg.CGSize;
const CGImage = cg.CGImage;
const CGColorSpace = cg.CGColorSpace;
const CGColorConversionInfo = cg.CGColorConversionInfo;
const CFStringRef = cg.CFStringRef;
const CVPixelBuffer = cv.CVPixelBuffer;

const CGImageFormat = cgt.CGImageFormat;
const BufferTypeCode = cgt.BufferTypeCode;
const ChannelDescription = cgt.ChannelDescription;
const MatrixType = cgt.MatrixType;
const TransferFunction = cgt.TransferFunction;
const RGBPrimaries = cgt.RGBPrimaries;
const WhitePoint = cgt.WhitePoint;

// ============================================================================
// vImage_Utilities.h — buffers and formats
// ============================================================================

pub extern fn vImageBuffer_Init(buf: *vImage_Buffer, height: vImagePixelCount, width: vImagePixelCount, pixelBits: u32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageBuffer_GetSize(buf: *const vImage_Buffer) CGSize;
pub extern fn vImageCGImageFormat_GetComponentCount(format: *const CGImageFormat) u32;
/// Returns a `Boolean`, which on Apple platforms is `signed char` rather than
/// `_Bool` — so `u8`, compared against zero, not `bool`.
pub extern fn vImageCGImageFormat_IsEqual(f1: ?*const CGImageFormat, f2: ?*const CGImageFormat) u8;
pub extern fn vImageBuffer_InitWithCGImage(buf: *vImage_Buffer, format: *CGImageFormat, backgroundColor: ?[*]const CGFloat, image: *CGImage, flags: vImage_Flags) vImage_Error;
pub extern fn vImageCreateCGImageFromBuffer(
    buf: *const vImage_Buffer,
    format: *const CGImageFormat,
    callback: ?*const fn (userData: ?*anyopaque, buf_data: ?*anyopaque) callconv(.c) void,
    userData: ?*anyopaque,
    flags: vImage_Flags,
    err: ?*vImage_Error,
) ?*CGImage;

// ============================================================================
// vImage_Utilities.h — vImageConverterRef
// ============================================================================

pub extern fn vImageConverter_Retain(converter: ?*vImageConverter) void;
pub extern fn vImageConverter_Release(converter: ?*vImageConverter) void;
pub extern fn vImageConverter_CreateWithCGImageFormat(
    srcFormat: *const CGImageFormat,
    destFormat: *const CGImageFormat,
    backgroundColor: ?[*]const CGFloat,
    flags: vImage_Flags,
    err: ?*vImage_Error,
) ?*vImageConverter;
/// The header's `VIMAGE_NON_NULL(1,2)` counts `codeFragment` as parameter 1
/// and `srcFormat` as 2, which would leave `destFormat` optional. The
/// function's own documentation contradicts that — it lists
/// `kvImageNullPointerArgument` for "srcFormat and/or destFormat is NULL" —
/// so both formats are declared required here and the attribute is treated as
/// an oversight.
pub extern fn vImageConverter_CreateWithColorSyncCodeFragment(
    codeFragment: ?*const anyopaque,
    srcFormat: *const CGImageFormat,
    destFormat: *const CGImageFormat,
    backgroundColor: ?[*]const CGFloat,
    flags: vImage_Flags,
    err: ?*vImage_Error,
) ?*vImageConverter;
pub extern fn vImageConverter_CreateWithCGColorConversionInfo(
    colorConversionInfoRef: *CGColorConversionInfo,
    sFormat: *const CGImageFormat,
    dFormat: *const CGImageFormat,
    bg: ?[*]const CGFloat,
    flags: vImage_Flags,
    err: ?*vImage_Error,
) ?*vImageConverter;
/// `srcs` and `dests` must be both null or both non-null.
pub extern fn vImageConverter_MustOperateOutOfPlace(converter: *vImageConverter, srcs: ?[*]const vImage_Buffer, dests: ?[*]const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConverter_GetNumberOfSourceBuffers(converter: *vImageConverter) c_ulong;
pub extern fn vImageConverter_GetNumberOfDestinationBuffers(converter: *vImageConverter) c_ulong;
/// Returns a borrowed, `end_of_list`-terminated array owned by the converter.
pub extern fn vImageConverter_GetSourceBufferOrder(converter: *vImageConverter) ?[*]const BufferTypeCode;
pub extern fn vImageConverter_GetDestinationBufferOrder(converter: *vImageConverter) ?[*]const BufferTypeCode;
pub extern fn vImageConvert_AnyToAny(converter: *vImageConverter, srcs: [*]const vImage_Buffer, dests: [*]const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;

// ============================================================================
// vImage_CVUtilities.h — CVPixelBuffer bridges
// ============================================================================

pub extern fn vImageBuffer_InitWithCVPixelBuffer(
    buffer: *vImage_Buffer,
    desiredFormat: *CGImageFormat,
    cvPixelBuffer: *CVPixelBuffer,
    cvImageFormat: ?*vImageCVImageFormat,
    backgroundColor: ?[*]const CGFloat,
    flags: vImage_Flags,
) vImage_Error;
pub extern fn vImageBuffer_CopyToCVPixelBuffer(
    buffer: *const vImage_Buffer,
    bufferFormat: *const CGImageFormat,
    cvPixelBuffer: *CVPixelBuffer,
    cvImageFormat: ?*vImageCVImageFormat,
    backgroundColor: ?[*]const CGFloat,
    flags: vImage_Flags,
) vImage_Error;
pub extern fn vImageBuffer_InitForCopyToCVPixelBuffer(buffers: [*]vImage_Buffer, converter: *vImageConverter, pixelBuffer: *CVPixelBuffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageBuffer_InitForCopyFromCVPixelBuffer(buffers: [*]vImage_Buffer, converter: *vImageConverter, pixelBuffer: *CVPixelBuffer, flags: vImage_Flags) vImage_Error;

// ============================================================================
// vImage_CVUtilities.h — vImageCVImageFormatRef
// ============================================================================

pub extern fn vImageCVImageFormat_CreateWithCVPixelBuffer(buffer: ?*CVPixelBuffer) ?*vImageCVImageFormat;
pub extern fn vImageCVImageFormat_Create(
    imageFormatType: u32,
    matrix: ?*const vImage_ARGBToYpCbCrMatrix,
    cvImageBufferChromaLocation: CFStringRef,
    baseColorspace: ?*CGColorSpace,
    alphaIsOneHint: c_int,
) ?*vImageCVImageFormat;
pub extern fn vImageCVImageFormat_Copy(format: *const vImageCVImageFormat) ?*vImageCVImageFormat;
pub extern fn vImageCVImageFormat_Retain(fmt: ?*vImageCVImageFormat) void;
pub extern fn vImageCVImageFormat_Release(fmt: ?*vImageCVImageFormat) void;
pub extern fn vImageCVImageFormat_GetFormatCode(format: *const vImageCVImageFormat) u32;
pub extern fn vImageCVImageFormat_GetChannelCount(format: *const vImageCVImageFormat) u32;
pub extern fn vImageCVImageFormat_GetChannelNames(format: *const vImageCVImageFormat) ?[*]const BufferTypeCode;
pub extern fn vImageCVImageFormat_GetColorSpace(format: *const vImageCVImageFormat) ?*CGColorSpace;
pub extern fn vImageCVImageFormat_SetColorSpace(format: *vImageCVImageFormat, colorspace: ?*CGColorSpace) vImage_Error;
pub extern fn vImageCVImageFormat_GetChromaSiting(format: *const vImageCVImageFormat) CFStringRef;
pub extern fn vImageCVImageFormat_SetChromaSiting(format: *vImageCVImageFormat, siting: CFStringRef) vImage_Error;
pub extern fn vImageCVImageFormat_GetConversionMatrix(format: *const vImageCVImageFormat, outType: ?*MatrixType) ?*const anyopaque;
pub extern fn vImageCVImageFormat_CopyConversionMatrix(format: *vImageCVImageFormat, matrix: *const anyopaque, inType: MatrixType) vImage_Error;
pub extern fn vImageCVImageFormat_GetAlphaHint(format: *const vImageCVImageFormat) c_int;
pub extern fn vImageCVImageFormat_SetAlphaHint(format: *vImageCVImageFormat, alphaIsOne: c_int) vImage_Error;
pub extern fn vImageCVImageFormat_GetChannelDescription(format: *const vImageCVImageFormat, @"type": BufferTypeCode) ?*const ChannelDescription;
pub extern fn vImageCVImageFormat_CopyChannelDescription(format: *vImageCVImageFormat, desc: *const ChannelDescription, @"type": BufferTypeCode) vImage_Error;
pub extern fn vImageCVImageFormat_GetUserData(format: *const vImageCVImageFormat) ?*anyopaque;
pub extern fn vImageCVImageFormat_SetUserData(
    format: *vImageCVImageFormat,
    userData: ?*anyopaque,
    userDataReleaseCallback: ?*const fn (callback_fmt: ?*vImageCVImageFormat, callback_userData: ?*anyopaque) callconv(.c) void,
) vImage_Error;

// ============================================================================
// vImage_CVUtilities.h — colour space construction and CG<->CV converters
// ============================================================================

pub extern fn vImageCreateRGBColorSpaceWithPrimariesAndTransferFunction(
    primaries: *const RGBPrimaries,
    tf: *const TransferFunction,
    intent: cg.RenderingIntent,
    flags: vImage_Flags,
    err: ?*vImage_Error,
) ?*CGColorSpace;
pub extern fn vImageCreateMonochromeColorSpaceWithWhitePointAndTransferFunction(
    whitePoint: *const WhitePoint,
    tf: *const TransferFunction,
    intent: cg.RenderingIntent,
    flags: vImage_Flags,
    err: ?*vImage_Error,
) ?*CGColorSpace;
pub extern fn vImageConverter_CreateForCGToCVImageFormat(
    srcFormat: *const CGImageFormat,
    destFormat: *vImageCVImageFormat,
    backgroundColor: ?[*]const CGFloat,
    flags: vImage_Flags,
    err: ?*vImage_Error,
) ?*vImageConverter;
pub extern fn vImageConverter_CreateForCVToCGImageFormat(
    srcFormat: *vImageCVImageFormat,
    destFormat: *const CGImageFormat,
    backgroundColor: ?[*]const CGFloat,
    flags: vImage_Flags,
    err: ?*vImage_Error,
) ?*vImageConverter;

// ============================================================================
// Link test
// ============================================================================

test "every declared symbol resolves at link time" {
    const std = @import("std");
    // Taking the address of each extern forces the linker to resolve it, so a
    // misspelled name fails the build rather than at first call. It does NOT
    // check the signature — a wrong parameter list still links and then
    // corrupts the stack, which is why the layouts in `cg_types.zig` are
    // measured against clang and the wrappers are value-tested.
    var sum: usize = 0;
    inline for (@typeInfo(@This()).@"struct".decls) |decl| {
        const field = @field(@This(), decl.name);
        if (@typeInfo(@TypeOf(field)) == .@"fn") {
            sum +%= @intFromPtr(&field);
        }
    }
    try std.testing.expect(sum != 0);
}
