//! Standalone tensor operations from `bnns.h`: matrix multiply, gather and
//! scatter, tile, shuffle, band-part, elementwise comparison and crop-resize.
//!
//! **Every entry point in this file belongs to the layer-filter generation of
//! BNNS, which Apple deprecated in macOS 15.0** in favour of the Graph API
//! (`bnns.Graph` here, `BNNSGraph*` in C). They are bound because macOS 15.0 is
//! a recent floor and callers on an older deployment target have nothing else
//! to reach for. Each function repeats its own deprecation version, because
//! they are not all the same: most arrived in macOS 13.0 and went in 15.0, but
//! `compareTensor` goes back to 11.0.
//!
//! These are the friendliest members of the deprecated set — descriptors in,
//! descriptors out, no `BNNSFilter` to create and destroy, no training state.
//! Build the descriptors with `tensor.descriptor`. Nothing here allocates
//! memory the caller must free, and nothing retains a descriptor past the call.
//!
//! ## Axis order, which is where the bodies are buried
//!
//! An `NDArrayDescriptor` carries both a `layout` and a `size` array, and the
//! meaning of `size[0]` depends on the layout. For the generic
//! `Nd_first_major` layouts — what this module uses throughout — `size` is the
//! ordinary logical shape, **outermost (slowest-varying) axis first**: a
//! row-major R-by-C matrix is `.@"2d_first_major"` with `size = .{ R, C }`.
//! (`.row_major_matrix` is the reverse, `.{ C, R }`; `tensor.zig` documents
//! that convention because `BNNSTranspose` uses it.)
//!
//! Three behaviours measured against Accelerate on macOS 15.7.7 / arm64 that
//! the header does not state, and that cost real debugging time:
//!
//! * `gather` and `scatter` take `axis` in the same order as the descriptor's
//!   `size`, so with a first-major descriptor `axis = 0` is rows.
//! * **`tile` reverses the axis order** relative to everything else here,
//!   including its own backward pass `tileBackward`. See `tile`.
//! * **`bandPart` corrupts its output when handed a `.row_major_matrix` or
//!   `.column_major_matrix` descriptor** — it returns 0 having written only
//!   part of the buffer. Use `.@"2d_first_major"`. See `bandPart`.
//!
//! `matMul` is the one call that wants scratch memory: ask
//! `matMulWorkspaceSize` first and pass a buffer of at least that many bytes,
//! or pass null and let BNNS allocate internally.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");
const tensor = @import("tensor.zig");

const NDArrayDescriptor = types.NDArrayDescriptor;
const FilterParameters = types.FilterParameters;
const ReduceFunction = types.ReduceFunction;
const RelationalOperator = types.RelationalOperator;
const ShuffleType = types.ShuffleType;
const LayerParametersCropResize = types.LayerParametersCropResize;
const Error = types.Error;
const check = types.check;

// ============================================================================
// Matrix multiplication
// ============================================================================

/// Bytes of scratch `matMul` wants for these exact arguments.
///
/// `BNNSMatMulWorkspaceSize`. It does not dereference the descriptors' `data`
/// pointers, so it can be asked before any buffer exists. The C function
/// returns `ssize_t` and signals invalid parameters with a *negative* value,
/// not with `SIZE_MAX`, so this returns `Error.BnnsQueryFailed` on a negative
/// result rather than going through `checkSize`. A return of 0 is legitimate
/// and means no scratch is needed.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn matMulWorkspaceSize(
    trans_a: bool,
    trans_b: bool,
    alpha: f32,
    input_a: *const NDArrayDescriptor,
    input_b: *const NDArrayDescriptor,
    output: *const NDArrayDescriptor,
    filter_params: ?*const FilterParameters,
) Error!usize {
    const n = c.BNNSMatMulWorkspaceSize(trans_a, trans_b, alpha, input_a, input_b, output, filter_params);
    if (n < 0) return Error.BnnsQueryFailed;
    return @intCast(n);
}

/// `C = alpha * op(A) * op(B)`, broadcasting every axis but the last two.
///
/// `BNNSMatMul`. The product is always over the final two axes of each
/// operand — the last two entries of a first-major `size` — and the leading
/// axes are matched from the back, an extent of 1 being broadcast. `trans_a`
/// and `trans_b` transpose those last two axes of the respective operand.
///
/// `workspace` may be null, in which case BNNS allocates internally; if given
/// it must be at least `matMulWorkspaceSize` bytes. Only `output`'s data is
/// written, never its descriptor fields, which is why the C prototype takes it
/// as a pointer to const.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn matMul(
    trans_a: bool,
    trans_b: bool,
    alpha: f32,
    input_a: *const NDArrayDescriptor,
    input_b: *const NDArrayDescriptor,
    output: *const NDArrayDescriptor,
    workspace: ?*anyopaque,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSMatMul(trans_a, trans_b, alpha, input_a, input_b, output, workspace, filter_params));
}

// ============================================================================
// Comparison
// ============================================================================

/// Elementwise comparison or logical operation, producing a boolean mask.
///
/// `BNNSCompareTensor`. `out` must have the same extents as the inputs and
/// data type `.boolean` (`BNNSDataTypeBoolean8`); a float or integer output is
/// rejected with a nonzero status rather than converted. `op` may also be one
/// of the logical members of `RelationalOperator`, in which case the inputs
/// are themselves boolean, and `.logical_not` is unary and reads `in0` only.
///
/// Note the missing `filter_params`: this is the one function in the file that
/// does not take one.
///
/// Introduced in macOS 11.0, deprecated in macOS 15.0. Prefer the Graph API
/// (`bnns.Graph`).
pub fn compareTensor(
    in0: *const NDArrayDescriptor,
    in1: *const NDArrayDescriptor,
    op: RelationalOperator,
    out: *NDArrayDescriptor,
) Error!void {
    return check(c.BNNSCompareTensor(in0, in1, op, out));
}

