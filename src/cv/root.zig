//! The slice of CoreVideo that vImage's `CVPixelBuffer` entry points need.
//!
//! Same ownership discipline as `accelerate.cg`: `*CVPixelBuffer` is a
//! borrowed pointer, `PixelBuffer` is an owned +1 reference with `deinit()`.
//!
//! Available only when the package is built with `-Dcoregraphics=true`.

const std = @import("std");
const cg = @import("../cg/root.zig");

const CFStringRef = cg.CFStringRef;
const CFTypeRef = cg.CFTypeRef;

// ============================================================================
// Scalars
// ============================================================================

/// `CVReturn` — 0 is success, everything else is a failure code.
pub const CVReturn = i32;
pub const CVOptionFlags = u64;

pub const CVError = error{
    /// `CVPixelBufferCreate` (or another CoreVideo call) returned non-zero.
    CoreVideoFailed,
};

/// Maps a `CVReturn` onto a Zig error. The specific code is not preserved —
/// CoreVideo's codes are not documented as a stable set — so use
/// `lastReturnCode`-style raw calls if you need the number.
pub inline fn check(r: CVReturn) CVError!void {
    if (r != 0) return CVError.CoreVideoFailed;
}

/// Packs a four-character code the way CoreVideo's `OSType` constants are
/// written, most significant byte first: `fourCC("BGRA") == 0x42475241`.
pub fn fourCC(comptime s: *const [4:0]u8) u32 {
    return (@as(u32, s[0]) << 24) | (@as(u32, s[1]) << 16) | (@as(u32, s[2]) << 8) | @as(u32, s[3]);
}

/// A subset of `kCVPixelFormatType_*`.
///
/// Note that CoreVideo does *not* encode every format as a four-character
/// code — the oldest ones are small integers (`kCVPixelFormatType_32ARGB` is
/// literally 32). Both kinds appear below, which is why the tag type is a
/// plain `u32` with an open enum rather than a character code.
pub const PixelFormat = enum(u32) {
    /// `kCVPixelFormatType_32ARGB` — 32-bit ARGB, and yes, the value is 32.
    argb32 = 32,
    /// `kCVPixelFormatType_32BGRA`.
    bgra32 = fourCC("BGRA"),
    /// `kCVPixelFormatType_32RGBA`.
    rgba32 = fourCC("RGBA"),
    /// `kCVPixelFormatType_24RGB` — the value is 24.
    rgb24 = 24,
    /// `kCVPixelFormatType_OneComponent8`.
    one_component8 = fourCC("L008"),
    /// `kCVPixelFormatType_TwoComponent8`.
    two_component8 = fourCC("2C08"),
    /// `kCVPixelFormatType_64ARGB`.
    argb64 = fourCC("b64a"),
    /// `kCVPixelFormatType_422YpCbCr8` — 2vuy, interleaved.
    ycbcr422_8 = fourCC("2vuy"),
    /// `kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange` — two planes,
    /// Y' then interleaved CbCr, video range.
    ycbcr420_biplanar_video = fourCC("420v"),
    /// `kCVPixelFormatType_420YpCbCr8BiPlanarFullRange`.
    ycbcr420_biplanar_full = fourCC("420f"),
    /// `kCVPixelFormatType_420YpCbCr8Planar` — three separate planes.
    ycbcr420_planar = fourCC("y420"),
    /// `kCVPixelFormatType_444YpCbCr8`.
    ycbcr444_8 = fourCC("v308"),
    _,

    pub fn code(self: PixelFormat) u32 {
        return @intFromEnum(self);
    }
};

// ============================================================================
// Chroma siting and matrix constants
// ============================================================================

/// `kCVImageBufferChromaLocation_*`, for
/// `vimage.cv.CVImageFormat.setChromaSiting`.
pub const ChromaLocation = struct {
    pub extern var kCVImageBufferChromaLocation_Left: CFStringRef;
    pub extern var kCVImageBufferChromaLocation_Center: CFStringRef;
    pub extern var kCVImageBufferChromaLocation_TopLeft: CFStringRef;
    pub extern var kCVImageBufferChromaLocation_Top: CFStringRef;
    pub extern var kCVImageBufferChromaLocation_BottomLeft: CFStringRef;
    pub extern var kCVImageBufferChromaLocation_Bottom: CFStringRef;
    pub extern var kCVImageBufferChromaLocation_DV420: CFStringRef;

    pub inline fn left() CFStringRef {
        return kCVImageBufferChromaLocation_Left;
    }
    pub inline fn center() CFStringRef {
        return kCVImageBufferChromaLocation_Center;
    }
    pub inline fn topLeft() CFStringRef {
        return kCVImageBufferChromaLocation_TopLeft;
    }
};

// ============================================================================
// CVPixelBuffer
// ============================================================================

pub const CVPixelBuffer = opaque {};
pub const CVPixelBufferRef = ?*CVPixelBuffer;

/// `kCVPixelBufferLock_ReadOnly`. Passing it lets CoreVideo skip
/// invalidating any cached GPU copy on unlock.
pub const lock_read_only: CVOptionFlags = 1;

