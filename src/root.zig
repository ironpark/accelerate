pub const types = @import("types.zig");
pub const Stride = types.Stride;
pub const Length = types.Length;
pub const SplitComplex = types.SplitComplex;
pub const SortOrder = types.SortOrder;
pub const DbFlag = types.DbFlag;
pub const WindowFlag = types.WindowFlag;

pub const Complex = types.Complex;
pub const Int24 = types.Int24;
pub const UInt24 = types.UInt24;

// -- dotp --
const dotp_mod = @import("dotp.zig");
pub const dotpr = dotp_mod.dotpr;
pub const dotpr2 = dotp_mod.dotpr2;
pub const zdotpr = dotp_mod.zdotpr;
pub const zidotpr = dotp_mod.zidotpr;
pub const zrdotpr = dotp_mod.zrdotpr;
pub const dotpr_s1_15 = dotp_mod.dotpr_s1_15;
pub const dotpr2_s1_15 = dotp_mod.dotpr2_s1_15;
pub const dotpr_s8_24 = dotp_mod.dotpr_s8_24;
pub const dotpr2_s8_24 = dotp_mod.dotpr2_s8_24;

// -- vecop --
const vecop_mod = @import("vecop.zig");
pub const vfill = vecop_mod.vfill;
pub const vadd = vecop_mod.vadd;
pub const vsub = vecop_mod.vsub;
pub const vmul = vecop_mod.vmul;
pub const vdiv = vecop_mod.vdiv;
pub const veqvi = vecop_mod.veqvi;
pub const vsmul = vecop_mod.vsmul;
pub const vsadd = vecop_mod.vsadd;
pub const vsdiv = vecop_mod.vsdiv;
pub const svdiv = vecop_mod.svdiv;
pub const vma = vecop_mod.vma;
pub const vmsa = vecop_mod.vmsa;
pub const vsma = vecop_mod.vsma;
pub const vam = vecop_mod.vam;
pub const vmsb = vecop_mod.vmsb;
pub const vmma = vecop_mod.vmma;
pub const vmmsb = vecop_mod.vmmsb;
pub const vsmsa = vecop_mod.vsmsa;
pub const vsmsb = vecop_mod.vsmsb;
pub const vsmsma = vecop_mod.vsmsma;
pub const vaam = vecop_mod.vaam;
pub const vasbm = vecop_mod.vasbm;
pub const vasm = vecop_mod.vasm;
pub const vsbm = vecop_mod.vsbm;
pub const vsbsbm = vecop_mod.vsbsbm;
pub const vsbsm = vecop_mod.vsbsm;
pub const vavlin = vecop_mod.vavlin;
pub const vpythg = vecop_mod.vpythg;
pub const vsq = vecop_mod.vsq;
pub const vssq = vecop_mod.vssq;
pub const vabs = vecop_mod.vabs;
pub const vneg = vecop_mod.vneg;
pub const vnabs = vecop_mod.vnabs;
pub const vfrac = vecop_mod.vfrac;
pub const vdist = vecop_mod.vdist;
pub const distancesq = vecop_mod.distancesq;
pub const zvadd = vecop_mod.zvadd;
pub const zrvadd = vecop_mod.zrvadd;
pub const zvsub = vecop_mod.zvsub;
pub const zrvsub = vecop_mod.zrvsub;
pub const zrvmul = vecop_mod.zrvmul;
pub const zvdiv = vecop_mod.zvdiv;
pub const zrvdiv = vecop_mod.zrvdiv;
pub const zvabs = vecop_mod.zvabs;
pub const zvfill = vecop_mod.zvfill;
pub const zvmul = vecop_mod.zvmul;
pub const zvcma = vecop_mod.zvcma;
pub const zvma = vecop_mod.zvma;
pub const zvcmul = vecop_mod.zvcmul;
pub const zvconj = vecop_mod.zvconj;
pub const zvzsml = vecop_mod.zvzsml;
pub const zvmags = vecop_mod.zvmags;
pub const zvmgsa = vecop_mod.zvmgsa;
pub const zvmov = vecop_mod.zvmov;
pub const zvneg = vecop_mod.zvneg;
pub const zvphas = vecop_mod.zvphas;
pub const zvsma = vecop_mod.zvsma;
pub const zaspec = vecop_mod.zaspec;
pub const zcoher = vecop_mod.zcoher;
pub const ztrans = vecop_mod.ztrans;
pub const zcspec = vecop_mod.zcspec;
pub const desamp = vecop_mod.desamp;
pub const zrdesamp = vecop_mod.zrdesamp;

