const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const vImage_Flags = types.vImage_Flags;
const vImagePixelCount = types.vImagePixelCount;
const Pixel_8888 = types.Pixel_8888;
const Pixel_FFFF = types.Pixel_FFFF;
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
    try std.testing.expectEqual(@as(vImage_Error, 0), err);
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
    try std.testing.expectEqual(@as(vImage_Error, 0), err);
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
    try std.testing.expectEqual(@as(vImage_Error, 0), err);
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
    try std.testing.expectEqual(@as(vImage_Error, 0), err);
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
    try std.testing.expectEqual(@as(vImage_Error, 0), err);
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
    try std.testing.expectEqual(@as(vImage_Error, 0), err);
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
    try std.testing.expectEqual(@as(vImage_Error, 0), err);
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
    try std.testing.expectEqual(@as(vImage_Error, 0), err);
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
    try std.testing.expectEqual(@as(vImage_Error, 0), err);
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
    try std.testing.expectEqual(@as(vImage_Error, 0), err);
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
    try std.testing.expectEqual(@as(vImage_Error, 0), err);
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
    // execution be the judge, per fix/REQUEST.md.
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
    try std.testing.expectEqual(@as(vImage_Error, 0), err);
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
    try std.testing.expectEqual(@as(vImage_Error, 0), err);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 7, 7, 7, 7 }, dest_mem[1 * row_bytes + 1 * 4 ..][0..4]);
}
