const std = @import("std");
const microbe = @import("microbe");
const chip = microbe.chip;

pub const PadID = chip.PadID;
pub const IOPort = chip.registers.types.gpio.IOPort;
pub const IOMode = chip.registers.types.gpio.IOMode;
pub const SlewRate = chip.registers.types.gpio.SlewRate;
pub const DriveMode = chip.registers.types.gpio.DriveMode;
pub const TerminationMode = chip.registers.types.gpio.TerminationMode;

pub const PortDataType = u16;

pub fn getOffset(comptime pad: PadID) comptime_int { comptime {
    return std.fmt.parseInt(u4, @tagName(pad)[2..], 10) catch unreachable;
}}

pub fn getIOPort(comptime pad: PadID) IOPort { comptime {
    return @field(IOPort, @tagName(pad)[1..2]);
}}

pub fn getIOPorts(comptime pads: []const PadID) []const IOPort { comptime {
    var ports: []const IOPort = &[_]IOPort {};
    outer: inline for (pads) |pad| {
        const port = getIOPort(pad);
        inline for (ports) |p| {
            if (p == port) continue :outer;
        }
        ports = ports ++ &[_]IOPort { port };
    }
    return ports;
}}

pub fn getPadsInPort(
    comptime pads: []const PadID,
    comptime port: IOPort,
    comptime min_offset: comptime_int,
    comptime max_offset: comptime_int,
) []const PadID { comptime {
    var pads_in_port: []const PadID = &.{};
    inline for (pads) |pad| {
        const pad_port = getIOPort(pad);
        const pad_offset = getOffset(pad);
        if (pad_port == port and pad_offset >= min_offset and pad_offset <= max_offset) {
            pads_in_port = pads_in_port ++ &[_]PadID { pad };
        }
    }
    return pads_in_port;
}}

pub fn ensurePortsEnabled(comptime pads: []const PadID) void {
    var v = chip.registers.RCC.IOPENR.read();
    inline for (comptime getIOPorts(pads)) |port| {
        @field(v, "GPIO" ++ @tagName(port) ++ "EN") = .clock_enabled;
    }
    chip.registers.RCC.IOPENR.write(v);
}

pub fn configureSlewRate(comptime pads: []const PadID, comptime slew: SlewRate) void {
    inline for (comptime getIOPorts(pads)) |port| {
        const port_regs = @field(chip.registers, "GPIO" ++ @tagName(port));
        var v = port_regs.OSPEEDR.read();
        inline for (comptime getPadsInPort(pads, port, 0, 15)) |pad| {
            @field(v, "OSPEEDR" ++ @tagName(pad)[2..]) = slew;
        }
        port_regs.OSPEEDR.write(v);
    }
}

pub fn configureDriveMode(comptime pads: []const PadID, comptime mode: DriveMode) void {
    inline for (comptime getIOPorts(pads)) |port| {
        const port_regs = @field(chip.registers, "GPIO" ++ @tagName(port));
        var v = port_regs.OTYPER.read();
        inline for (comptime getPadsInPort(pads, port, 0, 15)) |pad| {
            @field(v, "OT" ++ @tagName(pad)[2..]) = mode;
        }
        port_regs.OTYPER.write(v);
    }
}

pub fn configureTermination(comptime pads: []const PadID, comptime mode: TerminationMode) void {
    inline for (comptime getIOPorts(pads)) |port| {
        const port_regs = @field(chip.registers, "GPIO" ++ @tagName(port));
        var v = port_regs.PUPDR.read();
        inline for (comptime getPadsInPort(pads, port, 0, 15)) |pad| {
            @field(v, "PUPD" ++ @tagName(pad)[2..]) = mode;
        }
        port_regs.PUPDR.write(v);
    }
}

pub fn configureMODER(comptime pads: []const PadID, comptime mode: IOMode) void {
    inline for (comptime getIOPorts(pads)) |port| {
        const port_regs = @field(chip.registers, "GPIO" ++ @tagName(port));
        var v = port_regs.MODER.read();
        inline for (comptime getPadsInPort(pads, port, 0, 15)) |pad| {
            @field(v, "MODER" ++ @tagName(pad)[2..]) = mode;
        }
        port_regs.MODER.write(v);
    }
}

