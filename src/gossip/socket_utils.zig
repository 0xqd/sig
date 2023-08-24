const UdpSocket = @import("zig-network").Socket;
const Packet = @import("../gossip/packet.zig").Packet;
const PACKET_DATA_SIZE = @import("../gossip/packet.zig").PACKET_DATA_SIZE;
const Channel = @import("../sync/channel.zig").Channel;
const std = @import("std");

pub fn read_socket(
    socket: *UdpSocket,
    send_channel: *Channel(Packet),
    exit: *std.atomic.Atomic(bool),
) error{ SocketReadError, OutOfMemory, ChannelClosed }!void {
    defer send_channel.close();

    var read_buf: [PACKET_DATA_SIZE]u8 = undefined;
    var bytes_read: usize = undefined;

    while (bytes_read != 0) {
        if (exit.load(std.atomic.Ordering.Unordered)) {
            break;
        }

        var recv_meta = socket.receiveFrom(&read_buf) catch return error.SocketReadError;
        bytes_read = recv_meta.numberOfBytes;

        // send packet through channel
        const packet = Packet.init(recv_meta.sender, read_buf, bytes_read);
        try send_channel.send(packet);
    }
}

pub fn send_socket(
    socket: *UdpSocket,
    recv_channel: *Channel(Packet),
) !void {
    defer recv_channel.close();

    while (recv_channel.receive()) |p| {
        _ = try socket.sendTo(p.addr, p.data[0..p.size]);
    }
}
