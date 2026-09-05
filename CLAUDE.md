# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

macOS SwiftUI menu bar calendar app. Build with:
```bash
xcodebuild -project MenuCal.xcodeproj -scheme MenuCal -configuration Debug build
open MenuCal.xcodeproj
```

Release build + DMG (note: `make dmg` does **not** clean, so run `make clean` first
or stale files can ship inside the bundle):
```bash
make clean && make dmg      # → dist/MenuCal.dmg
```

No external dependencies — uses only Apple frameworks (SwiftUI, AppKit, EventKit,
Network, CryptoKit, Security, ServiceManagement).
No test targets currently configured.

Deployment target is macOS 26.1. Note the machine may *run* a newer macOS than the
installed SDK can *build* against — check `xcrun --show-sdk-version` before reaching
for a new API.

### Secrets.xcconfig (required)

Google OAuth credentials come from an untracked `Secrets.xcconfig` at the repo root,
wired in as the target's `baseConfigurationReference`:

```
GOOGLE_CLIENT_ID = <id>.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET = <secret>
```

They reach the app through `Info.plist` (`$(GOOGLE_CLIENT_ID)` /
`$(GOOGLE_CLIENT_SECRET)`) and are read via `Bundle.main.object(forInfoDictionaryKey:)`.
Without this file the build succeeds but `GoogleAuth` reports a missing client ID.
The secret is not confidential for an installed app (RFC 8252) but should stay out of
git.

## Design Philosophy

- Use modern Swift constructs: `@Observable`, async/await, SwiftUI previews
- Use Liquid Glass styling where applicable (`glassEffect`, `GlassEffectContainer`,
  `glassEffectTransition`; see `toolbarPill()` in `views/extensions/ViewModifiers.swift`)
- Prefer protocol-based abstractions for services

## Architecture

MenuCal is a macOS menu bar calendar app (`MenuBarExtra` with `.window` style) that
displays calendar events and reminders.

### Layout

The app has two main sections stacked vertically:
1. **Month view** (top) — calendar grid with paged horizontal scrolling (`PagedMonthView`)
2. **Day view** (bottom) — switchable between two modes:
   - **Events view** — flat list of events for the selected day
   - **Timeline view** — events spread across time slots in a day timeline; overlapping events are spaced so all remain clickable and visible

Top and bottom toolbars provide navigation, search, calendar visibility toggles, and an "add event" button.

Event detail overlay (`EventDetailView`) appears over the day view when an event is
selected. The RSVP control (`ParticipationView`) is **not** part of it — it's pinned
below the scroll view in `CalView` so a long guest list or notes can't push it past
the fold.

