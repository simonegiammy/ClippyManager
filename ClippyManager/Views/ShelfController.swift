import Observation

/// Drives the shelf's open/close so AppDelegate can trigger an ANIMATED collapse
/// (set `isOpen = false`, let the view animate, then order the panel out).
@Observable
@MainActor
final class ShelfController {
    var isOpen: Bool = false

    /// When true, the shelf must NOT auto-close on mouse-leave — a modal (e.g. the
    /// "New Category" sheet) or an in-flight AI preview is showing inside it.
    var keepOpen: Bool = false

    // Timings measured from NotchDock's recording (panel-height per frame):
    //  open  ~0.40s, fast-out with a tiny overshoot
    //  close ~0.45s, ease-in-out, no bounce
    static let openDuration: Double = 0.40
    static let closeDuration: Double = 0.42
}
