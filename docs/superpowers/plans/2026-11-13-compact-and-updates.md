# Compact Mode, Update Check and Lighter Polling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One menu bar item that carries every badge, a daily GitHub release check with one-click update, and no polling while the screen sleeps or is locked.

**Architecture:** Pure decisions (settings fields, version compare, release JSON, compact layout, poll gate) go in BadgeKit with Swift Testing tests; AppKit pieces (compact image, menu, engine wiring, updater process, Settings rows) go in the app target and are checked by hand on the installed build.

**Tech Stack:** Swift 6, AppKit + SwiftUI, Accessibility, XcodeGen, Swift Testing, URLSession.

**Spec:** `docs/superpowers/specs/2026-11-13-compact-and-updates-design.md`

## Global Constraints

- No new dependencies; macOS 15 target; Swift 6 strict concurrency (`@MainActor` app types).
- Settings stay backward compatible: new fields decode leniently, `compact` default `false`, `checkForUpdates` default `true`.
- Nothing changes when compact is off (placement, overlays, own items as today).
- Update check: `https://api.github.com/repos/kiluss2/MenuBadge/releases/latest`, header `Accept: application/vnd.github+json`, User-Agent `MenuBadge/<version>`, no auth, first check 10 s after launch, then every 24 h; env `MENUBADGE_RELEASE_API_URL` overrides the URL.
- Update install runs the **bundled** `install-release.sh` with `MENUBADGE_DMG_URL` = the release's `MenuBadge.dmg` asset; never a script from the network.
- Compact item: at most 3 apps drawn, the rest as "+N" (11 pt, secondary colour), icons at each app's `iconSize`, 4 pt apart; no idle animation; the app's `onNew` effect on the whole button when its badge grows.
- Copy: toggle "Gather badges in one item"; disabled note "Always shown in compact mode"; "Check for updates automatically"; "Check for Updates…"; "MenuBadge X is available" + "Update"; "MenuBadge is up to date"; "Could not check for updates"; menu "Update to X…".
- Build/test: `xcodegen generate && xcodebuild test -project MenuBadge.xcodeproj -scheme BadgeKit -destination platform=macOS -derivedDataPath ~/Library/Caches/MenuBadge/DerivedData`; install with `scripts/install.sh`.
- Commits as `kiluss2 <69423922+kiluss2@users.noreply.github.com>`, no Claude attribution.

## Review Focus

- Compact on while an app's overlay or own item is showing → those disappear at once, the badge shows in the compact item (Task 5 manual check).
- Compact toggled off again → per-app placement comes back on the next tick, compact glyph returns to plain glyph or is removed per "Show MenuBadge in menu bar" (Task 5).
- GitHub JSON without a `MenuBadge.dmg` asset, or a `tag_name` like `nightly` → no update offered (Task 2 test).
- Offline / HTTP 403 rate limit on the automatic check → silent, retried next day; on the manual check → "Could not check for updates" (Task 6).
- Screen locked while a badge changes → after unlock the tick runs at once and shows the current badge (Task 4 test on `PollGate`, Task 5 wiring).

---

### Task 1: Settings fields

**Files:**
- Modify: `BadgeKit/MenuBadgeSettings.swift`
- Test: `BadgeKitTests/SettingsTests.swift`

**Interfaces:**
- Produces: `MenuBadgeSettings.compact: Bool` (default false), `MenuBadgeSettings.checkForUpdates: Bool` (default true).

- [ ] **Step 1: Failing tests** `newFieldsDefaultWhenMissing` (decode `{"apps":[]}` → `compact == false`, `checkForUpdates == true`) and `newFieldsRoundTrip` (set both to the non-default, encode, decode, `#expect` equal; a wrong type `"compact":"yes"` decodes to false).
- [ ] **Step 2: Run** the test command; expect compile failure (no members).
- [ ] **Step 3: Add** the two stored properties and their `c.lenient(Bool.self, …) ?? default` lines in `init(from:)`.
- [ ] **Step 4: Run**; all tests pass.
- [ ] **Step 5: Commit** `Settings: compact and checkForUpdates fields`.

