//! Standalone tensor utilities from `bnns.h`: copy, transpose, size queries,
//! reduction and top-k.
//!
//! These take `NDArrayDescriptor`, the older and more general of BNNS's two
//! tensor descriptors. Two conventions matter and neither is obvious:
//!
//! * `size` is ordered **fastest-varying axis first**. For a row-major matrix
//!   with R rows and C columns, `size = .{ C, R }`. This is the opposite of the
//!   shape order `Tensor.init` takes.
//! * A `stride` entry of 0 means "contiguous along this axis", so a
//!   zero-initialised `stride` describes a densely packed array. That is the
//!   opposite of `Tensor`, where a 0 stride is a literal 0.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const DataType = types.DataType;
const DataLayout = types.DataLayout;
const NDArrayDescriptor = types.NDArrayDescriptor;
const Tensor = types.Tensor;
const FilterParameters = types.FilterParameters;
const Error = types.Error;
const check = types.check;

/// Build a densely packed `NDArrayDescriptor` over `data`.
///
/// `size` is in BNNS order — fastest-varying axis first — and must have as many
/// entries as `layout`'s rank. Strides are left at 0, which BNNS reads as
/// "contiguous".
///
/// The element count implied by `size` is asserted against `data.len`, because
/// a descriptor that overstates its extent reads past the end of the slice.
pub fn descriptor(comptime T: type, data: []T, layout: DataLayout, size: []const usize) NDArrayDescriptor {
    std.debug.assert(size.len >= 1 and size.len <= types.max_tensor_dimension);
    var count: usize = 1;
    for (size) |s| count *= s;
    std.debug.assert(count == data.len);

    var d = NDArrayDescriptor{
        .layout = layout,
        .data = @ptrCast(data.ptr),
        .data_type = DataType.of(T),
    };
    for (size, 0..) |s, i| d.size[i] = s;
    return d;
}

/// The rank implied by a `DataLayout`, as BNNS itself decodes it.
///
/// `BNNSDataLayoutGetRank`. Prefer this to reading the top nibbles of the enum
/// value by hand.
pub fn layoutRank(layout: DataLayout) usize {
    return c.BNNSDataLayoutGetRank(layout);
}

/// Size in bytes of the data an `NDArrayDescriptor` describes.
///
/// `BNNSNDArrayGetDataSize`. Returns **0** for every sub-byte data type — the
/// `int1/2/4`, `uint1/2/3/4/6` and `indexed*` families — rather than the packed
/// byte count. Measured against Accelerate on macOS 15.7.7 / arm64; the header
/// does not mention it. Size those buffers yourself. Zero is also what a
/// genuinely empty descriptor returns, so it is not usable as an error signal.
pub fn dataSize(desc: *const NDArrayDescriptor) usize {
    return c.BNNSNDArrayGetDataSize(desc);
}

/// Size in bytes that must be allocated for a `Tensor`'s data.
///
/// `BNNSTensorGetAllocationSize`. Derived from `shape` and `stride`, so the
/// strides must be filled in first.
pub fn allocationSize(tensor: *const Tensor) usize {
    return c.BNNSTensorGetAllocationSize(tensor);
}

/// Copy `src` into `dest`, converting data type and layout as needed.
///
/// `BNNSCopy`. The two descriptors need not agree on data type; BNNS converts.
pub fn copy(dest: *NDArrayDescriptor, src: *const NDArrayDescriptor, filter_params: ?*const FilterParameters) Error!void {
    return check(c.BNNSCopy(dest, src, filter_params));
}

/// Transpose `src` into `dest` by exchanging two axes.
///
/// `BNNSTranspose`. Axis indices are in BNNS order (fastest-varying first), so
/// for a rank-2 array `axis0 = 0, axis1 = 1` is the ordinary matrix transpose.
/// `dest`'s `size` must already reflect the swapped extents.
pub fn transpose(dest: *NDArrayDescriptor, src: *const NDArrayDescriptor, axis0: usize, axis1: usize, filter_params: ?*const FilterParameters) Error!void {
    return check(c.BNNSTranspose(dest, src, axis0, axis1, filter_params));
}

/// Parameters for `reduce`. Mirrors `BNNSLayerParametersReduction`.
pub const ReductionParams = c.BNNSLayerParametersReduction;

/// Reduce along whichever axes `o_desc` collapses relative to `i_desc`.
///
/// `BNNSDirectApplyReduction`. The reduced axes are implied by the shapes: an
/// output extent of 1 where the input extent is N reduces that axis. `epsilon`
/// is added to the argument of `.sum_log` and ignored otherwise.
pub fn reduce(params: *const ReductionParams, filter_params: ?*const FilterParameters) Error!void {
    return check(c.BNNSDirectApplyReduction(params, filter_params));
}

