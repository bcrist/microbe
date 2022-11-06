const std = @import("std");

pub const InterruptEnable = enum(u1) {
    interrupt_disabled = 0,
    interrupt_enabled = 1,
};

pub const InterruptFlag = enum(u1) {
    interrupt_not_active = 0,
    interrupt_pending = 1,
};

pub const InterruptClearFlag = enum(u1) {
    no_action = 0,
    clear_interrupt = 1,
};

pub const ErrorFlag = enum(u1) {
    no_error = 0,
    error_detected = 1,
};

pub const ErrorClearFlag = enum(u1) {
    no_action = 0,
    clear_error = 1,
};

pub const PeripheralReset = enum(u1) {
    no_action = 0,
    reset_peripheral = 1,
};

pub const gpio = struct {

    pub const IOPort = enum {
        A,
        B,
        C,
        D,
        F,
    };

    pub const IOMode = enum(u2) {
        input = 0,
        output = 1,
        alternate_function = 2,
        analog = 3,
    };

    pub const MODER = packed struct {
        MODER0: IOMode = .analog,
        MODER1: IOMode = .analog,
        MODER2: IOMode = .analog,
        MODER3: IOMode = .analog,
        MODER4: IOMode = .analog,
        MODER5: IOMode = .analog,
        MODER6: IOMode = .analog,
        MODER7: IOMode = .analog,
        MODER8: IOMode = .analog,
        MODER9: IOMode = .analog,
        MODER10: IOMode = .analog,
        MODER11: IOMode = .analog,
        MODER12: IOMode = .analog,
        MODER13: IOMode = .analog,
        MODER14: IOMode = .analog,
        MODER15: IOMode = .analog,

        pub fn init(all: IOMode) MODER {
            return .{
                .MODER0 = all,
                .MODER1 = all,
                .MODER2 = all,
                .MODER3 = all,
                .MODER4 = all,
                .MODER5 = all,
                .MODER6 = all,
                .MODER7 = all,
                .MODER8 = all,
                .MODER9 = all,
                .MODER10 = all,
                .MODER11 = all,
                .MODER12 = all,
                .MODER13 = all,
                .MODER14 = all,
                .MODER15 = all,
            };
        }
    };

    pub const GPIOA_MODER_reset_value = MODER {
        .MODER13 = .alternate_function,
        .MODER14 = .alternate_function,
    };

    pub const DriveMode = enum(u1) {
        push_pull = 0,
        open_drain = 1,

        pub const default = DriveMode.push_pull;
    };

    pub const OTYPER = packed struct {
        OT0: DriveMode = .push_pull,
        OT1: DriveMode = .push_pull,
        OT2: DriveMode = .push_pull,
        OT3: DriveMode = .push_pull,
        OT4: DriveMode = .push_pull,
        OT5: DriveMode = .push_pull,
        OT6: DriveMode = .push_pull,
        OT7: DriveMode = .push_pull,
        OT8: DriveMode = .push_pull,
        OT9: DriveMode = .push_pull,
        OT10: DriveMode = .push_pull,
        OT11: DriveMode = .push_pull,
        OT12: DriveMode = .push_pull,
        OT13: DriveMode = .push_pull,
        OT14: DriveMode = .push_pull,
        OT15: DriveMode = .push_pull,
        _reserved16: u1 = 0,
        _reserved17: u1 = 0,
        _reserved18: u1 = 0,
        _reserved19: u1 = 0,
        _reserved20: u1 = 0,
        _reserved21: u1 = 0,
        _reserved22: u1 = 0,
        _reserved23: u1 = 0,
        _reserved24: u1 = 0,
        _reserved25: u1 = 0,
        _reserved26: u1 = 0,
        _reserved27: u1 = 0,
        _reserved28: u1 = 0,
        _reserved29: u1 = 0,
        _reserved30: u1 = 0,
        _reserved31: u1 = 0,

        pub fn init(all: DriveMode) OTYPER {
            return .{
                .OT0 = all,
                .OT1 = all,
                .OT2 = all,
                .OT3 = all,
                .OT4 = all,
                .OT5 = all,
                .OT6 = all,
                .OT7 = all,
                .OT8 = all,
                .OT9 = all,
                .OT10 = all,
                .OT11 = all,
                .OT12 = all,
                .OT13 = all,
                .OT14 = all,
                .OT15 = all,
            };
        }
    };

    pub const SlewRate = enum(u2) {
        very_slow = 0,  // max 2-3 MHz @ 3.3V
        slow = 1,       // max 10-15 MHz @ 3.3V
        fast = 2,       // max 30-60 MHz @ 3.3V
        very_fast = 3,  // max 60-80 MHz @ 3.3V

        pub const default = SlewRate.very_slow;
    };

    pub const OSPEEDR = packed struct {
        OSPEEDR0: SlewRate = .very_slow,
        OSPEEDR1: SlewRate = .very_slow,
        OSPEEDR2: SlewRate = .very_slow,
        OSPEEDR3: SlewRate = .very_slow,
        OSPEEDR4: SlewRate = .very_slow,
        OSPEEDR5: SlewRate = .very_slow,
        OSPEEDR6: SlewRate = .very_slow,
        OSPEEDR7: SlewRate = .very_slow,
        OSPEEDR8: SlewRate = .very_slow,
        OSPEEDR9: SlewRate = .very_slow,
        OSPEEDR10: SlewRate = .very_slow,
        OSPEEDR11: SlewRate = .very_slow,
        OSPEEDR12: SlewRate = .very_slow,
        OSPEEDR13: SlewRate = .very_slow,
        OSPEEDR14: SlewRate = .very_slow,
        OSPEEDR15: SlewRate = .very_slow,

        pub fn init(all: SlewRate) OSPEEDR {
            return .{
                .OSPEEDR0 = all,
                .OSPEEDR1 = all,
                .OSPEEDR2 = all,
                .OSPEEDR3 = all,
                .OSPEEDR4 = all,
                .OSPEEDR5 = all,
                .OSPEEDR6 = all,
                .OSPEEDR7 = all,
                .OSPEEDR8 = all,
                .OSPEEDR9 = all,
                .OSPEEDR10 = all,
                .OSPEEDR11 = all,
                .OSPEEDR12 = all,
                .OSPEEDR13 = all,
                .OSPEEDR14 = all,
                .OSPEEDR15 = all,
            };
        }
    };

    pub const GPIOA_OSPEEDR_reset_value = OSPEEDR {
        .OSPEEDR13 = .very_high_speed,
    };

    pub const TerminationMode = enum(u2) {
        float = 0,
        pull_up = 1,
        pull_down = 2,
        _,

        pub const default = TerminationMode.pull_down;
    };

    pub const PUPDR = packed struct {
        PUPD0: TerminationMode = .float,
        PUPD1: TerminationMode = .float,
        PUPD2: TerminationMode = .float,
        PUPD3: TerminationMode = .float,
        PUPD4: TerminationMode = .float,
        PUPD5: TerminationMode = .float,
        PUPD6: TerminationMode = .float,
        PUPD7: TerminationMode = .float,
        PUPD8: TerminationMode = .float,
        PUPD9: TerminationMode = .float,
        PUPD10: TerminationMode = .float,
        PUPD11: TerminationMode = .float,
        PUPD12: TerminationMode = .float,
        PUPD13: TerminationMode = .float,
        PUPD14: TerminationMode = .float,
        PUPD15: TerminationMode = .float,

        pub fn init(all: TerminationMode) PUPDR {
            return .{
                .PUPD0 = all,
                .PUPD1 = all,
                .PUPD2 = all,
                .PUPD4 = all,
                .PUPD5 = all,
                .PUPD6 = all,
                .PUPD7 = all,
                .PUPD8 = all,
                .PUPD9 = all,
                .PUPD10 = all,
                .PUPD11 = all,
                .PUPD12 = all,
                .PUPD13 = all,
                .PUPD14 = all,
                .PUPD15 = all,
            };
        }
    };

    pub const GPIOA_PUPDR_reset_value = PUPDR {
        .PUPD13 = .pull_up,
        .PUPD14 = .pull_down,
    };

    pub const DR = packed struct {
        D0: u1 = 0,
        D1: u1 = 0,
        D2: u1 = 0,
        D3: u1 = 0,
        D4: u1 = 0,
        D5: u1 = 0,
        D6: u1 = 0,
        D7: u1 = 0,
        D8: u1 = 0,
        D9: u1 = 0,
        D10: u1 = 0,
        D11: u1 = 0,
        D12: u1 = 0,
        D13: u1 = 0,
        D14: u1 = 0,
        D15: u1 = 0,
        _reserved16: u1 = 0,
        _reserved17: u1 = 0,
        _reserved18: u1 = 0,
        _reserved19: u1 = 0,
        _reserved20: u1 = 0,
        _reserved21: u1 = 0,
        _reserved22: u1 = 0,
        _reserved23: u1 = 0,
        _reserved24: u1 = 0,
        _reserved25: u1 = 0,
        _reserved26: u1 = 0,
        _reserved27: u1 = 0,
        _reserved28: u1 = 0,
        _reserved29: u1 = 0,
        _reserved30: u1 = 0,
        _reserved31: u1 = 0,

        pub fn init(all: u1) DR {
            return .{
                .D0 = all,
                .D1 = all,
                .D2 = all,
                .D3 = all,
                .D4 = all,
                .D5 = all,
                .D6 = all,
                .D7 = all,
                .D8 = all,
                .D9 = all,
                .D10 = all,
                .D11 = all,
                .D12 = all,
                .D13 = all,
                .D14 = all,
                .D15 = all,
            };
        }
    };

    pub const BitSetFlag = enum(u1) {
        no_action = 0,
        set = 1,
    };
    pub const BitResetFlag = enum(u1) {
        no_action = 0,
        reset = 1,
    };

    pub const BSRR = packed struct {
        BS0: BitSetFlag = .no_action,
        BS1: BitSetFlag = .no_action,
        BS2: BitSetFlag = .no_action,
        BS3: BitSetFlag = .no_action,
        BS4: BitSetFlag = .no_action,
        BS5: BitSetFlag = .no_action,
        BS6: BitSetFlag = .no_action,
        BS7: BitSetFlag = .no_action,
        BS8: BitSetFlag = .no_action,
        BS9: BitSetFlag = .no_action,
        BS10: BitSetFlag = .no_action,
        BS11: BitSetFlag = .no_action,
        BS12: BitSetFlag = .no_action,
        BS13: BitSetFlag = .no_action,
        BS14: BitSetFlag = .no_action,
        BS15: BitSetFlag = .no_action,
        BR0: BitResetFlag = .no_action,
        BR1: BitResetFlag = .no_action,
        BR2: BitResetFlag = .no_action,
        BR3: BitResetFlag = .no_action,
        BR4: BitResetFlag = .no_action,
        BR5: BitResetFlag = .no_action,
        BR6: BitResetFlag = .no_action,
        BR7: BitResetFlag = .no_action,
        BR8: BitResetFlag = .no_action,
        BR9: BitResetFlag = .no_action,
        BR10: BitResetFlag = .no_action,
        BR11: BitResetFlag = .no_action,
        BR12: BitResetFlag = .no_action,
        BR13: BitResetFlag = .no_action,
        BR14: BitResetFlag = .no_action,
        BR15: BitResetFlag = .no_action,

        pub fn set(bits: u16) BSRR {
            const temp: u32 = bits;
            return @bitCast(BSRR, temp);
        }

        pub fn reset(bits: u16) BSRR {
            const temp = @as(u32, bits) << 16;
            return @bitCast(BSRR, temp);
        }
    };
    pub const BRR = packed struct {
        BR0: BitResetFlag = .no_action,
        BR1: BitResetFlag = .no_action,
        BR2: BitResetFlag = .no_action,
        BR3: BitResetFlag = .no_action,
        BR4: BitResetFlag = .no_action,
        BR5: BitResetFlag = .no_action,
        BR6: BitResetFlag = .no_action,
        BR7: BitResetFlag = .no_action,
        BR8: BitResetFlag = .no_action,
        BR9: BitResetFlag = .no_action,
        BR10: BitResetFlag = .no_action,
        BR11: BitResetFlag = .no_action,
        BR12: BitResetFlag = .no_action,
        BR13: BitResetFlag = .no_action,
        BR14: BitResetFlag = .no_action,
        BR15: BitResetFlag = .no_action,
        _reserved16: u1 = 0,
        _reserved17: u1 = 0,
        _reserved18: u1 = 0,
        _reserved19: u1 = 0,
        _reserved20: u1 = 0,
        _reserved21: u1 = 0,
        _reserved22: u1 = 0,
        _reserved23: u1 = 0,
        _reserved24: u1 = 0,
        _reserved25: u1 = 0,
        _reserved26: u1 = 0,
        _reserved27: u1 = 0,
        _reserved28: u1 = 0,
        _reserved29: u1 = 0,
        _reserved30: u1 = 0,
        _reserved31: u1 = 0,

        pub fn reset(bits: u16) BRR {
            const temp = @as(u32, bits);
            return @bitCast(BRR, temp);
        }
    };

    pub const PortConfigLockMode = enum(u1) {
        unlocked = 0,
        locked = 1,
    };

    pub const LCKR = packed struct {
        LCK0: PortConfigLockMode = .unlocked,
        LCK1: PortConfigLockMode = .unlocked,
        LCK2: PortConfigLockMode = .unlocked,
        LCK3: PortConfigLockMode = .unlocked,
        LCK4: PortConfigLockMode = .unlocked,
        LCK5: PortConfigLockMode = .unlocked,
        LCK6: PortConfigLockMode = .unlocked,
        LCK7: PortConfigLockMode = .unlocked,
        LCK8: PortConfigLockMode = .unlocked,
        LCK9: PortConfigLockMode = .unlocked,
        LCK10: PortConfigLockMode = .unlocked,
        LCK11: PortConfigLockMode = .unlocked,
        LCK12: PortConfigLockMode = .unlocked,
        LCK13: PortConfigLockMode = .unlocked,
        LCK14: PortConfigLockMode = .unlocked,
        LCK15: PortConfigLockMode = .unlocked,
        LCKK: enum(u1) {
            meta_unlocked = 0,
            meta_locked = 1,
        } = .meta_unlocked,
        _reserved17: u1 = 0,
        _reserved18: u1 = 0,
        _reserved19: u1 = 0,
        _reserved20: u1 = 0,
        _reserved21: u1 = 0,
        _reserved22: u1 = 0,
        _reserved23: u1 = 0,
        _reserved24: u1 = 0,
        _reserved25: u1 = 0,
        _reserved26: u1 = 0,
        _reserved27: u1 = 0,
        _reserved28: u1 = 0,
        _reserved29: u1 = 0,
        _reserved30: u1 = 0,
        _reserved31: u1 = 0,

        pub fn init(all: PortConfigLockMode) LCKR {
            return .{
                .LCK0 = all,
                .LCK1 = all,
                .LCK2 = all,
                .LCK3 = all,
                .LCK4 = all,
                .LCK5 = all,
                .LCK6 = all,
                .LCK7 = all,
                .LCK8 = all,
                .LCK9 = all,
                .LCK10 = all,
                .LCK11 = all,
                .LCK12 = all,
                .LCK13 = all,
                .LCK14 = all,
                .LCK15 = all,
            };
        }
    };

    pub const PA0_AF = enum(u4) {
        SPI2_SCK = 0,
        USART2_CTS = 1,
        _,
    };
    pub const PA1_AF = enum(u4) {
        SPI1_SCK__I2S1_CK = 0,
        USART2_RTS = 1,
        I2C1_SMBA = 6,
        EVENTOUT = 7,
        _,
    };
    pub const PA2_AF = enum(u4) {
        SPI1_MOSI__I2S1_SD = 0,
        USART2_TX = 1,
        _,
    };
    pub const PA3_AF = enum(u4) {
        SPI2_MISO = 0,
        USART2_RX = 1,
        EVENTOUT = 7,
        _,
    };
    pub const PA4_AF = enum(u4) {
        SPI1_NSS__I2S1_WS = 0,
        SPI2_MOSI = 1,
        TIM14_CH1 = 4,
        EVENTOUT = 7,
        _,
    };
    pub const PA5_AF = enum(u4) {
        SPI1_SCK__I2S1_CK = 0,
        EVENTOUT = 7,
        _,
    };
    pub const PA6_AF = enum(u4) {
        SPI1_MISO__I2S1_MCK = 0,
        TIM3_CH1 = 1,
        TIM1_BKIN = 2,
        TIM16_CH1 = 5,
        _,
    };
    pub const PA7_AF = enum(u4) {
        SPI1_MOSI__I2S1_SD = 0,
        TIM3_CH2 = 1,
        TIM1_CH1N = 2,
        TIM14_CH1 = 4,
        TIM17_CH1 = 5,
        _,
    };
    pub const PA8_AF = enum(u4) {
        MCO = 0,
        SPI2_NSS = 1,
        TIM1_CH1 = 2,
        EVENTOUT = 7,
        _,
    };
    pub const PA9_AF = enum(u4) {
        MCO = 0,
        USART1_TX = 1,
        TIM1_CH2 = 2,
        SPI2_MISO = 4,
        I2C1_SCL = 6,
        EVENTOUT = 7,
        _,
    };
    pub const PA10_AF = enum(u4) {
        SPI2_MOSI = 0,
        USART1_RX = 1,
        TIM1_CH3 = 2,
        TIM17_BKIN = 5,
        I2C1_SDA = 6,
        EVENTOUT = 7,
        _,
    };
    pub const PA11_AF = enum(u4) {
        SPI1_MISO__I2S1_MCK = 0,
        USART1_CTS = 1,
        TIM1_CH4 = 2,
        TIM1_BKIN2 = 5,
        I2C2_SCL = 6,
        _,
    };
    pub const PA12_AF = enum(u4) {
        SPI1_MOSI__I2S1_SD = 0,
        USART1_RTS_DE_CK = 1,
        TIM1_ETR = 2,
        I2S_CKIN = 5,
        I2C2_SDA = 6,
        _,
    };
    pub const PA13_AF = enum(u4) {
        SWDIO = 0,
        IR_OUT = 1,
        EVENTOUT = 7,
        _,
    };
    pub const PA14_AF = enum(u4) {
        SWCLK = 0,
        USART2_TX = 1,
        EVENTOUT = 7,
        _,
    };
    pub const PA15_AF = enum(u4) {
        SPI1_NSS__I2S1_WS = 0,
        USART2_RX = 1,
        EVENTOUT = 7,
        _,
    };

    pub const GPIOA_AFRL = packed struct {
        AFSEL0: PA0_AF = .SPI2_SCK,
        AFSEL1: PA1_AF = .SPI1_SCK__I2S1_CK,
        AFSEL2: PA2_AF = .SPI1_MOSI__I2S1_SD,
        AFSEL3: PA3_AF = .SPI2_MISO,
        AFSEL4: PA4_AF = .SPI1_NSS__I2S1_WS,
        AFSEL5: PA5_AF = .SPI1_SCK__I2S1_CK,
        AFSEL6: PA6_AF = .SPI1_MISO__I2S1_MCK,
        AFSEL7: PA7_AF = .SPI1_MOSI__I2S1_SD,
    };
    pub const GPIOA_AFRH = packed struct {
        AFSEL8: PA8_AF = .MCO,
        AFSEL9: PA9_AF = .MCO,
        AFSEL10: PA10_AF = .SPI2_MOSI,
        AFSEL11: PA11_AF = .SPI1_MISO__I2S1_MCK,
        AFSEL12: PA12_AF = .SPI1_MOSI__I2S1_SD,
        AFSEL13: PA13_AF = .SWDIO,
        AFSEL14: PA14_AF = .SWCLK,
        AFSEL15: PA15_AF = .SPI1_NSS__I2S1_WS,
    };

    pub const PB0_AF = enum(u4) {
        SPI1_NSS__I2S1_WS = 0,
        TIM3_CH3 = 1,
        TIM1_CH2N = 2,
        _,
    };
    pub const PB1_AF = enum(u4) {
        TIM14_CH1 = 0,
        TIM3_CH4 = 1,
        TIM1_CH3N = 2,
        EVENTOUT = 7,
        _,
    };
    pub const PB2_AF = enum(u4) {
        SPI2_MISO = 1,
        EVENTOUT = 7,
        _,
    };
    pub const PB3_AF = enum(u4) {
        SPI1_SCK__I2S1_CK = 0,
        TIM1_CH2 = 1,
        USART1_RTS_DE_CK = 4,
        EVENTOUT = 7,
        _,
    };
    pub const PB4_AF = enum(u4) {
        SPI1_MISO__I2S1_MCK = 0,
        TIM3_CH1 = 1,
        USART1_CTS = 4,
        TIM17_BKIN = 5,
        EVENTOUT = 7,
        _,
    };
    pub const PB5_AF = enum(u4) {
        SPI1_MOSI__I2S1_SD = 0,
        TIM3_CH2 = 1,
        TIM16_BKIN = 2,
        I2C1_SMBA = 6,
        _,
    };
    pub const PB6_AF = enum(u4) {
        USART1_TX = 0,
        TIM1_CH3 = 1,
        TIM16_CH1N = 2,
        SPI2_MISO = 4,
        I2C1_SCL = 6,
        EVENTOUT = 7,
        _,
    };
    pub const PB7_AF = enum(u4) {
        USART1_RX = 0,
        SPI2_MOSI = 1,
        TIM17_CH1N = 2,
        I2C1_SDA = 6,
        EVENTOUT = 7,
        _,
    };
    pub const PB8_AF = enum(u4) {
        SPI2_SCK = 1,
        TIM16_CH1 = 2,
        I2C1_SCL = 6,
        EVENTOUT = 7,
        _,
    };
    pub const PB9_AF = enum(u4) {
        IR_OUT = 0,
        TIM17_CH1 = 2,
        SPI2_NSS = 5,
        I2C1_SDA = 6,
        EVENTOUT = 7,
        _,
    };
    pub const PB10_AF = enum(u4) {
        SPI2_SCK = 5,
        I2C2_SCL = 6,
        _,
    };
    pub const PB11_AF = enum(u4) {
        SPI2_MOSI = 0,
        I2C2_SDA = 6,
        _,
    };
    pub const PB12_AF = enum(u4) {
        SPI2_NSS = 0,
        TIM1_BKIN = 2,
        EVENTOUT = 7,
        _,
    };
    pub const PB13_AF = enum(u4) {
        SPI2_SCK = 0,
        TIM1_CH1N = 2,
        I2C2_SCL = 6,
        EVENTOUT = 7,
        _,
    };
    pub const PB14_AF = enum(u4) {
        SPI2_MISO = 0,
        TIM1_CH2N = 2,
        I2C2_SDA = 6,
        EVENTOUT = 7,
        _,
    };
    pub const PB15_AF = enum(u4) {
        SPI2_MOSI = 0,
        TIM1_CH3N = 2,
        EVENTOUT = 7,
        _,
    };

    pub const GPIOB_AFRL = packed struct {
        AFSEL0: PB0_AF = .SPI1_NSS__I2S1_WS,
        AFSEL1: PB1_AF = .TIM14_CH1,
        AFSEL2: PB2_AF = @intToEnum(PB2_AF, 0),
        AFSEL3: PB3_AF = .SPI1_SCK__I2S1_CK,
        AFSEL4: PB4_AF = .SPI1_MISO__I2S1_MCK,
        AFSEL5: PB5_AF = .SPI1_MOSI__I2S1_SD,
        AFSEL6: PB6_AF = .USART1_TX,
        AFSEL7: PB7_AF = .USART1_RX,
    };
    pub const GPIOB_AFRH = packed struct {
        AFSEL8: PB8_AF = @intToEnum(PB8_AF, 0),
        AFSEL9: PB9_AF = .IR_OUT,
        AFSEL10: PB10_AF = @intToEnum(PB10_AF, 0),
        AFSEL11: PB11_AF = .SPI2_MOSI,
        AFSEL12: PB12_AF = .SPI2_NSS,
        AFSEL13: PB13_AF = .SPI2_SCK,
        AFSEL14: PB14_AF = .SPI2_MISO,
        AFSEL15: PB15_AF = .SPI2_MOSI,
    };

    pub const PC6_AF = enum(u4) {
        TIM3_CH1 = 1,
        _,
    };
    pub const PC7_AF = enum(u4) {
        TIM3_CH2 = 1,
        _,
    };
    pub const PC13_AF = enum(u4) {
        TIM1_BKIN = 2,
        _,
    };
    pub const PC14_AF = enum(u4) {
        TIM1_BKIN2 = 2,
        _,
    };
    pub const PC15_AF = enum(u4) {
        OSC32_EN = 0,
        OSC_EN = 1,
        _,
    };

    pub const GPIOC_AFRL = packed struct {
        _reserved0: u4 = 0,
        _reserved1: u4 = 0,
        _reserved2: u4 = 0,
        _reserved3: u4 = 0,
        _reserved4: u4 = 0,
        _reserved5: u4 = 0,
        AFRL6: PC6_AF = @intToEnum(PC6_AF, 0),
        AFRL7: PC7_AF = @intToEnum(PC7_AF, 0),
    };
    pub const GPIOC_AFRH = packed struct {
        _reserved8: u4 = 0,
        _reserved9: u4 = 0,
        _reserved10: u4 = 0,
        _reserved11: u4 = 0,
        _reserved12: u4 = 0,
        AFRH13: PC13_AF = @intToEnum(PC13_AF, 0),
        AFRH14: PC14_AF = @intToEnum(PC14_AF, 0),
        AFRH15: PC15_AF = .OSC32_EN,
    };

    pub const PD0_AF = enum(u4) {
        EVENTOUT = 0,
        SPI2_NSS = 1,
        TIM16_CH1 = 2,
        _,
    };
    pub const PD1_AF = enum(u4) {
        EVENTOUT = 0,
        SPI2_SCK = 1,
        TIM17_CH1 = 2,
        _,
    };
    pub const PD2_AF = enum(u4) {
        TIM3_ETR = 1,
        TIM1_CH1N = 2,
        _,
    };
    pub const PD3_AF = enum(u4) {
        USART2_CTS = 0,
        SPI2_MISO = 1,
        TIM1_CH2N = 2,
        _,
    };

    pub const GPIOD_AFRL = packed struct {
        AFRL0: PD0_AF = .EVENTOUT,
        AFRL1: PD1_AF = .EVENTOUT,
        AFRL2: PD2_AF = @intToEnum(PD2_AF, 0),
        AFRL3: PD3_AF = .USART2_CTS,
        _reserved4: u4 = 0,
        _reserved5: u4 = 0,
        _reserved6: u4 = 0,
        _reserved7: u4 = 0,
    };
    pub const GPIOD_AFRH = Unused_AFRH;

    pub const PF0_AF = enum(u4) {
        TIM14_CH1 = 2,
        _,
    };
    pub const PF1_AF = enum(u4) {
        OSC_EN = 0,
        _,
    };

    pub const GPIOF_AFRL = packed struct {
        AFRL0: PF0_AF = @intToEnum(PF0_AF, 0),
        AFRL1: PF1_AF = .OSC_EN,
        _reserved2: u4 = 0,
        _reserved3: u4 = 0,
        _reserved4: u4 = 0,
        _reserved5: u4 = 0,
        _reserved6: u4 = 0,
        _reserved7: u4 = 0,
    };
    pub const GPIOF_AFRH = Unused_AFRH;

    pub const Unused_AFRH = packed struct {
        _reserved8: u4 = 0,
        _reserved9: u4 = 0,
        _reserved10: u4 = 0,
        _reserved11: u4 = 0,
        _reserved12: u4 = 0,
        _reserved13: u4 = 0,
        _reserved14: u4 = 0,
        _reserved15: u4 = 0,
    };

};

