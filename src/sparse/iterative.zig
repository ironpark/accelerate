//! Iterative sparse solvers: conjugate gradient, GMRES and LSMR.
//!
//! Direct factorization (`factor.zig`) is the more reliable choice and should
//! be tried first. Iterative methods use less memory and can be much faster on
//! a well-conditioned problem or with a good preconditioner, but they need more
//! judgement from the caller: each solve costs the same as the last, and
//! convergence is not guaranteed.
//!
//! Which method:
//!
//! | Matrix | Method |
//! |---|---|
//! | symmetric positive-definite | `conjugateGradient` |
//! | square, full rank, indefinite or unsymmetric | `gmres` |
//! | rectangular or singular (least squares) | `lsmr` |
//!
//! ```zig
//! const status = try Iterative(f64).conjugateGradient(a, b, x, .{});
//! if (status != .converged) { ... }
//! ```
//!
//! ## The matrix-free form
//!
//! Every solver has an `...Operator` variant taking a callback instead of a
//! matrix, so `A` never has to be stored:
//!
//! ```zig
//! fn applyStencil(ctx: *Grid, accumulate: bool, trans: Transpose,
//!                 x: Dense(f64), y: Dense(f64)) void { ... }
//!
//! _ = try Iterative(f64).conjugateGradientOperator(*Grid, &grid, applyStencil, b, x, .{});
//! ```
//!
//! This is the shape the C API actually has - the matrix-taking overloads are
//! inline wrappers that build such a callback around `SparseMultiply`. On the C
//! side the callback is a `_Nonnull` Objective-C block; `block.zig` builds one
//! by hand, and the callback above is what it captures and dispatches to.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const matrix = @import("matrix.zig");
const block = @import("block.zig");

const SparseError = types.SparseError;

pub const Transpose = c.Transpose;
pub const IterativeStatus = c.IterativeStatus;
pub const GMRESVariant = c.GMRESVariant;
pub const LSMRConvergenceTest = c.LSMRConvergenceTest;
pub const PreconditionerType = c.PreconditionerType;

/// Shared knobs. Zero means "use Accelerate's default" for every field, which
/// is what the C factory functions (`SparseConjugateGradient()` and friends)
/// produce.
pub const CGOptions = struct {
    /// Iteration cap. 0 lets Accelerate choose.
    max_iterations: u31 = 0,
    /// Absolute residual tolerance.
    atol: f64 = 0,
    /// Relative residual tolerance.
    rtol: f64 = 0,
};

pub const GMRESOptions = struct {
    /// `.dqgmres` uses bounded memory and does not restart; `.gmres` is the
    /// restarted variant; `.fgmres` allows the preconditioner to change
    /// between iterations and therefore **requires** one - passing
    /// `.fgmres` with a null preconditioner is `error.ParameterError`.
    variant: GMRESVariant = .dqgmres,
    /// Size of the Krylov subspace kept. 0 lets Accelerate choose.
    nvec: u31 = 0,
    max_iterations: u31 = 0,
    atol: f64 = 0,
    rtol: f64 = 0,
};

pub const LSMROptions = struct {
    /// Tikhonov regularization: minimizes `||b - Ax||^2 + lambda^2 ||x||^2`.
    lambda: f64 = 0,
    nvec: u31 = 0,
    convergence_test: LSMRConvergenceTest = .default,
    atol: f64 = 0,
    rtol: f64 = 0,
    btol: f64 = 0,
    condition_limit: f64 = 0,
    max_iterations: u31 = 0,
};

