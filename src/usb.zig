// TODO add support for devices with more than one USB interface
// TODO support remote resume

comptime {
    std.debug.assert(@import("builtin").cpu.arch.endian() == .little);
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
pub fn USB(comptime Cfg: anytype) type {
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
            in: Endpoint_State = .stalled,
            out: Endpoint_State = .stalled,
            in_halted: bool = false,
            out_halted: bool = false,
        } = undefined,

        const Endpoint_State = enum (u2) {
            waiting,
            active,
            stalled,
        };

        pub fn init(self: *Self) void {
            self.init_state();
            chip.usb.init();
        }

        pub fn deinit(_: *Self) void {
            chip.usb.deinit();
        }

        fn init_state(self: *Self) void {
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
            const events: Events = chip.usb.poll_events();

            if (events.start_of_frame) {
                Config.handle_start_of_frame();
            }

            if (events.buffer_ready) {
                var iter = chip.usb.buffer_iterator();
                while (iter.next()) |info| {
                    self.update_buffer(info, events.setup_request);
                }
            }

            if (events.setup_request) self.handle_setup();

            if (events.bus_reset) self.reset();

            if (!self.started) {
                if (self.configuration) |configuration| {
                    self.start(configuration);
                }
            }
        }

        fn start(self: *Self, configuration: u8) void {
            for (0..Config.get_interface_count(configuration)) |i| {
                const interface: u8 = @intCast(i);
                for (0..Config.get_endpoint_count(configuration, interface)) |e| {
                    const ed: descriptor.Endpoint = Config.get_endpoint_descriptor(configuration, interface, @intCast(e));
                    chip.usb.configure_endpoint(ed);
                    log.info("initialized endpoint: ep{} {s}, {s}, {}B, {}ms", .{
                        ed.address.ep,
                        @tagName(ed.address.dir),
                        @tagName(ed.transfer_kind),
                        ed.max_packet_size_bytes,
                        ed.poll_interval_ms,
                    });

                    const ep = ed.address.ep;
                    if (ep == 0) continue;

                    switch (ed.address.dir) {
                        .out => {
                            self.ep_state[ep].out_halted = false;
                            self.ep_state[ep].out_max_packet_size_bytes = ed.max_packet_size_bytes;
                            self.update_out_state(ep);
                        },
                        .in => {
                            self.ep_state[ep].in_halted = false;
                            self.ep_state[ep].in_max_packet_size_bytes = ed.max_packet_size_bytes;
                            self.update_in_state(ep);
                        },
                    } 
                }
            }
            self.started = true;
        }

        fn reset(self: *Self) void {
            self.init_state();
            chip.usb.handle_bus_reset();
            Config.handle_bus_reset();
            log.info("bus reset", .{});
        }

        fn update_buffer(self: *Self, info: endpoint.Buffer_Info, setup_pending: bool) void {
            const ep = info.address.ep;
            if (info.buffer.len > 0) {
                const final = if (info.final_buffer) " (final)" else "";
                log.debug("ep{} {s} transfer complete {}B{s}", .{ ep, @tagName(info.address.dir), info.buffer.len, final });
            }
            switch (info.address.dir) {
                .in => if (ep == 0) {
                    if (self.new_address) |addr| {
                        chip.usb.set_address(addr);
                        log.debug("address changed to {}", .{ addr });
                        self.new_address = null;
                    }

                    if (!setup_pending) {
                        if (info.final_buffer) {
                            if (self.setup_data_offset > 0) self.setup_status_out();
                        } else {
                            const setup = chip.usb.get_setup_packet();
                            if (setup.kind == .standard and setup.request == .get_descriptor) {
                                self.handle_get_descriptor(setup);
                            } else if (Config.fill_setup_in(setup)) {
                                self.setup_transfer_in(self.setup_data_offset + self.setup_data_bytes_remaining);
                            } else {
                                chip.usb.start_stall(.{ .ep = ep, .dir = .in });
                                log.err("ep0 in stalled (no data to send)", .{});
                            }
                        }
                    }
                } else {
                    self.update_in_state(ep);
                },
                .out => if (ep == 0) {
                    if (info.buffer.len > 0) {
                        const final = if (info.final_buffer) " (final)" else "";
                        log.debug("ep0 out data: {}{s}", .{ std.fmt.fmtSliceHexLower(@volatileCast(info.buffer)), final });
                        if (!Config.handle_setup_out_buffer(chip.usb.get_setup_packet(), self.setup_data_offset, info.buffer, info.final_buffer)) {
                            log.err("ep0 out not handled: {}", .{ std.fmt.fmtSliceHexLower(@volatileCast(info.buffer)) });
                        }
                    }

                    const expected = self.setup_data_bytes_remaining;
                    const len = @min(expected, info.buffer.len);
                    self.setup_data_offset += len;
                    self.setup_data_bytes_remaining -= len;

                    if (info.final_buffer) {
                        if (self.setup_data_offset > 0) self.setup_status_in();
                    } else {
                        self.setup_transfer_out(self.setup_data_offset + self.setup_data_bytes_remaining);
                    }
                } else {
                    if (info.buffer.len > 0) {
                        Config.handle_out_buffer(ep, info.buffer);
                        log.debug("ep{} out: {}", .{ ep, std.fmt.fmtSliceHexLower(@volatileCast(info.buffer)) });
                    }
                    self.update_out_state(ep);
                },
            }
        }

        fn update_in_state(self: *Self, ep: endpoint.Index) void {
            const state = self.ep_state[ep];
            if (state.in_halted) {
                if (state.in != .stalled) {
                    chip.usb.start_stall(.{ .ep = ep, .dir = .in });
                    self.ep_state[ep].in = .stalled;
                    log.info("ep{} in stalled...", .{ ep });
                }
            } else if (!Config.is_endpoint_ready(.{ .ep = ep, .dir = .in })) {
                if (state.in != .waiting) {
                    chip.usb.start_nak(.{ .ep = ep, .dir = .in });
                    self.ep_state[ep].in = .waiting;
                    log.debug("ep{} in waiting...", .{ ep });
                }
            } else {
                if (@hasDecl(Config, "getInBuffer")) {
                    const data: []const u8 = Config.getInBuffer(ep, state.in_max_packet_size_bytes);
                    chip.usb.fill_buffer_in(ep, 0, data);
                    chip.usb.start_transfer_in(ep, data.len, state.next_in_pid, data.len < state.in_max_packet_size_bytes);
                    log.debug("ep{} in: {}", .{ ep, std.fmt.fmtSliceHexLower(data) });
                } else {
                    var data: [chip.usb.max_packet_size_bytes]u8 = undefined;
                    const len = Config.fill_in_buffer(ep, data[0..state.in_max_packet_size_bytes]);
                    chip.usb.fill_buffer_in(ep, 0, data[0..len]);
                    chip.usb.start_transfer_in(ep, len, state.next_in_pid, len < state.in_max_packet_size_bytes);
                    log.debug("ep{} in: {}", .{ ep, std.fmt.fmtSliceHexLower(data[0..len]) });
                }
                self.ep_state[ep].in = .active;
                self.ep_state[ep].next_in_pid = state.next_in_pid.next();
            }
        }

        fn update_out_state(self: *Self, ep: endpoint.Index) void {
            const state = self.ep_state[ep];
            if (state.out_halted) {
                if (state.out != .stalled) {
                    chip.usb.start_stall(.{ .ep = ep, .dir = .out });
                    self.ep_state[ep].out = .stalled;
                    log.info("ep{} out stalled...", .{ ep });
                }
            } else if (!Config.is_endpoint_ready(.{ .ep = ep, .dir = .out })) {
                if (state.out != .waiting) {
                    chip.usb.start_nak(.{ .ep = ep, .dir = .out });
                    self.ep_state[ep].out = .waiting;
                    log.debug("ep{} out waiting...", .{ ep });
                }
            } else {
                chip.usb.start_transfer_out(ep, state.out_max_packet_size_bytes, state.next_out_pid, false);
                self.ep_state[ep].out = .active;
                self.ep_state[ep].next_out_pid = state.next_out_pid.next();
                log.debug("ep{} out started", .{ ep });
            }
        }

        fn handle_setup(self: *Self) void {
            self.ep_state[0].next_in_pid = .data1;
            self.ep_state[0].next_out_pid = .data1;
            const setup: Setup_Packet = chip.usb.get_setup_packet();
            log.debug("{any}", .{ setup });
            self.setup_data_offset = 0;
            self.setup_data_bytes_remaining = setup.data_len;
            var handled = false;
            if (setup.kind == .standard) switch (setup.request) {
                .set_address => if (setup.direction == .out) {
                    const address = setup.get_address_payload();
                    self.new_address = address;
                    log.info("set address: {}", .{ address });
                    self.setup_status_in();
                    handled = true;
                },
                .set_configuration => if (setup.direction == .out) {
                    const configuration = setup.get_configuration_number_payload();
                    self.configuration = configuration;
                    Config.handle_configuration_changed(configuration);
                    log.info("set configuration: {}", .{ configuration });
                    self.setup_status_in();
                    handled = true;
                },
                .get_configuration => if (setup.direction == .in) {
                    const c: u16 = self.configuration orelse 0;
                    self.setup_transfer_in_data(std.mem.asBytes(&c));
                    log.info("get configuration", .{});
                    handled = true;
                },
                .get_descriptor => if (setup.direction == .in) {
                    self.handle_get_descriptor(setup);
                    handled = true;
                },
                .get_status => if (setup.direction == .in) {
                    var status: u16 = 0;
                    switch (setup.target) {
                        .device => {
                            if (Config.is_device_self_powered()) status |= 1;
                            if (self.allow_remote_wakeup) status |= 2;
                        },
                        .interface => {
                            const interface: u8 = setup.get_interface_number_payload();
                            log.info("get interface {} status", .{ interface });
                        },
                        .endpoint => {
                            const raw: u8 = @intCast(setup.get_endpoint_number_payload());
                            const addr: endpoint.Address = @bitCast(raw);
                            switch (addr.dir) {
                                .in => {
                                    if (self.ep_state[addr.ep].in_halted) status |= 1;
                                },
                                .out => {
                                    if (self.ep_state[addr.ep].out_halted) status |= 1;
                                },
                            }
                            log.info("get endpoint {} {s} status", .{ addr.ep, @tagName(addr.dir) });
                        },
                        else => {
                            log.err("get status for unrecognized target: {}", .{ @intFromEnum(setup.target) });
                        },
                    }
                    self.setup_transfer_in_data(std.mem.asBytes(&status));
                    handled = true;
                },
                .set_feature, .clear_feature => if (setup.direction == .out) {
                    self.setup_status_in();
                    const f = setup.get_feature_payload();
                    switch (f.feature) {
                        .endpoint_halt => if (setup.target == .endpoint) {
                            const raw: u8 = @intCast(f.endpoint);
                            const addr: endpoint.Address = @bitCast(raw);
                            const halt = setup.request == .set_feature;
                            switch (addr.dir) {
                                .in => {
                                    self.ep_state[addr.ep].in_halted = halt;
                                    self.update_in_state(addr.ep);
                                },
                                .out => {
                                    self.ep_state[addr.ep].out_halted = halt;
                                    self.update_out_state(addr.ep);
                                },
                            }
                        },
                        .device_remote_wakeup => if (setup.target == .device) {
                            self.allow_remote_wakeup = setup.request == .set_feature;
                        },
                        else => {},
                    }
                    log.info("{s}: target = {s}, ep = {}, feature = {}", .{
                        @tagName(setup.request),
                        @tagName(setup.target),
                        f.endpoint,
                        f.feature,
                    });
                    handled = true;
                },
                else => {},
            };

            if (Config.handle_setup(setup)) handled = true;

            if (!handled) {
                log.err("unrecognized setup: {s}, request = {}", .{
                    @tagName(setup.direction),
                    @intFromEnum(setup.request)
                });
            }
        }

        fn handle_get_descriptor(self: *Self, setup: Setup_Packet) void {
            const which = setup.get_descriptor_payload();
            switch (setup.target) {
                .device => switch (which.kind) {
                    .device => {
                        if (self.setup_data_offset == 0) {
                            log.info("get device descriptor {}B", .{ self.setup_data_bytes_remaining });
                        }
                        const d: descriptor.Device = Config.get_device_descriptor();
                        self.setup_transfer_in_data(d.as_bytes());
                    },
                    .device_qualifier => {
                        if (self.setup_data_offset == 0) {
                            log.info("get device qualifier {}B", .{ self.setup_data_bytes_remaining });
                        }
                        const d: descriptor.Device = Config.get_device_descriptor();
                        const dq: descriptor.Device_Qualifier = .{
                            .usb_version = d.usb_version,
                            .class = d.class,
                            .max_packet_size_bytes = d.max_packet_size_bytes,
                            .configuration_count = d.configuration_count,
                        };
                        self.setup_transfer_in_data(dq.as_bytes());
                    },
                    .string => {
                        const id: descriptor.String_ID = @enumFromInt(which.index);
                        if (self.setup_data_offset == 0) {
                            log.info("get string {}B: id = {}, lang = {}", .{ self.setup_data_bytes_remaining, id, which.language });
                        }
                        if (Config.get_string_descriptor(id, which.language)) |data| {
                            self.setup_transfer_in_data(data[0..data[0]]);
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
                        if (Config.get_configuration_descriptor_set(which.index)) |data| {
                            self.setup_transfer_in_data(data);
                        } else if (self.setup_data_offset == 0) {
                            log.warn("request for invalid configuration descriptor: {}", .{ which.index });
                        }
                    },
                    else => {
                        if (self.setup_data_offset == 0) {
                            log.info("get descriptor {}B: descriptor = 0x{X} {}", .{ self.setup_data_bytes_remaining, @intFromEnum(which.kind), which.index });
                        }
                        if (Config.get_descriptor(which.kind, which.index)) |data| {
                            self.setup_transfer_in_data(data);
                        } else if (self.setup_data_offset == 0) {
                            log.warn("request for invalid descriptor: 0x{X} {}", .{ @intFromEnum(which.kind), which.index });
                        }
                    }
                },
                .interface => {
                    if (self.setup_data_offset == 0) {
                        log.info("get interface-specific descriptor {}B: interface = {}, descriptor = 0x{X} {}", .{
                            self.setup_data_bytes_remaining,
                            @intFromEnum(which.language), // really interface
                            @intFromEnum(which.kind),
                            which.index,
                        });
                    }
                    if (Config.get_interface_specific_descriptor(@intCast(@intFromEnum(which.language)), which.kind, which.index)) |data| {
                        self.setup_transfer_in_data(data);
                    } else if (self.setup_data_offset == 0) {
                        log.warn("request for invalid interface-specific descriptor: interface = {}, descriptor = 0x{X} {}", .{
                            @intFromEnum(which.language), // really interface
                            @intFromEnum(which.kind),
                            which.index,
                        });
                    }
                },
                .endpoint => {
                    if (self.setup_data_offset == 0) {
                        log.info("get endpoint-specific descriptor {}B: endpoint = {}, descriptor = 0x{X} {}", .{
                            self.setup_data_bytes_remaining,
                            @intFromEnum(which.language), // really endpoint
                            @intFromEnum(which.kind),
                            which.index,
                        });
                    }
                    if (Config.get_endpoint_specific_descriptor(@intCast(@intFromEnum(which.language)), which.kind, which.index)) |data| {
                        self.setup_transfer_in_data(data);
                    } else if (self.setup_data_offset == 0) {
                        log.warn("request for invalid endpoint-specific descriptor: endpoint = {}, descriptor = 0x{X} {}", .{
                            @intFromEnum(which.language), // really endpoint
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
                            @intFromEnum(which.language),
                            which.kind,
                            which.index,
                        });
                    }
                },
            }
        }

        pub fn fill_setup_in(self: *Self, offset: u16, data: []const u8) u16 {
            const data_offset_isize: isize = offset;
            const setup_offset_isize: isize = self.setup_data_offset;
            chip.usb.fill_buffer_in(0, data_offset_isize - setup_offset_isize, data);
            const data_len_u16: u16 = @intCast(data.len);
            log.debug("ep0 in data @{}: {}", .{ data_offset_isize - setup_offset_isize, std.fmt.fmtSliceHexLower(data) });
            return offset + data_len_u16;
        }

        pub fn setup_transfer_in_data(self: *Self, data: []const u8) void {
            self.setup_transfer_in(self.fill_setup_in(0, data));
        }

        pub fn setup_transfer_in(self: *Self, total_len: u16) void {
            const pid = self.ep_state[0].next_in_pid;
            const max_packet_size = self.ep_state[0].in_max_packet_size_bytes;
            if (total_len < self.setup_data_bytes_remaining) {
                self.setup_data_bytes_remaining = total_len;
            }
            var len = @min(self.setup_data_bytes_remaining, total_len - self.setup_data_offset);
            if (len > max_packet_size) {
                len = max_packet_size;
            }
            chip.usb.start_transfer_in(0, len, pid, len < max_packet_size);
            const final = if (len < max_packet_size) " (final)" else "";
            log.debug("ep0 in {}B {s}{s}", .{ len, @tagName(pid), final });
            self.setup_data_offset += len;
            self.setup_data_bytes_remaining -= len;
            self.ep_state[0].next_in_pid = pid.next();
        }

        pub fn setup_transfer_out(self: *Self, total_len: u16) void {
            const pid = self.ep_state[0].next_out_pid;
            const max_packet_size = self.ep_state[0].out_max_packet_size_bytes;
            var len = @min(self.setup_data_bytes_remaining, total_len - self.setup_data_offset);
            if (len > max_packet_size) {
                len = max_packet_size;
            }
            chip.usb.start_transfer_out(0, len, pid, len < max_packet_size);
            const final = if (len < max_packet_size) " (final)" else "";
            log.debug("ep0 out {}B {s}{s}", .{ len, @tagName(pid), final });
            self.ep_state[0].next_out_pid = pid.next();
        }

        pub fn setup_status_in(self: *Self) void {
            self.setup_data_offset = 0;
            self.setup_data_bytes_remaining = 0;
            self.ep_state[0].next_out_pid = .data1;
            @call(.always_inline, setup_transfer_in, .{ self, 0 });
        }

        pub fn setup_status_out(self: *Self) void {
            self.setup_data_offset = 0;
            self.setup_data_bytes_remaining = 0;
            self.ep_state[0].next_out_pid = .data1;
            @call(.always_inline, setup_transfer_out, .{ self, 0 });
        }

    };
}

