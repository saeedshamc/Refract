#!/usr/bin/env bash
# Package Prism Echo for Linux (standalone binary)
# Requires: love installed (sudo apt install love  OR  love from love2d.org)
# Output:  dist/PrismEcho

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
LOVE_BIN="${LOVE_BIN:-$(command -v love)}"

if [[ -z "$LOVE_BIN" || ! -x "$LOVE_BIN" ]]; then
  echo "Error: 'love' not found. Install LÖVE or set LOVE_BIN=/path/to/love"
  exit 1
fi

mkdir -p "$DIST"
LOVE_FILE="$DIST/PrismEcho.love"
OUT_BIN="$DIST/PrismEcho"

cd "$ROOT"
zip -9 -r "$LOVE_FILE" \
  main.lua grid.lua entities.lua raytracer.lua \
  level.lua ui.lua lever.lua levelgen.lua storage.lua \
  levels/ assets/ \
  -x "*.git*" -x "dist/*" -x "build/*" -x "*.md" -x "run.bat"

# Fuse love binary + .love into one executable
cat "$LOVE_BIN" "$LOVE_FILE" > "$OUT_BIN"
chmod a+x "$OUT_BIN"

echo ""
echo "Done! Standalone Linux build:"
echo "  $OUT_BIN"
echo ""
echo "Run with: ./dist/PrismEcho"
