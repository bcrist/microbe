pub const class = struct {
    pub const default: classes.Info = .{
        .class = Class.hid,
        .subclass = .zero,
        .protocol = .zero,
    };

    pub const boot_keyboard: classes.Info = .{
        .class = Class.hid,
        .subclass = @enumFromInt(1),
        .protocol = @enumFromInt(1),
    };

    pub const boot_mouse: classes.Info = .{
        .class = Class.hid,
        .subclass = @enumFromInt(1),
        .protocol = @enumFromInt(2),
    };
};

pub const hid_descriptor: descriptor.Kind = @enumFromInt(0x21);
pub const report_descriptor: descriptor.Kind = @enumFromInt(0x22);
pub const physical_descriptor: descriptor.Kind = @enumFromInt(0x23);

pub const requests = struct {
    pub const get_report = request(0x1);
    pub const get_idle = request(0x2);
    pub const get_protocol = request(0x3);
    pub const set_report = request(0x9);
    pub const set_idle = request(0xA);
    pub const set_protocol = request(0xB);

    // Used for get_report and set_report
    pub const Report_Payload = packed struct (u32) {
        report_id: u8,
        report_kind: enum(u8) {
            input = 1,
            output = 2,
            feature = 3,
            _,
        },
        interface: u16,
    };

    // Used for get_idle and set_idle
    pub const Idle_Payload = packed struct (u32) {
        report_id: u8,
        interval: Idle_Interval, // for get_idle, this is in the data phase
        interface: u16,
    };

    // Used for get_protocol and set_protocol
    pub const Protocol_Payload = packed struct (u32) {
        protocol: u16, // for get_protocol, this is in the data phase
        interface: u16,
    };

    fn request(comptime num: comptime_int) usb.Setup_Request_Kind {
        return @enumFromInt(num);
    }
};

pub const Idle_Interval = enum(u8) {
    infinite = 0,
    @"16ms" = 4,
    @"500ms" = 125,
    _, // units of 4 ms
};

pub const Input_Reporter_Config = struct {
    max_buffer_size: usize,
    interface_index: u8,
    report_id: u8,
    default_idle_interval: Idle_Interval,
};
pub fn Input_Reporter(comptime Usb_Config_Type: type, comptime Report: type, comptime config: Input_Reporter_Config) type {
    if (!std.math.isPowerOfTwo(config.max_buffer_size)) {
        @compileError("Buffer size must be a power of two!");
    }
    const report_bytes = @bitSizeOf(Report) / 8;
    const Fifo = std.fifo.LinearFifo(Report, .{ .Static = config.max_buffer_size });
    return struct {
        const Self = @This();
        pub const Input_Report = Report;

        usb: *usb.USB(Usb_Config_Type),
        queue: Fifo = Fifo.init(),
        last_report: Report,
        idle_interval: Idle_Interval,
        idle_timer: u8 = 0,

        pub fn init(usb_ptr: *usb.USB(Usb_Config_Type)) Self {
            return .{
                .usb = usb_ptr,
                .queue = Fifo.init(),
                .last_report = .{},
                .idle_interval = config.default_idle_interval,
                .idle_timer = 0,
            };
        }

        pub fn reset(self: *Self) void {
            self.last_report = .{};
            self.idle_interval = config.default_idle_interval;
            self.idle_timer = 0;
        }

        pub fn push_all(self: *Self, reports: []const Report) void {
            for (reports) |rpt| {
                self.push(rpt);
            }
        }

        pub fn push(self: *Self, rpt: Report) void {
            if (!std.meta.eql(rpt, self.tail())) {
                while (self.queue.writableLength() == 0) {
                    if (self.usb.state != .connected) {
                        log.warn("Discarding input report; FIFO is full and USB is disconnected", .{});
                        return;
                    }
                    self.usb.update();
                }
                self.queue.writeItemAssumeCapacity(rpt);
            }
        }

        pub fn tail(self: *Self) Report {
            if (self.queue.readableLength() == 0) {
                return self.last_report;
            }
            var last_index = self.queue.head + self.queue.count - 1;
            last_index &= self.queue.buf.len - 1;
            return self.queue.buf[last_index];
        }

        pub fn tail_ptr(self: *Self) ?*Report {
            if (self.queue.readableLength() == 0) {
                return null;
            }
            var last_index = self.queue.head + self.queue.count - 1;
            last_index &= self.queue.buf.len - 1;
            return &self.queue.buf[last_index];
        }

        pub fn handle_start_of_frame(self: *Self) void {
            if (self.idle_interval == .infinite) return;
            self.idle_timer += 1;
        }

        pub fn is_endpoint_ready(self: *Self) bool {
            if (self.queue.readableLength() > 0) return true;
            const interval = self.idle_interval;
            if (interval == .infinite) return false;
            return self.idle_timer / 4 >= @intFromEnum(interval);
        }

        pub fn get_in_buffer(self: *Self) []const u8 {
            var buf: []const u8 = undefined;
            if (self.queue.readItem()) |next_report| {
                self.last_report = next_report;
                buf = std.mem.asBytes(&self.last_report)[0..report_bytes];
                log.debug("Input_Reporter {} report {}: {}", .{
                    config.interface_index,
                    config.report_id,
                    std.fmt.fmtSliceHexUpper(buf),
                });
            } else {
                buf = std.mem.asBytes(&self.last_report)[0..report_bytes];
            }
            self.idle_timer = 0;
            return buf;
        }

        pub fn handle_setup(self: *Self, setup: usb.Setup_Packet) bool {
            if (setup.kind != .class) return false;
            switch (setup.request) {
                requests.set_idle => if (setup.direction == .out) {
                    const payload: requests.Idle_Payload = @bitCast(setup.payload);
                    if (payload.interface == config.interface_index and payload.report_id == config.report_id) {
                        self.idle_interval = payload.interval;
                        self.usb.setup_status_in();
                        log.info("Input_Reporter {} set_idle {}: {}", .{
                            config.interface_index,
                            config.report_id,
                            self.idle_interval,
                        });
                        return true;
                    }
                },
                requests.get_idle => if (setup.direction == .in) {
                    const payload: requests.Idle_Payload = @bitCast(setup.payload);
                    if (payload.interface == config.interface_index and payload.report_id == config.report_id) {
                        log.info("Input_Reporter {} get_idle {}: {}", .{
                            config.interface_index,
                            config.report_id,
                            self.idle_interval,
                        });
                        self.usb.setup_transfer_in_data(std.mem.asBytes(&self.idle_interval));
                        return true;
                    }
                },
                requests.get_report => if (setup.direction == .in) {
                    const payload: requests.Report_Payload = @bitCast(setup.payload);
                    if (payload.interface == config.interface_index and payload.report_id == config.report_id and payload.report_kind == .input) {
                        const buf = std.mem.asBytes(&self.last_report)[0..report_bytes];
                        log.debug("Input_Reporter {} get_report {}: {}", .{
                            config.interface_index,
                            config.report_id,
                            std.fmt.fmtSliceHexUpper(buf),
                        });
                        self.usb.setup_transfer_in_data(buf);
                        return true;
                    }
                },
                else => {},
            }
            return false;
        }
    };
}

