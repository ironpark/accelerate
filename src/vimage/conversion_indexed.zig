//! Sub-byte planar formats (Planar1, Planar2, Planar4) and the indexed-colour
//! formats built on top of them (Indexed1, Indexed2, Indexed4).
//!
//! Bit packing
//! -----------
//! These formats store 8, 4, or 2 pixels per byte, packed big-endian *within*
//! the byte: the lowest-indexed pixel of a run occupies the **most significant**
//! bits. For Planar1, pixel x of a row lives at bit `7 - (x % 8)` of byte
//! `x / 8`. For Planar2 the pixel at x uses bits `6 - 2*(x % 4)` and up; for
//! Planar4, x even is the high nibble and x odd the low nibble.
//!
//! Plane sizing
//! ------------
//! `vImage_Buffer.width` is always counted in **pixels**, but `data` and
//! `rowBytes` are counted in **whole bytes**, so a row may end mid-byte:
//!
//!   * a Planar1/Indexed1 buffer of width W needs at least `(W + 7) / 8`
//!     bytes per row,
//!   * Planar2/Indexed2 needs `(W + 3) / 4`,
//!   * Planar4/Indexed4 needs `(W + 1) / 2`.
//!
//! Sub-byte indexing of a scanline is not expressible, so a buffer cannot start
//! part-way into a byte. On the decode side the leftover bits of the final byte
//! of a row are ignored; on the encode side their contents are unspecified, so
//! never compare a whole trailing byte when W is not a multiple of the packing
//! factor.
//!
//! Value scaling
//! -------------
//! The Planar*N* -> Planar8 direction is a plain multiply that maps the format's
//! full range onto 0...255 exactly: Planar1 multiplies by 255, Planar2 by 85,
//! and Planar4 by 17. The Indexed*N* -> Planar8 direction instead uses the pixel
//! as an index into a caller-supplied table of 2, 4, or 16 `Pixel_8` entries.
//!
//! Going down (Planar8 -> Planar*N*/Indexed*N*) is lossy and therefore takes a
//! dither method; see `Dither`. For the Indexed directions the colour table is
//! an in/out parameter: pass a table that is already populated (its entries must
//! be in ascending order or vImage returns `kvImageInvalidParameter`), or pass an
//! all-zero table and vImage will compute a suitable one for the image and write
//! it back.
//!
//! None of these functions operate in place.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const vImage_Flags = types.vImage_Flags;
const VImageError = types.VImageError;
const check = types.check;
const Pixel_8 = types.Pixel_8;
const Flags = types.Flags;

// ============================================================================
// Dither methods
// ============================================================================

/// Dither method for the lossy Planar8 -> Planar1/2/4 and Planar8 -> Indexed1/2/4
/// directions. These are the `kvImageConvert_Dither*` constants from
/// Conversion.h, passed as a plain C `int`.
///
/// Anything outside this set makes the conversion fail with
/// `VImageError.InvalidParameter` (kvImageInvalidParameter, -21773).
///
/// NOTE: this belongs in types.zig once the other dithered converters
/// (ARGB8888toARGB1555_dithered, Planar16UtoPlanar8_dithered, ...) are wrapped;
/// it is defined here only because this is the first module that needs it.
pub const Dither = struct {
    /// No dithering: round to the nearest representable value. Reproducible,
    /// but prone to banding across smooth gradients.
    pub const none: c_int = 0;
    /// Pre-computed blue noise, with a per-call random offset - so results are
    /// NOT reproducible between calls. Tiles safely.
    pub const ordered: c_int = 1;
    /// Pre-computed blue noise with a fixed offset: reproducible and tileable.
    pub const ordered_reproducible: c_int = 2;
    /// Floyd-Steinberg error diffusion. Does not tile; pass the whole image.
    pub const floyd_steinberg: c_int = 3;
    /// Atkinson error diffusion. Does not tile; pass the whole image.
    pub const atkinson: c_int = 4;

    /// OR into `ordered` / `ordered_reproducible` to shape the noise as a
    /// gaussian distribution. This is the default, hence zero.
    pub const ordered_gaussian_blue: c_int = 0;
    /// OR into `ordered` / `ordered_reproducible` for uniformly distributed
    /// noise: better colour fidelity, visibly noisier result.
    pub const ordered_uniform_blue: c_int = 1 << 28;
    /// Mask covering the noise-shape bits.
    pub const ordered_noise_shape_mask: c_int = 0xf << 28;
};

