import Foundation
import Observation

/// Runtime overrides for the values in `Config`, persisted to `UserDefaults`.
///
/// Named `TVSettings` rather than `Settings` because SwiftUI declares a
/// `Settings` *scene* on macOS. A class of the same name shadows it inside an
/// `App` body, and the resulting error names neither type.
///
/// An empty or absent override means "use the compiled-in default", so
/// clearing a field in the Settings screen restores the `Config` value rather
/// than leaving the app pointing at nothing.
@Observable
@MainActor
final class TVSettings {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        host = defaults.string(forKey: Keys.host) ?? Config.defaultHost
        mac = defaults.string(forKey: Keys.mac) ?? Config.defaultMAC
        broadcast = defaults.string(forKey: Keys.broadcast) ?? Config.defaultBroadcast
        useTLS = defaults.object(forKey: Keys.useTLS) as? Bool ?? Config.defaultUseTLS
    }

    var host: String { didSet { persist(host, Keys.host, default: Config.defaultHost) } }
    var mac: String { didSet { persist(mac, Keys.mac, default: Config.defaultMAC) } }
    var broadcast: String { didSet { persist(broadcast, Keys.broadcast, default: Config.defaultBroadcast) } }
    var useTLS: Bool { didSet { defaults.set(useTLS, forKey: Keys.useTLS) } }

    var port: Int { useTLS ? Config.tlsPort : Config.plainPort }

    var socketURL: URL? {
        let scheme = useTLS ? "wss" : "ws"
        let trimmed = host.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: "\(scheme)://\(trimmed):\(port)")
    }

    /// Restore every value to the compiled-in default.
    func resetToDefaults() {
        for key in [Keys.host, Keys.mac, Keys.broadcast, Keys.useTLS] {
            defaults.removeObject(forKey: key)
        }
        host = Config.defaultHost
        mac = Config.defaultMAC
        broadcast = Config.defaultBroadcast
        useTLS = Config.defaultUseTLS
    }

    private func persist(_ value: String, _ key: String, default fallback: String) {
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == fallback {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(trimmed, forKey: key)
        }
    }

    private enum Keys {
        static let host = "tv.host"
        static let mac = "tv.mac"
        static let broadcast = "tv.broadcast"
        static let useTLS = "tv.useTLS"
    }
}
