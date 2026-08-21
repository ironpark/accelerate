//! The BNNS Graph API: compile a Core ML model to a `Graph`, wrap it in a
//! `Context`, and execute it.
//!
//! This replaced the layer-filter API that Apple deprecated in macOS 15.0. The
//! shape of a session is:
//!
//! ```zig
//! var opts = try CompileOptions.init();
//! defer opts.deinit();
//! opts.setTargetSingleThread(true);
//!
//! var graph = try Graph.compileFromFile("model.mlmodelc", null, opts);
//! defer graph.deinit();          // plain free(), or munmap if compiled to a file
//!
//! var ctx = try Context.init(graph);
//! defer ctx.deinit();
//!
//! const ws = try testing.allocator.alloc(u8, try ctx.workspaceSize(null));
//! defer testing.allocator.free(ws);
//! try ctx.execute(null, arguments, ws);
//! ```
//!
//! Two lifetime rules BNNS does not enforce:
//! * a `Graph` must outlive every `Context` made from it;
//! * a `Graph` is released with `free`, or `munmap` if
//!   `CompileOptions.setOutputPath`/`setOutputFD` sent it straight to a file.
//!   `Graph.deinit` handles the `free` case; the mmap case is the caller's,
//!   because only the caller knows which was used.
//!
//! Note also that the input to `compileFromFile` is a *compiled* Core ML model
//! directory (`.mlmodelc`), not an `.mlmodel` or `.mlpackage`.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const Tensor = types.Tensor;
const Error = types.Error;
const check = types.check;
const checkSize = types.checkSize;

/// `BNNSGraphOptimizationPreference`.
pub const OptimizationPreference = c.BNNSGraphOptimizationPreference;
/// `BNNSGraphArgumentIntent`.
pub const ArgumentIntent = c.BNNSGraphArgumentIntent;
/// `BNNSGraphArgumentType`.
pub const ArgumentType = c.BNNSGraphArgumentType;
/// `BNNSGraphMessageLevel`. The log-mask setters take a bitwise OR of these.
pub const MessageLevel = c.BNNSGraphMessageLevel;
/// `bnns_graph_argument_t`.
pub const Argument = c.bnns_graph_argument_t;
/// `bnns_graph_shape_t`.
pub const Shape = c.bnns_graph_shape_t;
/// `bnns_user_message_data_t`.
pub const UserMessageData = c.bnns_user_message_data_t;
/// `bnns_graph_realloc_fn_t`.
pub const ReallocFn = c.bnns_graph_realloc_fn_t;
/// `bnns_graph_free_all_fn_t`.
pub const FreeAllFn = c.bnns_graph_free_all_fn_t;
/// `bnns_graph_compile_message_fn_t`.
pub const CompileMessageFn = c.bnns_graph_compile_message_fn_t;
/// `bnns_graph_execute_message_fn_t`.
pub const ExecuteMessageFn = c.bnns_graph_execute_message_fn_t;

/// The default set of message levels BNNS logs: unsupported, warning and error.
/// Info is off.
pub const default_message_log_mask: u32 =
    @intFromEnum(MessageLevel.unsupported) |
    @intFromEnum(MessageLevel.warning) |
    @intFromEnum(MessageLevel.err);

// ============================================================================
// Compile options
// ============================================================================

