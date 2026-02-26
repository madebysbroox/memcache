@preconcurrency import AuthenticationServices
import Foundation

// MARK: - Token Model

/// OAuth 2.0 tokens persisted in the Keychain.
struct OutlookTokens: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date

    var isExpired: Bool {
        Date() >= expiresAt
    }
}

// MARK: - Outlook Calendar Service

/// Outlook Calendar provider that implements CalendarServiceProtocol.
/// Uses OAuth 2.0 (authorization code flow) via ASWebAuthenticationSession
/// and stores tokens in the Keychain. Fetches events from Microsoft Graph API.
final class OutlookCalendarService: NSObject, CalendarServiceProtocol {

    // MARK: - Constants

    private static let keychainTokensKey = "outlook_oauth_tokens"

    // MARK: - State

    private var tokens: OutlookTokens?

    // MARK: - CalendarServiceProtocol

    var providerType: CalendarProviderType { .outlook }

    var authorizationStatus: CalendarAuthStatus {
        if let tokens = loadTokens() {
            return tokens.isExpired ? .notDetermined : .authorized
        }
        return .notDetermined
    }

    var isAuthenticated: Bool {
        loadTokens() != nil
    }

    // MARK: - Init

    override init() {
        super.init()
        self.tokens = loadTokens()
    }

    // MARK: - Access

    /// Triggers the OAuth consent flow via ASWebAuthenticationSession.
    /// Returns true if tokens were successfully obtained and stored.
    func requestAccess() async -> Bool {
        // If we already have a valid (non-expired) token, skip the flow
        if let existing = loadTokens(), !existing.isExpired {
            self.tokens = existing
            return true
        }

        // If we have an expired token with a refresh token, try refreshing first
        if let existing = loadTokens(), existing.isExpired, existing.refreshToken != nil {
            if let refreshed = await refreshAccessToken(using: existing) {
                self.tokens = refreshed
                return true
            }
        }

        // Full OAuth authorization code flow
        guard let code = await presentAuthSession() else {
            return false
        }

        guard let newTokens = await exchangeCodeForTokens(code) else {
            return false
        }

        self.tokens = newTokens
        return true
    }

    // MARK: - Fetch Meetings

