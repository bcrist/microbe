const std = @import("std");
const microbe = @import("microbe");
const chip = microbe.chip;
const dma = chip.dma;

const PadID = chip.PadID;

const checkPad = microbe.pads.isInSet;

pub const Config = struct {
    baud_rate: comptime_int,
    data_bits: enum (u4) {
        seven = 7,
        eight = 8,
    } = .eight,
    parity: ?chip.registers.types.usart.Parity = null,
    stop_bits: chip.registers.types.usart.StopBits = .one,
    which: ?enum {
        USART1,
        USART2,
    } = null,
    tx: ?PadID,
    rx: ?PadID,
    cts: ?PadID = null,
    rts: ?PadID = null,
    tx_buffer_size: comptime_int = 0,
    rx_buffer_size: comptime_int = 0,
    tx_dma_channel: ?dma.Channel = null,
    rx_dma_channel: ?dma.Channel = null,
};

const Registers = struct {
    basic_uart: bool,
    CR1: @TypeOf(chip.registers.USART1.CR1),
    CR2: @TypeOf(chip.registers.USART1.CR2),
    CR3: @TypeOf(chip.registers.USART1.CR3),
    BRR: @TypeOf(chip.registers.USART1.BRR),
    GTPR: @TypeOf(chip.registers.USART1.GTPR),
    RTOR: @TypeOf(chip.registers.USART1.RTOR),
    RQR: @TypeOf(chip.registers.USART1.RQR),
    ISR: @TypeOf(chip.registers.USART1.ISR),
    ICR: @TypeOf(chip.registers.USART1.ICR),
    RDR: @TypeOf(chip.registers.USART1.RDR),
    TDR: @TypeOf(chip.registers.USART1.TDR),
    PRESC: @TypeOf(chip.registers.USART1.PRESC),
};

const Usart = enum {
    USART1,
    USART1_swap_TX_RX,
    USART2,
    USART2_swap_TX_RX,
};

