import AppKit
import SwiftUI
import Combine

// MARK: - AppKit efekt görünümü (native translusent arka plan)
struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blending: NSVisualEffectView.BlendingMode = .behindWindow
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blending
    }
}

// MARK: - Panel view model
final class PanelViewModel: ObservableObject {
    @Published var search: String = ""
    @Published var selected: Set<Int32> = []
    @Published var forceMode: Bool = false
    @Published var tip: String = TipProvider.random()

    private var cancellables = Set<AnyCancellable>()
    private var knownPIDs: Set<Int32> = []

    init() {
        RunningAppsManager.shared.$apps
            .receive(on: RunLoop.main)
            .sink { [weak self] apps in self?.syncSelection(apps) }
            .store(in: &cancellables)
        syncSelection(RunningAppsManager.shared.apps)
    }

    private func syncSelection(_ apps: [AppEntry]) {
        let visible = Set(apps.filter { !$0.isBackground || PreferencesManager.shared.showBackgroundApps }.map(\.id))
        if PreferencesManager.shared.deselectApps {
            selected = selected.intersection(visible)
        } else {
            selected = selected.intersection(visible).union(visible.subtracting(knownPIDs))
        }
        knownPIDs = visible
    }

    var rows: [AppEntry] { RunningAppsManager.shared.panelList(search: search) }

    var allSelected: Bool {
        let ids = rows.map(\.id)
        return !ids.isEmpty && ids.allSatisfy { selected.contains($0) }
    }

    func toggleAll() {
        let ids = rows.map(\.id)
        if allSelected { selected.subtract(ids) }
        else { selected.formUnion(ids) }
    }

    func toggle(_ pid: Int32) {
        if selected.contains(pid) { selected.remove(pid) } else { selected.insert(pid) }
    }

    func rotateTip() { tip = TipProvider.random() }

    func quitSelected(force: Bool) {
        let list = rows.filter { selected.contains($0.id) }
        _ = QuitService.shared.quit(entries: list, force: force || PreferencesManager.shared.quitOption == .force)
    }
}

// MARK: - Dönen ipuçları
enum TipProvider {
    static let tips = [
        "Kapatmakta ısrar et ⚡",
        "Kazananlar kapatır 🏆",
        "Kapatma zamanı 👋",
        "Kapatmaya bağımlı oldum",
        "Yedi kez düş, sekiz kez kapat",
        "Kapatmayı hiç bırakma",
        "Kapatmakta utanç yok",
        "Kapatıcılar favorimiz",
        "Burada kazananlar kapatır",
        "Kapatma güvenli bölgesi",
        "Kapatmakta başarısızlık yok",
        "Kapatmak yeni bir başlangıçtır"
    ]
    static func random() -> String { tips.randomElement() ?? tips[0] }
}

// MARK: - Menü çubuğu paneli
struct MenuPanelView: View {
    @StateObject private var vm = PanelViewModel()
    @ObservedObject private var apps = RunningAppsManager.shared
    @ObservedObject private var prefs = PreferencesManager.shared
    private let accent = Color(red: 0.996, green: 0.737, blue: 0.200)

    var body: some View {
        VStack(spacing: 8) {
            headerButton
            searchRow
            appList
            footer
        }
        .padding(10)
        .frame(width: 320)
        .background(VisualEffectView(material: .popover, blending: .behindWindow))
        .onAppear {
            RunningAppsManager.shared.refresh()
            installFlagsMonitor()
        }
    }

    // "Tümünü Kapat" butonu
    private var headerButton: some View {
        Button(action: {
            vm.quitSelected(force: false)
        }) {
            Text(vm.forceMode ? "Zorla Tümünü Kapat" : "Tümünü Kapat")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black.opacity(0.85))
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .background(accent)
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .help("Seçili uygulamaları kapat. Option tuşuyla Zorla Kapat.")
    }

    // Seç-all onay kutusu + arama
    private var searchRow: some View {
        HStack(spacing: 8) {
            CheckBox(isOn: Binding(get: { vm.allSelected }, set: { _ in vm.toggleAll() }))
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("Ara", text: $vm.search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5))
            }
            .padding(.horizontal, 8)
            .frame(height: 26)
            .background(Color.primary.opacity(0.08))
            .cornerRadius(7)
        }
    }

    // Uygulama listesi
    private var appList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(vm.rows) { entry in
                    AppRowView(
                        entry: entry,
                        isSelected: vm.selected.contains(entry.id),
                        forceMode: vm.forceMode,
                        accent: accent,
                        onToggle: { vm.toggle(entry.id) },
                        onQuit: { _ = QuitService.shared.quit(entries: [entry], force: vm.forceMode) },
                        onForceQuit: { _ = QuitService.shared.quit(entries: [entry], force: true) },
                        onUnhide: { RunningAppsManager.shared.unhide(pid: entry.id) },
                        onReveal: { reveal(entry) }
                    )
                }
                if vm.rows.isEmpty {
                    Text("Çalışan uygulama yok")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 24)
                }
            }
            .padding(.vertical, 2)
        }
        .frame(maxHeight: 320)
    }

    // Alt bilgi
    private var footer: some View {
        HStack {
            Text(vm.tip)
                .font(.system(size: 11.5))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .onTapGesture { vm.rotateTip() }
            Spacer()
            Menu {
                Button(prefs.showBackgroundApps ? "Arka plan uygulamalarını gizle" : "Arka plan uygulamalarını gör") {
                    prefs.showBackgroundApps.toggle()
                }
                Divider()
                Button("Tercihler…") { NotificationCenter.default.post(name: .openPreferencesRequested, object: nil) }
                Button("Yardım") { NSWorkspace.shared.open(URL(string: "https://amicoapps.com/support/")!) }
                Divider()
                Button("KillBill'den Çık") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 13, weight: .semibold))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 28)
        }
        .padding(.top, 4)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Color.primary.opacity(0.08)), alignment: .top)
    }

    private func reveal(_ entry: AppEntry) {
        if let url = RunningAppsManager.shared.runningApplication(pid: entry.id)?.bundleURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    // Option tuşu ile Kapat/Zorla Kapat geçişi
    private func installFlagsMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { ev in
            vm.forceMode = ev.modifierFlags.contains(.option)
            return ev
        }
    }
}

// MARK: - Onay kutusu (native görünüm)
struct CheckBox: View {
    @Binding var isOn: Bool
    var body: some View {
        Button(action: { isOn.toggle() }) {
            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isOn ? Color(red: 0.996, green: 0.737, blue: 0.200) : .secondary)
        }
        .buttonStyle(.plain)
        .frame(width: 18)
    }
}
