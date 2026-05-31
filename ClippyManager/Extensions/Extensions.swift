import SwiftUI
import AppKit

// MARK: - Color from hex string

extension Color {
    init?(hex: String) {
        var raw = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.hasPrefix("#") { raw = String(raw.dropFirst()) }
        var int: UInt64 = 0
        Scanner(string: raw).scanHexInt64(&int)
        switch raw.count {
        case 3:
            self.init(
                .sRGB,
                red:   Double((int >> 8) & 0xF) / 15,
                green: Double((int >> 4) & 0xF) / 15,
                blue:  Double(int & 0xF)        / 15
            )
        case 6:
            self.init(
                .sRGB,
                red:   Double((int >> 16) & 0xFF) / 255,
                green: Double((int >>  8) & 0xFF) / 255,
                blue:  Double(int & 0xFF)          / 255
            )
        case 8:
            self.init(
                .sRGB,
                red:     Double((int >> 16) & 0xFF) / 255,
                green:   Double((int >>  8) & 0xFF) / 255,
                blue:    Double(int & 0xFF)          / 255,
                opacity: Double((int >> 24) & 0xFF) / 255
            )
        default:
            return nil
        }
    }
}

// MARK: - Relative date display

extension Date {
    var relativeShort: String {
        let interval = Date.now.timeIntervalSince(self)
        if interval < 60     { return "now" }
        if interval < 3_600  { return "\(Int(interval / 60))m" }
        if interval < 86_400 { return "\(Int(interval / 3_600))h" }
        return "\(Int(interval / 86_400))d"
    }
}

// MARK: - NSImage resize helper

extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let img = NSImage(size: newSize)
        img.lockFocus()
        let ctx = NSGraphicsContext.current!
        ctx.imageInterpolation = .high
        draw(in: NSRect(origin: .zero, size: newSize),
             from:  NSRect(origin: .zero, size: size),
             operation: .copy,
             fraction: 1)
        img.unlockFocus()
        return img
    }
}
