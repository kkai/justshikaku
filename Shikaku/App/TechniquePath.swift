import SwiftUI

/// The curriculum, as a row of carved seals.
///
/// This is the pitch, so it goes where the pitch goes — on the front page,
/// above the fold. No other app in the category names its solving techniques
/// at all, let alone tracks which ones you can use unaided.
///
/// Stages read as a stone being cut and finally inked:
/// blank → scored → cut → inked in vermilion. The accumulating red is the
/// one place in the app where `Theme.shu` is allowed to repeat, and it earns
/// it: an unplayed app shows none at all.
struct TechniquePath: View {
    let mastery: MasteryTracker
    var seal: CGFloat = 34
    /// Invoked with the tapped technique; nil renders the row inert (Stats).
    var onTap: ((Technique) -> Void)? = nil

    private var learned: Int {
        Technique.allCases.filter { mastery.stage(for: $0) == .learned }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.s2) {
            HStack {
                Text("Your path")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                Text("\(learned) of \(Technique.allCases.count) learned")
                    .font(Theme.numberFont(size: 13))
                    .foregroundStyle(Theme.inkSoft)
            }
            HStack(spacing: Layout.s2) {
                ForEach(Technique.allCases) { technique in
                    let seal = HankoSeal(stage: mastery.stage(for: technique),
                                         station: technique.rawValue + 1, side: seal)
                    if let onTap {
                        Button { onTap(technique) } label: { seal }
                            .buttonStyle(.plain)
                            .accessibilityLabel(
                                "\(TechniqueContent.name(for: technique)) lesson")
                    } else {
                        seal
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: onTap == nil ? .ignore : .contain)
        .accessibilityLabel("Your path, \(learned) of \(Technique.allCases.count) techniques learned")
    }
}

/// One technique's seal.
nonisolated struct HankoSeal: View {
    let stage: MasteryTracker.Stage
    /// The technique's position on the path, 1-based. Engraved faintly on an
    /// uncut stone so the row reads as seven stations, not seven placeholders.
    var station: Int = 0
    var side: CGFloat = 34

    var body: some View {
        Rectangle()
            .fill(fill)
            .overlay(Rectangle().strokeBorder(border, lineWidth: stage == .unseen ? 1 : 1.5))
            .overlay { if stage == .learned { glyph } else if station > 0 { stationNumber } }
            .frame(width: side, height: side)
    }

    private var stationNumber: some View {
        Text("\(station)")
            .font(Theme.numberFont(size: side * 0.38))
            .foregroundStyle(stage == .unseen ? Theme.inkSoft.opacity(0.5) : Theme.ink)
    }

    /// A cut seal carries a mark; an uncut stone is blank. The mark is the
    /// game's own partition again, at seal scale.
    private var glyph: some View {
        Rectangle()
            .fill(Theme.floor)
            .frame(width: side * 0.34, height: side * 0.52)
            .offset(x: -side * 0.16)
    }

    /// An uncut stone is still a stone: `.clear` on a hairline border made
    /// the whole path invisible on a first run, which read as a rendering
    /// fault rather than as seven things left to earn.
    private var fill: Color {
        switch stage {
        case .unseen: Theme.frame
        case .seen: Theme.frame
        case .practicing: Theme.mat
        case .learned: Theme.shu
        }
    }

    private var border: Color {
        switch stage {
        case .unseen: Theme.hairline
        case .seen: Theme.inkSoft
        case .practicing: Theme.heri
        case .learned: Theme.shu
        }
    }
}
