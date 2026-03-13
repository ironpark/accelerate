pub const types = @import("types.zig");

// -- Core types --
pub const vImage_Buffer = types.vImage_Buffer;
pub const vImagePixelCount = types.vImagePixelCount;
pub const vImage_Flags = types.vImage_Flags;
pub const vImage_Error = types.vImage_Error;
pub const Flags = types.Flags;
pub const Error = types.Error;

// -- Pixel types --
pub const Pixel_8 = types.Pixel_8;
pub const Pixel_F = types.Pixel_F;
pub const Pixel_8888 = types.Pixel_8888;
pub const Pixel_FFFF = types.Pixel_FFFF;
pub const Pixel_88 = types.Pixel_88;
pub const Pixel_FF = types.Pixel_FF;
pub const Pixel_16U = types.Pixel_16U;
pub const Pixel_16S = types.Pixel_16S;
pub const Pixel_16F = types.Pixel_16F;
pub const Pixel_ARGB_16U = types.Pixel_ARGB_16U;
pub const Pixel_ARGB_16S = types.Pixel_ARGB_16S;
pub const Pixel_16Q12 = types.Pixel_16Q12;
pub const Pixel_ARGB_16F = types.Pixel_ARGB_16F;

// -- Affine transforms --
pub const vImage_AffineTransform = types.vImage_AffineTransform;
pub const vImage_AffineTransform_Double = types.vImage_AffineTransform_Double;

// -- Opaque types --
pub const ResamplingFilter = types.ResamplingFilter;
pub const GammaFunction = types.GammaFunction;
pub const vImage_MultidimensionalTable = types.vImage_MultidimensionalTable;

// -- Modules --
pub const alpha = @import("alpha.zig");
pub const conversion = @import("conversion.zig");
pub const convolution = @import("convolution.zig");
pub const geometry = @import("geometry.zig");
pub const histogram = @import("histogram.zig");
pub const morphology = @import("morphology.zig");
pub const transform = @import("transform.zig");

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
