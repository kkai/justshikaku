//
//  ModeContent.swift
//  Shikaku
//
//  THE ONLY FILE WHERE A WAY TO PLAY BECOMES ENGLISH, the same rule
//  TechniqueContent follows for the techniques. Home's card subtitles, the
//  "Ways to play" list in Learn, and the info sheet inside each mode all
//  read from here, so a card and its explanation can never drift apart.
//

import Foundation

nonisolated enum Mode: Int, CaseIterable, Identifiable, Sendable {
    case daily
    case freePlay
    case climb
    case spotIt
    case drill
    case techniqueRoom
    case proof

    var id: Int { rawValue }
}

nonisolated enum ModeGuide {

    static func title(_ mode: Mode) -> String {
        switch mode {
        case .daily: "Today's room"
        case .freePlay: "Lay out a room"
        case .climb: "The Climb"
        case .spotIt: "Spot it"
        case .drill: "Timed drills"
        case .techniqueRoom: "A room that needs it"
        case .proof: "Your last room"
        }
    }

    /// One line. Home's cards use exactly this, so the card and the guide
    /// always say the same thing.
    static func oneLine(_ mode: Mode) -> String {
        switch mode {
        case .daily: "One room a day, built around one technique."
        case .freePlay: "Pick a size and a difficulty, and play."
        case .climb: "Room after room, three strikes, no clock."
        case .spotIt: "Ten positions where one technique is the move."
        case .drill: "One technique's board, cold and timed."
        case .techniqueRoom: "A full board that needs the technique you picked."
        case .proof: "Your own solve, replayed and checked."
        }
    }

    /// Two to four plain sentences: what it is, how it ends, and what it
    /// costs you. Every mode says whether it is free.
    static func explanation(_ mode: Mode) -> String {
        switch mode {
        case .daily:
            """
            Every player gets the same room each day, and each day's room is built so that one \
            named technique appears in its solution. The week climbs the curriculum from Monday \
            to Sunday, and finishing all seven days earns the week its seal. Miss a day and you \
            can still play it later, because the boards are the same for everyone forever. \
            Today's room is free, always.
            """
        case .freePlay:
            """
            The ordinary game. Pick a room size and a difficulty, and lay mats until every \
            number sits in a rectangle of its own size. There is no clock pressure and nothing \
            is lost by taking a hint. 5x5 and 7x7 are free at every difficulty, including the \
            hardest.
            """
        case .climb:
            """
            Rooms come one after another, and each one is a step harder than the last. A mat \
            that cannot be part of the finished room is a strike, and three strikes end the \
            climb. There is no clock, so the only thing that ends a run is being wrong three \
            times. Your best climb is remembered, and nothing is ranked against anyone else. \
            Free.
            """
        case .spotIt:
            """
            Ten real positions from real boards, each one stopped at the moment your chosen \
            technique is the move. Lay the mat it points to and the next position arrives. Lay \
            the wrong one and it is a strike, and three strikes end the run. Every position is \
            checked by the solver first, so the technique really does apply.
            """
        case .drill:
            """
            One technique's board, opened cold with no lesson and no staged argument. The timer \
            runs so you can watch it fall as the technique sinks in, and it never ends the run. \
            Finishing records the drill against that technique.
            """
        case .techniqueRoom:
            """
            A full puzzle generated so that the technique you picked appears in its solution. \
            Other apps sell you grid sizes; this asks for a board by the reasoning it needs. \
            Every visit builds a new one, and the room plays like any other.
            """
        case .proof:
            """
            When you finish a room, the app replays your own solve and checks each mat against \
            its solver. A mat the solver can work out from the position you played it in counts \
            as worked out, and the technique behind it gets the credit. A mat a hint laid is \
            marked as shown. A mat that was right but further than the lessons reach is called \
            a leap. Step through the replay to see which was which.
            """
        }
    }

    /// The modes a player can open from the front page or the seal path,
    /// in the order Learn lists them.
    static let listed: [Mode] = [.daily, .freePlay, .climb, .spotIt,
                                 .drill, .techniqueRoom, .proof]
}
