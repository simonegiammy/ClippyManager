import SwiftUI

/// Unlock screen: shows trial status, lifetime purchase, restore, and a promo
/// code field. Reachable from the menu; also shown as a lock overlay when the
/// trial has ended (only while license enforcement is enabled).
struct UpgradeView: View {
    @Environment(LicenseManager.self) private var license
    @Environment(StoreManager.self) private var store
    var onClose: (() -> Void)? = nil

    @State private var promo = ""
    @State private var message: (text: String, ok: Bool)? = nil
    @State private var busy = false

    var body: some View {
        VStack(spacing: 18) {
            header
            features
            Divider().overlay(Theme.cardBorder)
            purchaseBlock
            promoBlock
            if let message {
                Text(message.text)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(message.ok ? Color.green : Color.red)
                    .multilineTextAlignment(.center)
            }
            footer
        }
        .padding(.top, 30)
        .padding([.horizontal, .bottom], 24)
        .frame(width: 360)
        .background(GlassWindowFill())
        .environment(\.colorScheme, .dark)
        .task { await store.loadProduct() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.accent)
            Text("Clippy Lifetime")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            Text(license.statusSummary)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(license.isPurchased ? Color.green : Theme.textSecondary)
        }
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 8) {
            featureRow("Unlimited clipboard history")
            featureRow("Notch shelf, hover peek & library")
            featureRow("Custom categories & filters")
            featureRow("One-time payment · no subscription")
            featureRow("All future updates included")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Theme.accent)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private var purchaseBlock: some View {
        if license.isPurchased {
            Label("Unlocked — thank you!", systemImage: "checkmark.seal.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        } else {
            VStack(spacing: 8) {
                Button {
                    Task { busy = true; let ok = await store.purchase(); busy = false
                        message = ok ? ("Unlocked!", true)
                                     : (store.lastError ?? "Purchase unavailable", false) }
                } label: {
                    HStack {
                        Text("Unlock Lifetime")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(store.displayPrice)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                    .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(busy)

                Button("Restore Purchase") {
                    Task { busy = true; await store.restore(); busy = false
                        message = license.isPurchased ? ("Restored!", true)
                                                      : ("No purchase found", false) }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var promoBlock: some View {
        if !license.isPurchased {
            VStack(spacing: 8) {
                Text("Have a promo code?")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary)
                HStack(spacing: 8) {
                    TextField("PROMO-CODE", text: $promo)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
                        .onSubmit(redeem)
                    Button("Redeem", action: redeem)
                        .buttonStyle(.plain)
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Theme.pillInactive, in: RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(Theme.textPrimary)
                        .disabled(promo.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            if let onClose {
                Button(license.isPurchased ? "Done" : "Maybe later") { onClose() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text("Secure payment via App Store")
                .font(.system(size: 9))
                .foregroundStyle(Theme.textTertiary)
        }
    }

    private func redeem() {
        switch license.redeem(code: promo) {
        case .success:     message = ("Code accepted — unlocked!", true); promo = ""
        case .invalid:     message = ("Invalid code", false)
        case .alreadyUsed: message = ("Code already used", false)
        }
    }
}
