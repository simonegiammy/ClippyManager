import AppKit
import UniformTypeIdentifiers

/// A thin, always-on-top pill pinned under the notch. Dragging any content over
/// it opens the shelf so the user can drop items directly into Clippy.
final class NotchDropZone: NSPanel {
    private let zoneView: DropZoneView

    init(onDragEnter: @escaping () -> Void) {
        zoneView = DropZoneView(onDragEnter: onDragEnter)
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 16),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .mainMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        contentView = zoneView
        appearance = NSAppearance(named: .darkAqua)
    }

    override var canBecomeKey: Bool { false }

    func position() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let full = screen.frame
        let size = frame.size
        let x = full.midX - size.width / 2
        // Just below the menu bar / notch
        let y = visible.maxY - size.height + 2
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// The drag-accepting view shown as a subtle pill.
private final class DropZoneView: NSView {
    private let onDragEnter: () -> Void
    private var isTargeted = false { didSet { needsDisplay = true } }

    init(onDragEnter: @escaping () -> Void) {
        self.onDragEnter = onDragEnter
        super.init(frame: .zero)
        registerForDraggedTypes([
            .fileURL, .png, .tiff, .string,
            NSPasteboard.PasteboardType("public.image")
        ])
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let inset = bounds.insetBy(dx: 2, dy: 4)
        let path = NSBezierPath(roundedRect: inset, xRadius: inset.height / 2, yRadius: inset.height / 2)
        (isTargeted ? NSColor.controlAccentColor : NSColor.white.withAlphaComponent(0.22)).setFill()
        path.fill()
    }

    // MARK: - Dragging destination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isTargeted = true
        onDragEnter()
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isTargeted = false
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        isTargeted = false
    }

    // Hover affordance: brighten the pill on mouse-over.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        ))
    }
}
