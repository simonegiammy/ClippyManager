import AppKit

// Entry point. Top-level code in main.swift is nonisolated, but the process
// starts on the main thread, so it's safe to assume main-actor isolation to
// build the (main-actor) AppDelegate.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    _ = delegate           // keep alive (NSApplication.delegate is weak)
    app.run()
}
