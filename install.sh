#!/bin/bash
# Builds an optimized Halo.app and installs it into /Applications.
set -e
cd "$(dirname "$0")"

echo "Building Halo (release)..."
swift build -c release

APP="/Applications/Halo.app"

# Quit running copies — including the app's old name, Mersal Memo
pkill -x Halo 2>/dev/null || true
pkill -x MersalMemo 2>/dev/null || true
sleep 1

# Old name: move to the Trash (notes and settings are migrated on first launch of Halo)
if [ -d "/Applications/MersalMemo.app" ]; then
    trash "/Applications/MersalMemo.app"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Halo "$APP/Contents/MacOS/Halo"
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Reuse the Info.plist defined in run.sh
sed -n '/<?xml/,/<\/plist>/p' run.sh > "$APP/Contents/Info.plist"
codesign --force --deep -s - "$APP"

echo "Installed $APP — launching..."
open "$APP"
