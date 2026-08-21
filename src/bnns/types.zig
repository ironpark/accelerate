//! Types shared by the BNNS bindings.
//!
//! BNNS has two generations of API. The first, introduced in macOS 10.12, built
//! a network out of individual layer "filters" (`BNNSFilterCreateLayer*` /
//! `BNNSFilterApply*`). Apple deprecated that whole surface in macOS 15.0. The
//! second, `bnns_graph.h`, compiles a whole model — a `.mlmodelc` produced by
//! Core ML Tools — into a `bnns_graph_t` and executes it. This package binds the
//! second, plus the standalone utilities in `bnns.h` that were not deprecated
//! along with the filter API.
//!
//! Everything here is plain C with manual lifetimes: BNNS hands back structs
//! holding a pointer and a size, and the caller is responsible for the matching
//! destroy call.

const std = @import("std");

/// The maximum rank BNNS will accept. `BNNS_MAX_TENSOR_DIMENSION` in
/// bnns_structures.h.
pub const max_tensor_dimension = 8;

// ============================================================================
// Data types
// ============================================================================

/// `BNNSDataType` — the element type of a tensor.
///
/// The encoding is a class bit ORed with the width in bits, which is why the
/// values look irregular: `Float32` is `0x10000 | 32`, `Int8` is `0x20000 | 8`.
/// The sub-byte widths (Int1/2/4, UInt1/2/3/4/6) are real: BNNS packs those
/// into bytes.
pub const DataType = enum(u32) {
    // -- Floating point (0x10000) --
    float16 = 0x10000 | 16,
    float32 = 0x10000 | 32,
    /// Brain float: 8 exponent bits and 7 mantissa bits, so the same range as
    /// f32 at half the width. Not Zig's `f16`.
    bfloat16 = 0x10000 | 0x8000 | 16,

    // -- Signed integer (0x20000) --
    int1 = 0x20000 | 1,
    int2 = 0x20000 | 2,
    int4 = 0x20000 | 4,
    int8 = 0x20000 | 8,
    int16 = 0x20000 | 16,
    int32 = 0x20000 | 32,
    int64 = 0x20000 | 64,

    // -- Unsigned integer (0x40000) --
    uint1 = 0x40000 | 1,
    uint2 = 0x40000 | 2,
    uint3 = 0x40000 | 3,
    uint4 = 0x40000 | 4,
    uint6 = 0x40000 | 6,
    uint8 = 0x40000 | 8,
    uint16 = 0x40000 | 16,
    uint32 = 0x40000 | 32,
    uint64 = 0x40000 | 64,

    // -- Indexed, i.e. a lookup table (0x80000) --
    indexed1 = 0x80000 | 1,
    indexed2 = 0x80000 | 2,
    indexed4 = 0x80000 | 4,
    indexed8 = 0x80000 | 8,

    // -- Miscellaneous (0x100000) --
    boolean = 0x100000 | 8,

    _,

    /// Bit that marks the class of a data type.
    pub const float_bit: u32 = 0x10000;
    pub const int_bit: u32 = 0x20000;
    pub const uint_bit: u32 = 0x40000;
    pub const indexed_bit: u32 = 0x80000;
    pub const miscellaneous_bit: u32 = 0x100000;

    /// Width of one element in bits. Sub-byte types report their true width,
    /// so this is not always a multiple of 8.
    pub fn bits(self: DataType) u32 {
        return @intFromEnum(self) & 0xffff;
    }

    pub fn isFloat(self: DataType) bool {
        return @intFromEnum(self) & float_bit != 0;
    }

    pub fn isSigned(self: DataType) bool {
        return @intFromEnum(self) & int_bit != 0;
    }

    pub fn isUnsigned(self: DataType) bool {
        return @intFromEnum(self) & uint_bit != 0;
    }

    /// True when `data` holds indices into `table_data` rather than values.
    pub fn isIndexed(self: DataType) bool {
        return @intFromEnum(self) & indexed_bit != 0;
    }

    /// The `DataType` corresponding to a Zig scalar type, for the types that
    /// have an exact match. `f16` maps to `.float16`, not `.bfloat16`.
    pub fn of(comptime T: type) DataType {
        return switch (T) {
            f16 => .float16,
            f32 => .float32,
            i8 => .int8,
            i16 => .int16,
            i32 => .int32,
            i64 => .int64,
            u8 => .uint8,
            u16 => .uint16,
            u32 => .uint32,
            u64 => .uint64,
            bool => .boolean,
            else => @compileError("no BNNSDataType for " ++ @typeName(T)),
        };
    }
};

/// `BNNSDataLayout` — how a `NDArrayDescriptor`'s data is laid out, and
/// implicitly its rank.
///
/// The top nibbles encode the rank: `0x38001` is a rank-3 first-major layout.
/// `DataLayout.rank` asks BNNS itself rather than decoding this by hand.
pub const DataLayout = enum(u32) {
    vector = 0x10000,
    @"1d_last_major" = 0x18000,
    @"1d_first_major" = 0x18001,

    row_major_matrix = 0x20000,
    column_major_matrix = 0x20001,
    @"2d_last_major" = 0x28000,
    @"2d_first_major" = 0x28001,
    fully_connected_sparse = 0x21001,

    image_chw = 0x30000,
    sne = 0x30001,
    nse = 0x30002,
    mha_dhk = 0x30003,
    @"3d_last_major" = 0x38000,
    @"3d_first_major" = 0x38001,

    convolution_weights_oihw = 0x40000,
    convolution_weights_oihrwr = 0x40001,
    convolution_weights_iohrwr = 0x40002,
    convolution_weights_oihw_pack32 = 0x40010,
    @"4d_last_major" = 0x48000,
    @"4d_first_major" = 0x48001,

    @"5d_last_major" = 0x58000,
    @"5d_first_major" = 0x58001,
    @"6d_last_major" = 0x68000,
    @"6d_first_major" = 0x68001,
    @"7d_last_major" = 0x78000,
    @"7d_first_major" = 0x78001,
    @"8d_last_major" = 0x88000,
    @"8d_first_major" = 0x88001,

    _,

    /// The generic first-major (row-major, C order) layout of the given rank.
    /// Rank 0 is not representable; rank 1 maps to `.@"1d_first_major"`.
    pub fn firstMajor(comptime rank: usize) DataLayout {
        return switch (rank) {
            1 => .@"1d_first_major",
            2 => .@"2d_first_major",
            3 => .@"3d_first_major",
            4 => .@"4d_first_major",
            5 => .@"5d_first_major",
            6 => .@"6d_first_major",
            7 => .@"7d_first_major",
            8 => .@"8d_first_major",
            else => @compileError("BNNS supports rank 1..8"),
        };
    }

    /// The generic last-major (column-major, Fortran order) layout of the
    /// given rank.
    pub fn lastMajor(comptime rank: usize) DataLayout {
        return switch (rank) {
            1 => .@"1d_last_major",
            2 => .@"2d_last_major",
            3 => .@"3d_last_major",
            4 => .@"4d_last_major",
            5 => .@"5d_last_major",
            6 => .@"6d_last_major",
            7 => .@"7d_last_major",
            8 => .@"8d_last_major",
            else => @compileError("BNNS supports rank 1..8"),
        };
    }
};

/// `BNNSNDArrayFlags` — controls backpropagation accumulation. Only meaningful
/// for training, which this package does not otherwise bind.
pub const NDArrayFlags = enum(u32) {
    backprop_set = 0,
    backprop_accumulate = 1,
    _,
};

/// `BNNSReduceFunction` — the operation `directApplyReduction` performs along
/// the reduced axis.
pub const ReduceFunction = enum(u32) {
    max = 0,
    min = 1,
    arg_max = 2,
    arg_min = 3,
    mean = 4,
    mean_non_zero = 5,
    sum = 6,
    sum_square = 7,
    sum_log = 8,
    l1_norm = 9,
    logical_or = 10,
    logical_and = 11,
    l2_norm = 12,
    log_sum_exp = 13,
    product = 14,
    none = 15,
    log_sum = 16,
    _,

    /// `BNNSReduceFunctionAny` is an alias for `logical_or`.
    pub const any: ReduceFunction = .logical_or;
    /// `BNNSReduceFunctionAll` is an alias for `logical_and`.
    pub const all: ReduceFunction = .logical_and;
};

/// `BNNSRandomGeneratorMethod` — the only method BNNS exposes is a counter-mode
/// AES stream.
pub const RandomGeneratorMethod = enum(u32) {
    aes_ctr = 0,
    _,
};

// ============================================================================
// Callbacks and common parameters
// ============================================================================

/// `BNNSAlloc` — a posix_memalign-shaped allocator. Returns 0 on success.
pub const Alloc = ?*const fn (memptr: ?*?*anyopaque, alignment: usize, size: usize) callconv(.c) c_int;

/// `BNNSFree` — the matching deallocator.
pub const Free = ?*const fn (ptr: ?*anyopaque) callconv(.c) void;

/// `BNNSFilterParameters` — thread count and allocator hooks, accepted by most
/// of the standalone `bnns.h` entry points. Passing null uses BNNS's defaults:
/// as many threads as the machine warrants, and posix_memalign/free.
pub const FilterParameters = extern struct {
    /// A logical OR of `BNNSFlags` values. Zero is the default.
    flags: u32 = 0,
    /// 0 means "pick the best number for this machine".
    n_threads: usize = 0,
    alloc_memory: Alloc = null,
    free_memory: Free = null,
};

// ============================================================================
// Tensors
// ============================================================================

/// `BNNSNDArrayDescriptor` — the original, fully general array descriptor.
///
/// `size` and `stride` are both fixed-length arrays of 8; only the first
/// `layout.rank()` entries are read. A `stride` of 0 means "contiguous in this
/// axis", which is *not* how `Tensor` reads a zero stride.
pub const NDArrayDescriptor = extern struct {
    flags: NDArrayFlags = .backprop_set,
    layout: DataLayout,

    size: [max_tensor_dimension]usize = @splat(0),
    stride: [max_tensor_dimension]usize = @splat(0),

    data: ?*anyopaque = null,
    data_type: DataType,

    /// Lookup table, read only when `data_type` is one of the `indexed*` types.
    table_data: ?*anyopaque = null,
    table_data_type: DataType = .float32,

    /// Applied when converting integer `data` to float. A stored 0.0 is treated
    /// as 1.0 during computation.
    data_scale: f32 = 0,
    data_bias: f32 = 0,
};

