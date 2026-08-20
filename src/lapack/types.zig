//! Shared types for the LAPACK bindings.
//!
//! ## Which LAPACK this binds
//!
//! Exactly the same situation as `blas/types.zig`: Accelerate exports four
//! spellings of every routine, and the obvious one is the wrong one.
//!
//! | Mach-O symbol | Interface | Index type |
//! |---|---|---|
//! | `_sgesv`, `_sgesv_` | legacy (`clapack.h`) | `int` |
//! | `_sgesv$NEWLAPACK` | current, LP64 | `int` |
//! | `_sgesv$NEWLAPACK$ILP64` | current, ILP64 | `long` |
//!
//! `lapack.h` reaches the suffixed symbols through
//! `__LAPACK_ALIAS(sym)` = `__asm("_" #sym "$NEWLAPACK" ["$ILP64"])`, an asm
//! label rename that is invisible to C callers. `clapack.h`, which declares the
//! unsuffixed names, is deprecated as of macOS 13.3.
//!
//! `use_ilp64` and `Int` are re-derived here rather than imported from the BLAS
//! module so this module stands alone, but they must agree: mixing a 64-bit
//! `Int` with an LP64 symbol links cleanly and then misreads every dimension.
//!
//! ## Everything is a pointer
//!
//! LAPACK is Fortran. No routine takes a scalar by value, and no routine takes
//! or returns a complex by value - which means C99 `_Complex` register
//! classification never enters the picture and a plain `extern struct` is
//! always the right representation. There are also no hidden string-length
//! arguments, the usual hazard in hand-rolled LAPACK FFIs; `chla_transtype` is
//! the only routine that takes a length and it is for an output string.

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

/// `__LAPACK_bool` - a Fortran `LOGICAL`, as the selected symbols read it.
///
/// This is **not** 4 bytes under ILP64. `lapack_types.h` says:
///
/// ```c
/// #if defined( ACCELERATE_LAPACK_ILP64 )
///     typedef long __LAPACK_int;
///     typedef long __LAPACK_bool;
/// #else
///     typedef int  __LAPACK_int;
///     typedef int  __LAPACK_bool;  // Because the fortran logical is 4 bytes
/// #endif
/// ```
///
/// The comment justifies the LP64 branch and the ILP64 branch quietly widens it
/// to 8 bytes anyway. 163 declarations take a `Bool` array - the `bwork`
/// argument of the eigenvalue-sorting drivers - so defining this as `c_int` or
/// as Zig's 1-byte `bool` would read every other element of the wrong stride.
pub const Bool = Int;

/// Fortran `.TRUE.`, as returned by `sisnan`/`disnan`/`lsamen`.
pub fn isTrue(value: Bool) bool {
    return value != 0;
}

/// Interleaved complex, ABI-compatible with C's `float _Complex` /
/// `double _Complex` for the only way LAPACK uses them: behind a pointer.
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

        pub fn sub(a: Self, b: Self) Self {
            return .{ .re = a.re - b.re, .im = a.im - b.im };
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
    };
}

/// The real type underlying `T`, for the many routines whose norms, tolerances
/// and eigenvalues stay real even when the matrix is complex.
pub fn Real(comptime T: type) type {
    return switch (T) {
        f32, f64 => T,
        Complex(f32) => f32,
        Complex(f64) => f64,
        else => @compileError("not a LAPACK element type: " ++ @typeName(T)),
    };
}

/// The single-character precision prefix LAPACK uses for `T`, which `ilaenv`
/// wants as the first letter of the routine name it is asked about.
pub fn prefix(comptime T: type) u8 {
    return switch (T) {
        f32 => 's',
        f64 => 'd',
        Complex(f32) => 'c',
        Complex(f64) => 'z',
        else => @compileError("not a LAPACK element type: " ++ @typeName(T)),
    };
}

/// `__LAPACK_sgees_func_ptr` and friends: the eigenvalue-selection predicate
/// passed to the Schur drivers (`gees`, `geesx`) when `sort = .sorted`.
///
/// Real precisions receive the real and imaginary parts as two pointers;
/// complex precisions receive one pointer to the eigenvalue.
pub fn SelectSchurFn(comptime T: type) type {
    return switch (T) {
        f32, f64 => *const fn ([*]T, [*]T) callconv(.c) Bool,
        else => *const fn ([*]T) callconv(.c) Bool,
    };
}

/// `__LAPACK_sgges_func_ptr` and friends: the selection predicate for the
/// generalized Schur drivers (`gges`, `gges3`, `ggesx`).
pub fn SelectGeneralizedFn(comptime T: type) type {
    return switch (T) {
        f32, f64 => *const fn ([*]T, [*]T, [*]T) callconv(.c) Bool,
        else => *const fn ([*]T, [*]T) callconv(.c) Bool,
    };
}

