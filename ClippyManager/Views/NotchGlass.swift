import SwiftUI
import AppKit

/// Behind-window vibrancy **masked to the NotchShape** and animated natively with
/// Core Animation. SwiftUI's `.clipShape` cannot mask an `NSVisualEffectView`
/// (the real desktop blur), which is what left un-rounded black corners and a
/// rectangle that didn't follow the shape on close. Masking the layer directly
/// fixes both, and CA gives a buttery grow/retract.
struct NotchGlass: NSViewRepresentable {
    var isOpen: Bool
    var width: CGFloat
    var height: CGFloat
    var menuBand: CGFloat
    var neckDepth: CGFloat
    var openDuration: Double
    var closeDuration: Double

    func makeNSView(context: Context) -> NotchGlassNSView {
        let v = NotchGlassNSView()
        v.menuBand = menuBand
        v.neckDepth = neckDepth
        v.frame = NSRect(x: 0, y: 0, width: width, height: height)
        v.apply(open: isOpen, animated: false, duration: 0)
        context.coordinator.lastOpen = isOpen
        return v
    }

    func updateNSView(_ v: NotchGlassNSView, context: Context) {
        v.menuBand = menuBand
        v.neckDepth = neckDepth
        if context.coordinator.lastOpen != isOpen {
            context.coordinator.lastOpen = isOpen
            v.apply(open: isOpen, animated: true,
                    duration: isOpen ? openDuration : closeDuration)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator { var lastOpen: Bool? }
}

final class NotchGlassNSView: NSView {
    private let effect = NSVisualEffectView()
    private let veil = CALayer()
    private let maskLayer = CAShapeLayer()
    var menuBand: CGFloat = 34
    var neckDepth: CGFloat = 70
    private var currentOpen = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.isEmphasized = true
        effect.autoresizingMask = [.width, .height]
        addSubview(effect)
        effect.wantsLayer = true

        // Warm veil over the blur (keeps text legible, matches the other glass).
        veil.backgroundColor = NSColor(srgbRed: 34/255, green: 22/255, blue: 14/255, alpha: 0.42).cgColor
        effect.layer?.addSublayer(veil)

        // The shape mask on the blur.
        maskLayer.fillColor = NSColor.black.cgColor
        effect.layer?.mask = maskLayer

        // Soft shadow that EXACTLY hugs the mask shape with ZERO offset. Using
        // the same path as the mask means there's never a second silhouette
        // (the old body-rect shadow caused a visible double border on close);
        // zero offset means the concave shoulders can't cast directional "beaks".
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.32
        layer?.shadowRadius = 13
        layer?.shadowOffset = .zero
        layer?.masksToBounds = false
    }
    required init?(coder: NSCoder) { fatalError() }

    override func layout() {
        super.layout()
        effect.frame = bounds
        veil.frame = bounds
        maskLayer.frame = bounds
        // Re-assert the static path for the current state on relayout.
        let p = flippedPath(progress: currentOpen ? 1 : 0)
        maskLayer.path = p
        layer?.shadowPath = p
    }

    func apply(open: Bool, animated: Bool, duration: Double) {
        currentOpen = open
        let target = flippedPath(progress: open ? 1 : 0)
        let timing = open
            ? CAMediaTimingFunction(controlPoints: 0.22, 1.1, 0.36, 1)
            : CAMediaTimingFunction(controlPoints: 0.4, 0, 0.2, 1)

        if animated {
            // Mask AND shadow animate along the SAME path → one outline, no seam.
            let a = CABasicAnimation(keyPath: "path")
            a.fromValue = maskLayer.presentation()?.path ?? maskLayer.path
            a.toValue = target
            a.duration = duration
            a.timingFunction = timing
            maskLayer.add(a, forKey: "path")

            let s = CABasicAnimation(keyPath: "shadowPath")
            s.fromValue = layer?.presentation()?.shadowPath ?? layer?.shadowPath
            s.toValue = target
            s.duration = duration
            s.timingFunction = timing
            layer?.add(s, forKey: "shadowPath")
        }
        maskLayer.path = target
        layer?.shadowPath = target
    }

    /// NotchShape path flipped into the layer's bottom-left coordinate space.
    private func flippedPath(progress: CGFloat) -> CGPath {
        let rect = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        let p = NotchShape(progress: progress, menuBand: menuBand, neckDepth: neckDepth).path(in: rect).cgPath
        var flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: bounds.height)
        return p.copy(using: &flip) ?? p
    }
}
