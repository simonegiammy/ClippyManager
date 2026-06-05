import AppKit
import Carbon.HIToolbox

/// Writes a clip back to the system pasteboard and optionally simulates ⌘V.
enum PasteService {

    /// Copy the item to the clipboard. Notifies the monitor so it isn't re-captured.
    static func copy(_ item: ClipItem) {
        NotificationCenter.default.post(name: ClipboardMonitor.appDidCopy, object: nil)
        let pb = NSPasteboard.general
        pb.clearContents()

        switch item.type {
        case .image, .screenshot:
            if let img = item.nsImage { pb.writeObjects([img]) }
        case .file:
            if let paths = item.textContent {
                let urls = paths.components(separatedBy: "\n").map { URL(fileURLWithPath: $0) as NSURL }
                pb.writeObjects(urls)
            }
        default:
            if let text = item.textContent { pb.setString(text, forType: .string) }
        }
    }

    /// Copy then simulate a ⌘V paste into the frontmost app.
    /// Requires Accessibility permission; silently no-ops without it.
    static func pasteIntoFrontmostApp(_ item: ClipItem) {
        copy(item)
        guard AXIsProcessTrusted() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            simulateCommandV()
        }
    }

    /// Copy arbitrary text (e.g. an AI-transformed result) to the clipboard.
    static func copy(text: String) {
        NotificationCenter.default.post(name: ClipboardMonitor.appDidCopy, object: nil)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }

    /// Copy arbitrary text then simulate ⌘V into the frontmost app.
    static func pasteText(_ text: String) {
        copy(text: text)
        guard AXIsProcessTrusted() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            simulateCommandV()
        }
    }

    private static func simulateCommandV() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
