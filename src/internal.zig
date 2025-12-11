pub const interrupts = struct {
    pub fn configure_enables(comptime config: anytype) void {
        const info = @typeInfo(@TypeOf(config));
        switch (info) {
            .Struct => |struct_info| {
                for (struct_info.fields) |field| {
                    chip.interrupts.set_enabled(std.enums.nameCast(chip.interrupts.Interrupt, field.name), @field(config, field.name));
                }
            },
            else => {
                @compileError("Expected a struct literal containing interrupts to enable or disable!");
            },
        }
    }

    pub fn configure_priorities(comptime config: anytype) void {
        const info = @typeInfo(@TypeOf(config));
        switch (info) {
            .Struct => |struct_info| {
                for (struct_info.fields) |field| {
                    chip.interrupts.set_priority(std.enums.nameCast(chip.interrupts.Exception, field.name), @field(config, field.name));
                }
            },
            else => {
                @compileError("Expected a struct literal containing interrupts and priorities!");
            },
        }
    }
};

pub const clocks = struct {
    pub fn check_frequency(comptime name: []const u8, comptime freq: comptime_int, comptime min: comptime_int, comptime max: comptime_int) void {
        comptime {
            if (freq < min) {
                invalid_frequency(name, freq, ">=", min);
            } else if (freq > max) {
                invalid_frequency(name, freq, "<=", max);
            }
        }
    }

    pub fn invalid_frequency(comptime name: []const u8, comptime actual: comptime_int, comptime dir: []const u8, comptime limit: comptime_int) void {
        comptime {
            @compileError(std.fmt.comptimePrint("Invalid {s} frequency: {f}; must be {s} {f}", .{
                name, microbe.fmt_frequency(actual),
                dir,  microbe.fmt_frequency(limit),
            }));
        }
    }
};

