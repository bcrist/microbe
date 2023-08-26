const std = @import("std");
const builtin = @import("builtin");
const chip = @import("root").chip;

pub const Channel = chip.dma.Channel;

pub const reserve = impl.reserve;
pub const release = impl.release;
pub const isReserved = impl.isReserved;

const impl = if (builtin.mode == .Debug) struct {

    // EnumFieldStruct is buggy when using slices as the data type, so we wrap it in a struct:
    const ChannelOwner = struct {
        name: [*:0]const u8 = "",
    };

    const ChannelOwners = std.enums.EnumFieldStruct(Channel, ChannelOwner, .{});
    var channel_owners = ChannelOwners{};

    fn reserve(comptime channel: Channel, comptime owner: [*:0]const u8) void {
        var current_owner = @field(channel_owners, @tagName(channel)).name;
        if (current_owner[0] == 0) {
            @field(channel_owners, @tagName(channel)) = .{ .name = owner };
        } else {
            std.log.err("{s} current owner: {s}", .{ @tagName(channel), current_owner });
            std.log.err("{s} attempted new owner: {s}", .{ @tagName(channel), owner });
            @panic("Attempted to reserve a channel that's already owned!");
        }
    }

    fn release(comptime channel: Channel, comptime owner: [*:0]const u8) void {
        var current_owner = @field(channel_owners, @tagName(channel)).name;
        if (current_owner == owner) {
            @field(channel_owners, @tagName(channel)) = .{};
        } else {
            std.log.err("{s} current owner: {s}", .{ @tagName(channel), current_owner });
            std.log.err("{s} attempted release by: {s}", .{ @tagName(channel), owner });
            @panic("Attempted to release channel that's not owned by me!");
        }
    }

    fn isReserved(comptime channel: Channel) bool {
        return @field(channel_owners, @tagName(channel)).name[0] != 0;
    }
} else struct {
    var reserved_channels = std.EnumSet(Channel){};

    fn reserve(comptime channel: Channel, comptime _: [*:0]const u8) void {
        if (reserved_channels.contains(channel)) {
            @panic("Duplicate channel reservation!");
        } else {
            reserved_channels.insert(channel);
        }
    }

    fn release(comptime channel: Channel, comptime _: [*:0]const u8) void {
        if (!reserved_channels.contains(channel)) {
            @panic("Releasing unreserved channel!");
        } else {
            reserved_channels.remove(channel);
        }
    }

    fn isReserved(comptime channel: Channel) bool {
        return reserved_channels.contains(channel);
    }
};
