//! Shared types for the CBLAS bindings.
//!
//! ## Which BLAS this binds
//!
//! Accelerate ships three ABI variants of every CBLAS routine:
//!
//! | Mach-O symbol | Interface | Index type |
//! |---|---|---|
//! | `_cblas_sgemm` | legacy | `int` |
//! | `_cblas_sgemm$NEWLAPACK` | current, LP64 | `int` |
//! | `_cblas_sgemm$NEWLAPACK$ILP64` | current, ILP64 | `long` |
//!
//! The unsuffixed one is what `cblas.h` declares, and that whole header is
//! `API_DEPRECATED` since macOS 13.3: *"An updated CBLAS interface supporting
//! ILP64 is available. Please compile with -DACCELERATE_NEW_LAPACK ..."*. The
//! suffixed ones are what `cblas_new.h` reaches via
//! `__LAPACK_ALIAS(sym)`, which expands to
//! `__asm("_" #sym "$NEWLAPACK" ["$ILP64"])`.
//!
//! This binding targets the **current** interface, and selects ILP64 wherever
//! Accelerate offers it. `lapack_version.h` gates the `$ILP64` suffix on
//! `__arm64__ || __x86_64__`, so `alias_suffix` below reproduces exactly that
//! test - on any other target the symbol is the LP64 one and `Int` narrows to
//! match. Getting this pairing wrong would not fail to link; it would pass
//! 64-bit dimensions to a routine reading 32-bit ones.

const std = @import("std");
const builtin = @import("builtin");

/// Whether Accelerate provides ILP64 symbols for this target.
///
/// Mirrors the `#if defined(__arm64__) || defined(__x86_64__)` in
/// `lapack_version.h` that guards `__LAPACK_SUFFIX_ILP64`.
pub const use_ilp64 = switch (builtin.target.cpu.arch) {
    .aarch64, .aarch64_be, .x86_64 => true,
    else => false,
};

/// The suffix appended to every symbol name in `c.zig`.
pub const alias_suffix = if (use_ilp64) "$NEWLAPACK$ILP64" else "$NEWLAPACK";

/// `__LAPACK_int` - the integer type the selected symbols actually read.
pub const Int = if (use_ilp64) i64 else i32;

/// Interleaved complex, ABI-compatible with C's `float _Complex` /
/// `double _Complex` for the only way CBLAS uses them: behind a pointer.
///
/// No CBLAS entry point passes or returns a complex by value - complex scalars
/// go in as `const T *` and complex results come back through an out-parameter
/// (`cblas_cdotu_sub` and friends). That is why a plain `extern struct` is
/// sufficient here and the `_Complex` calling convention never comes up.
pub fn Complex(comptime T: type) type {
    return extern struct {
        const Self = @This();

        re: T,
        im: T,

        pub fn init(re: T, im: T) Self {
            return .{ .re = re, .im = im };
        }

        pub const zero: Self = .{ .re = 0, .im = 0 };
        pub const one: Self = .{ .re = 1, .im = 0 };

        pub fn add(a: Self, b: Self) Self {
            return .{ .re = a.re + b.re, .im = a.im + b.im };
        }

        pub fn mul(a: Self, b: Self) Self {
            return .{
                .re = a.re * b.re - a.im * b.im,
                .im = a.re * b.im + a.im * b.re,
            };
        }

        pub fn conj(a: Self) Self {
            return .{ .re = a.re, .im = -a.im };
        }

        pub fn abs(a: Self) T {
            return @sqrt(a.re * a.re + a.im * a.im);
        }

        pub fn eqlApprox(a: Self, b: Self, tolerance: T) bool {
            return @abs(a.re - b.re) <= tolerance and @abs(a.im - b.im) <= tolerance;
        }
    };
}

/// Storage order of a dense matrix. CBLAS accepts either; the Fortran BLAS
/// underneath is column-major, and Accelerate transposes the problem for you
/// when you ask for row-major.
pub const Order = enum(c_int) {
    row_major = 101,
    col_major = 102,
};

