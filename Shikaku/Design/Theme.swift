import SwiftUI
#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// A light/dark colour value, held as plain components rather than a `UIColor`
/// or `NSColor`.
///
/// This is what lets the provider closure in `Theme.dynamic(light:dark:)` stay
/// `@Sendable` on both platforms: it captures only these, and whether a given
/// SDK declares its platform colour type `Sendable` stops mattering. See the
/// note on `Theme` for why that closure's annotations are load-bearing.
nonisolated struct ThemeRGBA: Sendable {
    let red, green, blue, alpha: CGFloat

    static let white = ThemeRGBA(red: 1, green: 1, blue: 1, alpha: 1)
}

// These extensions are `nonisolated` for the same load-bearing reason as
// `Theme` below: under default MainActor isolation an unannotated extension
// initializer is MainActor-isolated, and the @Sendable provider closure that
// calls it would inherit exactly the executor assertion this file exists to
// prevent.
#if canImport(UIKit)
private nonisolated extension UIColor {
    convenience init(_ c: ThemeRGBA) {
        self.init(red: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
    }
}
#else
private nonisolated extension NSColor {
    /// `srgbRed:` rather than `red:`, so the components land in the same colour
    /// space UIKit puts them in and the two platforms render identically.
    convenience init(_ c: ThemeRGBA) {
        self.init(srgbRed: c.red, green: c.green, blue: c.blue, alpha: c.alpha)
    }
}
#endif

/// Semantic color and type tokens. **The tatami room**: Shikaku (四角) puzzles
/// are literally tatami floor plans, so the board is a room being laid out —
/// a straw-paper floor, igusa-green mats with a dark woven edge, sumi-ink
/// numerals, and one persimmon accent reserved for errors and the win stamp.
/// Monospaced digits carry the carpenter's-drawing voice; where Kakuro is
/// serif newsprint and Hashi is a rounded woodblock sea, Shikaku is a plan
/// drawn in ink.
///
/// `nonisolated` is load-bearing, not tidiness. The project builds with
/// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, so without it `Theme` — and the
/// provider closure in `dynamic(light:dark:)` — is implicitly `@MainActor`.
/// UIKit imports `-initWithDynamicProvider:` without `NS_SWIFT_SENDABLE`, so the
/// closure inherits that isolation and Swift 6 emits an executor assertion in
/// its prologue. UIKit resolves dynamic colors from SwiftUI's
/// `com.apple.SwiftUI.AsyncRenderer` thread, which trips the assertion and traps
/// (EXC_BREAKPOINT). It fired intermittently in Just Kakuro — anywhere,
/// including an idle Home screen — because whether a given resolve lands
/// off-main is a race. Guarded by ThemeIsolationTests.
nonisolated enum Theme {

    // MARK: - Colors (light / dark pairs)

    /// The straw-paper floor behind the board; dark mode is warm lacquer.
    static let floor = dynamic(light: ThemeRGBA(red: 0.937, green: 0.914, blue: 0.855, alpha: 1),
                               dark: ThemeRGBA(red: 0.090, green: 0.078, blue: 0.059, alpha: 1))
    /// Cards and sheets.
    static let surface = dynamic(light: .white,
                                 dark: ThemeRGBA(red: 0.133, green: 0.118, blue: 0.090, alpha: 1))
    /// Sumi charcoal: clue numerals, primary text, the drag line.
    static let ink = dynamic(light: ThemeRGBA(red: 0.149, green: 0.137, blue: 0.110, alpha: 1),
                             dark: ThemeRGBA(red: 0.925, green: 0.910, blue: 0.863, alpha: 1))
    /// Secondary text, quiet labels. 0.78 alpha, not 0.55 — a sibling's
    /// contrast audit failed at 0.55 and the fix is worth inheriting.
    static let inkSoft = dynamic(light: ThemeRGBA(red: 0.149, green: 0.137, blue: 0.110, alpha: 0.78),
                                 dark: ThemeRGBA(red: 0.925, green: 0.910, blue: 0.863, alpha: 0.76))
    /// Igusa-green wash for committed mats — the only large colour on the
    /// board, and it is earned: an empty board is quiet straw.
    static let mat = dynamic(light: ThemeRGBA(red: 0.541, green: 0.608, blue: 0.431, alpha: 0.30),
                             dark: ThemeRGBA(red: 0.333, green: 0.408, blue: 0.290, alpha: 0.38))
    /// The mat's woven edge band (heri): committed rectangle borders, and the
    /// satisfied clue's ink.
    static let heri = dynamic(light: ThemeRGBA(red: 0.243, green: 0.290, blue: 0.208, alpha: 1),
                              dark: ThemeRGBA(red: 0.576, green: 0.647, blue: 0.514, alpha: 1))
    /// The sumitsubo snap-line: drag preview stroke and area badge.
    static let inkLine = dynamic(light: ThemeRGBA(red: 0.149, green: 0.137, blue: 0.110, alpha: 1),
                                 dark: ThemeRGBA(red: 0.925, green: 0.910, blue: 0.863, alpha: 1))
    /// Kaki persimmon: errors and the win stamp — never on screen together.
    static let kaki = dynamic(light: ThemeRGBA(red: 0.769, green: 0.341, blue: 0.180, alpha: 1),
                              dark: ThemeRGBA(red: 0.851, green: 0.482, blue: 0.322, alpha: 1))
    /// Soft kaki wash for conflict cells during a drag.
    static let kakiWash = dynamic(light: ThemeRGBA(red: 0.769, green: 0.341, blue: 0.180, alpha: 0.18),
                                  dark: ThemeRGBA(red: 0.851, green: 0.482, blue: 0.322, alpha: 0.24))
    /// Hairlines, lattice dots, separators.
    static let hairline = dynamic(light: ThemeRGBA(red: 0.149, green: 0.137, blue: 0.110, alpha: 0.13),
                                  dark: ThemeRGBA(red: 0.925, green: 0.910, blue: 0.863, alpha: 0.13))

    /// The closure is *also* explicitly `@Sendable`. That is redundant while
    /// `Theme` is `nonisolated` — a `@Sendable` closure never inherits actor
    /// isolation — and deliberately so: either annotation alone prevents the
    /// executor-assertion prologue, so losing one does not silently bring the
    /// trap back. `dynamicProvider:` is spelled out rather than the trailing
    /// closure `UIColor { … }` so the dangerous API stays greppable.
    ///
    /// It captures `ThemeRGBA` values rather than platform colour objects, which
    /// is the third layer of the same protection: components are plainly
    /// `Sendable`, so the annotation above cannot be invalidated by whatever the
    /// SDK does or does not declare about `UIColor` and `NSColor`.
    private static func dynamic(light: ThemeRGBA, dark: ThemeRGBA) -> Color {
        #if canImport(UIKit)
        Color(UIColor(dynamicProvider: { @Sendable trait in
            UIColor(trait.userInterfaceStyle == .dark ? dark : light)
        }))
        #else
        // AppKit resolves against an NSAppearance rather than a trait
        // collection, and `bestMatch` is the documented way to ask a possibly
        // vibrant or accessibility appearance which of the two it counts as.
        Color(NSColor(name: nil, dynamicProvider: { @Sendable appearance in
            NSColor(appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light)
        }))
        #endif
    }

    // MARK: - Type

    /// Clue numerals: the carpenter's plan digit. Monospaced so values never
    /// shift as they change; semibold so they survive small cells.
    static func clueFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    /// A satisfied clue relaxes: same face, lighter weight.
    static func satisfiedClueFont(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .monospaced)
    }

    /// Area badge on the drag preview ("6/8"), timers, counts.
    static func numberFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    /// Display face for titles — the quiet grotesque carries the wordmark;
    /// the board's monospaced digits are the personality.
    static let title = Font.system(.largeTitle, design: .default, weight: .bold)
    static let heading = Font.system(.title2, design: .default, weight: .semibold)
}
