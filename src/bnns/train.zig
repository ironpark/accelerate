//! BNNS training support: the optimizer step, gradient clipping, tensor norms,
//! the sparse fully-connected weight converters, and the LSTM and multihead
//! attention apply calls.
//!
//! Every entry point in this file belongs to the first-generation
//! *layer-filter* API, which Apple deprecated in macOS 15.0 in favour of the
//! Graph API (`bnns.Graph`, in `graph.zig`). Nothing here is removed — it still
//! links and runs — but a new deployment target above macOS 15.0 should compile
//! a Core ML model and execute it through a `Graph` instead. The individual
//! deprecation versions differ (macOS 11.0/12.0/13.0 introductions, all
//! deprecated in 15.0) and each wrapper records its own.
//!
//! Facts a caller needs:
//!
//! * `axis_flags` on the clip/norm calls is a *bitmask of dimensions*, one bit
//!   per axis of the source descriptor, naming the axes the L2 norm is taken
//!   over. Zero means "all axes", which is the common case and yields a scalar.
//!   The reduced axes are dropped from the destination shape; when all axes are
//!   reduced the destination must be `DataLayout.vector` with `size[0] = 1`.
//! * `optimizerStep` updates many parameters in one call, and the number of
//!   accumulator descriptors it wants depends on the algorithm: SGD needs one
//!   per parameter (none at all if `momentum == 0`), Adam/AdamW two per
//!   parameter, their AMSGrad variants three, RMSProp one plus one for each of
//!   `centered` and a nonzero `momentum`. Accumulators are a flat array of
//!   `k * number_of_parameters` pointers, grouped by role and *not* by
//!   parameter, and the caller must zero them before the first step.
//! * The `*Fields` block passed as `alg_fields` is re-read on every step and
//!   never copied, so a learning-rate schedule can just mutate it in place. Its
//!   type must match `function`; passing the wrong one is not detected.
//! * The LSTM calls are "direct apply": there is no filter object, the whole
//!   network lives in one `LayerParametersLSTM` block, and the data pointers
//!   live inside the descriptors rather than being passed alongside. The
//!   training cache is a plain byte buffer whose minimum size comes from
//!   `computeLSTMTrainingCacheCapacity`; a short buffer is a hard failure.
//! * The multihead attention calls do take a filter, built with
//!   `BNNSFilterCreateLayerMultiheadAttention`, and the filter must outlive
//!   every apply. Both take a `backprop_cache`, but the forward call passes its
//!   size by *pointer* (in/out: null buffer plus non-null size pointer is a
//!   size query that performs no work) while the backward call passes the size
//!   by value.
//! * Two undocumented facts about the backward attention call, measured on
//!   macOS 15 and pinned by the tests below: it fails outright without the
//!   forward pass's `backprop_cache` rather than recomputing, and a
//!   caller-supplied `workspace` sized from its own `workspace_size` query is
//!   rejected as too small. Leaving `workspace` null, so BNNS allocates its
//!   own, is the configuration that works.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const Error = types.Error;
const check = types.check;
const checkSize = types.checkSize;

const FilterParameters = types.FilterParameters;
const LayerParametersLSTM = types.LayerParametersLSTM;
const MHAProjectionParameters = types.MHAProjectionParameters;
const NDArrayDescriptor = types.NDArrayDescriptor;
const NormType = types.NormType;
const OptimizerFunction = types.OptimizerFunction;
const SparsityParameters = types.SparsityParameters;

/// The opaque layer-filter handle, `BNNSFilter`. Declared in `c.zig`; aliased
/// here so the attention signatures read without a `c.` prefix.
const Filter = c.BNNSFilter;

// ============================================================================
// Optimizer
// ============================================================================

/// Apply one optimizer step to a whole list of parameters.
///
/// `BNNSOptimizerStep`. `alg_fields` points at the `Optimizer*Fields` struct
/// that matches `function` — `OptimizerSGDMomentumFields` for
/// `.sgd_momentum`, `OptimizerAdamFields` for `.adam`/`.adam_w`/the AMSGrad
/// variants, and so on. It is read, never stored.
///
/// `parameters` are updated in place; `gradients` must have the same length,
/// and each gradient descriptor must have the same shape as the parameter it
/// matches. `accumulators` is the optimizer's persistent state: a flat array of
/// `k * parameters.len` pointers grouped by role (all first moments, then all
/// second moments, ...), zeroed by the caller before the first step. Pass null
/// only for algorithms that need no state, i.e. SGD with `momentum == 0`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn optimizerStep(
    function: OptimizerFunction,
    alg_fields: *const anyopaque,
    parameters: []*NDArrayDescriptor,
    gradients: []*const NDArrayDescriptor,
    accumulators: ?[]?*NDArrayDescriptor,
    filter_params: ?*const FilterParameters,
) Error!void {
    std.debug.assert(parameters.len == gradients.len);
    if (accumulators) |acc| std.debug.assert(acc.len % parameters.len == 0);
    const acc_ptr: ?[*]?*NDArrayDescriptor = if (accumulators) |acc| acc.ptr else null;
    return check(c.BNNSOptimizerStep(
        function,
        alg_fields,
        parameters.len,
        parameters.ptr,
        gradients.ptr,
        acc_ptr,
        filter_params,
    ));
}

// ============================================================================
// Gradient clipping
// ============================================================================

/// Clamp every element of `src` into `[min_val, max_val]`, writing `dest`.
///
/// `BNNSClipByValue`. `dest` must have the same type and shape as `src`; it may
/// alias `src` for an in-place clip.
///
/// Deprecated in macOS 15.0 (introduced 12.0). Prefer the Graph API
/// (`bnns.Graph`).
pub fn clipByValue(dest: *NDArrayDescriptor, src: *const NDArrayDescriptor, min_val: f32, max_val: f32) Error!void {
    return check(c.BNNSClipByValue(dest, src, min_val, max_val));
}

/// Scale `src` down so its L2 norm does not exceed `max_norm`.
///
/// `BNNSClipByNorm`. The whole tensor is multiplied by
/// `min(1, max_norm / ||src||)`, so a tensor already inside the ball is copied
/// unchanged. `axis_flags` selects the axes the norm is taken over, with 0
/// meaning all of them; with a nonzero mask each slice is scaled by its own
/// norm. `dest` must match `src` in type and shape.
///
/// Deprecated in macOS 15.0 (introduced 12.0). Prefer the Graph API
/// (`bnns.Graph`).
pub fn clipByNorm(dest: *NDArrayDescriptor, src: *const NDArrayDescriptor, max_norm: f32, axis_flags: u32) Error!void {
    return check(c.BNNSClipByNorm(dest, src, max_norm, axis_flags));
}

