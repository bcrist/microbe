


/// Tick period may vary, but it should be between 1us and 1ms (1kHz to 1MHz).
/// This means rollovers will happen no more frequently than once every 70 minutes,
/// but at least once every 50 days.
///
/// As a rule of thumb, avoid comparing Ticks that might be more than 15-20 minutes
/// apart, because the relative ordering between two ticks may be inaccurate after
/// around 35 minutes.
///
/// For most devices this is driven by an interrupt and may be disabled in at least
/// some low power/sleep modes.
pub const Tick = enum (i32) {
    _,

    pub fn now() Tick {
        return chip.timing.current_tick();
    }

    pub fn is_after(self: Tick, other: Tick) bool {
        return (@intFromEnum(self) -% @intFromEnum(other)) > 0;
    }

    pub fn is_before(self: Tick, other: Tick) bool {
        return (@intFromEnum(self) -% @intFromEnum(other)) < 0;
    }

    pub fn plus(self: Tick, comptime time: anytype) Tick {
        const extra = comptime parse_duration(i32, time, frequency_hz());
        return @enumFromInt(@intFromEnum(self) +% extra);
    }

    pub fn delay(comptime time: anytype) void {
        chip.timing.block_until_tick(now().plus(time));
    }

    pub fn frequency_hz() comptime_int {
        return chip.timing.get_tick_frequency_hz();
    }
};

/// Microtick period may vary, but it should be faster than the Tick period.
///
/// For most devices this is driven by an interrupt and may be disabled in at least
/// some low power/sleep modes.
pub const Microtick = enum (i64) {
    _,

    pub fn now() Microtick {
        return chip.timing.current_microtick();
    }

    pub fn is_after(self: Microtick, other: Microtick) bool {
        return (@intFromEnum(self) -% @intFromEnum(other)) > 0;
    }

    pub fn is_before(self: Microtick, other: Microtick) bool {
        return (@intFromEnum(self) -% @intFromEnum(other)) < 0;
    }

    pub fn plus(self: Microtick, comptime time: anytype) Microtick {
        const extra = comptime parse_duration(i64, time, frequency_hz());
        return @enumFromInt(@intFromEnum(self) +% extra);
    }

    pub fn delay(comptime time: anytype) void {
        chip.timing.block_until_microtick(now().plus(time));
    }

    pub fn frequency_hz() comptime_int {
        return chip.timing.get_microtick_frequency_hz();
    }
};

fn parse_duration(comptime T: type, comptime time: anytype, comptime tick_frequency_hz: comptime_int) T {
    var extra: T = 0;
    const time_info = @typeInfo(@TypeOf(time));
    inline for (time_info.Struct.fields) |field| {
        const v: comptime_int = @field(time, field.name);
        extra +%= if (std.mem.eql(u8, field.name, "minutes"))
            v * 60 * tick_frequency_hz
        else if (std.mem.eql(u8, field.name, "seconds"))
            v * tick_frequency_hz
        else if (std.mem.eql(u8, field.name, "ms") or std.mem.eql(u8, field.name, "milliseconds") or std.mem.eql(u8, field.name, "millis"))
            @divFloor((v * tick_frequency_hz + 500), 1000)
        else if (std.mem.eql(u8, field.name, "us") or std.mem.eql(u8, field.name, "microseconds") or std.mem.eql(u8, field.name, "micros"))
            @divFloor((v * tick_frequency_hz + 500000), 1000000)
        else if (std.mem.eql(u8, field.name, "ticks"))
            v
        else
            @compileError("Unrecognized field!");
    }
    return @max(1, extra);
}

const chip = @import("chip_interface.zig");
const std = @import("std");
