import AppKit

final class ClipboardMonitor {
    private let storageManager: StorageManager
    private let classifier = ContentClassifier()
    private let sourceTracker = SourceAppTracker()
    private var timer: Timer?
    private var lastChangeCount: Int

    init(storageManager: StorageManager) {
        self.storageManager = storageManager
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        let t = Timer(timeInterval: 0.4, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Private

    private func poll() {
        let board = NSPasteboard.general
        let count = board.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        // Capture the source app ASAP after detecting the change
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
                colorHex: type == .color ? classifier.extractColorHex(from: text) : nil,
                detectedLanguage: type == .code ? classifier.detectLanguage(text) : nil
            )
            storageManager.add(item)
            return
        }

        // 2. Image
        if let image = NSImage(pasteboard: board),
           let tiff = image.tiffRepresentation {
            let item = ClipItem(
                type: .image,
                imageData: tiff,
                sourceAppName: appName,
                sourceAppBundleID: bundleID
            )
            storageManager.add(item)
            return
        }

        // 3. File URLs
        if let objects = board.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           !objects.isEmpty {
            let paths = objects.map(\.path).joined(separator: "\n")
            let item = ClipItem(
                type: .file,
                textContent: paths,
                sourceAppName: appName,
                sourceAppBundleID: bundleID
            )
            storageManager.add(item)
        }
    }
}
