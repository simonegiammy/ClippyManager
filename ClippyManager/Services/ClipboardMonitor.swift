import AppKit

final class ClipboardMonitor {

    static let appDidCopy = Notification.Name("ClipboardMonitor.appDidCopy")

    private let storageManager: StorageManager
    private let classifier = ContentClassifier()
    private let sourceTracker = SourceAppTracker()
    private var timer: Timer?
    private var lastChangeCount: Int
    private var suppressUntil: Date = .distantPast

    init(storageManager: StorageManager) {
        self.storageManager = storageManager
        self.lastChangeCount = NSPasteboard.general.changeCount

        NotificationCenter.default.addObserver(
            forName: Self.appDidCopy, object: nil, queue: .main
        ) { [weak self] _ in
            self?.suppressUntil = Date().addingTimeInterval(1.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.lastChangeCount = NSPasteboard.general.changeCount
            }
        }
    }

    func start() {
        let t = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() { timer?.invalidate(); timer = nil }

    // MARK: - Private

    private func poll() {
        // Respect global pause — keep counter in sync so resume doesn't backfill
        guard !storageManager.isCapturePaused else {
            lastChangeCount = NSPasteboard.general.changeCount
            return
        }
        guard Date() >= suppressUntil else {
            lastChangeCount = NSPasteboard.general.changeCount
            return
        }

        let board = NSPasteboard.general
        let count = board.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        sourceTracker.capture()
        let (appName, bundleID) = sourceTracker.current

        // 1. Text / links / code / colors
        if let text = board.string(forType: .string), !text.isEmpty {
            let type = classifier.classify(text: text)
            let item = ClipItem(
                type: type,
                textContent: text,
                sourceAppName: appName,
                sourceAppBundleID: bundleID,
                sourceURL: type == .link ? text.trimmingCharacters(in: .whitespacesAndNewlines) : nil,
                colorHex: type == .color ? classifier.extractColorHex(from: text) : nil,
                detectedLanguage: type == .code ? classifier.detectLanguage(text) : nil,
                byteSize: text.utf8.count,
                isSensitive: SensitiveDetector.isSensitive(text)
            )
            storageManager.add(item)
            return
        }

        // 2. Image (could be a screenshot)
        if let image = NSImage(pasteboard: board),
           let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            let isShot = looksLikeScreenshot(bundleID: bundleID, image: image)
            let item = ClipItem(
                type: isShot ? .screenshot : .image,
                imageData: png,
                sourceAppName: isShot ? "Screenshot" : appName,
                sourceAppBundleID: bundleID,
                byteSize: png.count
            )
            storageManager.add(item)
            return
        }

        // 3. File URLs
        if let objects = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !objects.isEmpty {
            let paths = objects.map(\.path).joined(separator: "\n")
            let totalSize = objects.reduce(0) { acc, url in
                acc + ((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
            let item = ClipItem(
                type: .file,
                textContent: paths,
                sourceAppName: appName,
                sourceAppBundleID: bundleID,
                byteSize: totalSize
            )
            storageManager.add(item)
        }
    }

    /// Heuristic: a macOS screenshot copied to the clipboard matches one of the
    /// connected screens' pixel dimensions (full-screen grab) or a 2x scale of it.
    private func looksLikeScreenshot(bundleID: String?, image: NSImage) -> Bool {
        guard let rep = image.representations.first else { return false }
        let w = CGFloat(rep.pixelsWide)
        let h = CGFloat(rep.pixelsHigh)
        guard w > 0, h > 0 else { return false }

        for screen in NSScreen.screens {
            let scale = screen.backingScaleFactor
            let sw = screen.frame.width * scale
            let sh = screen.frame.height * scale
            // Exact full-screen capture
            if abs(w - sw) < 2 && abs(h - sh) < 2 { return true }
            // Region grabs share the screen's aspect ratio at high resolution
            if w >= 200 && h >= 200 {
                let screenAspect = sw / sh
                let imgAspect = w / h
                if abs(screenAspect - imgAspect) < 0.02 && w > sw * 0.4 { return true }
            }
        }
        return false
    }
}
