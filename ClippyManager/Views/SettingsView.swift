import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @Environment(StorageManager.self) var storageManager
    @Environment(\.dismiss) private var dismiss

    @State private var maxItems: Double
    @State private var launchAtLogin = false
    @State private var showClearConfirm = false

    init() {
        let stored = UserDefaults.standard.integer(forKey: "maxHistoryItems")
        _maxItems = State(initialValue: Double(stored > 0 ? stored : 500))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // General
                    SettingsSection(title: "General") {
                        Toggle("Launch at login", isOn: $launchAtLogin)
                            .onChange(of: launchAtLogin) { _, newValue in
                                toggleLaunchAtLogin(newValue)
                            }
                    }

                    // History
                    SettingsSection(title: "History") {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Max items")
                                Spacer()
                                Text("\(Int(maxItems))")
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            Slider(value: $maxItems, in: 50...1000, step: 50)
                                .tint(Color(red: 0.08, green: 0.72, blue: 0.66))
                                .onChange(of: maxItems) { _, val in
                                    storageManager.update(maxItems: Int(val))
                                }
                        }
                    }

                    // Shortcut
                    SettingsSection(title: "Keyboard shortcut") {
                        HStack {
                            Text("Open panel")
                            Spacer()
                            ShortcutBadge(keys: ["⌘", "⇧", "V"])
                        }
                    }

                    // Danger zone
                    SettingsSection(title: "Data") {
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Label("Clear all history", systemImage: "trash")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .confirmationDialog("Clear all clipboard history?",
                                            isPresented: $showClearConfirm,
                                            titleVisibility: .visible) {
                            Button("Clear All", role: .destructive) {
                                storageManager.clearAll()
                                dismiss()
                            }
                            Button("Cancel", role: .cancel) {}
                        }
                    }

                    // About
                    SettingsSection(title: "About") {
                        HStack {
                            Text("Version")
                            Spacer()
                            Text("1.0.0")
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text("License")
                            Spacer()
                            Text("MIT")
                                .foregroundStyle(.secondary)
                        }
                        Link("GitHub Repository",
                             destination: URL(string: "https://github.com/simonegiammy/ClippyManager")!)
                        .font(.system(size: 13))
                    }
                }
                .padding(16)
            }
        }
        .frame(width: 360)
        .frame(minHeight: 400)
        .onAppear { checkLaunchAtLogin() }
    }

    // MARK: - Helpers

    private func checkLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func toggleLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently fail in dev builds (app not in /Applications)
        }
    }
}

// MARK: - Helper views

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .font(.system(size: 13))
        }
    }
}

struct ShortcutBadge: View {
    let keys: [String]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(keys, id: \.self) { key in
                Text(key)
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.primary.opacity(0.15), lineWidth: 0.5)
                            )
                    )
            }
        }
    }
}
