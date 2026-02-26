import SwiftUI

@main
struct MemCacheApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No main window — this is a menu bar-only app.
        // Settings window is managed directly by AppDelegate via NSWindow,
        // because the SwiftUI Settings scene + showSettingsWindow: selector
        // is unreliable in menu bar-only apps.
        Settings { EmptyView() }
    }
}
