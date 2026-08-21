//! The slice of CoreFoundation and CoreGraphics that vImage's CGImage-facing
//! entry points need, and nothing more.
//!
//! This is not a CoreGraphics binding. It exists so that
//! `vimage.utilities` and `vimage.cv` can take and return real `CGImageRef`s
//! and `CGColorSpaceRef`s instead of `*anyopaque`, and so a caller can build
//! the handful of objects those functions require without dropping to C.
//!
//! ## Ownership is in the type
//!
//! CoreFoundation's rule is the "Create Rule": a function with `Create` or
//! `Copy` in its name hands you a +1 reference that you must release, and any
//! other function hands you a borrowed reference that you must not. Getting
//! this wrong is an over-release crash or a leak, and C gives you the same
//! `CGImageRef` for both cases.
//!
//! Here the two cases are different Zig types:
//!
//! * `*CGImage`, `*CGColorSpace`, ... — a **borrowed** pointer. You do not own
//!   a reference; do not release it. Every getter returns this form, and every
//!   function that merely reads an object takes this form.
//! * `Image`, `ColorSpace`, ... — an **owned** +1 reference, with `deinit()`.
//!   Every constructor returns this form.
//!
//! To go from borrowed to owned, use `Image.borrow(ptr)` — it retains. To go
//! the other way, read `.ref`, which stays borrowed for as long as the wrapper
//! lives. `Image.adopt(ptr)` takes ownership of an existing +1 without
//! retaining, for pointers that came out of a C `Create` call directly.
//!
//! Available only when the package is built with `-Dcoregraphics=true`.

const std = @import("std");

// ============================================================================
// Scalar and CoreFoundation types
// ============================================================================

/// `CGFloat` — `double` on every 64-bit Apple platform, `float` on 32-bit.
pub const CGFloat = if (@sizeOf(usize) == 8) f64 else f32;

/// `CGSize`.
pub const CGSize = extern struct {
    width: CGFloat,
    height: CGFloat,
};

/// `CGPoint`.
pub const CGPoint = extern struct {
    x: CGFloat,
    y: CGFloat,
};

/// `CGRect`.
pub const CGRect = extern struct {
    origin: CGPoint,
    size: CGSize,
};

/// An opaque CoreFoundation object. Used for the parameters vImage types as a
/// bare `CFTypeRef`, and as the common base every `CF*Ref` here erases to.
pub const CFType = opaque {};
pub const CFTypeRef = ?*CFType;

/// `CFStringRef`. vImage only ever passes these through — the chroma-siting
/// and colour-space name constants — so no string API is bound.
pub const CFString = opaque {};
pub const CFStringRef = ?*const CFString;

pub extern fn CFRetain(cf: *const anyopaque) *const anyopaque;
pub extern fn CFRelease(cf: *const anyopaque) void;
pub extern fn CFEqual(a: *const anyopaque, b: *const anyopaque) u8;
pub extern fn CFGetRetainCount(cf: *const anyopaque) isize;

/// Whether two CoreFoundation objects are equal.
///
/// `CFEqual` returns a `Boolean`, which is a `signed char` — not a `_Bool` —
/// so it has to be compared against zero rather than reinterpreted.
pub inline fn equal(a: *const anyopaque, b: *const anyopaque) bool {
    return CFEqual(a, b) != 0;
}

// ============================================================================
// Errors
// ============================================================================

/// The only failure a CoreGraphics constructor reports is a null return; there
/// is no error code to unpack.
pub const CGError = error{
    /// A CoreGraphics `Create` call returned NULL.
    CoreGraphicsCreateFailed,
};

// ============================================================================
// Bitmap info
// ============================================================================

