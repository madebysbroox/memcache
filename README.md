# MemCache - Mac Menu Bar Meeting Reminder For My Old Age

A minimal, elegant Mac menu bar application that keeps your upcoming meetings visible and accessible without cluttering your workflow.

## Features

- **Minimal Menu Bar Widget**: Shows next meeting time + brief title (e.g. "2:30 PM - Standup")
- **Smart Urgency Indicators**: Color and style changes as meetings approach (30min / 15min / 5min thresholds)
- **Expandable Daily View**: Click to see full day's meeting schedule with times, durations, and locations
- **Meeting Join Links**: Auto-detects Zoom, Google Meet, Teams links with one-click join
- **Apple Calendar Integration**: Reads events via EventKit with proper permission handling
- **Edge Case Handling**: In-progress meetings, all-day events, empty days, past meetings

## Requirements

- macOS 13.0 (Ventura) or later
- Calendar access permission

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
│   │   ├── CalendarService.swift          # EventKit integration
│   │   └── MeetingStore.swift             # Observable meeting state management
│   ├── Views/
│   │   ├── PopoverContentView.swift       # Main popover container
│   │   ├── MeetingListView.swift          # Daily schedule list
│   │   └── SettingsView.swift             # Preferences window
│   └── Utilities/
│       └── MenuBarFormatter.swift         # Smart title truncation + formatting
└── Resources/
    ├── Info.plist                          # App config (LSUIElement, calendar permissions)
    └── MemCache.entitlements              # Sandbox + calendar entitlements
```

## Documentation

- **[MenuBarMeetings.md](MenuBarMeetings.md)**: Complete project specification
- **[MenuBarMeetings-Sprints.md](MenuBarMeetings-Sprints.md)**: 8-sprint development roadmap

## Roadmap

- [x] **Sprints 1-2**: Foundation, menu bar, Apple Calendar integration
- [x] **Sprints 3-4**: Daily schedule popup, smart urgency display
- [ ] **Sprints 5-6**: Google Calendar, multi-account support
- [ ] **Sprints 7-8**: Outlook integration, polish, distribution

---

*Project conceived 2026-02-06*