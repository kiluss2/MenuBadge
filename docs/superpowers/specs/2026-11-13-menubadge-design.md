# MenuBadge — design

Date: 2026-11-13. Status: approved by the user 2026-11-13.
Successor of `~/Resources/Tool/slack-menubar-badge` (single-file AppKit tool, Slack only).

## Why

The user keeps the Dock auto-hidden to get screen space, so Dock badges (unread counts) are never
seen. `slack-menubar-badge` solved this for Slack by drawing Slack's Dock badge on Slack's own menu
bar icon. The user liked it enough to want one tool for every app that puts a badge on its Dock
icon (Telegram, Mail, Zalo, …): turn an app on in Settings and it gets a badge on the menu bar,
with its own look.

Success: any badge-capable app can be switched on from a Settings window without touching code,
each app's badge can be tuned (corner, size, colours, animation), and the tool stays as light and
quiet as today's (≈13 MB, near-zero CPU, nothing animating between blinks).

## Goals

- One menu bar app, **MenuBadge**, that mirrors the Dock badge of every app the user enables.
- Per-app appearance, with a shared default that apps inherit until changed.
- Works for apps with and without their own menu bar icon (see Behaviour).
- A proper Xcode project (the user chose it: "invest, do it properly").

## Non-goals

- Real unread counts beyond what the app puts on its Dock tile. Slack only exposes a number for
  mentions/DMs and "•" for plain unreads; MenuBadge shows exactly what the Dock shows. No Slack
  API, no tokens, no patching other apps.
- Detecting that an app draws its own number in its menu bar icon (not readable: Telegram's number
  is inside its icon image, its AX title is empty). The user turns the app's own icon off instead.
- Notification Centre banners, sounds, or anything other than the badge.
- Distribution to other people (no notarisation, no App Store).

## Anti-goals (would make it a failure even if it works)

- Visible CPU/energy cost: continuous animations, fast polling, Screen Recording permission.
- Breaking clicks on other apps' menu bar icons (the overlay must stay click-through).
- Losing Accessibility permission on every rebuild.
- A cluttered menu bar the user cannot tame (every extra icon must be switchable off).

## What exists today (facts the new tool builds on)

From `slack-menubar-badge/main.swift`, tested on this Mac (macOS 27.2, two side-by-side displays):

- **Badge text:** Dock process → children with role `AXList` → tile whose `AXURL` ends with
  `/<App>.app` (or title matches) → attribute `AXStatusLabel` (string: "3", "•", nil when none).
  Works while the Dock is auto-hidden. `lsappinfo` no longer returns badge labels on this macOS.
- **App's menu bar icon:** app's AX element → `AXExtrasMenuBar` → first child → `AXPosition` /
  `AXSize` (AX coordinates: top-left origin, y down). Slack: 34×24, Telegram: 42×24.
- **Overlay:** borderless non-activating `NSPanel`, level `statusBar + 1`, `ignoresMouseEvents`,
  `canJoinAllSpaces | stationary | ignoresCycle`, clear background; one `CALayer` holding the
  badge image (rendered at backing scale × 1.25 so scale animations stay sharp).
- **Polling:** 1 s timer (tolerance 0.3 s); AX messaging timeout 0.5 s; cached AX elements
  re-resolved on `invalidUIElement`, app launch/quit and screen changes.
- **Animations:** timer-driven, nothing runs between them. Blink: `transform.scale.y` 1 → 0.1,
  close 0.07–0.09 s, hold 0.03 s, open 0.13–0.17 s; next blink after random 2.5–4 s; 1 in 4 is a
  double blink. New badge / count grew: sideways shake, `translation.x` ±3.5 pt decaying, 0.6 s.
- **Geometry today:** badge 12 pt circle (pill for 2+ digits, font 9 pt bold), centred on the
  glyph's bottom-right corner = (icon.midX + 8, icon.midY + 6) assuming a ~16 pt glyph centred
  in the item.
- **Signing:** self-signed identity `kiluss2 Local Code Signing` (login keychain, valid until 9999,
  untrusted is fine for `codesign`); TCC keys on the certificate leaf, so Accessibility survives
  rebuilds. Recreate steps are in the hub README.
