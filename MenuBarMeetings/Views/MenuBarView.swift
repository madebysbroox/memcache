import SwiftUI

/// Renders the menu bar label. Shows the next meeting or a fallback.
struct MenuBarView: View {
    let nextMeeting: Meeting?

    var body: some View {
        if let meeting = nextMeeting {
            Label(meeting.menuBarLabel, systemImage: "calendar")
        } else {
            Label("No meetings", systemImage: "calendar")
        }
    }
}