pub fn Impl(comptime config: Config) type {
    const tx_usart: ?Usart = if (config.tx) |tx| blk: {
        if (checkPad(tx, .{ .PA9, .PB6 })) break :blk .USART1;
        if (checkPad(tx, .{ .PA10, .PB7 })) break :blk .USART1_swap_TX_RX;
        if (checkPad(tx, .{ .PA2, .PA14 })) break :blk .USART2;
        if (checkPad(tx, .{ .PA3, .PA15 })) break :blk .USART2_swap_TX_RX;
        @compileError("Invalid TX pin");
    } else null;

    const rx_usart: ?Usart = if (config.rx) |rx| blk: {
        if (checkPad(rx, .{ .PA9, .PB6 })) break :blk .USART1_swap_TX_RX;
        if (checkPad(rx, .{ .PA10, .PB7 })) break :blk .USART1;
        if (checkPad(rx, .{ .PA2, .PA14 })) break :blk .USART2_swap_TX_RX;
        if (checkPad(rx, .{ .PA3, .PA15 })) break :blk .USART2;
        @compileError("Invalid RX pin");
    } else null;

    const which = tx_usart orelse (rx_usart orelse @compileError("UART with neither TX nor RX is useless"));
    const half_duplex = std.meta.eql(config.tx, config.rx);
    if ((rx_usart orelse which) != which and !half_duplex) {
        @compileError(std.fmt.comptimePrint("TX requires {s} but RX requires {s}", .{
            @tagName(tx_usart.?),
            @tagName(rx_usart.?),
        }));
    }

    if (config.which) |config_usart| {
        if (config_usart != switch (which) {
            .USART1, .USART1_swap_TX_RX => .USART1,
            .USART2, .USART2_swap_TX_RX => .USART2,
        }) @compileError(std.fmt.comptimePrint("Asked for {s} but pad configuration requires {s}", .{
            @tagName(config_usart),
            @tagName(which),
        }));
    }

    comptime var pads: []const PadID = &.{};

    if (config.tx) |tx| {
        pads = pads ++ &[_]PadID { tx };
        if (config.cts) |cts| {
            pads = pads ++ &[_]PadID { cts };
            if (!switch (which) {
                .USART1, .USART1_swap_TX_RX => checkPad(cts, .{ .PA11, .PB4 }),
                .USART2, .USART2_swap_TX_RX => checkPad(cts, .{ .PA0, .PD3 }),
            }) @compileError("Invalid CTS pin");
        }
    } else if (config.cts != null) {
        @compileError("CTS without TX is useless");
    }

    if (config.rx) |rx| {
        pads = pads ++ &[_]PadID { rx };
        if (config.rts) |rts| {
            pads = pads ++ &[_]PadID { rts };
            if (!switch (which) {
                .USART1, .USART1_swap_TX_RX => checkPad(rts, .{ .PA12, .PB3 }),
                .USART2, .USART2_swap_TX_RX => checkPad(rts, .{ .PA1 }),
            }) @compileError("Invalid RTS pin");
        }
    } else if (config.rts != null) {
        @compileError("RTS without RX is useless");
    }

    if (config.rx_dma_channel != null and std.meta.eql(config.rx_dma_channel, config.tx_dma_channel)) {
        @compileError("RX and TX may not use the same DMA channel");
    }

    comptime var afs: []const []const u8 = &.{};
    for (pads) |pad| {
        if (checkPad(pad, .{ .PA1 }))             { afs = afs ++ &[_][]const u8 { "USART2_RTS" }; }
        else if (checkPad(pad, .{ .PA0, .PD3 }))  { afs = afs ++ &[_][]const u8 { "USART2_CTS" }; }
        else if (checkPad(pad, .{ .PA2, .PA14 })) { afs = afs ++ &[_][]const u8 { "USART2_TX" }; }
        else if (checkPad(pad, .{ .PA3, .PA15 })) { afs = afs ++ &[_][]const u8 { "USART2_RX" }; }
        else if (checkPad(pad, .{ .PA9, .PB6 }))  { afs = afs ++ &[_][]const u8 { "USART1_TX" }; }
        else if (checkPad(pad, .{ .PA10, .PB7 })) { afs = afs ++ &[_][]const u8 { "USART1_RX" }; }
        else if (checkPad(pad, .{ .PA11, .PB4 })) { afs = afs ++ &[_][]const u8 { "USART1_CTS" }; }
        else if (checkPad(pad, .{ .PA12, .PB3 })) { afs = afs ++ &[_][]const u8 { "USART1_RTS" }; }
    }

    const registers: Registers = switch (which) {
        .USART1, .USART1_swap_TX_RX => .{
            .basic_uart = false,
            .CR1 = chip.registers.USART1.CR1,
            .CR2 = chip.registers.USART1.CR2,
            .CR3 = chip.registers.USART1.CR3,
            .BRR = chip.registers.USART1.BRR,
            .GTPR = chip.registers.USART1.GTPR,
            .RTOR = chip.registers.USART1.RTOR,
            .RQR = chip.registers.USART1.RQR,
            .ISR = chip.registers.USART1.ISR,
            .ICR = chip.registers.USART1.ICR,
            .RDR = chip.registers.USART1.RDR,
            .TDR = chip.registers.USART1.TDR,
            .PRESC = chip.registers.USART1.PRESC,
        },
        .USART2, .USART2_swap_TX_RX => .{
            .basic_uart = true,
            .CR1 = chip.registers.USART2.CR1,
            .CR2 = chip.registers.USART2.CR2,
            .CR3 = chip.registers.USART2.CR3,
            .BRR = chip.registers.USART2.BRR,
            .GTPR = chip.registers.USART2.GTPR,
            .RTOR = chip.registers.USART2.RTOR,
            .RQR = chip.registers.USART2.RQR,
            .ISR = chip.registers.USART2.ISR,
            .ICR = chip.registers.USART2.ICR,
            .RDR = chip.registers.USART2.RDR,
            .TDR = chip.registers.USART2.TDR,
            .PRESC = chip.registers.USART2.PRESC,
        },
    };

    return struct {
        rxi: Rx = .{},
        txi: Tx = .{},

        pub const DataType = u8;
        pub const ExactDataType = std.meta.Int(.unsigned, @enumToInt(config.data_bits));
        const Self = @This();

        const Rx = blk: {
            if (config.rx == null) {
                break :blk NoRx;
            } else if (config.rx_buffer_size == 0) {
                break :blk UnbufferedRx(Self, registers, config.parity != null);
            } else if (config.rx_dma_channel) |channel| {
                break :blk DmaRx(Self, registers, channel);
            } else {
                break :blk InterruptRx(Self, registers);
            }
        };

        const Tx = blk: {
            if (config.tx == null) {
                break :blk NoTx;
            } else if (config.tx_buffer_size == 0) {
                break :blk UnbufferedTx(Self, registers);
            } else if (config.tx_dma_channel) |channel| {
                break :blk DmaTx(Self, registers, channel);
            } else {
                break :blk InterruptTx(Self, registers);
            }
        };

        pub fn init() Self {
            microbe.pads.reserve(pads, "UART");

            switch (which) {
                .USART1, .USART1_swap_TX_RX => chip.registers.RCC.APBENR2.modify(.{ .USART1EN = .clock_enabled }),
                .USART2, .USART2_swap_TX_RX => chip.registers.RCC.APBENR1.modify(.{ .USART2EN = .clock_enabled }),
            }

            registers.CR1.modify(.{
                .UE = .usart_disabled,
            });

            chip.gpio.ensurePortsEnabled(pads);

            if (config.tx) |tx| {
                chip.gpio.configureSlewRate(&[_]PadID { tx }, .slow);
                if (half_duplex) {
                    chip.gpio.configureDriveMode(&[_]PadID { tx }, .open_drain);
                } else {
                    chip.gpio.configureDriveMode(&[_]PadID { tx }, .push_pull);
                }
            }
            if (config.rts) |rts| {
                chip.gpio.configureDriveMode(&[_]PadID { rts }, .push_pull);
                chip.gpio.configureSlewRate(&[_]PadID { rts }, .slow);
            }

            if (config.rx) |rx| {
                if (half_duplex) {
                    chip.gpio.configureTermination(&[_]PadID { rx }, .pull_up);
                } else {
                    chip.gpio.configureTermination(&[_]PadID { rx }, .pull_down);
                }
            }
            if (config.cts) |cts| {
                chip.gpio.configureTermination(&[_]PadID { cts }, .pull_up);
            }

            chip.gpio.configureAsAlternateFunction(pads, afs);

            const ker_clk = microbe.clock.getFrequency(.usart);
            const raw_brr = @divTrunc(ker_clk + config.baud_rate / 2, config.baud_rate);

            // TODO Do some checks to see if the baud rate is too high (or perhaps too low)
            // TODO Use OVER8 = .oversample_x8 if baud rate is too high compared to clock source
            var cr1 = chip.registers.types.usart.CR1 {
                .OVER8 = .oversample_x16,
            };

            comptime var raw_bits: u4 = @enumToInt(config.data_bits);
            if (config.parity != null) {
                raw_bits += 1;
            }
            std.debug.assert(raw_bits >= 7);
            std.debug.assert(raw_bits <= 9);
            cr1.M0 = if (raw_bits == 9) 1 else 0;
            cr1.M1 = if (raw_bits == 7) 1 else 0;

            if (config.parity) |parity| {
                cr1.PCE = .parity_enabled;
                cr1.PS = parity;
            }

            if (!registers.basic_uart) {
                cr1.FIFOEN = .fifo_enabled;
            }

            var cr2 = chip.registers.types.usart.CR2 {
                .STOP = config.stop_bits,
            };

            switch (which) {
                .USART1, .USART2 => {},
                .USART1_swap_TX_RX, .USART2_swap_TX_RX => {
                    cr2.SWAP = .swap_tx_rx;
                },
            }

            var cr3 = chip.registers.types.usart.CR3 {};
            if (half_duplex) cr3.HDSEL = .half_duplex;
            if (config.rts != null) cr3.RTSE = .RTS_enabled;
            if (config.cts != null) cr3.CTSE = .CTS_enabled;

            registers.CR1.write(cr1);
            registers.CR2.write(cr2);
            registers.CR3.write(cr3);

            // TODO use prescaler when it won't affect baud rate accuracy much (for non-basic UART)
            registers.PRESC.write(.{
                .PRESC = .div1,
            });

            registers.BRR.write(.{
                .BRR_0_3 = @truncate(u4, raw_brr),
                .BRR_4_15 = @intCast(u12, raw_brr >> 4),
            });

            registers.RQR.write(.{
                .RXFRQ = .request_flush_RX_data,
                .TXFRQ = .request_flush_TX_data,
            });

            var self = Self {};
            self.rxi.initRx();
            self.txi.initTx();
            return self;
        }

        pub fn start(self: *Self) void {
            self.rxi.startRx();
            self.txi.startTx();
            registers.CR1.modify(.{
                .UE = .usart_enabled,
            });
        }

        pub fn stop(self: *Self) void {
            self.txi.stopTx();
            self.rxi.stopRx();
            while (!self.txi.isTxIdle()) {}
            registers.CR1.modify(.{
                .UE = .usart_disabled,
            });
        }

        pub fn deinit(self: *Self) void {
            self.txi.deinitTx();
            self.rxi.deinitRx();

            registers.CR1.modify(.{
                .UE = .usart_disabled,
                .RE = .receiver_disabled,
                .TE = .transmitter_disabled,
            });
            switch (which) {
                .USART1, .USART1_swap_TX_RX => chip.registers.RCC.APBENR2.modify(.{ .USART1EN = .clock_disabled }),
                .USART2, .USART2_swap_TX_RX => chip.registers.RCC.APBENR1.modify(.{ .USART2EN = .clock_disabled }),
            }
            chip.gpio.configureMODER(pads, .analog);
            chip.gpio.configureTermination(pads, .float);
            microbe.pads.release(pads, "UART");
        }

        pub usingnamespace Rx;
        pub usingnamespace Tx;
    };
}

