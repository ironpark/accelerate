//! BNNS random number generation.
//!
//! A counter-mode AES stream that fills an `NDArrayDescriptor` directly, so the
//! whole tensor is generated in one call rather than element by element. The
//! generator state is explicit and can be saved and restored, which makes a run
//! reproducible across processes.
//!
//! This is not a cryptographic RNG interface — it is the sampler BNNS uses for
//! weight initialisation and dropout.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const NDArrayDescriptor = types.NDArrayDescriptor;
const FilterParameters = types.FilterParameters;
const RandomGeneratorMethod = types.RandomGeneratorMethod;
const Error = types.Error;
const check = types.check;

/// An owned BNNS random generator.
pub const RandomGenerator = struct {
    handle: c.BNNSRandomGenerator,

    /// Create a generator seeded from the system entropy source.
    ///
    /// `BNNSCreateRandomGenerator`. Use `initWithSeed` when a run needs to be
    /// reproducible.
    pub fn init(method: RandomGeneratorMethod, filter_params: ?*const FilterParameters) Error!RandomGenerator {
        const h = c.BNNSCreateRandomGenerator(method, filter_params);
        if (h == null) return Error.BnnsAllocationFailed;
        return .{ .handle = h };
    }

    /// Create a generator from an explicit seed.
    ///
    /// `BNNSCreateRandomGeneratorWithSeed`. Two generators created with the
    /// same method and seed produce the same stream.
    pub fn initWithSeed(method: RandomGeneratorMethod, seed: u64, filter_params: ?*const FilterParameters) Error!RandomGenerator {
        const h = c.BNNSCreateRandomGeneratorWithSeed(method, seed, filter_params);
        if (h == null) return Error.BnnsAllocationFailed;
        return .{ .handle = h };
    }

    /// `BNNSDestroyRandomGenerator`.
    pub fn deinit(self: *RandomGenerator) void {
        c.BNNSDestroyRandomGenerator(self.handle);
        self.handle = null;
    }

    /// Size in bytes of this generator's saveable state.
    ///
    /// `BNNSRandomGeneratorStateSize`. Depends on the method, so query it
    /// rather than assuming a fixed size.
    pub fn stateSize(self: RandomGenerator) usize {
        return c.BNNSRandomGeneratorStateSize(self.handle);
    }

    /// Copy the generator's state into `state`.
    ///
    /// `BNNSRandomGeneratorGetState`. `state.len` must be at least
    /// `stateSize()`.
    pub fn getState(self: RandomGenerator, state: []u8) Error!void {
        return check(c.BNNSRandomGeneratorGetState(self.handle, state.len, @ptrCast(state.ptr)));
    }

    /// Restore the generator's state from `state`, so that it resumes the
    /// stream from exactly where the state was captured.
    ///
    /// `BNNSRandomGeneratorSetState`. Note that BNNS types the `state`
    /// parameter as non-const `void *` even though it only reads it.
    pub fn setState(self: RandomGenerator, state: []u8) Error!void {
        return check(c.BNNSRandomGeneratorSetState(self.handle, state.len, @ptrCast(state.ptr)));
    }

    /// Fill a float tensor with values drawn uniformly from `[a, b)`.
    ///
    /// `BNNSRandomFillUniformFloat`.
    pub fn fillUniformFloat(self: RandomGenerator, desc: *NDArrayDescriptor, a: f32, b: f32) Error!void {
        return check(c.BNNSRandomFillUniformFloat(self.handle, desc, a, b));
    }

    /// Fill an integer tensor with values drawn uniformly from `[a, b)`.
    ///
    /// `BNNSRandomFillUniformInt`.
    pub fn fillUniformInt(self: RandomGenerator, desc: *NDArrayDescriptor, a: i64, b: i64) Error!void {
        return check(c.BNNSRandomFillUniformInt(self.handle, desc, a, b));
    }

    /// Fill a float tensor with normally distributed values.
    ///
    /// `BNNSRandomFillNormalFloat`.
    pub fn fillNormalFloat(self: RandomGenerator, desc: *NDArrayDescriptor, mean: f32, stddev: f32) Error!void {
        return check(c.BNNSRandomFillNormalFloat(self.handle, desc, mean, stddev));
    }

    /// Draw category indices according to `probabilities`.
    ///
    /// `BNNSRandomFillCategoricalFloat`. Set `log_probabilities` when
    /// `probabilities` holds log-probabilities rather than probabilities.
    ///
    /// Both descriptors are `const` here, matching the header — BNNS writes
    /// through the `data` pointer inside `desc` rather than to the descriptor.
    pub fn fillCategoricalFloat(
        self: RandomGenerator,
        desc: *const NDArrayDescriptor,
        probabilities: *const NDArrayDescriptor,
        log_probabilities: bool,
    ) Error!void {
        return check(c.BNNSRandomFillCategoricalFloat(self.handle, desc, probabilities, log_probabilities));
    }
};