/// `CGImageAlphaInfo` — where the alpha channel sits in a pixel, and whether
/// the colour channels are premultiplied by it.
pub const AlphaInfo = enum(u5) {
    /// No alpha channel.
    none = 0,
    /// Alpha last, colour channels premultiplied (e.g. RGBA, premultiplied).
    premultiplied_last = 1,
    /// Alpha first, colour channels premultiplied (e.g. ARGB, premultiplied).
    premultiplied_first = 2,
    /// Alpha last, not premultiplied.
    last = 3,
    /// Alpha first, not premultiplied.
    first = 4,
    /// A padding byte last; its contents are ignored (e.g. RGBX).
    none_skip_last = 5,
    /// A padding byte first; its contents are ignored (e.g. XRGB).
    none_skip_first = 6,
    /// Alpha only, no colour channels.
    only = 7,
    _,
};

/// The byte-order swap applied within a pixel. The swap chunk size must match
/// the pixel size, which is what gives access to formats like BGRA8888.
pub const ByteOrder = enum(u3) {
    default = 0,
    /// `kCGBitmapByteOrder16Little` (0x1000).
    little16 = 1,
    /// `kCGBitmapByteOrder32Little` (0x2000).
    little32 = 2,
    /// `kCGBitmapByteOrder16Big` (0x3000).
    big16 = 3,
    /// `kCGBitmapByteOrder32Big` (0x4000).
    big32 = 4,
    _,
};

/// `CGBitmapInfo` as a bitfield rather than an integer.
///
/// CoreGraphics packs three unrelated things into one `uint32_t`: a 5-bit
/// alpha-info enum in the low bits, a float-components flag at bit 8, and a
/// 3-bit byte-order enum at bits 12-14. Composing that by hand with `|` is
/// where BGRA-vs-RGBA mistakes come from.
pub const BitmapInfo = packed struct(u32) {
    alpha: AlphaInfo = .none,
    _reserved_5: u3 = 0,
    /// `kCGBitmapFloatComponents` (0x100) — components are `float`, not
    /// integers.
    float_components: bool = false,
    _reserved_9: u3 = 0,
    byte_order: ByteOrder = .default,
    _reserved_15: u17 = 0,

    pub fn bits(self: BitmapInfo) u32 {
        return @bitCast(self);
    }

    pub fn from(raw: u32) BitmapInfo {
        return @bitCast(raw);
    }
};

/// `CGColorRenderingIntent`. By convention CoreGraphics ignores a rendering
/// intent change that is not accompanied by a colour space change.
pub const RenderingIntent = enum(i32) {
    default = 0,
    absolute_colorimetric = 1,
    relative_colorimetric = 2,
    perceptual = 3,
    saturation = 4,
    _,
};

/// `CGColorSpaceModel`. `unknown` is -1, so the tag type must be signed.
pub const ColorSpaceModel = enum(i32) {
    unknown = -1,
    monochrome = 0,
    rgb = 1,
    cmyk = 2,
    lab = 3,
    device_n = 4,
    indexed = 5,
    pattern = 6,
    xyz = 7,
    _,
};

// ============================================================================
// CGColorSpace
// ============================================================================

pub const CGColorSpace = opaque {};
pub const CGColorSpaceRef = ?*CGColorSpace;

pub extern fn CGColorSpaceCreateDeviceRGB() CGColorSpaceRef;
pub extern fn CGColorSpaceCreateDeviceGray() CGColorSpaceRef;
pub extern fn CGColorSpaceCreateDeviceCMYK() CGColorSpaceRef;
pub extern fn CGColorSpaceCreateWithName(name: CFStringRef) CGColorSpaceRef;
pub extern fn CGColorSpaceRetain(space: CGColorSpaceRef) CGColorSpaceRef;
pub extern fn CGColorSpaceRelease(space: CGColorSpaceRef) void;
pub extern fn CGColorSpaceGetNumberOfComponents(space: *const CGColorSpace) usize;
pub extern fn CGColorSpaceGetModel(space: *const CGColorSpace) ColorSpaceModel;
pub extern fn CGColorSpaceGetName(space: *const CGColorSpace) CFStringRef;

