const std = @import("std");
const vdsp = @import("vdsp");

pub fn main() !void {
    const a = [_]f32{ 1.0, 2.0, 3.0, 4.0 };
    const b = [_]f32{ 5.0, 6.0, 7.0, 8.0 };

    // dot product
    const dot = vdsp.dotpr.dotpr(&a, &b);
    std.debug.print("dotpr: {d}\n", .{dot});

    // stereo dot product
    const dot2 = vdsp.dotpr.dotpr2(&a, &b, &[_]f32{ 1, 1, 1, 1 });
    std.debug.print("dotpr2: {d}, {d}\n", .{ dot2[0], dot2[1] });

    // sum
    const s = vdsp.reduction.sve(&a);
    std.debug.print("sum: {d}\n", .{s});

    // vector add
    var out: [4]f32 = undefined;
    vdsp.arithmetic.vadd(&a, &b, &out);
    std.debug.print("vadd: {any}\n", .{out});
}