There is also a `Window` scene (`OnboardingWindow`, id `"onboarding"`) for setup. See
[Setup window](#setup-window) for why it can't be part of the popover.

### MVVM Pattern

**ViewModels** (`viewmodel/`):
- `AppViewModel` — core UI state: selected date, selected month, navigation, keyboard shortcuts, event selection. Uses `@Observable`.
- `EventsViewModel` — calendar visibility (hidden calendars persisted to UserDefaults), fetches calendars, records RSVP responses. Contains nested `DayEventsViewModel` for per-day event fetching.
- `PermissionsViewModel` — Calendar & Reminders permission state via EventKit.
- `SettingsViewModel` — user preferences (UserDefaults) plus launch-at-login. A `shared` singleton so the service layer can read preferences.
- `RSVPOverrides` — pending RSVPs layered onto fetched events. See below.

**Views** (`views/`):
- `AppView` → `CalView` → `PagedMonthView` + `EventsView` + `EventDetailView`
- `TopToolbar` / `BottomToolbar` — navigation and controls
- `OnboardingWindow` — setup steps (permissions → Google → done)
- `details/` — 11 sub-views for event detail (title, time, participants, RSVP, notes, video call link, etc.)
- `DayEventsCapsule` — compact event indicators in month grid cells
- `DayBackgroundView` / `CurrentTimeView` — timeline visual components

### Event Display Rules

- Unaccepted and cancelled events display differently from normal/accepted events
  (`Event.isUnaccepted` drives `SlantedStripes`; note **tentative counts as unaccepted**)
- In timeline view, overlapping events are laid out so all remain accessible and visible
- Video conference links are auto-detected from 8+ providers (Zoom, Meet, Teams, Webex, etc.)
- `ParticipationStatus.color` uses AppKit's dynamic system colours
  (`Color(nsColor: .systemGreen)`), not SwiftUI's fixed `.green` — the latter don't
  adapt to light/dark or Increase Contrast

### Service Layer (Protocol-Based)

- `CalendarService` protocol — `fetchEvents(for:)`, `fetchEvents(from:to:)`,
  `fetchCalendars()`, `respondToEvent(event:status:) -> RespondOutcome`, `refreshData()`
- `ReminderService` protocol — `fetchReminders()`
- `AppleCalendarService` / `AppleReminderService` — EventKit implementations
- `GoogleAuth` — OAuth for the Google Calendar API (`@Observable`, `@MainActor`, singleton)
- `GoogleCalendarAPI` — the RSVP write
- `Keychain` — generic-password wrapper; holds only the Google refresh token
- `GoogleCalendarDeepLink` — builds/opens Google Calendar URLs (fallback path)

Reminders are fetched by the service layer but **nothing in the UI reads them yet**.

## RSVP writes and RSVPOverrides

**EventKit cannot set your own participation status.** `EKParticipant.participantStatus`
and `EKCalendarItem.attendees` are read-only and there is no write API — verified
against the SDK headers, not assumed. There's no Siri/App Intents route either: macOS
27's `.calendar` app-schema domain has only `createEvent` / `deleteEvent` /
`updateEvent`, none of which take an attendee status, and `attendeeStatus` exists only
as a *readable* property on the attendee entity. Don't go looking again.

So `AppleCalendarService.respondToEvent` branches:

1. **Google-account event with an account connected** → written through
   `GoogleCalendarAPI.setResponseStatus`. Returns `.written`.
2. **Everything else** → deep-link handoff to Google Calendar or Calendar.app.
   Returns `.handedOff`.

Every failure in (1) falls through to (2), so the button can never dead-end.

`RespondOutcome` matters: `.handedOff` means the user still has to respond in another
app, so the UI must not show a response they haven't made.

### The Google write

Read-modify-write, and the ordering is not optional:

```
GET  /calendars/{email}/events/{eventId}
mutate attendees[where self == true].responseStatus
PATCH same URL, body { attendees: <entire array> }, ?sendUpdates=all
```

**Array fields overwrite wholesale in Google's patch semantics** — sending only your
own attendee entry deletes everyone else from the event.

Event id resolution: `Event.googleEventId` derives it from the iCalUID, including the
`{seriesId}_{UTCStart}Z` instance suffix for recurring occurrences. When the UID is
foreign (invite created outside Google) it isn't derivable, and
`GoogleCalendarAPI.resolveEventID` falls back to an `events?iCalUID=` lookup.

### Why RSVPOverrides exists

A Google write does not reach EventKit until CalDAV syncs — seconds to minutes.
`refreshSourcesIfNecessary()` is only a hint and `.EKEventStoreChanged` has no timing
guarantee. Without an override layer the event keeps its unaccepted striping after
you've accepted it.

- **Applied in `DayEventsViewModel.fetchEvents`** — the single point every view fetches
  through, so stripes, month capsules and the detail view all update together. It
  rewrites `participationStatus` on the fetched events (hence that field is `var`)
  rather than sitting beside them, so no view needed changing.
- **Keyed by occurrence, not `event.id`.** EventKit gives every occurrence of a
  recurring series the same `eventIdentifier`, so an id-only key would apply one RSVP
  to the entire series. The key is `id + (occurrenceDate ?? untrimmedStart ?? startTime)`
  — `startTime` alone is unusable because `clampedToDay` mutates it.
- **Recorded only on `.written`**, and only applied optimistically when a write is
  actually going to be attempted (`isOnGoogleAccount && GoogleAuth.shared.isConnected`)
  — otherwise every hand-off would flash a status and revert it.
- **Dropped as soon as EventKit reports the same status.** That's the real exit; the
  24h TTL is a backstop. Overrides persist to UserDefaults so quitting inside the sync
  window doesn't resurrect the old striping.
- **Also caches the last status EventKit reported per occurrence** (`confirmedStatus`).
  `AppViewModel.selectedEvent` is a snapshot taken when the detail opened and is never
  refreshed, so once an override is dropped, falling back to the event's own value
  would revert the control to the pre-RSVP answer. Resolution order in
  `EventsViewModel.displayStatus` is: **pending override → last seen from EventKit →
  the event's own value.**

### Redrawing after a response

`respondToEvent` is **not** async — it records the override, bumps `refreshTick`, and
lets the network write run behind it, rolling back if the write fails or was a
hand-off. Rollback only fires if the override still holds the value *that* request
wrote, so a late failure can't clobber a newer answer.

Bump `refreshTick` directly; **don't rely on `refreshAll()` to do it.** `refreshAll()`
opens with `guard !isRefreshing` and that flag can stay true for up to 60s, so it
silently no-ops and nothing re-fetches.

## Setup window

`OnboardingWindow` is a real `Window` scene, not a popover section, because both setup
steps hand off to another app — System Settings for permissions,
the browser for Google — and `MenuBarExtra(.window)` dismisses the instant another app
becomes active, taking any progress or error state with it.

- Steps are **derived, not navigated**: no permissions → `.permissions`; connected or
  has Google calendars → `.google`; otherwise → `.done`.
- Presented at launch from the **menu bar label**'s `onAppear`
  (`MenuBarLabel` in `MenuCalApp.swift`). It cannot live in `AppView.onAppear` —
  that's the popover's content and doesn't exist until the icon is clicked.
- `SettingsViewModel.didSeeGoogleOnboarding` makes the Google offer one-time; Settings
  is the way back.
- **SwiftUI has no API to present a `MenuBarExtra` popover programmatically**, so setup
  ends by telling the user the app is in the menu bar rather than opening it for them.

## Permissions

- **Calendar only gates the app.** Reminders is requested but optional — nothing reads
  it, and gating on it locked users out of a working calendar.
- A grant confirmed by the request's own return value outranks
  `EKEventStore.authorizationStatus`, which can still report `.notDetermined` for a
  while afterwards. An explicit `.denied`/`.restricted` still wins, so revocation is
  noticed. Without this the poll loop overwrites a real grant with a stale reading and
  the UI asks forever.
- The effective usage-description keys are `NSCalendarsFullAccessUsageDescription` and
  `NSRemindersFullAccessUsageDescription`, set via `INFOPLIST_KEY_*` build settings.

## Gotchas

- **`Info.plist` is the target's real plist** (`INFOPLIST_FILE = Info.plist`), merged
  with the `INFOPLIST_KEY_*` build settings. It used to be dead — copied into
  `Resources/` and never read. Edits to it now take effect. `INFOPLIST_KEY_<custom>`
  silently drops keys Xcode doesn't know, so custom values must go in the file itself.
- **Sandbox**: `ENABLE_OUTGOING_NETWORK_CONNECTIONS` and
  `ENABLE_INCOMING_NETWORK_CONNECTIONS` are both required — the second for the OAuth
  loopback listener.
- **New files need pbxproj entries** (no file-system-synchronized groups): a
  `PBXFileReference`, a `PBXBuildFile`, group membership, and the Sources build phase.
- The popover is identified in `MenuCalApp`'s `didBecomeKey` observer by being
  **untitled and within 80pt of `appWidth`**. Any new untitled window of similar width
  will trip `handleWindowBecameKey` and reset the user's selected date.
- Sandboxed `NSLog` output isn't reliably visible; `AppleCalendarService.debugLog`
  appends to `~/Library/Containers/sak3th.MenuCal/Data/tmp/rsvp-debug.log`.

### Keyboard Navigation

Arrow keys navigate dates, `t` jumps to today, `,`/`.` navigate months.

### Models (`model/`)

- `Event` — full event data including participants, recurrence rules, participation
  status, video call link extraction, and Google id derivation
- `Reminder` — task with optional due date
- `Participant`, `ParticipationStatus`, `RecurrenceRule` — supporting types
