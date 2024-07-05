const std = @import("std");

pub fn main() !void {
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
            std.log.info("第一連線{?}", .{con1});
            con1 = con;
        }
    }
}
