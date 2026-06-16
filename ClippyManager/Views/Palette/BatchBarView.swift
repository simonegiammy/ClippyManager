import SwiftUI

/// Shown when 2+ clips are multi-selected: batch operations across them.
struct BatchBarView: View {
    let count: Int
    let locked: Bool
    var onRun: (PaletteController.BatchOp) -> Void
    var onClear: () -> Void

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12)).foregroundStyle(Theme.accent)
            Text("\(count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize()

            ForEach(Array(PaletteController.BatchOp.allCases.enumerated()), id: \.element.id) { idx, op in
                let on = idx == 0 && !(locked && op.needsAI)
                Button { onRun(op) } label: {
                    HStack(spacing: 5) {
                        Image(systemName: (locked && op.needsAI) ? "lock.fill" : op.systemImage)
                            .font(.system(size: 10, weight: .medium))
                        Text(op.title)
                            .font(.system(size: 12, weight: idx == 0 ? .semibold : .regular))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(
                        on ? AnyShapeStyle(LinearGradient(colors: Theme.accentGradient,
                                                          startPoint: .topLeading, endPoint: .bottomTrailing))
                           : AnyShapeStyle(Theme.pillInactive),
                        in: Capsule())
                    .foregroundStyle(on ? .white : Theme.textSecondary)
                    .fixedSize()
                }
                .buttonStyle(.plain)
                .help(op.title + " · ⌘\(idx + 1)")
            }

            Spacer(minLength: 4)

            Button { onClear() } label: {
                Text("Clear").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
            }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
    }
}
