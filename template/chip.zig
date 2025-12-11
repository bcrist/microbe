pub fn init_exports() void {
    @compileError("TODO");
}

pub const validation = @import("chip/validation.zig");
pub const interrupts = @import("chip/interrupts.zig");
pub const Interrupt = interrupts.Interrupt;
pub const Exception = interrupts.Exception;
pub const clocks = @import("chip/clocks.zig");
pub const timing = @import("chip/timing.zig");
pub const gpio = @import("chip/gpio.zig");
pub const usb = @import("chip/usb.zig");

pub const base_name = "My Chip Name";
pub const core_name = "My Chip's Core Name";

pub const Pad_ID = enum { };

pub inline fn modify_register(comptime reg: *volatile u32, comptime bits_to_set: u32, comptime bits_to_clear: u32) void {
    var val = reg.*;
    val |= bits_to_set;
    val &= ~bits_to_clear;
    reg.* = val;
}

pub inline fn toggle_register_bits(comptime reg: *volatile u32, bits_to_toggle: u32) void {
    var val = reg.*;
    val ^= bits_to_toggle;
    reg.* = val;
}

pub inline fn set_register_bits(comptime reg: *volatile u32, bits_to_set: u32) void {
    var val = reg.*;
    val |= bits_to_set;
    reg.* = val;
}

pub inline fn clear_register_bits(comptime reg: *volatile u32, bits_to_clear: u32) void {
    var val = reg.*;
    val &= ~bits_to_clear;
    reg.* = val;
}
