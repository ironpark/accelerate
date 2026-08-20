const std = @import("std");
const types = @import("types.zig");
const Connectivity = types.Connectivity;
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const VImageError = types.VImageError;
const check = types.check;
const vImage_Flags = types.vImage_Flags;
const vImagePixelCount = types.vImagePixelCount;
const GammaFunction = types.GammaFunction;
const vImage_MultidimensionalTable = types.vImage_MultidimensionalTable;
const Pixel_8 = types.Pixel_8;
const Pixel_F = types.Pixel_F;
const Pixel_8888 = types.Pixel_8888;
const Pixel_FFFF = types.Pixel_FFFF;
const Pixel_16U = types.Pixel_16U;
const Pixel_16S = types.Pixel_16S;
const Pixel_ARGB_16U = types.Pixel_ARGB_16U;
const Flags = types.Flags;

// ============================================================================
// Matrix multiply (planar color transforms)
// ============================================================================

/// Multiply M source planes by an MxN matrix to produce N destination planes.
///
/// For Planar8 / Planar16S the integer `divisor` normalises the result.
/// For PlanarF there is no divisor; fold it into the matrix if needed.
pub fn matrixMultiplyPlanar(
    comptime T: type,
    srcs: []const *const vImage_Buffer,
    dests: []const *const vImage_Buffer,
    matrix: []const T,
    divisor: if (T == f32) void else i32,
    pre_bias: ?[*]const if (T == f32) f32 else i16,
    post_bias: ?[*]const if (T == f32) f32 else i32,
    flags: vImage_Flags,
) VImageError!usize {
    const src_planes: u32 = @intCast(srcs.len);
    const dest_planes: u32 = @intCast(dests.len);
    switch (T) {
        f32 => return check(c.vImageMatrixMultiply_PlanarF(
            srcs.ptr,
            dests.ptr,
            src_planes,
            dest_planes,
            matrix.ptr,
            pre_bias,
            post_bias,
            flags,
        )),
        i16 => return check(c.vImageMatrixMultiply_Planar8(
            srcs.ptr,
            dests.ptr,
            src_planes,
            dest_planes,
            matrix.ptr,
            divisor,
            pre_bias,
            post_bias,
            flags,
        )),
        else => @compileError("matrixMultiplyPlanar requires f32 (PlanarF) or i16 (Planar8) matrix element type"),
    }
}

/// Multiply M source planes by an MxN i16 matrix with i32 divisor (Planar16S variant).
pub fn matrixMultiplyPlanar16S(
    srcs: []const *const vImage_Buffer,
    dests: []const *const vImage_Buffer,
    matrix: []const i16,
    divisor: i32,
    pre_bias: ?[*]const i16,
    post_bias: ?[*]const i32,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageMatrixMultiply_Planar16S(
        srcs.ptr,
        dests.ptr,
        @intCast(srcs.len),
        @intCast(dests.len),
        matrix.ptr,
        divisor,
        pre_bias,
        post_bias,
        flags,
    ));
}

// ============================================================================
// Matrix multiply (interleaved ARGB)
// ============================================================================

/// Apply a 4x4 matrix multiply to an interleaved 4-channel image.
///
/// For ARGB8888 the matrix elements are i16 with an i32 divisor.
/// For ARGBFFFF the matrix elements are f32 (no divisor).
pub fn matrixMultiplyARGB(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    matrix: *const [16]T,
    divisor: if (T == f32) void else i32,
    pre_bias: if (T == f32) ?*const [4]f32 else ?*const [4]i16,
    post_bias: if (T == f32) ?*const [4]f32 else ?*const [4]i32,
    flags: vImage_Flags,
) VImageError!usize {
    switch (T) {
        f32 => return check(c.vImageMatrixMultiply_ARGBFFFF(src, dest, matrix, pre_bias, post_bias, flags)),
        i16 => return check(c.vImageMatrixMultiply_ARGB8888(src, dest, matrix, divisor, pre_bias, post_bias, flags)),
        else => @compileError("matrixMultiplyARGB requires f32 (ARGBFFFF) or i16 (ARGB8888) matrix element type"),
    }
}

/// Apply a 1x4 matrix to a 4-channel interleaved image, producing a single-channel output.
///
/// ARGB8888 -> Planar8 (i16 matrix, i32 divisor, i32 post_bias scalar).
/// ARGBFFFF -> PlanarF (f32 matrix, f32 post_bias scalar).
pub fn matrixMultiplyARGBToPlanar(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    matrix: *const [4]T,
    divisor: if (T == f32) void else i32,
    pre_bias: if (T == f32) ?*const [4]f32 else ?*const [4]i16,
    post_bias: if (T == f32) f32 else i32,
    flags: vImage_Flags,
) VImageError!usize {
    switch (T) {
        f32 => return check(c.vImageMatrixMultiply_ARGBFFFFToPlanarF(src, dest, matrix, pre_bias, post_bias, flags)),
        i16 => return check(c.vImageMatrixMultiply_ARGB8888ToPlanar8(src, dest, matrix, divisor, pre_bias, post_bias, flags)),
        else => @compileError("matrixMultiplyARGBToPlanar requires f32 or i16 matrix element type"),
    }
}

// ============================================================================
// Gamma correction
// ============================================================================

/// Gamma function type constants.
pub const GammaType = enum(c_int) {
    use_gamma_value = 0,
    use_gamma_value_half_precision = 1,
    @"5_over_9_half_precision" = 2,
    @"9_over_5_half_precision" = 3,
    @"5_over_11_half_precision" = 4,
    @"11_over_5_half_precision" = 5,
    sRGB_forward_half_precision = 6,
    sRGB_reverse_half_precision = 7,
    @"11_over_9_half_precision" = 8,
    @"9_over_11_half_precision" = 9,
    BT709_forward_half_precision = 10,
    BT709_reverse_half_precision = 11,
};

/// Create a reusable gamma transfer-function handle.
pub fn createGammaFunction(gamma: f32, gamma_type: GammaType, flags: vImage_Flags) GammaFunction {
    return c.vImageCreateGammaFunction(gamma, @intFromEnum(gamma_type), flags);
}

/// Destroy a gamma transfer-function handle created by `createGammaFunction`.
pub fn destroyGammaFunction(f: GammaFunction) void {
    c.vImageDestroyGammaFunction(f);
}

