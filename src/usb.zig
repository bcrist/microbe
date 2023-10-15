// TODO add support for devices with more than one USB interface

comptime {
    std.debug.assert(@import("builtin").cpu.arch.endian() == .Little);
}

const std = @import("std");
const chip = @import("chip");

pub const log = std.log.scoped(.usb);
pub const classes = @import("usb/classes.zig");
pub const descriptor = @import("usb/descriptor.zig");
pub const endpoint = @import("usb/endpoint.zig");

// device classes:
pub const hid = @import("usb/hid.zig");

// Takes a struct that defines these functions:
//     fn getDeviceDescriptor() descriptor.Device
//     fn getStringDescriptor(id: descriptor.StringID, language: u16) []const u8
//     fn getConfigurationDescriptor(configuration: u8) descriptor.Configuration
//     fn getInterfaceDescriptor(configuration: u8, interface: u8) descriptor.Interface
//     fn getEndpointDescriptor(configuration: u8, interface: u8, index: u8) descriptor.Endpoint
//     fn getDescriptor(kind: descriptor.Kind, configuration: u8, index: u8) []const u8
//     fn isEndpointReady(address: endpoint.Address) bool
//     fn handleOutBuffer(ep: endpoint.Index, data: []const u8) void
//     fn fillInBuffer(ep: endpoint.Index, max_packet_size: usize) []const u8
//
// It may optionally also define:
//     fn handleBusReset() void
//     fn handleSetup(setup: SetupPacket) void
//     fn getExtraConfigurationDescriptors(configuration: u8, interface: u8) []const descriptor.ID
//     fn setConfiguration(configuration: u8) void
//     fn isDeviceSelfPowered() bool // if not defined, assumes false
//
// Expects the following to be defined in chip.usb:
//     const max_packet_size_bytes: u16
//     fn init() void
//     fn deinit() void
//     fn handleBusReset() void
//     fn pollEvents() Events
//     fn getSetupPacket() SetupPacket
//     fn setAddress(address: u7) void
//     fn configureEndpoint(ed: descriptor.Endpoint) void
//     fn bufferIterator() Iterator(endpoint.BufferInfo) // buffers of endpoints that have finished their transfer
//     fn fillBufferIn(ep: endpoint.Index, offset: isize, data: []const u8) void
//     fn startTransferIn(ep: endpoint.Index, len: usize, pid: PID) void
//     fn startTransferOut(ep: endpoint.Index, len: usize, pid: PID) void
//     fn startStall(address: endpoint.Address) void
//     fn startNak(address: endpoint.Address) void
pub fn Usb(comptime cfg: anytype) type {
    return struct {
        const Self = @This();
        pub const config = cfg;
        pub const debug = @hasDecl(config, "enable_logging") and config.enable_logging;

        setup_data_offset: isize = 0,
        new_address: ?u7 = null, // After .set_address, we have to do an acknowledgement step using our old address, so the new address can't be applied immediately
        configuration: ?u8 = null, // The current configuration number, or null if the host hasn't yet selected one
        started: bool = false, // Have we set up buffer transfers after being configured?
        allow_remote_wakeup: bool = false, // allow device to request wakeup from suspend
        ep_state: [16]extern struct {
            in_max_packet_size_bytes: u16 = chip.usb.max_packet_size_bytes,
            out_max_packet_size_bytes: u16 = chip.usb.max_packet_size_bytes,
            next_pid: PID = .data0,
            halted: bool = true,
            in: EndpointState = .stalled,
            out: EndpointState = .stalled,
        } = undefined,

        const EndpointState = enum (u2) {
            waiting,
            active,
            stalled,
        };

        pub fn init(self: *Self) void {
            chip.usb.init();
            self.reset();
        }

        pub fn deinit(self: *Self) void {
            self.reset();
            chip.usb.deinit();
        }

        pub fn reset(self: *Self) void {
            self.setup_data_offset = 0;
            self.new_address = null;
            self.configuration = null;
            self.started = false;
            self.allow_remote_wakeup = false;
            self.ep_state = .{ .{} } ** 16;
            chip.usb.handleBusReset();
            if (@hasDecl(config, "handleBusReset")) {
                config.handleBusReset();
            }
            if (debug) log.info("bus reset", .{});
        }

        /// Call from main loop
        pub fn update(self: *Self) void {
            const events: Events = chip.usb.pollEvents();

            if (events.setup_request) self.handleSetup();

            if (events.start_of_frame) {
                var iter = chip.usb.get.bufferIterator();
                while (iter.next()) |info| {
                    self.updateBuffer(info);
                }
            }

            if (events.bus_reset) self.reset();

            if (!self.started) {
                if (self.configuration) |configuration| {
                    const cd: descriptor.Configuration = config.getConfigurationDescriptor(configuration);
                    for (0..cd.interface_count) |i| {
                        const interface: u8 = @intCast(i);
                        const id: descriptor.Interface = config.getInterfaceDescriptor(configuration, interface);
                        for (0..id.endpoint_count) |e| {
                            const ed: descriptor.Endpoint = config.getEndpointDescriptor(configuration, interface, @intCast(e));
                            chip.usb.configureEndpoint(ed);
                            const ep = ed.address.ep;
                            self.ep_state[ep].halted = false;
                            switch (ed.address.dir) {
                                .out => {
                                    self.ep_state[ep].out_max_packet_size_bytes = ed.max_packet_size_bytes;
                                    self.updateOutState(ep);
                                },
                                .in => {
                                    self.ep_state[ep].in_max_packet_size_bytes = ed.max_packet_size_bytes;
                                    if (ep != 0) {
                                        self.updateInState(ep);
                                    }
                                },
                            } 
                        }
                    }
                    self.started = true;
                }
            }
        }

        fn updateBuffer(self: *Self, info: endpoint.BufferInfo) void {
            const ep = info.address.ep;
            const state = self.ep_state[ep];
            switch (info.address.dir) {
                .in => {
                    if (ep == 0) {
                        if (self.new_address) |addr| {
                            chip.usb.setAddress(addr);
                        }

                        if (self.setup_data_offset > 0) {
                            const setup = chip.usb.getSetupPacket();
                            std.debug.assert(setup.request == .get_descriptor);
                            self.handleGetDescriptor(setup.payload.descriptor, setup.data_len);
                        } else {
                            // We've completed all the EP0 IN DATA packets needed for this control transfer.
                            // Set up for an empty EP0 OUT STATUS packet:
                            chip.usb.startTransferOut(0, 0, state.next_pid);
                        }
                    } else {
                        self.updateInState(ep);
                    }
                },
                .out => {
                    if (info.buffer.len > 0) {
                        config.handleOutBuffer(ep, info.buffer);
                        if (debug) log.info("ep{} out: {}", .{ std.fmt.fmtSliceHexLower(info.buffer) });
                    }
                    self.updateOutState(ep);
                },
            }
        }

        fn updateInState(self: *Self, ep: endpoint.Index) void {
            const state = self.ep_state[ep];
            if (state.halted) {
                if (state.in != .stalled) {
                    chip.usb.startStall(.{ .ep = ep, .dir = .in });
                    self.ep_state[ep].in = .stalled;
                    if (debug) log.info("ep{} in stalled...", .{ ep });
                }
            } else if (!config.isEndpointReady(.{ .ep = ep, .dir = .in })) {
                if (state.in != .waiting) {
                    chip.usb.startNak(.{ .ep = ep, .dir = .in });
                    self.ep_state[ep].in = .waiting;
                    if (debug) log.debug("ep{} in waiting...", .{ ep });
                }
            } else {
                const data: []const u8 = config.fillInBuffer(ep, state.max_packet_size);
                chip.usb.fillBufferIn(ep, 0, data);
                chip.usb.startTransferIn(ep, data.len, state.next_pid);
                self.ep_state[ep].in = .active;
                self.ep_state[ep].next_pid = state.next_pid.next();
                if (debug) log.info("ep{} in: {}", .{ std.fmt.fmtSliceHexLower(data) });
            }
        }

        fn updateOutState(self: *Self, ep: endpoint.Index) void {
            const state = self.ep_state[ep];
            if (state.halted) {
                if (state.out != .stalled) {
                    chip.usb.startStall(.{ .ep = ep, .dir = .out });
                    self.ep_state[ep].out = .stalled;
                    if (debug) log.info("ep{} out stalled...", .{ ep });
                }
            } else if (!config.isEndpointReady(.{ .ep = ep, .dir = .out })) {
                if (state.out != .waiting) {
                    chip.usb.startNak(.{ .ep = ep, .dir = .out });
                    self.ep_state[ep].out = .waiting;
                    if (debug) log.debug("ep{} out waiting...", .{ ep });
                }
            } else {
                chip.usb.startTransferOut(ep, state.max_packet_size, state.next_pid);
                self.ep_state[ep].out = .active;
                self.ep_state[ep].next_pid = state.next_pid.next();
                if (debug) log.debug("ep{} out started", .{ ep });
            }
        }

        fn handleSetup(self: *Self) void {
            self.setup_data_offset = 0;
            self.ep_state[0].next_pid = .data1;
            const setup: SetupPacket = chip.usb.getSetupPacket();
            switch (setup.request) {
                .set_address => if (setup.direction == .out) {
                    chip.usb.startTransferOut(0, 0, .data1);
                    const address: u7 = @truncate(setup.payload.set_address.address);
                    self.new_address = address;
                    if (debug) log.info("set address: {}", .{ address });
                    return;
                },
                .set_configuration => if (setup.direction == .out) {
                    chip.usb.startTransferOut(0, 0, .data1);
                    const configuration = setup.payload.set_configuration.configuration;
                    self.configuration = configuration;
                    if (@hasDecl(config, "setConfiguration")) {
                        config.setConfiguration(configuration);
                    }
                    if (debug) log.info("set configuration: {}", .{ configuration });
                    return;
                },
                .get_configuration => if (setup.direction == .in) {
                    const c: u16 = self.configuration orelse 0;
                    self.setupTransferInData(setup.data_len, std.mem.asBytes(&c));
                    if (debug) log.info("get configuration", .{});
                    return;
                },
                .get_descriptor => if (setup.direction == .in) {
                    self.handleGetDescriptor(setup.payload.descriptor, setup.data_len);
                    return;
                },
                .get_status => if (setup.direction == .in) {
                    var status: u16 = 0;
                    switch (setup.target) {
                        .device => {
                            if (@hasDecl(config, "isDeviceSelfPowered") and config.isDeviceSelfPowered()) status |= 1;
                            if (self.allow_remote_wakeup) status |= 2;
                        },
                        .interface => {
                            const interface: u8 = @intCast(setup.payload.interface_status.interface);
                            if (debug) log.info("get interface {} status", .{ interface });
                        },
                        .endpoint => {
                            const ep: endpoint.Index = @intCast(setup.payload.endpoint_status.endpoint);
                            if (self.ep_state[ep].halted) status |= 1;
                            if (debug) log.info("get endpoint {} status", .{ ep });
                        },
                    }
                    self.setupTransferInData(setup.data_len, std.mem.asBytes(&status));
                    return;
                },
                .set_feature, .clear_feature => if (setup.direction == .out) {
                    chip.usb.startTransferOut(0, 0, .data1);
                    const f = setup.payload.feature;
                    switch (f.feature) {
                        .endpoint_halt => if (setup.target == .endpoint) {
                            const ep: endpoint.Index = @intCast(f.endpoint);
                            self.ep_state[ep].halted = setup.kind == .set_feature;
                        },
                        .device_remote_wakeup => if (setup.target == .device) {
                            self.allow_remote_wakeup = setup.kind == .set_feature;
                        },
                        else => {},
                    }
                    if (debug) log.info("{s}: target = {s}, ep = {}, feature = {s} ({})", .{
                        @tagName(setup.kind),
                        @tagName(setup.target),
                        f.endpoint,
                        @tagName(f.feature),
                        f.feature,
                    });
                    return;
                },
                else => {},
            }

            if (@hasDecl(config, "handleSetup")) {
                config.handleSetup(setup);
            } else {
                // ignore any unrecognized setup packets
                if (debug) log.info("unrecognized setup: {s}, request = {s} ({})", .{
                    @tagName(setup.direction),
                    @tagName(setup.request),
                    @intFromEnum(setup.request)
                });
            }
        }

        fn handleGetDescriptor(self: *Self, which: SetupDescriptorInfo, requested_len: usize) void {
            switch (which.kind) {
                .device => {
                    const d: descriptor.Device = config.getDeviceDescriptor();
                    self.setupTransferInData(requested_len, std.mem.asBytes(&d));
                    if (debug and self.setup_data_offset == 0) {
                        log.info("get device descriptor {}B", .{ requested_len });
                    }
                },
                .device_qualifier => {
                    const d: descriptor.Device = config.getDeviceDescriptor();
                    const dq: descriptor.DeviceQualifier = .{
                        .usb_version = d.usb_version,
                        .class = d.class,
                        .max_packet_size_bytes = d.max_packet_size_bytes,
                        .configuration_count = d.configuration_count,
                    };
                    self.setupTransferInData(requested_len, std.mem.asBytes(&dq));
                    if (debug and self.setup_data_offset == 0) {
                        log.info("get device qualifier {}B", .{ requested_len });
                    }
                    return;
                },
                .string => {
                    const id: descriptor.StringID = @enumFromInt(which.index);
                    const d: []const u8 = config.getStringDescriptor(id, which.language);
                    self.setupTransferInData(requested_len, d);
                    if (debug) log.info("get string {}B: id = {}, lang = {}", .{ requested_len, id, which.language });
                    return;
                },
                .endpoint => {
                    // USB hosts should never ask for endpoint descriptors directly, because
                    // there's no way to know which interface it's querying, so we just ignore it.
                    if (debug and self.setup_data_offset == 0) {
                        log.info("get endpoint descriptor {}B: index = {}", .{ requested_len, which.index });
                    }
                },
                .configuration => {
                    const configuration = self.configuration orelse 0;
                    var total_len: isize = -self.setup_data_offset;

                    const cd: descriptor.Configuration = config.getConfigurationDescriptor(configuration);
                    chip.usb.fillBufferIn(0, total_len, std.mem.asBytes(&cd));
                    total_len += @sizeOf(descriptor.Configuration);

                    for (0..cd.interface_count) |i| {
                        total_len = fillInterfaceDescriptor(configuration, @intCast(i), total_len);
                    }

                    self.setupTransferIn(requested_len, total_len);
                    if (debug and self.setup_data_offset == 0) {
                        log.info("get configuration descriptor {}B: {}", .{ requested_len, configuration });
                    }
                    return;
                },
                .interface => {
                    const configuration = self.configuration orelse 0;
                    const total_len = fillInterfaceDescriptor(configuration, @intCast(which.index), 0);
                    self.setupTransferIn(requested_len, total_len);
                    if (debug and self.setup_data_offset == 0) {
                        log.info("get interface descriptor {}B: config = {}, interface = {}", .{
                            requested_len,
                            configuration,
                            which.index,
                        });
                    }
                },
                else => {
                    const configuration = self.configuration;
                    const d: []const u8 = config.getDescriptor(which.kind, configuration, which.index);
                    self.setupTransferInData(requested_len, d);
                    if (debug and self.setup_data_offset == 0) {
                        log.info("get descriptor {}B: config = {}, kind = 0x{X}, index = {}", .{
                            requested_len,
                            configuration,
                            which.kind,
                            which.index,
                        });
                    }
                    return;
                },
            }
        }

        fn fillInterfaceDescriptor(configuration: u8, interface: u8, offset: u8) usize {
            var total_length = offset;
            const id: descriptor.Interface = config.getInterfaceDescriptor(configuration, interface);
            chip.usb.fillBufferIn(0, total_length, std.mem.asBytes(&id));
            total_length += @sizeOf(descriptor.Interface);

            for (0..id.endpoint_count) |e| {
                const ed: descriptor.Endpoint = config.getEndpointDescriptor(configuration, interface, @intCast(e));
                chip.usb.fillBufferIn(0, total_length, std.mem.asBytes(&ed));
                total_length += @sizeOf(descriptor.Endpoint);
            }

            if (@hasDecl(config, "getExtraConfigurationDescriptors")) {
                for (config.getExtraConfigurationDescriptors(configuration, interface)) |desc| {
                    const d: []const u8 = config.getDescriptor(desc.kind, configuration, desc.index);
                    chip.usb.fillBufferIn(0, total_length, d);
                    total_length += d.len;
                }
            }

            return total_length;
        }

        fn setupTransferInData(self: *Self, requested_len: isize, data: []const u8) void {
            var total_len: isize = -self.setup_data_offset;
            chip.usb.fillBufferIn(0, total_len, data);
            total_len += data.len;
            self.setupTransferIn(requested_len, total_len);
        }

        fn setupTransferIn(self: *Self, requested_len: isize, total_len: isize) void {
            std.debug.assert(total_len > 0);

            const pid = self.ep_state[0].next_pid;
            const len = @min(requested_len, total_len);
            chip.usb.startTransferIn(0, len, pid);
            self.ep_state[0].next_pid = pid.next();

            if (len > self.ep_state[0].max_packet_size_bytes) {
                self.setup_data_offset += len;
            } else {
                self.setup_data_offset = 0;
            }
        }

    };
}

