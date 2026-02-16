import Foundation
import Combine

/// Observable store that manages meeting data and state
class MeetingStore: ObservableObject {
    @Published var todaysMeetings: [Meeting] = []
    @Published var nextMeeting: Meeting?
    @Published var urgencyLevel: UrgencyLevel = .none
    @Published var calendarAccessGranted: Bool = false
    @Published var isLoading: Bool = false

    private let calendarService: CalendarService
    private var urgencyTimer: Timer?

    init(calendarService: CalendarService) {
        self.calendarService = calendarService
    }

    /// Request calendar access and fetch initial data
    func requestAccessAndFetch() {
        Task { @MainActor in
            isLoading = true
            let granted = await calendarService.requestAccess()
            calendarAccessGranted = granted

            if granted {
                refreshMeetings()
            }
            isLoading = false
            startUrgencyTimer()
        }
    }

    /// Refresh meetings from calendar
    func refreshMeetings() {
        let meetings = calendarService.fetchTodaysMeetings()

        Task { @MainActor in
            // Separate all-day events and timed events
            let timedMeetings = meetings.filter { !$0.isAllDay }
            let allDayMeetings = meetings.filter { $0.isAllDay }

            // Show all-day events first, then timed
            todaysMeetings = allDayMeetings + timedMeetings

            // Find next upcoming meeting (not ended, not all-day)
            updateNextMeeting()
        }
    }

    /// Update which meeting is "next" and recalculate urgency
    private func updateNextMeeting() {
        let now = Date()

        // First priority: a meeting that's about to start (not yet started)
        // Second priority: a meeting currently in progress
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
