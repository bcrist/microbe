const std = @import("std");
const chip = @import("chip_interface.zig");
const chip_util = @import("chip_util");
const mmio = @import("mmio.zig");
const Microtick = @import("timing.zig").Microtick;

pub const PadID = chip.PadID;

pub const Config = struct {
    name: [:0]const u8 = "JTAG",
    tck: PadID,
    tms: PadID,
    tdo: PadID, // Note this is an input from the adapter's perspective; it retains the naming convention of the DUT
    tdi: PadID, // Note this is an output from the adapter's perspective; it retains the naming convention of the DUT
    gpio_config: ?chip.gpio.Config = null,
    max_frequency_hz: comptime_int,
    chain: []const type,
};

pub const State = enum {
    unknown,
    unknown2,
    unknown3,
    unknown4,
    unknown5,
    reset,
    idle,
    DR_select,
    DR_capture,
    DR_shift,
    DR_exit1,
    DR_pause,
    DR_exit2,
    DR_update,
    IR_select,
    IR_capture,
    IR_shift,
    IR_exit1,
    IR_pause,
    IR_exit2,
    IR_update,
};

pub fn Adapter(comptime config: Config) type {
    comptime {
        var pad_ids: []const PadID = &.{
            config.tck,
            config.tms,
            config.tdo,
            config.tdi,
        };

        var outputs: []const PadID = &.{
            config.tck,
            config.tms,
            config.tdi,
        };

        var inputs: []const PadID = &.{
            config.tdo,
        };

        const clock_half_period_microticks = chip_util.divRound(chip.getMicrotickFrequencyHz(), config.max_frequency_hz * 2);

        chip.validation.pads.reserveAll(pad_ids, config.name);

        return struct {
            const AdapterSelf = @This();

            pub const max_frequency_hz = config.max_frequency_hz;

            state: State,

            pub fn init() AdapterSelf {
                chip.gpio.ensureInit(pad_ids);
                if (config.gpio_config) |gpio_config| {
                    chip.gpio.configure(pad_ids, gpio_config);
                }
                chip.gpio.setOutputEnables(outputs);
                chip.gpio.clearOutputEnables(inputs);
                return .{ .state = .unknown };
            }

            pub fn idle(self: *AdapterSelf, clocks: u32) void {
                self.changeState(.idle);
                chip.gpio.writeOutput(config.tms, 0);
                var n = clocks;
                while (n > 0) : (n -= 1) {
                    _ = self.clockPulse();
                }
            }

            pub fn idleUntil(self: *AdapterSelf, tick: Microtick, min_clocks: u32) u32 {
                self.changeState(.idle);
                chip.gpio.writeOutput(config.tms, 0);
                var clocks: u32 = 0;
                while (Microtick.now().isBefore(tick)) {
                    _ = self.clockPulse();
                    clocks += 1;
                }
                while (clocks < min_clocks) : (clocks += 1) {
                    _ = self.clockPulse();
                    clocks += 1;
                }
                return clocks;
            }

            pub fn changeState(self: *AdapterSelf, target_state: State) void {
                while (self.state != target_state) {
                    var tms: u1 = 1;
                    const next_state: State = switch (self.state) {
                        .unknown => .unknown2,
                        .unknown2 => .unknown3,
                        .unknown3 => .unknown4,
                        .unknown4 => .unknown5,
                        .unknown5 => .reset,
                        .reset => next: {
                            tms = 0;
                            break :next .idle;
                        },
                        .idle => .DR_select,
                        .DR_select => switch (target_state) {
                            .DR_capture, .DR_shift, .DR_exit1, .DR_pause, .DR_exit2, .DR_update => next: {
                                tms = 0;
                                break :next .DR_capture;
                            },
                            else => .IR_select,
                        },
                        .DR_capture => switch (target_state) {
                            .DR_shift => next: {
                                tms = 0;
                                break :next .DR_shift;
                            },
                            else => .DR_exit1,
                        },
                        .DR_shift => .DR_exit1,
                        .DR_exit1 => switch (target_state) {
                            .DR_pause, .DR_exit2, .DR_shift => next: {
                                tms = 0;
                                break :next .DR_pause;
                            },
                            else => .DR_update,
                        },
                        .DR_pause => .DR_exit2,
                        .DR_exit2 => switch (target_state) {
                            .DR_shift, .DR_exit1, .DR_pause => next: {
                                // TODO target_state of DR_exit1 or DR_pause doesn't really make
                                // sense here, since it will end up shifting a bit unexpectedly.
                                // But it's probably better than panicing.
                                tms = 0;
                                break :next .DR_shift;
                            },
                            else => .DR_update,
                        },
                        .DR_update => switch (target_state) {
                            .idle => next: {
                                tms = 0;
                                break :next .idle;
                            },
                            else => .DR_select,
                        },
                        .IR_select => switch (target_state) {
                            .IR_capture, .IR_shift, .IR_exit1, .IR_pause, .IR_exit2, .IR_update => next: {
                                tms = 0;
                                break :next .IR_capture;
                            },
                            else => .reset,
                        },
                        .IR_capture => switch (target_state) {
                            .IR_shift => next: {
                                tms = 0;
                                break :next .IR_shift;
                            },
                            else => .IR_exit1,
                        },
                        .IR_shift => .IR_exit1,
                        .IR_exit1 => switch (target_state) {
                            .IR_pause, .IR_exit2, .IR_shift => next: {
                                tms = 0;
                                break :next .DR_pause;
                            },
                            else => .IR_update,
                        },
                        .IR_pause => .IR_exit2,
                        .IR_exit2 => switch (target_state) {
                            .IR_shift, .IR_exit1, .IR_pause => next: {
                                // TODO target_state of IR_exit1 or IR_pause doesn't really make
                                // sense here, since it will end up shifting a bit unexpectedly.
                                // But it's probably better than panicing.
                                tms = 0;
                                break :next .IR_shift;
                            },
                            else => .IR_update,
                        },
                        .IR_update => switch (target_state) {
                            .idle => next: {
                                tms = 0;
                                break :next .idle;
                            },
                            else => .DR_select,
                        },
                    };
                    chip.gpio.writeOutput(config.tms, tms);
                    _ = self.clockPulse();
                    self.state = next_state;
                }
            }

            pub fn shiftIR(self: *AdapterSelf, comptime T: type, value: T) T {
                return self.shift(.IR_shift, .IR_exit1, T, value);
            }

            pub fn shiftDR(self: *AdapterSelf, comptime T: type, value: T) T {
                return self.shift(.DR_shift, .DR_exit1, T, value);
            }

            fn shift(self: *AdapterSelf, shift_state: State, exit_state: State, comptime T: type, value: T) T {
                if (@bitSizeOf(T) == 0) {
                    return @as(T, @bitCast({}));
                }
                self.changeState(shift_state);
                chip.gpio.writeOutput(config.tms, 0);
                const IntT = std.meta.Int(.unsigned, @bitSizeOf(T));
                var bitsRemaining: u32 = @bitSizeOf(T);
                var valueRemaining = mmio.toInt(IntT, value);
                var capture: IntT = 0;
                while (bitsRemaining > 1) : (bitsRemaining -= 1) {
                    chip.gpio.writeOutput(config.tdi, @as(u1, @truncate(valueRemaining)));
                    valueRemaining >>= 1;
                    capture >>= 1;
                    if (self.clockPulse() == 1) {
                        capture |= @shlExact(@as(IntT, 1), @bitSizeOf(T) - 1);
                    }
                }
                chip.gpio.writeOutput(config.tms, 1);
                chip.gpio.writeOutput(config.tdi, @as(u1, @truncate(valueRemaining)));
                capture >>= 1;
                if (self.clockPulse() == 1) {
                    capture |= @shlExact(@as(IntT, 1), @bitSizeOf(T) - 1);
                }
                self.state = exit_state;

                return mmio.fromInt(T, capture);
            }

            fn clockPulse(_: AdapterSelf) u1 {
                chip.gpio.writeOutput(config.tck, 0);
                var t = Microtick.now().plus(.{ .ticks = clock_half_period_microticks });
                chip.timing.blockUntilMicrotick(t);
                const bit = chip.gpio.readInput(config.tdo);
                chip.gpio.writeOutput(config.tck, 1);
                t = t.plus(.{ .ticks = clock_half_period_microticks });
                chip.timing.blockUntilMicrotick(t);
                return bit;
            }

            pub fn TAP(comptime index: comptime_int) type {
                return struct {
                    const TAPSelf = @This();
                    const InstructionType = config.chain[index];
                    adapter: *AdapterSelf,

                    pub fn instruction(self: TAPSelf, insn: InstructionType, ending_state: State) void {
                        inline for (config.chain, 0..) |T, i| {
                            if (i == index) {
                                _ = self.adapter.shiftIR(InstructionType, insn);
                            } else {
                                const BypassType = std.meta.Int(.unsigned, @bitSizeOf(T));
                                _ = self.adapter.shiftIR(BypassType, ~@as(BypassType, 0));
                            }
                        }
                        self.adapter.changeState(ending_state);
                    }

                    pub fn data(self: TAPSelf, comptime T: type, value: T, ending_state: State) T {
                        if (index > 0) {
                            const BypassType = std.meta.Int(.unsigned, index);
                            _ = self.adapter.shiftDR(BypassType, 0);
                        }
                        const capture = self.adapter.shiftDR(T, value);
                        if (index < config.chain.len - 1) {
                            const BypassType = std.meta.Int(.unsigned, config.chain.len - index - 1);
                            _ = self.adapter.shiftDR(BypassType, 0);
                        }
                        self.adapter.changeState(ending_state);
                        return capture;
                    }
                };
            }

            pub fn tap(self: *AdapterSelf, comptime index: comptime_int) TAP(index) {
                return .{ .adapter = self };
            }
        };
    }
}
