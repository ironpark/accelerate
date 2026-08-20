//! Zig type definitions for Apple's Sparse Solvers (Accelerate `Sparse/Solve.h`).
//!
//! ## Why these are hand-written and not `@cImport`ed
//!
//! Every public entry point in `Sparse/Solve.h` is declared
//! `static inline __attribute__((overloadable))`. Two consequences shape this
//! entire module:
//!
//!  1. There is no `SparseSolve` symbol in the dylib to link against. The
//!     inline wrappers dispatch to underscore-prefixed implementation
//!     functions (`_SparseFactorSymmetric_Double`, ...) which *are* exported,
//!     and which are declared - as `extern`, with
//!     `API_AVAILABLE(macos(10.13), ...)` - in the SDK headers
//!     `Sparse/SolveImplementation.h` and `Sparse/SolveImplementationTyped.h`.
//!     `c.zig` binds those, and this module re-implements the argument
//!     validation the inline wrappers perform.
//!
//!  2. `@cImport` cannot read the header at all: `__attribute__((overloadable))`
//!     lets one name be declared many times, and translate-c rejects the second
//!     declaration as a redefinition. `SparseSolve` alone has 78 overloads.
//!
//! Those two headers open with `#error "Do not include this header directly."`,
//! so the symbols are nominally private. They are nonetheless load-bearing ABI:
//! every binary that has ever compiled a call to `SparseSolve()` inlined a call
//! to them, so their signatures cannot change without breaking shipped
//! applications. There is no alternative entry point for a non-C/C++ caller.
//!
//! ## Struct layouts
//!
//! All layouts here are asserted against the C headers in `types.zig`'s test
//! block, so a future SDK that changes them fails the suite rather than
//! corrupting memory silently. The reference numbers were taken on macOS 15.4 /
//! arm64 by compiling a `sizeof`/`offsetof` dump against the real headers.

const std = @import("std");

// ============================================================================
// Matrix attributes
// ============================================================================

/// Which triangle of a triangular or symmetric matrix is stored.
pub const Triangle = enum(u1) {
    upper = 0,
    lower = 1,
};

/// What kind of matrix the structure describes.
///
/// For `.triangular`, `.unit_triangular` and `.symmetric`, the `triangle`
/// field of `Attributes` selects which half is actually stored; the other half
/// is implicitly zero (triangular) or a reflection (symmetric).
pub const Kind = enum(u2) {
    ordinary = 0,
    triangular = 1,
    unit_triangular = 2,
    symmetric = 3,
};

/// `SparseAttributes_t`.
///
/// A C bitfield, so this is a `packed struct(u32)` rather than an `extern
/// struct`. Only the low 16 bits are declared in the header; the rest is
/// implicit tail padding, kept explicit here so `@sizeOf` matches C's 4.
pub const Attributes = packed struct(u32) {
    /// If set, the matrix is implicitly transposed wherever it is used.
    transpose: bool = false,
    triangle: Triangle = .upper,
    kind: Kind = .ordinary,
    /// Reserved by Apple; must be zero.
    _reserved: u11 = 0,
    /// Set by Sparse itself on matrices it allocated (e.g. via
    /// `fromCoordinate`). Never set this by hand: `SparseCleanup` refuses to
    /// free a matrix without it, and would happily `free()` a stack pointer
    /// with it.
    _allocated_by_sparse: bool = false,
    _padding: u16 = 0,
};

/// What kind of matrix a *complex* structure describes.
///
/// `SparseAttributesComplex_t` widens `kind` from two bits to three so that
/// `.hermitian` can be added; the real and complex attribute layouts are
/// therefore not interchangeable, and neither are these two enums.
pub const KindComplex = enum(u3) {
    ordinary = 0,
    triangular = 1,
    unit_triangular = 2,
    /// `A = A^T`. Note this is the *un*-conjugated transpose, and is a much
    /// later addition than the rest: factorizing one needs macOS 26.
    symmetric = 3,
    /// `A = A^H`. The complex analogue of `.symmetric` and the one to reach
    /// for by default; available from macOS 15.5.
    hermitian = 7,
};

