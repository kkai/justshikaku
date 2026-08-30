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
    case stats
    case settings
}
