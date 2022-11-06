const std = @import("std");
const microbe = @import("microbe");
const core = microbe.core;

pub const log = microbe.defaultLog;

pub var uart1: microbe.Uart(.{
    .baud_rate = 9600,
    .tx = .PA9,
    .rx = .PA10,
    // .cts = .PA11,
    // .rts = .PA12,
}) = undefined;

pub fn main() !void {
    const test_bus = microbe.bus.Bus("Test", .{ .PA2, .PA3, .PA4, .PB4, .PB6 }, .{ .mode = .output }).init();
    test_bus.modifyInline(7);
    test_bus.modifyInline(17);
    test_bus.modifyInline(7);

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

        var i: usize = 0;
        while (i < 10_000_000) : (i += 1) {
            asm volatile ("" ::: "memory");
        }
    }
}
