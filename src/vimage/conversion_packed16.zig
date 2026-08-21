//! Conversions for vImage's three 16-bit-per-pixel packed formats:
//! ARGB1555, RGBA5551 and RGB565.
//!
//! Layout. Each pixel is one host-endian `uint16_t` (little endian on Intel and
//! Apple silicon), so a buffer row is `width * 2` bytes and the channels are bit
//! fields of that integer, most significant field first:
//!
//!     ARGB1555:  A<<15 | R<<10 | G<<5 | B        (1,5,5,5 bits)
//!     RGBA5551:  R<<11 | G<<6  | B<<1 | A        (5,5,5,1 bits)
//!     RGB565:    R<<11 | G<<5  | B               (5,6,5 bits, no alpha)
//!
//! Because they are host-endian integers rather than byte streams, the byte
//! order in memory is *not* the channel order: on a little endian machine the
//! low byte of an RGB565 pixel holds the blue channel and the low three bits of
//! green.
//!
//! Scaling. vImage widens a channel by the exact-rounding rule
//! `(v * 255 + half) / max` and narrows it by `(v * max + 127) / 255`, with
//! `max` 31 for a 5-bit field, 63 for a 6-bit field, and 1 for the alpha bit
//! (so 8-bit alpha >= 128 becomes 1, and a 1-bit alpha widens to 0 or 255).
//! Narrowing to 5 or 6 bits is lossy: a widen-then-narrow round trip through
//! 8 bits is exact, but narrow-then-widen is not.
//!
//! Alpha is never premultiplied or unpremultiplied by anything in this file. A
//! conversion that drops alpha (`*toRGB565`) simply discards it; if you need
//! flattening or unpremultiplication, do it in an 8-bit format first.
//!
//! Dithering. The `*Dithered` entry points take a `Dither` method. vImage's
//! documentation for the packed-16 encoders asks for `.ordered` or
//! `.ordered_reproducible`, and it means it: the four `*toRGB565_dithered`
//! entry points and the ARGB1555 / RGBA5551 dithered encoders all reject
//! `.none` with `kvImageInvalidParameter` (-21773), verified by the tests
//! below. Only `rgb565ToARGB1555` and `rgb565ToRGBA5551`, whose dither argument
//! is not part of a `_dithered` entry point, accept `.none` and then round to
//! nearest. The `tempBuffer` argument may be null, in which case vImage
//! allocates any scratch space it needs itself.
//!
//! None of these functions operate in place, except the 8888-to-packed
//! encoders (`argb8888ToARGB1555`, `rgba8888ToRGBA5551`, `*toRGB565` and their
//! dithered forms), which allow `src.data == dest.data` when
//! `src.rowBytes >= dest.rowBytes`.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const vImage_Flags = types.vImage_Flags;
const Error = types.Error;
const check = types.check;
const Pixel_8 = types.Pixel_8;
const Flags = types.Flags;
const Options = types.Options;

// ============================================================================
// Dither methods
// ============================================================================

/// Dithering method for the `_dithered` conversions, matching the anonymous
/// `kvImageConvert_Dither*` enum in Conversion.h.
///
/// It is non-exhaustive because the ordered methods may be OR-ed with a noise
/// shaping bit; use `orderedUniformBlue` to build that value rather than
/// writing the bit by hand.
pub const Dither = enum(c_int) {
    /// Round to nearest representable value. Deterministic.
    none = 0,
    /// Add pre-computed blue noise before rounding. The offset into the noise
    /// is randomised per call, so results differ between runs.
    ordered = 1,
    /// Like `ordered`, but the noise offset is the same on every call, so the
    /// output is reproducible.
    ordered_reproducible = 2,
    /// Floyd-Steinberg error diffusion.
    floyd_steinberg = 3,
    /// Atkinson error diffusion.
    atkinson = 4,
    _,

    /// `kvImageConvert_OrderedUniformBlue`. OR-ed into an ordered method to
    /// distribute the dither noise uniformly instead of the default gaussian.
    /// Better colour fidelity, visibly noisier image.
    pub const uniform_blue_bit: c_int = 1 << 28;

    /// `kvImageConvert_OrderedGaussianBlue` is zero, i.e. the default shaping.
    pub const gaussian_blue_bit: c_int = 0;

    /// Return `self` with the uniform-blue noise shaping bit set. Only
    /// meaningful for `.ordered` and `.ordered_reproducible`.
    pub fn orderedUniformBlue(self: Dither) Dither {
        return @enumFromInt(@intFromEnum(self) | uniform_blue_bit);
    }
};

// ============================================================================
// ARGB1555 <-> 8-bit
// ============================================================================

/// ARGB1555 -> ARGB8888.
///
/// `alpha = A * 255`, and each 5-bit channel widens as `(v * 255 + 15) / 31`.
/// Does not work in place; `dest` is 4 bytes per pixel.
pub fn argb1555ToARGB8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_ARGB1555toARGB8888(src, dest, flags.bits()));
}

/// ARGB1555 -> four Planar8 buffers, one per channel.
///
/// All four destinations must have the same dimensions, or the call returns
/// `BufferSizeMismatch`. Does not work in place.
pub fn argb1555ToPlanar8(
    src: *const vImage_Buffer,
    destA: *const vImage_Buffer,
    destR: *const vImage_Buffer,
    destG: *const vImage_Buffer,
    destB: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB1555toPlanar8(src, destA, destR, destG, destB, flags.bits()));
}

