# MenuBadge

Menu bar app that mirrors apps' **Dock badges** (unread counts) onto the menu bar, so they stay
visible while the Dock is auto-hidden. Successor of `slack-menubar-badge` (Slack only).

- Turn apps on in Settings; each gets its badge on its own menu bar icon, or on a MenuBadge item
  with the app's icon when it has none (Placement: Auto / On the app's icon / MenuBadge item).
  An app whose own icon is switched off in the app (Slack's menu bar icon, for one) has none, so
  its badge goes on a MenuBadge item; Settings says so. A MenuBadge item shows while its app is
  open (or only with a badge) and goes away when the app quits. ⌘-drag it to move it; the place
  is kept.
- Per-app look on top of a shared default: corner, size (8–16 pt), app icon size on a MenuBadge
  item (16–22 pt, default 20; the item is 24 pt tall), number / dot / text colours,
  animation while shown (Blink, Breathe, Bounce, Ripple, None) and on a new badge (Shake, Bounce,
  None). Each value on an app's page says whether it is set for the app or comes from Default
  Look, and ↺ makes it follow Default Look again. Counts above 999 show as "999+".
- Settings: open MenuBadge again (Spotlight, Launchpad, Finder) or use its menu bar icon. Stored
  as JSON in the `MenuBadge.settings.v1` user default; a value this version cannot read keeps its
  default, and settings that cannot be read at all are kept under `MenuBadge.settings.v1.unreadable`.
- Reads everything through Accessibility (Dock tile `AXStatusLabel`, app `AXExtrasMenuBar`), polled
  once a second; ~15 MB, ~0.15 % CPU, nothing animates between blinks.

Design and plan: `docs/superpowers/specs/2026-11-13-menubadge-design.md`,
`docs/superpowers/plans/2026-11-13-menubadge.md`.

## Install / remove

```bash
scripts/install.sh     # Release build → ~/Applications/MenuBadge.app, migrates from slack-menubar-badge
scripts/uninstall.sh   # login item off, app to the Trash, Accessibility entry reset
```

Needs Xcode and `xcodegen` (`brew install xcodegen`). The install build goes to
`~/Library/Caches/MenuBadge/DerivedData`, which Spotlight skips, so only the installed app shows
up when you search for MenuBadge. Grant Accessibility once
(System Settings › Privacy & Security › Accessibility › MenuBadge). The app is signed with the
self-signed `kiluss2 Local Code Signing` identity so the permission survives rebuilds; the
[mac-tools README](https://github.com/kiluss2/mac-tools#code-signing-for-tools-that-need-privacy-permissions)
shows how to recreate it on a new Mac.

## Develop

```bash
xcodegen generate                       # MenuBadge.xcodeproj is generated, not committed
xcodebuild test -project MenuBadge.xcodeproj -scheme BadgeKit -destination platform=macOS
open MenuBadge.xcodeproj
```

- `BadgeKit/` – pure logic with unit tests (labels, settings, geometry, placement, curves, status
  text).
- `MenuBadge/` – AppKit/AX/SwiftUI app (readers, overlay, own items, engine, Settings).
- `MENUBADGE_DEMO=<bundle id>` (`1` = Slack) runs every badge state on that app, then quits;
  "Preview All States" in an app's Settings does the same without quitting.
- `swift scripts/make-appicon.swift` redraws the app icon.