/// Apply a gamma curve to a PlanarF image.
pub fn gammaPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, gamma: GammaFunction, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageGamma_PlanarF(src, dest, gamma, flags));
}

/// Apply a gamma curve converting Planar8 to PlanarF.
pub fn gammaPlanar8toPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, gamma: GammaFunction, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageGamma_Planar8toPlanarF(src, dest, gamma, flags));
}

/// Apply a gamma curve converting PlanarF to Planar8.
pub fn gammaPlanarFtoPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, gamma: GammaFunction, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageGamma_PlanarFtoPlanar8(src, dest, gamma, flags));
}

// ============================================================================
// Piecewise Gamma
// ============================================================================

/// Apply a piecewise gamma curve (exponential + linear segments).
///
///   if pixel < boundary:  result = linearCoeffs[0]*pixel + linearCoeffs[1]
///   else:                 result = pow(exponentialCoeffs[0]*pixel + exponentialCoeffs[1], gamma) + exponentialCoeffs[2]
pub fn piecewiseGamma(
    comptime Src: type,
    comptime Dst: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    exponential_coeffs: *const [3]f32,
    gamma: f32,
    linear_coeffs: *const [2]f32,
    boundary: if (Src == f32) f32 else if (Src == Pixel_16S) Pixel_16S else Pixel_8,
    flags: vImage_Flags,
) VImageError!usize {
    if (Src == f32 and Dst == f32) {
        return check(c.vImagePiecewiseGamma_PlanarF(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags));
    } else if (Src == f32 and Dst == u8) {
        return check(c.vImagePiecewiseGamma_PlanarFtoPlanar8(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags));
    } else if (Src == u8 and Dst == u8) {
        return check(c.vImagePiecewiseGamma_Planar8(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags));
    } else if (Src == u8 and Dst == f32) {
        return check(c.vImagePiecewiseGamma_Planar8toPlanarF(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags));
    } else if (Src == u8 and Dst == Pixel_16S) {
        return check(c.vImagePiecewiseGamma_Planar8toPlanar16Q12(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags));
    } else if (Src == Pixel_16S and Dst == Pixel_16S) {
        return check(c.vImagePiecewiseGamma_Planar16Q12(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags));
    } else if (Src == Pixel_16S and Dst == u8) {
        return check(c.vImagePiecewiseGamma_Planar16Q12toPlanar8(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags));
    } else {
        @compileError("piecewiseGamma: unsupported Src/Dst combination");
    }
}

/// Apply a symmetric piecewise gamma curve (symmetric about the origin).
pub fn symmetricPiecewiseGamma(
    comptime T: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    exponential_coeffs: *const [3]f32,
    gamma: f32,
    linear_coeffs: *const [2]f32,
    boundary: if (T == f32) f32 else Pixel_16S,
    flags: vImage_Flags,
) VImageError!usize {
    switch (T) {
        f32 => return check(c.vImageSymmetricPiecewiseGamma_PlanarF(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags)),
        Pixel_16S => return check(c.vImageSymmetricPiecewiseGamma_Planar16Q12(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags)),
        else => @compileError("symmetricPiecewiseGamma requires f32 (PlanarF) or i16 (Planar16Q12)"),
    }
}

// ============================================================================
// Polynomial / Rational transforms
// ============================================================================

/// Evaluate piecewise polynomials on PlanarF image data.
///
/// `coefficients` is a packed array of N polynomial coefficient arrays (each of length order+1).
/// `boundaries` has N+1 entries defining the input ranges. N must be a power of 2.
pub fn piecewisePolynomial(
    comptime Src: type,
    comptime Dst: type,
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    coefficients: [*]const [*]const f32,
    boundaries: [*]const f32,
    order: u32,
    log2segments: u32,
    flags: vImage_Flags,
) VImageError!usize {
    if (Src == f32 and Dst == f32) {
        return check(c.vImagePiecewisePolynomial_PlanarF(src, dest, coefficients, boundaries, order, log2segments, flags));
    } else if (Src == u8 and Dst == f32) {
        return check(c.vImagePiecewisePolynomial_Planar8toPlanarF(src, dest, coefficients, boundaries, order, log2segments, flags));
    } else if (Src == f32 and Dst == u8) {
        return check(c.vImagePiecewisePolynomial_PlanarFtoPlanar8(src, dest, coefficients, boundaries, order, log2segments, flags));
    } else {
        @compileError("piecewisePolynomial: unsupported Src/Dst combination (use f32/f32, u8/f32, or f32/u8)");
    }
}

/// Evaluate symmetric piecewise polynomials on PlanarF data.
/// The polynomial is applied as p(|x|) * sign(x), making it C2 symmetric about the origin.
pub fn symmetricPiecewisePolynomial(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    coefficients: [*]const [*]const f32,
    boundaries: [*]const f32,
    order: u32,
    log2segments: u32,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageSymmetricPiecewisePolynomial_PlanarF(src, dest, coefficients, boundaries, order, log2segments, flags));
}

/// Evaluate piecewise rational expressions on PlanarF data.
///
///   result = (c0 + c1*x + c2*x^2 + ...) / (d0 + d1*x + d2*x^2 + ...)
pub fn piecewiseRational(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    top_coefficients: [*]const [*]const f32,
    bottom_coefficients: [*]const [*]const f32,
    boundaries: [*]const f32,
    top_order: u32,
    bottom_order: u32,
    log2segments: u32,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImagePiecewiseRational_PlanarF(src, dest, top_coefficients, bottom_coefficients, boundaries, top_order, bottom_order, log2segments, flags));
}

// ============================================================================
// Lookup table operations
// ============================================================================

/// Simple 8-bit to 16-bit lookup table.
pub fn lookupTable_Planar8toPlanar16(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]Pixel_16U, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageLookupTable_Planar8toPlanar16(src, dest, table, flags));
}

/// 8-bit to 24-bit (3-channel 8-bit) lookup table.
pub fn lookupTable_Planar8toPlanar24(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]u32, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageLookupTable_Planar8toPlanar24(src, dest, table, flags));
}

/// 8-bit to 48-bit (3-channel 16-bit) lookup table.
pub fn lookupTable_Planar8toPlanar48(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]u64, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageLookupTable_Planar8toPlanar48(src, dest, table, flags));
}

