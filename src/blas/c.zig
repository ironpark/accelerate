//! CBLAS extern declarations, generated from `vecLib/cblas_new.h`.
//!
//! Every symbol here carries the `$NEWLAPACK[$ILP64]` suffix that
//! `__LAPACK_ALIAS` applies in the header - see `types.zig` for why the plain
//! `cblas_*` names are the wrong ones to bind.
//!
//! Pointer nullability follows the header: `_Nullable` array arguments become
//! `?[*]`, and `_Nonnull` scalar arguments (complex `ALPHA`/`BETA`, the
//! `_sub` dot outputs, the Givens parameters) become single-item pointers.
//! Callers should use the checked wrappers in `level1.zig`, `level2.zig` and
//! `level3.zig` rather than these.

const types = @import("types.zig");

const Int = types.Int;
const Order = types.Order;
const Transpose = types.Transpose;
const Uplo = types.Uplo;
const Diag = types.Diag;
const Side = types.Side;
const Complex = types.Complex;

pub const appleblas_sgeadd = @extern(*const fn (Order, Transpose, Transpose, Int, Int, f32, ?[*]const f32, Int, f32, ?[*]const f32, Int, [*]f32, Int) callconv(.c) void, .{ .name = "appleblas_sgeadd" ++ types.alias_suffix });
pub const appleblas_dgeadd = @extern(*const fn (Order, Transpose, Transpose, Int, Int, f64, ?[*]const f64, Int, f64, ?[*]const f64, Int, [*]f64, Int) callconv(.c) void, .{ .name = "appleblas_dgeadd" ++ types.alias_suffix });
pub const cblas_isamax = @extern(*const fn (Int, ?[*]const f32, Int) callconv(.c) Int, .{ .name = "cblas_isamax" ++ types.alias_suffix });
pub const cblas_idamax = @extern(*const fn (Int, ?[*]const f64, Int) callconv(.c) Int, .{ .name = "cblas_idamax" ++ types.alias_suffix });
pub const cblas_icamax = @extern(*const fn (Int, ?[*]const Complex(f32), Int) callconv(.c) Int, .{ .name = "cblas_icamax" ++ types.alias_suffix });
pub const cblas_izamax = @extern(*const fn (Int, ?[*]const Complex(f64), Int) callconv(.c) Int, .{ .name = "cblas_izamax" ++ types.alias_suffix });
pub const cblas_sasum = @extern(*const fn (Int, ?[*]const f32, Int) callconv(.c) f32, .{ .name = "cblas_sasum" ++ types.alias_suffix });
pub const cblas_dasum = @extern(*const fn (Int, ?[*]const f64, Int) callconv(.c) f64, .{ .name = "cblas_dasum" ++ types.alias_suffix });
pub const cblas_scasum = @extern(*const fn (Int, ?[*]const Complex(f32), Int) callconv(.c) f32, .{ .name = "cblas_scasum" ++ types.alias_suffix });
pub const cblas_dzasum = @extern(*const fn (Int, ?[*]const Complex(f64), Int) callconv(.c) f64, .{ .name = "cblas_dzasum" ++ types.alias_suffix });
pub const cblas_saxpy = @extern(*const fn (Int, f32, ?[*]const f32, Int, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_saxpy" ++ types.alias_suffix });
pub const cblas_daxpy = @extern(*const fn (Int, f64, ?[*]const f64, Int, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_daxpy" ++ types.alias_suffix });
pub const cblas_caxpy = @extern(*const fn (Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_caxpy" ++ types.alias_suffix });
pub const cblas_zaxpy = @extern(*const fn (Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zaxpy" ++ types.alias_suffix });
pub const catlas_saxpby = @extern(*const fn (Int, f32, ?[*]const f32, Int, f32, ?[*]f32, Int) callconv(.c) void, .{ .name = "catlas_saxpby" ++ types.alias_suffix });
pub const catlas_daxpby = @extern(*const fn (Int, f64, ?[*]const f64, Int, f64, ?[*]f64, Int) callconv(.c) void, .{ .name = "catlas_daxpby" ++ types.alias_suffix });
pub const catlas_caxpby = @extern(*const fn (Int, *const Complex(f32), ?[*]const Complex(f32), Int, *const Complex(f32), ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "catlas_caxpby" ++ types.alias_suffix });
pub const catlas_zaxpby = @extern(*const fn (Int, *const Complex(f64), ?[*]const Complex(f64), Int, *const Complex(f64), ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "catlas_zaxpby" ++ types.alias_suffix });
pub const cblas_scopy = @extern(*const fn (Int, ?[*]const f32, Int, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_scopy" ++ types.alias_suffix });
pub const cblas_dcopy = @extern(*const fn (Int, ?[*]const f64, Int, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dcopy" ++ types.alias_suffix });
pub const cblas_ccopy = @extern(*const fn (Int, ?[*]const Complex(f32), Int, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_ccopy" ++ types.alias_suffix });
pub const cblas_zcopy = @extern(*const fn (Int, ?[*]const Complex(f64), Int, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zcopy" ++ types.alias_suffix });
pub const cblas_sdot = @extern(*const fn (Int, ?[*]const f32, Int, ?[*]const f32, Int) callconv(.c) f32, .{ .name = "cblas_sdot" ++ types.alias_suffix });
pub const cblas_ddot = @extern(*const fn (Int, ?[*]const f64, Int, ?[*]const f64, Int) callconv(.c) f64, .{ .name = "cblas_ddot" ++ types.alias_suffix });
pub const cblas_cdotu_sub = @extern(*const fn (Int, ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, *Complex(f32)) callconv(.c) void, .{ .name = "cblas_cdotu_sub" ++ types.alias_suffix });
pub const cblas_zdotu_sub = @extern(*const fn (Int, ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, *Complex(f64)) callconv(.c) void, .{ .name = "cblas_zdotu_sub" ++ types.alias_suffix });
pub const cblas_cdotc_sub = @extern(*const fn (Int, ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, *Complex(f32)) callconv(.c) void, .{ .name = "cblas_cdotc_sub" ++ types.alias_suffix });
pub const cblas_zdotc_sub = @extern(*const fn (Int, ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, *Complex(f64)) callconv(.c) void, .{ .name = "cblas_zdotc_sub" ++ types.alias_suffix });
pub const cblas_sdsdot = @extern(*const fn (Int, f32, ?[*]const f32, Int, ?[*]const f32, Int) callconv(.c) f32, .{ .name = "cblas_sdsdot" ++ types.alias_suffix });
pub const cblas_dsdot = @extern(*const fn (Int, ?[*]const f32, Int, ?[*]const f32, Int) callconv(.c) f64, .{ .name = "cblas_dsdot" ++ types.alias_suffix });
pub const cblas_snrm2 = @extern(*const fn (Int, ?[*]const f32, Int) callconv(.c) f32, .{ .name = "cblas_snrm2" ++ types.alias_suffix });
pub const cblas_dnrm2 = @extern(*const fn (Int, ?[*]const f64, Int) callconv(.c) f64, .{ .name = "cblas_dnrm2" ++ types.alias_suffix });
pub const cblas_scnrm2 = @extern(*const fn (Int, ?[*]const Complex(f32), Int) callconv(.c) f32, .{ .name = "cblas_scnrm2" ++ types.alias_suffix });
pub const cblas_dznrm2 = @extern(*const fn (Int, ?[*]const Complex(f64), Int) callconv(.c) f64, .{ .name = "cblas_dznrm2" ++ types.alias_suffix });
pub const cblas_srot = @extern(*const fn (Int, ?[*]f32, Int, ?[*]f32, Int, f32, f32) callconv(.c) void, .{ .name = "cblas_srot" ++ types.alias_suffix });
pub const cblas_drot = @extern(*const fn (Int, ?[*]f64, Int, ?[*]f64, Int, f64, f64) callconv(.c) void, .{ .name = "cblas_drot" ++ types.alias_suffix });
pub const cblas_csrot = @extern(*const fn (Int, ?[*]Complex(f32), Int, ?[*]Complex(f32), Int, f32, f32) callconv(.c) void, .{ .name = "cblas_csrot" ++ types.alias_suffix });
pub const cblas_zdrot = @extern(*const fn (Int, ?[*]Complex(f64), Int, ?[*]Complex(f64), Int, f64, f64) callconv(.c) void, .{ .name = "cblas_zdrot" ++ types.alias_suffix });
pub const cblas_srotg = @extern(*const fn (*f32, *f32, *f32, *f32) callconv(.c) void, .{ .name = "cblas_srotg" ++ types.alias_suffix });
pub const cblas_drotg = @extern(*const fn (*f64, *f64, *f64, *f64) callconv(.c) void, .{ .name = "cblas_drotg" ++ types.alias_suffix });
pub const cblas_crotg = @extern(*const fn (*Complex(f32), *Complex(f32), *f32, *Complex(f32)) callconv(.c) void, .{ .name = "cblas_crotg" ++ types.alias_suffix });
pub const cblas_zrotg = @extern(*const fn (*Complex(f64), *Complex(f64), *f64, *Complex(f64)) callconv(.c) void, .{ .name = "cblas_zrotg" ++ types.alias_suffix });
pub const cblas_srotm = @extern(*const fn (Int, ?[*]f32, Int, ?[*]f32, Int, [*]const f32) callconv(.c) void, .{ .name = "cblas_srotm" ++ types.alias_suffix });
pub const cblas_drotm = @extern(*const fn (Int, ?[*]f64, Int, ?[*]f64, Int, [*]const f64) callconv(.c) void, .{ .name = "cblas_drotm" ++ types.alias_suffix });
pub const cblas_srotmg = @extern(*const fn (*f32, *f32, *f32, f32, [*]f32) callconv(.c) void, .{ .name = "cblas_srotmg" ++ types.alias_suffix });
pub const cblas_drotmg = @extern(*const fn (*f64, *f64, *f64, f64, [*]f64) callconv(.c) void, .{ .name = "cblas_drotmg" ++ types.alias_suffix });
pub const cblas_sscal = @extern(*const fn (Int, f32, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_sscal" ++ types.alias_suffix });
pub const cblas_dscal = @extern(*const fn (Int, f64, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dscal" ++ types.alias_suffix });
pub const cblas_cscal = @extern(*const fn (Int, *const Complex(f32), ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_cscal" ++ types.alias_suffix });
pub const cblas_zscal = @extern(*const fn (Int, *const Complex(f64), ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zscal" ++ types.alias_suffix });
pub const cblas_csscal = @extern(*const fn (Int, f32, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_csscal" ++ types.alias_suffix });
pub const cblas_zdscal = @extern(*const fn (Int, f64, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zdscal" ++ types.alias_suffix });
pub const catlas_sset = @extern(*const fn (Int, f32, [*]f32, Int) callconv(.c) void, .{ .name = "catlas_sset" ++ types.alias_suffix });
pub const catlas_dset = @extern(*const fn (Int, f64, [*]f64, Int) callconv(.c) void, .{ .name = "catlas_dset" ++ types.alias_suffix });
pub const catlas_cset = @extern(*const fn (Int, *const Complex(f32), [*]Complex(f32), Int) callconv(.c) void, .{ .name = "catlas_cset" ++ types.alias_suffix });
pub const catlas_zset = @extern(*const fn (Int, *const Complex(f64), [*]Complex(f64), Int) callconv(.c) void, .{ .name = "catlas_zset" ++ types.alias_suffix });
pub const cblas_sswap = @extern(*const fn (Int, ?[*]f32, Int, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_sswap" ++ types.alias_suffix });
pub const cblas_dswap = @extern(*const fn (Int, ?[*]f64, Int, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dswap" ++ types.alias_suffix });
pub const cblas_cswap = @extern(*const fn (Int, ?[*]Complex(f32), Int, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_cswap" ++ types.alias_suffix });
pub const cblas_zswap = @extern(*const fn (Int, ?[*]Complex(f64), Int, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zswap" ++ types.alias_suffix });
pub const cblas_sgemv = @extern(*const fn (Order, Transpose, Int, Int, f32, ?[*]const f32, Int, ?[*]const f32, Int, f32, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_sgemv" ++ types.alias_suffix });
pub const cblas_dgemv = @extern(*const fn (Order, Transpose, Int, Int, f64, ?[*]const f64, Int, ?[*]const f64, Int, f64, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dgemv" ++ types.alias_suffix });
pub const cblas_cgemv = @extern(*const fn (Order, Transpose, Int, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, *const Complex(f32), ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_cgemv" ++ types.alias_suffix });
pub const cblas_zgemv = @extern(*const fn (Order, Transpose, Int, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, *const Complex(f64), ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zgemv" ++ types.alias_suffix });
pub const cblas_sgbmv = @extern(*const fn (Order, Transpose, Int, Int, Int, Int, f32, ?[*]const f32, Int, ?[*]const f32, Int, f32, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_sgbmv" ++ types.alias_suffix });
pub const cblas_dgbmv = @extern(*const fn (Order, Transpose, Int, Int, Int, Int, f64, ?[*]const f64, Int, ?[*]const f64, Int, f64, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dgbmv" ++ types.alias_suffix });
pub const cblas_cgbmv = @extern(*const fn (Order, Transpose, Int, Int, Int, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, *const Complex(f32), ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_cgbmv" ++ types.alias_suffix });
pub const cblas_zgbmv = @extern(*const fn (Order, Transpose, Int, Int, Int, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, *const Complex(f64), ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zgbmv" ++ types.alias_suffix });
pub const cblas_sger = @extern(*const fn (Order, Int, Int, f32, ?[*]const f32, Int, ?[*]const f32, Int, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_sger" ++ types.alias_suffix });
pub const cblas_dger = @extern(*const fn (Order, Int, Int, f64, ?[*]const f64, Int, ?[*]const f64, Int, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dger" ++ types.alias_suffix });
pub const cblas_cgerc = @extern(*const fn (Order, Int, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_cgerc" ++ types.alias_suffix });
pub const cblas_zgerc = @extern(*const fn (Order, Int, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zgerc" ++ types.alias_suffix });
pub const cblas_cgeru = @extern(*const fn (Order, Int, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_cgeru" ++ types.alias_suffix });
pub const cblas_zgeru = @extern(*const fn (Order, Int, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zgeru" ++ types.alias_suffix });
pub const cblas_chbmv = @extern(*const fn (Order, Uplo, Int, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, *const Complex(f32), ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_chbmv" ++ types.alias_suffix });
pub const cblas_zhbmv = @extern(*const fn (Order, Uplo, Int, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, *const Complex(f64), ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zhbmv" ++ types.alias_suffix });
pub const cblas_chemv = @extern(*const fn (Order, Uplo, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, *const Complex(f32), ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_chemv" ++ types.alias_suffix });
pub const cblas_zhemv = @extern(*const fn (Order, Uplo, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, *const Complex(f64), ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zhemv" ++ types.alias_suffix });
pub const cblas_cher = @extern(*const fn (Order, Uplo, Int, f32, ?[*]const Complex(f32), Int, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_cher" ++ types.alias_suffix });
pub const cblas_zher = @extern(*const fn (Order, Uplo, Int, f64, ?[*]const Complex(f64), Int, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zher" ++ types.alias_suffix });
pub const cblas_cher2 = @extern(*const fn (Order, Uplo, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_cher2" ++ types.alias_suffix });
pub const cblas_zher2 = @extern(*const fn (Order, Uplo, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zher2" ++ types.alias_suffix });
pub const cblas_chpmv = @extern(*const fn (Order, Uplo, Int, *const Complex(f32), ?[*]const Complex(f32), ?[*]const Complex(f32), Int, *const Complex(f32), ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_chpmv" ++ types.alias_suffix });
pub const cblas_zhpmv = @extern(*const fn (Order, Uplo, Int, *const Complex(f64), ?[*]const Complex(f64), ?[*]const Complex(f64), Int, *const Complex(f64), ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zhpmv" ++ types.alias_suffix });
pub const cblas_chpr = @extern(*const fn (Order, Uplo, Int, f32, ?[*]const Complex(f32), Int, ?[*]Complex(f32)) callconv(.c) void, .{ .name = "cblas_chpr" ++ types.alias_suffix });
pub const cblas_zhpr = @extern(*const fn (Order, Uplo, Int, f64, ?[*]const Complex(f64), Int, ?[*]Complex(f64)) callconv(.c) void, .{ .name = "cblas_zhpr" ++ types.alias_suffix });
pub const cblas_chpr2 = @extern(*const fn (Order, Uplo, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, ?[*]Complex(f32)) callconv(.c) void, .{ .name = "cblas_chpr2" ++ types.alias_suffix });
pub const cblas_zhpr2 = @extern(*const fn (Order, Uplo, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, ?[*]Complex(f64)) callconv(.c) void, .{ .name = "cblas_zhpr2" ++ types.alias_suffix });
pub const cblas_ssbmv = @extern(*const fn (Order, Uplo, Int, Int, f32, ?[*]const f32, Int, ?[*]const f32, Int, f32, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_ssbmv" ++ types.alias_suffix });
pub const cblas_dsbmv = @extern(*const fn (Order, Uplo, Int, Int, f64, ?[*]const f64, Int, ?[*]const f64, Int, f64, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dsbmv" ++ types.alias_suffix });
pub const cblas_sspmv = @extern(*const fn (Order, Uplo, Int, f32, ?[*]const f32, ?[*]const f32, Int, f32, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_sspmv" ++ types.alias_suffix });
pub const cblas_dspmv = @extern(*const fn (Order, Uplo, Int, f64, ?[*]const f64, ?[*]const f64, Int, f64, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dspmv" ++ types.alias_suffix });
pub const cblas_sspr = @extern(*const fn (Order, Uplo, Int, f32, ?[*]const f32, Int, ?[*]f32) callconv(.c) void, .{ .name = "cblas_sspr" ++ types.alias_suffix });
pub const cblas_dspr = @extern(*const fn (Order, Uplo, Int, f64, ?[*]const f64, Int, ?[*]f64) callconv(.c) void, .{ .name = "cblas_dspr" ++ types.alias_suffix });
pub const cblas_sspr2 = @extern(*const fn (Order, Uplo, Int, f32, ?[*]const f32, Int, ?[*]const f32, Int, ?[*]f32) callconv(.c) void, .{ .name = "cblas_sspr2" ++ types.alias_suffix });
pub const cblas_dspr2 = @extern(*const fn (Order, Uplo, Int, f64, ?[*]const f64, Int, ?[*]const f64, Int, ?[*]f64) callconv(.c) void, .{ .name = "cblas_dspr2" ++ types.alias_suffix });
pub const cblas_ssymv = @extern(*const fn (Order, Uplo, Int, f32, ?[*]const f32, Int, ?[*]const f32, Int, f32, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_ssymv" ++ types.alias_suffix });
pub const cblas_dsymv = @extern(*const fn (Order, Uplo, Int, f64, ?[*]const f64, Int, ?[*]const f64, Int, f64, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dsymv" ++ types.alias_suffix });
pub const cblas_ssyr = @extern(*const fn (Order, Uplo, Int, f32, ?[*]const f32, Int, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_ssyr" ++ types.alias_suffix });
pub const cblas_dsyr = @extern(*const fn (Order, Uplo, Int, f64, ?[*]const f64, Int, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dsyr" ++ types.alias_suffix });
pub const cblas_ssyr2 = @extern(*const fn (Order, Uplo, Int, f32, ?[*]const f32, Int, ?[*]const f32, Int, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_ssyr2" ++ types.alias_suffix });
pub const cblas_dsyr2 = @extern(*const fn (Order, Uplo, Int, f64, ?[*]const f64, Int, ?[*]const f64, Int, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dsyr2" ++ types.alias_suffix });
pub const cblas_stbmv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, Int, ?[*]const f32, Int, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_stbmv" ++ types.alias_suffix });
pub const cblas_dtbmv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, Int, ?[*]const f64, Int, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dtbmv" ++ types.alias_suffix });
pub const cblas_ctbmv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, Int, ?[*]const Complex(f32), Int, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_ctbmv" ++ types.alias_suffix });
pub const cblas_ztbmv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, Int, ?[*]const Complex(f64), Int, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_ztbmv" ++ types.alias_suffix });
pub const cblas_stbsv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, Int, ?[*]const f32, Int, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_stbsv" ++ types.alias_suffix });
pub const cblas_dtbsv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, Int, ?[*]const f64, Int, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dtbsv" ++ types.alias_suffix });
pub const cblas_ctbsv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, Int, ?[*]const Complex(f32), Int, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_ctbsv" ++ types.alias_suffix });
pub const cblas_ztbsv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, Int, ?[*]const Complex(f64), Int, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_ztbsv" ++ types.alias_suffix });
pub const cblas_stpmv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const f32, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_stpmv" ++ types.alias_suffix });
pub const cblas_dtpmv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const f64, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dtpmv" ++ types.alias_suffix });
pub const cblas_ctpmv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const Complex(f32), ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_ctpmv" ++ types.alias_suffix });
pub const cblas_ztpmv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const Complex(f64), ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_ztpmv" ++ types.alias_suffix });
pub const cblas_stpsv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const f32, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_stpsv" ++ types.alias_suffix });
pub const cblas_dtpsv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const f64, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dtpsv" ++ types.alias_suffix });
pub const cblas_ctpsv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const Complex(f32), ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_ctpsv" ++ types.alias_suffix });
pub const cblas_ztpsv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const Complex(f64), ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_ztpsv" ++ types.alias_suffix });
pub const cblas_strmv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const f32, Int, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_strmv" ++ types.alias_suffix });
pub const cblas_dtrmv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const f64, Int, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dtrmv" ++ types.alias_suffix });
pub const cblas_ctrmv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const Complex(f32), Int, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_ctrmv" ++ types.alias_suffix });
pub const cblas_ztrmv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const Complex(f64), Int, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_ztrmv" ++ types.alias_suffix });
pub const cblas_strsv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const f32, Int, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_strsv" ++ types.alias_suffix });
pub const cblas_dtrsv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const f64, Int, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dtrsv" ++ types.alias_suffix });
pub const cblas_ctrsv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const Complex(f32), Int, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_ctrsv" ++ types.alias_suffix });
pub const cblas_ztrsv = @extern(*const fn (Order, Uplo, Transpose, Diag, Int, ?[*]const Complex(f64), Int, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_ztrsv" ++ types.alias_suffix });
pub const cblas_sgemm = @extern(*const fn (Order, Transpose, Transpose, Int, Int, Int, f32, ?[*]const f32, Int, ?[*]const f32, Int, f32, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_sgemm" ++ types.alias_suffix });
pub const cblas_dgemm = @extern(*const fn (Order, Transpose, Transpose, Int, Int, Int, f64, ?[*]const f64, Int, ?[*]const f64, Int, f64, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dgemm" ++ types.alias_suffix });
pub const cblas_cgemm = @extern(*const fn (Order, Transpose, Transpose, Int, Int, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, *const Complex(f32), ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_cgemm" ++ types.alias_suffix });
pub const cblas_zgemm = @extern(*const fn (Order, Transpose, Transpose, Int, Int, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, *const Complex(f64), ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zgemm" ++ types.alias_suffix });
pub const cblas_chemm = @extern(*const fn (Order, Side, Uplo, Int, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, *const Complex(f32), ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_chemm" ++ types.alias_suffix });
pub const cblas_zhemm = @extern(*const fn (Order, Side, Uplo, Int, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, *const Complex(f64), ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zhemm" ++ types.alias_suffix });
pub const cblas_cherk = @extern(*const fn (Order, Uplo, Transpose, Int, Int, f32, ?[*]const Complex(f32), Int, f32, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_cherk" ++ types.alias_suffix });
pub const cblas_zherk = @extern(*const fn (Order, Uplo, Transpose, Int, Int, f64, ?[*]const Complex(f64), Int, f64, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zherk" ++ types.alias_suffix });
pub const cblas_cher2k = @extern(*const fn (Order, Uplo, Transpose, Int, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, f32, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_cher2k" ++ types.alias_suffix });
pub const cblas_zher2k = @extern(*const fn (Order, Uplo, Transpose, Int, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, f64, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zher2k" ++ types.alias_suffix });
pub const cblas_ssymm = @extern(*const fn (Order, Side, Uplo, Int, Int, f32, ?[*]const f32, Int, ?[*]const f32, Int, f32, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_ssymm" ++ types.alias_suffix });
pub const cblas_dsymm = @extern(*const fn (Order, Side, Uplo, Int, Int, f64, ?[*]const f64, Int, ?[*]const f64, Int, f64, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dsymm" ++ types.alias_suffix });
pub const cblas_csymm = @extern(*const fn (Order, Side, Uplo, Int, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, *const Complex(f32), ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_csymm" ++ types.alias_suffix });
pub const cblas_zsymm = @extern(*const fn (Order, Side, Uplo, Int, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, *const Complex(f64), ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zsymm" ++ types.alias_suffix });
pub const cblas_ssyrk = @extern(*const fn (Order, Uplo, Transpose, Int, Int, f32, ?[*]const f32, Int, f32, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_ssyrk" ++ types.alias_suffix });
pub const cblas_dsyrk = @extern(*const fn (Order, Uplo, Transpose, Int, Int, f64, ?[*]const f64, Int, f64, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dsyrk" ++ types.alias_suffix });
pub const cblas_csyrk = @extern(*const fn (Order, Uplo, Transpose, Int, Int, *const Complex(f32), ?[*]const Complex(f32), Int, *const Complex(f32), ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_csyrk" ++ types.alias_suffix });
pub const cblas_zsyrk = @extern(*const fn (Order, Uplo, Transpose, Int, Int, *const Complex(f64), ?[*]const Complex(f64), Int, *const Complex(f64), ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zsyrk" ++ types.alias_suffix });
pub const cblas_ssyr2k = @extern(*const fn (Order, Uplo, Transpose, Int, Int, f32, ?[*]const f32, Int, ?[*]const f32, Int, f32, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_ssyr2k" ++ types.alias_suffix });
pub const cblas_dsyr2k = @extern(*const fn (Order, Uplo, Transpose, Int, Int, f64, ?[*]const f64, Int, ?[*]const f64, Int, f64, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dsyr2k" ++ types.alias_suffix });
pub const cblas_csyr2k = @extern(*const fn (Order, Uplo, Transpose, Int, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]const Complex(f32), Int, *const Complex(f32), ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_csyr2k" ++ types.alias_suffix });
pub const cblas_zsyr2k = @extern(*const fn (Order, Uplo, Transpose, Int, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]const Complex(f64), Int, *const Complex(f64), ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_zsyr2k" ++ types.alias_suffix });
pub const cblas_strmm = @extern(*const fn (Order, Side, Uplo, Transpose, Diag, Int, Int, f32, ?[*]const f32, Int, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_strmm" ++ types.alias_suffix });
pub const cblas_dtrmm = @extern(*const fn (Order, Side, Uplo, Transpose, Diag, Int, Int, f64, ?[*]const f64, Int, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dtrmm" ++ types.alias_suffix });
pub const cblas_ctrmm = @extern(*const fn (Order, Side, Uplo, Transpose, Diag, Int, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_ctrmm" ++ types.alias_suffix });
pub const cblas_ztrmm = @extern(*const fn (Order, Side, Uplo, Transpose, Diag, Int, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_ztrmm" ++ types.alias_suffix });
pub const cblas_strsm = @extern(*const fn (Order, Side, Uplo, Transpose, Diag, Int, Int, f32, ?[*]const f32, Int, ?[*]f32, Int) callconv(.c) void, .{ .name = "cblas_strsm" ++ types.alias_suffix });
pub const cblas_dtrsm = @extern(*const fn (Order, Side, Uplo, Transpose, Diag, Int, Int, f64, ?[*]const f64, Int, ?[*]f64, Int) callconv(.c) void, .{ .name = "cblas_dtrsm" ++ types.alias_suffix });
pub const cblas_ctrsm = @extern(*const fn (Order, Side, Uplo, Transpose, Diag, Int, Int, *const Complex(f32), ?[*]const Complex(f32), Int, ?[*]Complex(f32), Int) callconv(.c) void, .{ .name = "cblas_ctrsm" ++ types.alias_suffix });
pub const cblas_ztrsm = @extern(*const fn (Order, Side, Uplo, Transpose, Diag, Int, Int, *const Complex(f64), ?[*]const Complex(f64), Int, ?[*]Complex(f64), Int) callconv(.c) void, .{ .name = "cblas_ztrsm" ++ types.alias_suffix });

// -- Threading control (`vecLib/thread_api.h`) --
//
// These two are not part of CBLAS and carry no `$NEWLAPACK` suffix: they are
// plain C symbols in vecLib, and the `.tbd` exports them as `_BLASSetThreading`
// / `_BLASGetThreading`. They govern BLAS *and* LAPACK, and the setting is
// per-thread. macOS 15.0 / iOS 18.0 and later.
pub const BLASSetThreading = @extern(*const fn (c_uint) callconv(.c) c_int, .{ .name = "BLASSetThreading" });
pub const BLASGetThreading = @extern(*const fn () callconv(.c) c_uint, .{ .name = "BLASGetThreading" });

// Zig resolves container declarations lazily, so an `@extern` nobody
// references is never checked and a misspelled symbol would link fine right up
// until the first caller. Referencing every one of them here forces resolution
// and turns a wrong name - or a `$NEWLAPACK[$ILP64]` suffix that a future SDK
// stops exporting - into a link error the suite catches.
test "every declared symbol resolves and links" {
    const std = @import("std");
    var sink: usize = 0;
    inline for (@typeInfo(@This()).@"struct".decls) |decl| {
        const field = @field(@This(), decl.name);
        if (@typeInfo(@TypeOf(field)) == .pointer) {
            sink +%= @intFromPtr(field);
        }
    }
    try std.testing.expect(sink != 0);
}