/// `BNNSTensor` — the simpler descriptor the graph API uses.
///
/// Differences from `NDArrayDescriptor` that bite:
/// * `rank` is explicit rather than implied by a layout.
/// * `shape` and `stride` are *signed*. A negative entry means "dynamic,
///   unspecified".
/// * A `stride` of 0 is a literal 0, not a request for contiguous packing.
///   Use `fillContiguousStrides` to get first-major strides.
/// * `data_size_in_bytes` is used for bounds checking, so it must be right.
pub const Tensor = extern struct {
    data_type: DataType,

    rank: u8 = 0,
    shape: [max_tensor_dimension]isize = @splat(0),
    stride: [max_tensor_dimension]isize = @splat(0),

    data: ?*anyopaque = null,
    data_size_in_bytes: usize = 0,

    /// Never read by BNNS; it sets this on tensors it returns, as a debugging
    /// aid. Points into the compiled graph, so it lives as long as the graph.
    name: ?[*:0]const u8 = null,

    /// Fill `stride` with first-major (C order) strides derived from `shape`.
    ///
    /// BNNS routines expect `stride[d] >= stride[d+1]` unless documented
    /// otherwise, and BNNS does not infer strides from a zero the way
    /// `NDArrayDescriptor` does.
    pub fn fillContiguousStrides(self: *Tensor) void {
        var acc: isize = 1;
        var d: usize = self.rank;
        while (d > 0) {
            d -= 1;
            self.stride[d] = acc;
            acc *= self.shape[d];
        }
    }

    /// A rank-N first-major tensor over `data`, with contiguous strides and
    /// `data_size_in_bytes` set from the slice.
    ///
    /// `shape` must multiply out to `data.len`; that is asserted, because
    /// getting it wrong hands BNNS a bounds-check value that disagrees with the
    /// shape and the failure surfaces much later.
    pub fn init(comptime T: type, data: []T, shape: []const usize) Tensor {
        std.debug.assert(shape.len >= 1 and shape.len <= max_tensor_dimension);
        var count: usize = 1;
        for (shape) |s| count *= s;
        std.debug.assert(count == data.len);

        var t = Tensor{
            .data_type = DataType.of(T),
            .rank = @intCast(shape.len),
            .data = @ptrCast(data.ptr),
            .data_size_in_bytes = data.len * @sizeOf(T),
        };
        for (shape, 0..) |s, i| t.shape[i] = @intCast(s);
        t.fillContiguousStrides();
        return t;
    }
};

// ============================================================================
// Layer-filter API enums (bnns_constants.h)
// ============================================================================
//
// Everything below belongs to the original `BNNSFilterCreateLayer*` surface,
// which Apple deprecated in macOS 15.0 in favour of the Graph API. The enums
// themselves are not marked deprecated in the header — only the entry points
// that consume them are — so they are declared here without a deprecation note
// unless the header attaches one to a specific member.
//
// Every one is `BNNS_ENUM(name, uint32_t, ...)`, i.e. a `uint32_t`-backed C
// enum, so each is `enum(u32)` with a `_` so that a value BNNS invents in a
// later release still round-trips instead of trapping.

/// `BNNSPoolingFunction` — the reduction a pooling layer applies over its
/// window.
pub const PoolingFunction = enum(u32) {
    /// Maximum over the window.
    max = 0,
    /// Mean over the window, with padded positions counted in the divisor.
    average_count_include_padding = 1,
    /// Mean over the window, with padded positions left out of the divisor.
    average_count_exclude_padding = 2,
    /// Un-pooling: scatters each value back to the argmax position recorded by
    /// a matching max pooling.
    un_max = 3,
    /// sqrt(sum of squares) over the window.
    l2_norm = 4,
    _,

    /// `BNNSPoolingFunctionAverage` is an alias for
    /// `average_count_include_padding`.
    ///
    /// Deprecated in macOS 11.0 with replacement
    /// `BNNSPoolingFunctionAverageCountIncludePadding`.
    pub const average: PoolingFunction = .average_count_include_padding;
};

/// `BNNSActivationFunction` — the pointwise nonlinearity applied at the end of
/// a layer, or by a standalone activation layer.
///
/// Several members read `alpha` and `beta` from the activation's parameter
/// struct; the header spells out each formula. Pointers to those two scalars
/// are what `BNNSGetPointer` hands back for `PointerSpecifier`.
pub const ActivationFunction = enum(u32) {
    /// x
    identity = 0,
    /// max(0, x)
    rectified_linear = 1,
    /// alpha*x if x<0, else x
    leaky_rectified_linear = 2,
    sigmoid = 3,
    tanh = 4,
    /// alpha*tanh(beta*x)
    scaled_tanh = 5,
    abs = 6,
    /// alpha*x
    linear = 7,
    /// min(max(x, alpha), beta)
    clamp = 8,
    /// Saturate((iscale*x + ioffset) >> ishift), an arithmetic shift.
    integer_linear_saturate = 9,
    /// As `integer_linear_saturate`, with per-channel scale/offset/shift.
    integer_linear_saturate_per_channel = 10,
    softmax = 11,
    /// 0.5*x*(1 + tanh(alpha*(x + beta*x^3)))
    gelu_approximation = 12,
    gumbel = 13,
    gumbel_max = 14,
    /// max(0, min(1, alpha*x + beta))
    hard_sigmoid = 15,
    /// alpha*log(1 + exp(beta*x))
    softplus = 16,
    /// x / (1 + |x|)
    softsign = 17,
    /// alpha*(exp(x) - 1) if x<0, else x
    elu = 18,
    /// min(alpha*x, beta) if x<0, else min(x, beta)
    clamped_leaky_rectified_linear = 19,
    /// alpha*x + beta
    linear_with_bias = 20,
    log_softmax = 21,
    log_sigmoid = 22,
    selu = 23,
    /// alpha*(exp(x/alpha) - 1) if x<0, else x
    celu = 24,
    /// 0 if |x| < |alpha|, else x
    hard_shrink = 25,
    /// 0 if |x| < |alpha|, else x - copysign(alpha, x)
    soft_shrink = 26,
    /// x - tanh(x)
    tanh_shrink = 27,
    /// beta if x <= alpha, else x
    threshold = 28,
    /// Leaky ReLU with one alpha per channel. Only valid with
    /// `DataLayout.image_chw`.
    prelu_per_channel = 29,
    /// x*(relu6(x + 3)/6)
    gelu_approximation2 = 30,
    /// x*sigmoid(x)
    silu = 31,
    /// min(max(0, x), 6)
    relu6 = 32,
    erf = 33,
    /// 0.5*x*(1 + erf(x/sqrt(2)))
    gelu = 34,
    /// x*sigmoid(1.702*x)
    gelu_approximation_sigmoid = 35,
    _,

    /// `BNNSActivationFunctionHardSwish` is an alias for
    /// `gelu_approximation2`: both are x*(relu6(x + 3)/6).
    pub const hard_swish: ActivationFunction = .gelu_approximation2;
};

/// `BNNSFlags` — filter creation flags, stored in `FilterParameters.flags`.
///
/// This is a bitmask, not a set of exclusive values: OR the members together
/// and pass the result as a `u32`.
pub const Flags = enum(u32) {
    /// Work directly from the client's `weights`/`bias` pointers instead of
    /// copying them. The client must then keep that memory alive for the whole
    /// lifetime of the filter.
    use_client_ptr = 0x0001,
    _,
};

/// `BNNSLossFunction` — the loss a loss layer computes between logits and
/// labels, before `LossReductionFunction` collapses it.
pub const LossFunction = enum(u32) {
    /// Softmax over the logits, then cross entropy against one-hot labels.
    softmax_cross_entropy = 1,
    /// Sigmoid per class, then cross entropy per class independently.
    sigmoid_cross_entropy = 2,
    mean_square_error = 3,
    /// Quadratic within `delta` of zero error, linear beyond it.
    huber = 4,
    /// The YOLO object-detection hybrid: MSE on x/y, Huber on w/h, sigmoid
    /// cross entropy on confidence, softmax cross entropy on class.
    yolo = 5,
    log = 6,
    /// 1 - sum(weight * label * prediction). Both sides should be unit-norm.
    cosine_distance = 7,
    /// max(0, 1 - t*logit) with t = 2*label - 1.
    hinge = 8,
    mean_absolute_error = 9,
    categorical_cross_entropy = 10,
    _,
};

/// `BNNSLossReductionFunction` — how a loss layer collapses the per-sample
/// losses of a batch.
pub const LossReductionFunction = enum(u32) {
    /// No reduction: the output is the same size as the input.
    none = 0,
    sum = 1,
    /// Sum, divided by the sum of the weights. Zero if that sum is zero.
    weighted_mean = 2,
    /// Sum, divided by the number of samples.
    mean = 3,
    /// Sum, divided by the number of nonzero weights. Zero if all are zero.
    non_zero_weight_mean = 4,
    _,
};

/// `BNNSArithmeticFunction` — the operation an arithmetic layer performs.
///
/// Binary members take a `BNNSArithmeticBinary` field struct, unary ones a
/// `BNNSArithmeticUnary`; `multiply_add` and `select` are ternary.
pub const ArithmeticFunction = enum(u32) {
    add = 0,
    subtract = 1,
    multiply = 2,
    divide = 3,
    square_root = 4,
    reciprocal_square_root = 5,
    ceil = 6,
    floor = 7,
    round = 8,
    sin = 9,
    cos = 10,
    tan = 11,
    asin = 12,
    acos = 13,
    atan = 14,
    sinh = 15,
    cosh = 16,
    tanh = 17,
    asinh = 18,
    acosh = 19,
    atanh = 20,
    pow = 21,
    exp = 22,
    exp2 = 23,
    log = 24,
    log2 = 25,
    /// Multiply, but 0 * NaN is 0 rather than NaN.
    multiply_no_nan = 26,
    /// Divide, but x/0 is 0 rather than NaN or infinity.
    divide_no_nan = 27,
    multiply_add = 28,
    minimum = 29,
    maximum = 30,
    /// Elementwise ternary select on a boolean input.
    select = 31,
    abs = 32,
    sign = 33,
    negate = 34,
    reciprocal = 35,
    square = 36,
    floor_divide = 37,
    trunc_divide = 38,
    trunc_remainder = 39,
    erf = 40,
    _,
};

/// `BNNSDescriptorType` — what role an `NDArrayDescriptor` plays in a training
/// layer, which decides how it is batched and whether it gets a gradient.
pub const DescriptorType = enum(u32) {
    /// No gradient. Broadcast across batch samples.
    constant = 0,
    /// An input or output. One gradient per sample in the batch.
    sample = 1,
    /// A trainable parameter such as weights or bias: broadcast across the
    /// batch, with its gradient summed over the batch.
    parameter = 2,
    _,
};

/// `BNNSOptimizerFunction` — the parameter-update rule an optimizer step
/// applies. The `*_with_clipping` variants first clip the gradient according to
/// an `OptimizerClippingFunction`.
pub const OptimizerFunction = enum(u32) {
    sgd_momentum = 1,
    adam = 2,
    rms_prop = 3,
    adam_w = 4,
    /// AMSGrad variant of Adam.
    adam_ams_grad = 5,
    /// AMSGrad variant of AdamW.
    adam_w_ams_grad = 6,
    sgd_momentum_with_clipping = 7,
    adam_with_clipping = 8,
    rms_prop_with_clipping = 9,
    adam_w_with_clipping = 10,
    adam_ams_grad_with_clipping = 11,
    adam_w_ams_grad_with_clipping = 12,
    _,
};

