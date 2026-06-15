import Foundation
import SwiftData
import AppKit

@Observable
final class StorageManager {
    let container: ModelContainer
    private let context: ModelContext

    private(set) var maxItems: Int {
        didSet { UserDefaults.standard.set(maxItems, forKey: "maxHistoryItems") }
    }

    /// Global capture pause state (persisted).
    var isCapturePaused: Bool {
        didSet { UserDefaults.standard.set(isCapturePaused, forKey: "isCapturePaused") }
    }

    init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
        let stored = UserDefaults.standard.integer(forKey: "maxHistoryItems")
        self.maxItems = stored > 0 ? stored : 500
        self.isCapturePaused = UserDefaults.standard.bool(forKey: "isCapturePaused")
        seedDefaultCategoriesIfNeeded()
    }

    // MARK: - Clip items

    func add(_ item: ClipItem) {
        if let newText = item.textContent, !newText.isEmpty {
            var descriptor = FetchDescriptor<ClipItem>(
                sortBy: [SortDescriptor(\ClipItem.createdAt, order: .reverse)]
            )
            descriptor.fetchLimit = 1
            if let last = try? context.fetch(descriptor).first,
               last.textContent == newText {
                return
            }
        }
        context.insert(item)
        save()
        pruneIfNeeded()
    }

    func delete(_ item: ClipItem) {
        context.delete(item)
        save()
    }

    func clearAll() {
        try? context.delete(model: ClipItem.self)
        save()
    }

    func update(maxItems newMax: Int) {
        maxItems = max(10, min(2000, newMax))
    }

    /// The N most recent clips (newest first). Used by ⌃⌘0–9.
    func recentItems(limit: Int) -> [ClipItem] {
        var d = FetchDescriptor<ClipItem>(
            sortBy: [SortDescriptor(\ClipItem.createdAt, order: .reverse)]
        )
        d.fetchLimit = limit
        return (try? context.fetch(d)) ?? []
    }

    // MARK: - Categories

    func categories() -> [Category] {
        let descriptor = FetchDescriptor<Category>(
            sortBy: [SortDescriptor(\Category.order, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func addCategory(name: String, systemImage: String, colorHex: String) {
        let count = categories().count
        let cat = Category(name: name, systemImage: systemImage, colorHex: colorHex, order: count)
        context.insert(cat)
        save()
    }

    func deleteCategory(_ category: Category) {
        // Unassign items first
        let catID = category.id
        let descriptor = FetchDescriptor<ClipItem>(
            predicate: #Predicate { $0.categoryID == catID }
        )
        if let items = try? context.fetch(descriptor) {
            items.forEach { $0.categoryID = nil }
        }
        context.delete(category)
        save()
    }

    // MARK: - Custom prompts (saved AI actions)

    func customPrompts() -> [CustomPrompt] {
        let d = FetchDescriptor<CustomPrompt>(sortBy: [SortDescriptor(\CustomPrompt.order)])
        return (try? context.fetch(d)) ?? []
    }

    func addCustomPrompt(title: String, instruction: String) {
        let order = customPrompts().count
        context.insert(CustomPrompt(title: title, instruction: instruction, order: order))
        save()
    }

    func deleteCustomPrompt(_ p: CustomPrompt) {
        context.delete(p)
        save()
    }

    private func seedDefaultCategoriesIfNeeded() {
        // Seed only on a genuinely fresh store (no categories AND no clips), so
        // categories the user later deletes are never resurrected.
        let itemCount = (try? context.fetchCount(FetchDescriptor<ClipItem>())) ?? 0
        guard categories().isEmpty, itemCount == 0 else { return }
        let defaults: [(String, String, String)] = [
            ("Prompts",      "text.bubble.fill",   "#A855F7"),
            ("Assets",       "square.stack.3d.up.fill", "#0080FF"),
            ("Inspirations", "sparkles",           "#FF9500"),
        ]
        for (i, d) in defaults.enumerated() {
            context.insert(Category(name: d.0, systemImage: d.1, colorHex: d.2, order: i))
        }
        save()
    }

    // MARK: - Internal

    @discardableResult
    private func save() -> Bool {
        do { try context.save(); return true } catch { return false }
    }

    private func pruneIfNeeded() {
        let descriptor = FetchDescriptor<ClipItem>(
            sortBy: [SortDescriptor(\ClipItem.createdAt, order: .reverse)]
        )
        guard let items = try? context.fetch(descriptor), items.count > maxItems else { return }
        let excess = items.suffix(from: maxItems)
        excess.filter { !$0.isPinned }.forEach { context.delete($0) }
        save()
    }
}
