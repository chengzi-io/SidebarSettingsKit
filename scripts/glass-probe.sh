#!/usr/bin/env bash
# With Reduce Transparency off: the kit's window as it is and with the form's own background
# kept, and an active plain SwiftUI replica.
set -uo pipefail
out=$PWD/glass; mkdir -p "$out"
swiftc -O scripts/probe-tools/find-window.swift -o /tmp/find-window
swiftc -O -parse-as-library scripts/probe-tools/replica.swift -o /tmp/Replica

sw_vers -productVersion
defaults write com.apple.universalaccess reduceTransparency -bool false
defaults write com.apple.universalaccess reduceMotion -bool false
sleep 2
echo "reduced=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency')"

scripts/screenshots.sh "$out/hidden" 5 2
SSK_PROBE_KEEP_FORM_BG=1 scripts/screenshots.sh "$out/kept" 5 2

/tmp/Replica >/dev/null 2>&1 &
pid=$!
sleep 6
read -r id _ < <(/tmp/find-window Replica)
screencapture -o -l "$id" "$out/replica-light.png" && echo "ok replica"
kill "$pid"