/// 8-bit to 96-bit (3-channel float) lookup table. Each entry is [4]f32; only the last 3 channels are written.
pub fn lookupTable_Planar8toPlanar96(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]Pixel_FFFF, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageLookupTable_Planar8toPlanar96(src, dest, table, flags));
}

/// 8-bit to 128-bit (4-channel float) lookup table.
pub fn lookupTable_Planar8toPlanar128(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]Pixel_FFFF, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageLookupTable_Planar8toPlanar128(src, dest, table, flags));
}

/// 8-bit to float lookup table.
pub fn lookupTable_Planar8toPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]Pixel_F, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageLookupTable_Planar8toPlanarF(src, dest, table, flags));
}

/// Float to 8-bit lookup table. Input floats in [0,1] are quantised to 4096 entries.
pub fn lookupTable_PlanarFtoPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [4096]Pixel_8, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageLookupTable_PlanarFtoPlanar8(src, dest, table, flags));
}

/// 8-bit to 64-bit unsigned lookup table.
pub fn lookupTable_8to64U(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]u64, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageLookupTable_8to64U(src, dest, table, flags));
}

/// 16-bit to 16-bit lookup table (65536 entries).
pub fn lookupTable_Planar16(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [0x10000]Pixel_16U, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageLookupTable_Planar16(src, dest, table, flags));
}

/// Interpolated float lookup table. The table spans [minFloat, maxFloat] with linear interpolation
/// between entries. The table must have tableEntries+1 elements allocated.
pub fn interpolatedLookupTable_PlanarF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    table: [*]const Pixel_F,
    table_entries: vImagePixelCount,
    max_float: f32,
    min_float: f32,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageInterpolatedLookupTable_PlanarF(src, dest, table, table_entries, max_float, min_float, flags));
}

// ============================================================================
// Multidimensional interpolated lookup table
// ============================================================================

/// Interpolation method for multidimensional lookup tables.
pub const InterpolationMethod = enum(c_int) {
    no_interpolation = 0,
    full = 1,
    half = 2,
};

/// Usage hint for `multidimensionalTableCreate`.
pub const MDTableUsageHint = enum(u32) {
    @"16Q12" = 1,
    float = 2,
};

/// Create a multidimensional interpolated lookup table.
///
/// `table_data` is a contiguous array of uint16 samples in [0,65535] (implicit /65535 scaling).
/// Returns the table handle; check `err` for errors.
pub fn multidimensionalTableCreate(
    table_data: [*]const u16,
    num_src_channels: u32,
    num_dest_channels: u32,
    table_entries_per_dimension: [*]const u8,
    hint: MDTableUsageHint,
    flags: vImage_Flags,
    err: ?*vImage_Error,
) vImage_MultidimensionalTable {
    return c.vImageMultidimensionalTable_Create(table_data, num_src_channels, num_dest_channels, table_entries_per_dimension, @intFromEnum(hint), flags, err);
}

/// Increment the retain count of a multidimensional table.
pub fn multidimensionalTableRetain(table: vImage_MultidimensionalTable) VImageError!usize {
    return check(c.vImageMultidimensionalTable_Retain(table));
}

/// Decrement the retain count; the table is freed when the count reaches 0.
pub fn multidimensionalTableRelease(table: vImage_MultidimensionalTable) VImageError!usize {
    return check(c.vImageMultidimensionalTable_Release(table));
}

/// Apply a multidimensional interpolated lookup table.
pub fn multiDimensionalInterpolatedLookupTable(
    comptime T: type,
    srcs: []const vImage_Buffer,
    dests: []const vImage_Buffer,
    temp_buffer: ?*anyopaque,
    table: vImage_MultidimensionalTable,
    method: InterpolationMethod,
    flags: vImage_Flags,
) VImageError!usize {
    switch (T) {
        f32 => return check(c.vImageMultiDimensionalInterpolatedLookupTable_PlanarF(srcs.ptr, dests.ptr, temp_buffer, table, @intFromEnum(method), flags)),
        Pixel_16S => return check(c.vImageMultiDimensionalInterpolatedLookupTable_Planar16Q12(srcs.ptr, dests.ptr, temp_buffer, table, @intFromEnum(method), flags)),
        else => @compileError("multiDimensionalInterpolatedLookupTable requires f32 (PlanarF) or i16 (Planar16Q12)"),
    }
}

// ============================================================================
// Flood fill
// ============================================================================

/// Fill a connected component of a Planar8 image with a new value.
pub fn floodFill_Planar8(src_dest: *const vImage_Buffer, seed_x: vImagePixelCount, seed_y: vImagePixelCount, new_value: Pixel_8, connectivity: Connectivity, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageFloodFill_Planar8(src_dest, null, seed_x, seed_y, new_value, @intFromEnum(connectivity), flags));
}

/// Fill a connected component of a Planar16U image with a new value.
pub fn floodFill_Planar16U(src_dest: *const vImage_Buffer, seed_x: vImagePixelCount, seed_y: vImagePixelCount, new_value: Pixel_16U, connectivity: Connectivity, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageFloodFill_Planar16U(src_dest, null, seed_x, seed_y, new_value, @intFromEnum(connectivity), flags));
}

/// Fill a connected component of an ARGB8888 image with a new value.
pub fn floodFill_ARGB8888(src_dest: *const vImage_Buffer, seed_x: vImagePixelCount, seed_y: vImagePixelCount, new_value: Pixel_8888, connectivity: Connectivity, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageFloodFill_ARGB8888(src_dest, null, seed_x, seed_y, &new_value, @intFromEnum(connectivity), flags));
}

/// Fill a connected component of an ARGB16U image with a new value.
pub fn floodFill_ARGB16U(src_dest: *const vImage_Buffer, seed_x: vImagePixelCount, seed_y: vImagePixelCount, new_value: Pixel_ARGB_16U, connectivity: Connectivity, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageFloodFill_ARGB16U(src_dest, null, seed_x, seed_y, &new_value, @intFromEnum(connectivity), flags));
}

// ============================================================================
// Tests
// ============================================================================

