//! Direct sparse solvers: factor a matrix once, then solve with it repeatedly.
//!
//! ```zig
//! var f = try Factorization(f64).init(alloc, .cholesky, a, .{});
//! defer f.deinit();
//! try f.solve(alloc, &b, &x);
//! ```
//!
//! ## What this adds over the C API
//!
//! * **Failure is a `try`, not a trap.** With `options.reportError == NULL` -
//!   the default - Sparse's parameter checks call `_SparseTrap()`, i.e.
//!   `__builtin_trap()`, killing the process. This binding installs a callback
//!   and checks the numeric `status` field, so both failure channels arrive as
//!   `SparseError`.
//! * **The solve workspace comes from a `std.mem.Allocator`.** Apple's inline
//!   `SparseSolve` wrappers `malloc` and `free` a scratch buffer on every call.
//!   The size is computable from public fields, so `solve` takes an allocator,
//!   and `solveWithWorkspace` takes a buffer the caller can hoist out of a loop
//!   entirely.
//!
//! ## What it does not
//!
//! `SymbolicOptions.malloc`/`free` - which is how Sparse allocates *the factor
//! itself* - take no context pointer, so a `std.mem.Allocator` cannot be
//! threaded through them without a process-global. This module passes libc's.
//! The factor allocation happens once per `init`; the workspace is the one that
//! recurs per solve, and that one is yours.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const matrix = @import("matrix.zig");

const Attributes = types.Attributes;
const SparseError = types.SparseError;
const FactorizationType = types.FactorizationType;

fn cMalloc(size: usize) callconv(.c) ?*anyopaque {
    return std.c.malloc(size);
}
fn cFree(pointer: ?*anyopaque) callconv(.c) void {
    std.c.free(pointer);
}

/// The number of positive, zero and negative pivots taken during an `LDL^T`
/// factorization.
pub const Inertia = struct {
    positive: u32,
    zero: u32,
    negative: u32,
};

