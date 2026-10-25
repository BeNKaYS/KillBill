import AppKit

// MARK: - Menü çubuğu simge seçenekleri
//
// Tüm simgeler template olarak üretilir; böylece koyu/açık menü çubuğuna
// ve sistem vurgusuna otomatik uyum sağlarlar.

enum StatusIconStyle: String, CaseIterable, Identifiable {
    // Uygulama simgesi (renkli, template değil)
    case appIcon
    // Elle çizilen simgeler
    case ringSlash
    case powerRing
    // SF Symbols tabanlı simgeler
    case power
    case bolt
    case crossCircle
    case crossOctagon
    case trash
    case flame
    case shield
    case hammer
    case boltSlash

    var id: String { rawValue }

    /// Bu sistemde simge gerçekten var mı? (Eski macOS sürümlerinde
    /// bazı semboller bulunmaz; seçicide göstermeyiz.)
    var isAvailable: Bool {
        if self == .appIcon { return StatusIconStyle.appIconSource() != nil }
        guard let name = symbolName else { return true }
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }

    /// Renkli simgeler template olarak çizilemez; menü çubuğunda kendi rengiyle durur.
    var isTemplate: Bool { self != .appIcon }

    /// Uygulama simgesinin kaynağı (önce paket, yoksa sistem simgesi).
    static func appIconSource() -> NSImage? {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        let sys = NSApp?.applicationIconImage
        return (sys?.size.width ?? 0) > 32 ? sys : nil
    }

    /// Seçicide gösterilecek simgeler.
    static var available: [StatusIconStyle] { allCases.filter(\.isAvailable) }

    var label: String {
        switch self {
        case .appIcon:     return "Uygulama simgesi"
        case .ringSlash:   return "Halka + çizgi"
        case .powerRing:   return "Güç halkası"
        case .power:       return "Açma / kapama"
        case .bolt:        return "Şimşek"
        case .crossCircle: return "Yuvarlak çarpı"
        case .crossOctagon:return "Sekizgen çarpı"
        case .trash:       return "Çöp kutusu"
        case .flame:       return "Alev"
        case .shield:      return "Kalkan + çarpı"
        case .hammer:      return "Çekiç"
        case .boltSlash:   return "Şimşek + çizgi"
        }
    }

    /// SF Symbols adı; elle çizilen simgelerde nil.
    private var symbolName: String? {
        switch self {
        case .appIcon, .ringSlash, .powerRing: return nil
        case .power:        return "power"
        case .bolt:         return "bolt.fill"
        case .crossCircle:  return "xmark.circle"
        case .crossOctagon: return "xmark.octagon.fill"
        case .trash:        return "trash.fill"
        case .flame:        return "flame.fill"
        case .shield:       return "xmark.shield.fill"
        case .hammer:       return "hammer.fill"
        case .boltSlash:    return "bolt.slash.fill"
        }
    }

    /// Menü çubuğu için template NSImage üretir.
    /// Simge bulunamazsa (eski sistem) elle çizilen halkaya düşer.
    func makeImage(size: CGFloat = 18) -> NSImage {
        if self == .appIcon {
            return makeAppIconImage(size: size)
        }
        if let name = symbolName,
           let symbol = NSImage(systemSymbolName: name, accessibilityDescription: label)?
            .withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: size * 0.78, weight: .semibold)) {
            let canvas = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
                let s = symbol.size
                symbol.draw(in: NSRect(x: rect.midX - s.width / 2,
                                       y: rect.midY - s.height / 2,
                                       width: s.width, height: s.height))
                return true
            }
            canvas.isTemplate = true
            return canvas
        }
        let drawn = drawCustom(size: size)
        drawn.isTemplate = true
        return drawn
    }

    // MARK: Uygulama simgesi

    /// Uygulama simgesini menü çubuğu boyutuna indirger.
    /// Küçük boyutta okunabilirlik için hafif yuvarlatılmış köşeyle çizilir.
    private func makeAppIconImage(size: CGFloat) -> NSImage {
        let canvas = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            guard let source = StatusIconStyle.appIconSource() else {
                // Simge bulunamazsa ince bir çerçeve çiz (boş yer bırakma)
                let p = NSBezierPath(roundedRect: rect.insetBy(dx: 1.5, dy: 1.5), xRadius: 4, yRadius: 4)
                p.lineWidth = 1.4
                NSColor.black.setStroke()
                p.stroke()
                return true
            }
            // Kaynağın kendi kenar boşluğunu koru, kareye sığdır.
            let inset: CGFloat = 0.5
            let box = rect.insetBy(dx: inset, dy: inset)
            let srcSize = source.size
            let side = min(srcSize.width, srcSize.height)
            let srcRect = NSRect(x: (srcSize.width - side) / 2,
                                 y: (srcSize.height - side) / 2,
                                 width: side, height: side)
            let radius: CGFloat = size * 0.22
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: box, xRadius: radius, yRadius: radius).addClip()
            source.draw(in: box, from: srcRect, operation: .sourceOver, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()
            return true
        }
        canvas.isTemplate = false
        return canvas
    }

    // MARK: Elle çizim

    private func drawCustom(size: CGFloat) -> NSImage {
        NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let c = NSPoint(x: rect.midX, y: rect.midY)
            let scale = rect.width / 18.0
            let lineWidth = 1.9 * scale

            NSColor.black.setStroke()
            NSColor.black.setFill()

            switch self {
            case .powerRing:
                // Üstü açık halka + dikey çizgi (güç simgesi)
                let r = 6.0 * scale
                let ring = NSBezierPath()
                ring.appendArc(withCenter: c, radius: r, startAngle: 120, endAngle: 420, clockwise: false)
                ring.lineWidth = lineWidth
                ring.lineCapStyle = .round
                ring.stroke()

                let stem = NSBezierPath()
                stem.move(to: NSPoint(x: c.x, y: c.y + 1.2 * scale))
                stem.line(to: NSPoint(x: c.x, y: c.y + 8.4 * scale))
                stem.lineWidth = lineWidth
                stem.lineCapStyle = .round
                stem.stroke()

            default:
                // Halka + eğik çizgi
                let r = 6.4 * scale
                let ring = NSBezierPath()
                ring.appendArc(withCenter: c, radius: r, startAngle: 40, endAngle: 320, clockwise: false)
                ring.lineWidth = lineWidth
                ring.lineCapStyle = .round
                ring.stroke()

                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: c.x - 4.2 * scale, y: c.y - 4.2 * scale))
                slash.line(to: NSPoint(x: c.x + 4.2 * scale, y: c.y + 4.2 * scale))
                slash.lineWidth = lineWidth
                slash.lineCapStyle = .round
                slash.stroke()
            }
            return true
        }
    }
}
