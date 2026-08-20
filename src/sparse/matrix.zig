//! Sparse and dense matrix views for the Sparse Solvers bindings.
//!
//! The C types carry raw pointers with the lengths implied by other fields
//! (`columnStarts` must have `columnCount + 1` entries, `data` must have
//! `blockSize^2 * nnz` and so on). Every one of those relationships is a way to
//! read out of bounds silently. The types here carry slices and check the
//! relationships in `init`, in the same spirit as `vdsp.SplitSlice`.

const std = @import("std");
const c = @import("c.zig");
const types = @import("types.zig");

const Attributes = types.Attributes;
const SparseError = types.SparseError;

/// A dense column-major matrix backed by a caller-owned slice.
///
/// Sparse treats a vector as an `n x 1` matrix, so `DenseMatrix` covers both
/// and there is no separate vector type; use `fromSlice` for the vector case.
pub fn Dense(comptime T: type) type {
    return struct {
        const Self = @This();

        data: []T,
        row_count: usize,
        column_count: usize,
        /// Distance between the starts of consecutive columns. At least
        /// `row_count`; larger when the matrix is a window onto a wider one.
        column_stride: usize,
        attributes: Attributes = .{},

        /// A single column vector over `data`.
        pub fn fromSlice(data: []T) Self {
            return .{
                .data = data,
                .row_count = data.len,
                .column_count = 1,
                .column_stride = data.len,
            };
        }

        pub fn init(data: []T, row_count: usize, column_count: usize, column_stride: usize) Self {
            // The C wrappers check this one too: a stride below row_count would
            // make columns overlap.
            std.debug.assert(column_stride >= row_count);
            std.debug.assert(column_count > 0);
            // The last column only needs `row_count` entries, not a full
            // stride, which is why this is not `column_count * stride`.
            std.debug.assert(data.len >= (column_count - 1) * column_stride + row_count);
            return .{
                .data = data,
                .row_count = row_count,
                .column_count = column_count,
                .column_stride = column_stride,
            };
        }

        /// Number of right-hand sides this matrix represents, accounting for
        /// `attributes.transpose`. This is the multiplier on
        /// `solveWorkspaceRequiredPerRHS`.
        pub fn rhsCount(self: Self) usize {
            return if (self.attributes.transpose) self.row_count else self.column_count;
        }

        /// Logical row count after `attributes.transpose` is applied.
        pub fn size(self: Self) usize {
            return if (self.attributes.transpose) self.column_count else self.row_count;
        }

        pub fn column(self: Self, j: usize) []T {
            std.debug.assert(j < self.column_count);
            return self.data[j * self.column_stride ..][0..self.row_count];
        }

        pub fn at(self: Self, i: usize, j: usize) T {
            std.debug.assert(i < self.row_count);
            return self.column(j)[i];
        }

        pub fn raw(self: Self) c.DenseMatrix(T) {
            return .{
                .rowCount = @intCast(self.row_count),
                .columnCount = @intCast(self.column_count),
                .columnStride = @intCast(self.column_stride),
                .attributes = self.attributes,
                .data = self.data.ptr,
            };
        }
    };
}

