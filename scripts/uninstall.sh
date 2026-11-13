#!/bin/bash
# Remove MenuBadge: login item, app (to the Trash) and its Accessibility entry.
# Settings stay in UserDefaults; clear them with: defaults delete com.kiluss.menubadge
set -euo pipefail

APP="$HOME/Applications/MenuBadge.app"
pkill -x MenuBadge 2>/dev/null || true
for _ in $(seq 50); do pgrep -x MenuBadge >/dev/null || break; sleep 0.1; done
if [ -x "$APP/Contents/MacOS/MenuBadge" ]; then
  "$APP/Contents/MacOS/MenuBadge" --unregister-login-item || true
fi
if [ -e "$APP" ]; then trash "$APP"; fi
tccutil reset Accessibility com.kiluss.menubadge >/dev/null 2>&1 || true
echo "removed MenuBadge"
