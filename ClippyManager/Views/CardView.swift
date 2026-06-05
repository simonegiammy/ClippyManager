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
        .background(Theme.cardBackground)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(isSelected ? Theme.selection : Theme.cardBorder,
                        lineWidth: isSelected ? 2 : 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
        .scaleEffect(isHovered ? 1.015 : 1.0)
        .shadow(color: .black.opacity(isHovered ? 0.35 : 0), radius: 10, y: 4)
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
        ZStack {
            LinearGradient(
                colors: [Theme.accent.opacity(0.25), Theme.cardBackground],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.accent)
                Text(item.preview)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        }
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
