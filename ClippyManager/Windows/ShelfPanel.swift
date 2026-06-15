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
        hasShadow = false   // the SwiftUI NotchShape carries its own shadow
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .none   // we animate the grow ourselves in SwiftUI
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Pin the panel to the very top, centered on the notch — its pill aligns
    /// with the physical notch and the body grows down from there.
    func positionUnderNotch() {
        guard let screen = NSScreen.main else { return }
        let full = screen.frame
        let size = frame.size
        let x = full.midX - size.width / 2
        let y = full.maxY - size.height   // top edge flush with the screen top
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}
