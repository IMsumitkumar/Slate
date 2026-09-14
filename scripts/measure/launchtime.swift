import AppKit
import CoreGraphics
import Foundation

// Measures cold launch: from spawning the app to the first on-screen window it
// owns. Uses the CoreGraphics window list, which needs no accessibility grant.

guard CommandLine.arguments.count >= 2 else { fatalError("usage: launchtime <app-bundle-path>") }
let appURL = URL(fileURLWithPath: CommandLine.arguments[1])
let appName = appURL.deletingPathExtension().lastPathComponent

func windowCount(forPID pid: pid_t) -> Int {
    let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
    guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return 0 }
    return list.filter { info in
        guard let owner = info[kCGWindowOwnerPID as String] as? pid_t, owner == pid else { return false }
        let bounds = info[kCGWindowBounds as String] as? [String: Any]
        let height = (bounds?["Height"] as? Double) ?? 0
        let width = (bounds?["Width"] as? Double) ?? 0
        // Ignore tiny helper/status windows; we want a real browser window.
        // The main WindowGroup has minWidth 500 / minHeight 360; the menu bar is 1920x30.
        return width >= 450 && height >= 340
    }.count
}

let config = NSWorkspace.OpenConfiguration()
config.activates = false
config.addsToRecentItems = false

let sem = DispatchSemaphore(value: 0)
var launchedPID: pid_t = 0
var launchError: Error?

let start = DispatchTime.now()
NSWorkspace.shared.openApplication(at: appURL, configuration: config) { app, error in
    launchedPID = app?.processIdentifier ?? 0
    launchError = error
    sem.signal()
}
sem.wait()

if let launchError { fatalError("launch failed: \(launchError)") }
guard launchedPID > 0 else { fatalError("no pid") }

var elapsedMS: Double = -1
let deadline = Date().addingTimeInterval(30)
while Date() < deadline {
    if windowCount(forPID: launchedPID) > 0 {
        elapsedMS = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000
        break
    }
    usleep(2000) // 2 ms
}

if elapsedMS < 0 {
    print("pid=\(launchedPID) result=TIMEOUT no window within 30s")
} else {
    print(String(format: "pid=%d window_ms=%.1f", launchedPID, elapsedMS))
}
