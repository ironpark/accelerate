//! Every code sample in `README.md`, as code the build actually compiles.
//!
//! `zig build test` compiles this file against the package, both with and
//! without `-Dcoregraphics`. Nothing here runs — the point is only that a
//! sample cannot go stale without the build going red. Three README examples
//! were already wrong when this file was added: a function name that never
//! existed, a missing `comptime T`, and a `dilate` call with the wrong
//! arity.
//!
//! Keep the snippets in `README.md` copied from here, not the other way
//! round.

const std = @import("std");
const accelerate = @import("accelerate");

const vdsp = accelerate.vdsp;
const vforce = accelerate.vforce;
const vimage = accelerate.vimage;
const sparse = accelerate.sparse;
const quadrature = accelerate.quadrature;
const blas = accelerate.blas;

// ============================================================================
// vDSP
// ============================================================================

pub fn vdspExample() !void {
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const b = [_]f32{ 5.0, 6.0, 7.0, 8.0 };
    var out: [4]f32 = undefined;
    vdsp.vadd(f32, &a, &b, &out);
    // out = { 6.0, 8.0, 10.0, 12.0 }

    const dot = vdsp.dotpr(f32, &a, &b);
    const s = vdsp.sve(f32, &a);
    _ = dot;
    _ = s;

    // An 8-point complex FFT, in place. `SplitSlice` carries the length of
    // both component buffers, so the transform size cannot disagree with the
    // storage.
    var realp = [_]f32{ 1, 2, 3, 4, 5, 6, 7, 8 };
    var imagp = [_]f32{0} ** 8;
    const io = vdsp.SplitSlice(f32).init(&realp, &imagp);

    var fft = try vdsp.FFT(f32).init(3, .radix2);
    defer fft.deinit();
    fft.zip(io, .forward);
    fft.zip(io, .inverse);

    // Accelerate's FFT is unnormalised; the round trip scales by 2^log2n.
    vdsp.vsmul(f32, io.realp, 1.0 / fft.roundTripScale(), io.realp);
}

// ============================================================================
// vForce
// ============================================================================

pub fn vforceExample() void {
    const x = [_]f32{ 1.0, 4.0, 9.0 };
    var out: [3]f32 = undefined;

    vforce.sqrt(f32, &x, &out);
    // out = { 1.0, 2.0, 3.0 }
    vforce.exp(f32, &x, &out);
    vforce.sin(f32, &x, &out);
    vforce.cos(f32, &x, &out);

    var sin_out: [3]f32 = undefined;
    var cos_out: [3]f32 = undefined;
    vforce.sincos(f32, &x, &sin_out, &cos_out);

    vforce.tanh(f32, &x, &out);
}

// ============================================================================
// vImage
// ============================================================================

pub fn vimageExample(top: *anyopaque, bottom: *anyopaque, out: *anyopaque, h: usize, w: usize) !void {
    const src = vimage.vImage_Buffer{ .data = top, .height = h, .width = w, .rowBytes = w * 4 };
    const back = vimage.vImage_Buffer{ .data = bottom, .height = h, .width = w, .rowBytes = w * 4 };
    const dst = vimage.vImage_Buffer{ .data = out, .height = h, .width = w, .rowBytes = w * 4 };

    // The pixel type is a comptime parameter, so one wrapper covers the 8-bit
    // and float variants.
    _ = try vimage.alpha.premultipliedAlphaBlendARGB(u8, &src, &back, &dst, .{});

    // Flags are a packed struct, not an integer to hand-OR. It cannot express
    // a bit vImage does not define -- and kvImageUnknownFlagsBit is a real
    // error vImage returns.
    _ = try vimage.geometry.scale(u8, &src, &dst, null, .{
        .high_quality_resampling = true,
        .edge_extend = true,
    });

    // vImage reports a scratch-buffer size through the same slot it reports
    // errors in, so the success test is `>= 0`, not `== 0`. With
    // `.get_temp_buffer_size` the return value is that size; otherwise it is 0.
    const kernel = [_]u8{0} ** 9;
    const scratch = try vimage.morphology.dilate(u8, &src, &dst, 0, 0, &kernel, 3, 3, .{
        .get_temp_buffer_size = true,
    });
    _ = scratch;
}

// ============================================================================
// vImage <-> CoreGraphics / CoreVideo  (-Dcoregraphics=true)
// ============================================================================

pub fn cgExample(buf: *const vimage.vImage_Buffer) !void {
    if (comptime !vimage.utilities.enabled) return;

    const cg = accelerate.cg;
    const utilities = vimage.utilities;

    var space = try cg.ColorSpace.initNamed(cg.ColorSpaceName.srgb());
    defer space.deinit();

    // Wrap a buffer in a CGImage. The pixel data is copied by default.
    const fmt = utilities.CGImageFormat.argb8888(space.ref);
    var image = try utilities.createCGImageFromBuffer(buf, &fmt, null, null, .{});
    defer image.deinit();

    // ...and decode one back out, in whatever format you ask for.
    var dst_fmt = utilities.CGImageFormat.bgra8888(space.ref);
    var dst: vimage.vImage_Buffer = undefined;
    try utilities.bufferInitWithCGImage(&dst, &dst_fmt, null, image.ref, .{});
    defer utilities.bufferFree(&dst);

    // vImageConvert_AnyToAny: one object converts between any two describable
    // formats, colour-space changes included.
    var conv = try utilities.Converter.initWithCGImageFormat(&fmt, &dst_fmt, null, .{});
    defer conv.deinit();
    _ = try conv.convert(&.{buf.*}, &.{dst}, null, .{});
}

