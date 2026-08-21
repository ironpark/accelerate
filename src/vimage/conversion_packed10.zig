//! 32-bit packed pixels with 10 bits per colour channel: ARGB2101010,
//! XRGB2101010 and RGBA1010102.
//!
//! All three formats store one pixel per 32-bit word, so a buffer row is
//! `width * 4` bytes and `vImage_Buffer.data` must be at least 4-byte aligned.
//! The `vImage_Buffer.width` field counts *pixels*, not channels.
//!
//! Bit layout, expressed on the 32-bit value once it has been loaded in the
//! order the format specifies:
//!
//!   ARGB2101010   A: bits 31..30   R: 29..20   G: 19..10   B: 9..0
//!   XRGB2101010   X: bits 31..30   R: 29..20   G: 19..10   B: 9..0
//!   RGBA1010102   R: bits 31..22   G: 21..12   B: 11..2    A: 1..0
//!
//! The two families differ in *byte order*, and the header's per-pixel
//! pseudo-code is inconsistent about it (some entry points show a bare load,
//! others show `ntohl`). Measured against the shipping library on
//! little-endian arm64:
//!
//!   * (X|A)RGB2101010 words are **host order**. The word above is exactly
//!     what a `*u32` load yields, so opaque white is the `u32` `0xFFF00000`.
//!   * RGBA1010102 words are **big endian**. The word above is the value
//!     *after* `@byteSwap`, so opaque red is `@byteSwap(@as(u32, 0xFFC00003))`
//!     == `0x0300C0FF` in memory. `packRGBA1010102` below does that for you.
//!
//! Alpha is only 2 bits wide, i.e. four levels. Converting 8-bit alpha out and
//! back is therefore lossy in general (255 -> 3 -> 255 and 0 -> 0 -> 0 are the
//! exact cases). `XRGB2101010` ignores the top two bits entirely on read and
//! writes them as zero; the `xrgb*` readers take the alpha to synthesise as an
//! explicit argument instead.
//!
//! Every entry point takes a `RGB101010RangeMin`/`RGB101010RangeMax` pair that
//! describes the encoded range of the 10-bit colour channels. Use
//! `full_range_min`/`full_range_max` (0 and 1023) for full-range data and
//! e.g. 64/940 for 10-bit video range. `range10 = max - min`; reading is
//! `(v10 - min) * SCALE / range10` and writing is the inverse, with
//! `SCALE` = 255 for 8888, 65535 for 16U, 4096 for 16Q12 and 1.0 for float.
//! Passing `min > max`, `min < 0` or `max > 1023` yields
//! `kvImageInvalidParameter`.
//!
//! The 16Q12 writers take a *second* pair, `RGB101010Min`/`RGB101010Max`,
//! which is the hard clamp applied after scaling. 16Q12 is signed 4.12 fixed
//! point and can carry values outside [0, 1], so the scaled result can leave
//! the encoded range; these two arguments decide how much of that excursion
//! survives. For full range, pass 0 and 1023; for video range you would
//! typically pass the wider 4/1019.
//!
//! `permute_map` reorders the *four-channel* side of each conversion, never
//! the packed side: `.{0, 1, 2, 3}` (or `null`) is ARGB, `.{3, 2, 1, 0}` is
//! BGRA. Each of 0..3 must appear exactly once.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const Error = types.Error;
const check = types.check;
const vImage_Flags = types.vImage_Flags;
const Pixel_8 = types.Pixel_8;
const Pixel_F = types.Pixel_F;
const Pixel_16U = types.Pixel_16U;
const Pixel_16Q12 = types.Pixel_16Q12;
const Flags = types.Flags;
const Options = types.Options;

/// `RGB101010RangeMin` for full-range 10-bit data.
pub const full_range_min: i32 = 0;
/// `RGB101010RangeMax` for full-range 10-bit data.
pub const full_range_max: i32 = 1023;

/// The identity `permuteMap`, i.e. ARGB order. The C entry points accept a
/// NULL `permuteMap` to mean this, but `c.zig` declares the parameter
/// non-optional, so the wrappers below substitute a pointer to this constant
/// when the caller passes `null`.
const identity_permute: [4]u8 = .{ 0, 1, 2, 3 };

inline fn permuteOrIdentity(permute_map: ?*const [4]u8) *const [4]u8 {
    return permute_map orelse &identity_permute;
}

