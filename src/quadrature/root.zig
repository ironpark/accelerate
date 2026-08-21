//! Bindings for Accelerate's Quadrature - one-dimensional numerical
//! integration of a real function.
//!
//! ```zig
//! const quadrature = @import("accelerate").quadrature;
//!
//! fn gaussian(_: void, x: f64) f64 {
//!     return @exp(-x * x);
//! }
//!
//! // Integrates to sqrt(pi) over the whole real line.
//! const r = try quadrature.integrateScalar(void, {}, gaussian, -inf, inf, .{
//!     .integrator = .{ .qags = .{} },
//!     .abs_tolerance = 1e-12,
//! }, allocator);
//! // r.value, r.abs_error, r.status
//! ```
//!
//! ## Choosing an integrator
//!
//! Adapted from QUADPACK's decision tree, as the header presents it:
//!
//! * Don't know much about the integrand, and performance is not critical -
//!   **QAGS**.
//! * Smooth integrand - **QNG**, falling back to **QAG** if QNG cannot reach
//!   the tolerance.
//! * Known discontinuities or singularities - split the range at them and
//!   integrate each piece.
//! * End-point singularities - **QAGS**.
//! * Oscillatory with no singularities - **QAG** with `.p61`.
//! * Infinite bounds - **QAGS**, which is the only integrator that accepts
//!   them. (Passing an infinite bound to QAG returns `NaN`; this binding
//!   rejects it up front instead.)
//!
//! ## Errors versus outcomes
//!
//! Failing to reach the requested tolerance is not treated as an error - it
//! comes back as `Result.status`, alongside the partial estimate and the error
//! bound Accelerate computed for it. That distinction matters for an
//! oscillatory integrand, where a result that missed a 1e-14 target by 0.3 is
//! still the answer you have. Genuine failures - an invalid argument, a failed
//! allocation, an internal error - are Zig errors.

const std = @import("std");
const c = @import("c.zig");

pub const Status = c.Status;

/// Genuine failures. Not reaching the requested tolerance is *not* one of
/// these; see `Result.status`.
pub const Error = error{
    /// Accelerate rejected an argument. The wrappers here validate the cases
    /// that are checkable in Zig, so reaching this means something the binding
    /// does not yet know to check.
    InvalidArgument,
    /// Accelerate could not allocate its own workspace.
    OutOfMemory,
    /// A bug in Accelerate, per its own header.
    Internal,
    /// A generic failure with no more specific code.
    Failed,
    /// A status outside the documented set.
    Unknown,
};

/// Number of Gauss-Kronrod points per subinterval, for QAG.
///
/// A closed set: Accelerate rejects anything else with an invalid-argument
/// error, so the enum makes a bad value unrepresentable rather than a runtime
/// failure.
pub const Points = enum(usize) {
    /// Maps to 21.
    default = 0,
    p15 = 15,
    p21 = 21,
    p31 = 31,
    p41 = 41,
    p51 = 51,
    /// Recommended for an oscillatory integrand with no singularities.
    p61 = 61,
};

/// This binding's default subdivision limit for the adaptive integrators.
///
/// Accelerate documents no default, and `max_intervals = 0` is rejected
/// outright (measured: status -2 for both QAG and QAGS), so leaving the field
/// zero-initialized would be a trap. This value is the binding's choice, not
/// Apple's.
pub const default_max_intervals: usize = 64;

/// Which algorithm to run, together with the parameters that algorithm
/// actually uses.
///
/// A tagged union rather than a flat struct so that `points_per_interval`
/// cannot be set on an integrator that ignores it, and so that QNG - which
/// needs no workspace and no subdivision limit - carries neither.
pub const Integrator = union(enum) {
    /// Non-adaptive Gauss-Kronrod-Patterson. Evaluates 21, 43 or 87 points
    /// until the tolerance is met. Needs no workspace.
    qng,
    /// Globally adaptive Gauss-Kronrod.
    qag: struct {
        points_per_interval: Points = .default,
        max_intervals: usize = default_max_intervals,
    },
    /// Globally adaptive with Wynn epsilon-algorithm acceleration. The only
    /// integrator that accepts an infinite bound.
    qags: struct {
        max_intervals: usize = default_max_intervals,
    },

    /// Bytes of scratch space this integrator needs. Zero for QNG.
    pub fn workspaceSize(self: Integrator) usize {
        return switch (self) {
            .qng => 0,
            .qag => |o| o.max_intervals * c.qag_workspace_per_interval,
            .qags => |o| o.max_intervals * c.qags_workspace_per_interval,
        };
    }

    fn maxIntervals(self: Integrator) usize {
        return switch (self) {
            .qng => 0,
            .qag => |o| o.max_intervals,
            .qags => |o| o.max_intervals,
        };
    }
};