/// Four Planar8 channel buffers -> ARGB1555.
///
/// Each 8-bit channel narrows as `(v * 31 + 127) / 255`, and the alpha plane
/// narrows to one bit as `(a + 127) / 255`. All four sources must have the same
/// dimensions. Does not work in place.
pub fn planar8ToARGB1555(
    srcA: *const vImage_Buffer,
    srcR: *const vImage_Buffer,
    srcG: *const vImage_Buffer,
    srcB: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_Planar8toARGB1555(srcA, srcR, srcG, srcB, dest, flags.bits()));
}

/// ARGB8888 -> ARGB1555, rounding to nearest.
///
/// `dest = (a << 15) | (r << 10) | (g << 5) | b` with the narrowing rule
/// described in the module comment. Works in place when `src.data == dest.data`
/// and `src.rowBytes >= dest.rowBytes`.
pub fn argb8888ToARGB1555(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_ARGB8888toARGB1555(src, dest, flags.bits()));
}

/// ARGB8888 -> ARGB1555 with dithering instead of round-to-nearest.
///
/// `temp_buffer` may be null, in which case vImage allocates its own scratch.
/// `dither` must be an ordered method: `.none` returns `InvalidParameter`.
pub fn argb8888ToARGB1555Dithered(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    temp_buffer: ?*anyopaque,
    dither: Dither,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB8888toARGB1555_dithered(src, dest, temp_buffer, @intFromEnum(dither), flags.bits()));
}

// ============================================================================
// RGBA5551 <-> 8-bit
// ============================================================================

/// RGBA5551 -> RGBA8888.
///
/// Each 5-bit channel widens as `(v * 255 + 15) / 31`; the alpha bit becomes
/// 0 or 255. Does not work in place.
pub fn rgba5551ToRGBA8888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_RGBA5551toRGBA8888(src, dest, flags.bits()));
}

/// RGBA8888 -> RGBA5551, rounding to nearest.
///
/// `dest = (r << 11) | (g << 6) | (b << 1) | a`. Works in place under the same
/// conditions as `argb8888ToARGB1555`.
pub fn rgba8888ToRGBA5551(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_RGBA8888toRGBA5551(src, dest, flags.bits()));
}

/// RGBA8888 -> RGBA5551 with dithering. `temp_buffer` may be null.
pub fn rgba8888ToRGBA5551Dithered(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    temp_buffer: ?*anyopaque,
    dither: Dither,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGBA8888toRGBA5551_dithered(src, dest, temp_buffer, @intFromEnum(dither), flags.bits()));
}

// ============================================================================
// RGB565 -> 8-bit
// ============================================================================

/// RGB565 -> ARGB8888, with a constant alpha for every pixel.
///
/// Red and blue widen as `(v * 255 + 15) / 31`, green as `(v * 255 + 31) / 63`.
/// Does not work in place.
pub fn rgb565ToARGB8888(alpha: Pixel_8, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_RGB565toARGB8888(alpha, src, dest, flags.bits()));
}

/// RGB565 -> RGBA8888, with a constant alpha for every pixel.
pub fn rgb565ToRGBA8888(alpha: Pixel_8, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_RGB565toRGBA8888(alpha, src, dest, flags.bits()));
}

/// RGB565 -> BGRA8888, with a constant alpha for every pixel. The destination
/// bytes are ordered B, G, R, A.
pub fn rgb565ToBGRA8888(alpha: Pixel_8, src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_RGB565toBGRA8888(alpha, src, dest, flags.bits()));
}

/// RGB565 -> RGB888. The destination is *three* bytes per pixel, so
/// `dest.rowBytes` must be at least `3 * width`. Does not work in place.
pub fn rgb565ToRGB888(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_RGB565toRGB888(src, dest, flags.bits()));
}

/// RGB565 -> three Planar8 buffers (R, G, B). There is no alpha to recover.
pub fn rgb565ToPlanar8(
    src: *const vImage_Buffer,
    destR: *const vImage_Buffer,
    destG: *const vImage_Buffer,
    destB: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGB565toPlanar8(src, destR, destG, destB, flags.bits()));
}

// ============================================================================
// 8-bit -> RGB565
// ============================================================================

/// ARGB8888 -> RGB565. Alpha is discarded, not flattened.
///
/// `dest = (r << 11) | (g << 5) | b`, with red/blue narrowed by
/// `(v * 31 + 127) / 255` and green by `(v * 63 + 127) / 255`. Works in place
/// when `src.data == dest.data` and `src.rowBytes >= dest.rowBytes`.
pub fn argb8888ToRGB565(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_ARGB8888toRGB565(src, dest, flags.bits()));
}

/// RGBA8888 -> RGB565. Alpha is discarded, not flattened.
pub fn rgba8888ToRGB565(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_RGBA8888toRGB565(src, dest, flags.bits()));
}

/// BGRA8888 -> RGB565. The source bytes are ordered B, G, R, A; the packed
/// result still has red in bits 15..11.
pub fn bgra8888ToRGB565(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_BGRA8888toRGB565(src, dest, flags.bits()));
}

