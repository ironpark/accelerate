// Consolidated C extern declarations for all vImage modules.
//
// This file contains all extern function declarations used by the vImage Zig bindings.
// Each module imports `const c = @import("c.zig");` to access these.

const types = @import("types.zig");

// -- Re-exported types from types.zig --

pub const vImage_Buffer = types.vImage_Buffer;
pub const vImagePixelCount = types.vImagePixelCount;
pub const vImage_Flags = types.vImage_Flags;
pub const vImage_Error = types.vImage_Error;
pub const Pixel_8 = types.Pixel_8;
pub const Pixel_F = types.Pixel_F;
pub const Pixel_8888 = types.Pixel_8888;
pub const Pixel_FFFF = types.Pixel_FFFF;
pub const Pixel_16U = types.Pixel_16U;
pub const Pixel_16S = types.Pixel_16S;
pub const Pixel_16Q12 = types.Pixel_16Q12;
pub const Pixel_ARGB_16U = types.Pixel_ARGB_16U;
pub const Pixel_ARGB_16S = types.Pixel_ARGB_16S;
pub const Pixel_16F = types.Pixel_16F;
pub const Pixel_ARGB_16F = types.Pixel_ARGB_16F;
pub const ResamplingFilter = types.ResamplingFilter;
pub const GammaFunction = types.GammaFunction;
pub const vImage_MultidimensionalTable = types.vImage_MultidimensionalTable;
pub const vImageConverterRef = types.vImageConverterRef;
pub const vImage_AffineTransform = types.vImage_AffineTransform;
pub const vImage_AffineTransform_Double = types.vImage_AffineTransform_Double;
pub const vImage_CGAffineTransform = types.vImage_CGAffineTransform;
pub const Pixel_88 = types.Pixel_88;
pub const Pixel_16U16U = types.Pixel_16U16U;
pub const Pixel_16S16S = types.Pixel_16S16S;
pub const Pixel_16F16F = types.Pixel_16F16F;
pub const Pixel_32U = types.Pixel_32U;
pub const vImage_PerspectiveTransform = types.vImage_PerspectiveTransform;
pub const WarpInterpolation = types.WarpInterpolation;
pub const KernelFunc = types.KernelFunc;
pub const vImageARGBType = types.vImageARGBType;
pub const vImageYpCbCrType = types.vImageYpCbCrType;
pub const vImage_YpCbCrToARGBMatrix = types.vImage_YpCbCrToARGBMatrix;
pub const vImage_YpCbCrToARGB = types.vImage_YpCbCrToARGB;
pub const vImage_ARGBToYpCbCrMatrix = types.vImage_ARGBToYpCbCrMatrix;
pub const vImage_ARGBToYpCbCr = types.vImage_ARGBToYpCbCr;
pub const vImage_YpCbCrPixelRange = types.vImage_YpCbCrPixelRange;

// ============================================================================
// Alpha
// ============================================================================

