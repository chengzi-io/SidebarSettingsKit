#!/usr/bin/env bash
# macOS 26 and 27, Reduce Transparency off: whether a plain SwiftUI NavigationSplitView with its
# title shown keeps a soft scroll edge under the toolbar, and its views beside the kit's.
set -uo pipefail
out=$PWD/glass; mkdir -p "$out"
swiftc -O scripts/probe-tools/pointer.swift -o /tmp/pointer
swiftc -O scripts/probe-tools/window-frame.swift -o /tmp/window-frame
{ sw_vers; swift --version 2>&1 | head -1; xcodebuild -version; } | tee "$out/versions.txt"

defaults write com.apple.universalaccess reduceTransparency -bool false
defaults write com.apple.universalaccess reduceMotion -bool false
sleep 2
read -r screen_w screen_h < <(osascript -l JavaScript -e 'ObjC.import("AppKit"); var f = $.NSScreen.mainScreen.frame; f.size.width + " " + f.size.height')
echo "screen $screen_w x $screen_h"
away() { /tmp/pointer $((screen_w - 5)) $((screen_h - 5)); }
away

pkg=Examples/SidebarSettingsDemo
swift build -c release --build-system native --package-path $pkg 2>&1 | tail -1
dir=$pkg/.build/release
otool -l "$dir/SidebarSettingsDemo" | grep -A4 LC_BUILD_VERSION >"$out/demo-build-version.txt"

# launch NAME SCENARIO [VAR=VALUE...]: opens the demo's settings window, light, tiled icons.
launch() {
    local name=$1 scenario=$2
    shift 2
    rm -f /tmp/wid
    (cd "$dir" && env "$@" SSK_PROBE_DUMP="$out/dump-$name.txt" ./SidebarSettingsDemo --icons tiled \
        --scenario "$scenario" --appearance light --window-id-file /tmp/wid >/dev/null 2>&1) &
    for _ in $(seq 1 150); do [[ -s /tmp/wid ]] && break; sleep 0.2; done
    sleep 3
}
finish() { pkill -f SidebarSettingsDemo; sleep 0.8; }

swiftc -O scripts/probe-tools/find-window.swift -o /tmp/find-window
swiftc -O -parse-as-library -swift-version 6 scripts/probe-tools/replica.swift -o /tmp/Replica
otool -l /tmp/Replica | grep -A4 LC_BUILD_VERSION | grep -E 'minos|sdk' | xargs | tee "$out/replica-build-version.txt"

# A plain SwiftUI NavigationSplitView, its title shown always, scrolled by the wheel.
SSK_PROBE_TREE="$out/tree-replica.txt" SSK_REPLICA_DUMP="$out/replica-dump.txt" /tmp/Replica >/dev/null 2>&1 &
replica=$!
for _ in $(seq 1 40); do /tmp/find-window Replica >/tmp/replica-window 2>/dev/null && break; sleep 0.5; done
sleep 2
read -r id x y w h </tmp/replica-window
screencapture -o -l "$id" "$out/replica-top.png"
/tmp/pointer $((x + w * 2 / 3)) $((y + h / 2)) 6; away; sleep 1.5
screencapture -o -l "$id" "$out/replica-wheel.png"
sleep 4.5
kill "$replica"
echo "ok replica"

# The kit's window scrolled, with and without the accessory, and its views.
for edge in none accessory; do
    launch "tree-$edge" 2 SSK_PROBE_EDGE=$edge SSK_PROBE_TREE="$out/tree-kit-$edge.txt"
    screencapture -o -l "$(</tmp/wid)" "$out/kit-$edge-2.png"
    sleep 1
    finish
    echo "ok kit $edge"
done
