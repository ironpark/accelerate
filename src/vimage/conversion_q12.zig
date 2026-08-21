//! Conversions to and from Pixel_16Q12, vImage's signed 4.12 fixed-point
//! format.
//!
//! A Pixel_16Q12 is a plain `int16_t` holding a value scaled by 4096: the
//! numeric value of a sample is `raw / 4096.0`, so 4096 is 1.0, 2048 is 0.5
//! and -4096 is -1.0. The representable range is therefore
//! [-32768/4096, 32767/4096) == [-8, 8): eight times the nominal [0,1] unit
//! range in each direction, which is the point of the format. The headroom
//! lets a chain of filters overshoot (ringing from a sharpening kernel,
//! out-of-gamut colour after a matrix multiply) without clipping, at 12
//! fractional bits of precision - four more than 8-bit, and unlike 16U the
//! excess is *signed*, so undershoot survives too. Only at the end of the
//! chain do you clamp back down into a display format.
//!
//! Buffer sizing: one Pixel_16Q12 is 2 bytes, so a planar 16Q12 row needs
//! `width * 2` bytes and a four-channel interleaved (ARGB16Q12) row needs
//! `width * 8`. `vImage_Buffer.width` is always counted in pixels, never in
//! samples or bytes.
//!
//! The integer conversions here are exactly specified by Conversion.h, and
//! the wrappers repeat each formula in their doc comment. The two that matter
//! most:
//!
//!     8 -> 16Q12:  dest = ((src << 12) + 127) / 255
//!     16Q12 -> 8:  dest = (CLAMP(src, 0, 4096) * 255 + 2048) >> 12
//!
//! So 8-bit 0 maps to 0 and 8-bit 255 maps to exactly 4096 (1.0), never
//! higher; 8-bit 128 maps to 2056, not 2048, because the 8-bit scale is /255
//! and not /256. The 8-bit round trip 8 -> 16Q12 -> 8 is lossless for all 256
//! levels (there is a test below asserting exactly that). Going the other way
//! is lossy: 16Q12 -> 8 -> 16Q12 only recovers the 256 representable levels,
//! and any sample outside [0, 4096] is clamped away entirely.
//!
//! Note that only the *integer* destinations clamp. `convertFTo16Q12` clamps
//! to the i16 range, but `convert16Q12ToF`, `convert16Q12To16F` and the
//! planar-to-16F interleaving functions pass negative and >1.0 samples
//! through unchanged - the whole [-8, 8) range survives.
//!
//! Half-precision destinations are `Pixel_16F`, which is `u16` in this
//! codebase (the raw IEEE 754 binary16 bit pattern), so tests here `@bitCast`
//! to `f16` when checking values, per the pattern in geometry.zig.
//!
//! Supported flags for every function in this file are exactly
//! `kvImageDoNotTile` and `kvImageGetTempBufferSize` (which reports 0, as none
//! of these use a temp buffer). Any other flag bit returns
//! `error.UnknownFlagsBit` and does no work.

const std = @import("std");
const types = @import("types.zig");
const c = @import("c.zig");

const vImage_Buffer = types.vImage_Buffer;
const vImage_Error = types.vImage_Error;
const vImage_Flags = types.vImage_Flags;
const VImageError = types.VImageError;
const check = types.check;
const Flags = types.Flags;
const Pixel_8 = types.Pixel_8;
const Pixel_F = types.Pixel_F;
const Pixel_16U = types.Pixel_16U;
const Pixel_16F = types.Pixel_16F;
const Pixel_16Q12 = types.Pixel_16Q12;

// ============================================================================
// Scalar format conversions
//
// One sample in, one sample out, same width and height. Each of these is a
// planar operation in the sense that it does not care about channel layout:
// to convert an interleaved four-channel image, multiply
// `vImage_Buffer.width` by 4 and leave `rowBytes` alone.
// ============================================================================

/// Convert Planar8 to 16Q12.
///
///     dest = ((src << 12) + 127) / 255
///
/// 0 maps to 0 and 255 maps to exactly 4096 (1.0); no larger value is ever
/// produced, which leaves the whole [4096, 32767] range as headroom for
/// subsequent filtering. Does not operate in place (the destination samples
/// are twice as wide as the source's).
pub fn convert8To16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_8to16Q12(src, dest, flags));
}