// ============================================================================
// Tile
// ============================================================================

/// Replicate `input` to fill `output`.
///
/// `BNNSTile`. The repeat counts are implied, not passed: each of `output`'s
/// extents must be an integer multiple of the corresponding one of `input`'s,
/// and that multiple is the repeat count for the axis.
///
/// **`BNNSTile` reads `size` back-to-front.** Measured against Accelerate on
/// macOS 15.7.7 / arm64: the repeat count derived from `size[i]` is applied to
/// axis `rank - 1 - i`, i.e. the opposite end of the array from where every
/// other function here — `tileBackward` included — would apply it. So to
/// repeat the three-element row `[1 2 3]` into two rows of a first-major
/// descriptor, give the input `size = .{ 3, 1 }` and the output
/// `size = .{ 3, 2 }`: innermost axis first, the reverse of the usual order.
/// Describing the same tensors in the usual order runs without error and
/// produces `{1, 1, 2, 2, 3, 3}` instead.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn tile(
    input: *const NDArrayDescriptor,
    output: *NDArrayDescriptor,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSTile(input, output, filter_params));
}

/// Backward pass of `tile`: reduce `out_delta` into `in_delta`.
///
/// `BNNSTileBackward`. The forward pass copies one input element to several
/// output elements, so the gradient sums over the copies: `in_delta[i]` gets
/// the sum of every `out_delta` element the forward pass would have filled
/// from `i`. Note the argument order — the destination comes first, unlike the
/// forward call.
///
/// Unlike `tile`, this reads `size` in the ordinary order for the layout, so
/// a forward/backward pair cannot use the same descriptors. Measured; see
/// `tile`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn tileBackward(
    in_delta: *NDArrayDescriptor,
    out_delta: *const NDArrayDescriptor,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSTileBackward(in_delta, out_delta, filter_params));
}

// ============================================================================
// Gather and scatter
// ============================================================================

/// Gather elements along one axis:
/// `output[i_0..i_axis..] = input[i_0..idx..]`.
///
/// `BNNSGather`. `indices` is read one of two ways: as a 1-D vector, giving
/// `idx = indices[i_axis]`, or as a tensor shaped like `output`, giving `idx`
/// elementwise. `output` then matches `input` except along `axis`, whose
/// extent becomes the length of `indices`.
///
/// `axis` is an index into the descriptor's `size`, so with a first-major
/// descriptor `axis = 0` selects rows and `axis = 1` columns. An index outside
/// the input's extent is an error (status -1005), never a clamp.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn gather(
    axis: usize,
    input: *const NDArrayDescriptor,
    indices: *const NDArrayDescriptor,
    output: *NDArrayDescriptor,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSGather(axis, input, indices, output, filter_params));
}

/// Scatter elements along one axis:
/// `output[i_0..idx..] = op(output[i_0..idx..], input[i_0..i_axis..])`.
///
/// `BNNSScatter`. The inverse of `gather`; `indices` is read the same two
/// ways, but sized against `input` rather than `output`. `output` is read as
/// well as written — positions no index names keep whatever the buffer held —
/// so zero it first unless you mean to accumulate into it.
///
/// Only `.none` (plain overwrite) and `.sum` are implemented as `op`. When two
/// input elements land on the same output element the order is unspecified,
/// so with `.none` the winner is arbitrary.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn scatter(
    axis: usize,
    op: ReduceFunction,
    input: *const NDArrayDescriptor,
    indices: *const NDArrayDescriptor,
    output: *NDArrayDescriptor,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSScatter(axis, op, input, indices, output, filter_params));
}

/// Gather elements or whole slices addressed by multi-dimensional index
/// vectors.
///
/// `BNNSGatherND`. `indices` is a rank-`k` tensor read as a rank-`(k-1)` grid
/// of 1-D lookup vectors; with a first-major descriptor the *last* axis holds
/// one lookup vector, so `size = .{ 3, 2 }` is three vectors of length two. A
/// lookup vector shorter than the input's rank names a slice rather than an
/// element: for a rank-3 input, `{1}` selects `input[1, :, :]` and `{3, 2}`
/// selects `input[3, 2, :]`.
///
/// `output`'s shape is therefore the grid shape followed by the trailing
/// `rank(input) - L` axes of the input, where `L` is the lookup-vector length.
/// Getting that wrong gives status -1003. Out-of-range indices are an error.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn gatherND(
    input: *const NDArrayDescriptor,
    indices: *const NDArrayDescriptor,
    output: *NDArrayDescriptor,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSGatherND(input, indices, output, filter_params));
}

/// Scatter elements or whole slices addressed by multi-dimensional index
/// vectors.
///
/// `BNNSScatterND`. The inverse of `gatherND`, with `indices` read the same
/// way and `input` shaped as `gatherND`'s output would be. As with `scatter`,
/// `output` is read-modify-write, only `.none` and `.sum` are implemented, and
/// collisions resolve in an unspecified order.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn scatterND(
    op: ReduceFunction,
    input: *const NDArrayDescriptor,
    indices: *const NDArrayDescriptor,
    output: *NDArrayDescriptor,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSScatterND(op, input, indices, output, filter_params));
}

// ============================================================================
// Shuffle and band part
// ============================================================================

/// Move data between the channel and spatial axes of an NCHW tensor.
///
/// `BNNSShuffle`. All four `ShuffleType` members are rank-4 NCHW only, and in
/// practice that means a `.@"4d_first_major"` descriptor with
/// `size = .{ N, C, H, W }`; a `.@"4d_last_major"` or
/// `.convolution_weights_oihw` descriptor is rejected outright.
///
/// The block factor is implied rather than passed: a `(N, C*r*r, H, W)` input
/// with a `(N, C, H*r, W*r)` output means `r`. `pixel_shuffle_nchw` and
/// `depth_to_space_nchw` differ only in element ordering, and only when
/// `C > 1`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn shuffle(
    shuffle_type: ShuffleType,
    input: *const NDArrayDescriptor,
    output: *NDArrayDescriptor,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSShuffle(shuffle_type, input, output, filter_params));
}

