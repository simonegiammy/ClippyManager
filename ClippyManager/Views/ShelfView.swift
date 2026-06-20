import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// Shelf layout metrics — static so AppDelegate can size the panel window to
/// exactly match the content (hug it; no dead space).
enum ShelfMetrics {
    static let width: CGFloat = 560
    static let menuBand: CGFloat = 34
    static let neck: CGFloat = 44      // teardrop neck: enough to taper, not a big empty gap
    static let cardRowHeight: CGFloat = 124

    // Estimated (slightly generous) heights of the stacked rows.
    static let topBarH: CGFloat = 28
    static let tabsH: CGFloat = 36
    static let bookmarksH: CGFloat = 54
    static let vSpacing: CGFloat = 10
    static let bottomPad: CGFloat = 14

    /// Empty glass between the notch and the first row (the emerging "neck").
    static var topInset: CGFloat { menuBand + neck + 6 }

    /// Exact panel height for the current content — compact with no bookmarks,
    /// taller when the bookmarks carousel is shown.
    static func bodyHeight(hasBookmarks: Bool) -> CGFloat {
        var h = topInset + topBarH + vSpacing + tabsH + vSpacing + cardRowHeight + bottomPad
        if hasBookmarks { h += vSpacing + bookmarksH }
        return h
    }
}

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
    @State private var growth: CGFloat = 0   // 0 closed (pill) → 1 open (panel)

    // AI preview state (inline, when an action runs from a card's context menu)
    @State private var aiAction: AIAction?
    @State private var aiItem: ClipItem?
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
    /// Reports the height the panel should be (so AppDelegate can resize the
    /// window when bookmarks appear/disappear).
    var onBodyHeightChange: (CGFloat) -> Void = { _ in }

    private var panelWidth: CGFloat { ShelfMetrics.width }
    private var menuBand: CGFloat { ShelfMetrics.menuBand }
    private var neck: CGFloat { ShelfMetrics.neck }
    private var cardRowHeight: CGFloat { ShelfMetrics.cardRowHeight }
    private var hasBookmarks: Bool { !bookmarkItems.isEmpty }
    /// Panel hugs its content: compact with no bookmarks, taller with them.
    private var bodyHeight: CGFloat { ShelfMetrics.bodyHeight(hasBookmarks: hasBookmarks) }

    /// Horizontal fade applied to carousels so items dissolve at the left/right
    /// edges instead of being cut off sharply.
    private var carouselFade: LinearGradient {
        LinearGradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: .black, location: 0.05),
            .init(color: .black, location: 0.95),
            .init(color: .clear, location: 1.0),
        ], startPoint: .leading, endPoint: .trailing)
    }

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
            // 1. The glass body — vibrancy masked to the NotchShape natively in
            //    Core Animation (SwiftUI .clipShape can't mask an NSVisualEffectView,
            //    which left un-rounded black corners). It grows/retracts itself.
            NotchGlass(isOpen: controller.isOpen,
                       width: panelWidth, height: bodyHeight, menuBand: menuBand,
                       neckDepth: neck,
                       openDuration: ShelfController.openDuration,
                       closeDuration: ShelfController.closeDuration)
                .frame(width: panelWidth, height: bodyHeight)
                .overlay(
                    NotchShape(progress: growth, menuBand: menuBand, neckDepth: neck)
                        .stroke(Theme.accent, lineWidth: isDropTargeted ? 2.5 : 0)
                )

            // 2. Content fades in only once the glass is nearly full, so tabs
            //    never appear over a still-small panel. Pinned to the TOP so it
            //    hugs the notch (no centered gap above the first row).
            content
                .frame(width: panelWidth, height: bodyHeight, alignment: .top)
                .opacity(growth > 0.8 ? Double((growth - 0.8) / 0.2) : 0)
                .allowsHitTesting(growth > 0.95)
        }
        .frame(width: panelWidth, height: bodyHeight, alignment: .top)
        .overlay(dropHint)
        .onDrop(of: [.image, .fileURL, .text, .plainText],
                isTargeted: $isDropTargeted) { providers in
            // Ignore drags that originated from the shelf itself — dragging a
            // card out and dropping it back must not duplicate it.
            if providers.contains(where: { $0.registeredTypeIdentifiers.contains(ClipDragMarker.typeID) }) {
                return false
            }
            return DropIngestor.ingest(providers: providers, into: storage)
        }
        .onHover { inside in handleHover(inside) }
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showAddCategory) {
            AddCategorySheet().environment(storage)
        }
        // Keep the shelf pinned open while a sheet or AI preview is up, so moving
        // the mouse away doesn't tear them down.
        .onChange(of: showAddCategory) { _, open in controller.keepOpen = open || aiAction != nil }
        .onChange(of: aiAction?.id) { _, _ in controller.keepOpen = showAddCategory || aiAction != nil }
        .onAppear { syncGrowth(animated: true); onBodyHeightChange(bodyHeight) }
        .onChange(of: controller.isOpen) { _, _ in syncGrowth(animated: true) }
        // Resize the window when the bookmarks carousel appears/disappears.
        .onChange(of: hasBookmarks) { _, _ in onBodyHeightChange(bodyHeight) }
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

    private var content: some View {
        VStack(spacing: 10) {
            topBar
            if aiAction != nil {
                aiPreview
            } else {
                CategoryTabsView(filter: filter, categories: categories,
                                 counts: counts, onAddCategory: { showAddCategory = true })
                bookmarksRow
                cards
            }
        }
        .padding(.top, menuBand + neck + 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
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
        if controller.keepOpen { return }   // sheet / AI preview open → stay
        if inside { return }
        // Near-instant on leave, with a tiny grace period only to tolerate the
        // pointer skimming the notch gap (matches NotchDock's snappy retract).
        let work = DispatchWorkItem {
            if copiedID == nil { onClose() }
        }
        leaveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: work)
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
            .background(Theme.panelBackground.opacity(0.9),
                        in: NotchShape(progress: 1, menuBand: menuBand, neckDepth: neck))
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

    /// Link clips in the current view, shown as a tappable bookmarks carousel
    /// above the clip carousel. Clicking one opens it in the default browser.
    private var bookmarkItems: [ClipItem] {
        allItems.filter { $0.type == .link && $0.isBookmarked }
    }

    @ViewBuilder
    private var bookmarksRow: some View {
        if !bookmarkItems.isEmpty {
            VStack(alignment: .leading, spacing: 5) {
                Label("Bookmarks", systemImage: "bookmark.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(bookmarkItems) { item in
                            Button { openLink(item) } label: {
                                HStack(spacing: 6) {
                                    FaviconView(host: item.linkHost, size: 15)
                                    Text(bookmarkLabel(item))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Theme.textPrimary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 9).padding(.vertical, 6)
                                .background(Theme.pillInactive, in: Capsule())
                                .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: 1))
                                .fixedSize()
                            }
                            .buttonStyle(.plain)
                            .help(item.linkURLString)
                        }
                    }
                    .padding(.vertical, 1)
                    .padding(.horizontal, 2)
                }
                .mask(carouselFade)
            }
        }
    }

    /// Short, readable label for a bookmark pill (host without scheme/www).
    private func bookmarkLabel(_ item: ClipItem) -> String {
        let raw = (item.sourceURL ?? item.textContent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let host = URL(string: raw)?.host {
            return host.replacingOccurrences(of: "www.", with: "")
        }
        return raw
    }

    private func openLink(_ item: ClipItem) {
        let raw = (item.sourceURL ?? item.textContent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: raw), url.scheme?.hasPrefix("http") == true else { return }
        NSWorkspace.shared.open(url)
        onClose()
    }

    @ViewBuilder
    private var cards: some View {
        Group {
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
                                onTap: { openItem(item) },
                                onDoubleTap: { openItem(item) }
                            )
                            .frame(width: 130, height: 120)
                            .contextMenu { contextMenu(for: item) }
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 2)
                }
                .mask(carouselFade)
            }
        }
        .frame(height: cardRowHeight)   // empty == full → no height jump
    }

    @ViewBuilder
    private func contextMenu(for item: ClipItem) -> some View {
        Button { copy(item) } label: { Label("Copy", systemImage: "doc.on.doc") }

        if item.type == .file {
            Button { openItem(item) } label: {
                Label(item.isFolder ? "Open Folder" : "Open File", systemImage: "arrow.up.forward.app")
            }
        }
        if item.type == .link {
            Button { openLink(item) } label: { Label("Open Link", systemImage: "safari") }
            Button { toggleBookmark(item) } label: {
                Label(item.isBookmarked ? "Remove from Bookmarks" : "Add to Bookmarks",
                      systemImage: item.isBookmarked ? "bookmark.slash" : "bookmark")
            }
        }

        Button { toggleFavorite(item) } label: {
            Label(item.isPinned ? "Unfavorite" : "Favorite",
                  systemImage: item.isPinned ? "star.slash" : "star")
        }

        // AI actions live here now (right-click), not on a single click.
        let actions = aiActions(for: item)
        if !actions.isEmpty {
            Divider()
            if availability.actionsActive {
                Menu {
                    ForEach(actions, id: \.id) { action in
                        Button { runAI(action, on: item) } label: {
                            Label(action.title, systemImage: action.systemImage)
                        }
                    }
                } label: { Label("AI Actions", systemImage: "wand.and.stars") }
            } else {
                Button {} label: { Label("AI Actions — enable Apple Intelligence", systemImage: "lock.fill") }
                    .disabled(true)
            }
        }

        if !categories.isEmpty {
            Divider()
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

    /// Double-click: open files/folders in Finder, links in the browser; anything
    /// else just copies (the classic behavior).
    private func openItem(_ item: ClipItem) {
        switch item.type {
        case .file:
            let paths = (item.textContent ?? "").components(separatedBy: "\n").filter { !$0.isEmpty }
            for p in paths { NSWorkspace.shared.open(URL(fileURLWithPath: p)) }
            onClose()
        case .link:
            let raw = (item.sourceURL ?? item.textContent ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: raw), url.scheme?.hasPrefix("http") == true {
                NSWorkspace.shared.open(url)
                onClose()
            } else {
                copy(item)
            }
        default:
            copy(item)
        }
    }

    private func toggleFavorite(_ item: ClipItem) {
        item.isPinned.toggle()
        try? modelContext.save()
    }

    private func toggleBookmark(_ item: ClipItem) {
        item.isBookmarked.toggle()
        try? modelContext.save()
    }

    // MARK: - AI from the shelf (right-click → AI Actions)

    private func aiActions(for item: ClipItem) -> [AIAction] {
        guard !item.isSensitive else { return [] }
        return AIActionCatalog.actions(for: item, destinationBundleID: nil)
    }

    private func runAI(_ action: AIAction, on item: ClipItem) {
        guard availability.actionsActive else { return }
        let lang = action.requiresLanguageArg ? "Italian" : nil
        AIUsageTracker.record(actionID: action.id, type: item.type, destinationBundleID: nil)
        aiItem = item
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
        aiItem = nil
        aiText = ""
        aiError = nil
    }

    private func pasteAIResult() {
        guard !aiText.isEmpty, let source = aiItem else { return }
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