// ============================================================================
// Tests
// ============================================================================

const tensor = @import("tensor.zig");

test "a seeded generator produces a reproducible stream" {
    const testing = std.testing;

    var a_data: [64]f32 = @splat(0);
    var b_data: [64]f32 = @splat(0);

    {
        var g = try RandomGenerator.initWithSeed(.aes_ctr, 12345, null);
        defer g.deinit();
        var d = tensor.descriptor(f32, &a_data, .@"1d_first_major", &.{64});
        try g.fillUniformFloat(&d, 0, 1);
    }
    {
        var g = try RandomGenerator.initWithSeed(.aes_ctr, 12345, null);
        defer g.deinit();
        var d = tensor.descriptor(f32, &b_data, .@"1d_first_major", &.{64});
        try g.fillUniformFloat(&d, 0, 1);
    }

    try testing.expectEqualSlices(f32, &a_data, &b_data);

    // And the values are actually in range, and not all identical.
    var all_same = true;
    for (a_data) |v| {
        try testing.expect(v >= 0 and v < 1);
        if (v != a_data[0]) all_same = false;
    }
    try testing.expect(!all_same);
}

test "different seeds produce different streams" {
    const testing = std.testing;

    var a_data: [32]f32 = @splat(0);
    var b_data: [32]f32 = @splat(0);

    var g1 = try RandomGenerator.initWithSeed(.aes_ctr, 1, null);
    defer g1.deinit();
    var d1 = tensor.descriptor(f32, &a_data, .@"1d_first_major", &.{32});
    try g1.fillUniformFloat(&d1, 0, 1);

    var g2 = try RandomGenerator.initWithSeed(.aes_ctr, 2, null);
    defer g2.deinit();
    var d2 = tensor.descriptor(f32, &b_data, .@"1d_first_major", &.{32});
    try g2.fillUniformFloat(&d2, 0, 1);

    try testing.expect(!std.mem.eql(f32, &a_data, &b_data));
}

test "saving and restoring state resumes the same stream" {
    const testing = std.testing;

    var g = try RandomGenerator.initWithSeed(.aes_ctr, 999, null);
    defer g.deinit();

    const n = g.stateSize();
    try testing.expect(n > 0);

    const state = try testing.allocator.alloc(u8, n);
    defer testing.allocator.free(state);
    try g.getState(state);

    var first: [16]f32 = @splat(0);
    var d1 = tensor.descriptor(f32, &first, .@"1d_first_major", &.{16});
    try g.fillUniformFloat(&d1, -1, 1);

    // Rewind to the captured state and draw again.
    try g.setState(state);
    var second: [16]f32 = @splat(0);
    var d2 = tensor.descriptor(f32, &second, .@"1d_first_major", &.{16});
    try g.fillUniformFloat(&d2, -1, 1);

    try testing.expectEqualSlices(f32, &first, &second);
}

test "fillUniformInt stays inside the half-open range" {
    const testing = std.testing;

    var data: [256]i32 = @splat(0);
    var g = try RandomGenerator.initWithSeed(.aes_ctr, 7, null);
    defer g.deinit();

    var d = tensor.descriptor(i32, &data, .@"1d_first_major", &.{256});
    try g.fillUniformInt(&d, 10, 20);

    var seen_low = false;
    var seen_high = false;
    for (data) |v| {
        try testing.expect(v >= 10 and v < 20);
        if (v == 10) seen_low = true;
        if (v == 19) seen_high = true;
    }
    // With 256 draws over 10 values, both endpoints should show up. This pins
    // that the range is [a, b) and not [a, b] or (a, b).
    try testing.expect(seen_low and seen_high);
}

test "fillNormalFloat produces roughly the requested mean and stddev" {
    const testing = std.testing;

    var data: [4096]f32 = @splat(0);
    var g = try RandomGenerator.initWithSeed(.aes_ctr, 4242, null);
    defer g.deinit();

    var d = tensor.descriptor(f32, &data, .@"1d_first_major", &.{4096});
    try g.fillNormalFloat(&d, 5.0, 2.0);

    var sum: f64 = 0;
    for (data) |v| sum += v;
    const mean = sum / @as(f64, data.len);

    var var_sum: f64 = 0;
    for (data) |v| {
        const dv = @as(f64, v) - mean;
        var_sum += dv * dv;
    }
    const stddev = @sqrt(var_sum / @as(f64, data.len));

    // The standard error of the mean over 4096 draws at sigma=2 is about
    // 0.031, so 0.2 is a wide but non-vacuous bound.
    try testing.expectApproxEqAbs(@as(f64, 5.0), mean, 0.2);
    try testing.expectApproxEqAbs(@as(f64, 2.0), stddev, 0.2);
}
