import Foundation
import SwiftData

@Model
class ClipItem {
    var id: UUID
    var typeRaw: String
    var textContent: String?
    @Attribute(.externalStorage) var imageData: Data?
    var sourceAppName: String?
    var sourceAppBundleID: String?
    var isPinned: Bool
    var createdAt: Date
    var colorHex: String?
    var detectedLanguage: String?

    init(
        type: ClipItemType,
        textContent: String? = nil,
        imageData: Data? = nil,
        sourceAppName: String? = nil,
        sourceAppBundleID: String? = nil,
        colorHex: String? = nil,
        detectedLanguage: String? = nil
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.textContent = textContent
        self.imageData = imageData
        self.sourceAppName = sourceAppName
        self.sourceAppBundleID = sourceAppBundleID
        self.isPinned = false
        self.createdAt = Date.now
        self.colorHex = colorHex
        self.detectedLanguage = detectedLanguage
    }

    var type: ClipItemType {
        get { ClipItemType(rawValue: typeRaw) ?? .text }
        set { typeRaw = newValue.rawValue }
    }

    var preview: String {
        switch type {
        case .image:
            return "Image"
        case .file:
            guard let t = textContent else { return "File" }
            let first = t.components(separatedBy: "\n").first ?? t
            return URL(fileURLWithPath: first).lastPathComponent
        case .color:
            return textContent ?? colorHex ?? "Color"
        default:
            let raw = textContent ?? ""
            return String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200))
        }
    }
}
