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

        // Sent concurrently, not in series. A target with no route now uses
        // its whole timeout rather than failing fast, and six sequential
        // three-second timeouts would leave the On button unresponsive for
        // the better part of twenty seconds. In parallel the whole thing is
        // bounded by one timeout.
        let attempts = targets
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .flatMap { target in ports.map { (target, $0) } }

        let outcomes = await withTaskGroup(
            of: (String, String?).self,
            returning: [(String, String?)].self
        ) { group in
            for (target, port) in attempts {
                group.addTask {
                    do {
                        try await send(packet, to: target, port: port)
                        return (target, nil)
                    } catch {
                        return (target, error.localizedDescription)
                    }
                }
            }
            var collected: [(String, String?)] = []
            for await outcome in group { collected.append(outcome) }
            return collected
        }

        var delivered: [String] = []
        var lastFailure: String?
        for (target, failure) in outcomes {
            if let failure {
                lastFailure = failure
            } else if !delivered.contains(target) {
                delivered.append(target)
            }
        }
        // Keep the caller's ordering rather than whichever task finished first.
        delivered = targets.filter { delivered.contains($0) }

        // Partial success is success: the global broadcast address in
        // particular is refused on some networks while the subnet one works,
        // and the packet only has to arrive once.
        guard !delivered.isEmpty else {
            throw Failure.sendFailed(
                "\(lastFailure ?? "no route to the broadcast address") "
                + "(tried \(targets.joined(separator: ", ")))"
            )
        }
        return delivered
    }

    /// How long to give one broadcast target before moving on.
    ///
    /// `NWConnection` does not fail when there is no route to a destination —
    /// it sits in `.waiting` indefinitely, which on a phone is the normal
    /// outcome for a subnet the device is not on. Without a bound, the
    /// continuation below is never resumed and power-on hangs forever with a
    /// spinner and no error.
    private static let perTargetTimeout: Duration = .seconds(3)

    private static func send(_ packet: Data, to host: String, port: NWEndpoint.Port) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await sendWithoutTimeout(packet, to: host, port: port) }
            group.addTask {
                try await Task.sleep(for: perTargetTimeout)
                throw Failure.sendFailed("no route to \(host):\(port.rawValue)")
            }
            try await group.next()
            group.cancelAll()
        }
    }

    private static func sendWithoutTimeout(_ packet: Data, to host: String, port: NWEndpoint.Port) async throws {
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
                case .waiting:
                    // Deliberately NOT a failure. iOS passes through
                    // `.waiting` on the way to `.ready` for a broadcast —
                    // typically reporting ENETDOWN ("network is down") for a
                    // moment while the route is brought up. Failing here
                    // breaks every send on a phone. The timeout above is what
                    // bounds a `.waiting` that never resolves.
                    break
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
