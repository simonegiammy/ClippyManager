import AppKit

final class ClipboardMonitor {

    // Notifica postata da HistoryPanelView prima di scrivere nel pasteboard,
    // così il monitor non rileva i propri copy come nuovi item
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

        // Quando l'app copia nel pasteboard (click su un item),
        // sopprimi il prossimo ciclo di monitoraggio per evitare
        // il loop: click → pasteboard change → SwiftData save →
        // @Query reload → SwiftUI re-render → hit-test rotto
        NotificationCenter.default.addObserver(
            forName: Self.appDidCopy,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.suppressUntil = Date().addingTimeInterval(1.5)
            // Aggiorna il contatore subito così il monitor non rileva
            // il cambio quando riprende
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.lastChangeCount = NSPasteboard.general.changeCount
            }
        }
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
        // Durante la soppressione aggiorna solo il contatore, non processare
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

        // 1. Testo / link / code / colori
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

        // 2. Immagine
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

        // 3. File URL
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
