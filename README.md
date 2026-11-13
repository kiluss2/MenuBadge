# MenuBadge

Menu bar app that mirrors apps' **Dock badges** (unread counts) onto the menu bar, so they stay
visible while the Dock is auto-hidden. Successor of `slack-menubar-badge` (Slack only).

- Turn apps on in Settings; each gets its badge on its own menu bar icon, or on a MenuBadge item
  with the app's icon when it has none (Placement: Auto / On the app's icon / MenuBadge item).
- Per-app look on top of a shared default: corner, size (8–16 pt), number / dot / text colours,
  animation while shown (Blink, Breathe, Bounce, Ripple, None) and on a new badge (Shake, Bounce,
  None).
- Settings: open MenuBadge again (Spotlight, Launchpad, Finder) or use its menu bar icon.
- Reads everything through Accessibility (Dock tile `AXStatusLabel`, app `AXExtrasMenuBar`), polled
  once a second; ~15 MB, ~0.15 % CPU, nothing animates between blinks.

Design and plan: `docs/superpowers/specs/2026-11-13-menubadge-design.md`,
`docs/superpowers/plans/2026-11-13-menubadge.md`.

## Install / remove

```bash
scripts/install.sh     # Release build → ~/Applications/MenuBadge.app, migrates from slack-menubar-badge
scripts/uninstall.sh   # login item off, app to the Trash, Accessibility entry reset
```

Needs Xcode and `xcodegen` (`brew install xcodegen`). Grant Accessibility once
(System Settings › Privacy & Security › Accessibility › MenuBadge). The app is signed with the
self-signed `kiluss2 Local Code Signing` identity so the permission survives rebuilds; the hub
README (`../README.md`) shows how to recreate it on a new Mac.

## Develop

```bash
xcodegen generate                       # MenuBadge.xcodeproj is generated, not committed
xcodebuild test -project MenuBadge.xcodeproj -scheme BadgeKit -destination platform=macOS
open MenuBadge.xcodeproj
```

- `BadgeKit/` – pure logic with unit tests (labels, settings, geometry, placement, curves).
- `MenuBadge/` – AppKit/AX/SwiftUI app (readers, overlay, own items, engine, Settings).
- `MENUBADGE_DEMO=<bundle id>` (`1` = Slack) runs every badge state on that app, then quits;
  "Preview All States" in an app's Settings does the same without quitting.
- `swift scripts/make-appicon.swift` redraws the app icon.