/// Find the `k` largest values along `axis`.
///
/// `BNNSDirectApplyTopK`. `best_values` receives the values and `best_indices`
/// their positions in the input. The `*_batch_stride` arguments step between
/// consecutive items of a batch, in elements, and are ignored when
/// `batch_size` is 1. `best_indices` must have an integer data type — BNNS
/// rejects a float one.
///
/// `best_indices` is NOT optional here, even though the C header marks it
/// `_Nullable` when the deployment target is macOS 13 or later. Passing NULL
/// makes `BNNSDirectApplyTopK` spin without returning — reproduced in plain C
/// against Accelerate on macOS 15.7.7 / arm64, so it is the framework's
/// behaviour and not an artifact of this binding. Requiring the descriptor
/// makes the hang unreachable; discard the indices if you do not want them.
/// `c.zig` still declares the parameter as optional, matching the header.
pub fn topK(
    k: usize,
    axis: usize,
    batch_size: usize,
    input: *const NDArrayDescriptor,
    input_batch_stride: usize,
    best_values: *NDArrayDescriptor,
    best_values_batch_stride: usize,
    best_indices: *NDArrayDescriptor,
    best_indices_batch_stride: usize,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSDirectApplyTopK(
        k,
        axis,
        batch_size,
        input,
        input_batch_stride,
        best_values,
        best_values_batch_stride,
        best_indices,
        best_indices_batch_stride,
        filter_params,
    ));
}

/// Test whether given indices fall within the top `k` along `axis`.
///
/// `BNNSDirectApplyInTopK`. `test_indices` holds the candidate positions and
/// `output` receives one flag per candidate.
pub fn inTopK(
    k: usize,
    axis: usize,
    batch_size: usize,
    input: *const NDArrayDescriptor,
    input_batch_stride: usize,
    test_indices: *const NDArrayDescriptor,
    test_indices_batch_stride: usize,
    output: *NDArrayDescriptor,
    output_batch_stride: usize,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSDirectApplyInTopK(
        k,
        axis,
        batch_size,
        input,
        input_batch_stride,
        test_indices,
        test_indices_batch_stride,
        output,
        output_batch_stride,
        filter_params,
    ));
}

// ============================================================================
// Tests
// ============================================================================

test "layoutRank decodes the rank BNNS encodes in a DataLayout" {
    const testing = std.testing;
    try testing.expectEqual(@as(usize, 1), layoutRank(.vector));
    try testing.expectEqual(@as(usize, 1), layoutRank(.@"1d_first_major"));
    try testing.expectEqual(@as(usize, 2), layoutRank(.row_major_matrix));
    try testing.expectEqual(@as(usize, 2), layoutRank(.column_major_matrix));
    try testing.expectEqual(@as(usize, 3), layoutRank(.image_chw));
    try testing.expectEqual(@as(usize, 4), layoutRank(.@"4d_first_major"));
    try testing.expectEqual(@as(usize, 8), layoutRank(.@"8d_first_major"));
}

test "dataSize returns byte extents for whole-byte types and 0 for sub-byte ones" {
    const testing = std.testing;

    var f: [12]f32 = @splat(0);
    const df = descriptor(f32, &f, .row_major_matrix, &.{ 4, 3 });
    try testing.expectEqual(@as(usize, 48), dataSize(&df));

    var b: [16]u8 = @splat(0);
    const db = descriptor(u8, &b, .@"1d_first_major", &.{16});
    try testing.expectEqual(@as(usize, 16), dataSize(&db));

    var h: [16]f16 = @splat(0);
    const dh = descriptor(f16, &h, .@"1d_first_major", &.{16});
    try testing.expectEqual(@as(usize, 32), dataSize(&dh));

    // Sub-byte types report 0, not the packed size. A uint4 array of 16
    // elements occupies 8 bytes, but BNNS says 0 — measured in plain C as well
    // as here, so it is the framework's behaviour. Anyone sizing an allocation
    // from this value would allocate nothing.
    for ([_]DataType{ .uint4, .uint2, .uint1, .int4, .indexed4 }) |dt| {
        var packed_desc = db;
        packed_desc.data_type = dt;
        try testing.expectEqual(@as(usize, 0), dataSize(&packed_desc));
    }

    // `boolean` is 0x100008 — eight bits wide despite holding one bit of
    // information — and does report a byte count.
    var bool_desc = db;
    bool_desc.data_type = .boolean;
    try testing.expectEqual(@as(usize, 16), dataSize(&bool_desc));
}

test "allocationSize derives a Tensor's byte extent from shape and stride" {
    const testing = std.testing;
    var data: [24]f32 = @splat(0);
    const t = Tensor.init(f32, &data, &.{ 2, 3, 4 });
    try testing.expectEqual(@as(usize, 24 * @sizeOf(f32)), allocationSize(&t));
}

