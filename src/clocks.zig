/// Chip clocks can be configured automatically by declaring a `clocks` constant
/// in the root source file:
///
/// pub const clocks = chip.clocks.Config { ... };
///
/// The exact format of the Config struct depends on the chip in use.
///
/// chip.clocks.getConfig() will return a comptime constant ParsedConfig
/// based on either the Config declared in the root source file, or the
/// default reset clock configuration if no clock configuration is provided.
///
/// ParsedConfig is guaranteed to have a field for every clock domain in the
/// Domain enum, with the field being named `@tagName(domain) ++ "_frequency_hz"`
/// and having type `comptime_int`.  Additionally, if a clock domain is sourced
/// from another domain, it will have a field `@tagName(domain) ++ "_source"`
/// whose type is either `Domain` or `?Domain`.  Normally, these fields will
/// be accessed through `getFrequency(domain)` and `getSource(domain)`.

const std = @import("std");
const chip = @import("root").chip;

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
        return chip.clocks.currentTick();
    }

    pub fn isAfter(self: Tick, other: Tick) bool {
        return (@intFromEnum(self) -% @intFromEnum(other)) > 0;
    }

    pub fn isBefore(self: Tick, other: Tick) bool {
        return (@intFromEnum(self) -% @intFromEnum(other)) < 0;
    }

    pub fn plus(self: Tick, comptime time: anytype) Tick {
        const extra = comptime parseDuration(i32, time, chip.clocks.getFrequency(.tick));
        return @enumFromInt(@intFromEnum(self) +% extra);
    }
};

/// Microtick period may vary, but it should be faster than the Tick period.
///
/// For most devices this is driven by an interrupt and may be disabled in at least
/// some low power/sleep modes.
pub const Microtick = enum (i64) {

    pub fn now() Microtick {
        return chip.clocks.currentMicrotick();
    }

    pub fn isAfter(self: Microtick, other: Microtick) bool {
        return (@intFromEnum(self) -% @intFromEnum(other)) > 0;
    }

    pub fn isBefore(self: Microtick, other: Microtick) bool {
        return (@intFromEnum(self) -% @intFromEnum(other)) < 0;
    }

    pub fn plus(self: Microtick, comptime time: anytype) Microtick {
        const extra = comptime parseDuration(i64, time, chip.clocks.getFrequency(.microtick));
        return @enumFromInt(@intFromEnum(self) +% extra);
    }
};

fn parseDuration(comptime T: type, comptime time: anytype, comptime tick_frequency_hz: comptime_int) T {
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
