import Foundation
import SwiftUI
import AppKit

/// Microsoft Outlook provider using Microsoft Graph API + OAuth 2.0.
///
/// Setup required before this provider can work:
/// 1. Register an app in Azure Portal (Azure Active Directory → App registrations)
/// 2. Add "Mobile and desktop applications" platform with redirect URI
///    `http://localhost:8090`
/// 3. Under API permissions, add `Calendars.Read` (delegated)
/// 4. Set `OutlookCalendarProvider.clientID` to your Application (client) ID
///
/// Uses authorization code flow with PKCE for public/desktop clients
/// (no client secret required).
final class OutlookCalendarProvider: CalendarProvider {
    let name = "Microsoft Outlook"

    private(set) var status: CalendarProviderStatus = .notConfigured

    private var tokens: OAuthTokens?

    // MARK: - Configuration (fill in from Azure Portal)

    /// Application (client) ID from Azure App Registration.
    /// Leave empty to disable Outlook.
    static var clientID: String = ""

    private static let tenantID = "common" // supports personal + work accounts
    private static let scopes = "Calendars.Read offline_access"
    private static let redirectPort: UInt16 = 8090
    private static let redirectURI = "http://localhost:8090"
    private static let keychainKey = "outlook_oauth_tokens"

    private static var authURL: String {
        "https://login.microsoftonline.com/\(tenantID)/oauth2/v2.0/authorize"
    }
    private static var tokenURL: String {
        "https://login.microsoftonline.com/\(tenantID)/oauth2/v2.0/token"
    }
    private static let eventsURL = "https://graph.microsoft.com/v1.0/me/calendarview"

    // MARK: - Token storage

    struct OAuthTokens: Codable {
        var accessToken: String
        var refreshToken: String?
        var expiresAt: Date
    }

    // MARK: - PKCE

    private var codeVerifier: String = ""

    private static func generateCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func codeChallenge(from verifier: String) -> String {
        let data = Data(verifier.utf8)
        var hash = [UInt8](repeating: 0, count: 32)
        data.withUnsafeBytes { ptr in
            _ = CC_SHA256(ptr.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
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
            status = .error("Outlook client ID not configured.")
            return
        }

        do {
            let code = try await startOAuthFlow()
            let newTokens = try await exchangeCodeForTokens(code: code)
            tokens = newTokens
            KeychainHelper.save(key: Self.keychainKey, value: newTokens)
            status = .authorized
        } catch {
            status = .error("Outlook sign-in failed: \(error.localizedDescription)")
        }
    }

    func fetchTodaysMeetings() async -> [Meeting] {
        guard var currentTokens = tokens else { return [] }

        // Refresh if expired
        if Date() >= currentTokens.expiresAt {
            guard let refreshed = try? await refreshAccessToken() else { return [] }
            currentTokens = refreshed
            tokens = refreshed
            KeychainHelper.save(key: Self.keychainKey, value: refreshed)
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

        let formatter = ISO8601DateFormatter()
        let startTime = formatter.string(from: startOfDay)
        let endTime = formatter.string(from: endOfDay)

        var components = URLComponents(string: Self.eventsURL)!
        components.queryItems = [
            URLQueryItem(name: "startDateTime", value: startTime),
            URLQueryItem(name: "endDateTime", value: endTime),
            URLQueryItem(name: "$orderby", value: "start/dateTime"),
            URLQueryItem(name: "$select", value: "id,subject,start,end,isAllDay,location,onlineMeeting,webLink")
        ]

        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(currentTokens.accessToken)", forHTTPHeaderField: "Authorization")

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = json["value"] as? [[String: Any]] else {
            return []
        }

        return items.compactMap { parseMeeting(from: $0) }
    }

    /// Disconnect: clear tokens and reset status.
    func signOut() {
        tokens = nil
        KeychainHelper.delete(key: Self.keychainKey)
        status = .notConfigured
    }

    // MARK: - OAuth Flow (PKCE)

    private func startOAuthFlow() async throws -> String {
        codeVerifier = Self.generateCodeVerifier()
        let challenge = Self.codeChallenge(from: codeVerifier)

        var components = URLComponents(string: Self.authURL)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: Self.clientID),
            URLQueryItem(name: "redirect_uri", value: Self.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: Self.scopes),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "prompt", value: "select_account")
        ]

