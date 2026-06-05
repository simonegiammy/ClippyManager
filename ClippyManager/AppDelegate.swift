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

    private var shelfPanel: ShelfPanel?
    private var libraryWindow: NSWindow?
    private var notchDropZone: NotchDropZone?
    private var localClickMonitor: Any?
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        hotKeyManager?.unregister()
        removeClickMonitor()
    }

    // MARK: - Setup

    private func setupContainer() {
        do {
            container = try ModelContainer(for: ClipItem.self, Category.self)
        } catch {
            fatalError("SwiftData init failed: \(error)")
        }
        storageManager = StorageManager(container: container)
        licenseManager = LicenseManager()
        storeManager = StoreManager(license: licenseManager)
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
                DispatchQueue.main.async { self?.toggleShelf() }
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

        let hoverItem = NSMenuItem(
            title: "Hover to Open", action: #selector(menuToggleHover), keyEquivalent: ""
        )
        hoverItem.state = hoverToOpenEnabled ? .on : .off
        menu.addItem(hoverItem)

        menu.addItem(.separator())

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
    @objc private func menuToggleHover() {
        hoverToOpenEnabled.toggle()
        notchDropZone?.isHoverEnabled = hoverToOpenEnabled
    }
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
        guard win === libraryWindow || win === upgradeWindow else { return }
        if win === upgradeWindow { upgradeWindow = nil }
        // Return to menu-bar-only mode when no managed window remains open.
        if (libraryWindow?.isVisible != true) && (upgradeWindow?.isVisible != true) {
            NSApp.setActivationPolicy(.accessory)
        }
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

    // MARK: - Recent paste (⌃⌘0–9)

    private func pasteRecent(_ index: Int) {
        let recents = storageManager.recentItems(limit: 10)
        guard index < recents.count else { return }
        PasteService.pasteIntoFrontmostApp(recents[index])
    }

    // MARK: - Helpers

    private func removeClickMonitor() {
        if let m = localClickMonitor {
            NSEvent.removeMonitor(m)
            localClickMonitor = nil
        }
    }
}
