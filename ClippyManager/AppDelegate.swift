import AppKit
import SwiftUI
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private var container: ModelContainer!
    private var storageManager: StorageManager!
    private var clipboardMonitor: ClipboardMonitor!
    private var hotKeyManager: HotKeyManager!
    private var licenseManager: LicenseManager!
    private var storeManager: StoreManager!
    private var upgradeWindow: NSWindow?
    private var settingsWindow: NSWindow?

    private var shelfPanel: ShelfPanel?
    private var libraryWindow: NSWindow?
    private var notchDropZone: NotchDropZone?
    private var localClickMonitor: Any?

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

        // Debug-only: open a surface immediately for screenshots/testing.
        if CommandLine.arguments.contains("--open-library") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.openLibrary() }
        }
        if CommandLine.arguments.contains("--open-shelf") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.openShelf() }
        }
        if CommandLine.arguments.contains("--open-upgrade") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.openUpgrade() }
        }
        if CommandLine.arguments.contains("--open-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in self?.openSettings() }
        }
        if CommandLine.arguments.contains("--open-palette") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in self?.openPastePalette() }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        hotKeyManager?.unregister()
        removeClickMonitor()
    }

    // MARK: - Setup

    private func setupContainer() {
        do {
            container = try ModelContainer(for: ClipItem.self, Category.self, CustomPrompt.self)
        } catch {
            fatalError("SwiftData init failed: \(error)")
        }
        storageManager = StorageManager(container: container)
        licenseManager = LicenseManager()
        storeManager = StoreManager(license: licenseManager)
        aiAvailability = AIAvailability()
        aiEngine = AIEngine()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        let img = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Clippy")!
        img.isTemplate = true
        button.image = img
        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
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
            }
        )
        zone.isHoverEnabled = hoverToOpenEnabled
        zone.position()
        zone.orderFront(nil)
        notchDropZone = zone

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

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showStatusMenu()
        } else {
            toggleShelf()
        }
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Shelf  (⌃⌘V)", action: #selector(menuToggleShelf), keyEquivalent: "")
        menu.addItem(withTitle: "Open Library", action: #selector(menuOpenLibrary), keyEquivalent: "")
        menu.addItem(.separator())
        let pauseItem = NSMenuItem(
            title: storageManager.isCapturePaused ? "Resume Capture" : "Pause Capture",
            action: #selector(menuTogglePause), keyEquivalent: ""
        )
        menu.addItem(pauseItem)

        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(menuOpenSettings), keyEquivalent: ",")
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)

        let statusLine = NSMenuItem(title: licenseManager.statusSummary, action: nil, keyEquivalent: "")
        statusLine.isEnabled = false
        menu.addItem(statusLine)
        let unlockTitle = licenseManager.isPurchased ? "Licensing…" : "Unlock Lifetime / Promo…"
        menu.addItem(withTitle: unlockTitle, action: #selector(menuOpenUpgrade), keyEquivalent: "")

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Clippy", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        menu.items.last?.target = NSApp
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil   // reset so left-click toggles next time
    }

    @objc private func menuToggleShelf() { toggleShelf() }
    @objc private func menuOpenLibrary() { openLibrary() }
    @objc private func menuTogglePause() { storageManager.isCapturePaused.toggle() }
    @objc private func menuOpenSettings() { openSettings() }
    @objc private func menuOpenUpgrade() { openUpgrade() }

    // MARK: - Shelf

    private func toggleShelf() {
        if let panel = shelfPanel, panel.isVisible {
            closeShelf()
        } else {
            shelfHoverActivated = false   // explicit open → stays until clicked away
            openShelf()
        }
    }

    /// Open the shelf from a hover (peek). Auto-closes when the mouse leaves.
    private func peekShelf() {
        guard hoverToOpenEnabled else { return }
        if let panel = shelfPanel, panel.isVisible { return }
        shelfHoverActivated = true
        openShelf()
    }

    private func openShelf() {
        let panel = shelfPanel ?? makeShelfPanel()
        shelfPanel = panel
        panel.positionUnderNotch()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        // Close when clicking outside the shelf
        removeClickMonitor()
        localClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closeShelf()
        }
    }

    private func closeShelf() {
        shelfPanel?.orderOut(nil)
        removeClickMonitor()
    }

    private func makeShelfPanel() -> ShelfPanel {
        let panel = ShelfPanel(contentRect: NSRect(x: 0, y: 0, width: 720, height: 230))
        panel.appearance = NSAppearance(named: .darkAqua)
        let root = ShelfView(
            onOpenLibrary: { [weak self] in self?.closeShelf(); self?.openLibrary() },
            onClose: { [weak self] in self?.closeShelf() },
            onOpenUpgrade: { [weak self] in self?.closeShelf(); self?.openUpgrade() },
            shouldAutoCloseOnLeave: { [weak self] in self?.shelfHoverActivated ?? false }
        )
        .environment(storageManager)
        .environment(licenseManager)
        .environment(storeManager)
        .modelContainer(container)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = panel.contentLayoutRect
        hosting.autoresizingMask = [.width, .height]
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

        let root = LibraryView(onOpenUpgrade: { [weak self] in self?.openUpgrade() })
            .environment(storageManager)
            .environment(licenseManager)
            .environment(storeManager)
            .modelContainer(container)

        let hosting = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Clippy Library"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
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
        guard win === libraryWindow || win === upgradeWindow || win === settingsWindow else { return }
        if win === upgradeWindow { upgradeWindow = nil }
        if win === settingsWindow { settingsWindow = nil }
        // Return to menu-bar-only mode when no managed window remains open.
        let anyVisible = (libraryWindow?.isVisible == true) ||
                         (upgradeWindow?.isVisible == true) ||
                         (settingsWindow?.isVisible == true)
        if !anyVisible { NSApp.setActivationPolicy(.accessory) }
    }

    // MARK: - Upgrade / licensing window

    private func openUpgrade() {
        NSApp.setActivationPolicy(.regular)
        if let win = upgradeWindow {
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
            return
        }
        let root = UpgradeView(onClose: { [weak self] in self?.upgradeWindow?.close() })
            .environment(licenseManager)
            .environment(storeManager)

        let hosting = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Unlock Clippy"
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
        win.titleVisibility = .hidden
        win.isReleasedWhenClosed = false
        win.appearance = NSAppearance(named: .darkAqua)
        win.delegate = self
        win.center()
        upgradeWindow = win
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    // MARK: - Settings window

    private func openSettings() {
        NSApp.setActivationPolicy(.regular)
        if let win = settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
            return
        }
        let root = SettingsView(onOpenUpgrade: { [weak self] in self?.openUpgrade() })
            .environment(storageManager)
            .environment(licenseManager)
            .environment(aiAvailability)

        let hosting = NSHostingController(rootView: root)
        let win = NSWindow(contentViewController: hosting)
        win.title = "Settings"
        win.styleMask = [.titled, .closable, .fullSizeContentView]
        win.titlebarAppearsTransparent = true
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
