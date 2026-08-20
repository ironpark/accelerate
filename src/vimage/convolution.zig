const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const VImageError = types.VImageError;
const check = types.check;
const vImage_Flags = types.vImage_Flags;
const vImagePixelCount = types.vImagePixelCount;
const Pixel_8888 = types.Pixel_8888;
const Pixel_FFFF = types.Pixel_FFFF;
const Pixel_16F = types.Pixel_16F;
const Pixel_ARGB_16F = types.Pixel_ARGB_16F;
const Flags = types.Flags;

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
) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageConvolve_Planar8(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.divisor, options.backgroundColor, flags),
        f32 => c.vImageConvolve_PlanarF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.backgroundColor, flags),
        f16 => c.vImageConvolve_Planar16F(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, halfBits(options.backgroundColor), flags),
        else => @compileError("convolvePlanar requires u8, f32 or f16"),
    });
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
) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageConvolve_ARGB8888(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.divisor, &options.backgroundColor, flags),
        f32 => c.vImageConvolve_ARGBFFFF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, &options.backgroundColor, flags),
        f16 => blk: {
            const bg = halfBits4(options.backgroundColor);
            break :blk c.vImageConvolve_ARGB16F(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, &bg, flags);
        },
        else => @compileError("convolveInterleaved requires u8, f32 or f16"),
    });
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
) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageConvolveWithBias_Planar8(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.divisor, options.bias, options.backgroundColor, flags),
        f32 => c.vImageConvolveWithBias_PlanarF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.bias, options.backgroundColor, flags),
        f16 => c.vImageConvolveWithBias_Planar16F(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.bias, halfBits(options.backgroundColor), flags),
        else => @compileError("convolveWithBiasPlanar requires u8, f32 or f16"),
    });
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
) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageConvolveWithBias_ARGB8888(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.divisor, options.bias, &options.backgroundColor, flags),
        f32 => c.vImageConvolveWithBias_ARGBFFFF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.bias, &options.backgroundColor, flags),
        f16 => blk: {
            const bg = halfBits4(options.backgroundColor);
            break :blk c.vImageConvolveWithBias_ARGB16F(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel_height, kernel_width, options.bias, &bg, flags);
        },
        else => @compileError("convolveWithBiasInterleaved requires u8, f32 or f16"),
    });
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
) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageConvolveMultiKernel_ARGB8888(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernels, kernel_height, kernel_width, &options.divisors, &options.biases, &options.backgroundColor, flags),
        f32 => c.vImageConvolveMultiKernel_ARGBFFFF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernels, kernel_height, kernel_width, &options.biases, &options.backgroundColor, flags),
        else => @compileError("convolveMultiKernelInterleaved requires u8 or f32"),
    });
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
) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageRichardsonLucyDeConvolve_Planar8(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel2, kernel_height, kernel_width, kernel_height2, kernel_width2, options.divisor, options.divisor2, options.backgroundColor, iterationCount, flags),
        f32 => c.vImageRichardsonLucyDeConvolve_PlanarF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel2, kernel_height, kernel_width, kernel_height2, kernel_width2, options.backgroundColor, iterationCount, flags),
        else => @compileError("richardsonLucyDeConvolvePlanar requires u8 or f32"),
    });
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
) VImageError!usize {
    return check(switch (T) {
        u8 => c.vImageRichardsonLucyDeConvolve_ARGB8888(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel2, kernel_height, kernel_width, kernel_height2, kernel_width2, options.divisor, options.divisor2, &options.backgroundColor, iterationCount, flags),
        f32 => c.vImageRichardsonLucyDeConvolve_ARGBFFFF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel, kernel2, kernel_height, kernel_width, kernel_height2, kernel_width2, &options.backgroundColor, iterationCount, flags),
        else => @compileError("richardsonLucyDeConvolveInterleaved requires u8 or f32"),
    });
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
) VImageError!usize {
    return check(c.vImageBoxConvolve_Planar8(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel_height, kernel_width, backgroundColor, flags));
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
) VImageError!usize {
    return check(c.vImageBoxConvolve_ARGB8888(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel_height, kernel_width, backgroundColor, flags));
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
) VImageError!usize {
    return check(c.vImageTentConvolve_Planar8(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel_height, kernel_width, backgroundColor, flags));
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
) VImageError!usize {
    return check(c.vImageTentConvolve_ARGB8888(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel_height, kernel_width, backgroundColor, flags));
}

// ============================================================================
// Separable Convolution
// ============================================================================

/// Separable convolution on a planar image: `T` selects `u8`, `u16`, `f32` or
/// `f16` (Planar8, Planar16U, PlanarF, Planar16F).
///
/// A separable filter is one whose 2D kernel is the outer product of two 1D
/// kernels, `kernel_y * kernel_x'`. Where `convolvePlanar` does
/// `kx * ky` multiply-accumulates per pixel, this does `kx + ky`, which for a
/// Gaussian blur of any useful radius is the difference between usable and
/// not. The weights are `f32` for every `T`, including the integer formats.
///
/// The kernels are slices rather than the pointer-plus-width pair the 2D
/// family uses, because here the element count *is* the width - there is no
/// second dimension for the length to disagree with.
///
/// Both kernel widths must be odd. Does not work in place.
///
/// Returns the temp buffer size when
/// `Options.of(.{ .get_temp_buffer_size = true })` is passed, as elsewhere in
/// this module.
pub fn sepConvolvePlanar(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernel_x: []const f32,
    kernel_y: []const f32,
    options: SepConvolvePlanarOptions(T),
    flags: vImage_Flags,
) VImageError!usize {
    const kx: u32 = @intCast(kernel_x.len);
    const ky: u32 = @intCast(kernel_y.len);
    return check(switch (T) {
        u8 => c.vImageSepConvolve_Planar8(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel_x.ptr, kx, kernel_y.ptr, ky, options.bias, options.backgroundColor, flags),
        u16 => c.vImageSepConvolve_Planar16U(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel_x.ptr, kx, kernel_y.ptr, ky, options.bias, options.backgroundColor, flags),
        f32 => c.vImageSepConvolve_PlanarF(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel_x.ptr, kx, kernel_y.ptr, ky, options.bias, options.backgroundColor, flags),
        f16 => c.vImageSepConvolve_Planar16F(src, dest, tempBuffer, srcOffsetToROI_X, srcOffsetToROI_Y, kernel_x.ptr, kx, kernel_y.ptr, ky, options.bias, halfBits(options.backgroundColor), flags),
        else => @compileError("sepConvolvePlanar requires u8, u16, f32 or f16"),
    });
}

