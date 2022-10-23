//! This is the entry point and root file of microzig.
//! If you do a @import("microzig"), you'll *basically* get this file.
//!
//! But microzig employs a proxy tactic

const std = @import("std");
const root = @import("root");
const builtin = @import("builtin");
const init = @import("init");

/// The package that defines the main() function to be called after reset.
pub const main = @import("main");

/// Contains build-time generated configuration options.
/// Currently just core and chip names.
pub const config = @import("microbe-config");

/// Provides low-level access to the current microcontroller.
pub const chip = @import("chip");

/// Provides low-level access to the current microcontroller's core/CPU.
pub const core = @import("core");

pub const interrupts = @import("interrupts.zig");
// pub const clock = @import("clock.zig");

// pub const gpio = @import("gpio.zig");
// pub const Gpio = gpio.Gpio;

// pub const pin = @import("pin.zig");
// pub const Pin = pin.Pin;

// pub const uart = @import("uart.zig");
// pub const Uart = uart.Uart;

// pub const i2c = @import("i2c.zig");
// pub const I2CController = i2c.I2CController;

// pub const debug = @import("debug.zig");

// pub const mmio = @import("mmio.zig");

// log is a no-op by default. Parts of microbe use the stdlib logging
// facility and compilations will fail on freestanding systems that
// use it but do not explicitly set `root.log`
pub const log = main.log;
pub fn defaultLog(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    _ = message_level;
    _ = scope;
    _ = format;
    _ = args;
}
// Conditionally export log_level if main has it defined.
usingnamespace if (@hasDecl(main, "log_level"))
    struct {
        pub const log_level = main.log_level;
    }
else
    struct {};

// Allow main to override the panic handler
pub const panic = if (@hasDecl(main, "panic"))
    main.panic
else
    microbe_panic;

/// The microbe default panic handler. Will disable interrupts and loop endlessly.
pub fn microbe_panic(message: []const u8, _: ?*std.builtin.StackTrace) noreturn {
    std.log.err("microbe PANIC: {s}", .{ message });

    if (builtin.cpu.arch != .avr) {
        var index: usize = 0;
        var iter = std.debug.StackIterator.init(@returnAddress(), null);
        while (iter.next()) |address| : (index += 1) {
            if (index == 0) {
                std.log.err("stack trace:", .{});
            }
            std.log.err("{d: >3}: 0x{X:0>8}", .{ index, address });
        }
    }
    if (@import("builtin").mode == .Debug) {
        // attach a breakpoint, this might trigger another
        // panic internally, so only do that in debug mode.
        std.log.info("triggering breakpoint...", .{});
        @breakpoint();
    }
    hang();
}

/// Hangs the processor and will stop doing anything useful. Use with caution!
pub fn hang() noreturn {
    while (true) {
        //std.debug.todo("interrupts");
        //interrupts.cli();

        // "this loop has side effects, don't optimize the endless loop away please. thanks!"
        asm volatile ("" ::: "memory");
    }
}

comptime {
    // Export the vector table if we have any.
    // For a lot of systems, the vector table provides a reset vector
    // that is either called (Cortex-M) or executed (AVR) when initalized.
    // Allow chip to override the vector table.
    const export_opts = .{
        .name = "vt",
        .section = ".vector_table",
        .linkage = .Strong,
    };

    if (@hasDecl(chip, "vector_table"))
        @export(chip.vector_table, export_opts)
    else if (@hasDecl(core, "vector_table"))
        @export(core.vector_table, export_opts)
    else if (@hasDecl(main, "interrupts"))
        @compileError("interrupts not configured");
}

/// This is the logical entry point for microbe.
/// It will invoke the main function from the root source file and provide error return handling
export fn microbe_main() noreturn {
    if (!@hasDecl(main, "main"))
        @compileError("The root source file must provide a public function main!");

    const main_fn = @field(main, "main");
    const info: std.builtin.Type = @typeInfo(@TypeOf(main_fn));

    const invalid_main_msg = "main must be either 'pub fn main() void' or 'pub fn main() !void'.";
    if (info != .Fn or info.Fn.args.len > 0) {
        @compileError(invalid_main_msg);
    }

    const return_type = info.Fn.return_type orelse @compileError(invalid_main_msg);

    if (info.Fn.calling_convention == .Async) {
        @compileError("TODO: Embedded event loop not supported yet. Please try again later.");
    }

    // initialize static memory
    init.init();

    if (@hasDecl(main, "init")) {
        main.init();
    }

    if (@typeInfo(return_type) == .ErrorUnion) {
        main_fn() catch |err| {
            // TODO:
            // - Compute maximum size on the type of "err"
            // - Do not emit error names when std.builtin.strip is set.
            var msg: [64]u8 = undefined;
            @panic(std.fmt.bufPrint(&msg, "main() returned error {s}", .{@errorName(err)}) catch @panic("main() returned error."));
        };
    } else {
        main_fn();
    }

    // main returned, just hang around here a bit
    hang();
}
