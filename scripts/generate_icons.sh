#!/bin/bash
# Usage: ./scripts/generate_icons.sh path/to/icon_1024x1024.png
# Requires: sips (built-in macOS) or ImageMagick (brew install imagemagick)
set -euo pipefail

SOURCE="${1:-icon_source.png}"
DEST="Voicy/Resources/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$SOURCE" ]; then
  echo "Usage: $0 <source_1024x1024.png>"
  exit 1
fi

resize() {
  local size=$1 out=$2
  if command -v sips &>/dev/null; then
    sips -z "$size" "$size" "$SOURCE" --out "$DEST/$out" >/dev/null
  else
    convert "$SOURCE" -resize "${size}x${size}" "$DEST/$out"
  fi
  echo "  $out (${size}x${size})"
}

echo "Generating icons from $SOURCE..."
resize 16   icon_16x16.png
resize 32   icon_32x32.png
resize 64   icon_64x64.png
resize 128  icon_128x128.png
resize 256  icon_256x256.png
resize 512  icon_512x512.png
resize 1024 icon_1024x1024.png
echo "Done. Commit the files in $DEST/"
