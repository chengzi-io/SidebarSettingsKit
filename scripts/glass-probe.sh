#!/usr/bin/env bash
# With Reduce Transparency off: the kit's window, a plain SwiftUI replica and System Settings,
# on the runner's desktop and over a red backdrop; and a dump of what lies behind the page.
set -uo pipefail
out=$PWD/glass; mkdir -p "$out"
swiftc -O scripts/probe-tools/find-window.swift -o /tmp/find-window
swiftc -O -parse-as-library scripts/probe-tools/replica.swift -o /tmp/Replica
swiftc -O scripts/probe-tools/backdrop.swift -o /tmp/Backdrop

capture_app() { # NAME LAUNCH-COMMAND... ; captures OWNER NAME's window into $out/$tag-NAME.png
    local name=$1; shift
    "$@" >/dev/null 2>&1 &
    local pid=$!
    sleep 6
    osascript -e "tell application \"$name\" to activate" >/dev/null 2>&1
    sleep 2
    read -r id _ < <(/tmp/find-window "$name")
    screencapture -o -l "$id" "$out/$tag-${name// /-}.png" && echo "ok $tag $name"
    osascript -e "tell application \"$name\" to quit" >/dev/null 2>&1
    sleep 1; kill "$pid" 2>/dev/null; sleep 1
}

sw_vers -productVersion
defaults write com.apple.universalaccess reduceTransparency -bool false
defaults write com.apple.universalaccess reduceMotion -bool false
sleep 2
echo "reduced=$(osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency')"

swift build --build-tests -Xswiftc -warnings-as-errors 2>&1 | tail -3
swift test --skip-build --filter GlassProbeTests 2>&1 | grep -E 'GLASSPROBE|✘|✔ Test run' > "$out/dump.txt"
grep -cE GLASSPROBE "$out/dump.txt"

for tag in desktop red; do
    if [[ $tag == red ]]; then /tmp/Backdrop & backdrop=$!; sleep 2; fi
    scripts/screenshots.sh "$out/$tag" 5
    capture_app Replica /tmp/Replica
    capture_app "System Settings" open -b com.apple.systempreferences
    if [[ $tag == red ]]; then kill "$backdrop"; fi
done
