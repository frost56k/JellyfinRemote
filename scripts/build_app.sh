#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_ROOT="$ROOT/.build-universal"
APP_PATH="$ROOT/dist/JellyfinRemote.app"
ARM_BUILD="$BUILD_ROOT/arm64"
INTEL_BUILD="$BUILD_ROOT/x86_64"

for tool in swift lipo sips iconutil codesign; do
  command -v "$tool" >/dev/null 2>&1 || { echo "Missing required macOS tool: $tool" >&2; exit 1; }
done
[[ -f "$ROOT/Package.swift" ]] || { echo "Package.swift not found in $ROOT" >&2; exit 1; }
[[ -f "$ROOT/Resources/AppIcon.png" ]] || { echo "Resources/AppIcon.png not found" >&2; exit 1; }

# Build each architecture independently; do not silently downgrade to arm64.
swift build -c release --arch arm64 --build-path "$ARM_BUILD"
swift build -c release --arch x86_64 --build-path "$INTEL_BUILD"
ARM_BIN="$(swift build -c release --arch arm64 --build-path "$ARM_BUILD" --show-bin-path)"
INTEL_BIN="$(swift build -c release --arch x86_64 --build-path "$INTEL_BUILD" --show-bin-path)"
[[ -x "$ARM_BIN/JellyfinRemote" ]] || { echo "arm64 build product missing: $ARM_BIN/JellyfinRemote" >&2; exit 1; }
[[ -x "$INTEL_BIN/JellyfinRemote" ]] || { echo "x86_64 build product missing: $INTEL_BIN/JellyfinRemote" >&2; exit 1; }

mkdir -p "$ROOT/dist" "$APP_PATH/Contents/MacOS" "$APP_PATH/Contents/Resources"
UNIVERSAL="$ROOT/dist/JellyfinRemote.universal"
lipo -create "$ARM_BIN/JellyfinRemote" "$INTEL_BIN/JellyfinRemote" -output "$UNIVERSAL"
lipo "$UNIVERSAL" -verify_arch arm64 x86_64
install -m 755 "$UNIVERSAL" "$APP_PATH/Contents/MacOS/JellyfinRemote"
rm -f "$UNIVERSAL"

ICONSET="$BUILD_ROOT/AppIcon.iconset"
rm -rf "$ICONSET"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -s format png -z "$size" "$size" "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -s format png -z "$double" "$double" "$ROOT/Resources/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP_PATH/Contents/Resources/AppIcon.icns"

cat > "$APP_PATH/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>JellyfinRemote</string>
  <key>CFBundleIdentifier</key><string>com.jellyfinremote.app</string>
  <key>CFBundleName</key><string>JellyfinRemote</string>
  <key>CFBundleDisplayName</key><string>JellyfinRemote</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>2.0.0</string>
  <key>CFBundleShortVersionString</key><string>2.0.0</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>JellyfinRemote управляет вкладкой Jellyfin в Safari по вашей команде.</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
</dict></plist>
PLIST
codesign --force --deep --sign - "$APP_PATH"
echo "Built universal macOS app: $APP_PATH"
lipo "$APP_PATH/Contents/MacOS/JellyfinRemote" -verify_arch arm64 x86_64