pub const gpio = struct {
    pub fn get_ports(comptime pads: []const chip.Pad_ID) []const chip.gpio.Port_ID {
        comptime {
            var ports: [pads.len]chip.gpio.Port_ID = undefined;
            var n = 0;
            outer: for (pads) |pad| {
                const port = chip.gpio.get_port(pad);
                for (ports[0..n]) |p| {
                    if (p == port) continue :outer;
                }
                ports[n] = port;
                n += 1;
            }
            const ports_copy: [n]chip.gpio.Port_ID = ports[0..n].*;
            return &ports_copy;
        }
    }

    pub fn get_pads_in_port(
        comptime pads: []const chip.Pad_ID,
        comptime port: chip.gpio.Port_ID,
        comptime min_offset: comptime_int,
        comptime max_offset: comptime_int,
    ) []const chip.Pad_ID {
        comptime {
            var pads_in_port: []const chip.Pad_ID = &.{};
            for (pads) |pad| {
                const pad_port = chip.gpio.get_port(pad);
                const pad_offset = chip.gpio.get_offset(pad);
                if (pad_port == port and pad_offset >= min_offset and pad_offset <= max_offset) {
                    pads_in_port = pads_in_port ++ &[_]chip.Pad_ID{pad};
                }
            }
            const pads_copy: [pads_in_port.len]chip.Pad_ID = pads_in_port.*;
            return &pads_copy;
        }
    }

    pub inline fn read_input(comptime pad: chip.Pad_ID) u1 {
        const offset = comptime chip.gpio.get_offset(pad);
        return @truncate(chip.gpio.read_input_port(comptime chip.gpio.get_port(pad)) >> offset);
    }

    pub inline fn read_output(comptime pad: chip.Pad_ID) u1 {
        const offset = comptime chip.gpio.get_offset(pad);
        return @truncate(chip.gpio.read_output_port(comptime chip.gpio.get_port(pad)) >> offset);
    }

    pub inline fn write_output(comptime pad: chip.Pad_ID, state: u1) void {
        const port = comptime chip.gpio.get_port(pad);
        const mask = @as(chip.gpio.Port_Data_Type, 1) << comptime chip.gpio.get_offset(pad);
        if (state == 0) {
            chip.gpio.clear_output_port_bits(port, mask);
        } else {
            chip.gpio.set_output_port_bits(port, mask);
        }
    }

    pub inline fn set_outputs(comptime pads: []const chip.Pad_ID) void {
        inline for (comptime chip.gpio.get_ports(pads)) |port| {
            var mask: chip.gpio.Port_Data_Type = 0;
            inline for (pads) |pad| {
                if (comptime chip.gpio.get_port(pad) == port) {
                    mask |= @as(chip.gpio.Port_Data_Type, 1) << comptime chip.gpio.get_offset(pad);
                }
            }
            chip.gpio.set_output_port_bits(port, mask);
        }
    }
    pub inline fn clear_outputs(comptime pads: []const chip.Pad_ID) void {
        inline for (comptime chip.gpio.get_ports(pads)) |port| {
            var mask: chip.gpio.Port_Data_Type = 0;
            inline for (pads) |pad| {
                if (comptime chip.gpio.get_port(pad) == port) {
                    mask |= @as(chip.gpio.Port_Data_Type, 1) << comptime chip.gpio.get_offset(pad);
                }
            }
            chip.gpio.clear_output_port_bits(port, mask);
        }
    }
    pub inline fn toggle_outputs(comptime pads: []const chip.Pad_ID) void {
        inline for (comptime chip.gpio.get_ports(pads)) |port| {
            var mask: chip.gpio.Port_Data_Type = 0;
            inline for (pads) |pad| {
                if (comptime chip.gpio.get_port(pad) == port) {
                    mask |= @as(chip.gpio.Port_Data_Type, 1) << comptime chip.gpio.get_offset(pad);
                }
            }
            chip.gpio.toggle_output_port_bits(port, mask);
        }
    }

    pub inline fn read_output_enable(comptime pad: chip.Pad_ID) u1 {
        const offset = comptime chip.gpio.get_offset(pad);
        return @truncate(chip.gpio.read_output_port_enables(comptime chip.gpio.get_port(pad)) >> offset);
    }

    pub inline fn write_output_enable(comptime pad: chip.Pad_ID, state: u1) void {
        const port = comptime chip.gpio.get_port(pad);
        const mask = @as(chip.gpio.Port_Data_Type, 1) << comptime chip.gpio.get_offset(pad);
        if (state == 0) {
            chip.gpio.clear_output_port_enable_bits(port, mask);
        } else {
            chip.gpio.set_output_port_enable_bits(port, mask);
        }
    }

    pub inline fn set_output_enables(comptime pads: []const chip.Pad_ID) void {
        inline for (comptime chip.gpio.get_ports(pads)) |port| {
            var mask: chip.gpio.Port_Data_Type = 0;
            inline for (pads) |pad| {
                if (comptime chip.gpio.get_port(pad) == port) {
                    mask |= @as(chip.gpio.Port_Data_Type, 1) << comptime chip.gpio.get_offset(pad);
                }
            }
            chip.gpio.set_output_port_enable_bits(port, mask);
        }
    }
    pub inline fn clear_output_enables(comptime pads: []const chip.Pad_ID) void {
        inline for (comptime chip.gpio.get_ports(pads)) |port| {
            var mask: chip.gpio.Port_Data_Type = 0;
            inline for (pads) |pad| {
                if (comptime chip.gpio.get_port(pad) == port) {
                    mask |= @as(chip.gpio.Port_Data_Type, 1) << comptime chip.gpio.get_offset(pad);
                }
            }
            chip.gpio.clear_output_port_enable_bits(port, mask);
        }
    }
    pub inline fn toggle_output_enables(comptime pads: []const chip.Pad_ID) void {
        inline for (comptime chip.gpio.get_ports(pads)) |port| {
            var mask: chip.gpio.Port_Data_Type = 0;
            inline for (pads) |pad| {
                if (comptime chip.gpio.get_port(pad) == port) {
                    mask |= @as(chip.gpio.Port_Data_Type, 1) << comptime chip.gpio.get_offset(pad);
                }
            }
            chip.gpio.toggle_output_port_enable_bits(port, mask);
        }
    }
};

const chip = @import("chip");
const microbe = @import("microbe");
const std = @import("std");
