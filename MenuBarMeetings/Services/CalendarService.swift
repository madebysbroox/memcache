import EventKit
import Foundation
import Combine
import SwiftUI

/// Manages Apple Calendar access via EventKit.
/// Publishes today's meetings and auto-refreshes on calendar changes + polling.
final class CalendarService: ObservableObject {
    @Published var meetings: [Meeting] = []
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?

    private let store = EKEventStore()
    private var cancellables = Set<AnyCancellable>()
    private var pollTimer: Timer?

    /// Seconds between automatic refreshes.
    private let pollInterval: TimeInterval = 60

    init() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        observeStoreChanges()
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Permissions (Calendar-002)

    func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.handleAccessResult(granted: granted, error: error)
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.handleAccessResult(granted: granted, error: error)
                }
            }
        }
    }

    private func handleAccessResult(granted: Bool, error: Error?) {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)

        if let error = error {
            errorMessage = error.localizedDescription
            return
        }

        if granted {
            errorMessage = nil
            fetchTodaysMeetings()
            startPolling()
        } else {
            errorMessage = "Calendar access denied. Grant permission in System Settings → Privacy & Security → Calendars."
        }
    }

    // MARK: - Fetching (Calendar-003)

    func fetchTodaysMeetings() {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return }

        let predicate = store.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let ekEvents = store.events(matching: predicate)

        meetings = ekEvents
            .map { event in
                Meeting(
                    id: event.eventIdentifier,
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
            .sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Auto-refresh

    /// Reacts to external calendar changes (e.g. user edits in Calendar.app).
    private func observeStoreChanges() {
        NotificationCenter.default.publisher(for: .EKEventStoreChanged, object: store)
            .debounce(for: .seconds(1), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.fetchTodaysMeetings()
            }
            .store(in: &cancellables)
    }

    /// Polls on a fixed interval so the "next meeting" stays current
    /// even when no external changes occur.
    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.fetchTodaysMeetings()
        }
    }

    // MARK: - Derived state

    /// The next upcoming (non-past, non-all-day) meeting.
    var nextMeeting: Meeting? {
        meetings.first { !$0.isPast && !$0.isAllDay }
    }
}
