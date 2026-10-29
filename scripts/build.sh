#!/bin/zsh
# 编译 Strokey.app（Apple Silicon + Intel 通用二进制）
# 用法：scripts/build.sh [版本号]
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-${VERSION:-1.0.0}}"
MIN_MACOS=13.0
APP=build/Strokey.app

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/obj

for arch in arm64 x86_64; do
  echo "→ 编译 $arch"
  swiftc -O -swift-version 5 \
    -target "$arch-apple-macos$MIN_MACOS" \
    Sources/Strokey/*.swift \
    -o "build/obj/Strokey-$arch"
done
lipo -create build/obj/Strokey-arm64 build/obj/Strokey-x86_64 -output "$APP/Contents/MacOS/Strokey"
rm -rf build/obj

cp assets/AppIcon.icns "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>io.github.jiacheng310.strokey</string>
  <key>CFBundleName</key><string>Strokey</string>
  <key>CFBundleDisplayName</key><string>Strokey</string>
  <key>CFBundleExecutable</key><string>Strokey</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>$MIN_MACOS</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>LSUIElement</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT License · github.com/JiaCheng310/Strokey</string>
</dict>
</plist>
EOF

# 没有 Apple 开发者证书时用 ad-hoc 签名（Apple Silicon 上运行必须有签名）
codesign --force --sign "${SIGN_IDENTITY:--}" "$APP"
echo "✓ $APP ($VERSION)"