pub fn Iterative(comptime T: type) type {
    return struct {
        const Self = @This();
        const Sparse = matrix.Sparse(T);
        const Dense = matrix.Dense(T);
        const RawDense = c.DenseMatrix(T);
        const f = c.fns(T);

        /// The operator callback: compute `y = op(x)`, or `y += op(x)` when
        /// `accumulate`.
        ///
        /// `trans` says whether to apply `A` or `A^T`. CG and GMRES only ever
        /// pass `.no_trans` (both require a square operator, and CG a symmetric
        /// one); LSMR uses both, so a matrix-free LSMR operator must implement
        /// the transpose.
        pub fn Operator(comptime Context: type) type {
            return *const fn (Context, bool, Transpose, Dense, Dense) void;
        }

        /// A preconditioner `P` approximating `A^-1`.
        pub const Preconditioner = struct {
            raw: c.OpaquePreconditioner(T),
            owned: bool,

            /// Builds one of Accelerate's built-in preconditioners for `a`.
            ///
            /// `.diagonal` (Jacobi) and `.diag_scaling` are cheap and often
            /// enough for a diagonally dominant system.
            pub fn init(kind: PreconditionerType, a: Sparse) SparseError!Preconditioner {
                if (kind == .user) return SparseError.ParameterError;
                var raw_a = a.raw();
                types.clearReportedError();
                const p = f.createPreconditioner(kind, &raw_a);
                try types.takeReportedError();
                return .{ .raw = p, .owned = true };
            }

            /// Wraps a caller-supplied preconditioner.
            ///
            /// `apply` computes `y = P x`, or `y = P^T x` when `trans` says so.
            /// `mem` is handed back unaltered as the first argument. Unlike the
            /// operator this is a plain C function pointer on Apple's side, so
            /// no block is involved.
            pub fn user(
                mem: ?*anyopaque,
                apply: *const fn (?*anyopaque, Transpose, RawDense, RawDense) callconv(.c) void,
            ) Preconditioner {
                return .{
                    .raw = .{ .type = .user, .mem = mem, .apply = apply },
                    .owned = false,
                };
            }

            pub fn deinit(self: *Preconditioner) void {
                if (self.owned) f.releasePreconditioner(&self.raw);
                self.owned = false;
                self.raw.type = .none;
            }
        };

        // -------------------------------------------------------------------
        // Block plumbing
        // -------------------------------------------------------------------

        /// What the operator call needs: the user's context and callback.
        ///
        /// Not itself the block capture - a block literal is an `extern
        /// struct` and `Context` may be any Zig type - so the block captures a
        /// *pointer* to one of these, living in `run`'s frame. That frame
        /// outlives the C call, which is the only lifetime that matters here.
        fn OpContext(comptime Context: type) type {
            return struct { ctx: Context, apply: Operator(Context) };
        }

        /// The block's `invoke`. C passes the block pointer first, then the
        /// four operator arguments; the dense matrices arrive by value.
        fn OpBlock(comptime Context: type) type {
            return block.Block(
                *const OpContext(Context),
                fn (*anyopaque, bool, Transpose, RawDense, RawDense) callconv(.c) void,
            );
        }

        fn invokeOperator(comptime Context: type) fn (*anyopaque, bool, Transpose, RawDense, RawDense) callconv(.c) void {
            return struct {
                fn invoke(blk: *anyopaque, accumulate: bool, trans: Transpose, x: RawDense, y: RawDense) callconv(.c) void {
                    const captured = OpBlock(Context).contextOf(blk);
                    captured.apply(captured.ctx, accumulate, trans, fromRaw(x), fromRaw(y));
                }
            }.invoke;
        }

        /// Rebuilds a length-carrying `Dense` from the raw struct Accelerate
        /// hands the callback. The last column needs only `rowCount` entries,
        /// not a full stride, which is what the C side allocates.
        fn fromRaw(m: RawDense) Dense {
            const rows: usize = @intCast(m.rowCount);
            const cols: usize = @intCast(m.columnCount);
            const stride: usize = @intCast(m.columnStride);
            return .{
                .data = m.data[0 .. (cols - 1) * stride + rows],
                .row_count = rows,
                .column_count = cols,
                .column_stride = stride,
                .attributes = m.attributes,
            };
        }

        /// The operator for an explicitly stored matrix: exactly what Apple's
        /// inline wrappers build, `SparseMultiply`/`SparseMultiplyAdd` with the
        /// transpose applied for LSMR.
        fn matrixOperator(a: Sparse, accumulate: bool, trans: Transpose, x: Dense, y: Dense) void {
            const target = if (trans == .no_trans) a else a.transposed();
            target.multiply(types.one(T), x, y, accumulate) catch {
                // The shapes were validated before the solve started, so a
                // failure here would mean Sparse changed its mind mid-solve.
                // There is no way to propagate out of a C callback; leave the
                // message pending so the solver's caller still sees it.
            };
        }

        // -------------------------------------------------------------------
        // Solvers
        // -------------------------------------------------------------------

        /// Conjugate gradient. `a` must be symmetric positive-definite.
        pub fn conjugateGradient(
            a: Sparse,
            b: Dense,
            x: Dense,
            options: CGOptions,
            preconditioner: ?*const Preconditioner,
        ) SparseError!IterativeStatus {
            try checkShapes(a, b, x, .square);
            return conjugateGradientOperator(Sparse, a, matrixOperator, b, x, options, preconditioner);
        }

        /// Conjugate gradient against a caller-supplied operator.
        pub fn conjugateGradientOperator(
            comptime Context: type,
            ctx: Context,
            apply: Operator(Context),
            b: Dense,
            x: Dense,
            options: CGOptions,
            preconditioner: ?*const Preconditioner,
        ) SparseError!IterativeStatus {
            var raw = c.CGOptions{
                .reportError = types.report_error_callback,
                .maxIterations = options.max_iterations,
                .atol = options.atol,
                .rtol = options.rtol,
            };
            return run(Context, ctx, apply, b, x, &raw, f.cgSolve, preconditioner);
        }

        /// GMRES. `a` must be square; it may be indefinite or unsymmetric.
        pub fn gmres(
            a: Sparse,
            b: Dense,
            x: Dense,
            options: GMRESOptions,
            preconditioner: ?*const Preconditioner,
        ) SparseError!IterativeStatus {
            try checkShapes(a, b, x, .square);
            return gmresOperator(Sparse, a, matrixOperator, b, x, options, preconditioner);
        }

        /// GMRES against a caller-supplied operator, optionally preconditioned.
        pub fn gmresOperator(
            comptime Context: type,
            ctx: Context,
            apply: Operator(Context),
            b: Dense,
            x: Dense,
            options: GMRESOptions,
            preconditioner: ?*const Preconditioner,
        ) SparseError!IterativeStatus {
            // Sparse reports this one cleanly rather than trapping, but
            // catching it here names the constraint at the call site.
            if (options.variant == .fgmres and preconditioner == null) {
                return SparseError.ParameterError;
            }
            var raw = c.GMRESOptions{
                .reportError = types.report_error_callback,
                .variant = options.variant,
                .nvec = options.nvec,
                .maxIterations = options.max_iterations,
                .atol = options.atol,
                .rtol = options.rtol,
            };
            return run(Context, ctx, apply, b, x, &raw, f.gmresSolve, preconditioner);
        }

        /// LSMR: minimizes `||b - A x||_2`. `a` may be rectangular or singular.
        pub fn lsmr(
            a: Sparse,
            b: Dense,
            x: Dense,
            options: LSMROptions,
            preconditioner: ?*const Preconditioner,
        ) SparseError!IterativeStatus {
            try checkShapes(a, b, x, .any);
            return lsmrOperator(Sparse, a, matrixOperator, b, x, options, preconditioner);
        }

        /// LSMR against a caller-supplied operator, optionally preconditioned.
        ///
        /// Unlike CG and GMRES, LSMR *does* call the operator with
        /// `trans == .trans`, so a matrix-free operator must implement `A^T`.
        pub fn lsmrOperator(
            comptime Context: type,
            ctx: Context,
            apply: Operator(Context),
            b: Dense,
            x: Dense,
            options: LSMROptions,
            preconditioner: ?*const Preconditioner,
        ) SparseError!IterativeStatus {
            var raw = c.LSMROptions{
                .reportError = types.report_error_callback,
                .lambda = options.lambda,
                .nvec = options.nvec,
                .convergenceTest = options.convergence_test,
                .atol = options.atol,
                .rtol = options.rtol,
                .btol = options.btol,
                .conditionLimit = options.condition_limit,
                .maxIterations = options.max_iterations,
            };
            return run(Context, ctx, apply, b, x, &raw, f.lsmrSolve, preconditioner);
        }

        // -------------------------------------------------------------------
        // Shared driver
        // -------------------------------------------------------------------

        fn run(
            comptime Context: type,
            ctx: Context,
            apply: Operator(Context),
            b: Dense,
            x: Dense,
            options: anytype,
            solver: anytype,
            preconditioner: ?*const Preconditioner,
        ) SparseError!IterativeStatus {
            if (b.rhsCount() != x.rhsCount()) return SparseError.ParameterError;
            if (b.rhsCount() == 0) return SparseError.ParameterError;

            const captured = OpContext(Context){ .ctx = ctx, .apply = apply };
            const blk = OpBlock(Context).init(&invokeOperator(Context), &captured);

            var raw_b = b.raw();
            var raw_x = x.raw();

            types.clearReportedError();
            const status = solver(
                options,
                &raw_x,
                &raw_b,
                @ptrCast(&blk),
                if (preconditioner) |p| &p.raw else null,
            );

            // The returned status decides, NOT whether a message was reported.
            // Unlike the direct solvers, the iterative ones also route ordinary
            // outcomes through `reportError` - failing to converge within
            // `max_iterations` reports "Exceeded maximum iteration limit." and
            // still returns `.max_iterations`. Treating any reported message as
            // a failure would turn that into an error, which it is not.
            switch (status) {
                .parameter_error => return SparseError.ParameterError,
                .internal_error => return SparseError.InternalError,
                else => {
                    // Drop the advisory message so it cannot be mistaken for a
                    // pending failure by the next call on this thread.
                    types.clearReportedError();
                    return status;
                },
            }
        }

        const ShapeRule = enum { square, any };

        /// The dimension checks the C wrappers do before dispatching.
        fn checkShapes(a: Sparse, b: Dense, x: Dense, rule: ShapeRule) SparseError!void {
            const block_size: usize = a.block_size;
            const am = block_size * if (a.attributes.transpose) a.column_count else a.row_count;
            const an = block_size * if (a.attributes.transpose) a.row_count else a.column_count;
            if (am == 0 or an == 0) return SparseError.ParameterError;

            if (b.rhsCount() != x.rhsCount()) return SparseError.ParameterError;
            if (x.size() != an) return SparseError.ParameterError;
            if (b.size() != am) return SparseError.ParameterError;
            // CG and GMRES need a square operator; LSMR is the whole point of
            // allowing a rectangular one.
            if (rule == .square and am != an) return SparseError.ParameterError;
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const TestMatrix = matrix.TestMatrix;
const D64 = matrix.Dense(f64);
const S64 = matrix.Sparse(f64);
const It64 = Iterative(f64);

test "conjugate gradient solves the SPD test system" {
    inline for (.{ f64, f32 }) |T| {
        const vals = TestMatrix.values(T);
        const a = TestMatrix.matrix(T, &vals);
        const D = matrix.Dense(T);

        var b = TestMatrix.rhs(T);
        var x = [_]T{0} ** 4;
        const status = try Iterative(T).conjugateGradient(
            a,
            D.fromSlice(&b),
            D.fromSlice(&x),
            .{ .rtol = 1e-12, .max_iterations = 100 },
            null,
        );

        try testing.expectEqual(IterativeStatus.converged, status);
        for (TestMatrix.solution(T), x) |want, got| {
            try testing.expectApproxEqAbs(want, got, if (T == f64) 1e-8 else 1e-3);
        }
    }
}

test "GMRES solves an unsymmetric square system" {
    // Unsymmetric, diagonally dominant 3x3, stored full (CSC):
    //   [ 4  1  0 ]
    //   [ 2  5  1 ]
    //   [ 0  1  6 ]
    const starts = [_]c_long{ 0, 2, 5, 7 };
    const rows = [_]c_int{ 0, 1, 0, 1, 2, 1, 2 };
    const vals = [_]f64{ 4, 2, 1, 5, 1, 1, 6 };
    const a = S64.init(3, 3, &starts, &rows, &vals, .{});

    // A * [1, 2, 3] = [6, 15, 20]
    var b = [_]f64{ 6, 15, 20 };
    var x = [_]f64{ 0, 0, 0 };
    const status = try It64.gmres(a, D64.fromSlice(&b), D64.fromSlice(&x), .{
        .rtol = 1e-12,
        .max_iterations = 200,
    }, null);

    try testing.expectEqual(IterativeStatus.converged, status);
    for ([_]f64{ 1, 2, 3 }, x) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-8);
    }
}

test "every GMRES variant reaches the same answer" {
    const starts = [_]c_long{ 0, 2, 5, 7 };
    const rows = [_]c_int{ 0, 1, 0, 1, 2, 1, 2 };
    const vals = [_]f64{ 4, 2, 1, 5, 1, 1, 6 };
    const a = S64.init(3, 3, &starts, &rows, &vals, .{});

    // FGMRES lets the preconditioner change between iterations, so it needs
    // one; the other two do not.
    var pre = try It64.Preconditioner.init(.diagonal, a);
    defer pre.deinit();

    inline for (.{ .dqgmres, .gmres, .fgmres }) |variant| {
        var b = [_]f64{ 6, 15, 20 };
        var x = [_]f64{ 0, 0, 0 };
        _ = try It64.gmres(a, D64.fromSlice(&b), D64.fromSlice(&x), .{
            .variant = variant,
            .rtol = 1e-12,
            .max_iterations = 200,
        }, if (variant == .fgmres) &pre else null);
        for ([_]f64{ 1, 2, 3 }, x) |want, got| {
            try testing.expectApproxEqAbs(want, got, 1e-6);
        }
    }
}

test "FGMRES without a preconditioner is an error, not a trap" {
    const starts = [_]c_long{ 0, 2, 5, 7 };
    const rows = [_]c_int{ 0, 1, 0, 1, 2, 1, 2 };
    const vals = [_]f64{ 4, 2, 1, 5, 1, 1, 6 };
    const a = S64.init(3, 3, &starts, &rows, &vals, .{});

    var b = [_]f64{ 6, 15, 20 };
    var x = [_]f64{ 0, 0, 0 };
    try testing.expectError(SparseError.ParameterError, It64.gmres(
        a,
        D64.fromSlice(&b),
        D64.fromSlice(&x),
        .{ .variant = .fgmres },
        null,
    ));
}

test "LSMR solves the overdetermined least-squares problem" {
    // The same 4x2 system QR handles in factor.zig, exact solution [1, 2].
    const starts = [_]c_long{ 0, 3, 6 };
    const rows = [_]c_int{ 0, 2, 3, 1, 2, 3 };
    const vals = [_]f64{ 1, 1, 1, 1, 1, 2 };
    const a = S64.init(4, 2, &starts, &rows, &vals, .{});

    var b = [_]f64{ 1, 2, 3, 5 };
    var x = [_]f64{ 0, 0 };
    const status = try It64.lsmr(a, D64.fromSlice(&b), D64.fromSlice(&x), .{
        .atol = 1e-13,
        .btol = 1e-13,
        .max_iterations = 500,
    }, null);

    try testing.expect(status == .converged or status == .max_iterations);
    try testing.expectApproxEqAbs(@as(f64, 1), x[0], 1e-6);
    try testing.expectApproxEqAbs(@as(f64, 2), x[1], 1e-6);
}

test "LSMR with lambda regularizes toward zero" {
    const starts = [_]c_long{ 0, 3, 6 };
    const rows = [_]c_int{ 0, 2, 3, 1, 2, 3 };
    const vals = [_]f64{ 1, 1, 1, 1, 1, 2 };
    const a = S64.init(4, 2, &starts, &rows, &vals, .{});

    var b = [_]f64{ 1, 2, 3, 5 };
    var x = [_]f64{ 0, 0 };
    _ = try It64.lsmr(a, D64.fromSlice(&b), D64.fromSlice(&x), .{
        .lambda = 10,
        .atol = 1e-13,
        .btol = 1e-13,
        .max_iterations = 500,
    }, null);

    // Heavy Tikhonov damping must shrink the solution well below [1, 2].
    const norm = @sqrt(x[0] * x[0] + x[1] * x[1]);
    try testing.expect(norm < @sqrt(5.0));
    try testing.expect(norm > 0);
}

test "a matrix-free operator solves the same system as the stored matrix" {
    const Dense4 = [4][4]f64;
    // The dense form of TestMatrix, reflected into both triangles.
    const dense = Dense4{
        .{ 2, 1, 0, 0 },
        .{ 1, 3, 1, 0 },
        .{ 0, 1, 4, 1 },
        .{ 0, 0, 1, 5 },
    };

    const apply = struct {
        fn f(m: *const Dense4, accumulate: bool, trans: Transpose, x: D64, y: D64) void {
            _ = trans; // symmetric
            for (0..x.column_count) |col| {
                const xc = x.column(col);
                const yc = y.column(col);
                for (0..x.row_count) |i| {
                    var acc: f64 = 0;
                    for (0..x.row_count) |j| acc += m[i][j] * xc[j];
                    yc[i] = if (accumulate) yc[i] + acc else acc;
                }
            }
        }
    }.f;

    var b = TestMatrix.rhs(f64);
    var x = [_]f64{0} ** 4;
    const status = try It64.conjugateGradientOperator(
        *const Dense4,
        &dense,
        apply,
        D64.fromSlice(&b),
        D64.fromSlice(&x),
        .{ .rtol = 1e-14, .max_iterations = 100 },
        null,
    );

    try testing.expectEqual(IterativeStatus.converged, status);
    for (TestMatrix.solution(f64), x) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-9);
    }
}

