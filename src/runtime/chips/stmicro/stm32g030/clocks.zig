const std = @import("std");
const registers = @import("registers.zig").registers;
const microbe = @import("microbe");
const main = microbe.main;
const rcc = registers.types.rcc;

const fmtFrequency = microbe.clock.fmtFrequency;
const divRound = microbe.clock.divRound;

pub const Domain = enum {
    // oscillators:
    hsi,
    hse,
    lsi,
    lse,
    i2s_clkin,

    // PLL:
    pll_in,     // (hsi16 or hse) / M
    pll_vco,    // pll_in * N
    pll_r,      // pll_vco / R
    pll_p,      // pll_vco / P

    // Intermediate clocks:
    sys,        // lsi, lse, hse, pll_r, or hsi16 / HSISYS_PRESC
    ahb,        // sys / AHB_PRESC
    ahb_div8,   // ahb / 8 (possible SysTick source)
    apb,        // ahb / APB_PRESC

    // Peripheral clocks:
    microtick,  // SysTick counter frequency; ahb or ahb_div8
    tick,       // SysTick interrupt; microtick / (RELOAD + 1)
    mco,        // (none, lsi, lse, sys, hse, hsi16, or pll_r) / MCO_PRESC
    lsco,       // lsi or lse
    i2s,        // sys, pll_p, hsi16, or I2S_CKIN AF
    rtc,        // lsi, lse, or hse/32
    adc,        // sys, hsi16, or pll_p
    usart,      // apb, lse, hsi16, or sys
    i2c,        // apb, hsi16, or sys
    tim,        // apb or apb*2
};

pub const Config = struct {
    vcore: PowerRange = .high_performance,
    hsi_enabled: bool = false,
    lsi_enabled: bool = false,
    hse_type: rcc.OscillatorBypass = .crystal,
    hse_frequency_hz: comptime_int = 0,
    lse_type: enum {
        low_power_crystal,
        medium_low_power_crystal,
        medium_high_power_crystal,
        high_power_crystal,
        cmos_clock,
    } = .low_power_crystal,
    lse_frequency_hz: comptime_int = 0,
    i2s_clkin_frequency_hz: comptime_int = 0,

    pll: ?struct {
        source: enum { hsi, hse },
        vco: union(enum) {
            auto: void,
            frequency_hz: comptime_int,
            manual: struct {
                divisor: rcc.PLLMDivisor,
                multiplier: rcc.PLLNMultiplier,
            },
        } = .{ .auto = {} },
        p_frequency_hz: comptime_int = 0,
        r_frequency_hz: comptime_int = 0,
    } = null,

    sys_source: union(enum) {
        lsi: void,
        lse: void,
        hse: void,
        pll_r: void,
        hsi: struct {
            divisor: ?rcc.HSIDIV = null,
            frequency_hz: ?comptime_int = null,
        }
    },

    ahb_prescale: ?rcc.AHBPrescale.Divisor = null,
    apb_prescale: ?rcc.APBPrescale.Divisor = null,

    tick: ?struct {
        source: enum { auto, ahb, ahb_div8 } = .auto,
        period_ns: comptime_int,
    } = null,

    mco: ?struct {
        source: enum { lsi, lse, sys, hse, hsi, pll_r },
        divisor: ?rcc.MCOPrescale = null,
        frequency_hz: ?comptime_int = null,
    } = null,

    lsco_source: ?enum { lsi, lse } = null,
    rtc_source: ?enum { lsi, lse, hse_div32 } = null,
    i2s_source: enum { sys, pll_p, hsi, i2s_clkin } = .sys,
    adc_source: enum { sys, hsi, pll_p } = .sys,
    usart_source: enum { apb, lse, hsi, sys } = .apb,
    i2c_source: enum { apb, hsi, sys } = .apb,
};

pub const ParsedConfig = struct {
    vcore: PowerRange,
    wait_states: registers.types.flash.WaitStates = undefined,
    hsi_frequency_hz: comptime_int,
    hse_bypass: rcc.OscillatorBypass,
    hse_frequency_hz: comptime_int,
    lsi_frequency_hz: comptime_int,
    lse_bypass: rcc.OscillatorBypass,
    lse_drive: rcc.LSEDRV,
    lse_frequency_hz: comptime_int,
    i2s_clkin_frequency_hz: comptime_int,
    pll_in_source: ?Domain = null,
    pll_in_frequency_hz: comptime_int = 0,
    pll_m: rcc.PLLMDivisor = rcc.PLLMDivisor.min(),
    pll_n: rcc.PLLNMultiplier = rcc.PLLNMultiplier.min(),
    pll_vco_frequency_hz: comptime_int = 0,
    pll_r: rcc.PLLRDivisor = rcc.PLLRDivisor.max(),
    pll_r_frequency_hz: comptime_int = 0,
    pll_p: rcc.PLLPDivisor = rcc.PLLPDivisor.max(),
    pll_p_frequency_hz: comptime_int = 0,
    hsidiv: rcc.HSIDIV = .div1,
    sys_source: Domain = undefined,
    sys_frequency_hz: comptime_int = undefined,
    ahb_prescale: rcc.AHBPrescale = rcc.AHBPrescale.fromDivisor(1),
    ahb_frequency_hz: comptime_int = undefined,
    ahb_div8_frequency_hz: comptime_int = undefined,
    apb_prescale: rcc.APBPrescale = rcc.APBPrescale.fromDivisor(1),
    apb_frequency_hz: comptime_int = undefined,
    tick_source: ?Domain = null,
    tick_reload: u24 = 0,
    microtick_frequency_hz: comptime_int = 0,
    tick_frequency_hz: comptime_int = 0,
    mco_source: ?Domain = null,
    mco_prescale: rcc.MCOPrescale = .div1,
    mco_frequency_hz: comptime_int = 0,
    lsco_source: ?Domain = null,
    lsco_frequency_hz: comptime_int = 0,
    i2s_source: Domain = undefined,
    i2s_frequency_hz: comptime_int = undefined,
    rtc_source: ?Domain = null,
    rtc_frequency_hz: comptime_int = 0,
    adc_source: Domain = undefined,
    adc_frequency_hz: comptime_int = undefined,
    usart_source: Domain = undefined,
    usart_frequency_hz: comptime_int = undefined,
    i2c_source: Domain = undefined,
    i2c_frequency_hz: comptime_int = undefined,
    tim_frequency_hz: comptime_int = undefined,
};

