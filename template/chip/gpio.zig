pub const Port_ID = enum {};
pub const Port_Data_Type = u32;
pub const Config = struct {};

pub fn get_port(comptime pad: Pad_ID) Port_ID {
    _ = pad;
    @compileError("TODO");
}

pub const get_ports = defaults.gpio.get_ports;

pub fn get_offset(comptime pad: Pad_ID) comptime_int {
    _ = pad;
    @compileError("TODO");
}

pub const get_pads_in_port = defaults.gpio.get_pads_in_port;

pub fn configure(comptime pads: []const Pad_ID, config: Config) void {
    _ = pads;
    _ = config;
    @compileError("TODO");
}

pub fn ensure_init(comptime pads: []const Pad_ID) void {
    _ = pads;
    @compileError("TODO");
}

pub fn read_input_port(comptime port: Port_ID) Port_Data_Type {
    _ = port;
    @compileError("TODO");
}

pub fn read_output_port(comptime port: Port_ID) Port_Data_Type {
    _ = port;
    @compileError("TODO");
}

pub fn write_output_port(comptime port: Port_ID, state: Port_Data_Type) void {
    _ = port;
    _ = state;
    @compileError("TODO");
}

pub fn clear_output_port_bits(comptime port: Port_ID, bits_to_clear: Port_Data_Type) void {
    _ = port;
    _ = bits_to_clear;
    @compileError("TODO");
}

pub fn set_output_port_bits(comptime port: Port_ID, bits_to_set: Port_Data_Type) void {
    _ = port;
    _ = bits_to_set;
    @compileError("TODO");
}

pub fn toggle_output_port_bits(comptime port: Port_ID, bits_to_toggle: Port_Data_Type) void {
    _ = port;
    _ = bits_to_toggle;
    @compileError("TODO");
}

pub fn modify_output_port(comptime port: Port_ID, bits_to_clear: Port_Data_Type, bits_to_set: Port_Data_Type) void {
    _ = port;
    _ = bits_to_clear;
    _ = bits_to_set;
    @compileError("TODO");
}

pub fn read_output_port_enables(comptime port: Port_ID) Port_Data_Type {
    _ = port;
    @compileError("TODO");
}

pub fn write_output_port_enables(comptime port: Port_ID, state: Port_Data_Type) void {
    _ = port;
    _ = state;
    @compileError("TODO");
}

pub fn clear_output_port_enable_bits(comptime port: Port_ID, bits_to_clear: Port_Data_Type) void {
    _ = port;
    _ = bits_to_clear;
    @compileError("TODO");
}

pub fn set_output_port_enable_bits(comptime port: Port_ID, bits_to_set: Port_Data_Type) void {
    _ = port;
    _ = bits_to_set;
    @compileError("TODO");
}

pub fn toggle_output_port_enable_bits(comptime port: Port_ID, bits_to_toggle: Port_Data_Type) void {
    _ = port;
    _ = bits_to_toggle;
    @compileError("TODO");
}

pub fn modify_output_port_enables(comptime port: Port_ID, bits_to_clear: Port_Data_Type, bits_to_set: Port_Data_Type) void {
    _ = port;
    _ = bits_to_clear;
    _ = bits_to_set;
    @compileError("TODO");
}

pub const read_input = defaults.gpio.read_input;
pub const read_output = defaults.gpio.read_output;
pub const write_output = defaults.gpio.write_output;
pub const set_outputs = defaults.gpio.set_outputs;
pub const clear_outputs = defaults.gpio.clear_ouputs;
pub const toggle_outputs = defaults.gpio.toggle_outputs;
pub const read_output_enable = defaults.gpio.read_output_enable;
pub const write_output_enable = defaults.gpio.write_output_enable;
pub const set_output_enables = defaults.gpio.set_output_enables;
pub const clear_output_enables = defaults.gpio.clear_output_enables;
pub const toggle_output_enables = defaults.gpio.toggle_output_enables;

const Pad_ID = @import("../chip.zig").Pad_ID;
const defaults = @import("microbe_internal");
