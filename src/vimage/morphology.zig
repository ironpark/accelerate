const types = @import("types.zig");
const vImage_Buffer = types.vImage_Buffer;
const vImagePixelCount = types.vImagePixelCount;
const vImage_Flags = types.vImage_Flags;
const vImage_Error = types.vImage_Error;
const Pixel_8 = types.Pixel_8;
const Pixel_F = types.Pixel_F;
const Pixel_8888 = types.Pixel_8888;
const Pixel_FFFF = types.Pixel_FFFF;
const c = @import("c.zig");

/// Kernel element type: u8 for integer pixel formats, f32 for float pixel formats.
fn KernelElement(comptime T: type) type {
    return switch (T) {
        Pixel_8, Pixel_8888 => u8,
        Pixel_F, Pixel_FFFF => f32,
        else => @compileError("Unsupported pixel type for morphology. Use Pixel_8, Pixel_F, Pixel_8888, or Pixel_FFFF."),
    };
}

// ============================================================================
// Dilate
// ============================================================================

/// Apply a dilate morphology filter to an image buffer.
///
/// The dilate filter probes the image with a shaped kernel, finding the maximum
/// value plus the kernel element at each position.
///
/// Supported pixel types: `Pixel_8` (Planar8), `Pixel_F` (PlanarF),
/// `Pixel_8888` (ARGB8888), `Pixel_FFFF` (ARGBFFFF).
pub fn dilate(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    roi_x: vImagePixelCount,
    roi_y: vImagePixelCount,
    kernel: []const KernelElement(T),
    kernel_height: vImagePixelCount,
    kernel_width: vImagePixelCount,
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        Pixel_8 => c.vImageDilate_Planar8(src, dest, roi_x, roi_y, kernel.ptr, kernel_height, kernel_width, flags),
        Pixel_F => c.vImageDilate_PlanarF(src, dest, roi_x, roi_y, kernel.ptr, kernel_height, kernel_width, flags),
        Pixel_8888 => c.vImageDilate_ARGB8888(src, dest, roi_x, roi_y, kernel.ptr, kernel_height, kernel_width, flags),
        Pixel_FFFF => c.vImageDilate_ARGBFFFF(src, dest, roi_x, roi_y, kernel.ptr, kernel_height, kernel_width, flags),
        else => @compileError("dilate requires Pixel_8, Pixel_F, Pixel_8888, or Pixel_FFFF"),
    };
}

// ============================================================================
// Erode
// ============================================================================

/// Apply an erode morphology filter to an image buffer.
///
/// The erode filter traces a shaped kernel beneath the image surface, finding
/// the minimum value minus the kernel element at each position.
///
/// Supported pixel types: `Pixel_8` (Planar8), `Pixel_F` (PlanarF),
/// `Pixel_8888` (ARGB8888), `Pixel_FFFF` (ARGBFFFF).
pub fn erode(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    roi_x: vImagePixelCount,
    roi_y: vImagePixelCount,
    kernel: []const KernelElement(T),
    kernel_height: vImagePixelCount,
    kernel_width: vImagePixelCount,
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        Pixel_8 => c.vImageErode_Planar8(src, dest, roi_x, roi_y, kernel.ptr, kernel_height, kernel_width, flags),
        Pixel_F => c.vImageErode_PlanarF(src, dest, roi_x, roi_y, kernel.ptr, kernel_height, kernel_width, flags),
        Pixel_8888 => c.vImageErode_ARGB8888(src, dest, roi_x, roi_y, kernel.ptr, kernel_height, kernel_width, flags),
        Pixel_FFFF => c.vImageErode_ARGBFFFF(src, dest, roi_x, roi_y, kernel.ptr, kernel_height, kernel_width, flags),
        else => @compileError("erode requires Pixel_8, Pixel_F, Pixel_8888, or Pixel_FFFF"),
    };
}

// ============================================================================
// Max (rectangular kernel)
// ============================================================================

/// Apply a max filter (dilate with a rectangular all-zero kernel).
///
/// This is a special-case dilate that uses a much faster algorithm.
/// Pass `null` for `temp_buffer` to let vImage allocate internally,
/// or use `kvImageGetTempBufferSize` in flags to query the required size.
///
/// Supported pixel types: `Pixel_8` (Planar8), `Pixel_F` (PlanarF),
/// `Pixel_8888` (ARGB8888), `Pixel_FFFF` (ARGBFFFF).
pub fn max(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    temp_buffer: ?*anyopaque,
    roi_x: vImagePixelCount,
    roi_y: vImagePixelCount,
    kernel_height: vImagePixelCount,
    kernel_width: vImagePixelCount,
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        Pixel_8 => c.vImageMax_Planar8(src, dest, temp_buffer, roi_x, roi_y, kernel_height, kernel_width, flags),
        Pixel_F => c.vImageMax_PlanarF(src, dest, temp_buffer, roi_x, roi_y, kernel_height, kernel_width, flags),
        Pixel_8888 => c.vImageMax_ARGB8888(src, dest, temp_buffer, roi_x, roi_y, kernel_height, kernel_width, flags),
        Pixel_FFFF => c.vImageMax_ARGBFFFF(src, dest, temp_buffer, roi_x, roi_y, kernel_height, kernel_width, flags),
        else => @compileError("max requires Pixel_8, Pixel_F, Pixel_8888, or Pixel_FFFF"),
    };
}

// ============================================================================
// Min (rectangular kernel)
// ============================================================================

/// Apply a min filter (erode with a rectangular all-zero kernel).
///
/// This is a special-case erode that uses a much faster algorithm.
/// Pass `null` for `temp_buffer` to let vImage allocate internally,
/// or use `kvImageGetTempBufferSize` in flags to query the required size.
///
/// Supported pixel types: `Pixel_8` (Planar8), `Pixel_F` (PlanarF),
/// `Pixel_8888` (ARGB8888), `Pixel_FFFF` (ARGBFFFF).
pub fn min(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    temp_buffer: ?*anyopaque,
    roi_x: vImagePixelCount,
    roi_y: vImagePixelCount,
    kernel_height: vImagePixelCount,
    kernel_width: vImagePixelCount,
    flags: vImage_Flags,
) vImage_Error {
    return switch (T) {
        Pixel_8 => c.vImageMin_Planar8(src, dest, temp_buffer, roi_x, roi_y, kernel_height, kernel_width, flags),
        Pixel_F => c.vImageMin_PlanarF(src, dest, temp_buffer, roi_x, roi_y, kernel_height, kernel_width, flags),
        Pixel_8888 => c.vImageMin_ARGB8888(src, dest, temp_buffer, roi_x, roi_y, kernel_height, kernel_width, flags),
        Pixel_FFFF => c.vImageMin_ARGBFFFF(src, dest, temp_buffer, roi_x, roi_y, kernel_height, kernel_width, flags),
        else => @compileError("min requires Pixel_8, Pixel_F, Pixel_8888, or Pixel_FFFF"),
    };
}
