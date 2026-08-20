//! C extern declarations for Apple's Sparse Solvers.
//!
//! These are the underscore-prefixed implementation symbols that
//! `Sparse/Solve.h`'s `static inline` public API dispatches to. See the module
//! docs in `types.zig` for why the public names cannot be bound directly.
//!
//! Signatures are transcribed from `Sparse/SolveImplementation.h` and
//! `Sparse/SolveImplementationTyped.h`, which declare them `extern` under
//! `API_AVAILABLE(macos(10.13), ios(11), watchos(4), tvos(11))`.
//!
//! The `_Double`/`_Float` split is C macro expansion on Apple's side; here it
//! is two sets of declarations plus `fns(T)` to pick between them at comptime.

const std = @import("std");
const types = @import("types.zig");

const Attributes = types.Attributes;

// ============================================================================
// ABI structs
// ============================================================================

/// `SparseMatrixStructure` - the sparsity pattern, in *block compressed sparse
/// column* form.
///
/// The matrix is a grid of `rowCount` x `columnCount` blocks, each
/// `blockSize x blockSize`; only blocks containing a non-zero are stored. Block
/// row indices for block column `j` are
/// `rowIndices[columnStarts[j]..columnStarts[j + 1]]`.
///
/// With `blockSize == 1` this is exactly ordinary CSC. CSR data can be fed in
/// by using `blockSize == 1` and setting `attributes.transpose` (strictly this
/// is a transposed CSC, so `rowCount`/`columnCount` are swapped relative to
/// true CSR).
///
/// `columnStarts` and `rowIndices` are non-const in C even for read-only use.
pub const MatrixStructure = extern struct {
    rowCount: c_int,
    columnCount: c_int,
    columnStarts: [*]c_long,
    rowIndices: [*]c_int,
    attributes: Attributes,
    blockSize: u8,
};

/// `SparseMatrix_Double` / `SparseMatrix_Float`.
///
/// `data` holds `blockSize * blockSize * N` values for `N` structurally
/// non-zero blocks, each block stored column-major.
pub fn SparseMatrix(comptime T: type) type {
    return extern struct {
        structure: MatrixStructure,
        data: [*]T,
    };
}

/// `DenseVector_Double` / `DenseVector_Float`.
pub fn DenseVector(comptime T: type) type {
    return extern struct {
        count: c_int,
        data: [*]T,
    };
}

/// `DenseMatrix_Double` / `DenseMatrix_Float`, stored column-major.
pub fn DenseMatrix(comptime T: type) type {
    return extern struct {
        rowCount: c_int,
        columnCount: c_int,
        columnStride: c_int,
        attributes: Attributes,
        data: [*]T,
    };
}

/// `SparseSymbolicFactorOptions`.
///
/// `malloc` and `free` are how Sparse allocates the factor itself. They take
/// no context pointer, so a `std.mem.Allocator` cannot be threaded through
/// them without a process-global - this binding passes libc's and documents
/// the limitation. The workspace for `solve`, which is the allocation that
/// recurs per call, *is* sized by us and does come from a Zig allocator.
pub const SymbolicOptions = extern struct {
    control: u32 = 0,
    orderMethod: types.Order = .default,
    order: ?[*]c_int = null,
    ignoreRowsAndColumns: ?[*]c_int = null,
    malloc: *const fn (usize) callconv(.c) ?*anyopaque,
    free: *const fn (?*anyopaque) callconv(.c) void,
    reportError: ?*const fn ([*:0]const u8) callconv(.c) void = null,
};

/// `SparseNumericFactorOptions`.
///
/// The defaults here are `_SparseDefaultNumericFactorOptions_Double` from
/// `SolveImplementation.h`. Note `pivotTolerance` differs by element type
/// (0.01 for double, 0.1 for float), so use `defaultNumericOptions(T)` rather
/// than `.{}` when the type matters.
pub const NumericOptions = extern struct {
    control: u32 = 0,
    scalingMethod: types.Scaling = .default,
    scaling: ?*anyopaque = null,
    pivotTolerance: f64 = 0.01,
    zeroTolerance: f64 = 1e-4 * std.math.floatEps(f64),
};

