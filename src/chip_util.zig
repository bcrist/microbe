const std = @import("std");
const chip = @import("root").chip;

pub fn configureInterruptEnables(comptime config: anytype) void {
    const info = @typeInfo(@TypeOf(config));
    switch (info) {
        .Struct => |struct_info| {
            for (struct_info.fields) |field| {
                chip.interrupts.setEnabled(std.enums.nameCast(chip.interrupts.Type, field.name), @field(config, field.name));
            }
        },
        else => {
            @compileError("Expected a struct literal containing interrupts to enable or disable!");
        },
    }
}

pub fn configureInterruptPriorities(comptime config: anytype) void {
    const info = @typeInfo(@TypeOf(config));
    switch (info) {
        .Struct => |struct_info| {
            for (struct_info.fields) |field| {
                chip.interrupts.setPriority(std.enums.nameCast(chip.interrupts.Type, field.name), @field(config, field.name));
            }
        },
        else => {
            @compileError("Expected a struct literal containing interrupts and priorities!");
        },
    }
}

pub fn fmtFrequency(freq: u64) std.fmt.Formatter(formatFrequency) {
    return .{ .data = freq };
}

fn formatFrequency(frequency: u64, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
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

pub fn divRound(comptime dividend: comptime_int, comptime divisor: comptime_int) comptime_int {
    return @divTrunc(dividend + @divTrunc(divisor, 2), divisor);
}
