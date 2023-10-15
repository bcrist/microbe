const std = @import("std");
const classes = @import("classes.zig");
const Class = classes.Class;
const Subclass = classes.Subclass;
const Protocol = classes.Protocol;

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
