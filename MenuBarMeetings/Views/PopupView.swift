import SwiftUI

struct PopupView: View {
    @EnvironmentObject var calendarService: CalendarService

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content

            Divider()

            footer
        }
        .frame(width: 320, height: 400)
        .onAppear {
            if calendarService.authorizationStatus == .notDetermined {
                calendarService.requestAccess()
            }
        }
    }

    // MARK: - Subviews

    private var header: some View {
        HStack {
            Text(todayString)
                .font(.headline)
            Spacer()
        }
        .padding(12)
    }

    @ViewBuilder
    private var content: some View {
        switch calendarService.authorizationStatus {
        case .authorized, .fullAccess:
            if calendarService.meetings.isEmpty {
                emptyState
            } else {
                meetingList
            }
        case .notDetermined:
            permissionPrompt(message: "Requesting calendar access…")
        default:
            permissionPrompt(
                message: calendarService.errorMessage
                    ?? "Calendar access denied. Open System Settings to grant permission."
            )
        }
    }

    private var meetingList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(calendarService.meetings) { meeting in
                    MeetingRow(meeting: meeting)
                    Divider().padding(.leading, 12)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No meetings today")
                .font(.title3)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func permissionPrompt(message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            Button("Preferences") {
                // Stub — wired up in Sprint 5
            }
            .disabled(true)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
    }

    // MARK: - Helpers

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Meeting Row

struct MeetingRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(meeting.isAllDay ? "All day" : meeting.formattedStartTime)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)

            VStack(alignment: .leading, spacing: 2) {
                Text(meeting.title)
                    .font(.callout)
                    .lineLimit(1)
                    .opacity(meeting.isPast ? 0.5 : 1.0)

                Text(meeting.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
    }
}