/// `BNNSOptimizerRegularizationFunction` — the weight penalty an optimizer adds
/// to the gradient.
pub const OptimizerRegularizationFunction = enum(u32) {
    none = 0,
    l1 = 1,
    l2 = 2,
    _,
};

/// `BNNSOptimizerSGDMomentumVariant` — which of the three algebraically
/// distinct SGD-with-momentum update formulas to use. The header spells each
/// one out; they differ in where the learning rate multiplies in, so they are
/// not interchangeable.
pub const OptimizerSGDMomentumVariant = enum(u32) {
    /// `BNNSSGDMomentumVariant0`: V = m*V - g*lr; W += V.
    variant0 = 0,
    /// `BNNSSGDMomentumVariant1`: V = m*V + g; W -= V*lr.
    variant1 = 1,
    /// `BNNSSGDMomentumVariant2`: V = m*V + lr*g; W -= V.
    variant2 = 2,
    _,
};

/// `BNNSOptimizerClippingFunction` — how an optimizer clips gradients before
/// applying them.
pub const OptimizerClippingFunction = enum(u32) {
    none = 0,
    /// Clamp each value into [min, max].
    by_value = 1,
    /// Scale down to a maximum L2 norm, per tensor.
    by_norm = 2,
    /// Scale by the ratio of the given L2 norm to the global L2 norm across all
    /// gradients.
    by_global_norm = 3,
    _,
};

/// `BNNSNormType` — the norm used where a routine takes one. BNNS only defines
/// L2.
pub const NormType = enum(u32) {
    l2_norm = 1,
    _,
};

/// `BNNSFilterType` — identifies which layer a filter is, used where a call
/// takes a generic filter and needs to know how to interpret its parameters.
pub const FilterType = enum(u32) {
    convolution = 0,
    fully_connected = 1,
    batch_norm = 2,
    instance_norm = 3,
    layer_norm = 4,
    group_norm = 5,
    transposed_convolution = 6,
    quantization = 7,
    arithmetic = 8,
    _,
};

/// `BNNSLayerFlags` — per-layer behaviour flags. Currently only LSTM uses them.
///
/// This is a bitmask, not a set of exclusive values: OR the members together
/// and pass the result as a `u32`.
pub const LayerFlags = enum(u32) {
    /// Run the LSTM in both directions.
    lstm_bidirectional = 0x0001,
    /// Ignore the activation fields of the gate layers and the hidden
    /// activation, and use the defaults documented for
    /// `BNNSLayerParametersLSTM`.
    lstm_default_activations = 0x0002,
    _,
};

/// `BNNSInterpolationMethod` — how a resize layer samples its input.
pub const InterpolationMethod = enum(u32) {
    /// Nearest neighbour; works for any number of resized dimensions.
    nearest = 0,
    /// Linear or bilinear. Requires at most two resized dimensions.
    linear = 1,
    _,
};

/// `BNNSLinearSamplingMode` — where a linear resize places its sample points
/// relative to the input grid.
///
/// With input extent `Xin` and output extent `Xout`, these differ only in the
/// spacing and offset of `grid_point[i]`; the header gives the exact formulas.
pub const LinearSamplingMode = enum(u32) {
    /// spacing = (Xin - Xin/Xout) / (Xout - 1).
    default = 0,
    /// Like `strict_align_corners`, except that for Xout == 1 the single sample
    /// lands at (Xin - 1)/2.
    align_corners = 1,
    /// spacing = Xin/Xout, offset by half a sample.
    unalign_corners = 2,
    /// spacing = (Xin - 1) / (Xout - 1).
    strict_align_corners = 3,
    /// delta = max(1, Xin - 1)/Xout, sampled from half a delta in.
    offset_corners = 4,
    _,
};

/// `BNNSBoxCoordinateMode` — the convention for the four numbers describing a
/// 2D bounding box.
pub const BoxCoordinateMode = enum(u32) {
    /// [h_start, w_start, h_end, w_end]
    corners_height_first = 0,
    /// [w_start, h_start, w_end, h_end]
    corners_width_first = 1,
    /// [h_center, w_center, box_height, box_width]
    center_size_height_first = 2,
    /// [w_center, h_center, box_width, box_height]
    center_size_width_first = 3,
    _,
};

/// `BNNSPaddingMode` — how a padding layer fills the region it adds.
pub const PaddingMode = enum(u32) {
    /// Fill with a caller-supplied constant.
    constant = 0,
    /// Odd-symmetric about the edge element: `x x A B C` -> `C B A B C`.
    reflect = 1,
    /// Even-symmetric about the edge: `x x A B` -> `B A A B`.
    symmetric = 2,
    _,
};

/// `BNNSRelationalOperator` — the elementwise comparison or logical operation a
/// relational layer performs. The logical members take boolean inputs.
pub const RelationalOperator = enum(u32) {
    equal = 0,
    less = 1,
    less_equal = 2,
    greater = 3,
    greater_equal = 4,
    not_equal = 5,
    logical_and = 6,
    logical_or = 7,
    /// Unary: !A.
    logical_not = 8,
    logical_nand = 9,
    logical_nor = 10,
    logical_xor = 11,
    _,
};

/// `BNNSPointerSpecifier` — which of a layer's internal scalars
/// `BNNSGetPointer` should hand back. Both are supported by activation layers.
pub const PointerSpecifier = enum(u32) {
    alpha = 0,
    beta = 1,
    _,
};

/// `BNNSEmbeddingFlags` — behaviour flags for embedding layers.
///
/// This is a bitmask, not a set of exclusive values: OR the members together
/// and pass the result as a `u32`.
pub const EmbeddingFlags = enum(u32) {
    /// `BNNSEmbeddingFlagScaleGradientByFrequency`: scale backward-pass
    /// gradients by how often the corresponding index occurred in the input.
    scale_gradient_by_frequency = 1,
    _,
};

/// `BNNSQuantizerFunction` — the direction a quantization layer converts in.
pub const QuantizerFunction = enum(u32) {
    /// y = scale*x + bias
    quantize = 0,
    /// y = (x - bias)/scale
    dequantize = 1,
    _,
};

/// `BNNSSparsityType` — the sparsity pattern of a sparse weight tensor.
pub const SparsityType = enum(u32) {
    /// No special structure to the nonzeros.
    unstructured = 0x0,
    _,
};

/// `BNNSTargetSystem` — the device class to optimize a data layout for, passed
/// to the `BNNSGetBestDataLayout*` queries. Optimal packing differs across
/// Apple silicon generations, so these queries exist rather than a fixed rule.
pub const TargetSystem = enum(u32) {
    /// One layout that is supported and reasonably fast on most devices.
    generic = 0,
    _,
};

/// `BNNSShuffleType` — the rearrangement `BNNSShuffle` performs. All four are
/// NCHW-only, and `r`/`b` is the block factor.
pub const ShuffleType = enum(u32) {
    /// (N, C*r*r, H, W) -> (N, C, H*r, W*r); depth-to-space in "CRD" order.
    pixel_shuffle_nchw = 0,
    /// The inverse: (N, C, H*r, W*r) -> (N, C*r*r, H, W).
    pixel_unshuffle_nchw = 1,
    /// (N, C*b*b, H, W) -> (N, C, H*b, W*b), but ordering the elements
    /// differently from `pixel_shuffle_nchw` when C > 1.
    depth_to_space_nchw = 2,
    /// The inverse of `depth_to_space_nchw`.
    space_to_depth_nchw = 3,
    _,
};

// ============================================================================
// Activation
// ============================================================================

/// `BNNSActivation` — the activation applied at the end of a layer, plus the
/// fixed-point rescaling parameters used when the layer works in integers.
///
/// `alpha` and `beta` are the function's parameters; which of them are read
/// depends on `function` (e.g. `.leaky_relu` reads `alpha` only, `.clamp` reads
/// both as the bounds).
///
/// The integer fields implement `y = (x * iscale) >> ishift) + ioffset`-style
/// requantization and are ignored for floating-point data. The `*_per_channel`
/// pointers, when non-null, supersede the corresponding scalar and must have one
/// entry per output channel.
pub const Activation = extern struct {
    function: ActivationFunction = .identity,
    alpha: f32 = 0,
    beta: f32 = 0,

    // The fields below arrived in macOS 10.13 and apply to integer data only.
    iscale: i32 = 0,
    ioffset: i32 = 0,
    ishift: i32 = 0,

    iscale_per_channel: ?[*]const i32 = null,
    ioffset_per_channel: ?[*]const i32 = null,
    ishift_per_channel: ?[*]const i32 = null,
};

// ============================================================================
// LSTM sub-layer descriptors
// ============================================================================

/// `BNNSLSTMGateDescriptor` — the weights, bias and activation of one LSTM gate.
///
/// Each gate computes `activation(b + Wi*input + Wh*hidden + Wc*cell)`. Weights
/// are stored `[num_layers][num_directions][hidden_size][*]`, and `b_desc` is
/// `[num_layers][num_directions][hidden_size]`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LSTMGateDescriptor = extern struct {
    /// Input weights. This is an array of two because when `num_layers > 1` and
    /// `input_size != hidden_size` the first layer's input weights have a
    /// different shape from the rest, so both are supplied.
    iw_desc: [2]NDArrayDescriptor,
    /// Hidden weights, `[..][hidden_size][hidden_size]`.
    hw_desc: NDArrayDescriptor,
    /// Cell weights, `[..][hidden_size][hidden_size]` (peephole connections).
    cw_desc: NDArrayDescriptor,
    /// Bias, `[..][hidden_size]`.
    b_desc: NDArrayDescriptor,
    activation: Activation,
};

/// `BNNSLSTMDataDescriptor` — the three tensors that make up one side (input or
/// output) of an LSTM layer.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LSTMDataDescriptor = extern struct {
    /// The sequence data itself.
    data_desc: NDArrayDescriptor,
    /// Hidden state.
    hidden_desc: NDArrayDescriptor,
    /// Cell state.
    cell_state_desc: NDArrayDescriptor,
};

// ============================================================================
// Arithmetic operand blocks
// ============================================================================

/// `BNNSArithmeticUnary` — one input and one output, for the arithmetic layer
/// functions that take a single operand.
///
/// The header declares one of these per arity rather than a union; the layer
/// parameters point at whichever one matches the `ArithmeticFunction` selected.
/// Each `*_type` says whether the matching descriptor is a constant, a sample
/// (i.e. varies per apply) or a trainable parameter.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const ArithmeticUnary = extern struct {
    in: NDArrayDescriptor,
    in_type: DescriptorType,
    out: NDArrayDescriptor,
    out_type: DescriptorType,
};

/// `BNNSArithmeticBinary` — two inputs and one output.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const ArithmeticBinary = extern struct {
    in1: NDArrayDescriptor,
    in1_type: DescriptorType,
    in2: NDArrayDescriptor,
    in2_type: DescriptorType,
    out: NDArrayDescriptor,
    out_type: DescriptorType,
};

/// `BNNSArithmeticTernary` — three inputs and one output.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const ArithmeticTernary = extern struct {
    in1: NDArrayDescriptor,
    in1_type: DescriptorType,
    in2: NDArrayDescriptor,
    in2_type: DescriptorType,
    in3: NDArrayDescriptor,
    in3_type: DescriptorType,
    out: NDArrayDescriptor,
    out_type: DescriptorType,
};

