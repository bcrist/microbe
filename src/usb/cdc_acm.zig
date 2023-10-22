/// Note this file is focused on basic CDC ACM interfaces for UART emulation.
/// It will not help much with creating a CDC networking device.
///
/// Standard CDC-ACM headers:
///
/// InterfaceAssociation: class.control_interface, 2 interfaces
/// Interface: class.control_interface, 1 endpoint
/// HeaderDescriptor
/// CallManagementDescriptor
/// AbstractControlManagementDescriptor
/// UnionDescriptor
/// Endpoint: control endpoint, in, interrupt, 10-16ms polling
/// Interface: class.data_interface, 2 endpoints
/// Endpoint: data endpoint, in, bulk
/// Endpoint: data endpoint, out, bulk

const std = @import("std");
const usb = @import("microbe").usb;
const descriptor = @import("descriptor.zig");
const classes = @import("classes.zig");
const Class = classes.Class;
const Subclass = classes.Subclass;
const Protocol = classes.Protocol;

pub const class = struct {
    pub const control_interface: classes.Info = .{
        .class = Class.cdc,
        .subclass = @enumFromInt(2), // abstract control model
        .protocol = @enumFromInt(1), // AT commands (V.250)
    };
    pub const data_interface: classes.Info = .{
        .class = Class.cdc_data,
        .subclass = .zero,
        .protocol = .zero,
    };
};

pub const HeaderDescriptor = packed struct (u40) {
    _len: u8 = @bitSizeOf(@This()) / 8,
    _kind: descriptor.Kind = interface_descriptor,
    _subkind: DescriptorSubkind = .header,
    cdc_version: descriptor.Version = .{ .major = 1, .minor = 2 },
};

pub const CallManagementDescriptor = packed struct (u40) {
    _len: u8 = @bitSizeOf(@This()) / 8,
    _kind: descriptor.Kind = interface_descriptor,
    _subkind: DescriptorSubkind = .call_management,
    device_handles_call_management: bool = false,
    can_transfer_call_management_over_data_interface: bool = true,
    _reserved: u6 = 0,
    data_interface_index: u8, // zero-based index of the data interface within this configuration
};

pub const AbstractControlManagementDescriptor = packed struct (u32) {
    _len: u8 = @bitSizeOf(@This()) / 8,
    _kind: descriptor.Kind = interface_descriptor,
    _subkind: DescriptorSubkind = .abstract_control_management,
    supports_feature_requests: bool = false,
    supports_line_requests: bool = true,
    supports_send_break_request: bool = false,
    supports_network_connection_notification: bool = false,
    _reserved: u4 = 0,
};

pub const UnionDescriptor = packed struct (u40) {
    _len: u8 = @bitSizeOf(@This()) / 8,
    _kind: descriptor.Kind = interface_descriptor,
    _subkind: DescriptorSubkind = .@"union",
    control_interface_index: u8, // zero-based index of the control interface within this configuration
    data_interface_index: u8, // zero-based index of the data interface within this configuration
};

const interface_descriptor: descriptor.Kind = @enumFromInt(0x24);

pub const DescriptorSubkind = enum (u8) {
    header = 0,
    call_management = 1,
    abstract_control_management = 2,
    @"union" = 6,
};

pub const LineCoding = packed struct (u56) {
    baud_rate: u32,
    stop_bits: enum (u8) {
        one = 0,
        one_and_half = 1,
        two = 2,
    },
    parity: enum (u8) {
        none = 0,
        odd = 1,
        even = 2,
        mark = 3,
        space = 4,
    },
    data_bits: enum (u8) {
        five = 5,
        six = 6,
        seven = 7,
        eight = 8,
        sixteen = 16,
    },
};

pub const ControlLineState = packed struct (u16) {
    dtr: bool,
    rts: bool,
    _reserved: u14 = 0,
};

pub const SerialState = packed struct (u16) {
    dcd: bool = false,
    dsr: bool = false,
    break_detected: bool = false,
    ri: bool = false,
    framing_error: bool = false,
    parity_error: bool = false,
    overrun: bool = false,
    _reserved: u9 = 0,
};

pub const requests = struct {
    pub const send_encapsulated_command = request(0); // required
    pub const get_encapsulated_response = request(1); // required
    pub const set_comm_feature = request(2);
    pub const get_comm_feature = request(3);
    pub const clear_comm_feature = request(4);
    pub const set_line_coding = request(0x20);
    pub const get_line_coding = request(0x21);
    pub const set_control_line_state = request(0x22);
    pub const send_break = request(0x23);

    fn request(comptime num: comptime_int) usb.SetupRequestKind {
        return @enumFromInt(num);
    }
};