test "the operator callback is invoked, and sees usable Dense views" {
    // Guards the block plumbing itself: if `invoke` were never reached, or the
    // captured context were wrong, the counter would stay zero and the solve
    // would silently produce nothing.
    const State = struct {
        calls: usize = 0,
        saw_rows: usize = 0,
        saw_transpose: bool = false,
    };
    var state = State{};

    const starts = [_]c_long{ 0, 1, 2, 3, 4 };
    const idx = [_]c_int{ 0, 1, 2, 3 };
    const vals = [_]f64{ 2, 2, 2, 2 };
    const a = S64.init(4, 4, &starts, &idx, &vals, .{
        .attributes = .{ .kind = .symmetric, .triangle = .lower },
    });

    const apply = struct {
        fn f(s: *State, accumulate: bool, trans: Transpose, x: D64, y: D64) void {
            s.calls += 1;
            s.saw_rows = x.row_count;
            if (trans != .no_trans) s.saw_transpose = true;
            for (0..x.row_count) |i| {
                const v = 2 * x.data[i];
                y.data[i] = if (accumulate) y.data[i] + v else v;
            }
        }
    }.f;

    var b = [_]f64{ 2, 4, 6, 8 };
    var x = [_]f64{0} ** 4;
    _ = try It64.conjugateGradientOperator(*State, &state, apply, D64.fromSlice(&b), D64.fromSlice(&x), .{
        .rtol = 1e-14,
        .max_iterations = 50,
    }, null);

    try testing.expect(state.calls > 0);
    try testing.expectEqual(@as(usize, 4), state.saw_rows);
    // CG never asks for the transpose - the header says so, and this pins it.
    try testing.expect(!state.saw_transpose);

    // 2I x = b means x = b/2.
    for ([_]f64{ 1, 2, 3, 4 }, x) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-9);
    }
    _ = a;
}

