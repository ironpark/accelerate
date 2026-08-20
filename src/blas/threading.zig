//! Threading control for BLAS and LAPACK (`vecLib/thread_api.h`).
//!
//! Accelerate decides on its own how many threads to give a BLAS or LAPACK
//! call. These two entry points let a caller force single-threaded execution
//! instead - the usual reason being that the caller is already parallel and
//! wants to own the machine's cores itself, rather than have Accelerate
//! oversubscribe them from inside each of its own worker threads.
//!
//! **The setting is per-thread.** It lives in a thread-local inside vecLib, so
//! changing it on one thread says nothing about any other, and a thread you
//! spawn starts from the default rather than inheriting yours. That makes
//! `setThreading` safe to call from a worker without coordinating with the
//! rest of the program, and it makes "set it once at startup" not work.
//!
//! Available on macOS 15.0, iOS 18.0, watchOS 11.0 and tvOS 18.0 and later.
//! There is no runtime feature check here: on an older system the symbols are
//! simply absent and the program fails to launch, the same as for any other
//! Accelerate entry point this package binds.

const std = @import("std");
const c = @import("c.zig");

/// The threading model vecLib uses for subsequent BLAS and LAPACK calls on
/// the current thread. Mirrors `enum BLAS_THREADING`.
pub const Threading = enum(c_uint) {
    /// Accelerate decides how many threads to use. The default.
    multi_threaded = 0,
    /// Run on the calling thread only.
    single_threaded = 1,
};

/// Set the threading model for subsequent BLAS and LAPACK calls on the
/// **current thread**.
///
/// Returns `error.ThreadingUnsupported` if the platform does not support the
/// requested model - the C function's documented `-1` return. Note that this
/// is a per-platform capability answer, not a per-call failure: if it says no
/// once it will say no every time.
pub fn setThreading(threading: Threading) error{ThreadingUnsupported}!void {
    if (c.BLASSetThreading(@intFromEnum(threading)) != 0) return error.ThreadingUnsupported;
}

/// The threading model currently selected on the **current thread**.
pub fn getThreading() Threading {
    const raw = c.BLASGetThreading();
    return switch (raw) {
        0 => .multi_threaded,
        1 => .single_threaded,
        // `BLAS_THREADING_MAX_OPTIONS` is 2 in the SDK this binds, so every
        // value the enum can hold is covered. A future vecLib that adds a
        // third model would land here rather than be silently mistranslated.
        else => unreachable,
    };
}

test "the default is multi-threaded and set/get round-trips" {
    const initial = getThreading();
    try std.testing.expectEqual(Threading.multi_threaded, initial);

    try setThreading(.single_threaded);
    try std.testing.expectEqual(Threading.single_threaded, getThreading());

    try setThreading(.multi_threaded);
    try std.testing.expectEqual(Threading.multi_threaded, getThreading());
}

test "single-threaded BLAS computes the same answer as multi-threaded" {
    // The point of the flag is scheduling, not arithmetic. This is a
    // characterization test: it pins that switching models does not change
    // the result of a routine large enough for Accelerate to want to thread
    // it, and it double-checks that the flag does not simply make calls fail.
    const level3 = @import("level3.zig");
    const n = 64;

    var a: [n * n]f64 = undefined;
    var b: [n * n]f64 = undefined;
    for (0..n * n) |i| {
        const f: f64 = @floatFromInt(i % 17);
        a[i] = f * 0.5 - 3.0;
        b[i] = 2.0 - f * 0.25;
    }

    var multi = [_]f64{0} ** (n * n);
    try setThreading(.multi_threaded);
    level3.gemm(f64, .row_major, .no_trans, .no_trans, n, n, n, 1, &a, n, &b, n, 0, &multi, n);

    var single = [_]f64{0} ** (n * n);
    try setThreading(.single_threaded);
    level3.gemm(f64, .row_major, .no_trans, .no_trans, n, n, n, 1, &a, n, &b, n, 0, &single, n);

    try setThreading(.multi_threaded);
    try std.testing.expectEqualSlices(f64, &multi, &single);
}
