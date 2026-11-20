#!/usr/bin/env bash
# macOS 26 and 27, Reduce Transparency off: where System Settings puts its toolbar title (window
# title or toolbar item); the kit's title as the window title or as a toolbar item, at the top and
# scrolled; how the tiled icons' symbols are sized; a real Tab in a demo linked with the right SDK;
# the SDK each build system records; the new AppKit and SwiftUI API and accessibility settings.
set -uo pipefail
out=$PWD/glass; mkdir -p "$out"
swiftc -O scripts/probe-tools/find-window.swift -o /tmp/find-window
swiftc -O scripts/probe-tools/pointer.swift -o /tmp/pointer
{ sw_vers; swift --version 2>&1 | head -1; xcodebuild -version; } | tee "$out/versions.txt"

defaults read com.apple.universalaccess >"$out/ua-image.txt" 2>&1
defaults write com.apple.universalaccess reduceTransparency -bool false
defaults write com.apple.universalaccess reduceMotion -bool false
sleep 2
defaults read com.apple.universalaccess >"$out/ua-probe.txt" 2>&1
read -r screen_w screen_h < <(osascript -l JavaScript -e 'ObjC.import("AppKit"); var f = $.NSScreen.mainScreen.frame; f.size.width + " " + f.size.height')
echo "screen $screen_w x $screen_h"
away() { /tmp/pointer $((screen_w - 5)) $((screen_h - 5)); }
away

# API
sdk=$(xcrun --sdk macosx --show-sdk-path)
appkit=$sdk/System/Library/Frameworks/AppKit.framework/Headers
grep -rn "macos(27" "$appkit" >"$out/appkit-27.txt"
grep -n "macos(26" "$appkit"/NSToolbarItem.h "$appkit"/NSToolbar.h "$appkit"/NSWindow.h "$appkit"/NSScrollView.h \
    "$appkit"/NSSplitViewItem.h "$appkit"/NSTitlebarAccessoryViewController.h >"$out/appkit-26-window.txt"
grep -n -i -E "accessibilityDisplay|border" "$appkit"/NSWorkspace.h >"$out/a11y-api.txt"
: >"$out/swiftui-27.txt"
while IFS= read -r interface; do
    echo "== $interface" >>"$out/swiftui-27.txt"
    grep -n "macOS 27" "$interface" >>"$out/swiftui-27.txt"
done < <(find "$sdk/System/Library/Frameworks/SwiftUI.framework" "$sdk/System/Library/Frameworks/SwiftUICore.framework" \
    -name 'arm64e-apple-macos.swiftinterface' 2>/dev/null)

# ax_dump PROCESS FILE: the front window's title and its elements, not descending into lists.
ax_dump() {
    osascript - "$1" >"$2" 2>&1 <<'APPLESCRIPT'
on run argv
    tell application "System Events" to tell process (item 1 of argv)
        set w to window 1
        set out to "window AXTitle: " & (value of attribute "AXTitle" of w) & linefeed
        set out to out & my walk(w, 0)
    end tell
    return out
end run
on walk(e, depth)
    tell application "System Events"
        set r to ""
        try
            set r to role of e
        end try
        set sr to ""
        try
            set sr to subrole of e
        end try
        set t to ""
        try
            set t to (value of attribute "AXTitle" of e) as text
        end try
        set v to ""
        try
            set v to (value of e) as text
        end try
        set d to ""
        try
            set d to description of e
        end try
        set i to ""
        try
            set i to (value of attribute "AXIdentifier" of e) as text
        end try
        set p to ""
        try
            set p to (position of e as text)
        end try
        set indent to ""
        repeat depth times
            set indent to indent & "  "
        end repeat
        set s to indent & r & "/" & sr & " title=" & t & " value=" & v & " desc=" & d & " id=" & i & " pos=" & p & linefeed
        if depth < 7 and r is not in {"AXOutline", "AXTable", "AXList", "AXScrollArea", "AXWebArea"} then
            try
                repeat with c in (UI elements of e)
                    set s to s & my walk(c, depth + 1)
                end repeat
            end try
        end if
    end tell
    return s
end walk
APPLESCRIPT
}

