import Foundation
import SwiftUI

/// Status of a calendar provider's connection.
enum CalendarProviderStatus: Equatable {
    case notConfigured
    case authorized
    case denied(String)
    case error(String)

    var isAuthorized: Bool {
        if case .authorized = self { return true }
        return false
    }
}

/// Abstraction over a calendar data source (Apple Calendar, Google, Outlook, etc.).
protocol CalendarProvider: AnyObject {
    /// Human-readable name for the provider (e.g. "Apple Calendar").
    var name: String { get }

    /// Current connection/authorization status.
    var status: CalendarProviderStatus { get }

    /// Request authorization from the user.
    func requestAccess() async

    /// Fetch today's meetings. Returns an empty array on failure.
    func fetchTodaysMeetings() async -> [Meeting]
}
