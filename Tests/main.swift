import AppKit
import Carbon.HIToolbox

var failures = 0
var checks = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    checks += 1
    if !condition() { failures += 1; print("FAIL: \(message)") }
}

expect(KeyCodeFormatter.string(for: ShortcutCombo(keyCode: 0, modifiers: UInt32(cmdKey))) == "⌘A",
       "Command-A must be recordable, not interpreted as no shortcut")
expect(KeyCodeFormatter.string(for: ShortcutCombo()) == "Kayıt yok", "Empty shortcut label")

let suite = "KillBill.Tests.\(UUID().uuidString)"
let defaults = UserDefaults(suiteName: suite)!
defer { defaults.removePersistentDomain(forName: suite) }
let prefs = PreferencesManager(defaults: defaults)
expect(prefs.quitOption == .normal, "New users default to normal quit")
prefs.updateGitHubRepo = "example/custom"
prefs.useSystemColor = false
prefs.resetAll()
expect(prefs.updateGitHubRepo == "BeNKaYS/KillBill" && prefs.useSystemColor, "Reset updates in-memory preferences")
let restored = PreferencesManager(defaults: defaults)
expect(restored.updateGitHubRepo == prefs.updateGitHubRepo, "Reset persists consistently")
let editor = AppEntry(id: 101, name: "Editor", bundleID: "test.editor", icon: nil, cpu: 12, isBackground: false, isTerminated: false)
let browser = AppEntry(id: 102, name: "Browser", bundleID: "test.browser", icon: nil, cpu: 3, isBackground: false, isTerminated: false)
prefs.toggleProtection(editor)
expect(PreferencesManager(defaults: defaults).isProtected(editor), "Protection survives relaunch")
var requested: [(Int32, Bool)] = []
var living: Set<Int32> = [101, 102]
let service = QuitService(preferences: prefs,
                          terminate: { pid, force in requested.append((pid, force)); return true },
                          isRunning: { living.contains($0) },
                          confirmForce: { _ in true })
service.quit(entries: [editor, browser], force: false)
expect(requested.count == 1 && requested.first?.0 == 102 && requested.first?.1 == false,
       "Normal batch excludes protected app and never force-quits")
expect(service.results.first?.state == .waiting, "Accepted request is not reported as closed")
living.remove(102)
service.refreshPending()
expect(service.results.first?.state == .closed, "Actual termination is reported")
requested.removeAll()
let cancelled = QuitService(preferences: prefs, terminate: { pid, force in requested.append((pid, force)); return true },
                            isRunning: { _ in true }, confirmForce: { _ in false })
cancelled.quit(entries: [browser], force: true)
expect(requested.isEmpty, "Cancelled force quit makes no process call")
let timeout = QuitService(preferences: prefs, terminate: { _, _ in true }, isRunning: { _ in true }, confirmForce: { _ in true })
timeout.quit(entries: [browser], force: false)
timeout.refreshPending(now: Date().addingTimeInterval(30))
expect(timeout.results.first?.state == .timedOut, "Timeout never implies termination")
let finder = AppEntry(id: 103, name: "Finder", bundleID: "com.apple.finder", icon: nil, cpu: 0, isBackground: false, isTerminated: false)
expect(!RunningAppsManager.filtered([finder, browser], preferences: prefs, search: "").contains { $0.id == 103 }, "Finder hidden by preference")
prefs.showBackgroundApps = true
let helper1 = AppEntry(id: 104, name: "Helper", bundleID: "test.helper", icon: nil, cpu: 2, isBackground: true, isTerminated: false)
let helper2 = AppEntry(id: 105, name: "Helper", bundleID: "test.helper", icon: nil, cpu: 3, isBackground: true, isTerminated: false)
let grouped = RunningAppsManager.filtered([helper1, helper2], preferences: prefs, search: "Helper")
expect(grouped.count == 1 && grouped.first?.cpu == 5 && grouped.first?.processIDs.count == 2, "Grouping retains all process targets and CPU total")
expect(RunningAppsManager.filtered([editor, browser], preferences: prefs, search: "Browser").map(\.id) == [102], "Search limits visible targets")

func rejects(_ label: String, _ operation: () throws -> Void) {
    do { try operation(); expect(false, label) } catch { expect(true, label) }
}
rejects("Invalid version rejected") { _ = try UpdateValidation.version(Data("{\"surum\":\"garbage\"}".utf8)) }
rejects("Missing version rejected") { _ = try UpdateValidation.version(Data("{}".utf8)) }
expect((try? UpdateValidation.version(Data("{\"surum\":\"1.12.0\"}".utf8)))?.version == "1.12.0", "Valid version parsed")
rejects("Invalid archive rejected") { try UpdateValidation.archive(Data("not a zip".utf8)) }

func makeArchive(symlink: Bool) throws -> Data {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("KillBillZip-\(UUID().uuidString)")
    let app = root.appendingPathComponent("KillBill.app")
    let contents = app.appendingPathComponent("Contents")
    try FileManager.default.createDirectory(at: contents.appendingPathComponent("MacOS"), withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: contents.appendingPathComponent("Resources"), withIntermediateDirectories: true)
    try Data("<plist/>".utf8).write(to: contents.appendingPathComponent("Info.plist"))
    try Data("binary".utf8).write(to: contents.appendingPathComponent("MacOS/KillBill"))
    try Data("{\"surum\":\"1.0.0\",\"tarih\":\"\",\"not\":\"\"}".utf8)
        .write(to: contents.appendingPathComponent("Resources/version.json"))
    if symlink {
        try FileManager.default.createSymbolicLink(atPath: contents.appendingPathComponent("Resources/link").path,
                                                   withDestinationPath: "../../../../etc/passwd")
    }
    let zip = root.appendingPathComponent("KillBill.zip")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = ["-c", "-k", "--keepParent", app.path, zip.path]
    try process.run(); process.waitUntilExit()
    defer { try? FileManager.default.removeItem(at: root) }
    return try Data(contentsOf: zip)
}
expect((try? UpdateValidation.archive(makeArchive(symlink: false))) != nil, "Valid KillBill archive accepted")
rejects("Archive symlink rejected") { try UpdateValidation.archive(makeArchive(symlink: true)) }

let temp = FileManager.default.temporaryDirectory.appendingPathComponent("KillBillTests-\(UUID().uuidString)")
try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temp) }
let target = temp.appendingPathComponent("KillBill.app")
let candidate = temp.appendingPathComponent("Candidate.app")
try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: candidate, withIntermediateDirectories: true)
try Data("old".utf8).write(to: target.appendingPathComponent("version"))
try Data("new".utf8).write(to: candidate.appendingPathComponent("version"))
let previous = try BundleInstaller.replace(target: target, candidate: candidate)
expect((try? String(contentsOf: target.appendingPathComponent("version"))) == "new", "Replacement installed")
try BundleInstaller.restore(target: target, previous: previous)
expect((try? String(contentsOf: target.appendingPathComponent("version"))) == "old", "Rollback restores previous version")
rejects("Missing candidate cannot destroy installed application") {
    _ = try BundleInstaller.replace(target: target, candidate: temp.appendingPathComponent("missing"))
}
expect(FileManager.default.fileExists(atPath: target.appendingPathComponent("version").path), "Failed preparation preserves original")

print("\(checks - failures)/\(checks) checks passed")
exit(failures == 0 ? 0 : 1)
