import SwiftUI

struct AppRowView: View {
    let entry: AppEntry
    let isSelected: Bool
    let forceMode: Bool
    let accent: Color
    let isProtected: Bool
    var onProtect: () -> Void
    var onToggle: () -> Void
    var onQuit: () -> Void
    var onForceQuit: () -> Void
    var onUnhide: () -> Void
    var onReveal: () -> Void
    @ViewState private var hovered = false

    var body: some View {
        HStack(spacing: 8) {
            CheckBox(isOn: Binding(get: { isSelected }, set: { _ in onToggle() }))
                .disabled(isProtected)
                .accessibilityLabel("\(entry.name) seç")

            Group {
                if let icon = entry.icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "app.fill").resizable().padding(2)
                }
            }
            .frame(width: 22, height: 22)

            Text(entry.name)
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)
                .help(entry.name)

            Spacer(minLength: 6)
            if entry.bundleID != nil {
                Button(action: onProtect) {
                    Image(systemName: isProtected ? "lock.fill" : "lock.open")
                        .foregroundColor(isProtected ? accent : .secondary)
                }.buttonStyle(.borderless)
                    .help(isProtected ? "Korumayı kaldır" : "Kapatmadan koru")
                    .accessibilityLabel("\(entry.name): \(isProtected ? "korumayı kaldır" : "koru")")
            }

            Text(entry.cpu > 0 ? String(format: "%.0f%%", entry.cpu) : "0%")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 38, alignment: .trailing)
                .accessibilityLabel("CPU yüzde \(Int(entry.cpu))")

            // Quit / Force Quit düğmesi (Option ile yıldırıma döner)
            Button(action: { forceMode ? onForceQuit() : onQuit() }) {
                Image(systemName: forceMode ? "bolt.fill" : "power")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(hovered ? accent : .secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .disabled(isProtected)
            .accessibilityLabel("\(entry.name) \(forceMode ? "zorla kapat" : "kapat")")
            .help(forceMode ? "Zorla kapat" : "Kapat")

            Menu {
                Button(forceMode ? "Zorla Kapat…" : "Kapat") { onQuit() }.disabled(isProtected)
                Button("Zorla Kapat…") { onForceQuit() }.disabled(isProtected)
                Divider()
                Button("Öne Getir") { onUnhide() }
                Button("Finder'da Göster") { onReveal() }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 18, height: 22)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 20)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovered ? Color.primary.opacity(0.08) : Color.clear)
        )
        .onHover { hovered = $0 }
        .contentShape(Rectangle())
    }
}
