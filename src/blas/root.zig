//! Bindings for Accelerate's CBLAS - dense linear algebra on vectors and
//! matrices.
//!
//! ```zig
//! const blas = @import("accelerate").blas;
//!
//! // C := A * B for 2x2 row-major matrices
//! const a = [_]f64{ 1, 2, 3, 4 };
//! const b = [_]f64{ 5, 6, 7, 8 };
//! var c = [_]f64{ 0, 0, 0, 0 };
//! blas.gemm(f64, .row_major, .no_trans, .no_trans, 2, 2, 2, 1, &a, 2, &b, 2, 0, &c, 2);
//! // c = { 19, 22, 43, 50 }
//! ```
//!
//! Element types are `f32`, `f64`, `Complex(f32)` and `Complex(f64)`, selected
//! by the first (comptime) argument. Routines that exist for only some of them
//! - `dot` is real-only, `hemm` complex-only - are a compile error for the
//! rest rather than a runtime surprise.
//!
//! ## Which CBLAS this is
//!
//! Accelerate ships the routines three times over: a legacy symbol, a current
//! LP64 symbol, and a current ILP64 symbol. `cblas.h` - the plain, unsuffixed
//! one - has been `API_DEPRECATED` since macOS 13.3. This binding uses the
//! **current** interface and picks ILP64 wherever Accelerate offers it, so
//! dimensions are 64-bit on arm64 and x86_64. See `types.zig` for the details
//! and for why that pairing has to be got right.
//!
//! ## Conventions kept from BLAS
//!
//! Parameter order, names and storage layouts are BLAS's, so reference
//! documentation transfers directly. What this layer adds:
//!
//! * Matrices and vectors are slices, and their lengths are checked against
//!   the dimensions, leading dimensions and increments.
//! * `Order`, `Transpose`, `Uplo`, `Diag` and `Side` are enums, not `int`s.
//! * The Hermitian routines that require a **real** scalar (`her`, `hpr`,
//!   `herk`, and `her2k`'s `beta`) take `Scalar(T)`, so passing a complex one
//!   does not compile.
//! * `iamax` returns an optional 0-based index instead of overloading 0 to
//!   mean both "first element" and "empty input".

const std = @import("std");

pub const c = @import("c.zig");
pub const types = @import("types.zig");
pub const level1 = @import("level1.zig");
pub const level2 = @import("level2.zig");
pub const level3 = @import("level3.zig");

// -- Types --
pub const Complex = types.Complex;
pub const Scalar = types.Scalar;
pub const Int = types.Int;
pub const use_ilp64 = types.use_ilp64;
pub const Order = types.Order;
pub const Transpose = types.Transpose;
pub const Uplo = types.Uplo;
pub const Diag = types.Diag;
pub const Side = types.Side;

// -- Level 1: vector-vector --
pub const asum = level1.asum;
pub const asumStrided = level1.asumStrided;
pub const nrm2 = level1.nrm2;
pub const nrm2Strided = level1.nrm2Strided;
pub const iamax = level1.iamax;
pub const iamaxStrided = level1.iamaxStrided;
pub const dot = level1.dot;
pub const dotStrided = level1.dotStrided;
pub const dotu = level1.dotu;
pub const dotuStrided = level1.dotuStrided;
pub const dotc = level1.dotc;
pub const dotcStrided = level1.dotcStrided;
pub const sdsdot = level1.sdsdot;
pub const sdsdotStrided = level1.sdsdotStrided;
pub const dsdot = level1.dsdot;
pub const dsdotStrided = level1.dsdotStrided;
pub const axpy = level1.axpy;
pub const axpyStrided = level1.axpyStrided;
pub const axpby = level1.axpby;
pub const axpbyStrided = level1.axpbyStrided;
pub const copy = level1.copy;
pub const copyStrided = level1.copyStrided;
pub const swap = level1.swap;
pub const swapStrided = level1.swapStrided;
pub const scal = level1.scal;
pub const scalStrided = level1.scalStrided;
pub const scalReal = level1.scalReal;
pub const scalRealStrided = level1.scalRealStrided;
pub const set = level1.set;
pub const setStrided = level1.setStrided;
pub const rot = level1.rot;
pub const rotStrided = level1.rotStrided;
pub const rotg = level1.rotg;
pub const rotgComplex = level1.rotgComplex;
pub const rotComplex = level1.rotComplex;
pub const rotComplexStrided = level1.rotComplexStrided;
pub const rotm = level1.rotm;
pub const rotmStrided = level1.rotmStrided;
pub const rotmg = level1.rotmg;

// -- Level 2: matrix-vector --
pub const gemv = level2.gemv;
pub const gbmv = level2.gbmv;
pub const ger = level2.ger;
pub const geru = level2.geru;
pub const gerc = level2.gerc;
pub const hemv = level2.hemv;
pub const symv = level2.symv;
pub const hbmv = level2.hbmv;
pub const sbmv = level2.sbmv;
pub const hpmv = level2.hpmv;
pub const spmv = level2.spmv;
pub const her = level2.her;
pub const syr = level2.syr;
pub const her2 = level2.her2;
pub const syr2 = level2.syr2;
pub const hpr = level2.hpr;
pub const spr = level2.spr;
pub const hpr2 = level2.hpr2;
pub const spr2 = level2.spr2;
pub const trmv = level2.trmv;
pub const trsv = level2.trsv;
pub const tbmv = level2.tbmv;
pub const tbsv = level2.tbsv;
pub const tpmv = level2.tpmv;
pub const tpsv = level2.tpsv;

// -- Level 3: matrix-matrix --
pub const gemm = level3.gemm;
pub const symm = level3.symm;
pub const hemm = level3.hemm;
pub const syrk = level3.syrk;
pub const herk = level3.herk;
pub const syr2k = level3.syr2k;
pub const her2k = level3.her2k;
pub const trmm = level3.trmm;
pub const trsm = level3.trsm;
pub const geadd = level3.geadd;

test {
    std.testing.refAllDecls(@This());
}
