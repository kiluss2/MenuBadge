#!/bin/bash
# Build MenuBadge (Release) and install it as ~/Applications/MenuBadge.app, replacing
# slack-menubar-badge on first install. Accessibility is granted once and survives reinstalls
# because the app is signed with the "kiluss2 Local Code Signing" identity (see README.md).
# Uninstall: scripts/uninstall.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="$HOME/Applications/MenuBadge.app"
IDENTITY="kiluss2 Local Code Signing"
OLD_LABEL="com.kiluss2.slack-menubar-badge"
cd "$DIR"

command -v xcodegen >/dev/null || { echo "xcodegen is missing: brew install xcodegen" >&2; exit 1; }
SIGN=()
# grep without -q reads all input, so `security` never dies of SIGPIPE under pipefail.
if ! security find-identity -p codesigning | grep "\"$IDENTITY\"" >/dev/null; then
  echo "note: '$IDENTITY' is not in the keychain; signing ad-hoc, so Accessibility must be" \
       "granted again after every install. README.md shows how to create the identity."
  SIGN=(CODE_SIGN_IDENTITY=-)
fi

xcodegen generate --quiet
xcodebuild -project MenuBadge.xcodeproj -scheme MenuBadge -configuration Release -quiet build ${SIGN[@]+"${SIGN[@]}"}
PRODUCTS="$(xcodebuild -project MenuBadge.xcodeproj -scheme MenuBadge -configuration Release -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR / && !found {print $2; found=1}')"
if [ ! -x "$PRODUCTS/MenuBadge.app/Contents/MacOS/MenuBadge" ]; then
  echo "build output not found in '$PRODUCTS'; the installed app was left as it was" >&2
  exit 1
fi

# Quit any running copy (installed or a dev build) and wait for it to go.
pkill -x MenuBadge 2>/dev/null || true
for _ in $(seq 50); do pgrep -x MenuBadge >/dev/null || break; sleep 0.1; done

mkdir -p "$HOME/Applications"
rm -rf "$APP"
ditto "$PRODUCTS/MenuBadge.app" "$APP"
REQ="$(codesign -d -r- "$APP" 2>&1 | tail -1)"
echo "$REQ"
if [ ${#SIGN[@]} -eq 0 ] && [[ "$REQ" != *"certificate leaf"* ]]; then
  echo "warning: the app is not signed with '$IDENTITY'; Accessibility will not survive rebuilds" >&2
fi

# One-time migration from slack-menubar-badge (old app and agent go to the Trash).
if launchctl print "gui/$(id -u)/$OLD_LABEL" >/dev/null 2>&1 \
   || [ -e "$HOME/Library/LaunchAgents/$OLD_LABEL.plist" ] || [ -e "$HOME/Applications/SlackMenubarBadge.app" ]; then
  launchctl bootout "gui/$(id -u)/$OLD_LABEL" 2>/dev/null || true
  for p in "$HOME/Library/LaunchAgents/$OLD_LABEL.plist" "$HOME/Applications/SlackMenubarBadge.app"; do
    if [ -e "$p" ]; then trash "$p"; fi
  done
  tccutil reset Accessibility "$OLD_LABEL" >/dev/null 2>&1 || true
  echo "migrated from slack-menubar-badge (old app and LaunchAgent moved to the Trash)"
fi

open "$APP"
echo "installed $APP"
