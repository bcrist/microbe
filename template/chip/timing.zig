pub inline fn block_at_least_cycles(min_cycles: u32) void {
    _ = min_cycles;
    @compileError("TODO");
}

pub fn current_tick() microbe.Tick {
    @compileError("TODO");
}

pub fn block_until_tick(tick: microbe.Tick) void {
    _ = tick;
    @compileError("TODO");
}

pub fn get_tick_frequency_hz() comptime_int {
    return clocks.get_config().tick.frequency_hz;
}

pub fn current_microtick() microbe.Microtick {
    @compileError("TODO");
}

pub fn block_until_microtick(tick: microbe.Microtick) void {
    _ = tick;
    @compileError("TODO");
}

pub fn get_microtick_frequency_hz() comptime_int {
    return clocks.get_config().microtick.frequency_hz;
}

const clocks = @import("clocks.zig");
const microbe = @import("microbe");
const std = @import("std");
