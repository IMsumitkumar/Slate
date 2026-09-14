# Phase 1 Audit — Ora module map against the Slate spec

Audited at commit `bf7dfa4` (Phase 0 complete). Source tree: 171 Swift files, 25,605 LOC.
Classified against `BROWSER_SPEC.md` Section 4.

**This file is the Phase 1 gate. Nothing on the Cut list has been deleted.**

---

## 1. Headline findings

Four things change what Phase 2 should be, and are worth reading before the tables.

### 1.1 Ora already has profile data isolation. Do not port Vane's `Profiles.swift`.

`ora/Core/BrowserEngine/BrowserEngineProfile.swift` already wraps `WKWebsiteDataStore(forIdentifier:)`, and `BrowserEngine.makeProfile(identifier:isPrivate:)` caches one profile per identifier. The identifier passed in is `container.id` — a **Space**. So every Ora Space is already a real, separately-stored WebKit profile, and private windows already use `.nonPersistent()`.

Spec Section 6 says: *"If you find that Ora already has profiles or tab sleeping, report it and adapt rather than replacing it."* This is that case. Phase 2's profiles work shrinks from "port Vane's profile system" to:

- Prove isolation actually holds, with a test (there is none today).
- Tidy up Space deletion. `TabManager.deleteContainer` (line 182) *does* call `PrivacyService.clearAllWebsiteData(for:)`, which calls `removeData(ofTypes: allWebsiteDataTypes(), modifiedSince: .distantPast)` — so **the website data is genuinely cleared**. What it never calls is `WKWebsiteDataStore.remove(forIdentifier:)`, which is absent from the whole tree. The store's own on-disk container is therefore orphaned rather than removed. This is a small leak of empty directories, not a privacy hole — worth fixing, but do not treat it as urgent.
- Decide whether "Space" is renamed "Profile" in the UI, or left alone (Section 11 defers UI).

### 1.2 Ora already has tab suspension, but it throws away page state.

`TabManager.swift:485–497` walks every tab and calls `tab.destroyWebView()` when the tab is not `isAlive`, correctly skipping the active tab, media-playing tabs, and non-normal (pinned/fav) tabs. That is most of the spec's tab-sleeping requirement, already working.

What is missing is the part that makes it feel instant:

| Spec wants | Ora does |
|---|---|
| Save `WKWebView.interactionState` before dropping the view | Nothing — `interactionState` appears nowhere in the tree |
| Restore scroll position and back/forward list on click | Reloads the bare `url` from scratch |
| Default 10 minutes | Minimum selectable is **1 hour**; options are 1h/6h/12h/1d/2d/Never |
| Release under memory pressure | No `DISPATCH_SOURCE_TYPE_MEMORYPRESSURE` handler anywhere |

So Phase 2 adapts rather than replaces: add `interactionState` save/restore, add a 10-minute option and make it the default, add a memory-pressure hook. Vane's `Engine.swift` is the reference for the first and third.

### 1.3 The binary is universal. Dropping Intel saves ~14 MB for nothing.

`Contents/MacOS/Slate` is a fat Mach-O: **13.6 MB arm64 + 14.3 MB x86_64**. Sparkle.framework is fat too. The spec's whole premise is Apple Silicon ("fastest on Apple Silicon", "unified memory"), and this is a personal browser for one Apple Silicon Mac.

Setting `ARCHS: arm64` takes the bundle from **35.4 MB to roughly 20 MB** before a single feature is cut — the largest single move available, at zero feature cost.

I have **not** made this change. It is the one item here that changes who can run the app, so it belongs to you, not me. See §5.

### 1.4 Autoplay is currently allowed, not blocked.

Section 4 Keep says "Autoplay blocked by default". `BrowserEngine.swift:28` sets `mediaPlaybackRequiresUserAction: false`, which maps to `mediaTypesRequiringUserActionForPlayback = []`. The plumbing is right, the default is inverted. One-line fix in Phase 2.

---

## 2. Keep — exists and works

Memory column is the estimated resident cost of the feature's own code and state, not the pages it renders. Anything under ~0.5 MB is noise and marked ~0; these are listed to confirm they were looked at, not because the number matters.

