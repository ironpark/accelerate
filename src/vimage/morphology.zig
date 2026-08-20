const std = @import("std");
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

// ============================================================================
// Tests
// ============================================================================
//
// Layout used throughout: a 5x5 Planar8/PlanarF src, all background (50), with
// a single asymmetric spike at src[1][3] (row 1, col 3 -- deliberately off both
// the center and any axis of symmetry). dest is a 3x3 tile positioned at
// srcOffsetToROI_X/Y = 1 with a 3x3 all-zero kernel (radius 1), so every dest
// pixel's neighborhood (src[dy-1..dy+1][dx-1..dx+1]) stays fully inside the 5x5
// src buffer -- no out-of-bounds reads at the tile edges.
//
// With this layout:
//   dest[0][0] (center src[1][1], cols 0-2) does NOT see the spike at col 3.
//   dest[0][1] (center src[1][2], cols 1-3) DOES see it.
//   dest[2][2] (center src[3][3], rows 2-4) does NOT see it (spike is row 1).
// A dilate/erode swap (Max used where Min was intended or vice versa) would
// flip whether the spike raises or lowers the affected pixels, so this table
// distinguishes the two unambiguously.

fn bufFromBytes(data: []u8, height: usize, width: usize, rowBytes: usize) vImage_Buffer {
    return .{ .data = data.ptr, .height = height, .width = width, .rowBytes = rowBytes };
}

test "dilate Planar8 spreads the MAX value into the kernel neighborhood" {
    var src = [_]u8{50} ** 25; // 5x5, row-major, rowBytes = 5
    src[1 * 5 + 3] = 200; // spike at (row=1, col=3)
    var dest = [_]u8{0} ** 9; // 3x3
    var kernel = [_]u8{0} ** 9; // 3x3 all-zero kernel

    const b_src = bufFromBytes(&src, 5, 5, 5);
    const b_dest = bufFromBytes(&dest, 3, 3, 3);

    const err = dilate(Pixel_8, &b_src, &b_dest, 1, 1, &kernel, 3, 3, 0);
    try std.testing.expectEqual(@as(vImage_Error, 0), err);

    // dest is row-major 3x3: dest[dy*3+dx].
    try std.testing.expectEqual(@as(u8, 50), dest[0 * 3 + 0]); // no spike in view
    try std.testing.expectEqual(@as(u8, 200), dest[0 * 3 + 1]); // spike in view -> MAX raised it
    try std.testing.expectEqual(@as(u8, 50), dest[2 * 3 + 2]); // spike out of view (different row)
}

test "erode Planar8 spreads the MIN value into the kernel neighborhood" {
    var src = [_]u8{50} ** 25;
    src[1 * 5 + 3] = 10; // dark spike at (row=1, col=3)
    var dest = [_]u8{0} ** 9;
    var kernel = [_]u8{0} ** 9;

    const b_src = bufFromBytes(&src, 5, 5, 5);
    const b_dest = bufFromBytes(&dest, 3, 3, 3);

    const err = erode(Pixel_8, &b_src, &b_dest, 1, 1, &kernel, 3, 3, 0);
    try std.testing.expectEqual(@as(vImage_Error, 0), err);

    try std.testing.expectEqual(@as(u8, 50), dest[0 * 3 + 0]); // no spike in view
    try std.testing.expectEqual(@as(u8, 10), dest[0 * 3 + 1]); // spike in view -> MIN lowered it
    try std.testing.expectEqual(@as(u8, 50), dest[2 * 3 + 2]); // spike out of view
}

test "dilate PlanarF spreads MAX, erode PlanarF spreads MIN (not swapped)" {
    var src_hi = [_]f32{1.0} ** 25;
    src_hi[1 * 5 + 3] = 9.0; // bright spike
    var src_lo = [_]f32{1.0} ** 25;
    src_lo[1 * 5 + 3] = -9.0; // dark spike
    var dest_hi = [_]f32{0} ** 9;
    var dest_lo = [_]f32{0} ** 9;
    var kernel = [_]f32{0} ** 9;
    const rb_src = 5 * @sizeOf(f32);
    const rb_dest = 3 * @sizeOf(f32);

    const b_src_hi = bufFromBytes(std.mem.sliceAsBytes(&src_hi), 5, 5, rb_src);
    const b_dest_hi = bufFromBytes(std.mem.sliceAsBytes(&dest_hi), 3, 3, rb_dest);
    const err1 = dilate(Pixel_F, &b_src_hi, &b_dest_hi, 1, 1, &kernel, 3, 3, 0);
    try std.testing.expectEqual(@as(vImage_Error, 0), err1);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), dest_hi[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), dest_hi[1], 0.001);

    const b_src_lo = bufFromBytes(std.mem.sliceAsBytes(&src_lo), 5, 5, rb_src);
    const b_dest_lo = bufFromBytes(std.mem.sliceAsBytes(&dest_lo), 3, 3, rb_dest);
    const err2 = erode(Pixel_F, &b_src_lo, &b_dest_lo, 1, 1, &kernel, 3, 3, 0);
    try std.testing.expectEqual(@as(vImage_Error, 0), err2);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), dest_lo[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -9.0), dest_lo[1], 0.001);
}

