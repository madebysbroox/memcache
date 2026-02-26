import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let calendarAccountManager = CalendarAccountManager.shared
    private var meetingStore: MeetingStore!
    private var refreshTimer: Timer?
    private var isPopoverOpen: Bool = false
    private var noMeetingsRemaining: Bool = false
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    // MARK: - Smooth animation state
    private var animationTimer: Timer?
    private var breathePhase: Double = 0
    private var lastAnimationUpdate: Date = Date()
    private var lastUrgencyLevel: UrgencyLevel = .none
    private var symbolBounceTriggered: Bool = false

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
        animationTimer?.invalidate()
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

    // MARK: - Smooth Breathing Animation

    /// Start the animation timer for smooth breathing effects.
    /// Runs at ~20Hz for smooth alpha transitions without excessive CPU.
    private func startAnimationTimer() {
        guard animationTimer == nil else { return }
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            return
        }
        lastAnimationUpdate = Date()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            let dt = now.timeIntervalSince(self.lastAnimationUpdate)
            self.lastAnimationUpdate = now
            self.advanceBreatheAnimation(dt: dt)
        }
    }

    private func stopAnimationTimer() {
        animationTimer?.invalidate()
        animationTimer = nil
        breathePhase = 0
    }

    /// Breathing speed (radians/sec) based on urgency — faster as meeting approaches.
    private func breatheSpeed(for urgency: UrgencyLevel) -> Double {
        switch urgency {
        case .imminent:   return .pi * 2.0    // Full cycle in ~1 second
        case .soon:       return .pi * 1.0    // Full cycle in ~2 seconds
        case .approaching: return .pi * 0.5   // Full cycle in ~4 seconds
        default:          return 0
        }
    }

    /// Advance the breathe animation and update the display.
    private func advanceBreatheAnimation(dt: Double) {
        let urgency = meetingStore.urgencyLevel
        let speed = breatheSpeed(for: urgency)
        guard speed > 0 else { return }
        breathePhase += speed * dt
        if breathePhase > .pi * 2.0 { breathePhase -= .pi * 2.0 }
        updateMenuBarDisplay()
    }

    /// Smooth alpha value from the breathe phase (oscillates between 0.35 and 1.0).
    private var breatheAlpha: CGFloat {
        CGFloat(0.675 + 0.325 * sin(breathePhase))
    }

    // MARK: - Menu Bar Display

    private func updateMenuBarDisplay() {
        guard let button = statusItem.button else { return }

        // Detect no-meetings state and switch to relaxed polling
        let previousNoMeetings = noMeetingsRemaining
        noMeetingsRemaining = meetingStore.nextMeeting == nil
        if noMeetingsRemaining != previousNoMeetings {
            rescheduleRefreshTimerIfNeeded()
        }

        let urgency = meetingStore.urgencyLevel

        // Use live countdown for imminent/soon meetings
        let display = MenuBarFormatter.format(
            meeting: meetingStore.nextMeeting,
            urgencyLevel: urgency,
            liveCountdown: urgency == .imminent || urgency == .soon
        )

        // Trigger one-shot bounce when urgency level escalates
        if urgency != lastUrgencyLevel {
            if urgency.rawValue > lastUrgencyLevel.rawValue {
                symbolBounceTriggered = true
            }
            lastUrgencyLevel = urgency
        }

        // Manage animation timer: run for approaching/soon/imminent
        let needsAnimation = urgency >= .approaching
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if needsAnimation {
            startAnimationTimer()
        } else {
            stopAnimationTimer()
        }

        // Build urgency indicator and text attributes
        let dotPrefix: String
        let textColor: NSColor
        let fontWeight: NSFont.Weight

        switch urgency {
        case .imminent:
            dotPrefix = "\u{25CF} "
            textColor = NSColor.systemRed.withAlphaComponent(breatheAlpha)
            fontWeight = .bold
        case .soon:
            dotPrefix = "\u{25CF} "
            textColor = NSColor.systemOrange.withAlphaComponent(breatheAlpha)
            fontWeight = .semibold
        case .approaching:
            dotPrefix = "\u{25CF} "
            textColor = NSColor.systemYellow.withAlphaComponent(breatheAlpha)
            fontWeight = .medium
        case .normal:
            dotPrefix = ""
            textColor = NSColor.labelColor
            fontWeight = .regular
        case .none:
            dotPrefix = ""
            textColor = NSColor.secondaryLabelColor
            fontWeight = .regular
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: textColor,
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: fontWeight)
        ]

        let displayText = dotPrefix + display.text
        button.attributedTitle = NSAttributedString(string: displayText, attributes: attributes)

        // Accessibility
        button.setAccessibilityTitle("MemCache: \(display.text)")
        button.setAccessibilityHelp("Click to show today's meeting schedule")

        // Dynamic SF Symbol icon based on urgency
        if meetingStore.nextMeeting == nil {
            let symbol = NSImage(
                systemSymbolName: "calendar",
                accessibilityDescription: "MemCache"
            )
            button.image = symbol
            button.imagePosition = .imageLeading
        } else {
            let (symbolName, symbolColor) = urgencySymbol(for: urgency)
            let symbol = NSImage(
                systemSymbolName: symbolName,
                accessibilityDescription: urgencyAccessibilityDescription(for: urgency)
            )
            let config = NSImage.SymbolConfiguration(paletteColors: [symbolColor])
            button.image = symbol?.withSymbolConfiguration(config)
            button.imagePosition = .imageLeading

            // Apply SF Symbol bounce effect on urgency escalation (macOS 14+)
            if symbolBounceTriggered {
                symbolBounceTriggered = false
                if #available(macOS 14.0, *) {
                    if let imageView = button.subviews.compactMap({ $0 as? NSImageView }).first {
                        imageView.addSymbolEffect(.bounce, options: .nonRepeating)
                    }
                }
            }
        }
    }

    /// Returns the appropriate SF Symbol name and color for each urgency level.
    /// Progressive icon sequence: calendar → clock → warning
    private func urgencySymbol(for urgency: UrgencyLevel) -> (String, NSColor) {
        switch urgency {
        case .imminent:
            return ("exclamationmark.triangle.fill", .systemRed)
        case .soon:
            return ("clock.badge.exclamationmark.fill", .systemOrange)
        case .approaching:
            return ("clock.fill", .systemYellow)
        case .normal:
            return ("calendar", .labelColor)
        case .none:
            return ("calendar", .secondaryLabelColor)
        }
    }

    private func urgencyAccessibilityDescription(for urgency: UrgencyLevel) -> String {
        switch urgency {
        case .imminent: return "Meeting imminent"
        case .soon: return "Meeting soon"
        case .approaching: return "Meeting approaching"
        case .normal: return "Upcoming meeting"
        case .none: return "No meetings"
        }
    }
}
