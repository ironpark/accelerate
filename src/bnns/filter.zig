//! The BNNS layer-filter object: apply it, apply it over a batch, run it
//! backward, and destroy it.
//!
//! Everything in this file is the **deprecated** first-generation BNNS API.
//! Apple deprecated the whole layer-filter surface in macOS 15.0 (iOS 18.0,
//! watchOS 11.0, tvOS 18.0) in favour of the Graph API, which this package
//! binds in `bnns.graph`. It is bound anyway because macOS 15.0 is a recent
//! floor to require, and a deployment target older than that has no Graph API
//! to fall back on.
//!
//! The shape of a session is: create a filter with one of the
//! `BNNSFilterCreateLayer*` calls in `bnns.layers` (or `Filter.initFused`
//! here), apply it as many times as you like, then `deinit` it.
//!
//! ```zig
//! var filter = try Filter.fromHandle(
//!     c.BNNSFilterCreateLayerFullyConnected(&layer_params, null),
//! );
//! defer filter.deinit();
//! try filter.apply(&input, &output);
//! ```
//!
//! Facts a caller needs:
//! * The filter captures the *shapes, strides, data types and weights* given
//!   at creation. Only the input and output data pointers are supplied per
//!   apply; changing a shape means destroying the filter and creating another.
//! * Weights and bias are copied into the filter at creation unless the
//!   `Flags.use_client_ptr` bit is set in `FilterParameters.flags`, in which
//!   case the client's buffers must outlive the filter.
//! * Every `stride` argument below is an increment **in values, not bytes**,
//!   between consecutive samples of the batch. Passing 0 means "the object
//!   size the filter was created with", i.e. tightly packed.
//! * Whether a filter takes one input or two is fixed by the layer type, not
//!   chosen here: arithmetic layers with a binary function and two-operand
//!   tensor contractions need the `TwoInput` calls, everything else needs the
//!   plain ones. Using the wrong arity fails at runtime, not at compile time.
//! * The backward calls exist only for training and carry two hard
//!   requirements the header states: the filter must have been created with
//!   `Flags.use_client_ptr`, and every descriptor involved must be
//!   `DataType.float32`.
//! * A `Filter` is not thread safe; applying the same filter from two threads
//!   concurrently is not supported.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const Error = types.Error;
const check = types.check;
const FilterParameters = types.FilterParameters;
const FilterType = types.FilterType;
const NDArrayDescriptor = types.NDArrayDescriptor;
const PointerSpecifier = types.PointerSpecifier;

