const std = @import("std");
const usb = @import("microbe").usb;
const descriptor = usb.descriptor;
const endpoint = usb.endpoint;
const classes = usb.classes;
const Setup_Packet = usb.Setup_Packet;
const PID = usb.PID;

pub const max_packet_size_bytes = 64;

pub fn init() void {
    // TODO
}

pub fn deinit() void {
    // TODO
}

pub fn handle_bus_reset() void {
    // TODO
}

pub fn poll_events() usb.Events {
    // TODO
}

pub fn get_setup_packet() Setup_Packet {
    // TODO
}

pub fn set_address(address: u7) void {
    _ = address; // autofix
    // TODO
}

pub fn configure_endpoint(ed: descriptor.Endpoint) void {
    _ = ed; // autofix
    // TODO
}

pub const Buffer_Iterator = struct {
    // TODO

    pub fn next(self: *Buffer_Iterator) ?endpoint.Buffer_Info {
        _ = self; // autofix
        // TODO
        return null;
    }
};
pub fn buffer_iterator() Buffer_Iterator { // buffers of endpoints that have finished their transfer
    return .{
        // TODO
    };
}

pub fn fill_buffer_in(ep: endpoint.Index, offset: isize, data: []const u8) void {
    _ = ep; // autofix
    _ = offset; // autofix
    _ = data; // autofix
    // TODO
}

pub fn start_transfer_in(ep: endpoint.Index, len: u16, pid: PID, last_buffer: bool) void {
    _ = ep; // autofix
    _ = len; // autofix
    _ = pid; // autofix
    _ = last_buffer; // autofix
    // TODO
}

pub fn start_transfer_out(ep: endpoint.Index, len: u16, pid: PID, last_buffer: bool) void {
    _ = ep; // autofix
    _ = len; // autofix
    _ = pid; // autofix
    _ = last_buffer; // autofix
    // TODO
}

pub fn start_stall(address: endpoint.Address) void {
    _ = address; // autofix
    // TODO
}

pub fn start_nak(address: endpoint.Address) void {
    _ = address;
    // TODO
}
