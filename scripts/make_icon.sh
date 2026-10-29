#!/bin/zsh
# 从 scripts/make_icon.swift 生成 assets/icon.png 和 assets/AppIcon.icns
set -euo pipefail
cd "$(dirname "$0")/.."

swift scripts/make_icon.swift assets/icon.png

SET=$(mktemp -d)/AppIcon.iconset
mkdir -p "$SET"
for s in 16 32 128 256 512; do
  sips -z $s $s assets/icon.png --out "$SET/icon_${s}x${s}.png" >/dev/null
  sips -z $((s * 2)) $((s * 2)) assets/icon.png --out "$SET/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$SET" -o assets/AppIcon.icns
rm -rf "$(dirname "$SET")"
echo "✓ assets/AppIcon.icns"
