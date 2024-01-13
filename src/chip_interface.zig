const chip = @import("chip");

pub const Pad_ID = chip.Pad_ID;

pub const interrupts = struct {
    const i = chip.interrupts;

    pub const Interrupt = i.Interrupt;
    pub const Exception = i.Exception;
    pub const Handler = i.Handler;

    pub const unhandled = i.unhandled; // (comptime Exception) -> Handler

    pub const is_enabled = i.is_enabled; // (comptime Interrupt) -> bool
    pub const set_enabled = i.set_enabled; // (comptime Interrupt, comptime bool) -> void
    pub const configure_enables = i.configure_enables; // (comptime anytype) -> void
    pub const get_priority = i.get_priority; // (comptime Exception) -> u8
    pub const set_priority = i.set_priority; // (comptime Exception, u8) -> void
    pub const configure_priorities = i.configure_priorities; // (comptime anytype) -> void
    pub const is_pending = i.is_pending; // (comptime Exception) -> bool
    pub const set_pending = i.set_pending; // (comptime Exception, comptime bool) -> void
    pub const are_globally_enabled = i.are_globally_enabled; // () -> bool
    pub const set_globally_enabled = i.set_globally_enabled; // (bool) -> void
    pub const current_exception = i.current_exception; // () -> Exception
    pub const is_in_handler = i.is_in_handler; // () -> bool
    pub const wait_for_interrupt = i.wait_for_interrupt; // () -> void
    pub const wait_for_event = i.wait_for_event; // () -> void
    pub const send_event = i.send_event; // () -> void
};

pub const gpio = struct {
    const i = chip.gpio;

    pub const Port_ID = i.Port_ID;
    pub const Port_Data_Type = i.Port_Data_Type; // typically u16 or u32
    pub const get_port = i.get_port; //  (comptime Pad_ID) -> Port_ID
    pub const get_ports = i.get_ports; // (comptime []const Pad_ID) -> []const Port_ID
    pub const get_offset = i.get_offset; // (comptime Pad_ID) -> comptime_int
    pub const get_pads_in_port = i.get_pads_in_port; // (comptime []const Pad_ID, comptime Port_ID, comptime_int, comptime_int) -> []const Pad_ID

    pub const ensure_init = i.ensure_init; // (comptime []const Pad_ID) -> void
    pub const Config = i.Config; // struct containing slew rate, pull up/down, etc.
    pub const configure = i.configure; // (comptime []const Pad_ID, Config) -> void

    pub const read_input_port = i.read_input_port; // (comptime Port_ID) -> Port_Data_Type

    pub const read_output_port = i.read_output_port; // (comptime Port_ID) -> Port_Data_Type
    pub const write_output_port = i.write_output_port; // (comptime Port_ID, Port_Data_Type) -> void
    pub const clear_output_port_bits = i.clear_output_port_bits; // (comptime Port_ID, clear: Port_Data_Type) -> void
    pub const set_output_port_bits = i.set_output_port_bits; // (comptime Port_ID, set: Port_Data_Type) -> void
    pub const modify_output_port = i.modify_output_port; // (comptime Port_ID, clear: Port_Data_Type, set: Port_Data_Type) -> void

    pub const read_output_port_enables = i.read_output_port_enables; // (comptime Port_ID) -> Port_Data_Type
    pub const write_output_port_enables = i.write_output_port_enables; // (comptime Port_ID) -> Port_Data_Type
    pub const clear_output_port_enable_bits = i.clear_output_port_enable_bits; // (comptime Port_ID, clear: Port_Data_Type) -> void
    pub const set_output_port_enable_bits = i.set_output_port_enable_bits; // (comptime Port_ID, set: Port_Data_Type) -> void
    pub const modify_output_port_enables = i.modify_output_port_enables; // (comptime Port_ID, clear: Port_Data_Type, set: Port_Data_Type) -> void

    pub const read_input = i.read_input; // (comptime Pad_ID) -> u1

    pub const read_output = i.read_output; // (comptime Pad_ID) -> u1
    pub const write_output = i.write_output; // (comptime Pad_ID, u1) -> void

    pub const read_output_enable = i.read_output_enable; // (comptime Pad_ID) -> u1
    pub const write_output_enable = i.write_output_enable; // (comptime Pad_ID, u1) -> void
    pub const set_output_enables = i.set_output_enables; // (comptime []const Pad_ID) -> void
    pub const clear_output_enables = i.clear_output_enables; // (comptime []const Pad_ID) -> void

};

pub const validation = struct {
    const i = chip.validation;
    pub const pads = i.pads; // Comptime_Resource_Validator(Pad_ID)
};

pub const timing = struct {
    const i = chip.timing;

    pub const current_tick = i.current_tick;
    pub const block_until_tick = i.block_until_tick;
    pub const get_tick_frequency_hz = i.get_tick_frequency_hz;

    pub const current_microtick = i.current_microtick;
    pub const block_until_microtick = i.block_until_microtick;
    pub const get_microtick_frequency_hz = i.get_microtick_frequency_hz;
};

pub const clocks = struct {
    const i = chip.clocks;

    pub const Config = i.Config;
    pub const Parsed_Config = i.Parsed_Config;
    pub const get_config = i.get_config;
    pub const apply_config = i.apply_config;
};
