//! Bindings for Apple's Sparse Solvers (`Accelerate/Sparse/Solve.h`).
//!
//! Solves `A x = b` for a sparse `A` and dense `x`, `b`, by direct
//! factorization:
//!
//! ```zig
//! const sparse = @import("accelerate").sparse;
//!
//! // Lower triangle of a symmetric positive-definite matrix, in CSC.
//! const starts = [_]c_long{ 0, 2, 4, 6, 7 };
//! const rows   = [_]c_int{ 0, 1, 1, 2, 2, 3, 3 };
//! const vals   = [_]f64{ 2, 1, 3, 1, 4, 1, 5 };
//! const a = sparse.Sparse(f64).init(4, 4, &starts, &rows, &vals, .{
//!     .attributes = .{ .kind = .symmetric, .triangle = .lower },
//! });
//!
//! var f = try sparse.Factorization(f64).init(.cholesky, a, .{});
//! defer f.deinit();
//!
//! var b = [_]f64{ 4, 10, 18, 23 };
//! var x = [_]f64{ 0, 0, 0, 0 };
//! try f.solve(allocator, &b, &x);   // x == { 1, 2, 3, 4 }
//! ```
//!
//! Supports `f32` and `f64`.
//!
//! ## Scope
//!
//! * **Direct methods** - Cholesky, `LDL^T` (four pivoting modes), QR, with
//!   refactorization and inertia.
//! * **Subfactors** - `L`, `D`, `P`, `S`, `Q`, `R` extracted and applied
//!   individually.
//! * **Iterative methods** - conjugate gradient, GMRES and LSMR, over either a
//!   stored matrix or a caller-supplied matrix-free operator, with built-in or
//!   user preconditioners.
//! * Sparse-times-dense multiplication and coordinate-to-block-CSC conversion.
//!
//! Not bound: the manual `SparseIterate` stepping interface, and the
//! deprecated opaque API in `Sparse/BLAS.h`.
//!
//! ## Two things worth knowing before you start
//!
//! * **Errors are `SparseError`, not process death.** Left to itself, Sparse
//!   reacts to a bad argument by calling `__builtin_trap()`. This binding
//!   validates first and installs a `reportError` callback, so mistakes come
//!   back as errors. `lastErrorMessage()` carries Sparse's own text.
//! * **The solve workspace is yours.** Apple's `SparseSolve` mallocs and frees
//!   scratch space on every call. Here `solve` takes a `std.mem.Allocator`, and
//!   `solveWithWorkspace` takes a buffer you can allocate once outside a loop.
//!   The factorization itself is still allocated by Sparse through libc - see
//!   `factor.zig` for why.

pub const c = @import("c.zig");
pub const types = @import("types.zig");
pub const matrix = @import("matrix.zig");
pub const factor = @import("factor.zig");
pub const subfactor = @import("subfactor.zig");
pub const iterative = @import("iterative.zig");
pub const block = @import("block.zig");

// -- Matrix types --
pub const Sparse = matrix.Sparse;
pub const Dense = matrix.Dense;

// -- Factorization --
pub const Factorization = factor.Factorization;
pub const Inertia = factor.Inertia;
pub const Subfactor = subfactor.Subfactor;

// -- Iterative --
pub const Iterative = iterative.Iterative;
pub const CGOptions = iterative.CGOptions;
pub const GMRESOptions = iterative.GMRESOptions;
pub const LSMROptions = iterative.LSMROptions;
pub const IterativeStatus = iterative.IterativeStatus;
pub const GMRESVariant = iterative.GMRESVariant;
pub const LSMRConvergenceTest = iterative.LSMRConvergenceTest;
pub const PreconditionerType = iterative.PreconditionerType;
pub const Transpose = iterative.Transpose;

// -- Enumerations --
pub const Attributes = types.Attributes;
pub const Kind = types.Kind;
pub const Triangle = types.Triangle;
pub const FactorizationType = types.FactorizationType;
pub const Order = types.Order;
pub const Scaling = types.Scaling;
pub const SubfactorKind = types.Subfactor;

// -- Errors --
pub const SparseError = types.SparseError;
pub const Status = types.Status;
pub const check = types.check;
pub const lastErrorMessage = types.lastErrorMessage;

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