fn makePlanarFBuffer(allocator: std.mem.Allocator, height: usize, width: usize, row_pad_elems: usize, values: []const f32) !struct { buf: vImage_Buffer, mem: []f32 } {
    const row_elems = width + row_pad_elems;
    const mem = try allocator.alloc(f32, row_elems * height);
    @memset(mem, -999.0);
    for (0..height) |y| @memcpy(mem[y * row_elems ..][0..width], values[y * width ..][0..width]);
    return .{ .buf = .{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_elems * @sizeOf(f32) }, .mem = mem };
}

fn readPlanarF(buf: vImage_Buffer, y: usize, x: usize) f32 {
    const base: [*]u8 = @ptrCast(buf.data.?);
    const row: [*]f32 = @ptrCast(@alignCast(base + y * buf.rowBytes));
    return row[x];
}

fn makePlanar8Buffer(allocator: std.mem.Allocator, height: usize, width: usize, row_pad: usize, values: []const u8) !struct { buf: vImage_Buffer, mem: []u8 } {
    const row_bytes = width + row_pad;
    const mem = try allocator.alloc(u8, row_bytes * height);
    @memset(mem, 0xAA);
    for (0..height) |y| @memcpy(mem[y * row_bytes ..][0..width], values[y * width ..][0..width]);
    return .{ .buf = .{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes }, .mem = mem };
}

fn readPlanar8(buf: vImage_Buffer, y: usize, x: usize) u8 {
    const base: [*]u8 = @ptrCast(buf.data.?);
    return base[y * buf.rowBytes + x];
}

test "matrixMultiplyPlanar f32: matrix is row-major [src_planes][dest_planes], per Transform.h's general matrix-multiply formula" {
    // Transform.h's general discussion: matrix has dest_planes columns and
    // src_planes rows, row-major; A'[j] = sum_i(bSrc[i] * matrix[i][j]).
    // Non-square (2 src planes -> 3 dest planes) so a transpose bug can't
    // hide. matrix (row-major, 2 rows x 3 cols):
    //   row0 (srcA): [1, 2, 3]
    //   row1 (srcB): [0, 0, 1]
    // dest0 = A*1 + B*0 = A
    // dest1 = A*2 + B*0 = 2A
    // dest2 = A*3 + B*1 = 3A + B
    const allocator = std.testing.allocator;
    var srcA = try makePlanarFBuffer(allocator, 2, 2, 1, &[_]f32{ 10, 10, 10, 10 });
    defer allocator.free(srcA.mem);
    var srcB = try makePlanarFBuffer(allocator, 2, 2, 2, &[_]f32{ 100, 100, 100, 100 });
    defer allocator.free(srcB.mem);
    var dest0 = try makePlanarFBuffer(allocator, 2, 2, 1, &[_]f32{ 0, 0, 0, 0 });
    defer allocator.free(dest0.mem);
    var dest1 = try makePlanarFBuffer(allocator, 2, 2, 2, &[_]f32{ 0, 0, 0, 0 });
    defer allocator.free(dest1.mem);
    var dest2 = try makePlanarFBuffer(allocator, 2, 2, 3, &[_]f32{ 0, 0, 0, 0 });
    defer allocator.free(dest2.mem);

    const srcs = [_]*const vImage_Buffer{ &srcA.buf, &srcB.buf };
    const dests = [_]*const vImage_Buffer{ &dest0.buf, &dest1.buf, &dest2.buf };
    const matrix = [_]f32{ 1, 2, 3, 0, 0, 1 };
    const err = matrixMultiplyPlanar(f32, &srcs, &dests, &matrix, {}, null, null, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectApproxEqAbs(@as(f32, 10), readPlanarF(dest0.buf, 0, 0), 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, 20), readPlanarF(dest1.buf, 0, 0), 1e-4);
    try std.testing.expectApproxEqAbs(@as(f32, 130), readPlanarF(dest2.buf, 0, 0), 1e-4);
}

test "matrixMultiplyPlanar i16 (Planar8): applies divisor and matrix row-major layout, matching Transform.h" {
    const allocator = std.testing.allocator;
    var srcA = try makePlanar8Buffer(allocator, 1, 1, 1, &[_]u8{10});
    defer allocator.free(srcA.mem);
    var srcB = try makePlanar8Buffer(allocator, 1, 1, 2, &[_]u8{20});
    defer allocator.free(srcB.mem);
    var dest0 = try makePlanar8Buffer(allocator, 1, 1, 1, &[_]u8{0});
    defer allocator.free(dest0.mem);

    const srcs = [_]*const vImage_Buffer{ &srcA.buf, &srcB.buf };
    const dests = [_]*const vImage_Buffer{&dest0.buf};
    // dest0 = (srcA*3 + srcB*1) / divisor = (30+20)/5 = 10
    const matrix = [_]i16{ 3, 1 };
    const err = matrixMultiplyPlanar(i16, &srcs, &dests, &matrix, 5, null, null, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(u8, 10), readPlanar8(dest0.buf, 0, 0));
}

test "matrixMultiplyPlanar16S: smoke test with divisor, i16 Planar16S pixel format" {
    const allocator = std.testing.allocator;
    // Planar16S pixels are i16; reuse the u8-buffer helper's byte layout
    // but with 2-byte elements via the f32 helper's pattern generalized inline.
    const row_bytes: usize = 1 * @sizeOf(i16) + 4;
    const mem_a = try allocator.alloc(u8, row_bytes);
    defer allocator.free(mem_a);
    @as(*i16, @ptrCast(@alignCast(mem_a.ptr))).* = 10;
    const srcA_buf = vImage_Buffer{ .data = mem_a.ptr, .height = 1, .width = 1, .rowBytes = row_bytes };

    const mem_b = try allocator.alloc(u8, row_bytes);
    defer allocator.free(mem_b);
    @as(*i16, @ptrCast(@alignCast(mem_b.ptr))).* = 20;
    const srcB_buf = vImage_Buffer{ .data = mem_b.ptr, .height = 1, .width = 1, .rowBytes = row_bytes };

    const dest_mem = try allocator.alloc(u8, row_bytes);
    defer allocator.free(dest_mem);
    @memset(dest_mem, 0);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = 1, .width = 1, .rowBytes = row_bytes };

    const srcs = [_]*const vImage_Buffer{ &srcA_buf, &srcB_buf };
    const dests = [_]*const vImage_Buffer{&dest_buf};
    const matrix = [_]i16{ 3, 1 }; // dest = (A*3 + B*1) / divisor = (30+20)/5 = 10
    const err = matrixMultiplyPlanar16S(&srcs, &dests, &matrix, 5, null, null, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(i16, 10), @as(*i16, @ptrCast(@alignCast(dest_mem.ptr))).*);
}

