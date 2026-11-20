#!/usr/bin/env bash
# macOS 26 and 27, Reduce Transparency off: which change gives the kit's page a soft scroll edge
# under the toolbar with the title shown, as System Settings has: a zero-height accessory asking for
# a soft edge, the title shown late, an empty title at the top, or no separator style on 26 and later.
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

for edge in none accessory late empty auto; do
    # Scrolled by the demo, to the end of the page.
    launch "edge-$edge-2" 2 SSK_PROBE_EDGE=$edge
    screencapture -o -l "$(</tmp/wid)" "$out/edge-$edge-2.png"
    finish
    # Scrolled by the wheel, from the top of the page.
    launch "edge-$edge-6" 6 SSK_PROBE_EDGE=$edge
    id=$(</tmp/wid)
    read -r x y w h < <(/tmp/window-frame "$id")
    screencapture -o -l "$id" "$out/edge-$edge-6-top.png"
    /tmp/pointer $((x + w * 2 / 3)) $((y + h / 2)) 6; away; sleep 1.5
    screencapture -o -l "$id" "$out/edge-$edge-6-wheel.png"
    finish
    echo "ok edge $edge"
done
# The accessory must not move a short page down.
launch edge-accessory-5 5 SSK_PROBE_EDGE=accessory
screencapture -o -l "$(</tmp/wid)" "$out/edge-accessory-5.png"
finish
launch edge-none-5 5 SSK_PROBE_EDGE=none
screencapture -o -l "$(</tmp/wid)" "$out/edge-none-5.png"
finish
