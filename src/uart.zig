// Notes for users:
//
// If your chip supports interrupt or DMA-driven transfers, and your ComptimeConfig is configured
// to utilize them, make sure you define the appropriate handlers in your root `interrupts` struct
// and call the corresponding `handle*` function in the Uart struct.

// Implementation Notes:
//
// chip.uart should be a namespace struct.
//
// chip.uart.Config should be a struct containing comptime configuration options for the UART.
// The exact fields depend on the chip's implementation, but here are the preferred names/types
// for some common options:
//  - baud_rate: comptime_int,
//  - data_bits: enum, // generally .seven or .eight, sometimes maybe other values.  Should not include parity bit.
//  - parity: ?enum, // .even, or .odd, or null for no parity.
//  - stop_bits: enum, // usually .one or two, sometimes .one_and_half or .half
//  - which: ?enum, // If the chip has multiple UART peripherals, allows selection of which one to use.  If set to null, select automatically based on rx/tx pins specified.
//  - rx: ?PadID, // The input pin to use for receiving, or null to disable receiving.
//  - tx: ?PadID, // The output pin to use for transmitting, or null to disable transmitting.
//  - cts: ?PadID, // The input pin to use for RTS/CTS bidirectional flow control.
//  - rts: ?PadID, // The output pin to use for RTS/CTS bidirectional flow control.
//  - tx_buffer_size: comptime_int, // The size of the internal software transmit FIFO buffer; set to 0 to disable interrupt/DMA driven I/O
//  - rx_buffer_size: comptime_int, // The size of the internal software receive FIFO buffer; set to 0 to disable interrupt/DMA driven I/O
//  - tx_dma_channel: ?enum, // If multiple DMA channels are available, select one to use for transmission.  Set to null to not use DMA for transmitted data.
//  - rx_dma_channel: ?enum, // If multiple DMA channels are available, select one to use for reception.  Set to null to not use DMA for received data.
//
// chip.uart.Impl should be a type function, taking a Config struct and return a struct, containing at least:
//  - const DataType: type; (usually u8)
//  - fn init(config: Config) Impl
//  - fn deinit(self: *Impl) void
//  - fn start(self: *Impl) void
//  - fn stop(self: *Impl) void
//
// If an implementation is capabable of receiving data, it should define:
//  - const ReadError: errorset
//          Usually some set of:
//           - error.Overrun
//                   Indicates some received data was lost because older data was not read fast enough.
//           - error.ParityError
//                   Indicates potential data corruption due to parity mismatch.  The character received should
//                   be ignored.
//           - error.FramingError
//                   Indicates an incorrect line state during the stop bit, which may indicate data corruption,
//                   configuration mismatch, or severe clock drift.  The character received should be ignored.
//           - error.BreakInterrupt
//                   Indicates an entire frame of 0 bits was received, including stop bits, which may be used as a
//                   data separator in some protocols, or may indicate a broken cable or other physical issue.
//                   Some implementations may not be capable of differentiating a break character from a framing
//                   error.
//           - error.NoiseError
//                   Indicates that a signal transition was detected too close to the "center" of a bit period,
//                   which may indicate borderline baud rate mismatch or significant noise on the line.
//                   The received noisy character should still be readable after this error is seen.
//  - fn isRxIdle(self: *Impl) bool
//          Returns true if the receiver has seen a start bit, but has not yet finished reading that byte yet.
//  - fn GenericReader(comptime Context: type, comptime ReadError: type, comptime readFn: fn (context: Context, buffer: []DataType) ReadError!usize) type
//          When DataType is u8, this should usually be an alias for std.io.Reader.  Otherwise, the
//          implementation must supply a similar Reader type which works with the DataType.  The Context
//          type will always be *Impl.
//  - (optional) fn peek(self: *Impl, out: []DataType) []const DataType
//          Returns a buffer containing data available to be read, without marking it as read.  The returned
//          buffer need not overlap `out`, if the implementation already has `@min(out.len, getRxBytesAvailable())`
//          bytes stored contiguously.  In this case, the returned slice should remain valid until the next time
//          data is read.
//
// Implementations may choose to implement one of two interfaces for reading data.
//
// Implementations that use a software receive buffer (and usually interrupts or DMA to fill that buffer)
// should prefer the first:
//  - fn getRxBytesAvailable(self: *Impl) usize
//          Returns the number of bytes or errors that can be read without blocking.
//  - fn readBlocking(self: *Impl, buffer: []DataType) ReadError!usize
//          A read function suitable for use with GenericReader.  It should block until at least one
//          byte has been read, and may block until the buffer is full, an error is detected, or the
//          line goes idle, whichever comes first.  If an error is detected, but at least one byte has
//          already been read, the error should not be reported until the next call to readBlocking().
//  - fn readNonBlocking(self: *Impl, buffer: []DataType) ReadErrorNonBlocking!usize
//          A read function suitable for use with GenericReader.  If there is no data ready to be read,
//          error.WouldBlock should be returned.  Otherwise, as much available data as can fit should
//          be copied to the buffer.
//
// Implementations that are only capable of reading one byte at a time may instead use a simplified interface:
//  - fn canRead(self: *Impl) bool
//          Indicates if a call to rx() will return a byte or error immediately.
//  - fn rx(self: *Impl) ReadError!DataType
//          Returns the next byte of received data, or an error.  Blocks until there is data available,
//          if necessary.
//  - fn getReadError(self: *Impl) ReadError!void
//          Checks if there is currently an error condition without reading data.  Any time rx() would return
//          an error, getReadError() should as well, and vice-versa.  If there are multiple bytes available,
//          (e.g. in a hardware FIFO), best effort should be made not to report errors until all data received
//          before the error has been read.
//  - fn clearReadError(self: *Impl, err: ReadError) void
//          Errors reported by rx() or getReadError() should always be persistent; i.e. calling either function
//          again should return the same error, until clearReadError() is called to acknowledge the error.
//
// If an implementation is capabable of transmitting data, it should define:
//  - const WriteError: errorset
//          Usually this is an empty errorset, but implementations may choose to add errors.
//  - fn isTxIdle(self: *Impl) bool
//          Returns true if the implementation has buffered data that hasn't been sent yet, or if there is
//          data currently being sent out, where the stop bit(s) haven't yet been sent out.
//  - fn GenericWriter(comptime Context: type, comptime WriteError: type, comptime writeFn: fn (context: Context, buffer: []const DataType) WriteError!usize) type
//          When DataType is u8, this should usually be an alias for std.io.Writer.  Otherwise, the
//          implementation must supply a similar Writer type which works with the DataType.  The Context
//          type will always be *Impl.
//
// Implementations may choose to implement one of two interfaces for writing data.
//
// Implementations that use a software transmit buffer (and usually interrupts or DMA to drain that buffer)
// should prefer the first:
//  - fn getTxBytesAvailable(self: *Impl) usize
//          Returns the number of bytes that can be written without blocking.
//  - fn writeBlocking(self: *Impl, buffer: []DataType) WriteError!usize
//          A write function suitable for use with GenericWriter.  If there is insufficient
//          space to hold all the data in the transmit buffer, it should block until enough
//          data has been transmitted to make room.  Note if CTS is in use, this means it
//          may block indefinitely.  If an error occurs, after at least one byte has been
//          written, it should not be returned until writeBlocking is called again.
//  - fn writeNonBlocking(self: *Impl, buffer: []DataType) WriteErrorNonBlocking!usize
//          A write function suitable for for use with GenericWriter.  If there is
//          insufficient space to hold all data in the buffer, write as much as possible.
//          If there is no space at all, return error.WouldBlock instead of 0.
//
// Implementations where WriteError is empty and that are only capable of writing one byte at a time may
// instead use a simplified interface:
//  - fn canWrite(self: *Impl) bool
//          Indicates if a call to tx() will return a byte or error immediately.
//  - fn tx(self: *Impl, byte: DataType) void
//          Transmits or queues a single byte to be written.  Blocks until at least one byte can be written.
//
// Additional declarations can be injected into the user-facing Uart interface by defining
// a struct named `ext` within the Impl type.  This can be used to add interrupt/DMA interface points.

