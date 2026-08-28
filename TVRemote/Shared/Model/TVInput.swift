import Foundation

/// An external input on the television, as reported by
/// `ssap://tv/getExternalInputList`.
struct TVInput: Identifiable, Equatable, Sendable, Decodable {
    let id: String
    let label: String
    let connected: Bool
    let appId: String?

    private enum CodingKeys: String, CodingKey {
        case id, label, connected, appId
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        label = try c.decodeIfPresent(String.self, forKey: .label) ?? id
        connected = try c.decodeIfPresent(Bool.self, forKey: .connected) ?? false
        appId = try c.decodeIfPresent(String.self, forKey: .appId)
    }

    init(id: String, label: String, connected: Bool, appId: String? = nil) {
        self.id = id
        self.label = label
        self.connected = connected
        self.appId = appId
    }

    /// SF Symbol that best represents this input.
    var symbolName: String {
        let key = id.lowercased()
        if key.contains("hdmi") { return "cable.connector" }
        if key.contains("comp") || key.contains("av") { return "av.remote" }
        if key.contains("tuner") || key.contains("tv") { return "antenna.radiowaves.left.and.right" }
        return "rectangle.on.rectangle"
    }
}
