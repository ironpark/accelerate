const std = @import("std");
const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;
const SplitComplex = types.SplitComplex;
const DoubleSplitComplex = types.DoubleSplitComplex;

const c = struct {
    // -- Vector fill (from vDSP_vecop.h) --
    extern fn vDSP_vfill(A: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vfillD(A: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vfilli(A: *const c_int, C: [*]c_int, IC: Stride, N: Length) void;
    // -- Vector add --
    extern fn vDSP_vadd(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vaddD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vaddi(A: [*]const i32, IA: Stride, B: [*]const i32, IB: Stride, C: [*]i32, IC: Stride, N: Length) void;
    extern fn vDSP_zvadd(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zvaddD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zrvadd(A: *const SplitComplex, IA: Stride, B: [*]const f32, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zrvaddD(A: *const DoubleSplitComplex, IA: Stride, B: [*]const f64, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
    // -- Vector subtract --
    extern fn vDSP_vsub(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vsubD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_zvsub(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zvsubD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zrvsub(A: *const SplitComplex, IA: Stride, B: [*]const f32, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zrvsubD(A: *const DoubleSplitComplex, IA: Stride, B: [*]const f64, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
    // -- Vector multiply --
    extern fn vDSP_vmul(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vmulD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_zrvmul(A: *const SplitComplex, IA: Stride, B: [*]const f32, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zrvmulD(A: *const DoubleSplitComplex, IA: Stride, B: [*]const f64, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
    // -- Vector divide --
    extern fn vDSP_vdiv(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vdivD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vdivi(B: [*]const i32, IB: Stride, A: [*]const i32, IA: Stride, C: [*]i32, IC: Stride, N: Length) void;
    extern fn vDSP_zvdiv(B: *const SplitComplex, IB: Stride, A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zvdivD(B: *const DoubleSplitComplex, IB: Stride, A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zrvdiv(A: *const SplitComplex, IA: Stride, B: [*]const f32, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zrvdivD(A: *const DoubleSplitComplex, IA: Stride, B: [*]const f64, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
    // -- Scalar-vector ops --
    extern fn vDSP_vsmul(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vsmulD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vsadd(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vsaddD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vsaddi(A: [*]const i32, IA: Stride, B: *const i32, C: [*]i32, IC: Stride, N: Length) void;
    extern fn vDSP_vsdiv(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vsdivD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vsdivi(A: [*]const i32, IA: Stride, B: *const i32, C: [*]i32, IC: Stride, N: Length) void;
    extern fn vDSP_svdiv(A: *const f32, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_svdivD(A: *const f64, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    // -- Multiply-add variants --
    extern fn vDSP_vma(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vmaD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
    extern fn vDSP_vmsa(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: *const f32, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vmsaD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: *const f64, D: [*]f64, ID: Stride, N: Length) void;
    extern fn vDSP_vsma(A: [*]const f32, IA: Stride, B: *const f32, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vsmaD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
    extern fn vDSP_vam(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vamD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
    // -- Multiply-multiply-add/sub --
    extern fn vDSP_vmma(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]const f32, ID: Stride, E: [*]f32, IE: Stride, N: Length) void;
    extern fn vDSP_vmmaD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]const f64, ID: Stride, E: [*]f64, IE: Stride, N: Length) void;
    extern fn vDSP_vmmsb(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]const f32, ID: Stride, E: [*]f32, IE: Stride, N: Length) void;
    extern fn vDSP_vmmsbD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]const f64, ID: Stride, E: [*]f64, IE: Stride, N: Length) void;
    // -- Multiply and subtract --
    extern fn vDSP_vmsb(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vmsbD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
    // -- Scalar multiply and scalar add --
    extern fn vDSP_vsmsa(A: [*]const f32, IA: Stride, B: *const f32, C: *const f32, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vsmsaD(A: [*]const f64, IA: Stride, B: *const f64, C: *const f64, D: [*]f64, ID: Stride, N: Length) void;
    // -- Scalar multiply and vector subtract --
    extern fn vDSP_vsmsb(A: [*]const f32, IA: Stride, B: *const f32, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vsmsbD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
    // -- Scalar multiply, scalar multiply, and add --
    extern fn vDSP_vsmsma(A: [*]const f32, IA: Stride, B: *const f32, C: [*]const f32, IC: Stride, D: *const f32, E: [*]f32, IE: Stride, N: Length) void;
    extern fn vDSP_vsmsmaD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]const f64, IC: Stride, D: *const f64, E: [*]f64, IE: Stride, N: Length) void;
    // -- Add-add-multiply, add-sub-multiply, add-scalar-multiply --
    extern fn vDSP_vaam(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]const f32, ID: Stride, E: [*]f32, IE: Stride, N: Length) void;
    extern fn vDSP_vaamD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]const f64, ID: Stride, E: [*]f64, IE: Stride, N: Length) void;
    extern fn vDSP_vasbm(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]const f32, ID: Stride, E: [*]f32, IE: Stride, N: Length) void;
    extern fn vDSP_vasbmD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]const f64, ID: Stride, E: [*]f64, IE: Stride, N: Length) void;
    extern fn vDSP_vasm(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: *const f32, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vasmD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: *const f64, D: [*]f64, ID: Stride, N: Length) void;
    // -- Subtract-multiply combos --
    extern fn vDSP_vsbm(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vsbmD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
    extern fn vDSP_vsbsbm(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]const f32, ID: Stride, E: [*]f32, IE: Stride, N: Length) void;
    extern fn vDSP_vsbsbmD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]const f64, ID: Stride, E: [*]f64, IE: Stride, N: Length) void;
    extern fn vDSP_vsbsm(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: *const f32, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vsbsmD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: *const f64, D: [*]f64, ID: Stride, N: Length) void;
    // -- Linear average --
    extern fn vDSP_vavlin(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vavlinD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    // -- Pythagoras --
    extern fn vDSP_vpythg(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]const f32, ID: Stride, E: [*]f32, IE: Stride, N: Length) void;
    extern fn vDSP_vpythgD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]const f64, ID: Stride, E: [*]f64, IE: Stride, N: Length) void;
    // -- Unary ops --
    extern fn vDSP_vsq(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vsqD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vssq(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vssqD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vdist(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vdistD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_distancesq(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: *f32, N: Length) void;
    extern fn vDSP_distancesqD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: *f64, N: Length) void;
    extern fn vDSP_vabs(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vabsD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vabsi(A: [*]const i32, IA: Stride, C: [*]i32, IC: Stride, N: Length) void;
    extern fn vDSP_vneg(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vnegD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vnabs(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vnabsD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vfrac(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vfracD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    // -- Precision conversion --
    extern fn vDSP_vdpsp(A: [*]const f64, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vspdp(A: [*]const f32, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    // -- Integer bit equivalence --
    extern fn vDSP_veqvi(A: [*]const i32, IA: Stride, B: [*]const i32, IB: Stride, C: [*]i32, IC: Stride, N: Length) void;
    // -- Complex absolute value --
    extern fn vDSP_zvabs(A: *const SplitComplex, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_zvabsD(A: *const DoubleSplitComplex, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    // -- Complex fill --
    extern fn vDSP_zvfill(A: *const SplitComplex, C: *const SplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zvfillD(A: *const DoubleSplitComplex, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
    // -- Complex multiply with conjugation --
    extern fn vDSP_zvmul(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length, Conjugate: c_int) void;
    extern fn vDSP_zvmulD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length, Conjugate: c_int) void;
    // -- Complex conjugate multiply and add --
    extern fn vDSP_zvcma(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, D: *const SplitComplex, ID: Stride, N: Length) void;
    extern fn vDSP_zvcmaD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, D: *const DoubleSplitComplex, ID: Stride, N: Length) void;
    // -- Complex multiply and add --
    extern fn vDSP_zvma(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, D: *const SplitComplex, ID: Stride, N: Length) void;
    extern fn vDSP_zvmaD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, D: *const DoubleSplitComplex, ID: Stride, N: Length) void;
    // -- Complex conjugate multiply --
    extern fn vDSP_zvcmul(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zvcmulD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
    // -- Complex conjugate --
    extern fn vDSP_zvconj(A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zvconjD(A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
    // -- Complex scalar multiply --
    extern fn vDSP_zvzsml(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, C: *const SplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zvzsmlD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
    // -- Complex magnitudes squared --
    extern fn vDSP_zvmags(A: *const SplitComplex, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_zvmagsD(A: *const DoubleSplitComplex, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    // -- Complex magnitudes squared and add --
    extern fn vDSP_zvmgsa(A: *const SplitComplex, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_zvmgsaD(A: *const DoubleSplitComplex, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    // -- Complex move --
    extern fn vDSP_zvmov(A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zvmovD(A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
    // -- Complex negate --
    extern fn vDSP_zvneg(A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
    extern fn vDSP_zvnegD(A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
    // -- Complex phase --
    extern fn vDSP_zvphas(A: *const SplitComplex, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_zvphasD(A: *const DoubleSplitComplex, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    // -- Complex scalar multiply and add --
    extern fn vDSP_zvsma(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, C: *const SplitComplex, IC: Stride, D: *const SplitComplex, ID: Stride, N: Length) void;
    extern fn vDSP_zvsmaD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, C: *const DoubleSplitComplex, IC: Stride, D: *const DoubleSplitComplex, ID: Stride, N: Length) void;
    // -- Spectral ops --
    extern fn vDSP_zaspec(A: *const SplitComplex, C: [*]f32, N: Length) void;
    extern fn vDSP_zaspecD(A: *const DoubleSplitComplex, C: [*]f64, N: Length) void;
    extern fn vDSP_zcoher(A: [*]const f32, B: [*]const f32, C: *const SplitComplex, D: [*]f32, N: Length) void;
    extern fn vDSP_zcoherD(A: [*]const f64, B: [*]const f64, C: *const DoubleSplitComplex, D: [*]f64, N: Length) void;
    extern fn vDSP_ztrans(A: [*]const f32, B: *const SplitComplex, C: *const SplitComplex, N: Length) void;
    extern fn vDSP_ztransD(A: [*]const f64, B: *const DoubleSplitComplex, C: *const DoubleSplitComplex, N: Length) void;
    extern fn vDSP_zcspec(A: *const SplitComplex, B: *const SplitComplex, C: *const SplitComplex, N: Length) void;
    extern fn vDSP_zcspecD(A: *const DoubleSplitComplex, B: *const DoubleSplitComplex, C: *const DoubleSplitComplex, N: Length) void;
    // -- Downsample --
    extern fn vDSP_desamp(A: [*]const f32, DF: Stride, F: [*]const f32, C: [*]f32, N: Length, P: Length) void;
    extern fn vDSP_desampD(A: [*]const f64, DF: Stride, F: [*]const f64, C: [*]f64, N: Length, P: Length) void;
    extern fn vDSP_zrdesamp(A: *const SplitComplex, DF: Stride, F: [*]const f32, C: *const SplitComplex, N: Length, P: Length) void;
    extern fn vDSP_zrdesampD(A: *const DoubleSplitComplex, DF: Stride, F: [*]const f64, C: *const DoubleSplitComplex, N: Length, P: Length) void;
};

// ============================================================================
// Fill
// ============================================================================

pub fn vfill(val: f32, out: []f32) void {
    c.vDSP_vfill(&val, out.ptr, 1, out.len);
}
pub fn vfillD(val: f64, out: []f64) void {
    c.vDSP_vfillD(&val, out.ptr, 1, out.len);
}
pub fn vfilli(val: c_int, out: []c_int) void {
    c.vDSP_vfilli(&val, out.ptr, 1, out.len);
}

// ============================================================================
// Binary vector ops
// ============================================================================

pub fn vadd(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vadd(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vaddD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vaddD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vaddi(a: []const i32, b: []const i32, out: []i32) void {
    c.vDSP_vaddi(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

pub fn vsub(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vsub(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vsubD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vsubD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

pub fn vmul(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vmul(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vmulD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vmulD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

pub fn vdiv(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vdiv(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vdivD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vdivD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vdivi(a: []const i32, b: []const i32, out: []i32) void {
    c.vDSP_vdivi(b.ptr, 1, a.ptr, 1, out.ptr, 1, a.len);
}

// -- Integer bit equivalence: C[n] = ~(A[n] ^ B[n]) --

pub fn veqvi(a: []const i32, b: []const i32, out: []i32) void {
    c.vDSP_veqvi(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

// ============================================================================
// Scalar-vector ops
// ============================================================================

pub fn vsmul(a: []const f32, scalar: f32, out: []f32) void {
    c.vDSP_vsmul(a.ptr, 1, &scalar, out.ptr, 1, a.len);
}
pub fn vsmulD(a: []const f64, scalar: f64, out: []f64) void {
    c.vDSP_vsmulD(a.ptr, 1, &scalar, out.ptr, 1, a.len);
}

pub fn vsadd(a: []const f32, scalar: f32, out: []f32) void {
    c.vDSP_vsadd(a.ptr, 1, &scalar, out.ptr, 1, a.len);
}
pub fn vsaddD(a: []const f64, scalar: f64, out: []f64) void {
    c.vDSP_vsaddD(a.ptr, 1, &scalar, out.ptr, 1, a.len);
}
pub fn vsaddi(a: []const i32, scalar: i32, out: []i32) void {
    c.vDSP_vsaddi(a.ptr, 1, &scalar, out.ptr, 1, a.len);
}

pub fn vsdiv(a: []const f32, scalar: f32, out: []f32) void {
    c.vDSP_vsdiv(a.ptr, 1, &scalar, out.ptr, 1, a.len);
}
pub fn vsdivD(a: []const f64, scalar: f64, out: []f64) void {
    c.vDSP_vsdivD(a.ptr, 1, &scalar, out.ptr, 1, a.len);
}
pub fn vsdivi(a: []const i32, scalar: i32, out: []i32) void {
    c.vDSP_vsdivi(a.ptr, 1, &scalar, out.ptr, 1, a.len);
}

/// Scalar / vector: C[n] = scalar / B[n]
pub fn svdiv(scalar: f32, b: []const f32, out: []f32) void {
    c.vDSP_svdiv(&scalar, b.ptr, 1, out.ptr, 1, b.len);
}
pub fn svdivD(scalar: f64, b: []const f64, out: []f64) void {
    c.vDSP_svdivD(&scalar, b.ptr, 1, out.ptr, 1, b.len);
}

// ============================================================================
// Multiply-add variants
// ============================================================================

/// D[n] = A[n] * B[n] + C[n]
pub fn vma(a: []const f32, b: []const f32, addend: []const f32, out: []f32) void {
    c.vDSP_vma(a.ptr, 1, b.ptr, 1, addend.ptr, 1, out.ptr, 1, a.len);
}
pub fn vmaD(a: []const f64, b: []const f64, addend: []const f64, out: []f64) void {
    c.vDSP_vmaD(a.ptr, 1, b.ptr, 1, addend.ptr, 1, out.ptr, 1, a.len);
}

/// D[n] = A[n] * B[n] + scalar
pub fn vmsa(a: []const f32, b: []const f32, scalar: f32, out: []f32) void {
    c.vDSP_vmsa(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len);
}
pub fn vmsaD(a: []const f64, b: []const f64, scalar: f64, out: []f64) void {
    c.vDSP_vmsaD(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len);
}

/// D[n] = A[n] * scalar + C[n]
pub fn vsma(a: []const f32, scalar: f32, addend: []const f32, out: []f32) void {
    c.vDSP_vsma(a.ptr, 1, &scalar, addend.ptr, 1, out.ptr, 1, a.len);
}
pub fn vsmaD(a: []const f64, scalar: f64, addend: []const f64, out: []f64) void {
    c.vDSP_vsmaD(a.ptr, 1, &scalar, addend.ptr, 1, out.ptr, 1, a.len);
}

/// D[n] = (A[n] + B[n]) * C[n]
pub fn vam(a: []const f32, b: []const f32, multiplier: []const f32, out: []f32) void {
    c.vDSP_vam(a.ptr, 1, b.ptr, 1, multiplier.ptr, 1, out.ptr, 1, a.len);
}
pub fn vamD(a: []const f64, b: []const f64, multiplier: []const f64, out: []f64) void {
    c.vDSP_vamD(a.ptr, 1, b.ptr, 1, multiplier.ptr, 1, out.ptr, 1, a.len);
}

/// D[n] = A[n] * B[n] - C[n]
pub fn vmsb(a: []const f32, b: []const f32, subtrahend: []const f32, out: []f32) void {
    c.vDSP_vmsb(a.ptr, 1, b.ptr, 1, subtrahend.ptr, 1, out.ptr, 1, a.len);
}
pub fn vmsbD(a: []const f64, b: []const f64, subtrahend: []const f64, out: []f64) void {
    c.vDSP_vmsbD(a.ptr, 1, b.ptr, 1, subtrahend.ptr, 1, out.ptr, 1, a.len);
}

/// E[n] = A[n]*B[n] + C[n]*D[n]
pub fn vmma(a: []const f32, b: []const f32, c_vec: []const f32, d: []const f32, out: []f32) void {
    c.vDSP_vmma(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len);
}
pub fn vmmaD(a: []const f64, b: []const f64, c_vec: []const f64, d: []const f64, out: []f64) void {
    c.vDSP_vmmaD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len);
}

/// E[n] = A[n]*B[n] - C[n]*D[n]
pub fn vmmsb(a: []const f32, b: []const f32, c_vec: []const f32, d: []const f32, out: []f32) void {
    c.vDSP_vmmsb(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len);
}
pub fn vmmsbD(a: []const f64, b: []const f64, c_vec: []const f64, d: []const f64, out: []f64) void {
    c.vDSP_vmmsbD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len);
}

/// D[n] = A[n] * scalar + scalar2
pub fn vsmsa(a: []const f32, scalar: f32, scalar2: f32, out: []f32) void {
    c.vDSP_vsmsa(a.ptr, 1, &scalar, &scalar2, out.ptr, 1, a.len);
}
pub fn vsmsaD(a: []const f64, scalar: f64, scalar2: f64, out: []f64) void {
    c.vDSP_vsmsaD(a.ptr, 1, &scalar, &scalar2, out.ptr, 1, a.len);
}

/// D[n] = A[n] * scalar - C[n]
pub fn vsmsb(a: []const f32, scalar: f32, subtrahend: []const f32, out: []f32) void {
    c.vDSP_vsmsb(a.ptr, 1, &scalar, subtrahend.ptr, 1, out.ptr, 1, a.len);
}
pub fn vsmsbD(a: []const f64, scalar: f64, subtrahend: []const f64, out: []f64) void {
    c.vDSP_vsmsbD(a.ptr, 1, &scalar, subtrahend.ptr, 1, out.ptr, 1, a.len);
}

/// E[n] = A[n]*scalarA + C[n]*scalarB
pub fn vsmsma(a: []const f32, scalar_a: f32, b: []const f32, scalar_b: f32, out: []f32) void {
    c.vDSP_vsmsma(a.ptr, 1, &scalar_a, b.ptr, 1, &scalar_b, out.ptr, 1, a.len);
}
pub fn vsmsmaD(a: []const f64, scalar_a: f64, b: []const f64, scalar_b: f64, out: []f64) void {
    c.vDSP_vsmsmaD(a.ptr, 1, &scalar_a, b.ptr, 1, &scalar_b, out.ptr, 1, a.len);
}

// ============================================================================
// Add-add-multiply, add-sub-multiply, add-scalar-multiply
// ============================================================================

/// E[n] = (A[n] + B[n]) * (C[n] + D[n])
pub fn vaam(a: []const f32, b: []const f32, c_vec: []const f32, d: []const f32, out: []f32) void {
    c.vDSP_vaam(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len);
}
pub fn vaamD(a: []const f64, b: []const f64, c_vec: []const f64, d: []const f64, out: []f64) void {
    c.vDSP_vaamD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len);
}

/// E[n] = (A[n] + B[n]) * (C[n] - D[n])
pub fn vasbm(a: []const f32, b: []const f32, c_vec: []const f32, d: []const f32, out: []f32) void {
    c.vDSP_vasbm(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len);
}
pub fn vasbmD(a: []const f64, b: []const f64, c_vec: []const f64, d: []const f64, out: []f64) void {
    c.vDSP_vasbmD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len);
}

/// D[n] = (A[n] + B[n]) * scalar
pub fn vasm(a: []const f32, b: []const f32, scalar: f32, out: []f32) void {
    c.vDSP_vasm(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len);
}
pub fn vasmD(a: []const f64, b: []const f64, scalar: f64, out: []f64) void {
    c.vDSP_vasmD(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len);
}

// ============================================================================
// Subtract-multiply combos
// ============================================================================

/// D[n] = (A[n] - B[n]) * C[n]
pub fn vsbm(a: []const f32, b: []const f32, multiplier: []const f32, out: []f32) void {
    c.vDSP_vsbm(a.ptr, 1, b.ptr, 1, multiplier.ptr, 1, out.ptr, 1, a.len);
}
pub fn vsbmD(a: []const f64, b: []const f64, multiplier: []const f64, out: []f64) void {
    c.vDSP_vsbmD(a.ptr, 1, b.ptr, 1, multiplier.ptr, 1, out.ptr, 1, a.len);
}

/// E[n] = (A[n] - B[n]) * (C[n] - D[n])
pub fn vsbsbm(a: []const f32, b: []const f32, c_vec: []const f32, d: []const f32, out: []f32) void {
    c.vDSP_vsbsbm(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len);
}
pub fn vsbsbmD(a: []const f64, b: []const f64, c_vec: []const f64, d: []const f64, out: []f64) void {
    c.vDSP_vsbsbmD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len);
}

/// D[n] = (A[n] - B[n]) * scalar
pub fn vsbsm(a: []const f32, b: []const f32, scalar: f32, out: []f32) void {
    c.vDSP_vsbsm(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len);
}
pub fn vsbsmD(a: []const f64, b: []const f64, scalar: f64, out: []f64) void {
    c.vDSP_vsbsmD(a.ptr, 1, b.ptr, 1, &scalar, out.ptr, 1, a.len);
}

// ============================================================================
// Linear average
// ============================================================================

/// C[n] = (C[n]*scalar + A[n]) / (scalar + 1)
pub fn vavlin(a: []const f32, scalar: f32, out: []f32) void {
    c.vDSP_vavlin(a.ptr, 1, &scalar, out.ptr, 1, a.len);
}
pub fn vavlinD(a: []const f64, scalar: f64, out: []f64) void {
    c.vDSP_vavlinD(a.ptr, 1, &scalar, out.ptr, 1, a.len);
}

// ============================================================================
// Pythagoras
// ============================================================================

/// E[n] = sqrt((A[n]-C[n])^2 + (B[n]-D[n])^2)
pub fn vpythg(a: []const f32, b: []const f32, c_vec: []const f32, d: []const f32, out: []f32) void {
    c.vDSP_vpythg(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len);
}
pub fn vpythgD(a: []const f64, b: []const f64, c_vec: []const f64, d: []const f64, out: []f64) void {
    c.vDSP_vpythgD(a.ptr, 1, b.ptr, 1, c_vec.ptr, 1, d.ptr, 1, out.ptr, 1, a.len);
}

// ============================================================================
// Unary ops
// ============================================================================

pub fn vsq(a: []const f32, out: []f32) void {
    c.vDSP_vsq(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vsqD(a: []const f64, out: []f64) void {
    c.vDSP_vsqD(a.ptr, 1, out.ptr, 1, a.len);
}

pub fn vssq(a: []const f32, out: []f32) void {
    c.vDSP_vssq(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vssqD(a: []const f64, out: []f64) void {
    c.vDSP_vssqD(a.ptr, 1, out.ptr, 1, a.len);
}

pub fn vabs(a: []const f32, out: []f32) void {
    c.vDSP_vabs(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vabsD(a: []const f64, out: []f64) void {
    c.vDSP_vabsD(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vabsi(a: []const i32, out: []i32) void {
    c.vDSP_vabsi(a.ptr, 1, out.ptr, 1, a.len);
}

pub fn vneg(a: []const f32, out: []f32) void {
    c.vDSP_vneg(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vnegD(a: []const f64, out: []f64) void {
    c.vDSP_vnegD(a.ptr, 1, out.ptr, 1, a.len);
}

/// C[n] = -|A[n]|
pub fn vnabs(a: []const f32, out: []f32) void {
    c.vDSP_vnabs(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vnabsD(a: []const f64, out: []f64) void {
    c.vDSP_vnabsD(a.ptr, 1, out.ptr, 1, a.len);
}

pub fn vfrac(a: []const f32, out: []f32) void {
    c.vDSP_vfrac(a.ptr, 1, out.ptr, 1, a.len);
}
pub fn vfracD(a: []const f64, out: []f64) void {
    c.vDSP_vfracD(a.ptr, 1, out.ptr, 1, a.len);
}

pub fn vdist(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vdist(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vdistD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vdistD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

/// Euclidean distance squared (scalar output): C = sum((A[n]-B[n])^2)
pub fn distancesq(a: []const f32, b: []const f32) f32 {
    var result: f32 = undefined;
    c.vDSP_distancesq(a.ptr, 1, b.ptr, 1, &result, a.len);
    return result;
}
pub fn distancesqD(a: []const f64, b: []const f64) f64 {
    var result: f64 = undefined;
    c.vDSP_distancesqD(a.ptr, 1, b.ptr, 1, &result, a.len);
    return result;
}

// ============================================================================
// Precision conversion
// ============================================================================

/// Double to single precision
pub fn vdpsp(a: []const f64, out: []f32) void {
    c.vDSP_vdpsp(a.ptr, 1, out.ptr, 1, a.len);
}

/// Single to double precision
pub fn vspdp(a: []const f32, out: []f64) void {
    c.vDSP_vspdp(a.ptr, 1, out.ptr, 1, a.len);
}

// ============================================================================
// Complex vector arithmetic
// ============================================================================

// -- Complex add --

pub fn zvadd(a: *const SplitComplex, b: *const SplitComplex, out: *const SplitComplex, n: Length) void {
    c.vDSP_zvadd(a, 1, b, 1, out, 1, n);
}
pub fn zvaddD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zvaddD(a, 1, b, 1, out, 1, n);
}

pub fn zrvadd(a: *const SplitComplex, b: []const f32, out: *const SplitComplex, n: Length) void {
    c.vDSP_zrvadd(a, 1, b.ptr, 1, out, 1, n);
}
pub fn zrvaddD(a: *const DoubleSplitComplex, b: []const f64, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zrvaddD(a, 1, b.ptr, 1, out, 1, n);
}

// -- Complex subtract --

pub fn zvsub(a: *const SplitComplex, b: *const SplitComplex, out: *const SplitComplex, n: Length) void {
    c.vDSP_zvsub(a, 1, b, 1, out, 1, n);
}
pub fn zvsubD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zvsubD(a, 1, b, 1, out, 1, n);
}

/// Subtract real from complex: C[n] = A[n] - B[n]
pub fn zrvsub(a: *const SplitComplex, b: []const f32, out: *const SplitComplex, n: Length) void {
    c.vDSP_zrvsub(a, 1, b.ptr, 1, out, 1, n);
}
pub fn zrvsubD(a: *const DoubleSplitComplex, b: []const f64, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zrvsubD(a, 1, b.ptr, 1, out, 1, n);
}

// -- Complex-real multiply --

pub fn zrvmul(a: *const SplitComplex, b: []const f32, out: *const SplitComplex, n: Length) void {
    c.vDSP_zrvmul(a, 1, b.ptr, 1, out, 1, n);
}
pub fn zrvmulD(a: *const DoubleSplitComplex, b: []const f64, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zrvmulD(a, 1, b.ptr, 1, out, 1, n);
}

// -- Complex divide --

pub fn zvdiv(a: *const SplitComplex, b: *const SplitComplex, out: *const SplitComplex, n: Length) void {
    c.vDSP_zvdiv(b, 1, a, 1, out, 1, n);
}
pub fn zvdivD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zvdivD(b, 1, a, 1, out, 1, n);
}

/// Complex / real: C[n] = A[n] / B[n]
pub fn zrvdiv(a: *const SplitComplex, b: []const f32, out: *const SplitComplex, n: Length) void {
    c.vDSP_zrvdiv(a, 1, b.ptr, 1, out, 1, n);
}
pub fn zrvdivD(a: *const DoubleSplitComplex, b: []const f64, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zrvdivD(a, 1, b.ptr, 1, out, 1, n);
}

// -- Complex absolute value (magnitude) --

pub fn zvabs(a: *const SplitComplex, out: []f32, n: Length) void {
    c.vDSP_zvabs(a, 1, out.ptr, 1, n);
}
pub fn zvabsD(a: *const DoubleSplitComplex, out: []f64, n: Length) void {
    c.vDSP_zvabsD(a, 1, out.ptr, 1, n);
}

// -- Complex fill --

pub fn zvfill(val: *const SplitComplex, out: *const SplitComplex, n: Length) void {
    c.vDSP_zvfill(val, out, 1, n);
}
pub fn zvfillD(val: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zvfillD(val, out, 1, n);
}

// -- Complex multiply with optional conjugation --

/// C[n] = A[n] * B[n] (conjugate=false) or conj(A[n]) * B[n] (conjugate=true)
pub fn zvmul(a: *const SplitComplex, b: *const SplitComplex, out: *const SplitComplex, n: Length, conjugate: bool) void {
    c.vDSP_zvmul(a, 1, b, 1, out, 1, n, if (conjugate) @as(c_int, -1) else @as(c_int, 1));
}
pub fn zvmulD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length, conjugate: bool) void {
    c.vDSP_zvmulD(a, 1, b, 1, out, 1, n, if (conjugate) @as(c_int, -1) else @as(c_int, 1));
}

// -- Complex conjugate multiply and add --

/// D[n] = conj(A[n]) * B[n] + C[n]
pub fn zvcma(a: *const SplitComplex, b: *const SplitComplex, addend: *const SplitComplex, out: *const SplitComplex, n: Length) void {
    c.vDSP_zvcma(a, 1, b, 1, addend, 1, out, 1, n);
}
pub fn zvcmaD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, addend: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zvcmaD(a, 1, b, 1, addend, 1, out, 1, n);
}

// -- Complex multiply and add --

/// D[n] = A[n] * B[n] + C[n]
pub fn zvma(a: *const SplitComplex, b: *const SplitComplex, addend: *const SplitComplex, out: *const SplitComplex, n: Length) void {
    c.vDSP_zvma(a, 1, b, 1, addend, 1, out, 1, n);
}
pub fn zvmaD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, addend: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zvmaD(a, 1, b, 1, addend, 1, out, 1, n);
}

// -- Complex conjugate multiply --

/// C[n] = conj(A[n]) * B[n]
pub fn zvcmul(a: *const SplitComplex, b: *const SplitComplex, out: *const SplitComplex, n: Length) void {
    c.vDSP_zvcmul(a, 1, b, 1, out, 1, n);
}
pub fn zvcmulD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zvcmulD(a, 1, b, 1, out, 1, n);
}

// -- Complex conjugate --

pub fn zvconj(a: *const SplitComplex, out: *const SplitComplex, n: Length) void {
    c.vDSP_zvconj(a, 1, out, 1, n);
}
pub fn zvconjD(a: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zvconjD(a, 1, out, 1, n);
}

// -- Complex vector multiply by complex scalar --

/// C[n] = A[n] * B[0]
pub fn zvzsml(a: *const SplitComplex, scalar: *const SplitComplex, out: *const SplitComplex, n: Length) void {
    c.vDSP_zvzsml(a, 1, scalar, out, 1, n);
}
pub fn zvzsmlD(a: *const DoubleSplitComplex, scalar: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zvzsmlD(a, 1, scalar, out, 1, n);
}

// -- Complex magnitudes squared --

/// C[n] = |A[n]|^2
pub fn zvmags(a: *const SplitComplex, out: []f32, n: Length) void {
    c.vDSP_zvmags(a, 1, out.ptr, 1, n);
}
pub fn zvmagsD(a: *const DoubleSplitComplex, out: []f64, n: Length) void {
    c.vDSP_zvmagsD(a, 1, out.ptr, 1, n);
}

// -- Complex magnitudes squared and add --

/// C[n] = |A[n]|^2 + B[n]
pub fn zvmgsa(a: *const SplitComplex, b: []const f32, out: []f32, n: Length) void {
    c.vDSP_zvmgsa(a, 1, b.ptr, 1, out.ptr, 1, n);
}
pub fn zvmgsaD(a: *const DoubleSplitComplex, b: []const f64, out: []f64, n: Length) void {
    c.vDSP_zvmgsaD(a, 1, b.ptr, 1, out.ptr, 1, n);
}

// -- Complex move --

pub fn zvmov(a: *const SplitComplex, out: *const SplitComplex, n: Length) void {
    c.vDSP_zvmov(a, 1, out, 1, n);
}
pub fn zvmovD(a: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zvmovD(a, 1, out, 1, n);
}

// -- Complex negate --

pub fn zvneg(a: *const SplitComplex, out: *const SplitComplex, n: Length) void {
    c.vDSP_zvneg(a, 1, out, 1, n);
}
pub fn zvnegD(a: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zvnegD(a, 1, out, 1, n);
}

// -- Complex phase (angle) --

/// C[n] = atan2(Im(A[n]), Re(A[n]))
pub fn zvphas(a: *const SplitComplex, out: []f32, n: Length) void {
    c.vDSP_zvphas(a, 1, out.ptr, 1, n);
}
pub fn zvphasD(a: *const DoubleSplitComplex, out: []f64, n: Length) void {
    c.vDSP_zvphasD(a, 1, out.ptr, 1, n);
}

// -- Complex scalar multiply and add --

/// D[n] = A[n] * B[0] + C[n]
pub fn zvsma(a: *const SplitComplex, scalar: *const SplitComplex, addend: *const SplitComplex, out: *const SplitComplex, n: Length) void {
    c.vDSP_zvsma(a, 1, scalar, addend, 1, out, 1, n);
}
pub fn zvsmaD(a: *const DoubleSplitComplex, scalar: *const DoubleSplitComplex, addend: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zvsmaD(a, 1, scalar, addend, 1, out, 1, n);
}

// ============================================================================
// Spectral / signal ops
// ============================================================================

/// Accumulating autospectrum: C[n] += |A[n]|^2
pub fn zaspec(a: *const SplitComplex, out: []f32, n: Length) void {
    c.vDSP_zaspec(a, out.ptr, n);
}
pub fn zaspecD(a: *const DoubleSplitComplex, out: []f64, n: Length) void {
    c.vDSP_zaspecD(a, out.ptr, n);
}

/// Coherence: D[n] = |C[n]|^2 / (A[n] * B[n])
pub fn zcoher(a: []const f32, b: []const f32, cross: *const SplitComplex, out: []f32, n: Length) void {
    c.vDSP_zcoher(a.ptr, b.ptr, cross, out.ptr, n);
}
pub fn zcoherD(a: []const f64, b: []const f64, cross: *const DoubleSplitComplex, out: []f64, n: Length) void {
    c.vDSP_zcoherD(a.ptr, b.ptr, cross, out.ptr, n);
}

/// Transfer function: C[n] = B[n] / A[n]
pub fn ztrans(a: []const f32, b: *const SplitComplex, out: *const SplitComplex, n: Length) void {
    c.vDSP_ztrans(a.ptr, b, out, n);
}
pub fn ztransD(a: []const f64, b: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_ztransD(a.ptr, b, out, n);
}

/// Accumulating cross-spectrum: C[n] += conj(A[n]) * B[n]
pub fn zcspec(a: *const SplitComplex, b: *const SplitComplex, out: *const SplitComplex, n: Length) void {
    c.vDSP_zcspec(a, b, out, n);
}
pub fn zcspecD(a: *const DoubleSplitComplex, b: *const DoubleSplitComplex, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zcspecD(a, b, out, n);
}

/// Anti-aliasing downsample: C[n] = sum(A[n*DF+p] * F[p], 0 <= p < P)
pub fn desamp(a: [*]const f32, decimation_factor: Stride, filter: []const f32, out: []f32) void {
    c.vDSP_desamp(a, decimation_factor, filter.ptr, out.ptr, out.len, filter.len);
}
pub fn desampD(a: [*]const f64, decimation_factor: Stride, filter: []const f64, out: []f64) void {
    c.vDSP_desampD(a, decimation_factor, filter.ptr, out.ptr, out.len, filter.len);
}

/// Complex-real downsample
pub fn zrdesamp(a: *const SplitComplex, decimation_factor: Stride, filter: []const f32, out: *const SplitComplex, n: Length) void {
    c.vDSP_zrdesamp(a, decimation_factor, filter.ptr, out, n, filter.len);
}
pub fn zrdesampD(a: *const DoubleSplitComplex, decimation_factor: Stride, filter: []const f64, out: *const DoubleSplitComplex, n: Length) void {
    c.vDSP_zrdesampD(a, decimation_factor, filter.ptr, out, n, filter.len);
}

// ============================================================================
// Tests
// ============================================================================

test "vadd" {
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    const b = [_]f32{ 4.0, 5.0, 6.0 };
    var out: [3]f32 = undefined;
    vadd(&a, &b, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 9.0), out[2], 0.001);
}

test "vsmul" {
    const a = [_]f32{ 1.0, 2.0, 3.0 };
    var out: [3]f32 = undefined;
    vsmul(&a, 2.5, &out);
    try std.testing.expectApproxEqAbs(@as(f32, 2.5), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 5.0), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 7.5), out[2], 0.001);
}
