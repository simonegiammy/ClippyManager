import SwiftUI

struct AddCategorySheet: View {
    @Environment(StorageManager.self) private var storage
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var icon = "square.grid.2x2"
    @State private var colorHex = "#0080FF"

    private let icons = [
        "square.grid.2x2", "text.bubble.fill", "sparkles", "star.fill",
        "folder.fill", "paintpalette.fill", "curlybraces", "photo.fill",
        "link", "tag.fill", "bookmark.fill", "flame.fill"
    ]
    private let colors = ["#0080FF", "#A855F7", "#FF9500", "#34C759", "#FF3B30", "#FF2D92", "#5AC8FA", "#FFCC00"]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Category")
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)

            TextField("Name", text: $name)
                .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 6) {
                Text("Icon").font(.caption).foregroundStyle(Theme.textSecondary)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                    ForEach(icons, id: \.self) { ic in
                        Image(systemName: ic)
                            .font(.system(size: 15))
                            .frame(width: 34, height: 34)
                            .background(icon == ic ? Theme.accent : Theme.pillInactive,
                                        in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(icon == ic ? .white : Theme.textSecondary)
                            .onTapGesture { icon = ic }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Color").font(.caption).foregroundStyle(Theme.textSecondary)
                HStack(spacing: 8) {
                    ForEach(colors, id: \.self) { hex in
                        Circle()
                            .fill(Color(hex: hex) ?? .blue)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle().stroke(.white, lineWidth: colorHex == hex ? 2 : 0)
                            )
                            .onTapGesture { colorHex = hex }
                    }
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    let trimmed = name.trimmingCharacters(in: .whitespaces)
                    guard !trimmed.isEmpty else { return }
                    storage.addCategory(name: trimmed, systemImage: icon, colorHex: colorHex)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }
}
