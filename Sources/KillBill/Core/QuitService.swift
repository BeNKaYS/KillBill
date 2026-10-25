import AppKit
import Foundation

extension Notification.Name {
    static let openPreferencesRequested = Notification.Name("KillBill.openPreferences")
    static let appsDidQuit = Notification.Name("KillBill.appsDidQuit")
}

// MARK: - Çıkarma servisi (QuitAll davranışını merkezîleştirir)

final class QuitService {
    static let shared = QuitService()

    /// Sonuç bildirimi için özet
    struct Result { var count: Int; var force: Bool }

    @discardableResult
    func quit(entries: [AppEntry], force: Bool) -> Int {
        var done = 0
        for e in entries {
            let ok = force ? RunningAppsManager.shared.forceQuit(pid: e.id)
                           : RunningAppsManager.shared.quit(pid: e.id)
            if ok { done += 1 }
        }
        if done > 0 {
            done > 1 ? SoundPlayer.shared.playAll() : SoundPlayer.shared.playSingle()
            NotificationCenter.default.post(name: .appsDidQuit,
                                            object: Result(count: done, force: force))
        }
        RunningAppsManager.shared.refresh()
        return done
    }

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
