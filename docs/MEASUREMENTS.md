# Measurements

Every metric, every commit. Targets are from `BROWSER_SPEC.md` Section 5.
Reproduce with `scripts/measure/` — see that directory's README for what each number means.

---

## 2026-09-14 — commit `bf7dfa4` — Phase 1 baseline

Release build, macOS 26.5.1, Xcode 26.6, Apple Silicon. This is the **baseline before any
feature cuts**: Phase 0 changed identity, signing and the update feed, nothing else.

### Summary against targets

| Metric | Target | Measured | Verdict |
|---|---|---|---|
| App bundle size | ≤ 15 MB | **35.4 MB** | ✗ 2.4× over |
| Cold launch to first window | ≤ 500 ms | **582 ms** median (18 runs) | ✗ 0/18 runs met it |
| Idle memory, app only, no page | — | **41 MB** | context for the next row |
| Idle memory, 1 loaded tab | ≤ 80 MB | **188 MB** | ✗ 2.4× over |
| Idle memory, 12 sleeping tabs | ≤ 150 MB | **not measurable** | tab sleeping does not preserve state yet |
| Energy, idle | "Low" for 10 min | **0.00% CPU** over 90 s (proxy) | ~ proxy clean, not the real check |
| Ad blocking | 0 ad requests on 3 sites | **not measured** | no rule lists had compiled |
| Profile isolation | login in A absent in B | **not measured** | no test exists |
| DRM | Netflix plays | **not measured** | Vane's `drmcheck` not ported |

**One of eight targets is met** (idle CPU, and only as a proxy). Four could not be measured
because the feature does not exist yet, which is what Phase 2 is for. The three misses are all
real and all explained below.

### Bundle size — 35.4 MB against a 15 MB target

| Component | Size | Note |
|---|---|---|
| `Contents/MacOS/Slate` | 28.0 MB | **fat binary: 13.6 MB arm64 + 14.3 MB x86_64** |
| `Contents/Resources/Assets.car` | 3.6 MB | compiled asset catalog |
| `Contents/Frameworks/Sparkle.framework` | 2.7 MB | also fat |
| `Resources/emoji-set.json` | 0.57 MB | emoji picker, on the Cut list |
| `Resources/swift-psl_PublicSuffixList` | 0.5 MB | transitive, via SafariConverterLib |

The x86_64 slice is the single largest line item in the whole app — larger than everything
on the Phase 2 Cut list put together (~4 MB). `ARCHS: arm64` alone would land the bundle
near **20 MB**. See `docs/AUDIT.md` §1.3; this is a decision for the gate, not mine to make.

### Cold launch — 582 ms median, over the 500 ms target

18 samples across three runs, app quit between each:

| Condition | n | min | median | max |
|---|---|---|---|---|
| Warm profile, consecutive | 8 | 574 | 582 | 628 |
| Wiped profile each time | 5 | 564 | 593 | 602 |
| Warm profile, repeat | 5 | 551 | 585 | 598 |
| **All** | **18** | **551** | **582** | **628** |

**0 of 18 runs met the 500 ms target.** Whether the profile is wiped or warm makes no
meaningful difference, so session restore is not the cost.

**I initially recorded 343 ms here and that was wrong.** An earlier set of five samples read
312–390 ms, and I wrote them up as passing. They are not reproducible: every subsequent run,
under conditions I controlled and repeated, lands in the 550–630 ms band. I cannot account
for the earlier numbers, so the reproducible ones stand and the verdict flips from pass to
fail. Re-run `scripts/measure/footprint.sh` yourself before accepting either figure.

**Caveat, and it matters.** This measures from `NSWorkspace.openApplication` to the first
window the app *creates* (≥ 450×340, via the CoreGraphics window list, counting off-screen
windows). It is a floor, not "cold launch to usable window" as the spec defines it — the
real number is worse, not better.

