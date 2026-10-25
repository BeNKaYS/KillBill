import AppKit
import Foundation

// MARK: - Ses efektleri (QuitAll: "quit-all.aiff" / "quit-single.aiff")

final class SoundPlayer {
    static let shared = SoundPlayer()

    private var quitSingle: NSSound?
    private var quitAll: NSSound?

    private init() {
        if let url = Bundle.main.url(forResource: "quit-single", withExtension: "aiff") {
            quitSingle = NSSound(contentsOf: url, byReference: true)
        }
        if let url = Bundle.main.url(forResource: "quit-all", withExtension: "aiff") {
            quitAll = NSSound(contentsOf: url, byReference: true)
        }
    }

    func playSingle() {
        guard PreferencesManager.shared.playSounds else { return }
        if let s = quitSingle { s.stop(); s.play() }
        else { NSSound.beep() }
    }

    func playAll() {
        guard PreferencesManager.shared.playSounds else { return }
        if let s = quitAll { s.stop(); s.play() }
        else { NSSound.beep() }
    }
}
