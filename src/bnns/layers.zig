//! BNNS layer-filter constructors — the deprecated, pre-graph API.
//!
//! Everything in this file belongs to the first generation of BNNS, in which a
//! network is assembled out of individual layer objects. You fill in one
//! `BNNSLayerParameters*` block per layer, hand it to the matching
//! `BNNSFilterCreateLayer*` call, and get back an opaque `BNNSFilter`. The
//! filter is then run with `BNNSFilterApply` / `BNNSFilterApplyTwoInput` and
//! released with `BNNSFilterDestroy` (all three live in `bnns.filter`).
//!
//! Apple deprecated this entire surface in macOS 15.0 in favour of the Graph
//! API (`bnns.Graph`), which compiles a whole `.mlmodelc` model instead. It is
//! bound here on purpose: macOS 15.0 is a recent floor to require, and a
//! deployment target older than that has no Graph API to fall back on. Four of
//! the constructors here — `createConvolutionLayer`, `createFullyConnectedLayer`,
//! `createPoolingLayer` and `createVectorActivationLayer` — are older still,
//! deprecated back in macOS 11.0 in favour of their `...LayerX` successors, and
//! are marked as such individually.
//!
//! ## Facts a caller needs
//!
//! * **The parameter block is read once.** `BNNSFilterCreateLayer*` copies what
//!   it needs at creation time, so the block itself may be a stack temporary.
//!   The one exception is `LayerParametersTensorContraction.operation`, a
//!   `const char *` that must remain valid for the duration of the create call,
//!   and any buffer the filter is told to alias — see the next point.
//! * **Weights are copied unless you say otherwise.** Set
//!   `FilterParameters.flags` to `@intFromEnum(Flags.use_client_ptr)` to make
//!   the filter work directly from your `w_desc.data` / `bias.data` pointers,
//!   in which case that memory must outlive the filter.
//! * **Input and output data pointers are *not* taken from the descriptors.**
//!   `i_desc.data` and `o_desc.data` are ignored by the forward apply calls;
//!   the buffers are the `in` / `out` arguments of `BNNSFilterApply`. Only the
//!   constant descriptors (weights, bias, dictionary, gamma, ...) carry live
//!   pointers. Every test below leaves the i/o descriptor `data` null.
//! * **Descriptor sizes are not in C order.** `size[0]` is the *fastest-moving*
//!   axis for the named layouts: for `.image_chw` it is the width, for
//!   `.row_major_matrix` it is the number of columns, for
//!   `.convolution_weights_oihw` it is the kernel width. See `DataLayout` in
//!   `types.zig`.
//! * **A null `filter_params` means defaults**: as many threads as the machine
//!   warrants and `posix_memalign`/`free`.
//! * **Four layer kinds have their own apply entry point** and reject the
//!   generic ones with -1: arithmetic layers need
//!   `BNNSArithmeticFilterApplyBatch` (which takes an *array* of input
//!   pointers, one per operand), normalization layers
//!   `BNNSNormalizationFilterApplyBatch` (whose trailing `training` flag picks
//!   between batch statistics and the moving ones), loss layers
//!   `BNNSLossFilterApplyBatch` (predictions and labels as separate arguments),
//!   and multihead attention `BNNSApplyMultiheadAttention`. Everything else
//!   runs through `BNNSFilterApply` / `BNNSFilterApplyTwoInput`.
//! * **Failure carries no reason code.** A creator returns NULL, which becomes
//!   `Error.BnnsAllocationFailed` here; the actual complaint goes to `os_log`.
//!   Unsupported *combinations* of otherwise valid parameters fail this way
//!   too, so a null return is not necessarily a programming error.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const Activation = types.Activation;
const ArithmeticBinary = types.ArithmeticBinary;
const ArithmeticUnary = types.ArithmeticUnary;
const ConvolutionLayerParameters = types.ConvolutionLayerParameters;
const DataLayout = types.DataLayout;
const DataType = types.DataType;
const Error = types.Error;
const FilterParameters = types.FilterParameters;
const FilterType = types.FilterType;
const FullyConnectedLayerParameters = types.FullyConnectedLayerParameters;
const ImageStackDescriptor = types.ImageStackDescriptor;
const LayerData = types.LayerData;
const LayerParametersActivation = types.LayerParametersActivation;
const LayerParametersArithmetic = types.LayerParametersArithmetic;
const LayerParametersBroadcastMatMul = types.LayerParametersBroadcastMatMul;
const LayerParametersConvolution = types.LayerParametersConvolution;
const LayerParametersDropout = types.LayerParametersDropout;
const LayerParametersEmbedding = types.LayerParametersEmbedding;
const LayerParametersFullyConnected = types.LayerParametersFullyConnected;
const LayerParametersGram = types.LayerParametersGram;
const LayerParametersLossBase = types.LayerParametersLossBase;
const LayerParametersMultiheadAttention = types.LayerParametersMultiheadAttention;
const LayerParametersNormalization = types.LayerParametersNormalization;
const LayerParametersPadding = types.LayerParametersPadding;
const LayerParametersPermute = types.LayerParametersPermute;
const LayerParametersPooling = types.LayerParametersPooling;
const LayerParametersResize = types.LayerParametersResize;
const LayerParametersTensorContraction = types.LayerParametersTensorContraction;
const NDArrayDescriptor = types.NDArrayDescriptor;
const PoolingLayerParameters = types.PoolingLayerParameters;
const VectorDescriptor = types.VectorDescriptor;

/// A non-null layer-filter handle.
///
/// `BNNSFilter` is `void *` and nullable in C (`c.BNNSFilter`); every creator
/// in this module has already turned a NULL return into
/// `Error.BnnsAllocationFailed`, so what comes back here is known good. It
/// coerces implicitly to `c.BNNSFilter` wherever the raw calls want it.
///
/// The handle owns memory: release it with `BNNSFilterDestroy`. One filter can
/// be applied repeatedly. Most layers are stateless between applies; dropout is
/// not — its generator advances on every call.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const Filter = *anyopaque;

/// `BNNSLayerParametersReduction` — the parameter block of a reduction layer.
///
/// Unlike its siblings this struct is declared in `c.zig` rather than
/// `types.zig`, because `BNNSDirectApplyReduction` needs it too; it is
/// re-exported here so callers of `createLayerReduction` have it to hand. The
/// reduced axes are named implicitly: set `o_desc.size[i]` to 1 for every axis
/// to reduce and leave the rest equal to `i_desc.size[i]`.
pub const LayerParametersReduction = c.BNNSLayerParametersReduction;

/// Turn a possibly-NULL `BNNSFilter` into `Error!Filter`.
fn checkFilter(handle: c.BNNSFilter) Error!Filter {
    return handle orelse Error.BnnsAllocationFailed;
}

// ============================================================================
// Layer creation (deprecated in macOS 15.0)
// ============================================================================

