/// Note this file is focused on basic CDC ACM interfaces for UART emulation.
/// It will not help much with creating a CDC networking device.
///
/// Standard CDC-ACM headers:
///
/// Interface_Association: class.control_interface, 2 interfaces
/// Interface: class.control_interface, 1 endpoint
/// Header_Descriptor
/// Call_Management_Descriptor
/// Abstract_Control_Management_Descriptor
/// Union_Descriptor
/// Endpoint: control endpoint, in, interrupt, 10-16ms polling
/// Interface: class.data_interface, 2 endpoints
/// Endpoint: data endpoint, in, bulk
/// Endpoint: data endpoint, out, bulk

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

pub const Header_Descriptor = packed struct (u40) {
    _len: u8 = @bitSizeOf(@This()) / 8,
    _kind: descriptor.Kind = interface_descriptor,
    _subkind: Descriptor_Subkind = .header,
    cdc_version: descriptor.Version = .{ .major = 1, .minor = 2 },

    pub fn asBytes(self: *const @This()) []const u8 {
        return descriptor.asBytes(self);
    }
};

pub const Call_Management_Descriptor = packed struct (u40) {
    _len: u8 = @bitSizeOf(@This()) / 8,
    _kind: descriptor.Kind = interface_descriptor,
    _subkind: Descriptor_Subkind = .call_management,
    device_handles_call_management: bool = false,
    can_transfer_call_management_over_data_interface: bool = true,
    _reserved: u6 = 0,
    data_interface_index: u8, // zero-based index of the data interface within this configuration

    pub fn asBytes(self: *const @This()) []const u8 {
        return descriptor.asBytes(self);
    }
};

pub const Abstract_Control_Management_Descriptor = packed struct (u32) {
    _len: u8 = @bitSizeOf(@This()) / 8,
    _kind: descriptor.Kind = interface_descriptor,
    _subkind: Descriptor_Subkind = .abstract_control_management,
    supports_feature_requests: bool = false,
    supports_line_requests: bool = true,
    supports_send_break_request: bool = false,
    supports_network_connection_notification: bool = false,
    _reserved: u4 = 0,

    pub fn asBytes(self: *const @This()) []const u8 {
        return descriptor.asBytes(self);
    }
};

pub const Union_Descriptor = packed struct (u40) {
    _len: u8 = @bitSizeOf(@This()) / 8,
    _kind: descriptor.Kind = interface_descriptor,
    _subkind: Descriptor_Subkind = .@"union",
    control_interface_index: u8, // zero-based index of the control interface within this configuration
    data_interface_index: u8, // zero-based index of the data interface within this configuration

    pub fn asBytes(self: *const @This()) []const u8 {
        return descriptor.asBytes(self);
    }
};

const interface_descriptor: descriptor.Kind = @enumFromInt(0x24);

pub const Descriptor_Subkind = enum (u8) {
    header = 0,
    call_management = 1,
    abstract_control_management = 2,
    @"union" = 6,
};