/// Scale a whole list of tensors by one shared factor derived from their
/// combined L2 norm.
///
/// `BNNSClipByGlobalNorm`. Every tensor is multiplied by
/// `min(1, max_norm / global)`, where `global` is `use_norm` when that is
/// nonzero and `sqrt(sum of all squared elements)` otherwise. This is the usual
/// "clip gradients by global norm" of a training loop, so the relative
/// direction of the update is preserved. `dest` and `src` must be the same
/// length and match elementwise in type and shape.
///
/// Deprecated in macOS 15.0 (introduced 12.0). Prefer the Graph API
/// (`bnns.Graph`).
pub fn clipByGlobalNorm(
    dest: []*NDArrayDescriptor,
    src: []*const NDArrayDescriptor,
    max_norm: f32,
    use_norm: f32,
) Error!void {
    std.debug.assert(dest.len == src.len);
    return check(c.BNNSClipByGlobalNorm(dest.ptr, src.ptr, dest.len, max_norm, use_norm));
}

// ============================================================================
// Norms
// ============================================================================

/// Reduce `src` to its norm along the axes named by `axis_flags`.
///
/// `BNNSComputeNorm`. `norm_type` only has one legal value, `.l2_norm`. The
/// axes in `axis_flags` are *removed* from the destination shape; when
/// `axis_flags` is 0 every axis is reduced and `dest` must be
/// `DataLayout.vector` with `size[0] = 1`.
///
/// Deprecated in macOS 15.0 (introduced 12.0). Prefer the Graph API
/// (`bnns.Graph`).
pub fn computeNorm(dest: *NDArrayDescriptor, src: *const NDArrayDescriptor, norm_type: NormType, axis_flags: u32) Error!void {
    return check(c.BNNSComputeNorm(dest, src, norm_type, axis_flags));
}

/// Backpropagate through `computeNorm`.
///
/// `BNNSComputeNormBackward`. For the L2 norm `y = ||x||` the derivative is
/// `dx = dy * x / y`, so the call needs both the forward input and the forward
/// output. Note the asymmetry in how they are passed: `in` and `out` are raw
/// *data* pointers to the forward pass values, while `in_delta` (written) and
/// `out_delta` (read) are full descriptors. `in_delta` carries the shape of
/// `x`, `out_delta` the reduced shape, and `axis_flags` must be exactly what
/// the forward call used.
///
/// Deprecated in macOS 15.0 (introduced 12.0). Prefer the Graph API
/// (`bnns.Graph`).
pub fn computeNormBackward(
    in: *const anyopaque,
    in_delta: *NDArrayDescriptor,
    out: *const anyopaque,
    out_delta: *const NDArrayDescriptor,
    norm_type: NormType,
    axis_flags: u32,
) Error!void {
    return check(c.BNNSComputeNormBackward(in, in_delta, out, out_delta, norm_type, axis_flags));
}

// ============================================================================
// Sparse fully-connected weights
// ============================================================================

/// Convert COO-format sparse weights into the device-specific packing that a
/// sparse fully-connected layer wants.
///
/// `BNNSNDArrayFullyConnectedSparsifySparseCOO`. `in_dense_shape` describes the
/// *dense* 2D matrix (sizes and layout only; its `data` is not read),
/// `in_indices` is a 2D `[NNZ, rank]` array of interleaved indices, and
/// `in_values` a 1D `[NNZ]` array of the nonzeros. The result is opaque: hand
/// `out` straight to a fully-connected layer, do not inspect it.
///
/// Two allocation rules bite. If `out.data` is null BNNS allocates the buffer
/// and the *caller* must free it; otherwise `out.data` must be at least the
/// size of the dense input. If `workspace` is null BNNS allocates scratch
/// internally, otherwise the buffer must be at least twice the dense input
/// size and `workspace_size` says how big it is. `batch_size` is the batch the
/// weights will later be applied with — it changes the packing — and 0 is read
/// as 1.
///
/// Deprecated in macOS 15.0 (introduced 13.0). Prefer the Graph API
/// (`bnns.Graph`).
pub fn ndArrayFullyConnectedSparsifySparseCOO(
    in_dense_shape: *const NDArrayDescriptor,
    in_indices: *const NDArrayDescriptor,
    in_values: *const NDArrayDescriptor,
    out: *NDArrayDescriptor,
    sparse_params: ?*const SparsityParameters,
    batch_size: usize,
    workspace: ?*anyopaque,
    workspace_size: usize,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSNDArrayFullyConnectedSparsifySparseCOO(
        in_dense_shape,
        in_indices,
        in_values,
        out,
        sparse_params,
        batch_size,
        workspace,
        workspace_size,
        filter_params,
    ));
}

/// Convert CSR-format sparse weights into the device-specific packing that a
/// sparse fully-connected layer wants.
///
/// `BNNSNDArrayFullyConnectedSparsifySparseCSR`. As the COO variant, but the
/// pattern arrives as `in_column_indices` (1D, `[NNZ]`) plus `in_row_starts`
/// (1D, `[rows + 1]`, starting at 0) rather than interleaved pairs. The same
/// `out.data`/`workspace` allocation rules apply.
///
/// Deprecated in macOS 15.0 (introduced 13.0). Prefer the Graph API
/// (`bnns.Graph`).
pub fn ndArrayFullyConnectedSparsifySparseCSR(
    in_dense_shape: *const NDArrayDescriptor,
    in_column_indices: *const NDArrayDescriptor,
    in_row_starts: *const NDArrayDescriptor,
    in_values: *const NDArrayDescriptor,
    out: *NDArrayDescriptor,
    sparse_params: ?*const SparsityParameters,
    batch_size: usize,
    workspace: ?*anyopaque,
    workspace_size: usize,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSNDArrayFullyConnectedSparsifySparseCSR(
        in_dense_shape,
        in_column_indices,
        in_row_starts,
        in_values,
        out,
        sparse_params,
        batch_size,
        workspace,
        workspace_size,
        filter_params,
    ));
}

// ============================================================================
// LSTM
// ============================================================================

/// The minimum size, in bytes, of the training cache for `layer_params`.
///
/// `BNNSComputeLSTMTrainingCacheCapacity`. Returns `SIZE_MAX` on failure, which
/// this maps to `Error.BnnsQueryFailed`; a legitimately zero-sized cache is
/// therefore distinguishable from a rejected layer description.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn computeLSTMTrainingCacheCapacity(layer_params: *const LayerParametersLSTM) Error!usize {
    return checkSize(c.BNNSComputeLSTMTrainingCacheCapacity(layer_params));
}

/// Run an LSTM forward over the whole batch, optionally caching intermediates
/// for the backward pass.
///
/// `BNNSDirectApplyLSTMBatchTrainingCaching`. There is no filter object: the
/// inputs, outputs, states, weights and biases all live in `layer_params`, with
/// the data pointers inside the descriptors, so the tensors must be filled in
/// before the call and the outputs are read out of the same struct afterwards.
///
/// `training_cache` may be null, which just skips caching; if it is non-null it
/// must be at least `computeLSTMTrainingCacheCapacity(layer_params)` bytes or
/// the call fails.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn directApplyLSTMBatchTrainingCaching(
    layer_params: *const LayerParametersLSTM,
    filter_params: ?*const FilterParameters,
    training_cache: ?[]u8,
) Error!void {
    const ptr: ?*anyopaque = if (training_cache) |t| @ptrCast(t.ptr) else null;
    const len: usize = if (training_cache) |t| t.len else 0;
    return check(c.BNNSDirectApplyLSTMBatchTrainingCaching(layer_params, filter_params, ptr, len));
}

