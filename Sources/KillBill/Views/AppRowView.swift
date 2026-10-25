import SwiftUI

struct AppRowView: View {
    let entry: AppEntry
    let isSelected: Bool
    let forceMode: Bool
    let accent: Color
    var onToggle: () -> Void
    var onQuit: () -> Void
    var onForceQuit: () -> Void
    var onUnhide: () -> Void
    var onReveal: () -> Void
    private var hovered = State(initialValue: false)

    var body: some View {
        HStack(spacing: 8) {
            CheckBox(isOn: Binding(get: { isSelected }, set: { _ in onToggle() }))

            Group {
                if let icon = entry.icon {
                    Image(nsImage: icon).resizable()
                } else {
                    Image(systemName: "app.fill").resizable().padding(2)
                }
            }
            .frame(width: 17, height: 17)

            Text(entry.name)
                .font(.system(size: 12.5, weight: .medium))
                .lineLimit(1)

            Spacer(minLength: 6)

            Text(entry.cpu > 0 ? String(format: "%.0f%%", entry.cpu) : "0%")
                .font(.system(size: 11.5, design: .monospaced))
                .foregroundColor(.secondary)

            // Quit / Force Quit düğmesi (Option ile yıldırıma döner)
            Button(action: { forceMode ? onForceQuit() : onQuit() }) {
                Image(systemName: forceMode ? "bolt.fill" : "power")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundColor(hovered.wrappedValue ? accent : .secondary)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .help(forceMode ? "Zorla kapat" : "Kapat")

            Menu {
                Button("Kapat") { onQuit() }
                Button("Zorla Kapat") { onForceQuit() }
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
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(hovered.wrappedValue ? Color.primary.opacity(0.08) : Color.clear)
        )
        .onHover { hovered.wrappedValue = $0 }
        .contentShape(Rectangle())
    }
}
