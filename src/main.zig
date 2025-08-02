const std = @import("std");
const http = std.http;
const Mutex = std.Thread.Mutex;
const Thread = std.Thread;

var server: std.net.Server = undefined;

var workerIdx: usize = 0;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const cores = try Thread.getCpuCount();

    const address = try std.net.Address.parseIp("127.0.0.1", 8081);
    server = try address.listen(std.net.Address.ListenOptions{ .reuse_address = true, .reuse_port = true });
    defer server.deinit();

    var threads = try allocator.alloc(Thread, cores);
    for (0..cores) |i| {
        threads[i] = try Thread.spawn(.{}, worker, .{});
    }

    for (0..cores) |i| {
        threads[i].join();
    }
}

pub fn worker() !void {
    var buffer: [1024]u8 = undefined;
    while (true) {
        var conn = try server.accept();
        defer conn.stream.close();
        var http_server = std.http.Server.init(conn, &buffer);
        var req = try http_server.receiveHead();
        try req.respond("hello world", std.http.Server.Request.RespondOptions{});
    }
}