/// Assemble an ARGB2101010 / XRGB2101010 word ready to be stored through a
/// `*u32`. `a` is the 2-bit alpha (0..3); the colour channels are 10-bit.
pub fn packARGB2101010(a: u2, r: u10, g: u10, b: u10) u32 {
    return (@as(u32, a) << 30) | (@as(u32, r) << 20) | (@as(u32, g) << 10) | @as(u32, b);
}

/// Assemble an RGBA1010102 word ready to be stored through a `*u32`. The
/// result is byte-swapped, because vImage reads this format big-endian.
pub fn packRGBA1010102(r: u10, g: u10, b: u10, a: u2) u32 {
    const big = (@as(u32, r) << 22) | (@as(u32, g) << 12) | (@as(u32, b) << 2) | @as(u32, a);
    return std.mem.nativeToBig(u32, big);
}

// ============================================================================
// RGBA1010102 (big-endian, alpha in the low 2 bits)
// ============================================================================

/// RGBA1010102 -> ARGB8888.
///
/// Colour channels are rescaled from `[range_min, range_max]` onto 0..255;
/// the 2-bit alpha is expanded as `(a * 255 + 1) / 3`, so 3 becomes 255.
/// `dest` is 4 bytes per pixel, same as `src`.
pub fn rgba1010102ToARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGBA1010102ToARGB8888(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGB8888 -> RGBA1010102.
///
/// The 8-bit alpha is quantised to two bits, so only 0 and 255 survive a
/// round trip unchanged.
pub fn argb8888ToRGBA1010102(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB8888ToRGBA1010102(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// RGBA1010102 -> ARGB16Q12.
///
/// `dest` is 8 bytes per pixel (four signed 4.12 fixed-point channels) and
/// must be at least 2-byte aligned. An encoded value equal to `range_max`
/// maps to 4096, i.e. 1.0.
pub fn rgba1010102ToARGB16Q12(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGBA1010102ToARGB16Q12(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGB16Q12 -> RGBA1010102.
///
/// `clamp_min`/`clamp_max` bound the 10-bit colour result after scaling; see
/// the module comment. Alpha is `clamp(0, (a16 * 3 + 2048) >> 12, 3)`, so
/// 4096 (1.0) becomes 3.
pub fn argb16Q12ToRGBA1010102(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    clamp_min: i32,
    clamp_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB16Q12ToRGBA1010102(src, dest, range_min, range_max, clamp_min, clamp_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// RGBA1010102 -> ARGB16U.
///
/// `dest` is 8 bytes per pixel. An encoded value equal to `range_max` maps to
/// 65535.
pub fn rgba1010102ToARGB16U(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_RGBA1010102ToARGB16U(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGB16U -> RGBA1010102. Alpha is quantised from 16 bits to 2.
pub fn argb16UToRGBA1010102(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB16UToRGBA1010102(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

// ============================================================================
// (X|A)RGB2101010 <-> ARGB8888
// ============================================================================

/// XRGB2101010 -> ARGB8888, substituting `alpha` for the ignored top 2 bits.
///
/// Whatever is in bits 31..30 of the source is discarded; the destination
/// alpha channel is filled with `alpha` verbatim (before `permute_map` is
/// applied, so it lands wherever the map sends channel 0).
pub fn xrgb2101010ToARGB8888(
    src: *const vImage_Buffer,
    alpha: Pixel_8,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_XRGB2101010ToARGB8888(src, alpha, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGB2101010 -> ARGB8888, expanding the 2-bit alpha as `(a * 255 + 1) / 3`.
pub fn argb2101010ToARGB8888(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB2101010ToARGB8888(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGB8888 -> XRGB2101010. The source alpha channel is dropped and the top
/// two bits of every destination word are written as zero.
pub fn argb8888ToXRGB2101010(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB8888ToXRGB2101010(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGB8888 -> ARGB2101010. Alpha is quantised to two bits.
pub fn argb8888ToARGB2101010(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB8888ToARGB2101010(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

// ============================================================================
// (X|A)RGB2101010 <-> ARGB16Q12
// ============================================================================

/// XRGB2101010 -> ARGB16Q12, substituting `alpha` (a raw 4.12 value, so 4096
/// is opaque) for the ignored top 2 bits.
pub fn xrgb2101010ToARGB16Q12(
    src: *const vImage_Buffer,
    alpha: Pixel_16Q12,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_XRGB2101010ToARGB16Q12(src, alpha, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGB2101010 -> ARGB16Q12. `range_max` maps to 4096 (1.0); values below
/// `range_min` become negative, which 4.12 fixed point can represent.
pub fn argb2101010ToARGB16Q12(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB2101010ToARGB16Q12(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGB16Q12 -> XRGB2101010. Top two bits of the destination are zero;
/// `clamp_min`/`clamp_max` bound the 10-bit colour result after scaling.
pub fn argb16Q12ToXRGB2101010(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    clamp_min: i32,
    clamp_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB16Q12ToXRGB2101010(src, dest, range_min, range_max, clamp_min, clamp_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGB16Q12 -> ARGB2101010. As `argb16Q12ToXRGB2101010`, but alpha is
/// encoded into the top two bits as `clamp(0, (a16 * 3 + 2048) >> 12, 3)`.
pub fn argb16Q12ToARGB2101010(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    clamp_min: i32,
    clamp_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB16Q12ToARGB2101010(src, dest, range_min, range_max, clamp_min, clamp_max, permuteOrIdentity(permute_map), flags.bits()));
}

// ============================================================================
// (X|A)RGB2101010 <-> ARGB16U
// ============================================================================

/// XRGB2101010 -> ARGB16U, substituting `alpha` for the ignored top 2 bits.
pub fn xrgb2101010ToARGB16U(
    src: *const vImage_Buffer,
    alpha: Pixel_16U,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_XRGB2101010ToARGB16U(src, alpha, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGB2101010 -> ARGB16U. `range_max` maps to 65535; the 2-bit alpha is
/// expanded to the full 16-bit range, so 3 becomes 65535.
pub fn argb2101010ToARGB16U(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB2101010ToARGB16U(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGB16U -> XRGB2101010. Source alpha is dropped; top two bits are zero.
pub fn argb16UToXRGB2101010(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB16UToXRGB2101010(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGB16U -> ARGB2101010. Alpha is quantised from 16 bits to 2.
pub fn argb16UToARGB2101010(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB16UToARGB2101010(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

// ============================================================================
// (X|A)RGB2101010 <-> ARGBFFFF
// ============================================================================

/// XRGB2101010 -> ARGBFFFF, substituting `alpha` for the ignored top 2 bits.
///
/// `dest` is 16 bytes per pixel. Colour is normalised to [0, 1] and clamped
/// there unless `flags` contains `kvImageDoNotClamp`.
pub fn xrgb2101010ToARGBFFFF(
    src: *const vImage_Buffer,
    alpha: Pixel_F,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_XRGB2101010ToARGBFFFF(src, alpha, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGB2101010 -> ARGBFFFF. The 2-bit alpha becomes `a / 3.0`.
pub fn argb2101010ToARGBFFFF(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB2101010ToARGBFFFF(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGBFFFF -> XRGB2101010. Source alpha is dropped; top two bits are zero.
/// Colour is clamped to [0, 1] before scaling unless `kvImageDoNotClamp`.
pub fn argbFFFFToXRGB2101010(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGBFFFFToXRGB2101010(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGBFFFF -> ARGB2101010. Alpha is encoded as `(int)(a * 3.0 + 0.5)`.
pub fn argbFFFFToARGB2101010(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGBFFFFToARGB2101010(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

// ============================================================================
// (X|A)RGB2101010 -> ARGB16F
// ============================================================================
//
// There is no ARGB16F -> 2101010 direction in Conversion.h; go via ARGBFFFF
// or ARGB16U if you need it.

/// XRGB2101010 -> ARGB16F, substituting `alpha` for the ignored top 2 bits.
///
/// `dest` is 8 bytes per pixel, four half floats. Note that `alpha` is an
/// `f32` even though the destination is half precision - that is what the C
/// prototype takes.
pub fn xrgb2101010ToARGB16F(
    src: *const vImage_Buffer,
    alpha: Pixel_F,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_XRGB2101010ToARGB16F(src, alpha, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

/// ARGB2101010 -> ARGB16F. The 2-bit alpha becomes `a / 3.0`.
pub fn argb2101010ToARGB16F(
    src: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    range_min: i32,
    range_max: i32,
    permute_map: ?*const [4]u8,
    flags: Options,
) Error!usize {
    return check(c.vImageConvert_ARGB2101010ToARGB16F(src, dest, range_min, range_max, permuteOrIdentity(permute_map), flags.bits()));
}

// ============================================================================
// Tests
// ============================================================================

/// A heap-allocated `width * height` buffer of `T`-sized pixels, packed
/// (`rowBytes == width * @sizeOf(T)`).
fn Image(comptime T: type) type {
    return struct {
        const Self = @This();

        pixels: []T,
        buf: vImage_Buffer,

        fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Self {
            const pixels = try allocator.alloc(T, width * height);
            @memset(pixels, std.mem.zeroes(T));
            return .{
                .pixels = pixels,
                .buf = .{
                    .data = pixels.ptr,
                    .height = height,
                    .width = width,
                    .rowBytes = width * @sizeOf(T),
                },
            };
        }

        fn deinit(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.pixels);
        }
    };
}

const Packed = Image(u32);
const ARGB8 = Image([4]u8);
const ARGB16 = Image([4]u16);
const ARGBQ12 = Image([4]i16);
const ARGBF = Image([4]f32);

fn half(bits: u16) f32 {
    return @floatCast(@as(f16, @bitCast(bits)));
}

test "packARGB2101010/argb2101010ToARGB8888: exact bit layout, A=31..30 R=29..20 G=19..10 B=9..0" {
    const allocator = std.testing.allocator;
    const src = try Packed.init(allocator, 4, 1);
    defer src.deinit(allocator);
    const dst = try ARGB8.init(allocator, 4, 1);
    defer dst.deinit(allocator);

    // Isolate one channel at a time at full scale.
    src.pixels[0] = packARGB2101010(3, 1023, 0, 0);
    src.pixels[1] = packARGB2101010(0, 0, 1023, 0);
    src.pixels[2] = packARGB2101010(0, 0, 0, 1023);
    src.pixels[3] = packARGB2101010(3, 1023, 1023, 1023);

    // Hand-check the packing itself: R=1023 alone is 0x3FF << 20.
    try std.testing.expectEqual(@as(u32, 0xFFF00000), src.pixels[0]);
    try std.testing.expectEqual(@as(u32, 0x000FFC00), src.pixels[1]);
    try std.testing.expectEqual(@as(u32, 0x000003FF), src.pixels[2]);

    _ = try argb2101010ToARGB8888(&src.buf, &dst.buf, full_range_min, full_range_max, null, .{});

    // alpha 3 -> (3*255+1)/3 == 255, colour 1023 -> 255.
    try std.testing.expectEqual([4]u8{ 255, 255, 0, 0 }, dst.pixels[0]);
    try std.testing.expectEqual([4]u8{ 0, 0, 255, 0 }, dst.pixels[1]);
    try std.testing.expectEqual([4]u8{ 0, 0, 0, 255 }, dst.pixels[2]);
    try std.testing.expectEqual([4]u8{ 255, 255, 255, 255 }, dst.pixels[3]);
}

test "ARGB8888 <-> ARGB2101010: colour channels round trip exactly for all 256 levels" {
    const allocator = std.testing.allocator;
    const n = 256;
    const src = try ARGB8.init(allocator, n, 1);
    defer src.deinit(allocator);
    const mid = try Packed.init(allocator, n, 1);
    defer mid.deinit(allocator);
    const back = try ARGB8.init(allocator, n, 1);
    defer back.deinit(allocator);

    for (src.pixels, 0..) |*p, i| {
        const v: u8 = @intCast(i);
        // Alpha 255 is one of the only two 8-bit alphas that survives the
        // 2-bit encoding (the other is 0).
        p.* = .{ 255, v, 255 - v, (v *% 7) };
    }

    _ = try argb8888ToARGB2101010(&src.buf, &mid.buf, full_range_min, full_range_max, null, .{});
    _ = try argb2101010ToARGB8888(&mid.buf, &back.buf, full_range_min, full_range_max, null, .{});

    try std.testing.expectEqualSlices([4]u8, src.pixels, back.pixels);

    // Spot-check the intermediate against the header's formula:
    //   R10 = ((R8 * 1023 + 127) / 255) + 0
    // For R8 = 128 that is (130944 + 127)/255 = 514.
    const r10: u32 = (mid.pixels[128] >> 20) & 0x3FF;
    try std.testing.expectEqual(@as(u32, 514), r10);
    // Alpha 255 -> 3.
    try std.testing.expectEqual(@as(u32, 3), mid.pixels[128] >> 30);
}

test "XRGB2101010: reader ignores the top 2 bits and uses the supplied alpha; writer zeroes them" {
    const allocator = std.testing.allocator;
    const src = try Packed.init(allocator, 2, 1);
    defer src.deinit(allocator);
    const dst = try ARGB8.init(allocator, 2, 1);
    defer dst.deinit(allocator);

    // Same colour, opposite top-2-bit content. Both must decode identically.
    src.pixels[0] = packARGB2101010(0, 1023, 512, 0);
    src.pixels[1] = packARGB2101010(3, 1023, 512, 0);

    _ = try xrgb2101010ToARGB8888(&src.buf, 200, &dst.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual(dst.pixels[0], dst.pixels[1]);
    // G10 = 512 -> (512*255 + 511)/1023 = 128.
    try std.testing.expectEqual([4]u8{ 200, 255, 128, 0 }, dst.pixels[0]);

    // Writer side: alpha 255 in the source must not reach the packed word.
    const src8 = try ARGB8.init(allocator, 1, 1);
    defer src8.deinit(allocator);
    src8.pixels[0] = .{ 255, 255, 0, 0 };
    const packed_dst = try Packed.init(allocator, 1, 1);
    defer packed_dst.deinit(allocator);
    _ = try argb8888ToXRGB2101010(&src8.buf, &packed_dst.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual(@as(u32, 0x3FF00000), packed_dst.pixels[0]);
}

test "RGBA1010102 is big-endian with alpha in the low 2 bits" {
    const allocator = std.testing.allocator;
    const src = try Packed.init(allocator, 2, 1);
    defer src.deinit(allocator);
    const dst = try ARGB8.init(allocator, 2, 1);
    defer dst.deinit(allocator);

    // R=1023, G=0, B=0, A=3 is 0xFFC00003 big-endian, i.e. 0x0300C0FF in
    // host order on a little-endian machine.
    src.pixels[0] = packRGBA1010102(1023, 0, 0, 3);
    src.pixels[1] = packRGBA1010102(0, 1023, 0, 0);
    if (@import("builtin").cpu.arch.endian() == .little) {
        try std.testing.expectEqual(@as(u32, 0x0300C0FF), src.pixels[0]);
    }

    _ = try rgba1010102ToARGB8888(&src.buf, &dst.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual([4]u8{ 255, 255, 0, 0 }, dst.pixels[0]);
    try std.testing.expectEqual([4]u8{ 0, 0, 255, 0 }, dst.pixels[1]);

    // ...and back. Alpha 255 -> 3 -> 255, so this is exact.
    const back = try Packed.init(allocator, 2, 1);
    defer back.deinit(allocator);
    _ = try argb8888ToRGBA1010102(&dst.buf, &back.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual(src.pixels[0], back.pixels[0]);
    try std.testing.expectEqual(src.pixels[1], back.pixels[1]);
}

test "ARGB16U <-> (X|A)RGB2101010 and RGBA1010102: endpoints exact, midpoint within 1 LSB of 10 bits" {
    const allocator = std.testing.allocator;
    const src = try ARGB16.init(allocator, 3, 1);
    defer src.deinit(allocator);
    const packed_argb = try Packed.init(allocator, 3, 1);
    defer packed_argb.deinit(allocator);
    const back = try ARGB16.init(allocator, 3, 1);
    defer back.deinit(allocator);

    src.pixels[0] = .{ 65535, 65535, 0, 0 };
    src.pixels[1] = .{ 65535, 0, 65535, 0 };
    src.pixels[2] = .{ 65535, 32768, 32768, 32768 };

    _ = try argb16UToARGB2101010(&src.buf, &packed_argb.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual(packARGB2101010(3, 1023, 0, 0), packed_argb.pixels[0]);
    // R16 = 32768 -> (32768*1023 + 32767)/65535 = 33554431/65535 = 512.
    try std.testing.expectEqual(@as(u32, 512), (packed_argb.pixels[2] >> 20) & 0x3FF);

    _ = try argb2101010ToARGB16U(&packed_argb.buf, &back.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual([4]u16{ 65535, 65535, 0, 0 }, back.pixels[0]);
    try std.testing.expectEqual([4]u16{ 65535, 0, 65535, 0 }, back.pixels[1]);
    // 512 -> (512*65535 + 511)/1023 = 32798: lossy by 30, well under one
    // 10-bit step (65535/1023 = 64).
    for (back.pixels[2][1..]) |v| {
        try std.testing.expectApproxEqAbs(@as(f64, 32768), @as(f64, @floatFromInt(v)), 64);
    }

    // The X variant drops source alpha and re-supplies it on read.
    const packed_x = try Packed.init(allocator, 3, 1);
    defer packed_x.deinit(allocator);
    _ = try argb16UToXRGB2101010(&src.buf, &packed_x.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual(@as(u32, 0), packed_x.pixels[0] >> 30);
    const back_x = try ARGB16.init(allocator, 3, 1);
    defer back_x.deinit(allocator);
    _ = try xrgb2101010ToARGB16U(&packed_x.buf, 4242, &back_x.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual([4]u16{ 4242, 65535, 0, 0 }, back_x.pixels[0]);

    // Same numbers through the big-endian RGBA1010102 spelling.
    const packed_rgba = try Packed.init(allocator, 3, 1);
    defer packed_rgba.deinit(allocator);
    _ = try argb16UToRGBA1010102(&src.buf, &packed_rgba.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual(packRGBA1010102(1023, 0, 0, 3), packed_rgba.pixels[0]);
    const back_rgba = try ARGB16.init(allocator, 3, 1);
    defer back_rgba.deinit(allocator);
    _ = try rgba1010102ToARGB16U(&packed_rgba.buf, &back_rgba.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual([4]u16{ 65535, 65535, 0, 0 }, back_rgba.pixels[0]);
}

test "ARGB16Q12 <-> (X|A)RGB2101010: 4096 is 1.0, 0 is 0.0; midpoint is lossy" {
    const allocator = std.testing.allocator;
    const src = try ARGBQ12.init(allocator, 2, 1);
    defer src.deinit(allocator);
    const mid = try Packed.init(allocator, 2, 1);
    defer mid.deinit(allocator);
    const back = try ARGBQ12.init(allocator, 2, 1);
    defer back.deinit(allocator);

    src.pixels[0] = .{ 4096, 4096, 0, 0 };
    src.pixels[1] = .{ 4096, 2048, 2048, 2048 };

    _ = try argb16Q12ToARGB2101010(&src.buf, &mid.buf, full_range_min, full_range_max, 0, 1023, null, .{});
    // A: clamp(0, (4096*3 + 2048) >> 12, 3) = 3.  R: ((4096*1023 + 2048) >> 12) + 0 = 1023.
    try std.testing.expectEqual(packARGB2101010(3, 1023, 0, 0), mid.pixels[0]);
    // 2048 -> ((2048*1023 + 2048) >> 12) = 512.
    try std.testing.expectEqual(@as(u32, 512), (mid.pixels[1] >> 20) & 0x3FF);

    _ = try argb2101010ToARGB16Q12(&mid.buf, &back.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual([4]i16{ 4096, 4096, 0, 0 }, back.pixels[0]);
    // 512 -> (512*4096 + 511)/1023 = 2050: two 4.12 steps off 2048.
    for (back.pixels[1][1..]) |v| {
        try std.testing.expectApproxEqAbs(@as(f64, 2048), @as(f64, @floatFromInt(v)), 4);
    }

    // XRGB variant: alpha comes from the argument, as a raw 4.12 value.
    const mid_x = try Packed.init(allocator, 2, 1);
    defer mid_x.deinit(allocator);
    _ = try argb16Q12ToXRGB2101010(&src.buf, &mid_x.buf, full_range_min, full_range_max, 0, 1023, null, .{});
    try std.testing.expectEqual(@as(u32, 0), mid_x.pixels[0] >> 30);
    const back_x = try ARGBQ12.init(allocator, 2, 1);
    defer back_x.deinit(allocator);
    _ = try xrgb2101010ToARGB16Q12(&mid_x.buf, 2048, &back_x.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual([4]i16{ 2048, 4096, 0, 0 }, back_x.pixels[0]);

    // And through RGBA1010102.
    const mid_rgba = try Packed.init(allocator, 2, 1);
    defer mid_rgba.deinit(allocator);
    _ = try argb16Q12ToRGBA1010102(&src.buf, &mid_rgba.buf, full_range_min, full_range_max, 0, 1023, null, .{});
    try std.testing.expectEqual(packRGBA1010102(1023, 0, 0, 3), mid_rgba.pixels[0]);
    const back_rgba = try ARGBQ12.init(allocator, 2, 1);
    defer back_rgba.deinit(allocator);
    _ = try rgba1010102ToARGB16Q12(&mid_rgba.buf, &back_rgba.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual([4]i16{ 4096, 4096, 0, 0 }, back_rgba.pixels[0]);
}

test "ARGB16Q12 -> packed: RGB101010Min/Max clamp the out-of-[0,1] excursion that 4.12 allows" {
    const allocator = std.testing.allocator;
    const src = try ARGBQ12.init(allocator, 2, 1);
    defer src.deinit(allocator);
    const dst = try Packed.init(allocator, 2, 1);
    defer dst.deinit(allocator);

    // 8192 == 2.0 and -4096 == -1.0, both legal 4.12 values, both far outside
    // the encodable 10-bit range once scaled.
    src.pixels[0] = .{ 4096, 8192, -4096, 0 };
    src.pixels[1] = .{ 4096, 8192, -4096, 0 };

    // Video range 64..940, with the wider 4..1019 hard clamp.
    _ = try argb16Q12ToXRGB2101010(&src.buf, &dst.buf, 64, 940, 4, 1019, null, .{});
    // R: ((8192*876 + 2048) >> 12) + 64 = 1752 + 64 = 1816 -> clamped to 1019.
    try std.testing.expectEqual(@as(u32, 1019), (dst.pixels[0] >> 20) & 0x3FF);
    // G: ((-4096*876 + 2048) >> 12) + 64 = -876 + 64 = -812 -> clamped to 4.
    try std.testing.expectEqual(@as(u32, 4), (dst.pixels[0] >> 10) & 0x3FF);
    // B: 0 -> 0 + 64 = 64, untouched by the clamp.
    try std.testing.expectEqual(@as(u32, 64), dst.pixels[0] & 0x3FF);

    // A tighter clamp bites harder on exactly the same input.
    _ = try argb16Q12ToXRGB2101010(&src.buf, &dst.buf, 64, 940, 64, 940, null, .{});
    try std.testing.expectEqual(@as(u32, 940), (dst.pixels[0] >> 20) & 0x3FF);
    try std.testing.expectEqual(@as(u32, 64), (dst.pixels[0] >> 10) & 0x3FF);
}

test "ARGBFFFF <-> (X|A)RGB2101010: 1.0 <-> range_max, alpha quantised to a/3" {
    const allocator = std.testing.allocator;
    const src = try ARGBF.init(allocator, 3, 1);
    defer src.deinit(allocator);
    const mid = try Packed.init(allocator, 3, 1);
    defer mid.deinit(allocator);
    const back = try ARGBF.init(allocator, 3, 1);
    defer back.deinit(allocator);

    src.pixels[0] = .{ 1.0, 1.0, 0.0, 0.0 };
    src.pixels[1] = .{ 1.0, 0.5, 0.5, 0.5 };
    // Alpha 1/3 must land on A2 == 1 : (int)(0.3333*3 + 0.5) == 1.
    src.pixels[2] = .{ 1.0 / 3.0, 0.0, 0.0, 1.0 };

    _ = try argbFFFFToARGB2101010(&src.buf, &mid.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual(packARGB2101010(3, 1023, 0, 0), mid.pixels[0]);
    // (int)(0.5 * 1023 + 0.5) == 512.
    try std.testing.expectEqual(@as(u32, 512), (mid.pixels[1] >> 20) & 0x3FF);
    try std.testing.expectEqual(@as(u32, 1), mid.pixels[2] >> 30);
    try std.testing.expectEqual(packARGB2101010(1, 0, 0, 1023), mid.pixels[2]);

    _ = try argb2101010ToARGBFFFF(&mid.buf, &back.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual([4]f32{ 1.0, 1.0, 0.0, 0.0 }, back.pixels[0]);
    // 512/1023 = 0.500489...
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), back.pixels[1][1], 1e-3);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0 / 3.0), back.pixels[2][0], 1e-6);

    // XRGB variant substitutes the alpha argument verbatim, unquantised.
    const mid_x = try Packed.init(allocator, 3, 1);
    defer mid_x.deinit(allocator);
    _ = try argbFFFFToXRGB2101010(&src.buf, &mid_x.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual(@as(u32, 0x3FF00000), mid_x.pixels[0]);
    const back_x = try ARGBF.init(allocator, 3, 1);
    defer back_x.deinit(allocator);
    _ = try xrgb2101010ToARGBFFFF(&mid_x.buf, 0.125, &back_x.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual([4]f32{ 0.125, 1.0, 0.0, 0.0 }, back_x.pixels[0]);
}

test "(X|A)RGB2101010 -> ARGB16F: half-float bit patterns, 1.0 is 0x3C00" {
    const allocator = std.testing.allocator;
    const src = try Packed.init(allocator, 2, 1);
    defer src.deinit(allocator);
    const dst = try ARGB16.init(allocator, 2, 1);
    defer dst.deinit(allocator);

    src.pixels[0] = packARGB2101010(3, 1023, 0, 0);
    src.pixels[1] = packARGB2101010(0, 0, 1023, 0);

    _ = try argb2101010ToARGB16F(&src.buf, &dst.buf, full_range_min, full_range_max, null, .{});
    // Pixel_16F is a raw u16 bit pattern in this binding; 1.0h == 0x3C00.
    try std.testing.expectEqual([4]u16{ 0x3C00, 0x3C00, 0, 0 }, dst.pixels[0]);
    try std.testing.expectEqual(@as(f32, 1.0), half(dst.pixels[1][2]));
    try std.testing.expectEqual(@as(f32, 0.0), half(dst.pixels[1][0]));

    // XRGB variant: alpha is an f32 argument even though dest is half.
    _ = try xrgb2101010ToARGB16F(&src.buf, 0.5, &dst.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual(@as(u16, 0x3800), dst.pixels[0][0]); // 0.5h
    try std.testing.expectEqual(@as(f32, 1.0), half(dst.pixels[0][1]));
}

test "video range (64..940) rescales colour per the header's integer formula" {
    const allocator = std.testing.allocator;
    const src = try ARGB8.init(allocator, 2, 1);
    defer src.deinit(allocator);
    const dst = try Packed.init(allocator, 2, 1);
    defer dst.deinit(allocator);

    src.pixels[0] = .{ 255, 255, 0, 128 };
    src.pixels[1] = .{ 0, 0, 0, 0 };

    _ = try argb8888ToXRGB2101010(&src.buf, &dst.buf, 64, 940, null, .{});
    // range10 = 876.  R8=255 -> ((255*876 + 127)/255) + 64 = 876 + 64 = 940.
    try std.testing.expectEqual(@as(u32, 940), (dst.pixels[0] >> 20) & 0x3FF);
    // G8=0 -> 0 + 64 = 64.
    try std.testing.expectEqual(@as(u32, 64), (dst.pixels[0] >> 10) & 0x3FF);
    // B8=128 -> ((128*876 + 127)/255) + 64 = 440 + 64 = 504.
    try std.testing.expectEqual(@as(u32, 504), dst.pixels[0] & 0x3FF);
    try std.testing.expectEqual(packARGB2101010(0, 64, 64, 64), dst.pixels[1]);

    // Decoding with the same range restores the 8-bit values exactly here.
    const back = try ARGB8.init(allocator, 2, 1);
    defer back.deinit(allocator);
    _ = try xrgb2101010ToARGB8888(&dst.buf, 255, &back.buf, 64, 940, null, .{});
    try std.testing.expectEqual([4]u8{ 255, 255, 0, 128 }, back.pixels[0]);
}

test "permute_map reorders the four-channel side only: {3,2,1,0} is BGRA" {
    const allocator = std.testing.allocator;
    const src = try Packed.init(allocator, 1, 1);
    defer src.deinit(allocator);
    const dst = try ARGB8.init(allocator, 1, 1);
    defer dst.deinit(allocator);

    src.pixels[0] = packARGB2101010(3, 1023, 512, 0);
    const bgra: [4]u8 = .{ 3, 2, 1, 0 };
    _ = try argb2101010ToARGB8888(&src.buf, &dst.buf, full_range_min, full_range_max, &bgra, .{});
    // ARGB would be {255, 255, 128, 0}; reversed that is {0, 128, 255, 255}.
    try std.testing.expectEqual([4]u8{ 0, 128, 255, 255 }, dst.pixels[0]);

    // null must behave exactly like {0,1,2,3}.
    const dst_id = try ARGB8.init(allocator, 1, 1);
    defer dst_id.deinit(allocator);
    const dst_null = try ARGB8.init(allocator, 1, 1);
    defer dst_null.deinit(allocator);
    _ = try argb2101010ToARGB8888(&src.buf, &dst_id.buf, full_range_min, full_range_max, &identity_permute, .{});
    _ = try argb2101010ToARGB8888(&src.buf, &dst_null.buf, full_range_min, full_range_max, null, .{});
    try std.testing.expectEqual(dst_id.pixels[0], dst_null.pixels[0]);
    try std.testing.expectEqual([4]u8{ 255, 255, 128, 0 }, dst_null.pixels[0]);
}

test "out-of-bounds RGB101010Range is rejected with kvImageInvalidParameter (-21773)" {
    const allocator = std.testing.allocator;
    const src = try Packed.init(allocator, 1, 1);
    defer src.deinit(allocator);
    const dst = try ARGB8.init(allocator, 1, 1);
    defer dst.deinit(allocator);

    // kvImageInvalidParameter is -21773; `check` maps it to
    // Error.InvalidParameter.
    try std.testing.expectEqual(@as(vImage_Error, -21773), types.ErrorCode.kvImageInvalidParameter);

    // min > max.
    try std.testing.expectError(
        Error.InvalidParameter,
        argb2101010ToARGB8888(&src.buf, &dst.buf, 900, 100, null, .{}),
    );
    // max > 1023.
    try std.testing.expectError(
        Error.InvalidParameter,
        argb2101010ToARGB8888(&src.buf, &dst.buf, 0, 4095, null, .{}),
    );
}