/// A sparse matrix in block compressed sparse column form.
///
/// Usually a *borrowed view* over caller-owned arrays: `init` does not copy or
/// allocate, and `deinit` is a no-op. The exception is a matrix produced by
/// `fromCoordinate`, which owns one allocation and must be `deinit`ed with the
/// same allocator.
///
/// With `block_size == 1` - the common case - this is ordinary CSC.
pub fn Sparse(comptime T: type) type {
    return struct {
        const Self = @This();

        /// Number of *block* rows. The matrix has `row_count * block_size`
        /// scalar rows.
        row_count: usize,
        /// Number of *block* columns.
        column_count: usize,
        /// Where each block column starts in `row_indices`; length
        /// `column_count + 1`.
        column_starts: []const c_long,
        /// Block row index of each stored block, grouped by column.
        row_indices: []const c_int,
        /// `block_size * block_size` values per stored block, each block
        /// column-major.
        values: []const T,
        attributes: Attributes = .{},
        block_size: u8 = 1,

        /// Non-null only for a matrix returned by `fromCoordinate`. Sparse
        /// packs the whole converted matrix into a single allocation whose base
        /// is `columnStarts` - which is why `SparseCleanup` on such a matrix is
        /// just `free(structure.columnStarts)`.
        ///
        /// We hand Sparse storage from a `std.mem.Allocator` rather than let it
        /// call `malloc`, so `attributes._allocated_by_sparse` stays clear and
        /// `SparseCleanup` must never be called on the result. `deinit` frees
        /// it through the same allocator instead.
        owned_storage: ?[]align(16) u8 = null,

        pub const Options = struct {
            attributes: Attributes = .{},
            block_size: u8 = 1,
        };

        /// Wraps caller-owned block-CSC arrays, checking every length relation
        /// the C API leaves implicit.
        pub fn init(
            row_count: usize,
            column_count: usize,
            column_starts: []const c_long,
            row_indices: []const c_int,
            values: []const T,
            options: Options,
        ) Self {
            std.debug.assert(options.block_size > 0);
            std.debug.assert(column_starts.len == column_count + 1);
            std.debug.assert(column_starts[0] == 0);

            const nnz_blocks: usize = @intCast(column_starts[column_count]);
            std.debug.assert(row_indices.len >= nnz_blocks);

            const per_block = @as(usize, options.block_size) * options.block_size;
            std.debug.assert(values.len >= nnz_blocks * per_block);

            // A symmetric or triangular matrix stores only one triangle, so the
            // "wrong" triangle being non-empty is a data bug the C API will
            // happily read past. Squareness is the cheap half of that check and
            // is what SparseFactor itself verifies.
            if (options.attributes.kind != .ordinary) {
                std.debug.assert(row_count == column_count);
            }

            return .{
                .row_count = row_count,
                .column_count = column_count,
                .column_starts = column_starts,
                .row_indices = row_indices,
                .values = values,
                .attributes = options.attributes,
                .block_size = options.block_size,
            };
        }

        /// Builds a block-CSC matrix from coordinate (triplet / COO) form.
        ///
        /// Out-of-range coordinates are dropped, duplicates are summed, and for
        /// `.symmetric` matrices entries in the "wrong" triangle are transposed
        /// into the right one. For `.triangular` kinds the wrong triangle is
        /// dropped instead.
        ///
        /// The result owns one allocation from `allocator`; release it with
        /// `deinit(allocator)`.
        pub fn fromCoordinate(
            allocator: std.mem.Allocator,
            row_count: usize,
            column_count: usize,
            rows: []const c_int,
            columns: []const c_int,
            values: []const T,
            options: Options,
        ) (SparseError || std.mem.Allocator.Error)!Self {
            std.debug.assert(options.block_size > 0);
            std.debug.assert(rows.len == columns.len);

            const block_count = rows.len;
            const per_block = @as(usize, options.block_size) * options.block_size;
            std.debug.assert(values.len >= block_count * per_block);

            // Sparse rejects a non-square matrix with a non-ordinary kind, and
            // would trap on it. Reject it here so the caller gets an error.
            if (options.attributes.kind != .ordinary and row_count != column_count) {
                return SparseError.ParameterError;
            }

            // Storage size straight from the allocating overload of
            // SparseConvertFromCoordinate. The 28-byte slack is alignment
            // headroom: Apple notes malloc already returns 16-byte-aligned
            // memory, so 2*16-4 is what is actually needed. We request
            // 16-byte-aligned memory for the same reason.
            const storage_bytes = 28 +
                (column_count + 1) * @sizeOf(c_long) +
                block_count * @sizeOf(c_int) +
                block_count * per_block * @sizeOf(T);

            const storage = try allocator.alignedAlloc(u8, .@"16", storage_bytes);
            errdefer allocator.free(storage);

            // Scratch, needed only for the duration of the call.
            const workspace = try allocator.alloc(c_int, row_count);
            defer allocator.free(workspace);

            types.clearReportedError();
            const built = c.fns(T).convertFromCoordinate(
                @intCast(row_count),
                @intCast(column_count),
                @intCast(block_count),
                options.block_size,
                options.attributes,
                rows.ptr,
                columns.ptr,
                values.ptr,
                storage.ptr,
                workspace.ptr,
            );
            try types.takeReportedError();

            const nnz_blocks: usize = @intCast(built.structure.columnStarts[column_count]);
            return .{
                .row_count = @intCast(built.structure.rowCount),
                .column_count = @intCast(built.structure.columnCount),
                .column_starts = built.structure.columnStarts[0 .. column_count + 1],
                .row_indices = built.structure.rowIndices[0..nnz_blocks],
                .values = built.data[0 .. nnz_blocks * per_block],
                .attributes = built.structure.attributes,
                .block_size = built.structure.blockSize,
                .owned_storage = storage,
            };
        }

        /// Releases the allocation made by `fromCoordinate`. A no-op for a
        /// borrowed view, so it is safe to call unconditionally.
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            if (self.owned_storage) |s| allocator.free(s);
            self.owned_storage = null;
        }

        /// Number of structurally non-zero blocks.
        pub fn blockCount(self: Self) usize {
            return @intCast(self.column_starts[self.column_count]);
        }

        /// Scalar rows, i.e. `row_count * block_size`.
        pub fn scalarRowCount(self: Self) usize {
            return self.row_count * self.block_size;
        }

        /// Scalar columns, i.e. `column_count * block_size`.
        pub fn scalarColumnCount(self: Self) usize {
            return self.column_count * self.block_size;
        }

        /// Block row indices stored in block column `j`.
        pub fn columnRows(self: Self, j: usize) []const c_int {
            std.debug.assert(j < self.column_count);
            const start: usize = @intCast(self.column_starts[j]);
            const end: usize = @intCast(self.column_starts[j + 1]);
            return self.row_indices[start..end];
        }

        /// The C struct. `columnStarts`/`rowIndices` are non-const in C even
        /// where they are read-only, hence the casts; Sparse does not write
        /// through them for an input matrix.
        pub fn raw(self: Self) c.SparseMatrix(T) {
            return .{
                .structure = .{
                    .rowCount = @intCast(self.row_count),
                    .columnCount = @intCast(self.column_count),
                    .columnStarts = @constCast(self.column_starts.ptr),
                    .rowIndices = @constCast(self.row_indices.ptr),
                    .attributes = self.attributes,
                    .blockSize = self.block_size,
                },
                .data = @constCast(self.values.ptr),
            };
        }

        /// A view of the same storage with the transpose flag flipped.
        pub fn transposed(self: Self) Self {
            var out = self;
            out.attributes.transpose = !self.attributes.transpose;
            // The view does not own the storage; only the original does.
            out.owned_storage = null;
            return out;
        }

        /// `y = alpha * A * x`, or `y += alpha * A * x` when `accumulate`.
        ///
        /// `x` and `y` are dense and may hold several right-hand sides.
        pub fn multiply(self: Self, alpha: T, x: Dense(T), y: Dense(T), accumulate: bool) SparseError!void {
            std.debug.assert(x.rhsCount() == y.rhsCount());
            types.clearReportedError();
            c.fns(T).spmv(alpha, self.raw(), x.raw(), accumulate, y.raw());
            try types.takeReportedError();
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// The 4x4 SPD tridiagonal matrix used throughout these tests, in
/// lower-triangular CSC:
///
///     [ 2 1 0 0 ]
///     [ 1 3 1 0 ]
///     [ 0 1 4 1 ]
///     [ 0 0 1 5 ]
pub const TestMatrix = struct {
    pub const column_starts = [_]c_long{ 0, 2, 4, 6, 7 };
    pub const row_indices = [_]c_int{ 0, 1, 1, 2, 2, 3, 3 };
    pub fn values(comptime T: type) [7]T {
        return .{ 2, 1, 3, 1, 4, 1, 5 };
    }
    /// `A * [1, 2, 3, 4]^T`.
    pub fn rhs(comptime T: type) [4]T {
        return .{ 4, 10, 18, 23 };
    }
    pub fn solution(comptime T: type) [4]T {
        return .{ 1, 2, 3, 4 };
    }
    pub fn matrix(comptime T: type, vals: []const T) Sparse(T) {
        return Sparse(T).init(4, 4, &column_starts, &row_indices, vals, .{
            .attributes = .{ .kind = .symmetric, .triangle = .lower },
        });
    }
};

test "Sparse.init records the block-CSC shape" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);

    try testing.expectEqual(@as(usize, 4), a.row_count);
    try testing.expectEqual(@as(usize, 7), a.blockCount());
    try testing.expectEqual(@as(usize, 4), a.scalarRowCount());
    try testing.expectEqualSlices(c_int, &.{ 0, 1 }, a.columnRows(0));
    try testing.expectEqualSlices(c_int, &.{3}, a.columnRows(3));

    const r = a.raw();
    try testing.expectEqual(@as(c_int, 4), r.structure.rowCount);
    try testing.expectEqual(@as(u8, 1), r.structure.blockSize);
    try testing.expectEqual(types.Kind.symmetric, r.structure.attributes.kind);
    try testing.expectEqual(types.Triangle.lower, r.structure.attributes.triangle);
}

