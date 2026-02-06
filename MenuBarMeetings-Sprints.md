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

- [ ] **Setup-001a**: Create Xcode project
  - Product name: `MenuBarMeetings`
  - Interface: **SwiftUI**, Language: **Swift**
  - Minimum deployment target: **macOS 13.0** (Ventura — required for `MenuBarExtra`)
  - Bundle identifier: `com.memcache.menubar-meetings`
  - Uncheck "Include Tests" for now (added in Sprint 8 / Tech Debt)

- [ ] **Setup-001b**: Configure as menu-bar-only app (no Dock icon)
  - Set `LSUIElement` = `YES` in `Info.plist` (Application is agent)
  - This hides the app from the Dock so it lives exclusively in the menu bar

- [ ] **Setup-001c**: Establish source directory layout
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

- [ ] **Setup-002a**: Implement `MenuBarMeetingsApp.swift` using the SwiftUI `MenuBarExtra` API
  - Declare `@main struct MenuBarMeetingsApp: App`
  - Use `MenuBarExtra("MenuBar Meetings", systemImage: "calendar")` for the menu bar item
  - Set the `MenuBarExtra` style to `.window` so clicking opens a popover panel
  - The body of the `MenuBarExtra` renders `PopupView()`

- [ ] **Setup-002b**: Add an `AppDelegate` via `@NSApplicationDelegateAdaptor`
  - Handle `applicationDidFinishLaunching` for any one-time setup
  - Handle `applicationWillTerminate` for clean shutdown

### Step 3 — Static Menu Bar Label

- [ ] **Core-001**: Create `MenuBarView.swift`
  - Display a static placeholder string: `"No meetings today"`
  - Use `Label` or `Text` with an SF Symbol icon (`calendar`)
  - This view will be swapped for live calendar data in Sprint 2

### Step 4 — Empty Popup / Popover Window

- [ ] **Core-002**: Create `PopupView.swift`
  - Render a fixed-size popover (width: ~320 pt, height: ~400 pt)
  - Show a centered placeholder: `"Your schedule will appear here"`
  - Add a **Quit** button at the bottom (`NSApplication.shared.terminate(nil)`)
  - Add a disabled **Preferences** button (stub for Sprint 5)

### Step 5 — App Icon & Menu Bar Icon

- [ ] **Setup-003a**: Add a placeholder `AppIcon` set inside `Assets.xcassets`
  - Provide at minimum a 512×512 @1x and 1024×1024 @2x icon (can be a simple calendar glyph for now)
- [ ] **Setup-003b**: Confirm the SF Symbol `calendar` renders correctly in the menu bar at all display scales
  - Fallback: create a custom 18×18 @1x / 36×36 @2x template image named `MenuBarIcon` in the asset catalog and reference it via `MenuBarExtra("MenuBar Meetings", image: "MenuBarIcon")`

### Deliverables
- App launches and shows a calendar icon + label in the menu bar
- Clicking the menu bar item opens/closes a popover with placeholder content
- App has no Dock icon (`LSUIElement`)
- Basic app lifecycle: launches cleanly, quits via popover button

### Definition of Done
- [ ] App can be built and launched from Xcode with zero warnings
- [ ] Menu bar item appears with an icon and is clickable
- [ ] Popover window opens/closes properly on click
- [ ] App does **not** appear in the Dock
- [ ] App can be quit cleanly via the popover Quit button
- [ ] Source files follow the directory layout above

---

## Sprint 2: Calendar Integration Foundation

**Goal**: Connect to Apple Calendar and display basic meeting data

### Issues/Tasks
- [ ] **Calendar-001**: EventKit framework integration
- [ ] **Calendar-002**: Calendar permissions handling
- [ ] **Calendar-003**: Fetch today's events from default calendar
- [ ] **Data-001**: Meeting data model (Event struct/class)
- [ ] **Display-001**: Show next meeting in menu bar (basic format)

### Deliverables
- Read events from Apple Calendar
- Display next meeting time + title in menu bar
- Handle permission requests gracefully

### Definition of Done
- [ ] App requests and handles Calendar permissions
- [ ] Can fetch today's calendar events
- [ ] Menu bar displays next meeting (format: "2:30 PM • Meeting Title")
- [ ] Updates when calendar changes (basic polling)

---

## Sprint 3: Popup Daily View

**Goal**: Build the expandable daily schedule view

### Issues/Tasks
- [ ] **UI-001**: Design daily schedule popup layout
- [ ] **UI-002**: Meeting list UI component (time, title, duration)
- [ ] **UI-003**: Popup window positioning (below menu bar item)
- [ ] **Display-002**: Format full day's meetings in popup
- [ ] **UX-001**: Click outside to close popup behavior

### Deliverables
- Clicking menu bar opens popup showing full day's meetings
- Clean, readable meeting list with proper formatting
- Popup behaves like native Mac popups

### Definition of Done
- [ ] Popup shows all today's meetings in chronological order
- [ ] Each meeting displays time, title, and duration
- [ ] Popup positions correctly below menu bar item
- [ ] Clicking outside closes popup
- [ ] Empty state ("No meetings today") handled

---

## Sprint 4: Smart Menu Bar Display

**Goal**: Improve menu bar text and basic urgency indicators

### Issues/Tasks
- [ ] **Algorithm-001**: Smart title truncation algorithm
- [ ] **Display-003**: Dynamic menu bar text sizing
- [ ] **Urgency-001**: Time-until-meeting calculation
- [ ] **Urgency-002**: Basic urgency indicator (color change <30min)
- [ ] **Polish-001**: Handle edge cases (no meetings, past meetings)

### Deliverables
- Menu bar intelligently shows appropriate meeting info
- Visual indicator when meeting is approaching
- Handles various schedule scenarios gracefully

### Definition of Done
- [ ] Meeting titles truncate intelligently (keep important words)
- [ ] Menu bar text adapts to available space
- [ ] Color/style changes when meeting <30 minutes away
- [ ] Shows "No meetings" or next upcoming when appropriate
- [ ] Past meetings don't show as "next"

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