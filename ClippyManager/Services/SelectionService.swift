import AppKit
import Carbon.HIToolbox

/// Reads and replaces the user's current text selection in the frontmost app by
/// simulating ⌘C / ⌘V. Requires Accessibility permission (key event posting).
enum SelectionService {

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    /// Request Accessibility access (shows the system prompt once).
    static func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(opts as CFDictionary)
    }

    /// Copy the current selection and return it as text (nil if nothing / no AX).
    static func readSelection(completion: @escaping (String?) -> Void) {
        guard hasAccessibility else { completion(nil); return }
        let pb = NSPasteboard.general
        let before = pb.changeCount

        NotificationCenter.default.post(name: ClipboardMonitor.appDidCopy, object: nil)
        sendCmd(key: CGKeyCode(kVK_ANSI_C))

        // Give the frontmost app a moment to put the selection on the pasteboard.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let text = (pb.changeCount != before) ? pb.string(forType: .string) : nil
            completion(text?.isEmpty == false ? text : nil)
        }
    }

    /// Replace the current selection with `text` (sets clipboard, then ⌘V).
    static func replaceSelection(with text: String) {
        guard hasAccessibility else { return }
        PasteService.copy(text: text)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            sendCmd(key: CGKeyCode(kVK_ANSI_V))
        }
    }

    // MARK: - Private

    private static func sendCmd(key: CGKeyCode) {
        let src = CGEventSource(stateID: .combinedSessionState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: true)
        down?.flags = .maskCommand
        let up = CGEvent(keyboardEventSource: src, virtualKey: key, keyDown: false)
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
