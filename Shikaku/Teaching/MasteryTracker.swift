//
//  MasteryTracker.swift
//  Shikaku
//
//  What the player has earned unaided. Owns no storage — ProgressStore is
//  injected and holds the persisted MasteryState.
//

import Foundation

@Observable @MainActor
final class MasteryTracker {

    nonisolated enum Stage: Int, Comparable, Sendable {
        case unseen, seen, practicing, learned

        nonisolated static func < (a: Stage, b: Stage) -> Bool { a.rawValue < b.rawValue }
    }

    private let store: ProgressStore

    init(store: ProgressStore) {
        self.store = store
    }

    /// Unaided uses before a technique counts as learned.
    static let learnedThreshold = 5

    func stage(for technique: Technique) -> Stage {
        let record = store.mastery.perTechnique[technique.rawValue]
        guard let record else { return .unseen }
        if record.unaided >= Self.learnedThreshold { return .learned }
        if record.drilled > 0 || record.unaided > 0 { return .practicing }
        if record.seen > 0 { return .seen }
        return .unseen
    }

    /// A hint at any level marks the technique seen — the player has now met
    /// the idea, whichever rung they stopped on.
    func recordHint(technique: Technique, level: HintLevel) {
        store.updateMastery { state in
            state.perTechnique[technique.rawValue, default: TechniqueMastery()].seen += 1
        }
    }

    /// A finished lesson marks the technique met. It advances the seal to
    /// `.seen` — a lesson is an introduction, not practice, so it must not
    /// touch the drill count (it did once, which both inflated drill stats
    /// and made a finished lesson look like nothing on the path).
    func recordLesson(technique: Technique) {
        store.updateMastery { state in
            state.perTechnique[technique.rawValue, default: TechniqueMastery()].seen += 1
        }
    }

    func recordDrill(technique: Technique) {
        store.updateMastery { state in
            state.perTechnique[technique.rawValue, default: TechniqueMastery()].drilled += 1
        }
    }

    /// Credit an unaided placement with the HARDEST-weighted technique in
    /// the elimination chain behind it, not the placement's own label —
    /// onlyFit is taught early but trivial, and the elimination work that
    /// earned the placement is what deserves the credit.
    func recordUnaidedPlacement(chain: [Technique]) {
        guard let hardest = chain.max(by: { $0.weight < $1.weight }) else { return }
        store.updateMastery { state in
            state.perTechnique[hardest.rawValue, default: TechniqueMastery()].unaided += 1
        }
    }
}