# System Settings
open -b com.apple.systempreferences
sleep 6
osascript -e 'tell application "System Settings" to activate' >/dev/null 2>&1
sleep 2
read -r id x y w h < <(/tmp/find-window "System Settings")
echo "system settings window $id at $x $y $w $h"
screencapture -o -l "$id" "$out/ss-rest.png"
ax_dump "System Settings" "$out/ax-ss-rest.txt"
/tmp/pointer $((x + w * 2 / 3)) $((y + h / 2)) 4; away; sleep 1.5
screencapture -o -l "$id" "$out/ss-scrolled.png"
ax_dump "System Settings" "$out/ax-ss-scrolled.txt"
osascript -e 'tell application "System Settings" to quit' >/dev/null 2>&1
sleep 2
echo "ok system settings"

# The demo, linked with the SDK it builds with
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

for title in window item; do
    for scenario in 5 2; do
        launch "title-$title-$scenario" $scenario SSK_PROBE_TITLE=$title
        screencapture -o -l "$(</tmp/wid)" "$out/title-$title-$scenario.png"
        [[ $scenario == 2 ]] && ax_dump SidebarSettingsDemo "$out/ax-kit-$title.txt"
        finish
        echo "ok title $title $scenario"
    done
done

for icon in font medium small fit; do
    launch "icon-$icon" 5 SSK_PROBE_ICON=$icon
    screencapture -o -l "$(</tmp/wid)" "$out/icon-$icon.png"
    finish
    echo "ok icon $icon"
done

# Tab: where a real key press (System Events) moves the focus, in System Settings and the demo.
focus_walk() {
    osascript - "$1" "$2" <<'APPLESCRIPT' 2>&1
on run argv
    set processName to item 1 of argv
    set label to item 2 of argv
    set out to ""
    tell application "System Events"
        set frontmost of process processName to true
        delay 1.5
        tell process processName
            repeat with i from 0 to 6
                try
                    set f to value of attribute "AXFocusedUIElement"
                    set d to ""
                    try
                        set d to description of f
                    end try
                    set out to out & label & " Tab " & i & ": " & (role of f) & " | " & d & linefeed
                on error e
                    set out to out & label & " Tab " & i & ": error " & e & linefeed
                end try
                key code 48
                delay 1
            end repeat
        end tell
    end tell
    return out
end run
APPLESCRIPT
}
{
    open -b com.apple.systempreferences
    sleep 6
    focus_walk "System Settings" SYS
    osascript -e 'tell application "System Settings" to quit' >/dev/null 2>&1
    sleep 2
    rm -f /tmp/wid
    (cd "$dir" && ./SidebarSettingsDemo --scenario 1 --window-id-file /tmp/wid >/dev/null 2>&1) &
    for _ in $(seq 1 150); do [[ -s /tmp/wid ]] && break; sleep 0.2; done
    sleep 2
    focus_walk SidebarSettingsDemo KIT
    osascript <<'APPLESCRIPT' 2>&1
tell application "System Events"
    tell process "SidebarSettingsDemo"
        keystroke "f" using command down
        delay 0.5
        keystroke "ance"
        delay 0.8
        key code 125
        delay 0.8
    end tell
end tell
APPLESCRIPT
    focus_walk SidebarSettingsDemo KIT-SEARCH
    finish
} | tee "$out/tab.txt"

# The SDK a plain executable records with each build system.
hello=$(mktemp -d)
mkdir -p "$hello/Sources/Hello"
cat >"$hello/Package.swift" <<'EOF'
// swift-tools-version: 6.2
import PackageDescription
let package = Package(name: "Hello", platforms: [.macOS(.v14)], targets: [.executableTarget(name: "Hello")])
EOF
echo 'import AppKit; print(NSApplication.shared)' >"$hello/Sources/Hello/main.swift"
{
    for system in default native; do
        flags=(); [[ $system == native ]] && flags=(--build-system native)
        (cd "$hello" && swift build -c release ${flags[@]+"${flags[@]}"} --scratch-path ".build-$system" 2>&1 | tail -1)
        bin=$(find "$hello/.build-$system" -type f -perm -111 -name Hello | head -1)
        echo "$system: $(otool -l "$bin" | grep -A4 LC_BUILD_VERSION | grep -E 'minos|sdk' | xargs)"
    done
} | tee "$out/sdk-check.txt"