const std = @import("std");
const chip = @import("root").chip;

pub const Config = chip.uart.Config;

pub fn Uart(comptime config: Config) type {
    const Impl = chip.uart.Impl(config);
    if (@hasDecl(Impl, "GenericReader")) {
        if (@hasDecl(Impl, "GenericWriter")) {
            return struct {
                const Self = @This();
                const DataType = Impl.DataType;

                impl: Impl,

                /// Initializes the UART with the given config and returns a handle to the uart.
                pub fn init() Self {
                    return Self{
                        .impl = Impl.init(),
                    };
                }

                /// Shut down UART, release GPIO reservations, etc.
                /// Take care not to use this while data is still being sent/received, or it
                /// will likely be lost.  Call stop() before deinit() to avoid this.
                pub fn deinit(self: *Self) void {
                    self.impl.deinit();
                }

                /// Start the UART in order to allow transmission and/or reception of data.
                /// On some platforms (e.g. STM32), any additional custom configuration of
                /// the UART peripheral needs to be done before the UART is fully enabled,
                /// and so must happen before calling start().
                pub fn start(self: *Self) void {
                    self.impl.start();
                }

                /// Stops reception of data immediately, and blocks until all buffered data
                /// has been transmitted fully.  If the UART is currently receiving a byte
                /// when stop() is called, it may or may not be read.
                /// The UART can be restarted again by calling start().
                pub fn stop(self: *Self) void {
                    self.impl.stop();
                }

                pub const ReadError = Impl.ReadError;
                pub const ReadErrorNonBlocking = ReadError || error{
                    /// Returned from a non-blocking reader for operations that would normally block,
                    /// due to the receive FIFO(s) being full.  Chips with no FIFO generally can only do
                    /// single-byte reads from a non-blocking reader, and only when canRead() == true
                    WouldBlock,
                };

                pub fn isRxIdle(self: *Self) bool {
                    return self.impl.isRxIdle();
                }

                pub fn getRxBytesAvailable(self: *Self) usize {
                    if (@hasDecl(Impl, "getRxBytesAvailable")) {
                        return self.impl.getRxBytesAvailable();
                    } else {
                        return @intFromBool(self.impl.canRead());
                    }
                }

                pub fn canRead(self: *Self) bool {
                    if (@hasDecl(Impl, "getRxBytesAvailable")) {
                        return self.impl.getRxBytesAvailable() > 0;
                    } else {
                        return self.impl.canRead();
                    }
                }

                pub usingnamespace if (@hasDecl(Impl, "peek")) struct {
                    pub fn peek(self: *Self, buffer: []DataType) []const DataType {
                        return self.impl.peek(buffer);
                    }
                } else struct {};

                pub fn reader(self: *Self) Reader {
                    return Reader{ .context = &self.impl };
                }
                pub const Reader = Impl.GenericReader(*Impl, ReadError, readBlocking);
                const readBlocking = computeReadBlocking(Impl);

                pub fn readerNonBlocking(self: *Self) ReaderNonBlocking {
                    return ReaderNonBlocking{ .context = &self.impl };
                }
                pub const ReaderNonBlocking = Impl.GenericReader(*Impl, ReadErrorNonBlocking, readNonBlocking);
                const readNonBlocking = computeReadBlocking(Impl);

                pub const WriteError = Impl.WriteError;
                pub const WriteErrorNonBlocking = WriteError || error{
                    /// Returned from a non-blocking writer for operations that would normally block,
                    /// due to the transmit FIFO(s) being full.  Chips with no FIFO generally can only do
                    /// single-byte writes from a non-blocking writer, and only when canWrite() == true
                    WouldBlock,
                };

                pub fn isTxIdle(self: *Self) bool {
                    return self.impl.isTxIdle();
                }

                pub fn getTxBytesAvailable(self: *Self) usize {
                    if (@hasDecl(Impl, "getTxBytesAvailable")) {
                        return self.impl.getTxBytesAvailable();
                    } else {
                        return @intFromBool(self.impl.canWrite());
                    }
                }

                pub fn canWrite(self: *Self) bool {
                    if (@hasDecl(Impl, "getTxBytesAvailable")) {
                        return self.impl.getTxBytesAvailable() > 0;
                    } else {
                        return self.impl.canWrite();
                    }
                }

                pub fn writer(self: *Self) Writer {
                    return Writer{ .context = &self.impl };
                }
                pub const Writer = Impl.GenericWriter(*Impl, WriteError, writeBlocking);
                const writeBlocking = computeWriteBlocking(Impl);

                pub fn writerNonBlocking(self: *Self) WriterNonBlocking {
                    return WriterNonBlocking{ .context = &self.impl };
                }
                pub const WriterNonBlocking = Impl.GenericWriter(*Impl, WriteErrorNonBlocking, writeNonBlocking);
                const writeNonBlocking = computeWriteNonBlocking(Impl);

                pub usingnamespace if (@hasDecl(Impl, "ext")) Impl.ext else struct {};
            };
        } else {
            return struct {
                const Self = @This();
                const DataType = Impl.DataType;

                impl: Impl,

                /// Initializes the UART with the given config and returns a handle to the uart.
                pub fn init() Self {
                    return Self{
                        .impl = Impl.init(),
                    };
                }

                /// Shut down UART, release GPIO reservations, etc.
                /// Take care not to use this while data is still being sent/received, or it
                /// will likely be lost.  Call stop() before deinit() to avoid this.
                pub fn deinit(self: *Self) void {
                    self.impl.deinit();
                }

                /// Start the UART in order to allow transmission and/or reception of data.
                /// On some platforms (e.g. STM32), any additional custom configuration of
                /// the UART peripheral needs to be done before the UART is fully enabled,
                /// and so must happen before calling start().
                pub fn start(self: *Self) void {
                    self.impl.start();
                }

                /// Stops reception of data immediately, and blocks until all buffered data
                /// has been transmitted fully.  If the UART is currently receiving a byte
                /// when stop() is called, it may or may not be read.
                /// The UART can be restarted again by calling start().
                pub fn stop(self: *Self) void {
                    self.impl.stop();
                }

                pub const ReadError = Impl.ReadError;
                pub const ReadErrorNonBlocking = ReadError || error{
                    /// Returned from a non-blocking reader for operations that would normally block,
                    /// due to the receive FIFO(s) being full.  Chips with no FIFO generally can only do
                    /// single-byte reads from a non-blocking reader, and only when canRead() == true
                    WouldBlock,
                };

                pub fn isRxIdle(self: *Self) bool {
                    return self.impl.isRxIdle();
                }

                pub fn getRxBytesAvailable(self: *Self) usize {
                    if (@hasDecl(Impl, "getRxBytesAvailable")) {
                        return self.impl.getRxBytesAvailable();
                    } else {
                        return @intFromBool(self.impl.canRead());
                    }
                }

                pub fn canRead(self: *Self) bool {
                    if (@hasDecl(Impl, "getRxBytesAvailable")) {
                        return self.impl.getRxBytesAvailable() > 0;
                    } else {
                        return self.impl.canRead();
                    }
                }

                pub usingnamespace if (@hasDecl(Impl, "peek")) struct {
                    pub fn peek(self: *Self, buffer: []DataType) []const DataType {
                        return self.impl.peek(buffer);
                    }
                } else struct {};

                pub fn reader(self: *Self) Reader {
                    return Reader{ .context = &self.impl };
                }
                pub const Reader = Impl.GenericReader(*Impl, ReadError, readBlocking);
                const readBlocking = computeReadBlocking(Impl);

                pub fn readerNonBlocking(self: *Self) ReaderNonBlocking {
                    return ReaderNonBlocking{ .context = &self.impl };
                }
                pub const ReaderNonBlocking = Impl.GenericReader(*Impl, ReadErrorNonBlocking, readNonBlocking);
                const readNonBlocking = computeReadBlocking(Impl);

                pub usingnamespace if (@hasDecl(Impl, "ext")) Impl.ext else struct {};
            };
        }
    } else if (@hasDecl(Impl, "GenericWriter")) {
        return struct {
            const Self = @This();
            const DataType = Impl.DataType;

            impl: Impl,

            /// Initializes the UART with the given config and returns a handle to the uart.
            pub fn init() Self {
                return Self{
                    .impl = Impl.init(),
                };
            }

            /// Shut down UART, release GPIO reservations, etc.
            /// Take care not to use this while data is still being sent/received, or it
            /// will likely be lost.  Call stop() before deinit() to avoid this.
            pub fn deinit(self: *Self) void {
                self.impl.deinit();
            }

            /// Start the UART in order to allow transmission and/or reception of data.
            /// On some platforms (e.g. STM32), any additional custom configuration of
            /// the UART peripheral needs to be done before the UART is fully enabled,
            /// and so must happen before calling start().
            pub fn start(self: *Self) void {
                self.impl.start();
            }

            /// Stops reception of data immediately, and blocks until all buffered data
            /// has been transmitted fully.  If the UART is currently receiving a byte
            /// when stop() is called, it may or may not be read.
            /// The UART can be restarted again by calling start().
            pub fn stop(self: *Self) void {
                self.impl.stop();
            }

            pub const WriteError = Impl.WriteError;
            pub const WriteErrorNonBlocking = WriteError || error{
                /// Returned from a non-blocking writer for operations that would normally block,
                /// due to the transmit FIFO(s) being full.  Chips with no FIFO generally can only do
                /// single-byte writes from a non-blocking writer, and only when canWrite() == true
                WouldBlock,
            };

            pub fn isTxIdle(self: *Self) bool {
                return self.impl.isTxIdle();
            }

            pub fn getTxBytesAvailable(self: *Self) usize {
                if (@hasDecl(Impl, "getTxBytesAvailable")) {
                    return self.impl.getTxBytesAvailable();
                } else {
                    return @intFromBool(self.impl.canWrite());
                }
            }

            pub fn canWrite(self: *Self) bool {
                if (@hasDecl(Impl, "getTxBytesAvailable")) {
                    return self.impl.getTxBytesAvailable() > 0;
                } else {
                    return self.impl.canWrite();
                }
            }

            pub fn writer(self: *Self) Writer {
                return Writer{ .context = &self.impl };
            }
            pub const Writer = Impl.GenericWriter(*Impl, WriteError, writeBlocking);
            const writeBlocking = computeWriteBlocking(Impl);

            pub fn writerNonBlocking(self: *Self) WriterNonBlocking {
                return WriterNonBlocking{ .context = &self.impl };
            }
            pub const WriterNonBlocking = Impl.GenericWriter(*Impl, WriteErrorNonBlocking, writeNonBlocking);
            const writeNonBlocking = computeWriteNonBlocking(Impl);

            pub usingnamespace if (@hasDecl(Impl, "ext")) Impl.ext else struct {};
        };
    } else {
        @compileError("UART with neither TX nor RX is useless");
    }
}

