import SwiftUI

/// Main popover view shown when clicking the menu bar item
struct PopoverContentView: View {
    @ObservedObject var meetingStore: MeetingStore

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()

            Divider()

            // Content
            if meetingStore.isLoading {
                LoadingView()
            } else if !meetingStore.calendarAccessGranted {
                CalendarAccessView(meetingStore: meetingStore)
            } else if meetingStore.todaysMeetings.isEmpty {
                EmptyStateView()
            } else {
                MeetingListView(
                    meetings: meetingStore.todaysMeetings,
                    nextMeeting: meetingStore.nextMeeting
                )
            }

            Divider()

            // Footer
            FooterView()
        }
        .frame(width: 320, height: 420)
    }
}

// MARK: - Header

private struct HeaderView: View {
    var body: some View {
        HStack {
            Text(todayString())
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text("MemCache")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Loading

private struct LoadingView: View {
    var body: some View {
        Spacer()
        ProgressView("Loading meetings...")
            .progressViewStyle(.circular)
        Spacer()
    }
}

// MARK: - Calendar Access Request

private struct CalendarAccessView: View {
    @ObservedObject var meetingStore: MeetingStore

    var body: some View {
        Spacer()
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Calendar Access Required")
                .font(.headline)

            Text("MemCache needs access to your calendar to show upcoming meetings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Grant Access") {
                meetingStore.requestAccessAndFetch()
            }
            .buttonStyle(.borderedProminent)
        }
        Spacer()
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    var body: some View {
        Spacer()
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No meetings today")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Enjoy your free day!")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        Spacer()
    }
}

// MARK: - Footer

private struct FooterView: View {
    var body: some View {
        HStack {
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit", systemImage: "power")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)

            Spacer()

            Button(action: {
                if #available(macOS 14.0, *) {
                    NSApp.activate()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }) {
                Label("Settings", systemImage: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
