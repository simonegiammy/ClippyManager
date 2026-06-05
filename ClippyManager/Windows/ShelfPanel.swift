import AppKit

/// Borderless floating panel for the notch shelf. Can become key so the
/// search field and clicks work, and floats above other windows on all spaces.
final class ShelfPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .mainMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Position the panel centered horizontally, just under the menu bar / notch.
    func positionUnderNotch() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let size = frame.size
        let x = visible.midX - size.width / 2
        let y = visible.maxY - size.height - 8
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
