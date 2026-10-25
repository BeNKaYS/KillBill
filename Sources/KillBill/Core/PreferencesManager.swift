import Foundation
import Combine
import ServiceManagement

// MARK: - Ayarlar (QuitAll ile birebir aynı UserDefaults anahtarları)

enum QuitOption: String, CaseIterable, Identifiable {
    case normal = "Quit"
    case force = "Force Quit"
    var id: String { rawValue }
    var label: String { self == .normal ? "Normal kapat" : "Zorla kapat" }
    var symbol: String { self == .normal ? "power" : "bolt.fill" }
}

enum AppsSort: String, CaseIterable, Identifiable {
    case alphabetical = "0"
    case cpuUsage = "1"
    var id: String { rawValue }
    var label: String { self == .cpuUsage ? "CPU Kullanımı" : "Alfabetik" }
    var symbol: String { self == .cpuUsage ? "arrow.up.arrow.down" : "textformat.abc" }
}

enum InactiveUnit: String, CaseIterable, Identifiable {
    case minute = "Min"
    case hour = "Hour"
    case day = "Day"
    var id: String { rawValue }
    var label: String {
        switch self {
        case .minute: return "Dk"
        case .hour: return "Saat"
        case .day: return "Gün"
        }
    }
}

struct ShortcutCombo: Equatable {
    var keyCode: UInt32 = 0
    var modifiers: UInt32 = 0
    var enabled: Bool = true

    var displayString: String {
        var parts: [String] = []
        if modifiers & 0x1000 != 0 { parts.append("⌃") }   // control
        if modifiers & 0x0800 != 0 { parts.append("⌥") }   // option
        if modifiers & 0x0100 != 0 { parts.append("⇧") }   // shift
        if modifiers & 0x0100 != 0 || modifiers & 0x0000 == 0 {}
        if modifiers & 0x1000 != 0 || modifiers & 0x2000 != 0 {}
        // cmd = 0x0100 in NSEvent terms for our storage; normalized below
        return parts.joined()
    }
}

// MARK: - PreferencesManager

