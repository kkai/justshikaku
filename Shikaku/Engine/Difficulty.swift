//
//  Difficulty.swift
//  Shikaku
//
//  Technique-based grading — the family's replacement for machine-effort
//  rating, which cannot express "this puzzle teaches soleOwner" and so
//  cannot drive a teaching game.
//

import Foundation

nonisolated enum Difficulty: Int, CaseIterable, Codable, Sendable, Comparable, Identifiable {
    case gentle, steady, sharp, deep, severe

    var id: Int { rawValue }

    static func < (a: Difficulty, b: Difficulty) -> Bool { a.rawValue < b.rawValue }

    /// The hardest technique the tier's puzzles may require. Also the solver
    /// ceiling during generation — nothing ships that needs more.
    var techniqueCeiling: Technique {
        switch self {
        case .gentle: .onlyFit
        case .steady: .mustCover
        case .sharp: .soleOwner
        case .deep: .strandedCell
        case .severe: .corridorCount
        }
    }
}

nonisolated enum DifficultyRater {

    /// Score = Σ technique weight over the trace, normalised per cell so one
    /// table serves all sizes.
    static func score(trace: [SolverStep], size: Int) -> Double {
        let raw = trace.reduce(0) { $0 + $1.technique.weight }
        return Double(raw) / Double(size * size)
    }

    /// Tier floor from the hardest technique in the trace.
    static func floor(trace: [SolverStep]) -> Difficulty {
        guard let hardest = trace.map(\.technique).max() else { return .gentle }
        switch hardest {
        case .oneCell, .primeStrip, .onlyFit: return .gentle
        case .mustCover: return .steady
        case .soleOwner: return .sharp
        case .strandedCell: return .deep
        case .corridorCount: return .severe
        }
    }

    /// Score thresholds that can lift a grade above its technique floor —
    /// deep/severe boards are usually dense soleOwner chains rather than
    /// showcases of the rare tail techniques (the measured sibling dynamic).
    /// Recalibrate with SHIKAKU_CALIBRATE=1 whenever generation, techniques,
    /// or weights change; the numbers are meaningless otherwise.
    static let thresholds: [(minScore: Double, tier: Difficulty)] = [
        (2.4, .severe),
        (1.9, .deep),
        (1.4, .sharp),
        (0.95, .steady),
    ]

    static func grade(trace: [SolverStep], size: Int) -> Difficulty {
        let base = floor(trace: trace)
        let s = score(trace: trace, size: size)
        for (minScore, tier) in thresholds where s >= minScore {
            return max(base, tier)
        }
        return base
    }
}