/// Convert 16Q12 to Planar8.
///
///     dest = (CLAMP(src, 0, 4096) * 255 + 2048) >> 12
///
/// Negative samples clamp to 0 and anything at or above 4088 saturates to
/// 255, so the headroom above 1.0 is discarded. Does not operate in place.
pub fn convert16Q12To8(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_16Q12to8(src, dest, flags));
}

/// Convert 16Q12 to half-precision float (Planar16F).
///
///     dest = src / 4096.0
///
/// 4096 becomes 1.0. Nothing is clamped, so negative and >1.0 samples pass
/// through. binary16 has an 11-bit significand, so samples with magnitude
/// above 2048/4096 lose the bottom fractional bit or two; below 1.0 the
/// conversion is exact. Operates in place provided `src.data == dest.data`
/// and `src.rowBytes == dest.rowBytes` (both formats are 2 bytes per sample).
pub fn convert16Q12To16F(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_16Q12to16F(src, dest, flags));
}

/// Convert half-precision float (Planar16F) to 16Q12.
///
/// 1.0 becomes exactly 4096. Values outside [-8, 8) cannot be represented and
/// saturate at the i16 limits. Operates in place provided
/// `src.data == dest.data` and `src.rowBytes == dest.rowBytes`.
pub fn convert16FTo16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_16Fto16Q12(src, dest, flags));
}

/// Convert 16Q12 to single-precision float (PlanarF).
///
///     dest = src / 4096.0f
///
/// Always exact - every i16 divided by a power of two is representable in
/// f32. 4096 becomes 1.0. Does not operate in place (4-byte destination
/// samples), despite the header's shared "operates in place" note, which
/// applies to the equal-width pairs.
pub fn convert16Q12ToF(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_16Q12toF(src, dest, flags));
}

/// Convert single-precision float (PlanarF) to 16Q12.
///
///     dest = CLAMP(-32768, lrintf(src * 4096.0f), 32767)
///
/// 1.0 becomes exactly 4096. Rounding is `lrintf`, i.e. round-half-to-even
/// under the default rounding mode, not round-half-away-from-zero. Anything
/// at or beyond +8.0 saturates to 32767 rather than wrapping.
pub fn convertFTo16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_Fto16Q12(src, dest, flags));
}

/// Convert 16Q12 to 16-bit unsigned (Planar16U).
///
///     dest = CLAMP(0, (src * 65535 + 2048) >> 12, 65535)
///
/// 4096 maps to 65535. Negative samples clamp to 0 and samples above 4096
/// clamp to 65535, so this discards the headroom the same way
/// `convert16Q12To8` does. Operates in place provided `src.data == dest.data`
/// and `src.rowBytes == dest.rowBytes`.
pub fn convert16Q12To16U(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_16Q12to16U(src, dest, flags));
}

/// Convert 16-bit unsigned (Planar16U) to 16Q12.
///
///     dest = (src * 4096 + 32767) / 65535
///
/// 65535 maps to exactly 4096 (1.0). The result never exceeds 4096, so the
/// upper headroom stays free. This direction is lossy - 65536 input levels
/// collapse onto 4097 output levels - and it is the inverse-lossy partner of
/// `convert16Q12To16U`, which expands back. Operates in place provided
/// `src.data == dest.data` and `src.rowBytes == dest.rowBytes`.
pub fn convert16UTo16Q12(src: *const vImage_Buffer, dest: *const vImage_Buffer, flags: vImage_Flags) VImageError!usize {
    return check(c.vImageConvert_16Uto16Q12(src, dest, flags));
}

// ============================================================================
// De-interleaving 8-bit -> planar 16Q12
//
// Channel order is set entirely by the order the destination buffers are
// passed, so an RGB888 source is handled by `rgb888ToPlanar16Q12(src, r, g, b)`
// and a BGR888 source by `rgb888ToPlanar16Q12(src, b, g, r)`; likewise
// `argb8888ToPlanar16Q12` handles BGRA by passing (b, g, r, a).
// ============================================================================

/// De-interleave RGB888 into three planar 16Q12 buffers, converting with the
/// same `((src << 12) + 127) / 255` formula as `convert8To16Q12`.
///
/// The source row is `width * 3` bytes; each destination row is `width * 2`
/// bytes. All three destinations must be the same size as each other and no
/// larger than the source, or the call returns `error.BufferSizeMismatch` /
/// `error.RoiLargerThanInputBuffer`. Does not operate in place.
pub fn rgb888ToPlanar16Q12(
    src: *const vImage_Buffer,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_RGB888toPlanar16Q12(src, red, green, blue, flags));
}

