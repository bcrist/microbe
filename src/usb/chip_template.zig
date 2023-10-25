const std = @import("std");
const usb = @import("microbe").usb;
const descriptor = usb.descriptor;
const endpoint = usb.endpoint;
const classes = usb.classes;
const SetupPacket = usb.SetupPacket;

pub const max_packet_size_bytes = 64;

pub fn init() void {
    // TODO
}

pub fn deinit() void {
    // TODO
}

pub fn handleBusReset() void {
    // TODO
}

pub fn pollEvents() usb.Events {
    // TODO
}

pub fn getSetupPacket() SetupPacket {
    // TODO
}

pub fn setAddress(address: u7) void {
    _ = address;
    // TODO
}

pub fn configureEndpoint(ed: descriptor.Endpoint) void {
    _ = ed;
    // TODO
}

pub const BufferIterator = struct {
    // TODO

    pub fn next(self: *BufferIterator) ?endpoint.BufferInfo {
        _ = self;
        // TODO
        return null;
    }
};
pub fn bufferIterator() BufferIterator { // buffers of endpoints that have finished their transfer
    return .{
        // TODO
    };
}

pub fn fillBufferIn(ep: endpoint.Index, offset: isize, data: []const u8) void {
    _ = data;
    _ = offset;
    _ = ep;
    // TODO
}

pub fn startTransferIn(ep: endpoint.Index, len: u16, pid: PID, last_buffer: bool) void {
    // TODO
}

pub fn startTransferOut(ep: endpoint.Index, len: u16, pid: PID, last_buffer: bool) void {
    // TODO
}

pub fn startStall(address: endpoint.Address) void {
    _ = address;
    // TODO
}

pub fn startNak(address: endpoint.Address) void {
    _ = address;
    // TODO
}
