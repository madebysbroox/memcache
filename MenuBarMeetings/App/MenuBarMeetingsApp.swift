import SwiftUI

@main
struct MenuBarMeetingsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var calendarService = CalendarService()

    var body: some Scene {
        MenuBarExtra {
            PopupView()
                .environmentObject(calendarService)
        } label: {
            MenuBarView(nextMeeting: calendarService.nextMeeting)
        }
        .menuBarExtraStyle(.window)

        Settings {
            PreferencesView()
                .environmentObject(calendarService)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // CalendarService is owned by the SwiftUI App struct;
        // permission request is triggered from PopupView on first launch.
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Cleanup will go here
    }
}
