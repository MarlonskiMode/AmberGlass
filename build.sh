#!/bin/bash
# Builds "build/Box Tint.app" and "build/Amber Glass.app".
# Pass --install to also copy them into /Applications.
set -euo pipefail
cd "$(dirname "$0")"

SIGN_ID="Box Tint Local"

# A stable identity, so macOS keeps Screen Recording permission across rebuilds.
# Ad-hoc signatures change every build, and the system treats each one as a new app.
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

# bundle <App Name> <executable> <icon style>
bundle() {
  local name="$1" exe="$2" style="$3"
  local app="build/$name.app"
  local iconset="build/$exe.iconset"
  local icon="build/$exe-1024.png"

  rm -rf "$app" "$iconset"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$iconset"

  cp ".build/release/$exe" "$app/Contents/MacOS/$exe"
  cp "Resources/$exe-Info.plist" "$app/Contents/Info.plist"

  swift Scripts/make-icon.swift "$icon" "$style"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$icon" --out "$iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) "$icon" --out "$iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$iconset" -o "$app/Contents/Resources/AppIcon.icns"
  rm -rf "$iconset" "$icon"

  codesign --force --sign "$SIGN_ID" --timestamp=none "$app"
  echo "Built $app"

  if [[ "$INSTALL" == 1 ]]; then
    rm -rf "/Applications/$name.app"
    cp -R "$app" /Applications/
    echo "Installed to /Applications/$name.app"
  fi
}

INSTALL=0
[[ "${1:-}" == "--install" ]] && INSTALL=1

bundle "Box Tint" BoxTint boxtint
bundle "Amber Glass" AmberGlass amber
