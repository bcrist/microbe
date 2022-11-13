/// Chip clocks can be configured automatically by declaring a `clocks` constant
/// in the root source file:
///
/// pub const clocks = microbe.clocks.Config { ... };
///
/// The exact format of the Config struct depends on the chip in use.
///
/// microbe.clocks.getConfig() will return a comptime constant ParsedConfig
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
const microbe = @import("root");
const chip = microbe.chip;
const main = microbe.main;

pub const Domain = chip.clocks.Domain;
pub const Config = chip.clocks.Config;
pub const ParsedConfig = chip.clocks.ParsedConfig;

pub fn getConfig() ParsedConfig { comptime {
    @setEvalBranchQuota(10_000);
    return if (@hasDecl(main, "clocks")) chip.clocks.parseConfig(main.clocks) else chip.clocks.reset_config;
}}

pub fn getFrequency(comptime domain: Domain) comptime_int { comptime {
    @setEvalBranchQuota(10_000);
    return @field(getConfig(), @tagName(domain) ++ "_frequency_hz");
}}

pub fn getSource(comptime domain: Domain) ?Domain { comptime {
    const config = getConfig();
    const field_name = @tagName(domain) ++ "_source";
    return if (@hasDecl(config, field_name)) @field(config, field_name) else null;
}}

/// Tick period may vary, but it should be between 1us and 1ms (1kHz to 1MHz).
/// This means rollovers will happen no more frequently than once every 70 minutes,
/// but at least once every 50 days.
///
/// As a rule of thumb, avoid comparing Ticks that might be more than 15-20 minutes
/// apart, because the relative ordering between two ticks may be inaccurate after
/// around 35 minutes.
pub const Tick = struct {
    raw: i32,

    pub fn isAfter(self: Tick, other: Tick) bool {
        return (self.raw -% other.raw) > 0;
    }

    pub fn isBefore(self: Tick, other: Tick) bool {
        return (self.raw -% other.raw) < 0;
    }

    fn parseDuration(comptime time: anytype, comptime T: type, tick_frequency_hz: T) i32 {
        var extra: i32 = 0;
        const time_info = @typeInfo(@TypeOf(time));
        inline for (time_info.Struct.fields) |field| {
            const v: comptime_int = @field(time, field.name);
            extra +%= if (std.mem.eql(u8, field.name, "minutes"))
                v * 60 * tick_frequency_hz
            else if (std.mem.eql(u8, field.name, "seconds"))
                v * tick_frequency_hz
            else if (std.mem.eql(u8, field.name, "ms") or std.mem.eql(u8, field.name, "milliseconds"))
                @divFloor((v * tick_frequency_hz + 500), 1000)
            else if (std.mem.eql(u8, field.name, "us") or std.mem.eql(u8, field.name, "microseconds"))
                @divFloor((v * tick_frequency_hz + 500000), 1000000)
            else if (std.mem.eql(u8, field.name, "ticks"))
                v
            else
                @compileError("Unrecognized field!");
        }
        return @max(1, extra);
    }

    pub fn plus(self: Tick, comptime time: anytype) Tick {
        const extra = comptime parseDuration(time, comptime_int, getFrequency(.tick));
        return .{
            .raw = self.raw +% extra,
        };
    }

};

pub var current_tick: Tick = .{ .raw = 0 };

pub fn blockUntilTick(t: Tick) void {
    while (current_tick.isBefore(t)) {
        asm volatile ("" ::: "memory");
    }
}

pub fn handleTickInterrupt() void {
    if (@hasDecl(chip.clocks, "handleTickInterrupt")) {
        chip.clocks.handleTickInterrupt();
    } else {
        current_tick.raw +%= 1;
    }
}

pub usingnamespace if (@hasDecl(chip.clocks, "currentMicrotick")) struct {

    pub const Microtick = struct {
        raw: i64,

        pub fn isAfter(self: Microtick, other: Microtick) bool {
            return (self.raw -% other.raw) > 0;
        }

        pub fn isBefore(self: Microtick, other: Microtick) bool {
            return (self.raw -% other.raw) < 0;
        }

        fn parseDuration(comptime time: anytype, comptime T: type, tick_frequency_hz: T) i32 {
            var extra: i32 = 0;
            const time_info = @typeInfo(@TypeOf(time));
            inline for (time_info.Struct.fields) |field| {
                const v: comptime_int = @field(time, field.name);
                extra +%= if (std.mem.eql(u8, field.name, "minutes"))
                    v * 60 * tick_frequency_hz
                else if (std.mem.eql(u8, field.name, "seconds"))
                    v * tick_frequency_hz
                else if (std.mem.eql(u8, field.name, "ms") or std.mem.eql(u8, field.name, "milliseconds"))
                    @divFloor((v * tick_frequency_hz + 500), 1000)
                else if (std.mem.eql(u8, field.name, "us") or std.mem.eql(u8, field.name, "microseconds"))
                    @divFloor((v * tick_frequency_hz + 500000), 1000000)
                else if (std.mem.eql(u8, field.name, "ticks"))
                    v
                else
                    @compileError("Unrecognized field!");
            }
            return @max(1, extra);
        }

        pub fn plus(self: Microtick, comptime time: anytype) Microtick {
            const extra = comptime parseDuration(time, comptime_int, getFrequency(.microtick));
            return .{
                .raw = self.raw +% extra,
            };
        }

    };

    pub const currentMicrotick = chip.clocks.currentMicrotick;

    pub fn blockUntilMicrotick(t: Microtick) void {
        while (currentMicrotick().isBefore(t)) {
            asm volatile ("" ::: "memory");
        }
    }

} else struct {};

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
        var tail: []const u8 = try std.fmt.bufPrint(&temp, ".{:0>6}", .{ rem });
        tail = std.mem.trimRight(u8, tail, "0");
        if (tail.len == 1) tail.len = 0;
        try writer.print("{}{s} MHz", .{ mhz, tail });
    } else if (frequency >= 1_000) {
        const khz = frequency / 1_000;
        const rem = frequency % 1_000;
        var temp: [4]u8 = undefined;
        var tail: []const u8 = try std.fmt.bufPrint(&temp, ".{:0>3}", .{ rem });
        tail = std.mem.trimRight(u8, tail, "0");
        if (tail.len == 1) tail.len = 0;
        try writer.print("{}{s} kHz", .{ khz, tail });
    } else {
        try writer.print("{} Hz", .{ frequency });
    }
}

pub fn divRound(comptime freq: comptime_int, comptime div: comptime_int) comptime_int {
    return @divTrunc(freq + @divTrunc(div, 2), div);
}
