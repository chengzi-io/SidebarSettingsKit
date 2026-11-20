#!/usr/bin/env bash
# Why the demo's window on macOS 27 is gray while a plain SwiftUI replica is white: the replica
# built for macOS 27 and for macOS 14, the binaries' build versions, and the demo window's layers.
set -uo pipefail
out=$PWD/glass; mkdir -p "$out"
swiftc -O scripts/probe-tools/find-window.swift -o /tmp/find-window
swiftc -O -parse-as-library scripts/probe-tools/replica.swift -o /tmp/Replica
swiftc -O -parse-as-library -target "$(uname -m)-apple-macosx14.0" scripts/probe-tools/replica.swift -o /tmp/Replica14

sw_vers -productVersion
xcode-select -p; xcrun --show-sdk-version; swift --version 2>&1 | head -1
defaults write com.apple.universalaccess reduceTransparency -bool false
defaults write com.apple.universalaccess reduceMotion -bool false
sleep 2

swift build -c release --package-path Examples/SidebarSettingsDemo 2>&1 | tail -1
demo=$PWD/Examples/SidebarSettingsDemo/.build/release/SidebarSettingsDemo
for bin in /tmp/Replica /tmp/Replica14 "$demo"; do
    echo "== $bin"; otool -l "$bin" | grep -A4 LC_BUILD_VERSION | grep -E 'minos|sdk'
done

rm -f /tmp/window-id
(cd "$(dirname "$demo")" && SSK_PROBE_DUMP=$out/demo-dump.txt ./SidebarSettingsDemo --icons tiled --scenario 5 --window-id-file /tmp/window-id >/dev/null 2>&1) &
for _ in $(seq 1 150); do [[ -s /tmp/window-id ]] && break; sleep 0.2; done
sleep 3
screencapture -o -l "$(</tmp/window-id)" "$out/demo.png" && echo "ok demo"
pkill -f SidebarSettingsDemo; sleep 1
head -12 "$out/demo-dump.txt"

for name in Replica Replica14; do
    "/tmp/$name" >/dev/null 2>&1 &
    pid=$!
    sleep 6
    read -r id _ < <(/tmp/find-window "$name")
    screencapture -o -l "$id" "$out/$name.png" && echo "ok $name"
    kill "$pid"; sleep 1
done
