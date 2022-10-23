const std = @import("std");
const micro = @import("microzig");
const chip = @import("chip");

// chip.uart should be a namespace struct.  It has no required declarations, but may contain
// the following to override the default versions defined here:
//  - DataBits: enum
//  - StopBits: enum
//  - Parity: enum
//  - ComptimeConfig: struct
//  - Config: struct
//
// chip.Uart should be a type function, taking a comptime int (the UART number for chips with
// more than one UART peripheral), and a ComptimeConfig struct.  It can optionally define
// InitError, ReadError, and/or WriteError to override the default error sets for those
// operations.  It has a number of required and optional public functions:
//  - pub fn init(config: Config) InitError!Self
//  - (optional) pub fn getOrInit(config: Config) InitError!Self
//  - (optional) pub fn isRxIdle(self: Self) bool
//  - (optional) pub fn isTxIdle(self: Self) bool
//  - pub fn canRead(self: Self) bool  or  pub fn getRxBytesAvailable(self: Self) usize
//  - pub fn canWrite(self: Self) bool  or  pub fn getTxBytesAvailable(self: Self) usize
//  - (optional) pub fn peek(self: Self, out: []u8) []const u8
//               (the returned buffer need not overlap `out`, if the driver already has
//               `@min(out.len, getRxBytesAvailable())` bytes stored contiguously)
//
// Implementing the following two functions is recommended if the driver features a software
// receive buffer that's filled using interrupt handlers or DMA transfers:
//  - (optional) pub fn readBlocking(self: Self, buffer: []u8) ReadError!usize
//  - (optional) pub fn readNonBlocking(self: Self, buffer: []u8) ReadErrorNonBlocking!usize
//               (should return error.WouldBlock if at least one byte can't be read)
//
// If both readBlocking and readNonBlocking are defined, the following will never be used and are not required:
//  - pub fn rx(self: Self) u8  (blocks if there isn't a received byte available)
//  - (optional) pub fn getReadError(self: Self) ?ReadError  and  pub fn clearReadError(self: Self, err: ReadError) void
//               (getReadError should continue returning an error until clearReadError is called)
//
// Implementing the following two functions is recommended if the driver features a software
// transmit buffer that's filled using interrupt handlers or DMA transfers:
//  - (optional) pub fn writeBlocking(self: Self, buffer: []u8) WriteError!usize
//  - (optional) pub fn writeNonBlocking(self: Self, buffer: []u8) WriteErrorNonBlocking!usize
//               (should return error.WouldBlock if at least one byte can't be written)
//
// If both writeBlocking and writeNonBlocking are defined, the following will never be used and is not required:
//  - pub fn tx(self: Self, byte: u8) void  (blocks until the byte can be queued/written)
//
// Additional declarations can be injected into the user-facing Uart interface by defining
// a struct named `ext` within the chip.Uart's returned type.  This can be used to add interrupt
// interface points.


const DataBits = enum {
    seven,
    eight,
    // hardware supports 9 data bits, but we don't, so that we don't need custom Reader/Writer implementations using u9 instead of u8
};

const StopBits = enum(u2) {
    one = 0,
    half = 1,
    two = 2,
    one_and_half = 3
};

const ComptimeConfig = struct {
    tx: ?type = micro.uart.Default,
    rx: ?type = micro.uart.Default,
    cts: ?type = micro.uart.NotUsed,
    rts: ?type = micro.uart.NotUsed,
    de: ?type = micro.uart.NotUsed,
    tx_buffer_size: comptime_int = 256,
    rx_buffer_size: comptime_int = 0,
};

//  - ComptimeConfig: struct
//  - Config: struct