//! Raw BNNS entry points.
//!
//! Both generations of the API are declared here. The modern graph surface
//! (`bnns_graph.h`) comes first; the layer-filter surface Apple deprecated in
//! macOS 15.0 (`BNNSFilterCreateLayer*`, `BNNSFilterApply*`, and the ~75
//! symbols around them) is in the clearly labelled section at the bottom. It is
//! bound deliberately: macOS 15.0 is a recent floor, and callers on older
//! deployment targets have no Graph API to fall back on. Every deprecated
//! declaration carries a doc comment naming the deprecating version and, where
//! the header gives one, the replacement.
//!
//! One nullability rule applies throughout: `bnns.h` sits inside
//! `_Pragma("clang assume_nonnull begin")`, so an unannotated pointer is
//! `_Nonnull` and only the parameters spelled `_Nullable` are optional. The
//! declarations below follow that, which is why several data pointers that look
//! like they could be null are not.
//!
//! Eleven graph entry points are `__asm__`-renamed in the header: the C name
//! `BNNSGraphContextExecute` resolves to the symbol
//! `_BNNSGraphContextExecute_v2`. Those are declared with `@extern` so the Zig
//! name can stay readable while the link name stays correct. Declaring them as
//! a plain `extern fn` under the header spelling would fail to link — which the
//! link test at the bottom of this file catches.

const types = @import("types.zig");

// -- Re-exported types from types.zig --
pub const DataType = types.DataType;
pub const DataLayout = types.DataLayout;
pub const NDArrayFlags = types.NDArrayFlags;
pub const ReduceFunction = types.ReduceFunction;
pub const RandomGeneratorMethod = types.RandomGeneratorMethod;
pub const FilterParameters = types.FilterParameters;
pub const NDArrayDescriptor = types.NDArrayDescriptor;
pub const Tensor = types.Tensor;
pub const max_tensor_dimension = types.max_tensor_dimension;

// -- Re-exported types used only by the deprecated layer-filter API below --
pub const Activation = types.Activation;
pub const ConvolutionLayerParameters = types.ConvolutionLayerParameters;
pub const FilterType = types.FilterType;
pub const FullyConnectedLayerParameters = types.FullyConnectedLayerParameters;
pub const ImageStackDescriptor = types.ImageStackDescriptor;
pub const LayerParametersActivation = types.LayerParametersActivation;
pub const LayerParametersArithmetic = types.LayerParametersArithmetic;
pub const LayerParametersBroadcastMatMul = types.LayerParametersBroadcastMatMul;
pub const LayerParametersConvolution = types.LayerParametersConvolution;
pub const LayerParametersCropResize = types.LayerParametersCropResize;
pub const LayerParametersDropout = types.LayerParametersDropout;
pub const LayerParametersEmbedding = types.LayerParametersEmbedding;
pub const LayerParametersFullyConnected = types.LayerParametersFullyConnected;
pub const LayerParametersGram = types.LayerParametersGram;
pub const LayerParametersLSTM = types.LayerParametersLSTM;
pub const LayerParametersMultiheadAttention = types.LayerParametersMultiheadAttention;
pub const LayerParametersNormalization = types.LayerParametersNormalization;
pub const LayerParametersPadding = types.LayerParametersPadding;
pub const LayerParametersPermute = types.LayerParametersPermute;
pub const LayerParametersPooling = types.LayerParametersPooling;
pub const LayerParametersQuantization = types.LayerParametersQuantization;
pub const LayerParametersResize = types.LayerParametersResize;
pub const LayerParametersTensorContraction = types.LayerParametersTensorContraction;
pub const MHAProjectionParameters = types.MHAProjectionParameters;
pub const NormType = types.NormType;
pub const OptimizerFunction = types.OptimizerFunction;
pub const PointerSpecifier = types.PointerSpecifier;
pub const PoolingLayerParameters = types.PoolingLayerParameters;
pub const RelationalOperator = types.RelationalOperator;
pub const ShuffleType = types.ShuffleType;
pub const SparsityParameters = types.SparsityParameters;
pub const VectorDescriptor = types.VectorDescriptor;

// ============================================================================
// Graph objects
// ============================================================================

/// `bnns_graph_t` — a compiled graph. A pointer/size pair rather than an opaque
/// handle because the payload may be written to disk and mmap'd back in.
/// Released with `free` (or `munmap`, if compiled straight to a file).
pub const bnns_graph_t = extern struct {
    data: ?*anyopaque = null,
    size: usize = 0,
};

/// `bnns_graph_context_t` — mutable state wrapped around a graph. Required for
/// dynamic shapes and several execution options. The underlying graph must
/// outlive it.
pub const bnns_graph_context_t = extern struct {
    data: ?*anyopaque = null,
    size: usize = 0,
};

/// `bnns_graph_compile_options_t` — compilation options.
pub const bnns_graph_compile_options_t = extern struct {
    data: ?*anyopaque = null,
    size: usize = 0,
};

/// `bnns_graph_shape_t` — one argument's shape, for `SetDynamicShapes`.
/// `rank == 0` means "use the shape baked into the source".
pub const bnns_graph_shape_t = extern struct {
    rank: usize = 0,
    shape: ?[*]u64 = null,
};

/// `bnns_user_message_data_t` — opaque payload handed back to a message-log
/// callback unchanged.
pub const bnns_user_message_data_t = extern struct {
    size: usize = 0,
    data: ?*anyopaque = null,
};

/// `BNNSGraphMessageLevel` — a bitmask, so the log-mask setters take a
/// logical OR of these.
pub const BNNSGraphMessageLevel = enum(u32) {
    info = 1,
    unsupported = 2,
    warning = 4,
    err = 8,
    _,
};

