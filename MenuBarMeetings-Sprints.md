# MenuBar Meetings - Sprint Development Plan

Development roadmap for the Mac menu bar meeting reminder application, structured for iterative implementation.

## Development Overview

- **Timeline**: 6-8 sprints (12-16 weeks)
- **Sprint Length**: 2 weeks each
- **Team Size**: 1-2 developers
- **Platform**: macOS (Swift/SwiftUI)

## Sprint 1: Foundation & Basic Menu Bar

**Goal**: Get basic app structure with minimal menu bar presence

### Step 1 — Xcode Project & Directory Layout

Create a new Xcode project targeting macOS with the following settings and structure:

- [x] **Setup-001a**: Create Xcode project
  - Product name: `MenuBarMeetings`
  - Interface: **SwiftUI**, Language: **Swift**
  - Minimum deployment target: **macOS 13.0** (Ventura — required for `MenuBarExtra`)
  - Bundle identifier: `com.memcache.menubar-meetings`
  - Uncheck "Include Tests" for now (added in Sprint 8 / Tech Debt)

- [x] **Setup-001b**: Configure as menu-bar-only app (no Dock icon)
  - Set `LSUIElement` = `YES` in `Info.plist` (Application is agent)
  - This hides the app from the Dock so it lives exclusively in the menu bar

- [x] **Setup-001c**: Establish source directory layout
  ```
  MenuBarMeetings/
  ├── App/
  │   └── MenuBarMeetingsApp.swift    # @main entry point
  ├── Views/
  │   ├── MenuBarView.swift           # Menu bar label content
  │   └── PopupView.swift             # Popover daily-schedule shell
  ├── Models/                         # (empty — populated in Sprint 2)
  ├── Services/                       # (empty — populated in Sprint 2)
  ├── Resources/
  │   └── Assets.xcassets             # App icon & menu bar icon
  └── Info.plist
  ```

### Step 2 — App Entry Point & MenuBarExtra

- [x] **Setup-002a**: Implement `MenuBarMeetingsApp.swift` using the SwiftUI `MenuBarExtra` API
  - Declare `@main struct MenuBarMeetingsApp: App`
  - Use `MenuBarExtra("MenuBar Meetings", systemImage: "calendar")` for the menu bar item
  - Set the `MenuBarExtra` style to `.window` so clicking opens a popover panel
  - The body of the `MenuBarExtra` renders `PopupView()`

- [x] **Setup-002b**: Add an `AppDelegate` via `@NSApplicationDelegateAdaptor`
  - Handle `applicationDidFinishLaunching` for any one-time setup
  - Handle `applicationWillTerminate` for clean shutdown

### Step 3 — Static Menu Bar Label

- [x] **Core-001**: Create `MenuBarView.swift`
  - Display a static placeholder string: `"No meetings today"`
  - Use `Label` or `Text` with an SF Symbol icon (`calendar`)
  - This view will be swapped for live calendar data in Sprint 2

### Step 4 — Empty Popup / Popover Window

- [x] **Core-002**: Create `PopupView.swift`
  - Render a fixed-size popover (width: ~320 pt, height: ~400 pt)
  - Show a centered placeholder: `"Your schedule will appear here"`
  - Add a **Quit** button at the bottom (`NSApplication.shared.terminate(nil)`)
  - Add a disabled **Preferences** button (stub for Sprint 5)

### Step 5 — App Icon & Menu Bar Icon

- [x] **Setup-003a**: Add a placeholder `AppIcon` set inside `Assets.xcassets`
  - Provide at minimum a 512×512 @1x and 1024×1024 @2x icon (can be a simple calendar glyph for now)
- [ ] **Setup-003b**: Confirm the SF Symbol `calendar` renders correctly in the menu bar at all display scales (requires macOS)
  - Fallback: create a custom 18×18 @1x / 36×36 @2x template image named `MenuBarIcon` in the asset catalog and reference it via `MenuBarExtra("MenuBar Meetings", image: "MenuBarIcon")`

### Deliverables
- App launches and shows a calendar icon + label in the menu bar
- Clicking the menu bar item opens/closes a popover with placeholder content
- App has no Dock icon (`LSUIElement`)
- Basic app lifecycle: launches cleanly, quits via popover button

