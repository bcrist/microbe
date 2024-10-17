pub const Config = struct {
    name: [:0]const u8 = "Bus",
    gpio_config: ?chip.gpio.Config = null,
    State: ?type = null,
};

pub fn Bus(comptime pad_ids: []const chip.Pad_ID, comptime config: Config) type {
    const Raw_Int = std.meta.Int(.unsigned, pad_ids.len);
    const ports = chip.gpio.get_ports(pad_ids);
    const State_Type = config.State orelse Raw_Int;

    std.debug.assert(@bitSizeOf(State_Type) == @bitSizeOf(Raw_Int));

    return struct {
        pub const State = State_Type;

        pub fn init() void {
            chip.validation.pads.reserve_all(pad_ids, config.name);
            chip.gpio.ensure_init(pad_ids);
            if (config.gpio_config) |gpio_config| {
                chip.gpio.configure(pad_ids, gpio_config);
            }
        }

        pub fn deinit() void {
            chip.validation.pads.release_all(pad_ids, config.name);
        }

        pub fn set_output_enable(oe: bool) void {
            if (oe) {
                chip.gpio.set_output_enables(pad_ids);
            } else {
                chip.gpio.clear_output_enables(pad_ids);
            }
        }
        pub inline fn set_output_enable_inline(comptime oe: bool) void {
            @call(.always_inline, set_output_enable, .{ oe });
        }

        pub fn read() State {
            var raw: Raw_Int = 0;
            inline for (ports) |port| {
                const port_state = chip.gpio.read_input_port(port);
                inline for (pad_ids, 0..) |pad, raw_bit| {
                    if (comptime chip.gpio.get_port(pad) == port) {
                        const port_bit = 1 << comptime chip.gpio.get_offset(pad);
                        if (0 != (port_state & port_bit)) {
                            raw |= 1 << raw_bit;
                        }
                    }
                }
            }
            return util.from_int(State, raw);
        }
        pub inline fn read_inline() State {
            return @call(.always_inline, read, .{});
        }

        pub fn get() State {
            var raw: Raw_Int = 0;
            inline for (ports) |port| {
                const port_state = chip.gpio.read_output_port(port);
                inline for (pad_ids, 0..) |pad, raw_bit| {
                    if (comptime chip.gpio.get_port(pad) == port) {
                        const port_bit = 1 << comptime chip.gpio.get_offset(pad);
                        if (0 != (port_state & port_bit)) {
                            raw |= 1 << raw_bit;
                        }
                    }
                }
            }
            return util.from_int(State, raw);
        }
        pub inline fn get_inline() State {
            return @call(.always_inline, get, .{});
        }

        pub fn modify(state: State) void {
            const raw = util.to_int(Raw_Int, state);
            inline for (ports) |port| {
                var to_clear: chip.gpio.Port_Data_Type = 0;
                var to_set: chip.gpio.Port_Data_Type = 0;
                inline for (pad_ids, 0..) |pad, raw_bit| {
                    if (comptime chip.gpio.get_port(pad) == port) {
                        const port_bit = 1 << comptime chip.gpio.get_offset(pad);
                        if (0 == (raw & (1 << raw_bit))) {
                            to_clear |= port_bit;
                        } else {
                            to_set |= port_bit;
                        }
                    }
                }
                chip.gpio.modify_output_port(port, to_clear, to_set);
            }
        }
        pub inline fn modify_inline(state: State) void {
            @call(.always_inline, modify, .{ state });
        }

        pub fn set_bits(state: State) void {
            const raw = util.to_int(Raw_Int, state);
            inline for (ports) |port| {
                var to_set: chip.gpio.Port_Data_Type = 0;
                inline for (pad_ids, 0..) |pad, raw_bit| {
                    if (comptime chip.gpio.get_port(pad) == port) {
                        if (0 != (raw & (1 << raw_bit))) {
                            to_set |= (1 << comptime chip.gpio.get_offset(pad));
                        }
                    }
                }
                chip.gpio.set_output_port_bits(port, to_set);
            }
        }
        pub inline fn set_bits_inline(state: State) void {
            @call(.always_inline, set_bits, .{ state });
        }

        pub fn clear_bits(state: State) void {
            const raw = util.to_int(state);
            inline for (ports) |port| {
                var to_clear: chip.gpio.Port_Data_Type = 0;
                inline for (pad_ids, 0..) |pad, raw_bit| {
                    if (comptime chip.gpio.get_port(pad) == port) {
                        if (0 != (raw & (1 << raw_bit))) {
                            to_clear |= (1 << comptime chip.gpio.get_offset(pad));
                        }
                    }
                }
                chip.gpio.clear_output_port_bits(port, to_clear);
            }
        }
        pub inline fn clear_bits_inline(state: State) void {
            @call(.always_inline, clear_bits, .{ state });
        }
    };
}

pub const Pad_ID = chip.Pad_ID;
const chip = @import("chip_interface.zig");
const util = @import("util.zig");
const std = @import("std");
