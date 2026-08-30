import SwiftUI

/// The board set into the room: a raised dark band around the lattice,
/// running out to the screen edges.
///
/// The band is not trim. It makes the board an *object in a room* rather
/// than a grid on a page — and it doubles as the input's grace margin (see
/// `touchOutset` below). It is deliberately a dark neutral, not timber: the
/// wood look was tried and cut.
///
/// Deliberately opaque throughout: no material, no blur, no translucency.
struct RoomBoard: View {
    let game: ShikakuGame

    /// Wide enough to read as a frame at App Store thumbnail size, and to be
    /// a useful grace margin for edge drags. Thinner than about 12 and it
    /// stops being a frame and starts being a border.
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
            .background(Theme.frame)
            // The board sits *in* the timber: a dark line at the inner edge of
            // the band reads as depth without costing a shadow pass.
            .overlay {
                Rectangle()
                    .stroke(.black.opacity(0.45), lineWidth: 1)
                    .padding(band)
            }
            .accessibilityElement(children: .contain)
    }

}