fn computeReadBlocking(comptime Impl: type) fn (impl: *Impl, buffer: []Impl.DataType) Impl.ReadError!usize {
    if (@hasDecl(Impl, "readBlocking")) {
        return Impl.readBlocking;
    } else return struct {
        fn readBlocking(impl: *Impl, buffer: []Impl.DataType) Impl.ReadError!usize {
            impl.getReadError() catch |err| {
                impl.clearReadError(err);
                return err;
            };

            for (buffer, 0..) |*c, i| {
                c.* = impl.rx() catch |err| {
                    if (i == 0) {
                        impl.clearReadError(err);
                        return err;
                    } else {
                        return i;
                    }
                };
            }
            return buffer.len;
        }
    }.readBlocking;
}

fn computeReadNonBlocking(comptime Impl: type) fn (impl: *Impl, buffer: []Impl.DataType) (Impl.ReadError || error.WouldBlock)!usize {
    if (@hasDecl(Impl, "readNonBlocking")) {
        return Impl.readNonBlocking;
    } else return struct {
        fn readNonBlocking(impl: *Impl, buffer: []Impl.DataType) (Impl.ReadError || error.WouldBlock)!usize {
            // Note this should not return an error if there are buffered
            // bytes received before the error occurred.
            impl.getReadError() catch |err| {
                impl.clearReadError(err);
                return err;
            };

            for (buffer, 0..) |*c, i| {
                const can_read = blk: {
                    if (@hasDecl(Impl, "getRxBytesAvailable")) {
                        break :blk impl.getRxBytesAvailable() > 0;
                    } else {
                        break :blk impl.canRead();
                    }
                };
                if (!can_read) {
                    if (i == 0) {
                        return error.WouldBlock;
                    } else {
                        return i;
                    }
                }
                c.* = impl.rx() catch |err| {
                    if (i == 0) {
                        impl.clearReadError(err);
                        return err;
                    } else {
                        return i;
                    }
                };
            }
            return buffer.len;
        }
    }.readNonBlocking;
}