// ---------------------------------------------------------------------------
// Option characters
//
// LAPACK spells its options as single characters rather than the small integers
// CBLAS uses, so these are `enum(u8)` and are passed as `@ptrCast(&opt)`.
// LAPACK compares them case-insensitively via `lsame`, but these use the
// uppercase spelling the documentation does.
// ---------------------------------------------------------------------------

/// Which triangle of a symmetric/Hermitian/triangular matrix is stored.
pub const Uplo = enum(u8) { upper = 'U', lower = 'L' };

/// Whether and how a matrix operand is transposed.
pub const Trans = enum(u8) {
    no_trans = 'N',
    trans = 'T',
    /// Conjugate transpose. For real precisions LAPACK treats this as `.trans`.
    conj_trans = 'C',
};

/// Whether a triangular matrix has an implicit unit diagonal.
pub const Diag = enum(u8) { non_unit = 'N', unit = 'U' };

/// Which side of the product the named operand appears on.
pub const Side = enum(u8) { left = 'L', right = 'R' };

/// Which norm to compute. `one` and `max_column_abs` are the same value, as are
/// `infinity` and `max_row_abs`; LAPACK documents both readings.
pub const Norm = enum(u8) {
    /// max(abs(A(i,j))). Not a submultiplicative norm.
    max_abs = 'M',
    /// The 1-norm: max column absolute sum.
    one = 'O',
    /// The infinity-norm: max row absolute sum.
    infinity = 'I',
    /// The Frobenius norm.
    frobenius = 'F',
};

/// Whether the eigenvalue/singular-value drivers also compute vectors.
pub const Job = enum(u8) { vectors = 'V', values_only = 'N' };

/// Which subset of the spectrum an expert driver should compute.
pub const Range = enum(u8) {
    /// All eigenvalues.
    all = 'A',
    /// Those in the half-open interval (vl, vu].
    interval = 'V',
    /// Those with indices il through iu.
    indices = 'I',
};

/// How `gesvd` should return the left or right singular vectors.
pub const JobSvd = enum(u8) {
    /// All columns of U (or all rows of V^T) are returned.
    all = 'A',
    /// The first min(m, n) columns (the "thin" SVD).
    some = 'S',
    /// Overwritten onto A.
    overwrite = 'O',
    /// Not computed.
    none = 'N',
};

/// Whether an expert driver equilibrates the system, and how it was scaled.
pub const Equed = enum(u8) {
    none = 'N',
    row = 'R',
    column = 'C',
    both = 'B',
};

/// Whether an expert driver factors the matrix, reuses a factorization, or
/// equilibrates first.
pub const Fact = enum(u8) {
    factored = 'F',
    not_factored = 'N',
    equilibrate = 'E',
};

/// Whether the Schur drivers sort eigenvalues with the supplied predicate.
pub const Sort = enum(u8) { sorted = 'S', unsorted = 'N' };

/// What `gebal`/`ggbal` should do before reduction.
pub const Balance = enum(u8) {
    none = 'N',
    permute = 'P',
    scale = 'S',
    both = 'B',
};

/// Which side's eigenvectors `trevc`/`tgevc` should compute.
pub const EigSide = enum(u8) { right = 'R', left = 'L', both = 'B' };

/// The order in which a block reflector's Householder vectors were applied.
///
/// `larfb`, `tprfb` and the block-reflector routines need to know, because the
/// product `H1 H2 ... Hk` and `Hk ... H2 H1` are different matrices.
pub const Direction = enum(u8) {
    /// `H = H(1) H(2) ... H(k)`.
    forward = 'F',
    /// `H = H(k) ... H(2) H(1)`.
    backward = 'B',
};

/// Whether a block reflector's vectors are stored as columns or rows.
pub const StoreV = enum(u8) {
    columnwise = 'C',
    rowwise = 'R',
};

/// Which of `gebrd`'s two orthogonal factors `orgbr`/`ormbr` should form.
pub const Vect = enum(u8) { q = 'Q', p = 'P' };

/// Every byte value, so an option character can be turned into a pointer
/// without the caller needing a variable to point at.
///
/// LAPACK takes its options by reference like everything else, and an option is
/// usually a literal at the call site (`.upper`, `.no_trans`). Materialising a
/// `var` for each one is noise, and taking the address of a temporary is not
/// something Zig will do. Indexing this table gives a stable pointer to the
/// right byte with no storage per call site.
const byte_table: [256]u8 = blk: {
    var table: [256]u8 = undefined;
    for (&table, 0..) |*slot, i| slot.* = @intCast(i);
    break :blk table;
};

