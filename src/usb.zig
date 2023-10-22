// TODO add support for devices with more than one USB interface
// TODO support remote resume

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
pub const cdc_acm = @import("usb/cdc_acm.zig");

// Takes a struct that defines these functions:
//     fn getDeviceDescriptor() descriptor.Device
//     fn getStringDescriptor(id: descriptor.StringID, language: u16) []const u8
//     fn getConfigurationDescriptor(configuration: u8) descriptor.Configuration
//     fn getInterfaceDescriptor(configuration: u8, interface: u8) descriptor.Interface
//     fn getEndpointDescriptor(configuration: u8, interface: u8, index: u8) descriptor.Endpoint
//     fn getDescriptor(kind: descriptor.Kind, configuration: u8, index: u8) []const u8
//     fn isEndpointReady(address: endpoint.Address) bool
//     fn handleOutBuffer(ep: endpoint.Index, data: []volatile const u8) void
//
// As well as one or the other of:
//     fn getInBuffer(ep: endpoint.Index, max_packet_size: u16) []const u8
//     fn fillInBuffer(ep: endpoint.Index, data: []const u8) u16
//
// It may optionally also define:
//     fn handleBusReset() void
//     fn handleSetup(setup: SetupPacket) bool
//     fn getAllConfigurationDescriptors(configuration: u8) []const u8
//     fn getExtraConfigurationDescriptors(configuration: u8, interface: u8) []const descriptor.ID
//     fn setConfiguration(configuration: u8) void
//     fn isDeviceSelfPowered() bool // if not defined, assumes false
//     fn handleSetupOutBuffer(setup: SetupPacket, offset: u16, data: []volatile const u8, last_buffer: bool) bool
//     fn fillSetupIn(setup: SetupPacket) bool
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
//     fn startTransferIn(ep: endpoint.Index, len: u16, pid: PID, last_buffer: bool) void
//     fn startTransferOut(ep: endpoint.Index, len: u16, pid: PID, last_buffer: bool) void
//     fn startStall(address: endpoint.Address) void
//     fn startNak(address: endpoint.Address) void
pub fn Usb(comptime Cfg: anytype) type {
    return struct {
        const Self = @This();
        pub const Config = Cfg;

        setup_data_offset: u16 = 0,
        setup_data_bytes_remaining: u16 = 0,
        new_address: ?u7 = null, // After .set_address, we have to do an acknowledgement step using our old address, so the new address can't be applied immediately
        configuration: ?u8 = null, // The current configuration number, or null if the host hasn't yet selected one
        started: bool = false, // Have we set up buffer transfers after being configured?
        allow_remote_wakeup: bool = false, // allow device to request wakeup from suspend
        ep_state: [16]struct {
            in_max_packet_size_bytes: u16 = chip.usb.max_packet_size_bytes,
            out_max_packet_size_bytes: u16 = chip.usb.max_packet_size_bytes,
            next_pid: PID = .data0,
            halted: bool = false,
            in: EndpointState = .stalled,
            out: EndpointState = .stalled,
        } = undefined,

        const EndpointState = enum (u2) {
            waiting,
            active,
            stalled,
        };

        pub fn init(self: *Self) void {
            self.initState();
            chip.usb.init();
        }

        pub fn deinit(_: *Self) void {
            chip.usb.deinit();
        }

        fn initState(self: *Self) void {
            self.setup_data_offset = 0;
            self.setup_data_bytes_remaining = 0;
            self.new_address = null;
            self.configuration = null;
            self.started = false;
            self.allow_remote_wakeup = false;
            self.ep_state = .{ .{} } ** 16;
        }

        /// Call from main loop
        pub fn update(self: *Self) void {
            const events: Events = chip.usb.pollEvents();

            if (events.setup_request) self.handleSetup();

            if (events.buffer_ready) {
                var iter = chip.usb.bufferIterator();
                while (iter.next()) |info| {
                    self.updateBuffer(info);
                }
            }

            if (events.bus_reset) self.reset();

            if (!self.started) {
                if (self.configuration) |configuration| {
                    self.start(configuration);
                }
            }
        }

        fn start(self: *Self, configuration: u8) void {
            const cd: descriptor.Configuration = Config.getConfigurationDescriptor(configuration);
            for (0..cd.interface_count) |i| {
                const interface: u8 = @intCast(i);
                const id: descriptor.Interface = Config.getInterfaceDescriptor(configuration, interface);
                for (0..id.endpoint_count) |e| {
                    const ed: descriptor.Endpoint = Config.getEndpointDescriptor(configuration, interface, @intCast(e));
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

        fn reset(self: *Self) void {
            self.initState();
            chip.usb.handleBusReset();
            if (@hasDecl(Config, "handleBusReset")) {
                Config.handleBusReset();
            }
            log.info("bus reset", .{});
        }

        fn updateBuffer(self: *Self, info: endpoint.BufferInfo) void {
            const ep = info.address.ep;
            if (info.buffer.len > 0) {
                const final = if (info.final_buffer) " (final)" else "";
                log.debug("ep{} {s} transfer complete {}B{s}", .{ ep, @tagName(info.address.dir), info.buffer.len, final });
            }
            switch (info.address.dir) {
                .in => if (ep == 0) {
                    if (self.new_address) |addr| {
                        chip.usb.setAddress(addr);
                        log.debug("address changed to {}", .{ addr });
                        self.new_address = null;
                    }

                    if (info.final_buffer) {
                        if (self.setup_data_offset > 0) {
                            // empty status packet
                            self.setup_data_offset = 0;
                            self.setupTransferOut(0);
                        }
                    } else {
                        const setup = chip.usb.getSetupPacket();
                        if (setup.kind == .standard and setup.request == .get_descriptor) {
                            self.handleGetDescriptor(setup.getDescriptorPayload());
                        } else if (@hasDecl(Config, "fillSetupIn")) {
                            if (Config.fillSetupIn(setup)) {
                                self.setupTransferIn(self.setup_data_offset + self.setup_data_bytes_remaining);
                            } else {
                                chip.usb.startStall(.{ .ep = ep, .dir = .in });
                                log.err("ep0 in stalled (no data to send)", .{});
                            }
                        } else {
                            chip.usb.startStall(.{ .ep = ep, .dir = .in });
                            log.err("ep0 in stalled (no fillSetupIn)", .{});
                        }
                    }
                } else {
                    self.updateInState(ep);
                },
                .out => if (ep == 0) {
                    if (info.buffer.len > 0) {
                        const final = if (info.final_buffer) " (final)" else "";
                        log.debug("ep0 out data: {}{s}", .{ std.fmt.fmtSliceHexLower(@volatileCast(info.buffer)), final });
                        if (@hasDecl(Config, "handleSetupOutBuffer") and !Config.handleSetupOutBuffer(chip.usb.getSetupPacket(), self.setup_data_offset, info.buffer, info.final_buffer)) {
                            log.err("ep0 out not handled: {}", .{ std.fmt.fmtSliceHexLower(@volatileCast(info.buffer)) });
                        }
                    }

                    const expected = self.setup_data_bytes_remaining;
                    const len = @min(expected, info.buffer.len);
                    self.setup_data_offset += len;
                    self.setup_data_bytes_remaining -= len;

                    if (info.final_buffer) {
                        if (self.setup_data_offset > 0) {
                            // empty status packet
                            self.setup_data_offset = 0;
                            self.setupTransferIn(0);
                        }
                    } else {
                        self.setupTransferOut(self.setup_data_offset + self.setup_data_bytes_remaining);
                    }
                } else {
                    if (info.buffer.len > 0) {
                        Config.handleOutBuffer(ep, info.buffer);
                        log.info("ep{} out: {}", .{ ep, std.fmt.fmtSliceHexLower(@volatileCast(info.buffer)) });
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
                    log.info("ep{} in stalled...", .{ ep });
                }
            } else if (!Config.isEndpointReady(.{ .ep = ep, .dir = .in })) {
                if (state.in != .waiting) {
                    chip.usb.startNak(.{ .ep = ep, .dir = .in });
                    self.ep_state[ep].in = .waiting;
                    log.debug("ep{} in waiting...", .{ ep });
                }
            } else {
                if (@hasDecl(Config, "getInBuffer")) {
                    const data: []const u8 = Config.getInBuffer(ep, state.in_max_packet_size_bytes);
                    chip.usb.fillBufferIn(ep, 0, data);
                    chip.usb.startTransferIn(ep, data.len, state.next_pid, data.len < state.in_max_packet_size_bytes);
                    log.info("ep{} in: {}", .{ ep, std.fmt.fmtSliceHexLower(data) });
                } else {
                    var data: [chip.usb.max_packet_size_bytes]u8 = undefined;
                    const len = Config.fillInBuffer(ep, data[0..state.in_max_packet_size_bytes]);
                    chip.usb.fillBufferIn(ep, 0, data[0..len]);
                    chip.usb.startTransferIn(ep, len, state.next_pid, len < state.in_max_packet_size_bytes);
                    log.info("ep{} in: {}", .{ ep, std.fmt.fmtSliceHexLower(data[0..len]) });
                }
                self.ep_state[ep].in = .active;
                self.ep_state[ep].next_pid = state.next_pid.next();
            }
        }

        fn updateOutState(self: *Self, ep: endpoint.Index) void {
            const state = self.ep_state[ep];
            if (state.halted) {
                if (state.out != .stalled) {
                    chip.usb.startStall(.{ .ep = ep, .dir = .out });
                    self.ep_state[ep].out = .stalled;
                    log.info("ep{} out stalled...", .{ ep });
                }
            } else if (!Config.isEndpointReady(.{ .ep = ep, .dir = .out })) {
                if (state.out != .waiting) {
                    chip.usb.startNak(.{ .ep = ep, .dir = .out });
                    self.ep_state[ep].out = .waiting;
                    log.debug("ep{} out waiting...", .{ ep });
                }
            } else {
                chip.usb.startTransferOut(ep, state.out_max_packet_size_bytes, state.next_pid, false);
                self.ep_state[ep].out = .active;
                self.ep_state[ep].next_pid = state.next_pid.next();
                log.debug("ep{} out started", .{ ep });
            }
        }

        fn handleSetup(self: *Self) void {
            self.ep_state[0].next_pid = .data1;
            const setup: SetupPacket = chip.usb.getSetupPacket();
            log.debug("{any}", .{ setup });
            self.setup_data_offset = 0;
            self.setup_data_bytes_remaining = setup.data_len;
            var handled = false;
            if (setup.kind == .standard) switch (setup.request) {
                .set_address => if (setup.direction == .out) {
                    const address = setup.getAddressPayload();
                    self.new_address = address;
                    log.info("set address: {}", .{ address });
                    self.setupTransferIn(0);
                    handled = true;
                },
                .set_configuration => if (setup.direction == .out) {
                    const configuration = setup.getConfigurationNumberPayload();
                    self.configuration = configuration;
                    if (@hasDecl(Config, "setConfiguration")) {
                        Config.setConfiguration(configuration);
                    }
                    log.info("set configuration: {}", .{ configuration });
                    self.setupTransferIn(0);
                    handled = true;
                },
                .get_configuration => if (setup.direction == .in) {
                    const c: u16 = self.configuration orelse 0;
                    self.setupTransferInData(std.mem.asBytes(&c));
                    log.info("get configuration", .{});
                    handled = true;
                },
                .get_descriptor => if (setup.direction == .in) {
                    self.handleGetDescriptor(setup.getDescriptorPayload());
                    handled = true;
                },
                .get_status => if (setup.direction == .in) {
                    var status: u16 = 0;
                    switch (setup.target) {
                        .device => {
                            if (@hasDecl(Config, "isDeviceSelfPowered") and Config.isDeviceSelfPowered()) status |= 1;
                            if (self.allow_remote_wakeup) status |= 2;
                        },
                        .interface => {
                            const interface: u8 = setup.getInterfaceNumberPayload();
                            log.info("get interface {} status", .{ interface });
                        },
                        .endpoint => {
                            const ep: endpoint.Index = @intCast(setup.getEndpointNumberPayload());
                            if (self.ep_state[ep].halted) status |= 1;
                            log.info("get endpoint {} status", .{ ep });
                        },
                        else => {
                            log.err("get status for unrecognized target: {}", .{ @intFromEnum(setup.target) });
                        },
                    }
                    self.setupTransferInData(std.mem.asBytes(&status));
                    handled = true;
                },
                .set_feature, .clear_feature => if (setup.direction == .out) {
                    self.setupTransferIn(0);
                    const f = setup.getFeaturePayload();
                    switch (f.feature) {
                        .endpoint_halt => if (setup.target == .endpoint) {
                            const ep: endpoint.Index = @intCast(f.endpoint);
                            self.ep_state[ep].halted = setup.request == .set_feature;
                        },
                        .device_remote_wakeup => if (setup.target == .device) {
                            self.allow_remote_wakeup = setup.request == .set_feature;
                        },
                        else => {},
                    }
                    log.info("{s}: target = {s}, ep = {}, feature = {}", .{
                        @tagName(setup.kind),
                        @tagName(setup.target),
                        f.endpoint,
                        f.feature,
                    });
                    handled = true;
                },
                else => {},
            };

            if (@hasDecl(Config, "handleSetup")) {
                if (Config.handleSetup(setup)) handled = true;
            }

            if (!handled) {
                log.err("unrecognized setup: {s}, request = {}", .{
                    @tagName(setup.direction),
                    @intFromEnum(setup.request)
                });
            }
        }

        fn handleGetDescriptor(self: *Self, which: SetupPacket.DescriptorPayload) void {
            switch (which.kind) {
                .device => {
                    if (self.setup_data_offset == 0) {
                        log.info("get device descriptor {}B", .{ self.setup_data_bytes_remaining });
                    }
                    const d: descriptor.Device = Config.getDeviceDescriptor();
                    self.setupTransferInData(std.mem.asBytes(&d)[0..d._len]);
                },
                .device_qualifier => {
                    if (self.setup_data_offset == 0) {
                        log.info("get device qualifier {}B", .{ self.setup_data_bytes_remaining });
                    }
                    const d: descriptor.Device = Config.getDeviceDescriptor();
                    const dq: descriptor.DeviceQualifier = .{
                        .usb_version = d.usb_version,
                        .class = d.class,
                        .max_packet_size_bytes = d.max_packet_size_bytes,
                        .configuration_count = d.configuration_count,
                    };
                    self.setupTransferInData(std.mem.asBytes(&dq)[0..dq._len]);
                },
                .string => {
                    const id: descriptor.StringID = @enumFromInt(which.index);
                    if (self.setup_data_offset == 0) {
                        log.info("get string {}B: id = {}, lang = {}", .{ self.setup_data_bytes_remaining, id, which.language });
                    }
                    self.setupTransferInData(Config.getStringDescriptor(id, which.language));
                },
                .endpoint => {
                    // USB hosts should never ask for endpoint descriptors directly, because
                    // there's no way to know which interface it's querying, so we just ignore it.
                    if (self.setup_data_offset == 0) {
                        log.info("get endpoint descriptor {}B: index = {}", .{ self.setup_data_bytes_remaining, which.index });
                    }
                },
                .configuration => {
                    const configuration = self.configuration orelse 0;
                    if (self.setup_data_offset == 0) {
                        log.info("get configuration descriptor {}B: {}", .{ self.setup_data_bytes_remaining, configuration });
                    }

                    if (@hasDecl(Config, "getAllConfigurationDescriptors")) {
                        self.setupTransferInData(Config.getAllConfigurationDescriptors(configuration));
                    } else {
                        var offset: u16 = 0;
                        const cd: descriptor.Configuration = Config.getConfigurationDescriptor(configuration);
                        offset = self.fillSetupIn(offset, std.mem.asBytes(&cd)[0..cd._len]);

                        for (0..cd.interface_count) |i| {
                            offset = self.fillInterfaceDescriptor(configuration, @intCast(i), @intCast(offset));
                        }
                        self.setupTransferIn(offset);
                    }
                },
                .interface => {
                    const configuration = self.configuration orelse 0;
                    if (self.setup_data_offset == 0) {
                        log.info("get interface descriptor {}B: config = {}, interface = {}", .{
                            self.setup_data_bytes_remaining,
                            configuration,
                            which.index,
                        });
                    }
                    const offset = self.fillInterfaceDescriptor(configuration, @intCast(which.index), 0);
                    self.setupTransferIn(offset);
                },
                else => {
                    const configuration = self.configuration orelse 0;
                    if (self.setup_data_offset == 0) {
                        log.info("get descriptor {}B: config = {}, kind = 0x{X}, index = {}", .{
                            self.setup_data_bytes_remaining,
                            configuration,
                            which.kind,
                            which.index,
                        });
                    }
                    self.setupTransferInData(Config.getDescriptor(which.kind, configuration, which.index));
                },
            }
        }

        fn fillInterfaceDescriptor(self: *Self, configuration: u8, interface: u8, data_offset: u16) u16 {
            var offset = data_offset;

            const id: descriptor.Interface = Config.getInterfaceDescriptor(configuration, interface);
            offset = self.fillSetupIn(offset, std.mem.asBytes(&id)[0..id._len]);

            for (0..id.endpoint_count) |e| {
                const ed: descriptor.Endpoint = Config.getEndpointDescriptor(configuration, interface, @intCast(e));
                offset = self.fillSetupIn(offset, std.mem.asBytes(&ed)[0..ed._len]);
            }

            if (@hasDecl(Config, "getExtraConfigurationDescriptors")) {
                for (Config.getExtraConfigurationDescriptors(configuration, interface)) |desc| {
                    offset = self.fillSetupIn(offset, Config.getDescriptor(desc.kind, configuration, desc.index));
                }
            }

            return offset;
        }

        pub fn fillSetupIn(self: *Self, offset: u16, data: []const u8) u16 {
            const data_offset_isize: isize = offset;
            const setup_offset_isize: isize = self.setup_data_offset;
            chip.usb.fillBufferIn(0, data_offset_isize - setup_offset_isize, data);
            const data_len_u16: u16 = @intCast(data.len);
            log.debug("ep0 in data @{}: {}", .{ data_offset_isize - setup_offset_isize, std.fmt.fmtSliceHexLower(data) });
            return offset + data_len_u16;
        }

        pub fn setupTransferInData(self: *Self, data: []const u8) void {
            self.setupTransferIn(self.fillSetupIn(0, data));
        }

        pub fn setupTransferIn(self: *Self, total_len: u16) void {
            const pid = self.ep_state[0].next_pid;
            const max_packet_size = self.ep_state[0].in_max_packet_size_bytes;
            if (total_len < self.setup_data_bytes_remaining) {
                self.setup_data_bytes_remaining = total_len;
            }
            var len = @min(self.setup_data_bytes_remaining, total_len - self.setup_data_offset);
            if (len > max_packet_size) {
                len = max_packet_size;
            }
            chip.usb.startTransferIn(0, len, pid, len < max_packet_size);
            log.debug("ep0 in {}B {s}", .{ len, @tagName(pid) });
            self.setup_data_offset += len;
            self.setup_data_bytes_remaining -= len;
            self.ep_state[0].next_pid = pid.next();
        }

        pub fn setupTransferOut(self: *Self, total_len: u16) void {
            const pid = self.ep_state[0].next_pid;
            const max_packet_size = self.ep_state[0].out_max_packet_size_bytes;
            var len = @min(self.setup_data_bytes_remaining, total_len - self.setup_data_offset);
            if (len > max_packet_size) {
                len = max_packet_size;
            }
            chip.usb.startTransferOut(0, len, pid, len < max_packet_size);
            log.debug("ep0 out {}B {s}", .{ len, @tagName(pid) });
            self.ep_state[0].next_pid = pid.next();
        }

    };
}

pub const Events = struct {
    buffer_ready: bool = false,
    bus_reset: bool = false,
    setup_request: bool = false,
};

pub const SetupRequestKind = enum (u8) {
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
    request: SetupRequestKind,
    payload: u32,
    data_len: u16,

    pub fn getAddressPayload(self: SetupPacket) u7 {
        std.debug.assert(self.request == .set_address);
        const payload: packed struct (u32) {
            address: u16,
            _reserved: u16,
        } = @bitCast(self.payload);
        return @truncate(payload.address);
    }

    pub const DescriptorPayload = packed struct (u32) {
        index: u8,
        kind: descriptor.Kind,
        language: u16,
    };
    pub fn getDescriptorPayload(self: SetupPacket) DescriptorPayload {
        std.debug.assert(self.request == .get_descriptor or self.request == .set_descriptor);
        return @bitCast(self.payload);
    }

    pub const FeaturePayload = packed struct (u32) { feature: Feature, endpoint: u16 };
    pub fn getFeaturePayload(self: SetupPacket) FeaturePayload {
        std.debug.assert(self.request == .clear_feature or self.request == .set_feature);
        return @bitCast(self.payload);
    }

    pub fn getConfigurationNumberPayload(self: SetupPacket) u8 {
        std.debug.assert(switch(self.request) {
            .set_configuration => true,

            .clear_feature, .set_feature,
            .get_descriptor, .set_descriptor,
            .get_configuration, .get_status,
            .get_interface, .set_interface,
            .synch_frame, .set_address => false,

            _ => true,
        });
        const payload: packed struct (u32) {
            configuration: u16,
            _reserved: u16,
        } = @bitCast(self.payload);
        return @truncate(payload.configuration);
    }

    pub fn getInterfaceNumberPayload(self: SetupPacket) u8 {
        std.debug.assert(switch(self.request) {
            .get_interface => true,
            .get_status => self.target == .interface,

            .clear_feature, .set_feature,
            .get_descriptor, .set_descriptor,
            .get_configuration, .set_configuration,
            .set_interface, .synch_frame, .set_address => false,

            _ => true,
        });
        const payload: packed struct (u32) {
            _reserved: u16,
            interface: u16,
        } = @bitCast(self.payload);
        return @truncate(payload.interface);
    }

    pub const SetInterfacePayload = packed struct (u32) { alternate_setting: u16, interface: u16 };
    pub fn getSetInterfacePayload(self: SetupPacket) SetInterfacePayload {
        std.debug.assert(self.request == .set_interface);
        return @bitCast(self.payload);
    }

    pub fn getEndpointNumberPayload(self: SetupPacket) u8 {
        std.debug.assert(switch(self.request) {
            .synch_frame => true,
            .get_status => self.target == .endpoint,

            .clear_feature, .set_feature,
            .get_descriptor, .set_descriptor,
            .get_configuration, .set_configuration,
            .get_interface, .set_interface, 
            .set_address => false,

            _ => true,
        });
        std.debug.assert(self.request == .synch_frame or self.request == .get_status and self.target == .endpoint);
        const payload: packed struct (u32) {
            _reserved: u16,
            endpoint: u16,
        } = @bitCast(self.payload);
        return @truncate(payload.endpoint);
    }
};

pub const Feature = enum (u16) {
    endpoint_halt = 0,
    device_remote_wakeup = 1,
    device_test_mode = 2,
    _
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
