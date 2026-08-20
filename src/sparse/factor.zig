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
            ///
            /// Real even for a complex matrix. `Solve.h` types this as
            /// `void *` and never says what it points at; the element type
            /// here follows `_SPARSE_REAL_SIZE`, which sizes every other
            /// complex buffer as twice the real one - i.e. treats the complex
            /// case as real data - and matches a diagonal scaling being a
            /// magnitude. Unverified against a running solver.
            user_scaling: ?[]types.Real(T) = null,
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
                // For a complex matrix `SparseFactor` accepts either kind and
                // routes Hermitian to its own entry point; for a real one only
                // `.symmetric` exists.
                const kind_ok = if (comptime types.isComplex(T))
                    a.attributes.kind == .symmetric or a.attributes.kind == .hermitian
                else
                    a.attributes.kind == .symmetric;
                if (!kind_ok) return SparseError.ParameterError;
                if (a.row_count != a.column_count) return SparseError.ParameterError;
                // COLAMD orders A^T A and is meaningless for a symmetric
                // factorization; Sparse rejects it rather than silently coping.
                if (options.order == .colamd) return SparseError.ParameterError;
            }
            // LU is square-only. `SparseFactorLU` traps on a rectangular
            // matrix rather than reporting it.
            if (algorithm.isLu() and a.row_count != a.column_count) return SparseError.ParameterError;
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
            const result = if (algorithm.isLu())
                f.factorLU(algorithm, &raw_a, &sf, &nf)
            else if (!algorithm.isSymmetric())
                f.factorQR(algorithm, &raw_a, &sf, &nf)
            else if (comptime types.isComplex(T))
                // Complex symmetric (`A = A^T`) and complex Hermitian
                // (`A = A^H`) are genuinely different problems with separate
                // entry points. Hermitian arrived in macOS 15.5; complex
                // symmetric needs macOS 26, and calling it on anything older
                // traps inside vecLib.
                (if (a.attributes.kind == .hermitian)
                    f.factorHermitian(algorithm, &raw_a, &sf, &nf)
                else
                    f.factorSymmetric(algorithm, &raw_a, &sf, &nf))
            else
                f.factorSymmetric(algorithm, &raw_a, &sf, &nf);
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
            // `SparseOpaqueSymbolicFactorization` carries only the two *real*
            // sizes. For a complex element type Apple's `_SPARSE_REAL_SIZE`
            // macro doubles the matching real one, which is where the factor
            // of two comes from - there is no `workspaceSize_Complex_Double`
            // field to read instead.
            const real = switch (types.Real(T)) {
                f64 => s.workspaceSize_Double,
                f32 => s.workspaceSize_Float,
                else => unreachable,
            };
            return if (comptime types.isComplex(T)) real * 2 else real;
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
            if (self.kind().isLu()) {
                f.refactorLU(&raw_a, &self.raw, &nf, workspace.ptr);
            } else if (!self.kind().isSymmetric()) {
                f.refactorQR(&raw_a, &self.raw, &nf, workspace.ptr);
            } else if (comptime types.isComplex(T)) {
                if (a.attributes.kind == .hermitian) {
                    f.refactorHermitian(&raw_a, &self.raw, &nf, workspace.ptr);
                } else {
                    f.refactorSymmetric(&raw_a, &self.raw, &nf, workspace.ptr);
                }
            } else {
                f.refactorSymmetric(&raw_a, &self.raw, &nf, workspace.ptr);
            }
            try types.takeReportedError();
            try types.check(self.raw.status);
        }

        /// Partially refactorizes after a few columns of `A` changed.
        ///
        /// `SparseUpdateFactor`. Where `refactor` redoes the whole numeric
        /// factorization, this redoes only the parts that depend on the
        /// columns named in `updated_indices`, which for a sparse update of a
        /// few columns is much cheaper.
        ///
        /// LU only, and specifically the three explicitly-pivoted spellings -
        /// `.lu` itself, the alias, is rejected. `update` must have the same
        /// sparsity pattern as the matrix originally factored.
        pub fn updateLu(self: *Self, updated_indices: []const c_int, update: Sparse) SparseError!void {
            switch (self.kind()) {
                .lu_unpivoted, .lu_spp, .lu_tpp => {},
                else => return SparseError.ParameterError,
            }

            const s = self.raw.symbolicFactorization;
            // The same four checks SPARSE_CHECK_MATCH_SYMB_FACTOR makes; a
            // mismatch would trap rather than report.
            if (update.row_count != @as(usize, @intCast(s.rowCount))) return SparseError.ParameterError;
            if (update.column_count != @as(usize, @intCast(s.columnCount))) return SparseError.ParameterError;
            if (update.block_size != s.blockSize) return SparseError.ParameterError;
            if (update.attributes.transpose != s.attributes.transpose) return SparseError.ParameterError;

            types.clearReportedError();
            f.updatePartialRefactorLU(
                &self.raw,
                @intCast(updated_indices.len),
                updated_indices.ptr,
                update.raw(),
            );
            try types.takeReportedError();
            try types.check(self.raw.status);
        }

        /// Counts of positive, zero and negative pivots.
        ///
        /// Only meaningful for an `LDL^T` factorization. Near-zero eigenvalues
        /// make the computed inertia sensitive to `Options.zero_tolerance`, so
        /// treat it as a numerical result rather than an exact one.
        pub fn inertia(self: Self) SparseError!Inertia {
            if (comptime types.isComplex(T)) {
                @compileError("inertia is defined for real symmetric factorizations only; " ++
                    "vecLib exports no complex SparseGetInertia");
            }
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

// ---------------------------------------------------------------------------
// LU
// ---------------------------------------------------------------------------

/// A deliberately non-symmetric 4x4, in full CSC:
///
///     [ 4  1  0  0 ]
///     [ 1  3  1  0 ]
///     [ 0  2  5  1 ]
///     [ 0  0  1  2 ]
///
/// `a[2][1] = 2` against `a[1][2] = 1` is what makes it non-symmetric, and so
/// makes it a matrix LU can factor and Cholesky/LDL^T cannot.
const LuMatrix = struct {
    const column_starts = [_]c_long{ 0, 2, 5, 8, 10 };
    const row_indices = [_]c_int{ 0, 1, 0, 1, 2, 1, 2, 3, 2, 3 };
    fn values(comptime T: type) [10]T {
        return .{ 4, 1, 1, 3, 2, 1, 5, 1, 1, 2 };
    }
    /// `A * [1, 2, 3, 4]^T`.
    fn rhs(comptime T: type) [4]T {
        return .{ 6, 10, 23, 11 };
    }
    fn solution(comptime T: type) [4]T {
        return .{ 1, 2, 3, 4 };
    }
    fn make(comptime T: type, vals: []const T) matrix.Sparse(T) {
        return matrix.Sparse(T).init(4, 4, &column_starts, &row_indices, vals, .{});
    }
};

test "LU factors a non-symmetric matrix and solves, all four pivoting modes" {
    // Requires macOS 15.5; on an older system vecLib traps rather than
    // returning a status, so there is no graceful degradation to test.
    inline for (.{ f64, f32 }) |T| {
        inline for (.{ FactorizationType.lu, .lu_unpivoted, .lu_spp, .lu_tpp }) |algorithm| {
            const vals = LuMatrix.values(T);
            const a = LuMatrix.make(T, &vals);
            var fac = try Factorization(T).init(algorithm, a, .{});
            defer fac.deinit();

            // Measured: `.lu` is not stored as itself. The symbolic factor
            // records `.lu_tpp`, which is what Solve.h means by "Default LU
            // factorization (currently LU with TPP)". Everything downstream -
            // `updateLu`, `Subfactor.isValidFor` - sees the resolved value,
            // never the alias.
            const expected_kind = if (algorithm == .lu) FactorizationType.lu_tpp else algorithm;
            try testing.expectEqual(expected_kind, fac.kind());

            var b = LuMatrix.rhs(T);
            var x = [_]T{0} ** 4;
            try fac.solve(testing.allocator, &b, &x);

            const want = LuMatrix.solution(T);
            for (0..4) |i| try testing.expectApproxEqAbs(want[i], x[i], tol(T));
        }
    }
}

test "Cholesky rejects the non-symmetric matrix LU accepts" {
    // The complement of the test above: the same matrix, and the reason LU
    // needed binding at all. `.ordinary` is not `.symmetric`, and `init`
    // catches that before Sparse can trap on it.
    const vals = LuMatrix.values(f64);
    const a = LuMatrix.make(f64, &vals);
    try testing.expectError(SparseError.ParameterError, Factorization(f64).init(.cholesky, a, .{}));
}

test "LU is rejected for a rectangular matrix" {
    // 3x2, structurally fine, but LU is square-only and SparseFactorLU would
    // trap rather than report.
    const starts = [_]c_long{ 0, 2, 4 };
    const rows = [_]c_int{ 0, 1, 1, 2 };
    const vals = [_]f64{ 1, 2, 3, 4 };
    const a = matrix.Sparse(f64).init(3, 2, &starts, &rows, &vals, .{});
    try testing.expectError(SparseError.ParameterError, Factorization(f64).init(.lu, a, .{}));
}

test "inertia is rejected for an LU factorization" {
    const vals = LuMatrix.values(f64);
    const a = LuMatrix.make(f64, &vals);
    var fac = try Factorization(f64).init(.lu_tpp, a, .{});
    defer fac.deinit();
    try testing.expectError(SparseError.ParameterError, fac.inertia());
}

test "LU refactor reuses the symbolic analysis for new values" {
    const vals = LuMatrix.values(f64);
    const a = LuMatrix.make(f64, &vals);
    var fac = try Factorization(f64).init(.lu_tpp, a, .{});
    defer fac.deinit();

    // Same pattern, every value doubled: the solution of A' x = b is half
    // what it was, which a stale numeric factor would not produce.
    var doubled: [10]f64 = undefined;
    for (vals, 0..) |v, i| doubled[i] = v * 2;
    const a2 = LuMatrix.make(f64, &doubled);
    try fac.refactor(testing.allocator, a2, .{});

    var b = LuMatrix.rhs(f64);
    var x = [_]f64{0} ** 4;
    try fac.solve(testing.allocator, &b, &x);

    const want = LuMatrix.solution(f64);
    for (0..4) |i| try testing.expectApproxEqAbs(want[i] / 2, x[i], tol(f64));
}

test "updateLu is LU-only and refactors after a column change" {
    {
        // Rejected for a factorization that is not LU. SparseUpdateFactor
        // handles only the three pivoted LU spellings, and since `.lu`
        // resolves to `.lu_tpp` at factor time, every LU reaches it.
        const vals = TestMatrix.values(f64);
        const a = TestMatrix.matrix(f64, &vals);
        var fac = try Factorization(f64).init(.cholesky, a, .{});
        defer fac.deinit();
        const idx = [_]c_int{0};
        try testing.expectError(SparseError.ParameterError, fac.updateLu(&idx, a));
    }
    {
        const vals = LuMatrix.values(f64);
        const a = LuMatrix.make(f64, &vals);
        var fac = try Factorization(f64).init(.lu_tpp, a, .{});
        defer fac.deinit();

        var updated = LuMatrix.values(f64);
        updated[0] = 8; // a[0][0]: 4 -> 8, which lives in column 0
        const a2 = LuMatrix.make(f64, &updated);
        const changed = [_]c_int{0};
        try fac.updateLu(&changed, a2);

        // Solve against the updated matrix's own right-hand side. With
        // a[0][0] = 8, A * [1,2,3,4]^T has first entry 8 + 2 = 10.
        var b = LuMatrix.rhs(f64);
        b[0] = 10;
        var x = [_]f64{0} ** 4;
        try fac.solve(testing.allocator, &b, &x);

        const want = LuMatrix.solution(f64);
        for (0..4) |i| try testing.expectApproxEqAbs(want[i], x[i], tol(f64));
    }
}

// ---------------------------------------------------------------------------
// Complex
// ---------------------------------------------------------------------------

/// A 3x3 Hermitian positive-definite matrix, lower triangle in CSC:
///
///     [  4     1+i    0   ]
///     [ 1-i     3    2i   ]
///     [  0    -2i     5   ]
///
/// Leading minors 4, 10 and 34 are all positive, so Cholesky succeeds.
const HermitianMatrix = struct {
    const column_starts = [_]c_long{ 0, 2, 4, 5 };
    const row_indices = [_]c_int{ 0, 1, 1, 2, 2 };
    fn values(comptime R: type) [5]types.Complex(R) {
        const Z = types.Complex(R);
        // Column-major over the lower triangle: (0,0), (1,0), (1,1), (2,1), (2,2).
        return .{ Z.init(4, 0), Z.init(1, -1), Z.init(3, 0), Z.init(0, -2), Z.init(5, 0) };
    }
    /// `A * [1, 2, 3]^T`.
    fn rhs(comptime R: type) [3]types.Complex(R) {
        const Z = types.Complex(R);
        return .{ Z.init(6, 2), Z.init(7, 5), Z.init(15, -4) };
    }
    fn make(comptime R: type, vals: []const types.Complex(R)) matrix.Sparse(types.Complex(R)) {
        return matrix.Sparse(types.Complex(R)).init(3, 3, &column_starts, &row_indices, vals, .{
            .attributes = .{ .kind = .hermitian, .triangle = .lower },
        });
    }
};

test "complex Hermitian Cholesky factors and solves" {
    // Requires macOS 15.5. Complex *symmetric* (kind .symmetric, A = A^T) is
    // a different entry point that needs macOS 26 and is deliberately not
    // exercised here.
    inline for (.{ f64, f32 }) |R| {
        const Z = types.Complex(R);
        const vals = HermitianMatrix.values(R);
        const a = HermitianMatrix.make(R, &vals);

        var fac = try Factorization(Z).init(.cholesky, a, .{});
        defer fac.deinit();

        var b = HermitianMatrix.rhs(R);
        var x = [_]Z{Z.init(0, 0)} ** 3;
        try fac.solve(testing.allocator, &b, &x);

        for (0..3) |i| {
            const want: R = @floatFromInt(i + 1);
            try testing.expectApproxEqAbs(want, x[i].real, tol(R));
            try testing.expectApproxEqAbs(@as(R, 0), x[i].imag, tol(R));
        }
    }
}

test "complex LDL^T solves the same Hermitian system" {
    const Z = types.Complex(f64);
    const vals = HermitianMatrix.values(f64);
    const a = HermitianMatrix.make(f64, &vals);

    var fac = try Factorization(Z).init(.ldlt, a, .{});
    defer fac.deinit();

    var b = HermitianMatrix.rhs(f64);
    var x = [_]Z{Z.init(0, 0)} ** 3;
    try fac.solve(testing.allocator, &b, &x);

    for (0..3) |i| {
        const want: f64 = @floatFromInt(i + 1);
        try testing.expectApproxEqAbs(want, x[i].real, tol(f64));
        try testing.expectApproxEqAbs(@as(f64, 0), x[i].imag, tol(f64));
    }
}

test "complex LU factors a non-Hermitian matrix" {
    const Z = types.Complex(f64);
    // The real LU matrix with an imaginary part added to one off-diagonal, so
    // it is neither Hermitian nor symmetric.
    const starts = LuMatrix.column_starts;
    const rows = LuMatrix.row_indices;
    var vals: [10]Z = undefined;
    const real_vals = LuMatrix.values(f64);
    for (real_vals, 0..) |v, i| vals[i] = Z.init(v, 0);
    vals[4] = Z.init(2, 1); // a[2][1] = 2 + i

    const a = matrix.Sparse(Z).init(4, 4, &starts, &rows, &vals, .{});
    var fac = try Factorization(Z).init(.lu_tpp, a, .{});
    defer fac.deinit();

    // b = A * [1, 2, 3, 4]^T. Only row 2 changes from the real case: the
    // 2 + i entry multiplies x[1] = 2, adding 2i.
    var b = [_]Z{ Z.init(6, 0), Z.init(10, 0), Z.init(23, 2), Z.init(11, 0) };
    var x = [_]Z{Z.init(0, 0)} ** 4;
    try fac.solve(testing.allocator, &b, &x);

    for (0..4) |i| {
        const want: f64 = @floatFromInt(i + 1);
        try testing.expectApproxEqAbs(want, x[i].real, tol(f64));
        try testing.expectApproxEqAbs(@as(f64, 0), x[i].imag, tol(f64));
    }
}

test "complex factorization rejects an ordinary matrix for a symmetric algorithm" {
    const Z = types.Complex(f64);
    const vals = HermitianMatrix.values(f64);
    const a = matrix.Sparse(Z).init(3, 3, &HermitianMatrix.column_starts, &HermitianMatrix.row_indices, &vals, .{});
    try testing.expectError(SparseError.ParameterError, Factorization(Z).init(.cholesky, a, .{}));
}