// ============================================================================
// Sub-byte planar -> Planar8
// ============================================================================

/// Expands a 1-bit-per-pixel plane to Planar8, multiplying each pixel by 255,
/// so 0 -> 0 and 1 -> 255.
///
/// `src` must supply at least `(dest.width + 7) / 8` bytes per row; the unused
/// low bits of a row's final byte are ignored. Does not work in place.
pub fn planar1toPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_Planar1toPlanar8(src, dest, flags));
}

/// Expands a 2-bit-per-pixel plane to Planar8, multiplying each pixel by 85,
/// so 0,1,2,3 -> 0,85,170,255.
///
/// `src` must supply at least `(dest.width + 3) / 4` bytes per row, four pixels
/// per byte, highest-order bit pair first. Does not work in place.
pub fn planar2toPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_Planar2toPlanar8(src, dest, flags));
}

/// Expands a 4-bit-per-pixel plane to Planar8, multiplying each pixel by 17,
/// so 0...15 -> 0, 17, 34, ... 255.
///
/// `src` must supply at least `(dest.width + 1) / 2` bytes per row: the even
/// pixel is the high nibble, the odd pixel the low nibble. Does not work in
/// place.
pub fn planar4toPlanar8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_Planar4toPlanar8(src, dest, flags));
}

// ============================================================================
// Indexed -> Planar8
// ============================================================================

/// Expands a 1-bit-per-pixel indexed image to Planar8 by looking each pixel up
/// in a two-entry colour table: bit 0 selects `colors[0]`, bit 1 `colors[1]`.
///
/// Unlike `planar1toPlanar8`, no scaling happens - the table entry is copied
/// verbatim. `src` needs `(dest.width + 7) / 8` bytes per row. Does not work in
/// place.
pub fn indexed1toPlanar8(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    colors: *const [2]Pixel_8,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_Indexed1toPlanar8(src, dest, colors, flags));
}

/// Expands a 2-bit-per-pixel indexed image to Planar8 through a four-entry
/// colour table.
///
/// `src` needs `(dest.width + 3) / 4` bytes per row. Does not work in place.
pub fn indexed2toPlanar8(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    colors: *const [4]Pixel_8,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_Indexed2toPlanar8(src, dest, colors, flags));
}

/// Expands a 4-bit-per-pixel indexed image to Planar8 through a sixteen-entry
/// colour table.
///
/// `src` needs `(dest.width + 1) / 2` bytes per row. Does not work in place.
pub fn indexed4toPlanar8(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    colors: *const [16]Pixel_8,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_Indexed4toPlanar8(src, dest, colors, flags));
}

// ============================================================================
// Planar8 -> sub-byte planar
// ============================================================================

/// Reduces Planar8 to a 1-bit-per-pixel plane. With `Dither.none` this is a
/// round-to-nearest against the two representable values 0 and 255, i.e. a
/// threshold at 128.
///
/// `dest` must have at least `(dest.width + 7) / 8` bytes per row; if the width
/// is not a multiple of 8 the trailing bits of the last byte of each row are
/// left unspecified.
///
/// `tempBuffer` may be null (the routine then allocates internally); to size one
/// yourself, call with `Flags.kvImageGetTempBufferSize` and use the returned
/// byte count. Does not work in place.
pub fn planar8toPlanar1(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    dither: c_int,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_Planar8toPlanar1(src, dest, tempBuffer, dither, flags));
}

/// Reduces Planar8 to a 2-bit-per-pixel plane; with `Dither.none`, the result is
/// `round(value / 85)`.
///
/// `dest` needs `(dest.width + 3) / 4` bytes per row. See `planar8toPlanar1` for
/// `tempBuffer` sizing. Does not work in place.
pub fn planar8toPlanar2(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    dither: c_int,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_Planar8toPlanar2(src, dest, tempBuffer, dither, flags));
}

