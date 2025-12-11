pub const MMIO = @import("mmio.zig").MMIO;
const timing = @import("timing.zig");
pub const Tick = timing.Tick;
pub const Microtick = timing.Microtick;
pub const Critical_Section = @import("Critical_Section.zig");
pub const bus = @import("bus.zig");
pub const Bus = bus.Bus;
pub const usb = @import("usb.zig");
pub const USB = usb.USB;

const validation = @import("resource_validation.zig");
pub const Runtime_Resource_Validator = if (config.runtime_resource_validation)
    validation.Runtime_Resource_Validator
else
    validation.Null_Resource_Validator;
pub const Bitset_Resource_Validator = validation.Bitset_Resource_Validator;

fn default_log_prefix(comptime message_level: std.log.Level, comptime scope: @Type(.enum_literal), writer: *std.io.Writer) void {
    const scope_name = if (std.mem.eql(u8, @tagName(scope), "default")) "" else @tagName(scope);
    const level_prefix = switch (message_level) {
        .err => "E",
        .warn => "W",
        .info => "I",
        .debug => "D",
    };
    writer.print(level_prefix ++ "{: <11} {s}: ", .{
        @intFromEnum(timing.Microtick.now()),
        scope_name,
    }) catch {};
}

pub fn default_blocking_log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@hasDecl(root, "debug_writer_nonblocking") and chip.interrupts.is_in_handler()) {
        default_log_prefix(message_level, scope, root.debug_writer_nonblocking);
        root.debug_writer_nonblocking.print(format, args) catch {};
        root.debug_writer_nonblocking.writeByte('\n') catch {};
        return;
    }
    if (@hasDecl(root, "debug_writer")) {
        default_log_prefix(message_level, scope, root.debug_writer);
        root.debug_writer.print(format, args) catch {};
        root.debug_writer.writeByte('\n') catch {};
    }
}

pub fn default_nonblocking_log(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    if (@hasDecl(root, "debug_writer_nonblocking")) {
        default_log_prefix(message_level, scope, root.debug_writer_nonblocking);
        root.debug_writer_nonblocking.print(format, args) catch {};
        root.debug_writer_nonblocking.writeByte('\n') catch {};
        return;
    }
    if (@hasDecl(root, "debug_writer")) {
        default_log_prefix(message_level, scope, root.debug_writer);
        root.debug_writer.print(format, args) catch {};
        root.debug_writer.writeByte('\n') catch {};
    }
}

pub fn default_panic(message: []const u8, trace: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    @branchHint(.cold);

    std.log.err("PANIC: {s}", .{message});
    dump_trace(trace);

    if (config.breakpoint_on_panic) {
        // attach a breakpoint, this might trigger another
        // panic internally, so only do that in debug mode.
        @breakpoint();
    }

    if (@hasDecl(chip, "panic_hang")) {
        chip.panic_hang();
    } else {
        hang();
    }
}

pub fn hang() noreturn {
    while (true) {
        // "this loop has side effects, don't optimize the endless loop away please. thanks!"
        asm volatile ("" ::: .{ .memory = true });
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
    if (chip.interrupts.is_in_handler()) {
        std.log.err("{}", .{chip.interrupts.current_exception()});
    }
}

pub fn fmt_frequency(freq: u64) std.fmt.Alt(u64, format_frequency) {
    return .{ .data = freq };
}

fn format_frequency(frequency: u64, writer: *std.io.Writer) !void {
    if (frequency >= 1_000_000) {
        const mhz = frequency / 1_000_000;
        const rem = frequency % 1_000_000;
        var temp: [7]u8 = undefined;
        var tail: []const u8 = try std.fmt.bufPrint(&temp, ".{:0>6}", .{rem});
        tail = std.mem.trimRight(u8, tail, "0");
        if (tail.len == 1) tail.len = 0;
        try writer.print("{}{s} MHz", .{ mhz, tail });
    } else if (frequency >= 1_000) {
        const khz = frequency / 1_000;
        const rem = frequency % 1_000;
        var temp: [4]u8 = undefined;
        var tail: []const u8 = try std.fmt.bufPrint(&temp, ".{:0>3}", .{rem});
        tail = std.mem.trimRight(u8, tail, "0");
        if (tail.len == 1) tail.len = 0;
        try writer.print("{}{s} kHz", .{ khz, tail });
    } else {
        try writer.print("{} Hz", .{frequency});
    }
}

pub fn div_round(comptime dividend: comptime_int, comptime divisor: comptime_int) comptime_int {
    return @divTrunc(dividend + @divTrunc(divisor, 2), divisor);
}

// This intentionally converts to strings and looks for equality there, so that you can check a
// Pad_ID against a tuple of enum literals, some of which might not be valid Pad_IDs.  That's
// useful when writing generic chip code, where some packages will be missing some Pad_IDs that
// other related chips do have.
pub fn is_pad_in_set(comptime pad: chip.Pad_ID, comptime set: anytype) bool {
    comptime {
        for (set) |p| {
            switch (@typeInfo(@TypeOf(p))) {
                .EnumLiteral => {
                    if (std.mem.eql(u8, @tagName(p), @tagName(pad))) {
                        return true;
                    }
                },
                .Pointer => {
                    if (std.mem.eql(u8, p, @tagName(pad))) {
                        return true;
                    }
                },
                else => @compileError("Expected enum or string literal!"),
            }
        }
        return false;
    }
}

pub fn error_set_contains_any(comptime Haystack: type, comptime Needle: type) bool {
    const haystack_set = @typeInfo(Haystack).ErrorSet orelse &.{};
    const needle_set = @typeInfo(Needle).ErrorSet orelse &.{};

    inline for (needle_set) |nerr| {
        inline for (haystack_set) |herr| {
            if (comptime std.mem.eql(u8, nerr.name, herr.name)) {
                return true;
            }
        }
    }
    return false;
}

pub fn error_set_contains_all(comptime Haystack: type, comptime Needle: type) bool {
    const haystack_set = @typeInfo(Haystack).ErrorSet orelse &.{};
    const needle_set = @typeInfo(Needle).ErrorSet orelse &.{};

    outer: inline for (needle_set) |nerr| {
        inline for (haystack_set) |herr| {
            if (comptime std.mem.eql(u8, nerr.name, herr.name)) {
                continue :outer;
            }
        }
        return false;
    }
    return true;
}

pub inline fn to_int(comptime T: type, value: anytype) T {
    return switch (@typeInfo(@TypeOf(value))) {
        .@"enum" => @intFromEnum(value),
        .pointer => @intFromPtr(value),
        else => @bitCast(value),
    };
}

pub inline fn from_int(comptime T: type, int_value: anytype) T {
    return switch (@typeInfo(T)) {
        .@"enum" => @enumFromInt(int_value),
        .pointer => @ptrFromInt(int_value),
        else => @bitCast(int_value),
    };
}

const chip = @import("chip");
const config = @import("config");
const root = @import("root");
const builtin = @import("builtin");
const std = @import("std");