// -- vaddsub --
const vaddsub_mod = @import("vaddsub.zig");
pub const vaddsub = vaddsub_mod.vaddsub;

// -- reduction --
const reduction_mod = @import("reduction.zig");
pub const sve = reduction_mod.sve;
pub const svesq = reduction_mod.svesq;
pub const sve_svesq = reduction_mod.sve_svesq;
pub const svemg = reduction_mod.svemg;
pub const meanv = reduction_mod.meanv;
pub const meamgv = reduction_mod.meamgv;
pub const measqv = reduction_mod.measqv;
pub const rmsqv = reduction_mod.rmsqv;
pub const maxv = reduction_mod.maxv;
pub const maxvi = reduction_mod.maxvi;
pub const maxmgv = reduction_mod.maxmgv;
pub const maxmgvi = reduction_mod.maxmgvi;
pub const minv = reduction_mod.minv;
pub const minvi = reduction_mod.minvi;
pub const minmgv = reduction_mod.minmgv;
pub const minmgvi = reduction_mod.minmgvi;
pub const normalize = reduction_mod.normalize;
pub const mmov = reduction_mod.mmov;
pub const mvessq = reduction_mod.mvessq;
pub const nzcros = reduction_mod.nzcros;
pub const svs = reduction_mod.svs;
pub const ValueIndex = reduction_mod.ValueIndex;
pub const NormResult = reduction_mod.NormResult;

// -- clip --
const clip_mod = @import("clip.zig");
pub const vclr = clip_mod.vclr;
pub const vcmprs = clip_mod.vcmprs;
pub const vclip = clip_mod.vclip;
pub const vclipc = clip_mod.vclipc;
pub const viclip = clip_mod.viclip;
pub const vthr = clip_mod.vthr;
pub const vthres = clip_mod.vthres;
pub const vlim = clip_mod.vlim;
pub const vmax = clip_mod.vmax;
pub const vmin = clip_mod.vmin;
pub const vmaxmg = clip_mod.vmaxmg;
pub const vminmg = clip_mod.vminmg;

// -- util --
const util_mod = @import("util.zig");
pub const vrvrs = util_mod.vrvrs;
pub const vswap = util_mod.vswap;
pub const vsort = util_mod.vsort;
pub const vsorti = util_mod.vsorti;
pub const vramp = util_mod.vramp;
pub const vgen = util_mod.vgen;
pub const vgathr = util_mod.vgathr;
pub const vindex = util_mod.vindex;
pub const vgathra = util_mod.vgathra;
pub const vthrsc = util_mod.vthrsc;
pub const vtabi = util_mod.vtabi;
pub const vtmerg = util_mod.vtmerg;
pub const wiener = util_mod.wiener;
pub const vlint = util_mod.vlint;
pub const vqint = util_mod.vqint;
pub const vintb = util_mod.vintb;
pub const vgenp = util_mod.vgenp;
pub const vpoly = util_mod.vpoly;
pub const vrsum = util_mod.vrsum;
pub const vsimps = util_mod.vsimps;
pub const vtrapz = util_mod.vtrapz;
pub const vswsum = util_mod.vswsum;
pub const vswmax = util_mod.vswmax;
pub const blkman_window = util_mod.blkman_window;
pub const hamm_window = util_mod.hamm_window;
pub const hann_window = util_mod.hann_window;

// -- matrix --
const matrix_mod = @import("matrix.zig");
pub const mmul = matrix_mod.mmul;
pub const mtrans = matrix_mod.mtrans;
pub const zmma = matrix_mod.zmma;
pub const zmms = matrix_mod.zmms;
pub const zmsm = matrix_mod.zmsm;
pub const zmmul = matrix_mod.zmmul;
pub const zvmmaa = matrix_mod.zvmmaa;

// -- conv --
const conv_mod = @import("conv.zig");
pub const conv = conv_mod.conv;
pub const imgfir = conv_mod.imgfir;
pub const f3x3 = conv_mod.f3x3;
pub const f5x5 = conv_mod.f5x5;
pub const deq22 = conv_mod.deq22;
pub const zconv = conv_mod.zconv;