/// Copy `input` to `output`, zeroing everything outside a diagonal band.
///
/// `BNNSBandPart`. Operates on the innermost matrix — the two axes with the
/// smallest strides — and repeats over any leading axes. `num_lower`
/// subdiagonals and `num_upper` superdiagonals survive: element `(i, j)` is
/// kept when `(num_lower < 0 or i - j <= num_lower)` and
/// `(num_upper < 0 or j - i <= num_upper)`. A negative count means "the whole
/// triangle", so `(-1, 0)` is a lower-triangular mask, `(0, -1)` an upper one
/// and `(0, 0)` the diagonal alone. Both are C `int`, hence `i32`.
///
/// **Use a `.@"2d_first_major"` descriptor.** Measured against Accelerate on
/// macOS 15.7.7 / arm64: given a `.row_major_matrix` or
/// `.column_major_matrix` descriptor of the same 4x4, `BNNSBandPart` returns 0
/// but writes only the first seven elements of the output and masks them
/// against the wrong diagonal. There is no error to check for, so the choice
/// of layout is the whole defence.
///
/// Both tensors must also be contiguous; the header says so and does not check
/// it.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn bandPart(
    num_lower: i32,
    num_upper: i32,
    input: *const NDArrayDescriptor,
    output: *NDArrayDescriptor,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSBandPart(num_lower, num_upper, input, output, filter_params));
}

// ============================================================================
// Crop and resize
// ============================================================================

/// Crop each region of interest out of `input` and resize it to `output`'s
/// spatial extent.
///
/// `BNNSCropResize`. The spatial axes are the two with the smallest strides
/// (H and W of an NCHW tensor). `roi` is meant to hold one box per row — the
/// four coordinates in `layer_params.box_coordinate_mode` order, plus the
/// index of the input batch element the box crops from — and `output`'s batch
/// extent is meant to be the number of boxes. Only bilinear interpolation is
/// implemented, and all three tensors must be contiguous.
///
/// **Not usable as bound, on this OS.** Measured against Accelerate on macOS
/// 15.7.7 / arm64: every configuration tried returns -1 without touching the
/// output — inputs of rank 2, 3, 4 and 5; `roi` of rank 1, 2, 4 and 5 with
/// four and with five values per box; normalized and absolute coordinates; all
/// four `BoxCoordinateMode`s; all five `LinearSamplingMode`s; both
/// `InterpolationMethod`s; one box and two; and a batch of two images. The
/// framework logs its reason to `os_log` as private data, so it is not
/// recoverable from here. The wrapper is kept because the signature is right
/// and an older OS may well accept it; see the test at the bottom of this file
/// for the exact matrix that was tried.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn cropResize(
    layer_params: *const LayerParametersCropResize,
    input: *const NDArrayDescriptor,
    roi: *const NDArrayDescriptor,
    output: *NDArrayDescriptor,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSCropResize(layer_params, input, roi, output, filter_params));
}

