pub const Stride = isize;
pub const Length = usize;

pub const SplitComplex = extern struct {
    realp: [*]f32,
    imagp: [*]f32,
};

pub const DoubleSplitComplex = extern struct {
    realp: [*]f64,
    imagp: [*]f64,
};

pub const SortOrder = enum(c_int) { ascending = 1, descending = -1 };

pub const DbFlag = enum(c_uint) { power = 0, amplitude = 1 };

pub const WindowFlag = enum(c_int) {
    half_window = 1,
    hann_denorm = 0,
    hann_norm = 2,
};
