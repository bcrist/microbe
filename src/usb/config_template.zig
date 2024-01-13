/// Instructions:
/// 1. Copy this file to your project.
/// 2. Implement/update TODOs
/// 5. Call init() at the top of your main function and update() within your main loop

const std = @import("std");
const usb = @import("microbe").usb;
const descriptor = usb.descriptor;
const endpoint = usb.endpoint;
const classes = usb.classes;
const Setup_Packet = usb.Setup_Packet;

pub fn get_device_descriptor() descriptor.Device {
    return .{
        .usb_version = .usb_2_0,
        .class = undefined, // TODO
        .vendor_id = 0x0000, // TODO
        .product_id = 0x0000, // TODO
        .version = .{
            .major = 0, // TODO
            .minor = 1, // TODO
        },
        .configuration_count = @intCast(configurations.len),
    };
}

const languages: descriptor.Supported_Languages(&.{
    .english_us,
    // TODO add any additonal languages here
}) = .{};
const strings = struct {
    const mfr_name: descriptor.String("TODO") = .{};
    const product_name: descriptor.String("TODO") = .{};
    const serial_number: descriptor.String("TODO") = .{};
    const default_configuration_name: descriptor.String("TODO") = .{};
    const default_interface_name: descriptor.String("TODO") = .{};

    // TODO add any additional strings needed
};

pub fn get_string_descriptor(id: descriptor.String_ID, language: descriptor.Language) ?[]const u8 {
    if (id == .languages) return languages.as_bytes();
    return switch (language) {
        .english_us => switch (id) {
            .manufacturer_name => strings.mfr_name.as_bytes(),
            .product_name => strings.product_name.as_bytes(),
            .serial_number => strings.serial_number.as_bytes(),
            .default_configuration_name => strings.default_configuration_name.as_bytes(),
            .default_interface_name => strings.default_interface_name.as_bytes(),
            // TODO hook up any additional strings to IDs
            else => null,
        },
        // TODO hook up any additional language strings here
        else => null,
    };
}

const default_configuration = struct {
    pub const default_interface = struct {
        pub const index = 0;
        // pub const alternate_setting: u8 = 0; // optional
        pub const class: classes.Class_Info = undefined; // TODO
        // pub const name: StringID = .default_interface_name; // optional

        pub const default_endpoint = struct {
            pub const address: endpoint.Address = .{
                .ep = 1, // TODO
                .dir = .in, // TODO
            };
            pub const kind: endpoint.Transfer_Kind = .bulk; // TODO
            // pub const poll_interval_ms: u8 = 16; // only for .interrupt endpoints
        };

        // TODO if you need multiple endpoints, add additional ones here

        pub const endpoints = .{
            default_endpoint,
            // TODO add any additional endpoints here
        };
    };

    // TODO if you need multiple interfaces, add additional ones here

    pub const interfaces = .{
        default_interface,
        // TODO add any additional interfaces here
    };

    pub const descriptors: Descriptor_Set = .{};
    pub const Descriptor_Set = packed struct {
        config: descriptor.Configuration = .{
            .number = 1, // TODO
            .name = .default_configuration_name, // TODO
            .self_powered = false, // TODO
            .remote_wakeup = false, // TODO
            .max_current_ma_div2 = 50, // TODO
            .length_bytes = @bitSizeOf(Descriptor_Set) / 8,
            .interface_count = @intCast(interfaces.len),
        },
        interface: descriptor.Interface = descriptor.Interface.parse(default_interface),
    };
};

// TODO if you want to define more than one configuration, add additional structs here

const configurations = .{
    default_configuration,
    // TODO add any additional configuration structs here
};

pub fn get_configuration_descriptor_set(configuration_index: u8) ?[]const u8 {
    inline for (0.., configurations) |i, configuration| {
        if (i == configuration_index) {
            return descriptor.asBytes(&configuration.descriptors);
        }
    }
    return null;
}

pub fn get_interface_count(configuration: u8) u8 {
    inline for (configurations) |cfg| {
        if (cfg.descriptors.config.number == configuration) {
            return @intCast(cfg.interfaces.len);
        }
    }
    return 0;
}

pub fn get_endpoint_count(configuration: u8, interface_index: u8) u8 {
    inline for (configurations) |cfg| {
        if (cfg.descriptors.config.number == configuration) {
            inline for (0.., cfg.interfaces) |j, interface| {
                if (j == interface_index) {
                    return @intCast(interface.endpoints.len);
                }
            }
        }
    }
    return 0;
}

// Endpoint descriptors are not queried directly by hosts, but these are used to set up
// the hardware configuration for each endpoint.
pub fn get_endpoint_descriptor(configuration: u8, interface_index: u8, endpoint_index: u8) descriptor.Endpoint {
    inline for (configurations) |cfg| {
        if (cfg.descriptors.config.number == configuration) {
            inline for (0.., cfg.interfaces) |j, iface| {
                if (j == interface_index) {
                    inline for (0.., iface.endpoints) |k, ep| {
                        if (k == endpoint_index) {
                            return descriptor.Endpoint.parse(ep);
                        }
                    }
                }
            }
        }
    }
    unreachable;
}

