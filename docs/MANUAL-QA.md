# Manual QA

The checks a maintainer makes before a release. Run each one on every macOS version you have; CI
covers macOS 15, 26 and 27 only.

Start the demo with the flags for the combination you are checking, or set the same thing in its
control panel and press **Open Settings**:

```
make demo
cd Examples/SidebarSettingsDemo && swift run SidebarSettingsDemo --style branded --appearance dark
```

## By macOS version

| Check | 26 | 15 | 14 |
| --- | --- | --- | --- |
| [ ] The sidebar keeps Liquid Glass: no preset changes its material | yes | no such look | no such look |
| [ ] Sidebar rows fade under the toolbar as you scroll the list | yes | system default | system default |
| [ ] The detail sits on the window's background, with no band under the toolbar | yes | yes | yes |
| [ ] The line under the toolbar follows the page: shown when scrolled, gone at the top | yes | yes | always shown; documented limit, not a bug |
| [ ] The window opens at 715 × 600 and cannot be resized (default configuration) | yes | yes | yes |
| [ ] The window opens where it was last positioned, across launches (AppKit's frame autosave) | yes | yes | yes |

macOS 26 and later are the versions where a wrong token or a stray background shows first. Check it with
`--style native` and `--style branded`, in both appearances.

## By style

### `.native`

- [ ] Rows look like the system sidebar: system height, system font, system icons. Changing the
      user's sidebar icon size in System Settings changes them too.
- [ ] The selection is the system highlight.
- [ ] Command-clicking the selected row keeps the page selected.
- [ ] Arrow keys move the selection.

### `.branded`

- [ ] Each icon sits on a 24 pt rounded square with 6 pt corners, the symbol white.
- [ ] The tile takes the page's tint; a page without a tint gets the tile's `defaultColor`.
- [ ] Rows fit the tiles with the system's padding, text 14 pt medium.
- [ ] The selection is the system highlight, as in `.native`.
- [ ] Untitled groups are set apart by space, titled groups show their title above the rows.

## Keyboard

- [ ] Arrow up and down move the selection, in both styles, with the window just opened.
- [ ] Typing the start of a page's title selects its row, in both styles.
- [ ] ⌘[ goes back, ⌘] forward; both enable and disable with the history.
- [ ] ⌘F focuses the search field from anywhere in the window.
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

## Dark mode

Launch with `--appearance dark`, both styles:

- [ ] Tiles and the selection stand out from the sidebar background.
- [ ] Row text and secondary text keep their contrast.
- [ ] The line under the toolbar is visible against the dark background.

## CI screenshots

Before a release, download the artifacts of the latest run of every runner and look at them:

```
gh run download --name screenshots-macos-15 --dir shots-15
gh run download --name screenshots-macos-26 --dir shots-26
gh run download --name screenshots-xcode-27 --dir shots-27
```

The matrix is two styles × two appearances × the scenarios in `scripts/screenshots.sh`, named
`macos-<major>-<style>-<appearance>-scenario-<n>.png`.

For every shot:

- [ ] The window is 715 × 600, the sidebar 215 pt wide.
- [ ] The appearance is the one in the file name.
- [ ] The search field is above the list, not in the toolbar.
- [ ] No page title is clipped or truncated where it should fit.
- [ ] The header is above the rows; where there is a footer, it is at the bottom.
- [ ] macOS 26 and 27 show Liquid Glass in the sidebar; macOS 15 does not.

Per scenario, check the one thing the scenario adds (the list is also in
[DEVELOPMENT.md](DEVELOPMENT.md)):

- [ ] `1`: three rows, the default window, no line under the toolbar at the top of the page.
- [ ] `2`: a long page opened at its end, the line under the toolbar shown while it is scrolled.
- [ ] `3`: over 40 rows, the sidebar scrolled to the last page with its row selected.
- [ ] `4`: titled and untitled groups side by side; an untitled group is set apart by space.
- [ ] `5`: the account header above the rows scrolls away; the tall footer stays at the bottom
      and is not clipped.
- [ ] `6`: the search shows only the pages that match.
- [ ] `6b`: a search that matches nothing leaves an empty list, and clearing it brings every
      page back.
- [ ] `7`: a 60-character title is truncated with an ellipsis instead of widening the sidebar;
      the words are Chinese.
