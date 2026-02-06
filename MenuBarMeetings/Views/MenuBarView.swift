import SwiftUI

/// Renders the menu bar label with urgency-aware styling.
///
/// Display logic:
/// - No meeting → "No meetings" (calendar icon)
/// - Meeting > 30 min away → "2:30 PM · Standup" (default style)
/// - Meeting 15–30 min → adds "in Xm" countdown, orange tint
/// - Meeting 5–15 min → countdown, red tint
/// - Meeting < 5 min → countdown, red tint, pulse animation
/// - Ongoing → "now · Standup", blue tint
struct MenuBarView: View {
    let nextMeeting: Meeting?

    @State private var isPulsing = false

    var body: some View {
        if let meeting = nextMeeting {
            Label {
                Text(labelText(for: meeting))
            } icon: {
                Image(systemName: iconName(for: meeting))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(iconColor(for: meeting))
                    .opacity(isPulsing && meeting.urgencyLevel == .high ? 0.4 : 1.0)
                    .animation(
                        meeting.urgencyLevel == .high
                            ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                            : .default,
                        value: isPulsing
                    )
            }
            .onChange(of: meeting.urgencyLevel) { newValue in
                isPulsing = newValue == .high
            }
            .onAppear {
                isPulsing = meeting.urgencyLevel == .high
            }
        } else {
            Label("No meetings", systemImage: "calendar")
        }
    }

    // MARK: - Display helpers

    private func labelText(for meeting: Meeting) -> String {
        let urgency = meeting.urgencyLevel
        let displayTitle = meeting.truncatedTitle(maxLength: 20)

        switch urgency {
        case .none:
            return "\(meeting.formattedStartTime) · \(displayTitle)"
        case .low, .medium, .high:
            return "\(meeting.countdownLabel) · \(displayTitle)"
        case .ongoing:
            return "now · \(displayTitle)"
        }
    }

    private func iconName(for meeting: Meeting) -> String {
        switch meeting.urgencyLevel {
        case .high:
            return "calendar.badge.exclamationmark"
        case .ongoing:
            return "calendar.badge.clock"
        default:
            return "calendar"
        }
    }

    private func iconColor(for meeting: Meeting) -> Color {
        switch meeting.urgencyLevel {
        case .none:     return .primary
        case .low:      return .orange
        case .medium:   return .red
        case .high:     return .red
        case .ongoing:  return .blue
        }
    }
}
