import Foundation

/// What the one-time unlock buys. Used to give the paywall contextual copy.
nonisolated enum PaidFeature: String, CaseIterable, Sendable, Identifiable {
    case largerBoards
    case lessons
    case practiceDrills
    case teachingHints
    case fullStats

    var id: String { rawValue }

    // Technique *prose* (what a technique is and how its argument goes)
    // belongs to Teaching/TechniqueContent.swift, never here.
    // Every string here is Shikaku's own. The siblings share this *type*, and
    // that is fine — what they must never share again is a sentence: the
    // 4.3(a) rejection was fed by four paywalls reading identically.
    var headline: String {
        switch self {
        case .largerBoards: "The big rooms"
        case .lessons: "Five more techniques"
        case .practiceDrills: "Timed drills"
        case .teachingHints: "The drawn argument"
        case .fullStats: "The mastery path"
        }
    }

    var pitch: String {
        switch self {
        case .largerBoards:
            "The 10 by 10 and 12 by 12 rooms, where the arguments run longer and the plan gets interesting."
        case .lessons:
            "Five more technique lessons: the whole path from the first easy deduction to the counting endgame."
        case .practiceDrills:
            "One technique at a time, on small rooms built so that technique is the move. Only unaided layings count."
        case .teachingHints:
            "The full hint ladder with the drawn argument. These hints show you why, instead of only telling you something is wrong."
        case .fullStats:
            "Best times, solve history, and a seal for every technique, cut only when you earn it."
        }
    }
}

/// What the hint button is allowed to do. Consumed by the Teaching layer's
/// HintEngine; defined here because which policy applies is a gating
/// decision, not a teaching one.
nonisolated enum HintPolicy: Sendable, Equatable {
    /// Free tier: "something here is wrong" — enough to feel what the hint
    /// engine would do for you. A withheld hint never calls `recordHint`.
    case errorsOnly
    /// The full ladder: nudge → technique → highlight → resolution.
    case full
}

/// Every gating decision in the app, as pure functions. Kept free of StoreKit
/// and of any actor isolation so the rules can be tested exhaustively without
/// a store connection — see `EntitlementTests`.
///
/// Every function takes `unlocked:` explicitly rather than reading a store.
/// That is what keeps them pure and `nonisolated`, and it is why the free tier
/// can be pinned by a test that never touches StoreKit.
nonisolated enum FeatureGate {

    /// Free: the rules tutorial (in full), plus the One Cell and Prime Strip
    /// lessons. Enough to learn the game and to feel what the hint engine
    /// would be doing for you.
    static let freeLessonCeiling: Technique = .primeStrip

    static func isLessonAvailable(_ technique: Technique, unlocked: Bool) -> Bool {
        unlocked || technique <= freeLessonCeiling
    }

    /// Free: 5×5 and 7×7, every difficulty tier.
    static func isBoardSizeAvailable(_ size: BoardSize, unlocked: Bool) -> Bool {
        unlocked || size == .five || size == .seven
    }

    /// Difficulty is never gated — a free player can play severe on 7×7.
    /// Gating difficulty punishes the players most likely to buy (Kakuro's
    /// rule).
    static func isDifficultyAvailable(_ difficulty: Difficulty, unlocked: Bool) -> Bool {
        true
    }

    static func areDrillsAvailable(unlocked: Bool) -> Bool {
        unlocked
    }

    /// The free tier keeps a real hint button — it just only catches errors.
    static func hintPolicy(unlocked: Bool) -> HintPolicy {
        unlocked ? .full : .errorsOnly
    }

    /// Best times per (size, difficulty) are free; everything else on the
    /// stats screen — history, trends, mastery detail — is behind this.
    static func isFullStatsAvailable(unlocked: Bool) -> Bool {
        unlocked
    }

    static func isAvailable(_ feature: PaidFeature, unlocked: Bool) -> Bool {
        unlocked
    }
}
