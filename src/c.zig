// Consolidated C extern declarations for all vDSP modules.
//
// This file contains all extern function declarations used by the vDSP Zig bindings.
// Each module imports `const c = @import("c.zig");` to access these.

const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;
const SplitComplex = types.SplitComplex;
const DoubleSplitComplex = types.DoubleSplitComplex;

// -- Opaque setup types --

pub const FFTSetup = *opaque {};
pub const FFTSetupD = *opaque {};
pub const DFTSetup = *opaque {};
pub const DFTSetupD = *opaque {};
pub const DFTInterleavedSetup = *opaque {};
pub const DFTInterleavedSetupD = *opaque {};
pub const BiquadSetup = *opaque {};
pub const BiquadSetupD = *opaque {};
pub const BiquadmSetup = *opaque {};
pub const BiquadmSetupD = *opaque {};

// -- Special types --

pub const Int24 = extern struct {
    bytes: [3]u8,

    pub fn from(val: i24) Int24 {
        return .{ .bytes = @bitCast(val) };
    }

    pub fn to(self: Int24) i24 {
        return @bitCast(self.bytes);
    }

    pub fn toI32(self: Int24) i32 {
        return self.to();
    }
};

pub const UInt24 = extern struct {
    bytes: [3]u8,

    pub fn from(val: u24) UInt24 {
        return .{ .bytes = @bitCast(val) };
    }

    pub fn to(self: UInt24) u24 {
        return @bitCast(self.bytes);
    }

    pub fn toU32(self: UInt24) u32 {
        return self.to();
    }
};

pub const ComplexF32 = extern struct { real: f32, imag: f32 };
pub const ComplexF64 = extern struct { real: f64, imag: f64 };

// ============================================================================
// dotp
// ============================================================================

pub extern fn vDSP_dotpr(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_dotprD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: *f64, N: Length) void;
pub extern fn vDSP_dotpr2(A0: [*]const f32, IA0: Stride, A1: [*]const f32, IA1: Stride, B: [*]const f32, IB: Stride, C0: *f32, C1: *f32, N: Length) void;
pub extern fn vDSP_dotpr2D(A0: [*]const f64, IA0: Stride, A1: [*]const f64, IA1: Stride, B: [*]const f64, IB: Stride, C0: *f64, C1: *f64, N: Length) void;
pub extern fn vDSP_zdotpr(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *SplitComplex, N: Length) void;
pub extern fn vDSP_zdotprD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *DoubleSplitComplex, N: Length) void;
pub extern fn vDSP_zidotpr(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *SplitComplex, N: Length) void;
pub extern fn vDSP_zidotprD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *DoubleSplitComplex, N: Length) void;
pub extern fn vDSP_zrdotpr(A: *const SplitComplex, IA: Stride, B: [*]const f32, IB: Stride, C: *SplitComplex, N: Length) void;
pub extern fn vDSP_zrdotprD(A: *const DoubleSplitComplex, IA: Stride, B: [*]const f64, IB: Stride, C: *DoubleSplitComplex, N: Length) void;
pub extern fn vDSP_dotpr_s1_15(A: [*]const i16, IA: Stride, B: [*]const i16, IB: Stride, C: *i16, N: Length) void;
pub extern fn vDSP_dotpr2_s1_15(A0: [*]const i16, IA0: Stride, A1: [*]const i16, IA1: Stride, B: [*]const i16, IB: Stride, C0: *i16, C1: *i16, N: Length) void;
pub extern fn vDSP_dotpr_s8_24(A: [*]const i32, IA: Stride, B: [*]const i32, IB: Stride, C: *i32, N: Length) void;
pub extern fn vDSP_dotpr2_s8_24(A0: [*]const i32, IA0: Stride, A1: [*]const i32, IA1: Stride, B: [*]const i32, IB: Stride, C0: *i32, C1: *i32, N: Length) void;

// ============================================================================
// vecop
// ============================================================================

