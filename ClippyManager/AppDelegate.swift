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
        popover.behavior = .semitransient
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
            DispatchQueue.main.async {
                self?.togglePopover(nil)
            }
        }
        hotKeyManager.register()
    }

    // MARK: - Toggle

    @objc func togglePopover(_ sender: Any?) {
        if popover.isShown {
            popover.performClose(sender)
        } else {
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}
