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
    const ip: [4]u8 = [4]u8{ 0, 0, 0, 0 };
    const addr = std.net.Address.initIp4(ip, 5850);
    var server = try addr.listen(.{});
    defer server.deinit();
    var con1: ?std.net.Server.Connection = null;
    while (true) {
        const con = try server.accept();
        if (con1) |c1| {
            std.log.info("第二連線{?}", .{con});
            std.log.info("Sending to 2...", .{});
            try c1.address.format("", .{}, con.stream.writer());
            std.log.info("Sending to 1...", .{});
            try con.address.format("", .{}, c1.stream.writer());
            std.log.info("完成了.", .{});
            break;
        } else {
            con1 = con;
            std.log.info("第一連線{?}", .{con1});
        }
    }
}

fn client(address: std.net.Address) !void {
    var stream = try std.net.tcpConnectToAddress(address);
    var buf = [1]u8{0} ** 14;
    var len: usize = undefined;
    len = 0;
    while (len < 11) {
        len = try stream.reader().read(&buf);
    }
    std.log.debug("yuh: {s} {s}", .{ buf[0..7], buf[7..] });
    const port = try std.fmt.parseInt(u16, buf[7..], 10);
    const ip4 = try std.net.Address.parseIp4(buf[0..7], port);
    std.log.debug("Got ip4: {?}", .{ip4});
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