My first attempt counted only on-screen windows and reported `TIMEOUT` / 3.2 s. The app's
windows were being created but not presented on screen in this automation context — the app
never came to the foreground (`isActive=false`), and the only on-screen window was a
182×170 panel. **Whether Slate presents a proper 1440×900 window on launch in a normal
desktop session is unverified.** Run `scripts/measure/launchtime.swift` from your own
session, and look at the screen while you do.

### Memory — 188 MB with one tab, against an 80 MB target

`phys_footprint`, the same figure Activity Monitor's Memory column shows.

| State | App | WebContent | GPU | Networking | **Total** |
|---|---|---|---|---|---|
| Fresh profile, no page loaded | 41 MB | — | — | — | **41 MB** |
| 1 restored tab (Google search), run A | 60 MB | 165 | 88 | 11 | **324 MB** |
| 1 restored tab (Google search), run B | 61 MB | 101 | 16 | 10 | **188 MB** |

Read these carefully:

- **41 MB is the app's own floor** with no web content at all. That part is healthy and
  leaves real headroom under the 80 MB target.
- **Neither loaded-tab row is "1 blank tab."** Both restored a live Google search results
  page, which is a heavy, script-driven document — not the blank tab the spec measures. The
  honest reading is that Slate's shell is cheap and WebKit's per-page cost dominates. A true
  blank-tab number still needs to be taken.
- **Run A vs run B is 136 MB of variance on identical inputs**, mostly in the GPU process
  (88 vs 16 MB). One sample of each is not enough to characterise this. Do not treat 188 MB
  as a stable figure.

I could not produce a controlled *N*-tab series: `open -a Slate <url>` did **not** create a
tab (verified — `ZTAB` stayed at 0 rows afterwards). That may be an artefact of the app not
being frontmost, or it may be a real defect in the `http`/`https` URL-event handling that
Section 4 lists under Keep. **Worth checking by hand** — it is the same code path as "set as
default browser".

### Energy — proxy only, but the proxy is clean

The spec asks for "Low" in Activity Monitor's Energy tab over 10 minutes, which needs a GUI
session. The proxy I can measure is CPU:

| Sample | Result |
|---|---|
| Idle CPU, 18 samples over 90 s, 1 restored tab, window unfocused | **mean 0.000%, max 0.0%** |

That is genuinely idle — no polling loop burning CPU in the background, which is the main
thing that would push Energy Impact off "Low". CPU is only one input to Energy Impact
though; wakeups, GPU and network all count, and none of those are captured here. **Re-run
the real 10-minute Activity Monitor check in your own session before trusting this.**

One observation worth recording: the app process measured **41 MB fresh, but 124 MB after
roughly twelve minutes** of sitting idle with a single restored tab (`phys_footprint_peak`
147 MB). That is the app process alone, not WebKit's helpers. A 3× growth while doing
nothing is the kind of thing that turns into a leak, and it deserves a proper look in
Phase 2 rather than a guess here — one sample is not a trend.

### Ad blocking — not measured

`~/Library/.../Application Support/Slate/ContentBlockers/` was **empty** after several
launches: no filter list had been downloaded or compiled. So there was nothing to test
blocking against, and the "0 requests to known ad domains" check is meaningless until lists
actually compile. Whether that is a first-run scheduling delay or a defect is itself worth
establishing in Phase 2 — content blocking is a Keep feature and the headline reason the
browser exists.

### Build health

| Check | Result |
|---|---|
| `xcodebuild build -scheme Slate -configuration Release` | SUCCEEDED |
| Warnings introduced | **0** |
| Pre-existing warnings | 1 — `SpacesSettingsView.swift:498`, unused result of `run(resultType:body:)` |
| `xcodebuild test -scheme Slate` | SUCCEEDED — 32 tests, 3 suites |

No warning baseline existed before this commit: Ora's committed `project.yml` pins a
`DEVELOPMENT_TEAM` and provisioning profile, so the fork could not build for anyone but
Ora. The test target also lacked `GENERATE_INFOPLIST_FILE` and failed to code-sign, so the
suite could not have been run upstream either. Both fixed in Phase 0.
