const std = @import("std");
const chip = @import("chip_interface.zig");
const util = @import("util.zig");

pub const PadID = chip.PadID;

pub const Config = struct {
    name: [:0]const u8 = "Bus",
    gpio_config: ?chip.gpio.Config = null,
};

pub fn Bus(comptime pad_ids: []const chip.PadID, comptime config: Config) type {
    comptime {
        var RawInt = std.meta.Int(.unsigned, pad_ids.len);

        chip.validation.pads.reserveAll(pad_ids, config.name);

        const ports = chip.gpio.getPorts(pad_ids);

        return struct {
            pub const State = RawInt;

            pub fn init() void {
                chip.gpio.ensureInit(pad_ids);
                if (config.gpio_config) |gpio_config| {
                    chip.gpio.configure(pad_ids, gpio_config);
                }
            }

            pub fn setOutputEnable(oe: bool) void {
                if (oe) {
                    chip.gpio.setOutputEnables(pad_ids);
                } else {
                    chip.gpio.clearOutputEnables(pad_ids);
                }
            }
            pub inline fn setOutputEnableInline(comptime oe: bool) void {
                @call(.always_inline, setOutputEnable, .{ oe });
            }

            pub fn read() State {
                var raw: RawInt = 0;
                inline for (ports) |port| {
                    const port_state = chip.gpio.readInputPort(port);
                    inline for (pad_ids, 0..) |pad, raw_bit| {
                        if (comptime chip.gpio.getPort(pad) == port) {
                            const port_bit = 1 << comptime chip.gpio.getOffset(pad);
                            if (0 != (port_state & port_bit)) {
                                raw |= 1 << raw_bit;
                            }
                        }
                    }
                }
                return util.fromInt(State, raw);
            }
            pub inline fn readInline() State {
                return @call(.always_inline, read, .{});
            }

            pub fn get() State {
                var raw: RawInt = 0;
                inline for (ports) |port| {
                    const port_state = chip.gpio.readOutputPort(port);
                    inline for (pad_ids, 0..) |pad, raw_bit| {
                        if (comptime chip.gpio.getPort(pad) == port) {
                            const port_bit = 1 << comptime chip.gpio.getOffset(pad);
                            if (0 != (port_state & port_bit)) {
                                raw |= 1 << raw_bit;
                            }
                        }
                    }
                }
                return util.fromInt(State, raw);
            }
            pub inline fn getInline() State {
                return @call(.always_inline, get, .{});
            }

            pub fn modify(state: State) void {
                const raw = util.toInt(RawInt, state);
                inline for (ports) |port| {
                    var to_clear: chip.gpio.PortDataType = 0;
                    var to_set: chip.gpio.PortDataType = 0;
                    inline for (pad_ids, 0..) |pad, raw_bit| {
                        if (comptime chip.gpio.getPort(pad) == port) {
                            const port_bit = 1 << comptime chip.gpio.getOffset(pad);
                            if (0 == (raw & (1 << raw_bit))) {
                                to_clear |= port_bit;
                            } else {
                                to_set |= port_bit;
                            }
                        }
                    }
                    chip.gpio.modifyOutputPort(port, to_clear, to_set);
                }
            }
            pub inline fn modifyInline(state: State) void {
                @call(.always_inline, modify, .{ state });
            }

            pub fn setBits(state: State) void {
                const raw = util.toInt(RawInt, state);
                inline for (ports) |port| {
                    var to_set: chip.gpio.PortDataType = 0;
                    inline for (pad_ids, 0..) |pad, raw_bit| {
                        if (comptime chip.gpio.getPort(pad) == port) {
                            if (0 != (raw & (1 << raw_bit))) {
                                to_set |= (1 << comptime chip.gpio.getOffset(pad));
                            }
                        }
                    }
                    chip.gpio.setOutputPortBits(port, to_set);
                }
            }
            pub inline fn setBitsInline(state: State) void {
                @call(.always_inline, setBits, .{ state });
            }

            pub fn clearBits(state: State) void {
                const raw = util.toInt(state);
                inline for (ports) |port| {
                    var to_clear: chip.gpio.PortDataType = 0;
                    inline for (pad_ids, 0..) |pad, raw_bit| {
                        if (comptime chip.gpio.getPort(pad) == port) {
                            if (0 != (raw & (1 << raw_bit))) {
                                to_clear |= (1 << comptime chip.gpio.getOffset(pad));
                            }
                        }
                    }
                    chip.gpio.clearOutputPortBits(port, to_clear);
                }
            }
            pub inline fn clearBitsInline(state: State) void {
                @call(.always_inline, clearBits, .{ state });
            }
        };
    }
}