### Task 2: Version compare and release JSON

**Files:**
- Create: `BadgeKit/AppVersion.swift`, `BadgeKit/ReleaseInfo.swift`
- Test: `BadgeKitTests/UpdateTests.swift`

**Interfaces:**
- Produces:
  - `public struct AppVersion: Comparable, Sendable { public init?(_ text: String) }` — strips a leading `v`/`V`, splits on `.`, every part must be an integer, missing parts compare as 0; nil for empty or non-numeric.
  - `public struct AvailableUpdate: Equatable, Sendable { public let version: String; public let dmgURL: URL; public let pageURL: URL }` (`version` without the `v`).
  - `public enum ReleaseInfo { public static func newerRelease(json: Data, current: String) throws -> AvailableUpdate? }` — throws on undecodable JSON; nil when not newer, tag not a version, or no asset named exactly `MenuBadge.dmg`. Reads `tag_name`, `html_url`, `assets[].name`, `assets[].browser_download_url`.

- [ ] **Step 1: Failing tests:**
  - `versionsCompareNumerically`: `AppVersion("1.10.0")! > AppVersion("1.9.0")!`, `AppVersion("v1.1")! == AppVersion("1.1.0")!`, `AppVersion("nightly") == nil`, `AppVersion("") == nil`.
  - `newerReleaseFound`: JSON with `tag_name "v1.1.0"`, `html_url`, assets `[{name:"MenuBadge.dmg", browser_download_url:"https://x/MenuBadge.dmg"}]`, current `"1.0.0"` → `AvailableUpdate(version: "1.1.0", dmgURL: https://x/MenuBadge.dmg, pageURL: html_url)`.
  - `sameOrOlderIsNil`: current `"1.1.0"` and `"1.2"` → nil.
  - `missingAssetOrBadTagIsNil`: asset named `Other.zip` → nil; `tag_name "nightly"` → nil.
  - `garbageThrows`: `Data("not json".utf8)` throws.
- [ ] **Step 2: Run**; compile failure.
- [ ] **Step 3: Implement** both files (private `Decodable` structs for the JSON).
- [ ] **Step 4: Run**; pass.
- [ ] **Step 5: Commit** `BadgeKit: version compare and GitHub release parsing`.

### Task 3: Compact layout and status

**Files:**
- Create: `BadgeKit/CompactLayout.swift`
- Modify: `BadgeKit/AppRuntime.swift` (add `case compactItem` to `Location`), `BadgeKit/AppStatusText.swift`
- Test: `BadgeKitTests/CompactTests.swift`, `BadgeKitTests/StatusTests.swift`

**Interfaces:**
- Produces:
  - `public struct CompactBadge: Equatable, Sendable { public let bundleID: String; public let label: BadgeLabel }`
  - `public struct CompactLayout: Equatable, Sendable { public static let maxShown = 3; public let shown: [CompactBadge]; public let overflow: Int; public init(_ badges: [CompactBadge]) }` — keeps input order (caller passes sidebar order, only apps with a badge).
  - `AppRuntime.Location.compactItem`; `AppStatusText.describe` → `"Running · MenuBadge item"` for it (same words as own item, no "no icon of its own" suffix); `placementNote` → nil when location is `.compactItem`.

- [ ] **Step 1: Failing tests** `compactKeepsOrderAndCaps` (5 badges → `shown` = first 3, `overflow` 2), `compactSmall` (2 → overflow 0; 0 → empty, 0), `statusInCompact` (describe with `.compactItem` running → `"Running · MenuBadge item"`; placementNote nil even with `hasOwnIcon == false`).
- [ ] **Step 2: Run**; compile failure.
- [ ] **Step 3: Implement**; fix any `switch` over `Location` in the app (engine mapping stays as is for now).
- [ ] **Step 4: Run**; pass.
- [ ] **Step 5: Commit** `BadgeKit: compact layout and status`.

### Task 4: Poll gate