/// `bnns_graph_compile_options_t` — options for `Graph.compileFromFile`.
pub const CompileOptions = struct {
    handle: c.bnns_graph_compile_options_t,

    /// `BNNSGraphCompileOptionsMakeDefault`.
    pub fn init() Error!CompileOptions {
        const h = c.BNNSGraphCompileOptionsMakeDefault();
        if (h.data == null) return Error.BnnsAllocationFailed;
        return .{ .handle = h };
    }

    /// `BNNSGraphCompileOptionsDestroy`.
    pub fn deinit(self: *CompileOptions) void {
        c.BNNSGraphCompileOptionsDestroy(self.handle);
        self.handle = .{};
    }

    /// Compile the graph to run on a single thread. Default is multi-threaded.
    pub fn setTargetSingleThread(self: CompileOptions, value: bool) void {
        c.BNNSGraphCompileOptionsSetTargetSingleThread(self.handle, value);
    }

    pub fn getTargetSingleThread(self: CompileOptions) bool {
        return c.BNNSGraphCompileOptionsGetTargetSingleThread(self.handle);
    }

    /// Include debug info in the compiled graph. Default is not to.
    pub fn setGenerateDebugInfo(self: CompileOptions, value: bool) void {
        c.BNNSGraphCompileOptionsSetGenerateDebugInfo(self.handle, value);
    }

    pub fn getGenerateDebugInfo(self: CompileOptions) bool {
        return c.BNNSGraphCompileOptionsGetGenerateDebugInfo(self.handle);
    }

    /// Trade execute performance against the on-disk size of the compiled
    /// graph. Default is `.performance`.
    pub fn setOptimizationPreference(self: CompileOptions, preference: OptimizationPreference) void {
        c.BNNSGraphCompileOptionsSetOptimizationPreference(self.handle, preference);
    }

    pub fn getOptimizationPreference(self: CompileOptions) OptimizationPreference {
        return c.BNNSGraphCompileOptionsGetOptimizationPreference(self.handle);
    }

    /// Write the compiled graph straight to `path` instead of holding it all in
    /// memory. The file is created with mode 0600, and the resulting `Graph` is
    /// a read-only mmap — release it with `munmap`, not `Graph.deinit`.
    ///
    /// Pass null to go back to compiling in memory. Ignored if a file
    /// descriptor was set with `setOutputFD`.
    pub fn setOutputPath(self: CompileOptions, path: ?[*:0]const u8) void {
        c.BNNSGraphCompileOptionsSetOutputPath(self.handle, path);
    }

    /// The path set by `setOutputPath`, or null. The returned pointer is owned
    /// by the options object.
    pub fn getOutputPath(self: CompileOptions) ?[*:0]const u8 {
        return c.BNNSGraphCompileOptionsGetOutputPath(self.handle);
    }

    /// As `setOutputPath`, but to an already-open descriptor, which is
    /// truncated and overwritten. Overrides any output path. Pass -1 to reset.
    pub fn setOutputFD(self: CompileOptions, fd: c_int) void {
        c.BNNSGraphCompileOptionsSetOutputFD(self.handle, fd);
    }

    /// The descriptor set by `setOutputFD`, or -1.
    pub fn getOutputFD(self: CompileOptions) c_int {
        return c.BNNSGraphCompileOptionsGetOutputFD(self.handle);
    }

    /// Route compile-time diagnostics to `callback` instead of `os_log`.
    pub fn setMessageLogCallback(self: CompileOptions, callback: CompileMessageFn, user_data: ?*UserMessageData) void {
        c.BNNSGraphCompileOptionsSetMessageLogCallback(self.handle, callback, user_data);
    }

    /// Bitwise OR of `MessageLevel` values to report.
    pub fn setMessageLogMask(self: CompileOptions, mask: u32) void {
        c.BNNSGraphCompileOptionsSetMessageLogMask(self.handle, mask);
    }
};

// ============================================================================
// Graph
// ============================================================================