const PowerRange = enum {
    low_power, // "low power run"
    mid_range, // "range 2"
    high_performance, // "range 1"
};

pub const reset_config = parseConfig(.{
    .hsi_enabled = true,
    .sys_source = .{ .hsi = .{ .divisor = .div1, } },
});

pub fn parseConfig(comptime config: Config) ParsedConfig { comptime {
    var parsed = ParsedConfig {
        .vcore = config.vcore,
        .hsi_frequency_hz = if (config.hsi_enabled) 16_000_000 else 0,
        .lsi_frequency_hz = if (config.lsi_enabled) 32_000 else 0,
        .hse_bypass = config.hse_type,
        .hse_frequency_hz = config.hse_frequency_hz,
        .lse_bypass = switch (config.lse_type) {
            .cmos_clock => .cmos_clock,
            else => .crystal,
        },
        .lse_drive = switch (config.lse_type) {
            .low_power_crystal, .cmos_clock => .low,
            .medium_low_power_crystal => .medium_low,
            .medium_high_power_crystal => .medium_high,
            .high_power_crystal => .high,
        },
        .lse_frequency_hz = config.lse_frequency_hz,
        .i2s_clkin_frequency_hz = config.i2s_clkin_frequency_hz,
    };

    if (config.pll) |pll| {
        parsed.pll_p_frequency_hz = pll.p_frequency_hz;
        parsed.pll_r_frequency_hz = pll.r_frequency_hz;
        switch (pll.source) {
            .hsi => {
                parsed.pll_in_source = .hsi;
                parsed.pll_in_frequency_hz = parsed.hsi_frequency_hz;
                if (parsed.hsi_frequency_hz == 0) {
                    @compileError("HSI must be enabled to be used as PLL input clock");
                }
            },
            .hse => {
                parsed.pll_in_source = .hse;
                parsed.pll_in_frequency_hz = parsed.hse_frequency_hz;
                if (parsed.hse_frequency_hz == 0) {
                    @compileError("HSE frequency must be specified to be used as PLL input clock");
                }
            },
        }
        switch (pll.vco) {
            .auto => findPllParamsAuto(&parsed),
            .frequency_hz => |freq| findPllParamsExplicitVco(&parsed, freq),
            .manual => |vco| findPllParamsManual(&parsed, vco.divisor, vco.multiplier),
        }

        checkFrequency("PLL input", parsed.pll_in_frequency_hz, 2_660_000, 16_000_000);
    }

    switch (config.sys_source) {
        .lsi => {
            parsed.sys_source = .lsi;
            parsed.sys_frequency_hz = parsed.lsi_frequency_hz;
            if (parsed.sys_frequency_hz == 0) {
                @compileError("LSI must be enabled to be used as the system clock source");
            }
        },
        .lse => {
            parsed.sys_source = .lse;
            parsed.sys_frequency_hz = parsed.lse_frequency_hz;
            if (parsed.sys_frequency_hz == 0) {
                @compileError("External LSE frequency must be specified to be used as the system clock source");
            }
        },
        .hse => {
            parsed.sys_source = .hse;
            parsed.sys_frequency_hz = parsed.hse_frequency_hz;
            if (parsed.sys_frequency_hz == 0) {
                @compileError("External HSE frequency must be specified to be used as the system clock source");
            }
        },
        .pll_r => {
            parsed.sys_source = .pll_r;
            parsed.sys_frequency_hz = parsed.pll_r_frequency_hz;
            if (parsed.sys_frequency_hz == 0) {
                @compileError("PLL R clock must be enabled to be used as the system clock source");
            }
        },
        .hsi => |hsi| {
            parsed.sys_source = .hsi;
            if (parsed.hsi_frequency_hz == 0) {
                @compileError("HSI must be enabled to be used as the system clock source");
            }
            if (hsi.divisor) |div| {
                parsed.hsidiv = div;
                parsed.sys_frequency_hz = divRound(parsed.hsi_frequency_hz, div.divisor());
                if (hsi.frequency_hz) |freq| {
                    if (freq != parsed.sys_frequency_hz) {
                        @compileError(std.fmt.comptimePrint("System clock frequency must be {} when using HSI {s}", .{
                            fmtFrequency(parsed.sys_frequency_hz),
                            @tagName(div),
                        }));
                    }
                }
            } else if (hsi.frequency_hz) |freq| {
                const Divisor = rcc.HSIDIV;
                checkFrequency("system clock", freq, divRound(parsed.hsi_frequency_hz, 128), parsed.hsi_frequency_hz);
                const div = divRound(parsed.hsi_frequency_hz, freq);
                const actual = divRound(parsed.hsi_frequency_hz, div);
                if (freq != actual) {
                    @compileError(std.fmt.comptimePrint("Invalid HSI system clock frequency; closest match is {}", .{ fmtFrequency(actual) }));
                }
                parsed.hsidiv = Divisor.fromDivisor(div);
                parsed.sys_frequency_hz = actual;
            } else {
                @compileError("Spease specify either `.divisor` or `.frequency_hz` for HSI system clock");
            }
        }
    }

    if (config.ahb_prescale) |div| {
        parsed.ahb_prescale = rcc.AHBPrescale {
            .divisor = div,
            .enabled = true,
        };
        parsed.ahb_frequency_hz = divRound(parsed.sys_frequency_hz, div.divisor());
    } else {
        parsed.ahb_frequency_hz = parsed.sys_frequency_hz;
    }
    parsed.ahb_div8_frequency_hz = divRound(parsed.ahb_frequency_hz, 8);

    if (config.apb_prescale) |div| {
        parsed.apb_prescale = rcc.APBPrescale {
            .divisor = div,
            .enabled = true,
        };
        parsed.apb_frequency_hz = divRound(parsed.ahb_frequency_hz, div.divisor());
    } else {
        parsed.apb_frequency_hz = parsed.ahb_frequency_hz;
    }

    if (config.tick) |tick| {
        var timer_freq = parsed.ahb_frequency_hz;
        var clocks_per_interrupt = divRound(timer_freq * tick.period_ns, 1_000_000_000);

        parsed.tick_source = switch (tick.source) {
            .auto => if (clocks_per_interrupt % 8 == 0 or clocks_per_interrupt > std.math.maxInt(u24)) .ahb_div8 else .ahb,
            .ahb => .ahb,
            .ahb_div8 => .ahb_div8,
        };

        if (parsed.tick_source.? == .ahb_div8) {
            timer_freq = parsed.ahb_div8_frequency_hz;
            clocks_per_interrupt = divRound(timer_freq * tick.period_ns, 1_000_000_000);
        }

        // systick interrupt only fires if RELOAD is > 0, and RELOAD is clocks_per_interrupt - 1,
        clocks_per_interrupt = @max(2, clocks_per_interrupt);

        const actual_freq = divRound(timer_freq, clocks_per_interrupt);
        const actual_period = divRound(clocks_per_interrupt * 1_000_000_000, timer_freq);
        if (actual_period != tick.period_ns) {
            var hclks_per_interrupt = clocks_per_interrupt;
            if (parsed.tick_source.? == .ahb_div8) {
                hclks_per_interrupt *= 8;
            }
            @compileError(std.fmt.comptimePrint("Invalid tick period; closest match is {} ns ({} HCLKs per interrupt, {} tick, {} microtick)", .{
                actual_period,
                hclks_per_interrupt,
                fmtFrequency(actual_freq),
                fmtFrequency(timer_freq)
            }));
        }
        parsed.microtick_frequency_hz = timer_freq;
        parsed.tick_frequency_hz = actual_freq;
        parsed.tick_reload = clocks_per_interrupt - 1;

        if (!@hasDecl(microbe.main, "interrupts") or !@hasDecl(microbe.main.interrupts, "SysTick")) {
            @compileError("SysTick interrupt handler not found; microbe.clock.handleTickInterrupt() must be called");
        }
    }

    if (config.mco) |mco| {
        switch (mco.source) {
            .lsi => {
                parsed.mco_source = .lsi;
                parsed.mco_frequency_hz = parsed.lsi_frequency_hz;
                if (parsed.mco_frequency_hz == 0) {
                    @compileError("LSI must be enabled to be used as the MCO source");
                }
            },
            .lse => {
                parsed.mco_source = .lse;
                parsed.mco_frequency_hz = parsed.lse_frequency_hz;
                if (parsed.mco_frequency_hz == 0) {
                    @compileError("LSE frequency must be specified to be used as the MCO source");
                }
            },
            .sys => {
                parsed.mco_source = .sys;
                parsed.mco_frequency_hz = parsed.sys_frequency_hz;
            },
            .hse => {
                parsed.mco_source = .hse;
                parsed.mco_frequency_hz = parsed.hse_frequency_hz;
                if (parsed.mco_frequency_hz == 0) {
                    @compileError("HSE frequency must be specified to be used as the MCO source");
                }
            },
            .hsi => {
                parsed.mco_source = .hsi;
                parsed.mco_frequency_hz = parsed.hsi_frequency_hz;
                if (parsed.mco_frequency_hz == 0) {
                    @compileError("HSI must be enabled to be used as the MCO source");
                }
            },
            .pll_r => {
                parsed.mco_source = .pll_r;
                parsed.mco_frequency_hz = parsed.pll_r_frequency_hz;
                if (parsed.mco_frequency_hz == 0) {
                    @compileError("PLL R clock must be enabled to be used as the MCO source");
                }
            },
        }

        if (mco.divisor) |div| {
            parsed.mco_prescale = div;
            parsed.mco_frequency_hz = divRound(parsed.mco_frequency_hz, div.divisor());
            if (mco.frequency_hz) |freq| {
                if (freq != parsed.mco_frequency_hz) {
                    @compileError(std.fmt.comptimePrint("MCO frequency must be {} based on selected source and divisor", .{
                        fmtFrequency(parsed.mco_frequency_hz),
                    }));
                }
            }
        } else if (mco.frequency_hz) |freq| {
            const Divisor = rcc.MCOPrescale;
            checkFrequency("MCO", freq, divRound(parsed.mco_frequency_hz, 1024), parsed.mco_frequency_hz);
            const div = divRound(parsed.mco_frequency_hz, freq);
            parsed.mco_frequency_hz = divRound(parsed.mco_frequency_hz, div);
            if (freq != parsed.mco_frequency_hz) {
                // TODO handle non-power-of-two divisors more gracefully
                @compileError(std.fmt.comptimePrint("Invalid HSI system clock frequency; closest match is {}", .{ fmtFrequency(parsed.mco_frequency_hz) }));
            }
            parsed.mco_prescale = Divisor.fromDivisor(div);
        } else {
            @compileError("Spease specify either `.divisor` or `.frequency_hz` for MCO");
        }
    }

    if (config.lsco_source) |lsco| switch (lsco) {
        .lsi => {
            parsed.lsco_source = .lsi;
            parsed.lsco_frequency_hz = parsed.lsi_frequency_hz;
            if (parsed.lsco_frequency_hz == 0) {
                @compileError("LSI must be enabled to be used as the LSCO source");
            }
        },
        .lse => {
            parsed.lsco_source = .lse;
            parsed.lsco_frequency_hz = parsed.lse_frequency_hz;
            if (parsed.lsco_frequency_hz == 0) {
                @compileError("LSE frequency must be specified to be used as the LSCO source");
            }
        },
    };

    if (config.rtc_source) |rtc| switch (rtc) {
        .lsi => {
            parsed.rtc_source = .lsi;
            parsed.rtc_frequency_hz = parsed.lsi_frequency_hz;
            if (parsed.rtc_frequency_hz == 0) {
                @compileError("LSI must be enabled to be used as the RTC source");
            }
        },
        .lse => {
            parsed.rtc_source = .lse;
            parsed.rtc_frequency_hz = parsed.lse_frequency_hz;
            if (parsed.rtc_frequency_hz == 0) {
                @compileError("LSE frequency must be specified to be used as the RTC source");
            }
        },
        .hse_div32 => {
            parsed.rtc_source = .hse;
            parsed.rtc_frequency_hz = divRound(parsed.hse_frequency_hz, 32);
            if (parsed.hse_frequency_hz == 0) {
                @compileError("HSE frequency must be specified to be used as the RTC source");
            }
        },
    };

    switch (config.i2s_source) {
        .sys => {
            parsed.i2s_source = .sys;
            parsed.i2s_frequency_hz = parsed.sys_frequency_hz;
        },
        .pll_p => {
            parsed.i2s_source = .pll_p;
            parsed.i2s_frequency_hz = parsed.pll_p_frequency_hz;
            if (parsed.i2s_frequency_hz == 0) {
                @compileError("PLL P clock must be enabled to be used as the I2S clock source");
            }
        },
        .hsi => {
            parsed.i2s_source = .hsi;
            parsed.i2s_frequency_hz = parsed.hsi_frequency_hz;
            if (parsed.i2s_frequency_hz == 0) {
                @compileError("HSI must be enabled to be used as the I2S clock source");
            }
        },
        .i2s_clkin => {
            parsed.i2s_source = .i2s_clkin;
            parsed.i2s_frequency_hz = parsed.i2s_clkin_frequency_hz;
            if (parsed.i2s_frequency_hz == 0) {
                @compileError("External i2s_clkin frequency must be specified to be used as the I2S clock source");
            }
        },
    }

    switch (config.adc_source) {
        .sys => {
            parsed.adc_source = .sys;
            parsed.adc_frequency_hz = parsed.sys_frequency_hz;
        },
        .hsi => {
            parsed.adc_source = .hsi;
            parsed.adc_frequency_hz = parsed.hsi_frequency_hz;
            if (parsed.adc_frequency_hz == 0) {
                @compileError("HSI must be enabled to be used as the ADC clock source");
            }
        },
        .pll_p => {
            parsed.adc_source = .pll_p;
            parsed.adc_frequency_hz = parsed.pll_p_frequency_hz;
            if (parsed.adc_frequency_hz == 0) {
                @compileError("PLL P clock must be enabled to be used as the ADC clock source");
            }
        },
    }

    switch (config.usart_source) {
        .sys => {
            parsed.usart_source = .sys;
            parsed.usart_frequency_hz = parsed.sys_frequency_hz;
        },
        .apb => {
            parsed.usart_source = .apb;
            parsed.usart_frequency_hz = parsed.apb_frequency_hz;
        },
        .hsi => {
            parsed.usart_source = .hsi;
            parsed.usart_frequency_hz = parsed.hsi_frequency_hz;
            if (parsed.usart_frequency_hz == 0) {
                @compileError("HSI must be enabled to be used as the USART clock source");
            }
        },
        .lse => {
            parsed.usart_source = .lse;
            parsed.usart_frequency_hz = parsed.lse_frequency_hz;
            if (parsed.usart_frequency_hz == 0) {
                @compileError("LSE frequency must be specified to be used as the USART clock source");
            }
        },
    }

    switch (config.i2c_source) {
        .sys => {
            parsed.i2c_source = .sys;
            parsed.i2c_frequency_hz = parsed.sys_frequency_hz;
        },
        .apb => {
            parsed.i2c_source = .apb;
            parsed.i2c_frequency_hz = parsed.apb_frequency_hz;
        },
        .hsi => {
            parsed.i2c_source = .hsi;
            parsed.i2c_frequency_hz = parsed.hsi_frequency_hz;
            if (parsed.i2c_frequency_hz == 0) {
                @compileError("HSI must be enabled to be used as the I2C clock source");
            }
        },
    }

    if (config.hse_frequency_hz > 0) switch (config.hse_type) {
        .crystal => checkFrequency("HSE", parsed.hse_frequency_hz, 4_000_000, 48_000_000),
        .cmos_clock => checkFrequency("HSE", parsed.hse_frequency_hz, 1, 48_000_000),
    };
    if (config.lse_frequency_hz > 0) switch (config.lse_type) {
        .crystal => checkFrequency("LSE", parsed.lse_frequency_hz, 32_768, 32_768),
        .cmos_clock => checkFrequency("LSE", parsed.lse_frequency_hz, 1, 1_000_000),
    };
    switch (parsed.vcore) {
        .low_power, .mid_range => {
            if (parsed.vcore == .low_power) {
                checkFrequency("system clock", parsed.sys_frequency_hz, 1, 2_000_000);
            } else {
                checkFrequency("system clock", parsed.sys_frequency_hz, 1, 16_000_000);
            }
            checkFrequency("HSE", parsed.hse_frequency_hz, 0, 16_000_000);
            checkFrequency("PLL VCO", parsed.pll_vco_frequency_hz, 0, 128_000_000);
            checkFrequency("PLL P", parsed.pll_p_frequency_hz, 0, 40_000_000);
            checkFrequency("PLL R", parsed.pll_r_frequency_hz, 0, 16_000_000);
            parsed.wait_states = switch (parsed.ahb_frequency_hz) {
                        1...8_000_000 => .zero,
                8_000_001...16_000_000 => .one,
                else => unreachable,
            };
        },
        .high_performance => {
            checkFrequency("system clock", parsed.sys_frequency_hz, 1, 64_000_000);
            checkFrequency("HSE", parsed.hse_frequency_hz, 0, 48_000_000);
            checkFrequency("PLL VCO", parsed.pll_vco_frequency_hz, 0, 344_000_000);
            checkFrequency("PLL P", parsed.pll_p_frequency_hz, 0, 122_000_000);
            checkFrequency("PLL R", parsed.pll_r_frequency_hz, 0, 64_000_000);
            parsed.wait_states = switch (parsed.ahb_frequency_hz) {
                         1...24_000_000 => .zero,
                24_000_001...48_000_000 => .one,
                48_000_001...64_000_000 => .two,
                else => unreachable,
            };
        },
    }

    return parsed;
}}