test "LSMR does ask its operator for the transpose" {
    // The counterpart to the CG check above: a matrix-free LSMR operator that
    // ignored `trans` would be silently wrong, so confirm it is really used.
    const State = struct { saw_no_trans: bool = false, saw_trans: bool = false };
    var state = State{};

    // 4x2 matrix as a dense array, applied both ways.
    const dense = [4][2]f64{ .{ 1, 0 }, .{ 0, 1 }, .{ 1, 1 }, .{ 1, 2 } };

    const apply = struct {
        fn f(s: *State, accumulate: bool, trans: Transpose, x: D64, y: D64) void {
            if (trans == .no_trans) {
                s.saw_no_trans = true;
                for (0..4) |i| {
                    var acc: f64 = 0;
                    for (0..2) |j| acc += dense[i][j] * x.data[j];
                    y.data[i] = if (accumulate) y.data[i] + acc else acc;
                }
            } else {
                s.saw_trans = true;
                for (0..2) |j| {
                    var acc: f64 = 0;
                    for (0..4) |i| acc += dense[i][j] * x.data[i];
                    y.data[j] = if (accumulate) y.data[j] + acc else acc;
                }
            }
        }
    }.f;

    var b = [_]f64{ 1, 2, 3, 5 };
    var x = [_]f64{ 0, 0 };
    _ = try It64.lsmrOperator(*State, &state, apply, D64.fromSlice(&b), D64.fromSlice(&x), .{
        .atol = 1e-13,
        .btol = 1e-13,
        .max_iterations = 500,
    }, null);

    try testing.expect(state.saw_no_trans);
    try testing.expect(state.saw_trans);
    try testing.expectApproxEqAbs(@as(f64, 1), x[0], 1e-6);
    try testing.expectApproxEqAbs(@as(f64, 2), x[1], 1e-6);
}

