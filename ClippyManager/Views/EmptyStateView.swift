import SwiftUI

struct EmptyStateView: View {
    let hasSearch: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: hasSearch ? "magnifyingglass" : "doc.on.clipboard")
                .font(.system(size: 32))
                .foregroundStyle(.quaternary)
            Text(hasSearch ? "No results" : "Nothing here yet")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
            if !hasSearch {
                Text("Copy something to get started")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}