// ============================================================================
// Multihead attention
// ============================================================================

/// `BNNSMHAProjectionParameters` — one projection of a multihead attention
/// layer. Query, key, value and the output each get their own copy.
///
/// The backpropagation entry point reuses this struct to hold the partial
/// differentials rather than the values.
pub const MHAProjectionParameters = extern struct {
    /// The input (query/key/value) or output this projection applies to.
    target_desc: NDArrayDescriptor,
    /// The projection matrix, e.g. Wᴷ.
    weights: NDArrayDescriptor,
    /// The projection bias, e.g. pᴷ. Set `bias.data = null` for no bias.
    bias: NDArrayDescriptor,
};

// ============================================================================
// Optimizer algorithm fields
// ============================================================================
//
// Each of these is pointed to by an optimizer layer's `optimizer_alg_fields`
// and is read afresh on every apply — BNNS does not cache it — so a schedule can
// mutate `learning_rate` between steps.

/// `BNNSOptimizerSGDMomentumFields` — parameters for
/// `OptimizerFunction.sgd_momentum`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const OptimizerSGDMomentumFields = extern struct {
    learning_rate: f32 = 0,
    /// Zero disables momentum entirely: the accumulator V is not computed and
    /// its scratch buffer may be null.
    momentum: f32 = 0,
    gradient_scale: f32 = 0,
    regularization_scale: f32 = 0,
    clip_gradients: bool = false,
    /// Ignored unless `clip_gradients` is set.
    clip_gradients_min: f32 = 0,
    /// Ignored unless `clip_gradients` is set.
    clip_gradients_max: f32 = 0,
    nesterov: bool = false,
    regularization_func: OptimizerRegularizationFunction,
    /// Which of the three momentum update formulas to use.
    sgd_momentum_variant: OptimizerSGDMomentumVariant,
};

/// `BNNSOptimizerSGDMomentumWithClippingFields` — parameters for
/// `OptimizerFunction.sgd_momentum_with_clipping`. Same algorithm as
/// `OptimizerSGDMomentumFields`, with the boolean clip flag replaced by a
/// clipping function and its norms.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const OptimizerSGDMomentumWithClippingFields = extern struct {
    learning_rate: f32 = 0,
    /// Zero gives vanilla SGD, as above.
    momentum: f32 = 0,
    gradient_scale: f32 = 0,
    regularization_scale: f32 = 0,
    nesterov: bool = false,
    regularization_func: OptimizerRegularizationFunction,
    sgd_momentum_variant: OptimizerSGDMomentumVariant,
    clipping_func: OptimizerClippingFunction,
    /// Used by clip-by-value.
    clip_gradients_min: f32 = 0,
    /// Used by clip-by-value.
    clip_gradients_max: f32 = 0,
    /// Max L2 norm, used by clip-by-norm and clip-by-global-norm.
    clip_gradients_max_norm: f32 = 0,
    /// A precomputed global L2 norm for clip-by-global-norm. Zero means "compute
    /// it from the gradient tensors".
    clip_gradients_use_norm: f32 = 0,
};

/// `BNNSOptimizerAdamFields` — parameters shared by Adam, AdamW and their
/// AMSGrad variants.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const OptimizerAdamFields = extern struct {
    learning_rate: f32 = 0,
    /// First moment decay, in [0,1).
    beta1: f32 = 0,
    /// Second moment decay, in [0,1).
    beta2: f32 = 0,
    /// Maintained by the caller, because one step optimizes many layers. Starts
    /// at 1 and is incremented once the whole network has been updated.
    time_step: f32 = 1,
    /// This is the paper's epsilon-hat, i.e.
    /// `epsilon * sqrt(1 - beta2 ** time_step)`.
    epsilon: f32 = 0,
    gradient_scale: f32 = 0,
    /// Regularization scale for Adam; the decoupled weight decay for AdamW.
    regularization_scale: f32 = 0,
    clip_gradients: bool = false,
    clip_gradients_min: f32 = 0,
    clip_gradients_max: f32 = 0,
    /// Used by Adam, ignored by AdamW.
    regularization_func: OptimizerRegularizationFunction,
};

/// `BNNSOptimizerAdamWithClippingFields` — Adam/AdamW with a clipping function
/// in place of the boolean clip flag.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const OptimizerAdamWithClippingFields = extern struct {
    learning_rate: f32 = 0,
    beta1: f32 = 0,
    beta2: f32 = 0,
    /// Maintained by the caller; starts at 1.
    time_step: f32 = 1,
    /// Epsilon-hat, as in `OptimizerAdamFields`.
    epsilon: f32 = 0,
    gradient_scale: f32 = 0,
    /// Regularization scale for Adam; decoupled weight decay for AdamW.
    regularization_scale: f32 = 0,
    /// Used by Adam, ignored by AdamW.
    regularization_func: OptimizerRegularizationFunction,
    clipping_func: OptimizerClippingFunction,
    /// Used by clip-by-value.
    clip_gradients_min: f32 = 0,
    /// Used by clip-by-value.
    clip_gradients_max: f32 = 0,
    /// Max L2 norm, used by clip-by-norm and clip-by-global-norm.
    clip_gradients_max_norm: f32 = 0,
    /// Precomputed global norm for clip-by-global-norm; zero means "compute it".
    clip_gradients_use_norm: f32 = 0,
};

/// `BNNSOptimizerRMSPropFields` — parameters for
/// `OptimizerFunction.rms_prop`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const OptimizerRMSPropFields = extern struct {
    learning_rate: f32 = 0,
    /// Smoothing constant on the squared-gradient accumulator.
    alpha: f32 = 0,
    /// Added to the denominator.
    epsilon: f32 = 0,
    /// Use the centered variant, which subtracts the squared mean gradient.
    centered: bool = false,
    /// Momentum decay rate; zero disables momentum.
    momentum: f32 = 0,
    gradient_scale: f32 = 0,
    regularization_scale: f32 = 0,
    clip_gradients: bool = false,
    clip_gradients_min: f32 = 0,
    clip_gradients_max: f32 = 0,
    regularization_func: OptimizerRegularizationFunction,
};

/// `BNNSOptimizerRMSPropWithClippingFields` — RMSProp with a clipping function
/// in place of the boolean clip flag.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const OptimizerRMSPropWithClippingFields = extern struct {
    learning_rate: f32 = 0,
    alpha: f32 = 0,
    epsilon: f32 = 0,
    centered: bool = false,
    /// Momentum decay rate; zero disables momentum.
    momentum: f32 = 0,
    gradient_scale: f32 = 0,
    regularization_scale: f32 = 0,
    regularization_func: OptimizerRegularizationFunction,
    clipping_func: OptimizerClippingFunction,
    /// Used by clip-by-value.
    clip_gradients_min: f32 = 0,
    /// Used by clip-by-value.
    clip_gradients_max: f32 = 0,
    /// Max L2 norm, used by clip-by-norm and clip-by-global-norm.
    clip_gradients_max_norm: f32 = 0,
    /// Precomputed global norm for clip-by-global-norm; zero means "compute it".
    clip_gradients_use_norm: f32 = 0,
};

// ============================================================================
// Sparsity
// ============================================================================

/// `BNNSSparsityParameters` — a hint to `ndArrayFullyConnectedSparsify`
/// describing the sparsity pattern to aim for. Introduced in macOS 13.0.
pub const SparsityParameters = extern struct {
    /// Reserved; must be zero.
    flags: u64 = 0,
    /// Numerator in `[0]`, denominator in `[1]`; the numerator must be smaller.
    /// For unstructured sparsity the ratio is simply `[0] / [1]`.
    sparsity_ratio: [2]u32 = @splat(0),
    sparsity_type: SparsityType,
    /// The SoC the resulting weights will be run on.
    target_system: TargetSystem,
};

// ============================================================================
// First-generation descriptors (deprecated in macOS 11.0)
// ============================================================================

/// `BNNSImageStackDescriptor` — a stack of same-sized single-channel images.
///
/// Pixel `P(c,x,y)` lives at `data[x + row_stride * y + image_stride * c]`, so
/// `row_stride >= width` and `image_stride >= row_stride * height`. Indexed data
/// types are not allowed here.
///
/// Note that the descriptor carries no data pointer: the first-generation
/// filters take the buffers as separate arguments to apply.
///
/// Deprecated in macOS 11.0 — BNNS moved to the Layer Parameters structs, and
/// `NDArrayDescriptor` replaces this. That successor API was in turn deprecated
/// in macOS 15.0 in favour of the Graph API (`bnns.Graph`).
pub const ImageStackDescriptor = extern struct {
    width: usize = 0,
    height: usize = 0,
    /// Number of images in the stack.
    channels: usize = 0,
    /// Increment in values, not bytes, between image rows.
    row_stride: usize = 0,
    /// Increment in values, not bytes, between channels.
    image_stride: usize = 0,

    data_type: DataType,
    /// `Y = data_scale * X + data_bias`, for the integer types only.
    data_scale: f32 = 0,
    data_bias: f32 = 0,
};

/// `BNNSVectorDescriptor` — a dense vector of `size` scalars. Indexed data types
/// are not allowed here.
///
/// Deprecated in macOS 11.0 — use `NDArrayDescriptor`. That successor API was in
/// turn deprecated in macOS 15.0 in favour of the Graph API (`bnns.Graph`).
pub const VectorDescriptor = extern struct {
    size: usize = 0,

    data_type: DataType,
    /// `Y = data_scale * X + data_bias`, for the integer types only.
    data_scale: f32 = 0,
    data_bias: f32 = 0,
};

/// `BNNSLayerData` — a tagged blob of layer constants: weights or bias.
///
/// The layout and element count of `data` are defined by the layer that holds
/// it, not by this struct — there is no shape here at all.
///
/// Which of the remaining fields matter depends on `data_type`:
/// * float types: none of them.
/// * `int*`/`uint*`: `data_scale` and `data_bias`, converting as
///   `Y = data_scale * X + data_bias`.
/// * `indexed*`: `data_table` only, which must point at exactly 256 floats
///   regardless of the index width.
///
/// Deprecated in macOS 11.0 — use `NDArrayDescriptor`. That successor API was in
/// turn deprecated in macOS 15.0 in favour of the Graph API (`bnns.Graph`).
pub const LayerData = extern struct {
    data: ?*const anyopaque = null,
    data_type: DataType,
    /// Integer types only; ignored for indexed and float types.
    data_scale: f32 = 0,
    /// Integer types only; ignored for indexed and float types.
    data_bias: f32 = 0,
    /// 256-entry conversion table; indexed types only.
    data_table: ?[*]const f32 = null,
};

