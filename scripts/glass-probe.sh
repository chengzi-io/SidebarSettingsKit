#!/usr/bin/env bash
# macOS 15: which separator style, once the page is scrolled, looks like System Settings'.
set -uo pipefail
out=$PWD/glass; mkdir -p "$out"
swiftc -O scripts/probe-tools/find-window.swift -o /tmp/find-window
swiftc -O scripts/probe-tools/pointer.swift -o /tmp/pointer
sw_vers -productVersion
defaults write com.apple.universalaccess reduceTransparency -bool false
defaults write com.apple.universalaccess reduceMotion -bool false
sleep 2
/tmp/pointer 1000 740

open -b com.apple.systempreferences
sleep 6
osascript -e 'tell application "System Settings" to activate' >/dev/null 2>&1
sleep 2
read -r id x y w h < <(/tmp/find-window "System Settings")
/tmp/pointer $((x + w * 2 / 3)) $((y + h / 2)) 6; /tmp/pointer 1000 740; sleep 1.5
screencapture -o -l "$id" "$out/ss-scrolled.png" && echo "ok ss"
osascript -e 'tell application "System Settings" to quit' >/dev/null 2>&1; sleep 2

pkg=Examples/SidebarSettingsDemo
swift build -c release --package-path $pkg 2>&1 | tail -1
dir=$pkg/.build/release
for sep in line shadow automatic; do
    for appearance in light dark; do
        rm -f /tmp/window-id
        (cd "$dir" && SSK_PROBE_SEPARATOR=$sep ./SidebarSettingsDemo --icons tiled --scenario 2 --appearance $appearance --window-id-file /tmp/window-id >/dev/null 2>&1) &
        for _ in $(seq 1 150); do [[ -s /tmp/window-id ]] && break; sleep 0.2; done
        sleep 1.5
        screencapture -o -l "$(</tmp/window-id)" "$out/$sep-$appearance.png" && echo "ok $sep $appearance"
        pkill -f SidebarSettingsDemo; sleep 0.8
    done
done
