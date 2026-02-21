import SwiftUI
import AppKit

/// Scrollable list of today's meetings shown in the popover
struct MeetingListView: View {
    let meetings: [Meeting]
    let nextMeeting: Meeting?

    @State private var copiedMeetingId: String?

    private var allDayMeetings: [Meeting] {
        meetings.filter { $0.isAllDay }
    }

    private var timedMeetings: [Meeting] {
        meetings.filter { !$0.isAllDay }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // All-day events section
                if !allDayMeetings.isEmpty {
                    AllDaySectionView(meetings: allDayMeetings)
                    Divider()
                        .padding(.horizontal, 16)
                }

                // Timed meetings
                ForEach(timedMeetings) { meeting in
                    MeetingRowView(
                        meeting: meeting,
                        isNext: meeting.id == nextMeeting?.id,
                        copiedMeetingId: $copiedMeetingId
                    )
                    .contextMenu {
                        if let joinURL = meeting.joinURL {
                            Button("Join Meeting") { NSWorkspace.shared.open(joinURL) }
                            Button("Copy Meeting Link") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(joinURL.absoluteString, forType: .string)
                            }
                            Divider()
                        }
                        Button("Copy Meeting Details") { copyMeetingDetails(meeting) }
                        Divider()
                        Button("Open Calendar") {
                            NSWorkspace.shared.open(URL(string: "x-apple-calevent://")!)
                        }
                    }

                    if meeting.id != timedMeetings.last?.id {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private func copyMeetingDetails(_ meeting: Meeting) {
        var details = meeting.title
        details += "\n\(meeting.timeRangeString)"
        if let location = meeting.location, !location.isEmpty {
            details += "\n\(location)"
        }
        if let joinURL = meeting.joinURL {
            details += "\nJoin: \(joinURL.absoluteString)"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(details, forType: .string)
        copiedMeetingId = meeting.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedMeetingId == meeting.id {
                copiedMeetingId = nil
            }
        }
    }
}

// MARK: - All Day Section

private struct AllDaySectionView: View {
    let meetings: [Meeting]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ALL DAY")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            ForEach(meetings) { meeting in
                HStack(spacing: 8) {
                    Circle()
                        .fill(.blue.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .accessibilityHidden(true)

                    Text(meeting.title)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("All day: \(meeting.title)")
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Meeting Row

struct MeetingRowView: View {
    let meeting: Meeting
    let isNext: Bool
    @Binding var copiedMeetingId: String?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time column
            VStack(alignment: .trailing, spacing: 2) {
                Text(startTimeString)
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(isNext ? .bold : .regular)
                    .foregroundStyle(timeColor)

                Text(durationString)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 64, alignment: .trailing)

            // Status indicator
            statusIndicator
                .accessibilityHidden(true)

            // Meeting details
            VStack(alignment: .leading, spacing: 4) {
                Text(meeting.title)
                    .font(.callout)
                    .fontWeight(isNext ? .semibold : .regular)
                    .foregroundStyle(meeting.hasEnded ? .secondary : .primary)
                    .lineLimit(2)

                if let location = meeting.location, !location.isEmpty {
                    Label(location, systemImage: "location")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !meeting.hasEnded {
                    HStack(spacing: 6) {
                        if let joinURL = meeting.joinURL {
                            let platform = meetingPlatform(from: joinURL)
                            Button(action: {
                                NSWorkspace.shared.open(joinURL)
                            }) {
                                Label("Join \(platform.name)", systemImage: platform.icon)
                                    .font(.caption2)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.mini)
                            .accessibilityLabel("Join \(platform.name) meeting for \(meeting.title)")
                        }

                        Button(action: {
                            copyMeetingDetails(meeting)
                        }) {
                            if copiedMeetingId == meeting.id {
                                Label("Copied!", systemImage: "checkmark")
                                    .font(.caption2)
                            } else {
                                Label("Copy", systemImage: "doc.on.doc")
                                    .font(.caption2)
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .accessibilityLabel("Copy details for \(meeting.title)")
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isNext ? Color.accentColor.opacity(0.08) : Color.clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint(meeting.joinURL != nil ? "Double-click to join meeting" : "")
        .focusable()
    }

    private var rowAccessibilityLabel: String {
        let status: String
        if meeting.isInProgress {
            status = "In progress"
        } else if meeting.hasEnded {
            status = "Ended"
        } else if isNext {
            status = "Next"
        } else {
            status = "Upcoming"
        }
        let duration = meeting.durationMinutes
        let durationText = duration >= 60
            ? "\(duration / 60) hour\(duration / 60 == 1 ? "" : "s")\(duration % 60 > 0 ? " \(duration % 60) minutes" : "")"
            : "\(duration) minutes"
        return "\(status): \(meeting.title), \(meeting.timeRangeString), \(durationText)"
    }

    private var startTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: meeting.startDate)
    }

    private var durationString: String {
        let minutes = meeting.durationMinutes
        if minutes >= 60 {
            let hours = minutes / 60
            let remaining = minutes % 60
            if remaining == 0 {
                return "\(hours)h"
            }
            return "\(hours)h \(remaining)m"
        }
        return "\(minutes)m"
    }

    private var timeColor: Color {
        if meeting.hasEnded {
            return .secondary
        }
        if isNext {
            switch UrgencyLevel.from(minutesUntil: meeting.minutesUntilStart) {
            case .imminent: return .red
            case .soon: return .orange
            case .approaching: return .yellow
            default: return .primary
            }
        }
        return .primary
    }

    @ViewBuilder
    private var statusIndicator: some View {
        if meeting.isInProgress {
            Circle()
                .fill(.green)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
        } else if meeting.hasEnded {
            Circle()
                .fill(.gray.opacity(0.4))
                .frame(width: 8, height: 8)
                .padding(.top, 4)
        } else if isNext {
            Circle()
                .fill(.blue)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
        } else {
            Circle()
                .strokeBorder(.gray.opacity(0.4), lineWidth: 1)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
        }
    }

    private func meetingPlatform(from url: URL) -> (name: String, icon: String) {
        let host = url.host?.lowercased() ?? ""
        if host.contains("zoom.us") { return ("Zoom", "video.fill") }
        if host.contains("meet.google.com") { return ("Google Meet", "video.fill") }
        if host.contains("teams.microsoft.com") { return ("Teams", "video.fill") }
        if host.contains("webex.com") { return ("Webex", "video.fill") }
        return ("Meeting", "video.fill")
    }

    private func copyMeetingDetails(_ meeting: Meeting) {
        var details = meeting.title
        details += "\n\(meeting.timeRangeString)"
        if let location = meeting.location, !location.isEmpty {
            details += "\n\(location)"
        }
        if let joinURL = meeting.joinURL {
            details += "\nJoin: \(joinURL.absoluteString)"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(details, forType: .string)
        copiedMeetingId = meeting.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copiedMeetingId == meeting.id {
                copiedMeetingId = nil
            }
        }
    }
}
