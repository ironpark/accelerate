const build_options = @import("build_options");

pub const types = @import("types.zig");

// -- Core types --
pub const vImage_Buffer = types.vImage_Buffer;
pub const vImagePixelCount = types.vImagePixelCount;
pub const vImage_Flags = types.vImage_Flags;
pub const vImage_Error = types.vImage_Error;
pub const Flags = types.Flags;
pub const Options = types.Options;
pub const Connectivity = types.Connectivity;
pub const Error = types.Error;
pub const VImageError = types.VImageError;
pub const check = types.check;

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

// -- CoreGraphics / CoreVideo modules (opt-in) --
//
// Present only when the package is built with `-Dcoregraphics=true`.
// Otherwise each name resolves to `disabled_module`, whose only declaration
// is `enabled = false` — so `@hasDecl` and a check on `.enabled` both work,
// and referencing anything else is a compile error naming the missing
// declaration.

/// `vImage_Utilities.h` — CGImage interoperation and `vImageConvert_AnyToAny`.
pub const utilities = if (build_options.coregraphics) @import("utilities.zig") else disabled_module;
/// `vImage_CVUtilities.h` — CVPixelBuffer interoperation.
pub const cv = if (build_options.coregraphics) @import("cv.zig") else disabled_module;
/// The vImage types that mention a CoreGraphics or CoreVideo type.
pub const cg_types = if (build_options.coregraphics) @import("cg_types.zig") else disabled_module;

/// Stands in for the CoreGraphics-gated namespaces when the option is off, so
/// that `vimage.utilities.enabled` is answerable either way instead of being
/// a "no member named 'utilities'" error that says nothing about the cause.
const disabled_module = struct {
    /// Rebuild with `-Dcoregraphics=true` to make these namespaces real.
    pub const enabled = false;
};

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