/// Separable convolution from a Planar8 source into a Planar16U destination.
///
/// Widening the result is the point: an 8-bit input convolved with a kernel
/// that sums to more than 1 saturates in 8 bits, so this one carries a
/// `scale` alongside the bias and writes 16 bits. The computed value is
/// `scale * sum + bias`, rounded and clamped to `0 ..= 65535`.
pub fn sepConvolvePlanar8to16U(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernel_x: []const f32,
    kernel_y: []const f32,
    options: struct {
        scale: f32 = 1.0,
        bias: f32 = 0.0,
        backgroundColor: u8 = 0,
    },
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageSepConvolve_Planar8to16U(
        src,
        dest,
        tempBuffer,
        srcOffsetToROI_X,
        srcOffsetToROI_Y,
        kernel_x.ptr,
        @intCast(kernel_x.len),
        kernel_y.ptr,
        @intCast(kernel_y.len),
        options.scale,
        options.bias,
        options.backgroundColor,
        flags,
    ));
}

/// Separable convolution on a 4-channel interleaved 8-bit image.
///
/// All four channels get the same pair of kernels; use
/// `convolveMultiKernelInterleaved` if they need to differ.
pub fn sepConvolveARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernel_x: []const f32,
    kernel_y: []const f32,
    options: struct {
        bias: f32 = 0.0,
        backgroundColor: Pixel_8888 = .{ 0, 0, 0, 0 },
    },
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageSepConvolve_ARGB8888(
        src,
        dest,
        tempBuffer,
        srcOffsetToROI_X,
        srcOffsetToROI_Y,
        kernel_x.ptr,
        @intCast(kernel_x.len),
        kernel_y.ptr,
        @intCast(kernel_y.len),
        options.bias,
        &options.backgroundColor,
        flags,
    ));
}

// ============================================================================
// Float-kernel ARGB8888 Convolution
// ============================================================================

/// Convolve an ARGB8888 image against a **floating-point** kernel.
///
/// `convolveInterleaved(u8, ...)` and `convolveWithBiasInterleaved(u8, ...)`
/// take an `i16` kernel and an integer divisor, which forces the caller to
/// express fractional weights as a scaled integer plus a divisor. This takes
/// the weights directly and needs no divisor. The result is still rounded and
/// clamped back into 8 bits per channel.
pub fn convolveFloatKernelARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    srcOffsetToROI_X: vImagePixelCount,
    srcOffsetToROI_Y: vImagePixelCount,
    kernel: [*]const f32,
    kernel_height: u32,
    kernel_width: u32,
    options: struct {
        bias: f32 = 0.0,
        backgroundColor: Pixel_8888 = .{ 0, 0, 0, 0 },
    },
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvolveFloatKernel_ARGB8888(
        src,
        dest,
        tempBuffer,
        srcOffsetToROI_X,
        srcOffsetToROI_Y,
        kernel,
        kernel_height,
        kernel_width,
        options.bias,
        &options.backgroundColor,
        flags,
    ));
}

// ============================================================================
// Type helpers
// ============================================================================

/// vImage's 16F formats are IEEE 754 binary16 stored as `uint16_t`, so a
/// background colour crosses the boundary as its bit pattern. Taking `f16` in
/// the wrapper and reinterpreting here means callers write `0.5`, not `0x3800`.
fn halfBits(value: f16) Pixel_16F {
    return @bitCast(value);
}

fn halfBits4(value: [4]f16) Pixel_ARGB_16F {
    return .{ halfBits(value[0]), halfBits(value[1]), halfBits(value[2]), halfBits(value[3]) };
}

/// Options for separable planar convolution. Every variant carries an `f32`
/// bias; only the background colour's type follows `T`.
fn SepConvolvePlanarOptions(comptime T: type) type {
    return switch (T) {
        // Planar8's background colour is a `Pixel_16U`, not a `Pixel_8`. That
        // is the header's signature - vImage takes the 16-bit value and uses
        // its low byte - and it is preserved here rather than narrowed, so a
        // caller reading Convolution.h finds the same type.
        u8, u16 => struct {
            bias: f32 = 0.0,
            backgroundColor: u16 = 0,
        },
        f32 => struct {
            bias: f32 = 0.0,
            backgroundColor: f32 = 0.0,
        },
        f16 => struct {
            bias: f32 = 0.0,
            backgroundColor: f16 = 0.0,
        },
        else => @compileError("SepConvolvePlanarOptions requires u8, u16, f32 or f16"),
    };
}

