import Foundation

/// What kind of output an action produces (drives which engine path runs).
enum AIOutputKind: Equatable {
    case text
    case bullets      // @Generable list
    case table        // @Generable markdown table
    case json         // @Generable JSON
}

/// A clip-bound AI action. Pure data — no FoundationModels dependency here.
struct AIAction: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let applicableTypes: Set<ClipItemType>
    let outputKind: AIOutputKind
    /// Instruction template; `{lang}` is substituted for translation actions.
    let instruction: String
    /// Translation/language target needed before running.
    let requiresLanguageArg: Bool

    init(id: String, title: String, systemImage: String,
         applicableTypes: Set<ClipItemType>, outputKind: AIOutputKind = .text,
         instruction: String, requiresLanguageArg: Bool = false) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.applicableTypes = applicableTypes
        self.outputKind = outputKind
        self.instruction = instruction
        self.requiresLanguageArg = requiresLanguageArg
    }

    static func == (lhs: AIAction, rhs: AIAction) -> Bool { lhs.id == rhs.id }
}
