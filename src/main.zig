const std = @import("std");
const http = std.http;
const Mutex = std.Thread.Mutex;
const Thread = std.Thread;

var server: std.net.Server = undefined;

var workerIdx: usize = 0;

threadlocal var buffer: [1024]u8 = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    const cores = try Thread.getCpuCount();

    var pool: Thread.Pool = undefined;
    try pool.init(.{ .allocator = allocator, .n_jobs = cores });
    defer pool.deinit();

    const address = try std.net.Address.parseIp("127.0.0.1", 8081);
    server = try address.listen(std.net.Address.ListenOptions{ .reuse_address = true, .reuse_port = true });
    defer server.deinit();
    while (true) {
        const conn = try server.accept();
        try pool.spawn(worker, .{conn});
    }

    var threads = try allocator.alloc(Thread, cores);
    for (0..cores) |i| {
        threads[i] = try Thread.spawn(.{}, worker, .{});
    }

    for (0..cores) |i| {
        threads[i].join();
    }
}

pub fn worker(conn: std.net.Server.Connection) void {
    workerInner(conn) catch |err| {
        std.debug.print("{}\n", .{err});
        return;
    };
}

fn workerInner(conn: std.net.Server.Connection) !void {
    defer conn.stream.close();
    var http_server = std.http.Server.init(conn, &buffer);
    var req = try http_server.receiveHead();
    try req.respond("hello world", std.http.Server.Request.RespondOptions{});
}