pub const Callback_Input_Reporter_Config = struct {
    interface_index: u8,
    report_id: u8,
};

pub fn Callback_Input_Reporter(comptime Usb_Config_Type: type, comptime Report: type, comptime callback: *const fn() Report, comptime config: Callback_Input_Reporter_Config) type {
    const report_bytes = @bitSizeOf(Report) / 8;
    return struct {
        const Self = @This();
        pub const Input_Report = Report;

        usb: *usb.USB(Usb_Config_Type),
        last_report: Report,

        pub fn init(usb_ptr: *usb.USB(Usb_Config_Type)) Self {
            return .{
                .usb = usb_ptr,
                .last_report = .{},
            };
        }

        pub fn reset(self: *Self) void {
            self.last_report = .{};
        }

        pub fn tail(self: *Self) Report {
            return self.last_report;
        }

        pub fn get_in_buffer(self: *Self) []const u8 {
            self.last_report = callback();
            const buf = std.mem.asBytes(&self.last_report)[0..report_bytes];
            log.debug("Callback_Input_Reporter {} report {}: {}", .{
                config.interface_index,
                config.report_id,
                std.fmt.fmtSliceHexUpper(buf),
            });
            return buf;
        }

        pub fn handle_setup(self: *Self, setup: usb.Setup_Packet) bool {
            if (setup.kind != .class) return false;
            switch (setup.request) {
                requests.set_idle => if (setup.direction == .out) {
                    const payload: requests.Idle_Payload = @bitCast(setup.payload);
                    if (payload.interface == config.interface_index and payload.report_id == config.report_id) {
                        const idle_interval = payload.interval;
                        self.usb.setup_status_in();
                        log.info("Callback_Input_Reporter {} set_idle {}: {}", .{
                            config.interface_index,
                            config.report_id,
                            idle_interval,
                        });
                        return true;
                    }
                },
                requests.get_idle => if (setup.direction == .in) {
                    const payload: requests.Idle_Payload = @bitCast(setup.payload);
                    if (payload.interface == config.interface_index and payload.report_id == config.report_id) {
                        const idle_interval: Idle_Interval = .infinite;
                        log.info("Callback_Input_Reporter {} get_idle {}: {}", .{
                            config.interface_index,
                            config.report_id,
                            idle_interval,
                        });
                        self.usb.setup_transfer_in_data(std.mem.asBytes(&idle_interval));
                        return true;
                    }
                },
                requests.get_report => if (setup.direction == .in) {
                    const payload: requests.Report_Payload = @bitCast(setup.payload);
                    if (payload.interface == config.interface_index and payload.report_id == config.report_id and payload.report_kind == .input) {
                        const buf = std.mem.asBytes(&self.last_report)[0..report_bytes];
                        log.debug("Callback_Input_Reporter {} get_report {}: {}", .{
                            config.interface_index,
                            config.report_id,
                            std.fmt.fmtSliceHexUpper(buf),
                        });
                        self.usb.setup_transfer_in_data(buf);
                        return true;
                    }
                },
                else => {},
            }
            return false;
        }
    };
}

