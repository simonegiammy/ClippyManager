import SwiftUI
import AppKit

/// A true macOS vibrancy backdrop that blurs the DESKTOP behind the window
/// (`.behindWindow`). SwiftUI's `.ultraThinMaterial` only blurs content within
/// the window's own hierarchy, which renders near-black inside a transparent
/// panel — this is what gives the real frosted-glass look.
struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = blending
        v.state = .active
        v.isEmphasized = true
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
        v.blendingMode = blending
        v.state = .active
    }
}

/// The Aurora Glass surface: real desktop vibrancy + a light warm veil + a soft
/// orange bleed from the top. Used by every window/panel so they all match.
struct AuroraGlassSurface: View {
    var body: some View {
        ZStack {
            VisualEffectBackground(material: .hudWindow)
            // Light warm veil — keeps text legible without hiding the blur.
            LinearGradient(
                colors: [Color(red: 58/255, green: 40/255, blue: 28/255).opacity(0.34),
                         Color(red: 20/255, green: 13/255, blue: 9/255).opacity(0.46)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [Theme.accent.opacity(0.16), .clear],
                           center: .init(x: 0.5, y: 0), startRadius: 0, endRadius: 480)
        }
    }
}