pub const Transpose = enum(c_int) {
    no_trans = 111,
    trans = 112,
    /// Conjugate transpose. For a real matrix this is the same as `.trans`.
    conj_trans = 113,
};

/// Which triangle of a symmetric, Hermitian or triangular matrix is stored.
pub const Uplo = enum(c_int) {
    upper = 121,
    lower = 122,
};

/// Whether a triangular matrix has an implicit unit diagonal.
pub const Diag = enum(c_int) {
    non_unit = 131,
    unit = 132,
};

/// Which side the triangular or symmetric operand multiplies from.
pub const Side = enum(c_int) {
    left = 141,
    right = 142,
};

/// The scalar type underlying `T`: `f32` for `f32` and `Complex(f32)`.
pub fn Scalar(comptime T: type) type {
    return switch (T) {
        f32, f64 => T,
        Complex(f32) => f32,
        Complex(f64) => f64,
        else => @compileError("BLAS supports f32, f64, Complex(f32) and Complex(f64), got " ++ @typeName(T)),
    };
}

/// Whether `T` is one of the two complex element types.
pub fn isComplex(comptime T: type) bool {
    return T == Complex(f32) or T == Complex(f64);
}

/// Narrows a `usize` dimension to `Int`, trapping on overflow in safe modes.
///
/// This is the one place the ILP64/LP64 choice becomes visible: on an LP64
/// target a dimension above 2^31 cannot be expressed, and silently truncating
/// it would produce a wrong answer rather than an error.
pub fn dim(n: usize) Int {
    std.debug.assert(n <= std.math.maxInt(Int));
    return @intCast(n);
}

/// Narrows a signed increment (which BLAS allows to be negative, meaning the
/// vector is traversed backwards).
pub fn inc(i: isize) Int {
    std.debug.assert(i >= std.math.minInt(Int) and i <= std.math.maxInt(Int));
    return @intCast(i);
}

/// Elements a vector of `n` entries with stride `incx` must contain.
///
/// BLAS reads `x[i * |incx|]` for `i` in `0..n`, in either direction, so the
/// span is the same for a negative stride.
pub fn vectorLen(n: usize, incx: isize) usize {
    if (n == 0) return 0;
    const step: usize = @abs(incx);
    std.debug.assert(step != 0);
    return (n - 1) * step + 1;
}

/// Elements a `rows x cols` matrix with leading dimension `ld` must contain,
/// under `order`.
///
/// Only the last row (row-major) or column (column-major) needs fewer than a
/// full `ld` entries, which is why this is not `rows * ld`.
pub fn matrixLen(order: Order, rows: usize, cols: usize, ld: usize) usize {
    if (rows == 0 or cols == 0) return 0;
    return switch (order) {
        .row_major => blk: {
            std.debug.assert(ld >= cols);
            break :blk (rows - 1) * ld + cols;
        },
        .col_major => blk: {
            std.debug.assert(ld >= rows);
            break :blk (cols - 1) * ld + rows;
        },
    };
}

/// Elements a packed triangular matrix of order `n` contains: `n(n+1)/2`.
pub fn packedLen(n: usize) usize {
    return n * (n + 1) / 2;
}

test "enum values match cblas.h" {
    const expectEqual = std.testing.expectEqual;
    try expectEqual(@as(c_int, 101), @intFromEnum(Order.row_major));
    try expectEqual(@as(c_int, 102), @intFromEnum(Order.col_major));
    try expectEqual(@as(c_int, 111), @intFromEnum(Transpose.no_trans));
    try expectEqual(@as(c_int, 112), @intFromEnum(Transpose.trans));
    try expectEqual(@as(c_int, 113), @intFromEnum(Transpose.conj_trans));
    try expectEqual(@as(c_int, 121), @intFromEnum(Uplo.upper));
    try expectEqual(@as(c_int, 122), @intFromEnum(Uplo.lower));
    try expectEqual(@as(c_int, 131), @intFromEnum(Diag.non_unit));
    try expectEqual(@as(c_int, 132), @intFromEnum(Diag.unit));
    try expectEqual(@as(c_int, 141), @intFromEnum(Side.left));
    try expectEqual(@as(c_int, 142), @intFromEnum(Side.right));
}