test "transposed flips only the flag, and does not duplicate ownership" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    const t = a.transposed();

    try testing.expect(!a.attributes.transpose);
    try testing.expect(t.attributes.transpose);
    try testing.expectEqual(a.values.ptr, t.values.ptr);
    try testing.expectEqual(@as(?[]align(16) u8, null), t.owned_storage);
}

test "Dense.fromSlice and init describe the same single column" {
    var buf = [_]f64{ 1, 2, 3, 4 };
    const v = Dense(f64).fromSlice(&buf);
    try testing.expectEqual(@as(usize, 4), v.row_count);
    try testing.expectEqual(@as(usize, 1), v.column_count);
    try testing.expectEqual(@as(usize, 1), v.rhsCount());
    try testing.expectEqual(@as(usize, 4), v.size());
    try testing.expectEqual(@as(f64, 3), v.at(2, 0));

    const m = Dense(f64).init(&buf, 4, 1, 4);
    try testing.expectEqual(v.raw().columnStride, m.raw().columnStride);
}

test "Dense with a stride larger than the row count exposes a window" {
    // 2x2 window into a 3-row buffer.
    var buf = [_]f64{ 1, 2, 99, 3, 4, 99 };
    const m = Dense(f64).init(&buf, 2, 2, 3);
    try testing.expectEqualSlices(f64, &.{ 1, 2 }, m.column(0));
    try testing.expectEqualSlices(f64, &.{ 3, 4 }, m.column(1));
    try testing.expectEqual(@as(usize, 2), m.rhsCount());
}

