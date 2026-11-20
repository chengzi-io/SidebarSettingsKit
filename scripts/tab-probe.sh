#!/usr/bin/env bash
# Where a real Tab key press (posted through System Events) moves the focus: in System Settings
# and in the demo's settings window. Keyboard navigation as the runner has it (off).
set -uo pipefail

# focus_walk PROCESS LABEL: the focused element, then after each of six Tab presses.
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

sw_vers
open -b com.apple.systempreferences
sleep 6
focus_walk "System Settings" SYS
osascript -e 'tell application "System Settings" to quit' >/dev/null 2>&1

swift build -c release --package-path Examples/SidebarSettingsDemo 2>&1 | tail -1
cd Examples/SidebarSettingsDemo/.build/release
./SidebarSettingsDemo --scenario 1 --window-id-file /tmp/wid &
demo=$!
for _ in $(seq 1 60); do [[ -s /tmp/wid ]] && break; sleep 0.5; done
sleep 2
focus_walk SidebarSettingsDemo KIT
# The same after a search and ↓ into the list, as the failing test does.
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
kill $demo
