//! BNNS per-layer-type apply entry points.
//!
//! Most layer filters are driven by the generic `BNNSFilterApplyBatch`. Six
//! layer families cannot be: pooling carries optional argmax indices,
//! normalization needs a training/inference switch, arithmetic takes a variable
//! number of inputs, permute has no forward-pass data to feed a backward call,
//! and loss takes labels and weights alongside the input. Each of those gets
//! its own apply — and, where training is supported, its own backward apply.
//! This module wraps that set, plus the three `BNNSDirectApply*` calls that run
//! a layer without a filter object at all.
//!
//! **This entire file is the deprecated layer-filter API.** Apple deprecated it
//! in macOS 15.0 in favour of the Graph API (`bnns.Graph`), which compiles a
//! whole Core ML model instead of assembling one out of layer objects. It is
//! bound for callers whose deployment target predates macOS 15.0.
//! `BNNSDirectApplyBroadcastMatMul` went earlier still, in macOS 13.0, with a
//! named replacement: `BNNSMatMul`. Every declaration below repeats its own
//! deprecation version.
//!
//! ## Two things to get right
//!
//! *Strides are counted in values, not bytes.* Every `*_stride` parameter here
//! is the increment from one batch sample to the next, measured in elements of
//! the descriptor's data type. For a contiguous batch of rank-1 samples of
//! length `n`, the stride is `n`.
//!
//! *The layer parameters own the data pointers, the apply call owns the batch.*
//! A filter is created from a `LayerParameters*` struct whose descriptors give
//! the shapes; `data` in those descriptors may be null, because the forward
//! data is passed to the apply call. The `BNNSDirectApply*` calls invert that:
//! there is no apply-time input pointer, so `layer_params.i_desc.data` and
//! `.o_desc.data` must point at the first batch sample.
//!
//! ## Pooling has two generations of apply
//!
//! `poolingApplyBatch` (macOS 11.0) fixes the max-pool index type at `size_t`.
//! `poolingApplyBatchEx` (macOS 13.0) takes an explicit `indices_data_type` and
//! accepts `.uint64` or `.uint32` — the same call otherwise. Prefer the `Ex`
//! form: 32-bit indices halve the index traffic. `poolingApplyBackwardBatch`
//! and `poolingApplyBackwardBatchEx` stand in exactly the same relation.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const DataType = types.DataType;
const DataLayout = types.DataLayout;
const NDArrayDescriptor = types.NDArrayDescriptor;
const FilterParameters = types.FilterParameters;
const LayerParametersActivation = types.LayerParametersActivation;
const LayerParametersQuantization = types.LayerParametersQuantization;
const Error = types.Error;
const check = types.check;

/// `BNNSFilter` — the opaque layer-filter handle these calls act on, created by
/// the matching `BNNSFilterCreateLayer*` constructor and released with
/// `BNNSFilterDestroy`.
pub const Filter = c.BNNSFilter;

// ============================================================================
// Pooling
// ============================================================================

/// Apply a pooling filter to a batch, optionally recording max-pool indices.
///
/// `BNNSPoolingFilterApplyBatch`. `filter` must come from
/// `BNNSFilterCreateLayerPooling`. `in` and `out` point at the first sample;
/// `in_stride` and `out_stride` step between samples in values.
///
/// `indices` is `size_t`-typed and has the same shape and stride as the
/// output. For `.max` it receives the argmax positions if non-null and is
/// otherwise skipped; for `.un_max` (max un-pooling) it is a required *input*
/// and has the shape of the *input* instead; every other pooling function
/// ignores it.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn poolingApplyBatch(
    filter: Filter,
    batch_size: usize,
    in: *const anyopaque,
    in_stride: usize,
    out: *anyopaque,
    out_stride: usize,
    indices: ?[*]usize,
    idx_stride: usize,
) Error!void {
    return check(c.BNNSPoolingFilterApplyBatch(filter, batch_size, in, in_stride, out, out_stride, indices, idx_stride));
}

/// Apply a pooling filter to a batch with a caller-chosen index type.
///
/// `BNNSPoolingFilterApplyBatchEx`. Identical to `poolingApplyBatch` except
/// that `indices` is untyped and `indices_data_type` says how to read it; the
/// header allows `.uint64` and `.uint32` only. This is the later of the two
/// (macOS 13.0 against 11.0) and is the one to reach for — `poolingApplyBatch`
/// is exactly this call pinned to a `size_t` index.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn poolingApplyBatchEx(
    filter: Filter,
    batch_size: usize,
    in: *const anyopaque,
    in_stride: usize,
    out: *anyopaque,
    out_stride: usize,
    indices_data_type: DataType,
    indices: ?*anyopaque,
    idx_stride: usize,
) Error!void {
    return check(c.BNNSPoolingFilterApplyBatchEx(filter, batch_size, in, in_stride, out, out_stride, indices_data_type, indices, idx_stride));
}