test "copy converts f32 to f16 element by element" {
    const testing = std.testing;

    var src_data = [_]f32{ 1.0, 2.0, 3.0, 4.0, 5.0, 6.0 };
    var dst_data: [6]f16 = @splat(0);

    const src = descriptor(f32, &src_data, .row_major_matrix, &.{ 3, 2 });
    var dst = descriptor(f16, &dst_data, .row_major_matrix, &.{ 3, 2 });

    try copy(&dst, &src, null);
    for (src_data, dst_data) |s, d| {
        try testing.expectEqual(@as(f16, @floatCast(s)), d);
    }
}

test "transpose exchanges the two axes of a row-major matrix" {
    const testing = std.testing;

    // 2 rows x 3 columns, row-major: size is {columns, rows}.
    var src_data = [_]f32{ 1, 2, 3, 4, 5, 6 };
    var dst_data: [6]f32 = @splat(0);

    const src = descriptor(f32, &src_data, .row_major_matrix, &.{ 3, 2 });
    // The result is 3 rows x 2 columns, so size becomes {2, 3}.
    var dst = descriptor(f32, &dst_data, .row_major_matrix, &.{ 2, 3 });

    try transpose(&dst, &src, 0, 1, null);

    //  1 2 3     1 4
    //  4 5 6  ->  2 5
    //             3 6
    try testing.expectEqualSlices(f32, &.{ 1, 4, 2, 5, 3, 6 }, &dst_data);
}

test "reduce sums a matrix along its fastest-varying axis" {
    const testing = std.testing;

    // 2 rows x 4 columns; sum each row down to a single value.
    var in_data = [_]f32{ 1, 2, 3, 4, 10, 20, 30, 40 };
    var out_data: [2]f32 = @splat(0);

    var params = std.mem.zeroes(ReductionParams);
    params.i_desc = descriptor(f32, &in_data, .row_major_matrix, &.{ 4, 2 });
    params.o_desc = descriptor(f32, &out_data, .row_major_matrix, &.{ 1, 2 });
    params.reduce_func = .sum;
    params.epsilon = 0;

    try reduce(&params, null);
    try testing.expectEqualSlices(f32, &.{ 10, 100 }, &out_data);
}

test "reduce computes max and mean along the same axis" {
    const testing = std.testing;

    var in_data = [_]f32{ 1, 7, 3, 5 };
    var out_data: [1]f32 = @splat(0);

    var params = std.mem.zeroes(ReductionParams);
    params.i_desc = descriptor(f32, &in_data, .row_major_matrix, &.{ 4, 1 });
    params.o_desc = descriptor(f32, &out_data, .row_major_matrix, &.{ 1, 1 });

    params.reduce_func = .max;
    try reduce(&params, null);
    try testing.expectEqual(@as(f32, 7), out_data[0]);

    params.reduce_func = .mean;
    try reduce(&params, null);
    try testing.expectEqual(@as(f32, 4), out_data[0]);

    params.reduce_func = .min;
    try reduce(&params, null);
    try testing.expectEqual(@as(f32, 1), out_data[0]);
}

test "topK returns the k largest values and their positions" {
    const testing = std.testing;

    var in_data = [_]f32{ 3, 9, 1, 7, 5 };
    var val_data: [2]f32 = @splat(0);
    var idx_data: [2]i32 = @splat(0);

    const input = descriptor(f32, &in_data, .@"1d_first_major", &.{5});
    var values = descriptor(f32, &val_data, .@"1d_first_major", &.{2});
    var indices = descriptor(i32, &idx_data, .@"1d_first_major", &.{2});

    try topK(2, 0, 1, &input, 0, &values, 0, &indices, 0, null);

    try testing.expectEqualSlices(f32, &.{ 9, 7 }, &val_data);
    try testing.expectEqualSlices(i32, &.{ 1, 3 }, &idx_data);
}

test "topK hangs on a null index descriptor, so the wrapper does not allow one" {
    // `BNNSDirectApplyTopK`'s `best_indices` is declared `_Nullable` in
    // bnns.h when the deployment target is macOS 13+, but passing NULL never
    // returns. Reproduced in plain C:
    //
    //     BNNSDirectApplyTopK(3, 0, 1, &in, 0, &vals, 0, NULL, 0, NULL);
    //
    // spins indefinitely on macOS 15.7.7 / arm64, while the same call with a
    // real index descriptor returns 0 immediately. `topK` therefore takes a
    // non-optional `*NDArrayDescriptor`, which is what this test pins: if the
    // parameter is ever widened back to `?*NDArrayDescriptor`, this stops
    // compiling and the hazard gets re-read rather than silently reintroduced.
    const testing = std.testing;
    const Param = @typeInfo(@TypeOf(topK)).@"fn".params[7].type.?;
    try testing.expectEqual(*NDArrayDescriptor, Param);
    try testing.expect(@typeInfo(Param) != .optional);

    // The extern still matches the header, so the raw call remains available
    // to anyone who wants to re-test the framework's behaviour.
    const CParam = @typeInfo(@TypeOf(c.BNNSDirectApplyTopK)).@"fn".params[7].type.?;
    try testing.expectEqual(?*NDArrayDescriptor, CParam);
}