/// Reduces Planar8 to a 4-bit-per-pixel plane; with `Dither.none`, the result is
/// `round(value / 17)`.
///
/// `dest` needs `(dest.width + 1) / 2` bytes per row. See `planar8toPlanar1` for
/// `tempBuffer` sizing. Does not work in place.
pub fn planar8toPlanar4(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    dither: c_int,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_Planar8toPlanar4(src, dest, tempBuffer, dither, flags));
}

// ============================================================================
// Planar8 -> Indexed
// ============================================================================

/// Reduces Planar8 to a 1-bit-per-pixel indexed image against a two-entry
/// colour table.
///
/// `colors` is in/out: a populated table must be in ascending order, otherwise
/// vImage returns `VImageError.InvalidParameter`. Pass an all-zero table to have
/// vImage pick a table for the image and write it back through this pointer.
///
/// `dest` needs `(dest.width + 7) / 8` bytes per row. See `planar8toPlanar1` for
/// `tempBuffer` sizing. Does not work in place.
pub fn planar8toIndexed1(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    colors: *[2]Pixel_8,
    dither: c_int,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_Planar8toIndexed1(src, dest, tempBuffer, colors, dither, flags));
}

/// Reduces Planar8 to a 2-bit-per-pixel indexed image against a four-entry
/// colour table. See `planar8toIndexed1` for the in/out semantics of `colors`.
///
/// `dest` needs `(dest.width + 3) / 4` bytes per row. Does not work in place.
pub fn planar8toIndexed2(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    colors: *[4]Pixel_8,
    dither: c_int,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_Planar8toIndexed2(src, dest, tempBuffer, colors, dither, flags));
}

/// Reduces Planar8 to a 4-bit-per-pixel indexed image against a sixteen-entry
/// colour table. See `planar8toIndexed1` for the in/out semantics of `colors`.
///
/// `dest` needs `(dest.width + 1) / 2` bytes per row. Does not work in place.
pub fn planar8toIndexed4(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    tempBuffer: ?*anyopaque,
    colors: *[16]Pixel_8,
    dither: c_int,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_Planar8toIndexed4(src, dest, tempBuffer, colors, dither, flags));
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

/// One-row buffer over `bytes`, `width` pixels wide. The caller states the
/// pixel width; the byte length is whatever it takes to hold it.
fn rowBuffer(bytes: []u8, width: u64) vImage_Buffer {
    return .{
        .data = bytes.ptr,
        .height = 1,
        .width = width,
        .rowBytes = bytes.len,
    };
}

test "planar1toPlanar8 unpacks MSB-first, 8 pixels per byte, scaled by 255" {
    const allocator = testing.allocator;
    // 0b1011_0001: pixel 0 is the *high* bit.
    var src_bytes = [_]u8{0b1011_0001};
    const dest_bytes = try allocator.alloc(u8, 8);
    defer allocator.free(dest_bytes);
    @memset(dest_bytes, 0xAA);

    const src = rowBuffer(&src_bytes, 8);
    const dest = rowBuffer(dest_bytes, 8);
    try testing.expectEqual(@as(usize, 0), try planar1toPlanar8(&src, &dest, Flags.kvImageNoFlags));

    try testing.expectEqualSlices(u8, &[_]u8{ 255, 0, 255, 255, 0, 0, 0, 255 }, dest_bytes);
}

test "planar2toPlanar8 unpacks 4 pixels per byte, scaled by 85" {
    const allocator = testing.allocator;
    // 0b00_01_10_11 -> indices 0,1,2,3 -> 0,85,170,255.
    var src_bytes = [_]u8{0b00_01_10_11};
    const dest_bytes = try allocator.alloc(u8, 4);
    defer allocator.free(dest_bytes);
    @memset(dest_bytes, 0xAA);

    const src = rowBuffer(&src_bytes, 4);
    const dest = rowBuffer(dest_bytes, 4);
    try testing.expectEqual(@as(usize, 0), try planar2toPlanar8(&src, &dest, Flags.kvImageNoFlags));

    try testing.expectEqualSlices(u8, &[_]u8{ 0, 85, 170, 255 }, dest_bytes);
}

