//
//  HintButton.swift
//  Shikaku
//
//  The hint ladder's controls: the lamp asks, asks again to climb, and the
//  banner shows each rung. Free players get the errors-only policy — the
//  locked nudge stays tappable and opens the paywall (never .disabled).
//

import SwiftUI

struct HintButton: View {
    let game: ShikakuGame

    @Environment(EntitlementStore.self) private var entitlements
    @Environment(ProgressStore.self) private var progress
    @Environment(MasteryTracker.self) private var mastery
    @Environment(PaywallPresenter.self) private var paywall

    private let engine = HintEngine()

    var body: some View {
        Button {
            advance()
        } label: {
            Label("Hint", systemImage: game.activeHint == nil ? "lightbulb" : "lightbulb.fill")
                .labelStyle(.iconOnly)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(QuietButtonStyle())
        .accessibilityLabel(game.activeHint == nil ? "Hint" : "More of the hint")
    }

    private func advance() {
        let policy = FeatureGate.hintPolicy(unlocked: entitlements.isUnlocked)
        if let current = game.activeHint {
            if current.isLocked {
                paywall.present(.teachingHints)
                return
            }
            game.activeHint = engine.escalate(
                current, for: game, mastery: mastery, policy: policy)
        } else {
            game.activeHint = engine.hint(
                for: game, mastery: mastery,
                showErrors: progress.settings.errorFeedback || policy == .errorsOnly,
                policy: policy)
        }
    }
}

/// The rung under the board: hint text, and Apply at the top of the ladder.
struct HintBanner: View {
    let game: ShikakuGame

    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver

    private let engine = HintEngine()

    var body: some View {
        if let hint = game.activeHint {
            HStack(alignment: .firstTextBaseline, spacing: Layout.s3) {
                Text(hint.text)
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if hint.level == .resolution && (hint.step?.placement != nil
                    || hint.isError || !(hint.step?.eliminations.isEmpty ?? true)) {
                    Button("Apply") {
                        engine.apply(hint, to: game)
                        game.activeHint = nil
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.heri)
                }
                Button {
                    game.activeHint = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.inkSoft)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Dismiss hint")
            }
            .padding(.horizontal, Layout.s4)
            .padding(.vertical, Layout.s2)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Layout.cardRadius))
            .padding(.horizontal, Layout.s4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                AccessibilityNotification.Announcement(hint.text).post()
            }
        }
    }
}