pub const Options = struct {
    integrator: Integrator = .{ .qags = .{} },
    /// Requested absolute tolerance. On success Accelerate guarantees
    /// `|S - S'| <= max(abs_tolerance, rel_tolerance * |S|)`.
    abs_tolerance: f64 = 0,
    /// Requested relative tolerance.
    rel_tolerance: f64 = 0,

    fn raw(self: Options) c.IntegrateOptions {
        return .{
            .integrator = switch (self.integrator) {
                .qng => .qng,
                .qag => .qag,
                .qags => .qags,
            },
            .abs_tolerance = self.abs_tolerance,
            .rel_tolerance = self.rel_tolerance,
            .qag_points_per_interval = switch (self.integrator) {
                .qag => |o| @intFromEnum(o.points_per_interval),
                else => 0,
            },
            .max_intervals = self.integrator.maxIntervals(),
        };
    }
};

pub const Result = struct {
    /// The approximation to the integral. May be `NaN` if `status` is not
    /// `.success`.
    value: f64,
    /// Accelerate's estimate of the absolute error on `value`.
    abs_error: f64,
    /// `.success`, or one of the two convergence outcomes:
    /// `.integrate_max_eval_error` (ran out of evaluations or subdivisions) or
    /// `.integrate_bad_behaviour_error`.
    status: Status,

    /// Whether the requested tolerance was reached.
    pub fn converged(self: Result) bool {
        return self.status == .success;
    }
};

/// The vectorized integrand: fill `y[i] = f(x[i])`.
///
/// `y.len == x.len` always. Batching is Accelerate's design, not an
/// afterthought - it is where a vDSP or vForce call belongs.
pub fn ArrayFunction(comptime Context: type) type {
    return *const fn (Context, x: []const f64, y: []f64) void;
}

/// The scalar integrand, for when vectorizing is not worth it.
pub fn ScalarFunction(comptime Context: type) type {
    return *const fn (Context, x: f64) f64;
}

/// What the C callback receives through `fun_arg`.
fn Trampoline(comptime Context: type) type {
    return struct {
        const Self = @This();

        ctx: Context,
        f: ArrayFunction(Context),

        fn invoke(arg: ?*anyopaque, n: usize, x: [*]const f64, y: [*]f64) callconv(.c) void {
            const self: *const Self = @ptrCast(@alignCast(arg.?));
            self.f(self.ctx, x[0..n], y[0..n]);
        }
    };
}

fn ScalarTrampoline(comptime Context: type) type {
    return struct {
        ctx: Context,
        f: ScalarFunction(Context),

        fn apply(self: *const @This(), x: []const f64, y: []f64) void {
            for (x, y) |xi, *yi| yi.* = self.f(self.ctx, xi);
        }
    };
}

fn validate(a: f64, b: f64, options: Options) Error!void {
    // Only QAGS accepts an infinite bound. QNG reports an invalid argument,
    // but QAG returns NaN with a max-eval status, which is a bad way to find
    // out - so reject both here.
    const infinite = std.math.isInf(a) or std.math.isInf(b);
    if (infinite and options.integrator != .qags) return Error.InvalidArgument;
    if (std.math.isNan(a) or std.math.isNan(b)) return Error.InvalidArgument;

    // Measured: 0 is rejected with status -2 by both adaptive integrators.
    switch (options.integrator) {
        .qng => {},
        .qag, .qags => if (options.integrator.maxIntervals() == 0) {
            return Error.InvalidArgument;
        },
    }
}