test "dilate/erode ARGB8888 apply per-channel MAX/MIN independently, alpha-first" {
    // Same 5x5 spike layout, replicated across 4 channels with distinct base
    // offsets so a channel-mixing bug (e.g. reading R's spike into G) would be
    // visible. kvImageLeaveAlphaUnchanged is NOT passed, so alpha also
    // participates in the dilate/erode like any other channel.
    const h = 5;
    const w = 5;
    const row_bytes = w * 4;
    var src: [h * row_bytes]u8 = undefined;
    for (0..h) |y| {
        for (0..w) |x| {
            const off = y * row_bytes + x * 4;
            const spike = (y == 1 and x == 3);
            src[off + 0] = if (spike) 210 else 40; // A
            src[off + 1] = if (spike) 220 else 50; // R
            src[off + 2] = if (spike) 230 else 60; // G
            src[off + 3] = if (spike) 240 else 70; // B
        }
    }
    var dest: [3 * 3 * 4]u8 = undefined;
    var kernel = [_]u8{0} ** 9;
    const b_src = bufFromBytes(&src, h, w, row_bytes);
    const b_dest = bufFromBytes(&dest, 3, 3, 12);

    const err = dilate(Pixel_8888, &b_src, &b_dest, 1, 1, &kernel, 3, 3, 0);
    try std.testing.expectEqual(@as(vImage_Error, 0), err);

    // dest[0][1] (dx=1,dy=0) sees the spike; dest[0][0] does not.
    const off_hit = 0 * 12 + 1 * 4;
    const off_miss = 0 * 12 + 0 * 4;
    try std.testing.expectEqual(@as(u8, 210), dest[off_hit + 0]);
    try std.testing.expectEqual(@as(u8, 220), dest[off_hit + 1]);
    try std.testing.expectEqual(@as(u8, 230), dest[off_hit + 2]);
    try std.testing.expectEqual(@as(u8, 240), dest[off_hit + 3]);
    try std.testing.expectEqual(@as(u8, 40), dest[off_miss + 0]);
    try std.testing.expectEqual(@as(u8, 50), dest[off_miss + 1]);
    try std.testing.expectEqual(@as(u8, 60), dest[off_miss + 2]);
    try std.testing.expectEqual(@as(u8, 70), dest[off_miss + 3]);
}

test "max (rectangular fast path) matches dilate with an equivalent all-zero kernel" {
    // Morphology.h:719-724 (vImageMax_Planar8): "Min is a special case for an
    // Erode function with a rectangular kernel that contains all the same
    // value. Max is a special case for a Dilate function with a rectangular
    // kernel that contains all the same value." Cross-check vImageMax_Planar8
    // against vImageDilate_Planar8 with an explicit all-zero 3x3 kernel on the
    // same input -- they must agree pixel-for-pixel.
    var src = [_]u8{50} ** 25;
    src[1 * 5 + 3] = 200;
    var dest_max = [_]u8{0} ** 9;
    var dest_dilate = [_]u8{0} ** 9;
    var kernel = [_]u8{0} ** 9;

    const b_src1 = bufFromBytes(&src, 5, 5, 5);
    const b_dest_max = bufFromBytes(&dest_max, 3, 3, 3);
    const err1 = max(Pixel_8, &b_src1, &b_dest_max, null, 1, 1, 3, 3, 0);
    try std.testing.expectEqual(@as(vImage_Error, 0), err1);

    const b_src2 = bufFromBytes(&src, 5, 5, 5);
    const b_dest_dilate = bufFromBytes(&dest_dilate, 3, 3, 3);
    const err2 = dilate(Pixel_8, &b_src2, &b_dest_dilate, 1, 1, &kernel, 3, 3, 0);
    try std.testing.expectEqual(@as(vImage_Error, 0), err2);

    try std.testing.expectEqualSlices(u8, &dest_dilate, &dest_max);
}

