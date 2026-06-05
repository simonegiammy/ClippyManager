import Foundation
import Observation

/// Which primary tab is active in the shelf / library.
enum PrimaryTab: Hashable {
    case history
    case favorites
    case category(UUID)
}

/// Shared filter / search state used by both the shelf and the library window.
@Observable
final class ClipFilter {
    var search: String = ""
    var tab: PrimaryTab = .history
    var typeFilter: ClipItemType? = nil
    var appFilter: String? = nil          // source app bundle ID
    var sortNewestFirst: Bool = true

    func apply(to items: [ClipItem], categories: [Category]) -> [ClipItem] {
        var result = items

        // Primary tab
        switch tab {
        case .history:
            break
        case .favorites:
            result = result.filter { $0.isPinned }
        case .category(let id):
            result = result.filter { $0.categoryID == id }
        }

        // Type filter
        if let t = typeFilter {
            result = result.filter { $0.type == t }
        }

        // App filter
        if let app = appFilter {
            result = result.filter { $0.sourceAppBundleID == app }
        }

        // Search
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            result = result.filter {
                ($0.textContent?.lowercased().contains(q) ?? false) ||
                ($0.sourceAppName?.lowercased().contains(q) ?? false) ||
                $0.type.label.lowercased().contains(q)
            }
        }

        if !sortNewestFirst { result = result.reversed() }
        return result
    }

    /// Distinct source apps present in the items (bundleID → display name).
    func sourceApps(in items: [ClipItem]) -> [(id: String, name: String)] {
        var seen = [String: String]()
        for item in items {
            if let id = item.sourceAppBundleID, seen[id] == nil {
                seen[id] = item.sourceAppName ?? id
            }
        }
        return seen.map { (id: $0.key, name: $0.value) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
