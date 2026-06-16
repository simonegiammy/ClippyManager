import SwiftUI

/// The contextual AI action chips shown under the focused clip.
/// First chip is the suggested default (highlighted). Locked style when AI is off.
struct ActionBarView: View {
    let actions: [AIAction]
    let locked: Bool
    var onPick: (AIAction) -> Void
    var onMore: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: locked ? "sparkles" : "wand.and.stars")
                .font(.system(size: 11))
                .foregroundStyle(locked ? Theme.textTertiary : Theme.accent)

            ForEach(Array(actions.prefix(3).enumerated()), id: \.element.id) { idx, action in
                chip(action, isDefault: idx == 0, number: idx + 1)
            }

            if actions.count > 3 {
                Button(action: onMore) {
                    Text("More")
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.pillInactive, in: Capsule())
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize()
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 4)

            if locked {
                Label("Locked", systemImage: "lock.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func chip(_ action: AIAction, isDefault: Bool, number: Int) -> some View {
        Button { onPick(action) } label: {
            HStack(spacing: 5) {
                Image(systemName: locked ? "lock.fill" : action.systemImage)
                    .font(.system(size: 10, weight: .medium))
                Text(action.title)
                    .font(.system(size: 12, weight: isDefault ? .semibold : .regular))
                    .lineLimit(1)
            }
            .padding(.horizontal, 11).padding(.vertical, 6)
            .background(
                isDefault && !locked ? AnyShapeStyle(LinearGradient(
                    colors: Theme.accentGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                    : AnyShapeStyle(Theme.pillInactive),
                in: Capsule()
            )
            .foregroundStyle(isDefault && !locked ? .white : Theme.textSecondary)
            .opacity(locked ? 0.7 : 1)
            .fixedSize()                       // never wrap to two lines
        }
        .buttonStyle(.plain)
        .help(action.title + (locked ? "" : " · ⌘\(number)"))
    }
}