/// Three Planar8 channel buffers (R, G, B) -> RGB565.
///
/// All three sources must have the same dimensions. Does not work in place.
pub fn planar8ToRGB565(
    srcR: *const vImage_Buffer,
    srcG: *const vImage_Buffer,
    srcB: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_Planar8toRGB565(srcR, srcG, srcB, dest, flags.bits()));
}

/// RGB888 -> RGB565 with dithering. The source is three bytes per pixel.
/// `temp_buffer` may be null.
pub fn rgb888ToRGB565Dithered(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    temp_buffer: ?*anyopaque,
    dither: Dither,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGB888toRGB565_dithered(src, dest, temp_buffer, @intFromEnum(dither), flags.bits()));
}

/// ARGB8888 -> RGB565 with dithering. Alpha is discarded. `temp_buffer` may be
/// null.
pub fn argb8888ToRGB565Dithered(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    temp_buffer: ?*anyopaque,
    dither: Dither,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB8888toRGB565_dithered(src, dest, temp_buffer, @intFromEnum(dither), flags.bits()));
}

/// RGBA8888 -> RGB565 with dithering. Alpha is discarded. `temp_buffer` may be
/// null.
pub fn rgba8888ToRGB565Dithered(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    temp_buffer: ?*anyopaque,
    dither: Dither,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGBA8888toRGB565_dithered(src, dest, temp_buffer, @intFromEnum(dither), flags.bits()));
}

/// BGRA8888 -> RGB565 with dithering. Alpha is discarded. `temp_buffer` may be
/// null.
pub fn bgra8888ToRGB565Dithered(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    temp_buffer: ?*anyopaque,
    dither: Dither,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_BGRA8888toRGB565_dithered(src, dest, temp_buffer, @intFromEnum(dither), flags.bits()));
}

// ============================================================================
// Packed 16-bit <-> packed 16-bit
// ============================================================================

/// ARGB1555 -> RGB565. Alpha is dropped and the 5-bit green is widened to six
/// bits; no channel loses precision, so no dither method is needed.
pub fn argb1555ToRGB565(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_ARGB1555toRGB565(src, dest, flags.bits()));
}

/// RGBA5551 -> RGB565. Alpha is dropped and green is widened to six bits.
pub fn rgba5551ToRGB565(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: Options) Error!usize {
    return check(c.vImageConvert_RGBA5551toRGB565(src, dest, flags.bits()));
}

/// RGB565 -> ARGB1555. The new alpha bit is set to 1 (opaque).
///
/// Green loses a bit, so `dither` selects how that bit is dropped; `.none`
/// rounds to nearest and is deterministic.
pub fn rgb565ToARGB1555(src: *const vImage_Buffer, dest: *const vImage_Buffer, dither: Dither, flags: Options) Error!usize {
    return check(c.vImageConvert_RGB565toARGB1555(src, dest, @intFromEnum(dither), flags.bits()));
}

/// RGB565 -> RGBA5551. The new alpha bit is set to 1 (opaque).
///
/// Green loses a bit, so `dither` selects how that bit is dropped; `.none`
/// rounds to nearest and is deterministic.
pub fn rgb565ToRGBA5551(src: *const vImage_Buffer, dest: *const vImage_Buffer, dither: Dither, flags: Options) Error!usize {
    return check(c.vImageConvert_RGB565toRGBA5551(src, dest, @intFromEnum(dither), flags.bits()));
}

// ============================================================================
// Test helpers
// ============================================================================
//
// Every buffer is allocated with padded rowBytes and the padding filled with a
// sentinel, so a wrapper that got a stride or an element size wrong shows up as
// a wrong pixel value rather than silently reading contiguous data.

const testing = std.testing;

const TestBuffer = struct {
    buf: vImage_Buffer,
    mem: []align(16) u8,

    fn free(self: TestBuffer, allocator: std.mem.Allocator) void {
        allocator.free(self.mem);
    }
};

/// Allocate a buffer of `height * width` elements of type `T` (u8 for Planar8,
/// u16 for a packed format, [4]u8 for a 8888 format, [3]u8 for RGB888), with
/// one spare element per row of stride padding.
fn makeBuffer(comptime T: type, allocator: std.mem.Allocator, height: usize, width: usize, values: []const T) !TestBuffer {
    const row_bytes = (width + 1) * @sizeOf(T);
    const mem = try allocator.alignedAlloc(u8, .@"16", row_bytes * height);
    @memset(mem, 0xAA); // sentinel: must never be read back as pixel data
    for (0..height) |y| {
        for (0..width) |x| {
            const value = values[y * width + x];
            @memcpy(mem[y * row_bytes + x * @sizeOf(T) ..][0..@sizeOf(T)], std.mem.asBytes(&value));
        }
    }
    return .{
        .buf = .{ .data = mem.ptr, .height = height, .width = width, .rowBytes = row_bytes },
        .mem = mem,
    };
}

/// Allocate a destination buffer of `T` elements, zero-filled inside the ROI
/// and sentinel-filled in the stride padding.
fn makeDest(comptime T: type, allocator: std.mem.Allocator, height: usize, width: usize) !TestBuffer {
    const zeros = try allocator.alloc(T, height * width);
    defer allocator.free(zeros);
    @memset(zeros, std.mem.zeroes(T));
    return makeBuffer(T, allocator, height, width, zeros);
}