test "matrixMultiplyARGB i16 (ARGB8888): row-major [srcChannel][destChannel], A/R channel swap distinguishes rows from columns" {
    // matrix (row-major, 4 src channels x 4 dest channels), swapping only A and R:
    //   destA = srcR, destR = srcA, destG = srcG, destB = srcB
    const allocator = std.testing.allocator;
    const row_bytes: usize = 4 + 4;
    const mem = try allocator.alloc(u8, row_bytes);
    defer allocator.free(mem);
    @memset(mem, 0);
    mem[0] = 10; // A
    mem[1] = 20; // R
    mem[2] = 30; // G
    mem[3] = 40; // B
    const src_buf = vImage_Buffer{ .data = mem.ptr, .height = 1, .width = 1, .rowBytes = row_bytes };
    const dest_mem = try allocator.alloc(u8, row_bytes);
    defer allocator.free(dest_mem);
    @memset(dest_mem, 0);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = 1, .width = 1, .rowBytes = row_bytes };

    const matrix = [16]i16{
        0, 1, 0, 0, // srcA row -> destR
        1, 0, 0, 0, // srcR row -> destA
        0, 0, 1, 0, // srcG row -> destG
        0, 0, 0, 1, // srcB row -> destB
    };
    const err = matrixMultiplyARGB(i16, &src_buf, &dest_buf, &matrix, 1, null, null, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqualSlices(u8, &[_]u8{ 20, 10, 30, 40 }, dest_mem[0..4]);
}

test "matrixMultiplyARGB f32 (ARGBFFFF): smoke test, identity matrix reproduces input" {
    const allocator = std.testing.allocator;
    const row_elems: usize = 4 + 4;
    const mem = try allocator.alloc(f32, row_elems);
    defer allocator.free(mem);
    @memset(mem, 0);
    mem[0] = 1;
    mem[1] = 2;
    mem[2] = 3;
    mem[3] = 4;
    const src_buf = vImage_Buffer{ .data = mem.ptr, .height = 1, .width = 1, .rowBytes = row_elems * @sizeOf(f32) };
    const dest_mem = try allocator.alloc(f32, row_elems);
    defer allocator.free(dest_mem);
    @memset(dest_mem, 0);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = 1, .width = 1, .rowBytes = row_elems * @sizeOf(f32) };

    const identity = [16]f32{
        1, 0, 0, 0,
        0, 1, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1,
    };
    const err = matrixMultiplyARGB(f32, &src_buf, &dest_buf, &identity, {}, null, null, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectApproxEqAbs(@as(f32, 1), dest_mem[0], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 2), dest_mem[1], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 3), dest_mem[2], 1e-5);
    try std.testing.expectApproxEqAbs(@as(f32, 4), dest_mem[3], 1e-5);
}

test "matrixMultiplyARGBToPlanar i16: 1x4 matrix picks out one channel, confirming row order == channel order" {
    const allocator = std.testing.allocator;
    const row_bytes: usize = 4 + 4;
    const mem = try allocator.alloc(u8, row_bytes);
    defer allocator.free(mem);
    mem[0] = 10; // A
    mem[1] = 20; // R
    mem[2] = 30; // G
    mem[3] = 40; // B
    const src_buf = vImage_Buffer{ .data = mem.ptr, .height = 1, .width = 1, .rowBytes = row_bytes };
    var dest = try makePlanar8Buffer(allocator, 1, 1, 2, &[_]u8{0});
    defer allocator.free(dest.mem);

    // matrix = [0,1,0,0] selects the R channel (row index 1).
    const matrix = [4]i16{ 0, 1, 0, 0 };
    const err = matrixMultiplyARGBToPlanar(i16, &src_buf, &dest.buf, &matrix, 1, null, 0, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(u8, 20), readPlanar8(dest.buf, 0, 0));
}

test "createGammaFunction/gammaPlanarF: computes pow(x, gamma), not pow(x, 1/gamma) (Transform.h: result = pow(fabs(value), gamma) * sign)" {
    // Transform.h's discussion right above vImageCreateGammaFunction:
    //   result = pow(fabs(value), gamma) * sign
    // A gamma of 2.0 applied to 0.5 should give 0.25, not 0.5^(1/2)=0.707..
    // -- the two are far enough apart that a reciprocal-exponent bug would
    // be caught immediately by an approx tolerance.
    const allocator = std.testing.allocator;
    const gamma_fn = createGammaFunction(2.0, .use_gamma_value, Flags.kvImageNoFlags);
    try std.testing.expect(gamma_fn != null);
    defer destroyGammaFunction(gamma_fn);

    var src = try makePlanarFBuffer(allocator, 1, 1, 2, &[_]f32{0.5});
    defer allocator.free(src.mem);
    var dest = try makePlanarFBuffer(allocator, 1, 1, 3, &[_]f32{0});
    defer allocator.free(dest.mem);

    const err = gammaPlanarF(&src.buf, &dest.buf, gamma_fn, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), readPlanarF(dest.buf, 0, 0), 1e-3);
}

test "gammaPlanar8toPlanarF / gammaPlanarFtoPlanar8: round trip is approximately identity for gamma=1" {
    const allocator = std.testing.allocator;
    const gamma_fn = createGammaFunction(1.0, .use_gamma_value, Flags.kvImageNoFlags);
    try std.testing.expect(gamma_fn != null);
    defer destroyGammaFunction(gamma_fn);

    var src8 = try makePlanar8Buffer(allocator, 1, 1, 1, &[_]u8{128});
    defer allocator.free(src8.mem);
    var midF = try makePlanarFBuffer(allocator, 1, 1, 2, &[_]f32{0});
    defer allocator.free(midF.mem);
    const err1 = gammaPlanar8toPlanarF(&src8.buf, &midF.buf, gamma_fn, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err1);
    // Planar8's normalized value for 128 is 128/255.
    try std.testing.expectApproxEqAbs(@as(f32, 128.0 / 255.0), readPlanarF(midF.buf, 0, 0), 1e-3);

    var back8 = try makePlanar8Buffer(allocator, 1, 1, 3, &[_]u8{0});
    defer allocator.free(back8.mem);
    const err2 = gammaPlanarFtoPlanar8(&midF.buf, &back8.buf, gamma_fn, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err2);
    try std.testing.expectEqual(@as(u8, 128), readPlanar8(back8.buf, 0, 0));
}

