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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    var alloc = arena.allocator();
    while (true) {
        const con = try server.accept();

        if (con1) |c1| {
            defer {
                c1.stream.close();
                con.stream.close();
            }
            std.log.info("第二連線{any}", .{con});
            std.log.info("傳送到二：自己的數字：「{d}」", .{con.address.in.getPort()});
            const buf = try alloc.alloc(u8, 128);
            const writer = con.stream.writer(buf);
            var interface = writer.interface;
            try ProtoParser.writePort(con.address.in.getPort(), &interface);
            try ProtoParser.writeDelim(&interface);
            try ProtoParser.writePeer(c1.address, &interface);
            try ProtoParser.writeTerminator(&interface);

            std.log.info("傳送到一: 自己的數字：「{f}」", .{c1.address});
            const c1_buf = try alloc.alloc(u8, 128);
            const c1_writer = con.stream.writer(c1_buf);
            var c1_interface = c1_writer.interface;
            try ProtoParser.writePeer(con.address, &c1_interface);
            try ProtoParser.writeTerminator(&c1_interface);

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
    var reader = stream.reader(&buf);
    const xunxi = try ProtoParser.duWanQuanXunXi(reader.interface());

    var response = ProtoParser.init(xunxi);
    try response.parse();
    std.log.debug("Got ip4: {any}", .{response.peer});

    if (response.port) |port| {
        // 因為有數字，是服務員
        var server = try bindPort(port);
        defer server.deinit();
        std.log.debug("Bound to port: {d}", .{port});
        const con = try server.accept();
        var newbuf = [1]u8{0} ** 32;
        reader = con.stream.reader(&newbuf);
        var interface = reader.interface();
        _ = try interface.peek(1);
        std.log.debug("{s}", .{newbuf});
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        var arena = std.heap.ArenaAllocator.init(gpa.allocator());
        var cm = ConnectionManager{
            .address = response.peer orelse return client_errors.MissingPeer,
            .xintiao_jiange = 1500,
            .alloc = arena.allocator(),
        };
        defer cm.deinit();
        defer arena.deinit();
        try cm.connect(10, 750);
    } else if (response.peer) |peer_addr| {
        var gpa = std.heap.GeneralPurposeAllocator(.{}){};
        var arena = std.heap.ArenaAllocator.init(gpa.allocator());
        var cm = ConnectionManager{ .address = peer_addr, .alloc = arena.allocator() };
        defer cm.deinit();
        defer arena.deinit();
        try cm.connect(0, 750);
        try cm.xintiao();
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
