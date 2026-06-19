import SwiftUI

/// The signature Aurora Glass shape: a 200px notch pill with **concave
/// shoulders** that grows downward into the full panel as one continuous form —
/// so the shelf reads as a physical extension of the notch, never a detached bar.
///
/// `progress` 0 → just the pill (closed); 1 → full panel (open). It's the
/// `animatableData`, so animating it produces the "genie" grow/suck effect.
struct NotchShape: Shape {
    /// 0 = closed (pill only), 1 = fully open.
    var progress: CGFloat
    /// Pill width at the top (matches the physical notch).
    var pillWidth: CGFloat = 200
    /// Height of the menu-bar band the pill lives in.
    var menuBand: CGFloat = 36
    /// Corner radius of the expanded panel body.
    var bodyRadius: CGFloat = 26
    /// Pill top corner radius and shoulder radius.
    var pillTop: CGFloat = 11
    var shoulder: CGFloat = 20

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let W = rect.width
        let prog = max(0, min(1, progress))
        let mb = menuBand
        let nt = pillTop
        let r = shoulder
        let cx = W / 2
        let nl = cx - pillWidth / 2
        let nr = cx + pillWidth / 2

        // Body grows in BOTH width and height together so it physically emerges
        // from the notch. Growing only height left a full-width thin sliver at the
        // menu band early on, whose concave shoulders read as "wings/M".
        let fullBodyH = max(0, rect.height - mb)
        let bodyH = fullBodyH * prog
        let H = mb + bodyH
        // Edges interpolate from just outside the pill (closed) to the frame edges (open).
        let leftEdge  = (nl - r) * (1 - prog)
        let rightEdge = W - (W - (nr + r)) * (1 - prog)
        // Clamp corner radius so short/narrow bodies never fold back on themselves.
        let br = min(bodyRadius, bodyH / 2, (rightEdge - leftEdge) / 2)

        var p = Path()
        // Pill top
        p.move(to: CGPoint(x: nl, y: nt))
        p.addQuadCurve(to: CGPoint(x: nl + nt, y: 0), control: CGPoint(x: nl, y: 0))
        p.addLine(to: CGPoint(x: nr - nt, y: 0))
        p.addQuadCurve(to: CGPoint(x: nr, y: nt), control: CGPoint(x: nr, y: 0))
        // Down the pill's right edge, concave shoulder out to the body's right edge
        p.addLine(to: CGPoint(x: nr, y: mb - r))
        p.addQuadCurve(to: CGPoint(x: min(nr + r, rightEdge - br), y: mb), control: CGPoint(x: nr, y: mb))
        p.addLine(to: CGPoint(x: rightEdge - br, y: mb))
        p.addQuadCurve(to: CGPoint(x: rightEdge, y: mb + br), control: CGPoint(x: rightEdge, y: mb))
        // Right side down + bottom-right corner
        p.addLine(to: CGPoint(x: rightEdge, y: H - br))
        p.addQuadCurve(to: CGPoint(x: rightEdge - br, y: H), control: CGPoint(x: rightEdge, y: H))
        // Bottom edge + bottom-left corner
        p.addLine(to: CGPoint(x: leftEdge + br, y: H))
        p.addQuadCurve(to: CGPoint(x: leftEdge, y: H - br), control: CGPoint(x: leftEdge, y: H))
        // Left side up + top-left body corner
        p.addLine(to: CGPoint(x: leftEdge, y: mb + br))
        p.addQuadCurve(to: CGPoint(x: leftEdge + br, y: mb), control: CGPoint(x: leftEdge, y: mb))
        p.addLine(to: CGPoint(x: max(nl - r, leftEdge + br), y: mb))
        // Concave shoulder back up into the pill
        p.addQuadCurve(to: CGPoint(x: nl, y: mb - r), control: CGPoint(x: nl, y: mb))
        p.addLine(to: CGPoint(x: nl, y: nt))
        p.closeSubpath()
        return p
    }
}
