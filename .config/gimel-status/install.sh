#!/bin/sh
# (Re)load the gimel-status LaunchAgent: read-only host metrics JSON on :8090
# (loopback + Tailscale address only), consumed by the Klaw dashboard's
# klaw-host card as the "gimel" http target. Server: ~/bin/gimel-status.py.
# Uninstall: launchctl bootout gui/$(id -u)/com.kballenegger.gimel-status;
#   rm ~/Library/LaunchAgents/com.kballenegger.gimel-status.plist
set -e
src=$(cd "$(dirname "$0")" && pwd)
label=com.kballenegger.gimel-status
cp "$src/$label.plist" "$HOME/Library/LaunchAgents/$label.plist"
launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/$label.plist"
echo "installed; check: curl -s http://127.0.0.1:8090/status"
