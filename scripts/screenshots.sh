#!/usr/bin/env bash
# Capture the demo's settings window, one PNG per kind of icons, appearance and scene.
#
# Works on a GitHub-hosted macOS runner (where /bin/bash already has Screen
# Recording permission) and locally (where the terminal needs that permission
# itself; without it screencapture returns a picture of the desktop only).

set -euo pipefail

readonly DEMO_PACKAGE_DIR="Examples/SidebarSettingsDemo"
readonly DEMO_BINARY="SidebarSettingsDemo"
readonly SCENARIOS=(1 2 3 4 5 6 6b 7)
readonly ICONS=(plain tiled)
readonly APPEARANCES=(light dark)
readonly WINDOW_ID_TIMEOUT=60

usage() {
    echo "usage: ${0##*/} OUTPUT_DIR [scenario ...]" >&2
    echo "scenarios: ${SCENARIOS[*]} (default: all)" >&2
    exit 2
}

if [[ $# -lt 1 ]]; then
    usage
fi
output_dir=$1
shift
if [[ $# -gt 0 ]]; then
    scenarios=("$@")
else
    scenarios=("${SCENARIOS[@]}")
fi

mkdir -p "$output_dir"
output_dir=$(cd -- "$output_dir" && pwd)
repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$repo_root"

echo "==> building $DEMO_BINARY (release)"
swift build -c release --package-path "$DEMO_PACKAGE_DIR"

# SwiftPM finds <Package>_<Target>.bundle next to the executable, so the demo is
# run from its own build directory and its binary is never moved.
cd "$DEMO_PACKAGE_DIR/.build/release"

macos_major=$(sw_vers -productVersion | cut -d. -f1)
work_dir=$(mktemp -d)
demo_pid=

stop_demo() {
    if [[ -n $demo_pid ]]; then
        kill "$demo_pid" 2>/dev/null || true
        wait "$demo_pid" 2>/dev/null || true
        demo_pid=
    fi
}

cleanup() {
    stop_demo
    rm -rf "$work_dir"
}
trap cleanup EXIT

# wait_for_window_id FILE PID: 0 once FILE holds a window id, 1 otherwise.
wait_for_window_id() {
    local file=$1 pid=$2
    local deadline=$((SECONDS + WINDOW_ID_TIMEOUT))
    while ((SECONDS < deadline)); do
        if [[ -s $file ]]; then
            return 0
        fi
        if ! kill -0 "$pid" 2>/dev/null; then
            return 1
        fi
        sleep 0.2
    done
    return 1
}

# capture ICONS APPEARANCE SCENARIO: 0 when the PNG was written.
capture() {
    local icons=$1 appearance=$2 scenario=$3
    local window_id_file=$work_dir/window-id
    local shot=$output_dir/macos-$macos_major-$icons-$appearance-scenario-$scenario.png
    local window_id
    local language_args=()

    # Scenario 7 shows the kit's own words in Simplified Chinese. The demo declares every
    # language the kit has in its embedded Info.plist, so the argument domain's AppleLanguages is
    # what the app's language follows; it changes this launch only, nothing is written to the
    # persistent defaults.
    if [[ $scenario == 7 ]]; then
        language_args=(-AppleLanguages "(zh-Hans)")
    fi

    rm -f "$window_id_file"
    ./"$DEMO_BINARY" \
        --icons "$icons" \
        --appearance "$appearance" \
        --scenario "$scenario" \
        --window-id-file "$window_id_file" \
        ${language_args[@]+"${language_args[@]}"} &
    demo_pid=$!

    if ! wait_for_window_id "$window_id_file" "$demo_pid"; then
        if kill -0 "$demo_pid" 2>/dev/null; then
            echo "FAIL $shot: scenario $scenario ($icons icons, $appearance) wrote no window id within ${WINDOW_ID_TIMEOUT}s" >&2
        else
            echo "FAIL $shot: scenario $scenario ($icons icons, $appearance) exited before writing a window id" >&2
        fi
        stop_demo
        return 1
    fi

    # Let the scene settle: sheets and sidebar rows animate in.
    sleep 1

    window_id=$(<"$window_id_file")
    if ! screencapture -o -l "$window_id" "$shot"; then
        echo "FAIL $shot: screencapture could not copy window $window_id" >&2
        stop_demo
        return 1
    fi
    stop_demo

    echo "ok   $shot"
}

captured=0
failed=0
for icons in "${ICONS[@]}"; do
    for appearance in "${APPEARANCES[@]}"; do
        for scenario in "${scenarios[@]}"; do
            if capture "$icons" "$appearance" "$scenario"; then
                captured=$((captured + 1))
            else
                failed=$((failed + 1))
            fi
        done
    done
done

echo "==> $captured captured, $failed failed (macOS $macos_major, $output_dir)"
if ((failed > 0)); then
    exit 1
fi
