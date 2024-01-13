# Microbe

Microbe is a framework for developing embedded firmware in Zig, primarily targeting small 32-bit architectures like ARM Cortex-M0.  It is similar in many ways to [microzig](https://github.com/ZigEmbeddedGroup/microzig) and in fact some parts were forked directly from that project.  But there are a few things about microzig that I didn't like:

* Microzig caters heavily to the use of development boards, which is great for beginners, but just adds a lot of unnecessary complexity if you're using a microcontroller directly on your project/product board.
* It forces a complex project structure on you.  You can't define the root source file yourself, instead it only exists in an "app" module.  There's a HAL (hardware abstraction layer) module that doesn't make sense; the entire project is a hardware abstraction layer, so why is there a HAL within the HAL?
* The use of anonymous types to represent pins is weird.  It seems the only reason is to ensure they're used at comptime, but you can do that just as easily with an enum passed as a `comptime` parameter.  The conflation of chip pins names and board pin names is annoying.
* The UART interface doesn't provide a non-blocking interface, or an easy way to support buffered implementations using interrupts or DMA.
* There's no facility to easily work with multiple GPIOs simultaneously as a parallel bus.
* The SVD-generated register types can be difficult to use, especially where a field would ideally be represented by an enum.

I don't bring these up to criticize the microzig project, but rather to highlight the areas where Microbe takes a different path.  If you haven't tried microzig yet but you're looking to do embedded programming with Zig, start there first.  If you have tried microzig but share some of the feelings I listed above, then this project may be useful to you.  And if you're a microzig contributor and think something you see here should be ported, let me know and I'll see if I can help.

## Building
Add this package to your `build.zig.zon` file and import it in your `build.zig` script as `microbe`.  Then just call `microbe.addExecutable(...)` instead of `std.Build.addExecutable(...)`, providing the chip and section information for your desired target.

You can find example applications and `build.zig` scripts here:
* [STM32](https://github.com/bcrist/microbe-stm32/tree/main/example)
* [RP2040](https://github.com/bcrist/microbe-rpi/tree/main/example)

## Conventions
There are a few API conventions that should be followed in order for chip-specific code to interact well with application code and the common code in this repo, as well as to make porting between architectures as easy as possible.

Most of the symbols that chip implementations are expected to expose can be found in `src/chip_interface.zig`.

### Interrupt Configuration
Chip implementations should provide an enum `chip.interrupts.Interrupt` which lists all the "external" (i.e. NVIC-controlled) interrupts supported by the chip.  The integer values associated with this enum indicate their offset in the NVIC registers.  Additionally `chip.interrupts.Exception` should be an enum which includes all the interrupts, but also may contain synchronous exceptions & fault conditions.  The integer values associated with this enum indicate the exception number.  An interrupts exception number is generally different from its interrupt number.

Chip implementations should look for an `interrupts` struct in the root source file and automatically populate the vector table with the addresses of the handlers provided within it.  The handler names must match the names from `chip.interrupts.Exception` exactly.

### Clock & Power Configuration
Chip implementations should provide a struct `chip.clocks.Config` which allows configuration of all the major clock domains on the chip.  The exact format will depend on the details of the architecture, but for every major clock domain in the chip, the clock config should have a field:

    xxx_frequency_hz: comptime_int

Where `xxx` is the name of the clock domain.  A frequency of 0 Hz should be considered to mean "clock disabled".  If a clock domain is sourced from another clock, it should additionally have a field:

    xxx_source: E

Where `E` is an enum type, or optional-wrapped enum type, giving the options that can be used as a source.

On reset, chip implementations should initialize the chip's clocks based on a `clocks` constant (of type `chip.clocks.Config`) declared in the root source file.  If no such declaration exists, the chip's default clock configuration should be used.

Chip implementations should also provide `chip.clocks.apply_config(...)` to allow dynamic clock changes.  Peripherals that are sensitive to clock frequencies (UARTs, PWMs etc.) will generally assume the clocks they use do not change, so care must be taken when using this.

Chip implementations may also provide `chip.clocks.get_config()` to provide a version of the configuration with additional details and defaults filled in.  This should be comptime callable.  If it does not return a `chip.clocks.Config` struct, it should return a `chip.clocks.Parsed_Config` struct.

The clock config struct may also contain fields for configuring low-power modes or other power-related features.

### UARTs
Chip implementations may provide one or more UART implementations that allow `std.io` streams to be used.  If there is only one implementation, `chip.uart.UART` should be a function that takes a comptime configuration struct and returns an implementation struct.  If multiple implementations are provided via separate constructor functions.

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

    const Data_Type // usually u8
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
    const Reader // usually std.io.Reader(..., Read_Error, ...)
    fn reader(*Self) Reader

    const Read_Error_Nonblocking
    const Reader_Nonblocking
    fn reader_nonblocking(*Self) Reader_Nonblocking

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
    const Writer // usually std.io.Writer(..., Write_Error, ...)
    fn writer(*Self) Writer

    const Write_Error_Nonblocking
    const Writer_Nonblocking
    fn writer_nonblocking(*Self) Writer_Nonblocking

The `Read_Error_Nonblocking` and `Write_Error_Nonblocking` should generally match include everything from the blocking variants, as well as `error.Would_Block`, which is returned when the buffer is empty/full and no more data can be read or written.  Ideally, when reading or writing multiple words, either the entire operation succeeds, or it has no effect if `Would_Block` is returned, except for functions that give feedback on how much work they accomplished (e.g. `Writer.write`).  This precludes the use of `std.io.Reader`/`Writer` for the non-blocking variants.

Some implementations may require additional functions, e.g. to handle interrupts.