/// De-interleave ARGB8888 into four planar 16Q12 buffers, converting with the
/// same `((src << 12) + 127) / 255` formula as `convert8To16Q12`.
///
/// The alpha channel is converted identically to the colour channels; if the
/// source is premultiplied it stays premultiplied, since the conversion is a
/// per-sample rescale. Source rows are `width * 4` bytes, each destination row
/// `width * 2`. Does not operate in place.
pub fn argb8888ToPlanar16Q12(
    src: *const vImage_Buffer,
    alpha: *const vImage_Buffer,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_ARGB8888toPlanar16Q12(src, alpha, red, green, blue, flags));
}

// ============================================================================
// Interleaving planar 16Q12 -> 8-bit / 16F
// ============================================================================

/// Interleave three planar 16Q12 buffers into RGB888, converting with the
/// clamping `(CLAMP(src, 0, 4096) * 255 + 2048) >> 12` formula.
///
/// Destination rows are `width * 3` bytes. Because the conversion clamps,
/// out-of-range working values are lost here - do any headroom-dependent work
/// before this call. Does not operate in place.
pub fn planar16Q12ToRGB888(
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_Planar16Q12toRGB888(red, green, blue, dest, flags));
}

/// Interleave four planar 16Q12 buffers into ARGB8888, converting with the
/// clamping `(CLAMP(src, 0, 4096) * 255 + 2048) >> 12` formula.
///
/// Destination rows are `width * 4` bytes. Alpha is converted like any other
/// channel and no (un)premultiplication is performed. Does not operate in
/// place.
pub fn planar16Q12ToARGB8888(
    alpha: *const vImage_Buffer,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_Planar16Q12toARGB8888(alpha, red, green, blue, dest, flags));
}

/// Interleave three planar 16Q12 buffers into RGB16F (three half floats per
/// pixel), dividing each sample by 4096.
///
/// Destination rows are `width * 6` bytes. Unlike the 8-bit interleavers this
/// does not clamp, so negative and above-1.0 samples survive. Does not operate
/// in place.
pub fn planar16Q12ToRGB16F(
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_Planar16Q12toRGB16F(red, green, blue, dest, flags));
}

/// Interleave four planar 16Q12 buffers into ARGB16F (four half floats per
/// pixel), dividing each sample by 4096.
///
/// Destination rows are `width * 8` bytes. Does not clamp; does not operate in
/// place.
pub fn planar16Q12ToARGB16F(
    alpha: *const vImage_Buffer,
    red: *const vImage_Buffer,
    green: *const vImage_Buffer,
    blue: *const vImage_Buffer,
    dest: *const vImage_Buffer,
    flags: vImage_Flags,
) VImageError!usize {
    return check(c.vImageConvert_Planar16Q12toARGB16F(alpha, red, green, blue, dest, flags));
}

// ============================================================================
// Tests
// ============================================================================

/// A test image whose rows carry two elements of trailing padding, so that a
/// wrapper that confused `rowBytes` with `width * channels * sizeof(T)` would
/// read the wrong samples.
fn Img(comptime T: type) type {
    return struct {
        const Self = @This();

        mem: []T,
        stride: usize, // elements per row, padding included
        channels: usize,
        buf: vImage_Buffer,

        fn init(allocator: std.mem.Allocator, width: usize, height: usize, channels: usize) !Self {
            const stride = width * channels + 2;
            const mem = try allocator.alloc(T, stride * height);
            @memset(mem, 0);
            return .{
                .mem = mem,
                .stride = stride,
                .channels = channels,
                .buf = .{
                    .data = mem.ptr,
                    .height = height,
                    .width = width,
                    .rowBytes = stride * @sizeOf(T),
                },
            };
        }

        fn deinit(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.mem);
        }

        /// Sample `ch` of pixel (x, y).
        fn at(self: Self, x: usize, y: usize, ch: usize) T {
            return self.mem[y * self.stride + x * self.channels + ch];
        }

        fn set(self: Self, x: usize, y: usize, ch: usize, value: T) void {
            self.mem[y * self.stride + x * self.channels + ch] = value;
        }

        /// Fill row 0 of a single-channel image from a slice.
        fn fillRow0(self: Self, values: []const T) void {
            for (values, 0..) |v, x| self.set(x, 0, 0, v);
        }
    };
}

