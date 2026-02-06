import Foundation

struct Meeting: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let url: URL?
    let calendarName: String

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }

    var isOngoing: Bool {
        let now = Date()
        return startDate <= now && now < endDate
    }

    var isPast: Bool {
        Date() >= endDate
    }

    /// Formatted start time, e.g. "2:30 PM"
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: startDate)
    }

    /// Formatted duration, e.g. "30m" or "1h 15m"
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        if remaining == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remaining)m"
    }

    /// Menu bar display string: "2:30 PM · Standup"
    var menuBarLabel: String {
        if isAllDay {
            return title
        }
        return "\(formattedStartTime) · \(title)"
    }
}