/// An owned `BNNSFilter` — one layer of the deprecated layer-filter API.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const Filter = struct {
    handle: c.BNNSFilter,

    /// Adopt a raw `BNNSFilter` returned by one of the `BNNSFilterCreateLayer*`
    /// entry points, turning the API's null-on-failure convention into an
    /// error. Ownership transfers: the resulting `Filter` must be `deinit`ed.
    ///
    /// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
    pub fn fromHandle(handle: c.BNNSFilter) Error!Filter {
        if (handle == null) return Error.BnnsAllocationFailed;
        return .{ .handle = handle };
    }

    /// Create an N-layer fused filter: `in -> filter0 -> ... -> filterN-1 -> out`.
    ///
    /// `BNNSFilterCreateFusedLayer`. `filter_types[i]` says which layer
    /// `layer_params[i]` describes, and each element of `layer_params` must
    /// point at the parameter struct that matches — the same struct that would
    /// create that layer standalone. The two slices must be the same length.
    ///
    /// The header only supports fusing two filters, in these configurations:
    /// convolution / transposed convolution / fully connected, followed by a
    /// normalization or a quantization layer; or arithmetic followed by a
    /// normalization. Adjacent descriptors must agree exactly: filter K's
    /// output descriptor and filter K+1's input descriptor need the same
    /// sizes, strides and data type. For training, all but the last filter
    /// must use `ActivationFunction.identity`.
    ///
    /// Apply the result with the `fused*` methods, not the plain ones.
    ///
    /// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
    pub fn initFused(
        filter_types: []const FilterType,
        layer_params: []const *const anyopaque,
        filter_params: ?*const FilterParameters,
    ) Error!Filter {
        std.debug.assert(filter_types.len == layer_params.len);
        std.debug.assert(filter_types.len != 0);
        const h = c.BNNSFilterCreateFusedLayer(
            filter_types.len,
            filter_types.ptr,
            @constCast(layer_params.ptr),
            filter_params,
        );
        if (h == null) return Error.BnnsAllocationFailed;
        return .{ .handle = h };
    }

    /// Release every resource the filter holds.
    ///
    /// `BNNSFilterDestroy`. Safe on a filter created by any of the create
    /// calls, fused or not. Nulls the handle so a double `deinit` is a no-op.
    ///
    /// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
    pub fn deinit(self: *Filter) void {
        c.BNNSFilterDestroy(self.handle);
        self.handle = null;
    }

    /// Apply the filter to one input, producing one output.
    ///
    /// `BNNSFilterApply`. `in` and `out` point at a single object of the
    /// input/output shape the filter was created with. For layers that take
    /// two inputs use `applyTwoInput`.
    ///
    /// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
    pub fn apply(self: Filter, in: *const anyopaque, out: *anyopaque) Error!void {
        return check(c.BNNSFilterApply(self.handle, in, out));
    }

    /// Apply the filter to `batch_size` (input, output) pairs.
    ///
    /// `BNNSFilterApplyBatch`. `in` must hold `batch_size` inputs and `out`
    /// `batch_size` outputs. `in_stride`/`out_stride` are increments in values
    /// between consecutive samples; 0 means the filter's own object size.
    ///
    /// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
    pub fn applyBatch(
        self: Filter,
        batch_size: usize,
        in: *const anyopaque,
        in_stride: usize,
        out: *anyopaque,
        out_stride: usize,
    ) Error!void {
        return check(c.BNNSFilterApplyBatch(self.handle, batch_size, in, in_stride, out, out_stride));
    }

    /// Apply a two-input filter to one pair of inputs.
    ///
    /// `BNNSFilterApplyTwoInput`. Only layers whose type genuinely consumes
    /// two tensors accept this — a broadcast matmul with neither operand
    /// marked as weights, or a tensor contraction with two non-weight operands.
    /// An arithmetic layer is *not* one of them despite taking two operands:
    /// it was observed to return `Error.BnnsFailed` here, and wants the
    /// arithmetic-specific multi-input apply instead.
    ///
    /// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
    pub fn applyTwoInput(
        self: Filter,
        in_a: *const anyopaque,
        in_b: *const anyopaque,
        out: *anyopaque,
    ) Error!void {
        return check(c.BNNSFilterApplyTwoInput(self.handle, in_a, in_b, out));
    }

    /// Apply a two-input filter over a batch.
    ///
    /// `BNNSFilterApplyTwoInputBatch`. The two inputs have independent
    /// strides, which lets one operand be broadcast by passing a stride of 0
    /// only if the layer declares that operand `DescriptorType.constant`;
    /// otherwise both must advance per sample.
    ///
    /// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
    pub fn applyTwoInputBatch(
        self: Filter,
        batch_size: usize,
        in_a: *const anyopaque,
        in_a_stride: usize,
        in_b: *const anyopaque,
        in_b_stride: usize,
        out: *anyopaque,
        out_stride: usize,
    ) Error!void {
        return check(c.BNNSFilterApplyTwoInputBatch(
            self.handle,
            batch_size,
            in_a,
            in_a_stride,
            in_b,
            in_b_stride,
            out,
            out_stride,
        ));
    }

    /// Backpropagate through the filter, producing the input gradient and,
    /// optionally, the weight and bias gradients.
    ///
    /// `BNNSFilterApplyBackwardBatch`. Arguments in C order:
    /// * `in` / `in_stride` — the forward pass input `x`. Ignored except for
    ///   pooling layers and for activations that need `x` to differentiate.
    /// * `in_delta` / `in_delta_stride` — receives `dx`; pass null to skip it,
    ///   which is what you do for the first layer of a network.
    /// * `out` / `out_stride` — the forward pass output `y`. Ignored when the
    ///   activation is identity; **required** when the layer has a fused
    ///   non-identity activation.
    /// * `out_delta` / `out_delta_stride` — the incoming gradient `dy`.
    /// * `weights_delta`, `bias_delta` — receive the parameter gradients,
    ///   already summed over the batch; null to skip either.
    ///
    /// All active gradients must be computed in one call. The filter must have
    /// been created with `Flags.use_client_ptr`, and every descriptor must be
    /// `DataType.float32`.
    ///
    /// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
    pub fn applyBackwardBatch(
        self: Filter,
        batch_size: usize,
        in: ?*const anyopaque,
        in_stride: usize,
        in_delta: ?*NDArrayDescriptor,
        in_delta_stride: usize,
        out: ?*const anyopaque,
        out_stride: usize,
        out_delta: *const NDArrayDescriptor,
        out_delta_stride: usize,
        weights_delta: ?*NDArrayDescriptor,
        bias_delta: ?*NDArrayDescriptor,
    ) Error!void {
        return check(c.BNNSFilterApplyBackwardBatch(
            self.handle,
            batch_size,
            in,
            in_stride,
            in_delta,
            in_delta_stride,
            out,
            out_stride,
            out_delta,
            out_delta_stride,
            weights_delta,
            bias_delta,
        ));
    }

    /// Backpropagate through a two-input filter, producing a gradient for each
    /// of the two inputs.
    ///
    /// `BNNSFilterApplyBackwardTwoInputBatch`. Same rules as
    /// `applyBackwardBatch` — one call must compute every active gradient, the
    /// filter needs `Flags.use_client_ptr`, and everything is float32 — with
    /// the input arguments doubled up: `in_a`/`in_a_delta` and
    /// `in_b`/`in_b_delta`. Either delta may be null to skip that gradient.
    ///
    /// Observed quirk worth knowing: for a broadcast matmul whose output is an
    /// N-by-1 matrix, only the first row of the `in_a` gradient is written and
    /// the rest is left untouched. The N-by-N case is correct.
    ///
    /// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
    pub fn applyBackwardTwoInputBatch(
        self: Filter,
        batch_size: usize,
        in_a: ?*const anyopaque,
        in_a_stride: usize,
        in_a_delta: ?*NDArrayDescriptor,
        in_a_delta_stride: usize,
        in_b: ?*const anyopaque,
        in_b_stride: usize,
        in_b_delta: ?*NDArrayDescriptor,
        in_b_delta_stride: usize,
        out: ?*const anyopaque,
        out_stride: usize,
        out_delta: *const NDArrayDescriptor,
        out_delta_stride: usize,
        weights_delta: ?*NDArrayDescriptor,
        bias_delta: ?*NDArrayDescriptor,
    ) Error!void {
        return check(c.BNNSFilterApplyBackwardTwoInputBatch(
            self.handle,
            batch_size,
            in_a,
            in_a_stride,
            in_a_delta,
            in_a_delta_stride,
            in_b,
            in_b_stride,
            in_b_delta,
            in_b_delta_stride,
            out,
            out_stride,
            out_delta,
            out_delta_stride,
            weights_delta,
            bias_delta,
        ));
    }

    /// Apply a fused filter (see `initFused`) over a batch.
    ///
    /// `BNNSFusedFilterApplyBatch`. Identical to `applyBatch` but for the
    /// `training` flag, which only matters when one of the fused layers is a
    /// normalization: true normalizes with the current batch statistics and
    /// updates the moving mean/variance, false normalizes with the stored
    /// moving statistics when they are present.
    ///
    /// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
    pub fn fusedApplyBatch(
        self: Filter,
        batch_size: usize,
        in: *const anyopaque,
        in_stride: usize,
        out: *anyopaque,
        out_stride: usize,
        training: bool,
    ) Error!void {
        return check(c.BNNSFusedFilterApplyBatch(self.handle, batch_size, in, in_stride, out, out_stride, training));
    }

    /// Apply a fused filter whose first layer takes several inputs.
    ///
    /// `BNNSFusedFilterApplyMultiInputBatch`. `in` holds one pointer per input
    /// of the leading arithmetic layer and `in_strides` one stride per input;
    /// the two slices must be the same length, which is passed on as
    /// `number_of_inputs`. Only the arithmetic-then-normalization fusion
    /// supports this call.
    ///
    /// Deprecated in macOS 12.0..15.0. Prefer the Graph API (`bnns.Graph`).
    pub fn fusedApplyMultiInputBatch(
        self: Filter,
        batch_size: usize,
        in: []const *const anyopaque,
        in_strides: []const usize,
        out: *anyopaque,
        out_stride: usize,
        training: bool,
    ) Error!void {
        std.debug.assert(in.len == in_strides.len);
        return check(c.BNNSFusedFilterApplyMultiInputBatch(
            self.handle,
            batch_size,
            in.len,
            @constCast(in.ptr),
            in_strides.ptr,
            out,
            out_stride,
            training,
        ));
    }

    /// Backpropagate through a fused filter.
    ///
    /// `BNNSFusedFilterApplyBackwardBatch`. Like `applyBackwardBatch`, except
    /// that the parameter gradients of every fused layer arrive in one flat
    /// array instead of the `weights_delta`/`bias_delta` pair:
    /// `delta_parameters` lists the first layer's parameters in the order that
    /// layer's standalone backward call takes them, then the second layer's,
    /// and so on. Input and output deltas are *not* in that array. Every slot
    /// must be present; use null for a parameter you do not want.
    ///
    /// For a convolution fused with a batch norm that is
    /// `.{ weights_delta, bias_delta, beta_delta, gamma_delta }`.
    ///
    /// Note that `out_delta` is non-const here and BNNS may overwrite it while
    /// computing the fused activation's backward pass.
    ///
    /// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
    pub fn fusedApplyBackwardBatch(
        self: Filter,
        batch_size: usize,
        in: ?*const anyopaque,
        in_stride: usize,
        in_delta: ?*NDArrayDescriptor,
        in_delta_stride: usize,
        out: ?*const anyopaque,
        out_stride: usize,
        out_delta: *NDArrayDescriptor,
        out_delta_stride: usize,
        delta_parameters: ?[]const ?*NDArrayDescriptor,
    ) Error!void {
        return check(c.BNNSFusedFilterApplyBackwardBatch(
            self.handle,
            batch_size,
            in,
            in_stride,
            in_delta,
            in_delta_stride,
            out,
            out_stride,
            out_delta,
            out_delta_stride,
            if (delta_parameters) |p| @constCast(p.ptr) else null,
        ));
    }

    /// Backpropagate through a fused filter whose first layer takes several
    /// inputs, producing one gradient per input.
    ///
    /// `BNNSFusedFilterApplyBackwardMultiInputBatch`. `in`/`in_strides` are the
    /// forward inputs (both may be null for arithmetic layers that supported an
    /// in-place forward pass), and `in_deltas`/`in_delta_strides` are the
    /// gradients to produce — those are mandatory, one entry per input, and all
    /// of them must be computed in this single call. `delta_parameters` follows
    /// the same flat layout as in `fusedApplyBackwardBatch`. Only the
    /// arithmetic-then-normalization fusion supports this call.
    ///
    /// Deprecated in macOS 12.0..15.0. Prefer the Graph API (`bnns.Graph`).
    pub fn fusedApplyBackwardMultiInputBatch(
        self: Filter,
        batch_size: usize,
        in: ?[]const ?*const anyopaque,
        in_strides: ?[]const usize,
        in_deltas: []const *NDArrayDescriptor,
        in_delta_strides: []const usize,
        out: ?*const anyopaque,
        out_stride: usize,
        out_delta: *NDArrayDescriptor,
        out_delta_stride: usize,
        delta_parameters: ?[]const ?*NDArrayDescriptor,
    ) Error!void {
        std.debug.assert(in_deltas.len == in_delta_strides.len);
        if (in) |p| std.debug.assert(p.len == in_deltas.len);
        if (in_strides) |s| std.debug.assert(s.len == in_deltas.len);
        return check(c.BNNSFusedFilterApplyBackwardMultiInputBatch(
            self.handle,
            batch_size,
            in_deltas.len,
            if (in) |p| @constCast(p.ptr) else null,
            if (in_strides) |s| s.ptr else null,
            @constCast(in_deltas.ptr),
            in_delta_strides.ptr,
            out,
            out_stride,
            out_delta,
            out_delta_stride,
            if (delta_parameters) |p| @constCast(p.ptr) else null,
        ));
    }

    /// Get a descriptor referring to one of the filter's internal trainable
    /// scalars, so it can be read or modified after creation.
    ///
    /// `BNNSGetPointer`. Activation layers keep their `alpha` and `beta` here,
    /// which is what `PointerSpecifier` selects between. The returned
    /// descriptor's `data` points *into* the filter: writing through it changes
    /// what the next `apply` computes, the pointer dies with the filter, and it
    /// is not safe to touch while another thread is applying the filter.
    ///
    /// The C call signals failure by returning a descriptor with a null `data`,
    /// which this turns into `Error.BnnsFailed`.
    ///
    /// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
    pub fn getPointer(self: Filter, target: PointerSpecifier) Error!NDArrayDescriptor {
        const desc = c.BNNSGetPointer(self.handle, target);
        if (desc.data == null) return Error.BnnsFailed;
        return desc;
    }
};

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const DataLayout = types.DataLayout;

