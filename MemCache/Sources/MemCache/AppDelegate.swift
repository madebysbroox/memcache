import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let calendarAccountManager = CalendarAccountManager.shared
    private var meetingStore: MeetingStore!
    private var refreshTimer: Timer?
    private var pulseTimer: Timer?
    private var isPulseHigh: Bool = true
    private var isPopoverOpen: Bool = false
    private var noMeetingsRemaining: Bool = false
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize meeting store with all active calendar services
        meetingStore = MeetingStore(calendarServices: calendarAccountManager.allActiveServices())

        // Create the popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(meetingStore: meetingStore)
        )

        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.action = #selector(togglePopover)
            button.target = self
            updateMenuBarDisplay()
        }

        // Observe meeting store changes to update the menu bar text
        meetingStore.$nextMeeting
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)

        meetingStore.$urgencyLevel
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateMenuBarDisplay()
            }
            .store(in: &cancellables)

        // When calendar accounts change (connect/disconnect/toggle), update MeetingStore
        calendarAccountManager.servicesChanged
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                guard let self = self else { return }
                self.meetingStore.updateServices(self.calendarAccountManager.allActiveServices())
                self.meetingStore.refreshMeetings()
            }
            .store(in: &cancellables)

        // Observe refreshInterval changes from Settings
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rescheduleRefreshTimerIfNeeded()
            }
            .store(in: &cancellables)

        // Initial fetch
        meetingStore.requestAccessAndFetch()

        // Schedule the refresh timer
        scheduleRefreshTimer()

        // TODO: launchAtLogin – requires SMAppService (macOS 13+) or a login-item
        // helper bundle. Not implemented in this sprint.
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        pulseTimer?.invalidate()
    }

    /// Current interval used by the refresh timer, tracked so we only
    /// reschedule when the user actually changes the setting.
    private var currentRefreshInterval: TimeInterval = 0

    private func scheduleRefreshTimer() {
        refreshTimer?.invalidate()
        let userInterval = UserDefaults.standard.double(forKey: "refreshInterval")
        let baseSeconds = userInterval > 0 ? userInterval : 60

        let seconds: TimeInterval
        if isPopoverOpen {
            seconds = 30
        } else if noMeetingsRemaining {
            seconds = 300
        } else {
            seconds = baseSeconds
        }
        currentRefreshInterval = seconds

        meetingStore.syncCacheTTL()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: true) { [weak self] _ in
            self?.meetingStore.refreshMeetings()
        }
    }

    private func rescheduleRefreshTimerIfNeeded() {
        let userInterval = UserDefaults.standard.double(forKey: "refreshInterval")
        let baseSeconds = userInterval > 0 ? userInterval : 60

        let desiredSeconds: TimeInterval
        if isPopoverOpen {
            desiredSeconds = 30
        } else if noMeetingsRemaining {
            desiredSeconds = 300
        } else {
            desiredSeconds = baseSeconds
        }

        if desiredSeconds != currentRefreshInterval {
            scheduleRefreshTimer()
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
            isPopoverOpen = false
            scheduleRefreshTimer()
        } else {
            isPopoverOpen = true
            meetingStore.forceRefresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            scheduleRefreshTimer()
        }
    }

    private func startPulseTimer() {
        guard pulseTimer == nil else { return }
        // Respect the user's reduce motion accessibility preference
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            return
        }
        isPulseHigh = true
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.isPulseHigh.toggle()
            self.updateMenuBarDisplay()
        }
    }

    private func stopPulseTimer() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        isPulseHigh = true
    }

    private func updateMenuBarDisplay() {
        guard let button = statusItem.button else { return }

        // Detect no-meetings state and switch to relaxed polling
        let previousNoMeetings = noMeetingsRemaining
        noMeetingsRemaining = meetingStore.nextMeeting == nil
        if noMeetingsRemaining != previousNoMeetings {
            rescheduleRefreshTimerIfNeeded()
        }

        let display = MenuBarFormatter.format(
            meeting: meetingStore.nextMeeting,
            urgencyLevel: meetingStore.urgencyLevel
        )

        let urgency = meetingStore.urgencyLevel

        // Manage pulse timer based on urgency
        if urgency == .imminent {
            startPulseTimer()
        } else {
            stopPulseTimer()
        }

        // Build urgency dot prefix and attributes
        let dotPrefix: String
        let attributes: [NSAttributedString.Key: Any]

        switch urgency {
        case .imminent:
            let alpha: CGFloat = isPulseHigh ? 1.0 : 0.5
            dotPrefix = "\u{25CF} "
            attributes = [
                .foregroundColor: NSColor.systemRed.withAlphaComponent(alpha),
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
            ]
        case .soon:
            dotPrefix = "\u{25CF} "
            attributes = [
                .foregroundColor: NSColor.systemOrange,
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
            ]
        case .approaching:
            dotPrefix = "\u{25CF} "
            attributes = [
                .foregroundColor: NSColor.systemYellow,
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            ]
        case .normal:
            dotPrefix = ""
            attributes = [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
        case .none:
            dotPrefix = ""
            attributes = [
                .foregroundColor: NSColor.secondaryLabelColor,
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
        }

        let displayText = dotPrefix + display.text
        button.attributedTitle = NSAttributedString(string: displayText, attributes: attributes)

        // Accessibility for menu bar button
        button.setAccessibilityTitle("MemCache: \(display.text)")
        button.setAccessibilityHelp("Click to show today's meeting schedule")

        // Set image for calendar icon when no meetings, or warning icon when imminent
        if meetingStore.nextMeeting == nil {
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "MemCache")
            button.imagePosition = .imageLeading
        } else if urgency == .imminent {
            let symbol = NSImage(systemSymbolName: "exclamationmark.triangle.fill", accessibilityDescription: "Meeting imminent")
            let config = NSImage.SymbolConfiguration(paletteColors: [.systemRed])
            button.image = symbol?.withSymbolConfiguration(config)
            button.imagePosition = .imageLeading
        } else {
            button.image = nil
        }
    }
}
