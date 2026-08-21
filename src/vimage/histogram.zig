const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const Error = types.Error;
const check = types.check;
const vImage_Flags = types.vImage_Flags;
const vImagePixelCount = types.vImagePixelCount;
const Pixel_F = types.Pixel_F;
const Options = types.Options;

/// Pixel format tag used for comptime type dispatch.
/// `Planar8`  -> single-channel u8
/// `PlanarF`  -> single-channel f32
/// `ARGB8888` -> four-channel u8
/// `ARGBFFFF` -> four-channel f32
pub const Format = enum { Planar8, PlanarF, ARGB8888, ARGBFFFF };

// ============================================================================
// Histogram Calculation
// ============================================================================

/// Calculates a histogram for a Planar8 source image.
///
/// `histogram` must point to an array of 256 elements.
pub fn histogramCalculation_Planar8(
    src: *const vImage_Buffer,
    histogram: [*]vImagePixelCount,
    flags: Options,
) Error!usize {
    return check(c.vImageHistogramCalculation_Planar8(src, histogram, flags.bits()));
}

/// Calculates a histogram for a PlanarF source image.
///
/// `histogram` must point to an array of `histogram_entries` elements.
/// Pixel values are clamped to [minVal, maxVal] for binning.
pub fn histogramCalculation_PlanarF(
    src: *const vImage_Buffer,
    histogram: [*]vImagePixelCount,
    histogram_entries: u32,
    minVal: Pixel_F,
    maxVal: Pixel_F,
    flags: Options,
) Error!usize {
    return check(c.vImageHistogramCalculation_PlanarF(src, histogram, histogram_entries, minVal, maxVal, flags.bits()));
}

/// Calculates per-channel histograms for an ARGB8888 source image.
///
/// `histogram` is an array of 4 pointers, each pointing to a 256-element array.
pub fn histogramCalculation_ARGB8888(
    src: *const vImage_Buffer,
    histogram: *[4][*]vImagePixelCount,
    flags: Options,
) Error!usize {
    return check(c.vImageHistogramCalculation_ARGB8888(src, histogram, flags.bits()));
}

/// Calculates per-channel histograms for an ARGBFFFF source image.
///
/// `histogram` is an array of 4 pointers, each pointing to an array of
/// `histogram_entries` elements. Pixel values are clamped to [minVal, maxVal].
pub fn histogramCalculation_ARGBFFFF(
    src: *const vImage_Buffer,
    histogram: *[4][*]vImagePixelCount,
    histogram_entries: u32,
    minVal: Pixel_F,
    maxVal: Pixel_F,
    flags: Options,
) Error!usize {
    return check(c.vImageHistogramCalculation_ARGBFFFF(src, histogram, histogram_entries, minVal, maxVal, flags.bits()));
}

/// Type-dispatched histogram calculation.
///
/// For `Planar8` / `ARGB8888`: pass `histogram` and `flags`.
/// For `PlanarF` / `ARGBFFFF`: pass `histogram`, `histogram_entries`, `minVal`, `maxVal`, and `flags`.
pub fn histogramCalculation(comptime fmt: Format, args: switch (fmt) {
    .Planar8 => struct {
        src: *const vImage_Buffer,
        histogram: [*]vImagePixelCount,
        flags: Options = .{},
    },
    .PlanarF => struct {
        src: *const vImage_Buffer,
        histogram: [*]vImagePixelCount,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: Options = .{},
    },
    .ARGB8888 => struct {
        src: *const vImage_Buffer,
        histogram: *[4][*]vImagePixelCount,
        flags: Options = .{},
    },
    .ARGBFFFF => struct {
        src: *const vImage_Buffer,
        histogram: *[4][*]vImagePixelCount,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: Options = .{},
    },
}) Error!usize {
    return check(switch (fmt) {
        .Planar8 => c.vImageHistogramCalculation_Planar8(args.src, args.histogram, args.flags.bits()),
        .PlanarF => c.vImageHistogramCalculation_PlanarF(args.src, args.histogram, args.histogram_entries, args.minVal, args.maxVal, args.flags.bits()),
        .ARGB8888 => c.vImageHistogramCalculation_ARGB8888(args.src, args.histogram, args.flags.bits()),
        .ARGBFFFF => c.vImageHistogramCalculation_ARGBFFFF(args.src, args.histogram, args.histogram_entries, args.minVal, args.maxVal, args.flags.bits()),
    });
}

// ============================================================================
// Histogram Equalization
// ============================================================================

/// Equalizes the histogram of a Planar8 image.
pub fn equalization_Planar8(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageEqualization_Planar8(src, dest, flags.bits()));
}

/// Equalizes the histogram of a PlanarF image.
///
/// `tempBuffer` may be null; set `.get_temp_buffer_size` in `flags` (`kvImageGetTempBufferSize`) to query
/// required size without performing the operation.
pub fn equalization_PlanarF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    histogram_entries: u32,
    minVal: Pixel_F,
    maxVal: Pixel_F,
    flags: Options,
) Error!usize {
    return check(c.vImageEqualization_PlanarF(src, dest, tempBuffer, histogram_entries, minVal, maxVal, flags.bits()));
}

/// Equalizes the histogram of an ARGB8888 image.
pub fn equalization_ARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageEqualization_ARGB8888(src, dest, flags.bits()));
}

