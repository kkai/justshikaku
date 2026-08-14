import Foundation
import Observation

/// Owns paywall presentation for the whole app. One sheet at the root beats
/// five copies scattered through the view tree, and gives one place to hang a
/// purchase celebration later. A service, like `PuzzleCache` — not a ViewModel.
///
/// The elders of the family wrap the feature in a `PaywallContext` struct so a
/// source screen or a promo code can be added without touching call sites.
/// Shikaku v1 presents the `PaidFeature` directly — it is `Identifiable`, so
/// it drives `.sheet(item:)` as-is — and grows the struct back the day a
/// second field actually exists.
@Observable @MainActor
final class PaywallPresenter {
    private(set) var presented: PaidFeature?

    func present(_ feature: PaidFeature) {
        presented = feature
    }

    func dismiss() {
        presented = nil
    }
}
