import SwiftUI
import AppKit

struct ClipRowView: View {
    let item: ClipItem
    let onCopy: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .trailing) {
            // Hover background
            Color.primary.opacity(isHovered ? 0.05 : 0)

            // Full-row tap button
            Button(action: onCopy) {
                HStack(spacing: 10) {
                    sourceIcon
                        .frame(width: 20, height: 20)

                    typeIcon

                    content

                    Spacer()

                    if item.type == .color,
                       let hex = item.colorHex,
                       let color = Color(hex: hex) {
                        colorSwatch(color)
                    }

                    // Age — nascosto durante hover (sostituito dal pin)
                    Text(item.createdAt.relativeShort)
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                        .frame(minWidth: 24, alignment: .trailing)
                        .opacity(isHovered ? 0 : 1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Pin button — overlay separato, cattura solo il suo click
            if isHovered {
                Button { togglePin() } label: {
                    Image(systemName: item.isPinned ? "pin.slash" : "pin")
                        .font(.system(size: 12))
                        .foregroundStyle(
                            item.isPinned
                                ? Color(red: 0.08, green: 0.72, blue: 0.66)
                                : .secondary
                        )
                        .frame(width: 24, alignment: .center)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .help(item.isPinned ? "Unpin" : "Pin to top")
            }
        }
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var sourceIcon: some View {
        if let bundleID = item.sourceAppBundleID,
           let img = SourceAppTracker.appIcon(bundleID: bundleID) {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 4))
        } else {
            Image(systemName: "app")
                .font(.system(size: 14))
                .foregroundStyle(.quaternary)
        }
    }

    private var typeIcon: some View {
        Image(systemName: item.type.systemImage)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(item.type.accentColor)
            .frame(width: 14)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item.preview)
                .font(.system(size: 12))
                .lineLimit(item.type == .image ? 1 : 2)
                .foregroundStyle(.primary)
            if let app = item.sourceAppName {
                Text(app)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func colorSwatch(_ color: Color) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(color)
            .frame(width: 22, height: 22)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
    }

    private func togglePin() {
        item.isPinned.toggle()
        try? modelContext.save()
    }
}
