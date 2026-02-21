# Creating an iOS Version of MemCache

Step-by-step guide to build an iOS companion app for MemCache, bringing meeting reminders to iPhone and iPad.

---

## Overview

The macOS MemCache app is a menu bar widget. iOS doesn't have a menu bar, so the iOS version needs a different UX strategy. The best iOS equivalents are:

- **Lock Screen / Home Screen Widget** (WidgetKit) -- shows next meeting at a glance
- **Live Activity** (ActivityKit) -- persistent banner during upcoming/in-progress meetings
- **Main App** -- full daily schedule view (similar to the macOS popover)
- **Notifications** -- urgency alerts at 30min, 15min, 5min thresholds
- **Watch Complication** (optional) -- Apple Watch glanceable meeting info

---

## Step 1: Project Setup

### Option A: Add iOS Target to Existing Xcode Project

1. Open the MemCache Xcode project (or create one per APP_STORE_PUBLISHING.md)
2. **File > New > Target**
3. Choose **iOS > App**
4. Configure:
   - **Product Name**: MemCache
   - **Bundle Identifier**: com.memcache.app.ios
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Minimum Deployment**: iOS 17.0 (for interactive widgets and Live Activities)
5. Add a second target for the widget: **File > New > Target > Widget Extension**
   - **Product Name**: MemCacheWidget
   - Check **Include Live Activity**

### Option B: Create a Separate iOS Project

1. **File > New > Project > iOS > App**
2. Same configuration as above
3. Share code via a local Swift Package for the shared models/services

### Recommended: Shared Code via Swift Package

Create a shared package for code reuse between macOS and iOS:

```
MemCacheShared/
├── Package.swift
└── Sources/MemCacheShared/
    ├── Models/
    │   └── Meeting.swift          # Shared meeting model
    ├── Services/
    │   ├── CalendarServiceProtocol.swift
    │   ├── GoogleCalendarService.swift
    │   ├── GoogleAuthConfig.swift
    │   ├── OutlookCalendarService.swift
    │   ├── OutlookAuthConfig.swift
    │   ├── KeychainHelper.swift
    │   └── CalendarCache.swift
    └── Utilities/
        └── MeetingFormatter.swift  # Shared formatting logic
```

Both the macOS and iOS apps would depend on this package. Platform-specific code (AppDelegate, Views, Widgets) stays in each target.

---

## Step 2: Identify Shared vs. Platform-Specific Code

### Shared (reuse directly)
| File | Notes |
|------|-------|
| `Meeting.swift` | Model is platform-independent |
| `CalendarServiceProtocol.swift` | Protocol is platform-independent |
| `GoogleCalendarService.swift` | Uses Foundation + AuthenticationServices (both available on iOS) |
| `GoogleAuthConfig.swift` | Constants, platform-independent |
| `OutlookCalendarService.swift` | Same as Google -- Foundation + AuthenticationServices |
| `OutlookAuthConfig.swift` | Constants, platform-independent |
| `KeychainHelper.swift` | Security framework works on iOS |
| `CalendarCache.swift` | Pure Foundation |
| `MenuBarFormatter.swift` | Rename to `MeetingFormatter.swift`, reuse truncation logic |

### Needs Adaptation
| File | macOS Version | iOS Adaptation |
|------|--------------|----------------|
| `AppleCalendarService.swift` | Uses EventKit | Same EventKit API, but iOS permission flow differs slightly |
| `CalendarAccountManager.swift` | Singleton with NSObject | Same pattern, but UI triggers differ |
| `MeetingStore.swift` | ObservableObject with Combine | Same, but add widget timeline support |

### iOS-Only (new code)
| Component | Description |
|-----------|-------------|
| `MemCacheApp.swift` (iOS) | iOS app entry point with NavigationStack |
| `DailyScheduleView.swift` | Main app view (full screen version of macOS popover) |
| `MeetingRowView.swift` (iOS) | Redesigned for touch -- larger tap targets, swipe actions |
| `SettingsView.swift` (iOS) | iOS-style settings with NavigationLink |
| `WidgetProvider.swift` | WidgetKit timeline provider |
| `WidgetViews.swift` | Widget UI for small/medium/large sizes |
| `LiveActivityManager.swift` | Start/update/end Live Activities |
| `NotificationManager.swift` | Schedule local notifications at urgency thresholds |

---

## Step 3: Implement the iOS App

### 3a: Main App View

