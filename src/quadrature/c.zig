//! C extern declarations for Accelerate's Quadrature (numerical integration).
//!
//! Transcribed from `vecLib/Quadrature/Quadrature.h` and `Integration.h`. The
//! whole library is a single exported symbol, `quadrature_integrate`; unlike
//! `Sparse/Solve.h` there is no inline dispatch layer and nothing overloaded,
//! so these declarations map one-to-one onto the header.

const std = @import("std");

/// `quadrature_status`. Success is 0; every failure is negative.
pub const Status = enum(c_int) {
    success = 0,
    generic_error = -1,
    invalid_arg_error = -2,
    alloc_error = -3,
    internal_error = -99,
    /// The requested accuracy could not be reached within the allowed number
    /// of evaluations or subdivisions.
    integrate_max_eval_error = -101,
    /// Extremely bad integrand behaviour, or excessive roundoff at some point
    /// of the interval.
    integrate_bad_behaviour_error = -102,
    _,
};

/// `quadrature_integrator`.
pub const Integrator = enum(c_int) {
    qng = 0,
    qag = 1,
    qags = 2,
};

/// `quadrature_function_array`.
///
/// The array form is the only form Accelerate offers: one call evaluates the
/// integrand at `n` points. That is deliberate - most of the time in a
/// quadrature run is spent inside this callback, so batching amortizes the
/// indirect call.
pub const FunctionArray = *const fn (
    arg: ?*anyopaque,
    n: usize,
    x: [*]const f64,
    y: [*]f64,
) callconv(.c) void;

/// `quadrature_integrate_function`.
pub const IntegrateFunction = extern struct {
    fun: FunctionArray,
    fun_arg: ?*anyopaque,
};

/// `quadrature_integrate_options`.
pub const IntegrateOptions = extern struct {
    integrator: Integrator,
    abs_tolerance: f64,
    rel_tolerance: f64,
    /// 0, 15, 21, 31, 41, 51 or 61. 0 means the default of 21. QAG only.
    qag_points_per_interval: usize,
    /// Ignored when a workspace is supplied - the workspace size caps the
    /// subdivision instead.
    max_intervals: usize,
};

/// `QUADRATURE_INTEGRATE_QAG_WORKSPACE_PER_INTERVAL`.
pub const qag_workspace_per_interval: usize = 32;
/// `QUADRATURE_INTEGRATE_QAGS_WORKSPACE_PER_INTERVAL`.
pub const qags_workspace_per_interval: usize = 152;

pub extern fn quadrature_integrate(
    f: *const IntegrateFunction,
    a: f64,
    b: f64,
    options: *const IntegrateOptions,
    status: ?*Status,
    abs_error: ?*f64,
    workspace_size: usize,
    workspace: ?*anyopaque,
) f64;

// ============================================================================
// Layout assertions
// ============================================================================

// Reference values taken on macOS 15.4 / arm64 by compiling a
// sizeof/offsetof dump against the real headers. Both structs are passed to
// Accelerate by pointer rather than by value, so drift here is less immediately
// catastrophic than in `sparse`, but it would still silently feed the
// integrator garbage tolerances.
test "ABI struct layouts match the C headers" {
    const expectEqual = std.testing.expectEqual;

    try expectEqual(@as(usize, 16), @sizeOf(IntegrateFunction));
    try expectEqual(@as(usize, 0), @offsetOf(IntegrateFunction, "fun"));
    try expectEqual(@as(usize, 8), @offsetOf(IntegrateFunction, "fun_arg"));

    try expectEqual(@as(usize, 40), @sizeOf(IntegrateOptions));
    try expectEqual(@as(usize, 0), @offsetOf(IntegrateOptions, "integrator"));
    try expectEqual(@as(usize, 8), @offsetOf(IntegrateOptions, "abs_tolerance"));
    try expectEqual(@as(usize, 16), @offsetOf(IntegrateOptions, "rel_tolerance"));
    try expectEqual(@as(usize, 24), @offsetOf(IntegrateOptions, "qag_points_per_interval"));
    try expectEqual(@as(usize, 32), @offsetOf(IntegrateOptions, "max_intervals"));

    try expectEqual(@as(usize, 4), @sizeOf(Status));
    try expectEqual(@as(usize, 4), @sizeOf(Integrator));

    try expectEqual(@as(c_int, 0), @intFromEnum(Integrator.qng));
    try expectEqual(@as(c_int, 1), @intFromEnum(Integrator.qag));
    try expectEqual(@as(c_int, 2), @intFromEnum(Integrator.qags));
    try expectEqual(@as(c_int, -101), @intFromEnum(Status.integrate_max_eval_error));
    try expectEqual(@as(c_int, -102), @intFromEnum(Status.integrate_bad_behaviour_error));
}
