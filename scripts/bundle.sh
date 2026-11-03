#!/bin/zsh
# Builds Aerial Switcher.app (and a zip of it) into dist/.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-1.0.2}"
APP="dist/Aerial Switcher.app"

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/AerialSwitcher"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/AerialSwitcher"
cp Assets/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key><string>en</string>
  <key>CFBundleLocalizations</key><array><string>en</string><string>zh-Hans</string></array>
  <key>CFBundleExecutable</key><string>AerialSwitcher</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
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
