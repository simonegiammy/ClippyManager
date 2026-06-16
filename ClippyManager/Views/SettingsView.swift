import SwiftUI
import ServiceManagement

/// Preferences window. Dark-themed to match the app.
struct SettingsView: View {
    @Environment(StorageManager.self) private var storage
    @Environment(AIAvailability.self) private var ai

    @AppStorage("hoverToOpen") private var hoverToOpen = true
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true

    @State private var launchAtLogin = false
    @State private var maxItems: Double = 500
    @State private var showClearConfirm = false
    @State private var showAddPrompt = false
    @State private var promptsRefresh = 0   // bump to re-read prompts after edits


    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Color.clear.frame(height: 6)   // clear the transparent titlebar
                header

                section("General") {
                    toggleRow("Launch at login", systemImage: "power",
                              isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, v in setLaunchAtLogin(v) }

                    Divider().overlay(Theme.cardBorder)

                    toggleRow("Hover the notch to peek", systemImage: "cursorarrow.rays",
                              isOn: $hoverToOpen)
                        .onChange(of: hoverToOpen) { _, _ in
                            NotificationCenter.default.post(name: .clippyHoverSettingChanged, object: nil)
                        }
                }

                section("Capture") {
                    toggleRow("Pause clipboard capture", systemImage: "pause.circle",
                              isOn: Binding(get: { storage.isCapturePaused },
                                            set: { storage.isCapturePaused = $0 }))

                    Divider().overlay(Theme.cardBorder)

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("History limit", systemImage: "tray.full")
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text("\(Int(maxItems)) items")
                                .foregroundStyle(Theme.textSecondary)
                                .monospacedDigit()
                        }
                        Slider(value: $maxItems, in: 50...2000, step: 50)
                            .tint(Theme.accent)
                            .onChange(of: maxItems) { _, v in storage.update(maxItems: Int(v)) }
                    }
                    .font(.system(size: 13))
                }

                aiSection

                promptsSection

                section("Shortcuts") {
                    shortcutRow("Open the paste palette", keys: ["⌃", "⌘", "V"])
                    Divider().overlay(Theme.cardBorder)
                    shortcutRow("Paste recent clip", keys: ["⌃", "⌘", "0–9"])
                }

                section("Updates") {
                    toggleRow("Automatically check for updates", systemImage: "arrow.triangle.2.circlepath",
                              isOn: $autoCheckUpdates)
                    Text("When installed from the Mac App Store, updates are delivered automatically — this setting only applies to direct downloads.")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                    Button("Check for Updates…") {
                        NSWorkspace.shared.open(URL(string: "https://github.com/simonegiammy/ClippyManager/releases")!)
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
                }


                section("Data") {
                    Button(role: .destructive) { showClearConfirm = true } label: {
                        Label("Clear all history", systemImage: "trash")
                            .foregroundStyle(.red)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog("Clear all clipboard history?",
                                        isPresented: $showClearConfirm, titleVisibility: .visible) {
                        Button("Clear All", role: .destructive) { storage.clearAll() }
                        Button("Cancel", role: .cancel) {}
                    }
                }

                aboutFooter
            }
            .padding(22)
        }
        .frame(width: 380, height: 560)
        .background(GlassWindowFill())
        .environment(\.colorScheme, .dark)
        .sheet(isPresented: $showAddPrompt) {
            AddPromptSheet { title, instruction in
                storage.addCustomPrompt(title: title, instruction: instruction)
                promptsRefresh += 1
            }
        }
        .onAppear {
            launchAtLogin = (SMAppService.mainApp.status == .enabled)
            maxItems = Double(storage.maxItems)
        }
    }

    // MARK: - Pieces

    private var promptsSection: some View {
        section("Custom Prompts") {
            let prompts = storage.customPrompts()
            let _ = promptsRefresh   // dependency to refresh after add/delete
            if prompts.isEmpty {
                Text("Save your own AI actions (e.g. “Rewrite in my email style”). They appear in the ⌃⌘V action menu.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(prompts) { p in
                    HStack {
                        Image(systemName: "wand.and.stars.inverse")
                            .font(.system(size: 11)).foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.title).font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.textPrimary)
                            Text(p.instruction).font(.system(size: 10))
                                .foregroundStyle(Theme.textTertiary).lineLimit(1)
                        }
                        Spacer()
                        Button {
                            storage.deleteCustomPrompt(p); promptsRefresh += 1
                        } label: {
                            Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(.red)
                        }.buttonStyle(.plain)
                    }
                }
            }
            Button { showAddPrompt = true } label: {
                Label("Add prompt", systemImage: "plus.circle")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }.buttonStyle(.plain)
        }
    }

    private var aiSection: some View {
        section("AI Actions") {
            HStack(spacing: 8) {
                Image(systemName: ai.status.isAvailable ? "sparkles" : "sparkles.slash")
                    .foregroundStyle(ai.status.isAvailable ? Theme.accent : Theme.textSecondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(ai.status.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(ai.status.isAvailable ? "On-device · summarize, rewrite, translate, →JSON…"
                                               : "On-device AI transformations for your clips")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textTertiary)
                }
                Spacer()
            }

            Text(ai.status.explanation)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !ai.status.fixSteps.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(ai.status.fixSteps.enumerated()), id: \.offset) { i, step in
                        Text("\(i + 1). \(step)")
                            .font(.system(size: 10)).foregroundStyle(Theme.textTertiary)
                    }
                }
            }

            if ai.status.canFix {
                Button { ai.openFix() } label: {
                    Text(ai.status.fixActionLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 7)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }

            Divider().overlay(Theme.cardBorder)

            toggleRow("Show AI actions in the palette", systemImage: "wand.and.stars",
                      isOn: Binding(get: { ai.userEnabled }, set: { ai.userEnabled = $0 }))
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 20))
                .foregroundStyle(Theme.accent)
            Text("Settings")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
        }
    }

    private func section<C: View>(_ title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.textTertiary)
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(12)
                .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func toggleRow(_ label: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label(label, systemImage: systemImage)
                .foregroundStyle(Theme.textPrimary)
                .font(.system(size: 13))
        }
        .toggleStyle(.switch)
        .tint(Theme.accent)
    }

    private func shortcutRow(_ label: String, keys: [String]) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textPrimary)
            Spacer()
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { k in
                    Text(k)
                        .font(.system(size: 11, weight: .medium))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var aboutFooter: some View {
        HStack {
            Text("ClippyManager 1.0.0")
                .font(.system(size: 10))
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            Link("GitHub", destination: URL(string: "https://github.com/simonegiammy/ClippyManager")!)
                .font(.system(size: 10))
                .foregroundStyle(Theme.accent)
        }
    }

    // MARK: - Launch at login

    private func setLaunchAtLogin(_ enable: Bool) {
        do {
            if enable { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch {
            // Reverts the toggle if the system call fails (e.g. unsigned dev build).
            DispatchQueue.main.async {
                launchAtLogin = (SMAppService.mainApp.status == .enabled)
            }
        }
    }
}

extension Notification.Name {
    static let clippyHoverSettingChanged = Notification.Name("clippy.hoverSettingChanged")
}