/// `SparseAttributesComplex_t`.
///
/// Not simply `Attributes` with an extra field: `kind` is three bits here
/// against two there, which shifts everything above it. Passing one where the
/// other is expected would misread `kind` and `_allocated_by_sparse` both, so
/// the two are distinct types and `AttributesFor` picks between them.
pub const AttributesComplex = packed struct(u32) {
    /// If set, the matrix is implicitly transposed wherever it is used.
    transpose: bool = false,
    triangle: Triangle = .upper,
    kind: KindComplex = .ordinary,
    /// When `transpose` is set, selects `A^H` over `A^T`. Ignored otherwise.
    conjugate_transpose: bool = false,
    /// Reserved by Apple; must be zero.
    _reserved: u9 = 0,
    /// See `Attributes._allocated_by_sparse`.
    _allocated_by_sparse: bool = false,
    _padding: u16 = 0,
};

// ============================================================================
// Element types
// ============================================================================

/// A complex element, matching C's `float _Complex` / `double _Complex`
/// layout: real part first, imaginary second, no padding.
///
/// Sparse passes complex scalars by value (`SparseMultiply`'s `alpha`, for
/// one). On both arm64 and x86-64 a two-element float struct and a `_Complex`
/// of the same element type are classified identically by the ABI, so this is
/// the right shape to hand across the boundary as well as the right shape in
/// memory.
pub fn Complex(comptime R: type) type {
    return extern struct {
        const Self = @This();

        real: R,
        imag: R = 0,

        pub fn init(real: R, imag: R) Self {
            return .{ .real = real, .imag = imag };
        }

        pub fn conjugate(self: Self) Self {
            return .{ .real = self.real, .imag = -self.imag };
        }

        pub fn add(a: Self, b: Self) Self {
            return .{ .real = a.real + b.real, .imag = a.imag + b.imag };
        }

        pub fn mul(a: Self, b: Self) Self {
            return .{
                .real = a.real * b.real - a.imag * b.imag,
                .imag = a.real * b.imag + a.imag * b.real,
            };
        }

        pub fn abs(self: Self) R {
            return @sqrt(self.real * self.real + self.imag * self.imag);
        }
    };
}

/// The multiplicative identity for element type `T`. A plain `1` literal does
/// not coerce to `Complex(R)`, so generic code that needs a unit scalar - the
/// iterative solvers' matrix operator, for one - goes through this.
pub fn one(comptime T: type) T {
    return if (comptime isComplex(T)) .{ .real = 1, .imag = 0 } else 1;
}

/// The additive identity, for the same reason as `one`.
pub fn zero(comptime T: type) T {
    return if (comptime isComplex(T)) .{ .real = 0, .imag = 0 } else 0;
}

/// Whether `T` is one of the two complex element types.
pub fn isComplex(comptime T: type) bool {
    return T == Complex(f32) or T == Complex(f64);
}

/// The underlying real type: `f32` for `f32` and `Complex(f32)`, and likewise
/// for `f64`.
pub fn Real(comptime T: type) type {
    return switch (T) {
        f32, f64 => T,
        Complex(f32) => f32,
        Complex(f64) => f64,
        else => @compileError("Sparse element type must be f32, f64, Complex(f32) or Complex(f64)"),
    };
}

/// The attributes struct that goes with element type `T`.
pub fn AttributesFor(comptime T: type) type {
    return if (isComplex(T)) AttributesComplex else Attributes;
}

// ============================================================================
// Enumerations
// ============================================================================

