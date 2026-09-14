# Lessons

One lesson per entry. One-line summary on top. Newest first.

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

1. **`com.apple.security.cs.disable-library-validation`** — keeps the rest of the hardened runtime (no `DYLD_*` injection, no ptrace attach, no unsigned executable memory outside the entitled JIT region) and gives up only library validation. **Chosen.**
2. `ENABLE_HARDENED_RUNTIME: NO` — gives up all of the above, not just library validation. Strictly worse.
3. Link Sparkle statically — not practical; Sparkle ships as a framework with XPC services that the sandboxed installer path requires.

Worth knowing: Ora's own unused `ora-debug.entitlements` already carried `disable-library-validation`, so upstream hit the same wall on its debug path.

**Why it matters:** this is a permanent consequence of having no Apple Developer account, not a one-off. Any future embedded framework will need the same entitlement, and the security trade-off is real — the process will load any validly-signed library, not just ours.

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
