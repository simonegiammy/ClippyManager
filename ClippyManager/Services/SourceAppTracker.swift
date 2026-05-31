import AppKit

final class SourceAppTracker {

    private var lastAppName: String?
    private var lastBundleID: String?

    func capture() {
        guard let app = NSWorkspace.shared.frontmostApplication else { return }
        lastAppName = app.localizedName
        lastBundleID = app.bundleIdentifier
    }

    var current: (name: String?, bundleID: String?) {
        (lastAppName, lastBundleID)
    }

    static func appIcon(bundleID: String) -> NSImage? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 20, height: 20)
        return icon
    }
}
