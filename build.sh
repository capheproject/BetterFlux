#!/bin/zsh
# Builds BetterFlux.app into ./build. Pass --install to copy it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
APP=build/BetterFlux.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/BetterFlux "$APP/Contents/MacOS/BetterFlux"

cat > "$APP/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>BetterFlux</string>
    <key>CFBundleIdentifier</key><string>com.paulfarla.BetterFlux</string>
    <key>CFBundleName</key><string>BetterFlux</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

codesign --force --sign - "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    rm -rf /Applications/BetterFlux.app
    cp -R "$APP" /Applications/
    echo "Installed to /Applications/BetterFlux.app"
fi