/// `SparseFactorization_t` - which factorization `factor()` should compute.
pub const FactorizationType = enum(u8) {
    /// `A = PLL'P'`, for symmetric/Hermitian positive-definite `A`. Fails -
    /// potentially after significant work - if `A` is not positive-definite.
    cholesky = 0,
    /// Default `LDL^T` (currently equivalent to `.ldlt_tpp`).
    ldlt = 1,
    /// `LDL^T` with 1x1 pivots only and no pivoting. Fast, but unstable for
    /// anything but well-behaved full-rank systems.
    ldlt_unpivoted = 2,
    /// `LDL^T` with Supernode Bunch-Kaufman and static pivoting.
    ldlt_sbk = 3,
    /// `LDL^T` with full threshold partial pivoting. Provably stable, at the
    /// cost of potentially larger factors.
    ldlt_tpp = 4,
    /// `A = QRP` (or `P'R'Q'` when underdetermined), for any real matrix.
    qr = 40,
    /// QR without storing `Q`, i.e. `A^T A = R^T R`.
    cholesky_at_a = 41,

    // -- LU, for square matrices with no symmetry --
    //
    // These are the only factorizations here that place no structural demand
    // on the matrix: no symmetry, no positive-definiteness. They arrived in
    // macOS 15.5 / iOS 18.5, several releases after the rest, and calling one
    // on an older system traps inside vecLib rather than returning a status.

    /// Default LU, currently `.lu_tpp`.
    lu = 80,
    /// LU with no numerical pivoting. Fastest and least stable; a zero pivot
    /// is a hard failure rather than something to permute around.
    lu_unpivoted = 81,
    /// LU with partial pivoting restricted to within supernodes.
    lu_spp = 82,
    /// LU with threshold partial pivoting.
    lu_tpp = 83,

    /// Whether this factorization requires a symmetric (or, for a complex
    /// matrix, Hermitian) input.
    ///
    /// Mirrors the dispatch in `SparseFactor()`: QR and LU have their own
    /// entry points, and everything else goes to the symmetric one.
    pub fn isSymmetric(self: FactorizationType) bool {
        return switch (self) {
            .qr, .cholesky_at_a, .lu, .lu_unpivoted, .lu_spp, .lu_tpp => false,
            else => true,
        };
    }

    /// Whether this is one of the LU factorizations.
    pub fn isLu(self: FactorizationType) bool {
        return switch (self) {
            .lu, .lu_unpivoted, .lu_spp, .lu_tpp => true,
            else => false,
        };
    }
};

/// `SparseOrder_t` - fill-reducing ordering heuristic.
///
/// The elimination order is the single biggest factor in how large the factors
/// get. AMD is fast and good for small-to-medium problems; MeTiS nested
/// dissection is slower to compute but better for very large ones. COLAMD
/// orders `A^T A` while only touching `A`, which is why it is the default for
/// QR and is *not* valid for symmetric factorizations.
pub const Order = enum(u8) {
    /// AMD for symmetric factorizations, COLAMD for QR.
    default = 0,
    /// Use `SymbolicOptions.order`, or the identity if it is null.
    user = 1,
    amd = 2,
    metis = 3,
    /// Not valid for symmetric factorizations - use `.amd`.
    colamd = 4,
};

/// `SparseScaling_t` - diagonal scaling applied before factorization.
pub const Scaling = enum(u8) {
    /// Inf-norm equilibriation for `LDL^T`, none for Cholesky.
    default = 0,
    /// Use `NumericOptions.scaling` if non-null, otherwise no scaling.
    user = 1,
    equilibriation_inf = 2,
};