/// A factorized sparse matrix.
pub fn Factorization(comptime T: type) type {
    return struct {
        const Self = @This();
        const Sparse = matrix.Sparse(T);
        const Dense = matrix.Dense(T);
        const f = c.fns(T);

        raw: c.OpaqueFactorization(T),

        /// Knobs for `init`. The defaults match Apple's
        /// `_SparseDefaultSymbolicFactorOptions` and the per-type
        /// `_SparseDefaultNumericFactorOptions`.
        pub const Options = struct {
            /// Fill-reducing ordering. `.default` picks AMD for symmetric
            /// factorizations and COLAMD for QR. `.colamd` is not valid for a
            /// symmetric factorization.
            order: types.Order = .default,
            /// An explicit permutation, used when `order == .user`. Must have
            /// one entry per column.
            user_order: ?[]c_int = null,
            /// Rows and columns to exclude from the factorization, terminated
            /// the way Sparse expects. Rarely needed.
            ignore_rows_and_columns: ?[]c_int = null,
            /// Diagonal scaling. `.default` is inf-norm equilibriation for
            /// `LDL^T` and none for Cholesky.
            scaling: types.Scaling = .default,
            /// Explicit scaling factors, used when `scaling == .user`. Also
            /// receives the computed scaling when non-null.
            user_scaling: ?[]T = null,
            /// Threshold for partial pivoting, clamped by Sparse to [0, 0.5].
            /// Null uses Apple's per-type recommendation: 0.01 for `f64`, 0.1
            /// for `f32`.
            pivot_tolerance: ?f64 = null,
            /// Values below this in absolute value are treated as zero. Null
            /// uses `1e-4 * eps(T)`. Raising it changes which pivots are
            /// considered zero, and so changes the reported `inertia`.
            zero_tolerance: ?f64 = null,

            fn symbolic(self: Options) c.SymbolicOptions {
                return .{
                    .orderMethod = self.order,
                    .order = if (self.user_order) |o| o.ptr else null,
                    .ignoreRowsAndColumns = if (self.ignore_rows_and_columns) |o| o.ptr else null,
                    .malloc = &cMalloc,
                    .free = &cFree,
                    .reportError = types.report_error_callback,
                };
            }

            fn numeric(self: Options) c.NumericOptions {
                const defaults = c.defaultNumericOptions(T);
                return .{
                    .scalingMethod = self.scaling,
                    .scaling = if (self.user_scaling) |s| @ptrCast(s.ptr) else null,
                    .pivotTolerance = self.pivot_tolerance orelse defaults.pivotTolerance,
                    .zeroTolerance = self.zero_tolerance orelse defaults.zeroTolerance,
                };
            }
        };

        /// Factorizes `a`.
        ///
        /// `algorithm` selects the factorization; see `FactorizationType`. Symmetric
        /// factorizations require `a.attributes.kind == .symmetric` and a
        /// square matrix - `SparseFactor` checks this and would trap, so it is
        /// checked here first.
        ///
        /// Takes no allocator: Sparse allocates the factor through
        /// `SymbolicOptions.malloc`, which has no context pointer. See the
        /// module docs.
        pub fn init(algorithm: FactorizationType, a: Sparse, options: Options) SparseError!Self {
            if (algorithm.isSymmetric()) {
                if (a.attributes.kind != .symmetric) return SparseError.ParameterError;
                if (a.row_count != a.column_count) return SparseError.ParameterError;
                // COLAMD orders A^T A and is meaningless for a symmetric
                // factorization; Sparse rejects it rather than silently coping.
                if (options.order == .colamd) return SparseError.ParameterError;
            }
            if (a.column_count == 0) return SparseError.ParameterError;
            if (options.order == .user) {
                if (options.user_order) |o| {
                    if (o.len < a.column_count) return SparseError.ParameterError;
                }
            }

            const sf = options.symbolic();
            const nf = options.numeric();
            const raw_a = a.raw();

            types.clearReportedError();
            const result = if (algorithm.isSymmetric())
                f.factorSymmetric(algorithm, &raw_a, &sf, &nf)
            else
                f.factorQR(algorithm, &raw_a, &sf, &nf);
            try types.takeReportedError();

            // Two statuses, checked separately: the symbolic phase can fail on
            // its own (ordering, structure), and the numeric phase can fail
            // afterwards (e.g. a non-positive-definite matrix under Cholesky).
            var out = Self{ .raw = result };
            errdefer out.deinit();
            try types.check(result.symbolicFactorization.status);
            try types.check(result.status);
            return out;
        }

        /// Releases the factorization. Safe to call more than once.
        pub fn deinit(self: *Self) void {
            // Destroying a factorization that never got off the ground would
            // otherwise walk a null `numericFactorization`.
            if (self.raw.numericFactorization != null or self.raw.symbolicFactorization.factorization != null) {
                f.destroyOpaqueNumeric(&self.raw);
            }
            self.raw.numericFactorization = null;
            self.raw.symbolicFactorization.factorization = null;
        }

        /// Adds a reference to the underlying factorization and returns a
        /// second handle to it. Both must be `deinit`ed.
        pub fn retain(self: *Self) Self {
            var copy = self.raw;
            f.retainNumeric(&copy);
            return .{ .raw = copy };
        }

        /// Number of scalar rows of the factored matrix.
        pub fn rowCount(self: Self) usize {
            const s = self.raw.symbolicFactorization;
            return @as(usize, @intCast(s.rowCount)) * s.blockSize;
        }

        /// Number of scalar columns of the factored matrix.
        pub fn columnCount(self: Self) usize {
            const s = self.raw.symbolicFactorization;
            return @as(usize, @intCast(s.columnCount)) * s.blockSize;
        }

        /// The factorization algorithm that was used.
        pub fn kind(self: Self) FactorizationType {
            return self.raw.symbolicFactorization.type;
        }

        /// Bytes of scratch space `solveWithWorkspace` needs for `nrhs`
        /// right-hand sides.
        ///
        /// This is the formula Apple's inline `SparseSolve` uses to size its
        /// internal `malloc`, exposed so the allocation can be hoisted out of a
        /// solve loop.
        pub fn workspaceSize(self: Self, nrhs: usize) usize {
            return self.raw.solveWorkspaceRequiredStatic +
                nrhs * self.raw.solveWorkspaceRequiredPerRHS;
        }

        /// Solves `A x = b`, allocating the scratch buffer for the call.
        pub fn solve(self: Self, allocator: std.mem.Allocator, b: []const T, x: []T) (SparseError || std.mem.Allocator.Error)!void {
            return self.solveMatrix(
                allocator,
                Dense.fromSlice(@constCast(b)),
                Dense.fromSlice(x),
            );
        }

        /// Solves `A x = b` in place: `xb` holds `b` on entry and `x` on exit.
        ///
        /// For a non-square system `xb` must be `max(rows, columns)` long, not
        /// just the size of the solution.
        pub fn solveInPlace(self: Self, allocator: std.mem.Allocator, xb: []T) (SparseError || std.mem.Allocator.Error)!void {
            return self.solveMatrixInPlace(allocator, Dense.fromSlice(xb));
        }

        /// Multi-right-hand-side out-of-place solve.
        pub fn solveMatrix(self: Self, allocator: std.mem.Allocator, b: Dense, x: Dense) (SparseError || std.mem.Allocator.Error)!void {
            const workspace = try allocator.alignedAlloc(u8, .@"16", self.workspaceSize(b.rhsCount()));
            defer allocator.free(workspace);
            return self.solveWithWorkspace(b, x, workspace);
        }

        /// Multi-right-hand-side in-place solve.
        pub fn solveMatrixInPlace(self: Self, allocator: std.mem.Allocator, xb: Dense) (SparseError || std.mem.Allocator.Error)!void {
            const workspace = try allocator.alignedAlloc(u8, .@"16", self.workspaceSize(xb.rhsCount()));
            defer allocator.free(workspace);
            return self.solveWithWorkspace(null, xb, workspace);
        }

        /// Solves using a caller-supplied scratch buffer, so a loop of solves
        /// can allocate once.
        ///
        /// Passing `null` for `b` means an in-place solve, with `x` holding the
        /// right-hand side on entry. `workspace` must be at least
        /// `workspaceSize(x.rhsCount())` bytes.
        pub fn solveWithWorkspace(self: Self, b: ?Dense, x: Dense, workspace: []align(16) u8) SparseError!void {
            std.debug.assert(workspace.len >= self.workspaceSize(x.rhsCount()));

            const rows = self.rowCount();
            const cols = self.columnCount();
            if (b) |rhs| {
                std.debug.assert(rhs.rhsCount() == x.rhsCount());
                // For QR the residual lives in `b`, so it is sized by the row
                // count; every other factorization solves a square system.
                const expected_b = if (self.kind() == .qr) rows else cols;
                std.debug.assert(rhs.size() == expected_b);
                std.debug.assert(x.size() == cols);
            } else {
                // In place, the one buffer has to hold both, so it is sized by
                // the larger dimension.
                std.debug.assert(x.size() == @max(rows, cols));
            }

            const raw_x = x.raw();
            const raw_b = if (b) |rhs| rhs.raw() else null;

            types.clearReportedError();
            f.solveOpaque(
                &self.raw,
                if (raw_b) |*p| p else null,
                &raw_x,
                workspace.ptr,
            );
            return types.takeReportedError();
        }

        /// Bytes of scratch space `refactorWithWorkspace` needs.
        ///
        /// Unlike the solve workspace this does not scale with anything the
        /// caller chooses; it is fixed by the symbolic factorization.
        pub fn refactorWorkspaceSize(self: Self) usize {
            const s = self.raw.symbolicFactorization;
            return switch (T) {
                f64 => s.workspaceSize_Double,
                f32 => s.workspaceSize_Float,
                else => unreachable,
            };
        }

        /// Recomputes the numeric factorization for a matrix with the *same*
        /// sparsity pattern but different values, reusing this object's memory.
        ///
        /// This is the payoff for repeated solves on a structurally fixed
        /// problem: the ordering and symbolic analysis - usually the expensive
        /// part - are not redone.
        pub fn refactor(self: *Self, allocator: std.mem.Allocator, a: Sparse, options: Options) (SparseError || std.mem.Allocator.Error)!void {
            const workspace = try allocator.alignedAlloc(u8, .@"16", self.refactorWorkspaceSize());
            defer allocator.free(workspace);
            return self.refactorWithWorkspace(a, options, workspace);
        }

        /// `refactor` with a caller-supplied scratch buffer, for refactoring in
        /// a loop without reallocating.
        ///
        /// `workspace` must be at least `refactorWorkspaceSize()` bytes. It is
        /// `_Nonnull` on the C side and is *not* optional: passing null does
        /// not fall back to an internal allocation, it hangs.
        pub fn refactorWithWorkspace(self: *Self, a: Sparse, options: Options, workspace: []align(16) u8) SparseError!void {
            std.debug.assert(workspace.len >= self.refactorWorkspaceSize());

            const s = self.raw.symbolicFactorization;
            // SPARSE_CHECK_MATCH_SYMB_FACTOR checks exactly these four; a
            // mismatch would trap.
            if (a.row_count != @as(usize, @intCast(s.rowCount))) return SparseError.ParameterError;
            if (a.column_count != @as(usize, @intCast(s.columnCount))) return SparseError.ParameterError;
            if (a.block_size != s.blockSize) return SparseError.ParameterError;
            if (a.attributes.transpose != s.attributes.transpose) return SparseError.ParameterError;

            const nf = options.numeric();
            const raw_a = a.raw();

            types.clearReportedError();
            if (self.kind().isSymmetric()) {
                f.refactorSymmetric(&raw_a, &self.raw, &nf, workspace.ptr);
            } else {
                f.refactorQR(&raw_a, &self.raw, &nf, workspace.ptr);
            }
            try types.takeReportedError();
            try types.check(self.raw.status);
        }

        /// Counts of positive, zero and negative pivots.
        ///
        /// Only meaningful for an `LDL^T` factorization. Near-zero eigenvalues
        /// make the computed inertia sensitive to `Options.zero_tolerance`, so
        /// treat it as a numerical result rather than an exact one.
        pub fn inertia(self: Self) SparseError!Inertia {
            switch (self.kind()) {
                .ldlt, .ldlt_unpivoted, .ldlt_sbk, .ldlt_tpp => {},
                else => return SparseError.ParameterError,
            }

            var positive: c_int = 0;
            var zero: c_int = 0;
            var negative: c_int = 0;

            types.clearReportedError();
            const status = f.getInertia(self.raw, &positive, &zero, &negative);
            try types.takeReportedError();
            try types.check(status);

            return .{
                .positive = @intCast(positive),
                .zero = @intCast(zero),
                .negative = @intCast(negative),
            };
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const TestMatrix = matrix.TestMatrix;

fn tol(comptime T: type) T {
    return if (T == f64) 1e-10 else 1e-4;
}

test "Cholesky factor and solve, both element types" {
    inline for (.{ f64, f32 }) |T| {
        const vals = TestMatrix.values(T);
        const a = TestMatrix.matrix(T, &vals);

        var fac = try Factorization(T).init(.cholesky, a, .{});
        defer fac.deinit();

        try testing.expectEqual(@as(usize, 4), fac.rowCount());
        try testing.expectEqual(@as(usize, 4), fac.columnCount());
        try testing.expectEqual(FactorizationType.cholesky, fac.kind());

        var b = TestMatrix.rhs(T);
        var x = [_]T{0} ** 4;
        try fac.solve(testing.allocator, &b, &x);

        for (TestMatrix.solution(T), x) |want, got| {
            try testing.expectApproxEqAbs(want, got, tol(T));
        }
    }
}

test "every symmetric factorization type reaches the same solution" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);

    inline for (.{ .cholesky, .ldlt, .ldlt_unpivoted, .ldlt_sbk, .ldlt_tpp }) |kind| {
        var fac = try Factorization(f64).init(kind, a, .{});
        defer fac.deinit();

        var b = TestMatrix.rhs(f64);
        var x = [_]f64{0} ** 4;
        try fac.solve(testing.allocator, &b, &x);
        for (TestMatrix.solution(f64), x) |want, got| {
            try testing.expectApproxEqAbs(want, got, 1e-10);
        }
    }
}

test "in-place solve overwrites the right-hand side" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    var fac = try Factorization(f64).init(.cholesky, a, .{});
    defer fac.deinit();

    var xb = TestMatrix.rhs(f64);
    try fac.solveInPlace(testing.allocator, &xb);
    for (TestMatrix.solution(f64), xb) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-10);
    }
}