/// A rank-1 `.vector` descriptor over `data`.
fn vectorDesc(n: usize, data: ?[]f32) NDArrayDescriptor {
    var d: NDArrayDescriptor = .{ .layout = .vector, .data_type = .float32 };
    d.size[0] = n;
    if (data) |s| {
        std.debug.assert(s.len == n);
        d.data = @ptrCast(s.ptr);
    }
    return d;
}

/// A `.row_major_matrix` descriptor. `size[0]` is the fastest-varying axis,
/// i.e. the number of columns.
fn matrixDesc(columns: usize, rows: usize, data: []f32) NDArrayDescriptor {
    std.debug.assert(data.len == columns * rows);
    var d: NDArrayDescriptor = .{ .layout = .row_major_matrix, .data_type = .float32 };
    d.size[0] = columns;
    d.size[1] = rows;
    d.data = @ptrCast(data.ptr);
    return d;
}

/// A `.row_major_matrix` descriptor whose data is supplied at apply time.
fn matrixDescNoData(columns: usize, rows: usize) NDArrayDescriptor {
    var d: NDArrayDescriptor = .{ .layout = .row_major_matrix, .data_type = .float32 };
    d.size[0] = columns;
    d.size[1] = rows;
    return d;
}

/// `y = 3*x0 + 4*x1 + 5`, as a 2-input 1-output fully connected layer.
/// `W(o,i)` lives at `weights[i + o*in_size]`, so a 1x2 row-major matrix.
fn makeAffineFilter(weights: []f32, bias: []f32, params: *types.LayerParametersFullyConnected) !Filter {
    params.* = .{
        .i_desc = vectorDesc(2, null),
        .w_desc = matrixDesc(2, 1, weights),
        .o_desc = vectorDesc(1, null),
        .bias = vectorDesc(1, bias),
        .activation = .{ .function = .identity },
    };
    var fp: FilterParameters = .{ .flags = @intFromEnum(types.Flags.use_client_ptr) };
    return Filter.fromHandle(c.BNNSFilterCreateLayerFullyConnected(params, &fp));
}

