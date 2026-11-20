#!/usr/bin/env bash
# Probe branch only: capture the settings window and dump its layout for each probe variant.
set -euo pipefail

readonly VARIANTS=(base sep,searchLarge sep,searchRounded)
readonly SCENARIOS=(1 2)

output_dir=${1:?usage: probe.sh OUTPUT_DIR}
mkdir -p "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd)
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."
repo_root=$PWD

swift build -c release --package-path Examples/SidebarSettingsDemo
cd Examples/SidebarSettingsDemo/.build/release

work_dir=$(mktemp -d)
failed=0
for variant in "${VARIANTS[@]}"; do
    for scenario in "${SCENARIOS[@]}"; do
        name="${variant//,/+}-scenario-$scenario"
        rm -f "$work_dir/id"
        SSK_PROBE="$variant" SSK_PROBE_DUMP="$output_dir/$name.txt" ./SidebarSettingsDemo \
            --icons plain --appearance light --scenario "$scenario" --window-id-file "$work_dir/id" &
        pid=$!
        for _ in $(seq 1 300); do
            [[ -s $work_dir/id ]] && break
            kill -0 "$pid" 2>/dev/null || break
            sleep 0.2
        done
        if [[ -s $work_dir/id ]]; then
            sleep 1
            if screencapture -o -l "$(<"$work_dir/id")" "$output_dir/$name.png"; then
                echo "ok   $name"
            else
                echo "FAIL $name: screencapture" >&2
                failed=$((failed + 1))
            fi
        else
            echo "FAIL $name: no window id" >&2
            failed=$((failed + 1))
        fi
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    done
done
# The same layout in plain SwiftUI: as it opens, scrolled to its end, and with the sidebar toggle.
for mode in top end top,toggle; do
    name="replica-${mode//,/+}"
    rm -f "$work_dir/id"
    SSK_PROBE_REPLICA="$mode" SSK_PROBE_DUMP="$output_dir/$name.txt" SSK_PROBE_ID_FILE="$work_dir/id" \
        ./SidebarSettingsDemo --appearance light &
    pid=$!
    for _ in $(seq 1 300); do
        [[ -s $work_dir/id ]] && break
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.2
    done
    if [[ -s $work_dir/id ]] && screencapture -o -l "$(<"$work_dir/id")" "$output_dir/$name.png"; then
        echo "ok   $name"
    else
        echo "FAIL $name" >&2
        failed=$((failed + 1))
    fi
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
done

# Apple's own System Settings, as the reference: as it opens, then scrolled.
tools=$(mktemp -d)
swiftc -O "$repo_root/scripts/probe-tools/find-window.swift" -o "$tools/find-window"
swiftc -O "$repo_root/scripts/probe-tools/scroll.swift" -o "$tools/scroll"
open "x-apple.systempreferences:com.apple.Appearance-Settings.extension"
sleep 6
if read -r id x y w h < <("$tools/find-window" "System Settings"); then
    screencapture -o -l "$id" "$output_dir/system-settings.png" && echo "ok   system-settings"
    "$tools/scroll" $((x + 300)) $((y + h * 2 / 3)) || echo "scroll failed"
    sleep 1
    screencapture -o -l "$id" "$output_dir/system-settings-scrolled.png" && echo "ok   system-settings-scrolled"
else
    echo "FAIL system-settings: no window" >&2
    failed=$((failed + 1))
fi
echo "==> $failed failed"
((failed == 0))
