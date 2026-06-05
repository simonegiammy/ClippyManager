import Foundation

final class ContentClassifier {

    func classify(text: String) -> ClipItemType {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isLink(trimmed)  { return .link }
        if isColor(trimmed) { return .color }
        if isCode(text)     { return .code }
        return .text
    }

    /// Returns a `#RRGGBB` hex usable for a color swatch, converting from
    /// rgb()/rgba()/hsl()/hsla() when needed.
    func extractColorHex(from text: String) -> String? {
        let s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if s.hasPrefix("#") { return s }

        let lower = s.lowercased()
        if lower.hasPrefix("rgb") {
            let nums = numbers(in: s)
            if nums.count >= 3 {
                return hex(Int(nums[0]), Int(nums[1]), Int(nums[2]))
            }
        }
        if lower.hasPrefix("hsl") {
            let nums = numbers(in: s)
            if nums.count >= 3 {
                let (r, g, b) = hslToRgb(h: nums[0], s: nums[1] / 100, l: nums[2] / 100)
                return hex(r, g, b)
            }
        }
        return s
    }

    private func numbers(in text: String) -> [Double] {
        let parts = text.components(separatedBy: CharacterSet(charactersIn: "0123456789.").inverted)
        return parts.compactMap { Double($0) }
    }

    private func hex(_ r: Int, _ g: Int, _ b: Int) -> String {
        func clamp(_ v: Int) -> Int { max(0, min(255, v)) }
        return String(format: "#%02X%02X%02X", clamp(r), clamp(g), clamp(b))
    }

    private func hslToRgb(h: Double, s: Double, l: Double) -> (Int, Int, Int) {
        let c = (1 - abs(2 * l - 1)) * s
        let hp = h / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        var (r, g, b): (Double, Double, Double) = (0, 0, 0)
        switch hp {
        case 0..<1: (r, g, b) = (c, x, 0)
        case 1..<2: (r, g, b) = (x, c, 0)
        case 2..<3: (r, g, b) = (0, c, x)
        case 3..<4: (r, g, b) = (0, x, c)
        case 4..<5: (r, g, b) = (x, 0, c)
        default:    (r, g, b) = (c, 0, x)
        }
        let m = l - c / 2
        return (Int((r + m) * 255), Int((g + m) * 255), Int((b + m) * 255))
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
