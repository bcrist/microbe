const std = @import("std");
const endpoint = @import("endpoint.zig");
const classes = @import("classes.zig");
const chip = @import("chip");

pub const Kind = enum (u8) {
    device = 0x01,
    configuration = 0x02,
    string = 0x03,
    interface = 0x04, // not directly queried; sent with configuration descriptor
    endpoint = 0x05, // not directly queried; sent with configuration descriptor
    device_qualifier = 0x06,
    interface_association = 0x0B,
    _
};

pub const Version = packed struct (u16) {
    rev: u4 = 0,
    minor: u4 = 0,
    major: u8,
};

pub const UsbVersion = enum (u16) {
    usb_1_1 = @bitCast(Version{ .major = 1, .minor = 1 }),
    usb_2_0 = @bitCast(Version{ .major = 2 }),
    _
};

pub const Device = packed struct (u144) {
    _len: u8 = @bitSizeOf(Device) / 8,
    _kind: Kind = .device,

    usb_version: UsbVersion,
    class: classes.Info,
    max_packet_size_bytes: u8 = chip.usb.max_packet_size_bytes,
    vendor_id: u16,
    product_id: u16,
    version: Version,
    manufacturer_name: StringID = .manufacturer_name,
    product_name: StringID = .product_name,
    serial_number: StringID = .serial_number,
    configuration_count: u8,
};

// A subset of the full device descriptor
pub const DeviceQualifier = packed struct (u80) {
    _len: u8 = @bitSizeOf(DeviceQualifier) / 8,
    _kind: Kind = .device_qualifier,

    usb_version: UsbVersion,
    class: classes.Info,
    max_packet_size_bytes: u8 = chip.usb.max_packet_size_bytes,
    configuration_count: u8,
    _reserved: u8 = 0,
};

pub const Configuration = packed struct (u72) {
    _len: u8 = @bitSizeOf(Configuration) / 8,
    _kind: Kind = .configuration,

    /// Total length of all descriptors in this configuration, concatenated.
    /// This will include this descriptor, plus at least one interface
    /// descriptor, plus each interface descriptor's endpoint descriptors.
    length_bytes: u16,
    interface_count: u8,
    number: u8,
    name: StringID,
    _bus_powered: bool = true, // must be set even if self_powered is set.
    self_powered: bool,
    remote_wakeup: bool, // device can signal for host to take it out of suspend
    _reserved: u5 = 0,
    max_current_ma_div2: u8,
};

// Note when using this, the device should use `classes.iad_device` instead of `classes.composite_device`
pub const InterfaceAssociation = packed struct (u64) {
    _len: u8 = @bitSizeOf(InterfaceAssociation) / 8,
    _kind: Kind = .interface_association,

    first_interface: u8,
    interface_count: u8,
    function_class: classes.Info,
    name: StringID,
};

pub const Interface = packed struct (u72) {
    _len: u8 = @bitSizeOf(Interface) / 8,
    _kind: Kind = .interface,

    number: u8,
    /// Allows a single interface to have several alternate interface
    /// settings, where each alternate increments this field. Normally there's
    /// only one, and `alternate_setting` is zero.
    alternate_setting: u8 = 0,
    endpoint_count: u8,
    class: classes.Info,
    name: StringID,

    pub fn parse(comptime info: type) Interface {
        return .{
            .number = info.index,
            .alternate_setting = if (@hasDecl(info, "alternate_setting")) info.alternate_setting else 0,
            .endpoint_count = @intCast(info.endpoints.len),
            .class = info.class,
            .name = if (@hasDecl(info, "name")) info.name else @enumFromInt(0),
        };
    }
};

pub const Endpoint = packed struct (u56) {
    _len: u8 = @bitSizeOf(Endpoint) / 8,
    _kind: Kind = .endpoint,

    address: endpoint.Address,
    transfer_kind: endpoint.TransferKind,
    synchronization: endpoint.Synchronization = .none,
    usage: endpoint.Usage = .data,
    _reserved: u2 = 0,
    max_packet_size_bytes: u16 = chip.usb.max_packet_size_bytes,
    poll_interval_ms: u8,

    pub fn parse(comptime info: type) Endpoint {
        return .{
            .address = info.address,
            .transfer_kind = info.kind,
            .synchronization = if (info.kind == .isochronous) info.synchronization else .none,
            .usage = if (info.kind == .isochronous) info.usage else .data,
            .max_packet_size_bytes = if (@hasDecl(info, "max_packet_size_bytes")) info.max_packet_size_bytes else chip.usb.max_packet_size_bytes,
            .poll_interval_ms = if (info.kind == .interrupt) info.poll_interval_ms else 0,
        };
    }
};

pub const ID = struct {
    kind: Kind,
    index: u8,
};

pub const StringID = enum (u8) {
    languages = 0,
    manufacturer_name = 1,
    product_name = 2,
    serial_number = 3,
    default_configuration_name = 4,
    default_interface_name = 5,
    _
};

pub fn String(comptime utf8: []const u8) type {
    const utf16_len = (std.unicode.calcUtf16LeLen(utf8) catch unreachable);
    comptime var utf16: [utf16_len]u16 = undefined;
    _ = comptime std.unicode.utf8ToUtf16Le(&utf16, utf8) catch unreachable;

    return extern struct {
        _len: u8 = @bitSizeOf(@This()) / 8,
        _kind: Kind = .string,
        data: [utf16_len]u16 = utf16,
    };
}

/// StringID 0 should map to this
pub fn SupportedLanguages(comptime languages: []const Language) type {
    const len = languages.len;
    const ptr: *const [len]Language = @ptrCast(languages);

    return extern struct {
        _len: u8 = @bitSizeOf(@This()) / 8,
        _kind: Kind = .string,
        data: [len]Language = ptr.*,
    };
}

