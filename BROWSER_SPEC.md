# Lightweight macOS Browser — Engineering Spec

Version 1.0 · September 14, 2026
Status: final decisions. Hand this file to Claude Code as the brief.

---

## 1. Intent

I am building a personal daily-driver browser for macOS to replace Google Chrome. It must use very little memory, very little energy, start fast, and have only the features I use. It will be open source under GPL-3.0 and I will share progress publicly, so the code must be clean enough to show.

The larger goal: a browser that idles near 100 MB with a dozen tabs, opens in under half a second, blocks ads at the network layer, keeps Chrome-style profiles fully isolated, and plays DRM video. Nothing else.

## 2. Decisions (locked)

These were decided after research. Do not reopen them.

| Decision | Choice | Why |
|---|---|---|
| Engine | WebKit via `WKWebView` | Ships with macOS, shared memory, fastest on Apple Silicon, FairPlay DRM for free. No Chromium, no Electron, no CEF. |
| Base code | Fork of **Ora Browser** | Best foundation: Sparkle updater, AdGuard content blocker, App Sandbox, signing config, tests, macOS 15 minimum. |
| Feature reference | **Vane** (MIT) | Has profiles, tab sleeping, `WKWebExtension` hosting, DRM check. Copy patterns with attribution. |
| Language | Swift 5.9+, SwiftUI + AppKit | What Ora already uses. Do not migrate to Swift 6 strict concurrency unless it is free. |
| License | GPL-3.0 | Inherited from Ora. Non-negotiable. |
| Memory rule | Every feature must earn its RAM | If a feature's memory cost cannot be measured, it does not ship. |
| GPU as memory | Rejected | Apple Silicon has unified memory. There is no "elsewhere" to put page memory. |
| Servo / Ladybird | Not now | Not daily-driver ready in 2026. Revisit in 2027. |

## 3. Sources

