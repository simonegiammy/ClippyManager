import SwiftUI

/// "Aurora Glass" design system — frosted glass, vibrancy, warm orange accent.
/// The desktop glows through; every surface speaks the same language.
enum Theme {
    // MARK: - Accent (orange)

    static let accent       = Color(hex: "#FF8A3D")!          // primary orange
    static let accentBright  = Color(hex: "#FF9D4D")!
    static let accentDeep    = Color(hex: "#F56A1C")!
    static let accentSoft    = Color(hex: "#FF8A3D")!.opacity(0.20)

    /// App-icon / glyph gradient stops.
    static let iconGradient = [Color(hex: "#FFC488")!, Color(hex: "#FF8A3D")!, Color(hex: "#EF5E0C")!]
    static let accentGradient = [Color(hex: "#FF9D4D")!, Color(hex: "#F56A1C")!]

    // MARK: - Surfaces

    /// Near-black warm base behind the glass.
    static let base = Color(hex: "#0C0806")!
    static let panelBackground = Color(hex: "#0C0806")!
    static let panelBackgroundElevated = Color(hex: "#140D09")!

    /// Glass tint stops (used by the .glass material).
    static let glassTop = Color(red: 58/255, green: 40/255, blue: 28/255).opacity(0.66)
    static let glassBottom = Color(red: 20/255, green: 13/255, blue: 9/255).opacity(0.76)

    static let cardBackground = Color.white.opacity(0.06)
    static let cardBackgroundHover = Color.white.opacity(0.10)
    static let cardBorder = Color.white.opacity(0.11)
    static let hairline = Color.white.opacity(0.08)

    // Pills / chips
    static let pillInactive = Color.white.opacity(0.07)
    static let pillActive = accentSoft
    static let pillActiveText = Color.white
    static let pillInactiveText = Color.white.opacity(0.60)

    // Text
    static let textPrimary = Color(hex: "#F4F3FB")!
    static let textSecondary = Color(hex: "#F4F3FB")!.opacity(0.60)
    static let textTertiary = Color(hex: "#F4F3FB")!.opacity(0.40)

    static let selection = accent

    // MARK: - Metrics

    static let panelRadius: CGFloat = 18
    static let cardRadius: CGFloat = 14
    static let controlRadius: CGFloat = 11
    static let pillRadius: CGFloat = 999

    // MARK: - Type accent colors (per clip type)

    static func typeColor(_ type: ClipItemType) -> Color {
        switch type {
        case .text:       return Color.white.opacity(0.65)
        case .link:       return Color(hex: "#7FBCFF")!
        case .code:       return Color(hex: "#6FE0A0")!
        case .color:      return Color(hex: "#FFC06B")!
        case .image:      return Color(hex: "#FF9D6B")!
        case .file:       return Color.white.opacity(0.7)
        case .screenshot: return Color(hex: "#FF8A8C")!
        }
    }

    // MARK: - Helpers

    static func formatBytes(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) bytes" }
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - Monospace label (JetBrains Mono feel via system monospaced)

extension Font {
    static func monoLabel(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

// MARK: - Aurora background

struct AuroraBackground: View {
    var body: some View {
        ZStack {
            Theme.base
            // Warm radial glows, mirroring the prototype's aurora.
            RadialGradient(colors: [Color(hex: "#B0612E")!.opacity(0.9), .clear],
                           center: .init(x: 0.18, y: -0.05), startRadius: 0, endRadius: 520)
            RadialGradient(colors: [Color(hex: "#E06A3A")!.opacity(0.8), .clear],
                           center: .init(x: 0.88, y: 0.05), startRadius: 0, endRadius: 460)
            RadialGradient(colors: [Color(hex: "#9C4A1E")!.opacity(0.7), .clear],
                           center: .init(x: 0.55, y: 1.25), startRadius: 0, endRadius: 560)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Glass material modifier

struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = Theme.panelRadius
    var stroke: Bool = true

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .background(
                LinearGradient(colors: [Theme.glassTop, Theme.glassBottom],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(stroke ? 0.13 : 0), lineWidth: 1)
            )
            .overlay( // top inset highlight
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(colors: [Color.white.opacity(0.18), .clear],
                                       startPoint: .top, endPoint: .center),
                        lineWidth: 1
                    )
                    .blendMode(.plusLighter)
                    .opacity(stroke ? 1 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// Edge-to-edge frosted glass for a whole window's content (no margin, no fake
/// chrome — the real macOS window provides the frame & traffic lights).
/// Uses real behind-window vibrancy so the desktop blurs through.
struct GlassWindowFill: View {
    var body: some View {
        AuroraGlassSurface().ignoresSafeArea()
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = Theme.panelRadius) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }

    /// Fill helper for the warm accent gradient.
    func accentGradientFill() -> some View {
        self.foregroundStyle(
            LinearGradient(colors: Theme.accentGradient, startPoint: .topLeading, endPoint: .bottomTrailing)
        )
    }
}

/// A small warm clipboard glyph used in headers/badges.
struct ClippyGlyph: View {
    var size: CGFloat = 24
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.33, style: .continuous)
            .fill(LinearGradient(colors: [Theme.accentBright, Theme.accentDeep],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.2)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: size * 0.36, height: size * 0.46)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.16)
                            .fill(Color.white.opacity(0.42))
                            .frame(width: size * 0.36, height: size * 0.46)
                            .offset(x: size * 0.13, y: -size * 0.13)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.33, style: .continuous)
                    .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
            )
            .frame(width: size, height: size)
    }
}
