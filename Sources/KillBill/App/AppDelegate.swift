import AppKit
import SwiftUI
import Combine

extension NSApplication {
    func bringForward() {
        if #available(macOS 14.0, *) { self.activate() }
        else { self.activate(ignoringOtherApps: true) }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var prefsWindow: NSWindow?
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menü çubuğu öğesi
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = PreferencesManager.shared.statusIconStyle.makeImage()
            button.image?.isTemplate = true
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Menü çubuğu simgesi ayarlardan değişince anında güncelle
        PreferencesManager.shared.$statusIconStyle
            .receive(on: RunLoop.main)
            .sink { [weak self] style in
                self?.statusItem.button?.image = style.makeImage()
                self?.statusItem.button?.image?.isTemplate = true
            }
            .store(in: &cancellables)

        // Popover (panel)
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 480)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuPanelView())

        // İzleyiciler
        RunningAppsManager.shared.startMonitoring()
        HotkeyManager.shared.reload()
        HotkeyManager.shared.onActivate = { [weak self] in self?.showPopover() }
        HotkeyManager.shared.onQuitAll = { QuitService.shared.quitAll(force: false) }
        HotkeyManager.shared.onForceQuitAll = { QuitService.shared.quitAll(force: true) }

        // İlk çalıştırma hoş geldin / izin istekleri
        NotificationCenter.default.addObserver(self, selector: #selector(openPreferences),
                                               name: .openPreferencesRequested, object: nil)

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if self?.popover.isShown == true { self?.closePopover() }
        }

        // Gerekli izinleri iste (ilk fırsatta)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            PermissionsManager.shared.refresh()
        }

        // Kullanıcı Sistem Ayarları'ndan izin verip uygulamaya döndüğünde
        // durumu hemen tazele (izin verilmişse "Verildi" görünsün).
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            PermissionsManager.shared.refresh()
        }

        // Test: KILLBILL_SHOW_PANEL=1 ile başlatılırsa paneli otomatik aç
        if ProcessInfo.processInfo.environment["KILLBILL_SHOW_PANEL"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.showPopover() }
        }
        // Test: KILLBILL_SHOW_PREFS=1 ile başlatılırsa ayarları otomatik aç
        if ProcessInfo.processInfo.environment["KILLBILL_SHOW_PREFS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in self?.openPreferences() }
        }
    }

    // MARK: Popover
    @objc private func togglePopover() {
        popover.isShown ? closePopover() : showPopover()
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        RunningAppsManager.shared.refresh()
        NSApp.bringForward()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func closePopover() { popover.performClose(nil) }

    // MARK: Tercihler penceresi
    @objc func openPreferences() {
        closePopover()
        if let w = prefsWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.bringForward()
            return
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false)
        window.title = "KillBill"
        window.contentViewController = NSHostingController(rootView: PreferencesView())
        window.isReleasedWhenClosed = false
        window.center()
        prefsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.bringForward()
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        if let m = eventMonitor { NSEvent.removeMonitor(m) }
        RunningAppsManager.shared.stopMonitoring()
    }

    // MARK: Menü çubuğu ikonu
    // Simgeler artık StatusIconStyle içinde üretiliyor; burası eski çağrılar için kısayol.
    static func makeStatusIcon(_ style: StatusIconStyle = .ringSlash) -> NSImage {
        style.makeImage()
    }
}
