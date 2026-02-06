import SwiftUI

/// Preferences window for managing calendar sources.
struct PreferencesView: View {
    @EnvironmentObject var calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Calendar Sources")
                .font(.title2.weight(.semibold))

            // Apple Calendar
            ProviderRow(
                name: "Apple Calendar",
                icon: "calendar",
                status: calendarService.appleProvider.status,
                connectAction: { calendarService.requestAppleAccess() },
                disconnectAction: nil
            )

            Divider()

            // Google Calendar
            ProviderRow(
                name: "Google Calendar",
                icon: "globe",
                status: calendarService.googleProvider.status,
                connectAction: { calendarService.connectGoogle() },
                disconnectAction: { calendarService.disconnectGoogle() }
            )

            Divider()

            // Microsoft Outlook
            ProviderRow(
                name: "Microsoft Outlook",
                icon: "envelope",
                status: calendarService.outlookProvider.status,
                connectAction: { calendarService.connectOutlook() },
                disconnectAction: { calendarService.disconnectOutlook() }
            )

            Divider()

            // Advanced settings
            Text("Advanced")
                .font(.title2.weight(.semibold))

            HStack {
                Text("Update interval")
                Spacer()
                Picker("", selection: $calendarService.pollInterval) {
                    Text("30 seconds").tag(30.0 as TimeInterval)
                    Text("1 minute").tag(60.0 as TimeInterval)
                    Text("2 minutes").tag(120.0 as TimeInterval)
                    Text("5 minutes").tag(300.0 as TimeInterval)
                    Text("10 minutes").tag(600.0 as TimeInterval)
                }
                .labelsHidden()
                .frame(width: 140)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 360, height: 400)
    }
}

// MARK: - Provider Row

struct ProviderRow: View {
    let name: String
    let icon: String
    let status: CalendarProviderStatus
    let connectAction: () -> Void
    let disconnectAction: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(statusColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            actionButton
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        switch status {
        case .authorized:
            if let disconnect = disconnectAction {
                Button("Disconnect") { disconnect() }
                    .foregroundStyle(.red)
            } else {
                Text("Connected")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        case .notConfigured:
            Button("Connect") { connectAction() }
        case .denied:
            Button("Grant Access") { connectAction() }
        case .error:
            Button("Retry") { connectAction() }
        }
    }

    private var statusText: String {
        switch status {
        case .authorized:    return "Connected"
        case .notConfigured: return "Not connected"
        case .denied(let m): return m
        case .error(let m):  return m
        }
    }

    private var statusColor: Color {
        switch status {
        case .authorized:    return .green
        case .notConfigured: return .secondary
        case .denied:        return .orange
        case .error:         return .red
        }
    }
}