fn pixel(comptime T: type, b: TestBuffer, y: usize, x: usize) T {
    const base: [*]const u8 = @ptrCast(b.mem.ptr);
    var out: T = undefined;
    @memcpy(std.mem.asBytes(&out), base[y * b.buf.rowBytes + x * @sizeOf(T) ..][0..@sizeOf(T)]);
    return out;
}

/// Pack the fields of an ARGB1555 pixel the way the header documents it.
fn argb1555(a: u16, r: u16, g: u16, b: u16) u16 {
    return (a << 15) | (r << 10) | (g << 5) | b;
}

/// Pack the fields of an RGBA5551 pixel the way the header documents it.
fn rgba5551(r: u16, g: u16, b: u16, a: u16) u16 {
    return (r << 11) | (g << 6) | (b << 1) | a;
}

/// Pack the fields of an RGB565 pixel the way the header documents it.
fn rgb565(r: u16, g: u16, b: u16) u16 {
    return (r << 11) | (g << 5) | b;
}

/// Assert that every named bit field of `got` is within `tolerance` of the same
/// field of `want`. Each field is a `.{ shift, mask }` pair. Used for dithered
/// conversions, whose exact output is not hand-computable but whose per-channel
/// error is bounded by one step of the destination format.
fn expectFieldsClose(want: u16, got: u16, fields: []const struct { u16, u16 }, tolerance: i32) !void {
    for (fields) |field| {
        const shift, const mask = field;
        const w: i32 = @intCast((want >> @intCast(shift)) & mask);
        const g: i32 = @intCast((got >> @intCast(shift)) & mask);
        if (@abs(w - g) > tolerance) {
            std.debug.print("field shift={d} mask=0x{X}: want {d}, got {d} (want pixel 0x{X:0>4}, got 0x{X:0>4})\n", .{ shift, mask, w, g, want, got });
            return error.TestExpectedApproxEq;
        }
    }
}

// ============================================================================
// Tests: ARGB1555
// ============================================================================

test "argb8888ToARGB1555 produces the exact documented bit pattern" {
    const allocator = testing.allocator;
    // {A,R,G,B} = {255, 255, 0, 132}
    //   a = (255 + 127)/255       = 1
    //   r = (255*31 + 127)/255    = 31
    //   g = (0*31   + 127)/255    = 0
    //   b = (132*31 + 127)/255    = 16
    // packed = (1<<15)|(31<<10)|(0<<5)|16 = 0xFC10
    const src = try makeBuffer([4]u8, allocator, 1, 2, &[_][4]u8{ .{ 255, 255, 0, 132 }, .{ 0, 0, 0, 0 } });
    defer src.free(allocator);
    const dest = try makeDest(u16, allocator, 1, 2);
    defer dest.free(allocator);

    _ = try argb8888ToARGB1555(&src.buf, &dest.buf, .{});
    try testing.expectEqual(@as(u16, 0xFC10), pixel(u16, dest, 0, 0));
    try testing.expectEqual(argb1555(1, 31, 0, 16), pixel(u16, dest, 0, 0));
    try testing.expectEqual(@as(u16, 0), pixel(u16, dest, 0, 1));
}

test "argb1555ToARGB8888 round trips the values that survive narrowing" {
    const allocator = testing.allocator;
    // 0xFC10 = a:1 r:31 g:0 b:16
    //   alpha = 1*255            = 255
    //   red   = (31*255 + 15)/31 = 255
    //   green = 0
    //   blue  = (16*255 + 15)/31 = 132
    const src = try makeBuffer(u16, allocator, 1, 1, &[_]u16{argb1555(1, 31, 0, 16)});
    defer src.free(allocator);
    const dest = try makeDest([4]u8, allocator, 1, 1);
    defer dest.free(allocator);

    _ = try argb1555ToARGB8888(&src.buf, &dest.buf, .{});
    try testing.expectEqual([4]u8{ 255, 255, 0, 132 }, pixel([4]u8, dest, 0, 0));
}

