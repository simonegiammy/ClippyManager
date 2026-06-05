import SwiftUI
import AppKit

/// Right-hand detail pane: large preview, metadata, and a Copy button.
struct DetailPaneView: View {
    let item: ClipItem
    var onClose: (() -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.cardBorder)
            ScrollView { previewBlock.padding(16) }
            Divider().overlay(Theme.cardBorder)
            metadata
            footer
        }
        .background(Theme.panelBackgroundElevated)
    }

    private var header: some View {
        HStack {
            Label(item.type.label, systemImage: item.type.systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(item.type.accentColor)
            Spacer()
            Button { toggleFavorite() } label: {
                Image(systemName: item.isPinned ? "star.fill" : "star")
                    .foregroundStyle(item.isPinned ? Theme.accent : Theme.textSecondary)
            }
            .buttonStyle(.plain)
            if let onClose {
                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private var previewBlock: some View {
        switch item.type {
        case .image, .screenshot:
            if let img = item.nsImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        case .color:
            VStack(spacing: 10) {
                if let hex = item.colorHex, let c = Color(hex: hex) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(c)
                        .frame(height: 120)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder))
                }
                Text(item.preview)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.textPrimary)
                    .textSelection(.enabled)
            }
        case .code:
            Text(item.preview)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Color(red: 0.7, green: 0.85, blue: 0.7))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        default:
            Text(item.isSensitive ? "•••••• (sensitive content hidden)" : item.preview)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var metadata: some View {
        VStack(spacing: 8) {
            metaRow("Date", value: item.createdAt.formatted(date: .abbreviated, time: .shortened))
            if let app = item.sourceAppName {
                metaRow("Source", value: app)
            }
            if let url = item.sourceURL {
                metaRow("URL", value: url)
            }
            if item.byteSize > 0 {
                metaRow("Size", value: item.formattedSize)
            }
        }
        .padding(12)
    }

    private func metaRow(_ key: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var footer: some View {
        Button { PasteService.copy(item) } label: {
            Label("Copy to clipboard", systemImage: "doc.on.doc")
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .padding(12)
    }

    private func toggleFavorite() {
        item.isPinned.toggle()
        try? modelContext.save()
    }
}