test "apply: fully connected 2->1 computes 3*x0 + 4*x1 + 5" {
    var weights = [_]f32{ 3, 4 };
    var bias = [_]f32{5};
    var params: types.LayerParametersFullyConnected = undefined;
    var filter = try makeAffineFilter(&weights, &bias, &params);
    defer filter.deinit();

    const in = [_]f32{ 1, 2 };
    const out = try testing.allocator.alloc(f32, 1);
    defer testing.allocator.free(out);
    out[0] = -1;

    try filter.apply(&in, out.ptr);
    try testing.expectEqual(@as(f32, 16), out[0]); // 3*1 + 4*2 + 5
}

test "applyBatch: two samples, strides counted in values" {
    var weights = [_]f32{ 3, 4 };
    var bias = [_]f32{5};
    var params: types.LayerParametersFullyConnected = undefined;
    var filter = try makeAffineFilter(&weights, &bias, &params);
    defer filter.deinit();

    const in = [_]f32{ 1, 2, 10, 20 };
    var out = [_]f32{ -1, -1 };
    try filter.applyBatch(2, &in, 2, &out, 1);
    // 3*1 + 4*2 + 5 = 16, 3*10 + 4*20 + 5 = 115
    try testing.expectEqualSlices(f32, &.{ 16, 115 }, &out);

    // A stride of 0 means "the object size the filter was created with", so
    // the packed layout above is reproduced exactly.
    var out_default = [_]f32{ -1, -1 };
    try filter.applyBatch(2, &in, 0, &out_default, 0);
    try testing.expectEqualSlices(f32, &.{ 16, 115 }, &out_default);

    // A larger input stride skips a sample: only the first two of every three
    // values are read.
    const spread = [_]f32{ 1, 2, 99, 10, 20, 99 };
    var out_spread = [_]f32{ -1, -1 };
    try filter.applyBatch(2, &spread, 3, &out_spread, 1);
    try testing.expectEqualSlices(f32, &.{ 16, 115 }, &out_spread);
}

