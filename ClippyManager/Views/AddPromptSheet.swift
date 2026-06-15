import SwiftUI

/// Sheet to create a saved custom AI prompt.
struct AddPromptSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onSave: (String, String) -> Void

    @State private var title = ""
    @State private var instruction = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("New Custom Prompt")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text("Name").font(.caption).foregroundStyle(Theme.textSecondary)
                TextField("e.g. My email style", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Instruction").font(.caption).foregroundStyle(Theme.textSecondary)
                TextEditor(text: $instruction)
                    .font(.system(size: 12))
                    .frame(height: 90)
                    .padding(4)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
                Text("The clip text is appended automatically. Example: “Rewrite the following in a warm, concise email tone.”")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    let t = title.trimmingCharacters(in: .whitespaces)
                    let i = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !t.isEmpty, !i.isEmpty else { return }
                    onSave(t, i)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty ||
                          instruction.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
        .background(Theme.panelBackground)
        .environment(\.colorScheme, .dark)
    }
}
