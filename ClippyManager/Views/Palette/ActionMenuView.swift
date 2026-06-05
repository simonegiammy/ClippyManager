import SwiftUI

/// Full list of actions for the focused clip (opened with → ), keyboard-selectable.
struct ActionMenuView: View {
    let entries: [PaletteController.ActionEntry]
    let selectedIndex: Int
    var onPick: (PaletteController.ActionEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ACTIONS")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
                .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 2)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 1) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { idx, entry in
                            row(entry, focused: idx == selectedIndex)
                                .id(idx)
                                .onTapGesture { onPick(entry) }
                        }
                    }
                    .padding(.horizontal, 6).padding(.bottom, 6)
                }
                .onChange(of: selectedIndex) { _, new in
                    withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(new, anchor: .center) }
                }
            }
        }
        .frame(maxHeight: 220)
    }

    private func row(_ entry: PaletteController.ActionEntry, focused: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: entry.action.systemImage)
                .font(.system(size: 11))
                .foregroundStyle(focused ? .white : Theme.accent)
                .frame(width: 16)
            Text(entry.title)
                .font(.system(size: 12))
                .foregroundStyle(focused ? .white : Theme.textPrimary)
            Spacer()
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(focused ? Theme.accent : Color.clear)
        )
    }
}
