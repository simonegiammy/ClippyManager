import SwiftUI

/// Streaming result panel with the on-device badge, inline edit, and accept/regenerate.
struct TransformPreviewView: View {
    @Bindable var controller: PaletteController

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().overlay(Theme.cardBorder)
            content
            Divider().overlay(Theme.cardBorder)
            footer
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            if let a = controller.currentAction {
                Image(systemName: a.systemImage).foregroundStyle(Theme.accent)
                Text(a.title + (controller.currentLanguage.map { " \($0)" } ?? ""))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            Spacer()
            // The single, real differentiator — shown right at transform time.
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                Text("On-device · nothing leaves your Mac")
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Theme.accentSoft, in: Capsule())
        }
        .padding(12)
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let err = controller.previewError {
                    Label(err, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12))
                        .foregroundStyle(.orange)
                } else {
                    // Editable result (it's just text).
                    TextEditor(text: $controller.previewText)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textPrimary)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                    if controller.isStreaming {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Generating…").font(.system(size: 11)).foregroundStyle(Theme.textTertiary)
                        }
                    }
                }
            }
            .padding(12)
        }
        .frame(maxHeight: 240)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button { controller.revert() } label: {
                Label("Back", systemImage: "arrow.uturn.left").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(Theme.textSecondary)

            Button { controller.regenerate() } label: {
                Label("Regenerate", systemImage: "arrow.clockwise").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundStyle(Theme.textSecondary)
            .disabled(controller.isStreaming)

            Spacer()

            Text("⌘R regenerate · esc back")
                .font(.system(size: 9)).foregroundStyle(Theme.textTertiary)

            Button { controller.acceptResult() } label: {
                Label("Paste result  ⌘↩", systemImage: "return")
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(controller.isStreaming || controller.previewText.isEmpty)
        }
        .padding(12)
    }
}
