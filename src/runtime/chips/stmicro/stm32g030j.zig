const microbe = @import("microbe");
const core = microbe.core;
pub usingnamespace @import("stm32g030/registers.zig");
pub const gpio = @import("stm32/gpio.zig");
pub const uart = @import("stm32g030/uart.zig");
pub const dma = @import("stm32g030/dma.zig");
pub const clocks = @import("stm32g030/clocks.zig");
pub const interrupts = core.interrupts;

pub const PadID = enum {
    PA0,    // pin 4, pad bonded with PA1, PA2, ~RST
    PA1,    // pin 4, pad bonded with PA0, PA2, ~RST
    PA2,    // pin 4, pad bonded with PA0, PA1, ~RST
    PA8,    // pin 5, pad bonded with PA9/PA11, PB0, PB1
    PA9,    // pin 5, when not configured for PA11, pad bonded with PA8, PB0, PB1
    PA10,   // pin 6, when not configured for PA12
    PA11,   // pin 5, when not configured for PA9, pad bonded with PA8, PB0, PB1
    PA12,   // pin 6, when not configured for PA10
    PA13,   // pin 7
    PA14,   // pin 8, pad bonded with PA15, PB5, PB6
    PA15,   // pin 8, pad bonded with PA14, PB5, PB6

    PB0,    // pin 5, pad bonded with PA8, PA9/PA11, PB1
    PB1,    // pin 5, pad bonded with PA8, PA9/PA11, PB0
    PB5,    // pin 8, pad bonded with PA14, PA15, PB6
    PB6,    // pin 8, pad bonded with PA14, PA15, PB5
    PB7,    // pin 1, pad bonded with PB8, PB9, PC14
    PB8,    // pin 1, pad bonded with PB7, PB9, PC14
    PB9,    // pin 1, pad bonded with PB7, PB8, PC14

    PC14,   // pin 1, pad bonded with PB7, PB8, PB9
};
