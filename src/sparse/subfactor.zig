//! Individual factors of a factorization: `L`, `D`, `P`, `S`, `Q`, `R`.
//!
//! A `Factorization` solves `A x = b` in one step. A `Subfactor` gives access
//! to the pieces, so you can apply `L` on its own, or use `PLP'` to split a
//! solve into a transpose half and a non-transpose half.
//!
//! ```zig
//! var m = try Subfactor(f64).init(.plps, &fac);
//! defer m.deinit();
//! try m.solve(allocator, null, x);               // x <- M^-1 x
//! try m.transposed().solve(allocator, null, x);  // x <- M^-T x  => full solve
//! ```
//!
//! `SparseCreateSubfactor` is one of the entry points with no dylib symbol of
//! its own: it is pure inline C over `_SparseRetainNumeric` and
//! `_SparseGetWorkspaceRequired`. `init` below is that function transcribed,
//! including its table of which subfactor is valid for which factorization.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");
const matrix = @import("matrix.zig");
const factor = @import("factor.zig");

const Error = types.Error;

/// A retained reference to one factor of a `Factorization`.
///
/// Holds its own reference to the underlying factorization, so the parent may
/// be `deinit`ed while this is still alive.
pub fn Subfactor(comptime T: type) type {
    return struct {
        const Self = @This();
        const Dense = matrix.Dense(T);
        const f = c.fns(T);

        raw: c.OpaqueSubfactor(T),

        /// Extracts `which` from `parent`.
        ///
        /// Fails with `error.ParameterError` if the combination is not
        /// meaningful - `.d` of a Cholesky factorization, say, which has no
        /// diagonal factor. See `types.Subfactor.isValidFor`.
        pub fn init(which: types.Subfactor, parent: *const factor.Factorization(T)) Error!Self {
            const parent_kind = parent.raw.symbolicFactorization.type;
            if (!which.isValidFor(parent_kind)) return Error.ParameterError;
            if (parent.raw.numericFactorization == null) return Error.ParameterError;
            try types.check(parent.raw.symbolicFactorization.status);
            try types.check(parent.raw.status);

            // Attribute defaults come straight from SparseCreateSubfactor:
            // ordinary/lower unless the subfactor is triangular, and R is the
            // only upper-triangular one.
            var attributes = types.AttributesFor(T){ .triangle = .lower, .kind = .ordinary };
            switch (which) {
                .l => attributes.kind = .triangular,
                .r, .rp => {
                    attributes.kind = .triangular;
                    attributes.triangle = .upper;
                },
                // .plps stays ordinary: it is a product, not a triangle.
                else => {},
            }

            // Count the new reference before anything can fail, mirroring the
            // order in the C wrapper.
            var retained = parent.raw;
            f.retainNumeric(&retained);

            var static_bytes: usize = 0;
            var per_rhs_bytes: usize = 0;
            types.clearReportedError();
            f.getWorkspaceRequired(which, retained, &static_bytes, &per_rhs_bytes);
            types.takeReportedError() catch |e| {
                f.destroyOpaqueNumeric(&retained);
                return e;
            };

            return .{ .raw = .{
                .attributes = attributes,
                .contents = which,
                .factor = retained,
                .workspaceRequiredStatic = static_bytes,
                .workspaceRequiredPerRHS = per_rhs_bytes,
            } };
        }

        /// Releases this subfactor's reference to the factorization.
        pub fn deinit(self: *Self) void {
            if (self.raw.contents == .invalid) return;
            f.destroyOpaqueNumeric(&self.raw.factor);
            self.raw.contents = .invalid;
        }

        /// Which factor this is.
        pub fn contents(self: Self) types.Subfactor {
            return self.raw.contents;
        }

        /// A view of the same factor, transposed. Does not take a new
        /// reference - it borrows this one, so do not `deinit` the result.
        ///
        /// For `.plps`, a **non-transpose solve followed by a transpose solve**
        /// is equivalent to a full system solve with `A`.
        ///
        /// `Solve.h` states the opposite order ("transpose solve followed by
        /// non-transpose solve"). It is wrong, and measurably so: for the
        /// symmetric 4x4 in `matrix.TestMatrix`, the header's order returns
        /// `{0.690, 2.035, 2.772, 4.198}` where the answer is `{1, 2, 3, 4}`.
        /// The algebra agrees with the measurement rather than the prose - for
        /// Cholesky `A = PLL'P'`, so `M = PLP'` satisfies `M M' = A`, and
        /// solving `A x = b` means `M y = b` first, then `M' x = y`. Pinned by
        /// the "PLPS round trip" test below.
        pub fn transposed(self: Self) Self {
            var out = self;
            out.raw.attributes.transpose = !self.raw.attributes.transpose;
            return out;
        }

        /// The subfactor's dimensions as `.{ rows, columns }`.
        ///
        /// Transcribed from `_SparseSubFactorGetDimn`. Every subfactor is
        /// `n x n` except `Q` of a QR factorization, which is `m x n`.
        pub fn dimensions(self: Self) struct { usize, usize } {
            const s = self.raw.factor.symbolicFactorization;
            const block: usize = s.blockSize;
            var m: usize = @as(usize, @intCast(s.rowCount)) * block;
            var n: usize = @as(usize, @intCast(s.columnCount)) * block;

            // Sparse always factors a matrix with m >= n.
            if (m < n) std.mem.swap(usize, &m, &n);
            if (!(s.type == .qr and self.raw.contents == .q)) m = n;
            if (self.raw.attributes.transpose) std.mem.swap(usize, &m, &n);
            return .{ m, n };
        }

        /// Bytes of scratch space needed for `nrhs` right-hand sides.
        pub fn workspaceSize(self: Self, nrhs: usize) usize {
            return self.raw.workspaceRequiredStatic +
                nrhs * self.raw.workspaceRequiredPerRHS;
        }

        /// `x <- F^-1 b`, or `x <- F^-1 x` when `b` is null.
        pub fn solve(self: Self, allocator: std.mem.Allocator, b: ?Dense, x: Dense) (Error || std.mem.Allocator.Error)!void {
            const workspace = try allocator.alignedAlloc(u8, .@"16", self.workspaceSize(x.rhsCount()));
            defer allocator.free(workspace);
            return self.solveWithWorkspace(b, x, workspace);
        }

        /// `solve` with a caller-supplied buffer of at least
        /// `workspaceSize(x.rhsCount())` bytes.
        pub fn solveWithWorkspace(self: Self, b: ?Dense, x: Dense, workspace: []align(16) u8) Error!void {
            std.debug.assert(workspace.len >= self.workspaceSize(x.rhsCount()));
            try self.checkOperands(b, x);

            const raw_x = x.raw();
            const raw_b = if (b) |rhs| rhs.raw() else null;

            types.clearReportedError();
            f.solveSubfactor(&self.raw, if (raw_b) |*p| p else null, &raw_x, workspace.ptr);
            return types.takeReportedError();
        }

        /// `y <- F x`, or `x <- F x` in place when `x` is null.
        pub fn multiply(self: Self, allocator: std.mem.Allocator, x: ?Dense, y: Dense) (Error || std.mem.Allocator.Error)!void {
            const workspace = try allocator.alignedAlloc(u8, .@"16", self.workspaceSize(y.rhsCount()));
            defer allocator.free(workspace);
            return self.multiplyWithWorkspace(x, y, workspace);
        }

        /// `multiply` with a caller-supplied buffer.
        pub fn multiplyWithWorkspace(self: Self, x: ?Dense, y: Dense, workspace: []align(16) u8) Error!void {
            std.debug.assert(workspace.len >= self.workspaceSize(y.rhsCount()));
            try self.checkOperands(x, y);

            const raw_y = y.raw();
            const raw_x = if (x) |src| src.raw() else null;

            types.clearReportedError();
            f.multiplySubfactor(&self.raw, if (raw_x) |*p| p else null, &raw_y, workspace.ptr);
            return types.takeReportedError();
        }

        /// The shape checks the C wrappers perform before dispatching. Doing
        /// them here is what keeps a mismatch from reaching `_SparseTrap`.
        fn checkOperands(self: Self, in: ?Dense, out: Dense) Error!void {
            const m, const n = self.dimensions();
            if (out.rhsCount() == 0) return Error.ParameterError;

            if (in) |src| {
                if (src.rhsCount() != out.rhsCount()) return Error.ParameterError;
                if (src.size() != n or out.size() != m) return Error.ParameterError;
            } else {
                // In place, one buffer holds both sides, so it is sized by the
                // larger dimension.
                if (out.size() != @max(m, n)) return Error.ParameterError;
            }
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const TestMatrix = matrix.TestMatrix;
const Dense64 = matrix.Dense(f64);

fn choleskyOfTestMatrix(vals: *const [7]f64) !factor.Factorization(f64) {
    return factor.Factorization(f64).init(.cholesky, TestMatrix.matrix(f64, vals), .{});
}

test "PLPS round trip: non-transpose solve first, then transpose" {
    const vals = TestMatrix.values(f64);
    var fac = try choleskyOfTestMatrix(&vals);
    defer fac.deinit();

    var l = try Subfactor(f64).init(.l, &fac);
    defer l.deinit();

    try testing.expectEqual(types.Subfactor.l, l.contents());
    try testing.expectEqual(@as(usize, 4), l.dimensions()[0]);
    try testing.expectEqual(@as(usize, 4), l.dimensions()[1]);

    // A = P L L' P', so M = PLP' satisfies M M' = A and a full solve is
    // M y = b then M' x = y. L alone omits P, hence .plps for the round trip.
    var plps = try Subfactor(f64).init(.plps, &fac);
    defer plps.deinit();

    var x = TestMatrix.rhs(f64);
    try plps.solve(testing.allocator, null, Dense64.fromSlice(&x));
    try plps.transposed().solve(testing.allocator, null, Dense64.fromSlice(&x));

    for (TestMatrix.solution(f64), x) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-10);
    }

    // And the order the header documents does NOT work - kept as a test so
    // that if a future SDK ever makes the prose true, this fails loudly rather
    // than leaving both orders plausible.
    var wrong = TestMatrix.rhs(f64);
    try plps.transposed().solve(testing.allocator, null, Dense64.fromSlice(&wrong));
    try plps.solve(testing.allocator, null, Dense64.fromSlice(&wrong));
    try testing.expect(!std.math.approxEqAbs(f64, 1, wrong[0], 1e-6));
}

test "multiplying by L then solving with L is the identity" {
    const vals = TestMatrix.values(f64);
    var fac = try choleskyOfTestMatrix(&vals);
    defer fac.deinit();

    var l = try Subfactor(f64).init(.l, &fac);
    defer l.deinit();

    const original = [_]f64{ 1, -2, 3.5, 0.25 };
    var x = original;
    var y = [_]f64{0} ** 4;

    try l.multiply(testing.allocator, Dense64.fromSlice(&x), Dense64.fromSlice(&y));
    try l.solve(testing.allocator, Dense64.fromSlice(&y), Dense64.fromSlice(&x));

    for (original, x) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-10);
    }
}

