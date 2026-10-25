import AppKit
import Carbon.HIToolbox

// MARK: - Global kısayollar (Carbon RegisterEventHotKey — Accessibility izni gerektirmez)

final class HotkeyManager {
    static let shared = HotkeyManager()

    enum Action: UInt32 {
        case activate = 1
        case quitAll = 2
        case forceQuitAll = 3
    }

    var onActivate: (() -> Void)?
    var onQuitAll: (() -> Void)?
    var onForceQuitAll: (() -> Void)?

    private var refs: [EventHotKeyRef?] = []
    private var handlerRef: EventHandlerRef?
    private static var instance: HotkeyManager?

    private init() {
        HotkeyManager.instance = self
        installHandler()
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                               name: .hotkeysDidChange, object: nil)
    }

    private func installHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (_, event, _) -> OSStatus in
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let action = hkID.id
            DispatchQueue.main.async {
                guard let mgr = HotkeyManager.instance else { return }
                switch action {
                case Action.activate.rawValue:     mgr.onActivate?()
                case Action.quitAll.rawValue:       mgr.onQuitAll?()
                case Action.forceQuitAll.rawValue:  mgr.onForceQuitAll?()
                default: break
                }
            }
            return noErr
        }, 1, &eventType, nil, &handlerRef)
    }

    @objc func reload() {
        unregisterAll()
        let prefs = PreferencesManager.shared
        if prefs.shortcutActivateEnabled, prefs.shortcutActivate.keyCode != 0 {
            register(.activate, combo: prefs.shortcutActivate)
        }
        if prefs.shortcutQuitEnabled, prefs.shortcutQuit.keyCode != 0 {
            register(.quitAll, combo: prefs.shortcutQuit)
        }
        if prefs.shortcutForceQuitEnabled, prefs.shortcutForceQuit.keyCode != 0 {
            register(.forceQuitAll, combo: prefs.shortcutForceQuit)
        }
    }

    private func register(_ action: Action, combo: ShortcutCombo) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4B42_4C42), id: action.rawValue) // 'KBLB'
        let status = RegisterEventHotKey(UInt32(combo.keyCode), UInt32(combo.modifiers),
                                         hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr { refs.append(ref) }
        else { NSLog("KillBill: kısayol kaydedilemedi (\(action)): \(status)") }
    }

    private func unregisterAll() {
        for r in refs { if let r { UnregisterEventHotKey(r) } }
        refs.removeAll()
    }
}