### Base: Ora Browser
- Repo: https://github.com/the-ora/browser
- License: GPL-3.0
- Stack: Swift 5.9, SwiftUI + AppKit, WebKit, XcodeGen (`project.yml`), macOS 15.0+
- Dependencies (from `project.yml`):
  - Sparkle 2.6+ — auto-updates (https://github.com/sparkle-project/Sparkle)
  - SafariConverterLib 4.2.2 — AdGuard/EasyList → WebKit content rules (https://github.com/AdguardTeam/SafariConverterLib)
  - FaviconFinder 5.1.5 — tab icons
  - Inject 1.5.2 — dev hot reload only
- Entitlements: App Sandbox on, hardened runtime on, `com.apple.developer.web-browser`, JIT, camera, mic, downloads
- Structure: `ora/App/`, `ora/Core/`, `ora/Features/`, `ora/Shared/`, `ora/Info/`, `ora/Resources/`
- Known state: last release v0.2.14 on April 7, 2026. 27 open issues. Treat it as a starting point I now maintain, not an upstream I depend on.

### Feature reference: Vane
- Repo: https://github.com/notnaki/vane
- License: MIT (compatible with GPL-3.0; keep attribution)
- What to study and port:
  - `Profiles.swift` — profiles via `WKWebsiteDataStore(forIdentifier:)`, one SQLite file, keychain items, favicons, session, and extensions per profile
  - `Engine.swift` — tab suspension: save `WKWebView.interactionState`, drop the web view after idle timeout, recreate on click, release under memory pressure; pinned and PiP tabs exempt
  - `Extensions.swift` — `WKWebExtensionController` hosting, one controller per profile
  - `DRMCheck.swift` — EME probe proving FairPlay loads; Safari user-agent string requirement
  - `Crash.swift` — running-marker file plus 30-second session autosave
- Requires macOS 26 for `WKWebExtension`, `isInspectable`, `pageZoom`. Guard those behind `#available` if my minimum stays at 15.

### Apple APIs
- Profiles: `WKWebsiteDataStore(forIdentifier:)` — macOS 14+. Guide: https://webkit.org/blog/14423/building-profiles-with-new-webkit-api/
- Extensions: `WKWebExtension`, `WKWebExtensionContext`, `WKWebExtensionController` — macOS 15.4+. Docs: https://developer.apple.com/documentation/webkit/wkwebextension
- Content blocking: `WKContentRuleListStore` — rules compile to bytecode and run in the network process. No JavaScript, no per-page cost.
- Tab state: `WKWebView.interactionState` — URL, back/forward list, scroll position.
- Autoplay: `WKWebViewConfiguration.mediaTypesRequiringUserActionForPlayback = .all`

### What NOT to use
- Min (Electron) — bundles Chromium. Only its ideas (task groups, fuzzy address bar) are worth anything.
- Any Electron, Tauri, CEF, or Chromium dependency. Zero exceptions.

## 4. Feature list

### Keep (must exist in v1)
- Tabs: open, close, reorder, pin, drag between windows
- Tab sleeping after N idle minutes (default 10), instant restore on click, exempt pinned and media-playing tabs
- Address bar: URL or search, suggestions from history and bookmarks, `!bang` search engine prefixes
- Profiles: create, switch, rename, delete; full data isolation; profile switcher in toolbar; delete removes the data store by identifier
- Content blocking: on by default, EasyList + EasyPrivacy + AdGuard Base via SafariConverterLib, weekly list refresh, per-site toggle
- Bookmarks with folders
- History with search and clear (last hour / day / all)
- Downloads to `~/Downloads`, no overwrite, show in Finder
- Find in page
- Private window (ephemeral data store, never written to disk)
- Extensions via `WKWebExtension`: install from folder, enable per profile
- Autoplay blocked by default
- Session restore and crash recovery
- Set as default browser, handle `http`/`https` URL events
- Sparkle auto-update pointed at MY appcast, not Ora's
- Dark mode follows system
- Chrome keyboard shortcuts: ⌘T ⌘W ⌘L ⌘⇧T ⌘1–9 ⌘F ⌘, ⌘Q

### Cut from Ora (remove in v1)
- Anything in Ora not on the Keep list: quick launcher extras, emoji picker, split view, developer-mode panels, themes, AI features, any social or sync surface
- Remove the code and its dependencies, not just the menu item

### Not in v1 (do not build)
- Sync, built-in password manager (use macOS Passwords or an extension), translate, reader mode, picture-in-picture, casting, sidebar panels, AI

## 5. Targets (measured, not felt)

| Metric | Target | How to measure |
|---|---|---|
| Idle memory, 1 blank tab | ≤ 80 MB app + WebContent | `footprint <pid>` or Activity Monitor, sum of app and its XPC children |
| Idle memory, 12 sleeping tabs | ≤ 150 MB | Same, after all 12 have slept |
| Cold launch to usable window | ≤ 500 ms | `time open -a <App>` plus log timestamp at first window |
| App binary size | ≤ 15 MB (Sparkle is most of it) | `du -sh <App>.app` |
| Energy impact, idle, 5 tabs | "Low" in Activity Monitor for 10 minutes | Activity Monitor Energy tab |
| Ad blocking | 0 requests to known ad domains on 3 test sites | Web Inspector network tab |
| Profile isolation | Login in profile A is absent in profile B | Manual test with two accounts |
| DRM | Netflix plays in a real window | Port Vane's `drmcheck` |

Record every measurement in `docs/MEASUREMENTS.md` with date and commit hash. A feature that moves a number the wrong way gets reverted or justified in that file.

## 6. Boundaries

- Do not add any dependency beyond the four Ora already has. If one seems needed, stop and ask with its memory cost.
- Do not pull in Electron, Tauri, CEF, Chromium, or a bundled engine under any name.
- Do not change the license or remove Ora's copyright notices. Add mine alongside.
- When porting from Vane, add `// Adapted from Vane (MIT) — https://github.com/notnaki/vane` at the top of each file and keep its license text in `THIRD_PARTY_NOTICES.md`.
- Replace before first build: bundle ID, app name, icon, Sparkle `SUFeedURL` and `SUPublicEDKey`; switch signing to ad-hoc and remove Ora's `DEVELOPMENT_TEAM` and provisioning profile. Never ship pointing at Ora's appcast or team.
- Do not refactor Ora's architecture for style. Cut and add only.
- Do not raise the macOS minimum above 15.0 without asking. Use `#available(macOS 26, *)` guards for newer WebKit APIs.
- Destructive actions that need my approval before doing: deleting a top-level module, changing `project.yml` dependencies, force-pushing, rewriting git history.
- If you find that Ora already has profiles or tab sleeping, report it and adapt rather than replacing it.

## 7. Phases

Only three phases, because only two real decision gates exist. Within a phase, work end to end.

### Phase 0 — Fork and own it
Outcome: my renamed fork builds and runs from a clean clone, signed with my team, with `upstream` as a git remote and Ora's appcast fully replaced by mine.

### Phase 1 — Audit
Outcome: a file `docs/AUDIT.md` that maps every Ora module to Keep / Cut / Missing against Section 4, with an estimated memory cost or saving per item, and baseline numbers for every metric in Section 5.

**Gate: I read the audit and approve the cut list before anything is deleted.**

### Phase 2 — Cut and add
Outcome: everything on the Cut list is gone, everything on the Keep list works, profiles and tab sleeping are ported from Vane's patterns, blocker lists refresh weekly, and all Section 5 targets are met or the miss is explained in `docs/MEASUREMENTS.md`.

**Gate: I run it daily for a week. I report what annoys me.**

### Phase 3 — Polish and release
Outcome: fixes from my week of use, ad-hoc signed `.dmg` published on GitHub Releases with a "right-click → Open on first launch" note, working Sparkle update from v1.0.0 to v1.0.1 proven end to end, README rewritten for my fork with credit to Ora and Vane.

## 8. Verification

Before calling any phase done:
- `xcodebuild build -scheme <App> -configuration Release` passes with zero warnings introduced by this work.
- `xcodebuild test -scheme <App>` passes. Add tests for profile isolation and tab sleep/restore.
- Every Section 5 metric is measured and written to `docs/MEASUREMENTS.md` with the commit hash.
- The app launches from a clean clone with only `./scripts/setup.sh` and `xcodegen`.
- Audit each claim against a tool result from this session. Only report work you can point to evidence for. If something is not verified, say so. If tests fail, say so with the output.

## 9. Working style

When you have enough information to act, act. If you are weighing a choice, give a recommendation, not a survey. Do the simplest thing that works well. Do not add features, refactors, or abstractions beyond what this spec requires. Pause only for the gates in Section 7, the destructive actions in Section 6, or input only I can provide.

Keep a `docs/LESSONS.md`: one lesson per entry, one-line summary on top, record corrections and confirmed approaches with why they mattered. Update rather than duplicate. Delete what turns out wrong.

## 10. Final summary format

Lead with the outcome. First sentence answers "what happened." Then the measurements. Then what changes what I would do next. Complete sentences, no shorthand.

## 11. Project inputs

- App name: **Kite** (placeholder; I may rename before Phase 0)
- Bundle ID: `io.github.<my-handle>.kite` — replace `<my-handle>` with my GitHub username
- Signing: **ad-hoc**. No Apple Developer account. Set `CODE_SIGN_IDENTITY: "-"`, `CODE_SIGN_STYLE: Automatic`, remove `DEVELOPMENT_TEAM` and `PROVISIONING_PROFILE_SPECIFIER`. No notarization.
- Sparkle EdDSA key: generate locally with Sparkle's `generate_keys` tool during Phase 0; paste the public key into `project.yml` and store the private key in my login keychain
- Appcast URL: `https://<my-handle>.github.io/kite/appcast.xml` (enable GitHub Pages on the fork in Phase 0)
- macOS version: latest (≥ 26). All WebKit APIs in Section 3 are available; still guard with `#available` so the minimum stays 15.0.
- Extensions to test first: **Bitwarden** and **Dark Reader** (standard web extensions). Do not test AdGuard's Safari extension; ad blocking is already built in via SafariConverterLib.
- Default search engine: **Google**
- UI: I will redesign it later. Do not spend Phase 1–2 effort on visual design; keep Ora's UI working as is.

## 12. Kickoff prompt for Claude Code

Paste this to start. Recommended effort: **xhigh** for Phases 1 and 2, **high** for Phase 0 and 3.

```
Read @BROWSER_SPEC.md fully. It is the brief for this whole project.

Start Phase 0, then continue directly into Phase 1 and stop at the Phase 1 gate.

Intent: Section 1. Locked decisions: Section 2. Sources and what to port: Section 3.
Feature list: Section 4. Measurable targets: Section 5. Boundaries: Section 6.
The inputs in Section 11 are filled in.

You are operating autonomously until the Phase 1 gate. I am not watching and cannot
answer questions mid-task. For reversible actions that follow from the spec, proceed
without asking. Before ending your turn, check your last paragraph: if it is a plan,
a question, or a promise about work you have not done, do that work now with tool
calls. End only at the gate or when blocked on input only I can provide.

Verify as Section 8 says. Report as Section 10 says.
```

If Claude Code stops with a statement of intent instead of acting, reply `continue`.