test "Complex has the interleaved layout C expects" {
    try std.testing.expectEqual(@as(usize, 8), @sizeOf(Complex(f32)));
    try std.testing.expectEqual(@as(usize, 16), @sizeOf(Complex(f64)));
    try std.testing.expectEqual(@as(usize, 0), @offsetOf(Complex(f32), "re"));
    try std.testing.expectEqual(@as(usize, 4), @offsetOf(Complex(f32), "im"));
    try std.testing.expectEqual(@as(usize, 8), @offsetOf(Complex(f64), "im"));

    // An array of Complex must be indistinguishable from an interleaved array
    // of the scalar type - that is the layout every BLAS complex pointer means.
    const zs = [_]Complex(f32){ .init(1, 2), .init(3, 4) };
    const flat: *const [4]f32 = @ptrCast(&zs);
    try std.testing.expectEqualSlices(f32, &.{ 1, 2, 3, 4 }, flat);
}

test "the ILP64 pairing is self-consistent" {
    // Int must match the interface the selected symbols were built with.
    // A mismatch links fine and then reads the wrong half of every dimension.
    if (use_ilp64) {
        try std.testing.expectEqual(@as(usize, 8), @sizeOf(Int));
        try std.testing.expect(std.mem.endsWith(u8, alias_suffix, "$ILP64"));
    } else {
        try std.testing.expectEqual(@as(usize, 4), @sizeOf(Int));
        try std.testing.expect(!std.mem.endsWith(u8, alias_suffix, "$ILP64"));
    }
    try std.testing.expect(std.mem.startsWith(u8, alias_suffix, "$NEWLAPACK"));
}

test "vectorLen spans the same elements for either stride direction" {
    try std.testing.expectEqual(@as(usize, 0), vectorLen(0, 1));
    try std.testing.expectEqual(@as(usize, 5), vectorLen(5, 1));
    try std.testing.expectEqual(@as(usize, 9), vectorLen(5, 2));
    try std.testing.expectEqual(@as(usize, 9), vectorLen(5, -2));
}

test "matrixLen accounts for the short final row or column" {
    // 3x4 row-major with ld 6: two full rows plus four entries.
    try std.testing.expectEqual(@as(usize, 2 * 6 + 4), matrixLen(.row_major, 3, 4, 6));
    // 3x4 column-major with ld 5: three full columns plus three entries.
    try std.testing.expectEqual(@as(usize, 3 * 5 + 3), matrixLen(.col_major, 3, 4, 5));
    // Tight packing.
    try std.testing.expectEqual(@as(usize, 12), matrixLen(.row_major, 3, 4, 4));
    try std.testing.expectEqual(@as(usize, 12), matrixLen(.col_major, 3, 4, 3));
    try std.testing.expectEqual(@as(usize, 0), matrixLen(.row_major, 0, 4, 4));
}

test "packedLen is the triangular number" {
    try std.testing.expectEqual(@as(usize, 0), packedLen(0));
    try std.testing.expectEqual(@as(usize, 1), packedLen(1));
    try std.testing.expectEqual(@as(usize, 6), packedLen(3));
    try std.testing.expectEqual(@as(usize, 15), packedLen(5));
}

test "Scalar and isComplex classify the four element types" {
    try std.testing.expectEqual(f32, Scalar(f32));
    try std.testing.expectEqual(f64, Scalar(f64));
    try std.testing.expectEqual(f32, Scalar(Complex(f32)));
    try std.testing.expectEqual(f64, Scalar(Complex(f64)));
    try std.testing.expect(!isComplex(f32));
    try std.testing.expect(isComplex(Complex(f64)));
}
