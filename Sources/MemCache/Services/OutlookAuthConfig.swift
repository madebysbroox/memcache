import Foundation

// To use Outlook Calendar integration you need to:
// 1. Register an application in the Azure Portal (https://portal.azure.com → Azure Active Directory → App registrations)
// 2. Add a "Mobile and desktop applications" platform with the redirect URI below
// 3. Under API permissions, add Microsoft Graph → Calendars.Read (delegated)
// 4. Replace the placeholder clientId with your Application (client) ID
// 5. No client secret is needed for public (native) apps — use PKCE if desired

/// Configuration constants for Microsoft Identity Platform OAuth 2.0 and Graph API.
enum OutlookAuthConfig {
    /// OAuth 2.0 Application (client) ID — replace with your own from Azure Portal.
    static let clientId = "YOUR_CLIENT_ID"

    /// Custom URL scheme redirect URI for macOS (Microsoft's recommended format).
    static let redirectURI = "msauth.com.memcache.app://auth"

    /// Microsoft Identity Platform v2.0 authorization endpoint (multi-tenant).
    static let authURL = "https://login.microsoftonline.com/common/oauth2/v2/authorize"

    /// Microsoft Identity Platform v2.0 token endpoint (multi-tenant).
    static let tokenURL = "https://login.microsoftonline.com/common/oauth2/v2/token"

    /// Scopes for read-only calendar access and offline refresh tokens.
    static let calendarScope = "Calendars.Read offline_access"

    /// Base URL for Microsoft Graph API v1.0.
    static let graphAPIBase = "https://graph.microsoft.com/v1.0"
}