test "a built-in diagonal preconditioner is accepted and reaches the same answer" {
    // Badly scaled but diagonally dominant, so Jacobi has something to work on.
    // Reflecting the stored lower triangle gives
    //   [ 1000  1     0    ]
    //   [ 1     2     1    ]
    //   [ 0     1     0.05 ]
    const starts = [_]c_long{ 0, 2, 4, 5 };
    const rows = [_]c_int{ 0, 1, 1, 2, 2 };
    const vals = [_]f64{ 1000, 1, 2, 1, 0.05 };
    const a = S64.init(3, 3, &starts, &rows, &vals, .{
        .attributes = .{ .kind = .symmetric, .triangle = .lower },
    });

    var pre = try It64.Preconditioner.init(.diagonal, a);
    defer pre.deinit();
    try testing.expectEqual(PreconditionerType.diagonal, pre.raw.type);

    // A * [1, 2, 3] = [1000+2, 1+4+3, 2+0.15].
    const b_values = [_]f64{ 1002, 8, 2.15 };

    // Preconditioned and unpreconditioned must agree; the preconditioner
    // changes the path to the answer, not the answer.
    var with_pre = [_]f64{ 0, 0, 0 };
    var without_pre = [_]f64{ 0, 0, 0 };
    for ([_]?*const It64.Preconditioner{ &pre, null }, [_]*[3]f64{ &with_pre, &without_pre }) |p, out| {
        var b = b_values;
        const status = try It64.gmres(
            a,
            D64.fromSlice(&b),
            D64.fromSlice(out),
            .{ .rtol = 1e-13, .max_iterations = 500 },
            p,
        );
        try testing.expectEqual(IterativeStatus.converged, status);
        for ([_]f64{ 1, 2, 3 }, out.*) |want, got| {
            try testing.expectApproxEqAbs(want, got, 1e-8);
        }
    }
}