test "argb1555ToPlanar8 and planar8ToARGB1555 round trip through four planes" {
    const allocator = testing.allocator;
    const src = try makeBuffer(u16, allocator, 1, 2, &[_]u16{ argb1555(1, 31, 0, 16), argb1555(0, 6, 13, 25) });
    defer src.free(allocator);
    const a = try makeDest(u8, allocator, 1, 2);
    defer a.free(allocator);
    const r = try makeDest(u8, allocator, 1, 2);
    defer r.free(allocator);
    const g = try makeDest(u8, allocator, 1, 2);
    defer g.free(allocator);
    const b = try makeDest(u8, allocator, 1, 2);
    defer b.free(allocator);

    _ = try argb1555ToPlanar8(&src.buf, &a.buf, &r.buf, &g.buf, &b.buf, .{});
    // pixel 0: a=1 -> 255, r=31 -> 255, g=0 -> 0, b=16 -> (16*255+15)/31 = 132
    try testing.expectEqual(@as(u8, 255), pixel(u8, a, 0, 0));
    try testing.expectEqual(@as(u8, 255), pixel(u8, r, 0, 0));
    try testing.expectEqual(@as(u8, 0), pixel(u8, g, 0, 0));
    try testing.expectEqual(@as(u8, 132), pixel(u8, b, 0, 0));
    // pixel 1: a=0 -> 0, r=6 -> (6*255+15)/31 = 49, g=13 -> (13*255+15)/31 = 107,
    //          b=25 -> (25*255+15)/31 = 206
    try testing.expectEqual(@as(u8, 0), pixel(u8, a, 0, 1));
    try testing.expectEqual(@as(u8, 49), pixel(u8, r, 0, 1));
    try testing.expectEqual(@as(u8, 107), pixel(u8, g, 0, 1));
    try testing.expectEqual(@as(u8, 206), pixel(u8, b, 0, 1));

    // Back again: widen-then-narrow is exact, so the packed pixels return.
    const back = try makeDest(u16, allocator, 1, 2);
    defer back.free(allocator);
    _ = try planar8ToARGB1555(&a.buf, &r.buf, &g.buf, &b.buf, &back.buf, .{});
    try testing.expectEqual(pixel(u16, src, 0, 0), pixel(u16, back, 0, 0));
    try testing.expectEqual(pixel(u16, src, 0, 1), pixel(u16, back, 0, 1));
}

test "argb8888ToARGB1555Dithered rejects DitherNone with kvImageInvalidParameter" {
    // Conversion.h says the dither argument "should be kvImageConvert_DitherOrdered
    // or kvImageConvert_DitherOrderedReproducible". `.none` is not merely a no-op
    // here: the entry point rejects it with kvImageInvalidParameter (-21773).
    const allocator = testing.allocator;
    const src = try makeBuffer([4]u8, allocator, 1, 2, &[_][4]u8{ .{ 255, 255, 0, 132 }, .{ 0, 130, 77, 4 } });
    defer src.free(allocator);
    const dest = try makeDest(u16, allocator, 1, 2);
    defer dest.free(allocator);

    try testing.expectError(
        Error.InvalidParameter,
        argb8888ToARGB1555Dithered(&src.buf, &dest.buf, null, .none, .{}),
    );
}

test "argb8888ToARGB1555Dithered stays within one 5-bit step of the undithered encoder" {
    const allocator = testing.allocator;
    const colour = [4]u8{ 255, 255, 0, 132 };
    const src = try makeBuffer([4]u8, allocator, 2, 8, &([_][4]u8{colour} ** 16));
    defer src.free(allocator);
    const plain = try makeDest(u16, allocator, 2, 8);
    defer plain.free(allocator);
    const dithered = try makeDest(u16, allocator, 2, 8);
    defer dithered.free(allocator);
    const again = try makeDest(u16, allocator, 2, 8);
    defer again.free(allocator);

    _ = try argb8888ToARGB1555(&src.buf, &plain.buf, .{});
    _ = try argb8888ToARGB1555Dithered(&src.buf, &dithered.buf, null, .ordered_reproducible, .{});
    _ = try argb8888ToARGB1555Dithered(&src.buf, &again.buf, null, .ordered_reproducible, .{});

    for (0..2) |y| for (0..8) |x| {
        const want = pixel(u16, plain, y, x);
        const got = pixel(u16, dithered, y, x);
        // ordered_reproducible uses a fixed noise offset, so it is repeatable.
        try testing.expectEqual(got, pixel(u16, again, y, x));
        try testing.expectEqual(want >> 15, got >> 15); // alpha is one bit: never dithered off
        try expectFieldsClose(want, got, &.{ .{ 10, 0x1F }, .{ 5, 0x1F }, .{ 0, 0x1F } }, 1);
    };
}

// ============================================================================
// Tests: RGBA5551
// ============================================================================

test "rgba8888ToRGBA5551 produces the exact documented bit pattern" {
    const allocator = testing.allocator;
    // {R,G,B,A} = {8, 200, 255, 255}
    //   r = (8*31   + 127)/255 = 1
    //   g = (200*31 + 127)/255 = 24
    //   b = (255*31 + 127)/255 = 31
    //   a = (255    + 127)/255 = 1
    // packed = (1<<11)|(24<<6)|(31<<1)|1 = 0x0E3F
    const src = try makeBuffer([4]u8, allocator, 1, 1, &[_][4]u8{.{ 8, 200, 255, 255 }});
    defer src.free(allocator);
    const dest = try makeDest(u16, allocator, 1, 1);
    defer dest.free(allocator);

    _ = try rgba8888ToRGBA5551(&src.buf, &dest.buf, .{});
    try testing.expectEqual(@as(u16, 0x0E3F), pixel(u16, dest, 0, 0));
    try testing.expectEqual(rgba5551(1, 24, 31, 1), pixel(u16, dest, 0, 0));
}

