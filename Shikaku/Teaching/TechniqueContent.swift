//
//  TechniqueContent.swift
//  Shikaku
//
//  THE ONLY FILE WHERE ENGINE FACTS BECOME ENGLISH. The engine emits
//  structured ExplanationData; every player-facing sentence about the game
//  lives here, which is what makes the single humanizer pass possible and
//  keeps the engine free of UI and localization. Every context-dependent
//  branch degrades to rule(for:) rather than emitting a sentence with a
//  hole in it.
//

import Foundation

nonisolated enum TechniqueContent {

    static func name(for technique: Technique) -> String {
        switch technique {
        case .oneCell: "Ones"
        case .primeStrip: "Prime Strips"
        case .onlyFit: "Only Fit"
        case .mustCover: "Common Ground"
        case .soleOwner: "Lone Reacher"
        case .strandedCell: "No Orphans"
        case .corridorCount: "Count the Room"
        }
    }

    /// A few words for list rows — full sentences clip under large Dynamic
    /// Type (a sibling's accessibility audit caught exactly that).
    static func summary(for technique: Technique) -> String {
        switch technique {
        case .oneCell: "A 1 is its own mat"
        case .primeStrip: "Primes are strips"
        case .onlyFit: "One fit left"
        case .mustCover: "Every fit shares cells"
        case .soleOwner: "Only one clue reaches"
        case .strandedCell: "Don't strand a cell"
        case .corridorCount: "The areas don't add up"
        }
    }

    /// The technique's rule, one or two sentences. The fallback for every
    /// richer explanation.
    static func rule(for technique: Technique) -> String {
        switch technique {
        case .oneCell:
            "A clue of 1 is a room of one cell. Lay it down and move on."
        case .primeStrip:
            "A prime number can't make a wider rectangle, only a strip one cell wide. When just one strip fits, that's the mat."
        case .onlyFit:
            "Sometimes walls and neighbours leave a clue exactly one way to sit. If only one rectangle fits, it's the one."
        case .mustCover:
            "Try every rectangle that could hold a clue. If all of them pass through the same cells, those cells belong to that clue, even before you know which rectangle it is."
        case .soleOwner:
            "Every cell must end up inside some mat. If only one clue can reach a cell, that cell is spoken for, and the clue's mat has to cover it."
        case .strandedCell:
            "A mat can't leave a cell behind. If laying a rectangle would cut some cell off from every clue, that rectangle was never right."
        case .corridorCount:
            "Count a walled-off region, then count the most each nearby clue could give it. If the numbers come up short, the placement that made the region is wrong."
        }
    }

    // MARK: - Hint ladder copy (levels below the technique's rule)

    /// Level 1: names the family of the move without naming the move.
    static func nudge(for technique: Technique) -> String {
        switch technique {
        case .oneCell:
            "There's a mat here that lays itself."
        case .primeStrip:
            "One of these numbers can only stretch one way."
        case .onlyFit:
            "Somewhere on the board, a clue has run out of options."
        case .mustCover:
            "Two placements can disagree and still overlap. Look for cells every option shares."
        case .soleOwner:
            "There's a cell only one clue can reach."
        case .strandedCell:
            "One of the tempting placements would leave a cell orphaned."
        case .corridorCount:
            "Count a cornered region against what can actually fill it."
        }
    }

    /// Error hint: the board holds a wrong mat. Free tier sees only these.
    static let errorNudge = "One of your mats isn't right. It fits the rules where it sits, but it can't be part of the finished room."
    static let errorResolution = "This mat is the one to lift. The rest of your work stands."
    static let noErrorAllClear = "Nothing's wrong so far. Every mat you've laid can stay."

    /// The teaching ladder behind the unlock. Shown instead of a nudge to
    /// free players when the board holds no errors.
    static let withheld = "Your mats are all sound. The step-by-step teaching hints come with the full game."

    /// Level 3: the argument in words, alongside the drawn overlay. Every
    /// branch degrades to rule(for:) — never a sentence with a hole.
    static func detail(for step: SolverStep, puzzle: Puzzle) -> String {
        guard let protagonist = step.explanation.clueIndices.first else {
            return rule(for: step.technique)
        }
        let value = puzzle.clues[protagonist].value
        switch step.technique {
        case .oneCell:
            return "The highlighted 1 fills its own cell."
        case .primeStrip:
            return "\(value) is prime, so the \(value) can only be a strip, and the walls leave just one place for it."
        case .onlyFit:
            let ruledOut = step.explanation.eliminatedRects.count
            return ruledOut > 0
                ? "Of every rectangle that could hold the \(value), \(ruledOut) collide with walls, clues, or your mats. One remains."
                : "Only one rectangle can hold the \(value) here."
        case .mustCover:
            let cells = step.explanation.claimedCells.count
            return "Every rectangle that could hold the \(value) passes through the \(cells) marked cell\(cells == 1 ? "" : "s"). They're the \(value)'s, whichever way it ends up lying."
        case .soleOwner:
            return "No other clue can stretch to the marked cell. Only the \(value) can, so its mat must cover it."
        case .strandedCell:
            return "If the \(value) took the struck rectangle, the marked cell would be walled off with no clue left to house it."
        case .corridorCount:
            let numbers = step.explanation.areaNumbers
            if numbers.count == 2 {
                return "That placement seals off a region of \(numbers[0]) cells, but the clues that can reach it cover at most \(numbers[1]). The numbers don't meet."
            }
            return rule(for: step.technique)
        }
    }

    // MARK: - Resolution phrasing

    static func resolution(for technique: Technique, clueValue: Int) -> String {
        switch technique {
        case .oneCell:
            "The 1 is its own mat."
        case .primeStrip:
            "The \(clueValue) is prime, so it's a strip, and only this one fits."
        case .onlyFit:
            "Only this rectangle can hold the \(clueValue)."
        case .mustCover:
            "Every possible mat for the \(clueValue) covers the marked cells, so they're claimed. That rules out the struck placements."
        case .soleOwner:
            "Only the \(clueValue) can reach the marked cell, so its mat must cover it. The struck placements can't."
        case .strandedCell:
            "That placement of the \(clueValue) would strand the marked cell with no clue to house it."
        case .corridorCount:
            "That placement walls off a region the remaining clues can't fill."
        }
    }
}
