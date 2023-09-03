pub fn ComptimeResourceValidator(comptime K: type, comptime resource_name: []const u8) type {
    comptime var owners: std.enums.EnumFieldStruct(K, Owner, .{}) = .{};

    return struct {
        pub fn reserve(comptime resource: K, comptime owner: [*:0]const u8) void {
            comptime {
                var actual_owner = @field(owners, @tagName(resource)).name;
                if (actual_owner[0] == 0) {
                    @field(owners, @tagName(resource)) = .{ .name = owner };
                } else {
                    @compileError(std.fmt.comptimePrint(
                        \\Attempted to reserve {s} {s} that's already owned!
                        \\   attempted owner: {s}
                        \\   actual owner: {s}
                        \\
                    , .{
                        resource_name,
                        @tagName(resource),
                        owner,
                        actual_owner,
                    }));
                }
            }
        }

        pub fn reserveAll(comptime array: []const K, comptime owner: [*:0]const u8) void {
            comptime {
                inline for (array) |resource| {
                    reserve(resource, owner);
                }
            }
        }

        pub fn isReserved(comptime resource: K) bool {
            return comptime @field(owners, @tagName(resource)).name[0] != 0;
        }

        pub fn getOwner(comptime resource: K) ?[*:0]const u8 {
            comptime var owner = @field(owners, @tagName(resource)).name;
            return comptime if (owner[0] == 0) null else owner;
        }
    };
}

pub fn RuntimeResourceValidator(comptime K: type, comptime resource_name: []const u8) type {
    return struct {
        var owners: std.enums.EnumFieldStruct(K, Owner, .{}) = .{};

        pub fn reserve(comptime resource: K, owner: [*:0]const u8) void {
            var current_owner = @field(owners, @tagName(resource)).name;
            if (current_owner[0] == 0) {
                @field(owners, @tagName(resource)) = .{ .name = owner };
            } else {
                std.log.err("{s} current owner: {s}", .{ @tagName(resource), current_owner });
                std.log.err("{s} attempted new owner: {s}", .{ @tagName(resource), owner });
                @panic("Attempted to reserve a " ++ resource_name ++ " that's already owned!");
            }
        }

        pub fn reserveAll(comptime resources: []const K, owner: [*:0]const u8) void {
            inline for (resources) |resource| {
                reserve(resource, owner);
            }
        }

        pub fn release(comptime resource: K, owner: [*:0]const u8) void {
            var current_owner = @field(owners, @tagName(resource)).name;
            if (current_owner == owner) {
                @field(owners, @tagName(resource)) = .{};
            } else {
                std.log.err("{s} current owner: {s}", .{ @tagName(resource), current_owner });
                std.log.err("{s} attempted release by: {s}", .{ @tagName(resource), owner });
                @panic("Attempted to release " ++ resource_name ++ " that's not owned by me!");
            }
        }

        pub fn releaseAll(comptime resources: []const K, owner: [*:0]const u8) void {
            inline for (resources) |resource| {
                release(resource, owner);
            }
        }

        pub fn areAnyReserved(comptime resources: []const K) bool {
            inline for (resources) |resource| {
                if (isReserved(resource)) {
                    return true;
                }
            }
            return false;
        }

        pub fn isReserved(comptime resource: K) bool {
            return @field(owners, @tagName(resource)).name[0] != 0;
        }

        pub fn getOwner(comptime resource: K) ?[*:0]const u8 {
            const owner = @field(owners, @tagName(resource)).name;
            return if (owner[0] == 0) null else owner;
        }

    };
}

pub fn NullResourceValidator(comptime K: type, comptime _: []const u8) type {
    return struct {
        pub fn reserve(comptime _: K, _: [*:0]const u8) void {}
        pub fn reserveAll(comptime _: []const K, _: [*:0]const u8) void {}
        pub fn release(comptime _: K, _: [*:0]const u8) void {}
        pub fn releaseAll(comptime _: []const K, _: [*:0]const u8) void {}
        pub fn areAnyReserved(comptime _: []const K) bool { return false; }
        pub fn isReserved(comptime _: K) bool { return false; }
        pub fn getOwner(comptime _: K) ?[*:0]const u8 { return null; }
    };
}

const Owner = struct {
    name: [*:0]const u8 = "",
};

const std = @import("std");
