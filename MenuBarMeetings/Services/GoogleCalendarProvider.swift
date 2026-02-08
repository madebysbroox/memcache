import Foundation
import SwiftUI
import AppKit

/// Google Calendar provider using OAuth 2.0 + REST API.
///
/// Setup required before this provider can work:
/// 1. Create a project in Google Cloud Console
/// 2. Enable the Google Calendar API
/// 3. Create an OAuth 2.0 Client ID (macOS / Desktop app type)
/// 4. Set `GoogleCalendarProvider.clientID` to your client ID
///
/// The provider uses the loopback redirect flow (http://127.0.0.1) which
/// does not require a client secret for public/desktop clients.
final class GoogleCalendarProvider: CalendarProvider {
    let name = "Google Calendar"

    private(set) var status: CalendarProviderStatus = .notConfigured

    private var tokens: OAuthTokens?

    // MARK: - Configuration (fill in from Google Cloud Console)

    /// Your OAuth 2.0 client ID from Google Cloud Console.
    /// Leave empty to disable Google Calendar.
    static var clientID: String = ""

    private static let scopes = "https://www.googleapis.com/auth/calendar.readonly"
    private static let authURL = "https://accounts.google.com/o/oauth2/v2/auth"
    private static let tokenURL = "https://oauth2.googleapis.com/token"
    private static let calendarListURL = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
    private static let keychainKey = "google_oauth_tokens"

    // MARK: - Token storage

    struct OAuthTokens: Codable {
        var accessToken: String
        var refreshToken: String?
        var expiresAt: Date
    }

    // MARK: - Init

    init() {
        if let saved = KeychainHelper.read(key: Self.keychainKey, as: OAuthTokens.self) {
            tokens = saved
            status = .authorized
        }
    }

    // MARK: - CalendarProvider

    func requestAccess() async {
        guard !Self.clientID.isEmpty else {
            status = .error("Google Calendar client ID not configured.")
            return
        }

        do {
            let code = try await startOAuthFlow()
            let newTokens = try await exchangeCodeForTokens(code: code)
            tokens = newTokens
            
            guard KeychainHelper.save(key: Self.keychainKey, value: newTokens) else {
                status = .error("Failed to save Google credentials to Keychain.")
                return
            }
            
            status = .authorized
        } catch {
            status = .error("Google sign-in failed: \(error.localizedDescription)")
        }
    }

    func fetchTodaysMeetings() async -> [Meeting] {
        guard let tokens = tokens else { return [] }

        var accessToken = tokens.accessToken

        // Refresh if expired
        if Date() >= tokens.expiresAt, let refreshed = try? await refreshAccessToken() {
            self.tokens = refreshed
            
            // Best effort save - if it fails, continue with the valid token in memory
            _ = KeychainHelper.save(key: Self.keychainKey, value: refreshed)
            
            accessToken = refreshed.accessToken
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: startOfDay)
        let timeMax = formatter.string(from: endOfDay)

        var components = URLComponents(string: Self.calendarListURL)!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMin),
            URLQueryItem(name: "timeMax", value: timeMax),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["items"] as? [[String: Any]] else {
            return []
        }

