import Foundation

enum CalendarAuthStatus {
    case authorized
    case denied
    case notDetermined
    case restricted
}

enum CalendarProviderType: String, CaseIterable {
    case apple = "Apple Calendar"
    case google = "Google Calendar"
    case outlook = "Outlook"
}

protocol CalendarServiceProtocol: AnyObject {
    var providerType: CalendarProviderType { get }
    var authorizationStatus: CalendarAuthStatus { get }
    var isAuthenticated: Bool { get }

    func requestAccess() async -> Bool
    func fetchTodaysMeetings() -> [Meeting]
    func fetchMeetings(from startDate: Date, to endDate: Date) -> [Meeting]
}
