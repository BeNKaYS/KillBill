import AppKit
import Foundation

// MARK: - İzinler (Apple Events / Automation ve Accessibility)

final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var automationGranted: Bool = false

    private init() {
        automationGranted = PermissionsManager.probeAutomationQuiet()
    }

    // MARK: Automation (Apple Events)
    /// Sessizce Apple Events iznini yoklar (istem göstermez).
    ///
    /// Hedef **Finder** olmalı: KillBill'in gerçekten kullandığı hedef bu.
    /// "System Events" ayrı bir TCC kaydıdır ve izin verilmiş olsa bile
    /// orada -1743 dönebilir; bu yüzden kontrol Finder üzerinden yapılır.
    private static func probeAutomationQuiet() -> Bool {
        let src = """
        tell application "Finder"
            return name of startup disk
        end tell
        """
        var error: NSDictionary?
        _ = NSAppleScript(source: src)?.executeAndReturnError(&error)
        guard let error else { return true }   // hata yok → izin var
        let code = error[NSAppleScript.errorNumber] as? Int
        // -1743: kullanıcı izin vermedi · -600: Finder çalışmıyor (izin durumu belirsiz)
        if code == -1743 { return false }
        if code == -600 { return true }
        return true
    }

    /// Apple Events iznini talep eder (gerekirse TCC istemini tetikler).
    func requestAutomation(completion: ((Bool) -> Void)? = nil) {
        let src = """
        tell application "Finder"
            if running then
                return name of startup disk
            else
                return "not running"
            end if
        end tell
        """
        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let script = NSAppleScript(source: src)
            _ = script?.executeAndReturnError(&error)
            let denied = (error?[NSAppleScript.errorNumber] as? Int) == -1743
            DispatchQueue.main.async {
                self.automationGranted = !denied
                completion?(self.automationGranted)
            }
        }
    }

    /// AppleScript kaynağını çalıştırır (Finder kapatma / çöp boşaltma için).
    @discardableResult
    func runAppleScript(_ source: String) -> NSDictionary? {
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error, let code = error[NSAppleScript.errorNumber] as? Int, code == -1743 {
            DispatchQueue.main.async { self.automationGranted = false }
            openAutomationSettings()
        }
        return error
    }

    // MARK: Sistem Ayarları kısayolları
    func openAutomationSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")
    }

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }
    }

    func refresh() {
        automationGranted = PermissionsManager.probeAutomationQuiet()
    }
}
