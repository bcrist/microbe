// const std = @import("std");
// const chip = @import("root").chip;

// pub const Config = chip.uart.Config;

// pub fn Uart(comptime config: Config) type {
//     const Impl = chip.uart.Impl(config);
//     if (@hasDecl(Impl, "GenericReader")) {
//         if (@hasDecl(Impl, "GenericWriter")) {
//             return struct {
//                 const Self = @This();
//                 const DataType = Impl.DataType;

//                 impl: Impl,

//                 /// Initializes the UART with the given config and returns a handle to the uart.
//                 pub fn init() Self {
//                     return Self{
//                         .impl = Impl.init(),
//                     };
//                 }

//                 /// Shut down UART, release GPIO reservations, etc.
//                 /// Take care not to use this while data is still being sent/received, or it
//                 /// will likely be lost.  Call stop() before deinit() to avoid this.
//                 pub fn deinit(self: *Self) void {
//                     self.impl.deinit();
//                 }

//                 /// Start the UART in order to allow transmission and/or reception of data.
//                 /// On some platforms (e.g. STM32), any additional custom configuration of
//                 /// the UART peripheral needs to be done before the UART is fully enabled,
//                 /// and so must happen before calling start().
//                 pub fn start(self: *Self) void {
//                     self.impl.start();
//                 }

//                 /// Stops reception of data immediately, and blocks until all buffered data
//                 /// has been transmitted fully.  If the UART is currently receiving a byte
//                 /// when stop() is called, it may or may not be read.
//                 /// The UART can be restarted again by calling start().
//                 pub fn stop(self: *Self) void {
//                     self.impl.stop();
//                 }

//                 pub const ReadError = Impl.ReadError;
//                 pub const ReadErrorNonBlocking = ReadError || error{
//                     /// Returned from a non-blocking reader for operations that would normally block,
//                     /// due to the receive FIFO(s) being full.  Chips with no FIFO generally can only do
//                     /// single-byte reads from a non-blocking reader, and only when canRead() == true
//                     WouldBlock,
//                 };

//                 pub fn isRxIdle(self: *Self) bool {
//                     return self.impl.isRxIdle();
//                 }

//                 pub fn getRxBytesAvailable(self: *Self) usize {
//                     if (@hasDecl(Impl, "getRxBytesAvailable")) {
//                         return self.impl.getRxBytesAvailable();
//                     } else {
//                         return @intFromBool(self.impl.canRead());
//                     }
//                 }

//                 pub fn canRead(self: *Self) bool {
//                     if (@hasDecl(Impl, "getRxBytesAvailable")) {
//                         return self.impl.getRxBytesAvailable() > 0;
//                     } else {
//                         return self.impl.canRead();
//                     }
//                 }

//                 pub usingnamespace if (@hasDecl(Impl, "peek")) struct {
//                     pub fn peek(self: *Self, buffer: []DataType) []const DataType {
//                         return self.impl.peek(buffer);
//                     }
//                 } else struct {};

//                 pub fn reader(self: *Self) Reader {
//                     return Reader{ .context = &self.impl };
//                 }
//                 pub const Reader = Impl.GenericReader(*Impl, ReadError, readBlocking);
//                 const readBlocking = computeReadBlocking(Impl);

//                 pub fn readerNonBlocking(self: *Self) ReaderNonBlocking {
//                     return ReaderNonBlocking{ .context = &self.impl };
//                 }
//                 pub const ReaderNonBlocking = Impl.GenericReader(*Impl, ReadErrorNonBlocking, readNonBlocking);
//                 const readNonBlocking = computeReadBlocking(Impl);

//                 pub const WriteError = Impl.WriteError;
//                 pub const WriteErrorNonBlocking = WriteError || error{
//                     /// Returned from a non-blocking writer for operations that would normally block,
//                     /// due to the transmit FIFO(s) being full.  Chips with no FIFO generally can only do
//                     /// single-byte writes from a non-blocking writer, and only when canWrite() == true
//                     WouldBlock,
//                 };

//                 pub fn isTxIdle(self: *Self) bool {
//                     return self.impl.isTxIdle();
//                 }

//                 pub fn getTxBytesAvailable(self: *Self) usize {
//                     if (@hasDecl(Impl, "getTxBytesAvailable")) {
//                         return self.impl.getTxBytesAvailable();
//                     } else {
//                         return @intFromBool(self.impl.canWrite());
//                     }
//                 }

//                 pub fn canWrite(self: *Self) bool {
//                     if (@hasDecl(Impl, "getTxBytesAvailable")) {
//                         return self.impl.getTxBytesAvailable() > 0;
//                     } else {
//                         return self.impl.canWrite();
//                     }
//                 }

//                 pub fn writer(self: *Self) Writer {
//                     return Writer{ .context = &self.impl };
//                 }
//                 pub const Writer = Impl.GenericWriter(*Impl, WriteError, writeBlocking);
//                 const writeBlocking = computeWriteBlocking(Impl);

