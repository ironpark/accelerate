//! BNNS k-nearest-neighbours.
//!
//! A small, self-contained classifier: allocate a store sized for at most
//! `max_n_samples` feature vectors, append samples to it, and then ask, for any
//! sample already loaded, which `n_neighbors` samples are closest to it.
//!
//! Note the shape of the query. `getInfo` takes a *sample number* — an index
//! into the samples already loaded — not an arbitrary query vector. This is a
//! neighbour graph over the loaded set, not a lookup for unseen points.
//!
//! Two behaviours measured against Accelerate on macOS 15.7.7 / arm64, neither
//! of which the header states:
//!
//! * The result **includes the query sample itself**, first, at distance 0. Ask
//!   for `k` neighbours and you get the sample plus its `k - 1` nearest others.
//! * Loading past `max_n_samples` **succeeds silently**, returning 0. There is
//!   no capacity error to check for, so `loadSlice` asserts the bound itself.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const DataType = types.DataType;
const FilterParameters = types.FilterParameters;
const Error = types.Error;
const check = types.check;

/// An owned `BNNSNearestNeighbors` store.
pub const NearestNeighbors = struct {
    handle: c.BNNSNearestNeighbors,
    n_features: u32,
    n_neighbors: u32,
    data_type: DataType,
    /// Capacity, kept because BNNS will not report an overflow itself.
    max_n_samples: u32,
    /// Samples loaded so far, across all `loadSlice` calls.
    loaded: u32 = 0,

    /// Allocate a store.
    ///
    /// `BNNSCreateNearestNeighbors`. `max_n_samples` is the capacity, fixed at
    /// creation; `n_features` the length of one feature vector; `n_neighbors`
    /// how many neighbours a query returns.
    pub fn init(
        max_n_samples: u32,
        n_features: u32,
        n_neighbors: u32,
        data_type: DataType,
        filter_params: ?*const FilterParameters,
    ) Error!NearestNeighbors {
        const h = c.BNNSCreateNearestNeighbors(max_n_samples, n_features, n_neighbors, data_type, filter_params);
        if (h == null) return Error.BnnsAllocationFailed;
        return .{
            .handle = h,
            .n_features = n_features,
            .n_neighbors = n_neighbors,
            .data_type = data_type,
            .max_n_samples = max_n_samples,
        };
    }

    /// `BNNSDestroyNearestNeighbors`.
    pub fn deinit(self: *NearestNeighbors) void {
        c.BNNSDestroyNearestNeighbors(self.handle);
        self.handle = null;
    }

    /// Append `n_new_samples` feature vectors, laid out contiguously as
    /// `n_new_samples * n_features` elements of `data_type`.
    ///
    /// `BNNSNearestNeighborsLoad`. Samples accumulate across calls, so loading
    /// 2 then 3 leaves 5 in the store.
    ///
    /// Loading past `max_n_samples` does NOT fail — BNNS returns 0 and writes
    /// anyway. Prefer `loadSlice`, which tracks the count and asserts.
    pub fn load(self: NearestNeighbors, n_new_samples: u32, data: *const anyopaque) Error!void {
        return check(c.BNNSNearestNeighborsLoad(self.handle, n_new_samples, data));
    }

    /// Typed convenience wrapper over `load`.
    /// Asserts that `samples.len` is a whole number of feature vectors, that
    /// `T` matches the store's data type, and that the load stays inside
    /// `max_n_samples` — BNNS itself reports success on an overflowing load, so
    /// this is the only place the capacity is enforced.
    pub fn loadSlice(self: *NearestNeighbors, comptime T: type, samples: []const T) Error!void {
        std.debug.assert(DataType.of(T) == self.data_type);
        std.debug.assert(self.n_features != 0);
        std.debug.assert(samples.len % self.n_features == 0);
        const n: u32 = @intCast(samples.len / self.n_features);
        std.debug.assert(self.loaded + n <= self.max_n_samples);
        try self.load(n, @ptrCast(samples.ptr));
        self.loaded += n;
    }

    /// Look up the neighbours of the sample at `sample_number`.
    ///
    /// `BNNSNearestNeighborsGetInfo`. `indices` receives the neighbours'
    /// sample numbers and `distances` the corresponding distances, in the
    /// store's data type. Either may be null if not wanted. Both must have room
    /// for `n_neighbors` entries.
    pub fn getInfo(self: NearestNeighbors, sample_number: i32, indices: ?[]c_int, distances: ?*anyopaque) Error!void {
        if (indices) |ix| std.debug.assert(ix.len >= self.n_neighbors);
        const ix_ptr: ?[*]c_int = if (indices) |ix| ix.ptr else null;
        return check(c.BNNSNearestNeighborsGetInfo(self.handle, sample_number, ix_ptr, distances));
    }

    /// Typed convenience wrapper over `getInfo`.
    pub fn getInfoTyped(
        self: NearestNeighbors,
        comptime T: type,
        sample_number: i32,
        indices: ?[]c_int,
        distances: ?[]T,
    ) Error!void {
        std.debug.assert(DataType.of(T) == self.data_type);
        if (distances) |d| std.debug.assert(d.len >= self.n_neighbors);
        const d_ptr: ?*anyopaque = if (distances) |d| @ptrCast(d.ptr) else null;
        return self.getInfo(sample_number, indices, d_ptr);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "the neighbour list starts with the query sample itself, at distance 0" {
    const testing = std.testing;

    // Five 1-D samples at 0, 1, 2, 10, 11. Ask for the 3 nearest.
    var knn = try NearestNeighbors.init(8, 1, 3, .float32, null);
    defer knn.deinit();
    try knn.loadSlice(f32, &[_]f32{ 0, 1, 2, 10, 11 });

    var indices: [3]c_int = @splat(-1);
    var distances: [3]f32 = @splat(0);

    // Sample 0 sits at 0. The result is {itself, 1, 2} at distances {0, 1, 2} —
    // BNNS counts the query sample as one of the k, which the header does not
    // say. Measured, and matched by an equivalent plain-C program.
    try knn.getInfoTyped(f32, 0, &indices, &distances);
    try testing.expectEqualSlices(c_int, &.{ 0, 1, 2 }, &indices);
    try testing.expectApproxEqAbs(@as(f32, 0), distances[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 1), distances[1], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 2), distances[2], 1e-5);

    // Sample 3 sits at 10, in the far cluster: {itself, 4, 2} at {0, 1, 8}.
    try knn.getInfoTyped(f32, 3, &indices, &distances);
    try testing.expectEqualSlices(c_int, &.{ 3, 4, 2 }, &indices);
    try testing.expectApproxEqAbs(@as(f32, 0), distances[0], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 1), distances[1], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 8), distances[2], 1e-5);

    // Sample 1 sits at 1, equidistant from 0 and 2: {itself, 0, 2} at {0, 1, 1}.
    try knn.getInfoTyped(f32, 1, &indices, &distances);
    try testing.expectEqualSlices(c_int, &.{ 1, 0, 2 }, &indices);
    try testing.expectApproxEqAbs(@as(f32, 1), distances[1], 1e-5);
    try testing.expectApproxEqAbs(@as(f32, 1), distances[2], 1e-5);
}