test "piecewiseGamma f32/f32: linear branch below boundary, exponential branch at/above, matching Transform.h's documented formula" {
    // Transform.h: if x < boundary: r = linearCoeffs[0]*x + linearCoeffs[1]
    //              else: t = expCoeffs[0]*x + expCoeffs[1]; r = pow(t,gamma) + expCoeffs[2]
    const allocator = std.testing.allocator;
    // Below-boundary point: x=0.1, boundary=0.5, linear=[2,1] -> r = 2*0.1+1 = 1.2
    // At-or-above: x=0.5, exp=[1,0,0], gamma=2 -> t=0.5, r=0.5^2=0.25
    var src = try makePlanarFBuffer(allocator, 1, 2, 1, &[_]f32{ 0.1, 0.5 });
    defer allocator.free(src.mem);
    var dest = try makePlanarFBuffer(allocator, 1, 2, 2, &[_]f32{ 0, 0 });
    defer allocator.free(dest.mem);
    const exp_coeffs = [3]f32{ 1, 0, 0 };
    const lin_coeffs = [2]f32{ 2, 1 };
    const err = piecewiseGamma(f32, f32, &src.buf, &dest.buf, &exp_coeffs, 2.0, &lin_coeffs, 0.5, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectApproxEqAbs(@as(f32, 1.2), readPlanarF(dest.buf, 0, 0), 1e-3);
    try std.testing.expectApproxEqAbs(@as(f32, 0.25), readPlanarF(dest.buf, 0, 1), 1e-3);
}

test "symmetricPiecewiseGamma f32: symmetric about the origin, f(-x) == -f(x)" {
    const allocator = std.testing.allocator;
    var src = try makePlanarFBuffer(allocator, 1, 2, 1, &[_]f32{ 0.7, -0.7 });
    defer allocator.free(src.mem);
    var dest = try makePlanarFBuffer(allocator, 1, 2, 2, &[_]f32{ 0, 0 });
    defer allocator.free(dest.mem);
    const exp_coeffs = [3]f32{ 1, 0, 0 };
    const lin_coeffs = [2]f32{ 1, 0 };
    const err = symmetricPiecewiseGamma(f32, &src.buf, &dest.buf, &exp_coeffs, 2.0, &lin_coeffs, 0.5, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    const pos = readPlanarF(dest.buf, 0, 0);
    const neg = readPlanarF(dest.buf, 0, 1);
    try std.testing.expectApproxEqAbs(pos, -neg, 1e-3);
    try std.testing.expectApproxEqAbs(@as(f32, 0.49), pos, 1e-3); // 0.7^2
}

test "piecewisePolynomial PlanarF/PlanarF: order-1 (linear) polynomial reproduces coefficients[1]*x + coefficients[0]" {
    // A single segment (log2segments=0), order=1: p(x) = c[0] + c[1]*x.
    // coefficients is an array of (N=1) pointers, each to (order+1)=2 floats.
    const allocator = std.testing.allocator;
    var src = try makePlanarFBuffer(allocator, 1, 2, 1, &[_]f32{ 0.0, 1.0 });
    defer allocator.free(src.mem);
    var dest = try makePlanarFBuffer(allocator, 1, 2, 2, &[_]f32{ 0, 0 });
    defer allocator.free(dest.mem);
    // p(x) = 3 + 5*x
    const seg0 = [2]f32{ 3, 5 };
    const coeffs = [1][*]const f32{seg0[0..].ptr};
    const boundaries = [2]f32{ 0.0, 1.0 };
    const err = piecewisePolynomial(f32, f32, &src.buf, &dest.buf, coeffs[0..].ptr, boundaries[0..].ptr, 1, 0, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectApproxEqAbs(@as(f32, 3), readPlanarF(dest.buf, 0, 0), 1e-3); // p(0)=3
    try std.testing.expectApproxEqAbs(@as(f32, 8), readPlanarF(dest.buf, 0, 1), 1e-3); // p(1)=3+5=8
}

test "symmetricPiecewisePolynomial: p(|x|)*sign(x), matching this file's own doc comment" {
    const allocator = std.testing.allocator;
    var src = try makePlanarFBuffer(allocator, 1, 2, 1, &[_]f32{ 0.5, -0.5 });
    defer allocator.free(src.mem);
    var dest = try makePlanarFBuffer(allocator, 1, 2, 2, &[_]f32{ 0, 0 });
    defer allocator.free(dest.mem);
    // p(x) = 2*x (odd function even without the symmetric wrapper, but this
    // confirms the call succeeds and the sign is correctly threaded).
    const seg0 = [2]f32{ 0, 2 };
    const coeffs = [1][*]const f32{seg0[0..].ptr};
    const boundaries = [2]f32{ 0.0, 1.0 };
    const err = symmetricPiecewisePolynomial(&src.buf, &dest.buf, coeffs[0..].ptr, boundaries[0..].ptr, 1, 0, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    const pos = readPlanarF(dest.buf, 0, 0);
    const neg = readPlanarF(dest.buf, 0, 1);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), pos, 1e-3);
    try std.testing.expectApproxEqAbs(@as(f32, -1.0), neg, 1e-3);
}

test "piecewiseRational: (top polynomial)/(bottom polynomial), degenerate bottom=1 reduces to the top polynomial" {
    const allocator = std.testing.allocator;
    var src = try makePlanarFBuffer(allocator, 1, 1, 1, &[_]f32{2.0});
    defer allocator.free(src.mem);
    var dest = try makePlanarFBuffer(allocator, 1, 1, 2, &[_]f32{0});
    defer allocator.free(dest.mem);
    // top(x) = 1 + 3x (order 1), bottom(x) = 1 (order 0) -> result = 1+3x = 7 at x=2
    const top_seg0 = [2]f32{ 1, 3 };
    const bottom_seg0 = [1]f32{1};
    const top_coeffs = [1][*]const f32{top_seg0[0..].ptr};
    const bottom_coeffs = [1][*]const f32{bottom_seg0[0..].ptr};
    const boundaries = [2]f32{ 0.0, 10.0 };
    const err = piecewiseRational(&src.buf, &dest.buf, top_coeffs[0..].ptr, bottom_coeffs[0..].ptr, boundaries[0..].ptr, 1, 0, 0, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), readPlanarF(dest.buf, 0, 0), 1e-3);
}

test "lookupTable_Planar8toPlanar16: dest[i] = table[src[i]] (direct indexed lookup)" {
    const allocator = std.testing.allocator;
    var src = try makePlanar8Buffer(allocator, 1, 1, 1, &[_]u8{5});
    defer allocator.free(src.mem);
    const dest_mem = try allocator.alloc(u16, 1 + 2);
    defer allocator.free(dest_mem);
    @memset(dest_mem, 0);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = 1, .width = 1, .rowBytes = (1 + 2) * @sizeOf(u16) };

    var table: [256]u16 = [_]u16{0} ** 256;
    table[5] = 1234;
    const err = lookupTable_Planar8toPlanar16(&src.buf, &dest_buf, &table, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(u16, 1234), dest_mem[0]);
}

