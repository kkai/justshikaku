//
//  GameplayAndStoreTests.swift
//  ShikakuTests
//
//  The gesture state machine as pure calls on ShikakuGame, the persistence
//  invariants the family regressed on, and the free set asserted exactly.
//

import Foundation
import Testing
@testable import Shikaku

@Suite @MainActor struct GestureModelTests {

    /// A 3×3 with a 1, a 2 and a 6 — small enough to reason about every move.
    private func makeGame() -> ShikakuGame {
        ShikakuGame(puzzle: TutorialPuzzles.rules.puzzle, size: .five, difficulty: .gentle)
    }

    @Test func dragCommitsARectWithExactlyOneClue() {
        let game = makeGame()
        game.dragChanged(anchor: Cell(row: 0, col: 1), current: Cell(row: 0, col: 2))
        #expect(game.preview?.clueCount == 1)
        game.dragEnded()
        #expect(game.board.placed.count == 1)
        #expect(game.board.placed[0].rect == GridRect(minRow: 0, minCol: 1, maxRow: 0, maxCol: 2))
    }

    @Test func dragAcrossTwoCluesRejects() {
        let game = makeGame()
        game.dragChanged(anchor: Cell(row: 0, col: 0), current: Cell(row: 0, col: 2))
        game.dragEnded()
        #expect(game.board.placed.isEmpty)
        #expect(game.rejectedPreview != nil)
    }

    @Test func wrongAreaCommitsAndShowsConflict() {
        let game = makeGame()
        // 2 cells swept over the 6's clue: commits, flagged as a conflict.
        game.dragChanged(anchor: Cell(row: 2, col: 0), current: Cell(row: 2, col: 1))
        game.dragEnded()
        #expect(game.board.placed.count == 1)
        if let placed = game.board.placed.first {
            #expect(game.areaConflict(placed))
        }
    }

    @Test func tapDeletesACommittedMat() {
        let game = makeGame()
        game.dragChanged(anchor: Cell(row: 0, col: 1), current: Cell(row: 0, col: 2))
        game.dragEnded()
        #expect(game.board.placed.count == 1)
        // Tap = anchor and current in the same cell.
        game.dragChanged(anchor: Cell(row: 0, col: 2), current: Cell(row: 0, col: 2))
        game.dragEnded()
        #expect(game.board.placed.isEmpty)
    }

    @Test func tapOnClueWithSingleFitAutoPlaces() {
        let game = makeGame()
        game.dragChanged(anchor: Cell(row: 0, col: 0), current: Cell(row: 0, col: 0))
        game.dragEnded()
        #expect(game.board.placed.first?.rect == GridRect(minRow: 0, minCol: 0, maxRow: 0, maxCol: 0))
    }

    @Test func redrawOverReplacesTheMatsBeneath() {
        let game = makeGame()
        // The 2 laid vertically, into the 6's territory.
        game.dragChanged(anchor: Cell(row: 0, col: 2), current: Cell(row: 1, col: 2))
        game.dragEnded()
        #expect(game.board.placed.count == 1)
        // The 6 drawn over its true home displaces the overlapping 2.
        game.dragChanged(anchor: Cell(row: 1, col: 0), current: Cell(row: 2, col: 2))
        game.dragEnded()
        #expect(game.board.placed.count == 1)
        #expect(game.board.placed.first?.clueIndex == 2)
    }

    @Test func undoRestoresDisplacedMats() {
        let game = makeGame()
        game.dragChanged(anchor: Cell(row: 0, col: 2), current: Cell(row: 1, col: 2))
        game.dragEnded()
        game.dragChanged(anchor: Cell(row: 1, col: 0), current: Cell(row: 2, col: 2))
        game.dragEnded()
        game.undo()
        #expect(game.board.placed.count == 1)
        #expect(game.board.placed.first?.clueIndex == 1)
    }

    @Test func solvingTheBoardWins() {
        let game = makeGame()
        for (i, rect) in game.puzzle.solution.enumerated() {
            game.dragChanged(anchor: Cell(row: rect.minRow, col: rect.minCol),
                             current: Cell(row: rect.maxRow, col: rect.maxCol))
            game.dragEnded()
            _ = i
        }
        #expect(game.isSolved)
        #expect(game.didWin)
    }

    @Test func masteryCreditIsNotFarmableThroughUndo() {
        let game = makeGame()
        #expect(game.claimMasteryCredit(forClue: 1))
        game.undo()
        // Credited state survives undo deliberately.
        #expect(!game.claimMasteryCredit(forClue: 1))
    }
}

@Suite @MainActor struct PersistenceTests {

