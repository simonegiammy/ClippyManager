import Foundation

/// Learns which actions the user prefers per (clip type × destination-app bucket)
/// and feeds a usage boost back into the catalog ordering. Fully local.
enum AIUsageTracker {
    private static let key = "ai.usageCounts"

    /// Coarse bucket for the destination app so learning generalizes
    /// (e.g. all chat apps share a bucket).
    static func appBucket(_ bundleID: String?) -> String {
        let app = (bundleID ?? "").lowercased()
        if app.contains("slack") || app.contains("messages") || app.contains("whatsapp") ||
           app.contains("telegram") || app.contains("discord") { return "chat" }
        if app.contains("mail") || app.contains("notes") || app.contains("outlook") { return "writing" }
        if app.contains("xcode") || app.contains("code") || app.contains("terminal") ||
           app.contains("iterm") { return "code" }
        if app.isEmpty { return "none" }
        return "other"
    }

    private static func slot(_ type: ClipItemType, _ bucket: String) -> String {
        "\(type.rawValue)|\(bucket)"
    }

    /// Record that the user ran `actionID` for this clip type + destination.
    static func record(actionID: String, type: ClipItemType, destinationBundleID: String?) {
        var counts = load()
        let s = slot(type, appBucket(destinationBundleID))
        var inner = counts[s] ?? [:]
        inner[actionID, default: 0] += 1
        counts[s] = inner
        UserDefaults.standard.set(counts, forKey: key)
    }

    /// How many times `actionID` was used in this slot (for ordering boost).
    static func score(actionID: String, type: ClipItemType, destinationBundleID: String?) -> Int {
        let counts = load()
        return counts[slot(type, appBucket(destinationBundleID))]?[actionID] ?? 0
    }

    static func reset() { UserDefaults.standard.removeObject(forKey: key) }

    private static func load() -> [String: [String: Int]] {
        (UserDefaults.standard.dictionary(forKey: key) as? [String: [String: Int]]) ?? [:]
    }
}
