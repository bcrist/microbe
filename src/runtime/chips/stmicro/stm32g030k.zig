const microbe = @import("microbe");
const core = microbe.core;
pub usingnamespace @import("stm32g030/registers.zig");
pub const gpio = @import("stm32/gpio.zig");
pub const uart = @import("stm32g030/uart.zig");
pub const dma = @import("stm32g030/dma.zig");
pub const clocks = @import("stm32g030/clocks.zig");
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
    PA8,    // pin 18
    PA9,    // pin 19 (and optionally pin 22, replaces PA11)
    PA10,   // pin 21 (and optionally pin 23, replaces PA12)
    PA11,   // pin 22, when not configured for PA9
    PA12,   // pin 23, when not configured for PA10
    PA13,   // pin 24
    PA14,   // pin 25
    PA15,   // pin 26

    PB0,    // pin 15
    PB1,    // pin 16
    PB2,    // pin 17
    PB3,    // pin 27
    PB4,    // pin 28
    PB5,    // pin 29
    PB6,    // pin 30
    PB7,    // pin 31
    PB8,    // pin 32
    PB9,    // pin 1

    PC6,    // pin 20
    PC14,   // pin 2
    PC15,   // pin 3
};