/// This function can be used to provide class-specific descriptors associated with the device
pub fn get_descriptor(kind: descriptor.Kind, descriptor_index: u8) ?[]const u8 {
    _ = descriptor_index;
    _ = kind;
    // TODO
    return null;
}

/// This function can be used to provide class-specific descriptors associated with a particular interface, e.g. HID report descriptors
pub fn get_interface_specific_descriptor(interface: u8, kind: descriptor.Kind, descriptor_index: u8) ?[]const u8 {
    _ = descriptor_index;
    _ = kind;
    _ = interface;
    // TODO
    return null;
}

/// This function can be used to provide class-specific descriptors associated with a particular endpoint
pub fn get_endpoint_specific_descriptor(ep: endpoint.Index, kind: descriptor.Kind, descriptor_index: u8) ?[]const u8 {
    _ = descriptor_index;
    _ = kind;
    _ = ep;
    // TODO
    return null;
}

/// This function determines whether the USB engine should reply to non-control transactions with ACK or NAK
/// For .in endpoints, this should return true when we have some data to send.
/// For .out endpoints, this should return true when we can handle at least the max packet size of data for this endpoint.
pub fn is_endpoint_ready(address: endpoint.Address) bool {
    _ = address; // autofix
    // TODO
}

/// The buffer returned from this function only needs to remain valid briefly; it will be copied to an internal buffer.
/// If you don't have a buffer available, you can instead define:
///     pub fn fill_in_buffer(ep: endpoint.Index, data: []u8) u16 { ... }
pub fn get_in_buffer(ep: endpoint.Index, max_packet_size: u16) []const u8 {
    _ = ep; // autofix
    _ = max_packet_size; // autofix
    // TODO
}

pub fn handle_out_buffer(ep: endpoint.Index, data: []volatile const u8) void {
    _ = ep; // autofix
    _ = data; // autofix
    // TODO
}

/// Called when a SOF packet is received
pub fn handle_start_of_frame() void {
    // TODO
}

/// Called when the host resets the bus
pub fn handle_bus_reset() void {
   // TODO
}

/// Called when a set_configuration setup request is processed
pub fn handle_configuration_changed(configuration: u8) void {
    _ = configuration; // autofix
    // TODO
}

/// Used to respond to the get_status setup request
pub fn is_device_self_powered() bool {
    return false;
}

/// Handle any class/device-specific setup requests here.
/// Return true if the setup request is recognized and handled.
///
/// Requests where setup.data_len == 0 should call `device.setup_status_in()`.
/// Note this is regardless of whether setup.direction is .in or .out.
///
/// .in requests with a non-zero length should make one or more calls to `device.fill_setup_in(offset, data)`,
/// followed by a call to `device.setup_transfer_in(total_length)`, or just a single
/// call to `device.setup_transfer_in_data(data)`.  The data may be larger than the maximum EP0 transfer size.
/// In that case the data will need to be provided again using the `fill_setup_in` function below.
///
/// .out requests with a non-zero length should call `device.setup_transfer_out(setup.data_len)`.
/// The data will then be provided later via `handle_setup_out_buffer`
///
/// Note that this gets called even for standard requests that are normally handled internally.
/// You _must_ check that the packet matches what you're looking for specifically.
fn handle_setup(setup: Setup_Packet) bool {
    _ = setup; // autofix
    // TODO
}

/// If an .in setup request's data is too large for a single data packet,
/// this will be called after each buffer is transferred to fill in the next buffer.
/// If it returns false, endpoint 0 will be stalled.
/// Otherwise, it is assumed that the entire remaining data, or the entire buffer (whichever is smaller)
/// will be filled with data to send.
/// 
/// Normally this function should make one or more calls to `device.fill_setup_in(offset, data)`,
/// corresponding to the entire data payload, including parts that have already been sent.  The
/// parts outside the current buffer will automatically be ignored.
pub fn fill_setup_in(setup: Setup_Packet) bool {
    _ = setup; // autofix
    // TODO
    return false;
}

/// Return true if the setup request is recognized and the data buffer was processed.
fn handle_setup_out_buffer(setup: Setup_Packet, offset: u16, data: []volatile const u8, last_buffer: bool) bool {
    _ = setup; // autofix
    _ = offset; // autofix
    _ = data; // autofix
    _ = last_buffer; // autofix
    // TODO
    return false;
}

pub fn init() void {
    device.init();
    // TODO add any additional initialization needed
}

pub fn update() void {
    device.update();
}

var device: usb.USB(@This()) = .{};
// TODO add any additional global state needed