// -- Vector fill --
pub extern fn vDSP_vfill(A: *const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfillD(A: *const f64, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vfilli(A: *const i32, C: [*]i32, IC: Stride, N: Length) void;
// -- Vector add --
pub extern fn vDSP_vadd(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vaddD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vaddi(A: [*]const i32, IA: Stride, B: [*]const i32, IB: Stride, C: [*]i32, IC: Stride, N: Length) void;
pub extern fn vDSP_zvadd(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zvaddD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zrvadd(A: *const SplitComplex, IA: Stride, B: [*]const f32, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zrvaddD(A: *const DoubleSplitComplex, IA: Stride, B: [*]const f64, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
// -- Vector subtract --
pub extern fn vDSP_vsub(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vsubD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_zvsub(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zvsubD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zrvsub(A: *const SplitComplex, IA: Stride, B: [*]const f32, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zrvsubD(A: *const DoubleSplitComplex, IA: Stride, B: [*]const f64, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
// -- Vector multiply --
pub extern fn vDSP_vmul(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vmulD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_zrvmul(A: *const SplitComplex, IA: Stride, B: [*]const f32, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zrvmulD(A: *const DoubleSplitComplex, IA: Stride, B: [*]const f64, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
// -- Vector divide --
pub extern fn vDSP_vdiv(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vdivD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vdivi(B: [*]const i32, IB: Stride, A: [*]const i32, IA: Stride, C: [*]i32, IC: Stride, N: Length) void;
pub extern fn vDSP_zvdiv(B: *const SplitComplex, IB: Stride, A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zvdivD(B: *const DoubleSplitComplex, IB: Stride, A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zrvdiv(A: *const SplitComplex, IA: Stride, B: [*]const f32, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zrvdivD(A: *const DoubleSplitComplex, IA: Stride, B: [*]const f64, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
// -- Scalar-vector ops --
pub extern fn vDSP_vsmul(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vsmulD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vsadd(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vsaddD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vsaddi(A: [*]const i32, IA: Stride, B: *const i32, C: [*]i32, IC: Stride, N: Length) void;
pub extern fn vDSP_vsdiv(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vsdivD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vsdivi(A: [*]const i32, IA: Stride, B: *const i32, C: [*]i32, IC: Stride, N: Length) void;
pub extern fn vDSP_svdiv(A: *const f32, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_svdivD(A: *const f64, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
// -- Multiply-add variants --
pub extern fn vDSP_vma(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vmaD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
pub extern fn vDSP_vmsa(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: *const f32, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vmsaD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: *const f64, D: [*]f64, ID: Stride, N: Length) void;
pub extern fn vDSP_vsma(A: [*]const f32, IA: Stride, B: *const f32, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vsmaD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
pub extern fn vDSP_vam(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vamD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
// -- Multiply-multiply-add/sub --
pub extern fn vDSP_vmma(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]const f32, ID: Stride, E: [*]f32, IE: Stride, N: Length) void;
pub extern fn vDSP_vmmaD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]const f64, ID: Stride, E: [*]f64, IE: Stride, N: Length) void;
pub extern fn vDSP_vmmsb(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]const f32, ID: Stride, E: [*]f32, IE: Stride, N: Length) void;
pub extern fn vDSP_vmmsbD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]const f64, ID: Stride, E: [*]f64, IE: Stride, N: Length) void;
// -- Multiply and subtract --
pub extern fn vDSP_vmsb(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vmsbD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
// -- Scalar multiply and scalar add --
pub extern fn vDSP_vsmsa(A: [*]const f32, IA: Stride, B: *const f32, C: *const f32, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vsmsaD(A: [*]const f64, IA: Stride, B: *const f64, C: *const f64, D: [*]f64, ID: Stride, N: Length) void;
// -- Scalar multiply and vector subtract --
pub extern fn vDSP_vsmsb(A: [*]const f32, IA: Stride, B: *const f32, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vsmsbD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
// -- Scalar multiply, scalar multiply, and add --
pub extern fn vDSP_vsmsma(A: [*]const f32, IA: Stride, B: *const f32, C: [*]const f32, IC: Stride, D: *const f32, E: [*]f32, IE: Stride, N: Length) void;
pub extern fn vDSP_vsmsmaD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]const f64, IC: Stride, D: *const f64, E: [*]f64, IE: Stride, N: Length) void;
// -- Add-add-multiply, add-sub-multiply, add-scalar-multiply --
pub extern fn vDSP_vaam(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]const f32, ID: Stride, E: [*]f32, IE: Stride, N: Length) void;
pub extern fn vDSP_vaamD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]const f64, ID: Stride, E: [*]f64, IE: Stride, N: Length) void;
pub extern fn vDSP_vasbm(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]const f32, ID: Stride, E: [*]f32, IE: Stride, N: Length) void;
pub extern fn vDSP_vasbmD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]const f64, ID: Stride, E: [*]f64, IE: Stride, N: Length) void;
pub extern fn vDSP_vasm(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: *const f32, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vasmD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: *const f64, D: [*]f64, ID: Stride, N: Length) void;
// -- Subtract-multiply combos --
pub extern fn vDSP_vsbm(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vsbmD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
pub extern fn vDSP_vsbsbm(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]const f32, ID: Stride, E: [*]f32, IE: Stride, N: Length) void;
pub extern fn vDSP_vsbsbmD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]const f64, ID: Stride, E: [*]f64, IE: Stride, N: Length) void;
pub extern fn vDSP_vsbsm(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: *const f32, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vsbsmD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: *const f64, D: [*]f64, ID: Stride, N: Length) void;
// -- Linear average --
pub extern fn vDSP_vavlin(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vavlinD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
// -- Pythagoras --
pub extern fn vDSP_vpythg(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]const f32, IC: Stride, D: [*]const f32, ID: Stride, E: [*]f32, IE: Stride, N: Length) void;
pub extern fn vDSP_vpythgD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]const f64, IC: Stride, D: [*]const f64, ID: Stride, E: [*]f64, IE: Stride, N: Length) void;
// -- Unary ops --
pub extern fn vDSP_vsq(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vsqD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vssq(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vssqD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vdist(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vdistD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_distancesq(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_distancesqD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: *f64, N: Length) void;
pub extern fn vDSP_vabs(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vabsD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vabsi(A: [*]const i32, IA: Stride, C: [*]i32, IC: Stride, N: Length) void;
pub extern fn vDSP_vneg(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vnegD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vnabs(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vnabsD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vfrac(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfracD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
// -- Integer bit equivalence --
pub extern fn vDSP_veqvi(A: [*]const i32, IA: Stride, B: [*]const i32, IB: Stride, C: [*]i32, IC: Stride, N: Length) void;
// -- Complex absolute value --
pub extern fn vDSP_zvabs(A: *const SplitComplex, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_zvabsD(A: *const DoubleSplitComplex, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
// -- Complex fill --
pub extern fn vDSP_zvfill(A: *const SplitComplex, C: *const SplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zvfillD(A: *const DoubleSplitComplex, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
// -- Complex multiply with conjugation --
pub extern fn vDSP_zvmul(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length, Conjugate: c_int) void;
pub extern fn vDSP_zvmulD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length, Conjugate: c_int) void;
// -- Complex conjugate multiply and add --
pub extern fn vDSP_zvcma(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, D: *const SplitComplex, ID: Stride, N: Length) void;
pub extern fn vDSP_zvcmaD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, D: *const DoubleSplitComplex, ID: Stride, N: Length) void;
// -- Complex multiply and add --
pub extern fn vDSP_zvma(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, D: *const SplitComplex, ID: Stride, N: Length) void;
pub extern fn vDSP_zvmaD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, D: *const DoubleSplitComplex, ID: Stride, N: Length) void;
// -- Complex conjugate multiply --
pub extern fn vDSP_zvcmul(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zvcmulD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
// -- Complex conjugate --
pub extern fn vDSP_zvconj(A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zvconjD(A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
// -- Complex scalar multiply --
pub extern fn vDSP_zvzsml(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, C: *const SplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zvzsmlD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
// -- Complex magnitudes squared --
pub extern fn vDSP_zvmags(A: *const SplitComplex, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_zvmagsD(A: *const DoubleSplitComplex, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
// -- Complex magnitudes squared and add --
pub extern fn vDSP_zvmgsa(A: *const SplitComplex, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_zvmgsaD(A: *const DoubleSplitComplex, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
// -- Complex move --
pub extern fn vDSP_zvmov(A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zvmovD(A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
// -- Complex negate --
pub extern fn vDSP_zvneg(A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, N: Length) void;
pub extern fn vDSP_zvnegD(A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length) void;
// -- Complex phase --
pub extern fn vDSP_zvphas(A: *const SplitComplex, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_zvphasD(A: *const DoubleSplitComplex, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
// -- Complex scalar multiply and add --
pub extern fn vDSP_zvsma(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, C: *const SplitComplex, IC: Stride, D: *const SplitComplex, ID: Stride, N: Length) void;
pub extern fn vDSP_zvsmaD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, C: *const DoubleSplitComplex, IC: Stride, D: *const DoubleSplitComplex, ID: Stride, N: Length) void;
// -- Spectral ops --
pub extern fn vDSP_zaspec(A: *const SplitComplex, C: [*]f32, N: Length) void;
pub extern fn vDSP_zaspecD(A: *const DoubleSplitComplex, C: [*]f64, N: Length) void;
pub extern fn vDSP_zcoher(A: [*]const f32, B: [*]const f32, C: *const SplitComplex, D: [*]f32, N: Length) void;
pub extern fn vDSP_zcoherD(A: [*]const f64, B: [*]const f64, C: *const DoubleSplitComplex, D: [*]f64, N: Length) void;
pub extern fn vDSP_ztrans(A: [*]const f32, B: *const SplitComplex, C: *const SplitComplex, N: Length) void;
pub extern fn vDSP_ztransD(A: [*]const f64, B: *const DoubleSplitComplex, C: *const DoubleSplitComplex, N: Length) void;
pub extern fn vDSP_zcspec(A: *const SplitComplex, B: *const SplitComplex, C: *const SplitComplex, N: Length) void;
pub extern fn vDSP_zcspecD(A: *const DoubleSplitComplex, B: *const DoubleSplitComplex, C: *const DoubleSplitComplex, N: Length) void;
// -- Downsample --
pub extern fn vDSP_desamp(A: [*]const f32, DF: Stride, F: [*]const f32, C: [*]f32, N: Length, P: Length) void;
pub extern fn vDSP_desampD(A: [*]const f64, DF: Stride, F: [*]const f64, C: [*]f64, N: Length, P: Length) void;
pub extern fn vDSP_zrdesamp(A: *const SplitComplex, DF: Stride, F: [*]const f32, C: *const SplitComplex, N: Length, P: Length) void;
pub extern fn vDSP_zrdesampD(A: *const DoubleSplitComplex, DF: Stride, F: [*]const f64, C: *const DoubleSplitComplex, N: Length, P: Length) void;

// ============================================================================
// vaddsub
// ============================================================================

pub extern fn vDSP_vaddsub(I0: [*]const f32, I0S: Stride, I1: [*]const f32, I1S: Stride, O0: [*]f32, O0S: Stride, O1: [*]f32, O1S: Stride, N: Length) void;
pub extern fn vDSP_vaddsubD(I0: [*]const f64, I0S: Stride, I1: [*]const f64, I1S: Stride, O0: [*]f64, O0S: Stride, O1: [*]f64, O1S: Stride, N: Length) void;

// ============================================================================
// reduction
// ============================================================================

pub extern fn vDSP_sve(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_sveD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
pub extern fn vDSP_svesq(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_svesqD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
pub extern fn vDSP_sve_svesq(A: [*]const f32, IA: Stride, Sum: *f32, SumSq: *f32, N: Length) void;
pub extern fn vDSP_sve_svesqD(A: [*]const f64, IA: Stride, Sum: *f64, SumSq: *f64, N: Length) void;
pub extern fn vDSP_svemg(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_svemgD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
pub extern fn vDSP_meanv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_meanvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
pub extern fn vDSP_meamgv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_meamgvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
pub extern fn vDSP_measqv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_measqvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
pub extern fn vDSP_rmsqv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_rmsqvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
pub extern fn vDSP_maxv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_maxvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
pub extern fn vDSP_maxvi(A: [*]const f32, IA: Stride, C: *f32, I: *Length, N: Length) void;
pub extern fn vDSP_maxviD(A: [*]const f64, IA: Stride, C: *f64, I: *Length, N: Length) void;
pub extern fn vDSP_maxmgv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_maxmgvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
pub extern fn vDSP_maxmgvi(A: [*]const f32, IA: Stride, C: *f32, I: *Length, N: Length) void;
pub extern fn vDSP_maxmgviD(A: [*]const f64, IA: Stride, C: *f64, I: *Length, N: Length) void;
pub extern fn vDSP_minv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_minvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
pub extern fn vDSP_minvi(A: [*]const f32, IA: Stride, C: *f32, I: *Length, N: Length) void;
pub extern fn vDSP_minviD(A: [*]const f64, IA: Stride, C: *f64, I: *Length, N: Length) void;
pub extern fn vDSP_minmgv(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_minmgvD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
pub extern fn vDSP_minmgvi(A: [*]const f32, IA: Stride, C: *f32, I: *Length, N: Length) void;
pub extern fn vDSP_minmgviD(A: [*]const f64, IA: Stride, C: *f64, I: *Length, N: Length) void;
pub extern fn vDSP_normalize(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, Mean: *f32, StdDev: *f32, N: Length) void;
pub extern fn vDSP_normalizeD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, Mean: *f64, StdDev: *f64, N: Length) void;
pub extern fn vDSP_mmov(A: [*]const f32, C: [*]f32, M: Length, N: Length, TA: Length, TC: Length) void;
pub extern fn vDSP_mmovD(A: [*]const f64, C: [*]f64, M: Length, N: Length, TA: Length, TC: Length) void;
pub extern fn vDSP_mvessq(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_mvessqD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;
pub extern fn vDSP_nzcros(A: [*]const f32, IA: Stride, B: Length, C: *Length, D: *Length, N: Length) void;
pub extern fn vDSP_nzcrosD(A: [*]const f64, IA: Stride, B: Length, C: *Length, D: *Length, N: Length) void;
pub extern fn vDSP_svs(A: [*]const f32, IA: Stride, C: *f32, N: Length) void;
pub extern fn vDSP_svsD(A: [*]const f64, IA: Stride, C: *f64, N: Length) void;

// ============================================================================
// clip
// ============================================================================

pub extern fn vDSP_vclr(C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vclrD(C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vcmprs(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vcmprsD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vclip(A: [*]const f32, IA: Stride, lo: *const f32, hi: *const f32, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vclipD(A: [*]const f64, IA: Stride, lo: *const f64, hi: *const f64, D: [*]f64, ID: Stride, N: Length) void;
pub extern fn vDSP_vclipc(A: [*]const f32, IA: Stride, lo: *const f32, hi: *const f32, D: [*]f32, ID: Stride, N: Length, NLow: *Length, NHigh: *Length) void;
pub extern fn vDSP_vclipcD(A: [*]const f64, IA: Stride, lo: *const f64, hi: *const f64, D: [*]f64, ID: Stride, N: Length, NLow: *Length, NHigh: *Length) void;
pub extern fn vDSP_viclip(A: [*]const f32, IA: Stride, lo: *const f32, hi: *const f32, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_viclipD(A: [*]const f64, IA: Stride, lo: *const f64, hi: *const f64, D: [*]f64, ID: Stride, N: Length) void;
pub extern fn vDSP_vthr(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vthrD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vthres(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vthresD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vlim(A: [*]const f32, IA: Stride, B: *const f32, C_val: *const f32, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vlimD(A: [*]const f64, IA: Stride, B: *const f64, C_val: *const f64, D: [*]f64, ID: Stride, N: Length) void;
pub extern fn vDSP_vmax(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vmaxD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vmin(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vminD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vmaxmg(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vmaxmgD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vminmg(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vminmgD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;

// ============================================================================
// util
// ============================================================================

// -- Reverse / swap / sort --
pub extern fn vDSP_vrvrs(C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vrvrsD(C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vswap(A: [*]f32, IA: Stride, B: [*]f32, IB: Stride, N: Length) void;
pub extern fn vDSP_vswapD(A: [*]f64, IA: Stride, B: [*]f64, IB: Stride, N: Length) void;
pub extern fn vDSP_vsort(C: [*]f32, N: Length, Order: c_int) void;
pub extern fn vDSP_vsortD(C: [*]f64, N: Length, Order: c_int) void;
pub extern fn vDSP_vsorti(C: [*]const f32, I: [*]Length, Temporary: ?[*]Length, N: Length, Order: c_int) void;
pub extern fn vDSP_vsortiD(C: [*]const f64, I: [*]Length, Temporary: ?[*]Length, N: Length, Order: c_int) void;
// -- Ramp / generate --
pub extern fn vDSP_vramp(A: *const f32, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vrampD(A: *const f64, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vgen(A: *const f32, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vgenD(A: *const f64, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
// -- Gather / index --
pub extern fn vDSP_vgathr(A: [*]const f32, B: [*]const Length, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vgathrD(A: [*]const f64, B: [*]const Length, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vindex(A: [*]const f32, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vindexD(A: [*]const f64, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vgathra(A: [*]const [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vgathraD(A: [*]const [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
// -- Threshold with signed constant --
pub extern fn vDSP_vthrsc(A: [*]const f32, IA: Stride, B: *const f32, C_val: *const f32, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vthrscD(A: [*]const f64, IA: Stride, B: *const f64, C_val: *const f64, D: [*]f64, ID: Stride, N: Length) void;
// -- Table lookup and interpolation --
pub extern fn vDSP_vtabi(A: [*]const f32, IA: Stride, S1: *const f32, S2: *const f32, C: [*]const f32, M: Length, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vtabiD(A: [*]const f64, IA: Stride, S1: *const f64, S2: *const f64, C: [*]const f64, M: Length, D: [*]f64, ID: Stride, N: Length) void;
// -- Tapered merge --
pub extern fn vDSP_vtmerg(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vtmergD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
// -- Wiener Levinson --
pub extern fn vDSP_wiener(L: Length, A: [*]const f32, C: [*]const f32, F: [*]f32, P: [*]f32, Flag: c_int, Error: *c_int) void;
pub extern fn vDSP_wienerD(L: Length, A: [*]const f64, C: [*]const f64, F: [*]f64, P: [*]f64, Flag: c_int, Error: *c_int) void;
// -- Interpolation --
pub extern fn vDSP_vgenp(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, M: Length) void;
pub extern fn vDSP_vgenpD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, M: Length) void;
pub extern fn vDSP_vlint(A: [*]const f32, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, M: Length) void;
pub extern fn vDSP_vlintD(A: [*]const f64, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, M: Length) void;
pub extern fn vDSP_vqint(A: [*]const f32, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, M: Length) void;
pub extern fn vDSP_vqintD(A: [*]const f64, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, M: Length) void;
pub extern fn vDSP_vintb(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: *const f32, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_vintbD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: *const f64, D: [*]f64, ID: Stride, N: Length) void;
pub extern fn vDSP_vpoly(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, P: Length) void;
pub extern fn vDSP_vpolyD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, P: Length) void;
// -- Integration --
pub extern fn vDSP_vrsum(A: [*]const f32, IA: Stride, S: *const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vrsumD(A: [*]const f64, IA: Stride, S: *const f64, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vsimps(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vsimpsD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vtrapz(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vtrapzD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vswsum(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length, P: Length) void;
pub extern fn vDSP_vswsumD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length, P: Length) void;
pub extern fn vDSP_vswmax(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length, P: Length) void;
pub extern fn vDSP_vswmaxD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length, P: Length) void;
// -- Window functions --
pub extern fn vDSP_blkman_window(C: [*]f32, N: Length, Flag: c_int) void;
pub extern fn vDSP_blkman_windowD(C: [*]f64, N: Length, Flag: c_int) void;
pub extern fn vDSP_hamm_window(C: [*]f32, N: Length, Flag: c_int) void;
pub extern fn vDSP_hamm_windowD(C: [*]f64, N: Length, Flag: c_int) void;
pub extern fn vDSP_hann_window(C: [*]f32, N: Length, Flag: c_int) void;
pub extern fn vDSP_hann_windowD(C: [*]f64, N: Length, Flag: c_int) void;

// ============================================================================
// matrix
// ============================================================================

pub extern fn vDSP_mmul(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, M: Length, N: Length, P: Length) void;
pub extern fn vDSP_mmulD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, M: Length, N: Length, P: Length) void;
pub extern fn vDSP_mtrans(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, M: Length, N: Length) void;
pub extern fn vDSP_mtransD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, M: Length, N: Length) void;
pub extern fn vDSP_zmma(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, D: *const SplitComplex, ID: Stride, M: Length, N: Length, P: Length) void;
pub extern fn vDSP_zmmaD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, D: *const DoubleSplitComplex, ID: Stride, M: Length, N: Length, P: Length) void;
pub extern fn vDSP_zmms(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, D: *const SplitComplex, ID: Stride, M: Length, N: Length, P: Length) void;
pub extern fn vDSP_zmmsD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, D: *const DoubleSplitComplex, ID: Stride, M: Length, N: Length, P: Length) void;
pub extern fn vDSP_zmsm(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, D: *const SplitComplex, ID: Stride, M: Length, N: Length, P: Length) void;
pub extern fn vDSP_zmsmD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, D: *const DoubleSplitComplex, ID: Stride, M: Length, N: Length, P: Length) void;
pub extern fn vDSP_zmmul(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, M: Length, N: Length, P: Length) void;
pub extern fn vDSP_zmmulD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, M: Length, N: Length, P: Length) void;
pub extern fn vDSP_zvmmaa(A: *const SplitComplex, IA: Stride, B: *const SplitComplex, IB: Stride, C: *const SplitComplex, IC: Stride, D: *const SplitComplex, ID: Stride, E: *const SplitComplex, IE: Stride, F: *const SplitComplex, IF: Stride, N: Length) void;
pub extern fn vDSP_zvmmaaD(A: *const DoubleSplitComplex, IA: Stride, B: *const DoubleSplitComplex, IB: Stride, C: *const DoubleSplitComplex, IC: Stride, D: *const DoubleSplitComplex, ID: Stride, E: *const DoubleSplitComplex, IE: Stride, F: *const DoubleSplitComplex, IF: Stride, N: Length) void;

// ============================================================================
// conv
// ============================================================================

pub extern fn vDSP_conv(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, M: Length) void;
pub extern fn vDSP_convD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, M: Length) void;
pub extern fn vDSP_zconv(A: *const SplitComplex, IA: Stride, F: *const SplitComplex, IF: Stride, C: *const SplitComplex, IC: Stride, N: Length, P: Length) void;
pub extern fn vDSP_zconvD(A: *const DoubleSplitComplex, IA: Stride, F: *const DoubleSplitComplex, IF: Stride, C: *const DoubleSplitComplex, IC: Stride, N: Length, P: Length) void;
pub extern fn vDSP_imgfir(A: [*]const f32, NR: Length, NC: Length, B: [*]const f32, C: [*]f32, M: Length, N: Length) void;
pub extern fn vDSP_imgfirD(A: [*]const f64, NR: Length, NC: Length, B: [*]const f64, C: [*]f64, M: Length, N: Length) void;
pub extern fn vDSP_f3x3(A: [*]const f32, NR: Length, NC: Length, B: [*]const f32, C: [*]f32) void;
pub extern fn vDSP_f3x3D(A: [*]const f64, NR: Length, NC: Length, B: [*]const f64, C: [*]f64) void;
pub extern fn vDSP_f5x5(A: [*]const f32, NR: Length, NC: Length, B: [*]const f32, C: [*]f32) void;
pub extern fn vDSP_f5x5D(A: [*]const f64, NR: Length, NC: Length, B: [*]const f64, C: [*]f64) void;
pub extern fn vDSP_deq22(A: [*]const f32, IA: Stride, B: [*]const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_deq22D(A: [*]const f64, IA: Stride, B: [*]const f64, C: [*]f64, IC: Stride, N: Length) void;

// ============================================================================
// convert
// ============================================================================

pub extern fn vDSP_vfix8(A: [*]const f32, IA: Stride, C: [*]i8, IC: Stride, N: Length) void;
pub extern fn vDSP_vfix8D(A: [*]const f64, IA: Stride, C: [*]i8, IC: Stride, N: Length) void;
pub extern fn vDSP_vfix16(A: [*]const f32, IA: Stride, C: [*]i16, IC: Stride, N: Length) void;
pub extern fn vDSP_vfix16D(A: [*]const f64, IA: Stride, C: [*]i16, IC: Stride, N: Length) void;
pub extern fn vDSP_vfix32(A: [*]const f32, IA: Stride, C: [*]i32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfix32D(A: [*]const f64, IA: Stride, C: [*]i32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixu8(A: [*]const f32, IA: Stride, C: [*]u8, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixu8D(A: [*]const f64, IA: Stride, C: [*]u8, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixu16(A: [*]const f32, IA: Stride, C: [*]u16, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixu16D(A: [*]const f64, IA: Stride, C: [*]u16, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixu32(A: [*]const f32, IA: Stride, C: [*]u32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixu32D(A: [*]const f64, IA: Stride, C: [*]u32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixr8(A: [*]const f32, IA: Stride, C: [*]i8, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixr8D(A: [*]const f64, IA: Stride, C: [*]i8, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixr16(A: [*]const f32, IA: Stride, C: [*]i16, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixr16D(A: [*]const f64, IA: Stride, C: [*]i16, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixr32(A: [*]const f32, IA: Stride, C: [*]i32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixr32D(A: [*]const f64, IA: Stride, C: [*]i32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixru8(A: [*]const f32, IA: Stride, C: [*]u8, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixru8D(A: [*]const f64, IA: Stride, C: [*]u8, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixru16(A: [*]const f32, IA: Stride, C: [*]u16, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixru16D(A: [*]const f64, IA: Stride, C: [*]u16, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixru32(A: [*]const f32, IA: Stride, C: [*]u32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfixru32D(A: [*]const f64, IA: Stride, C: [*]u32, IC: Stride, N: Length) void;
pub extern fn vDSP_vflt8(A: [*]const i8, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vflt8D(A: [*]const i8, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vflt16(A: [*]const i16, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vflt16D(A: [*]const i16, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vflt32(A: [*]const i32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vflt32D(A: [*]const i32, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vfltu8(A: [*]const u8, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfltu8D(A: [*]const u8, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vfltu16(A: [*]const u16, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfltu16D(A: [*]const u16, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vfltu32(A: [*]const u32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfltu32D(A: [*]const u32, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_vflt24(A: [*]const Int24, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfltu24(A: [*]const UInt24, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfltsm24(A: [*]const Int24, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vfltsmu24(A: [*]const UInt24, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vsmfix24(A: [*]const f32, IA: Stride, B: *const f32, C: [*]Int24, IC: Stride, N: Length) void;
pub extern fn vDSP_vsmfixu24(A: [*]const f32, IA: Stride, B: *const f32, C: [*]UInt24, IC: Stride, N: Length) void;
// -- Precision conversion (also used by vecop) --
pub extern fn vDSP_vdpsp(A: [*]const f64, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_vspdp(A: [*]const f32, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
// -- Decibel conversion --
pub extern fn vDSP_vdbcon(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length, F: c_uint) void;
pub extern fn vDSP_vdbconD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length, F: c_uint) void;
// -- Polar / Rect --
pub extern fn vDSP_polar(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_polarD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
pub extern fn vDSP_rect(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
pub extern fn vDSP_rectD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
// -- Envelope --
pub extern fn vDSP_venvlp(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C_val: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
pub extern fn vDSP_venvlpD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C_val: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;

// ============================================================================
// fft
// ============================================================================

// -- Setup / destroy --
pub extern fn vDSP_create_fftsetup(Log2n: Length, Radix: c_int) ?FFTSetup;
pub extern fn vDSP_create_fftsetupD(Log2n: Length, Radix: c_int) ?FFTSetupD;
pub extern fn vDSP_destroy_fftsetup(setup: ?FFTSetup) void;
pub extern fn vDSP_destroy_fftsetupD(setup: ?FFTSetupD) void;

// -- Complex-to-complex, in-place (zip) --
pub extern fn vDSP_fft_zip(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
pub extern fn vDSP_fft_zipD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
pub extern fn vDSP_fft_zipt(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, Buffer: *const SplitComplex, Log2N: Length, Direction: c_int) void;
pub extern fn vDSP_fft_ziptD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, Direction: c_int) void;

// -- Complex-to-complex, out-of-place (zop) --
pub extern fn vDSP_fft_zop(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
pub extern fn vDSP_fft_zopD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
pub extern fn vDSP_fft_zopt(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, Buffer: *const SplitComplex, Log2N: Length, Direction: c_int) void;
pub extern fn vDSP_fft_zoptD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, Direction: c_int) void;

// -- Real-to-complex, in-place (zrip) --
pub extern fn vDSP_fft_zrip(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
pub extern fn vDSP_fft_zripD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
pub extern fn vDSP_fft_zript(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, Buffer: *const SplitComplex, Log2N: Length, Direction: c_int) void;
pub extern fn vDSP_fft_zriptD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, Direction: c_int) void;

// -- Real-to-complex, out-of-place (zrop) --
pub extern fn vDSP_fft_zrop(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
pub extern fn vDSP_fft_zropD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, Log2N: Length, Direction: c_int) void;
pub extern fn vDSP_fft_zropt(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, C: *const SplitComplex, IC: Stride, Buffer: *const SplitComplex, Log2N: Length, Direction: c_int) void;
pub extern fn vDSP_fft_zroptD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, C: *const DoubleSplitComplex, IC: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, Direction: c_int) void;

// -- 2D complex-to-complex, in-place --
pub extern fn vDSP_fft2d_zip(Setup: FFTSetup, C: *const SplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
pub extern fn vDSP_fft2d_zipD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
pub extern fn vDSP_fft2d_zipt(Setup: FFTSetup, C: *const SplitComplex, IC0: Stride, IC1: Stride, Buffer: *const SplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
pub extern fn vDSP_fft2d_ziptD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Buffer: *const DoubleSplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;

// -- 2D complex-to-complex, out-of-place --
pub extern fn vDSP_fft2d_zop(Setup: FFTSetup, A: *const SplitComplex, IA0: Stride, IA1: Stride, C: *const SplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
pub extern fn vDSP_fft2d_zopD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA0: Stride, IA1: Stride, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
pub extern fn vDSP_fft2d_zopt(Setup: FFTSetup, A: *const SplitComplex, IA0: Stride, IA1: Stride, C: *const SplitComplex, IC0: Stride, IC1: Stride, Buffer: *const SplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
pub extern fn vDSP_fft2d_zoptD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA0: Stride, IA1: Stride, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Buffer: *const DoubleSplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;

// -- 2D real-to-complex, in-place --
pub extern fn vDSP_fft2d_zrip(Setup: FFTSetup, C: *const SplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
pub extern fn vDSP_fft2d_zripD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
pub extern fn vDSP_fft2d_zript(Setup: FFTSetup, C: *const SplitComplex, IC0: Stride, IC1: Stride, Buffer: *const SplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
pub extern fn vDSP_fft2d_zriptD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Buffer: *const DoubleSplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;

// -- 2D real-to-complex, out-of-place --
pub extern fn vDSP_fft2d_zrop(Setup: FFTSetup, A: *const SplitComplex, IA0: Stride, IA1: Stride, C: *const SplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
pub extern fn vDSP_fft2d_zropD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA0: Stride, IA1: Stride, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
pub extern fn vDSP_fft2d_zropt(Setup: FFTSetup, A: *const SplitComplex, IA0: Stride, IA1: Stride, C: *const SplitComplex, IC0: Stride, IC1: Stride, Buffer: *const SplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;
pub extern fn vDSP_fft2d_zroptD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA0: Stride, IA1: Stride, C: *const DoubleSplitComplex, IC0: Stride, IC1: Stride, Buffer: *const DoubleSplitComplex, Log2N0: Length, Log2N1: Length, Direction: c_int) void;

// -- Multiple FFT, complex in-place --
pub extern fn vDSP_fftm_zip(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, IM: Stride, Log2N: Length, M: Length, Direction: c_int) void;
pub extern fn vDSP_fftm_zipD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, IM: Stride, Log2N: Length, M: Length, Direction: c_int) void;
pub extern fn vDSP_fftm_zipt(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, IM: Stride, Buffer: *const SplitComplex, Log2N: Length, M: Length, Direction: c_int) void;
pub extern fn vDSP_fftm_ziptD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, IM: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, M: Length, Direction: c_int) void;

// -- Multiple FFT, complex out-of-place --
pub extern fn vDSP_fftm_zop(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, IMA: Stride, C: *const SplitComplex, IC: Stride, IMC: Stride, Log2N: Length, M: Length, Direction: c_int) void;
pub extern fn vDSP_fftm_zopD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, IMA: Stride, C: *const DoubleSplitComplex, IC: Stride, IMC: Stride, Log2N: Length, M: Length, Direction: c_int) void;
pub extern fn vDSP_fftm_zopt(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, IMA: Stride, C: *const SplitComplex, IC: Stride, IMC: Stride, Buffer: *const SplitComplex, Log2N: Length, M: Length, Direction: c_int) void;
pub extern fn vDSP_fftm_zoptD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, IMA: Stride, C: *const DoubleSplitComplex, IC: Stride, IMC: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, M: Length, Direction: c_int) void;

// -- Multiple FFT, real in-place --
pub extern fn vDSP_fftm_zrip(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, IM: Stride, Log2N: Length, M: Length, Direction: c_int) void;
pub extern fn vDSP_fftm_zripD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, IM: Stride, Log2N: Length, M: Length, Direction: c_int) void;
pub extern fn vDSP_fftm_zript(Setup: FFTSetup, C: *const SplitComplex, IC: Stride, IM: Stride, Buffer: *const SplitComplex, Log2N: Length, M: Length, Direction: c_int) void;
pub extern fn vDSP_fftm_zriptD(Setup: FFTSetupD, C: *const DoubleSplitComplex, IC: Stride, IM: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, M: Length, Direction: c_int) void;

// -- Multiple FFT, real out-of-place --
pub extern fn vDSP_fftm_zrop(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, IMA: Stride, C: *const SplitComplex, IC: Stride, IMC: Stride, Log2N: Length, M: Length, Direction: c_int) void;
pub extern fn vDSP_fftm_zropD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, IMA: Stride, C: *const DoubleSplitComplex, IC: Stride, IMC: Stride, Log2N: Length, M: Length, Direction: c_int) void;
pub extern fn vDSP_fftm_zropt(Setup: FFTSetup, A: *const SplitComplex, IA: Stride, IMA: Stride, C: *const SplitComplex, IC: Stride, IMC: Stride, Buffer: *const SplitComplex, Log2N: Length, M: Length, Direction: c_int) void;
pub extern fn vDSP_fftm_zroptD(Setup: FFTSetupD, A: *const DoubleSplitComplex, IA: Stride, IMA: Stride, C: *const DoubleSplitComplex, IC: Stride, IMC: Stride, Buffer: *const DoubleSplitComplex, Log2N: Length, M: Length, Direction: c_int) void;

// -- Interleaved conversion --
pub extern fn vDSP_ctoz(C: [*]const ComplexF32, IC: Stride, Z: *const SplitComplex, IZ: Stride, N: Length) void;
pub extern fn vDSP_ctozD(C: [*]const ComplexF64, IC: Stride, Z: *const DoubleSplitComplex, IZ: Stride, N: Length) void;
pub extern fn vDSP_ztoc(Z: *const SplitComplex, IZ: Stride, C: [*]ComplexF32, IC: Stride, N: Length) void;
pub extern fn vDSP_ztocD(Z: *const DoubleSplitComplex, IZ: Stride, C: [*]ComplexF64, IC: Stride, N: Length) void;

// ============================================================================
// fixed_fft
// ============================================================================

pub extern fn vDSP_FFT16_copv(Output: [*]f32, Input: [*]const f32, Direction: c_int) void;
pub extern fn vDSP_FFT32_copv(Output: [*]f32, Input: [*]const f32, Direction: c_int) void;
pub extern fn vDSP_FFT16_zopv(Or: [*]f32, Oi: [*]f32, Ir: [*]const f32, Ii: [*]const f32, Direction: c_int) void;
pub extern fn vDSP_FFT32_zopv(Or: [*]f32, Oi: [*]f32, Ir: [*]const f32, Ii: [*]const f32, Direction: c_int) void;

// ============================================================================
// dft
// ============================================================================

// -- Setup --
pub extern fn vDSP_DFT_CreateSetup(Previous: ?DFTSetup, Length: Length) ?DFTSetup;
pub extern fn vDSP_DFT_zop_CreateSetup(Previous: ?DFTSetup, Length: Length, Direction: c_int) ?DFTSetup;
pub extern fn vDSP_DFT_zop_CreateSetupD(Previous: ?DFTSetupD, Length: Length, Direction: c_int) ?DFTSetupD;
pub extern fn vDSP_DFT_zrop_CreateSetup(Previous: ?DFTSetup, Length: Length, Direction: c_int) ?DFTSetup;
pub extern fn vDSP_DFT_zrop_CreateSetupD(Previous: ?DFTSetupD, Length: Length, Direction: c_int) ?DFTSetupD;
pub extern fn vDSP_DCT_CreateSetup(Previous: ?DFTSetup, Length: Length, Type: c_int) ?DFTSetup;
// -- Destroy --
pub extern fn vDSP_DFT_DestroySetup(Setup: ?DFTSetup) void;
pub extern fn vDSP_DFT_DestroySetupD(Setup: ?DFTSetupD) void;
// -- Execute (split complex) --
pub extern fn vDSP_DFT_Execute(Setup: DFTSetup, Ir: [*]const f32, Ii: [*]const f32, Or: [*]f32, Oi: [*]f32) void;
pub extern fn vDSP_DFT_ExecuteD(Setup: DFTSetupD, Ir: [*]const f64, Ii: [*]const f64, Or: [*]f64, Oi: [*]f64) void;
// -- Legacy execute with stride --
pub extern fn vDSP_DFT_zop(Setup: DFTSetup, Ir: [*]const f32, Ii: [*]const f32, Is: Stride, Or: [*]f32, Oi: [*]f32, Os: Stride, Direction: c_int) void;
// -- DCT execute --
pub extern fn vDSP_DCT_Execute(Setup: DFTSetup, Input: [*]const f32, Output: [*]f32) void;
// -- Interleaved setup --
pub extern fn vDSP_DFT_Interleaved_CreateSetup(Previous: ?DFTInterleavedSetup, Length: Length, Direction: c_int, RealToComplex: c_int) ?DFTInterleavedSetup;
pub extern fn vDSP_DFT_Interleaved_CreateSetupD(Previous: ?DFTInterleavedSetupD, Length: Length, Direction: c_int, RealToComplex: c_int) ?DFTInterleavedSetupD;
// -- Interleaved execute --
pub extern fn vDSP_DFT_Interleaved_Execute(Setup: DFTInterleavedSetup, Iri: [*]const ComplexF32, Ori: [*]ComplexF32) void;
pub extern fn vDSP_DFT_Interleaved_ExecuteD(Setup: DFTInterleavedSetupD, Iri: [*]const ComplexF64, Ori: [*]ComplexF64) void;
// -- Interleaved destroy --
pub extern fn vDSP_DFT_Interleaved_DestroySetup(Setup: ?DFTInterleavedSetup) void;
pub extern fn vDSP_DFT_Interleaved_DestroySetupD(Setup: ?DFTInterleavedSetupD) void;

// ============================================================================
// biquad
// ============================================================================

// -- Single-channel setup/destroy --
pub extern fn vDSP_biquad_CreateSetup(Coefficients: [*]const f64, M: Length) ?BiquadSetup;
pub extern fn vDSP_biquad_CreateSetupD(Coefficients: [*]const f64, M: Length) ?BiquadSetupD;
pub extern fn vDSP_biquad_DestroySetup(setup: ?BiquadSetup) void;
pub extern fn vDSP_biquad_DestroySetupD(setup: ?BiquadSetupD) void;
// -- Single-channel coefficient update --
pub extern fn vDSP_biquad_SetCoefficientsDouble(setup: BiquadSetup, coeffs: [*]const f64, start_sec: Length, nsec: Length) void;
pub extern fn vDSP_biquad_SetCoefficientsSingle(setup: BiquadSetup, coeffs: [*]const f32, start_sec: Length, nsec: Length) void;
// -- Single-channel execute --
pub extern fn vDSP_biquad(Setup: BiquadSetup, Delay: [*]f32, X: [*]const f32, IX: Stride, Y: [*]f32, IY: Stride, N: Length) void;
pub extern fn vDSP_biquadD(Setup: BiquadSetupD, Delay: [*]f64, X: [*]const f64, IX: Stride, Y: [*]f64, IY: Stride, N: Length) void;
// -- Multi-channel setup/destroy --
pub extern fn vDSP_biquadm_CreateSetup(coeffs: [*]const f64, M: Length, N: Length) ?BiquadmSetup;
pub extern fn vDSP_biquadm_CreateSetupD(coeffs: [*]const f64, M: Length, N: Length) ?BiquadmSetupD;
pub extern fn vDSP_biquadm_DestroySetup(setup: BiquadmSetup) void;
pub extern fn vDSP_biquadm_DestroySetupD(setup: BiquadmSetupD) void;
// -- Multi-channel state --
pub extern fn vDSP_biquadm_CopyState(dest: BiquadmSetup, src: BiquadmSetup) void;
pub extern fn vDSP_biquadm_CopyStateD(dest: BiquadmSetupD, src: BiquadmSetupD) void;
pub extern fn vDSP_biquadm_ResetState(setup: BiquadmSetup) void;
pub extern fn vDSP_biquadm_ResetStateD(setup: BiquadmSetupD) void;
// -- Multi-channel coefficient update --
pub extern fn vDSP_biquadm_SetCoefficientsDouble(setup: BiquadmSetup, coeffs: [*]const f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;
pub extern fn vDSP_biquadm_SetCoefficientsDoubleD(setup: BiquadmSetupD, coeffs: [*]const f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;
pub extern fn vDSP_biquadm_SetCoefficientsSingle(setup: BiquadmSetup, coeffs: [*]const f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;
pub extern fn vDSP_biquadm_SetCoefficientsSingleD(setup: BiquadmSetupD, coeffs: [*]const f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;
// -- Multi-channel target (interpolated coefficient update) --
pub extern fn vDSP_biquadm_SetTargetsDouble(setup: BiquadmSetup, targets: [*]const f64, interp_rate: f32, interp_threshold: f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;
pub extern fn vDSP_biquadm_SetTargetsDoubleD(setup: BiquadmSetupD, targets: [*]const f64, interp_rate: f64, interp_threshold: f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;
pub extern fn vDSP_biquadm_SetTargetsSingle(setup: BiquadmSetup, targets: [*]const f32, interp_rate: f32, interp_threshold: f32, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;
pub extern fn vDSP_biquadm_SetTargetsSingleD(setup: BiquadmSetupD, targets: [*]const f32, interp_rate: f64, interp_threshold: f64, start_sec: Length, start_chn: Length, nsec: Length, nchn: Length) void;
// -- Multi-channel active filter control --
pub extern fn vDSP_biquadm_SetActiveFilters(setup: BiquadmSetup, filter_states: [*]const bool) void;
pub extern fn vDSP_biquadm_SetActiveFiltersD(setup: BiquadmSetupD, filter_states: [*]const bool) void;
// -- Multi-channel execute --
pub extern fn vDSP_biquadm(Setup: BiquadmSetup, X: [*]const [*]const f32, IX: Stride, Y: [*]const [*]f32, IY: Stride, N: Length) void;
pub extern fn vDSP_biquadmD(Setup: BiquadmSetupD, X: [*]const [*]const f64, IX: Stride, Y: [*]const [*]f64, IY: Stride, N: Length) void;

// ============================================================================
// ramp
// ============================================================================

pub extern fn vDSP_vrampmul(I: [*]const f32, IS: Stride, Start: *f32, Step: *const f32, O: [*]f32, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmulD(I: [*]const f64, IS: Stride, Start: *f64, Step: *const f64, O: [*]f64, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmuladd(I: [*]const f32, IS: Stride, Start: *f32, Step: *const f32, O: [*]f32, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmuladdD(I: [*]const f64, IS: Stride, Start: *f64, Step: *const f64, O: [*]f64, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmul2(I0: [*]const f32, I1: [*]const f32, IS: Stride, Start: *f32, Step: *const f32, O0: [*]f32, O1: [*]f32, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmul2D(I0: [*]const f64, I1: [*]const f64, IS: Stride, Start: *f64, Step: *const f64, O0: [*]f64, O1: [*]f64, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmuladd2(I0: [*]const f32, I1: [*]const f32, IS: Stride, Start: *f32, Step: *const f32, O0: [*]f32, O1: [*]f32, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmuladd2D(I0: [*]const f64, I1: [*]const f64, IS: Stride, Start: *f64, Step: *const f64, O0: [*]f64, O1: [*]f64, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmul_s1_15(I: [*]const i16, IS: Stride, Start: *i16, Step: *const i16, O: [*]i16, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmuladd_s1_15(I: [*]const i16, IS: Stride, Start: *i16, Step: *const i16, O: [*]i16, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmul2_s1_15(I0: [*]const i16, I1: [*]const i16, IS: Stride, Start: *i16, Step: *const i16, O0: [*]i16, O1: [*]i16, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmuladd2_s1_15(I0: [*]const i16, I1: [*]const i16, IS: Stride, Start: *i16, Step: *const i16, O0: [*]i16, O1: [*]i16, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmul_s8_24(I: [*]const i32, IS: Stride, Start: *i32, Step: *const i32, O: [*]i32, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmuladd_s8_24(I: [*]const i32, IS: Stride, Start: *i32, Step: *const i32, O: [*]i32, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmul2_s8_24(I0: [*]const i32, I1: [*]const i32, IS: Stride, Start: *i32, Step: *const i32, O0: [*]i32, O1: [*]i32, OS: Stride, N: Length) void;
pub extern fn vDSP_vrampmuladd2_s8_24(I0: [*]const i32, I1: [*]const i32, IS: Stride, Start: *i32, Step: *const i32, O0: [*]i32, O1: [*]i32, OS: Stride, N: Length) void;
