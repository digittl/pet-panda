# pet-panda

A native macOS menu bar app called **Panda Pal** — a cute floating pet panda that lives on your screen.

## Download

Go to the [Releases](../../releases) page and download the latest `PandaPal.zip`. Unzip it and run `PandaPal.app`.

> On first launch, right-click the app → **Open** to bypass Gatekeeper (the app is unsigned).

## Build from Source

See [PandaPal/README.md](PandaPal/README.md) for full build and run instructions.

### Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15.0 or later

### Quick Start

```bash
cd PandaPal
open PandaPal.xcodeproj
# Press ⌘R in Xcode to build and run
```

Or from the command line:

```bash
cd PandaPal
xcodebuild -project PandaPal.xcodeproj -scheme PandaPal -configuration Release build
```

## CI/CD

- **Every push to `main`** and every PR triggers a build on macOS. The built `.app` is available as a workflow artifact on the Actions tab.
- **Creating a GitHub Release** (tag + publish) automatically builds the app and attaches `PandaPal.zip` as a downloadable release asset.
