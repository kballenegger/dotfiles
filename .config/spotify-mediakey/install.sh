#!/bin/sh
# Build SpotifyMediaKey.app into ~/Applications and (re)load its LaunchAgent.
# Uninstall: launchctl bootout gui/$(id -u)/com.kballenegger.spotify-mediakey;
#   rm -rf ~/Applications/SpotifyMediaKey.app ~/Library/LaunchAgents/com.kballenegger.spotify-mediakey.plist
set -e
src=$(cd "$(dirname "$0")" && pwd)
app="$HOME/Applications/SpotifyMediaKey.app"
label=com.kballenegger.spotify-mediakey
mkdir -p "$app/Contents/MacOS"
cp "$src/Info.plist" "$app/Contents/Info.plist"
swiftc -O -o "$app/Contents/MacOS/SpotifyMediaKey" "$src/main.swift"
codesign --force --sign - --identifier com.kballenegger.SpotifyMediaKey "$app"
cp "$src/$label.plist" "$HOME/Library/LaunchAgents/$label.plist"
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$label.plist"
echo "installed; log: ~/Library/Logs/SpotifyMediaKey.log"