/// `bnns_graph_t` — a compiled graph, plus the queries over its signature.
pub const Graph = struct {
    handle: c.bnns_graph_t,

    /// Compile a `.mlmodelc` directory into a graph.
    ///
    /// `BNNSGraphCompileFromFile` (symbol `_BNNSGraphCompileFromFile_v2`).
    /// `function` selects a single function from the source; pass null or the
    /// empty string to compile all of them. `options` may be a default-
    /// constructed `CompileOptions{}` to accept BNNS's defaults.
    ///
    /// BNNS reports failure as a null `data` pointer and sends the reason to
    /// the message log, so the error here carries no detail. Install a callback
    /// with `CompileOptions.setMessageLogCallback` to see why.
    pub fn compileFromFile(filename: [*:0]const u8, function: ?[*:0]const u8, options: CompileOptions) Error!Graph {
        const h = c.BNNSGraphCompileFromFile(filename, function, options.handle);
        if (h.data == null) return Error.BnnsAllocationFailed;
        return .{ .handle = h };
    }

    /// Release a graph that was compiled in memory.
    ///
    /// The header specifies `free()`. If the graph was compiled straight to a
    /// file via `CompileOptions.setOutputPath` or `setOutputFD`, it is an mmap
    /// instead and must be released with `munmap` — do not call this.
    pub fn deinit(self: *Graph) void {
        if (self.handle.data) |p| std.c.free(p);
        self.handle = .{};
    }

    /// Number of input arguments of `function`.
    ///
    /// `BNNSGraphGetInputCount`. Pass null for `function` when the graph has
    /// only one. Failure is reported as `SIZE_MAX`, which `checkSize` turns
    /// into an error.
    pub fn inputCount(self: Graph, function: ?[*:0]const u8) Error!usize {
        return checkSize(c.BNNSGraphGetInputCount(self.handle, function));
    }

    /// `BNNSGraphGetOutputCount`.
    pub fn outputCount(self: Graph, function: ?[*:0]const u8) Error!usize {
        return checkSize(c.BNNSGraphGetOutputCount(self.handle, function));
    }

    /// `BNNSGraphGetArgumentCount` — the sum of `inputCount` and `outputCount`.
    pub fn argumentCount(self: Graph, function: ?[*:0]const u8) Error!usize {
        return checkSize(c.BNNSGraphGetArgumentCount(self.handle, function));
    }

    /// `BNNSGraphGetFunctionCount` — number of callable functions.
    pub fn functionCount(self: Graph) Error!usize {
        return checkSize(c.BNNSGraphGetFunctionCount(self.handle));
    }

    /// Fill `names` with the input argument names.
    ///
    /// `BNNSGraphGetInputNames` (symbol `_BNNSGraphGetInputNames_v2`). Each
    /// pointer is read-only and owned by the graph. Only the first
    /// `min(inputCount, names.len)` entries are written.
    pub fn inputNames(self: Graph, function: ?[*:0]const u8, names: []?[*:0]const u8) Error!void {
        return check(c.BNNSGraphGetInputNames(self.handle, function, names.len, names.ptr));
    }

    /// `BNNSGraphGetOutputNames` (symbol `_BNNSGraphGetOutputNames_v2`).
    pub fn outputNames(self: Graph, function: ?[*:0]const u8, names: []?[*:0]const u8) Error!void {
        return check(c.BNNSGraphGetOutputNames(self.handle, function, names.len, names.ptr));
    }

    /// `BNNSGraphGetArgumentNames` — the outputs followed by the inputs.
    pub fn argumentNames(self: Graph, function: ?[*:0]const u8, names: []?[*:0]const u8) Error!void {
        return check(c.BNNSGraphGetArgumentNames(self.handle, function, names.len, names.ptr));
    }

    /// `BNNSGraphGetFunctionNames`.
    pub fn functionNames(self: Graph, names: []?[*:0]const u8) Error!void {
        return check(c.BNNSGraphGetFunctionNames(self.handle, names.len, names.ptr));
    }

    /// Fill `intents` with each argument's direction.
    ///
    /// `BNNSGraphGetArgumentIntents`.
    pub fn argumentIntents(self: Graph, function: ?[*:0]const u8, intents: []ArgumentIntent) Error!void {
        return check(c.BNNSGraphGetArgumentIntents(self.handle, function, intents.len, intents.ptr));
    }

    /// Index of `argument` in the array passed to `Context.execute`.
    ///
    /// `BNNSGraphGetArgumentPosition`. This is how a caller maps a name to a
    /// slot without depending on declaration order.
    pub fn argumentPosition(self: Graph, function: ?[*:0]const u8, argument: [*:0]const u8) Error!usize {
        return checkSize(c.BNNSGraphGetArgumentPosition(self.handle, function, argument));
    }

    /// Fill `interleave` with pointers to each argument's interleave factors,
    /// and `counts` with their lengths.
    ///
    /// `BNNSGraphGetArgumentInterleaveFactors`. An argument with no interleave
    /// factor gets a null pointer and a count of 0. Both slices must be the
    /// same length.
    pub fn argumentInterleaveFactors(
        self: Graph,
        function: ?[*:0]const u8,
        interleave: []?[*]const u16,
        counts: []usize,
    ) Error!void {
        std.debug.assert(interleave.len == counts.len);
        return check(c.BNNSGraphGetArgumentInterleaveFactors(self.handle, function, interleave.len, interleave.ptr, counts.ptr));
    }

    /// Fill in `tensor`'s strides from the graph's declaration of `argument`.
    ///
    /// `BNNSGraphTensorFillStrides`.
    pub fn fillTensorStrides(self: Graph, function: ?[*:0]const u8, argument: [*:0]const u8, tensor: *Tensor) Error!void {
        return check(c.BNNSGraphTensorFillStrides(self.handle, function, argument, tensor));
    }
};

