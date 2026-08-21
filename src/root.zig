pub const vdsp = @import("vdsp/root.zig");
pub const vimage = @import("vimage/root.zig");
pub const vforce = @import("vforce/root.zig");
pub const sparse = @import("sparse/root.zig");
pub const quadrature = @import("quadrature/root.zig");
pub const blas = @import("blas/root.zig");
pub const lapack = @import("lapack/root.zig");
pub const bnns = @import("bnns/root.zig");

// -- CoreGraphics / CoreVideo support (opt-in) --
//
// The minimum of CoreFoundation, CoreGraphics and CoreVideo that
// `vimage.utilities` and `vimage.cv` need in order to take and return real
// `CGImageRef`s and `CVPixelBufferRef`s. Present only when the package is
// built with `-Dcoregraphics=true`.

/// CoreFoundation and CoreGraphics: `CGColorSpace`, `CGImage`, `CGBitmapInfo`.
pub const cg = if (build_options.coregraphics) @import("cg/root.zig") else disabled_module;
/// CoreVideo: `CVPixelBuffer` and the pixel-format codes.
pub const cv = if (build_options.coregraphics) @import("cv/root.zig") else disabled_module;

const build_options = @import("build_options");

/// See `vimage.utilities` for why this exists rather than simply omitting the
/// declaration.
const disabled_module = struct {
    /// Rebuild with `-Dcoregraphics=true` to make these namespaces real.
    pub const enabled = false;
};

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
