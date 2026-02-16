import SwiftUI

/// Settings/Preferences window
struct SettingsView: View {
    @AppStorage("refreshInterval") private var refreshInterval: Double = 60
    @AppStorage("showAllDayEvents") private var showAllDayEvents: Bool = true
    @AppStorage("launchAtLogin") private var launchAtLogin: Bool = false

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

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 400, height: 250)
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

            Text("Version 1.0.0")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
