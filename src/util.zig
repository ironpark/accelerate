const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;
const SortOrder = types.SortOrder;
const WindowFlag = types.WindowFlag;

const c = struct {
    // -- Reverse / swap / sort --
    extern fn vDSP_vrvrs(C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vrvrsD(C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vswap(A: [*]f32, IA: Stride, B: [*]f32, IB: Stride, N: Length) void;
    extern fn vDSP_vswapD(A: [*]f64, IA: Stride, B: [*]f64, IB: Stride, N: Length) void;
    extern fn vDSP_vsort(C: [*]f32, N: Length, Order: c_int) void;
    extern fn vDSP_vsortD(C: [*]f64, N: Length, Order: c_int) void;
    extern fn vDSP_vsorti(C: [*]const f32, I: [*]Length, Temporary: ?[*]Length, N: Length, Order: c_int) void;
    extern fn vDSP_vsortiD(C: [*]const f64, I: [*]Length, Temporary: ?[*]Length, N: Length, Order: c_int) void;
    // -- Ramp / generate --
    extern fn vDSP_vramp(A: *const f32, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vrampD(A: *const f64, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vgen(A: *const f32, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vgenD(A: *const f64, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    // -- Gather / index --
    extern fn vDSP_vgathr(A: [*]const f32, B: [*]const Length, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vgathrD(A: [*]const f64, B: [*]const Length, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vindex(A: [*]const f32, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vindexD(A: [*]const f64, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vgathra(A: [*]const [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vgathraD(A: [*]const [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    // -- Threshold with signed constant --
    extern fn vDSP_vthrsc(A: [*]const f32, IA: Stride, B: *const f32, C_val: *const f32, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vthrscD(A: [*]const f64, IA: Stride, B: *const f64, C_val: *const f64, D: [*]f64, ID: Stride, N: Length) void;
    // -- Table lookup and interpolation --
    extern fn vDSP_vtabi(A: [*]const f32, IA: Stride, S1: *const f32, S2: *const f32, C: [*]const f32, M: Length, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vtabiD(A: [*]const f64, IA: Stride, S1: *const f64, S2: *const f64, C: [*]const f64, M: Length, D: [*]f64, ID: Stride, N: Length) void;
    // -- Tapered merge --
    extern fn vDSP_vtmerg(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vtmergD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length) void;
    // -- Wiener Levinson --
    extern fn vDSP_wiener(L: Length, A: [*]const f32, C: [*]const f32, F: [*]f32, P: [*]f32, Flag: c_int, Error: *c_int) void;
    extern fn vDSP_wienerD(L: Length, A: [*]const f64, C: [*]const f64, F: [*]f64, P: [*]f64, Flag: c_int, Error: *c_int) void;
    // -- Interpolation --
    extern fn vDSP_vgenp(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_vgenpD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_vlint(A: [*]const f32, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_vlintD(A: [*]const f64, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_vqint(A: [*]const f32, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_vqintD(A: [*]const f64, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, M: Length) void;
    extern fn vDSP_vintb(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: *const f32, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_vintbD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: *const f64, D: [*]f64, ID: Stride, N: Length) void;
    extern fn vDSP_vpoly(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C: [*]f32, IC: Stride, N: Length, P: Length) void;
    extern fn vDSP_vpolyD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C: [*]f64, IC: Stride, N: Length, P: Length) void;
    // -- Integration --
    extern fn vDSP_vrsum(A: [*]const f32, IA: Stride, S: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vrsumD(A: [*]const f64, IA: Stride, S: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vsimps(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vsimpsD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vtrapz(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vtrapzD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vswsum(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length, P: Length) void;
    extern fn vDSP_vswsumD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length, P: Length) void;
    extern fn vDSP_vswmax(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length, P: Length) void;
    extern fn vDSP_vswmaxD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length, P: Length) void;
    // -- Window functions --
    extern fn vDSP_blkman_window(C: [*]f32, N: Length, Flag: c_int) void;
    extern fn vDSP_blkman_windowD(C: [*]f64, N: Length, Flag: c_int) void;
    extern fn vDSP_hamm_window(C: [*]f32, N: Length, Flag: c_int) void;
    extern fn vDSP_hamm_windowD(C: [*]f64, N: Length, Flag: c_int) void;
    extern fn vDSP_hann_window(C: [*]f32, N: Length, Flag: c_int) void;
    extern fn vDSP_hann_windowD(C: [*]f64, N: Length, Flag: c_int) void;
};

// ============================================================================
// Reverse / swap / sort
// ============================================================================

pub fn vrvrs(buf: []f32) void {
    c.vDSP_vrvrs(buf.ptr, 1, buf.len);
}
pub fn vrvrsD(buf: []f64) void {
    c.vDSP_vrvrsD(buf.ptr, 1, buf.len);
}

pub fn vswap(a: []f32, b: []f32) void {
    c.vDSP_vswap(a.ptr, 1, b.ptr, 1, a.len);
}
pub fn vswapD(a: []f64, b: []f64) void {
    c.vDSP_vswapD(a.ptr, 1, b.ptr, 1, a.len);
}

pub fn vsort(buf: []f32, order: SortOrder) void {
    c.vDSP_vsort(buf.ptr, buf.len, @intFromEnum(order));
}
pub fn vsortD(buf: []f64, order: SortOrder) void {
    c.vDSP_vsortD(buf.ptr, buf.len, @intFromEnum(order));
}

pub fn vsorti(data: []const f32, indices: []Length, order: SortOrder) void {
    c.vDSP_vsorti(data.ptr, indices.ptr, null, data.len, @intFromEnum(order));
}
pub fn vsortiD(data: []const f64, indices: []Length, order: SortOrder) void {
    c.vDSP_vsortiD(data.ptr, indices.ptr, null, data.len, @intFromEnum(order));
}

// ============================================================================
// Ramp / generate
// ============================================================================

pub fn vramp(start: f32, step: f32, out: []f32) void {
    c.vDSP_vramp(&start, &step, out.ptr, 1, out.len);
}
pub fn vrampD(start: f64, step: f64, out: []f64) void {
    c.vDSP_vrampD(&start, &step, out.ptr, 1, out.len);
}

pub fn vgen(start: f32, end: f32, out: []f32) void {
    c.vDSP_vgen(&start, &end, out.ptr, 1, out.len);
}
pub fn vgenD(start: f64, end: f64, out: []f64) void {
    c.vDSP_vgenD(&start, &end, out.ptr, 1, out.len);
}

// ============================================================================
// Gather / index
// ============================================================================

pub fn vgathr(table: []const f32, indices: []const Length, out: []f32) void {
    c.vDSP_vgathr(table.ptr, indices.ptr, 1, out.ptr, 1, indices.len);
}
pub fn vgathrD(table: []const f64, indices: []const Length, out: []f64) void {
    c.vDSP_vgathrD(table.ptr, indices.ptr, 1, out.ptr, 1, indices.len);
}

pub fn vindex(table: []const f32, indices: []const f32, out: []f32) void {
    c.vDSP_vindex(table.ptr, indices.ptr, 1, out.ptr, 1, indices.len);
}
pub fn vindexD(table: []const f64, indices: []const f64, out: []f64) void {
    c.vDSP_vindexD(table.ptr, indices.ptr, 1, out.ptr, 1, indices.len);
}

pub fn vgathra(ptrs: [*]const [*]const f32, out: []f32) void {
    c.vDSP_vgathra(ptrs, 1, out.ptr, 1, out.len);
}
pub fn vgathraD(ptrs: [*]const [*]const f64, out: []f64) void {
    c.vDSP_vgathraD(ptrs, 1, out.ptr, 1, out.len);
}

// ============================================================================
// Threshold with signed constant
// ============================================================================

pub fn vthrsc(a: []const f32, threshold: f32, val: f32, out: []f32) void {
    c.vDSP_vthrsc(a.ptr, 1, &threshold, &val, out.ptr, 1, a.len);
}
pub fn vthrscD(a: []const f64, threshold: f64, val: f64, out: []f64) void {
    c.vDSP_vthrscD(a.ptr, 1, &threshold, &val, out.ptr, 1, a.len);
}

// ============================================================================
// Table lookup and interpolation
// ============================================================================

pub fn vtabi(a: []const f32, s1: f32, s2: f32, table: []const f32, out: []f32) void {
    c.vDSP_vtabi(a.ptr, 1, &s1, &s2, table.ptr, table.len, out.ptr, 1, a.len);
}
pub fn vtabiD(a: []const f64, s1: f64, s2: f64, table: []const f64, out: []f64) void {
    c.vDSP_vtabiD(a.ptr, 1, &s1, &s2, table.ptr, table.len, out.ptr, 1, a.len);
}

// ============================================================================
// Tapered merge
// ============================================================================

pub fn vtmerg(a: []const f32, b: []const f32, out: []f32) void {
    c.vDSP_vtmerg(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}
pub fn vtmergD(a: []const f64, b: []const f64, out: []f64) void {
    c.vDSP_vtmergD(a.ptr, 1, b.ptr, 1, out.ptr, 1, a.len);
}

// ============================================================================
// Wiener Levinson
// ============================================================================

pub fn wiener(l: Length, a: [*]const f32, corr: [*]const f32, filter: [*]f32, power: [*]f32, flag: c_int) c_int {
    var err: c_int = undefined;
    c.vDSP_wiener(l, a, corr, filter, power, flag, &err);
    return err;
}
pub fn wienerD(l: Length, a: [*]const f64, corr: [*]const f64, filter: [*]f64, power: [*]f64, flag: c_int) c_int {
    var err: c_int = undefined;
    c.vDSP_wienerD(l, a, corr, filter, power, flag, &err);
    return err;
}

// ============================================================================
// Interpolation
// ============================================================================

/// Linear interpolation from table using fractional indices
pub fn vlint(table: []const f32, indices: []const f32, out: []f32) void {
    c.vDSP_vlint(table.ptr, indices.ptr, 1, out.ptr, 1, out.len, table.len);
}
pub fn vlintD(table: []const f64, indices: []const f64, out: []f64) void {
    c.vDSP_vlintD(table.ptr, indices.ptr, 1, out.ptr, 1, out.len, table.len);
}

/// Quadratic interpolation from table using fractional indices
pub fn vqint(table: []const f32, indices: []const f32, out: []f32) void {
    c.vDSP_vqint(table.ptr, indices.ptr, 1, out.ptr, 1, out.len, table.len);
}
pub fn vqintD(table: []const f64, indices: []const f64, out: []f64) void {
    c.vDSP_vqintD(table.ptr, indices.ptr, 1, out.ptr, 1, out.len, table.len);
}

/// Interpolation between two vectors: D = A + t*(B-A)
pub fn vintb(a: []const f32, b: []const f32, t: f32, out: []f32) void {
    c.vDSP_vintb(a.ptr, 1, b.ptr, 1, &t, out.ptr, 1, a.len);
}
pub fn vintbD(a: []const f64, b: []const f64, t: f64, out: []f64) void {
    c.vDSP_vintbD(a.ptr, 1, b.ptr, 1, &t, out.ptr, 1, a.len);
}

/// Generate by extrapolation and interpolation
pub fn vgenp(values: []const f32, positions: []const f32, out: []f32) void {
    c.vDSP_vgenp(values.ptr, 1, positions.ptr, 1, out.ptr, 1, out.len, values.len);
}
pub fn vgenpD(values: []const f64, positions: []const f64, out: []f64) void {
    c.vDSP_vgenpD(values.ptr, 1, positions.ptr, 1, out.ptr, 1, out.len, values.len);
}

/// Evaluate polynomial: coefficients A, evaluation points B, results C
pub fn vpoly(coeffs: []const f32, points: []const f32, out: []f32) void {
    c.vDSP_vpoly(coeffs.ptr, 1, points.ptr, 1, out.ptr, 1, points.len, coeffs.len - 1);
}
pub fn vpolyD(coeffs: []const f64, points: []const f64, out: []f64) void {
    c.vDSP_vpolyD(coeffs.ptr, 1, points.ptr, 1, out.ptr, 1, points.len, coeffs.len - 1);
}

// ============================================================================
// Integration
// ============================================================================

pub fn vrsum(a: []const f32, scale: f32, out: []f32) void {
    c.vDSP_vrsum(a.ptr, 1, &scale, out.ptr, 1, a.len);
}
pub fn vrsumD(a: []const f64, scale: f64, out: []f64) void {
    c.vDSP_vrsumD(a.ptr, 1, &scale, out.ptr, 1, a.len);
}

pub fn vsimps(a: []const f32, step: f32, out: []f32) void {
    c.vDSP_vsimps(a.ptr, 1, &step, out.ptr, 1, a.len);
}
pub fn vsimpsD(a: []const f64, step: f64, out: []f64) void {
    c.vDSP_vsimpsD(a.ptr, 1, &step, out.ptr, 1, a.len);
}

pub fn vtrapz(a: []const f32, step: f32, out: []f32) void {
    c.vDSP_vtrapz(a.ptr, 1, &step, out.ptr, 1, a.len);
}
pub fn vtrapzD(a: []const f64, step: f64, out: []f64) void {
    c.vDSP_vtrapzD(a.ptr, 1, &step, out.ptr, 1, a.len);
}

pub fn vswsum(a: []const f32, out: []f32, window_len: Length) void {
    c.vDSP_vswsum(a.ptr, 1, out.ptr, 1, out.len, window_len);
}
pub fn vswsumD(a: []const f64, out: []f64, window_len: Length) void {
    c.vDSP_vswsumD(a.ptr, 1, out.ptr, 1, out.len, window_len);
}

pub fn vswmax(a: []const f32, out: []f32, window_len: Length) void {
    c.vDSP_vswmax(a.ptr, 1, out.ptr, 1, out.len, window_len);
}
pub fn vswmaxD(a: []const f64, out: []f64, window_len: Length) void {
    c.vDSP_vswmaxD(a.ptr, 1, out.ptr, 1, out.len, window_len);
}

// ============================================================================
// Window functions
// ============================================================================

pub fn blkman_window(out: []f32, flag: WindowFlag) void {
    c.vDSP_blkman_window(out.ptr, out.len, @intFromEnum(flag));
}
pub fn blkman_windowD(out: []f64, flag: WindowFlag) void {
    c.vDSP_blkman_windowD(out.ptr, out.len, @intFromEnum(flag));
}

pub fn hamm_window(out: []f32, flag: WindowFlag) void {
    c.vDSP_hamm_window(out.ptr, out.len, @intFromEnum(flag));
}
pub fn hamm_windowD(out: []f64, flag: WindowFlag) void {
    c.vDSP_hamm_windowD(out.ptr, out.len, @intFromEnum(flag));
}

pub fn hann_window(out: []f32, flag: WindowFlag) void {
    c.vDSP_hann_window(out.ptr, out.len, @intFromEnum(flag));
}
pub fn hann_windowD(out: []f64, flag: WindowFlag) void {
    c.vDSP_hann_windowD(out.ptr, out.len, @intFromEnum(flag));
}
