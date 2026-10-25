#!/bin/bash
set -e

echo "🚀 KillBill derleniyor (Release)..."
cd "$(dirname "$0")"

swift build -c release

APP_NAME="KillBill"
BUNDLE_DIR="$APP_NAME.app"
MACOS_DIR="$BUNDLE_DIR/Contents/MacOS"
RESOURCES_DIR="$BUNDLE_DIR/Contents/Resources"

echo "📦 Uygulama paketi (.app) oluşturuluyor..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# İkili dosyayı kopyala
cp ".build/release/KillBill" "$MACOS_DIR/$APP_NAME"

# Kaynakları kopyala (Geliştirici Kartı, ikon, JS, sesler)
if [ -d "Sources/KillBill/Resources" ]; then
    cp -R Sources/KillBill/Resources/* "$RESOURCES_DIR/" 2>/dev/null || true
fi

# Sürüm: tek kaynak version.json
VERSION="0.0.0"
if [ -f "version.json" ]; then
    VERSION=$(/usr/bin/python3 -c 'import json;print(json.load(open("version.json"))["surum"])' 2>/dev/null || echo "0.0.0")
    cp "version.json" "$RESOURCES_DIR/version.json"
fi
echo "🔖 Sürüm: $VERSION"

# Info.plist oluştur
cat << 'EOF' > "$BUNDLE_DIR/Contents/Info.plist"
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
    <string>KillBill, diğer uygulamaların pencerelerini kapatmak ve çöp kutusunu boşaltmak için Apple Events erişimi gerektirir.</string>
    <key>NSDesktopFolderUsageDescription</key>
    <string>KillBill masaüstü öğelerini yönetmek için masaüstü erişimi gerektirir.</string>
</dict>
</plist>
EOF

/usr/bin/sed -i '' "s/__VERSION__/$VERSION/g" "$BUNDLE_DIR/Contents/Info.plist"

chmod +x "$MACOS_DIR/$APP_NAME"

echo "🔏 Ad-hoc imzalanıyor..."
codesign --force --deep --sign - --identifier "com.benkays.killbill" "$BUNDLE_DIR" 2>/dev/null || true

# Güncelleme paketi (yerel kaynak ve GitHub release için)
echo "🗜️  Güncelleme paketi (KillBill.zip) oluşturuluyor..."
rm -f "$APP_NAME.zip"
/usr/bin/ditto -c -k --keepParent "$BUNDLE_DIR" "$APP_NAME.zip"

echo "✅ Başarılı! $BUNDLE_DIR ve $APP_NAME.zip hazırlandı."
echo "👉 Çalıştırmak için: open $BUNDLE_DIR"
