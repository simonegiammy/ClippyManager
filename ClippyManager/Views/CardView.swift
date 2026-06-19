import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// A single clipboard item rendered as a Supaste-style card:
/// content preview on top, source-app badge + timestamp + size on the bottom.
struct CardView: View {
    let item: ClipItem
    var isSelected: Bool = false
    var onTap: () -> Void
    var onDoubleTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()

            footer
        }
        .background(isHovered ? Theme.cardBackgroundHover : Theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(isSelected ? Theme.selection : Theme.cardBorder,
                        lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .shadow(color: Theme.accentDeep.opacity(isHovered ? 0.25 : 0), radius: 14, y: 6)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .animation(.easeOut(duration: 0.12), value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onDoubleTap() }
        .onTapGesture { onTap() }
        .onDrag { dragProvider() }
        .help(item.title)
    }

    // MARK: - Preview area

    @ViewBuilder
    private var preview: some View {
        switch item.type {
        case .image, .screenshot:
            if let img = item.nsImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder(icon: item.type.systemImage)
            }
        case .color:
            colorPreview
        case .code:
            codePreview
        case .link:
            linkPreview
        case .file:
            filePreview
        default:
            textPreview
        }
    }

    private var textPreview: some View {
        ZStack(alignment: .topLeading) {
            Theme.cardBackground
            if item.isSensitive {
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Sensitive")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text(item.preview)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(5)
                    .multilineTextAlignment(.leading)
                    .padding(10)
            }
        }
    }

    private var codePreview: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.4)
            Text(item.preview)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color(red: 0.7, green: 0.85, blue: 0.7))
                .lineLimit(6)
                .padding(10)
        }
    }

    private var linkPreview: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Theme.accent.opacity(0.22), Theme.cardBackground],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    FaviconView(host: item.linkHost, size: 22)
                    Text(item.linkHost)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                }
                if !item.linkPath.isEmpty {
                    Text(item.linkPath)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Label("Open", systemImage: "arrow.up.forward.app")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .padding(11)
        }
    }

    /// File and folder cards get a dedicated widget: a folder glyph + item count
    /// for directories, or the macOS file-type icon for files.
    private var filePreview: some View {
        ZStack {
            LinearGradient(colors: [Color.white.opacity(0.08), Theme.cardBackground],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 8) {
                if item.isFolder {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "#7FC3FF")!, Color(hex: "#3A9BFF")!],
                                                        startPoint: .top, endPoint: .bottom))
                    if let count = folderCount {
                        Text(count)
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textTertiary)
                    }
                } else if let icon = item.fileIcon {
                    Image(nsImage: icon)
                        .resizable().scaledToFit()
                        .frame(width: 44, height: 44)
                } else {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.textTertiary)
                }
                Text(item.preview)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.vertical, 10)
        }
    }

    private var folderCount: String? {
        guard item.isFolder, let first = item.filePaths.first else { return nil }
        let items = (try? FileManager.default.contentsOfDirectory(atPath: first))?.count
        return items.map { "\($0) item\($0 == 1 ? "" : "s")" }
    }

    private var colorPreview: some View {
        ZStack {
            if let hex = item.colorHex, let color = Color(hex: hex) {
                color
                VStack {
                    Spacer()
                    Text(item.preview)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                        .padding(.bottom, 8)
                }
            } else {
                placeholder(icon: "paintpalette.fill")
            }
        }
    }

    private func placeholder(icon: String) -> some View {
        ZStack {
            Theme.cardBackground
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    // MARK: - Footer (source + time + size)

    private var footer: some View {
        HStack(spacing: 6) {
            sourceBadge
            Text(item.relativeTime)
                .font(.system(size: 9))
                .foregroundStyle(Theme.textTertiary)
            Spacer(minLength: 0)
            if item.byteSize > 0 {
                Text(item.formattedSize)
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textTertiary)
            }
            if item.isPinned {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.25))
    }

    @ViewBuilder
    private var sourceBadge: some View {
        if let bundleID = item.sourceAppBundleID,
           let icon = SourceAppTracker.appIcon(bundleID: bundleID) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 14, height: 14)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        } else {
            Image(systemName: item.type.systemImage)
                .font(.system(size: 9))
                .foregroundStyle(item.type.accentColor)
                .frame(width: 14, height: 14)
        }
    }

    // MARK: - Drag out

    private func dragProvider() -> NSItemProvider {
        if let img = item.nsImage {
            return NSItemProvider(object: img)
        }
        if item.type == .file, let paths = item.textContent {
            let first = paths.components(separatedBy: "\n").first ?? paths
            let url = URL(fileURLWithPath: first)
            return NSItemProvider(contentsOf: url) ?? NSItemProvider(object: first as NSString)
        }
        return NSItemProvider(object: (item.textContent ?? "") as NSString)
    }
}
