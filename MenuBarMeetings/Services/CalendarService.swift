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
    let outlookProvider = OutlookCalendarProvider()

    /// All registered providers.
    var providers: [CalendarProvider] { [appleProvider, googleProvider, outlookProvider] }

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

    /// User-configurable poll interval (seconds). Persisted via UserDefaults.
    @Published var pollInterval: TimeInterval = UserDefaults.standard.double(forKey: "pollInterval").clamped(to: 30...600, default: 60) {
        didSet {
            UserDefaults.standard.set(pollInterval, forKey: "pollInterval")
            startPolling() // restart timer with new interval
        }
    }

    /// Minimum time (seconds) between API fetches to reduce redundant calls.
    private let cacheInterval: TimeInterval = 15

    /// Tracks when the last successful refresh completed.
    private var lastRefreshDate: Date?

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

    /// Initiate Microsoft Outlook OAuth sign-in.
    func connectOutlook() {
        Task { @MainActor in
            await outlookProvider.requestAccess()
            await refresh()
        }
    }

    /// Disconnect Microsoft Outlook.
    func disconnectOutlook() {
        outlookProvider.signOut()
        Task { @MainActor in
            await refresh()
        }
    }

    /// Fetch events from all enabled providers and merge.
    /// Uses a simple cache: skips fetch if last refresh was within `cacheInterval`.
    @MainActor
    func refresh() async {
        let now = Date()
        if let lastRefresh = lastRefreshDate, now.timeIntervalSince(lastRefresh) < cacheInterval {
            return // cached data still valid
        }

        isLoading = true
        var allMeetings: [Meeting] = []

        for provider in enabledProviders {
            let events = await provider.fetchTodaysMeetings()
            allMeetings.append(contentsOf: events)
        }

        meetings = allMeetings.sorted { $0.startDate < $1.startDate }
        lastRefreshDate = now
        isLoading = false
    }

    /// Force-refresh ignoring the cache (e.g. after connecting a new provider).
    @MainActor
    func forceRefresh() async {
        lastRefreshDate = nil
        await refresh()
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

// MARK: - Double clamped helper

private extension Double {
    /// Returns `self` if within `range`, otherwise the default value.
    /// Treats 0 (UserDefaults unset) as "use default".
    func clamped(to range: ClosedRange<Double>, default defaultValue: Double) -> Double {
        if self == 0 { return defaultValue }
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