/// Apple's per-type numeric defaults: a "recommended value for difficult
/// matrices" pivot tolerance, and a zero tolerance "a few orders of magnitude
/// below epsilon" for the element type.
pub fn defaultNumericOptions(comptime T: type) NumericOptions {
    return .{
        .pivotTolerance = if (T == f64) 0.01 else 0.1,
        .zeroTolerance = 1e-4 * @as(f64, std.math.floatEps(T)),
    };
}

/// `SparseOpaqueSymbolicFactorization` - the reference-counted symbolic
/// (ordering + pattern) half of a factorization.
pub const OpaqueSymbolic = extern struct {
    status: i32,
    rowCount: c_int,
    columnCount: c_int,
    attributes: Attributes,
    blockSize: u8,
    type: types.FactorizationType,
    factorization: ?*anyopaque,
    workspaceSize_Float: usize,
    workspaceSize_Double: usize,
    factorSize_Float: usize,
    factorSize_Double: usize,
};

/// `SparseOpaqueFactorization_Double` / `_Float`.
pub fn OpaqueFactorization(comptime T: type) type {
    return extern struct {
        /// The C struct holds no `T`-typed field - the numeric factor is behind
        /// `numericFactorization` - so this marker is what keeps
        /// `OpaqueFactorization(f32)` and `(f64)` from being the same type and
        /// silently interchangeable at the call boundary.
        pub const Element = T;

        status: i32,
        attributes: Attributes,
        symbolicFactorization: OpaqueSymbolic,
        userFactorStorage: bool,
        numericFactorization: ?*anyopaque,
        solveWorkspaceRequiredStatic: usize,
        solveWorkspaceRequiredPerRHS: usize,
    };
}

/// `enum CBLAS_TRANSPOSE`, as the iterative solvers' operator callback
/// receives it.
pub const Transpose = enum(c_int) {
    no_trans = 111,
    trans = 112,
    conj_trans = 113,
};

/// `SparsePreconditioner_t`.
pub const PreconditionerType = enum(c_int) {
    none = 0,
    user = 1,
    diagonal = 2,
    diag_scaling = 3,
};

/// `SparseIterativeStatus_t`.
pub const IterativeStatus = enum(i32) {
    converged = 0,
    max_iterations = 1,
    parameter_error = -1,
    ill_conditioned = -2,
    internal_error = -99,
    _,
};

/// `SparseGMRESVariant_t`.
pub const GMRESVariant = enum(u8) {
    /// Direct Quasi-GMRES: bounded memory, no restarts.
    dqgmres = 0,
    /// Restarted GMRES.
    gmres = 1,
    /// Flexible GMRES, for a preconditioner that varies between iterations.
    fgmres = 2,
};

/// `SparseLSMRConvergenceTest_t`.
pub const LSMRConvergenceTest = enum(c_int) {
    default = 0,
    fong_saunders = 1,
};

/// `SparseCGOptions`.
pub const CGOptions = extern struct {
    reportError: ?*const fn ([*:0]const u8) callconv(.c) void = null,
    maxIterations: c_int = 0,
    atol: f64 = 0,
    rtol: f64 = 0,
    reportStatus: ?*const fn ([*:0]const u8) callconv(.c) void = null,
};

/// `SparseGMRESOptions`.
pub const GMRESOptions = extern struct {
    reportError: ?*const fn ([*:0]const u8) callconv(.c) void = null,
    variant: GMRESVariant = .dqgmres,
    nvec: c_int = 0,
    maxIterations: c_int = 0,
    atol: f64 = 0,
    rtol: f64 = 0,
    reportStatus: ?*const fn ([*:0]const u8) callconv(.c) void = null,
};

/// `SparseLSMROptions`.
pub const LSMROptions = extern struct {
    reportError: ?*const fn ([*:0]const u8) callconv(.c) void = null,
    lambda: f64 = 0,
    nvec: c_int = 0,
    convergenceTest: LSMRConvergenceTest = .default,
    atol: f64 = 0,
    rtol: f64 = 0,
    btol: f64 = 0,
    conditionLimit: f64 = 0,
    maxIterations: c_int = 0,
    reportStatus: ?*const fn ([*:0]const u8) callconv(.c) void = null,
};

