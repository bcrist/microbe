const std = @import("std");
pub const chip = @import("chip");
const microbe = @import("microbe");

comptime {
    _ = @import("config");
    _ = @import("chip");
}

pub const panic = microbe.defaultPanic;
pub const std_options = struct {
    pub const logFn = microbe.defaultLog;
};

pub const clocks = chip.clocks.Config {
    .hsi_enabled = true,
    .hse_frequency_hz = 4_300_000,
    .pll = .{
        .source = .hse,
        .r_frequency_hz = 44_842_857,
    },
    .sys_source = .{ .pll_r = {} },
    .tick = .{ .period_ns = 999_981 },
    .usart_source = .hsi,
};

pub const interrupts = struct {
    pub const SysTick = chip.clocks.handleTickInterrupt;
};

pub var uart1: microbe.uart.Uart(.{
    .baud_rate = 9600,
    .tx = .PA9,
    .rx = .PA10,
    // .cts = .PA11,
    // .rts = .PA12,
}) = undefined;


const TestBus = microbe.bus.Bus("Test", .{ .PA2, .PA3, .PA4, .PB4, .PB6 }, .{ .mode = .output });

pub fn main() !void {
    TestBus.init();
    TestBus.modifyInline(7);
    TestBus.modifyInline(17);
    TestBus.modifyInline(7);

    uart1 = @TypeOf(uart1).init();
    uart1.start();

    while (true) {
        if (uart1.canRead()) {
            var writer = uart1.writer();
            var reader = uart1.reader();

            try writer.writeAll(":");

            while (uart1.canRead()) {
                var b = reader.readByte() catch |err| {
                    const s = switch (err) {
                        error.Overrun => "!ORE!",
                        error.FramingError => "!FE!",
                        error.NoiseError =>   "!NE!",
                        error.EndOfStream => "!EOS!",
                        error.BreakInterrupt => "!BRK!",
                    };
                    try writer.writeAll(s);
                    continue;
                };

                switch (b) {
                    ' '...'[', ']'...'~' => try writer.writeByte(b),
                    else => try writer.print("\\x{x}", .{ b }),
                }
            }

            try writer.writeAll("\r\n");
        }

        chip.clocks.blockUntilMicrotick(chip.clocks.currentMicrotick().plus(.{ .seconds = 2 }));
    }
}
