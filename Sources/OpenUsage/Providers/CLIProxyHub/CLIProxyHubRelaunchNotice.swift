import AppKit
import Observation

/// The dashboard's "Hub Accounts Changed" notice. Hub cards are built once at launch from the cached
/// account list, so when the background sync saves a different set of accounts the cards stay as they
/// were until the app relaunches. Held in memory only: dismissing hides it for this launch.
@MainActor
@Observable
final class CLIProxyHubRelaunchNotice {
    private(set) var isPending = false
    /// Set when the relaunch helper could not start, so the card can ask the user to quit and reopen.
    private(set) var relaunchFailed = false

    func markChanged() {
        isPending = true
    }

    func dismiss() {
        isPending = false
    }

    /// Starts a fresh copy once this one has exited, then quits. Waiting on the PID matters:
    /// `SingleInstanceGuard` makes a copy that starts while an older one runs yield to it and quit.
    func relaunch(shell: URL = URL(fileURLWithPath: "/bin/sh")) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let bundle = Bundle.main
        // An unbundled build (`swift run`) has no app bundle to open, so it reruns its executable.
        let target = bundle.bundleIdentifier != nil ? bundle.bundlePath : (bundle.executablePath ?? "")
        let reopen = bundle.bundleIdentifier != nil ? #"/usr/bin/open "$1""# : #""$1" &"#
        let process = Process()
        process.executableURL = shell
        process.arguments = ["-c", "while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done; \(reopen)", "sh", target]
        do {
            try process.run()
        } catch {
            AppLog.error(.lifecycle, "OpenUsage could not relaunch itself: \(error.localizedDescription)")
            relaunchFailed = true
            return
        }
        NSApp.terminate(nil)
    }
}