/// The colour-space name constants, for `ColorSpace.named`.
///
/// These are `CFStringRef` globals, so each is a pointer-sized variable
/// holding the string — hence `extern var` of pointer type rather than
/// `extern const` of the string itself.
pub const ColorSpaceName = struct {
    pub extern var kCGColorSpaceSRGB: CFStringRef;
    pub extern var kCGColorSpaceGenericRGBLinear: CFStringRef;
    pub extern var kCGColorSpaceGenericGrayGamma2_2: CFStringRef;
    pub extern var kCGColorSpaceLinearGray: CFStringRef;
    pub extern var kCGColorSpaceDisplayP3: CFStringRef;
    pub extern var kCGColorSpaceExtendedLinearSRGB: CFStringRef;
    pub extern var kCGColorSpaceITUR_709: CFStringRef;
    pub extern var kCGColorSpaceITUR_2020: CFStringRef;

    pub inline fn srgb() CFStringRef {
        return kCGColorSpaceSRGB;
    }
    pub inline fn displayP3() CFStringRef {
        return kCGColorSpaceDisplayP3;
    }
    pub inline fn genericGrayGamma2_2() CFStringRef {
        return kCGColorSpaceGenericGrayGamma2_2;
    }
    pub inline fn itur709() CFStringRef {
        return kCGColorSpaceITUR_709;
    }
    pub inline fn itur2020() CFStringRef {
        return kCGColorSpaceITUR_2020;
    }
};

/// An owned `CGColorSpaceRef`.
pub const ColorSpace = struct {
    /// Borrowed for as long as this wrapper lives. Pass it to functions that
    /// take a colour space; do not release it.
    ref: *CGColorSpace,

    /// Take ownership of an existing +1 reference without retaining.
    pub fn adopt(ref: *CGColorSpace) ColorSpace {
        return .{ .ref = ref };
    }

    /// Retain a borrowed pointer and return it as an owned reference.
    pub fn borrow(ref: *CGColorSpace) ColorSpace {
        _ = CGColorSpaceRetain(ref);
        return .{ .ref = ref };
    }

    /// `CGColorSpaceCreateDeviceRGB`.
    pub fn deviceRGB() CGError!ColorSpace {
        return adopt(CGColorSpaceCreateDeviceRGB() orelse return CGError.CoreGraphicsCreateFailed);
    }

    /// `CGColorSpaceCreateDeviceGray`.
    pub fn deviceGray() CGError!ColorSpace {
        return adopt(CGColorSpaceCreateDeviceGray() orelse return CGError.CoreGraphicsCreateFailed);
    }

    /// `CGColorSpaceCreateDeviceCMYK`.
    pub fn deviceCMYK() CGError!ColorSpace {
        return adopt(CGColorSpaceCreateDeviceCMYK() orelse return CGError.CoreGraphicsCreateFailed);
    }

    /// `CGColorSpaceCreateWithName`, e.g. `ColorSpaceName.srgb()`.
    pub fn named(space_name: CFStringRef) CGError!ColorSpace {
        return adopt(CGColorSpaceCreateWithName(space_name) orelse return CGError.CoreGraphicsCreateFailed);
    }

    /// A second owned reference to the same colour space.
    pub fn retain(self: ColorSpace) ColorSpace {
        return borrow(self.ref);
    }

    /// `CGColorSpaceRelease`.
    pub fn deinit(self: ColorSpace) void {
        CGColorSpaceRelease(self.ref);
    }

    /// The number of colour components, not counting alpha — 3 for RGB, 1 for
    /// grayscale, 4 for CMYK.
    pub fn componentCount(self: ColorSpace) usize {
        return CGColorSpaceGetNumberOfComponents(self.ref);
    }

    pub fn model(self: ColorSpace) ColorSpaceModel {
        return CGColorSpaceGetModel(self.ref);
    }

    /// The colour space's name, or null for an unnamed (e.g. device) space.
    /// Borrowed.
    pub fn name(self: ColorSpace) CFStringRef {
        return CGColorSpaceGetName(self.ref);
    }
};