test "rgba5551ToRGBA8888 widening is lossy within one 5-bit step" {
    const allocator = testing.allocator;
    const src = try makeBuffer(u16, allocator, 1, 1, &[_]u16{rgba5551(1, 24, 31, 1)});
    defer src.free(allocator);
    const dest = try makeDest([4]u8, allocator, 1, 1);
    defer dest.free(allocator);

    _ = try rgba5551ToRGBA8888(&src.buf, &dest.buf, .{});
    //   r = (1*255  + 15)/31 = 8
    //   g = (24*255 + 15)/31 = 197   (the original 200 is not recoverable)
    //   b = (31*255 + 15)/31 = 255
    //   a = 1*255            = 255
    const got = pixel([4]u8, dest, 0, 0);
    try testing.expectEqual([4]u8{ 8, 197, 255, 255 }, got);
    // One 5-bit step is 255/31 ~ 8.2, so the green error stays well inside it.
    try testing.expect(@abs(@as(i32, got[1]) - 200) <= 8);
}

test "rgba8888ToRGBA5551Dithered rejects DitherNone with kvImageInvalidParameter" {
    const allocator = testing.allocator;
    const src = try makeBuffer([4]u8, allocator, 1, 2, &[_][4]u8{ .{ 8, 200, 255, 255 }, .{ 90, 17, 240, 0 } });
    defer src.free(allocator);
    const dest = try makeDest(u16, allocator, 1, 2);
    defer dest.free(allocator);

    // Same constraint as the ARGB1555 encoder: kvImageInvalidParameter (-21773).
    try testing.expectError(
        Error.InvalidParameter,
        rgba8888ToRGBA5551Dithered(&src.buf, &dest.buf, null, .none, .{}),
    );
}

test "rgba8888ToRGBA5551Dithered stays within one 5-bit step of the undithered encoder" {
    const allocator = testing.allocator;
    const colour = [4]u8{ 8, 200, 255, 255 };
    const src = try makeBuffer([4]u8, allocator, 2, 8, &([_][4]u8{colour} ** 16));
    defer src.free(allocator);
    const plain = try makeDest(u16, allocator, 2, 8);
    defer plain.free(allocator);
    const dithered = try makeDest(u16, allocator, 2, 8);
    defer dithered.free(allocator);

    _ = try rgba8888ToRGBA5551(&src.buf, &plain.buf, .{});
    _ = try rgba8888ToRGBA5551Dithered(&src.buf, &dithered.buf, null, .ordered_reproducible, .{});

    for (0..2) |y| for (0..8) |x| {
        const want = pixel(u16, plain, y, x);
        const got = pixel(u16, dithered, y, x);
        try testing.expectEqual(want & 1, got & 1); // alpha bit preserved
        try expectFieldsClose(want, got, &.{ .{ 11, 0x1F }, .{ 6, 0x1F }, .{ 1, 0x1F } }, 1);
    };
}

// ============================================================================
// Tests: RGB565
// ============================================================================

test "argb8888/rgba8888/bgra8888 to RGB565 agree on the same colour" {
    const allocator = testing.allocator;
    // colour R=255 G=200 B=8:
    //   r = (255*31 + 127)/255 = 31
    //   g = (200*63 + 127)/255 = 49
    //   b = (8*31   + 127)/255 = 1
    // packed = (31<<11)|(49<<5)|1 = 0xFE21
    const expected = rgb565(31, 49, 1);
    try testing.expectEqual(@as(u16, 0xFE21), expected);

    const argb = try makeBuffer([4]u8, allocator, 1, 1, &[_][4]u8{.{ 255, 255, 200, 8 }});
    defer argb.free(allocator);
    const rgba = try makeBuffer([4]u8, allocator, 1, 1, &[_][4]u8{.{ 255, 200, 8, 255 }});
    defer rgba.free(allocator);
    const bgra = try makeBuffer([4]u8, allocator, 1, 1, &[_][4]u8{.{ 8, 200, 255, 255 }});
    defer bgra.free(allocator);

    inline for (.{
        .{ argb, argb8888ToRGB565 },
        .{ rgba, rgba8888ToRGB565 },
        .{ bgra, bgra8888ToRGB565 },
    }) |pair| {
        const dest = try makeDest(u16, allocator, 1, 1);
        defer dest.free(allocator);
        _ = try pair[1](&pair[0].buf, &dest.buf, .{});
        try testing.expectEqual(expected, pixel(u16, dest, 0, 0));
    }
}

test "rgb565 to ARGB8888/RGBA8888/BGRA8888 widens green from six bits and injects alpha" {
    const allocator = testing.allocator;
    const src = try makeBuffer(u16, allocator, 1, 1, &[_]u16{rgb565(31, 49, 1)});
    defer src.free(allocator);
    //   red   = (31*255 + 15)/31 = 255
    //   green = (49*255 + 31)/63 = 198   (200 is not recoverable from six bits)
    //   blue  = (1*255  + 15)/31 = 8
    const alpha: Pixel_8 = 0x77;

    {
        const dest = try makeDest([4]u8, allocator, 1, 1);
        defer dest.free(allocator);
        _ = try rgb565ToARGB8888(alpha, &src.buf, &dest.buf, .{});
        try testing.expectEqual([4]u8{ 0x77, 255, 198, 8 }, pixel([4]u8, dest, 0, 0));
    }
    {
        const dest = try makeDest([4]u8, allocator, 1, 1);
        defer dest.free(allocator);
        _ = try rgb565ToRGBA8888(alpha, &src.buf, &dest.buf, .{});
        try testing.expectEqual([4]u8{ 255, 198, 8, 0x77 }, pixel([4]u8, dest, 0, 0));
    }
    {
        const dest = try makeDest([4]u8, allocator, 1, 1);
        defer dest.free(allocator);
        _ = try rgb565ToBGRA8888(alpha, &src.buf, &dest.buf, .{});
        try testing.expectEqual([4]u8{ 8, 198, 255, 0x77 }, pixel([4]u8, dest, 0, 0));
    }
}