pub const dma = struct {

    pub const AddressIncrementMode = enum(u1) {
        constant_address = 0,
        increment_address = 1,
    };

    pub const WordSize = enum(u2) {
        x8b = 0,
        x16b = 1,
        x32b = 2,
    };

    pub const CCR = packed struct {
        /// channel enable
        /// When a channel transfer error occurs, this bit is cleared by hardware. It can
        /// not be set again by software (channel x re-activated) until the TEIFx bit of the
        /// DMA_ISR register is cleared (by setting the CTEIFx bit of the DMA_IFCR
        /// register).
        /// Note: this bit is set and cleared by software.
        EN: enum(u1) {
            channel_disabled = 0,
            channel_enabled = 1,
        } = .channel_disabled,
        /// transfer complete interrupt enable
        /// Note: this bit is set and cleared by software.
        /// It must not be written when the channel is enabled (EN = 1).
        /// It is not read-only when the channel is enabled (EN=1).
        TCIE: InterruptEnable = .interrupt_disabled,
        /// half transfer interrupt enable
        /// Note: this bit is set and cleared by software.
        /// It must not be written when the channel is enabled (EN = 1).
        /// It is not read-only when the channel is enabled (EN=1).
        HTIE: InterruptEnable = .interrupt_disabled,
        /// transfer error interrupt enable
        /// Note: this bit is set and cleared by software.
        /// It must not be written when the channel is enabled (EN = 1).
        /// It is not read-only when the channel is enabled (EN=1).
        TEIE: InterruptEnable = .interrupt_disabled,
        /// data transfer direction
        /// This bit must be set only in memory-to-peripheral and peripheral-to-memory
        /// modes.
        /// Source attributes are defined by PSIZE and PINC, plus the DMA_CPARx register.
        /// This is still valid in a memory-to-memory mode.
        /// Destination attributes are defined by MSIZE and MINC, plus the DMA_CMARx
        /// register. This is still valid in a peripheral-to-peripheral mode.
        /// Destination attributes are defined by PSIZE and PINC, plus the DMA_CPARx
        /// register. This is still valid in a memory-to-memory mode.
        /// Source attributes are defined by MSIZE and MINC, plus the DMA_CMARx register.
        /// This is still valid in a peripheral-to-peripheral mode.
        /// Note: this bit is set and cleared by software.
        /// It must not be written when the channel is enabled (EN = 1).
        /// It is read-only when the channel is enabled (EN=1).
        DIR: enum(u1) {
            read_from_peripheral = 0,
            read_from_memory = 1,
        } = .read_from_peripheral,
        /// circular mode
        /// Note: this bit is set and cleared by software.
        /// It must not be written when the channel is enabled (EN = 1).
        /// It is not read-only when the channel is enabled (EN=1).
        CIRC: enum(u1) {
            circular_mode_disabled = 0,
            circular_mode_enabled = 1,
        } = .circular_mode_disabled,
        /// peripheral increment mode
        /// Defines the increment mode for each DMA transfer to the identified peripheral.
        /// n memory-to-memory mode, this field identifies the memory destination if DIR=1
        /// and the memory source if DIR=0.
        /// In peripheral-to-peripheral mode, this field identifies the peripheral
        /// destination if DIR=1 and the peripheral source if DIR=0.
        /// Note: this bit is set and cleared by software.
        /// It must not be written when the channel is enabled (EN = 1).
        /// It is read-only when the channel is enabled (EN=1).
        PINC: AddressIncrementMode = .constant_address,
        /// memory increment mode
        /// Defines the increment mode for each DMA transfer to the identified memory.
        /// In memory-to-memory mode, this field identifies the memory source if DIR=1 and
        /// the memory destination if DIR=0.
        /// In peripheral-to-peripheral mode, this field identifies the peripheral source if
        /// DIR=1 and the peripheral destination if DIR=0.
        /// Note: this bit is set and cleared by software.
        /// It must not be written when the channel is enabled (EN = 1).
        /// It is read-only when the channel is enabled (EN=1).
        MINC: AddressIncrementMode = .constant_address,
        /// peripheral size
        /// Defines the data size of each DMA transfer to the identified peripheral.
        /// In memory-to-memory mode, this field identifies the memory destination if DIR=1
        /// and the memory source if DIR=0.
        /// In peripheral-to-peripheral mode, this field identifies the peripheral
        /// destination if DIR=1 and the peripheral source if DIR=0.
        /// Note: this field is set and cleared by software.
        /// It must not be written when the channel is enabled (EN = 1).
        /// It is read-only when the channel is enabled (EN=1).
        PSIZE: WordSize = .x8b,
        /// memory size
        /// Defines the data size of each DMA transfer to the identified memory.
        /// In memory-to-memory mode, this field identifies the memory source if DIR=1 and
        /// the memory destination if DIR=0.
        /// In peripheral-to-peripheral mode, this field identifies the peripheral source if
        /// DIR=1 and the peripheral destination if DIR=0.
        /// Note: this field is set and cleared by software.
        /// It must not be written when the channel is enabled (EN = 1).
        /// It is read-only when the channel is enabled (EN=1).
        MSIZE: WordSize = .x8b,
        /// priority level
        /// Note: this field is set and cleared by software.
        /// It must not be written when the channel is enabled (EN = 1).
        /// It is read-only when the channel is enabled (EN=1).
        PL: enum(u2) {
            low = 0,
            medium = 1,
            high = 2,
            very_high = 3,
        } = .low,
        /// memory-to-memory mode
        /// Note: this bit is set and cleared by software.
        /// It must not be written when the channel is enabled (EN = 1).
        /// It is read-only when the channel is enabled (EN=1).
        MEM2MEM: enum(u1) {
            uses_peripheral = 0,
            memory_only = 1,
        } = .uses_peripheral,
        _reserved15: u1 = 0,
        _reserved16: u1 = 0,
        _reserved17: u1 = 0,
        _reserved18: u1 = 0,
        _reserved19: u1 = 0,
        _reserved20: u1 = 0,
        _reserved21: u1 = 0,
        _reserved22: u1 = 0,
        _reserved23: u1 = 0,
        _reserved24: u1 = 0,
        _reserved25: u1 = 0,
        _reserved26: u1 = 0,
        _reserved27: u1 = 0,
        _reserved28: u1 = 0,
        _reserved29: u1 = 0,
        _reserved30: u1 = 0,
        _reserved31: u1 = 0,
    };

    pub const CNDTR = packed struct {
        /// number of data to transfer (0 to 2^16-1)
        /// This field is updated by hardware when the channel is enabled:
        /// It is decremented after each single DMA 'read followed by write├ó┬Ç┬Ö transfer,
        /// indicating the remaining amount of data items to transfer.
        /// It is kept at zero when the programmed amount of data to transfer is reached, if
        /// the channel is not in circular mode (CIRC=0 in the DMA_CCRx register).
        /// It is reloaded automatically by the previously programmed value, when the
        /// transfer is complete, if the channel is in circular mode (CIRC=1).
        /// If this field is zero, no transfer can be served whatever the channel status
        /// (enabled or not).
        /// Note: this field is set and cleared by software.
        /// It must not be written when the channel is enabled (EN = 1).
        /// It is read-only when the channel is enabled (EN=1).
        NDT: u16 = 0,
        _reserved16: u1 = 0,
        _reserved17: u1 = 0,
        _reserved18: u1 = 0,
        _reserved19: u1 = 0,
        _reserved20: u1 = 0,
        _reserved21: u1 = 0,
        _reserved22: u1 = 0,
        _reserved23: u1 = 0,
        _reserved24: u1 = 0,
        _reserved25: u1 = 0,
        _reserved26: u1 = 0,
        _reserved27: u1 = 0,
        _reserved28: u1 = 0,
        _reserved29: u1 = 0,
        _reserved30: u1 = 0,
        _reserved31: u1 = 0,
    };

    /// peripheral address
    /// It contains the base address of the peripheral data register from/to which the
    /// data will be read/written.
    /// When PSIZE[1:0]=01 (16 bits), bit 0 of PA[31:0] is ignored. Access is
    /// automatically aligned to a half-word address.
    /// When PSIZE=10 (32 bits), bits 1 and 0 of PA[31:0] are ignored. Access is
    /// automatically aligned to a word address.
    /// In memory-to-memory mode, this register identifies the memory destination
    /// address if DIR=1 and the memory source address if DIR=0.
    /// In peripheral-to-peripheral mode, this register identifies the peripheral
    /// destination address DIR=1 and the peripheral source address if DIR=0.
    /// Note: this register is set and cleared by software.
    /// It must not be written when the channel is enabled (EN = 1).
    /// It is not read-only when the channel is enabled (EN=1).
    pub const CPAR = packed struct {
        PA: u32 = 0,
    };

    /// memory address
    /// It contains the base address of the memory from/to which the data will be
    /// read/written.
    /// When MSIZE[1:0]=01 (16 bits), bit 0 of MA[31:0] is ignored. Access is
    /// automatically aligned to a half-word address.
    /// When MSIZE=10 (32 bits), bits 1 and 0 of MA[31:0] are ignored. Access is
    /// automatically aligned to a word address.
    /// In memory-to-memory mode, this register identifies the memory source address if
    /// DIR=1 and the memory destination address if DIR=0.
    /// In peripheral-to-peripheral mode, this register identifies the peripheral source
    /// address DIR=1 and the peripheral destination address if DIR=0.
    /// Note: this register is set and cleared by software.
    /// It must not be written when the channel is enabled (EN = 1).
    /// It is not read-only when the channel is enabled (EN=1).
    pub const CMAR = packed struct {
        MA: u32 = 0,
    };

    pub const mux = struct {
        pub const MuxID = enum(u8) {
            channel_disabled = 0,
            dmamux_req_gen0 = 1,
            dmamux_req_gen1 = 2,
            dmamux_req_gen2 = 3,
            dmamux_req_gen3 = 4,
            ADC = 5,
            I2C1_RX = 10,
            I2C1_TX = 11,
            I2C2_RX = 12,
            I2C2_TX = 13,
            SPI1_RX = 16,
            SPI1_TX = 17,
            SPI2_RX = 18,
            SPI2_TX = 19,
            TIM1_CH1 = 20,
            TIM1_CH2 = 21,
            TIM1_CH3 = 22,
            TIM1_CH4 = 23,
            TIM1_TRIG_COM = 24,
            TIM1_UP = 25,
            TIM3_CH1 = 32,
            TIM3_CH2 = 33,
            TIM3_CH3 = 34,
            TIM3_CH4 = 35,
            TIM3_TRIG = 36,
            TIM3_UP = 37,
            TIM16_CH1 = 44,
            TIM16_COM = 45,
            TIM16_UP = 46,
            TIM17_CH1 = 47,
            TIM17_COM = 48,
            TIM17_UP = 49,
            USART1_RX = 50,
            USART1_TX = 51,
            USART2_RX = 52,
            USART2_TX = 53,
            _,
        };

        pub const TriggerSyncID = enum(u5) {
            EXTI_LINE0 = 0,
            EXTI_LINE1 = 1,
            EXTI_LINE2 = 2,
            EXTI_LINE3 = 3,
            EXTI_LINE4 = 4,
            EXTI_LINE5 = 5,
            EXTI_LINE6 = 6,
            EXTI_LINE7 = 7,
            EXTI_LINE8 = 8,
            EXTI_LINE9 = 9,
            EXTI_LINE10 = 10,
            EXTI_LINE11 = 11,
            EXTI_LINE12 = 12,
            EXTI_LINE13 = 13,
            EXTI_LINE14 = 14,
            EXTI_LINE15 = 15,
            dmamux_evt0 = 16,
            dmamux_evt1 = 17,
            dmamux_evt2 = 18,
            dmamux_evt3 = 19,
            TIM14_OC = 22,
            _,
        };

        pub const TriggerSyncPolarity = enum(u2) {
            no_event = 0,
            rising_edge = 1,
            falling_edge = 2,
            both_edges = 3,
        };

        pub const DMAMUX_CCR = packed struct {
            /// Input DMA request line selected
            DMAREQ_ID: MuxID = .channel_disabled,
            /// Interrupt enable at synchronization event overrun
            SOIE: InterruptEnable = .interrupt_disabled,
            /// Event generation enable/disable
            EGE: enum(u1) {
                event_generation_disabled = 0,
                event_generation_enabled = 1,
            } = .event_generation_disabled,
            _reserved10: u1 = 0,
            _reserved11: u1 = 0,
            _reserved12: u1 = 0,
            _reserved13: u1 = 0,
            _reserved14: u1 = 0,
            _reserved15: u1 = 0,
            /// Synchronous operating mode enable/disable
            SE: enum(u1) {
                sync_disabled = 0,
                sync_enabled = 1,
            } = .sync_disabled,
            /// Synchronization event type selector
            /// Defines the synchronization event on the selected synchronization input:
            SPOL: TriggerSyncPolarity = .no_event,
            /// Number of DMA requests to forward
            /// Defines the number of DMA requests forwarded before output event is generated.
            /// In synchronous mode, it also defines the number of DMA requests to forward after
            /// a synchronization event, then stop forwarding.
            /// The actual number of DMA requests forwarded is NBREQ+1. Note: This field can
            /// only be written when both SE and EGE bits are reset.
            NBREQ: u5 = 0,
            /// Synchronization input selected
            SYNC_ID: TriggerSyncID = .EXTI_LINE0,
            _reserved29: u1 = 0,
            _reserved30: u1 = 0,
            _reserved31: u1 = 0,
        };

        pub const DMAMUX_RGCR = packed struct {
            /// DMA request trigger input selected
            SIG_ID: TriggerSyncID = .EXTI_LINE0,
            _reserved5: u1 = 0,
            _reserved6: u1 = 0,
            _reserved7: u1 = 0,
            /// Interrupt enable at trigger event overrun
            OIE: InterruptEnable = .interrupt_disabled,
            _reserved9: u1 = 0,
            _reserved10: u1 = 0,
            _reserved11: u1 = 0,
            _reserved12: u1 = 0,
            _reserved13: u1 = 0,
            _reserved14: u1 = 0,
            _reserved15: u1 = 0,
            /// DMA request generator channel enable/disable
            GE: enum(u1) {
                generator_disabled = 0,
                generator_enabled = 1,
            } = .generator_disabled,
            /// DMA request generator trigger event type
            /// selection Defines the trigger event on the selected DMA request trigger input
            GPOL: TriggerSyncPolarity = .no_event,
            /// Number of DMA requests to generate
            /// Defines the number of DMA requests generated after a trigger event, then stop
            /// generating. The actual number of generated DMA requests is GNBREQ+1. Note:
            /// This field can only be written when GE bit is reset.
            GNBREQ: u5 = 0,
            _reserved24: u1 = 0,
            _reserved25: u1 = 0,
            _reserved26: u1 = 0,
            _reserved27: u1 = 0,
            _reserved28: u1 = 0,
            _reserved29: u1 = 0,
            _reserved30: u1 = 0,
            _reserved31: u1 = 0,
        };

        pub const RGSR = packed struct {
            OF0: InterruptFlag = .interrupt_not_active,
            OF1: InterruptFlag = .interrupt_not_active,
            OF2: InterruptFlag = .interrupt_not_active,
            OF3: InterruptFlag = .interrupt_not_active,
            _reserved4: u1 = 0,
            _reserved5: u1 = 0,
            _reserved6: u1 = 0,
            _reserved7: u1 = 0,
            _reserved8: u1 = 0,
            _reserved9: u1 = 0,
            _reserved10: u1 = 0,
            _reserved11: u1 = 0,
            _reserved12: u1 = 0,
            _reserved13: u1 = 0,
            _reserved14: u1 = 0,
            _reserved15: u1 = 0,
            _reserved16: u1 = 0,
            _reserved17: u1 = 0,
            _reserved18: u1 = 0,
            _reserved19: u1 = 0,
            _reserved20: u1 = 0,
            _reserved21: u1 = 0,
            _reserved22: u1 = 0,
            _reserved23: u1 = 0,
            _reserved24: u1 = 0,
            _reserved25: u1 = 0,
            _reserved26: u1 = 0,
            _reserved27: u1 = 0,
            _reserved28: u1 = 0,
            _reserved29: u1 = 0,
            _reserved30: u1 = 0,
            _reserved31: u1 = 0,
        };

        pub const RGCFR = packed struct {
            COF0: InterruptClearFlag = .no_action,
            COF1: InterruptClearFlag = .no_action,
            COF2: InterruptClearFlag = .no_action,
            COF3: InterruptClearFlag = .no_action,
            _reserved4: u1 = 0,
            _reserved5: u1 = 0,
            _reserved6: u1 = 0,
            _reserved7: u1 = 0,
            _reserved8: u1 = 0,
            _reserved9: u1 = 0,
            _reserved10: u1 = 0,
            _reserved11: u1 = 0,
            _reserved12: u1 = 0,
            _reserved13: u1 = 0,
            _reserved14: u1 = 0,
            _reserved15: u1 = 0,
            _reserved16: u1 = 0,
            _reserved17: u1 = 0,
            _reserved18: u1 = 0,
            _reserved19: u1 = 0,
            _reserved20: u1 = 0,
            _reserved21: u1 = 0,
            _reserved22: u1 = 0,
            _reserved23: u1 = 0,
            _reserved24: u1 = 0,
            _reserved25: u1 = 0,
            _reserved26: u1 = 0,
            _reserved27: u1 = 0,
            _reserved28: u1 = 0,
            _reserved29: u1 = 0,
            _reserved30: u1 = 0,
            _reserved31: u1 = 0,
        };
    };
};