- **Measured cost:** ≈13 MB physical footprint, ~0 % CPU idle; WindowServer cost of animations
  was within measurement noise.
- Dev/test hooks: `SMB_TEST_BADGE=<text>` forces a badge, `SMB_DEMO=1` walks through all states
  with captions in the menu bar, then quits.

## Behaviour

### Which apps

- Settings lists apps the user has added plus, as suggestions, currently running regular apps
  (they have a Dock tile). Adding is also possible from a file picker on `/Applications`.
  *(My call.)*
- Each app row shows its live status: running or not, "has its own menu bar icon" or not, and
  "badge seen" / "no badge seen yet". Nothing is hidden or blocked: an app that never badges simply
  never shows anything. *(User asked whether unusable apps could be hidden; the agreed answer is
  to show status instead, since badge support is only known once a badge appears.)*
- Slack is enabled by default on first launch, with today's look, so the switch from
  slack-menubar-badge changes nothing visible.

### Where each app's badge goes (automatic, per app, re-checked live)

- **App has a menu bar icon** (AX finds it, frame on a screen): overlay on that icon, as today.
- **App has none** (or its icon is hidden/off-screen): MenuBadge adds its own status item for the
  app: the app's icon (template-free, ~16 pt) with the badge composited on it; click activates the
  app. Per-app setting: **always shown** (default) or **only while it has a badge**.
- Switching happens automatically, e.g. the user turns Telegram's "Show Icon in Menu Bar" off and
  MenuBadge moves the badge to its own Telegram item within a second.
- App not running → nothing for it. "Always shown" applies only to an app **last seen without its
  own menu bar icon**: its MenuBadge item stays, showing the app icon without a badge. An app last
  seen with its own icon (Slack) shows nothing while it is not running, so quitting Slack never
  makes a MenuBadge Slack icon appear. An app never seen running since it was added shows nothing.
  *(My call, from the builder check.)*
- Per-app **Placement** override: Auto (default, the rules above), On the app's icon, MenuBadge's
  own item. For apps whose icon comes from a helper process or that have several menu bar icons,
  where "first child of the app's `AXExtrasMenuBar`" picks the wrong one or none. The builder
  checks Telegram, Mail and Zalo with AX on this Mac while planning. *(My call, from the builder
  check.)*

### Badge meaning

- Numeric label (or "99+"-like text) → count style. "•" / "●" → dot style. Any other short text →
  count style showing up to 4 characters. *(My call.)*
- Only Slack uses the dot; other apps' labels are counts.

### Per-app appearance (each app inherits the shared default until changed)

| Setting | Options | Default (= today) |
|---|---|---|
| Corner | top-left, top-right, bottom-left, bottom-right | bottom-right |
| Size | 8–16 pt | 12 pt |
| Count colour | colour picker | red `#ED3133` |
| Dot colour | colour picker | blue `#1C99FF` |
| Text colour | colour picker | white |
| Idle animation (while a badge is shown) | Blink (eye), Breathe, Bounce, Ripple, None | Blink |
| New-badge effect (badge appears or count grows) | Shake, Bounce, None | Shake |

Preset intent (exact timings left to the builder, all timer-driven with random 2.5–4 s pauses like
Blink, never continuous):
- **Breathe:** short fade + swell and back (the 0.3 s version tried earlier showed the logo through
  the faded badge; keep the fade shallow).
- **Bounce:** small hop up and settle.
- **Ripple:** a ring expands from the badge and fades; the badge itself stays still and readable.

Settings shows a live preview of the app's badge with the chosen options, and a "Preview all
states" button that runs the demo (states: none → dot → 1 → 3 → 12 → dot → none). *(My call.)*

### MenuBadge's own menu bar icon

- Setting "Show MenuBadge in menu bar", default **on**. Its menu: Settings…, Pause all badges,
  Quit.
- Launching MenuBadge again (Spotlight, Launchpad, Finder) while it runs opens Settings, so the
  icon can be off without losing access. *(User agreed.)*

### Permissions and startup

- First run: Settings opens on an Accessibility step with live status and a button to the right
  System Settings pane; badges start as soon as permission is granted, no relaunch.