test "P is a permutation: applying it and undoing it round-trips" {
    const vals = TestMatrix.values(f64);
    var fac = try choleskyOfTestMatrix(&vals);
    defer fac.deinit();

    var p = try Subfactor(f64).init(.p, &fac);
    defer p.deinit();

    const original = [_]f64{ 10, 20, 30, 40 };
    var x = original;
    var y = [_]f64{0} ** 4;

    try p.multiply(testing.allocator, Dense64.fromSlice(&x), Dense64.fromSlice(&y));

    // A permutation only reorders, so the multiset of entries is unchanged.
    var sorted_in = original;
    var sorted_out = y;
    std.mem.sort(f64, &sorted_in, {}, std.sort.asc(f64));
    std.mem.sort(f64, &sorted_out, {}, std.sort.asc(f64));
    try testing.expectEqualSlices(f64, &sorted_in, &sorted_out);

    try p.solve(testing.allocator, Dense64.fromSlice(&y), Dense64.fromSlice(&x));
    for (original, x) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-12);
    }
}

test "D of an LDL^T carries the inertia on its diagonal" {
    const starts = [_]c_long{ 0, 1, 2, 3, 4 };
    const idx = [_]c_int{ 0, 1, 2, 3 };
    const vals = [_]f64{ 2, -3, 4, -5 };
    const a = matrix.Sparse(f64).init(4, 4, &starts, &idx, &vals, .{
        .attributes = .{ .kind = .symmetric, .triangle = .lower },
    });

    var fac = try factor.Factorization(f64).init(.ldlt, a, .{});
    defer fac.deinit();

    var d = try Subfactor(f64).init(.d, &fac);
    defer d.deinit();

    // Recover D column by column: D e_j is the j-th column.
    var negatives: u32 = 0;
    var positives: u32 = 0;
    for (0..4) |j| {
        var e = [_]f64{0} ** 4;
        e[j] = 1;
        var col = [_]f64{0} ** 4;
        try d.multiply(testing.allocator, Dense64.fromSlice(&e), Dense64.fromSlice(&col));
        if (col[j] > 0) positives += 1 else if (col[j] < 0) negatives += 1;
    }

    // The matrix is diag(2, -3, 4, -5), so D must agree with the inertia -
    // reached here through a completely different entry point.
    const n = try fac.inertia();
    try testing.expectEqual(n.positive, positives);
    try testing.expectEqual(n.negative, negatives);
}

