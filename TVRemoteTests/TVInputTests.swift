import Testing
import Foundation
@testable import TVRemote

struct TVInputTests {

    @Test("An input decodes from the shape getExternalInputList returns")
    func decodesFromSSAP() throws {
        let json = Data("""
        { "id": "HDMI_2", "label": "Apple TV", "connected": true, "appId": "com.webos.app.hdmi2" }
        """.utf8)

        let input = try JSONDecoder().decode(TVInput.self, from: json)

        #expect(input.id == "HDMI_2")
        #expect(input.label == "Apple TV")
        #expect(input.connected)
        #expect(input.appId == "com.webos.app.hdmi2")
    }

    @Test("A missing label falls back to the id rather than an empty string")
    func labelFallsBackToID() throws {
        let json = Data(#"{ "id": "HDMI_3" }"#.utf8)
        let input = try JSONDecoder().decode(TVInput.self, from: json)

        #expect(input.label == "HDMI_3")
        #expect(!input.connected)
        #expect(input.appId == nil)
    }

    @Test("Inputs pick a symbol from their kind", arguments: [
        ("HDMI_1", "cable.connector"),
        ("TUNER", "antenna.radiowaves.left.and.right"),
        ("COMP_1", "av.remote"),
        ("SOMETHING_ELSE", "rectangle.on.rectangle"),
    ])
    func symbolMatchesKind(_ id: String, _ expected: String) {
        let input = TVInput(id: id, label: id, connected: true)
        #expect(input.symbolName == expected)
    }
}
