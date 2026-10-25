import SwiftUI
import AppKit

struct PreferencesView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case general, updates, shortcuts, developer
        var id: String { rawValue }
        var title: String {
            switch self {
            case .general: return "Genel"
            case .updates: return "Güncelleme"
            case .shortcuts: return "Kısayollar"
            case .developer: return "Geliştirici"
            }
        }
        var symbol: String {
            switch self {
            case .general: return "gearshape"
            case .updates: return "arrow.triangle.2.circlepath"
            case .shortcuts: return "command"
            case .developer: return "person.crop.circle"
            }
        }
    }

    private var tab = State(initialValue: Tab.general)
    private let accent = Color(red: 0.996, green: 0.737, blue: 0.200)

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch tab.wrappedValue {
                    case .general: GeneralTab(accent: accent)
                    case .updates: UpdatesTab(accent: accent)
                    case .shortcuts: ShortcutsTab(accent: accent)
                    case .developer: DeveloperTab()
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 420, minHeight: 560)
    }

    private var tabBar: some View {
        HStack(spacing: 6) {
            ForEach(Tab.allCases) { t in
                Button(action: { tab.wrappedValue = t }) {
                    VStack(spacing: 3) {
                        Image(systemName: t.symbol).font(.system(size: 17, weight: .semibold))
                        Text(t.title).font(.system(size: 10.5, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundColor(tab.wrappedValue == t ? accent : .secondary)
                    .background(RoundedRectangle(cornerRadius: 8).fill(tab.wrappedValue == t ? Color.primary.opacity(0.07) : .clear))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

// MARK: - Ortak yardımcılar
private struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.secondary)
    }
}

private struct HelpBadge: View {
    let tip: String
    var body: some View {
        Image(systemName: "questionmark.circle")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
            .help(tip)
    }
}

private struct PrefToggle: View {
    let title: String
    @Binding var isOn: Bool
    var tip: String? = nil
    var body: some View {
        HStack(spacing: 6) {
            Toggle(title, isOn: $isOn).toggleStyle(.checkbox).font(.system(size: 12.5))
            if let tip { HelpBadge(tip: tip) }
            Spacer()
        }
    }
}

// MARK: - Genel
private struct GeneralTab: View {
    let accent: Color
    @ObservedObject var prefs = PreferencesManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "Başlangıç:")
            PrefToggle(title: "Açılışta başlat", isOn: $prefs.openAtLogin, tip: "KillBill'i oturum açılışında başlat.")

            SectionTitle(text: "Menü çubuğu:")
            statusIconPicker
            Text("Seçili simge: \(prefs.statusIconStyle.label)")
                .font(.system(size: 11)).foregroundColor(.secondary)

            SectionTitle(text: "Eğlence:")
            PrefToggle(title: "Sesleri çal", isOn: $prefs.playSounds,
                       tip: "Uygulamalar kapatılırken tatmin edici bir ses çalar.")
            PrefToggle(title: "Varsayılan sistem rengini kullan", isOn: $prefs.useSystemColor,
                       tip: "Vurgu rengi için sistem rengini kullanır.")

            SectionTitle(text: "Gelişmiş:")
            PrefToggle(title: "Arka plan uygulamalarını gör", isOn: $prefs.showBackgroundApps,
                       tip: "Arka planda çalışan tüm uygulamaları gör ve kapat.")
            PrefToggle(title: "Arka plan uygulamalarını grupla", isOn: $prefs.groupBackgroundApps,
                       tip: "Aynı arka plan uygulamasının birden çok kopyasını tek satırda grupla.")
            PrefToggle(title: "Uygulamaları varsayılan olarak seçme", isOn: $prefs.deselectApps)

            HStack(spacing: 8) {
                Toggle("Şu süreden sonra hareketsiz uygulamaları kapat", isOn: $prefs.autoQuitEnabled)
                    .toggleStyle(.checkbox).font(.system(size: 12.5))
                TextField("", value: $prefs.autoQuitMinutes, format: .number)
                    .frame(width: 44).textFieldStyle(.roundedBorder)
                    .disabled(!prefs.autoQuitEnabled)
                Picker("", selection: $prefs.autoQuitUnit) {
                    ForEach(InactiveUnit.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden().frame(width: 84).disabled(!prefs.autoQuitEnabled)
                HelpBadge(tip: "Hareketsiz uygulamaları belirli bir süre sonra otomatik kapat.")
            }

            PrefToggle(title: "Kapatma ipuçlarını kapat", isOn: $prefs.disableTips)
            PrefToggle(title: "Finder'ı listeye dahil et", isOn: $prefs.includeFinderInList)
            PrefToggle(title: "Çöp Kutusu'nu listeye dahil et", isOn: $prefs.includeTrashInList)

            Divider().padding(.vertical, 2)

            HStack {
                Text("Sırala:").font(.system(size: 12.5))
                Picker("", selection: $prefs.sortOption) {
                    ForEach(AppsSort.allCases) { Text($0.label).tag($0) }
                }.labelsHidden().frame(width: 150)
                HelpBadge(tip: "Uygulama listesini alfabetik ya da CPU kullanımına göre sırala.")
                Spacer()
            }

            HStack {
                Text("Varsayılan:").font(.system(size: 12.5))
                Picker("", selection: $prefs.quitOption) {
                    ForEach(QuitOption.allCases) { Text($0.label).tag($0) }
                }.labelsHidden().frame(width: 150)
                HelpBadge(tip: "Varsayılan kapatma davranışı: Normal ya da Zorla kapat.")
                Spacer()
            }

            HStack {
                Text("Sıfırla:").font(.system(size: 12.5))
                Button("Tümünü sıfırla") { prefs.resetAll() }
                Spacer()
            }

            Divider().padding(.vertical, 2)
            PermissionsSection(accent: accent)
        }
    }

    // Menü çubuğu simgesi seçici
    private var statusIconPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
            ForEach(StatusIconStyle.available) { style in
                let isSelected = prefs.statusIconStyle == style
                Button {
                    prefs.statusIconStyle = style
                } label: {
                    Image(nsImage: style.makeImage(size: 20))
                        .renderingMode(.template)
                        .foregroundColor(isSelected ? accent : .primary)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 7)
                                .fill(isSelected ? accent.opacity(0.16) : Color.primary.opacity(0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .strokeBorder(isSelected ? accent : Color.clear, lineWidth: 1.2)
                        )
                }
                .buttonStyle(.plain)
                .help(style.label)
                .accessibilityLabel(Text(style.label))
            }
        }
    }
}

// MARK: - İzinler bölümü
private struct PermissionsSection: View {
    let accent: Color
    @ObservedObject var perms = PermissionsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "İzinler:")
            permissionRow(
                title: "Otomasyon (Apple Events)",
                desc: "Finder pencerelerini kapatmak ve çöpü boşaltmak için gerekir.",
                granted: perms.automationGranted,
                request: { perms.requestAutomation() },
                openSettings: { perms.openAutomationSettings() }
            )
        }
        .onAppear { perms.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            perms.refresh()
        }
    }

    private func permissionRow(title: String, desc: String, granted: Bool,
                               request: @escaping () -> Void, openSettings: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundColor(granted ? .green : .orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 12.5, weight: .semibold))
                Text(desc).font(.system(size: 11)).foregroundColor(.secondary)
            }
            Spacer()
            if granted {
                Text("Verildi").font(.system(size: 11, weight: .semibold)).foregroundColor(.green)
            } else {
                Button("Sistem Ayarları") { openSettings() }
                Button("İste") { request() }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
    }
}