test "a user preconditioner's apply callback is invoked" {
    const Counter = struct {
        var calls: usize = 0;
        fn apply(_: ?*anyopaque, trans: Transpose, x: c.DenseMatrix(f64), y: c.DenseMatrix(f64)) callconv(.c) void {
            _ = trans;
            calls += 1;
            // Identity preconditioner: correct, just useless.
            const n: usize = @intCast(x.rowCount);
            @memcpy(y.data[0..n], x.data[0..n]);
        }
    };
    Counter.calls = 0;

    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    const pre = It64.Preconditioner.user(null, &Counter.apply);

    var b = TestMatrix.rhs(f64);
    var x = [_]f64{0} ** 4;
    _ = try It64.gmres(
        a,
        D64.fromSlice(&b),
        D64.fromSlice(&x),
        .{ .rtol = 1e-13, .max_iterations = 200 },
        &pre,
    );

    try testing.expect(Counter.calls > 0);
    for (TestMatrix.solution(f64), x) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-7);
    }
}

test "a preconditioner may not be constructed with type .user" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    // .user has no matrix to build from; the callback form is `user()`.
    try testing.expectError(SparseError.ParameterError, It64.Preconditioner.init(.user, a));
}

test "mismatched shapes are rejected rather than trapped" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);

    var b = TestMatrix.rhs(f64);
    var short = [_]f64{ 0, 0, 0 };
    try testing.expectError(SparseError.ParameterError, It64.conjugateGradient(
        a,
        D64.fromSlice(&b),
        D64.fromSlice(&short),
        .{},
        null,
    ));

    // CG and GMRES require a square operator.
    const starts = [_]c_long{ 0, 3, 6 };
    const rows = [_]c_int{ 0, 2, 3, 1, 2, 3 };
    const rect_vals = [_]f64{ 1, 1, 1, 1, 1, 2 };
    const rect = S64.init(4, 2, &starts, &rows, &rect_vals, .{});
    var rb = [_]f64{ 1, 2, 3, 5 };
    var rx = [_]f64{ 0, 0 };
    try testing.expectError(SparseError.ParameterError, It64.conjugateGradient(
        rect,
        D64.fromSlice(&rb),
        D64.fromSlice(&rx),
        .{},
        null,
    ));
    // But LSMR accepts it.
    _ = try It64.lsmr(rect, D64.fromSlice(&rb), D64.fromSlice(&rx), .{ .max_iterations = 100 }, null);
}

