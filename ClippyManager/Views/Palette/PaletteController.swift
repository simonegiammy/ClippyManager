import AppKit
import Observation

/// The brain of the paste palette: holds state, runs AI actions, and routes
/// keystrokes for the three-key flow (Enter / Cmd+Enter / → menu).
@Observable
@MainActor
final class PaletteController {
    enum Mode: Equatable { case browsing, actionMenu, preview }

    // Injected
    let availability: AIAvailability
    let engine: AIEngine
    let destinationBundleID: String?
    private let onPasteOriginal: (ClipItem) -> Void
    private let onPasteText: (String, ClipItem) -> Void
    private let onClose: () -> Void

    // Data
    var allItems: [ClipItem] = []
    var customActions: [AIAction] = []     // saved custom prompts

    /// Selection-in-place mode: a single transient clip; accept replaces the
    /// user's live selection instead of saving to history.
    var selectionMode: Bool = false
    var search: String = "" { didSet { if focusedIndex >= filtered.count { focusedIndex = max(0, filtered.count - 1) } } }

    // Navigation
    var mode: Mode = .browsing
    var focusedIndex: Int = 0
    var actionIndex: Int = 0

    // Preview
    var currentAction: AIAction?
    var currentLanguage: String?
    var previewText: String = ""
    var isStreaming: Bool = false
    var previewError: String?
    var chainTitles: [String] = []     // breadcrumb of applied actions
    var showChainMenu: Bool = false
    private var runTask: Task<Void, Never>?

    // Unavailable teaser
    var showUnavailable: Bool = false
    var teaserAction: AIAction?

    init(availability: AIAvailability, engine: AIEngine, destinationBundleID: String?,
         onPasteOriginal: @escaping (ClipItem) -> Void,
         onPasteText: @escaping (String, ClipItem) -> Void,
         onClose: @escaping () -> Void) {
        self.availability = availability
        self.engine = engine
        self.destinationBundleID = destinationBundleID
        self.onPasteOriginal = onPasteOriginal
        self.onPasteText = onPasteText
        self.onClose = onClose
    }

    // MARK: - Derived

