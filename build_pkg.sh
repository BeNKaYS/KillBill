#!/bin/bash
set -e

cd "$(dirname "$0")"
APP_NAME="KillBill"
VERSION="1.0.0"
IDENTIFIER="com.benkays.killbill"

echo "🚀 KillBill derleniyor (Release)..."
swift build -c release

echo "📦 Uygulama paketi (.app) oluşturuluyor..."
rm -rf "$APP_NAME.app"
mkdir -p "$APP_NAME.app/Contents/MacOS" "$APP_NAME.app/Contents/Resources"
cp ".build/release/$APP_NAME" "$APP_NAME.app/Contents/MacOS/$APP_NAME"
[ -d "Sources/KillBill/Resources" ] && cp -R Sources/KillBill/Resources/* "$APP_NAME.app/Contents/Resources/" 2>/dev/null || true

cat << 'EOF' > "$APP_NAME.app/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>KillBill</string>
    <key>CFBundleIdentifier</key><string>com.benkays.killbill</string>
    <key>CFBundleName</key><string>KillBill</string>
    <key>CFBundleDisplayName</key><string>KillBill</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Telif Hakkı © 2026 BeNKaYS. Tüm hakları saklıdır.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>KillBill, diğer uygulamaların pencerelerini kapatmak ve çöp kutusunu boşaltmak için Apple Events erişimi gerektirir.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>KillBill masaüstü öğelerini yönetmek için masaüstü erişimi gerektirir.</string>
</dict>
</plist>
EOF

chmod +x "$APP_NAME.app/Contents/MacOS/$APP_NAME"
xattr -cr "$APP_NAME.app" 2>/dev/null || true
find "$APP_NAME.app" -name "._*" -delete 2>/dev/null || true
codesign --force --deep --sign - "$APP_NAME.app" 2>/dev/null || true

echo "🎨 Kurucu için geliştirici kartı hazırlanıyor (avatar + QR gömülü)..."
mkdir -p installer
python3 - << 'PY'
import base64, pathlib, re
src = pathlib.Path("Sources/KillBill/Resources")
card = (src/"developer_card.html").read_text(encoding="utf-8")
qr   = (src/"qrcode.min.js").read_text(encoding="utf-8")
avatar_b64 = base64.b64encode((src/"avatar.png").read_bytes()).decode()

# qrcode.min.js'i satır içine al
card = card.replace('<script src="qrcode.min.js"></script>', '<script>\n' + qr + '\n</script>')
# yerel bulunamazsa CDN'e düşen bloğu kaldır (kurucuda internet olmayabilir)
card = re.sub(r'<script>\s*// Yerel qrcode\.min\.js.*?</script>', '', card, flags=re.S)
# avatarı base64 data URI yap
card = card.replace('src="avatar.png"', 'src="data:image/png;base64,' + avatar_b64 + '"')
# kurucu penceresi için hafif ölçek
card = card.replace('.dev-card {', '.dev-card { zoom: 0.92;')
pathlib.Path("installer/conclusion.html").write_text(card, encoding="utf-8")
print("   → installer/conclusion.html üretildi")
PY

echo "📦 macOS bileşen paketi oluşturuluyor..."
rm -f "$APP_NAME-component.pkg" "$APP_NAME.pkg"
pkgbuild --component "$APP_NAME.app" \
         --install-location "/Applications" \
         --identifier "$IDENTIFIER" \
         --version "$VERSION" \
         "$APP_NAME-component.pkg"

echo "🎁 Geliştirici kartlı yükleyici (.pkg) oluşturuluyor..."
productbuild --distribution installer/distribution.xml \
             --package-path . \
             --resources installer \
             "$APP_NAME.pkg"

echo ""
echo "🎉 TAMAMLANDI:"
echo "  1. Uygulama:  $APP_NAME.app"
echo "  2. Bileşen:   $APP_NAME-component.pkg"
echo "  3. Yükleyici: $APP_NAME.pkg  (kurulum sonu BeNKaYS geliştirici kartı gösterilir)"
echo ""
echo "👉 Kurucuyu açmak için: open $APP_NAME.pkg"
