// SpotifyMediaKey: when macOS launches Apple Music because no app owns
// "Now Playing" (typically right after login, before Spotify has played
// anything), quit Music and send play/pause to Spotify instead.
// Hold Option while opening Music to let it launch normally.
import AppKit

let logURL = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Logs/SpotifyMediaKey.log")

func log(_ msg: String) {
    let line = "\(ISO8601DateFormatter().string(from: Date())) \(msg)\n"
    if let h = try? FileHandle(forWritingTo: logURL) {
        h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close()
    } else {
        try? line.write(to: logURL, atomically: true, encoding: .utf8)
    }
}

@discardableResult
func runScript(_ source: String) -> String? {
    var err: NSDictionary?
    let result = NSAppleScript(source: source)?.executeAndReturnError(&err)
    if let err = err { log("AppleScript error: \(err)"); return nil }
    return result?.stringValue
}

var lastHandled = Date.distantPast

final class Watcher: NSObject {
    @objc func appLaunched(_ note: Notification) {
        guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              app.bundleIdentifier == "com.apple.Music" else { return }
        if NSEvent.modifierFlags.contains(.option) {
            log("Music launched with Option held, leaving it alone")
            return
        }
        app.forceTerminate()
        if Date().timeIntervalSince(lastHandled) < 1.5 {
            log("Music launched again within debounce window, killed it")
            return
        }
        lastHandled = Date()
        log("Music launched (pid \(app.processIdentifier)), killed it, sending playpause to Spotify")
        runScript("tell application \"Spotify\" to playpause")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            log("Spotify player state now: \(runScript("tell application \"Spotify\" to get player state as string") ?? "?")")
        }
    }
}

let watcher = Watcher()
NSWorkspace.shared.notificationCenter.addObserver(
    watcher, selector: #selector(Watcher.appLaunched(_:)),
    name: NSWorkspace.didLaunchApplicationNotification, object: nil)

// Music may already have been spawned before we started; handle it too.
for app in NSWorkspace.shared.runningApplications where app.bundleIdentifier == "com.apple.Music" {
    log("Music already running at startup (pid \(app.processIdentifier)), leaving it")
}

// Touch Spotify once at startup so the Automation permission prompt appears
// now rather than on the first media-key press.
if !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty {
    log("startup: Spotify player state = \(runScript("tell application \"Spotify\" to get player state as string") ?? "?")")
}
log("SpotifyMediaKey started")

let nsapp = NSApplication.shared
nsapp.setActivationPolicy(.prohibited)
nsapp.run()
