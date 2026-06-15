import SwiftUI

enum ClipItemType: String, Codable, CaseIterable, Identifiable {
    case text       = "text"
    case link       = "link"
    case code       = "code"
    case color      = "color"
    case image      = "image"
    case file       = "file"
    case screenshot = "screenshot"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text:       "Text"
        case .link:       "Links"
        case .code:       "Code"
        case .color:      "Colors"
        case .image:      "Images"
        case .file:       "Files"
        case .screenshot: "Screenshots"
        }
    }

    var systemImage: String {
        switch self {
        case .text:       "textformat"
        case .link:       "link"
        case .code:       "chevron.left.forwardslash.chevron.right"
        case .color:      "paintpalette.fill"
        case .image:      "photo.fill"
        case .file:       "doc.fill"
        case .screenshot: "camera.viewfinder"
        }
    }

    /// Aurora Glass per-type accent (delegates to the theme).
    var accentColor: Color { Theme.typeColor(self) }

    /// Whether this type renders as a visual (image-like) card.
    var isVisual: Bool {
        self == .image || self == .screenshot
    }
}