        NSWorkspace.shared.open(components.url!)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().async {
                do {
                    let code = try Self.listenForOAuthRedirect(port: Self.redirectPort)
                    continuation.resume(returning: code)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

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

        let response = """
        HTTP/1.1 200 OK\r\nContent-Type: text/html\r\n\r\n\
        <html><body><h2>Sign-in complete</h2><p>You can close this tab and return to MenuBar Meetings.</p></body></html>
        """
        _ = response.withCString { send(clientSocket, $0, strlen($0), 0) }
        close(clientSocket)

        guard let url = URLComponents(string: "http://localhost" + (requestString.split(separator: " ").dropFirst().first.map(String.init) ?? "")),
              let code = url.queryItems?.first(where: { $0.name == "code" })?.value else {
            throw OAuthError.noCode
        }

        return code
    }

    // MARK: - Token Exchange

    private func exchangeCodeForTokens(code: String) async throws -> OAuthTokens {
        let body: [String: String] = [
            "code": code,
            "client_id": Self.clientID,
            "redirect_uri": Self.redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": codeVerifier
        ]
        return try await postTokenRequest(body: body)
    }

    private func refreshAccessToken() async throws -> OAuthTokens {
        guard let refreshToken = tokens?.refreshToken else { throw OAuthError.noRefreshToken }

        let body: [String: String] = [
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
        request.httpBody = body.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&").data(using: .utf8)

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
              let subject = item["subject"] as? String else { return nil }

        let isAllDay = item["isAllDay"] as? Bool ?? false
        let startDict = item["start"] as? [String: Any] ?? [:]
        let endDict   = item["end"] as? [String: Any] ?? [:]

        let isoFormatter = ISO8601DateFormatter()
        // Graph API returns dateTime without timezone offset for non-allday events
        let flexFormatter = DateFormatter()
        flexFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSS"
        flexFormatter.timeZone = TimeZone(identifier: startDict["timeZone"] as? String ?? "UTC")

        let dateOnlyFormatter = DateFormatter()
        dateOnlyFormatter.dateFormat = "yyyy-MM-dd"

        let startDate: Date
        let endDate: Date

        if isAllDay {
            guard let s = startDict["dateTime"] as? String, let e = endDict["dateTime"] as? String else { return nil }
            startDate = dateOnlyFormatter.date(from: String(s.prefix(10))) ?? isoFormatter.date(from: s) ?? Date()
            endDate   = dateOnlyFormatter.date(from: String(e.prefix(10))) ?? isoFormatter.date(from: e) ?? Date()
        } else {
            guard let s = startDict["dateTime"] as? String, let e = endDict["dateTime"] as? String else { return nil }
            startDate = flexFormatter.date(from: s) ?? isoFormatter.date(from: s) ?? Date()
            endDate   = flexFormatter.date(from: e) ?? isoFormatter.date(from: e) ?? Date()
        }

        let locationDict = item["location"] as? [String: Any]
        let location = locationDict?["displayName"] as? String

        let onlineMeeting = item["onlineMeeting"] as? [String: Any]
        let joinUrl = (onlineMeeting?["joinUrl"] as? String).flatMap(URL.init(string:))

        return Meeting(
            id: "outlook_\(id)",
            title: subject,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            location: location,
            url: joinUrl,
            calendarName: "Outlook",
            calendarColor: .indigo
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
            case .noCode:           return "No authorization code received from Microsoft."
            case .tokenParseFailed: return "Failed to parse tokens from Microsoft."
            case .noRefreshToken:   return "No refresh token available."
            }
        }
    }
}