test "load accumulates across calls rather than replacing" {
    const testing = std.testing;

    var knn = try NearestNeighbors.init(8, 2, 2, .float32, null);
    defer knn.deinit();

    // Two 2-D samples, then two more.
    try knn.loadSlice(f32, &[_]f32{ 0, 0, 5, 5 });
    try knn.loadSlice(f32, &[_]f32{ 0.5, 0.5, 5.5, 5.5 });
    try testing.expectEqual(@as(u32, 4), knn.loaded);

    var indices: [2]c_int = @splat(-1);

    // Sample 0 at (0,0): itself, then sample 2 at (0.5, 0.5). Index 2 only
    // exists if the second load appended.
    try knn.getInfoTyped(f32, 0, &indices, null);
    try testing.expectEqualSlices(c_int, &.{ 0, 2 }, &indices);

    // Sample 1 at (5,5): itself, then sample 3 at (5.5, 5.5).
    try knn.getInfoTyped(f32, 1, &indices, null);
    try testing.expectEqualSlices(c_int, &.{ 1, 3 }, &indices);
}

test "getInfo accepts a null distances pointer" {
    const testing = std.testing;

    var knn = try NearestNeighbors.init(4, 1, 2, .float32, null);
    defer knn.deinit();
    try knn.loadSlice(f32, &[_]f32{ 0, 3, 100 });

    var indices: [2]c_int = @splat(-1);
    try knn.getInfo(0, &indices, null);
    try testing.expectEqualSlices(c_int, &.{ 0, 1 }, &indices);
}

test "BNNS reports success when a load overflows the store, so loadSlice tracks it" {
    const testing = std.testing;

    var knn = try NearestNeighbors.init(2, 1, 1, .float32, null);
    defer knn.deinit();

    try knn.loadSlice(f32, &[_]f32{ 0, 1 });
    try testing.expectEqual(@as(u32, 2), knn.loaded);

    // The raw entry point returns 0 — success — for a third sample into a
    // capacity-2 store, and writes anyway. Confirmed in plain C too. There is
    // no error to propagate, which is why `loadSlice` carries `loaded` and
    // asserts instead; the assertion is not exercised here because a failed
    // assert aborts the test process.
    var extra: [1]f32 = .{2};
    try knn.load(1, @ptrCast(&extra));
    try testing.expectEqual(@as(u32, 2), knn.loaded);
}
