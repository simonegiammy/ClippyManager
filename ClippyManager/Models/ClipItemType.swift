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

    var accentColor: Color {
        switch self {
        case .text:       Color(red: 0.6, green: 0.6, blue: 0.65)
        case .link:       Color(red: 0.2, green: 0.55, blue: 1.0)
        case .code:       Color(red: 0.65, green: 0.45, blue: 1.0)
        case .color:      Color(red: 1.0, green: 0.6, blue: 0.2)
        case .image:      Color(red: 0.1, green: 0.75, blue: 0.6)
        case .file:       Color(red: 0.55, green: 0.6, blue: 0.7)
        case .screenshot: Color(red: 1.0, green: 0.35, blue: 0.5)
        }
    }

    /// Whether this type renders as a visual (image-like) card.
    var isVisual: Bool {
        self == .image || self == .screenshot
    }
}
