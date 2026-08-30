import SwiftUI

/// Size and difficulty, moved off the front page.
///
/// They used to be two chip rows occupying the top half of Home, which made
/// the first thing a new player saw a configuration form — for a game whose
/// one distinctive feature, the room, never appeared until they tapped Play.
/// Here they are a deliberate detour: Home restores what you played last, so
/// most sessions never open this at all.
///
/// Paywalled sizes stay tappable and present the paywall — never `.disabled`
/// (the family rule: a locked row that cannot be tapped cannot be bought).
struct NewRoomSheet: View {
    @Binding var size: BoardSize
    @Binding var difficulty: Difficulty
    let onStart: () -> Void

    @Environment(EntitlementStore.self) private var entitlements
    @Environment(\.dismiss) private var dismiss

    /// The paywall must be presented from THIS sheet, not through
    /// `PaywallPresenter`: the presenter's sheet hangs off ContentView, and
    /// SwiftUI silently refuses to present it while this sheet is already up
    /// — so a locked chip would do nothing at all.
    @State private var paywallFeature: PaidFeature?

    var body: some View {
        ZStack {
            Theme.floor.ignoresSafeArea()
            VStack(alignment: .leading, spacing: Layout.s5) {
                Text("A new room")
                    .font(Theme.heading)
                    .foregroundStyle(Theme.ink)
                    .padding(.top, Layout.s5)
                sizePicker
                difficultyPicker
                Spacer(minLength: 0)
                Button("Lay out a room") {
                    Haptics.matSettle()
                    dismiss()
                    onStart()
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(Layout.s5)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .sheet(item: $paywallFeature) { feature in
            PaywallView(feature: feature)
        }
    }

    private var sizePicker: some View {
        VStack(alignment: .leading, spacing: Layout.s2) {
            Text("Room size")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
            HStack(spacing: Layout.s2) {
                ForEach(BoardSize.allCases) { candidate in
                    sizeChip(candidate)
                }
            }
        }
    }

    @ViewBuilder
    private func sizeChip(_ candidate: BoardSize) -> some View {
        let available = FeatureGate.isBoardSizeAvailable(candidate, unlocked: entitlements.isUnlocked)
        let selected = size == candidate
        Button {
            if available {
                size = candidate
            } else {
                paywallFeature = .largerBoards
            }
        } label: {
            HStack(spacing: 3) {
                Text(candidate.label)
                    .font(Theme.numberFont(size: 15))
                if !available {
                    Image(systemName: "lock")
                        .font(.caption2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Layout.s2)
            .background(chipFill(selected))
            .foregroundStyle(selected ? Theme.floor : Theme.ink)
        }
        .accessibilityLabel("\(candidate.label)\(available ? "" : ", locked")")
    }

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: Layout.s2) {
            Text("Difficulty")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.inkSoft)
            // One control vocabulary for the whole app: square-cornered chips
            // cut from the same material as everything else, not a stock
            // segmented control (system grey chrome reads as someone else's
            // app on this floor). Difficulty is never gated: a free player can
            // play severe.
            HStack(spacing: Layout.s1) {
                ForEach(Difficulty.allCases) { tier in
                    difficultyChip(tier)
                }
            }
        }
    }

    @ViewBuilder
    private func difficultyChip(_ tier: Difficulty) -> some View {
        let selected = difficulty == tier
        Button {
            difficulty = tier
        } label: {
            Text(tier.label)
                .font(.footnote.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Layout.s2)
                .background(chipFill(selected))
                .foregroundStyle(selected ? Theme.floor : Theme.ink)
        }
        .accessibilityLabel("\(tier.label)\(selected ? ", selected" : "")")
    }

    /// Selected chips are cut bone; unselected ones are timber. Square, like
    /// every other object in the room.
    private func chipFill(_ selected: Bool) -> some View {
        Rectangle()
            .fill(selected ? AnyShapeStyle(Theme.ink) : AnyShapeStyle(Theme.frame))
    }
}
