import SwiftUI
import AppKit
import Carbon.HIToolbox

/// Kısayol kaydedici (QuitAll'daki ShortcutRecorderView karşılığı)
struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var combo: ShortcutCombo
    var onChange: () -> Void

    func makeNSView(context: Context) -> RecorderNSView {
        let v = RecorderNSView()
        v.onCapture = { keyCode, mods in
            combo = ShortcutCombo(keyCode: keyCode, modifiers: mods, enabled: combo.enabled)
            onChange()
        }
        v.combo = combo
        return v
    }

    func updateNSView(_ nsView: RecorderNSView, context: Context) {
        nsView.combo = combo
        nsView.needsDisplay = true
    }

    final class RecorderNSView: NSView {
        var onCapture: ((UInt32, UInt32) -> Void)?
        var combo = ShortcutCombo() { didSet { needsDisplay = true } }
        private var recording = false

        override var acceptsFirstResponder: Bool { true }
        override var canBecomeKeyView: Bool { true }

        override func draw(_ dirtyRect: NSRect) {
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
            (recording ? NSColor.controlAccentColor.withAlphaComponent(0.25) : NSColor.controlBackgroundColor).setFill()
            path.fill()
            NSColor.separatorColor.setStroke()
            path.lineWidth = 1
            path.stroke()

            let text = recording ? "Tuşlara basın…" : KeyCodeFormatter.string(for: combo)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.labelColor
            ]
            let size = (text as NSString).size(withAttributes: attrs)
            let point = NSPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
            (text as NSString).draw(at: point, withAttributes: attrs)
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
            recording = true
            needsDisplay = true
        }

        override func keyDown(with event: NSEvent) {
            guard recording else { super.keyDown(with: event); return }
            // Sadece modifier basıldıysa bekle
            if event.keyCode == 0 { return }
            recording = false
            onCapture?(UInt32(event.keyCode), KeyCodeFormatter.carbonModifiers(from: event.modifierFlags))
            needsDisplay = true
        }

        override func resignFirstResponder() -> Bool {
            recording = false
            needsDisplay = true
            return true
        }
    }
}

enum KeyCodeFormatter {
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.option)  { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        if flags.contains(.shift)   { m |= UInt32(shiftKey) }
        return m
    }

    static func string(for combo: ShortcutCombo) -> String {
        if combo.keyCode == 0 { return "Kayıt yok" }
        var s = ""
        if combo.modifiers & UInt32(controlKey) != 0 { s += "⌃" }
        if combo.modifiers & UInt32(optionKey)  != 0 { s += "⌥" }
        if combo.modifiers & UInt32(shiftKey)   != 0 { s += "⇧" }
        if combo.modifiers & UInt32(cmdKey)     != 0 { s += "⌘" }
        s += keyName(UInt32(combo.keyCode))
        return s
    }

    static func keyName(_ keyCode: UInt32) -> String {
        let map: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7",
            27: "-", 28: "8", 29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N",
            46: "M", 47: ".", 50: "`", 36: "⏎", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
            96: "F5", 97: "F6", 98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11",
            105: "F13", 107: "F14", 109: "F10", 111: "F12", 114: "Help", 115: "↖", 116: "⇞",
            117: "⌦", 118: "F4", 119: "↘", 120: "F2", 121: "⇟", 122: "F1", 123: "←", 124: "→",
            125: "↓", 126: "↑"
        ]
        return map[keyCode] ?? "#\(keyCode)"
    }
}
