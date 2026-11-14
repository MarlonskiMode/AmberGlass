#!/bin/bash
# Builds "build/Amber Glass.app". Pass --install to also copy it into /Applications.
set -euo pipefail
cd "$(dirname "$0")"

# The certificate name stays as-is. macOS ties Screen Recording permission to this
# identity, so renaming it would make the app ask for permission again.
SIGN_ID="Box Tint Local"

if ! security find-identity -v -p codesigning | grep -q "$SIGN_ID"; then
  tmp=$(mktemp -d)
  openssl req -x509 -newkey rsa:2048 -keyout "$tmp/key.pem" -out "$tmp/cert.pem" -days 3650 -nodes \
    -subj "/CN=$SIGN_ID" \
    -addext "keyUsage=critical,digitalSignature" \
    -addext "extendedKeyUsage=critical,codeSigning"
  openssl pkcs12 -export -legacy -out "$tmp/cert.p12" -inkey "$tmp/key.pem" -in "$tmp/cert.pem" -passout pass:boxtint
  security import "$tmp/cert.p12" -k "$HOME/Library/Keychains/login.keychain-db" -P boxtint -T /usr/bin/codesign -A
  security add-trusted-cert -r trustRoot -p codeSign -k "$HOME/Library/Keychains/login.keychain-db" "$tmp/cert.pem"
  rm -rf "$tmp"
fi

swift build -c release --disable-sandbox

APP="build/Amber Glass.app"
ICONSET="build/AmberGlass.iconset"
ICON="build/AmberGlass-1024.png"

rm -rf "$APP" "$ICONSET"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$ICONSET"

cp .build/release/AmberGlass "$APP/Contents/MacOS/AmberGlass"
cp Resources/AmberGlass-Info.plist "$APP/Contents/Info.plist"

swift Scripts/make-icon.swift "$ICON"
for s in 16 32 128 256 512; do
  sips -z $s $s "$ICON" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) "$ICON" --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
rm -rf "$ICONSET" "$ICON"

codesign --force --sign "$SIGN_ID" --timestamp=none "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  rm -rf "/Applications/Amber Glass.app"
  cp -R "$APP" /Applications/
  echo "Installed to /Applications/Amber Glass.app"
fi
