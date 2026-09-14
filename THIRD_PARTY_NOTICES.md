# Third-Party Notices

This repository includes third-party source code and other third-party components that remain subject to their own licenses.

## Ora Browser (upstream)

- Upstream project: [the-ora/browser](https://github.com/the-ora/browser)
- License: GPL-3.0
- Local path: the whole repository

Slate is a fork of Ora Browser. Almost all of the Swift source in `ora/` originated in Ora and remains under GPL-3.0, which Slate inherits. Ora's git history is preserved in this repository, and `upstream` is configured as a git remote pointing at the original project. The full license text is in [`LICENSE`](LICENSE).

## Vane

- Upstream project: [notnaki/vane](https://github.com/notnaki/vane)
- License: MIT

Feature patterns for profiles (`WKWebsiteDataStore(forIdentifier:)`), tab suspension via `WKWebView.interactionState`, `WKWebExtension` hosting, and the FairPlay DRM probe are adapted from Vane. Each adapted file carries a header comment:

```swift
// Adapted from Vane (MIT) — https://github.com/notnaki/vane
```

> No Vane-derived code has landed yet. This entry will list the specific files, and carry Vane's license text, once Phase 2 ports them.

## SplitView

- Upstream project: [stevengharris/SplitView](https://github.com/stevengharris/SplitView)
- Upstream source path: `Sources/SplitView`
- Local path: `ora/Shared/Layout/SplitView`
- License: MIT
- Included license text: `Vendor/SplitView/LICENSE`

The files in `ora/Shared/Layout/SplitView` were copied from the upstream `SplitView` project and may include local modifications.

## Swift package dependencies

Resolved through Swift Package Manager and not vendored into this repository:

| Package | License | Used for |
|---|---|---|
| [Sparkle](https://github.com/sparkle-project/Sparkle) | MIT | Auto-updates |
| [SafariConverterLib](https://github.com/AdguardTeam/SafariConverterLib) | LGPL-3.0 | AdGuard/EasyList → WebKit content rules |
| [FaviconFinder](https://github.com/will-lumley/FavIconFinder) | MIT | Tab icons |
| [Inject](https://github.com/krzysztofzablocki/Inject) | MIT | Debug-only hot reload |

SafariConverterLib additionally pulls in `swift-psl`, `Punycode`, and `swift-argument-parser`; FaviconFinder pulls in `SwiftSoup`.