final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    private let d = UserDefaults.standard

    // QuitAll UserDefaults anahtarları
    private enum Key {
        static let playSound            = "kUserdefaultsPlaySound"
        static let groupBackgroundApps  = "kUserdefaultsGroupBackgroundApps"
        static let showBackgroundApps   = "kUserdefaultsShowBackgroundApps"
        static let deselectApps         = "kUserdefaultsDeselectApps"
        static let disableTips          = "kUserdefaultsDisableTips"
        static let quitOption           = "kUserdefaultsQuitOption"
        static let menuAppsSort         = "kUserdefaultsMenuAppsSort"
        static let quitInactiveAfter    = "kUserdefaultsQuitInactiveAppsAfter"
        static let shortcutActivate     = "kUserdefaultsShortcutActivate"
        static let shortcutQuit         = "kUserdefaultsShortcutQuit"
        static let shortcutForceQuit    = "kUserdefaultsShortcutForceQuit"
        static let includeFinder        = "includeFinderInList"
        static let includeTrash         = "includeTrashInList"
        static let skipMusicApps        = "skipAutoclosingMusicApps"
        static let useSystemColor       = "kUserdefaultsUseSystemColor"
        static let statusIconStyle      = "kUserdefaultsStatusIconStyle"
        // Güncelleme
        static let updateSourceKind     = "kUserdefaultsUpdateSourceKind"
        static let updateLocalPath      = "kUserdefaultsUpdateLocalPath"
        static let updateGitHubRepo     = "kUserdefaultsUpdateGitHubRepo"
        static let updateGitHubMode     = "kUserdefaultsUpdateGitHubMode"
        static let updateBranch         = "kUserdefaultsUpdateBranch"
    }

    // MARK: Yayınlanan değerler
    @Published var playSounds: Bool            { didSet { d.set(playSounds, forKey: Key.playSound) } }
    @Published var groupBackgroundApps: Bool   { didSet { d.set(groupBackgroundApps, forKey: Key.groupBackgroundApps) } }
    @Published var showBackgroundApps: Bool    { didSet { d.set(showBackgroundApps, forKey: Key.showBackgroundApps) } }
    @Published var deselectApps: Bool          { didSet { d.set(deselectApps, forKey: Key.deselectApps) } }
    @Published var disableTips: Bool           { didSet { d.set(disableTips, forKey: Key.disableTips) } }
    @Published var quitOption: QuitOption      { didSet { d.set(quitOption.rawValue, forKey: Key.quitOption) } }
    @Published var sortOption: AppsSort        { didSet { d.set(sortOption.rawValue, forKey: Key.menuAppsSort) } }
    @Published var includeFinderInList: Bool   { didSet { d.set(includeFinderInList ? 1 : 0, forKey: Key.includeFinder) } }
    @Published var includeTrashInList: Bool    { didSet { d.set(includeTrashInList ? 1 : 0, forKey: Key.includeTrash) } }
    @Published var openAtLogin: Bool           { didSet { applyLoginItem() } }
    @Published var useSystemColor: Bool        { didSet { d.set(useSystemColor, forKey: Key.useSystemColor) } }
    @Published var statusIconStyle: StatusIconStyle { didSet { d.set(statusIconStyle.rawValue, forKey: Key.statusIconStyle) } }

    // Güncelleme kaynağı
    @Published var updateSourceKind: UpdateSourceKind { didSet { d.set(updateSourceKind.rawValue, forKey: Key.updateSourceKind) } }
    @Published var updateLocalPath: String          { didSet { d.set(updateLocalPath, forKey: Key.updateLocalPath) } }
    @Published var updateGitHubRepo: String         { didSet { d.set(updateGitHubRepo, forKey: Key.updateGitHubRepo) } }
    @Published var updateGitHubMode: GitHubUpdateMode { didSet { d.set(updateGitHubMode.rawValue, forKey: Key.updateGitHubMode) } }
    @Published var updateBranch: String             { didSet { d.set(updateBranch, forKey: Key.updateBranch) } }

    // Otomatik çık (inactive)
    @Published var autoQuitEnabled: Bool       { didSet { saveInactive() } }
    @Published var autoQuitMinutes: Int        { didSet { saveInactive() } }
    @Published var autoQuitUnit: InactiveUnit  { didSet { saveInactive() } }

    // Kısayollar
    @Published var shortcutActivateEnabled: Bool  { didSet { saveShortcut(.activate) } }
    @Published var shortcutQuitEnabled: Bool      { didSet { saveShortcut(.quitAll) } }
    @Published var shortcutForceQuitEnabled: Bool { didSet { saveShortcut(.forceQuitAll) } }
    @Published var shortcutActivate: ShortcutCombo  { didSet { saveShortcut(.activate) } }
    @Published var shortcutQuit: ShortcutCombo      { didSet { saveShortcut(.quitAll) } }
    @Published var shortcutForceQuit: ShortcutCombo { didSet { saveShortcut(.forceQuitAll) } }

    private init() {
        playSounds           = d.object(forKey: Key.playSound) as? Bool ?? true
        groupBackgroundApps  = d.object(forKey: Key.groupBackgroundApps) as? Bool ?? true
        showBackgroundApps   = d.object(forKey: Key.showBackgroundApps) as? Bool ?? false
        deselectApps         = d.object(forKey: Key.deselectApps) as? Bool ?? false
        disableTips          = d.object(forKey: Key.disableTips) as? Bool ?? false

        let qo = d.string(forKey: Key.quitOption) ?? QuitOption.force.rawValue
        quitOption = QuitOption(rawValue: qo) ?? .force

        let so = d.string(forKey: Key.menuAppsSort) ?? AppsSort.cpuUsage.rawValue
        sortOption = AppsSort(rawValue: so) ?? .cpuUsage

        includeFinderInList = (d.object(forKey: Key.includeFinder) as? Int ?? 0) == 1
        includeTrashInList  = (d.object(forKey: Key.includeTrash) as? Int ?? 0) == 1
        useSystemColor      = d.object(forKey: Key.useSystemColor) as? Bool ?? true
        statusIconStyle     = StatusIconStyle(rawValue: d.string(forKey: Key.statusIconStyle) ?? "") ?? .ringSlash
        updateSourceKind    = UpdateSourceKind(rawValue: d.string(forKey: Key.updateSourceKind) ?? "") ?? .github
        updateLocalPath     = d.string(forKey: Key.updateLocalPath) ?? NSHomeDirectory() + "/Desktop/Dev_Folder/KillBill"
        updateGitHubRepo    = d.string(forKey: Key.updateGitHubRepo) ?? "BeNKaYS/KillBill"
        updateGitHubMode    = GitHubUpdateMode(rawValue: d.string(forKey: Key.updateGitHubMode) ?? "") ?? .release
        updateBranch        = d.string(forKey: Key.updateBranch) ?? "main"

        let inactive = PreferencesManager.decodeInactive(d.string(forKey: Key.quitInactiveAfter))
        autoQuitEnabled = inactive.enabled
        autoQuitMinutes = inactive.minutes
        autoQuitUnit    = inactive.unit

        let sa = PreferencesManager.decodeShortcut(d.string(forKey: Key.shortcutActivate))
        let sq = PreferencesManager.decodeShortcut(d.string(forKey: Key.shortcutQuit))
        let sf = PreferencesManager.decodeShortcut(d.string(forKey: Key.shortcutForceQuit))
        shortcutActivate  = sa.combo; shortcutActivateEnabled  = sa.enabled
        shortcutQuit      = sq.combo; shortcutQuitEnabled      = sq.enabled
        shortcutForceQuit = sf.combo; shortcutForceQuitEnabled = sf.enabled

        openAtLogin = PreferencesManager.currentLoginItemEnabled()
        d.set(false, forKey: Key.skipMusicApps) // bilgi: müzik uygulamalarını atlama (QuitAll varsayılanı kapalı)
    }

    // MARK: Reset
    func resetAll() {
        let skip = d.object(forKey: Key.skipMusicApps) as? Int ?? 0
        for k in [Key.playSound, Key.groupBackgroundApps, Key.showBackgroundApps, Key.deselectApps,
                  Key.disableTips, Key.quitOption, Key.menuAppsSort, Key.quitInactiveAfter,
                  Key.shortcutActivate, Key.shortcutQuit, Key.shortcutForceQuit,
                  Key.includeFinder, Key.includeTrash, Key.statusIconStyle,
                  Key.updateSourceKind, Key.updateLocalPath, Key.updateGitHubRepo,
                  Key.updateGitHubMode, Key.updateBranch] {
            d.removeObject(forKey: k)
        }
        d.set(skip, forKey: Key.skipMusicApps)

        playSounds = true
        groupBackgroundApps = true
        showBackgroundApps = false
        deselectApps = false
        disableTips = false
        quitOption = .force
        sortOption = .cpuUsage
        includeFinderInList = false
        includeTrashInList = false
        statusIconStyle = .ringSlash
        updateSourceKind = .github
        autoQuitEnabled = false; autoQuitMinutes = 15; autoQuitUnit = .minute
        shortcutActivateEnabled = true;  shortcutQuitEnabled = true;  shortcutForceQuitEnabled = true
        shortcutActivate =  ShortcutCombo(keyCode: 0, modifiers: 0, enabled: true)
        shortcutQuit =      ShortcutCombo(keyCode: 0, modifiers: 0, enabled: true)
        shortcutForceQuit = ShortcutCombo(keyCode: 0, modifiers: 0, enabled: true)
    }

    // MARK: Login item
    private func applyLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if openAtLogin { try SMAppService.mainApp.register() }
                else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("KillBill: launch at login değiştirilemedi: \(error.localizedDescription)")
            }
        }
    }

    private static func currentLoginItemEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    // MARK: (De)serializasyon yardımcıları
    enum ShortcutKind { case activate, quitAll, forceQuitAll }

    private func saveShortcut(_ kind: ShortcutKind) {
        let (key, combo, enabled): (String, ShortcutCombo, Bool) = {
            switch kind {
            case .activate:  return (Key.shortcutActivate, shortcutActivate, shortcutActivateEnabled)
            case .quitAll:   return (Key.shortcutQuit, shortcutQuit, shortcutQuitEnabled)
            case .forceQuitAll: return (Key.shortcutForceQuit, shortcutForceQuit, shortcutForceQuitEnabled)
            }
        }()
        var c = combo; c.enabled = enabled
        let dict: [String: Any] = ["keyCode": Int(c.keyCode), "modifiers": Int(c.modifiers), "enabled": enabled, "deleted": false]
        if let data = try? JSONSerialization.data(withJSONObject: dict), let str = String(data: data, encoding: .utf8) {
            d.set(str, forKey: key)
        }
        NotificationCenter.default.post(name: .hotkeysDidChange, object: nil)
    }

    private static func decodeShortcut(_ raw: String?) -> (combo: ShortcutCombo, enabled: Bool) {
        guard let raw, let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (ShortcutCombo(), true)
        }
        let keyCode = UInt32(obj["keyCode"] as? Int ?? 0)
        let mods = UInt32(obj["modifiers"] as? Int ?? 0)
        let enabled = obj["enabled"] as? Bool ?? true
        return (ShortcutCombo(keyCode: keyCode, modifiers: mods, enabled: enabled), enabled)
    }

    private func saveInactive() {
        let dict: [String: Any] = ["enabled": autoQuitEnabled, "minutes": autoQuitMinutes, "unit": autoQuitUnit.rawValue]
        if let data = try? JSONSerialization.data(withJSONObject: dict), let str = String(data: data, encoding: .utf8) {
            d.set(str, forKey: Key.quitInactiveAfter)
        }
    }

    private static func decodeInactive(_ raw: String?) -> (enabled: Bool, minutes: Int, unit: InactiveUnit) {
        guard let raw, let data = raw.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (false, 15, .minute)
        }
        return (obj["enabled"] as? Bool ?? false,
                obj["minutes"] as? Int ?? 15,
                InactiveUnit(rawValue: obj["unit"] as? String ?? "Min") ?? .minute)
    }
}

extension Notification.Name {
    static let hotkeysDidChange = Notification.Name("KillBill.hotkeysDidChange")
}
