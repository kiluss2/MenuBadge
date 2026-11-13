# Compact mode and update check — design

Date: 2026-11-13. Status: draft for review. The user handed the design calls to Claude
("bạn tự quyết"); every choice below is Claude's call unless marked as the user's.

## Why

1. **Compact mode.** When the menu bar is full (a MacBook notch, a narrow display, many icons),
   macOS hides the status items that do not fit. Today a hidden app icon makes MenuBadge fall back
   to a MenuBadge item for that app, and that new item lands in the hidden area too, so the badge
   disappears. One item that carries every badge is much less likely to be cut, and the user can
   ⌘-drag it next to the clock. Mostly for people the app is shared with (the author's Mac mini has
   no notch).
2. **Update check.** The app is shared through GitHub releases; people who got it should learn
   about a new version and install it with one click, without the Terminal.

## Goals

- A General setting that gathers all badges into one menu bar item.
- At a glance the user still sees *which* apps have unread items, not just a total.
- MenuBadge checks GitHub for a newer release and offers a one-click update.

## Non-goals

- Event-driven badge reading (idea 2). Probed on 2026-11-13 with an `AXObserver` on the Dock and a
  helper that changed its own Dock badge: the Dock posts only `AXCreated` / `AXUIElementDestroyed`
  (a tile appears or goes); `AXValueChanged`, `AXTitleChanged`, `AXLayoutChanged` and
  `AXStatusLabelChanged` return `kAXErrorNotificationUnsupported` (-25207) on the Dock app and on
  each tile. Polling once a second stays.
- Detecting automatically that items are hidden and switching to compact by itself.
- Notarization, Sparkle or any third-party framework; system notifications for updates.

## Anti-goals

- A compact item that grows without limit (it would get hidden itself).
- An update path that runs code fetched at click time, or that loses the Accessibility grant.
- Network traffic beyond one small anonymous request a day.

## Approaches considered (compact item drawing)

| | How | Trade-off |
|---|---|---|
| **A (chosen)** | One `NSStatusItem` whose button image is redrawn as one composited `NSImage` (icons + badges) whenever what it shows changes | Simple; copies on other displays update by themselves because the image changes; no idle animations |
| B | One item with a badge `CALayer` per app (like `OwnItemPresenter`) | Keeps idle animations, but needs the per-display redraw workaround times N and much more code |
| C | MenuBadge glyph with a total count | Smallest, but loses "which app" — fails a goal |

A, because several badges blinking side by side would be noisy anyway, and it avoids the
inactive-display redraw problem B would multiply.

## Design: compact mode

**Setting.** General › MenuBadge section: toggle **"Gather badges in one item"** (default off;
stored as `compact: Bool` in `MenuBadgeSettings`, read leniently like the other fields). Footer
text explains it is for a full menu bar and that ⌘-drag moves the item.

**Which item.** Compact mode uses MenuBadge's own icon (`MenuBarItem`, autosave name `MenuBadge`),
so the item keeps its place and its menu. While compact is on, the item is shown even if "Show
MenuBadge in menu bar" is off (that toggle is disabled with a note "Always shown in compact
mode"). No overlays and no per-app MenuBadge items are created; existing ones are removed when the
toggle turns on, and normal placement resumes when it turns off.

**What it shows.**
- No badges: the MenuBadge glyph, as today.
- Badges: the apps that have one, in sidebar order, each as its trimmed app icon at the app's
  `iconSize` with its badge in its own look (corner, size, colours), 4 pt apart.
- At most 3 apps drawn; a 4th or more becomes a "+N" label (secondary text colour, 11 pt) after
  the third. Max width ≈ 3 × 26 + 20 pt.
- Paused (Pause all badges): the glyph only.
- Running-only, as today: a quit app's badge is gone.

**Animation.** No idle animations in compact mode. When any app's badge grows (the `grew` signal
the engine already computes), the whole button plays that app's `onNew` effect (Shake or Bounce)
once on the button layer, using `BadgeAnimations`.

**Menu.** Above today's items, one row per enabled app that has a badge: app icon, name, badge
text right-aligned (e.g. "Slack 3"); choosing it opens the app (same as `OwnItemPresenter.openApp`).
A separator, then Settings…, Pause All Badges, (Update row, below), Quit. Rows are rebuilt in
`menuWillOpen`.