//                 pub fn writerNonBlocking(self: *Self) WriterNonBlocking {
//                     return WriterNonBlocking{ .context = &self.impl };
//                 }
//                 pub const WriterNonBlocking = Impl.GenericWriter(*Impl, WriteErrorNonBlocking, writeNonBlocking);
//                 const writeNonBlocking = computeWriteNonBlocking(Impl);

//                 pub usingnamespace if (@hasDecl(Impl, "ext")) Impl.ext else struct {};
//             };
//         } else {
//             return struct {
//                 const Self = @This();
//                 const DataType = Impl.DataType;

//                 impl: Impl,

//                 /// Initializes the UART with the given config and returns a handle to the uart.
//                 pub fn init() Self {
//                     return Self{
//                         .impl = Impl.init(),
//                     };
//                 }

//                 /// Shut down UART, release GPIO reservations, etc.
//                 /// Take care not to use this while data is still being sent/received, or it
//                 /// will likely be lost.  Call stop() before deinit() to avoid this.
//                 pub fn deinit(self: *Self) void {
//                     self.impl.deinit();
//                 }

//                 /// Start the UART in order to allow transmission and/or reception of data.
//                 /// On some platforms (e.g. STM32), any additional custom configuration of
//                 /// the UART peripheral needs to be done before the UART is fully enabled,
//                 /// and so must happen before calling start().
//                 pub fn start(self: *Self) void {
//                     self.impl.start();
//                 }

//                 /// Stops reception of data immediately, and blocks until all buffered data
//                 /// has been transmitted fully.  If the UART is currently receiving a byte
//                 /// when stop() is called, it may or may not be read.
//                 /// The UART can be restarted again by calling start().
//                 pub fn stop(self: *Self) void {
//                     self.impl.stop();
//                 }

//                 pub const ReadError = Impl.ReadError;
//                 pub const ReadErrorNonBlocking = ReadError || error{
//                     /// Returned from a non-blocking reader for operations that would normally block,
//                     /// due to the receive FIFO(s) being full.  Chips with no FIFO generally can only do
//                     /// single-byte reads from a non-blocking reader, and only when canRead() == true
//                     WouldBlock,
//                 };

//                 pub fn isRxIdle(self: *Self) bool {
//                     return self.impl.isRxIdle();
//                 }

//                 pub fn getRxBytesAvailable(self: *Self) usize {
//                     if (@hasDecl(Impl, "getRxBytesAvailable")) {
//                         return self.impl.getRxBytesAvailable();
//                     } else {
//                         return @intFromBool(self.impl.canRead());
//                     }
//                 }

//                 pub fn canRead(self: *Self) bool {
//                     if (@hasDecl(Impl, "getRxBytesAvailable")) {
//                         return self.impl.getRxBytesAvailable() > 0;
//                     } else {
//                         return self.impl.canRead();
//                     }
//                 }

//                 pub usingnamespace if (@hasDecl(Impl, "peek")) struct {
//                     pub fn peek(self: *Self, buffer: []DataType) []const DataType {
//                         return self.impl.peek(buffer);
//                     }
//                 } else struct {};

//                 pub fn reader(self: *Self) Reader {
//                     return Reader{ .context = &self.impl };
//                 }
//                 pub const Reader = Impl.GenericReader(*Impl, ReadError, readBlocking);
//                 const readBlocking = computeReadBlocking(Impl);

//                 pub fn readerNonBlocking(self: *Self) ReaderNonBlocking {
//                     return ReaderNonBlocking{ .context = &self.impl };
//                 }
//                 pub const ReaderNonBlocking = Impl.GenericReader(*Impl, ReadErrorNonBlocking, readNonBlocking);
//                 const readNonBlocking = computeReadBlocking(Impl);

//                 pub usingnamespace if (@hasDecl(Impl, "ext")) Impl.ext else struct {};
//             };
//         }
//     } else if (@hasDecl(Impl, "GenericWriter")) {
//         return struct {
//             const Self = @This();
//             const DataType = Impl.DataType;

//             impl: Impl,


//             pub const WriteError = Impl.WriteError;
//             pub const WriteErrorNonBlocking = WriteError || error{
//                 /// Returned from a non-blocking writer for operations that would normally block,
//                 /// due to the transmit FIFO(s) being full.  Chips with no FIFO generally can only do
//                 /// single-byte writes from a non-blocking writer, and only when canWrite() == true
//                 WouldBlock,
//             };

//             pub fn isTxIdle(self: *Self) bool {
//                 return self.impl.isTxIdle();
//             }

//             pub fn getTxBytesAvailable(self: *Self) usize {
//                 if (@hasDecl(Impl, "getTxBytesAvailable")) {
//                     return self.impl.getTxBytesAvailable();
//                 } else {
//                     return @intFromBool(self.impl.canWrite());
//                 }
//             }

