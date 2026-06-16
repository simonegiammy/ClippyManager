import Foundation

/// The catalog of AI actions plus contextual ordering (type × destination app).
enum AIActionCatalog {

    // MARK: - All actions

    static let all: [AIAction] = [
        // — Text / prose —
        AIAction(id: "summarize", title: "Summarize", systemImage: "text.append",
                 applicableTypes: [.text, .link, .file], outputKind: .text,
                 instruction: "Summarize the following text concisely in 1–3 sentences. Keep the original language. Output only the summary."),
        AIAction(id: "tldr_bullets", title: "Key points", systemImage: "list.bullet",
                 applicableTypes: [.text, .link, .file], outputKind: .bullets,
                 instruction: "Extract the key points of the following text as a short bullet list. Keep the original language."),
        AIAction(id: "shorten", title: "Shorten", systemImage: "arrow.down.right.and.arrow.up.left",
                 applicableTypes: [.text], outputKind: .text,
                 instruction: "Rewrite the following text to be significantly shorter while keeping the meaning and language. Output only the rewritten text."),
        AIAction(id: "rewrite_formal", title: "Make formal", systemImage: "briefcase",
                 applicableTypes: [.text], outputKind: .text,
                 instruction: "Rewrite the following text in a professional, formal tone. Keep the language. Output only the rewritten text."),
        AIAction(id: "rewrite_casual", title: "Make casual", systemImage: "bubble.left.and.bubble.right",
                 applicableTypes: [.text], outputKind: .text,
                 instruction: "Rewrite the following text in a friendly, casual tone. Keep the language. Output only the rewritten text."),
        AIAction(id: "fix_grammar", title: "Fix grammar", systemImage: "checkmark.seal",
                 applicableTypes: [.text], outputKind: .text,
                 instruction: "Correct spelling, grammar and punctuation in the following text. Preserve meaning and language. Output only the corrected text."),
        AIAction(id: "simplify", title: "Simplify", systemImage: "wand.and.stars",
                 applicableTypes: [.text], outputKind: .text,
                 instruction: "Rewrite the following text so it is simple and easy to understand. Keep the language. Output only the rewritten text."),
        AIAction(id: "translate", title: "Translate…", systemImage: "globe",
                 applicableTypes: [.text, .link, .file], outputKind: .text,
                 instruction: "Translate the following text into {lang}. Output only the translation.",
                 requiresLanguageArg: true),
        AIAction(id: "extract_actions", title: "Extract action items", systemImage: "checklist",
                 applicableTypes: [.text], outputKind: .bullets,
                 instruction: "Extract concrete action items and tasks from the following text as a bullet list. Keep the language."),
        AIAction(id: "to_title", title: "Make a title", systemImage: "textformat.size",
                 applicableTypes: [.text], outputKind: .text,
                 instruction: "Write one short, catchy title for the following text. Output only the title."),

        // — Code —
        AIAction(id: "explain_code", title: "Explain", systemImage: "text.bubble",
                 applicableTypes: [.code], outputKind: .text,
                 instruction: "Explain clearly what the following code does, in a short paragraph. Output only the explanation."),
        AIAction(id: "comment_code", title: "Add comments", systemImage: "number",
                 applicableTypes: [.code], outputKind: .text,
                 instruction: "Add concise, helpful comments to the following code. Output only the commented code, no fences."),
        AIAction(id: "explain_regex", title: "Explain regex", systemImage: "asterisk",
                 applicableTypes: [.code, .text], outputKind: .text,
                 instruction: "Explain what the following regular expression matches, step by step. Output only the explanation."),
        AIAction(id: "to_json", title: "→ JSON", systemImage: "curlybraces",
                 applicableTypes: [.code, .text], outputKind: .json,
                 instruction: "Convert the following content into well-formed JSON that captures its structure."),

        // — Structured / data —
        AIAction(id: "to_table", title: "→ Table", systemImage: "tablecells",
                 applicableTypes: [.text, .code], outputKind: .table,
                 instruction: "Organize the following content into a table with clear columns and rows."),
    ]

    // MARK: - Contextual ordering

    /// Actions applicable to the clip, ordered so the best default for the
    /// destination app comes first. Learned usage nudges frequently-picked
    /// actions upward without overriding strong contextual rules.
    static func actions(for clip: ClipItem, destinationBundleID: String?) -> [AIAction] {
        let pool = all.filter { $0.applicableTypes.contains(clip.type) }
        let priority = contextPriority(for: clip, destinationBundleID: destinationBundleID)

        // Effective rank = context position minus a usage boost (capped so a
        // single rule-1 default isn't trivially displaced).
        func rank(_ a: AIAction) -> Double {
            let base = Double(priority.firstIndex(of: a.id) ?? 50)
            let used = AIUsageTracker.score(actionID: a.id, type: clip.type,
                                            destinationBundleID: destinationBundleID)
            let boost = min(Double(used), 3.0)   // up to 3 positions
            return base - boost
        }

        return pool.sorted { a, b in
            let ra = rank(a), rb = rank(b)
            if ra != rb { return ra < rb }
            return a.title < b.title
        }
    }

    /// The suggested default action id for the clip + destination, if any.
    static func defaultAction(for clip: ClipItem, destinationBundleID: String?) -> AIAction? {
        actions(for: clip, destinationBundleID: destinationBundleID).first
    }

    /// Rule-based priority list (§4 baseline) — front of the list wins.
    private static func contextPriority(for clip: ClipItem, destinationBundleID: String?) -> [String] {
        let app = (destinationBundleID ?? "").lowercased()
        let isChat = app.contains("slack") || app.contains("messages") ||
                     app.contains("whatsapp") || app.contains("telegram") || app.contains("discord")
        let isMailNotes = app.contains("mail") || app.contains("notes")
        let isCodeApp = app.contains("xcode") || app.contains("terminal") ||
                        app.contains("code") /* vscode */ || app.contains("iterm")

        switch clip.type {
        case .code:
            if isCodeApp { return ["explain_code", "comment_code", "to_json", "explain_regex", "to_table"] }
            return ["explain_code", "comment_code", "to_json", "to_table", "explain_regex"]

        case .link:
            return ["summarize", "tldr_bullets", "translate"]

        case .text:
            // Foreign-language text → translation first.
            if looksForeign(clip.textContent) {
                return ["translate", "summarize", "fix_grammar", "shorten"]
            }
            if isChat { return ["shorten", "rewrite_casual", "fix_grammar", "translate", "summarize"] }
            if isMailNotes { return ["summarize", "rewrite_formal", "fix_grammar", "tldr_bullets", "translate"] }
            let long = (clip.textContent?.count ?? 0) > 280
            if long { return ["summarize", "tldr_bullets", "shorten", "fix_grammar", "translate"] }
            return ["fix_grammar", "rewrite_formal", "shorten", "summarize", "translate"]

        default:
            return []
        }
    }

    /// Cheap heuristic: does the text appear to be in a non-English language?
    private static func looksForeign(_ text: String?) -> Bool {
        guard let t = text, t.count > 12 else { return false }
        // Common accented / non-ASCII letters suggest a non-English source.
        let nonAscii = t.unicodeScalars.filter { $0.value > 127 && CharacterSet.letters.contains($0) }
        return Double(nonAscii.count) / Double(t.count) > 0.04
    }
}
