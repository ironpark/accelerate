const types = @import("types.zig");
const Stride = types.Stride;
const Length = types.Length;
const DbFlag = types.DbFlag;

const Int24 = extern struct { bytes: [3]u8 };
const UInt24 = extern struct { bytes: [3]u8 };

const c = struct {
    extern fn vDSP_vfix8(A: [*]const f32, IA: Stride, C: [*]i8, IC: Stride, N: Length) void;
    extern fn vDSP_vfix8D(A: [*]const f64, IA: Stride, C: [*]i8, IC: Stride, N: Length) void;
    extern fn vDSP_vfix16(A: [*]const f32, IA: Stride, C: [*]i16, IC: Stride, N: Length) void;
    extern fn vDSP_vfix16D(A: [*]const f64, IA: Stride, C: [*]i16, IC: Stride, N: Length) void;
    extern fn vDSP_vfix32(A: [*]const f32, IA: Stride, C: [*]i32, IC: Stride, N: Length) void;
    extern fn vDSP_vfix32D(A: [*]const f64, IA: Stride, C: [*]i32, IC: Stride, N: Length) void;
    extern fn vDSP_vfixu8(A: [*]const f32, IA: Stride, C: [*]u8, IC: Stride, N: Length) void;
    extern fn vDSP_vfixu8D(A: [*]const f64, IA: Stride, C: [*]u8, IC: Stride, N: Length) void;
    extern fn vDSP_vfixu16(A: [*]const f32, IA: Stride, C: [*]u16, IC: Stride, N: Length) void;
    extern fn vDSP_vfixu16D(A: [*]const f64, IA: Stride, C: [*]u16, IC: Stride, N: Length) void;
    extern fn vDSP_vfixu32(A: [*]const f32, IA: Stride, C: [*]u32, IC: Stride, N: Length) void;
    extern fn vDSP_vfixu32D(A: [*]const f64, IA: Stride, C: [*]u32, IC: Stride, N: Length) void;
    extern fn vDSP_vfixr8(A: [*]const f32, IA: Stride, C: [*]i8, IC: Stride, N: Length) void;
    extern fn vDSP_vfixr8D(A: [*]const f64, IA: Stride, C: [*]i8, IC: Stride, N: Length) void;
    extern fn vDSP_vfixr16(A: [*]const f32, IA: Stride, C: [*]i16, IC: Stride, N: Length) void;
    extern fn vDSP_vfixr16D(A: [*]const f64, IA: Stride, C: [*]i16, IC: Stride, N: Length) void;
    extern fn vDSP_vfixr32(A: [*]const f32, IA: Stride, C: [*]i32, IC: Stride, N: Length) void;
    extern fn vDSP_vfixr32D(A: [*]const f64, IA: Stride, C: [*]i32, IC: Stride, N: Length) void;
    extern fn vDSP_vfixru8(A: [*]const f32, IA: Stride, C: [*]u8, IC: Stride, N: Length) void;
    extern fn vDSP_vfixru8D(A: [*]const f64, IA: Stride, C: [*]u8, IC: Stride, N: Length) void;
    extern fn vDSP_vfixru16(A: [*]const f32, IA: Stride, C: [*]u16, IC: Stride, N: Length) void;
    extern fn vDSP_vfixru16D(A: [*]const f64, IA: Stride, C: [*]u16, IC: Stride, N: Length) void;
    extern fn vDSP_vfixru32(A: [*]const f32, IA: Stride, C: [*]u32, IC: Stride, N: Length) void;
    extern fn vDSP_vfixru32D(A: [*]const f64, IA: Stride, C: [*]u32, IC: Stride, N: Length) void;
    extern fn vDSP_vflt8(A: [*]const i8, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vflt8D(A: [*]const i8, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vflt16(A: [*]const i16, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vflt16D(A: [*]const i16, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vflt32(A: [*]const i32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vflt32D(A: [*]const i32, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vfltu8(A: [*]const u8, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vfltu8D(A: [*]const u8, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vfltu16(A: [*]const u16, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vfltu16D(A: [*]const u16, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vfltu32(A: [*]const u32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vfltu32D(A: [*]const u32, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vflt24(A: [*]const Int24, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vfltu24(A: [*]const UInt24, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vfltsm24(A: [*]const Int24, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vfltsmu24(A: [*]const UInt24, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vsmfix24(A: [*]const f32, IA: Stride, B: *const f32, C: [*]Int24, IC: Stride, N: Length) void;
    extern fn vDSP_vsmfixu24(A: [*]const f32, IA: Stride, B: *const f32, C: [*]UInt24, IC: Stride, N: Length) void;
    extern fn vDSP_vdpsp(A: [*]const f64, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_vspdp(A: [*]const f32, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_vdbcon(A: [*]const f32, IA: Stride, B: *const f32, C: [*]f32, IC: Stride, N: Length, F: c_uint) void;
    extern fn vDSP_vdbconD(A: [*]const f64, IA: Stride, B: *const f64, C: [*]f64, IC: Stride, N: Length, F: c_uint) void;
    extern fn vDSP_polar(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_polarD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_rect(A: [*]const f32, IA: Stride, C: [*]f32, IC: Stride, N: Length) void;
    extern fn vDSP_rectD(A: [*]const f64, IA: Stride, C: [*]f64, IC: Stride, N: Length) void;
    extern fn vDSP_venvlp(A: [*]const f32, IA: Stride, B: [*]const f32, IB: Stride, C_val: [*]const f32, IC: Stride, D: [*]f32, ID: Stride, N: Length) void;
    extern fn vDSP_venvlpD(A: [*]const f64, IA: Stride, B: [*]const f64, IB: Stride, C_val: [*]const f64, IC: Stride, D: [*]f64, ID: Stride, N: Length) void;
};

// -- Float precision conversion --

/// Vector double-precision to single-precision conversion.
pub fn vdpsp(a: []const f64, out: []f32) void {
    c.vDSP_vdpsp(a.ptr, 1, out.ptr, 1, a.len);
}
/// Vector single-precision to double-precision conversion.
pub fn vspdp(a: []const f32, out: []f64) void {
    c.vDSP_vspdp(a.ptr, 1, out.ptr, 1, a.len);
}

// -- Int to float --

/// Vector convert to floating-point from integer.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vflt8(comptime T: type, a: []const i8, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vflt8(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vflt8D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vflt8 requires f32 or f64"),
    }
}
/// Vector convert to floating-point from integer.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vflt16(comptime T: type, a: []const i16, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vflt16(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vflt16D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vflt16 requires f32 or f64"),
    }
}
/// Vector convert to floating-point from integer.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vflt32(comptime T: type, a: []const i32, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vflt32(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vflt32D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vflt32 requires f32 or f64"),
    }
}
/// Vector convert to floating-point from unsigned integer.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vfltu8(comptime T: type, a: []const u8, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vfltu8(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfltu8D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfltu8 requires f32 or f64"),
    }
}
/// Vector convert to floating-point from unsigned integer.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vfltu16(comptime T: type, a: []const u16, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vfltu16(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfltu16D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfltu16 requires f32 or f64"),
    }
}
/// Vector convert to floating-point from unsigned integer.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vfltu32(comptime T: type, a: []const u32, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vfltu32(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfltu32D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfltu32 requires f32 or f64"),
    }
}

// -- 24-bit int to float --

/// Vector convert 24-bit integer to single-precision float.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vflt24(a: [*]const Int24, out: [*]f32, n: Length) void {
    c.vDSP_vflt24(a, 1, out, 1, n);
}
/// Vector convert 24-bit unsigned integer to single-precision float.
///
///     for (n = 0; n < N; ++n)
///         C[n] = A[n];
pub fn vfltu24(a: [*]const UInt24, out: [*]f32, n: Length) void {
    c.vDSP_vfltu24(a, 1, out, 1, n);
}

// -- 24-bit int to float with scale --

/// Vector convert 24-bit integer to single-precision float and scale.
///
///     for (n = 0; n < N; ++n)
///         C[n] = B[0] * (float)A[n];
pub fn vfltsm24(a: [*]const Int24, scale: f32, out: [*]f32, n: Length) void {
    c.vDSP_vfltsm24(a, 1, &scale, out, 1, n);
}
/// Vector convert 24-bit unsigned integer to single-precision float and scale.
///
///     for (n = 0; n < N; ++n)
///         C[n] = B[0] * (float)A[n];
pub fn vfltsmu24(a: [*]const UInt24, scale: f32, out: [*]f32, n: Length) void {
    c.vDSP_vfltsmu24(a, 1, &scale, out, 1, n);
}

// -- Float to 24-bit int with scale --

/// Vector convert single precision to 24-bit signed integer with pre-scaling.
/// The scaled value is rounded toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n] * B[0]);
///
/// Note: Values outside the representable range are clamped to the largest
/// or smallest representable values of the destination type.
pub fn vsmfix24(a: [*]const f32, scale: f32, out: [*]Int24, n: Length) void {
    c.vDSP_vsmfix24(a, 1, &scale, out, 1, n);
}
/// Vector convert single precision to 24-bit unsigned integer with pre-scaling.
/// The scaled value is rounded toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n] * B[0]);
///
/// Note: Values outside the representable range are clamped to the largest
/// or smallest representable values of the destination type.
pub fn vsmfixu24(a: [*]const f32, scale: f32, out: [*]UInt24, n: Length) void {
    c.vDSP_vsmfixu24(a, 1, &scale, out, 1, n);
}

// -- Float to int (truncate toward zero) --

/// Vector convert to integer, round toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n]);
pub fn vfix8(comptime T: type, a: []const T, out: []i8) void {
    switch (T) {
        f32 => c.vDSP_vfix8(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfix8D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfix8 requires f32 or f64"),
    }
}
/// Vector convert to integer, round toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n]);
pub fn vfix16(comptime T: type, a: []const T, out: []i16) void {
    switch (T) {
        f32 => c.vDSP_vfix16(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfix16D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfix16 requires f32 or f64"),
    }
}
/// Vector convert to integer, round toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n]);
pub fn vfix32(comptime T: type, a: []const T, out: []i32) void {
    switch (T) {
        f32 => c.vDSP_vfix32(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfix32D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfix32 requires f32 or f64"),
    }
}

// -- Float to unsigned int (truncate toward zero) --

/// Vector convert to unsigned integer, round toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n]);
pub fn vfixu8(comptime T: type, a: []const T, out: []u8) void {
    switch (T) {
        f32 => c.vDSP_vfixu8(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixu8D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixu8 requires f32 or f64"),
    }
}
/// Vector convert to unsigned integer, round toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n]);
pub fn vfixu16(comptime T: type, a: []const T, out: []u16) void {
    switch (T) {
        f32 => c.vDSP_vfixu16(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixu16D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixu16 requires f32 or f64"),
    }
}
/// Vector convert to unsigned integer, round toward zero.
///
///     for (n = 0; n < N; ++n)
///         C[n] = trunc(A[n]);
pub fn vfixu32(comptime T: type, a: []const T, out: []u32) void {
    switch (T) {
        f32 => c.vDSP_vfixu32(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixu32D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixu32 requires f32 or f64"),
    }
}

// -- Float to int (round to nearest) --

/// Vector convert to integer, round to nearest.
///
///     for (n = 0; n < N; ++n)
///         C[n] = rint(A[n]);
///
/// Note: It is expected that the global rounding mode be the default,
/// round-to-nearest. It is unspecified whether ties round up or down.
pub fn vfixr8(comptime T: type, a: []const T, out: []i8) void {
    switch (T) {
        f32 => c.vDSP_vfixr8(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixr8D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixr8 requires f32 or f64"),
    }
}
/// Vector convert to integer, round to nearest.
///
///     for (n = 0; n < N; ++n)
///         C[n] = rint(A[n]);
///
/// Note: It is expected that the global rounding mode be the default,
/// round-to-nearest. It is unspecified whether ties round up or down.
pub fn vfixr16(comptime T: type, a: []const T, out: []i16) void {
    switch (T) {
        f32 => c.vDSP_vfixr16(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixr16D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixr16 requires f32 or f64"),
    }
}
/// Vector convert to integer, round to nearest.
///
///     for (n = 0; n < N; ++n)
///         C[n] = rint(A[n]);
///
/// Note: It is expected that the global rounding mode be the default,
/// round-to-nearest. It is unspecified whether ties round up or down.
pub fn vfixr32(comptime T: type, a: []const T, out: []i32) void {
    switch (T) {
        f32 => c.vDSP_vfixr32(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixr32D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixr32 requires f32 or f64"),
    }
}

// -- Float to unsigned int (round to nearest) --

/// Vector convert to unsigned integer, round to nearest.
///
///     for (n = 0; n < N; ++n)
///         C[n] = rint(A[n]);
///
/// Note: It is expected that the global rounding mode be the default,
/// round-to-nearest. It is unspecified whether ties round up or down.
pub fn vfixru8(comptime T: type, a: []const T, out: []u8) void {
    switch (T) {
        f32 => c.vDSP_vfixru8(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixru8D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixru8 requires f32 or f64"),
    }
}
/// Vector convert to unsigned integer, round to nearest.
///
///     for (n = 0; n < N; ++n)
///         C[n] = rint(A[n]);
///
/// Note: It is expected that the global rounding mode be the default,
/// round-to-nearest. It is unspecified whether ties round up or down.
pub fn vfixru16(comptime T: type, a: []const T, out: []u16) void {
    switch (T) {
        f32 => c.vDSP_vfixru16(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixru16D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixru16 requires f32 or f64"),
    }
}
/// Vector convert to unsigned integer, round to nearest.
///
///     for (n = 0; n < N; ++n)
///         C[n] = rint(A[n]);
///
/// Note: It is expected that the global rounding mode be the default,
/// round-to-nearest. It is unspecified whether ties round up or down.
pub fn vfixru32(comptime T: type, a: []const T, out: []u32) void {
    switch (T) {
        f32 => c.vDSP_vfixru32(a.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_vfixru32D(a.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("vfixru32 requires f32 or f64"),
    }
}

// -- Vector envelope --

/// Vector envelope.
///
///     for (n = 0; n < N; ++n)
///     {
///         if (C[n] < B[n] || A[n] < C[n]) D[n] = C[n];
///         else D[n] = 0;
///     }
pub fn venvlp(comptime T: type, a: []const T, b: []const T, cv: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_venvlp(a.ptr, 1, b.ptr, 1, cv.ptr, 1, out.ptr, 1, a.len),
        f64 => c.vDSP_venvlpD(a.ptr, 1, b.ptr, 1, cv.ptr, 1, out.ptr, 1, a.len),
        else => @compileError("venvlp requires f32 or f64"),
    }
}

// -- Decibel conversion --

/// Vector convert to decibels, power, or amplitude.
///
///     If Flag is 1:
///         alpha = 20;
///     If Flag is 0:
///         alpha = 10;
///
///     for (n = 0; n < N; ++n)
///         C[n] = alpha * log10(A[n] / B[0]);
pub fn vdbcon(comptime T: type, a: []const T, zero_ref: T, flag: DbFlag, out: []T) void {
    switch (T) {
        f32 => c.vDSP_vdbcon(a.ptr, 1, &zero_ref, out.ptr, 1, a.len, @intFromEnum(flag)),
        f64 => c.vDSP_vdbconD(a.ptr, 1, &zero_ref, out.ptr, 1, a.len, @intFromEnum(flag)),
        else => @compileError("vdbcon requires f32 or f64"),
    }
}

// -- Polar / Rect (interleaved pairs) --

pub fn polar(comptime T: type, rect_pairs: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_polar(rect_pairs.ptr, 2, out.ptr, 2, rect_pairs.len / 2),
        f64 => c.vDSP_polarD(rect_pairs.ptr, 2, out.ptr, 2, rect_pairs.len / 2),
        else => @compileError("polar requires f32 or f64"),
    }
}

pub fn rect(comptime T: type, polar_pairs: []const T, out: []T) void {
    switch (T) {
        f32 => c.vDSP_rect(polar_pairs.ptr, 2, out.ptr, 2, polar_pairs.len / 2),
        f64 => c.vDSP_rectD(polar_pairs.ptr, 2, out.ptr, 2, polar_pairs.len / 2),
        else => @compileError("rect requires f32 or f64"),
    }
}