/// Run an LSTM backward pass to obtain the input and weight gradients.
///
/// `BNNSDirectApplyLSTMBatchBackward`. `layer_delta_params` is a second
/// `LayerParametersLSTM` whose descriptors hold the *deltas* rather than the
/// values: its `output_descriptor` supplies the incoming gradient and its
/// `input_descriptor` and gate descriptors receive the computed ones. Its
/// scalar fields must describe the same network as `layer_params`.
///
/// `training_cache` is the buffer filled by
/// `directApplyLSTMBatchTrainingCaching`. Passing null is legal and makes BNNS
/// recompute the forward pass; passing a buffer shorter than the required
/// capacity fails.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn directApplyLSTMBatchBackward(
    layer_params: *const LayerParametersLSTM,
    layer_delta_params: *const LayerParametersLSTM,
    filter_params: ?*const FilterParameters,
    training_cache: ?[]const u8,
) Error!void {
    const ptr: ?*const anyopaque = if (training_cache) |t| @ptrCast(t.ptr) else null;
    const len: usize = if (training_cache) |t| t.len else 0;
    return check(c.BNNSDirectApplyLSTMBatchBackward(layer_params, layer_delta_params, filter_params, ptr, len));
}

// ============================================================================
// Multihead attention
// ============================================================================

/// Arguments to `applyMultiheadAttention`, one field per C parameter of
/// `BNNSApplyMultiheadAttention` in header order.
///
/// The C function takes seventeen positional arguments, half of them nullable
/// and several of them pointer/stride pairs, so they are grouped here rather
/// than spelled out at every call site. The `*_stride` fields are *batch*
/// strides, in elements, between consecutive samples of the batch.
///
/// `query`, `key`, `value` and `output` have no default: `bnns.h` sits inside
/// `_Pragma("clang assume_nonnull begin")`, so those four are required even
/// though every other pointer in the same prototype is explicitly `_Nullable`.
pub const MultiheadAttentionArgs = struct {
    /// Number of samples in the batch.
    batch_size: usize = 1,
    /// Q, laid out as `query.target_desc` of the layer parameters.
    query: *const anyopaque,
    query_stride: usize = 0,
    /// K, laid out as `key.target_desc`.
    key: *const anyopaque,
    key_stride: usize = 0,
    /// Optional 1D boolean tensor of length `source_length`. Where true, that
    /// key entry is excluded from the attention.
    key_mask: ?*const NDArrayDescriptor = null,
    key_mask_stride: usize = 0,
    /// V, laid out as `value.target_desc`.
    value: *const anyopaque,
    value_stride: usize = 0,
    /// Destination, laid out as `output.target_desc`.
    output: *anyopaque,
    output_stride: usize = 0,
    /// Optional additive attention mask, added before the softmax. Shape
    /// `target_length x source_length`, or with a leading `num_heads` and/or
    /// `batch_size`. A boolean tensor adds `-inf` where true, i.e. forbids
    /// attention there.
    add_to_attention: ?*const NDArrayDescriptor = null,
    /// In/out. Non-null with a null `backprop_cache` turns the call into a size
    /// query that performs no attention.
    backprop_cache_size: ?*usize = null,
    /// Receives the intermediates that speed up
    /// `applyMultiheadAttentionBackward`.
    backprop_cache: ?*anyopaque = null,
    /// In/out, exactly like `backprop_cache_size`.
    workspace_size: ?*usize = null,
    /// Scratch. If null BNNS allocates its own.
    workspace: ?*anyopaque = null,
};

/// Apply a multihead attention layer forward.
///
/// `BNNSApplyMultiheadAttention`. `filter` comes from
/// `BNNSFilterCreateLayerMultiheadAttention` and must outlive the call. To size
/// the buffers, call once with `backprop_cache_size` and/or `workspace_size`
/// pointing at a `usize` and the matching buffer pointer null: BNNS writes the
/// recommended sizes and performs no attention. If both are queried at once the
/// workspace size returned assumes the full backprop cache is supplied.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn applyMultiheadAttention(filter: Filter, args: MultiheadAttentionArgs) Error!void {
    return check(c.BNNSApplyMultiheadAttention(
        filter,
        args.batch_size,
        args.query,
        args.query_stride,
        args.key,
        args.key_stride,
        args.key_mask,
        args.key_mask_stride,
        args.value,
        args.value_stride,
        args.output,
        args.output_stride,
        args.add_to_attention,
        args.backprop_cache_size,
        args.backprop_cache,
        args.workspace_size,
        args.workspace,
    ));
}

/// Arguments to `applyMultiheadAttentionBackward`, one field per C parameter of
/// `BNNSApplyMultiheadAttentionBackward` in header order.
///
/// Every `*_param_delta` is an `MHAProjectionParameters` reused as an output:
/// its `target_desc`, `weights` and `bias` receive the gradients with respect
/// to that input, its projection matrix and its bias. A null `data` on any
/// member means "do not compute this one", and `target_desc.stride[2]` is read
/// as the batch stride of that delta.
pub const MultiheadAttentionBackwardArgs = struct {
    batch_size: usize = 1,
    query: ?*const anyopaque = null,
    query_stride: usize = 0,
    query_param_delta: ?*MHAProjectionParameters = null,
    key: ?*const anyopaque = null,
    key_stride: usize = 0,
    key_mask: ?*const NDArrayDescriptor = null,
    key_mask_stride: usize = 0,
    key_param_delta: ?*MHAProjectionParameters = null,
    value: ?*const anyopaque = null,
    value_stride: usize = 0,
    value_param_delta: ?*MHAProjectionParameters = null,
    /// Must match what the forward pass was given.
    add_to_attention: ?*const NDArrayDescriptor = null,
    /// Gradient of the optional attention bias `bᴷ`.
    key_attn_bias_delta: ?*NDArrayDescriptor = null,
    /// Gradient of the optional attention bias `bⱽ`.
    value_attn_bias_delta: ?*NDArrayDescriptor = null,
    /// The incoming gradient with respect to the layer output.
    output: ?*const anyopaque = null,
    output_stride: usize = 0,
    /// The one non-optional delta block.
    output_param_delta: *MHAProjectionParameters,
    /// Size of `backprop_cache` in bytes, BY VALUE here — unlike the forward
    /// call, where it is a pointer. Zero, or a null buffer, means the cache is
    /// not read and the needed intermediates are recomputed.
    backprop_cache_size: usize = 0,
    backprop_cache: ?*anyopaque = null,
    /// In/out pointer, as in the forward call: non-null with a null `workspace`
    /// is a size query.
    workspace_size: ?*usize = null,
    workspace: ?*anyopaque = null,
};