/// Back-propagate through a pooling filter.
///
/// `BNNSPoolingFilterApplyBackwardBatch`, 13 parameters. `out_delta` is the
/// incoming output gradient and is required. `in_delta` and `bias_delta`
/// receive gradients and may each be null when that gradient is not wanted —
/// but every gradient that *is* wanted has to be produced by this one call,
/// there is no second pass. `in` is the forward input, `out` the forward
/// output; `out` is read only when the filter has a fused non-identity
/// activation. `indices` are the forward-pass `size_t` indices, which let max
/// pooling skip re-finding the argmax.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn poolingApplyBackwardBatch(
    filter: Filter,
    batch_size: usize,
    in: ?*const anyopaque,
    in_stride: usize,
    in_delta: ?*NDArrayDescriptor,
    in_delta_stride: usize,
    out: ?*const anyopaque,
    out_stride: usize,
    out_delta: *NDArrayDescriptor,
    out_delta_stride: usize,
    bias_delta: ?*NDArrayDescriptor,
    indices: ?[*]const usize,
    idx_stride: usize,
) Error!void {
    return check(c.BNNSPoolingFilterApplyBackwardBatch(filter, batch_size, in, in_stride, in_delta, in_delta_stride, out, out_stride, out_delta, out_delta_stride, bias_delta, indices, idx_stride));
}

/// Back-propagate through a pooling filter with a caller-chosen index type.
///
/// `BNNSPoolingFilterApplyBackwardBatchEx`, 14 parameters — one more than
/// `poolingApplyBackwardBatch`, the extra one being `indices_data_type`
/// immediately before `indices`. That is the only difference: `.uint64` or
/// `.uint32` indices instead of `size_t`. Introduced in macOS 13.0, so it is
/// the later of the pair.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn poolingApplyBackwardBatchEx(
    filter: Filter,
    batch_size: usize,
    in: ?*const anyopaque,
    in_stride: usize,
    in_delta: ?*NDArrayDescriptor,
    in_delta_stride: usize,
    out: ?*const anyopaque,
    out_stride: usize,
    out_delta: *NDArrayDescriptor,
    out_delta_stride: usize,
    bias_delta: ?*NDArrayDescriptor,
    indices_data_type: DataType,
    indices: ?*const anyopaque,
    idx_stride: usize,
) Error!void {
    return check(c.BNNSPoolingFilterApplyBackwardBatchEx(filter, batch_size, in, in_stride, in_delta, in_delta_stride, out, out_stride, out_delta, out_delta_stride, bias_delta, indices_data_type, indices, idx_stride));
}

// ============================================================================
// Normalization
// ============================================================================

/// Apply a normalization filter to a batch.
///
/// `BNNSNormalizationFilterApplyBatch`. `filter` comes from
/// `BNNSFilterCreateLayerNormalization`, whose `FilterType` argument picks
/// batch, instance, layer or group normalization.
///
/// `training` is the whole reason this call exists rather than
/// `BNNSFilterApplyBatch`. When true, the input is normalized by the current
/// batch/instance/layer/group statistics, the moving mean and variance are
/// updated (batch and instance norm only, and only if their descriptors have
/// data), and state may be cached internally for the backward pass. When
/// false, the moving statistics are used if present and the current ones
/// otherwise. In-place — `out` equal to `in` — is supported in both modes.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn normalizationApplyBatch(
    filter: Filter,
    batch_size: usize,
    in: *const anyopaque,
    in_stride: usize,
    out: *anyopaque,
    out_stride: usize,
    training: bool,
) Error!void {
    return check(c.BNNSNormalizationFilterApplyBatch(filter, batch_size, in, in_stride, out, out_stride, training));
}

/// Back-propagate through a normalization filter.
///
/// `BNNSNormalizationFilterApplyBackwardBatch`. Produces the input gradient
/// plus the gradients of the trainable shift and scale; each of `in_delta`,
/// `beta_delta` and `gamma_delta` may be null to skip it, and all the ones that
/// are wanted must be produced in this single call. `in_delta`, `out_delta`,
/// `beta_delta` and `gamma_delta` must all be `.float32` or `.bfloat16`
/// whatever the forward data type. `out` is the forward output and is ignored
/// unless the filter has a fused non-identity activation, in which case it is
/// required. Note `out_delta` may be scribbled on while the fused activation
/// backward is computed.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn normalizationApplyBackwardBatch(
    filter: Filter,
    batch_size: usize,
    in_delta: ?*NDArrayDescriptor,
    in_delta_stride: usize,
    out: ?*const anyopaque,
    out_stride: usize,
    out_delta: *NDArrayDescriptor,
    out_delta_stride: usize,
    beta_delta: ?*NDArrayDescriptor,
    gamma_delta: ?*NDArrayDescriptor,
) Error!void {
    return check(c.BNNSNormalizationFilterApplyBackwardBatch(filter, batch_size, in_delta, in_delta_stride, out, out_stride, out_delta, out_delta_stride, beta_delta, gamma_delta));
}

// ============================================================================
// Arithmetic
// ============================================================================

/// Apply an arithmetic filter to a batch of input sets.
///
/// `BNNSArithmeticFilterApplyBatch`. `filter` comes from
/// `BNNSFilterCreateLayerArithmetic`. An arithmetic layer has as many inputs as
/// its `ArithmeticFunction` is arity: `in` is an array of `number_of_inputs`
/// data pointers and `in_stride` a parallel array of `number_of_inputs` batch
/// strides. Both arrays must be that long — a short `in_stride` is read out of
/// bounds, and nothing in the C signature stops it.
///
/// Inputs broadcast: two operand shapes are compatible when each dimension is
/// either equal or 1. `batch_size` is ignored for any operand declared
/// `.constant` or `.parameter` in the layer's operand struct. Two entries of
/// `in` may alias, in which case the corresponding backward gradients must
/// alias too.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn arithmeticApplyBatch(
    filter: Filter,
    batch_size: usize,
    number_of_inputs: usize,
    in: [*]const *const anyopaque,
    in_stride: [*]const usize,
    out: *anyopaque,
    out_stride: usize,
) Error!void {
    return check(c.BNNSArithmeticFilterApplyBatch(filter, batch_size, number_of_inputs, in, in_stride, out, out_stride));
}