/// Returns the kernel element pointer type for the given pixel component type.
fn KernelPtr(comptime T: type) type {
    return switch (T) {
        u8 => [*]const i16,
        // The 16F entry points take a *single*-precision kernel: the pixels
        // are half, the weights are not.
        f32, f16 => [*]const f32,
        else => @compileError("KernelPtr requires u8, f32 or f16"),
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
        f16 => struct {
            backgroundColor: f16 = 0.0,
        },
        else => @compileError("ConvolvePlanarOptions requires u8, f32 or f16"),
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
        f16 => struct {
            backgroundColor: [4]f16 = .{ 0.0, 0.0, 0.0, 0.0 },
        },
        else => @compileError("ConvolveInterleavedOptions requires u8, f32 or f16"),
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
        f16 => struct {
            bias: f32 = 0.0,
            backgroundColor: f16 = 0.0,
        },
        else => @compileError("ConvolveWithBiasPlanarOptions requires u8, f32 or f16"),
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
        f16 => struct {
            bias: f32 = 0.0,
            backgroundColor: [4]f16 = .{ 0.0, 0.0, 0.0, 0.0 },
        },
        else => @compileError("ConvolveWithBiasInterleavedOptions requires u8, f32 or f16"),
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

// ============================================================================
// Tests
// ============================================================================
//
// Buffers are deliberately built with `rowBytes` larger than
// `width * bytesPerPixel` (real padding, not just the tight-packed minimum)
// so a wrapper that assumed `rowBytes == width * bytesPerPixel` would read
// or write at the wrong offset and fail these tests instead of silently
// "working" on tightly-packed test data.

/// Allocate a Planar8 vImage_Buffer with padded rowBytes and populate it
/// from a tightly-packed row-major `values` slice (height*width elements).
fn makePlanar8Buffer(allocator: std.mem.Allocator, height: usize, width: usize, row_pad: usize, values: []const u8) !struct { buf: vImage_Buffer, mem: []u8 } {
    const row_bytes = width + row_pad;
    const mem = try allocator.alloc(u8, row_bytes * height);
    @memset(mem, 0xAA); // sentinel padding, must never be read as pixel data
    for (0..height) |y| {
        @memcpy(mem[y * row_bytes ..][0..width], values[y * width ..][0..width]);
    }
    return .{
        .buf = .{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes },
        .mem = mem,
    };
}

fn readPlanar8(buf: vImage_Buffer, y: usize, x: usize) u8 {
    const base: [*]u8 = @ptrCast(buf.data.?);
    return base[y * buf.rowBytes + x];
}

/// Allocate an all-zero Planar8 destination buffer with padded rowBytes.
fn makeEmptyPlanar8Buffer(allocator: std.mem.Allocator, height: usize, width: usize, row_pad: usize) !struct { buf: vImage_Buffer, mem: []u8 } {
    const row_bytes = width + row_pad;
    const mem = try allocator.alloc(u8, row_bytes * height);
    @memset(mem, 0);
    return .{
        .buf = .{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes },
        .mem = mem,
    };
}

/// Allocate a PlanarF vImage_Buffer with padded rowBytes (row_pad in f32 elements).
fn makePlanarFBuffer(allocator: std.mem.Allocator, height: usize, width: usize, row_pad_elems: usize, values: []const f32) !struct { buf: vImage_Buffer, mem: []f32 } {
    const row_elems = width + row_pad_elems;
    const mem = try allocator.alloc(f32, row_elems * height);
    @memset(mem, -999.0);
    for (0..height) |y| {
        @memcpy(mem[y * row_elems ..][0..width], values[y * width ..][0..width]);
    }
    return .{
        .buf = .{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_elems * @sizeOf(f32) },
        .mem = mem,
    };
}

fn readPlanarF(buf: vImage_Buffer, y: usize, x: usize) f32 {
    const base: [*]u8 = @ptrCast(buf.data.?);
    const row: [*]f32 = @ptrCast(@alignCast(base + y * buf.rowBytes));
    return row[x];
}

test "convolvePlanar u8: kernel_height/kernel_width are not swapped" {
    // 3x3 image, values distinct per-pixel so a specific neighbor pick is
    // unambiguous:
    //   1 2 3
    //   4 5 6
    //   7 8 9
    // A 1x3 (height=1, width=3) kernel {0,0,1} selects, for interior pixel
    // (x=1,y=1), the pixel one column to the right: pixel[y][x+1] = 6.
    // If kernel_height/kernel_width were swapped by the wrapper, the C call
    // would instead see a 3x1 kernel and select pixel[y+1][x] = 8. 6 != 8,
    // so this distinguishes the two unambiguously.
    const allocator = std.testing.allocator;
    const src_vals = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    var src = try makePlanar8Buffer(allocator, 3, 3, 2, &src_vals);
    defer allocator.free(src.mem);
    var dest = try makeEmptyPlanar8Buffer(allocator, 3, 3, 3);
    defer allocator.free(dest.mem);

    const kernel = [_]i16{ 0, 0, 1 };
    const err = convolvePlanar(u8, &src.buf, &dest.buf, null, 0, 0, kernel[0..].ptr, 1, 3, .{ .divisor = 1 }, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(u8, 6), readPlanar8(dest.buf, 1, 1));
}

test "convolvePlanar f32: kernel_height/kernel_width are not swapped" {
    const allocator = std.testing.allocator;
    const src_vals = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    var src = try makePlanarFBuffer(allocator, 3, 3, 2, &src_vals);
    defer allocator.free(src.mem);
    var dest = try makePlanarFBuffer(allocator, 3, 3, 3, &[_]f32{0} ** 9);
    defer allocator.free(dest.mem);

    // 3x1 (height=3, width=1) kernel {0,0,1} selects pixel[y+1][x] = 8 for
    // the interior pixel (x=1,y=1) -- the complementary check to the u8 test
    // above (this time width=1, height=3).
    const kernel = [_]f32{ 0, 0, 1 };
    const err = convolvePlanar(f32, &src.buf, &dest.buf, null, 0, 0, kernel[0..].ptr, 3, 1, .{}, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(f32, 8), readPlanarF(dest.buf, 1, 1));
}

test "convolveInterleaved ARGB8888: kernel_height/kernel_width are not swapped" {
    // Same idea as convolvePlanar, but on channel 0 (A) of a 4-channel
    // interleaved image; other channels are zeroed so a channel mixup would
    // also be visible.
    const allocator = std.testing.allocator;
    const width = 3;
    const height = 3;
    const row_bytes = width * 4 + 4; // padded
    const mem = try allocator.alloc(u8, row_bytes * height);
    defer allocator.free(mem);
    @memset(mem, 0);
    const vals = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    for (0..height) |y| {
        for (0..width) |x| {
            mem[y * row_bytes + x * 4] = vals[y * width + x]; // channel 0 only
        }
    }
    const src_buf = vImage_Buffer{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };

    const dest_mem = try allocator.alloc(u8, row_bytes * height);
    defer allocator.free(dest_mem);
    @memset(dest_mem, 0);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };

    const kernel = [_]i16{ 0, 0, 1 };
    const err = convolveInterleaved(u8, &src_buf, &dest_buf, null, 0, 0, kernel[0..].ptr, 1, 3, .{ .divisor = 1 }, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(u8, 6), dest_mem[1 * row_bytes + 1 * 4]);
}

test "convolveWithBiasPlanar u8: applies (sum + bias) / divisor, matching Convolution.h's documented formula" {
    // Convolution.h (vImageConvolveWithBias_Planar8): "sum = (sum + bias) / divisor;"
    // -- bias is added before dividing, distinct from vImageConvolve_Planar8's
    // rounding correction "(sum + divisor/2) / divisor" (no user bias).
    const allocator = std.testing.allocator;
    const src_vals = [_]u8{ 10, 10, 10, 10, 10, 10, 10, 10, 10 };
    var src = try makePlanar8Buffer(allocator, 3, 3, 1, &src_vals);
    defer allocator.free(src.mem);
    var dest = try makeEmptyPlanar8Buffer(allocator, 3, 3, 2);
    defer allocator.free(dest.mem);

    // 1x1 kernel {3} at center pixel: sum = 3*10 = 30. bias=5, divisor=7.
    // Expected (integer division, truncating toward zero since (30+5)=35 is
    // positive): 35/7 = 5.
    const kernel = [_]i16{3};
    const err = convolveWithBiasPlanar(u8, &src.buf, &dest.buf, null, 0, 0, kernel[0..].ptr, 1, 1, .{ .divisor = 7, .bias = 5 }, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(u8, 5), readPlanar8(dest.buf, 1, 1));
}

test "convolveWithBiasInterleaved f32: bias is added to the weighted sum" {
    const allocator = std.testing.allocator;
    const width = 3;
    const height = 3;
    const row_bytes = width * 4 * @sizeOf(f32) + 8;
    const row_elems = row_bytes / @sizeOf(f32);
    const mem = try allocator.alloc(f32, row_elems * height);
    defer allocator.free(mem);
    @memset(mem, 0);
    for (0..height) |y| {
        for (0..width) |x| {
            mem[y * row_elems + x * 4] = 2.0; // channel 0 only
        }
    }
    const src_buf = vImage_Buffer{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };
    const dest_mem = try allocator.alloc(f32, row_elems * height);
    defer allocator.free(dest_mem);
    @memset(dest_mem, 0);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };

    // 1x1 kernel {3.0}, bias=0.5: sum = 3*2=6, +bias = 6.5.
    const kernel = [_]f32{3.0};
    const err = convolveWithBiasInterleaved(f32, &src_buf, &dest_buf, null, 0, 0, kernel[0..].ptr, 1, 1, .{ .bias = 0.5 }, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectApproxEqAbs(@as(f32, 6.5), dest_mem[1 * row_elems + 1 * 4], 1e-6);
}

test "convolveMultiKernelInterleaved u8: each channel uses its own kernel/divisor/bias" {
    const allocator = std.testing.allocator;
    const width = 1;
    const height = 1;
    const row_bytes: usize = 4 + 4;
    const mem = try allocator.alloc(u8, row_bytes * height);
    defer allocator.free(mem);
    @memset(mem, 0);
    // A=10, R=20, G=30, B=40
    mem[0] = 10;
    mem[1] = 20;
    mem[2] = 30;
    mem[3] = 40;
    const src_buf = vImage_Buffer{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };
    const dest_mem = try allocator.alloc(u8, row_bytes * height);
    defer allocator.free(dest_mem);
    @memset(dest_mem, 0);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };

    // Per-channel 1x1 kernel of {1}, per-channel divisor = channel index+1,
    // per-channel bias = 0. Expected: A=10/1=10, R=20/2=10, G=30/3=10, B=40/4=10.
    // A shared/mixed-up divisor array would produce different (non-uniform) output.
    const kA = [_]i16{1};
    const kR = [_]i16{1};
    const kG = [_]i16{1};
    const kB = [_]i16{1};
    const kernels = [4][*]const i16{ kA[0..].ptr, kR[0..].ptr, kG[0..].ptr, kB[0..].ptr };
    const err = convolveMultiKernelInterleaved(u8, &src_buf, &dest_buf, null, 0, 0, &kernels, 1, 1, .{ .divisors = .{ 1, 2, 3, 4 } }, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 10, 10, 10, 10 }, dest_mem[0..4]);
}

