// const std = @import("std");
// const microbe = @import("microbe.zig");
// const chip = @import("chip");

// // Notes for users:
// //
// // If your chip supports interrupt or DMA-driven transfers, and your ComptimeConfig is configured
// // to utilize them, make sure you define the appropriate handlers in your root `interrupts` struct
// // and call the corresponding `handle*` function in the Uart struct.


// // Notes for chip implementers:
// //
// // chip.uart should be a namespace struct.  It has no required declarations, but may contain
// // the following to override the default versions defined here:
// //  - DataBits: enum
// //  - StopBits: enum
// //  - Parity: enum
// //  - ComptimeConfig: struct
// //  - Config: struct
// //
// // chip.Uart should be a type function, taking a comptime int (the UART number for chips with
// // more than one UART peripheral), and a ComptimeConfig struct.  It can optionally define
// // InitError, ReadError, and/or WriteError to override the default error sets for those
// // operations.  It has a number of required and optional public functions:
// //  - pub fn init(config: Config) InitError!Self
// //  - (optional) pub fn getOrInit(config: Config) InitError!Self
// //  - (optional) pub fn isRxIdle(self: Self) bool
// //  - (optional) pub fn isTxIdle(self: Self) bool
// //  - pub fn canRead(self: Self) bool  or  pub fn getRxBytesAvailable(self: Self) usize
// //  - pub fn canWrite(self: Self) bool  or  pub fn getTxBytesAvailable(self: Self) usize
// //  - (optional) pub fn peek(self: Self, out: []DataT) []const DataT
// //               (the returned buffer need not overlap `out`, if the driver already has
// //               `@min(out.len, getRxBytesAvailable())` bytes stored contiguously)
// //
// // Implementing the following two functions is recommended if the driver features a software
// // receive buffer that's filled using interrupt handlers or DMA transfers:
// //  - (optional) pub fn readBlocking(self: Self, buffer: []DataT) ReadError!usize
// //  - (optional) pub fn readNonBlocking(self: Self, buffer: []DataT) ReadErrorNonBlocking!usize
// //               (should return error.WouldBlock if at least one byte can't be read)
// //
// // If both readBlocking and readNonBlocking are defined, the following will never be used and are not required:
// //  - pub fn rx(self: Self) DataT  (blocks if there isn't a received byte available)
// //  - (optional) pub fn getReadError(self: Self) ?ReadError  and  pub fn clearReadError(self: Self, err: ReadError) void
// //               (getReadError should continue returning an error until clearReadError is called)
// //
// // Implementing the following two functions is recommended if the driver features a software
// // transmit buffer that's filled using interrupt handlers or DMA transfers:
// //  - (optional) pub fn writeBlocking(self: Self, buffer: []DataT) WriteError!usize
// //  - (optional) pub fn writeNonBlocking(self: Self, buffer: []DataT) WriteErrorNonBlocking!usize
// //               (should return error.WouldBlock if at least one byte can't be written)
// //
// // If both writeBlocking and writeNonBlocking are defined, the following will never be used and is not required:
// //  - pub fn tx(self: Self, byte: DataT) void  (blocks until the byte can be queued/written)
// //
// // Additional declarations can be injected into the user-facing Uart interface by defining
// // a struct named `ext` within the chip.Uart's returned type.  This can be used to add interrupt
// // interface points.

// pub fn Uart(comptime index: comptime_int, comptime cc: ComptimeConfig) type {
//     const SystemUart = chip.Uart(index, cc);
//     return struct {
//         const Self = @This();

//         const DataT = if (@hasDecl(SystemUart, "DataT")) SystemUart.DataT else u8;

//         internal: SystemUart,

//         /// Initializes the UART with the given config and returns a handle to the uart.
//         pub fn init(config: Config) InitError!Self {
//             micro.clock.ensure();
//             return Self{
//                 .internal = try SystemUart.init(config),
//             };
//         }

//         /// If the UART is already initialized, try to return a handle to it,
//         /// else initialize with the given config.
//         pub fn getOrInit(config: Config) InitError!Self {
//             if (!@hasDecl(SystemUart, "getOrInit")) {
//                 // fallback to reinitializing the UART
//                 return init(config);
//             }
//             return Self{
//                 .internal = try SystemUart.getOrInit(config),
//             };
//         }

