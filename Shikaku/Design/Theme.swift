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

/// Semantic color and type tokens. **The lacquered room**: Shikaku (四角)
/// puzzles are literally tatami floor plans, so the board is a room being laid
/// out — seen from directly above, the way the app icon sees it. A lacquered
/// dark floor, a raised dark band around the board, opaque igusa-green mats
/// with a woven edge band, bone numerals, and shu vermilion for teaching.
///
/// Three rules hold this together and are worth defending:
///
/// 1. **Green is dominant, not an accent.** The mats are the largest coloured
///    area on every screen. Near-black with a single vermilion accent is a
///    stock look; green doing the dominant work is not.
/// 2. **Vermilion means teaching**, never error. Eliminations and wrong mats
///    are *hatched* (`hatch`), because a carpenter rules something out by
///    drawing on it. This also retires the old constraint that the accent and
///    the win stamp could never share a screen.
/// 3. **Opaque, always.** No materials, no blur, no translucency anywhere —
///    the deliberate anti-Liquid-Glass stance, and the opposite of the nearest
///    competitor's stated design language.
///
/// The app ships dark only (see `ShikakuApp`); the light values below are kept
/// live so the appearance can return without touching the isolation-critical
/// structure of this file.
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

    /// The lacquered floor the whole app sits on. Warm, not neutral: this is
    /// wood under lacquer, not a grey.
    static let floor = dynamic(light: ThemeRGBA(red: 0.937, green: 0.914, blue: 0.855, alpha: 1),
                               dark: ThemeRGBA(red: 0.078, green: 0.063, blue: 0.047, alpha: 1))
    /// The raised band around the board and the fill of quiet controls — a
    /// step up from `floor`, deliberately NOT timber. It reads as a darker
    /// neutral, never as wood: Kai killed the brown on sight.
    static let frame = dynamic(light: ThemeRGBA(red: 0.851, green: 0.831, blue: 0.780, alpha: 1),
                               dark: ThemeRGBA(red: 0.157, green: 0.133, blue: 0.102, alpha: 1))
    /// Sheets and the few remaining raised panels. Being retired from the
    /// board and from inline panels — see Layout.
    static let surface = dynamic(light: .white,
                                 dark: ThemeRGBA(red: 0.118, green: 0.098, blue: 0.075, alpha: 1))
    /// Bone: clue numerals, primary text, the drag line.
    static let ink = dynamic(light: ThemeRGBA(red: 0.149, green: 0.137, blue: 0.110, alpha: 1),
                             dark: ThemeRGBA(red: 0.949, green: 0.918, blue: 0.855, alpha: 1))
    /// Secondary text, quiet labels. 0.78 alpha, not 0.55 — a sibling's
    /// contrast audit failed at 0.55 and the fix is worth inheriting.
    static let inkSoft = dynamic(light: ThemeRGBA(red: 0.149, green: 0.137, blue: 0.110, alpha: 0.78),
                                 dark: ThemeRGBA(red: 0.949, green: 0.918, blue: 0.855, alpha: 0.76))
    /// Igusa green for committed mats. **Opaque, and the dominant colour of
    /// the app** — the mats are the largest coloured area on every screen. If
    /// a build ever reads as "black with one red accent", this is too dark:
    /// raise it rather than adding a colour.
    static let mat = dynamic(light: ThemeRGBA(red: 0.541, green: 0.608, blue: 0.431, alpha: 1),
                             dark: ThemeRGBA(red: 0.243, green: 0.333, blue: 0.251, alpha: 1))
    /// The mat's woven edge band (heri): committed rectangle borders, and the
    /// satisfied clue's ink.
    static let heri = dynamic(light: ThemeRGBA(red: 0.243, green: 0.290, blue: 0.208, alpha: 1),
                              dark: ThemeRGBA(red: 0.576, green: 0.647, blue: 0.514, alpha: 1))
    /// The sumitsubo snap-line: drag preview stroke and area tag.
    static let inkLine = dynamic(light: ThemeRGBA(red: 0.149, green: 0.137, blue: 0.110, alpha: 1),
                                 dark: ThemeRGBA(red: 0.949, green: 0.918, blue: 0.855, alpha: 1))
    /// Shu vermilion — **the teaching accent, and nothing else**. Hint focus,
    /// the hanko seals, the commit flash, the win stamp. It deliberately no
    /// longer marks errors: red on this board means "the app is showing you
    /// something", which is the one thing no competitor's board can say.
    /// Never more than two elements at a time.
    static let shu = dynamic(light: ThemeRGBA(red: 0.769, green: 0.204, blue: 0.122, alpha: 1),
                             dark: ThemeRGBA(red: 0.820, green: 0.251, blue: 0.153, alpha: 1))
    /// Shu at wash strength, for the region a hint is arguing about.
    static let shuWash = dynamic(light: ThemeRGBA(red: 0.769, green: 0.204, blue: 0.122, alpha: 0.16),
                                 dark: ThemeRGBA(red: 0.820, green: 0.251, blue: 0.153, alpha: 0.22))
    /// Ruled-out ink: the hatching over an eliminated placement or a wrong
    /// mat. Elimination is drawn, not coloured — that is what makes room for
    /// `shu` to mean teaching.
    static let hatch = dynamic(light: ThemeRGBA(red: 0.149, green: 0.137, blue: 0.110, alpha: 0.42),
                               dark: ThemeRGBA(red: 0.949, green: 0.918, blue: 0.855, alpha: 0.46))
    /// Hairlines, lattice dots, separators.
    static let hairline = dynamic(light: ThemeRGBA(red: 0.149, green: 0.137, blue: 0.110, alpha: 0.13),
                                  dark: ThemeRGBA(red: 0.949, green: 0.918, blue: 0.855, alpha: 0.13))

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
