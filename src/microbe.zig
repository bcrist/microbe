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
    const scope_name = if (std.mem.eql(u8, @tagName(scope), "default")) "" else @tagName(scope);
    const level_prefix = switch (message_level) {
        .err =>   "E",
        .warn =>  "W",
        .info =>  "I",
        .debug => "D",
    };
    root.debug_uart.writer().print(level_prefix ++ "{: <11} {s}: ", .{
        @intFromEnum(timing.Tick.now()),
        scope_name,
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

pub fn defaultPanic(message: []const u8, trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @setCold(true);

    std.log.err("PANIC: {s}", .{message});
    dumpTrace(trace);

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

fn dumpTrace(trace: ?*std.builtin.StackTrace) void {
    if (trace) |stack_trace| {
        var frame_index: usize = 0;
        var frames_left: usize = @min(stack_trace.index, stack_trace.instruction_addresses.len);

        while (frames_left != 0) : ({
            frames_left -= 1;
            frame_index = (frame_index + 1) % stack_trace.instruction_addresses.len;
        }) {
            const return_address = stack_trace.instruction_addresses[frame_index];
            std.log.err("{d: >3}: 0x{X:0>8}", .{ frame_index, return_address - 1 });
        }

        if (stack_trace.index > stack_trace.instruction_addresses.len) {
            const dropped_frames = stack_trace.index - stack_trace.instruction_addresses.len;
            std.log.err("({d} additional stack frames skipped...)", .{dropped_frames});
        }
    } else {
        var index: usize = 0;
        var iter = std.debug.StackIterator.init(@returnAddress(), null);
        while (iter.next()) |address| : (index += 1) {
            if (index == 0) {
                std.log.err("stack trace:", .{});
            }
            std.log.err("{d: >3}: 0x{X:0>8}", .{ index, address });
        }
    }
}
