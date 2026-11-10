// Main program of each "Claude N.app" launcher. It runs the bundled `launch`
// script, then quits.
//
// A bare shell script as the app's program can exit before macOS has finished
// opening it, and macOS then reports "The application can't be opened" (-609).
// Running as a real app until the script is done avoids that.
import AppKit

final class Launcher: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        let script = Bundle.main.bundleURL.appendingPathComponent("Contents/MacOS/launch")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = [script.path]
        task.terminationHandler = { _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
        do { try task.run() } catch { NSApp.terminate(nil) }
    }

    // A second click while this is still running needs nothing extra.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool { false }
}

let delegate = Launcher()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
