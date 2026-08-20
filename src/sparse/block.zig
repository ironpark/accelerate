//! A minimal Objective-C block, built by hand so Zig code can be passed where
//! Accelerate demands one.
//!
//! Every iterative solver in `Sparse/Solve.h` takes its operator as a
//! `_Nonnull` block:
//!
//! ```c
//! void (^ApplyOperator)(bool accumulate, enum CBLAS_TRANSPOSE trans,
//!                       DenseMatrix_Double X, DenseMatrix_Double Y)
//! ```
//!
//! There is no block-free entry point - the matrix-taking `SparseSolve`
//! overloads build the block inside the inline wrapper - so binding CG, GMRES
//! or LSMR at all requires producing one.
//!
//! Zig has no block syntax, but a block is not magic: it is a struct with a
//! layout fixed by libclosure's `Block_private.h`. This module reproduces that
//! layout, which is enough for a block that is *called* by C. (Creating a block
//! that C stores and invokes later would additionally need working copy and
//! dispose helpers; see the note on lifetime below.)
//!
//! ## Layout
//!
//! ```c
//! struct Block_layout {
//!     void *isa;
//!     volatile int32_t flags;
//!     int32_t reserved;
//!     void (*invoke)(void *, ...);
//!     struct Block_descriptor_1 *descriptor;
//!     // captured variables follow
//! };
//! struct Block_descriptor_1 { uintptr_t reserved; uintptr_t size; };
//! ```
//!
//! ## Lifetime
//!
//! The blocks here are stack blocks with no copy/dispose helpers, which is
//! correct precisely because the captured context is plain data and Accelerate
//! only invokes the operator for the duration of the solve call. `descriptor.size`
//! is set correctly, so even if Sparse were to `Block_copy` one, the copy would
//! be a faithful `memcpy`. Do not store one of these past the call that
//! received it.

const std = @import("std");

/// `struct Block_descriptor_1`. One per block type, not per instance.
pub const Descriptor = extern struct {
    reserved: usize = 0,
    /// Size of the whole block literal, captures included. libclosure uses
    /// this for `Block_copy`, so it must be right.
    size: usize,
};

/// libclosure's class for a block that still lives on the stack.
///
/// `_NSConcreteGlobalBlock` would be the alternative, but a global block is by
/// definition capture-free, and ours captures a context pointer.
extern var _NSConcreteStackBlock: anyopaque;

/// A block literal capturing a single `Context` value and invoking `Signature`.
///
/// `Signature` must be a `callconv(.c)` function type whose *first* parameter
/// is the block pointer itself - that is the block ABI's implicit `self`.
/// Recover the context inside with `contextOf`.
///
/// The literal is an `extern struct`, so `Context` must be extern-compatible.
/// To capture something richer, capture a pointer to it - the block only has
/// to outlive the call, so a pointer to a local in the calling frame is fine
/// and is what `iterative.zig` does.
pub fn Block(comptime Context: type, comptime Signature: type) type {
    return extern struct {
        const Self = @This();

        isa: *anyopaque,
        flags: i32,
        reserved: i32,
        invoke: *const Signature,
        descriptor: *const Descriptor,
        context: Context,

        /// Shared by every instance of this block type; only its `size` is
        /// read, and that is a property of the type.
        const descriptor_value: Descriptor = .{ .size = @sizeOf(Self) };

        /// Builds a block. The result must not outlive `context`.
        ///
        /// `flags` is zero: no copy/dispose helpers (the capture is plain
        /// data), and no signature string, which Accelerate does not ask for.
        pub fn init(invoke: *const Signature, context: Context) Self {
            return .{
                .isa = &_NSConcreteStackBlock,
                .flags = 0,
                .reserved = 0,
                .invoke = invoke,
                .descriptor = &descriptor_value,
                .context = context,
            };
        }

        /// Recovers the captured context from the block pointer C hands to
        /// `invoke` as its first argument.
        pub fn contextOf(block: *anyopaque) Context {
            const self: *const Self = @ptrCast(@alignCast(block));
            return self.context;
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

const testing = std.testing;

// Calls a block the way C does: through `invoke`, passing the block itself as
// the first argument. This is the contract Accelerate relies on, so exercising
// it here is a direct test of the layout rather than a proxy.
fn callThrough(block: anytype, a: i32, b: i32) i32 {
    const ptr: *anyopaque = @ptrCast(@constCast(block));
    return block.invoke(ptr, a, b);
}

const Adder = Block(i32, fn (*anyopaque, i32, i32) callconv(.c) i32);

fn addWithBias(blk: *anyopaque, a: i32, b: i32) callconv(.c) i32 {
    return a + b + Adder.contextOf(blk);
}

test "a hand-built block invokes and sees its captured context" {
    const b = Adder.init(&addWithBias, 100);
    try testing.expectEqual(@as(i32, 111), callThrough(&b, 4, 7));

    // A second instance with a different capture must not disturb the first.
    const c2 = Adder.init(&addWithBias, -5);
    try testing.expectEqual(@as(i32, 6), callThrough(&c2, 4, 7));
    try testing.expectEqual(@as(i32, 111), callThrough(&b, 4, 7));
}

test "the literal matches libclosure's Block_layout" {
    // isa(8) + flags(4) + reserved(4) + invoke(8) + descriptor(8) = 32 bytes
    // before any capture. Accelerate reads `invoke` and `descriptor` at those
    // offsets; getting them wrong would be a wild jump, not a compile error.
    try testing.expectEqual(@as(usize, 0), @offsetOf(Adder, "isa"));
    try testing.expectEqual(@as(usize, 8), @offsetOf(Adder, "flags"));
    try testing.expectEqual(@as(usize, 12), @offsetOf(Adder, "reserved"));
    try testing.expectEqual(@as(usize, 16), @offsetOf(Adder, "invoke"));
    try testing.expectEqual(@as(usize, 24), @offsetOf(Adder, "descriptor"));
    try testing.expectEqual(@as(usize, 32), @offsetOf(Adder, "context"));

    try testing.expectEqual(@as(usize, 16), @sizeOf(Descriptor));
    try testing.expectEqual(@as(usize, 0), @offsetOf(Descriptor, "reserved"));
    try testing.expectEqual(@as(usize, 8), @offsetOf(Descriptor, "size"));
}

test "descriptor.size covers the captures, so Block_copy would be faithful" {
    const Big = Block([4]u64, fn (*anyopaque) callconv(.c) void);
    const b = Big.init(&struct {
        fn f(_: *anyopaque) callconv(.c) void {}
    }.f, .{ 1, 2, 3, 4 });
    try testing.expectEqual(@sizeOf(Big), b.descriptor.size);
    try testing.expect(b.descriptor.size >= 32 + 4 * @sizeOf(u64));
}

test "isa points at the stack block class" {
    const b = Adder.init(&addWithBias, 0);
    try testing.expectEqual(@as(*anyopaque, @ptrCast(&_NSConcreteStackBlock)), b.isa);
    // Zero flags: no copy/dispose helpers and no signature string.
    try testing.expectEqual(@as(i32, 0), b.flags);
}

test "a pointer-capturing block reaches mutable state" {
    var total: i64 = 0;
    const Accum = Block(*i64, fn (*anyopaque, i64) callconv(.c) void);
    const b = Accum.init(&struct {
        fn f(blk: *anyopaque, v: i64) callconv(.c) void {
            Accum.contextOf(blk).* += v;
        }
    }.f, &total);

    const ptr: *anyopaque = @ptrCast(@constCast(&b));
    b.invoke(ptr, 5);
    b.invoke(ptr, 37);
    try testing.expectEqual(@as(i64, 42), total);
}
