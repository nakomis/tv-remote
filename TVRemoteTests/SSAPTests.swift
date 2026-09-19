import Testing
import Foundation
@testable import TVRemote

struct SSAPTests {

    @Test("Launch targets the system launcher over SSAP")
    func launchAppURI() {
        #expect(SSAP.launchApp == "ssap://system.launcher/launch")
    }

    @Test("The launch payload carries the app id webOS expects, and nothing else")
    func launchPayloadCarriesAppID() {
        let payload = SSAP.launchPayload(id: "com.nakomis.naktv")

        #expect(payload["id"] as? String == "com.nakomis.naktv")
        #expect(payload.count == 1)
    }

    @Test("Config carries NakTV's webOS app id")
    func nakTVAppIdDefault() {
        #expect(Config.nakTVAppId == "com.nakomis.naktv")
    }
}