/// Backward pass of `cropResize`: scatter `out_delta` back onto `in_delta`.
///
/// `BNNSCropResizeBackward`. `roi` and `layer_params` must be the boxes and
/// parameters the forward pass used. `in_delta` is the destination and comes
/// second, before the source `out_delta`. Contiguous tensors only.
///
/// Shares `cropResize`'s fate: -1 for every configuration tried on macOS
/// 15.7.7 / arm64. See `cropResize`.
///
/// Deprecated in macOS 15.0. Prefer the Graph API (`bnns.Graph`).
pub fn cropResizeBackward(
    layer_params: *const LayerParametersCropResize,
    in_delta: *NDArrayDescriptor,
    roi: *const NDArrayDescriptor,
    out_delta: *const NDArrayDescriptor,
    filter_params: ?*const FilterParameters,
) Error!void {
    return check(c.BNNSCropResizeBackward(layer_params, in_delta, roi, out_delta, filter_params));
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;
const descriptor = tensor.descriptor;

test "matMul multiplies a 2x3 by a 3x2 with an explicit workspace" {
    // A = [ 1 2 3 ]   B = [  7  8 ]   A*B = [  58  64 ]
    //     [ 4 5 6 ]       [  9 10 ]         [ 139 154 ]
    //                     [ 11 12 ]
    var a_data = [_]f32{ 1, 2, 3, 4, 5, 6 };
    var b_data = [_]f32{ 7, 8, 9, 10, 11, 12 };
    var c_data: [4]f32 = @splat(-1);

    const a = descriptor(f32, &a_data, .@"2d_first_major", &.{ 2, 3 });
    const b = descriptor(f32, &b_data, .@"2d_first_major", &.{ 3, 2 });
    const out = descriptor(f32, &c_data, .@"2d_first_major", &.{ 2, 2 });

    const ws_bytes = try matMulWorkspaceSize(false, false, 1.0, &a, &b, &out, null);
    const ws = try testing.allocator.alignedAlloc(u8, .of(f64), @max(ws_bytes, 1));
    defer testing.allocator.free(ws);

    try matMul(false, false, 1.0, &a, &b, &out, ws.ptr, null);
    try testing.expectEqualSlices(f32, &.{ 58, 64, 139, 154 }, &c_data);
}

test "matMul accepts a null workspace and applies alpha" {
    var a_data = [_]f32{ 1, 2, 3, 4, 5, 6 };
    var b_data = [_]f32{ 7, 8, 9, 10, 11, 12 };
    var c_data: [4]f32 = @splat(-1);

    const a = descriptor(f32, &a_data, .@"2d_first_major", &.{ 2, 3 });
    const b = descriptor(f32, &b_data, .@"2d_first_major", &.{ 3, 2 });
    const out = descriptor(f32, &c_data, .@"2d_first_major", &.{ 2, 2 });

    try matMul(false, false, 2.0, &a, &b, &out, null, null);
    try testing.expectEqualSlices(f32, &.{ 116, 128, 278, 308 }, &c_data);
}

test "matMul transposes the last two axes of A when asked" {
    // A is stored 3x2; transA turns it into the 2x3 of the test above.
    //   stored A = [ 1 4 ]  ->  op(A) = [ 1 2 3 ]
    //              [ 2 5 ]              [ 4 5 6 ]
    //              [ 3 6 ]
    var a_data = [_]f32{ 1, 4, 2, 5, 3, 6 };
    var b_data = [_]f32{ 7, 8, 9, 10, 11, 12 };
    var c_data: [4]f32 = @splat(-1);

    const a = descriptor(f32, &a_data, .@"2d_first_major", &.{ 3, 2 });
    const b = descriptor(f32, &b_data, .@"2d_first_major", &.{ 3, 2 });
    const out = descriptor(f32, &c_data, .@"2d_first_major", &.{ 2, 2 });

    try matMul(true, false, 1.0, &a, &b, &out, null, null);
    try testing.expectEqualSlices(f32, &.{ 58, 64, 139, 154 }, &c_data);
}

test "matMul broadcasts a rank-2 B across a batch of A" {
    // A is (2, 2, 3): the 2x3 above, then the first two rows of the identity.
    // B is (3, 2) and is repeated across the batch, so the second output is
    // just B's first two rows.
    var a_data = [_]f32{
        1, 2, 3, 4, 5, 6,
        1, 0, 0, 0, 1, 0,
    };
    var b_data = [_]f32{ 7, 8, 9, 10, 11, 12 };
    var c_data: [8]f32 = @splat(-1);

    const a = descriptor(f32, &a_data, .@"3d_first_major", &.{ 2, 2, 3 });
    const b = descriptor(f32, &b_data, .@"2d_first_major", &.{ 3, 2 });
    const out = descriptor(f32, &c_data, .@"3d_first_major", &.{ 2, 2, 2 });

    try matMul(false, false, 1.0, &a, &b, &out, null, null);
    try testing.expectEqualSlices(f32, &.{ 58, 64, 139, 154, 7, 8, 9, 10 }, &c_data);
}

test "matMulWorkspaceSize answers without touching the data pointers" {
    var a_data = [_]f32{ 1, 2, 3, 4, 5, 6 };
    var b_data = [_]f32{ 7, 8, 9, 10, 11, 12 };
    var c_data: [4]f32 = @splat(0);

    var a = descriptor(f32, &a_data, .@"2d_first_major", &.{ 2, 3 });
    var b = descriptor(f32, &b_data, .@"2d_first_major", &.{ 3, 2 });
    var out = descriptor(f32, &c_data, .@"2d_first_major", &.{ 2, 2 });

    const with_data = try matMulWorkspaceSize(false, false, 1.0, &a, &b, &out, null);

    // The header promises the query ignores `data`, which is what makes it
    // usable for sizing an allocation before the buffers exist.
    a.data = null;
    b.data = null;
    out.data = null;
    const without_data = try matMulWorkspaceSize(false, false, 1.0, &a, &b, &out, null);
    try testing.expectEqual(with_data, without_data);
}

test "matMulWorkspaceSize reports a negative size for shapes that do not multiply" {
    var a_data = [_]f32{ 1, 2, 3, 4, 5, 6 };
    var b_data = [_]f32{ 1, 2, 3, 4, 5, 6 };
    var c_data: [4]f32 = @splat(0);

    // 2x3 times 2x3 is not a legal product: the inner extents are 3 and 2.
    const a = descriptor(f32, &a_data, .@"2d_first_major", &.{ 2, 3 });
    const b = descriptor(f32, &b_data, .@"2d_first_major", &.{ 2, 3 });
    const out = descriptor(f32, &c_data, .@"2d_first_major", &.{ 2, 2 });

    try testing.expectError(
        Error.BnnsQueryFailed,
        matMulWorkspaceSize(false, false, 1.0, &a, &b, &out, null),
    );
}

test "compareTensor produces a known boolean mask" {
    var lhs_data = [_]f32{ 1, 5, 3, 7 };
    var rhs_data = [_]f32{ 2, 5, 1, 9 };
    var mask: [4]bool = @splat(true);

    const lhs = descriptor(f32, &lhs_data, .@"1d_first_major", &.{4});
    const rhs = descriptor(f32, &rhs_data, .@"1d_first_major", &.{4});
    var out = descriptor(bool, &mask, .@"1d_first_major", &.{4});

    try compareTensor(&lhs, &rhs, .greater, &out);
    try testing.expectEqualSlices(bool, &.{ false, false, true, false }, &mask);

    try compareTensor(&lhs, &rhs, .equal, &out);
    try testing.expectEqualSlices(bool, &.{ false, true, false, false }, &mask);

    try compareTensor(&lhs, &rhs, .less_equal, &out);
    try testing.expectEqualSlices(bool, &.{ true, true, false, true }, &mask);
}

test "compareTensor works elementwise across a rank-2 tensor" {
    //  [ 1 2 3 ] >= [ 6 5 4 ]  ->  [ F F F ]
    //  [ 4 5 6 ]    [ 3 2 1 ]      [ T T T ]
    var lhs_data = [_]f32{ 1, 2, 3, 4, 5, 6 };
    var rhs_data = [_]f32{ 6, 5, 4, 3, 2, 1 };
    var mask: [6]bool = @splat(false);

    const lhs = descriptor(f32, &lhs_data, .@"2d_first_major", &.{ 2, 3 });
    const rhs = descriptor(f32, &rhs_data, .@"2d_first_major", &.{ 2, 3 });
    var out = descriptor(bool, &mask, .@"2d_first_major", &.{ 2, 3 });

    try compareTensor(&lhs, &rhs, .greater_equal, &out);
    try testing.expectEqualSlices(bool, &.{ false, false, false, true, true, true }, &mask);
}

test "compareTensor rejects a non-boolean output tensor" {
    var lhs_data = [_]f32{ 1, 5, 3, 7 };
    var rhs_data = [_]f32{ 2, 5, 1, 9 };
    var out_data: [4]f32 = @splat(-1);

    const lhs = descriptor(f32, &lhs_data, .@"1d_first_major", &.{4});
    const rhs = descriptor(f32, &rhs_data, .@"1d_first_major", &.{4});
    var out = descriptor(f32, &out_data, .@"1d_first_major", &.{4});

    // Status -1: the mask is not silently written as 1.0/0.0 floats.
    try testing.expectError(Error.BnnsFailed, compareTensor(&lhs, &rhs, .greater, &out));
    try testing.expectEqualSlices(f32, &.{ -1, -1, -1, -1 }, &out_data);
}

test "tile repeats a row, with the extents given innermost-first" {
    // The row [1 2 3] repeated into two rows. Because BNNSTile reverses the
    // axis order, the 1x3 input is described as `.{ 3, 1 }` and the 2x3 output
    // as `.{ 3, 2 }`.
    var in_data = [_]f32{ 1, 2, 3 };
    var out_data: [6]f32 = @splat(-1);

    const input = descriptor(f32, &in_data, .@"2d_first_major", &.{ 3, 1 });
    var output = descriptor(f32, &out_data, .@"2d_first_major", &.{ 3, 2 });

    try tile(&input, &output, null);
    try testing.expectEqualSlices(f32, &.{ 1, 2, 3, 1, 2, 3 }, &out_data);
}

test "tile applies the repeat count from size[i] to axis rank-1-i" {
    // Same descriptors, written the way every other function here reads them:
    // a 1x3 input and a 2x3 output. The repeat lands on the innermost axis
    // instead, so each element is doubled in place. This is the measured
    // behaviour, not the documented one; the test exists so a future OS that
    // fixes it is noticed.
    var in_data = [_]f32{ 1, 2, 3 };
    var out_data: [6]f32 = @splat(-1);

    const input = descriptor(f32, &in_data, .@"2d_first_major", &.{ 1, 3 });
    var output = descriptor(f32, &out_data, .@"2d_first_major", &.{ 2, 3 });

    try tile(&input, &output, null);
    try testing.expectEqualSlices(f32, &.{ 1, 1, 2, 2, 3, 3 }, &out_data);
}

test "tile repeats along the outer and the inner axis" {
    var in_data = [_]f32{ 1, 2, 3, 4, 5, 6 };
    var out_data: [12]f32 = @splat(-1);

    // Reversed order: `.{ 2, 3 }` is a 3-row, 2-column matrix
    // [1 2; 3 4; 5 6].
    const input = descriptor(f32, &in_data, .@"2d_first_major", &.{ 2, 3 });

    // Doubling size[0] doubles the innermost (column) axis.
    var wide = descriptor(f32, &out_data, .@"2d_first_major", &.{ 4, 3 });
    try tile(&input, &wide, null);
    try testing.expectEqualSlices(f32, &.{ 1, 2, 1, 2, 3, 4, 3, 4, 5, 6, 5, 6 }, &out_data);

    // Doubling size[1] doubles the outermost (row) axis: the whole matrix
    // appears twice.
    @memset(&out_data, -1);
    var tall = descriptor(f32, &out_data, .@"2d_first_major", &.{ 2, 6 });
    try tile(&input, &tall, null);
    try testing.expectEqualSlices(f32, &.{ 1, 2, 3, 4, 5, 6, 1, 2, 3, 4, 5, 6 }, &out_data);
}

test "tile repeats a vector three times" {
    var in_data = [_]f32{ 1, 2, 3 };
    var out_data: [9]f32 = @splat(-1);

    const input = descriptor(f32, &in_data, .@"1d_first_major", &.{3});
    var output = descriptor(f32, &out_data, .@"1d_first_major", &.{9});

    // Rank 1 has no axis order to get wrong.
    try tile(&input, &output, null);
    try testing.expectEqualSlices(f32, &.{ 1, 2, 3, 1, 2, 3, 1, 2, 3 }, &out_data);
}

test "tileBackward sums the gradient over the repeated copies" {
    // A 1x3 row tiled into two rows; the gradient adds the two rows. Note the
    // descriptors are in the ordinary outermost-first order here, unlike the
    // forward call above.
    var out_delta_data = [_]f32{ 1, 2, 3, 10, 20, 30 };
    var in_delta_data: [3]f32 = @splat(-1);

    const out_delta = descriptor(f32, &out_delta_data, .@"2d_first_major", &.{ 2, 3 });
    var in_delta = descriptor(f32, &in_delta_data, .@"2d_first_major", &.{ 1, 3 });

    try tileBackward(&in_delta, &out_delta, null);
    try testing.expectEqualSlices(f32, &.{ 11, 22, 33 }, &in_delta_data);
}

test "gather picks elements of a vector by index" {
    var in_data = [_]f32{ 10, 20, 30, 40 };
    var idx_data = [_]i32{ 3, 0, 1 };
    var out_data: [3]f32 = @splat(-1);

    const input = descriptor(f32, &in_data, .@"1d_first_major", &.{4});
    const indices = descriptor(i32, &idx_data, .@"1d_first_major", &.{3});
    var output = descriptor(f32, &out_data, .@"1d_first_major", &.{3});

    try gather(0, &input, &indices, &output, null);
    try testing.expectEqualSlices(f32, &.{ 40, 10, 20 }, &out_data);
}

test "gather along axis 0 reorders rows and along axis 1 reorders columns" {
    // [ 1 2 3 ]
    // [ 4 5 6 ]
    var in_data = [_]f32{ 1, 2, 3, 4, 5, 6 };
    const input = descriptor(f32, &in_data, .@"2d_first_major", &.{ 2, 3 });

    // Rows {1, 1, 0}: the second row twice, then the first.
    var row_idx = [_]i32{ 1, 1, 0 };
    var row_out: [9]f32 = @splat(-1);
    const rows = descriptor(i32, &row_idx, .@"1d_first_major", &.{3});
    var row_desc = descriptor(f32, &row_out, .@"2d_first_major", &.{ 3, 3 });
    try gather(0, &input, &rows, &row_desc, null);
    try testing.expectEqualSlices(f32, &.{ 4, 5, 6, 4, 5, 6, 1, 2, 3 }, &row_out);

    // Columns {2, 0}.
    var col_idx = [_]i32{ 2, 0 };
    var col_out: [4]f32 = @splat(-1);
    const cols = descriptor(i32, &col_idx, .@"1d_first_major", &.{2});
    var col_desc = descriptor(f32, &col_out, .@"2d_first_major", &.{ 2, 2 });
    try gather(1, &input, &cols, &col_desc, null);
    try testing.expectEqualSlices(f32, &.{ 3, 1, 6, 4 }, &col_out);
}

test "gather rejects an out-of-range index rather than clamping" {
    var in_data = [_]f32{ 10, 20, 30, 40 };
    var idx_data = [_]i32{4};
    var out_data: [1]f32 = @splat(-1);

    const input = descriptor(f32, &in_data, .@"1d_first_major", &.{4});
    const indices = descriptor(i32, &idx_data, .@"1d_first_major", &.{1});
    var output = descriptor(f32, &out_data, .@"1d_first_major", &.{1});

    // Status -1005; the output is left alone rather than filled from index 3.
    try testing.expectError(Error.BnnsFailed, gather(0, &input, &indices, &output, null));
    try testing.expectEqual(@as(f32, -1), out_data[0]);
}

test "scatter with .none writes each input element to its indexed slot" {
    var in_data = [_]f32{ 1, 2, 3 };
    var idx_data = [_]i32{ 2, 0, 1 };
    var out_data: [3]f32 = @splat(0);

    const input = descriptor(f32, &in_data, .@"1d_first_major", &.{3});
    const indices = descriptor(i32, &idx_data, .@"1d_first_major", &.{3});
    var output = descriptor(f32, &out_data, .@"1d_first_major", &.{3});

    // out[2] = 1, out[0] = 2, out[1] = 3.
    try scatter(0, .none, &input, &indices, &output, null);
    try testing.expectEqualSlices(f32, &.{ 2, 3, 1 }, &out_data);
}

test "scatter with .sum accumulates into the existing output" {
    var in_data = [_]f32{ 1, 2, 3 };
    var idx_data = [_]i32{ 0, 0, 2 };
    var out_data = [_]f32{ 100, 200, 300 };

    const input = descriptor(f32, &in_data, .@"1d_first_major", &.{3});
    const indices = descriptor(i32, &idx_data, .@"1d_first_major", &.{3});
    var output = descriptor(f32, &out_data, .@"1d_first_major", &.{3});

    // Two inputs collide on slot 0 (100 + 1 + 2), slot 1 is never named and
    // keeps its prior value, slot 2 gets 300 + 3.
    try scatter(0, .sum, &input, &indices, &output, null);
    try testing.expectEqualSlices(f32, &.{ 103, 200, 303 }, &out_data);
}

test "scatter moves whole rows when the axis is the outer one" {
    // Rows of a 2x3 input scattered into rows 2 and 0 of a 3x3 output.
    var in_data = [_]f32{ 1, 2, 3, 4, 5, 6 };
    var idx_data = [_]i32{ 2, 0 };
    var out_data: [9]f32 = @splat(0);

    const input = descriptor(f32, &in_data, .@"2d_first_major", &.{ 2, 3 });
    const indices = descriptor(i32, &idx_data, .@"1d_first_major", &.{2});
    var output = descriptor(f32, &out_data, .@"2d_first_major", &.{ 3, 3 });

    try scatter(0, .none, &input, &indices, &output, null);
    try testing.expectEqualSlices(f32, &.{ 4, 5, 6, 0, 0, 0, 1, 2, 3 }, &out_data);
}

test "gatherND with full-length lookup vectors picks individual elements" {
    // 3x3 matrix; three lookup vectors of length 2 name (0,0), (1,2), (2,1).
    var in_data = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    var idx_data = [_]i32{ 0, 0, 1, 2, 2, 1 };
    var out_data: [3]f32 = @splat(-1);

    const input = descriptor(f32, &in_data, .@"2d_first_major", &.{ 3, 3 });
    // The last axis holds one lookup vector, so this is 3 vectors of 2.
    const indices = descriptor(i32, &idx_data, .@"2d_first_major", &.{ 3, 2 });
    var output = descriptor(f32, &out_data, .@"1d_first_major", &.{3});

    try gatherND(&input, &indices, &output, null);
    try testing.expectEqualSlices(f32, &.{ 1, 6, 8 }, &out_data);
}

test "gatherND with short lookup vectors gathers whole rows" {
    var in_data = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    var idx_data = [_]i32{ 2, 0 };
    var out_data: [6]f32 = @splat(-1);

    const input = descriptor(f32, &in_data, .@"2d_first_major", &.{ 3, 3 });
    // Two lookup vectors of length 1: rows 2 and 0.
    const indices = descriptor(i32, &idx_data, .@"2d_first_major", &.{ 2, 1 });
    var output = descriptor(f32, &out_data, .@"2d_first_major", &.{ 2, 3 });

    try gatherND(&input, &indices, &output, null);
    try testing.expectEqualSlices(f32, &.{ 7, 8, 9, 1, 2, 3 }, &out_data);
}

test "gatherND rejects an output whose shape does not follow from the indices" {
    var in_data = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9 };
    var idx_data = [_]i32{ 0, 0, 1, 2, 2, 1 };
    var out_data: [3]f32 = @splat(-1);

    const input = descriptor(f32, &in_data, .@"2d_first_major", &.{ 3, 3 });
    // Two lookup vectors of length 3, so each names an element of a rank-3
    // input; against this rank-2 input that is status -1003.
    const indices = descriptor(i32, &idx_data, .@"2d_first_major", &.{ 2, 3 });
    var output = descriptor(f32, &out_data, .@"1d_first_major", &.{3});

    try testing.expectError(Error.BnnsFailed, gatherND(&input, &indices, &output, null));
}

