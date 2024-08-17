pub const util = @import("util.zig");
pub const MMIO = @import("mmio.zig").MMIO;
const timing = @import("timing.zig");
pub const Tick = timing.Tick;
pub const Microtick = timing.Microtick;
pub const Critical_Section = @import("Critical_Section.zig");
pub const bus = @import("bus.zig");
pub const Bus = bus.Bus;
pub const usb = @import("usb.zig");
pub const USB = usb.USB;
pub const jtag = @import("jtag.zig");

const validation = @import("resource_validation.zig");
pub const Runtime_Resource_Validator = if (config.runtime_resource_validation)
    validation.Runtime_Resource_Validator else validation.Null_Resource_Validator;
pub const Bitset_Resource_Validator = validation.Bitset_Resource_Validator;

fn default_log_prefix(comptime message_level: std.log.Level, comptime scope: @Type(.EnumLiteral), writer: anytype) void {
    const scope_name = if (std.mem.eql(u8, @tagName(scope), "default")) "" else @tagName(scope);
    const level_prefix = switch (message_level) {
        .err =>   "E",
        .warn =>  "W",
        .info =>  "I",
        .debug => "D",
    };
    writer.print(level_prefix ++ "{: <11} {s}: ", .{
        @intFromEnum(timing.Tick.now()),
        scope_name,
    }) catch {};
}

pub fn default_log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@hasDecl(root, "debug_uart")) {
        if (@import("chip").interrupts.is_in_handler()) {
            var writer = root.debug_uart.writer_nonblocking();
            default_log_prefix(message_level, scope, writer);
            writer.print(format, args) catch {};
            writer.writeByte('\n') catch {};
        } else {
            var writer = root.debug_uart.writer();
            default_log_prefix(message_level, scope, writer);
            writer.print(format, args) catch {};
            writer.writeByte('\n') catch {};
        }
    }
}

pub fn default_panic(message: []const u8, trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @setCold(true);

    std.log.err("PANIC: {s}", .{message});
    dump_trace(trace);

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

fn dump_trace(trace: ?*std.builtin.StackTrace) void {
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

const config = @import("config");
const root = @import("root");
const builtin = @import("builtin");
const std = @import("std");
