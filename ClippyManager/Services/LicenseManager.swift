import Foundation
import CryptoKit
import Observation

/// Licensing layer: a 3-day free trial followed by a one-time lifetime unlock.
///
/// IMPORTANT: enforcement is **dormant** by default — `enforcementEnabled` is
/// `false`, so the app stays fully unlocked. Once the App Store IAP product is
/// configured in App Store Connect, flip `enforcementEnabled` to `true` (or set
/// the `CLIPPY_ENFORCE_LICENSE` env/launch arg) to turn the paywall on.
@Observable
final class LicenseManager {

    // MARK: - Configuration

    /// Master switch. Keep `false` until the IAP is live on the App Store.
    static let enforcementEnabled = false

    /// StoreKit product identifier for the lifetime unlock.
    /// Create this exact product in App Store Connect (Non-Consumable).
    static let lifetimeProductID = "com.giammy.clippymanager.lifetime"

    /// Fallback display price (StoreKit's localized price is used when available).
    static let displayPrice = "$29"

    let trialDays = 3

    /// SHA-256 hashes of valid promo codes (normalized: trimmed + uppercased).
    /// Add your own by appending `sha256(uppercased code)` here.
    private static let promoCodeHashes: Set<String> = [
        "946e0e2b0451afea7f418c40f58d48465ed7467a67062791ece8c2ea6dbdc37c", // CLIPPY-LIFETIME
        "8822090526528f3289a8b628717cba8363f1c0fa7218c5eaca6125cc7fc16a0a", // EARLYBIRD-2026
        "0e80156f7565cd7d3048f628bcbfeee05ac05259159704435fce55771f48d6d8", // FRIENDS-OF-CLIPPY
        "22b0493861832fff303c27eb48a8c1436174fb13675ced0361a01ae698154379", // WELCOME10
    ]

    // MARK: - Persisted state

    private enum Keys {
        static let firstLaunch = "license.firstLaunchDate"
        static let purchased   = "license.isPurchased"
        static let unlockVia   = "license.unlockMethod"
        static let usedCodes   = "license.usedCodeHashes"
    }

    private(set) var firstLaunchDate: Date
    private(set) var isPurchased: Bool
    private(set) var unlockMethod: String?

    init() {
        let defaults = UserDefaults.standard
        let isNew = (defaults.object(forKey: Keys.firstLaunch) as? Date) == nil
        let launch = (defaults.object(forKey: Keys.firstLaunch) as? Date) ?? Date()
        firstLaunchDate = launch
        isPurchased = defaults.bool(forKey: Keys.purchased)
        unlockMethod = defaults.string(forKey: Keys.unlockVia)
        if isNew {
            defaults.set(launch, forKey: Keys.firstLaunch)
        }
    }

    // MARK: - Derived state

    var enforcing: Bool {
        Self.enforcementEnabled ||
        CommandLine.arguments.contains("--enforce-license") ||
        ProcessInfo.processInfo.environment["CLIPPY_ENFORCE_LICENSE"] == "1"
    }

    var trialEndDate: Date {
        Calendar.current.date(byAdding: .day, value: trialDays, to: firstLaunchDate) ?? firstLaunchDate
    }

    var trialDaysRemaining: Int {
        let comps = Calendar.current.dateComponents([.day], from: Date(), to: trialEndDate)
        return max(0, (comps.day ?? 0) + ((Date() < trialEndDate) ? 1 : 0))
    }

    var isTrialActive: Bool { Date() < trialEndDate }

    /// True when the user can use the app (always true while enforcement is off).
    var isUnlocked: Bool {
        guard enforcing else { return true }
        return isPurchased || isTrialActive
    }

    var isLocked: Bool { !isUnlocked }

    var statusSummary: String {
        if isPurchased {
            return unlockMethod?.hasPrefix("promo") == true ? "Lifetime · Promo" : "Lifetime"
        }
        if isTrialActive {
            let d = trialDaysRemaining
            return "Trial · \(d) day\(d == 1 ? "" : "s") left"
        }
        return "Trial ended"
    }

    // MARK: - Unlocking

    func unlockWithPurchase() {
        isPurchased = true
        unlockMethod = "purchase"
        persist()
    }

    enum RedeemResult { case success, invalid, alreadyUsed }

    @discardableResult
    func redeem(code raw: String) -> RedeemResult {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty else { return .invalid }
        let hash = Self.sha256(normalized)

        guard Self.promoCodeHashes.contains(hash) else { return .invalid }

        var used = Set(UserDefaults.standard.stringArray(forKey: Keys.usedCodes) ?? [])
        if used.contains(hash) { return .alreadyUsed }
        used.insert(hash)
        UserDefaults.standard.set(Array(used), forKey: Keys.usedCodes)

        isPurchased = true
        unlockMethod = "promo"
        persist()
        return .success
    }

    // MARK: - Internal

    private func persist() {
        let d = UserDefaults.standard
        d.set(isPurchased, forKey: Keys.purchased)
        d.set(unlockMethod, forKey: Keys.unlockVia)
    }

    private static func sha256(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
