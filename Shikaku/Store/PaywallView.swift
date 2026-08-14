import SwiftUI

/// The one-time unlock. No subscription, no ads, no consumables — the pitch is
/// that this is the whole thing, once.
///
/// Presentation invariants (family-tested, see docs/MONETIZATION.md):
/// - Paywalled rows elsewhere stay **tappable** and call
///   `paywall.present(_:)` — no gated control is ever `.disabled()`. Only
///   mastery-locked rows disable.
/// - Restore must ALSO live in Settings, unconditionally — this sheet must
///   never be the only path to it. A player who reinstalled and hits no gate
///   still needs a way to get their purchase back.
struct PaywallView: View {
    let feature: PaidFeature

    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.s5) {
                header
                featureList
                purchaseControls
            }
            .padding(Layout.s5)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.floor)
        .presentationBackground(Theme.floor)
        .task {
            // A failure raised on another screen must not greet the player here.
            entitlements.clearTransientState()
            await entitlements.loadProduct()
        }
        .onChange(of: entitlements.isUnlocked) { _, unlocked in
            // This is what closes the sheet when an Ask to Buy is approved
            // later, with no purchase-completion callback anywhere.
            if unlocked { dismiss() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Layout.s2) {
            HStack(alignment: .top, spacing: Layout.s3) {
                Text(feature.headline)
                    .font(Theme.heading)
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
                // The only way out that does not involve buying something.
                SheetCloseButton()
            }
            Text(feature.pitch)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
        }
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: Layout.s3) {
            Text("The full game includes")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.inkSoft)
                .textCase(.uppercase)
            ForEach(PaidFeature.allCases) { item in
                HStack(alignment: .firstTextBaseline, spacing: Layout.s3) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.heri)
                    // Everything is listed regardless of which gate they hit;
                    // the one they hit is the one in ink.
                    Text(item.headline)
                        .font(.subheadline)
                        .foregroundStyle(item == feature ? Theme.ink : Theme.inkSoft)
                        .fontWeight(item == feature ? .semibold : .regular)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(Layout.s4)
        .background(RoundedRectangle(cornerRadius: Layout.cardRadius, style: .continuous)
            .fill(Theme.surface))
    }

    private var purchaseControls: some View {
        VStack(spacing: Layout.s3) {
            Button {
                Task { await entitlements.purchase() }
            } label: {
                if entitlements.purchaseState == .purchasing {
                    ProgressView().tint(Theme.surface)
                } else {
                    // Never hardcode the price — App Review rejects a button
                    // that disagrees with the product's real localized price.
                    Text(entitlements.product.map { "Unlock everything · \($0.displayPrice)" }
                         ?? "Unlock everything")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            // Both controls key off the same flag, so a purchase and a restore
            // can never be started on top of each other.
            .disabled(entitlements.purchaseState.isBusy)

            Text("One purchase. No subscription, no ads.")
                .font(.footnote)
                .foregroundStyle(Theme.inkSoft)

            Button {
                Task { await entitlements.restore() }
            } label: {
                HStack(spacing: Layout.s2) {
                    if entitlements.purchaseState == .restoring {
                        ProgressView().controlSize(.small)
                    }
                    Text(entitlements.purchaseState == .restoring
                         ? "Checking with the App Store…" : "Restore purchases")
                }
                .font(.footnote)
            }
            .buttonStyle(QuietButtonStyle())
            .disabled(entitlements.purchaseState.isBusy)

            statusLine
        }
    }

    /// One place for everything the store has to say, so a waiting state, a
    /// neutral note and a failure cannot each invent their own layout.
    @ViewBuilder
    private var statusLine: some View {
        switch entitlements.purchaseState {
        case .awaitingApproval:
            message("Sent for approval. The full game unlocks by itself once it is approved, "
                    + "and you can keep playing in the meantime.", color: Theme.ink)
        case .note(let text):
            message(text, color: Theme.inkSoft)
        case .failed(let text):
            message(text, color: Theme.kaki)
        default:
            EmptyView()
        }
    }

    private func message(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(color)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Small circular close affordance for the paywall sheet.
private struct SheetCloseButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)
                .padding(Layout.s2)
                .background(Circle().fill(Theme.surface))
        }
        .accessibilityLabel("Close")
    }
}

/// The pitch, card-shaped, for a screen that also carries free content.
///
/// Stats needs this: best times belong to the free tier, so locking the whole
/// screen would hide data the player owns.
struct LockedFeaturePanel: View {
    let feature: PaidFeature
    @Environment(PaywallPresenter.self) private var paywall

    var body: some View {
        VStack(spacing: Layout.s4) {
            Image(systemName: "lock")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.heri)
            Text(feature.headline)
                .font(Theme.heading)
                .foregroundStyle(Theme.ink)
            Text(feature.pitch)
                .font(.subheadline)
                .foregroundStyle(Theme.inkSoft)
                .multilineTextAlignment(.center)
            // Tappable, never .disabled — the tap IS the paywall entry point.
            Button("Unlock everything") {
                paywall.present(feature)
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, Layout.s1)
        }
        .padding(Layout.s5)
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: Layout.sheetRadius, style: .continuous)
            .fill(Theme.surface))
    }
}
