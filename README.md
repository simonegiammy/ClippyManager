# ClippyManager

A lightweight, privacy-first clipboard manager for macOS — lives in your menu bar, remembers everything you copy.

![macOS 14+](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift 5](https://img.shields.io/badge/Swift-5-orange)
![License MIT](https://img.shields.io/badge/License-MIT-green)
![App Sandbox](https://img.shields.io/badge/App%20Sandbox-✓-teal)

---

## Features

| Feature | Description |
|---|---|
| **Clipboard history** | Captures everything you copy: text, links, code, colors, images, files |
| **Instant search** | Full-text search across your entire history |
| **Smart categories** | Auto-classifies items into Text / Links / Code / Colors / Images / Files |
| **Color detection** | Recognizes HEX, RGB, RGBA, HSL, HSLA, HSV, CMYK — with color swatch preview |
| **Code detection** | Multi-line code snippets detected automatically with language hint |
| **Pinned items** | Pin frequently-used items so they always stay at the top |
| **Source app tracking** | See which app you copied from, with icon |
| **Global shortcut** | Open the panel with ⌘⇧V from anywhere |
| **Sort order** | Toggle Newest First / Oldest First |
| **Privacy by design** | Zero cloud sync, zero tracking, zero analytics — data stays on your Mac |
| **App Sandbox** | Fully sandboxed, App Store-ready |

---

## Screenshots

> _Coming soon — app icon and screenshots to be added._

---

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15+ to build from source

---

## Building from source

```bash
# 1. Clone
git clone https://github.com/simonegiammy/ClippyManager.git
cd ClippyManager

# 2. Generate the Xcode project (requires xcodegen)
brew install xcodegen
xcodegen generate

# 3. Open in Xcode
open ClippyManager.xcodeproj

# 4. Build & Run (⌘R)
```

> **Or build from the command line (unsigned, development only):**
> ```bash
> xcodebuild -scheme ClippyManager build \
>   CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO
> ```

---

## Architecture

```
ClippyManager/
├── AppDelegate.swift          # NSStatusItem + NSPopover + lifecycle
├── main.swift                 # Entry point
├── Models/
│   ├── ClipItem.swift         # SwiftData @Model
│   └── ClipItemType.swift     # Enum: text/link/code/color/image/file
├── Services/
│   ├── ClipboardMonitor.swift # NSPasteboard polling (0.4 s interval)
│   ├── ContentClassifier.swift# Auto-classifies clipboard content
│   ├── HotKeyManager.swift    # ⌘⇧V via Carbon RegisterEventHotKey
│   ├── SourceAppTracker.swift # NSWorkspace frontmost app capture
│   └── StorageManager.swift   # SwiftData container + CRUD + pruning
├── Views/
│   ├── HistoryPanelView.swift # Main panel (search + chips + list + footer)
│   ├── SearchBarView.swift
│   ├── CategoryChipsView.swift
│   ├── ClipRowView.swift
│   ├── SettingsView.swift
│   └── EmptyStateView.swift
├── Extensions/
│   └── Extensions.swift       # Color(hex:), Date.relativeShort, NSImage resize
└── Resources/
    ├── Assets.xcassets/       # App icon + teal AccentColor
    └── PrivacyInfo.xcprivacy  # Privacy manifest: no data collection
```

**Key technical decisions:**
- **Persistence**: SwiftData (`@Model`), macOS 14+
- **Global hotkey**: Carbon `RegisterEventHotKey` — sandbox-safe, no Accessibility permission required
- **Clipboard monitor**: `NSPasteboard.changeCount` polling on main `RunLoop` with `.common` mode
- **Observable state**: `@Observable` + `@Environment` (Swift 5.9 / macOS 14 approach)
- **No paste simulation**: clicking an item puts it in the pasteboard; the user pastes normally with ⌘V (no Accessibility permission needed)

---

## Roadmap

- [ ] Secure Items — Touch ID / password protection for sensitive clips
- [ ] Developer Mode — code editor with syntax highlighting
- [ ] Text editor — edit before pasting
- [ ] Source app filtering — filter history by which app you copied from
- [ ] Time-based cleanup — clear Last Hour / Today / Yesterday / Last 7 days
- [ ] Ignored apps list — privacy per-app (e.g. password managers)
- [ ] Auto-paste — optional ⌘V simulation after copy (requires Accessibility)
- [ ] App icon — custom teal/green icon design
- [ ] App Store submission

---

## Contributing

Pull requests are welcome. For significant changes, open an issue first to discuss what you'd like to change.

1. Fork the repo
2. Create a branch: `git checkout -b feature/my-feature`
3. Commit your changes
4. Push and open a PR

Please keep changes focused and test on macOS 14+.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Inspired by

[ClipBoardy](https://www.clipboardy.app) by Tristan Jarrett — an excellent clipboard manager on the App Store. ClippyManager is an independent open-source reimplementation built from scratch.
