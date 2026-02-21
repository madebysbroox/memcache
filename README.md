# MemCache - Mac Menu Bar Meeting Reminder For My Old Age

A minimal, elegant Mac menu bar application that keeps your upcoming meetings visible and accessible without cluttering your workflow.

## Features

- **Minimal Menu Bar Widget**: Shows next meeting time + brief title (e.g. "2:30 PM - Standup")
- **Smart Urgency Indicators**: Progressive color and style changes as meetings approach (30min / 15min / 5min thresholds) with subtle pulse animation for imminent meetings
- **Expandable Daily View**: Click to see full day's meeting schedule with times, durations, and locations
- **Meeting Join Links**: Auto-detects Zoom, Google Meet, Teams, Webex links with platform-specific one-click join buttons
- **Copy Meeting Details**: Copy meeting info to clipboard with visual feedback
- **Multi-Calendar Support**: Apple Calendar, Google Calendar, and Microsoft Outlook integration
- **Smart Caching & Polling**: Efficient calendar data caching with adaptive polling intervals
- **Accessibility**: VoiceOver support, keyboard navigation, respects Reduce Motion preference
- **Dark/Light Mode**: Full support for macOS appearance modes
- **Edge Case Handling**: In-progress meetings, all-day events, empty days, past meetings, network errors

## Requirements

- macOS 13.0 (Ventura) or later
- Calendar access permission
- For Google Calendar: OAuth 2.0 credentials from Google Cloud Console
- For Outlook: App registration in Azure Portal

## Getting Started

```bash
cd MemCache
# Open in Xcode
open Package.swift
# Or build from command line
swift build
```

1. Open `MemCache/Package.swift` in Xcode
2. Build and run (Cmd+R)
3. Grant calendar access when prompted
4. The app appears in your menu bar — click to see today's schedule

## Project Structure

```
MemCache/
├── Package.swift                          # Swift Package Manager manifest
├── Sources/MemCache/
│   ├── MemCacheApp.swift                  # App entry point
│   ├── AppDelegate.swift                  # Menu bar setup, popover, lifecycle
│   ├── Models/
│   │   └── Meeting.swift                  # Meeting data model + urgency levels
│   ├── Services/
│   │   ├── CalendarServiceProtocol.swift  # Shared calendar service protocol
│   │   ├── CalendarService.swift          # Apple Calendar (EventKit) integration
│   │   ├── GoogleCalendarService.swift    # Google Calendar (REST API + OAuth)
│   │   ├── GoogleAuthConfig.swift         # Google OAuth configuration
│   │   ├── OutlookCalendarService.swift   # Outlook Calendar (Graph API + OAuth)
│   │   ├── OutlookAuthConfig.swift        # Microsoft OAuth configuration
│   │   ├── KeychainHelper.swift           # Secure token storage
│   │   ├── CalendarAccountManager.swift   # Multi-account lifecycle management
│   │   ├── CalendarCache.swift            # Thread-safe calendar data cache
│   │   └── MeetingStore.swift             # Observable meeting state management
│   ├── Views/
│   │   ├── PopoverContentView.swift       # Main popover container
│   │   ├── MeetingListView.swift          # Daily schedule list with join buttons
│   │   └── SettingsView.swift             # Preferences window with calendar accounts
│   └── Utilities/
│       └── MenuBarFormatter.swift         # Smart title truncation + formatting
└── Resources/
    ├── Info.plist                          # App config (v2.0.0, LSUIElement, permissions)
    └── MemCache.entitlements              # Sandbox + calendar + network entitlements
```

## Documentation

- **[MenuBarMeetings.md](MenuBarMeetings.md)**: Complete project specification
- **[MenuBarMeetings-Sprints.md](MenuBarMeetings-Sprints.md)**: 8-sprint development roadmap

## Roadmap

- [x] **Sprints 1-2**: Foundation, menu bar, Apple Calendar integration
- [x] **Sprints 3-4**: Daily schedule popup, smart urgency display
- [x] **Sprints 5-6**: Google Calendar, multi-account support, advanced urgency & polish
- [x] **Sprints 7-8**: Outlook integration, performance optimization, accessibility, distribution prep

---

*Project conceived 2026-02-06*