pub const Output_Report_Config = struct {
    interface_index: u8,
    report_id: u8,
};
pub fn Output_Reporter(comptime Usb_Config_Type: type, comptime Report: type, comptime config: Output_Report_Config) type {
    const report_bytes = @bitSizeOf(Report) / 8;
    return struct {
        const Self = @This();
        pub const Output_Report = Report;

        usb: *usb.USB(Usb_Config_Type),
        current_report: Report,

        pub fn init(usb_ptr: *usb.USB(Usb_Config_Type)) Self {
            return .{
                .usb = usb_ptr,
                .current_report = .{},
            };
        }

        pub fn handle_setup(self: *Self, setup: usb.Setup_Packet) bool {
            if (setup.kind != .class) return false;
            switch (setup.request) {
                requests.set_report => if (setup.direction == .out) {
                    const payload: requests.Report_Payload = @bitCast(setup.payload);
                    if (payload.interface == config.interface_index and payload.report_id == config.report_id and payload.report_kind == .output) {
                        log.debug("Output_Reporter {} set_report {} received", .{
                            config.interface_index,
                            config.report_id,
                        });
                        self.usb.setup_transfer_out(setup.data_len);
                        return true;
                    }
                },
                requests.get_report => if (setup.direction == .in) {
                    const payload: requests.Report_Payload = @bitCast(setup.payload);
                    if (payload.interface == config.interface_index and payload.report_id == config.report_id and payload.report_kind == .output) {
                        const buf = std.mem.asBytes(&self.current_report)[0..report_bytes];
                        log.debug("Output_Reporter {} get_report {}: {}", .{
                            config.interface_index,
                            config.report_id,
                            std.fmt.fmtSliceHexUpper(buf),
                        });
                        self.usb.setup_transfer_in_data(buf);
                        return true;
                    }
                },
                else => {},
            }
            return false;
        }

        pub fn handle_setup_out_buffer(self: *Self, setup: usb.Setup_Packet, offset: u16, data: []volatile const u8) bool {
            if (setup.kind != .class or setup.request != requests.set_report) return false;
            const payload: requests.Report_Payload = @bitCast(setup.payload);
            if (payload.interface == config.interface_index and payload.report_id == config.report_id and payload.report_kind == .output) {
                if (offset > report_bytes) return true;

                var buf = std.mem.asBytes(&self.current_report)[offset..report_bytes];
                const bytes = @min(data.len, buf.len);
                @memcpy(buf[0..bytes], data[0..bytes]);

                log.debug("Output_Reporter {} set_report {}: {}", .{
                    config.interface_index,
                    config.report_id,
                    std.fmt.fmtSliceHexUpper(buf),
                });
                return true;
            }
            return false;
        }
    };
}

pub const Locale = enum(u8) {
    generic = 0,
    arabic,
    belgian,
    canadian_bilingual,
    canadian_french,
    czech_republic,
    danish,
    finnish,
    french,
    german,
    greek,
    hebrew,
    hungary,
    international,
    italian,
    japan_katakana,
    korean,
    latin_america,
    netherlands_dutch,
    norwegian,
    persian_farsi,
    poland,
    portuguese,
    russia,
    slovakia,
    spanish,
    swedish,
    swiss_french,
    swiss_german,
    switzerland,
    taiwan,
    turkish_q,
    uk,
    us,
    yugoslavia,
    turkish_f,
    _,
};

pub const boot_keyboard = struct {
    pub const HID_Descriptor = Descriptor(.generic, .{ Report_Descriptor });
    pub const Report_Descriptor = report.Descriptor(.{
        report.Usage_Page(.generic_desktop),
        report.Usage(page.Generic_Desktop.keyboard),
        report.Collection(.application, .{
            report.Bit_Count(8),
            report.Usage_Page(.keyboard),
            report.Usage_Range(page.Keyboard.lcontrol, page.Keyboard.rgui),
            report.Logical_Range(0, 1),
            report.Absolute_Input(.linear, .returns_to_preferred_state, .no_null_state),
            report.Byte_Count(1),
            report.Constant_Input,
            report.Byte_Count(6),
            report.Usage_Range(0, 255),
            report.Logical_Range(0, 255),
            report.Array_Input,

            report.Bit_Count(3),
            report.Usage_Page(.leds),
            report.Usage_Range(page.LEDs.num_lock, page.LEDs.scroll_lock),
            report.Absolute_Output(.linear, .no_null_state, .nonvolatile),
            report.Bit_Count(5),
            report.Constant_Output,
        }),
    });
    pub const Input_Report = extern struct {
        modifiers: packed struct (u8) {
            left_control: bool = false,
            left_shift: bool = false,
            left_alt: bool = false,
            left_gui: bool = false,
            right_control: bool = false,
            right_shift: bool = false,
            right_alt: bool = false,
            right_gui: bool = false,
        } = .{},
        _reserved: u8 = 0,
        keys: [6]page.Keyboard = std.mem.zeroes([6]page.Keyboard),
    };
    pub const Output_Report = packed struct (u8) {
        num_lock: bool = false,
        caps_lock: bool = false,
        scroll_lock: bool = false,
        compose: bool = false,
        kana: bool = false,
        _reserved: u3 = 0,
    };
};

