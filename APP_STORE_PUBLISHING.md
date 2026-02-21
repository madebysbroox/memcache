# Publishing MemCache to the Mac App Store

Step-by-step guide to get MemCache from source code to listed on the Mac App Store.

---

## Prerequisites

- Mac running macOS 13.0 or later
- Xcode 15+ installed
- An Apple Developer Program membership ($99/year) at https://developer.apple.com/programs/

---

## Step 1: Enroll in the Apple Developer Program

1. Go to https://developer.apple.com/programs/
2. Sign in with your Apple ID (or create one)
3. Follow enrollment steps -- requires payment of $99/year
4. Wait for approval (usually within 48 hours)

---

## Step 2: Create an Xcode Project (Migrate from SPM)

MemCache currently uses Swift Package Manager. For App Store distribution, you need a proper Xcode project.

1. Open Xcode and select **File > New > Project**
2. Choose **macOS > App** template
3. Configure:
   - **Product Name**: MemCache
   - **Team**: Select your Apple Developer team
   - **Organization Identifier**: com.memcache
   - **Bundle Identifier**: com.memcache.app
   - **Interface**: SwiftUI
   - **Language**: Swift
4. Save the project alongside the existing code
5. Remove the auto-generated ContentView.swift and MemCacheApp.swift
6. Drag all files from `Sources/MemCache/` into the Xcode project navigator
7. Drag `Resources/Info.plist` and `Resources/MemCache.entitlements` into the project
8. In **Project Settings > General**:
   - Set **Minimum Deployments** to macOS 13.0
   - Set **Version** to 2.0.0
   - Set **Build** to 2
9. In **Project Settings > Build Settings**:
   - Set **Info.plist File** to the path of your Info.plist
   - Set **Code Signing Entitlements** to the path of MemCache.entitlements

---

## Step 3: Configure Signing & Capabilities

1. In Xcode, select the project in the navigator
2. Go to **Signing & Capabilities** tab
3. Check **Automatically manage signing**
4. Select your **Team** from the dropdown
5. Verify the **Bundle Identifier** is `com.memcache.app`
6. Verify these capabilities are listed:
   - **App Sandbox** (enabled)
   - **Calendars** (Read access)
   - **Outgoing Connections (Client)** (for Google/Outlook API calls)
7. If any capability is missing, click **+ Capability** and add it

---

## Step 4: Configure App Icons

1. In Xcode, open **Assets.xcassets**
2. Click **AppIcon**
3. Provide app icon images at all required sizes:
   - 16x16, 32x32, 64x64, 128x128, 256x256, 512x512, 1024x1024
   - Each size needs 1x and 2x variants
4. Use a tool like Icon Composer, Sketch, or Figma to create the icon set
5. Alternatively, use a single 1024x1024 image and let Xcode auto-generate sizes (Xcode 15+)

---

## Step 5: Set Up Google Calendar Credentials (Required Before Submission)

1. Go to https://console.cloud.google.com
2. Create a new project (or use existing)
3. Enable the **Google Calendar API**
4. Go to **Credentials > Create Credentials > OAuth 2.0 Client ID**
5. Select **iOS** application type (works for macOS too)
6. Set the **Bundle ID** to `com.memcache.app`
7. Copy the **Client ID**
8. Open `Sources/MemCache/Services/GoogleAuthConfig.swift`
9. Replace `YOUR_CLIENT_ID.apps.googleusercontent.com` with your actual Client ID
10. Configure the **OAuth consent screen**:
    - App name: MemCache
    - Scopes: `calendar.readonly`
    - Submit for verification (required for production apps)

---

## Step 6: Set Up Outlook Credentials (Required Before Submission)

1. Go to https://portal.azure.com > **Azure Active Directory > App registrations**
2. Click **New registration**
   - Name: MemCache
   - Supported account types: **Accounts in any organizational directory and personal Microsoft accounts**
   - Redirect URI: **Public client/native** with value `msauth.com.memcache.app://auth`
3. Copy the **Application (client) ID**
4. Open `Sources/MemCache/Services/OutlookAuthConfig.swift`
5. Replace `YOUR_CLIENT_ID` with your actual Client ID
6. Under **API permissions**, add:
   - Microsoft Graph > Delegated > `Calendars.Read`
   - Microsoft Graph > Delegated > `offline_access`
7. Click **Grant admin consent** if applicable

---

## Step 7: Register a Custom URL Scheme

For OAuth callbacks, register the URL schemes in Info.plist:

1. In Xcode, open **Info.plist** (or use the Info tab in project settings)
2. Add **URL Types** array with two entries:

**Entry 1 -- Google OAuth:**
- URL Schemes: `com.memcache.app`
- URL Identifier: `com.memcache.app.google-oauth`
- Role: Viewer

**Entry 2 -- Microsoft OAuth:**
- URL Schemes: `msauth.com.memcache.app`
- URL Identifier: `com.memcache.app.outlook-oauth`
- Role: Viewer

