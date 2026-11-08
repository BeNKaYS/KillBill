import AppKit
import Foundation

extension Notification.Name {
    static let openPreferencesRequested = Notification.Name("KillBill.openPreferences")
    static let appsDidQuit = Notification.Name("KillBill.appsDidQuit")
}

// MARK: - Çıkarma servisi (QuitAll davranışını merkezîleştirir)

final class QuitService: ObservableObject {
    static let shared = QuitService()

    enum State: String { case waiting = "Yanıt bekleniyor", closed = "Kapandı", failed = "Kapatılamadı", timedOut = "Hâlâ açık" }
    struct Outcome: Identifiable {
        let id: Int32
        let name: String
        var state: State
    }
    @Published private(set) var results: [Outcome] = []
    @Published private(set) var statusMessage = ""
    private let preferences: PreferencesManager
    private let terminate: (Int32, Bool) -> Bool
    private let isRunning: (Int32) -> Bool
    private let confirmForce: ([AppEntry]) -> Bool
    private var timer: Timer?
    private var deadline = Date.distantPast
    var isBusy: Bool { results.contains { $0.state == .waiting } }

    init(preferences: PreferencesManager = .shared,
         terminate: @escaping (Int32, Bool) -> Bool = { pid, force in
             guard let app = NSRunningApplication(processIdentifier: pid) else { return false }
             return force ? app.forceTerminate() : app.terminate()
         },
         isRunning: @escaping (Int32) -> Bool = { NSRunningApplication(processIdentifier: $0)?.isTerminated == false },
         confirmForce: @escaping ([AppEntry]) -> Bool = QuitService.askForceConfirmation) {
        self.preferences = preferences
        self.terminate = terminate
        self.isRunning = isRunning
        self.confirmForce = confirmForce
    }

    private static func askForceConfirmation(_ entries: [AppEntry]) -> Bool {
        let alert = NSAlert()
        alert.messageText = "\(entries.count) uygulama zorla kapatılsın mı?"
        alert.informativeText = entries.map(\.name).joined(separator: ", ") + "\nKaydedilmemiş değişiklikler kaybolabilir."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Vazgeç")
        alert.addButton(withTitle: "Zorla Kapat")
        NSApp.bringForward()
        return alert.runModal() == .alertSecondButtonReturn
    }

    /// Sonuç bildirimi için özet
    struct Result { var count: Int; var force: Bool }

    @discardableResult
    func quit(entries: [AppEntry], force: Bool) -> Int {
        guard !isBusy else { return 0 }
        let targets = entries.filter { !preferences.isProtected($0) }
        guard !targets.isEmpty else { statusMessage = "Kapatılacak uygulama yok; korunan uygulamalar atlandı."; return 0 }
        guard !force || confirmForce(targets) else { return 0 }
        var seen = Set<Int32>()
        results = targets.flatMap { entry -> [Outcome] in
            entry.processIDs.compactMap { pid in
                guard seen.insert(pid).inserted else { return nil }
                let state: State = !isRunning(pid) ? .closed : (terminate(pid, force) ? .waiting : .failed)
                return Outcome(id: pid, name: entry.name, state: state)
            }
        }
        deadline = Date().addingTimeInterval(15)
        refreshPending()
        timer?.invalidate()
        if isBusy {
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.refreshPending() }
        }
        return results.filter { $0.state == .waiting || $0.state == .closed }.count
    }

    func refreshPending(now: Date = Date()) {
        let previousClosed = results.filter { $0.state == .closed }.count
        results = results.map { outcome in
            var next = outcome
            if next.state == .waiting {
                if !isRunning(next.id) { next.state = .closed }
                else if now >= deadline { next.state = .timedOut }
            }
            return next
        }
        let closed = results.filter { $0.state == .closed }.count
        if closed > previousClosed, preferences.playSounds {
            closed - previousClosed > 1 ? SoundPlayer.shared.playAll() : SoundPlayer.shared.playSingle()
        }
        let waiting = results.filter { $0.state == .waiting }.count
        let failed = results.count - closed - waiting
        statusMessage = "\(closed) kapandı" + (waiting > 0 ? " · \(waiting) yanıt bekliyor" : "") + (failed > 0 ? " · \(failed) kapanmadı" : "")
        if !isBusy { timer?.invalidate(); timer = nil }
    }

    deinit { timer?.invalidate() }

    func quitAll(force: Bool) {
        let list = RunningAppsManager.shared.panelList(search: "")
        quit(entries: list, force: force)
    }

    // MARK: Finder / Çöp (Apple Events gerektirir)
    func quitFinder() {
        PermissionsManager.shared.runAppleScript("tell application \"Finder\" to quit")
    }

    func emptyTrash() {
        PermissionsManager.shared.runAppleScript("""
        tell application "Finder"
            try
                empty the trash
            end try
        end tell
        """)
    }
}
