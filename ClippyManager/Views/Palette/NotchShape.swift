import SwiftUI

/// The signature Aurora Glass shape: the notch pill at the top from which the
/// panel **emerges through a narrow neck**, widening via a smooth ogee skirt into
/// the full body below the menu bar. Keeping the glass at the notch width where it
/// meets the notch (instead of spanning full width at the menu-bar line) removes
/// the two "towers" that used to flank the notch.
///
/// `progress` 0 → just the pill (closed); 1 → full panel (open). It's the
/// `animatableData`, so animating it produces the "genie" grow/suck effect.
struct NotchShape: Shape {
    /// 0 = closed (pill only), 1 = fully open.
    var progress: CGFloat
    /// Pill width at the top (matches the physical notch).
    var pillWidth: CGFloat = 200
    /// Height of the menu-bar band the pill lives in.
    var menuBand: CGFloat = 34
    /// Corner radius of the expanded panel body.
    var bodyRadius: CGFloat = 26
    /// Pill top corner radius.
    var pillTop: CGFloat = 11
    /// How far below the menu band the glass takes to widen from the notch width
    /// to the full body width (the length of the emerging "neck"). Must match
    /// ShelfView's `neck` so content clears the funnel.
    var neckDepth: CGFloat = 70

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let W = rect.width
        let prog = max(0, min(1, progress))
        let mb = menuBand
        let nt = pillTop
        let cx = W / 2
        let nl = cx - pillWidth / 2
        let nr = cx + pillWidth / 2

        // Body grows in BOTH width and height with progress so it physically
        // emerges from the notch rather than sliding in.
        let fullBodyH = max(0, rect.height - mb)
        let bodyH = fullBodyH * prog
        let H = mb + bodyH
        // Side edges interpolate from the notch edges (closed) to the frame
        // edges (open).
        let leftEdge  = nl * (1 - prog)
        let rightEdge = W - (W - nr) * (1 - prog)
        // The neck never exceeds the available body height (so the skirt always
        // ends above the bottom corners).
        let neck = min(neckDepth, bodyH * 0.85)
        let br = min(bodyRadius, max(0, (bodyH - neck) / 2), (rightEdge - leftEdge) / 2)

        var p = Path()
        // Pill top (sits in the menu bar, matching the physical notch).
        p.move(to: CGPoint(x: nl, y: nt))
        p.addQuadCurve(to: CGPoint(x: nl + nt, y: 0), control: CGPoint(x: nl, y: 0))
        p.addLine(to: CGPoint(x: nr - nt, y: 0))
        p.addQuadCurve(to: CGPoint(x: nr, y: nt), control: CGPoint(x: nr, y: 0))
        // Straight down the pill's right edge to the menu band.
        p.addLine(to: CGPoint(x: nr, y: mb))
        // Ogee skirt: leave the notch going straight down, flare out, arrive at
        // the body's right edge going straight down (vertical tangents both ends
        // → no flat shoulder).
        p.addCurve(to: CGPoint(x: rightEdge, y: mb + neck),
                   control1: CGPoint(x: nr, y: mb + neck),
                   control2: CGPoint(x: rightEdge, y: mb))
        // Right side down + bottom-right corner.
        p.addLine(to: CGPoint(x: rightEdge, y: H - br))
        p.addQuadCurve(to: CGPoint(x: rightEdge - br, y: H), control: CGPoint(x: rightEdge, y: H))
        // Bottom edge + bottom-left corner.
        p.addLine(to: CGPoint(x: leftEdge + br, y: H))
        p.addQuadCurve(to: CGPoint(x: leftEdge, y: H - br), control: CGPoint(x: leftEdge, y: H))
        // Left side up to where the skirt begins.
        p.addLine(to: CGPoint(x: leftEdge, y: mb + neck))
        // Ogee skirt back up into the notch's left edge.
        p.addCurve(to: CGPoint(x: nl, y: mb),
                   control1: CGPoint(x: leftEdge, y: mb),
                   control2: CGPoint(x: nl, y: mb + neck))
        // Up the pill's left edge, closing the loop.
        p.addLine(to: CGPoint(x: nl, y: nt))
        p.closeSubpath()
        return p
    }
}