/// `BNNSConvolutionLayerParameters` — the first-generation convolution
/// description.
///
/// `Output(o,x,y) = activation(bias(o) + sum over i,kx,ky of
/// Weight(o,i,kx,ky) * Input(i, x_stride*x + kx, y_stride*y + ky))`, with
/// weights stored at `weights[kx + k_width * (ky + k_height * (i + in_channels * o))]`.
///
/// Sizes must satisfy `in_width + 2 * x_padding == x_stride * (out_width - 1) + k_width`
/// and the same in y.
///
/// Deprecated in macOS 11.0 with replacement `BNNSLayerParametersConvolution`
/// (`LayerParametersConvolution`), which was itself deprecated in macOS 15.0 in
/// favour of the Graph API (`bnns.Graph`).
pub const ConvolutionLayerParameters = extern struct {
    /// X increment in the input image.
    x_stride: usize = 0,
    /// Y increment in the input image.
    y_stride: usize = 0,
    /// Virtual zeros added to the left and right of every input channel.
    x_padding: usize = 0,
    /// Virtual zeros added above and below every input channel.
    y_padding: usize = 0,
    k_width: usize = 0,
    k_height: usize = 0,
    in_channels: usize = 0,
    out_channels: usize = 0,

    /// `k_width * k_height * in_channels * out_channels` values.
    weights: LayerData,
    /// `out_channels` values, one per output channel.
    bias: LayerData,
    activation: Activation,
};

/// `BNNSFullyConnectedLayerParameters` — the first-generation fully connected
/// layer: `Output(o) = activation(bias(o) + sum over i of Weight(o,i) * Input(i))`,
/// with `Weight(o,i)` stored at `weights[i + o * in_size]`.
///
/// Deprecated in macOS 11.0 with replacement
/// `BNNSLayerParametersFullyConnected` (`LayerParametersFullyConnected`), which
/// was itself deprecated in macOS 15.0 in favour of the Graph API
/// (`bnns.Graph`).
pub const FullyConnectedLayerParameters = extern struct {
    in_size: usize = 0,
    out_size: usize = 0,

    /// `in_size * out_size` values.
    weights: LayerData,
    /// `out_size` values, one per output component.
    bias: LayerData,
    activation: Activation,
};

/// `BNNSPoolingLayerParameters` — the first-generation pooling layer:
/// `Output(o,x,y) = activation(bias(o) + PoolingFunction over the k_width by
/// k_height window at (x_stride*x, y_stride*y))`.
///
/// Sizes must satisfy `in_width + 2 * x_padding >= x_stride * (out_width - 1) + 1`
/// and the same in y.
///
/// Deprecated in macOS 11.0 with replacement `BNNSLayerParametersPooling`
/// (`LayerParametersPooling`), which was itself deprecated in macOS 15.0 in
/// favour of the Graph API (`bnns.Graph`).
pub const PoolingLayerParameters = extern struct {
    /// X increment in the input image.
    x_stride: usize = 0,
    /// Y increment in the input image.
    y_stride: usize = 0,
    /// Virtual zeros added to the left and right of every input channel.
    x_padding: usize = 0,
    /// Virtual zeros added above and below every input channel.
    y_padding: usize = 0,
    k_width: usize = 0,
    k_height: usize = 0,
    in_channels: usize = 0,
    out_channels: usize = 0,

    pooling_function: PoolingFunction,
    /// `out_channels` values.
    bias: LayerData,
    activation: Activation,
};

// ============================================================================
// Layer parameters (the deprecated filter API)
//
// Every `BNNSLayerParameters*` block below feeds one `BNNSFilterCreateLayer*`
// call. Apple deprecated the whole filter surface in macOS 15.0 in favour of
// the Graph API, but the layer objects remain the only option on deployment
// targets older than that.
//
// These are `extern struct` and their field order is load-bearing: BNNS reads
// them by offset. Descriptor fields (`NDArrayDescriptor`, `Activation`, ...)
// are embedded by value, not by pointer.
// ============================================================================

/// `BNNSLayerParametersConvolution` — a 2D convolution, optionally grouped,
/// dilated, strided and asymmetrically padded, with a fused bias and
/// activation: `Output(o,x,y) = activation(bias(o) + sum Weight * Input)`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersConvolution = extern struct {
    /// Input image stack.
    i_desc: NDArrayDescriptor,
    /// Weights, `Weight(o,i,kx,ky)`, in one of the `convolution_weights_*`
    /// layouts.
    w_desc: NDArrayDescriptor,
    /// Output image stack.
    o_desc: NDArrayDescriptor,

    /// One value per output channel. Set `bias.data = null` for no bias.
    bias: NDArrayDescriptor,
    activation: Activation,

    /// Width increment in the input image. A stored 0 is treated as 1.
    x_stride: usize = 0,
    /// Height increment in the input image. A stored 0 is treated as 1.
    y_stride: usize = 0,
    /// Kernel width increment. Ignored when <= 1.
    x_dilation_stride: usize = 0,
    /// Kernel height increment. Ignored when <= 1.
    y_dilation_stride: usize = 0,
    /// Virtual zero border added to the left and right of every channel.
    x_padding: usize = 0,
    /// Virtual zero border added to the top and bottom of every channel.
    y_padding: usize = 0,
    /// Convolution group size. Ignored when <= 1; otherwise both channel
    /// counts must be divisible by it.
    groups: usize = 0,
    /// Asymmetric padding, `{ left, right, up, down }`. Ignored when all zero
    /// or when either of `x_padding`/`y_padding` is nonzero.
    pad: [4]usize = @splat(0),
};

/// `BNNSLayerParametersFullyConnected` — a matrix-vector product with a fused
/// bias and activation: `Output(o) = activation(bias(o) + sum_i W(o,i) * In(i))`.
/// `Weight(o,i)` lives at `weights[i + o * in_size]`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersFullyConnected = extern struct {
    /// Input vector.
    i_desc: NDArrayDescriptor,
    /// Weight matrix, `in_size * out_size` values.
    w_desc: NDArrayDescriptor,
    /// Output vector.
    o_desc: NDArrayDescriptor,

    /// One value per output component. Set `bias.data = null` for no bias.
    bias: NDArrayDescriptor,
    activation: Activation,
};

/// `BNNSLayerParametersPooling` — max/average pooling over a `k_width` by
/// `k_height` window, with a fused bias and activation.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersPooling = extern struct {
    i_desc: NDArrayDescriptor,
    o_desc: NDArrayDescriptor,

    /// One value per output channel. Set `bias.data = null` for no bias.
    bias: NDArrayDescriptor,
    activation: Activation,

    /// The reduction applied to each window.
    pooling_function: PoolingFunction,

    k_width: usize,
    k_height: usize,
    /// Width increment in the input image. A stored 0 is treated as 1.
    x_stride: usize = 0,
    /// Height increment in the input image. A stored 0 is treated as 1.
    y_stride: usize = 0,
    /// Window width increment; no dilation when <= 1.
    x_dilation_stride: usize = 0,
    /// Window height increment; no dilation when <= 1.
    y_dilation_stride: usize = 0,
    x_padding: usize = 0,
    y_padding: usize = 0,
    /// Asymmetric padding, `{ left, right, up, down }`. Ignored when all zero
    /// or when either of `x_padding`/`y_padding` is nonzero.
    pad: [4]usize = @splat(0),
};

/// `BNNSLayerParametersActivation` — applies `activation` elementwise. With
/// `activation.function` set to identity and differing input/output data
/// types, this is instead a type conversion layer.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersActivation = extern struct {
    i_desc: NDArrayDescriptor,
    o_desc: NDArrayDescriptor,

    activation: Activation,
    /// Bitmask of the axes an axis-sensitive activation (softmax, log-softmax)
    /// runs along. 0 means the axis of `i_desc.size[0]`. The bit one past the
    /// layout's last dimension selects the batch axis: 2 for `.vector`, 8 for
    /// `.image_chw`.
    axis_flags: u32 = 0,
};

/// `BNNSLayerParametersLossBase` — the generic loss layer. The Softmax cross
/// entropy, sigmoid cross entropy, Huber and Yolo losses each have their own
/// struct below, whose leading fields are layout-compatible with this one.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersLossBase = extern struct {
    function: LossFunction,
    i_desc: NDArrayDescriptor,
    o_desc: NDArrayDescriptor,
    /// How the per-element losses are collapsed into the output.
    reduction: LossReductionFunction,
};

/// `BNNSLayerParametersLossSoftmaxCrossEntropy` — softmax cross entropy loss.
/// The first four fields are layout-compatible with `LayerParametersLossBase`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersLossSoftmaxCrossEntropy = extern struct {
    function: LossFunction,
    i_desc: NDArrayDescriptor,
    o_desc: NDArrayDescriptor,
    reduction: LossReductionFunction,

    /// Label smoothing over `n` labels:
    /// `smoothed[i] = labels[i] * (1 - label_smooth) + label_smooth / n`.
    /// 0 leaves the labels untouched.
    label_smooth: f32 = 0,
};

/// `BNNSLayerParametersLossSigmoidCrossEntropy` — sigmoid cross entropy loss.
/// The first four fields are layout-compatible with `LayerParametersLossBase`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersLossSigmoidCrossEntropy = extern struct {
    function: LossFunction,
    i_desc: NDArrayDescriptor,
    o_desc: NDArrayDescriptor,
    reduction: LossReductionFunction,

    /// Label smoothing over two labels:
    /// `smoothed[i] = labels[i] * (1 - label_smooth) + label_smooth / 2`.
    /// 0 leaves the labels untouched.
    label_smooth: f32 = 0,
};

/// `BNNSLayerParametersLossHuber` — Huber loss, quadratic below `huber_delta`
/// and linear above it. The first four fields are layout-compatible with
/// `LayerParametersLossBase`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersLossHuber = extern struct {
    function: LossFunction,
    i_desc: NDArrayDescriptor,
    o_desc: NDArrayDescriptor,
    reduction: LossReductionFunction,

    /// The quadratic/linear crossover point.
    huber_delta: f32,
};

/// `BNNSLayerParametersLossYolo` — the YOLO detection loss. Input and ground
/// truth are laid out as
/// `(batch)x(grid height)x(grid width)x(anchors)x(x,y,w,h,confidence,classes)`.
/// The first four fields are layout-compatible with `LayerParametersLossBase`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersLossYolo = extern struct {
    function: LossFunction,
    i_desc: NDArrayDescriptor,
    o_desc: NDArrayDescriptor,
    /// Must be the sum reduction for the Yolo loss.
    reduction: LossReductionFunction,

    /// Huber delta used for the w,h part of the loss. 0 is taken as 1.
    huber_delta: f32 = 0,
    number_of_grid_columns: usize,
    number_of_grid_rows: usize,
    number_of_anchor_boxes: usize,
    /// Must be `5 + number of classes`.
    anchor_box_size: usize,
    /// Rescore confidence from the prediction/ground-truth IOU.
    rescore: bool,
    scale_xy: f32,
    scale_wh: f32,
    scale_object: f32,
    scale_no_object: f32,
    scale_classification: f32,
    /// Minimum IOU for treating a box as an object.
    object_minimum_iou: f32,
    /// Maximum IOU for treating a box as no object.
    no_object_maximum_iou: f32,
    /// `w0,h0,w1,h1,...` — `2 * number_of_anchor_boxes` floats.
    anchors_data: ?[*]f32 = null,
};

