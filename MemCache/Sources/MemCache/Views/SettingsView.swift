import SwiftUI
import AppKit

/// Settings/Preferences window
struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Double = 60
    @AppStorage("showAllDayEvents") private var showAllDayEvents: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false
    @ObservedObject private var accountManager = CalendarAccountManager.shared

    var body: some View {
        TabView {
            GeneralSettingsView(
                refreshInterval: $refreshInterval,
                showAllDayEvents: $showAllDayEvents,
                launchAtLogin: $launchAtLogin
            )
            .tabItem {
                Label("General", systemImage: "gear")
            }

            CalendarsSettingsView(accountManager: accountManager)
                .tabItem {
                    Label("Calendars", systemImage: "calendar")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 350)
    }
}

// MARK: - General Settings

private struct GeneralSettingsView: View {
    @Binding var refreshInterval: Double
    @Binding var showAllDayEvents: Bool
    @Binding var launchAtLogin: Bool

    var body: some View {
        Form {
            Section("Display") {
                Toggle("Show all-day events", isOn: $showAllDayEvents)

                Picker("Refresh interval", selection: $refreshInterval) {
                    Text("30 seconds").tag(30.0)
                    Text("1 minute").tag(60.0)
                    Text("2 minutes").tag(120.0)
                    Text("5 minutes").tag(300.0)
                }
            }

            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Calendars Settings

private struct CalendarsSettingsView: View {
    @ObservedObject var accountManager: CalendarAccountManager

    var body: some View {
        Form {
            Section("Apple Calendar") {
                AppleCalendarRow(accountManager: accountManager, service: accountManager.appleService)
            }

            Section("Google Calendar") {
                GoogleCalendarRow(accountManager: accountManager)
            }

            Section("Outlook Calendar") {
                OutlookCalendarRow(accountManager: accountManager)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Apple Calendar Row

private struct AppleCalendarRow: View {
    @ObservedObject var accountManager: CalendarAccountManager
    let service: AppleCalendarService

    @State private var status: CalendarAuthStatus

    init(accountManager: CalendarAccountManager, service: AppleCalendarService) {
        self.accountManager = accountManager
        self.service = service
        self._status = State(initialValue: service.authorizationStatus)
    }

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: Binding(
                get: { accountManager.isAppleEnabled },
                set: { accountManager.setAppleEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)

            Image(systemName: "calendar")
                .foregroundStyle(.red)

            Text("Apple Calendar")

            Spacer()

            switch status {
            case .authorized:
                StatusBadge(connected: true)
            case .denied:
                Text("Denied")
                    .font(.caption)
                    .foregroundStyle(.red)
            case .restricted:
                Text("Restricted")
                    .font(.caption)
                    .foregroundStyle(.orange)
            case .notDetermined:
                Button("Grant Access") {
                    Task {
                        let granted = await service.requestAccess()
                        if granted {
                            status = .authorized
                        } else {
                            status = service.authorizationStatus
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Google Calendar Row

private struct GoogleCalendarRow: View {
    @ObservedObject var accountManager: CalendarAccountManager

    var body: some View {
        HStack(spacing: 8) {
            if accountManager.isGoogleConnected {
                Toggle("", isOn: Binding(
                    get: { accountManager.isGoogleEnabled },
                    set: { accountManager.setGoogleEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            Image(systemName: "globe")
                .foregroundStyle(.blue)

            Text("Google Calendar")

            Spacer()

            if accountManager.isGoogleConnecting {
                ProgressView()
                    .controlSize(.small)
                Text("Connecting...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if accountManager.isGoogleConnected {
                StatusBadge(connected: true)
                Button("Disconnect") {
                    accountManager.disconnectGoogle()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("Connect") {
                    Task {
                        await accountManager.connectGoogle()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Outlook Calendar Row

private struct OutlookCalendarRow: View {
    @ObservedObject var accountManager: CalendarAccountManager

    var body: some View {
        HStack(spacing: 8) {
            if accountManager.isOutlookConnected {
                Toggle("", isOn: Binding(
                    get: { accountManager.isOutlookEnabled },
                    set: { accountManager.setOutlookEnabled($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(.purple)

            Text("Outlook Calendar")

            Spacer()

            if accountManager.isOutlookConnecting {
                ProgressView()
                    .controlSize(.small)
                Text("Connecting...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if accountManager.isOutlookConnected {
                StatusBadge(connected: true)
                Button("Disconnect") {
                    accountManager.disconnectOutlook()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Button("Connect") {
                    Task {
                        await accountManager.connectOutlook()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Status Badge

private struct StatusBadge: View {
    let connected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(connected ? .green : .red)
                .frame(width: 8, height: 8)
            Text(connected ? "Connected" : "Not Connected")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - About

private struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 48))
                .foregroundStyle(.blue)

            Text("MemCache")
                .font(.title)
                .fontWeight(.bold)

            Text("Menu Bar Meeting Reminder")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Version 2.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Button("Send Feedback") {
                NSWorkspace.shared.open(URL(string: "https://github.com/madebysbroox/memcache/issues")!)
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