test "planar4toPlanar8 unpacks high nibble first, scaled by 17" {
    const allocator = testing.allocator;
    // 0x5A -> 5,10 ; 0x0F -> 0,15.
    var src_bytes = [_]u8{ 0x5A, 0x0F };
    const dest_bytes = try allocator.alloc(u8, 4);
    defer allocator.free(dest_bytes);
    @memset(dest_bytes, 0xAA);

    const src = rowBuffer(&src_bytes, 4);
    const dest = rowBuffer(dest_bytes, 4);
    try testing.expectEqual(@as(usize, 0), try planar4toPlanar8(&src, &dest, Flags.kvImageNoFlags));

    try testing.expectEqualSlices(u8, &[_]u8{ 5 * 17, 10 * 17, 0 * 17, 15 * 17 }, dest_bytes);
}

test "planar1toPlanar8: a width-9 row needs (9+7)/8 = 2 bytes, trailing bits ignored" {
    const allocator = testing.allocator;
    // Second byte holds only pixel 8 (its high bit); the low 7 bits are junk
    // that must not appear in the output.
    var src_bytes = [_]u8{ 0b1111_0000, 0b0111_1111 };
    try testing.expectEqual(@as(usize, 2), (9 + 7) / 8);

    const dest_bytes = try allocator.alloc(u8, 9);
    defer allocator.free(dest_bytes);
    @memset(dest_bytes, 0xAA);

    const src = rowBuffer(&src_bytes, 9);
    const dest = rowBuffer(dest_bytes, 9);
    try testing.expectEqual(@as(usize, 0), try planar1toPlanar8(&src, &dest, Flags.kvImageNoFlags));

    try testing.expectEqualSlices(u8, &[_]u8{ 255, 255, 255, 255, 0, 0, 0, 0, 0 }, dest_bytes);
}

test "planar8toPlanar1 with Dither.none thresholds at 128 and packs MSB first" {
    const allocator = testing.allocator;
    //          255  0  255 255  0   0    127 128
    // 127 rounds down to 0 (127/255 -> 0), 128 rounds up to 1.
    var src_bytes = [_]u8{ 255, 0, 255, 255, 0, 0, 127, 128 };
    const dest_bytes = try allocator.alloc(u8, 1);
    defer allocator.free(dest_bytes);
    dest_bytes[0] = 0;

    const src = rowBuffer(&src_bytes, 8);
    const dest = rowBuffer(dest_bytes, 8);
    try testing.expectEqual(
        @as(usize, 0),
        try planar8toPlanar1(&src, &dest, null, Dither.none, Flags.kvImageNoFlags),
    );

    try testing.expectEqual(@as(u8, 0b1011_0001), dest_bytes[0]);
}

test "Planar8 -> Planar4 -> Planar8 round trips exact multiples of 17" {
    const allocator = testing.allocator;
    var src_bytes = [_]u8{ 0, 17, 5 * 17, 10 * 17, 14 * 17, 255 };
    const packed_bytes = try allocator.alloc(u8, 3); // (6 + 1) / 2
    defer allocator.free(packed_bytes);
    @memset(packed_bytes, 0);
    const back_bytes = try allocator.alloc(u8, 6);
    defer allocator.free(back_bytes);
    @memset(back_bytes, 0xAA);

    const src = rowBuffer(&src_bytes, 6);
    const mid = rowBuffer(packed_bytes, 6);
    const back = rowBuffer(back_bytes, 6);

    try testing.expectEqual(
        @as(usize, 0),
        try planar8toPlanar4(&src, &mid, null, Dither.none, Flags.kvImageNoFlags),
    );
    // Exact packed bytes: nibbles 0,1 | 5,10 | 14,15.
    try testing.expectEqualSlices(u8, &[_]u8{ 0x01, 0x5A, 0xEF }, packed_bytes);

    try testing.expectEqual(@as(usize, 0), try planar4toPlanar8(&mid, &back, Flags.kvImageNoFlags));
    try testing.expectEqualSlices(u8, &src_bytes, back_bytes);
}