test "an iteration cap that is too low reports max_iterations, not an error" {
    const starts = [_]c_long{ 0, 2, 5, 7 };
    const rows = [_]c_int{ 0, 1, 0, 1, 2, 1, 2 };
    const vals = [_]f64{ 4, 2, 1, 5, 1, 1, 6 };
    const a = S64.init(3, 3, &starts, &rows, &vals, .{});

    var b = [_]f64{ 6, 15, 20 };
    var x = [_]f64{ 0, 0, 0 };
    const status = try It64.gmres(a, D64.fromSlice(&b), D64.fromSlice(&x), .{
        .variant = .gmres,
        .rtol = 1e-300, // unreachable
        .max_iterations = 1,
    }, null);

    // Not converging is an outcome the caller judges, not a failure. Sparse
    // *does* push "Exceeded maximum iteration limit." through the reportError
    // callback here, so this also pins that `run` decides on the returned
    // status rather than on whether a message arrived.
    try testing.expectEqual(IterativeStatus.max_iterations, status);
}

test "multi-RHS iterative solve" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);

    // Two right-hand sides: A*[1,2,3,4] and A*[1,0,0,0].
    var b = [_]f64{ 4, 10, 18, 23, 2, 1, 0, 0 };
    var x = [_]f64{0} ** 8;
    const status = try It64.conjugateGradient(
        a,
        D64.init(&b, 4, 2, 4),
        D64.init(&x, 4, 2, 4),
        .{ .rtol = 1e-13, .max_iterations = 100 },
        null,
    );

    try testing.expectEqual(IterativeStatus.converged, status);
    for ([_]f64{ 1, 2, 3, 4 }, x[0..4]) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-8);
    }
    for ([_]f64{ 1, 0, 0, 0 }, x[4..8]) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-8);
    }
}

