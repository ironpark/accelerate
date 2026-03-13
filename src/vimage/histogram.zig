const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const vImage_Flags = types.vImage_Flags;
const vImagePixelCount = types.vImagePixelCount;
const Pixel_F = types.Pixel_F;

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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageHistogramCalculation_Planar8(src, histogram, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageHistogramCalculation_PlanarF(src, histogram, histogram_entries, minVal, maxVal, flags);
}

/// Calculates per-channel histograms for an ARGB8888 source image.
///
/// `histogram` is an array of 4 pointers, each pointing to a 256-element array.
pub fn histogramCalculation_ARGB8888(
    src: *const vImage_Buffer,
    histogram: *[4][*]vImagePixelCount,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageHistogramCalculation_ARGB8888(src, histogram, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageHistogramCalculation_ARGBFFFF(src, histogram, histogram_entries, minVal, maxVal, flags);
}

/// Type-dispatched histogram calculation.
///
/// For `Planar8` / `ARGB8888`: pass `histogram` and `flags`.
/// For `PlanarF` / `ARGBFFFF`: pass `histogram`, `histogram_entries`, `minVal`, `maxVal`, and `flags`.
pub fn histogramCalculation(comptime fmt: Format, args: switch (fmt) {
    .Planar8 => struct {
        src: *const vImage_Buffer,
        histogram: [*]vImagePixelCount,
        flags: vImage_Flags = 0,
    },
    .PlanarF => struct {
        src: *const vImage_Buffer,
        histogram: [*]vImagePixelCount,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: vImage_Flags = 0,
    },
    .ARGB8888 => struct {
        src: *const vImage_Buffer,
        histogram: *[4][*]vImagePixelCount,
        flags: vImage_Flags = 0,
    },
    .ARGBFFFF => struct {
        src: *const vImage_Buffer,
        histogram: *[4][*]vImagePixelCount,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: vImage_Flags = 0,
    },
}) vImage_Error {
    return switch (fmt) {
        .Planar8 => c.vImageHistogramCalculation_Planar8(args.src, args.histogram, args.flags),
        .PlanarF => c.vImageHistogramCalculation_PlanarF(args.src, args.histogram, args.histogram_entries, args.minVal, args.maxVal, args.flags),
        .ARGB8888 => c.vImageHistogramCalculation_ARGB8888(args.src, args.histogram, args.flags),
        .ARGBFFFF => c.vImageHistogramCalculation_ARGBFFFF(args.src, args.histogram, args.histogram_entries, args.minVal, args.maxVal, args.flags),
    };
}

// ============================================================================
// Histogram Equalization
// ============================================================================

/// Equalizes the histogram of a Planar8 image.
pub fn equalization_Planar8(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageEqualization_Planar8(src, dest, flags);
}

/// Equalizes the histogram of a PlanarF image.
///
/// `tempBuffer` may be null; pass `kvImageGetTempBufferSize` in flags to query
/// required size without performing the operation.
pub fn equalization_PlanarF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    histogram_entries: u32,
    minVal: Pixel_F,
    maxVal: Pixel_F,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageEqualization_PlanarF(src, dest, tempBuffer, histogram_entries, minVal, maxVal, flags);
}

/// Equalizes the histogram of an ARGB8888 image.
pub fn equalization_ARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageEqualization_ARGB8888(src, dest, flags);
}

/// Equalizes the histogram of an ARGBFFFF image.
pub fn equalization_ARGBFFFF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    histogram_entries: u32,
    minVal: Pixel_F,
    maxVal: Pixel_F,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageEqualization_ARGBFFFF(src, dest, tempBuffer, histogram_entries, minVal, maxVal, flags);
}

/// Type-dispatched histogram equalization.
pub fn equalization(comptime fmt: Format, args: switch (fmt) {
    .Planar8 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        flags: vImage_Flags = 0,
    },
    .PlanarF => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        tempBuffer: ?*anyopaque = null,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: vImage_Flags = 0,
    },
    .ARGB8888 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        flags: vImage_Flags = 0,
    },
    .ARGBFFFF => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        tempBuffer: ?*anyopaque = null,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: vImage_Flags = 0,
    },
}) vImage_Error {
    return switch (fmt) {
        .Planar8 => c.vImageEqualization_Planar8(args.src, args.dest, args.flags),
        .PlanarF => c.vImageEqualization_PlanarF(args.src, args.dest, args.tempBuffer, args.histogram_entries, args.minVal, args.maxVal, args.flags),
        .ARGB8888 => c.vImageEqualization_ARGB8888(args.src, args.dest, args.flags),
        .ARGBFFFF => c.vImageEqualization_ARGBFFFF(args.src, args.dest, args.tempBuffer, args.histogram_entries, args.minVal, args.maxVal, args.flags),
    };
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageHistogramSpecification_Planar8(src, dest, desired_histogram, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageHistogramSpecification_PlanarF(src, dest, tempBuffer, desired_histogram, histogram_entries, minVal, maxVal, flags);
}

/// Performs histogram specification on an ARGB8888 image.
///
/// `desired_histogram` is an array of 4 pointers, each pointing to a
/// 256-element target distribution array.
pub fn histogramSpecification_ARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    desired_histogram: *const [4][*]const vImagePixelCount,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageHistogramSpecification_ARGB8888(src, dest, desired_histogram, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageHistogramSpecification_ARGBFFFF(src, dest, tempBuffer, desired_histogram, histogram_entries, minVal, maxVal, flags);
}

/// Type-dispatched histogram specification.
pub fn histogramSpecification(comptime fmt: Format, args: switch (fmt) {
    .Planar8 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        desired_histogram: [*]const vImagePixelCount,
        flags: vImage_Flags = 0,
    },
    .PlanarF => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        tempBuffer: ?*anyopaque = null,
        desired_histogram: [*]const vImagePixelCount,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: vImage_Flags = 0,
    },
    .ARGB8888 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        desired_histogram: *const [4][*]const vImagePixelCount,
        flags: vImage_Flags = 0,
    },
    .ARGBFFFF => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        tempBuffer: ?*anyopaque = null,
        desired_histogram: *const [4][*]const vImagePixelCount,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: vImage_Flags = 0,
    },
}) vImage_Error {
    return switch (fmt) {
        .Planar8 => c.vImageHistogramSpecification_Planar8(args.src, args.dest, args.desired_histogram, args.flags),
        .PlanarF => c.vImageHistogramSpecification_PlanarF(args.src, args.dest, args.tempBuffer, args.desired_histogram, args.histogram_entries, args.minVal, args.maxVal, args.flags),
        .ARGB8888 => c.vImageHistogramSpecification_ARGB8888(args.src, args.dest, args.desired_histogram, args.flags),
        .ARGBFFFF => c.vImageHistogramSpecification_ARGBFFFF(args.src, args.dest, args.tempBuffer, args.desired_histogram, args.histogram_entries, args.minVal, args.maxVal, args.flags),
    };
}

