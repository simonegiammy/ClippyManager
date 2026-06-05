import SwiftUI

/// A compact vertical row in the paste palette list.
struct PaletteRowView: View {
    let item: ClipItem
    let isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            sourceBadge
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.isSensitive ? "•••••• (sensitive)" : item.title)
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Label(item.type.label, systemImage: item.type.systemImage)
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 10))
                        .foregroundStyle(item.type.accentColor)
                    if let app = item.sourceAppName {
                        Text("· \(app)")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            Text(item.relativeTime)
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isFocused ? Theme.accentSoft : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Theme.accent.opacity(0.6) : Color.clear, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var sourceBadge: some View {
        if item.type.isVisual, let img = item.nsImage {
            Image(nsImage: img).resizable().scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 5))
        } else if let bundleID = item.sourceAppBundleID,
                  let icon = SourceAppTracker.appIcon(bundleID: bundleID) {
            Image(nsImage: icon).resizable().frame(width: 18, height: 18)
        } else {
            Image(systemName: item.type.systemImage)
                .font(.system(size: 12))
                .foregroundStyle(item.type.accentColor)
        }
    }
}
