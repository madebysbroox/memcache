import Foundation
import Combine
import SwiftUI

/// Aggregates meetings from all enabled calendar providers.
/// Publishes a unified, sorted meeting list and handles polling.
final class CalendarService: ObservableObject {
    @Published var meetings: [Meeting] = []
    @Published var isLoading = false

    let appleProvider = AppleCalendarProvider()
    let googleProvider = GoogleCalendarProvider()

    /// All registered providers.
    var providers: [CalendarProvider] { [appleProvider, googleProvider] }

    /// Providers that are currently authorized and contributing events.
    var enabledProviders: [CalendarProvider] {
        providers.filter { $0.status.isAuthorized }
    }

    /// True when at least one provider is authorized.
    var hasAnyAuthorized: Bool {
        providers.contains { $0.status.isAuthorized }
    }

    /// True when no provider has been configured yet (first launch).
    var needsSetup: Bool {
        providers.allSatisfy {
            if case .notConfigured = $0.status { return true }
            return false
        }
    }

    private var pollTimer: Timer?
    private let pollInterval: TimeInterval = 60

    init() {}

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Public API

    /// Request access for Apple Calendar (primary provider).
    func requestAppleAccess() {
        Task { @MainActor in
            await appleProvider.requestAccess()
            await refresh()
            startPolling()
        }
    }

    /// Initiate Google Calendar OAuth sign-in.
    func connectGoogle() {
        Task { @MainActor in
            await googleProvider.requestAccess()
            await refresh()
        }
    }

    /// Disconnect Google Calendar.
    func disconnectGoogle() {
        googleProvider.signOut()
        Task { @MainActor in
            await refresh()
        }
    }

    /// Fetch events from all enabled providers and merge.
    @MainActor
    func refresh() async {
        isLoading = true
        var allMeetings: [Meeting] = []

        for provider in enabledProviders {
            let events = await provider.fetchTodaysMeetings()
            allMeetings.append(contentsOf: events)
        }

        meetings = allMeetings.sorted { $0.startDate < $1.startDate }
        isLoading = false
    }

    // MARK: - Polling

    func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    // MARK: - Derived state

    /// The next upcoming (non-past, non-all-day) meeting across all providers.
    var nextMeeting: Meeting? {
        meetings.first { !$0.isPast && !$0.isAllDay }
    }
}
