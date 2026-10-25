import AppKit
import Combine
import Foundation

// MARK: - Güncelleme (yerel klasör + GitHub)
//
// Akış: kontrol → bildir → onay → yedek → indir → doğrula → yaz → yenile → geri al
// Kaynak sözleşmesi:
//   • Kökte `version.json`  { "surum": "1.0.1", "tarih": "2026-10-25", "not": "..." }
//   • Paket adı `KillBill.zip`; içinde tek bir `KillBill.app` olur.
//   • GitHub release modunda bunlar release varlığı (asset) olarak durur.
//   • GitHub dal modunda `version.json` kökte, paket `dist/KillBill.zip` altında durur.

enum UpdateSourceKind: String, CaseIterable, Identifiable {
    case local, github
    var id: String { rawValue }
    var label: String { self == .local ? "Yerel klasör" : "GitHub" }
}

enum GitHubUpdateMode: String, CaseIterable, Identifiable {
    case release, branch
    var id: String { rawValue }
    var label: String { self == .release ? "Release" : "Dal" }
}

struct UpdateInfo: Equatable {
    var version: String
    var date: String
    var note: String
}

enum UpdateError: LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let m): return m
        }
    }
}

final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()

    // MARK: Yayınlanan durum
    @Published private(set) var isChecking = false
    @Published private(set) var isUpdating = false
    @Published private(set) var available: UpdateInfo?
    @Published private(set) var statusLine: String = "Henüz kontrol edilmedi."

    fileprivate func setProgress(_ text: String) { statusLine = text }
    @Published private(set) var lastCheck: Date?

    /// Uygulamanın kendi sürümü (paket içindeki version.json → Info.plist).
    let currentVersion: String = UpdateManager.readCurrentVersion()
    let currentNote: String = UpdateManager.readCurrentNote()

    private let supportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("KillBill", isDirectory: true)
    }()

    private var backupsDir: URL { supportDir.appendingPathComponent("Yedek", isDirectory: true) }
    private var tokenFile: URL { supportDir.appendingPathComponent("github-token") }

    private var currentBundlePath: String { Bundle.main.bundlePath }

    /// İndirme/açma için kullanılan geçici klasör (iş bitince silinir).
    private var lastTempRoot: URL?

    var isRunningFromBundle: Bool { currentBundlePath.hasSuffix(".app") }

    private init() {}

    // MARK: - Sürüm okuma

    private static func readCurrentVersion() -> String {
        if let info = readBundledVersion() { return info.version }
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    private static func readCurrentNote() -> String {
        readBundledVersion()?.note ?? ""
    }

    private static func readBundledVersion() -> UpdateInfo? {
        guard let url = Bundle.main.url(forResource: "version", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return decodeVersion(data)
    }

    private static func decodeVersion(_ data: Data) -> UpdateInfo? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        let version = (obj["surum"] as? String) ?? (obj["version"] as? String)
        guard let version, !version.isEmpty else { return nil }
        return UpdateInfo(version: version,
                          date: obj["tarih"] as? String ?? "",
                          note: obj["not"] as? String ?? "")
    }

    // MARK: - Kaynak yapılandırması

    private var prefs: PreferencesManager { .shared }

    private var githubRepo: String {
        prefs.updateGitHubRepo.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// "owner/repo" ya da tam URL kabul eder.
    private func normalizedRepo() throws -> String {
        var raw = githubRepo
        guard !raw.isEmpty else {
            throw UpdateError.message("GitHub deposu girilmedi.\nÖrnek: kullanici/KillBill")
        }
        if raw.hasPrefix("https://github.com/") { raw = String(raw.dropFirst("https://github.com/".count)) }
        if raw.hasSuffix(".git") { raw = String(raw.dropLast(4)) }
        raw = raw.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = raw.split(separator: "/")
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            throw UpdateError.message("GitHub deposu \"sahip/depo\" biçiminde olmalı. Örnek: BeNKaYS/KillBill")
        }
        return "\(parts[0])/\(parts[1])"
    }

    private func localSourceURL() throws -> URL {
        var path = prefs.updateLocalPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            throw UpdateError.message("Yerel kaynak klasörü seçilmedi.")
        }
        if path.hasPrefix("~") {
            path = (path as NSString).expandingTildeInPath
        }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue else {
            throw UpdateError.message("Klasör bulunamadı: \(url.path)")
        }
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("version.json").path) else {
            throw UpdateError.message("Bu klasör bir KillBill kaynağı değil (version.json yok).")
        }
        guard hasLocalPackage(in: url) else {
            throw UpdateError.message("Klasörde güncelleme paketi yok. KillBill.zip ya da KillBill.app bekleniyor.")
        }
        return url
    }

    private func hasLocalPackage(in dir: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: dir.appendingPathComponent("KillBill.zip").path)
            || fm.fileExists(atPath: dir.appendingPathComponent("KillBill.app").path)
    }

    private func githubToken() -> String? {
        if let env = ProcessInfo.processInfo.environment["KILLBILL_GH_TOKEN"], !env.isEmpty { return env }
        guard let data = try? Data(contentsOf: tokenFile),
              let str = String(data: data, encoding: .utf8) else { return nil }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    // MARK: - Kontrol

    func checkForUpdates() {
        guard !isChecking, !isUpdating else { return }
        isChecking = true
        available = nil
        statusLine = "Kontrol ediliyor…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let info = try self.fetchRemoteVersion()
                DispatchQueue.main.async {
                    self.lastCheck = Date()
                    if UpdateManager.compare(info.version, self.currentVersion) > 0 {
                        self.available = info
                        self.statusLine = "Yeni sürüm: \(info.version) · \(info.date.isEmpty ? "tarih yok" : info.date) · \(info.note)"
                    } else {
                        self.available = nil
                        self.statusLine = "Güncel — sürüm \(self.currentVersion)."
                    }
                    self.isChecking = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.lastCheck = Date()
                    self.available = nil
                    self.statusLine = "Hata: \(error.localizedDescription)"
                    self.isChecking = false
                }
            }
        }
    }

    /// Yayınlanan sürümü okur (yerel dosya ya da HTTPS).
    private func fetchRemoteVersion() throws -> UpdateInfo {
        switch prefs.updateSourceKind {
        case .local:
            let dir = try localSourceURL()
            let data = try Data(contentsOf: dir.appendingPathComponent("version.json"))
            guard let info = UpdateManager.decodeVersion(data) else {
                throw UpdateError.message("version.json okunamadı ya da geçersiz.")
            }
            return info

        case .github:
            let repo = try normalizedRepo()
            switch prefs.updateGitHubMode {
            case .branch:
                let branch = prefs.updateBranch.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !branch.isEmpty else { throw UpdateError.message("Dal adı boş olamaz.") }
                let raw = "https://raw.githubusercontent.com/\(repo)/\(branch)/version.json"
                let data = try UpdateManager.httpsData(raw)
                guard let info = UpdateManager.decodeVersion(data) else {
                    throw UpdateError.message("Depodaki version.json geçersiz.")
                }
                return info
            case .release:
                let release = try fetchLatestRelease(repo: repo)
                if let versionAsset = release.assets.first(where: { $0.name == "version.json" }) {
                    let data = try UpdateManager.httpsData(versionAsset.url)
                    if let info = UpdateManager.decodeVersion(data) { return info }
                }
                // version.json varlığı yoksa etiketi sürüm kabul et
                let tagVersion = release.tag.replacingOccurrences(of: "v", with: "", options: .anchored)
                guard !tagVersion.isEmpty else {
                    throw UpdateError.message("Release bulundu ama sürüm etiketi okunamadı.\nRelease'e version.json ekleyin.")
                }
                return UpdateInfo(version: tagVersion, date: "", note: release.name)
            }
        }
    }

    // MARK: - GitHub yardımcıları

    private struct ReleaseAsset { let name: String; let url: String; let size: Int }
    private struct Release { let tag: String; let name: String; let assets: [ReleaseAsset] }

    private func fetchLatestRelease(repo: String) throws -> Release {
        let releasesURL = "https://api.github.com/repos/\(repo)/releases/latest"
        let data: Data
        do {
            data = try UpdateManager.httpsData(releasesURL)
        } catch {
            // 404 iki farklı şey olabilir: depo yok ya da depo var ama Release yok.
            if UpdateManager.status(of: "https://api.github.com/repos/\(repo)") == 404 {
                throw UpdateError.message("Depo bulunamadı: \(repo)\nDepo özel ise GitHub token gerekir; yoksa sahip/depo adını kontrol edin.")
            }
            throw error
        }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UpdateError.message("GitHub yanıtı okunamadı.")
        }
        if let message = obj["message"] as? String {
            throw UpdateError.message("GitHub: \(message)")
        }
        let tag = obj["tag_name"] as? String ?? ""
        let name = obj["name"] as? String ?? ""
        let assets = (obj["assets"] as? [[String: Any]] ?? []).compactMap { a -> ReleaseAsset? in
            guard let n = a["name"] as? String,
                  let u = a["browser_download_url"] as? String else { return nil }
            return ReleaseAsset(name: n, url: u, size: a["size"] as? Int ?? 0)
        }
        return Release(tag: tag, name: name, assets: assets)
    }

    private static func httpsData(_ urlString: String) throws -> Data {
        try httpGet(urlString).data
    }

    /// HTTP GET; durum kodunu da döndürür ki 404'ün sebebi ayrıştırılabilsin.
    private static func httpGet(_ urlString: String) throws -> (data: Data, status: Int) {
        guard let url = URL(string: urlString), url.scheme == "https" else {
            throw UpdateError.message("Yalnızca HTTPS adresleri kabul edilir.")
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 25
        request.setValue("KillBill-Updater", forHTTPHeaderField: "User-Agent")
        if url.host == "api.github.com" || url.host == "raw.githubusercontent.com" {
            if let token = UpdateManager.shared.githubToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        var result: Result<(Data, Int), Error>!
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            if let error { result = .failure(error); return }
            guard let http = response as? HTTPURLResponse else {
                result = .failure(UpdateError.message("Sunucu yanıtı okunamadı.")); return
            }
            result = .success((data ?? Data(), http.statusCode))
        }.resume()
        semaphore.wait()
        let (data, status) = try result.get()
        guard (200..<300).contains(status) else {
            throw UpdateError.message(UpdateManager.describe(status: status, url: urlString, body: data))
        }
        return (data, status)
    }

    /// Yalnızca durum kodunu döndürür (hata fırlatmaz). Depo var mı yok mu
    /// ayrımını yapabilmek için kullanılır.
    private static func status(of urlString: String) -> Int? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.httpMethod = "GET"
        request.setValue("KillBill-Updater", forHTTPHeaderField: "User-Agent")
        if let token = UpdateManager.shared.githubToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        var result: Int?
        let semaphore = DispatchSemaphore(value: 0)
        URLSession.shared.dataTask(with: request) { _, response, _ in
            result = (response as? HTTPURLResponse)?.statusCode
            semaphore.signal()
        }.resume()
        semaphore.wait()
        return result
    }

    /// HTTP hata kodunu kullanıcıya anlamlı bir cümleye çevirir.
    private static func describe(status: Int, url: String, body: Data) -> String {
        let apiMessage = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["message"] as? String
        switch status {
        case 401:
            return "GitHub kimlik doğrulaması başarısız (401). Özel depo için token gerekli."
        case 403:
            return "GitHub erişimi reddedildi (403).\nOlası sebep: API limiti doldu ya da token geçersiz."
        case 404:
            if url.contains("/releases/") {
                return "Bu depoda henüz yayınlanmış Release yok.\nGitHub'da bir Release oluşturup KillBill.zip ve version.json yükleyin, ya da kaynağı \"Dal\" yapın."
            }
            if url.contains("raw.githubusercontent.com") {
                return "Dosya depoda bulunamadı (404).\nDal adı yanlış olabilir ya da version.json depoda yok."
            }
            // /repos/{owner}/{repo}
            let repo = url.replacingOccurrences(of: "https://api.github.com/repos/", with: "")
            return "Depo bulunamadı: \(repo)\nDepo özel ise token gerekir; yoksa sahip/depo adını kontrol edin."
        case 429:
            return "GitHub istek limiti aşıldı (429). Birkaç dakika sonra tekrar deneyin."
        default:
            let detail = apiMessage.map { " — \($0)" } ?? ""
            return "Sunucu \(status) döndü\(detail)"
        }
    }

    // MARK: - Güncelleme

    func performUpdate() {
        guard let info = available, !isUpdating, !isChecking else { return }
        guard isRunningFromBundle else {
            statusLine = "Güncelleme yalnızca .app paketi olarak çalışırken yapılabilir."
            return
        }
        isUpdating = true
        statusLine = "Güncelleme hazırlanıyor…"

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                let package = try self.obtainPackage(expected: info)
                defer {
                    if let temp = self.lastTempRoot { try? FileManager.default.removeItem(at: temp) }
                    self.lastTempRoot = nil
                }
                try self.install(package: package, expected: info)
                DispatchQueue.main.async {
                    self.isUpdating = false
                    self.statusLine = "Sürüm \(info.version) yazıldı. Uygulama yeniden başlatılıyor…"
                    self.relaunch()
                }
            } catch {
                DispatchQueue.main.async {
                    self.isUpdating = false
                    self.statusLine = "Güncelleme başarısız: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Paketi indirir/kopyalar, doğrular ve geçici klasöre açar. Açılan .app yolunu döndürür.
    private func obtainPackage(expected: UpdateInfo) throws -> URL {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("KillBillUpdate-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        lastTempRoot = tempRoot

        let zipURL = tempRoot.appendingPathComponent("KillBill.zip")
        var bundleCandidate: URL?

        switch prefs.updateSourceKind {
        case .local:
            let dir = try localSourceURL()
            let localZip = dir.appendingPathComponent("KillBill.zip")
            let localApp = dir.appendingPathComponent("KillBill.app")
            if FileManager.default.fileExists(atPath: localZip.path) {
                try FileManager.default.copyItem(at: localZip, to: zipURL)
            } else if FileManager.default.fileExists(atPath: localApp.path) {
                bundleCandidate = try extractAppFromDirectory(localApp, into: tempRoot)
            }
        case .github:
            let remote = try remotePackageURL()
            note("İndiriliyor…")
            try download(remote, to: zipURL)
        }

        if let bundleCandidate { return bundleCandidate }

        let extracted = tempRoot.appendingPathComponent("Extracted", isDirectory: true)
        try FileManager.default.createDirectory(at: extracted, withIntermediateDirectories: true)
        try validateZip(zipURL)
        note("Paket açılıyor…")
        try run("/usr/bin/ditto", ["-x", "-k", zipURL.path, extracted.path])
        guard let app = findApp(in: extracted) else {
            throw UpdateError.message("Paket içinde KillBill.app bulunamadı.")
        }
        return app
    }

    private func remotePackageURL() throws -> URL {
        switch prefs.updateGitHubMode {
        case .branch:
            let repo = try normalizedRepo()
            let branch = prefs.updateBranch.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: "https://raw.githubusercontent.com/\(repo)/\(branch)/dist/KillBill.zip") else {
                throw UpdateError.message("İndirme adresi oluşturulamadı.")
            }
            return url
        case .release:
            let repo = try normalizedRepo()
            let release = try fetchLatestRelease(repo: repo)
            guard let asset = release.assets.first(where: { $0.name.lowercased() == "killbill.zip" })
                ?? release.assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }) else {
                throw UpdateError.message("Release içinde KillBill.zip bulunamadı.")
            }
            guard asset.size <= 300 * 1024 * 1024 else {
                throw UpdateError.message("Paket beklenenden büyük (\(asset.size) bayt).")
            }
            guard let url = URL(string: asset.url) else {
                throw UpdateError.message("İndirme adresi geçersiz.")
            }
            return url
        }
    }

    private func download(_ url: URL, to destination: URL) throws {
        guard url.scheme == "https" else {
            throw UpdateError.message("Güvenlik: HTTPS olmayan kaynaktan indirme reddedildi.")
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("KillBill-Updater", forHTTPHeaderField: "User-Agent")
        if let token = githubToken(), url.host == "api.github.com" || url.host == "raw.githubusercontent.com" {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let semaphore = DispatchSemaphore(value: 0)
        var failure: Error?
        let task = URLSession.shared.downloadTask(with: request) { tmp, response, error in
            defer { semaphore.signal() }
            if let error { failure = error; return }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                failure = UpdateError.message("Paket indirilemedi (sunucu yanıtı)."); return
            }
            guard let tmp else { failure = UpdateError.message("İndirilen paket boş."); return }
            do {
                let dest = destination
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.moveItem(at: tmp, to: dest)
            } catch {
                failure = error
            }
        }
        task.resume()
        semaphore.wait()
        if let failure { throw failure }

        let size = (try? FileManager.default.attributesOfItem(atPath: destination.path)[.size] as? Int) ?? 0
        guard size > 0, size <= 300 * 1024 * 1024 else {
            throw UpdateError.message("Paket boyutu geçersiz (\(size) bayt).")
        }
    }

    /// Zip-slip koruması: mutlak yol ve `..` içeren girdiler reddedilir.
    private func validateZip(_ zip: URL) throws {
        let listing = try runCapturing("/usr/bin/unzip", ["-Z1", zip.path])
        let entries = listing.split(separator: "\n").map(String.init)
        guard !entries.isEmpty else { throw UpdateError.message("Paket boş ya da bozuk.") }
        for entry in entries {
            if entry.hasPrefix("/") || entry.contains("..") {
                throw UpdateError.message("Güvenlik: paket içinde geçersiz yol var (\(entry)).")
            }
        }
        guard entries.contains(where: { $0.contains("KillBill.app/") }) else {
            throw UpdateError.message("Paket içinde KillBill.app yok.")
        }
    }

    private func extractAppFromDirectory(_ app: URL, into root: URL) throws -> URL {
        let dest = root.appendingPathComponent("Unsigned/KillBill.app", isDirectory: true)
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: app, to: dest)
        return dest
    }

    private func findApp(in dir: URL) -> URL? {
        guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else { return nil }
        for case let url as URL in enumerator where url.pathExtension == "app" {
            return url
        }
        return nil
    }

    /// Yedek al → paketi yerleştir → hata olursa geri al.
    private func install(package: URL, expected: UpdateInfo) throws {
        let fm = FileManager.default
        let target = URL(fileURLWithPath: currentBundlePath)
        let installedID = Bundle(path: package.path)?.bundleIdentifier
        guard installedID == Bundle.main.bundleIdentifier else {
            throw UpdateError.message("Paket farklı bir uygulama içeriyor (\(installedID ?? "kimlik yok")).")
        }
        // Paketin kendi sürümü bildirilenle aynı mı?
        if let infoURL = Bundle(path: package.path)?.url(forResource: "version", withExtension: "json"),
           let data = try? Data(contentsOf: infoURL),
           let info = UpdateManager.decodeVersion(data),
           UpdateManager.compare(info.version, expected.version) != 0 {
            throw UpdateError.message("Paket sürümü (\(info.version)) bildirilenle (\(expected.version)) uyuşmuyor.")
        }

        try fm.createDirectory(at: backupsDir, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let backupZip = backupsDir.appendingPathComponent("KillBill-\(currentVersion)-\(stamp).zip")

        note("Yedek alınıyor…")
        try run("/usr/bin/ditto", ["-c", "-k", "--keepParent", target.path, backupZip.path])

        let staging = supportDir.appendingPathComponent("Staging", isDirectory: true)
        try? fm.removeItem(at: staging)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        let oldCopy = staging.appendingPathComponent("old.app", isDirectory: true)

        var movedOld = false
        do {
            note("Dosyalar yazılıyor…")
            // Kendi paketini taşımak çalışan süreç için güvenlidir; yeni paket aynı yola konur.
            try fm.moveItem(at: target, to: oldCopy)
            movedOld = true
            try fm.copyItem(at: package, to: target)
            // Karantina damgası varsa temizle
            try? run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", target.path])
        } catch {
            if movedOld {
                try? fm.removeItem(at: target)
                try? fm.moveItem(at: oldCopy, to: target)
            }
            throw UpdateError.message("Yazma başarısız, eski sürüm geri kondu. Yedek: \(backupZip.path)")
        }

        try? fm.removeItem(at: oldCopy)
        try? fm.removeItem(at: staging)
        statusLine = "Güncellendi. Yedek: \(backupZip.path)"
    }

    private func relaunch() {
        let path = currentBundlePath
        guard path.hasSuffix(".app") else { NSApp.terminate(nil); return }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = ["-c", "sleep 1.2; /usr/bin/open -n \"\(path)\""]
        try? p.run()
        NSApp.terminate(nil)
    }

    // MARK: - Süreç yardımcıları

    private func run(_ launchPath: String, _ args: [String]) throws {
        _ = try runCapturing(launchPath, args)
    }

    @discardableResult
    private func runCapturing(_ launchPath: String, _ args: [String]) throws -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: launchPath)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        try p.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            let msg = String(data: data, encoding: .utf8) ?? ""
            throw UpdateError.message("\(launchPath) başarısız: \(msg.isEmpty ? "çıkış \(p.terminationStatus)" : msg)")
        }
        return String(data: data, encoding: .utf8) ?? ""
    }

    // MARK: - Sürüm karşılaştırma

    static func compare(_ a: String, _ b: String) -> Int {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        let n = max(pa.count, pb.count)
        for i in 0..<n {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        return 0
    }
}

// İlerleme satırını ana iş parçacığından güncelleyen küçük yardımcı.
private func note(_ text: String) {
    DispatchQueue.main.async { UpdateManager.shared.setProgress(text) }
}
