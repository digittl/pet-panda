# AGENTS.md

## Cursor Cloud specific instructions

This repository contains **Panda Pal**, a native macOS SwiftUI menu bar app. It requires macOS and Xcode to build — it cannot be compiled on Linux.

### Project structure

- `PandaPal/` — the Xcode project directory
  - `PandaPal.xcodeproj` — Xcode project file (shared scheme included)
  - `PandaPal/` — Swift source files (AppDelegate, views, view model, window controller)
  - `Package.swift` — alternative SPM build support

### Building

- **Primary**: Open `PandaPal/PandaPal.xcodeproj` in Xcode, press ⌘R
- **CLI**: `cd PandaPal && xcodebuild -project PandaPal.xcodeproj -scheme PandaPal build`
- **SPM**: `cd PandaPal && swift build` (limited — no .app bundle)

### Key caveats

- This is a macOS-only project. The cloud VM (Linux) cannot compile or run it.
- No external dependencies — pure Apple frameworks (SwiftUI, AppKit, Combine).
- No tests are configured yet — the project is purely visual/interactive.
- The `LSUIElement=true` plist key hides the app from the Dock; the app only appears in the menu bar.
- The floating panda uses `NSPanel` with `.nonactivatingPanel` to avoid stealing focus from other apps.