---

## Step 8: Test the Release Build

1. In Xcode, set the scheme to **MemCache** and target to **My Mac**
2. Select **Product > Archive** (this builds a release version)
3. If the archive succeeds, Xcode opens the **Organizer** window
4. Before distributing, test the archived build:
   - In Organizer, right-click the archive > **Show in Finder**
   - Right-click the .xcarchive > **Show Package Contents**
   - Navigate to `Products/Applications/` and run MemCache.app
5. Verify:
   - App appears in menu bar (not in Dock)
   - Calendar permission prompt appears
   - Apple Calendar events display correctly
   - Google Calendar OAuth flow works
   - Outlook Calendar OAuth flow works
   - Urgency indicators work
   - Settings window opens and all tabs function
   - Quit button works

---

## Step 9: Create the App Store Listing

1. Go to https://appstoreconnect.apple.com
2. Click **My Apps > + > New App**
3. Fill in:
   - **Platform**: macOS
   - **Name**: MemCache
   - **Primary Language**: English (U.S.)
   - **Bundle ID**: com.memcache.app (select from dropdown)
   - **SKU**: memcache-macos (any unique string)
4. Fill in the **App Information** tab:
   - **Subtitle**: Menu Bar Meeting Reminder
   - **Category**: Productivity
   - **Secondary Category**: Business
   - **Privacy Policy URL**: (required -- host a privacy policy page)
5. Fill in the **Pricing and Availability** tab:
   - Select price tier (or Free)
   - Select availability by country

---

## Step 10: Prepare App Store Screenshots

You need screenshots for the Mac App Store listing:

- **Required size**: 1280x800 or 1440x900 (or Retina equivalents)
- **Up to 10 screenshots** per localization
- Recommended screenshots:
  1. Menu bar showing next meeting with urgency indicator
  2. Expanded popover with full day's schedule
  3. Meeting with "Join Zoom" button visible
  4. Settings window -- Calendars tab showing connected accounts
  5. Settings window -- General tab
  6. Menu bar in dark mode

Take screenshots using **Cmd+Shift+4** (area) or **Cmd+Shift+5** (options).

---

## Step 11: Write the App Store Description

**Suggested description:**

> MemCache keeps your upcoming meetings visible in your Mac's menu bar without cluttering your workflow.
>
> Glance at the menu bar to see your next meeting. As it approaches, visual urgency indicators draw your attention with progressive color changes and subtle animation. Click to expand a clean daily schedule view with all your meetings, times, and one-click join buttons.
>
> Features:
> - See your next meeting at a glance in the menu bar
> - Progressive urgency indicators as meetings approach
> - Full daily schedule in an expandable popup
> - One-click join for Zoom, Google Meet, Teams, and Webex
> - Apple Calendar, Google Calendar, and Outlook support
> - Smart caching and adaptive polling for efficiency
> - Full VoiceOver and keyboard navigation support
> - Respects system dark/light mode and Reduce Motion
>
> MemCache is the perfect balance of visibility and minimalism -- always present, never intrusive until it matters.

---

## Step 12: Submit for App Review

1. In Xcode Organizer, select your archive
2. Click **Distribute App**
3. Select **App Store Connect**
4. Choose **Upload**
5. Follow the prompts (signing, entitlements verification)
6. Wait for processing (usually 15-30 minutes)
7. In App Store Connect, go to your app
8. Under the version, select the uploaded build
9. Fill in:
   - **What's New**: Describe features (for updates)
   - **App Review Information**: Provide demo account details if needed, contact info
   - **Notes for Review**: Explain calendar access requirement, mention OAuth flows for Google/Outlook
10. Click **Submit for Review**

---

## Step 13: App Review Process

- **Typical review time**: 24-48 hours (can vary)
- **Common rejection reasons for this type of app**:
  - Missing privacy policy
  - Calendar permission description not clear enough
  - OAuth consent screen not verified by Google
  - App doesn't function without calendar access (must handle gracefully -- MemCache already does this)
- If rejected, read the rejection notes carefully, fix the issues, and resubmit

---

## Step 14: Post-Approval

Once approved:
1. Your app goes live on the Mac App Store
2. Set up **TestFlight** for future beta testing
3. Monitor **Crash Reports** in App Store Connect
4. Respond to **Customer Reviews**
5. For updates: increment version in Info.plist, archive, and submit again

---

## Quick Reference: Key Identifiers

| Item | Value |
|------|-------|
| Bundle ID | `com.memcache.app` |
| Version | 2.0.0 |
| Build | 2 |
| Min macOS | 13.0 |
| Entitlements | sandbox, calendars, network.client |
| Google OAuth Redirect | `com.memcache.app:/oauth2callback` |
| Outlook OAuth Redirect | `msauth.com.memcache.app://auth` |
