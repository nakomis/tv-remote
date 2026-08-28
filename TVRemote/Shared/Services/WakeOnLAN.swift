import Foundation
import Network
import os

/// Sends Wake-on-LAN magic packets.
///
/// A television in standby has no IP stack running, so there is nothing to
/// connect to — SSAP cannot turn it on. What *is* still running is the network
/// interface itself, watching every frame that reaches it for a "magic packet":
/// six `0xFF` bytes followed by the interface's own MAC address repeated
/// sixteen times. Seeing that pattern is what wakes the set.
///
/// Because the TV has no address to be sent to, the packet must be broadcast.
enum WakeOnLAN {

    enum Failure: LocalizedError {
        case malformedMAC(String)
        case sendFailed(String)

        var errorDescription: String? {
            switch self {
            case .malformedMAC(let mac):
                "\"\(mac)\" is not a valid MAC address. Expected six hex pairs, e.g. 20:28:bc:bb:5d:60."
            case .sendFailed(let reason):
                "Could not send the wake packet: \(reason)"
            }
        }
    }

    /// Builds the 102-byte magic packet for a MAC address.
    ///
    /// Accepts `:`, `-`, `.` or no separator at all, in any case.
    static func magicPacket(for mac: String) throws -> Data {
        let hex = mac.filter(\.isHexDigit).lowercased()
        guard hex.count == 12 else { throw Failure.malformedMAC(mac) }

        var bytes = [UInt8]()
        var index = hex.startIndex
        while index < hex.endIndex {
            let next = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<next], radix: 16) else {
                throw Failure.malformedMAC(mac)
            }
            bytes.append(byte)
            index = next
        }

        var packet = Data(repeating: 0xFF, count: 6)
        for _ in 0..<16 { packet.append(contentsOf: bytes) }
        return packet
    }

    /// Broadcasts the magic packet for `mac`.
    ///
    /// Targets, in order: the broadcast address derived from whichever local
    /// interface is actually on the television's subnet, then the configured
    /// one, then the global broadcast address — each on both conventional WoL
    /// ports (9, discard, and 7, echo). Firmware and routers vary in which
    /// they honour, and the packets are 102 bytes, so sending to all of them
    /// is cheaper than diagnosing which was needed.
    ///
    /// The derived address comes first because a configured one is a guess
    /// about the netmask, and a wrong guess fails silently: a "broadcast"
    /// address that is not one gets treated as an ordinary unicast to a
    /// non-existent host and dropped, with no error anywhere.
    @discardableResult
    static func wake(mac: String, host: String, broadcast: String) async throws -> [String] {
        let packet = try magicPacket(for: mac)

        var targets: [String] = []
        if let derived = NetworkInterfaces.broadcastAddress(reaching: host) {
            targets.append(derived)
        }
        for candidate in [broadcast, "255.255.255.255"] where !targets.contains(candidate) {
            targets.append(candidate)
        }
        let ports: [NWEndpoint.Port] = [9, 7]

        var lastFailure: String?
        var delivered = false

        for target in targets where !target.trimmingCharacters(in: .whitespaces).isEmpty {
            for port in ports {
                do {
                    try await send(packet, to: target, port: port)
                    delivered = true
                } catch {
                    lastFailure = error.localizedDescription
                }
            }
        }

        if !delivered {
            throw Failure.sendFailed(lastFailure ?? "no route to the broadcast address")
        }
        return targets
    }

    private static func send(_ packet: Data, to host: String, port: NWEndpoint.Port) async throws {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        // Required for 255.255.255.255 and subnet broadcast: without it the
        // stack refuses to send to a broadcast destination.
        if let ip = parameters.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options {
            ip.version = .v4
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: port,
            using: parameters
        )

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let resumed = OSAllocatedUnfairLock(initialState: false)

            @Sendable func finish(_ result: Result<Void, Error>) {
                let alreadyResumed = resumed.withLock { state -> Bool in
                    defer { state = true }
                    return state
                }
                guard !alreadyResumed else { return }
                connection.cancel()
                continuation.resume(with: result)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: packet, completion: .contentProcessed { error in
                        if let error {
                            finish(.failure(Failure.sendFailed(error.localizedDescription)))
                        } else {
                            finish(.success(()))
                        }
                    })
                case .failed(let error):
                    finish(.failure(Failure.sendFailed(error.localizedDescription)))
                case .cancelled:
                    finish(.failure(Failure.sendFailed("connection cancelled")))
                default:
                    break
                }
            }

            connection.start(queue: .global(qos: .userInitiated))
        }
    }
}
