import AppKit
import SwiftUI
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var container: ModelContainer!
    private var storageManager: StorageManager!
    private var clipboardMonitor: ClipboardMonitor!
    private var hotKeyManager: HotKeyManager!
    private var settingsWindow: NSWindow?

    private var shelfPanel: ShelfPanel?
    private var libraryWindow: NSWindow?
    private var notchDropZone: NotchDropZone?
    private var localClickMonitor: Any?
    private let shelfController = ShelfController()
    private var shelfCloseWork: DispatchWorkItem?
    private var notchHoverMonitor: Any?       // global mouse-move watcher (Space-agnostic)
    private var pointerInsideNotch = false

    // AI paste palette
    private var aiAvailability: AIAvailability!
    private var aiEngine: AIEngine!
    private var palettePanel: PastePalettePanel?
    private var paletteClickMonitor: Any?
    private var shelfHoverActivated = false   // shelf opened via hover → auto-closes on leave

    private var hoverToOpenEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "hoverToOpen") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "hoverToOpen") }
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupContainer()
        setupStatusItem()
        setupClipboardMonitor()
        setupHotKeys()
        setupNotchDropZone()

        #if DEBUG
        // Debug-only: open a surface immediately for screenshots/testing.
        if CommandLine.arguments.contains("--open-library") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.openLibrary() }
        }
        if CommandLine.arguments.contains("--open-shelf") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.openShelf() }
        }
        if CommandLine.arguments.contains("--open-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.openSettings() }
        }
        if CommandLine.arguments.contains("--open-palette") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.openPastePalette() }
        }
        #endif
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        hotKeyManager?.unregister()
        removeClickMonitor()
        if let m = notchHoverMonitor { NSEvent.removeMonitor(m); notchHoverMonitor = nil }
    }

    // MARK: - Setup

    private func setupContainer() {
        do {
            container = try ModelContainer(for: ClipItem.self, Category.self, CustomPrompt.self)
        } catch {
            fatalError("SwiftData init failed: \(error)")
        }
        storageManager = StorageManager(container: container)
        aiAvailability = AIAvailability()
        aiEngine = AIEngine()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        // The orange Clippy app icon (full color, not a template glyph).
        let img = NSImage(named: "MenuBarIcon") ?? NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clippy")!
        img.isTemplate = false
        img.size = NSSize(width: 18, height: 18)
        button.image = img
        // Standard macOS menu-bar behavior: any click opens the menu (with the
        // button highlighted), exactly like a normal menu-bar app.
        statusItem.menu = makeStatusMenu()
    }

    private func setupClipboardMonitor() {
        clipboardMonitor = ClipboardMonitor(storageManager: storageManager)
        clipboardMonitor.start()
    }

    private func setupHotKeys() {
        hotKeyManager = HotKeyManager(
            onToggle: { [weak self] in
                DispatchQueue.main.async { self?.togglePastePalette() }
            },
            onSelection: { [weak self] in
                DispatchQueue.main.async { self?.transformSelectionInPlace() }
            },
            onRecent: { [weak self] index in
                DispatchQueue.main.async { self?.pasteRecent(index) }
            }
        )
        hotKeyManager.register()
    }

    private func setupNotchDropZone() {
        let zone = NotchDropZone(
            onDragEnter: { [weak self] in
                DispatchQueue.main.async { self?.openShelf() }
            },
            onHover: { [weak self] in
                DispatchQueue.main.async { self?.peekShelf() }
            },
            onDrop: { [weak self] pb in
                guard let self else { return false }
                let ok = DropIngestor.ingest(pasteboard: pb, into: self.storageManager)
                if ok { self.openShelf() }   // reveal the freshly-saved item
                return ok
            }
        )
        zone.isHoverEnabled = hoverToOpenEnabled
        zone.position()
        zone.orderFront(nil)
        notchDropZone = zone

        // Global mouse monitor: the NSTrackingArea inside NotchDropZone does NOT
        // receive events when another app owns the active Space (e.g. a real
        // fullscreen app), so hover-to-open would silently fail there. A global
        // monitor sees the pointer regardless of Space and drives open/close.
        notchHoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.handleGlobalMouseMove()
        }

        // Reposition if the screen layout changes.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.notchDropZone?.position()
        }

        // React to the hover toggle changed from Settings.
        NotificationCenter.default.addObserver(
            forName: .clippyHoverSettingChanged, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.notchDropZone?.isHoverEnabled = self.hoverToOpenEnabled
        }
    }

    // MARK: - Status item menu / click

    /// Builds the standard menu-bar menu. Its delegate (self) refreshes the
    /// dynamic Pause item each time it's about to open.
    private func makeStatusMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "Open Shelf  (⌃⌘V)", action: #selector(menuToggleShelf), keyEquivalent: "")
        menu.addItem(withTitle: "Open Library", action: #selector(menuOpenLibrary), keyEquivalent: "")
        menu.addItem(.separator())

        let pauseItem = NSMenuItem(title: "Pause Capture", action: #selector(menuTogglePause), keyEquivalent: "")
        pauseItem.tag = 1   // looked up in menuWillOpen to set the right title
        menu.addItem(pauseItem)

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(menuOpenSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Clippy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)

        // Action items target self (the Quit item keeps its NSApp target).
        for item in menu.items where item.action != nil && item !== quit {
            item.target = self
        }
        return menu
    }

    @objc private func menuToggleShelf() { toggleShelf() }
    @objc private func menuOpenLibrary() { openLibrary() }
    @objc private func menuTogglePause() { storageManager.isCapturePaused.toggle() }
    @objc private func menuOpenSettings() { openSettings() }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Refresh the dynamic Pause/Resume title each time the menu opens.
        if let pause = menu.item(withTag: 1) {
            pause.title = storageManager.isCapturePaused ? "Resume Capture" : "Pause Capture"
        }
    }

    // MARK: - Shelf

    private func toggleShelf() {
        if shelfController.isOpen {
            closeShelf()
        } else {
            shelfHoverActivated = false   // explicit open → stays until clicked away
            openShelf()
        }
    }

    /// Open the shelf from a hover (peek). Auto-closes when the mouse leaves.
    private func peekShelf() {
        guard hoverToOpenEnabled else { return }
        if shelfController.isOpen { return }
        shelfHoverActivated = true
        openShelf()
    }

    /// Space-agnostic hover detection. Opens when the cursor enters the notch
    /// strip at the top center; closes when it leaves the open shelf's bounds.
    private func handleGlobalMouseMove() {
        guard hoverToOpenEnabled, let screen = NSScreen.main else { return }
        // Cocoa global coords: origin bottom-left. Convert from the event's
        // top-left mouseLocation.
        let m = NSEvent.mouseLocation
        let full = screen.frame

        // Notch trigger strip: ~240pt wide, top ~52pt of the screen.
        let stripW: CGFloat = 240, stripH: CGFloat = 52
        let inStrip = abs(m.x - full.midX) <= stripW / 2 && m.y >= full.maxY - stripH

        if shelfController.isOpen {
            // A sheet / AI preview is up → never auto-close.
            if shelfController.keepOpen { return }
            // Close when the pointer is outside the (open) shelf rect.
            if let panel = shelfPanel {
                let f = panel.frame.insetBy(dx: -8, dy: -8)
                if shelfHoverActivated && !f.contains(m) && !inStrip {
                    closeShelf()
                }
            }
        } else if inStrip {
            shelfHoverActivated = true
            openShelf()
        }
    }

    private func openShelf() {
        shelfCloseWork?.cancel()
        let panel = shelfPanel ?? makeShelfPanel()
        shelfPanel = panel
        panel.positionUnderNotch()
        // Order front WITHOUT activating the app — activating switches Spaces and
        // makes the panel vanish over other apps' fullscreen windows. A
        // non-activating panel at max window level overlays fullscreen instead.
        panel.orderFrontRegardless()
        shelfController.isOpen = true   // drives the grow animation in SwiftUI

        // Close when clicking outside the shelf — unless a sheet / AI preview is up.
        removeClickMonitor()
        localClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            guard let self, !self.shelfController.keepOpen else { return }
            self.closeShelf()
        }
    }

    /// Animate the collapse, THEN order the panel out — so it retracts into the
    /// notch instead of vanishing (the NotchDock behaviour).
    private func closeShelf() {
        removeClickMonitor()
        // Idempotent: if a close is already animating (isOpen already false but a
        // collapse is scheduled), do NOTHING — a second call must not order the
        // panel out immediately and truncate the retract animation.
        guard shelfController.isOpen else { return }
        guard shelfPanel != nil else { return }

        shelfController.isOpen = false   // triggers the reverse animation
        shelfCloseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.shelfPanel?.orderOut(nil)
        }
        shelfCloseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + ShelfController.closeDuration + 0.02, execute: work)
    }

    private func makeShelfPanel() -> ShelfPanel {
        let panel = ShelfPanel(contentRect: NSRect(x: 0, y: 0, width: 720, height: 320))
        panel.appearance = NSAppearance(named: .darkAqua)
        let engine = aiEngine!
        let avail = aiAvailability!
        let root = ShelfView(
            engine: engine,
            availability: avail,
            controller: shelfController,
            onOpenLibrary: { [weak self] in self?.closeShelf(); self?.openLibrary() },
            onClose: { [weak self] in self?.closeShelf() },
            shouldAutoCloseOnLeave: { [weak self] in self?.shelfHoverActivated ?? false }
        )
        .environment(storageManager)
        .modelContainer(container)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = panel.contentLayoutRect
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting
        return panel
    }

    // MARK: - Library window

    private func openLibrary() {
        // A LSUIElement (.accessory) app must switch to .regular for a standard
        // window to appear, gain focus, and show in the Dock/⌘-Tab.
        NSApp.setActivationPolicy(.regular)

        if let win = libraryWindow {
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
            return
        }

        let root = LibraryView(
            onOpenSettings: { [weak self] in self?.openSettings() }
        )
            .environment(storageManager)
            .modelContainer(container)

        let hosting = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Clippy Library"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.backgroundColor = .clear
        win.isOpaque = false
        win.setContentSize(NSSize(width: 900, height: 560))
        win.center()
        win.isReleasedWhenClosed = false
        win.appearance = NSAppearance(named: .darkAqua)
        win.delegate = self
        libraryWindow = win

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        let win = notification.object as? NSWindow
        guard win === libraryWindow || win === settingsWindow else { return }
        if win === settingsWindow { settingsWindow = nil }
        // Return to menu-bar-only mode when no managed window remains open.
        let anyVisible = (libraryWindow?.isVisible == true) ||
                         (settingsWindow?.isVisible == true)
        if !anyVisible { NSApp.setActivationPolicy(.accessory) }
    }

    // MARK: - Settings window

    private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        if let win = settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
            return
        }
        let root = SettingsView()
            .environment(storageManager)
            .environment(aiAvailability)

        let hosting = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Settings"
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.backgroundColor = .clear
        win.isOpaque = false
        win.isReleasedWhenClosed = false
        win.appearance = NSAppearance(named: .darkAqua)
        win.delegate = self
        win.center()
        settingsWindow = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    // MARK: - Recent paste (⌃⌘0–9)

    private func pasteRecent(_ index: Int) {
        let recents = storageManager.recentItems(limit: 10)
        guard index < recents.count else { return }
        PasteService.pasteIntoFrontmostApp(recents[index])
    }

    // MARK: - AI paste palette (⌃⌘V)

    private func togglePastePalette() {
        if let panel = palettePanel, panel.isVisible { closePastePalette() }
        else { openPastePalette() }
    }

    private func openPastePalette() {
        // Capture the DESTINATION app (frontmost now, before we steal focus).
        let tracker = SourceAppTracker()
        tracker.capture()
        let destinationBundleID = tracker.current.bundleID

        aiAvailability.refresh()

        let controller = PaletteController(
            availability: aiAvailability,
            engine: aiEngine,
            destinationBundleID: destinationBundleID,
            onPasteOriginal: { [weak self] item in self?.pasteOriginalFromPalette(item) },
            onPasteText: { [weak self] text, source in self?.pasteTextFromPalette(text, source: source) },
            onClose: { [weak self] in self?.closePastePalette() }
        )
        controller.allItems = storageManager.recentItems(limit: 200)
        controller.customActions = storageManager.customPrompts().map(\.asAction)

        let panel = PastePalettePanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 420))
        let root = PastePaletteView(controller: controller)
            .modelContainer(container)
        let hosting = NSHostingView(rootView: root)
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting
        palettePanel = panel

        panel.positionCentered()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        // Pre-warm the model so the first transform is snappy.
        aiEngine.prewarm()

        // Close on outside click.
        removePaletteClickMonitor()
        paletteClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in self?.closePastePalette() }
    }

    private func closePastePalette() {
        palettePanel?.orderOut(nil)
        palettePanel = nil
        removePaletteClickMonitor()
    }

    // MARK: - Selection-in-place (⌃⌘J)

    private func transformSelectionInPlace() {
        guard SelectionService.hasAccessibility else {
            SelectionService.requestAccessibility()
            return
        }
        // Remember the app we'll paste back into.
        let tracker = SourceAppTracker()
        tracker.capture()
        let targetBundleID = tracker.current.bundleID

        SelectionService.readSelection { [weak self] selected in
            guard let self else { return }
            guard let text = selected, !text.isEmpty else { return }
            self.openSelectionPalette(text: text, targetBundleID: targetBundleID)
        }
    }

    private func openSelectionPalette(text: String, targetBundleID: String?) {
        aiAvailability.refresh()

        // A transient clip wrapping the live selection.
        let transient = ClipItem(type: ContentClassifier().classify(text: text),
                                 textContent: text, sourceAppName: "Selection",
                                 sourceAppBundleID: targetBundleID, byteSize: text.utf8.count)

        let controller = PaletteController(
            availability: aiAvailability,
            engine: aiEngine,
            destinationBundleID: targetBundleID,
            onPasteOriginal: { [weak self] _ in self?.closePastePalette() },  // no-op: keep selection
            onPasteText: { [weak self] result, _ in
                self?.closePastePalette()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    SelectionService.replaceSelection(with: result)
                }
            },
            onClose: { [weak self] in self?.closePastePalette() }
        )
        controller.selectionMode = true
        controller.allItems = [transient]
        controller.customActions = storageManager.customPrompts().map(\.asAction)

        let panel = PastePalettePanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 420))
        let root = PastePaletteView(controller: controller).modelContainer(container)
        let hosting = NSHostingView(rootView: root)
        hosting.autoresizingMask = [.width, .height]
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        panel.contentView = hosting
        palettePanel = panel

        panel.positionCentered()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        aiEngine.prewarm()

        removePaletteClickMonitor()
        paletteClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in self?.closePastePalette() }
    }

    private func removePaletteClickMonitor() {
        if let m = paletteClickMonitor { NSEvent.removeMonitor(m); paletteClickMonitor = nil }
    }

    /// Enter → paste the original clip into the destination app.
    private func pasteOriginalFromPalette(_ item: ClipItem) {
        closePastePalette()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            PasteService.pasteIntoFrontmostApp(item)
        }
    }

    /// ⌘Return in preview → save derived clip (original preserved) + paste result.
    private func pasteTextFromPalette(_ text: String, source: ClipItem) {
        let derived = ClipItem(
            type: .text,
            textContent: text,
            sourceAppName: "AI",
            sourceAppBundleID: source.sourceAppBundleID,
            byteSize: text.utf8.count
        )
        storageManager.add(derived)
        closePastePalette()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            PasteService.pasteText(text)
        }
    }

    // MARK: - Helpers

    private func removeClickMonitor() {
        if let m = localClickMonitor {
            NSEvent.removeMonitor(m)
            localClickMonitor = nil
        }
    }
}