test "min (rectangular fast path) matches erode with an equivalent all-zero kernel" {
    var src = [_]u8{50} ** 25;
    src[1 * 5 + 3] = 10;
    var dest_min = [_]u8{0} ** 9;
    var dest_erode = [_]u8{0} ** 9;
    var kernel = [_]u8{0} ** 9;

    const b_src1 = bufFromBytes(&src, 5, 5, 5);
    const b_dest_min = bufFromBytes(&dest_min, 3, 3, 3);
    const err1 = min(Pixel_8, &b_src1, &b_dest_min, null, 1, 1, 3, 3, 0);
    try std.testing.expectEqual(@as(vImage_Error, 0), err1);

    const b_src2 = bufFromBytes(&src, 5, 5, 5);
    const b_dest_erode = bufFromBytes(&dest_erode, 3, 3, 3);
    const err2 = erode(Pixel_8, &b_src2, &b_dest_erode, 1, 1, &kernel, 3, 3, 0);
    try std.testing.expectEqual(@as(vImage_Error, 0), err2);

    try std.testing.expectEqualSlices(u8, &dest_erode, &dest_min);
}

test "max/min PlanarF rectangular fast path" {
    var src_hi = [_]f32{1.0} ** 25;
    src_hi[1 * 5 + 3] = 9.0;
    var src_lo = [_]f32{1.0} ** 25;
    src_lo[1 * 5 + 3] = -9.0;
    var dest_max = [_]f32{0} ** 9;
    var dest_min = [_]f32{0} ** 9;
    const rb_src = 5 * @sizeOf(f32);
    const rb_dest = 3 * @sizeOf(f32);

    const b_src_hi = bufFromBytes(std.mem.sliceAsBytes(&src_hi), 5, 5, rb_src);
    const b_dest_max = bufFromBytes(std.mem.sliceAsBytes(&dest_max), 3, 3, rb_dest);
    const err1 = max(Pixel_F, &b_src_hi, &b_dest_max, null, 1, 1, 3, 3, 0);
    try std.testing.expectEqual(@as(vImage_Error, 0), err1);
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), dest_max[1], 0.001);

    const b_src_lo = bufFromBytes(std.mem.sliceAsBytes(&src_lo), 5, 5, rb_src);
    const b_dest_min = bufFromBytes(std.mem.sliceAsBytes(&dest_min), 3, 3, rb_dest);
    const err2 = min(Pixel_F, &b_src_lo, &b_dest_min, null, 1, 1, 3, 3, 0);
    try std.testing.expectEqual(@as(vImage_Error, 0), err2);
    try std.testing.expectApproxEqAbs(@as(f32, -9.0), dest_min[1], 0.001);
}

test "max/min ARGBFFFF rectangular fast path, per-channel" {
    const h = 5;
    const w = 5;
    const row_bytes = w * 4 * @sizeOf(f32);
    var src: [h * w * 4]f32 = undefined;
    for (0..h) |y| {
        for (0..w) |x| {
            const base = (y * w + x) * 4;
            const spike = (y == 1 and x == 3);
            src[base + 0] = if (spike) 21.0 else 4.0;
            src[base + 1] = if (spike) 22.0 else 5.0;
            src[base + 2] = if (spike) 23.0 else 6.0;
            src[base + 3] = if (spike) 24.0 else 7.0;
        }
    }
    var dest: [3 * 3 * 4]f32 = undefined;
    const b_src = bufFromBytes(std.mem.sliceAsBytes(&src), h, w, row_bytes);
    const b_dest = bufFromBytes(std.mem.sliceAsBytes(&dest), 3, 3, 3 * 4 * @sizeOf(f32));

    const err = max(Pixel_FFFF, &b_src, &b_dest, null, 1, 1, 3, 3, 0);
    try std.testing.expectEqual(@as(vImage_Error, 0), err);
    // dest[0][1] (index (0*3+1)*4) sees the spike.
    const hit = (0 * 3 + 1) * 4;
    try std.testing.expectApproxEqAbs(@as(f32, 21.0), dest[hit + 0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 24.0), dest[hit + 3], 0.001);
    // dest[2][2] does not.
    const miss = (2 * 3 + 2) * 4;
    try std.testing.expectApproxEqAbs(@as(f32, 4.0), dest[miss + 0], 0.001);
}
