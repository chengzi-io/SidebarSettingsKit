#!/usr/bin/env bash
# Probe branch only: capture the settings window and dump its layout for each probe variant.
set -euo pipefail

readonly VARIANTS=(base sep sep,noSoft sep,adjust sep,trackingItem sep,sidebarSafeNone compact unified)
readonly SCENARIOS=(1 2 3 5)

output_dir=${1:?usage: probe.sh OUTPUT_DIR}
mkdir -p "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd)
cd "$(dirname -- "${BASH_SOURCE[0]}")/.."

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
echo "==> $failed failed"
((failed == 0))
