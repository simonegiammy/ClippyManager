import SwiftUI

enum ClipItemType: String, Codable, CaseIterable, Identifiable {
    case text   = "text"
    case link   = "link"
    case code   = "code"
    case color  = "color"
    case image  = "image"
    case file   = "file"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .text:  "Text"
        case .link:  "Links"
        case .code:  "Code"
        case .color: "Colors"
        case .image: "Images"
        case .file:  "Files"
        }
    }

    var systemImage: String {
        switch self {
        case .text:  "doc.text"
        case .link:  "link"
        case .code:  "chevron.left.forwardslash.chevron.right"
        case .color: "paintpalette"
        case .image: "photo"
        case .file:  "doc"
        }
    }

    var accentColor: Color {
        switch self {
        case .text:  .primary
        case .link:  .blue
        case .code:  .purple
        case .color: .orange
        case .image: Color(red: 0.08, green: 0.72, blue: 0.66)
        case .file:  .gray
        }
    }
}
