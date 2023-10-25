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

/// See `usb/config_template.zig` for how to integrate USB in a project
/// See `usb/chip_template.zig` for how to use this with new USB hardware
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
            next_in_pid: PID = .data0,
            next_out_pid: PID = .data0,
            in: EndpointState = .stalled,
            out: EndpointState = .stalled,
            halted: bool = false,
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

            if (events.start_of_frame) {
                Config.handleStartOfFrame();
            }

            if (events.buffer_ready) {
                var iter = chip.usb.bufferIterator();
                while (iter.next()) |info| {
                    self.updateBuffer(info, events.setup_request);
                }
            }

            if (events.setup_request) self.handleSetup();

            if (events.bus_reset) self.reset();

            if (!self.started) {
                if (self.configuration) |configuration| {
                    self.start(configuration);
                }
            }
        }

        fn start(self: *Self, configuration: u8) void {
            for (0..Config.getInterfaceCount(configuration)) |i| {
                const interface: u8 = @intCast(i);
                for (0..Config.getEndpointCount(configuration, interface)) |e| {
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
            Config.handleBusReset();
            log.info("bus reset", .{});
        }

        fn updateBuffer(self: *Self, info: endpoint.BufferInfo, setup_pending: bool) void {
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

                    if (!setup_pending) {
                        if (info.final_buffer) {
                            if (self.setup_data_offset > 0) self.setupStatusOut();
                        } else {
                            const setup = chip.usb.getSetupPacket();
                            if (setup.kind == .standard and setup.request == .get_descriptor) {
                                self.handleGetDescriptor(setup);
                            } else if (Config.fillSetupIn(setup)) {
                                self.setupTransferIn(self.setup_data_offset + self.setup_data_bytes_remaining);
                            } else {
                                chip.usb.startStall(.{ .ep = ep, .dir = .in });
                                log.err("ep0 in stalled (no data to send)", .{});
                            }
                        }
                    }
                } else {
                    self.updateInState(ep);
                },
                .out => if (ep == 0) {
                    if (info.buffer.len > 0) {
                        const final = if (info.final_buffer) " (final)" else "";
                        log.debug("ep0 out data: {}{s}", .{ std.fmt.fmtSliceHexLower(@volatileCast(info.buffer)), final });
                        if (!Config.handleSetupOutBuffer(chip.usb.getSetupPacket(), self.setup_data_offset, info.buffer, info.final_buffer)) {
                            log.err("ep0 out not handled: {}", .{ std.fmt.fmtSliceHexLower(@volatileCast(info.buffer)) });
                        }
                    }

                    const expected = self.setup_data_bytes_remaining;
                    const len = @min(expected, info.buffer.len);
                    self.setup_data_offset += len;
                    self.setup_data_bytes_remaining -= len;

                    if (info.final_buffer) {
                        if (self.setup_data_offset > 0) self.setupStatusIn();
                    } else {
                        self.setupTransferOut(self.setup_data_offset + self.setup_data_bytes_remaining);
                    }
                } else {
                    if (info.buffer.len > 0) {
                        Config.handleOutBuffer(ep, info.buffer);
                        log.debug("ep{} out: {}", .{ ep, std.fmt.fmtSliceHexLower(@volatileCast(info.buffer)) });
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
                    chip.usb.startTransferIn(ep, data.len, state.next_in_pid, data.len < state.in_max_packet_size_bytes);
                    log.debug("ep{} in: {}", .{ ep, std.fmt.fmtSliceHexLower(data) });
                } else {
                    var data: [chip.usb.max_packet_size_bytes]u8 = undefined;
                    const len = Config.fillInBuffer(ep, data[0..state.in_max_packet_size_bytes]);
                    chip.usb.fillBufferIn(ep, 0, data[0..len]);
                    chip.usb.startTransferIn(ep, len, state.next_in_pid, len < state.in_max_packet_size_bytes);
                    log.debug("ep{} in: {}", .{ ep, std.fmt.fmtSliceHexLower(data[0..len]) });
                }
                self.ep_state[ep].in = .active;
                self.ep_state[ep].next_in_pid = state.next_in_pid.next();
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
                chip.usb.startTransferOut(ep, state.out_max_packet_size_bytes, state.next_out_pid, false);
                self.ep_state[ep].out = .active;
                self.ep_state[ep].next_in_pid = state.next_in_pid.next();
                log.debug("ep{} out started", .{ ep });
            }
        }

        fn handleSetup(self: *Self) void {
            self.ep_state[0].next_in_pid = .data1;
            self.ep_state[0].next_out_pid = .data1;
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
                    self.setupStatusIn();
                    handled = true;
                },
                .set_configuration => if (setup.direction == .out) {
                    const configuration = setup.getConfigurationNumberPayload();
                    self.configuration = configuration;
                    Config.handleConfigurationChanged(configuration);
                    log.info("set configuration: {}", .{ configuration });
                    self.setupStatusIn();
                    handled = true;
                },
                .get_configuration => if (setup.direction == .in) {
                    const c: u16 = self.configuration orelse 0;
                    self.setupTransferInData(std.mem.asBytes(&c));
                    log.info("get configuration", .{});
                    handled = true;
                },
                .get_descriptor => if (setup.direction == .in) {
                    self.handleGetDescriptor(setup);
                    handled = true;
                },
                .get_status => if (setup.direction == .in) {
                    var status: u16 = 0;
                    switch (setup.target) {
                        .device => {
                            if (Config.isDeviceSelfPowered()) status |= 1;
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
                    self.setupStatusIn();
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

            if (Config.handleSetup(setup)) handled = true;

            if (!handled) {
                log.err("unrecognized setup: {s}, request = {}", .{
                    @tagName(setup.direction),
                    @intFromEnum(setup.request)
                });
            }
        }

        fn handleGetDescriptor(self: *Self, setup: SetupPacket) void {
            const which = setup.getDescriptorPayload();
            switch (setup.target) {
                .device => switch (which.kind) {
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
                        if (Config.getStringDescriptor(id, which.language)) |data| {
                            self.setupTransferInData(data[0..data[0]]);
                        } else if (self.setup_data_offset == 0) {
                            log.warn("request for invalid string descriptor: id = {}, lang = {}", .{ id, which.language });
                        }
                    },
                    .interface => {
                        // USB hosts should always request interface descriptors indirectly as part of the configuration descriptor set.
                        if (self.setup_data_offset == 0) {
                            log.info("get interface descriptor {}B: index = {}", .{ self.setup_data_bytes_remaining, which.index });
                        }
                    },
                    .endpoint => {
                        // USB hosts should always request endpoint descriptors indirectly as part of the configuration descriptor set.
                        if (self.setup_data_offset == 0) {
                            log.info("get endpoint descriptor {}B: index = {}", .{ self.setup_data_bytes_remaining, which.index });
                        }
                    },
                    .configuration => {
                        if (self.setup_data_offset == 0) {
                            log.info("get configuration descriptor {}B: {}", .{ self.setup_data_bytes_remaining, which.index });
                        }
                        if (Config.getConfigurationDescriptorSet(which.index)) |data| {
                            self.setupTransferInData(data[0..data[0]]);
                        } else if (self.setup_data_offset == 0) {
                            log.warn("request for invalid configuration descriptor: {}", .{ which.index });
                        }
                    },
                    else => {
                        if (self.setup_data_offset == 0) {
                            log.info("get descriptor {}B: descriptor = 0x{X} {}", .{ self.setup_data_bytes_remaining, @intFromEnum(which.kind), which.index });
                        }
                        if (Config.getDescriptor(which.kind, which.index)) |data| {
                            self.setupTransferInData(data[0..data[0]]);
                        } else if (self.setup_data_offset == 0) {
                            log.warn("request for invalid descriptor: 0x{X} {}", .{ @intFromEnum(which.kind), which.index });
                        }
                    }
                },
                .interface => {
                    if (self.setup_data_offset == 0) {
                        log.info("get interface-specific descriptor {}B: interface = {}, descriptor = 0x{X} {}", .{
                            self.setup_data_bytes_remaining,
                            which.language, // really interface
                            @intFromEnum(which.kind),
                            which.index,
                        });
                    }
                    if (Config.getInterfaceSpecificDescriptor(@intCast(@intFromEnum(which.language)), which.kind, which.index)) |data| {
                        self.setupTransferInData(data[0..data[0]]);
                    } else if (self.setup_data_offset == 0) {
                        log.warn("request for invalid interface-specific descriptor: interface = {}, descriptor = 0x{X} {}", .{
                            which.language, // really interface
                            @intFromEnum(which.kind),
                            which.index,
                        });
                    }
                },
                .endpoint => {
                    if (self.setup_data_offset == 0) {
                        log.info("get endpoint-specific descriptor {}B: endpoint = {}, descriptor = 0x{X} {}", .{
                            self.setup_data_bytes_remaining,
                            which.language, // really endpoint
                            @intFromEnum(which.kind),
                            which.index,
                        });
                    }
                    if (Config.getEndpointSpecificDescriptor(@intCast(@intFromEnum(which.language)), which.kind, which.index)) |data| {
                        self.setupTransferInData(data[0..data[0]]);
                    } else if (self.setup_data_offset == 0) {
                        log.warn("request for invalid endpoint-specific descriptor: endpoint = {}, descriptor = 0x{X} {}", .{
                            which.language, // really endpoint
                            @intFromEnum(which.kind),
                            which.index,
                        });
                    }
                },
                else => {
                    if (self.setup_data_offset == 0) {
                        log.warn("invalid get descriptor {}B: target = {}, target_index = {}, descriptor = 0x{X} {}", .{
                            self.setup_data_bytes_remaining,
                            @intFromEnum(setup.target),
                            which.language,
                            which.kind,
                            which.index,
                        });
                    }
                },
            }
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
            const pid = self.ep_state[0].next_in_pid;
            const max_packet_size = self.ep_state[0].in_max_packet_size_bytes;
            if (total_len < self.setup_data_bytes_remaining) {
                self.setup_data_bytes_remaining = total_len;
            }
            var len = @min(self.setup_data_bytes_remaining, total_len - self.setup_data_offset);
            if (len > max_packet_size) {
                len = max_packet_size;
            }
            chip.usb.startTransferIn(0, len, pid, len < max_packet_size);
            const final = if (len < max_packet_size) " (final)" else "";
            log.debug("ep0 in {}B {s}{s}", .{ len, @tagName(pid), final });
            self.setup_data_offset += len;
            self.setup_data_bytes_remaining -= len;
            self.ep_state[0].next_in_pid = pid.next();
        }

        pub fn setupTransferOut(self: *Self, total_len: u16) void {
            const pid = self.ep_state[0].next_out_pid;
            const max_packet_size = self.ep_state[0].out_max_packet_size_bytes;
            var len = @min(self.setup_data_bytes_remaining, total_len - self.setup_data_offset);
            if (len > max_packet_size) {
                len = max_packet_size;
            }
            chip.usb.startTransferOut(0, len, pid, len < max_packet_size);
            const final = if (len < max_packet_size) " (final)" else "";
            log.debug("ep0 out {}B {s}{s}", .{ len, @tagName(pid), final });
            self.ep_state[0].next_out_pid = pid.next();
        }

        pub fn setupStatusIn(self: *Self) void {
            self.setup_data_offset = 0;
            self.setup_data_bytes_remaining = 0;
            self.ep_state[0].next_out_pid = .data1;
            @call(.always_inline, setupTransferIn, .{ self, 0 });
        }

        pub fn setupStatusOut(self: *Self) void {
            self.setup_data_offset = 0;
            self.setup_data_bytes_remaining = 0;
            self.ep_state[0].next_out_pid = .data1;
            @call(.always_inline, setupTransferOut, .{ self, 0 });
        }

    };
}

pub const Events = struct {
    start_of_frame: bool = false,
    buffer_ready: bool = false,
    bus_reset: bool = false,
    setup_request: bool = false,
};

pub const SetupTarget = enum (u5) {
    device = 0,
    interface = 1,
    endpoint = 2,
    other = 3,
    _,
};

pub const SetupKind = enum (u2) {
    standard = 0,
    class = 1,
    vendor = 2,
    _,
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
    target: SetupTarget,
    kind: SetupKind,
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
        language: descriptor.Language,
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