    var filtered: [ClipItem] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return allItems }
        return allItems.filter {
            ($0.textContent?.lowercased().contains(q) ?? false) ||
            ($0.sourceAppName?.lowercased().contains(q) ?? false) ||
            $0.type.label.lowercased().contains(q)
        }
    }

    var focusedItem: ClipItem? {
        let f = filtered
        guard f.indices.contains(focusedIndex) else { return nil }
        return f[focusedIndex]
    }

    /// Actions for the focused clip (empty if sensitive or non-actionable type).
    /// Built-in contextual actions first, then the user's saved custom prompts.
    var actions: [AIAction] {
        guard let item = focusedItem, !item.isSensitive else { return [] }
        let builtin = AIActionCatalog.actions(for: item, destinationBundleID: destinationBundleID)
        let custom = customActions.filter { $0.applicableTypes.contains(item.type) }
        return builtin + custom
    }

    var defaultAction: AIAction? { actions.first }

    /// Whether AI chips should appear at all (actionable clip present).
    var showsActionBar: Bool {
        guard let item = focusedItem else { return false }
        return !item.isSensitive && !actions.isEmpty && availability.userEnabled
    }

    // MARK: - Keyboard

    /// Returns true if the event was handled (and should be swallowed).
    func handleKey(_ event: NSEvent) -> Bool {
        let cmd = event.modifierFlags.contains(.command)
        switch event.keyCode {
        case 53: // esc
            handleEscape(); return true
        case 36, 76: // return / keypad enter
            return handleReturn(cmd: cmd)
        case 125: // down
            move(1); return true
        case 126: // up
            move(-1); return true
        case 124: // right arrow
            if mode == .browsing, showsActionBar { mode = .actionMenu; actionIndex = 0; return true }
            return false
        case 123: // left arrow
            if mode == .actionMenu { mode = .browsing; return true }
            return false
        case 15: // R
            if cmd, mode == .preview { regenerate(); return true }
            return false
        case 18, 19, 20, 21, 23, 22, 26, 28, 25: // 1…9
            if cmd, mode == .browsing {
                let digits: [UInt16: Int] = [18:0, 19:1, 20:2, 21:3, 23:4, 22:5, 26:6, 28:7, 25:8]
                if let idx = digits[event.keyCode] { runQuickAction(idx); return true }
            }
            return false
        default:
            return false
        }
    }

    /// Cmd+N → run the Nth action chip on the focused clip.
    private func runQuickAction(_ index: Int) {
        guard let item = focusedItem else { return }
        let list = actions
        guard list.indices.contains(index) else { return }
        let action = list[index]
        let lang = action.requiresLanguageArg ? Self.translateLanguages[0] : nil
        trigger(action, on: item, language: lang)
    }

    /// Returns whether the Return key was consumed.
    private func handleReturn(cmd: Bool) -> Bool {
        switch mode {
        case .browsing:
            guard let item = focusedItem else { return true }
            if cmd {
                // Cmd+Enter → default AI action (or paste original if none/teaser)
                if let action = defaultAction { trigger(action, on: item) }
                else { onPasteOriginal(item) }
            } else {
                onPasteOriginal(item)   // Enter → original, sacred
            }
            return true
        case .actionMenu:
            let menu = expandedActions
            guard menu.indices.contains(actionIndex), let item = focusedItem else { return true }
            trigger(menu[actionIndex].action, on: item, language: menu[actionIndex].language)
            return true
        case .preview:
            // The result is editable: plain Return inserts a newline; ⌘Return pastes.
            if cmd { acceptResult(); return true }
            return false
        }
    }

    private func handleEscape() {
        switch mode {
        case .browsing:  onClose()
        case .actionMenu: mode = .browsing
        case .preview:   revert()
        }
    }

    private func move(_ delta: Int) {
        switch mode {
        case .browsing:
            let n = filtered.count
            guard n > 0 else { return }
            focusedIndex = (focusedIndex + delta + n) % n
        case .actionMenu:
            let n = expandedActions.count
            guard n > 0 else { return }
            actionIndex = (actionIndex + delta + n) % n
        case .preview:
            break
        }
    }

    // MARK: - Action menu expansion (translate → languages)

    struct ActionEntry: Identifiable {
        let action: AIAction
        let language: String?
        var id: String { action.id + (language ?? "") }
        var title: String { language != nil ? "\(action.title) \(language!)" : action.title }
    }

    private static let translateLanguages = ["Italian", "English", "Spanish", "French", "German"]

    var expandedActions: [ActionEntry] {
        actions.flatMap { action -> [ActionEntry] in
            if action.requiresLanguageArg {
                return Self.translateLanguages.map { ActionEntry(action: action, language: $0) }
            }
            return [ActionEntry(action: action, language: nil)]
        }
    }

    // MARK: - Running

    func triggerDefault() {
        guard let item = focusedItem, let action = defaultAction else { return }
        trigger(action, on: item)
    }

    /// Run an action chip clicked in the action bar (browsing mode).
    func pick(_ action: AIAction) {
        guard let item = focusedItem else { return }
        let lang = action.requiresLanguageArg ? Self.translateLanguages[0] : nil
        trigger(action, on: item, language: lang)
    }

    /// Run a specific expanded entry chosen from the full action menu.
    func handlePick(_ entry: ActionEntry, item: ClipItem) {
        trigger(entry.action, on: item, language: entry.language)
    }

    private func trigger(_ action: AIAction, on item: ClipItem, language: String? = nil) {
        // Gating: unavailable → teaser instead of running.
        guard availability.actionsActive else {
            teaserAction = action
            showUnavailable = true
            return
        }
        AIUsageTracker.record(actionID: action.id, type: item.type,
                              destinationBundleID: destinationBundleID)
        currentAction = action
        currentLanguage = language ?? (action.requiresLanguageArg ? Self.translateLanguages[0] : nil)
        chainTitles = [action.title + (currentLanguage.map { " \($0)" } ?? "")]
        mode = .preview
        runStream(action: action, item: item, language: currentLanguage)
    }

    // MARK: - Chaining (apply another action to the current result)

    /// Actions that can be chained onto the streamed text result.
    var chainableActions: [AIAction] {
        AIActionCatalog.all.filter { $0.applicableTypes.contains(.text) && $0.id != currentAction?.id }
    }

    func chain(_ action: AIAction, language: String? = nil) {
        guard !previewText.isEmpty else { return }
        let lang = language ?? (action.requiresLanguageArg ? Self.translateLanguages[0] : nil)
        if let item = focusedItem {
            AIUsageTracker.record(actionID: action.id, type: item.type,
                                  destinationBundleID: destinationBundleID)
        }
        currentAction = action
        currentLanguage = lang
        chainTitles.append(action.title + (lang.map { " \($0)" } ?? ""))
        showChainMenu = false
        runStreamText(action: action, input: previewText, language: lang)
    }

    private func runStreamText(action: AIAction, input: String, language: String?) {
        runTask?.cancel()
        previewText = ""
        previewError = nil
        isStreaming = true
        runTask = Task { @MainActor in
            do {
                for try await partial in engine.transform(action: action, text: input, language: language) {
                    if Task.isCancelled { break }
                    previewText = partial
                }
            } catch {
                previewError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isStreaming = false
        }
    }

    private func runStream(action: AIAction, item: ClipItem, language: String?) {
        runTask?.cancel()
        previewText = ""
        previewError = nil
        isStreaming = true
        runTask = Task { @MainActor in
            do {
                for try await partial in engine.transform(action: action, clip: item, language: language) {
                    if Task.isCancelled { break }
                    previewText = partial
                }
            } catch {
                previewError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isStreaming = false
        }
    }

    func regenerate() {
        guard let action = currentAction, let item = focusedItem else { return }
        engine.resetSession()
        runStream(action: action, item: item, language: currentLanguage)
    }

    func revert() {
        runTask?.cancel()
        isStreaming = false
        previewText = ""
        previewError = nil
        currentAction = nil
        chainTitles = []
        mode = .browsing
    }

    func acceptResult() {
        guard !previewText.isEmpty, let source = focusedItem, let action = currentAction else { return }
        onPasteText(previewText, source)   // AppDelegate saves derived clip + pastes
        _ = action
    }

    func dismissTeaser() { showUnavailable = false; teaserAction = nil }

    func close() { runTask?.cancel(); onClose() }
}
