#!/bin/zsh
# 一键安装最新版 Strokey 到 /Applications
# curl -fsSL https://raw.githubusercontent.com/JiaCheng310/Strokey/main/scripts/install.sh | zsh
set -euo pipefail

REPO="JiaCheng310/Strokey"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

echo "→ 查询最新版本 / Fetching latest release…"
URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')
if [[ -z "$URL" ]]; then
  echo "✗ 没有找到发布包 / No release found: https://github.com/$REPO/releases" >&2
  exit 1
fi

echo "→ 下载 / Downloading $URL"
curl -fsSL "$URL" -o "$TMP/Strokey.zip"
ditto -x -k "$TMP/Strokey.zip" "$TMP"

pkill -x Strokey 2>/dev/null || true
rm -rf /Applications/Strokey.app
mv "$TMP/Strokey.app" /Applications/
# 应用没有经过 Apple 公证，去掉隔离标记，避免被 Gatekeeper 拦截
xattr -dr com.apple.quarantine /Applications/Strokey.app 2>/dev/null || true

open /Applications/Strokey.app
echo "✓ 已安装到 /Applications/Strokey.app"
echo "  首次运行请在「系统设置 → 隐私与安全性 → 辅助功能」中允许 Strokey"
echo "  First launch: allow Strokey in System Settings → Privacy & Security → Accessibility"
