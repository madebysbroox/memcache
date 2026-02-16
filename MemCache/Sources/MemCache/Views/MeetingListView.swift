import SwiftUI

/// Scrollable list of today's meetings shown in the popover
struct MeetingListView: View {
    let meetings: [Meeting]
    let nextMeeting: Meeting?

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
                        isNext: meeting.id == nextMeeting?.id
                    )

                    if meeting.id != timedMeetings.last?.id {
                        Divider()
                            .padding(.horizontal, 16)
                    }
                }
            }
            .padding(.vertical, 4)
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

                    Text(meeting.title)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
        }
        .padding(.bottom, 8)
    }
}

// MARK: - Meeting Row

struct MeetingRowView: View {
    let meeting: Meeting
    let isNext: Bool

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

                if let joinURL = meeting.joinURL {
                    Button(action: {
                        NSWorkspace.shared.open(joinURL)
                    }) {
                        Label("Join Meeting", systemImage: "video")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isNext ? Color.accentColor.opacity(0.06) : Color.clear)
        .contentShape(Rectangle())
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
                .strokeBorder(.gray.opacity(0.3), lineWidth: 1)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
        }
    }
}