//         /// Shut down UART, release GPIO reservations, etc.
//         pub fn deinit(self: Self) void {
//             if (@hasDecl(SystemUart, "deinit")) {
//                 self.internal.deinit();
//                 // fall back to reinitializing with both TX/RX disabled
//                 return init(.{
//                     .tx = NotUsed,
//                     .rx = NotUsed,
//                  });
//             } else {
//                 self.internal.deinit();
//             }
//         }

//         pub const InitError = if (@hasDecl(SystemUart, "InitError"))
//             SystemUart.InitError
//         else
//             error{
//                 UnsupportedWordSize,
//                 UnsupportedParity,
//                 UnsupportedStopBitCount,
//                 UnsupportedBaudRate,
//             }
//         ;

//         pub usingnamespace if (cc.rx != NotUsed) struct {
//             pub const ReadError = if (@hasDecl(SystemUart, "ReadError"))
//                 SystemUart.ReadError
//             else
//                 error{
//                     /// The input buffer received a byte while the receive FIFO is already full.
//                     /// Chips with no FIFO will overrun as soon as a second byte arrives.
//                     Overrun,
//                     /// A byte with an invalid parity bit was received.
//                     ParityError,
//                     /// The stop bit of our byte was not valid.
//                     FramingError,
//                     /// The break interrupt error will happen when RXD is logic zero for
//                     /// the duration of a full byte.
//                     BreakInterrupt,
//                 }
//             ;

//             pub const ReadErrorNonBlocking = ReadError || error{
//                 /// Returned from a non-blocking reader for operations that would normally block,
//                 /// due to the receive FIFO(s) being full.  Chips with no FIFO generally can only do
//                 /// single-byte reads from a non-blocking reader, and only when canRead() == true
//                 WouldBlock,
//             };

//             /// If supported by the chip, indicates if the receive line has been idle for at least one full byte
//             pub fn isRxIdle(self: Self) bool {
//                 if (@hasDecl(SystemUart, "isRxIdle")) {
//                     return self.internal.isRxIdle();
//                 } else {
//                     return true;
//                 }
//             }

//             pub fn getRxBytesAvailable(self: Self) usize {
//                 if (@hasDecl(SystemUart, "getRxBytesAvailable")) {
//                     return self.internal.getRxBytesAvailable();
//                 } else {
//                     return @boolToInt(self.internal.canRead());
//                 }
//             }

//             pub fn canRead(self: Self) bool {
//                 if (@hasDecl(SystemUart, "getRxBytesAvailable")) {
//                     return self.internal.getRxBytesAvailable() > 0;
//                 } else {
//                     return self.internal.canRead();
//                 }
//             }

//             pub fn reader(self: Self) Reader {
//                 return Reader{ .context = self };
//             }
//             pub fn readerNonBlocking(self: Self) ReaderNonBlocking {
//                 return ReaderNonBlocking{ .context = self };
//             }

//             pub const Reader = if (@hasDecl(SystemUart, "GenericReader"))
//                 SystemUart.GenericReader(DataT, Self, ReadError, readBlocking)
//             else if (DataT == u8)
//                 std.io.Reader(Self, ReadError, readBlocking)
//             else
//                 @compileError("Could not autodetect Reader type.  chip.Uart.GenericReader must be defined!");

//             fn readBlocking(self: Self, buffer: []DataT) ReadError!usize {
//                 if (@hasDecl(SystemUart, "readBlocking")) {
//                     return self.internal.readBlocking(buffer);
//                 } else {
//                     if (@hasDecl(SystemUart, "getReadError")) {
//                         // Note this should not return an error if there are buffered
//                         // bytes received before the error occurred.
//                         if (self.internal.getReadError()) |err| {
//                             self.internal.clearReadError(err);
//                             return err;
//                         }
//                     }
//                     for (buffer) |*c, i| {
//                         c.* = self.internal.rx();
//                         if (@hasDecl(SystemUart, "getReadError")) {
//                             if (self.internal.getReadError()) |_| return i+1;
//                         }
//                     }
//                     return buffer.len;
//                 }
//             }