**Code shape.**
- BadgeKit: `CompactLayout` — pure function from `[(bundleID, label, appearance)]` in sidebar
  order to the drawn entries + overflow count, with unit tests (ordering, max 3, +N, dot vs count,
  empty). `PlacementInput` gains nothing; the engine skips `resolvePlacement` and hides presenters
  when `compact` is on.
- App: `CompactRenderer` draws the image (reusing `BadgeRenderer.image` and `AppIconCache`);
  `MenuBarItem` gets `showCompact(_ entries:)` and the app rows; `BadgeEngine.tick` collects the
  labels and hands them over.

## Design: update check

**When.** On launch (after 10 s) and every 24 h while running, if **"Check for updates
automatically"** is on (General, default on, `checkForUpdates: Bool`). Plus a manual **Check for
Updates…** button in General and in the menu.

**How.** `GET https://api.github.com/repos/kiluss2/MenuBadge/releases/latest` with
`URLSession`, `Accept: application/vnd.github+json`, User-Agent `MenuBadge/<version>` (no
personal data, no auth). Read `tag_name` (`v1.1.0`) and the `MenuBadge.dmg` asset's
`browser_download_url`. Compare with `CFBundleShortVersionString` numerically per dot component
(BadgeKit `AppVersion`, unit tested: 1.10.0 > 1.9.0, `v` prefix, missing parts = 0, garbage =
no update). Drafts and prereleases are already excluded by `/latest`. For testing,
`MENUBADGE_RELEASE_API_URL` overrides the API URL (a local `file://` JSON works).

**Shown.** When newer: General shows "MenuBadge 1.1.0 is available" with **Update** and a link to
the release notes (`html_url`); the menu shows **Update to 1.1.0…**. Nothing else (no
notification, no badge on the glyph). A manual check that finds nothing says "MenuBadge is up to
date" in place; a failed check says "Could not check for updates" (automatic failures stay
silent).

**Updating.** `scripts/install-release.sh` is copied into the app bundle (Resources) at build
time. Update runs `/bin/bash <bundled script>` detached (new process group, so it survives
MenuBadge quitting), with `MENUBADGE_DMG_URL` set to the asset URL of the exact release found.
The script already quits MenuBadge, replaces the app in the same folder, and reopens it; the new
build is signed with the same identity, so Accessibility stays granted. No script is fetched from
the network. A downloaded DMG via curl carries no quarantine flag, as today.

**Release flow.** Bump `MARKETING_VERSION` in `project.yml` for each release (1.1.0 for this
work); `make-release.sh` unchanged. README: mention the daily check and how to turn it off.

## Design: lighter polling

Measured on 2026-11-13 (Mac mini, Slack + Telegram on): MenuBadge used 0.05 s CPU per minute
(~0.08 %), the Dock 0.02 s per minute in total, ~15 MB at launch (46 MB after the Settings window
had been open). A second event source was also probed: LaunchServices keeps a `StatusLabel` per
app but `lsappinfo listen +all` posts nothing when it changes. Two cheap savings remain:

- **Sleep with the screen.** Stop the 1 s timer on `NSWorkspace.screensDidSleepNotification` and
  `NSWorkspace.sessionDidResignActiveNotification` (fast user switch) and on screen lock
  (`com.apple.screenIsLocked` distributed notification); restart it, with an immediate tick, on the
  matching wake / unlock / `sessionDidBecomeActive` notifications. Nothing is visible meanwhile.
- **No icon lookups in compact mode.** The engine skips `MenuExtraReader` (the AX call into each
  app for its menu bar icon) and `IconPresence` while compact is on; only Dock labels are read.

## Constraints

- Swift 6, macOS target as today, no new dependencies; XcodeGen project.
- Settings stay backward compatible (lenient decode, new fields default as above).
- Existing behaviour is unchanged when compact is off.

## Left to the builder

- Exact spacing / label font of "+N" within the stated limits.
- Whether the compact image is cached per (entries, scale).
- How the detached update process is spawned (`posix_spawn` with `POSIX_SPAWN_SETSID`, or
  `Process` running `/usr/bin/nohup`), as long as it survives MenuBadge quitting.

## Testing

- Unit: `CompactLayout`, `AppVersion`, settings decoding of the two new fields (missing → defaults).
- Manual: compact on/off with Slack + Telegram + a helper app with a Dock badge (as in the probe);
  4+ badges for "+N"; menu rows open the app; paused shows the glyph.
- Update: `MENUBADGE_RELEASE_API_URL` pointing at a test JSON that names version 9.9.9 and a local
  DMG (`file://`), to see the row and the button, and that the reinstall keeps Accessibility.
