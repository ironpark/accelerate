const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
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
) vImage_Error {
    const src_planes: u32 = @intCast(srcs.len);
    const dest_planes: u32 = @intCast(dests.len);
    switch (T) {
        f32 => return c.vImageMatrixMultiply_PlanarF(
            srcs.ptr,
            dests.ptr,
            src_planes,
            dest_planes,
            matrix.ptr,
            pre_bias,
            post_bias,
            flags,
        ),
        i16 => return c.vImageMatrixMultiply_Planar8(
            srcs.ptr,
            dests.ptr,
            src_planes,
            dest_planes,
            matrix.ptr,
            divisor,
            pre_bias,
            post_bias,
            flags,
        ),
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
) vImage_Error {
    return c.vImageMatrixMultiply_Planar16S(
        srcs.ptr,
        dests.ptr,
        @intCast(srcs.len),
        @intCast(dests.len),
        matrix.ptr,
        divisor,
        pre_bias,
        post_bias,
        flags,
    );
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
) vImage_Error {
    switch (T) {
        f32 => return c.vImageMatrixMultiply_ARGBFFFF(src, dest, matrix, pre_bias, post_bias, flags),
        i16 => return c.vImageMatrixMultiply_ARGB8888(src, dest, matrix, divisor, pre_bias, post_bias, flags),
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
) vImage_Error {
    switch (T) {
        f32 => return c.vImageMatrixMultiply_ARGBFFFFToPlanarF(src, dest, matrix, pre_bias, post_bias, flags),
        i16 => return c.vImageMatrixMultiply_ARGB8888ToPlanar8(src, dest, matrix, divisor, pre_bias, post_bias, flags),
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
pub fn gammaPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, gamma: GammaFunction, flags: vImage_Flags) vImage_Error {
    return c.vImageGamma_PlanarF(src, dest, gamma, flags);
}

/// Apply a gamma curve converting Planar8 to PlanarF.
pub fn gammaPlanar8toPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, gamma: GammaFunction, flags: vImage_Flags) vImage_Error {
    return c.vImageGamma_Planar8toPlanarF(src, dest, gamma, flags);
}

/// Apply a gamma curve converting PlanarF to Planar8.
pub fn gammaPlanarFtoPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, gamma: GammaFunction, flags: vImage_Flags) vImage_Error {
    return c.vImageGamma_PlanarFtoPlanar8(src, dest, gamma, flags);
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
) vImage_Error {
    if (Src == f32 and Dst == f32) {
        return c.vImagePiecewiseGamma_PlanarF(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags);
    } else if (Src == f32 and Dst == u8) {
        return c.vImagePiecewiseGamma_PlanarFtoPlanar8(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags);
    } else if (Src == u8 and Dst == u8) {
        return c.vImagePiecewiseGamma_Planar8(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags);
    } else if (Src == u8 and Dst == f32) {
        return c.vImagePiecewiseGamma_Planar8toPlanarF(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags);
    } else if (Src == u8 and Dst == Pixel_16S) {
        return c.vImagePiecewiseGamma_Planar8toPlanar16Q12(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags);
    } else if (Src == Pixel_16S and Dst == Pixel_16S) {
        return c.vImagePiecewiseGamma_Planar16Q12(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags);
    } else if (Src == Pixel_16S and Dst == u8) {
        return c.vImagePiecewiseGamma_Planar16Q12toPlanar8(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags);
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
) vImage_Error {
    switch (T) {
        f32 => return c.vImageSymmetricPiecewiseGamma_PlanarF(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags),
        Pixel_16S => return c.vImageSymmetricPiecewiseGamma_Planar16Q12(src, dest, exponential_coeffs, gamma, linear_coeffs, boundary, flags),
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
) vImage_Error {
    if (Src == f32 and Dst == f32) {
        return c.vImagePiecewisePolynomial_PlanarF(src, dest, coefficients, boundaries, order, log2segments, flags);
    } else if (Src == u8 and Dst == f32) {
        return c.vImagePiecewisePolynomial_Planar8toPlanarF(src, dest, coefficients, boundaries, order, log2segments, flags);
    } else if (Src == f32 and Dst == u8) {
        return c.vImagePiecewisePolynomial_PlanarFtoPlanar8(src, dest, coefficients, boundaries, order, log2segments, flags);
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
) vImage_Error {
    return c.vImageSymmetricPiecewisePolynomial_PlanarF(src, dest, coefficients, boundaries, order, log2segments, flags);
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
) vImage_Error {
    return c.vImagePiecewiseRational_PlanarF(src, dest, top_coefficients, bottom_coefficients, boundaries, top_order, bottom_order, log2segments, flags);
}

// ============================================================================
// Lookup table operations
// ============================================================================

/// Simple 8-bit to 16-bit lookup table.
pub fn lookupTable_Planar8toPlanar16(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]Pixel_16U, flags: vImage_Flags) vImage_Error {
    return c.vImageLookupTable_Planar8toPlanar16(src, dest, table, flags);
}

/// 8-bit to 24-bit (3-channel 8-bit) lookup table.
pub fn lookupTable_Planar8toPlanar24(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]u32, flags: vImage_Flags) vImage_Error {
    return c.vImageLookupTable_Planar8toPlanar24(src, dest, table, flags);
}

/// 8-bit to 48-bit (3-channel 16-bit) lookup table.
pub fn lookupTable_Planar8toPlanar48(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]u64, flags: vImage_Flags) vImage_Error {
    return c.vImageLookupTable_Planar8toPlanar48(src, dest, table, flags);
}

/// 8-bit to 96-bit (3-channel float) lookup table. Each entry is [4]f32; only the last 3 channels are written.
pub fn lookupTable_Planar8toPlanar96(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]Pixel_FFFF, flags: vImage_Flags) vImage_Error {
    return c.vImageLookupTable_Planar8toPlanar96(src, dest, table, flags);
}