pub const boot_mouse = struct {
    pub const HID_Descriptor = Descriptor(.generic, .{ Report_Descriptor });
    pub const Report_Descriptor = report.Descriptor(.{
        report.Usage_Page(.generic_desktop),
        report.Usage(page.Generic_Desktop.mouse),
        report.Collection(.application, .{
            report.Usage(page.Generic_Desktop.pointer),
            report.Collection(.physical, .{
                report.Bit_Count(8),
                report.Usage_Page(.buttons),
                report.Usage_Range(1, 8),
                report.Logical_Range(0, 1),
                report.Absolute_Input(.linear, .returns_to_preferred_state, .no_null_state),
                report.Byte_Count(2),
                report.Usage_Page(.generic_desktop),
                report.Usage(page.Generic_Desktop.x),
                report.Usage(page.Generic_Desktop.y),
                report.Logical_Range(-127, 127),
                report.Relative_Input,
            }),
        }),
    });
    pub const Input_Report = packed struct (u24) {
        left_btn: bool = false,
        right_btn: bool = false,
        middle_btn: bool = false,
        btn_4: bool = false,
        btn_5: bool = false,
        btn_6: bool = false,
        btn_7: bool = false,
        btn_8: bool = false,

        x: i8 = 0,
        y: i8 = 0,
    };
};

// Takes a tuple of report/physical descriptors (usually just the report descriptor)
pub fn Descriptor(comptime locale: Locale, comptime class_descriptors: anytype) type {
    const Sub_Descriptor_Info = packed struct {
        kind: descriptor.Kind,
        len: u16
    };

    const fields = comptime blk: {
        var fields: []const std.builtin.Type.StructField = &.{};

        for (0.., class_descriptors) |i, desc| {
            const DescType = if (@TypeOf(desc) == type) desc else @TypeOf(desc);
            const default: Sub_Descriptor_Info = .{
                .kind = DescType._kind,
                .len = DescType._len,
            };

            const t: std.builtin.Type.StructField = .{
                .name = std.fmt.comptimePrint("{}", .{ i }),
                .type = Sub_Descriptor_Info,
                .default_value = &default,
                .is_comptime = false,
                .alignment = 0,
            };
            fields = fields ++ .{ t };
        }

        break :blk fields;
    };

    const Sub_Descriptor_Infos = @Type(.{ .@"struct" = .{
        .layout = .@"packed",
        .fields = fields,
        .decls = &.{},
        .is_tuple = false,
    }});

    return packed struct {
        _len: u8 = @bitSizeOf(@This()) / 8,
        _kind: descriptor.Kind = hid_descriptor,
        hid_version: descriptor.Version = .{ .major = 1, .minor = 1, .rev = 1 },
        locale: Locale = locale,
        num_descriptors: u8 = @intCast(fields.len),
        descriptors: Sub_Descriptor_Infos = .{},

        pub fn as_bytes(self: *const @This()) []const u8 {
            return descriptor.as_bytes(self);
        }
    };
}