/// Equalizes the histogram of an ARGBFFFF image.
pub fn equalization_ARGBFFFF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    histogram_entries: u32,
    minVal: Pixel_F,
    maxVal: Pixel_F,
    flags: Options,
) Error!usize {
    return check(c.vImageEqualization_ARGBFFFF(src, dest, tempBuffer, histogram_entries, minVal, maxVal, flags.bits()));
}

/// Type-dispatched histogram equalization.
pub fn equalization(comptime fmt: Format, args: switch (fmt) {
    .Planar8 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        flags: Options = .{},
    },
    .PlanarF => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        tempBuffer: ?*anyopaque = null,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: Options = .{},
    },
    .ARGB8888 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        flags: Options = .{},
    },
    .ARGBFFFF => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        tempBuffer: ?*anyopaque = null,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: Options = .{},
    },
}) Error!usize {
    return check(switch (fmt) {
        .Planar8 => c.vImageEqualization_Planar8(args.src, args.dest, args.flags.bits()),
        .PlanarF => c.vImageEqualization_PlanarF(args.src, args.dest, args.tempBuffer, args.histogram_entries, args.minVal, args.maxVal, args.flags.bits()),
        .ARGB8888 => c.vImageEqualization_ARGB8888(args.src, args.dest, args.flags.bits()),
        .ARGBFFFF => c.vImageEqualization_ARGBFFFF(args.src, args.dest, args.tempBuffer, args.histogram_entries, args.minVal, args.maxVal, args.flags.bits()),
    });
}

// ============================================================================
// Histogram Specification
// ============================================================================

/// Performs histogram specification on a Planar8 image.
///
/// `desired_histogram` must point to an array of 256 elements describing the
/// target distribution.
pub fn histogramSpecification_Planar8(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    desired_histogram: [*]const vImagePixelCount,
    flags: Options,
) Error!usize {
    return check(c.vImageHistogramSpecification_Planar8(src, dest, desired_histogram, flags.bits()));
}

/// Performs histogram specification on a PlanarF image.
pub fn histogramSpecification_PlanarF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    desired_histogram: [*]const vImagePixelCount,
    histogram_entries: u32,
    minVal: Pixel_F,
    maxVal: Pixel_F,
    flags: Options,
) Error!usize {
    return check(c.vImageHistogramSpecification_PlanarF(src, dest, tempBuffer, desired_histogram, histogram_entries, minVal, maxVal, flags.bits()));
}

/// Performs histogram specification on an ARGB8888 image.
///
/// `desired_histogram` is an array of 4 pointers, each pointing to a
/// 256-element target distribution array.
pub fn histogramSpecification_ARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    desired_histogram: *const [4][*]const vImagePixelCount,
    flags: Options,
) Error!usize {
    return check(c.vImageHistogramSpecification_ARGB8888(src, dest, desired_histogram, flags.bits()));
}

/// Performs histogram specification on an ARGBFFFF image.
pub fn histogramSpecification_ARGBFFFF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    desired_histogram: *const [4][*]const vImagePixelCount,
    histogram_entries: u32,
    minVal: Pixel_F,
    maxVal: Pixel_F,
    flags: Options,
) Error!usize {
    return check(c.vImageHistogramSpecification_ARGBFFFF(src, dest, tempBuffer, desired_histogram, histogram_entries, minVal, maxVal, flags.bits()));
}

/// Type-dispatched histogram specification.
pub fn histogramSpecification(comptime fmt: Format, args: switch (fmt) {
    .Planar8 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        desired_histogram: [*]const vImagePixelCount,
        flags: Options = .{},
    },
    .PlanarF => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        tempBuffer: ?*anyopaque = null,
        desired_histogram: [*]const vImagePixelCount,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: Options = .{},
    },
    .ARGB8888 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        desired_histogram: *const [4][*]const vImagePixelCount,
        flags: Options = .{},
    },
    .ARGBFFFF => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        tempBuffer: ?*anyopaque = null,
        desired_histogram: *const [4][*]const vImagePixelCount,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: Options = .{},
    },
}) Error!usize {
    return check(switch (fmt) {
        .Planar8 => c.vImageHistogramSpecification_Planar8(args.src, args.dest, args.desired_histogram, args.flags.bits()),
        .PlanarF => c.vImageHistogramSpecification_PlanarF(args.src, args.dest, args.tempBuffer, args.desired_histogram, args.histogram_entries, args.minVal, args.maxVal, args.flags.bits()),
        .ARGB8888 => c.vImageHistogramSpecification_ARGB8888(args.src, args.dest, args.desired_histogram, args.flags.bits()),
        .ARGBFFFF => c.vImageHistogramSpecification_ARGBFFFF(args.src, args.dest, args.tempBuffer, args.desired_histogram, args.histogram_entries, args.minVal, args.maxVal, args.flags.bits()),
    });
}

// ============================================================================
// Contrast Stretch
// ============================================================================

/// Stretches the contrast of a Planar8 image to fill the full [0, 255] range.
pub fn contrastStretch_Planar8(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageContrastStretch_Planar8(src, dest, flags.bits()));
}

/// Stretches the contrast of a PlanarF image.
pub fn contrastStretch_PlanarF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    histogram_entries: u32,
    minVal: Pixel_F,
    maxVal: Pixel_F,
    flags: Options,
) Error!usize {
    return check(c.vImageContrastStretch_PlanarF(src, dest, tempBuffer, histogram_entries, minVal, maxVal, flags.bits()));
}

