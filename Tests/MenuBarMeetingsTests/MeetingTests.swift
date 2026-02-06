import XCTest
import SwiftUI
@testable import MenuBarMeetings

final class MeetingTests: XCTestCase {

    // MARK: - formattedStartTime

    func testFormattedStartTime() {
        let meeting = makeMeeting(startHour: 14, startMinute: 30)
        XCTAssertEqual(meeting.formattedStartTime, "2:30 PM")
    }

    // MARK: - formattedTimeRange

    func testFormattedTimeRange() {
        let meeting = makeMeeting(startHour: 14, startMinute: 30, durationMinutes: 30)
        XCTAssertEqual(meeting.formattedTimeRange, "2:30 PM – 3:00 PM")
    }

    // MARK: - formattedDuration

    func testFormattedDurationMinutesOnly() {
        let meeting = makeMeeting(durationMinutes: 45)
        XCTAssertEqual(meeting.formattedDuration, "45m")
    }

    func testFormattedDurationExactHour() {
        let meeting = makeMeeting(durationMinutes: 60)
        XCTAssertEqual(meeting.formattedDuration, "1h")
    }

    func testFormattedDurationHoursAndMinutes() {
        let meeting = makeMeeting(durationMinutes: 90)
        XCTAssertEqual(meeting.formattedDuration, "1h 30m")
    }

    // MARK: - menuBarLabel

    func testMenuBarLabelForTimedMeeting() {
        let meeting = makeMeeting(title: "Standup", startHour: 14, startMinute: 30)
        XCTAssertEqual(meeting.menuBarLabel, "2:30 PM · Standup")
    }

    func testMenuBarLabelForAllDayEvent() {
        let meeting = makeMeeting(title: "Company Offsite", isAllDay: true)
        XCTAssertEqual(meeting.menuBarLabel, "Company Offsite")
    }

    // MARK: - isPast / isOngoing

    func testIsPastForPastMeeting() {
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(-3600),
            durationMinutes: 30
        )
        XCTAssertTrue(meeting.isPast)
    }

    func testIsOngoingForCurrentMeeting() {
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(-600),
            durationMinutes: 30
        )
        XCTAssertTrue(meeting.isOngoing)
        XCTAssertFalse(meeting.isPast)
    }

    func testIsNotPastForFutureMeeting() {
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(3600),
            durationMinutes: 30
        )
        XCTAssertFalse(meeting.isPast)
        XCTAssertFalse(meeting.isOngoing)
    }

    // MARK: - Urgency level (Sprint 4)

    func testUrgencyNoneForDistantMeeting() {
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(45 * 60),
            durationMinutes: 30
        )
        XCTAssertEqual(meeting.urgencyLevel, .none)
    }

    func testUrgencyLowForMeetingIn20Min() {
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(20 * 60),
            durationMinutes: 30
        )
        XCTAssertEqual(meeting.urgencyLevel, .low)
    }

    func testUrgencyMediumForMeetingIn10Min() {
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(10 * 60),
            durationMinutes: 30
        )
        XCTAssertEqual(meeting.urgencyLevel, .medium)
    }

    func testUrgencyHighForMeetingIn3Min() {
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(3 * 60),
            durationMinutes: 30
        )
        XCTAssertEqual(meeting.urgencyLevel, .high)
    }

    func testUrgencyOngoingForCurrentMeeting() {
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(-600),
            durationMinutes: 30
        )
        XCTAssertEqual(meeting.urgencyLevel, .ongoing)
    }

    // MARK: - Countdown label (Sprint 4)

    func testCountdownLabelForOngoing() {
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(-300),
            durationMinutes: 30
        )
        XCTAssertEqual(meeting.countdownLabel, "now")
    }

    func testCountdownLabelForMinutesAway() {
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(12 * 60 + 30),
            durationMinutes: 30
        )
        XCTAssertEqual(meeting.countdownLabel, "in 12m")
    }

    func testCountdownLabelForHoursAway() {
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(90 * 60 + 30),
            durationMinutes: 30
        )
        XCTAssertEqual(meeting.countdownLabel, "in 1h 30m")
    }

    // MARK: - Smart title truncation (Sprint 4)

    func testTruncatedTitleShortTitleUnchanged() {
        let meeting = makeMeeting(title: "Standup")
        XCTAssertEqual(meeting.truncatedTitle(maxLength: 20), "Standup")
    }

    func testTruncatedTitleDropsFillerWords() {
        let meeting = makeMeeting(title: "Review of the Q4 Budget and Forecast")
        let result = meeting.truncatedTitle(maxLength: 25)
        XCTAssertFalse(result.contains("the"))
        XCTAssertFalse(result.contains(" of "))
        XCTAssertTrue(result.count <= 25)
    }

    func testTruncatedTitleHardTruncatesLongTitle() {
        let meeting = makeMeeting(title: "Extremely Long Meeting Title That Goes Way Beyond")
        let result = meeting.truncatedTitle(maxLength: 15)
        XCTAssertTrue(result.count <= 15)
        XCTAssertTrue(result.hasSuffix("…"))
    }

    // MARK: - Helpers

    private func makeMeeting(
        title: String = "Test Meeting",
        startHour: Int = 10,
        startMinute: Int = 0,
        durationMinutes: Int = 30,
        isAllDay: Bool = false
    ) -> Meeting {
        let calendar = Calendar.current
        let start = calendar.date(
            bySettingHour: startHour, minute: startMinute, second: 0, of: Date()
        )!
        let end = start.addingTimeInterval(Double(durationMinutes) * 60)
        return Meeting(
            id: UUID().uuidString,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: isAllDay,
            location: nil,
            url: nil,
            calendarName: "Test",
            calendarColor: .blue
        )
    }

    private func makeMeeting(
        start: Date,
        durationMinutes: Int
    ) -> Meeting {
        let end = start.addingTimeInterval(Double(durationMinutes) * 60)
        return Meeting(
            id: UUID().uuidString,
            title: "Test Meeting",
            startDate: start,
            endDate: end,
            isAllDay: false,
            location: nil,
            url: nil,
            calendarName: "Test",
            calendarColor: .blue
        )
    }
}