fn findPllParamsManual(comptime parsed: *ParsedConfig, comptime divisor: rcc.PLLMDivisor, comptime multiplier: rcc.PLLNMultiplier) void { comptime {
    parsed.pll_m = divisor;
    parsed.pll_n = multiplier;
    parsed.pll_in_frequency_hz = divRound(parsed.pll_in_frequency_hz, divisor.divisor());
    parsed.pll_vco_frequency_hz = parsed.pll_in_frequency_hz * @enumToInt(multiplier);
    if (parsed.pll_p_frequency_hz == 0 and parsed.pll_r_frequency_hz == 0) {
        @compileError("All PLL clock outputs are disabled, but the PLL itself is enabled; just use `.pll = null` instead");
    }
    {
        const PDivisor = rcc.PLLPDivisor;
        const p = if (parsed.pll_p_frequency_hz == 0)
            PDivisor.max().divisor()
        else
            divRound(parsed.pll_vco_frequency_hz, parsed.pll_p_frequency_hz)
        ;
        const p_freq = if (parsed.pll_p_frequency_hz == 0) 0 else divRound(parsed.pll_vco_frequency_hz, p);
        if (p < PDivisor.min().divisor()) {
            invalidFrequency("PLL P", p_freq, "<=", divRound(parsed.pll_vco_frequency_hz, PDivisor.min().divisor()));
        } else if (p > PDivisor.max().divisor()) {
            invalidFrequency("PLL P", p_freq, ">=", divRound(parsed.pll_vco_frequency_hz, PDivisor.max().divisor()));
        } else if (p_freq != parsed.pll_p_frequency_hz) {
            @compileError(std.fmt.comptimePrint("Invalid PLL P frequency; closest match is {}", .{ fmtFrequency(p_freq) }));
        }
        parsed.pll_p = PDivisor.fromDivisor(p);
        parsed.pll_p_frequency_hz = p_freq;
    }
    {
        const RDivisor = rcc.PLLRDivisor;
        const r = if (parsed.pll_r_frequency_hz == 0)
            RDivisor.max().divisor()
        else
            divRound(parsed.pll_vco_frequency_hz, parsed.pll_r_frequency_hz)
        ;
        const r_freq = if (parsed.pll_r_frequency_hz == 0) 0 else divRound(parsed.pll_vco_frequency_hz, r);
        if (r < RDivisor.min().divisor()) {
            invalidFrequency("PLL R", r_freq, "<=", divRound(parsed.pll_vco_frequency_hz, RDivisor.min().divisor()));
        } else if (r > RDivisor.max().divisor()) {
            invalidFrequency("PLL R", r_freq, ">=", divRound(parsed.pll_vco_frequency_hz, RDivisor.max().divisor()));
        } else if (r_freq != parsed.pll_r_frequency_hz) {
            @compileError(std.fmt.comptimePrint("Invalid PLL R frequency; closest match is {}", .{ fmtFrequency(r_freq) }));
        }
        parsed.pll_r = RDivisor.fromDivisor(r);
        parsed.pll_r_frequency_hz = r_freq;
    }
}}