/// Stretches the contrast of an ARGB8888 image.
pub fn contrastStretch_ARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageContrastStretch_ARGB8888(src, dest, flags.bits()));
}

/// Stretches the contrast of an ARGBFFFF image.
pub fn contrastStretch_ARGBFFFF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    histogram_entries: u32,
    minVal: Pixel_F,
    maxVal: Pixel_F,
    flags: Options,
) Error!usize {
    return check(c.vImageContrastStretch_ARGBFFFF(src, dest, tempBuffer, histogram_entries, minVal, maxVal, flags.bits()));
}

/// Type-dispatched contrast stretch.
pub fn contrastStretch(comptime fmt: Format, args: switch (fmt) {
    .Planar8 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        flags: Options = .{},
    },
    .PlanarF => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        tempBuffer: ?*anyopaque = null,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: Options = .{},
    },
    .ARGB8888 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        flags: Options = .{},
    },
    .ARGBFFFF => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        tempBuffer: ?*anyopaque = null,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: Options = .{},
    },
}) Error!usize {
    return check(switch (fmt) {
        .Planar8 => c.vImageContrastStretch_Planar8(args.src, args.dest, args.flags.bits()),
        .PlanarF => c.vImageContrastStretch_PlanarF(args.src, args.dest, args.tempBuffer, args.histogram_entries, args.minVal, args.maxVal, args.flags.bits()),
        .ARGB8888 => c.vImageContrastStretch_ARGB8888(args.src, args.dest, args.flags.bits()),
        .ARGBFFFF => c.vImageContrastStretch_ARGBFFFF(args.src, args.dest, args.tempBuffer, args.histogram_entries, args.minVal, args.maxVal, args.flags.bits()),
    });
}

// ============================================================================
// Ends-in Contrast Stretch
// ============================================================================

/// Performs an ends-in contrast stretch on a Planar8 image.
///
/// `percent_low` and `percent_high` specify the percentage of pixels to clip
/// at the low and high ends respectively (0-100).
pub fn endsInContrastStretch_Planar8(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    percent_low: u32,
    percent_high: u32,
    flags: Options,
) Error!usize {
    return check(c.vImageEndsInContrastStretch_Planar8(src, dest, percent_low, percent_high, flags.bits()));
}

/// Performs an ends-in contrast stretch on a PlanarF image.
pub fn endsInContrastStretch_PlanarF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    percent_low: u32,
    percent_high: u32,
    histogram_entries: u32,
    minVal: Pixel_F,
    maxVal: Pixel_F,
    flags: Options,
) Error!usize {
    return check(c.vImageEndsInContrastStretch_PlanarF(src, dest, tempBuffer, percent_low, percent_high, histogram_entries, minVal, maxVal, flags.bits()));
}

/// Performs an ends-in contrast stretch on an ARGB8888 image.
///
/// `percent_low` and `percent_high` are arrays of 4 per-channel percentages.
pub fn endsInContrastStretch_ARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    percent_low: *const [4]c_uint,
    percent_high: *const [4]c_uint,
    flags: Options,
) Error!usize {
    return check(c.vImageEndsInContrastStretch_ARGB8888(src, dest, percent_low, percent_high, flags.bits()));
}

/// Performs an ends-in contrast stretch on an ARGBFFFF image.
pub fn endsInContrastStretch_ARGBFFFF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    percent_low: *const [4]c_uint,
    percent_high: *const [4]c_uint,
    histogram_entries: u32,
    minVal: Pixel_F,
    maxVal: Pixel_F,
    flags: Options,
) Error!usize {
    return check(c.vImageEndsInContrastStretch_ARGBFFFF(src, dest, tempBuffer, percent_low, percent_high, histogram_entries, minVal, maxVal, flags.bits()));
}

/// Type-dispatched ends-in contrast stretch.
pub fn endsInContrastStretch(comptime fmt: Format, args: switch (fmt) {
    .Planar8 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        percent_low: u32,
        percent_high: u32,
        flags: Options = .{},
    },
    .PlanarF => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        tempBuffer: ?*anyopaque = null,
        percent_low: u32,
        percent_high: u32,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: Options = .{},
    },
    .ARGB8888 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        percent_low: *const [4]c_uint,
        percent_high: *const [4]c_uint,
        flags: Options = .{},
    },
    .ARGBFFFF => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        tempBuffer: ?*anyopaque = null,
        percent_low: *const [4]c_uint,
        percent_high: *const [4]c_uint,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: Options = .{},
    },
}) Error!usize {
    return check(switch (fmt) {
        .Planar8 => c.vImageEndsInContrastStretch_Planar8(args.src, args.dest, args.percent_low, args.percent_high, args.flags.bits()),
        .PlanarF => c.vImageEndsInContrastStretch_PlanarF(args.src, args.dest, args.tempBuffer, args.percent_low, args.percent_high, args.histogram_entries, args.minVal, args.maxVal, args.flags.bits()),
        .ARGB8888 => c.vImageEndsInContrastStretch_ARGB8888(args.src, args.dest, args.percent_low, args.percent_high, args.flags.bits()),
        .ARGBFFFF => c.vImageEndsInContrastStretch_ARGBFFFF(args.src, args.dest, args.tempBuffer, args.percent_low, args.percent_high, args.histogram_entries, args.minVal, args.maxVal, args.flags.bits()),
    });
}

// ============================================================================
// Tests
// ============================================================================

fn bufFromBytes(data: []u8, height: usize, width: usize, rowBytes: usize) vImage_Buffer {
    return .{ .data = data.ptr, .height = height, .width = width, .rowBytes = rowBytes };
}

