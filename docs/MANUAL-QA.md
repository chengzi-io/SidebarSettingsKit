# Manual QA

The checks a maintainer makes before a release. Run each one on every macOS version you have; CI
covers macOS 15 and macOS 26 only.

Start the demo with the flags for the combination you are checking, or set the same thing in its
control panel and press **Open Settings**:

```
make demo
cd Examples/SidebarSettingsDemo && swift run --build-system native SidebarSettingsDemo --icons tiled --appearance dark
```

## By macOS version

| Check | 26 | 15 | 14 |
| --- | --- | --- | --- |
| [ ] The sidebar keeps Liquid Glass, with plain icons and tiled | yes | no such look | no such look |
| [ ] Sidebar rows fade under the toolbar as you scroll the list | yes | system default | system default |
| [ ] The detail sits on the window's background, with no band under the toolbar | yes | yes | yes |
| [ ] The line under the toolbar: none at the top of a page, shown once it scrolls, none again on a new page | no line at all | yes | always shows ([known limit](ROADMAP.md)) |
| [ ] Compact **Toolbar style**: the sidebar's top gap matches its bottom gap | yes | yes | yes |
| [ ] The window opens at 715 × 600 and cannot be resized (default configuration) | yes | yes | yes |
| [ ] The minimize and zoom buttons are dimmed, also with **Resizing** set to resizable; double-clicking the title bar does not zoom the window, and Window › Enter Full Screen is unavailable | yes | yes | yes |
| [ ] The window opens where it was last positioned, across launches (AppKit's frame autosave) | yes | yes | yes |

macOS 26 is the version where a wrong token or a stray background shows first. Check it with
`--icons plain` and `--icons tiled`, in both appearances.

The sidebar's top and bottom gaps are zero on macOS 14, 15 and 27: it reaches the window's edge.
macOS 26 runs a compact toolbar as `.automatic`, so both gaps are the floating sidebar's inset.

## By kind of icons

### `.plain`

- [ ] Rows look like the system sidebar: system height, system font, system icons. Changing the
      user's sidebar icon size in System Settings changes them too.
- [ ] The selection is the system highlight.
- [ ] A tinted icon (Appearance in the demo) shows its tint, and turns white with its title on the
      selected row in the key window.
- [ ] Command-clicking the selected row keeps the page selected.
- [ ] Arrow keys move the selection.

### `.tiled`

- [ ] Each icon sits on a rounded square, the symbol white, placed as in System Settings: the
      square's left edge as far from the selection's edge as the square is from the title.
- [ ] With the demo launched with `-NSTableViewDefaultSizeMode 1`, `2` and `3`, the squares are
      16, 20 and 24 pt and the rows as tall as `.plain`'s at the same size, as System Settings'
      follow its own Sidebar icon size setting.
- [ ] The tile takes the page's tint; a page without a tint (General in the demo) gets gray.
- [ ] Row text is the system's, as in `.plain`.
- [ ] The selection is the system highlight, as in `.plain`.

## Keyboard

- [ ] Arrow up and down move the selection, plain and tiled, with the window just opened.
- [ ] Typing the start of a page's title selects its row, plain and tiled.
- [ ] ⌘[ goes back, ⌘] forward; both enable and disable with the history.
- [ ] ⌘F focuses the search field from anywhere in the window.
- [ ] In the search field, ↓ moves to the pages found and opens the first when the search hides
      the page shown; ↑ and ↓ then move through the pages found, ↑ on the first stays in the list,
      and Tab goes back to the field with the search kept.
- [ ] Typing a search that finds nothing, then deleting a letter, keeps the typing in the field.
- [ ] With Keyboard navigation on (System Settings › Keyboard), Tab also reaches the page's
      controls and comes back to the search field.
- [ ] Esc clears the search field and the list shows every page again.
- [ ] ⌘W closes the window; ⌘, opens it again, on the page it was closed on.
- [ ] After the window is closed with ⌘W, Settings… opens the same window, not a second one.
- [ ] With **Back and forward buttons** off in the control panel, ⌘[ and ⌘] do nothing.

## VoiceOver

Turn VoiceOver on (⌘F5) and tab through the window:

- [ ] Each sidebar row reads its title, and the selected row says "selected".
- [ ] The back and forward buttons read "Back" and "Forward".
- [ ] The search field reads the search prompt.
- [ ] The window title names the selected page, also with `title = .hidden`.

## Chinese UI

Set the system language to Simplified Chinese (System Settings > General > Language & Region), or
run the demo with `--scenario 7`, whose screenshot is taken in Chinese:

- [ ] The search prompt reads 搜索.
- [ ] The app menu item reads 设置….
- [ ] VoiceOver and the toolbar's overflow menu read 返回 and 前进.
- [ ] Page titles come from the app's own strings and are not cut off in the sidebar.

## Other languages

Run the demo with `-AppleLanguages "(ja)"` after its flags, then `"(de)"`:

- [ ] The search prompt, and No Results with `--scenario 6b`, are in that language.

Add `-AppleLanguages "(ar)" -AppleTextDirection YES -NSForceRightToLeftWritingDirection YES` for
a right-to-left window:

- [ ] The sidebar and the window buttons are on the right, and the back arrow, next to the
      sidebar, points right.

## Dark mode

Launch with `--appearance dark`, plain and tiled:

- [ ] Tiles and the selection stand out from the sidebar background.
- [ ] Row text and secondary text keep their contrast.
- [ ] Where the line under the toolbar shows, it is visible against the dark background.
- [ ] Switching the Mac between Light and Dark (System Settings › Appearance) with the window open
      switches the window with it.

## CI screenshots

Before a release, download the artifacts of the latest run of every runner and look at them:

```
gh run download --name screenshots-macos-15 --dir shots-15
gh run download --name screenshots-macos-26 --dir shots-26
gh run download --name screenshots-xcode-27 --dir shots-27
```

The matrix is two kinds of icons × two appearances × the scenarios in `scripts/screenshots.sh`, named
`macos-<major>-<icons>-<appearance>-scenario-<n>.png`.

For every shot:

- [ ] The window is 715 × 600, the sidebar 215 pt wide.
- [ ] The appearance is the one in the file name.
- [ ] The search field is above the list, not in the toolbar.
- [ ] No page title is clipped or truncated where it should fit.
- [ ] The header is above the rows; where there is a footer, it is at the bottom.
- [ ] macOS 26 shows Liquid Glass in the sidebar; macOS 15 does not.

Per scenario, check the one thing the scenario adds (the list is also in
[DEVELOPMENT.md](DEVELOPMENT.md)):

- [ ] `1`: three rows, the default window. On macOS 15 the toolbar above the page is the page's
      color, active or not, with the pointer over the window or away from it.
- [ ] `2`: a long page opened at its end, scrolled under the toolbar.
- [ ] `3`: over 40 rows, the sidebar scrolled to the last page with its row selected.
- [ ] `4`: three groups, set apart by space, without titles.
- [ ] `5`: the account header above the rows scrolls away; the tall footer stays at the bottom
      and is not clipped.
- [ ] `6`: the search shows only the pages that match.
- [ ] In every toolbar style of the control panel, the back and forward arrows show no labels
      under them.
- [ ] With **Back and forward buttons** off, the title starts in line with the page's grouped form,
      not against the sidebar. On macOS 26, note where it sits and whether an empty glass shape
      shows before it.
- [ ] `6b`: a search that matches nothing shows a small, light "No Results" under a small
      magnifying glass, and clearing it brings every page back.
- [ ] `7`: a 60-character title is truncated with an ellipsis instead of widening the sidebar;
      the words are Chinese.