/// Apply a multihead attention layer backward, producing the input and
/// projection gradients.
///
/// `BNNSApplyMultiheadAttentionBackward`. When two of query/key/value share a
/// data pointer — self-attention being the obvious case — pointing the matching
/// `*_param_delta.target_desc.data` at one buffer makes BNNS accumulate the sum
/// of the components there, which is what the chain rule wants.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn applyMultiheadAttentionBackward(filter: Filter, args: MultiheadAttentionBackwardArgs) Error!void {
    return check(c.BNNSApplyMultiheadAttentionBackward(
        filter,
        args.batch_size,
        args.query,
        args.query_stride,
        args.query_param_delta,
        args.key,
        args.key_stride,
        args.key_mask,
        args.key_mask_stride,
        args.key_param_delta,
        args.value,
        args.value_stride,
        args.value_param_delta,
        args.add_to_attention,
        args.key_attn_bias_delta,
        args.value_attn_bias_delta,
        args.output,
        args.output_stride,
        args.output_param_delta,
        args.backprop_cache_size,
        args.backprop_cache,
        args.workspace_size,
        args.workspace,
    ));
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const DataLayout = types.DataLayout;

/// A contiguous f32 descriptor over `data`, with `sizes` written into
/// `size[0..]` in the order given. `layout` decides how those sizes are read.
fn desc(data: ?*anyopaque, layout: DataLayout, sizes: []const usize) NDArrayDescriptor {
    var d = NDArrayDescriptor{ .layout = layout, .data_type = .float32, .data = data };
    for (sizes, 0..) |s, i| d.size[i] = s;
    return d;
}

/// A contiguous f32 descriptor over `data` in the generic first-major layout of
/// rank `sizes.len`, asserting that the shape matches the slice length.
fn f32Desc(data: []f32, comptime rank: usize, size: [rank]usize) NDArrayDescriptor {
    var count: usize = 1;
    for (size) |s| count *= s;
    std.debug.assert(count == data.len);
    return desc(@ptrCast(data.ptr), DataLayout.firstMajor(rank), &size);
}

test "clipByValue clamps into the interval elementwise" {
    var src = [_]f32{ -2.0, -0.5, 0.5, 3.0 };
    var dst = [_]f32{ 9, 9, 9, 9 };

    const src_desc = f32Desc(&src, 1, .{4});
    var dst_desc = f32Desc(&dst, 1, .{4});

    try clipByValue(&dst_desc, &src_desc, -1.0, 1.0);
    try testing.expectEqualSlices(f32, &.{ -1.0, -0.5, 0.5, 1.0 }, &dst);
}

test "computeNorm over every axis gives the scalar L2 norm" {
    var src = [_]f32{ 3.0, 4.0 };
    var out = [_]f32{0};

    const src_desc = f32Desc(&src, 1, .{2});
    var out_desc = desc(@ptrCast(&out), .vector, &.{1});

    try computeNorm(&out_desc, &src_desc, .l2_norm, 0);
    try testing.expectApproxEqAbs(@as(f32, 5.0), out[0], 1e-6);
}

test "computeNorm with an axis mask reduces exactly that axis" {
    // A 2x2 in `2d_first_major`, i.e. rows (3,4) and (12,5): element (i,j)
    // lives at i*size[1] + j, so bit d of axis_flags names the `size[d]` axis.
    var src = [_]f32{ 3.0, 4.0, 12.0, 5.0 };
    var out = [_]f32{ 0, 0 };

    const src_desc = f32Desc(&src, 2, .{ 2, 2 });
    var out_desc = f32Desc(&out, 1, .{2});

    // Bit 0 reduces the outer axis, leaving one norm per column:
    // ||(3,12)|| = 12.369317, ||(4,5)|| = 6.4031243.
    try computeNorm(&out_desc, &src_desc, .l2_norm, 0x1);
    try testing.expectApproxEqAbs(@as(f32, 12.369317), out[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 6.4031243), out[1], 1e-5);

    // Bit 1 reduces the inner axis, leaving one norm per row:
    // ||(3,4)|| = 5, ||(12,5)|| = 13.
    try computeNorm(&out_desc, &src_desc, .l2_norm, 0x2);
    try testing.expectApproxEqAbs(@as(f32, 5.0), out[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 13.0), out[1], 1e-5);
}

test "clipByNorm scales a too-large tensor onto the ball and leaves a small one alone" {
    var src = [_]f32{ 3.0, 4.0 }; // ||src|| = 5
    var dst = [_]f32{ 0, 0 };

    const src_desc = f32Desc(&src, 1, .{2});
    var dst_desc = f32Desc(&dst, 1, .{2});

    // max_norm 2.5 is half the norm, so every element halves.
    try clipByNorm(&dst_desc, &src_desc, 2.5, 0);
    try testing.expectApproxEqAbs(@as(f32, 1.5), dst[0], 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 2.0), dst[1], 1e-6);

    // max_norm 10 exceeds the norm, so the tensor passes through untouched.
    try clipByNorm(&dst_desc, &src_desc, 10.0, 0);
    try testing.expectApproxEqAbs(@as(f32, 3.0), dst[0], 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 4.0), dst[1], 1e-6);
}

test "clipByGlobalNorm scales every tensor by one shared factor" {
    // Global norm of {3,4} and {12} is sqrt(9+16+144) = 13.
    var a_src = [_]f32{ 3.0, 4.0 };
    var b_src = [_]f32{12.0};
    var a_dst = [_]f32{ 0, 0 };
    var b_dst = [_]f32{0};

    const a_src_desc = f32Desc(&a_src, 1, .{2});
    const b_src_desc = f32Desc(&b_src, 1, .{1});
    var a_dst_desc = f32Desc(&a_dst, 1, .{2});
    var b_dst_desc = f32Desc(&b_dst, 1, .{1});

    var srcs = [_]*const NDArrayDescriptor{ &a_src_desc, &b_src_desc };
    var dsts = [_]*NDArrayDescriptor{ &a_dst_desc, &b_dst_desc };

    // max_norm 6.5 is half of 13, so the shared factor is 0.5.
    try clipByGlobalNorm(&dsts, &srcs, 6.5, 0.0);
    try testing.expectApproxEqAbs(@as(f32, 1.5), a_dst[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 2.0), a_dst[1], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 6.0), b_dst[0], 1e-5);

    // Supplying use_norm overrides the computed global norm: 26 with max 6.5
    // gives a factor of 0.25.
    try clipByGlobalNorm(&dsts, &srcs, 6.5, 26.0);
    try testing.expectApproxEqAbs(@as(f32, 0.75), a_dst[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 1.0), a_dst[1], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 3.0), b_dst[0], 1e-5);
}