/// Half floats cross the boundary as raw bit patterns (`Pixel_16F` == `u16`).
fn half(bits: Pixel_16F) f16 {
    return @bitCast(bits);
}

fn halfBits(value: f16) Pixel_16F {
    return @bitCast(value);
}

test "convert8To16Q12: 255 -> 4096 exactly, 128 -> 2056, per ((v<<12)+127)/255" {
    const allocator = std.testing.allocator;
    const src = try Img(Pixel_8).init(allocator, 6, 1, 1);
    defer src.deinit(allocator);
    const dest = try Img(Pixel_16Q12).init(allocator, 6, 1, 1);
    defer dest.deinit(allocator);

    src.fillRow0(&[_]Pixel_8{ 0, 1, 64, 128, 254, 255 });
    try std.testing.expectEqual(@as(usize, 0), try convert8To16Q12(&src.buf, &dest.buf, Flags.kvImageNoFlags));

    // ((v << 12) + 127) / 255, computed by hand:
    //   0   -> 127/255                = 0
    //   1   -> 4223/255               = 16
    //   64  -> 262271/255             = 1028
    //   128 -> 524415/255             = 2056   (not 2048: the 8-bit scale is /255)
    //   254 -> 1040511/255            = 4080
    //   255 -> 1044607/255            = 4096   (exactly 1.0, and never more)
    const want = [_]Pixel_16Q12{ 0, 16, 1028, 2056, 4080, 4096 };
    for (want, 0..) |w, x| try std.testing.expectEqual(w, dest.at(x, 0, 0));
}

test "convert16Q12To8: clamps [0,4096] then rounds, per (clamp*255+2048)>>12" {
    const allocator = std.testing.allocator;
    const src = try Img(Pixel_16Q12).init(allocator, 7, 1, 1);
    defer src.deinit(allocator);
    const dest = try Img(Pixel_8).init(allocator, 7, 1, 1);
    defer dest.deinit(allocator);

    src.fillRow0(&[_]Pixel_16Q12{ -8192, -1, 0, 16, 2056, 4088, 32767 });
    try std.testing.expectEqual(@as(usize, 0), try convert16Q12To8(&src.buf, &dest.buf, Flags.kvImageNoFlags));

    // Negatives clamp to 0; 4088 is already 255 (the header says "4088 or
    // greater"); the top of the 16Q12 range clamps to 4096 -> 255, so all the
    // headroom above 1.0 is thrown away here.
    const want = [_]Pixel_8{ 0, 0, 0, 1, 128, 255, 255 };
    for (want, 0..) |w, x| try std.testing.expectEqual(w, dest.at(x, 0, 0));
}

test "8 -> 16Q12 -> 8 round trips losslessly for all 256 levels" {
    const allocator = std.testing.allocator;
    const src = try Img(Pixel_8).init(allocator, 256, 1, 1);
    defer src.deinit(allocator);
    const mid = try Img(Pixel_16Q12).init(allocator, 256, 1, 1);
    defer mid.deinit(allocator);
    const back = try Img(Pixel_8).init(allocator, 256, 1, 1);
    defer back.deinit(allocator);

    for (0..256) |v| src.set(v, 0, 0, @intCast(v));

    _ = try convert8To16Q12(&src.buf, &mid.buf, Flags.kvImageNoFlags);
    _ = try convert16Q12To8(&mid.buf, &back.buf, Flags.kvImageNoFlags);

    for (0..256) |v| try std.testing.expectEqual(@as(Pixel_8, @intCast(v)), back.at(v, 0, 0));
    // Sanity: the intermediate really is the fixed-point value, not a copy.
    try std.testing.expectEqual(@as(Pixel_16Q12, 4096), mid.at(255, 0, 0));
}

test "convert16Q12ToF: exact division by 4096, negatives and headroom preserved" {
    const allocator = std.testing.allocator;
    const src = try Img(Pixel_16Q12).init(allocator, 6, 1, 1);
    defer src.deinit(allocator);
    const dest = try Img(Pixel_F).init(allocator, 6, 1, 1);
    defer dest.deinit(allocator);

    src.fillRow0(&[_]Pixel_16Q12{ -8192, -4096, 0, 2048, 4096, 16384 });
    try std.testing.expectEqual(@as(usize, 0), try convert16Q12ToF(&src.buf, &dest.buf, Flags.kvImageNoFlags));

    const want = [_]Pixel_F{ -2.0, -1.0, 0.0, 0.5, 1.0, 4.0 };
    for (want, 0..) |w, x| try std.testing.expectEqual(w, dest.at(x, 0, 0));
}