/// `SparseSubfactor_t` - which piece of a factorization to extract.
///
/// Values are consecutive, not flags. (An earlier draft of this binding
/// assumed a bitmask - 1, 2, 4, 8, ... - which is wrong and would have
/// silently requested the wrong subfactor.)
pub const Subfactor = enum(u8) {
    /// The value `_SparseInvalidSubfactor()` returns; never request it.
    invalid = 0,
    /// Permutation `P`. Valid for every factorization type.
    p = 1,
    /// Diagonal scaling `S`. `LDL^T` only.
    s = 2,
    /// Lower triangular `L`. Cholesky and `LDL^T` only.
    l = 3,
    /// Block diagonal `D`. `LDL^T` only.
    d = 4,
    /// `PLP'` (Cholesky) or `PLP'S` (`LDL^T`). Solve only - a transpose solve
    /// followed by a non-transpose solve is a full system solve.
    plps = 5,
    /// Orthogonal `Q`. QR only, and the one subfactor that is `m x n` rather
    /// than `n x n`.
    q = 6,
    /// Upper triangular `R`. QR and `.cholesky_at_a` only.
    r = 7,
    /// `RP`. QR and `.cholesky_at_a` only.
    rp = 8,
    /// Row scaling `S_r`. Pivoted LU only. macOS 15.5 and later.
    sr = 9,
    /// Column scaling `S_c`. Pivoted LU only. macOS 15.5 and later.
    sc = 10,

    /// Which factorization types this subfactor can be extracted from.
    /// Mirrors the switch in `SparseCreateSubfactor`.
    pub fn isValidFor(self: Subfactor, kind: FactorizationType) bool {
        return switch (self) {
            .invalid => false,
            .p => true,
            .l, .plps => switch (kind) {
                .cholesky, .ldlt, .ldlt_unpivoted, .ldlt_sbk, .ldlt_tpp => true,
                else => false,
            },
            .s, .d => switch (kind) {
                .ldlt, .ldlt_unpivoted, .ldlt_sbk, .ldlt_tpp => true,
                else => false,
            },
            // `Q` is the one subfactor LU and QR share: for LU it is the
            // column permutation, not an orthogonal factor. `.lu` is absent
            // because `SparseCreateSubfactor` names only the three pivoted
            // spellings - which costs nothing, since a factorization
            // requested as `.lu` records itself as `.lu_tpp`.
            .q => switch (kind) {
                .qr, .lu_unpivoted, .lu_spp, .lu_tpp => true,
                else => false,
            },
            .r, .rp => kind == .qr or kind == .cholesky_at_a,
            .sr, .sc => switch (kind) {
                .lu_unpivoted, .lu_spp, .lu_tpp => true,
                else => false,
            },
        };
    }
};

/// Raw `SparseStatus_t` values, as returned in the `status` fields.
pub const Status = struct {
    pub const ok: i32 = 0;
    pub const factorization_failed: i32 = -1;
    pub const matrix_is_singular: i32 = -2;
    pub const internal_error: i32 = -3;
    pub const parameter_error: i32 = -4;
    /// `-INT_MAX`, not `INT_MIN`.
    pub const released: i32 = -std.math.maxInt(i32);
};

// ============================================================================
// Zig-native error handling
// ============================================================================

/// Sparse's failure modes as a Zig error set.
///
/// The C API has two separate failure channels, and this set unifies them:
///
///  - Numerical failure is reported through the `status` field of the returned
///    factorization object, which is easy to ignore.
///  - Parameter errors call `options.reportError`, or - when that is null,
///    which is the default - log to `os_log` and **abort the process** via
///    `_SparseTrap()`, i.e. `__builtin_trap()`.
///
/// This binding validates arguments in Zig before the call, and installs a
/// `reportError` callback so anything Sparse rejects internally surfaces as
/// `error.ParameterError` instead of a trap. See `takeReportedError`.
pub const SparseError = error{
    /// The factorization could not be completed. For `.cholesky` this most
    /// often means the matrix was not positive-definite.
    FactorizationFailed,
    /// The matrix is singular to working precision.
    MatrixIsSingular,
    /// Sparse reported an internal failure.
    InternalError,
    /// Sparse rejected an argument. `lastErrorMessage()` has the detail.
    ParameterError,
    /// The factorization object has already been released.
    Released,
    /// A status code outside the documented set.
    Unknown,
};

/// Maps a raw `SparseStatus_t` onto `SparseError`.
pub fn check(status: i32) SparseError!void {
    return switch (status) {
        Status.ok => {},
        Status.factorization_failed => SparseError.FactorizationFailed,
        Status.matrix_is_singular => SparseError.MatrixIsSingular,
        Status.internal_error => SparseError.InternalError,
        Status.parameter_error => SparseError.ParameterError,
        Status.released => SparseError.Released,
        else => SparseError.Unknown,
    };
}

