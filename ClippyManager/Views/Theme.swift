import SwiftUI

/// Dark glassmorphic design system inspired by Supaste.
enum Theme {
    // MARK: - Colors

    /// Near-black glass panel background.
    static let panelBackground = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let panelBackgroundElevated = Color(red: 0.11, green: 0.11, blue: 0.12)

    /// Card surfaces.
    static let cardBackground = Color(red: 0.14, green: 0.14, blue: 0.16)
    static let cardBackgroundHover = Color(red: 0.18, green: 0.18, blue: 0.20)
    static let cardBorder = Color.white.opacity(0.08)

    /// Pills / chips.
    static let pillInactive = Color.white.opacity(0.08)
    static let pillActive = Color.white
    static let pillActiveText = Color.black
    static let pillInactiveText = Color.white.opacity(0.85)

    /// Text.
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.6)
    static let textTertiary = Color.white.opacity(0.35)

    /// Brand accent — the Supaste blue.
    static let accent = Color(red: 0.0, green: 0.5, blue: 1.0)
    static let accentSoft = Color(red: 0.0, green: 0.5, blue: 1.0).opacity(0.18)

    /// Selection ring.
    static let selection = Color(red: 0.0, green: 0.5, blue: 1.0)

    // MARK: - Metrics

    static let cardRadius: CGFloat = 12
    static let panelRadius: CGFloat = 20
    static let pillRadius: CGFloat = 999

    // MARK: - Helpers

    /// Human-readable byte size, e.g. "10 MB", "424 bytes".
    static func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) bytes" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Glass background modifier

struct GlassPanelBackground: ViewModifier {
    var cornerRadius: CGFloat = Theme.panelRadius

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Theme.panelBackground.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = Theme.panelRadius) -> some View {
        modifier(GlassPanelBackground(cornerRadius: cornerRadius))
    }
}
