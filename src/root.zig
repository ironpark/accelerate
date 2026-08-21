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

/// Force semantic analysis of every declaration reachable from `T`, including
/// methods on nested types.
///
/// `std.testing.refAllDecls` only goes one level deep, so a `pub fn` that
/// nothing calls -- a method on a struct inside a module, say -- is never
/// analysed, and can sit in the tree not compiling. That is not hypothetical:
/// `vimage.utilities.Converter.tempBufferSize` was in exactly that state,
/// passing a `u32` where an `Options` was wanted, through a full green test
/// run.
///
/// `depth` bounds the walk so that a type that refers back to its own
/// namespace cannot loop forever.
fn refAllDeclsDeep(comptime T: type, comptime depth: usize) void {
    if (depth == 0) return;
    inline for (comptime @import("std").meta.declarations(T)) |decl| {
        const field = @field(T, decl.name);
        if (@TypeOf(field) == type) {
            switch (@typeInfo(field)) {
                .@"struct", .@"union", .@"enum", .@"opaque" => refAllDeclsDeep(field, depth - 1),
                else => {},
            }
        } else {
            _ = &@field(T, decl.name);
        }
    }
}

test {
    @setEvalBranchQuota(200_000);
    refAllDeclsDeep(@This(), 6);
}