fn computeWriteBlocking(comptime Impl: type) fn (impl: *Impl, buffer: []const Impl.DataType) Impl.WriteError!usize {
    if (@hasDecl(Impl, "writeBlocking")) {
        return Impl.writeBlocking;
    } else return struct {
        fn writeBlocking(impl: *Impl, buffer: []const Impl.DataType) Impl.WriteError!usize {
            for (buffer) |c| {
                impl.tx(c);
            }
            return buffer.len;
        }
    }.writeBlocking;
}

fn computeWriteNonBlocking(comptime Impl: type) fn (impl: *Impl, buffer: []const Impl.DataType) (Impl.WriteError || error.WouldBlock)!usize {
    if (@hasDecl(Impl, "writeNonBlocking")) {
        return Impl.writeNonBlocking;
    } else return struct {
        fn writeNonBlocking(impl: *Impl, buffer: []const Impl.DataType) (Impl.WriteError || error.WouldBlock)!usize {
            for (buffer, 0..) |c, i| {
                const can_write = blk: {
                    if (@hasDecl(Impl, "getTxBytesAvailable")) {
                        break :blk impl.getTxBytesAvailable() > 0;
                    } else {
                        break :blk impl.canWrite();
                    }
                };
                if (can_write) {
                    impl.tx(c);
                } else if (i == 0) {
                    return error.WouldBlock;
                } else {
                    return i;
                }
            }
            return buffer.len;
        }
    }.writeNonBlocking;
}