### Definition of Done
- [ ] App can be built and launched from Xcode with zero warnings (requires macOS)
- [ ] Menu bar item appears with an icon and is clickable (requires macOS)
- [ ] Popover window opens/closes properly on click (requires macOS)
- [ ] App does **not** appear in the Dock (requires macOS — `LSUIElement` configured)
- [ ] App can be quit cleanly via the popover Quit button (requires macOS)
- [x] Source files follow the directory layout above (verified by structural test)

---

## Sprint 2: Calendar Integration Foundation

**Goal**: Connect to Apple Calendar and display basic meeting data

### Step 1 — Meeting Data Model

- [x] **Data-001**: Create `Models/Meeting.swift`
  - `struct Meeting: Identifiable` with `id`, `title`, `startDate`, `endDate`, `isAllDay`, `location`, `url`, `calendarName`
  - Computed properties: `duration`, `isOngoing`, `isPast`, `formattedStartTime`, `formattedDuration`, `menuBarLabel`
  - Menu bar format: `"2:30 PM · Standup"`

### Step 2 — CalendarService (EventKit)

- [x] **Calendar-001**: Create `Services/CalendarService.swift`
  - `ObservableObject` wrapping `EKEventStore`
  - Publishes `meetings: [Meeting]`, `authorizationStatus`, `errorMessage`

- [x] **Calendar-002**: Permission handling
  - `requestAccess()` uses `requestFullAccessToEvents` on macOS 14+ with fallback to `requestAccess(to:)` on macOS 13
  - Handles granted / denied / error states and updates `authorizationStatus`
  - Denied state shows a user-friendly message directing to System Settings

- [x] **Calendar-003**: Fetch today's events
  - `fetchTodaysMeetings()` queries EventKit for start-of-day → end-of-day
  - Maps `EKEvent` → `Meeting`, sorted chronologically
  - `nextMeeting` computed property returns the first non-past, non-all-day event

### Step 3 — Auto-Refresh

- [x] **Refresh**: Calendar change observation + polling
  - Subscribes to `EKEventStoreChanged` notification (debounced 1s) for external edits
  - 60-second polling timer keeps the "next meeting" current as time passes

### Step 4 — Wire Into Views

- [x] **Display-001**: Update `MenuBarMeetingsApp.swift`
  - `@StateObject` for `CalendarService`, passed via `environmentObject` to popup
  - `MenuBarView` receives `nextMeeting` and displays its `menuBarLabel`
  - `PopupView` auto-triggers `requestAccess()` on first appear when status is `.notDetermined`

- [x] **Display-002**: Update `PopupView.swift`
  - Header shows today's date (`"Thursday, Feb 6"`)
  - Authorized + meetings → scrollable `MeetingRow` list (time, title, duration)
  - Authorized + empty → `"No meetings today"` placeholder
  - Not determined → `"Requesting calendar access…"`
  - Denied → error message with System Settings guidance

### Deliverables
- Read events from Apple Calendar via EventKit
- Display next meeting time + title in menu bar (`"2:30 PM · Standup"`)
- Handle permission requests gracefully with user-facing messages
- Auto-refresh on calendar changes and 60-second polling

### Definition of Done
- [ ] App requests and handles Calendar permissions (requires macOS)
- [ ] Can fetch today's calendar events (requires macOS)
- [x] Menu bar displays next meeting (format: `"h:mm a · Title"`)
- [x] Updates when calendar changes (EKEventStoreChanged + 60s polling)

---

## Sprint 3: Popup Daily View

**Goal**: Build the expandable daily schedule view

### Step 1 — Enhanced Meeting Model

- [x] **Data-002**: Add `calendarColor: Color` property to `Meeting`
  - Sourced from `EKCalendar.cgColor` in `CalendarService`
- [x] **Data-003**: Add `formattedTimeRange` computed property
  - Format: `"2:30 PM – 3:00 PM"` using shared `DateFormatter`

### Step 2 — Polished Popup Layout

- [x] **UI-001**: Separate all-day events from timed events
  - `SectionHeader` component for "All Day" / "Schedule" labels
  - `AllDayRow` shows calendar color dot, title, and calendar name
  - Timed section only gets a header when all-day events are also present