pub fn configureAsInput(comptime pads: []const PadID) void {
    configureMODER(pads, .input);
}
pub fn configureAsOutput(comptime pads: []const PadID) void {
    configureMODER(pads, .output);
}
pub fn configureAsUnused(comptime pads: []const PadID) void {
    configureMODER(pads, .analog);
}
pub fn configureAsAlternateFunction(comptime pads: []const PadID, comptime afs: []const []const u8) void {
    inline for (comptime getIOPorts(pads)) |port| {
        const port_regs = @field(chip.registers, "GPIO" ++ @tagName(port));
        const afrl_pads = comptime getPadsInPort(pads, port, 0, 7);
        const afrh_pads = comptime getPadsInPort(pads, port, 8, 15);

        if (afrl_pads.len > 0) {
            var v = port_regs.AFRL.read();
            inline for (pads) |pad, i| {
                const pad_port = getIOPort(pad);
                const pad_offset = getOffset(pad);
                if (pad_port == port and pad_offset >= 0 and pad_offset <= 7) {
                    const AFType = @field(chip.registers.types.gpio, @tagName(pad) ++ "_AF");
                    @field(v, "AFSEL" ++ @tagName(pad)[2..]) = std.enums.nameCast(AFType, afs[i]);
                }
            }
            port_regs.AFRL.write(v);
        }
        if (afrh_pads.len > 0) {
            var v = port_regs.AFRH.read();
            inline for (pads) |pad, i| {
                const pad_port = getIOPort(pad);
                const pad_offset = getOffset(pad);
                if (pad_port == port and pad_offset >= 8 and pad_offset <= 15) {
                    const AFType = @field(chip.registers.types.gpio, @tagName(pad) ++ "_AF");
                    @field(v, "AFSEL" ++ @tagName(pad)[2..]) = std.enums.nameCast(AFType, afs[i]);
                }
            }
            port_regs.AFRH.write(v);
        }
    }
    configureMODER(pads, .alternate_function);
}

pub fn isOutput(comptime pad: PadID) bool {
    const port = getIOPort(pad);
    var v = @field(chip.registers, "GPIO" ++ @tagName(port)).MODER.read();
    return @field(v, "MODER" ++ @tagName(pad)[2..]) == .output;
}

pub fn readInputPort(comptime port: IOPort) u16 {
    return @truncate(u16, @field(chip.registers, "GPIO" ++ @tagName(port)).IDR.raw);
}

pub fn readOutputPort(comptime port: IOPort) u16 {
    return @truncate(u16, @field(chip.registers, "GPIO" ++ @tagName(port)).ODR.raw);
}

pub fn writeOutputPort(comptime port: IOPort, state: u16) void {
    const state32: u32 = state;
    @field(chip.registers, "GPIO" ++ @tagName(port)).ODR.raw = state32;
}

pub fn modifyOutputPort(comptime port: IOPort, bits_to_clear: u16, bits_to_set: u16) void {
    const bsr = @as(u32, bits_to_set) | @shlExact(@as(u32, bits_to_clear), 16);
    @field(chip.registers, "GPIO" ++ @tagName(port)).BSRR.raw = bsr;
}

pub fn readInput(comptime pad: PadID) u1 {
    const port = getIOPort(pad);
    var v = @field(chip.registers, "GPIO" ++ @tagName(port)).IDR.read();
    return @field(v, "D" ++ @tagName(pad)[2..]);
}

pub fn readOutput(comptime pad: PadID) u1 {
    const port = getIOPort(pad);
    var v = @field(chip.registers, "GPIO" ++ @tagName(port)).ODR.read();
    return @field(v, "D" ++ @tagName(pad)[2..]);
}

pub fn writeOutput(comptime pad: PadID, state: u1) void {
    const port = getIOPort(pad);
    if (state == 0) {
        const BRR = chip.registers.types.gpio.BRR;
        const v = BRR {};
        @field(v, "BR" ++ @tagName(pad)[2..]) = .reset;
        @field(chip.registers, "GPIO" ++ @tagName(port)).BRR.write(v);
    } else {
        const BSRR = chip.registers.types.gpio.BSRR;
        const v = BSRR {};
        @field(v, "BS" ++ @tagName(pad)[2..]) = .set;
        @field(chip.registers, "GPIO" ++ @tagName(port)).BSRR.write(v);
    }
}
