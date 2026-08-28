import Foundation

#if canImport(Darwin)
import Darwin
#endif

/// Finds the broadcast address for the subnet a given host sits on.
///
/// Wake-on-LAN has to be broadcast, and the correct broadcast address depends
/// entirely on the netmask: on a /24 network `172.29.0.19` broadcasts to
/// `172.29.0.255`, but on a /16 it is `172.29.255.255`. Hard-coding either one
/// is a guess, and a wrong guess fails silently — the packet is treated as an
/// ordinary unicast to a host that does not exist, gets ARPed for, and is
/// dropped. Nothing reports an error; the television simply never wakes.
///
/// So ask the system instead. This walks the machine's interfaces, finds the
/// one whose subnet actually contains the television, and computes the
/// broadcast address from that interface's own mask.
enum NetworkInterfaces {

    /// The broadcast address of the local subnet containing `host`,
    /// or `nil` if no interface is on the same subnet.
    static func broadcastAddress(reaching host: String) -> String? {
        guard let target = ipv4(from: host) else { return nil }

        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        for interface in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(interface.pointee.ifa_flags)
            guard flags & IFF_UP != 0,
                  flags & IFF_LOOPBACK == 0,
                  let addressPointer = interface.pointee.ifa_addr,
                  addressPointer.pointee.sa_family == UInt8(AF_INET),
                  let maskPointer = interface.pointee.ifa_netmask
            else { continue }

            let address = ipv4(from: addressPointer)
            let mask = ipv4(from: maskPointer)

            // Same subnet as the television?
            guard address & mask == target & mask else { continue }

            // Broadcast is the network address with every host bit set.
            return string(from: (address & mask) | ~mask)
        }
        return nil
    }

    // MARK: - Conversions

    private static func ipv4(from text: String) -> UInt32? {
        var address = in_addr()
        guard inet_pton(AF_INET, text, &address) == 1 else { return nil }
        return UInt32(bigEndian: address.s_addr)
    }

    private static func ipv4(from pointer: UnsafeMutablePointer<sockaddr>) -> UInt32 {
        pointer.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
            UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
        }
    }

    private static func string(from address: UInt32) -> String {
        "\((address >> 24) & 0xFF).\((address >> 16) & 0xFF).\((address >> 8) & 0xFF).\(address & 0xFF)"
    }
}