fn mapStatus(status: Status) Error!void {
    return switch (status) {
        // Convergence outcomes travel in `Result.status`, not as errors.
        .success, .integrate_max_eval_error, .integrate_bad_behaviour_error => {},
        .invalid_arg_error => Error.InvalidArgument,
        .alloc_error => Error.OutOfMemory,
        .internal_error => Error.Internal,
        .generic_error => Error.Failed,
        _ => Error.Unknown,
    };
}

/// Integrates `f` over the open interval between `a` and `b`, using a
/// caller-supplied workspace.
///
/// `workspace` must be at least `options.integrator.workspaceSize()` bytes;
/// pass an empty slice for QNG, which needs none. Supplying a workspace makes
/// its size, rather than `max_intervals`, the cap on subdivision.
///
/// `a` and `b` need not be ordered, and either may be infinite for QAGS.
pub fn integrateWithWorkspace(
    comptime Context: type,
    ctx: Context,
    f: ArrayFunction(Context),
    a: f64,
    b: f64,
    options: Options,
    workspace: []u8,
) Error!Result {
    try validate(a, b, options);
    std.debug.assert(workspace.len >= options.integrator.workspaceSize());

    const trampoline = Trampoline(Context){ .ctx = ctx, .f = f };
    const function = c.IntegrateFunction{
        .fun = &Trampoline(Context).invoke,
        .fun_arg = @ptrCast(@constCast(&trampoline)),
    };
    const raw_options = options.raw();

    var status: Status = .success;
    var abs_error: f64 = 0;
    const value = c.quadrature_integrate(
        &function,
        a,
        b,
        &raw_options,
        &status,
        &abs_error,
        workspace.len,
        if (workspace.len == 0) null else workspace.ptr,
    );

    try mapStatus(status);
    return .{ .value = value, .abs_error = abs_error, .status = status };
}

/// Integrates `f` over the interval between `a` and `b`, allocating the
/// workspace for the call.
pub fn integrate(
    comptime Context: type,
    ctx: Context,
    f: ArrayFunction(Context),
    a: f64,
    b: f64,
    options: Options,
    allocator: std.mem.Allocator,
) (Error || std.mem.Allocator.Error)!Result {
    const size = options.integrator.workspaceSize();
    const workspace = try allocator.alloc(u8, size);
    defer allocator.free(workspace);
    return integrateWithWorkspace(Context, ctx, f, a, b, options, workspace);
}

/// `integrate` with a scalar integrand.
///
/// Accelerate only offers the array form, so this loops over the batch. For a
/// cheap integrand that is fine; for an expensive one, write the array form and
/// vectorize it.
pub fn integrateScalar(
    comptime Context: type,
    ctx: Context,
    f: ScalarFunction(Context),
    a: f64,
    b: f64,
    options: Options,
    allocator: std.mem.Allocator,
) (Error || std.mem.Allocator.Error)!Result {
    const T = ScalarTrampoline(Context);
    const wrapper = T{ .ctx = ctx, .f = f };
    return integrate(*const T, &wrapper, &T.apply, a, b, options, allocator);
}

/// `integrateScalar` with a caller-supplied workspace.
pub fn integrateScalarWithWorkspace(
    comptime Context: type,
    ctx: Context,
    f: ScalarFunction(Context),
    a: f64,
    b: f64,
    options: Options,
    workspace: []u8,
) Error!Result {
    const T = ScalarTrampoline(Context);
    const wrapper = T{ .ctx = ctx, .f = f };
    return integrateWithWorkspace(*const T, &wrapper, &T.apply, a, b, options, workspace);
}

pub const c_api = c;

