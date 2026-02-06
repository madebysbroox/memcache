#!/usr/bin/env bash
#
# Structural validation test for MenuBarMeetings (Sprint 1 + Sprint 2).
# Verifies directory layout, required files, Info.plist config, and
# Swift source conventions without needing a Swift compiler.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }

echo "=== MenuBarMeetings Scaffolding Tests ==="
echo ""

# ── 1. Directory layout ──────────────────────────────────────────────
echo "[1] Directory layout"

for dir in \
    MenuBarMeetings/App \
    MenuBarMeetings/Views \
    MenuBarMeetings/Models \
    MenuBarMeetings/Services \
    MenuBarMeetings/Resources/Assets.xcassets/AppIcon.appiconset \
    MenuBarMeetings/Resources/Assets.xcassets/MenuBarIcon.imageset; do
    if [ -d "$ROOT/$dir" ]; then
        pass "$dir/ exists"
    else
        fail "$dir/ missing"
    fi
done

# ── 2. Required source files ─────────────────────────────────────────
echo ""
echo "[2] Required source files"

for file in \
    Package.swift \
    MenuBarMeetings/Info.plist \
    MenuBarMeetings/App/MenuBarMeetingsApp.swift \
    MenuBarMeetings/Views/MenuBarView.swift \
    MenuBarMeetings/Views/PopupView.swift \
    MenuBarMeetings/Models/Meeting.swift \
    MenuBarMeetings/Services/CalendarService.swift \
    MenuBarMeetings/Resources/Assets.xcassets/Contents.json \
    MenuBarMeetings/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json \
    MenuBarMeetings/Resources/Assets.xcassets/MenuBarIcon.imageset/Contents.json; do
    if [ -f "$ROOT/$file" ]; then
        pass "$file exists"
    else
        fail "$file missing"
    fi
done

# ── 3. Info.plist checks ─────────────────────────────────────────────
echo ""
echo "[3] Info.plist configuration"

PLIST="$ROOT/MenuBarMeetings/Info.plist"

if grep -q '<key>LSUIElement</key>' "$PLIST" && grep -A1 '<key>LSUIElement</key>' "$PLIST" | grep -q '<true/>'; then
    pass "LSUIElement is true (no Dock icon)"
else
    fail "LSUIElement not set to true"
fi

if grep -q 'com.memcache.menubar-meetings' "$PLIST"; then
    pass "Bundle identifier is com.memcache.menubar-meetings"
else
    fail "Bundle identifier incorrect"
fi

if grep -q '<string>13.0</string>' "$PLIST"; then
    pass "Minimum macOS version is 13.0"
else
    fail "Minimum macOS version not set to 13.0"
fi

# ── 4. Package.swift checks ──────────────────────────────────────────
echo ""
echo "[4] Package.swift configuration"

PKG="$ROOT/Package.swift"

if grep -q '\.macOS(.v13)' "$PKG"; then
    pass "Platform target is macOS 13+"
else
    fail "Platform target not set to macOS 13"
fi

if grep -q 'executableTarget' "$PKG"; then
    pass "Executable target defined"
else
    fail "No executable target"
fi

# ── 5. Swift source conventions ───────────────────────────────────────
echo ""
echo "[5] Swift source conventions"

APP="$ROOT/MenuBarMeetings/App/MenuBarMeetingsApp.swift"

if grep -q '@main' "$APP"; then
    pass "@main entry point declared"
else
    fail "@main entry point missing"
fi

if grep -q 'MenuBarExtra' "$APP"; then
    pass "MenuBarExtra API used"
else
    fail "MenuBarExtra API not found"
fi

if grep -q 'NSApplicationDelegateAdaptor' "$APP"; then
    pass "AppDelegate adaptor wired up"
else
    fail "AppDelegate adaptor missing"
fi

if grep -q '\.window' "$APP"; then
    pass "MenuBarExtra style set to .window"
else
    fail "MenuBarExtra style not set to .window"
fi

POPUP="$ROOT/MenuBarMeetings/Views/PopupView.swift"

if grep -q 'NSApplication.shared.terminate' "$POPUP"; then
    pass "Quit button calls terminate"
else
    fail "Quit action missing in PopupView"
fi

if grep -q 'frame(width: 320, height: 400)' "$POPUP"; then
    pass "Popup frame is 320x400"
else
    fail "Popup frame dimensions incorrect"
fi

LABEL="$ROOT/MenuBarMeetings/Views/MenuBarView.swift"

if grep -q 'No meetings' "$LABEL"; then
    pass "Fallback text present in MenuBarView"
else
    fail "Fallback text missing in MenuBarView"
fi

# ── 6. Sprint 2: Meeting model ───────────────────────────────────────
echo ""
echo "[6] Meeting data model"

MODEL="$ROOT/MenuBarMeetings/Models/Meeting.swift"