/// Back-propagate through an arithmetic filter.
///
/// `BNNSArithmeticFilterApplyBackwardBatch`, 11 parameters. Every input
/// gradient must be computed in this one call: `in_delta` is a non-null array
/// of `number_of_inputs` descriptor pointers, with `in_delta_stride` a parallel
/// array of strides. `in`/`in_stride` hold the forward inputs and may be null
/// for functions whose backward does not need them. `out` is the forward
/// output; it is required when the layer has a fused activation and is
/// optional (but sometimes faster) otherwise.
///
/// If two forward inputs aliased, their gradient descriptors must alias too.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn arithmeticApplyBackwardBatch(
    filter: Filter,
    batch_size: usize,
    number_of_inputs: usize,
    in: ?[*]const ?*const anyopaque,
    in_stride: ?[*]const usize,
    in_delta: [*]*NDArrayDescriptor,
    in_delta_stride: [*]const usize,
    out: ?*const anyopaque,
    out_stride: usize,
    out_delta: *NDArrayDescriptor,
    out_delta_stride: usize,
) Error!void {
    return check(c.BNNSArithmeticFilterApplyBackwardBatch(filter, batch_size, number_of_inputs, in, in_stride, in_delta, in_delta_stride, out, out_stride, out_delta, out_delta_stride));
}

// ============================================================================
// Permute
// ============================================================================

/// Back-propagate through a permute filter.
///
/// `BNNSPermuteFilterApplyBackwardBatch`. A permutation is its own inverse
/// structure: this scatters `out_delta` back through the layer's axis
/// permutation into `in_delta`, so `in_delta` has the *input* shape and
/// `out_delta` the *output* shape. There is no forward-pass data to pass in,
/// which is why the generic backward apply does not fit.
///
/// The forward direction has no specialized entry point — use
/// `BNNSFilterApplyBatch` for that.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn permuteApplyBackwardBatch(
    filter: Filter,
    batch_size: usize,
    in_delta: *NDArrayDescriptor,
    in_delta_stride: usize,
    out_delta: *const NDArrayDescriptor,
    out_delta_stride: usize,
) Error!void {
    return check(c.BNNSPermuteFilterApplyBackwardBatch(filter, batch_size, in_delta, in_delta_stride, out_delta, out_delta_stride));
}

// ============================================================================
// Loss
// ============================================================================

/// Compute a loss over a batch, and optionally its input gradient.
///
/// `BNNSLossFilterApplyBatch`, 11 parameters. `filter` comes from
/// `BNNSFilterCreateLayerLoss`.
///
/// `out` receives the loss: one value if the layer's `LossReductionFunction`
/// reduces, and otherwise a contiguous run — `batch_size` values for softmax
/// cross entropy, `batch_size * i_desc.size[0]` for sigmoid cross entropy, MSE
/// and Huber.
///
/// `weights_size` is a count, not a byte size, and must be 0 (no weighting), 1
/// (one weight for the whole batch), or the per-sample count: `batch_size` for
/// softmax cross entropy, `batch_size * i_desc.size[0]` for the others.
///
/// `in_delta` is an optimization for the common case where the loss is the last
/// layer: pass a descriptor to get the input gradient computed here without a
/// separate backward pass, or null to skip it.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn lossApplyBatch(
    filter: Filter,
    batch_size: usize,
    in: *const anyopaque,
    in_stride: usize,
    labels: *const anyopaque,
    labels_stride: usize,
    weights: ?*const anyopaque,
    weights_size: usize,
    out: *anyopaque,
    in_delta: ?*NDArrayDescriptor,
    in_delta_stride: usize,
) Error!void {
    return check(c.BNNSLossFilterApplyBatch(filter, batch_size, in, in_stride, labels, labels_stride, weights, weights_size, out, in_delta, in_delta_stride));
}

/// Back-propagate through a loss filter from an incoming output gradient.
///
/// `BNNSLossFilterApplyBackwardBatch`, 12 parameters. Use this when the loss
/// is *not* the last layer, i.e. when there is a real `out_delta` to chain
/// from; when it is the last layer, `lossApplyBatch`'s `in_delta` parameter
/// does the same job in one pass and is cheaper.
///
/// `weights` and `weights_size` follow the same rules as in `lossApplyBatch`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn lossApplyBackwardBatch(
    filter: Filter,
    batch_size: usize,
    in: *const anyopaque,
    in_stride: usize,
    in_delta: *NDArrayDescriptor,
    in_delta_stride: usize,
    labels: *const anyopaque,
    labels_stride: usize,
    weights: ?*const anyopaque,
    weights_size: usize,
    out_delta: *const NDArrayDescriptor,
    out_delta_stride: usize,
) Error!void {
    return check(c.BNNSLossFilterApplyBackwardBatch(filter, batch_size, in, in_stride, in_delta, in_delta_stride, labels, labels_stride, weights, weights_size, out_delta, out_delta_stride));
}

// ============================================================================
// Filter-free direct applies
// ============================================================================

