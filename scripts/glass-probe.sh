#!/usr/bin/env bash
# With Reduce Transparency off: the kit's window with the appearance forced by the demo, left to
# the system, and dark through the argument domain; with each separator style; and the replica
# with and without a forced aqua appearance.
set -uo pipefail
out=$PWD/glass; mkdir -p "$out"
swiftc -O scripts/probe-tools/find-window.swift -o /tmp/find-window
swiftc -O -parse-as-library scripts/probe-tools/replica.swift -o /tmp/Replica
swiftc -O scripts/probe-tools/pointer.swift -o /tmp/pointer

sw_vers -productVersion
defaults write com.apple.universalaccess reduceTransparency -bool false
defaults write com.apple.universalaccess reduceMotion -bool false
sleep 2
/tmp/pointer 1000 740

swift build -c release --package-path Examples/SidebarSettingsDemo 2>&1 | tail -1
demo=$PWD/Examples/SidebarSettingsDemo/.build/release/SidebarSettingsDemo

shot() { # NAME SEPARATOR ARGS... : the demo's settings window as NAME.png
    local name=$1 separator=$2; shift 2
    local id_file=/tmp/window-id
    rm -f "$id_file"
    (cd "$(dirname "$demo")" && SSK_PROBE_SEPARATOR=$separator ./SidebarSettingsDemo --icons tiled --window-id-file "$id_file" "$@" >/dev/null 2>&1) &
    local pid=$!
    for _ in $(seq 1 150); do [[ -s $id_file ]] && break; sleep 0.2; done
    sleep 1.5
    screencapture -o -l "$(<"$id_file")" "$out/$name.png" && echo "ok $name"
    pkill -f SidebarSettingsDemo; wait "$pid" 2>/dev/null; sleep 0.5
}

for sep in line automatic none; do
    for sc in 5 2; do
        shot "system-light-$sep-$sc" "$sep" --scenario "$sc"
    done
done
for sc in 5 2; do
    shot "forced-light-line-$sc" line --appearance light --scenario "$sc"
done
shot forced-dark-line-5 line --appearance dark --scenario 5
shot argdark-line-5 line --scenario 5 -AppleInterfaceStyle Dark
shot argdark-automatic-5 automatic --scenario 5 -AppleInterfaceStyle Dark

for variant in default aqua; do
    if [[ $variant == aqua ]]; then export SSK_REPLICA_AQUA=1; fi
    /tmp/Replica >/dev/null 2>&1 &
    pid=$!
    sleep 6
    read -r id _ < <(/tmp/find-window Replica)
    screencapture -o -l "$id" "$out/replica-$variant.png" && echo "ok replica $variant"
    kill "$pid"; sleep 1
done