test "scatterND puts rows back where gatherND took them from" {
    // The output of the gatherND-rows test, scattered back with the same
    // indices, rebuilds the rows it came from and leaves the rest zero.
    var in_data = [_]f32{ 7, 8, 9, 1, 2, 3 };
    var idx_data = [_]i32{ 2, 0 };
    var out_data: [9]f32 = @splat(0);

    const input = descriptor(f32, &in_data, .@"2d_first_major", &.{ 2, 3 });
    const indices = descriptor(i32, &idx_data, .@"2d_first_major", &.{ 2, 1 });
    var output = descriptor(f32, &out_data, .@"2d_first_major", &.{ 3, 3 });

    try scatterND(.none, &input, &indices, &output, null);
    try testing.expectEqualSlices(f32, &.{ 1, 2, 3, 0, 0, 0, 7, 8, 9 }, &out_data);
}

test "bandPart keeps a diagonal band and zeroes the rest" {
    //  1  2  3  4      1  2  0  0
    //  5  6  7  8  ->  5  6  7  0
    //  9 10 11 12      0 10 11 12
    // 13 14 15 16      0  0 15 16
    var in_data = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    var out_data: [16]f32 = @splat(-1);

    const input = descriptor(f32, &in_data, .@"2d_first_major", &.{ 4, 4 });
    var output = descriptor(f32, &out_data, .@"2d_first_major", &.{ 4, 4 });

    try bandPart(1, 1, &input, &output, null);
    try testing.expectEqualSlices(f32, &.{
        1, 2,  0,  0,
        5, 6,  7,  0,
        0, 10, 11, 12,
        0, 0,  15, 16,
    }, &out_data);
}

