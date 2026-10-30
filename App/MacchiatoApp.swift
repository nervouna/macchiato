import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLineTool.isActive { return }
        // A menu bar app has no windows to keep it alive; without this macOS may quietly terminate it.
        ProcessInfo.processInfo.automaticTerminationSupportEnabled = false
        ProcessInfo.processInfo.disableAutomaticTermination("Macchiato runs its daily schedule")
        ProcessInfo.processInfo.disableSuddenTermination()
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0 != NSRunningApplication.current }
        if !others.isEmpty {
            NSApp.terminate(nil)
            return
        }
        AppModel.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct MacchiatoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    init() {
        CommandLineTool.runIfRequested()
    }

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(!CommandLineTool.isActive)) {
            MenuView()
        } label: {
            Image(systemName: AppModel.shared.menuSymbol)
        }
        .menuBarExtraStyle(.window)

        Window("Settings", id: "settings") {
            SettingsView()
        }
        .windowResizability(.contentSize)
    }
}