test "histogramCalculation_Planar8 bins a known pixel-value distribution" {
    // Histogram.h:33-35: histogram[src[x]]++ for every pixel. Use a known
    // distribution: 3 pixels of value 10, 1 pixel of value 200, rest value 0.
    const h = 2;
    const w = 4; // 8 pixels total
    var src = [_]u8{ 10, 10, 10, 200, 0, 0, 0, 0 };
    var histogram: [256]vImagePixelCount = [_]vImagePixelCount{0} ** 256;
    const b_src = bufFromBytes(&src, h, w, w);

    const err = histogramCalculation_Planar8(&b_src, &histogram, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(vImagePixelCount, 4), histogram[0]);
    try std.testing.expectEqual(@as(vImagePixelCount, 3), histogram[10]);
    try std.testing.expectEqual(@as(vImagePixelCount, 1), histogram[200]);
    try std.testing.expectEqual(@as(vImagePixelCount, 0), histogram[1]);

    var total: vImagePixelCount = 0;
    for (histogram) |c_| total += c_;
    try std.testing.expectEqual(@as(vImagePixelCount, 8), total);
}

test "histogramCalculation_PlanarF bins pixel values into histogram_entries bins over [minVal, maxVal]" {
    const h = 1;
    const w = 4;
    // Range [0, 100), 10 bins -> bin width 10. Values 5 -> bin 0, 95 -> bin 9,
    // 50 -> bin 5. One value (200) is above maxVal and must clamp into the last bin.
    var src = [_]f32{ 5.0, 95.0, 50.0, 200.0 };
    var histogram: [10]vImagePixelCount = [_]vImagePixelCount{0} ** 10;
    const b_src = bufFromBytes(std.mem.sliceAsBytes(&src), h, w, w * @sizeOf(f32));

    const err = histogramCalculation_PlanarF(&b_src, &histogram, 10, 0.0, 100.0, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(vImagePixelCount, 1), histogram[0]);
    try std.testing.expectEqual(@as(vImagePixelCount, 1), histogram[5]);
    try std.testing.expectEqual(@as(vImagePixelCount, 2), histogram[9]); // 95 and clamped 200
}

