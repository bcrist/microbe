pub fn configure_interrupt_enables(comptime config: anytype) void {
    const info = @typeInfo(@TypeOf(config));
    switch (info) {
        .Struct => |struct_info| {
            for (struct_info.fields) |field| {
                chip.interrupts.set_enabled(std.enums.nameCast(chip.interrupts.Interrupt, field.name), @field(config, field.name));
            }
        },
        else => {
            @compileError("Expected a struct literal containing interrupts to enable or disable!");
        },
    }
}

pub fn configure_interrupt_priorities(comptime config: anytype) void {
    const info = @typeInfo(@TypeOf(config));
    switch (info) {
        .Struct => |struct_info| {
            for (struct_info.fields) |field| {
                chip.interrupts.set_priority(std.enums.nameCast(chip.interrupts.Exception, field.name), @field(config, field.name));
            }
        },
        else => {
            @compileError("Expected a struct literal containing interrupts and priorities!");
        },
    }
}

pub fn fmt_frequency(freq: u64) std.fmt.Formatter(format_frequency) {
    return .{ .data = freq };
}

fn format_frequency(frequency: u64, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
    _ = fmt;
    _ = options;

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
        .Enum => @intFromEnum(value),
        .Pointer => @intFromPtr(value),
        else => @bitCast(value),
    };
}

pub inline fn from_int(comptime T: type, int_value: anytype) T {
    return switch (@typeInfo(T)) {
        .Enum => @enumFromInt(int_value),
        .Pointer => @ptrFromInt(int_value),
        else => @bitCast(int_value),
    };
}

const chip = @import("chip");
const std = @import("std");
