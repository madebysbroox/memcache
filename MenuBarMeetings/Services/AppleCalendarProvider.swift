import EventKit
import Foundation
import SwiftUI

/// Apple Calendar provider backed by EventKit.
final class AppleCalendarProvider: CalendarProvider {
    let name = "Apple Calendar"

    private let store = EKEventStore()

    private(set) var status: CalendarProviderStatus = .notConfigured

    init() {
        refreshStatus()
    }

    // MARK: - CalendarProvider

    func requestAccess() async {
        do {
            if #available(macOS 14.0, *) {
                let granted = try await store.requestFullAccessToEvents()
                status = granted ? .authorized : .denied(Self.deniedMessage)
            } else {
                let granted = try await store.requestAccess(to: .event)
                status = granted ? .authorized : .denied(Self.deniedMessage)
            }
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func fetchTodaysMeetings() async -> [Meeting] {
        guard status.isAuthorized else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        return ekEvents.map { event in
            Meeting(
                id: "apple_\(event.eventIdentifier ?? UUID().uuidString)",
                title: event.title ?? "(No title)",
                startDate: event.startDate,
                endDate: event.endDate,
                isAllDay: event.isAllDay,
                location: event.location,
                url: event.url,
                calendarName: event.calendar.title,
                calendarColor: Color(cgColor: event.calendar.cgColor)
            )
        }
    }
    
    func signOut() {
        // Apple Calendar uses system-level permissions, so there's no token to clear.
        // User must revoke access in System Settings.
    }

    // MARK: - Internal

    func refreshStatus() {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .authorized, .fullAccess:
            status = .authorized
        case .denied, .restricted:
            status = .denied(Self.deniedMessage)
        case .notDetermined:
            status = .notConfigured
        case .writeOnly:
            status = .denied("Write-only access is insufficient. Please grant full calendar access.")
        @unknown default:
            status = .notConfigured
        }
    }

    private static let deniedMessage =
        "Calendar access denied. Grant permission in System Settings → Privacy & Security → Calendars."
}
