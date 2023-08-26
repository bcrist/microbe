const std = @import("std");
const chip = @import("root").chip;
const CriticalSection = @import("CriticalSection.zig");
const pads = @import("pads.zig");

pub const Mode = enum {
    input,
    output,
    bidirectional,
};

pub const PadID = chip.gpio.PadID;
pub const SlewRate = chip.gpio.SlewRate;
pub const DriveMode = chip.gpio.DriveMode;
pub const TerminationMode = chip.gpio.TerminationMode;

pub const Direction = enum(u1) {
    input = 0,
    output = 1,
};

pub const Config = struct {
    mode: Mode,
    slew: SlewRate = SlewRate.default,
    drive: DriveMode = DriveMode.default,
    termination: TerminationMode = TerminationMode.default,
};

pub fn Bus(comptime bus_name: []const u8, comptime pads_struct: anytype, comptime config: Config) type {
    comptime {
        const PadsType = @TypeOf(pads_struct);
        const pads_struct_info = @typeInfo(PadsType).Struct;

        if (!pads_struct_info.is_tuple) {
            @compileError("Struct State types not yet stupported");
        }

        var pad_ids: []const PadID = &[_]PadID{};
        var RawInt = std.meta.Int(.unsigned, pads_struct_info.fields.len);
        inline for (pads_struct) |pad| {
            pad_ids = pad_ids ++ [_]PadID{pad};
        }

        var pad_reservation_name = "Bus " ++ bus_name;

        return struct {
            pub const State = RawInt;

            pub fn init() void {
                const cs = CriticalSection.enter();
                defer cs.leave();

                pads.reserve(pad_ids, pad_reservation_name);
                chip.gpio.ensurePortsEnabled(pad_ids);
                chip.gpio.configureTermination(pad_ids, config.termination);
                switch (config.mode) {
                    .output => {
                        chip.gpio.configureSlewRate(pad_ids, config.slew);
                        chip.gpio.configureDriveMode(pad_ids, config.drive);
                        chip.gpio.configureAsOutput(pad_ids);
                    },
                    .input => {
                        chip.gpio.configureAsInput(pad_ids);
                    },
                    .bidirectional => {
                        chip.gpio.configureSlewRate(pad_ids, config.slew);
                        chip.gpio.configureDriveMode(pad_ids, config.drive);
                        chip.gpio.configureAsInput(pad_ids);
                    },
                }
            }

            pub fn deinit() void {
                const cs = CriticalSection.enter();
                defer cs.leave();

                if (config.termination != .float) {
                    chip.gpio.configureTermination(pad_ids, .float);
                }
                chip.gpio.configureAsUnused(pad_ids);
                pads.release(pad_ids, pad_reservation_name);
            }

            pub usingnamespace if (config.mode != .output) struct {
                pub fn read() State {
                    var raw = RawInt{};
                    if (@hasDecl(chip.gpio, "readInputPort") and @hasDecl(chip.gpio, "getIOPorts")) {
                        inline for (comptime chip.gpio.getIOPorts(pad_ids)) |port| {
                            const port_state = chip.gpio.readInputPort(port);
                            inline for (pad_ids, 0..) |pad, raw_bit| {
                                if (chip.gpio.getIOPort(pad) == port) {
                                    const port_bit = 1 << chip.gpio.getOffset(pad);
                                    if (0 != (port_state & port_bit)) {
                                        raw |= 1 << raw_bit;
                                    }
                                }
                            }
                        }
                    } else {
                        // TODO
                        @compileError("not implemented!");
                    }
                    return @as(State, @bitCast(raw));
                }
            } else struct {};

            pub usingnamespace if (config.mode == .bidirectional) struct {
                pub fn setDirection(dir: Direction) void {
                    switch (dir) {
                        .input => chip.gpio.configureAsInput(pad_ids),
                        .output => chip.gpio.configureAsOutput(pad_ids),
                    }
                }
                pub fn getDirection() Direction {
                    if (chip.gpio.isOutput(pad_ids[0])) {
                        return .output;
                    } else {
                        return .input;
                    }
                }
            } else struct {};

            pub usingnamespace if (config.mode != .input) struct {
                pub fn get() State {
                    var raw: RawInt = 0;
                    if (@hasDecl(chip.gpio, "readOutputPort") and @hasDecl(chip.gpio, "getIOPorts")) {
                        inline for (comptime chip.gpio.getIOPorts(pad_ids)) |port| {
                            const port_state = chip.gpio.readOutputPort(port);
                            inline for (pad_ids, 0..) |pad, raw_bit| {
                                if (chip.gpio.getIOPort(pad) == port) {
                                    const port_bit = 1 << chip.gpio.getOffset(pad);
                                    if (0 != (port_state & port_bit)) {
                                        raw |= 1 << raw_bit;
                                    }
                                }
                            }
                        }
                    } else {
                        // TODO
                        @compileError("not implemented!");
                    }
                    return @as(State, @bitCast(raw));
                }

                pub fn modify(state: State) void {
                    const raw = @as(RawInt, @bitCast(state));
                    if (@hasDecl(chip.gpio, "modifyOutputPort") and @hasDecl(chip.gpio, "getIOPorts")) {
                        inline for (comptime chip.gpio.getIOPorts(pad_ids)) |port| {
                            var to_clear: chip.gpio.PortDataType = 0;
                            var to_set: chip.gpio.PortDataType = 0;
                            inline for (pad_ids, 0..) |pad, raw_bit| {
                                if (chip.gpio.getIOPort(pad) == port) {
                                    const port_bit = 1 << chip.gpio.getOffset(pad);
                                    if (0 == (raw & (1 << raw_bit))) {
                                        to_clear |= port_bit;
                                    } else {
                                        to_set |= port_bit;
                                    }
                                }
                            }
                            chip.gpio.modifyOutputPort(port, to_clear, to_set);
                        }
                    } else {
                        // TODO
                        @compileError("not implemented!");
                    }
                }
                pub inline fn modifyInline(state: State) void {
                    @call(.always_inline, modify, .{state});
                }

                pub fn setBits(state: State) void {
                    const raw = @as(RawInt, @bitCast(state));
                    if (@hasDecl(chip.gpio, "modifyOutputPort") and @hasDecl(chip.gpio, "getIOPorts")) {
                        inline for (comptime chip.gpio.getIOPorts(pad_ids)) |port| {
                            var to_set: chip.gpio.PortDataType = 0;
                            inline for (pad_ids, 0..) |pad, raw_bit| {
                                if (chip.gpio.getIOPort(pad) == port) {
                                    if (0 != (raw & (1 << raw_bit))) {
                                        to_set |= (1 << chip.gpio.getOffset(pad));
                                    }
                                }
                            }
                            chip.gpio.modifyOutputPort(port, 0, to_set);
                        }
                    } else {
                        // TODO
                        @compileError("not implemented!");
                    }
                }
                pub inline fn setBitsInline(state: State) void {
                    @call(.always_inline, setBits, .{state});
                }

                pub fn clearBits(state: State) void {
                    const raw = @as(RawInt, @bitCast(state));
                    if (@hasDecl(chip.gpio, "modifyOutputPort") and @hasDecl(chip.gpio, "getIOPorts")) {
                        inline for (comptime chip.gpio.getIOPorts(pad_ids)) |port| {
                            var to_clear: chip.gpio.PortDataType = 0;
                            inline for (pad_ids, 0..) |pad, raw_bit| {
                                if (chip.gpio.getIOPort(pad) == port) {
                                    if (0 != (raw & (1 << raw_bit))) {
                                        to_clear |= (1 << chip.gpio.getOffset(pad));
                                    }
                                }
                            }
                            chip.gpio.modifyOutputPort(port, to_clear, 0);
                        }
                    } else {
                        // TODO
                        @compileError("not implemented!");
                    }
                }
                pub inline fn clearBitsInline(state: State) void {
                    @call(.always_inline, clearBits, .{state});
                }
            } else struct {};
        };
    }
}