/// `BNNSGraphOptimizationPreference`
pub const BNNSGraphOptimizationPreference = enum(u32) {
    performance = 0,
    ir_size = 1,
    _,
};

/// `BNNSGraphArgumentIntent`. `in_out` is `in | out`, i.e. 3.
pub const BNNSGraphArgumentIntent = enum(u32) {
    in = 1,
    out = 2,
    in_out = 3,
    _,
};

/// `BNNSGraphArgumentType` — how `BNNSGraphContextExecute` reads the
/// `arguments` array. Note the values are 0 and 2; 1 is not used.
pub const BNNSGraphArgumentType = enum(u32) {
    pointer = 0,
    tensor = 2,
    _,
};

/// `bnns_graph_argument_t` — one entry of the `arguments` array passed to
/// execute. The union member that is live depends on the argument type set via
/// `BNNSGraphContextSetArgumentType`.
pub const bnns_graph_argument_t = extern struct {
    /// `tensor` / `descriptor` / `data_ptr` in C. All three are pointers, so a
    /// single field with a cast at the call site is equivalent and avoids an
    /// extern union.
    ptr: ?*anyopaque = null,
    /// Size in bytes of `ptr`, when it is a raw data pointer.
    data_ptr_size: usize = 0,
};

/// `bnns_graph_realloc_fn_t` — user allocator for workspace/output memory.
/// Returns 0 on success.
pub const bnns_graph_realloc_fn_t = ?*const fn (
    user_memory_context: ?*anyopaque,
    user_memory_context_size: usize,
    memptr: *?*anyopaque,
    alignment: usize,
    size: usize,
) callconv(.c) c_int;

/// `bnns_graph_free_all_fn_t` — called once at context destruction to release
/// everything associated with the user memory context.
pub const bnns_graph_free_all_fn_t = ?*const fn (
    user_memory_context: ?*anyopaque,
    user_memory_context_size: usize,
) callconv(.c) void;

/// `bnns_graph_compile_message_fn_t`
pub const bnns_graph_compile_message_fn_t = ?*const fn (
    msg_level: BNNSGraphMessageLevel,
    error_msg: [*:0]const u8,
    source_location: ?[*:0]const u8,
    additional_logging_arguments: ?*bnns_user_message_data_t,
) callconv(.c) void;

/// `bnns_graph_execute_message_fn_t`
pub const bnns_graph_execute_message_fn_t = ?*const fn (
    msg_level: BNNSGraphMessageLevel,
    error_msg: [*:0]const u8,
    op_info: ?[*:0]const u8,
    additional_logging_arguments: ?*bnns_user_message_data_t,
) callconv(.c) void;

/// `BNNSRandomGenerator` — `void *`, opaque.
pub const BNNSRandomGenerator = ?*anyopaque;

/// `BNNSNearestNeighbors` — `void *`, opaque.
pub const BNNSNearestNeighbors = ?*anyopaque;

/// `BNNSFilter` — `void *`, opaque. Handle to one layer-filter object, created
/// by `BNNSFilterCreateLayer*` and released with `BNNSFilterDestroy`.
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub const BNNSFilter = ?*anyopaque;

/// `BNNSLayerParametersReduction` — the whole input to
/// `BNNSDirectApplyReduction`.
pub const BNNSLayerParametersReduction = extern struct {
    i_desc: NDArrayDescriptor,
    o_desc: NDArrayDescriptor,
    /// Weights, for the reductions that take them. Zero-initialised otherwise.
    w_desc: NDArrayDescriptor,
    reduce_func: ReduceFunction,
    /// Added to the argument of `sum_log`.
    epsilon: f32,
};

// ============================================================================
// Graph — compile options
// ============================================================================

pub extern fn BNNSGraphCompileOptionsMakeDefault() bnns_graph_compile_options_t;
pub extern fn BNNSGraphCompileOptionsDestroy(options: bnns_graph_compile_options_t) void;

pub extern fn BNNSGraphCompileOptionsSetTargetSingleThread(options: bnns_graph_compile_options_t, value: bool) void;
pub extern fn BNNSGraphCompileOptionsGetTargetSingleThread(options: bnns_graph_compile_options_t) bool;

pub extern fn BNNSGraphCompileOptionsSetGenerateDebugInfo(options: bnns_graph_compile_options_t, value: bool) void;
pub extern fn BNNSGraphCompileOptionsGetGenerateDebugInfo(options: bnns_graph_compile_options_t) bool;

pub extern fn BNNSGraphCompileOptionsSetOptimizationPreference(options: bnns_graph_compile_options_t, preference: BNNSGraphOptimizationPreference) void;
pub extern fn BNNSGraphCompileOptionsGetOptimizationPreference(options: bnns_graph_compile_options_t) BNNSGraphOptimizationPreference;

pub extern fn BNNSGraphCompileOptionsSetMessageLogCallback(options: bnns_graph_compile_options_t, log_callback: bnns_graph_compile_message_fn_t, additional_logging_arguments: ?*bnns_user_message_data_t) void;
pub extern fn BNNSGraphCompileOptionsSetMessageLogMask(options: bnns_graph_compile_options_t, log_level_mask: u32) void;

pub extern fn BNNSGraphCompileOptionsSetOutputPath(options: bnns_graph_compile_options_t, path: ?[*:0]const u8) void;
pub extern fn BNNSGraphCompileOptionsGetOutputPath(options: bnns_graph_compile_options_t) ?[*:0]const u8;
pub extern fn BNNSGraphCompileOptionsSetOutputFD(options: bnns_graph_compile_options_t, fd: c_int) void;
pub extern fn BNNSGraphCompileOptionsGetOutputFD(options: bnns_graph_compile_options_t) c_int;

