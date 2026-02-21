import Foundation
import Combine

/// Observable store that manages meeting data and state
class MeetingStore: ObservableObject {
    @Published var todaysMeetings: [Meeting] = []
    @Published var nextMeeting: Meeting?
    @Published var urgencyLevel: UrgencyLevel = .none
    @Published var calendarAccessGranted: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastFetchError: String?

    private var calendarServices: [CalendarServiceProtocol]
    private var urgencyTimer: Timer?
    private let cache = CalendarCache()

    init(calendarServices: [CalendarServiceProtocol]) {
        self.calendarServices = calendarServices
        syncCacheTTL()
    }

    /// Update the set of active calendar services (e.g. after connect/disconnect).
    /// Invalidates cache for any providers that were removed.
    func updateServices(_ services: [CalendarServiceProtocol]) {
        let oldProviders = Set(calendarServices.map { $0.providerType })
        let newProviders = Set(services.map { $0.providerType })
        let removed = oldProviders.subtracting(newProviders)
        for provider in removed {
            cache.invalidate(provider: provider)
        }
        self.calendarServices = services
    }

    /// Request calendar access and fetch initial data
    func requestAccessAndFetch() {
        Task { @MainActor in
            isLoading = true

            var anyGranted = false
            for service in calendarServices {
                let granted = await service.requestAccess()
                if granted { anyGranted = true }
            }
            calendarAccessGranted = anyGranted

            if anyGranted {
                refreshMeetings()
            }
            isLoading = false
            startUrgencyTimer()
        }
    }

    /// Refresh meetings from all calendar services.
    /// Fetches on a background queue to avoid deadlocking the main thread
    /// (GoogleCalendarService uses synchronous semaphore-based networking).
    func refreshMeetings() {
        let services = calendarServices
        let showAllDay = UserDefaults.standard.object(forKey: "showAllDayEvents") as? Bool ?? true
        let today = Date()
        let meetingCache = cache

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var allMeetings: [Meeting] = []
            var hadFetchError = false
            for service in services {
                if let cached = meetingCache.get(provider: service.providerType, date: today) {
                    allMeetings.append(contentsOf: cached)
                } else {
                    let meetings = service.fetchTodaysMeetings()
                    if meetings.isEmpty && service.providerType != .apple {
                        // Network-dependent services returning empty may indicate a fetch failure
                        hadFetchError = true
                    }
                    meetingCache.set(meetings, provider: service.providerType, date: today)
                    allMeetings.append(contentsOf: meetings)
                }
            }
            allMeetings.sort()

            DispatchQueue.main.async {
                guard let self = self else { return }
                let timedMeetings = allMeetings.filter { !$0.isAllDay }

                if showAllDay {
                    let allDayMeetings = allMeetings.filter { $0.isAllDay }
                    self.todaysMeetings = allDayMeetings + timedMeetings
                } else {
                    self.todaysMeetings = timedMeetings
                }

                if hadFetchError {
                    self.lastFetchError = "Some calendars couldn't be reached. Showing cached data."
                } else {
                    self.lastFetchError = nil
                }

                self.updateNextMeeting()
            }
        }
    }

    /// Force-refresh by invalidating all cached data first (e.g. when popover opens).
    func forceRefresh() {
        cache.invalidateAll()
        refreshMeetings()
    }

    /// Sync the cache TTL with the user's configured refresh interval.
    func syncCacheTTL() {
        let interval = UserDefaults.standard.double(forKey: "refreshInterval")
        let seconds = interval > 0 ? interval : 60
        cache.updateTTL(seconds)
    }

    /// Update which meeting is "next" and recalculate urgency
    private func updateNextMeeting() {
        let upcoming = todaysMeetings
            .filter { !$0.isAllDay && !$0.hasEnded }
            .sorted()

        if let next = upcoming.first(where: { !$0.isInProgress }) {
            // There's a future meeting
            nextMeeting = next
            urgencyLevel = UrgencyLevel.from(minutesUntil: next.minutesUntilStart)
        } else if let inProgress = upcoming.first(where: { $0.isInProgress }) {
            // Only in-progress meetings remain
            nextMeeting = inProgress
            urgencyLevel = .normal
        } else {
            // No more meetings today
            nextMeeting = nil
            urgencyLevel = .none
        }
    }

    /// Start a timer that recalculates urgency every 30 seconds
    private func startUrgencyTimer() {
        urgencyTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateNextMeeting()
            }
        }
    }

    deinit {
        urgencyTimer?.invalidate()
    }
}