/// `SparseOpaquePreconditioner_Double` / `_Float`.
///
/// `apply` is an ordinary C function pointer, not a block - `mem` is passed
/// back to it unaltered, so a user preconditioner needs no block shim.
pub fn OpaquePreconditioner(comptime T: type) type {
    return extern struct {
        type: PreconditionerType,
        mem: ?*anyopaque,
        apply: ?*const fn (?*anyopaque, Transpose, DenseMatrix(T), DenseMatrix(T)) callconv(.c) void,
    };
}

/// `SparseOpaqueSubfactor_Double` / `_Float`.
pub fn OpaqueSubfactor(comptime T: type) type {
    return extern struct {
        attributes: Attributes,
        contents: types.Subfactor,
        factor: OpaqueFactorization(T),
        workspaceRequiredStatic: usize,
        workspaceRequiredPerRHS: usize,
    };
}

// ============================================================================
// Type-independent entry points
// ============================================================================

pub extern fn _SparseSymbolicFactorSymmetric(factorType: types.FactorizationType, Matrix: *const MatrixStructure, options: *const SymbolicOptions) OpaqueSymbolic;
pub extern fn _SparseSymbolicFactorQR(factorType: types.FactorizationType, Matrix: *const MatrixStructure, options: *const SymbolicOptions) OpaqueSymbolic;
pub extern fn _SparseRetainSymbolic(symbolicFactor: *OpaqueSymbolic) void;
pub extern fn _SparseDestroyOpaqueSymbolic(toFree: *OpaqueSymbolic) void;
pub extern fn _SparseGetOptionsFromSymbolicFactor(factor: *OpaqueSymbolic) SymbolicOptions;

// ============================================================================
// Double
// ============================================================================

pub extern fn _SparseConvertFromCoordinate_Double(m: c_int, n: c_int, nBlock: c_long, blockSize: u8, attributes: Attributes, row: [*]const c_int, col: [*]const c_int, val: [*]const f64, storage: [*]u8, workspace: [*]c_int) SparseMatrix(f64);
pub extern fn _SparseFactorSymmetric_Double(factorType: types.FactorizationType, Matrix: *const SparseMatrix(f64), sfoptions: *const SymbolicOptions, nfoptions: *const NumericOptions) OpaqueFactorization(f64);
pub extern fn _SparseFactorQR_Double(factorType: types.FactorizationType, Matrix: *const SparseMatrix(f64), sfoptions: *const SymbolicOptions, nfoptions: *const NumericOptions) OpaqueFactorization(f64);
pub extern fn _SparseNumericFactorSymmetric_Double(symbolicFactor: *OpaqueSymbolic, Matrix: *const SparseMatrix(f64), options: *const NumericOptions, factorStorage: ?*anyopaque, workspace: ?*anyopaque) OpaqueFactorization(f64);
pub extern fn _SparseNumericFactorQR_Double(symbolicFactor: *OpaqueSymbolic, Matrix: *const SparseMatrix(f64), options: *const NumericOptions, factorStorage: ?*anyopaque, workspace: ?*anyopaque) OpaqueFactorization(f64);
pub extern fn _SparseRefactorSymmetric_Double(Matrix: *const SparseMatrix(f64), Factorization: *OpaqueFactorization(f64), nfoptions: *const NumericOptions, workspace: ?*anyopaque) void;
pub extern fn _SparseRefactorQR_Double(Matrix: *const SparseMatrix(f64), Factorization: *OpaqueFactorization(f64), nfoptions: *const NumericOptions, workspace: ?*anyopaque) void;
pub extern fn _SparseMultiplySubfactor_Double(Subfactor: *const OpaqueSubfactor(f64), x: ?*const DenseMatrix(f64), y: *const DenseMatrix(f64), workspace: [*]u8) void;
pub extern fn _SparseSolveSubfactor_Double(Subfactor: *const OpaqueSubfactor(f64), b: ?*const DenseMatrix(f64), x: *const DenseMatrix(f64), workspace: [*]u8) void;
pub extern fn _SparseSolveOpaque_Double(Factored: *const OpaqueFactorization(f64), RHS: ?*const DenseMatrix(f64), Soln: *const DenseMatrix(f64), workspace: ?*anyopaque) void;
pub extern fn _SparseDestroyOpaqueNumeric_Double(toFree: *OpaqueFactorization(f64)) void;
pub extern fn _SparseRetainNumeric_Double(numericFactor: *OpaqueFactorization(f64)) void;
pub extern fn _SparseGetOptionsFromNumericFactor_Double(factor: *OpaqueFactorization(f64)) NumericOptions;
pub extern fn _SparseGetWorkspaceRequired_Double(Subfactor: types.Subfactor, Factor: OpaqueFactorization(f64), workStatic: *usize, workPerRHS: *usize) void;
pub extern fn _SparseCGSolve_Double(options: *const CGOptions, X: *DenseMatrix(f64), B: *DenseMatrix(f64), ApplyOperator: *const anyopaque, Preconditioner: ?*const OpaquePreconditioner(f64)) IterativeStatus;
pub extern fn _SparseGMRESSolve_Double(options: *GMRESOptions, X: *DenseMatrix(f64), B: *DenseMatrix(f64), ApplyOperator: *const anyopaque, Preconditioner: ?*const OpaquePreconditioner(f64)) IterativeStatus;
pub extern fn _SparseLSMRSolve_Double(options: *LSMROptions, X: *DenseMatrix(f64), B: *DenseMatrix(f64), ApplyOperator: *const anyopaque, Preconditioner: ?*const OpaquePreconditioner(f64)) IterativeStatus;
pub extern fn _SparseCreatePreconditioner_Double(type: PreconditionerType, A: *SparseMatrix(f64)) OpaquePreconditioner(f64);
pub extern fn _SparseReleaseOpaquePreconditioner_Double(toFree: *OpaquePreconditioner(f64)) void;
pub extern fn _SparseSpMV_Double(alpha: f64, A: SparseMatrix(f64), x: DenseMatrix(f64), accumulate: bool, y: DenseMatrix(f64)) void;