// -- Alpha Blend (non-premultiplied) --
pub extern fn vImageAlphaBlend_Planar8(srcTop: *const vImage_Buffer, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, srcBottomAlpha: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAlphaBlend_PlanarF(srcTop: *const vImage_Buffer, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, srcBottomAlpha: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAlphaBlend_ARGB8888(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAlphaBlend_ARGBFFFF(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- Alpha Blend (premultiplied) --
pub extern fn vImagePremultipliedAlphaBlend_Planar8(srcTop: *const vImage_Buffer, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultipliedAlphaBlend_PlanarF(srcTop: *const vImage_Buffer, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultipliedAlphaBlend_ARGB8888(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultipliedAlphaBlend_BGRA8888(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultipliedAlphaBlend_ARGBFFFF(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultipliedAlphaBlend_BGRAFFFF(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- Alpha Blend (premultiplied, with permute) --
pub extern fn vImagePremultipliedAlphaBlendWithPermute_ARGB8888(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, makeDestAlphaOpaque: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultipliedAlphaBlendWithPermute_RGBA8888(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, makeDestAlphaOpaque: bool, flags: vImage_Flags) vImage_Error;

// -- Alpha Blend (premultiplied, SVG blend modes) --
pub extern fn vImagePremultipliedAlphaBlendMultiply_RGBA8888(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultipliedAlphaBlendScreen_RGBA8888(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultipliedAlphaBlendDarken_RGBA8888(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultipliedAlphaBlendLighten_RGBA8888(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- Premultiply Data --
pub extern fn vImagePremultiplyData_Planar8(src: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultiplyData_PlanarF(src: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultiplyData_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultiplyData_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultiplyData_RGBA8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultiplyData_RGBAFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultiplyData_RGBA16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultiplyData_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultiplyData_RGBA16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultiplyData_ARGB16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultiplyData_RGBA16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- Unpremultiply Data --
pub extern fn vImageUnpremultiplyData_Planar8(src: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageUnpremultiplyData_PlanarF(src: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageUnpremultiplyData_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageUnpremultiplyData_RGBA8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageUnpremultiplyData_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageUnpremultiplyData_RGBAFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageUnpremultiplyData_RGBA16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageUnpremultiplyData_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageUnpremultiplyData_RGBA16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageUnpremultiplyData_ARGB16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageUnpremultiplyData_RGBA16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- Premultiplied Const Alpha Blend --
pub extern fn vImagePremultipliedConstAlphaBlend_Planar8(srcTop: *const vImage_Buffer, constAlpha: u8, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultipliedConstAlphaBlend_PlanarF(srcTop: *const vImage_Buffer, constAlpha: f32, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultipliedConstAlphaBlend_ARGB8888(srcTop: *const vImage_Buffer, constAlpha: u8, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePremultipliedConstAlphaBlend_ARGBFFFF(srcTop: *const vImage_Buffer, constAlpha: f32, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- Alpha Blend (non-premultiplied to premultiplied) --
pub extern fn vImageAlphaBlend_NonpremultipliedToPremultiplied_Planar8(srcTop: *const vImage_Buffer, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAlphaBlend_NonpremultipliedToPremultiplied_PlanarF(srcTop: *const vImage_Buffer, srcTopAlpha: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAlphaBlend_NonpremultipliedToPremultiplied_ARGB8888(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAlphaBlend_NonpremultipliedToPremultiplied_ARGBFFFF(srcTop: *const vImage_Buffer, srcBottom: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- Clip to Alpha --
pub extern fn vImageClipToAlpha_Planar8(src: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageClipToAlpha_PlanarF(src: *const vImage_Buffer, alpha: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageClipToAlpha_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageClipToAlpha_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageClipToAlpha_RGBA8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageClipToAlpha_RGBAFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// ============================================================================
// Convolution
// ============================================================================

// -- General Convolution --

pub extern fn vImageConvolve_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const i16, kernel_height: u32, kernel_width: u32, divisor: i32, backgroundColor: u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvolve_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernel_height: u32, kernel_width: u32, backgroundColor: f32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvolve_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const i16, kernel_height: u32, kernel_width: u32, divisor: i32, backgroundColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvolve_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernel_height: u32, kernel_width: u32, backgroundColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvolve_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernel_height: u32, kernel_width: u32, backgroundColor: Pixel_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvolve_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernel_height: u32, kernel_width: u32, backgroundColor: *const Pixel_ARGB_16F, flags: vImage_Flags) vImage_Error;

// -- Convolution with Bias --

pub extern fn vImageConvolveWithBias_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const i16, kernel_height: u32, kernel_width: u32, divisor: i32, bias: i32, backgroundColor: u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvolveWithBias_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernel_height: u32, kernel_width: u32, bias: f32, backgroundColor: f32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvolveWithBias_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const i16, kernel_height: u32, kernel_width: u32, divisor: i32, bias: i32, backgroundColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvolveWithBias_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernel_height: u32, kernel_width: u32, bias: f32, backgroundColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvolveWithBias_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernel_height: u32, kernel_width: u32, bias: f32, backgroundColor: Pixel_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvolveWithBias_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernel_height: u32, kernel_width: u32, bias: f32, backgroundColor: *const Pixel_ARGB_16F, flags: vImage_Flags) vImage_Error;

// ARGB8888 pixels convolved against a *float* kernel, with a float bias. The
// integer-kernel `vImageConvolveWithBias_ARGB8888` above divides by an integer
// divisor; this one has no divisor because the kernel already carries the
// scale. It is the only member of the ARGB8888 family that does.
pub extern fn vImageConvolveFloatKernel_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernelHeight: u32, kernelWidth: u32, bias: f32, backgroundColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;

// -- Separable Convolution --
//
// Two 1D kernels applied along rows and columns instead of one 2D kernel:
// O(kx + ky) work per pixel rather than O(kx * ky). Note that Planar8's
// `backgroundColor` is `Pixel_16U`, not `Pixel_8` - that is the header's
// signature, not a transcription slip.
pub extern fn vImageSepConvolve_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernelX: [*]const f32, kernelX_width: u32, kernelY: [*]const f32, kernelY_width: u32, bias: f32, backgroundColor: Pixel_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageSepConvolve_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernelX: [*]const f32, kernelX_width: u32, kernelY: [*]const f32, kernelY_width: u32, bias: f32, backgroundColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageSepConvolve_Planar16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernelX: [*]const f32, kernelX_width: u32, kernelY: [*]const f32, kernelY_width: u32, bias: f32, backgroundColor: Pixel_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageSepConvolve_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernelX: [*]const f32, kernelX_width: u32, kernelY: [*]const f32, kernelY_width: u32, bias: f32, backgroundColor: Pixel_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageSepConvolve_Planar8to16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernelX: [*]const f32, kernelX_width: u32, kernelY: [*]const f32, kernelY_width: u32, scale: f32, bias: f32, backgroundColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageSepConvolve_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernelX: [*]const f32, kernelX_width: u32, kernelY: [*]const f32, kernelY_width: u32, bias: f32, backgroundColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;

// -- Multi-Kernel Convolution --

pub extern fn vImageConvolveMultiKernel_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernels: *const [4][*]const i16, kernel_height: u32, kernel_width: u32, divisors: *const [4]i32, biases: *const [4]i32, backgroundColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvolveMultiKernel_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernels: *const [4][*]const f32, kernel_height: u32, kernel_width: u32, biases: *const [4]f32, backgroundColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;

// -- Richardson-Lucy Deconvolution --

pub extern fn vImageRichardsonLucyDeConvolve_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const i16, kernel2: [*]const i16, kernel_height: u32, kernel_width: u32, kernel_height2: u32, kernel_width2: u32, divisor: i32, divisor2: i32, backgroundColor: u8, iterationCount: u32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRichardsonLucyDeConvolve_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernel2: [*]const f32, kernel_height: u32, kernel_width: u32, kernel_height2: u32, kernel_width2: u32, backgroundColor: f32, iterationCount: u32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRichardsonLucyDeConvolve_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const i16, kernel2: [*]const i16, kernel_height: u32, kernel_width: u32, kernel_height2: u32, kernel_width2: u32, divisor: i32, divisor2: i32, backgroundColor: *const Pixel_8888, iterationCount: u32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRichardsonLucyDeConvolve_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernel2: [*]const f32, kernel_height: u32, kernel_width: u32, kernel_height2: u32, kernel_width2: u32, backgroundColor: *const Pixel_FFFF, iterationCount: u32, flags: vImage_Flags) vImage_Error;

// -- Box Convolution --

pub extern fn vImageBoxConvolve_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel_height: u32, kernel_width: u32, backgroundColor: u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageBoxConvolve_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel_height: u32, kernel_width: u32, backgroundColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;

// -- Tent Convolution --

pub extern fn vImageTentConvolve_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel_height: u32, kernel_width: u32, backgroundColor: u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageTentConvolve_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel_height: u32, kernel_width: u32, backgroundColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;

// ============================================================================
// Conversion
// ============================================================================

// -- Clip --

pub extern fn vImageClip_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, maxFloat: Pixel_F, minFloat: Pixel_F, flags: vImage_Flags) vImage_Error;

// -- Planar8 <-> PlanarF --

pub extern fn vImageConvert_Planar8toPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, maxFloat: Pixel_F, minFloat: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_PlanarFtoPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, maxFloat: Pixel_F, minFloat: Pixel_F, flags: vImage_Flags) vImage_Error;

// -- Planar16F <-> PlanarF / Planar8 --

pub extern fn vImageConvert_Planar16FtoPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_PlanarFtoPlanar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar8toPlanar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar16FtoPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- 16S/16U <-> Float --

pub extern fn vImageConvert_16SToF(src: *const vImage_Buffer, dest: *const vImage_Buffer, offset: f32, scale: f32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_16UToF(src: *const vImage_Buffer, dest: *const vImage_Buffer, offset: f32, scale: f32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_FTo16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, offset: f32, scale: f32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_FTo16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, offset: f32, scale: f32, flags: vImage_Flags) vImage_Error;

// -- Planar8 <-> 16U --

pub extern fn vImageConvert_16UToPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar8To16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- Planar -> ARGB (channel combine, same format) --

pub extern fn vImageConvert_Planar8toARGB8888(srcA: *const vImage_Buffer, srcR: *const vImage_Buffer, srcG: *const vImage_Buffer, srcB: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_PlanarFtoARGBFFFF(srcA: *const vImage_Buffer, srcR: *const vImage_Buffer, srcG: *const vImage_Buffer, srcB: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- ARGB -> Planar (channel split, same format) --

pub extern fn vImageConvert_ARGB8888toPlanar8(srcARGB: *const vImage_Buffer, destA: *const vImage_Buffer, destR: *const vImage_Buffer, destG: *const vImage_Buffer, destB: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGBFFFFtoPlanarF(srcARGB: *const vImage_Buffer, destA: *const vImage_Buffer, destR: *const vImage_Buffer, destG: *const vImage_Buffer, destB: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- Cross-format planar combine/extract (Planar8 <-> ARGBFFFF, PlanarF <-> ARGB8888) --

pub extern fn vImageConvert_Planar8ToARGBFFFF(alpha: *const vImage_Buffer, red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, dest: *const vImage_Buffer, maxFloat: *const Pixel_FFFF, minFloat: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888toPlanarF(src: *const vImage_Buffer, alpha: *const vImage_Buffer, red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, maxFloat: *const Pixel_FFFF, minFloat: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGBFFFFtoPlanar8(src: *const vImage_Buffer, alpha: *const vImage_Buffer, red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, maxFloat: *const Pixel_FFFF, minFloat: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_PlanarFToARGB8888(alpha: *const vImage_Buffer, red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, dest: *const vImage_Buffer, maxFloat: *const Pixel_FFFF, minFloat: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;

// -- RGB <-> Planar (3-channel interleave/deinterleave) --

pub extern fn vImageConvert_Planar8toRGB888(planarRed: *const vImage_Buffer, planarGreen: *const vImage_Buffer, planarBlue: *const vImage_Buffer, rgbDest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_PlanarFtoRGBFFF(planarRed: *const vImage_Buffer, planarGreen: *const vImage_Buffer, planarBlue: *const vImage_Buffer, rgbDest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGB888toPlanar8(rgbSrc: *const vImage_Buffer, redDest: *const vImage_Buffer, greenDest: *const vImage_Buffer, blueDest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGBFFFtoPlanarF(rgbSrc: *const vImage_Buffer, redDest: *const vImage_Buffer, greenDest: *const vImage_Buffer, blueDest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- RGB -> ARGB/RGBA/BGRA 8888 (add alpha) --

pub extern fn vImageConvert_RGB888toARGB8888(rgbSrc: *const vImage_Buffer, aSrc: ?*const vImage_Buffer, alpha: Pixel_8, argbDest: *const vImage_Buffer, premultiply: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGB888toRGBA8888(rgbSrc: *const vImage_Buffer, aSrc: ?*const vImage_Buffer, alpha: Pixel_8, rgbaDest: *const vImage_Buffer, premultiply: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGB888toBGRA8888(rgbSrc: *const vImage_Buffer, aSrc: ?*const vImage_Buffer, alpha: Pixel_8, bgraDest: *const vImage_Buffer, premultiply: bool, flags: vImage_Flags) vImage_Error;

// -- ARGB/RGBA/BGRA 8888 -> RGB888 (strip alpha) --

pub extern fn vImageConvert_ARGB8888toRGB888(argbSrc: *const vImage_Buffer, rgbDest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGBA8888toRGB888(rgbaSrc: *const vImage_Buffer, rgbDest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_BGRA8888toRGB888(bgraSrc: *const vImage_Buffer, rgbDest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- ARGBFFFF / RGBAFFFF / BGRAFFFF -> RGBFFF (strip alpha float) --

pub extern fn vImageConvert_ARGBFFFFtoRGBFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGBAFFFFtoRGBFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_BGRAFFFFtoRGBFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- RGBFFF -> ARGBFFFF / RGBAFFFF / BGRAFFFF (add alpha float) --

pub extern fn vImageConvert_RGBFFFtoARGBFFFF(rgbSrc: *const vImage_Buffer, aSrc: ?*const vImage_Buffer, alpha: Pixel_F, argbDest: *const vImage_Buffer, premultiply: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGBFFFtoRGBAFFFF(rgbSrc: *const vImage_Buffer, aSrc: ?*const vImage_Buffer, alpha: Pixel_F, rgbaDest: *const vImage_Buffer, premultiply: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGBFFFtoBGRAFFFF(rgbSrc: *const vImage_Buffer, aSrc: ?*const vImage_Buffer, alpha: Pixel_F, bgraDest: *const vImage_Buffer, premultiply: bool, flags: vImage_Flags) vImage_Error;

// -- Flatten (alpha composite against background) --

pub extern fn vImageFlatten_ARGB8888ToRGB888(src: *const vImage_Buffer, dest: *const vImage_Buffer, backgroundColor: *const Pixel_8888, isImagePremultiplied: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageFlatten_ARGBFFFFToRGBFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, backgroundColor: *const Pixel_FFFF, isImagePremultiplied: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageFlatten_RGBA8888ToRGB888(src: *const vImage_Buffer, dest: *const vImage_Buffer, backgroundColor: *const Pixel_8888, isImagePremultiplied: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageFlatten_RGBAFFFFToRGBFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, backgroundColor: *const Pixel_FFFF, isImagePremultiplied: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageFlatten_BGRA8888ToRGB888(src: *const vImage_Buffer, dest: *const vImage_Buffer, backgroundColor: *const Pixel_8888, isImagePremultiplied: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageFlatten_BGRAFFFFToRGBFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, backgroundColor: *const Pixel_FFFF, isImagePremultiplied: bool, flags: vImage_Flags) vImage_Error;

// -- Permute channels --

pub extern fn vImagePermuteChannels_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePermuteChannels_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePermuteChannels_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePermuteChannels_RGB888(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [3]u8, flags: vImage_Flags) vImage_Error;

// -- Extract single channel --

pub extern fn vImageExtractChannel_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, channelIndex: c_long, flags: vImage_Flags) vImage_Error;
pub extern fn vImageExtractChannel_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, channelIndex: c_long, flags: vImage_Flags) vImage_Error;
pub extern fn vImageExtractChannel_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, channelIndex: c_long, flags: vImage_Flags) vImage_Error;

// -- Overwrite channels (planar -> interleaved) --

pub extern fn vImageOverwriteChannels_ARGB8888(newSrc: *const vImage_Buffer, origSrc: *const vImage_Buffer, dest: *const vImage_Buffer, copyMask: u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageOverwriteChannels_ARGBFFFF(newSrc: *const vImage_Buffer, origSrc: *const vImage_Buffer, dest: *const vImage_Buffer, copyMask: u8, flags: vImage_Flags) vImage_Error;

// -- Overwrite channels with scalar --

pub extern fn vImageOverwriteChannelsWithScalar_Planar8(scalar: Pixel_8, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageOverwriteChannelsWithScalar_PlanarF(scalar: Pixel_F, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageOverwriteChannelsWithScalar_ARGB8888(scalar: Pixel_8, src: *const vImage_Buffer, dest: *const vImage_Buffer, copyMask: u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageOverwriteChannelsWithScalar_ARGBFFFF(scalar: Pixel_F, src: *const vImage_Buffer, dest: *const vImage_Buffer, copyMask: u8, flags: vImage_Flags) vImage_Error;

// -- Overwrite channels with pixel --

pub extern fn vImageOverwriteChannelsWithPixel_ARGB8888(the_pixel: *const Pixel_8888, src: *const vImage_Buffer, dest: *const vImage_Buffer, copyMask: u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageOverwriteChannelsWithPixel_ARGBFFFF(the_pixel: *const Pixel_FFFF, src: *const vImage_Buffer, dest: *const vImage_Buffer, copyMask: u8, flags: vImage_Flags) vImage_Error;

// -- Select channels (interleaved -> interleaved) --

pub extern fn vImageSelectChannels_ARGB8888(newSrc: *const vImage_Buffer, origSrc: *const vImage_Buffer, dest: *const vImage_Buffer, copyMask: u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageSelectChannels_ARGBFFFF(newSrc: *const vImage_Buffer, origSrc: *const vImage_Buffer, dest: *const vImage_Buffer, copyMask: u8, flags: vImage_Flags) vImage_Error;

// -- Buffer fill --

pub extern fn vImageBufferFill_ARGB8888(dest: *const vImage_Buffer, color: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageBufferFill_ARGBFFFF(dest: *const vImage_Buffer, color: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;

// -- Table lookup --

pub extern fn vImageTableLookUp_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, alphaTable: ?[*]const Pixel_8, redTable: ?[*]const Pixel_8, greenTable: ?[*]const Pixel_8, blueTable: ?[*]const Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageTableLookUp_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: [*]const Pixel_8, flags: vImage_Flags) vImage_Error;

// -- Copy buffer --

pub extern fn vImageCopyBuffer(src: *const vImage_Buffer, dest: *const vImage_Buffer, pixelSize: usize, flags: vImage_Flags) vImage_Error;

// -- ARGB1555 <-> ARGB8888 / Planar8 --

pub extern fn vImageConvert_ARGB1555toARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB1555toPlanar8(src: *const vImage_Buffer, destA: *const vImage_Buffer, destR: *const vImage_Buffer, destG: *const vImage_Buffer, destB: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar8toARGB1555(srcA: *const vImage_Buffer, srcR: *const vImage_Buffer, srcG: *const vImage_Buffer, srcB: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888toARGB1555(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888toARGB1555_dithered(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, dither: c_int, flags: vImage_Flags) vImage_Error;

// -- RGBA5551 <-> RGBA8888 --

pub extern fn vImageConvert_RGBA5551toRGBA8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGBA8888toRGBA5551(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGBA8888toRGBA5551_dithered(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, dither: c_int, flags: vImage_Flags) vImage_Error;

// -- RGB565 <-> 8888 --

pub extern fn vImageConvert_RGB565toARGB8888(alpha: Pixel_8, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGB565toRGBA8888(alpha: Pixel_8, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGB565toBGRA8888(alpha: Pixel_8, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGB565toRGB888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888toRGB565(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGBA8888toRGB565(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_BGRA8888toRGB565(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- RGB565 dithered encoders --

pub extern fn vImageConvert_RGB888toRGB565_dithered(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, dither: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888toRGB565_dithered(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, dither: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGBA8888toRGB565_dithered(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, dither: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_BGRA8888toRGB565_dithered(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, dither: c_int, flags: vImage_Flags) vImage_Error;

// -- RGB565 <-> Planar8 --

pub extern fn vImageConvert_RGB565toPlanar8(src: *const vImage_Buffer, destR: *const vImage_Buffer, destG: *const vImage_Buffer, destB: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar8toRGB565(srcR: *const vImage_Buffer, srcG: *const vImage_Buffer, srcB: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- Packed 16-bit <-> packed 16-bit --

pub extern fn vImageConvert_ARGB1555toRGB565(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGBA5551toRGB565(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGB565toARGB1555(src: *const vImage_Buffer, dest: *const vImage_Buffer, dither: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGB565toRGBA5551(src: *const vImage_Buffer, dest: *const vImage_Buffer, dither: c_int, flags: vImage_Flags) vImage_Error;

// -- RGBA1010102 <-> ARGB8888 / ARGB16U / ARGB16Q12 --

pub extern fn vImageConvert_RGBA1010102ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888ToRGBA1010102(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGBA1010102ToARGB16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB16Q12ToRGBA1010102(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, RGB101010Min: i32, RGB101010Max: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGBA1010102ToARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB16UToRGBA1010102(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;

// -- (X|A)RGB2101010 <-> ARGB8888 --

pub extern fn vImageConvert_XRGB2101010ToARGB8888(src: *const vImage_Buffer, alpha: Pixel_8, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB2101010ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888ToXRGB2101010(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888ToARGB2101010(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;

// -- (X|A)RGB2101010 <-> ARGB16Q12 --

pub extern fn vImageConvert_XRGB2101010ToARGB16Q12(src: *const vImage_Buffer, alpha: Pixel_16Q12, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB2101010ToARGB16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB16Q12ToXRGB2101010(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, RGB101010Min: i32, RGB101010Max: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB16Q12ToARGB2101010(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, RGB101010Min: i32, RGB101010Max: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;

// -- (X|A)RGB2101010 <-> ARGB16U --

pub extern fn vImageConvert_XRGB2101010ToARGB16U(src: *const vImage_Buffer, alpha: Pixel_16U, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB2101010ToARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB16UToXRGB2101010(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB16UToARGB2101010(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;

// -- (X|A)RGB2101010 <-> ARGBFFFF --

pub extern fn vImageConvert_XRGB2101010ToARGBFFFF(src: *const vImage_Buffer, alpha: Pixel_F, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB2101010ToARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGBFFFFToXRGB2101010(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGBFFFFToARGB2101010(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;

// -- (X|A)RGB2101010 -> ARGB16F --

// Note: alpha here is Pixel_F (a real 32-bit float), not a half; no bitcast needed.
pub extern fn vImageConvert_XRGB2101010ToARGB16F(src: *const vImage_Buffer, alpha: Pixel_F, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB2101010ToARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, RGB101010RangeMin: i32, RGB101010RangeMax: i32, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;

// -- YpCbCr conversion info generation --

pub extern fn vImageConvert_YpCbCrToARGB_GenerateConversion(matrix: *const vImage_YpCbCrToARGBMatrix, pixelRange: *const vImage_YpCbCrPixelRange, outInfo: *vImage_YpCbCrToARGB, inYpCbCrType: vImageYpCbCrType, outARGBType: vImageARGBType, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGBToYpCbCr_GenerateConversion(matrix: *const vImage_ARGBToYpCbCrMatrix, pixelRange: *const vImage_YpCbCrPixelRange, outInfo: *vImage_ARGBToYpCbCr, inARGBType: vImageARGBType, outYpCbCrType: vImageYpCbCrType, flags: vImage_Flags) vImage_Error;

// -- 4:2:2 8-bit YpCbCr <-> ARGB8888 --

pub extern fn vImageConvert_422YpCbYpCr8ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888To422YpCbYpCr8(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_422CbYpCrYp8ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888To422CbYpCrYp8(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_422CbYpCrYp8_AA8ToARGB8888(src: *const vImage_Buffer, srcA: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888To422CbYpCrYp8_AA8(src: *const vImage_Buffer, dest: *const vImage_Buffer, destA: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;

// -- 4:2:0 8-bit YpCbCr <-> ARGB8888 --

pub extern fn vImageConvert_420Yp8_Cb8_Cr8ToARGB8888(srcYp: *const vImage_Buffer, srcCb: *const vImage_Buffer, srcCr: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888To420Yp8_Cb8_Cr8(src: *const vImage_Buffer, destYp: *const vImage_Buffer, destCb: *const vImage_Buffer, destCr: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_420Yp8_CbCr8ToARGB8888(srcYp: *const vImage_Buffer, srcCbCr: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888To420Yp8_CbCr8(src: *const vImage_Buffer, destYp: *const vImage_Buffer, destCbCr: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;

// -- 4:4:4 8-bit YpCbCr <-> ARGB8888 --

pub extern fn vImageConvert_444AYpCbCr8ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888To444AYpCbCr8(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_444CbYpCrA8ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888To444CbYpCrA8(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_444CrYpCb8ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888To444CrYpCb8(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;

// -- 4:4:4 16-bit YpCbCr <-> ARGB8888 / ARGB16U --

pub extern fn vImageConvert_444AYpCbCr16ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888To444AYpCbCr16(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_444AYpCbCr16ToARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB16UTo444AYpCbCr16(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;

// -- 4:4:4 10-bit YpCbCr <-> ARGB8888 / ARGB16Q12 --

pub extern fn vImageConvert_444CrYpCb10ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888To444CrYpCb10(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_444CrYpCb10ToARGB16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_16Q12, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB16Q12To444CrYpCb10(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;

// -- 4:2:2 10-bit YpCbCr <-> ARGB8888 / ARGB16Q12 --

pub extern fn vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888To422CrYpCbYpCbYpCbYpCrYpCrYp10(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_16Q12, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB16Q12To422CrYpCbYpCbYpCbYpCrYpCrYp10(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;

// -- 4:2:2 16-bit YpCbCr <-> ARGB8888 / ARGB16U --

pub extern fn vImageConvert_422CbYpCrYp16ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888To422CbYpCrYp16(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_422CbYpCrYp16ToARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_YpCbCrToARGB, permuteMap: *const [4]u8, alpha: Pixel_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB16UTo422CbYpCrYp16(src: *const vImage_Buffer, dest: *const vImage_Buffer, info: *const vImage_ARGBToYpCbCr, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;

// -- 16Q12 scalar format conversions --

pub extern fn vImageConvert_8to16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_16Q12to8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_16Q12to16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_16Fto16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_16Q12toF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Fto16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_16Q12to16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_16Uto16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- 16Q12 planar <-> interleaved --

pub extern fn vImageConvert_RGB888toPlanar16Q12(src: *const vImage_Buffer, red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888toPlanar16Q12(src: *const vImage_Buffer, alpha: *const vImage_Buffer, red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar16Q12toRGB888(red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar16Q12toARGB8888(alpha: *const vImage_Buffer, red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar16Q12toRGB16F(red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar16Q12toARGB16F(alpha: *const vImage_Buffer, red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- Half-float / 12-bit / 16-bit depth conversions --

pub extern fn vImageConvert_12UTo16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_16UTo12U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_16Fto16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_16Uto16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- 16U interleaved <-> 8888 / 16U interleaved --

pub extern fn vImageConvert_ARGB16UToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, copyMask: u8, backgroundColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888ToARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, copyMask: u8, backgroundColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB8888ToRGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [3]u8, copyMask: u8, backgroundColor: *const [3]Pixel_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGB16UToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, copyMask: u8, backgroundColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;

// -- 16U interleaved <-> 16U planar / 3-channel 16U --

pub extern fn vImageConvert_ARGB16UtoPlanar16U(argbSrc: *const vImage_Buffer, aDest: *const vImage_Buffer, rDest: *const vImage_Buffer, gDest: *const vImage_Buffer, bDest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar16UtoARGB16U(aSrc: *const vImage_Buffer, rSrc: *const vImage_Buffer, gSrc: *const vImage_Buffer, bSrc: *const vImage_Buffer, argbDest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGB16UtoPlanar16U(rgbSrc: *const vImage_Buffer, rDest: *const vImage_Buffer, gDest: *const vImage_Buffer, bDest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar16UtoRGB16U(rSrc: *const vImage_Buffer, gSrc: *const vImage_Buffer, bSrc: *const vImage_Buffer, rgbDest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGB16UtoRGB16U(argbSrc: *const vImage_Buffer, rgbDest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGBA16UtoRGB16U(rgbaSrc: *const vImage_Buffer, rgbDest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_BGRA16UtoRGB16U(bgraSrc: *const vImage_Buffer, rgbDest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGB16UtoARGB16U(rgbSrc: *const vImage_Buffer, aSrc: ?*const vImage_Buffer, alpha: Pixel_16U, argbDest: *const vImage_Buffer, premultiply: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGB16UtoRGBA16U(rgbSrc: *const vImage_Buffer, aSrc: ?*const vImage_Buffer, alpha: Pixel_16U, rgbaDest: *const vImage_Buffer, premultiply: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGB16UtoBGRA16U(rgbSrc: *const vImage_Buffer, aSrc: ?*const vImage_Buffer, alpha: Pixel_16U, bgraDest: *const vImage_Buffer, premultiply: bool, flags: vImage_Flags) vImage_Error;

// -- Dithered down-conversions --

pub extern fn vImageConvert_ARGB16UtoARGB8888_dithered(src: *const vImage_Buffer, dest: *const vImage_Buffer, dither: c_int, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ARGBFFFFtoARGB8888_dithered(src: *const vImage_Buffer, dest: *const vImage_Buffer, maxFloat: *const Pixel_FFFF, minFloat: *const Pixel_FFFF, dither: c_int, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar16UtoPlanar8_dithered(src: *const vImage_Buffer, dest: *const vImage_Buffer, dither: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_PlanarFtoPlanar8_dithered(src: *const vImage_Buffer, dest: *const vImage_Buffer, maxFloat: Pixel_F, minFloat: Pixel_F, dither: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGB16UtoRGB888_dithered(src: *const vImage_Buffer, dest: *const vImage_Buffer, dither: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_RGBFFFtoRGB888_dithered(src: *const vImage_Buffer, dest: *const vImage_Buffer, maxFloat: *const [3]Pixel_F, minFloat: *const [3]Pixel_F, dither: c_int, flags: vImage_Flags) vImage_Error;

// -- Planar <-> XRGB / BGRX interleaved (opaque-alpha variants) --

pub extern fn vImageConvert_XRGB8888ToPlanar8(src: *const vImage_Buffer, red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_BGRX8888ToPlanar8(src: *const vImage_Buffer, blue: *const vImage_Buffer, green: *const vImage_Buffer, red: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_XRGBFFFFToPlanarF(src: *const vImage_Buffer, red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_BGRXFFFFToPlanarF(src: *const vImage_Buffer, blue: *const vImage_Buffer, green: *const vImage_Buffer, red: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar8ToXRGB8888(alpha: Pixel_8, red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar8ToBGRX8888(blue: *const vImage_Buffer, green: *const vImage_Buffer, red: *const vImage_Buffer, alpha: Pixel_8, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar8ToXRGBFFFF(alpha: Pixel_F, red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, dest: *const vImage_Buffer, maxFloat: *const Pixel_FFFF, minFloat: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar8ToBGRXFFFF(blue: *const vImage_Buffer, green: *const vImage_Buffer, red: *const vImage_Buffer, alpha: Pixel_F, dest: *const vImage_Buffer, maxFloat: *const Pixel_FFFF, minFloat: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_PlanarFToXRGB8888(alpha: Pixel_8, red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, dest: *const vImage_Buffer, maxFloat: *const Pixel_FFFF, minFloat: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_PlanarFToBGRX8888(blue: *const vImage_Buffer, green: *const vImage_Buffer, red: *const vImage_Buffer, alpha: Pixel_8, dest: *const vImage_Buffer, maxFloat: *const Pixel_FFFF, minFloat: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_PlanarFToXRGBFFFF(alpha: Pixel_F, red: *const vImage_Buffer, green: *const vImage_Buffer, blue: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_PlanarFToBGRXFFFF(blue: *const vImage_Buffer, green: *const vImage_Buffer, red: *const vImage_Buffer, alpha: Pixel_F, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- Indexed and sub-byte planar formats --

pub extern fn vImageConvert_Indexed1toPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, colors: *const [2]Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Indexed2toPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, colors: *const [4]Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Indexed4toPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, colors: *const [16]Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar8toIndexed1(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, colors: *[2]Pixel_8, dither: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar8toIndexed2(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, colors: *[4]Pixel_8, dither: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar8toIndexed4(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, colors: *[16]Pixel_8, dither: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar1toPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar2toPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar4toPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar8toPlanar1(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, dither: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar8toPlanar2(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, dither: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_Planar8toPlanar4(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, dither: c_int, flags: vImage_Flags) vImage_Error;

// -- Chunky <-> Planar (generic N-channel) --

pub extern fn vImageConvert_ChunkyToPlanar8(srcChannels: [*]const ?*const anyopaque, destPlanarBuffers: [*]const *const vImage_Buffer, channelCount: c_uint, srcStrideBytes: usize, srcWidth: vImagePixelCount, srcHeight: vImagePixelCount, srcRowBytes: usize, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_ChunkyToPlanarF(srcChannels: [*]const ?*const anyopaque, destPlanarBuffers: [*]const *const vImage_Buffer, channelCount: c_uint, srcStrideBytes: usize, srcWidth: vImagePixelCount, srcHeight: vImagePixelCount, srcRowBytes: usize, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_PlanarToChunky8(srcPlanarBuffers: [*]const *const vImage_Buffer, destChannels: [*]const ?*anyopaque, channelCount: c_uint, destStrideBytes: usize, destWidth: vImagePixelCount, destHeight: vImagePixelCount, destRowBytes: usize, flags: vImage_Flags) vImage_Error;
pub extern fn vImageConvert_PlanarToChunkyF(srcPlanarBuffers: [*]const *const vImage_Buffer, destChannels: [*]const ?*anyopaque, channelCount: c_uint, destStrideBytes: usize, destWidth: vImagePixelCount, destHeight: vImagePixelCount, destRowBytes: usize, flags: vImage_Flags) vImage_Error;

// -- Flatten (composite against a background color) --

pub extern fn vImageFlatten_ARGB8888(argbSrc: *const vImage_Buffer, argbDst: *const vImage_Buffer, argbBackgroundColorPtr: *const Pixel_8888, isImagePremultiplied: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageFlatten_ARGBFFFF(argbSrc: *const vImage_Buffer, argbDst: *const vImage_Buffer, argbBackgroundColorPtr: *const Pixel_FFFF, isImagePremultiplied: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageFlatten_ARGB16U(argbSrc: *const vImage_Buffer, argbDst: *const vImage_Buffer, argbBackgroundColorPtr: *const Pixel_ARGB_16U, isImagePremultiplied: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageFlatten_ARGB16Q12(argbSrc: *const vImage_Buffer, argbDst: *const vImage_Buffer, argbBackgroundColorPtr: *const Pixel_ARGB_16S, isImagePremultiplied: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageFlatten_RGBA8888(rgbaSrc: *const vImage_Buffer, rgbaDst: *const vImage_Buffer, rgbaBackgroundColorPtr: *const Pixel_8888, isImagePremultiplied: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageFlatten_RGBAFFFF(rgbaSrc: *const vImage_Buffer, rgbaDst: *const vImage_Buffer, rgbaBackgroundColorPtr: *const Pixel_FFFF, isImagePremultiplied: bool, flags: vImage_Flags) vImage_Error;
pub extern fn vImageFlatten_RGBA16U(rgbaSrc: *const vImage_Buffer, rgbaDst: *const vImage_Buffer, rgbaBackgroundColorPtr: *const Pixel_ARGB_16U, isImagePremultiplied: bool, flags: vImage_Flags) vImage_Error;
// Note: vImageFlatten_RGBA16Q12 uses the ARGB parameter names in the header verbatim.
pub extern fn vImageFlatten_RGBA16Q12(argbSrc: *const vImage_Buffer, argbDst: *const vImage_Buffer, argbBackgroundColorPtr: *const Pixel_ARGB_16S, isImagePremultiplied: bool, flags: vImage_Flags) vImage_Error;

// -- Buffer fill --

pub extern fn vImageBufferFill_ARGB16U(dest: *const vImage_Buffer, color: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageBufferFill_ARGB16S(dest: *const vImage_Buffer, color: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageBufferFill_ARGB16F(dest: *const vImage_Buffer, color: *const Pixel_ARGB_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageBufferFill_CbCr8(dest: *const vImage_Buffer, color: *const Pixel_88, flags: vImage_Flags) vImage_Error;
pub extern fn vImageBufferFill_CbCr16U(dest: *const vImage_Buffer, color: *const Pixel_16U16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageBufferFill_CbCr16S(dest: *const vImage_Buffer, color: *const Pixel_16S16S, flags: vImage_Flags) vImage_Error;

// -- Channel overwrite / permute --

pub extern fn vImageOverwriteChannelsWithPixel_ARGB16U(the_pixel: *const Pixel_ARGB_16U, src: *const vImage_Buffer, dest: *const vImage_Buffer, copyMask: u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageOverwriteChannelsWithScalar_Planar16U(scalar: Pixel_16U, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageOverwriteChannelsWithScalar_Planar16S(scalar: Pixel_16S, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageOverwriteChannelsWithScalar_Planar16F(scalar: Pixel_16F, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePermuteChannels_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePermuteChannelsWithMaskedInsert_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, copyMask: u8, backgroundColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePermuteChannelsWithMaskedInsert_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, copyMask: u8, backgroundColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePermuteChannelsWithMaskedInsert_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, permuteMap: *const [4]u8, copyMask: u8, backgroundColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;

// -- Byte swap --

pub extern fn vImageByteSwap_Planar16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// ============================================================================
// Geometry
// ============================================================================
//
// Generated from Geometry.h. The format suffix set differs per operation -
// `vImageScale` has fourteen, `vImagePerspectiveWarp` six - so the lists below
// are the header's, not a uniform cross-product.
//
// Multi-channel background colours are C arrays, which decay to pointers as
// parameters, so they are `*const [N]T` here and not the array by value.

// -- vImageRotate --

pub extern fn vImageRotate_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: Pixel_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: *const Pixel_ARGB_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate_CbCr16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: *const Pixel_16F16F, flags: vImage_Flags) vImage_Error;

// -- vImageScale --

pub extern fn vImageScale_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_Planar16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_Planar16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_XRGB2101010W(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_CbCr8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_CbCr16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_CbCr16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;

// -- vImageHorizontalReflect --

pub extern fn vImageHorizontalReflect_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_Planar16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_CbCr16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- vImageVerticalReflect --

pub extern fn vImageVerticalReflect_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_Planar16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_CbCr16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- vImageRotate90 --

pub extern fn vImageRotate90_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate90_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate90_Planar16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: Pixel_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate90_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: Pixel_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate90_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate90_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate90_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate90_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate90_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: *const Pixel_ARGB_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate90_CbCr16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: *const Pixel_16F16F, flags: vImage_Flags) vImage_Error;

// -- vImageAffineWarp --

pub extern fn vImageAffineWarp_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarp_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarp_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: Pixel_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarp_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarp_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarp_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarp_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarp_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: *const Pixel_ARGB_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarp_CbCr16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: *const Pixel_16F16F, flags: vImage_Flags) vImage_Error;

// -- vImageAffineWarpD --

pub extern fn vImageAffineWarpD_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpD_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpD_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: Pixel_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpD_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpD_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpD_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpD_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpD_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: *const Pixel_ARGB_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpD_CbCr16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: *const Pixel_16F16F, flags: vImage_Flags) vImage_Error;

// -- vImageAffineWarpCG --

pub extern fn vImageAffineWarpCG_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_CGAffineTransform, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpCG_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_CGAffineTransform, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpCG_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_CGAffineTransform, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpCG_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_CGAffineTransform, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpCG_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_CGAffineTransform, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpCG_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_CGAffineTransform, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;

// -- vImageHorizontalShear --

pub extern fn vImageHorizontalShear_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_Planar16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_Planar16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_XRGB2101010W(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_32U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_CbCr8(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_88, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_CbCr16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_16U16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_CbCr16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_16S16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_CbCr16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_16F16F, flags: vImage_Flags) vImage_Error;

// -- vImageVerticalShear --

pub extern fn vImageVerticalShear_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_Planar16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_Planar16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_XRGB2101010W(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_32U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_CbCr8(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_88, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_CbCr16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_16U16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_CbCr16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_16S16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_CbCr16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_16F16F, flags: vImage_Flags) vImage_Error;

// -- vImageHorizontalShearD --

pub extern fn vImageHorizontalShearD_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShearD_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShearD_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: Pixel_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShearD_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShearD_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShearD_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShearD_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShearD_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShearD_CbCr16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_16U16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShearD_CbCr16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_16S16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShearD_CbCr16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_16F16F, flags: vImage_Flags) vImage_Error;

// -- vImageVerticalShearD --

pub extern fn vImageVerticalShearD_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShearD_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShearD_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: Pixel_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShearD_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShearD_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShearD_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShearD_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShearD_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShearD_CbCr16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_16U16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShearD_CbCr16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_16S16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShearD_CbCr16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f64, shearSlope: f64, filter: ResamplingFilter, backColor: *const Pixel_16F16F, flags: vImage_Flags) vImage_Error;

// -- vImagePerspectiveWarp --

pub extern fn vImagePerspectiveWarp_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_PerspectiveTransform, interpolation: WarpInterpolation, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePerspectiveWarp_Planar16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_PerspectiveTransform, interpolation: WarpInterpolation, backColor: Pixel_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePerspectiveWarp_Planar16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_PerspectiveTransform, interpolation: WarpInterpolation, backColor: Pixel_16F, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePerspectiveWarp_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_PerspectiveTransform, interpolation: WarpInterpolation, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePerspectiveWarp_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_PerspectiveTransform, interpolation: WarpInterpolation, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePerspectiveWarp_ARGB16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_PerspectiveTransform, interpolation: WarpInterpolation, backColor: *const Pixel_ARGB_16F, flags: vImage_Flags) vImage_Error;

// -- Resampling Filter --
//
// `vImageNewResamplingKernel`, `vImageGetResamplingKernelSize` and
// `vImageNewResamplingKernelForFunctionUsingBuffer` are `#define` aliases for
// the three below, not symbols of their own.

pub extern fn vImageNewResamplingFilter(scale: f32, flags: vImage_Flags) ResamplingFilter;
pub extern fn vImageDestroyResamplingFilter(filter: ResamplingFilter) void;
pub extern fn vImageGetResamplingFilterSize(scale: f32, kernelFunc: KernelFunc, kernelWidth: f32, flags: vImage_Flags) usize;
pub extern fn vImageGetResamplingFilterExtent(filter: ResamplingFilter, flags: vImage_Flags) vImagePixelCount;
pub extern fn vImageNewResamplingFilterForFunctionUsingBuffer(filter: ResamplingFilter, scale: f32, kernelFunc: KernelFunc, kernelWidth: f32, userData: ?*anyopaque, flags: vImage_Flags) vImage_Error;

// -- Perspective transform helper --

pub extern fn vImageGetPerspectiveWarp(srcPoints: *const [4][2]f32, destPoints: *const [4][2]f32, transform: *vImage_PerspectiveTransform, flags: vImage_Flags) vImage_Error;

// ============================================================================
// Histogram
// ============================================================================

// -- Histogram Calculation --

pub extern fn vImageHistogramCalculation_Planar8(src: *const vImage_Buffer, histogram: [*]vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHistogramCalculation_PlanarF(src: *const vImage_Buffer, histogram: [*]vImagePixelCount, histogram_entries: c_uint, minVal: Pixel_F, maxVal: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHistogramCalculation_ARGB8888(src: *const vImage_Buffer, histogram: *[4][*]vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHistogramCalculation_ARGBFFFF(src: *const vImage_Buffer, histogram: *[4][*]vImagePixelCount, histogram_entries: c_uint, minVal: Pixel_F, maxVal: Pixel_F, flags: vImage_Flags) vImage_Error;

// -- Histogram Equalization --

pub extern fn vImageEqualization_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageEqualization_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, histogram_entries: c_uint, minVal: Pixel_F, maxVal: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageEqualization_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageEqualization_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, histogram_entries: c_uint, minVal: Pixel_F, maxVal: Pixel_F, flags: vImage_Flags) vImage_Error;

// -- Histogram Specification --

pub extern fn vImageHistogramSpecification_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, desired_histogram: [*]const vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHistogramSpecification_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, desired_histogram: [*]const vImagePixelCount, histogram_entries: c_uint, minVal: Pixel_F, maxVal: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHistogramSpecification_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, desired_histogram: *const [4][*]const vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHistogramSpecification_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, desired_histogram: *const [4][*]const vImagePixelCount, histogram_entries: c_uint, minVal: Pixel_F, maxVal: Pixel_F, flags: vImage_Flags) vImage_Error;

// -- Contrast Stretch --

pub extern fn vImageContrastStretch_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageContrastStretch_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, histogram_entries: c_uint, minVal: Pixel_F, maxVal: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageContrastStretch_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageContrastStretch_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, histogram_entries: c_uint, minVal: Pixel_F, maxVal: Pixel_F, flags: vImage_Flags) vImage_Error;

// -- Ends-in Contrast Stretch --

pub extern fn vImageEndsInContrastStretch_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, percent_low: c_uint, percent_high: c_uint, flags: vImage_Flags) vImage_Error;
pub extern fn vImageEndsInContrastStretch_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, percent_low: c_uint, percent_high: c_uint, histogram_entries: c_uint, minVal: Pixel_F, maxVal: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageEndsInContrastStretch_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, percent_low: *const [4]c_uint, percent_high: *const [4]c_uint, flags: vImage_Flags) vImage_Error;
pub extern fn vImageEndsInContrastStretch_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, percent_low: *const [4]c_uint, percent_high: *const [4]c_uint, histogram_entries: c_uint, minVal: Pixel_F, maxVal: Pixel_F, flags: vImage_Flags) vImage_Error;

// ============================================================================
// Morphology
// ============================================================================

// -- Dilate --

pub extern fn vImageDilate_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const u8, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageDilate_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageDilate_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const u8, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageDilate_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;

// -- Erode --

pub extern fn vImageErode_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const u8, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageErode_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageErode_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const u8, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageErode_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel: [*]const f32, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;

// -- Max --

pub extern fn vImageMax_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageMax_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageMax_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageMax_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;

// -- Min --

pub extern fn vImageMin_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageMin_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageMin_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;
pub extern fn vImageMin_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, kernel_height: vImagePixelCount, kernel_width: vImagePixelCount, flags: vImage_Flags) vImage_Error;

// ============================================================================
// Transform
// ============================================================================

// -- Matrix Multiply (Planar) --

pub extern fn vImageMatrixMultiply_Planar8(srcs: [*]const *const vImage_Buffer, dests: [*]const *const vImage_Buffer, src_planes: u32, dest_planes: u32, matrix: [*]const i16, divisor: i32, pre_bias: ?[*]const i16, post_bias: ?[*]const i32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageMatrixMultiply_PlanarF(srcs: [*]const *const vImage_Buffer, dests: [*]const *const vImage_Buffer, src_planes: u32, dest_planes: u32, matrix: [*]const f32, pre_bias: ?[*]const f32, post_bias: ?[*]const f32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageMatrixMultiply_Planar16S(srcs: [*]const *const vImage_Buffer, dests: [*]const *const vImage_Buffer, src_planes: u32, dest_planes: u32, matrix: [*]const i16, divisor: i32, pre_bias: ?[*]const i16, post_bias: ?[*]const i32, flags: vImage_Flags) vImage_Error;

// -- Matrix Multiply (Interleaved ARGB) --

pub extern fn vImageMatrixMultiply_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, matrix: *const [16]i16, divisor: i32, pre_bias: ?*const [4]i16, post_bias: ?*const [4]i32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageMatrixMultiply_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, matrix: *const [16]f32, pre_bias: ?*const [4]f32, post_bias: ?*const [4]f32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageMatrixMultiply_ARGB8888ToPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, matrix: *const [4]i16, divisor: i32, pre_bias: ?*const [4]i16, post_bias: i32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageMatrixMultiply_ARGBFFFFToPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, matrix: *const [4]f32, pre_bias: ?*const [4]f32, post_bias: f32, flags: vImage_Flags) vImage_Error;

// -- Gamma (create / destroy / apply) --

pub extern fn vImageCreateGammaFunction(gamma: f32, gamma_type: c_int, flags: vImage_Flags) GammaFunction;
pub extern fn vImageDestroyGammaFunction(f: GammaFunction) void;
pub extern fn vImageGamma_Planar8toPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, gamma: GammaFunction, flags: vImage_Flags) vImage_Error;
pub extern fn vImageGamma_PlanarFtoPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, gamma: GammaFunction, flags: vImage_Flags) vImage_Error;
pub extern fn vImageGamma_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, gamma: GammaFunction, flags: vImage_Flags) vImage_Error;

// -- Piecewise Gamma --

pub extern fn vImagePiecewiseGamma_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, exponentialCoeffs: *const [3]f32, gamma: f32, linearCoeffs: *const [2]f32, boundary: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePiecewiseGamma_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, exponentialCoeffs: *const [3]f32, gamma: f32, linearCoeffs: *const [2]f32, boundary: f32, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePiecewiseGamma_PlanarFtoPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, exponentialCoeffs: *const [3]f32, gamma: f32, linearCoeffs: *const [2]f32, boundary: f32, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePiecewiseGamma_Planar8toPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, exponentialCoeffs: *const [3]f32, gamma: f32, linearCoeffs: *const [2]f32, boundary: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePiecewiseGamma_Planar16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, exponentialCoeffs: *const [3]f32, gamma: f32, linearCoeffs: *const [2]f32, boundary: Pixel_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePiecewiseGamma_Planar16Q12toPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, exponentialCoeffs: *const [3]f32, gamma: f32, linearCoeffs: *const [2]f32, boundary: Pixel_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePiecewiseGamma_Planar8toPlanar16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, exponentialCoeffs: *const [3]f32, gamma: f32, linearCoeffs: *const [2]f32, boundary: Pixel_8, flags: vImage_Flags) vImage_Error;

// -- Symmetric Piecewise Gamma --

pub extern fn vImageSymmetricPiecewiseGamma_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, exponentialCoeffs: *const [3]f32, gamma: f32, linearCoeffs: *const [2]f32, boundary: f32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageSymmetricPiecewiseGamma_Planar16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, exponentialCoeffs: *const [3]f32, gamma: f32, linearCoeffs: *const [2]f32, boundary: Pixel_16S, flags: vImage_Flags) vImage_Error;

// -- Piecewise Polynomial --

pub extern fn vImagePiecewisePolynomial_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, coefficients: [*]const [*]const f32, boundaries: [*]const f32, order: u32, log2segments: u32, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePiecewisePolynomial_Planar8toPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, coefficients: [*]const [*]const f32, boundaries: [*]const f32, order: u32, log2segments: u32, flags: vImage_Flags) vImage_Error;
pub extern fn vImagePiecewisePolynomial_PlanarFtoPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, coefficients: [*]const [*]const f32, boundaries: [*]const f32, order: u32, log2segments: u32, flags: vImage_Flags) vImage_Error;

// -- Symmetric Piecewise Polynomial --

pub extern fn vImageSymmetricPiecewisePolynomial_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, coefficients: [*]const [*]const f32, boundaries: [*]const f32, order: u32, log2segments: u32, flags: vImage_Flags) vImage_Error;

// -- Piecewise Rational --

pub extern fn vImagePiecewiseRational_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, topCoefficients: [*]const [*]const f32, bottomCoefficients: [*]const [*]const f32, boundaries: [*]const f32, topOrder: u32, bottomOrder: u32, log2segments: u32, flags: vImage_Flags) vImage_Error;

// -- Lookup Tables --

pub extern fn vImageLookupTable_Planar8toPlanar16(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]Pixel_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageLookupTable_Planar8toPlanar24(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]u32, flags: vImage_Flags) vImage_Error;
pub extern fn vImageLookupTable_Planar8toPlanar48(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]u64, flags: vImage_Flags) vImage_Error;
pub extern fn vImageLookupTable_Planar8toPlanar96(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageLookupTable_Planar8toPlanar128(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]Pixel_FFFF, flags: vImage_Flags) vImage_Error;
pub extern fn vImageLookupTable_Planar8toPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageLookupTable_PlanarFtoPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [4096]Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageLookupTable_8to64U(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]u64, flags: vImage_Flags) vImage_Error;
pub extern fn vImageLookupTable_Planar16(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [0x10000]Pixel_16U, flags: vImage_Flags) vImage_Error;

// -- Interpolated Lookup Table --

pub extern fn vImageInterpolatedLookupTable_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: [*]const Pixel_F, tableEntries: vImagePixelCount, maxFloat: f32, minFloat: f32, flags: vImage_Flags) vImage_Error;

// -- Multidimensional Interpolated Lookup Table --

pub extern fn vImageMultidimensionalTable_Create(tableData: [*]const u16, numSrcChannels: u32, numDestChannels: u32, table_entries_per_dimension: [*]const u8, hint: u32, flags: vImage_Flags, err: ?*vImage_Error) vImage_MultidimensionalTable;
pub extern fn vImageMultidimensionalTable_Retain(table: vImage_MultidimensionalTable) vImage_Error;
pub extern fn vImageMultidimensionalTable_Release(table: vImage_MultidimensionalTable) vImage_Error;
pub extern fn vImageMultiDimensionalInterpolatedLookupTable_PlanarF(srcs: [*]const vImage_Buffer, dests: [*]const vImage_Buffer, tempBuffer: ?*anyopaque, table: vImage_MultidimensionalTable, method: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageMultiDimensionalInterpolatedLookupTable_Planar16Q12(srcs: [*]const vImage_Buffer, dests: [*]const vImage_Buffer, tempBuffer: ?*anyopaque, table: vImage_MultidimensionalTable, method: c_int, flags: vImage_Flags) vImage_Error;

// -- Flood Fill --

pub extern fn vImageFloodFill_Planar8(srcDest: *const vImage_Buffer, tempBuffer: ?*anyopaque, seedX: vImagePixelCount, seedY: vImagePixelCount, newValue: Pixel_8, connectivity: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageFloodFill_Planar16U(srcDest: *const vImage_Buffer, tempBuffer: ?*anyopaque, seedX: vImagePixelCount, seedY: vImagePixelCount, newValue: Pixel_16U, connectivity: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageFloodFill_ARGB8888(srcDest: *const vImage_Buffer, tempBuffer: ?*anyopaque, seedX: vImagePixelCount, seedY: vImagePixelCount, newValue: *const Pixel_8888, connectivity: c_int, flags: vImage_Flags) vImage_Error;
pub extern fn vImageFloodFill_ARGB16U(srcDest: *const vImage_Buffer, tempBuffer: ?*anyopaque, seedX: vImagePixelCount, seedY: vImagePixelCount, newValue: *const Pixel_ARGB_16U, connectivity: c_int, flags: vImage_Flags) vImage_Error;

// ============================================================================
// Basic Image Types
// ============================================================================

// -- PNG predictor --

pub extern fn vImagePNGDecompressionFilter(buffer: *const vImage_Buffer, startScanline: vImagePixelCount, scanlineCount: vImagePixelCount, bitsPerPixel: u32, filterMethodNumber: u32, filterType: u32, flags: vImage_Flags) vImage_Error;

// An `extern fn` nobody calls is never resolved, so a misspelled symbol - or
// one a future SDK stops exporting - would link cleanly right up until the
// first caller. Taking the address of every declaration here forces all of
// them to resolve at link time, which matters most for the format variants
// that no test instantiates directly.
// -- Standard Y'CbCr conversion matrices --
//
// The framework exports these as *pointers to* matrices, so each Zig symbol is
// a variable holding a `*const` matrix rather than the matrix itself.
pub extern var kvImage_YpCbCrToARGBMatrix_ITU_R_601_4: *const vImage_YpCbCrToARGBMatrix;
pub extern var kvImage_YpCbCrToARGBMatrix_ITU_R_709_2: *const vImage_YpCbCrToARGBMatrix;
pub extern var kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4: *const vImage_ARGBToYpCbCrMatrix;
pub extern var kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2: *const vImage_ARGBToYpCbCrMatrix;

test "every declared vImage symbol resolves and links" {
    const std = @import("std");
    var sink: usize = 0;
    inline for (@typeInfo(@This()).@"struct".decls) |decl| {
        const field = @field(@This(), decl.name);
        if (@typeInfo(@TypeOf(field)) == .@"fn") {
            sink +%= @intFromPtr(&field);
        }
    }
    try std.testing.expect(sink != 0);
}