test "solveWithWorkspace reuses one buffer across many solves" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    var fac = try Factorization(f64).init(.cholesky, a, .{});
    defer fac.deinit();

    const workspace = try testing.allocator.alignedAlloc(u8, .@"16", fac.workspaceSize(1));
    defer testing.allocator.free(workspace);

    // Solving A x = A e_j must return e_j, for every j.
    for (0..4) |j| {
        var e = [_]f64{0} ** 4;
        e[j] = 1;
        var b = [_]f64{0} ** 4;
        try a.multiply(1, matrix.Dense(f64).fromSlice(&e), matrix.Dense(f64).fromSlice(&b), false);

        var x = [_]f64{0} ** 4;
        try fac.solveWithWorkspace(
            matrix.Dense(f64).fromSlice(&b),
            matrix.Dense(f64).fromSlice(&x),
            workspace,
        );
        for (e, x) |want, got| try testing.expectApproxEqAbs(want, got, 1e-10);
    }
}

test "workspaceSize is the documented linear function of nrhs" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    var fac = try Factorization(f64).init(.cholesky, a, .{});
    defer fac.deinit();

    const static = fac.raw.solveWorkspaceRequiredStatic;
    const per_rhs = fac.raw.solveWorkspaceRequiredPerRHS;
    try testing.expectEqual(static, fac.workspaceSize(0));
    try testing.expectEqual(static + per_rhs, fac.workspaceSize(1));
    try testing.expectEqual(static + 7 * per_rhs, fac.workspaceSize(7));
}

