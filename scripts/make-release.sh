#!/bin/bash
# Build MenuBadge (Release) and package it as dist/MenuBadge.dmg for a GitHub release:
#   scripts/make-release.sh
#   gh release create v<version> dist/MenuBadge.dmg --title "MenuBadge <version>" --notes "..."
# The app is signed with the "kiluss2 Local Code Signing" identity (see README.md), so a Mac that
# granted Accessibility to one release keeps it for the next. It is not notarized.
set -euo pipefail

DIR="$(cd "$(dirname "$0")/.." && pwd)"
IDENTITY="kiluss2 Local Code Signing"
CACHE="$HOME/Library/Caches/MenuBadge"
DERIVED="$CACHE/DerivedData"
OUT="$DIR/dist/MenuBadge.dmg"
cd "$DIR"

command -v xcodegen >/dev/null || { echo "xcodegen is missing: brew install xcodegen" >&2; exit 1; }
# grep without -q reads all input, so `security` never dies of SIGPIPE under pipefail.
if ! security find-identity -p codesigning | grep "\"$IDENTITY\"" >/dev/null; then
  echo "'$IDENTITY' is not in the keychain; a release must be signed with it (see README.md)" >&2
  exit 1
fi

xcodegen generate --quiet
xcodebuild -project MenuBadge.xcodeproj -scheme MenuBadge -configuration Release -derivedDataPath "$DERIVED" \
  -quiet build
APP="$DERIVED/Build/Products/Release/MenuBadge.app"
codesign --verify --strict "$APP"
VERSION="$(defaults read "$APP/Contents/Info.plist" CFBundleShortVersionString)"

# Stage under ~/Library/Caches (Spotlight skips it, so no stray MenuBadge.app shows up in search).
mkdir -p "$CACHE" "$DIR/dist"
STAGE="$(mktemp -d "$CACHE/dmg.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/MenuBadge.app"
ln -s /Applications "$STAGE/Applications"
hdiutil create -quiet -ov -volname "MenuBadge $VERSION" -srcfolder "$STAGE" -format UDZO "$OUT"
hdiutil verify -quiet "$OUT"
echo "MenuBadge $VERSION → $OUT ($(du -h "$OUT" | cut -f1))"
