const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const vImage_Flags = types.vImage_Flags;
const vImagePixelCount = types.vImagePixelCount;
const Pixel_8888 = types.Pixel_8888;
const Pixel_FFFF = types.Pixel_FFFF;

// ============================================================================
// General Convolution
// ============================================================================

/// General convolution on a planar image.
///
/// For Planar8, a signed 16-bit integer kernel with a divisor is used.
/// For PlanarF, a floating-point kernel is used (no divisor needed).
///
/// Applies a convolution kernel (weighted average of neighboring pixels)
/// to produce effects such as blur, sharpen, or edge detection.
///
/// The kernel dimensions must be odd numbers.
/// Does not work in place (src and dest must not alias).
pub fn convolvePlanar(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernel: KernelPtr(T),
    kernel_height: u32,
    kernel_width: u32,
    options: ConvolvePlanarOptions(T),
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        u8 => c.vImageConvolve_Planar8(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.divisor, options.backgroundColor, flags),
        f32 => c.vImageConvolve_PlanarF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.backgroundColor, flags),
        else => @compileError("convolvePlanar requires u8 or f32"),
    };
}

/// General convolution on a 4-channel interleaved image.
///
/// For ARGB8888, a signed 16-bit integer kernel with a divisor is used.
/// For ARGBFFFF, a floating-point kernel is used (no divisor needed).
///
/// Works on any four-channel interleaved format (ARGB, RGBA, BGRA, etc.).
/// The kernel dimensions must be odd numbers.
/// Does not work in place.
pub fn convolveInterleaved(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernel: KernelPtr(T),
    kernel_height: u32,
    kernel_width: u32,
    options: ConvolveInterleavedOptions(T),
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        u8 => c.vImageConvolve_ARGB8888(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.divisor, &options.backgroundColor, flags),
        f32 => c.vImageConvolve_ARGBFFFF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, &options.backgroundColor, flags),
        else => @compileError("convolveInterleaved requires u8 or f32"),
    };
}

// ============================================================================
// Convolution with Bias
// ============================================================================

/// Convolution with bias on a planar image.
///
/// Same as convolvePlanar but adds a bias value before the divisor is applied.
/// Useful for edge detection filters where the derivative can be negative,
/// and a bias shifts values into the representable range.
///
/// For Planar8: result = CLAMP((sum + bias) / divisor, 0, 255)
/// For PlanarF: result = sum + bias  (no clamping)
pub fn convolveWithBiasPlanar(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernel: KernelPtr(T),
    kernel_height: u32,
    kernel_width: u32,
    options: ConvolveWithBiasPlanarOptions(T),
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        u8 => c.vImageConvolveWithBias_Planar8(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.divisor, options.bias, options.backgroundColor, flags),
        f32 => c.vImageConvolveWithBias_PlanarF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.bias, options.backgroundColor, flags),
        else => @compileError("convolveWithBiasPlanar requires u8 or f32"),
    };
}

/// Convolution with bias on a 4-channel interleaved image.
///
/// Same as convolveInterleaved but adds a bias value.
/// For ARGB8888: integer bias applied before integer division.
/// For ARGBFFFF: float bias added to the weighted sum.
pub fn convolveWithBiasInterleaved(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernel: KernelPtr(T),
    kernel_height: u32,
    kernel_width: u32,
    options: ConvolveWithBiasInterleavedOptions(T),
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        u8 => c.vImageConvolveWithBias_ARGB8888(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.divisor, options.bias, &options.backgroundColor, flags),
        f32 => c.vImageConvolveWithBias_ARGBFFFF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.bias, &options.backgroundColor, flags),
        else => @compileError("convolveWithBiasInterleaved requires u8 or f32"),
    };
}

// ============================================================================
// Multi-Kernel Convolution
// ============================================================================

/// Convolution with a separate kernel (and bias/divisor) per channel on a
/// 4-channel interleaved image.
///
/// Allows independent filtering of each channel -- e.g. different blur for
/// alpha vs. color, or per-channel spatial shifts.
///
/// For ARGB8888: each channel has its own i16 kernel, i32 divisor and i32 bias.
/// For ARGBFFFF: each channel has its own f32 kernel and f32 bias.
pub fn convolveMultiKernelInterleaved(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernels: *const [4]MultiKernelElement(T),
    kernel_height: u32,
    kernel_width: u32,
    options: MultiKernelOptions(T),
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        u8 => c.vImageConvolveMultiKernel_ARGB8888(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernels, kernel_height, kernel_width, &options.divisors, &options.biases, &options.backgroundColor, flags),
        f32 => c.vImageConvolveMultiKernel_ARGBFFFF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernels, kernel_height, kernel_width, &options.biases, &options.backgroundColor, flags),
        else => @compileError("convolveMultiKernelInterleaved requires u8 or f32"),
    };
}