    func fetchTodaysMeetings() -> [Meeting] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        return fetchMeetings(from: startOfDay, to: endOfDay)
    }

    func fetchMeetings(from startDate: Date, to endDate: Date) -> [Meeting] {
        guard let validTokens = ensureValidTokens() else {
            print("MemCache: Outlook Calendar – not authenticated")
            return []
        }

        // Fetch the user's calendar list first
        let calendars = fetchCalendarList(accessToken: validTokens.accessToken)
        if calendars.isEmpty {
            return []
        }

        // Fetch events using calendarview (all calendars combined)
        let allMeetings = fetchCalendarViewEvents(
            calendars: calendars,
            startDate: startDate,
            endDate: endDate,
            accessToken: validTokens.accessToken
        )

        return allMeetings.sorted()
    }

    // MARK: - Disconnect

    /// Removes stored tokens, effectively signing the user out.
    func disconnect() {
        KeychainHelper.delete(key: Self.keychainTokensKey)
        self.tokens = nil
    }

    // MARK: - OAuth Flow

    /// Present ASWebAuthenticationSession for the user to grant consent.
    /// Returns the authorization code on success, nil on failure/cancellation.
    private func presentAuthSession() async -> String? {
        guard var components = URLComponents(string: OutlookAuthConfig.authURL) else { return nil }

        components.queryItems = [
            URLQueryItem(name: "client_id", value: OutlookAuthConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: OutlookAuthConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: OutlookAuthConfig.calendarScope),
            URLQueryItem(name: "response_mode", value: "query")
        ]

        guard let authURL = components.url else { return nil }
        let scheme = OutlookAuthConfig.redirectURI.components(separatedBy: ":").first

        return await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: scheme
            ) { callbackURL, error in
                if let error = error {
                    print("MemCache: Outlook auth session error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let callbackURL = callbackURL,
                      let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: code)
            }

            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false

            DispatchQueue.main.async {
                session.start()
            }
        }
    }

    /// Exchange the authorization code for access and refresh tokens.
    private func exchangeCodeForTokens(_ code: String) async -> OutlookTokens? {
        guard let url = URL(string: OutlookAuthConfig.tokenURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "code": code,
            "client_id": OutlookAuthConfig.clientId,
            "redirect_uri": OutlookAuthConfig.redirectURI,
            "grant_type": "authorization_code",
            "scope": OutlookAuthConfig.calendarScope
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        return await performTokenRequest(request)
    }

    /// Use a refresh token to obtain a new access token.
    private func refreshAccessToken(using existingTokens: OutlookTokens) async -> OutlookTokens? {
        guard let refreshToken = existingTokens.refreshToken,
              let url = URL(string: OutlookAuthConfig.tokenURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "refresh_token": refreshToken,
            "client_id": OutlookAuthConfig.clientId,
            "grant_type": "refresh_token",
            "scope": OutlookAuthConfig.calendarScope
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        // Refresh responses may not include a new refresh_token — preserve the old one
        guard var newTokens = await performTokenRequest(request) else { return nil }
        if newTokens.refreshToken == nil {
            newTokens = OutlookTokens(
                accessToken: newTokens.accessToken,
                refreshToken: refreshToken,
                expiresAt: newTokens.expiresAt
            )
        }
        return newTokens
    }

    /// Shared helper that executes a token endpoint request and parses the response.
    private func performTokenRequest(_ request: URLRequest) async -> OutlookTokens? {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                print("MemCache: Outlook token request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                return nil
            }

            let refreshToken = json["refresh_token"] as? String
            let expiresIn = json["expires_in"] as? Double ?? 3600
            let expiresAt = Date().addingTimeInterval(expiresIn)

            let tokens = OutlookTokens(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: expiresAt
            )
            saveTokens(tokens)
            return tokens
        } catch {
            print("MemCache: Outlook token exchange error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Token Persistence

    private func saveTokens(_ tokens: OutlookTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        KeychainHelper.save(key: Self.keychainTokensKey, data: data)
    }

    private func loadTokens() -> OutlookTokens? {
        guard let data = KeychainHelper.load(key: Self.keychainTokensKey) else { return nil }
        return try? JSONDecoder().decode(OutlookTokens.self, from: data)
    }

    /// Returns a valid (non-expired) tokens object, refreshing if necessary.
    /// Falls back to nil if refresh also fails.
    private func ensureValidTokens() -> OutlookTokens? {
        guard let current = tokens ?? loadTokens() else { return nil }

        if !current.isExpired {
            return current
        }

        // Try synchronous refresh via semaphore so we can return from the sync protocol methods
        let semaphore = DispatchSemaphore(value: 0)
        var refreshed: OutlookTokens?

        Task {
            refreshed = await refreshAccessToken(using: current)
            semaphore.signal()
        }
        semaphore.wait()

        if let refreshed = refreshed {
            self.tokens = refreshed
            return refreshed
        }

        // Refresh failed — mark as unauthenticated
        disconnect()
        return nil
    }

    // MARK: - Calendar List API

    private struct OutlookCalendar {
        let id: String
        let name: String
        let color: String?
    }

    private func fetchCalendarList(accessToken: String) -> [OutlookCalendar] {
        guard let url = URL(string: "\(OutlookAuthConfig.graphAPIBase)/me/calendars") else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        var result: [OutlookCalendar] = []
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error = error {
                print("MemCache: Outlook calendar list error: \(error.localizedDescription)")
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["value"] as? [[String: Any]] else {
                return
            }

            result = items.compactMap { item in
                guard let id = item["id"] as? String,
                      let name = item["name"] as? String else { return nil }
                return OutlookCalendar(
                    id: id,
                    name: name,
                    color: item["color"] as? String
                )
            }
        }
        task.resume()
        semaphore.wait()

        return result
    }

    // MARK: - Calendar View Events API

    private func fetchCalendarViewEvents(
        calendars: [OutlookCalendar],
        startDate: Date,
        endDate: Date,
        accessToken: String
    ) -> [Meeting] {
        guard var components = URLComponents(
            string: "\(OutlookAuthConfig.graphAPIBase)/me/calendarview"
        ) else {
            return []
        }

        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime]

        components.queryItems = [
            URLQueryItem(name: "startDateTime", value: iso8601Formatter.string(from: startDate)),
            URLQueryItem(name: "endDateTime", value: iso8601Formatter.string(from: endDate)),
            URLQueryItem(name: "$select", value: "subject,start,end,location,body,isAllDay,onlineMeeting,webLink"),
            URLQueryItem(name: "$orderby", value: "start/dateTime"),
            URLQueryItem(name: "$top", value: "250")
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("outlook.timezone=\"UTC\"", forHTTPHeaderField: "Prefer")

        // Build a lookup from calendar ID to calendar info
        let calendarLookup = Dictionary(uniqueKeysWithValues: calendars.map { ($0.id, $0) })
        let defaultCalendar = calendars.first

        var meetings: [Meeting] = []
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error = error {
                print("MemCache: Outlook events fetch error: \(error.localizedDescription)")
                return
            }

            // Handle 401 — token may have been revoked
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                print("MemCache: Outlook API returned 401 — token may be invalid")
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["value"] as? [[String: Any]] else {
                return
            }

            meetings = items.compactMap { event in
                self.parseMeeting(from: event, calendarLookup: calendarLookup, defaultCalendar: defaultCalendar)
            }
        }
        task.resume()
        semaphore.wait()

        return meetings
    }

    // MARK: - Event Parsing

    private func parseMeeting(
        from event: [String: Any],
        calendarLookup: [String: OutlookCalendar],
        defaultCalendar: OutlookCalendar?
    ) -> Meeting? {
        guard let eventId = event["id"] as? String else { return nil }

        let title = event["subject"] as? String ?? "Untitled Event"
        let isAllDay = event["isAllDay"] as? Bool ?? false

        // Location
        let locationDict = event["location"] as? [String: Any]
        let location = locationDict?["displayName"] as? String

        // Notes (truncated to 500 chars)
        let bodyDict = event["body"] as? [String: Any]
        let bodyContent = bodyDict?["content"] as? String
        let notes: String? = bodyContent.map { String($0.prefix(500)) }

        // Start/end dates — Graph returns dateTime without "Z" when we request UTC via Prefer header
        let startDict = event["start"] as? [String: Any]
        let endDict = event["end"] as? [String: Any]

        guard let startDateTimeString = startDict?["dateTime"] as? String,
              let endDateTimeString = endDict?["dateTime"] as? String else {
            return nil
        }

        let startDate = parseGraphDateTime(startDateTimeString)
        let endDate = parseGraphDateTime(endDateTimeString)

        guard let start = startDate, let end = endDate else { return nil }

        // Join URL: prefer onlineMeeting.joinUrl, fall back to body content
        let joinURL = extractJoinURL(from: event)

        // Calendar info
        let calendarId = event["calendar@odata.associationLink"] as? String
        let calendar = calendarId.flatMap { calendarLookup[$0] } ?? defaultCalendar

        return Meeting(
            id: eventId,
            title: title,
            startDate: start,
            endDate: end,
            location: location,
            notes: notes,
            joinURL: joinURL,
            calendarName: calendar?.name ?? "Outlook",
            calendarColor: calendar?.color,
            isAllDay: isAllDay
        )
    }

    private func extractJoinURL(from event: [String: Any]) -> URL? {
        // Prefer onlineMeeting.joinUrl (Teams, Skype, etc.)
        if let onlineMeeting = event["onlineMeeting"] as? [String: Any],
           let joinUrlString = onlineMeeting["joinUrl"] as? String,
           let url = URL(string: joinUrlString) {
            return url
        }

        // Fall back to extracting a URL from the body content
        if let bodyDict = event["body"] as? [String: Any],
           let content = bodyDict["content"] as? String {
            return extractMeetingURLFromBody(content)
        }

        return nil
    }

    /// Attempts to find a Teams or meeting URL in the HTML body content.
    private func extractMeetingURLFromBody(_ body: String) -> URL? {
        let patterns = [
            "https://teams\\.microsoft\\.com/l/meetup-join/[^\"\\s<>]+",
            "https://meet\\.google\\.com/[^\"\\s<>]+",
            "https://[^\"\\s<>]*zoom\\.us/[^\"\\s<>]+"
        ]

        for pattern in patterns {
            if let range = body.range(of: pattern, options: .regularExpression),
               let url = URL(string: String(body[range])) {
                return url
            }
        }

        return nil
    }

    // MARK: - Date Parsing

    /// Parse a Graph API dateTime string. Graph returns format like "2024-01-15T10:00:00.0000000"
    /// when we set Prefer: outlook.timezone="UTC". We append "Z" to make it a proper UTC timestamp.
    private func parseGraphDateTime(_ string: String) -> Date? {
        let normalized = string.hasSuffix("Z") ? string : string + "Z"

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: normalized) { return date }

        // Retry without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: normalized)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension OutlookCalendarService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
    }
}