| Module | LOC | Spec line | Memory | Notes |
|---|---|---|---|---|
| `Core/BrowserEngine` | 1,382 | Engine | core | `WKWebView` wrapper, profiles, pages, downloads. The load-bearing module. |
| `Features/Tabs` | 2,593 | Tabs: open/close/reorder/pin/drag | ~0 + per-tab | Drag between windows present (`DragAndDrop/`). Suspension: see §1.2. |
| `Features/Privacy` (AdBlock) | 1,728 | Content blocking | ~2–4 MB compiled rules | SafariConverterLib → `WKContentRuleListStore`. Auto-refresh scheduler exists (`AdBlockService.swift:324`); confirm cadence is weekly. Per-site toggle present. |
| `Features/Downloads` | 1,278 | Downloads, show in Finder | ~0 | |
| `Features/History` | 142 | History + search + clear | ~0 | Thin; backed by SwiftData. |
| `Features/FindInPage` | 556 | Find in page | ~0 | |
| `Features/Sidebar` | 1,425 | Tab UI | ~0 | This *is* the tab strip. Not the "sidebar panels" Section 4 cuts. |
| `Features/Search` | 365 | Address bar search | ~0 | Minus AI engines — see Cut. |
| `Core/Services/App/UpdateService` | — | Sparkle | ~0 | Now points at my appcast. |
| `Core/Constants/Theme.swift` | 573 (all Constants) | — | ~0 | **Design tokens, not a theme switcher.** Used by 44 files. Section 4's "themes" cut does not apply; removing this would be a rewrite of every view, which Section 6 forbids. Keep. |
| `Core/Platform`, `Core/Domain`, `Core/Extensions`, `Core/Utilities` | 1,514 | — | ~0 | Infrastructure. |
| `Shared/Components` | 2,976 | — | ~0 | Buttons, inputs, toasts, dialogs, icons. Some dead weight once cuts land (see §4). |
| Private window | — | Private window | ~0 | `WKWebsiteDataStore.nonPersistent()`, already correct. |
| Dark mode | — | Follows system | ~0 | `AppearanceManager`. |

---

## 3. Cut — remove in v1

Listed with what actually has to happen, because several are entangled rather than free-standing directories.

| Module | LOC | Why | Est. saving | Difficulty |
|---|---|---|---|---|
| `Features/Passwords` | 1,844 | Section 4: "built-in password manager" is Not in v1 | ~1.5 MB binary; removes a keychain surface | **Entangled.** Referenced from `Tab.swift` (`passwordCoordinator`), `SettingsStore`, `PasswordsSettingsView`, the `passwordManager` script handler, and `Resources/WebScripts/password-manager.js`. Cut the injected script too — it currently runs on every page load. |
| `Shared/Layout/SplitView` + `BrowserSplitView` | 1,501 + 92 | Section 4: split view | ~0.8 MB | Vendored MIT code; also used by `SettingsContentView.swift` (101 LOC), which needs a plain layout instead. Remove the `THIRD_PARTY_NOTICES.md` entry with it. |
| `Features/Launcher` | 1,096 | Section 4: "quick launcher extras" | ~0.6 MB | **Careful.** The Keep list wants "suggestions from history and bookmarks" in the address bar. Some of `LauncherViewModel` is that suggestion engine. Cut the overlay and the AI suggestions; keep or re-home the suggestion matching. Do not delete blind. |
| `Features/Player` | 461 | Section 4: picture-in-picture is Not in v1 | ~0.3 MB | `MediaController` also feeds the "tab is playing media" flag that tab suspension depends on. **Keep that signal**, cut the global player UI and the PiP trigger. |
| `Shared/EmojiPicker` | 232 + 571 KB JSON | Section 4: emoji picker | ~0.6 MB bundle + parse cost | The 571 KB `emoji-set.json` (584,224 bytes) is a bundled resource and the third-largest file in the app. Used for Space icons — needs a replacement icon story first. |
| `Features/Importer` | 375 | Not on the Keep list | ~0.2 MB | Free-standing; imports from other browsers. Easiest cut on this list. |
| AI search engines | ~60 | Section 4: no AI | ~0 | ChatGPT/Claude/Gemini/Grok/Perplexity entries in `SearchEngineService.swift` plus `createAISuggestion` in `LauncherViewModel`. Not an AI assistant — just search targets. Also drop their capsule logo assets. |
| `.cursor-rules.yaml` | — | Tooling for an editor this project does not use; references `oraApp.swift`, which does not exist | ~0 | |
| `ROADMAP.md` | — | Superseded by `BROWSER_SPEC.md`; already annotated to say so | ~0 | |
| `ora/Info/ora-debug.entitlements` | — | Dead: referenced by nothing after Phase 0 | ~0 | |
| `oraUITests/` | — | **Not in `project.yml` at all** — it has never been built or run by anything | ~0 | Either wire it up or delete it. It currently gives false confidence. |

**Estimated total from the Cut list: ~4 MB of binary**, versus ~14 MB from the architecture change alone. The cuts are worth doing for the RAM, the attack surface, and the maintenance load — but they are not what gets the bundle under 15 MB. Section 1.3 is.

---

## 4. Missing — on the Keep list, does not exist