test "rgb565ToRGB888 writes three bytes per pixel" {
    const allocator = testing.allocator;
    const src = try makeBuffer(u16, allocator, 1, 2, &[_]u16{ rgb565(31, 49, 1), rgb565(0, 63, 31) });
    defer src.free(allocator);
    const dest = try makeDest([3]u8, allocator, 1, 2);
    defer dest.free(allocator);

    _ = try rgb565ToRGB888(&src.buf, &dest.buf, .{});
    try testing.expectEqual([3]u8{ 255, 198, 8 }, pixel([3]u8, dest, 0, 0));
    try testing.expectEqual([3]u8{ 0, 255, 255 }, pixel([3]u8, dest, 0, 1));
}

test "rgb565ToPlanar8 and planar8ToRGB565 round trip" {
    const allocator = testing.allocator;
    const src = try makeBuffer(u16, allocator, 1, 2, &[_]u16{ rgb565(31, 49, 1), rgb565(6, 26, 25) });
    defer src.free(allocator);
    const r = try makeDest(u8, allocator, 1, 2);
    defer r.free(allocator);
    const g = try makeDest(u8, allocator, 1, 2);
    defer g.free(allocator);
    const b = try makeDest(u8, allocator, 1, 2);
    defer b.free(allocator);

    _ = try rgb565ToPlanar8(&src.buf, &r.buf, &g.buf, &b.buf, .{});
    try testing.expectEqual(@as(u8, 255), pixel(u8, r, 0, 0));
    try testing.expectEqual(@as(u8, 198), pixel(u8, g, 0, 0));
    try testing.expectEqual(@as(u8, 8), pixel(u8, b, 0, 0));
    // r=6  -> (6*255  + 15)/31 = 49
    // g=26 -> (26*255 + 31)/63 = 105
    // b=25 -> (25*255 + 15)/31 = 206
    try testing.expectEqual(@as(u8, 49), pixel(u8, r, 0, 1));
    try testing.expectEqual(@as(u8, 105), pixel(u8, g, 0, 1));
    try testing.expectEqual(@as(u8, 206), pixel(u8, b, 0, 1));

    const back = try makeDest(u16, allocator, 1, 2);
    defer back.free(allocator);
    _ = try planar8ToRGB565(&r.buf, &g.buf, &b.buf, &back.buf, .{});
    try testing.expectEqual(pixel(u16, src, 0, 0), pixel(u16, back, 0, 0));
    try testing.expectEqual(pixel(u16, src, 0, 1), pixel(u16, back, 0, 1));
}

test "RGB565 dithered encoders reject DitherNone with kvImageInvalidParameter" {
    const allocator = testing.allocator;
    const rgb = try makeBuffer([3]u8, allocator, 1, 1, &[_][3]u8{.{ 255, 200, 8 }});
    defer rgb.free(allocator);
    const rgba = try makeBuffer([4]u8, allocator, 1, 1, &[_][4]u8{.{ 255, 200, 8, 255 }});
    defer rgba.free(allocator);
    const dest = try makeDest(u16, allocator, 1, 1);
    defer dest.free(allocator);

    // All four RGB565 dithered encoders require an ordered method; `.none`
    // fails with kvImageInvalidParameter (-21773).
    try testing.expectError(
        Error.InvalidParameter,
        rgb888ToRGB565Dithered(&rgb.buf, &dest.buf, null, .none, .{}),
    );
    try testing.expectError(
        Error.InvalidParameter,
        argb8888ToRGB565Dithered(&rgba.buf, &dest.buf, null, .none, .{}),
    );
    try testing.expectError(
        Error.InvalidParameter,
        rgba8888ToRGB565Dithered(&rgba.buf, &dest.buf, null, .none, .{}),
    );
    try testing.expectError(
        Error.InvalidParameter,
        bgra8888ToRGB565Dithered(&rgba.buf, &dest.buf, null, .none, .{}),
    );
}

