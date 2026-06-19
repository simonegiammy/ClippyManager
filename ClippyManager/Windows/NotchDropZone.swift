import AppKit
import UniformTypeIdentifiers

/// A thin, always-on-top pill pinned under the notch.
/// - Dragging content over it opens the shelf (drop-to-save).
/// - Hovering the mouse over it (no drag) peeks the shelf so you can grab clips.
final class NotchDropZone: NSPanel {
    private let zoneView: DropZoneView

    init(onDragEnter: @escaping () -> Void,
         onHover: @escaping () -> Void,
         onDrop: @escaping (NSPasteboard) -> Bool) {
        zoneView = DropZoneView(onDragEnter: onDragEnter, onHover: onHover, onDrop: onDrop)
        super.init(
            // Taller target (52pt) so a dragged file is easy to land on the notch.
            contentRect: NSRect(x: 0, y: 0, width: 240, height: 52),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        // popUpMenu level floats above normal windows but is BELOW the shielding
        // level — the shielding/maximum level silently breaks Finder drag delivery,
        // which is why dropping a file did nothing. Hover-open still works over
        // fullscreen via the global mouse monitor (Space-agnostic).
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.popUpMenuWindow)))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
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
        let full = screen.frame
        let size = frame.size
        let x = full.midX - size.width / 2
        // Flush with the very top of the screen so the hover zone sits ON the
        // physical notch (not the menu-bar strip below it).
        let y = full.maxY - size.height
        setFrameOrigin(NSPoint(x: x, y: y))
    }
}

/// The subtle pill that accepts drags and detects hover-intent.
private final class DropZoneView: NSView {
    private let onDragEnter: () -> Void
    private let onHover: () -> Void
    private let onDrop: (NSPasteboard) -> Bool
    var isHoverEnabled = true

    private var isTargeted = false { didSet { needsDisplay = true } }
    private var isMouseInside = false { didSet { needsDisplay = true } }
    private var hoverWork: DispatchWorkItem?

    init(onDragEnter: @escaping () -> Void, onHover: @escaping () -> Void,
         onDrop: @escaping (NSPasteboard) -> Bool) {
        self.onDragEnter = onDragEnter
        self.onHover = onHover
        self.onDrop = onDrop
        super.init(frame: .zero)
        registerForDraggedTypes([
            .fileURL, .png, .tiff, .string,
            NSPasteboard.PasteboardType("public.image")
        ])
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        // Invisible by default — the physical black notch IS the affordance, like
        // NotchDock. Only show a faint accent tint while a drag hovers over it.
        guard isTargeted else { return }
        let inset = bounds.insetBy(dx: 2, dy: 6)
        let path = NSBezierPath(roundedRect: inset, xRadius: inset.height / 2, yRadius: inset.height / 2)
        NSColor.controlAccentColor.withAlphaComponent(0.85).setFill()
        path.fill()
    }

    // MARK: - Hover intent

    override func mouseEntered(with event: NSEvent) {
        isMouseInside = true
        guard isHoverEnabled else { return }
        // Snappy, like NotchDock — barely any delay before it grows.
        let work = DispatchWorkItem { [weak self] in self?.onHover() }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
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

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isTargeted = false
        return onDrop(sender.draggingPasteboard)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) { isTargeted = false }
    override func draggingEnded(_ sender: NSDraggingInfo) { isTargeted = false }
}
