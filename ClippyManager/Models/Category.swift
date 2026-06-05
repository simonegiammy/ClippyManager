import Foundation
import SwiftData
import SwiftUI

/// A user-created space for organizing clips (e.g. Prompts, Assets, Inspirations).
@Model
final class Category {
    var id: UUID = UUID()
    var name: String = ""
    var systemImage: String = "square.grid.2x2"
    var colorHex: String = "#0080FF"
    var order: Int = 0
    var createdAt: Date = Date.now

    init(name: String, systemImage: String = "square.grid.2x2", colorHex: String = "#0080FF", order: Int = 0) {
        self.id = UUID()
        self.name = name
        self.systemImage = systemImage
        self.colorHex = colorHex
        self.order = order
        self.createdAt = .now
    }

    var color: Color { Color(hex: colorHex) ?? Theme.accent }
}
