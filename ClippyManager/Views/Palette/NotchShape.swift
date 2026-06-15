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
        // The panel body grows from the menu band down to the eased height.
        let eased = max(menuBand + 1, rect.height)
        let H = menuBand + (eased - menuBand) * max(0, min(1, progress))

        let cx = W / 2
        let nl = cx - pillWidth / 2
        let nr = cx + pillWidth / 2
        let r = shoulder
        let nt = pillTop
        let br = bodyRadius
        let mb = menuBand

        var p = Path()
        // Pill top edge
        p.move(to: CGPoint(x: nl, y: nt))
        p.addQuadCurve(to: CGPoint(x: nl + nt, y: 0), control: CGPoint(x: nl, y: 0))
        p.addLine(to: CGPoint(x: nr - nt, y: 0))
        p.addQuadCurve(to: CGPoint(x: nr, y: nt), control: CGPoint(x: nr, y: 0))
        // Right concave shoulder out to the panel
        p.addLine(to: CGPoint(x: nr, y: mb - r))
        p.addQuadCurve(to: CGPoint(x: nr + r, y: mb), control: CGPoint(x: nr, y: mb))
        p.addLine(to: CGPoint(x: W - br, y: mb))
        p.addQuadCurve(to: CGPoint(x: W, y: mb + br), control: CGPoint(x: W, y: mb))
        // Right side down
        p.addLine(to: CGPoint(x: W, y: H - br))
        p.addQuadCurve(to: CGPoint(x: W - br, y: H), control: CGPoint(x: W, y: H))
        // Bottom
        p.addLine(to: CGPoint(x: br, y: H))
        p.addQuadCurve(to: CGPoint(x: 0, y: H - br), control: CGPoint(x: 0, y: H))
        // Left side up
        p.addLine(to: CGPoint(x: 0, y: mb + br))
        p.addQuadCurve(to: CGPoint(x: br, y: mb), control: CGPoint(x: 0, y: mb))
        p.addLine(to: CGPoint(x: nl - r, y: mb))
        // Left concave shoulder back into the pill
        p.addQuadCurve(to: CGPoint(x: nl, y: mb - r), control: CGPoint(x: nl, y: mb))
        p.addLine(to: CGPoint(x: nl, y: nt))
        p.closeSubpath()
        return p
    }
}