// ============================================================================
// Context
// ============================================================================

/// `bnns_graph_context_t` — mutable execution state around a `Graph`.
///
/// The graph must outlive the context.
pub const Context = struct {
    handle: c.bnns_graph_context_t,

    /// `BNNSGraphContextMake`.
    pub fn init(graph: Graph) Error!Context {
        const h = c.BNNSGraphContextMake(graph.handle);
        if (h.data == null) return Error.BnnsAllocationFailed;
        return .{ .handle = h };
    }

    /// Create a context for a model compiled with `StateMode=Streaming`.
    ///
    /// `BNNSGraphContextMakeStreaming`. In addition to the usual work, this
    /// allocates ring-buffer storage for every in-out (Core ML `state`)
    /// argument, and `execute` then ignores caller-supplied pointers for those
    /// arguments and rewrites them to point into the ring buffer.
    pub fn initStreaming(graph: Graph, function: ?[*:0]const u8, initial_states: ?[]const Tensor) Error!Context {
        const count = if (initial_states) |s| s.len else 0;
        const ptr = if (initial_states) |s| s.ptr else null;
        const h = c.BNNSGraphContextMakeStreaming(graph.handle, function, count, ptr);
        if (h.data == null) return Error.BnnsAllocationFailed;
        return .{ .handle = h };
    }

    /// `BNNSGraphContextDestroy` (symbol `_BNNSGraphContextDestroy_v2`).
    pub fn deinit(self: *Context) void {
        c.BNNSGraphContextDestroy(self.handle);
        self.handle = .{};
    }

    /// Set the shapes of dynamically shaped arguments.
    ///
    /// `BNNSGraphContextSetDynamicShapes` (symbol `..._v2`). Must be called
    /// before `execute` if the model has dynamic shapes, and `workspaceSize`
    /// must be re-queried afterwards.
    pub fn setDynamicShapes(self: Context, function: ?[*:0]const u8, shapes: []Shape) Error!void {
        return check(c.BNNSGraphContextSetDynamicShapes(self.handle, function, shapes.len, shapes.ptr));
    }

    /// Set the batch size for a model with a dynamic leading dimension.
    ///
    /// `BNNSGraphContextSetBatchSize` (symbol `..._v2`). As with
    /// `setDynamicShapes`, re-query `workspaceSize` afterwards.
    pub fn setBatchSize(self: Context, function: ?[*:0]const u8, batch_size: u64) Error!void {
        return check(c.BNNSGraphContextSetBatchSize(self.handle, function, batch_size));
    }

    /// Choose how `execute` reads the `arguments` array: as raw data pointers
    /// or as `Tensor` pointers.
    ///
    /// `BNNSGraphContextSetArgumentType`. Default is `.pointer`.
    pub fn setArgumentType(self: Context, argument_type: ArgumentType) Error!void {
        return check(c.BNNSGraphContextSetArgumentType(self.handle, argument_type));
    }

    /// Check intermediate results for NaN and infinity during execution.
    ///
    /// `BNNSGraphContextEnableNanAndInfChecks`. Off by default; it costs
    /// performance.
    pub fn enableNanAndInfChecks(self: Context, enable: bool) void {
        c.BNNSGraphContextEnableNanAndInfChecks(self.handle, enable);
    }

    /// `BNNSGraphContextSetStreamingAdvanceCount` — how far the streaming ring
    /// buffer advances per execution. Requires macOS 15.4.
    pub fn setStreamingAdvanceCount(self: Context, advance_count: usize) Error!void {
        return check(c.BNNSGraphContextSetStreamingAdvanceCount(self.handle, advance_count));
    }

    /// Minimum workspace size in bytes for `execute`.
    ///
    /// `BNNSGraphContextGetWorkspaceSize` (symbol `..._v2`). Re-query after any
    /// call that changes shapes. The value is not monotonic in the dynamic
    /// size — a larger batch does not guarantee a larger workspace — so do not
    /// cache a maximum.
    pub fn workspaceSize(self: Context, function: ?[*:0]const u8) Error!usize {
        return checkSize(c.BNNSGraphContextGetWorkspaceSize(self.handle, function));
    }

    /// Run the graph.
    ///
    /// `BNNSGraphContextExecute` (symbol `..._v2`). `arguments` is indexed by
    /// `Graph.argumentPosition`. Pass a `workspace` of at least
    /// `workspaceSize` bytes to avoid any allocation during execution; pass
    /// null to let BNNS allocate.
    ///
    /// A context must not be used by two threads at once.
    pub fn execute(self: Context, function: ?[*:0]const u8, arguments: []Argument, workspace: ?[]u8) Error!void {
        const ws_size = if (workspace) |w| w.len else 0;
        const ws_ptr = if (workspace) |w| w.ptr else null;
        return check(c.BNNSGraphContextExecute(self.handle, function, arguments.len, arguments.ptr, ws_size, ws_ptr));
    }

    /// Describe one of the graph's arguments as a `Tensor`.
    ///
    /// `BNNSGraphContextGetTensor`. Set `fill_known_dynamic_shapes` to have
    /// BNNS substitute any shapes it has been able to deduce. The returned
    /// tensor's `name` points into the graph.
    pub fn getTensor(self: Context, function: ?[*:0]const u8, argument: [*:0]const u8, fill_known_dynamic_shapes: bool) Error!Tensor {
        var t: Tensor = .{ .data_type = .float32 };
        try check(c.BNNSGraphContextGetTensor(self.handle, function, argument, fill_known_dynamic_shapes, &t));
        return t;
    }

    /// Hand workspace allocation to the caller.
    ///
    /// `BNNSGraphContextSetWorkspaceAllocationCallback` (symbol `..._v2`).
    /// `free_fn` is called once at `deinit` to release everything associated
    /// with `user_memory_context`.
    pub fn setWorkspaceAllocationCallback(
        self: Context,
        realloc_fn: ReallocFn,
        free_fn: FreeAllFn,
        user_memory_context_size: usize,
        user_memory_context: ?*anyopaque,
    ) Error!void {
        return check(c.BNNSGraphContextSetWorkspaceAllocationCallback(self.handle, realloc_fn, free_fn, user_memory_context_size, user_memory_context));
    }

    /// As above, for output tensors.
    ///
    /// `BNNSGraphContextSetOutputAllocationCallback` (symbol `..._v2`). If the
    /// same `user_memory_context` pointer is given to both this and the
    /// workspace callback, `free_fn` is called only once.
    pub fn setOutputAllocationCallback(
        self: Context,
        realloc_fn: ReallocFn,
        free_fn: FreeAllFn,
        user_memory_context_size: usize,
        user_memory_context: ?*anyopaque,
    ) Error!void {
        return check(c.BNNSGraphContextSetOutputAllocationCallback(self.handle, realloc_fn, free_fn, user_memory_context_size, user_memory_context));
    }

    /// Route execution-time diagnostics to `callback` instead of `os_log`.
    pub fn setMessageLogCallback(self: Context, callback: ExecuteMessageFn, user_data: ?*UserMessageData) Error!void {
        return check(c.BNNSGraphContextSetMessageLogCallback(self.handle, callback, user_data));
    }

    /// Bitwise OR of `MessageLevel` values to report.
    pub fn setMessageLogMask(self: Context, mask: u32) Error!void {
        return check(c.BNNSGraphContextSetMessageLogMask(self.handle, mask));
    }
};