const NoRx = struct {
    pub fn initRx(_: NoRx) void {}
    pub fn deinitRx(_: NoRx) void {}
    pub fn startRx(_: NoRx) void {}
    pub fn stopRx(_: NoRx) void {}
};

const NoTx = struct {
    pub fn initTx(_: NoTx) void {}
    pub fn deinitTx(_: NoTx) void {}
    pub fn startTx(_: NoTx) void {}
    pub fn stopTx(_: NoTx) void {}
};

fn UnbufferedRx(comptime I: type, comptime registers: Registers, comptime parity_enabled: bool) type {
    return struct {

        peek_byte: ?u8 = null,
        bytes_til_overrun: ?u4 = null,
        pending_error: ?ReadError = null,

        const Self = @This();
        pub const GenericReader = std.io.Reader;
        pub const ReadError = if (parity_enabled) error {
            Overrun,
            ParityError,
            FramingError,
            BreakInterrupt,
            NoiseError,
        } else error {
            Overrun,
            FramingError,
            BreakInterrupt,
            NoiseError,
        };

        pub fn initRx(_: Self) void {}

        pub fn deinitRx(_: Self) void {}

        pub fn startRx(_: Self) void {
            registers.CR1.modify(.{
                .RE = .receiver_enabled,
            });
        }
        pub fn stopRx(_: Self) void {
            registers.CR1.modify(.{
                .RE = .receiver_disabled,
            });
        }

        pub fn isRxIdle(_: I) bool {
            return registers.ISR.read().BUSY == .RX_idle;
        }

        pub fn canRead(impl: I) bool {
            return impl.rxi.peek_byte != null
                or impl.rxi.pending_error != null
                or registers.ISR.read().RXNE_RXFNE == .RXD_available;
        }

        pub fn peek(impl: *I, out: []u8) []const u8 {
            if (out.len == 0) {
                return out[0..0];
            } else if (impl.rxi.peek_byte) |b| {
                out[0] = b;
            } else if (impl.rxi.pending_error) |_| {
                return out[0..0];
            } else {
                const isr = registers.ISR.read();
                if (isr.RXNE_RXFNE == .RXD_available) {
                    checkNewByteErrors(&impl.rxi, isr) catch {
                        return out[0..0];
                    };
                    const b = @truncate(I.ExactDataType, impl.rxi.readByte());
                    impl.rxi.peek_byte = b;
                    out[0] = b;
                } else {
                    return out[0..0];
                }
            }
            return out[0..1];
        }

        pub fn rx(impl: *I) ReadError!u8 {
            if (impl.rxi.peek_byte) |b| {
                impl.rxi.peek_byte = null;
                return b;
            }

            if (impl.rxi.pending_error) |err| return err;

            // block until we've received something
            var isr = registers.ISR.read();
            while (isr.RXNE_RXFNE == .RXD_empty) {
                isr = registers.ISR.read();
            }

            try checkNewByteErrors(&impl.rxi, isr);

            return @truncate(I.ExactDataType, impl.rxi.readByte());
        }

        pub fn getReadError(impl: *I) ReadError!void {
            if (impl.rxi.peek_byte) |_| return;
            if (impl.rxi.pending_error) |err| return err;
            try checkNewByteErrors(&impl.rxi, registers.ISR.read());
        }

        fn checkNewByteErrors(self: *Self, isr: chip.registers.types.usart.ISR) ReadError!void {
            if (isr.FE == .framing_error_detected) {
                registers.ICR.write(.{
                    .FECF = .clear_error,
                    .PECF = .clear_error,
                    .NCF = .clear_error,
                });
                const b = self.readByte();
                const err: ReadError = if (b == 0) error.BreakInterrupt else error.FramingError;
                self.pending_error = err;
                return err;
            } else if (parity_enabled and isr.PE == .parity_error_detected) {
                registers.ICR.write(.{
                    .PECF = .clear_error,
                    .NCF = .clear_error,
                });
                _ = self.readByte();
                self.pending_error = error.ParityError;
                return error.ParityError;
            } else if (isr.NF == .noise_error_detected) {
                registers.ICR.write(.{
                    .NCF = .clear_error,
                });
                self.pending_error = error.NoiseError;
                return error.NoiseError;
            }
        }

        pub fn clearReadError(impl: *I, _: ReadError) void {
            impl.rxi.pending_error = null;
        }

        // assumes peek_byte, pending_error, ISR.FE/PE/NF have already been checked/cleared, and ISR.RXNE_RXFNE == .RXD_available
        fn readByte(self: *Self) u8 {
            if (self.bytes_til_overrun) |bytes_remaining| {
                if (bytes_remaining == 1) {
                    var data = @truncate(u8, registers.RDR.read());
                    registers.RQR.write(.{ .RXFRQ = .request_flush_RX_data });
                    registers.ICR.write(.{ .ORECF = .clear_error });
                    self.bytes_til_overrun = null;
                    self.pending_error = error.Overrun;
                    return data;
                } else {
                    std.debug.assert(bytes_remaining != 0);
                    self.bytes_til_overrun = bytes_remaining - 1;
                    return @truncate(u8, registers.RDR.read());
                }
            } else {
                var data = @truncate(u8, registers.RDR.read());
                if (registers.ISR.read().ORE == .rx_overrun_error_detected) {
                    if (registers.basic_uart) {
                        registers.ICR.write(.{ .ORECF = .clear_error });
                        self.pending_error = error.Overrun;
                    } else {
                        self.bytes_til_overrun = 8;
                    }
                }
                return data;
            }
        }
    };
}