test "planar8toPlanar2 is lossy: Dither.none rounds to the nearest multiple of 85" {
    const allocator = testing.allocator;
    // 40 -> 0 (|40| < 42.5), 50 -> 85, 200 -> 170 (|200-170|=30 < |255-200|=55).
    var src_bytes = [_]u8{ 40, 50, 200, 255 };
    const packed_bytes = try allocator.alloc(u8, 1);
    defer allocator.free(packed_bytes);
    packed_bytes[0] = 0;
    const back_bytes = try allocator.alloc(u8, 4);
    defer allocator.free(back_bytes);
    @memset(back_bytes, 0xAA);

    const src = rowBuffer(&src_bytes, 4);
    const mid = rowBuffer(packed_bytes, 4);
    const back = rowBuffer(back_bytes, 4);

    try testing.expectEqual(
        @as(usize, 0),
        try planar8toPlanar2(&src, &mid, null, Dither.none, Flags.kvImageNoFlags),
    );
    try testing.expectEqual(@as(u8, 0b00_01_10_11), packed_bytes[0]);

    try testing.expectEqual(@as(usize, 0), try planar2toPlanar8(&mid, &back, Flags.kvImageNoFlags));
    // Every pixel is within half a quantisation step (43) of the original.
    for (src_bytes, back_bytes) |want, got| {
        const diff = @abs(@as(i32, want) - @as(i32, got));
        try testing.expect(diff <= 43);
    }
    try testing.expectEqualSlices(u8, &[_]u8{ 0, 85, 170, 255 }, back_bytes);
}

test "indexed1toPlanar8 looks bits up in a 2-entry table instead of scaling" {
    const allocator = testing.allocator;
    var src_bytes = [_]u8{0b1011_0001};
    const colors = [2]Pixel_8{ 10, 200 };
    const dest_bytes = try allocator.alloc(u8, 8);
    defer allocator.free(dest_bytes);
    @memset(dest_bytes, 0xAA);

    const src = rowBuffer(&src_bytes, 8);
    const dest = rowBuffer(dest_bytes, 8);
    try testing.expectEqual(
        @as(usize, 0),
        try indexed1toPlanar8(&src, &dest, &colors, Flags.kvImageNoFlags),
    );

    try testing.expectEqualSlices(u8, &[_]u8{ 200, 10, 200, 200, 10, 10, 10, 200 }, dest_bytes);
}

test "indexed2toPlanar8 maps each 2-bit index through a 4-entry table" {
    const allocator = testing.allocator;
    var src_bytes = [_]u8{ 0b00_01_10_11, 0b11_00_01_10 };
    const colors = [4]Pixel_8{ 3, 30, 130, 230 };
    const dest_bytes = try allocator.alloc(u8, 8);
    defer allocator.free(dest_bytes);
    @memset(dest_bytes, 0xAA);

    const src = rowBuffer(&src_bytes, 8);
    const dest = rowBuffer(dest_bytes, 8);
    try testing.expectEqual(
        @as(usize, 0),
        try indexed2toPlanar8(&src, &dest, &colors, Flags.kvImageNoFlags),
    );

    try testing.expectEqualSlices(
        u8,
        &[_]u8{ 3, 30, 130, 230, 230, 3, 30, 130 },
        dest_bytes,
    );
}

test "indexed4toPlanar8 maps each nibble through a 16-entry table" {
    const allocator = testing.allocator;
    var src_bytes = [_]u8{ 0x0F, 0x5A, 0x73 };
    // colors[i] = 255 - 16*i, so a table entry is never equal to i*17 (which
    // would let a plain Planar4 expansion masquerade as a table lookup).
    var colors: [16]Pixel_8 = undefined;
    for (&colors, 0..) |*e, i| e.* = @intCast(255 - 16 * i);

    const dest_bytes = try allocator.alloc(u8, 6);
    defer allocator.free(dest_bytes);
    @memset(dest_bytes, 0xAA);

    const src = rowBuffer(&src_bytes, 6);
    const dest = rowBuffer(dest_bytes, 6);
    try testing.expectEqual(
        @as(usize, 0),
        try indexed4toPlanar8(&src, &dest, &colors, Flags.kvImageNoFlags),
    );

    try testing.expectEqualSlices(
        u8,
        &[_]u8{ colors[0], colors[15], colors[5], colors[10], colors[7], colors[3] },
        dest_bytes,
    );
}

