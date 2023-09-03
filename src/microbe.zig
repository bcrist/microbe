const std = @import("std");
const builtin = @import("builtin");
const root = @import("root");

pub const Mmio = @import("mmio.zig").Mmio;
const timing = @import("timing.zig");
pub const Tick = timing.Tick;
pub const Microtick = timing.Microtick;
pub const CriticalSection = @import("CriticalSection.zig");
pub const bus = @import("bus.zig");
pub const uart = @import("uart.zig");
pub const jtag = @import("jtag.zig");

const validation = @import("resource_validation.zig");
pub const RuntimeResourceValidator = if (root.config.runtime_resource_validation)
    validation.RuntimeResourceValidator else validation.NullResourceValidator;
pub const ComptimeResourceValidator = validation.ComptimeResourceValidator;

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