pub const notifications = struct {
    // These are sent on the communications interface's in endpoint

    pub fn networkConnection(interface_index: u8, connected: bool) usb.SetupPacket {
        var payload: u32 = interface_index;
        payload <<= 16;
        payload |= @intFromBool(connected);
        return .{
            .target = .interface,
            .kind = .class,
            .direction = .in,
            .request = @enumFromInt(0),
            .payload = payload,
            .data_len = 0,
        };
    }
    pub fn responseAvailable(interface_index: u8) usb.SetupPacket {
        var payload: u32 = interface_index;
        payload <<= 16;
        return .{
            .target = .interface,
            .kind = .class,
            .direction = .in,
            .request = @enumFromInt(1),
            .payload = payload,
            .data_len = 0,
        };
    }

    pub fn serialState(interface_index: u8, state: SerialState) SerialStateNotification {
        var payload: u32 = interface_index;
        payload <<= 16;
        return .{
            .setup = .{
                .target = .interface,
                .kind = .class,
                .direction = .in,
                .request = @enumFromInt(0x20),
                .payload = payload,
                .data_len = 2,
            },
            .state = state,
        };
    }
    pub const SerialStateNotification = packed struct (u80) {
        setup: usb.SetupPacket,
        state: SerialState,
    };

};

pub const UartConfig = struct {
    communications_interface_index: u8,
    rx_packet_size: comptime_int,
    tx_buffer_size: comptime_int = 256,
    rx_buffer_size: comptime_int = 128,
};
pub fn Uart(comptime UsbConfigType: type, comptime config: UartConfig) type {
    if (!std.math.isPowerOfTwo(config.tx_buffer_size)) {
        @compileError("UART Tx buffer size must be a power of two!");
    }
    if (!std.math.isPowerOfTwo(config.rx_buffer_size)) {
        @compileError("UART Rx buffer size must be a power of two!");
    }

    const log = std.log.scoped(.usb);

    const TxFifo = std.fifo.LinearFifo(u8, .{ .Static = config.tx_buffer_size });
    const RxFifo = std.fifo.LinearFifo(u8, .{ .Static = config.rx_buffer_size });

    const Errors = struct {
        const Read            = error {};
        const ReadNonBlocking = error { WouldBlock };

        const Write            = error {};
        const WriteNonBlocking = error { WouldBlock };
    };

    return struct {

        const Self = @This();
        pub const DataType = u8;

        pub const ReadError = Errors.Read;
        pub const Reader = std.io.Reader(*Self, ReadError, Self.readBlocking);

        pub const ReadErrorNonBlocking = Errors.ReadNonBlocking;
        pub const ReaderNonBlocking = std.io.Reader(*Self, ReadErrorNonBlocking, Self.readNonBlocking);

        pub const WriteError = Errors.Write;
        pub const Writer = std.io.Writer(*Self, WriteError, Self.writeBlocking);

        pub const WriteErrorNonBlocking = Errors.WriteNonBlocking;
        pub const WriterNonBlocking = std.io.Writer(*Self, WriteErrorNonBlocking, Self.writeNonBlocking);

        usb: *usb.Usb(UsbConfigType),
        tx: TxFifo,
        rx: RxFifo,
        received_encapsulated_command: bool,
        dtr: bool,
        rts: bool,
        line_coding: LineCoding,

        pub fn init(usb_ptr: *usb.Usb(UsbConfigType)) Self {
            return .{
                .usb = usb_ptr,
                .tx = TxFifo.init(),
                .rx = RxFifo.init(),
                .received_encapsulated_command = false,
                .dtr = false,
                .rts = false,
                .line_coding = .{
                    .baud_rate = 0,
                    .stop_bits = .one,
                    .parity = .none,
                    .data_bits = .eight,
                },
            };
        }

        pub fn start(_: Self) void {}
        pub fn stop(_: Self) void {}

        pub fn deinit(self: *Self) void {
            self.tx.deinit();
            self.rx.deinit();
        }

        pub fn isRxFull(self: *Self) bool {
            return self.rx.writableLength() < config.rx_packet_size;
        }

        pub fn getRxAvailableCount(self: *Self) usize {
            return self.rx.readableLength();
        }

        pub fn canRead(self: *Self) bool {
            return self.rx.readableLength() > 0;
        }

        pub fn peek(self: *Self, buffer: []DataType) []const DataType {
            if (buffer.len == 0) return buffer[0..0];
            var bytes = self.rx.readableSlice(0);
            if (bytes.len > buffer.len) {
                bytes = bytes[0..buffer.len];
            }
            @memcpy(buffer.ptr, bytes);
            return buffer[0..bytes.len];
        }

        pub fn peekOne(self: *Self) ?DataType {
            if (self.rx.count > 0) self.rx.peekItem(0) else null;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn readerNonBlocking(self: *Self) ReaderNonBlocking {
            return .{ .context = self };
        }

        pub fn isTxIdle(self: *Self) bool {
            return self.tx.readableLength() == 0;
        }

        pub fn getTxAvailableCount(self: *Self) usize {
            return self.tx.writableLength();
        }

        pub fn canWrite(self: *Self) bool {
            return self.tx.writableLength() > 0;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn writerNonBlocking(self: *Self) WriterNonBlocking {
            return .{ .context = self };
        }

        fn readBlocking(self: *Self, out: []DataType) ReadError!usize {
            var remaining = out;
            while (remaining.len > 0) {
                while (self.rx.readableLength() == 0) {
                    self.usb.update();
                }

                const bytes_read = self.rx.read(remaining);
                remaining = remaining[bytes_read..];
            }

            return out.len;
        }

        fn readNonBlocking(self: *Self, out: []DataType) ReadErrorNonBlocking!usize {
            if (out.len == 0) return 0;
            const bytes_read = self.rx.read(out);
            return if (bytes_read == 0) error.WouldBlock else bytes_read;
        }

        fn writeBlocking(self: *Self, data_to_write: []const DataType) WriteError!usize {
            var remaining = data_to_write;
            while (remaining.len > 0) {
                var bytes_to_write = self.tx.writableLength();
                while (bytes_to_write == 0) {
                    self.usb.update();
                    bytes_to_write = self.tx.writableLength();
                }

                if (bytes_to_write > remaining.len) {
                    bytes_to_write = remaining.len;
                }

                self.tx.writeAssumeCapacity(remaining[0..bytes_to_write]);
                remaining = remaining[bytes_to_write..];
            }

            return data_to_write.len;
        }

        fn writeNonBlocking(self: *Self, data_to_write: []const DataType) WriteErrorNonBlocking!usize {
            if (data_to_write.len == 0) return 0;
            const len = self.tx.writableLength();
            if (len == 0) return error.WouldBlock;
            self.tx.writeAssumeCapacity(data_to_write[0..len]);
            return len;
        }

        /// Note this implementation ignores all the optional requests.
        /// The response available notification can be sent when the received_encapsulated_command field is set (then unset it)
        pub fn handleSetup(self: *Self, setup: usb.SetupPacket) bool {
            if (setup.kind != .class or setup.target != .interface) return false;
            if (setup.getInterfaceNumberPayload() != config.communications_interface_index) return false;
            switch (setup.request) {
                requests.send_encapsulated_command => if (setup.direction == .out) {
                    log.info("send_gencapsulated_command", .{});
                    self.usb.setupTransferOut(setup.data_len);
                    self.received_request = setup.request;
                    return true;
                },
                requests.get_encapsulated_response => if (setup.direction == .in) {
                    log.info("Ignoring get_gencapsulated_response", .{});
                    self.usb.setupTransferIn(0);
                    return true;
                },
                requests.set_line_coding => if (setup.direction == .out) {
                    log.info("set_line_coding", .{});
                    self.usb.setupTransferOut(setup.data_len);
                    self.received_request = setup.request;
                    return true;
                },
                requests.get_line_coding => if (setup.direction == .in) {
                    log.info("get_line_coding", .{});
                    self.usb.fillSetupIn(0, std.mem.asBytes(&self.line_coding));
                    self.usb.setupTransferIn(@bitSizeOf(LineCoding) / 8);
                    return true;
                },
                requests.set_control_line_state => if (setup.direction == .out) {
                    log.info("set_line_coding", .{});
                    self.usb.setupTransferOut(setup.data_len);
                    self.received_request = setup.request;
                    return true;
                },
                else => {},
            }
            return false;
        }

        pub fn handleSetupOutBuffer(self: *Self, setup: usb.SetupPacket, offset: u16, data: []volatile const u8) bool {
            switch (setup.request) {
                requests.send_encapsulated_command => {
                    self.received_encapsulated_command = true;
                    return true;
                },
                requests.set_line_coding => {
                    std.debug.assert(offset == 0);
                    self.line_coding = std.mem.bytesToValue(LineCoding, data);
                    return true;
                },
                requests.set_control_line_state => {
                    std.debug.assert(offset == 0);
                    const state = std.mem.bytesToValue(ControlLineState, data);
                    self.dtr = state.dtr;
                    self.rts = state.rts;
                    return true;
                },
                else => return false,
            }
        }

        pub fn handleOutBuffer(self: *Self, data: []volatile const u8) void {
            self.rx.writeAssumeCapacity(@volatileCast(data));
        }
        pub fn fillInBuffer(self: *Self, data: []u8) u16 {
            return @intCast(self.tx.read(data));
        }

    };
}
