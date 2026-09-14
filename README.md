<div align="center">
  <img width="150" height="150" src="/assets/icon.png" alt="Slate logo">
  <h1>Slate</h1>
  <p>A small, fast, WebKit browser for macOS.</p>
</div>
<br/>
<p align="center">
  <a href="https://www.apple.com/macos/"><img src="https://badgen.net/badge/macOS/15+/blue" alt="macOS 15+"></a>
  <a href="https://swift.org"><img src="https://badgen.net/badge/Swift/5.9/orange" alt="Swift 5.9"></a>
  <a href="LICENSE"><img src="https://badgen.net/badge/License/GPL-3.0/green" alt="GPL-3.0"></a>
</p>

> [!NOTE]
> Slate is a personal project under active construction and is not ready for daily use yet.

## Overview

Slate is a personal daily-driver browser for macOS, forked from [Ora Browser](https://github.com/the-ora/browser). It uses WebKit (`WKWebView`) — the engine that ships with macOS — so there is no bundled Chromium and no Electron.

The goal is a browser that idles near 100 MB with a dozen tabs, opens in under half a second, blocks ads at the network layer, keeps Chrome-style profiles fully isolated, and plays DRM video. Nothing else. Every feature has to earn its RAM.

See [`BROWSER_SPEC.md`](BROWSER_SPEC.md) for the full brief, the locked decisions, and the measurable targets.

## Quick Start

```bash
git clone https://github.com/IMsumitkumar/Slate.git
cd Slate
./scripts/setup.sh
open Slate.xcodeproj
```

The setup script installs required tooling, installs git hooks, and regenerates the Xcode project.

## Development

- Main app target: `Slate`
- Project configuration is managed with `XcodeGen` in `project.yml`
- Regenerate the project after config changes with `xcodegen`
- Build: `xcodebuild build -scheme Slate -configuration Release -destination "platform=macOS"`
- Test: `xcodebuild test -scheme Slate -destination "platform=macOS"`

Slate is **ad-hoc signed**. There is no Apple Developer account, no team ID, and no notarization, so a downloaded build needs right-click → Open on first launch.

## Docs

- [Spec](BROWSER_SPEC.md) — the brief this project is built against
- [Audit](docs/AUDIT.md) — module-by-module Keep / Cut / Missing map
- [Measurements](docs/MEASUREMENTS.md) — every metric, every commit
- [Lessons](docs/LESSONS.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)

## Credits

Slate is a fork of **[Ora Browser](https://github.com/the-ora/browser)** (GPL-3.0) by [@yonaries](https://github.com/yonaries), [@kenenisa](https://github.com/kenenisa), and contributors. Ora did the hard part: the WebKit shell, the Sparkle integration, the AdGuard content-blocker pipeline, and the sandbox and signing configuration. Slate keeps that foundation and cuts it down.

Feature patterns for profiles, tab suspension, and extension hosting are adapted from **[Vane](https://github.com/notnaki/vane)** (MIT). See [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## License

Slate is licensed under [GPL-3.0](LICENSE), inherited from Ora Browser. Third-party libraries used by this project are licensed under their own open-source licenses.