    private func makeStore() -> ProgressStore {
        let defaults = UserDefaults(suiteName: "shikaku-tests-\(UUID().uuidString)")!
        return ProgressStore(userDefaults: defaults)
    }

    @Test func savedGameRoundTrips() {
        let store = makeStore()
        let lesson = TutorialPuzzles.lesson(for: .onlyFit)
        let snapshot = GameSnapshot(
            puzzle: lesson.puzzle, board: lesson.startingBoard,
            elapsedSeconds: 42, sizeRaw: BoardSize.five.rawValue,
            difficultyRaw: Difficulty.sharp.rawValue, hintsUsed: 1)
        store.save(snapshot)
        #expect(store.savedGame?.elapsedSeconds == 42)
        store.clearSavedGame()
        #expect(store.savedGame == nil)
    }

    @Test func recordSolveReportsRecordsAndTiesCorrectly() {
        let store = makeStore()
        #expect(store.recordSolve(size: .five, difficulty: .gentle, seconds: 100, hintsUsed: 0))
        #expect(store.recordSolve(size: .five, difficulty: .gentle, seconds: 90, hintsUsed: 0))
        // An exact tie is NOT a record.
        #expect(!store.recordSolve(size: .five, difficulty: .gentle, seconds: 90, hintsUsed: 0))
        #expect(!store.recordSolve(size: .five, difficulty: .gentle, seconds: 200, hintsUsed: 0))
        #expect(store.bestTime(size: .five, difficulty: .gentle) == 90)
    }

    @Test func masteryPersistsThroughTheStore() {
        let store = makeStore()
        store.updateMastery { $0.perTechnique[Technique.soleOwner.rawValue, default: TechniqueMastery()].unaided += 1 }
        #expect(store.mastery.perTechnique[Technique.soleOwner.rawValue]?.unaided == 1)
    }
}

@Suite struct EntitlementTests {

    /// The free set, asserted exactly — a drifting gate is a silent product
    /// change.
    @Test func freeTierIsExactlyAsDesigned() {
        #expect(FeatureGate.isBoardSizeAvailable(.five, unlocked: false))
        #expect(FeatureGate.isBoardSizeAvailable(.seven, unlocked: false))
        #expect(!FeatureGate.isBoardSizeAvailable(.ten, unlocked: false))
        #expect(!FeatureGate.isBoardSizeAvailable(.twelve, unlocked: false))

        for difficulty in Difficulty.allCases {
            #expect(FeatureGate.isDifficultyAvailable(difficulty, unlocked: false),
                    "difficulty is never gated")
        }

        #expect(FeatureGate.isLessonAvailable(.oneCell, unlocked: false))
        #expect(FeatureGate.isLessonAvailable(.primeStrip, unlocked: false))
        #expect(!FeatureGate.isLessonAvailable(.onlyFit, unlocked: false))
        #expect(!FeatureGate.isLessonAvailable(.corridorCount, unlocked: false))

        #expect(FeatureGate.hintPolicy(unlocked: false) == .errorsOnly)
        #expect(!FeatureGate.areDrillsAvailable(unlocked: false))
        #expect(!FeatureGate.isFullStatsAvailable(unlocked: false))
    }

    @Test func unlockOpensEverything() {
        for size in BoardSize.allCases {
            #expect(FeatureGate.isBoardSizeAvailable(size, unlocked: true))
        }
        for technique in Technique.allCases {
            #expect(FeatureGate.isLessonAvailable(technique, unlocked: true))
        }
        #expect(FeatureGate.hintPolicy(unlocked: true) == .full)
        #expect(FeatureGate.areDrillsAvailable(unlocked: true))
        #expect(FeatureGate.isFullStatsAvailable(unlocked: true))
    }

    /// Every PaidFeature must be presentable from somewhere — a feature
    /// advertised on the paywall but sold from nowhere shipped once in a
    /// sibling. Source scan over the app tree.
    @Test func everyPaidFeatureHasAPresentingCallSite() throws {
        let testsDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let sourceRoot = testsDir.deletingLastPathComponent().appendingPathComponent("Shikaku")
        let files = try FileManager.default
            .subpathsOfDirectory(atPath: sourceRoot.path)
            .filter { $0.hasSuffix(".swift") }
        var corpus = ""
        for file in files {
            corpus += (try? String(contentsOf: sourceRoot.appendingPathComponent(file),
                                   encoding: .utf8)) ?? ""
        }
        for feature in PaidFeature.allCases {
            #expect(corpus.contains("paywall.present(.\(feature))")
                    || corpus.contains("present(.\(feature))"),
                    "\(feature) has no paywall.present call site")
        }
    }
}