//             pub fn canWrite(self: *Self) bool {
//                 if (@hasDecl(Impl, "getTxBytesAvailable")) {
//                     return self.impl.getTxBytesAvailable() > 0;
//                 } else {
//                     return self.impl.canWrite();
//                 }
//             }

//             pub fn writer(self: *Self) Writer {
//                 return Writer{ .context = &self.impl };
//             }
//             pub const Writer = Impl.GenericWriter(*Impl, WriteError, writeBlocking);
//             const writeBlocking = computeWriteBlocking(Impl);

//             pub fn writerNonBlocking(self: *Self) WriterNonBlocking {
//                 return WriterNonBlocking{ .context = &self.impl };
//             }
//             pub const WriterNonBlocking = Impl.GenericWriter(*Impl, WriteErrorNonBlocking, writeNonBlocking);
//             const writeNonBlocking = computeWriteNonBlocking(Impl);

//             pub usingnamespace if (@hasDecl(Impl, "ext")) Impl.ext else struct {};
//         };
//     } else {
//         @compileError("UART with neither TX nor RX is useless");
//     }
// }

// fn computeReadBlocking(comptime Impl: type) fn (impl: *Impl, buffer: []Impl.DataType) Impl.ReadError!usize {
//     if (@hasDecl(Impl, "readBlocking")) {
//         return Impl.readBlocking;
//     } else return struct {
//         fn readBlocking(impl: *Impl, buffer: []Impl.DataType) Impl.ReadError!usize {
//             impl.getReadError() catch |err| {
//                 impl.clearReadError(err);
//                 return err;
//             };

//             for (buffer, 0..) |*c, i| {
//                 c.* = impl.rx() catch |err| {
//                     if (i == 0) {
//                         impl.clearReadError(err);
//                         return err;
//                     } else {
//                         return i;
//                     }
//                 };
//             }
//             return buffer.len;
//         }
//     }.readBlocking;
// }

// fn computeReadNonBlocking(comptime Impl: type) fn (impl: *Impl, buffer: []Impl.DataType) (Impl.ReadError || error.WouldBlock)!usize {
//     if (@hasDecl(Impl, "readNonBlocking")) {
//         return Impl.readNonBlocking;
//     } else return struct {
//         fn readNonBlocking(impl: *Impl, buffer: []Impl.DataType) (Impl.ReadError || error.WouldBlock)!usize {
//             // Note this should not return an error if there are buffered
//             // bytes received before the error occurred.
//             impl.getReadError() catch |err| {
//                 impl.clearReadError(err);
//                 return err;
//             };

//             for (buffer, 0..) |*c, i| {
//                 const can_read = blk: {
//                     if (@hasDecl(Impl, "getRxBytesAvailable")) {
//                         break :blk impl.getRxBytesAvailable() > 0;
//                     } else {
//                         break :blk impl.canRead();
//                     }
//                 };
//                 if (!can_read) {
//                     if (i == 0) {
//                         return error.WouldBlock;
//                     } else {
//                         return i;
//                     }
//                 }
//                 c.* = impl.rx() catch |err| {
//                     if (i == 0) {
//                         impl.clearReadError(err);
//                         return err;
//                     } else {
//                         return i;
//                     }
//                 };
//             }
//             return buffer.len;
//         }
//     }.readNonBlocking;
// }

// fn computeWriteBlocking(comptime Impl: type) fn (impl: *Impl, buffer: []const Impl.DataType) Impl.WriteError!usize {
//     if (@hasDecl(Impl, "writeBlocking")) {
//         return Impl.writeBlocking;
//     } else return struct {
//         fn writeBlocking(impl: *Impl, buffer: []const Impl.DataType) Impl.WriteError!usize {
//             for (buffer) |c| {
//                 impl.tx(c);
//             }
//             return buffer.len;
//         }
//     }.writeBlocking;
// }

// fn computeWriteNonBlocking(comptime Impl: type) fn (impl: *Impl, buffer: []const Impl.DataType) (Impl.WriteError || error.WouldBlock)!usize {
//     if (@hasDecl(Impl, "writeNonBlocking")) {
//         return Impl.writeNonBlocking;
//     } else return struct {
//         fn writeNonBlocking(impl: *Impl, buffer: []const Impl.DataType) (Impl.WriteError || error.WouldBlock)!usize {
//             for (buffer, 0..) |c, i| {
//                 const can_write = blk: {
//                     if (@hasDecl(Impl, "getTxBytesAvailable")) {
//                         break :blk impl.getTxBytesAvailable() > 0;
//                     } else {
//                         break :blk impl.canWrite();
//                     }
//                 };
//                 if (can_write) {
//                     impl.tx(c);
//                 } else if (i == 0) {
//                     return error.WouldBlock;
//                 } else {
//                     return i;
//                 }
//             }
//             return buffer.len;
//         }
//     }.writeNonBlocking;
// }