/// Apply an activation (or a type conversion) to a batch without creating a
/// filter.
///
/// `BNNSDirectApplyActivationBatch` — equivalent to create, apply, destroy in
/// one call, so it is the right choice for a one-shot application and the wrong
/// one inside a loop.
///
/// The data pointers live in the layer parameters, not in the argument list:
/// set `layer_params.i_desc.data` and `layer_params.o_desc.data` to the first
/// input and output sample, and let `in_stride`/`out_stride` walk the batch.
///
/// With `layer_params.activation.function` left at `.identity` and differing
/// input and output data types, this is a conversion layer rather than an
/// activation.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn directApplyActivationBatch(
    layer_params: *const LayerParametersActivation,
    filter_params: ?*const FilterParameters,
    batch_size: usize,
    in_stride: usize,
    out_stride: usize,
) Error!void {
    return check(c.BNNSDirectApplyActivationBatch(layer_params, filter_params, batch_size, in_stride, out_stride));
}

/// Quantize or dequantize a batch without creating a filter.
///
/// `BNNSDirectApplyQuantizer`. `layer_params.function` picks the direction:
/// `.quantize` computes `y = scale*x + bias` into the lower-precision output,
/// `.dequantize` computes `y = (x - bias)/scale`. As with
/// `directApplyActivationBatch`, the data pointers come from
/// `layer_params.i_desc.data` and `.o_desc.data`.
///
/// `scale` and `bias` are optional (null `data` means "not applied") and must
/// use the `.vector` layout. `layer_params.axis_mask` selects the single axis
/// they vary along, with their length equal to that axis's size; an
/// `axis_mask` of 0 means one scalar scale and bias for the whole tensor, and
/// then the vectors are length 1. The descriptors' own `data_scale` and
/// `data_bias` fields are ignored here.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn directApplyQuantizer(
    layer_params: *const LayerParametersQuantization,
    filter_params: ?*const FilterParameters,
    batch_size: usize,
    input_stride: usize,
    output_stride: usize,
) Error!void {
    return check(c.BNNSDirectApplyQuantizer(layer_params, filter_params, batch_size, input_stride, output_stride));
}