// MARK: - Kısayollar
private struct ShortcutsTab: View {
    let accent: Color
    @ObservedObject var prefs = PreferencesManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            shortcutRow("Menüyü aç:", enabled: $prefs.shortcutActivateEnabled,
                        combo: $prefs.shortcutActivate)
            shortcutRow("Tümünü kapat:", enabled: $prefs.shortcutQuitEnabled,
                        combo: $prefs.shortcutQuit)
            shortcutRow("Tümünü zorla kapat:", enabled: $prefs.shortcutForceQuitEnabled,
                        combo: $prefs.shortcutForceQuit)

            HStack(spacing: 6) {
                Image(systemName: "option").font(.system(size: 12))
                Text("“Kapat” ve “Zorla Kapat” arasında geçiş için Option tuşunu basılı tutun.")
                    .font(.system(size: 11.5)).foregroundColor(.secondary)
            }
            .padding(.top, 6)
        }
    }

    private func shortcutRow(_ title: String, enabled: Binding<Bool>, combo: Binding<ShortcutCombo>) -> some View {
        HStack(spacing: 8) {
            Toggle("", isOn: enabled).labelsHidden().toggleStyle(.checkbox)
            Text(title).font(.system(size: 12.5)).frame(width: 130, alignment: .leading)
            ShortcutRecorderView(combo: combo, onChange: { HotkeyManager.shared.reload() })
                .frame(width: 150, height: 24)
                .disabled(!enabled.wrappedValue)
            Button {
                combo.wrappedValue = ShortcutCombo(keyCode: 0, modifiers: 0, enabled: enabled.wrappedValue)
                HotkeyManager.shared.reload()
            } label: {
                Image(systemName: "xmark.circle").foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(!enabled.wrappedValue)
            HelpBadge(tip: "Bu kısayolu kaydet veya sil.")
            Spacer()
        }
    }
}

