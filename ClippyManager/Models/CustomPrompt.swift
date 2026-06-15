import Foundation
import SwiftData

/// A user-defined AI action ("rewrite in my email style", …). Saved prompts are
/// surfaced in the palette action menu for text/code clips.
@Model
final class CustomPrompt {
    var id: UUID = UUID()
    var title: String = ""
    var instruction: String = ""
    var order: Int = 0
    var createdAt: Date = Date.now

    init(title: String, instruction: String, order: Int = 0) {
        self.id = UUID()
        self.title = title
        self.instruction = instruction
        self.order = order
        self.createdAt = .now
    }

    /// Bridge to a runnable AIAction (input appended by the engine prompt).
    var asAction: AIAction {
        AIAction(
            id: "custom.\(id.uuidString)",
            title: title,
            systemImage: "wand.and.stars.inverse",
            applicableTypes: [.text, .code, .link],
            outputKind: .text,
            instruction: instruction
        )
    }
}