test "getPointer: reads and rewrites an activation layer's alpha in place" {
    var params: types.LayerParametersActivation = .{
        .i_desc = vectorDesc(2, null),
        .o_desc = vectorDesc(2, null),
        .activation = .{ .function = .leaky_rectified_linear, .alpha = 0.25 },
    };
    var filter = try Filter.fromHandle(c.BNNSFilterCreateLayerActivation(&params, null));
    defer filter.deinit();

    const in = [_]f32{ -4, 2 };
    var out = [_]f32{ 0, 0 };
    try filter.apply(&in, &out);
    try testing.expectEqualSlices(f32, &.{ -1, 2 }, &out); // 0.25*-4, 2

    const alpha = try filter.getPointer(.alpha);
    try testing.expectEqual(types.DataType.float32, alpha.data_type);
    const alpha_ptr: *f32 = @ptrCast(@alignCast(alpha.data.?));
    try testing.expectEqual(@as(f32, 0.25), alpha_ptr.*);

    // The descriptor aliases the filter's own storage, so writing through it
    // changes what the next apply computes.
    alpha_ptr.* = 0.5;
    try filter.apply(&in, &out);
    try testing.expectEqualSlices(f32, &.{ -2, 2 }, &out);
}

test "applyTwoInput and applyTwoInputBatch: broadcast matmul of two 2x2 operands" {
    var params: types.LayerParametersBroadcastMatMul = .{
        .alpha = 1,
        .beta = 0,
        .transA = false,
        .transB = false,
        .quadratic = false,
        .a_is_weights = false,
        .b_is_weights = false,
        .iA_desc = matrixDescNoData(2, 2),
        .iB_desc = matrixDescNoData(2, 2),
        .o_desc = matrixDescNoData(2, 2),
    };
    var filter = try Filter.fromHandle(c.BNNSFilterCreateLayerBroadcastMatMul(&params, null));
    defer filter.deinit();

    // A = [[1, 2], [3, 4]], B = [[5, 6], [7, 8]] -> A*B = [[19, 22], [43, 50]].
    const a = [_]f32{ 1, 2, 3, 4 };
    const b = [_]f32{ 5, 6, 7, 8 };
    var out = [_]f32{ 0, 0, 0, 0 };
    try filter.applyTwoInput(&a, &b, &out);
    try testing.expectEqualSlices(f32, &.{ 19, 22, 43, 50 }, &out);

    // Same again over a batch of two, the second pair having B scaled by 10.
    const a2 = a ++ a;
    const b2 = b ++ [_]f32{ 50, 60, 70, 80 };
    var out2: [8]f32 = @splat(0);
    try filter.applyTwoInputBatch(2, &a2, 4, &b2, 4, &out2, 4);
    try testing.expectEqualSlices(f32, &.{ 19, 22, 43, 50, 190, 220, 430, 500 }, &out2);
}

