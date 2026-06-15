import Foundation
import SwiftData
import AppKit

@Model
final class ClipItem {
    // NOTE: non-optional properties carry declaration-level defaults so that
    // SwiftData lightweight migration can backfill rows from older schemas.
    var id: UUID = UUID()
    var typeRaw: String = ClipItemType.text.rawValue
    var textContent: String?
    @Attribute(.externalStorage) var imageData: Data?
    var sourceAppName: String?
    var sourceAppBundleID: String?
    var sourceURL: String?
    var isPinned: Bool = false          // "favorite" (star)
    var createdAt: Date = Date.now
    var colorHex: String?
    var detectedLanguage: String?
    var byteSize: Int = 0
    var isSensitive: Bool = false
    var categoryID: UUID?       // assigned custom category

    init(
        type: ClipItemType,
        textContent: String? = nil,
        imageData: Data? = nil,
        sourceAppName: String? = nil,
        sourceAppBundleID: String? = nil,
        sourceURL: String? = nil,
        colorHex: String? = nil,
        detectedLanguage: String? = nil,
        byteSize: Int = 0,
        isSensitive: Bool = false
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.textContent = textContent
        self.imageData = imageData
        self.sourceAppName = sourceAppName
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceURL = sourceURL
        self.isPinned = false
        self.createdAt = .now
        self.colorHex = colorHex
        self.detectedLanguage = detectedLanguage
        self.byteSize = byteSize
        self.isSensitive = isSensitive
        self.categoryID = nil
    }

    var type: ClipItemType {
        get { ClipItemType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }

    var preview: String {
        switch type {
        case .image, .screenshot:
            return type == .screenshot ? "Screenshot" : "Image"
        case .file:
            guard let t = textContent, !t.isEmpty else { return "File" }
            let paths = t.components(separatedBy: "\n").filter { !$0.isEmpty }
            let first = URL(fileURLWithPath: paths.first ?? t).lastPathComponent
            return paths.count > 1 ? "\(first) +\(paths.count - 1) more" : first
        case .color:
            return textContent ?? colorHex ?? "Color"
        default:
            let raw = textContent ?? ""
            return String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(300))
        }
    }

    /// Single-line title for compact display.
    var title: String {
        preview.components(separatedBy: "\n").first ?? preview
    }

    var nsImage: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }

    var formattedSize: String {
        Theme.formatBytes(byteSize)
    }

    var relativeTime: String {
        createdAt.relativeShort
    }
}