// ---------------------------------------------------------------------------
// reportError plumbing
// ---------------------------------------------------------------------------

/// Sparse hands us a `const char *` and expects no return value, so the
/// callback cannot itself fail the call. It records the message here and the
/// caller checks afterwards. Thread-local because Sparse is re-entrant and
/// two threads may be factoring different matrices at once.
threadlocal var reported_buf: [256]u8 = undefined;
threadlocal var reported_len: usize = 0;

fn reportErrorCallback(message: [*:0]const u8) callconv(.c) void {
    const s = std.mem.span(message);
    const n = @min(s.len, reported_buf.len);
    @memcpy(reported_buf[0..n], s[0..n]);
    reported_len = n;
}

/// The `reportError` function pointer to install in `SymbolicOptions`.
///
/// Installing *any* non-null pointer is what keeps Sparse from calling
/// `__builtin_trap()` on a parameter error. Per the header: "If the callback
/// returns, control will be returned to the caller with any outputs in a safe
/// but undefined state (i.e. they may hold partial results or garbage, but all
/// sizes and pointers are valid)." That is why callers must treat a reported
/// error as fatal to the operation and discard its outputs.
pub const report_error_callback: *const fn ([*:0]const u8) callconv(.c) void = &reportErrorCallback;

/// The last message Sparse reported on this thread, or null if none is
/// pending. Valid until the next Sparse call on this thread.
pub fn lastErrorMessage() ?[]const u8 {
    if (reported_len == 0) return null;
    return reported_buf[0..reported_len];
}

/// Clears any pending reported error. Call before entering Sparse so a stale
/// message from an earlier call is not mistaken for a fresh failure.
pub fn clearReportedError() void {
    reported_len = 0;
}

/// Returns `error.ParameterError` if Sparse reported a problem since the last
/// `clearReportedError`, leaving the message retrievable via
/// `lastErrorMessage()`.
pub fn takeReportedError() SparseError!void {
    if (reported_len != 0) return SparseError.ParameterError;
}

// ============================================================================
// Layout assertions
// ============================================================================

test "Attributes matches the C bitfield layout" {
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(Attributes));

    // Field order and widths, pinned by bit position rather than by trusting
    // the declaration order to survive an edit.
    const lower_sym = Attributes{ .kind = .symmetric, .triangle = .lower };
    try std.testing.expectEqual(@as(u32, 0b1110), @as(u32, @bitCast(lower_sym)));

    const transposed = Attributes{ .transpose = true };
    try std.testing.expectEqual(@as(u32, 0b0001), @as(u32, @bitCast(transposed)));

    const allocated = Attributes{ ._allocated_by_sparse = true };
    try std.testing.expectEqual(@as(u32, 1 << 15), @as(u32, @bitCast(allocated)));

    try std.testing.expectEqual(Attributes{}, @as(Attributes, @bitCast(@as(u32, 0))));
}

