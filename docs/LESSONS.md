# Lessons

One lesson per entry. One-line summary on top. Newest first.

---

## Ora already had profiles and tab suspension — the spec anticipated this, and it halves Phase 2

**Summary:** Before porting anything from Vane, check what Ora already does. Two of the three headline Phase 2 features turned out to be partly built.

`BrowserEngineProfile.swift` already wraps `WKWebsiteDataStore(forIdentifier:)`, and `BrowserEngine.makeProfile` is called with `container.id` — the id of a Space. So Ora's Spaces are already per-identifier WebKit profiles with real on-disk separation, and private windows already use `.nonPersistent()`. Porting Vane's `Profiles.swift` would have replaced working code with equivalent code.

Likewise `TabManager.swift:485` already destroys the web view of tabs that are not `isAlive`, correctly exempting the active tab, media-playing tabs, and pinned tabs. What it does not do is save `WKWebView.interactionState` first, so restoring reloads the URL from scratch and loses scroll position and back/forward history. That single gap — not the whole feature — is what Vane's `Engine.swift` is needed for.

Spec Section 6 said exactly this would happen: *"If you find that Ora already has profiles or tab sleeping, report it and adapt rather than replacing it."*

**Why it matters:** the instruction to port from a reference implementation is not the same as an instruction to port wholesale. Read the host code first; the delta is usually much smaller than the feature name suggests.

---

## A measurement that disagrees with itself by 10× is measuring the wrong thing

**Summary:** Cold launch first read as `TIMEOUT` then 3.2 s, and is actually ~343 ms. The tool was filtering for on-screen windows; the window exists before it is presented.

`CGWindowListCopyWindowInfo` with `.optionOnScreenOnly` returned nothing matching, because the app was launched from automation, never came to the foreground, and its main window stayed off-screen. Switching to `.optionAll` gave a stable 312–390 ms across five runs.

The lesson is not "use `.optionAll`". It is that the first number was absurd — a 3.2 s launch for a SwiftUI shell — and absurdity is a signal to go and look at what the tool is actually counting, not to write the number down. Dumping every window the process owned (size, layer, on-screen flag) took two minutes and explained it immediately.

The residual honesty cost is recorded in `docs/MEASUREMENTS.md`: the fixed number measures *window creation*, which is a floor for "cold launch to usable window", not the same thing. The spec's metric still needs a human looking at a screen.

The same class of error bit the memory numbers twice: once measuring a profile whose "blank tab" was a loaded Google search results page, and once attributing WebKit helper processes by a PID diff that silently found none.

**Why it matters:** Section 5 says "measured, not felt", and Section 8 says only report what a tool result supports. A tool result you have not sanity-checked is not evidence.

---

## Ad-hoc signing and the hardened runtime cannot both hold without disabling library validation

**Summary:** An ad-hoc signed app with the hardened runtime on cannot load its own embedded frameworks, because library validation compares Team IDs and an ad-hoc signature has none.

Slate is ad-hoc signed (`CODE_SIGN_IDENTITY: "-"`, no `DEVELOPMENT_TEAM`) per the spec. With `ENABLE_HARDENED_RUNTIME: YES` on Release, the first launch died instantly:

```
dyld: Library not loaded: @rpath/Sparkle.framework/Versions/B/Sparkle
  Reason: ... not valid for use in process:
  mapping process and mapped file (non-platform) have different Team IDs
```

Both the app and `Sparkle.framework` were in fact ad-hoc signed — `codesign -dv` reported `TeamIdentifier=not set` for each. The failure is not a mismatch between two different teams; it is that library validation needs a Team ID to match against, and "no team" never satisfies it. Two ad-hoc signatures cannot validate each other.

Three ways out, and why the chosen one won:

1. **`com.apple.security.cs.disable-library-validation`** — keeps the rest of the hardened runtime (no `DYLD_*` injection, no unsigned executable memory outside the entitled JIT region) and gives up only library validation. **Chosen.** See the next entry for the trap that came with it.
2. `ENABLE_HARDENED_RUNTIME: NO` — gives up all of the above, not just library validation. Strictly worse.
3. Link Sparkle statically — not practical; Sparkle ships as a framework with XPC services that the sandboxed installer path requires.