test "conjugate gradient on a complex Hermitian system" {
    // The iterative solvers are generic over the element type the same way the
    // direct ones are, and CG's requirement becomes Hermitian positive
    // definite rather than symmetric positive definite. This is the 3x3 from
    // factor.zig, solved without a factorization.
    const Z = types.Complex(f64);
    const starts = [_]c_long{ 0, 2, 4, 5 };
    const rows = [_]c_int{ 0, 1, 1, 2, 2 };
    const vals = [_]Z{ Z.init(4, 0), Z.init(1, -1), Z.init(3, 0), Z.init(0, -2), Z.init(5, 0) };
    const a = matrix.Sparse(Z).init(3, 3, &starts, &rows, &vals, .{
        .attributes = .{ .kind = .hermitian, .triangle = .lower },
    });

    var b = [_]Z{ Z.init(6, 2), Z.init(7, 5), Z.init(15, -4) };
    var x = [_]Z{Z.init(0, 0)} ** 3;

    const status = try Iterative(Z).conjugateGradient(
        a,
        matrix.Dense(Z).fromSlice(&b),
        matrix.Dense(Z).fromSlice(&x),
        .{ .rtol = 1e-12 },
        null,
    );
    try testing.expectEqual(IterativeStatus.converged, status);

    for (0..3) |i| {
        const want: f64 = @floatFromInt(i + 1);
        try testing.expectApproxEqAbs(want, x[i].real, 1e-8);
        try testing.expectApproxEqAbs(@as(f64, 0), x[i].imag, 1e-8);
    }
}
