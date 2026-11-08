#!/bin/bash
set -euo pipefail

echo "🚀 KillBill derleniyor (Release)..."
cd "$(dirname "$0")"

APP_NAME="KillBill"
BUNDLE_DIR="$APP_NAME.app"
MACOS_DIR="$BUNDLE_DIR/Contents/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Contents/Resources"

# Sürüm: tek kaynak version.json
VERSION=$(/usr/bin/python3 -c 'import json;print(json.load(open("version.json"))["surum"])')
[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,3}$ ]] || { echo "❌ version.json içindeki surum geçersiz: $VERSION"; exit 1; }

swift build -c release

echo "📦 Uygulama paketi (.app) oluşturuluyor..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp ".build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
if [ -d "Sources/KillBill/Resources" ]; then
    cp -R Sources/KillBill/Resources/* "$RESOURCES_DIR/"
fi
cp "version.json" "$RESOURCES_DIR/version.json"
echo "🔖 Sürüm: $VERSION"

cat > "$BUNDLE_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>KillBill</string>
    <key>CFBundleIdentifier</key>
    <string>com.benkays.killbill</string>
    <key>CFBundleName</key>
    <string>KillBill</string>
    <key>CFBundleDisplayName</key>
    <string>KillBill</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>__VERSION__</string>
    <key>CFBundleVersion</key>
    <string>__VERSION__</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Telif Hakkı © 2026 BeNKaYS. Tüm hakları saklıdır.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>KillBill, Finder'ı kapatmak ve çöp kutusunu boşaltmak için Apple Events erişimi ister.</string>
</dict>
</plist>
EOF

/usr/bin/sed -i '' "s/__VERSION__/$VERSION/g" "$BUNDLE_DIR/Contents/Info.plist"
chmod +x "$MACOS_DIR/$APP_NAME"

# İmzalama: KILLBILL_SIGN_IDENTITY verilirse gerçek Developer ID ile imzalar.
# Ad-hoc imza yalnızca yerel geliştirme içindir; dağıtım paketi üretmez.
if [ -n "${KILLBILL_SIGN_IDENTITY:-}" ]; then
    echo "🔏 Developer ID ile imzalanıyor: $KILLBILL_SIGN_IDENTITY"
    codesign --force --deep --options runtime --timestamp \
             --sign "$KILLBILL_SIGN_IDENTITY" --identifier "com.benkays.killbill" "$BUNDLE_DIR"
    codesign --verify --deep --strict --verbose=2 "$BUNDLE_DIR"
else
    echo "⚠️  Ad-hoc imza (yalnızca yerel kullanım). Dağıtım için KILLBILL_SIGN_IDENTITY ayarlayın."
    codesign --force --deep --sign - --identifier "com.benkays.killbill" "$BUNDLE_DIR"
fi

echo "🗜️  Güncelleme paketi (KillBill.zip) oluşturuluyor..."
rm -f "$APP_NAME.zip"
/usr/bin/ditto -c -k --keepParent "$BUNDLE_DIR" "$APP_NAME.zip"

echo "✅ Başarılı! $BUNDLE_DIR ve $APP_NAME.zip hazırlandı."
echo "👉 Çalıştırmak için: open $BUNDLE_DIR"