test "richardsonLucyDeConvolvePlanar u8: identity PSFs converge to the source image" {
    // Convolution.h's documented iterative formula is:
    //   e[i+1] = e[i] * (psf0 conv (e[0] / (psf1 conv e[i])))
    // With psf0 = psf1 = a 1x1 identity kernel {1}/1, "conv" is a no-op, so
    // algebraically e[i+1] = e[i] * (e[0] / e[i]) = e[0] for any i -- the
    // output should equal the source exactly regardless of iterationCount.
    // This is a real mathematical property of the formula, not a guess, and
    // exercises both kernel/kernel2 argument slots (even though they're
    // structurally identical for this input, a kernel_height/kernel_height2
    // or kernel_width/kernel_width2 mixup would still show up as a
    // dimension error from the C call since both are 1x1 -- verified
    // vImage_Error == 0).
    const allocator = std.testing.allocator;
    const src_vals = [_]u8{ 12, 34, 56, 78, 90, 11, 22, 33, 44 };
    var src = try makePlanar8Buffer(allocator, 3, 3, 1, &src_vals);
    defer allocator.free(src.mem);
    var dest = try makeEmptyPlanar8Buffer(allocator, 3, 3, 2);
    defer allocator.free(dest.mem);

    const kernel = [_]i16{1};
    const kernel2 = [_]i16{1};
    const err = richardsonLucyDeConvolvePlanar(
        u8,
        &src.buf,
        &dest.buf,
        null,
        0,
        0,
        kernel[0..].ptr,
        1,
        1,
        kernel2[0..].ptr,
        1,
        1,
        .{ .divisor = 1, .divisor2 = 1 },
        5,
        Flags.kvImageEdgeExtend,
    );
    try std.testing.expectEqual(@as(usize, 0), try err);
    for (0..3) |y| {
        for (0..3) |x| {
            try std.testing.expectEqual(readPlanar8(src.buf, y, x), readPlanar8(dest.buf, y, x));
        }
    }
}