test "AttributesComplex is not Attributes with a field added" {
    // `kind` is three bits here against two there, so everything above it
    // shifts. `conjugate_transpose` occupies the bit that `_reserved` starts
    // at in the real layout, and `_allocated_by_sparse` stays at bit 15 only
    // because `_reserved` narrows to compensate. Bit-pattern assertions
    // rather than field-order trust.
    try std.testing.expectEqual(@as(usize, 4), @sizeOf(AttributesComplex));

    const lower_herm = AttributesComplex{ .kind = .hermitian, .triangle = .lower };
    // kind = 7 in bits 2..4, triangle = 1 in bit 1.
    try std.testing.expectEqual(@as(u32, 0b11110), @as(u32, @bitCast(lower_herm)));

    const conj = AttributesComplex{ .transpose = true, .conjugate_transpose = true };
    // transpose = bit 0, conjugate_transpose = bit 5.
    try std.testing.expectEqual(@as(u32, 0b100001), @as(u32, @bitCast(conj)));

    const allocated = AttributesComplex{ ._allocated_by_sparse = true };
    try std.testing.expectEqual(@as(u32, 1 << 15), @as(u32, @bitCast(allocated)));

    // The same nominal attributes give different bit patterns in the two
    // layouts once `kind` is non-zero, which is why the structs cannot be
    // cast into each other.
    const real_sym = Attributes{ .kind = .symmetric };
    const complex_sym = AttributesComplex{ .kind = .symmetric };
    try std.testing.expectEqual(@as(u32, 0b1100), @as(u32, @bitCast(real_sym)));
    try std.testing.expectEqual(@as(u32, 0b1100), @as(u32, @bitCast(complex_sym)));
    // ... they agree for `.symmetric` (3 fits either width) and diverge as
    // soon as a bit above `kind` is set.
    const real_alloc_sym = Attributes{ .kind = .symmetric, ._allocated_by_sparse = true };
    const complex_conj_sym = AttributesComplex{ .kind = .symmetric, .conjugate_transpose = true };
    try std.testing.expect(@as(u32, @bitCast(real_alloc_sym)) != @as(u32, @bitCast(complex_conj_sym)));
}

test "Complex arithmetic helpers" {
    const Z = Complex(f64);
    const a = Z.init(1, 2);
    const b = Z.init(3, -1);
    try std.testing.expectEqual(Z.init(4, 1), a.add(b));
    // (1 + 2i)(3 - i) = 3 - i + 6i - 2i^2 = 5 + 5i
    try std.testing.expectEqual(Z.init(5, 5), a.mul(b));
    try std.testing.expectEqual(Z.init(1, -2), a.conjugate());
    try std.testing.expectApproxEqAbs(@as(f64, 5), Z.init(3, 4).abs(), 1e-12);

    try std.testing.expect(isComplex(Z));
    try std.testing.expect(!isComplex(f64));
    try std.testing.expectEqual(f64, Real(Z));
    try std.testing.expectEqual(f32, Real(Complex(f32)));
    try std.testing.expectEqual(f64, Real(f64));
    try std.testing.expectEqual(AttributesComplex, AttributesFor(Z));
    try std.testing.expectEqual(Attributes, AttributesFor(f64));
}

test "FactorizationType classifies LU" {
    for ([_]FactorizationType{ .lu, .lu_unpivoted, .lu_spp, .lu_tpp }) |t| {
        try std.testing.expect(t.isLu());
        // LU is the one family that is neither symmetric nor QR: it places no
        // structural demand on the matrix at all.
        try std.testing.expect(!t.isSymmetric());
    }
    for ([_]FactorizationType{ .cholesky, .ldlt, .ldlt_tpp }) |t| {
        try std.testing.expect(!t.isLu());
        try std.testing.expect(t.isSymmetric());
    }
    for ([_]FactorizationType{ .qr, .cholesky_at_a }) |t| {
        try std.testing.expect(!t.isLu());
        try std.testing.expect(!t.isSymmetric());
    }
}

test "enum values match the C header" {
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(FactorizationType.cholesky));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(FactorizationType.ldlt_tpp));
    try std.testing.expectEqual(@as(u8, 40), @intFromEnum(FactorizationType.qr));
    try std.testing.expectEqual(@as(u8, 41), @intFromEnum(FactorizationType.cholesky_at_a));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(Order.colamd));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(Scaling.equilibriation_inf));
    // Consecutive, not a bitmask - see the note on `Subfactor`.
    try std.testing.expectEqual(@as(u8, 0), @intFromEnum(Subfactor.invalid));
    try std.testing.expectEqual(@as(u8, 1), @intFromEnum(Subfactor.p));
    try std.testing.expectEqual(@as(u8, 2), @intFromEnum(Subfactor.s));
    try std.testing.expectEqual(@as(u8, 3), @intFromEnum(Subfactor.l));
    try std.testing.expectEqual(@as(u8, 4), @intFromEnum(Subfactor.d));
    try std.testing.expectEqual(@as(u8, 5), @intFromEnum(Subfactor.plps));
    try std.testing.expectEqual(@as(u8, 6), @intFromEnum(Subfactor.q));
    try std.testing.expectEqual(@as(u8, 7), @intFromEnum(Subfactor.r));
    try std.testing.expectEqual(@as(u8, 8), @intFromEnum(Subfactor.rp));
    try std.testing.expectEqual(@as(i32, -2147483647), Status.released);
}

