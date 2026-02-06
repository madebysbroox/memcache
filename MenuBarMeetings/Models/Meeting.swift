import Foundation
import SwiftUI

/// Urgency level based on time until meeting starts.
enum UrgencyLevel: Comparable {
    case none       // > 30 minutes away
    case low        // 15–30 minutes
    case medium     // 5–15 minutes
    case high       // < 5 minutes
    case ongoing    // currently in progress
}

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

    /// Minutes until the meeting starts. Negative if already started.
    var minutesUntilStart: Int {
        Int(startDate.timeIntervalSince(Date()) / 60)
    }

    /// Current urgency level for this meeting.
    var urgencyLevel: UrgencyLevel {
        if isOngoing { return .ongoing }
        let mins = minutesUntilStart
        if mins < 0  { return .none }  // past, shouldn't display
        if mins < 5  { return .high }
        if mins < 15 { return .medium }
        if mins < 30 { return .low }
        return .none
    }

    // MARK: - Formatted strings

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

    /// Countdown string for the menu bar, e.g. "in 12m" or "now"
    var countdownLabel: String {
        if isOngoing { return "now" }
        let mins = minutesUntilStart
        if mins <= 0 { return "now" }
        if mins < 60 { return "in \(mins)m" }
        let hours = mins / 60
        let remaining = mins % 60
        if remaining == 0 { return "in \(hours)h" }
        return "in \(hours)h \(remaining)m"
    }

    /// Smart-truncated title that fits within a character budget.
    func truncatedTitle(maxLength: Int = 20) -> String {
        if title.count <= maxLength { return title }
        // Drop filler words, then hard-truncate if still too long
        let fillers: Set<String> = ["the", "a", "an", "and", "with", "for", "to", "of", "in", "on", "at"]
        let words = title.split(separator: " ").map(String.init)
        let filtered = words.filter { !fillers.contains($0.lowercased()) }
        let joined = filtered.joined(separator: " ")
        if joined.count <= maxLength { return joined }
        return String(joined.prefix(maxLength - 1)) + "…"
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
