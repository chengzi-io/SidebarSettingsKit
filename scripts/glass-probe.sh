#!/usr/bin/env bash
# macOS 27, Reduce Transparency off: how Apple's own apps draw the toolbar's scroll edge when
# their content scrolls under it, and whether their toolbar shows a title.
set -uo pipefail
out=$PWD/glass; mkdir -p "$out"
swiftc -O scripts/probe-tools/pointer.swift -o /tmp/pointer
swiftc -O scripts/probe-tools/find-window.swift -o /tmp/find-window
{ sw_vers; xcodebuild -version; } | tee "$out/versions.txt"
defaults write com.apple.universalaccess reduceTransparency -bool false
defaults write com.apple.universalaccess reduceMotion -bool false
sleep 2
read -r screen_w screen_h < <(osascript -l JavaScript -e 'ObjC.import("AppKit"); var f = $.NSScreen.mainScreen.frame; f.size.width + " " + f.size.height')
away() { /tmp/pointer $((screen_w - 5)) $((screen_h - 5)); }
away

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

# app_shot LABEL OWNER COMMAND...: opens the app, captures its front window at rest and after the
# wheel scrolls its content, and dumps the window's elements.
app_shot() {
    local label=$1 owner=$2
    shift 2
    "$@" >/dev/null 2>&1 &
    for _ in $(seq 1 60); do /tmp/find-window "$owner" >/tmp/app-window 2>/dev/null && break; sleep 0.5; done
    sleep 4
    osascript -e "tell application \"System Events\" to set frontmost of process \"$owner\" to true" >/dev/null 2>&1
    sleep 1
    if ! /tmp/find-window "$owner" >/tmp/app-window; then
        echo "no window $label"
        return
    fi
    read -r id x y w h </tmp/app-window
    echo "$label window $id at $x $y $w $h"
    screencapture -o -l "$id" "$out/app-$label-rest.png"
    ax_dump "$owner" "$out/ax-$label-rest.txt"
    /tmp/pointer $((x + w * 2 / 3)) $((y + h / 2)) 8; away; sleep 1.5
    screencapture -o -l "$id" "$out/app-$label-scrolled.png"
    ax_dump "$owner" "$out/ax-$label-scrolled.txt"
    osascript -e "tell application \"$owner\" to quit" >/dev/null 2>&1
    sleep 2
    pkill -x "$owner" 2>/dev/null
    echo "ok $label"
}

app_shot activity-monitor "Activity Monitor" open -a "Activity Monitor"
app_shot font-book "Font Book" open -a "Font Book"
app_shot finder Finder open /System/Library/Frameworks
app_shot textedit TextEdit open -a TextEdit /etc/services
app_shot system-information "System Information" open -a "System Information"
app_shot console Console open -a Console
app_shot music Music open -a Music
app_shot notes Notes open -a Notes
