# tv-remote

SwiftUI remotes for an LG B3 OLED (webOS 23) — one iPhone/iPad app, one macOS
menu bar app. Power on via Wake-on-LAN, power off / volume / mute / input
switching via SSAP. Both share everything under `TVRemote/Shared`; only the
app shell differs.

## The two protocols, and why

- **Wake-on-LAN** is the only way to turn the set *on*. In standby there is no
  IP stack, so SSAP cannot help — only a broadcast magic packet at the link
  layer will do it. Requires *Mobile TV On* enabled on the TV.
- **SSAP** (JSON over WebSocket) handles everything once the TV is awake.
  Requests carry a caller-chosen `id`; replies quote it back asynchronously, so
  `SSAPClient` matches them via a pending table.

  **Use port 3001 over TLS.** Port 3000 is open on webOS 23 and accepts TCP,
  but then closes without an HTTP response — the WebSocket upgrade never
  completes. This looks like a network fault and is not one. The TV's
  certificate is self-signed, so `SSAPClient` installs a delegate that accepts
  it. Do not "fix" the default back to plaintext.

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
TVRemote/Shared     Config, Theme, Model, Services, and the shared views
TVRemote/iOS        App entry point + navigation-stack shell
TVRemote/macOS      App entry point + MenuBarExtra popover
TVRemote/Resources  Info.plists (per platform), entitlements, assets
TVRemoteTests/      Swift Testing suites, run against both platforms
scripts/probe.py    Development aid: same handshake, dumps raw TV replies
scripts/build-mac.sh Release build, signing, notarisation, packaging
```

Shared sources are compiled into both app targets directly rather than via a
framework target — for six services and five views that is ceremony without
benefit.

## Appearance

Both apps run dark unconditionally — `.preferredColorScheme(.dark)`, no light
variant. The palette in `Theme.swift` is nakostat's dark theme
(`nakostat/web/src/index.css`) converted from OKLCH to sRGB. It is hueless
apart from `--destructive`, so `Theme.positive` is that red hue-rotated at the
same L and C. If the palette needs extending, derive from nakostat's tokens the
same way rather than picking a colour by eye.

## Building

The `.xcodeproj` is **generated** from `project.yml` by XcodeGen and is
gitignored. After editing `project.yml`, or after adding a file:

```sh
xcodegen generate
```

```sh
xcodebuild build -project TVRemote.xcodeproj -scheme TVRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

xcodebuild build -project TVRemote.xcodeproj -scheme TVRemoteMac \
  -destination 'platform=macOS'
```

Team `62YFUFBSFX`, bundle id `com.nakomis.tvremote`, targets iOS 17 / macOS 14.

`./scripts/build-mac.sh` packages the Mac app. It signs with a Developer ID
Application certificate and notarises when both are available, and otherwise
still produces a working bundle with instructions. A `.pkg` is not worth it:
it needs its own Developer ID *Installer* certificate and its own notarisation
for the same Gatekeeper outcome.

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
- **Do not name anything `Settings`.** SwiftUI declares a `Settings` *scene* on
  macOS, and a same-named class silently shadows it inside an `App` body; the
  compiler error names neither type. Ours is `TVSettings`.
- Both app targets set `PRODUCT_MODULE_NAME: TVRemote` so one test suite can
  `@testable import TVRemote` on either platform. Do not override
  `PRODUCT_NAME` on the Mac target either — the unit-test bundle derives
  `TEST_HOST` from the target name and renaming the product breaks it. The
  pretty name comes from `CFBundleDisplayName`.
- webOS moved volume fields into a nested `volumeStatus` object in later
  releases but some models still send the flat ones. Both are read. The B3
  sends the nested form: `payload.volumeStatus.{volume,muteStatus}`.
- `setVolume` makes webOS flash its on-screen volume bar even when the value is
  unchanged. Seeing the overlay does not mean the level moved.
- Inputs carry friendly labels from HDMI SPD data — HDMI 3 reports as
  "PS5 Game Console", not "HDMI 3". Render `label`, never the `id`.

## Architecture diagrams

Source: `docs/architecture/tv-remote.drawio` — SVG auto-regenerated on commit
by `.githooks/pre-commit`.

To activate the hook after cloning:
```bash
git config core.hooksPath .githooks
```
