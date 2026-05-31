import Foundation

final class ContentClassifier {

    func classify(text: String) -> ClipItemType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isLink(trimmed)  { return .link }
        if isColor(trimmed) { return .color }
        if isCode(text)     { return .code }
        return .text
    }

    func extractColorHex(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Return HEX as-is; rgb/hsl etc. return the full string for display
        return trimmed
    }

    func detectLanguage(_ code: String) -> String? {
        if code.contains("func ")   || (code.contains("var ") && code.contains("->")) { return "Swift" }
        if code.contains("def ")    || code.contains("import numpy") || code.contains("print(") { return "Python" }
        if code.contains("function") || code.contains("const ") || code.contains("=>") { return "JavaScript" }
        if code.contains("SELECT ") || code.contains("FROM ") { return "SQL" }
        if code.contains("<html")   || code.contains("</") { return "HTML" }
        if code.contains("package ") || code.contains("fun ") { return "Kotlin/Go" }
        return nil
    }

    // MARK: - Private helpers

    private func isLink(_ text: String) -> Bool {
        guard !text.contains("\n"),
              let url = URL(string: text) else { return false }
        return url.scheme == "http" || url.scheme == "https" || url.scheme == "ftp"
    }

    private func isColor(_ text: String) -> Bool {
        let patterns = [
            "^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{4}|[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$",
            "^rgba?\\(\\s*\\d+\\s*,\\s*\\d+\\s*,\\s*\\d+\\s*(,\\s*[\\d.]+\\s*)?\\)$",
            "^hsla?\\(\\s*\\d+\\s*,\\s*\\d+%\\s*,\\s*\\d+%\\s*(,\\s*[\\d.]+\\s*)?\\)$",
            "^hsva?\\(\\s*\\d+\\s*,\\s*\\d+%\\s*,\\s*\\d+%\\s*(,\\s*[\\d.]+\\s*)?\\)$",
            "^cmyk\\(\\s*\\d+%\\s*,\\s*\\d+%\\s*,\\s*\\d+%\\s*,\\s*\\d+%\\s*\\)$"
        ]
        return patterns.contains {
            text.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }
    }

    private func isCode(_ text: String) -> Bool {
        guard text.contains("\n") else { return false }
        let keywords = [
            "func ", "class ", "struct ", "enum ", "import ",
            "def ", "return ", "if ", "for ", "while ",
            "const ", "let ", "var ", "val ",
            "<?php", "<html", "SELECT ", "FROM ", "WHERE ",
            "#!/", "#include", "#define",
            "package ", "public ", "private ", "override "
        ]
        return keywords.contains { text.contains($0) }
    }
}
