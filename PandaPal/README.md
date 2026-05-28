# Panda Pal 🐼

A native macOS menu bar app featuring a cute floating pet panda that lives on your screen.

## Features

- **Menu bar only** — no Dock icon, runs silently in your menu bar
- **Floating panda** — a transparent, borderless window with a vector-drawn panda that floats above all other windows
- **Draggable** — drag the panda anywhere on screen
- **Idle animations** — the panda blinks, waves, sleeps, stretches, and looks around on its own
- **Pat reaction** — click the panda to trigger a cute bounce + heart animation
- **Position persistence** — remembers where you left the panda between app launches
- **Menu bar controls** — Show/Hide Panda, Reset Position, and Quit

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later (for building)

## Build & Run

### Option 1: Xcode (Recommended)

1. Open `PandaPal.xcodeproj` in Xcode
2. Select the **PandaPal** scheme and **My Mac** as the destination
3. Press **⌘R** to build and run

### Option 2: Command Line with xcodebuild

```bash
cd PandaPal
xcodebuild -project PandaPal.xcodeproj -scheme PandaPal -configuration Debug build
```

The built app will be in the `build/` directory. You can find it with:

```bash
find build -name "PandaPal.app" -type d
```

Then open it:

```bash
open build/Build/Products/Debug/PandaPal.app
```

### Option 3: Swift Package Manager

```bash
cd PandaPal
swift build
```

Then run:

```bash
.build/debug/PandaPal
```

> **Note:** The SPM build runs as a plain executable. For the full macOS app experience (menu bar icon, proper activation policy), use the Xcode build which produces a proper `.app` bundle with the Info.plist.

## Usage

1. After launching, you'll see a **paw print icon** (🐾) in your menu bar
2. A cute panda will appear floating on your screen
3. **Drag** the panda anywhere you like
4. **Click** the panda to pat it — it will bounce and show a heart
5. Wait and watch — the panda has idle animations (blinking, waving, sleeping, stretching, looking around)
6. Use the menu bar icon to:
   - **Show/Hide Panda** (⌘P) — toggle panda visibility
   - **Reset Position** (⌘R) — move panda back to center of screen
   - **Quit** (⌘Q) — exit the app

## Architecture

```
PandaPal/
├── PandaPalApp.swift          # App entry point (@main)
├── AppDelegate.swift          # Menu bar setup, status item, menu actions
├── PandaWindowController.swift # NSPanel config, position persistence, dragging
├── PandaViewModel.swift       # Animation state machine, idle cycle, pat reaction
├── PandaContainerView.swift   # Root SwiftUI view with overlays (hearts, zzz)
├── PandaView.swift            # Vector panda drawn with SwiftUI shapes
└── Info.plist                 # LSUIElement=true to hide from Dock
```

## Technical Details

- **Floating window**: Uses `NSPanel` with `.borderless` and `.nonactivatingPanel` style masks, configured as transparent with `.floating` window level
- **No Dock icon**: `LSUIElement = true` in Info.plist plus `NSApp.setActivationPolicy(.accessory)` at runtime
- **Programmatic assets**: The panda is drawn entirely with SwiftUI `Circle`, `Ellipse`, `RoundedRectangle`, and custom `Shape` paths — no image files needed
- **Position persistence**: Last position saved to `UserDefaults` on every window move
- **Animation system**: Timer-based idle cycle with randomized intervals; each animation state modifies `@Published` properties that drive SwiftUI view updates

## License

MIT
