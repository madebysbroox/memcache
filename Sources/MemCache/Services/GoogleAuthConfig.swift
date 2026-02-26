import Foundation

// To use Google Calendar integration you need to:
// 1. Create a project in the Google Cloud Console (https://console.cloud.google.com)
// 2. Enable the Google Calendar API for that project
// 3. Create OAuth 2.0 credentials (Desktop / iOS application type)
// 4. Set the redirect URI to the custom URL scheme below
// 5. Replace the placeholder clientId with your own

/// Configuration constants for Google OAuth 2.0 and Calendar API.
enum GoogleAuthConfig {
    /// OAuth 2.0 client ID — replace with your own from Google Cloud Console.
    static let clientId = "YOUR_CLIENT_ID.apps.googleusercontent.com"

    /// Custom URL scheme redirect URI used to capture the authorization code.
    static let redirectURI = "com.memcache.app:/oauth2callback"

    /// Google OAuth 2.0 authorization endpoint.
    static let authURL = "https://accounts.google.com/o/oauth2/v2/auth"

    /// Google OAuth 2.0 token endpoint.
    static let tokenURL = "https://oauth2.googleapis.com/token"

    /// Scope for read-only access to Google Calendar.
    static let calendarScope = "https://www.googleapis.com/auth/calendar.readonly"

    /// Base URL for the Google Calendar v3 API.
    static let calendarAPIBase = "https://www.googleapis.com/calendar/v3"
}