test "planar8toIndexed1 with a supplied table picks the nearest of two entries" {
    const allocator = testing.allocator;
    // Table {10, 200}: the midpoint is 105, so <= 105 -> index 0.
    var colors = [2]Pixel_8{ 10, 200 };
    var src_bytes = [_]u8{ 10, 200, 200, 10, 0, 255, 20, 190 };
    const dest_bytes = try allocator.alloc(u8, 1);
    defer allocator.free(dest_bytes);
    dest_bytes[0] = 0;

    const src = rowBuffer(&src_bytes, 8);
    const dest = rowBuffer(dest_bytes, 8);
    try testing.expectEqual(
        @as(usize, 0),
        try planar8toIndexed1(&src, &dest, null, &colors, Dither.none, Flags.kvImageNoFlags),
    );

    try testing.expectEqual(@as(u8, 0b0110_0101), dest_bytes[0]);
    // The table is in/out but a supplied table must come back untouched.
    try testing.expectEqualSlices(u8, &[_]u8{ 10, 200 }, &colors);
}

test "planar8toIndexed2 with an all-zero table has vImage compute the table" {
    const allocator = testing.allocator;
    var colors = [4]Pixel_8{ 0, 0, 0, 0 };
    var src_bytes = [_]u8{ 0, 80, 160, 255 };
    const dest_bytes = try allocator.alloc(u8, 1);
    defer allocator.free(dest_bytes);
    dest_bytes[0] = 0;

    const src = rowBuffer(&src_bytes, 4);
    const dest = rowBuffer(dest_bytes, 4);
    try testing.expectEqual(
        @as(usize, 0),
        try planar8toIndexed2(&src, &dest, null, &colors, Dither.none, Flags.kvImageNoFlags),
    );

    // vImage filled in a table; it must be non-descending and no longer all
    // zero. (Observed on macOS 15: the computed table is { 0, 85, 170, 255 } -
    // an even ramp rather than something fitted to the histogram - but only the
    // ordering is documented, so that is all this asserts.)
    try testing.expect(colors[3] != 0);
    try testing.expect(colors[0] <= colors[1]);
    try testing.expect(colors[1] <= colors[2]);
    try testing.expect(colors[2] <= colors[3]);

    // Whatever table it chose, decoding through it must land within one
    // quantisation step (85) of the original samples.
    const back_bytes = try allocator.alloc(u8, 4);
    defer allocator.free(back_bytes);
    const back = rowBuffer(back_bytes, 4);
    try testing.expectEqual(
        @as(usize, 0),
        try indexed2toPlanar8(&dest, &back, &colors, Flags.kvImageNoFlags),
    );
    for (src_bytes, back_bytes) |want, got| {
        try testing.expect(@abs(@as(i32, want) - @as(i32, got)) <= 85);
    }
}

test "Planar8 -> Indexed4 -> Planar8 round trips values that are in the table" {
    const allocator = testing.allocator;
    // Ascending table; every source sample is exactly an entry, so a
    // Dither.none round trip is lossless.
    var colors: [16]Pixel_8 = undefined;
    for (&colors, 0..) |*e, i| e.* = @intCast(i * 16);
    var src_bytes = [_]u8{ colors[0], colors[15], colors[5], colors[10] };

    const packed_bytes = try allocator.alloc(u8, 2);
    defer allocator.free(packed_bytes);
    @memset(packed_bytes, 0);
    const back_bytes = try allocator.alloc(u8, 4);
    defer allocator.free(back_bytes);
    @memset(back_bytes, 0xAA);

    const src = rowBuffer(&src_bytes, 4);
    const mid = rowBuffer(packed_bytes, 4);
    const back = rowBuffer(back_bytes, 4);

    try testing.expectEqual(
        @as(usize, 0),
        try planar8toIndexed4(&src, &mid, null, &colors, Dither.none, Flags.kvImageNoFlags),
    );
    // Indices 0,15 | 5,10, high nibble first.
    try testing.expectEqualSlices(u8, &[_]u8{ 0x0F, 0x5A }, packed_bytes);

    try testing.expectEqual(
        @as(usize, 0),
        try indexed4toPlanar8(&mid, &back, &colors, Flags.kvImageNoFlags),
    );
    try testing.expectEqualSlices(u8, &src_bytes, back_bytes);
}