// ============================================================================
// Tests
//
// Everything downstream of a compiled graph needs a real `.mlmodelc`, which
// this repository does not carry and cannot generate without Core ML Tools. So
// the tests here cover what is reachable without one: the options object, which
// is fully self-contained, and the failure path of compilation.
// ============================================================================

test "CompileOptions round-trips every option it can report back" {
    const testing = std.testing;

    var opts = try CompileOptions.init();
    defer opts.deinit();

    // Documented defaults.
    try testing.expect(!opts.getTargetSingleThread());
    try testing.expect(!opts.getGenerateDebugInfo());
    try testing.expectEqual(OptimizationPreference.performance, opts.getOptimizationPreference());
    try testing.expectEqual(@as(c_int, -1), opts.getOutputFD());
    try testing.expect(opts.getOutputPath() == null);

    opts.setTargetSingleThread(true);
    try testing.expect(opts.getTargetSingleThread());
    opts.setTargetSingleThread(false);
    try testing.expect(!opts.getTargetSingleThread());

    opts.setGenerateDebugInfo(true);
    try testing.expect(opts.getGenerateDebugInfo());

    opts.setOptimizationPreference(.ir_size);
    try testing.expectEqual(OptimizationPreference.ir_size, opts.getOptimizationPreference());
    opts.setOptimizationPreference(.performance);
    try testing.expectEqual(OptimizationPreference.performance, opts.getOptimizationPreference());

    opts.setOutputFD(7);
    try testing.expectEqual(@as(c_int, 7), opts.getOutputFD());
    // -1 resets to compiling in memory.
    opts.setOutputFD(-1);
    try testing.expectEqual(@as(c_int, -1), opts.getOutputFD());
}

