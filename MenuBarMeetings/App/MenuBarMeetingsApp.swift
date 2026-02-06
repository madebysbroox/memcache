import SwiftUI

@main
struct MenuBarMeetingsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("MenuBar Meetings", systemImage: "calendar") {
            PopupView()
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // One-time setup will go here (e.g. calendar permissions in Sprint 2)
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup will go here
    }
}
