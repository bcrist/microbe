pub const Class = enum (u8) {
    device = 0x00, // get class info from interface descriptor
    audio = 0x01, 
    cdc = 0x02, // communications device class
    hid = 0x03, // human interface device
    physical = 0x05,
    image = 0x06,
    printer = 0x07,
    msc = 0x08, // mass storage class
    hub = 0x09,
    cdc_data = 0x0A,
    smart_card = 0x0B,
    content_security = 0x0D,
    video = 0x0E,
    personal_health = 0x0F,
    audio_video = 0x10,
    billboard = 0x11,
    type_c_bridge = 0x12,
    bulk_display_protocol = 0x13,
    mctp_over_usb = 0x14,
    i3c = 0x3C,
    diagnostic_device = 0xDC,
    wireless_controller = 0xE0,
    miscellaneous = 0xEF,
    application_specific = 0xFE,
    vendor = 0xFF,
    _,
};

pub const Subclass = enum (u8) { zero = 0, _ };
pub const Protocol = enum (u8) { zero = 0, _ };

pub const Info = packed struct (u24) {
    class: Class,
    subclass: Subclass,
    protocol: Protocol,
};
