# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

macOS SwiftUI menu bar calendar app. Build with:
```bash
xcodebuild -project MenuCal.xcodeproj -scheme MenuCal -configuration Debug build
open MenuCal.xcodeproj
```

No external dependencies — uses only Apple frameworks (SwiftUI, EventKit, SwiftData, AppKit).
No test targets currently configured.

## Design Philosophy

- Use modern Swift constructs: `@Observable`, async/await, SwiftUI previews
- Use Liquid Glass styling where applicable
- Prefer protocol-based abstractions for services

## Architecture

MenuCal is a macOS menu bar calendar app (`MenuBarExtra` with `.window` style) that displays calendar events and reminders.

### Layout

The app has two main sections stacked vertically:
1. **Month view** (top) — calendar grid with paged horizontal scrolling (`PagedMonthView`)
2. **Day view** (bottom) — switchable between two modes:
   - **Events view** — flat list of events for the selected day
   - **Timeline view** — events spread across time slots in a day timeline; overlapping events are spaced so all remain clickable and visible

Top and bottom toolbars provide navigation, search, calendar visibility toggles, and an "add event" button.

Event detail overlay (`EventDetailView`) appears over the day view when an event is selected.

### MVVM Pattern

**ViewModels** (`viewmodel/`):
- `AppViewModel` — core UI state: selected date, selected month, navigation, keyboard shortcuts, event selection. Uses `@Observable`.
- `EventsViewModel` — calendar visibility (hidden calendars persisted to UserDefaults), fetches calendars, handles event RSVP responses. Contains nested `DayEventsViewModel` for per-day event fetching.
- `PermissionsViewModel` — Calendar & Reminders permission state via EventKit.
- `CalendarViewModel` — **deprecated**, being replaced by the above three.

**Views** (`views/`):
- `AppView` → `CalView` → `PagedMonthView` + `EventsView` + `EventDetailView`
- `TopToolbar` / `BottomToolbar` — navigation and controls
- `details/` — 11 sub-views for event detail (title, time, participants, RSVP, notes, video call link, etc.)
- `DayEventsCapsule` — compact event indicators in month grid cells
- `DayBackgroundView` / `CurrentTimeView` — timeline visual components

### Event Display Rules

- Unaccepted and cancelled events display differently from normal/accepted events (visual distinction via participation status)
- In timeline view, overlapping events are laid out so all remain accessible and visible
- Video conference links are auto-detected from 8+ providers (Zoom, Meet, Teams, Webex, etc.)

### Service Layer (Protocol-Based)

- `CalendarService` protocol — `fetchEvents(for:)`, `fetchEvents(from:to:)`, `fetchCalendars()`, `respondToEvent(id:status:)`, `refreshData()`
- `ReminderService` protocol — `fetchReminders()`
- `AppleCalendarService` / `AppleReminderService` — EventKit implementations

### Models (`model/`)

- `Event` — full event data including participants, recurrence rules, participation status, video call link extraction
- `Reminder` — task with optional due date
- `Participant`, `ParticipationStatus`, `RecurrenceRule` — supporting types

### Keyboard Navigation

Arrow keys navigate dates, `t` jumps to today, `,`/`.` navigate months.

## Permissions

Requires Calendar and Reminders permissions via Info.plist (`NSCalendarsUsageDescription`, `NSRemindersUsageDescription`).