// ============================================================================
// Richardson-Lucy Deconvolution
// ============================================================================

/// Richardson-Lucy (Lucy-Richardson) iterative deconvolution on a planar image.
///
/// Attempts to reverse the effect of a known convolution kernel (point spread
/// function). Commonly used to correct lens blur, motion blur, or other
/// optical distortions.
///
/// Uses the iterative formula:
///   e[i+1] = e[i] * (psf0 conv (e[0] / (psf1 conv e[i])))
///
/// kernel (psf0) and kernel2 (psf1) dimensions must be odd.
/// Does not work in place.
pub fn richardsonLucyDeConvolvePlanar(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernel: DeconvolveKernelPtr(T),
    kernel_height: u32,
    kernel_width: u32,
    kernel2: DeconvolveKernelPtr(T),
    kernel_height2: u32,
    kernel_width2: u32,
    options: DeconvolvePlanarOptions(T),
    iterationCount: u32,
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        u8 => c.vImageRichardsonLucyDeConvolve_Planar8(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel2, kernel_height, kernel_width, kernel_height2, kernel_width2, options.divisor, options.divisor2, options.backgroundColor, iterationCount, flags),
        f32 => c.vImageRichardsonLucyDeConvolve_PlanarF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel2, kernel_height, kernel_width, kernel_height2, kernel_width2, options.backgroundColor, iterationCount, flags),
        else => @compileError("richardsonLucyDeConvolvePlanar requires u8 or f32"),
    };
}

/// Richardson-Lucy iterative deconvolution on a 4-channel interleaved image.
///
/// Channels are operated on independently. Works on any 4-channel interleaved
/// format (ARGB, RGBA, BGRA, etc.).
pub fn richardsonLucyDeConvolveInterleaved(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernel: DeconvolveKernelPtr(T),
    kernel_height: u32,
    kernel_width: u32,
    kernel2: DeconvolveKernelPtr(T),
    kernel_height2: u32,
    kernel_width2: u32,
    options: DeconvolveInterleavedOptions(T),
    iterationCount: u32,
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        u8 => c.vImageRichardsonLucyDeConvolve_ARGB8888(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel2, kernel_height, kernel_width, kernel_height2, kernel_width2, options.divisor, options.divisor2, &options.backgroundColor, iterationCount, flags),
        f32 => c.vImageRichardsonLucyDeConvolve_ARGBFFFF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel2, kernel_height, kernel_width, kernel_height2, kernel_width2, &options.backgroundColor, iterationCount, flags),
        else => @compileError("richardsonLucyDeConvolveInterleaved requires u8 or f32"),
    };
}

// ============================================================================
// Box Filter
// ============================================================================

/// Box convolution (uniform average) on a planar image.
///
/// A box filter is a special case where all kernel weights are 1.
/// It computes the unweighted average of pixels in the kernel area.
/// The cost is constant regardless of kernel size, making it very
/// efficient for large blurs (though the result is rectangular in appearance).
///
/// Only available for Planar8.
pub fn boxConvolvePlanar8(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernel_height: u32,
    kernel_width: u32,
    backgroundColor: u8,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageBoxConvolve_Planar8(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel_height, kernel_width, backgroundColor, flags);
}

/// Box convolution on a 4-channel interleaved 8-bit image.
pub fn boxConvolveARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernel_height: u32,
    kernel_width: u32,
    backgroundColor: *const Pixel_8888,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageBoxConvolve_ARGB8888(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel_height, kernel_width, backgroundColor, flags);
}

// ============================================================================
// Tent Filter
// ============================================================================

/// Tent convolution on a planar image.
///
/// A tent filter produces a linearly-weighted average equivalent to two
/// successive box filter passes. The cost is constant regardless of kernel
/// size. The result has less obvious rectangular character than a box blur.
///
/// Only available for Planar8.
pub fn tentConvolvePlanar8(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernel_height: u32,
    kernel_width: u32,
    backgroundColor: u8,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageTentConvolve_Planar8(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel_height, kernel_width, backgroundColor, flags);
}

/// Tent convolution on a 4-channel interleaved 8-bit image.
pub fn tentConvolveARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernel_height: u32,
    kernel_width: u32,
    backgroundColor: *const Pixel_8888,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageTentConvolve_ARGB8888(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel_height, kernel_width, backgroundColor, flags);
}