// ============================================================================
// CGImage
// ============================================================================

pub const CGImage = opaque {};
pub const CGImageRef = ?*CGImage;

pub extern fn CGImageRetain(image: CGImageRef) CGImageRef;
pub extern fn CGImageRelease(image: CGImageRef) void;
pub extern fn CGImageGetWidth(image: *const CGImage) usize;
pub extern fn CGImageGetHeight(image: *const CGImage) usize;
pub extern fn CGImageGetBitsPerComponent(image: *const CGImage) usize;
pub extern fn CGImageGetBitsPerPixel(image: *const CGImage) usize;
pub extern fn CGImageGetBytesPerRow(image: *const CGImage) usize;
pub extern fn CGImageGetColorSpace(image: *const CGImage) CGColorSpaceRef;
pub extern fn CGImageGetBitmapInfo(image: *const CGImage) BitmapInfo;
pub extern fn CGImageGetAlphaInfo(image: *const CGImage) u32;
pub extern fn CGImageGetRenderingIntent(image: *const CGImage) RenderingIntent;
pub extern fn CGImageGetDecode(image: *const CGImage) ?[*]const CGFloat;
pub extern fn CGImageIsMask(image: *const CGImage) u8;

/// An owned `CGImageRef`.
pub const Image = struct {
    /// Borrowed for as long as this wrapper lives.
    ref: *CGImage,

    /// Take ownership of an existing +1 reference without retaining. This is
    /// what `vimage.utilities.createCGImageFromBuffer` uses, because
    /// `vImageCreateCGImageFromBuffer` is a Create function.
    pub fn adopt(ref: *CGImage) Image {
        return .{ .ref = ref };
    }

    /// Retain a borrowed pointer and return it as an owned reference.
    pub fn borrow(ref: *CGImage) Image {
        _ = CGImageRetain(ref);
        return .{ .ref = ref };
    }

    pub fn retain(self: Image) Image {
        return borrow(self.ref);
    }

    /// `CGImageRelease`.
    pub fn deinit(self: Image) void {
        CGImageRelease(self.ref);
    }

    pub fn width(self: Image) usize {
        return CGImageGetWidth(self.ref);
    }

    pub fn height(self: Image) usize {
        return CGImageGetHeight(self.ref);
    }

    pub fn bitsPerComponent(self: Image) usize {
        return CGImageGetBitsPerComponent(self.ref);
    }

    pub fn bitsPerPixel(self: Image) usize {
        return CGImageGetBitsPerPixel(self.ref);
    }

    pub fn bytesPerRow(self: Image) usize {
        return CGImageGetBytesPerRow(self.ref);
    }

    /// The image's colour space, **borrowed**. Wrap it with
    /// `ColorSpace.borrow` if it needs to outlive the image.
    pub fn colorSpace(self: Image) ?*CGColorSpace {
        return CGImageGetColorSpace(self.ref);
    }

    pub fn bitmapInfo(self: Image) BitmapInfo {
        return CGImageGetBitmapInfo(self.ref);
    }

    /// Equivalent to `bitmapInfo().alpha`; kept because CoreGraphics exposes
    /// it as its own entry point.
    pub fn alphaInfo(self: Image) AlphaInfo {
        return @enumFromInt(@as(u5, @truncate(CGImageGetAlphaInfo(self.ref))));
    }

    pub fn renderingIntent(self: Image) RenderingIntent {
        return CGImageGetRenderingIntent(self.ref);
    }

    /// The decode array, borrowed, or null for the default range.
    pub fn decode(self: Image) ?[*]const CGFloat {
        return CGImageGetDecode(self.ref);
    }

    pub fn isMask(self: Image) bool {
        return CGImageIsMask(self.ref) != 0;
    }
};

