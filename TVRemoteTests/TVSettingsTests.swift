import Testing
import Foundation
@testable import TVRemote

@MainActor
struct TVSettingsTests {

    private func isolatedDefaults() -> UserDefaults {
        let name = "tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test("A fresh install uses the values compiled into Config")
    func defaultsComeFromConfig() {
        let settings = TVSettings(defaults: isolatedDefaults())
        #expect(settings.host == Config.defaultHost)
        #expect(settings.mac == Config.defaultMAC)
        #expect(settings.broadcast == Config.defaultBroadcast)
        #expect(settings.useTLS == Config.defaultUseTLS)
    }

    @Test("Overrides survive a restart")
    func overridesPersist() {
        let defaults = isolatedDefaults()
        let first = TVSettings(defaults: defaults)
        first.host = "10.0.0.5"

        let second = TVSettings(defaults: defaults)
        #expect(second.host == "10.0.0.5")
    }

    @Test("Clearing a field falls back to the Config default rather than empty")
    func clearingRestoresDefault() {
        let defaults = isolatedDefaults()
        let settings = TVSettings(defaults: defaults)
        settings.host = "10.0.0.5"
        settings.host = "   "

        #expect(TVSettings(defaults: defaults).host == Config.defaultHost)
    }

    @Test("The socket URL follows the TLS toggle")
    func socketURLFollowsTLS() {
        let settings = TVSettings(defaults: isolatedDefaults())
        settings.host = "10.0.0.5"

        settings.useTLS = false
        #expect(settings.socketURL?.absoluteString == "ws://10.0.0.5:\(Config.plainPort)")

        settings.useTLS = true
        #expect(settings.socketURL?.absoluteString == "wss://10.0.0.5:\(Config.tlsPort)")
    }

    @Test("Restoring defaults clears every override")
    func resetClearsOverrides() {
        let defaults = isolatedDefaults()
        let settings = TVSettings(defaults: defaults)
        settings.host = "10.0.0.5"
        settings.mac = "aa:bb:cc:dd:ee:ff"
        settings.useTLS = true

        settings.resetToDefaults()

        #expect(settings.host == Config.defaultHost)
        #expect(settings.mac == Config.defaultMAC)
        #expect(settings.useTLS == Config.defaultUseTLS)
        #expect(TVSettings(defaults: defaults).host == Config.defaultHost)
    }
}