pub const rcc = struct {

    pub const OscillatorEnable = enum(u1) {
        oscillator_disabled = 0,
        oscillator_enabled = 1,
    };

    pub const OscillatorEnableWhenStopped = enum(u1) {
        oscillator_disabled_when_stopped = 0,
        oscillator_enabled_when_stopped = 1,
    };

    pub const OscillatorReadyFlag = enum(u1) {
        oscillator_unstable = 0,
        oscillator_stable = 1,
    };

    pub const ClockEnable = enum(u1) {
        clock_disabled = 0,
        clock_enabled = 1,
    };

    pub const ClockEnableWhenSleeping = enum(u1) {
        clock_disabled_when_sleeping = 0,
        clock_enabled_when_sleeping = 1,
    };

    pub const OscillatorBypass = enum(u1) {
        crystal = 0,
        cmos_clock = 1,
    };

    pub const HSIDIV = enum(u3) {
        div1 = 0,
        div2 = 1,
        div4 = 2,
        div8 = 3,
        div16 = 4,
        div32 = 5,
        div64 = 6,
        div128 = 7,

        pub fn fromDivisor(comptime div: comptime_int) HSIDIV {
            return switch (div) {
                1 => .div1,
                2 => .div2,
                4 => .div4,
                8 => .div8,
                16 => .div16,
                32 => .div32,
                64 => .div64,
                128 => .div128,
                else => @compileError("Invalid divisor"),
            };
        }

        pub fn divisor(self: HSIDIV) u8 {
            return @as(u8, 1) << @enumToInt(self);
        }
    };

    pub const CssEnable = enum(u1) {
        clock_failover_disabled = 0,
        clock_failover_enabled_when_stable = 1,
    };

    pub const SystemClockSource = enum(u3) {
        HSISYS = 0,
        HSE = 1,
        PLLRCLK = 2,
        LSI = 3,
        LSE = 4,
        _,
    };

    pub const AHBPrescale = packed struct {
        divisor: Divisor,
        enabled: bool,

        const Divisor = enum(u3) {
            div2 = 0,
            div4 = 1,
            div8 = 2,
            div16 = 3,
            div64 = 4,
            div128 = 5,
            div256 = 6,
            div512 = 7,

            pub fn fromDivisor(comptime div: comptime_int) Divisor {
                return switch (div) {
                    2 => .div2,
                    4 => .div4,
                    8 => .div8,
                    16 => .div16,
                    64 => .div64,
                    128 => .div128,
                    256 => .div256,
                    512 => .div512,
                    else => @compileError("Invalid divisor"),
                };
            }

            pub fn divisor(self: Divisor) u10 {
                return switch (self) {
                    .div2 => 2,
                    .div4 => 4,
                    .div8 => 8,
                    .div16 => 16,
                    .div64 => 64,
                    .div128 => 128,
                    .div256 => 256,
                    .div512 => 512,
                };
            }
        };
    };

    pub const APBPrescale = packed struct {
        divisor: Divisor,
        enabled: bool,

        const Divisor = enum(u2) {
            div2 = 0,
            div4 = 1,
            div8 = 2,
            div16 = 3,

            pub fn fromDivisor(comptime div: comptime_int) Divisor {
                return switch (div) {
                    2 => .div2,
                    4 => .div4,
                    8 => .div8,
                    16 => .div16,
                    else => @compileError("Invalid divisor"),
                };
            }

            pub fn divisor(self: Divisor) u10 {
                return @as(u5, 2) << @enumToInt(self);
            }
        };
    };

    pub const MCOSource = enum(u4) {
        disabled = 0,
        SYSCLK = 1,
        HSI16 = 3,
        HSE = 4,
        PLLRCLK = 5,
        LSI = 6,
        LSE = 7,
        _,
    };

    pub const MCOPrescale = enum(u4) {
        div1 = 0,
        div2 = 1,
        div4 = 2,
        div8 = 3,
        div16 = 4,
        div32 = 5,
        div64 = 6,
        div128 = 7,
        div256 = 8,
        div512 = 9,
        div1024 = 10,
        _,

        pub fn fromDivisor(comptime div: comptime_int) MCOPrescale {
            return switch (div) {
                1 => .div1,
                2 => .div2,
                4 => .div4,
                8 => .div8,
                16 => .div16,
                32 => .div32,
                64 => .div64,
                128 => .div128,
                256 => .div256,
                512 => .div512,
                1024 => .div1024,
                else => @compileError("Invalid divisor"),
            };
        }

        pub fn divisor(self: MCOPrescale) u11 {
            return @as(u11, 1) << @enumToInt(self);
        }
    };

    pub const PLLSource = enum(u2) {
        none = 0,
        HSI16 = 2,
        HSE = 3,
        _,
    };

    pub const PLLMDivisor = enum(u3) {
        div1 = 0,
        div2 = 1,
        div3 = 2,
        div4 = 3,
        div5 = 4,
        div6 = 5,
        div7 = 6,
        div8 = 7,

        pub const min = .div1;
        pub const max = .div8;

        pub fn fromDivisor(comptime div: comptime_int) PLLMDivisor {
            return @intToEnum(PLLMDivisor, div - 1);
        }

        pub fn divisor(self: PLLMDivisor) u4 {
            return @enumToInt(self) + 1;
        }
    };

    pub const PLLNMultiplier = enum(u7) {
        x8 = 8,
        x9 = 9,

        x10 = 10,
        x11 = 11,
        x12 = 12,
        x13 = 13,
        x14 = 14,
        x15 = 15,
        x16 = 16,
        x17 = 17,
        x18 = 18,
        x19 = 19,

        x20 = 20,
        x21 = 21,
        x22 = 22,
        x23 = 23,
        x24 = 24,
        x25 = 25,
        x26 = 26,
        x27 = 27,
        x28 = 28,
        x29 = 29,

        x30 = 30,
        x31 = 31,
        x32 = 32,
        x33 = 33,
        x34 = 34,
        x35 = 35,
        x36 = 36,
        x37 = 37,
        x38 = 38,
        x39 = 39,

        x40 = 40,
        x41 = 41,
        x42 = 42,
        x43 = 43,
        x44 = 44,
        x45 = 45,
        x46 = 46,
        x47 = 47,
        x48 = 48,
        x49 = 49,

        x50 = 50,
        x51 = 51,
        x52 = 52,
        x53 = 53,
        x54 = 54,
        x55 = 55,
        x56 = 56,
        x57 = 57,
        x58 = 58,
        x59 = 59,

        x60 = 60,
        x61 = 61,
        x62 = 62,
        x63 = 63,
        x64 = 64,
        x65 = 65,
        x66 = 66,
        x67 = 67,
        x68 = 68,
        x69 = 69,

        x70 = 70,
        x71 = 71,
        x72 = 72,
        x73 = 73,
        x74 = 74,
        x75 = 75,
        x76 = 76,
        x77 = 77,
        x78 = 78,
        x79 = 79,

        x80 = 80,
        x81 = 81,
        x82 = 82,
        x83 = 83,
        x84 = 84,
        x85 = 85,
        x86 = 86,
        _,

        pub const min = .x8;
        pub const max = .x86;
    };

    pub const PLLPDivisor = enum(u5) {
        div2 = 1,
        div3 = 2,
        div4 = 3,
        div5 = 4,
        div6 = 5,
        div7 = 6,
        div8 = 7,
        div9 = 8,
        div10 = 9,
        div11 = 10,
        div12 = 11,
        div13 = 12,
        div14 = 13,
        div15 = 14,
        div16 = 15,
        div17 = 16,
        div18 = 17,
        div19 = 18,
        div20 = 19,
        div21 = 20,
        div22 = 21,
        div23 = 22,
        div24 = 23,
        div25 = 24,
        div26 = 25,
        div27 = 26,
        div28 = 27,
        div29 = 28,
        div30 = 29,
        div31 = 30,
        div32 = 31,
        _,

        pub const min = .div2;
        pub const max = .div32;

        pub fn fromDivisor(comptime div: comptime_int) PLLPDivisor {
            return @intToEnum(PLLPDivisor, div - 1);
        }

        pub fn divisor(self: PLLPDivisor) u4 {
            return @enumToInt(self) + 1;
        }
    };

    pub const PLLRDivisor = enum(u3) {
        div1 = 0,
        div2 = 1,
        div3 = 2,
        div4 = 3,
        div5 = 4,
        div6 = 5,
        div7 = 6,
        div8 = 7,

        pub const min = .div1;
        pub const max = .div8;

        pub fn fromDivisor(comptime div: comptime_int) PLLRDivisor {
            return @intToEnum(PLLRDivisor, div - 1);
        }

        pub fn divisor(self: PLLRDivisor) u4 {
            return @enumToInt(self) + 1;
        }
    };

    pub const UsartClockSource = enum(u2) {
        PCLK = 0,
        SYSCLK = 1,
        HSI16 = 2,
        LSE = 3,
    };

    pub const I2CClockSource = enum(u2) {
        PCLK = 0,
        SYSCLK = 1,
        HSI16 = 2,
        _,
    };

    pub const I2SClockSource = enum(u2) {
        SYSCLK = 0,
        PLLPCLK = 1,
        HSI16 = 2,
        I2S_CKIN = 3,
    };

    pub const AdcClockSource = enum(u2) {
        SYSCLK = 0,
        PLLPCLK = 1,
        HSI16 = 2,
        _,
    };

    pub const LSEDRV = enum(u2) {
        low = 0,
        medium_low = 1,
        medium_high = 2,
        high = 3,
    };

    pub const LSECSSD = enum(u1) {
        no_error = 0,
        LSE_failure_detected = 1,
    };

    pub const RtcClockSource = enum(u2) {
        none = 0,
        LSE = 1,
        LSI = 2,
        HSE_div32 = 3,
    };

    pub const LSCOSource = enum(u1) {
        LSI = 0,
        LSE = 1,
    };

    pub const RMVF = enum(u1) {
        no_action = 0,
        clear_reset_flags = 1,
    };

    pub const ResetFlag = enum(u1) {
        no_reset = 0,
        reset_detected = 1,
    };

};

