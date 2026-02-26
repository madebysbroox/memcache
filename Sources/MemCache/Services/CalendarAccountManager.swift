import Foundation
import Combine

/// Manages the lifecycle of calendar service accounts.
/// Singleton so it can be accessed from both AppDelegate and SettingsView.
final class CalendarAccountManager: ObservableObject {
    static let shared = CalendarAccountManager()

    @Published var appleService: AppleCalendarService
    @Published var googleService: GoogleCalendarService?
    @Published var outlookService: OutlookCalendarService?
    @Published var isGoogleConnected: Bool = false
    @Published var isGoogleConnecting: Bool = false
    @Published var isOutlookConnected: Bool = false
    @Published var isOutlookConnecting: Bool = false

    /// Per-provider enable/disable toggles, persisted via UserDefaults.
    @Published var isAppleEnabled: Bool {
        didSet { UserDefaults.standard.set(isAppleEnabled, forKey: "calendarEnabled_apple") }
    }
    @Published var isGoogleEnabled: Bool {
        didSet { UserDefaults.standard.set(isGoogleEnabled, forKey: "calendarEnabled_google") }
    }
    @Published var isOutlookEnabled: Bool {
        didSet { UserDefaults.standard.set(isOutlookEnabled, forKey: "calendarEnabled_outlook") }
    }

    /// Fires whenever the set of active services changes so consumers can react.
    let servicesChanged = PassthroughSubject<Void, Never>()

    private init() {
        self.appleService = AppleCalendarService()

        // Load per-provider toggles (default to enabled)
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "calendarEnabled_apple") == nil {
            defaults.set(true, forKey: "calendarEnabled_apple")
        }
        if defaults.object(forKey: "calendarEnabled_google") == nil {
            defaults.set(true, forKey: "calendarEnabled_google")
        }
        if defaults.object(forKey: "calendarEnabled_outlook") == nil {
            defaults.set(true, forKey: "calendarEnabled_outlook")
        }
        self.isAppleEnabled = defaults.bool(forKey: "calendarEnabled_apple")
        self.isGoogleEnabled = defaults.bool(forKey: "calendarEnabled_google")
        self.isOutlookEnabled = defaults.bool(forKey: "calendarEnabled_outlook")

        // Check if Google tokens exist in Keychain to auto-restore the session
        let probe = GoogleCalendarService()
        if probe.isAuthenticated {
            self.googleService = probe
            self.isGoogleConnected = true
        }

        // Check if Outlook tokens exist in Keychain to auto-restore the session
        let outlookProbe = OutlookCalendarService()
        if outlookProbe.isAuthenticated {
            self.outlookService = outlookProbe
            self.isOutlookConnected = true
        }
    }

    /// Triggers the OAuth consent flow for Google Calendar.
    /// Returns true if the connection succeeded.
    @MainActor
    func connectGoogle() async -> Bool {
        isGoogleConnecting = true
        defer { isGoogleConnecting = false }

        let service = GoogleCalendarService()
        let granted = await service.requestAccess()

        if granted {
            googleService = service
            isGoogleConnected = true
            isGoogleEnabled = true
            servicesChanged.send()
            return true
        }
        return false
    }

    /// Disconnects Google Calendar by removing tokens and clearing the reference.
    func disconnectGoogle() {
        googleService?.disconnect()
        googleService = nil
        isGoogleConnected = false
        servicesChanged.send()
    }

    /// Triggers the OAuth consent flow for Outlook Calendar.
    /// Returns true if the connection succeeded.
    @MainActor
    func connectOutlook() async -> Bool {
        isOutlookConnecting = true
        defer { isOutlookConnecting = false }

        let service = OutlookCalendarService()
        let granted = await service.requestAccess()

        if granted {
            outlookService = service
            isOutlookConnected = true
            isOutlookEnabled = true
            servicesChanged.send()
            return true
        }
        return false
    }

    /// Disconnects Outlook Calendar by removing tokens and clearing the reference.
    func disconnectOutlook() {
        outlookService?.disconnect()
        outlookService = nil
        isOutlookConnected = false
        servicesChanged.send()
    }

    /// Toggle a provider on or off. Fires servicesChanged so MeetingStore can update.
    func setAppleEnabled(_ enabled: Bool) {
        isAppleEnabled = enabled
        servicesChanged.send()
    }

    func setGoogleEnabled(_ enabled: Bool) {
        isGoogleEnabled = enabled
        servicesChanged.send()
    }

    func setOutlookEnabled(_ enabled: Bool) {
        isOutlookEnabled = enabled
        servicesChanged.send()
    }

    /// Returns an array of all currently connected and enabled calendar services.
    func allActiveServices() -> [CalendarServiceProtocol] {
        var services: [CalendarServiceProtocol] = []
        if isAppleEnabled {
            services.append(appleService)
        }
        if isGoogleEnabled, let google = googleService, google.isAuthenticated {
            services.append(google)
        }
        if isOutlookEnabled, let outlook = outlookService, outlook.isAuthenticated {
            services.append(outlook)
        }
        return services
    }
}