test "Q of a QR factorization is m x n, unlike every other subfactor" {
    // The same overdetermined 4x2 system used in factor.zig.
    const starts = [_]c_long{ 0, 3, 6 };
    const idx = [_]c_int{ 0, 2, 3, 1, 2, 3 };
    const vals = [_]f64{ 1, 1, 1, 1, 1, 2 };
    const a = matrix.Sparse(f64).init(4, 2, &starts, &idx, &vals, .{});

    var fac = try factor.Factorization(f64).init(.qr, a, .{});
    defer fac.deinit();

    var q = try Subfactor(f64).init(.q, &fac);
    defer q.deinit();
    const qm, const qn = q.dimensions();
    try testing.expectEqual(@as(usize, 4), qm);
    try testing.expectEqual(@as(usize, 2), qn);

    // R is square, n x n.
    var r = try Subfactor(f64).init(.r, &fac);
    defer r.deinit();
    const rm, const rn = r.dimensions();
    try testing.expectEqual(@as(usize, 2), rm);
    try testing.expectEqual(@as(usize, 2), rn);
    try testing.expectEqual(types.Triangle.upper, r.raw.attributes.triangle);
    try testing.expectEqual(types.Kind.triangular, r.raw.attributes.kind);
}

test "transposed swaps the dimensions without taking a reference" {
    const starts = [_]c_long{ 0, 3, 6 };
    const idx = [_]c_int{ 0, 2, 3, 1, 2, 3 };
    const vals = [_]f64{ 1, 1, 1, 1, 1, 2 };
    const a = matrix.Sparse(f64).init(4, 2, &starts, &idx, &vals, .{});
    var fac = try factor.Factorization(f64).init(.qr, a, .{});
    defer fac.deinit();

    var q = try Subfactor(f64).init(.q, &fac);
    defer q.deinit();

    const m, const n = q.dimensions();
    const tm, const tn = q.transposed().dimensions();
    try testing.expectEqual(m, tn);
    try testing.expectEqual(n, tm);
    // Transposing twice is the identity.
    const rm, const rn = q.transposed().transposed().dimensions();
    try testing.expectEqual(m, rm);
    try testing.expectEqual(n, rn);
}

