import SwiftUI
import AppKit

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
            if calendarService.needsSetup {
                calendarService.requestAppleAccess()
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
        if calendarService.needsSetup {
            permissionPrompt(message: "Requesting calendar access…")
        } else if !calendarService.hasAnyAuthorized {
            permissionPrompt(
                message: "No calendars connected. Open Preferences to connect a calendar."
            )
        } else if calendarService.meetings.isEmpty {
            emptyState
        } else {
            meetingList
        }
    }

    private var meetingList: some View {
        let allDay = calendarService.meetings.filter { $0.isAllDay }
        let timed = calendarService.meetings.filter { !$0.isAllDay }

        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if !allDay.isEmpty {
                    SectionHeader(title: "All Day")
                    ForEach(allDay) { meeting in
                        AllDayRow(meeting: meeting)
                        Divider().padding(.leading, 12)
                    }
                }

                if !timed.isEmpty {
                    if !allDay.isEmpty {
                        SectionHeader(title: "Schedule")
                    }
                    ForEach(timed) { meeting in
                        MeetingRow(meeting: meeting)
                        Divider().padding(.leading, 12)
                    }
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
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }

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

// MARK: - Section Header

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }
}

// MARK: - All-Day Row

struct AllDayRow: View {
    let meeting: Meeting

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(meeting.calendarColor)
                .frame(width: 8, height: 8)

            Text(meeting.title)
                .font(.callout)
                .lineLimit(1)

            Spacer()

            Text(meeting.calendarName)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
    }
}

// MARK: - Meeting Row

struct MeetingRow: View {
    let meeting: Meeting

    @State private var showCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(meeting.calendarColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 2) {
                    Text(meeting.title)
                        .font(.callout)
                        .lineLimit(1)
                        .opacity(meeting.isPast ? 0.5 : 1.0)
                        .fontWeight(meeting.isOngoing ? .semibold : .regular)

                    Text(meeting.formattedTimeRange)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    if let location = meeting.location, !location.isEmpty {
                        Text(location)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(meeting.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

            // Action buttons
            if !meeting.isPast {
                HStack(spacing: 8) {
                    if let joinLink = meeting.joinLink, let joinLabel = meeting.joinLabel {
                        Button {
                            NSWorkspace.shared.open(joinLink)
                        } label: {
                            Label(joinLabel, systemImage: "video")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(meeting.copyableDetails, forType: .string)
                        showCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            showCopied = false
                        }
                    } label: {
                        Label(showCopied ? "Copied" : "Copy", systemImage: showCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.top, 4)
                .padding(.leading, 16)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(meeting.isOngoing ? Color.accentColor.opacity(0.08) : Color.clear)
    }
}
