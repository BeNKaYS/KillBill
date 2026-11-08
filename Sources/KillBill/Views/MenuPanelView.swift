import AppKit
import SwiftUI
import Combine

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .popover
    var blending: NSVisualEffectView.BlendingMode = .behindWindow
    func makeNSView(context: Context) -> NSVisualEffectView { NSVisualEffectView() }
    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
        view.state = .active
    }
}

final class PanelViewModel: ObservableObject {
    @Published var search = ""
    @Published var selected: Set<Int32> = []
    @Published var forceMode = false
    private var knownPIDs: Set<Int32> = []
    private var subscriptions = Set<AnyCancellable>()
    private var flagsMonitor: Any?

    init() {
        RunningAppsManager.shared.$apps
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncSelection() }
            .store(in: &subscriptions)
        PreferencesManager.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.syncSelection() }
            .store(in: &subscriptions)
    }

    var rows: [AppEntry] { RunningAppsManager.shared.panelList(search: search) }
    var eligibleRows: [AppEntry] { rows.filter { !PreferencesManager.shared.isProtected($0) } }
    var targets: [AppEntry] { eligibleRows.filter { selected.contains($0.id) } }
    var effectiveForce: Bool { forceMode || PreferencesManager.shared.quitOption == .force }
    var allSelected: Bool { !eligibleRows.isEmpty && eligibleRows.allSatisfy { selected.contains($0.id) } }

    func syncSelection() {
        let visible = Set(RunningAppsManager.shared.panelList(search: "")
            .filter { !PreferencesManager.shared.isProtected($0) }.map(\.id))
        selected.formIntersection(visible)
        if !PreferencesManager.shared.deselectApps { selected.formUnion(visible.subtracting(knownPIDs)) }
        knownPIDs = visible
    }

    func toggleAll() {
        let ids = eligibleRows.map(\.id)
        if allSelected { selected.subtract(ids) } else { selected.formUnion(ids) }
    }

    func toggle(_ pid: Int32) {
        if selected.contains(pid) { selected.remove(pid) } else { selected.insert(pid) }
    }

    func beginObservingKeys() {
        forceMode = NSEvent.modifierFlags.contains(.option)
        guard flagsMonitor == nil else { return }
        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.forceMode = event.modifierFlags.contains(.option)
            return event
        }
    }

    func endObservingKeys() {
        if let monitor = flagsMonitor { NSEvent.removeMonitor(monitor) }
        flagsMonitor = nil
        forceMode = false
    }
    deinit { if let monitor = flagsMonitor { NSEvent.removeMonitor(monitor) } }
}

struct MenuPanelView: View {
    @StateObject private var vm = PanelViewModel()
    @ObservedObject private var apps = RunningAppsManager.shared
    @ObservedObject private var prefs = PreferencesManager.shared
    @ObservedObject private var quit = QuitService.shared
    private var accent: Color { prefs.useSystemColor ? .accentColor : Color(red: 0.996, green: 0.737, blue: 0.200) }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("KillBill").font(.headline)
                Spacer()
                Menu {
                    Picker("Sıralama", selection: $prefs.sortOption) {
                        ForEach(AppsSort.allCases) { Text($0.label).tag($0) }
                    }
                    Toggle("Arka plan uygulamaları", isOn: $prefs.showBackgroundApps)
                } label: { Image(systemName: "line.3.horizontal.decrease") }
                .menuStyle(.borderlessButton).fixedSize()
                .accessibilityLabel("Liste seçenekleri")
            }
            HStack(spacing: 8) {
                CheckBox(isOn: Binding(get: { vm.allSelected }, set: { _ in vm.toggleAll() }))
                    .accessibilityLabel("Görünen uygulamaların tümünü seç")
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Uygulama ara", text: $vm.search).textFieldStyle(.plain)
                if !vm.search.isEmpty {
                    Button { vm.search = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).accessibilityLabel("Aramayı temizle")
                }
            }
            .padding(8).background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(vm.rows) { entry in
                        AppRowView(entry: entry, isSelected: vm.selected.contains(entry.id),
                                   forceMode: vm.effectiveForce, accent: accent,
                                   isProtected: prefs.isProtected(entry),
                                   onProtect: { prefs.toggleProtection(entry) },
                                   onToggle: { vm.toggle(entry.id) },
                                   onQuit: { quit.quit(entries: [entry], force: vm.effectiveForce) },
                                   onForceQuit: { quit.quit(entries: [entry], force: true) },
                                   onUnhide: { apps.unhide(pid: entry.id) },
                                   onReveal: { reveal(entry) })
                    }
                    if vm.rows.isEmpty {
                        VStack(spacing: 6) {
                            Image(systemName: "magnifyingglass").font(.title2)
                            Text(vm.search.isEmpty ? "Listelenecek uygulama yok" : "Eşleşen uygulama bulunamadı")
                            if !vm.search.isEmpty { Button("Aramayı temizle") { vm.search = "" } }
                        }.foregroundColor(.secondary).padding(.vertical, 28)
                    }
                }
            }.frame(height: 280)
            Divider()
            HStack {
                Text("\(vm.targets.count) seçili · \(vm.rows.filter { prefs.isProtected($0) }.count) korunan")
                    .font(.caption).foregroundColor(.secondary)
                Spacer()
                Menu {
                    Button("Ayarlar…") { NotificationCenter.default.post(name: .openPreferencesRequested, object: nil) }
                    if prefs.includeTrashInList { Button("Çöp Kutusunu Boşalt…") { quit.emptyTrash() } }
                    Button("Yardım") { NSWorkspace.shared.open(URL(string: "https://github.com/BeNKaYS/KillBill#readme")!) }
                    Divider()
                    Button("KillBill'den Çık") { NSApp.terminate(nil) }
                } label: { Image(systemName: "gearshape") }
                .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("KillBill menüsü")
            }
            Button {
                quit.quit(entries: vm.targets, force: vm.effectiveForce)
            } label: {
                Label("Seçilen \(vm.targets.count) uygulamayı \(vm.effectiveForce ? "zorla kapat" : "kapat")",
                      systemImage: vm.effectiveForce ? "bolt.fill" : "power")
                    .frame(maxWidth: .infinity).padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.effectiveForce ? .red : accent)
            .disabled(vm.targets.isEmpty || quit.isBusy)

            if !quit.statusMessage.isEmpty {
                Text(quit.statusMessage).font(.caption).frame(maxWidth: .infinity, alignment: .leading)
                if !quit.results.isEmpty {
                    DisclosureGroup("İşlem ayrıntıları") {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(quit.results) { result in
                                    Text("\(result.name): \(result.state.rawValue)").font(.caption)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }.frame(maxHeight: 80)
                    }.font(.caption)
                }
            } else if !prefs.disableTips {
                Text("Option: zorla kapat · Kilit: toplu kapatmadan koru")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding(14).frame(width: 380)
        .background(VisualEffectView())
        .onAppear { vm.syncSelection(); vm.beginObservingKeys() }
        .onDisappear { vm.endObservingKeys() }
    }

    private func reveal(_ entry: AppEntry) {
        if let url = apps.runningApplication(pid: entry.id)?.bundleURL { NSWorkspace.shared.activateFileViewerSelecting([url]) }
    }
}

struct CheckBox: View {
    @Binding var isOn: Bool
    var body: some View {
        Toggle("Seç", isOn: $isOn).labelsHidden().toggleStyle(.checkbox)
    }
}