test {
    std.testing.refAllDecls(@This());
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const inf = std.math.inf(f64);

fn square(_: void, x: f64) f64 {
    return x * x;
}

test "every integrator computes a polynomial integral exactly" {
    // int_0^3 x^2 dx = 9
    inline for (.{
        Integrator{ .qng = {} },
        Integrator{ .qag = .{} },
        Integrator{ .qags = .{} },
    }) |integrator| {
        const r = try integrateScalar(void, {}, square, 0, 3, .{
            .integrator = integrator,
            .abs_tolerance = 1e-12,
            .rel_tolerance = 1e-12,
        }, testing.allocator);

        try testing.expect(r.converged());
        try testing.expectApproxEqAbs(@as(f64, 9), r.value, 1e-10);
        try testing.expect(r.abs_error < 1e-9);
    }
}

test "reversed bounds negate the result" {
    // The header says a and b need not be ordered.
    const forward = try integrateScalar(void, {}, square, 0, 3, .{
        .abs_tolerance = 1e-12,
    }, testing.allocator);
    const backward = try integrateScalar(void, {}, square, 3, 0, .{
        .abs_tolerance = 1e-12,
    }, testing.allocator);

    try testing.expectApproxEqAbs(forward.value, -backward.value, 1e-10);
}

test "QAGS integrates a Gaussian over the whole real line" {
    const gaussian = struct {
        fn f(_: void, x: f64) f64 {
            return @exp(-x * x);
        }
    }.f;

    const r = try integrateScalar(void, {}, gaussian, -inf, inf, .{
        .integrator = .{ .qags = .{ .max_intervals = 200 } },
        .abs_tolerance = 1e-12,
        .rel_tolerance = 1e-12,
    }, testing.allocator);

    try testing.expect(r.converged());
    try testing.expectApproxEqAbs(@sqrt(std.math.pi), r.value, 1e-10);
}

test "QAGS handles a one-sided infinite bound" {
    // int_0^inf e^-x dx = 1
    const decay = struct {
        fn f(_: void, x: f64) f64 {
            return @exp(-x);
        }
    }.f;

    const r = try integrateScalar(void, {}, decay, 0, inf, .{
        .integrator = .{ .qags = .{ .max_intervals = 200 } },
        .abs_tolerance = 1e-12,
    }, testing.allocator);

    try testing.expect(r.converged());
    try testing.expectApproxEqAbs(@as(f64, 1), r.value, 1e-10);
}

test "QAGS handles an end-point singularity" {
    // int_0^1 1/sqrt(x) dx = 2, singular at 0.
    const inv_sqrt = struct {
        fn f(_: void, x: f64) f64 {
            return if (x <= 0) 0 else 1 / @sqrt(x);
        }
    }.f;

    const r = try integrateScalar(void, {}, inv_sqrt, 0, 1, .{
        .integrator = .{ .qags = .{ .max_intervals = 200 } },
        .abs_tolerance = 1e-10,
        .rel_tolerance = 1e-10,
    }, testing.allocator);

    try testing.expect(r.converged());
    try testing.expectApproxEqAbs(@as(f64, 2), r.value, 1e-8);
}

test "an infinite bound outside QAGS is rejected, not silently NaN" {
    const one = struct {
        fn f(_: void, _: f64) f64 {
            return 1;
        }
    }.f;

    // Measured: QNG reports invalid-argument, but QAG returns NaN with a
    // max-eval status - a bad way to discover the integrator was wrong.
    inline for (.{ Integrator{ .qng = {} }, Integrator{ .qag = .{} } }) |integrator| {
        try testing.expectError(Error.InvalidArgument, integrateScalar(
            void,
            {},
            one,
            0,
            inf,
            .{ .integrator = integrator },
            testing.allocator,
        ));
    }
}

test "max_intervals of zero is rejected" {
    // Accelerate returns status -2 for this on both adaptive integrators, so a
    // zero-initialized options struct would fail at runtime rather than at the
    // call site.
    inline for (.{
        Integrator{ .qag = .{ .max_intervals = 0 } },
        Integrator{ .qags = .{ .max_intervals = 0 } },
    }) |integrator| {
        try testing.expectError(Error.InvalidArgument, integrateScalar(
            void,
            {},
            square,
            0,
            1,
            .{ .integrator = integrator },
            testing.allocator,
        ));
    }
    // QNG ignores the field entirely.
    const r = try integrateScalar(void, {}, square, 0, 1, .{
        .integrator = .{ .qng = {} },
        .abs_tolerance = 1e-12,
    }, testing.allocator);
    try testing.expect(r.converged());
}

test "workspaceSize follows the documented per-interval constants" {
    try testing.expectEqual(@as(usize, 0), (Integrator{ .qng = {} }).workspaceSize());
    try testing.expectEqual(
        @as(usize, 100 * 32),
        (Integrator{ .qag = .{ .max_intervals = 100 } }).workspaceSize(),
    );
    try testing.expectEqual(
        @as(usize, 100 * 152),
        (Integrator{ .qags = .{ .max_intervals = 100 } }).workspaceSize(),
    );
}

test "a caller-supplied workspace gives the same answer as an allocated one" {
    const options = Options{
        .integrator = .{ .qags = .{ .max_intervals = 128 } },
        .abs_tolerance = 1e-12,
        .rel_tolerance = 1e-12,
    };

    const workspace = try testing.allocator.alloc(u8, options.integrator.workspaceSize());
    defer testing.allocator.free(workspace);

    const with = try integrateScalarWithWorkspace(void, {}, square, 0, 3, options, workspace);
    const without = try integrateScalar(void, {}, square, 0, 3, options, testing.allocator);

    try testing.expectEqual(without.value, with.value);
    try testing.expectEqual(without.abs_error, with.abs_error);

    // QNG takes an empty workspace.
    const qng = try integrateScalarWithWorkspace(void, {}, square, 0, 3, .{
        .integrator = .{ .qng = {} },
        .abs_tolerance = 1e-12,
    }, &.{});
    try testing.expectApproxEqAbs(@as(f64, 9), qng.value, 1e-10);
}

test "the array form receives batches and sees its context" {
    const State = struct {
        calls: usize = 0,
        points: usize = 0,
        max_batch: usize = 0,
    };
    var state = State{};

    const batched = struct {
        fn f(s: *State, x: []const f64, y: []f64) void {
            s.calls += 1;
            s.points += x.len;
            s.max_batch = @max(s.max_batch, x.len);
            for (x, y) |xi, *yi| yi.* = xi * xi;
        }
    }.f;

    const r = try integrate(*State, &state, batched, 0, 3, .{
        .integrator = .{ .qng = {} },
        .abs_tolerance = 1e-12,
    }, testing.allocator);

    try testing.expectApproxEqAbs(@as(f64, 9), r.value, 1e-10);
    try testing.expect(state.calls > 0);
    // QNG evaluates 21, 43 or 87 points; batching means far fewer calls than
    // points, which is the whole reason the C API is array-shaped.
    try testing.expect(state.points >= 21);
    try testing.expect(state.max_batch > 1);
    try testing.expect(state.calls < state.points);
}

test "a context carrying parameters integrates a family of functions" {
    // int_0^1 x^k dx = 1/(k+1)
    const power = struct {
        fn f(k: f64, x: f64) f64 {
            return std.math.pow(f64, x, k);
        }
    }.f;

    for ([_]f64{ 0, 1, 2, 3, 7 }) |k| {
        const r = try integrateScalar(f64, k, power, 0, 1, .{
            .abs_tolerance = 1e-12,
            .rel_tolerance = 1e-12,
        }, testing.allocator);
        try testing.expect(r.converged());
        try testing.expectApproxEqAbs(1 / (k + 1), r.value, 1e-10);
    }
}

test "failing to reach the tolerance is a status, not an error" {
    // sin(1/x) oscillates without bound as x -> 0. With a tight tolerance and
    // a deliberately tiny subdivision budget, QAG cannot converge.
    const oscillatory = struct {
        fn f(_: void, x: f64) f64 {
            return @sin(1 / (x + 1e-12));
        }
    }.f;

    const r = try integrateScalar(void, {}, oscillatory, 0, 1, .{
        .integrator = .{ .qag = .{ .max_intervals = 2 } },
        .abs_tolerance = 1e-14,
        .rel_tolerance = 1e-14,
    }, testing.allocator);

    // Not an error: the partial estimate and its (large) error bound are the
    // useful output here.
    try testing.expect(!r.converged());
    try testing.expectEqual(Status.integrate_max_eval_error, r.status);
    try testing.expect(r.abs_error > 1e-3);
    try testing.expect(!std.math.isNan(r.value));
}

test "a bigger budget tightens the estimate without ever converging" {
    // sin(1/x) has infinitely many oscillations approaching 0, so no finite
    // subdivision reaches a 1e-8 tolerance - measured: `.integrate_max_eval_error`
    // at 512, 2048 and 4096 intervals alike. What *does* improve is the error
    // bound, and this is precisely the case the `Result.status` design exists
    // for: the value is accurate to ~1e-6 and useful, and calling it an error
    // would throw it away.
    const oscillatory = struct {
        fn f(_: void, x: f64) f64 {
            return @sin(1 / (x + 1e-12));
        }
    }.f;

    // Reference value of int_0^1 sin(1/x) dx.
    const reference: f64 = 0.5040670619069283;

    const small = try integrateScalar(void, {}, oscillatory, 0, 1, .{
        .integrator = .{ .qag = .{ .points_per_interval = .p61, .max_intervals = 8 } },
        .abs_tolerance = 1e-8,
        .rel_tolerance = 1e-8,
    }, testing.allocator);
    const large = try integrateScalar(void, {}, oscillatory, 0, 1, .{
        .integrator = .{ .qag = .{ .points_per_interval = .p61, .max_intervals = 2048 } },
        .abs_tolerance = 1e-8,
        .rel_tolerance = 1e-8,
    }, testing.allocator);

    try testing.expect(!small.converged());
    try testing.expect(!large.converged());
    try testing.expect(large.abs_error < small.abs_error);
    try testing.expectApproxEqAbs(reference, large.value, 1e-4);
}

test "a smooth oscillatory integrand does converge" {
    // int_0^pi sin(20x) dx = (1 - cos(20*pi))/20 = 0, and the integrand is
    // smooth, so unlike sin(1/x) this reaches the tolerance.
    const wave = struct {
        fn f(_: void, x: f64) f64 {
            return @sin(20 * x);
        }
    }.f;

    const r = try integrateScalar(void, {}, wave, 0, std.math.pi, .{
        .integrator = .{ .qag = .{ .points_per_interval = .p61, .max_intervals = 256 } },
        .abs_tolerance = 1e-10,
        .rel_tolerance = 1e-10,
    }, testing.allocator);

    try testing.expect(r.converged());
    try testing.expectApproxEqAbs(@as(f64, 0), r.value, 1e-9);
}

test "every points_per_interval value Accelerate accepts is usable" {
    // The enum exists because anything outside this set is rejected with an
    // invalid-argument error - 17, for instance, was measured returning -2.
    inline for (.{ .default, .p15, .p21, .p31, .p41, .p51, .p61 }) |points| {
        const r = try integrateScalar(void, {}, square, 0, 3, .{
            .integrator = .{ .qag = .{ .points_per_interval = points, .max_intervals = 64 } },
            .abs_tolerance = 1e-12,
            .rel_tolerance = 1e-12,
        }, testing.allocator);
        try testing.expect(r.converged());
        try testing.expectApproxEqAbs(@as(f64, 9), r.value, 1e-10);
    }
}

test "Options.raw maps the union onto the flat C struct" {
    const qng = (Options{ .integrator = .{ .qng = {} }, .abs_tolerance = 0.5 }).raw();
    try testing.expectEqual(c.Integrator.qng, qng.integrator);
    try testing.expectEqual(@as(usize, 0), qng.qag_points_per_interval);
    try testing.expectEqual(@as(usize, 0), qng.max_intervals);
    try testing.expectEqual(@as(f64, 0.5), qng.abs_tolerance);

    const qag = (Options{ .integrator = .{ .qag = .{
        .points_per_interval = .p41,
        .max_intervals = 33,
    } } }).raw();
    try testing.expectEqual(c.Integrator.qag, qag.integrator);
    try testing.expectEqual(@as(usize, 41), qag.qag_points_per_interval);
    try testing.expectEqual(@as(usize, 33), qag.max_intervals);

    // QAGS has no points setting, so the field must go out as 0 rather than
    // carrying a stale value from another arm.
    const qags = (Options{ .integrator = .{ .qags = .{ .max_intervals = 7 } } }).raw();
    try testing.expectEqual(c.Integrator.qags, qags.integrator);
    try testing.expectEqual(@as(usize, 0), qags.qag_points_per_interval);
    try testing.expectEqual(@as(usize, 7), qags.max_intervals);
}

test "NaN bounds are rejected" {
    const nan = std.math.nan(f64);
    try testing.expectError(Error.InvalidArgument, integrateScalar(
        void,
        {},
        square,
        nan,
        1,
        .{},
        testing.allocator,
    ));
    try testing.expectError(Error.InvalidArgument, integrateScalar(
        void,
        {},
        square,
        0,
        nan,
        .{},
        testing.allocator,
    ));
}
