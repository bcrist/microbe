const microbe = @import("microbe");
const core = microbe.core;
pub usingnamespace @import("stm32g030/registers.zig");
pub const gpio = @import("stm32/gpio.zig");
pub const uart = @import("stm32g030/uart.zig");
pub const dma = @import("stm32g030/dma.zig");
pub const interrupts = core.interrupts;

pub const PadID = enum {
    PA0,    // pin 7
    PA1,    // pin 8
    PA2,    // pin 9
    PA3,    // pin 10
    PA4,    // pin 11
    PA5,    // pin 12
    PA6,    // pin 13
    PA7,    // pin 14
    PA8,    // pin 15, pad bonded with PB0, PB1, PB2
    PA9,    // pin 16, when not configured for PA11
    PA10,   // pin 17, when not configured for PA12
    PA11,   // pin 16, when not configured for PA9
    PA12,   // pin 17, when not configured for PA10

    PA13,   // pin 18
    PA14,   // pin 19, pad bonded with PA15
    PA15,   // pin 19, pad bonded with PA14

    PB0,    // pin 15, pad bonded with PA8, PB1, PB2
    PB1,    // pin 15, pad bonded with PA8, PB0, PB2
    PB2,    // pin 15, pad bonded with PA8, PB0, PB1
    PB3,    // pin 20, pad bonded with PB4, PB5, PB6
    PB4,    // pin 20, pad bonded with PB3, PB5, PB6
    PB5,    // pin 20, pad bonded with PB3, PB4, PB6
    PB6,    // pin 20, pad bonded with PB3, PB4, PB5
    PB7,    // pin 1, pad bonded with PB8
    PB8,    // pin 1, pad bonded with PB7
    PB9,    // pin 2, pad bonded with PC14

    PC14,   // pin 2, pad bonded with PB9
    PC15,   // pin 3
};
