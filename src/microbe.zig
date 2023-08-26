const std = @import("std");
const builtin = @import("builtin");
const root = @import("root");

pub const Mmio = @import("mmio.zig").Mmio;
const clocks = @import("clocks.zig");
pub const Tick = clocks.Tick;
pub const Microtick = clocks.Microtick;
pub const CriticalSection = @import("CriticalSection.zig");
pub const pads = @import("pads.zig");
pub const dma = @import("dma.zig");
pub const bus = @import("bus.zig");
pub const uart = @import("uart.zig");
pub const jtag = @import("jtag.zig");

pub fn defaultLog(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = message_level;
    _ = scope;
    _ = format;
    _ = args;
}

pub fn defaultPanic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @setCold(true);

    std.log.err("microbe PANIC: {s}", .{message});

    if (builtin.cpu.arch != .avr) {
        var index: usize = 0;
        var iter = std.debug.StackIterator.init(@returnAddress(), null);
        while (iter.next()) |address| : (index += 1) {
            if (index == 0) {
                std.log.err("stack trace:", .{});
            }
            std.log.err("{d: >3}: 0x{X:0>8}", .{ index, address });
        }
    }
    if (@import("builtin").mode == .Debug) {
        // attach a breakpoint, this might trigger another
        // panic internally, so only do that in debug mode.
        std.log.info("triggering breakpoint...", .{});
        @breakpoint();
    }
    hang();
}

pub fn hang() noreturn {
    while (true) {
        // "this loop has side effects, don't optimize the endless loop away please. thanks!"
        asm volatile ("" ::: "memory");
    }
}
