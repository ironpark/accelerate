//! BNNS — Basic Neural Network Subroutines.
//!
//! BNNS has two generations of API and this package binds only the current one.
//!
//! The original, from macOS 10.12, assembled a network out of individual layer
//! objects: `BNNSFilterCreateLayerConvolution`, `BNNSFilterApply`, and around
//! 75 symbols besides. Apple deprecated all of it in macOS 15.0. Those symbols
//! still exist in the framework, but binding a deprecated API is not something
//! this package does — the same call was made for `LinearAlgebra` (`la_*`).
//!
//! The current API compiles a whole model instead. You produce a `.mlmodelc`
//! with Core ML Tools, compile it into a `Graph`, and execute it through a
//! `Context`:
//!
//! ```zig
//! var graph = try bnns.Graph.compileFromFile("model.mlmodelc", null, .{});
//! defer graph.deinit();
//! var ctx = try bnns.Context.init(graph);
//! defer ctx.deinit();
//! ```
//!
//! Alongside the graph API, `bnns.h` carries a handful of standalone utilities
//! that were not deprecated, and those are bound too: tensor copy and
//! transpose, reductions, top-k, a seedable random generator, and a small
//! k-nearest-neighbours store.
//!
//! ## Deployment target
//!
//! | Symbol | Available |
//! |---|---|
//! | the whole `Graph`/`Context`/`CompileOptions` surface | macOS 15.0 |
//! | `Context.setStreamingAdvanceCount` | macOS 15.4 |
//! | `RandomGenerator` | macOS 12.0 |
//! | `NearestNeighbors` | macOS 11.0 |
//! | `tensor.copy`, `tensor.transpose`, `tensor.reduce`, `tensor.topK` | macOS 11.0 |
//!
//! ## A trap worth knowing about
//!
//! Eleven graph entry points are `__asm__`-renamed in the header: the C name
//! `BNNSGraphContextExecute` resolves to the symbol
//! `_BNNSGraphContextExecute_v2`. `c.zig` declares those with `@extern` so the
//! Zig-side name stays readable, and a link test forces every declaration to
//! resolve so a missed rename fails the build rather than the program.

pub const types = @import("types.zig");
pub const c = @import("c.zig");

// -- Core types --
pub const DataType = types.DataType;
pub const DataLayout = types.DataLayout;
pub const NDArrayFlags = types.NDArrayFlags;
pub const ReduceFunction = types.ReduceFunction;
pub const RandomGeneratorMethod = types.RandomGeneratorMethod;
pub const NDArrayDescriptor = types.NDArrayDescriptor;
pub const Tensor = types.Tensor;
pub const FilterParameters = types.FilterParameters;
pub const Alloc = types.Alloc;
pub const Free = types.Free;
pub const max_tensor_dimension = types.max_tensor_dimension;
pub const Error = types.Error;
pub const check = types.check;
pub const checkSize = types.checkSize;

// -- Modules --
pub const tensor = @import("tensor.zig");
pub const graph = @import("graph.zig");
pub const random = @import("random.zig");
pub const knn = @import("knn.zig");

// -- Deprecated layer-filter API --
//
// Apple deprecated all of this in macOS 15.0 in favour of the Graph API above.
// It is bound because macOS 15.0 is a recent floor to require, and because a
// deployment target that predates it has no Graph API to fall back on. Every
// declaration in these modules carries the version it was deprecated in, and
// its replacement where the header names one.
pub const filter = @import("filter.zig");
pub const layers = @import("layers.zig");
pub const ops = @import("ops.zig");
pub const specialized = @import("specialized.zig");
pub const train = @import("train.zig");

// -- Graph API --
pub const Graph = graph.Graph;
pub const Context = graph.Context;
pub const CompileOptions = graph.CompileOptions;
pub const OptimizationPreference = graph.OptimizationPreference;
pub const ArgumentIntent = graph.ArgumentIntent;
pub const ArgumentType = graph.ArgumentType;
pub const MessageLevel = graph.MessageLevel;
pub const Argument = graph.Argument;
pub const Shape = graph.Shape;

// -- Standalone utilities --
pub const RandomGenerator = random.RandomGenerator;
pub const NearestNeighbors = knn.NearestNeighbors;
pub const descriptor = tensor.descriptor;
pub const copy = tensor.copy;
pub const transpose = tensor.transpose;
pub const reduce = tensor.reduce;
pub const topK = tensor.topK;
pub const inTopK = tensor.inTopK;

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
