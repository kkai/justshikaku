//
//  Route.swift
//  Shikaku
//
//  One navigation vocabulary; ContentView owns the single destination
//  switch. `nonisolated` so value-type navigation state stays free of actor
//  concerns.
//

import Foundation

nonisolated enum Route: Hashable {
    case play(size: BoardSize, difficulty: Difficulty)
    case resume
    case learn
    /// Straight into one technique's lesson — the seal path's fast door.
    case lesson(Technique)
    /// Today's room.
    case daily(DayKey)
    /// A fresh room generated so one technique appears in its solve —
    /// the seal path's third door. The seed rolls at tap time.
    case techniqueRoom(Technique, seed: UInt64)
    /// One technique's timed drill, straight from its seal.
    case drill(Technique)
    /// The last solve, replayed and graded.
    case proof
    /// Ten mined positions where one technique is the move.
    case spotIt(Technique)
    /// Room after room up the ladder; three strikes.
    case climb
    case stats
    case settings
}