test "convertFTo16Q12: 1.0 -> 4096, rounds to nearest, saturates at 32767" {
    const allocator = std.testing.allocator;
    const src = try Img(Pixel_F).init(allocator, 6, 1, 1);
    defer src.deinit(allocator);
    const dest = try Img(Pixel_16Q12).init(allocator, 6, 1, 1);
    defer dest.deinit(allocator);

    // 0.30000001192 * 4096 = 1228.80005 -> lrintf = 1229.
    src.fillRow0(&[_]Pixel_F{ -1.5, 0.0, 0.3, 0.5, 1.0, 8.5 });
    try std.testing.expectEqual(@as(usize, 0), try convertFTo16Q12(&src.buf, &dest.buf, Flags.kvImageNoFlags));

    const want = [_]Pixel_16Q12{ -6144, 0, 1229, 2048, 4096, 32767 };
    for (want, 0..) |w, x| try std.testing.expectEqual(w, dest.at(x, 0, 0));
}

test "convert16Q12To16U / convert16UTo16Q12: 4096 <-> 65535 with the documented rounding" {
    const allocator = std.testing.allocator;
    const q = try Img(Pixel_16Q12).init(allocator, 5, 1, 1);
    defer q.deinit(allocator);
    const u = try Img(Pixel_16U).init(allocator, 5, 1, 1);
    defer u.deinit(allocator);

    // CLAMP(0, (src * 65535 + 2048) >> 12, 65535)
    q.fillRow0(&[_]Pixel_16Q12{ -1, 0, 1, 2048, 4096 });
    try std.testing.expectEqual(@as(usize, 0), try convert16Q12To16U(&q.buf, &u.buf, Flags.kvImageNoFlags));
    const want_u = [_]Pixel_16U{ 0, 0, 16, 32768, 65535 };
    for (want_u, 0..) |w, x| try std.testing.expectEqual(w, u.at(x, 0, 0));

    // (src * 4096 + 32767) / 65535, back the other way into a fresh buffer.
    const q2 = try Img(Pixel_16Q12).init(allocator, 5, 1, 1);
    defer q2.deinit(allocator);
    u.fillRow0(&[_]Pixel_16U{ 0, 1, 32768, 65534, 65535 });
    try std.testing.expectEqual(@as(usize, 0), try convert16UTo16Q12(&u.buf, &q2.buf, Flags.kvImageNoFlags));
    // 1 -> 4127/65535 = 0 (lossy: 16 input levels share each 16Q12 level),
    // 65535 -> 268464127/65535 = 4096 exactly.
    const want_q = [_]Pixel_16Q12{ 0, 0, 2048, 4096, 4096 };
    for (want_q, 0..) |w, x| try std.testing.expectEqual(w, q2.at(x, 0, 0));
}

test "convert16Q12To16F / convert16FTo16Q12: 4096 <-> 1.0h, lossy above 0.5 within 1/2048" {
    const allocator = std.testing.allocator;
    const q = try Img(Pixel_16Q12).init(allocator, 6, 1, 1);
    defer q.deinit(allocator);
    const h = try Img(Pixel_16F).init(allocator, 6, 1, 1);
    defer h.deinit(allocator);

    q.fillRow0(&[_]Pixel_16Q12{ -4096, 0, 1, 2048, 4096, 4097 });
    try std.testing.expectEqual(@as(usize, 0), try convert16Q12To16F(&q.buf, &h.buf, Flags.kvImageNoFlags));

    // Exact for the first five: 1/4096 is a normal binary16, and 0.5 and 1.0
    // are exact. 4097/4096 needs a 13th significand bit that binary16 lacks,
    // so it rounds to 1.0 - hence the tolerance on the last one.
    try std.testing.expectEqual(@as(f16, -1.0), half(h.at(0, 0, 0)));
    try std.testing.expectEqual(@as(f16, 0.0), half(h.at(1, 0, 0)));
    try std.testing.expectEqual(@as(f16, 1.0 / 4096.0), half(h.at(2, 0, 0)));
    try std.testing.expectEqual(@as(f16, 0.5), half(h.at(3, 0, 0)));
    try std.testing.expectEqual(@as(f16, 1.0), half(h.at(4, 0, 0)));
    try std.testing.expectApproxEqAbs(@as(f16, 4097.0 / 4096.0), half(h.at(5, 0, 0)), 1.0 / 2048.0);

    // And back: everything except the 4097 sample must round trip exactly.
    const q2 = try Img(Pixel_16Q12).init(allocator, 6, 1, 1);
    defer q2.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try convert16FTo16Q12(&h.buf, &q2.buf, Flags.kvImageNoFlags));
    const want = [_]Pixel_16Q12{ -4096, 0, 1, 2048, 4096, 4096 };
    for (want, 0..) |w, x| try std.testing.expectEqual(w, q2.at(x, 0, 0));
}

