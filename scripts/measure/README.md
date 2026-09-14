# Measurement harness

Reproduces the `BROWSER_SPEC.md` Section 5 numbers recorded in `docs/MEASUREMENTS.md`.
Nothing here is built into the app.

```bash
APP="$(xcodebuild -project Slate.xcodeproj -scheme Slate -configuration Release \
        -showBuildSettings 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR/{print $2}')/Slate.app"

scripts/measure/footprint.sh "$APP" 30     # cold launch ms + phys_footprint, app and WebKit helpers
scripts/measure/idle-cpu.sh  "$APP" 10     # idle CPU% over 10 minutes
```

`footprint.sh` compiles `launchtime.swift` itself on first run (into `$TMPDIR`, or wherever
`SLATE_LAUNCH_PROBE` points) and rebuilds it whenever the source is newer, so there is no
separate build step. To run the launch probe alone:

```bash
swiftc -O scripts/measure/launchtime.swift -o /tmp/slate-launchtime
/tmp/slate-launchtime "$APP"
```

## What the numbers mean

`footprint.sh` reports **`phys_footprint`**, which is what Activity Monitor shows in its
Memory column — not RSS, which double-counts shared pages. WebKit's helper processes are
children of `launchd` rather than of the app and carry no identifying arguments, so they
are attributed by diffing a PID snapshot taken before launch against one taken after.
That attribution is only sound if no other WebKit-based app starts during the run.

`launchtime.swift` measures from `NSWorkspace.openApplication` to the first window the
app owns that is at least 450x340, using the CoreGraphics window list (no accessibility
permission needed). It counts **off-screen windows too**, because the window is created
before it is presented. It therefore measures *window creation*, which is a floor for
"cold launch to usable window", not the same thing. Treat it as a lower bound, and check
the real thing by watching the screen.

`idle-cpu.sh` is a proxy for the Activity Monitor "Energy Impact" check, which needs a GUI
session. CPU is one input to Energy Impact; wakeups, GPU and network are not captured.

## Measure from a wiped profile when you mean first launch

```bash
pkill -x Slate; rm -rf ~/Library/Containers/io.github.imsumitkumar.slate/Data
```

The container directory itself cannot be removed (SIP owns its metadata); removing
`Data` is enough and is what the recorded first-launch numbers used.
