#!/bin/bash
# Install or update MenuBadge from the latest GitHub release, in one line:
#   curl -fsSL https://raw.githubusercontent.com/kiluss2/MenuBadge/main/scripts/install-release.sh | bash
# Downloads MenuBadge.dmg, copies MenuBadge.app to ~/Applications (or replaces the copy already in
# /Applications) and opens it. A file downloaded by curl carries no quarantine flag, so macOS opens
# the app without the "cannot verify the developer" prompt. Accessibility is still granted once.
# MENUBADGE_DMG_URL overrides the download (for testing a local build: file:///path/MenuBadge.dmg).
set -euo pipefail

URL="${MENUBADGE_DMG_URL:-https://github.com/kiluss2/MenuBadge/releases/latest/download/MenuBadge.dmg}"
if [ -d /Applications/MenuBadge.app ]; then APP=/Applications/MenuBadge.app; else APP="$HOME/Applications/MenuBadge.app"; fi

WORK="$(mktemp -d)"
cleanup() {
  hdiutil detach -quiet "$WORK/mnt" 2>/dev/null || true
  rm -rf "$WORK"
}
trap cleanup EXIT

echo "Downloading MenuBadge…"
curl -fL --progress-bar "$URL" -o "$WORK/MenuBadge.dmg"
mkdir "$WORK/mnt"
hdiutil attach -quiet -nobrowse -readonly -mountpoint "$WORK/mnt" "$WORK/MenuBadge.dmg"
[ -d "$WORK/mnt/MenuBadge.app" ] || { echo "MenuBadge.app is missing from the download" >&2; exit 1; }

# Quit a running copy before replacing it.
osascript -e 'quit app "MenuBadge"' >/dev/null 2>&1 || true
for _ in $(seq 50); do pgrep -x MenuBadge >/dev/null || break; sleep 0.1; done
pkill -x MenuBadge 2>/dev/null || true

mkdir -p "$(dirname "$APP")"
rm -rf "$APP"
ditto "$WORK/mnt/MenuBadge.app" "$APP"
open "$APP"
VERSION="$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "?")"
echo "MenuBadge $VERSION installed at $APP."
echo "First time: turn MenuBadge on in System Settings › Privacy & Security › Accessibility."
