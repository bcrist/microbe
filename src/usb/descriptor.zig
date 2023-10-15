const std = @import("std");
const endpoint = @import("endpoint.zig");
const classes = @import("classes.zig");
const chip = @import("chip");

pub const Kind = enum (u8) {
    device = 0x01,
    configuration = 0x02,
    string = 0x03,
    interface = 0x04, // not directly queried; sent with configuration descriptor
    endpoint = 0x05, // not directly queried; sent with configuration descriptor
    device_qualifier = 0x06,
    _
};

pub const Version = packed struct (u16) {
    rev: u4 = 0,
    minor: u4 = 0,
    major: u8,
};

pub const UsbVersion = enum (u16) {
    usb_1_1 = @bitCast(Version{ .major = 1, .minor = 1 }),
    usb_2_0 = @bitCast(Version{ .major = 2 }),
    _
};

pub const Device = packed struct (u144) {
    _len: u8 = @sizeOf(Device),
    _kind: Kind = .device,

    usb_version: UsbVersion,
    class: classes.Info,
    max_packet_size_bytes: u8 = chip.usb.max_packet_size_bytes,
    vendor_id: u16,
    product_id: u16,
    version: Version,
    manufacturer_name: StringID = .manufacturer_name,
    product_name: StringID = .product_name,
    serial_number: StringID = .serial_number,
    configuration_count: u8,
};

// A subset of the full device descriptor
pub const DeviceQualifier = packed struct (u80) {
    _len: u8 = @sizeOf(DeviceQualifier),
    _kind: Kind = .device_qualifier,

    usb_version: UsbVersion,
    class: classes.Info,
    max_packet_size_bytes: u8 = chip.usb_max_packet_size_bytes,
    configuration_count: u8,
    _reserved: u8 = 0,
};

pub const Configuration = packed struct (u72) {
    _len: u8 = @sizeOf(Configuration),
    _kind: Kind = .configuration,

    /// Total length of all descriptors in this configuration, concatenated.
    /// This will include this descriptor, plus at least one interface
    /// descriptor, plus each interface descriptor's endpoint descriptors.
    length_bytes: u16,
    interface_count: u8,
    number: u8,
    name: StringID = .default_configuration_name,
    _bus_powered: bool = true, // must be set even if self_powered is set.
    self_powered: bool,
    remote_wakeup: bool, // device can signal for host to take it out of suspend
    _reserved: u5 = 0,
    max_current_ma_div2: u8,
};

pub const Interface = packed struct (u72) {
    _len: u8 = @sizeOf(Interface),
    _kind: Kind = .interface,

    number: u8,
    /// Allows a single interface to have several alternate interface
    /// settings, where each alternate increments this field. Normally there's
    /// only one, and `alternate_setting` is zero.
    alternate_setting: u8 = 0,
    endpoint_count: u8,
    class: classes.Info,
    name: StringID = .default_interface_name,
};

pub const Endpoint = packed struct (u56) {
    _len: u8 = @sizeOf(Endpoint),
    _kind: Kind = .endpoint,

    address: endpoint.Address,
    transfer_kind: endpoint.TransferKind,
    synchronization: endpoint.Synchronization = .none,
    usage: endpoint.Usage = .data,
    _reserved: u2 = 0,
    max_packet_size_bytes: u16 = chip.usb.max_packet_size_bytes,
    poll_interval_ms: u8,
};

pub const ID = struct {
    kind: Kind,
    index: u8,
};

pub const StringID = enum (u8) {
    language = 0,
    manufacturer_name = 1,
    product_name = 2,
    serial_number = 3,
    default_configuration_name = 4,
    default_interface_name = 5,
    _
};

pub fn String(comptime utf8: []const u8) type {
    const utf16_len = (std.unicode.calcUtf16LeLen(utf8) catch unreachable);
    comptime var utf16: [utf16_len]u16 = undefined;
    _ = comptime std.unicode.utf8ToUtf16Le(&utf16, utf8);

    return extern struct {
        _len: u8 = @sizeOf(@This()),
        _kind: Kind = .string,
        data: [utf16_len]u16 = utf16,
    };
}
