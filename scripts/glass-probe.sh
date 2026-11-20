#!/usr/bin/env bash
# macOS 15, 26 and 27, Reduce Transparency off: which System Settings pages show their title in
# the toolbar at rest, and which only once the page scrolls.
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

title() {
    osascript -e 'tell application "System Events" to tell process "System Settings" to get value of attribute "AXTitle" of window 1' 2>&1
}

open -b com.apple.systempreferences
for _ in $(seq 1 60); do /tmp/find-window "System Settings" >/tmp/ss-window 2>/dev/null && break; sleep 0.5; done
sleep 4
osascript -e 'tell application "System Settings" to activate' >/dev/null 2>&1
sleep 1

# page LABEL PANE_ID: shows the pane, records the window's title and a capture at rest, then
# after the wheel scrolls the page.
page() {
    local label=$1 pane=$2
    open "x-apple.systempreferences:$pane"
    sleep 4
    away
    sleep 1
    if ! /tmp/find-window "System Settings" >/tmp/ss-window; then
        echo "$label: no window" | tee -a "$out/titles.txt"
        return
    fi
    read -r id x y w h </tmp/ss-window
    screencapture -o -l "$id" "$out/ss-$label-rest.png"
    local rest scrolled
    rest=$(title)
    /tmp/pointer $((x + w * 2 / 3)) $((y + h / 2)) 8; away; sleep 1.5
    screencapture -o -l "$id" "$out/ss-$label-scrolled.png"
    scrolled=$(title)
    echo "$label: rest=\"$rest\" scrolled=\"$scrolled\"" | tee -a "$out/titles.txt"
}

page general com.apple.systempreferences.GeneralSettings
page about com.apple.SystemProfiler.AboutExtension
page software-update com.apple.Software-Update-Settings.extension
page storage com.apple.settings.Storage
page appearance com.apple.Appearance-Settings.extension
page accessibility com.apple.Accessibility-Settings.extension
page control-center com.apple.ControlCenter-Settings.extension
page desktop-dock com.apple.Desktop-Settings.extension
page displays com.apple.Displays-Settings.extension
page wallpaper com.apple.Wallpaper-Settings.extension
page notifications com.apple.Notifications-Settings.extension
page sound com.apple.Sound-Settings.extension
page focus com.apple.Focus-Settings.extension
page lock-screen com.apple.Lock-Screen-Settings.extension
page privacy com.apple.settings.PrivacySecurity.extension
page users com.apple.Users-Groups-Settings.extension
page network com.apple.Network-Settings.extension
page wifi com.apple.wifi-settings-extension
page bluetooth com.apple.BluetoothSettings
page keyboard com.apple.Keyboard-Settings.extension
page trackpad com.apple.Trackpad-Settings.extension
page mouse com.apple.Mouse-Settings.extension
osascript -e 'tell application "System Settings" to quit' >/dev/null 2>&1
echo done
