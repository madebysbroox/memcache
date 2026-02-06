import Foundation
import SwiftUI

struct Meeting: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let location: String?
    let url: URL?
    let calendarName: String
    let calendarColor: Color

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
        Self.timeFormatter.string(from: startDate)
    }

    /// Formatted time range, e.g. "2:30 – 3:00 PM"
    var formattedTimeRange: String {
        "\(Self.timeFormatter.string(from: startDate)) – \(Self.timeFormatter.string(from: endDate))"
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

    // MARK: - Shared formatter

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
}