// ============================================================================
// CGColorConversionInfo
// ============================================================================

pub const CGColorConversionInfo = opaque {};
pub const CGColorConversionInfoRef = ?*CGColorConversionInfo;

pub extern fn CGColorConversionInfoCreate(src: *const CGColorSpace, dst: *const CGColorSpace) CGColorConversionInfoRef;

/// An owned `CGColorConversionInfoRef`, for
/// `vimage.utilities.Converter.createWithCGColorConversionInfo`.
///
/// `CGColorConversionInfo` is a CFType with no dedicated release function, so
/// `deinit` calls `CFRelease` directly.
///
/// Both colour spaces must have defined colorimetry — a *device* colour space
/// is rejected with a null return.
pub const ColorConversionInfo = struct {
    ref: *CGColorConversionInfo,

    /// `CGColorConversionInfoCreate`.
    pub fn init(src: *const CGColorSpace, dst: *const CGColorSpace) CGError!ColorConversionInfo {
        return .{ .ref = CGColorConversionInfoCreate(src, dst) orelse return CGError.CoreGraphicsCreateFailed };
    }

    pub fn adopt(ref: *CGColorConversionInfo) ColorConversionInfo {
        return .{ .ref = ref };
    }

    pub fn borrow(ref: *CGColorConversionInfo) ColorConversionInfo {
        _ = CFRetain(ref);
        return .{ .ref = ref };
    }

    pub fn deinit(self: ColorConversionInfo) void {
        CFRelease(self.ref);
    }
};

// ============================================================================
// Tests
// ============================================================================

test "struct layouts match CoreGraphics" {
    const testing = std.testing;
    // Measured against <CoreGraphics/CoreGraphics.h> with clang on
    // macOS 15.7 / arm64.
    try testing.expectEqual(@as(usize, 8), @sizeOf(CGFloat));
    try testing.expectEqual(@as(usize, 16), @sizeOf(CGSize));
    try testing.expectEqual(@as(usize, 16), @sizeOf(CGPoint));
    try testing.expectEqual(@as(usize, 32), @sizeOf(CGRect));
    try testing.expectEqual(@as(usize, 4), @sizeOf(BitmapInfo));
    try testing.expectEqual(@as(usize, 4), @sizeOf(RenderingIntent));
}

test "BitmapInfo bit positions match the kCGBitmap* constants" {
    const testing = std.testing;
    // Values printed by a C program including <CoreGraphics/CoreGraphics.h>.
    try testing.expectEqual(@as(u32, 0), (BitmapInfo{}).bits());
    try testing.expectEqual(@as(u32, 1), (BitmapInfo{ .alpha = .premultiplied_last }).bits());
    try testing.expectEqual(@as(u32, 2), (BitmapInfo{ .alpha = .premultiplied_first }).bits());
    try testing.expectEqual(@as(u32, 7), (BitmapInfo{ .alpha = .only }).bits());
    try testing.expectEqual(@as(u32, 256), (BitmapInfo{ .float_components = true }).bits());
    try testing.expectEqual(@as(u32, 4096), (BitmapInfo{ .byte_order = .little16 }).bits());
    try testing.expectEqual(@as(u32, 8192), (BitmapInfo{ .byte_order = .little32 }).bits());
    try testing.expectEqual(@as(u32, 12288), (BitmapInfo{ .byte_order = .big16 }).bits());
    try testing.expectEqual(@as(u32, 16384), (BitmapInfo{ .byte_order = .big32 }).bits());

    // kCGBitmapAlphaInfoMask is 0x1F and kCGBitmapByteOrderMask is 0x7000 —
    // the two fields do not overlap, and a BGRA8888 descriptor is exactly
    // their OR.
    const bgra = BitmapInfo{ .alpha = .premultiplied_first, .byte_order = .little32 };
    try testing.expectEqual(@as(u32, 2 | 8192), bgra.bits());
    try testing.expectEqual(bgra, BitmapInfo.from(bgra.bits()));
}