/// `BNNSLayerParametersNormalization` — batch, instance, layer or group
/// normalization, selected by the `NormType` passed to the create call, with a
/// fused elementwise activation.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersNormalization = extern struct {
    i_desc: NDArrayDescriptor,
    o_desc: NDArrayDescriptor,
    /// Trainable shift. Ignored when `beta_desc.data` is null.
    beta_desc: NDArrayDescriptor,
    /// Trainable scale. Ignored when `gamma_desc.data` is null.
    gamma_desc: NDArrayDescriptor,
    /// Batch/instance norm only, and always f32 whatever the input type. A
    /// null `data` means the moving mean is neither tracked nor used.
    moving_mean_desc: NDArrayDescriptor,
    /// Batch/instance norm only, and always f32. A null `data` means the
    /// moving variance is neither tracked nor used.
    moving_variance_desc: NDArrayDescriptor,
    /// Moving-statistics update rate during training; must be in [0, 1].
    momentum: f32,
    /// Added under the root in `1/sqrt(variance + epsilon)`.
    epsilon: f32,
    /// Fused activation; elementwise functions only, no softmax.
    activation: Activation,
    /// Group norm only: the channel count must be divisible by this.
    num_groups: usize = 0,
    /// Layer norm only: first normalized axis. 0 normalizes over CHW, 1 over
    /// HW, 2 over W.
    normalization_axis: usize,
};

/// `BNNSLayerParametersDropout` — zeroes elements with probability `rate`
/// during training.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersDropout = extern struct {
    i_desc: NDArrayDescriptor,
    o_desc: NDArrayDescriptor,
    /// Probability an element (or a group of them) is dropped; in [0, 1).
    rate: f32,
    /// Random seed. Ignored when 0.
    seed: u32 = 0,
    /// Bitmask of the dimensions along which the keep/drop decision is shared.
    /// Only the low 4 bits are used.
    control: u8 = 0,
};

/// `BNNSLayerParametersLSTM` — a stack of LSTM cells, optionally bidirectional,
/// over a whole sequence.
///
/// `num_directions` is 2 when `lstm_flags` carries the bidirectional bit and 1
/// otherwise; the weight and state layouts in the gate descriptors are indexed
/// `[num_layers][num_directions][...]`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersLSTM = extern struct {
    input_size: usize,
    /// Element count of both the hidden state and the cell state.
    hidden_size: usize,
    batch_size: usize,
    /// Number of LSTM layers stacked on top of one another.
    num_layers: usize,
    /// Length of the sequential input.
    seq_len: usize,
    /// Dropout applied between stacked layers, never after the last one.
    /// Ignored when `num_layers == 1`.
    dropout: f32 = 0,
    /// A mask of `BNNSLayerFlags` LSTM bits: bidirectional (0x1) and
    /// default-activations (0x2).
    lstm_flags: u32 = 0,
    /// Optional 1D array of `seq_len` unsigned batch sizes, one per step. A
    /// null `data` uses `batch_size` for every step.
    sequence_descriptor: NDArrayDescriptor,
    /// Input data, plus the initial hidden and cell states.
    input_descriptor: LSTMDataDescriptor,
    /// Output data, plus the final hidden and cell states.
    output_descriptor: LSTMDataDescriptor,
    /// Default activation sigmoid.
    input_gate: LSTMGateDescriptor,
    /// Default activation sigmoid.
    forget_gate: LSTMGateDescriptor,
    /// Default activation tanh.
    candidate_gate: LSTMGateDescriptor,
    /// Default activation sigmoid.
    output_gate: LSTMGateDescriptor,
    /// Activation producing the hidden output. Default tanh.
    hidden_activation: Activation,
};

/// `BNNSLayerParametersArithmetic` — one elementwise arithmetic operation.
///
/// The operand descriptors do not live here: they live in the struct pointed to
/// by `arithmetic_function_fields`, whose type depends on
/// `arithmetic_function` (`ArithmeticUnary`, `ArithmeticBinary` or
/// `ArithmeticTernary`).
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersArithmetic = extern struct {
    arithmetic_function: ArithmeticFunction,
    /// Non-null. Points at the operand struct matching `arithmetic_function`.
    arithmetic_function_fields: *anyopaque,
    activation: Activation,
};

/// `BNNSLayerParametersPermute` — copies a tensor while reordering its axes.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersPermute = extern struct {
    i_desc: NDArrayDescriptor,
    /// Same layout and data type as `i_desc`, with `size` already permuted.
    o_desc: NDArrayDescriptor,
    /// `permutation[k]` is the *input* axis feeding output axis `k`. Entries at
    /// or beyond the layout's rank are ignored.
    permutation: [max_tensor_dimension]usize,
};

/// `BNNSLayerParametersTensorContraction` — an arbitrary contraction written in
/// Einstein summation notation, e.g. `"a_ijp, b_ijq -> o_pq"` for
/// `o_pq = alpha * sum_ij a_ijp * b_ijq`.
///
/// A left-hand name beginning with `w` marks that operand as trained weights;
/// at most one operand may be. `*` as the first or last index broadcasts. With
/// two genuine inputs the layer must be run through the two-input apply calls.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersTensorContraction = extern struct {
    /// The summation string. Must outlive the create call.
    operation: ?[*:0]const u8,
    /// Scaling applied to the result.
    alpha: f32,
    /// Scaling applied to the existing output before the result is added. Must
    /// be exactly 0.0 or 1.0.
    beta: f32,
    iA_desc: NDArrayDescriptor,
    iB_desc: NDArrayDescriptor,
    o_desc: NDArrayDescriptor,
};

/// `BNNSLayerParametersGram` — `G[f,c] = alpha * sum_ij x[i,j,f] * x[i,j,c]`,
/// with any leading dimensions broadcast. Equivalent to a tensor contraction
/// with `"x_*ijf, x_*ijc -> G_*fc"`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersGram = extern struct {
    /// Scaling applied to the result.
    alpha: f32,
    /// The tensor `x`.
    i_desc: NDArrayDescriptor,
    /// The Gram matrix `G`.
    o_desc: NDArrayDescriptor,
};

/// `BNNSLayerParametersResize` — resamples the dimensions whose input and
/// output sizes differ. Every resized dimension must scale the same way: all
/// up or all down.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersResize = extern struct {
    method: InterpolationMethod,
    i_desc: NDArrayDescriptor,
    /// Sizes must be an integral multiple of `i_desc`'s.
    o_desc: NDArrayDescriptor,
    /// Align the sampling grid to the centres of the scaled dimensions rather
    /// than to their edges.
    align_corners: bool,
};

/// `BNNSLayerParametersCropResize` — crops the regions named by a set of
/// bounding boxes and resizes each to the output size. Only bilinear
/// interpolation is implemented.
///
/// Note that no descriptors appear here: the tensors are passed to the create
/// call separately.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersCropResize = extern struct {
    /// The box coordinates are normalized to (0, 1).
    normalized_coordinates: bool,
    /// Extra scale multiplying the box coordinates.
    spatial_scale: f32,
    /// Value used where sampling falls outside the input.
    extrapolation_value: f32 = 0,
    sampling_mode: LinearSamplingMode,
    /// Which four numbers a box is: the corner/centre convention.
    box_coordinate_mode: BoxCoordinateMode,
    method: InterpolationMethod,
};

/// `BNNSLayerParametersBroadcastMatMul` — matrix multiply over the last two
/// indices of each operand, broadcasting all the leading ones.
///
/// `C = beta * C + alpha * op(A) * op(B)`, where the leading dimensions are
/// matched from the back and a dimension of size 1 is repeated.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersBroadcastMatMul = extern struct {
    /// Scaling applied to the product.
    alpha: f32,
    /// Scaling applied to the existing output. Must be exactly 0.0 or 1.0.
    beta: f32,
    /// Transpose the last two dimensions of A.
    transA: bool,
    /// Transpose the last two dimensions of B.
    transB: bool,
    /// A is being multiplied by itself; `iB_desc` is ignored. Inference is
    /// unaffected (only faster), but the backward pass is only correct with
    /// this set.
    quadratic: bool,
    /// Treat A as trained weights: fixed across a batch, gradients accumulated.
    a_is_weights: bool,
    /// Treat B as trained weights.
    b_is_weights: bool,
    iA_desc: NDArrayDescriptor,
    iB_desc: NDArrayDescriptor,
    o_desc: NDArrayDescriptor,
};

/// `BNNSLayerParametersMultiheadAttention` — the multihead attention layer of
/// "Attention is All You Need".
///
/// The shape parameters are all inferred from the descriptors: `num_heads` from
/// `query.weights.size[2]`, `d_model` from `query.target_desc.size[1]`,
/// `d_key` from `key.weights.size[1]`, `d_value` from
/// `output.target_desc.size[1]`, and the sequence lengths from
/// `query`/`key.target_desc.size[0]`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersMultiheadAttention = extern struct {
    /// Q, its per-head projection `Wᴾ` and bias `pᴾ`.
    query: MHAProjectionParameters,
    /// K, its per-head projection `Wᴷ` and bias `pᴷ`.
    key: MHAProjectionParameters,
    /// V, its per-head projection `Wⱽ` and bias `pⱽ`.
    value: MHAProjectionParameters,
    /// Append a row of zeroes to the projected K and V.
    add_zero_attn: bool,
    /// Optional `d_key x num_heads` bias `bᴷ` added inside the attention.
    /// Set `data = null` to omit; if present, `value_attn_bias` must be too.
    key_attn_bias: NDArrayDescriptor,
    /// Optional `d_value x num_heads` bias `bⱽ`. Paired with `key_attn_bias`.
    value_attn_bias: NDArrayDescriptor,
    /// The output tensor, the combining projection `Wᴼ` and bias `pᴼ`.
    output: MHAProjectionParameters,
    /// Dropout probability applied to the result. Any value outside the open
    /// range (0, 1) — 0 included — disables dropout.
    dropout: f32 = 0,
    /// Seed for the dropout generator.
    seed: u32 = 0,
};

/// `BNNSLayerParametersPadding` — grows a tensor by adding a border in each
/// dimension.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersPadding = extern struct {
    i_desc: NDArrayDescriptor,
    /// `o_desc.size[d]` must equal
    /// `i_desc.size[d] + padding_size[d][0] + padding_size[d][1]`.
    o_desc: NDArrayDescriptor,
    /// `[d][0]` elements before and `[d][1]` after the data in dimension `d`.
    /// Entries beyond the layout's rank are not read.
    padding_size: [max_tensor_dimension][2]usize,
    padding_mode: PaddingMode,
    /// Fill value for `.constant` padding. Only the first `sizeof(element)`
    /// bytes of these 4 are used, so the bit pattern must match the data type.
    padding_value: u32,
};

