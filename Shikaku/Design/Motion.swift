import SwiftUI

/// Named animation tokens. Views never write inline animation values — every
/// animated moment in the app has a name here, which is what keeps motion
/// coherent and Reduce Motion honest.
///
/// `nonisolated` for the same load-bearing reason as `Theme` — see the note
/// there and ThemeIsolationTests.
nonisolated enum Motion {

    /// A committed mat settling into the floor: quick, slightly overdamped.
    static let settle = Animation.spring(response: 0.28, dampingFraction: 0.78)

    /// The sumitsubo preview line tracking the finger.
    static let snapLine = Animation.interactiveSpring(response: 0.15, dampingFraction: 0.86)

    /// A rejected drag shaking off.
    static let matReject = Animation.spring(response: 0.18, dampingFraction: 0.45)

    /// Witnesses in a drawn argument appear in sequence, this far apart.
    static let argumentStagger: Double = 0.12

    /// One element of a drawn argument fading or striking.
    static let argumentBeat = Animation.easeOut(duration: 0.22)

    /// The win sweep crossing the room.
    static let winSweep = Animation.easeInOut(duration: 0.9)

    /// Chrome transitions (sheets, banner slides).
    static let chrome = Animation.easeInOut(duration: 0.22)
}