test "invalid subfactor/factorization combinations are rejected" {
    const vals = TestMatrix.values(f64);
    var chol = try choleskyOfTestMatrix(&vals);
    defer chol.deinit();

    // Cholesky has no diagonal or scaling factor, and no Q or R.
    for ([_]types.Subfactor{ .d, .s, .q, .r, .rp, .invalid }) |which| {
        try testing.expectError(Error.ParameterError, Subfactor(f64).init(which, &chol));
    }
    // But L, P and PLPS are fine.
    for ([_]types.Subfactor{ .l, .p, .plps }) |which| {
        var sf = try Subfactor(f64).init(which, &chol);
        sf.deinit();
    }
}

test "a subfactor outlives the factorization it came from" {
    const vals = TestMatrix.values(f64);
    var fac = try choleskyOfTestMatrix(&vals);
    var plps = try Subfactor(f64).init(.plps, &fac);
    defer plps.deinit();

    // Drop the parent handle; the subfactor holds its own reference.
    fac.deinit();

    var x = TestMatrix.rhs(f64);
    try plps.solve(testing.allocator, null, Dense64.fromSlice(&x));
    try plps.transposed().solve(testing.allocator, null, Dense64.fromSlice(&x));
    for (TestMatrix.solution(f64), x) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-10);
    }
}

