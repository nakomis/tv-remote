import Foundation

/// What the television says about its own power, from
/// `ssap://com.webos.service.tvpower/power/getPowerState`.
///
/// This matters because "the WebSocket is open" is not the same as "the TV is
/// on", and the difference shows up in exactly the cases a remote cares about.
/// webOS keeps its network stack up in several states where the panel is dark,
/// so without asking, a screen-off television looks identical to a working one.
enum TVPowerState: Sendable, Equatable {
    /// On and showing a picture.
    case active
    /// Network up, panel off — webOS's "screen off" mode.
    case screenOff
    /// On its way down, or up.
    case standby
    /// Going to sleep; the socket is about to die.
    case suspend
    /// Off.
    case off
    /// A state this app does not recognise. Kept rather than collapsed, so a
    /// firmware update adding a state does not silently read as "off".
    case unknown(String)

    init(reported: String) {
        switch reported.lowercased().replacingOccurrences(of: " ", with: "") {
        case "active": self = .active
        case "screenoff", "screensaver": self = .screenOff
        case "activestandby", "standby": self = .standby
        case "suspend": self = .suspend
        case "poweroff", "off": self = .off
        default: self = .unknown(reported)
        }
    }

    /// Whether the set is meaningfully usable — i.e. worth keeping the
    /// connection and the controls enabled.
    ///
    /// `screenOff` counts: the TV still answers, and volume and input changes
    /// still work, which is the behaviour someone would expect from a remote.
    var isAwake: Bool {
        switch self {
        case .active, .screenOff, .unknown: true
        case .standby, .suspend, .off: false
        }
    }

    /// Shown next to the connection status, or `nil` when there is nothing
    /// worth saying beyond "connected".
    var note: String? {
        switch self {
        case .active: nil
        case .screenOff: "screen off"
        case .standby: "going to standby"
        case .suspend: "suspending"
        case .off: "powering off"
        case .unknown(let raw): raw.lowercased()
        }
    }
}