test "convert16FTo16Q12: 1.0h -> 4096 and out-of-range halves saturate" {
    const allocator = std.testing.allocator;
    const h = try Img(Pixel_16F).init(allocator, 4, 1, 1);
    defer h.deinit(allocator);
    const q = try Img(Pixel_16Q12).init(allocator, 4, 1, 1);
    defer q.deinit(allocator);

    h.fillRow0(&[_]Pixel_16F{ halfBits(1.0), halfBits(-0.25), halfBits(7.5), halfBits(100.0) });
    try std.testing.expectEqual(@as(usize, 0), try convert16FTo16Q12(&h.buf, &q.buf, Flags.kvImageNoFlags));

    try std.testing.expectEqual(@as(Pixel_16Q12, 4096), q.at(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_16Q12, -1024), q.at(1, 0, 0));
    try std.testing.expectEqual(@as(Pixel_16Q12, 30720), q.at(2, 0, 0)); // 7.5 * 4096
    try std.testing.expectEqual(@as(Pixel_16Q12, 32767), q.at(3, 0, 0)); // 100 is way past +8
}

test "rgb888ToPlanar16Q12 / planar16Q12ToRGB888: de-interleave, convert, re-interleave" {
    const allocator = std.testing.allocator;
    const width = 3;
    const src = try Img(Pixel_8).init(allocator, width, 2, 3);
    defer src.deinit(allocator);

    // Distinct per channel and per pixel so a channel mixup is visible.
    const rgb = [2][3][3]Pixel_8{
        .{ .{ 255, 128, 0 }, .{ 0, 255, 128 }, .{ 128, 0, 255 } },
        .{ .{ 1, 2, 3 }, .{ 254, 253, 252 }, .{ 64, 65, 66 } },
    };
    for (0..2) |y| for (0..width) |x| for (0..3) |ch| src.set(x, y, ch, rgb[y][x][ch]);

    const r = try Img(Pixel_16Q12).init(allocator, width, 2, 1);
    defer r.deinit(allocator);
    const g = try Img(Pixel_16Q12).init(allocator, width, 2, 1);
    defer g.deinit(allocator);
    const b = try Img(Pixel_16Q12).init(allocator, width, 2, 1);
    defer b.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), try rgb888ToPlanar16Q12(&src.buf, &r.buf, &g.buf, &b.buf, Flags.kvImageNoFlags));

    // Same formula as convert8To16Q12: 255 -> 4096, 128 -> 2056, 0 -> 0.
    try std.testing.expectEqual(@as(Pixel_16Q12, 4096), r.at(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_16Q12, 2056), g.at(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_16Q12, 0), b.at(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_16Q12, 0), r.at(1, 0, 0));
    try std.testing.expectEqual(@as(Pixel_16Q12, 4096), g.at(1, 0, 0));
    try std.testing.expectEqual(@as(Pixel_16Q12, 2056), b.at(1, 0, 0));
    // Row 1 exercises the rowBytes stride on every plane.
    try std.testing.expectEqual(@as(Pixel_16Q12, 4080), r.at(1, 1, 0)); // 254
    try std.testing.expectEqual(@as(Pixel_16Q12, 1028), r.at(2, 1, 0)); // 64

    const back = try Img(Pixel_8).init(allocator, width, 2, 3);
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try planar16Q12ToRGB888(&r.buf, &g.buf, &b.buf, &back.buf, Flags.kvImageNoFlags));

    for (0..2) |y| for (0..width) |x| for (0..3) |ch| {
        try std.testing.expectEqual(rgb[y][x][ch], back.at(x, y, ch));
    };
}

