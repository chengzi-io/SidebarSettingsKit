#!/usr/bin/env bash
# Screenshots with the runner's Reduce Transparency (on), then with it off, for the demo and for
# System Settings.
set -uo pipefail
out=$PWD/glass; mkdir -p "$out"
swiftc -O scripts/probe-tools/find-window.swift -o /tmp/find-window

reduced() {
    osascript -l JavaScript -e 'ObjC.import("AppKit"); $.NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceTransparency' 2>&1
}

system_settings() {
    open -b com.apple.systempreferences
    sleep 6
    osascript -e 'tell application "System Settings" to activate' >/dev/null 2>&1
    sleep 2
    read -r id _ < <(/tmp/find-window "System Settings")
    screencapture -o -l "$id" "$out/$1-system-settings.png" && echo "ok system settings $1"
    osascript -e 'tell application "System Settings" to quit' >/dev/null 2>&1
    sleep 2
}

sw_vers
echo "== as the runner has it: defaults=$(defaults read com.apple.universalaccess reduceTransparency 2>&1) reduced=$(reduced)"
scripts/screenshots.sh "$out/reduced" 5 1
system_settings reduced

defaults write com.apple.universalaccess reduceTransparency -bool false; echo "write exit=$?"
defaults write com.apple.universalaccess reduceMotion -bool false; echo "write exit=$?"
sleep 2
echo "== after turning it off: defaults=$(defaults read com.apple.universalaccess reduceTransparency 2>&1) reduced=$(reduced)"
scripts/screenshots.sh "$out/glass" 5 1
system_settings glass