test "computeNormBackward gives dx = dy * x / ||x||" {
    var x = [_]f32{ 3.0, 4.0 }; // ||x|| = 5
    var y = [_]f32{5.0};
    var dy = [_]f32{2.0};
    var dx = [_]f32{ 0, 0 };

    var dx_desc = f32Desc(&dx, 1, .{2});
    const dy_desc = desc(@ptrCast(&dy), .vector, &.{1});

    try computeNormBackward(@ptrCast(&x), &dx_desc, @ptrCast(&y), &dy_desc, .l2_norm, 0);
    // dy * x/||x|| = 2 * [0.6, 0.8]
    try testing.expectApproxEqAbs(@as(f32, 1.2), dx[0], 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 1.6), dx[1], 1e-6);
}

test "optimizerStep runs one exact SGD update" {
    // Vanilla SGD (momentum 0, variant0): V = 0*V - g*lr, W += V, i.e.
    // W' = W - lr*g. With W = [1,2,3,4], g = [0.5,-1,2,0], lr = 0.1 that is
    // [0.95, 2.1, 2.8, 4.0]. momentum 0 means no accumulator is needed, so the
    // accumulator array may be null.
    var w = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    var g = [_]f32{ 0.5, -1.0, 2.0, 0.0 };

    var w_desc = f32Desc(&w, 1, .{4});
    const g_desc = f32Desc(&g, 1, .{4});

    var params = [_]*NDArrayDescriptor{&w_desc};
    var grads = [_]*const NDArrayDescriptor{&g_desc};

    const fields = types.OptimizerSGDMomentumFields{
        .learning_rate = 0.1,
        .momentum = 0.0,
        .gradient_scale = 1.0,
        .regularization_scale = 0.0,
        .regularization_func = .none,
        .sgd_momentum_variant = .variant0,
    };

    try optimizerStep(.sgd_momentum, @ptrCast(&fields), &params, &grads, null, null);

    try testing.expectApproxEqAbs(@as(f32, 0.95), w[0], 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 2.1), w[1], 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 2.8), w[2], 1e-6);
    try testing.expectApproxEqAbs(@as(f32, 4.0), w[3], 1e-6);
}

test "optimizerStep with momentum accumulates across two steps" {
    // variant1: V = m*V + g, W -= V*lr. With m = 0.9, lr = 0.1, g = 2 held
    // constant: after step 1 V = 2 and W = 10 - 0.2 = 9.8; after step 2
    // V = 0.9*2 + 2 = 3.8 and W = 9.8 - 0.38 = 9.42.
    var w = [_]f32{10.0};
    var g = [_]f32{2.0};
    var v = [_]f32{0.0}; // the accumulator, zeroed by the caller

    var w_desc = f32Desc(&w, 1, .{1});
    const g_desc = f32Desc(&g, 1, .{1});
    var v_desc = f32Desc(&v, 1, .{1});

    var params = [_]*NDArrayDescriptor{&w_desc};
    var grads = [_]*const NDArrayDescriptor{&g_desc};
    var accs = [_]?*NDArrayDescriptor{&v_desc};

    const fields = types.OptimizerSGDMomentumFields{
        .learning_rate = 0.1,
        .momentum = 0.9,
        .gradient_scale = 1.0,
        .regularization_func = .none,
        .sgd_momentum_variant = .variant1,
    };

    try optimizerStep(.sgd_momentum, @ptrCast(&fields), &params, &grads, &accs, null);
    try testing.expectApproxEqAbs(@as(f32, 9.8), w[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 2.0), v[0], 1e-5);

    try optimizerStep(.sgd_momentum, @ptrCast(&fields), &params, &grads, &accs, null);
    try testing.expectApproxEqAbs(@as(f32, 9.42), w[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 3.8), v[0], 1e-5);
}

// ----------------------------------------------------------------------------
// Sparsify: convert, then actually use the result in a fully-connected layer.
// ----------------------------------------------------------------------------

const sparse_n = 8;

/// Build a fully-connected filter over the (opaque) sparse weights `w`, apply
/// it to `x` and return the result. This is the only way to check that a
/// sparsify call produced the right thing: the packed output is not inspectable.
fn applySparseFullyConnected(w: *const NDArrayDescriptor, x: *[sparse_n]f32) ![sparse_n]f32 {
    const layer = types.LayerParametersFullyConnected{
        .i_desc = desc(null, .vector, &.{sparse_n}),
        .w_desc = w.*,
        .o_desc = desc(null, .vector, &.{sparse_n}),
        .bias = desc(null, .vector, &.{sparse_n}),
        .activation = .{},
    };
    const filter = c.BNNSFilterCreateLayerFullyConnected(&layer, null);
    if (filter == null) return Error.BnnsAllocationFailed;
    defer c.BNNSFilterDestroy(filter);

    var y: [sparse_n]f32 = @splat(-1);
    try check(c.BNNSFilterApplyBatch(filter, 1, @ptrCast(x), sparse_n, @ptrCast(&y), sparse_n));
    return y;
}

test "ndArrayFullyConnectedSparsifySparseCOO produces usable weights" {
    // The dense 8x8 matrix is 2*I plus a single 7 at (row 3, column 0), so
    // y = W*x has y[i] = 2*x[i] except y[3] = 2*x[3] + 7*x[0].
    const nnz = sparse_n + 1;
    var values: [nnz]f32 = undefined;
    var indices: [2 * nnz]u32 = undefined;
    for (0..sparse_n) |k| {
        // Interleaved, even = column, odd = row (row-major ordering).
        indices[2 * k] = @intCast(k);
        indices[2 * k + 1] = @intCast(k);
        values[k] = 2.0;
    }
    indices[2 * sparse_n] = 0; // column 0
    indices[2 * sparse_n + 1] = 3; // row 3
    values[sparse_n] = 7.0;

    const dense = desc(null, .row_major_matrix, &.{ sparse_n, sparse_n });
    var idx_desc = desc(@ptrCast(&indices), .row_major_matrix, &.{ 2, nnz });
    idx_desc.data_type = .uint32;
    const val_desc = desc(@ptrCast(&values), .vector, &.{nnz});

    // Preallocating out.data at the dense size keeps BNNS from allocating a
    // buffer that we would then have to free ourselves.
    var packed_buf: [sparse_n * sparse_n]f32 = @splat(0);
    var out = desc(@ptrCast(&packed_buf), .fully_connected_sparse, &.{ sparse_n, sparse_n });

    try ndArrayFullyConnectedSparsifySparseCOO(&dense, &idx_desc, &val_desc, &out, null, 1, null, 0, null);

    // The packing is smaller than the dense matrix it came from.
    const packed_bytes = c.BNNSNDArrayGetDataSize(&out);
    try testing.expect(packed_bytes > 0);
    try testing.expect(packed_bytes < @sizeOf(@TypeOf(packed_buf)));

    var x = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const y = try applySparseFullyConnected(&out, &x);
    try testing.expectEqualSlices(f32, &.{ 2, 4, 6, 15, 10, 12, 14, 16 }, &y);
}