//             pub const ReaderNonBlocking = if (@hasDecl(SystemUart, "GenericReader"))
//                 SystemUart.GenericReader(DataT, Self, ReadErrorNonBlocking, readNonBlocking)
//             else if (DataT == u8)
//                 std.io.Reader(Self, ReadErrorNonBlocking, readNonBlocking)
//             else
//                 @compileError("Could not autodetect Reader type.  chip.Uart.GenericReader must be defined!");

//             fn readNonBlocking(self: Self, buffer: []DataT) ReadErrorNonBlocking!usize {
//                 if (@hasDecl(SystemUart, "readNonBlocking")) {
//                     return self.internal.readNonBlocking(buffer);
//                 } else {
//                     if (@hasDecl(SystemUart, "getReadError")) {
//                         // Note this should not return an error if there are buffered
//                         // bytes received before the error occurred.
//                         if (self.internal.getReadError()) |err| {
//                             self.internal.clearReadError(err);
//                             return err;
//                         }
//                     }
//                     for (buffer) |*c, i| {
//                         if (self.canRead()) {
//                             c.* = self.internal.rx();
//                         } else if (i == 0) {
//                             return error.WouldBlock;
//                         } else {
//                             return i;
//                         }

//                         if (@hasDecl(SystemUart, "getReadError")) {
//                             if (self.internal.getReadError()) |_| return i+1;
//                         }
//                     }
//                     return buffer.len;
//                 }
//             }

//             pub usingnamespace if (@hasDecl(SystemUart, "peek")) struct {
//                 pub fn peek(self: Self, buffer: []DataT) []const DataT {
//                     return self.internal.peek(buffer);
//                 }
//             } else struct{};
//         } else struct{};

//         pub usingnamespace if (cc.tx != NotUsed) struct {
//             pub const WriteError = if (@hasDecl(SystemUart, "WriteError"))
//                 SystemUart.WriteError
//             else
//                 error{}
//             ;

//             pub const WriteErrorNonBlocking = WriteError || error{
//                 /// Returned from a non-blocking writer for operations that would normally block,
//                 /// due to the transmit FIFO(s) being full.  Chips with no FIFO generally can only do
//                 /// single-byte writes from a non-blocking writer, and only when canWrite() == true
//                 WouldBlock,
//             };

//             /// If supported by the chip, indicates that all written data has been sent over the wire
//             /// If you are going to shut down/reinitialize the UART, you may want to poll this to ensure
//             /// all written data has been flushed.
//             pub fn isTxIdle(self: Self) bool {
//                 if (@hasDecl(SystemUart, "isTxIdle")) {
//                     return self.internal.isTxIdle();
//                 } else {
//                     return true;
//                 }
//             }

//             pub fn getTxBytesAvailable(self: Self) usize {
//                 if (@hasDecl(SystemUart, "getTxBytesAvailable")) {
//                     return self.internal.getTxBytesAvailable();
//                 } else {
//                     return @boolToInt(self.internal.canWrite());
//                 }
//             }

//             pub fn canWrite(self: Self) bool {
//                 if (@hasDecl(SystemUart, "getTxBytesAvailable")) {
//                     return self.internal.getTxBytesAvailable() > 0;
//                 } else {
//                     return self.internal.canWrite();
//                 }
//             }

//             pub fn writer(self: Self) Writer {
//                 return Writer{ .context = self };
//             }
//             pub fn writerNonBlocking(self: Self) WriterNonBlocking {
//                 return WriterNonBlocking{ .context = self };
//             }

//             pub const Writer = if (@hasDecl(SystemUart, "GenericWriter"))
//                 SystemUart.GenericWriter(DataT, Self, WriteError, writeBlocking)
//             else if (DataT == u8)
//                 std.io.Reader(Self, WriteError, writeBlocking)
//             else
//                 @compileError("Could not autodetect Writer type.  chip.Uart.GenericReader must be defined!");


//             fn writeBlocking(self: Self, buffer: []const DataT) WriteError!usize {
//                 if (@hasDecl(SystemUart, "writeBlocking")) {
//                     return self.internal.writeBlocking(buffer);
//                 } else {
//                     for (buffer) |c| {
//                         self.internal.tx(c);
//                     }
//                     return buffer.len;
//                 }
//             }