test "applyBackwardBatch: fully connected gradients, summed over the batch" {
    var weights = [_]f32{ 3, 4 };
    var bias = [_]f32{5};
    var params: types.LayerParametersFullyConnected = undefined;
    var filter = try makeAffineFilter(&weights, &bias, &params);
    defer filter.deinit();

    // x = [[1, 2], [10, 20]], dy = [1, 2].
    const x = [_]f32{ 1, 2, 10, 20 };
    var dy = [_]f32{ 1, 2 };
    var dx = [_]f32{ 0, 0, 0, 0 };
    var dw = [_]f32{ 0, 0 };
    var db = [_]f32{0};

    var in_delta = vectorDesc(2, dx[0..2]);
    var out_delta = vectorDesc(1, dy[0..1]); // one sample; the batch is walked by stride
    var weights_delta = matrixDesc(2, 1, &dw);
    var bias_delta = vectorDesc(1, &db);

    try filter.applyBackwardBatch(
        2,
        &x,
        2,
        &in_delta,
        2,
        null, // y is ignored: the layer's activation is identity
        1,
        &out_delta,
        1,
        &weights_delta,
        &bias_delta,
    );

    // dx_i = W^T * dy_i           -> [1*3, 1*4], [2*3, 2*4]
    try testing.expectEqualSlices(f32, &.{ 3, 4, 6, 8 }, &dx);
    // dW = sum_i dy_i * x_i^T     -> 1*[1,2] + 2*[10,20]
    try testing.expectEqualSlices(f32, &.{ 21, 42 }, &dw);
    // db = sum_i dy_i             -> 1 + 2
    try testing.expectEqual(@as(f32, 3), db[0]);
}

test "applyBackwardBatch: BNNS does not enforce the header's use_client_ptr rule" {
    var weights = [_]f32{ 3, 4 };
    var bias = [_]f32{5};
    var params: types.LayerParametersFullyConnected = .{
        .i_desc = vectorDesc(2, null),
        .w_desc = matrixDesc(2, 1, &weights),
        .o_desc = vectorDesc(1, null),
        .bias = vectorDesc(1, &bias),
        .activation = .{ .function = .identity },
    };
    // No FilterParameters at all, so the use_client_ptr flag is clear and BNNS
    // is free to have copied the weights rather than aliasing them.
    var filter = try Filter.fromHandle(c.BNNSFilterCreateLayerFullyConnected(&params, null));
    defer filter.deinit();

    const x = [_]f32{ 1, 2 };
    var dy = [_]f32{1};
    var dx = [_]f32{ 0, 0 };
    var in_delta = vectorDesc(2, &dx);
    var out_delta = vectorDesc(1, &dy);

    // The header says backward apply requires `Flags.use_client_ptr`. Observed
    // on macOS 15: for a fully connected layer the call succeeds anyway and the
    // gradient is correct. Do not rely on that — set the flag.
    try filter.applyBackwardBatch(1, &x, 2, &in_delta, 2, null, 1, &out_delta, 1, null, null);
    try testing.expectEqualSlices(f32, &.{ 3, 4 }, &dx);
}

test "applyBackwardTwoInputBatch: gradients of a matrix product w.r.t. both operands" {
    var params: types.LayerParametersBroadcastMatMul = .{
        .alpha = 1,
        .beta = 0,
        .transA = false,
        .transB = false,
        .quadratic = false,
        .a_is_weights = false,
        .b_is_weights = false,
        .iA_desc = matrixDescNoData(2, 2),
        .iB_desc = matrixDescNoData(2, 2),
        .o_desc = matrixDescNoData(2, 2),
    };
    var fp: FilterParameters = .{ .flags = @intFromEnum(types.Flags.use_client_ptr) };
    var filter = try Filter.fromHandle(c.BNNSFilterCreateLayerBroadcastMatMul(&params, &fp));
    defer filter.deinit();

    const a = [_]f32{ 1, 2, 3, 4 };
    const b = [_]f32{ 5, 6, 7, 8 };
    var y = [_]f32{ 19, 22, 43, 50 }; // the forward output, A*B
    var dc = [_]f32{ 1, 2, 3, 4 };
    var da: [4]f32 = @splat(0);
    var db: [4]f32 = @splat(0);

    var in_a_delta = matrixDesc(2, 2, &da);
    var in_b_delta = matrixDesc(2, 2, &db);
    var out_delta = matrixDesc(2, 2, &dc);

    try filter.applyBackwardTwoInputBatch(
        1,
        &a,
        4,
        &in_a_delta,
        4,
        &b,
        4,
        &in_b_delta,
        4,
        &y,
        4,
        &out_delta,
        4,
        null, // neither operand is declared as weights
        null,
    );

    // dA = dC * B^T = [[1,2],[3,4]] * [[5,7],[6,8]]
    try testing.expectEqualSlices(f32, &.{ 17, 23, 39, 53 }, &da);
    // dB = A^T * dC = [[1,3],[2,4]] * [[1,2],[3,4]]
    try testing.expectEqualSlices(f32, &.{ 10, 14, 14, 20 }, &db);
}

