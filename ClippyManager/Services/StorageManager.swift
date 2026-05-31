import Foundation
import SwiftData

@Observable
final class StorageManager {
    let container: ModelContainer
    private let context: ModelContext

    private(set) var maxItems: Int {
        didSet { UserDefaults.standard.set(maxItems, forKey: "maxHistoryItems") }
    }

    init(container: ModelContainer) {
        self.container = container
        self.context = ModelContext(container)
        let stored = UserDefaults.standard.integer(forKey: "maxHistoryItems")
        self.maxItems = stored > 0 ? stored : 500
    }

    func add(_ item: ClipItem) {
        // Dedup: skip if identical to most recent text item
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

    @discardableResult
    private func save() -> Bool {
        do {
            try context.save()
            return true
        } catch {
            return false
        }
    }

    private func pruneIfNeeded() {
        let descriptor = FetchDescriptor<ClipItem>(
            sortBy: [SortDescriptor(\ClipItem.createdAt, order: .reverse)]
        )
        guard let items = try? context.fetch(descriptor),
              items.count > maxItems else { return }

        let excess = items.suffix(from: maxItems)
        excess.filter { !$0.isPinned }.forEach { context.delete($0) }
        save()
    }
}