pub fn cvExample(argb_source: *const vimage.vImage_Buffer) !void {
    if (comptime !vimage.cv.enabled) return;

    const cg = accelerate.cg;
    const cv = accelerate.cv;

    var space = try cg.ColorSpace.initNamed(cg.ColorSpaceName.srgb());
    defer space.deinit();
    const fmt = vimage.utilities.CGImageFormat.argb8888(space.ref);

    var pb = try cv.PixelBuffer.init(1920, 1080, .ycbcr420_biplanar_video);
    defer pb.deinit();

    var cv_fmt = try vimage.cv.CVImageFormat.initWithCVPixelBuffer(pb.ref);
    defer cv_fmt.deinit();
    try cv_fmt.setColorSpace(space.ref);
    try cv_fmt.setConversionMatrix(.{ .argb_to_ypcbcr = vimage.conversion.ycbcr.argbToYpCbCrMatrix601() });
    try cv_fmt.setChromaSiting(cv.ChromaLocation.center());

    var encoder = try vimage.cv.converterForCGToCVImageFormat(&fmt, cv_fmt, &.{ 0, 0, 0 }, .{});
    defer encoder.deinit();

    // `.do_not_allocate` (kvImageNoAllocate) points the vImage buffers straight
    // at the pixel buffer's own planes, so the conversion writes into it with
    // no extra copy.
    var planes: [2]vimage.vImage_Buffer = undefined;
    try pb.lock(0);
    defer pb.unlock(0) catch {};
    try vimage.cv.bufferInitForCopyToCVPixelBuffer(&planes, encoder, pb.ref, .{ .do_not_allocate = true });
    _ = try encoder.convert(&.{argb_source.*}, &planes, null, .{});
}

// ============================================================================
// BLAS
// ============================================================================

pub fn blasExample() void {
    const a = [_]f64{ 1, 2, 3, 4 };
    const b = [_]f64{ 5, 6, 7, 8 };
    var c = [_]f64{ 0, 0, 0, 0 };
    blas.gemm(f64, .row_major, .no_trans, .no_trans, 2, 2, 2, 1, &a, 2, &b, 2, 0, &c, 2);
    // c = { 19, 22, 43, 50 }

    const x = [_]f64{ 3, 4 };
    var y = [_]f64{ 0, 0, 0, 0 };
    const n = blas.nrm2(f64, &x); // 5
    _ = n;
    blas.axpy(f64, 2.0, &x, y[0..2]); // y := 2x + y
    blas.axpyStrided(f64, 2, 2.0, &x, 1, &y, 2); // every other element of y

    const Z = blas.Complex(f64);
    const z = [_]Z{ .init(1, 2), .init(3, -1) };
    const inner = blas.dotc(Z, &z, &z); // real, = ||z||^2
    _ = inner;
}

// ============================================================================
// Quadrature
// ============================================================================

fn gaussian(_: void, x: f64) f64 {
    return @exp(-x * x);
}

fn batched(_: void, x: []const f64, y: []f64) void {
    vforce.exp(f64, x, y);
}

pub fn quadratureExample(allocator: std.mem.Allocator) !void {
    const inf = std.math.inf(f64);

    // Integrates to sqrt(pi) over the whole real line.
    const r = try quadrature.integrateScalar(void, {}, gaussian, -inf, inf, .{
        .integrator = .{ .qags = .{} },
        .abs_tolerance = 1e-12,
    }, allocator);
    _ = r.value;
    _ = r.abs_error;
    _ = r.status;

    // The array form is the one Accelerate actually calls; use it to vectorize.
    _ = try quadrature.integrate(void, {}, batched, 0, 1, .{}, allocator);
}

// ============================================================================
// Sparse
// ============================================================================

pub fn sparseExample(allocator: std.mem.Allocator) !void {
    // Lower triangle of a symmetric positive-definite matrix, in CSC.
    const starts = [_]c_long{ 0, 2, 4, 6, 7 };
    const rows = [_]c_int{ 0, 1, 1, 2, 2, 3, 3 };
    const vals = [_]f64{ 2, 1, 3, 1, 4, 1, 5 };
    const a = sparse.Sparse(f64).init(4, 4, &starts, &rows, &vals, .{
        .attributes = .{ .kind = .symmetric, .triangle = .lower },
    });

    var f = try sparse.Factorization(f64).init(.cholesky, a, .{});
    defer f.deinit();

    var b = [_]f64{ 4, 10, 18, 23 };
    var x = [_]f64{ 0, 0, 0, 0 };
    try f.solve(allocator, &b, &x);
    // x = { 1, 2, 3, 4 }

    // Iterative, for when a factorization is too big to store.
    const status = try sparse.Iterative(f64).conjugateGradient(
        a,
        sparse.Dense(f64).fromSlice(&b),
        sparse.Dense(f64).fromSlice(&x),
        .{ .rtol = 1e-12 },
        null,
    );
    _ = status;
}

test {
    // Without this the functions above are never referenced, so Zig never
    // analyses their bodies and the file compiles no matter what it says.
    // Every declaration here is a top-level function, so one level is enough.
    std.testing.refAllDecls(@This());
}
