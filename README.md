# pet-panda

A native macOS menu bar app called **Panda Pal** — a cute floating pet panda that lives on your screen.

## Quick Start

See [PandaPal/README.md](PandaPal/README.md) for full build and run instructions.

### Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later

### Build & Run

```bash
cd PandaPal
open PandaPal.xcodeproj
# Press ⌘R in Xcode to build and run
```

Or from the command line:

```bash
cd PandaPal
xcodebuild -project PandaPal.xcodeproj -scheme PandaPal -configuration Debug build
open build/Build/Products/Debug/PandaPal.app
```
