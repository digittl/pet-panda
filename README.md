# pet-panda

A native macOS menu bar app called **Panda Pal** — a cute floating pet panda that lives on your screen.

## Download

Go to the [Releases](../../releases) page and download the latest `PandaPal.zip`. Unzip it and run `PandaPal.app`.

> The app is unsigned, so macOS will quarantine it on download. Before first launch, strip the quarantine flag from Terminal:
>
> ```bash
> xattr -dr com.apple.quarantine /Applications/PandaPal.app
> ```
>
> (Adjust the path if you unzipped somewhere other than `/Applications`.) Right-click → **Open** no longer works on current macOS for unsigned apps — the `xattr` command is the only way.

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

## Auto-updates

PandaPal uses [Sparkle](https://sparkle-project.org) for in-app updates. It checks `https://digittl.github.io/pet-panda/appcast.xml` once a day; when a new version is published the menu bar offers to install it. You can also force a check via the menu bar → **Check for Updates…**

## CI/CD

- **Every push to `main`** and every PR triggers a build on macOS. The built `.app` is available as a workflow artifact on the Actions tab.
- **Creating a GitHub Release** (tag + publish) automatically builds the app, signs the zip with Sparkle's EdDSA key, attaches `PandaPal.zip` as a downloadable release asset, and pushes a fresh `appcast.xml` to the `gh-pages` branch (served via GitHub Pages). The release tag (e.g. `v1.1.0`) drives `CFBundleShortVersionString` so Sparkle can compare versions correctly.
