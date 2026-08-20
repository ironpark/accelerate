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
const AttributesComplex = types.AttributesComplex;
const AttributesFor = types.AttributesFor;
const Complex = types.Complex;

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

/// `SparseMatrixStructureComplex` - the same shape as `MatrixStructure` but
/// carrying `AttributesComplex`, whose `kind` field is a bit wider.
///
/// The two are *not* interchangeable and cannot be made so by casting: use
/// `_SparseFromStructureComplex` / `_SparseToStructureComplex`, which are
/// Apple's own conversions and know how `.hermitian` maps onto the narrower
/// real `kind`.
pub const MatrixStructureComplex = extern struct {
    rowCount: c_int,
    columnCount: c_int,
    columnStarts: [*]c_long,
    rowIndices: [*]c_int,
    attributes: AttributesComplex,
    blockSize: u8,
};

/// The structure type that goes with element type `T`.
pub fn MatrixStructureFor(comptime T: type) type {
    return if (types.isComplex(T)) MatrixStructureComplex else MatrixStructure;
}

/// `SparseMatrix_Double` / `_Float` / `_Complex_Double` / `_Complex_Float`.
///
/// `data` holds `blockSize * blockSize * N` values for `N` structurally
/// non-zero blocks, each block stored column-major.
pub fn SparseMatrix(comptime T: type) type {
    return extern struct {
        structure: MatrixStructureFor(T),
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

/// `DenseMatrix_Double` and friends, stored column-major.
pub fn DenseMatrix(comptime T: type) type {
    return extern struct {
        rowCount: c_int,
        columnCount: c_int,
        columnStride: c_int,
        attributes: AttributesFor(T),
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
    // Both defaults are set by the *precision*, not by whether the element is
    // complex: Apple's `_SparseDefaultNumericFactorOptions_Complex_Double`
    // carries the same numbers as the `_Double` one.
    const R = types.Real(T);
    return .{
        .pivotTolerance = if (R == f64) 0.01 else 0.1,
        .zeroTolerance = 1e-4 * @as(f64, std.math.floatEps(R)),
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
        attributes: AttributesFor(T),
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
        attributes: AttributesFor(T),
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
pub extern fn _SparseSymbolicFactorLU(factorType: types.FactorizationType, Matrix: *const MatrixStructure, options: *const SymbolicOptions) OpaqueSymbolic;
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
pub extern fn _SparseFactorLU_Double(factorType: types.FactorizationType, Matrix: *const SparseMatrix(f64), sfoptions: *const SymbolicOptions, nfoptions: *const NumericOptions) OpaqueFactorization(f64);
pub extern fn _SparseNumericFactorLU_Double(symbolicFactor: *OpaqueSymbolic, Matrix: *const SparseMatrix(f64), options: *const NumericOptions, factorStorage: ?*anyopaque, workspace: ?*anyopaque) OpaqueFactorization(f64);
pub extern fn _SparseRefactorLU_Double(Matrix: *const SparseMatrix(f64), Factorization: *OpaqueFactorization(f64), nfoptions: *const NumericOptions, workspace: ?*anyopaque) void;
pub extern fn _SparseUpdatePartialRefactorLU_Double(Opaque: *OpaqueFactorization(f64), updateCount: c_int, updatedIndices: [*]const c_int, newMatrix: SparseMatrix(f64)) void;

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
pub extern fn _SparseFactorLU_Float(factorType: types.FactorizationType, Matrix: *const SparseMatrix(f32), sfoptions: *const SymbolicOptions, nfoptions: *const NumericOptions) OpaqueFactorization(f32);
pub extern fn _SparseNumericFactorLU_Float(symbolicFactor: *OpaqueSymbolic, Matrix: *const SparseMatrix(f32), options: *const NumericOptions, factorStorage: ?*anyopaque, workspace: ?*anyopaque) OpaqueFactorization(f32);
pub extern fn _SparseRefactorLU_Float(Matrix: *const SparseMatrix(f32), Factorization: *OpaqueFactorization(f32), nfoptions: *const NumericOptions, workspace: ?*anyopaque) void;
pub extern fn _SparseUpdatePartialRefactorLU_Float(Opaque: *OpaqueFactorization(f32), updateCount: c_int, updatedIndices: [*]const c_int, newMatrix: SparseMatrix(f32)) void;

// ============================================================================
// Complex
// ============================================================================
//
// Two things differ from the real blocks above, both of them consequences of
// `SparseAttributesComplex_t` being a separate struct rather than an extra
// field:
//
//  * `SparseMatrix(Complex(f64))` embeds `MatrixStructureComplex`, so it is a
//    distinct type from `SparseMatrix(f64)` even though the two have the same
//    size. The symbolic-factor entry points take the *real* structure, which
//    is what `_SparseFromStructureComplex` is for.
//  * There is a `_SparseFactorHermitian` alongside `_SparseFactorSymmetric`.
//    Hermitian is the one to use (macOS 15.5); complex *symmetric* - a genuine
//    `A = A^T` with complex entries - needs macOS 26.
//
// `_SparseGetInertia` has no complex spelling: inertia is defined for the
// real symmetric case only.

/// `_SparseFromStructureComplex` - the complex-attributed structure, converted
/// to the real one the symbolic factorization entry points take. Apple owns
/// the `kind` mapping; do not reimplement it by casting.
pub extern fn _SparseFromStructureComplex(K: MatrixStructureComplex) MatrixStructure;
pub extern fn _SparseToStructureComplex(K: MatrixStructure) MatrixStructureComplex;
pub extern fn _SparseFromAttributeComplex(K: AttributesComplex) Attributes;
pub extern fn _SparseToAttributeComplex(K: Attributes) AttributesComplex;

// -- Complex double --

pub extern fn _SparseConvertFromCoordinate_Complex_Double(m: c_int, n: c_int, nBlock: c_long, blockSize: u8, attributes: AttributesComplex, row: [*]const c_int, col: [*]const c_int, val: [*]const Complex(f64), storage: [*]u8, workspace: [*]c_int) SparseMatrix(Complex(f64));
pub extern fn _SparseFactorSymmetric_Complex_Double(factorType: types.FactorizationType, Matrix: *const SparseMatrix(Complex(f64)), sfoptions: *const SymbolicOptions, nfoptions: *const NumericOptions) OpaqueFactorization(Complex(f64));
pub extern fn _SparseFactorHermitian_Complex_Double(factorType: types.FactorizationType, Matrix: *const SparseMatrix(Complex(f64)), sfoptions: *const SymbolicOptions, nfoptions: *const NumericOptions) OpaqueFactorization(Complex(f64));
pub extern fn _SparseFactorQR_Complex_Double(factorType: types.FactorizationType, Matrix: *const SparseMatrix(Complex(f64)), sfoptions: *const SymbolicOptions, nfoptions: *const NumericOptions) OpaqueFactorization(Complex(f64));
pub extern fn _SparseFactorLU_Complex_Double(factorType: types.FactorizationType, Matrix: *const SparseMatrix(Complex(f64)), sfoptions: *const SymbolicOptions, nfoptions: *const NumericOptions) OpaqueFactorization(Complex(f64));
pub extern fn _SparseNumericFactorSymmetric_Complex_Double(symbolicFactor: *OpaqueSymbolic, Matrix: *const SparseMatrix(Complex(f64)), options: *const NumericOptions, factorStorage: ?*anyopaque, workspace: ?*anyopaque) OpaqueFactorization(Complex(f64));
pub extern fn _SparseNumericFactorHermitian_Complex_Double(symbolicFactor: *OpaqueSymbolic, Matrix: *const SparseMatrix(Complex(f64)), options: *const NumericOptions, factorStorage: ?*anyopaque, workspace: ?*anyopaque) OpaqueFactorization(Complex(f64));
pub extern fn _SparseNumericFactorQR_Complex_Double(symbolicFactor: *OpaqueSymbolic, Matrix: *const SparseMatrix(Complex(f64)), options: *const NumericOptions, factorStorage: ?*anyopaque, workspace: ?*anyopaque) OpaqueFactorization(Complex(f64));
pub extern fn _SparseNumericFactorLU_Complex_Double(symbolicFactor: *OpaqueSymbolic, Matrix: *const SparseMatrix(Complex(f64)), options: *const NumericOptions, factorStorage: ?*anyopaque, workspace: ?*anyopaque) OpaqueFactorization(Complex(f64));
pub extern fn _SparseRefactorSymmetric_Complex_Double(Matrix: *const SparseMatrix(Complex(f64)), Factorization: *OpaqueFactorization(Complex(f64)), nfoptions: *const NumericOptions, workspace: ?*anyopaque) void;
pub extern fn _SparseRefactorHermitian_Complex_Double(Matrix: *const SparseMatrix(Complex(f64)), Factorization: *OpaqueFactorization(Complex(f64)), nfoptions: *const NumericOptions, workspace: ?*anyopaque) void;
pub extern fn _SparseRefactorQR_Complex_Double(Matrix: *const SparseMatrix(Complex(f64)), Factorization: *OpaqueFactorization(Complex(f64)), nfoptions: *const NumericOptions, workspace: ?*anyopaque) void;
pub extern fn _SparseRefactorLU_Complex_Double(Matrix: *const SparseMatrix(Complex(f64)), Factorization: *OpaqueFactorization(Complex(f64)), nfoptions: *const NumericOptions, workspace: ?*anyopaque) void;
pub extern fn _SparseUpdatePartialRefactorLU_Complex_Double(Opaque: *OpaqueFactorization(Complex(f64)), updateCount: c_int, updatedIndices: [*]const c_int, newMatrix: SparseMatrix(Complex(f64))) void;
pub extern fn _SparseMultiplySubfactor_Complex_Double(Subfactor: *const OpaqueSubfactor(Complex(f64)), x: ?*const DenseMatrix(Complex(f64)), y: *const DenseMatrix(Complex(f64)), workspace: [*]u8) void;
pub extern fn _SparseSolveSubfactor_Complex_Double(Subfactor: *const OpaqueSubfactor(Complex(f64)), b: ?*const DenseMatrix(Complex(f64)), x: *const DenseMatrix(Complex(f64)), workspace: [*]u8) void;
pub extern fn _SparseSolveOpaque_Complex_Double(Factored: *const OpaqueFactorization(Complex(f64)), RHS: ?*const DenseMatrix(Complex(f64)), Soln: *const DenseMatrix(Complex(f64)), workspace: ?*anyopaque) void;
pub extern fn _SparseDestroyOpaqueNumeric_Complex_Double(toFree: *OpaqueFactorization(Complex(f64))) void;
pub extern fn _SparseRetainNumeric_Complex_Double(numericFactor: *OpaqueFactorization(Complex(f64))) void;
pub extern fn _SparseGetOptionsFromNumericFactor_Complex_Double(factor: *OpaqueFactorization(Complex(f64))) NumericOptions;
pub extern fn _SparseGetWorkspaceRequired_Complex_Double(Subfactor: types.Subfactor, Factor: OpaqueFactorization(Complex(f64)), workStatic: *usize, workPerRHS: *usize) void;
pub extern fn _SparseCGSolve_Complex_Double(options: *const CGOptions, X: *DenseMatrix(Complex(f64)), B: *DenseMatrix(Complex(f64)), ApplyOperator: *const anyopaque, Preconditioner: ?*const OpaquePreconditioner(Complex(f64))) IterativeStatus;
pub extern fn _SparseGMRESSolve_Complex_Double(options: *GMRESOptions, X: *DenseMatrix(Complex(f64)), B: *DenseMatrix(Complex(f64)), ApplyOperator: *const anyopaque, Preconditioner: ?*const OpaquePreconditioner(Complex(f64))) IterativeStatus;
pub extern fn _SparseLSMRSolve_Complex_Double(options: *LSMROptions, X: *DenseMatrix(Complex(f64)), B: *DenseMatrix(Complex(f64)), ApplyOperator: *const anyopaque, Preconditioner: ?*const OpaquePreconditioner(Complex(f64))) IterativeStatus;
pub extern fn _SparseCreatePreconditioner_Complex_Double(type: PreconditionerType, A: *SparseMatrix(Complex(f64))) OpaquePreconditioner(Complex(f64));
pub extern fn _SparseReleaseOpaquePreconditioner_Complex_Double(toFree: *OpaquePreconditioner(Complex(f64))) void;
pub extern fn _SparseSpMV_Complex_Double(alpha: Complex(f64), A: SparseMatrix(Complex(f64)), x: DenseMatrix(Complex(f64)), accumulate: bool, y: DenseMatrix(Complex(f64))) void;

// -- Complex float --

pub extern fn _SparseConvertFromCoordinate_Complex_Float(m: c_int, n: c_int, nBlock: c_long, blockSize: u8, attributes: AttributesComplex, row: [*]const c_int, col: [*]const c_int, val: [*]const Complex(f32), storage: [*]u8, workspace: [*]c_int) SparseMatrix(Complex(f32));
pub extern fn _SparseFactorSymmetric_Complex_Float(factorType: types.FactorizationType, Matrix: *const SparseMatrix(Complex(f32)), sfoptions: *const SymbolicOptions, nfoptions: *const NumericOptions) OpaqueFactorization(Complex(f32));
pub extern fn _SparseFactorHermitian_Complex_Float(factorType: types.FactorizationType, Matrix: *const SparseMatrix(Complex(f32)), sfoptions: *const SymbolicOptions, nfoptions: *const NumericOptions) OpaqueFactorization(Complex(f32));
pub extern fn _SparseFactorQR_Complex_Float(factorType: types.FactorizationType, Matrix: *const SparseMatrix(Complex(f32)), sfoptions: *const SymbolicOptions, nfoptions: *const NumericOptions) OpaqueFactorization(Complex(f32));
pub extern fn _SparseFactorLU_Complex_Float(factorType: types.FactorizationType, Matrix: *const SparseMatrix(Complex(f32)), sfoptions: *const SymbolicOptions, nfoptions: *const NumericOptions) OpaqueFactorization(Complex(f32));
pub extern fn _SparseNumericFactorSymmetric_Complex_Float(symbolicFactor: *OpaqueSymbolic, Matrix: *const SparseMatrix(Complex(f32)), options: *const NumericOptions, factorStorage: ?*anyopaque, workspace: ?*anyopaque) OpaqueFactorization(Complex(f32));
pub extern fn _SparseNumericFactorHermitian_Complex_Float(symbolicFactor: *OpaqueSymbolic, Matrix: *const SparseMatrix(Complex(f32)), options: *const NumericOptions, factorStorage: ?*anyopaque, workspace: ?*anyopaque) OpaqueFactorization(Complex(f32));
pub extern fn _SparseNumericFactorQR_Complex_Float(symbolicFactor: *OpaqueSymbolic, Matrix: *const SparseMatrix(Complex(f32)), options: *const NumericOptions, factorStorage: ?*anyopaque, workspace: ?*anyopaque) OpaqueFactorization(Complex(f32));
pub extern fn _SparseNumericFactorLU_Complex_Float(symbolicFactor: *OpaqueSymbolic, Matrix: *const SparseMatrix(Complex(f32)), options: *const NumericOptions, factorStorage: ?*anyopaque, workspace: ?*anyopaque) OpaqueFactorization(Complex(f32));
pub extern fn _SparseRefactorSymmetric_Complex_Float(Matrix: *const SparseMatrix(Complex(f32)), Factorization: *OpaqueFactorization(Complex(f32)), nfoptions: *const NumericOptions, workspace: ?*anyopaque) void;
pub extern fn _SparseRefactorHermitian_Complex_Float(Matrix: *const SparseMatrix(Complex(f32)), Factorization: *OpaqueFactorization(Complex(f32)), nfoptions: *const NumericOptions, workspace: ?*anyopaque) void;
pub extern fn _SparseRefactorQR_Complex_Float(Matrix: *const SparseMatrix(Complex(f32)), Factorization: *OpaqueFactorization(Complex(f32)), nfoptions: *const NumericOptions, workspace: ?*anyopaque) void;
pub extern fn _SparseRefactorLU_Complex_Float(Matrix: *const SparseMatrix(Complex(f32)), Factorization: *OpaqueFactorization(Complex(f32)), nfoptions: *const NumericOptions, workspace: ?*anyopaque) void;
pub extern fn _SparseUpdatePartialRefactorLU_Complex_Float(Opaque: *OpaqueFactorization(Complex(f32)), updateCount: c_int, updatedIndices: [*]const c_int, newMatrix: SparseMatrix(Complex(f32))) void;
pub extern fn _SparseMultiplySubfactor_Complex_Float(Subfactor: *const OpaqueSubfactor(Complex(f32)), x: ?*const DenseMatrix(Complex(f32)), y: *const DenseMatrix(Complex(f32)), workspace: [*]u8) void;
pub extern fn _SparseSolveSubfactor_Complex_Float(Subfactor: *const OpaqueSubfactor(Complex(f32)), b: ?*const DenseMatrix(Complex(f32)), x: *const DenseMatrix(Complex(f32)), workspace: [*]u8) void;
pub extern fn _SparseSolveOpaque_Complex_Float(Factored: *const OpaqueFactorization(Complex(f32)), RHS: ?*const DenseMatrix(Complex(f32)), Soln: *const DenseMatrix(Complex(f32)), workspace: ?*anyopaque) void;
pub extern fn _SparseDestroyOpaqueNumeric_Complex_Float(toFree: *OpaqueFactorization(Complex(f32))) void;
pub extern fn _SparseRetainNumeric_Complex_Float(numericFactor: *OpaqueFactorization(Complex(f32))) void;
pub extern fn _SparseGetOptionsFromNumericFactor_Complex_Float(factor: *OpaqueFactorization(Complex(f32))) NumericOptions;
pub extern fn _SparseGetWorkspaceRequired_Complex_Float(Subfactor: types.Subfactor, Factor: OpaqueFactorization(Complex(f32)), workStatic: *usize, workPerRHS: *usize) void;
pub extern fn _SparseCGSolve_Complex_Float(options: *const CGOptions, X: *DenseMatrix(Complex(f32)), B: *DenseMatrix(Complex(f32)), ApplyOperator: *const anyopaque, Preconditioner: ?*const OpaquePreconditioner(Complex(f32))) IterativeStatus;
pub extern fn _SparseGMRESSolve_Complex_Float(options: *GMRESOptions, X: *DenseMatrix(Complex(f32)), B: *DenseMatrix(Complex(f32)), ApplyOperator: *const anyopaque, Preconditioner: ?*const OpaquePreconditioner(Complex(f32))) IterativeStatus;
pub extern fn _SparseLSMRSolve_Complex_Float(options: *LSMROptions, X: *DenseMatrix(Complex(f32)), B: *DenseMatrix(Complex(f32)), ApplyOperator: *const anyopaque, Preconditioner: ?*const OpaquePreconditioner(Complex(f32))) IterativeStatus;
pub extern fn _SparseCreatePreconditioner_Complex_Float(type: PreconditionerType, A: *SparseMatrix(Complex(f32))) OpaquePreconditioner(Complex(f32));
pub extern fn _SparseReleaseOpaquePreconditioner_Complex_Float(toFree: *OpaquePreconditioner(Complex(f32))) void;
pub extern fn _SparseSpMV_Complex_Float(alpha: Complex(f32), A: SparseMatrix(Complex(f32)), x: DenseMatrix(Complex(f32)), accumulate: bool, y: DenseMatrix(Complex(f32))) void;

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
/// The per-element-type dispatch table.
///
/// The four variants differ only by a name suffix (`_Double`, `_Float`,
/// `_Complex_Double`, `_Complex_Float`) - that suffix is C macro expansion on
/// Apple's side - so rather than list ~30 declarations four times over, this
/// resolves each one by name at comptime. A misspelling is still a compile
/// error, and `c.zig`'s link test still forces every declaration to resolve.
pub fn fns(comptime T: type) type {
    const suffix = switch (T) {
        f64 => "_Double",
        f32 => "_Float",
        Complex(f64) => "_Complex_Double",
        Complex(f32) => "_Complex_Float",
        else => @compileError("Sparse supports f32, f64, Complex(f32) and Complex(f64) only, got " ++ @typeName(T)),
    };
    const Self = @This();
    const get = struct {
        fn f(comptime base: []const u8) @TypeOf(@field(Self, base ++ suffix)) {
            return @field(Self, base ++ suffix);
        }
    }.f;

    return struct {
        pub const convertFromCoordinate = get("_SparseConvertFromCoordinate");
        pub const factorSymmetric = get("_SparseFactorSymmetric");
        pub const factorQR = get("_SparseFactorQR");
        pub const factorLU = get("_SparseFactorLU");
        pub const numericFactorSymmetric = get("_SparseNumericFactorSymmetric");
        pub const numericFactorQR = get("_SparseNumericFactorQR");
        pub const numericFactorLU = get("_SparseNumericFactorLU");
        pub const refactorSymmetric = get("_SparseRefactorSymmetric");
        pub const refactorQR = get("_SparseRefactorQR");
        pub const refactorLU = get("_SparseRefactorLU");
        pub const updatePartialRefactorLU = get("_SparseUpdatePartialRefactorLU");
        pub const solveOpaque = get("_SparseSolveOpaque");
        pub const multiplySubfactor = get("_SparseMultiplySubfactor");
        pub const solveSubfactor = get("_SparseSolveSubfactor");
        pub const destroyOpaqueNumeric = get("_SparseDestroyOpaqueNumeric");
        pub const retainNumeric = get("_SparseRetainNumeric");
        pub const getOptionsFromNumericFactor = get("_SparseGetOptionsFromNumericFactor");
        pub const getWorkspaceRequired = get("_SparseGetWorkspaceRequired");
        pub const spmv = get("_SparseSpMV");
        pub const cgSolve = get("_SparseCGSolve");
        pub const gmresSolve = get("_SparseGMRESSolve");
        pub const lsmrSolve = get("_SparseLSMRSolve");
        pub const createPreconditioner = get("_SparseCreatePreconditioner");
        pub const releasePreconditioner = get("_SparseReleaseOpaquePreconditioner");

        /// Hermitian factorization. Complex only - a real Hermitian matrix is
        /// just a symmetric one, and vecLib exports no real spelling.
        pub const factorHermitian = if (types.isComplex(T)) get("_SparseFactorHermitian") else {};
        pub const numericFactorHermitian = if (types.isComplex(T)) get("_SparseNumericFactorHermitian") else {};
        pub const refactorHermitian = if (types.isComplex(T)) get("_SparseRefactorHermitian") else {};

        /// Inertia is defined for the real symmetric case only; vecLib exports
        /// no `_Complex_*` spelling of it.
        pub const getInertia = if (types.isComplex(T)) {} else get("_SparseGetInertia");
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

test "complex ABI struct layouts match the C headers" {
    const expectEqual = std.testing.expectEqual;

    // `SparseMatrixStructureComplex` has the same field offsets as the real
    // one - `attributes` is 4 bytes either way - so this is not a check that
    // they differ, but that widening `kind` inside the bitfield did not change
    // the struct around it.
    try expectEqual(@as(usize, 32), @sizeOf(MatrixStructureComplex));
    try expectEqual(@as(usize, 24), @offsetOf(MatrixStructureComplex, "attributes"));
    try expectEqual(@as(usize, 28), @offsetOf(MatrixStructureComplex, "blockSize"));

    inline for (.{ Complex(f64), Complex(f32) }) |T| {
        try expectEqual(@as(usize, 40), @sizeOf(SparseMatrix(T)));
        try expectEqual(@as(usize, 32), @offsetOf(SparseMatrix(T), "data"));
        try expectEqual(@as(usize, 24), @sizeOf(DenseMatrix(T)));
        try expectEqual(@as(usize, 16), @offsetOf(DenseMatrix(T), "data"));
        // 104 and 128, the same as the real variants: swapping
        // `SparseAttributes_t` for `SparseAttributesComplex_t` changes no
        // offset. Measured with a `sizeof`/`offsetof` dump compiled against
        // Accelerate.h on macOS 15.7 / arm64, not inferred.
        try expectEqual(@as(usize, 104), @sizeOf(OpaqueFactorization(T)));
        try expectEqual(@as(usize, 4), @offsetOf(OpaqueFactorization(T), "attributes"));
        try expectEqual(@as(usize, 8), @offsetOf(OpaqueFactorization(T), "symbolicFactorization"));
        try expectEqual(@as(usize, 128), @sizeOf(OpaqueSubfactor(T)));
        try expectEqual(@as(usize, 24), @sizeOf(OpaquePreconditioner(T)));
    }

    // The element types themselves: `float _Complex` is two contiguous floats
    // with the real part first, and nothing else.
    try expectEqual(@as(usize, 8), @sizeOf(Complex(f32)));
    try expectEqual(@as(usize, 16), @sizeOf(Complex(f64)));
    try expectEqual(@as(usize, 0), @offsetOf(Complex(f64), "real"));
    try expectEqual(@as(usize, 8), @offsetOf(Complex(f64), "imag"));
}

test "the complex/real attribute conversions round-trip through vecLib" {
    // `AttributesComplex` is not `Attributes` with a field bolted on: `kind`
    // is three bits against two, which moves `_allocated_by_sparse`. Rather
    // than reimplement the mapping, the binding calls Apple's converters - so
    // this checks that the two structs are laid out the way those converters
    // expect, which a hand-written `@bitCast` would not survive.
    const expectEqual = std.testing.expectEqual;

    const complex_attrs = AttributesComplex{ .kind = .triangular, .triangle = .lower, .transpose = true };
    const as_real = _SparseFromAttributeComplex(complex_attrs);
    try expectEqual(types.Kind.triangular, as_real.kind);
    try expectEqual(types.Triangle.lower, as_real.triangle);
    try expectEqual(true, as_real.transpose);

    const back = _SparseToAttributeComplex(as_real);
    try expectEqual(types.KindComplex.triangular, back.kind);
    try expectEqual(types.Triangle.lower, back.triangle);
    try expectEqual(true, back.transpose);

    // `.hermitian` has no room in the real `kind`'s two bits. What vecLib
    // does with it is its business; the point here is that the call is what
    // decides, and that it does not corrupt the neighbouring fields.
    const herm = AttributesComplex{ .kind = .hermitian, .triangle = .lower };
    const herm_real = _SparseFromAttributeComplex(herm);
    try expectEqual(types.Triangle.lower, herm_real.triangle);
    try expectEqual(false, herm_real.transpose);
}
