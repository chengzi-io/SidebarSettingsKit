#!/usr/bin/env bash
# macOS 27: whether the window title in the toolbar makes the page's top scroll edge hard.
set -uo pipefail
out=$PWD/glass; mkdir -p "$out"
swiftc -O scripts/probe-tools/pointer.swift -o /tmp/pointer
sw_vers -productVersion
defaults write com.apple.universalaccess reduceTransparency -bool false
defaults write com.apple.universalaccess reduceMotion -bool false
sleep 2
/tmp/pointer 1000 740
pkg=Examples/SidebarSettingsDemo
swift build -c release --build-system native --package-path $pkg 2>&1 | tail -1
dir=$pkg/.build/release
for title in shown hidden; do
    for edge in system soft; do
        for appearance in light dark; do
            unset SSK_PROBE_HIDE_TITLE SSK_PROBE_SOFT_DETAIL
            [[ $title == hidden ]] && export SSK_PROBE_HIDE_TITLE=1
            [[ $edge == soft ]] && export SSK_PROBE_SOFT_DETAIL=1
            rm -f /tmp/window-id
            (cd "$dir" && ./SidebarSettingsDemo --icons tiled --scenario 2 --appearance $appearance --window-id-file /tmp/window-id >/dev/null 2>&1) &
            for _ in $(seq 1 150); do [[ -s /tmp/window-id ]] && break; sleep 0.2; done
            sleep 2
            screencapture -o -l "$(</tmp/window-id)" "$out/title-$title-$edge-$appearance.png" && echo "ok $title $edge $appearance"
            pkill -f SidebarSettingsDemo; sleep 0.8
        done
    done
done
