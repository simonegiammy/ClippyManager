import Foundation
import AppKit
import Observation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// The actionable AI status — three verification layers mapped to real reasons.
enum AIStatus: Equatable {
    case available
    case needsOSUpdate        // system < macOS 26
    case deviceNotEligible    // hardware can't run Apple Intelligence
    case notEnabled           // Apple Intelligence toggle off
    case modelDownloading     // model assets not ready yet

    var isAvailable: Bool { self == .available }

    var title: String {
        switch self {
        case .available:        "On-device AI · Ready"
        case .needsOSUpdate:    "Update to macOS 26"
        case .deviceNotEligible:"Not supported on this Mac"
        case .notEnabled:       "Apple Intelligence is off"
        case .modelDownloading: "Model is downloading…"
        }
    }

    var explanation: String {
        switch self {
        case .available:
            "AI actions run entirely on your Mac — summarize, rewrite, translate, explain code, convert to JSON, and more. Nothing leaves your device."
        case .needsOSUpdate:
            "Clippy's on-device AI actions need macOS 26 (Tahoe) or later. Update your Mac to use them."
        case .deviceNotEligible:
            "This Mac doesn't support Apple Intelligence, so on-device AI actions aren't available here. Clippy still works as a full clipboard manager."
        case .notEnabled:
            "Turn on Apple Intelligence in System Settings to unlock on-device AI actions in Clippy."
        case .modelDownloading:
            "Apple Intelligence is finishing downloading its on-device model. This runs in the background — try again in a little while."
        }
    }

    /// Whether there's a user-actionable fix (vs. honest dead-end on old hardware).
    var canFix: Bool {
        switch self {
        case .needsOSUpdate, .notEnabled, .modelDownloading: true
        case .available, .deviceNotEligible: false
        }
    }

    var fixActionLabel: String {
        switch self {
        case .needsOSUpdate:    "Open Software Update…"
        case .notEnabled:       "Enable Apple Intelligence…"
        case .modelDownloading: "Check Again"
        default:                ""
        }
    }

    /// Step-by-step guidance shown alongside the fix button.
    var fixSteps: [String] {
        switch self {
        case .notEnabled:
            ["Open System Settings", "Go to Apple Intelligence & Siri", "Turn on Apple Intelligence"]
        case .needsOSUpdate:
            ["Open System Settings", "Go to General → Software Update", "Install the latest macOS"]
        default: []
        }
    }
}

/// Centralized, observable AI availability with the three-layer check.
@Observable
@MainActor
final class AIAvailability {
    private(set) var status: AIStatus = .needsOSUpdate

    /// Whether the user has switched AI actions off in Settings.
    var userEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "ai.showActions") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "ai.showActions"); refresh() }
    }

    /// True only when actions should actually run (status ok AND user opted in).
    var actionsActive: Bool { status.isAvailable && userEnabled }

    init() { refresh() }

    func refresh() {
        status = Self.detect()
    }

    private static func detect() -> AIStatus {
        // Layer 1 — OS
        guard #available(macOS 26, *) else { return .needsOSUpdate }

        // Layers 2 & 3 — hardware / enablement / model readiness
        #if canImport(FoundationModels)
        switch SystemLanguageModel.default.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            switch reason {
            case .deviceNotEligible:          return .deviceNotEligible
            case .appleIntelligenceNotEnabled: return .notEnabled
            case .modelNotReady:              return .modelDownloading
            @unknown default:                 return .notEnabled
            }
        @unknown default:
            return .notEnabled
        }
        #else
        return .deviceNotEligible
        #endif
    }

    /// Perform the actionable fix for the current status.
    func openFix() {
        switch status {
        case .notEnabled:
            openSystemSettings(panes: [
                "x-apple.systempreferences:com.apple.AppleIntelligence-Settings.extension",
                "x-apple.systempreferences:com.apple.Siri-Settings.extension"
            ])
        case .needsOSUpdate:
            openSystemSettings(panes: [
                "x-apple.systempreferences:com.apple.Software-Update-Settings.extension"
            ])
        case .modelDownloading:
            refresh()
        default:
            break
        }
    }

    private func openSystemSettings(panes: [String]) {
        for pane in panes {
            if let url = URL(string: pane), NSWorkspace.shared.open(url) { return }
        }
        // Fallback: just open System Settings.
        if let url = URL(string: "x-apple.systempreferences:") {
            NSWorkspace.shared.open(url)
        }
    }
}
