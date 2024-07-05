const std = @import("std");

pub fn main() !void {
    const ip: [4]u8 = [4]u8{ 0, 0, 0, 0 };
    const addr = std.net.Address.initIp4(ip, 5850);
    var server = try addr.listen(.{});
    const con1 = try server.accept();
    std.log.debug("hehe {?}", .{con1});
}
