import SwiftUI

/// Main popover view shown when clicking the menu bar item
struct PopoverContentView: View {
    @ObservedObject var meetingStore: MeetingStore

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView()

            Divider()

            // Error banner
            if let error = meetingStore.lastFetchError {
                FetchErrorBanner(message: error)
            }

            // AI Daily Briefing
            if meetingStore.isGeneratingBriefing {
                BriefingLoadingView()
            } else if let briefing = meetingStore.dailyBriefing {
                DailyBriefingView(briefing: briefing)
            }

            // Conflict alerts
            if !meetingStore.conflictDescriptions.isEmpty {
                ConflictBanner(descriptions: meetingStore.conflictDescriptions)
            }

            // Content
            if meetingStore.isLoading {
                LoadingView()
            } else if !meetingStore.calendarAccessGranted {
                CalendarAccessView(meetingStore: meetingStore)
            } else if meetingStore.todaysMeetings.isEmpty && meetingStore.lastFetchError == nil {
                EmptyStateView()
            } else {
                MeetingListView(
                    meetings: meetingStore.todaysMeetings,
                    nextMeeting: meetingStore.nextMeeting,
                    meetingSummaries: meetingStore.meetingSummaries
                )
            }

            Divider()

            // Footer
            FooterView()
        }
        .frame(width: 320, height: 420)
    }
}

// MARK: - Header

private struct HeaderView: View {
    var body: some View {
        HStack {
            Text(todayString())
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text("MemCache")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MemCache, \(todayString())")
    }

    private func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: Date())
    }
}

// MARK: - Loading

private struct LoadingView: View {
    var body: some View {
        Spacer()
        ProgressView("Loading meetings...")
            .progressViewStyle(.circular)
        Spacer()
    }
}

// MARK: - Calendar Access Request

private struct CalendarAccessView: View {
    @ObservedObject var meetingStore: MeetingStore

    var body: some View {
        Spacer()
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Calendar Access Required")
                .font(.headline)

            Text("MemCache needs access to your calendar to show upcoming meetings.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Button("Grant Access") {
                meetingStore.requestAccessAndFetch()
            }
            .buttonStyle(.borderedProminent)
        }
        Spacer()
    }
}

// MARK: - Empty State

private struct EmptyStateView: View {
    var body: some View {
        Spacer()
        VStack(spacing: 12) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("No meetings today")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Enjoy your free day!")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        Spacer()
    }
}

// MARK: - Fetch Error Banner

private struct FetchErrorBanner: View {
    let message: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.caption)
            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
    }
}

// MARK: - Daily Briefing

private struct DailyBriefingView: View {
    let briefing: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple)
                .font(.caption)
            Text(briefing)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.06))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("AI briefing: \(briefing)")
    }
}

private struct BriefingLoadingView: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "sparkles")
                .foregroundStyle(.purple.opacity(0.5))
                .font(.caption)
            Text("Generating daily briefing...")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            ProgressView()
                .controlSize(.mini)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.03))
    }
}

// MARK: - Conflict Banner

private struct ConflictBanner: View {
    let descriptions: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(descriptions, id: \.self) { desc in
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.2")
                        .foregroundStyle(.red)
                        .font(.caption2)
                    Text(desc)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.06))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Schedule conflict: \(descriptions.joined(separator: ". "))")
    }
}

// MARK: - Footer

private struct FooterView: View {
    var body: some View {
        HStack {
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit", systemImage: "power")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Quit MemCache")

            Spacer()

            Button(action: {
                if #available(macOS 14.0, *) {
                    NSApp.activate()
                } else {
                    NSApp.activate(ignoringOtherApps: true)
                }
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }) {
                Label("Settings", systemImage: "gear")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Open MemCache settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