Worth knowing: Ora's own unused `ora-debug.entitlements` already carried `disable-library-validation`, so upstream hit the same wall on its debug path.

**Why it matters:** this is a permanent consequence of having no Apple Developer account, not a one-off. Any future embedded framework will need the same entitlement, and the security trade-off is real — the process will load any validly-signed library, not just ours.

---

## `CODE_SIGN_STYLE: Automatic` with an ad-hoc identity silently ships `get-task-allow` in Release

**Summary:** Xcode decided the Release build was not a distribution build and injected the debug entitlement that lets any process read the browser's memory. Nothing in the build log said so.

Spec Section 11 mandates `CODE_SIGN_STYLE: Automatic` and `CODE_SIGN_IDENTITY: "-"`. That pairing makes Xcode treat the configuration as non-distribution, so `CODE_SIGN_INJECT_BASE_ENTITLEMENTS` (which defaults to `YES`) adds `com.apple.security.get-task-allow` to the signed entitlements. Ora never hit this because its Release used `Manual` + `Developer ID Application`.

Verified in the built artifact, not inferred:

```
$ codesign -d --entitlements :- .../Release/Slate.app | grep get-task-allow
<key>com.apple.security.get-task-allow</key><true/>
```

`get-task-allow` permits `task_for_pid` on the process — any code running as the same user can attach and read memory: cookies, session tokens, anything decrypted in the address space. Combined with the `disable-library-validation` above, two of the hardened runtime's three main protections were gone from the shipped app while the project file still said `ENABLE_HARDENED_RUNTIME: YES`.

Fix: `CODE_SIGN_INJECT_BASE_ENTITLEMENTS: NO` on Release only. Re-verified after rebuild — the key is gone, `Signature=adhoc` and `flags=0x10002(adhoc,runtime)` are unchanged, and the app still launches.

**Why it matters, twice over.** First, the entitlements that end up in the binary are not the entitlements you wrote in `project.yml`; the only way to know is to ask `codesign` about the built product. Second, I had already written the previous lesson claiming the hardened runtime still prevented ptrace attach — a confident, checkable, and false claim. A fresh-context review caught it. Check the artifact, not the config, and be suspicious of security claims you did not verify against a tool result.

---

## SwiftData does not create intermediate directories for its store URL

**Summary:** Pointing a `ModelConfiguration` at a path whose parent directory does not exist fails at open time; SwiftData creates the store file but not the folders above it.

On a wiped sandbox container, the Release build emitted 307 `CoreData: error` lines on launch, including the misleading `Sandbox access to file-write-create denied`. The container was the app's own, so sandboxing was not actually the problem — `Data/Library/Application Support/Slate/` simply did not exist yet.

The app appeared to work anyway, which is the interesting part. `ContentBlockerArtifactStore.init` calls `createDirectory(withIntermediateDirectories: true)` on the same `Application Support/Slate` folder, so whether the database opened depended on whether the content blocker happened to be constructed before SwiftData. First-launch persistence was resting on start-up ordering.

Fix: `ModelConfiguration.databaseURL(in:)` creates the directory before handing the URL to SwiftData, and takes the support directory as a parameter so it can be tested against a temp dir rather than a real container. Verified by wiping `~/Library/Containers/io.github.imsumitkumar.slate/Data` and relaunching: 307 error lines → 0.

**Why it matters:** this was inherited from Ora and would hit every fresh install. It also means "it runs on my machine" is not evidence of a working first launch — the container has to be wiped to test that path.

---

## The fork could not build at all before the signing was changed

**Summary:** Ora's committed `project.yml` pins a `DEVELOPMENT_TEAM` and a provisioning profile, so a clean clone fails to build for anyone who is not Ora.

```
error: No profile for team '3Y566D2A4G' matching 'ora-profile-working' found
```

There was therefore no "before" build to compare warnings against — the warning baseline could only be established after the Phase 0 signing change. Recorded so that the single pre-existing warning in `SpacesSettingsView.swift:498` is not mistaken for something this work introduced.

**Why it matters:** when a baseline cannot be taken, say so rather than implying the comparison was made.