```
iOS App Structure:
├── MemCacheApp.swift              # @main entry, TabView or NavigationStack
├── Views/
│   ├── DailyScheduleView.swift    # Today's meetings (main tab)
│   ├── MeetingDetailView.swift    # Tap a meeting for full details + actions
│   ├── CalendarAccountsView.swift # Manage connected calendars
│   └── SettingsView.swift         # Preferences
├── Services/
│   └── NotificationManager.swift  # UNUserNotificationCenter scheduling
└── Extensions/
    └── Meeting+iOS.swift          # iOS-specific Meeting extensions
```

**DailyScheduleView** should include:
- Header with today's date
- "Next meeting" hero card at top (with urgency coloring)
- Scrollable list of all today's meetings
- Pull-to-refresh
- Tap meeting to see detail / join / copy

**MeetingDetailView** should include:
- Full meeting title, time range, duration
- Location with "Open in Maps" button
- Join meeting button (large, prominent)
- Copy details button
- Calendar name and color indicator

### 3b: iOS-Specific EventKit Differences

The `AppleCalendarService` needs minor adjustments for iOS:

```swift
// iOS requires different permission handling
import EventKit

class AppleCalendarService: CalendarServiceProtocol {
    func requestAccess() async -> Bool {
        // iOS 17+ uses requestFullAccessToEvents() -- same as macOS 14+
        // iOS 16 and below uses requestAccess(to:)
        if #available(iOS 17.0, *) {
            return try await eventStore.requestFullAccessToEvents()
        } else {
            return try await eventStore.requestAccess(to: .event)
        }
    }
}
```

### 3c: Replace AppKit with UIKit/SwiftUI

Key replacements:
| macOS (AppKit) | iOS (UIKit/SwiftUI) |
|----------------|---------------------|
| `NSStatusItem` | Widget / Live Activity |
| `NSPopover` | Main app view |
| `NSWorkspace.shared.open(url)` | `UIApplication.shared.open(url)` |
| `NSPasteboard.general` | `UIPasteboard.general` |
| `NSApp.sendAction(...)` for Settings | NavigationLink to SettingsView |
| `ASPresentationAnchor` (NSWindow) | `ASPresentationAnchor` (UIWindow) |

---

## Step 4: Implement the Widget (WidgetKit)

### 4a: Widget Timeline Provider

```swift
import WidgetKit
import SwiftUI

struct MeetingTimelineProvider: TimelineProvider {
    let meetingStore = MeetingStore(calendarServices: CalendarAccountManager.shared.allActiveServices())

    func placeholder(in context: Context) -> MeetingEntry {
        MeetingEntry(date: Date(), nextMeeting: nil, urgencyLevel: .none)
    }

    func getSnapshot(in context: Context, completion: @escaping (MeetingEntry) -> Void) {
        meetingStore.refreshMeetings()
        let entry = MeetingEntry(
            date: Date(),
            nextMeeting: meetingStore.nextMeeting,
            urgencyLevel: meetingStore.urgencyLevel
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MeetingEntry>) -> Void) {
        meetingStore.refreshMeetings()

        var entries: [MeetingEntry] = []
        let now = Date()

        // Create entries for the next 2 hours at 5-minute intervals
        for minuteOffset in stride(from: 0, to: 120, by: 5) {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: now)!
            let entry = MeetingEntry(
                date: entryDate,
                nextMeeting: meetingStore.nextMeeting,
                urgencyLevel: meetingStore.urgencyLevel
            )
            entries.append(entry)
        }

        let timeline = Timeline(entries: entries, policy: .after(
            Calendar.current.date(byAdding: .hour, value: 1, to: now)!
        ))
        completion(timeline)
    }
}

struct MeetingEntry: TimelineEntry {
    let date: Date
    let nextMeeting: Meeting?
    let urgencyLevel: UrgencyLevel
}
```

### 4b: Widget Views

Design three widget sizes:

**Small Widget (accessoryRectangular on Lock Screen):**
```
┌──────────────┐
│ 2:30 PM      │
│ Team Standup  │
│ in 25 min    │
└──────────────┘
```

**Medium Widget:**
```
┌─────────────────────────────────┐
│ MemCache          Today, Feb 21 │
│                                 │
│ ● 2:30 PM  Team Standup   30m  │
│ ○ 4:00 PM  Sprint Review  60m  │
│ ○ 5:30 PM  1:1 with Alex  30m  │
└─────────────────────────────────┘
```

**Large Widget:**
```
┌─────────────────────────────────┐
│ MemCache          Today, Feb 21 │
│                                 │
│ NEXT UP                    25m  │
│ ■ Team Standup       2:30 PM   │
│   Join Google Meet              │
│─────────────────────────────────│
│ ○ 4:00 PM  Sprint Review  60m  │
│ ○ 5:30 PM  1:1 with Alex  30m  │
│                                 │
│          3 meetings today       │
└─────────────────────────────────┘
```