test "multi-RHS solve inverts the matrix column by column" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    var fac = try Factorization(f64).init(.cholesky, a, .{});
    defer fac.deinit();

    // Right-hand sides are the four columns of A, so the solution is I.
    var b = [_]f64{0} ** 16;
    for (0..4) |j| {
        var e = [_]f64{0} ** 4;
        e[j] = 1;
        var col = [_]f64{0} ** 4;
        try a.multiply(1, matrix.Dense(f64).fromSlice(&e), matrix.Dense(f64).fromSlice(&col), false);
        @memcpy(b[j * 4 ..][0..4], &col);
    }

    var x = [_]f64{0} ** 16;
    try fac.solveMatrix(
        testing.allocator,
        matrix.Dense(f64).init(&b, 4, 4, 4),
        matrix.Dense(f64).init(&x, 4, 4, 4),
    );

    for (0..4) |j| {
        for (0..4) |i| {
            const want: f64 = if (i == j) 1 else 0;
            try testing.expectApproxEqAbs(want, x[j * 4 + i], 1e-10);
        }
    }
}

test "Cholesky of an indefinite matrix fails instead of trapping" {
    // diag(2, -3, 4, -5) is symmetric but not positive-definite.
    const starts = [_]c_long{ 0, 1, 2, 3, 4 };
    const idx = [_]c_int{ 0, 1, 2, 3 };
    const vals = [_]f64{ 2, -3, 4, -5 };
    const a = matrix.Sparse(f64).init(4, 4, &starts, &idx, &vals, .{
        .attributes = .{ .kind = .symmetric, .triangle = .lower },
    });

    try testing.expectError(
        SparseError.FactorizationFailed,
        Factorization(f64).init(.cholesky, a, .{}),
    );
}

