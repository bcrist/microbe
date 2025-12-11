# Microbe

Microbe is a framework for developing embedded firmware in Zig, primarily targeting small 32-bit architectures like ARM Cortex-M0.  Some parts were originally based on [microzig](https://github.com/ZigEmbeddedGroup/microzig), but there were a few things about microzig that I didn't like (at least at the time).  It has been a long time and I have not kept up with microzig so I expect there are many significant differences at this point.

## Building
Add the main microbe dependency to your project:
```bash
zig fetch --save https://github.com/bcrist/microbe
```

Add a chip implementation dependency to your project:
```bash
zig fetch --save https://github.com/bcrist/microbe-rpi
```

Set up your `build.zig`:
```zig
const microbe = @import("microbe");
const std = @import("std");

pub fn build(b: *std.Build) void {
    microbe.addExecutable(.{
        .root_module = b.path("..."),
        .chip = ...
    });
}
```

See the examples in a chip implementation repo for more specific setup for a particular target.

## Conventions
All chip implementations should implement the symbols found in `template/chip.zig`.  Implementations are free to provide additional functionality, but if firmware can be written using only these "public" APIs then it should be relatively easy to port between different chips.

### Interrupt Configuration
Chip implementations should provide an enum `chip.interrupts.Interrupt` which lists all the "external" interrupts supported by the chip.  Additionally `chip.interrupts.Exception` should be an enum which includes all the interrupts, but also may contain synchronous exceptions & fault conditions.  The integer values associated with an interrupt need not be the same as the integer associated with the corresponding Exception.

Chip implementations should look for an `interrupts` struct in the root source file and automatically populate the vector table (or equivalent) with the addresses of the handlers provided within it.  The handler names must match the names from `chip.interrupts.Exception` exactly.

### Clock & Power Configuration
Chip implementations should provide a struct `chip.clocks.Config` which allows configuration of all the major clock domains on the chip.  The exact format will depend on the details of the architecture, but for every major clock domain in the chip, the clock config should have a field:
```zig
    xxx_frequency_hz: comptime_int
```

Where `xxx` is the name of the clock domain.  A frequency of 0 Hz should be considered to mean "clock disabled".  If a clock domain is sourced from another clock, it should additionally have a field:
```zig
    xxx_source: E
```
Where `E` is an enum type, or optional-wrapped enum type, giving the options that can be used as a source.

On reset, chip implementations should initialize the chip's clocks based on a `clocks` constant (of type `chip.clocks.Config`) declared in the root source file.  If no such declaration exists, the chip's default clock configuration should be used.

Chip implementations should also provide `chip.clocks.apply_config(...)` to allow dynamic clock changes.  Peripherals that are sensitive to clock frequencies (UARTs, PWMs etc.) will generally assume the clocks they use do not change, so care must be taken when using this.

Chip implementations should also provide `chip.clocks.get_config()` to provide a version of the configuration with additional details and defaults filled in.  This should be comptime callable.  If it does not return a `chip.clocks.Config` struct, it should return a `chip.clocks.Parsed_Config` struct.

The clock config struct may also contain fields for configuring low-power modes or other power-related features.

### UARTs
Chip implementations may provide one or more UART implementations that allow `std.io.Reader`/`std.io.Writer` streams to be used.  If there is only one implementation, `chip.uart.UART` should be a function that takes a comptime configuration struct and returns an implementation struct.  Multiple implementations may be provided via separate constructor functions.

The recommended names and types for some common configuration options are:

- `baud_rate_hz: comptime_int`
- `data_bits: enum`
    - Generally `.seven` or `.eight`, sometimes maybe other values
    - Should not include parity bit
- `parity: enum`
    - `.even`, `.odd`, or `.none`
- `stop_bits: enum`
    - Usually `.one` or `.two`, sometimes `.one_and_half` or `.half`
- `which: ?enum`
    - If the chip has multiple UART peripherals, allows selection of which one to use
    - If set to null, select automatically based on rx/tx pins specified
- `rx: ?Pad_ID`
    - The input pin to use for receiving, or null to disable receiving
- `tx: ?Pad_ID`
    - The output pin to use for transmitting, or null to disable transmitting
- `cts: ?Pad_ID`
    - The input pin to use for RTS/CTS bidirectional flow control
- `rts: ?Pad_ID`
    - The output pin to use for RTS/CTS bidirectional flow control
- `tx_buffer_size: comptime_int`
    - The size of the internal software transmit FIFO buffer
    - Set to 0 to disable interrupt/DMA driven I/O
- `rx_buffer_size: comptime_int`
    - The size of the internal software receive FIFO buffer
    - Set to 0 to disable interrupt/DMA driven I/O
- `tx_dma_channel: ?enum`
    - If multiple DMA channels are available, select one to use for transmission
    - Set to null to not use DMA for transmitted data
- `rx_dma_channel: ?enum`
    - If multiple DMA channels are available, select one to use for reception
    - Set to null to not use DMA for received data

All UART implementations should expose at least these declarations:

    fn init() Self
    fn start(*Self) void
    fn stop(*Self) void

Implementations that have reception capability should provide:

    fn is_rx_idle(*Self) bool // optional; some hardware may not be capable of reporting this
    fn get_rx_available_count(*Self) usize
    fn can_read(*Self) bool
    fn peek(*Self, []Data_Type) Read_Error![]const Data_Type
    fn peek_one(*Self) Read_Error!?Data_Type

    const Read_Error
    last_read_error: ?Read_Error
    reader: std.io.Reader

`Read_Error` usually consists of some subset of:

- `error.Overrun`
    - Indicates some received data was lost because older data was not read fast enough
    - Attempting to read again should return at least one word before another Overrun can occur
- `error.Parity_Error`
    - Indicates potential data corruption due to parity mismatch
    - The character received should still be provided if another read is performed
- `error.Framing_Error`
    - Indicates an incorrect line state during the stop bit, which may indicate data corruption, configuration mismatch, or severe clock drift
    - The character received should still be provided if another read is performed
- `error.Break_Interrupt`
    - Indicates an entire frame of 0 bits was received, including stop bits
    - May be used as a data separator in some protocols, or may indicate a broken cable or other physical issue
    - Note some implementations may not be capable of differentiating a break character from a framing error
- `error.Noise_Error`
    - Indicates that a signal transition was detected too close to the "center" of a bit period
    - May indicate borderline baud rate mismatch or significant noise on the line
    - The received noisy character should still be readable after this error is seen

Implementations that have transmission capability should provide:

    fn is_tx_idle(*Self) bool // optional; some hardware may not be capable of reporting this
    fn get_tx_available_count(*Self) usize
    fn can_write(*Self) bool

    const Write_Error
    last_write_error: ?Write_Error
    writer: std.io.Writer

Some implementations may require additional functions, e.g. to handle interrupts.
