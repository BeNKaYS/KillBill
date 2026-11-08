import Foundation
import Security

enum UpdateValidation {
    static let maxBytes = 300 * 1024 * 1024
    static let maxExpandedBytes = 600 * 1024 * 1024

    static func version(_ data: Data) throws -> UpdateInfo {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = (object["surum"] ?? object["version"]) as? String,
              value.range(of: #"^[0-9]{1,9}(\.[0-9]{1,9}){0,3}$"#, options: .regularExpression) != nil else {
            throw UpdateError.message("Sürüm bilgisi eksik veya geçersiz; sayısal bir sürüm bekleniyor.")
        }
        return UpdateInfo(version: value, date: object["tarih"] as? String ?? "", note: object["not"] as? String ?? "")
    }

    /// Our update format deliberately supports regular files/directories only.
    /// Reject symlinks BEFORE extraction, ZIP64, encrypted and multi-disk archives.
    static func archive(_ data: Data) throws {
        func invalid() -> UpdateError { .message("Güvenli olmayan veya desteklenmeyen ZIP paketi.") }
        guard data.count >= 22, data.count <= maxBytes else { throw invalid() }
        func uint(_ offset: Int, _ width: Int) throws -> Int {
            guard offset >= 0, offset <= data.count - width else { throw invalid() }
            return (0..<width).reduce(0) { $0 | (Int(data[offset + $1]) << (8 * $1)) }
        }
        var end: Int?
        for offset in stride(from: data.count - 22, through: max(0, data.count - 65557), by: -1) {
            if try uint(offset, 4) == 0x06054b50,
               offset + 22 + (try uint(offset + 20, 2)) == data.count { end = offset; break }
        }
        guard let end else { throw invalid() }
        let count = try uint(end + 10, 2)
        let centralSize = try uint(end + 12, 4)
        let centralStart = try uint(end + 16, 4)
        let disk = try uint(end + 4, 2)
        let centralDisk = try uint(end + 6, 2)
        let entriesOnDisk = try uint(end + 8, 2)
        guard disk == 0, centralDisk == 0,
              entriesOnDisk == count, count > 0, count < 10000,
              centralStart + centralSize == end else { throw invalid() }
        var cursor = centralStart
        var expanded = 0
        var names = Set<String>()
        var ranges: [Range<Int>] = []
        for _ in 0..<count {
            guard try uint(cursor, 4) == 0x02014b50 else { throw invalid() }
            let flags = try uint(cursor + 8, 2)
            let method = try uint(cursor + 10, 2)
            let compressed = try uint(cursor + 20, 4)
            let size = try uint(cursor + 24, 4)
            let nameLength = try uint(cursor + 28, 2)
            let extraLength = try uint(cursor + 30, 2)
            let commentLength = try uint(cursor + 32, 2)
            let diskStart = try uint(cursor + 34, 2)
            let mode = (try uint(cursor + 38, 4)) >> 16
            let kind = mode & 0xf000
            let local = try uint(cursor + 42, 4)
            let next = cursor + 46 + nameLength + extraLength + commentLength
            guard next <= end, nameLength > 0, flags & 1 == 0, [0, 8].contains(method),
                  [0, 0x8000, 0x4000].contains(kind), diskStart == 0 else { throw invalid() }
            guard let name = String(data: data[(cursor + 46)..<(cursor + 46 + nameLength)], encoding: .utf8),
                  name.hasPrefix("KillBill.app/"), !name.contains(".."), !name.contains("\\"),
                  !name.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
                  !name.contains("//"), names.insert(name.lowercased()).inserted else { throw invalid() }
            expanded += size
            guard expanded <= maxExpandedBytes, local < centralStart,
                  try uint(local, 4) == 0x04034b50 else { throw invalid() }
            let localFlags = try uint(local + 6, 2)
            let localMethod = try uint(local + 8, 2)
            let localNameLength = try uint(local + 26, 2)
            guard localFlags == flags, localMethod == method, localNameLength == nameLength else { throw invalid() }
            let localNameStart = local + 30
            let payload = localNameStart + nameLength + (try uint(local + 28, 2))
            guard payload <= centralStart, payload + compressed <= centralStart,
                  data[localNameStart..<(localNameStart + nameLength)] == data[(cursor + 46)..<(cursor + 46 + nameLength)] else { throw invalid() }
            if flags & 8 == 0 {
                let localCompressed = try uint(local + 18, 4)
                let localSize = try uint(local + 22, 4)
                guard localCompressed == compressed, localSize == size else { throw invalid() }
            }
            let range = local..<(payload + compressed)
            guard !ranges.contains(where: { $0.overlaps(range) }) else { throw invalid() }
            ranges.append(range)
            cursor = next
        }
        guard cursor == end, names.contains("killbill.app/contents/info.plist"),
              names.contains("killbill.app/contents/macos/killbill"),
              names.contains("killbill.app/contents/resources/version.json") else { throw invalid() }
    }

