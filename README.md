# KillBill

**QuitAll** (Amico Apps) uygulamasının birebir menü çubuğu klonu.
Çalışan uygulamaları tek yerden — bir kısmını ya da hepsini — kapatın.

> "A fresh start without a restart."

---

## Nasıl çalışır

KillBill bir menü çubuğu (LSUIElement) uygulamasıdır. Menü çubuğundaki ikona tıklayınca
bir panel açılır:

- **Quit All** butonu — seçili tüm uygulamaları kapatır (Option tuşuyla *Force Quit All*).
- **Search** — uygulamalarda filtreleme.
- **Seçim kutuları** — satır satır ya da hepsini seç/kaldır.
- **Her satır:** onay kutusu · uygulama ikonu · ad · CPU % · güç/`⏻` (Option ile `⚡`) · `⋯` menüsü
  (Quit / Force Quit / Bring to Front / Reveal in Finder).
- **Alt bilgi:** dönen ipucu metni + `☰` menüsü (View background apps · Preferences · Help · Quit).

Uygulamalar, kapanmadan önce kaydetmeniz için sizi uyarır. Force Quit ise kaydedilmemiş
değişiklikleri yok sayar.

---

## Tersine mühendislik kaynağı

Klon, sistemde kurulu gerçek **QuitAll 1.3.6 (build 206)** paketinden çıkarıldı
(`/Applications/QuitAll.app`). Kullanılan kanıtlar:

| Kanıt | Ne verdi |
|---|---|
| `Contents/MacOS/QuitAll` (string tablosu) | Sınıf/ivar adları, tüm ayar anahtarları, menü/uyarı metinleri, dönen ipuçları |
| `Base.lproj/*.storyboardc` (REA `decode-interface-builder`) | Preferences sekmeleri, kontroller, çerçeveler, tüm tooltip metinleri |
| `Assets.car` (REA `inspect-asset-catalog`) | UI ikon adları + **AccentColor = sRGB(0.996, 0.737, 0.200) = `#FEC033`** |
| `defaults read com.quitallapp.quitall-paddle` | Canlı kullanıcı ayarları |
| Setapp/Amico ekran görüntüleri | Panel ve Preferences görsel tasarımı |

> Not: REA'nın Hopper sağlayıcısı bu makinede `~/Applications` altında Hopper arıyordu;
> `/Applications` altındaki Hopper'a bir sembolik bağ ile düzeltildi. Tasarım için Hopper'a
> gerek kalmadı — storyboard + asset kataloğu + string tablosu yeterli oldu.

---

## Birebir ayar anahtarları

`UserDefaults` anahtarları orijinal QuitAll ile **aynı** (bkz. `Core/PreferencesManager.swift`):

| Anahtar | Anlam |
|---|---|
| `kUserdefaultsPlaySound` | Kapatma sesi |
| `kUserdefaultsGroupBackgroundApps` | Arka plan kopyalarını grupla |
| `kUserdefaultsShowBackgroundApps` | Arka plan uygulamalarını göster |
| `kUserdefaultsDeselectApps` | Varsayılan olarak seçimi kaldır |
| `kUserdefaultsDisableTips` | İpuçlarını kapat |
| `kUserdefaultsQuitOption` | `Quit` / `Force Quit` |
| `kUserdefaultsMenuAppsSort` | `0` alfabetik · `1` CPU |
| `kUserdefaultsQuitInactiveAppsAfter` | `{enabled, minutes, unit}` JSON |
| `kUserdefaultsShortcutActivate/Quit/ForceQuit` | `{keyCode, modifiers, enabled, deleted}` JSON |
| `includeFinderInList` / `includeTrashInList` | Finder / Çöp satırı |
| `kUserdefaultsUseSystemColor` | Vurgu için sistem rengi |

## Preferences sekmeleri

General · Shortcuts · Support · About · License · **Developer**

General sekmesindeki alanlar orijinalden: Startup (Open at login), Fun (Play cool sounds,
Use default system color), Advanced (View/Group background apps, Deselect apps by default,
Quit inactive apps after + süre, Disable quit tips, Include Finder/Trash), Sort, Default, Reset all
ve **Permissions** bölümü.

---

## İzinler

- **Automation (Apple Events)** — Finder'ı kapatmak ve çöp kutusunu boşaltmak için.
  `Preferences ▸ General ▸ Permissions ▸ İste` ile talep edilir; verilmezse ilgili işlemler
  Sistem Ayarları'na yönlendirir.
- **Accessibility** — pencere/süreç denetimi için (isteğe bağlı).
- Uygulamaların normal/force kapatılması ve CPU okuma **izin gerektirmez** (NSRunningApplication).

---

## Derleme

```bash
./build_app.sh     # → KillBill.app
./build_pkg.sh     # → KillBill.pkg (kurulum sonu BeNKaYS geliştirici kartı)
open KillBill.app
```

Gereksinim: Xcode **Command Line Tools** (Swift 5.9+). Not: SwiftUI `@State` makrosu CLT'de
bulunmadığından bu projede `@State` yerine düz `State` yapısı kullanılır.

## Geliştirici kartı

- Uygulama içinde: **Preferences ▸ Developer** (WKWebView).
- Kurucuda: `.pkg` **conclusion** ekranı — avatar ve QR kod satır içine gömülü, kendi kendine
  yeten HTML (`installer/conclusion.html`, `build_pkg.sh` tarafından üretilir).

Kaynaklar: `Sources/KillBill/Resources/developer_card.html`, `avatar.png`, `qrcode.min.js`.

---

## Yapı

```
Sources/KillBill/
  main.swift                      # NSApplication giriş noktası
  App/AppDelegate.swift           # menü çubuğu + panel + tercihler penceresi
  Core/
    PreferencesManager.swift      # birebir UserDefaults anahtarları
    RunningAppsManager.swift      # uygulama listesi + CPU (ps) + quit/forceQuit
    PermissionsManager.swift      # Automation / Accessibility
    QuitService.swift             # toplu/tekil kapatma
    HotkeyManager.swift           # Carbon global kısayollar
    SoundPlayer.swift             # kapatma sesleri
  Views/
    MenuPanelView.swift           # panel (QuitAll tasarımı)
    AppRowView.swift              # liste satırı
    PreferencesView.swift         # sekmeli tercihler
    DeveloperCardView.swift       # geliştirici kartı (WKWebView)
    ShortcutRecorderView.swift    # kısayol kaydedici
  Resources/                      # ikon, avatar, kart, ses, JS
installer/                        # pkg distribution + welcome + conclusion
```
