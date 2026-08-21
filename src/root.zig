pub const vdsp = @import("vdsp/root.zig");
pub const vimage = @import("vimage/root.zig");
pub const vforce = @import("vforce/root.zig");
pub const sparse = @import("sparse/root.zig");
pub const quadrature = @import("quadrature/root.zig");
pub const blas = @import("blas/root.zig");
pub const lapack = @import("lapack/root.zig");
pub const bnns = @import("bnns/root.zig");

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
