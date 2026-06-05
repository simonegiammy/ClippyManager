import AppKit
import UniformTypeIdentifiers

/// A thin, always-on-top pill pinned under the notch.
/// - Dragging content over it opens the shelf (drop-to-save).
/// - Hovering the mouse over it (no drag) peeks the shelf so you can grab clips.
final class NotchDropZone: NSPanel {
    private let zoneView: DropZoneView

    init(onDragEnter: @escaping () -> Void, onHover: @escaping () -> Void) {
        zoneView = DropZoneView(onDragEnter: onDragEnter, onHover: onHover)
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 18),
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

    /// Whether hovering (without dragging) should peek the shelf.
    var isHoverEnabled: Bool {
        get { zoneView.isHoverEnabled }
        set { zoneView.isHoverEnabled = newValue }
    }

    func position() {
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let full = screen.frame
        let size = frame.size
        let x = full.midX - size.width / 2
        let y = visible.maxY - size.height + 2   // just below the menu bar / notch
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// The subtle pill that accepts drags and detects hover-intent.
private final class DropZoneView: NSView {
    private let onDragEnter: () -> Void
    private let onHover: () -> Void
    var isHoverEnabled = true

    private var isTargeted = false { didSet { needsDisplay = true } }
    private var isMouseInside = false { didSet { needsDisplay = true } }
    private var hoverWork: DispatchWorkItem?

    init(onDragEnter: @escaping () -> Void, onHover: @escaping () -> Void) {
        self.onDragEnter = onDragEnter
        self.onHover = onHover
        super.init(frame: .zero)
        registerForDraggedTypes([
            .fileURL, .png, .tiff, .string,
            NSPasteboard.PasteboardType("public.image")
        ])
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let inset = bounds.insetBy(dx: 2, dy: 5)
        let path = NSBezierPath(roundedRect: inset, xRadius: inset.height / 2, yRadius: inset.height / 2)
        let color: NSColor
        if isTargeted {
            color = .controlAccentColor
        } else if isMouseInside {
            color = NSColor.white.withAlphaComponent(0.5)
        } else {
            color = NSColor.white.withAlphaComponent(0.22)
        }
        color.setFill()
        path.fill()
    }

    // MARK: - Hover intent

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        guard isHoverEnabled else { return }
        let work = DispatchWorkItem { [weak self] in self?.onHover() }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }

    override func mouseExited(with event: NSEvent) {
        isMouseInside = false
        hoverWork?.cancel()
        hoverWork = nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self
        ))
    }

    // MARK: - Dragging destination

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isTargeted = true
        onDragEnter()
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { isTargeted = false }
    override func draggingEnded(_ sender: NSDraggingInfo) { isTargeted = false }
}
