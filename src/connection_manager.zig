const ConnectionManager = @This();

const std = @import("std");
const Address = std.net.Address;
const Stream = std.net.Stream;

const errors = error{
    ConnectAttemptsExceeded,
    NoPeer,
};

peer: ?Stream = null,
address: Address,
xintiao_jiange: u64 = 1500,
alloc: std.mem.Allocator,

pub fn tryConnect(self: *ConnectionManager) !bool {
    if (self.peer) |_| {
        std.log.warn("Already connected", .{});
        return true;
    }
    const s: ?Stream = std.net.tcpConnectToAddress(self.address) catch null;
    if (s) |stream| {
        self.peer = stream;
        return true;
    }
    return false;
}

pub fn connect(self: *ConnectionManager, n: u8, ms: u64) !void {
    var attempts = n;
    while (true) {
        if (try self.tryConnect()) {
            std.log.debug("連線了", .{});
            return;
        }

        if (attempts == 1) {
            return errors.ConnectAttemptsExceeded;
        }

        if (attempts > 1) {
            std.log.debug("無法連線。可以試試再{d}次。", .{attempts});
            std.Thread.sleep(ms * 1000);
            attempts -= 1;
        }
    }
}

pub fn deinit(self: *ConnectionManager) void {
    if (self.peer) |peer| {
        peer.close();
    }
}

fn read(self: *ConnectionManager) ![]const u8 {
    if (self.peer) |peer| {
        const data = self.alloc.alloc(u8, 20);
        if (try peer.reader().read(data) > 0) {
            return data;
        }
        std.log.debug("連線關了", .{});
    } else {
        return errors.NoPeer;
    }
}

pub fn xintiao(self: *ConnectionManager) !void {
    if (self.peer) |peer| {
        const buf = try self.alloc.alloc(u8, 32);
        const writer = peer.writer(buf);
        var interface = writer.interface;
        while (true) {
            try interface.writeAll("心跳");
            std.log.debug("傳送心跳了", .{});
            std.Thread.sleep(self.xintiao_jiange);
        }
    } else {
        return errors.NoPeer;
    }
}