test "isSymmetric mirrors SparseFactor's dispatch" {
    try std.testing.expect(FactorizationType.cholesky.isSymmetric());
    try std.testing.expect(FactorizationType.ldlt.isSymmetric());
    try std.testing.expect(FactorizationType.ldlt_unpivoted.isSymmetric());
    try std.testing.expect(FactorizationType.ldlt_sbk.isSymmetric());
    try std.testing.expect(FactorizationType.ldlt_tpp.isSymmetric());
    try std.testing.expect(!FactorizationType.qr.isSymmetric());
    try std.testing.expect(!FactorizationType.cholesky_at_a.isSymmetric());
}

test "Subfactor.isValidFor mirrors SparseCreateSubfactor's switch" {
    // P is the only subfactor valid for every factorization type.
    inline for (.{ .cholesky, .ldlt, .ldlt_tpp, .qr, .cholesky_at_a }) |k| {
        try std.testing.expect(Subfactor.p.isValidFor(k));
    }
    // L exists for Cholesky and LDL^T, not for QR.
    try std.testing.expect(Subfactor.l.isValidFor(.cholesky));
    try std.testing.expect(Subfactor.l.isValidFor(.ldlt_tpp));
    try std.testing.expect(!Subfactor.l.isValidFor(.qr));
    // D and S are LDL^T only - Cholesky has no diagonal factor.
    try std.testing.expect(!Subfactor.d.isValidFor(.cholesky));
    try std.testing.expect(Subfactor.d.isValidFor(.ldlt_sbk));
    try std.testing.expect(!Subfactor.s.isValidFor(.cholesky));
    // Q is QR only; R covers QR and CholeskyAtA.
    try std.testing.expect(Subfactor.q.isValidFor(.qr));
    try std.testing.expect(!Subfactor.q.isValidFor(.cholesky_at_a));
    try std.testing.expect(Subfactor.r.isValidFor(.qr));
    try std.testing.expect(Subfactor.r.isValidFor(.cholesky_at_a));
    try std.testing.expect(!Subfactor.r.isValidFor(.cholesky));
    // The invalid sentinel is never requestable.
    try std.testing.expect(!Subfactor.invalid.isValidFor(.cholesky));
}

test "check maps every documented status" {
    try check(Status.ok);
    try std.testing.expectError(SparseError.FactorizationFailed, check(Status.factorization_failed));
    try std.testing.expectError(SparseError.MatrixIsSingular, check(Status.matrix_is_singular));
    try std.testing.expectError(SparseError.InternalError, check(Status.internal_error));
    try std.testing.expectError(SparseError.ParameterError, check(Status.parameter_error));
    try std.testing.expectError(SparseError.Released, check(Status.released));
    try std.testing.expectError(SparseError.Unknown, check(-12345));
}

test "reportError plumbing round-trips a message" {
    clearReportedError();
    try std.testing.expectEqual(@as(?[]const u8, null), lastErrorMessage());
    try takeReportedError();

    report_error_callback("rowCount must be > 0.\n");
    try std.testing.expectError(SparseError.ParameterError, takeReportedError());
    try std.testing.expectEqualStrings("rowCount must be > 0.\n", lastErrorMessage().?);

    clearReportedError();
    try std.testing.expectEqual(@as(?[]const u8, null), lastErrorMessage());
}
