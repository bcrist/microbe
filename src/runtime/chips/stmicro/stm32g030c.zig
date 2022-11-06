const microbe = @import("microbe");
const core = microbe.core;
pub usingnamespace @import("stm32g030/registers.zig");
pub const gpio = @import("stm32/gpio.zig");
pub const uart = @import("stm32g030/uart.zig");
pub const dma = @import("stm32g030/dma.zig");
pub const interrupts = core.interrupts;

pub const PadID = enum {
    PA0,    // pin 11
    PA1,    // pin 12
    PA2,    // pin 13
    PA3,    // pin 14
    PA4,    // pin 15
    PA5,    // pin 16
    PA6,    // pin 17
    PA7,    // pin 18
    PA8,    // pin 28
    PA9,    // pin 29 (and optionally pin 33, replaces PA11)
    PA10,   // pin 32 (and optionally pin 34, replaces PA12)
    PA11,   // pin 33, when not configured for PA9
    PA12,   // pin 34, when not configured for PA10
    PA13,   // pin 35
    PA14,   // pin 36
    PA15,   // pin 37

    PB0,    // pin 19
    PB1,    // pin 20
    PB2,    // pin 21
    PB3,    // pin 42
    PB4,    // pin 43
    PB5,    // pin 44
    PB6,    // pin 45
    PB7,    // pin 46
    PB8,    // pin 47
    PB9,    // pin 48
    PB10,   // pin 22
    PB11,   // pin 23
    PB12,   // pin 24
    PB13,   // pin 25
    PB14,   // pin 26
    PB15,   // pin 27

    PC6,    // pin 30
    PC7,    // pin 31
    PC13,   // pin 1
    PC14,   // pin 2
    PC15,   // pin 3

    PD0,    // pin 38
    PD1,    // pin 39
    PD2,    // pin 40
    PD3,    // pin 41

    PF0,    // pin 8
    PF1,    // pin 9
};
