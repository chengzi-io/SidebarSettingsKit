#!/usr/bin/env bash
# Where Tab moves the focus, in System Settings and in the kit's window, with the Keyboard
# navigation setting as the runner has it, then off (0), then on (2).
set -uo pipefail

system_settings() {
    osascript -e 'tell application "System Settings" to quit' >/dev/null 2>&1
    sleep 2
    open -b com.apple.systempreferences
    sleep 6
    osascript <<'APPLESCRIPT' 2>&1
tell application "System Settings" to activate
delay 2
set out to ""
tell application "System Events"
    tell process "System Settings"
        repeat with i from 0 to 6
            try
                set f to value of attribute "AXFocusedUIElement"
                set r to role of f
                set d to ""
                try
                    set d to description of f
                end try
                set n to ""
                try
                    set n to name of f
                end try
                set out to out & "SYS Tab " & i & ": " & r & " | " & d & " | " & n & linefeed
            on error e
                set out to out & "SYS Tab " & i & ": error " & e & linefeed
            end try
            key code 48
            delay 1
        end repeat
    end tell
end tell
return out
APPLESCRIPT
    osascript -e 'tell application "System Settings" to quit' >/dev/null 2>&1
}

run() {
    echo "=== $1: AppleKeyboardUIMode=$(defaults read -g AppleKeyboardUIMode 2>&1)"
    system_settings
    swift test --filter TabProbeTests 2>&1 | grep -E "PROBE|✘|passed|failed" | head -40
}

sw_vers
swift build --build-tests >/dev/null 2>&1 || swift build --build-tests 2>&1 | tail -20
run default
defaults write -g AppleKeyboardUIMode -int 0
run off
defaults write -g AppleKeyboardUIMode -int 2
run on
