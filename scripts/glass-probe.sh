#!/usr/bin/env bash
# Why SwiftPM on the macOS 27 runner links the demo with SDK 14.0, and the demo's look once it
# links with the real SDK.
set -uo pipefail
out=$PWD/glass; mkdir -p "$out"
swiftc -O scripts/probe-tools/find-window.swift -o /tmp/find-window
swiftc -O scripts/probe-tools/pointer.swift -o /tmp/pointer

sw_vers -productVersion
swift --version 2>&1 | head -1
swift build --help 2>&1 | grep -i -A2 'build-system' | head -6
defaults write com.apple.universalaccess reduceTransparency -bool false
defaults write com.apple.universalaccess reduceMotion -bool false
sleep 2
/tmp/pointer 1000 740

pkg=Examples/SidebarSettingsDemo
echo "== default build, link line"
swift build -c release --package-path $pkg -v 2>&1 | grep -oE '(-platform_version|-target|--target=|-mmacosx-version-min=|-sdk )[^ ]*( [^ ]*){0,3}' | sort | uniq -c | head -12
otool -l $pkg/.build/release/SidebarSettingsDemo | grep -A4 LC_BUILD_VERSION | grep -E 'minos|sdk'
ls -la $pkg/.build/ | head

shot() { # NAME BUILD-DIR SEPARATOR ARGS...
    local name=$1 dir=$2 separator=$3; shift 3
    rm -f /tmp/window-id
    (cd "$dir" && SSK_PROBE_SEPARATOR=$separator ./SidebarSettingsDemo --icons tiled --window-id-file /tmp/window-id "$@" >/dev/null 2>&1) &
    for _ in $(seq 1 150); do [[ -s /tmp/window-id ]] && break; sleep 0.2; done
    sleep 1.5
    screencapture -o -l "$(</tmp/window-id)" "$out/$name.png" && echo "ok $name"
    pkill -f SidebarSettingsDemo; sleep 0.8
}

for system in native swiftbuild; do
    echo "== --build-system $system"
    rm -rf /tmp/demo-$system
    if swift build -c release --package-path $pkg --build-system $system --scratch-path /tmp/demo-$system 2>&1 | tail -2; then
        bin=$(find /tmp/demo-$system -path '*release/SidebarSettingsDemo' -type f -perm +111 | head -1)
        echo "binary $bin"
        otool -l "$bin" | grep -A4 LC_BUILD_VERSION | grep -E 'minos|sdk'
        for sep in line automatic none; do
            for sc in 5 2; do shot "$system-$sep-$sc" "$(dirname "$bin")" "$sep" --scenario "$sc"; done
        done
        shot "$system-line-5-dark" "$(dirname "$bin")" line --scenario 5 --appearance dark
    fi
done
