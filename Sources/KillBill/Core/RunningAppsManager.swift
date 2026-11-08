import AppKit
import Foundation

// MARK: - Uygulama Girdisi (QuitAll'daki AppEntry karşılığı)

struct AppEntry: Identifiable, Equatable {
    let id: Int32          // pid
    var name: String
    var bundleID: String?
    var icon: NSImage?
    var cpu: Double        // yüzde
    var isBackground: Bool
    var isTerminated: Bool
    var memberPIDs: [Int32] = []
    var processIDs: [Int32] { memberPIDs.isEmpty ? [id] : memberPIDs }

    static func == (l: AppEntry, r: AppEntry) -> Bool { l.id == r.id }

    /// Aynı uygulamanın birden fazla kopyası (grup) için eşitlik anahtarı
    var groupKey: String { bundleID ?? name }
}

// MARK: - RunningAppsManager

final class RunningAppsManager: ObservableObject {
    static let shared = RunningAppsManager()

    @Published private(set) var apps: [AppEntry] = []

    private let psQueue = DispatchQueue(label: "com.benkays.killbill.ps", qos: .utility)
    private var timer: Timer?
    private let ownPID = ProcessInfo.processInfo.processIdentifier
    private var lastCPU: [Int32: Double] = [:]
    private var sampling = false
    private var observers: [NSObjectProtocol] = []

    // MARK: Tarama
    func refresh(cpu: [Int32: Double]? = nil) {
        if let cpu { lastCPU = cpu }
        var list: [AppEntry] = []
        for app in NSWorkspace.shared.runningApplications {
            guard app.processIdentifier != ownPID,
                  app.isTerminated == false,
                  app.localizedName != nil,
                  app.activationPolicy != .prohibited || app.bundleIdentifier != nil else { continue }
            guard app.bundleIdentifier != nil || app.bundleURL != nil else { continue }

            let bg = app.activationPolicy != .regular
            let entry = AppEntry(
                id: app.processIdentifier,
                name: app.localizedName ?? "?",
                bundleID: app.bundleIdentifier,
                icon: app.icon,
                cpu: lastCPU[app.processIdentifier] ?? 0,
                isBackground: bg,
                isTerminated: app.isTerminated
            )
            list.append(entry)
        }
        self.apps = list
        lastCPU = lastCPU.filter { key, _ in list.contains { $0.id == key } }
    }

    /// `ps` üzerinden CPU yüzdelerini toplar (arka planda)
    func sampleCPU(completion: @escaping ([Int32: Double]) -> Void) {
        psQueue.async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/bin/ps")
            p.arguments = ["-Ao", "pid=,pcpu="]
            let pipe = Pipe(); p.standardOutput = pipe
            var result: [Int32: Double] = [:]
            do {
                try p.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                if let out = String(data: data, encoding: .utf8) {
                    for line in out.split(separator: "\n") {
                        let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                        if parts.count >= 2, let pid = Int32(parts[0]), let cpu = Double(parts[1]) {
                            result[pid] = cpu
                        }
                    }
                }
            } catch { /* yoksay */ }
            DispatchQueue.main.async { completion(result) }
        }
    }

    func startMonitoring(interval: TimeInterval = 2.0) {
        if observers.isEmpty {
            for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
                observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.refresh() })
            }
        }
        refresh()
    }

    func setPanelVisible(_ visible: Bool) {
        timer?.invalidate(); timer = nil
        guard visible else { return }
        sampleAndRefresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.sampleAndRefresh()
        }
    }

    func stopMonitoring() {
        setPanelVisible(false)
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
    }

    private func sampleAndRefresh() {
        guard !sampling else { return }
        sampling = true
        sampleCPU { [weak self] cpu in self?.sampling = false; self?.refresh(cpu: cpu) }
    }

    // MARK: Pano için sıralanmış liste
    func panelList(search: String) -> [AppEntry] {
        Self.filtered(apps, preferences: .shared, search: search)
    }

    static func filtered(_ apps: [AppEntry], preferences prefs: PreferencesManager, search: String) -> [AppEntry] {
        var list = apps.filter { prefs.includeFinderInList || $0.bundleID != "com.apple.finder" }
        if !prefs.showBackgroundApps { list = list.filter { !$0.isBackground } }
        if prefs.groupBackgroundApps {
            let groups = Dictionary(grouping: list.filter(\.isBackground), by: \.groupKey)
            list = list.filter { !$0.isBackground } + groups.values.map { members in
                var entry = members.sorted { $0.id < $1.id }.first!
                entry.memberPIDs = members.flatMap(\.processIDs)
                entry.cpu = members.reduce(0) { $0 + $1.cpu }
                if members.count > 1 { entry.name += " (\(members.count))" }
                return entry
            }
        }
        if !search.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(search) }
        }
        switch prefs.sortOption {
        case .cpuUsage:     list.sort { $0.cpu > $1.cpu }
        case .alphabetical: list.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }
        return list
    }

    // MARK: Çıkarma işlemleri
    @discardableResult
    func quit(pid: Int32) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return false }
        return app.terminate()
    }

    @discardableResult
    func forceQuit(pid: Int32) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return false }
        return app.forceTerminate()
    }

    func unhide(pid: Int32) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        if #available(macOS 14.0, *) { app.activate() } else { app.activate(options: [.activateIgnoringOtherApps]) }
    }

    func runningApplication(pid: Int32) -> NSRunningApplication? { NSRunningApplication(processIdentifier: pid) }
}