test "bandPart with a negative count keeps a whole triangle" {
    var in_data = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    var out_data: [16]f32 = @splat(-1);

    const input = descriptor(f32, &in_data, .@"2d_first_major", &.{ 4, 4 });
    var output = descriptor(f32, &out_data, .@"2d_first_major", &.{ 4, 4 });

    // Every subdiagonal, no superdiagonal: lower triangle.
    try bandPart(-1, 0, &input, &output, null);
    try testing.expectEqualSlices(f32, &.{
        1,  0,  0,  0,
        5,  6,  0,  0,
        9,  10, 11, 0,
        13, 14, 15, 16,
    }, &out_data);

    // The mirror image: upper triangle.
    try bandPart(0, -1, &input, &output, null);
    try testing.expectEqualSlices(f32, &.{
        1, 2, 3,  4,
        0, 6, 7,  8,
        0, 0, 11, 12,
        0, 0, 0,  16,
    }, &out_data);

    // Diagonal only.
    try bandPart(0, 0, &input, &output, null);
    try testing.expectEqualSlices(f32, &.{
        1, 0, 0,  0,
        0, 6, 0,  0,
        0, 0, 11, 0,
        0, 0, 0,  16,
    }, &out_data);
}

test "bandPart works on a non-square matrix" {
    // [ 1 2 3 ]  diagonal only  ->  [ 1 0 0 ]
    // [ 4 5 6 ]                     [ 0 5 0 ]
    var in_data = [_]f32{ 1, 2, 3, 4, 5, 6 };
    var out_data: [6]f32 = @splat(-1);

    const input = descriptor(f32, &in_data, .@"2d_first_major", &.{ 2, 3 });
    var output = descriptor(f32, &out_data, .@"2d_first_major", &.{ 2, 3 });

    try bandPart(0, 0, &input, &output, null);
    try testing.expectEqualSlices(f32, &.{ 1, 0, 0, 0, 5, 0 }, &out_data);
}

