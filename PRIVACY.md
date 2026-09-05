# MenuCal Privacy Policy

Last updated: 30 August 2026

MenuCal is a macOS menu bar calendar app. It is designed so that your calendar
data stays on your Mac.

## What MenuCal accesses

- **Calendars and events**, and **Reminders**, through Apple's EventKit
  framework, using the permissions you grant in System Settings. This includes
  event titles, times, locations, notes, organizers and attendees — the same
  information Apple's own Calendar app shows you.

MenuCal reads this data to display it. It does not copy it anywhere.

## What leaves your Mac

Almost nothing. Specifically:

- **Nothing is sent to the developer.** MenuCal has no backend server, no
  analytics, no telemetry, and no crash reporting. No usage data is collected.
- **Google Calendar responses.** If you connect a Google account, then when you
  explicitly tap Accept, Maybe or Decline on an invitation, MenuCal sends that
  response to the Google Calendar API so it reaches the organiser. It reads the
  event first in order to send your reply without disturbing the other
  attendees. Nothing else is sent, and nothing is sent unless you tap.
- **Links you choose to open.** Opening a video call link or an event in Google
  Calendar or Apple Calendar hands the link to your browser or that app, as any
  link would.

MenuCal does not sell, share, or transmit your data to any third party.

## Credentials

If you connect a Google account, MenuCal stores the resulting OAuth tokens in
the **macOS Keychain** on your Mac. Those tokens are sent only to Google, only
to authenticate your own requests. The developer never receives them.

MenuCal requests the narrowest Google permission that allows responding to
invitations (`calendar.events`). It does not request access to your Gmail,
contacts, files, or any other Google service.

## Settings

Preferences — such as which calendars you have hidden — are stored locally on
your Mac in standard macOS app preferences. They are not synced or uploaded.

## Removing your data

- **Disconnect a Google account** in MenuCal's settings to delete its stored
  tokens from your Keychain.
- **Revoke access entirely** at
  [myaccount.google.com/permissions](https://myaccount.google.com/permissions).
- **Delete everything** by removing the MenuCal app. Because MenuCal keeps no
  server-side records, there is nothing else to delete.

Revoking calendar or reminder permission in System Settings > Privacy &
Security stops MenuCal reading that data immediately.

## Children

MenuCal is not directed at children under 13.

## Changes

Any change to this policy will be published at this URL with an updated date
above.

## Contact

Questions: **v.saketh@gmail.com**
