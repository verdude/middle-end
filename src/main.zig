const std = @import("std");
const ProtoParser = @import("./proto.zig");
const ConnectionManager = @import("./connection_manager.zig");

const os = std.os;

const client_errors = error{ MissingPeer, BadResponse };

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
            defer {
                c1.stream.close();
                con.stream.close();
            }

            std.log.info("第二連線{?}", .{con});
            std.log.info("傳送到二：自己的數字：「{d}」", .{con.address.in.getPort()});
            try ProtoParser.writePort(con.address.in.getPort(), con.stream.writer());
            try ProtoParser.writeDelim(con.stream.writer());
            try ProtoParser.writePeer(c1.address, con.stream.writer());
            try ProtoParser.writeTerminator(con.stream.writer());

            std.log.info("傳送到一: 自己的數字：「{?}」", .{c1});
            try ProtoParser.writePeer(con.address, c1.stream.writer());
            try ProtoParser.writeTerminator(c1.stream.writer());

            std.log.info("完成了.", .{});
            break;
        } else {
            con1 = con;
            std.log.info("第一連線{?}", .{con1});
        }
    }
}

fn client(address: std.net.Address) !void {
    const stream = try std.net.tcpConnectToAddress(address);
    defer stream.close();
    const blen = 1024;
    var buf = [1]u8{0} ** blen;
    const xunxi = try ProtoParser.duWanQuanXunXi(stream, buf[0..blen]);

    var response = ProtoParser.init(xunxi);
    try response.parse();
    std.log.debug("Got ip4: {?}", .{response.peer});

    if (response.port) |port| {
        // 因為有數字，是服務員
        var server = try bindPort(port);
        defer server.deinit();
        std.log.debug("Bound to port: {d}", .{port});
        const con = try server.accept();
        var len: usize = 0;
        var newbuf = [1]u8{0} ** 32;
        while (len == 0) {
            len = try con.stream.reader().read(newbuf[0..]);
        }
        std.log.debug("{s}", .{newbuf});
        var gpa = std.heap.GeneralPurposeAllocator{};
        var cm = ConnectionManager{
            .address = response.peer orelse return client_errors.MissingPeer,
            .xintiao_jiange = 1500,
            .alloc = gpa.allocator(),
        };
        defer cm.deinit();
        try cm.connect(10, 750);
    } else if (response.peer) |peer_addr| {
        var cm = ConnectionManager{ .address = peer_addr };
        defer cm.deinit();
        try cm.connect(0, 750);
        try cm.heartbeat();
    } else {
        std.log.err("Large error", .{});
        return client_errors.BadResponse;
    }
}

fn bindPort(port: u16) !std.net.Server {
    const ip = [4]u8{ 0, 0, 0, 0 };
    const addr = std.net.Address.initIp4(ip, port);
    return try addr.listen(.{ .reuse_address = true });
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
