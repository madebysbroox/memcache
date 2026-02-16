import Foundation

/// Formats meeting information for display in the menu bar
struct MenuBarFormatter {
    /// Maximum characters for the menu bar display
    static let maxMenuBarLength = 32

    struct DisplayResult {
        let text: String
        let urgencyLevel: UrgencyLevel
    }

    /// Format a meeting for menu bar display
    static func format(meeting: Meeting?, urgencyLevel: UrgencyLevel) -> DisplayResult {
        guard let meeting = meeting else {
            return DisplayResult(text: "No meetings", urgencyLevel: .none)
        }

        if meeting.isInProgress {
            return formatInProgress(meeting: meeting)
        }

        return formatUpcoming(meeting: meeting, urgencyLevel: urgencyLevel)
    }

    /// Format an in-progress meeting
    private static func formatInProgress(meeting: Meeting) -> DisplayResult {
        let endTime = formatTime(meeting.endDate)
        let title = truncateTitle(meeting.title, maxLength: maxMenuBarLength - endTime.count - 7)
        return DisplayResult(
            text: "Now \u{2022} \(title) til \(endTime)",
            urgencyLevel: .normal
        )
    }

    /// Format an upcoming meeting
    private static func formatUpcoming(meeting: Meeting, urgencyLevel: UrgencyLevel) -> DisplayResult {
        let time = formatTime(meeting.startDate)
        let minutesAway = meeting.minutesUntilStart

        // For imminent meetings, show countdown instead of time
        if minutesAway <= 5 && minutesAway >= 0 {
            let title = truncateTitle(meeting.title, maxLength: maxMenuBarLength - 10)
            let label = minutesAway == 0 ? "NOW" : "\(minutesAway)m"
            return DisplayResult(
                text: "\(label) \u{2022} \(title)",
                urgencyLevel: urgencyLevel
            )
        }

        let title = truncateTitle(meeting.title, maxLength: maxMenuBarLength - time.count - 3)
        return DisplayResult(
            text: "\(time) \u{2022} \(title)",
            urgencyLevel: urgencyLevel
        )
    }

    /// Format a date as a short time string (e.g. "2:30 PM")
    private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    /// Intelligently truncate a meeting title to fit available space
    static func truncateTitle(_ title: String, maxLength: Int) -> String {
        guard title.count > maxLength, maxLength > 0 else {
            return title
        }

        // Try to break at a word boundary
        let trimmed = String(title.prefix(maxLength))
        if let lastSpace = trimmed.lastIndex(of: " ") {
            let wordBoundary = String(trimmed[trimmed.startIndex..<lastSpace])
            if wordBoundary.count > maxLength / 2 {
                return wordBoundary + "\u{2026}" // ellipsis
            }
        }

        return String(title.prefix(maxLength - 1)) + "\u{2026}"
    }
}
