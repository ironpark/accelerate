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

// ============================================================================
// Geometry
// ============================================================================

// -- Rotate --

pub extern fn vImageRotate_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, angleInRadians: f32, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;

// -- Scale --

pub extern fn vImageScale_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_Planar16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;
pub extern fn vImageScale_Planar16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, flags: vImage_Flags) vImage_Error;

// -- Affine Warp (single-precision transform) --

pub extern fn vImageAffineWarp_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarp_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarp_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarp_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarp_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarp_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;

// -- Affine Warp (double-precision transform) --

pub extern fn vImageAffineWarpD_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpD_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpD_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpD_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpD_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpD_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_AffineTransform_Double, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;

// -- Affine Warp (CGAffineTransform) --

pub extern fn vImageAffineWarpCG_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_CGAffineTransform, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpCG_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_CGAffineTransform, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpCG_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_CGAffineTransform, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpCG_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_CGAffineTransform, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpCG_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_CGAffineTransform, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageAffineWarpCG_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, tempBuffer: ?*anyopaque, transform: *const vImage_CGAffineTransform, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;

// -- Reflect --

pub extern fn vImageHorizontalReflect_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalReflect_Planar16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

pub extern fn vImageVerticalReflect_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalReflect_Planar16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) vImage_Error;

// -- Rotate90 --

pub extern fn vImageRotate90_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate90_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate90_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate90_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate90_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageRotate90_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, rotationConstant: u8, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;

// -- Shear (single-precision) --

pub extern fn vImageHorizontalShear_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageHorizontalShear_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, xTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;

pub extern fn vImageVerticalShear_Planar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_8, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_PlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: Pixel_F, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_ARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_8888, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_ARGB16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16U, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_ARGB16S(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_ARGB_16S, flags: vImage_Flags) vImage_Error;
pub extern fn vImageVerticalShear_ARGBFFFF(src: *const vImage_Buffer, dest: *const vImage_Buffer, srcOffsetToROI_X: vImagePixelCount, srcOffsetToROI_Y: vImagePixelCount, yTranslate: f32, shearSlope: f32, filter: ResamplingFilter, backColor: *const Pixel_FFFF, flags: vImage_Flags) vImage_Error;

// -- Resampling Filter --

pub extern fn vImageNewResamplingFilter(scale: f32, flags: vImage_Flags) ResamplingFilter;
pub extern fn vImageDestroyResamplingFilter(filter: ResamplingFilter) void;

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