test "bandPart silently corrupts its output for a .row_major_matrix descriptor" {
    // The same 4x4 as the first bandPart test, described with the layout
    // `tensor.transpose` and friends expect. BNNSBandPart returns success and
    // then writes only the first seven elements, masked against the wrong
    // diagonal. Measured on macOS 15.7.7 / arm64. Recorded so the trap is not
    // rediscovered the hard way; `.@"2d_first_major"` is the fix.
    var in_data = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    var out_data: [16]f32 = @splat(-1);

    const input = descriptor(f32, &in_data, .row_major_matrix, &.{ 4, 4 });
    var output = descriptor(f32, &out_data, .row_major_matrix, &.{ 4, 4 });

    try bandPart(1, 1, &input, &output, null);

    const correct = [_]f32{
        1, 2,  0,  0,
        5, 6,  7,  0,
        0, 10, 11, 12,
        0, 0,  15, 16,
    };
    try testing.expect(!std.mem.eql(f32, &correct, &out_data));
    // The tail of the buffer is never touched: still the -1 sentinel.
    try testing.expectEqual(@as(f32, -1), out_data[15]);
}

test "shuffle spreads four channels into 2x2 spatial blocks" {
    // NCHW (1, 4, 2, 2) -> (1, 1, 4, 4), so r = 2. The four input planes are
    //   p0 = [ 1  2 ]  p1 = [ 5  6 ]  p2 = [  9 10 ]  p3 = [ 13 14 ]
    //        [ 3  4 ]       [ 7  8 ]       [ 11 12 ]       [ 15 16 ]
    // and pixel shuffle interleaves them, taking channel i*2+j to the (i, j)
    // corner of each output block:
    //   [  1  5  2  6 ]
    //   [  9 13 10 14 ]
    //   [  3  7  4  8 ]
    //   [ 11 15 12 16 ]
    var in_data = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    var out_data: [16]f32 = @splat(-1);

    const input = descriptor(f32, &in_data, .@"4d_first_major", &.{ 1, 4, 2, 2 });
    var output = descriptor(f32, &out_data, .@"4d_first_major", &.{ 1, 1, 4, 4 });

    try shuffle(.pixel_shuffle_nchw, &input, &output, null);
    try testing.expectEqualSlices(f32, &.{
        1,  5,  2,  6,
        9,  13, 10, 14,
        3,  7,  4,  8,
        11, 15, 12, 16,
    }, &out_data);
}