pub const Events = struct {
    start_of_frame: bool = false,
    bus_reset: bool = false,
    setup_request: bool = false,
};

pub const SetupPacket = packed struct (u64) {
    target: enum(u5) {
        device = 0,
        interface = 1,
        endpoint = 2,
        other = 3,
        _,
    },
    kind: enum (u2) {
        standard = 0,
        class = 1,
        vendor = 2,
        _,
    },
    direction: endpoint.Direction,
    request: enum(u8) {
        get_status = 0,
        clear_feature = 1,
        set_feature = 3,
        set_address = 5,
        get_descriptor = 6,
        set_descriptor = 7,
        get_configuration = 8,
        set_configuration = 9,
        get_interface = 10,
        set_interface = 11,
        synch_frame = 12,
        _,
    },
    payload: union {
        raw: u32,
        feature: packed struct (u32) { // used by clear_feature and set_feature
            feature: Feature,
            endpoint: u16,
        },
        interface_status: packed struct (u32) {
            _reserved: u16,
            interface: u16,
        },
        endpoint_status: packed struct (u32) {
            _reserved: u16,
            endpoint: u16,
        },
        set_address: packed struct (u32) {
            address: u16,
            _reserved: u16,
        },
        descriptor: SetupDescriptorInfo,
        set_configuration: packed struct (u32) {
            configuration: u16,
            _reserved: u16,
        },
        get_interface: packed struct (u32) {
            _reserved: u16,
            interface: u16,
        },
        set_interface: packed struct (u32) {
            alternate_setting: u16,
            interface: u16,
        },
        synch_frame: packed struct (u32) {
            _reserved: u16,
            endpoint: u16,
        },
    },
    data_len: u16,
};

pub const Feature = enum (u16) {
    endpoint_halt = 0,
    device_remote_wakeup = 1,
    device_test_mode = 2,
    _
};

pub const SetupDescriptorInfo = packed struct (u32) {
    index: u8,
    kind: descriptor.Kind,
    language: u16,
};

pub const PID = enum (u1) {
    data0 = 0,
    data1 = 1,

    pub fn next(self: PID) PID {
        return switch (self) {
            .data0 => .data1,
            .data1 => .data0,
        };
    }
};