test "planar16Q12ToRGB888: channel order follows argument order, so (b,g,r) writes BGR" {
    const allocator = std.testing.allocator;
    const r = try Img(Pixel_16Q12).init(allocator, 1, 1, 1);
    defer r.deinit(allocator);
    const g = try Img(Pixel_16Q12).init(allocator, 1, 1, 1);
    defer g.deinit(allocator);
    const b = try Img(Pixel_16Q12).init(allocator, 1, 1, 1);
    defer b.deinit(allocator);
    r.set(0, 0, 0, 4096); // 1.0 -> 255
    g.set(0, 0, 0, 2056); // -> 128
    b.set(0, 0, 0, 0);

    const dest = try Img(Pixel_8).init(allocator, 1, 1, 3);
    defer dest.deinit(allocator);
    _ = try planar16Q12ToRGB888(&b.buf, &g.buf, &r.buf, &dest.buf, Flags.kvImageNoFlags);

    try std.testing.expectEqual(@as(Pixel_8, 0), dest.at(0, 0, 0));
    try std.testing.expectEqual(@as(Pixel_8, 128), dest.at(0, 0, 1));
    try std.testing.expectEqual(@as(Pixel_8, 255), dest.at(0, 0, 2));
}

test "argb8888ToPlanar16Q12 / planar16Q12ToARGB8888: alpha is converted like any other channel" {
    const allocator = std.testing.allocator;
    const width = 2;
    const src = try Img(Pixel_8).init(allocator, width, 2, 4);
    defer src.deinit(allocator);

    const argb = [2][2][4]Pixel_8{
        .{ .{ 255, 128, 64, 0 }, .{ 0, 1, 2, 3 } },
        .{ .{ 200, 100, 50, 25 }, .{ 254, 255, 128, 129 } },
    };
    for (0..2) |y| for (0..width) |x| for (0..4) |ch| src.set(x, y, ch, argb[y][x][ch]);

    const a = try Img(Pixel_16Q12).init(allocator, width, 2, 1);
    defer a.deinit(allocator);
    const r = try Img(Pixel_16Q12).init(allocator, width, 2, 1);
    defer r.deinit(allocator);
    const g = try Img(Pixel_16Q12).init(allocator, width, 2, 1);
    defer g.deinit(allocator);
    const b = try Img(Pixel_16Q12).init(allocator, width, 2, 1);
    defer b.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 0), try argb8888ToPlanar16Q12(&src.buf, &a.buf, &r.buf, &g.buf, &b.buf, Flags.kvImageNoFlags));

    try std.testing.expectEqual(@as(Pixel_16Q12, 4096), a.at(0, 0, 0)); // 255
    try std.testing.expectEqual(@as(Pixel_16Q12, 2056), r.at(0, 0, 0)); // 128
    try std.testing.expectEqual(@as(Pixel_16Q12, 1028), g.at(0, 0, 0)); // 64
    try std.testing.expectEqual(@as(Pixel_16Q12, 0), b.at(0, 0, 0)); // 0
    try std.testing.expectEqual(@as(Pixel_16Q12, 3213), a.at(0, 1, 0)); // 200: 819327/255 = 3213

    const back = try Img(Pixel_8).init(allocator, width, 2, 4);
    defer back.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try planar16Q12ToARGB8888(&a.buf, &r.buf, &g.buf, &b.buf, &back.buf, Flags.kvImageNoFlags));

    for (0..2) |y| for (0..width) |x| for (0..4) |ch| {
        try std.testing.expectEqual(argb[y][x][ch], back.at(x, y, ch));
    };
}

