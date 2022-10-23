
// TODO have regz generate this
pub const InterruptType = enum {
    WWDG = 0,
    RTC_TAMP_EXTI_19_21 = 2,
    FLASH = 3,
    RCC = 4,
    EXTI_0_1 = 5,
    EXTI_2_3 = 6,
    EXTI_4_5_6_7_8_9_10_11_12_13_14_15 = 7,
    DMA_Channel_1 = 9,
    DMA_Channel_2_3 = 10,
    DMA_Channel_4_5_DMAMUX = 11,
    ADC_EXTI_17_18 = 12,
    TIM1_BRK_UP_TRG_COM = 13,
    TIM1_CC = 14,
    TIM3_TIM4 = 16,
    TIM6 = 17,
    TIM7 = 18,
    TIM14 = 19,
    TIM15 = 20,
    TIM16 = 21,
    TIM17 = 22,
    I2C1 = 23,
    I2C2_I2C3 = 24,
    SPI1 = 25,
    SPI2_SPI3 = 26,
    USART1_EXTI_25 = 27,
    USART2_EXTI_26 = 28,
    USART3_USART4_USART5_USART6_EXTI28 = 29,
};

pub const gpio = struct {

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
        very_slow = 0,
        slow = 1,
        fast = 2,
        very_fast = 3,
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

    pub const LineMaintenance = enum(u2) {
        float = 0,
        pull_up = 1,
        pull_down = 2,
        _,
    };

    pub const PUPDR = packed struct {
        PUPD0: LineMaintenance = .float,
        PUPD1: LineMaintenance = .float,
        PUPD2: LineMaintenance = .float,
        PUPD4: LineMaintenance = .float,
        PUPD5: LineMaintenance = .float,
        PUPD6: LineMaintenance = .float,
        PUPD7: LineMaintenance = .float,
        PUPD8: LineMaintenance = .float,
        PUPD9: LineMaintenance = .float,
        PUPD10: LineMaintenance = .float,
        PUPD11: LineMaintenance = .float,
        PUPD12: LineMaintenance = .float,
        PUPD13: LineMaintenance = .float,
        PUPD14: LineMaintenance = .float,
        PUPD15: LineMaintenance = .float,

        pub fn init(all: LineMaintenance) PUPDR {
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
        _reserved16: u1 = undefined,
        _reserved17: u1 = undefined,
        _reserved18: u1 = undefined,
        _reserved19: u1 = undefined,
        _reserved20: u1 = undefined,
        _reserved21: u1 = undefined,
        _reserved22: u1 = undefined,
        _reserved23: u1 = undefined,
        _reserved24: u1 = undefined,
        _reserved25: u1 = undefined,
        _reserved26: u1 = undefined,
        _reserved27: u1 = undefined,
        _reserved28: u1 = undefined,
        _reserved29: u1 = undefined,
        _reserved30: u1 = undefined,
        _reserved31: u1 = undefined,

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
        _reserved16: u1 = undefined,
        _reserved17: u1 = undefined,
        _reserved18: u1 = undefined,
        _reserved19: u1 = undefined,
        _reserved20: u1 = undefined,
        _reserved21: u1 = undefined,
        _reserved22: u1 = undefined,
        _reserved23: u1 = undefined,
        _reserved24: u1 = undefined,
        _reserved25: u1 = undefined,
        _reserved26: u1 = undefined,
        _reserved27: u1 = undefined,
        _reserved28: u1 = undefined,
        _reserved29: u1 = undefined,
        _reserved30: u1 = undefined,
        _reserved31: u1 = undefined,

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
        _reserved17: u1 = undefined,
        _reserved18: u1 = undefined,
        _reserved19: u1 = undefined,
        _reserved20: u1 = undefined,
        _reserved21: u1 = undefined,
        _reserved22: u1 = undefined,
        _reserved23: u1 = undefined,
        _reserved24: u1 = undefined,
        _reserved25: u1 = undefined,
        _reserved26: u1 = undefined,
        _reserved27: u1 = undefined,
        _reserved28: u1 = undefined,
        _reserved29: u1 = undefined,
        _reserved30: u1 = undefined,
        _reserved31: u1 = undefined,

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
        _reserved0: u4 = undefined,
        _reserved1: u4 = undefined,
        _reserved2: u4 = undefined,
        _reserved3: u4 = undefined,
        _reserved4: u4 = undefined,
        _reserved5: u4 = undefined,
        AFRL6: PC6_AF = @intToEnum(PC6_AF, 0),
        AFRL7: PC7_AF = @intToEnum(PC7_AF, 0),
    };
    pub const GPIOC_AFRH = packed struct {
        _reserved8: u4 = undefined,
        _reserved9: u4 = undefined,
        _reserved10: u4 = undefined,
        _reserved11: u4 = undefined,
        _reserved12: u4 = undefined,
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
        _reserved4: u4 = undefined,
        _reserved5: u4 = undefined,
        _reserved6: u4 = undefined,
        _reserved7: u4 = undefined,
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
        _reserved2: u4 = undefined,
        _reserved3: u4 = undefined,
        _reserved4: u4 = undefined,
        _reserved5: u4 = undefined,
        _reserved6: u4 = undefined,
        _reserved7: u4 = undefined,
    };
    pub const GPIOF_AFRH = Unused_AFRH;

    pub const Unused_AFRH = packed struct {
        _reserved8: u4 = undefined,
        _reserved9: u4 = undefined,
        _reserved10: u4 = undefined,
        _reserved11: u4 = undefined,
        _reserved12: u4 = undefined,
        _reserved13: u4 = undefined,
        _reserved14: u4 = undefined,
        _reserved15: u4 = undefined,
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
        TCIE: enum(u1) {
            transfer_complete_interrupt_disabled = 0,
            transfer_complete_interrupt_enabled = 1,
        } = .transfer_complete_interrupt_disabled,
        /// half transfer interrupt enable
        /// Note: this bit is set and cleared by software.
        /// It must not be written when the channel is enabled (EN = 1).
        /// It is not read-only when the channel is enabled (EN=1).
        HTIE: enum(u1) {
            half_transfer_interrupt_disabled = 0,
            half_transfer_interrupt_enabled = 1,
        } = .half_transfer_interrupt_disabled,
        /// transfer error interrupt enable
        /// Note: this bit is set and cleared by software.
        /// It must not be written when the channel is enabled (EN = 1).
        /// It is not read-only when the channel is enabled (EN=1).
        TEIE: enum(u1) {
            transfer_error_interrupt_disabled = 0,
            transfer_error_interrupt_enabled = 1,
        } = transfer_error_interrupt_disabled,
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
        _reserved15: u1 = undefined,
        _reserved16: u1 = undefined,
        _reserved17: u1 = undefined,
        _reserved18: u1 = undefined,
        _reserved19: u1 = undefined,
        _reserved20: u1 = undefined,
        _reserved21: u1 = undefined,
        _reserved22: u1 = undefined,
        _reserved23: u1 = undefined,
        _reserved24: u1 = undefined,
        _reserved25: u1 = undefined,
        _reserved26: u1 = undefined,
        _reserved27: u1 = undefined,
        _reserved28: u1 = undefined,
        _reserved29: u1 = undefined,
        _reserved30: u1 = undefined,
        _reserved31: u1 = undefined,
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
        _reserved16: u1 = undefined,
        _reserved17: u1 = undefined,
        _reserved18: u1 = undefined,
        _reserved19: u1 = undefined,
        _reserved20: u1 = undefined,
        _reserved21: u1 = undefined,
        _reserved22: u1 = undefined,
        _reserved23: u1 = undefined,
        _reserved24: u1 = undefined,
        _reserved25: u1 = undefined,
        _reserved26: u1 = undefined,
        _reserved27: u1 = undefined,
        _reserved28: u1 = undefined,
        _reserved29: u1 = undefined,
        _reserved30: u1 = undefined,
        _reserved31: u1 = undefined,
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
        TIM6_UP = 38,
        TIM7_UP = 39,
        TIM15_CH1 = 40,
        TIM15_CH2 = 41,
        TIM15_TRIG_COM = 42,
        TIM15_UP = 43,
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
        USART3_RX = 54,
        USART3_TX = 55,
        USART4_RX = 56,
        USART4_TX = 57,
        I2C3_RX = 62,
        I2C3_TX = 63,
        SPI3_RX = 66,
        SPI3_TX = 67,
        TIM4_CH1 = 68,
        TIM4_CH2 = 69,
        TIM4_CH3 = 70,
        TIM4_CH4 = 71,
        TIM4_TRIG = 72,
        TIM4_UP = 73,
        USART5_RX = 74,
        USART5_TX = 75,
        USART6_RX = 76,
        USART6_TX = 77,
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
        SOIE: enum(u1) {
            sync_overrun_interrupt_disabled = 0,
            sync_overrun_interrupt_enabled = 1,
        } = .sync_overrun_interrupt_disabled,
        /// Event generation enable/disable
        EGE: enum(u1) {
            event_generation_disabled = 0,
            event_generation_enabled = 1,
        } = .event_generation_disabled,
        _reserved10: u1 = undefined,
        _reserved11: u1 = undefined,
        _reserved12: u1 = undefined,
        _reserved13: u1 = undefined,
        _reserved14: u1 = undefined,
        _reserved15: u1 = undefined,
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
        SYNC_ID: TriggerSyncID = EXTI_LINE0,
        _reserved29: u1 = undefined,
        _reserved30: u1 = undefined,
        _reserved31: u1 = undefined,
    };

    pub const DMAMUX_RGCR = packed struct {
        /// DMA request trigger input selected
        SIG_ID: TriggerSyncID = EXTI_LINE0,
        _reserved5: u1 = undefined,
        _reserved6: u1 = undefined,
        _reserved7: u1 = undefined,
        /// Interrupt enable at trigger event overrun
        OIE: enum(u1) {
            trigger_overrun_interrupt_disabled = 0,
            trigger_overrun_interrupt_enabled = 1,
        } = .trigger_overrun_interrupt_disabled,
        _reserved9: u1 = undefined,
        _reserved10: u1 = undefined,
        _reserved11: u1 = undefined,
        _reserved12: u1 = undefined,
        _reserved13: u1 = undefined,
        _reserved14: u1 = undefined,
        _reserved15: u1 = undefined,
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
        _reserved24: u1 = undefined,
        _reserved25: u1 = undefined,
        _reserved26: u1 = undefined,
        _reserved27: u1 = undefined,
        _reserved28: u1 = undefined,
        _reserved29: u1 = undefined,
        _reserved30: u1 = undefined,
        _reserved31: u1 = undefined,
    };

    pub const RequestGeneratorOverrunFlag = enum {
        no_event = 0,
        trigger_event_overran = 1,
    };

    pub const RequestGeneratorClearOverrunFlag = enum {
        no_action = 0,
        clear_trigger_event_overrun = 1,
    };

    pub const RGSR = packed struct {
        OF0: RequestGeneratorOverrunFlag = .no_event,
        OF1: RequestGeneratorOverrunFlag = .no_event,
        OF2: RequestGeneratorOverrunFlag = .no_event,
        OF3: RequestGeneratorOverrunFlag = .no_event,
        _reserved4: u1 = undefined,
        _reserved5: u1 = undefined,
        _reserved6: u1 = undefined,
        _reserved7: u1 = undefined,
        _reserved8: u1 = undefined,
        _reserved9: u1 = undefined,
        _reserved10: u1 = undefined,
        _reserved11: u1 = undefined,
        _reserved12: u1 = undefined,
        _reserved13: u1 = undefined,
        _reserved14: u1 = undefined,
        _reserved15: u1 = undefined,
        _reserved16: u1 = undefined,
        _reserved17: u1 = undefined,
        _reserved18: u1 = undefined,
        _reserved19: u1 = undefined,
        _reserved20: u1 = undefined,
        _reserved21: u1 = undefined,
        _reserved22: u1 = undefined,
        _reserved23: u1 = undefined,
        _reserved24: u1 = undefined,
        _reserved25: u1 = undefined,
        _reserved26: u1 = undefined,
        _reserved27: u1 = undefined,
        _reserved28: u1 = undefined,
        _reserved29: u1 = undefined,
        _reserved30: u1 = undefined,
        _reserved31: u1 = undefined,
    };

    pub const RGCFR = packed struct {
        COF0: RequestGeneratorClearOverrunFlag = .no_action,
        COF1: RequestGeneratorClearOverrunFlag = .no_action,
        COF2: RequestGeneratorClearOverrunFlag = .no_action,
        COF3: RequestGeneratorClearOverrunFlag = .no_action,
        _reserved4: u1 = undefined,
        _reserved5: u1 = undefined,
        _reserved6: u1 = undefined,
        _reserved7: u1 = undefined,
        _reserved8: u1 = undefined,
        _reserved9: u1 = undefined,
        _reserved10: u1 = undefined,
        _reserved11: u1 = undefined,
        _reserved12: u1 = undefined,
        _reserved13: u1 = undefined,
        _reserved14: u1 = undefined,
        _reserved15: u1 = undefined,
        _reserved16: u1 = undefined,
        _reserved17: u1 = undefined,
        _reserved18: u1 = undefined,
        _reserved19: u1 = undefined,
        _reserved20: u1 = undefined,
        _reserved21: u1 = undefined,
        _reserved22: u1 = undefined,
        _reserved23: u1 = undefined,
        _reserved24: u1 = undefined,
        _reserved25: u1 = undefined,
        _reserved26: u1 = undefined,
        _reserved27: u1 = undefined,
        _reserved28: u1 = undefined,
        _reserved29: u1 = undefined,
        _reserved30: u1 = undefined,
        _reserved31: u1 = undefined,
    };

};
