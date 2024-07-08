const ProtoParser = @This();
const std = @import("std");

delim: u8 = '\n',
index: usize = 0,
peer: ?std.net.Address = null,
port: ?u16 = null,
buf: []const u8,

const port_str = "port: ";
const peer_str = "peer: ";

const Field = union(enum) {
    port: u16,
    peer: std.net.Address,
};

pub fn init(buf: []const u8) ProtoParser {
    return .{
        .buf = buf,
    };
}

fn addressFromSlice(val: []const u8) !std.net.Address {
    var i: usize = 0;
    while (i < val.len and val[i] != ':') : (i += 1) {}
    var j = i;
    while (!std.ascii.isDigit(val[j])) : (j += 1) {}

    const port_start = j;
    while (std.ascii.isDigit(val[j])) : (j += 1) {}
    const port_end = port_start + j - port_start;
    std.log.debug("Address comp: {x} {x}", .{ val[0..i], val[port_start..port_end] });
    const port = try std.fmt.parseInt(u16, val[port_start..port_end], 10);
    return try std.net.Address.parseIp4(val[0..i], port);
}

fn getValue(self: *ProtoParser) ![]const u8 {
    var end_idx = self.index;
    while (end_idx < self.buf.len and self.buf[end_idx] != 0x10) : (end_idx += 1) {}
    if (end_idx >= self.buf.len) {
        return error{MissingValue}.MissingValue;
    }
    defer self.index = end_idx + 1;
    return self.buf[self.index..end_idx];
}

fn parseField(self: *ProtoParser) !Field {
    const len = peer_str.len;
    const next_field = self.buf[self.index .. len + self.index];
    self.index += len;

    std.log.debug("Next field: {x}", .{next_field});
    if (std.mem.eql(u8, next_field, port_str)) {
        return Field{ .port = try std.fmt.parseInt(u16, try self.getValue(), 10) };
    } else if (std.mem.eql(u8, next_field, peer_str)) {
        return Field{ .peer = try addressFromSlice(try self.getValue()) };
    }
    return error{InvalidField}.InvalidField;
}

pub fn parse(self: *ProtoParser) !void {
    std.log.debug("Response: {x}", .{self.buf});
    switch ((try self.parseField())) {
        .peer => |peer| {
            self.peer = peer;
            const next = try self.parseField();
            switch (next) {
                Field.peer => return error{DuplicatePeer}.DuplicatePeer,
                Field.port => |port| self.port = port,
            }
        },
        .port => |port| {
            self.port = port;
            switch ((try self.parseField())) {
                Field.peer => |peer| self.peer = peer,
                else => return error{MissingPeer}.MissingPeer,
            }
        },
    }
}

pub fn writeDelim(writer: anytype) !void {
    if (try writer.write(&.{0x10}) != 1) {
        return error{WriteFailure}.WriteFailure;
    }
}

pub fn writePeer(address: std.net.Address, writer: anytype) !void {
    if (try writer.write(peer_str) != port_str.len) {
        return error{WriteFailure}.WriteFailure;
    }
    try address.format("", .{}, writer);
}

pub fn writePort(port: u16, writer: anytype) !void {
    if (try writer.write(port_str) != port_str.len) {
        return error{WriteFailure}.WriteFailure;
    }
    try std.fmt.formatInt(
        port,
        10,
        std.fmt.Case.upper,
        .{},
        writer,
    );
}

pub fn isServer(self: *ProtoParser) !bool {
    if (self.port) |_| {
        return true;
    } else {
        return false;
    }
}

pub fn duWanQuanXunXi(stream: std.net.Stream, buf: []u8) ![]u8 {
    var len = try stream.reader().read(buf);
    while (true) {
        const read = try stream.reader().read(buf[len..]);
        if (read == 0) {
            std.log.debug("Connection closed: {d}", .{read});
            break;
        }
        len += read;
        if (len > 1 and buf[len - 1] == 0x10 and buf[len - 2] == 0x10) {
            std.log.debug("讀訊息完畢", .{});
            break;
        }
    }
    std.log.info("Received a message: {x}", .{buf[0..len]});
    return buf[0..len];
}

pub fn writeTerminator(writer: anytype) !void {
    if (try writer.write(&.{ 0x10, 0x10 }) != 2) {
        std.log.err("試試寫錯了", .{});
        return error{WriteFailure}.WriteFailure;
    }
}