//             pub const WriterNonBlocking = if (@hasDecl(SystemUart, "GenericWriter"))
//                 SystemUart.GenericWriter(DataT, Self, WriteErrorNonBlocking, writeNonBlocking)
//             else if (DataT == u8)
//                 std.io.Reader(Self, WriteErrorNonBlocking, writeNonBlocking)
//             else
//                 @compileError("Could not autodetect Writer type.  chip.Uart.GenericReader must be defined!");

//             fn writeNonBlocking(self: Self, buffer: []const DataT) WriteErrorNonBlocking!usize {
//                 if (@hasDecl(SystemUart, "writeNonBlocking")) {
//                     return self.internal.writeNonBlocking(buffer);
//                 } else {
//                     for (buffer) |c, i| {
//                         if (self.canWrite()) {
//                             self.internal.tx(c);
//                         } else if (i == 0) {
//                             return error.WouldBlock;
//                         } else {
//                             return i;
//                         }
//                     }
//                     return buffer.len;
//                 }
//             }
//         } else struct{};

//         pub usingnamespace if (@hasDecl(SystemUart, "ext")) SystemUart.ext else struct{};
//     };
// }

// // TODO: comptime verify that the enums are valid

// /// Comptime configuration of the UART.  This is generally used to optionally configure
// /// specific pins to be used with the chosen UART or enable advanced features like DMA
// /// transfers.
// ///
// /// Chip implementers note: Some suggested fields for common features:
// ///   cts: ?type, // The input pin to use for RTS/CTS bidirectional flow control.
// ///   rts: ?type, // The output pin to use for RTS/CTS bidirectional flow control.
// ///   tx_buffer_size: comptime_int, // The size of the internal software transmit FIFO buffer; set to 0 to disable interrupt/DMA driven I/O
// ///   rx_buffer_size: comptime_int, // The size of the internal software receive FIFO buffer; set to 0 to disable interrupt/DMA driven I/O
// ///   tx_dma_channel: ?enum, // If multiple DMA channels are available, select one to use for transmission.  Set to null to not use DMA for transmitted data.
// ///   rx_dma_channel: ?enum, // If multiple DMA channels are available, select one to use for reception.  Set to null to not use DMA for received data.
// pub const ComptimeConfig = if (@hasDecl(chip.uart, "ComptimeConfig"))
//     chip.uart.ComptimeConfig
// else
//     struct{
//         /// The pin to use for transmitting, if multiple options are available.
//         /// Set to null for default, or NotUsed to disable transmitting entirely.
//         tx: ?type = Default,
//         /// The pin to use for receiving, if multiple options are available.
//         /// Set to null for default, or NotUsed to disable receiving entirely.
//         rx: ?type = Default, 
//     }
// ;

// /// Set to a pin in ComptimeConfig to use the chip's default assignment.
// pub const Default: ?type = null;

// /// Assign this to tx or rx in ComptimeConfig to disable that direction, creating a unidirectional UART.
// /// May not be fully supported by all chips.
// /// Calling Uart(...).init(.{ .tx = NotUsed, .rx = NotUsed }) should deinitialize/shutdown the UART hardware,
// /// if supported by the chip.
// pub const NotUsed = opaque {};

// /// A UART configuration. The config defaults to the *8N1* setting, so "8 data bits, no parity, 1 stop bit" which is the
// /// most common serial format.
// pub const Config = if (@hasDecl(chip.uart, "Config"))
//     chip.uart.Config
// else
//     struct {
//         /// TODO: Make this optional, to support STM32F303 et al. auto baud-rate detection?
//         baud_rate: u32,
//         stop_bits: StopBits = .one,
//         parity: ?Parity = null,
//         data_bits: DataBits = .eight,
//     }
// ;

// pub const DataBits = if (@hasDecl(chip.uart, "DataBits"))
//     chip.uart.DataBits
// else
//     enum {
//         eight,
//     }
// ;

// pub const StopBits = if (@hasDecl(chip.uart, "StopBits"))
//     chip.uart.StopBits
// else
//     enum {
//         one,
//     }
// ;

// pub const Parity = if (@hasDecl(chip.uart, "Parity"))
//     chip.uart.Parity
// else
//     enum {
//         even,
//         odd,
//     }
// ;