test "a symmetric factorization rejects a matrix that is not marked symmetric" {
    const vals = TestMatrix.values(f64);
    // Same storage, but declared ordinary.
    const a = matrix.Sparse(f64).init(4, 4, &TestMatrix.column_starts, &TestMatrix.row_indices, &vals, .{});

    try testing.expectError(
        SparseError.ParameterError,
        Factorization(f64).init(.cholesky, a, .{}),
    );
}

test "COLAMD is rejected for a symmetric factorization" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    try testing.expectError(
        SparseError.ParameterError,
        Factorization(f64).init(.cholesky, a, .{ .order = .colamd }),
    );
}

test "inertia counts pivots of an indefinite LDL^T" {
    const starts = [_]c_long{ 0, 1, 2, 3, 4 };
    const idx = [_]c_int{ 0, 1, 2, 3 };
    const vals = [_]f64{ 2, -3, 4, -5 };
    const a = matrix.Sparse(f64).init(4, 4, &starts, &idx, &vals, .{
        .attributes = .{ .kind = .symmetric, .triangle = .lower },
    });

    var fac = try Factorization(f64).init(.ldlt, a, .{});
    defer fac.deinit();

    const n = try fac.inertia();
    try testing.expectEqual(@as(u32, 2), n.positive);
    try testing.expectEqual(@as(u32, 0), n.zero);
    try testing.expectEqual(@as(u32, 2), n.negative);
}

