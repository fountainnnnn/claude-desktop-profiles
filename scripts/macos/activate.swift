// Brings the Claude process with the given PID to the front and asks it to
// reopen its window (what a normal Dock click does), in case the window was
// closed with the red button while the app kept running.
import AppKit

guard CommandLine.arguments.count > 1, let pid = Int32(CommandLine.arguments[1]),
      let app = NSRunningApplication(processIdentifier: pid) else { exit(1) }

let reopen = NSAppleEventDescriptor(
    eventClass: AEEventClass(kCoreEventClass), eventID: AEEventID(kAEReopenApplication),
    targetDescriptor: NSAppleEventDescriptor(processIdentifier: pid),
    returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
let err = AESendMessage(reopen.aeDesc, nil, AESendMode(kAENoReply), kAEDefaultTimeout)
if err != noErr {
    // Usually -1743: the user declined "control Claude". Focusing still works.
    FileHandle.standardError.write("reopen event failed: \(err)\n".data(using: .utf8)!)
}
app.activate(options: [.activateAllWindows])