fn findPllParamsExplicitVco(comptime parsed: *ParsedConfig, comptime target_vco_freq: comptime_int) void { comptime {
    const Divisor = rcc.PLLMDivisor;
    const Multiplier = rcc.PLLNMultiplier;

    const source_freq = parsed.pll_in_frequency_hz;
    var best_error: ?comptime_int = null;

    const max_vco_freq = switch (parsed.vcore) {
        .low_power, .mid_range => 128_000_000,
        .high_performance => 344_000_000,
    };

    var m = Divisor.max().divisor();
    const min = Divisor.min().divisor();
    while (m >= min) : (m -= 1) {
        const in_freq = divRound(source_freq, m);
        if (in_freq < 2_660_000) continue;
        if (in_freq > 16_000_000) break;

        var n = @enumToInt(Multiplier.min());
        const max = @enumToInt(Multiplier.max());
        while (n <= max) : (n += 1) {
            const vco_freq = in_freq * n;
            if (vco_freq > max_vco_freq) break;

            const vco_error = std.math.absCast(target_vco_freq - vco_freq);
            if (vco_error == 0) {
                findPllParamsManual(parsed, m, n);
                return;
            } else if (best_error == null or vco_error < best_error.?) {
                parsed.pll_in_frequency_hz = in_freq;
                parsed.pll_vco_frequency_hz = vco_freq;
                parsed.pll_m = Divisor.fromDivisor(m);
                parsed.pll_n = @intToEnum(Multiplier, n);
                best_error = vco_error;
            }
        }
    }

    if (best_error) |_| {
        @compileError(std.fmt.comptimePrint(
            \\Can't generate requested PLL VCO frequency.  Closest match was:
            \\       Source frequency: {}
            \\       PLL in frequency: {} (M = {s})
            \\      PLL VCO frequency: {} (N = {s})
            \\   Target VCO frequency: {} (error = {})
        , .{
            fmtFrequency(source_freq),
            fmtFrequency(parsed.pll_in_frequency_hz), @tagName(parsed.pll_m),
            fmtFrequency(parsed.pll_vco_frequency_hz), @tagName(parsed.pll_n),
            fmtFrequency(target_vco_freq), fmtFrequency(std.math.absCast(parsed.pll_vco_frequency_hz - target_vco_freq)),
        }));
    } else {
        @compileError("Can't generate requested PLL VCO frequency");
    }
}}