    static func bundle(_ url: URL, expected: UpdateInfo, installed: URL, remote: Bool) throws {
        let fm = FileManager.default
        guard url.lastPathComponent == "KillBill.app",
              let candidate = Bundle(url: url), let current = Bundle(url: installed),
              candidate.bundleIdentifier == current.bundleIdentifier,
              let executable = candidate.executableURL, executable.lastPathComponent == "KillBill",
              fm.isExecutableFile(atPath: executable.path),
              let versionURL = candidate.url(forResource: "version", withExtension: "json") else {
            throw UpdateError.message("Paket kimliği, çalıştırılabilir dosya veya version.json eksik.")
        }
        let info = try version(Data(contentsOf: versionURL))
        guard info.version == expected.version else { throw UpdateError.message("Paket sürümü kontrol edilen sürümle uyuşmuyor.") }
        guard let files = fm.enumerator(at: url, includingPropertiesForKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey]) else {
            throw UpdateError.message("Paket okunamadı.")
        }
        var total = 0
        for case let file as URL in files {
            let values = try file.resourceValues(forKeys: [.isSymbolicLinkKey, .isRegularFileKey, .isDirectoryKey, .fileSizeKey])
            guard values.isSymbolicLink != true, values.isRegularFile == true || values.isDirectory == true else {
                throw UpdateError.message("Pakette sembolik bağ veya desteklenmeyen dosya var.")
            }
            total += values.fileSize ?? 0
            guard total <= maxExpandedBytes else { throw UpdateError.message("Açılan paket boyutu sınırı aşıldı.") }
        }
        let currentTeam = try signingTeam(installed, requireValid: false)
        let candidateTeam = try signingTeam(url, requireValid: true)
        if remote || currentTeam != nil {
            guard let currentTeam, candidateTeam == currentTeam else {
                throw UpdateError.message("Güncelleme aynı Developer ID yayıncısı tarafından imzalanmalı. Bu geliştirme yapısı için doğruladığınız yerel paketi seçin.")
            }
            var requirement: SecRequirement?
            let rule = "anchor apple generic and certificate leaf[subject.OU] = \"\(currentTeam)\""
            var code: SecStaticCode?
            guard SecRequirementCreateWithString(rule as CFString, [], &requirement) == errSecSuccess,
                  SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
                  SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures), requirement) == errSecSuccess else {
                throw UpdateError.message("Yayıncı imzası doğrulanamadı.")
            }
        }
    }

    private static func signingTeam(_ url: URL, requireValid: Bool) throws -> String? {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code else {
            throw UpdateError.message("Paket imzası okunamadı.")
        }
        if requireValid && SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures), nil) != errSecSuccess {
            throw UpdateError.message("Paket imzası geçersiz veya dosyalar değiştirilmiş.")
        }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess else { return nil }
        return (info as? [String: Any])?[kSecCodeInfoTeamIdentifier as String] as? String
    }
}

enum BundleInstaller {
    /// Stage on the destination volume before moving the installed application.
    static func replace(target: URL, candidate: URL) throws -> URL {
        let fm = FileManager.default
        let parent = target.deletingLastPathComponent()
        let staged = parent.appendingPathComponent(".KillBill-staged-\(UUID().uuidString).app")
        let previous = parent.appendingPathComponent(".KillBill-previous-\(UUID().uuidString).app")
        defer { try? fm.removeItem(at: staged) }
        try fm.copyItem(at: candidate, to: staged)
        try fm.moveItem(at: target, to: previous)
        do { try fm.moveItem(at: staged, to: target) }
        catch {
            do { try fm.moveItem(at: previous, to: target) }
            catch { throw UpdateError.message("Kurulum ve geri alma başarısız. Önceki uygulama: \(previous.path)") }
            throw UpdateError.message("Kurulum başarısız; önceki uygulama geri yüklendi.")
        }
        return previous
    }

    static func restore(target: URL, previous: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: previous.path) else { throw UpdateError.message("Önceki uygulama bulunamadı: \(previous.path)") }
        let failed = target.deletingLastPathComponent().appendingPathComponent(".KillBill-failed-\(UUID().uuidString).app")
        let exists = fm.fileExists(atPath: target.path)
        if exists { try fm.moveItem(at: target, to: failed) }
        do { try fm.moveItem(at: previous, to: target) }
        catch {
            if exists { try? fm.moveItem(at: failed, to: target) }
            throw UpdateError.message("Geri alma başarısız. Önceki uygulama: \(previous.path)")
        }
        if exists { try? fm.removeItem(at: failed) }
    }
}
