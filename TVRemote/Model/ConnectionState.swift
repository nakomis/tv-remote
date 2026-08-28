import Foundation

/// Where the app is in its conversation with the television.
enum ConnectionState: Equatable, Sendable {
    /// No socket open. Either the TV is off, or we have not tried yet.
    case disconnected
    /// Opening the WebSocket and sending the registration handshake.
    case connecting
    /// The TV is showing its "allow this device?" prompt and is waiting for
    /// someone to press OK on the physical remote.
    case pairing
    /// Registered and able to issue commands.
    case connected
    /// Something went wrong; the associated value is fit to show a human.
    case failed(String)

    var isConnected: Bool { self == .connected }

    var isBusy: Bool {
        switch self {
        case .connecting, .pairing: true
        default: false
        }
    }

    var describedForHuman: String {
        switch self {
        case .disconnected: "Not connected"
        case .connecting: "Connecting…"
        case .pairing: "Accept the prompt on the TV"
        case .connected: "Connected"
        case .failed(let reason): reason
        }
    }
}
