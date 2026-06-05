import SwiftUI
import SwiftData

/// Horizontal pill tabs: History · Favorites · custom categories · "+".
struct CategoryTabsView: View {
    @Bindable var filter: ClipFilter
    let categories: [Category]
    let counts: [PrimaryTab: Int]
    var onAddCategory: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                pill(.history, label: "History", icon: "clock.arrow.circlepath")
                pill(.favorites, label: "Favorites", icon: "star.fill")

                ForEach(categories) { cat in
                    pill(.category(cat.id), label: cat.name, icon: cat.systemImage, tint: cat.color)
                }

                Button(action: onAddCategory) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 26, height: 26)
                        .background(Theme.pillInactive, in: Circle())
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 2)
        }
    }

    private func pill(_ tab: PrimaryTab, label: String, icon: String, tint: Color? = nil) -> some View {
        let isActive = filter.tab == tab
        let count = counts[tab] ?? 0
        return Button {
            filter.tab = tab
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isActive ? Theme.pillActiveText : (tint ?? Theme.pillInactiveText))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(isActive ? Theme.pillActiveText.opacity(0.6) : Theme.textTertiary)
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(isActive ? Theme.pillActive : Theme.pillInactive,
                        in: RoundedRectangle(cornerRadius: Theme.pillRadius))
            .foregroundStyle(isActive ? Theme.pillActiveText : Theme.pillInactiveText)
        }
        .buttonStyle(.plain)
    }
}

/// Secondary filter row: type filter + app filter dropdowns.
struct FilterBarView: View {
    @Bindable var filter: ClipFilter
    let sourceApps: [(id: String, name: String)]

    var body: some View {
        HStack(spacing: 8) {
            Menu {
                Button("All Types") { filter.typeFilter = nil }
                Divider()
                ForEach(ClipItemType.allCases) { type in
                    Button {
                        filter.typeFilter = type
                    } label: {
                        Label(type.label, systemImage: type.systemImage)
                    }
                }
            } label: {
                filterChip(
                    icon: filter.typeFilter?.systemImage ?? "line.3.horizontal.decrease.circle",
                    text: filter.typeFilter?.label ?? "All Types",
                    active: filter.typeFilter != nil
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Menu {
                Button("All Apps") { filter.appFilter = nil }
                Divider()
                ForEach(sourceApps, id: \.id) { app in
                    Button(app.name) { filter.appFilter = app.id }
                }
            } label: {
                filterChip(
                    icon: "app.dashed",
                    text: appName(filter.appFilter) ?? "All Apps",
                    active: filter.appFilter != nil
                )
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Spacer()

            Button {
                filter.sortNewestFirst.toggle()
            } label: {
                filterChip(
                    icon: filter.sortNewestFirst ? "arrow.down" : "arrow.up",
                    text: filter.sortNewestFirst ? "Newest" : "Oldest",
                    active: false
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func appName(_ id: String?) -> String? {
        guard let id else { return nil }
        return sourceApps.first { $0.id == id }?.name
    }

    private func filterChip(icon: String, text: String, active: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9))
            Text(text).font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(active ? Theme.accentSoft : Theme.pillInactive,
                    in: RoundedRectangle(cornerRadius: 7))
        .foregroundStyle(active ? Theme.accent : Theme.textSecondary)
    }
}