test "rhsCount and size follow the transpose flag" {
    var buf = [_]f64{ 1, 2, 3, 4, 5, 6 };
    var m = Dense(f64).init(&buf, 3, 2, 3);
    try testing.expectEqual(@as(usize, 2), m.rhsCount());
    try testing.expectEqual(@as(usize, 3), m.size());

    m.attributes.transpose = true;
    try testing.expectEqual(@as(usize, 3), m.rhsCount());
    try testing.expectEqual(@as(usize, 2), m.size());
}

test "multiply reproduces a hand-computed symmetric product" {
    inline for (.{ f64, f32 }) |T| {
        const vals = TestMatrix.values(T);
        const a = TestMatrix.matrix(T, &vals);

        var x = TestMatrix.solution(T);
        var y = [_]T{ 0, 0, 0, 0 };
        try a.multiply(1, Dense(T).fromSlice(&x), Dense(T).fromSlice(&y), false);

        // Only the lower triangle is stored; the product must still reflect the
        // full symmetric matrix.
        for (TestMatrix.rhs(T), y) |want, got| {
            try testing.expectApproxEqAbs(want, got, if (T == f64) 1e-12 else 1e-5);
        }
    }
}

test "multiply accumulates and scales" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);
    var x = TestMatrix.solution(f64);
    var y = [_]f64{ 1, 1, 1, 1 };

    try a.multiply(2, Dense(f64).fromSlice(&x), Dense(f64).fromSlice(&y), true);
    for (TestMatrix.rhs(f64), y) |ax, got| {
        try testing.expectApproxEqAbs(1 + 2 * ax, got, 1e-12);
    }
}

