import EventKit
import Foundation

/// Service for interacting with Apple Calendar via EventKit
class AppleCalendarService: CalendarServiceProtocol {
    private let eventStore = EKEventStore()

    var providerType: CalendarProviderType { .apple }

    var isAuthenticated: Bool {
        authorizationStatus == .authorized
    }

    /// Check current authorization status mapped to CalendarAuthStatus
    var authorizationStatus: CalendarAuthStatus {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .restricted, .writeOnly:
            return .restricted
        @unknown default:
            return .notDetermined
        }
    }

    /// Request calendar access from the user
    func requestAccess() async -> Bool {
        do {
            if #available(macOS 14.0, *) {
                return try await eventStore.requestFullAccessToEvents()
            } else {
                return try await eventStore.requestAccess(to: .event)
            }
        } catch {
            print("MemCache: Calendar access request failed: \(error.localizedDescription)")
            return false
        }
    }

    /// Fetch today's events from all calendars
    func fetchTodaysMeetings() -> [Meeting] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        return fetchMeetings(from: startOfDay, to: endOfDay)
    }

    /// Fetch events within a date range
    func fetchMeetings(from startDate: Date, to endDate: Date) -> [Meeting] {
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil // All calendars
        )

        let ekEvents = eventStore.events(matching: predicate)

        return ekEvents.map { event in
            Meeting(
                id: event.eventIdentifier ?? UUID().uuidString,
                title: event.title ?? "Untitled Meeting",
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                notes: event.notes,
                joinURL: extractJoinURL(from: event),
                calendarName: event.calendar?.title ?? "Calendar",
                calendarColor: nil,
                isAllDay: event.isAllDay
            )
        }.sorted()
    }

    /// Extract video meeting join URLs from event data
    private func extractJoinURL(from event: EKEvent) -> URL? {
        // Check URL field first
        if let url = event.url {
            if isJoinURL(url) {
                return url
            }
        }

        // Check location for URLs
        if let location = event.location, let url = extractURL(from: location) {
            if isJoinURL(url) {
                return url
            }
        }

        // Check notes for URLs
        if let notes = event.notes, let url = extractURL(from: notes) {
            if isJoinURL(url) {
                return url
            }
        }

        return nil
    }

    /// Check if a URL is a meeting join link
    private func isJoinURL(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        let joinHosts = [
            "zoom.us", "meet.google.com", "teams.microsoft.com",
            "webex.com", "gotomeeting.com", "chime.aws"
        ]
        return joinHosts.contains(where: { host.contains($0) })
    }

    /// Extract the first URL from a string
    private func extractURL(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        let match = detector?.firstMatch(in: text, options: [], range: range)

        return match?.url
    }
}
