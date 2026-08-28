#!/usr/bin/env bash
#
# Builds a release "TV Remote.app" and packages it for another Mac.
#
# If a Developer ID Application certificate is present, the app is signed with
# it and — when notarytool credentials are configured — notarised and stapled,
# which is the only way it opens on someone else's Mac without ceremony.
# Without that certificate the script still produces a working bundle, but
# Gatekeeper on the destination Mac will refuse it until quarantine is cleared.
#
#   ./scripts/build-mac.sh
#
# One-off, to enable notarisation (needs an app-specific password from
# appleid.apple.com, NOT your Apple ID password):
#
#   xcrun notarytool store-credentials nakomis-notary \
#     --apple-id <your-apple-id> --team-id 62YFUFBSFX --password <app-specific>
#
set -euo pipefail

cd "$(dirname "$0")/.."

TEAM_ID="62YFUFBSFX"
NOTARY_PROFILE="${NOTARY_PROFILE:-nakomis-notary}"
BUILD_DIR="build/mac"
APP_NAME="TV Remote"

command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen"; exit 1; }

echo "==> Generating the Xcode project"
xcodegen generate >/dev/null

echo "==> Archiving (Release)"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
xcodebuild archive \
  -project TVRemote.xcodeproj \
  -scheme TVRemoteMac \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$BUILD_DIR/TVRemote.xcarchive" \
  -quiet

APP_SRC="$BUILD_DIR/TVRemote.xcarchive/Products/Applications/TVRemoteMac.app"
APP="$BUILD_DIR/$APP_NAME.app"
rm -rf "$APP"
cp -R "$APP_SRC" "$APP"

# Look for a Developer ID Application identity. Note that the two certificates
# named "Developer ID Certification Authority" that ship with every Mac are
# Apple's intermediates, not yours — hence matching on the full prefix.
IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
  | grep '"Developer ID Application:' \
  | head -1 | sed -E 's/.*"(.*)".*/\1/' || true)"

if [[ -n "$IDENTITY" ]]; then
  echo "==> Signing with: $IDENTITY"
  codesign --force --deep --options runtime --timestamp \
    --entitlements TVRemote/Resources/macOS/TVRemote.entitlements \
    --sign "$IDENTITY" "$APP"
  codesign --verify --strict --verbose=2 "$APP"

  ZIP="$BUILD_DIR/$APP_NAME.zip"
  rm -f "$ZIP"
  /usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"

  if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
    echo "==> Notarising (this takes a few minutes)"
    xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait
    echo "==> Stapling the ticket to the app"
    xcrun stapler staple "$APP"
    rm -f "$ZIP"
    /usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
    echo
    echo "Done: $ZIP"
    echo "Signed, notarised and stapled — it will open on any Mac with a double-click."
  else
    echo
    echo "Done: $ZIP"
    echo "Signed but NOT notarised: no notarytool profile '$NOTARY_PROFILE'."
    echo "macOS 15+ will still block it on another Mac. See the header of this"
    echo "script for the one-off store-credentials command."
  fi
else
  ZIP="$BUILD_DIR/$APP_NAME.zip"
  rm -f "$ZIP"
  /usr/bin/ditto -c -k --keepParent "$APP" "$ZIP"
  cat <<'MSG'

Done, but NO Developer ID Application certificate was found.

You have a paid Apple Developer Program membership, so you are entitled to
one — it simply has not been created on this Mac yet:

    Xcode -> Settings -> Accounts -> (your Apple ID) -> Manage Certificates
    -> + -> Developer ID Application

Until then the app still runs here, but on another Mac Gatekeeper will refuse
it. The recipient can override that once, per copy:

    xattr -dr com.apple.quarantine "/Applications/TV Remote.app"

MSG
  echo "Built: $ZIP"
fi
