// activate <pid>         Brings that Claude process to the front and asks it to
//                        reopen its window (what a normal Dock click does), in
//                        case the window was closed with the red button.
// activate --quit <pid>  Asks that Claude process to quit normally, as Cmd+Q
//                        would. Used by update-helper.sh.
import AppKit

var args = Array(CommandLine.arguments.dropFirst())
let quit = args.first == "--quit"
if quit { args.removeFirst() }
guard let arg = args.first, let pid = Int32(arg),
      let app = NSRunningApplication(processIdentifier: pid) else { exit(1) }

if quit { exit(app.terminate() ? 0 : 1) }

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
