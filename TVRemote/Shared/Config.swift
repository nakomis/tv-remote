import Foundation

/// Everything deployment-specific lives here.
///
/// These are compile-time defaults. Each one can also be overridden at runtime
/// from the app's Settings screen (stored in `UserDefaults`), so changing TVs
/// does not strictly require a rebuild — but if the change is permanent, edit
/// it here so a fresh install picks it up too.
enum Config {

    // MARK: - The television

    /// The TV's address on the LAN.
    ///
    /// `172.29.0.19` is a DHCP reservation on the router for the LG B3 OLED,
    /// so it is stable. If the reservation ever changes, change it here.
    static let defaultHost = "172.29.0.19"

    /// The TV's wired/wireless MAC address, used as the target of the
    /// Wake-on-LAN magic packet. Obtained with `arp -n <host>` while the TV is
    /// awake, or from Settings → Support → TV Information on the TV itself.
    static let defaultMAC = "20:28:bc:bb:5d:60"

    /// Fallback broadcast address for the magic packet.
    ///
    /// Normally unused: `WakeOnLAN` derives the right address from whichever
    /// local interface is on the television's subnet, which is the only way to
    /// get it right without knowing the netmask. This value is the fallback
    /// for when no interface matches.
    ///
    /// The home network is a **/16** (`netmask 0xffff0000`), so the broadcast
    /// address is `172.29.255.255`. It is emphatically not `172.29.0.255` —
    /// that is the /24 answer, and on a /16 it is just an ordinary host
    /// address that nothing replies to, so the packet is silently dropped and
    /// the television never wakes.
    static let defaultBroadcast = "172.29.255.255"

    // MARK: - SSAP transport

    /// webOS speaks SSAP (Simple Service Access Protocol) over a WebSocket.
    ///
    /// Port 3000 is plaintext `ws://` and port 3001 is `wss://` with a
    /// self-signed certificate. **Both ports accept TCP connections on webOS
    /// 23, but only 3001 actually speaks SSAP** — 3000 completes the TCP
    /// handshake and then closes without sending an HTTP response, so the
    /// WebSocket upgrade never happens. Verified against an LG B3 on
    /// 2026-08-28 with `scripts/probe.py`.
    ///
    /// The plaintext option is kept because older webOS releases do serve
    /// 3000, but TLS is the working default here.
    static let defaultUseTLS = true

    static let plainPort = 3000
    static let tlsPort = 3001

    /// How long to wait for the TV to answer a request before giving up.
    static let requestTimeout: Duration = .seconds(8)

    /// How long to wait for the user to accept the pairing prompt on the TV.
    /// webOS shows a modal asking to allow the connection; the first launch
    /// blocks here until someone presses OK with the physical remote.
    static let pairingTimeout: Duration = .seconds(60)

    /// After sending a magic packet, how long to keep retrying the WebSocket
    /// connection before declaring the TV unreachable. A B3 takes roughly
    /// 8-12 seconds from standby to accepting connections.
    static let wakeTimeout: Duration = .seconds(30)

    // MARK: - Identity

    /// Shown on the TV's pairing prompt and in its list of connected devices.
    static let clientName = "TV Remote"

    /// Bumped whenever the permission list in `SSAPHandshake` changes.
    ///
    /// A `client-key` carries the permissions granted *at the moment it was
    /// issued*; widening the manifest later does nothing for an existing key.
    /// The stored key is filed under this revision, so raising it makes the
    /// old key invisible and the next connection re-pairs with the current
    /// permissions instead of failing with a 401 that looks like a bug.
    ///
    /// 2 — added CONTROL_MOUSE_AND_KEYBOARD and CONTROL_INPUT_TEXT for the
    ///     pointer input socket (keypad).
    static let manifestRevision = 2

    /// Keychain service under which the TV's `client-key` is stored. The key
    /// is issued once, on first pairing, and reused forever after — without
    /// it the TV re-prompts on every connection.
    static let keychainService = "com.nakomis.tvremote.clientkey"
}
