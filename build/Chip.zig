name: []const u8,
dependency_name: []const u8,
module_name: []const u8,
core: Core,
memory_regions: []const Memory_Region,
single_threaded: bool = true,
entry_point: []const u8 = "_boot2",
extra_config: []const ExtraOption = &.{},

pub const ExtraOption = struct {
    name: []const u8,
    value: []const u8,
    escape: bool = false,
};

const Core = @import("Core.zig");
const Memory_Region = @import("Memory_Region.zig");