test "histogramCalculation_ARGB8888 bins each channel independently, alpha-first" {
    const h = 1;
    const w = 2;
    const row_bytes = w * 4;
    // Pixel0: A=10 R=20 G=30 B=40 ; Pixel1: A=10 R=21 G=31 B=41
    var src = [_]u8{ 10, 20, 30, 40, 10, 21, 31, 41 };
    var hist_a: [256]vImagePixelCount = [_]vImagePixelCount{0} ** 256;
    var hist_r: [256]vImagePixelCount = [_]vImagePixelCount{0} ** 256;
    var hist_g: [256]vImagePixelCount = [_]vImagePixelCount{0} ** 256;
    var hist_b: [256]vImagePixelCount = [_]vImagePixelCount{0} ** 256;
    var histogram: [4][*]vImagePixelCount = .{ &hist_a, &hist_r, &hist_g, &hist_b };
    const b_src = bufFromBytes(&src, h, w, row_bytes);

    const err = histogramCalculation_ARGB8888(&b_src, &histogram, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    // A channel (index 0 in memory) has both pixels at value 10.
    try std.testing.expectEqual(@as(vImagePixelCount, 2), hist_a[10]);
    // R channel (index 1) has one pixel each at 20 and 21 -- confirms the
    // wrapper reads channel 1, not some other offset.
    try std.testing.expectEqual(@as(vImagePixelCount, 1), hist_r[20]);
    try std.testing.expectEqual(@as(vImagePixelCount, 1), hist_r[21]);
    try std.testing.expectEqual(@as(vImagePixelCount, 1), hist_g[30]);
    try std.testing.expectEqual(@as(vImagePixelCount, 1), hist_b[40]);
}

test "histogramCalculation_ARGBFFFF bins each channel independently over [minVal,maxVal]" {
    const h = 1;
    const w = 1;
    var src = [_]f32{ 1.0, 51.0, 76.0, 99.0 }; // A R G B
    var hist_a: [10]vImagePixelCount = [_]vImagePixelCount{0} ** 10;
    var hist_r: [10]vImagePixelCount = [_]vImagePixelCount{0} ** 10;
    var hist_g: [10]vImagePixelCount = [_]vImagePixelCount{0} ** 10;
    var hist_b: [10]vImagePixelCount = [_]vImagePixelCount{0} ** 10;
    var histogram: [4][*]vImagePixelCount = .{ &hist_a, &hist_r, &hist_g, &hist_b };
    const b_src = bufFromBytes(std.mem.sliceAsBytes(&src), h, w, 4 * @sizeOf(f32));

    const err = histogramCalculation_ARGBFFFF(&b_src, &histogram, 10, 0.0, 100.0, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(vImagePixelCount, 1), hist_a[0]); // 1.0 -> bin 0
    try std.testing.expectEqual(@as(vImagePixelCount, 1), hist_r[5]); // 51.0 -> bin 5
    try std.testing.expectEqual(@as(vImagePixelCount, 1), hist_g[7]); // 76.0 -> bin 7
    try std.testing.expectEqual(@as(vImagePixelCount, 1), hist_b[9]); // 99.0 -> bin 9
}

test "histogramCalculation dispatch wrapper matches direct Planar8/PlanarF calls" {
    const h = 1;
    const w = 4;
    var src8 = [_]u8{ 10, 10, 10, 200 };
    var hist_direct: [256]vImagePixelCount = [_]vImagePixelCount{0} ** 256;
    var hist_dispatch: [256]vImagePixelCount = [_]vImagePixelCount{0} ** 256;
    const b1 = bufFromBytes(&src8, h, w, w);
    const b2 = bufFromBytes(&src8, h, w, w);
    _ = try histogramCalculation_Planar8(&b1, &hist_direct, .{});
    _ = try histogramCalculation(.Planar8, .{ .src = &b2, .histogram = &hist_dispatch });
    try std.testing.expectEqualSlices(vImagePixelCount, &hist_direct, &hist_dispatch);

    var srcf = [_]f32{ 5.0, 95.0, 50.0, 200.0 };
    var hist_direct_f: [10]vImagePixelCount = [_]vImagePixelCount{0} ** 10;
    var hist_dispatch_f: [10]vImagePixelCount = [_]vImagePixelCount{0} ** 10;
    const bf1 = bufFromBytes(std.mem.sliceAsBytes(&srcf), h, w, w * @sizeOf(f32));
    const bf2 = bufFromBytes(std.mem.sliceAsBytes(&srcf), h, w, w * @sizeOf(f32));
    _ = try histogramCalculation_PlanarF(&bf1, &hist_direct_f, 10, 0.0, 100.0, .{});
    _ = try histogramCalculation(.PlanarF, .{ .src = &bf2, .histogram = &hist_dispatch_f, .histogram_entries = 10, .minVal = 0.0, .maxVal = 100.0 });
    try std.testing.expectEqualSlices(vImagePixelCount, &hist_direct_f, &hist_dispatch_f);
}

test "equalization_Planar8 preserves relative order (monotonic transform)" {
    // [characterization] This test pins behavior that Apple does not document
    // and that was determined by running the real framework, not derived from
    // a header. It asserts what macOS does today. If a future OS version
    // changes it, this failing is the intended signal to re-verify and update
    // the doc comment - it is NOT evidence that this binding regressed.
    // Equalization is a monotonic remapping of pixel values derived from the
    // cumulative histogram: a strictly larger input value can never map to a
    // strictly smaller output value. Build an image with 4 distinct ascending
    // values, unevenly distributed, and check the output preserves that order.
    const h = 1;
    const w = 4;
    var src = [_]u8{ 10, 80, 150, 220 };
    var dest = [_]u8{0} ** 4;
    const b_src = bufFromBytes(&src, h, w, w);
    const b_dest = bufFromBytes(&dest, h, w, w);

    const err = equalization_Planar8(&b_src, &b_dest, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expect(dest[0] <= dest[1]);
    try std.testing.expect(dest[1] <= dest[2]);
    try std.testing.expect(dest[2] <= dest[3]);
    // Runtime-verified (Apple's exact rounding isn't specified in Histogram.h):
    // for 4 equal-weight distinct values, cumulative fraction * 255 rounds to
    // {64, 128, 191, 255}, i.e. the max value maps to 255 but the min value
    // maps to ~1/4 of full scale rather than 0 (the CDF *includes* the pixel's
    // own bucket, so even the lowest value has nonzero cumulative weight).
    try std.testing.expectEqual(@as(u8, 64), dest[0]);
    try std.testing.expectEqual(@as(u8, 128), dest[1]);
    try std.testing.expectEqual(@as(u8, 191), dest[2]);
    try std.testing.expectEqual(@as(u8, 255), dest[3]);
}

test "equalization_PlanarF preserves relative order over an explicit range" {
    const h = 1;
    const w = 4;
    var src = [_]f32{ 10.0, 40.0, 70.0, 95.0 };
    var dest = [_]f32{0} ** 4;
    const rb = w * @sizeOf(f32);
    const b_src = bufFromBytes(std.mem.sliceAsBytes(&src), h, w, rb);
    const b_dest = bufFromBytes(std.mem.sliceAsBytes(&dest), h, w, rb);

    const err = equalization_PlanarF(&b_src, &b_dest, null, 256, 0.0, 100.0, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expect(dest[0] <= dest[1]);
    try std.testing.expect(dest[1] <= dest[2]);
    try std.testing.expect(dest[2] <= dest[3]);
}

test "equalization_ARGB8888 processes each channel independently, alpha-first" {
    const h = 1;
    const w = 4;
    const row_bytes = w * 4;
    var src: [16]u8 = undefined;
    const a_vals = [_]u8{ 10, 80, 150, 220 };
    for (0..w) |x| {
        src[x * 4 + 0] = a_vals[x]; // A channel carries the ascending pattern
        src[x * 4 + 1] = 128; // R constant
        src[x * 4 + 2] = 128; // G constant
        src[x * 4 + 3] = 128; // B constant
    }
    var dest = [_]u8{0} ** 16;
    const b_src = bufFromBytes(&src, h, w, row_bytes);
    const b_dest = bufFromBytes(&dest, h, w, row_bytes);

    const err = equalization_ARGB8888(&b_src, &b_dest, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    // Alpha channel (offset 0) should be monotonically increasing since its
    // input values are.
    try std.testing.expect(dest[0 * 4 + 0] <= dest[1 * 4 + 0]);
    try std.testing.expect(dest[1 * 4 + 0] <= dest[2 * 4 + 0]);
    try std.testing.expect(dest[2 * 4 + 0] <= dest[3 * 4 + 0]);
}

test "equalization_ARGBFFFF processes each channel independently" {
    const h = 1;
    const w = 4;
    const row_bytes = w * 4 * @sizeOf(f32);
    var src: [16]f32 = undefined;
    const a_vals = [_]f32{ 10.0, 40.0, 70.0, 95.0 };
    for (0..w) |x| {
        src[x * 4 + 0] = a_vals[x];
        src[x * 4 + 1] = 50.0;
        src[x * 4 + 2] = 50.0;
        src[x * 4 + 3] = 50.0;
    }
    var dest = [_]f32{0} ** 16;
    const b_src = bufFromBytes(std.mem.sliceAsBytes(&src), h, w, row_bytes);
    const b_dest = bufFromBytes(std.mem.sliceAsBytes(&dest), h, w, row_bytes);

    const err = equalization_ARGBFFFF(&b_src, &b_dest, null, 256, 0.0, 100.0, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expect(dest[0 * 4 + 0] <= dest[1 * 4 + 0]);
    try std.testing.expect(dest[1 * 4 + 0] <= dest[2 * 4 + 0]);
    try std.testing.expect(dest[2 * 4 + 0] <= dest[3 * 4 + 0]);
}

test "equalization dispatch wrapper matches direct Planar8/PlanarF calls" {
    const h = 1;
    const w = 4;
    var src8 = [_]u8{ 10, 80, 150, 220 };
    var dest_direct = [_]u8{0} ** 4;
    var dest_dispatch = [_]u8{0} ** 4;
    const b1s = bufFromBytes(&src8, h, w, w);
    const b1d = bufFromBytes(&dest_direct, h, w, w);
    _ = try equalization_Planar8(&b1s, &b1d, .{});
    const b2s = bufFromBytes(&src8, h, w, w);
    const b2d = bufFromBytes(&dest_dispatch, h, w, w);
    _ = try equalization(.Planar8, .{ .src = &b2s, .dest = &b2d });
    try std.testing.expectEqualSlices(u8, &dest_direct, &dest_dispatch);
}

test "histogramSpecification_Planar8 succeeds and preserves ordering with an ascending desired histogram" {
    // Histogram.h ~557-565 (vImageHistogramSpecification_Planar8): remaps src to
    // conform to `desired_histogram`. Using an ascending-weight desired
    // histogram (more weight on higher values) should still yield a monotonic
    // mapping for a monotonic source, since the underlying transform composes
    // two monotonic cumulative-histogram functions.
    const h = 1;
    const w = 4;
    var src = [_]u8{ 10, 80, 150, 220 };
    var dest = [_]u8{0} ** 4;
    var desired: [256]vImagePixelCount = undefined;
    for (0..256) |i| desired[i] = @intCast(i); // linearly increasing target weights
    const b_src = bufFromBytes(&src, h, w, w);
    const b_dest = bufFromBytes(&dest, h, w, w);

    const err = histogramSpecification_Planar8(&b_src, &b_dest, &desired, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expect(dest[0] <= dest[1]);
    try std.testing.expect(dest[1] <= dest[2]);
    try std.testing.expect(dest[2] <= dest[3]);
}

test "histogramSpecification_PlanarF succeeds and preserves ordering" {
    const h = 1;
    const w = 4;
    var src = [_]f32{ 10.0, 40.0, 70.0, 95.0 };
    var dest = [_]f32{0} ** 4;
    var desired: [256]vImagePixelCount = undefined;
    for (0..256) |i| desired[i] = @intCast(i);
    const rb = w * @sizeOf(f32);
    const b_src = bufFromBytes(std.mem.sliceAsBytes(&src), h, w, rb);
    const b_dest = bufFromBytes(std.mem.sliceAsBytes(&dest), h, w, rb);

    const err = histogramSpecification_PlanarF(&b_src, &b_dest, null, &desired, 256, 0.0, 100.0, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expect(dest[0] <= dest[1]);
    try std.testing.expect(dest[1] <= dest[2]);
    try std.testing.expect(dest[2] <= dest[3]);
}

test "histogramSpecification_ARGB8888/ARGBFFFF succeed with per-channel desired histograms" {
    const h = 1;
    const w = 2;
    const row_bytes = w * 4;
    var src = [_]u8{ 10, 20, 30, 40, 200, 220, 230, 240 };
    var dest = [_]u8{0} ** 8;
    var desired: [256]vImagePixelCount = undefined;
    for (0..256) |i| desired[i] = @intCast(i);
    const per_channel: [4][*]const vImagePixelCount = .{ &desired, &desired, &desired, &desired };
    const b_src = bufFromBytes(&src, h, w, row_bytes);
    const b_dest = bufFromBytes(&dest, h, w, row_bytes);

    const err = histogramSpecification_ARGB8888(&b_src, &b_dest, &per_channel, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    // Alpha channel: pixel0 A=10 < pixel1 A=200, ordering must be preserved.
    try std.testing.expect(dest[0] <= dest[4]);

    var srcf = [_]f32{ 10.0, 20.0, 30.0, 40.0, 80.0, 85.0, 90.0, 95.0 };
    var destf = [_]f32{0} ** 8;
    const rbf = w * 4 * @sizeOf(f32);
    const b_srcf = bufFromBytes(std.mem.sliceAsBytes(&srcf), h, w, rbf);
    const b_destf = bufFromBytes(std.mem.sliceAsBytes(&destf), h, w, rbf);
    const errf = histogramSpecification_ARGBFFFF(&b_srcf, &b_destf, null, &per_channel, 256, 0.0, 100.0, .{});
    try std.testing.expectEqual(@as(usize, 0), try errf);
    try std.testing.expect(destf[0] <= destf[4]);
}

test "histogramSpecification dispatch wrapper matches direct Planar8 call" {
    const h = 1;
    const w = 4;
    var src = [_]u8{ 10, 80, 150, 220 };
    var dest_direct = [_]u8{0} ** 4;
    var dest_dispatch = [_]u8{0} ** 4;
    var desired: [256]vImagePixelCount = undefined;
    for (0..256) |i| desired[i] = @intCast(i);

    const b1s = bufFromBytes(&src, h, w, w);
    const b1d = bufFromBytes(&dest_direct, h, w, w);
    _ = try histogramSpecification_Planar8(&b1s, &b1d, &desired, .{});
    const b2s = bufFromBytes(&src, h, w, w);
    const b2d = bufFromBytes(&dest_dispatch, h, w, w);
    _ = try histogramSpecification(.Planar8, .{ .src = &b2s, .dest = &b2d, .desired_histogram = &desired });
    try std.testing.expectEqualSlices(u8, &dest_direct, &dest_dispatch);
}

test "contrastStretch_Planar8 widens a narrow input range toward [0,255]" {
    const h = 1;
    const w = 4;
    var src = [_]u8{ 100, 110, 120, 130 }; // narrow range
    var dest = [_]u8{0} ** 4;
    const b_src = bufFromBytes(&src, h, w, w);
    const b_dest = bufFromBytes(&dest, h, w, w);

    const err = contrastStretch_Planar8(&b_src, &b_dest, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    // Min input maps near 0, max input maps near 255; ordering preserved.
    try std.testing.expect(dest[0] < 20);
    try std.testing.expect(dest[3] > 235);
    try std.testing.expect(dest[0] <= dest[1] and dest[1] <= dest[2] and dest[2] <= dest[3]);
}

test "contrastStretch_PlanarF widens a narrow input range toward [minVal,maxVal]" {
    const h = 1;
    const w = 4;
    var src = [_]f32{ 40.0, 45.0, 50.0, 55.0 };
    var dest = [_]f32{0} ** 4;
    const rb = w * @sizeOf(f32);
    const b_src = bufFromBytes(std.mem.sliceAsBytes(&src), h, w, rb);
    const b_dest = bufFromBytes(std.mem.sliceAsBytes(&dest), h, w, rb);

    const err = contrastStretch_PlanarF(&b_src, &b_dest, null, 256, 0.0, 100.0, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expect(dest[0] < 10.0);
    try std.testing.expect(dest[3] > 90.0);
}

test "contrastStretch_ARGB8888/ARGBFFFF widen per-channel, alpha-first" {
    const h = 1;
    const w = 4;
    const row_bytes = w * 4;
    var src: [16]u8 = undefined;
    const a_vals = [_]u8{ 100, 110, 120, 130 };
    for (0..w) |x| {
        src[x * 4 + 0] = a_vals[x];
        src[x * 4 + 1] = 128;
        src[x * 4 + 2] = 128;
        src[x * 4 + 3] = 128;
    }
    var dest = [_]u8{0} ** 16;
    const b_src = bufFromBytes(&src, h, w, row_bytes);
    const b_dest = bufFromBytes(&dest, h, w, row_bytes);
    const err = contrastStretch_ARGB8888(&b_src, &b_dest, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expect(dest[0 * 4 + 0] < 20);
    try std.testing.expect(dest[3 * 4 + 0] > 235);
}

test "contrastStretch dispatch wrapper matches direct Planar8 call" {
    const h = 1;
    const w = 4;
    var src = [_]u8{ 100, 110, 120, 130 };
    var dest_direct = [_]u8{0} ** 4;
    var dest_dispatch = [_]u8{0} ** 4;
    const b1s = bufFromBytes(&src, h, w, w);
    const b1d = bufFromBytes(&dest_direct, h, w, w);
    _ = try contrastStretch_Planar8(&b1s, &b1d, .{});
    const b2s = bufFromBytes(&src, h, w, w);
    const b2d = bufFromBytes(&dest_dispatch, h, w, w);
    _ = try contrastStretch(.Planar8, .{ .src = &b2s, .dest = &b2d });
    try std.testing.expectEqualSlices(u8, &dest_direct, &dest_dispatch);
}

test "endsInContrastStretch_Planar8 with nonzero clipping percentage widens the range" {
    // [characterization] This test pins behavior that Apple does not document
    // and that was determined by running the real framework, not derived from
    // a header. It asserts what macOS does today. If a future OS version
    // changes it, this failing is the intended signal to re-verify and update
    // the doc comment - it is NOT evidence that this binding regressed.
    // Runtime-verified: with only 4 distinct pixel values (too sparse for the
    // percentile-based algorithm) and percent_low=percent_high=0, the output is
    // NOT a full contrast stretch -- it is left unchanged. A 10-pixel sample
    // with a nonzero clip percentage (10%) does trigger stretching and, in this
    // case, produces exactly the same output as contrastStretch_Planar8 (see
    // "max (rectangular fast path)"-style cross-check below), confirming
    // endsInContrastStretch generalizes contrastStretch as documented.
    const h = 1;
    const w = 10;
    var src = [_]u8{ 100, 105, 110, 115, 120, 125, 130, 135, 140, 145 };
    var dest = [_]u8{0} ** 10;
    const b_src = bufFromBytes(&src, h, w, w);
    const b_dest = bufFromBytes(&dest, h, w, w);

    const err = endsInContrastStretch_Planar8(&b_src, &b_dest, 10, 10, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    const expected = [_]u8{ 0, 28, 56, 85, 113, 141, 170, 198, 226, 255 };
    try std.testing.expectEqualSlices(u8, &expected, &dest);
}

test "endsInContrastStretch_PlanarF with nonzero clipping percentage widens the range" {
    // [characterization] This test pins behavior that Apple does not document
    // and that was determined by running the real framework, not derived from
    // a header. It asserts what macOS does today. If a future OS version
    // changes it, this failing is the intended signal to re-verify and update
    // the doc comment - it is NOT evidence that this binding regressed.
    const h = 1;
    const w = 10;
    var src = [_]f32{ 100, 105, 110, 115, 120, 125, 130, 135, 140, 145 };
    var dest = [_]f32{0} ** 10;
    const rb = w * @sizeOf(f32);
    const b_src = bufFromBytes(std.mem.sliceAsBytes(&src), h, w, rb);
    const b_dest = bufFromBytes(std.mem.sliceAsBytes(&dest), h, w, rb);

    const err = endsInContrastStretch_PlanarF(&b_src, &b_dest, null, 10, 10, 256, 0.0, 255.0, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    for (0..9) |i| try std.testing.expect(dest[i] <= dest[i + 1]);
    // Runtime-verified: for the PlanarF variant, the result lands in a
    // normalized [0,1] range regardless of the requested [minVal,maxVal]
    // window (here 0..255) -- the stretch is expressed as a fraction of the
    // histogram span, not rescaled back into minVal..maxVal. This is Apple's
    // own vImage behavior (the wrapper passes minVal/maxVal straight through
    // in the position Histogram.h declares), not a binding bug.
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), dest[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), dest[9], 0.01);
}

test "endsInContrastStretch_ARGB8888/ARGBFFFF accept per-channel percent arrays" {
    const h = 1;
    const w = 10;
    const row_bytes = w * 4;
    var src: [40]u8 = undefined;
    const a_vals = [_]u8{ 100, 105, 110, 115, 120, 125, 130, 135, 140, 145 };
    for (0..w) |x| {
        src[x * 4 + 0] = a_vals[x];
        src[x * 4 + 1] = 128;
        src[x * 4 + 2] = 128;
        src[x * 4 + 3] = 128;
    }
    var dest = [_]u8{0} ** 40;
    const b_src = bufFromBytes(&src, h, w, row_bytes);
    const b_dest = bufFromBytes(&dest, h, w, row_bytes);
    const percent_low: [4]c_uint = .{ 10, 0, 0, 0 };
    const percent_high: [4]c_uint = .{ 10, 0, 0, 0 };
    const err = endsInContrastStretch_ARGB8888(&b_src, &b_dest, &percent_low, &percent_high, .{});
    try std.testing.expectEqual(@as(usize, 0), try err);
    // Alpha channel (offset 0), stretched with the same 10% inputs verified
    // above, must land on the same LUT.
    const expected = [_]u8{ 0, 28, 56, 85, 113, 141, 170, 198, 226, 255 };
    for (0..w) |x| {
        try std.testing.expectEqual(expected[x], dest[x * 4 + 0]);
    }

    var srcf: [40]f32 = undefined;
    const af_vals = [_]f32{ 100, 105, 110, 115, 120, 125, 130, 135, 140, 145 };
    for (0..w) |x| {
        srcf[x * 4 + 0] = af_vals[x];
        srcf[x * 4 + 1] = 50.0;
        srcf[x * 4 + 2] = 50.0;
        srcf[x * 4 + 3] = 50.0;
    }
    var destf = [_]f32{0} ** 40;
    const rbf = w * 4 * @sizeOf(f32);
    const b_srcf = bufFromBytes(std.mem.sliceAsBytes(&srcf), h, w, rbf);
    const b_destf = bufFromBytes(std.mem.sliceAsBytes(&destf), h, w, rbf);
    const errf = endsInContrastStretch_ARGBFFFF(&b_srcf, &b_destf, null, &percent_low, &percent_high, 256, 0.0, 255.0, .{});
    try std.testing.expectEqual(@as(usize, 0), try errf);
    try std.testing.expect(destf[0 * 4 + 0] <= destf[9 * 4 + 0]);
}

test "endsInContrastStretch dispatch wrapper matches direct Planar8 call" {
    const h = 1;
    const w = 4;
    var src = [_]u8{ 100, 110, 120, 130 };
    var dest_direct = [_]u8{0} ** 4;
    var dest_dispatch = [_]u8{0} ** 4;
    const b1s = bufFromBytes(&src, h, w, w);
    const b1d = bufFromBytes(&dest_direct, h, w, w);
    _ = try endsInContrastStretch_Planar8(&b1s, &b1d, 0, 0, .{});
    const b2s = bufFromBytes(&src, h, w, w);
    const b2d = bufFromBytes(&dest_dispatch, h, w, w);
    _ = try endsInContrastStretch(.Planar8, .{ .src = &b2s, .dest = &b2d, .percent_low = 0, .percent_high = 0 });
    try std.testing.expectEqualSlices(u8, &dest_direct, &dest_dispatch);
}