### 4c: Widget Configuration

```swift
@main
struct MemCacheWidget: Widget {
    let kind = "MemCacheWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MeetingTimelineProvider()) { entry in
            MemCacheWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("MemCache")
        .description("See your upcoming meetings at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .systemLarge,
            .accessoryRectangular,  // Lock Screen
            .accessoryCircular      // Lock Screen
        ])
    }
}
```

---

## Step 5: Implement Live Activities (iOS 16.1+)

Live Activities show a persistent, updating banner on the Lock Screen and Dynamic Island for in-progress or imminent meetings.

### 5a: Define the Activity Attributes

```swift
import ActivityKit

struct MeetingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var meetingTitle: String
        var startTime: Date
        var endTime: Date
        var minutesRemaining: Int
        var joinURL: URL?
        var isInProgress: Bool
    }

    var meetingId: String
    var calendarName: String
}
```

### 5b: Start a Live Activity

```swift
class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<MeetingActivityAttributes>?

    func startActivity(for meeting: Meeting) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = MeetingActivityAttributes(
            meetingId: meeting.id,
            calendarName: meeting.calendarName
        )

        let state = MeetingActivityAttributes.ContentState(
            meetingTitle: meeting.title,
            startTime: meeting.startDate,
            endTime: meeting.endDate,
            minutesRemaining: meeting.minutesUntilStart,
            joinURL: meeting.joinURL,
            isInProgress: meeting.isInProgress
        )

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: meeting.endDate)
            )
        } catch {
            print("MemCache: Failed to start Live Activity: \(error)")
        }
    }

    func updateActivity(for meeting: Meeting) {
        let state = MeetingActivityAttributes.ContentState(
            meetingTitle: meeting.title,
            startTime: meeting.startDate,
            endTime: meeting.endDate,
            minutesRemaining: meeting.minutesUntilStart,
            joinURL: meeting.joinURL,
            isInProgress: meeting.isInProgress
        )

        Task {
            await currentActivity?.update(.init(state: state, staleDate: meeting.endDate))
        }
    }

    func endActivity() {
        Task {
            await currentActivity?.end(nil, dismissalPolicy: .immediate)
            currentActivity = nil
        }
    }
}
```

### 5c: When to Start/Update/End

In `MeetingStore` or a dedicated coordinator:
- **Start** a Live Activity when next meeting is < 15 minutes away
- **Update** every 60 seconds with fresh countdown
- **Transition** to "in progress" state when meeting starts
- **End** when meeting ends or user dismisses

---

## Step 6: Implement Local Notifications

```swift
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func scheduleMeetingReminders(for meetings: [Meeting]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        for meeting in meetings where !meeting.isAllDay && !meeting.hasEnded {
            // 30-minute reminder
            scheduleReminder(for: meeting, minutesBefore: 30, identifier: "\(meeting.id)-30m")
            // 15-minute reminder
            scheduleReminder(for: meeting, minutesBefore: 15, identifier: "\(meeting.id)-15m")
            // 5-minute reminder
            scheduleReminder(for: meeting, minutesBefore: 5, identifier: "\(meeting.id)-5m")
        }
    }

    private func scheduleReminder(for meeting: Meeting, minutesBefore: Int, identifier: String) {
        let triggerDate = meeting.startDate.addingTimeInterval(-Double(minutesBefore * 60))
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = meeting.title
        content.body = "\(minutesBefore) minutes until your meeting"
        content.sound = minutesBefore <= 5 ? .default : .none
        content.categoryIdentifier = "MEETING_REMINDER"

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            ),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
```

---

## Step 7: iOS App Data Sharing

To share calendar account data between the main app and widget extension:

### 7a: App Groups

1. In Xcode, add the **App Groups** capability to both the app target and widget target
2. Create a group: `group.com.memcache.app`
3. Use `UserDefaults(suiteName: "group.com.memcache.app")` instead of `UserDefaults.standard` for shared preferences
4. Use the shared Keychain access group for OAuth tokens

### 7b: Shared Keychain

Update `KeychainHelper.swift` to use a shared access group:

```swift
// Add to all Keychain queries:
kSecAttrAccessGroup as String: "group.com.memcache.app"
```

This allows the widget to read Google/Outlook OAuth tokens stored by the main app.

---

## Step 8: iOS-Specific Entitlements

The iOS app needs these entitlements:

```xml
<!-- MemCache-iOS.entitlements -->
<dict>
    <key>com.apple.security.application-groups</key>
    <array>
        <string>group.com.memcache.app</string>
    </array>
    <key>com.apple.developer.usernotifications.time-sensitive</key>
    <true/>
</dict>
```

And in Info.plist:

```xml
<key>NSCalendarsUsageDescription</key>
<string>MemCache needs access to your calendar to show upcoming meetings.</string>
<key>NSCalendarsFullAccessUsageDescription</key>
<string>MemCache needs full access to your calendar to show upcoming meetings.</string>
<key>NSSupportsLiveActivities</key>
<true/>
```

---

## Step 9: iOS Project File Structure

```
MemCache-iOS/
├── MemCacheApp.swift                    # iOS app entry point
├── Views/
│   ├── DailyScheduleView.swift          # Main schedule (like macOS popover)
│   ├── MeetingRowView.swift             # Touch-friendly meeting row
│   ├── MeetingDetailView.swift          # Full meeting details + actions
│   ├── CalendarAccountsView.swift       # Connect/disconnect calendars
│   └── SettingsView.swift               # iOS-style preferences
├── Services/
│   ├── NotificationManager.swift        # Local notification scheduling
│   └── LiveActivityManager.swift        # Live Activity lifecycle
├── Widget/
│   ├── MemCacheWidget.swift             # Widget entry point
│   ├── MeetingTimelineProvider.swift     # Timeline data provider
│   ├── WidgetViews/
│   │   ├── SmallWidgetView.swift
│   │   ├── MediumWidgetView.swift
│   │   ├── LargeWidgetView.swift
│   │   └── LockScreenWidgetView.swift
│   └── LiveActivity/
│       ├── MeetingActivityAttributes.swift
│       └── MeetingLiveActivityView.swift
├── Shared/ (or via MemCacheShared Swift Package)
│   ├── Models/Meeting.swift
│   ├── Services/CalendarServiceProtocol.swift
│   ├── Services/AppleCalendarService.swift
│   ├── Services/GoogleCalendarService.swift
│   ├── Services/OutlookCalendarService.swift
│   ├── Services/KeychainHelper.swift
│   ├── Services/CalendarCache.swift
│   ├── Services/CalendarAccountManager.swift
│   └── Services/MeetingStore.swift
└── Resources/
    ├── Info.plist
    ├── MemCache-iOS.entitlements
    └── Assets.xcassets
```

---

## Step 10: Estimated Implementation Effort

| Component | Effort | Notes |
|-----------|--------|-------|
| Shared package extraction | 1-2 days | Extract platform-independent code |
| Main iOS app views | 3-4 days | DailySchedule, MeetingDetail, Settings |
| Widget (all sizes) | 2-3 days | Timeline provider + 4 widget views |
| Live Activities | 1-2 days | Activity attributes + Dynamic Island UI |
| Notifications | 1 day | UNUserNotificationCenter scheduling |
| App Groups / shared data | 1 day | Keychain sharing, UserDefaults suite |
| Platform adaptations | 1-2 days | UIKit replacements, permission flow tweaks |
| Testing & polish | 2-3 days | Device testing, widget refresh behavior |
| **Total** | **~2-3 weeks** | For a single developer |

---

## Step 11: Publishing the iOS App

Follow the same general process as APP_STORE_PUBLISHING.md with these iOS-specific notes:

1. **Screenshots needed**: iPhone 6.7" (required), iPhone 6.1", iPad 12.9" (if universal)
2. **App Review**: Widget and Live Activity will be reviewed -- ensure they update correctly
3. **Privacy**: Same calendar access + notification permission disclosures
4. **TestFlight**: Strongly recommended for iOS -- easy to distribute beta builds to testers
5. **OAuth redirect URIs**: Register the iOS bundle ID with Google Cloud Console and Azure AD in addition to the macOS one

---

## Tips and Gotchas

- **Widget refresh limits**: WidgetKit controls refresh timing. You get ~40-70 refreshes per day. Design timelines efficiently.
- **Background App Refresh**: Enable this capability so the app can update data periodically. Budget is limited by iOS.
- **OAuth on iOS**: `ASWebAuthenticationSession` works the same on iOS but uses `UIWindow` for the presentation anchor instead of `NSWindow`.
- **EventKit on iOS**: Nearly identical API to macOS. The main difference is the permission prompt UI.
- **Live Activity limits**: Maximum 8 hours duration. End activities when meetings end.
- **Shared Keychain**: Requires matching App ID prefix and Keychain Sharing capability on both targets.
- **Universal app**: Consider making the iOS app universal (iPhone + iPad) from the start. SwiftUI makes this straightforward with adaptive layouts.
