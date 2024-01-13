pub const Config = struct {
    name: [:0]const u8 = "JTAG",
    tck: Pad_ID,
    tms: Pad_ID,
    tdo: Pad_ID, // Note this is an input from the adapter's perspective; it retains the naming convention of the DUT
    tdi: Pad_ID, // Note this is an output from the adapter's perspective; it retains the naming convention of the DUT
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
        const pad_ids: []const Pad_ID = &.{
            config.tck,
            config.tms,
            config.tdo,
            config.tdi,
        };

        const outputs: []const Pad_ID = &.{
            config.tck,
            config.tms,
            config.tdi,
        };

        const inputs: []const Pad_ID = &.{
            config.tdo,
        };

        const clock_half_period_microticks = util.div_round(chip.get_microtick_frequency_hz(), config.max_frequency_hz * 2);

        chip.validation.pads.reserve_all(pad_ids, config.name);

        return struct {
            const Adapter_Self = @This();

            pub const max_frequency_hz = config.max_frequency_hz;

            state: State,

            pub fn init() Adapter_Self {
                chip.gpio.ensure_init(pad_ids);
                if (config.gpio_config) |gpio_config| {
                    chip.gpio.configure(pad_ids, gpio_config);
                }
                chip.gpio.set_output_enables(outputs);
                chip.gpio.clear_output_enables(inputs);
                return .{ .state = .unknown };
            }

            pub fn idle(self: *Adapter_Self, clocks: u32) void {
                self.change_state(.idle);
                chip.gpio.write_output(config.tms, 0);
                var n = clocks;
                while (n > 0) : (n -= 1) {
                    _ = self.clock_pulse();
                }
            }

            pub fn idle_until(self: *Adapter_Self, tick: Microtick, min_clocks: u32) u32 {
                self.change_state(.idle);
                chip.gpio.write_output(config.tms, 0);
                var clocks: u32 = 0;
                while (Microtick.now().is_before(tick)) {
                    _ = self.clock_pulse();
                    clocks += 1;
                }
                while (clocks < min_clocks) : (clocks += 1) {
                    _ = self.clock_pulse();
                    clocks += 1;
                }
                return clocks;
            }

            pub fn change_state(self: *Adapter_Self, target_state: State) void {
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
                    chip.gpio.write_output(config.tms, tms);
                    _ = self.clock_pulse();
                    self.state = next_state;
                }
            }

            pub fn shift_ir(self: *Adapter_Self, comptime T: type, value: T) T {
                return self.shift(.IR_shift, .IR_exit1, T, value);
            }

            pub fn shift_dr(self: *Adapter_Self, comptime T: type, value: T) T {
                return self.shift(.DR_shift, .DR_exit1, T, value);
            }

            fn shift(self: *Adapter_Self, shift_state: State, exit_state: State, comptime T: type, value: T) T {
                if (@bitSizeOf(T) == 0) {
                    return @as(T, @bitCast({}));
                }
                self.change_state(shift_state);
                chip.gpio.write_output(config.tms, 0);
                const IntT = std.meta.Int(.unsigned, @bitSizeOf(T));
                var bitsRemaining: u32 = @bitSizeOf(T);
                var valueRemaining = util.to_int(IntT, value);
                var capture: IntT = 0;
                while (bitsRemaining > 1) : (bitsRemaining -= 1) {
                    chip.gpio.write_output(config.tdi, @as(u1, @truncate(valueRemaining)));
                    valueRemaining >>= 1;
                    capture >>= 1;
                    if (self.clock_pulse() == 1) {
                        capture |= @shlExact(@as(IntT, 1), @bitSizeOf(T) - 1);
                    }
                }
                chip.gpio.write_output(config.tms, 1);
                chip.gpio.write_output(config.tdi, @as(u1, @truncate(valueRemaining)));
                capture >>= 1;
                if (self.clock_pulse() == 1) {
                    capture |= @shlExact(@as(IntT, 1), @bitSizeOf(T) - 1);
                }
                self.state = exit_state;

                return util.from_int(T, capture);
            }

            fn clock_pulse(_: Adapter_Self) u1 {
                chip.gpio.write_output(config.tck, 0);
                var t = Microtick.now().plus(.{ .ticks = clock_half_period_microticks });
                chip.timing.block_until_microtick(t);
                const bit = chip.gpio.read_input(config.tdo);
                chip.gpio.write_output(config.tck, 1);
                t = t.plus(.{ .ticks = clock_half_period_microticks });
                chip.timing.block_until_microtick(t);
                return bit;
            }

            pub fn TAP(comptime index: comptime_int) type {
                return struct {
                    const TAP_Self = @This();
                    const Instruction_Type = config.chain[index];
                    adapter: *Adapter_Self,

                    pub fn instruction(self: TAP_Self, insn: Instruction_Type, ending_state: State) void {
                        inline for (config.chain, 0..) |T, i| {
                            if (i == index) {
                                _ = self.adapter.shift_ir(Instruction_Type, insn);
                            } else {
                                const BypassType = std.meta.Int(.unsigned, @bitSizeOf(T));
                                _ = self.adapter.shift_ir(BypassType, ~@as(BypassType, 0));
                            }
                        }
                        self.adapter.change_state(ending_state);
                    }

                    pub fn data(self: TAP_Self, comptime T: type, value: T, ending_state: State) T {
                        if (index > 0) {
                            const BypassType = std.meta.Int(.unsigned, index);
                            _ = self.adapter.shift_dr(BypassType, 0);
                        }
                        const capture = self.adapter.shift_dr(T, value);
                        if (index < config.chain.len - 1) {
                            const BypassType = std.meta.Int(.unsigned, config.chain.len - index - 1);
                            _ = self.adapter.shift_dr(BypassType, 0);
                        }
                        self.adapter.change_state(ending_state);
                        return capture;
                    }
                };
            }

            pub fn tap(self: *Adapter_Self, comptime index: comptime_int) TAP(index) {
                return .{ .adapter = self };
            }
        };
    }
}

const Microtick = @import("timing.zig").Microtick;
pub const Pad_ID = chip.Pad_ID;
const chip = @import("chip_interface.zig");
const mmio = @import("mmio.zig");
const util = @import("util.zig");
const std = @import("std");