// ============================================================================
// Contrast Stretch
// ============================================================================

/// Stretches the contrast of a Planar8 image to fill the full [0, 255] range.
pub fn contrastStretch_Planar8(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageContrastStretch_Planar8(src, dest, flags);
}

/// Stretches the contrast of a PlanarF image.
pub fn contrastStretch_PlanarF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    histogram_entries: u32,
    minVal: Pixel_F,
    maxVal: Pixel_F,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageContrastStretch_PlanarF(src, dest, tempBuffer, histogram_entries, minVal, maxVal, flags);
}

/// Stretches the contrast of an ARGB8888 image.
pub fn contrastStretch_ARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageContrastStretch_ARGB8888(src, dest, flags);
}

/// Stretches the contrast of an ARGBFFFF image.
pub fn contrastStretch_ARGBFFFF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    histogram_entries: u32,
    minVal: Pixel_F,
    maxVal: Pixel_F,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageContrastStretch_ARGBFFFF(src, dest, tempBuffer, histogram_entries, minVal, maxVal, flags);
}

/// Type-dispatched contrast stretch.
pub fn contrastStretch(comptime fmt: Format, args: switch (fmt) {
    .Planar8 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        flags: vImage_Flags = 0,
    },
    .PlanarF => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        tempBuffer: ?*anyopaque = null,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: vImage_Flags = 0,
    },
    .ARGB8888 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        flags: vImage_Flags = 0,
    },
    .ARGBFFFF => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        tempBuffer: ?*anyopaque = null,
        histogram_entries: u32,
        minVal: Pixel_F,
        maxVal: Pixel_F,
        flags: vImage_Flags = 0,
    },
}) vImage_Error {
    return switch (fmt) {
        .Planar8 => c.vImageContrastStretch_Planar8(args.src, args.dest, args.flags),
        .PlanarF => c.vImageContrastStretch_PlanarF(args.src, args.dest, args.tempBuffer, args.histogram_entries, args.minVal, args.maxVal, args.flags),
        .ARGB8888 => c.vImageContrastStretch_ARGB8888(args.src, args.dest, args.flags),
        .ARGBFFFF => c.vImageContrastStretch_ARGBFFFF(args.src, args.dest, args.tempBuffer, args.histogram_entries, args.minVal, args.maxVal, args.flags),
    };
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageEndsInContrastStretch_Planar8(src, dest, percent_low, percent_high, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageEndsInContrastStretch_PlanarF(src, dest, tempBuffer, percent_low, percent_high, histogram_entries, minVal, maxVal, flags);
}

/// Performs an ends-in contrast stretch on an ARGB8888 image.
///
/// `percent_low` and `percent_high` are arrays of 4 per-channel percentages.
pub fn endsInContrastStretch_ARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    percent_low: *const [4]c_uint,
    percent_high: *const [4]c_uint,
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageEndsInContrastStretch_ARGB8888(src, dest, percent_low, percent_high, flags);
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
    flags: vImage_Flags,
) vImage_Error {
    return c.vImageEndsInContrastStretch_ARGBFFFF(src, dest, tempBuffer, percent_low, percent_high, histogram_entries, minVal, maxVal, flags);
}

/// Type-dispatched ends-in contrast stretch.
pub fn endsInContrastStretch(comptime fmt: Format, args: switch (fmt) {
    .Planar8 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        percent_low: u32,
        percent_high: u32,
        flags: vImage_Flags = 0,
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
        flags: vImage_Flags = 0,
    },
    .ARGB8888 => struct {
        src: *const vImage_Buffer,
        dest: *const vImage_Buffer,
        percent_low: *const [4]c_uint,
        percent_high: *const [4]c_uint,
        flags: vImage_Flags = 0,
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
        flags: vImage_Flags = 0,
    },
}) vImage_Error {
    return switch (fmt) {
        .Planar8 => c.vImageEndsInContrastStretch_Planar8(args.src, args.dest, args.percent_low, args.percent_high, args.flags),
        .PlanarF => c.vImageEndsInContrastStretch_PlanarF(args.src, args.dest, args.tempBuffer, args.percent_low, args.percent_high, args.histogram_entries, args.minVal, args.maxVal, args.flags),
        .ARGB8888 => c.vImageEndsInContrastStretch_ARGB8888(args.src, args.dest, args.percent_low, args.percent_high, args.flags),
        .ARGBFFFF => c.vImageEndsInContrastStretch_ARGBFFFF(args.src, args.dest, args.tempBuffer, args.percent_low, args.percent_high, args.histogram_entries, args.minVal, args.maxVal, args.flags),
    };
}