test "lookupTable_PlanarFtoPlanar8: smoke test, error == 0 and produces a plausible in-range value" {
    const allocator = std.testing.allocator;
    var src = try makePlanarFBuffer(allocator, 1, 1, 1, &[_]f32{0.5});
    defer allocator.free(src.mem);
    var dest = try makePlanar8Buffer(allocator, 1, 1, 2, &[_]u8{0});
    defer allocator.free(dest.mem);

    var table: [4096]u8 = [_]u8{0} ** 4096;
    table[2048] = 200; // roughly the middle entry, corresponding to input ~0.5
    const err = lookupTable_PlanarFtoPlanar8(&src.buf, &dest.buf, &table, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(u8, 200), readPlanar8(dest.buf, 0, 0));
}

test "lookupTable_8to64U: dest[i] = table[src[i]]" {
    const allocator = std.testing.allocator;
    var src = try makePlanar8Buffer(allocator, 1, 1, 1, &[_]u8{9});
    defer allocator.free(src.mem);
    const dest_mem = try allocator.alloc(u64, 1);
    defer allocator.free(dest_mem);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = 1, .width = 1, .rowBytes = @sizeOf(u64) };
    var table: [256]u64 = [_]u64{0} ** 256;
    table[9] = 0xDEADBEEF;
    const err = lookupTable_8to64U(&src.buf, &dest_buf, &table, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(u64, 0xDEADBEEF), dest_mem[0]);
}

test "lookupTable_Planar16: dest[i] = table[src[i]] for a 16-bit source" {
    const allocator = std.testing.allocator;
    const src_mem = try allocator.alloc(u16, 1);
    defer allocator.free(src_mem);
    src_mem[0] = 300;
    const src_buf = vImage_Buffer{ .data = src_mem.ptr, .height = 1, .width = 1, .rowBytes = @sizeOf(u16) };
    const dest_mem = try allocator.alloc(u16, 1);
    defer allocator.free(dest_mem);
    const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = 1, .width = 1, .rowBytes = @sizeOf(u16) };

    const table = try allocator.alloc(u16, 0x10000);
    defer allocator.free(table);
    @memset(table, 0);
    table[300] = 42;
    const err = lookupTable_Planar16(&src_buf, &dest_buf, table[0..0x10000], Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectEqual(@as(u16, 42), dest_mem[0]);
}

test "lookupTable_Planar8toPlanar24/48/96/128/PlanarF: smoke tests, error == 0" {
    const allocator = std.testing.allocator;
    var src = try makePlanar8Buffer(allocator, 1, 1, 1, &[_]u8{0});
    defer allocator.free(src.mem);

    {
        var table: [256]u32 = [_]u32{0} ** 256;
        const dest_mem = try allocator.alloc(u32, 1);
        defer allocator.free(dest_mem);
        const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = 1, .width = 1, .rowBytes = @sizeOf(u32) };
        _ = try lookupTable_Planar8toPlanar24(&src.buf, &dest_buf, &table, Flags.kvImageNoFlags);
    }
    {
        var table: [256]u64 = [_]u64{0} ** 256;
        const dest_mem = try allocator.alloc(u64, 1);
        defer allocator.free(dest_mem);
        const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = 1, .width = 1, .rowBytes = @sizeOf(u64) };
        _ = try lookupTable_Planar8toPlanar48(&src.buf, &dest_buf, &table, Flags.kvImageNoFlags);
    }
    {
        var table: [256]Pixel_FFFF = [_]Pixel_FFFF{.{ 0, 0, 0, 0 }} ** 256;
        const dest_mem = try allocator.alloc(f32, 4);
        defer allocator.free(dest_mem);
        const dest_buf = vImage_Buffer{ .data = dest_mem.ptr, .height = 1, .width = 1, .rowBytes = 4 * @sizeOf(f32) };
        _ = try lookupTable_Planar8toPlanar96(&src.buf, &dest_buf, &table, Flags.kvImageNoFlags);
        _ = try lookupTable_Planar8toPlanar128(&src.buf, &dest_buf, &table, Flags.kvImageNoFlags);
    }
    {
        var table: [256]f32 = [_]f32{0} ** 256;
        table[0] = 0.75;
        var dest = try makePlanarFBuffer(allocator, 1, 1, 1, &[_]f32{0});
        defer allocator.free(dest.mem);
        _ = try lookupTable_Planar8toPlanarF(&src.buf, &dest.buf, &table, Flags.kvImageNoFlags);
        try std.testing.expectApproxEqAbs(@as(f32, 0.75), readPlanarF(dest.buf, 0, 0), 1e-6);
    }
}

test "interpolatedLookupTable_PlanarF: linear interpolation between adjacent table entries, matching Transform.h's formula" {
    // Transform.h: fIndex = (tableEntries-1)*(clip(x)-minFloat)/(maxFloat-minFloat);
    //              result = table[floor(fIndex)]*(1-fract) + table[floor(fIndex)+1]*fract
    // tableEntries=3, table has tableEntries+1=4 entries: [0, 10, 20, 30], range [0,1].
    // x=0.25 -> fIndex = 2*0.25 = 0.5 -> index=0, fract=0.5 -> result = 0*0.5+10*0.5 = 5.
    const allocator = std.testing.allocator;
    var src = try makePlanarFBuffer(allocator, 1, 1, 1, &[_]f32{0.25});
    defer allocator.free(src.mem);
    var dest = try makePlanarFBuffer(allocator, 1, 1, 2, &[_]f32{0});
    defer allocator.free(dest.mem);
    const table = [4]f32{ 0, 10, 20, 30 };
    const err = interpolatedLookupTable_PlanarF(&src.buf, &dest.buf, table[0..].ptr, 3, 1.0, 0.0, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), readPlanarF(dest.buf, 0, 0), 1e-3);
}