test "richardsonLucyDeConvolveInterleaved u8: smoke test (identity PSFs preserve the source)" {
    const allocator = std.testing.allocator;
    const width = 2;
    const height = 2;
    const row_bytes: usize = width * 4 + 4;
    const mem = try allocator.alloc(u8, row_bytes * height);
    defer allocator.free(mem);
    const vals = [_]u8{ 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160 };
    @memcpy(mem[0 .. width * 4], vals[0 .. width * 4]);
    @memcpy(mem[row_bytes .. row_bytes + width * 4], vals[width * 4 ..][0 .. width * 4]);
    const src_buf = vImage_Buffer{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };
    const dest_mem = try allocator.alloc(u8, row_bytes * height);
    defer allocator.free(dest_mem);
    @memset(dest_mem, 0);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };

    const kernel = [_]i16{1};
    const kernel2 = [_]i16{1};
    const err = richardsonLucyDeConvolveInterleaved(
        u8,
        &src_buf,
        &dest_buf,
        null,
        0,
        0,
        kernel[0..].ptr,
        1,
        1,
        kernel2[0..].ptr,
        1,
        1,
        .{ .divisor = 1, .divisor2 = 1 },
        3,
        Flags.kvImageEdgeExtend,
    );
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqualSlices(u8, mem[0 .. width * 4], dest_mem[0 .. width * 4]);
}

test "boxConvolvePlanar8: uniform average over kernel_height x kernel_width, matching Convolution.h" {
    // Convolution.h: kernel_area = kernel_height*kernel_width;
    // sum = (sum + kernel_area/2) / kernel_area  (rounded unweighted average)
    const allocator = std.testing.allocator;
    // 3x3 image, interior pixel (1,1) covered fully by a 3x3 box (no edge handling needed):
    //   1 2 3
    //   4 5 6
    //   7 8 9
    // sum = 1+2+3+4+5+6+7+8+9 = 45; area=9; (45+4)/9 = 5 (integer division).
    const src_vals = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    var src = try makePlanar8Buffer(allocator, 3, 3, 2, &src_vals);
    defer allocator.free(src.mem);
    var dest = try makeEmptyPlanar8Buffer(allocator, 3, 3, 1);
    defer allocator.free(dest.mem);

    const err = boxConvolvePlanar8(&src.buf, &dest.buf, null, 0, 0, 3, 3, 0, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(u8, 5), readPlanar8(dest.buf, 1, 1));
}

test "boxConvolvePlanar8: kernel_height/kernel_width are not swapped (non-square 1x3)" {
    // 1x3 box (height=1,width=3) over row y=1: (4+5+6+1)/3 = 5 (integer div w/ rounding).
    // If height/width were swapped, the C call would see a 3x1 box instead,
    // averaging column x=1 (2+5+8+1)/3 = 5 too by coincidence with this data,
    // so use asymmetric data where the two differ:
    //   1 2 3
    //   4 5 60
    //   7 8 9
    // 1x3 row average at (1,1): (4+5+60 + 1)/3 = 70/3 = 23 (int, clamped to 255 n/a).
    // 3x1 col average at (1,1): (2+5+8 + 1)/3 = 16/3 = 5.
    const allocator = std.testing.allocator;
    const src_vals = [_]u8{ 1, 2, 3, 4, 5, 60, 7, 8, 9 };
    var src = try makePlanar8Buffer(allocator, 3, 3, 2, &src_vals);
    defer allocator.free(src.mem);
    var dest = try makeEmptyPlanar8Buffer(allocator, 3, 3, 1);
    defer allocator.free(dest.mem);

    const err = boxConvolvePlanar8(&src.buf, &dest.buf, null, 0, 0, 1, 3, 0, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(u8, 23), readPlanar8(dest.buf, 1, 1));
}

test "boxConvolveARGB8888: smoke test, error == 0" {
    const allocator = std.testing.allocator;
    const width = 3;
    const height = 3;
    const row_bytes = width * 4 + 4;
    const mem = try allocator.alloc(u8, row_bytes * height);
    defer allocator.free(mem);
    @memset(mem, 5);
    const src_buf = vImage_Buffer{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };
    const dest_mem = try allocator.alloc(u8, row_bytes * height);
    defer allocator.free(dest_mem);
    @memset(dest_mem, 0);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };
    const bg = Pixel_8888{ 0, 0, 0, 0 };

    const err = boxConvolveARGB8888(&src_buf, &dest_buf, null, 0, 0, 3, 3, &bg, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(usize, 0), try err);
    // Uniform input -> uniform output, unweighted average preserves the constant.
    try std.testing.expectEqualSlices(u8, &[_]u8{ 5, 5, 5, 5 }, dest_mem[1 * row_bytes + 1 * 4 ..][0..4]);
}