// ============================================================================
// Float
// ============================================================================

pub extern fn _SparseConvertFromCoordinate_Float(m: c_int, n: c_int, nBlock: c_long, blockSize: u8, attributes: Attributes, row: [*]const c_int, col: [*]const c_int, val: [*]const f32, storage: [*]u8, workspace: [*]c_int) SparseMatrix(f32);
pub extern fn _SparseFactorSymmetric_Float(factorType: types.FactorizationType, Matrix: *const SparseMatrix(f32), sfoptions: *const SymbolicOptions, nfoptions: *const NumericOptions) OpaqueFactorization(f32);
pub extern fn _SparseFactorQR_Float(factorType: types.FactorizationType, Matrix: *const SparseMatrix(f32), sfoptions: *const SymbolicOptions, nfoptions: *const NumericOptions) OpaqueFactorization(f32);
pub extern fn _SparseNumericFactorSymmetric_Float(symbolicFactor: *OpaqueSymbolic, Matrix: *const SparseMatrix(f32), options: *const NumericOptions, factorStorage: ?*anyopaque, workspace: ?*anyopaque) OpaqueFactorization(f32);
pub extern fn _SparseNumericFactorQR_Float(symbolicFactor: *OpaqueSymbolic, Matrix: *const SparseMatrix(f32), options: *const NumericOptions, factorStorage: ?*anyopaque, workspace: ?*anyopaque) OpaqueFactorization(f32);
pub extern fn _SparseRefactorSymmetric_Float(Matrix: *const SparseMatrix(f32), Factorization: *OpaqueFactorization(f32), nfoptions: *const NumericOptions, workspace: ?*anyopaque) void;
pub extern fn _SparseRefactorQR_Float(Matrix: *const SparseMatrix(f32), Factorization: *OpaqueFactorization(f32), nfoptions: *const NumericOptions, workspace: ?*anyopaque) void;
pub extern fn _SparseMultiplySubfactor_Float(Subfactor: *const OpaqueSubfactor(f32), x: ?*const DenseMatrix(f32), y: *const DenseMatrix(f32), workspace: [*]u8) void;
pub extern fn _SparseSolveSubfactor_Float(Subfactor: *const OpaqueSubfactor(f32), b: ?*const DenseMatrix(f32), x: *const DenseMatrix(f32), workspace: [*]u8) void;
pub extern fn _SparseSolveOpaque_Float(Factored: *const OpaqueFactorization(f32), RHS: ?*const DenseMatrix(f32), Soln: *const DenseMatrix(f32), workspace: ?*anyopaque) void;
pub extern fn _SparseDestroyOpaqueNumeric_Float(toFree: *OpaqueFactorization(f32)) void;
pub extern fn _SparseRetainNumeric_Float(numericFactor: *OpaqueFactorization(f32)) void;
pub extern fn _SparseGetOptionsFromNumericFactor_Float(factor: *OpaqueFactorization(f32)) NumericOptions;
pub extern fn _SparseGetWorkspaceRequired_Float(Subfactor: types.Subfactor, Factor: OpaqueFactorization(f32), workStatic: *usize, workPerRHS: *usize) void;
pub extern fn _SparseCGSolve_Float(options: *const CGOptions, X: *DenseMatrix(f32), B: *DenseMatrix(f32), ApplyOperator: *const anyopaque, Preconditioner: ?*const OpaquePreconditioner(f32)) IterativeStatus;
pub extern fn _SparseGMRESSolve_Float(options: *GMRESOptions, X: *DenseMatrix(f32), B: *DenseMatrix(f32), ApplyOperator: *const anyopaque, Preconditioner: ?*const OpaquePreconditioner(f32)) IterativeStatus;
pub extern fn _SparseLSMRSolve_Float(options: *LSMROptions, X: *DenseMatrix(f32), B: *DenseMatrix(f32), ApplyOperator: *const anyopaque, Preconditioner: ?*const OpaquePreconditioner(f32)) IterativeStatus;
pub extern fn _SparseCreatePreconditioner_Float(type: PreconditionerType, A: *SparseMatrix(f32)) OpaquePreconditioner(f32);
pub extern fn _SparseReleaseOpaquePreconditioner_Float(toFree: *OpaquePreconditioner(f32)) void;
pub extern fn _SparseSpMV_Float(alpha: f32, A: SparseMatrix(f32), x: DenseMatrix(f32), accumulate: bool, y: DenseMatrix(f32)) void;

