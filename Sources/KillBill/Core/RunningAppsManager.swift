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

    // MARK: Tarama
    func refresh(cpu: [Int32: Double] = [:]) {
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
                cpu: cpu[app.processIdentifier] ?? 0,
                isBackground: bg,
                isTerminated: app.isTerminated
            )
            list.append(entry)
        }
        self.apps = list
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
        sampleAndRefresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.sampleAndRefresh()
        }
    }

    func stopMonitoring() { timer?.invalidate(); timer = nil }

    private func sampleAndRefresh() {
        sampleCPU { [weak self] cpu in self?.refresh(cpu: cpu) }
    }

    // MARK: Pano için sıralanmış liste
    func panelList(search: String) -> [AppEntry] {
        let prefs = PreferencesManager.shared
        var list = apps
        if !prefs.showBackgroundApps { list = list.filter { !$0.isBackground } }
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
