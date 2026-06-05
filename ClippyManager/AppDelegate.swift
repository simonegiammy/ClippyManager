import AppKit
import SwiftUI
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var container: ModelContainer!
    private var storageManager: StorageManager!
    private var clipboardMonitor: ClipboardMonitor!
    private var hotKeyManager: HotKeyManager!

    private var shelfPanel: ShelfPanel?
    private var libraryWindow: NSWindow?
    private var notchDropZone: NotchDropZone?
    private var localClickMonitor: Any?

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupContainer()
        setupStatusItem()
        setupClipboardMonitor()
        setupHotKeys()
        setupNotchDropZone()
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
        let zone = NotchDropZone(onDragEnter: { [weak self] in
            DispatchQueue.main.async { self?.openShelf() }
        })
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

    // MARK: - Shelf

    private func toggleShelf() {
        if let panel = shelfPanel, panel.isVisible {
            closeShelf()
        } else {
            openShelf()
        }
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
            onClose: { [weak self] in self?.closeShelf() }
        )
        .environment(storageManager)
        .modelContainer(container)

        let hosting = NSHostingView(rootView: root)
        hosting.frame = panel.contentLayoutRect
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        return panel
    }

    // MARK: - Library window

    private func openLibrary() {
        if let win = libraryWindow {
            NSApp.activate(ignoringOtherApps: true)
            win.makeKeyAndOrderFront(nil)
            return
        }

        let root = LibraryView()
            .environment(storageManager)
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
        libraryWindow = win

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