- "Open at login" toggle, default on, via `SMAppService.mainApp` (replaces the LaunchAgent).
  *(My call.)*

### Known limitations (accepted)

- With two displays, AX reports the icon frame on one menu bar; the overlay follows that one (as
  today).
- Full-screen spaces: overlay not shown (no `fullScreenAuxiliary`), as today.

## Constraints

- Xcode project, macOS deployment target 15.0 (same as DeviceBar), Swift 6, Xcode 27.2 on this
  Mac. `xcodegen` is installed if the builder wants a generated, diff-friendly project.
- Settings UI in SwiftUI; overlay and status items in AppKit. Load the `swiftui-pro` skill before
  writing SwiftUI and follow it.
- Signed with `kiluss2 Local Code Signing`, no Apple team; Hardened Runtime off or compatible with
  AX; no sandbox (AX on other apps needs it off).
- Bundle id `com.kiluss.menubadge`; installs to `~/Applications/MenuBadge.app`.
- Cost budget: idle footprint in the tens of MB, no continuous animation, polling ≤ 1 Hz.
- Repo: lives in the hub `kiluss2/mac-tools` as `MenuBadge/`; commits as
  `kiluss2 <69423922+kiluss2@users.noreply.github.com>`, no Claude attribution; commit/push only
  when the user says so.
- Persist settings in `UserDefaults` (per-app overrides keyed by bundle id).

## Approaches considered

| | Approach | Trade-off |
|---|---|---|
| A | Swift Package + `install.sh` that assembles the `.app` (like DeviceBar) | One-command build, no Xcode needed; no asset catalog, hand-made `.icns` |
| **B (picked)** | **Full Xcode project** | Asset catalog, previews, debugger, standard app target and tests; heavier, needs Xcode to build |
| C | Keep growing the single `main.swift` | Least change; becomes a 1000-line file, hard to maintain |

The user picked **B** to do it properly from the start.

## Decided by the user

- One tool for many apps, each switched on in Settings.
- Per-app corner, size, colours, animation; default = today's look; extra animation presets.
- Own status item for apps without a menu bar icon; per-app "always" / "only with badge", default
  always.
- MenuBadge's own menu bar icon, switchable; Settings also opens by relaunching the app.
- Apps that draw their own number: the user turns the app's own icon off; no detection.
- Full Xcode project.

## My calls (for the user to check)

- Name **MenuBadge**, bundle id `com.kiluss.menubadge` (Accessibility granted once more).
- Location `~/Resources/Tool/MenuBadge` inside the hub, replacing `slack-menubar-badge/`.
- App list = added apps + running apps as suggestions; Slack enabled by default.
- Not-running app: its own item stays (icon without badge) only if it was last seen without its own
  menu bar icon and is set to "always"; otherwise nothing.
- Per-app Placement override (Auto / On the app's icon / Own item), default Auto.
- "Open at login" via `SMAppService`, default on; LaunchAgent and old app removed on migration.
- Live preview + "Preview all states" in Settings; "Pause all badges" in the menu.
- Non-numeric, non-dot labels shown as text, up to 4 characters.

## Migration

- Port the working pieces of `slack-menubar-badge/main.swift` (AX readers, overlay, blink, shake,
  image rendering) rather than rewriting them.
- On install: stop and remove the `com.kiluss2.slack-menubar-badge` LaunchAgent and
  `~/Applications/SlackMenubarBadge.app` (to the Trash), remove its TCC entry
  (`tccutil reset Accessibility com.kiluss2.slack-menubar-badge`); remove `slack-menubar-badge/`
  from the hub and update the hub README row.

## Left to the builder

- Project generation (xcodegen `project.yml` or Xcode template), file/module layout.
- Settings window layout and navigation.
- Exact parameters of the new presets (Breathe, Bounce, Ripple, Bounce-on-new).
- Glyph-size assumption per corner (today assumes a ~16 pt glyph centred in the item); a per-app
  fine offset if needed.
- Test strategy: unit tests (Swift Testing) for label parsing, corner/size geometry, settings
  inheritance and persistence; a demo mode equivalent to `SMB_DEMO` for visual checks.
