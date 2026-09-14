# CLAUDE.md

Read `BROWSER_SPEC.md` first. It is the brief. This file is the working agreement.

## What this is
A personal, open-source (GPL-3.0) macOS browser forked from Ora. WebKit only. Goal: minimal memory, minimal energy, fast, Chrome-style profiles, nothing I do not use.

## Definition of done for any feature or fix
A change is done only when all of these are true and you can point to the evidence in this session:
1. Tests exist for the new behaviour and they pass. If behaviour cannot be unit-tested, a UI test or a scripted manual check exists and was run.
2. The full test suite passes. Not just the new tests.
3. `xcodebuild build -configuration Release` passes with no new warnings.
4. The memory and launch numbers in `BROWSER_SPEC.md` Section 5 were re-measured and written to `docs/MEASUREMENTS.md` with the commit hash. If a number got worse, say so and why.
5. A fresh-context subagent reviewed the diff against the spec and reported no blocking issues. Fix what it finds before reporting.
6. The change is on its own branch with a clear commit message. Nothing lands on `main` untested.

"Done" without these is not done. Say "not yet verified" instead.

## Quality rules
- Time is not a constraint. Correctness is. Take the long path when the short path is unverified.
- Prefer deleting code to adding it. Every feature must earn its RAM.
- No new dependencies without asking and stating the memory cost.
- No Electron, Tauri, CEF, or Chromium under any name. Ever.
- Do not refactor for style. Cut and add only.
- Keep macOS minimum at 15.0. Guard newer WebKit APIs with `#available`.
- Port from Vane (MIT) with a header comment and an entry in `THIRD_PARTY_NOTICES.md`.

## Project facts
- Build: `./scripts/setup.sh` then `xcodegen` then `xcodebuild -scheme Slate`.
- Signing: ad-hoc. No Apple Developer account. Never add a team ID.
- Sparkle feed and key are mine, not Ora's. Never point at Ora's appcast.
- Upstream Ora is a git remote named `upstream`. Do not merge from it without asking.

## Memory files
- `docs/AUDIT.md` — Phase 1 output. Module map: Keep / Cut / Missing.
- `docs/MEASUREMENTS.md` — every metric, every commit.
- `docs/LESSONS.md` — one lesson per entry, one-line summary on top. Record corrections and confirmed approaches with why. Update rather than duplicate. Delete what turns out wrong.

## When to stop and ask
- The two gates in `BROWSER_SPEC.md` Section 7.
- Deleting a top-level module, changing `project.yml` dependencies, rewriting git history.
- Any choice that changes a Section 2 decision.
Otherwise act.
