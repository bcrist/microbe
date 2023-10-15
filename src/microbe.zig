const std = @import("std");
const root = @import("root");
const builtin = @import("builtin");
const config = @import("config");

pub const util = @import("util.zig");
pub const Mmio = @import("mmio.zig").Mmio;
const timing = @import("timing.zig");
pub const Tick = timing.Tick;
pub const Microtick = timing.Microtick;
pub const CriticalSection = @import("CriticalSection.zig");
pub const bus = @import("bus.zig");
pub const usb = @import("usb.zig");
pub const jtag = @import("jtag.zig");

const validation = @import("resource_validation.zig");
pub const RuntimeResourceValidator = if (config.runtime_resource_validation)
    validation.RuntimeResourceValidator else validation.NullResourceValidator;
pub const ComptimeResourceValidator = validation.ComptimeResourceValidator;

fn defaultLogPrefix(comptime message_level: std.log.Level, comptime scope: @Type(.EnumLiteral)) void {
    root.debug_uart.writer().print("[{s}] @{} {s}: ", .{
        message_level.asText(),
        @intFromEnum(timing.Tick.now()),
        @tagName(scope),
    }) catch unreachable;
}

pub fn defaultLog(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@hasDecl(root, "debug_uart")) {
        defaultLogPrefix(message_level, scope);
        var writer = root.debug_uart.writer();
        writer.print(format, args) catch unreachable;
        writer.writeByte('\n') catch unreachable;
    }
}

pub fn defaultPanic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @setCold(true);

    std.log.err("PANIC: {s}", .{message});

    var index: usize = 0;
    var iter = std.debug.StackIterator.init(@returnAddress(), null);
    while (iter.next()) |address| : (index += 1) {
        if (index == 0) {
            std.log.err("stack trace:", .{});
        }
        std.log.err("{d: >3}: 0x{X:0>8}", .{ index, address });
    }
    if (@import("builtin").mode == .Debug) {
        // attach a breakpoint, this might trigger another
        // panic internally, so only do that in debug mode.
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