pub const Events = struct {
    start_of_frame: bool = false,
    buffer_ready: bool = false,
    bus_reset: bool = false,
    setup_request: bool = false,
};

pub const Setup_Target = enum (u5) {
    device = 0,
    interface = 1,
    endpoint = 2,
    other = 3,
    _,
};

pub const Setup_Kind = enum (u2) {
    standard = 0,
    class = 1,
    vendor = 2,
    _,
};

pub const Setup_Request_Kind = enum (u8) {
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

pub const Setup_Packet = packed struct (u64) {
    target: Setup_Target,
    kind: Setup_Kind,
    direction: endpoint.Direction,
    request: Setup_Request_Kind,
    payload: u32,
    data_len: u16,

    pub fn get_address_payload(self: Setup_Packet) u7 {
        std.debug.assert(self.request == .set_address);
        const payload: packed struct (u32) {
            address: u16,
            _reserved: u16,
        } = @bitCast(self.payload);
        return @truncate(payload.address);
    }

    pub const Descriptor_Payload = packed struct (u32) {
        index: u8,
        kind: descriptor.Kind,
        language: descriptor.Language,
    };
    pub fn get_descriptor_payload(self: Setup_Packet) Descriptor_Payload {
        std.debug.assert(self.request == .get_descriptor or self.request == .set_descriptor);
        return @bitCast(self.payload);
    }

    pub const Feature_Payload = packed struct (u32) { feature: Feature, endpoint: u16 };
    pub fn get_feature_payload(self: Setup_Packet) Feature_Payload {
        std.debug.assert(self.request == .clear_feature or self.request == .set_feature);
        return @bitCast(self.payload);
    }

    pub fn get_configuration_number_payload(self: Setup_Packet) u8 {
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

    pub fn get_interface_number_payload(self: Setup_Packet) u8 {
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

    pub const Set_Interface_Payload = packed struct (u32) { alternate_setting: u16, interface: u16 };
    pub fn get_set_interface_payload(self: Setup_Packet) Set_Interface_Payload {
        std.debug.assert(self.request == .set_interface);
        return @bitCast(self.payload);
    }

    pub fn get_endpoint_number_payload(self: Setup_Packet) u8 {
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