| Feature | Spec line | Status | Est. cost |
|---|---|---|---|
| **Bookmarks with folders** | Keep | **Entirely absent.** No bookmark code, model, or UI anywhere; the only tree-wide match for "bookmark" is a word inside `emoji-set.json`. `Folder.swift` is a *tab* folder, not a bookmark folder. | New SwiftData model + UI. Largest missing item. |
| **Extensions via `WKWebExtension`** | Keep | Absent. Zero matches. | Port Vane's `Extensions.swift`; one `WKWebExtensionController` per profile. Guard with `#available(macOS 15.4, *)`. |
| **`!bang` search prefixes** | Keep | **Partial.** `SearchEngineService` has alias arrays (`["google","goo","g"]`, `["ddg","duck"]`) that work as prefixes, but not the literal `!` syntax. | Small — decide whether aliases satisfy this or add `!`. |
| **Tab sleeping: state-preserving** | Keep | Partial — see §1.2. | Medium. |
| **10-minute sleep default** | Keep | Absent; minimum option is 1 hour. | Trivial. |
| **Memory-pressure release** | Keep (implied by Section 5) | Absent. | Small; `DispatchSource` memory-pressure handler. |
| **Autoplay blocked by default** | Keep | Inverted — see §1.4. | Trivial. |
| **Profile delete removes the data store** | Keep | **Partial.** Deleting a Space clears all website data, but never calls `WKWebsiteDataStore.remove(forIdentifier:)` (absent tree-wide), so the empty store container is orphaned. | Small; tidiness, not privacy. |
| **WebAuthn / passkey sign-in** | implied by Keep (daily-driver replacement for Chrome) | **Removed in Phase 0 and not recoverable.** `com.apple.developer.web-browser.public-key-credential` is an Apple-granted entitlement requiring a provisioning profile, which ad-hoc signing cannot have. Passkey logins in `WKWebView` will not work. | Blocked on having an Apple Developer account. |
| **Crash recovery** | Keep | No `webViewWebContentProcessDidTerminate` handler, no running-marker file, no periodic session autosave. | Port Vane's `Crash.swift`. |
| **DRM / FairPlay check** | Section 5 metric | Absent. **But** `BrowserEngine.swift:20` already sets a Safari 26 user-agent, which is the precondition Vane's note calls out. | Port Vane's `DRMCheck.swift`. |
| **Profile isolation test** | Section 8 | No test exists. | Required by Section 8 regardless. |
| **Tab sleep/restore test** | Section 8 | No test exists. | Required by Section 8 regardless. |

---

## 5. Decisions I need from you at this gate

1. **Drop x86_64 (`ARCHS: arm64`)?** Saves ~14 MB — more than every feature cut combined. Cost: the app will not run on Intel Macs. My recommendation is yes; the spec is Apple-Silicon-premised throughout. Not done, awaiting your call.
2. **Approve the Cut list in §3 as written?** In particular the three entangled ones — Launcher (keep the suggestion engine), Player (keep the is-playing-media signal), Passwords (also remove the injected script).
3. **Accept losing passkeys?** Ad-hoc signing forced the removal of
   `com.apple.developer.web-browser.public-key-credential`, so WebAuthn/passkey sign-in will not
   work in Slate. There is no workaround without an Apple Developer account — the entitlement is
   granted by Apple, not self-asserted. If you use passkeys daily, this is the one thing in this
   audit that might change your mind about ad-hoc signing.
4. **`oraUITests/`: wire up or delete?** It is currently unbuilt dead weight.
5. **Rename Space → Profile in the UI?** They are already the same thing technically. Section 11 defers UI work, so my default is to leave the wording alone and revisit in Phase 3.
6. **Source directory names.** `ora/`, `oraTests/`, `oraUITests/` still carry Ora's name. I left them: Section 6 says cut and add only, and Section 11's replace-before-first-build list does not mention them. Say the word and it is one `git mv`.

---

## 6. Residual Ora identifiers (deliberately not renamed)

Phase 0 renamed everything user-visible plus every identifier that names Ora's infrastructure. These remain, by choice:

- **Type and file names**: `OraCommands`, `OraRoot`, `OraApp`, `OraBrowserScripts`, `OraInput`, `OraIcon`, `OraButton`, `ModelConfiguration.oraDatabase`. Renaming is pure style churn, which Section 6 forbids.
- **Page-injected names**: `window.__oraBridge`, `window.__oraMedia`, the `ora-sb-shield` element id, `data-ora-password-field-id`, and the `ora-`-prefixed spoofed device ids in `BrowserPrivacyService`. These are readable by any page, so they are a **fingerprinting** question, not a naming one — renaming them to `slate-` would be equally identifying. Worth addressing properly in Phase 2's privacy pass. The password-manager ones disappear with that cut.
- **SwiftData store name** `"OraData"` — the store's logical name, distinct from the file path (now `Slate/SlateData.sqlite`). Changing it risks a migration for no user-visible gain.

---

## 7. Build health at the gate

| Check | Result |
|---|---|
| `xcodebuild build -scheme Slate -configuration Release` | **SUCCEEDED** |
| Warnings introduced by Phase 0 | **0** |
| Pre-existing warnings | **1** — `SpacesSettingsView.swift:498`, unused result of `run(resultType:body:)` |
| `xcodebuild test -scheme Slate` | **SUCCEEDED**, 32 tests / 3 suites |
| Test count before Phase 0 | 28 — and the suite **could not run at all**: the test target had no `GENERATE_INFOPLIST_FILE`, so code signing failed. CI only ever linted. |
| Direct SPM dependencies | 4 (Sparkle, SafariConverterLib, FaviconFinder, Inject) — unchanged, as Section 6 requires |
| Transitive | 4 more: `swift-psl`, `Punycode`, `SwiftSoup`, `swift-argument-parser` |

`Inject` is debug-only hot reload. It is a dependency Section 4 has no use for, but removing it changes `project.yml` dependencies, which Section 6 says to ask about first. Flagging, not acting.