pub const usart = struct {

    pub const Parity = enum(u1) {
        even = 0,
        odd = 1,
    };

    pub const StopBits = enum(u2) {
        one = 0,
        half = 1,
        two = 2,
        one_and_half = 3,
    };

    pub const CR1 = packed struct {
        UE: enum(u1) {
            usart_disabled = 0,
            usart_enabled = 1,
        } = .usart_disabled,
        UESM: enum(u1) {
            usart_disabled_when_stopped = 0,
            usart_enabled_when_stopped = 1,
        } = .usart_disabled_when_stopped,
        RE: enum(u1) {
            receiver_disabled = 0,
            receiver_enabled = 1,
        } = .receiver_disabled,
        TE: enum(u1) {
            transmitter_disabled = 0,
            transmitter_enabled = 1,
        } = .transmitter_disabled,
        IDLEIE: InterruptEnable = .interrupt_disabled,
        RXNEIE: InterruptEnable = .interrupt_disabled,
        TCIE: InterruptEnable = .interrupt_disabled,
        TXEIE: InterruptEnable = .interrupt_disabled,
        PEIE: InterruptEnable = .interrupt_disabled,
        PS: Parity = .even,
        PCE: enum(u1) {
            parity_disabled = 0,
            parity_enabled = 1,
        } = .parity_disabled,
        WAKE: enum(u1) {
            unmute_on_idle = 0,
            unmute_on_address_mark = 1,
        } = .unmute_on_idle,
        M0: u1 = 0,
        MME: enum(u1) {
            mute_disabled = 0,
            mute_enabled = 1,
        } = .mute_disabled,
        CMIE: InterruptEnable = .interrupt_disabled,
        OVER8: enum(u1) {
            oversample_x16 = 0,
            oversample_x8 = 1,
        } = .oversample_x16,
        DEDT: u5 = 0,
        DEAT: u5 = 0,
        RTOIE: InterruptEnable = .interrupt_disabled,
        EOBIE: InterruptEnable = .interrupt_disabled,
        M1: u1 = 0,
        FIFOEN: enum(u1) {
            fifo_disabled = 0,
            fifo_enabled = 1,
        } = .fifo_disabled,
        TXFEIE: InterruptEnable = .interrupt_disabled,
        RXFFIE: InterruptEnable = .interrupt_disabled,
    };

    pub const CR2 = packed struct {
        SLVEN: enum(u1) {
            slave_mode_disabled = 0,
            slave_mode_enabled = 1,
        } = .slave_mode_disabled,
        _reserved1: u1 = 0,
        _reserved2: u1 = 0,
        DIS_NSS: enum(u1) {
            select_by_nss = 0,
            always_selected = 1,
        } = .select_by_nss,
        ADDM7: enum(u1) {
            check_four_bits = 0,
            check_all_bits_except_one = 1,
        } = .check_four_bits,
        LBDL: enum(u1) {
            lin_break_is_10_bits = 0,
            lin_break_is_11_bits = 1,
        } = .lin_break_is_10_bits,
        LBDIE: InterruptEnable = .interrupt_disabled,
        _reserved7: u1 = 0,
        LBCL: enum(u1) {
            last_bit_clock_pulse_disabled = 0,
            last_bit_clock_pulse_enabled = 1,
        } = .last_bit_clock_pulse_disabled,
        CPHA: enum(u1) {
            capture_on_first_edge = 0,
            capture_on_second_edge = 1,
        } = .capture_on_first_edge,
        CPOL: enum(u1) {
            low_when_idle = 0,
            high_when_idle = 1,
        } = .low_when_idle,
        CLKEN: enum(u1) {
            sync_clock_disabled = 0,
            sync_clock_enabled = 1,
        } = .sync_clock_disabled,
        STOP: StopBits = .one,
        LINEN: enum(u1) {
            lin_mode_disabled = 0,
            lin_mode_enabled = 1,
        } = .lin_mode_disabled,
        SWAP: enum(u1) {
            normal = 0,
            swap_tx_rx = 1,
        } = .normal,
        RXINV: enum(u1) {
            normal = 0,
            invert_rx = 1,
        } = .normal,
        TXINV: enum(u1) {
            normal = 0,
            invert_tx = 1,
        } = .normal,
        DATAINV: enum(u1) {
            normal = 0,
            invert_data_and_parity = 1,
        } = .normal,
        MSBFIRST: enum(u1) {
            lsb_first = 0,
            msb_first = 1,
        } = .lsb_first,
        ABREN: enum(u1) {
            baud_rate_locked = 0,
            autodetect_baud_rate = 1,
        } = .baud_rate_locked,
        ABRMOD: enum(u2) {
            measure_start_bit = 0,
            measure_start_bit_and_first_data_bit = 1,
            measure_0x7F = 2,
            measure_0x55 = 3,
        } = .measure_start_bit,
        RTOEN: enum(u1) {
            receive_timeout_disabled = 0,
            receive_timeout_enabled = 1,
        } = .receive_timeout_disabled,
        ADDR: u8 = 0,
    };

    pub const FifoThreshold = enum(u3) {
        one_word_available = 0,
        two_words_available = 1,
        four_words_available = 2,
        six_words_available = 3,
        seven_words_available = 4,
        eight_words_available = 5,
        _,
    };

    pub const CR3 = packed struct {
        EIE: InterruptEnable = .interrupt_disabled,
        IREN: enum(u1) {
            irda_mode_disabled = 0,
            irda_mode_enabled = 1,
        } = .irda_mode_disabled,
        IRLP: enum(u1) {
            normal = 0,
            low_power_irda = 1,
        } = .normal,
        HDSEL: enum(u1) {
            full_duplex_or_simplex = 0,
            half_duplex = 1,
        } = .full_duplex_or_simplex,
        NACK: enum(u1) {
            smartcard_NACK_not_sent_after_PE = 0,
            smartcard_NACK_sent_after_PE = 1,
        } = .smartcard_NACK_not_sent_after_PE,
        SCEN: enum(u1) {
            smartcard_mode_disabled = 0,
            smartcard_mode_enabled = 1,
        } = .smartcard_mode_disabled,
        DMAR: enum(u1) {
            RX_DMA_disabled = 0,
            RX_DMA_enabled = 1,
        } = .RX_DMA_disabled,
        DMAT: enum(u1) {
            TX_DMA_disabled = 0,
            TX_DMA_enabled = 1,
        } = .TX_DMA_disabled,
        RTSE: enum(u1) {
            RTS_disabled = 0,
            RTS_enabled = 1,
        } = .RTS_disabled,
        CTSE: enum(u1) {
            CTS_disabled = 0,
            CTS_enabled = 1,
        } = .CTS_disabled,
        CTSIE: InterruptEnable = .interrupt_disabled,
        ONEBIT: enum(u1) {
            three_samples_per_bit = 0,
            one_sample_per_bit = 1,
        } = .three_samples_per_bit,
        OVRDIS: enum(u1) {
            normal = 0,
            ignore_overrun_and_bypass_RX_fifo = 1,
        } = .normal,
        DDRE: enum(u1) {
            DMA_remains_enabled_after_RX_error = 0,
            DMA_is_disabled_after_RX_error = 1,
        } = .DMA_remains_enabled_after_RX_error,
        DEM: enum(u1) {
            DE_disabled = 0,
            DE_enabled = 1,
        } = .DE_disabled,
        DEP: enum(u1) {
            active_high_DE = 0,
            active_low_DE = 1,
        } = .active_high_DE,
        _reserved16: u1 = 0,
        SCARCNT: u3 = 0,
        WUS: enum(u2) {
            WUF_on_addr_match = 0,
            WUF_on_start_bit = 2,
            WUF_on_rxne_or_rxfne = 3,
            _,
        } = .WUF_on_addr_match,
        WUFIE: InterruptEnable = .interrupt_disabled,
        TXFTIE: InterruptEnable = .interrupt_disabled,
        TCBGTIE: InterruptEnable = .interrupt_disabled,
        RXFTCFG: FifoThreshold = .one_word_available,
        RXFTIE: InterruptEnable = .interrupt_disabled,
        TXFTCFG: FifoThreshold = .one_word_available,
    };

    pub const BRR = packed struct {
        BRR_0_3: u4 = 0,
        BRR_4_15: u12 = 0,
        _reserved16: u1 = 0,
        _reserved17: u1 = 0,
        _reserved18: u1 = 0,
        _reserved19: u1 = 0,
        _reserved20: u1 = 0,
        _reserved21: u1 = 0,
        _reserved22: u1 = 0,
        _reserved23: u1 = 0,
        _reserved24: u1 = 0,
        _reserved25: u1 = 0,
        _reserved26: u1 = 0,
        _reserved27: u1 = 0,
        _reserved28: u1 = 0,
        _reserved29: u1 = 0,
        _reserved30: u1 = 0,
        _reserved31: u1 = 0,
    };

    pub const PrescaleDivisor = enum(u4) {
        div1 = 0,
        div2 = 1,
        div4 = 2,
        div6 = 3,
        div8 = 4,
        div10 = 5,
        div12 = 6,
        div16 = 7,
        div32 = 8,
        div64 = 9,
        div128 = 10,
        div256 = 11,
        _,

        pub const min = .div1;
        pub const max = .div256;

        pub fn fromDivisor(comptime div: comptime_int) PrescaleDivisor {
            return std.enums.nameCast(PrescaleDivisor, std.fmt.comptimePrint("div{}", .{ div }));
        }

        pub fn divisor(self: PrescaleDivisor) u4 {
            return switch (self) {
                .div1 => 1, 
                .div2 => 2,
                .div4 => 4,
                .div6 => 6,
                .div8 => 8,
                .div10 => 10,
                .div12 => 12,
                .div16 => 16,
                .div32 => 32,
                .div64 => 64,
                .div128 => 128,
                .div256 => 256,
                else => unreachable,
            };
        }
    };

    pub const PRESC = packed struct {
        PRESC: PrescaleDivisor = .div1,
        _: u28 = 0,
    };

    pub const GTPR = packed struct {
        /// Prescaler value
        PSC: u8 = 0,
        /// Guard time value
        GT: u8 = 0,
        _reserved16: u1 = 0,
        _reserved17: u1 = 0,
        _reserved18: u1 = 0,
        _reserved19: u1 = 0,
        _reserved20: u1 = 0,
        _reserved21: u1 = 0,
        _reserved22: u1 = 0,
        _reserved23: u1 = 0,
        _reserved24: u1 = 0,
        _reserved25: u1 = 0,
        _reserved26: u1 = 0,
        _reserved27: u1 = 0,
        _reserved28: u1 = 0,
        _reserved29: u1 = 0,
        _reserved30: u1 = 0,
        _reserved31: u1 = 0,
    };

    pub const RTOR = packed struct {
        /// Receiver timeout value
        RTO: u24 = 0,
        /// Block Length
        BLEN: u8 = 0,
    };

    pub const RQR = packed struct {
        ABRRQ: enum(u1) {
            no_action = 0,
            request_detect_baud_rate = 1,
        } = .no_action,
        SBKRQ: enum(u1) {
            no_action = 0,
            request_send_break = 1,
        } = .no_action,
        MMRQ: enum(u1) {
            no_action = 0,
            request_mute = 1,
        } = .no_action,
        RXFRQ: enum(u1) {
            no_action = 0,
            request_flush_RX_data = 1,
        } = .no_action,
        TXFRQ: enum(u1) {
            no_action = 0,
            request_flush_TX_data = 1,
        } = .no_action,
        _reserved5: u1 = 0,
        _reserved6: u1 = 0,
        _reserved7: u1 = 0,
        _reserved8: u1 = 0,
        _reserved9: u1 = 0,
        _reserved10: u1 = 0,
        _reserved11: u1 = 0,
        _reserved12: u1 = 0,
        _reserved13: u1 = 0,
        _reserved14: u1 = 0,
        _reserved15: u1 = 0,
        _reserved16: u1 = 0,
        _reserved17: u1 = 0,
        _reserved18: u1 = 0,
        _reserved19: u1 = 0,
        _reserved20: u1 = 0,
        _reserved21: u1 = 0,
        _reserved22: u1 = 0,
        _reserved23: u1 = 0,
        _reserved24: u1 = 0,
        _reserved25: u1 = 0,
        _reserved26: u1 = 0,
        _reserved27: u1 = 0,
        _reserved28: u1 = 0,
        _reserved29: u1 = 0,
        _reserved30: u1 = 0,
        _reserved31: u1 = 0,
    };

    pub const ISR = packed struct {
        PE: enum(u1) {
            no_error = 0,
            parity_error_detected = 1,
        } = .no_error,
        FE: enum(u1) {
            no_error = 0,
            framing_error_detected = 1,
        } = .no_error,
        NF: enum(u1) {
            no_error = 0,
            noise_error_detected = 1,
        } = .no_error,
        ORE: enum(u1) {
            no_error = 0,
            rx_overrun_error_detected = 1,
        } = .no_error,
        IDLE: enum(u1) {
            no_idle_detected = 0,
            idle_detected = 1,
        } = .no_idle_detected,
        RXNE_RXFNE: enum(u1) {
            RXD_empty = 0,
            RXD_available = 1,
        } = .RXD_empty,
        TC: enum(u1) {
            TX_in_progress = 0,
            TX_complete = 1,
        } = .TX_in_progress,
        TXE_TXFNF: enum(u1) {
            TXD_full = 0,
            TXD_available = 1,
        } = .TXD_full,
        LBDF: enum(u1) {
            lin_break_not_detected = 0,
            lin_break_detected = 1,
        } = .lin_break_not_detected,
        CTSIF: InterruptFlag = .interrupt_not_active,
        CTS: enum(u1) {
            not_clear_to_send = 0,
            clear_to_send = 1,
        } = .not_clear_to_send,
        RTOF: enum(u1) {
            RX_timeout_not_reached = 0,
            RX_timeout_detected = 1,
        } = .RX_timeout_not_reached,
        EOBF: enum(u1) {
            end_of_block_not_reached = 0,
            end_of_block_detected = 1,
        } = .end_of_block_not_reached,
        UDR: enum(u1) {
            no_error = 0,
            slave_underrun_error_detected = 1,
        } = .no_error,
        ABRE: enum(u1) {
            no_error = 0,
            auto_baud_rate_error_detected = 1,
        } = .no_error,
        ABRF: enum(u1) {
            auto_baud_rate_not_complete = 0,
            auto_baud_rate_complete = 1,
        } = .auto_baud_rate_not_complete,
        BUSY: enum(u1) {
            RX_idle = 0,
            RX_in_progress = 1,
        } = .RX_idle,
        CMF: enum(u1) {
            character_match_not_detected = 0,
            character_match_detected = 1,
        } = .character_match_not_detected,
        SBKF: enum(u1) {
            break_not_requested = 0,
            break_pending = 1,
        } = .break_not_requested,
        RWU: enum(u1) {
            RX_active = 0,
            RX_muted = 1,
        } = .RX_active,
        WUF: enum(u1) {
            wakeup_event_not_detected = 0,
            wakeup_event_detected = 1,
        } = .wakeup_event_not_detected,
        TEACK: enum(u1) {
            transmitter_disabled = 0,
            transmitter_enabled = 1,
        } = .transmitter_disabled,
        REACK: enum(u1) {
            receiver_disabled = 0,
            receiver_enabled = 1,
        } = .receiver_disabled,
        TXFE: enum(u1) {
            TX_FIFO_not_empty = 0,
            TX_FIFO_empty = 1,
        } = .TX_FIFO_not_empty,
        RXFF: enum(u1) {
            RX_FIFO_not_full = 0,
            RX_FIFO_full = 1,
        } = .RX_FIFO_not_full,
        TCBGT: enum(u1) {
            transmission_incomplete_or_failed = 0,
            transmission_complete = 1,
        } = .transmission_incomplete_or_failed,
        RXFT: enum(u1) {
            RX_FIFO_under_threshold = 0,
            RX_FIFO_over_threshold = 1,
        } = .RX_FIFO_under_threshold,
        TXFT: enum(u1) {
            TX_FIFO_under_threshold = 0,
            TX_FIFO_over_threshold = 1,
        } = .TX_FIFO_under_threshold,
        _reserved28: u1 = 0,
        _reserved29: u1 = 0,
        _reserved30: u1 = 0,
        _reserved31: u1 = 0,
    };

    pub const ICR = packed struct {
        PECF: ErrorClearFlag = .no_action,
        FECF: ErrorClearFlag = .no_action,
        NCF: ErrorClearFlag = .no_action,
        ORECF: ErrorClearFlag = .no_action,
        IDLECF: enum(u1) {
            no_action = 0,
            clear_idle = 1,
        } = .no_action,
        TXFECF: enum(u1) {
            no_action = 0,
            clear_TX_FIFO_empty = 1,
        } = .no_action,
        TCCF: enum(u1) {
            no_action = 0,
            clear_transmission_complete = 1,
        } = .no_action,
        TCBGTCF: enum(u1) {
            no_action = 0,
            clear_transmission_complete = 1,
        } = .no_action,
        LBDCF: enum(u1) {
            no_action = 0,
            clear_lin_break_flag = 1,
        } = .no_action,
        CTSCF: enum(u1) {
            no_action = 0,
            clear_CTS_flag = 1,
        } = .no_action,
        _reserved10: u1 = 0,
        RTOCF: enum(u1) {
            no_action = 0,
            clear_receiver_timeout = 1,
        } = .no_action,
        EOBCF: enum(u1) {
            no_action = 0,
            clear_end_of_block_flag = 1,
        } = .no_action,
        UDRCF: ErrorClearFlag = .no_action,
        _reserved14: u1 = 0,
        _reserved15: u1 = 0,
        _reserved16: u1 = 0,
        CMCF: enum(u1) {
            no_action = 0,
            clear_character_match = 1,
        } = .no_action,
        _reserved18: u1 = 0,
        _reserved19: u1 = 0,
        WUCF: enum(u1) {
            no_action = 0,
            clear_wakeup_from_stop = 1,
        } = .no_action,
        _reserved21: u1 = 0,
        _reserved22: u1 = 0,
        _reserved23: u1 = 0,
        _reserved24: u1 = 0,
        _reserved25: u1 = 0,
        _reserved26: u1 = 0,
        _reserved27: u1 = 0,
        _reserved28: u1 = 0,
        _reserved29: u1 = 0,
        _reserved30: u1 = 0,
        _reserved31: u1 = 0,
    };

};
