import SwiftUI
import AppKit

/// Loads website favicons (Safari-tab style) directly from the site — no third
/// party. Memory + disk cached. Off by default in spirit with the app's privacy:
/// gated by the `bookmarkFavicons` setting (see Settings → Bookmarks).
@MainActor
final class FaviconLoader {
    static let shared = FaviconLoader()

    private var memory: [String: NSImage] = [:]
    private var inFlight: Set<String> = []
    private let cacheDir: URL

    /// User setting — fetching favicons requires network; default on.
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: "bookmarkFavicons") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "bookmarkFavicons") }
    }

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDir = base.appendingPathComponent("Favicons", isDirectory: true)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    /// Returns a cached favicon immediately if present.
    func cached(for host: String) -> NSImage? {
        if let img = memory[host] { return img }
        let file = cacheDir.appendingPathComponent(host + ".png")
        if let data = try? Data(contentsOf: file), let img = NSImage(data: data) {
            memory[host] = img
            return img
        }
        return nil
    }

    /// Fetch the favicon for a host, calling `completion` on the main actor when
    /// ready. No-ops if disabled, already cached, or already in flight.
    func load(host: String, completion: @escaping (NSImage) -> Void) {
        guard Self.enabled, !host.isEmpty else { return }
        if let img = cached(for: host) { completion(img); return }
        guard !inFlight.contains(host) else { return }
        inFlight.insert(host)

        Task.detached(priority: .utility) {
            let img = await Self.download(host: host)
            await MainActor.run {
                self.inFlight.remove(host)
                guard let img else { return }
                self.memory[host] = img
                if let tiff = img.tiffRepresentation,
                   let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                    try? png.write(to: self.cacheDir.appendingPathComponent(host + ".png"))
                }
                completion(img)
            }
        }
    }

    /// Try a few standard favicon locations on the site itself (no aggregator).
    private static func download(host: String) async -> NSImage? {
        let candidates = [
            "https://\(host)/apple-touch-icon.png",
            "https://\(host)/favicon.ico",
            "https://\(host)/favicon.png",
        ]
        for str in candidates {
            guard let url = URL(string: str) else { continue }
            var req = URLRequest(url: url, timeoutInterval: 5)
            req.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
            if let (data, resp) = try? await URLSession.shared.data(for: req),
               (resp as? HTTPURLResponse)?.statusCode == 200,
               let img = NSImage(data: data), img.size.width > 4 {
                return img
            }
        }
        return nil
    }
}

/// A favicon view that loads asynchronously and falls back to a link glyph.
struct FaviconView: View {
    let host: String
    var size: CGFloat = 16
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else {
                Image(systemName: "globe")
                    .font(.system(size: size * 0.72, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            image = FaviconLoader.shared.cached(for: host)
            FaviconLoader.shared.load(host: host) { img in image = img }
        }
        .id(host)
    }
}