- [x] **UI-002**: Enhanced `MeetingRow`
  - Calendar color dot (8 pt circle) aligned to title
  - Full time range (`formattedTimeRange`) instead of just start time
  - Location line (conditional, shown when non-empty)
  - Duration badge right-aligned
  - Ongoing meetings: semibold title + subtle accent background highlight
  - Past meetings: 50% opacity fade

- [x] **UI-003**: Popup window positioning (below menu bar item)
  - Handled automatically by `MenuBarExtra(.window)` style

### Step 3 — UX Behavior

- [x] **UX-001**: Click outside to close popup
  - Handled automatically by `MenuBarExtra(.window)` style
- [x] **Display-002**: Format full day's meetings with chronological sort
  - Already sorted in `CalendarService.fetchTodaysMeetings()`

### Deliverables
- Clicking menu bar opens popup showing full day's meetings
- All-day events grouped at top, timed events below with "Schedule" header
- Each meeting shows color dot, title, time range, duration, and optional location
- Ongoing meeting visually highlighted; past meetings faded
- Popup behaves like native Mac popups (auto-positioning, click-outside-to-close)

### Definition of Done
- [x] Popup shows all today's meetings in chronological order
- [x] Each meeting displays time range, title, duration, location, and calendar color
- [x] Popup positions correctly below menu bar item (MenuBarExtra .window)
- [x] Clicking outside closes popup (MenuBarExtra .window)
- [x] Empty state ("No meetings today") handled
- [x] All-day events separated into their own section

---

## Sprint 4: Smart Menu Bar Display

**Goal**: Improve menu bar text and basic urgency indicators

### Step 1 — Urgency System

- [x] **Urgency-001**: `UrgencyLevel` enum (`none`, `low`, `medium`, `high`, `ongoing`)
  - Thresholds: >30 min → none, 15–30 → low, 5–15 → medium, <5 → high
- [x] **Urgency-002**: `minutesUntilStart` and `urgencyLevel` on `Meeting`
- [x] **Urgency-003**: `countdownLabel` — human-readable countdown (`"in 12m"`, `"in 1h 30m"`, `"now"`)

### Step 2 — Smart Title Truncation

- [x] **Algorithm-001**: `truncatedTitle(maxLength:)` on `Meeting`
  - Returns title unchanged if within budget
  - Drops filler words (the, a, an, and, with, for, to, of, in, on, at)
  - Hard-truncates with `…` if still over budget

### Step 3 — Urgency-Aware Menu Bar

- [x] **Display-003**: Rewrite `MenuBarView` with urgency logic
  - `> 30 min` → `"2:30 PM · Standup"` (default icon)
  - `15–30 min` → `"in Xm · Standup"` (orange icon)
  - `5–15 min` → `"in Xm · Standup"` (red icon)
  - `< 5 min` → `"in Xm · Standup"` (red icon, `calendar.badge.exclamationmark`)
  - `ongoing` → `"now · Standup"` (blue icon, `calendar.badge.clock`)
  - No meeting → `"No meetings"` (default icon)
- [x] **Polish-001**: Past meetings excluded by `CalendarService.nextMeeting`

### Deliverables
- Menu bar shows smart countdown as meetings approach
- Urgency-colored icon shifts through orange → red → badge
- Titles truncated intelligently to fit menu bar space
- Ongoing meetings indicated with "now" and clock badge

### Definition of Done
- [x] Meeting titles truncate intelligently (drop filler words, then hard-truncate)
- [x] Menu bar text switches from time to countdown within 30 minutes
- [x] Color/icon changes at 30, 15, and 5 minute thresholds
- [x] Shows "No meetings" when no upcoming events
- [x] Past meetings excluded via `nextMeeting` filter

---

## Sprint 5: Multi-Calendar Support

**Goal**: Expand beyond Apple Calendar to Google Calendar integration

### Issues/Tasks
- [ ] **Integration-001**: Google Calendar API setup and authentication
- [ ] **Integration-002**: OAuth flow for Google Calendar
- [ ] **Data-002**: Multi-source calendar data management
- [ ] **Settings-001**: Basic preferences window (calendar selection)
- [ ] **Sync-001**: Unified event fetching from multiple sources

### Deliverables
- Connect to Google Calendar accounts
- Preferences to enable/disable calendar sources
- Combined view of events from multiple calendars