/// 8-bit to 128-bit (4-channel float) lookup table.
pub fn lookupTable_Planar8toPlanar128(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]Pixel_FFFF, flags: vImage_Flags) vImage_Error {
    return c.vImageLookupTable_Planar8toPlanar128(src, dest, table, flags);
}

/// 8-bit to float lookup table.
pub fn lookupTable_Planar8toPlanarF(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]Pixel_F, flags: vImage_Flags) vImage_Error {
    return c.vImageLookupTable_Planar8toPlanarF(src, dest, table, flags);
}

/// Float to 8-bit lookup table. Input floats in [0,1] are quantised to 4096 entries.
pub fn lookupTable_PlanarFtoPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [4096]Pixel_8, flags: vImage_Flags) vImage_Error {
    return c.vImageLookupTable_PlanarFtoPlanar8(src, dest, table, flags);
}

/// 8-bit to 64-bit unsigned lookup table.
pub fn lookupTable_8to64U(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [256]u64, flags: vImage_Flags) vImage_Error {
    return c.vImageLookupTable_8to64U(src, dest, table, flags);
}

/// 16-bit to 16-bit lookup table (65536 entries).
pub fn lookupTable_Planar16(src: *const vImage_Buffer, dest: *const vImage_Buffer, table: *const [0x10000]Pixel_16U, flags: vImage_Flags) vImage_Error {
    return c.vImageLookupTable_Planar16(src, dest, table, flags);
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
) vImage_Error {
    return c.vImageInterpolatedLookupTable_PlanarF(src, dest, table, table_entries, max_float, min_float, flags);
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
pub fn multidimensionalTableRetain(table: vImage_MultidimensionalTable) vImage_Error {
    return c.vImageMultidimensionalTable_Retain(table);
}

/// Decrement the retain count; the table is freed when the count reaches 0.
pub fn multidimensionalTableRelease(table: vImage_MultidimensionalTable) vImage_Error {
    return c.vImageMultidimensionalTable_Release(table);
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
) vImage_Error {
    switch (T) {
        f32 => return c.vImageMultiDimensionalInterpolatedLookupTable_PlanarF(srcs.ptr, dests.ptr, temp_buffer, table, @intFromEnum(method), flags),
        Pixel_16S => return c.vImageMultiDimensionalInterpolatedLookupTable_Planar16Q12(srcs.ptr, dests.ptr, temp_buffer, table, @intFromEnum(method), flags),
        else => @compileError("multiDimensionalInterpolatedLookupTable requires f32 (PlanarF) or i16 (Planar16Q12)"),
    }
}

// ============================================================================
// Flood fill
// ============================================================================

/// Fill a connected component of a Planar8 image with a new value.
pub fn floodFill_Planar8(src_dest: *const vImage_Buffer, seed_x: vImagePixelCount, seed_y: vImagePixelCount, new_value: Pixel_8, connectivity: c_int, flags: vImage_Flags) vImage_Error {
    return c.vImageFloodFill_Planar8(src_dest, null, seed_x, seed_y, new_value, connectivity, flags);
}

/// Fill a connected component of a Planar16U image with a new value.
pub fn floodFill_Planar16U(src_dest: *const vImage_Buffer, seed_x: vImagePixelCount, seed_y: vImagePixelCount, new_value: Pixel_16U, connectivity: c_int, flags: vImage_Flags) vImage_Error {
    return c.vImageFloodFill_Planar16U(src_dest, null, seed_x, seed_y, new_value, connectivity, flags);
}

/// Fill a connected component of an ARGB8888 image with a new value.
pub fn floodFill_ARGB8888(src_dest: *const vImage_Buffer, seed_x: vImagePixelCount, seed_y: vImagePixelCount, new_value: Pixel_8888, connectivity: c_int, flags: vImage_Flags) vImage_Error {
    return c.vImageFloodFill_ARGB8888(src_dest, null, seed_x, seed_y, new_value, connectivity, flags);
}

/// Fill a connected component of an ARGB16U image with a new value.
pub fn floodFill_ARGB16U(src_dest: *const vImage_Buffer, seed_x: vImagePixelCount, seed_y: vImagePixelCount, new_value: Pixel_ARGB_16U, connectivity: c_int, flags: vImage_Flags) vImage_Error {
    return c.vImageFloodFill_ARGB16U(src_dest, null, seed_x, seed_y, new_value, connectivity, flags);
}
