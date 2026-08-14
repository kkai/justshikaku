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
    case stats
    case settings
}