// ============================================================================
// Graph — compilation
// ============================================================================

/// Header name `BNNSGraphCompileFromFile`; symbol `_BNNSGraphCompileFromFile_v2`.
pub const BNNSGraphCompileFromFile = @extern(*const fn (
    filename: [*:0]const u8,
    function: ?[*:0]const u8,
    options: bnns_graph_compile_options_t,
) callconv(.c) bnns_graph_t, .{ .name = "BNNSGraphCompileFromFile_v2" });

// ============================================================================
// Graph — query
// ============================================================================

pub extern fn BNNSGraphGetInputCount(graph: bnns_graph_t, function: ?[*:0]const u8) usize;
pub extern fn BNNSGraphGetOutputCount(graph: bnns_graph_t, function: ?[*:0]const u8) usize;
pub extern fn BNNSGraphGetArgumentCount(graph: bnns_graph_t, function: ?[*:0]const u8) usize;
pub extern fn BNNSGraphGetFunctionCount(graph: bnns_graph_t) usize;

/// Header name `BNNSGraphGetInputNames`; symbol `_BNNSGraphGetInputNames_v2`.
pub const BNNSGraphGetInputNames = @extern(*const fn (
    graph: bnns_graph_t,
    function: ?[*:0]const u8,
    input_names_count: usize,
    input_names: [*]?[*:0]const u8,
) callconv(.c) c_int, .{ .name = "BNNSGraphGetInputNames_v2" });

/// Header name `BNNSGraphGetOutputNames`; symbol `_BNNSGraphGetOutputNames_v2`.
pub const BNNSGraphGetOutputNames = @extern(*const fn (
    graph: bnns_graph_t,
    function: ?[*:0]const u8,
    output_names_count: usize,
    output_names: [*]?[*:0]const u8,
) callconv(.c) c_int, .{ .name = "BNNSGraphGetOutputNames_v2" });

pub extern fn BNNSGraphGetArgumentNames(graph: bnns_graph_t, function: ?[*:0]const u8, argument_names_count: usize, argument_names: [*]?[*:0]const u8) c_int;
pub extern fn BNNSGraphGetFunctionNames(graph: bnns_graph_t, function_name_count: usize, function_names: [*]?[*:0]const u8) c_int;
pub extern fn BNNSGraphGetArgumentIntents(graph: bnns_graph_t, function: ?[*:0]const u8, argument_intents_count: usize, argument_intents: [*]BNNSGraphArgumentIntent) c_int;
pub extern fn BNNSGraphGetArgumentPosition(graph: bnns_graph_t, function: ?[*:0]const u8, argument: [*:0]const u8) usize;
pub extern fn BNNSGraphGetArgumentInterleaveFactors(graph: bnns_graph_t, function: ?[*:0]const u8, argument_count: usize, argument_interleave: [*]?[*]const u16, argument_interleave_counts: [*]usize) c_int;
pub extern fn BNNSGraphTensorFillStrides(graph: bnns_graph_t, function: ?[*:0]const u8, argument: [*:0]const u8, tensor: *Tensor) c_int;

// ============================================================================
// Graph — context
// ============================================================================

pub extern fn BNNSGraphContextMake(graph: bnns_graph_t) bnns_graph_context_t;
pub extern fn BNNSGraphContextMakeStreaming(graph: bnns_graph_t, function: ?[*:0]const u8, initial_states_count: usize, initial_states: ?[*]const Tensor) bnns_graph_context_t;

/// Header name `BNNSGraphContextDestroy`; symbol `_BNNSGraphContextDestroy_v2`.
pub const BNNSGraphContextDestroy = @extern(*const fn (
    context: bnns_graph_context_t,
) callconv(.c) void, .{ .name = "BNNSGraphContextDestroy_v2" });

/// Header name `BNNSGraphContextSetDynamicShapes`; symbol
/// `_BNNSGraphContextSetDynamicShapes_v2`.
pub const BNNSGraphContextSetDynamicShapes = @extern(*const fn (
    context: bnns_graph_context_t,
    function: ?[*:0]const u8,
    shapes_count: usize,
    shapes: [*]bnns_graph_shape_t,
) callconv(.c) c_int, .{ .name = "BNNSGraphContextSetDynamicShapes_v2" });

/// Header name `BNNSGraphContextSetBatchSize`; symbol
/// `_BNNSGraphContextSetBatchSize_v2`.
pub const BNNSGraphContextSetBatchSize = @extern(*const fn (
    context: bnns_graph_context_t,
    function: ?[*:0]const u8,
    batch_size: u64,
) callconv(.c) c_int, .{ .name = "BNNSGraphContextSetBatchSize_v2" });

pub extern fn BNNSGraphContextSetArgumentType(context: bnns_graph_context_t, argument_type: BNNSGraphArgumentType) c_int;

/// Header name and symbol agree here, but the header still spells out an
/// `__asm__` clause, so it is declared the same way as its neighbours.
pub const BNNSGraphContextEnableNanAndInfChecks = @extern(*const fn (
    context: bnns_graph_context_t,
    enable_check_for_nans_inf: bool,
) callconv(.c) void, .{ .name = "BNNSGraphContextEnableNanAndInfChecks" });

pub extern fn BNNSGraphContextSetStreamingAdvanceCount(context: bnns_graph_context_t, advance_count: usize) c_int;

/// Header name `BNNSGraphContextExecute`; symbol
/// `_BNNSGraphContextExecute_v2`.
pub const BNNSGraphContextExecute = @extern(*const fn (
    context: bnns_graph_context_t,
    function: ?[*:0]const u8,
    argument_count: usize,
    arguments: [*]bnns_graph_argument_t,
    workspace_size: usize,
    workspace: ?[*]u8,
) callconv(.c) c_int, .{ .name = "BNNSGraphContextExecute_v2" });

