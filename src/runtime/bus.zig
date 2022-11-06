const std = @import("std");
const microbe = @import("root");
const chip = microbe.chip;

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

pub fn Bus(comptime bus_name: []const u8, comptime pads: anytype, comptime config: Config) type { comptime {
    const PadsType = @TypeOf(pads);
    const pads_struct_info = @typeInfo(PadsType).Struct;

    if (!pads_struct_info.is_tuple) {
        @compileError("Struct State types not yet stupported");
    }

    var pad_ids: []const PadID = &[_]PadID {};
    var RawInt = std.meta.Int(.unsigned, pads_struct_info.fields.len);
    inline for (pads) |pad| {
        pad_ids = pad_ids ++ [_]PadID { pad };
    }

    var pad_reservation_name = "Bus " ++ bus_name;

    return struct {
        const Self = @This();
        pub const State = RawInt;

        pub fn init() Self {
            const cs = microbe.interrupts.enterCriticalSection();
            defer cs.leave();

            microbe.pads.reserve(pad_ids, pad_reservation_name);
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
            return .{};
        }

        pub fn deinit(_: Self) void {
            const cs = microbe.interrupts.enterCriticalSection();
            defer cs.leave();

            if (config.termination != .float) {
                chip.gpio.configureTermination(pad_ids, .float);
            }
            chip.gpio.configureAsUnused(pad_ids);
            microbe.pads.release(pad_ids, pad_reservation_name);
        }

        pub usingnamespace if (config.mode != .output) struct {
            pub fn read(_: Self) State {
                var raw = RawInt {};
                if (@hasDecl(chip.gpio, "readInputPort") and @hasDecl(chip.gpio, "getIOPorts")) {
                    inline for (chip.gpio.getIOPorts(pad_ids)) |port| {
                        const port_state = chip.gpio.readInputPort(port);
                        inline for (pad_ids) |pad, raw_bit| {
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
                return @bitCast(State, raw);
            }
        } else struct {};

        pub usingnamespace if (config.mode == .bidirectional) struct {
            pub fn setDirection(_: Self, dir: Direction) void {
                switch (dir) {
                    .input => chip.gpio.configureAsInput(pad_ids),
                    .output => chip.gpio.configureAsOutput(pad_ids),
                }
            }
            pub fn getDirection(_: Self) Direction {
                if (chip.gpio.isOutput(pad_ids[0])) {
                    return .output;
                } else {
                    return .input;
                }
            }
        } else struct {};

        pub usingnamespace if (config.mode != .input) struct {
            pub fn get(_: Self) State {
                var raw = RawInt {};
                if (@hasDecl(chip.gpio, "readOutputPort") and @hasDecl(chip.gpio, "getIOPorts")) {
                    inline for (chip.gpio.getIOPorts(pad_ids)) |port| {
                        const port_state = chip.gpio.readOutputPort(port);
                        inline for (pad_ids) |pad, raw_bit| {
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
                return @bitCast(State, raw);
            }

            pub fn modify(_: Self, state: State) void {
                const raw = @bitCast(RawInt, state);
                if (@hasDecl(chip.gpio, "modifyOutputPort") and @hasDecl(chip.gpio, "getIOPorts")) {
                    inline for (comptime chip.gpio.getIOPorts(pad_ids)) |port| {
                        var to_clear: chip.gpio.PortDataType = 0;
                        var to_set: chip.gpio.PortDataType = 0;
                        inline for (pad_ids) |pad, raw_bit| {
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
            pub fn modifyInline(self: Self, state: State) callconv(.Inline) void {
                @call(.{ .modifier = .always_inline }, modify, .{ self, state });
            }

            pub fn setBits(_: Self, state: State) void {
                const raw = @bitCast(RawInt, state);
                if (@hasDecl(chip.gpio, "modifyOutputPort") and @hasDecl(chip.gpio, "getIOPorts")) {
                    inline for (chip.gpio.getIOPorts(pad_ids)) |port| {
                        var to_set: chip.gpio.PortDataType = 0;
                        inline for (pad_ids) |pad, raw_bit| {
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
            pub fn setBitsInline(self: Self, state: State) callconv(.Inline) void {
                @call(.{ .modifier = .always_inline }, setBits, .{ self, state });
            }

            pub fn clearBits(_: Self, state: State) void {
                const raw = @bitCast(RawInt, state);
                if (@hasDecl(chip.gpio, "modifyOutputPort") and @hasDecl(chip.gpio, "getIOPorts")) {
                    inline for (chip.gpio.getIOPorts(pad_ids)) |port| {
                        var to_clear: chip.gpio.PortDataType = 0;
                        inline for (pad_ids) |pad, raw_bit| {
                            if (chip.gpio.getIOPort(pad) == port) {
                                if (0 == (raw & (1 << raw_bit))) {
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
            pub fn clearBitsInline(self: Self, state: State) callconv(.Inline) void {
                @call(.{ .modifier = .always_inline }, clearBits, .{ self, state });
            }
        } else struct {};

    };
}}