test "ndArrayFullyConnectedSparsifySparseCSR produces the same weights as COO" {
    // The same matrix, in CSR: every row has its diagonal 2, and row 3 also
    // has a 7 in column 0.
    const nnz = sparse_n + 1;
    var columns: [nnz]u32 = undefined;
    var values: [nnz]f32 = undefined;
    var row_starts: [sparse_n + 1]u32 = undefined;

    var p: u32 = 0;
    for (0..sparse_n) |r| {
        row_starts[r] = p;
        if (r == 3) {
            columns[p] = 0;
            values[p] = 7.0;
            p += 1;
        }
        columns[p] = @intCast(r);
        values[p] = 2.0;
        p += 1;
    }
    row_starts[sparse_n] = p; // the trailing end-of-last-row marker

    const dense = desc(null, .row_major_matrix, &.{ sparse_n, sparse_n });
    var col_desc = desc(@ptrCast(&columns), .vector, &.{nnz});
    col_desc.data_type = .uint32;
    var row_desc = desc(@ptrCast(&row_starts), .vector, &.{sparse_n + 1});
    row_desc.data_type = .uint32;
    const val_desc = desc(@ptrCast(&values), .vector, &.{nnz});

    var packed_buf: [sparse_n * sparse_n]f32 = @splat(0);
    var out = desc(@ptrCast(&packed_buf), .fully_connected_sparse, &.{ sparse_n, sparse_n });

    try ndArrayFullyConnectedSparsifySparseCSR(&dense, &col_desc, &row_desc, &val_desc, &out, null, 1, null, 0, null);

    var x = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    const y = try applySparseFullyConnected(&out, &x);
    try testing.expectEqualSlices(f32, &.{ 2, 4, 6, 15, 10, 12, 14, 16 }, &y);
}

// ----------------------------------------------------------------------------
// LSTM: one cell, one step, everything scalar, so the arithmetic is checkable.
// ----------------------------------------------------------------------------

/// The smallest possible LSTM: input_size = hidden_size = batch_size =
/// seq_len = num_layers = 1, unidirectional, no peephole, no bias. Every weight
/// is a 1x1 matrix, so the whole cell reduces to scalar arithmetic.
const TinyLstm = struct {
    zero: f32 = 0,
    x: f32 = 1.0,
    h_in: f32 = 0,
    c_in: f32 = 0,
    y: f32 = -99,
    h_out: f32 = -99,
    c_out: f32 = -99,
    w_input: f32 = 1.0,
    w_forget: f32 = 0.5,
    w_candidate: f32 = 1.0,
    w_output: f32 = 2.0,

    /// The `[num_layers][num_directions][batch_size][hidden_size]` state
    /// tensors, all of extent 1 here.
    fn state(data: *f32) NDArrayDescriptor {
        return desc(@ptrCast(data), DataLayout.firstMajor(4), &.{ 1, 1, 1, 1 });
    }

    /// One gate: a 1x1 input weight (duplicated for the >1-layer case), zeroed
    /// hidden, cell (peephole) and bias terms.
    fn gate(self: *TinyLstm, w: *f32, f: types.ActivationFunction) types.LSTMGateDescriptor {
        const w_desc = desc(@ptrCast(w), .row_major_matrix, &.{ 1, 1 });
        const zero_mat = desc(@ptrCast(&self.zero), .row_major_matrix, &.{ 1, 1 });
        return .{
            .iw_desc = .{ w_desc, w_desc },
            .hw_desc = zero_mat,
            .cw_desc = zero_mat,
            .b_desc = desc(@ptrCast(&self.zero), .vector, &.{1}),
            .activation = .{ .function = f },
        };
    }

    fn params(self: *TinyLstm) LayerParametersLSTM {
        return .{
            .input_size = 1,
            .hidden_size = 1,
            .batch_size = 1,
            .num_layers = 1,
            .seq_len = 1,
            .dropout = 0,
            .lstm_flags = 0,
            // A null sequence descriptor means "batch_size at every step".
            .sequence_descriptor = desc(null, .vector, &.{0}),
            .input_descriptor = .{
                // SNE, shape (input_size, batch_size, seq_len).
                .data_desc = desc(@ptrCast(&self.x), .sne, &.{ 1, 1, 1 }),
                .hidden_desc = state(&self.h_in),
                .cell_state_desc = state(&self.c_in),
            },
            .output_descriptor = .{
                .data_desc = desc(@ptrCast(&self.y), .sne, &.{ 1, 1, 1 }),
                .hidden_desc = state(&self.h_out),
                .cell_state_desc = state(&self.c_out),
            },
            .input_gate = self.gate(&self.w_input, .sigmoid),
            .forget_gate = self.gate(&self.w_forget, .sigmoid),
            .candidate_gate = self.gate(&self.w_candidate, .tanh),
            .output_gate = self.gate(&self.w_output, .sigmoid),
            .hidden_activation = .{ .function = .tanh },
        };
    }
};

fn sigmoid(v: f32) f32 {
    return 1.0 / (1.0 + std.math.exp(-v));
}

test "computeLSTMTrainingCacheCapacity sizes a cache the forward pass accepts" {
    var lstm = TinyLstm{};
    const lp = lstm.params();

    const capacity = try computeLSTMTrainingCacheCapacity(&lp);
    try testing.expect(capacity > 0);

    const cache = try testing.allocator.alloc(u8, capacity);
    defer testing.allocator.free(cache);
    try directApplyLSTMBatchTrainingCaching(&lp, null, cache);

    // One byte short is a hard failure, not a silent fallback to no caching.
    try testing.expectError(Error.BnnsFailed, directApplyLSTMBatchTrainingCaching(&lp, null, cache[0 .. capacity - 1]));

    // A null cache is legal and simply skips caching.
    try directApplyLSTMBatchTrainingCaching(&lp, null, null);
}

test "directApplyLSTMBatchTrainingCaching computes the textbook LSTM cell" {
    var lstm = TinyLstm{};
    const lp = lstm.params();

    const capacity = try computeLSTMTrainingCacheCapacity(&lp);
    const cache = try testing.allocator.alloc(u8, capacity);
    defer testing.allocator.free(cache);

    try directApplyLSTMBatchTrainingCaching(&lp, null, cache);

    // With h0 = c0 = 0 the hidden and peephole terms drop out, leaving
    //   i = sigmoid(w_input * x), g = tanh(w_candidate * x),
    //   o = sigmoid(w_output * x), c1 = f*c0 + i*g = i*g, h1 = o*tanh(c1).
    const i = sigmoid(lstm.w_input * lstm.x);
    const g = std.math.tanh(lstm.w_candidate * lstm.x);
    const o = sigmoid(lstm.w_output * lstm.x);
    const c1 = i * g;
    const h1 = o * std.math.tanh(c1);

    try testing.expectApproxEqAbs(c1, lstm.c_out, 1e-6);
    try testing.expectApproxEqAbs(h1, lstm.h_out, 1e-6);
    // seq_len is 1, so the single output step is the final hidden state.
    try testing.expectApproxEqAbs(h1, lstm.y, 1e-6);
}