/// Header name `BNNSGraphContextGetWorkspaceSize`; symbol
/// `_BNNSGraphContextGetWorkspaceSize_v2`.
pub const BNNSGraphContextGetWorkspaceSize = @extern(*const fn (
    context: bnns_graph_context_t,
    function: ?[*:0]const u8,
) callconv(.c) usize, .{ .name = "BNNSGraphContextGetWorkspaceSize_v2" });

pub extern fn BNNSGraphContextGetTensor(context: bnns_graph_context_t, function: ?[*:0]const u8, argument: [*:0]const u8, fill_known_dynamic_shapes: bool, tensor: *Tensor) c_int;

/// Header name `BNNSGraphContextSetWorkspaceAllocationCallback`; symbol
/// `_BNNSGraphContextSetWorkspaceAllocationCallback_v2`.
pub const BNNSGraphContextSetWorkspaceAllocationCallback = @extern(*const fn (
    context: bnns_graph_context_t,
    realloc_fn: bnns_graph_realloc_fn_t,
    free_fn: bnns_graph_free_all_fn_t,
    user_memory_context_size: usize,
    user_memory_context: ?*anyopaque,
) callconv(.c) c_int, .{ .name = "BNNSGraphContextSetWorkspaceAllocationCallback_v2" });

/// Header name `BNNSGraphContextSetOutputAllocationCallback`; symbol
/// `_BNNSGraphContextSetOutputAllocationCallback_v2`.
pub const BNNSGraphContextSetOutputAllocationCallback = @extern(*const fn (
    context: bnns_graph_context_t,
    realloc_fn: bnns_graph_realloc_fn_t,
    free_fn: bnns_graph_free_all_fn_t,
    user_memory_context_size: usize,
    user_memory_context: ?*anyopaque,
) callconv(.c) c_int, .{ .name = "BNNSGraphContextSetOutputAllocationCallback_v2" });

pub extern fn BNNSGraphContextSetMessageLogCallback(context: bnns_graph_context_t, log_callback_fn: bnns_graph_execute_message_fn_t, additional_logging_arguments: ?*bnns_user_message_data_t) c_int;
pub extern fn BNNSGraphContextSetMessageLogMask(context: bnns_graph_context_t, log_level_mask: u32) c_int;

// ============================================================================
// Standalone tensor utilities (bnns.h)
// ============================================================================

pub extern fn BNNSCopy(dest: *NDArrayDescriptor, src: *const NDArrayDescriptor, filter_params: ?*const FilterParameters) c_int;
pub extern fn BNNSTranspose(dest: *NDArrayDescriptor, src: *const NDArrayDescriptor, axis0: usize, axis1: usize, filter_params: ?*const FilterParameters) c_int;

pub extern fn BNNSNDArrayGetDataSize(array: *const NDArrayDescriptor) usize;
pub extern fn BNNSTensorGetAllocationSize(tensor: *const Tensor) usize;
pub extern fn BNNSDataLayoutGetRank(layout: DataLayout) usize;

pub extern fn BNNSDirectApplyReduction(layer_params: *const BNNSLayerParametersReduction, filter_params: ?*const FilterParameters) c_int;
pub extern fn BNNSDirectApplyTopK(K: usize, axis: usize, batch_size: usize, input: *const NDArrayDescriptor, input_batch_stride: usize, best_values: *NDArrayDescriptor, best_values_batch_stride: usize, best_indices: ?*NDArrayDescriptor, best_indices_batch_stride: usize, filter_params: ?*const FilterParameters) c_int;
pub extern fn BNNSDirectApplyInTopK(K: usize, axis: usize, batch_size: usize, input: *const NDArrayDescriptor, input_batch_stride: usize, test_indices: *const NDArrayDescriptor, test_indices_batch_stride: usize, output: *NDArrayDescriptor, output_batch_stride: usize, filter_params: ?*const FilterParameters) c_int;

// ============================================================================
// Random number generation (bnns.h)
// ============================================================================

pub extern fn BNNSCreateRandomGenerator(method: RandomGeneratorMethod, filter_params: ?*const FilterParameters) BNNSRandomGenerator;
pub extern fn BNNSCreateRandomGeneratorWithSeed(method: RandomGeneratorMethod, seed: u64, filter_params: ?*const FilterParameters) BNNSRandomGenerator;
pub extern fn BNNSDestroyRandomGenerator(generator: BNNSRandomGenerator) void;

pub extern fn BNNSRandomGeneratorStateSize(generator: BNNSRandomGenerator) usize;
pub extern fn BNNSRandomGeneratorGetState(generator: BNNSRandomGenerator, state_size: usize, state: ?*anyopaque) c_int;
pub extern fn BNNSRandomGeneratorSetState(generator: BNNSRandomGenerator, state_size: usize, state: ?*anyopaque) c_int;

pub extern fn BNNSRandomFillUniformFloat(generator: BNNSRandomGenerator, desc: *NDArrayDescriptor, a: f32, b: f32) c_int;
pub extern fn BNNSRandomFillUniformInt(generator: BNNSRandomGenerator, desc: *NDArrayDescriptor, a: i64, b: i64) c_int;
pub extern fn BNNSRandomFillNormalFloat(generator: BNNSRandomGenerator, desc: *NDArrayDescriptor, mean: f32, stddev: f32) c_int;
pub extern fn BNNSRandomFillCategoricalFloat(generator: BNNSRandomGenerator, desc: *const NDArrayDescriptor, probabilities: *const NDArrayDescriptor, log_probabilities: bool) c_int;

