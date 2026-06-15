import SwiftUI

/// The contextual AI action chips shown under the focused clip.
/// First chip is the suggested default (highlighted). Locked style when AI is off.
struct ActionBarView: View {
    let actions: [AIAction]
    let locked: Bool
    var onPick: (AIAction) -> Void
    var onMore: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: locked ? "sparkles" : "wand.and.stars")
                .font(.system(size: 10))
                .foregroundStyle(locked ? Theme.textTertiary : Theme.accent)

            ForEach(Array(actions.prefix(4).enumerated()), id: \.element.id) { idx, action in
                chip(action, isDefault: idx == 0, number: idx + 1)
            }

            if actions.count > 4 {
                Button(action: onMore) {
                    Text("More →")
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(Theme.pillInactive, in: Capsule())
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            if locked {
                Label("Locked", systemImage: "lock.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                Text("⌘↩ default · → menu")
                    .font(.system(size: 9))
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.04))
    }

    private func chip(_ action: AIAction, isDefault: Bool, number: Int) -> some View {
        Button { onPick(action) } label: {
            HStack(spacing: 4) {
                Image(systemName: locked ? "lock.fill" : action.systemImage)
                    .font(.system(size: 9, weight: .medium))
                Text(action.title)
                    .font(.system(size: 11, weight: isDefault ? .semibold : .regular))
                if !locked {
                    Text("⌘\(number)")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(isDefault ? .white.opacity(0.7) : Theme.textTertiary)
                }
            }
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(
                isDefault && !locked ? Theme.accent : Theme.pillInactive,
                in: Capsule()
            )
            .foregroundStyle(isDefault && !locked ? .white : Theme.textSecondary)
            .opacity(locked ? 0.7 : 1)
        }
        .buttonStyle(.plain)
    }
}