pub const Line_Coding = packed struct (u56) {
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

pub const Control_Line_State = packed struct (u16) {
    dtr: bool,
    rts: bool,
    _reserved: u14 = 0,
};

pub const Serial_State = packed struct (u16) {
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

    fn request(comptime num: comptime_int) usb.Setup_Request_Kind {
        return @enumFromInt(num);
    }
};

pub const notifications = struct {
    // These are sent on the communications interface's in endpoint

    pub fn networkConnection(interface_index: u8, connected: bool) usb.Setup_Packet {
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
    pub fn responseAvailable(interface_index: u8) usb.Setup_Packet {
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

    pub fn serialState(interface_index: u8, state: Serial_State) Serial_State_Notification {
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
    pub const Serial_State_Notification = packed struct (u80) {
        setup: usb.Setup_Packet,
        state: Serial_State,
    };

};

pub const UART_Config = struct {
    communications_interface_index: u8,
    rx_packet_size: comptime_int,
    tx_buffer_size: comptime_int = 256,
    rx_buffer_size: comptime_int = 128,
};
pub fn UART(comptime USB_Config: type, comptime config: UART_Config) type {
    if (!std.math.isPowerOfTwo(config.tx_buffer_size)) {
        @compileError("UART Tx buffer size must be a power of two!");
    }
    if (!std.math.isPowerOfTwo(config.rx_buffer_size)) {
        @compileError("UART Rx buffer size must be a power of two!");
    }

    const log = std.log.scoped(.usb);

    const Tx_FIFO = std.fifo.LinearFifo(u8, .{ .Static = config.tx_buffer_size });
    const Rx_FIFO = std.fifo.LinearFifo(u8, .{ .Static = config.rx_buffer_size });

    const Errors = struct {
        const Read            = error { Disconnected };
        const ReadNonBlocking = error { Would_Block };

        const Write            = error { Disconnected };
        const write_nonblocking = error { Would_Block };
    };

    return struct {

        const Self = @This();
        pub const Data_Type = u8;

        pub const Read_Error = Errors.Read;
        pub const Reader = std.io.Reader(*Self, Read_Error, Self.read_blocking);

        pub const Read_Error_Nonblocking = Errors.ReadNonBlocking;
        pub const Reader_Nonblocking = std.io.Reader(*Self, Read_Error_Nonblocking, Self.read_nonblocking);

        pub const Write_Error = Errors.Write;
        pub const Writer = std.io.Writer(*Self, Write_Error, Self.write_blocking);

        pub const Write_Error_Nonblocking = Errors.write_nonblocking;
        pub const Writer_Nonblocking = std.io.Writer(*Self, Write_Error_Nonblocking, Self.write_nonblocking);

        usb: *usb.USB(USB_Config),
        tx: Tx_FIFO,
        rx: Rx_FIFO,
        received_encapsulated_command: bool,
        dtr: bool,
        rts: bool,
        line_coding: Line_Coding,

        pub fn init(usb_ptr: *usb.USB(USB_Config)) Self {
            return .{
                .usb = usb_ptr,
                .tx = Tx_FIFO.init(),
                .rx = Rx_FIFO.init(),
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

        pub fn is_rx_full(self: *Self) bool {
            return self.rx.writableLength() < config.rx_packet_size;
        }

        pub fn get_rx_available_count(self: *Self) usize {
            return self.rx.readableLength();
        }

        pub fn can_read(self: *Self) bool {
            return self.rx.readableLength() > 0;
        }

        pub fn peek(self: *Self, buffer: []Data_Type) []const Data_Type {
            if (buffer.len == 0) return buffer[0..0];
            var bytes = self.rx.readableSlice(0);
            if (bytes.len > buffer.len) {
                bytes = bytes[0..buffer.len];
            }
            @memcpy(buffer.ptr, bytes);
            return buffer[0..bytes.len];
        }

        pub fn peek_one(self: *Self) ?Data_Type {
            if (self.rx.count > 0) self.rx.peekItem(0) else null;
        }

        pub fn reader(self: *Self) Reader {
            return .{ .context = self };
        }

        pub fn reader_nonblocking(self: *Self) Reader_Nonblocking {
            return .{ .context = self };
        }

        pub fn is_tx_idle(self: *Self) bool {
            return self.tx.readableLength() == 0;
        }

        pub fn get_tx_available_count(self: *Self) usize {
            return self.tx.writableLength();
        }

        pub fn can_write(self: *Self) bool {
            return self.tx.writableLength() > 0;
        }

        pub fn writer(self: *Self) Writer {
            return .{ .context = self };
        }

        pub fn writer_nonblocking(self: *Self) Writer_Nonblocking {
            return .{ .context = self };
        }

        fn read_blocking(self: *Self, out: []Data_Type) Read_Error!usize {
            var remaining = out;
            while (remaining.len > 0) {
                while (self.rx.readableLength() == 0) {
                    if (self.usb.state != .connected) return error.Disconnected;
                    self.usb.update();
                }

                const bytes_read = self.rx.read(remaining);
                remaining = remaining[bytes_read..];
            }

            return out.len;
        }

        fn read_nonblocking(self: *Self, out: []Data_Type) Read_Error_Nonblocking!usize {
            if (out.len == 0) return 0;
            const bytes_read = self.rx.read(out);
            return if (bytes_read == 0) error.Would_Block else bytes_read;
        }

        fn write_blocking(self: *Self, data_to_write: []const Data_Type) Write_Error!usize {
            var remaining = data_to_write;
            while (remaining.len > 0) {
                var bytes_to_write = self.tx.writableLength();
                while (bytes_to_write == 0) {
                    if (self.usb.state != .connected) return error.Disconnected;
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

        fn write_nonblocking(self: *Self, data_to_write: []const Data_Type) Write_Error_Nonblocking!usize {
            if (data_to_write.len == 0) return 0;
            const len = self.tx.writableLength();
            if (len == 0) return error.Would_Block;
            self.tx.writeAssumeCapacity(data_to_write[0..len]);
            return len;
        }

        /// Note this implementation ignores all the optional requests.
        /// The response available notification can be sent when the received_encapsulated_command field is set (then unset it)
        pub fn handle_setup(self: *Self, setup: usb.Setup_Packet) bool {
            if (setup.kind != .class or setup.target != .interface) return false;

            const payload: packed struct (u32) {
                _reserved: u16,
                interface: u16,
            } = @bitCast(setup.payload);
            if (payload.interface != config.communications_interface_index) return false;
            
            switch (setup.request) {
                requests.send_encapsulated_command => if (setup.direction == .out) {
                    log.info("send_gencapsulated_command", .{});
                    self.usb.setup_transfer_out(setup.data_len);
                    return true;
                },
                requests.get_encapsulated_response => if (setup.direction == .in) {
                    log.info("Ignoring get_gencapsulated_response", .{});
                    self.usb.setup_transfer_in(0);
                    return true;
                },
                requests.set_line_coding => if (setup.direction == .out) {
                    log.info("set_line_coding", .{});
                    self.usb.setup_transfer_out(setup.data_len);
                    return true;
                },
                requests.get_line_coding => if (setup.direction == .in) {
                    log.info("get_line_coding", .{});
                    _ = self.usb.fill_setup_in(0, std.mem.asBytes(&self.line_coding));
                    self.usb.setup_transfer_in(@bitSizeOf(Line_Coding) / 8);
                    return true;
                },
                requests.set_control_line_state => if (setup.direction == .out) {
                    log.info("set_control_line_state", .{});
                    self.usb.setup_transfer_in(0);
                    const value: u16 = @truncate(setup.payload);
                    const state: Control_Line_State = @bitCast(value);
                    self.dtr = state.dtr;
                    self.rts = state.rts;
                    return true;
                },
                else => {},
            }
            return false;
        }

        pub fn handle_setup_out_buffer(self: *Self, setup: usb.Setup_Packet, offset: u16, data: []volatile const u8, final_buffer: bool) bool {
            if (setup.kind != .class) return false;
            switch (setup.request) {
                requests.send_encapsulated_command => {
                    self.received_encapsulated_command = true;
                    return true;
                },
                requests.set_line_coding => {
                    if (offset == 0 and data.len == @bitSizeOf(Line_Coding) / 8 and final_buffer == true) {
                        @memcpy(std.mem.asBytes(&self.line_coding).ptr, @volatileCast(data));
                        log.debug("line coding updated: {any}", .{ self.line_coding });
                    }
                    return true;
                },
                else => return false,
            }
        }

        pub fn handle_out_buffer(self: *Self, data: []volatile const u8) void {
            self.rx.writeAssumeCapacity(@volatileCast(data));
        }
        pub fn fill_in_buffer(self: *Self, data: []u8) u16 {
            return @intCast(self.tx.read(data));
        }

    };
}

const Class = classes.Class;
const Subclass = classes.Subclass;
const Protocol = classes.Protocol;
const classes = @import("classes.zig");
const descriptor = @import("descriptor.zig");
const usb = @import("../usb.zig");
const std = @import("std");
