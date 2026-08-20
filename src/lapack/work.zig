//! Workspace sizing for the 573 LAPACK routines that take an `lwork`.
//!
//! LAPACK will not allocate for you. Every blocked routine takes a caller-owned
//! scratch array plus its length, and asking for the right length is a call in
//! its own right: pass `lwork = -1` and the routine returns immediately, having
//! written the optimal size into `work[0]` and touched nothing else.
//!
//! Two details make this awkward enough to be worth a helper.
//!
//! The returned size arrives as a **float**, in the first element of the
//! floating-point workspace, and has to be rounded and cast back to `Int`. For
//! complex routines it arrives as a complex whose real part is the size.
//!
//! And the size is *optimal*, not *minimal*. Every such routine also documents a
//! minimum below which it fails with `info < 0`. Handing back the optimum is
//! right for performance, but a caller who wants to bound memory needs to know
//! the distinction exists, so `query` reports the optimum and the wrappers
//! document each routine's minimum.
//!
//! An undersized workspace is a clean `info < 0` failure, not corruption - that
//! is asserted below. A *null* workspace is not: the closest analogue in this
//! library, `sparse.Factorization.refactor`, hangs forever when handed one,
//! because the parameter is `_Nonnull` and nothing checks. That is why the
//! allocator-taking forms exist at all.

const std = @import("std");
const types = @import("types.zig");
const info_mod = @import("info.zig");

const Int = types.Int;
const Complex = types.Complex;

/// Reads an optimal `lwork` back out of the first workspace element.
///
/// The value is a float because LAPACK has nowhere else to put it: `work` is
/// the routine's floating-point scratch array, so the size travels in the same
/// type as the data.
pub fn sizeFrom(comptime T: type, work0: T) Int {
    const real = switch (T) {
        f32, f64 => work0,
        Complex(f32), Complex(f64) => work0.re,
        else => @compileError("not a LAPACK element type: " ++ @typeName(T)),
    };
    // Round rather than truncate. The value is integral in practice, but it
    // arrives through a float and truncating a 128 that arrived as 127.9999
    // would produce a workspace one element short - which LAPACK rejects with
    // info < 0 rather than tolerating.
    return @intFromFloat(@round(real));
}

/// Every `lwork` has a documented minimum; this is the sentinel that asks for
/// the optimum instead of supplying one.
pub const query: Int = -1;

/// The scratch buffers a LAPACK call needs, sized by a query and owned by the
/// caller's allocator.
///
/// Routines vary in which of these they want - `geqrf` needs only `work`,
/// `syevr` needs `work` and `iwork`, `heevr` needs all three - so the unused
/// ones stay empty rather than being allocated at length zero and passed.
pub fn Workspace(comptime T: type) type {
    return struct {
        const Self = @This();

        work: []T = &.{},
        rwork: []types.Real(T) = &.{},
        iwork: []Int = &.{},

        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn allocWork(self: *Self, n: Int) !void {
            self.work = try self.allocator.alloc(T, @intCast(@max(n, 1)));
        }

        pub fn allocRwork(self: *Self, n: Int) !void {
            self.rwork = try self.allocator.alloc(types.Real(T), @intCast(@max(n, 1)));
        }

        pub fn allocIwork(self: *Self, n: Int) !void {
            self.iwork = try self.allocator.alloc(Int, @intCast(@max(n, 1)));
        }

        pub fn deinit(self: *Self) void {
            if (self.work.len != 0) self.allocator.free(self.work);
            if (self.rwork.len != 0) self.allocator.free(self.rwork);
            if (self.iwork.len != 0) self.allocator.free(self.iwork);
            self.* = .{ .allocator = self.allocator };
        }
    };
}

/// Passes a scalar to the raw `c.zig` layer, which takes every argument by
/// pointer because LAPACK is Fortran.
pub fn ref(value: anytype) [*]const @TypeOf(value.*) {
    return @ptrCast(value);
}

/// Same, for an argument the routine writes to.
pub fn out(value: anytype) [*]@TypeOf(value.*) {
    return @ptrCast(value);
}

const c = @import("c.zig");

test "a workspace query reports a size without touching the matrix" {
    var a = [_]f64{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    const before = a;
    var tau: [4]f64 = undefined;
    var work: [1]f64 = .{-1};
    var info: Int = 0;
    const n: Int = 4;
    var lwork: Int = query;

    c.dgeqrf(ref(&n), ref(&n), &a, ref(&n), &tau, &work, ref(&lwork), out(&info));

    try info_mod.checkArgs(info);
    const optimal = sizeFrom(f64, work[0]);
    try std.testing.expect(optimal >= 4); // documented minimum is max(1, n)
    // The query must not have factored anything.
    try std.testing.expectEqualSlices(f64, &before, &a);

    // And the reported size must actually be accepted.
    lwork = optimal;
    const buf = try std.testing.allocator.alloc(f64, @intCast(optimal));
    defer std.testing.allocator.free(buf);
    c.dgeqrf(ref(&n), ref(&n), &a, ref(&n), &tau, buf.ptr, ref(&lwork), out(&info));
    try info_mod.checkArgs(info);
}

test "an undersized workspace fails cleanly rather than corrupting" {
    // This is the assumption the allocator-free `...WithWorkspace` forms rest
    // on: a caller who sizes their own buffer too small gets told, rather than
    // getting a wrong answer or a smashed stack.
    var a = [_]f64{ 4, 1, 1, 3 };
    var tau: [2]f64 = undefined;
    var work: [1]f64 = undefined;
    var info: Int = 0;
    const n: Int = 2;
    const too_small: Int = 0; // documented minimum is max(1, n) = 2

    c.dgeqrf(ref(&n), ref(&n), &a, ref(&n), &tau, &work, ref(&too_small), out(&info));

    try std.testing.expectError(error.InvalidArgument, info_mod.checkArgs(info));
    // Argument 7 is lwork.
    try std.testing.expectEqual(@as(Int, -7), info_mod.lastInfo());
}

test "sizeFrom rounds instead of truncating" {
    try std.testing.expectEqual(@as(Int, 128), sizeFrom(f64, 127.99999999));
    try std.testing.expectEqual(@as(Int, 128), sizeFrom(f32, 128.0));
    try std.testing.expectEqual(@as(Int, 64), sizeFrom(Complex(f32), .{ .re = 64, .im = 0 }));
}

test "Workspace allocates only what was asked for" {
    var ws = Workspace(f64).init(std.testing.allocator);
    defer ws.deinit();

    try ws.allocWork(32);
    try std.testing.expectEqual(@as(usize, 32), ws.work.len);
    try std.testing.expectEqual(@as(usize, 0), ws.rwork.len);
    try std.testing.expectEqual(@as(usize, 0), ws.iwork.len);

    // A zero-length request still yields one element: LAPACK dereferences work
    // even when it needs nothing, to write the query result there.
    var ws2 = Workspace(Complex(f32)).init(std.testing.allocator);
    defer ws2.deinit();
    try ws2.allocWork(0);
    try std.testing.expectEqual(@as(usize, 1), ws2.work.len);
    try ws2.allocRwork(0);
    try std.testing.expectEqual(f32, @TypeOf(ws2.rwork[0]));
}
