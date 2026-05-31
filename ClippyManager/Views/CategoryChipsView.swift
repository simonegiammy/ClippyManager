import SwiftUI

struct CategoryChipsView: View {
    @Binding var selected: ClipItemType?

    private let categories: [(id: String, type: ClipItemType?, label: String, icon: String)] = [
        ("all",   nil,    "All",    "tray"),
        ("text",  .text,  "Text",   "doc.text"),
        ("link",  .link,  "Links",  "link"),
        ("code",  .code,  "Code",   "chevron.left.forwardslash.chevron.right"),
        ("color", .color, "Colors", "paintpalette"),
        ("image", .image, "Images", "photo"),
        ("file",  .file,  "Files",  "doc"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(categories, id: \.id) { cat in
                    ChipButton(
                        label: cat.label,
                        icon: cat.icon,
                        isSelected: selected == cat.type,
                        accentColor: cat.type?.accentColor ?? Color(red: 0.08, green: 0.72, blue: 0.66)
                    ) {
                        if cat.type == nil {
                            selected = nil
                        } else {
                            selected = (selected == cat.type) ? nil : cat.type
                        }
                    }
                }
            }
        }
    }
}

struct ChipButton: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let accentColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Capsule().fill(isSelected ? accentColor : Color.primary.opacity(0.07)))
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }
}