test "directApplyLSTMBatchBackward matches the analytic LSTM gradients" {
    var lstm = TinyLstm{};
    const lp = lstm.params();

    const capacity = try computeLSTMTrainingCacheCapacity(&lp);
    const cache = try testing.allocator.alloc(u8, capacity);
    defer testing.allocator.free(cache);
    try directApplyLSTMBatchTrainingCaching(&lp, null, cache);

    // The delta block is a second LayerParametersLSTM describing the same
    // network, with every descriptor pointing at a delta instead of a value:
    // output_descriptor.data_desc carries the incoming dL/dy, and the input
    // and gate descriptors receive the computed gradients.
    var deltas = TinyLstm{
        .x = -99, // dL/dx, written
        .y = 1.0, // dL/dy, read
        .h_in = 0,
        .c_in = 0,
        .h_out = 0,
        .c_out = 0,
        .w_input = -99,
        .w_forget = -99,
        .w_candidate = -99,
        .w_output = -99,
    };
    const dp = deltas.params();

    try directApplyLSTMBatchBackward(&lp, &dp, null, cache);

    // dL/dy = 1, so with h = o*tanh(c), c = i*g and c0 = 0:
    //   dh/dc = o * (1 - tanh(c)^2)
    //   dc/dw_input     = g * i*(1-i) * x
    //   dc/dw_candidate = i * (1-g^2) * x
    //   dh/dw_output    = tanh(c) * o*(1-o) * x
    // and dL/dx sums each gate's contribution scaled by its input weight.
    const x = lstm.x;
    const i = sigmoid(lstm.w_input * x);
    const g = std.math.tanh(lstm.w_candidate * x);
    const o = sigmoid(lstm.w_output * x);
    const c1 = i * g;
    const tanh_c = std.math.tanh(c1);
    const dh_dc = o * (1.0 - tanh_c * tanh_c);

    const d_w_input = dh_dc * g * i * (1.0 - i) * x;
    const d_w_candidate = dh_dc * i * (1.0 - g * g) * x;
    const d_w_output = tanh_c * o * (1.0 - o) * x;

    try testing.expectApproxEqAbs(d_w_input, deltas.w_input, 1e-6);
    try testing.expectApproxEqAbs(d_w_candidate, deltas.w_candidate, 1e-6);
    try testing.expectApproxEqAbs(d_w_output, deltas.w_output, 1e-6);
    // c0 = 0 kills the forget gate's gradient entirely.
    try testing.expectApproxEqAbs(@as(f32, 0.0), deltas.w_forget, 1e-6);

    const dx = lstm.w_input * d_w_input + lstm.w_candidate * d_w_candidate + lstm.w_output * d_w_output;
    try testing.expectApproxEqAbs(dx, deltas.x, 1e-6);
}

// ----------------------------------------------------------------------------
// Multihead attention: one head, one token, one dimension.
// ----------------------------------------------------------------------------

/// The degenerate multihead attention layer: target_length = source_length =
/// d_model = d_key = d_value = num_heads = 1, no biases, no mask, no dropout.
///
/// The attention softmax is over a single element, so it is always exactly 1
/// and the layer collapses to `output = value * Wⱽ * Wᴼ` — an exact expected
/// value, and one that also pins down the gradients.
const TinyMha = struct {
    q: f32 = 0.5,
    k: f32 = 1.5,
    v: f32 = 3.5,
    out: f32 = -99,
    w_query: f32 = 1.0,
    w_key: f32 = 1.0,
    w_value: f32 = 2.0,
    w_output: f32 = 3.0,

    /// A projection weight tensor, `d x d_key x num_heads` in MHA_DHK layout.
    fn projection(w: *f32) NDArrayDescriptor {
        return desc(@ptrCast(w), .mha_dhk, &.{ 1, 1, 1 });
    }

    fn params(self: *TinyMha) types.LayerParametersMultiheadAttention {
        const no_bias = desc(null, .row_major_matrix, &.{ 1, 1 });
        return .{
            .query = .{
                // 2D, target_length x d_model.
                .target_desc = desc(@ptrCast(&self.q), .row_major_matrix, &.{ 1, 1 }),
                .weights = projection(&self.w_query),
                .bias = no_bias,
            },
            .key = .{
                .target_desc = desc(@ptrCast(&self.k), .row_major_matrix, &.{ 1, 1 }),
                .weights = projection(&self.w_key),
                .bias = no_bias,
            },
            .value = .{
                .target_desc = desc(@ptrCast(&self.v), .row_major_matrix, &.{ 1, 1 }),
                .weights = projection(&self.w_value),
                .bias = no_bias,
            },
            .add_zero_attn = false,
            .key_attn_bias = desc(null, .vector, &.{1}),
            .value_attn_bias = desc(null, .vector, &.{1}),
            .output = .{
                .target_desc = desc(@ptrCast(&self.out), .row_major_matrix, &.{ 1, 1 }),
                // 2D, num_heads*d_value x d_model.
                .weights = desc(@ptrCast(&self.w_output), .row_major_matrix, &.{ 1, 1 }),
                .bias = desc(null, .vector, &.{1}),
            },
            .dropout = 0,
            .seed = 0,
        };
    }
};

test "applyMultiheadAttention sizes its buffers and then computes the projection" {
    var mha = TinyMha{};
    const lp = mha.params();

    const filter = c.BNNSFilterCreateLayerMultiheadAttention(&lp, null);
    try testing.expect(filter != null);
    defer c.BNNSFilterDestroy(filter);

    // A non-null size pointer with a null buffer is a pure size query: it
    // writes the sizes and performs no attention, so `out` keeps its sentinel.
    var cache_size: usize = 0;
    var workspace_size: usize = 0;
    try applyMultiheadAttention(filter, .{
        .query = @ptrCast(&mha.q),
        .key = @ptrCast(&mha.k),
        .value = @ptrCast(&mha.v),
        .output = @ptrCast(&mha.out),
        .backprop_cache_size = &cache_size,
        .workspace_size = &workspace_size,
    });
    try testing.expect(cache_size > 0);
    try testing.expect(workspace_size > 0);
    try testing.expectEqual(@as(f32, -99), mha.out);

    const cache = try testing.allocator.alloc(u8, cache_size);
    defer testing.allocator.free(cache);
    const workspace = try testing.allocator.alloc(u8, workspace_size);
    defer testing.allocator.free(workspace);

    var cache_bytes = cache_size;
    var workspace_bytes = workspace_size;
    try applyMultiheadAttention(filter, .{
        .query = @ptrCast(&mha.q),
        .key = @ptrCast(&mha.k),
        .value = @ptrCast(&mha.v),
        .output = @ptrCast(&mha.out),
        .backprop_cache_size = &cache_bytes,
        .backprop_cache = @ptrCast(cache.ptr),
        .workspace_size = &workspace_bytes,
        .workspace = @ptrCast(workspace.ptr),
    });

    // softmax over one element is 1, so output = v * Wⱽ * Wᴼ = 3.5*2*3.
    try testing.expectApproxEqAbs(@as(f32, 21.0), mha.out, 1e-5);
}

