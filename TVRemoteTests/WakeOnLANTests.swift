import Testing
import Foundation
@testable import TVRemote

struct WakeOnLANTests {

    @Test("A magic packet is six 0xFF bytes then the MAC sixteen times")
    func packetShape() throws {
        let packet = try WakeOnLAN.magicPacket(for: "20:28:bc:bb:5d:60")

        #expect(packet.count == 102)
        #expect(packet.prefix(6).allSatisfy { $0 == 0xFF })

        let mac: [UInt8] = [0x20, 0x28, 0xBC, 0xBB, 0x5D, 0x60]
        for repetition in 0..<16 {
            let start = 6 + repetition * 6
            let slice = Array(packet[start..<(start + 6)])
            #expect(slice == mac, "repetition \(repetition) did not match the MAC")
        }
    }

    @Test("Separators and case in the MAC are irrelevant", arguments: [
        "20:28:bc:bb:5d:60",
        "20-28-BC-BB-5D-60",
        "2028.bcbb.5d60",
        "2028BCBB5D60",
    ])
    func separatorsAreIgnored(_ mac: String) throws {
        let packet = try WakeOnLAN.magicPacket(for: mac)
        let canonical = try WakeOnLAN.magicPacket(for: "20:28:bc:bb:5d:60")
        #expect(packet == canonical)
    }

    @Test("A MAC of the wrong length is rejected", arguments: [
        "20:28:bc:bb:5d",
        "20:28:bc:bb:5d:60:71",
        "",
        "not a mac at all",
    ])
    func malformedMACsThrow(_ mac: String) {
        #expect(throws: WakeOnLAN.Failure.self) {
            _ = try WakeOnLAN.magicPacket(for: mac)
        }
    }
}