/// `BNNSLayerParametersEmbedding` — a lookup table. Each integer index in the
/// input selects one item of `dictionary`; the output shape is the dictionary
/// item shape concatenated with the input shape.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersEmbedding = extern struct {
    flags: EmbeddingFlags,
    /// Must hold a signed or unsigned integer type.
    i_desc: NDArrayDescriptor,
    /// Shape `(dictionary item shape, i_desc shape)`.
    o_desc: NDArrayDescriptor,
    /// The item shape with a trailing dimension of `num_embeddings`.
    dictionary: NDArrayDescriptor,
    /// When in `[0, num_embeddings - 1]`, that entry is treated as an
    /// all-zero tensor on lookup.
    padding_idx: usize,
    /// If nonzero, any vector whose norm exceeds this is renormalized to it
    /// during the forward lookup.
    max_norm: f32 = 0,
    /// The `p` of the p-norm used with `max_norm`. 0 means the 2-norm.
    norm_type: f32 = 0,
};

/// `BNNSLayerParametersQuantization` — converts between a higher and a lower
/// precision tensor, optionally per-axis. The `data_scale`/`data_bias` fields
/// of the descriptors are ignored here; `scale` and `bias` below are used
/// instead.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const LayerParametersQuantization = extern struct {
    /// Which axis `scale`/`bias` vary along: exactly one bit set, or 0 for a
    /// single scalar scale and bias over the whole tensor. Bit `naxis`, one
    /// past the layout's dimensions, selects the batch axis.
    axis_mask: usize = 0,
    function: QuantizerFunction,
    i_desc: NDArrayDescriptor,
    o_desc: NDArrayDescriptor,
    /// Optional, `.vector` layout. Ignored when `scale.data` is null. Length
    /// is the size of the selected axis, or 1 when `axis_mask` is 0.
    scale: NDArrayDescriptor,
    /// Optional, `.vector` layout. Ignored when `bias.data` is null.
    bias: NDArrayDescriptor,
};

// ============================================================================
// Errors
// ============================================================================

/// BNNS reports failure two ways: an `int` return that is 0 on success, and
/// object-returning calls that hand back a null `data` pointer. Neither carries
/// a reason code — the detail goes to the message-log callback, or to `os_log`
/// if none is installed.
pub const Error = error{
    /// A BNNS call returned a nonzero status.
    BnnsFailed,
    /// A BNNS call that returns an object handed back a null one.
    BnnsAllocationFailed,
    /// A size-returning call returned `SIZE_MAX`, its failure sentinel.
    BnnsQueryFailed,
};

/// Turn a BNNS `int` status into an error union. Zero is success.
pub fn check(status: c_int) Error!void {
    if (status != 0) return Error.BnnsFailed;
}

/// Turn a `size_t`-returning query into an error union. These report failure as
/// `SIZE_MAX`, which is easy to mistake for a plausible size.
pub fn checkSize(value: usize) Error!usize {
    if (value == std.math.maxInt(usize)) return Error.BnnsQueryFailed;
    return value;
}

// ============================================================================
// Layout parity with C
// ============================================================================

/// Assert that `T` has the given size and field offsets.
fn expectCLayout(comptime T: type, comptime size: usize, comptime offsets: anytype) !void {
    try std.testing.expectEqual(size, @sizeOf(T));
    inline for (offsets) |entry| {
        try std.testing.expectEqual(@as(usize, entry[1]), @offsetOf(T, entry[0]));
    }
}

// Every number below was MEASURED on this machine, not inferred: a throwaway C
// program including <Accelerate/Accelerate.h> printed `sizeof` for each struct
// and `offsetof` for each of its fields, and these are those numbers verbatim.
// A failure here means the Zig struct disagrees with the framework it is
// passed to — a wrong field type, a missing field or a wrong order — which
// would otherwise compile, link and silently corrupt data.
test "struct layouts match Accelerate.h: descriptors, activations and optimizer field blocks" {
    try expectCLayout(FilterParameters, 32, .{ .{ "flags", 0 }, .{ "n_threads", 8 }, .{ "alloc_memory", 16 }, .{ "free_memory", 24 } });
    try expectCLayout(NDArrayDescriptor, 176, .{ .{ "flags", 0 }, .{ "layout", 4 }, .{ "size", 8 }, .{ "stride", 72 }, .{ "data", 136 }, .{ "data_type", 144 }, .{ "table_data", 152 }, .{ "table_data_type", 160 }, .{ "data_scale", 164 }, .{ "data_bias", 168 } });
    try expectCLayout(Tensor, 160, .{ .{ "data_type", 0 }, .{ "rank", 4 }, .{ "shape", 8 }, .{ "stride", 72 }, .{ "data", 136 }, .{ "data_size_in_bytes", 144 }, .{ "name", 152 } });
    try expectCLayout(Activation, 48, .{ .{ "function", 0 }, .{ "alpha", 4 }, .{ "beta", 8 }, .{ "iscale", 12 }, .{ "ioffset", 16 }, .{ "ishift", 20 }, .{ "iscale_per_channel", 24 }, .{ "ioffset_per_channel", 32 }, .{ "ishift_per_channel", 40 } });
    try expectCLayout(LSTMGateDescriptor, 928, .{ .{ "iw_desc", 0 }, .{ "hw_desc", 352 }, .{ "cw_desc", 528 }, .{ "b_desc", 704 }, .{ "activation", 880 } });
    try expectCLayout(LSTMDataDescriptor, 528, .{ .{ "data_desc", 0 }, .{ "hidden_desc", 176 }, .{ "cell_state_desc", 352 } });
    try expectCLayout(ArithmeticUnary, 368, .{ .{ "in", 0 }, .{ "in_type", 176 }, .{ "out", 184 }, .{ "out_type", 360 } });
    try expectCLayout(ArithmeticBinary, 552, .{ .{ "in1", 0 }, .{ "in1_type", 176 }, .{ "in2", 184 }, .{ "in2_type", 360 }, .{ "out", 368 }, .{ "out_type", 544 } });
    try expectCLayout(ArithmeticTernary, 736, .{ .{ "in1", 0 }, .{ "in1_type", 176 }, .{ "in2", 184 }, .{ "in2_type", 360 }, .{ "in3", 368 }, .{ "in3_type", 544 }, .{ "out", 552 }, .{ "out_type", 728 } });
    try expectCLayout(MHAProjectionParameters, 528, .{ .{ "target_desc", 0 }, .{ "weights", 176 }, .{ "bias", 352 } });
    try expectCLayout(OptimizerSGDMomentumFields, 40, .{ .{ "learning_rate", 0 }, .{ "momentum", 4 }, .{ "gradient_scale", 8 }, .{ "regularization_scale", 12 }, .{ "clip_gradients", 16 }, .{ "clip_gradients_min", 20 }, .{ "clip_gradients_max", 24 }, .{ "nesterov", 28 }, .{ "regularization_func", 32 }, .{ "sgd_momentum_variant", 36 } });
    try expectCLayout(OptimizerSGDMomentumWithClippingFields, 48, .{ .{ "learning_rate", 0 }, .{ "momentum", 4 }, .{ "gradient_scale", 8 }, .{ "regularization_scale", 12 }, .{ "nesterov", 16 }, .{ "regularization_func", 20 }, .{ "sgd_momentum_variant", 24 }, .{ "clipping_func", 28 }, .{ "clip_gradients_min", 32 }, .{ "clip_gradients_max", 36 }, .{ "clip_gradients_max_norm", 40 }, .{ "clip_gradients_use_norm", 44 } });
    try expectCLayout(OptimizerAdamFields, 44, .{ .{ "learning_rate", 0 }, .{ "beta1", 4 }, .{ "beta2", 8 }, .{ "time_step", 12 }, .{ "epsilon", 16 }, .{ "gradient_scale", 20 }, .{ "regularization_scale", 24 }, .{ "clip_gradients", 28 }, .{ "clip_gradients_min", 32 }, .{ "clip_gradients_max", 36 }, .{ "regularization_func", 40 } });
    try expectCLayout(OptimizerAdamWithClippingFields, 52, .{ .{ "learning_rate", 0 }, .{ "beta1", 4 }, .{ "beta2", 8 }, .{ "time_step", 12 }, .{ "epsilon", 16 }, .{ "gradient_scale", 20 }, .{ "regularization_scale", 24 }, .{ "regularization_func", 28 }, .{ "clipping_func", 32 }, .{ "clip_gradients_min", 36 }, .{ "clip_gradients_max", 40 }, .{ "clip_gradients_max_norm", 44 }, .{ "clip_gradients_use_norm", 48 } });
    try expectCLayout(OptimizerRMSPropFields, 44, .{ .{ "learning_rate", 0 }, .{ "alpha", 4 }, .{ "epsilon", 8 }, .{ "centered", 12 }, .{ "momentum", 16 }, .{ "gradient_scale", 20 }, .{ "regularization_scale", 24 }, .{ "clip_gradients", 28 }, .{ "clip_gradients_min", 32 }, .{ "clip_gradients_max", 36 }, .{ "regularization_func", 40 } });
    try expectCLayout(OptimizerRMSPropWithClippingFields, 52, .{ .{ "learning_rate", 0 }, .{ "alpha", 4 }, .{ "epsilon", 8 }, .{ "centered", 12 }, .{ "momentum", 16 }, .{ "gradient_scale", 20 }, .{ "regularization_scale", 24 }, .{ "regularization_func", 28 }, .{ "clipping_func", 32 }, .{ "clip_gradients_min", 36 }, .{ "clip_gradients_max", 40 }, .{ "clip_gradients_max_norm", 44 }, .{ "clip_gradients_use_norm", 48 } });
    try expectCLayout(SparsityParameters, 24, .{ .{ "flags", 0 }, .{ "sparsity_ratio", 8 }, .{ "sparsity_type", 16 }, .{ "target_system", 20 } });
    try expectCLayout(ImageStackDescriptor, 56, .{ .{ "width", 0 }, .{ "height", 8 }, .{ "channels", 16 }, .{ "row_stride", 24 }, .{ "image_stride", 32 }, .{ "data_type", 40 }, .{ "data_scale", 44 }, .{ "data_bias", 48 } });
    try expectCLayout(VectorDescriptor, 24, .{ .{ "size", 0 }, .{ "data_type", 8 }, .{ "data_scale", 12 }, .{ "data_bias", 16 } });
    try expectCLayout(LayerData, 32, .{ .{ "data", 0 }, .{ "data_type", 8 }, .{ "data_scale", 12 }, .{ "data_bias", 16 }, .{ "data_table", 24 } });
    try expectCLayout(ConvolutionLayerParameters, 176, .{ .{ "x_stride", 0 }, .{ "y_stride", 8 }, .{ "x_padding", 16 }, .{ "y_padding", 24 }, .{ "k_width", 32 }, .{ "k_height", 40 }, .{ "in_channels", 48 }, .{ "out_channels", 56 }, .{ "weights", 64 }, .{ "bias", 96 }, .{ "activation", 128 } });
    try expectCLayout(FullyConnectedLayerParameters, 128, .{ .{ "in_size", 0 }, .{ "out_size", 8 }, .{ "weights", 16 }, .{ "bias", 48 }, .{ "activation", 80 } });
    try expectCLayout(PoolingLayerParameters, 152, .{ .{ "x_stride", 0 }, .{ "y_stride", 8 }, .{ "x_padding", 16 }, .{ "y_padding", 24 }, .{ "k_width", 32 }, .{ "k_height", 40 }, .{ "in_channels", 48 }, .{ "out_channels", 56 }, .{ "pooling_function", 64 }, .{ "bias", 72 }, .{ "activation", 104 } });
}

