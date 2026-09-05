# MenuCal

A macOS menu bar calendar. Your month, your day, and your next meeting's video link,
one click from the status bar — and, unlike most menu bar calendars, you can actually
RSVP from it.

Requires **macOS 26.1** or later.

## What it does

- **Month grid + day view** in a single popover, with paged month scrolling
- **Timeline or list** for the selected day; overlapping events are laid out so every
  one stays visible and clickable
- **All-day events** pinned in a capped strip above the day view
- **Event detail** — participants and their responses, notes, calendar, recurrence
- **Video call links** auto-detected from Zoom, Meet, Teams, Webex, GoToMeeting,
  BlueJeans, Whereby and Skype
- **Respond to invitations in place** — Accept / Maybe / Decline without leaving the
  menu bar (see below)
- **Per-calendar visibility**, remembered across launches
- **Keyboard navigation** — arrows for days, `⌥`+arrows for months, `,`/`.` for weeks,
  `t` for today, `m` month/week, `e` timeline/list, `esc` to close

## RSVP: the interesting part

macOS gives apps no way to change your own response to an invitation. EventKit exposes
attendees and their statuses as **read-only**, and there is no Shortcuts or Siri route
either. Every other menu bar calendar therefore bounces you to Calendar.app or the web.

MenuCal handles the common case directly:

- **Google Calendar accounts** — connect the account once and Accept / Maybe / Decline
  are written straight to Google. The organiser is notified exactly as if you'd replied
  in Google Calendar.
- **Anything else** — the response opens the event in Google Calendar or Calendar.app,
  the same hand-off as before. The button never dead-ends.

Because a Google write takes seconds to minutes to sync back through CalDAV, your
answer is shown immediately and reconciled when the system catches up — so the event
loses its "unanswered" striping the moment you click, not two minutes later.

## Building

```bash
xcodebuild -project MenuCal.xcodeproj -scheme MenuCal -configuration Debug build
```

Release build and installer:

```bash
make clean && make dmg      # → dist/MenuCal.dmg
```

`make dmg` doesn't clean first, so run `make clean` or stale files can end up inside
the bundle.

No external dependencies — Apple frameworks only.

### Google credentials

The RSVP feature needs your own OAuth client. Everything else builds and runs without
it.

1. Create a project at [console.cloud.google.com](https://console.cloud.google.com) and
   enable the **Google Calendar API**. It's free and needs no billing account — the
   free tier is 1,000,000 requests/day and MenuCal makes about two per RSVP.
2. Configure the OAuth consent screen. If your calendar is on a Google Workspace
   domain you own, choose **Internal** — it skips verification and, importantly, keeps
   refresh tokens alive. Otherwise choose **External** and **publish to production**:
   left in Testing, Google revokes the refresh token every 7 days and you'll be
   re-authorising weekly.
3. Add the scope `https://www.googleapis.com/auth/calendar.events`.
4. Create an OAuth client of type **Desktop app**.
5. Put the credentials in an untracked `Secrets.xcconfig` at the repo root:

```
GOOGLE_CLIENT_ID = <id>.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET = <secret>
```

Sign-in uses the installed-app loopback flow (RFC 8252) with PKCE and the system
browser; the refresh token is stored in your Keychain. The client secret ships inside
the app bundle, which is expected for an installed app and is why the OAuth scope is
kept to the narrowest one that can respond to invitations.

## Installing

The DMG is signed with a development certificate rather than notarised, so Gatekeeper
will block the first launch: right-click the app → **Open**.

MenuCal asks for **Calendar** access on first run. **Reminders** is requested too but
is optional — declining it doesn't affect anything currently in the app.

## Privacy

Calendar data stays on your Mac. There is no server, no analytics and no telemetry.
The only outbound requests are the invitation responses you explicitly send to Google.
See [PRIVACY.md](PRIVACY.md).

## Development notes

Architecture, the RSVP override layer, and the sharp edges worth knowing about are
documented in [CLAUDE.md](CLAUDE.md).