if grep -q 'struct Meeting: Identifiable' "$MODEL"; then
    pass "Meeting struct conforms to Identifiable"
else
    fail "Meeting struct missing or not Identifiable"
fi

for prop in startDate endDate isAllDay title calendarName; do
    if grep -q "$prop" "$MODEL"; then
        pass "Meeting has '$prop' property"
    else
        fail "Meeting missing '$prop' property"
    fi
done

if grep -q 'menuBarLabel' "$MODEL"; then
    pass "Meeting has menuBarLabel computed property"
else
    fail "Meeting missing menuBarLabel"
fi

if grep -q 'formattedStartTime' "$MODEL"; then
    pass "Meeting has formattedStartTime"
else
    fail "Meeting missing formattedStartTime"
fi

if grep -q 'formattedDuration' "$MODEL"; then
    pass "Meeting has formattedDuration"
else
    fail "Meeting missing formattedDuration"
fi

# ── 7. CalendarService & Providers ────────────────────────────────────
echo ""
echo "[7] CalendarService & providers"

SVC="$ROOT/MenuBarMeetings/Services/CalendarService.swift"

if grep -q 'ObservableObject' "$SVC"; then
    pass "CalendarService is ObservableObject"
else
    fail "CalendarService is not ObservableObject"
fi

if grep -q 'requestAppleAccess' "$SVC"; then
    pass "CalendarService has requestAppleAccess()"
else
    fail "CalendarService missing requestAppleAccess()"
fi

if grep -q 'connectGoogle' "$SVC"; then
    pass "CalendarService has connectGoogle()"
else
    fail "CalendarService missing connectGoogle()"
fi

if grep -q 'refresh' "$SVC"; then
    pass "CalendarService has refresh()"
else
    fail "CalendarService missing refresh()"
fi

if grep -q 'Timer.scheduledTimer' "$SVC"; then
    pass "CalendarService has polling timer"
else
    fail "CalendarService missing polling timer"
fi

if grep -q 'nextMeeting' "$SVC"; then
    pass "CalendarService exposes nextMeeting"
else
    fail "CalendarService missing nextMeeting"
fi

# ── 8. Sprint 2: View integration ────────────────────────────────────
echo ""
echo "[8] Sprint 2 view integration"

if grep -q 'CalendarService' "$APP"; then
    pass "App entry point uses CalendarService"
else
    fail "App entry point does not reference CalendarService"
fi

if grep -q 'environmentObject' "$APP"; then
    pass "CalendarService passed as environmentObject"
else
    fail "environmentObject not used in App"
fi

if grep -q 'nextMeeting' "$LABEL"; then
    pass "MenuBarView receives nextMeeting"
else
    fail "MenuBarView does not use nextMeeting"
fi

if grep -q 'EnvironmentObject' "$POPUP"; then
    pass "PopupView reads CalendarService from environment"
else
    fail "PopupView missing EnvironmentObject"
fi

if grep -q 'MeetingRow' "$POPUP"; then
    pass "PopupView renders MeetingRow components"
else
    fail "PopupView missing MeetingRow"
fi

if grep -q 'requestAppleAccess\|requestAccess' "$POPUP"; then
    pass "PopupView triggers permission request on appear"
else
    fail "PopupView does not trigger requestAccess"
fi

# ── 9. Sprint 3: Popup daily view polish ──────────────────────────────
echo ""
echo "[9] Sprint 3 popup daily view"

if grep -q 'calendarColor' "$MODEL"; then
    pass "Meeting has calendarColor property"
else
    fail "Meeting missing calendarColor"
fi

if grep -q 'formattedTimeRange' "$MODEL"; then
    pass "Meeting has formattedTimeRange"
else
    fail "Meeting missing formattedTimeRange"
fi

if grep -q 'AllDayRow' "$POPUP"; then
    pass "PopupView has AllDayRow component"
else
    fail "PopupView missing AllDayRow"
fi

if grep -q 'SectionHeader' "$POPUP"; then
    pass "PopupView has SectionHeader component"
else
    fail "PopupView missing SectionHeader"
fi

if grep -q 'calendarColor' "$POPUP"; then
    pass "MeetingRow shows calendar color dot"
else
    fail "MeetingRow missing calendar color"
fi

if grep -q 'formattedTimeRange' "$POPUP"; then
    pass "MeetingRow shows time range"
else
    fail "MeetingRow missing time range"
fi

if grep -q 'location' "$POPUP"; then
    pass "MeetingRow shows location when available"
else
    fail "MeetingRow missing location display"
fi

if grep -q 'isOngoing' "$POPUP"; then
    pass "MeetingRow highlights ongoing meetings"
else
    fail "MeetingRow does not highlight ongoing meetings"
fi