// ============================================================================
// SparseGetInertia
// ============================================================================

// `SparseGetInertia` (Solve.h:2416, 2445) is the one public entry point that is
// `overloadable` but NOT `static inline`. It therefore exists out of line - and
// only under its C++-mangled name, since `overloadable` implies C++ mangling.
//
// This is more brittle than the `_Sparse*` route: the mangling encodes the
// parameter *type names*, so renaming `SparseOpaqueFactorization_Double` would
// break the link even if the ABI were unchanged. It is exactly one function, it
// has been stable since macOS 13, and there is no other way to reach it, so the
// trade is worth making - but a link error here means "Apple renamed a type",
// not "the struct layout drifted".
pub const _SparseGetInertia_Double = @extern(*const fn (OpaqueFactorization(f64), *c_int, *c_int, *c_int) callconv(.c) c_int, .{
    .name = "_Z16SparseGetInertia32SparseOpaqueFactorization_DoublePiS0_S0_",
});
pub const _SparseGetInertia_Float = @extern(*const fn (OpaqueFactorization(f32), *c_int, *c_int, *c_int) callconv(.c) c_int, .{
    .name = "_Z16SparseGetInertia31SparseOpaqueFactorization_FloatPiS0_S0_",
});

// ============================================================================
// Comptime dispatch
// ============================================================================