**Files:**
- Create: `BadgeKit/PollGate.swift`
- Test: `BadgeKitTests/PollGateTests.swift`

**Interfaces:**
- Produces: `public struct PollGate: Equatable, Sendable { public enum Reason: Hashable, Sendable { case screensAsleep, screenLocked, sessionInactive }; public init(); public var shouldPoll: Bool; public mutating func set(_ reason: Reason, _ active: Bool) -> Bool }` — `set` returns true when `shouldPoll` went from false to true (caller ticks at once).

- [ ] **Step 1: Failing test** `gateResumesOnlyWhenAllClear`: lock → `shouldPoll` false; sleep → false; unlock returns false and still false; wake returns true and `shouldPoll` true; setting an already-clear reason clear returns false.
- [ ] **Step 2: Run**; compile failure.
- [ ] **Step 3: Implement** with a `Set<Reason>`.
- [ ] **Step 4: Run**; pass.
- [ ] **Step 5: Commit** `BadgeKit: poll gate`.

### Task 5: Compact item, engine wiring, sleeping poll

**Files:**
- Create: `MenuBadge/Badge/CompactRenderer.swift`
- Modify: `MenuBadge/MenuBarItem.swift`, `MenuBadge/Engine/BadgeEngine.swift`, `MenuBadge/AppDelegate.swift`, `MenuBadge/UI/GeneralPane.swift`

**Interfaces:**
- Consumes: `CompactLayout`, `CompactBadge`, `PollGate`, `MenuBadgeSettings.compact`, `AppIconCache.menuBarIcon(for:side:)`, `BadgeRenderer.image(_:_:)`, `BadgeGeometry.badgeRectAX(iconAX:corner:badgeSize:glyphSize:)`, `BadgeAnimations.playNew(_:on:)`.
- Produces:
  - `@MainActor enum CompactRenderer { static func image(_ layout: CompactLayout, appearances: [String: BadgeAppearance]) -> NSImage }` — height 22 pt; each app: its trimmed icon at `iconSize` plus its badge placed like the own item (same geometry call), 4 pt between apps, "+N" after the third.
  - `MenuBarItem.showCompact(_ layout: CompactLayout?, appearances: [String: BadgeAppearance], grewBundleID: String?)` — nil layout = plain glyph; plays `appearances[grewBundleID].onNew` on the button layer.
  - `MenuBarItem.sync()` keeps the item while `store.settings.compact` is true.
  - Menu rows built in `menuWillOpen` from a `badgeRows: () -> [(bundleID: String, name: String, text: String)]` closure passed at init; choosing a row opens the app.
- Engine changes: when `compact` is on, per enabled app read only the Dock label (skip `extras.iconFrame` and `IconPresence`), set runtime location `.compactItem` (or `.hidden` without a badge / not running), hide all overlays and own items, and call `menuBarItem.showCompact` once per tick only when the layout or appearances changed (keep the last value). Paused, untrusted or compact off → `showCompact(nil, …)` (plain glyph). The engine gets a `weak var menuBarItem: MenuBarItem?` set by `AppDelegate`.
- Sleeping poll: engine owns a `PollGate`; observers for `NSWorkspace.screensDidSleepNotification`/`screensDidWakeNotification`, `sessionDidResignActiveNotification`/`sessionDidBecomeActiveNotification`, and `DistributedNotificationCenter` `com.apple.screenIsLocked`/`com.apple.screenIsUnlocked`; `tick()` returns early when `!gate.shouldPoll`; `set(...) == true` → `resetReaders(); tick()`.
- GeneralPane: toggle "Gather badges in one item" bound to `compact`; "Show MenuBadge in menu bar" `.disabled(store.settings.compact)` with footnote "Always shown in compact mode"; footer explains ⌘-drag. `observeSettings` in AppDelegate also tracks `compact`.

