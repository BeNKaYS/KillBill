#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"
APP_NAME="KillBill"
IDENTIFIER="com.benkays.killbill"

# Sürüm tek kaynaktan: version.json
VERSION=$(/usr/bin/python3 -c 'import json;print(json.load(open("version.json"))["surum"])')
[[ "$VERSION" =~ ^[0-9]+(\.[0-9]+){0,3}$ ]] || { echo "❌ version.json içindeki surum geçersiz: $VERSION"; exit 1; }

# 1) .app ve KillBill.zip'i build_app.sh üretir (tek paketleme yolu).
./build_app.sh

echo "🎨 Kurucu için sade geliştirici bilgisi hazırlanıyor..."
# Kurulum sonu ekranı: ayrı kart/animasyon değil, uygulamanın kendi sade "Hakkında" görünümü.
cat > installer/conclusion.html << EOF
<!DOCTYPE html>
<html lang="tr"><head><meta charset="utf-8">
<style>
 body { font: 13px -apple-system, BlinkMacSystemFont, sans-serif; color: #1d1d1f; margin: 0; padding: 28px 32px; }
 h1 { font-size: 17px; margin: 0 0 4px; }
 .muted { color: #6e6e73; margin: 0 0 18px; }
 p { margin: 0 0 8px; line-height: 1.45; }
 a { color: #0a63c2; text-decoration: none; }
 hr { border: 0; border-top: 1px solid #d2d2d7; margin: 18px 0; }
</style></head><body>
<h1>KillBill $VERSION</h1>
<p class="muted">Kurulum tamamlandı. Uygulama /Applications klasörüne eklendi.</p>
<p>Menü çubuğundan KillBill'i açın; seçtiğiniz uygulamaları normal ya da zorla kapatın. Korunan uygulamalar toplu işlemlerde atlanır.</p>
<hr>
<p><strong>Sercan ÖZDEMİR · BeNKaYS</strong><br>Bilişim Teknolojileri Öğretmeni</p>
<p><a href="mailto:sercanozdemir@yandex.com">sercanozdemir@yandex.com</a> · <a href="https://github.com/BeNKaYS">github.com/BeNKaYS</a></p>
</body></html>
EOF

if [ -n "${KILLBILL_SIGN_IDENTITY:-}" ]; then
    echo "📦 Bileşen paketi Developer ID ile oluşturuluyor..."
    pkgbuild --component "$APP_NAME.app" \
             --install-location "/Applications" \
             --identifier "$IDENTIFIER" \
             --version "$VERSION" \
             --sign "$KILLBILL_SIGN_IDENTITY" \
             "$APP_NAME-component.pkg"
    productbuild --distribution installer/distribution.xml \
                 --package-path . \
                 --resources installer \
                 --sign "$KILLBILL_SIGN_IDENTITY" \
                 "$APP_NAME.pkg"
    echo "🔏 Paket imzalandı."
else
    echo "📦 Bileşen paketi (imzasız, yerel kullanım) oluşturuluyor..."
    pkgbuild --component "$APP_NAME.app" \
             --install-location "/Applications" \
             --identifier "$IDENTIFIER" \
             --version "$VERSION" \
             "$APP_NAME-component.pkg"
    productbuild --distribution installer/distribution.xml \
                 --package-path . \
                 --resources installer \
                 "$APP_NAME.pkg"
    echo "⚠️  Paket imzasız. Başka Mac'lere dağıtım için KILLBILL_SIGN_IDENTITY ve notarizasyon gerekir."
fi

echo ""
echo "🎉 TAMAMLANDI:"
echo "  1. Uygulama:  $APP_NAME.app"
echo "  2. Bileşen:   $APP_NAME-component.pkg"
echo "  3. Yükleyici: $APP_NAME.pkg"
echo ""
echo "👉 Kurucuyu açmak için: open $APP_NAME.pkg"