pub const report = struct {

    pub fn Bit_Count(comptime count: comptime_int) type {
        return Count_And_Size(count, 1);
    }
    pub fn Byte_Count(comptime count: comptime_int) type {
        return Count_And_Size(count, 8);
    }
    pub fn Count_And_Size(comptime count: comptime_int, comptime size: comptime_int) type {
        return packed struct {
            _size: Short_Item(.global_report_size, size) = .{},
            _count: Short_Item(.global_report_count, count) = .{},
        };
    }

    pub fn Logical_Range(comptime min: comptime_int, comptime max: comptime_int) type {
        return packed struct {
            _min: Short_Item(.global_logical_minimum, min) = .{},
            _max: Short_Item(.global_logical_maximum, max) = .{},
        };
    }

    pub fn Usage_Range(comptime min: anytype, comptime max: anytype) type {
        return packed struct {
            _min: Short_Item(.local_usage_minimum, int_or_enum(min)) = .{},
            _max: Short_Item(.local_usage_maximum, int_or_enum(max)) = .{},
        };
    }

    pub fn Usage(comptime usage: anytype) type {
        return Short_Item(.local_usage, int_or_enum(usage));
    }

    fn int_or_enum(comptime a: anytype) comptime_int {
        return switch (@typeInfo(@TypeOf(a))) {
            .@"enum" => @intFromEnum(a),
            .int, .comptime_int => a,
            else => @compileError("Expected enum or integer"),
        };
    }

    pub const Usage_Page_Kind = enum(u16) {
        generic_desktop = 0x1,
        simulation_controls = 0x2,
        vr_controls = 0x3,
        sport_controls = 0x4,
        game_controls = 0x05,
        generic_device_controls = 0x06,
        keyboard = 0x07,
        leds = 0x08,
        buttons = 0x09,
        ordinal = 0x0A,
        telephony_devices = 0x0B,
        consumer = 0x0C,
        digitizers = 0x0D,
        haptics = 0x0E,
        physical_input_devices = 0x0F,
        unicode = 0x10,
        soc = 0x11,
        eye_and_head_trackers = 0x12,
        auxiliary_display = 0x14,
        sensors = 0x20,
        medical_instruments = 0x40,
        braille_display = 0x41,
        lighting_and_illumination = 0x59,
        monitors = 0x80,
        monitors_enumerated = 0x81,
        vesa_virtual_controls = 0x82,
        power = 0x84,
        battery_systems = 0x85,
        barcode_scanners = 0x8C,
        scales = 0x8D,
        magnetic_stripe_readers = 0x8E,
        camera_controls = 0x90,
        arcade = 0x91,
        gaming_devices = 0x92,
        fido_alliance = 0xF1D0,
        _,
    };
    pub fn Usage_Page(comptime kind: Usage_Page_Kind) type {
        return Short_Item(.global_usage_page, @intFromEnum(kind));
    }

    pub const Constant_Input = Input(.{ .disposition = .constant });
    pub const Constant_Output = Output(.{ .disposition = .constant });

    pub const Array_Input = Input(.{ .disposition = .array, .nullability = .has_null_state });
    pub const Array_Output = Output(.{ .disposition = .array, .nullability = .has_null_state });

    pub fn Absolute_Input(comptime linearity: IO_Flags.Linearity, comptime autonomy: IO_Flags.Autonomy, comptime nullability: IO_Flags.Nullability) type {
        return Input(.{
            .disposition = .variable,
            .basis = .absolute,
            .linearity = linearity,
            .autonomy = autonomy,
            .nullability = nullability,
        });
    }
    pub fn Absolute_Output(comptime linearity: IO_Flags.Linearity, comptime nullability: IO_Flags.Nullability, comptime volatility: IO_Flags.Volatility) type {
        return Output(.{
            .disposition = .variable,
            .basis = .absolute,
            .linearity = linearity,
            .nullability = nullability,
            .volatility = volatility,
        });
    }
    pub fn Wrapped_Input(comptime linearity: IO_Flags.Linearity, comptime autonomy: IO_Flags.Autonomy, comptime nullability: IO_Flags.Nullability) type {
        return Input(.{
            .disposition = .variable,
            .basis = .absolute_wrapped,
            .linearity = linearity,
            .autonomy = autonomy,
            .nullability = nullability,
        });
    }
    pub const Relative_Input = Input(.{ .disposition = .variable, .basis = .relative, .autonomy = .none });
    pub fn Relative_Output(comptime volatility: IO_Flags.Volatility) type {
        return Output(.{
            .disposition = .variable,
            .basis = .relative,
            .volatility = volatility,
        });
    }

    pub const IO_Flags = packed struct (u16) {
        disposition: enum (u2) {
            array = 0,
            constant = 1,
            variable = 2,
        } = .array,
        basis: enum (u2) {
            absolute = 0,
            relative = 1,
            absolute_wrapped = 2,
            relative_wrapped = 3, // not sure why you'd want this...
        } = .absolute,
        linearity: Linearity = .linear,
        autonomy: Autonomy = .returns_to_preferred_state,
        nullability: Nullability = .no_null_state,
        volatility: Volatility = .nonvolatile,
        buffered_bytes: bool = false,
        _reserved: u7 = 0,

        pub const Linearity = enum (u1) {
            linear = 0,
            nonlinear = 1,
        };
        pub const Autonomy = enum (u1) {
            returns_to_preferred_state = 0,
            none = 1,
        };
        pub const Nullability = enum (u1) {
            no_null_state = 0,
            has_null_state = 1,
        };
        pub const Volatility = enum (u1) {
            nonvolatile = 0,
            @"volatile" = 1,
        };
    };
    pub fn Input(comptime flags: IO_Flags) type {
        return Short_Item(.input, @as(u16, @bitCast(flags)));
    }
    pub fn Output(comptime flags: IO_Flags) type {
        return Short_Item(.output, @as(u16, @bitCast(flags)));
    }

    pub const Collection_Kind = enum(u8) {
        physical = 0, // group of axes
        application = 1, // mouse, keybaord
        logical = 2, // interrelated data
        report = 3,
        named_array = 4,
        usage_switch = 5,
        usage_modifier = 6,
        _,
    };
    pub fn Collection(comptime kind: Collection_Kind, comptime contents: anytype) type {
        return packed struct {
            collection: Short_Item(.collection, @intFromEnum(kind)) = .{},
            items: Items(contents) = .{},
            end: Short_Item(.end_collection, 0) = .{},
        };
    }

    pub fn Descriptor(comptime contents: anytype) type {
        return packed struct {
            contents: Items(contents) = .{},

            pub const _len: u8 = @bitSizeOf(@This()) / 8;
            pub const _kind: descriptor.Kind = report_descriptor;
            pub fn as_bytes(self: *const @This()) []const u8 {
                return descriptor.as_bytes(self);
            }
        };
    }

    fn Items(comptime contents: anytype) type {
        const types = comptime blk: {
            var types: []const std.builtin.Type.StructField = &.{};

            for (0.., contents) |i, ItemType| {
                const default: ItemType = .{};
                const t: std.builtin.Type.StructField = .{
                    .name = std.fmt.comptimePrint("{}", .{ i }),
                    .type = ItemType,
                    .default_value = &default,
                    .is_comptime = false,
                    .alignment = 0,
                };
                types = types ++ .{ t };
            }

            break :blk types;
        };

        return @Type(.{ .@"struct" = .{
            .layout = .@"packed",
            .fields = types,
            .decls = &.{},
            .is_tuple = false,
        }});
    }

    pub const Short_Item_Kind = enum (u6) {
        global_usage_page = 0b1,
        global_logical_minimum = 0b101,
        global_logical_maximum = 0b1001,
        global_physical_minimum = 0b1101,
        global_physical_maximum = 0b10001,
        global_unit_exponent = 0b10101,
        global_unit = 0b11001,
        global_report_size = 0b11101,
        global_report_id = 0b100001,
        global_report_count = 0b100101,
        global_push = 0b101001,
        global_pop = 0b101101,

        local_usage = 0b10,
        local_usage_minimum = 0b110,
        local_usage_maximum = 0b1010,
        local_designator_index = 0b1110,
        local_designator_minimum = 0b10010,
        local_designator_maximum = 0b10110,
        local_string_index = 0b11110,
        local_string_minimum = 0b100010,
        local_string_maximum = 0b100110,
        local_delimiter = 0b101010,

        input = 0b100000,
        output = 0b100100,
        collection = 0b101000,
        feature = 0b101100,
        end_collection = 0b110000,

        _,
    };
    pub fn Short_Item(comptime kind: Short_Item_Kind, comptime data: comptime_int) type {
        comptime var can_be_zero_bytes = false;
        comptime var can_be_signed = false;

        switch (@as(u2, @truncate(@intFromEnum(kind)))) {
            0 => can_be_zero_bytes = true, // main item
            1 => can_be_signed = true, // global item
            else  => {}
        }

        // USB HID spec v1.11: 6.2.2.4: Remarks: "The default data value for all Main items is zero (0)."
        // This would lead one to believe Collection(Physical) could be encoded as 0xA0 instead of 0xA1 0x00,
        // but it's normally done the latter way, and Windows won't accept the former.
        // Therefore we never encode Collection items with size 0:
        if (kind == .collection) can_be_zero_bytes = false;

        if (can_be_zero_bytes and data == 0) {
            return packed struct (u8) {
                _size: u2 = 0,
                _kind: Short_Item_Kind = kind,
            };
        } else if (can_be_signed) {
            const idata: i32 = @intCast(data);
            if (@as(i8, @truncate(idata)) == idata) {
                return packed struct (u16) {
                    _size: u2 = 1,
                    _kind: Short_Item_Kind = kind,
                    data: i8 = @truncate(idata),
                };
            } else if (@as(i16, @truncate(idata)) == idata) {
                return packed struct (u24) {
                    _size: u2 = 2,
                    _kind: Short_Item_Kind = kind,
                    data: i16 = @truncate(idata),
                };
            } else {
                return packed struct (u40) {
                    _size: u2 = 3,
                    _kind: Short_Item_Kind = kind,
                    data: i32 = idata,
                };
            }
        } else {
            const udata: u32 = @intCast(data);
            if (@as(u8, @truncate(udata)) == udata) {
                return packed struct (u16) {
                    _size: u2 = 1,
                    _kind: Short_Item_Kind = kind,
                    data: u8 = @truncate(udata),
                };
            } else if (@as(u16, @truncate(udata)) == udata) {
                return packed struct (u24) {
                    _size: u2 = 2,
                    _kind: Short_Item_Kind = kind,
                    data: u16 = @truncate(udata),
                };
            } else {
                return packed struct (u40) {
                    _size: u2 = 3,
                    _kind: Short_Item_Kind = kind,
                    data: u32 = udata,
                };
            }
        }
    }

    pub fn Long_Item(comptime tag: u8, comptime data: []const u8) type {
        const len = data.len;
        const ptr: *const [len]u8 = @ptrCast(data);

        return packed struct {
            _size: u2 = 2,
            _reserved: u6 = 0x3f,
            _len: u8 = @intCast(data.len),
            tag: u8 = tag,
            data: [len]u8 = ptr.*,
        };
    }
};