// ============================================================================
// Type helpers
// ============================================================================

/// Returns the kernel element pointer type for the given pixel component type.
fn KernelPtr(comptime T: type) type {
    return switch (T) {
        u8 => [*]const i16,
        f32 => [*]const f32,
        else => @compileError("KernelPtr requires u8 or f32"),
    };
}

/// Returns the kernel element pointer type for deconvolution.
fn DeconvolveKernelPtr(comptime T: type) type {
    return KernelPtr(T);
}

/// Returns the multi-kernel element pointer type (per-channel kernel pointer).
fn MultiKernelElement(comptime T: type) type {
    return switch (T) {
        u8 => [*]const i16,
        f32 => [*]const f32,
        else => @compileError("MultiKernelElement requires u8 or f32"),
    };
}

/// Options for planar convolution (type-dependent fields).
fn ConvolvePlanarOptions(comptime T: type) type {
    return switch (T) {
        u8 => struct {
            divisor: i32 = 1,
            backgroundColor: u8 = 0,
        },
        f32 => struct {
            backgroundColor: f32 = 0.0,
        },
        else => @compileError("ConvolvePlanarOptions requires u8 or f32"),
    };
}

/// Options for interleaved convolution (type-dependent fields).
fn ConvolveInterleavedOptions(comptime T: type) type {
    return switch (T) {
        u8 => struct {
            divisor: i32 = 1,
            backgroundColor: Pixel_8888 = .{ 0, 0, 0, 0 },
        },
        f32 => struct {
            backgroundColor: Pixel_FFFF = .{ 0.0, 0.0, 0.0, 0.0 },
        },
        else => @compileError("ConvolveInterleavedOptions requires u8 or f32"),
    };
}

/// Options for planar convolution with bias.
fn ConvolveWithBiasPlanarOptions(comptime T: type) type {
    return switch (T) {
        u8 => struct {
            divisor: i32 = 1,
            bias: i32 = 0,
            backgroundColor: u8 = 0,
        },
        f32 => struct {
            bias: f32 = 0.0,
            backgroundColor: f32 = 0.0,
        },
        else => @compileError("ConvolveWithBiasPlanarOptions requires u8 or f32"),
    };
}

/// Options for interleaved convolution with bias.
fn ConvolveWithBiasInterleavedOptions(comptime T: type) type {
    return switch (T) {
        u8 => struct {
            divisor: i32 = 1,
            bias: i32 = 0,
            backgroundColor: Pixel_8888 = .{ 0, 0, 0, 0 },
        },
        f32 => struct {
            bias: f32 = 0.0,
            backgroundColor: Pixel_FFFF = .{ 0.0, 0.0, 0.0, 0.0 },
        },
        else => @compileError("ConvolveWithBiasInterleavedOptions requires u8 or f32"),
    };
}

/// Options for multi-kernel interleaved convolution.
fn MultiKernelOptions(comptime T: type) type {
    return switch (T) {
        u8 => struct {
            divisors: [4]i32 = .{ 1, 1, 1, 1 },
            biases: [4]i32 = .{ 0, 0, 0, 0 },
            backgroundColor: Pixel_8888 = .{ 0, 0, 0, 0 },
        },
        f32 => struct {
            biases: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 },
            backgroundColor: Pixel_FFFF = .{ 0.0, 0.0, 0.0, 0.0 },
        },
        else => @compileError("MultiKernelOptions requires u8 or f32"),
    };
}

/// Options for planar deconvolution.
fn DeconvolvePlanarOptions(comptime T: type) type {
    return switch (T) {
        u8 => struct {
            divisor: i32 = 1,
            divisor2: i32 = 1,
            backgroundColor: u8 = 0,
        },
        f32 => struct {
            backgroundColor: f32 = 0.0,
        },
        else => @compileError("DeconvolvePlanarOptions requires u8 or f32"),
    };
}

/// Options for interleaved deconvolution.
fn DeconvolveInterleavedOptions(comptime T: type) type {
    return switch (T) {
        u8 => struct {
            divisor: i32 = 1,
            divisor2: i32 = 1,
            backgroundColor: Pixel_8888 = .{ 0, 0, 0, 0 },
        },
        f32 => struct {
            backgroundColor: Pixel_FFFF = .{ 0.0, 0.0, 0.0, 0.0 },
        },
        else => @compileError("DeconvolveInterleavedOptions requires u8 or f32"),
    };
}
