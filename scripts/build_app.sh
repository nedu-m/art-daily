#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")/.."

echo "▶ Building release binary…"
swift build -c release

APP_DIR="build/Art.app"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp .build/release/Art "$APP_DIR/Contents/MacOS/Art"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"

if [[ ! -f Resources/ArtIcon.icns ]]; then
    echo "▶ Rendering app icon…"
    swift tools/make_icon.swift
    ICONSET="build/ArtIcon.iconset"
    rm -rf "$ICONSET"
    mkdir -p "$ICONSET"
    for size in 16 32 128 256 512; do
        sips -z "$size" "$size" Resources/ArtIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
        double=$((size * 2))
        sips -z "$double" "$double" Resources/ArtIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
    done
    iconutil -c icns "$ICONSET" -o Resources/ArtIcon.icns
fi
cp Resources/ArtIcon.icns "$APP_DIR/Contents/Resources/ArtIcon.icns"

echo "▶ Signing (ad-hoc)…"
codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1

echo "✅ Built: $PWD/$APP_DIR"
