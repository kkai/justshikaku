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

    private var begun: Int {
        Technique.allCases.filter { mastery.stage(for: $0) > .unseen }.count
    }

    /// The counter must move the first time anything happens — "0 of 7
    /// learned" after finishing a lesson read as a bug, because .learned is
    /// deliberately five unaided uses away.
    private var counter: String {
        if learned > 0 { return "\(learned) of \(Technique.allCases.count) learned" }
        if begun > 0 { return "\(begun) of \(Technique.allCases.count) begun" }
        return "\(Technique.allCases.count) techniques"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.s2) {
            HStack {
                Text("Your path")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.inkSoft)
                Spacer()
                Text(counter)
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
        .modifier(PathAccessibility(inert: onTap == nil, learned: learned))
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
            .overlay(Rectangle().strokeBorder(border, lineWidth: borderWidth))
            .overlay { if stage == .learned { glyph } else if station > 0 { stationNumber } }
            .frame(width: side, height: side)
    }

    private var stationNumber: some View {
        Text("\(station)")
            .font(Theme.numberFont(size: side * 0.38))
            .foregroundStyle(stage == .unseen ? Theme.inkSoft.opacity(0.5) : Theme.ink)
            .fontWeight(stage == .unseen ? .regular : .bold)
    }

    /// A cut seal carries a mark; an uncut stone is blank. The mark is the
    /// game's own partition again, at seal scale.
    private var glyph: some View {
        Rectangle()
            .fill(Theme.floor)
            .frame(width: side * 0.34, height: side * 0.52)
            .offset(x: -side * 0.16)
    }

    /// Every stage must be tellable at arm's length on the dark floor — mat
    /// green on raised dark was nearly invisible at 34pt, which made a
    /// freshly finished lesson look like nothing happened.
    ///
    /// unseen: dark stone, faint number · seen: SCORED — heri border, bright
    /// number · practicing: cut — mat fill, heri border · learned: inked shu.
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
        case .seen: Theme.heri
        case .practicing: Theme.heri
        case .learned: Theme.shu
        }
    }

    private var borderWidth: CGFloat {
        switch stage {
        case .unseen: 1
        case .seen: 2
        case .practicing: 1.5
        case .learned: 1.5
        }
    }
}


/// Combined into one element only when the row is inert (Stats). As a
/// launcher it must stay a container — a combining element swallowed the
/// seal buttons for VoiceOver and every UI driver.
private struct PathAccessibility: ViewModifier {
    let inert: Bool
    let learned: Int

    func body(content: Content) -> some View {
        if inert {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "Your path, \(learned) of \(Technique.allCases.count) techniques learned")
        } else {
            content
        }
    }
}