pub const Language = enum (u16) {
    afrikaans = 0x0436,
    albanian = 0x041c,
    arabic_saudi_arabia = 0x0401,
    arabic_iraq = 0x0801,
    arabic_egypt = 0x0c01,
    arabic_libya = 0x1001,
    arabic_algeria = 0x1401,
    arabic_morocco = 0x1801,
    arabic_tunisia = 0x1c01,
    arabic_oman = 0x2001,
    arabic_yemen = 0x2401,
    arabic_syria = 0x2801,
    arabic_jordan = 0x2c01,
    arabic_lebanon = 0x3001,
    arabic_kuwait = 0x3401,
    arabic_uae = 0x3801,
    arabic_bahrain = 0x3c01,
    arabic_qatar = 0x4001,
    armenian = 0x042b,
    assamese = 0x044d,
    azeri_latin = 0x042c,
    azeri_cyrillic = 0x082c,
    basque = 0x042d,
    belarussian = 0x0423,
    bengali = 0x0445,
    bulgarian = 0x0402,
    burmese = 0x0455,
    catalan = 0x0403,
    chinese_taiwan = 0x0404,
    chinese_prc = 0x0804,
    chinese_hong_kong = 0x0c04,
    chinese_singapore = 0x1004,
    chinese_macau = 0x1404,
    croatian = 0x041a,
    czech = 0x0405,
    danish = 0x0406,
    dutch_netherlands = 0x0413,
    dutch_belgium = 0x0813,
    english_us = 0x0409,
    english_uk = 0x0809,
    english_australia = 0x0c09,
    english_canada = 0x1009,
    english_new_zealand = 0x1409,
    english_ireland = 0x1809,
    english_south_africa = 0x1c09,
    english_jamaica = 0x2009,
    english_caribbean = 0x2409,
    english_belize = 0x2809,
    english_trinidad = 0x2c09,
    english_zimbabwe = 0x3009,
    english_phillippines = 0x3409,
    estonian = 0x0425,
    faeroese = 0x0438,
    farsi = 0x0429,
    finnish = 0x040b,
    french_standard = 0x040c,
    french_belgiun = 0x080c,
    french_canada = 0x0c0c,
    french_switzerland = 0x100c,
    french_luxembourg = 0x140c,
    french_monaco = 0x180c,
    georgian = 0x0437,
    german_standard = 0x0407,
    german_switzerland = 0x0807,
    german_austria = 0x0c07,
    german_luxembourg = 0x1007,
    german_liechtenstein = 0x1407,
    greek = 0x0408,
    gujarati = 0x0447,
    hebrew = 0x040d,
    hindi = 0x0439,
    hungarian = 0x040e,
    icelandic = 0x040f,
    indonesian = 0x0421,
    italian_standard = 0x0410,
    italian_switzerland = 0x0810,
    japanese = 0x0411,
    kannada = 0x044b,
    kashmiri = 0x0860,
    kazakh = 0x043f,
    konkani = 0x0457,
    korean = 0x0412,
    korean_johab = 0x0812,
    latvian = 0x0426,
    lithuanian = 0x0427,
    lithuanian_classic = 0x0827,
    macedonian = 0x042f,
    malay_malaysia = 0x043e,
    malay_brunei_darussalam = 0x083e,
    malayalam = 0x044c,
    manipuri = 0x0458,
    marathi = 0x044e,
    nepali = 0x0861,
    norwegian_bokmal = 0x0414,
    norwegian_nynorsk = 0x0814,
    oriya = 0x0448,
    polish = 0x0415,
    portuguese_brazil = 0x0416,
    portuguese_standard = 0x0816,
    punjabi = 0x0446,
    romanian = 0x0418,
    russian = 0x0419,
    sanskrit = 0x044f,
    serbian_cyrillic = 0x0c1a,
    serbian_latin = 0x081a,
    sindhi = 0x0459,
    slovak = 0x041b,
    slovenian = 0x0424,
    spanish_traditional = 0x040a,
    spanish_mexico = 0x080a,
    spanish_modern = 0x0c0a,
    spanish_guatemala = 0x100a,
    spanish_costa_rica = 0x140a,
    spanish_panama = 0x180a,
    spanish_dominican_republic = 0x1c0a,
    spanish_venezuela = 0x200a,
    spanish_colombia = 0x240a,
    spanish_peru = 0x280a,
    spanish_argentina = 0x2c0a,
    spanish_ecuador = 0x300a,
    spanish_chile = 0x340a,
    spanish_uruguay = 0x380a,
    spanish_paraguay = 0x3c0a,
    spanish_bolivia = 0x400a,
    spanish_el_salvador = 0x440a,
    spanish_honduras = 0x480a,
    spanish_nicaragua = 0x4c0a,
    spanish_puerto_rico = 0x500a,
    sutu = 0x0430,
    swahili = 0x0441,
    swedish = 0x041d,
    swedish_finland = 0x081d,
    tamil = 0x0449,
    tatar = 0x0444,
    telugu = 0x044a,
    thai = 0x041e,
    turkish = 0x041f,
    ukrainian = 0x0422,
    urdu_pakistan = 0x0420,
    urdu_india = 0x0820,
    uzbek_latin = 0x0443,
    uzbek_cyrillic = 0x0843,
    vietnamese = 0x042a,
    hid_usage_data_descriptor = 0x04ff,
    hid_vendor_1 = 0xf0ff,
    hid_vendor_2 = 0xf4ff,
    hid_vendor_3 = 0xf8ff,
    hid_vendor_4 = 0xfcff,
};