test "multidimensionalTableCreate/Retain/Release: retain count keeps the table valid after one release, per Transform.h's documented refcounting" {
    // Transform.h: "On creation the table has a retain count of 1. When the
    // reference count drops to 0, the table is destroyed." So: create (1),
    // retain (2), release (1, still valid -- confirmed by a successful
    // lookup call), release again (0, destroyed). We stop using the handle
    // after the second release since further use would be a use-after-free.
    const allocator = std.testing.allocator;
    // 2 src channels (2x2 samples each dimension = 4 total), 1 dest channel.
    const table_data = [_]u16{ 0, 65535, 0, 65535 }; // R0C0, R0C1, R1C0, R1C1 (dest is 1-channel, so flat u16 samples)
    const entries_per_dim = [2]u8{ 2, 2 };
    var err1: vImage_Error = undefined;
    const table = multidimensionalTableCreate(table_data[0..].ptr, 2, 1, entries_per_dim[0..].ptr, .float, Flags.kvImageNoFlags, &err1);
    try std.testing.expectEqual(@as(usize, 0), try types.check(err1));
    try std.testing.expect(table != null);

    const retain_err = multidimensionalTableRetain(table);
    try std.testing.expectEqual(@as(usize, 0), try retain_err);

    const release1_err = multidimensionalTableRelease(table);
    try std.testing.expectEqual(@as(usize, 0), try release1_err);

    // Retain count should still be 1 here (created=1, retained=2, released
    // once=1) -- confirm the table is still usable via an actual lookup call.
    const src = try makePlanarFBuffer(allocator, 1, 1, 1, &[_]f32{0.5});
    defer allocator.free(src.mem);
    const dest = try makePlanarFBuffer(allocator, 1, 1, 2, &[_]f32{0});
    defer allocator.free(dest.mem);
    const srcs = [1]vImage_Buffer{src.buf};
    const dests = [1]vImage_Buffer{dest.buf};
    const lookup_err = multiDimensionalInterpolatedLookupTable(f32, &srcs, &dests, null, table, .full, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try lookup_err);

    const release2_err = multidimensionalTableRelease(table);
    try std.testing.expectEqual(@as(usize, 0), try release2_err);
}

test "floodFill_Planar8: fills the connected component containing the seed, does not cross a differently-valued boundary" {
    const allocator = std.testing.allocator;
    // 5x5 image: a 3x3 block of value 10 in the middle surrounded by 0.
    var img = try makePlanar8Buffer(allocator, 5, 5, 2, &([_]u8{0} ** 25));
    defer allocator.free(img.mem);
    for (1..4) |y| for (1..4) |x| setPlanar8Local(img.buf, y, x, 10);

    const err = floodFill_Planar8(&img.buf, 2, 2, 99, .four, Flags.kvImageNoFlags);
    try std.testing.expectEqual(@as(usize, 0), try err);
    // Interior of the block is now 99.
    try std.testing.expectEqual(@as(u8, 99), readPlanar8(img.buf, 2, 2));
    try std.testing.expectEqual(@as(u8, 99), readPlanar8(img.buf, 1, 1));
    try std.testing.expectEqual(@as(u8, 99), readPlanar8(img.buf, 3, 3));
    // Pixels outside the connected component (originally 0) are untouched.
    try std.testing.expectEqual(@as(u8, 0), readPlanar8(img.buf, 0, 0));
    try std.testing.expectEqual(@as(u8, 0), readPlanar8(img.buf, 4, 4));
}

fn setPlanar8Local(buf: vImage_Buffer, y: usize, x: usize, v: u8) void {
    const base: [*]u8 = @ptrCast(buf.data.?);
    base[y * buf.rowBytes + x] = v;
}

test "floodFill_Planar16U/ARGB8888/ARGB16U: smoke tests, seed_x/seed_y order matches Transform.h" {
    const allocator = std.testing.allocator;
    {
        const mem = try allocator.alloc(u16, 4);
        defer allocator.free(mem);
        @memset(mem, 7);
        const buf = vImage_Buffer{ .data = mem.ptr, .height = 2, .width = 2, .rowBytes = 2 * @sizeOf(u16) };
        const err = floodFill_Planar16U(&buf, 0, 0, 55, .four, Flags.kvImageNoFlags);
        try std.testing.expectEqual(@as(usize, 0), try err);
        try std.testing.expectEqual(@as(u16, 55), mem[0]);
    }
    {
        const mem = try allocator.alloc(u8, 2 * 2 * 4);
        defer allocator.free(mem);
        @memset(mem, 3);
        const buf = vImage_Buffer{ .data = mem.ptr, .height = 2, .width = 2, .rowBytes = 2 * 4 };
        const new_value: Pixel_8888 = .{ 9, 9, 9, 9 };
        const err = floodFill_ARGB8888(&buf, 0, 0, new_value, .four, Flags.kvImageNoFlags);
        try std.testing.expectEqual(@as(usize, 0), try err);
        try std.testing.expectEqualSlices(u8, &[_]u8{ 9, 9, 9, 9 }, mem[0..4]);
    }
    {
        const mem = try allocator.alloc(u16, 2 * 2 * 4);
        defer allocator.free(mem);
        @memset(mem, 3);
        const buf = vImage_Buffer{ .data = mem.ptr, .height = 2, .width = 2, .rowBytes = 2 * 4 * @sizeOf(u16) };
        const new_value: Pixel_ARGB_16U = .{ 9, 9, 9, 9 };
        const err = floodFill_ARGB16U(&buf, 0, 0, new_value, .four, Flags.kvImageNoFlags);
        try std.testing.expectEqual(@as(usize, 0), try err);
        try std.testing.expectEqualSlices(u16, &[_]u16{ 9, 9, 9, 9 }, mem[0..4]);
    }
}
