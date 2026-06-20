import AppKit
import UniformTypeIdentifiers

/// Ingests items dropped directly onto Clippy (images, files, text) and stores
/// them as clips — the manual counterpart to automatic clipboard capture.
enum DropIngestor {

    /// Handle SwiftUI drop providers. Returns true if anything was ingested.
    @discardableResult
    static func ingest(providers: [NSItemProvider], into storage: StorageManager) -> Bool {
        var handled = false
        for provider in providers {
            if provider.canLoadObject(ofClass: NSImage.self) {
                handled = true
                provider.loadObject(ofClass: NSImage.self) { obj, _ in
                    guard let image = obj as? NSImage,
                          let tiff = image.tiffRepresentation,
                          let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
                    else { return }
                    DispatchQueue.main.async {
                        storage.add(ClipItem(type: .image, imageData: png,
                                             sourceAppName: "Dropped", byteSize: png.count))
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                handled = true
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                    var url: URL?
                    if let d = data as? Data { url = URL(dataRepresentation: d, relativeTo: nil) }
                    else if let u = data as? URL { url = u }
                    guard let fileURL = url else { return }
                    let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    DispatchQueue.main.async {
                        MainActor.assumeIsolated { ingestFile(fileURL, size: size, into: storage) }
                    }
                }
            } else if provider.canLoadObject(ofClass: NSString.self) {
                handled = true
                provider.loadObject(ofClass: NSString.self) { obj, _ in
                    guard let text = obj as? String, !text.isEmpty else { return }
                    DispatchQueue.main.async {
                        let type = ContentClassifier().classify(text: text)
                        storage.add(ClipItem(type: type, textContent: text,
                                             sourceAppName: "Dropped",
                                             byteSize: text.utf8.count))
                    }
                }
            }
        }
        return handled
    }

    /// Ingest a drop received by an AppKit view (the notch drop zone), reading
    /// directly from the dragging pasteboard. Returns true if anything was saved.
    @MainActor
    @discardableResult
    static func ingest(pasteboard pb: NSPasteboard, into storage: StorageManager) -> Bool {
        // 0. A drag that originated from the shelf itself → ignore (no duplicate).
        if pb.types?.contains(where: { $0.rawValue == ClipDragMarker.typeID }) == true {
            return false
        }
        // 1. File URLs (files & folders)
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            for url in urls {
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                ingestFile(url, size: size, into: storage)
            }
            return true
        }
        // 2. Image data
        if let image = NSImage(pasteboard: pb),
           let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            storage.add(ClipItem(type: .image, imageData: png,
                                 sourceAppName: "Dropped", byteSize: png.count))
            return true
        }
        // 3. Plain text / links
        if let text = pb.string(forType: .string), !text.isEmpty {
            let type = ContentClassifier().classify(text: text)
            storage.add(ClipItem(type: type, textContent: text,
                                 sourceAppName: "Dropped", byteSize: text.utf8.count))
            return true
        }
        return false
    }

    @MainActor
    private static func ingestFile(_ url: URL, size: Int, into storage: StorageManager) {
        // If it's an image file, store the image; otherwise store as a file ref.
        if let type = UTType(filenameExtension: url.pathExtension),
           type.conforms(to: .image),
           let image = NSImage(contentsOf: url),
           let tiff = image.tiffRepresentation,
           let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
            let clip = ClipItem(type: .image, imageData: png,
                                sourceAppName: "Dropped", byteSize: png.count)
            clip.originalName = url.lastPathComponent   // keep the name for drag-out
            storage.add(clip)
        } else {
            storage.add(ClipItem(type: .file, textContent: url.path,
                                 sourceAppName: "Dropped", byteSize: size))
        }
    }
}