fn findPllParamsAuto(comptime parsed: *ParsedConfig) void { comptime {
    const Divisor = rcc.PLLMDivisor;
    const Multiplier = rcc.PLLNMultiplier;
    const PDivisor = rcc.PLLPDivisor;
    const RDivisor = rcc.PLLRDivisor;

    const target_p_freq = parsed.pll_p_frequency_hz;
    const target_r_freq = parsed.pll_r_frequency_hz;
    const source_freq = parsed.pll_in_frequency_hz;
    var best_error: ?comptime_int = null;

    if (target_p_freq == 0 and target_r_freq == 0) {
        @compileError("All PLL clock outputs are disabled, but the PLL itself is enabled; just use `.pll = null` instead");
    }

    const max_vco_freq = switch (parsed.vcore) {
        .low_power, .mid_range => 128_000_000,
        .high_performance => 344_000_000,
    };

    var m = @as(comptime_int, Divisor.max().divisor());
    const min = Divisor.min().divisor();
    while (m >= min) : (m -= 1) {
        const in_freq = divRound(source_freq, m);
        if (in_freq < 2_660_000) continue;
        if (in_freq > 16_000_000) break;

        var n = @as(comptime_int, @enumToInt(Multiplier.min()));
        const max = @enumToInt(Multiplier.max());
        while (n <= max) : (n += 1) {
            const vco_freq = in_freq * n;
            if (vco_freq > max_vco_freq) break;

            const p = if (target_p_freq == 0) PDivisor.max().divisor() else divRound(vco_freq, target_p_freq);
            const r = if (target_r_freq == 0) RDivisor.max().divisor() else divRound(vco_freq, target_r_freq);
            if (p > PDivisor.max().divisor() or r > RDivisor.max().divisor()) break;
            if (p < PDivisor.min().divisor() or r < RDivisor.min().divisor()) continue;

            const p_freq = divRound(vco_freq, p);
            const r_freq = divRound(vco_freq, r);

            const p_error = if (target_p_freq == 0) 0 else (p_freq - target_p_freq);
            const r_error = if (target_r_freq == 0) 0 else (r_freq - target_r_freq);
            const pr_error = std.math.absCast(p_error) + std.math.absCast(r_error);

            if (best_error == null or pr_error < best_error.?) {
                parsed.pll_m = Divisor.fromDivisor(m);
                parsed.pll_in_frequency_hz = in_freq;
                parsed.pll_n = @intToEnum(Multiplier, n);
                parsed.pll_vco_frequency_hz = vco_freq;
                parsed.pll_p = PDivisor.fromDivisor(p);
                parsed.pll_p_frequency_hz = if (target_p_freq == 0) 0 else p_freq;
                parsed.pll_r = RDivisor.fromDivisor(r);
                parsed.pll_r_frequency_hz = if (target_r_freq == 0) 0 else r_freq;
                if (pr_error == 0) {
                    return;
                } else {
                    best_error = pr_error;
                }
            }
        }
    }

    if (best_error) |_| {
        @compileError(std.fmt.comptimePrint(
            \\Can't generate requested PLL frequencies.  Closest match was:
            \\     Source frequency: {}
            \\     PLL in frequency: {} (M = {s})
            \\    PLL VCO frequency: {} (N = {s})
            \\      PLL P frequency: {} (P = {s})
            \\   Target P frequency: {} (error = {})
            \\      PLL R frequency: {} (R = {s})
            \\   Target R frequency: {} (error = {})
        , .{
            fmtFrequency(source_freq),
            fmtFrequency(parsed.pll_in_frequency_hz), @tagName(parsed.pll_m),
            fmtFrequency(parsed.pll_vco_frequency_hz), @tagName(parsed.pll_n),
            fmtFrequency(parsed.pll_p_frequency_hz), @tagName(parsed.pll_p),
            fmtFrequency(target_p_freq), fmtFrequency(std.math.absCast(parsed.pll_p_frequency_hz - target_p_freq)),
            fmtFrequency(parsed.pll_r_frequency_hz), @tagName(parsed.pll_r),
            fmtFrequency(target_r_freq), fmtFrequency(std.math.absCast(parsed.pll_r_frequency_hz - target_r_freq)),
        }));
    } else {
        @compileError("Can't generate requested PLL frequencies");
    }
}}

