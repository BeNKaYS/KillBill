# KillBill

Çalışan uygulamaları menü çubuğundan tek yerden yönetin: seçtiklerinizi normal ya da
zorla kapatın, korunan uygulamaları toplu işlemlerin dışında tutun.

> "A fresh start without a restart."

KillBill, macOS 13+ için SwiftUI/AppKit ile yazılmış bir menü çubuğu (LSUIElement)
uygulamasıdır. Bu sürüm, Amico Apps'in QuitAll uygulamasından esinlenen bir klonun
bağımsız, bakımı yapılan sürümüdür.

```bash
./build_app.sh          # → KillBill.app + KillBill.zip
./build_pkg.sh          # → KillBill.pkg (imzalı ya da yerel imzasız)
./test.sh               # → regresyon kontrolleri
open KillBill.app
```

Gereksinim: Xcode Command Line Tools (Swift 5.9+).

## Kullanım

- **Panel:** arama, sıralama, tekli/toplu seçim, CPU değeri.
- **Kapat:** düğme hedef sayısını ve modu söyler (`Seçilen 3 uygulamayı kapat`).
  Option tuşu zorla kapatma modunu gösterir; zorla toplu kapatma onay ister.
- **Korunan uygulamalar:** satırdaki kilit simgesiyle eklenir. Korunanlar seçilemez,
  tekli ve toplu kapatmada atlanır. Liste `Ayarlar ▸ Kapatma` altında yönetilir.
- **Sonuç:** her hedef için `Yanıt bekleniyor`, `Kapandı`, `Kapatılamadı` ya da
  `Hâlâ açık` durumu gösterilir. Kaydetme diyaloğunda bekleyen uygulama kapanmış sayılmaz;
  zaman aşımı otomatik zorla kapatmaya dönüşmez.
- **Kısayollar:** panel açma, tümünü kapatma, tümünü zorla kapatma. Command, Option
  veya Control içeren birleşimler gerekir; `⌘A` gibi harfler kaydedilebilir, Escape iptal
  eder, Delete siler. Çakışma arayüzde bildirilir.

## Ayarlar

| Sekme | İçerik |
|---|---|
| Genel | Açılışta başlat, menü çubuğu simgesi, ses, sistem rengi, arka plan uygulamaları, gruplama, Finder, Çöp eylemi, sıralama, izinler, sıfırlama |
| Kapatma | Varsayılan işlem ve korunan uygulama listesi |
| Kısayollar | Üç global kısayol ve doğrulama mesajları |
| Güncelleme | Yerel klasör / GitHub, kontrol ve güncelleme, yedekler |
| Hakkında | Sürüm, kısa tanıtım, geliştirici bilgisi |

Otomatik hareketsizlik kapatması bu sürümde kullanılamıyor; uygulamalar yalnızca
kullanıcı işlemiyle kapatılır.

## Güncelleme

Akış: kontrol → bildir → onay → yedek → indir → doğrula → yaz → yeniden aç → gerekirse geri al.

- Tek sürüm kaynağı kökteki `version.json`; `.app`, `.zip` ve `.pkg` aynı sürümü taşır.
- GitHub release (önerilen) ya da dal, veya yerel klasör. HTTPS zorunludur; yönlendirmelerde de.
- Paket, açılmadan önce ZIP yapısı için denetlenir: yalnızca `KillBill.app/` girdileri,
  sembolik bağ yok, şifreli/çok parçalı/boyut aşan arşiv reddedilir.
- Açıldıktan sonra kimlik, çalıştırılabilir dosya, `version.json` sürümü ve (uzak kaynakta)
  aynı Developer ID takımı imzası doğrulanır.
- **Güncelleme açılamazsa** yeni sürüm ayrılır, önceki sürüm geri konur ve sonuç Ayarlar'da
  gösterilir. Yedekler `~/Library/Application Support/KillBill/Yedek/` altındadır.
- Özel depo anahtarı yalnızca macOS Anahtar Zinciri'nde tutulur; ayarlara yazılmaz.

## İmzalama ve dağıtım

Varsayılan betikler ad-hoc imza üretir ve yalnızca yerel kullanım içindir. Başka Mac'lere
dağıtım için:

```bash
KILLBILL_SIGN_IDENTITY="Developer ID Application: ..." ./build_pkg.sh
```

Sonrasında Apple notarizasyonu (`notarytool submit --wait` + `stapler`) gerekir. Bu adımlar
Apple Developer hesabı ve sertifika gerektirdiği için depoya eklenmemiştir.

## Testler

```bash
./test.sh
```

`Tests/main.swift` üretim kodunu derleyip sahte süreç işlemleriyle çalışır; gerçek
uygulamaları kapatmaz. Kapsanan davranışlar: normal/zorla kapatma ayrımı, korunan
uygulamalar, kapanma takibi ve zaman aşımı, arama/gruplama, kısayol kodları,
tercih kalıcılığı ve sıfırlama, sürüm/ZIP doğrulaması, kurulum ve geri alma.

## İzinler

- **Automation (Apple Events):** Finder'ı kapatmak ve çöpü boşaltmak için. Verilmezse
  KillBill ilgili işlemi yapmaz ve Sistem Ayarları'nı önerir.
- Uygulamaların normal/zorla kapatılması ve CPU okuma izin gerektirmez.

## Yapı

```
Sources/KillBill/
  main.swift                      # NSApplication giriş noktası
  App/AppDelegate.swift           # menü çubuğu, panel, ayarlar penceresi
  Core/
    PreferencesManager.swift      # tercihler, korunan uygulamalar, giriş öğesi
    RunningAppsManager.swift      # uygulama listesi, CPU, gruplama
    QuitService.swift             # kapatma politikası ve sonuç takibi
    UpdateManager.swift           # güncelleme orkestrasyonu
    UpdateValidation.swift        # sürüm/ZIP/imza doğrulama, geri alma
    HotkeyManager.swift           # Carbon global kısayollar
    PermissionsManager.swift      # Automation izni
    SoundPlayer.swift             # kapatma sesleri
    StatusIcon.swift              # menü çubuğu simgeleri
  Views/
    MenuPanelView.swift           # panel
    AppRowView.swift              # uygulama satırı
    PreferencesView.swift         # sekmeli ayarlar
    ShortcutRecorderView.swift    # kısayol kaydedici
    DeveloperCardView.swift       # (eski kart; artık kullanılmıyor)
    ViewState.swift               # CLT uyumlu State eşlemesi
installer/                        # pkg dağıtımı ve sade sonuç ekranı
Tests/main.swift                  # regresyon kontrolleri
test.sh                           # test çalıştırıcısı
```

## Geliştirici

**Sercan ÖZDEMİR (BeNKaYS)** · Bilişim Teknolojileri Öğretmeni
[sercanozdemir@yandex.com](mailto:sercanozdemir@yandex.com) · [github.com/BeNKaYS](https://github.com/BeNKaYS)