test "an unrecognised dither value is rejected with kvImageInvalidParameter" {
    const allocator = testing.allocator;
    var src_bytes = [_]u8{ 0, 255, 0, 255, 0, 255, 0, 255 };
    const dest_bytes = try allocator.alloc(u8, 1);
    defer allocator.free(dest_bytes);
    dest_bytes[0] = 0;

    const src = rowBuffer(&src_bytes, 8);
    const dest = rowBuffer(dest_bytes, 8);
    // 99 is outside the kvImageConvert_Dither* set; vImage returns
    // kvImageInvalidParameter (-21773), which `check` maps to InvalidParameter.
    try testing.expectError(
        VImageError.InvalidParameter,
        planar8toPlanar1(&src, &dest, null, 99, Flags.kvImageNoFlags),
    );
    try testing.expectEqual(
        @as(vImage_Error, -21773),
        @as(vImage_Error, types.Error.kvImageInvalidParameter),
    );
}

test "kvImageGetTempBufferSize reports a size through the return slot, not an error" {
    const allocator = testing.allocator;
    var src_bytes = [_]u8{ 0, 255, 0, 255, 0, 255, 0, 255 };
    const dest_bytes = try allocator.alloc(u8, 1);
    defer allocator.free(dest_bytes);
    dest_bytes[0] = 0;

    const src = rowBuffer(&src_bytes, 8);
    const dest = rowBuffer(dest_bytes, 8);
    const size = try planar8toPlanar1(&src, &dest, null, Dither.none, Flags.kvImageGetTempBufferSize);
    // Documented as "does no work, but returns the required size": whatever it
    // is, it must not have been reported as a failure, and the destination must
    // be untouched.
    try testing.expectEqual(@as(u8, 0), dest_bytes[0]);

    if (size != 0) {
        const temp = try allocator.alloc(u8, size);
        defer allocator.free(temp);
        try testing.expectEqual(
            @as(usize, 0),
            try planar8toPlanar1(&src, &dest, temp.ptr, Dither.none, Flags.kvImageNoFlags),
        );
        try testing.expectEqual(@as(u8, 0b0101_0101), dest_bytes[0]);
    }
}

test "ordered_reproducible dithering gives the same bytes on every call" {
    const allocator = testing.allocator;
    // A flat mid-grey ramp is the case where dithering actually differs from
    // rounding; the reproducible variant must still be deterministic.
    var src_bytes = [_]u8{ 100, 110, 120, 130, 140, 150, 160, 170 };
    const a_bytes = try allocator.alloc(u8, 1);
    defer allocator.free(a_bytes);
    const b_bytes = try allocator.alloc(u8, 1);
    defer allocator.free(b_bytes);
    a_bytes[0] = 0;
    b_bytes[0] = 0;

    const src = rowBuffer(&src_bytes, 8);
    const a = rowBuffer(a_bytes, 8);
    const b = rowBuffer(b_bytes, 8);
    const dither = Dither.ordered_reproducible | Dither.ordered_uniform_blue;
    try testing.expectEqual(@as(usize, 0), try planar8toPlanar1(&src, &a, null, dither, Flags.kvImageNoFlags));
    try testing.expectEqual(@as(usize, 0), try planar8toPlanar1(&src, &b, null, dither, Flags.kvImageNoFlags));
    try testing.expectEqual(a_bytes[0], b_bytes[0]);
}

test "a destination wider than the source is refused, not silently truncated" {
    const allocator = testing.allocator;
    var src_bytes = [_]u8{0b1010_1010};
    const dest_bytes = try allocator.alloc(u8, 16);
    defer allocator.free(dest_bytes);
    @memset(dest_bytes, 0xAA);

    const src = rowBuffer(&src_bytes, 8);
    const dest = rowBuffer(dest_bytes, 16);
    try testing.expectError(
        VImageError.RoiLargerThanInputBuffer,
        planar1toPlanar8(&src, &dest, Flags.kvImageNoFlags),
    );
}
