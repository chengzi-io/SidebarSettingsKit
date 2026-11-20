#!/usr/bin/env bash
# What the macOS 27 SDK offers for a scroll view's edge effect, in AppKit and SwiftUI.
set -uo pipefail
mkdir -p glass
sdk=$(xcrun --show-sdk-path); xcrun --show-sdk-version
H=$sdk/System/Library/Frameworks/AppKit.framework/Headers
grep -rn -i 'EdgeEffect\|Pocket' "$H" | sed "s|$H/||" | cut -c1-260 | tee glass/appkit.txt
echo "== SwiftUI"
find "$sdk/System/Library/Frameworks/SwiftUI.framework" -name '*.swiftinterface' | head -3
iface=$(find "$sdk/System/Library/Frameworks/SwiftUI.framework" -name 'arm64e-apple-macos.swiftinterface' | head -1)
grep -n -i 'scrollEdgeEffect\|ScrollEdgeEffect' "$iface" | cut -c1-260 | head -40 | tee glass/swiftui.txt
for h in NSScrollView.h NSSplitViewItem.h NSWindow.h NSToolbar.h; do echo "== $h"; diff <(grep -n 'API_AVAILABLE(macos(27' "$H/$h" | cut -c1-240) /dev/null | sed 's/^< //' ; done | tee glass/new27.txt
