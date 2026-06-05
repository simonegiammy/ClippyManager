import SwiftUI
import SwiftData

/// The full Library window: searchable grid with date grouping + detail pane.
struct LibraryView: View {
    @Environment(StorageManager.self) private var storage
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipItem.createdAt, order: .reverse) private var allItems: [ClipItem]
    @Query(sort: \Category.order) private var categories: [Category]

    @State private var filter = ClipFilter()
    @State private var selected: ClipItem?
    @State private var showAddCategory = false

    private var filtered: [ClipItem] {
        filter.apply(to: allItems, categories: categories)
    }

    private var counts: [PrimaryTab: Int] {
        var d: [PrimaryTab: Int] = [:]
        d[.history] = allItems.count
        d[.favorites] = allItems.filter { $0.isPinned }.count
        for cat in categories {
            d[.category(cat.id)] = allItems.filter { $0.categoryID == cat.id }.count
        }
        return d
    }

    private let columns = [GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 12)]

    var body: some View {
        HStack(spacing: 0) {
            mainColumn
            if let sel = selected {
                Divider().overlay(Theme.cardBorder)
                DetailPaneView(item: sel, onClose: { selected = nil })
                    .frame(width: 300)
                    .transition(.move(edge: .trailing))
            }
        }
        .background(Theme.panelBackground)
        .frame(minWidth: 720, minHeight: 480)
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet().environment(storage)
        }
        .animation(.easeInOut(duration: 0.18), value: selected)
    }

    private var mainColumn: some View {
        VStack(spacing: 12) {
            header
            CategoryTabsView(filter: filter, categories: categories,
                             counts: counts, onAddCategory: { showAddCategory = true })
            FilterBarView(filter: filter, sourceApps: filter.sourceApps(in: allItems))
            grid
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Library")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            SearchBarView(text: Binding(get: { filter.search }, set: { filter.search = $0 }),
                          placeholder: "Search your clipboard…")
                .frame(maxWidth: 320)
            Spacer()
            Button { storage.isCapturePaused.toggle() } label: {
                Label(storage.isCapturePaused ? "Paused" : "Capturing",
                      systemImage: storage.isCapturePaused ? "pause.circle.fill" : "record.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(storage.isCapturePaused ? Theme.accent : Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var grid: some View {
        if filtered.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "tray")
                    .font(.system(size: 34))
                    .foregroundStyle(Theme.textTertiary)
                Text(filter.search.isEmpty ? "Nothing here yet" : "No results")
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(groupedByDay, id: \.0) { day, items in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(day)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(items) { item in
                                    CardView(
                                        item: item,
                                        isSelected: selected?.id == item.id,
                                        onTap: { selected = item },
                                        onDoubleTap: { PasteService.copy(item) }
                                    )
                                    .frame(height: 150)
                                    .contextMenu { contextMenu(for: item) }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    /// Group filtered items by day label (Today / Yesterday / date).
    private var groupedByDay: [(String, [ClipItem])] {
        let cal = Calendar.current
        var groups: [String: [ClipItem]] = [:]
        var order: [String] = []
        for item in filtered {
            let label: String
            if cal.isDateInToday(item.createdAt) { label = "Today" }
            else if cal.isDateInYesterday(item.createdAt) { label = "Yesterday" }
            else { label = item.createdAt.formatted(date: .abbreviated, time: .omitted) }
            if groups[label] == nil { groups[label] = []; order.append(label) }
            groups[label]?.append(item)
        }
        return order.map { ($0, groups[$0] ?? []) }
    }

    @ViewBuilder
    private func contextMenu(for item: ClipItem) -> some View {
        Button { PasteService.copy(item) } label: { Label("Copy", systemImage: "doc.on.doc") }
        Button { item.isPinned.toggle(); try? modelContext.save() } label: {
            Label(item.isPinned ? "Unfavorite" : "Favorite",
                  systemImage: item.isPinned ? "star.slash" : "star")
        }
        if !categories.isEmpty {
            Menu("Add to Category") {
                ForEach(categories) { cat in
                    Button(cat.name) { item.categoryID = cat.id; try? modelContext.save() }
                }
                if item.categoryID != nil {
                    Divider()
                    Button("Remove from Category") { item.categoryID = nil; try? modelContext.save() }
                }
            }
        }
        Divider()
        Button(role: .destructive) {
            if selected?.id == item.id { selected = nil }
            storage.delete(item)
        } label: { Label("Delete", systemImage: "trash") }
    }
}