// MARK: - Güncelleme
private struct UpdatesTab: View {
    let accent: Color
    @ObservedObject var prefs = PreferencesManager.shared
    @ObservedObject var updater = UpdateManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("KillBill").font(.system(size: 15, weight: .bold))
                Text("Mevcut sürüm: \(updater.currentVersion)")
                    .font(.system(size: 12)).foregroundColor(.secondary)
                if !updater.currentNote.isEmpty {
                    Text(updater.currentNote)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }

            Divider()

            SectionTitle(text: "Kaynak:")
            Picker("", selection: $prefs.updateSourceKind) {
                ForEach(UpdateSourceKind.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch prefs.updateSourceKind {
            case .local:
                HStack(spacing: 6) {
                    TextField("Kaynak klasör yolu", text: $prefs.updateLocalPath)
                        .textFieldStyle(.roundedBorder)
                    Button("Seç…") { chooseLocalFolder() }
                }
                Text("Klasörde `version.json` ve `KillBill.zip` (ya da `KillBill.app`) bulunmalı.")
                    .font(.system(size: 10.5)).foregroundColor(.secondary)
            case .github:
                HStack(spacing: 6) {
                    TextField("sahip/depo", text: $prefs.updateGitHubRepo)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        let repo = prefs.updateGitHubRepo.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !repo.isEmpty,
                              let url = URL(string: "https://github.com/\(repo)") else { return }
                        NSWorkspace.shared.open(url)
                    } label: { Image(systemName: "arrow.up.right.square") }
                        .buttonStyle(.borderless)
                    HelpBadge(tip: "Örnek: kullanici/KillBill. Tam URL de yazılabilir.")
                }
                HStack(spacing: 8) {
                    Picker("", selection: $prefs.updateGitHubMode) {
                        ForEach(GitHubUpdateMode.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 160)
                    if prefs.updateGitHubMode == .branch {
                        TextField("dal", text: $prefs.updateBranch)
                            .textFieldStyle(.roundedBorder).frame(width: 120)
                    } else {
                        Text("Release modunda `KillBill.zip` ve `version.json` varlıkları aranır.")
                            .font(.system(size: 10.5)).foregroundColor(.secondary)
                    }
                }
                if prefs.updateGitHubMode == .release {
                    Text("Release yoksa 404 alırsınız; depoda Release oluşturup `KillBill.zip` ve `version.json` yükleyin.")
                        .font(.system(size: 10.5)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            HStack(spacing: 8) {
                Button {
                    updater.checkForUpdates()
                } label: {
                    Label("Kontrol Et", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(updater.isChecking || updater.isUpdating)

                Button {
                    updater.performUpdate()
                } label: {
                    Label("Güncelle", systemImage: "square.and.arrow.down")
                }
                .disabled(updater.available == nil || updater.isChecking || updater.isUpdating)

                if updater.isChecking || updater.isUpdating {
                    ProgressView().controlSize(.small)
                }
                Spacer()
            }

            Text(updater.statusLine)
                .font(.system(size: 11.5))
                .foregroundColor(updater.statusLine.hasPrefix("Hata") || updater.statusLine.hasPrefix("Güncelleme başarısız")
                                 ? .orange : .secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let last = updater.lastCheck {
                Text("Son kontrol: \(last.formatted(date: .omitted, time: .shortened))")
                    .font(.system(size: 10.5)).foregroundColor(.secondary)
            }

            if !updater.isRunningFromBundle {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    Text("Güncelleme yalnızca .app olarak çalışırken yazılabilir.")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
            Spacer()
        }
    }

    private func chooseLocalFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Seç"
        if !prefs.updateLocalPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: (prefs.updateLocalPath as NSString).expandingTildeInPath)
        }
        if panel.runModal() == .OK, let url = panel.url {
            prefs.updateLocalPath = url.path
        }
    }
}

// MARK: - Geliştirici (Geliştirici Kartı)
private struct DeveloperTab: View {
    var body: some View {
        VStack(spacing: 8) {
            DeveloperCardView()
                .frame(height: 560)
                .clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
}
