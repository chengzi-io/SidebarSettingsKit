#!/usr/bin/env bash
# macOS 26 and 27, Reduce Transparency off: what gives a plain SwiftUI NavigationSplitView a soft
# scroll edge under a toolbar that shows the title, as System Settings has; the SDK's new API.
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

# API new in this SDK: each declaration after an availability line.
sdk=$(xcrun --sdk macosx --show-sdk-path)
while IFS= read -r interface; do
    echo "== $interface"
    awk '/macOS 27/ { left = 3 } left > 0 { print FNR ": " $0; left-- }' "$interface"
done < <(find "$sdk/System/Library/Frameworks/SwiftUI.framework/" "$sdk/System/Library/Frameworks/SwiftUICore.framework/" \
    -name 'arm64e-apple-macos.swiftinterface' 2>/dev/null) >"$out/swiftui-27.txt"
find "$sdk/System/Library/Frameworks/AppKit.framework/Headers/" -name '*.h' -exec grep -n "macos(27" {} + >"$out/appkit-27.txt"

# A plain SwiftUI NavigationSplitView, scrolled by the wheel: its title shown, shown once the page
# scrolls, or removed; with and without a soft top scroll edge asked for.
for variant in shown scroll hidden shown-soft scroll-soft; do
    title=${variant%-soft}
    soft=(); [[ $variant == *-soft ]] && soft=(REPLICA_SOFT=1)
    env REPLICA_TITLE="$title" ${soft[@]+"${soft[@]}"} SSK_PROBE_TREE="$out/tree-replica-$variant.txt" \
        SSK_REPLICA_DUMP=/dev/null /tmp/Replica >/dev/null 2>&1 &
    replica=$!
    for _ in $(seq 1 40); do /tmp/find-window Replica >/tmp/replica-window 2>/dev/null && break; sleep 0.5; done
    sleep 2
    read -r id x y w h </tmp/replica-window
    screencapture -o -l "$id" "$out/replica-$variant-top.png"
    /tmp/pointer $((x + w * 2 / 3)) $((y + h / 2)) 6; away; sleep 1.5
    screencapture -o -l "$id" "$out/replica-$variant-wheel.png"
    sleep 2.5
    kill "$replica"; sleep 1
    echo "ok replica $variant"
done