test "RGB565 dithered encoders read their channels in the right order (within one step)" {
    const allocator = testing.allocator;
    const width = 8;
    const height = 2;
    const n = width * height;
    // R=255 G=200 B=8 is deliberately asymmetric: an encoder that read the
    // source channels in the wrong order would put 1 in bits 15..11 instead
    // of 31, which no dither can excuse.
    const rgb = try makeBuffer([3]u8, allocator, height, width, &([_][3]u8{.{ 255, 200, 8 }} ** n));
    defer rgb.free(allocator);
    const argb = try makeBuffer([4]u8, allocator, height, width, &([_][4]u8{.{ 255, 255, 200, 8 }} ** n));
    defer argb.free(allocator);
    const rgba = try makeBuffer([4]u8, allocator, height, width, &([_][4]u8{.{ 255, 200, 8, 255 }} ** n));
    defer rgba.free(allocator);
    const bgra = try makeBuffer([4]u8, allocator, height, width, &([_][4]u8{.{ 8, 200, 255, 255 }} ** n));
    defer bgra.free(allocator);

    // Reference: the plain (round to nearest) ARGB8888 encoder.
    //   r = (255*31 + 127)/255 = 31, g = (200*63 + 127)/255 = 49, b = (8*31 + 127)/255 = 1
    const reference = rgb565(31, 49, 1);
    const plain = try makeDest(u16, allocator, height, width);
    defer plain.free(allocator);
    _ = try argb8888ToRGB565(&argb.buf, &plain.buf, .{});
    try testing.expectEqual(reference, pixel(u16, plain, 1, 5));

    inline for (.{
        .{ rgb, rgb888ToRGB565Dithered },
        .{ argb, argb8888ToRGB565Dithered },
        .{ rgba, rgba8888ToRGB565Dithered },
        .{ bgra, bgra8888ToRGB565Dithered },
    }) |pair| {
        const dest = try makeDest(u16, allocator, height, width);
        defer dest.free(allocator);
        _ = try pair[1](&pair[0].buf, &dest.buf, null, .ordered_reproducible, .{});
        for (0..height) |y| for (0..width) |x| {
            try expectFieldsClose(reference, pixel(u16, dest, y, x), &.{ .{ 11, 0x1F }, .{ 5, 0x3F }, .{ 0, 0x1F } }, 1);
        };
    }
}

// ============================================================================
// Tests: packed <-> packed
// ============================================================================

test "argb1555ToRGB565 and rgb565ToARGB1555 round trip when green is saturated" {
    const allocator = testing.allocator;
    // a=1 r=6 g=31 b=25. Green 31/31 widens to the saturated 63/63, so the
    // trip back is exact and no dithering choice can change the result.
    const src = try makeBuffer(u16, allocator, 1, 1, &[_]u16{argb1555(1, 6, 31, 25)});
    defer src.free(allocator);
    const mid = try makeDest(u16, allocator, 1, 1);
    defer mid.free(allocator);

    _ = try argb1555ToRGB565(&src.buf, &mid.buf, .{});
    try testing.expectEqual(rgb565(6, 63, 25), pixel(u16, mid, 0, 0));

    const back = try makeDest(u16, allocator, 1, 1);
    defer back.free(allocator);
    _ = try rgb565ToARGB1555(&mid.buf, &back.buf, .none, .{});
    // The alpha bit comes back as 1 (opaque) regardless of the input.
    try testing.expectEqual(argb1555(1, 6, 31, 25), pixel(u16, back, 0, 0));
}

test "rgba5551ToRGB565 and rgb565ToRGBA5551 round trip when green is saturated" {
    const allocator = testing.allocator;
    const src = try makeBuffer(u16, allocator, 1, 1, &[_]u16{rgba5551(6, 31, 25, 0)});
    defer src.free(allocator);
    const mid = try makeDest(u16, allocator, 1, 1);
    defer mid.free(allocator);

    _ = try rgba5551ToRGB565(&src.buf, &mid.buf, .{});
    try testing.expectEqual(rgb565(6, 63, 25), pixel(u16, mid, 0, 0));

    const back = try makeDest(u16, allocator, 1, 1);
    defer back.free(allocator);
    _ = try rgb565ToRGBA5551(&mid.buf, &back.buf, .none, .{});
    // Alpha was dropped by the first conversion and comes back as 1 (opaque),
    // so the source's alpha=0 is *not* recovered.
    try testing.expectEqual(rgba5551(6, 31, 25, 1), pixel(u16, back, 0, 0));
}

test "rgb565ToARGB1555 with DitherNone drops the low green bit within one step" {
    const allocator = testing.allocator;
    // Every 6-bit green, converted to 5 bits with no dithering, must land
    // within one 5-bit step of the ideal value g6*31/63.
    var greens: [64]u16 = undefined;
    for (0..64) |i| greens[i] = rgb565(0, @intCast(i), 0);
    const src = try makeBuffer(u16, allocator, 1, greens.len, &greens);
    defer src.free(allocator);
    const dest = try makeDest(u16, allocator, 1, greens.len);
    defer dest.free(allocator);

    _ = try rgb565ToARGB1555(&src.buf, &dest.buf, .none, .{});
    for (0..64) |i| {
        const got = pixel(u16, dest, 0, i);
        try testing.expectEqual(@as(u16, 1), got >> 15); // alpha forced opaque
        const g5: i32 = @intCast((got >> 5) & 0x1F);
        const ideal = @divFloor(@as(i32, @intCast(i)) * 31 + 31, 63);
        try testing.expect(@abs(g5 - ideal) <= 1);
    }
}

test "Dither constants match the kvImageConvert_Dither* values" {
    try testing.expectEqual(@as(c_int, 0), @intFromEnum(Dither.none));
    try testing.expectEqual(@as(c_int, 1), @intFromEnum(Dither.ordered));
    try testing.expectEqual(@as(c_int, 2), @intFromEnum(Dither.ordered_reproducible));
    try testing.expectEqual(@as(c_int, 3), @intFromEnum(Dither.floyd_steinberg));
    try testing.expectEqual(@as(c_int, 4), @intFromEnum(Dither.atkinson));
    try testing.expectEqual(@as(c_int, 0x10000001), @intFromEnum(Dither.ordered.orderedUniformBlue()));
}