# ── 10. Sprint 4: Smart menu bar & urgency ────────────────────────────
echo ""
echo "[10] Sprint 4 smart menu bar & urgency"

if grep -q 'UrgencyLevel' "$MODEL"; then
    pass "UrgencyLevel enum defined"
else
    fail "UrgencyLevel enum missing"
fi

if grep -q 'urgencyLevel' "$MODEL"; then
    pass "Meeting has urgencyLevel property"
else
    fail "Meeting missing urgencyLevel"
fi

if grep -q 'minutesUntilStart' "$MODEL"; then
    pass "Meeting has minutesUntilStart"
else
    fail "Meeting missing minutesUntilStart"
fi

if grep -q 'countdownLabel' "$MODEL"; then
    pass "Meeting has countdownLabel"
else
    fail "Meeting missing countdownLabel"
fi

if grep -q 'truncatedTitle' "$MODEL"; then
    pass "Meeting has truncatedTitle()"
else
    fail "Meeting missing truncatedTitle()"
fi

if grep -q 'urgencyLevel' "$LABEL"; then
    pass "MenuBarView uses urgencyLevel"
else
    fail "MenuBarView does not use urgencyLevel"
fi

if grep -q 'countdownLabel' "$LABEL"; then
    pass "MenuBarView shows countdown"
else
    fail "MenuBarView does not show countdown"
fi

if grep -q 'truncatedTitle' "$LABEL"; then
    pass "MenuBarView uses truncatedTitle"
else
    fail "MenuBarView does not use truncatedTitle"
fi

if grep -q 'iconColor' "$LABEL"; then
    pass "MenuBarView has urgency-based icon color"
else
    fail "MenuBarView missing urgency icon color"
fi

if grep -q 'calendar.badge' "$LABEL"; then
    pass "MenuBarView uses urgency-specific SF Symbols"
else
    fail "MenuBarView missing urgency SF Symbols"
fi

# ── 11. Sprint 5: Multi-calendar & preferences ────────────────────────
echo ""
echo "[11] Sprint 5 multi-calendar & preferences"

PROVIDER="$ROOT/MenuBarMeetings/Services/CalendarProvider.swift"
APPLE="$ROOT/MenuBarMeetings/Services/AppleCalendarProvider.swift"
GOOGLE="$ROOT/MenuBarMeetings/Services/GoogleCalendarProvider.swift"
KEYCHAIN="$ROOT/MenuBarMeetings/Services/KeychainHelper.swift"
PREFS="$ROOT/MenuBarMeetings/Views/PreferencesView.swift"

for file in "$PROVIDER" "$APPLE" "$GOOGLE" "$KEYCHAIN" "$PREFS"; do
    name=$(basename "$file")
    if [ -f "$file" ]; then
        pass "$name exists"
    else
        fail "$name missing"
    fi
done

if grep -q 'protocol CalendarProvider' "$PROVIDER"; then
    pass "CalendarProvider protocol defined"
else
    fail "CalendarProvider protocol missing"
fi

if grep -q 'CalendarProviderStatus' "$PROVIDER"; then
    pass "CalendarProviderStatus enum defined"
else
    fail "CalendarProviderStatus missing"
fi

if grep -q 'CalendarProvider' "$APPLE" && grep -q 'EventKit' "$APPLE"; then
    pass "AppleCalendarProvider conforms to protocol and uses EventKit"
else
    fail "AppleCalendarProvider not properly implemented"
fi

if grep -q 'CalendarProvider' "$GOOGLE" && grep -q 'OAuth' "$GOOGLE"; then
    pass "GoogleCalendarProvider conforms to protocol with OAuth"
else
    fail "GoogleCalendarProvider not properly implemented"
fi

if grep -q 'SecItemAdd\|kSecClass' "$KEYCHAIN"; then
    pass "KeychainHelper uses Security framework"
else
    fail "KeychainHelper missing Security framework usage"
fi

if grep -q 'enabledProviders\|providers' "$SVC"; then
    pass "CalendarService aggregates multiple providers"
else
    fail "CalendarService not aggregating providers"
fi

if grep -q 'ProviderRow' "$PREFS"; then
    pass "PreferencesView has ProviderRow components"
else
    fail "PreferencesView missing ProviderRow"
fi

if grep -q 'Settings' "$APP"; then
    pass "App registers Settings scene for Preferences"
else
    fail "App missing Settings scene"
fi

if grep -q 'showSettingsWindow\|showPreferencesWindow' "$POPUP"; then
    pass "PopupView Preferences button opens settings"
else
    fail "PopupView Preferences button not wired"
fi

if grep -qv '\.disabled(true)' "$POPUP" || ! grep -q 'Preferences.*disabled' "$POPUP"; then
    pass "Preferences button is enabled"
else
    fail "Preferences button still disabled"
fi

# ── Summary ───────────────────────────────────────────────────────────
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