test "deinit is idempotent" {
    const vals = TestMatrix.values(f64);
    var fac = try choleskyOfTestMatrix(&vals);
    defer fac.deinit();
    var l = try Subfactor(f64).init(.l, &fac);
    l.deinit();
    l.deinit();
    try testing.expectEqual(types.Subfactor.invalid, l.contents());
}

test "mismatched operand shapes are rejected rather than trapped" {
    const vals = TestMatrix.values(f64);
    var fac = try choleskyOfTestMatrix(&vals);
    defer fac.deinit();
    var l = try Subfactor(f64).init(.l, &fac);
    defer l.deinit();

    var short = [_]f64{ 1, 2, 3 };
    var ok = [_]f64{ 1, 2, 3, 4 };
    const workspace = try testing.allocator.alignedAlloc(u8, .@"16", l.workspaceSize(1));
    defer testing.allocator.free(workspace);

    try testing.expectError(Error.ParameterError, l.solveWithWorkspace(
        Dense64.fromSlice(&short),
        Dense64.fromSlice(&ok),
        workspace,
    ));
    try testing.expectError(Error.ParameterError, l.multiplyWithWorkspace(
        Dense64.fromSlice(&short),
        Dense64.fromSlice(&ok),
        workspace,
    ));
}

test "workspaceSize is linear in the right-hand side count" {
    const vals = TestMatrix.values(f64);
    var fac = try choleskyOfTestMatrix(&vals);
    defer fac.deinit();
    var l = try Subfactor(f64).init(.l, &fac);
    defer l.deinit();

    const static = l.raw.workspaceRequiredStatic;
    const per_rhs = l.raw.workspaceRequiredPerRHS;
    try testing.expectEqual(static, l.workspaceSize(0));
    try testing.expectEqual(static + 5 * per_rhs, l.workspaceSize(5));
}

test "subfactors work for f32 as well" {
    const vals = TestMatrix.values(f32);
    var fac = try factor.Factorization(f32).init(.cholesky, TestMatrix.matrix(f32, &vals), .{});
    defer fac.deinit();

    var plps = try Subfactor(f32).init(.plps, &fac);
    defer plps.deinit();

    var x = TestMatrix.rhs(f32);
    const D32 = matrix.Dense(f32);
    try plps.solve(testing.allocator, null, D32.fromSlice(&x));
    try plps.transposed().solve(testing.allocator, null, D32.fromSlice(&x));
    for (TestMatrix.solution(f32), x) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-4);
    }
}

test "LU exposes P, Q, Sr and Sc, and refuses L, D, R" {
    // The LU subfactor table is not the QR one with LU spellings added:
    // `SparseCreateSubfactor` gives LU the permutations and the two scalings
    // but no L or U at all, and reuses `.q` for the *column* permutation
    // rather than an orthogonal factor. Requires macOS 15.5.
    const starts = [_]c_long{ 0, 2, 5, 8, 10 };
    const rows = [_]c_int{ 0, 1, 0, 1, 2, 1, 2, 3, 2, 3 };
    const vals = [_]f64{ 4, 1, 1, 3, 2, 1, 5, 1, 1, 2 };
    const a = matrix.Sparse(f64).init(4, 4, &starts, &rows, &vals, .{});

    var fac = try factor.Factorization(f64).init(.lu_tpp, a, .{});
    defer fac.deinit();

    inline for (.{ types.Subfactor.p, .q, .sr, .sc }) |which| {
        var sub = try Subfactor(f64).init(which, &fac);
        defer sub.deinit();
        try testing.expectEqual(which, sub.contents());
    }
    inline for (.{ types.Subfactor.l, .d, .s, .r, .rp, .plps }) |which| {
        try testing.expectError(Error.ParameterError, Subfactor(f64).init(which, &fac));
    }
}

test "Sr and Sc are rejected for a non-LU factorization" {
    const vals = matrix.TestMatrix.values(f64);
    const a = matrix.TestMatrix.matrix(f64, &vals);
    var fac = try factor.Factorization(f64).init(.ldlt, a, .{});
    defer fac.deinit();

    try testing.expectError(Error.ParameterError, Subfactor(f64).init(.sr, &fac));
    try testing.expectError(Error.ParameterError, Subfactor(f64).init(.sc, &fac));
}
