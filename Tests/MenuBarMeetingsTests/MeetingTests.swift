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

    // MARK: - Join link detection (Sprint 6)

    func testJoinLinkDetectsZoomURL() {
        let meeting = makeMeeting(url: URL(string: "https://zoom.us/j/123456789"))
        XCTAssertNotNil(meeting.joinLink)
        XCTAssertEqual(meeting.joinLabel, "Join Zoom")
    }

    func testJoinLinkDetectsTeamsURL() {
        let meeting = makeMeeting(url: URL(string: "https://teams.microsoft.com/l/meetup-join/abc"))
        XCTAssertNotNil(meeting.joinLink)
        XCTAssertEqual(meeting.joinLabel, "Join Teams")
    }

    func testJoinLinkDetectsGoogleMeetURL() {
        let meeting = makeMeeting(url: URL(string: "https://meet.google.com/abc-defg-hij"))
        XCTAssertNotNil(meeting.joinLink)
        XCTAssertEqual(meeting.joinLabel, "Join Meet")
    }

    func testJoinLinkNilForNonMeetingURL() {
        let meeting = makeMeeting(url: URL(string: "https://example.com/notes"))
        XCTAssertNil(meeting.joinLink)
        XCTAssertNil(meeting.joinLabel)
    }

    func testJoinLinkExtractsFromLocation() {
        let meeting = makeMeeting(location: "Room 4B — https://zoom.us/j/999")
        XCTAssertNotNil(meeting.joinLink)
        XCTAssertEqual(meeting.joinLabel, "Join Zoom")
    }

    // MARK: - Copyable details (Sprint 6)

    func testCopyableDetailsIncludesAllFields() {
        let meeting = makeMeeting(
            title: "Standup",
            startHour: 14, startMinute: 30, durationMinutes: 30,
            location: "Room A",
            url: URL(string: "https://zoom.us/j/123")
        )
        let details = meeting.copyableDetails
        XCTAssertTrue(details.contains("Standup"))
        XCTAssertTrue(details.contains("2:30 PM"))
        XCTAssertTrue(details.contains("Room A"))
        XCTAssertTrue(details.contains("zoom.us"))
    }

    // MARK: - Edge cases (Sprint 8)

    func testZeroDurationMeeting() {
        let meeting = makeMeeting(durationMinutes: 0)
        XCTAssertEqual(meeting.formattedDuration, "0m")
        XCTAssertEqual(meeting.duration, 0)
    }

    func testVeryLongDuration() {
        let meeting = makeMeeting(durationMinutes: 480) // 8 hours
        XCTAssertEqual(meeting.formattedDuration, "8h")
    }

    func testMultiHourDurationWithMinutes() {
        let meeting = makeMeeting(durationMinutes: 135) // 2h 15m
        XCTAssertEqual(meeting.formattedDuration, "2h 15m")
    }

    func testEmptyTitleTruncation() {
        let meeting = makeMeeting(title: "")
        XCTAssertEqual(meeting.truncatedTitle(maxLength: 20), "")
    }

    func testTitleExactlyAtMaxLength() {
        let meeting = makeMeeting(title: "Exactly Twenty Chars") // 20 chars
        XCTAssertEqual(meeting.truncatedTitle(maxLength: 20), "Exactly Twenty Chars")
    }

    func testTitleAllFillerWords() {
        let meeting = makeMeeting(title: "The And For To Of In On At")
        let result = meeting.truncatedTitle(maxLength: 30)
        // All words are filler — result should be empty
        XCTAssertEqual(result, "")
    }

    func testUrgencyAtExact30MinBoundary() {
        // At exactly 30 minutes, minutesUntilStart == 30, which is >= 30 → .none
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(30 * 60),
            durationMinutes: 30
        )
        XCTAssertEqual(meeting.urgencyLevel, .none)
    }

    func testUrgencyAtExact15MinBoundary() {
        // At exactly 15 minutes, minutesUntilStart == 15, which is >= 15 → .low
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(15 * 60),
            durationMinutes: 30
        )
        XCTAssertEqual(meeting.urgencyLevel, .low)
    }

    func testUrgencyAtExact5MinBoundary() {
        // At exactly 5 minutes, minutesUntilStart == 5, which is >= 5 → .medium
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(5 * 60),
            durationMinutes: 30
        )
        XCTAssertEqual(meeting.urgencyLevel, .medium)
    }

    func testCountdownLabelExactHour() {
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(60 * 60 + 30),
            durationMinutes: 30
        )
        XCTAssertEqual(meeting.countdownLabel, "in 1h")
    }

    func testJoinLinkDetectsWebexURL() {
        let meeting = makeMeeting(url: URL(string: "https://company.webex.com/meet/abc"))
        XCTAssertNotNil(meeting.joinLink)
        XCTAssertEqual(meeting.joinLabel, "Join Webex")
    }

    func testJoinLinkNilWhenNoURLOrLocation() {
        let meeting = makeMeeting()
        XCTAssertNil(meeting.joinLink)
        XCTAssertNil(meeting.joinLabel)
    }

    func testCopyableDetailsForAllDayEvent() {
        let meeting = makeMeeting(title: "Team Offsite", isAllDay: true, location: "Building 5")
        let details = meeting.copyableDetails
        XCTAssertTrue(details.contains("Team Offsite"))
        XCTAssertTrue(details.contains("Building 5"))
        // All-day events should NOT include time range
        XCTAssertFalse(details.contains("AM"))
        XCTAssertFalse(details.contains("PM"))
    }

    func testCopyableDetailsMinimal() {
        let meeting = makeMeeting(title: "Quick Chat")
        let details = meeting.copyableDetails
        XCTAssertTrue(details.contains("Quick Chat"))
        // Should have title + time range, no location or link
        XCTAssertEqual(details.components(separatedBy: "\n").count, 2)
    }

    func testAllDayMeetingProperties() {
        let meeting = makeMeeting(title: "Holiday", isAllDay: true)
        XCTAssertTrue(meeting.isAllDay)
        XCTAssertEqual(meeting.menuBarLabel, "Holiday")
    }

    func testAccessibilityDescriptionOngoing() {
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(-600),
            durationMinutes: 30
        )
        let desc = meeting.accessibilityDescription
        XCTAssertTrue(desc.contains("Ongoing"))
        XCTAssertTrue(desc.contains("Test Meeting"))
    }

    func testAccessibilityDescriptionFuture() {
        let meeting = makeMeeting(title: "Design Review", startHour: 15, location: "Room B")
        let desc = meeting.accessibilityDescription
        XCTAssertTrue(desc.contains("Design Review"))
        XCTAssertTrue(desc.contains("Room B"))
        XCTAssertTrue(desc.contains("Test"))
    }

    func testAccessibilityDescriptionAllDay() {
        let meeting = makeMeeting(title: "Company Holiday", isAllDay: true)
        let desc = meeting.accessibilityDescription
        XCTAssertTrue(desc.contains("All day"))
        XCTAssertTrue(desc.contains("Company Holiday"))
    }

    func testAccessibilityDescriptionPast() {
        let meeting = makeMeeting(
            start: Date().addingTimeInterval(-3600),
            durationMinutes: 30
        )
        let desc = meeting.accessibilityDescription
        XCTAssertTrue(desc.contains("Past"))
    }

    // MARK: - Helpers

    private func makeMeeting(
        title: String = "Test Meeting",
        startHour: Int = 10,
        startMinute: Int = 0,
        durationMinutes: Int = 30,
        isAllDay: Bool = false,
        location: String? = nil,
        url: URL? = nil
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
            location: location,
            url: url,
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