/// Selects the `_Double` or `_Float` entry points for `T`.
pub fn fns(comptime T: type) type {
    return switch (T) {
        f64 => struct {
            pub const convertFromCoordinate = _SparseConvertFromCoordinate_Double;
            pub const factorSymmetric = _SparseFactorSymmetric_Double;
            pub const factorQR = _SparseFactorQR_Double;
            pub const numericFactorSymmetric = _SparseNumericFactorSymmetric_Double;
            pub const numericFactorQR = _SparseNumericFactorQR_Double;
            pub const refactorSymmetric = _SparseRefactorSymmetric_Double;
            pub const refactorQR = _SparseRefactorQR_Double;
            pub const solveOpaque = _SparseSolveOpaque_Double;
            pub const multiplySubfactor = _SparseMultiplySubfactor_Double;
            pub const solveSubfactor = _SparseSolveSubfactor_Double;
            pub const destroyOpaqueNumeric = _SparseDestroyOpaqueNumeric_Double;
            pub const retainNumeric = _SparseRetainNumeric_Double;
            pub const getOptionsFromNumericFactor = _SparseGetOptionsFromNumericFactor_Double;
            pub const getWorkspaceRequired = _SparseGetWorkspaceRequired_Double;
            pub const spmv = _SparseSpMV_Double;
            pub const cgSolve = _SparseCGSolve_Double;
            pub const gmresSolve = _SparseGMRESSolve_Double;
            pub const lsmrSolve = _SparseLSMRSolve_Double;
            pub const createPreconditioner = _SparseCreatePreconditioner_Double;
            pub const releasePreconditioner = _SparseReleaseOpaquePreconditioner_Double;
            pub const getInertia = _SparseGetInertia_Double;
        },
        f32 => struct {
            pub const convertFromCoordinate = _SparseConvertFromCoordinate_Float;
            pub const factorSymmetric = _SparseFactorSymmetric_Float;
            pub const factorQR = _SparseFactorQR_Float;
            pub const numericFactorSymmetric = _SparseNumericFactorSymmetric_Float;
            pub const numericFactorQR = _SparseNumericFactorQR_Float;
            pub const refactorSymmetric = _SparseRefactorSymmetric_Float;
            pub const refactorQR = _SparseRefactorQR_Float;
            pub const solveOpaque = _SparseSolveOpaque_Float;
            pub const multiplySubfactor = _SparseMultiplySubfactor_Float;
            pub const solveSubfactor = _SparseSolveSubfactor_Float;
            pub const destroyOpaqueNumeric = _SparseDestroyOpaqueNumeric_Float;
            pub const retainNumeric = _SparseRetainNumeric_Float;
            pub const getOptionsFromNumericFactor = _SparseGetOptionsFromNumericFactor_Float;
            pub const getWorkspaceRequired = _SparseGetWorkspaceRequired_Float;
            pub const spmv = _SparseSpMV_Float;
            pub const cgSolve = _SparseCGSolve_Float;
            pub const gmresSolve = _SparseGMRESSolve_Float;
            pub const lsmrSolve = _SparseLSMRSolve_Float;
            pub const createPreconditioner = _SparseCreatePreconditioner_Float;
            pub const releasePreconditioner = _SparseReleaseOpaquePreconditioner_Float;
            pub const getInertia = _SparseGetInertia_Float;
        },
        else => @compileError("Sparse supports f32 and f64 only, got " ++ @typeName(T)),
    };
}

// ============================================================================
// Layout assertions
// ============================================================================

