const std = @import("std");
const microbe = @import("microbe");
const core = microbe.core;
const chip = @import("stm32g030/registers.zig");
pub usingnamespace chip;
const reg = chip.registers;

pub const interrupts = core.interrupts;

pub const uart = @import("stm32g030/uart.zig");
pub const Uart = uart.Uart;
