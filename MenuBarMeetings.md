# MenuBar Meetings - Mac Menu Bar Meeting Reminder

A minimal, elegant Mac menu bar application that keeps your upcoming meetings visible and accessible without cluttering your workflow.

## Core Concept

A discrete menu bar widget that displays your next meeting time and brief title, becoming more prominent as the meeting approaches. Click to expand into a clean daily schedule view.

## Key Features

### Menu Bar Widget
- **Minimal Display**: Shows next meeting time + 1-2 words from title/description
- **Smart Truncation**: Intelligently shortens meeting titles to fit menu bar space
- **Urgency Indicators**: Visual changes when meeting is <30 minutes away:
  - Color shift (subtle → more noticeable)
  - Text animation (gentle pulse/scroll for long titles)
  - Icon badge/indicator

### Expandable Daily View
- **Full Schedule**: Click widget to open popup showing complete day's meetings
- **Clean Layout**: Organized timeline view with:
  - Meeting times
  - Full titles
  - Duration indicators
  - Location/join links (if available)
- **Quick Actions**: One-click to join meetings, copy details, etc.

### Calendar Integration
- **Universal Support**: Connect to multiple calendar sources:
  - **Apple Calendar** (CalDAV)
  - **Google Calendar** (Google Calendar API)
  - **Microsoft Outlook** (Microsoft Graph API)
- **Multi-Account**: Support multiple calendars from different services
- **Real-time Sync**: Automatic updates as calendar changes

## Technical Requirements

### Platform
- **macOS**: Native Mac application
- **System Integration**: Menu bar presence, system notifications
- **Permissions**: Calendar access, notification permissions

### Architecture Considerations
- **Lightweight**: Minimal memory footprint
- **Battery Efficient**: Smart polling/push updates
- **Privacy**: Local processing, secure credential storage in Keychain

### UI Framework Options
- **SwiftUI**: Modern, native Mac development
- **Electron**: Cross-platform if future expansion planned
- **Native Cocoa**: Maximum performance and system integration

## User Experience Flow

### Initial Setup
1. Launch app → appears in menu bar
2. First-time setup wizard for calendar connections
3. Permission requests (Calendar, Notifications)

### Daily Usage
1. **Glance**: Menu bar shows "2:30 PM • Standup"
2. **Urgency**: 20 minutes before → color shifts, subtle animation
3. **Detail**: Click widget → popup shows full day schedule
4. **Action**: Click meeting in popup → join/copy/details options

### Edge Cases
- **No meetings**: Show "No meetings today" or next upcoming
- **Multiple simultaneous**: Show count or most important
- **All-day events**: Smart handling (show at top, different styling)

## Implementation Phases

### Phase 1: MVP
- Basic menu bar widget
- Single calendar integration (start with Apple Calendar)
- Simple popup daily view
- Basic urgency indicator

### Phase 2: Polish
- Multi-calendar support
- Advanced urgency animations
- Join meeting integrations
- Customizable settings

### Phase 3: Enhancement
- Smart meeting insights
- Travel time integration
- Custom notification rules
- Keyboard shortcuts

## Technical Challenges

### Calendar Integration
- **API Rate Limits**: Efficient polling strategies
- **Auth Management**: OAuth token refresh handling
- **Sync Conflicts**: Multiple calendar source coordination

### UI/UX
- **Menu Bar Space**: Dynamic sizing based on content
- **System Theme**: Dark/light mode adaptation
- **Accessibility**: VoiceOver support, keyboard navigation

### Performance
- **Background Updates**: Efficient calendar polling
- **Memory Usage**: Lightweight data structures
- **Battery Impact**: Smart wake/sleep handling

## Success Metrics

- **Adoption**: Daily active usage
- **Efficiency**: Reduced meeting preparation time
- **Reliability**: 99%+ uptime, accurate meeting data
- **Performance**: <1% CPU usage, <50MB memory

## Future Considerations

- **Cross-Platform**: Windows/Linux versions
- **Team Features**: Shared meeting visibility
- **AI Integration**: Smart meeting preparation suggestions
- **Apple Watch**: Companion watch app for wrist notifications

---

**Target Users**: Mac users who attend multiple daily meetings and want a distraction-free way to stay aware of their schedule without constantly checking calendar apps.

**Differentiator**: Strikes the perfect balance between visibility and minimalism - always present but never intrusive until it matters.