test "tentConvolvePlanar8: runtime-confirmed triangular weighting for kernel size 3" {
    // Convolution.h documents the *general* weighted-sum-then-divide formula
    // for vImageTentConvolve_Planar8 but does not spell out the per-size
    // kernel weights (they are generated internally from kernel_height/
    // kernel_width). For an odd size N, a 1D tent kernel is the standard
    // triangular weighting that peaks at the center and falls off linearly;
    // for N=3 that is {1,2,1} (sum=4), and the 2D kernel is the separable
    // outer product. This test treats that as a hypothesis and lets runtime
    // execution be the judge.
    //   1 2 3
    //   4 5 6
    //   7 8 9
    // Predicted 3x3 tent weights (outer product of {1,2,1}):
    //   1 2 1
    //   2 4 2
    //   1 2 1
    // sum = 1*1+2*2+3*1 + 4*2+5*4+6*2 + 7*1+8*2+9*1
    //     = (1+4+3) + (8+20+12) + (7+16+9) = 8 + 40 + 32 = 80
    // divisor = sum of weights = 16. (80 + 8) / 16 = 5 (rounded).
    const allocator = std.testing.allocator;
    const src_vals = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    var src = try makePlanar8Buffer(allocator, 3, 3, 2, &src_vals);
    defer allocator.free(src.mem);
    var dest = try makeEmptyPlanar8Buffer(allocator, 3, 3, 1);
    defer allocator.free(dest.mem);

    const err = tentConvolvePlanar8(&src.buf, &dest.buf, null, 0, 0, 3, 3, 0, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(u8, 5), readPlanar8(dest.buf, 1, 1));
}

test "tentConvolveARGB8888: smoke test, error == 0" {
    const allocator = std.testing.allocator;
    const width = 3;
    const height = 3;
    const row_bytes = width * 4 + 4;
    const mem = try allocator.alloc(u8, row_bytes * height);
    defer allocator.free(mem);
    @memset(mem, 7);
    const src_buf = vImage_Buffer{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };
    const dest_mem = try allocator.alloc(u8, row_bytes * height);
    defer allocator.free(dest_mem);
    @memset(dest_mem, 0);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };
    const bg = Pixel_8888{ 0, 0, 0, 0 };

    const err = tentConvolveARGB8888(&src_buf, &dest_buf, null, 0, 0, 3, 3, &bg, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 7, 7, 7, 7 }, dest_mem[1 * row_bytes + 1 * 4 ..][0..4]);
}

// ---------------------------------------------------------------------------
// Separable convolution, float-kernel ARGB8888, and the 16F formats
// ---------------------------------------------------------------------------

/// Allocate a Planar16F vImage_Buffer with padded rowBytes, populated from
/// `f16` values. vImage sees `uint16_t`; the storage here is `f16` so the
/// tests can read the pixels back as numbers.
fn makePlanar16FBuffer(allocator: std.mem.Allocator, height: usize, width: usize, row_pad_elems: usize, values: []const f16) !struct { buf: vImage_Buffer, mem: []f16 } {
    const row_elems = width + row_pad_elems;
    const mem = try allocator.alloc(f16, row_elems * height);
    @memset(mem, -999.0);
    for (0..height) |y| {
        @memcpy(mem[y * row_elems ..][0..width], values[y * width ..][0..width]);
    }
    return .{
        .buf = .{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_elems * @sizeOf(f16) },
        .mem = mem,
    };
}

fn readPlanar16F(buf: vImage_Buffer, y: usize, x: usize) f16 {
    const base: [*]u8 = @ptrCast(buf.data.?);
    const row: [*]f16 = @ptrCast(@alignCast(base + y * buf.rowBytes));
    return row[x];
}

fn makePlanar16UBuffer(allocator: std.mem.Allocator, height: usize, width: usize, row_pad_elems: usize, values: []const u16) !struct { buf: vImage_Buffer, mem: []u16 } {
    const row_elems = width + row_pad_elems;
    const mem = try allocator.alloc(u16, row_elems * height);
    @memset(mem, 0xEEEE);
    for (0..height) |y| {
        @memcpy(mem[y * row_elems ..][0..width], values[y * width ..][0..width]);
    }
    return .{
        .buf = .{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_elems * @sizeOf(u16) },
        .mem = mem,
    };
}

fn readPlanar16U(buf: vImage_Buffer, y: usize, x: usize) u16 {
    const base: [*]u8 = @ptrCast(buf.data.?);
    const row: [*]u16 = @ptrCast(@alignCast(base + y * buf.rowBytes));
    return row[x];
}

test "sepConvolvePlanar u8: kernelX and kernelY are not swapped" {
    // The separable pair is exactly where an argument-order slip hides,
    // because for the symmetric kernels people actually use (Gaussian, box)
    // swapping X and Y produces the same image. This uses an asymmetric pair
    // that does not: kernelX = {0,0,1} shifts one column right, kernelY is
    // the identity. On
    //   1 2 3
    //   4 5 6
    //   7 8 9
    // the centre pixel must become 6. Swapped, it would become 8.
    const allocator = std.testing.allocator;
    const src_vals = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    var src = try makePlanar8Buffer(allocator, 3, 3, 2, &src_vals);
    defer allocator.free(src.mem);
    var dest = try makeEmptyPlanar8Buffer(allocator, 3, 3, 3);
    defer allocator.free(dest.mem);

    const kx = [_]f32{ 0, 0, 1 };
    const ky = [_]f32{ 0, 1, 0 };
    const err = try sepConvolvePlanar(u8, &src.buf, &dest.buf, null, 0, 0, &kx, &ky, .{}, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(usize, 0), err);
    try std.testing.expectEqual(@as(u8, 6), readPlanar8(dest.buf, 1, 1));
}

