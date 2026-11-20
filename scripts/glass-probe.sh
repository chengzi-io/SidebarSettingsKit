#!/usr/bin/env bash
# macOS 26 and 27, with the demo linked against the real SDK: the line under the toolbar at rest,
# with the pointer on the toolbar, and scrolled, with the page's top scroll edge left to the
# system and set to soft.
set -uo pipefail
out=$PWD/glass; mkdir -p "$out"
swiftc -O scripts/probe-tools/pointer.swift -o /tmp/pointer
swiftc -O scripts/probe-tools/window-frame.swift -o /tmp/window-frame
sw_vers -productVersion
defaults write com.apple.universalaccess reduceTransparency -bool false
defaults write com.apple.universalaccess reduceMotion -bool false
sleep 2
away() { /tmp/pointer 1000 740; }
away

pkg=Examples/SidebarSettingsDemo
swift build -c release --build-system native --package-path $pkg 2>&1 | tail -1
dir=$pkg/.build/release

for edge in system soft; do
    for sc in 5 2; do
        for appearance in light dark; do
            rm -f /tmp/window-id
            if [[ $edge == soft ]]; then export SSK_PROBE_SOFT_DETAIL=1; else unset SSK_PROBE_SOFT_DETAIL; fi
            (cd "$dir" && ./SidebarSettingsDemo --icons tiled --scenario $sc --appearance $appearance --window-id-file /tmp/window-id >/dev/null 2>&1) &
            for _ in $(seq 1 150); do [[ -s /tmp/window-id ]] && break; sleep 0.2; done
            sleep 1.5
            id=$(</tmp/window-id)
            screencapture -o -l "$id" "$out/$edge-$sc-$appearance-away.png"
            read -r x y w h < <(/tmp/window-frame "$id")
            /tmp/pointer $((x + w * 2 / 3)) $((y + 26)); sleep 1.2
            screencapture -o -l "$id" "$out/$edge-$sc-$appearance-hover.png"
            away; sleep 1.2
            screencapture -o -l "$id" "$out/$edge-$sc-$appearance-after.png" && echo "ok $edge $sc $appearance"
            pkill -f SidebarSettingsDemo; sleep 0.8
        done
    done
done
