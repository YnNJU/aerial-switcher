#!/bin/zsh
# Builds Aerial Switcher.app (and a zip of it) into dist/.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
APP="dist/Aerial Switcher.app"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/AerialSwitcher"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/AerialSwitcher"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>AerialSwitcher</string>
  <key>CFBundleIdentifier</key><string>io.github.ynnju.aerial-switcher</string>
  <key>CFBundleName</key><string>Aerial Switcher</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
</dict>
</plist>
EOF

# Ad-hoc signature: required to run on Apple silicon; not a Developer ID.
codesign --force --sign - "$APP"

(cd dist && ditto -c -k --keepParent "Aerial Switcher.app" "AerialSwitcher-$VERSION.zip")
echo "Built $APP"