// ============================================================================
// k-nearest neighbours (bnns.h)
// ============================================================================

pub extern fn BNNSCreateNearestNeighbors(max_n_samples: c_uint, n_features: c_uint, n_neighbors: c_uint, data_type: DataType, filter_params: ?*const FilterParameters) BNNSNearestNeighbors;
pub extern fn BNNSDestroyNearestNeighbors(knn: BNNSNearestNeighbors) void;
pub extern fn BNNSNearestNeighborsLoad(knn: BNNSNearestNeighbors, n_new_samples: c_uint, data_ptr: ?*const anyopaque) c_int;
pub extern fn BNNSNearestNeighborsGetInfo(knn: BNNSNearestNeighbors, sample_number: c_int, indices: ?[*]c_int, distances: ?*anyopaque) c_int;

// ============================================================================
// DEPRECATED layer-filter API (bnns.h)
//
// Everything below this line belongs to the older, pre-graph generation of
// BNNS: you build a network out of individual layer objects
// (`BNNSFilterCreateLayerConvolution`) and then apply them (`BNNSFilterApply`).
// Apple deprecated this entire surface in macOS 15.0 in favour of the Graph
// API (`bnns_graph.h`, bound above and wrapped in `bnns.Graph`). It is bound
// here on purpose, for callers whose deployment target predates the Graph API.
//
// Four layer creators near the top were deprecated earlier still, in macOS
// 11.0, in favour of their `BNNSFilterCreateLayer*` successors — which are
// themselves deprecated in macOS 15.0. `BNNSDirectApplyBroadcastMatMul` was
// deprecated in macOS 13.0 with replacement `BNNSMatMul`.
//
// None of these carry an `__asm__` rename clause in the header, so they are
// plain `extern fn` declarations rather than `@extern`.
// ============================================================================