test "planar16Q12ToRGB16F: interleaves as src/4096 without clamping" {
    const allocator = std.testing.allocator;
    const r = try Img(Pixel_16Q12).init(allocator, 2, 1, 1);
    defer r.deinit(allocator);
    const g = try Img(Pixel_16Q12).init(allocator, 2, 1, 1);
    defer g.deinit(allocator);
    const b = try Img(Pixel_16Q12).init(allocator, 2, 1, 1);
    defer b.deinit(allocator);

    r.fillRow0(&[_]Pixel_16Q12{ 4096, -2048 }); //  1.0, -0.5
    g.fillRow0(&[_]Pixel_16Q12{ 2048, 8192 }); //  0.5,  2.0
    b.fillRow0(&[_]Pixel_16Q12{ 0, 32767 }); //  0.0,  ~7.9998

    const dest = try Img(Pixel_16F).init(allocator, 2, 1, 3);
    defer dest.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try planar16Q12ToRGB16F(&r.buf, &g.buf, &b.buf, &dest.buf, Flags.kvImageNoFlags));

    try std.testing.expectEqual(@as(f16, 1.0), half(dest.at(0, 0, 0)));
    try std.testing.expectEqual(@as(f16, 0.5), half(dest.at(0, 0, 1)));
    try std.testing.expectEqual(@as(f16, 0.0), half(dest.at(0, 0, 2)));
    try std.testing.expectEqual(@as(f16, -0.5), half(dest.at(1, 0, 0)));
    // Nothing is clamped to [0,1] on this path, unlike the RGB888 one.
    try std.testing.expectEqual(@as(f16, 2.0), half(dest.at(1, 0, 1)));
    // 32767/4096 = 7.99976; binary16 near 8 has a step of 1/2048.
    try std.testing.expectApproxEqAbs(@as(f16, 7.99976), half(dest.at(1, 0, 2)), 1.0 / 2048.0);
}

test "planar16Q12ToARGB16F: four planes interleave in argument order" {
    const allocator = std.testing.allocator;
    const a = try Img(Pixel_16Q12).init(allocator, 1, 2, 1);
    defer a.deinit(allocator);
    const r = try Img(Pixel_16Q12).init(allocator, 1, 2, 1);
    defer r.deinit(allocator);
    const g = try Img(Pixel_16Q12).init(allocator, 1, 2, 1);
    defer g.deinit(allocator);
    const b = try Img(Pixel_16Q12).init(allocator, 1, 2, 1);
    defer b.deinit(allocator);

    a.set(0, 0, 0, 4096); // 1.0
    r.set(0, 0, 0, 3072); // 0.75
    g.set(0, 0, 0, 1024); // 0.25
    b.set(0, 0, 0, -4096); // -1.0
    a.set(0, 1, 0, 2048); // second row: exercises rowBytes
    r.set(0, 1, 0, 512); // 0.125
    g.set(0, 1, 0, 0);
    b.set(0, 1, 0, 16384); // 4.0

    const dest = try Img(Pixel_16F).init(allocator, 1, 2, 4);
    defer dest.deinit(allocator);
    try std.testing.expectEqual(@as(usize, 0), try planar16Q12ToARGB16F(&a.buf, &r.buf, &g.buf, &b.buf, &dest.buf, Flags.kvImageNoFlags));

    const want = [2][4]f16{ .{ 1.0, 0.75, 0.25, -1.0 }, .{ 0.5, 0.125, 0.0, 4.0 } };
    for (0..2) |y| for (0..4) |ch| {
        try std.testing.expectEqual(want[y][ch], half(dest.at(0, y, ch)));
    };
}

test "unsupported flag bits are rejected with kvImageUnknownFlagsBit" {
    // Conversion.h: the only flags these accept are kvImageDoNotTile and
    // kvImageGetTempBufferSize. kvImageEdgeExtend (8) is meaningless for a
    // format conversion, so it must be refused rather than ignored.
    const allocator = std.testing.allocator;
    const src = try Img(Pixel_8).init(allocator, 4, 1, 1);
    defer src.deinit(allocator);
    const dest = try Img(Pixel_16Q12).init(allocator, 4, 1, 1);
    defer dest.deinit(allocator);
    src.fillRow0(&[_]Pixel_8{ 255, 255, 255, 255 });

    try std.testing.expectError(
        VImageError.UnknownFlagsBit,
        convert8To16Q12(&src.buf, &dest.buf, Flags.kvImageEdgeExtend),
    );
    // No work was done.
    try std.testing.expectEqual(@as(Pixel_16Q12, 0), dest.at(0, 0, 0));

    // kvImageGetTempBufferSize reports 0: none of these need scratch space.
    try std.testing.expectEqual(
        @as(usize, 0),
        try convert8To16Q12(&src.buf, &dest.buf, Flags.kvImageGetTempBufferSize),
    );
    try std.testing.expectEqual(@as(Pixel_16Q12, 0), dest.at(0, 0, 0));

    // kvImageDoNotTile is accepted and does the work.
    _ = try convert8To16Q12(&src.buf, &dest.buf, Flags.kvImageDoNotTile);
    try std.testing.expectEqual(@as(Pixel_16Q12, 4096), dest.at(0, 0, 0));
}
