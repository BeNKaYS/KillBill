import AppKit

// KillBill — QuitAll uygulamasının menü çubuğu (LSUIElement) klonu.
// Giriş noktası: NSApplication'ı elle kurup AppDelegate'i bağlarız.
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
