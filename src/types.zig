const std = @import("std");

pub const Stride = isize;
pub const Length = usize;

pub fn SplitComplex(comptime T: type) type {
    return extern struct {
        realp: [*]T,
        imagp: [*]T,
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
