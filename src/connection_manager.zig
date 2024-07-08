const ConnectionManager = @This();

const std = @import("std");
const Address = std.net.Address;
const Stream = std.net.Stream;

peer: ?Stream = null,
address: Address,

pub fn connect(self: *ConnectionManager) !bool {
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
