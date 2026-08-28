# tv-remote — an iPhone, iPad and Mac remote for an LG webOS television

## Support

If you find this useful, please consider buying me a coffee:

[![Donate with PayPal](https://www.paypalobjects.com/en_GB/i/btn/btn_donate_SM.gif)](https://www.paypal.com/donate?hosted_button_id=Q3BESC73EWVNN&custom=tv-remote)

## Table of Contents

<!-- toc -->

- [Architecture Diagram](#architecture-diagram)
- [What it does](#what-it-does)
- [How it talks to the television](#how-it-talks-to-the-television)
  * [Wake-on-LAN, for switching on](#wake-on-lan-for-switching-on)
  * [SSAP, for everything else](#ssap-for-everything-else)
  * [Pairing](#pairing)
- [Repository layout](#repository-layout)
- [Configuration](#configuration)
- [The icon](#the-icon)
- [Appearance](#appearance)
- [Building](#building)
- [Distributing the Mac app](#distributing-the-mac-app)
- [Setting up the TV](#setting-up-the-tv)
- [Poking the TV by hand](#poking-the-tv-by-hand)
- [Testing](#testing)
- [Architecture Diagrams](#architecture-diagrams)
- [Support](#support)

<!-- tocstop -->

## Architecture Diagram

![Architecture](docs/architecture/tv-remote.svg)

## What it does

Two SwiftUI apps — one for iPhone and iPad, one that lives in the Mac's menu
bar — that turn an LG OLED on and off, change the volume, and switch between
HDMI inputs. They talk to the television directly over the local network:
there is no cloud service, no account, and nothing leaves the LAN.

Both share the same core. Only the shell around it differs: a navigation stack
on iOS, a `MenuBarExtra` popover on macOS.

Built against an **LG B3 OLED running webOS 23**, but nothing in it is specific
to that model beyond the defaults in `TVRemote/App/Config.swift`.

## How it talks to the television

Two protocols, because turning a television *on* and controlling one that is
already on are genuinely different problems.

### Wake-on-LAN, for switching on

A television in standby has no IP stack running. There is no socket to connect
to and no address to connect to it at, so no amount of cleverness at the
application layer will wake it. What *is* still powered is the network
interface itself, which watches every frame that reaches it for a **magic
packet**: six `0xFF` bytes followed by the interface's own MAC address repeated
sixteen times. Recognising that pattern is what brings the set up.

Because the TV has no address to be sent to, the packet is broadcast to the
subnet. `WakeOnLAN.swift` sends it to both the subnet broadcast address and the
global one, on ports 9 and 7, since firmware and routers disagree about which
combination they honour.

This needs **Mobile TV On** enabled on the television — see [Setting up the
TV](#setting-up-the-tv).

### SSAP, for everything else

Once awake, the TV serves **SSAP** (Simple Service Access Protocol), a
JSON-over-WebSocket protocol, on port 3001 over TLS.

> **Port 3000 does not work on webOS 23**, despite being open. It completes the
> TCP handshake and then closes the connection without sending an HTTP
> response, so the WebSocket upgrade never happens. Only `wss://` on 3001
> speaks SSAP, using a self-signed certificate the app has to accept
> explicitly. Older webOS releases do serve 3000, which is why the plaintext
> option survives in Settings — but TLS is the default. Messages carry a `type`, a
caller-chosen `id`, a `uri` naming the service, and an optional `payload`; the
TV replies asynchronously quoting the same `id`. `SSAPClient.swift` keeps a
table of in-flight requests keyed by that id so replies can be matched to
whoever is waiting for them.

The commands used are:

| Purpose | URI |
| --- | --- |
| Power off | `ssap://system/turnOff` |
| Volume up / down | `ssap://audio/volumeUp`, `ssap://audio/volumeDown` |
| Set volume | `ssap://audio/setVolume` |
| Mute | `ssap://audio/setMute` |
| Watch the volume | `ssap://audio/getVolume` (subscription) |
| List inputs | `ssap://tv/getExternalInputList` |
| Switch input | `ssap://tv/switchInput` |
| Current input | `ssap://com.webos.applicationManager/getForegroundAppInfo` |

Volume is a **subscription** rather than a poll: the TV pushes an update
whenever the level changes, so the slider stays right even when someone uses
the physical remote.

### Pairing

The TV will not accept commands from an unregistered client. The first
connection sends a manifest of requested permissions, the TV puts an "allow
this device?" prompt on screen, and once it is accepted with the physical
remote the TV returns a `client-key`. That key is kept in the iOS keychain and
presented on every subsequent connection, which is what stops the prompt
appearing every time. *Forget pairing* in Settings deletes it.

## Repository layout

```
TVRemote/
  Shared/      Everything both apps use
    Config.swift    Every deployment-specific value
    Theme.swift     The palette, from nakostat's dark tokens
    Model/          TVInput, ConnectionState, TVSettings
    Services/       WakeOnLAN, SSAPClient, SSAPHandshake, KeychainStore, TVController
    Views/          StatusBadge, PowerControls, VolumeControl, InputPicker, SettingsForm
  iOS/         App entry point and the navigation-stack shell
  macOS/       App entry point and the menu bar popover
  Resources/   Info.plists, entitlements, asset catalogue
TVRemoteTests/ Swift Testing unit tests, run against both platforms
scripts/       probe.py (poke the TV by hand), build-mac.sh (package the Mac app)
project.yml    XcodeGen spec; the .xcodeproj is generated, not committed
```

## Configuration

Everything deployment-specific lives in **`TVRemote/App/Config.swift`**:

```swift
static let defaultHost      = "172.29.0.19"        // DHCP reservation on the router
static let defaultMAC       = "20:28:bc:bb:5d:60"  // target of the magic packet
static let defaultBroadcast = "172.29.0.255"       // where the magic packet is sent
static let defaultUseTLS    = true                 // wss://:3001; 3000 is dead on webOS 23
```

Each is also overridable at runtime from the app's Settings screen, so a
temporary change does not need a rebuild. Clearing a field restores the
compiled-in default rather than leaving it empty.

To find the MAC of a TV that is currently awake:

```sh
ping -c1 172.29.0.19 && arp -n 172.29.0.19
```

## The icon

`docs/icon/source-1024.png` is the artwork (generated with Seedream via
fal.ai). `scripts/make-icons.py` turns it into both platforms' icon sets:

```sh
python3 scripts/make-icons.py docs/icon/source-1024.png
```

The two platforms want opposite things from the same picture, which is why
this is a script rather than a drag into Xcode:

- **iOS** needs a full-bleed square with no transparency and no rounded
  corners — it applies its own mask, so a pre-rounded source gets rounded
  twice and shows pale fringes.
- **macOS** does not mask at all, so the shape has to be in the image: an
  824x824 rounded plate centred on a 1024x1024 transparent canvas, per Apple's
  icon grid.

Generated artwork also tends to arrive as a rounded shape on a white page,
which is wrong for both. The script detects that page's corner radius and
replaces it with `Theme.background` before building either form.

## Appearance

Both apps are dark unconditionally, using the palette from `nakostat`'s dark
theme (`web/src/index.css`) converted from OKLCH to sRGB in `Theme.swift`. That
palette is deliberately hueless — its only colour is `--destructive` — so the
green used for power-on is that same red with its hue rotated at identical
lightness and chroma, rather than an arbitrary green bolted on.

There is no light variant, and the apps do not follow the system appearance. A
remote gets used in a dark room, and a menu bar popover that flashes white at
night is worse than useless.

## Building

The `.xcodeproj` is generated by [XcodeGen](https://github.com/yonaskolb/XcodeGen)
from `project.yml` and is deliberately not committed:

```sh
brew install xcodegen
xcodegen generate
open TVRemote.xcodeproj
```

Two schemes: **TVRemote** (iPhone/iPad) and **TVRemoteMac** (menu bar). Signing
is automatic against team `62YFUFBSFX`.

From the command line:

```sh
xcodebuild test -project TVRemote.xcodeproj -scheme TVRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

xcodebuild test -project TVRemote.xcodeproj -scheme TVRemoteMac \
  -destination 'platform=macOS'
```

> The simulator shares the Mac's network, so it can reach the TV and is a
> perfectly good place to test everything except the local-network permission
> prompt, which only appears on a real device.

## Distributing the Mac app

```sh
./scripts/build-mac.sh
```

This archives a Release build, renames the bundle to `TV Remote.app`, signs it,
and produces `build/mac/TV Remote.zip`.

The app is a **`.app` bundle**. A `.pkg` would gain nothing: an installer
package needs its own *Developer ID Installer* certificate and its own
notarisation, so it is strictly more work for the same Gatekeeper outcome.

To open on **another Mac** without ceremony, the app must be signed with a
**Developer ID Application** certificate and notarised. Note that the two
certificates named *Developer ID Certification Authority* present on every Mac
are Apple's intermediates, not yours — check with:

```sh
security find-identity -v -p codesigning | grep "Developer ID Application"
```

If that prints nothing, create one (a paid Apple Developer Program membership
covers it): **Xcode → Settings → Accounts → Manage Certificates → + →
Developer ID Application**. Then set up notarisation once, using an
app-specific password from appleid.apple.com:

```sh
xcrun notarytool store-credentials nakomis-notary \
  --apple-id <your-apple-id> --team-id 62YFUFBSFX --password <app-specific>
```

After that `build-mac.sh` signs, notarises and staples automatically, and the
zip opens anywhere with a double-click.

Without a Developer ID the script still produces a working bundle, but the
receiving Mac has to clear quarantine by hand:

```sh
xattr -dr com.apple.quarantine "/Applications/TV Remote.app"
```

## Setting up the TV

Two settings on the television matter:

1. **Mobile TV On** — *Settings → General → Devices → TV Management → Mobile TV
   On*. Without it the network interface is fully powered down in standby and
   the magic packet has nothing to reach. Turning the TV **on** will not work
   until this is enabled; everything else will.
2. **A DHCP reservation** for the TV on the router, so its address does not
   move out from under `Config.defaultHost`.

## Poking the TV by hand

`scripts/probe.py` performs the same handshake as the app and dumps what the TV
reports. It is how the payload shapes in `TVController` were checked against a
real set — and how the port 3000 dead end above was found:

```sh
python3 scripts/probe.py [host]
```

The first run raises the pairing prompt; afterwards the key is cached in
`scripts/.client-key`.

## Testing

```sh
xcodebuild test -project TVRemote.xcodeproj -scheme TVRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

xcodebuild test -project TVRemote.xcodeproj -scheme TVRemoteMac \
  -destination 'platform=macOS'
```

The same suite runs against both platforms. It covers magic-packet
construction, the settings/override precedence rules, SSAP payload decoding and
connection-state logic. The socket itself is not unit-tested — that is what
`scripts/probe.py` is for.

## Architecture Diagrams

`docs/architecture/tv-remote.drawio` is the source for the diagram above.
The SVG is auto-regenerated on commit by the pre-commit hook in
`.githooks/pre-commit`.

To activate the hook after cloning:

```bash
git config core.hooksPath .githooks
```

## Support

If you find this useful, please consider buying me a coffee:

[![Donate with PayPal](https://www.paypalobjects.com/en_GB/i/btn/btn_donate_SM.gif)](https://www.paypal.com/donate?hosted_button_id=Q3BESC73EWVNN&custom=tv-remote)
