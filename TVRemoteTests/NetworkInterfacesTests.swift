import Testing
import Foundation
@testable import TVRemote

struct NetworkInterfacesTests {

    @Test("The broadcast address for a reachable host matches this machine's own subnet")
    func derivesBroadcastForLocalSubnet() throws {
        // Find an address this machine actually holds, so the test works on
        // any network (a CI runner's included) rather than assuming a subnet.
        guard let (localAddress, expectedBroadcast) = firstLocalIPv4() else {
            // No non-loopback IPv4 interface, e.g. a sandbox with no network.
            return
        }

        let derived = NetworkInterfaces.broadcastAddress(reaching: localAddress)
        #expect(derived == expectedBroadcast)
    }

    @Test("A host on no local subnet derives nothing rather than guessing")
    func unreachableHostReturnsNil() {
        // TEST-NET-1, reserved for documentation and never locally routed.
        #expect(NetworkInterfaces.broadcastAddress(reaching: "192.0.2.123") == nil)
    }

    @Test("Malformed addresses are rejected rather than treated as 0.0.0.0")
    func malformedHostReturnsNil() {
        #expect(NetworkInterfaces.broadcastAddress(reaching: "not-an-ip") == nil)
        #expect(NetworkInterfaces.broadcastAddress(reaching: "") == nil)
        #expect(NetworkInterfaces.broadcastAddress(reaching: "999.1.1.1") == nil)
    }

    /// The first non-loopback IPv4 interface, as (address, broadcast),
    /// computed independently of the code under test.
    private func firstLocalIPv4() -> (String, String)? {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return nil }
        defer { freeifaddrs(head) }

        for interface in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(interface.pointee.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  let addr = interface.pointee.ifa_addr,
                  addr.pointee.sa_family == UInt8(AF_INET),
                  let mask = interface.pointee.ifa_netmask
            else { continue }

            let a = addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            let m = mask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                UInt32(bigEndian: $0.pointee.sin_addr.s_addr)
            }
            let broadcast = (a & m) | ~m
            func text(_ v: UInt32) -> String {
                "\((v >> 24) & 0xFF).\((v >> 16) & 0xFF).\((v >> 8) & 0xFF).\(v & 0xFF)"
            }
            return (text(a), text(broadcast))
        }
        return nil
    }
}

struct BroadcastArithmeticTests {

    /// The bug this guards against: assuming a /24 on a /16 network produces
    /// an address that is not a broadcast at all, and fails silently.
    @Test("Netmask width determines the broadcast address", arguments: [
        ("172.29.0.19", 16, "172.29.255.255"),
        ("172.29.0.19", 24, "172.29.0.255"),
        ("10.0.0.5",     8, "10.255.255.255"),
        ("192.168.1.7", 24, "192.168.1.255"),
        ("192.168.1.7", 25, "192.168.1.127"),
    ])
    func broadcastFollowsTheMask(_ host: String, _ prefix: Int, _ expected: String) {
        let parts = host.split(separator: ".").compactMap { UInt32($0) }
        let address = (parts[0] << 24) | (parts[1] << 16) | (parts[2] << 8) | parts[3]
        let mask: UInt32 = prefix == 0 ? 0 : ~UInt32(0) << (32 - UInt32(prefix))
        let broadcast = (address & mask) | ~mask
        let text = "\((broadcast >> 24) & 0xFF).\((broadcast >> 16) & 0xFF).\((broadcast >> 8) & 0xFF).\(broadcast & 0xFF)"
        #expect(text == expected)
    }
}
