import AppKit

/// Keyboard-first vertical palette panel (Raycast/Alfred-like), centered on screen.
final class PastePalettePanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .modalPanel
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false   // the SwiftUI rounded shape carries its own shadow
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        appearance = NSAppearance(named: .darkAqua)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Centered, slightly above middle (command-palette placement).
    func positionCentered() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = frame.size
        let x = visible.midX - size.width / 2
        let y = visible.midY - size.height / 2 + visible.height * 0.10
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
