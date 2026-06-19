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
    @State private var selectedID: UUID? = nil       // tap-selected clip → shows AI bar
    @State private var isDropTargeted = false
    @State private var leaveWork: DispatchWorkItem?
    @State private var growth: CGFloat = 0   // 0 closed (pill) → 1 open (panel)

    // AI preview state (inline, when an action runs from the shelf)
    @State private var aiAction: AIAction?
    @State private var aiText: String = ""
    @State private var aiStreaming = false
    @State private var aiError: String?
    @State private var aiTask: Task<Void, Never>?

    let engine: AIEngine
    let availability: AIAvailability
    var controller: ShelfController
    var onOpenLibrary: () -> Void
    var onClose: () -> Void
    var shouldAutoCloseOnLeave: () -> Bool = { false }

    private var selectedItem: ClipItem? {
        guard let id = selectedID else { return nil }
        return allItems.first { $0.id == id }
    }

    private var shelfActions: [AIAction] {
        guard let item = selectedItem, !item.isSensitive else { return [] }
        return AIActionCatalog.actions(for: item, destinationBundleID: nil)
    }

    // Panel size — the menu band at top is where the notch pill lives.
    private let panelWidth: CGFloat = 720
    private let panelHeight: CGFloat = 320   // room for tabs + cards + AI action bar
    private let menuBand: CGFloat = 34

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
        ZStack(alignment: .top) {
            // 1. The glass body, clipped to the notch shape that GROWS from the
            //    pill. This is the "genie / drop" — one continuous form from the notch.
            glassBody
                .frame(width: panelWidth, height: panelHeight)
                .clipShape(NotchShape(progress: growth, menuBand: menuBand))
                .overlay(
                    NotchShape(progress: growth, menuBand: menuBand)
                        .stroke(Theme.accent, lineWidth: isDropTargeted ? 2.5 : 0)
                )
                .shadow(color: .black.opacity(0.55), radius: 30, y: 18)

            // 2. Content fades in only once mostly grown.
            content
                .frame(width: panelWidth, height: panelHeight)
                .opacity(growth > 0.6 ? Double((growth - 0.6) / 0.4) : 0)
                .allowsHitTesting(growth > 0.9)
        }
        .frame(width: panelWidth, height: panelHeight)
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
        .onAppear { syncGrowth(animated: true) }
        .onChange(of: controller.isOpen) { _, _ in syncGrowth(animated: true) }
    }

    /// Animate the notch shape toward the controller's open state, using the
    /// curves measured from NotchDock: a quick small-overshoot spring on open,
    /// a smooth ease-in-out on close (no bounce).
    private func syncGrowth(animated: Bool) {
        guard animated else { growth = controller.isOpen ? 1 : 0; return }
        if controller.isOpen {
            withAnimation(.timingCurve(0.22, 1.1, 0.36, 1, duration: ShelfController.openDuration)) {
                growth = 1
            }
        } else {
            withAnimation(.timingCurve(0.4, 0, 0.2, 1, duration: ShelfController.closeDuration)) {
                growth = 0
            }
        }
    }

    /// The glass fill of the panel (no content) — what the notch shape clips.
    private var glassBody: some View {
        AuroraGlassSurface()
    }

    private var content: some View {
        VStack(spacing: 10) {
            topBar
            if aiAction != nil {
                aiPreview
            } else {
                CategoryTabsView(filter: filter, categories: categories,
                                 counts: counts, onAddCategory: { showAddCategory = true })
                cards
                if selectedItem != nil { shelfActionBar }
            }
        }
        .padding(.top, menuBand + 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    /// AI action chips for the tap-selected clip — appears under the cards.
    @ViewBuilder
    private var shelfActionBar: some View {
        if !shelfActions.isEmpty {
            HStack(spacing: 7) {
                Image(systemName: availability.actionsActive ? "wand.and.stars" : "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(availability.actionsActive ? Theme.accent : Theme.textTertiary)
                ForEach(Array(shelfActions.prefix(4).enumerated()), id: \.element.id) { idx, action in
                    Button { runAI(action) } label: {
                        HStack(spacing: 5) {
                            Image(systemName: availability.actionsActive ? action.systemImage : "lock.fill")
                                .font(.system(size: 10, weight: .medium))
                            Text(action.title)
                                .font(.system(size: 12, weight: idx == 0 ? .semibold : .regular))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(
                            idx == 0 && availability.actionsActive
                                ? AnyShapeStyle(LinearGradient(colors: Theme.accentGradient,
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                                : AnyShapeStyle(Theme.pillInactive),
                            in: Capsule())
                        .foregroundStyle(idx == 0 && availability.actionsActive ? .white : Theme.textSecondary)
                        .fixedSize()
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 4)
                Button { copy(selectedItem!) } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
    }

    /// Inline streaming result of a shelf-triggered AI action.
    private var aiPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: aiAction?.systemImage ?? "wand.and.stars")
                    .foregroundStyle(Theme.accent)
                Text(aiAction?.title ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Label("On-device", systemImage: "sparkles")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Theme.accentSoft, in: Capsule())
                Spacer()
                Button { cancelAI() } label: {
                    Image(systemName: "xmark").foregroundStyle(Theme.textSecondary)
                }.buttonStyle(.plain)
            }
            ScrollView {
                Text(aiError ?? aiText)
                    .font(.system(size: 12))
                    .foregroundStyle(aiError != nil ? .orange : Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: .infinity)
            HStack {
                if aiStreaming {
                    ProgressView().controlSize(.small)
                    Text("Generating…").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                }
                Spacer()
                Button { cancelAI() } label: {
                    Text("Back").font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                }.buttonStyle(.plain)
                Button { pasteAIResult() } label: {
                    Label("Paste result", systemImage: "return")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 9))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(aiStreaming || aiText.isEmpty)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
                            isSelected: selectedID == item.id || copiedID == item.id,
                            onTap: { tapCard(item) },
                            onDoubleTap: { copy(item) }
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

    /// First tap selects (revealing the AI action bar); tapping the already-
    /// selected card copies it.
    private func tapCard(_ item: ClipItem) {
        if selectedID == item.id {
            copy(item)
        } else {
            withAnimation(.easeOut(duration: 0.15)) { selectedID = item.id }
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

    // MARK: - AI from the shelf

    private func runAI(_ action: AIAction) {
        guard let item = selectedItem else { return }
        guard availability.actionsActive else { return }   // AI off → chips already locked
        let lang = action.requiresLanguageArg ? "Italian" : nil
        AIUsageTracker.record(actionID: action.id, type: item.type, destinationBundleID: nil)
        aiAction = action
        aiText = ""
        aiError = nil
        aiStreaming = true
        aiTask?.cancel()
        aiTask = Task { @MainActor in
            do {
                for try await partial in engine.transform(action: action, clip: item, language: lang) {
                    if Task.isCancelled { break }
                    aiText = partial
                }
            } catch {
                aiError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            aiStreaming = false
        }
    }

    private func cancelAI() {
        aiTask?.cancel()
        aiStreaming = false
        aiAction = nil
        aiText = ""
        aiError = nil
    }

    private func pasteAIResult() {
        guard !aiText.isEmpty, let source = selectedItem else { return }
        // Save a derived clip (original preserved) then paste.
        let derived = ClipItem(type: .text, textContent: aiText, sourceAppName: "AI",
                               sourceAppBundleID: source.sourceAppBundleID, byteSize: aiText.utf8.count)
        storage.add(derived)
        let text = aiText
        cancelAI()
        onClose()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            PasteService.pasteText(text)
        }
    }
}