test "pixel_unshuffle_nchw inverts pixel_shuffle_nchw" {
    var in_data = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    var mid_data: [16]f32 = @splat(-1);
    var back_data: [16]f32 = @splat(-1);

    const input = descriptor(f32, &in_data, .@"4d_first_major", &.{ 1, 4, 2, 2 });
    var mid = descriptor(f32, &mid_data, .@"4d_first_major", &.{ 1, 1, 4, 4 });
    try shuffle(.pixel_shuffle_nchw, &input, &mid, null);

    const mid_in = mid;
    var back = descriptor(f32, &back_data, .@"4d_first_major", &.{ 1, 4, 2, 2 });
    try shuffle(.pixel_unshuffle_nchw, &mid_in, &back, null);

    try testing.expectEqualSlices(f32, &in_data, &back_data);
}

test "shuffle rejects a layout that is not 4d_first_major" {
    var in_data = [_]f32{ 1, 2, 3, 4 };
    var out_data: [4]f32 = @splat(-1);

    // The same NCHW extents under `.@"4d_last_major"`, which BNNS refuses
    // (status -1) rather than reinterpreting.
    const input = descriptor(f32, &in_data, .@"4d_last_major", &.{ 1, 4, 1, 1 });
    var output = descriptor(f32, &out_data, .@"4d_last_major", &.{ 1, 1, 2, 2 });

    try testing.expectError(Error.BnnsFailed, shuffle(.pixel_shuffle_nchw, &input, &output, null));
}

test "cropResize returns -1 for every configuration tried on macOS 15" {
    // Recorded rather than skipped: BNNSCropResize could not be made to run at
    // all on macOS 15.7.7 / arm64. Beyond the case below, the same -1 came back
    // for inputs of rank 2, 3, 4 and 5; `roi` of rank 1, 2, 4 and 5, with four
    // values per box and with five; normalized and absolute coordinates; every
    // BoxCoordinateMode; every LinearSamplingMode; both InterpolationMethods;
    // one box and two; a spatial_scale of 0 and of 1; and a two-image batch
    // with the box naming the second image. The framework's own explanation
    // goes to os_log as private data.
    //
    // The wrapper stays: the signature matches the header, and an older
    // deployment target may accept what this OS does not.
    var in_data = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    // [h_start, w_start, h_end, w_end, batch_index] — the whole image.
    var roi_data = [_]f32{ 0, 0, 3, 3, 0 };
    var out_data: [16]f32 = @splat(-1);

    const params = LayerParametersCropResize{
        .normalized_coordinates = false,
        .spatial_scale = 1.0,
        .extrapolation_value = 0,
        .sampling_mode = .strict_align_corners,
        .box_coordinate_mode = .corners_height_first,
        .method = .linear,
    };

    // NCHW (1, 1, 4, 4), one box, output the same size: with
    // `.strict_align_corners` this would be the identity if it ran.
    const input = descriptor(f32, &in_data, .@"4d_first_major", &.{ 1, 1, 4, 4 });
    const roi = descriptor(f32, &roi_data, .@"2d_first_major", &.{ 1, 5 });
    var output = descriptor(f32, &out_data, .@"4d_first_major", &.{ 1, 1, 4, 4 });

    try testing.expectError(Error.BnnsFailed, cropResize(&params, &input, &roi, &output, null));
    // Nothing was written before the failure.
    try testing.expectEqual(@as(f32, -1), out_data[0]);
}

test "cropResizeBackward shares cropResize's fate" {
    var in_delta_data: [16]f32 = @splat(-1);
    var out_delta_data = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    var roi_data = [_]f32{ 0, 0, 3, 3, 0 };

    const params = LayerParametersCropResize{
        .normalized_coordinates = false,
        .spatial_scale = 1.0,
        .extrapolation_value = 0,
        .sampling_mode = .strict_align_corners,
        .box_coordinate_mode = .corners_height_first,
        .method = .linear,
    };

    var in_delta = descriptor(f32, &in_delta_data, .@"4d_first_major", &.{ 1, 1, 4, 4 });
    const roi = descriptor(f32, &roi_data, .@"2d_first_major", &.{ 1, 5 });
    const out_delta = descriptor(f32, &out_delta_data, .@"4d_first_major", &.{ 1, 1, 4, 4 });

    try testing.expectError(
        Error.BnnsFailed,
        cropResizeBackward(&params, &in_delta, &roi, &out_delta, null),
    );
    try testing.expectEqual(@as(f32, -1), in_delta_data[0]);
}
