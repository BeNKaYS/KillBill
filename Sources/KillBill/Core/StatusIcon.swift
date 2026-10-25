import AppKit

// MARK: - Menü çubuğu simge seçenekleri
//
// Tüm simgeler template olarak üretilir; böylece koyu/açık menü çubuğuna
// ve sistem vurgusuna otomatik uyum sağlarlar.

enum StatusIconStyle: String, CaseIterable, Identifiable {
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
        guard let name = symbolName else { return true }
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
    }

    /// Seçicide gösterilecek simgeler.
    static var available: [StatusIconStyle] { allCases.filter(\.isAvailable) }

    var label: String {
        switch self {
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
        case .ringSlash, .powerRing: return nil
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
