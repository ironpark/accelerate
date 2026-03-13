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

/// Resampling filter handle used by Geometry functions.
pub const ResamplingFilter = ?*opaque {};

/// Gamma transfer-function handle used by vImageGamma.
pub const GammaFunction = ?*opaque {};

/// Handle to a multidimensional interpolated lookup table.
pub const vImage_MultidimensionalTable = ?*opaque {};

/// Handle to a vImage pixel-format converter (CFType-bridged).
pub const vImageConverterRef = ?*opaque {};

/// Handle to a CoreVideo image format description.
pub const vImageCVImageFormatRef = ?*opaque {};
pub const vImageConstCVImageFormatRef = ?*const opaque {};

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

pub const vImage_YpCbCrToARGB = extern struct {
    _opaque: [16]i32,
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

pub const vImage_ARGBToYpCbCr = extern struct {
    _opaque: [16]i32,
};

pub const vImage_YpCbCrPixelRange = extern struct {
    Yp_bias: i16,
    CbCr_bias: i16,
    YpRangeMax: i16,
    CbCrRangeMax: i16,
    YpMax: i16,
    YpMin: i16,
    CbCrMax: i16,
    CbCrMin: i16,
};

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
};
