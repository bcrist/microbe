pub const Config = struct {
    microtick: struct {
        period_ns: comptime_int,
    } = .{ .period_ns = 1_000 },

    tick: ?struct {
        period_ns: comptime_int,
    } = .{ .period_ns = 10_000_000 },
};

pub const Parsed_Config = struct {
    microtick: struct {
        period_ns: comptime_int,
        frequency_hz: comptime_int,
    },
    tick: struct {
        period_ns: comptime_int,
        frequency_hz: comptime_int,
    },
};

pub fn get_config() Parsed_Config {
    return comptime if (@hasDecl(root, "clocks")) parse_config(root.clocks) else reset_config;
}

pub const reset_config = parse_config(.{});

pub fn parse_config(comptime config: Config) Parsed_Config {
    return comptime done: {
        var parsed = Parsed_Config{
            .microtick = .{
                .period_ns = 0,
                .frequency_hz = 0,
            },
            .tick = .{
                .period_ns = 0,
                .frequency_hz = 0,
            },
        };

        {
            parsed.microtick.period_ns = config.microtick.period_ns;
            parsed.microtick.frequency_hz = microbe.div_round(1_000_000_000, config.microtick.period_ns);
            
            const actual_period = microbe.div_round(1_000_000_000, parsed.microtick.frequency_hz);
                if (actual_period != parsed.microtick.period_ns) {
                    @compileError(std.fmt.comptimePrint("Invalid microtick period; closest match is {} ns ({f} microtick)", .{
                        actual_period,
                        microbe.fmt_frequency(parsed.microtick.frequency_hz),
                    }));
                }
            check_frequency("microtick", parsed.microtick.frequency_hz, 1, 1_000_000_000);
        }

        if (config.tick) |tick| {
            parsed.tick.period_ns = tick.period_ns;
            parsed.tick.frequency_hz = microbe.div_round(1_000_000_000, tick.period_ns);

            const actual_period = microbe.div_round(1_000_000_000, parsed.tick.frequency_hz);
            if (actual_period != tick.period_ns) {
                @compileError(std.fmt.comptimePrint("Invalid tick period; closest match is {} ns ({f} tick)", .{
                    actual_period,
                    microbe.fmt_frequency(parsed.tick.frequency_hz),
                }));
            }
            check_frequency("tick", parsed.tick.frequency_hz, 1, 1_000_000);
        }

        break :done parsed;
    };
}

pub fn print_config(comptime config: Parsed_Config, writer: *std.io.Writer) !void {
    try writer.writeAll("\nMicrotick\n");
    try writer.writeAll(std.fmt.comptimePrint("   Frequency: {}\n", .{ comptime microbe.fmt_frequency(config.microtick.frequency_hz) }));
    try writer.writeAll(std.fmt.comptimePrint("   Period:    {} ns\n", .{ config.microtick.period_ns }));

    try writer.writeAll("\nTick\n");
    try writer.writeAll(std.fmt.comptimePrint("   Frequency: {}\n", .{ comptime microbe.fmt_frequency(config.tick.frequency_hz) }));
    try writer.writeAll(std.fmt.comptimePrint("   Period:    {} ns\n", .{ config.tick.period_ns }));
}

/// This contains all the steps that might potentially be necessary to change
/// from one Parsed_Config to another, or to set up the initial Parsed_Config.
/// It's generated at comptime so that the run() function optimizes to just the necessary operations.
const Config_Change = struct {
    pub inline fn run(comptime self: Config_Change) void {
        _ = self;
        @compileError("TODO");
    }
};

pub fn init() void {
    const ch = comptime change: {
        var cc = Config_Change {};
        const config = get_config();
        _ = &cc;
        _ = config;
        if (@compileError("TODO")) break :change cc;
    };
    ch.run();
}

pub fn apply_config(comptime config: anytype, comptime previous_config: anytype) void {
    const parsed = comptime if (@TypeOf(config) == Parsed_Config) config else parse_config(config);
    const previous_parsed = comptime if (@TypeOf(previous_config) == Parsed_Config) previous_config else parse_config(previous_config);
    apply_parsed_config(parsed, previous_parsed);
}

fn apply_parsed_config(comptime parsed: Parsed_Config, comptime old: Parsed_Config) void {
    _ = old;
    _ = parsed;
    comptime change: {
        var cc = Config_Change {};
        _ = &cc;
        if (@compileError("TODO")) break :change cc;
    }.run();
}

const check_frequency = internal.check_frequency;

const Pad_ID = @import("../chip.zig").Pad_ID;
const internal = @import("microbe_internal");
const microbe = @import("microbe");
const root = @import("root");
const std = @import("std");