pub const page = struct {

    pub const Generic_Desktop = enum(u8) { // Page 0x01
        // Collection (Application)
        mouse = 2,
        joystick = 4,
        gamepad = 5,
        keyboard = 6,
        keypad = 7,
        multi_axis_controller = 8,
        system_control = 0x80,

        // Collection (Physical)
        pointer = 1,

        // Collection (Logical)
        counted_buffer = 0x3A,

        // Dynamic Value
        x = 0x30,
        y = 0x31,
        z = 0x32,
        rx = 0x33,
        ry = 0x34,
        rz = 0x35,
        slider = 0x36,
        dial = 0x37,
        wheel = 0x38,
        hat_switch = 0x39,
        byte_count = 0x3B,
        vx = 0x40,
        vy = 0x41,
        vz = 0x42,
        vbrx = 0x43,
        vbry = 0x44,
        vbrz = 0x45,
        vno = 0x46,
        feature_notification = 0x47,
        resolution_multiplier = 0x48,
        qx = 0x49,
        qy = 0x4A,
        qz = 0x4B,
        qw = 0x4C,

        // One Shot Control
        motion_wakeup = 0x3C,
        system_power_down = 0x81,
        system_sleep = 0x82,
        system_wake_up = 0x83,

        // On/Off Control
        start = 0x3D,
        select = 0x3E,

        _,
    };

    pub const Keyboard = enum(u8) { // Page 0x07
        error_rollover = 0x01,  // reserved for typical keyboard status or keyboard errors.  not a physical key
        post_fail = 0x02,       // reserved for typical keyboard status or keyboard errors.  not a physical key
        error_undefined = 0x03, // reserved for typical keyboard status or keyboard errors.  not a physical key
        kb_a = 0x04,
        kb_b = 0x05,
        kb_c = 0x06,
        kb_d = 0x07,
        kb_e = 0x08,
        kb_f = 0x09,
        kb_g = 0x0A,
        kb_h = 0x0B,
        kb_i = 0x0C,
        kb_j = 0x0D,
        kb_k = 0x0E,
        kb_l = 0x0F,
        kb_m = 0x10,
        kb_n = 0x11,
        kb_o = 0x12,
        kb_p = 0x13,
        kb_q = 0x14,
        kb_r = 0x15,
        kb_s = 0x16,
        kb_t = 0x17,
        kb_u = 0x18,
        kb_v = 0x19,
        kb_w = 0x1A,
        kb_x = 0x1B,
        kb_y = 0x1C,
        kb_z = 0x1D,
        kb_1_exclaim = 0x1E,
        kb_2_at = 0x1F,
        kb_3_octothorpe = 0x20,
        kb_4_dollar = 0x21,
        kb_5_percent = 0x22,
        kb_6_caret = 0x23,
        kb_7_ampersand = 0x24,
        kb_8_asterisk = 0x25,
        kb_9_oparen = 0x26,
        kb_0_cparen = 0x27,
        kb_return = 0x28,
        escape = 0x29,
        backspace = 0x2A,
        tab = 0x2B,
        space = 0x2C,
        hyphen_underscore = 0x2D,
        equals_plus = 0x2E,
        obracket_obrace = 0x2F,
        cbracket_cbrace = 0x30,
        backslash_vbar = 0x31,
        foreign_num_tilde = 0x32,
        semicolon_colon = 0x33,
        squote_dquote = 0x34,
        backtick_tilde = 0x35,
        comma_lessthan = 0x36,
        period_greaterthan = 0x37,
        slash_question = 0x38,
        caps_lock = 0x39,
        f1 = 0x3A,
        f2 = 0x3B,
        f3 = 0x3C,
        f4 = 0x3D,
        f5 = 0x3E,
        f6 = 0x3F,
        f7 = 0x40,
        f8 = 0x41,
        f9 = 0x42,
        f10 = 0x43,
        f11 = 0x44,
        f12 = 0x45,
        print_screen = 0x46,// Usage of keys is not modified by the state of the control, alt, shift, or num lock keys.  That is, a key does not send extra codes to compensate for the state of any control, alt, shift, or num lock keys
        scroll_lock = 0x47,
        pause = 0x48,     // Usage of keys is not modified by the state of the control, alt, shift, or num lock keys.  That is, a key does not send extra codes to compensate for the state of any control, alt, shift, or num lock keys
        insert = 0x49,    // Usage of keys is not modified by the state of the control, alt, shift, or num lock keys.  That is, a key does not send extra codes to compensate for the state of any control, alt, shift, or num lock keys
        home = 0x4A,      // Usage of keys is not modified by the state of the control, alt, shift, or num lock keys.  That is, a key does not send extra codes to compensate for the state of any control, alt, shift, or num lock keys
        page_up = 0x4B,   // Usage of keys is not modified by the state of the control, alt, shift, or num lock keys.  That is, a key does not send extra codes to compensate for the state of any control, alt, shift, or num lock keys
        delete = 0x4C,    // Usage of keys is not modified by the state of the control, alt, shift, or num lock keys.  That is, a key does not send extra codes to compensate for the state of any control, alt, shift, or num lock keys
        end = 0x4D,       // Usage of keys is not modified by the state of the control, alt, shift, or num lock keys.  That is, a key does not send extra codes to compensate for the state of any control, alt, shift, or num lock keys
        page_down = 0x4E, // Usage of keys is not modified by the state of the control, alt, shift, or num lock keys.  That is, a key does not send extra codes to compensate for the state of any control, alt, shift, or num lock keys
        nav_right = 0x4F, // Usage of keys is not modified by the state of the control, alt, shift, or num lock keys.  That is, a key does not send extra codes to compensate for the state of any control, alt, shift, or num lock keys
        nav_left = 0x50,  // Usage of keys is not modified by the state of the control, alt, shift, or num lock keys.  That is, a key does not send extra codes to compensate for the state of any control, alt, shift, or num lock keys
        nav_down = 0x51,  // Usage of keys is not modified by the state of the control, alt, shift, or num lock keys.  That is, a key does not send extra codes to compensate for the state of any control, alt, shift, or num lock keys
        nav_up = 0x52,    // Usage of keys is not modified by the state of the control, alt, shift, or num lock keys.  That is, a key does not send extra codes to compensate for the state of any control, alt, shift, or num lock keys
        kp_num_lock = 0x53,
        kp_divide = 0x54,
        kp_multiply = 0x55,
        kp_minus = 0x56,
        kp_plus = 0x57,
        kp_enter = 0x58,
        kp_1_end = 0x59,
        kp_2_nav_down = 0x5A,
        kp_3_page_down = 0x5B,
        kp_4_nav_left = 0x5C,
        kp_5 = 0x5D,
        kp_6_nav_right = 0x5E,
        kp_7_home = 0x5F,
        kp_8_nav_up = 0x60,
        kp_9_page_up = 0x61,
        kp_0_insert = 0x62,
        kp_dot_delete = 0x63,
        foreign_backslash_vbar = 0x64,
        application = 0x65, // windows key for win95, "compose"
        power = 0x66, // reserved for typical keyboard status or keyboard errors.  not a physical key
        kp_equals = 0x67,
        f13 = 0x68,
        f14 = 0x69,
        f15 = 0x6A,
        f16 = 0x6B,
        f17 = 0x6C,
        f18 = 0x6D,
        f19 = 0x6E,
        f20 = 0x6F,
        f21 = 0x70,
        f22 = 0x71,
        f23 = 0x72,
        f24 = 0x73,
        execute = 0x74,
        help = 0x75,
        menu = 0x76,
        select = 0x77,
        stop = 0x78,
        again = 0x79,
        undo = 0x7A,
        cut = 0x7B,
        copy = 0x7C,
        paste = 0x7D,
        find = 0x7E,
        mute = 0x7F,
        volume_up = 0x80,
        volume_down = 0x81,
        locking_caps_lock = 0x82,   // most systems should use the non-locking version of this key
        locking_num_lock = 0x83,    // most systems should use the non-locking version of this key
        locking_scroll_lock = 0x84, // most systems should use the non-locking version of this key
        kp_comma = 0x85, // keypad comma on brazilian keypad where period normally is.  os may map to period instead of comma depending on locale setting
        kp_equal_sign = 0x86, // as/400
        international_1 = 0x87,
        international_2 = 0x88,
        international_3 = 0x89,
        international_4 = 0x8A,
        international_5 = 0x8B,
        international_6 = 0x8C,
        international_7 = 0x8D,
        international_8 = 0x8E,
        international_9 = 0x8F,
        lang_1 = 0x90,
        lang_2 = 0x91,
        lang_3 = 0x92,
        lang_4 = 0x93,
        lang_5 = 0x94,
        lang_6 = 0x95,
        lang_7 = 0x96,
        lang_8 = 0x97,
        lang_9 = 0x98,
        alternate_erase = 0x99,
        sysreq_attn = 0x9A,
        cancel = 0x9B,
        clear = 0x9C,
        prior = 0x9D,
        alt_return = 0x9E,
        separator = 0x9F,
        out = 0xA0,
        oper = 0xA1,
        clear_again = 0xA2,
        crsel_props = 0xA3,
        exsel = 0xA4,
        kp_00 = 0xB0,
        kp_000 = 0xB1,
        thousands_separator = 0xB2, // depends on locale
        decimal_separator = 0xB3,   // depends on locale
        currency_unit = 0xB4,       // depends on locale
        currency_subunit = 0xB5,    // depends on locale
        kp_oparen = 0xB6,
        kp_cparen = 0xB7,
        kp_obrace = 0xB8,
        kp_cbrace = 0xB9,
        kp_tab = 0xBA,
        kp_backspace = 0xBB,
        kp_a = 0xBC,
        kp_b = 0xBD,
        kp_c = 0xBE,
        kp_d = 0xBF,
        kp_e = 0xC0,
        kp_f = 0xC1,
        kp_xor = 0xC2,
        kp_caret = 0xC3,
        kp_percent = 0xC4,
        kp_lessthan = 0xC5,
        kp_greaterthan = 0xC6,
        kp_ampersand = 0xC7,
        kp_double_ampersand = 0xC8,
        kp_vbar = 0xC9,
        kp_double_vbar = 0xCA,
        kp_colon = 0xCB,
        kp_octothorpe = 0xCC,
        kp_space = 0xCD,
        kp_at = 0xCE,
        kp_exclaim = 0xCF,
        kp_mem_store = 0xD0,
        kp_mem_recall = 0xD1,
        kp_mem_clear = 0xD2,
        kp_mem_add = 0xD3,
        kp_mem_subtract = 0xD4,
        kp_mem_multiply = 0xD5,
        kp_mem_divide = 0xD6,
        kp_plus_minus = 0xD7,
        kp_clear = 0xD8,
        kp_clear_entry = 0xD9,
        kp_binary = 0xDA,
        kp_octal = 0xDB,
        kp_decimal = 0xDC,
        kp_hexadecimal = 0xDD,
        lcontrol = 0xE0,
        lshift = 0xE1,
        lalt = 0xE2,
        lgui = 0xE3, // windows or apple key
        rcontrol = 0xE4,
        rshift = 0xE5,
        ralt = 0xE6,
        rgui = 0xE7, // windows or apple key

        _,
    };

    pub const LEDs = enum(u8) { // Page 0x08
        num_lock = 0x01,
        caps_lock = 0x02,
        scroll_lock = 0x03,
        compose = 0x04,
        kana = 0x05,
        shift = 0x07,

        _,
    };

    pub const Consumer = enum(u8) { // Page 0x0C
        consumer_control = 0x01,

        play = 0xB0,
        pause = 0xB1,
        record = 0xB2,
        fast_forward = 0xB3,
        rewind = 0xB4,
        next_track = 0xB5,
        prev_track = 0xB6,
        stop = 0xB7,
        eject = 0xB8,
        random_play = 0xB9,
        stop_eject = 0xCC,
        play_pause = 0xCD,
        mute = 0xE2,
        volume_up = 0xE9,
        volume_down = 0xEA,

        _,
    };

};

const log = std.log.scoped(.hid);

const Class = classes.Class;
const Subclass = classes.Subclass;
const Protocol = classes.Protocol;
const classes = @import("classes.zig");
const descriptor = @import("descriptor.zig");
const usb = @import("../usb.zig");
const std = @import("std");
