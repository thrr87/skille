#!/usr/bin/env bash
# Build a proper Skille.app and install it to ~/Applications (Dock-friendly).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "${1-}" != "" ]]; then
  DEST="$1"
else
  DEST="$HOME/Applications/Skille.app"
fi
BUILD_DIR="$ROOT/.build/release"
STAGE="$ROOT/.build/Skille.app"

cd "$ROOT"

echo "Building release..."
swift build -c release --product Skille

BIN="$BUILD_DIR/Skille"
if [[ ! -x "$BIN" ]]; then
  BIN="$(find "$ROOT/.build" -path '*/release/Skille' -type f -perm -111 | head -n 1)"
fi
if [[ -z "$BIN" || ! -x "$BIN" ]]; then
  echo "error: release binary not found" >&2
  exit 1
fi

echo "Assembling app bundle..."
rm -rf "$STAGE"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"
cp "$ROOT/packaging/Info.plist" "$STAGE/Contents/Info.plist"
cp "$BIN" "$STAGE/Contents/MacOS/Skille"
chmod +x "$STAGE/Contents/MacOS/Skille"

if command -v codesign >/dev/null; then
  codesign --force --deep --sign - "$STAGE" >/dev/null 2>&1 || true
fi

echo "Installing to $DEST ..."
mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
cp -R "$STAGE" "$DEST"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$DEST" >/dev/null 2>&1 || true
fi

echo "Installed: $DEST"
echo "Open with: open \"$DEST\""