// -- convert --
const convert_mod = @import("convert.zig");
pub const vdpsp = convert_mod.vdpsp;
pub const vspdp = convert_mod.vspdp;
pub const vflt8 = convert_mod.vflt8;
pub const vflt16 = convert_mod.vflt16;
pub const vflt32 = convert_mod.vflt32;
pub const vfltu8 = convert_mod.vfltu8;
pub const vfltu16 = convert_mod.vfltu16;
pub const vfltu32 = convert_mod.vfltu32;
pub const vflt24 = convert_mod.vflt24;
pub const vfltu24 = convert_mod.vfltu24;
pub const vfltsm24 = convert_mod.vfltsm24;
pub const vfltsmu24 = convert_mod.vfltsmu24;
pub const vsmfix24 = convert_mod.vsmfix24;
pub const vsmfixu24 = convert_mod.vsmfixu24;
pub const vfix8 = convert_mod.vfix8;
pub const vfix16 = convert_mod.vfix16;
pub const vfix32 = convert_mod.vfix32;
pub const vfixu8 = convert_mod.vfixu8;
pub const vfixu16 = convert_mod.vfixu16;
pub const vfixu32 = convert_mod.vfixu32;
pub const vfixr8 = convert_mod.vfixr8;
pub const vfixr16 = convert_mod.vfixr16;
pub const vfixr32 = convert_mod.vfixr32;
pub const vfixru8 = convert_mod.vfixru8;
pub const vfixru16 = convert_mod.vfixru16;
pub const vfixru32 = convert_mod.vfixru32;
pub const venvlp = convert_mod.venvlp;
pub const vdbcon = convert_mod.vdbcon;
pub const polar = convert_mod.polar;
pub const rect = convert_mod.rect;

// -- fft --
const fft_mod = @import("fft.zig");
pub const FFTSetup = fft_mod.FFTSetup;
pub const FFTSetupD = fft_mod.FFTSetupD;
pub const Direction = fft_mod.Direction;
pub const Radix = fft_mod.Radix;
pub const FFT = fft_mod.FFT;
pub const ctoz = fft_mod.ctoz;
pub const ztoc = fft_mod.ztoc;

// -- fixed_fft --
const fixed_fft_mod = @import("fixed_fft.zig");
pub const fft16_copv = fixed_fft_mod.fft16_copv;
pub const fft32_copv = fixed_fft_mod.fft32_copv;
pub const fft16_zopv = fixed_fft_mod.fft16_zopv;
pub const fft32_zopv = fixed_fft_mod.fft32_zopv;

// -- dft --
const dft_mod = @import("dft.zig");
pub const DFTSetup = dft_mod.DFTSetup;
pub const DFTSetupD = dft_mod.DFTSetupD;
pub const DFTInterleavedSetup = dft_mod.DFTInterleavedSetup;
pub const DFTInterleavedSetupD = dft_mod.DFTInterleavedSetupD;
pub const DCTType = dft_mod.DCTType;
pub const RealToComplex = dft_mod.RealToComplex;
pub const DFT = dft_mod.DFT;
pub const RealDFT = dft_mod.RealDFT;
pub const DCT = dft_mod.DCT;
pub const InterleavedDFT = dft_mod.InterleavedDFT;

// -- biquad --
const biquad_mod = @import("biquad.zig");
pub const BiquadSetup = biquad_mod.BiquadSetup;
pub const BiquadSetupD = biquad_mod.BiquadSetupD;
pub const BiquadmSetup = biquad_mod.BiquadmSetup;
pub const BiquadmSetupD = biquad_mod.BiquadmSetupD;
pub const Biquad = biquad_mod.Biquad;
pub const Biquadm = biquad_mod.Biquadm;

// -- ramp --
const ramp_mod = @import("ramp.zig");
pub const vrampmul = ramp_mod.vrampmul;
pub const vrampmuladd = ramp_mod.vrampmuladd;
pub const vrampmul2 = ramp_mod.vrampmul2;
pub const vrampmuladd2 = ramp_mod.vrampmuladd2;
pub const vrampmul_s1_15 = ramp_mod.vrampmul_s1_15;
pub const vrampmuladd_s1_15 = ramp_mod.vrampmuladd_s1_15;
pub const vrampmul2_s1_15 = ramp_mod.vrampmul2_s1_15;
pub const vrampmuladd2_s1_15 = ramp_mod.vrampmuladd2_s1_15;
pub const vrampmul_s8_24 = ramp_mod.vrampmul_s8_24;
pub const vrampmuladd_s8_24 = ramp_mod.vrampmuladd_s8_24;
pub const vrampmul2_s8_24 = ramp_mod.vrampmul2_s8_24;
pub const vrampmuladd2_s8_24 = ramp_mod.vrampmuladd2_s8_24;

test {
    const std = @import("std");
    std.testing.refAllDecls(@This());
}
