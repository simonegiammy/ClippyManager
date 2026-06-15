import SwiftUI

/// Shown when 2+ clips are multi-selected: batch operations across them.
struct BatchBarView: View {
    let count: Int
    let locked: Bool
    var onRun: (PaletteController.BatchOp) -> Void
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 11)).foregroundStyle(Theme.accent)
            Text("\(count) selected")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            ForEach(Array(PaletteController.BatchOp.allCases.enumerated()), id: \.element.id) { idx, op in
                Button { onRun(op) } label: {
                    HStack(spacing: 4) {
                        Image(systemName: (locked && op.needsAI) ? "lock.fill" : op.systemImage)
                            .font(.system(size: 9, weight: .medium))
                        Text(op.title).font(.system(size: 11, weight: idx == 0 ? .semibold : .regular))
                        Text("⌘\(idx + 1)").font(.system(size: 8, weight: .medium))
                            .foregroundStyle(idx == 0 ? .white.opacity(0.7) : Theme.textTertiary)
                    }
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(idx == 0 && !(locked && op.needsAI) ? Theme.accent : Theme.pillInactive,
                                in: Capsule())
                    .foregroundStyle(idx == 0 && !(locked && op.needsAI) ? .white : Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Button { onClear() } label: {
                Text("Clear").font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(Theme.accentSoft)
    }
}