// Every number below was MEASURED on this machine, not inferred: a throwaway C
// program including <Accelerate/Accelerate.h> printed `sizeof` for each struct
// and `offsetof` for each of its fields, and these are those numbers verbatim.
// A failure here means the Zig struct disagrees with the framework it is
// passed to — a wrong field type, a missing field or a wrong order — which
// would otherwise compile, link and silently corrupt data.
test "struct layouts match Accelerate.h: layer parameter blocks" {
    try expectCLayout(LayerParametersConvolution, 840, .{ .{ "i_desc", 0 }, .{ "w_desc", 176 }, .{ "o_desc", 352 }, .{ "bias", 528 }, .{ "activation", 704 }, .{ "x_stride", 752 }, .{ "y_stride", 760 }, .{ "x_dilation_stride", 768 }, .{ "y_dilation_stride", 776 }, .{ "x_padding", 784 }, .{ "y_padding", 792 }, .{ "groups", 800 }, .{ "pad", 808 } });
    try expectCLayout(LayerParametersFullyConnected, 752, .{ .{ "i_desc", 0 }, .{ "w_desc", 176 }, .{ "o_desc", 352 }, .{ "bias", 528 }, .{ "activation", 704 } });
    try expectCLayout(LayerParametersPooling, 680, .{ .{ "i_desc", 0 }, .{ "o_desc", 176 }, .{ "bias", 352 }, .{ "activation", 528 }, .{ "pooling_function", 576 }, .{ "k_width", 584 }, .{ "k_height", 592 }, .{ "x_stride", 600 }, .{ "y_stride", 608 }, .{ "x_dilation_stride", 616 }, .{ "y_dilation_stride", 624 }, .{ "x_padding", 632 }, .{ "y_padding", 640 }, .{ "pad", 648 } });
    try expectCLayout(LayerParametersActivation, 408, .{ .{ "i_desc", 0 }, .{ "o_desc", 176 }, .{ "activation", 352 }, .{ "axis_flags", 400 } });
    try expectCLayout(LayerParametersLossBase, 368, .{ .{ "function", 0 }, .{ "i_desc", 8 }, .{ "o_desc", 184 }, .{ "reduction", 360 } });
    try expectCLayout(LayerParametersLossSoftmaxCrossEntropy, 368, .{ .{ "function", 0 }, .{ "i_desc", 8 }, .{ "o_desc", 184 }, .{ "reduction", 360 }, .{ "label_smooth", 364 } });
    try expectCLayout(LayerParametersLossSigmoidCrossEntropy, 368, .{ .{ "function", 0 }, .{ "i_desc", 8 }, .{ "o_desc", 184 }, .{ "reduction", 360 }, .{ "label_smooth", 364 } });
    try expectCLayout(LayerParametersLossHuber, 368, .{ .{ "function", 0 }, .{ "i_desc", 8 }, .{ "o_desc", 184 }, .{ "reduction", 360 }, .{ "huber_delta", 364 } });
    try expectCLayout(LayerParametersLossYolo, 440, .{ .{ "function", 0 }, .{ "i_desc", 8 }, .{ "o_desc", 184 }, .{ "reduction", 360 }, .{ "huber_delta", 364 }, .{ "number_of_grid_columns", 368 }, .{ "number_of_grid_rows", 376 }, .{ "number_of_anchor_boxes", 384 }, .{ "anchor_box_size", 392 }, .{ "rescore", 400 }, .{ "scale_xy", 404 }, .{ "scale_wh", 408 }, .{ "scale_object", 412 }, .{ "scale_no_object", 416 }, .{ "scale_classification", 420 }, .{ "object_minimum_iou", 424 }, .{ "no_object_maximum_iou", 428 }, .{ "anchors_data", 432 } });
    try expectCLayout(LayerParametersNormalization, 1128, .{ .{ "i_desc", 0 }, .{ "o_desc", 176 }, .{ "beta_desc", 352 }, .{ "gamma_desc", 528 }, .{ "moving_mean_desc", 704 }, .{ "moving_variance_desc", 880 }, .{ "momentum", 1056 }, .{ "epsilon", 1060 }, .{ "activation", 1064 }, .{ "num_groups", 1112 }, .{ "normalization_axis", 1120 } });
    try expectCLayout(LayerParametersDropout, 368, .{ .{ "i_desc", 0 }, .{ "o_desc", 176 }, .{ "rate", 352 }, .{ "seed", 356 }, .{ "control", 360 } });
    try expectCLayout(LayerParametersLSTM, 5040, .{ .{ "input_size", 0 }, .{ "hidden_size", 8 }, .{ "batch_size", 16 }, .{ "num_layers", 24 }, .{ "seq_len", 32 }, .{ "dropout", 40 }, .{ "lstm_flags", 44 }, .{ "sequence_descriptor", 48 }, .{ "input_descriptor", 224 }, .{ "output_descriptor", 752 }, .{ "input_gate", 1280 }, .{ "forget_gate", 2208 }, .{ "candidate_gate", 3136 }, .{ "output_gate", 4064 }, .{ "hidden_activation", 4992 } });
    try expectCLayout(LayerParametersArithmetic, 64, .{ .{ "arithmetic_function", 0 }, .{ "arithmetic_function_fields", 8 }, .{ "activation", 16 } });
    try expectCLayout(LayerParametersPermute, 416, .{ .{ "i_desc", 0 }, .{ "o_desc", 176 }, .{ "permutation", 352 } });
    try expectCLayout(LayerParametersTensorContraction, 544, .{ .{ "operation", 0 }, .{ "alpha", 8 }, .{ "beta", 12 }, .{ "iA_desc", 16 }, .{ "iB_desc", 192 }, .{ "o_desc", 368 } });
    try expectCLayout(LayerParametersGram, 360, .{ .{ "alpha", 0 }, .{ "i_desc", 8 }, .{ "o_desc", 184 } });
    try expectCLayout(LayerParametersResize, 368, .{ .{ "method", 0 }, .{ "i_desc", 8 }, .{ "o_desc", 184 }, .{ "align_corners", 360 } });
    try expectCLayout(LayerParametersCropResize, 24, .{ .{ "normalized_coordinates", 0 }, .{ "spatial_scale", 4 }, .{ "extrapolation_value", 8 }, .{ "sampling_mode", 12 }, .{ "box_coordinate_mode", 16 }, .{ "method", 20 } });
    try expectCLayout(LayerParametersBroadcastMatMul, 544, .{ .{ "alpha", 0 }, .{ "beta", 4 }, .{ "transA", 8 }, .{ "transB", 9 }, .{ "quadratic", 10 }, .{ "a_is_weights", 11 }, .{ "b_is_weights", 12 }, .{ "iA_desc", 16 }, .{ "iB_desc", 192 }, .{ "o_desc", 368 } });
    try expectCLayout(LayerParametersMultiheadAttention, 2480, .{ .{ "query", 0 }, .{ "key", 528 }, .{ "value", 1056 }, .{ "add_zero_attn", 1584 }, .{ "key_attn_bias", 1592 }, .{ "value_attn_bias", 1768 }, .{ "output", 1944 }, .{ "dropout", 2472 }, .{ "seed", 2476 } });
    try expectCLayout(LayerParametersPadding, 488, .{ .{ "i_desc", 0 }, .{ "o_desc", 176 }, .{ "padding_size", 352 }, .{ "padding_mode", 480 }, .{ "padding_value", 484 } });
    try expectCLayout(LayerParametersEmbedding, 552, .{ .{ "flags", 0 }, .{ "i_desc", 8 }, .{ "o_desc", 184 }, .{ "dictionary", 360 }, .{ "padding_idx", 536 }, .{ "max_norm", 544 }, .{ "norm_type", 548 } });
    try expectCLayout(LayerParametersQuantization, 720, .{ .{ "axis_mask", 0 }, .{ "function", 8 }, .{ "i_desc", 16 }, .{ "o_desc", 192 }, .{ "scale", 368 }, .{ "bias", 544 } });
}

test "DataType encoding matches the header's bit layout" {
    const testing = std.testing;
    try testing.expectEqual(@as(u32, 0x10020), @intFromEnum(DataType.float32));
    try testing.expectEqual(@as(u32, 0x18010), @intFromEnum(DataType.bfloat16));
    try testing.expectEqual(@as(u32, 0x20008), @intFromEnum(DataType.int8));
    try testing.expectEqual(@as(u32, 0x40008), @intFromEnum(DataType.uint8));
    try testing.expectEqual(@as(u32, 0x100008), @intFromEnum(DataType.boolean));

    try testing.expectEqual(@as(u32, 32), DataType.float32.bits());
    try testing.expectEqual(@as(u32, 4), DataType.uint4.bits());
    try testing.expect(DataType.float16.isFloat());
    try testing.expect(!DataType.int16.isFloat());
    try testing.expect(DataType.int16.isSigned());
    try testing.expect(DataType.uint16.isUnsigned());
    try testing.expect(DataType.indexed4.isIndexed());

    // bfloat16 carries the float bit as well as its own 0x8000 marker, so it
    // must not be mistaken for an integer type.
    try testing.expect(DataType.bfloat16.isFloat());
    try testing.expect(!DataType.bfloat16.isSigned());

    try testing.expectEqual(DataType.float32, DataType.of(f32));
    try testing.expectEqual(DataType.int32, DataType.of(i32));
}

test "Tensor.init fills contiguous first-major strides" {
    const testing = std.testing;
    var data: [24]f32 = @splat(0);
    const t = Tensor.init(f32, &data, &.{ 2, 3, 4 });

    try testing.expectEqual(@as(u8, 3), t.rank);
    try testing.expectEqualSlices(isize, &.{ 2, 3, 4 }, t.shape[0..3]);
    // First-major: the last axis is the fastest-varying.
    try testing.expectEqualSlices(isize, &.{ 12, 4, 1 }, t.stride[0..3]);
    try testing.expectEqual(@as(usize, 24 * @sizeOf(f32)), t.data_size_in_bytes);
    try testing.expectEqual(DataType.float32, t.data_type);
    // BNNS expects stride[d] >= stride[d+1] for first-major data.
    try testing.expect(t.stride[0] >= t.stride[1] and t.stride[1] >= t.stride[2]);
}

test "check and checkSize map BNNS's two failure conventions" {
    const testing = std.testing;
    try check(0);
    try testing.expectError(Error.BnnsFailed, check(-1));
    try testing.expectError(Error.BnnsFailed, check(1));

    try testing.expectEqual(@as(usize, 7), try checkSize(7));
    try testing.expectEqual(@as(usize, 0), try checkSize(0));
    try testing.expectError(Error.BnnsQueryFailed, checkSize(std.math.maxInt(usize)));
}
