#!/usr/bin/env bash
# With Reduce Transparency off: System Settings at rest, with the pointer on its toolbar, and
# scrolled; the kit's window with the separator left to AppKit; the window frame's effect view
# variants; a plain SwiftUI replica and its layers.
set -uo pipefail
out=$PWD/glass; mkdir -p "$out"
swiftc -O scripts/probe-tools/find-window.swift -o /tmp/find-window
swiftc -O -parse-as-library scripts/probe-tools/replica.swift -o /tmp/Replica
swiftc -O scripts/probe-tools/pointer.swift -o /tmp/pointer

sw_vers -productVersion
defaults write com.apple.universalaccess reduceTransparency -bool false
defaults write com.apple.universalaccess reduceMotion -bool false
sleep 2
read -r screen_w screen_h < <(osascript -l JavaScript -e 'ObjC.import("AppKit"); var f = $.NSScreen.mainScreen.frame; f.size.width + " " + f.size.height')
echo "screen $screen_w x $screen_h"
away() { /tmp/pointer $((screen_w - 5)) $((screen_h - 5)); }
away

# System Settings
open -b com.apple.systempreferences
sleep 6
osascript -e 'tell application "System Settings" to activate' >/dev/null 2>&1
sleep 2
read -r id x y w h < <(/tmp/find-window "System Settings")
echo "system settings window $id at $x $y $w $h"
screencapture -o -l "$id" "$out/ss-rest.png"
/tmp/pointer $((x + w * 2 / 3)) $((y + 26)); sleep 1
screencapture -o -l "$id" "$out/ss-hover.png"
/tmp/pointer $((x + w * 2 / 3)) $((y + h / 2)) 4; away; sleep 1
screencapture -o -l "$id" "$out/ss-scrolled.png"
osascript -e 'tell application "System Settings" to quit' >/dev/null 2>&1
sleep 2
echo "ok system settings"

# The kit
SSK_PROBE_SEPARATOR=automatic scripts/screenshots.sh "$out/sep-automatic" 5 2
for mode in asis hide window follow; do
    SSK_PROBE_THEME_EFFECT=$mode scripts/screenshots.sh "$out/effect-$mode" 5
done

# Replica
SSK_REPLICA_DUMP=$out/replica-dump.txt /tmp/Replica >/dev/null 2>&1 &
pid=$!
sleep 6
read -r id _ < <(/tmp/find-window Replica)
screencapture -o -l "$id" "$out/replica-light.png" && echo "ok replica"
kill "$pid"
head -40 "$out/replica-dump.txt"