test "inertia is rejected for a non-LDL^T factorization" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    var fac = try Factorization(f64).init(.cholesky, a, .{});
    defer fac.deinit();
    try testing.expectError(SparseError.ParameterError, fac.inertia());
}

test "refactor reuses the symbolic analysis for new values" {
    var vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    var fac = try Factorization(f64).init(.cholesky, a, .{});
    defer fac.deinit();

    // Same pattern, doubled values: A' = 2A, so A' x = 2b has the same x.
    var doubled: [7]f64 = undefined;
    for (vals, 0..) |v, i| doubled[i] = 2 * v;
    const a2 = TestMatrix.matrix(f64, &doubled);
    try fac.refactor(testing.allocator, a2, .{});

    var b = TestMatrix.rhs(f64);
    for (&b) |*v| v.* *= 2;
    var x = [_]f64{0} ** 4;
    try fac.solve(testing.allocator, &b, &x);
    for (TestMatrix.solution(f64), x) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-10);
    }
}

test "refactor rejects a different sparsity pattern" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    var fac = try Factorization(f64).init(.cholesky, a, .{});
    defer fac.deinit();

    // A 3x3 diagonal matrix: right kind, wrong size.
    const starts = [_]c_long{ 0, 1, 2, 3 };
    const idx = [_]c_int{ 0, 1, 2 };
    const small_vals = [_]f64{ 1, 1, 1 };
    const small = matrix.Sparse(f64).init(3, 3, &starts, &idx, &small_vals, .{
        .attributes = .{ .kind = .symmetric, .triangle = .lower },
    });

    try testing.expectError(SparseError.ParameterError, fac.refactor(testing.allocator, small, .{}));
}

test "QR solves a least-squares problem" {
    // Overdetermined 4x2 system whose exact solution is [1, 2]:
    //   [1 0]        [1]
    //   [0 1] [1] =  [2]
    //   [1 1] [2]    [3]
    //   [1 2]        [5]
    const starts = [_]c_long{ 0, 3, 6 };
    const idx = [_]c_int{ 0, 2, 3, 1, 2, 3 };
    const vals = [_]f64{ 1, 1, 1, 1, 1, 2 };
    const a = matrix.Sparse(f64).init(4, 2, &starts, &idx, &vals, .{});

    var fac = try Factorization(f64).init(.qr, a, .{});
    defer fac.deinit();

    try testing.expectEqual(@as(usize, 4), fac.rowCount());
    try testing.expectEqual(@as(usize, 2), fac.columnCount());

    var b = [_]f64{ 1, 2, 3, 5 };
    var x = [_]f64{ 0, 0 };
    try fac.solve(testing.allocator, &b, &x);

    try testing.expectApproxEqAbs(@as(f64, 1), x[0], 1e-10);
    try testing.expectApproxEqAbs(@as(f64, 2), x[1], 1e-10);
}

