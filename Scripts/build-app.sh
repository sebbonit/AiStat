#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIGURATION="${CONFIGURATION:-release}"
APP_DIR="$ROOT_DIR/.build/ResetStat.app"

"$ROOT_DIR/Scripts/generate-icon.swift"
swift build -c "$CONFIGURATION"

BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
EXECUTABLE="$BIN_DIR/ResetStat"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"

cp "$ROOT_DIR/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$ROOT_DIR/Resources/ResetStat.icns" "$APP_DIR/Contents/Resources/ResetStat.icns"
cp "$EXECUTABLE" "$APP_DIR/Contents/MacOS/ResetStat"

codesign --force --deep --sign - "$APP_DIR"

echo "Built $APP_DIR"
