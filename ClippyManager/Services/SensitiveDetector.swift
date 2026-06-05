import Foundation

/// Heuristic detector for sensitive clipboard content (passwords, cards, tokens).
enum SensitiveDetector {

    static func isSensitive(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        // Credit card (13–16 digits, optional separators)
        if matches(trimmed, #"^(?:\d[ -]?){13,16}$"#) { return true }

        // Likely API key / token
        let tokenPrefixes = ["sk-", "pk_", "ghp_", "gho_", "xox", "AKIA", "AIza", "Bearer "]
        if tokenPrefixes.contains(where: { trimmed.hasPrefix($0) }) { return true }

        // JWT
        if matches(trimmed, #"^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$"#) { return true }

        // Long high-entropy single token (likely secret)
        if !trimmed.contains(" ") && !trimmed.contains("\n") && trimmed.count >= 20 {
            let hasUpper = trimmed.rangeOfCharacter(from: .uppercaseLetters) != nil
            let hasLower = trimmed.rangeOfCharacter(from: .lowercaseLetters) != nil
            let hasDigit = trimmed.rangeOfCharacter(from: .decimalDigits) != nil
            if hasUpper && hasLower && hasDigit { return true }
        }

        // Mentions "password:" pattern
        if matches(trimmed.lowercased(), #"(password|passwd|secret|api[_ ]?key)\s*[:=]\s*\S+"#) { return true }

        return false
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}
