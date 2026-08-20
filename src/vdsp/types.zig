const std = @import("std");

pub const Stride = isize;
pub const Length = usize;

/// The raw C-ABI split-complex layout (`DSPSplitComplex` /
/// `DSPDoubleSplitComplex`): two bare pointers with no lengths attached.
///
/// This is the type vDSP itself speaks, so it stays exactly as the C header
/// declares it. Prefer `SplitSlice(T)` in your own code and let the wrappers
/// convert - see the note on `SplitSlice` for why.
pub fn SplitComplex(comptime T: type) type {
    return extern struct {
        realp: [*]T,
        imagp: [*]T,
    };
}

/// A split-complex buffer pair that carries its own length.
///
/// `SplitComplex(T)` is two raw pointers, so every vDSP function taking one
/// also takes a separate element count that nothing can validate: pass an `n`
/// larger than the buffers and the C function reads or writes past the end.
/// That is not a hypothetical - it is the shape of both hangs this binding's
/// audit uncovered (`vsorti`, and `zdotpr` writing through an uninitialized
/// `DSPSplitComplex`).
///
/// `SplitSlice(T)` closes that hole by keeping the lengths in the type. The
/// wrappers still take an explicit `n` wherever the C API does, because
/// operating on a prefix of a larger scratch buffer is normal in DSP code and
/// worth keeping; what changes is that `n` is now *checkable*, and every
/// wrapper asserts it against the actual buffer lengths.
pub fn SplitSlice(comptime T: type) type {
    return struct {
        const Self = @This();

        realp: []T,
        imagp: []T,

        pub fn init(realp: []T, imagp: []T) Self {
            std.debug.assert(realp.len == imagp.len);
            return .{ .realp = realp, .imagp = imagp };
        }

        /// Number of complex elements. The two component buffers must be the
        /// same length; a mismatch is a caller bug, not a representable state.
        pub fn len(self: Self) usize {
            std.debug.assert(self.realp.len == self.imagp.len);
            return self.realp.len;
        }

        /// The raw C-ABI view. The returned struct borrows this slice's
        /// storage, so it must not outlive the buffers it points into.
        pub fn raw(self: Self) SplitComplex(T) {
            return .{ .realp = self.realp.ptr, .imagp = self.imagp.ptr };
        }

        /// A sub-range `[start, end)`, lengths carried along.
        pub fn slice(self: Self, start: usize, end: usize) Self {
            return .{ .realp = self.realp[start..end], .imagp = self.imagp[start..end] };
        }

        pub fn at(self: Self, i: usize) Complex(T) {
            return .{ .real = self.realp[i], .imag = self.imagp[i] };
        }

        pub fn set(self: Self, i: usize, z: Complex(T)) void {
            self.realp[i] = z.real;
            self.imagp[i] = z.imag;
        }
    };
}

pub fn Complex(comptime T: type) type {
    return extern struct {
        const Self = @This();

        real: T,
        imag: T,

        pub fn init(re: T, im: T) Self {
            return .{ .real = re, .imag = im };
        }

        pub fn fromStd(z: std.math.Complex(T)) Self {
            return .{ .real = z.re, .imag = z.im };
        }

        pub fn toStd(self: Self) std.math.Complex(T) {
            return .{ .re = self.real, .im = self.imag };
        }
    };
}

pub const Int24 = extern struct {
    bytes: [3]u8,

    pub fn from(val: i24) Int24 {
        return .{ .bytes = @bitCast(val) };
    }

    pub fn to(self: Int24) i24 {
        return @bitCast(self.bytes);
    }

    pub fn toI32(self: Int24) i32 {
        return self.to();
    }
};

pub const UInt24 = extern struct {
    bytes: [3]u8,

    pub fn from(val: u24) UInt24 {
        return .{ .bytes = @bitCast(val) };
    }

    pub fn to(self: UInt24) u24 {
        return @bitCast(self.bytes);
    }

    pub fn toU32(self: UInt24) u32 {
        return self.to();
    }
};

pub const SortOrder = enum(c_int) { ascending = 1, descending = -1 };

pub const DbFlag = enum(c_uint) { power = 0, amplitude = 1 };

pub const WindowFlag = enum(c_int) {
    half_window = 1,
    hann_denorm = 0,
    hann_norm = 2,
};

// ============================================================================
// Tests
// ============================================================================

test "Complex(T).init, fromStd, toStd" {
    const c1 = Complex(f32).init(3.0, -4.0);
    try std.testing.expectEqual(@as(f32, 3.0), c1.real);
    try std.testing.expectEqual(@as(f32, -4.0), c1.imag);

    const std_z = std.math.Complex(f32){ .re = 1.5, .im = 2.5 };
    const c2 = Complex(f32).fromStd(std_z);
    try std.testing.expectEqual(@as(f32, 1.5), c2.real);
    try std.testing.expectEqual(@as(f32, 2.5), c2.imag);

    const back = c2.toStd();
    try std.testing.expectEqual(std_z.re, back.re);
    try std.testing.expectEqual(std_z.im, back.im);
}

test "Int24 round trip and toI32, full range including negatives" {
    // i24 range is [-8388608, 8388607]; verify the @bitCast round trip holds
    // at both extremes and at a negative asymmetric value, not just 0.
    const values = [_]i24{ -8388608, -100, 0, 100, 8388607 };
    for (values) |v| {
        const packed_val = Int24.from(v);
        try std.testing.expectEqual(v, packed_val.to());
        try std.testing.expectEqual(@as(i32, v), packed_val.toI32());
    }
}

test "UInt24 round trip and toU32, full range" {
    const values = [_]u24{ 0, 100, 8388607, 16777215 };
    for (values) |v| {
        const packed_val = UInt24.from(v);
        try std.testing.expectEqual(v, packed_val.to());
        try std.testing.expectEqual(@as(u32, v), packed_val.toU32());
    }
}

test "SplitSlice carries its own length and converts to the raw C view" {
    var re = [_]f32{ 1.0, 2.0, 3.0 };
    var im = [_]f32{ 4.0, 5.0, 6.0 };
    const ss = SplitSlice(f32).init(&re, &im);

    try std.testing.expectEqual(@as(usize, 3), ss.len());
    try std.testing.expectEqual(Complex(f32).init(2.0, 5.0), ss.at(1));

    // raw() must alias the same storage, not copy it: writing through the raw
    // view (which is what every wrapper hands to vDSP) has to be visible in
    // the caller's slices.
    const raw = ss.raw();
    raw.realp[0] = -1.0;
    raw.imagp[2] = -6.0;
    try std.testing.expectEqual(@as(f32, -1.0), re[0]);
    try std.testing.expectEqual(@as(f32, -6.0), im[2]);

    ss.set(0, Complex(f32).init(9.0, 9.0));
    try std.testing.expectEqual(@as(f32, 9.0), re[0]);

    const mid = ss.slice(1, 3);
    try std.testing.expectEqual(@as(usize, 2), mid.len());
    try std.testing.expectEqual(Complex(f32).init(2.0, 5.0), mid.at(0));
}