fn checkFrequency(comptime name: []const u8, comptime freq: comptime_int, comptime min: comptime_int, comptime max: comptime_int) void { comptime {
    if (freq < min) {
        invalidFrequency(name, freq, ">=", min);
    } else if (freq > max) {
        invalidFrequency(name, freq, "<=", max);
    }
}}

fn invalidFrequency(comptime name: []const u8, comptime actual: comptime_int, comptime dir: []const u8, comptime limit: comptime_int) void { comptime {
    @compileError(std.fmt.comptimePrint("Invalid {s} frequency: {}; must be {s} {}", .{
        name, fmtFrequency(actual),
        dir, fmtFrequency(limit),
    }));
}}

pub fn init(comptime config: Config) void {
    const parsed = comptime blk: {
        @setEvalBranchQuota(2_000);
        break :blk parseConfig(config);
    };

    // turn on oscillators as necessary
    if (parsed.hsi_frequency_hz > 0 or parsed.hse_frequency_hz > 0) {
        var cr = registers.RCC.CR.read();
        if (parsed.hsi_frequency_hz > 0) {
            cr.HSION = .oscillator_enabled;
            cr.HSIDIV = parsed.hsidiv;
        }
        if (parsed.hse_frequency_hz > 0) {
            cr.HSEON = .oscillator_enabled;
            cr.HSEBYP = parsed.hse_bypass;
        }
        registers.RCC.CR.write(cr);
    }
    if (parsed.lsi_frequency_hz > 0) {
        registers.RCC.CSR.modify(.{ .LSION = .oscillator_enabled });
    }
    if (parsed.lse_frequency_hz > 0) {
        registers.RCC.BDCR.modify(.{
            .LSEON = .oscillator_enabled,
            .LSEBYP = parsed.lse_bypass,
            .LSEDRV = parsed.lse_drive,
        });
    }

    // Wait for the oscillators we need to stabilize
    if (parsed.hsi_frequency_hz > 0) {
        while (registers.RCC.CR.read().HSIRDY != .oscillator_stable) {}
    }
    if (parsed.hse_frequency_hz > 0) {
        while (registers.RCC.CR.read().HSERDY != .oscillator_stable) {}
    }

    if (parsed.pll_in_source) |source_domain| {
        const source = switch (source_domain) {
            .hsi => .HSI,
            .hse => .HSE,
            else => unreachable,
        };

        var pllcfg = @TypeOf(registers.RCC.PLLCFGR.*).underlying_type {
            .PLLSRC = source,
            .PLLM = parsed.pll_m,
            .PLLN = parsed.pll_n,
            .PLLP = parsed.pll_p,
            .PLLR = parsed.pll_r,
        };

        registers.RCC.PLLCFGR.write(pllcfg);
        registers.RCC.CR.modify(.{ .PLLON = .oscillator_enabled });
        if (parsed.pll_p_frequency_hz > 0) pllcfg.PLLPEN = .oscillator_enabled;
        if (parsed.pll_r_frequency_hz > 0) pllcfg.PLLREN = .oscillator_enabled;
        while (registers.RCC.CR.read().PLLRDY != .oscillator_stable) {}
        registers.RCC.PLLCFGR.write(pllcfg);
    }

    if (parsed.lsi_frequency_hz > 0) {
        while (registers.RCC.CSR.read().LSIRDY != .oscillator_stable) {}
    }
    if (parsed.lse_frequency_hz > 0) {
        while (registers.RCC.BDCR.read().LSERDY != .oscillator_stable) {}
    }

    if (parsed.wait_states != .zero) {
        registers.FLASH.ACR.write(.{
            .LATENCY = parsed.wait_states,
            .PRFTEN = .prefetch_enabled,
            .ICEN = .cache_enabled,
        });
        while (registers.FLASH.ACR.read().LATENCY != parsed.wait_states) {}
    }

    if (parsed.sys_source != .hsi or parsed.ahb_prescale.enabled or parsed.apb_prescale.enabled or parsed.mco_source != null) {
        var cfgr = registers.RCC.CFGR.read();

        if (parsed.sys_source != .hsi) {
            cfgr.SW = switch (parsed.sys_source) {
                .lsi => .LSI,
                .lse => .LSE,
                .hse => .HSE,
                .pll_r => .PLLRCLK,
                else => unreachable,
            };
        }

        if (parsed.ahb_prescale.enabled) cfgr.HPRE = parsed.ahb_prescale;
        if (parsed.apb_prescale.enabled) cfgr.PPRE = parsed.apb_prescale;

        if (parsed.mco_source) |source_domain| {
            cfgr.MCOSEL = switch (source_domain) {
                .sys => .SYSCLK,
                .hsi => .HSI16,
                .hse => .HSE,
                .pll_r => .PLLRCLK,
                .lsi => .LSI,
                .lse => .LSE,
                else => unreachable,
            };
            cfgr.MCOPRE = parsed.mco_prescale;
        }

        registers.RCC.CFGR.write(cfgr);
    }

    switch (parsed.vcore) {
        .low_power => registers.PWR.CR1.modify(.{
            .LPR = 1,
            .VOS = 2
        }),
        .mid_range => registers.PWR.CR1.modify(.{
            .VOS = 2
        }),
        .high_performance => {},
    }

    if (parsed.lsco_source != null or parsed.rtc_source != null) {
        var bdcr = registers.RCC.BDCR.read();

        if (parsed.lsco_source) |source_domain| {
            bdcr.LSCOSEL = switch (source_domain) {
                .lsi => .LSI,
                .lse => .LSE,
                else => unreachable,
            };
            bdcr.LSCOEN = .clock_enabled;
        }

        if (parsed.rtc_source) |source_domain| {
            bdcr.RTCSEL = switch (source_domain) {
                .lsi => .LSI,
                .lse => .LSE,
                .hse => .HSE_div32,
                else => unreachable,
            };
            bdcr.RTCEN = .clock_enabled;
        }

        registers.RCC.BDCR.write(bdcr);
    }

    if (parsed.adc_source != .sys or parsed.i2s_source != .sys or parsed.usart_source != .apb or parsed.i2c_source != .apb) {
        var ccipr = registers.RCC.CCIPR.read();

        switch (parsed.adc_source) {
            .sys => {},
            .pll_p => ccipr.ADCSEL = .PLLPCLK,
            .hsi => ccipr.ADCSEL = .HSI16,
            else => unreachable,
        }

        switch (parsed.i2s_source) {
            .sys => {},
            .pll_p => ccipr.I2SSEL = .PLLPCLK,
            .hsi => ccipr.I2SSEL = .HSI16,
            .i2s_clkin => ccipr.I2SSEL = .I2S_CKIN,
            else => unreachable,
        }

        switch (parsed.usart_source) {
            .apb => {},
            .sys => ccipr.USARTSEL = .SYSCLK,
            .hsi => ccipr.USARTSEL = .HSI16,
            .lse => ccipr.USARTSEL = .LSE,
            else => unreachable,
        }

        switch (parsed.i2c_source) {
            .apb => {},
            .sys => ccipr.USARTSEL = .SYSCLK,
            .hsi => ccipr.USARTSEL = .HSI16,
            else => unreachable,
        }

        registers.RCC.CCIPR.write(ccipr);
    }

    if (parsed.tick_source) |source_domain| {
        const source: u1 = switch (source_domain) {
            .ahb => 1,
            .ahb_div8 => 0,
            else => unreachable,
        };
        registers.SCS.SysTick.LOAD.write(.{
            .RELOAD = parsed.tick_reload,
        });
        registers.SCS.SysTick.VAL.write(.{
            .CURRENT = 0,
        });
        registers.SCS.SysTick.CTRL.write(.{
            .CLKSOURCE = source,
            .TICKINT = 1,
            .ENABLE = 1,
        });
    }
}

pub inline fn handleTickInterrupt() void {
    if (registers.SCS.SysTick.CTRL.read().COUNTFLAG != 0) {
        microbe.clock.current_tick.raw +%= 1;
        microtick_base +%= microbe.clock.getConfig().tick_reload + 1;
    }
}

var microtick_base: i64 = 0;

pub inline fn currentMicrotick() microbe.clock.Microtick {
    const tick_reload = microbe.clock.getConfig().tick_reload;
    var cs = microbe.interrupts.enterCriticalSection();
    defer cs.leave();

    var val = registers.SCS.SysTick.VAL.read().CURRENT;
    if (registers.SCS.SysTick.CTRL.read().COUNTFLAG != 0) {
        val = registers.SCS.SysTick.VAL.read().CURRENT;
        microbe.clock.current_tick.raw +%= 1;
        microtick_base +%= tick_reload + 1;
    }
    var raw = microtick_base;
    if (val > 0) {
        raw +%= @as(u24, tick_reload + 1) -% val;
    }
    return .{ .raw = raw };
}
