import SwiftUI

/// The board set into the room: a lacquered wood band around the lattice,
/// running out to the screen edges.
///
/// The frame is not trim. It is what makes the board an *object in a room*
/// rather than a grid on a page, and it is the first thing that separates
/// this app from a category of flat, translucent, edge-to-edge-white boards.
/// The app icon has always shown the room this way — seen from directly
/// above, one lit field inside lacquered dark. This is that view, on screen.
///
/// Deliberately opaque throughout: no material, no blur, no translucency.
struct RoomBoard: View {
    let game: ShikakuGame

    /// Wide enough to read as timber at App Store thumbnail size. Thinner
    /// than about 12 and it stops being a frame and starts being a border.
    private let band: CGFloat = 14

    var body: some View {
        // The band is part of the board's touch surface: a drag that starts
        // on the timber clamps into the border row or column (BoardGeometry
        // .clampedCell). Border cells are the category's sore spot — the top
        // competitor's one critical review is "8–10 attempts to select" them —
        // so the wood is deliberately forgiving, not dead.
        BoardView(game: game, touchOutset: band)
            // The lattice needs its own opaque ground: without it the timber
            // fill behind the whole padded stack shows through the board and
            // the room reads as one flat brown square.
            .background(Theme.floor)
            .padding(band)
            .background {
                Rectangle()
                    .fill(Theme.frame)
                    .overlay(alignment: .top) { lacquerSheen }
            }
            // The board sits *in* the timber: a dark line at the inner edge of
            // the band reads as depth without costing a shadow pass.
            .overlay {
                Rectangle()
                    .stroke(.black.opacity(0.45), lineWidth: 1)
                    .padding(band)
            }
            .accessibilityElement(children: .contain)
    }

    /// One highlight along the top edge of the band — light falling on a
    /// lacquered surface from the top of the room. A full gradient over the
    /// whole frame would read as plastic.
    private var lacquerSheen: some View {
        LinearGradient(colors: [.white.opacity(0.12), .clear],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: band)
            .allowsHitTesting(false)
    }
}