/// A fully-connected identity layer (2 -> 2, weights = I) fused with a batch
/// normalization over the same two channels. This is configuration 2 of the
/// list in `initFused`'s doc comment.
const FusedFixture = struct {
    weights: [4]f32 = .{ 1, 0, 0, 1 },
    bias: [2]f32 = .{ 0, 0 },
    beta: [2]f32 = .{ 0, 0 },
    gamma: [2]f32 = .{ 1, 1 },
    fc: types.LayerParametersFullyConnected = undefined,
    bn: types.LayerParametersNormalization = undefined,

    fn build(self: *FusedFixture) !Filter {
        self.fc = .{
            .i_desc = vectorDesc(2, null),
            .w_desc = matrixDesc(2, 2, &self.weights),
            .o_desc = vectorDesc(2, null),
            .bias = vectorDesc(2, &self.bias),
            .activation = .{ .function = .identity },
        };
        self.bn = .{
            .i_desc = vectorDesc(2, null),
            .o_desc = vectorDesc(2, null),
            .beta_desc = vectorDesc(2, &self.beta),
            .gamma_desc = vectorDesc(2, &self.gamma),
            .moving_mean_desc = vectorDesc(2, null), // null data: not tracked
            .moving_variance_desc = vectorDesc(2, null),
            .momentum = 0,
            .epsilon = 1e-5,
            .activation = .{ .function = .identity },
            .num_groups = 0,
            .normalization_axis = 0,
        };
        const params = [_]*const anyopaque{ @ptrCast(&self.fc), @ptrCast(&self.bn) };
        var fp: FilterParameters = .{ .flags = @intFromEnum(types.Flags.use_client_ptr) };
        return Filter.initFused(&.{ .fully_connected, .batch_norm }, &params, &fp);
    }
};

test "initFused + fusedApplyBatch: identity matmul then batch norm" {
    var fixture: FusedFixture = .{};
    var filter = try fixture.build();
    defer filter.deinit();

    // x = [[1, 2], [3, 4]]. The fully connected layer passes it through, then
    // batch norm normalizes each channel over the batch: channel 0 sees {1, 3}
    // (mean 2, population variance 1) and channel 1 sees {2, 4} (mean 3,
    // variance 1), so both come out as -1/sqrt(1 + epsilon), +1/sqrt(...).
    const x = [_]f32{ 1, 2, 3, 4 };
    var out: [4]f32 = @splat(0);
    try filter.fusedApplyBatch(2, &x, 2, &out, 2, true);

    const expected = [_]f32{ -1, -1, 1, 1 };
    for (expected, out) |e, got| try testing.expectApproxEqAbs(e, got, 1e-4);
}

test "fusedApplyBackwardBatch: parameter gradients arrive in one flat array" {
    var fixture: FusedFixture = .{};
    var filter = try fixture.build();
    defer filter.deinit();

    const x = [_]f32{ 1, 2, 3, 4 };
    var y: [4]f32 = @splat(0);
    try filter.fusedApplyBatch(2, &x, 2, &y, 2, true);

    // dy = [[1, 0], [0, 2]].
    var dy = [_]f32{ 1, 0, 0, 2 };
    var dx: [4]f32 = @splat(0);
    var dw: [4]f32 = @splat(0);
    var db: [2]f32 = @splat(0);
    var dbeta: [2]f32 = @splat(0);
    var dgamma: [2]f32 = @splat(0);

    var in_delta = vectorDesc(2, dx[0..2]);
    var out_delta = vectorDesc(2, dy[0..2]);
    var weights_delta = matrixDesc(2, 2, &dw);
    var bias_delta = vectorDesc(2, &db);
    var beta_delta = vectorDesc(2, &dbeta);
    var gamma_delta = vectorDesc(2, &dgamma);

    // Fully connected contributes (weights, bias) and batch norm (beta, gamma),
    // in that order, exactly as their standalone backward calls take them.
    const deltas = [_]?*NDArrayDescriptor{ &weights_delta, &bias_delta, &beta_delta, &gamma_delta };
    try filter.fusedApplyBackwardBatch(2, &x, 2, &in_delta, 2, &y, 2, &out_delta, 2, &deltas);

    // dbeta = sum_i dy_i          -> [1 + 0, 0 + 2]
    try testing.expectEqualSlices(f32, &.{ 1, 2 }, &dbeta);
    // dgamma = sum_i dy_i * y_i   -> [1*(-1) + 0*1, 0*(-1) + 2*1]
    for ([_]f32{ -1, 2 }, dgamma) |e, got| try testing.expectApproxEqAbs(e, got, 1e-4);
    // With a batch of two the normalized output is +-1 whatever the input is,
    // so the gradient reaching the fully connected layer is exactly zero.
    // (Up to the epsilon in 1/sqrt(var + epsilon), which leaves ~1e-5 behind.)
    for (dx) |v| try testing.expectApproxEqAbs(@as(f32, 0), v, 1e-4);
    for (dw) |v| try testing.expectApproxEqAbs(@as(f32, 0), v, 1e-4);
    for (db) |v| try testing.expectApproxEqAbs(@as(f32, 0), v, 1e-4);
}