// -- Layer creation (macOS 15.0 deprecations) --

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerConvolution(layer_params: *const LayerParametersConvolution, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerTransposedConvolution(layer_params: *const LayerParametersConvolution, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerFullyConnected(layer_params: *const LayerParametersFullyConnected, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerPooling(layer_params: *const LayerParametersPooling, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerActivation(layer_params: *const LayerParametersActivation, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
/// `layer_params` is one of the `BNNSLayerParametersLoss*` blocks, chosen by
/// the `function` field it starts with, hence the untyped `const void *`.
pub extern fn BNNSFilterCreateLayerLoss(layer_params: *const anyopaque, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerNormalization(normType: FilterType, layer_params: *const LayerParametersNormalization, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerArithmetic(layer_params: *const LayerParametersArithmetic, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerPermute(layer_params: *const LayerParametersPermute, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerDropout(layer_params: *const LayerParametersDropout, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerPadding(layer_params: *const LayerParametersPadding, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerBroadcastMatMul(layer_params: *const LayerParametersBroadcastMatMul, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerTensorContraction(layer_params: *const LayerParametersTensorContraction, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerGram(layer_params: *const LayerParametersGram, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerResize(layer_params: *const LayerParametersResize, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerMultiheadAttention(layer_params: *const LayerParametersMultiheadAttention, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerReduction(layer_params: *const BNNSLayerParametersReduction, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
/// `filter_type` and `layer_params` are parallel arrays of length
/// `number_of_fused_filters`; each `layer_params[i]` points at the
/// `BNNSLayerParameters*` block matching `filter_type[i]`.
pub extern fn BNNSFilterCreateFusedLayer(number_of_fused_filters: usize, filter_type: [*]const FilterType, layer_params: [*]*const anyopaque, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterCreateLayerEmbedding(layer_params: *const LayerParametersEmbedding, filter_params: ?*const FilterParameters) BNNSFilter;

// -- Layer creation (macOS 11.0 deprecations, superseded before macOS 15.0) --

/// Deprecated in macOS 11.0 with replacement `BNNSFilterCreateLayerConvolution`
/// (which is itself deprecated in macOS 15.0; prefer the Graph API).
pub extern fn BNNSFilterCreateConvolutionLayer(in_desc: *const ImageStackDescriptor, out_desc: *const ImageStackDescriptor, layer_params: *const ConvolutionLayerParameters, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 11.0 with replacement `BNNSFilterCreateLayerFullyConnected`
/// (which is itself deprecated in macOS 15.0; prefer the Graph API).
pub extern fn BNNSFilterCreateFullyConnectedLayer(in_desc: *const VectorDescriptor, out_desc: *const VectorDescriptor, layer_params: *const FullyConnectedLayerParameters, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 11.0 with replacement `BNNSFilterCreateLayerPooling`
/// (which is itself deprecated in macOS 15.0; prefer the Graph API).
pub extern fn BNNSFilterCreatePoolingLayer(in_desc: *const ImageStackDescriptor, out_desc: *const ImageStackDescriptor, layer_params: *const PoolingLayerParameters, filter_params: ?*const FilterParameters) BNNSFilter;

/// Deprecated in macOS 11.0 with replacement `BNNSFilterCreateLayerActivation`
/// (which is itself deprecated in macOS 15.0; prefer the Graph API).
pub extern fn BNNSFilterCreateVectorActivationLayer(in_desc: *const VectorDescriptor, out_desc: *const VectorDescriptor, activation: *const Activation, filter_params: ?*const FilterParameters) BNNSFilter;

// -- Filter application (inference) --

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterApply(filter: BNNSFilter, in: *const anyopaque, out: *anyopaque) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterApplyBatch(filter: BNNSFilter, batch_size: usize, in: *const anyopaque, in_stride: usize, out: *anyopaque, out_stride: usize) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterApplyTwoInput(filter: BNNSFilter, inA: *const anyopaque, inB: *const anyopaque, out: *anyopaque) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterApplyTwoInputBatch(filter: BNNSFilter, batch_size: usize, inA: *const anyopaque, inA_stride: usize, inB: *const anyopaque, inB_stride: usize, out: *anyopaque, out_stride: usize) c_int;

// -- Filter application (training / backward) --

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterApplyBackwardBatch(filter: BNNSFilter, batch_size: usize, in: ?*const anyopaque, in_stride: usize, in_delta: ?*NDArrayDescriptor, in_delta_stride: usize, out: ?*const anyopaque, out_stride: usize, out_delta: *const NDArrayDescriptor, out_delta_stride: usize, weights_delta: ?*NDArrayDescriptor, bias_delta: ?*NDArrayDescriptor) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterApplyBackwardTwoInputBatch(filter: BNNSFilter, batch_size: usize, inA: ?*const anyopaque, inA_stride: usize, inA_delta: ?*NDArrayDescriptor, inA_delta_stride: usize, inB: ?*const anyopaque, inB_stride: usize, inB_delta: ?*NDArrayDescriptor, inB_delta_stride: usize, out: ?*const anyopaque, out_stride: usize, out_delta: *const NDArrayDescriptor, out_delta_stride: usize, weights_delta: ?*NDArrayDescriptor, bias_delta: ?*NDArrayDescriptor) c_int;

// -- Fused filter application --

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFusedFilterApplyBatch(filter: BNNSFilter, batch_size: usize, in: *const anyopaque, in_stride: usize, out: *anyopaque, out_stride: usize, training: bool) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
/// `in` and `in_stride` are arrays of `number_of_inputs` entries.
pub extern fn BNNSFusedFilterApplyMultiInputBatch(filter: BNNSFilter, batch_size: usize, number_of_inputs: usize, in: [*]*const anyopaque, in_stride: [*]const usize, out: *anyopaque, out_stride: usize, training: bool) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
/// `delta_parameters` is an array of descriptor pointers, one per trainable
/// parameter of the fused filter; individual entries may be null.
pub extern fn BNNSFusedFilterApplyBackwardBatch(filter: BNNSFilter, batch_size: usize, in: ?*const anyopaque, in_stride: usize, in_delta: ?*NDArrayDescriptor, in_delta_stride: usize, out: ?*const anyopaque, out_stride: usize, out_delta: *NDArrayDescriptor, out_delta_stride: usize, delta_parameters: ?[*]?*NDArrayDescriptor) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFusedFilterApplyBackwardMultiInputBatch(filter: BNNSFilter, batch_size: usize, number_of_inputs: usize, in: ?[*]?*const anyopaque, in_stride: ?[*]const usize, in_delta: [*]*NDArrayDescriptor, in_delta_stride: [*]const usize, out: ?*const anyopaque, out_stride: usize, out_delta: *NDArrayDescriptor, out_delta_stride: usize, delta_parameters: ?[*]?*NDArrayDescriptor) c_int;

// -- Filter teardown and introspection --

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSFilterDestroy(filter: BNNSFilter) void;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
/// Returns the descriptor BY VALUE (C: `BNNSNDArrayDescriptor BNNSGetPointer(...)`).
pub extern fn BNNSGetPointer(filter: BNNSFilter, target: PointerSpecifier) NDArrayDescriptor;

// -- Tensor ops (bnns.h) --

/// `BNNSMatMulWorkspaceSize` — bytes of workspace `BNNSMatMul` wants, or a
/// negative value on failure (returns `ssize_t`, not `size_t`).
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSMatMulWorkspaceSize(transA: bool, transB: bool, alpha: f32, inputA: *const NDArrayDescriptor, inputB: *const NDArrayDescriptor, output: *const NDArrayDescriptor, filter_params: ?*const FilterParameters) isize;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSMatMul(transA: bool, transB: bool, alpha: f32, inputA: *const NDArrayDescriptor, inputB: *const NDArrayDescriptor, output: *const NDArrayDescriptor, workspace: ?*anyopaque, filter_params: ?*const FilterParameters) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSCompareTensor(in0: *const NDArrayDescriptor, in1: *const NDArrayDescriptor, op: RelationalOperator, out: *NDArrayDescriptor) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSTile(input: *const NDArrayDescriptor, output: *NDArrayDescriptor, filter_params: ?*const FilterParameters) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSTileBackward(in_delta: *NDArrayDescriptor, out_delta: *const NDArrayDescriptor, filter_params: ?*const FilterParameters) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSGather(axis: usize, input: *const NDArrayDescriptor, indices: *const NDArrayDescriptor, output: *NDArrayDescriptor, filter_params: ?*const FilterParameters) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSScatter(axis: usize, op: ReduceFunction, input: *const NDArrayDescriptor, indices: *const NDArrayDescriptor, output: *NDArrayDescriptor, filter_params: ?*const FilterParameters) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSGatherND(input: *const NDArrayDescriptor, indices: *const NDArrayDescriptor, output: *NDArrayDescriptor, filter_params: ?*const FilterParameters) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSScatterND(op: ReduceFunction, input: *const NDArrayDescriptor, indices: *const NDArrayDescriptor, output: *NDArrayDescriptor, filter_params: ?*const FilterParameters) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSShuffle(@"type": ShuffleType, input: *const NDArrayDescriptor, output: *NDArrayDescriptor, filter_params: ?*const FilterParameters) c_int;

/// `num_lower` / `num_upper` are C `int`; negative means "the whole triangle".
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSBandPart(num_lower: c_int, num_upper: c_int, input: *const NDArrayDescriptor, output: *NDArrayDescriptor, filter_params: ?*const FilterParameters) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSCropResize(layer_params: *const LayerParametersCropResize, input: *const NDArrayDescriptor, roi: *const NDArrayDescriptor, output: *NDArrayDescriptor, filter_params: ?*const FilterParameters) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSCropResizeBackward(layer_params: *const LayerParametersCropResize, in_delta: *NDArrayDescriptor, roi: *const NDArrayDescriptor, out_delta: *const NDArrayDescriptor, filter_params: ?*const FilterParameters) c_int;

// -- Optimizer, clipping and norms (bnns.h) --

/// `OptimizerAlgFields` points at the `BNNSOptimizer*Fields` struct matching
/// `function`. `accumulators` may be null for optimizers that keep no state.
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSOptimizerStep(function: OptimizerFunction, OptimizerAlgFields: *const anyopaque, number_of_parameters: usize, parameters: [*]*NDArrayDescriptor, gradients: [*]*const NDArrayDescriptor, accumulators: ?[*]?*NDArrayDescriptor, filter_params: ?*const FilterParameters) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSClipByValue(dest: *NDArrayDescriptor, src: *const NDArrayDescriptor, min_val: f32, max_val: f32) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSClipByNorm(dest: *NDArrayDescriptor, src: *const NDArrayDescriptor, max_norm: f32, axis_flags: u32) c_int;

/// `dest` and `src` are arrays of `count` descriptor pointers.
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSClipByGlobalNorm(dest: [*]*NDArrayDescriptor, src: [*]*const NDArrayDescriptor, count: usize, max_norm: f32, use_norm: f32) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSComputeNorm(dest: *NDArrayDescriptor, src: *const NDArrayDescriptor, norm_type: NormType, axis_flags: u32) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSComputeNormBackward(in: *const anyopaque, in_delta: *NDArrayDescriptor, out: *const anyopaque, out_delta: *const NDArrayDescriptor, norm_type: NormType, axis_flags: u32) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSNDArrayFullyConnectedSparsifySparseCOO(in_dense_shape: *const NDArrayDescriptor, in_indices: *const NDArrayDescriptor, in_values: *const NDArrayDescriptor, out: *NDArrayDescriptor, sparse_params: ?*const SparsityParameters, batch_size: usize, workspace: ?*anyopaque, workspace_size: usize, filter_params: ?*const FilterParameters) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSNDArrayFullyConnectedSparsifySparseCSR(in_dense_shape: *const NDArrayDescriptor, in_column_indices: *const NDArrayDescriptor, in_row_starts: *const NDArrayDescriptor, in_values: *const NDArrayDescriptor, out: *NDArrayDescriptor, sparse_params: ?*const SparsityParameters, batch_size: usize, workspace: ?*anyopaque, workspace_size: usize, filter_params: ?*const FilterParameters) c_int;

// -- Sequence models: LSTM and multihead attention (bnns.h) --

/// Minimum training-cache size in bytes for `BNNSDirectApplyLSTMBatchTrainingCaching`.
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSComputeLSTMTrainingCacheCapacity(layer_params: *const LayerParametersLSTM) usize;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSDirectApplyLSTMBatchTrainingCaching(layer_params: *const LayerParametersLSTM, filter_params: ?*const FilterParameters, training_cache_ptr: ?*anyopaque, training_cache_capacity: usize) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSDirectApplyLSTMBatchBackward(layer_params: *const LayerParametersLSTM, layer_delta_params: *const LayerParametersLSTM, filter_params: ?*const FilterParameters, training_cache_ptr: ?*const anyopaque, training_cache_capacity: usize) c_int;

/// 17 parameters. `backprop_cache_size` and `workspace_size` are in/out
/// `size_t *`: pass a pointer with the buffer size, or null.
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSApplyMultiheadAttention(F: BNNSFilter, batch_size: usize, query: *const anyopaque, query_stride: usize, key: *const anyopaque, key_stride: usize, key_mask: ?*const NDArrayDescriptor, key_mask_stride: usize, value: *const anyopaque, value_stride: usize, output: *anyopaque, output_stride: usize, add_to_attention: ?*const NDArrayDescriptor, backprop_cache_size: ?*usize, backprop_cache: ?*anyopaque, workspace_size: ?*usize, workspace: ?*anyopaque) c_int;

/// 23 parameters. Note `backprop_cache_size` here is a `size_t` BY VALUE, while
/// `workspace_size` is still a `size_t *`.
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSApplyMultiheadAttentionBackward(F: BNNSFilter, batch_size: usize, query: ?*const anyopaque, query_stride: usize, query_param_delta: ?*MHAProjectionParameters, key: ?*const anyopaque, key_stride: usize, key_mask: ?*const NDArrayDescriptor, key_mask_stride: usize, key_param_delta: ?*MHAProjectionParameters, value: ?*const anyopaque, value_stride: usize, value_param_delta: ?*MHAProjectionParameters, add_to_attention: ?*const NDArrayDescriptor, key_attn_bias_delta: ?*NDArrayDescriptor, value_attn_bias_delta: ?*NDArrayDescriptor, output: ?*const anyopaque, output_stride: usize, output_param_delta: *MHAProjectionParameters, backprop_cache_size: usize, backprop_cache: ?*anyopaque, workspace_size: ?*usize, workspace: ?*anyopaque) c_int;

// -- Specialized per-layer batch apply (bnns.h) --

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSPoolingFilterApplyBatch(filter: BNNSFilter, batch_size: usize, in: *const anyopaque, in_stride: usize, out: *anyopaque, out_stride: usize, indices: ?[*]usize, idx_stride: usize) c_int;

/// Same as `BNNSPoolingFilterApplyBatch` but the max-pool indices may be
/// `uint64_t` or `uint32_t`, selected by `indices_data_type`.
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSPoolingFilterApplyBatchEx(filter: BNNSFilter, batch_size: usize, in: *const anyopaque, in_stride: usize, out: *anyopaque, out_stride: usize, indices_data_type: DataType, indices: ?*anyopaque, idx_stride: usize) c_int;

/// 13 parameters.
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSPoolingFilterApplyBackwardBatch(filter: BNNSFilter, batch_size: usize, in: ?*const anyopaque, in_stride: usize, in_delta: ?*NDArrayDescriptor, in_delta_stride: usize, out: ?*const anyopaque, out_stride: usize, out_delta: *NDArrayDescriptor, out_delta_stride: usize, bias_delta: ?*NDArrayDescriptor, indices: ?[*]const usize, idx_stride: usize) c_int;

/// 14 parameters — one more than `BNNSPoolingFilterApplyBackwardBatch`, the
/// extra one being `indices_data_type` immediately before `indices`.
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSPoolingFilterApplyBackwardBatchEx(filter: BNNSFilter, batch_size: usize, in: ?*const anyopaque, in_stride: usize, in_delta: ?*NDArrayDescriptor, in_delta_stride: usize, out: ?*const anyopaque, out_stride: usize, out_delta: *NDArrayDescriptor, out_delta_stride: usize, bias_delta: ?*NDArrayDescriptor, indices_data_type: DataType, indices: ?*const anyopaque, idx_stride: usize) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSNormalizationFilterApplyBatch(filter: BNNSFilter, batch_size: usize, in: *const anyopaque, in_stride: usize, out: *anyopaque, out_stride: usize, training: bool) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSNormalizationFilterApplyBackwardBatch(filter: BNNSFilter, batch_size: usize, in_delta: ?*NDArrayDescriptor, in_delta_stride: usize, out: ?*const anyopaque, out_stride: usize, out_delta: *NDArrayDescriptor, out_delta_stride: usize, beta_delta: ?*NDArrayDescriptor, gamma_delta: ?*NDArrayDescriptor) c_int;

/// `in` is an array of `number_of_inputs` input pointers, `in_stride` the
/// matching array of strides.
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSArithmeticFilterApplyBatch(filter: BNNSFilter, batch_size: usize, number_of_inputs: usize, in: [*]const *const anyopaque, in_stride: [*]const usize, out: *anyopaque, out_stride: usize) c_int;

/// 11 parameters. `in` / `in_stride` are nullable arrays of `number_of_inputs`
/// entries; `in_delta` / `in_delta_stride` are non-null arrays of the same length.
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSArithmeticFilterApplyBackwardBatch(filter: BNNSFilter, batch_size: usize, number_of_inputs: usize, in: ?[*]const ?*const anyopaque, in_stride: ?[*]const usize, in_delta: [*]*NDArrayDescriptor, in_delta_stride: [*]const usize, out: ?*const anyopaque, out_stride: usize, out_delta: *NDArrayDescriptor, out_delta_stride: usize) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSPermuteFilterApplyBackwardBatch(filter: BNNSFilter, batch_size: usize, in_delta: *NDArrayDescriptor, in_delta_stride: usize, out_delta: *const NDArrayDescriptor, out_delta_stride: usize) c_int;

/// 11 parameters. `weights_size` is a count, not a pointer.
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSLossFilterApplyBatch(filter: BNNSFilter, batch_size: usize, in: *const anyopaque, in_stride: usize, labels: *const anyopaque, labels_stride: usize, weights: ?*const anyopaque, weights_size: usize, out: *anyopaque, in_delta: ?*NDArrayDescriptor, in_delta_stride: usize) c_int;

/// 12 parameters.
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSLossFilterApplyBackwardBatch(filter: BNNSFilter, batch_size: usize, in: *const anyopaque, in_stride: usize, in_delta: *NDArrayDescriptor, in_delta_stride: usize, labels: *const anyopaque, labels_stride: usize, weights: ?*const anyopaque, weights_size: usize, out_delta: *const NDArrayDescriptor, out_delta_stride: usize) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSDirectApplyActivationBatch(layer_params: *const LayerParametersActivation, filter_params: ?*const FilterParameters, batch_size: usize, in_stride: usize, out_stride: usize) c_int;

/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub extern fn BNNSDirectApplyQuantizer(layer_params: *const LayerParametersQuantization, filter_params: ?*const FilterParameters, batch_size: usize, input_stride: usize, output_stride: usize) c_int;

/// Returns `void`, not `int` — there is no status to check.
/// Deprecated in macOS 13.0 with replacement `BNNSMatMul`.
pub extern fn BNNSDirectApplyBroadcastMatMul(transA: bool, transB: bool, alpha: f32, inputA: *const NDArrayDescriptor, inputB: *const NDArrayDescriptor, output: *const NDArrayDescriptor, filter_params: ?*const FilterParameters) void;

test "every declared BNNS symbol resolves and links" {
    // Forces the linker to resolve every declaration in this file. Catches a
    // misspelled symbol name — notably the eleven `_v2` renames, which would
    // silently be wrong if declared under their header spelling. It does NOT
    // catch a wrong signature: those link cleanly and misbehave at runtime.
    const std = @import("std");
    var sink: usize = 0;
    inline for (@typeInfo(@This()).@"struct".decls) |decl| {
        const field = @field(@This(), decl.name);
        const Info = @typeInfo(@TypeOf(field));
        if (Info == .@"fn") {
            sink +%= @intFromPtr(&field);
        } else if (Info == .pointer and @typeInfo(Info.pointer.child) == .@"fn") {
            sink +%= @intFromPtr(field);
        }
    }
    try std.testing.expect(sink != 0);
}