fn UnbufferedTx(comptime I: type, comptime registers: Registers) type {
    return struct {
        const Self = @This();
        pub const GenericWriter = std.io.Writer;
        pub const WriteError = error {};

        pub fn initTx(_: Self) void {}
        pub fn deinitTx(_: Self) void {}
        pub fn startTx(_: Self) void {
            registers.CR1.modify(.{
                .TE = .transmitter_enabled,
            });
        }

        pub fn stopTx(_: Self) void {
            registers.CR1.modify(.{
                .TE = .transmitter_disabled,
            });
        }

        pub fn isTxIdle(_: I) bool {
            return registers.ISR.read().TC == .TX_complete;
        }

        pub fn canWrite(_: I) bool {
            return registers.ISR.read().TXE_TXFNF == .TXD_available;
        }

        pub fn tx(_: I, byte: u8) void {
            // block until we've got space
            var isr = registers.ISR.read();
            while (isr.TXE_TXFNF == .TXD_full) {
                isr = registers.ISR.read();
            }

            registers.TDR.raw = byte;
        }
    };
}

fn InterruptRx(comptime I: type, comptime registers: Registers) type {
    _ = I;
    _ = registers;
    @compileError("Not implemented yet");
}

fn InterruptTx(comptime I: type, comptime registers: Registers) type {
    _ = I;
    _ = registers;
    @compileError("Not implemented yet");
}

fn DmaRx(comptime I: type, comptime registers: Registers, comptime channel: dma.Channel) type {
    _ = I;
    _ = registers;
    _ = channel;
    @compileError("Not implemented yet");
}

fn DmaTx(comptime I: type, comptime registers: Registers, comptime channel: dma.Channel) type {
    _ = I;
    _ = registers;
    _ = channel;
    @compileError("Not implemented yet");
}