test "sepConvolvePlanar f32: separable pair equals the outer-product 2D kernel" {
    // The stronger claim: a separable convolution is the 2D convolution by
    // ky * kx'. Running both and comparing pins the whole computation, not
    // just the argument order - and it does so against vImage's own 2D path,
    // which the existing tests already tie to Convolution.h's formula.
    const allocator = std.testing.allocator;
    const w = 5;
    const h = 5;
    var src_vals: [w * h]f32 = undefined;
    for (0..h) |y| {
        for (0..w) |x| {
            const fy: f32 = @floatFromInt(y);
            const fx: f32 = @floatFromInt(x);
            src_vals[y * w + x] = fx * 2.0 - fy + fx * fy * 0.5;
        }
    }

    const kx = [_]f32{ 0.25, 0.5, 0.25 };
    const ky = [_]f32{ -1.0, 0.0, 1.0 }; // asymmetric: a vertical derivative

    var sep_src = try makePlanarFBuffer(allocator, h, w, 2, &src_vals);
    defer allocator.free(sep_src.mem);
    var sep_dest = try makePlanarFBuffer(allocator, h, w, 3, &[_]f32{0} ** (w * h));
    defer allocator.free(sep_dest.mem);
    _ = try sepConvolvePlanar(f32, &sep_src.buf, &sep_dest.buf, null, 0, 0, &kx, &ky, .{}, Flags.kvImageEdgeExtend);

    // The equivalent 2D kernel, in the row-major (kernel_height x
    // kernel_width) order convolvePlanar expects.
    var kernel2d: [9]f32 = undefined;
    for (0..3) |i| {
        for (0..3) |j| kernel2d[i * 3 + j] = ky[i] * kx[j];
    }
    var full_src = try makePlanarFBuffer(allocator, h, w, 2, &src_vals);
    defer allocator.free(full_src.mem);
    var full_dest = try makePlanarFBuffer(allocator, h, w, 3, &[_]f32{0} ** (w * h));
    defer allocator.free(full_dest.mem);
    _ = try convolvePlanar(f32, &full_src.buf, &full_dest.buf, null, 0, 0, kernel2d[0..].ptr, 3, 3, .{}, Flags.kvImageEdgeExtend);

    for (0..h) |y| {
        for (0..w) |x| {
            try std.testing.expectApproxEqAbs(
                readPlanarF(full_dest.buf, y, x),
                readPlanarF(sep_dest.buf, y, x),
                0.001,
            );
        }
    }
}

test "sepConvolvePlanar u16: bias is added to the weighted sum" {
    const allocator = std.testing.allocator;
    const src_vals = [_]u16{ 100, 200, 300, 400, 500, 600, 700, 800, 900 };
    var src = try makePlanar16UBuffer(allocator, 3, 3, 2, &src_vals);
    defer allocator.free(src.mem);
    var dest = try makePlanar16UBuffer(allocator, 3, 3, 3, &[_]u16{0} ** 9);
    defer allocator.free(dest.mem);

    const identity = [_]f32{ 0, 1, 0 };
    _ = try sepConvolvePlanar(u16, &src.buf, &dest.buf, null, 0, 0, &identity, &identity, .{ .bias = 50 }, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(u16, 550), readPlanar16U(dest.buf, 1, 1));
}

test "sepConvolvePlanar f16: half-precision pixels, single-precision weights" {
    const allocator = std.testing.allocator;
    const src_vals = [_]f16{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    var src = try makePlanar16FBuffer(allocator, 3, 3, 2, &src_vals);
    defer allocator.free(src.mem);
    var dest = try makePlanar16FBuffer(allocator, 3, 3, 3, &[_]f16{0} ** 9);
    defer allocator.free(dest.mem);

    const kx = [_]f32{ 0, 0, 1 };
    const ky = [_]f32{ 0, 1, 0 };
    _ = try sepConvolvePlanar(f16, &src.buf, &dest.buf, null, 0, 0, &kx, &ky, .{}, Flags.kvImageEdgeExtend);
    try std.testing.expectApproxEqAbs(@as(f16, 6), readPlanar16F(dest.buf, 1, 1), 0.01);
}

test "sepConvolvePlanar8to16U: scale widens past what 8 bits could hold" {
    // The reason this variant exists: with scale = 100 the identity result
    // 200 becomes 20000, which is representable in the 16-bit destination and
    // would have clamped to 255 in an 8-bit one.
    const allocator = std.testing.allocator;
    const src_vals = [_]u8{ 10, 20, 30, 40, 200, 60, 70, 80, 90 };
    var src = try makePlanar8Buffer(allocator, 3, 3, 2, &src_vals);
    defer allocator.free(src.mem);
    var dest = try makePlanar16UBuffer(allocator, 3, 3, 3, &[_]u16{0} ** 9);
    defer allocator.free(dest.mem);

    const identity = [_]f32{ 0, 1, 0 };
    _ = try sepConvolvePlanar8to16U(&src.buf, &dest.buf, null, 0, 0, &identity, &identity, .{ .scale = 100, .bias = 7 }, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(u16, 20007), readPlanar16U(dest.buf, 1, 1));
}

test "sepConvolveARGB8888: kernelX and kernelY are not swapped" {
    const allocator = std.testing.allocator;
    const width = 3;
    const height = 3;
    const row_bytes = width * 4 + 4;
    const mem = try allocator.alloc(u8, row_bytes * height);
    defer allocator.free(mem);
    @memset(mem, 0);
    const vals = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    for (0..height) |y| {
        for (0..width) |x| mem[y * row_bytes + x * 4] = vals[y * width + x];
    }
    const src_buf = vImage_Buffer{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };

    const dest_mem = try allocator.alloc(u8, row_bytes * height);
    defer allocator.free(dest_mem);
    @memset(dest_mem, 0);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };

    const kx = [_]f32{ 0, 0, 1 };
    const ky = [_]f32{ 0, 1, 0 };
    _ = try sepConvolveARGB8888(&src_buf, &dest_buf, null, 0, 0, &kx, &ky, .{}, Flags.kvImageEdgeExtend);
    try std.testing.expectEqual(@as(u8, 6), dest_mem[1 * row_bytes + 1 * 4]);
}

