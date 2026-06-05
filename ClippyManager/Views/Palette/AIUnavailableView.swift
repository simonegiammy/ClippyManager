import SwiftUI

/// Teaser shown when an AI action is invoked but Apple Intelligence isn't available.
/// Sells the value (what you'd get) and guides the user to enable it.
struct AIUnavailableView: View {
    let status: AIStatus
    let action: AIAction?
    let availability: AIAvailability
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles").foregroundStyle(Theme.accent)
                Text(action.map { "“\($0.title)” needs Apple Intelligence" } ?? "AI actions")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark").foregroundStyle(Theme.textSecondary)
                }.buttonStyle(.plain)
            }

            // What you'd get (sell before install).
            if let example = exampleFor(action) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("HERE'S WHAT YOU'D GET")
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(Theme.textTertiary)
                    Text(example)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 8))
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "lock.shield")
                Text("Runs 100% on-device — nothing ever leaves your Mac.")
            }
            .font(.system(size: 10)).foregroundStyle(Theme.accent)

            Divider().overlay(Theme.cardBorder)

            // The honest status + guidance.
            Text(status.explanation)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)

            if !status.fixSteps.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(status.fixSteps.enumerated()), id: \.offset) { i, step in
                        Text("\(i + 1). \(step)")
                            .font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                    }
                }
            }

            HStack {
                Spacer()
                if status.canFix {
                    Button { availability.openFix() } label: {
                        Text(status.fixActionLabel)
                            .font(.system(size: 12, weight: .semibold))
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.white)
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(width: 380)
        .background(Theme.panelBackgroundElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func exampleFor(_ action: AIAction?) -> String? {
        switch action?.id {
        case "summarize":    "A 1–2 sentence summary of the clip, in its original language."
        case "translate":    "The clip translated into your chosen language."
        case "fix_grammar":  "The same text with spelling and grammar corrected."
        case "explain_code": "A plain-English explanation of what the code does."
        case "to_json":      "The content converted into clean, valid JSON."
        case "to_table":     "The content organized into a tidy markdown table."
        case "tldr_bullets", "extract_actions": "The key points pulled out as a bullet list."
        default:             "An instant on-device transformation of this clip."
        }
    }
}
