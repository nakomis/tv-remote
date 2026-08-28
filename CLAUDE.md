# tv-remote

A SwiftUI iPhone/iPad remote for an LG B3 OLED (webOS 23): power on via
Wake-on-LAN, power off / volume / mute / input switching via SSAP.

## The two protocols, and why

- **Wake-on-LAN** is the only way to turn the set *on*. In standby there is no
  IP stack, so SSAP cannot help — only a broadcast magic packet at the link
  layer will do it. Requires *Mobile TV On* enabled on the TV.
- **SSAP** (JSON over WebSocket, port 3000 plain / 3001 TLS) handles everything
  once the TV is awake. Requests carry a caller-chosen `id`; replies quote it
  back asynchronously, so `SSAPClient` matches them via a pending table.

Do **not** rebuild this on top of dev-mode SSH and `luna-send`. It works, but
webOS developer mode sessions expire after ~50 hours and have to be re-armed
from the TV's own UI, which defeats the purpose of a remote control. SSAP needs
no dev mode and survives reboots.

## Configuration

Every deployment-specific value is in `TVRemote/App/Config.swift` — host, MAC,
broadcast address, TLS toggle, timeouts. `Model/Settings.swift` layers
`UserDefaults` overrides on top for the Settings screen; an empty override
falls back to the `Config` value rather than to an empty string.

The TV is `172.29.0.19` (DHCP reservation), MAC `20:28:bc:bb:5d:60`.

## Repository layout

```
TVRemote/App        Entry point + Config.swift
TVRemote/Model      TVInput, ConnectionState, Settings
TVRemote/Services   WakeOnLAN, SSAPClient, SSAPHandshake, KeychainStore, TVController
TVRemote/Views      SwiftUI screens
TVRemoteTests/      Swift Testing suites
scripts/probe.py    Development aid: same handshake, dumps raw TV replies
```

## Building

The `.xcodeproj` is **generated** from `project.yml` by XcodeGen and is
gitignored. After editing `project.yml`, or after adding a file:

```sh
xcodegen generate
```

```sh
xcodebuild build -project TVRemote.xcodeproj -scheme TVRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Team `62YFUFBSFX`, bundle id `com.nakomis.tvremote`, deployment target iOS 17.

## Testing

```sh
xcodebuild test -project TVRemote.xcodeproj -scheme TVRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Swift Testing (`@Test`, `#expect`), not XCTest. Coverage target 70% of the
testable surface — the WebSocket itself is exercised by `scripts/probe.py`
rather than by unit tests, since mocking it would only test the mock.

The simulator shares the Mac's network, so it can reach the real TV.

## Gotchas

- `[String: Any]` is not `Sendable`. SSAP frames are serialised to a `String`
  **before** crossing into a child task, or the build fails under Swift 6.
- `Info.plist` must keep `NSLocalNetworkUsageDescription` and
  `NSAllowsLocalNetworking`, or iOS silently blocks the connection on device.
- A stale `client-key` is rejected outright; `TVController` deletes it on a
  `rejected` failure so the next attempt falls back to the pairing prompt
  instead of failing forever.
- webOS moved volume fields into a nested `volumeStatus` object in later
  releases but some models still send the flat ones. Both are read.

## Architecture diagrams

Source: `docs/architecture/tv-remote.drawio` — SVG auto-regenerated on commit
by `.githooks/pre-commit`.

To activate the hook after cloning:
```bash
git config core.hooksPath .githooks
```