### Definition of Done
- [ ] Users can authenticate with Google Calendar
- [ ] Preferences window allows calendar source selection
- [ ] Events from multiple calendars appear in unified view
- [ ] Calendar credentials stored securely in Keychain
- [ ] Error handling for authentication failures

---

## Sprint 6: Advanced Urgency & Polish

**Goal**: Enhanced urgency indicators and meeting actions

### Issues/Tasks
- [ ] **Urgency-003**: Text animation for urgent meetings (subtle pulse)
- [ ] **Urgency-004**: Progressive urgency levels (30min, 15min, 5min)
- [ ] **Actions-001**: Meeting action buttons in popup (join, copy)
- [ ] **Actions-002**: Detect and handle meeting join links
- [ ] **Polish-002**: Dark/light mode theme support

### Deliverables
- Sophisticated urgency system with multiple warning levels
- Actionable meetings (join Zoom/Teams/Meet links)
- Proper macOS theme integration

### Definition of Done
- [ ] Multiple urgency levels with different visual treatments
- [ ] Meeting join links are detected and clickable
- [ ] Copy meeting details functionality
- [ ] App respects system light/dark mode
- [ ] Animation is subtle and non-distracting

---

## Sprint 7: Outlook Integration & Performance

**Goal**: Complete the calendar trio and optimize performance

### Issues/Tasks
- [ ] **Integration-003**: Microsoft Graph API setup
- [ ] **Integration-004**: Outlook calendar authentication and fetching
- [ ] **Performance-001**: Efficient calendar polling/caching strategy
- [ ] **Performance-002**: Memory usage optimization
- [ ] **Settings-002**: Advanced preferences (update intervals, etc.)

### Deliverables
- Full Outlook calendar integration
- Optimized performance for continuous operation
- Advanced user preferences

### Definition of Done
- [ ] Outlook calendar integration working
- [ ] App uses <50MB memory consistently
- [ ] Smart polling reduces API calls
- [ ] Preferences for update frequency and behavior
- [ ] All three major calendar platforms supported

---

## Sprint 8: Final Polish & Release Prep

**Goal**: Bug fixes, final UX polish, and distribution readiness

### Issues/Tasks
- [ ] **Testing-001**: Comprehensive edge case testing
- [ ] **UX-002**: Accessibility support (VoiceOver, keyboard nav)
- [ ] **Polish-003**: App icon and menu bar icon refinement
- [ ] **Distribution-001**: Code signing and notarization setup
- [ ] **Documentation-001**: User guide and troubleshooting docs

### Deliverables
- Production-ready application
- Proper macOS distribution setup
- User documentation

### Definition of Done
- [ ] All critical bugs resolved
- [ ] Accessibility features implemented
- [ ] App properly signed and notarized for distribution
- [ ] User documentation complete
- [ ] Ready for App Store or direct distribution

---

## Technical Debt & Ongoing

### Continuous Tasks (Address Throughout)
- [ ] **Tech-Debt-001**: Unit test coverage for core logic
- [ ] **Tech-Debt-002**: Error logging and crash reporting
- [ ] **Tech-Debt-003**: Performance monitoring and profiling
- [ ] **Tech-Debt-004**: Security audit of credential storage

### Post-Launch Considerations
- [ ] User feedback collection and analysis
- [ ] Additional calendar platforms (if requested)
- [ ] Advanced features (travel time, AI insights)
- [ ] Cross-platform exploration

---

## Dependencies & Risk Mitigation

### External Dependencies
- **EventKit** (Apple): Low risk, stable framework
- **Google Calendar API**: Monitor rate limits, handle quotas
- **Microsoft Graph API**: Plan for auth complexity

### Technical Risks
- **Calendar API Changes**: Build abstraction layer for easier swapping
- **macOS Updates**: Test with beta versions of macOS
- **Memory Leaks**: Regular profiling, especially with continuous operation

### Success Metrics per Sprint
- **Sprint 1-2**: App launches and shows calendar data
- **Sprint 3-4**: Daily usage becomes viable
- **Sprint 5-6**: Feature completeness for broad user base
- **Sprint 7-8**: Production quality and reliability

This sprint structure allows for regular demos, user feedback, and iterative improvement while maintaining a clear path to a production-ready application.