test "multiply handles several right-hand sides at once" {
    const vals = TestMatrix.values(f64);
    const a = TestMatrix.matrix(f64, &vals);

    // Columns: [1,2,3,4] and the unit vector e0.
    var x = [_]f64{ 1, 2, 3, 4, 1, 0, 0, 0 };
    var y = [_]f64{0} ** 8;
    try a.multiply(1, Dense(f64).init(&x, 4, 2, 4), Dense(f64).init(&y, 4, 2, 4), false);

    try testing.expectEqualSlices(f64, &TestMatrix.rhs(f64), y[0..4]);
    // A * e0 is the first column of the full symmetric matrix.
    try testing.expectEqualSlices(f64, &.{ 2, 1, 0, 0 }, y[4..8]);
}

test "fromCoordinate sums duplicates and drops out-of-range entries" {
    const alloc = testing.allocator;

    // Entries for the same 4x4 matrix, given upper-triangle-first, with (1,1)
    // split across two entries and one coordinate deliberately out of range.
    const rows = [_]c_int{ 0, 0, 1, 1, 1, 2, 2, 3, 9 };
    const cols = [_]c_int{ 0, 1, 1, 1, 2, 2, 3, 3, 0 };
    const vals = [_]f64{ 2, 1, 1, 2, 1, 4, 1, 5, 777 };

    var a = try Sparse(f64).fromCoordinate(alloc, 4, 4, &rows, &cols, &vals, .{
        .attributes = .{ .kind = .symmetric, .triangle = .lower },
    });
    defer a.deinit(alloc);

    try testing.expectEqual(@as(usize, 4), a.row_count);
    try testing.expectEqual(@as(usize, 7), a.blockCount());
    try testing.expect(a.owned_storage != null);

    // `_allocatedBySparse` must stay *clear*. Apple's allocating overload of
    // SparseConvertFromCoordinate sets it by hand after the call, as a licence
    // for SparseCleanup to `free()` the matrix; `_SparseConvertFromCoordinate`
    // itself never sets it. Our storage came from a Zig allocator and is
    // released by `deinit`, so setting it would invite libc `free()` on memory
    // libc did not hand out.
    try testing.expect(!a.attributes._allocated_by_sparse);

    // The (1,1) duplicates must have summed to 3, and the out-of-range entry
    // must be gone - verified through the product rather than the raw storage.
    var x = TestMatrix.solution(f64);
    var y = [_]f64{0} ** 4;
    try a.multiply(1, Dense(f64).fromSlice(&x), Dense(f64).fromSlice(&y), false);
    for (TestMatrix.rhs(f64), y) |want, got| {
        try testing.expectApproxEqAbs(want, got, 1e-12);
    }
}

test "fromCoordinate rejects a non-square matrix with a symmetric kind" {
    const alloc = testing.allocator;
    const rows = [_]c_int{0};
    const cols = [_]c_int{0};
    const vals = [_]f64{1};

    // Sparse would trap on this; we must return an error instead.
    try testing.expectError(SparseError.ParameterError, Sparse(f64).fromCoordinate(
        alloc,
        3,
        4,
        &rows,
        &cols,
        &vals,
        .{ .attributes = .{ .kind = .symmetric } },
    ));
}

test "deinit is a no-op on a borrowed view" {
    const vals = TestMatrix.values(f64);
    var a = TestMatrix.matrix(f64, &vals);
    // Would be a double free / bad free if `deinit` did not check ownership.
    a.deinit(testing.allocator);
    a.deinit(testing.allocator);
    try testing.expectEqual(@as(usize, 7), a.blockCount());
}