pub extern fn CVPixelBufferCreate(
    allocator: ?*const anyopaque,
    width: usize,
    height: usize,
    pixelFormatType: u32,
    pixelBufferAttributes: ?*const anyopaque,
    pixelBufferOut: *CVPixelBufferRef,
) CVReturn;
pub extern fn CVPixelBufferRetain(buffer: CVPixelBufferRef) CVPixelBufferRef;
pub extern fn CVPixelBufferRelease(buffer: CVPixelBufferRef) void;
pub extern fn CVPixelBufferLockBaseAddress(buffer: *CVPixelBuffer, lockFlags: CVOptionFlags) CVReturn;
pub extern fn CVPixelBufferUnlockBaseAddress(buffer: *CVPixelBuffer, unlockFlags: CVOptionFlags) CVReturn;
pub extern fn CVPixelBufferGetWidth(buffer: *CVPixelBuffer) usize;
pub extern fn CVPixelBufferGetHeight(buffer: *CVPixelBuffer) usize;
pub extern fn CVPixelBufferGetPixelFormatType(buffer: *CVPixelBuffer) u32;
pub extern fn CVPixelBufferGetBaseAddress(buffer: *CVPixelBuffer) ?*anyopaque;
pub extern fn CVPixelBufferGetBytesPerRow(buffer: *CVPixelBuffer) usize;
pub extern fn CVPixelBufferIsPlanar(buffer: *CVPixelBuffer) u8;
pub extern fn CVPixelBufferGetPlaneCount(buffer: *CVPixelBuffer) usize;
pub extern fn CVPixelBufferGetBaseAddressOfPlane(buffer: *CVPixelBuffer, planeIndex: usize) ?*anyopaque;
pub extern fn CVPixelBufferGetBytesPerRowOfPlane(buffer: *CVPixelBuffer, planeIndex: usize) usize;
pub extern fn CVPixelBufferGetWidthOfPlane(buffer: *CVPixelBuffer, planeIndex: usize) usize;
pub extern fn CVPixelBufferGetHeightOfPlane(buffer: *CVPixelBuffer, planeIndex: usize) usize;
pub extern fn CVBufferSetAttachment(buffer: *CVPixelBuffer, key: CFStringRef, value: CFTypeRef, mode: u32) void;