// Reference values from compiling a sizeof/offsetof dump against the real
// headers on macOS 15.4 / arm64. These are not decoration: every struct here is
// passed to or returned from Accelerate by value, so a silent layout drift
// would corrupt memory rather than fail to compile. Running the suite on a new
// SDK or architecture re-checks them.
test "ABI struct layouts match the C headers" {
    const expectEqual = std.testing.expectEqual;

    try expectEqual(@as(usize, 32), @sizeOf(MatrixStructure));
    try expectEqual(@as(usize, 0), @offsetOf(MatrixStructure, "rowCount"));
    try expectEqual(@as(usize, 4), @offsetOf(MatrixStructure, "columnCount"));
    try expectEqual(@as(usize, 8), @offsetOf(MatrixStructure, "columnStarts"));
    try expectEqual(@as(usize, 16), @offsetOf(MatrixStructure, "rowIndices"));
    try expectEqual(@as(usize, 24), @offsetOf(MatrixStructure, "attributes"));
    try expectEqual(@as(usize, 28), @offsetOf(MatrixStructure, "blockSize"));

    inline for (.{ f64, f32 }) |T| {
        try expectEqual(@as(usize, 40), @sizeOf(SparseMatrix(T)));
        try expectEqual(@as(usize, 32), @offsetOf(SparseMatrix(T), "data"));
        try expectEqual(@as(usize, 16), @sizeOf(DenseVector(T)));
        try expectEqual(@as(usize, 24), @sizeOf(DenseMatrix(T)));
        try expectEqual(@as(usize, 12), @offsetOf(DenseMatrix(T), "attributes"));
        try expectEqual(@as(usize, 16), @offsetOf(DenseMatrix(T), "data"));

        try expectEqual(@as(usize, 104), @sizeOf(OpaqueFactorization(T)));
        try expectEqual(@as(usize, 4), @offsetOf(OpaqueFactorization(T), "attributes"));
        try expectEqual(@as(usize, 8), @offsetOf(OpaqueFactorization(T), "symbolicFactorization"));
        try expectEqual(@as(usize, 72), @offsetOf(OpaqueFactorization(T), "userFactorStorage"));
        try expectEqual(@as(usize, 80), @offsetOf(OpaqueFactorization(T), "numericFactorization"));
        try expectEqual(@as(usize, 88), @offsetOf(OpaqueFactorization(T), "solveWorkspaceRequiredStatic"));
        try expectEqual(@as(usize, 96), @offsetOf(OpaqueFactorization(T), "solveWorkspaceRequiredPerRHS"));

        try expectEqual(@as(usize, 128), @sizeOf(OpaqueSubfactor(T)));
        try expectEqual(@as(usize, 24), @sizeOf(OpaquePreconditioner(T)));
    }

    try expectEqual(@as(usize, 48), @sizeOf(SymbolicOptions));
    try expectEqual(@as(usize, 4), @offsetOf(SymbolicOptions, "orderMethod"));
    try expectEqual(@as(usize, 8), @offsetOf(SymbolicOptions, "order"));
    try expectEqual(@as(usize, 16), @offsetOf(SymbolicOptions, "ignoreRowsAndColumns"));
    try expectEqual(@as(usize, 24), @offsetOf(SymbolicOptions, "malloc"));
    try expectEqual(@as(usize, 32), @offsetOf(SymbolicOptions, "free"));
    try expectEqual(@as(usize, 40), @offsetOf(SymbolicOptions, "reportError"));

    try expectEqual(@as(usize, 32), @sizeOf(NumericOptions));
    try expectEqual(@as(usize, 4), @offsetOf(NumericOptions, "scalingMethod"));
    try expectEqual(@as(usize, 8), @offsetOf(NumericOptions, "scaling"));
    try expectEqual(@as(usize, 16), @offsetOf(NumericOptions, "pivotTolerance"));
    try expectEqual(@as(usize, 24), @offsetOf(NumericOptions, "zeroTolerance"));

    try expectEqual(@as(usize, 64), @sizeOf(OpaqueSymbolic));
    try expectEqual(@as(usize, 12), @offsetOf(OpaqueSymbolic, "attributes"));
    try expectEqual(@as(usize, 16), @offsetOf(OpaqueSymbolic, "blockSize"));
    try expectEqual(@as(usize, 17), @offsetOf(OpaqueSymbolic, "type"));
    try expectEqual(@as(usize, 24), @offsetOf(OpaqueSymbolic, "factorization"));
    try expectEqual(@as(usize, 32), @offsetOf(OpaqueSymbolic, "workspaceSize_Float"));
    try expectEqual(@as(usize, 40), @offsetOf(OpaqueSymbolic, "workspaceSize_Double"));
    try expectEqual(@as(usize, 48), @offsetOf(OpaqueSymbolic, "factorSize_Float"));
    try expectEqual(@as(usize, 56), @offsetOf(OpaqueSymbolic, "factorSize_Double"));

    try expectEqual(@as(usize, 40), @sizeOf(CGOptions));
    try expectEqual(@as(usize, 48), @sizeOf(GMRESOptions));
    try expectEqual(@as(usize, 72), @sizeOf(LSMROptions));
    try expectEqual(@as(usize, 8), @offsetOf(LSMROptions, "lambda"));
    try expectEqual(@as(usize, 16), @offsetOf(LSMROptions, "nvec"));
    try expectEqual(@as(usize, 20), @offsetOf(LSMROptions, "convergenceTest"));
    try expectEqual(@as(usize, 56), @offsetOf(LSMROptions, "maxIterations"));

    // `c_long` is what `columnStarts` is declared as; on any target where it is
    // not pointer-sized the CSC index type here would be wrong.
    try expectEqual(@sizeOf(usize), @sizeOf(c_long));
}

test "defaultNumericOptions reproduces Apple's per-type defaults" {
    const d = defaultNumericOptions(f64);
    try std.testing.expectEqual(@as(f64, 0.01), d.pivotTolerance);
    try std.testing.expectEqual(@as(f64, 1e-4 * std.math.floatEps(f64)), d.zeroTolerance);

    const f = defaultNumericOptions(f32);
    try std.testing.expectEqual(@as(f64, 0.1), f.pivotTolerance);
    try std.testing.expectEqual(@as(f64, 1e-4 * @as(f64, std.math.floatEps(f32))), f.zeroTolerance);
}
