import SwiftUI
import AppKit

/// The vertical, keyboard-first paste palette (⌃⌘V). Renders the controller's
/// state and routes keystrokes via a local NSEvent monitor.
struct PastePaletteView: View {
    @Bindable var controller: PaletteController
    @FocusState private var searchFocused: Bool
    @State private var keyMonitor: Any?
    @State private var appeared = false

    var body: some View {
        panel
            // Genie grow: scales up from the top edge with a springy overshoot,
            // echoing the notch shelf's "drop" feel.
            .scaleEffect(x: appeared ? 1 : 0.88, y: appeared ? 1 : 0.6, anchor: .top)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.timingCurve(0.34, 1.32, 0.42, 1, duration: 0.5)) { appeared = true }
            }
    }

    private var panel: some View {
        VStack(spacing: 0) {
            searchBar
            Divider().overlay(Theme.cardBorder)

            if controller.mode == .preview {
                TransformPreviewView(controller: controller)
            } else {
                listSection
                if controller.mode == .actionMenu {
                    Divider().overlay(Theme.cardBorder)
                    ActionMenuView(entries: controller.expandedActions,
                                   selectedIndex: controller.actionIndex,
                                   onPick: { entry in
                                       if let item = controller.focusedItem {
                                           controller.handlePick(entry, item: item)
                                       }
                                   })
                } else if controller.isMultiSelecting {
                    Divider().overlay(Theme.cardBorder)
                    BatchBarView(count: controller.selectedClips.count,
                                 locked: !controller.availability.actionsActive,
                                 onRun: { controller.runBatch($0) },
                                 onClear: { controller.clearSelection() })
                } else if controller.showsActionBar {
                    Divider().overlay(Theme.cardBorder)
                    ActionBarView(actions: controller.actions,
                                  locked: !controller.availability.actionsActive,
                                  onPick: { controller.pick($0) },
                                  onMore: { controller.mode = .actionMenu; controller.actionIndex = 0 })
                }
            }
        }
        .frame(width: 560)
        .frame(minHeight: 360, maxHeight: 520)
        .glassPanel(cornerRadius: 16)
        .overlay {
            if controller.showUnavailable {
                ZStack {
                    Color.black.opacity(0.5).onTapGesture { controller.dismissTeaser() }
                    AIUnavailableView(status: controller.availability.status,
                                      action: controller.teaserAction,
                                      availability: controller.availability,
                                      onDismiss: { controller.dismissTeaser() })
                }
            }
        }
        .environment(\.colorScheme, .dark)
        .onAppear { searchFocused = true; installMonitor() }
        .onDisappear { removeMonitor() }
    }

    // MARK: - Sections

    private var searchBar: some View {
        HStack(spacing: 9) {
            Image(systemName: controller.selectionMode ? "text.cursor" : "magnifyingglass")
                .font(.system(size: 13)).foregroundStyle(Theme.textTertiary)
            if controller.selectionMode {
                Text("Transform selection · pick an action, ⌘↩ for default")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else if controller.isMultiSelecting {
                Text("Multi-select · space toggles · ⌘1–3 batch action")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextField("Search · ↩ paste · ⌘↩ AI · space to multi-select", text: $controller.search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textPrimary)
                    .focused($searchFocused)
            }
            if controller.availability.actionsActive {
                Label("AI on-device", systemImage: "sparkles")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    @ViewBuilder
    private var listSection: some View {
        if controller.filtered.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "tray").font(.system(size: 26)).foregroundStyle(Theme.textTertiary)
                Text(controller.search.isEmpty ? "Nothing copied yet" : "No results")
                    .font(.system(size: 12)).foregroundStyle(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 200)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(controller.filtered.enumerated()), id: \.element.id) { idx, item in
                            PaletteRowView(item: item,
                                           isFocused: idx == controller.focusedIndex,
                                           isSelected: controller.selectedIDs.contains(item.id),
                                           showSelection: controller.isMultiSelecting)
                                .id(idx)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if controller.isMultiSelecting {
                                        controller.toggleSelection(of: item)
                                    } else {
                                        controller.focusedIndex = idx
                                    }
                                }
                                .simultaneousGesture(TapGesture().modifiers(.command).onEnded {
                                    controller.toggleSelection(of: item)
                                })
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 360)
                .onChange(of: controller.focusedIndex) { _, new in
                    withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(new, anchor: .center) }
                }
            }
        }
    }

    // MARK: - Key monitor

    private func installMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            controller.handleKey(event) ? nil : event
        }
    }

    private func removeMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}