test "a device RGB colour space reports 3 components and the RGB model" {
    const testing = std.testing;
    const cs = try ColorSpace.deviceRGB();
    defer cs.deinit();
    try testing.expectEqual(@as(usize, 3), cs.componentCount());
    try testing.expectEqual(ColorSpaceModel.rgb, cs.model());
}

test "device gray is 1 component, CMYK is 4" {
    const testing = std.testing;
    const gray = try ColorSpace.deviceGray();
    defer gray.deinit();
    try testing.expectEqual(@as(usize, 1), gray.componentCount());
    try testing.expectEqual(ColorSpaceModel.monochrome, gray.model());

    const cmyk = try ColorSpace.deviceCMYK();
    defer cmyk.deinit();
    try testing.expectEqual(@as(usize, 4), cmyk.componentCount());
    try testing.expectEqual(ColorSpaceModel.cmyk, cmyk.model());
}

test "a named colour space round-trips its name" {
    const testing = std.testing;
    const cs = try ColorSpace.named(ColorSpaceName.srgb());
    defer cs.deinit();
    try testing.expectEqual(@as(usize, 3), cs.componentCount());
    const n = cs.name() orelse return error.UnexpectedNull;
    // CFStringRef constants are interned, but compare by value rather than
    // relying on that.
    try testing.expect(equal(n, ColorSpaceName.srgb().?));
}

test "the stock colour spaces are immortal singletons" {
    const testing = std.testing;
    // Measured on macOS 15.7 / arm64: both `CGColorSpaceCreateDeviceRGB` and
    // `CGColorSpaceCreateWithName` hand back a cached object whose retain
    // count reads 0xFFFFFFFF and does not move when retained or released.
    //
    // This matters for the ownership convention: they still follow the Create
    // Rule and must still be released, but a retain-count assertion is not a
    // way to test that here. The balancing tests live on objects that are
    // genuinely reference counted — `utilities.Converter`,
    // `cv.PixelBuffer` and `vimage.cv.CVImageFormat`.
    const immortal: isize = 0xFFFF_FFFF;

    const dev = try ColorSpace.deviceRGB();
    defer dev.deinit();
    try testing.expectEqual(immortal, CFGetRetainCount(dev.ref));

    const second = dev.retain();
    try testing.expectEqual(immortal, CFGetRetainCount(dev.ref));
    second.deinit();
    try testing.expectEqual(immortal, CFGetRetainCount(dev.ref));

    const srgb = try ColorSpace.named(ColorSpaceName.srgb());
    defer srgb.deinit();
    try testing.expectEqual(immortal, CFGetRetainCount(srgb.ref));

    // Asking twice returns the same object, which is what makes the count
    // meaningless rather than merely large.
    const srgb_again = try ColorSpace.named(ColorSpaceName.srgb());
    defer srgb_again.deinit();
    try testing.expectEqual(srgb.ref, srgb_again.ref);
}

test "a colour conversion info can be built between two named spaces" {
    const testing = std.testing;
    const src = try ColorSpace.named(ColorSpaceName.srgb());
    defer src.deinit();
    const dst = try ColorSpace.named(ColorSpaceName.displayP3());
    defer dst.deinit();

    const info = try ColorConversionInfo.init(src.ref, dst.ref);
    defer info.deinit();

    // A device colour space has no defined colorimetry, so CoreGraphics has
    // nothing to build a transform from and returns NULL rather than an
    // error code. Measured, and the reason `init` reports a plain
    // `CoreGraphicsCreateFailed`.
    const device = try ColorSpace.deviceRGB();
    defer device.deinit();
    try testing.expectError(CGError.CoreGraphicsCreateFailed, ColorConversionInfo.init(device.ref, dst.ref));
}