        return items.compactMap { item in
            parseMeeting(from: item)
        }
    }

    /// Disconnect: clear tokens and reset status.
    func signOut() {
        tokens = nil
        KeychainHelper.delete(key: Self.keychainKey)
        status = .notConfigured
    }

    // MARK: - OAuth Flow

    /// Opens the system browser for Google sign-in and listens on a loopback port for the redirect.
    private func startOAuthFlow() async throws -> String {
        let redirectPort: UInt16 = 8089
        let redirectURI = "http://127.0.0.1:\(redirectPort)"

        var components = URLComponents(string: Self.authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scopes),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]

        // Open browser
        NSWorkspace.shared.open(components.url!)

        // Listen for the redirect on a local socket
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let code = try Self.listenForOAuthRedirect(port: redirectPort)
                    continuation.resume(returning: code)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Minimal TCP listener that captures the OAuth authorization code from the redirect.
    private static func listenForOAuthRedirect(port: UInt16) throws -> String {
        let serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else { throw OAuthError.socketFailed }

        var reuseAddr: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuseAddr, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY

        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(serverSocket)
            throw OAuthError.bindFailed
        }

        listen(serverSocket, 1)
        let clientSocket = accept(serverSocket, nil, nil)
        close(serverSocket)
        guard clientSocket >= 0 else { throw OAuthError.acceptFailed }

        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = recv(clientSocket, &buffer, buffer.count, 0)
        let requestString = String(bytes: buffer[..<bytesRead], encoding: .utf8) ?? ""

        // Send a simple HTML response so the user sees something
        let response = """
        HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n\
        <html><body><h2>Sign-in complete</h2><p>You can close this tab and return to MenuBar Meetings.</p></body></html>
        """
        _ = response.withCString { send(clientSocket, $0, strlen($0), 0) }
        close(clientSocket)

        // Parse the code from "GET /?code=XXXX&scope=... HTTP/1.1"
        guard let url = URLComponents(string: "http://localhost" + (requestString.split(separator: " ").dropFirst().first.map(String.init) ?? "")),
              let code = url.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.noCode
        }

        return code
    }

    // MARK: - Token Exchange

    private func exchangeCodeForTokens(code: String) async throws -> OAuthTokens {
        let redirectURI = "http://127.0.0.1:8089"
        let body = [
            "code": code,
            "client_id": Self.clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code"
        ]

        return try await postTokenRequest(body: body)
    }

    private func refreshAccessToken() async throws -> OAuthTokens {
        guard let refreshToken = tokens?.refreshToken else { throw OAuthError.noRefreshToken }

        let body = [
            "refresh_token": refreshToken,
            "client_id": Self.clientID,
            "grant_type": "refresh_token"
        ]

        return try await postTokenRequest(body: body)
    }

    private func postTokenRequest(body: [String: String]) async throws -> OAuthTokens {
        var request = URLRequest(url: URL(string: Self.tokenURL)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let accessToken = json["access_token"] as? String else {
            throw OAuthError.tokenParseFailed
        }

        let expiresIn = json["expires_in"] as? Int ?? 3600
        let refreshToken = json["refresh_token"] as? String ?? tokens?.refreshToken

        return OAuthTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        )
    }

    // MARK: - Event Parsing

    private func parseMeeting(from item: [String: Any]) -> Meeting? {
        guard let id = item["id"] as? String,
              let summary = item["summary"] as? String else { return nil }

        let startDict = item["start"] as? [String: Any] ?? [:]
        let endDict   = item["end"] as? [String: Any] ?? [:]

        let isAllDay = startDict["date"] != nil
        let isoFormatter = ISO8601DateFormatter()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let startDate: Date
        let endDate: Date

        if isAllDay {
            guard let s = startDict["date"] as? String, let e = endDict["date"] as? String,
                  let sd = dateFormatter.date(from: s), let ed = dateFormatter.date(from: e) else { return nil }
            startDate = sd
            endDate = ed
        } else {
            guard let s = startDict["dateTime"] as? String, let e = endDict["dateTime"] as? String,
                  let sd = isoFormatter.date(from: s), let ed = isoFormatter.date(from: e) else { return nil }
            startDate = sd
            endDate = ed
        }

        let location = item["location"] as? String
        let hangoutLink = item["hangoutLink"] as? String

        return Meeting(
            id: "google_\(id)",
            title: summary,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            url: hangoutLink.flatMap(URL.init(string:)),
            calendarName: "Google",
            calendarColor: .blue
        )
    }

    // MARK: - Errors

    enum OAuthError: LocalizedError {
        case socketFailed, bindFailed, acceptFailed, noCode
        case tokenParseFailed, noRefreshToken

        var errorDescription: String? {
            switch self {
            case .socketFailed:     return "Failed to create socket for OAuth redirect."
            case .bindFailed:       return "Failed to bind to port for OAuth redirect."
            case .acceptFailed:     return "Failed to accept OAuth redirect connection."
            case .noCode:           return "No authorization code received from Google."
            case .tokenParseFailed: return "Failed to parse tokens from Google."
            case .noRefreshToken:   return "No refresh token available."
            }
        }
    }
}
