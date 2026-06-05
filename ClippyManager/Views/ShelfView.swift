import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// The Supaste-style notch shelf: a dark glass horizontal panel with cards.
struct ShelfView: View {
    @Environment(StorageManager.self) private var storage
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipItem.createdAt, order: .reverse) private var allItems: [ClipItem]
    @Query(sort: \Category.order) private var categories: [Category]

    @State private var filter = ClipFilter()
    @State private var showAddCategory = false
    @State private var copiedID: UUID? = nil
    @State private var isDropTargeted = false
    @State private var leaveWork: DispatchWorkItem?

    var onOpenLibrary: () -> Void
    var onClose: () -> Void
    var shouldAutoCloseOnLeave: () -> Bool = { false }

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

    var body: some View {
        VStack(spacing: 10) {
            topBar
            CategoryTabsView(filter: filter, categories: categories,
                             counts: counts, onAddCategory: { showAddCategory = true })
            cards
        }
        .padding(14)
        .frame(width: 720, height: 230)
        .glassPanel()
        .overlay(
            RoundedRectangle(cornerRadius: Theme.panelRadius)
                .stroke(Theme.accent, lineWidth: isDropTargeted ? 2.5 : 0)
                .animation(.easeOut(duration: 0.12), value: isDropTargeted)
        )
        .overlay(dropHint)
        .onDrop(of: [.image, .fileURL, .text, .plainText],
                isTargeted: $isDropTargeted) { providers in
            DropIngestor.ingest(providers: providers, into: storage)
        }
        .onHover { inside in handleHover(inside) }
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet().environment(storage)
        }
    }

    /// When the shelf was opened by hovering the notch, close it shortly after
    /// the pointer leaves — so it behaves like a peek.
    private func handleHover(_ inside: Bool) {
        leaveWork?.cancel()
        guard shouldAutoCloseOnLeave() else { return }
        if inside { return }
        let work = DispatchWorkItem {
            if copiedID == nil { onClose() }
        }
        leaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    @ViewBuilder
    private var dropHint: some View {
        if isDropTargeted {
            VStack(spacing: 8) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Theme.accent)
                Text("Drop to save in Clippy")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.panelBackground.opacity(0.85),
                        in: RoundedRectangle(cornerRadius: Theme.panelRadius))
            .allowsHitTesting(false)
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 13))
                .foregroundStyle(Theme.accent)
            Text("Clippy")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            SearchBarView(text: Binding(get: { filter.search }, set: { filter.search = $0 }))
                .frame(maxWidth: 280)

            Spacer()

            // Pause toggle
            Button { storage.isCapturePaused.toggle() } label: {
                Image(systemName: storage.isCapturePaused ? "pause.circle.fill" : "record.circle")
                    .foregroundStyle(storage.isCapturePaused ? Theme.accent : Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help(storage.isCapturePaused ? "Capture paused — click to resume" : "Pause capture")

            // Open library
            Button(action: onOpenLibrary) {
                Image(systemName: "rectangle.grid.2x2")
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Open Library")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundStyle(Theme.textSecondary)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var cards: some View {
        if filtered.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: storage.isCapturePaused ? "pause.circle" : "tray")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.textTertiary)
                Text(storage.isCapturePaused ? "Capture paused" :
                        (filter.search.isEmpty ? "Nothing here yet" : "No results"))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(filtered) { item in
                        CardView(
                            item: item,
                            isSelected: copiedID == item.id,
                            onTap: { copy(item) },
                            onDoubleTap: { onOpenLibrary() }
                        )
                        .frame(width: 130, height: 120)
                        .contextMenu { contextMenu(for: item) }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for item: ClipItem) -> some View {
        Button { copy(item) } label: { Label("Copy", systemImage: "doc.on.doc") }
        Button { toggleFavorite(item) } label: {
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
        Button(role: .destructive) { storage.delete(item) } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func copy(_ item: ClipItem) {
        PasteService.copy(item)
        copiedID = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if copiedID == item.id { onClose() }
        }
    }

    private func toggleFavorite(_ item: ClipItem) {
        item.isPinned.toggle()
        try? modelContext.save()
    }
}