test "retain keeps the factorization alive past the first deinit" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    var first = try Factorization(f64).init(.cholesky, a, .{});
    var second = first.retain();
    defer second.deinit();

    first.deinit();

    // The second handle must still solve correctly.
    var b = TestMatrix.rhs(f64);
    var x = [_]f64{0} ** 4;
    try second.solve(testing.allocator, &b, &x);
    for (TestMatrix.solution(f64), x) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-10);
    }
}

test "deinit is idempotent" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    var fac = try Factorization(f64).init(.cholesky, a, .{});
    fac.deinit();
    fac.deinit();
}

test "solving from a matrix built by fromCoordinate" {
    const alloc = testing.allocator;
    const rows = [_]c_int{ 0, 1, 1, 2, 2, 3, 3 };
    const cols = [_]c_int{ 0, 0, 1, 1, 2, 2, 3 };
    const vals = [_]f64{ 2, 1, 3, 1, 4, 1, 5 };

    var a = try matrix.Sparse(f64).fromCoordinate(alloc, 4, 4, &rows, &cols, &vals, .{
        .attributes = .{ .kind = .symmetric, .triangle = .lower },
    });
    defer a.deinit(alloc);

    var fac = try Factorization(f64).init(.cholesky, a, .{});
    defer fac.deinit();

    var b = TestMatrix.rhs(f64);
    var x = [_]f64{0} ** 4;
    try fac.solve(alloc, &b, &x);
    for (TestMatrix.solution(f64), x) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-10);
    }
}

test "refactorWorkspaceSize reports the symbolic factorization's requirement" {
    // Pins the field this reads. The C wrapper sizes its own workspace from the
    // same field, and passing a null workspace to `_SparseRefactor*` does not
    // fall back to an internal allocation - it hangs - so a zero or wrong size
    // here is not a benign mistake.
    inline for (.{ f64, f32 }) |T| {
        const vals = TestMatrix.values(T);
        const a = TestMatrix.matrix(T, &vals);
        var fac = try Factorization(T).init(.cholesky, a, .{});
        defer fac.deinit();

        const s = fac.raw.symbolicFactorization;
        const expected = if (T == f64) s.workspaceSize_Double else s.workspaceSize_Float;
        try testing.expectEqual(expected, fac.refactorWorkspaceSize());
        try testing.expect(fac.refactorWorkspaceSize() > 0);
    }
}

test "refactorWithWorkspace reuses one buffer across a sequence of value updates" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    var fac = try Factorization(f64).init(.cholesky, a, .{});
    defer fac.deinit();

    const workspace = try testing.allocator.alignedAlloc(u8, .@"16", fac.refactorWorkspaceSize());
    defer testing.allocator.free(workspace);
    const solve_workspace = try testing.allocator.alignedAlloc(u8, .@"16", fac.workspaceSize(1));
    defer testing.allocator.free(solve_workspace);

    // Scaling A by k scales the right-hand side by k and leaves x unchanged.
    for ([_]f64{ 1, 3, 0.5, 10 }) |k| {
        var scaled: [7]f64 = undefined;
        for (vals, 0..) |v, i| scaled[i] = k * v;
        try fac.refactorWithWorkspace(TestMatrix.matrix(f64, &scaled), .{}, workspace);

        var b = TestMatrix.rhs(f64);
        for (&b) |*v| v.* *= k;
        var x = [_]f64{0} ** 4;
        try fac.solveWithWorkspace(
            matrix.Dense(f64).fromSlice(&b),
            matrix.Dense(f64).fromSlice(&x),
            solve_workspace,
        );
        for (TestMatrix.solution(f64), x) |want, got| {
            try testing.expectApproxEqAbs(want, got, 1e-10);
        }
    }
}