test "CompileOptions.setOutputPath stores a copy of the path" {
    const testing = std.testing;

    var opts = try CompileOptions.init();
    defer opts.deinit();

    opts.setOutputPath("/tmp/bnns-graph-output.bnnsir");
    const got = opts.getOutputPath() orelse return error.TestUnexpectedResult;
    try testing.expectEqualStrings("/tmp/bnns-graph-output.bnnsir", std.mem.span(got));

    // Null resets to the in-memory default.
    opts.setOutputPath(null);
    try testing.expect(opts.getOutputPath() == null);
}

test "setMessageLogMask and setMessageLogCallback accept the documented values" {
    const testing = std.testing;

    var opts = try CompileOptions.init();
    defer opts.deinit();

    // There is no getter for either, so this pins that the calls are accepted
    // and that the mask constant matches the header's documented default.
    opts.setMessageLogMask(default_message_log_mask);
    opts.setMessageLogMask(@intFromEnum(MessageLevel.err));
    opts.setMessageLogCallback(null, null);

    try testing.expectEqual(@as(u32, 14), default_message_log_mask);
}

test "compiling a path that does not exist fails rather than crashing" {
    const testing = std.testing;

    var opts = try CompileOptions.init();
    defer opts.deinit();
    // Silence the os_log complaint this is about to provoke.
    opts.setMessageLogMask(0);

    const result = Graph.compileFromFile("/nonexistent/path/to/model.mlmodelc", null, opts);
    try testing.expectError(Error.BnnsAllocationFailed, result);
}

test "MessageLevel and ArgumentType values match the header" {
    const testing = std.testing;

    try testing.expectEqual(@as(u32, 1), @intFromEnum(MessageLevel.info));
    try testing.expectEqual(@as(u32, 2), @intFromEnum(MessageLevel.unsupported));
    try testing.expectEqual(@as(u32, 4), @intFromEnum(MessageLevel.warning));
    try testing.expectEqual(@as(u32, 8), @intFromEnum(MessageLevel.err));

    // The gap is real: BNNSGraphArgumentTypeTensor is 2, not 1.
    try testing.expectEqual(@as(u32, 0), @intFromEnum(ArgumentType.pointer));
    try testing.expectEqual(@as(u32, 2), @intFromEnum(ArgumentType.tensor));

    // in_out is in | out.
    try testing.expectEqual(
        @intFromEnum(ArgumentIntent.in) | @intFromEnum(ArgumentIntent.out),
        @intFromEnum(ArgumentIntent.in_out),
    );
}