/// `BNNSFilterCreateLayerConvolution` — a 2D convolution over an image stack,
/// with an optional fused bias and activation.
///
/// `Output(o,x,y) = activation(bias(o) + sum_{i,kx,ky} W(o,i,kx,ky) *
/// Input(i, x_stride*x + kx*x_dilation_stride, y_stride*y + ky*y_dilation_stride))`.
///
/// The shapes must satisfy
/// `in_width + 2*x_padding >= x_stride*(out_width - 1) + (k_width + (k_width - 1)*(x_dilation_stride - 1))`
/// and the same in y; a stride or dilation of 0 is read as 1. `w_desc` must use
/// one of the `convolution_weights_*` layouts, whose `size` is
/// `{ k_width, k_height, in_channels, out_channels }`. Set `bias.data = null`
/// for no bias.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerConvolution(
    layer_params: *const LayerParametersConvolution,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerConvolution(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerTransposedConvolution` — the transpose of a
/// convolution, also known as a deconvolution or a fractionally strided
/// convolution.
///
/// Takes the same `LayerParametersConvolution` block as `createLayerConvolution`
/// but reverses the roles of the two spatial shapes: the size constraint is
/// checked with `i_desc` and `o_desc` swapped, so the layer upsamples where a
/// convolution would downsample. Only `DataType.float32` is supported, and
/// gradients are unavailable when `groups > 1`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerTransposedConvolution(
    layer_params: *const LayerParametersConvolution,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerTransposedConvolution(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerFullyConnected` — a matrix-vector product with a fused
/// bias and activation: `Output(o) = activation(bias(o) + sum_i W(o,i)*In(i))`.
///
/// `W(o,i)` must land at `weights[i + o*in_size]`, which for a
/// `.row_major_matrix` `w_desc` means `size = { in_size, out_size }` —
/// `size[0]` is the column count. `bias` holds `out_size` values, or has a null
/// `data` for no bias.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerFullyConnected(
    layer_params: *const LayerParametersFullyConnected,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerFullyConnected(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerPooling` — max, average or L2 pooling over a
/// `k_width` by `k_height` window, with a fused bias and activation.
///
/// The shapes must satisfy `in_width + 2*x_padding >= x_stride*(out_width - 1) + 1`
/// and the same in y. Note that `average_count_include_padding` and
/// `average_count_exclude_padding` differ only in whether the virtual zero
/// border counts towards the divisor.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerPooling(
    layer_params: *const LayerParametersPooling,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerPooling(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerActivation` — applies one pointwise nonlinearity.
///
/// Input and output need only agree on their *element count*, not their layout,
/// so this doubles as a reshape. With `activation.function == .identity` and
/// differing `data_type`s it is instead a type conversion layer. Axis-sensitive
/// functions (softmax, log-softmax) read `axis_flags`, a bitmask in which 0
/// means the axis of `i_desc.size[0]`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerActivation(
    layer_params: *const LayerParametersActivation,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerActivation(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerLoss` — computes a loss between predictions and
/// labels, then collapses it with a `LossReductionFunction`.
///
/// `layer_params` is untyped in C because the block is chosen by the loss:
/// `LayerParametersLossBase` for the plain losses, and
/// `LayerParametersLossSoftmaxCrossEntropy`,
/// `LayerParametersLossSigmoidCrossEntropy`, `LayerParametersLossHuber` or
/// `LayerParametersLossYolo` for the four that carry extra fields. All five
/// begin with the same `function`/`i_desc`/`o_desc`/`reduction` prefix, which is
/// what BNNS dispatches on. Pass a pointer to whichever struct matches
/// `function`; passing the wrong one is not detectable at compile time.
///
/// The resulting filter has its own apply entry point: `BNNSLossFilterApplyBatch`,
/// which takes predictions and labels as separate arguments plus optional
/// per-sample weights. `BNNSFilterApply` and `BNNSFilterApplyTwoInput` both
/// return -1 for a loss filter. The output size follows the reduction:
/// `.none` writes one loss per input element, everything else a single scalar.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerLoss(
    layer_params: *const anyopaque,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerLoss(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerNormalization` — batch, instance, layer or group
/// normalization with a fused elementwise activation.
///
/// Which one is chosen by `norm_type`, not by the parameter block: pass
/// `.batch_norm`, `.instance_norm`, `.layer_norm` or `.group_norm`. That is the
/// only `BNNSFilterCreateLayer*` call that takes a discriminator argument.
///
/// Only `.image_chw` and `.vector` layouts are accepted, a vector of length L
/// being equivalent to an L×1×1 CHW image. `moving_mean_desc` and
/// `moving_variance_desc` are always f32 whatever the input type, apply to
/// batch and instance norm only, and are skipped entirely when their `data` is
/// null. `num_groups` is read by group norm alone, `normalization_axis` by
/// layer norm alone.
///
/// Run the filter with `BNNSNormalizationFilterApplyBatch`, whose trailing
/// `training` flag chooses between the current batch statistics and the moving
/// ones; the generic `BNNSFilterApply` returns -1 for a normalization filter.
/// In-place operation (`out == in`) is supported.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerNormalization(
    norm_type: FilterType,
    layer_params: *const LayerParametersNormalization,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerNormalization(norm_type, layer_params, filter_params));
}

/// `BNNSFilterCreateLayerArithmetic` — one elementwise arithmetic operation.
///
/// The operand descriptors are *not* in the parameter block: they live in the
/// struct `arithmetic_function_fields` points at, whose type is decided by
/// `arithmetic_function` — `ArithmeticUnary` for the one-operand functions,
/// `ArithmeticBinary` for two, `ArithmeticTernary` for `multiply_add` and
/// `select`. That pointer is read during the create call only.
///
/// Arithmetic filters have their own apply entry point,
/// `BNNSArithmeticFilterApplyBatch`, which takes an array of `number_of_inputs`
/// input pointers and a matching array of batch strides. `BNNSFilterApply` and
/// `BNNSFilterApplyTwoInput` both return -1 for an arithmetic filter, whatever
/// the operand count. Two operand descriptors sharing a `data` pointer are taken
/// to be the same tensor, in which case their sizes, strides and data types must
/// match too. Operands broadcast: any dimension may be 1 where the output's is
/// larger.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerArithmetic(
    layer_params: *const LayerParametersArithmetic,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerArithmetic(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerPermute` — copies a tensor while reordering its axes.
///
/// `permutation[k]` is the *input* axis that feeds output axis `k`, so
/// `{ 2, 1, 0 }` on an `.image_chw` tensor swaps width and channels. Input and
/// output must share a data type and a layout rank; `o_desc.size` must already
/// be the permuted sizes. Entries at or beyond the rank are ignored.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerPermute(
    layer_params: *const LayerParametersPermute,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerPermute(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerDropout` — zeroes elements with probability `rate`.
///
/// `rate` must be in [0, 1). `seed` is ignored when 0, and `control` is a
/// 4-bit mask of the dimensions along which one keep/drop decision is shared.
///
/// Note that the plain forward `BNNSFilterApply` *does* drop: it zeroes the
/// chosen elements and scales the survivors by `1/(1 - rate)`, and it advances
/// the generator, so two applies of the same filter to the same input give
/// different answers. There is no inference mode on this layer — build it with
/// `rate = 0`, or leave it out of the network entirely, when you want the
/// identity.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerDropout(
    layer_params: *const LayerParametersDropout,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerDropout(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerPadding` — grows a tensor by adding a border.
///
/// `o_desc.size[d]` must equal
/// `i_desc.size[d] + padding_size[d][0] + padding_size[d][1]` for every `d`
/// within the layout's rank; entries beyond it are not read. For
/// `PaddingMode.constant`, `padding_value` supplies the fill: it is a raw
/// 32-bit pattern of which only the leading `@sizeOf(element)` bytes are used,
/// so an f32 fill must be `@bitCast` rather than converted.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerPadding(
    layer_params: *const LayerParametersPadding,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerPadding(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerBroadcastMatMul` — a matrix multiply over the last two
/// axes of each operand, broadcasting all the leading ones.
///
/// `C = beta*C + alpha*op(A)*op(B)`, where `beta` must be exactly 0.0 or 1.0 and
/// `transA`/`transB` transpose the trailing two axes. Leading axes are matched
/// from the back, and an axis of size 1 is repeated. Set `quadratic` when B is
/// A: inference is merely faster for it, but the backward pass is only correct
/// with it set. Run the layer with `BNNSFilterApplyTwoInput`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerBroadcastMatMul(
    layer_params: *const LayerParametersBroadcastMatMul,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerBroadcastMatMul(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerTensorContraction` — an arbitrary contraction written
/// in Einstein summation notation, e.g. `"a_ijp, b_ijq -> o_pq"` for
/// `o_pq = alpha * sum_ij a_ijp * b_ijq`.
///
/// An operand whose name begins with `w` is treated as trained weights, and at
/// most one may be. `*` as the first or last index broadcasts, and must sit at
/// the same end for every operand. Matching index letters must name equal
/// sizes, unless one side has size 1 and can be broadcast.
///
/// The number of genuine inputs decides how the filter is applied: with two,
/// `BNNSFilterApplyTwoInput` is required; with one — a single operand, a
/// weights operand, or a tensor contracted with itself — plain
/// `BNNSFilterApply` works. `beta` must be exactly 0.0 or 1.0.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerTensorContraction(
    layer_params: *const LayerParametersTensorContraction,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerTensorContraction(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerGram` — the Gram matrix
/// `G[f,c] = alpha * sum_ij x[i,j,f] * x[i,j,c]`, with any leading axes
/// broadcast.
///
/// Equivalent to `createLayerTensorContraction` with
/// `"x_*ijf, x_*ijc -> G_*fc"`, and, being a contraction of a tensor with
/// itself, is applied with the single-input `BNNSFilterApply`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerGram(
    layer_params: *const LayerParametersGram,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerGram(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerResize` — resamples the axes whose input and output
/// sizes differ, leaving the rest alone.
///
/// Every resized axis must scale the same way — all up or all down, no mixture
/// — and the output sizes must be an integral multiple of the input's.
/// `.linear` interpolation is limited to at most two resized axes; `.nearest`
/// has no such limit. `align_corners` puts the sampling grid on the centres of
/// the scaled axes rather than their edges.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerResize(
    layer_params: *const LayerParametersResize,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerResize(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerMultiheadAttention` — the multihead attention block of
/// "Attention is All You Need".
///
/// Nothing is passed as a scalar shape: every dimension is inferred from the
/// descriptors. `num_heads` comes from `query.weights.size[2]`, `d_model` from
/// `query.target_desc.size[1]`, `d_key` from `key.weights.size[1]`, `d_value`
/// from `output.target_desc.size[1]`, and the two sequence lengths from
/// `query.target_desc.size[0]` and `key.target_desc.size[0]`. The three
/// projection weight tensors use the `.mha_dhk` layout. `key_attn_bias` and
/// `value_attn_bias` are optional but must be supplied together. `dropout`
/// outside the open interval (0, 1) — 0 included — disables dropout.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerMultiheadAttention(
    layer_params: *const LayerParametersMultiheadAttention,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerMultiheadAttention(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerReduction` — reduces one or more axes with a
/// `ReduceFunction`.
///
/// The reduced axes are named by shape rather than by an axis list: set
/// `o_desc.size[i]` to 1 for each axis to collapse, and leave every other entry
/// equal to `i_desc.size[i]`. `w_desc` supplies per-element weights for the
/// reductions that take them and should otherwise be left zeroed with a null
/// `data`. `epsilon` is added to the argument of `sum_log`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn createLayerReduction(
    layer_params: *const LayerParametersReduction,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerReduction(layer_params, filter_params));
}

/// `BNNSFilterCreateLayerEmbedding` — a lookup table.
///
/// Each integer in the input indexes `dictionary`, whose shape is one
/// dictionary item with a trailing axis of `num_embeddings`. The output shape is
/// the item shape concatenated with the input shape, so a dictionary of
/// `(3, 4, 5)` and an input of `(6, 7)` produce `(3, 4, 6, 7)`. `i_desc` must
/// name a signed or unsigned integer type. A `padding_idx` inside
/// `[0, num_embeddings - 1]` makes that entry read as an all-zero item.
/// `max_norm`, when nonzero, renormalizes over-long items during the forward
/// lookup, using the `norm_type`-norm (0 meaning the 2-norm).
///
/// Introduced in macOS 12.0, later than its siblings. Deprecated in macOS 15.0.
/// Prefer the Graph API (`bnns.Graph`).
pub fn createLayerEmbedding(
    layer_params: *const LayerParametersEmbedding,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateLayerEmbedding(layer_params, filter_params));
}

// ============================================================================
// First-generation layer creation (deprecated in macOS 11.0)
// ============================================================================
//
// These four predate the `BNNSLayerParameters*` blocks entirely: the tensor
// shapes come in as separate `in_desc`/`out_desc` arguments, weights come in as
// untyped `LayerData` blobs with no shape of their own, and there is no
// `NDArrayDescriptor` anywhere. They were deprecated in macOS 11.0 — four
// releases before the rest of this file — each naming its `...LayerX`
// successor, which was then itself deprecated in macOS 15.0. There is no reason
// to reach for them in new code; they are bound so that existing callers can be
// ported mechanically.

/// `BNNSFilterCreateConvolutionLayer` — the first-generation convolution.
///
/// Same arithmetic as `createLayerConvolution`, but the shapes come from
/// `in_desc`/`out_desc` and the kernel dimensions from `layer_params`, with the
/// weights a bare pointer holding
/// `k_width * k_height * in_channels * out_channels` values at
/// `weights[kx + k_width*(ky + k_height*(i + in_channels*o))]`. No dilation, no
/// groups, and only symmetric padding.
///
/// Deprecated in macOS 11.0 with replacement `BNNSFilterCreateLayerConvolution`
/// (`createLayerConvolution`), which is itself deprecated in macOS 15.0 —
/// prefer the Graph API (`bnns.Graph`).
pub fn createConvolutionLayer(
    in_desc: *const ImageStackDescriptor,
    out_desc: *const ImageStackDescriptor,
    layer_params: *const ConvolutionLayerParameters,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateConvolutionLayer(in_desc, out_desc, layer_params, filter_params));
}

/// `BNNSFilterCreateFullyConnectedLayer` — the first-generation fully connected
/// layer, `Output(o) = activation(bias(o) + sum_i W(o,i)*Input(i))` with
/// `W(o,i)` at `weights[i + o*in_size]`.
///
/// `in_desc.size` must equal `layer_params.in_size` and `out_desc.size`
/// `layer_params.out_size`; the sizes are stated twice and BNNS checks that they
/// agree.
///
/// Deprecated in macOS 11.0 with replacement
/// `BNNSFilterCreateLayerFullyConnected` (`createLayerFullyConnected`), which is
/// itself deprecated in macOS 15.0 — prefer the Graph API (`bnns.Graph`).
pub fn createFullyConnectedLayer(
    in_desc: *const VectorDescriptor,
    out_desc: *const VectorDescriptor,
    layer_params: *const FullyConnectedLayerParameters,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateFullyConnectedLayer(in_desc, out_desc, layer_params, filter_params));
}

/// `BNNSFilterCreatePoolingLayer` — the first-generation pooling layer.
///
/// Same arithmetic as `createLayerPooling`, with the shapes in
/// `in_desc`/`out_desc`. No dilation and no asymmetric padding.
///
/// Deprecated in macOS 11.0 with replacement `BNNSFilterCreateLayerPooling`
/// (`createLayerPooling`), which is itself deprecated in macOS 15.0 — prefer the
/// Graph API (`bnns.Graph`).
pub fn createPoolingLayer(
    in_desc: *const ImageStackDescriptor,
    out_desc: *const ImageStackDescriptor,
    layer_params: *const PoolingLayerParameters,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreatePoolingLayer(in_desc, out_desc, layer_params, filter_params));
}

/// `BNNSFilterCreateVectorActivationLayer` — the first-generation activation and
/// type-conversion layer, over vectors only.
///
/// Note the shape of the call: there is no parameter block at all, just the two
/// vector descriptors and a bare `Activation`. Input and output must have the
/// same `size`; a differing `data_type` between them makes this a conversion.
///
/// Introduced in macOS 10.13, a release later than the other three.
/// Deprecated in macOS 11.0 with replacement `BNNSFilterCreateLayerActivation`
/// (`createLayerActivation`), which is itself deprecated in macOS 15.0 — prefer
/// the Graph API (`bnns.Graph`).
pub fn createVectorActivationLayer(
    in_desc: *const VectorDescriptor,
    out_desc: *const VectorDescriptor,
    activation: *const Activation,
    filter_params: ?*const FilterParameters,
) Error!Filter {
    return checkFilter(c.BNNSFilterCreateVectorActivationLayer(in_desc, out_desc, activation, filter_params));
}

// ============================================================================
// Tests
// ============================================================================
//
// Every test that can be made to run actually runs the filter and checks the
// numbers, because a wrapper with the wrong arity or a value-versus-pointer
// mistake still links and still returns a non-null handle — a "no error"
// assertion would pass right through it.
//
// The apply and destroy entry points live in `bnns.filter`, which is a separate
// module; these tests call `c.BNNSFilterApply*` and `c.BNNSFilterDestroy`
// directly rather than depending on it.

const testing = std.testing;

/// Build an `NDArrayDescriptor` for a test. `data` is null for the tensors
/// whose buffer is passed to the apply call instead.
fn desc(comptime T: type, layout: DataLayout, sizes: []const usize, data: ?[]const T) NDArrayDescriptor {
    std.debug.assert(sizes.len <= types.max_tensor_dimension);
    var d = NDArrayDescriptor{ .layout = layout, .data_type = DataType.of(T) };
    for (sizes, 0..) |s, i| d.size[i] = s;
    if (data) |p| d.data = @ptrCast(@constCast(p.ptr));
    return d;
}

fn destroy(f: Filter) void {
    c.BNNSFilterDestroy(f);
}

fn apply(f: Filter, in: []const f32, out: []f32) !void {
    try types.check(c.BNNSFilterApply(f, @ptrCast(in.ptr), @ptrCast(out.ptr)));
}

fn applyTwo(f: Filter, a: []const f32, b: []const f32, out: []f32) !void {
    try types.check(c.BNNSFilterApplyTwoInput(f, @ptrCast(a.ptr), @ptrCast(b.ptr), @ptrCast(out.ptr)));
}

/// Arithmetic layers take their operands as an array of pointers.
fn applyArithmetic(f: Filter, ins: []const *const anyopaque, strides: []const usize, out: []f32) !void {
    std.debug.assert(ins.len == strides.len);
    try types.check(c.BNNSArithmeticFilterApplyBatch(f, 1, ins.len, ins.ptr, strides.ptr, @ptrCast(out.ptr), out.len));
}

fn expectClose(expected: []const f32, actual: []const f32) !void {
    try testing.expectEqual(expected.len, actual.len);
    for (expected, actual) |e, a| try testing.expectApproxEqAbs(e, a, 1e-5);
}

test "activation layer computes ReLU" {
    var params = LayerParametersActivation{
        .i_desc = desc(f32, .vector, &.{4}, null),
        .o_desc = desc(f32, .vector, &.{4}, null),
        .activation = .{ .function = .rectified_linear },
    };

    const f = try createLayerActivation(&params, null);
    defer destroy(f);

    var out: [4]f32 = @splat(-99);
    try apply(f, &[_]f32{ -1, 2, -3, 4 }, &out);
    try expectClose(&.{ 0, 2, 0, 4 }, &out);
}

test "activation layer computes clamp from alpha and beta" {
    // clamp(x) = min(max(x, alpha), beta): proves alpha/beta reach BNNS in the
    // right order, which an identity activation would not.
    var params = LayerParametersActivation{
        .i_desc = desc(f32, .vector, &.{5}, null),
        .o_desc = desc(f32, .vector, &.{5}, null),
        .activation = .{ .function = .clamp, .alpha = -1, .beta = 2 },
    };

    const f = try createLayerActivation(&params, null);
    defer destroy(f);

    var out: [5]f32 = @splat(-99);
    try apply(f, &[_]f32{ -5, -1, 0.5, 2, 7 }, &out);
    try expectClose(&.{ -1, -1, 0.5, 2, 2 }, &out);
}

test "fully connected layer computes W*x + b" {
    // W is 2x3 with W(o,i) at weights[i + o*3], so a .row_major_matrix whose
    // size[0] is the column count.
    const weights = [_]f32{ 1, 2, 3, 4, 5, 6 };
    const bias = [_]f32{ 0.5, -1 };

    var params = LayerParametersFullyConnected{
        .i_desc = desc(f32, .vector, &.{3}, null),
        .w_desc = desc(f32, .row_major_matrix, &.{ 3, 2 }, &weights),
        .o_desc = desc(f32, .vector, &.{2}, null),
        .bias = desc(f32, .vector, &.{2}, &bias),
        .activation = .{ .function = .identity },
    };

    const f = try createLayerFullyConnected(&params, null);
    defer destroy(f);

    var out: [2]f32 = @splat(-99);
    // W*(1,1,1) = (6, 15), plus bias (0.5, -1).
    try apply(f, &[_]f32{ 1, 1, 1 }, &out);
    try expectClose(&.{ 6.5, 14 }, &out);

    // W*(1,0,-1) = (1-3, 4-6) = (-2, -2), plus bias.
    try apply(f, &[_]f32{ 1, 0, -1 }, &out);
    try expectClose(&.{ -1.5, -3 }, &out);
}

test "convolution layer sums a 2x2 window of ones" {
    // 3x3 single-channel input, 2x2 kernel of ones, stride 1, no padding: the
    // output is the sum of each 2x2 window.
    const weights = [_]f32{ 1, 1, 1, 1 };

    var params = LayerParametersConvolution{
        .i_desc = desc(f32, .image_chw, &.{ 3, 3, 1 }, null),
        .w_desc = desc(f32, .convolution_weights_oihw, &.{ 2, 2, 1, 1 }, &weights),
        .o_desc = desc(f32, .image_chw, &.{ 2, 2, 1 }, null),
        .bias = desc(f32, .vector, &.{1}, null),
        .activation = .{ .function = .identity },
        .x_stride = 1,
        .y_stride = 1,
    };

    const f = try createLayerConvolution(&params, null);
    defer destroy(f);

    var out: [4]f32 = @splat(-99);
    // Rows 1 2 3 / 4 5 6 / 7 8 9.
    try apply(f, &[_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, &out);
    try expectClose(&.{ 12, 16, 24, 28 }, &out);
}

test "transposed convolution with a 1x1 kernel scales its input" {
    // A 1x1 kernel with unit stride makes input and output the same shape,
    // which is the one transposed-convolution configuration that is trivial to
    // check by hand: each pixel is multiplied by the single weight.
    const weights = [_]f32{2};

    var params = LayerParametersConvolution{
        .i_desc = desc(f32, .image_chw, &.{ 2, 2, 1 }, null),
        .w_desc = desc(f32, .convolution_weights_oihw, &.{ 1, 1, 1, 1 }, &weights),
        .o_desc = desc(f32, .image_chw, &.{ 2, 2, 1 }, null),
        .bias = desc(f32, .vector, &.{1}, null),
        .activation = .{ .function = .identity },
        .x_stride = 1,
        .y_stride = 1,
    };

    const f = try createLayerTransposedConvolution(&params, null);
    defer destroy(f);

    var out: [4]f32 = @splat(-99);
    try apply(f, &[_]f32{ 1, 2, 3, 4 }, &out);
    try expectClose(&.{ 2, 4, 6, 8 }, &out);
}

test "pooling layer takes the maximum of each 2x2 window" {
    var params = LayerParametersPooling{
        .i_desc = desc(f32, .image_chw, &.{ 3, 3, 1 }, null),
        .o_desc = desc(f32, .image_chw, &.{ 2, 2, 1 }, null),
        .bias = desc(f32, .vector, &.{1}, null),
        .activation = .{ .function = .identity },
        .pooling_function = .max,
        .k_width = 2,
        .k_height = 2,
        .x_stride = 1,
        .y_stride = 1,
    };

    const f = try createLayerPooling(&params, null);
    defer destroy(f);

    var out: [4]f32 = @splat(-99);
    try apply(f, &[_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, &out);
    try expectClose(&.{ 5, 6, 8, 9 }, &out);
}

test "pooling layer averages, counting the padded positions" {
    // 2x2 input, 2x2 window, one pixel of padding on every side, stride 2 gives
    // a 2x2 output. Counting padding, each window divides by 4.
    var params = LayerParametersPooling{
        .i_desc = desc(f32, .image_chw, &.{ 2, 2, 1 }, null),
        .o_desc = desc(f32, .image_chw, &.{ 2, 2, 1 }, null),
        .bias = desc(f32, .vector, &.{1}, null),
        .activation = .{ .function = .identity },
        .pooling_function = .average_count_include_padding,
        .k_width = 2,
        .k_height = 2,
        .x_stride = 2,
        .y_stride = 2,
        .x_padding = 1,
        .y_padding = 1,
    };

    const f = try createLayerPooling(&params, null);
    defer destroy(f);

    var out: [4]f32 = @splat(-99);
    // Padded input is 4x4 with the data at the centre:
    //   0 0 0 0 / 0 1 2 0 / 0 3 4 0 / 0 0 0 0
    // The four stride-2 windows hold {0,0,0,1}, {0,0,2,0}, {0,3,0,0}, {4,0,0,0}.
    try apply(f, &[_]f32{ 1, 2, 3, 4 }, &out);
    try expectClose(&.{ 0.25, 0.5, 0.75, 1 }, &out);
}

test "arithmetic layer adds two inputs" {
    var fields = ArithmeticBinary{
        .in1 = desc(f32, .vector, &.{3}, null),
        .in1_type = .sample,
        .in2 = desc(f32, .vector, &.{3}, null),
        .in2_type = .sample,
        .out = desc(f32, .vector, &.{3}, null),
        .out_type = .sample,
    };
    var params = LayerParametersArithmetic{
        .arithmetic_function = .add,
        .arithmetic_function_fields = @ptrCast(&fields),
        .activation = .{ .function = .identity },
    };

    const f = try createLayerArithmetic(&params, null);
    defer destroy(f);

    const in1 = [_]f32{ 1, 2, 3 };
    const in2 = [_]f32{ 10, 20, 30 };
    var out: [3]f32 = @splat(-99);
    try applyArithmetic(f, &.{ @ptrCast(&in1), @ptrCast(&in2) }, &.{ 3, 3 }, &out);
    try expectClose(&.{ 11, 22, 33 }, &out);

    // The generic entry points do not work on an arithmetic filter, whatever
    // the operand count; this is the only way to run one.
    try testing.expectError(Error.BnnsFailed, applyTwo(f, &in1, &in2, &out));
    try testing.expectError(Error.BnnsFailed, apply(f, &in1, &out));
}

test "arithmetic layer applies a unary function" {
    // A one-operand function still goes through BNNSArithmeticFilterApplyBatch,
    // just with an input array of length 1.
    var fields = ArithmeticUnary{
        .in = desc(f32, .vector, &.{4}, null),
        .in_type = .sample,
        .out = desc(f32, .vector, &.{4}, null),
        .out_type = .sample,
    };
    var params = LayerParametersArithmetic{
        .arithmetic_function = .square,
        .arithmetic_function_fields = @ptrCast(&fields),
        .activation = .{ .function = .identity },
    };

    const f = try createLayerArithmetic(&params, null);
    defer destroy(f);

    const in = [_]f32{ -3, -1, 2, 4 };
    var out: [4]f32 = @splat(-99);
    try applyArithmetic(f, &.{@ptrCast(&in)}, &.{4}, &out);
    try expectClose(&.{ 9, 1, 4, 16 }, &out);
}

test "permute layer transposes a 2x3 tensor" {
    var params = LayerParametersPermute{
        .i_desc = desc(f32, .@"2d_first_major", &.{ 2, 3 }, null),
        .o_desc = desc(f32, .@"2d_first_major", &.{ 3, 2 }, null),
        .permutation = .{ 1, 0, 0, 0, 0, 0, 0, 0 },
    };

    const f = try createLayerPermute(&params, null);
    defer destroy(f);

    var out: [6]f32 = @splat(-99);
    // Input rows (1 2 3) and (4 5 6); the transpose is (1 4) (2 5) (3 6).
    try apply(f, &[_]f32{ 1, 2, 3, 4, 5, 6 }, &out);
    try expectClose(&.{ 1, 4, 2, 5, 3, 6 }, &out);
}

test "padding layer inserts a constant border" {
    var params = LayerParametersPadding{
        .i_desc = desc(f32, .vector, &.{3}, null),
        .o_desc = desc(f32, .vector, &.{6}, null),
        .padding_size = .{ .{ 1, 2 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 } },
        .padding_mode = .constant,
        // The fill is a raw bit pattern, not a converted value.
        .padding_value = @bitCast(@as(f32, 7)),
    };

    const f = try createLayerPadding(&params, null);
    defer destroy(f);

    var out: [6]f32 = @splat(-99);
    try apply(f, &[_]f32{ 1, 2, 3 }, &out);
    try expectClose(&.{ 7, 1, 2, 3, 7, 7 }, &out);
}

test "resize layer doubles an image with nearest-neighbour sampling" {
    var params = LayerParametersResize{
        .method = .nearest,
        .i_desc = desc(f32, .image_chw, &.{ 2, 2, 1 }, null),
        .o_desc = desc(f32, .image_chw, &.{ 4, 4, 1 }, null),
        .align_corners = false,
    };

    const f = try createLayerResize(&params, null);
    defer destroy(f);

    var out: [16]f32 = @splat(-99);
    // Input 1 2 / 3 4; each pixel becomes a 2x2 block.
    try apply(f, &[_]f32{ 1, 2, 3, 4 }, &out);
    try expectClose(&.{
        1, 1, 2, 2,
        1, 1, 2, 2,
        3, 3, 4, 4,
        3, 3, 4, 4,
    }, &out);
}

test "gram layer computes x-transpose times x across channels" {
    // x is 2 wide, 1 high, 2 channels: channel 0 is (1, 2), channel 1 is (3, 4).
    // G[f,c] = sum over the spatial axes of x[.,.,f]*x[.,.,c].
    var params = LayerParametersGram{
        .alpha = 1,
        .i_desc = desc(f32, .image_chw, &.{ 2, 1, 2 }, null),
        .o_desc = desc(f32, .row_major_matrix, &.{ 2, 2 }, null),
    };

    const f = try createLayerGram(&params, null);
    defer destroy(f);

    var out: [4]f32 = @splat(-99);
    // G[0,0] = 1+4 = 5, G[0,1] = G[1,0] = 3+8 = 11, G[1,1] = 9+16 = 25.
    try apply(f, &[_]f32{ 1, 2, 3, 4 }, &out);
    try expectClose(&.{ 5, 11, 11, 25 }, &out);
}

test "gram layer honours alpha" {
    var params = LayerParametersGram{
        .alpha = 2,
        .i_desc = desc(f32, .image_chw, &.{ 2, 1, 2 }, null),
        .o_desc = desc(f32, .row_major_matrix, &.{ 2, 2 }, null),
    };

    const f = try createLayerGram(&params, null);
    defer destroy(f);

    var out: [4]f32 = @splat(-99);
    try apply(f, &[_]f32{ 1, 2, 3, 4 }, &out);
    try expectClose(&.{ 10, 22, 22, 50 }, &out);
}

test "broadcast matmul multiplies a 2x3 by a 3x2" {
    // .row_major_matrix puts the column count in size[0], so a 2x3 matrix is
    // { 3, 2 }.
    var params = LayerParametersBroadcastMatMul{
        .alpha = 1,
        .beta = 0,
        .transA = false,
        .transB = false,
        .quadratic = false,
        .a_is_weights = false,
        .b_is_weights = false,
        .iA_desc = desc(f32, .row_major_matrix, &.{ 3, 2 }, null),
        .iB_desc = desc(f32, .row_major_matrix, &.{ 2, 3 }, null),
        .o_desc = desc(f32, .row_major_matrix, &.{ 2, 2 }, null),
    };

    const f = try createLayerBroadcastMatMul(&params, null);
    defer destroy(f);

    var out: [4]f32 = @splat(-99);
    // A = (1 2 3; 4 5 6), B = (1 0; 0 1; 1 1) => A*B = (4 5; 10 11).
    try applyTwo(f, &[_]f32{ 1, 2, 3, 4, 5, 6 }, &[_]f32{ 1, 0, 0, 1, 1, 1 }, &out);
    try expectClose(&.{ 4, 5, 10, 11 }, &out);
}

test "tensor contraction transposes with a summation string" {
    // A single-operand contraction, so plain BNNSFilterApply drives it.
    var params = LayerParametersTensorContraction{
        .operation = "a_ij -> c_ji",
        .alpha = 1,
        .beta = 0,
        .iA_desc = desc(f32, .@"2d_first_major", &.{ 2, 3 }, null),
        .iB_desc = desc(f32, .@"2d_first_major", &.{ 0, 0 }, null),
        .o_desc = desc(f32, .@"2d_first_major", &.{ 3, 2 }, null),
    };

    const f = try createLayerTensorContraction(&params, null);
    defer destroy(f);

    var out: [6]f32 = @splat(-99);
    try apply(f, &[_]f32{ 1, 2, 3, 4, 5, 6 }, &out);
    try expectClose(&.{ 1, 4, 2, 5, 3, 6 }, &out);
}

test "reduction layer sums the axis whose output size is 1" {
    var params = LayerParametersReduction{
        .i_desc = desc(f32, .image_chw, &.{ 4, 1, 1 }, null),
        .o_desc = desc(f32, .image_chw, &.{ 1, 1, 1 }, null),
        .w_desc = desc(f32, .image_chw, &.{ 0, 0, 0 }, null),
        .reduce_func = .sum,
        .epsilon = 0,
    };

    const f = try createLayerReduction(&params, null);
    defer destroy(f);

    var out: [1]f32 = @splat(-99);
    try apply(f, &[_]f32{ 1, 2, 3, 4 }, &out);
    try expectClose(&.{10}, &out);
}

test "reduction layer takes the maximum along the width" {
    var params = LayerParametersReduction{
        .i_desc = desc(f32, .image_chw, &.{ 3, 2, 1 }, null),
        .o_desc = desc(f32, .image_chw, &.{ 1, 2, 1 }, null),
        .w_desc = desc(f32, .image_chw, &.{ 0, 0, 0 }, null),
        .reduce_func = .max,
        .epsilon = 0,
    };

    const f = try createLayerReduction(&params, null);
    defer destroy(f);

    var out: [2]f32 = @splat(-99);
    // Rows (1 9 2) and (4 3 8).
    try apply(f, &[_]f32{ 1, 9, 2, 4, 3, 8 }, &out);
    try expectClose(&.{ 9, 8 }, &out);
}

test "layer normalization centres and scales a vector" {
    var params = LayerParametersNormalization{
        .i_desc = desc(f32, .vector, &.{4}, null),
        .o_desc = desc(f32, .vector, &.{4}, null),
        .beta_desc = desc(f32, .vector, &.{0}, null),
        .gamma_desc = desc(f32, .vector, &.{0}, null),
        .moving_mean_desc = desc(f32, .vector, &.{0}, null),
        .moving_variance_desc = desc(f32, .vector, &.{0}, null),
        .momentum = 0,
        .epsilon = 1e-5,
        .activation = .{ .function = .identity },
        .num_groups = 0,
        .normalization_axis = 0,
    };

    const f = try createLayerNormalization(.layer_norm, &params, null);
    defer destroy(f);

    const in = [_]f32{ 1, 2, 3, 4 };
    var out: [4]f32 = @splat(-99);
    // mean 2.5, variance 1.25, so (x - 2.5)/sqrt(1.25 + 1e-5).
    try types.check(c.BNNSNormalizationFilterApplyBatch(f, 1, @ptrCast(&in), 4, @ptrCast(&out), 4, false));
    const s = 1.0 / @sqrt(1.25 + 1e-5);
    try expectClose(&.{ -1.5 * s, -0.5 * s, 0.5 * s, 1.5 * s }, &out);

    // Normalization has its own entry point for the sake of that `training`
    // flag; the generic one is rejected.
    try testing.expectError(Error.BnnsFailed, apply(f, &in, &out));
}

test "dropout layer with rate 0 is the identity" {
    var params = LayerParametersDropout{
        .i_desc = desc(f32, .vector, &.{4}, null),
        .o_desc = desc(f32, .vector, &.{4}, null),
        .rate = 0,
        .seed = 1234,
        .control = 0,
    };

    const f = try createLayerDropout(&params, null);
    defer destroy(f);

    var out: [4]f32 = @splat(-99);
    try apply(f, &[_]f32{ 1, 2, 3, 4 }, &out);
    try expectClose(&.{ 1, 2, 3, 4 }, &out);
}

test "dropout layer drops and rescales on the plain forward apply" {
    // There is no inference mode here: a nonzero rate zeroes elements and
    // multiplies the survivors by 1/(1 - rate) even through BNNSFilterApply.
    // The pattern is seeded and advances per call, so only the two possible
    // per-element values are asserted, not which one lands where.
    var params = LayerParametersDropout{
        .i_desc = desc(f32, .vector, &.{8}, null),
        .o_desc = desc(f32, .vector, &.{8}, null),
        .rate = 0.5,
        .seed = 1234,
        .control = 0,
    };

    const f = try createLayerDropout(&params, null);
    defer destroy(f);

    const in = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var first: [8]f32 = @splat(-99);
    var second: [8]f32 = @splat(-99);
    try apply(f, &in, &first);
    try apply(f, &in, &second);

    var differ = false;
    for (in, first, second) |x, a, b| {
        try testing.expect(a == 0 or a == 2 * x);
        try testing.expect(b == 0 or b == 2 * x);
        if (a != b) differ = true;
    }
    // The generator advances, so a second apply of the same filter to the same
    // input is not the same result.
    try testing.expect(differ);
}

test "embedding layer looks items up in a dictionary" {
    // Dictionary of 3 embeddings, each a 2-vector: shape { 2, 3 } with the
    // embedding count last. Item e is (10*(2e+1), 10*(2e+2)).
    const dictionary = [_]f32{
        10, 30, 50, // component 0 of embeddings 0, 1, 2
        20, 40, 60, // component 1
    };
    const indices = [_]u32{ 2, 0 };

    var params = LayerParametersEmbedding{
        .flags = @enumFromInt(0),
        .i_desc = desc(u32, .vector, &.{2}, null),
        .o_desc = desc(f32, .@"2d_first_major", &.{ 2, 2 }, null),
        .dictionary = desc(f32, .@"2d_first_major", &.{ 2, 3 }, &dictionary),
        .padding_idx = std.math.maxInt(usize),
        .max_norm = 0,
        .norm_type = 0,
    };

    const f = try createLayerEmbedding(&params, null);
    defer destroy(f);

    var out: [4]f32 = @splat(-99);
    try types.check(c.BNNSFilterApply(f, @ptrCast(&indices), @ptrCast(&out)));
    // Output is (item shape, input shape) = (2, 2): component k of the item
    // named by index n. Indices are 2 then 0, i.e. (50, 60) then (10, 20).
    try expectClose(&.{ 50, 10, 60, 20 }, &out);
}

test "loss layer computes a mean squared error under each reduction" {
    // Predictions (1, 2, 3) against labels (0, 2, 6): squared errors 1, 0, 9.
    const preds = [_]f32{ 1, 2, 3 };
    const labels = [_]f32{ 0, 2, 6 };

    inline for (.{
        .{ types.LossReductionFunction.none, [_]f32{ 1, 0, 9 } },
        .{ types.LossReductionFunction.sum, [_]f32{10} },
        .{ types.LossReductionFunction.mean, [_]f32{10.0 / 3.0} },
    }) |case| {
        const expected: [case[1].len]f32 = case[1];
        var params = LayerParametersLossBase{
            .function = .mean_square_error,
            .i_desc = desc(f32, .vector, &.{3}, null),
            .o_desc = desc(f32, .vector, &.{expected.len}, null),
            .reduction = case[0],
        };

        const f = try createLayerLoss(&params, null);
        defer destroy(f);

        var out: [3]f32 = @splat(-99);
        try types.check(c.BNNSLossFilterApplyBatch(
            f,
            1,
            @ptrCast(&preds),
            preds.len,
            @ptrCast(&labels),
            labels.len,
            null, // no per-sample loss weights
            0,
            @ptrCast(&out),
            null, // no input-delta output
            0,
        ));
        try expectClose(&expected, out[0..expected.len]);

        // Losses take predictions and labels through their own entry point.
        try testing.expectError(Error.BnnsFailed, applyTwo(f, &preds, &labels, &out));
    }
}

// `createLayerMultiheadAttention` gets no numeric test. The parameter block is
// four `MHAProjectionParameters` — query, key, value and output — each holding a
// target, a weights and a bias descriptor, and none of the shapes are given
// directly: `num_heads`, `d_model`, `d_key`, `d_value` and both sequence lengths
// are all inferred from `size[]` entries spread across those twelve descriptors,
// with the three projection weight tensors in the `.mha_dhk` layout whose
// element order (`d*stride[0] + h*stride[1] + k*stride[2]`) does not match its
// own `size[]` order. Filling that in blind and asserting a non-null handle
// would test nothing that a wrong signature could fail, so it is left to a
// caller with a real model. The observed behaviour of an under-specified block
// is a NULL return, i.e. `Error.BnnsAllocationFailed`, with the complaint in
// `os_log` — see the test below.

test "multihead attention rejects an empty parameter block" {
    // Records what an unfillable block actually does: BNNS validates and returns
    // NULL rather than crashing or handing back a broken filter.
    const empty = NDArrayDescriptor{ .layout = .vector, .data_type = .float32 };
    const projection = types.MHAProjectionParameters{
        .target_desc = empty,
        .weights = empty,
        .bias = empty,
    };
    var params = LayerParametersMultiheadAttention{
        .query = projection,
        .key = projection,
        .value = projection,
        .add_zero_attn = false,
        .key_attn_bias = empty,
        .value_attn_bias = empty,
        .output = projection,
        .dropout = 0,
        .seed = 0,
    };

    try testing.expectError(
        Error.BnnsAllocationFailed,
        createLayerMultiheadAttention(&params, null),
    );
}

// -- First-generation constructors --

test "first-generation convolution layer sums a 2x2 window" {
    const weights = [_]f32{ 1, 1, 1, 1 };

    const in_desc = ImageStackDescriptor{
        .width = 3,
        .height = 3,
        .channels = 1,
        .row_stride = 3,
        .image_stride = 9,
        .data_type = .float32,
    };
    const out_desc = ImageStackDescriptor{
        .width = 2,
        .height = 2,
        .channels = 1,
        .row_stride = 2,
        .image_stride = 4,
        .data_type = .float32,
    };
    const params = ConvolutionLayerParameters{
        .x_stride = 1,
        .y_stride = 1,
        .k_width = 2,
        .k_height = 2,
        .in_channels = 1,
        .out_channels = 1,
        .weights = LayerData{ .data = @ptrCast(&weights), .data_type = .float32 },
        .bias = LayerData{ .data = null, .data_type = .float32 },
        .activation = .{ .function = .identity },
    };

    const f = try createConvolutionLayer(&in_desc, &out_desc, &params, null);
    defer destroy(f);

    var out: [4]f32 = @splat(-99);
    try apply(f, &[_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, &out);
    try expectClose(&.{ 12, 16, 24, 28 }, &out);
}

test "first-generation fully connected layer computes W*x" {
    const weights = [_]f32{ 1, 2, 3, 4, 5, 6 };

    const in_desc = VectorDescriptor{ .size = 3, .data_type = .float32 };
    const out_desc = VectorDescriptor{ .size = 2, .data_type = .float32 };
    const params = FullyConnectedLayerParameters{
        .in_size = 3,
        .out_size = 2,
        .weights = LayerData{ .data = @ptrCast(&weights), .data_type = .float32 },
        .bias = LayerData{ .data = null, .data_type = .float32 },
        .activation = .{ .function = .identity },
    };

    const f = try createFullyConnectedLayer(&in_desc, &out_desc, &params, null);
    defer destroy(f);

    var out: [2]f32 = @splat(-99);
    try apply(f, &[_]f32{ 1, 1, 1 }, &out);
    try expectClose(&.{ 6, 15 }, &out);
}

test "first-generation pooling layer takes a 2x2 maximum" {
    const in_desc = ImageStackDescriptor{
        .width = 3,
        .height = 3,
        .channels = 1,
        .row_stride = 3,
        .image_stride = 9,
        .data_type = .float32,
    };
    const out_desc = ImageStackDescriptor{
        .width = 2,
        .height = 2,
        .channels = 1,
        .row_stride = 2,
        .image_stride = 4,
        .data_type = .float32,
    };
    const params = PoolingLayerParameters{
        .x_stride = 1,
        .y_stride = 1,
        .k_width = 2,
        .k_height = 2,
        .in_channels = 1,
        .out_channels = 1,
        .pooling_function = .max,
        .bias = LayerData{ .data = null, .data_type = .float32 },
        .activation = .{ .function = .identity },
    };

    const f = try createPoolingLayer(&in_desc, &out_desc, &params, null);
    defer destroy(f);

    var out: [4]f32 = @splat(-99);
    try apply(f, &[_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 }, &out);
    try expectClose(&.{ 5, 6, 8, 9 }, &out);
}

test "first-generation vector activation layer computes ReLU" {
    const in_desc = VectorDescriptor{ .size = 4, .data_type = .float32 };
    const out_desc = VectorDescriptor{ .size = 4, .data_type = .float32 };
    const activation = Activation{ .function = .rectified_linear };

    const f = try createVectorActivationLayer(&in_desc, &out_desc, &activation, null);
    defer destroy(f);

    var out: [4]f32 = @splat(-99);
    try apply(f, &[_]f32{ -1, 2, -3, 4 }, &out);
    try expectClose(&.{ 0, 2, 0, 4 }, &out);
}

test "a creator returns BnnsAllocationFailed rather than a null handle" {
    // The shapes contradict each other: a 2x2 window cannot come out of a 1x1
    // input. BNNS reports that by returning NULL, which the wrapper turns into
    // an error, so no caller can accidentally hold a null Filter.
    var params = LayerParametersPooling{
        .i_desc = desc(f32, .image_chw, &.{ 1, 1, 1 }, null),
        .o_desc = desc(f32, .image_chw, &.{ 4, 4, 1 }, null),
        .bias = desc(f32, .vector, &.{1}, null),
        .activation = .{ .function = .identity },
        .pooling_function = .max,
        .k_width = 2,
        .k_height = 2,
        .x_stride = 1,
        .y_stride = 1,
    };

    try testing.expectError(Error.BnnsAllocationFailed, createLayerPooling(&params, null));
}
