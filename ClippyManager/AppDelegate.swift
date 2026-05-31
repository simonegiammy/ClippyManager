import AppKit
import SwiftUI
import SwiftData

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var container: ModelContainer!
    private var storageManager: StorageManager!
    private var clipboardMonitor: ClipboardMonitor!
    private var hotKeyManager: HotKeyManager!
    private var eventMonitor: Any?  // monitora click fuori dal popover

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupContainer()
        setupStatusItem()
        setupPopover()
        setupClipboardMonitor()
        setupHotKey()
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        hotKeyManager?.unregister()
        removeEventMonitor()
    }

    // MARK: - Setup

    private func setupContainer() {
        do {
            container = try ModelContainer(for: ClipItem.self)
        } catch {
            fatalError("SwiftData init failed: \(error)")
        }
        storageManager = StorageManager(container: container)
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        let img = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "ClippyManager")!
        img.isTemplate = true
        button.image = img
        button.target = self
        button.action = #selector(togglePopover(_:))
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 360, height: 520)
        // applicationDefined: gestiamo noi apertura/chiusura — più controllo
        // di semitransient che perde il focus silenziosamente
        popover.behavior = .applicationDefined
        popover.animates = true

        let rootView = HistoryPanelView()
            .environment(storageManager)
            .modelContainer(container)

        popover.contentViewController = NSHostingController(rootView: rootView)
    }

    private func setupClipboardMonitor() {
        clipboardMonitor = ClipboardMonitor(storageManager: storageManager)
        clipboardMonitor.start()
    }

    private func setupHotKey() {
        hotKeyManager = HotKeyManager { [weak self] in
            DispatchQueue.main.async { self?.togglePopover(nil) }
        }
        hotKeyManager.register()
    }

    // MARK: - Toggle

    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    private func openPopover() {
        guard let button = statusItem.button else { return }

        // Attiva l'app prima di mostrare il popover
        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

        // La window del popover non è pronta immediatamente dopo show():
        // asyncAfter dà il tempo al run loop di completare il setup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.popover.contentViewController?.view.window?.makeKey()
        }

        // Monitor click fuori dal popover → chiudi
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func closePopover() {
        popover.performClose(nil)
        removeEventMonitor()
    }

    private func removeEventMonitor() {
        if let m = eventMonitor {
            NSEvent.removeMonitor(m)
            eventMonitor = nil
        }
    }
}