/// An elementwise add of two inputs fused with a batch normalization — the one
/// configuration the multi-input fused calls accept.
const FusedAddFixture = struct {
    beta: [2]f32 = .{ 0, 0 },
    gamma: [2]f32 = .{ 1, 1 },
    operands: types.ArithmeticBinary = undefined,
    arithmetic: types.LayerParametersArithmetic = undefined,
    bn: types.LayerParametersNormalization = undefined,

    fn build(self: *FusedAddFixture) !Filter {
        self.operands = .{
            .in1 = vectorDesc(2, null),
            .in1_type = .sample,
            .in2 = vectorDesc(2, null),
            .in2_type = .sample,
            .out = vectorDesc(2, null),
            .out_type = .sample,
        };
        self.arithmetic = .{
            .arithmetic_function = .add,
            .arithmetic_function_fields = @ptrCast(&self.operands),
            .activation = .{ .function = .identity },
        };
        self.bn = .{
            .i_desc = vectorDesc(2, null),
            .o_desc = vectorDesc(2, null),
            .beta_desc = vectorDesc(2, &self.beta),
            .gamma_desc = vectorDesc(2, &self.gamma),
            .moving_mean_desc = vectorDesc(2, null),
            .moving_variance_desc = vectorDesc(2, null),
            .momentum = 0,
            .epsilon = 1e-5,
            .activation = .{ .function = .identity },
            .num_groups = 0,
            .normalization_axis = 0,
        };
        const params = [_]*const anyopaque{ @ptrCast(&self.arithmetic), @ptrCast(&self.bn) };
        var fp: FilterParameters = .{ .flags = @intFromEnum(types.Flags.use_client_ptr) };
        return Filter.initFused(&.{ .arithmetic, .batch_norm }, &params, &fp);
    }
};

test "fusedApplyMultiInputBatch: add two inputs, then batch norm" {
    var fixture: FusedAddFixture = .{};
    var filter = try fixture.build();
    defer filter.deinit();

    // a + b = [[1, 2], [3, 4]], the same tensor the fully connected fixture
    // normalizes above, so the output is again -1, -1, +1, +1.
    const a = [_]f32{ 1, 2, 2, 3 };
    const b = [_]f32{ 0, 0, 1, 1 };
    var out: [4]f32 = @splat(0);

    const inputs = [_]*const anyopaque{ @ptrCast(&a), @ptrCast(&b) };
    const strides = [_]usize{ 2, 2 };
    try filter.fusedApplyMultiInputBatch(2, &inputs, &strides, &out, 2, true);

    for ([_]f32{ -1, -1, 1, 1 }, out) |e, got| try testing.expectApproxEqAbs(e, got, 1e-4);
}

test "fusedApplyBackwardMultiInputBatch: one gradient per input, plus the norm parameters" {
    var fixture: FusedAddFixture = .{};
    var filter = try fixture.build();
    defer filter.deinit();

    const a = [_]f32{ 1, 2, 2, 3 };
    const b = [_]f32{ 0, 0, 1, 1 };
    var y: [4]f32 = @splat(0);
    const inputs = [_]*const anyopaque{ @ptrCast(&a), @ptrCast(&b) };
    const strides = [_]usize{ 2, 2 };
    try filter.fusedApplyMultiInputBatch(2, &inputs, &strides, &y, 2, true);

    var dy = [_]f32{ 1, 0, 0, 2 };
    var da: [4]f32 = @splat(0);
    var db: [4]f32 = @splat(0);
    var dbeta: [2]f32 = @splat(0);
    var dgamma: [2]f32 = @splat(0);

    var da_desc = vectorDesc(2, da[0..2]);
    var db_desc = vectorDesc(2, db[0..2]);
    var out_delta = vectorDesc(2, dy[0..2]);
    var beta_delta = vectorDesc(2, &dbeta);
    var gamma_delta = vectorDesc(2, &dgamma);

    const in_deltas = [_]*NDArrayDescriptor{ &da_desc, &db_desc };
    // The arithmetic layer has no trainable parameters, so the flat parameter
    // array is just the batch norm's (beta, gamma).
    const deltas = [_]?*NDArrayDescriptor{ &beta_delta, &gamma_delta };
    const inputs_nullable = [_]?*const anyopaque{ @ptrCast(&a), @ptrCast(&b) };
    try filter.fusedApplyBackwardMultiInputBatch(
        2,
        &inputs_nullable,
        &strides,
        &in_deltas,
        &strides,
        &y,
        2,
        &out_delta,
        2,
        &deltas,
    );

    // dbeta = sum_i dy_i, dgamma = sum_i dy_i * y_i, exactly as in the
    // single-input fused case.
    try testing.expectEqualSlices(f32, &.{ 1, 2 }, &dbeta);
    for ([_]f32{ -1, 2 }, dgamma) |e, got| try testing.expectApproxEqAbs(e, got, 1e-4);
    // Add passes its gradient through unchanged, and the batch-of-two batch
    // norm gradient is zero, so both input gradients are zero and equal.
    for (da, db) |x, z| {
        try testing.expectApproxEqAbs(@as(f32, 0), x, 1e-4);
        try testing.expectApproxEqAbs(x, z, 1e-6);
    }
}
