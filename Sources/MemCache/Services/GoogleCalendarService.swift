@preconcurrency import AuthenticationServices
import Foundation

// MARK: - Token Model

/// OAuth 2.0 tokens persisted in the Keychain.
struct GoogleTokens: Codable {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date

    var isExpired: Bool {
        Date() >= expiresAt
    }
}

// MARK: - Google Calendar Service

/// Google Calendar provider that implements CalendarServiceProtocol.
/// Uses OAuth 2.0 (authorization code flow) via ASWebAuthenticationSession
/// and stores tokens in the Keychain.
final class GoogleCalendarService: NSObject, CalendarServiceProtocol {

    // MARK: - Constants

    private static let keychainTokensKey = "google_oauth_tokens"

    // MARK: - State

    private var tokens: GoogleTokens?

    // MARK: - CalendarServiceProtocol

    var providerType: CalendarProviderType { .google }

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
            print("MemCache: Google Calendar – not authenticated")
            return []
        }

        // Fetch the user's calendar list first
        let calendars = fetchCalendarList(accessToken: validTokens.accessToken)
        if calendars.isEmpty {
            return []
        }

        var allMeetings: [Meeting] = []

        for cal in calendars {
            let events = fetchEvents(
                calendarId: cal.id,
                calendarName: cal.summary,
                calendarColor: cal.backgroundColor,
                timeMin: startDate,
                timeMax: endDate,
                accessToken: validTokens.accessToken
            )
            allMeetings.append(contentsOf: events)
        }

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
        guard var components = URLComponents(string: GoogleAuthConfig.authURL) else { return nil }

        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleAuthConfig.clientId),
            URLQueryItem(name: "redirect_uri", value: GoogleAuthConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleAuthConfig.calendarScope),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        guard let authURL = components.url else { return nil }
        let scheme = GoogleAuthConfig.redirectURI.components(separatedBy: ":").first

        return await withCheckedContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: scheme
            ) { callbackURL, error in
                if let error = error {
                    print("MemCache: Google auth session error: \(error.localizedDescription)")
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
    private func exchangeCodeForTokens(_ code: String) async -> GoogleTokens? {
        guard let url = URL(string: GoogleAuthConfig.tokenURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "code": code,
            "client_id": GoogleAuthConfig.clientId,
            "redirect_uri": GoogleAuthConfig.redirectURI,
            "grant_type": "authorization_code"
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        return await performTokenRequest(request)
    }

    /// Use a refresh token to obtain a new access token.
    private func refreshAccessToken(using existingTokens: GoogleTokens) async -> GoogleTokens? {
        guard let refreshToken = existingTokens.refreshToken,
              let url = URL(string: GoogleAuthConfig.tokenURL) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyParams = [
            "refresh_token": refreshToken,
            "client_id": GoogleAuthConfig.clientId,
            "grant_type": "refresh_token"
        ]
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        // Refresh responses may not include a new refresh_token — preserve the old one
        guard var newTokens = await performTokenRequest(request) else { return nil }
        if newTokens.refreshToken == nil {
            newTokens = GoogleTokens(
                accessToken: newTokens.accessToken,
                refreshToken: refreshToken,
                expiresAt: newTokens.expiresAt
            )
        }
        return newTokens
    }

    /// Shared helper that executes a token endpoint request and parses the response.
    private func performTokenRequest(_ request: URLRequest) async -> GoogleTokens? {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode) else {
                print("MemCache: Google token request failed with status: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let accessToken = json["access_token"] as? String else {
                return nil
            }

            let refreshToken = json["refresh_token"] as? String
            let expiresIn = json["expires_in"] as? Double ?? 3600
            let expiresAt = Date().addingTimeInterval(expiresIn)

            let tokens = GoogleTokens(
                accessToken: accessToken,
                refreshToken: refreshToken,
                expiresAt: expiresAt
            )
            saveTokens(tokens)
            return tokens
        } catch {
            print("MemCache: Google token exchange error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Token Persistence

    private func saveTokens(_ tokens: GoogleTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        KeychainHelper.save(key: Self.keychainTokensKey, data: data)
    }

    private func loadTokens() -> GoogleTokens? {
        guard let data = KeychainHelper.load(key: Self.keychainTokensKey) else { return nil }
        return try? JSONDecoder().decode(GoogleTokens.self, from: data)
    }

    /// Returns a valid (non-expired) tokens object, refreshing if necessary.
    /// Falls back to nil if refresh also fails.
    private func ensureValidTokens() -> GoogleTokens? {
        guard let current = tokens ?? loadTokens() else { return nil }

        if !current.isExpired {
            return current
        }

        // Try synchronous refresh via semaphore so we can return from the sync protocol methods
        let semaphore = DispatchSemaphore(value: 0)
        var refreshed: GoogleTokens?

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

    private struct GoogleCalendar {
        let id: String
        let summary: String
        let backgroundColor: String?
    }

    private func fetchCalendarList(accessToken: String) -> [GoogleCalendar] {
        guard let url = URL(string: "\(GoogleAuthConfig.calendarAPIBase)/users/me/calendarList") else {
            return []
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        var result: [GoogleCalendar] = []
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error = error {
                print("MemCache: Google calendarList error: \(error.localizedDescription)")
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                return
            }

            result = items.compactMap { item in
                guard let id = item["id"] as? String,
                      let summary = item["summary"] as? String else { return nil }
                return GoogleCalendar(
                    id: id,
                    summary: summary,
                    backgroundColor: item["backgroundColor"] as? String
                )
            }
        }
        task.resume()
        semaphore.wait()

        return result
    }

    // MARK: - Events API

    private func fetchEvents(
        calendarId: String,
        calendarName: String,
        calendarColor: String?,
        timeMin: Date,
        timeMax: Date,
        accessToken: String
    ) -> [Meeting] {
        let encodedId = calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? calendarId

        guard var components = URLComponents(
            string: "\(GoogleAuthConfig.calendarAPIBase)/calendars/\(encodedId)/events"
        ) else {
            return []
        }

        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.formatOptions = [.withInternetDateTime]

        components.queryItems = [
            URLQueryItem(name: "timeMin", value: iso8601Formatter.string(from: timeMin)),
            URLQueryItem(name: "timeMax", value: iso8601Formatter.string(from: timeMax)),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime"),
            URLQueryItem(name: "maxResults", value: "250")
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        var meetings: [Meeting] = []
        let semaphore = DispatchSemaphore(value: 0)

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }

            if let error = error {
                print("MemCache: Google events fetch error: \(error.localizedDescription)")
                return
            }

            // Handle 401 — token may have been revoked
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                print("MemCache: Google API returned 401 — token may be invalid")
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let items = json["items"] as? [[String: Any]] else {
                return
            }

            meetings = items.compactMap { event in
                self.parseMeeting(from: event, calendarName: calendarName, calendarColor: calendarColor)
            }
        }
        task.resume()
        semaphore.wait()

        return meetings
    }

    // MARK: - Event Parsing

    private func parseMeeting(
        from event: [String: Any],
        calendarName: String,
        calendarColor: String?
    ) -> Meeting? {
        guard let eventId = event["id"] as? String else { return nil }

        let title = event["summary"] as? String ?? "Untitled Event"
        let location = event["location"] as? String
        let notes = event["description"] as? String

        // Determine start/end dates and whether the event is all-day
        let startDict = event["start"] as? [String: Any]
        let endDict = event["end"] as? [String: Any]

        var startDate: Date?
        var endDate: Date?
        var isAllDay = false

        if let dateTimeString = startDict?["dateTime"] as? String {
            startDate = parseISO8601(dateTimeString)
        } else if let dateString = startDict?["date"] as? String {
            startDate = parseDateOnly(dateString)
            isAllDay = true
        }

        if let dateTimeString = endDict?["dateTime"] as? String {
            endDate = parseISO8601(dateTimeString)
        } else if let dateString = endDict?["date"] as? String {
            endDate = parseDateOnly(dateString)
        }

        guard let start = startDate, let end = endDate else { return nil }

        // Extract join URL from hangoutLink or conferenceData
        let joinURL = extractJoinURL(from: event)

        return Meeting(
            id: eventId,
            title: title,
            startDate: start,
            endDate: end,
            location: location,
            notes: notes,
            joinURL: joinURL,
            calendarName: calendarName,
            calendarColor: calendarColor,
            isAllDay: isAllDay
        )
    }

    private func extractJoinURL(from event: [String: Any]) -> URL? {
        // Prefer hangoutLink (Google Meet)
        if let hangout = event["hangoutLink"] as? String, let url = URL(string: hangout) {
            return url
        }

        // Fall back to conferenceData entry points
        if let confData = event["conferenceData"] as? [String: Any],
           let entryPoints = confData["entryPoints"] as? [[String: Any]] {
            for entry in entryPoints {
                if let type = entry["entryPointType"] as? String, type == "video",
                   let uri = entry["uri"] as? String, let url = URL(string: uri) {
                    return url
                }
            }
        }

        return nil
    }

    // MARK: - Date Parsing

    private func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        // Retry without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private func parseDateOnly(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.date(from: string)
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension GoogleCalendarService: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
    }
}
