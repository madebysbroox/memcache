import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var calendarService: CalendarService!
    private var meetingStore: MeetingStore!
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize services
        calendarService = CalendarService()
        meetingStore = MeetingStore(calendarService: calendarService)

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

        // Initial fetch
        meetingStore.requestAccessAndFetch()

        // Refresh every 60 seconds
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.meetingStore.refreshMeetings()
            self?.updateMenuBarDisplay()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            meetingStore.refreshMeetings()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func updateMenuBarDisplay() {
        guard let button = statusItem.button else { return }

        let display = MenuBarFormatter.format(
            meeting: meetingStore.nextMeeting,
            urgencyLevel: meetingStore.urgencyLevel
        )

        button.title = display.text

        // Apply urgency-based styling
        let attributes: [NSAttributedString.Key: Any]
        switch meetingStore.urgencyLevel {
        case .imminent:
            attributes = [
                .foregroundColor: NSColor.systemRed,
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold)
            ]
        case .soon:
            attributes = [
                .foregroundColor: NSColor.systemOrange,
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)
            ]
        case .approaching:
            attributes = [
                .foregroundColor: NSColor.systemYellow,
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            ]
        case .normal, .none:
            attributes = [
                .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            ]
        }

        button.attributedTitle = NSAttributedString(string: display.text, attributes: attributes)

        // Set image for calendar icon when no meetings
        if meetingStore.nextMeeting == nil {
            button.image = NSImage(systemSymbolName: "calendar", accessibilityDescription: "MemCache")
            button.imagePosition = .imageLeading
        } else {
            button.image = nil
        }
    }
}
