import Foundation

/// Represents a calendar meeting/event
struct Meeting: Identifiable, Comparable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let joinURL: URL?
    let calendarName: String
    let calendarColor: String?
    let isAllDay: Bool

    /// Duration in minutes
    var durationMinutes: Int {
        Int(endDate.timeIntervalSince(startDate) / 60)
    }

    /// Formatted time range string (e.g. "2:30 – 3:00 PM")
    var timeRangeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm"

        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "h:mm a"

        // Only show AM/PM on start if it differs from end
        let startPeriod = Calendar.current.component(.hour, from: startDate) < 12 ? "AM" : "PM"
        let endPeriod = Calendar.current.component(.hour, from: endDate) < 12 ? "AM" : "PM"

        if startPeriod == endPeriod {
            return "\(formatter.string(from: startDate)) – \(endFormatter.string(from: endDate))"
        } else {
            let startFull = DateFormatter()
            startFull.dateFormat = "h:mm a"
            return "\(startFull.string(from: startDate)) – \(endFormatter.string(from: endDate))"
        }
    }

    /// Minutes until this meeting starts (negative if already started)
    var minutesUntilStart: Int {
        Int(startDate.timeIntervalSinceNow / 60)
    }

    /// Whether this meeting is currently in progress
    var isInProgress: Bool {
        let now = Date()
        return now >= startDate && now < endDate
    }

    /// Whether this meeting has already ended
    var hasEnded: Bool {
        Date() >= endDate
    }

    static func < (lhs: Meeting, rhs: Meeting) -> Bool {
        lhs.startDate < rhs.startDate
    }
}

/// Urgency level based on how soon the next meeting is
enum UrgencyLevel: Int, Comparable {
    case none = 0       // No upcoming meetings
    case normal = 1     // > 30 minutes away
    case approaching = 2 // 15-30 minutes away
    case soon = 3       // 5-15 minutes away
    case imminent = 4   // < 5 minutes away

    static func < (lhs: UrgencyLevel, rhs: UrgencyLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(minutesUntil: Int) -> UrgencyLevel {
        switch minutesUntil {
        case ..<0:
            return .normal // Already started, treat as normal
        case 0..<5:
            return .imminent
        case 5..<15:
            return .soon
        case 15..<30:
            return .approaching
        default:
            return .normal
        }
    }
}