- [ ] **Step 1: Implement** the above; `xcodegen generate`; build with `scripts/install.sh`.
- [ ] **Step 2: Run** BadgeKit tests; all pass.
- [ ] **Step 3: Manual check (installed app, settings exported first with `defaults export com.kiluss.menubadge <scratch>/prefs.plist`):** compact on → Slack/Telegram badges in one item, their own items/overlays gone; a helper process with `NSApp.dockTile.badgeLabel` = "1" (added as an app in Settings is not possible for an unbundled helper, so use 4+ real apps or a temporary `.app` bundle in the scratchpad) for "+N"; menu rows open the app; Pause → glyph only; compact off → old placement back. Capture only MenuBadge's own windows/items by window id. Restore prefs with `defaults import`.
- [ ] **Step 4: Commit** `Compact mode: one menu bar item for every badge; no polling while the screen sleeps`.

### Task 6: Update check and install

**Files:**
- Create: `MenuBadge/Update/UpdateChecker.swift`
- Modify: `project.yml` (copy `scripts/install-release.sh` into the app's Resources), `MenuBadge/AppDelegate.swift`, `MenuBadge/MenuBarItem.swift`, `MenuBadge/UI/GeneralPane.swift`, `MenuBadge/UI/SettingsWindowController.swift` (pass the checker)

**Interfaces:**
- Consumes: `ReleaseInfo.newerRelease(json:current:)`, `AvailableUpdate`, `MenuBadgeSettings.checkForUpdates`.
- Produces: `@MainActor @Observable final class UpdateChecker { enum Status { case idle, checking, upToDate, failed }; private(set) var available: AvailableUpdate?; private(set) var status: Status; func start(); func checkNow(manual: Bool) async; func install() }`.
  - `start()`: first check after 10 s, then a 24 h repeating timer; each automatic check is skipped when `checkForUpdates` is false.
  - Automatic failures leave `status` `.idle`; manual ones set `.failed`; manual with no update sets `.upToDate`.
  - `install()`: runs `/bin/bash <Bundle.main path to install-release.sh>` in a new session (`posix_spawn` with `POSIX_SPAWN_SETSID`, stdout/stderr to `/dev/null`) with env `MENUBADGE_DMG_URL=<dmgURL>`; the script quits and reopens MenuBadge.
- MenuBarItem: when `available != nil`, an "Update to X…" item above Quit (calls `install()`), and "Check for Updates…" (manual check, then opens Settings › General to show the result).
- GeneralPane: section "Updates": toggle "Check for updates automatically"; when available, "MenuBadge X is available" + "Update" button + release-notes `Link(pageURL)`; else "Check for Updates…" button with the status text.

- [ ] **Step 1: Implement**; `xcodegen generate`; `scripts/install.sh`.
- [ ] **Step 2: Manual check:** write `<scratch>/release.json` naming `v9.9.9` and asset `MenuBadge.dmg` → `file://<scratch>/MenuBadge.dmg` (built with `scripts/make-release.sh`, copied to the scratchpad); launch the installed app with `MENUBADGE_RELEASE_API_URL=file://<scratch>/release.json` (`open --env`); see the General row and menu item; press Update → app quits, reinstalls, reopens, Accessibility still Granted. Then an invalid JSON file + manual check → "Could not check for updates".
- [ ] **Step 3: Commit** `Update check: daily GitHub release check with one-click install`.

### Task 7: Version, docs, release

**Files:**
- Modify: `project.yml` (`MARKETING_VERSION: "1.1.0"`, `CURRENT_PROJECT_VERSION: "2"`), `README.md`

- [ ] **Step 1: README:** bullets for compact mode and the daily update check (one anonymous request to GitHub a day, toggle in General); mention "no polling while the screen sleeps"; refresh the Settings screenshot only if General changed visibly (window-id capture of MenuBadge only).
- [ ] **Step 2: Run** the test command and `scripts/install.sh`; all pass, app runs.
- [ ] **Step 3: Commit** `MenuBadge 1.1.0`; push `main` (the user asked for pushes on this repo when work is done).
- [ ] **Step 4: Ask the user** before `scripts/make-release.sh` + `gh release create v1.1.0` (public release).