/// Multiply two tensors with broadcasting, without creating a filter.
///
/// `BNNSDirectApplyBroadcastMatMul` computes `output = alpha * op(A) * op(B)`,
/// where `op` transposes the last two dimensions when the matching `trans` flag
/// is set. Dimensions beyond the last two broadcast. Only `output.data` is
/// written; the rest of that descriptor is read.
///
/// This one returns `void` — there is no status to check, so a malformed call
/// reports through the message log and leaves the output untouched rather than
/// returning an error. It is the only function in this module that cannot
/// fail loudly.
///
/// Deprecated in macOS 13.0 with replacement `BNNSMatMul`. (The rest of this
/// module went in macOS 15.0; this one went two releases earlier.)
pub fn directApplyBroadcastMatMul(
    trans_a: bool,
    trans_b: bool,
    alpha: f32,
    input_a: *const NDArrayDescriptor,
    input_b: *const NDArrayDescriptor,
    output: *const NDArrayDescriptor,
    filter_params: ?*const FilterParameters,
) void {
    c.BNNSDirectApplyBroadcastMatMul(trans_a, trans_b, alpha, input_a, input_b, output, filter_params);
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

// The filter-based tests below build their filters by calling the
// `BNNSFilterCreateLayer*` constructors in `c.zig` directly. They are meant to
// go through the wrappers in `layers.zig`, which was still a three-line stub
// when this module was written; switch them over once it lands.

/// A rank-1 `.vector` descriptor over `data`.
fn vec(comptime T: type, data: []T) NDArrayDescriptor {
    var d = NDArrayDescriptor{ .layout = .vector, .data_type = DataType.of(T) };
    d.size[0] = data.len;
    d.data = @ptrCast(data.ptr);
    return d;
}

/// A rank-1 `.vector` descriptor of `len` elements with no data attached.
fn vecShape(comptime T: type, len: usize) NDArrayDescriptor {
    var d = NDArrayDescriptor{ .layout = .vector, .data_type = DataType.of(T) };
    d.size[0] = len;
    return d;
}

/// A `.image_chw` descriptor: `size` is `{ width, height, channels }`.
fn chw(comptime T: type, w: usize, h: usize, ch: usize, data: ?[]T) NDArrayDescriptor {
    var d = NDArrayDescriptor{ .layout = .image_chw, .data_type = DataType.of(T) };
    d.size[0] = w;
    d.size[1] = h;
    d.size[2] = ch;
    if (data) |s| d.data = @ptrCast(s.ptr);
    return d;
}

test "directApplyActivationBatch runs ReLU over a batch of two" {
    var in = [_]f32{ -1, 0, 2, -3, 4, -5 };
    var out: [6]f32 = @splat(-99);

    const params = LayerParametersActivation{
        .i_desc = vec(f32, in[0..3]),
        .o_desc = vec(f32, out[0..3]),
        .activation = .{ .function = .rectified_linear },
    };
    // Descriptors cover one sample of 3; the strides walk the other sample.
    try directApplyActivationBatch(&params, null, 2, 3, 3);

    try testing.expectEqualSlices(f32, &.{ 0, 0, 2, 0, 4, 0 }, &out);
}

test "directApplyActivationBatch computes leaky ReLU with alpha" {
    var in = [_]f32{ -4, -1, 0, 3 };
    var out: [4]f32 = @splat(-99);

    const params = LayerParametersActivation{
        .i_desc = vec(f32, &in),
        .o_desc = vec(f32, &out),
        // alpha*x for x < 0, x otherwise.
        .activation = .{ .function = .leaky_rectified_linear, .alpha = 0.25 },
    };
    try directApplyActivationBatch(&params, null, 1, 0, 0);

    try testing.expectEqualSlices(f32, &.{ -1, -0.25, 0, 3 }, &out);
}

test "directApplyActivationBatch with identity converts between data types" {
    // An identity activation whose input and output data types differ is a
    // conversion layer, per the header.
    var in = [_]f32{ 1.5, -2.5, 300.25, 4 };
    var out: [4]i32 = @splat(-99);

    var o_desc = NDArrayDescriptor{ .layout = .vector, .data_type = .int32 };
    o_desc.size[0] = 4;
    o_desc.data = @ptrCast(&out);

    const params = LayerParametersActivation{
        .i_desc = vec(f32, &in),
        .o_desc = o_desc,
        .activation = .{ .function = .identity },
    };
    try directApplyActivationBatch(&params, null, 1, 0, 0);

    // Round-to-nearest-even: 1.5 -> 2, -2.5 -> -2.
    try testing.expectEqualSlices(i32, &.{ 2, -2, 300, 4 }, &out);
}

test "directApplyQuantizer applies y = scale*x + bias" {
    var in = [_]f32{ 0, 2, 4, 6 };
    var out: [4]i8 = @splat(-99);
    var scale = [_]f32{0.5};
    var bias = [_]f32{1};

    var o_desc = NDArrayDescriptor{ .layout = .vector, .data_type = .int8 };
    o_desc.size[0] = 4;
    o_desc.data = @ptrCast(&out);

    const params = LayerParametersQuantization{
        // 0: one scalar scale and bias over the whole tensor.
        .axis_mask = 0,
        .function = .quantize,
        .i_desc = vec(f32, &in),
        .o_desc = o_desc,
        .scale = vec(f32, &scale),
        .bias = vec(f32, &bias),
    };
    try directApplyQuantizer(&params, null, 1, 0, 0);

    // y = 0.5*x + 1 over {0, 2, 4, 6}.
    try testing.expectEqualSlices(i8, &.{ 1, 2, 3, 4 }, &out);
}

test "directApplyQuantizer dequantizes back with y = (x - bias)/scale" {
    var in = [_]i8{ 1, 2, 3, 4 };
    var out: [4]f32 = @splat(-99);
    var scale = [_]f32{0.5};
    var bias = [_]f32{1};

    var i_desc = NDArrayDescriptor{ .layout = .vector, .data_type = .int8 };
    i_desc.size[0] = 4;
    i_desc.data = @ptrCast(&in);

    const params = LayerParametersQuantization{
        .axis_mask = 0,
        .function = .dequantize,
        .i_desc = i_desc,
        .o_desc = vec(f32, &out),
        .scale = vec(f32, &scale),
        .bias = vec(f32, &bias),
    };
    try directApplyQuantizer(&params, null, 1, 0, 0);

    // The exact inverse of the previous test.
    try testing.expectEqualSlices(f32, &.{ 0, 2, 4, 6 }, &out);
}

test "directApplyBroadcastMatMul multiplies a 2x3 by a 3x2 and scales" {
    // Row-major matrix layout: size[0] is the column count, size[1] the row
    // count, so a 2x3 matrix has size = { 3, 2 }.
    var a = [_]f32{ 1, 2, 3, 4, 5, 6 }; // 2x3
    var b = [_]f32{ 7, 8, 9, 10, 11, 12 }; // 3x2
    var out: [4]f32 = @splat(-99);

    var da = NDArrayDescriptor{ .layout = .row_major_matrix, .data_type = .float32 };
    da.size[0] = 3;
    da.size[1] = 2;
    da.data = @ptrCast(&a);

    var db = NDArrayDescriptor{ .layout = .row_major_matrix, .data_type = .float32 };
    db.size[0] = 2;
    db.size[1] = 3;
    db.data = @ptrCast(&b);

    var dc = NDArrayDescriptor{ .layout = .row_major_matrix, .data_type = .float32 };
    dc.size[0] = 2;
    dc.size[1] = 2;
    dc.data = @ptrCast(&out);

    directApplyBroadcastMatMul(false, false, 2, &da, &db, &dc, null);

    // A*B = [[58, 64], [139, 154]], times alpha = 2.
    try testing.expectEqualSlices(f32, &.{ 116, 128, 278, 308 }, &out);
}

test "directApplyBroadcastMatMul transposes the last two dimensions of B" {
    var a = [_]f32{ 1, 2, 3, 4, 5, 6 }; // 2x3
    // The previous test's B, transposed: 2x3 holding B^T.
    var bt = [_]f32{ 7, 9, 11, 8, 10, 12 };
    var out: [4]f32 = @splat(-99);

    var da = NDArrayDescriptor{ .layout = .row_major_matrix, .data_type = .float32 };
    da.size[0] = 3;
    da.size[1] = 2;
    da.data = @ptrCast(&a);

    var db = NDArrayDescriptor{ .layout = .row_major_matrix, .data_type = .float32 };
    db.size[0] = 3;
    db.size[1] = 2;
    db.data = @ptrCast(&bt);

    var dc = NDArrayDescriptor{ .layout = .row_major_matrix, .data_type = .float32 };
    dc.size[0] = 2;
    dc.size[1] = 2;
    dc.data = @ptrCast(&out);

    directApplyBroadcastMatMul(false, true, 1, &da, &db, &dc, null);

    // Same product as above with alpha = 1.
    try testing.expectEqualSlices(f32, &.{ 58, 64, 139, 154 }, &out);
}

/// 2x2 max pooling, stride 2, over a single-channel 4x4 image.
fn makeMaxPoolFilter() Error!Filter {
    var params = types.LayerParametersPooling{
        .i_desc = chw(f32, 4, 4, 1, null),
        .o_desc = chw(f32, 2, 2, 1, null),
        .bias = .{ .layout = .vector, .data_type = .float32 },
        .activation = .{ .function = .identity },
        .pooling_function = .max,
        .k_width = 2,
        .k_height = 2,
        .x_stride = 2,
        .y_stride = 2,
    };
    params.bias.size[0] = 1;
    const f = c.BNNSFilterCreateLayerPooling(&params, null);
    if (f == null) return Error.BnnsAllocationFailed;
    return f;
}

const pool_in = [_]f32{
    1,  2,  3,  4,
    5,  6,  7,  8,
    9,  10, 11, 12,
    13, 14, 15, 16,
};

test "poolingApplyBatch max-pools and records size_t argmax indices" {
    const filter = try makeMaxPoolFilter();
    defer c.BNNSFilterDestroy(filter);

    var in = pool_in ++ pool_in;
    // Second sample is the first one negated, so its maxima sit elsewhere.
    for (in[16..]) |*v| v.* = -v.*;

    var out: [8]f32 = @splat(-99);
    var indices: [8]usize = @splat(std.math.maxInt(usize));

    try poolingApplyBatch(filter, 2, @ptrCast(&in), 16, @ptrCast(&out), 4, &indices, 4);

    // Windows of the first sample: {1,2,5,6} {3,4,7,8} {9,10,13,14} {11,12,15,16}.
    try testing.expectEqualSlices(f32, &.{ 6, 8, 14, 16 }, out[0..4]);
    // Negated, the maximum of each window is the smallest original value.
    try testing.expectEqualSlices(f32, &.{ -1, -3, -9, -11 }, out[4..8]);
    // Flat positions of those maxima within the 4x4 input.
    try testing.expectEqualSlices(usize, &.{ 5, 7, 13, 15 }, indices[0..4]);
    try testing.expectEqualSlices(usize, &.{ 0, 2, 8, 10 }, indices[4..8]);
}

test "poolingApplyBatchEx writes the same indices as uint32" {
    const filter = try makeMaxPoolFilter();
    defer c.BNNSFilterDestroy(filter);

    var in = pool_in;
    var out: [4]f32 = @splat(-99);
    var indices: [4]u32 = @splat(0xffffffff);

    try poolingApplyBatchEx(filter, 1, @ptrCast(&in), 0, @ptrCast(&out), 0, .uint32, @ptrCast(&indices), 0);

    try testing.expectEqualSlices(f32, &.{ 6, 8, 14, 16 }, &out);
    // Identical to the size_t indices from `poolingApplyBatch`, just narrower.
    try testing.expectEqualSlices(u32, &.{ 5, 7, 13, 15 }, &indices);
}

test "poolingApplyBackwardBatch routes the gradient to the argmax positions" {
    const filter = try makeMaxPoolFilter();
    defer c.BNNSFilterDestroy(filter);

    var in = pool_in;
    var out: [4]f32 = @splat(0);
    var indices: [4]usize = @splat(0);
    try poolingApplyBatch(filter, 1, @ptrCast(&in), 0, @ptrCast(&out), 0, &indices, 0);

    // One unit of gradient per output element, distinguishable per window.
    var out_grad = [_]f32{ 1, 2, 3, 4 };
    var in_grad: [16]f32 = @splat(-99);

    var in_delta = chw(f32, 4, 4, 1, in_grad[0..]);
    var out_delta = chw(f32, 2, 2, 1, out_grad[0..]);

    try poolingApplyBackwardBatch(
        filter,
        1,
        @ptrCast(&in),
        0,
        &in_delta,
        0,
        null,
        0,
        &out_delta,
        0,
        null,
        &indices,
        0,
    );

    // Max pooling sends each output gradient to the winning input only.
    const expected = [_]f32{
        0, 0, 0, 0,
        0, 1, 0, 2,
        0, 0, 0, 0,
        0, 3, 0, 4,
    };
    try testing.expectEqualSlices(f32, &expected, &in_grad);
}

test "poolingApplyBackwardBatchEx accepts uint32 indices" {
    const filter = try makeMaxPoolFilter();
    defer c.BNNSFilterDestroy(filter);

    var in = pool_in;
    var out: [4]f32 = @splat(0);
    var indices: [4]u32 = @splat(0);
    try poolingApplyBatchEx(filter, 1, @ptrCast(&in), 0, @ptrCast(&out), 0, .uint32, @ptrCast(&indices), 0);

    var out_grad = [_]f32{ 1, 2, 3, 4 };
    var in_grad: [16]f32 = @splat(-99);
    var in_delta = chw(f32, 4, 4, 1, in_grad[0..]);
    var out_delta = chw(f32, 2, 2, 1, out_grad[0..]);

    try poolingApplyBackwardBatchEx(
        filter,
        1,
        @ptrCast(&in),
        0,
        &in_delta,
        0,
        null,
        0,
        &out_delta,
        0,
        null,
        .uint32,
        @ptrCast(&indices),
        0,
    );

    const expected = [_]f32{
        0, 0, 0, 0,
        0, 1, 0, 2,
        0, 0, 0, 0,
        0, 3, 0, 4,
    };
    try testing.expectEqualSlices(f32, &expected, &in_grad);
}

test "normalizationApplyBatch layer-normalizes each sample independently" {
    var params = types.LayerParametersNormalization{
        .i_desc = chw(f32, 4, 1, 1, null),
        .o_desc = chw(f32, 4, 1, 1, null),
        .beta_desc = vecShape(f32, 1),
        .gamma_desc = vecShape(f32, 1),
        .moving_mean_desc = vecShape(f32, 1),
        .moving_variance_desc = vecShape(f32, 1),
        .momentum = 0,
        .epsilon = 0,
        .activation = .{ .function = .identity },
        .num_groups = 0,
        .normalization_axis = 0,
    };
    const filter = c.BNNSFilterCreateLayerNormalization(.layer_norm, &params, null);
    if (filter == null) return Error.BnnsAllocationFailed;
    defer c.BNNSFilterDestroy(filter);

    var in = [_]f32{ 1, 2, 3, 4 };
    var out: [4]f32 = @splat(-99);
    try normalizationApplyBatch(filter, 1, @ptrCast(&in), 4, @ptrCast(&out), 4, false);

    // mean 2.5, population variance 1.25, so sigma = sqrt(1.25) = 1.118034.
    const sigma = @sqrt(1.25);
    const expected = [_]f32{ -1.5 / sigma, -0.5 / sigma, 0.5 / sigma, 1.5 / sigma };
    for (expected, out) |e, o| try testing.expectApproxEqAbs(e, o, 1e-4);
}

test "normalizationApplyBackwardBatch differentiates the layer norm" {
    var params = types.LayerParametersNormalization{
        .i_desc = chw(f32, 4, 1, 1, null),
        .o_desc = chw(f32, 4, 1, 1, null),
        .beta_desc = vecShape(f32, 1),
        .gamma_desc = vecShape(f32, 1),
        .moving_mean_desc = vecShape(f32, 1),
        .moving_variance_desc = vecShape(f32, 1),
        .momentum = 0,
        .epsilon = 0,
        .activation = .{ .function = .identity },
        .num_groups = 0,
        .normalization_axis = 0,
    };
    const filter = c.BNNSFilterCreateLayerNormalization(.layer_norm, &params, null);
    if (filter == null) return Error.BnnsAllocationFailed;
    defer c.BNNSFilterDestroy(filter);

    // The backward pass consumes state cached by a *training* forward pass, so
    // the pair has to be run in order on the same filter.
    var in = [_]f32{ 1, 2, 3, 4 };
    var out: [4]f32 = @splat(0);
    try normalizationApplyBatch(filter, 1, @ptrCast(&in), 4, @ptrCast(&out), 4, true);

    var out_grad = [_]f32{ 1, 0, 0, 0 };
    var in_grad: [4]f32 = @splat(-99);
    var out_delta = chw(f32, 4, 1, 1, out_grad[0..]);
    var in_delta = chw(f32, 4, 1, 1, in_grad[0..]);

    try normalizationApplyBackwardBatch(filter, 1, &in_delta, 4, null, 0, &out_delta, 4, null, null);

    // dx_i = (dy_i - mean(dy) - xhat_i*mean(dy*xhat)) / sigma, with
    // sigma = sqrt(1.25), xhat = {-1.5, -0.5, 0.5, 1.5}/sigma, mean(dy) = 0.25
    // and mean(dy*xhat) = -1.5/(4*sigma).
    const sigma = @sqrt(1.25);
    var expected: [4]f32 = undefined;
    for (&expected, out_grad, [_]f32{ -1.5, -0.5, 0.5, 1.5 }) |*e, dy, centred| {
        const xhat = centred / sigma;
        e.* = (dy - 0.25 - xhat * (-1.5 / (4 * sigma))) / sigma;
    }
    for (expected, in_grad) |e, g| try testing.expectApproxEqAbs(e, g, 1e-4);
    // The layer-norm gradient sums to zero: it is orthogonal to a constant
    // shift of the input.
    try testing.expectApproxEqAbs(@as(f32, 0), in_grad[0] + in_grad[1] + in_grad[2] + in_grad[3], 1e-5);
}

test "arithmeticApplyBatch adds two inputs elementwise over a batch" {
    var fields = types.ArithmeticBinary{
        .in1 = vecShape(f32, 3),
        .in1_type = .sample,
        .in2 = vecShape(f32, 3),
        .in2_type = .sample,
        .out = vecShape(f32, 3),
        .out_type = .sample,
    };
    var params = types.LayerParametersArithmetic{
        .arithmetic_function = .add,
        .arithmetic_function_fields = @ptrCast(&fields),
        .activation = .{ .function = .identity },
    };
    const filter = c.BNNSFilterCreateLayerArithmetic(&params, null);
    if (filter == null) return Error.BnnsAllocationFailed;
    defer c.BNNSFilterDestroy(filter);

    var a = [_]f32{ 1, 2, 3, 10, 20, 30 };
    var b = [_]f32{ 0.5, 0.5, 0.5, -1, -2, -3 };
    var out: [6]f32 = @splat(-99);

    const ins = [_]*const anyopaque{ @ptrCast(&a), @ptrCast(&b) };
    const strides = [_]usize{ 3, 3 };
    try arithmeticApplyBatch(filter, 2, 2, &ins, &strides, @ptrCast(&out), 3);

    try testing.expectEqualSlices(f32, &.{ 1.5, 2.5, 3.5, 9, 18, 27 }, &out);
}

test "arithmeticApplyBackwardBatch passes the gradient through an add unchanged" {
    var fields = types.ArithmeticBinary{
        .in1 = vecShape(f32, 3),
        .in1_type = .sample,
        .in2 = vecShape(f32, 3),
        .in2_type = .sample,
        .out = vecShape(f32, 3),
        .out_type = .sample,
    };
    var params = types.LayerParametersArithmetic{
        .arithmetic_function = .add,
        .arithmetic_function_fields = @ptrCast(&fields),
        .activation = .{ .function = .identity },
    };
    const filter = c.BNNSFilterCreateLayerArithmetic(&params, null);
    if (filter == null) return Error.BnnsAllocationFailed;
    defer c.BNNSFilterDestroy(filter);

    var grad_a: [3]f32 = @splat(-99);
    var grad_b: [3]f32 = @splat(-99);
    var d_a = vec(f32, &grad_a);
    var d_b = vec(f32, &grad_b);
    var in_delta = [_]*NDArrayDescriptor{ &d_a, &d_b };
    const in_delta_strides = [_]usize{ 3, 3 };

    var out_grad = [_]f32{ 1, 2, 3 };
    var out_delta = vec(f32, &out_grad);

    try arithmeticApplyBackwardBatch(filter, 1, 2, null, null, &in_delta, &in_delta_strides, null, 3, &out_delta, 3);

    // d(a+b)/da = d(a+b)/db = 1, so both gradients equal the output gradient.
    try testing.expectEqualSlices(f32, &.{ 1, 2, 3 }, &grad_a);
    try testing.expectEqualSlices(f32, &.{ 1, 2, 3 }, &grad_b);
}

test "permuteApplyBackwardBatch transposes the gradient back" {
    var i_desc = NDArrayDescriptor{ .layout = .@"2d_first_major", .data_type = .float32 };
    i_desc.size[0] = 2;
    i_desc.size[1] = 3;
    var o_desc = NDArrayDescriptor{ .layout = .@"2d_first_major", .data_type = .float32 };
    o_desc.size[0] = 3;
    o_desc.size[1] = 2;

    var permutation: [types.max_tensor_dimension]usize = @splat(0);
    permutation[0] = 1;
    permutation[1] = 0;

    var params = types.LayerParametersPermute{
        .i_desc = i_desc,
        .o_desc = o_desc,
        .permutation = permutation,
    };
    const filter = c.BNNSFilterCreateLayerPermute(&params, null);
    if (filter == null) return Error.BnnsAllocationFailed;
    defer c.BNNSFilterDestroy(filter);

    // Output gradient has the output shape (3x2 in first-major order).
    var out_grad = [_]f32{ 1, 2, 3, 4, 5, 6 };
    var in_grad: [6]f32 = @splat(-99);

    var in_delta = i_desc;
    in_delta.data = @ptrCast(&in_grad);
    var out_delta = o_desc;
    out_delta.data = @ptrCast(&out_grad);

    try permuteApplyBackwardBatch(filter, 1, &in_delta, 6, &out_delta, 6);

    // The backward of a transpose is a transpose.
    try testing.expectEqualSlices(f32, &.{ 1, 3, 5, 2, 4, 6 }, &in_grad);
}

test "lossApplyBatch computes an unreduced mean-square error and its gradient" {
    var params = types.LayerParametersLossBase{
        .function = .mean_square_error,
        .i_desc = vecShape(f32, 3),
        .o_desc = vecShape(f32, 3),
        .reduction = .none,
    };
    const filter = c.BNNSFilterCreateLayerLoss(@ptrCast(&params), null);
    if (filter == null) return Error.BnnsAllocationFailed;
    defer c.BNNSFilterDestroy(filter);

    var in = [_]f32{ 1, 2, 3 };
    var labels = [_]f32{ 0, 0, 0 };
    var out: [3]f32 = @splat(-99);
    var grad: [3]f32 = @splat(-99);
    var in_delta = vec(f32, &grad);

    try lossApplyBatch(filter, 1, @ptrCast(&in), 3, @ptrCast(&labels), 3, null, 0, @ptrCast(&out), &in_delta, 3);

    try testing.expectEqualSlices(f32, &.{ 1, 4, 9 }, &out);
    try testing.expectEqualSlices(f32, &.{ 2, 4, 6 }, &grad);
}

test "lossApplyBackwardBatch chains an incoming output gradient" {
    var params = types.LayerParametersLossBase{
        .function = .mean_square_error,
        .i_desc = vecShape(f32, 3),
        .o_desc = vecShape(f32, 3),
        .reduction = .none,
    };
    const filter = c.BNNSFilterCreateLayerLoss(@ptrCast(&params), null);
    if (filter == null) return Error.BnnsAllocationFailed;
    defer c.BNNSFilterDestroy(filter);

    var in = [_]f32{ 1, 2, 3 };
    var labels = [_]f32{ 0, 0, 0 };
    var grad: [3]f32 = @splat(-99);
    var in_delta = vec(f32, &grad);

    var out_grad = [_]f32{ 1, 1, 1 };
    var out_delta = vec(f32, &out_grad);

    try lossApplyBackwardBatch(filter, 1, @ptrCast(&in), 3, &in_delta, 3, @ptrCast(&labels), 3, null, 0, &out_delta, 3);

    try testing.expectEqualSlices(f32, &.{ 2, 4, 6 }, &grad);
}
