import SwiftUI
import SwiftData

struct HistoryPanelView: View {
    @Environment(StorageManager.self) var storageManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ClipItem.createdAt, order: .reverse) private var allItems: [ClipItem]

    @State private var searchText = ""
    @State private var selectedCategory: ClipItemType? = nil
    @State private var sortNewestFirst = true
    @State private var showSettings = false

    private var filteredItems: [ClipItem] {
        var items = allItems

        if let cat = selectedCategory {
            items = items.filter { $0.type == cat }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            items = items.filter {
                $0.textContent?.lowercased().contains(query) == true ||
                $0.sourceAppName?.lowercased().contains(query) == true
            }
        }
        if !sortNewestFirst {
            items = items.reversed()
        }
        return items
    }

    private var pinned: [ClipItem] { filteredItems.filter { $0.isPinned } }
    private var recent: [ClipItem] { filteredItems.filter { !$0.isPinned } }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            listContent
            Divider()
            footer
        }
        .frame(width: 360)
        .frame(minHeight: 440, maxHeight: 580)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(storageManager)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 8) {
            SearchBarView(text: $searchText)
            CategoryChipsView(selected: $selectedCategory)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private var listContent: some View {
        if filteredItems.isEmpty {
            EmptyStateView(hasSearch: !searchText.isEmpty)
        } else {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                    if !pinned.isEmpty {
                        Section {
                            rows(pinned)
                        } header: {
                            SectionHeader(title: "Pinned", icon: "pin.fill")
                        }
                    }
                    if !recent.isEmpty {
                        Section {
                            rows(recent)
                        } header: {
                            SectionHeader(title: "Recent", icon: "clock")
                        }
                    }
                }
            }
        }
    }

    private func rows(_ items: [ClipItem]) -> some View {
        ForEach(items) { item in
            ClipRowView(item: item) { copyToClipboard(item) }
            Divider()
                .padding(.leading, 44)
        }
    }

    private var footer: some View {
        HStack {
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Settings")

            Spacer()

            Button { sortNewestFirst.toggle() } label: {
                HStack(spacing: 4) {
                    Image(systemName: sortNewestFirst ? "arrow.down" : "arrow.up")
                        .font(.system(size: 11))
                    Text(sortNewestFirst ? "Newest" : "Oldest")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button { clearHistory() } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Clear history")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func copyToClipboard(_ item: ClipItem) {
        // Avvisa il monitor PRIMA di scrivere nel pasteboard,
        // così non rileva questo copy come un nuovo item esterno
        NotificationCenter.default.post(name: ClipboardMonitor.appDidCopy, object: nil)

        let pb = NSPasteboard.general
        pb.clearContents()
        if let text = item.textContent {
            pb.setString(text, forType: .string)
        } else if let data = item.imageData, let image = NSImage(data: data) {
            pb.writeObjects([image])
        }
    }

    private func clearHistory() {
        try? modelContext.delete(model: ClipItem.self)
        try? modelContext.save()
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
    }
}