test "convolveFloatKernelARGB8888: fractional weights without an integer divisor" {
    // The integer-kernel path would need {1,1,1} with divisor 3 to express
    // this; here the weights are the weights. 1/3 is not representable in
    // binary, which is the point - an i16 kernel could not carry it at all.
    const allocator = std.testing.allocator;
    const width = 3;
    const height = 3;
    const row_bytes = width * 4 + 4;
    const mem = try allocator.alloc(u8, row_bytes * height);
    defer allocator.free(mem);
    @memset(mem, 0);
    const vals = [_]u8{ 30, 60, 90, 30, 60, 90, 30, 60, 90 };
    for (0..height) |y| {
        for (0..width) |x| mem[y * row_bytes + x * 4] = vals[y * width + x];
    }
    const src_buf = vImage_Buffer{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };

    const dest_mem = try allocator.alloc(u8, row_bytes * height);
    defer allocator.free(dest_mem);
    @memset(dest_mem, 0);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = height, .width = width, .rowBytes = row_bytes };

    const third: f32 = 1.0 / 3.0;
    const kernel = [_]f32{ third, third, third }; // 1x3 horizontal mean
    _ = try convolveFloatKernelARGB8888(&src_buf, &dest_buf, null, 0, 0, kernel[0..].ptr, 1, 3, .{}, Flags.kvImageEdgeExtend);
    // (30 + 60 + 90) / 3 = 60 at the centre.
    try std.testing.expectEqual(@as(u8, 60), dest_mem[1 * row_bytes + 1 * 4]);
}

test "convolvePlanar / convolveWithBiasPlanar f16: the 16F prongs run" {
    const allocator = std.testing.allocator;
    const src_vals = [_]f16{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };

    {
        var src = try makePlanar16FBuffer(allocator, 3, 3, 2, &src_vals);
        defer allocator.free(src.mem);
        var dest = try makePlanar16FBuffer(allocator, 3, 3, 3, &[_]f16{0} ** 9);
        defer allocator.free(dest.mem);
        const kernel = [_]f32{ 0, 0, 1 }; // 1x3: one column right
        _ = try convolvePlanar(f16, &src.buf, &dest.buf, null, 0, 0, kernel[0..].ptr, 1, 3, .{}, Flags.kvImageEdgeExtend);
        try std.testing.expectApproxEqAbs(@as(f16, 6), readPlanar16F(dest.buf, 1, 1), 0.01);
    }
    {
        var src = try makePlanar16FBuffer(allocator, 3, 3, 2, &src_vals);
        defer allocator.free(src.mem);
        var dest = try makePlanar16FBuffer(allocator, 3, 3, 3, &[_]f16{0} ** 9);
        defer allocator.free(dest.mem);
        const kernel = [_]f32{ 0, 1, 0 };
        _ = try convolveWithBiasPlanar(f16, &src.buf, &dest.buf, null, 0, 0, kernel[0..].ptr, 1, 3, .{ .bias = 10 }, Flags.kvImageEdgeExtend);
        try std.testing.expectApproxEqAbs(@as(f16, 15), readPlanar16F(dest.buf, 1, 1), 0.01);
    }
}

test "convolveInterleaved / convolveWithBiasInterleaved f16: the ARGB16F prongs run" {
    const allocator = std.testing.allocator;
    const width = 3;
    const height = 3;
    const row_elems = width * 4 + 4;

    const mem = try allocator.alloc(f16, row_elems * height);
    defer allocator.free(mem);
    @memset(mem, 0);
    const vals = [_]f16{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    for (0..height) |y| {
        for (0..width) |x| mem[y * row_elems + x * 4] = vals[y * width + x];
    }
    const src_buf = vImage_Buffer{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_elems * @sizeOf(f16) };

    const dest_mem = try allocator.alloc(f16, row_elems * height);
    defer allocator.free(dest_mem);
    @memset(dest_mem, 0);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = height, .width = width, .rowBytes = row_elems * @sizeOf(f16) };

    const shift_right = [_]f32{ 0, 0, 1 };
    _ = try convolveInterleaved(f16, &src_buf, &dest_buf, null, 0, 0, shift_right[0..].ptr, 1, 3, .{}, Flags.kvImageEdgeExtend);
    try std.testing.expectApproxEqAbs(@as(f16, 6), dest_mem[1 * row_elems + 1 * 4], 0.01);

    @memset(dest_mem, 0);
    const identity = [_]f32{ 0, 1, 0 };
    _ = try convolveWithBiasInterleaved(f16, &src_buf, &dest_buf, null, 0, 0, identity[0..].ptr, 1, 3, .{ .bias = 10 }, Flags.kvImageEdgeExtend);
    try std.testing.expectApproxEqAbs(@as(f16, 15), dest_mem[1 * row_elems + 1 * 4], 0.01);
}

test "halfBits reinterprets rather than converts" {
    // If this ever became an @intFromFloat the background colour would be
    // silently wrong for every 16F call, and the tests above - which all use
    // edge-extend, never the background - would not notice.
    try std.testing.expectEqual(@as(Pixel_16F, 0x3C00), halfBits(1.0));
    try std.testing.expectEqual(@as(Pixel_16F, 0x0000), halfBits(0.0));
    try std.testing.expectEqual(@as(Pixel_16F, 0x3800), halfBits(0.5));
    try std.testing.expectEqual(Pixel_ARGB_16F{ 0x3C00, 0, 0x3800, 0x3C00 }, halfBits4(.{ 1.0, 0.0, 0.5, 1.0 }));
}
