//
//  Technique.swift
//  Shikaku
//
//  THE DECLARATION ORDER IS THE SOURCE OF TRUTH for five consumers: the
//  solver loop (lowest applicable technique first), difficulty weights, hint
//  escalation, the tutorial sequence, and the practice menu. Reorder here and
//  everywhere follows; never introduce a second ordering.
//

import Foundation

nonisolated enum Technique: Int, CaseIterable, Codable, Sendable, Comparable, Identifiable {
    /// A clue of value 1 is its own rectangle. The freebie tier.
    case oneCell
    /// A prime clue can only be a 1×n strip; exactly one strip fits.
    /// Machine-subsumed by `onlyFit`, kept as its own case so the simpler
    /// argument fires with its own lesson, prose, and mastery slot.
    case primeStrip
    /// A clue with exactly one live candidate.
    case onlyFit
    /// Cells contained in every live candidate of a clue belong to it;
    /// eliminate foreign candidates through them.
    case mustCover
    /// An uncovered cell reachable by exactly one clue must belong to it.
    case soleOwner
    /// One-ply: a candidate that would leave some cell with no reacher dies.
    case strandedCell
    /// One-ply counting: a candidate that leaves a region whose reachers'
    /// best fits sum below the region's area dies.
    case corridorCount

    var id: Int { rawValue }

    static func < (a: Technique, b: Technique) -> Bool { a.rawValue < b.rawValue }

    /// Difficulty weight per applied step. Distinct from curriculum position:
    /// mastery credits the hardest-weighted link in an elimination chain, and
    /// grading sums these over the trace. Calibrated via SHIKAKU_CALIBRATE=1.
    var weight: Int {
        switch self {
        case .oneCell: 1
        case .primeStrip: 2
        case .onlyFit: 3
        case .mustCover: 8
        case .soleOwner: 12
        case .strandedCell: 22
        case .corridorCount: 30
        }
    }

    /// Measured expectation, pinned both ways by the EngineCheck harness:
    /// techniques listed here are allowed to be absent from generated solver
    /// traces (their drills use hand-authored boards); techniques not listed
    /// must appear somewhere in the generation corpus. The sibling apps
    /// measured exactly this dynamic (parity: 0 appearances in 1,200 boards).
    /// Measured 2026-08-13: strandedCell fires in generated traces (15× in
    /// the 60-board corpus); corridorCount is the only unreachable tail.
    static let allowedAbsentFromGeneratedPuzzles: Set<Technique> = [.corridorCount]
}

/// A placement the solver proposes or applies.
nonisolated struct Placement: Hashable, Codable, Sendable {
    let clueIndex: Int
    let rect: GridRect
}

/// A candidate removed from a clue's list.
nonisolated struct Elimination: Hashable, Codable, Sendable {
    let clueIndex: Int
    let rect: GridRect
}

/// Structured facts for the teaching layer. The engine never holds a string —
/// TechniqueContent.swift is the only place this becomes English.
nonisolated struct ExplanationData: Codable, Sendable, Equatable {
    /// Clues the argument is about; first is the protagonist.
    var clueIndices: [Int] = []
    /// Ghost rectangles the overlay draws (surviving/considered placements).
    var candidateRects: [GridRect] = []
    /// Ghost rectangles the overlay strikes through.
    var eliminatedRects: [GridRect] = []
    /// Cells claimed for the protagonist clue (mustCover, soleOwner).
    var claimedCells: [Cell] = []
    /// The stranded cell (strandedCell) or spotlight cell (soleOwner).
    var focusCell: Cell? = nil
    /// Corridor region for corridorCount, outlined by RegionOutline.
    var region: [Cell]? = nil
    /// Counting figures: [regionArea, bestFitTotal] for corridorCount.
    var areaNumbers: [Int] = []
}

/// One applied step of the logical solver.
nonisolated struct SolverStep: Codable, Sendable, Equatable {
    let technique: Technique
    let placement: Placement?
    let eliminations: [Elimination]
    let explanation: ExplanationData
}