/// Passes an option character to the raw `c.zig` layer, which takes every
/// argument by pointer.
///
/// The tag is not comptime-known when the option came from a runtime value, so
/// this indexes `byte_table` rather than pointing at the enum literal.
pub fn opt(value: anytype) [*]const u8 {
    return @ptrCast(&byte_table[@intFromEnum(value)]);
}

// ---------------------------------------------------------------------------
// Storage
// ---------------------------------------------------------------------------

/// Narrows a caller's `usize` extent to the `Int` the symbols read.
pub fn dim(n: usize) Int {
    std.debug.assert(n <= std.math.maxInt(Int));
    return @intCast(n);
}

/// Minimum slice length for a column-major `rows x cols` matrix with leading
/// dimension `ld`.
///
/// The last column only needs `rows` elements, not `ld`, so this is
/// `ld * (cols - 1) + rows` rather than `ld * cols`. Requiring the larger
/// figure would reject slices LAPACK never reads past - notably the common case
/// of a caller passing exactly the trailing submatrix a blocked routine works
/// on.
pub fn colMajorLen(rows: usize, cols: usize, ld: usize) usize {
    std.debug.assert(ld >= @max(1, rows));
    if (cols == 0 or rows == 0) return 0;
    return ld * (cols - 1) + rows;
}

/// Minimum slice length for a triangular matrix in packed storage.
///
/// Packed storage holds only the referenced triangle, column by column, with no
/// leading dimension at all.
pub fn packedLen(n: usize) usize {
    return n * (n + 1) / 2;
}

/// Asserts a column-major matrix slice is large enough for the extents given.
pub fn assertMatrix(len: usize, rows: usize, cols: usize, ld: usize) void {
    std.debug.assert(len >= colMajorLen(rows, cols, ld));
}

test "colMajorLen measures what LAPACK actually reads" {
    // A 3x3 with ld = 5 spans 5 + 5 + 3 = 13 elements, not 15: the last column
    // stops after its third row.
    try std.testing.expectEqual(@as(usize, 13), colMajorLen(3, 3, 5));
    try std.testing.expectEqual(@as(usize, 9), colMajorLen(3, 3, 3));
    try std.testing.expectEqual(@as(usize, 0), colMajorLen(0, 0, 1));
    try std.testing.expectEqual(@as(usize, 0), colMajorLen(3, 0, 3));
}

test "packedLen counts one triangle" {
    try std.testing.expectEqual(@as(usize, 6), packedLen(3));
    try std.testing.expectEqual(@as(usize, 10), packedLen(4));
}

test "Bool is the width the selected symbols actually read" {
    // `sgees` writes `bwork` with this stride. If Bool ever narrows to c_int
    // while Int stays 64-bit, every other element of a sorting driver's bwork
    // is garbage - and nothing else in the suite would notice.
    try std.testing.expectEqual(@sizeOf(Int), @sizeOf(Bool));
    if (use_ilp64) try std.testing.expectEqual(@as(usize, 8), @sizeOf(Bool));
}

test "Int and alias_suffix are chosen together" {
    // A 64-bit Int paired with an LP64 symbol links cleanly and then misreads
    // every dimension, so pin the pairing rather than each half separately.
    if (use_ilp64) {
        try std.testing.expectEqual(@as(usize, 8), @sizeOf(Int));
        try std.testing.expect(std.mem.endsWith(u8, alias_suffix, "$ILP64"));
    } else {
        try std.testing.expectEqual(@as(usize, 4), @sizeOf(Int));
        try std.testing.expect(!std.mem.endsWith(u8, alias_suffix, "$ILP64"));
    }
}

test "option characters match the letters LAPACK documents" {
    try std.testing.expectEqual(@as(u8, 'U'), @intFromEnum(Uplo.upper));
    try std.testing.expectEqual(@as(u8, 'C'), @intFromEnum(Trans.conj_trans));
    try std.testing.expectEqual(@as(u8, 'F'), @intFromEnum(Norm.frobenius));
    try std.testing.expectEqual(@as(u8, 'O'), @intFromEnum(JobSvd.overwrite));
    try std.testing.expectEqual(@as(u8, 'E'), @intFromEnum(Fact.equilibrate));
}

test "Real and prefix agree on the four precisions" {
    try std.testing.expectEqual(f32, Real(Complex(f32)));
    try std.testing.expectEqual(f64, Real(Complex(f64)));
    try std.testing.expectEqual(f64, Real(f64));
    try std.testing.expectEqual(@as(u8, 'z'), prefix(Complex(f64)));
    try std.testing.expectEqual(@as(u8, 's'), prefix(f32));
}
