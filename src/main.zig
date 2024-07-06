const std = @import("std");

const os = std.os;

const Flags = enum {};

const Args = struct {
    iter: std.process.ArgIterator,
    pub fn init(alloc: std.mem.Allocator) !Args {
        var args = try std.process.ArgIterator.initWithAllocator(alloc);
        _ = args.next();
        return .{ .iter = args };
    }
    pub fn next(self: *Args) ?[]const u8 {
        return self.iter.next();
    }
    pub fn deinit(self: *Args) void {
        self.args.deinit();
    }
};

fn middle() !void {
    var server = try bindPort(5850);
    defer server.deinit();
    var con1: ?std.net.Server.Connection = null;
    while (true) {
        const con = try server.accept();
        if (con1) |c1| {
            std.log.info("第二連線{?}", .{con});
            std.log.info("傳送到二...", .{});
            try c1.address.format("", .{}, con.stream.writer());
            std.log.info("傳送到一...", .{});
            try con.address.format("", .{}, c1.stream.writer());
            std.log.info("完成了.", .{});
            break;
        } else {
            con1 = con;
            std.log.info("第一連線{?}", .{con1});
        }
    }
}

fn waitForMessage(stream: std.net.Stream) !void {
    var buf = [1]u8{0} ** 100;
    var len = try stream.reader().read(&buf);
    while (len == 0) {
        len = try stream.reader().read(&buf);
    }
    if (len == 0) {
        std.log.err("真的不好", .{});
        return error{cuole}.cuole;
    }
    std.log.info("Received a message: {s}", .{buf[0..len]});
}

fn bindPort(port: u16) !std.net.Server {
    const ip = [4]u8{ 0, 0, 0, 0 };
    const addr = std.net.Address.initIp4(ip, port);
    return try addr.listen(.{ .reuse_address = true });
}

fn addressFromString(buf: []const u8) !std.net.Address {
    var i: usize = 0;
    while (i < buf.len and buf[i] != ':') : (i += 1) {}
    var j = i;
    while (!std.ascii.isDigit(buf[j])) : (j += 1) {}
    const port_start = j;
    while (std.ascii.isDigit(buf[j])) : (j += 1) {}
    const port_end = port_start + j - port_start;
    std.log.debug("Address comp: {s} {s}", .{ buf[0..i], buf[port_start..port_end] });
    const port = try std.fmt.parseInt(u16, buf[port_start..port_end], 10);
    return try std.net.Address.parseIp4(buf[0..i], port);
}

fn client(address: std.net.Address) !void {
    var stream = try std.net.tcpConnectToAddress(address);
    var buf = [1]u8{0} ** 24;
    if (try stream.reader().read(&buf) == 0) {
        std.log.err("Connection closed...", .{});
        return error{ProxyConnectionClosed}.ProxyConnectionClosed;
    }
    const ip4 = try addressFromString(&buf);
    std.log.debug("Got ip4: {?}", .{ip4});

    var peer = try std.net.tcpConnectToAddress(address);
    if (try peer.writer().write("你好我愛你") == 0) {
        std.log.err("大過", .{});
        return error{cuole}.cuole;
    }
    try waitForMessage(peer);
}

pub fn main() !void {
    const len: u16 = 100;
    var buf = [1]u8{0} ** len;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    var args = try Args.init(fba.allocator());
    if (args.next()) |i| {
        std.log.debug("使用者. {s}", .{i});
        try client(try std.net.Address.parseIp4(i, 5850));
    } else {
        try middle();
    }
}