/// An owned `CVPixelBufferRef`.
///
/// A pixel buffer's pixels are only addressable between
/// `lockBaseAddress` and `unlockBaseAddress`; outside that window
/// `baseAddress()` may return a pointer CoreVideo is free to move.
pub const PixelBuffer = struct {
    /// Borrowed for as long as this wrapper lives.
    ref: *CVPixelBuffer,

    /// `CVPixelBufferCreate` with the default allocator and no attributes.
    ///
    /// A buffer created this way is plain malloc-backed memory. Pass
    /// attributes through `initWithAttributes` if it has to be IOSurface- or
    /// Metal-compatible.
    pub fn init(image_width: usize, image_height: usize, format: PixelFormat) CVError!PixelBuffer {
        return initWithAttributes(image_width, image_height, format, null);
    }

    /// `CVPixelBufferCreate`. `attributes` is a borrowed `CFDictionaryRef`;
    /// building one is outside this package's scope, so it is typed as an
    /// opaque pointer you can pass through from elsewhere.
    pub fn initWithAttributes(
        image_width: usize,
        image_height: usize,
        format: PixelFormat,
        attributes: ?*const anyopaque,
    ) CVError!PixelBuffer {
        var out: CVPixelBufferRef = null;
        try check(CVPixelBufferCreate(null, image_width, image_height, format.code(), attributes, &out));
        return .{ .ref = out orelse return CVError.CoreVideoFailed };
    }

    /// Take ownership of an existing +1 reference without retaining.
    pub fn adopt(ref: *CVPixelBuffer) PixelBuffer {
        return .{ .ref = ref };
    }

    /// Retain a borrowed pointer and return it as an owned reference.
    pub fn borrow(ref: *CVPixelBuffer) PixelBuffer {
        _ = CVPixelBufferRetain(ref);
        return .{ .ref = ref };
    }

    pub fn retain(self: PixelBuffer) PixelBuffer {
        return borrow(self.ref);
    }

    /// `CVPixelBufferRelease`.
    pub fn deinit(self: PixelBuffer) void {
        CVPixelBufferRelease(self.ref);
    }

    /// `CVPixelBufferLockBaseAddress`. Pass `lock_read_only` when the buffer
    /// will only be read.
    pub fn lock(self: PixelBuffer, flags: CVOptionFlags) CVError!void {
        return check(CVPixelBufferLockBaseAddress(self.ref, flags));
    }

    /// `CVPixelBufferUnlockBaseAddress`. `flags` must match the `lock` call.
    pub fn unlock(self: PixelBuffer, flags: CVOptionFlags) CVError!void {
        return check(CVPixelBufferUnlockBaseAddress(self.ref, flags));
    }

    pub fn width(self: PixelBuffer) usize {
        return CVPixelBufferGetWidth(self.ref);
    }

    pub fn height(self: PixelBuffer) usize {
        return CVPixelBufferGetHeight(self.ref);
    }

    pub fn pixelFormat(self: PixelBuffer) PixelFormat {
        return @enumFromInt(CVPixelBufferGetPixelFormatType(self.ref));
    }

    /// Valid only while the buffer is locked. Null for a planar buffer — use
    /// `baseAddressOfPlane` there.
    pub fn baseAddress(self: PixelBuffer) ?*anyopaque {
        return CVPixelBufferGetBaseAddress(self.ref);
    }

    pub fn bytesPerRow(self: PixelBuffer) usize {
        return CVPixelBufferGetBytesPerRow(self.ref);
    }

    pub fn isPlanar(self: PixelBuffer) bool {
        return CVPixelBufferIsPlanar(self.ref) != 0;
    }

    /// 0 for a non-planar buffer, not 1.
    pub fn planeCount(self: PixelBuffer) usize {
        return CVPixelBufferGetPlaneCount(self.ref);
    }

    pub fn baseAddressOfPlane(self: PixelBuffer, plane: usize) ?*anyopaque {
        return CVPixelBufferGetBaseAddressOfPlane(self.ref, plane);
    }

    pub fn bytesPerRowOfPlane(self: PixelBuffer, plane: usize) usize {
        return CVPixelBufferGetBytesPerRowOfPlane(self.ref, plane);
    }

    pub fn widthOfPlane(self: PixelBuffer, plane: usize) usize {
        return CVPixelBufferGetWidthOfPlane(self.ref, plane);
    }

    pub fn heightOfPlane(self: PixelBuffer, plane: usize) usize {
        return CVPixelBufferGetHeightOfPlane(self.ref, plane);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "fourCC packs most significant byte first" {
    const testing = std.testing;
    try testing.expectEqual(@as(u32, 0x42475241), fourCC("BGRA"));
    try testing.expectEqual(@as(u32, 0x34323076), fourCC("420v"));
    // The old formats are not character codes at all.
    try testing.expectEqual(@as(u32, 32), @intFromEnum(PixelFormat.argb32));
    try testing.expectEqual(@as(u32, 24), @intFromEnum(PixelFormat.rgb24));
}

test "a 32BGRA pixel buffer reports its own geometry back" {
    const testing = std.testing;
    const pb = try PixelBuffer.init(16, 8, .bgra32);
    defer pb.deinit();

    try testing.expectEqual(@as(usize, 16), pb.width());
    try testing.expectEqual(@as(usize, 8), pb.height());
    try testing.expectEqual(PixelFormat.bgra32, pb.pixelFormat());
    try testing.expect(!pb.isPlanar());
    // A non-planar buffer reports 0 planes, not 1.
    try testing.expectEqual(@as(usize, 0), pb.planeCount());
    try testing.expect(pb.bytesPerRow() >= 16 * 4);
}

test "pixels are addressable between lock and unlock" {
    const testing = std.testing;
    const pb = try PixelBuffer.init(4, 4, .bgra32);
    defer pb.deinit();

    try pb.lock(0);
    defer pb.unlock(0) catch {};

    const base = pb.baseAddress() orelse return error.UnexpectedNull;
    const stride = pb.bytesPerRow();
    const bytes: [*]u8 = @ptrCast(base);
    @memset(bytes[0 .. stride * 4], 0);
    bytes[0] = 0xAB;
    try testing.expectEqual(@as(u8, 0xAB), bytes[0]);
}

test "a 420v buffer is planar with a full-size luma plane and half-size chroma" {
    const testing = std.testing;
    const pb = try PixelBuffer.init(16, 8, .ycbcr420_biplanar_video);
    defer pb.deinit();

    try testing.expect(pb.isPlanar());
    try testing.expectEqual(@as(usize, 2), pb.planeCount());
    try testing.expectEqual(@as(usize, 16), pb.widthOfPlane(0));
    try testing.expectEqual(@as(usize, 8), pb.heightOfPlane(0));
    // Plane 1 is interleaved CbCr at half resolution in both directions.
    try testing.expectEqual(@as(usize, 8), pb.widthOfPlane(1));
    try testing.expectEqual(@as(usize, 4), pb.heightOfPlane(1));

    try pb.lock(0);
    defer pb.unlock(0) catch {};
    try testing.expect(pb.baseAddressOfPlane(0) != null);
    try testing.expect(pb.baseAddressOfPlane(1) != null);
}

test "retain and release balance out" {
    const testing = std.testing;
    const pb = try PixelBuffer.init(4, 4, .bgra32);
    defer pb.deinit();
    const before = cg.CFGetRetainCount(pb.ref);
    const second = pb.retain();
    try testing.expectEqual(before + 1, cg.CFGetRetainCount(pb.ref));
    second.deinit();
    try testing.expectEqual(before, cg.CFGetRetainCount(pb.ref));
}