test "applyMultiheadAttentionBackward returns the exact projection gradients" {
    var mha = TinyMha{};
    const lp = mha.params();

    const filter = c.BNNSFilterCreateLayerMultiheadAttention(&lp, null);
    try testing.expect(filter != null);
    defer c.BNNSFilterDestroy(filter);

    var cache_size: usize = 0;
    try applyMultiheadAttention(filter, .{
        .query = @ptrCast(&mha.q),
        .key = @ptrCast(&mha.k),
        .value = @ptrCast(&mha.v),
        .output = @ptrCast(&mha.out),
        .backprop_cache_size = &cache_size,
    });
    const cache = try testing.allocator.alloc(u8, cache_size);
    defer testing.allocator.free(cache);

    var cache_bytes = cache_size;
    try applyMultiheadAttention(filter, .{
        .query = @ptrCast(&mha.q),
        .key = @ptrCast(&mha.k),
        .value = @ptrCast(&mha.v),
        .output = @ptrCast(&mha.out),
        .backprop_cache_size = &cache_bytes,
        .backprop_cache = @ptrCast(cache.ptr),
    });

    // The deltas reuse the projection struct: target_desc holds dL/d(input)
    // for the inputs, and dL/d(output) on the way in for the output block.
    var d_out: f32 = 1.0;
    var d_q: f32 = -99;
    var d_k: f32 = -99;
    var d_v: f32 = -99;
    var d_w_query: f32 = -99;
    var d_w_key: f32 = -99;
    var d_w_value: f32 = -99;
    var d_w_output: f32 = -99;

    const no_bias = desc(null, .row_major_matrix, &.{ 1, 1 });
    var query_delta = MHAProjectionParameters{
        .target_desc = desc(@ptrCast(&d_q), .row_major_matrix, &.{ 1, 1 }),
        .weights = TinyMha.projection(&d_w_query),
        .bias = no_bias,
    };
    var key_delta = MHAProjectionParameters{
        .target_desc = desc(@ptrCast(&d_k), .row_major_matrix, &.{ 1, 1 }),
        .weights = TinyMha.projection(&d_w_key),
        .bias = no_bias,
    };
    var value_delta = MHAProjectionParameters{
        .target_desc = desc(@ptrCast(&d_v), .row_major_matrix, &.{ 1, 1 }),
        .weights = TinyMha.projection(&d_w_value),
        .bias = no_bias,
    };
    var output_delta = MHAProjectionParameters{
        .target_desc = desc(@ptrCast(&d_out), .row_major_matrix, &.{ 1, 1 }),
        .weights = desc(@ptrCast(&d_w_output), .row_major_matrix, &.{ 1, 1 }),
        .bias = desc(null, .vector, &.{1}),
    };

    // Two constraints, both established empirically on macOS 15 and neither
    // documented in the header. They are checked below rather than merely
    // described, so a future BNNS that changes them fails this test loudly.
    //   1. `backprop_cache` is required: with a zero size and a null buffer
    //      the call returns -1 instead of recomputing the forward pass.
    //   2. A caller-supplied `workspace` must be generously sized. The size
    //      this very call reports through `workspace_size` is *not* enough.
    // Letting BNNS allocate its own workspace (both fields null) always works.
    try testing.expectError(Error.BnnsFailed, applyMultiheadAttentionBackward(filter, .{
        .query = @ptrCast(&mha.q),
        .query_param_delta = &query_delta,
        .key = @ptrCast(&mha.k),
        .key_param_delta = &key_delta,
        .value = @ptrCast(&mha.v),
        .value_param_delta = &value_delta,
        .output = @ptrCast(&mha.out),
        .output_param_delta = &output_delta,
        .backprop_cache_size = 0,
        .backprop_cache = null,
    }));

    var reported_workspace: usize = 0;
    try applyMultiheadAttentionBackward(filter, .{
        .query = @ptrCast(&mha.q),
        .query_param_delta = &query_delta,
        .key = @ptrCast(&mha.k),
        .key_param_delta = &key_delta,
        .value = @ptrCast(&mha.v),
        .value_param_delta = &value_delta,
        .output = @ptrCast(&mha.out),
        .output_param_delta = &output_delta,
        .backprop_cache_size = cache_size,
        .backprop_cache = @ptrCast(cache.ptr),
        .workspace_size = &reported_workspace,
    });
    try testing.expect(reported_workspace > 0);

    const too_small = try testing.allocator.alloc(u8, reported_workspace);
    defer testing.allocator.free(too_small);
    var too_small_bytes = reported_workspace;
    try testing.expectError(Error.BnnsFailed, applyMultiheadAttentionBackward(filter, .{
        .query = @ptrCast(&mha.q),
        .query_param_delta = &query_delta,
        .key = @ptrCast(&mha.k),
        .key_param_delta = &key_delta,
        .value = @ptrCast(&mha.v),
        .value_param_delta = &value_delta,
        .output = @ptrCast(&mha.out),
        .output_param_delta = &output_delta,
        .backprop_cache_size = cache_size,
        .backprop_cache = @ptrCast(cache.ptr),
        .workspace_size = &too_small_bytes,
        .workspace = @ptrCast(too_small.ptr),
    }));

    // The working configuration: cache supplied, workspace left to BNNS.
    try applyMultiheadAttentionBackward(filter, .{
        .query = @ptrCast(&mha.q),
        .query_param_delta = &query_delta,
        .key = @ptrCast(&mha.k),
        .key_param_delta = &key_delta,
        .value = @ptrCast(&mha.v),
        .value_param_delta = &value_delta,
        .output = @ptrCast(&mha.out),
        .output_param_delta = &output_delta,
        .backprop_cache_size = cache_size,
        .backprop_cache = @ptrCast(cache.ptr),
    });

    // output = v * Wⱽ * Wᴼ with dL/d(output) = 1, so
    //   dL/dv  = Wⱽ*Wᴼ = 6, dL/dWⱽ = v*Wᴼ = 10.5, dL/dWᴼ = v*Wⱽ = 7.
    try testing.expectApproxEqAbs(@as(f32, 6.0), d_v, 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 10.5), d_w_value, 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 7.0), d_w_output, 1e-5);
    // A one-element softmax is constant at 1 whatever the scores are, so no
    // gradient reaches the query or key side at all.
    try testing.expectApproxEqAbs(@as(f32, 0.0), d_q, 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0.0), d_k, 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0.0), d_w_query, 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 0.0), d_w_key, 1e-5);
}
